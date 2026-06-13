## Project-specific layer for "feed your teto". Everything game-specific that
## used to live inside the core controller (UI hookups, interaction, audio)
## hangs under this node. It is local-only: freed on non-authority peers.
class_name GameLayer
extends Node

func _ready() -> void:
	if not is_multiplayer_authority():
		queue_free()
