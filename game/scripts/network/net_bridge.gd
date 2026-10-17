class_name NetBridge
extends Node
## The single RPC endpoint between a server and its clients.
##
## Lives at <branch root>/Net on every peer, under a branch that owns its own
## SceneMultiplayer (so a server and several clients can even share one
## process in tests). World state flows only from the server: clients send
## intentions, the server validates them through MatchController and
## broadcasts results by stable entity id.
##
## Authentication uses SceneMultiplayer's auth callback: no RPC from a peer is
## delivered before its hello/ticket is verified and `complete_auth` is called.

signal room_updated(room: Dictionary)
signal joined(pid: int)
signal join_failed(reason_key: String)
signal disconnected(reason_key: String)
signal load_requested(config: Dictionary)
signal match_begun
signal ping_received(pid: int, pos: Vector3, kind: int)
signal revive_changed(target: int, active: bool)

enum Mode { OFFLINE, SERVER, CLIENT }
enum Trust { DEDICATED, LAN_HOST }

const PHASE_LOBBY := "lobby"
const PHASE_LOADING := "loading"
const PHASE_PLAYING := "playing"
const PHASE_ENDED := "ended"

var mode: Mode = Mode.OFFLINE
var trust: Trust = Trust.DEDICATED
## Parent node levels are built under (World root, or a SubViewport in tests).
var world_parent: Node
var room: Dictionary = {}
var my_pid := 0
var mc: MatchController
var map: MapBase
var local_player: PlayerController
## Dedicated servers: shared secret with the lobby service (never on clients).
var ticket_secret := ""
## Seconds a disconnected player's slot is kept during a match.
var reconnect_window := NetProtocol.RECONNECT_WINDOW
var expected_room_id := ""
## Display name / color of a LAN host's own player.
var host_name := ""
var host_color := 0
var limiter := NetProtocol.RateLimiter.new()

var _mp: SceneMultiplayer
var _enet: ENetMultiplayerPeer
var _phase := PHASE_LOBBY
var _peers: Dictionary = {}
var _pid_by_uid: Dictionary = {}
var _names: Dictionary = {}
var _colors: Dictionary = {}
var _ready: Dictionary = {}
var _loaded: Dictionary = {}
var _away_since: Dictionary = {}
var _banned: Dictionary = {}
var _last_motion: Dictionary = {}
var _avatars: Dictionary = {}
var _puppets: Dictionary = {}
var _owner_pid := 0
var _match_config: Dictionary = {}
var _broadcast_timer := 0.0
var _time_timer := 0.0
var _load_deadline := -1.0
var _hello: Dictionary = {}
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	name = "Net"
	_rng.randomize()


func _exit_tree() -> void:
	close()


# --- Setup ---------------------------------------------------------------------------


func _install_multiplayer() -> void:
	_mp = SceneMultiplayer.new()
	_mp.server_relay = false
	_mp.allow_object_decoding = false
	_mp.auth_timeout = NetProtocol.AUTH_TIMEOUT
	get_tree().set_multiplayer(_mp, get_parent().get_path())


## Starts a server. `p_room` keys: room_id, code, map_id, difficulty_id, max_players.
## A LAN host also plays (pid 1) in the same process.
func host(
	port: int, p_room: Dictionary, p_trust: Trust, dtls_key: CryptoKey = null, dtls_cert: X509Certificate = null
) -> Error:
	_install_multiplayer()
	trust = p_trust
	_enet = ENetMultiplayerPeer.new()
	var max_clients := clampi(int(p_room.get("max_players", NetProtocol.MAX_PLAYERS)), 1, NetProtocol.MAX_PLAYERS)
	var err := _enet.create_server(port, max_clients)
	if err != OK:
		return err
	if dtls_key and dtls_cert:
		err = _enet.host.dtls_server_setup(TLSOptions.server(dtls_key, dtls_cert))
		if err != OK:
			return err
	_mp.auth_callback = _server_auth
	_mp.multiplayer_peer = _enet
	_mp.peer_connected.connect(_on_peer_connected)
	_mp.peer_disconnected.connect(_on_peer_disconnected)
	mode = Mode.SERVER
	expected_room_id = str(p_room.get("room_id", ""))
	room = {
		"room_id": expected_room_id,
		"code": str(p_room.get("code", "")),
		"map_id": str(p_room.get("map_id", "house")),
		"difficulty_id": str(p_room.get("difficulty_id", "normal")),
		"max_players": max_clients if trust == Trust.DEDICATED else mini(max_clients + 1, NetProtocol.MAX_PLAYERS),
		"trust": "dedicated" if trust == Trust.DEDICATED else "lan",
	}
	if trust == Trust.LAN_HOST:
		my_pid = 1
		_names[1] = NameValidator.normalize(host_name)
		_colors[1] = host_color
		_ready[1] = true
		_owner_pid = 1
		_pid_by_uid["lan-host"] = 1
	_publish_room()
	Log.info("net", "Server listening", {"port": port, "trust": room["trust"], "dtls": dtls_key != null})
	return OK


