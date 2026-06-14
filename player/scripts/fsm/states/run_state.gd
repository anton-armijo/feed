## Grounded movement at run speed. Releasing run returns to Walk; the motor
## then decelerates using run_to_walk_deceleration.
class_name RunState
extends GroundedMoveState

func enter(_from: StringName) -> void:
	bb.anim_state = &"run"

func target_speed() -> float:
	return config.locomotion.run_speed

func speed_tier_transition(intent: InputIntent) -> StringName:
	return &"" if intent.run_held else &"Walk"
