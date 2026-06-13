extends Control

@onready var ip_input: LineEdit = $VBoxContainer/IPInput
@onready var connect_button: Button = $VBoxContainer/ConnectButton
@onready var host_button: Button = $VBoxContainer/HostButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

func _ready() -> void:
	if NetworkManager.is_dedicated_server:
		return

	connect_button.pressed.connect(_on_connect)
	host_button.pressed.connect(_on_host)

	if NetworkManager.last_error != "":
		status_label.text = NetworkManager.last_error
		NetworkManager.last_error = ""

func _on_connect() -> void:
	var ip := ip_input.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"

	connect_button.disabled = true
	host_button.disabled = true

	NetworkManager.connect_ip = ip
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_host() -> void:
	connect_button.disabled = true
	host_button.disabled = true

	NetworkManager.pending_host = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")
