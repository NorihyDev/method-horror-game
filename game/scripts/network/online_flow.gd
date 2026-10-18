class_name OnlineFlow
extends Node
## One multiplayer session on this device: an online room or a LAN
## development session. Translates network events into screen changes and
## owns cleanup.
##
## Online rooms go through the METHOD relay (Cloudflare Worker + one Durable
## Object per room, services/relay). The room's creator hosts: their device
## runs the match (rules, enemy AI, physics) exactly like a LAN host, and the
## relay forwards packets between it and the guests over secure WebSockets.
## If the creator leaves, the room ends for everyone.

signal status_changed(text_key: String)
signal begun

enum Kind { ONLINE, LAN_HOST, LAN_CLIENT }

## The host's device runs the match for everyone: rooms hold four players.
const LAN_MAX_PLAYERS := 4
## How long the room creator waits for the relay to admit them.
const RELAY_CONNECT_SECONDS := 15.0

## Reason key of the last session that ended in an error (tests, diagnostics).
static var last_abort := ""

var app: App
var kind: Kind = Kind.ONLINE
var net: NetBridge
var relay: RelayClient
var relay_peer: RelayMultiplayerPeer
var room_info: Dictionary = {}
var in_match := false
var _root: Node
var _hello: Dictionary = {}
var _address := ""
var _port := 0
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
	relay = RelayClient.new()
	relay.name = "RelayClient"
	add_child(relay)
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


## Creates a private room and hosts it from this device. Returns "" once in
## the lobby, or a message key.
func create_online(map_id: String, difficulty_id: String, max_players: int, password: String) -> String:
	kind = Kind.ONLINE
	status_changed.emit("MP_STATUS_CREATING")
	var players := clampi(max_players, 2, NetProtocol.RELAY_MAX_PLAYERS)
	var r := await relay.create_room(players, password)
	if not r["ok"]:
		return str(r["error"])
	if _leaving:
		return "NET_LOST"
	room_info = {"code": r["code"], "map_id": map_id, "difficulty_id": difficulty_id, "max_players": players}
	status_changed.emit("MP_STATUS_CONNECTING")
	relay_peer = RelayMultiplayerPeer.new()
	if relay_peer.open(relay.socket_url(str(r["code"]), true, str(r["host_token"])), true) != OK:
		return "NET_UNREACHABLE"
	# Wait for the relay to admit us as the room's host before opening the lobby.
	var deadline := Time.get_ticks_msec() + int(RELAY_CONNECT_SECONDS * 1000.0)
	while relay_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING:
		relay_peer.poll()
		if Time.get_ticks_msec() > deadline:
			relay_peer.close()
			return "NET_UNREACHABLE"
		await get_tree().process_frame
		if _leaving:
			return "NET_LOST"
	if relay_peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
		return RelayClient.reason_key(relay_peer.last_error)
	# Deferred: the relay reports from inside the multiplayer poll.
	relay_peer.relay_error.connect(_on_host_relay_error, CONNECT_DEFERRED)
	net.host_name = Saves.display_name()
	net.host_color = Saves.avatar_color_index()
	net.allowed_maps = Session.unlocked_map_ids()
	var map := map_id if Session.is_map_unlocked(map_id) else "house"
	net.host_relay(
		relay_peer,
		{"room_id": r["code"], "code": r["code"], "map_id": map, "difficulty_id": difficulty_id, "max_players": players}
	)
	_joined = true
	app.goto("lobby", {"flow": self})
	return ""


## Joins a room by its code. Returns "" while connecting (the lobby opens on
## success; failures come back as an alert), or a message key.
func join_online(code: String, password: String) -> String:
	kind = Kind.ONLINE
	var clean := code.strip_edges()
	if clean.length() != 6 or not clean.is_valid_int():
		return "NET_CODE_FORMAT"
	if not RelayClient.is_configured():
		return "MP_ONLINE_NOT_CONFIGURED"
	room_info = {"code": clean, "password": password}
	_hello = {
		"lan_id": Saves.local_id(),
		"name": Saves.display_name(),
		"color": Saves.avatar_color_index(),
		"char": Saves.character(),
	}
	status_changed.emit("MP_STATUS_CONNECTING")
	return _connect_guest()


func _connect_guest() -> String:
	relay_peer = RelayMultiplayerPeer.new()
	var url := relay.socket_url(str(room_info["code"]), false, str(room_info.get("password", "")))
	if relay_peer.open(url, false) != OK:
		return "NET_UNREACHABLE"
	net.join_relay(relay_peer, _hello)
	return ""


func host_lan() -> String:
	kind = Kind.LAN_HOST
	net.host_name = Saves.display_name()
	net.host_color = Saves.avatar_color_index()
	net.allowed_maps = Session.unlocked_map_ids()
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
	_hello = {
		"lan_id": Saves.local_id(),
		"name": Saves.display_name(),
		"color": Saves.avatar_color_index(),
		"char": Saves.character(),
	}
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
	_abort(_relay_reason(reason))


## The relay's own refusal (room full, wrong password, host left...) explains
## a failure better than the generic transport error.
func _relay_reason(fallback: String) -> String:
	if kind == Kind.ONLINE and relay_peer and not relay_peer.last_error.is_empty():
		return RelayClient.reason_key(relay_peer.last_error)
	return fallback


## The room creator lost the relay: the room is gone for everyone.
func _on_host_relay_error(code: String) -> void:
	if _leaving:
		return
	if net and net.mc and net.mc.is_finished():
		return
	_abort(RelayClient.reason_key(code) if code != "HOST_LEFT" else "NET_LOST")


func _on_disconnected(reason: String) -> void:
	if _leaving:
		return
	if net and net.mc and net.mc.is_finished():
		return  # results are already showing; the server may simply close first
	var why := _relay_reason(reason)
	# A dropped guest can rejoin its slot while the host is still there.
	if in_match and kind == Kind.ONLINE and Settings.b("auto_reconnect") and why == "NET_LOST":
		_reconnect()
		return
	_abort(why)


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
	await get_tree().create_timer(2.0).timeout
	if _leaving:
		return
	# Same code and identity: the host puts us back into our slot with a
	# full snapshot (or the relay says why not, e.g. the host left).
	in_match = false
	_joined = false
	_reconnecting = true
	app.set_world(null)
	_make_bridge()
	var err := _connect_guest()
	if not err.is_empty():
		_abort(err)


func _on_load_requested(config: Dictionary) -> void:
	_reconnecting = false
	var params := config.duplicate()
	params.merge({"online": true, "flow": self, "config": config}, true)
	app.reset_to("loading", params)


func _abort(reason: String) -> void:
	if _leaving:
		return
	last_abort = reason
	leave()
	Session.quit_to_menu()
	app.goto("multiplayer")
	app.alert("MP_DISCONNECTED_TITLE", describe_error(reason))


## Player-facing text for a reason key from the relay or the host.
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
	if Session.online == self:
		Session.online = null
	# Let the relay's "leave" message go out before freeing the socket.
	get_tree().create_timer(1.0).timeout.connect(queue_free)


func is_lan() -> bool:
	return kind != Kind.ONLINE


func display_code() -> String:
	return str(room_info.get("code", ""))
