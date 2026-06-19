## Ability that toggles lock_on_character (the model locks to the camera
## facing, enabling backpedaling). Bound to the "shift_lock" input action
## (F3 by default). Opt-in via PlayerComponentsConfig.enable_lock_on_character;
## when disabled, lock_on_character can still be set via PlayerApi.
##
## This is a presentation/movement-mode ability, not a state provider: it
## provides no FSM states, it only toggles the blackboard flag.
class_name LockOnCharacterAbility
extends Ability

var _toggled := false


func ability_id() -> StringName:
	return &"LockOnCharacter"


func provided_states() -> Array[LocomotionState]:
	return []


func physics_update(_intent: InputIntent, _delta: float) -> void:
	if Input.is_action_just_pressed("shift_lock"):
		_toggled = not _toggled
		api.blackboard().lock_on_character = _toggled
		if _toggled:
			activate()
		else:
			deactivate()


func _on_activate() -> void:
	_toggled = true


func _on_deactivate() -> void:
	_toggled = false
	api.blackboard().lock_on_character = false
