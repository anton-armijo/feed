## Registry and update loop for modular abilities. Child Ability nodes are
## auto-registered at setup; abilities can also be added/removed at runtime.
## The manager hands every ability the same restricted AbilityContext.
class_name AbilityManager
extends Node

signal ability_registered(id: StringName)
signal ability_unregistered(id: StringName)

var _abilities: Dictionary = {}  # StringName -> Ability
var _ctx: AbilityContext

func setup(ctx: AbilityContext) -> void:
	_ctx = ctx
	for child in get_children():
		if child is Ability:
			register(child)

func register(ability: Ability) -> void:
	ability.ctx = _ctx
	if ability.config != null:
		ability.enabled = ability.config.enabled_by_default
	for state in ability.provided_states():
		_ctx.register_state(state)
	if not ability.is_inside_tree():
		add_child(ability)
	_abilities[ability.ability_id()] = ability
	ability_registered.emit(ability.ability_id())

func unregister(id: StringName) -> void:
	var ability: Ability = _abilities.get(id)
	if ability == null:
		return
	ability.deactivate()
	for state in ability.provided_states():
		_ctx.unregister_state(state.state_id())
	_abilities.erase(id)
	ability_unregistered.emit(id)

func get_ability(id: StringName) -> Ability:
	return _abilities.get(id)

func has_ability(id: StringName) -> bool:
	return _abilities.has(id)

## Ticked by the Player coordinator before the FSM each physics frame.
func physics_update(intent: InputIntent, delta: float) -> void:
	for ability: Ability in _abilities.values():
		if ability.enabled:
			ability.physics_update(intent, delta)
