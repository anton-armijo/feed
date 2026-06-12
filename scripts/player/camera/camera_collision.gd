## Prevents the camera from clipping through geometry by limiting the rig's
## zoom distance. Child of CameraRig; reads the rig's config and writes only
## rig.collision_zoom_limit.
extends Node

@onready var _rig: CameraRig = get_parent()

var _current_limit: float = INF

func _ready() -> void:
	await get_tree().physics_frame
	_current_limit = _rig.target_zoom

func _physics_process(delta: float) -> void:
	if _rig.config == null:
		return
	var cfg: CameraConfig = _rig.config
	var target: float = _rig.target_zoom

	if target <= 0.0 or _rig.is_first_person():
		_current_limit = INF
		_rig.collision_zoom_limit = INF
		return

	var pivot: Node3D = _rig.x_pivot
	var pivot_pos: Vector3 = pivot.global_position
	var desired_cam_world: Vector3 = pivot.to_global(Vector3(0.0, 0.0, target))

	var space := pivot.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(pivot_pos, desired_cam_world)
	query.collision_mask = cfg.collision_mask
	query.hit_back_faces = false

	var body := _rig.get_parent()
	if body is CollisionObject3D:
		query.exclude = [body.get_rid()]

	var result := space.intersect_ray(query)

	if result:
		var hit_dist: float = maxf(pivot_pos.distance_to(result.position) - cfg.camera_radius, 0.0)
		if hit_dist < _rig.camera.position.z - 0.05:
			_current_limit = move_toward(_current_limit, hit_dist, cfg.collision_approach_speed * delta)
	else:
		_current_limit = move_toward(_current_limit, target, cfg.collision_return_speed * delta)

	_current_limit = clampf(_current_limit, 0.0, cfg.max_zoom)
	_rig.collision_zoom_limit = _current_limit
