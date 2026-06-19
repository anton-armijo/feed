## Base class for modular character abilities (Sprint, Climb, Attack, ...).
## Add a subclass node under AbilityManager and it is live; remove the node
## and the capability is gone. Abilities act exclusively through the injected
## PlayerApi and signal intent — they can never force an FSM transition.
class_name Ability
extends Node

signal activated
signal deactivated

@export var config: AbilityConfig
@export var enabled := true

var api: PlayerApi
var is_active := false

## Identity inside the AbilityManager registry. Defaults to the node name.
func ability_id() -> StringName:
	return name

## Optional FSM states this ability contributes (e.g. Climb provides a
## ClimbState). Registered by the AbilityManager at setup.
func provided_states() -> Array[LocomotionState]:
	return []

func can_activate() -> bool:
	return true

func activate() -> void:
	if is_active or not enabled or not can_activate():
		return
	is_active = true
	_on_activate()
	activated.emit()

func deactivate() -> void:
	if not is_active:
		return
	is_active = false
	_on_deactivate()
	deactivated.emit()

## Called every physics frame (active or not) so abilities can watch intent.
func physics_update(_intent: InputIntent, _delta: float) -> void:
	pass

# --- Subclass hooks -------------------------------------------------------------

func _on_activate() -> void:
	pass

func _on_deactivate() -> void:
	pass
