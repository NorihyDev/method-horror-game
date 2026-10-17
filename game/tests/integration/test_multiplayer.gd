extends TestCase
## Authoritative multiplayer over real localhost ENet: one dedicated-style
## server and two clients in this process, each on its own SceneMultiplayer
## branch and in its own isolated 3D/physics/navigation world.

const SECRET := "integration-test-secret-0123456789abcdef"  # gitleaks:allow (test-only value)
const ROOM := "room-it-1"

var server: Dictionary
var clients: Array[Dictionary] = []
var _port := 0


func _side(side_name: String) -> Dictionary:
	var root := Node.new()
	root.name = side_name
	add_child(root)
	var vp := SubViewport.new()
	vp.own_world_3d = true
	vp.size = Vector2i(32, 32)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	root.add_child(vp)
	var net := NetBridge.new()
	root.add_child(net)
	net.world_parent = vp
	return {"root": root, "vp": vp, "net": net, "events": []}


func _ticket(uid: String, name_text: String, exp_offset: int = 300, room_id: String = ROOM) -> String:
	return NetProtocol.make_ticket(
		{
			"v": 1,
			"room": room_id,
			"uid": uid,
			"name": name_text,
			"color": 1,
			"exp": int(Time.get_unix_time_from_system()) + exp_offset
		},
		SECRET
	)


func _start_server() -> void:
	_port = 24750 + randi() % 200
	server = _side("Server")
	var net: NetBridge = server["net"]
	net.ticket_secret = SECRET
	var err := net.host(
		_port,
		{"room_id": ROOM, "code": "123456", "map_id": "house", "difficulty_id": "normal", "max_players": 4},
		NetBridge.Trust.DEDICATED
	)
	assert_eq(err, OK, "server listens")


func _join(uid: String, name_text: String, ticket: String = "") -> Dictionary:
	var c := _side("Client_" + uid)
	var net: NetBridge = c["net"]
	net.joined.connect(func(pid: int) -> void: c["events"].append("joined:%d" % pid))
	net.join_failed.connect(func(reason: String) -> void: c["events"].append("failed:" + reason))
	net.load_requested.connect(
		func(cfg: Dictionary) -> void:
			c["events"].append("load")
			net.client_build_level(cfg)
	)
	net.match_begun.connect(func() -> void: c["events"].append("begun"))
	var t := ticket if not ticket.is_empty() else _ticket(uid, name_text)
	net.join("127.0.0.1", _port, {"ticket": t})
	return c


func _wait_for(predicate: Callable, max_frames: int = 600) -> bool:
	for i in max_frames:
		if predicate.call():
			return true
		await get_tree().physics_frame
	return false


func _has_event(c: Dictionary, prefix: String) -> bool:
	for e in c["events"]:
		if str(e).begins_with(prefix):
			return true
	return false


func after_each() -> void:
	for c in clients:
		if is_instance_valid(c["root"]):
			(c["net"] as NetBridge).close()
			c["root"].queue_free()
	if server and is_instance_valid(server["root"]):
		(server["net"] as NetBridge).close()
		server["root"].queue_free()
	clients.clear()
	await get_tree().process_frame


