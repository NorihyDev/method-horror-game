extends Node
## Headless dedicated server for one room.
##
## godot --headless --path game -- --server --port=24600 --room=<id> --code=<6 digits>
##     --map=house --difficulty=normal --max-players=4
## Secrets come only from the environment: METHOD_TICKET_SECRET (required),
## METHOD_SERVER_SECRET and METHOD_LOBBY_URL (to report status and results).
## Optional DTLS: METHOD_DTLS_KEY / METHOD_DTLS_CERT (PEM file paths).

const IDLE_LOBBY_SECONDS := 180.0
const LINGER_AFTER_END := 30.0
const MAX_LIFETIME := 3.0 * 3600.0

var net: NetBridge
var _lobby_url := ""
var _server_secret := ""
var _idle := 0.0
var _ended_at := -1.0
var _uptime := 0.0
var _reported_phase := ""
var _result_sent := false


func _ready() -> void:
	var secret := OS.get_environment("METHOD_TICKET_SECRET")
	if secret.length() < 32:
		Log.error("server", "METHOD_TICKET_SECRET missing or too short; refusing to start")
		get_tree().quit(2)
		return
	_server_secret = OS.get_environment("METHOD_SERVER_SECRET")
	_lobby_url = OS.get_environment("METHOD_LOBBY_URL").trim_suffix("/")
	var root := Node.new()
	root.name = "NetRoot"
	add_child(root)
	net = NetBridge.new()
	root.add_child(net)
	net.world_parent = Session.app.world_root
	net.ticket_secret = secret
	var room := {
		"room_id": AppInfo.arg_value("--room", ""),
		"code": AppInfo.arg_value("--code", ""),
		"map_id": AppInfo.arg_value("--map", "house"),
		"difficulty_id": AppInfo.arg_value("--difficulty", "normal"),
		"max_players": int(AppInfo.arg_value("--max-players", "4")),
	}
	if str(room["room_id"]).is_empty():
		Log.error("server", "--room is required")
		get_tree().quit(2)
		return
	var key: CryptoKey = null
	var cert: X509Certificate = null
	var key_path := OS.get_environment("METHOD_DTLS_KEY")
	var cert_path := OS.get_environment("METHOD_DTLS_CERT")
	if not key_path.is_empty() and not cert_path.is_empty():
		key = CryptoKey.new()
		cert = X509Certificate.new()
		if key.load(key_path) != OK or cert.load(cert_path) != OK:
			Log.error("server", "Could not load DTLS key/certificate")
			get_tree().quit(2)
			return
	var port := int(AppInfo.arg_value("--port", str(NetProtocol.DEFAULT_PORT)))
	var err := net.host(port, room, NetBridge.Trust.DEDICATED, key, cert)
	if err != OK:
		Log.error("server", "Could not listen", {"port": port, "error": error_string(err)})
		get_tree().quit(3)
		return
	net.room_updated.connect(_on_room_updated)
	net.load_requested.connect(func(_cfg: Dictionary) -> void:
		net.mc.match_finished.connect(_on_match_finished))


func _process(delta: float) -> void:
	if net == null:
		return
	_uptime += delta
	var members: Array = net.room.get("members", [])
	var connected := 0
	for m in members:
		if not bool(m.get("away", false)):
			connected += 1
	_idle = _idle + delta if connected == 0 else 0.0
	var limit := IDLE_LOBBY_SECONDS if net.phase() == NetBridge.PHASE_LOBBY else NetProtocol.RECONNECT_WINDOW + 30.0
	if _idle > limit or _uptime > MAX_LIFETIME:
		_shutdown("idle or lifetime limit")
	if _ended_at >= 0.0 and _uptime - _ended_at > LINGER_AFTER_END:
		_shutdown("match ended")


func _on_room_updated(room: Dictionary) -> void:
	var phase := str(room.get("phase", ""))
	var lobby_state := {"lobby": "open", "loading": "playing", "playing": "playing", "ended": "ended"}.get(phase, "open") as String
	if lobby_state != _reported_phase:
		_reported_phase = lobby_state
		_post("/v1/internal/rooms/%s/status" % net.expected_room_id, {"state": lobby_state})
	if phase == NetBridge.PHASE_ENDED and _ended_at < 0.0:
		_ended_at = _uptime


func _on_match_finished(_result: Dictionary) -> void:
	if _result_sent:
		return
	_result_sent = true
	var players: Array = []
	for pid in net.mc.state.players:
		var uid := net.uid_of(int(pid))
		if uid.is_empty():
			continue
		var r := net.mc.build_result(net.mc.state.result, int(pid))
		players.append({
			"user_id": uid,
			"escaped": str(r["local_status"]) == MatchState.STATUS_ESCAPED,
			"optional_completed": int(r["optional_completed"]),
		})
	_post("/v1/internal/match-result", {
		"room_id": net.expected_room_id,
		"match_id": net.mc.state.match_id,
		"map_id": net.mc.state.map_id,
		"difficulty_id": net.mc.state.difficulty_id,
		"players": players,
	})


func _post(path: String, body: Dictionary) -> void:
	if _lobby_url.is_empty() or _server_secret.is_empty():
		return
	var raw := JSON.stringify(body)
	var ts := str(int(Time.get_unix_time_from_system()))
	var sig := NetProtocol.hmac_sha256(_server_secret, ("POST\n%s\n%s\n%s" % [path, ts, raw]).to_utf8_buffer()).hex_encode()
	var http := HTTPRequest.new()
	http.timeout = 10.0
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
		Log.info("server", "Lobby call finished", {"path": path, "result": result, "status": code})
		http.queue_free())
	http.request(_lobby_url + path, PackedStringArray([
		"Content-Type: application/json", "X-Method-Timestamp: " + ts, "X-Method-Signature: " + sig,
	]), HTTPClient.METHOD_POST, raw)


func _shutdown(reason: String) -> void:
	Log.info("server", "Shutting down", {"reason": reason})
	set_process(false)
	net.close()
	get_tree().create_timer(1.0).timeout.connect(func() -> void: get_tree().quit(0))
