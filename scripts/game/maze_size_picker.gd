extends VBoxContainer

@onready var _size_input: LineEdit = $SizeInput
@onready var _confirm_button: Button = $ConfirmButton
@onready var _label: Label = $"../Label"
@onready var _loading_screen: CanvasLayer = $"../.."

var _is_server: bool = false

func _enter_tree() -> void:
	_is_server = NetworkManager.pending_host
	_loading_screen = get_parent().get_parent() as CanvasLayer
	if _is_server:
		_loading_screen.hold()

func _ready() -> void:
	if _is_server:
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
	var _size := raw.to_int()
	if _size < 5:
		_size = 5
	if _size > 200:
		_size = 200

	var maze_gen := $"../../../MazeGenerator"
	var mseed := randi()
	if maze_gen and maze_gen.has_method("regenerate"):
		maze_gen.regenerate(_size, _size, mseed)

	NetworkManager.maze_configured = true
	NetworkManager.maze_width = _size
	NetworkManager.maze_height = _size
	NetworkManager.maze_seed = mseed
	NetworkManager.rpc_maze_configured.rpc(_size, _size, mseed)

	visible = false
	_label.visible = true
	_loading_screen.release()
