## Composition root of the networking session (mirrors Player / player_base.tscn).
## Owns no networking logic itself: it wires the components together
## ("references down"), exposes the NetState blackboard plus a thin action
## facade, and lets the components report back through NetState signals
## ("signals up").
##
## Autoloaded as `NetSession` (scene autoload) so the whole session lives in a
## single, inspectable .tscn just like the player does.
##
## Component pipeline:
##   NetState          -> single public read surface (the blackboard)
##   NetTransport      -> the only writer of multiplayer.multiplayer_peer
##   SessionController -> lifecycle logic, drives transport + scene flow
##   SceneFlow         -> scene transitions
##   CmdlineBootstrap  -> headless server launch (--server)
##   LeaveInput        -> escape-to-leave gesture
##
## Note: no class_name here — the autoload singleton is already exposed globally
## as `NetSession`, and a matching class_name would shadow it.
extends Node

@export var config: NetConfig

@onready var state: NetState = $NetState
@onready var transport: NetTransport = $NetTransport
@onready var scene_flow: SceneFlow = $SceneFlow
@onready var controller: SessionController = $SessionController
@onready var bootstrap: CmdlineBootstrap = $CmdlineBootstrap
@onready var leave_input: LeaveInput = $LeaveInput

func _ready() -> void:
	if config == null:
		config = NetConfig.new()
	config.ensure_defaults()

	# References down: wire every component from the single composition root.
	transport.setup(state, config)
	scene_flow.setup(config)
	controller.setup(state, transport, scene_flow, config)
	bootstrap.setup(controller, config)
	leave_input.setup(controller, state)

	# Headless server launches straight into the game; otherwise the menu (the
	# project's main scene) is already on screen and waits for user intent.
	# Deferred so any scene change happens after the initial tree is built
	# (changing scenes mid-construction is illegal).
	bootstrap.run.call_deferred()

# --- Action facade (single entry point for UI / game scenes) -----------------

func host_game() -> void:
	controller.host_game()

func join_game(ip: String) -> void:
	controller.join_game(ip)

## Called by the game scene once it is ready to actually create the peer.
func enter_game() -> void:
	controller.enter_game()

func leave() -> void:
	controller.leave()
