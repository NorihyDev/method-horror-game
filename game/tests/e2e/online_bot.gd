extends Node
## End-to-end online bot (development builds only). Drives the real client
## path — RelayClient → OnlineFlow → lobby / loading / gameplay / results
## screens — through a running METHOD relay (local `wrangler dev` or the
## deployed Worker). Two separate processes, owner and guest:
##
##   godot --headless --path game -- --bot --role=owner --relay=<url>
##   godot --headless --path game -- --bot --role=guest --code=123456 --relay=<url>
##
## Started by services/relay/scripts/e2e-relay.ts. Prints "BOT_EVENT <name>
## <data>" lines; exits 0 on success, 1 on failure.

const PASSWORD := "e2e-pass"
const STEP_TIMEOUT := 60.0
## Second room (host departure test): the owner writes its code here.
const ROOM2_FILE := "user://e2e_relay_room2.txt"

var role := ""
var app: App
var flow: OnlineFlow


func _ready() -> void:
	app = get_parent() as App
	role = AppInfo.arg_value("--role", "owner")
	Settings.set_value("auto_reconnect", true, false)
	Saves.set_display_name("Bot " + role.capitalize())
	_run.call_deferred()


func _run() -> void:
	var ok := false
	if role == "owner":
		ok = await _owner()
	else:
		ok = await _guest()
	if ok:
		_event("done")
		get_tree().quit(0)


func _event(event_name: String, data: String = "") -> void:
	print("BOT_EVENT %s %s" % [event_name, data])


func _fail(why: String) -> bool:
	printerr("BOT_FAIL [%s] %s" % [role, why])
	get_tree().quit(1)
	return false


func _wait(predicate: Callable, timeout: float = STEP_TIMEOUT) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if predicate.call():
			return true
		await get_tree().process_frame
	return false


func _new_flow() -> OnlineFlow:
	flow = Session.ensure_online()
	return flow


## The current screen by its script ("Lobby", "Gameplay", "Results"...): node
## names get auto-suffixed while a previous instance is still being freed.
func _screen() -> String:
	var screen := app.current()
	if screen == null or screen.get_script() == null:
		return ""
	return (screen.get_script() as Script).resource_path.get_file().trim_suffix("_screen.gd").capitalize()


func _in_gameplay() -> bool:
	return flow != null and is_instance_valid(flow) and flow.in_match and _screen() == "Gameplay"


## Frames this client sent to the relay per second over `seconds` of play.
func _measure_rate(seconds: float) -> float:
	var peer := flow.relay_peer
	var before := peer.frames_sent
	await get_tree().create_timer(seconds).timeout
	return (peer.frames_sent - before) / seconds


func _net() -> NetBridge:
	return flow.net if flow and is_instance_valid(flow) else null


# --- Owner (room creator, hosts the match) -------------------------------------------------------