## Connects to a server. `hello` keys: ticket (online) or lan_id (LAN), name, color.
func join(address: String, port: int, hello: Dictionary, dtls_trusted: X509Certificate = null) -> Error:
	_install_multiplayer()
	_enet = ENetMultiplayerPeer.new()
	var err := _enet.create_client(address, port)
	if err != OK:
		return err
	if dtls_trusted:
		err = _enet.host.dtls_client_setup(address, TLSOptions.client(dtls_trusted, "localhost"))
		if err != OK:
			return err
	_hello = hello.duplicate()
	_hello["protocol"] = AppInfo.PROTOCOL_VERSION
	_hello["build"] = AppInfo.version()
	_mp.auth_callback = _client_auth
	_mp.peer_authenticating.connect(_on_client_authenticating)
	_mp.peer_authentication_failed.connect(func(_id: int) -> void: _fail("NET_REJECT_TIMEOUT"))
	_mp.connection_failed.connect(func() -> void: _fail("NET_UNREACHABLE"))
	_mp.server_disconnected.connect(_on_server_disconnected)
	# Only once both sides finished authenticating can RPCs reach the server.
	_mp.connected_to_server.connect(func() -> void: joined.emit(my_pid))
	_mp.multiplayer_peer = _enet
	mode = Mode.CLIENT
	return OK


func close() -> void:
	if _mp and _mp.multiplayer_peer:
		_mp.multiplayer_peer.close()
		_mp.multiplayer_peer = null
	if _mp and is_inside_tree() and get_parent():
		get_tree().set_multiplayer(null, get_parent().get_path())
	_mp = null
	mode = Mode.OFFLINE


func is_server() -> bool:
	return mode == Mode.SERVER


func phase() -> String:
	return _phase


# --- Server: authentication ------------------------------------------------------------


func _server_auth(peer: int, data: PackedByteArray) -> void:
	if data.size() > NetProtocol.MAX_AUTH_BYTES:
		_reject(peer, NetProtocol.REJECT_MALFORMED)
		return
	var parsed: Variant = JSON.parse_string(data.get_string_from_utf8())
	if not parsed is Dictionary:
		_reject(peer, NetProtocol.REJECT_MALFORMED)
		return
	var hello: Dictionary = parsed
	if int(hello.get("protocol", -1)) != AppInfo.PROTOCOL_VERSION:
		_reject(peer, NetProtocol.REJECT_VERSION)
		return
	var identity := _identify(hello)
	if not identity["ok"]:
		_reject(peer, identity["reason"])
		return
	var uid: String = identity["uid"]
	if _banned.has(uid):
		_reject(peer, NetProtocol.REJECT_KICKED)
		return
	var reconnect := _pid_by_uid.has(uid)
	if reconnect and _any_peer_for(int(_pid_by_uid[uid])):
		_reject(peer, "NET_REJECT_DUPLICATE")
		return
	if not reconnect:
		if _phase != PHASE_LOBBY:
			_reject(peer, NetProtocol.REJECT_STARTED)
			return
		if _names.size() >= int(room["max_players"]):
			_reject(peer, NetProtocol.REJECT_FULL)
			return
	var pid := int(_pid_by_uid[uid]) if reconnect else _next_pid()
	_pid_by_uid[uid] = pid
	_names[pid] = identity["name"]
	_colors[pid] = clampi(int(identity["color"]), 0, Saves.AVATAR_COLORS.size() - 1)
	if not reconnect:
		_ready[pid] = false
	_peers[peer] = {"uid": uid, "pid": pid, "reconnect": reconnect, "connected": false}
	# The lobby names the owner in their ticket; otherwise the first member owns.
	if _owner_pid == 0 or (bool(identity.get("owner", false)) and _phase == PHASE_LOBBY):
		_owner_pid = pid
	var reply := {"ok": true, "pid": pid, "reconnect": reconnect}
	_mp.send_auth(peer, JSON.stringify(reply).to_utf8_buffer())
	_mp.complete_auth(peer)


func _identify(hello: Dictionary) -> Dictionary:
	if trust == Trust.DEDICATED:
		var v := NetProtocol.verify_ticket(
			str(hello.get("ticket", "")), ticket_secret, expected_room_id, int(Time.get_unix_time_from_system())
		)
		if not v["ok"]:
			return {"ok": false, "reason": v["reason"]}
		var p: Dictionary = v["payload"]
		var ticket_name := str(p.get("name", ""))
		if NameValidator.validate(ticket_name) != NameValidator.Result.OK:
			return {"ok": false, "reason": NetProtocol.REJECT_NAME}
		return {
			"ok": true,
			"uid": str(p["uid"]),
			"name": NameValidator.normalize(ticket_name),
			"color": int(p.get("color", 0)),
			"owner": bool(p.get("own", false)),
		}
	# LAN development: no ticket; lower trust (documented). The id only keys reconnects.
	var lan_name := str(hello.get("name", ""))
	if NameValidator.validate(lan_name) != NameValidator.Result.OK:
		return {"ok": false, "reason": NetProtocol.REJECT_NAME}
	var lan_id := str(hello.get("lan_id", ""))
	if lan_id.length() < 8 or lan_id.length() > 64:
		return {"ok": false, "reason": NetProtocol.REJECT_MALFORMED}
	return {
		"ok": true,
		"uid": "lan-" + SaveIO.sha256_text(lan_id).substr(0, 16),
		"name": NameValidator.normalize(lan_name),
		"color": int(hello.get("color", 0))
	}


