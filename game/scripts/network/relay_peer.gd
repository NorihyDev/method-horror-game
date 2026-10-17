class_name RelayMultiplayerPeer
extends MultiplayerPeerExtension
## Godot multiplayer over the METHOD relay (Cloudflare Worker + one Durable
## Object per room, protocol in services/relay/src/protocol.ts). The room's
## creator is the host (peer 1) and runs the match exactly like a LAN host;
## the relay forwards packets between it and the guests over one secure
## WebSocket each and stamps every packet with its real sender. The relay is
## not a game server: it checks membership, sizes and rates, never game rules.
##
## Frames: client -> relay [u8 1][i32 target][u8 channel][u8 mode][payload]
##         relay -> client [u8 1][i32 from][u8 channel][u8 mode][payload]
## Text frames: JSON control (welcome / join / leave / closed / error) and
## "ping"/"pong" keep-alives.

signal relay_error(code: String)

const PROTOCOL := 1
const KIND_DATA := 1
const HEADER := 7
const PING_SECONDS := 20.0
## A welcome must arrive this soon after the socket opens.
const WELCOME_TIMEOUT := 10.0

var is_host := false
## Last refusal or close reason from the relay ("ROOM_FULL", "HOST_LEFT", ...).
var last_error := ""
## Frames sent to / received from the relay (quota diagnostics: every frame
## the relay receives counts toward its daily request allowance).
var frames_sent := 0
var frames_received := 0

var _ws := WebSocketPeer.new()
var _status := MultiplayerPeer.CONNECTION_DISCONNECTED
var _id := 0
var _target := 0
var _channel := 0
var _mode := MultiplayerPeer.TRANSFER_MODE_RELIABLE
var _refuse := false
## Received packets: [from, channel, mode, payload].
var _queue: Array = []
var _peers: Dictionary = {}
var _opened_at := 0.0
var _ping_timer := 0.0
var _was_open := false


## Opens the socket. `url` is the full ws(s)://.../v1/rooms/<code>/ws?... URL.
func open(url: String, as_host: bool) -> Error:
	is_host = as_host
	_ws.inbound_buffer_size = 1 << 20
	_ws.outbound_buffer_size = 1 << 20
	_ws.max_queued_packets = 4096
	var tls: TLSOptions = TLSOptions.client() if url.begins_with("wss://") else null
	var err := _ws.connect_to_url(url, tls)
	if err != OK:
		return err
	_status = MultiplayerPeer.CONNECTION_CONNECTING
	_opened_at = Time.get_ticks_msec() / 1000.0
	return OK


func _poll() -> void:
	_ws.poll()
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		_was_open = true
		while _ws.get_available_packet_count() > 0:
			var data := _ws.get_packet()
			if _ws.was_string_packet():
				_on_control(data.get_string_from_utf8())
			else:
				_on_frame(data)
		_ping_timer -= get_process_delta()
		if _ping_timer <= 0.0:
			_ping_timer = PING_SECONDS
			_ws.send_text("ping")
		if _status == MultiplayerPeer.CONNECTION_CONNECTING:
			if Time.get_ticks_msec() / 1000.0 - _opened_at > WELCOME_TIMEOUT:
				_lost("TIMEOUT")
	elif state == WebSocketPeer.STATE_CLOSED and _status != MultiplayerPeer.CONNECTION_DISCONNECTED:
		if last_error.is_empty():
			var reason := _ws.get_close_reason()
			last_error = reason if not reason.is_empty() else ("UNREACHABLE" if not _was_open else "LOST")
		_lost(last_error)


static func get_process_delta() -> float:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_process_delta_time() if tree else 0.016


