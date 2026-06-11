extends Node3D

@export var player_scene: PackedScene = load("res://prefabs/player.tscn")
@export var teto_scene: PackedScene = load("res://prefabs/teto_plush.tscn")
@export var spawn_point := Vector3(0, 0.1, 0)
@export var teto_spawn_point := Vector3(0, 0.1, -8)

func spawn_player(peer_id: int) -> void:
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	player.position = spawn_point
	player.set_multiplayer_authority(peer_id)
	player.peer_id = peer_id

	var teto = teto_scene.instantiate()
	teto.name = "teto_" + str(peer_id)
	teto.owner_id = peer_id
	teto.position = teto_spawn_point

	call_deferred("_deferred_spawn", player, teto)

func _deferred_spawn(player: Node, object: Node) -> void:
	var root = get_parent()
	root.add_child(player)
	root.add_child(object)

	player.watch_object(object)

func _ready() -> void:
	if multiplayer.is_server():
		spawn_player(multiplayer.get_unique_id())

func _process(delta: float) -> void:
	pass
