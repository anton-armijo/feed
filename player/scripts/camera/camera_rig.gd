## Standalone orbit camera system. Lives in its own scene (camera_rig.tscn),
## is instanced inside the player prefab, and is freed for non-authority
## peers. It observes the character (position via parenting, state via the
## blackboard) and never participates in movement physics.
##
## Blackboard fields owned (written) by this rig:
##   camera_yaw, camera_pitch, camera_zoom, first_person, lock_on_character, lock_mouse.
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
var _presenter: CharacterPresenter
var _initial_y := 0.0
var _last_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _smoother: YSmoother

## True after regaining focus; camera stays frozen until a click is received.
var _awaiting_recapture := false
# --- Scripted control (set via PlayerApi) -------------------------------------
## When true, mouse input is ignored and camera_yaw is driven by set_scripted_yaw.
var _scripted_mode := false
## Runtime first-person force (cutscenes/abilities). Stacks with config.force_first_person.
var _first_person_forced := false
## lock_mouse default mode: "always_on" (mouse locked by default, right-click releases)
## or "always_off" (mouse free by default, right-click locks). Set via PlayerApi.
var _lock_mouse_default: StringName = &"always_off"
# --- Camera effects (FOV + shake) ---------------------------------------------
var _effects: ResolvedPlayerConfig.CameraEffects
var _effects_enabled := true
var _manual_fov: float = -1.0  # < 0 = no manual override
var _shake_trauma: float = 0.0
var _shake_time: float = 0.0
var _fall_shake: float = 0.0  # continuous build-up while falling
var _fov_kick: float = 0.0   # land FOV impulse, decays with land_shake_duration
var _run_speed: float = 5.4  # for FOV/shake normalization; set in setup_effects

func setup(
	blackboard: PlayerBlackboard,
	body: CharacterBody3D,
	model_node: Node3D = null,
	presenter: CharacterPresenter = null
) -> void:
	_bb = blackboard
	_body = body
	_presenter = presenter
	if config == null:
		config = CameraConfig.new()
	_initial_y = position.y
	_smoother = YSmoother.new(config.height_smooth_speed)
	target_zoom = camera.position.z
	_bb.camera_yaw = rotation.y
	_bb.input_enabled_changed.connect(_on_input_enabled_changed)
	_bb.landed.connect(_on_landed)
	_model = model_node

	# React to UI-layer mouse-capture blocks without knowing who sets them.
	NetSession.state.mouse_capture_blocked_changed.connect(_on_mouse_capture_blocked_changed)

## Wires the dynamic camera effects (FOV + shake). Called by Player after
## setup() if camera effects are enabled.
func setup_effects(
	effects: ResolvedPlayerConfig.CameraEffects,
	run_speed: float
) -> void:
	_effects = effects
	_effects_enabled = effects.enabled
	_run_speed = run_speed
	if _effects_enabled:
		camera.fov = effects.base_fov

## True when the user intentionally zoomed past the snap threshold.
## Uses target_zoom (intent) rather than current_zoom so collision-driven
## camera pushes don't trigger first-person mode.
func is_first_person() -> bool:
	return target_zoom < config.first_person_snap_distance

# --- Scripted control (PlayerApi verbs) ---------------------------------------

## Force first-person view at runtime (cutscenes/abilities). Stacks with
## config.force_first_person. Pass false to release the runtime force.
func set_first_person_forced(forced: bool) -> void:
	_first_person_forced = forced

## lock_mouse default mode: "always_on" (mouse locked by default, right-click
## temporarily releases) or "always_off" (mouse free by default, right-click
## temporarily locks). The rig inverts this default while right-click is held.
func set_lock_mouse_default(mode: StringName) -> void:
	_lock_mouse_default = mode

## Puts the rig in scripted mode and sets the camera yaw (radians). While in
## scripted mode, mouse input is ignored. Pass a yaw to rotate the rig; the
## rig publishes camera_yaw from its rotation each physics frame as usual.
func set_scripted_yaw(rad: float) -> void:
	_scripted_mode = true
	rotation.y = rad
	_bb.camera_yaw = rad

