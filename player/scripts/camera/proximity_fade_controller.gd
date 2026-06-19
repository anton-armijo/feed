## Child of CameraRig. Raycasts from the camera toward each player's
## fade collision areas every physics frame and sets the model fade based
## on the closest distance. Runs locally on every client (each client
## handles the fade of all players it can see, including its own).
##
## The controller is character-agnostic: it uses the "players" group and
## duck-types for a CharacterPresenter + get_fade_areas(). It never imports
## the Player class.
##
## Can be used standalone by exporting the camera and fade_config, or wired
## via setup() by CameraRig/Player.
class_name ProximityFadeController
extends Node

const FADE_LAYER := 128  # collision layer 8 (bit 7) — dedicated fade collision layer

## Camera from which the fade distance is measured. If null, the controller
## attempts to find a Camera3D in its parent CameraRig on _ready.
@export var camera: Camera3D
## Configuration for distances, enabled toggle, and optional area filter.
## If null, the controller remains disabled until setup() is called.
@export var fade_config: ProximityFadeConfig

var _camera: Camera3D
var _config: ProximityFadeConfig
var _enabled: bool = true
var _fade_start: float = 1.5
var _fade_end: float = 0.3
var _checked_areas: Array[StringName] = []
var _space: PhysicsDirectSpaceState3D
var _is_setup := false

func _ready() -> void:
	if camera == null:
		var parent := get_parent()
		if parent is CameraRig:
			camera = parent.camera
	if camera != null and fade_config != null:
		setup(camera, fade_config)

func setup(config_camera: Camera3D, config: ProximityFadeConfig) -> void:
	_camera = config_camera
	if config != null:
		_config = config
		_enabled = config.enabled
		_fade_start = config.fade_start_distance
		_fade_end = config.fade_end_distance
		_checked_areas = config.checked_areas
	_is_setup = true

func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	if not enabled:
		_clear_all_fades()

func _physics_process(_delta: float) -> void:
	if not _enabled or _camera == null:
		return
	_space = _camera.get_world_3d().direct_space_state
	for body in get_tree().get_nodes_in_group("players"):
		_process_player_fade(body)

func _process_player_fade(body: Node) -> void:
	if not body is CharacterBody3D:
		return
	var presenter := _get_presenter(body)
	if presenter == null:
		return
	var areas := _get_areas_to_check(presenter)
	if areas.is_empty():
		presenter.set_fade(0.0)
		return
	var min_dist := _find_min_distance(areas)
	if min_dist < 0.0:
		# No ray hit any area — fully visible.
		presenter.set_fade(0.0)
		return
	var fade := _distance_to_fade(min_dist)
	presenter.set_fade(fade)

## Duck-types for the presenter (node "Model/CharacterScene" under the player).
func _get_presenter(body: Node) -> CharacterPresenter:
	var model := body.get_node_or_null("Model")
	if model == null:
		return null
	return model.get_node_or_null("CharacterScene") as CharacterPresenter

## Returns the Area3D nodes to raycast, filtered by the config's checked_areas
## list (or all Area3D children if the list is empty).
func _get_areas_to_check(presenter: CharacterPresenter) -> Array[Area3D]:
	var all := presenter.get_fade_areas()
	if _checked_areas.is_empty():
		return all
	var filtered: Array[Area3D] = []
	for area in all:
		if area.name in _checked_areas:
			filtered.append(area)
	return filtered

## Raycasts from the camera toward each area's global position and returns the
## minimum hit distance. Returns -1 if no area was hit.
func _find_min_distance(areas: Array[Area3D]) -> float:
	var min_dist: float = -1.0
	var cam_origin := _camera.global_position
	for area in areas:
		var target := area.global_position
		var params := PhysicsRayQueryParameters3D.new()
		params.from = cam_origin
		params.to = target
		params.collision_mask = FADE_LAYER
		params.collide_with_areas = true
		params.collide_with_bodies = false
		params.hit_from_inside = true
		var hit := _space.intersect_ray(params)
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
##   dist >= fade_start → 0 (visible)
##   dist <= fade_end   → 1 (invisible)
##   in between         → lerp
func _distance_to_fade(dist: float) -> float:
	if dist >= _fade_start:
		return 0.0
	if dist <= _fade_end:
		return 1.0
	return 1.0 - inverse_lerp(_fade_end, _fade_start, dist)

## Resets all players' fade to 0 (visible) when the controller is disabled.
func _clear_all_fades() -> void:
	if not is_inside_tree():
		return
	for body in get_tree().get_nodes_in_group("players"):
		if not body is CharacterBody3D:
			continue
		var presenter := _get_presenter(body)
		if presenter != null:
			presenter.set_fade(0.0)