func _owner() -> bool:
	_new_flow()
	var err := await flow.create_online("house", "story", 2, PASSWORD)
	if not err.is_empty():
		return _fail("create_online: " + err)
	if not await _wait(func() -> bool: return _screen() == "Lobby"):
		return _fail("never reached the lobby screen")
	_event("code", flow.display_code())
	if not _is_owner():
		return _fail("the creator does not own the room")
	_event("owner")
	if not await _wait(func() -> bool: return _members() == 2 and _all_ready(), 120.0):
		return _fail("guest never joined and readied (members=%d)" % _members())
	_event("guest_ready")
	_net().request_start()
	if not await _wait(_in_gameplay, 90.0):
		return _fail("match did not begin (screen=%s)" % _screen())
	_event("in_match", str(_net().my_pid))
	var mc := _net().mc
	mc.request_interact("door_front", 0)
	if not await _wait(func() -> bool: return mc.state.has_flag("exit_found")):
		return _fail("host did not apply its own interaction")
	_event("interaction_applied")
	# Bring the monster in now; the host simulates it and relays its state.
	mc.set("_enemy_arrival_at", 0.0)
	if not await _wait(func() -> bool: return not mc.enemies.is_empty(), 60.0):
		return _fail("monster never spawned on the host")
	_event("monster_spawned")
	var guest := _other_pid()
	var start := MatchState.array_to_vec(mc.state.player(guest)["pos"])
	var moved := func() -> bool: return MatchState.array_to_vec(mc.state.player(guest)["pos"]).distance_to(start) > 0.8
	if not await _wait(moved, 60.0):
		return _fail("guest movement never reached the host")
	_event("guest_movement_synced")
	_event("host_frames_per_second", "%.1f" % await _measure_rate(10.0))
	if not await _wait(func() -> bool: return bool(mc.state.player(guest).get("away", false)), 90.0):
		return _fail("guest never dropped")
	_event("teammate_away")
	if not await _wait(func() -> bool: return not bool(mc.state.player(guest).get("away", true)), 90.0):
		return _fail("guest never came back")
	_event("teammate_back")
	# Finish the match: open the garage and let both players escape.
	await get_tree().create_timer(2.0).timeout
	mc.set_flag("garage_open")
	mc.player_escaped(guest)
	mc.player_escaped(_net().my_pid)
	if not await _wait(func() -> bool: return mc.is_finished(), 30.0):
		return _fail("match did not finish")
	_event("match_finished")
	await get_tree().create_timer(5.0).timeout
	return await _owner_host_departure()


## A second room: the guest joins, then the host leaves and the guest must be
## told the room ended (not left hanging).
func _owner_host_departure() -> bool:
	Session.quit_to_menu()
	await get_tree().create_timer(1.5).timeout
	_new_flow()
	var err := await flow.create_online("house", "normal", 4, "")
	if not err.is_empty():
		return _fail("second create_online: " + err)
	var f := FileAccess.open(ROOM2_FILE, FileAccess.WRITE)
	f.store_string(flow.display_code())
	f.close()
	_event("room2", flow.display_code())
	if not await _wait(func() -> bool: return _members() == 2, 120.0):
		return _fail("guest never joined room 2")
	_event("room2_guest_joined")
	await get_tree().create_timer(2.0).timeout
	Session.quit_to_menu()
	_event("host_left")
	await get_tree().create_timer(3.0).timeout
	return true


func _is_owner() -> bool:
	return int(_net().room.get("owner_pid", 0)) == _net().my_pid


func _members() -> int:
	var net := _net()
	return (net.room.get("members", []) as Array).size() if net else 0


func _all_ready() -> bool:
	for m in _net().room.get("members", []):
		if not bool(m.get("ready", false)) or bool(m.get("away", false)):
			return false
	return true


func _other_pid() -> int:
	for pid in _net().mc.state.players:
		if int(pid) != _net().my_pid:
			return int(pid)
	return -1


# --- Guest ---------------------------------------------------------------------------------------


func _guest() -> bool:
	var code := AppInfo.arg_value("--code", "")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ROOM2_FILE))
	if not await _refused(code, "not-the-password", "NET_PASSWORD_WRONG"):
		return false
	_event("wrong_password_refused")
	if not await _refused("000000" if code != "000000" else "111111", PASSWORD, "NET_ROOM_NOT_FOUND"):
		return false
	_event("unknown_code_refused")
	return await _guest_match(code)


