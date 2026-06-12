## Project-specific layer for "feed your teto". Everything game-specific that
## used to live inside the core controller (UI hookups, interaction, audio)
## hangs under this node. It is local-only: freed on non-authority peers.
class_name GameLayer
extends Node

@onready var ui: Control = $ui

func _ready() -> void:
	if not is_multiplayer_authority():
		queue_free()

## Hook for game systems that want the local UI to observe an object manager.
func watch_object(object_manager: Node) -> void:
	ui.watch(object_manager)
