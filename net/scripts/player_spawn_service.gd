## Player spawn/despawn service: a MultiplayerSpawner that lives in the game
## scene and reacts ONLY to NetState signals (never raw multiplayer signals or
## the transport). Its single job is to keep one player instance per peer; it
## emits its own signals so game-specific systems (audio, maze sync, HUD) can
## react without this node knowing about them.
##
## It is server-authoritative: only the server actually spawns/despawns; the
## MultiplayerSpawner replicates the instances to every client automatically.
class_name PlayerSpawnService
extends MultiplayerSpawner

signal player_spawned(peer_id: int, player: Node)
signal player_despawned(peer_id: int)

@export var player_scene: PackedScene = load("uid://dxtje6oorvk5e")
@export var spawn_location: Node3D

func _ready() -> void:
	add_to_group("player_spawner")
	spawn_function = _custom_spawn

	var state: NetState = NetSession.state
	state.peer_joined.connect(_on_peer_joined)
	state.peer_left.connect(_on_peer_left)
	state.session_started.connect(_on_session_started)

	# If the host's session is already live (e.g. re-entering), spawn its local
	# player right away. Dedicated servers have no local player.
	if multiplayer.multiplayer_peer and multiplayer.is_server() and not state.is_dedicated() and state.is_online():
		_spawn(multiplayer.get_unique_id())

func _custom_spawn(data: Variant) -> Node:
	var peer_id: int = data
	var player := player_scene.instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	return player

func _spawn(peer_id: int) -> void:
	var player := spawn(peer_id)
	if player:
		player_spawned.emit(peer_id, player)
		print("[PlayerSpawnService] Spawned player peer_id=%d" % peer_id)

func _on_session_started() -> void:
	# Host's own local player (clients receive theirs via replication).
	if multiplayer.is_server() and not NetSession.state.is_dedicated():
		_spawn(multiplayer.get_unique_id())

func _on_peer_joined(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	_spawn(peer_id)

func _on_peer_left(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	var player := spawn_location.get_node_or_null(str(peer_id))
	if player:
		player.queue_free()
		player_despawned.emit(peer_id)
		print("[PlayerSpawnService] Despawned player peer_id=%d" % peer_id)