func test_full_session_lobby_to_shared_state() -> void:
	_start_server()
	var snet: NetBridge = server["net"]
	var a := _join("user-aaaaaaaa", "Ann")
	clients.append(a)
	assert_true(await _wait_for(func() -> bool: return _has_event(a, "joined")), "client A joined")
	var b := _join("user-bbbbbbbb", "Bob")
	clients.append(b)
	assert_true(await _wait_for(func() -> bool: return _has_event(b, "joined")), "client B joined")
	var anet: NetBridge = a["net"]
	var bnet: NetBridge = b["net"]
	assert_true(
		await _wait_for(func() -> bool: return (bnet.room.get("members", []) as Array).size() == 2),
		"both see the lobby"
	)
	assert_eq(int(snet.room["owner_pid"]), anet.my_pid, "first player owns the room")

	# Invalid tickets never reach the lobby.
	var bad := _join("user-cccccccc", "Cat", _ticket("user-cccccccc", "Cat", 300, "another-room"))
	clients.append(bad)
	assert_true(await _wait_for(func() -> bool: return _has_event(bad, "failed")), "wrong-room ticket rejected")
	var expired := _join("user-dddddddd", "Dan", _ticket("user-dddddddd", "Dan", -10))
	clients.append(expired)
	assert_true(
		await _wait_for(func() -> bool: return _has_event(expired, "failed:" + NetProtocol.REJECT_EXPIRED)),
		"expired ticket rejected"
	)
	assert_eq((snet.room["members"] as Array).size(), 2, "rejected peers never became members")

	# Only the owner can start, and only when everyone is ready.
	bnet.request_start()
	anet.request_start()
	await frames(20)
	assert_eq(snet.phase(), NetBridge.PHASE_LOBBY, "not started while B is not ready")
	bnet.set_ready(true)
	assert_true(await _wait_for(func() -> bool: return snet.can_start()), "B ready")
	anet.request_start()
	assert_true(
		await _wait_for(func() -> bool: return _has_event(a, "begun") and _has_event(b, "begun"), 900),
		"both clients began after the load barrier"
	)
	assert_eq(snet.phase(), NetBridge.PHASE_PLAYING)
	await frames(10)

	# Late joiners are refused once the match started.
	var late := _join("user-eeeeeeee", "Eve")
	clients.append(late)
	assert_true(
		await _wait_for(func() -> bool: return _has_event(late, "failed:" + NetProtocol.REJECT_STARTED)),
		"late join rejected"
	)

	# Each client sees itself and the other player.
	assert_true(anet.local_player != null and bnet.local_player != null, "local players spawned")
	assert_true(anet.avatars().has(bnet.my_pid) and bnet.avatars().has(anet.my_pid), "avatars spawned")
	assert_eq(anet.mc.state.variant.size(), 0, "clients never receive puzzle answers")

	# A client intention changes server state, which reaches the other client.
	anet.mc.request_interact("door_front", 0)
	assert_true(
		await _wait_for(func() -> bool: return snet.mc.state.has_flag("exit_found")), "server applied A's interaction"
	)
	assert_true(await _wait_for(func() -> bool: return bnet.mc.state.has_flag("exit_found")), "B received the flag")

	# Two players racing for one item: exactly one gets it.
	snet.map.place_pickup_state(snet.mc, "race_battery", "battery", "bt_foyer")
	snet.mc._restore_dynamic_entities()
	snet.mc.set_entity_state("race_battery", snet.mc.state.entities["race_battery"])
	assert_true(
		await _wait_for(
			func() -> bool: return anet.mc.entities.has("race_battery") and bnet.mc.entities.has("race_battery")
		),
		"pickup replicated"
	)
	anet.mc.state.players[anet.my_pid]["pos"] = snet.mc.state.players[anet.my_pid]["pos"]
	anet.mc.request_interact("race_battery", 0)
	bnet.mc.request_interact("race_battery", 0)
	await _wait_for(func() -> bool: return bool(snet.mc.state.entities["race_battery"].get("taken", false)))
	await frames(20)
	var a_has := snet.mc.has_item(anet.my_pid, "battery")
	var b_has := snet.mc.has_item(bnet.my_pid, "battery")
	assert_true(a_has != b_has, "exactly one player received the battery (a=%s b=%s)" % [a_has, b_has])

	# Cheating attempts are ignored by the server.
	var b_pos_before: Array = snet.mc.state.players[bnet.my_pid]["pos"].duplicate()
	bnet.rpc_id(1, "_c_motion", Vector3(19, 0, -6), 0.0, 4.0, 0)  # teleport to the exit
	bnet.rpc_id(1, "_c_motion", Vector3(NAN, 0, 0), 0.0, 4.0, 0)
	bnet.rpc_id(1, "_s_flag", "garage_open")  # server-only method
	bnet.rpc_id(1, "_c_interact", 42, "x", null, [])  # malformed
	bnet.rpc_id(1, "_c_kick", anet.my_pid)  # not owner (and match running)
	await frames(30)
	var b_pos_after: Array = snet.mc.state.players[bnet.my_pid]["pos"]
	assert_true(MatchState.array_to_vec(b_pos_after).distance_to(Vector3(19, 0, -6)) > 5.0, "teleport rejected")
	assert_true(
		MatchState.array_to_vec(b_pos_after).distance_to(MatchState.array_to_vec(b_pos_before)) < 3.0,
		"position not corrupted"
	)
	assert_false(snet.mc.state.has_flag("garage_open"), "client cannot call server-only RPCs")
	assert_eq(snet.mc.state.players[anet.my_pid]["status"], MatchState.STATUS_ALIVE, "nobody was kicked")

	# Disconnect and reconnect within the window: same player, full state back.
	var b_pid := bnet.my_pid
	bnet.close()
	assert_true(
		await _wait_for(func() -> bool: return bool(snet.mc.state.players[b_pid].get("away", false))),
		"server marks B away"
	)
	var b2 := _join("user-bbbbbbbb", "Bob")
	clients.append(b2)
	var b2net: NetBridge = b2["net"]
	assert_true(await _wait_for(func() -> bool: return _has_event(b2, "begun"), 900), "B rejoined the running match")
	assert_eq(b2net.my_pid, b_pid, "same player slot after reconnect")
	assert_true(b2net.mc.state.has_flag("exit_found"), "reconnect snapshot contains progress")
	assert_false(bool(snet.mc.state.players[b_pid].get("away", true)), "no longer away")
	assert_eq(b2net.mc.has_item(b_pid, "battery"), b_has, "inventory restored from server")


