extends MultiplayerSpawner

@export var player_scene: PackedScene = load("res://prefabs/player_instance.tscn")
@export var spawn_location: Node3D

func spawn_player(peer_id: int):
	var player = player_scene.instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)
	spawn_location.add_child(player)

func _ready() -> void:
	if multiplayer.is_server():
		spawn_player(get_multiplayer_authority())
