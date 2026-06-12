extends Node

func request_interact(object: Node, player_id: int) -> void:
	# Futuro: object.sv_interact.rpc_id(SERVER_ID, player_id)
	object.sv_interact(player_id)
