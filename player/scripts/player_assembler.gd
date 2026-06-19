## First child of Player. Maintains the runtime-enabled state of every
## optional component and FSM state. No queue_free — nodes stay in the
## tree; Player reads this node's is_enabled() to decide what to wire/tick.
## FSM state toggles are pushed to LocomotionFSM (register/unregister).
##
## Startup values come from PlayerComponentsConfig. Runtime toggling uses
## set_enabled() / toggle() / the ability fachade.
class_name PlayerAssembler
extends Node

var enabled: Dictionary = {}

var _player: Player
var _fsm: LocomotionFSM
var _ability_manager: AbilityManager

func _ready() -> void:
	_player = get_parent()
	if not _player is Player:
		return

	var cfg: PlayerComponentsConfig = null
	if _player.config and _player.config.components:
		cfg = _player.config.components
	if cfg == null:
		cfg = PlayerComponentsConfig.new()

	_fsm = _player.get_node_or_null("LocomotionFSM")
	_ability_manager = _player.get_node_or_null("AbilityManager")

	enabled["InputCollector"]         = cfg.enable_input
	enabled["StairStepper"]           = cfg.enable_stair_stepper
	enabled["CameraRig"]              = cfg.enable_camera
	enabled["Model"]                  = cfg.enable_model
	enabled["WalkSounds"]             = cfg.enable_footsteps
	enabled["AbilityManager"]         = cfg.enable_abilities
	enabled["MultiplayerSynchronizer"] = cfg.enable_multiplayer_sync
	enabled["FSM.Run"]                = cfg.enable_sprint
	enabled["FSM.Jump"]               = cfg.enable_jump
	enabled["FSM.Land"]               = cfg.enable_jump
	enabled["LockOnCharacter"]        = cfg.enable_lock_on_character

# --- Public API ---------------------------------------------------------------

func is_enabled(component: StringName) -> bool:
	return enabled.get(component, true)

func set_enabled(component: StringName, value: bool) -> void:
	if enabled.get(component) == value:
		return
	enabled[component] = value

	if component.begins_with("FSM.") and _fsm:
		var state_name := component.trim_prefix("FSM.")
		if value:
			var node := _fsm.get_node_or_null(state_name)
			if node is LocomotionState:
				_fsm.register_state(node)
		else:
			_fsm.unregister_state(state_name)

func toggle(component: StringName) -> bool:
	set_enabled(component, not is_enabled(component))
	return is_enabled(component)

# --- FSM initial state (called once by Player after fsm.setup()) ---------------

func apply_initial_state() -> void:
	if _fsm == null:
		return
	for key in enabled:
		if key.begins_with("FSM.") and not enabled[key]:
			_fsm.unregister_state(key.trim_prefix("FSM."))

# --- Ability fachade ----------------------------------------------------------

func add_ability(ability: Ability) -> void:
	if _ability_manager:
		_ability_manager.register(ability)

func remove_ability(id: StringName) -> void:
	if _ability_manager:
		_ability_manager.unregister(id)

func enable_ability(id: StringName) -> void:
	if _ability_manager:
		var ability := _ability_manager.get_ability(id)
		if ability:
			ability.enabled = true

func disable_ability(id: StringName) -> void:
	if _ability_manager:
		var ability := _ability_manager.get_ability(id)
		if ability:
			ability.enabled = false

func swap_ability(old_id: StringName, new_ability: Ability) -> void:
	if _ability_manager == null:
		return
	_ability_manager.unregister(old_id)
	_ability_manager.register(new_ability)