func _guest_match(code: String) -> bool:
	_new_flow()
	var err := await flow.join_online(code, PASSWORD)
	if not err.is_empty():
		return _fail("join_online: " + err)
	if not await _wait(func() -> bool: return _screen() == "Lobby"):
		return _fail("never reached the lobby screen (last error %s)" % OnlineFlow.last_abort)
	_event("joined", str(_net().my_pid))
	_net().set_ready(true)
	if not await _wait(_in_gameplay, 120.0):
		return _fail("match did not begin (screen=%s)" % _screen())
	_event("in_match", str(_net().my_pid))
	var mc := _net().mc
	if mc.state.variant.size() != 0:
		return _fail("a guest received the puzzle answers")
	if not await _wait(func() -> bool: return mc.state.has_flag("exit_found")):
		return _fail("host's interaction never replicated")
	_event("saw_interaction")
	if not await _wait(func() -> bool: return not mc.enemies.is_empty(), 60.0):
		return _fail("monster never replicated")
	var puppet: Node3D = mc.enemies[0]
	var p0 := puppet.global_position
	_event("monster_replicated", str(p0.snapped(Vector3.ONE * 0.1)))
	# Walk forward in small steps, like a player would.
	var me := _net().local_player
	var dir := -me.global_basis.z
	dir.y = 0.0
	for i in 40:
		me.global_position += dir.normalized() * 0.05
		await get_tree().physics_frame
	_event("walked")
	_event("guest_frames_per_second", "%.1f" % await _measure_rate(10.0))
	if not await _wait(func() -> bool: return puppet.global_position.distance_to(p0) > 0.3, 60.0):
		_event("monster_static", "the monster did not move in 60 s (may be idle)")
	else:
		_event("monster_moves_on_guest")
	# Drop the connection: the flow rejoins the same room and slot and gets
	# a full snapshot before control returns.
	var pid := _net().my_pid
	_net().close()
	flow.call("_on_disconnected", "NET_LOST")
	if not await _wait(func() -> bool: return _screen() == "Loading", 10.0):
		return _fail("no reconnect screen")
	if not await _wait(_in_gameplay, 90.0):
		return _fail("did not rejoin the match (screen=%s, error=%s)" % [_screen(), OnlineFlow.last_abort])
	if _net().my_pid != pid:
		return _fail("rejoined into another slot")
	if not _net().mc.state.has_flag("exit_found"):
		return _fail("reconnect snapshot lacked progress")
	_event("reconnected_with_state")
	return await _guest_results()


func _guest_results() -> bool:
	# The host finishes the match: results must arrive here.
	if not await _wait(func() -> bool: return _screen() == "Results", 60.0):
		return _fail("never saw the results (screen=%s)" % _screen())
	_event("match_completed_on_guest")
	Session.quit_to_menu()
	return await _guest_host_departure()


func _guest_host_departure() -> bool:
	if not await _wait(func() -> bool: return FileAccess.file_exists(ROOM2_FILE), 90.0):
		return _fail("owner never opened room 2")
	await get_tree().create_timer(0.5).timeout
	var code2 := FileAccess.get_file_as_string(ROOM2_FILE).strip_edges()
	_new_flow()
	var err := await flow.join_online(code2, "")
	if not err.is_empty():
		return _fail("join room 2: " + err)
	if not await _wait(func() -> bool: return _screen() == "Lobby"):
		return _fail("never reached room 2's lobby")
	_event("room2_joined")
	var left := func() -> bool: return _screen() == "Multiplayer" and app.has_modal()
	if not await _wait(left, 60.0):
		return _fail("host departure was not reported (screen=%s)" % _screen())
	var why := OnlineFlow.last_abort
	if why != "NET_HOST_LEFT":
		return _fail("host departure reported as %s" % why)
	_event("host_left_reported")
	return true


## Joins expecting the relay to refuse with `expected`.
func _refused(code: String, password: String, expected: String) -> bool:
	_new_flow()
	var err := await flow.join_online(code, password)
	if not err.is_empty():
		return _fail("join_online(%s) returned %s immediately" % [code, err])
	var back := func() -> bool: return _screen() == "Multiplayer" and app.has_modal()
	if not await _wait(back, 30.0):
		return _fail("no refusal for %s (screen=%s)" % [code, _screen()])
	if OnlineFlow.last_abort != expected:
		return _fail("expected %s, got %s" % [expected, OnlineFlow.last_abort])
	app.close_all_modals()
	await get_tree().create_timer(0.5).timeout
	return true
