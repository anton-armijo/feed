## Drives animation playback speed based on real player velocity and tracks
## footstep/landing markers by accumulating scaled delta time.
##
## All logic runs in _process with a single delta:
##   1. Compute speed_scale from horizontal_speed / reference_speed, clamped
##   2. animation_tree.advance(delta * speed_scale)
##   3. _anim_clock += delta * speed_scale → check markers → notify blackboard
##
## The AnimationTree is set to ANIMATION_PROCESS_MANUAL — this node is the
## sole driver via advance(). Non-speed-driven states get scale=1.0.
##
## horizontal_speed is smoothed via lerpf to avoid stutter on remote peers
## where the value arrives only on network ticks.
##
## Markers and speed-driven flag are data-driven: each Animation resource in
## the AnimationPlayer carries them as metadata:
##   - "footstep_markers": Array of {time: float, name: StringName}
##   - "speed_driven": bool (default false)
## This keeps the driver character-agnostic — new animations declare their
## own markers instead of editing this script.
class_name AnimationDriver
extends Node

@export var animation_tree: AnimationTree

var blackboard: PlayerBlackboard
var locomotion_config: ResolvedPlayerConfig.Locomotion

## anim_state → Array[{time: float, name: StringName}]. Populated from
## Animation.get_meta("footstep_markers") at setup.
var _marker_config: Dictionary = {}

## anim_state → bool. Populated from Animation.get_meta("speed_driven").
var _speed_driven: Dictionary = {}

## Animation cycle lengths for wrap detection. Populated from the
## AnimationPlayer library at startup.
var _anim_lengths: Dictionary = {}

var _current_anim: StringName = &""
var _anim_clock: float = 0.0
var _speed_scale: float = 1.0
var _smoothed_speed: float = 0.0
var _anim_player: AnimationPlayer
var _triggered_this_cycle: Dictionary = {}


## Called by CharacterPresenter._setup_child_nodes() for auto-discovery.
func presenter_setup(bb: PlayerBlackboard, resolved: ResolvedPlayerConfig) -> void:
	setup(bb, resolved.locomotion)


func setup(p_blackboard: PlayerBlackboard, p_loco: ResolvedPlayerConfig.Locomotion) -> void:
	blackboard = p_blackboard
	locomotion_config = p_loco
	_current_anim = blackboard.anim_state
	blackboard.anim_state_changed.connect(_on_anim_state_changed)

	set_process(true)
	if animation_tree != null:
		animation_tree.process_callback = AnimationTree.ANIMATION_PROCESS_MANUAL
	_cache_anim_player()
	_load_anim_data()


func _cache_anim_player() -> void:
	if animation_tree == null:
		return
	var player_path: NodePath = animation_tree.get("anim_player")
	if player_path.is_empty():
		return
	_anim_player = animation_tree.get_node_or_null(player_path) as AnimationPlayer


## Loads animation lengths, footstep markers and speed-driven flags from the
## AnimationPlayer's libraries. Each Animation resource may carry:
##   - meta "footstep_markers": Array[{time, name}]
##   - meta "speed_driven": bool
func _load_anim_data() -> void:
	if _anim_player == null:
		push_warning("AnimationDriver: AnimationPlayer not found, using no markers/lengths")
		return
	for lib_name in _anim_player.get_animation_library_list():
		var lib := _anim_player.get_animation_library(lib_name)
		if lib == null:
			continue
		for anim_name in lib.get_animation_list():
			var a := lib.get_animation(anim_name)
			if a == null:
				continue
			if a.length > 0.0:
				_anim_lengths[anim_name] = a.length
			var markers: Array = a.get_meta("footstep_markers", [])
			if not markers.is_empty():
				_marker_config[StringName(anim_name)] = markers
			if a.get_meta("speed_driven", false):
				_speed_driven[StringName(anim_name)] = true


func _on_anim_state_changed(anim: StringName) -> void:
	_current_anim = anim
	_anim_clock = 0.0
	_triggered_this_cycle.clear()


# -- speed scaling ----------------------------------------------------------


func _compute_speed_scale() -> float:
	if not _speed_driven.get(_current_anim, false):
		return 1.0

	var cfg := locomotion_config
	if cfg == null:
		return 1.0

	var ref_speed := _reference_speed_for(_current_anim, cfg)
	if ref_speed <= 0.0:
		return 1.0

	var raw := _smoothed_speed / ref_speed
	var clamped := clampf(raw, cfg.min_animation_speed, cfg.max_animation_speed)
	return clamped * cfg.animation_speed_multiplier


func _reference_speed_for(anim: StringName, cfg: ResolvedPlayerConfig.Locomotion) -> float:
	match anim:
		&"walk", &"walk_back":
			return cfg.walk_speed
		&"run":
			return cfg.run_speed
		_:
			return -1.0


# -- main loop --------------------------------------------------------------


func _process(delta: float) -> void:
	if animation_tree == null or blackboard == null:
		return
	if _current_anim.is_empty():
		return

	_smoothed_speed = lerpf(_smoothed_speed, blackboard.horizontal_speed, 15.0 * delta)
	_speed_scale = _compute_speed_scale()
	animation_tree.advance(delta * _speed_scale)

	var markers: Array = _marker_config.get(_current_anim, [])
	if markers.is_empty():
		return

	_anim_clock += delta * _speed_scale
	var length: float = _anim_lengths.get(_current_anim, 1.0)
	if _anim_clock >= length:
		_anim_clock = fmod(_anim_clock, length)
		_triggered_this_cycle.clear()

	for entry: Dictionary in markers:
		var t: float = entry.time
		var mname: StringName = entry.name
		if not _triggered_this_cycle.get(mname, false) and _anim_clock >= t:
			_triggered_this_cycle[mname] = true
			blackboard.notify_footstep(mname)