func _reject(peer: int, reason: String) -> void:
	Log.info("net", "Rejected connection", {"peer": peer, "reason": reason})
	# The client closes on rejection; a client that does not is dropped by the
	# SceneMultiplayer auth timeout because complete_auth() is never called.
	_mp.send_auth(peer, JSON.stringify({"ok": false, "reason": reason}).to_utf8_buffer())


func _any_peer_for(pid: int) -> bool:
	for peer in _peers:
		if int(_peers[peer]["pid"]) == pid:
			return true
	return false


func _next_pid() -> int:
	for pid in range(1, NetProtocol.MAX_PLAYERS + 1):
		if not _names.has(pid):
			return pid
	return -1


func _peer_of(pid: int) -> int:
	for peer in _peers:
		if int(_peers[peer]["pid"]) == pid and bool(_peers[peer]["connected"]):
			return int(peer)
	return 0


func _sender_pid(kind: String) -> int:
	if mode != Mode.SERVER:
		return 0
	var peer := _mp.get_remote_sender_id()
	if not _peers.has(peer):
		return 0
	if not limiter.allow(peer, kind, Time.get_ticks_msec() / 1000.0):
		if int(limiter.dropped.get(peer, 0)) > 400:
			Log.warn("net", "Disconnecting abusive peer", {"peer": peer})
			_drop_peer.call_deferred(peer)
		return 0
	return int(_peers[peer]["pid"])


# --- Server: lobby ----------------------------------------------------------------------


func _on_peer_connected(peer: int) -> void:
	if not _peers.has(peer):
		return
	var info: Dictionary = _peers[peer]
	info["connected"] = true
	var pid := int(info["pid"])
	if bool(info["reconnect"]) and _phase == PHASE_PLAYING:
		_rpc_to(peer, "_s_load", [_client_config(pid)])
	_publish_room()


func _on_peer_disconnected(peer: int) -> void:
	if not _peers.has(peer):
		return
	var pid := int(_peers[peer]["pid"])
	var uid := str(_peers[peer]["uid"])
	_peers.erase(peer)
	limiter.forget(peer)
	if _phase == PHASE_PLAYING and mc:
		_away_since[pid] = mc.state.elapsed
		mc.set_player_away(pid, true)
		var avatar: RemoteAvatar = _avatars.get(pid)
		if avatar:
			avatar.set_away(true)
	elif _phase != PHASE_ENDED:
		_names.erase(pid)
		_ready.erase(pid)
		_loaded.erase(pid)
		_pid_by_uid.erase(uid)
		if _owner_pid == pid:
			_owner_pid = _first_member()
		if _phase == PHASE_LOADING:
			_check_all_loaded()
	_publish_room()


func _first_member() -> int:
	var pids := _names.keys()
	pids.sort()
	for pid in pids:
		if trust == Trust.LAN_HOST and int(pid) == 1:
			return 1
		if _peer_of(int(pid)) != 0:
			return int(pid)
	return 0


func _publish_room() -> void:
	if mode != Mode.SERVER:
		return
	var members: Array = []
	var pids := _names.keys()
	pids.sort()
	for pid in pids:
		var connected := _peer_of(int(pid)) != 0 or (trust == Trust.LAN_HOST and int(pid) == 1)
		(
			members
			. append(
				{
					"pid": int(pid),
					"name": _names[pid],
					"color": int(_colors.get(pid, 0)),
					"ready": bool(_ready.get(pid, false)) or int(pid) == _owner_pid,
					"owner": int(pid) == _owner_pid,
					"away": not connected,
				}
			)
		)
	room["members"] = members
	room["owner_pid"] = _owner_pid
	room["phase"] = _phase
	room_updated.emit(room)
	_rpc_all("_s_room", [room])


@rpc("any_peer", "call_remote", "reliable")
func _c_set_ready(value: Variant) -> void:
	var pid := _sender_pid("lobby")
	if pid <= 0 or _phase != PHASE_LOBBY or not value is bool:
		return
	_ready[pid] = value
	_publish_room()


@rpc("any_peer", "call_remote", "reliable")
func _c_set_options(map_id: Variant, difficulty_id: Variant) -> void:
	var pid := _sender_pid("lobby")
	if pid <= 0 or pid != _owner_pid or _phase != PHASE_LOBBY:
		return
	server_set_options(map_id, difficulty_id)


func server_set_options(map_id: Variant, difficulty_id: Variant) -> void:
	if not (map_id is String and difficulty_id is String):
		return
	var def := Session.map_def(map_id)
	if def == null or not def.is_playable() or def.is_tutorial:
		return
	if Session.difficulty(difficulty_id) == null or not def.supported_difficulties.has(StringName(difficulty_id)):
		return
	room["map_id"] = map_id
	room["difficulty_id"] = difficulty_id
	_publish_room()


@rpc("any_peer", "call_remote", "reliable")
func _c_kick(target: Variant) -> void:
	var pid := _sender_pid("lobby")
	if pid <= 0 or pid != _owner_pid:
		return
	server_kick(target)


func server_kick(target: Variant) -> void:
	if _phase != PHASE_LOBBY or not target is int or int(target) == _owner_pid:
		return
	var peer := _peer_of(int(target))
	if peer == 0:
		return
	_banned[str(_peers[peer]["uid"])] = true
	_rpc_to(peer, "_s_kicked", [NetProtocol.REJECT_KICKED])
	get_tree().create_timer(0.2).timeout.connect(func() -> void: _drop_peer(peer))


