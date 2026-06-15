## Tiny game-scene entry point: when the game scene finishes loading it tells
## the session "I'm ready, create the peer now" via NetSession.enter_game().
## This is the single trigger that turns the deferred host/join intent into a
## live connection, keeping that responsibility out of the spawn service.
class_name SessionBootstrap
extends Node

func _ready() -> void:
	NetSession.enter_game()
