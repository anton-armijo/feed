extends MultiplayerSpawner

@export var player_scene: PackedScene = load("res://prefabs/player_instance.tscn")
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
	spawn_function = _custom_spawn

	if not multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.connect(_on_peer_connected)
	if not multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)

	if multiplayer.is_server() and not NetworkManager.is_dedicated_server:
		spawn_player(multiplayer.get_unique_id())
	elif multiplayer.is_server():
		print("[PlayerSpawner] Servidor dedicado — no se spawnea jugador propio")

func _on_peer_connected(id: int) -> void:
	if not multiplayer.is_server():
		return
	spawn_player(id)

func _on_peer_disconnected(id: int) -> void:
	if not multiplayer.is_server():
		return
	var player_node := spawn_location.get_node_or_null(str(id))
	if player_node:
		player_node.queue_free()
		print("[PlayerSpawner] Jugador eliminado: peer_id=%d" % id)
