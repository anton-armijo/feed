extends Control

@onready var label_level    := $Level
@onready var label_progress := $Percentage

func watch(object_manager: Node) -> void:
	# Estado inicial
	_refresh(object_manager.get_state())
	# Actualizaciones
	object_manager.state_updated.connect(_refresh)

func _refresh(data: LevelData) -> void:
	label_level.text    = str(data.level)
	label_progress.text = str(data.percentage * 100) + "%"
	#progress_bar.value  = data.percentage
