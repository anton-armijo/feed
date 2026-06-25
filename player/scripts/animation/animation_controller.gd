## Pure presentation layer: observes blackboard anim_state changes and plays
## the matching AnimationTree state. Contains zero gameplay logic — all
## thresholds and decisions live in the FSM states. Works identically for
## remote players, whose anim_state arrives via the MultiplayerSynchronizer.
##
## Honours anim_state_override: when non-empty, the override is played
## instead of the FSM's anim_state (used by cutscenes/emote abilities via
## PlayerApi).
class_name AnimationController
extends AnimationTree

var _playback: AnimationNodeStateMachinePlayback
var _bb: PlayerBlackboard

## Called by CharacterPresenter._setup_child_nodes() for auto-discovery.
func presenter_setup(bb: PlayerBlackboard, _config: PlayerConfig) -> void:
	setup(bb)


func setup(blackboard: PlayerBlackboard) -> void:
	_bb = blackboard
	_playback = get("parameters/playback")
	assert(_playback != null, \
		"AnimationTree '%s' has no 'parameters/playback'. " % name + \
		"Ensure its root is an AnimationNodeStateMachine.")
	active = true
	_playback.start(_effective_anim())
	_bb.anim_state_changed.connect(_on_anim_changed)
	_bb.anim_state_override_changed.connect(_on_override_changed)

## The animation that should actually play: override if set, else anim_state.
func _effective_anim() -> StringName:
	if not _bb.anim_state_override.is_empty():
		return _bb.anim_state_override
	return _bb.anim_state

func _on_anim_changed(_anim: StringName) -> void:
	if _bb.anim_state_override.is_empty():
		_playback.travel(_bb.anim_state)

func _on_override_changed(anim: StringName) -> void:
	if anim.is_empty():
		_playback.travel(_bb.anim_state)
	else:
		_playback.travel(anim)
