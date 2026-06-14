extends MultiplayerSpawner

@export var player_scene: PackedScene = load("uid://dxtje6oorvk5e")
@export var spawn_location: Node3D

func _custom_spawn(data: Variant) -> Node:
	var peer_id: int = data
	var player := player_scene.instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	return player

func spawn_player(peer_id: int) -> void:
	spawn(peer_id)
	print("[PlayerSpawner] Jugador spawneado: peer_id=%d" % peer_id)

func _ready() -> void:
	add_to_group("player_spawner")
	spawn_function = _custom_spawn

	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.connect(_on_server_disconnected)

	var loading_screen := get_node("../LoadingScreen") as CanvasLayer
	NetworkManager._on_game_scene_loaded(loading_screen)

	if not multiplayer.multiplayer_peer:
		return

	if multiplayer.is_server() and not NetworkManager.is_dedicated_server:
		spawn_player(multiplayer.get_unique_id())

func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	spawn_player(id)
	if NetworkManager.maze_configured:
		NetworkManager.rpc_maze_configured.rpc_id(id, NetworkManager.maze_width, NetworkManager.maze_height, NetworkManager.maze_seed)

func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var player_node := spawn_location.get_node_or_null(str(id))
	if player_node:
		player_node.queue_free()
		print("[PlayerSpawner] Jugador eliminado: peer_id=%d" % id)

func _on_server_disconnected() -> void:
	if multiplayer.server_disconnected.is_connected(_on_server_disconnected):
		multiplayer.server_disconnected.disconnect(_on_server_disconnected)
	NetworkManager.last_error = "Desconectado del servidor"
	NetworkManager.cleanup_peer()
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
