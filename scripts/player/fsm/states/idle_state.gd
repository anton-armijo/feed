## Grounded, no movement intent. Friction brings the body to a stop.
class_name IdleState
extends LocomotionState

func enter(_from: StringName) -> void:
	bb.anim_state = &"idle"

func physics_update(intent: InputIntent, delta: float) -> StringName:
	if not motor.is_grounded():
		return &"Fall"

	# FSM validates the jump: we are grounded here, so a buffered press is valid.
	if intent.has_buffered_jump():
		intent.consume_jump()
		return &"Jump"

	motor.apply_friction(delta)

	if intent.wish_dir != Vector3.ZERO:
		return &"Run" if intent.run_held else &"Walk"
	return &""