func _on_input_enabled_changed(enabled: bool) -> void:
	if not enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_last_mouse_mode = Input.MOUSE_MODE_VISIBLE
		_awaiting_recapture = false
	elif _bb.first_person:
		_awaiting_recapture = true

func _set_mouse_mode(mode: Input.MouseMode) -> void:
	if NetSession.state.mouse_capture_blocked and mode == Input.MOUSE_MODE_CAPTURED:
		return
	if _last_mouse_mode != mode:
		_last_mouse_mode = mode
		Input.set_mouse_mode(mode)

func _physics_process(_delta: float) -> void:
	if _bb == null:
		return
	# Published in physics time so input/FSM read a stable yaw.
	_bb.camera_yaw = rotation.y
	_bb.camera_pitch = x_pivot.rotation.x

func _process(delta: float) -> void:
	if _bb == null:
		return
	_manage_locks()
	_follow_height(delta)
	_update_zoom(delta)
	_update_effects(delta)

# --- Camera effects (FOV + shake) ---------------------------------------------

## Triggers a landing shake impulse + FOV kick, scaled by fall distance.
func _on_landed(fall_distance: float) -> void:
	if not _effects_enabled or _effects == null:
		return
	var t := clampf(fall_distance / _effects.fall_distance_for_max_shake, 0.0, 1.0)
	_shake_trauma = minf(_shake_trauma + t, 1.0)
	_fov_kick = maxf(_fov_kick, t)

## Sets a manual FOV override (degrees). Pass -1 to clear and return to auto.
func set_fov(deg: float) -> void:
	_manual_fov = deg

## Adds a shake impulse (0..1) on top of any existing trauma.
func add_shake(amount: float) -> void:
	_shake_trauma = minf(_shake_trauma + amount, 1.0)

## Enables/disables the automatic FOV and shake curves.
func set_effects_enabled(enabled: bool) -> void:
	_effects_enabled = enabled
	if not enabled:
		_shake_trauma = 0.0
		if _effects != null and _manual_fov < 0.0:
			camera.fov = _effects.base_fov

func _update_effects(delta: float) -> void:
	if not _effects_enabled or _effects == null:
		return
	_update_fov(delta)
	_update_shake(delta)

func _update_fov(delta: float) -> void:
	# Land FOV kick decays with land_shake_duration.
	if _fov_kick > 0.0:
		_fov_kick = maxf(_fov_kick - delta / _effects.land_shake_duration, 0.0)
	var target: float
	if _manual_fov >= 0.0:
		target = _manual_fov
	else:
		var speed_frac := clampf(_bb.horizontal_speed / _loco_run_speed(), 0.0, 1.0)
		var fall_frac := clampf(-_bb.velocity_y / _effects.fall_speed_for_max_fov, 0.0, 1.0)
		target = _effects.base_fov
		target += _effects.run_fov_add * speed_frac
		target += _effects.fall_fov_add * fall_frac
		target += _effects.land_fov_kick * _fov_kick
	camera.fov = lerpf(camera.fov, target, _effects.fov_lerp_speed * delta)

func _update_shake(delta: float) -> void:
	# Land trauma decays.
	if _shake_trauma > 0.0:
		_shake_trauma = maxf(_shake_trauma - delta / _effects.land_shake_duration, 0.0)
	_shake_time += delta

	# Fall shake: ramps up while airborne with negative velocity, decays fast
	# when grounded. Simulates wind resistance building up.
	var fall_frac := clampf(-_bb.velocity_y / _effects.fall_speed_for_max_fov, 0.0, 1.0)
	if not _bb.is_grounded and fall_frac > 0.0:
		_fall_shake = minf(
			_fall_shake + fall_frac * _effects.fall_shake_ramp_speed * delta,
			_effects.fall_shake_max
		)
	else:
		_fall_shake = lerpf(_fall_shake, 0.0, 10.0 * delta)

	# Total shake = land trauma² + continuous fall + run.
	var trauma_sq := _shake_trauma * _shake_trauma
	var run_frac := clampf(_bb.horizontal_speed / _loco_run_speed(), 0.0, 1.0)
	var total := trauma_sq * _effects.land_shake_amount + _fall_shake + run_frac * _effects.run_shake_amount

	if total > 0.0005:
		# Offset: subtle positional shake (10x less than before).
		var noise_x := sin(_shake_time * _effects.shake_frequency * 1.7)
		var noise_y := sin(_shake_time * _effects.shake_frequency * 2.3 + 1.5)
		camera.h_offset = noise_x * total
		camera.v_offset = noise_y * total
		# Tilt: camera ladeo — wind resistance feel.
		var tilt_rad := deg_to_rad(_effects.tilt_amount)
		var tilt_noise := sin(_shake_time * _effects.tilt_frequency)
		camera.rotation.z = tilt_noise * total * tilt_rad * 10.0
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		camera.rotation.z = lerpf(camera.rotation.z, 0.0, 10.0 * delta)

