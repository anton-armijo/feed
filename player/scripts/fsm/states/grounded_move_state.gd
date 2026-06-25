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


## Target speed adjusted for backpedaling: when the facing is locked to the
## camera and the character moves into the rear semi-plane, it walks slower
## and cannot sprint. Subclasses' speed_tier_transition() already block the
## Run upgrade while backpedaling; this scales the actual speed used by the
## motor for the current frame.
func _backwalk_target_speed(intent: InputIntent) -> float:
	var speed := target_speed()
	if bb.is_backpedaling(intent.wish_dir):
		speed *= config.locomotion.backwalk_speed_multiplier
	return speed


func physics_update(intent: InputIntent, delta: float) -> StringName:
	if not motor.is_grounded():
		return &"Fall" if fsm.has_state(&"Fall") else &""

	if intent.has_buffered_jump() and fsm.has_state(&"Jump"):
		intent.consume_jump()
		return &"Jump"

	var facing_locked := bb.is_facing_locked()
	motor.move_ground_damped(intent.wish_dir, _backwalk_target_speed(intent), delta, facing_locked)

	# Directional anim variant (e.g. walk_back) is resolved against the set the
	# presenter advertised. Setter guards on equality, so this is cheap.
	bb.anim_state = bb.resolve_anim(ground_anim(intent), intent.wish_dir)

	if intent.wish_dir == Vector3.ZERO:
		return &"Idle"
	return speed_tier_transition(intent)
