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
##
## PlayerAssembler gates all optional components at startup (from
## PlayerComponentsConfig) and at runtime (set_enabled / toggle).
class_name Player
extends CharacterBody3D

@export var config: PlayerConfig

var _model_turn_speed: float

@onready var assembler: PlayerAssembler = $PlayerAssembler
@onready var blackboard: PlayerBlackboard = $Blackboard
@onready var api: PlayerApi = $PlayerApi
@onready var input_collector: InputCollector = $InputCollector
@onready var motor: MovementMotor = $MovementMotor
@onready var stepper: StairStepper = $MovementMotor/StairStepper
@onready var ground_probe: GroundProbe = $GroundProbe
@onready var fsm: LocomotionFSM = $LocomotionFSM
@onready var ability_manager: AbilityManager = $AbilityManager
@onready var model: ModelVisual = $Model
@onready var presenter: CharacterPresenter = $Model/CharacterScene
@onready var camera_rig: CameraRig = $CameraRig

var peer_id: int
var _is_local := false

func _ready() -> void:
	peer_id = get_multiplayer_authority()
	var my_id := multiplayer.get_unique_id()
	_is_local = peer_id == my_id or name == str(my_id)
	add_to_group("players")

	# The custom StairStepper handles all step-up/step-down logic. Disabling
	# the built-in floor snap prevents it from fighting the stepper's upward
	# teleport and producing vertical jitter on stairs.
	floor_snap_length = 0.0
	floor_stop_on_slope = true
	floor_block_on_wall = false

	if config == null:
		config = PlayerConfig.new()
	config.ensure_defaults()
	config.validate()
	blackboard.body_height = config.body_height
	_model_turn_speed = config.locomotion.compute_model_turn_speed(config.weight)

	# Core — always present and wired.
	motor.setup(self, blackboard, stepper, config.locomotion, config.jump)
	ground_probe.setup(self, config.probe, config.body_height)
	fsm.setup(self, motor, stepper, ground_probe, blackboard, config)
	assembler.apply_initial_state()

	# Semi-core — gated by assembler.
	if assembler.is_enabled("StairStepper") and stepper != null:
		stepper.setup(self, blackboard, config.stair, config.body_height)
	if assembler.is_enabled("InputCollector") and input_collector != null:
		input_collector.setup(blackboard, config.jump)

	# Centralised verb surface — built after all subsystems are wired so it
	# can forward to them. Abilities receive this instead of a dedicated context.
	api.setup(blackboard, motor, fsm, input_collector, camera_rig, presenter, config, ability_manager)

	if assembler.is_enabled("AbilityManager") and ability_manager != null:
		ability_manager.setup(api)
		if assembler.is_enabled("LockOnCharacter"):
			var lock_ability := LockOnCharacterAbility.new()
			ability_manager.register(lock_ability)

	# Presentation layers run on every peer (remote state arrives via sync).
	if assembler.is_enabled("Model"):
		model.setup(blackboard, self)
		presenter.setup_presenter(blackboard, config)

	# Wire FootIKController (auto-discovered by presenter_setup) to ModelVisual
	# so the IK's hip-lowering offset is blended into Y smoothing.
	if assembler.is_enabled("FootIK"):
		var ik_controller: FootIKController = _find_ik_controller()
		if ik_controller != null:
			model.set_ik_controller(ik_controller)

	if _is_local:
		if assembler.is_enabled("CameraRig"):
			camera_rig.setup(blackboard, self, model, presenter)
			api.set_lock_mouse_default(config.components.default_lock_mouse_mode)
			camera_rig.setup_effects(
				config.camera_effects,
				config.locomotion.run_speed
			)
		fsm.start()
	else:
		if assembler.is_enabled("CameraRig"):
			camera_rig.queue_free()

	if assembler.is_enabled("Model"):
		model.teleport()

func _physics_process(delta: float) -> void:
	if not _is_local:
		return

	var intent: InputIntent = null
	if assembler.is_enabled("InputCollector") and input_collector != null:
		input_collector.collect(delta)
		intent = input_collector.intent
	if intent == null:
		intent = InputIntent.new()

	if assembler.is_enabled("StairStepper") and stepper != null:
		stepper.update_grounded(delta)
	if assembler.is_enabled("AbilityManager") and ability_manager != null:
		ability_manager.physics_update(intent, delta)
	fsm.physics_update(intent, delta)
	motor.physics_step(delta)

	_update_model_yaw(intent, delta)
	_publish_state(intent)

## Gameplay-facing yaw: faces the camera in first person / shift lock, or
## turns toward the move direction. ModelVisual applies it visually.
func _update_model_yaw(intent: InputIntent, delta: float) -> void:
	if blackboard.first_person or blackboard.lock_on_character:
		blackboard.model_yaw = blackboard.camera_yaw
		return
	if intent.wish_dir == Vector3.ZERO:
		return
	blackboard.model_yaw = lerp_angle(
		blackboard.model_yaw,
		atan2(-intent.wish_dir.x, -intent.wish_dir.z),
		_model_turn_speed * delta
	)

func _publish_state(intent: InputIntent) -> void:
	blackboard.is_grounded = motor.is_grounded_visual()
	blackboard.velocity_y = velocity.y
	blackboard.horizontal_speed = Vector2(velocity.x, velocity.z).length()
	blackboard.has_move_input = intent.wish_dir != Vector3.ZERO
	blackboard.wish_direction = intent.wish_dir
	blackboard.velocity = velocity
	blackboard.move_speed_multiplier = motor.speed_multiplier()
	if is_on_floor():
		blackboard.last_safe_position = global_position

func _find_ik_controller() -> FootIKController:
	if presenter == null:
		return null
	for child in presenter.find_children("FootIKController", "FootIKController", false, true):
		return child as FootIKController
	return null
