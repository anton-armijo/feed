## Standalone orbit camera system. Lives in its own scene (camera_rig.tscn),
## is instanced inside the player prefab, and is freed for non-authority
## peers. It observes the character (position via parenting, state via the
## blackboard) and never participates in movement physics.
##
## Blackboard fields owned (written) by this rig:
##   camera_yaw, first_person, shift_lock, shift_lock_toggle_on.
class_name CameraRig
extends Node3D

@export var config: CameraConfig

@onready var x_pivot: Node3D = $XPivot
@onready var camera: Camera3D = $XPivot/Camera3D

var target_zoom := 0.0
var current_zoom := 0.0
## Written by the CameraCollision child; INF means unobstructed.
var collision_zoom_limit: float = INF

var _bb: PlayerBlackboard
var _body: CharacterBody3D
var _model: Node3D
var _initial_y := 0.0
var _shift_toggled := false
var _last_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _smoother: YSmoother
# First person forced by camera collision (so zoom-out can restore).
var _fp_from_collision := false
var _zoom_before_fp := 0.0

func setup(blackboard: PlayerBlackboard, body: CharacterBody3D) -> void:
	_bb = blackboard
	_body = body
	if config == null:
		config = CameraConfig.new()
	_initial_y = position.y
	_smoother = YSmoother.new(config.height_smooth_speed)
	target_zoom = camera.position.z
	_bb.camera_yaw = rotation.y
	_bb.input_enabled_changed.connect(_on_input_enabled_changed)
	_model = _body.get_node_or_null("Model")

func is_first_person() -> bool:
	return current_zoom < config.first_person_snap_distance

func _on_input_enabled_changed(enabled: bool) -> void:
	if not enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_last_mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif _bb.first_person:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_last_mouse_mode = Input.MOUSE_MODE_CAPTURED

func _set_mouse_mode(mode: Input.MouseMode) -> void:
	if _last_mouse_mode != mode:
		_last_mouse_mode = mode
		Input.set_mouse_mode(mode)

func _physics_process(_delta: float) -> void:
	if _bb == null:
		return
	# Published in physics time so input/FSM read a stable yaw.
	_bb.camera_yaw = rotation.y

func _process(delta: float) -> void:
	if _bb == null:
		return
	_manage_shift_lock()
	_follow_height(delta)
	_update_zoom(delta)

func _manage_shift_lock() -> void:
	if Input.is_action_just_pressed("shift_lock"):
		_shift_toggled = not _shift_toggled
	_bb.shift_lock_toggle_on = _shift_toggled
	_bb.shift_lock = _shift_toggled or Input.is_action_pressed("right_click")
	if not _bb.first_person and _bb.input_enabled and not config.force_first_person:
		_set_mouse_mode(Input.MOUSE_MODE_CAPTURED if _bb.shift_lock else Input.MOUSE_MODE_VISIBLE)

func _follow_height(delta: float) -> void:
	var target_y := _body.global_position.y
	_smoother.process_smoothing(delta, target_y)
	position.y = _initial_y + _smoother.get_offset(target_y)

func _update_zoom(delta: float) -> void:
	if config.force_first_person:
		if _model:
			_model.visible = false
		camera.position.z = 0.0
		current_zoom = 0.0
		target_zoom = 0.0
		if not _bb.first_person:
			_set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			_bb.first_person = true
		return

	camera.position.z = lerpf(
		camera.position.z,
		minf(target_zoom, collision_zoom_limit),
		config.zoom_lerp_speed * delta
	)
	camera.position.z = clampf(camera.position.z, 0.0, config.max_zoom)
	current_zoom = camera.position.z

	# Snap into first person.
	if camera.position.z < config.first_person_snap_distance and not _bb.first_person:
		if _model:
			_model.visible = false
		camera.position.z = 0.0
		current_zoom = 0.0
		_set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_bb.first_person = true
		if target_zoom > config.first_person_snap_distance:
			_zoom_before_fp = target_zoom
			_fp_from_collision = true
			target_zoom = 0.0

	# Leave first person (smooth zoom out instead of snapping).
	if camera.position.z > config.first_person_snap_distance and _bb.first_person:
		if _model:
			_model.visible = true
		target_zoom = config.first_person_snap_distance
		_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_bb.first_person = false

func _input(event: InputEvent) -> void:
	if _bb == null or not _bb.input_enabled:
		return

	if event is InputEventMouseMotion and (_bb.first_person or _bb.shift_lock):
		rotate_y(deg_to_rad(-event.relative.x * config.mouse_sensitivity))
		x_pivot.rotate_x(deg_to_rad(
			-event.relative.y * config.mouse_sensitivity * config.pitch_sensitivity_multiplier))
		x_pivot.rotation_degrees.x = clampf(
			x_pivot.rotation_degrees.x, config.pitch_min_degrees, config.pitch_max_degrees)

	if config.force_first_person:
		return

	if event.is_action_pressed("wheel_up"):
		if not _fp_from_collision:
			target_zoom -= config.zoom_speed

	if event.is_action_pressed("wheel_down"):
		if _fp_from_collision:
			target_zoom = _zoom_before_fp
			_fp_from_collision = false
		else:
			target_zoom += config.zoom_speed

	target_zoom = clampf(target_zoom, 0.0, config.max_zoom)
