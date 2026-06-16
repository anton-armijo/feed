## Main menu: a pure observer of the networking session. It never touches the
## transport directly; it calls the NetSession action facade and reads/clears
## the last error from the NetState blackboard.
extends Control

@onready var ip_input: LineEdit = $VBoxContainer/IPInput
@onready var connect_button: Button = $VBoxContainer/ConnectButton
@onready var host_button: Button = $VBoxContainer/HostButton
@onready var status_label: Label = $VBoxContainer/StatusLabel

func _ready() -> void:
	if NetSession.state.is_dedicated():
		return

	connect_button.pressed.connect(_on_connect)
	host_button.pressed.connect(_on_host)

	if NetSession.state.last_error != "":
		status_label.text = NetSession.state.last_error
		NetSession.state.last_error = ""

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()

func _on_connect() -> void:
	var ip := ip_input.text.strip_edges()
	_lock_buttons()
	NetSession.join_game(ip)

func _on_host() -> void:
	_lock_buttons()
	NetSession.host_game()

func _lock_buttons() -> void:
	connect_button.disabled = true
	host_button.disabled = true