@rpc("any_peer", "call_remote", "reliable")
func _c_start() -> void:
	var pid := _sender_pid("lobby")
	if pid <= 0 or pid != _owner_pid:
		return
	server_start()


## Owner (or LAN host) starts the match when every connected member is ready.
func server_start() -> bool:
	if _phase != PHASE_LOBBY or not can_start():
		return false
	_phase = PHASE_LOADING
	var members := _names.keys()
	members.sort()
	_match_config = {
		"mode": "online" if trust == Trust.DEDICATED else "lan",
		"map_id": room["map_id"],
		"difficulty_id": room["difficulty_id"],
		"seed": _rng.randi(),
		"match_id": Crypto.new().generate_random_bytes(12).hex_encode(),
		"player_count": members.size(),
		"authority": true,
	}
	var built := LevelLoader.build(world_parent, _match_config)
	if not built["ok"]:
		Log.error("net", "Server failed to build level", {"error": built["error"]})
		_phase = PHASE_LOBBY
		_publish_room()
		return false
	map = built["map"]
	mc = built["match"]
	mc.net = self
	mc.local_player_id = my_pid if trust == Trust.LAN_HOST else -1
	mc.enemy_spawned.connect(_on_enemy_spawned)
	for i in members.size():
		var pid := int(members[i])
		mc.add_player_record(pid, str(_names[pid]))
		var spawn := map.player_spawn(i)
		mc.state.players[pid]["pos"] = MatchState.vec_to_array(spawn.origin)
		mc.state.players[pid]["yaw"] = spawn.basis.get_euler().y
		if pid != my_pid:
			_spawn_avatar(pid, spawn.origin, spawn.basis.get_euler().y)
	if trust == Trust.LAN_HOST:
		local_player = LevelLoader.spawn_local_player(map, mc, my_pid, str(_names[my_pid]), members.find(my_pid))
		local_player.input_enabled = false
		_loaded[my_pid] = true
	for peer in _peers:
		if bool(_peers[peer]["connected"]):
			_rpc_to(int(peer), "_s_load", [_client_config(int(_peers[peer]["pid"]))])
	_load_deadline = Time.get_ticks_msec() / 1000.0 + NetProtocol.LOAD_TIMEOUT
	_publish_room()
	load_requested.emit(_match_config)
	_check_all_loaded()
	return true


func can_start() -> bool:
	if _names.is_empty():
		return false
	for pid in _names:
		var connected := _peer_of(int(pid)) != 0 or (trust == Trust.LAN_HOST and int(pid) == 1)
		if connected and int(pid) != _owner_pid and not bool(_ready.get(pid, false)):
			return false
	return true


func _client_config(pid: int) -> Dictionary:
	var cfg := _match_config.duplicate()
	cfg["authority"] = false
	cfg["pid"] = pid
	return cfg


@rpc("any_peer", "call_remote", "reliable")
func _c_loaded() -> void:
	var pid := _sender_pid("lobby")
	if pid <= 0 or mc == null:
		return
	if _phase == PHASE_PLAYING:
		# A reconnecting player finished loading: send state, then let them in.
		var peer := _peer_of(pid)
		_rpc_to(peer, "_s_snapshot", [_snapshot()])
		_rpc_to(peer, "_s_begin", [])
		_away_since.erase(pid)
		mc.set_player_away(pid, false)
		var avatar: RemoteAvatar = _avatars.get(pid)
		if avatar:
			avatar.set_away(false)
		_publish_room()
		return
	if _phase != PHASE_LOADING:
		return
	_loaded[pid] = true
	_check_all_loaded()


func _check_all_loaded() -> void:
	if _phase != PHASE_LOADING:
		return
	for peer in _peers:
		if bool(_peers[peer]["connected"]) and not bool(_loaded.get(int(_peers[peer]["pid"]), false)):
			return
	_begin_match()


func _begin_match() -> void:
	_phase = PHASE_PLAYING
	_load_deadline = -1.0
	# Players who never finished loading are treated as disconnected.
	for pid in _names:
		if not bool(_loaded.get(pid, false)) and int(pid) != my_pid:
			_away_since[pid] = 0.0
			mc.set_player_away(int(pid), true)
	mc.begin()
	var snap := _snapshot()
	for peer in _peers:
		if bool(_peers[peer]["connected"]):
			_rpc_to(int(peer), "_s_snapshot", [snap])
			_rpc_to(int(peer), "_s_begin", [])
	_publish_room()
	match_begun.emit()


func _snapshot() -> Dictionary:
	var enemies: Array = []
	for e in mc.enemies:
		if is_instance_valid(e):
			var w := e as Node3D
			enemies.append({"id": str(w.name), "pos": w.global_position, "yaw": w.rotation.y})
	return {"state": mc.state.client_snapshot(), "enemies": enemies}


# --- Server: gameplay intents ----------------------------------------------------------------

