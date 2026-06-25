## Gameplay sensor: short/medium downward raycasts used by the Fall state to
## decide how close the ground is (keep current visuals vs. show the fall
## animation vs. prepare for landing). Pure sensing, no decisions.
class_name GroundProbe
extends Node3D

var _ray_short: RayCast3D
var _ray_medium: RayCast3D

func setup(body: CharacterBody3D, config: ProbeConfig, body_height: float) -> void:
	_ray_short = _make_ray(body, body_height * config.short_factor, config.collision_mask)
	_ray_medium = _make_ray(body, body_height * config.medium_factor, config.collision_mask)

## Ground close enough that airborne visuals should be suppressed entirely.
func is_near_ground_short() -> bool:
	return _ray_short != null and _ray_short.is_colliding()

## Ground close enough that a fall animation should blend back to ground pose.
func is_near_ground_medium() -> bool:
	return _ray_medium != null and _ray_medium.is_colliding()

func _make_ray(body: CharacterBody3D, length: float, collision_mask: int) -> RayCast3D:
	var ray := RayCast3D.new()
	ray.enabled = true
	ray.target_position = Vector3(0.0, -length, 0.0)
	ray.collision_mask = collision_mask
	ray.add_exception(body)
	add_child(ray)
	return ray
