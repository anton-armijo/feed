## Configuration for the proximity-based model fade. Lives in
## PlayerConfig.extras; the ProximityFadeController searches for it during
## setup(). Pure data.
class_name ProximityFadeConfig
extends Resource

@export_group("Distances")
## Distance (m) at which the model starts to fade. Beyond this, fully visible.
@export var fade_start_distance: float = 0.4
## Distance (m) at which the model is fully invisible. Must be < fade_start.
@export var fade_end_distance: float = 0.1

@export_group("Areas")
## Names of the Area3D nodes (under the presenter) to raycast for distance.
## If empty, all Area3D children of the presenter are checked.
@export var checked_areas: Array[StringName] = []

@export_group("Toggle")
@export var enabled: bool = true