@rpc("any_peer", "call_remote", "unreliable_ordered", 1)
func _c_motion(pos: Variant, yaw: Variant, speed: Variant, flags: Variant) -> void:
	var pid := _sender_pid("motion")
	if pid <= 0 or mc == null or not mc.running:
		return
	if not (
		NetProtocol.finite_vec(pos) and NetProtocol.finite_num(yaw) and NetProtocol.finite_num(speed) and flags is int
	):
		return
	var p := mc.state.player(pid)
	if p.is_empty() or p["status"] != MatchState.STATUS_ALIVE or not str(p["hiding"]).is_empty():
		return
	var now := Time.get_ticks_msec() / 1000.0
	var last := float(_last_motion.get(pid, now - 0.1))
	_last_motion[pid] = now
	var old := MatchState.array_to_vec(p["pos"])
	var new_pos: Vector3 = pos
	var allowed := NetProtocol.MAX_PLAYER_SPEED * clampf(now - last, 0.05, 1.0) * 1.5 + 0.6
	if Vector2(new_pos.x - old.x, new_pos.z - old.z).length() > allowed or absf(new_pos.y - old.y) > 4.0:
		_rpc_to(_peer_of(pid), "_s_correct", [old])
		return
	var f := int(flags)
	mc.report_motion(pid, new_pos, float(yaw), clampf(float(speed), 0.0, 10.0), f & 1 != 0, f & 2 != 0, f & 4 != 0)
	var avatar: RemoteAvatar = _avatars.get(pid)
	if avatar:
		avatar.server_place(new_pos, float(yaw))


@rpc("any_peer", "call_remote", "reliable")
func _c_interact(entity_id: Variant, sub: Variant, action: Variant, args: Variant) -> void:
	var pid := _sender_pid("action")
	if pid <= 0 or mc == null:
		return
	if not (entity_id is String and sub is int and action is String and args is Dictionary):
		return
	if (entity_id as String).length() > 48:
		return
	mc.server_interact(pid, entity_id, sub, action, args)


@rpc("any_peer", "call_remote", "reliable")
func _c_drop(item: Variant) -> void:
	var pid := _sender_pid("action")
	if pid > 0 and mc and item is String and (item as String).length() <= 32:
		mc.drop_item(pid, item)


@rpc("any_peer", "call_remote", "reliable")
func _c_use_item(item: Variant) -> void:
	var pid := _sender_pid("action")
	if pid > 0 and mc and item is String and item == "battery":
		mc.use_battery(pid)


@rpc("any_peer", "call_remote", "reliable")
func _c_ping(pos: Variant, kind: Variant) -> void:
	var pid := _sender_pid("ping")
	if pid <= 0 or mc == null or not NetProtocol.finite_vec(pos) or not kind is int:
		return
	server_ping(pid, pos, clampi(kind, 0, 3))


func server_ping(pid: int, pos: Vector3, kind: int) -> void:
	var p := mc.state.player(pid)
	if p.is_empty() or p["status"] != MatchState.STATUS_ALIVE:
		return
	if MatchState.array_to_vec(p["pos"]).distance_to(pos) > 30.0:
		return
	ping_received.emit(pid, pos, kind)
	_rpc_all("_s_ping", [pid, pos, kind])


@rpc("any_peer", "call_remote", "reliable")
func _c_revive(target: Variant, start: Variant) -> void:
	var pid := _sender_pid("action")
	if pid > 0 and mc and target is int and start is bool:
		mc.server_revive(pid, target, start)


@rpc("any_peer", "call_remote", "reliable")
func _c_leave() -> void:
	var peer := _mp.get_remote_sender_id()
	if _peers.has(peer):
		_drop_peer.call_deferred(peer)


## Server-initiated disconnect. SceneMultiplayer.disconnect_peer() forgets the
## peer without emitting peer_disconnected, so record the departure first
## (away / left / lobby removal), then drop the connection.
func _drop_peer(peer: int) -> void:
	_on_peer_disconnected(peer)
	if _mp and _mp.multiplayer_peer and _mp.get_peers().has(peer):
		_mp.disconnect_peer(peer)


# --- Server: broadcasts (called by MatchController via net.call) --------------------------------


func broadcast_entity(id: String, st: Dictionary) -> void:
	_rpc_all("_s_entity", [id, st])


func broadcast_flag(flag: String) -> void:
	_rpc_all("_s_flag", [flag])


func broadcast_counters(counters: Dictionary) -> void:
	_rpc_all("_s_counters", [counters])


func broadcast_objectives(objectives: Dictionary) -> void:
	_rpc_all("_s_objectives", [objectives])


func broadcast_sound(sound: String, pos: Vector3, volume_db: float, max_distance: float) -> void:
	_rpc_all("_s_sound", [sound, pos, volume_db, max_distance])


func broadcast_damage(pid: int, hits: int) -> void:
	_rpc_all("_s_damage", [pid, hits])


func broadcast_status(pid: int, status: String) -> void:
	_rpc_all("_s_status", [pid, status])
	var avatar: RemoteAvatar = _avatars.get(pid)
	if avatar:
		avatar.set_status(status)


func broadcast_hiding(pid: int, spot: String) -> void:
	_rpc_all("_s_hiding", [pid, spot])
	var avatar: RemoteAvatar = _avatars.get(pid)
	if avatar:
		avatar.set_hidden(not spot.is_empty())


func send_inventory(pid: int, items: Array) -> void:
	var peer := _peer_of(pid)
	if peer != 0:
		_rpc_to(peer, "_s_inventory", [pid, items])


