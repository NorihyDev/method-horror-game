class_name OnlineFlow
extends Node
## One multiplayer session on this device: an online room (lobby service +
## dedicated server) or a LAN development session. Translates network events
## into screen changes and owns cleanup.

signal status_changed(text_key: String)
signal begun

enum Kind { ONLINE, LAN_HOST, LAN_CLIENT }

const CONNECT_RETRIES := 8
const RETRY_SECONDS := 1.5
const RECONNECT_ATTEMPTS := 5
## Validated player count; 5–6 stay locked until sync/performance checks pass.
const LAN_MAX_PLAYERS := 4

var app: App
var kind: Kind = Kind.ONLINE
var net: NetBridge
var lobby: LobbyClient
var room_info: Dictionary = {}
var in_match := false
var _root: Node
var _hello: Dictionary = {}
var _address := ""
var _port := 0
var _connect_attempts := 0
var _joined := false
var _leaving := false
var _reconnecting := false


static func create(p_app: App) -> OnlineFlow:
	var flow := OnlineFlow.new()
	flow.name = "OnlineFlow"
	flow.app = p_app
	p_app.add_child(flow)
	return flow


func _ready() -> void:
	lobby = LobbyClient.new()
	lobby.name = "LobbyClient"
	add_child(lobby)
	_make_bridge()


func _make_bridge() -> void:
	if _root and is_instance_valid(_root):
		_root.queue_free()
	_root = Node.new()
	_root.name = "NetRoot"
	add_child(_root)
	net = NetBridge.new()
	_root.add_child(net)
	net.world_parent = app.world_root
	net.joined.connect(_on_joined)
	net.join_failed.connect(_on_join_failed)
	net.disconnected.connect(_on_disconnected)
	net.load_requested.connect(_on_load_requested)
	net.match_begun.connect(
		func() -> void:
			in_match = true
			begun.emit()
	)


# --- Starting a session -----------------------------------------------------------------


func create_online(map_id: String, difficulty_id: String, max_players: int, password: String) -> String:
	kind = Kind.ONLINE
	status_changed.emit("MP_STATUS_SIGNING_IN")
	var g := await lobby.ensure_guest(Saves.display_name(), Saves.avatar_color_index())
	if not g["ok"]:
		return str(g["error"])
	status_changed.emit("MP_STATUS_CREATING")
	var r := await lobby.create_room(map_id, difficulty_id, max_players, password)
	if not r["ok"]:
		return str(r["error"])
	_connect_online(r["room"])
	return ""


func join_online(code: String, password: String) -> String:
	kind = Kind.ONLINE
	status_changed.emit("MP_STATUS_SIGNING_IN")
	var g := await lobby.ensure_guest(Saves.display_name(), Saves.avatar_color_index())
	if not g["ok"]:
		return str(g["error"])
	status_changed.emit("MP_STATUS_JOINING")
	var r := await lobby.join_room(code, password)
	if not r["ok"]:
		return str(r["error"])
	_connect_online(r["room"])
	return ""


func _connect_online(room: Dictionary) -> void:
	room_info = room
	var server: Dictionary = room.get("server", {})
	_address = str(server.get("host", ""))
	_port = int(server.get("port", 0))
	_hello = {"ticket": str(room.get("ticket", ""))}
	_connect_attempts = 0
	status_changed.emit("MP_STATUS_CONNECTING")
	net.join(_address, _port, _hello)


func host_lan() -> String:
	kind = Kind.LAN_HOST
	net.host_name = Saves.display_name()
	net.host_color = Saves.avatar_color_index()
	var err := net.host(
		NetProtocol.LAN_PORT,
		{"room_id": "lan", "map_id": "house", "difficulty_id": "normal", "max_players": LAN_MAX_PLAYERS - 1},
		NetBridge.Trust.LAN_HOST
	)
	if err != OK:
		return "MP_LAN_PORT_BUSY"
	_joined = true
	app.goto("lobby", {"flow": self})
	return ""


