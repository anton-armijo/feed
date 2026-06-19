## Ascending phase of a jump. Entering this state IS the jump: callers (Idle,
## Walk, Run, Fall-with-coyote, Land) have already validated floor/coyote, so
## enter() applies the impulse. Exits to Fall at the apex.
class_name JumpState
extends LocomotionState


func enter(_from: StringName) -> void:
	motor.launch_vertical(resolved.jump.jump_velocity)
	bb.anim_state = &"jump"
	bb.notify_jumped()
	bb.air_time = 0.0


func physics_update(intent: InputIntent, delta: float) -> StringName:
	motor.apply_gravity(delta)
	motor.move_air_damped(intent.wish_dir, _air_target_speed(intent), delta, bb.is_facing_locked())
	bb.air_time += delta

	if body.velocity.y <= 0.0:
		return &"Fall"
	return &""


func _air_target_speed(intent: InputIntent) -> float:
	return resolved.locomotion.run_speed if intent.run_held else resolved.locomotion.walk_speed
