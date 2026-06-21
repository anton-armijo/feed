## Physical execution layer: the ONLY writer of body.velocity and the only
## caller of move_and_slide(). Receives data (directions, target speeds) and
## never reads Input. FSM states and abilities drive it through its public API.
##
## Abilities influence speed exclusively through the speed-modifier stack
## (add_speed_modifier / remove_speed_modifier) and gravity through
## set_gravity_enabled(); they never touch velocity directly.
class_name MovementMotor
extends Node

var gravity_enabled := true
## Smoothed scalar speed target (m/s); eases Walk<->Run transitions.
var current_speed := 0.0

var _body: CharacterBody3D
var _bb: PlayerBlackboard
var _stepper: StairStepper
var _loco: ResolvedPlayerConfig.Locomotion
var _jump: ResolvedPlayerConfig.Jump
var _speed_modifiers: Dictionary = {}  # StringName -> float multiplier


func setup(body: CharacterBody3D, bb: PlayerBlackboard, stepper: StairStepper, resolved: ResolvedPlayerConfig) -> void:
	_body = body
	_bb = bb
	_stepper = stepper
	_loco = resolved.locomotion
	_jump = resolved.jump
	current_speed = _loco.walk_speed


# --- Queries ------------------------------------------------------------------


## Physics-grounded: on the floor or in the middle of a stair step-up.
func is_grounded() -> bool:
	return _body.is_on_floor() or (_bb != null and _bb.is_stepping)


## Grounded for presentation purposes (includes stair step-down snapping).
func is_grounded_visual() -> bool:
	return is_grounded() or (_bb != null and _bb.is_stepping_down)


func horizontal_velocity() -> Vector3:
	return Vector3(_body.velocity.x, 0.0, _body.velocity.z)


func speed_multiplier() -> float:
	var multiplier := 1.0
	for value: float in _speed_modifiers.values():
		multiplier *= value
	return multiplier


# --- Ability hooks ------------------------------------------------------------


func add_speed_modifier(id: StringName, multiplier: float) -> void:
	_speed_modifiers[id] = multiplier


func remove_speed_modifier(id: StringName) -> void:
	_speed_modifiers.erase(id)


func set_gravity_enabled(enabled: bool) -> void:
	gravity_enabled = enabled


# --- Movement API (called by FSM states) ---------------------------------------


func move_ground(wish_dir: Vector3, target_speed: float, delta: float) -> void:
	move_ground_damped(wish_dir, target_speed, delta, true)


## Ground move with explicit control over the reverse-velocity damp. The FSM
## passes apply_reverse_damp = bb.is_facing_locked() so the damp only kicks in
## when the model cannot turn toward its wish_dir (backpedaling). Abilities that
## drive motion directly can keep the default (damp on).
func move_ground_damped(
	wish_dir: Vector3, target_speed: float, delta: float, apply_reverse_damp: bool
) -> void:
	_update_current_speed(target_speed * speed_multiplier(), delta)
	_accelerate(wish_dir, _loco.acceleration, delta, apply_reverse_damp)


func move_air(wish_dir: Vector3, target_speed: float, delta: float) -> void:
	move_air_damped(wish_dir, target_speed, delta, true)


## Air move with explicit reverse-damp gate, mirroring move_ground_damped.
func move_air_damped(
	wish_dir: Vector3, target_speed: float, delta: float, apply_reverse_damp: bool
) -> void:
	_update_current_speed(target_speed * speed_multiplier(), delta)
	_accelerate(wish_dir, _loco.acceleration * _loco.air_control, delta, apply_reverse_damp)


func apply_friction(delta: float) -> void:
	var h_vel := horizontal_velocity()
	var rate := _stopping_rate(h_vel.length())
	h_vel = h_vel.move_toward(Vector3.ZERO, rate * delta)
	_body.velocity.x = h_vel.x
	_body.velocity.z = h_vel.z


func apply_gravity(delta: float) -> void:
	if gravity_enabled:
		_body.velocity.y -= _jump.gravity * delta


## Instant vertical impulse (jumping). Overwrites vertical velocity.
func launch_vertical(vertical_speed: float) -> void:
	_body.velocity.y = vertical_speed


## Direct velocity write for ability-provided states (e.g. Climb).
func set_velocity(velocity: Vector3) -> void:
	_body.velocity = velocity


# --- Frame execution (called once per physics frame by Player) -----------------


func physics_step(delta: float) -> void:
	if _stepper != null:
		_stepper.step_up(horizontal_velocity() * delta)
	_body.move_and_slide()
	if _bb != null and _bb.is_stepping:
		_body.apply_floor_snap()
	elif _stepper != null:
		_stepper.step_down()


# --- Internals ------------------------------------------------------------------


func _update_current_speed(target_speed: float, delta: float) -> void:
	# Decelerating toward a lower tier (Run -> Walk) uses its own, snappier rate.
	var rate := (
		_loco.run_to_walk_deceleration if target_speed < current_speed else _loco.acceleration
	)
	current_speed = move_toward(current_speed, target_speed, rate * delta)


func _stopping_rate(speed: float) -> float:
	return _loco.stopping_deceleration if speed > _loco.walk_speed else _loco.friction


func _accelerate(
	wish_dir: Vector3, acceleration: float, delta: float, apply_reverse_damp: bool
) -> void:
	var h_vel := horizontal_velocity()
	if wish_dir != Vector3.ZERO:
		# Damp velocity when reversing direction for a snappier turnaround.
		# Only applied when the model is facing-locked (can't turn toward
		# wish_dir); in free third person the model turns and there is no
		# real "reverse" to damp.
		if apply_reverse_damp and h_vel.dot(wish_dir) < 0.0:
			h_vel *= _loco.reverse_velocity_damp
		h_vel = h_vel.move_toward(wish_dir * current_speed, acceleration * delta)
	else:
		var rate := _stopping_rate(h_vel.length())
		h_vel = h_vel.move_toward(Vector3.ZERO, rate * delta)
	_body.velocity.x = h_vel.x
	_body.velocity.z = h_vel.z