func send_notify(pid: int, key: String, args: Array) -> void:
	if pid == 0:
		_rpc_all("_s_notify", [key, args])
	else:
		var peer := _peer_of(pid)
		if peer != 0:
			_rpc_to(peer, "_s_notify", [key, args])


func broadcast_spawn_drop(id: String, item: String, pos: Vector3) -> void:
	_rpc_all("_s_spawn_drop", [id, item, pos])


func broadcast_finished(_result: Dictionary) -> void:
	_phase = PHASE_ENDED
	for peer in _peers:
		if bool(_peers[peer]["connected"]):
			var pid := int(_peers[peer]["pid"])
			_rpc_to(int(peer), "_s_finished", [mc.build_result(mc.state.result, pid)])
	_publish_room()


func broadcast_phase(phase_value: int) -> void:
	_rpc_all("_s_phase", [phase_value])


func send_recharge(pid: int) -> void:
	var peer := _peer_of(pid)
	if peer != 0:
		_rpc_to(peer, "_s_recharge", [])


func broadcast_revive(target: int, progress: float) -> void:
	revive_changed.emit(target, progress >= 0.0)
	_rpc_all("_s_revive", [target, progress >= 0.0])


func broadcast_away(pid: int, away: bool) -> void:
	_rpc_all("_s_away", [pid, away])


# --- Server: tick --------------------------------------------------------------------------------


func _physics_process(delta: float) -> void:
	if mode == Mode.SERVER:
		_server_tick(delta)
	elif mode == Mode.CLIENT and local_player and mc and mc.running:
		pass


func _server_tick(delta: float) -> void:
	if _phase == PHASE_LOADING and _load_deadline > 0.0 and Time.get_ticks_msec() / 1000.0 > _load_deadline:
		Log.warn("net", "Load barrier timed out; starting with loaded players")
		_begin_match()
	if _phase != PHASE_PLAYING or mc == null:
		return
	for pid in _away_since.keys():
		if mc.state.elapsed - float(_away_since[pid]) > reconnect_window:
			_away_since.erase(pid)
			mc.player_left(int(pid))
	_broadcast_timer -= delta
	if _broadcast_timer <= 0.0:
		_broadcast_timer = 1.0 / NetProtocol.BROADCAST_HZ
		_rpc_all_unreliable("_s_players", [_players_packet()])
		for e in mc.enemies:
			if is_instance_valid(e) and e is Watcher:
				var w: Watcher = e
				_rpc_all_unreliable(
					"_s_enemy", [str(w.name), w.global_position, w.rotation.y, w.net_anim(), w.net_lens()]
				)
	_time_timer -= delta
	if _time_timer <= 0.0:
		_time_timer = NetProtocol.TIME_SYNC_SECONDS
		_rpc_all_unreliable("_s_time", [mc.state.elapsed])


func _players_packet() -> Dictionary:
	var out := {}
	for pid in mc.state.players:
		var p: Dictionary = mc.state.players[pid]
		var flags := (1 if p.get("crouch", false) else 0) | (4 if p.get("flashlight", false) else 0)
		out[int(pid)] = [MatchState.array_to_vec(p["pos"]), float(p["yaw"]), flags]
	return out


func _on_enemy_spawned(enemy: Node) -> void:
	var w := enemy as Node3D
	if w.name.is_empty() or str(w.name).begins_with("@"):
		w.name = "watcher_%d" % mc.enemies.size()
	_rpc_all("_s_enemy_spawn", [str(w.name), w.global_position, w.rotation.y])


func _spawn_avatar(pid: int, pos: Vector3, yaw: float) -> RemoteAvatar:
	var a := RemoteAvatar.new()
	a.player_id = pid
	a.display_name = str(_names.get(pid, ""))
	a.color = Saves.AVATAR_COLORS[clampi(int(_colors.get(pid, 0)), 0, Saves.AVATAR_COLORS.size() - 1)]
	map.players_root.add_child(a)
	a.server_place(pos, yaw)
	_avatars[pid] = a
	mc.register_player(pid, a)
	return a


# --- Client: authentication ------------------------------------------------------------------


func _on_client_authenticating(id: int) -> void:
	if id == 1:
		_mp.send_auth(1, JSON.stringify(_hello).to_utf8_buffer())


func _client_auth(id: int, data: PackedByteArray) -> void:
	if id != 1:
		return
	var parsed: Variant = JSON.parse_string(data.get_string_from_utf8())
	if not parsed is Dictionary or not bool(parsed.get("ok", false)):
		var reason := (
			str(parsed.get("reason", NetProtocol.REJECT_MALFORMED))
			if parsed is Dictionary
			else NetProtocol.REJECT_MALFORMED
		)
		_fail(reason)
		return
	my_pid = int(parsed.get("pid", 0))
	_mp.complete_auth(1)


## Never close from inside a multiplayer callback: the API is mid-poll.
func _fail(reason: String) -> void:
	join_failed.emit(reason)
	close.call_deferred()


func _on_server_disconnected() -> void:
	disconnected.emit("NET_LOST")
	close.call_deferred()


# --- Client: requests ------------------------------------------------------------------------------


func set_ready(value: bool) -> void:
	if mode == Mode.CLIENT:
		rpc_id(1, "_c_set_ready", value)


func request_start() -> void:
	if mode == Mode.CLIENT:
		rpc_id(1, "_c_start")
	elif mode == Mode.SERVER and trust == Trust.LAN_HOST:
		server_start()


