extends AudioStreamPlayer

var _original_volume_db: float

func _ready() -> void:
	_original_volume_db = volume_db

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			volume_db = -80.0
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			volume_db = _original_volume_db
