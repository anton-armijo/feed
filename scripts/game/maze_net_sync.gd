## Project-specific networking layer for the maze (mirrors GameLayer: anything
## game-specific that used to live inside the network core hangs here, not in
## the generic NetSession). It owns the maze parameters and the RPC that
## distributes them, so the networking core stays oblivious to mazes.
##
## Lives in the game scene, so its node path is identical on every peer and the
## RPC resolves correctly. The host configures the maze; the server pushes the
## current config to late joiners; everyone reacts through `maze_received`.
class_name MazeNetSync
extends Node

signal maze_received(width: int, height: int, maze_seed: int)

var configured := false
var width := 20
var height := 20
var maze_seed := 0

func _ready() -> void:
	add_to_group("maze_net_sync")
	NetSession.state.peer_joined.connect(_on_peer_joined)

## Called by the host (size picker) once the maze size is chosen. Applies the
## config locally and broadcasts it to every connected peer.
func configure(new_width: int, new_height: int, new_seed: int) -> void:
	_apply(new_width, new_height, new_seed)
	_rpc_set_maze.rpc(new_width, new_height, new_seed)

func _on_peer_joined(peer_id: int) -> void:
	if multiplayer.is_server() and configured:
		_rpc_set_maze.rpc_id(peer_id, width, height, maze_seed)

func _apply(new_width: int, new_height: int, new_seed: int) -> void:
	width = new_width
	height = new_height
	maze_seed = new_seed
	configured = true
	maze_received.emit(new_width, new_height, new_seed)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_set_maze(new_width: int, new_height: int, new_seed: int) -> void:
	_apply(new_width, new_height, new_seed)
