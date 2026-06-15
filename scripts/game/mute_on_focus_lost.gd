extends AudioStreamPlayer

@export var fade_in_duration: float = 2.0
@export var fade_out_duration: float = 0.5

var _original_volume_db: float
static var silenced_volume_db: float = -80.0
var _volume_tween: Tween

func _ready() -> void:
	_original_volume_db = volume_db

	var loading_screen = get_node_or_null("../LoadingScreen")
	if loading_screen:
		await loading_screen.fade_completed

	volume_db = silenced_volume_db
	play()
	_fade_in()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_fade_out()

		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			_fade_in()

func _fade_in() -> void:
	if _volume_tween:
		_volume_tween.kill()

	_volume_tween = create_tween()

	_volume_tween.tween_property(
		self,
		"volume_db",
		_original_volume_db,
		fade_in_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _fade_out() -> void:
	if _volume_tween:
		_volume_tween.kill()

	_volume_tween = create_tween()

	_volume_tween.tween_property(
		self,
		"volume_db",
		silenced_volume_db,
		fade_out_duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
