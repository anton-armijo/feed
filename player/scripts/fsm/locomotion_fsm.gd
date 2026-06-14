## Finite state machine with FULL authority over locomotion state transitions.
##
## - Child LocomotionState nodes are auto-registered at setup; abilities can
##   plug additional states in at runtime via register_state().
## - Internal transitions come from the active state's physics_update return.
## - External actors (abilities) can only *request* a transition; the FSM
##   validates it through can_exit/can_enter and may refuse.
## - The FSM is the only writer of bb.locomotion_state.
class_name LocomotionFSM
extends Node

signal state_changed(previous: StringName, next: StringName)

@export var initial_state: StringName = &"Idle"

var current: LocomotionState

var _states: Dictionary = {}  # StringName -> LocomotionState
var _body: CharacterBody3D
var _motor: MovementMotor
var _stepper: StairStepper
var _probe: GroundProbe
var _bb: PlayerBlackboard
var _config: PlayerConfig

func setup(
	body: CharacterBody3D,
	motor: MovementMotor,
	stepper: StairStepper,
	probe: GroundProbe,
	bb: PlayerBlackboard,
	config: PlayerConfig
) -> void:
	_body = body
	_motor = motor
	_stepper = stepper
	_probe = probe
	_bb = bb
	_config = config
	for child in get_children():
		if child is LocomotionState:
			register_state(child)

## Registers a state and injects its dependencies. Ability-provided states
## (not yet in the tree) are adopted as children.
func register_state(state: LocomotionState) -> void:
	state.fsm = self
	state.body = _body
	state.motor = _motor
	state.stepper = _stepper
	state.probe = _probe
	state.bb = _bb
	state.config = _config
	if not state.is_inside_tree():
		add_child(state)
	_states[state.state_id()] = state

func unregister_state(id: StringName) -> void:
	if _states.has(id) and current != _states[id]:
		_states.erase(id)

func has_state(id: StringName) -> bool:
	return _states.has(id)

func start() -> void:
	assert(_states.has(initial_state), "LocomotionFSM: missing initial state '%s'" % initial_state)
	current = _states[initial_state]
	current.enter(&"")
	_bb.locomotion_state = current.state_id()

func physics_update(intent: InputIntent, delta: float) -> void:
	if current == null:
		return
	var next := current.physics_update(intent, delta)
	if next != &"" and next != current.state_id():
		_transition_to(next)

## Transition *intent* entry point for abilities and other external systems.
## Returns false if the FSM (or either state) refuses. No external actor can
## force a state change.
func request_transition(id: StringName) -> bool:
	if current == null or not _states.has(id) or id == current.state_id():
		return false
	if not current.can_exit(id):
		return false
	if not _states[id].can_enter(current.state_id()):
		return false
	_transition_to(id)
	return true

func _transition_to(id: StringName) -> void:
	assert(_states.has(id), "LocomotionFSM: unknown state '%s'" % id)
	var previous := current.state_id()
	current.exit(id)
	current = _states[id]
	current.enter(previous)
	_bb.locomotion_state = id
	state_changed.emit(previous, id)
