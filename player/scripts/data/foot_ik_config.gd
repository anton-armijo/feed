## Tuning data for the procedural foot IK system. Pure data — no logic,
## no node references.
##
## All positions and offsets are derived automatically by [FootIKCalibrator]
## from the [Skeleton3D]; these knobs control *behaviour* and *feel*, not
## geometry. Switching character models requires zero manual retuning —
## only adjust the bone-name overrides in [FootIKController] if the new rig
## uses different naming conventions.
class_name FootIKConfig
extends Resource

## Per-animation influence profiles. Each entry maps an animation name to an
## [IKInfluenceProfile] that drives the foot IK influence over time. Supports
## FOOTSTEP, LAND, CONSTANT, and ZERO modes.
@export var animation_profiles: Array[AnimIKEntry] = []

@export_group("Transitions")
## Lerp speed for influence transitions during normal operation.
@export_range(1.0, 50.0) var normal_lerp_speed := 10.0
## Lerp speed boost when the character just landed.
@export_range(1.0, 50.0) var land_lerp_speed := 25.0
## Lerp speed boost for hard landings (fall_distance > hard_land_distance).
@export_range(10.0, 50.0) var hard_land_lerp_speed := 35.0
## Fall distance (metres) that triggers the hard-land snap.
@export var hard_land_distance := 2.0
## Lerp speed for resetting the visual-container Y offset back to zero.
@export_range(1.0, 30.0) var body_reset_lerp_speed := 15.0
## Lerp speed for the visual-container Y offset when the body needs lowering.
@export_range(1.0, 30.0) var body_lower_lerp_speed := 10.0

@export_group("Foot Rotation")
## If true, feet align to the surface normal via CopyTransformModifier3D.
@export var foot_rotation_enabled := true
## SLERP speed for quaternion smoothing on foot rotation.
@export_range(1.0, 30.0) var foot_rot_slerp_speed := 15.0
## Lerp speed for the CopyTransformModifier3D influence.
@export_range(1.0, 30.0) var foot_rot_lerp_speed := 15.0
## Lerp speed for the target Y position during foot alignment.
@export_range(1.0, 40.0) var foot_rot_y_lerp_speed := 20.0

@export_group("Raycast")
## Weight of the front ray vs. the back ray when both collide (0 = back only, 1 = front only).
@export_range(0.0, 1.0, 0.05) var front_ray_weight := 0.5
## Height of the raycast origin as a fraction of body_height.
@export_range(0.1, 1.0) var ray_origin_height_ratio := 0.4
## Extra ray length below the expected sole position (safety margin).
@export var ray_ground_margin := 0.3
## Collision mask for foot IK raycasts.
@export_flags_3d_physics var ray_collision_mask := 2
## Frames to keep using the last valid hit after a ray loses contact, smoothing
## out the flicker when a foot crosses the edge of a step mid-stride.
@export_range(0, 30) var ray_miss_grace_frames := 5
## When front and back ray Y differ by more than this fraction of sole_offset,
## use the highest hit instead of averaging (prevents target floating between
## steps on stair edges).
@export_range(0.5, 3.0, 0.1) var step_edge_sole_ratio := 1.5

@export_group("Derivation")
## Sole-offset multiplier when climbing UP a slope (1.0 = no change).
@export_range(0.5, 1.5) var sole_offset_up_ratio := 0.95
## Sole-offset multiplier when climbing DOWN a slope.
@export_range(0.5, 1.5) var sole_offset_down_ratio := 0.90
## Slope threshold as a fraction of average leg length.
@export_range(0.0, 0.2) var slope_threshold_ratio := 0.03
## Distance of the pole-knee marker forward of the knee, as a fraction of leg length.
@export_range(0.2, 2.0) var pole_forward_ratio := 0.7
## Extra vertical offset for the pole-knee marker.
@export var pole_y_offset := 0.1
## Foot-length fraction used for the back-ray offset (heel).
@export_range(0.1, 1.0) var ray_back_foot_ratio := 0.45
## Foot-length fraction used for the front-ray offset (toe).
@export_range(0.1, 1.0) var ray_front_foot_ratio := 0.45