func test_lan_host_plays_and_hosts() -> void:
	_port = 24950 + randi() % 40
	server = _side("LanHost")
	var hnet: NetBridge = server["net"]
	hnet.host_name = "Host"
	assert_eq(
		hnet.host(
			_port,
			{"room_id": "lan", "map_id": "house", "difficulty_id": "story", "max_players": 3},
			NetBridge.Trust.LAN_HOST
		),
		OK
	)
	var c := _side("LanClient")
	clients.append(c)
	var cnet: NetBridge = c["net"]
	cnet.load_requested.connect(func(cfg: Dictionary) -> void: cnet.client_build_level(cfg))
	var joined_flag := [false]
	cnet.joined.connect(func(_pid: int) -> void: joined_flag[0] = true)
	cnet.join("127.0.0.1", _port, {"lan_id": "device-0123456789", "name": "Guest"})
	assert_true(await _wait_for(func() -> bool: return joined_flag[0]), "LAN client joined without a ticket")
	cnet.set_ready(true)
	assert_true(await _wait_for(func() -> bool: return hnet.can_start()))
	assert_true(hnet.server_start(), "host starts")
	assert_true(await _wait_for(func() -> bool: return hnet.phase() == NetBridge.PHASE_PLAYING, 900), "match running")
	assert_true(hnet.local_player != null, "host has its own player")
	assert_eq(str(hnet.room["trust"]), "lan", "room labeled as LAN trust")


## Server + two ready clients in a running match (enemy disabled).
func _running_match() -> Array[Dictionary]:
	_start_server()
	var snet: NetBridge = server["net"]
	var a := _join("user-aaaaaaaa", "Ann")
	clients.append(a)
	var b := _join("user-bbbbbbbb", "Bob")
	clients.append(b)
	await _wait_for(func() -> bool: return _has_event(a, "joined") and _has_event(b, "joined"))
	(b["net"] as NetBridge).set_ready(true)
	await _wait_for(func() -> bool: return snet.can_start() and (snet.room["members"] as Array).size() == 2)
	(a["net"] as NetBridge).request_start()
	await _wait_for(func() -> bool: return _has_event(a, "begun") and _has_event(b, "begun"), 900)
	snet.mc.enemy_enabled = false
	return [a, b]