func request_kick(pid: int) -> void:
	if mode == Mode.CLIENT:
		rpc_id(1, "_c_kick", pid)
	elif mode == Mode.SERVER:
		server_kick(pid)


func request_options(map_id: String, difficulty_id: String) -> void:
	if mode == Mode.CLIENT:
		rpc_id(1, "_c_set_options", map_id, difficulty_id)
	elif mode == Mode.SERVER:
		server_set_options(map_id, difficulty_id)


func leave() -> void:
	if mode == Mode.CLIENT and _mp and _mp.multiplayer_peer:
		rpc_id(1, "_c_leave")
	close()


## Client: build the level announced by the server, then report loaded.
func client_build_level(config: Dictionary) -> bool:
	var built := LevelLoader.build(world_parent, config)
	if not built["ok"]:
		return false
	map = built["map"]
	mc = built["match"]
	mc.net = self
	mc.local_player_id = my_pid
	rpc_id(1, "_c_loaded")
	return true


func send_interact(entity_id: String, sub: int, action: String, args: Dictionary) -> void:
	if mode == Mode.CLIENT:
		rpc_id(1, "_c_interact", entity_id, sub, action, args)


func send_motion(pos: Vector3, yaw: float, speed: float, crouch: bool, sprint: bool, flashlight: bool) -> void:
	if mode == Mode.CLIENT:
		var flags := (1 if crouch else 0) | (2 if sprint else 0) | (4 if flashlight else 0)
		rpc_id(1, "_c_motion", pos, yaw, speed, flags)


func send_drop(item: String) -> void:
	if mode == Mode.CLIENT:
		rpc_id(1, "_c_drop", item)


func send_use_item(item: String) -> void:
	if mode == Mode.CLIENT:
		rpc_id(1, "_c_use_item", item)


func send_ping(pos: Vector3, kind: int) -> void:
	if mode == Mode.CLIENT:
		rpc_id(1, "_c_ping", pos, kind)
	elif mode == Mode.SERVER and mc:
		server_ping(my_pid, pos, kind)


func send_revive(target: int, start: bool) -> void:
	if mode == Mode.CLIENT:
		rpc_id(1, "_c_revive", target, start)
	elif mode == Mode.SERVER and mc:
		mc.server_revive(my_pid, target, start)


func rtt_ms() -> int:
	if mode != Mode.CLIENT or _enet == null:
		return -1
	var server_peer := _enet.get_peer(1)
	return int(server_peer.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME)) if server_peer else -1


# --- Client: incoming ----------------------------------------------------------------------------

@rpc("authority", "call_remote", "reliable")
func _s_room(data: Dictionary) -> void:
	room = data
	room_updated.emit(room)


@rpc("authority", "call_remote", "reliable")
func _s_kicked(reason: String) -> void:
	disconnected.emit(reason)
	close.call_deferred()


@rpc("authority", "call_remote", "reliable")
func _s_load(config: Dictionary) -> void:
	my_pid = int(config.get("pid", my_pid))
	load_requested.emit(config)


@rpc("authority", "call_remote", "reliable")
func _s_snapshot(data: Dictionary) -> void:
	if mc == null:
		return
	mc.client_apply_snapshot(data.get("state", {}))
	if local_player == null:
		var record := mc.state.player(my_pid)
		var start_pos := MatchState.array_to_vec(record.get("pos"))
		var start_yaw := float(record.get("yaw", 0.0))
		local_player = LevelLoader.spawn_local_player(map, mc, my_pid, str(record.get("name", "")))
		local_player.place(Transform3D(Basis(Vector3.UP, start_yaw), start_pos + Vector3(0, 0.05, 0)))
		mc.state.players[my_pid]["pos"] = MatchState.vec_to_array(start_pos)
		local_player.input_enabled = false
	for pid in mc.state.players:
		if int(pid) != my_pid and not _avatars.has(int(pid)):
			var rec: Dictionary = mc.state.players[pid]
			var a := RemoteAvatar.new()
			a.player_id = int(pid)
			a.display_name = str(rec.get("name", ""))
			map.players_root.add_child(a)
			a.target(MatchState.array_to_vec(rec.get("pos")), float(rec.get("yaw", 0.0)), true)
			a.set_status(str(rec.get("status", "")))
			_avatars[int(pid)] = a
			mc.register_player(int(pid), a)
	for e in data.get("enemies", []):
		_ensure_puppet(str(e["id"]), e["pos"], float(e["yaw"]))


@rpc("authority", "call_remote", "reliable")
func _s_begin() -> void:
	match_begun.emit()


@rpc("authority", "call_remote", "reliable")
func _s_entity(id: String, st: Dictionary) -> void:
	if mc:
		mc.client_apply_entity(id, st)


@rpc("authority", "call_remote", "reliable")
func _s_flag(flag: String) -> void:
	if mc:
		mc.client_apply_flag(flag)


@rpc("authority", "call_remote", "reliable")
func _s_counters(counters: Dictionary) -> void:
	if mc:
		mc.client_apply_counters(counters)


@rpc("authority", "call_remote", "reliable")
func _s_objectives(objectives: Dictionary) -> void:
	if mc:
		mc.client_apply_objectives(objectives)


