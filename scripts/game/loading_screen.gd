extends CanvasLayer

@export var delay := 1.5
@export var fade_duration := 0.5

func _ready() -> void:
	if NetworkManager.is_dedicated_server:
		queue_free()
		return

	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(_fade_out)

func _fade_out() -> void:
	var rect: ColorRect = $ColorRect
	var tween := create_tween()
	tween.tween_property(rect, "color:a", 0.0, fade_duration)
	tween.tween_callback(queue_free)
