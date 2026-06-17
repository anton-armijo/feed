## Tuning data for ground locomotion. Pure data: no logic, no node references.
class_name LocomotionConfig
extends Resource

@export_group("Speeds")
@export var walk_speed := 3.5
@export var run_speed := 5.5

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

@export_group("Animation Speed")
## Speed scale lower bound: animation never freezes.
@export_range(0.1, 1.0, 0.05) var min_animation_speed := 0.4
## Speed scale upper bound: prevents absurd animation speed.
@export_range(1.0, 3.0, 0.1) var max_animation_speed := 1.8
## Global multiplier applied on top of the computed speed scale.
## < 1.0 slows all speed-driven animations down, > 1.0 speeds them up.
@export_range(0.1, 2.0, 0.05) var animation_speed_multiplier := 1.0
