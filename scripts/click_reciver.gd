extends Area3D

@onready var teto_manager = get_parent()

func _ready():
	pass

func on_interacted(player):
	teto_manager.on_click(player)

func sv_interact(player_id: int) -> void:
	teto_manager.sv_interact(player_id)
