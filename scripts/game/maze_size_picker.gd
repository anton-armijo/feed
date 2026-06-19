extends VBoxContainer

@onready var _size_input: LineEdit = $SizeInput
@onready var _confirm_button: Button = $ConfirmButton
@onready var _label: Label = $"../Label"
@onready var _loading_screen: CanvasLayer = $"../.."

var _is_server: bool = false


func _enter_tree() -> void:
	# Only the host configures the maze. The intent is known before the peer
	# exists, so we read the pending role rather than the (not yet set) role.
	_is_server = NetSession.state.pending_role == NetState.Role.HOST
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
	var size := raw.to_int()
	if size < 5:
		size = 5
	if size > 200:
		size = 200

	# MazeNetSync applies the config locally (its maze_received signal makes the
	# generator rebuild) and replicates it to every connected peer.
	var mseed := randi()
	var maze_sync := get_tree().get_first_node_in_group("maze_net_sync") as MazeNetSync
	if maze_sync:
		maze_sync.configure(size, size, mseed)

	visible = false
	_label.visible = true
	_loading_screen.release()
