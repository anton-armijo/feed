## Grounded movement at run speed. Releasing run returns to Walk; the motor
## then decelerates using run_to_walk_deceleration. Backpedaling also forces
## Walk (no sprinting backwards when the facing is locked to the camera).
class_name RunState
extends GroundedMoveState


func enter(_from: StringName) -> void:
	bb.anim_state = &"run"


func target_speed() -> float:
	return resolved.locomotion.run_speed


func speed_tier_transition(intent: InputIntent) -> StringName:
	if not intent.run_held or bb.is_backpedaling(intent.wish_dir):
		return &"Walk"
	return &""
