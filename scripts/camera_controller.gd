extends Node3D
class_name CameraController

@export var mouse_sensitivity = 0.5
@export var max_camera_rotation = 50
@export var min_camera_rotation = -85
@export var zoom_speed = 0.5
@export var max_zoom = 10.0
@export var first_person_snap_distance = 0.22

@export var player_manager: PlayerManager
@export var visual_smoother: TransformSmootherComponent

@onready var camera = $XCameraPivot/Camera3D
@onready var XCameraPivot = $XCameraPivot

const Y_MULT = 0.4
const MODEL_LAYER = 1 << 19

var target_zoom = 0
var shift_pressed = false
var initial_y := 0.0
var collision_zoom_limit: float = INF

var _last_mouse_mode := Input.MOUSE_MODE_VISIBLE

# Distancia actual de la cámara — variable compartida para otros nodos
var current_zoom: float = 0.0

# Control de primera persona forzada por colisión
var _fp_from_collision: bool = false
var _zoom_before_fp: float = 0.0

func is_first_person() -> bool:
	return current_zoom < first_person_snap_distance

func _recover_mouse_check(is_on_focus: bool):
	if player_manager.first_person and is_on_focus:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _ready() -> void:
	initial_y = position.y
	
	if not player_manager: player_manager = $"../PlayerManager"
	if not visual_smoother: 
		visual_smoother = TransformSmootherComponent.new()
		visual_smoother.smooth_speed = 14.0
		add_child(visual_smoother)

	player_manager.camera_yaw = camera.rotation.x
	target_zoom = camera.position.z
	player_manager.window_focus_changed.connect(_recover_mouse_check)

func _set_mouse_mode(mode: int) -> void:
	if _last_mouse_mode != mode:
		_last_mouse_mode = mode
		Input.set_mouse_mode(mode)

func manage_shift_lock() -> void:
	shift_pressed = !shift_pressed if Input.is_action_just_pressed("shift_lock") else shift_pressed
	player_manager.shift_lock_toggle_on = shift_pressed
	var right_click = Input.is_action_pressed("right_click")
	player_manager.shift_lock = right_click or shift_pressed
	if not player_manager.first_person and player_manager.is_window_selected:
		if player_manager.shift_lock:
			_set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _physics_process(_delta: float) -> void:
	player_manager.camera_yaw = rotation.y


func _process(delta: float) -> void:
	manage_shift_lock()

	var target_y = get_parent().global_position.y
	if visual_smoother:
		visual_smoother.process_smoothing(delta, target_y)
		position.y = initial_y + visual_smoother.get_stair_offset(target_y)
	
	camera.position.z = lerp(
		camera.position.z,
		minf(target_zoom, collision_zoom_limit), 10 * delta)
	camera.position.z = clamp(camera.position.z, 0.0, max_zoom)

	current_zoom = camera.position.z

	if camera.position.z < first_person_snap_distance and not player_manager.first_person:
		camera.cull_mask &= ~MODEL_LAYER
		camera.position.z = 0.0
		current_zoom = 0.0
		_set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		player_manager.first_person = true

		if target_zoom > first_person_snap_distance:
			_zoom_before_fp = target_zoom
			_fp_from_collision = true
			target_zoom = 0.0

	if camera.position.z > first_person_snap_distance and player_manager.first_person:
		camera.cull_mask |= MODEL_LAYER
		# Smooth zoom out instead of snapping
		target_zoom = first_person_snap_distance
		_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
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
		if not _fp_from_collision:
			target_zoom -= zoom_speed

	if event.is_action_pressed("wheel_down"):
		if _fp_from_collision:
			target_zoom = _zoom_before_fp
			_fp_from_collision = false
		else:
			target_zoom += zoom_speed

	target_zoom = clamp(target_zoom, 0.0, max_zoom)
