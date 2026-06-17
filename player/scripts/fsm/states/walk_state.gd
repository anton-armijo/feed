## Grounded movement at walk speed.
class_name WalkState
extends GroundedMoveState

func enter(_from: StringName) -> void:
	bb.anim_state = &"walk"

func target_speed() -> float:
	return config.locomotion.walk_speed

func speed_tier_transition(intent: InputIntent) -> StringName:
	return &"Run" if intent.run_held and fsm.has_state(&"Run") else &""
