extends CharacterBody3D

@export var speed := 4.5
@export var run_speed := 7.0
@export var jump_velocity := 4.2
@export var acceleration := 25.0
@export var friction := 18.0
@export var coyote_time := 0.05
@export var jump_buffer_time := 0.1
@export var gravity := 9.8
@export var model_turn_speed := 12.0
@export var model_yaw_offset_deg := 0.0
@export var step_smooth_speed := 14.0

@onready var player_manager = $PlayerManager
@onready var stair_handler = $AuraMonsterModule
@onready var camera_controller = $YCameraPivot
@onready var model = $Model

var model_initial_rotation := Vector3.ZERO
var model_initial_y := 0.0
var model_smoothed_y := 0.0
var model_first_frame := true

var coyote_timer := 0.0
var jump_buffer_timer := 0.0
var was_on_floor := false

func _ready() -> void:
	floor_snap_length = 0.35
	floor_stop_on_slope = true
	floor_block_on_wall = false

	model_initial_rotation = model.rotation
	model_initial_y = model.position.y

func _process(delta: float) -> void:
	var target_y := global_position.y
	if model_first_frame:
		model_smoothed_y = target_y
		model_first_frame = false

	model_smoothed_y = lerpf(model_smoothed_y, target_y, step_smooth_speed * delta)
	model.global_position.y = model_smoothed_y + model_initial_y

func _physics_process(delta: float) -> void:
	stair_handler.update_grounded()

	var effectively_on_floor = is_on_floor() \
		or stair_handler.is_stepping \
		or stair_handler.is_stepping_down

	player_manager.is_grounded = effectively_on_floor

	if not effectively_on_floor:
		velocity.y -= gravity * delta

	coyote_timer = coyote_time if effectively_on_floor else max(coyote_timer - delta, 0.0)

	if Input.is_action_pressed("jump"):
		jump_buffer_timer = jump_buffer_time
	else:
		jump_buffer_timer = max(jump_buffer_timer - delta, 0.0)

	if not player_manager.is_window_selected:
		_apply_horizontal_friction(delta)
		was_on_floor = effectively_on_floor
		move_and_slide()
		return

	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back")
	)

	var is_running := Input.is_action_pressed("run")
	var current_speed := run_speed if is_running else speed

	var wish_dir := Vector3.ZERO
	if input_dir.length_squared() > 0.001:
		var local := Vector3(input_dir.x, 0.0, input_dir.y)
		wish_dir = local.rotated(Vector3.UP, player_manager.camera_yaw).normalized()

	var h_vel := Vector3(velocity.x, 0.0, velocity.z)
	if wish_dir != Vector3.ZERO:
		h_vel = h_vel.move_toward(wish_dir * current_speed, acceleration * delta)
	else:
		h_vel = h_vel.move_toward(Vector3.ZERO, friction * delta)

	velocity.x = h_vel.x
	velocity.z = h_vel.z

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		velocity.y = jump_velocity
		jump_buffer_timer = 0.0
		coyote_timer = 0.0

	_update_model_rotation(wish_dir, delta)

	stair_handler.step_up(Vector3(velocity.x, 0.0, velocity.z) * delta)
	move_and_slide()

	if stair_handler.is_stepping:
		apply_floor_snap()
	else:
		stair_handler.step_down()

	var on_floor_final = is_on_floor() \
		or stair_handler.is_stepping \
		or stair_handler.is_stepping_down

	player_manager.is_grounded = on_floor_final
	player_manager.velocity_y = velocity.y
	_update_state(wish_dir, is_running, on_floor_final)
	was_on_floor = on_floor_final

func _update_model_rotation(wish_dir: Vector3, delta: float) -> void:
	if player_manager.first_person or player_manager.shift_lock_toggle_on:
		model.rotation.y = model_initial_rotation.y + player_manager.camera_yaw
		return

	if wish_dir == Vector3.ZERO:
		return

	var target_yaw := atan2(-wish_dir.x, -wish_dir.z)
	var target_rotation_y := model_initial_rotation.y + target_yaw

	model.rotation.y = lerp_angle(
		model.rotation.y,
		target_rotation_y,
		model_turn_speed * delta
	)

func _update_state(wish_dir: Vector3, is_running: bool, on_floor: bool) -> void:
	var effectively_on_floor = on_floor or stair_handler.is_stepping

	if not effectively_on_floor:
		if velocity.y > 0.0:
			_enter_state(player_manager.State.JUMPING)
		else:
			_enter_state(player_manager.State.FALLING)
		return

	if wish_dir != Vector3.ZERO:
		_enter_state(player_manager.State.RUNNING if is_running else player_manager.State.WALKING)
	else:
		_enter_state(player_manager.State.IDLE)

func _enter_state(new_state) -> void:
	if player_manager.state == new_state:
		return
	player_manager.state = new_state

func _apply_horizontal_friction(delta: float) -> void:
	var h_vel := Vector3(velocity.x, 0.0, velocity.z)
	h_vel = h_vel.move_toward(Vector3.ZERO, friction * delta)
	velocity.x = h_vel.x
	velocity.z = h_vel.z