@rpc("authority", "call_remote", "reliable")
func _s_sound(sound: String, pos: Vector3, volume_db: float, max_distance: float) -> void:
	if map:
		AudioService.play_3d(sound, map, pos, volume_db, max_distance)


@rpc("authority", "call_remote", "reliable")
func _s_damage(pid: int, hits: int) -> void:
	if mc:
		mc.client_apply_damage(pid, hits)


@rpc("authority", "call_remote", "reliable")
func _s_status(pid: int, status: String) -> void:
	if mc:
		mc.client_apply_status(pid, status)
	var avatar: RemoteAvatar = _avatars.get(pid)
	if avatar:
		avatar.set_status(status)


@rpc("authority", "call_remote", "reliable")
func _s_hiding(pid: int, spot: String) -> void:
	if mc:
		mc.client_apply_hiding(pid, spot)
	var avatar: RemoteAvatar = _avatars.get(pid)
	if avatar:
		avatar.set_hidden(not spot.is_empty())


@rpc("authority", "call_remote", "reliable")
func _s_inventory(pid: int, items: Array) -> void:
	if mc:
		mc.client_set_inventory(pid, items)


@rpc("authority", "call_remote", "reliable")
func _s_notify(key: String, args: Array) -> void:
	if mc:
		mc.client_notify(key, args)


@rpc("authority", "call_remote", "reliable")
func _s_spawn_drop(id: String, item: String, pos: Vector3) -> void:
	if mc and map and not mc.entities.has(id):
		mc.state.entities[id] = {"kind": "dropped", "item": item, "pos": MatchState.vec_to_array(pos), "taken": false}
		map.spawn_dropped_item(mc, id, item, pos)


@rpc("authority", "call_remote", "reliable")
func _s_finished(result: Dictionary) -> void:
	if mc:
		mc.client_apply_finished(result)


@rpc("authority", "call_remote", "reliable")
func _s_phase(phase_value: int) -> void:
	if mc:
		mc.client_apply_phase(phase_value)


@rpc("authority", "call_remote", "reliable")
func _s_recharge() -> void:
	if local_player:
		local_player.recharge_flashlight()


@rpc("authority", "call_remote", "reliable")
func _s_revive(target: int, active: bool) -> void:
	revive_changed.emit(target, active)


@rpc("authority", "call_remote", "reliable")
func _s_away(pid: int, away: bool) -> void:
	if mc and mc.state.players.has(pid):
		mc.state.players[pid]["away"] = away
	var avatar: RemoteAvatar = _avatars.get(pid)
	if avatar:
		avatar.set_away(away)


@rpc("authority", "call_remote", "reliable")
func _s_ping(pid: int, pos: Vector3, kind: int) -> void:
	ping_received.emit(pid, pos, kind)


@rpc("authority", "call_remote", "reliable")
func _s_enemy_spawn(id: String, pos: Vector3, yaw: float) -> void:
	_ensure_puppet(id, pos, yaw)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _s_players(data: Dictionary) -> void:
	if mc == null:
		return
	for key in data:
		var pid := int(key)
		var entry: Array = data[key]
		if mc.state.players.has(pid) and pid != my_pid:
			mc.state.players[pid]["pos"] = MatchState.vec_to_array(entry[0])
		var avatar: RemoteAvatar = _avatars.get(pid)
		if avatar:
			avatar.target(entry[0], float(entry[1]), false, int(entry[2]))


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _s_enemy(id: String, pos: Vector3, yaw: float, anim: String, lens: float) -> void:
	var puppet: Watcher = _puppets.get(id)
	if puppet:
		puppet.apply_net(pos, yaw, anim, lens)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _s_time(elapsed: float) -> void:
	if mc and absf(mc.state.elapsed - elapsed) > 0.15:
		mc.state.elapsed = elapsed


@rpc("authority", "call_remote", "reliable")
func _s_correct(pos: Vector3) -> void:
	if local_player:
		local_player.global_position = pos


func _ensure_puppet(id: String, pos: Variant, yaw: float) -> void:
	if _puppets.has(id) or map == null or not pos is Vector3:
		return
	var w := Watcher.new()
	w.name = id
	map.enemies_root.add_child(w)
	w.global_position = pos
	w.rotation.y = yaw
	w.setup(mc, map)
	_puppets[id] = w
	mc.enemies.append(w)


func avatars() -> Dictionary:
	return _avatars


## Server: the lobby user id behind a player slot ("" for LAN/host players).
func uid_of(pid: int) -> String:
	for uid in _pid_by_uid:
		if int(_pid_by_uid[uid]) == pid and not str(uid).begins_with("lan-"):
			return str(uid)
	return ""


# --- RPC helpers ---------------------------------------------------------------------------------


func _rpc_all(method: String, args: Array) -> void:
	if _mp == null or _mp.multiplayer_peer == null or _peers.is_empty():
		return
	for peer in _peers:
		if bool(_peers[peer]["connected"]):
			_rpc_to(int(peer), method, args)


func _rpc_all_unreliable(method: String, args: Array) -> void:
	_rpc_all(method, args)


func _rpc_to(peer: int, method: String, args: Array) -> void:
	if _mp == null or _mp.multiplayer_peer == null or peer == 0:
		return
	var call_args: Array = [peer, method]
	call_args.append_array(args)
	callv("rpc_id", call_args)
