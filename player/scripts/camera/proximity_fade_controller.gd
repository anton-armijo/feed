## Child of CharacterPresenter. Manages the fade for ONE character:
## raycasts from the active camera toward this character's fade collision
## areas every physics frame and sets the model fade based on the closest
## distance.
##
## The controller is character-agnostic: it receives a CharacterPresenter
## via setup() and duck-types for get_fade_areas(). It never imports the
## Player class.
class_name ProximityFadeController
extends Node

const FADE_LAYER := 128  # collision layer 8 (bit 7) — dedicated fade collision layer

var _presenter: CharacterPresenter
var _config: ProximityFadeConfig
var _enabled: bool = true
var _fade_start: float = 1.5
var _fade_end: float = 0.3
var _checked_areas: Array[StringName] = []


func setup(presenter: CharacterPresenter, config: ProximityFadeConfig) -> void:
	_presenter = presenter
	if config != null:
		_config = config
		_enabled = config.enabled
		_fade_start = config.fade_start_distance
		_fade_end = config.fade_end_distance
		_checked_areas = config.checked_areas


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled and _presenter != null:
		_presenter.set_fade(0.0)


func _physics_process(_delta: float) -> void:
	if not _enabled or _presenter == null:
		return
	var camera := _get_camera()
	if camera == null:
		return
	var space := camera.get_world_3d().direct_space_state
	var areas := _get_areas_to_check()
	if areas.is_empty():
		_presenter.set_fade(0.0)
		return
	var min_dist := _find_min_distance(camera, space, areas)
	if min_dist < 0.0:
		_presenter.set_fade(0.0)
		return
	var fade := _distance_to_fade(min_dist)
	_presenter.set_fade(fade)


func _get_camera() -> Camera3D:
	var viewport := get_viewport()
	if viewport == null:
		return null
	return viewport.get_camera_3d()


## Returns the Area3D nodes to raycast, filtered by the config's checked_areas
## list (or all Area3D children if the list is empty).
func _get_areas_to_check() -> Array[Area3D]:
	var all := _presenter.get_fade_areas()
	if _checked_areas.is_empty():
		return all
	var filtered: Array[Area3D] = []
	for area in all:
		if area.name in _checked_areas:
			filtered.append(area)
	return filtered


## Raycasts from the camera toward each area's global position and returns the
## minimum hit distance. Returns -1 if no area was hit.
func _find_min_distance(camera: Camera3D, space: PhysicsDirectSpaceState3D, areas: Array[Area3D]) -> float:
	var min_dist: float = -1.0
	var cam_origin := camera.global_position
	for area in areas:
		var target := area.global_position
		var params := PhysicsRayQueryParameters3D.new()
		params.from = cam_origin
		params.to = target
		params.collision_mask = FADE_LAYER
		params.collide_with_areas = true
		params.collide_with_bodies = false
		params.hit_from_inside = true
		var hit := space.intersect_ray(params)
		var dist: float
		if hit and hit.has("position") and hit.collider in areas:
			dist = cam_origin.distance_to(hit["position"])
		else:
			# Camera may be inside the area (e.g. first person / close zoom),
			# or the ray hit another player's fade area. Fall back to direct
			# distance so the model still fades based on its own proximity.
			dist = cam_origin.distance_to(target)
		if min_dist < 0.0 or dist < min_dist:
			min_dist = dist
	return min_dist


## Maps a distance to a fade amount:
##   dist >= fade_start -> 0 (visible)
##   dist <= fade_end   -> 1 (invisible)
##   in between         -> lerp
func _distance_to_fade(dist: float) -> float:
	if dist >= _fade_start:
		return 0.0
	if dist <= _fade_end:
		return 1.0
	return 1.0 - inverse_lerp(_fade_end, _fade_start, dist)
