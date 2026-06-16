## Tracks animation time by accumulating delta frames for the active animation
## state and emits footstep markers when pre-configured threshold times are
## crossed. Uses delta accumulation (not AnimationTree.get) for reliability.
##
## Plain Node with set_process(true) ensures _process always runs.
## Blackboard wiring is lazy: connects on the first _process frame after
## player.gd sets the blackboard export (which happens after _ready).
class_name AnimationNotifier
extends Node

@export var animation_tree: AnimationTree
@export var blackboard: PlayerBlackboard

## anim_state → [{time: float, name: StringName}]
var _marker_config: Dictionary = {
	&"walk": [
		{time = 0.1069, name = &"step_1"},
		{time = 0.4746, name = &"step_2"},
	],
	&"run": [
		{time = 0.0667, name = &"step_1"},
		{time = 0.3500, name = &"step_2"},
	],
	&"land": [
		{time = 0.1013, name = &"landed"},
	],
}

## Animation cycle lengths for wrap detection. Read from the AnimationPlayer's
## library at startup if available; otherwise fall back to these estimates.
var _anim_lengths: Dictionary = {
	"walk": 0.95,
	"run":  0.67,
	"land": 0.35,
}

var _current_anim: StringName = &""
var _anim_clock: float = 0.0
var _triggered_this_cycle: Dictionary = {}
var _wired: bool = false

func _ready() -> void:
	set_process(true)
	_load_anim_lengths()

func _load_anim_lengths() -> void:
	if animation_tree == null:
		return
	var player_path: NodePath = animation_tree.get("anim_player")
	if player_path.is_empty():
		return
	var ap: AnimationPlayer = animation_tree.get_node_or_null(player_path) as AnimationPlayer
	if ap == null:
		return
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		if lib == null:
			continue
		for anim_name in _anim_lengths:
			if lib.has_animation(anim_name):
				var a := lib.get_animation(anim_name)
				if a != null and a.length > 0.0:
					_anim_lengths[anim_name] = a.length

func _wire_blackboard() -> void:
	if _wired or blackboard == null:
		return
	_wired = true
	_current_anim = blackboard.anim_state
	blackboard.anim_state_changed.connect(_on_anim_state_changed)

func _on_anim_state_changed(anim: StringName) -> void:
	_current_anim = anim
	_anim_clock = 0.0
	_triggered_this_cycle.clear()

func _process(delta: float) -> void:
	_wire_blackboard()

	if animation_tree == null or blackboard == null:
		return
	if _current_anim.is_empty():
		return

	var markers: Array = _marker_config.get(_current_anim, [])
	if markers.is_empty():
		return

	_anim_clock += delta
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
