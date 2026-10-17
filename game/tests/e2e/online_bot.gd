extends Node
## End-to-end online bot (development builds only). Drives the real client
## path — LobbyClient → OnlineFlow → lobby / loading / gameplay screens —
## against a running lobby service and the dedicated server it spawns.
##
## Started by services/lobby/scripts/e2e-online.ts:
##   godot --headless --path game -- --bot --role=owner --lobby=http://127.0.0.1:PORT
##   godot --headless --path game -- --bot --role=guest --code=123456 --lobby=...
## Prints "BOT_EVENT <name> <data>" lines; exits 0 on success, 1 on failure.

const PASSWORD := "e2e-pass"
const STEP_TIMEOUT := 60.0

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


## A fresh flow with its own guest identity (bots never share a session file).
func _new_flow() -> OnlineFlow:
	flow = Session.ensure_online()
	flow.lobby.session_path = "user://test_bot_%s_session.json" % role
	flow.lobby.token = ""
	flow.lobby.user = {}
	flow.lobby.call("_load_session")
	return flow


func _screen() -> String:
	return str(app.current().name) if app.current() else ""


func _in_gameplay() -> bool:
	return flow != null and flow.in_match and _screen() == "Gameplay"


func _net() -> NetBridge:
	return flow.net if flow else null


# --- Owner -------------------------------------------------------------------------------------


func _owner() -> bool:
	_new_flow()
	var err := await flow.create_online("house", "story", 2, PASSWORD)
	if not err.is_empty():
		return _fail("create_online: " + err)
	if not await _wait(func() -> bool: return _screen() == "Lobby"):
		return _fail("never reached the lobby screen")
	_event("code", flow.display_code())
	if not await _wait(func() -> bool: return _net().my_pid > 0 and _is_owner()):
		return _fail("not the room owner")
	_event("owner")
	if not await _wait(func() -> bool: return _members() == 2 and _all_ready(), 120.0):
		return _fail("guest never joined and readied (members=%d)" % _members())
	_event("guest_ready")
	_net().request_start()
	if not await _wait(_in_gameplay, 90.0):
		return _fail("match did not begin (screen=%s)" % _screen())
	_event("in_match", str(_net().my_pid))
	var mc := _net().mc
	if mc.state.variant.size() != 0:
		return _fail("client received puzzle answers")
	mc.request_interact("door_front", 0)
	if not await _wait(func() -> bool: return mc.state.has_flag("exit_found")):
		return _fail("server did not apply the owner's interaction")
	_event("interaction_applied")
	# The guest drops and reconnects; watch it go away and come back.
	var guest := _other_pid()
	if not await _wait(func() -> bool: return bool(mc.state.player(guest).get("away", false)), 90.0):
		return _fail("guest never dropped")
	_event("teammate_away")
	if not await _wait(func() -> bool: return not bool(mc.state.player(guest).get("away", true)), 90.0):
		return _fail("guest never came back")
	_event("teammate_back")
	if not await _wait(func() -> bool: return _guest_left(mc, guest), 90.0):
		return _fail("guest never left")
	# Leave too; the server ends the match after the reconnect window and
	# reports results to the lobby, which records them in the verified wallet.
	var lobby := flow.lobby
	var client := LobbyClient.new()
	client.session_path = lobby.session_path
	add_child(client)
	client.token = lobby.token
	Session.quit_to_menu()
	var recorded := false
	var deadline := Time.get_ticks_msec() + 120000
	while Time.get_ticks_msec() < deadline and not recorded:
		await get_tree().create_timer(2.0).timeout
		var w := await client.wallet()
		if int(w["status"]) == 200:
			for entry in w["json"].get("ledger", []):
				if str(entry.get("reason", "")) == "match":
					recorded = true
	if not recorded:
		return _fail("match result never reached the verified wallet")
	_event("result_recorded")
	return await _check_online_shop(client)


## The real shop screen with the online wallet, as the same guest (the shop's
## own client reads the default session file, so hand it this bot's token).
func _check_online_shop(client: LobbyClient) -> bool:
	var shared := LobbyClient.new()
	add_child(shared)
	shared.token = client.token
	shared.call("_save_session")
	var shop: Screen = app.goto("shop")
	shop.call("_switch", 1)
	if not await _wait(func() -> bool: return bool(shop.get("_online_ready")), 30.0):
		return _fail("shop never loaded the online wallet")
	if Saves.online_balance != 0:
		return _fail("unexpected online balance %d after a defeat" % Saves.online_balance)
	_event("shop_online_wallet")
	var item := Saves.catalog.get_item("flashlight_sodium")
	shop.call("_buy_online", "flashlight_sodium", item)
	if not await _wait(func() -> bool: return app.has_modal(), 30.0):
		return _fail("no answer to the online purchase")
	if Saves.online_owned.has("flashlight_sodium"):
		return _fail("an unaffordable online purchase went through")
	_event("shop_purchase_refused")
	return true


func _is_owner() -> bool:
	return int(_net().room.get("owner_pid", 0)) == _net().my_pid


func _members() -> int:
	return (_net().room.get("members", []) as Array).size()


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


func _guest_left(mc: MatchController, guest: int) -> bool:
	var p := mc.state.player(guest)
	return bool(p.get("away", false)) or str(p.get("status", "")) == MatchState.STATUS_LEFT


# --- Guest ---------------------------------------------------------------------------------------


func _guest() -> bool:
	var code := AppInfo.arg_value("--code", "")
	_new_flow()
	# A wrong password is refused before any connection is made.
	var err := await flow.join_online(code, "not-the-password")
	if err != "NET_PASSWORD_WRONG":
		return _fail("wrong password gave '%s'" % err)
	_event("wrong_password_refused")
	flow.leave()
	# Unknown codes fail cleanly too.
	_new_flow()
	err = await flow.join_online("000000" if code != "000000" else "111111", PASSWORD)
	if err != "NET_ROOM_NOT_FOUND":
		return _fail("unknown code gave '%s'" % err)
	_event("unknown_code_refused")
	flow.leave()
	_new_flow()
	err = await flow.join_online(code, PASSWORD)
	if not err.is_empty():
		return _fail("join_online: " + err)
	if not await _wait(func() -> bool: return _screen() == "Lobby"):
		return _fail("never reached the lobby screen")
	_event("joined", str(_net().my_pid))
	_net().set_ready(true)
	if not await _wait(_in_gameplay, 120.0):
		return _fail("match did not begin (screen=%s)" % _screen())
	_event("in_match", str(_net().my_pid))
	if not await _wait(func() -> bool: return _net().mc.state.has_flag("exit_found")):
		return _fail("owner's interaction never replicated")
	_event("saw_interaction")
	# Simulate a dropped connection; the flow must reconnect with a fresh
	# ticket and receive a full snapshot before controlling the player again.
	var pid := _net().my_pid
	_net().close()
	flow.call("_on_disconnected", "NET_LOST")
	if not await _wait(func() -> bool: return _screen() == "Loading", 10.0):
		return _fail("no reconnect screen")
	if not await _wait(_in_gameplay, 90.0):
		return _fail("did not rejoin the match (screen=%s)" % _screen())
	if _net().my_pid != pid:
		return _fail("rejoined into another slot")
	if not _net().mc.state.has_flag("exit_found"):
		return _fail("reconnect snapshot lacked progress")
	_event("reconnected_with_state")
	await get_tree().create_timer(2.0).timeout
	Session.quit_to_menu()
	await get_tree().create_timer(1.0).timeout
	return true
