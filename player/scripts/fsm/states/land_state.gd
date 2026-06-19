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
		return &"Fall" if fsm.has_state(&"Fall") else &""

	# Early cancel: jump intent, validated against the floor state above.
	if intent.has_buffered_jump() and fsm.has_state(&"Jump"):
		intent.consume_jump()
		return &"Jump"

	# Movement is not locked during the recovery (matches previous feel).
	# Backpedaling slows the recovery walk too; reverse-damp is gated by the
	# facing-lock flag just like in GroundedMoveState.
	var facing_locked := bb.is_facing_locked()
	var speed := resolved.locomotion.walk_speed
	if bb.is_backpedaling(intent.wish_dir):
		speed *= resolved.locomotion.backwalk_speed_multiplier
	motor.move_ground_damped(intent.wish_dir, speed, delta, facing_locked)

	_timer += delta
	if _timer >= resolved.jump.land_duration:
		return ground_state(intent)
	return &""
