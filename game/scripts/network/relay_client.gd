class_name RelayClient
extends Node
## HTTPS side of the METHOD relay: creates private rooms and builds the
## WebSocket URLs for them. The endpoint comes from the project setting
## `method/online/relay_url` (the deployed Worker, set in project.godot), or
## `--relay=<url>` / METHOD_RELAY_URL during development. It is a public
## URL, not a secret: no credentials live in the game.

const SETTING := "method/online/relay_url"
const PROTOCOL := RelayMultiplayerPeer.PROTOCOL
const TIMEOUT := 12.0

var base_url := ""


func _ready() -> void:
	base_url = configured_url()


static func configured_url() -> String:
	var url := AppInfo.arg_value("--relay", OS.get_environment("METHOD_RELAY_URL"))
	if url.is_empty():
		url = str(ProjectSettings.get_setting(SETTING, ""))
	return url.strip_edges().trim_suffix("/")


static func is_configured() -> bool:
	var url := configured_url()
	return url.begins_with("https://") or url.begins_with("http://")


## POST /v1/rooms -> {ok, code, host_token, max_players} or {ok: false, error}.
func create_room(max_players: int, password: String) -> Dictionary:
	if not is_configured():
		return {"ok": false, "error": "MP_ONLINE_NOT_CONFIGURED"}
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var body := JSON.stringify({"proto": PROTOCOL, "max_players": max_players, "password": password})
	var err := http.request(
		base_url + "/v1/rooms", PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, body
	)
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "NET_UNREACHABLE"}
	var res: Array = await http.request_completed
	http.queue_free()
	var status := int(res[1])
	var parsed: Variant = JSON.parse_string((res[3] as PackedByteArray).get_string_from_utf8())
	if int(res[0]) != HTTPRequest.RESULT_SUCCESS or status == 0:
		return {"ok": false, "error": "NET_UNREACHABLE"}
	if status == 426:
		return {"ok": false, "error": "NET_REJECT_VERSION"}
	if status != 201 or not parsed is Dictionary:
		return {"ok": false, "error": "NET_GENERIC_ERROR"}
	var d: Dictionary = parsed
	return {
		"ok": true,
		"code": str(d.get("code", "")),
		"host_token": str(d.get("host_token", "")),
		"max_players": int(d.get("max_players", 4)),
	}


## WebSocket URL for a room. Guests pass the password; the host its token.
func socket_url(code: String, as_host: bool, secret: String) -> String:
	var ws := base_url.replace("https://", "wss://").replace("http://", "ws://")
	var query := "proto=%d&role=%s" % [PROTOCOL, "host" if as_host else "guest"]
	if as_host:
		query += "&token=" + secret.uri_encode()
	elif not secret.is_empty():
		query += "&pw=" + secret.uri_encode()
	return "%s/v1/rooms/%s/ws?%s" % [ws, code.uri_encode(), query]


## Player-facing message key for a relay refusal or close reason.
static func reason_key(code: String) -> String:
	match code:
		"ROOM_NOT_FOUND", "ROOM_EXPIRED":
			return "NET_ROOM_NOT_FOUND"
		"ROOM_FULL":
			return NetProtocol.REJECT_FULL
		"WRONG_PASSWORD":
			return "NET_PASSWORD_WRONG"
		"LOCKED_OUT":
			return "NET_LOCKED_OUT"
		"KICKED":
			return NetProtocol.REJECT_KICKED
		"VERSION":
			return NetProtocol.REJECT_VERSION
		"HOST_LEFT":
			return "NET_HOST_LEFT"
		"RATE_LIMITED", "MALFORMED":
			return "NET_RATE_LIMITED"
		"UNREACHABLE", "TIMEOUT":
			return "NET_UNREACHABLE"
	return "NET_LOST"
