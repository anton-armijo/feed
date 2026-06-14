## Restricted API surface handed to abilities. This is the ONLY way abilities
## are allowed to influence the character:
##   - speed modifiers / gravity toggle on the motor,
##   - transition *requests* to the FSM (which may refuse),
##   - registering ability-provided FSM states,
##   - whitelisted blackboard flags.
## Abilities never get raw access to velocity or the FSM internals.
class_name AbilityContext
extends RefCounted

var blackboard: PlayerBlackboard
## Read access for sensing (raycasts, position). Do not write to it.
var body: CharacterBody3D

var _motor: MovementMotor
var _fsm: LocomotionFSM

func _init(body_ref: CharacterBody3D, motor: MovementMotor, fsm: LocomotionFSM, bb: PlayerBlackboard) -> void:
	body = body_ref
	_motor = motor
	_fsm = fsm
	blackboard = bb

# --- Motor influence ----------------------------------------------------------

func add_speed_modifier(id: StringName, multiplier: float) -> void:
	_motor.add_speed_modifier(id, multiplier)

func remove_speed_modifier(id: StringName) -> void:
	_motor.remove_speed_modifier(id)

func set_gravity_enabled(enabled: bool) -> void:
	_motor.set_gravity_enabled(enabled)

# --- FSM intent (the FSM keeps full authority) ----------------------------------

## Signals the intent to transition. Returns false if the FSM refuses.
func request_state(id: StringName) -> bool:
	return _fsm.request_transition(id)

func current_state() -> StringName:
	return _fsm.current.state_id() if _fsm.current else &""

func register_state(state: LocomotionState) -> void:
	_fsm.register_state(state)

func unregister_state(id: StringName) -> void:
	_fsm.unregister_state(id)

# --- Whitelisted blackboard flags ----------------------------------------------

func set_sprinting(sprinting: bool) -> void:
	blackboard.is_sprinting = sprinting