func join_lan(address: String) -> String:
	kind = Kind.LAN_CLIENT
	var clean := address.strip_edges()
	if not clean.is_valid_ip_address():
		return "MP_LAN_BAD_ADDRESS"
	_address = clean
	_port = NetProtocol.LAN_PORT
	_hello = {"lan_id": Saves.local_id(), "name": Saves.display_name(), "color": Saves.avatar_color_index()}
	_connect_attempts = CONNECT_RETRIES  # no boot delay to wait for on LAN
	status_changed.emit("MP_STATUS_CONNECTING")
	net.join(_address, _port, _hello)
	return ""


# --- Events -------------------------------------------------------------------------------


func _on_joined(_pid: int) -> void:
	_joined = true
	if in_match or _reconnecting:
		return  # the server sends the running match's level next
	if not app.current() or app.current().name != "Lobby":
		app.goto("lobby", {"flow": self})


func _on_join_failed(reason: String) -> void:
	# A freshly spawned dedicated server may still be booting.
	if not _joined and reason == "NET_UNREACHABLE" and _connect_attempts < CONNECT_RETRIES and kind == Kind.ONLINE:
		_connect_attempts += 1
		await get_tree().create_timer(RETRY_SECONDS).timeout
		if _leaving:
			return
		_make_bridge()
		net.join(_address, _port, _hello)
		return
	_abort(reason)


func _on_disconnected(reason: String) -> void:
	if _leaving:
		return
	if net and net.mc and net.mc.is_finished():
		return  # results are already showing; the server may simply close first
	if in_match and kind == Kind.ONLINE and Settings.b("auto_reconnect") and reason == "NET_LOST":
		_reconnect()
		return
	_abort(reason)


func _reconnect() -> void:
	status_changed.emit("MP_STATUS_RECONNECTING")
	# Leave the dead world behind a waiting screen before freeing it.
	in_match = false
	get_tree().paused = false
	AudioService.stop_all_world()
	app.post_fx.set_active(false)
	(
		app
		. reset_to(
			"loading",
			{
				"online": true,
				"flow": self,
				"waiting": true,
				"map_id": str(net.room.get("map_id", room_info.get("map_id", ""))),
				"difficulty_id": str(net.room.get("difficulty_id", room_info.get("difficulty_id", "normal"))),
			}
		)
	)
	app.set_world(null)
	for attempt in RECONNECT_ATTEMPTS:
		await get_tree().create_timer(2.0).timeout
		if _leaving:
			return
		var r := await lobby.reconnect_ticket(str(room_info.get("room_id", "")))
		if not r["ok"]:
			continue
		in_match = false
		_joined = false
		_reconnecting = true
		app.set_world(null)
		_make_bridge()
		_connect_online(r["room"])
		return
	_abort("NET_LOST")


func _on_load_requested(config: Dictionary) -> void:
	_reconnecting = false
	var params := config.duplicate()
	params.merge({"online": true, "flow": self, "config": config}, true)
	app.reset_to("loading", params)


func _abort(reason: String) -> void:
	if _leaving:
		return
	leave()
	Session.quit_to_menu()
	app.goto("multiplayer")
	app.alert("MP_DISCONNECTED_TITLE", describe_error(reason))


## Player-facing text for a reason key from the lobby service or game server.
static func describe_error(reason: String) -> String:
	var text := TranslationServer.translate(reason)
	return text if text != reason else TranslationServer.translate("NET_GENERIC_ERROR")


# --- Leaving ---------------------------------------------------------------------------------


func leave() -> void:
	if _leaving:
		return
	_leaving = true
	if net:
		net.leave()
	if kind == Kind.ONLINE and not in_match and not room_info.is_empty():
		lobby.leave_room(str(room_info.get("room_id", "")))
	if Session.online == self:
		Session.online = null
	# Give the best-effort "leave room" request time to go out before freeing.
	get_tree().create_timer(3.0).timeout.connect(queue_free)


func is_lan() -> bool:
	return kind != Kind.ONLINE


func display_code() -> String:
	return str(room_info.get("code", ""))
