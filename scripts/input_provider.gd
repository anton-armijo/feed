extends Node
class_name InputProvider

var move_dir := Vector2.ZERO
var wish_dir := Vector3.ZERO
var is_running := false
var is_jumping := false
var is_jumping_just_pressed := false

var _jump_buffer_timer := 0.0
@export var jump_buffer_time := 0.1

func update(delta: float, camera_yaw: float, can_receive_input: bool) -> void:
	if not can_receive_input:
		move_dir = Vector2.ZERO
		wish_dir = Vector3.ZERO
		is_running = false
		is_jumping = false
		is_jumping_just_pressed = false
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)
		return

	var raw_input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_forward", "move_back")
	)
	
	#if not has_pressed_first_input:
		#if raw_input_dir != Vector2.ZERO:
			#has_pressed_first_input = true
			#
	#if not has_pressed_first_input:
		#raw_input_dir = Vector2.ZERO
		
	move_dir = raw_input_dir
	
	wish_dir = Vector3.ZERO
	if move_dir.length_squared() > 0.001:
		wish_dir = Vector3(move_dir.x, 0.0, move_dir.y).rotated(Vector3.UP, camera_yaw).normalized()

	is_running = Input.is_action_pressed("run")
	is_jumping = Input.is_action_pressed("jump")
	
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = max(_jump_buffer_timer - delta, 0.0)
		
	is_jumping_just_pressed = _jump_buffer_timer > 0.0

func consume_jump_buffer() -> void:
	_jump_buffer_timer = 0.0
	is_jumping_just_pressed = false
