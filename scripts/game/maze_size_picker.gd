extends VBoxContainer

@onready var _size_input: LineEdit = $SizeInput
@onready var _confirm_button: Button = $ConfirmButton
@onready var _label: Label = $"../Label"
@onready var _loading_screen: CanvasLayer = $"../.."

var _is_host: bool = false

func _enter_tree() -> void:
	_is_host = NetworkManager.pending_host
	_loading_screen = get_parent().get_parent() as CanvasLayer
	if _is_host:
		_loading_screen.hold()
	else:
		_loading_screen.pre_fade.connect(_on_pre_fade)

func _ready() -> void:
	if _is_host:
		_show_picker()

func _on_pre_fade() -> void:
	if NetworkManager.maze_configured:
		return

	if multiplayer.get_peers().size() <= 1:
		_loading_screen.hold()
		_show_picker()

func _show_picker() -> void:
	_confirm_button.pressed.connect(_on_confirm)
	_size_input.text_submitted.connect(_on_text_submitted)
	visible = true
	_label.visible = false
	_size_input.grab_focus()

func _on_text_submitted(_text: String) -> void:
	_on_confirm()

func _on_confirm() -> void:
	var raw := _size_input.text.strip_edges()
	var size := raw.to_int()
	if size < 5:
		size = 5
	if size > 200:
		size = 200

	var maze_gen := $"../../../MazeGenerator"
	if maze_gen and maze_gen.has_method("regenerate"):
		maze_gen.regenerate(size, size)

	if multiplayer.is_server():
		NetworkManager.maze_configured = true
		NetworkManager.rpc_maze_configured.rpc()
	else:
		NetworkManager.rpc_maze_configured.rpc_id(1)

	visible = false
	_label.visible = true
	_loading_screen.release()
