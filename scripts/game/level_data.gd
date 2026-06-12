extends RefCounted
class_name LevelData

var level: int
var progress: int
var required_points: float
var percentage: float
var total_points: int

func _init(p_level: int, p_progress: int, p_required: float, p_percentage: float, p_total: int) -> void:
	level           = p_level
	progress        = p_progress
	required_points = p_required
	percentage      = p_percentage
	total_points    = p_total
