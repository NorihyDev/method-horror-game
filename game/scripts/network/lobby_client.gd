class_name LobbyClient
extends Node
## HTTP client for the METHOD lobby service.
##
## The service URL comes from the project setting `method/online/lobby_url`
## (set per export), or `--lobby=<url>` / METHOD_LOBBY_URL in development.
## Plain http:// is accepted only for localhost development.
##
## The guest token is stored in the app-private user directory with a
## checksum. Godot exposes no OS keychain, so this is not hardware-backed
## secure storage (see docs/security.md).

const TIMEOUT := 10.0
const SETTING := "method/online/lobby_url"

var base_url := ""
var token := ""
var user: Dictionary = {}
var session_path := "user://online_session.json"


func _ready() -> void:
	base_url = configured_url()
	if AppInfo.uses_isolated_storage():
		session_path = "user://test_online_session.json"
	_load_session()


## The lobby service URL for this build/run ("" when none is configured).
static func configured_url() -> String:
	var url := AppInfo.arg_value("--lobby", OS.get_environment("METHOD_LOBBY_URL"))
	if url.is_empty():
		url = str(ProjectSettings.get_setting(SETTING, ""))
	return url.trim_suffix("/")


## Returns "" when usable, otherwise a translation key explaining why not.
func availability() -> String:
	return availability_for(base_url)


static func availability_for(url: String) -> String:
	if url.is_empty():
		return "MP_UNAVAILABLE_SERVICE"
	if not is_secure_url(url):
		return "MP_INSECURE_SERVICE"
	return ""


static func is_secure_url(url: String) -> bool:
	if url.begins_with("https://"):
		return true
	for local in ["http://127.0.0.1", "http://localhost", "http://[::1]"]:
		if url.begins_with(local):
			return true
	return false


func has_session() -> bool:
	return not token.is_empty()


## Ensures a valid guest session, creating one if needed.
func ensure_guest(display_name: String, color: int) -> Dictionary:
	if has_session():
		var me := await request("GET", "/v1/me")
		if me["status"] == 200:
			user = me["json"]
			if str(user.get("name", "")) != NameValidator.normalize(display_name) or int(user.get("color", 0)) != color:
				var upd := await request("PATCH", "/v1/me", {"name": display_name, "color": color})
				if upd["status"] == 200:
					user = upd["json"]
			return {"ok": true}
		if me["status"] != 401:
			return {"ok": false, "error": _error_key(me)}
		_clear_session()
	var g := await request("POST", "/v1/guest", {"name": display_name, "color": color}, false)
	if g["status"] != 201:
		return {"ok": false, "error": _error_key(g)}
	token = str(g["json"].get("token", ""))
	user = {"id": g["json"].get("user_id"), "name": g["json"].get("name"), "color": g["json"].get("color")}
	_save_session()
	return {"ok": true}


func create_room(map_id: String, difficulty_id: String, max_players: int, password: String) -> Dictionary:
	var body := {"map_id": map_id, "difficulty_id": difficulty_id, "max_players": max_players}
	if not password.is_empty():
		body["password"] = password
	return _room_result(await request("POST", "/v1/rooms", body), 201)


func join_room(code: String, password: String) -> Dictionary:
	var body := {"code": code}
	if not password.is_empty():
		body["password"] = password
	return _room_result(await request("POST", "/v1/rooms/join", body), 200)


func reconnect_ticket(room_id: String) -> Dictionary:
	return _room_result(await request("POST", "/v1/rooms/%s/ticket" % room_id.uri_encode(), {}), 200)


func leave_room(room_id: String) -> void:
	await request("POST", "/v1/rooms/%s/leave" % room_id.uri_encode(), {})


func wallet() -> Dictionary:
	return await request("GET", "/v1/wallet")


## Buys a cosmetic with the verified wallet. The idempotency key makes a
## retried request (lost reply, double tap) charge at most once.
func purchase(item_id: String, idempotency_key: String) -> Dictionary:
	return await request("POST", "/v1/shop/purchase", {"item_id": item_id, "idempotency_key": idempotency_key})


func logout() -> void:
	if has_session():
		await request("POST", "/v1/logout", {})
	_clear_session()


func _room_result(r: Dictionary, ok_status: int) -> Dictionary:
	if r["status"] != ok_status:
		return {"ok": false, "error": _error_key(r)}
	var j: Dictionary = r["json"]
	var server: Dictionary = j.get("server", {})
	if str(j.get("ticket", "")).is_empty() or server.is_empty():
		return {"ok": false, "error": "NET_SERVICE_ERROR"}
	return {"ok": true, "room": j}


## Performs a JSON request. Returns {"status": int, "json": Dictionary}.
## status 0 = network failure.
func request(method: String, path: String, body: Dictionary = {}, auth: bool = true) -> Dictionary:
	if not availability().is_empty():
		return {"status": 0, "json": {}}
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var headers := PackedStringArray(
		[
			"Content-Type: application/json",
			"X-Method-Protocol: %d" % AppInfo.PROTOCOL_VERSION,
		]
	)
	if auth and has_session():
		headers.append("Authorization: Bearer " + token)
	var verb := (
		(
			{
				"GET": HTTPClient.METHOD_GET,
				"POST": HTTPClient.METHOD_POST,
				"PATCH": HTTPClient.METHOD_PATCH,
				"DELETE": HTTPClient.METHOD_DELETE,
			}
			. get(method, HTTPClient.METHOD_GET)
		)
		as int
	)
	var payload := "" if method == "GET" else JSON.stringify(body)
	var err := http.request(base_url + path, headers, verb, payload)
	if err != OK:
		http.queue_free()
		return {"status": 0, "json": {}}
	var result: Array = await http.request_completed
	http.queue_free()
	var status := int(result[1]) if int(result[0]) == HTTPRequest.RESULT_SUCCESS else 0
	var parsed: Variant = JSON.parse_string((result[3] as PackedByteArray).get_string_from_utf8())
	return {"status": status, "json": parsed if parsed is Dictionary else {}}


func _error_key(r: Dictionary) -> String:
	if int(r["status"]) == 0:
		return "NET_SERVICE_UNREACHABLE"
	var code := str(r["json"].get("error", "SERVICE_ERROR"))
	return "NET_" + code


func _load_session() -> void:
	var res := SaveIO.read_with_recovery(session_path)
	if res["data"] is Dictionary:
		token = str(res["data"].get("token", ""))


func _save_session() -> void:
	SaveIO.write_atomic(session_path, {"token": token})


func _clear_session() -> void:
	token = ""
	user = {}
	SaveIO.delete_all(session_path)
