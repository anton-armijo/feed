## Reusable base class for game-specific orchestration. Any Node that should
## only exist on the local peer extends this and overrides _setup(). All game-
## specific wiring (UI hookups, scene components, audio) happens in _setup().
##
## This is the project-level analogue of Player.setup() and NetSession: a
## single entry point for authority-gated initialization.
class_name GameLayer
extends Node

## True when this node belongs to the local player's authority peer.
var is_authority := false

func _ready() -> void:
	is_authority = is_multiplayer_authority()
	if not is_authority:
		queue_free()
		return
	_setup()

## Override in subclasses. Called after the local-authority check passes,
## before the first frame. Wire children, connect signals, read configs here.
func _setup() -> void:
	pass