func test_downed_revive_cancel_and_bleed_out() -> void:
	var pair := await _running_match()
	var snet: NetBridge = server["net"]
	var anet: NetBridge = pair[0]["net"]
	var bnet: NetBridge = pair[1]["net"]
	assert_eq(snet.phase(), NetBridge.PHASE_PLAYING, "match running")
	var a_pid := anet.my_pid
	var b_pid := bnet.my_pid
	var revive_events: Array = []
	bnet.revive_changed.connect(func(target: int, active: bool) -> void: revive_events.append([target, active]))
	# A stops sending motion so the test controls A's authoritative position.
	anet.local_player.set_physics_process(false)
	var b_pos := MatchState.array_to_vec(snet.mc.state.players[b_pid]["pos"])
	snet.mc.state.players[a_pid]["pos"] = MatchState.vec_to_array(b_pos + Vector3(1.0, 0, 0))

	# Enough hits put B down (not dead) in co-op, on every peer.
	for i in snet.mc.difficulty.player_hits:
		snet.mc.damage_player(b_pid)
	assert_eq(snet.mc.state.players[b_pid]["status"], MatchState.STATUS_DOWNED)
	assert_true(
		await _wait_for(func() -> bool: return bnet.mc.state.players[b_pid]["status"] == MatchState.STATUS_DOWNED),
		"B sees itself downed"
	)
	assert_true(
		await _wait_for(func() -> bool: return anet.mc.state.players[b_pid]["status"] == MatchState.STATUS_DOWNED),
		"A sees B downed"
	)

	# A downed player cannot act; a far-away teammate cannot start a revive.
	assert_false(snet.mc.server_interact(b_pid, "door_front", 0, "use", {}), "downed players cannot interact")
	snet.mc.state.players[a_pid]["pos"] = MatchState.vec_to_array(b_pos + Vector3(6.0, 0, 0))
	assert_false(snet.mc.server_revive(a_pid, b_pid, true), "revive refused out of range")

	# In range: the revive runs for revive_time, then B is back up on every peer.
	snet.mc.state.players[a_pid]["pos"] = MatchState.vec_to_array(b_pos + Vector3(1.0, 0, 0))
	anet.send_revive(b_pid, true)
	assert_true(await _wait_for(func() -> bool: return snet.mc.revive_progress(b_pid) >= 0.0), "revive started")
	assert_true(
		await _wait_for(func() -> bool: return bnet.mc.state.players[b_pid]["status"] == MatchState.STATUS_ALIVE, 900),
		"B revived"
	)
	assert_true(revive_events.has([b_pid, true]) and revive_events.has([b_pid, false]), "revive progress replicated")
	assert_eq(int(snet.mc.state.players[b_pid]["hits"]), snet.mc.difficulty.player_hits - 1, "revived on last hit")

	# Walking away cancels a revive in progress.
	snet.mc.damage_player(b_pid)
	assert_eq(snet.mc.state.players[b_pid]["status"], MatchState.STATUS_DOWNED, "down again")
	anet.send_revive(b_pid, true)
	assert_true(await _wait_for(func() -> bool: return snet.mc.revive_progress(b_pid) >= 0.0), "second revive started")
	snet.mc.state.players[a_pid]["pos"] = MatchState.vec_to_array(b_pos + Vector3(8.0, 0, 0))
	assert_true(await _wait_for(func() -> bool: return snet.mc.revive_progress(b_pid) < 0.0), "revive cancelled")
	assert_eq(snet.mc.state.players[b_pid]["status"], MatchState.STATUS_DOWNED, "still down after cancel")

	# Nobody helps: B bleeds out and dies; the match goes on while A is alive.
	var quick: DifficultyDefinition = snet.mc.difficulty.duplicate()
	quick.bleedout_time = 0.5
	snet.mc.difficulty = quick
	assert_true(
		await _wait_for(func() -> bool: return anet.mc.state.players[b_pid]["status"] == MatchState.STATUS_DEAD),
		"B bled out"
	)
	assert_false(snet.mc.is_finished(), "match continues while A lives")

	# Last one standing goes down too: nobody can revive, the match ends in defeat.
	for i in snet.mc.difficulty.player_hits:
		snet.mc.damage_player(a_pid)
	assert_true(await _wait_for(func() -> bool: return anet.mc.is_finished()), "A's client sees the end")
	assert_eq(snet.mc.state.result, "defeat")
