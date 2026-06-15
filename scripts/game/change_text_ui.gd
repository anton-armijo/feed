extends Control

@export var seconds_to_change: int = 7
@export var old_text: String = "Find the Teto • Press Shift to run. Esc (twice) to exit"
@export var new_text: String = "Find the Teto"

@onready var label: Label = $Label

func _ready() -> void:
	label.text = old_text
	
	var loading_screen = get_node("../LoadingScreen")
	if loading_screen:
		await loading_screen.fade_completed
	
	await get_tree().create_timer(seconds_to_change).timeout
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	
	await tween.finished
	label.text = new_text
	
	var tween2 := create_tween()
	tween2.tween_property(label, "modulate:a", 1.0, 0.5)
