@tool
class_name FloorSurfaceTag
extends Node

@export var surface_id: StringName = &"default":
	set(value):
		surface_id = value
		_apply()

func _ready() -> void:
	_apply()

func _apply() -> void:
	var parent := get_parent()
	if parent:
		parent.set_meta(&"surface_id", surface_id)
