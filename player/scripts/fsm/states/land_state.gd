## Transient landing recovery state. Entered only for falls larger than
## JumpConfig.land_anim_min_fall (the Fall state decides). Auto-exits to
## Idle or Walk/Run after land_duration. A buffered jump cancels it early
## (the FSM re-validates the floor before allowing it).
class_name LandState
extends LocomotionState

var _timer := 0.0

func enter(_from: StringName) -> void:
	_timer = 0.0
	bb.anim_state = &"land"

func physics_update(intent: InputIntent, delta: float) -> StringName:
	if not motor.is_grounded():
		return &"Fall"

	# Early cancel: jump intent, validated against the floor state above.
	if intent.has_buffered_jump():
		intent.consume_jump()
		return &"Jump"

	# Movement is not locked during the recovery (matches previous feel).
	motor.move_ground(intent.wish_dir, config.locomotion.walk_speed, delta)

	_timer += delta
	if _timer >= config.jump.land_duration:
		return ground_state(intent)
	return &""
