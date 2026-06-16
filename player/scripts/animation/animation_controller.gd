## Pure presentation layer: observes blackboard anim_state changes and plays
## the matching AnimationTree state. Contains zero gameplay logic — all
## thresholds and decisions live in the FSM states. Works identically for
## remote players, whose anim_state arrives via the MultiplayerSynchronizer.
class_name AnimationController
extends AnimationTree

var _playback: AnimationNodeStateMachinePlayback
var _bb: PlayerBlackboard

func setup(blackboard: PlayerBlackboard) -> void:
	_bb = blackboard
	_playback = get("parameters/playback")
	assert(_playback != null, \
		"AnimationTree '%s' has no 'parameters/playback'. " % name + \
		"Ensure its root is an AnimationNodeStateMachine.")
	active = true
	_playback.start(_bb.anim_state)
	_bb.anim_state_changed.connect(_on_anim_state_changed)

func _on_anim_state_changed(anim: StringName) -> void:
	_playback.travel(anim)
