## Composition root of the character. Owns no gameplay logic itself: it wires
## the components together (references down), drives the fixed per-frame
## pipeline, and publishes raw physics facts to the blackboard. Components
## report back through signals or blackboard fields (signals up).
##
## Physics pipeline (authority only):
##   1. InputCollector  -> InputIntent          (intent, never execution)
##   2. StairStepper    -> grounded bookkeeping
##   3. AbilityManager  -> modifiers / FSM transition requests
##   4. LocomotionFSM   -> state logic, drives the MovementMotor
##   5. MovementMotor   -> stair step + move_and_slide (the only physics write)
##   6. Blackboard      -> publish state for presentation / sync layers
class_name Player
extends CharacterBody3D

@export var config: PlayerConfig

@onready var blackboard: PlayerBlackboard = $Blackboard
@onready var input_collector: InputCollector = $InputCollector
@onready var motor: MovementMotor = $MovementMotor
@onready var stepper: StairStepper = $MovementMotor/StairStepper
@onready var ground_probe: GroundProbe = $GroundProbe
@onready var fsm: LocomotionFSM = $LocomotionFSM
@onready var ability_manager: AbilityManager = $AbilityManager
@onready var model: ModelVisual = $Model
@onready var animation_controller: AnimationController = $Model/CharacterScene/AnimationTree
@onready var animation_driver: AnimationDriver = $Model/CharacterScene/AnimationDriver
@onready var camera_rig: CameraRig = $CameraRig

var peer_id: int
var _is_local := false

func _ready() -> void:
	peer_id = get_multiplayer_authority()
	var my_id := multiplayer.get_unique_id()
	_is_local = peer_id == my_id or name == str(my_id)
	add_to_group("players")

	print("[Player] _ready: name=%s, peer_id=%d, my_id=%d, authority=%d, is_local=%s" % [name, peer_id, my_id, get_multiplayer_authority(), _is_local])

	floor_snap_length = 0.35
	floor_stop_on_slope = true
	floor_block_on_wall = false

	if config == null:
		config = PlayerConfig.new()
	config.ensure_defaults()
	blackboard.body_height = config.body_height

	# References down: wire every component from the single composition root.
	stepper.setup(self)
	motor.setup(self, stepper, config)
	ground_probe.setup(self, config.body_height)
	input_collector.setup(blackboard, config)
	fsm.setup(self, motor, stepper, ground_probe, blackboard, config)
	ability_manager.setup(AbilityContext.new(self, motor, fsm, blackboard))

	# Presentation layers run on every peer (remote state arrives via sync).
	model.setup(blackboard, self)
	animation_controller.setup(blackboard)
	animation_driver.setup(blackboard, config.locomotion)

	if _is_local:
		camera_rig.setup(blackboard, self, model)
		fsm.start()
	else:
		# The camera is a local-only system; remote replicas never need one.
		camera_rig.queue_free()

	model.teleport()

func _physics_process(delta: float) -> void:
	if not _is_local:
		return

	input_collector.collect(delta)
	var intent := input_collector.intent

	stepper.update_grounded(delta)
	ability_manager.physics_update(intent, delta)
	fsm.physics_update(intent, delta)
	motor.physics_step(delta)

	_update_model_yaw(intent, delta)
	_publish_state(intent)

## Gameplay-facing yaw: faces the camera in first person / shift lock, or
## turns toward the move direction. ModelVisual applies it visually.
func _update_model_yaw(intent: InputIntent, delta: float) -> void:
	if blackboard.first_person or blackboard.shift_lock_toggle_on:
		blackboard.model_yaw = blackboard.camera_yaw
		return
	if intent.wish_dir == Vector3.ZERO:
		return
	blackboard.model_yaw = lerp_angle(
		blackboard.model_yaw,
		atan2(-intent.wish_dir.x, -intent.wish_dir.z),
		config.locomotion.model_turn_speed * delta
	)

func _publish_state(intent: InputIntent) -> void:
	blackboard.is_grounded = motor.is_grounded_visual()
	blackboard.velocity_y = velocity.y
	blackboard.horizontal_speed = Vector2(velocity.x, velocity.z).length()
	blackboard.has_move_input = intent.wish_dir != Vector3.ZERO
	blackboard.wish_direction = intent.wish_dir
	blackboard.velocity = velocity
	blackboard.move_speed_multiplier = motor.speed_multiplier()
