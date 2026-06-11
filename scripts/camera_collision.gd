extends Node

@export_flags_3d_physics var collision_mask: int = 1
@export var camera_radius: float = 0.2
@export var return_speed: float = 6.0
@export var approach_speed: float = 12.0

@onready var _ctrl: Node3D = get_parent()
@onready var _pivot: Node3D = _ctrl.get_node("XCameraPivot")
@onready var _cam: Camera3D = _pivot.get_node("Camera3D")
@onready var _pm: Node3D = _ctrl.get_parent().get_node("PlayerManager")

var _tolerance_timer: float = 0.0
var _current_limit: float = INF


func _ready() -> void:
	await get_tree().physics_frame
	_current_limit = _ctrl.target_zoom


func _physics_process(delta: float) -> void:
	var target: float = _ctrl.target_zoom

	if target <= 0.0 or _pm.first_person:
		_current_limit = INF
		_ctrl.collision_zoom_limit = INF
		_tolerance_timer = 0.0
		return

	var pivot_pos: Vector3 = _pivot.global_position
	var desired_cam_world: Vector3 = _pivot.to_global(Vector3(0.0, 0.0, target))

	var space := _pivot.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(pivot_pos, desired_cam_world)
	query.collision_mask = collision_mask
	query.hit_back_faces = false

	var player := _ctrl.get_parent()
	if player is CollisionObject3D:
		query.exclude = [player.get_rid()]

	var result := space.intersect_ray(query)

	if result:
		var hit_dist: float = maxf(pivot_pos.distance_to(result.position) - camera_radius, 0.0)
		var cam_z: float = _cam.position.z

		if hit_dist < cam_z - 0.05:
			_current_limit = move_toward(_current_limit, hit_dist, approach_speed * delta)
	else:
		_tolerance_timer = maxf(_tolerance_timer - delta * 2.0, 0.0)
		_current_limit = move_toward(_current_limit, target, return_speed * delta)

	_current_limit = clampf(_current_limit, 0.0, _ctrl.max_zoom)
	_ctrl.collision_zoom_limit = _current_limit
