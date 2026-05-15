extends Node3D

@export var mouse_sensitivity = 0.5
@export var max_camera_rotation = 50
@export var min_camera_rotation = -85
@export var zoom_speed = 0.5
@export var max_zoom = 10.0
@export var first_person_snap_distance = 0.22
@export var step_smooth_speed := 14.0  # qué tan rápido suaviza el salto de escalón

@onready var player_manager = get_parent().get_node("PlayerManager")
@onready var Camera = $XCameraPivot/Camera3D
@onready var XCameraPivot = $XCameraPivot

const Y_MULT = 0.4
const MODEL_LAYER = 1 << 19

var target_zoom = 0
var shift_pressed = false
var initial_y := 0.0

# Smoothing de escaleras
var smoothed_y := 0.0
var first_frame := true
var stair_offset := 0.0

func _recover_mouse_check(is_on_focus: bool):
	if player_manager.first_person and is_on_focus:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _ready() -> void:
	initial_y = position.y
	player_manager.camera_yaw = Camera.rotation.x
	target_zoom = Camera.position.z
	player_manager.window_focus_changed.connect(_recover_mouse_check)

func manage_shift_lock() -> void:
	shift_pressed = !shift_pressed if Input.is_action_just_pressed("shift_lock") else shift_pressed
	player_manager.shift_lock_toggle_on = shift_pressed
	var right_click = Input.is_action_pressed("right_click")
	player_manager.shift_lock = right_click or shift_pressed
	if not player_manager.first_person and player_manager.is_window_selected:
		if player_manager.shift_lock:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(_delta: float) -> void:
	player_manager.camera_yaw = rotation.y

func _process(delta: float) -> void:
	manage_shift_lock()

	# --- Smooth de escaleras ---
	# target_y es el Y real del player cada frame
	var target_y = get_parent().global_position.y
	if first_frame:
		smoothed_y = target_y
		first_frame = false

	smoothed_y = lerpf(smoothed_y, target_y, step_smooth_speed * delta)
	# Compensamos en espacio local: si el player saltó +0.4 de golpe,
	# position.y queda en -0.4 y va lerpeando de vuelta a 0
	stair_offset = smoothed_y - target_y
	position.y = initial_y + stair_offset

	# --- Zoom ---
	Camera.position.z = lerp(Camera.position.z, target_zoom, 10 * delta)
	Camera.position.z = clamp(Camera.position.z, 0.0, max_zoom)

	if Camera.position.z < first_person_snap_distance and not player_manager.first_person:
		Camera.cull_mask &= ~MODEL_LAYER
		Camera.position.z = 0.0
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		player_manager.first_person = true
	if Camera.position.z > first_person_snap_distance and player_manager.first_person:
		Camera.cull_mask |= MODEL_LAYER
		Camera.position.z = first_person_snap_distance
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		player_manager.first_person = false

func _input(event: InputEvent) -> void:
	if not player_manager.is_window_selected:
		return
	if event is InputEventMouseMotion and (player_manager.first_person or player_manager.shift_lock):
		var camera_rotation = deg_to_rad(-event.relative.x * mouse_sensitivity)
		rotate_y(camera_rotation)
		XCameraPivot.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity * Y_MULT))
		XCameraPivot.rotation_degrees.x = clamp(
			XCameraPivot.rotation_degrees.x, min_camera_rotation, max_camera_rotation
		)
	if event.is_action_pressed("wheel_up"):
		target_zoom -= zoom_speed
	if event.is_action_pressed("wheel_down"):
		target_zoom += zoom_speed
	target_zoom = clamp(target_zoom, 0.0, max_zoom)