func _on_control(text: String) -> void:
	if text == "pong":
		return
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return
	var m: Dictionary = parsed
	match str(m.get("t", "")):
		"welcome":
			if int(m.get("proto", 0)) != PROTOCOL:
				_lost("VERSION")
				return
			_id = int(m.get("id", 0))
			_status = MultiplayerPeer.CONNECTION_CONNECTED
			if not is_host:
				_peers[1] = true
				peer_connected.emit(1)
		"join":
			var id := int(m.get("id", 0))
			if is_host and id > 1 and not _peers.has(id):
				_peers[id] = true
				peer_connected.emit(id)
		"leave":
			var gone := int(m.get("id", 0))
			if is_host and _peers.erase(gone):
				peer_disconnected.emit(gone)
		"error", "closed":
			last_error = str(m.get("code", m.get("reason", "LOST")))
			# The relay's message is authoritative: close our side now.
			_ws.close(1000, last_error)
			_lost(last_error)


func _on_frame(data: PackedByteArray) -> void:
	if data.size() < HEADER or data[0] != KIND_DATA:
		return
	var from := data.decode_s32(1)
	# Guests only ever hear from the host; the host only from known guests.
	if not is_host and from != 1:
		return
	if is_host and not _peers.has(from):
		return
	frames_received += 1
	_queue.append([from, data[5], data[6], data.slice(HEADER)])


func _lost(reason: String) -> void:
	if _status == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	last_error = reason
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
	for id in _peers.keys():
		peer_disconnected.emit(int(id))
	_peers.clear()
	relay_error.emit(reason)


# --- MultiplayerPeer interface -------------------------------------------------------------


func _get_available_packet_count() -> int:
	return _queue.size()


func _get_packet_script() -> PackedByteArray:
	if _queue.is_empty():
		return PackedByteArray()
	return _queue.pop_front()[3]


func _put_packet_script(buffer: PackedByteArray) -> Error:
	if _status != MultiplayerPeer.CONNECTION_CONNECTED:
		return ERR_UNCONFIGURED
	var frame := PackedByteArray()
	frame.resize(HEADER)
	frame[0] = KIND_DATA
	frame.encode_s32(1, _target if is_host else 1)
	frame[5] = clampi(_channel, 0, 255)
	frame[6] = _mode
	frame.append_array(buffer)
	frames_sent += 1
	return _ws.send(frame, WebSocketPeer.WRITE_MODE_BINARY)


func _get_packet_peer() -> int:
	return int(_queue[0][0]) if not _queue.is_empty() else 0


func _get_packet_channel() -> int:
	return int(_queue[0][1]) if not _queue.is_empty() else 0


func _get_packet_mode() -> MultiplayerPeer.TransferMode:
	return int(_queue[0][2]) as MultiplayerPeer.TransferMode if not _queue.is_empty() else _mode


func _get_max_packet_size() -> int:
	return 1 << 16


func _set_target_peer(peer: int) -> void:
	_target = peer


func _get_unique_id() -> int:
	return _id


func _is_server() -> bool:
	return is_host


func _is_server_relay_supported() -> bool:
	return false


func _get_connection_status() -> MultiplayerPeer.ConnectionStatus:
	return _status


func _set_transfer_channel(channel: int) -> void:
	_channel = channel


func _get_transfer_channel() -> int:
	return _channel


func _set_transfer_mode(mode: MultiplayerPeer.TransferMode) -> void:
	_mode = mode


func _get_transfer_mode() -> MultiplayerPeer.TransferMode:
	return _mode


func _set_refuse_new_connections(enable: bool) -> void:
	_refuse = enable


func _is_refusing_new_connections() -> bool:
	return _refuse


## Host: the relay closes that guest's socket (and tells everyone it left).
func _disconnect_peer(peer: int, _force: bool) -> void:
	if is_host and _peers.has(peer):
		_ws.send_text(JSON.stringify({"t": "kick", "id": peer}))
		_peers.erase(peer)
		peer_disconnected.emit(peer)


func _close() -> void:
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.send_text(JSON.stringify({"t": "leave"}))
		_ws.close(1000, "LEFT")
	_peers.clear()
	_queue.clear()
	_status = MultiplayerPeer.CONNECTION_DISCONNECTED
