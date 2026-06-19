## Base class for locomotion states. States receive injected references
## (references down) and communicate transitions by returning the next state
## id from physics_update, or via the FSM's request/validation API.
##
## States are allowed to:
##   - drive the MovementMotor,
##   - write bb.anim_state (they decide which presentation state fits),
##   - read intent, probes and the stepper.
## States must never call move_and_slide or touch other states.
class_name LocomotionState
extends Node

var fsm: LocomotionFSM
var body: CharacterBody3D
var motor: MovementMotor
var stepper: StairStepper
var probe: GroundProbe
var bb: PlayerBlackboard
var resolved: ResolvedPlayerConfig

## Identity of the state inside the FSM. Defaults to the node name.
func state_id() -> StringName:
	return name

## FSM authority hooks: a transition only happens if the current state agrees
## to exit AND the target state agrees to enter.
func can_enter(_from: StringName) -> bool:
	return true

func can_exit(_to: StringName) -> bool:
	return true

func enter(_from: StringName) -> void:
	pass

func exit(_to: StringName) -> void:
	pass

## Returns the id of the state to transition to, or &"" to stay.
func physics_update(_intent: InputIntent, _delta: float) -> StringName:
	return &""

## Shared helper: presentation state matching the current ground intent.
func ground_anim(intent: InputIntent) -> StringName:
	if intent.wish_dir == Vector3.ZERO:
		return &"idle"
	return &"run" if intent.run_held else &"walk"

## Shared helper: ground state matching the current intent.
func ground_state(intent: InputIntent) -> StringName:
	if intent.wish_dir == Vector3.ZERO:
		return &"Idle"
	return &"Run" if intent.run_held else &"Walk"