## Helper: run_speed for FOV/shake normalization (set in setup_effects).
func _loco_run_speed() -> float:
	return _run_speed

func _on_mouse_capture_blocked_changed(blocked: bool) -> void:
	if blocked:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_last_mouse_mode = Input.MOUSE_MODE_VISIBLE
		_awaiting_recapture = false
	elif _bb and _bb.first_person:
		_set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

## Manages lock_mouse: the mouse is locked by default (always_on) or free by
## default (always_off). Right-click inverts the default while held. The
## rig writes lock_mouse to the blackboard and captures/releases the cursor.
## lock_on_character is managed by the LockOnCharacter ability (F3 toggle);
## the rig only reads it here to decide mouse capture in TP non-shift view.
func _manage_locks() -> void:
	var right_click_held := Input.is_action_pressed("right_click")
	var base_locked := _lock_mouse_default == &"always_on"
	# Right-click inverts the default.
	_bb.lock_mouse = base_locked != right_click_held

	if not _bb.first_person and _bb.input_enabled and not config.force_first_person:
		_set_mouse_mode(Input.MOUSE_MODE_CAPTURED if _bb.lock_mouse else Input.MOUSE_MODE_VISIBLE)

func _follow_height(delta: float) -> void:
	var target_y := _body.global_position.y
	_smoother.process_smoothing(delta, target_y)
	position.y = _initial_y + _smoother.get_offset(target_y)

func _update_zoom(delta: float) -> void:
	if config.force_first_person or _first_person_forced:
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

	# Snap into first person (only when zoom intent crosses the threshold,
	# not when collision pushes the camera physically close).
	if target_zoom < config.first_person_snap_distance and not _bb.first_person:
		if _model:
			_model.visible = false
		camera.position.z = 0.0
		current_zoom = 0.0
		_set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		_bb.first_person = true

	# Leave first person (smooth zoom out instead of snapping).
	if camera.position.z > config.first_person_snap_distance and _bb.first_person:
		if _model:
			_model.visible = true
		target_zoom = config.first_person_snap_distance
		_set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_bb.first_person = false

	_bb.camera_zoom = current_zoom

func _input(event: InputEvent) -> void:
	if _bb == null or not _bb.input_enabled:
		return
	if _scripted_mode:
		return

	if NetSession.state.mouse_capture_blocked:
		return

	if _awaiting_recapture:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT or event.button_index == MOUSE_BUTTON_RIGHT:
				_set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				_awaiting_recapture = false
		return

	if event is InputEventMouseMotion and (_bb.first_person or _bb.lock_on_character or _bb.lock_mouse):
		rotate_y(deg_to_rad(-event.relative.x * config.mouse_sensitivity))
		x_pivot.rotate_x(deg_to_rad(
			-event.relative.y * config.mouse_sensitivity * config.pitch_sensitivity_multiplier))
		x_pivot.rotation_degrees.x = clampf(
			x_pivot.rotation_degrees.x, config.pitch_min_degrees, config.pitch_max_degrees)

	if config.force_first_person:
		return

	if event.is_action_pressed("wheel_up"):
		target_zoom -= config.zoom_speed

	if event.is_action_pressed("wheel_down"):
		target_zoom += config.zoom_speed

	target_zoom = clampf(target_zoom, 0.0, config.max_zoom)
