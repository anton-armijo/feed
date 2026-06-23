## Detects the floor surface below the player using a downward raycast.
## Emits surface_changed when the detected surface_id changes.
## Reads surface_id from the collider's meta (set by FloorSurfaceTag).
## Supports runtime override via override_surface / clear_override.
class_name SurfaceDetector
extends Node

signal surface_changed(surface_id: StringName)

@export var ray_length: float = 0.5
@export var update_interval: float = 0.1

var current_surface_id: StringName = &"default"
var _player: CharacterBody3D
var _override_surface_id: StringName = &""
var _has_override: bool = false
var _timer: float = 0.0

func setup(player: CharacterBody3D) -> void:
	_player = player

func get_effective_surface_id() -> StringName:
	return _override_surface_id if _has_override else current_surface_id

func override_surface(surface_id: StringName) -> void:
	_override_surface_id = surface_id
	_has_override = true

func clear_override() -> void:
	_has_override = false

func _process(delta: float) -> void:
	_timer += delta
	if _timer < update_interval:
		return
	_timer = 0.0
	_detect_surface()

func _detect_surface() -> void:
	if not is_instance_valid(_player) or not _player.is_inside_tree():
		return

	var space := _player.get_world_3d().direct_space_state
	if space == null:
		return

	var from := _player.global_position + Vector3.UP * 0.05
	var to := _player.global_position + Vector3.DOWN * ray_length

	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var result := space.intersect_ray(query)
	if result.is_empty():
		_set_surface(&"default")
		return

	var collider := result.get("collider") as Node
	if not is_instance_valid(collider):
		_set_surface(&"default")
		return

	var detected: StringName = &"default"
	if collider.has_meta(&"surface_id"):
		detected = collider.get_meta(&"surface_id")

	_set_surface(detected)

func _set_surface(id: StringName) -> void:
	if _has_override:
		current_surface_id = _override_surface_id
		return
	if current_surface_id != id:
		current_surface_id = id
		surface_changed.emit(id)
