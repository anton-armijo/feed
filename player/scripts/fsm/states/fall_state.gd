## Airborne with non-positive vertical velocity. Owns:
##   - gravity and air control,
##   - the coyote-time window (only when the fall started from the ground),
##   - fall-distance accumulation,
##   - the landing decision (transient Land vs. direct return to ground states),
##   - airborne presentation choice (via GroundProbe), so the animation layer
##     stays a dumb state->clip mapping.
class_name FallState
extends LocomotionState

const _GROUND_STATES: Array[StringName] = [&"Idle", &"Walk", &"Run", &"Land"]

var _coyote := 0.0
var _fall_distance := 0.0
var _from_jump := false

func enter(from: StringName) -> void:
	_fall_distance = 0.0
	_from_jump = from == &"Jump"
	if not _from_jump:
		bb.air_time = 0.0
	# Coyote only applies when walking off ground, never after a jump.
	_coyote = config.jump.coyote_time if from in _GROUND_STATES else 0.0

func physics_update(intent: InputIntent, delta: float) -> StringName:
	motor.apply_gravity(delta)
	motor.move_air(intent.wish_dir, _air_target_speed(intent), delta)

	_coyote = maxf(_coyote - delta, 0.0)
	bb.air_time += delta
	if body.velocity.y < 0.0:
		_fall_distance += -body.velocity.y * delta

	# Landing: FSM decides whether the Land state is worth entering.
	if motor.is_grounded() and body.velocity.y <= 0.0:
		bb.notify_landed(_fall_distance)
		bb.air_time = 0.0
		if _fall_distance >= config.jump.land_anim_min_fall and fsm.has_state(&"Land"):
			return &"Land"
		return ground_state(intent)  # trivial fall: skip Land entirely

	# Coyote jump: intent only signals; the FSM validates the window here.
	if intent.has_buffered_jump() and _coyote > 0.0 and body.velocity.y <= 0.0 \
		and fsm.has_state(&"Jump"):
		intent.consume_jump()
		return &"Jump"

	_update_anim(intent)
	return &""

func _air_target_speed(intent: InputIntent) -> float:
	return config.locomotion.run_speed if intent.run_held else config.locomotion.walk_speed

## Presentation decision for the airborne phase. Keeps ground visuals during
## micro-falls (stairs, slopes) and blends back to a ground pose right before
## touchdown, matching the previous controller's feel.
func _update_anim(intent: InputIntent) -> void:
	if stepper != null and (stepper.is_stepping or stepper.is_stepping_down):
		return  # stair adjustment, keep current visuals
	if body.velocity.y > 0.1:
		bb.anim_state = &"jump"  # ascending (external impulse)
		return
	if probe.is_near_ground_short():
		return  # about to touch down, keep current visuals
	if bb.anim_state == &"fall" and probe.is_near_ground_medium():
		bb.anim_state = ground_anim(intent)  # pre-land blend
		return
	if _from_jump or _fall_distance >= config.jump.fall_anim_min_fall:
		bb.anim_state = &"fall"
