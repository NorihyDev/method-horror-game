extends TestCase
## Match snapshots (checkpoints / reconnect payloads) and localization coverage.


func _state() -> MatchState:
	var s := MatchState.new()
	s.match_id = "m1"
	s.map_id = "house"
	s.difficulty_id = "normal"
	s.rng_seed = 99
	s.flags = {"power_on": true}
	s.counters = {"fuses_installed": 3}
	s.objectives = {"power": {"state": 2, "activated_at": 3.0}}
	s.entities = {"door_study": {"open": true, "locked": false}}
	s.variant = {"puzzle": {"code": "1234"}}
	var p := s.add_player(1, "Ann")
	p["pos"] = [1.0, 2.0, 3.0]
	p["inventory"] = [{"id": "fuse", "count": 1}]
	return s


func test_snapshot_round_trip() -> void:
	var snap := _state().to_snapshot()
	var json := JSON.stringify(snap)
	var back := MatchState.from_snapshot(JSON.parse_string(json))
	assert_true(back != null)
	assert_eq(back.match_id, "m1")
	assert_true(back.has_flag("power_on"))
	assert_eq(int(back.counters["fuses_installed"]), 3)
	assert_eq(int(back.objectives["power"]["state"]), 2)
	assert_eq(MatchState.array_to_vec(back.player(1)["pos"]), Vector3(1, 2, 3))
	assert_eq(str(back.variant["puzzle"]["code"]), "1234")


func test_client_snapshot_hides_answers() -> void:
	var snap := _state().client_snapshot()
	assert_true((snap["variant"] as Dictionary).is_empty(), "puzzle answers never sent to clients")


func test_malformed_snapshot_is_sanitized_or_rejected() -> void:
	assert_eq(MatchState.from_snapshot({"v": 999}), null, "unknown version rejected")
	var weird := {
		"v": 1,
		"player_count": 50,
		"phase": 77,
		"elapsed": -5,
		"flags": "nope",
		"players": {"0": {}, "-3": {}, "2": {"pos": ["a"], "inventory": "x"}},
		"objectives": {"o": {"state": 9}}
	}
	var s := MatchState.from_snapshot(weird)
	assert_true(s != null)
	assert_eq(s.player_count, NetProtocol.MAX_PLAYERS)
	assert_eq(int(s.phase), int(MatchState.Phase.ENDED))
	assert_eq(s.elapsed, 0.0)
	assert_true(s.flags.is_empty())
	assert_false(s.players.has(0), "invalid player ids dropped")
	assert_true(s.players.has(2))
	assert_eq((s.player(2)["inventory"] as Array).size(), 0)
	assert_eq(int(s.objectives["o"]["state"]), 2, "state clamped")


func test_string_tables_cover_code_keys() -> void:
	var en := _table("en")
	var fr := _table("fr")
	for key in en:
		assert_true(fr.has(key), "fr missing " + key)
		assert_eq(str(fr[key]).count("%"), str(en[key]).count("%"), "placeholder mismatch in " + key)
	for key in fr:
		assert_true(en.has(key), "en missing " + key)
	var referenced := _referenced_keys()
	var ignore := [
		"ACTIVE",
		"COMPLETE",
		"LOCKED",
		"METHOD",
		"III",
		"ORDER",
		"SFX",
		"ACTION_",
		"FILE_",
		"OPT_",
		"SET_",
		"SHOP_SLOT_",
		"CLR",
		# HTTP verbs, environment variable names and dynamic key prefixes.
		"GET",
		"POST",
		"PATCH",
		"DELETE",
		"NET_",
		"TEAM_",
		"SERVICE_ERROR",
		"METHOD_DTLS_CERT",
		"METHOD_DTLS_KEY",
		"METHOD_LOBBY_URL",
		"METHOD_SERVER_SECRET",
		"METHOD_TICKET_SECRET",
		"METHOD_RELAY_URL",
		# Relay protocol codes (services/relay), mapped to NET_ keys by RelayClient.
		"HOST_LEFT",
		"ROOM_NOT_FOUND",
		"ROOM_EXPIRED",
		"ROOM_FULL",
		"WRONG_PASSWORD",
		"LOCKED_OUT",
		"KICKED",
		"VERSION",
		"RATE_LIMITED",
		"MALFORMED",
		"UNREACHABLE",
		"TIMEOUT",
		"LOST",
		"LEFT",
		# Stenciled labels on world props (not UI text).
		"RELAY",
		"START",
	]
	for key in referenced:
		if ignore.has(key):
			continue
		assert_true(en.has(key), "en.json missing key referenced in code: " + key)


func _table(locale: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://localization/%s.json" % locale))


func _referenced_keys() -> Dictionary:
	var out := {}
	var re := RegEx.create_from_string('"([A-Z][A-Z0-9_]{2,})"')
	var stack: Array[String] = ["res://scripts"]
	while not stack.is_empty():
		var d: String = stack.pop_back()
		var dir := DirAccess.open(d)
		for sub in dir.get_directories():
			stack.append(d.path_join(sub))
		for f in dir.get_files():
			if f.ends_with(".gd"):
				for m in re.search_all(FileAccess.get_file_as_string(d.path_join(f))):
					out[m.get_string(1)] = true
	return out
