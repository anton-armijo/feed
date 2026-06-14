## Tuning data for ground locomotion. Pure data: no logic, no node references.
class_name LocomotionConfig
extends Resource

@export_group("Speeds")
@export var walk_speed := 4.5
@export var run_speed := 7.5

@export_group("Acceleration")
@export var acceleration := 25.0
@export var friction := 30.0
## Deceleration rate used when the speed target drops (e.g. Run -> Walk).
@export var run_to_walk_deceleration := 40.0
## Higher deceleration applied when stopping from speeds above walk_speed.
@export var stopping_deceleration := 60.0
## Multiplier applied to current velocity when the player reverses direction.
@export_range(0.0, 1.0) var reverse_velocity_damp := 0.5
## 1.0 = full control in the air, 0.0 = no air control.
@export_range(0.0, 1.0) var air_control := 1.0

@export_group("Visuals")
## How fast the model rotates toward the move direction (rad-lerp factor).
@export var model_turn_speed := 12.0
