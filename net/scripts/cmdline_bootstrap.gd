## Bootstrap layer: inspects the command line once at startup and, if the
## dedicated-server flag is present, asks the SessionController to launch a
## headless server (mirrors how InputCollector is just one swappable source of
## intent). On regular launches it does nothing and the menu drives the flow.
class_name CmdlineBootstrap
extends Node

var _session: SessionController
var _config: NetConfig

func setup(session: SessionController, config: NetConfig) -> void:
	_session = session
	_config = config

func run() -> bool:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		args = OS.get_cmdline_args()
	if not args.has(_config.dedicated_server_arg):
		return false
	print("[CmdlineBootstrap] Dedicated server flag detected, starting headless.")
	_session.start_dedicated()
	return true
