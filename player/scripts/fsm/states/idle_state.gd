## Grounded, no movement intent. Friction brings the body to a stop.
class_name IdleState
extends LocomotionState

func enter(_from: StringName) -> void:
	bb.anim_state = &"idle"

func physics_update(intent: InputIntent, delta: float) -> StringName:
	if not motor.is_grounded():
		return &"Fall" if fsm.has_state(&"Fall") else &""

	if intent.has_buffered_jump() and fsm.has_state(&"Jump"):
		intent.consume_jump()
		return &"Jump"

	motor.apply_friction(delta)

	if intent.wish_dir != Vector3.ZERO:
		if intent.run_held and fsm.has_state(&"Run"):
			return &"Run"
		return &"Walk"
	return &""
