## Shared behavior for grounded movement states (Walk, Run). Subclasses only
## define their target speed and their speed-tier transition, which keeps Run
## a distinct FSM state (1:1 animation mapping, own transition tuning, single
## synced enum) without duplicating movement code.
class_name GroundedMoveState
extends LocomotionState

func target_speed() -> float:
	return config.locomotion.walk_speed

## Walk -> Run / Run -> Walk decisions live in the subclasses.
func speed_tier_transition(_intent: InputIntent) -> StringName:
	return &""

func physics_update(intent: InputIntent, delta: float) -> StringName:
	if not motor.is_grounded():
		return &"Fall"

	# FSM validates the jump: grounded confirmed above, intent only signals.
	if intent.has_buffered_jump():
		intent.consume_jump()
		return &"Jump"

	motor.move_ground(intent.wish_dir, target_speed(), delta)

	if intent.wish_dir == Vector3.ZERO:
		return &"Idle"
	return speed_tier_transition(intent)
