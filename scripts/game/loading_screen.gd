extends CanvasLayer

@export var delay := 1.5
@export var fade_duration := 0.5

var _label: Label = null
var _fade_timer: SceneTreeTimer = null

func _ready() -> void:
	if NetworkManager.is_dedicated_server:
		queue_free()
		return

	_label = $ColorRect/Label

func set_status(text: String) -> void:
	if _label:
		_label.text = text

func start_fade_out() -> void:
	if _fade_timer:
		return
	_fade_timer = get_tree().create_timer(delay)
	_fade_timer.timeout.connect(_fade_out)

func _fade_out() -> void:
	var rect: ColorRect = $ColorRect
	var tween := create_tween()
	tween.tween_property(rect, "color:a", 0.0, fade_duration)
	tween.tween_callback(queue_free)
