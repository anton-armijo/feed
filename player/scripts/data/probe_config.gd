## Tuning data for the ground probe raycasts. Pure data.
## Ray lengths are expressed as a fraction of body height; the probe
## multiplies them at setup time.
class_name ProbeConfig
extends Resource

@export_group("Ray Factors")
## Short ray length as a fraction of body height (near-ground suppression).
@export var short_factor := 0.06
## Medium ray length as a fraction of body height (fall-anim blend distance).
@export var medium_factor := 0.17

@export_group("Collision")
@export_flags_3d_physics var collision_mask: int = 1
