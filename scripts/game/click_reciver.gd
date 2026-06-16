extends Area3D

signal interacted(player_id: int)

func sv_interact(player_id: int) -> void:
	interacted.emit(player_id)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_interact(player_id: int) -> void:
	if multiplayer.is_server():
		sv_interact(player_id)
