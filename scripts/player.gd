extends CharacterBody3D
class_name Player

@export var movement_data: MovementData
@export var player_manager: PlayerManager
@export var camera_controller: CameraController

@onready var stair_handler: StairStepperComponent = $StairStepperComponent
@onready var model: Node3D = $Model
@onready var input_provider: InputProvider = $InputProvider
@onready var visual_smoother: TransformSmootherComponent = $TransformSmootherComponent

@onready var ui = $ui

var peer_id: int

var model_initial_rotation: Vector3 = Vector3.ZERO
var model_initial_y: float = 0.0

var coyote_timer: float = 0.0

enum PlayerState { GROUNDED, AIR }
var current_state: PlayerState = PlayerState.GROUNDED

func watch_object(object_manager: Node) -> void:
	ui.watch(object_manager)

func _ready() -> void:
	peer_id = get_multiplayer_authority()
	floor_snap_length    = 0.35
	floor_stop_on_slope  = true
	floor_block_on_wall  = false
	
	if not player_manager:
		player_manager = $PlayerManager
	if not camera_controller:
		camera_controller = $YCameraPivot
		
	if not movement_data:
		movement_data = MovementData.new()
		
	model_initial_rotation = model.rotation
	model_initial_y        = model.position.y
	
	visual_smoother.teleport()

func _process(delta: float) -> void:
	visual_smoother.process_smoothing(delta, global_position.y)
	model.global_position.y = visual_smoother.get_smoothed_y() + model_initial_y

func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
		
	# Input reading via Provider
	input_provider.update(delta, player_manager.camera_yaw, player_manager.is_window_selected)
	
	stair_handler.update_grounded(delta)
	
	var on_floor : bool = is_on_floor() or player_manager.is_stepping
	
	match current_state:
		PlayerState.GROUNDED:
			_state_grounded(delta, on_floor)
		PlayerState.AIR:
			_state_air(delta, on_floor)
			
	if not player_manager.is_window_selected:
		_apply_horizontal_friction(delta)
		move_and_slide()
		return
		
	_handle_horizontal_movement(delta)
	_update_model_rotation(input_provider.wish_dir, delta)
	
	stair_handler.step_up(Vector3(velocity.x, 0.0, velocity.z) * delta)
	move_and_slide()
	
	if player_manager.is_stepping:
		apply_floor_snap()
	else:
		stair_handler.step_down()
		
	# Update Manager
	player_manager.is_grounded        = is_on_floor() or player_manager.is_stepping or player_manager.is_stepping_down
	player_manager.velocity_y         = velocity.y
	player_manager.has_horizontal_input = input_provider.wish_dir != Vector3.ZERO
	player_manager.is_running         = input_provider.is_running

func _state_grounded(delta: float, on_floor: bool) -> void:
	coyote_timer = movement_data.coyote_time
	
	if not on_floor:
		current_state = PlayerState.AIR
		return
		
	# Jump check
	if input_provider.is_jumping_just_pressed and coyote_timer > 0.0:
		velocity.y = movement_data.jump_velocity
		input_provider.consume_jump_buffer()
		coyote_timer = 0.0
		current_state = PlayerState.AIR
		
	player_manager.is_grounded = true

func _state_air(delta: float, on_floor: bool) -> void:
	velocity.y -= movement_data.gravity * delta
	coyote_timer = max(coyote_timer - delta, 0.0)
	
	if on_floor and velocity.y <= 0.0:
		current_state = PlayerState.GROUNDED
		return
		
	# Allows jumping just after falling off ledge
	if input_provider.is_jumping_just_pressed and coyote_timer > 0.0 and velocity.y <= 0.0:
		velocity.y = movement_data.jump_velocity
		input_provider.consume_jump_buffer()
		coyote_timer = 0.0
		
	player_manager.is_grounded = player_manager.is_stepping_down

func _handle_horizontal_movement(delta: float) -> void:
	var is_running    := input_provider.is_running
	var current_speed := movement_data.run_speed if is_running else movement_data.speed
	var wish_dir      := input_provider.wish_dir
	
	var h_vel := Vector3(velocity.x, 0.0, velocity.z)
	if wish_dir != Vector3.ZERO:
		var dot := h_vel.dot(wish_dir)
		if dot < 0.0:
			# Decelerate progressively instead of killing velocity instantly
			h_vel *= 0.5
			
		var accel := movement_data.run_to_walk_deceleration if not is_running and h_vel.length() > movement_data.speed else movement_data.acceleration
		h_vel = h_vel.move_toward(wish_dir * current_speed, accel * delta)
	else:
		var stop_friction := movement_data.run_to_walk_deceleration if h_vel.length() > movement_data.speed else movement_data.friction
		h_vel = h_vel.move_toward(Vector3.ZERO, stop_friction * delta)
		
	velocity.x = h_vel.x
	velocity.z = h_vel.z

func _update_model_rotation(wish_dir: Vector3, delta: float) -> void:
	if player_manager.first_person or player_manager.shift_lock_toggle_on:
		model.rotation.y = model_initial_rotation.y + player_manager.camera_yaw
		return
	if wish_dir == Vector3.ZERO:
		return
	model.rotation.y = lerp_angle(
		model.rotation.y,
		model_initial_rotation.y + atan2(-wish_dir.x, -wish_dir.z),
		movement_data.model_turn_speed * delta
	)

func _apply_horizontal_friction(delta: float) -> void:
	var h_vel := Vector3(velocity.x, 0.0, velocity.z)
	h_vel      = h_vel.move_toward(Vector3.ZERO, movement_data.friction * delta)
	velocity.x = h_vel.x
	velocity.z = h_vel.z
