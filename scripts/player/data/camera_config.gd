## Tuning data for the orbit camera rig. Pure data.
class_name CameraConfig
extends Resource

@export_group("Look")
@export var mouse_sensitivity := 0.5
@export var pitch_max_degrees := 50.0
@export var pitch_min_degrees := -85.0
## Vertical sensitivity multiplier relative to horizontal.
@export var pitch_sensitivity_multiplier := 0.4

@export_group("Zoom")
@export var zoom_speed := 0.5
@export var max_zoom := 10.0
## Below this camera distance the rig snaps into first person.
@export var first_person_snap_distance := 0.22
@export var zoom_lerp_speed := 10.0

@export_group("Smoothing")
## Vertical follow smoothing (stair steps, etc.).
@export var height_smooth_speed := 14.0

@export_group("Collision")
@export_flags_3d_physics var collision_mask: int = 1
@export var camera_radius := 0.2
@export var collision_return_speed := 6.0
@export var collision_approach_speed := 12.0
