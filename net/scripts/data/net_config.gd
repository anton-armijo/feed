## Aggregate configuration for the networking session. The NetSession
## composition root owns one of these and injects it into every component that
## needs tuning data. Pure data, no logic (mirrors PlayerConfig).
class_name NetConfig
extends Resource

@export_group("Transport")
@export var port := 4242
@export var default_ip := "127.0.0.1"
## Seconds a client waits for the server before giving up.
@export var connect_timeout := 5.0
@export var max_clients := 32

@export_group("Scene Flow")
## Scene shown when offline / after leaving a session.
@export var menu_scene: PackedScene
## Scene loaded to play (hosts, clients and dedicated servers all load this).
@export var game_scene: PackedScene

@export_group("Bootstrap")
## Command line flag that launches the process as a dedicated server.
@export var dedicated_server_arg := "--server"

## Guarantees the optional fields are usable so components never null-check.
func ensure_defaults() -> void:
	if port <= 0:
		port = 4242
	if default_ip.is_empty():
		default_ip = "127.0.0.1"
	if connect_timeout <= 0.0:
		connect_timeout = 5.0
	if max_clients <= 0:
		max_clients = 32
