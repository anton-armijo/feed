extends Node3D

@export var short_factor : float = 0.1
@export var medium_factor: float = 0.3

@onready var ray_short : RayCast3D = $RayShort
@onready var ray_medium: RayCast3D = $RayMedium
@onready var manager: Node = $"../../PlayerManager"

func _ready() -> void:
	var body_height: float = manager.body_height
	_configure_ray(ray_short,  body_height * short_factor)
	_configure_ray(ray_medium, body_height * medium_factor)

func _configure_ray(ray: RayCast3D, length: float) -> void:
	ray.enabled = true
	ray.target_position = Vector3(0.0, -length, 0.0)
	ray.collision_mask = 1

func keep_current_anim() -> bool:
	return ray_short.is_colliding() or manager.is_stepping or manager.is_stepping_down

func skip_to_land() -> bool:
	return not ray_short.is_colliding() and ray_medium.is_colliding()
