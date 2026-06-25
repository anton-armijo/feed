## Grounded movement at walk speed.
class_name WalkState
extends GroundedMoveState


func enter(_from: StringName) -> void:
	bb.anim_state = &"walk"


func target_speed() -> float:
	return config.locomotion.walk_speed


func speed_tier_transition(intent: InputIntent) -> StringName:
	# Cannot start sprinting while backpedaling (facing locked to the camera and
	# moving into the rear semi-plane).
	if intent.run_held and not bb.is_backpedaling(intent.wish_dir) and fsm.has_state(&"Run"):
		return &"Run"
	return &""
