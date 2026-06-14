## Tuning data for jumping, gravity and landing. Pure data.
class_name JumpConfig
extends Resource

@export_group("Jump")
@export var jump_velocity := 4.2
@export var gravity := 9.81
## Time window after walking off a ledge during which a jump is still allowed.
@export var coyote_time := 0.11
## Time window during which a jump press is remembered before touching ground.
@export var jump_buffer_time := 0.1

@export_group("Landing")
## Duration of the transient Land state before it auto-exits to Idle/Walk.
@export var land_duration := 0.35
## Minimum accumulated fall distance (meters) for the Land state to trigger.
## Falls shorter than this skip Land entirely (Fall -> Idle/Walk).
@export var land_anim_min_fall := 0.30
## Minimum accumulated fall distance (meters) before the "fall" visual shows.
@export var fall_anim_min_fall := 0.80
