extends HouseFixture
## Plays The Black Ward start to finish through authoritative interactions,
## including the failure branches: a missing relay, a wrong breaker pattern
## (trips everything), a wrong security code and an unpowered console.


func test_full_escape() -> void:
	if not await build("black_ward", "normal", 4242):
		return
	assert_empty(mc.rules.validate(), "rules")
	var puzzle := mc.puzzle()

	# 1. The ambulance-bay shutter has no power: "find a way out" completes.
	put(Vector3(4.0, 0.05, 1.2))
	assert_true(await use("bay_shutter"))
	assert_true(mc.state.has_flag("exit_found"), "trying the shutter completes 'find a way out'")

	# 2. The bay console cannot be reached yet and would refuse without power anyway.
	assert_true(bool(mc.state.entities["door_security"]["locked"]), "security office starts locked")

	# 3. Staff card → staff wing (card reader).
	approach("door_staff")
	assert_true(await use("door_staff"))
	assert_true(bool(mc.state.entities["door_staff"]["locked"]), "no card, no entry")
	await take(pickup_for_slot("staff_card"))
	approach("door_staff")
	assert_true(await use("door_staff"))
	assert_false(bool(mc.state.entities["door_staff"]["locked"]), "card opens the staff wing")
	assert_true(mc.state.has_flag("staff_open"))

	# 4. Emergency power: no relay → refused; wrong pattern → trip; right → power.
	var schematic: Array = mc.state.entities["note_schematic"]["args"]
	assert_eq(schematic.size(), EmergencyPanel.BREAKERS, "schematic lists every circuit")
	approach("door_generator")
	await use("door_generator")
	put(Vector3(9.0, 0.05, 14.0))
	assert_true(await use("emergency_panel", EmergencyPanel.SUB_START))
	assert_false(mc.state.has_flag("ward_power"), "no relay, no start")
	await take(pickup_for_slot("starter_relay"))
	put(Vector3(9.0, 0.05, 14.0))
	assert_true(await use("emergency_panel", EmergencyPanel.SUB_RELAY))
	assert_true(bool(mc.state.entities["emergency_panel"]["relay"]), "relay fitted")
	var circuit: Array = puzzle["circuit"]
	# Set exactly the wrong breakers first.
	for i in EmergencyPanel.BREAKERS:
		if not bool(circuit[i]):
			assert_true(await use("emergency_panel", i + 1))
	assert_true(await use("emergency_panel", EmergencyPanel.SUB_START))
	assert_false(mc.state.has_flag("ward_power"), "wrong pattern does not start")
	for on in mc.state.entities["emergency_panel"]["breakers"]:
		assert_false(bool(on), "a trip throws every breaker open")
	for i in EmergencyPanel.BREAKERS:
		if bool(circuit[i]):
			assert_true(await use("emergency_panel", i + 1))
		assert_eq(schematic[i], "@CIRCUIT_LIVE" if bool(circuit[i]) else "@CIRCUIT_FAULT", "schematic matches")
	assert_true(await use("emergency_panel", EmergencyPanel.SUB_START))
	assert_true(mc.state.has_flag("ward_power"), "emergency power restored")
	assert_eq(int(mc.state.phase), int(MatchState.Phase.ESCALATE), "phase escalates with power")
	assert_true((mc.entities["monitor_1"] as MonitorClue).powered, "monitors come alive with power")

	# 5. Security card → observation wing; monitors and the round order give the code.
	await take(pickup_for_slot("security_card"))
	approach("door_obs")
	assert_true(await use("door_obs"))
	assert_false(bool(mc.state.entities["door_obs"]["locked"]), "security card opens observation")
	var readings := {}
	for i in 4:
		var st: Dictionary = mc.state.entities["monitor_%d" % (i + 1)]
		readings[int(st["bed"])] = int(st["digit"])
	var order: Array = mc.state.entities["note_roster"]["args"]
	var code := ""
	for bed in order:
		code += str(readings[int(bed)])
	assert_eq(code, puzzle["code"], "monitors + roster give the code")

	# 6. Keypad (wrong first), then the security office.
	put(Vector3(15.0, 0.05, 14.0))
	var wrong := "0000" if code != "0000" else "1111"
	assert_true(await use("keypad", 0, "submit", {"code": wrong}))
	assert_false(mc.state.has_flag("security_open"), "wrong code rejected")
	await get_tree().create_timer(KeypadEntity.ATTEMPT_COOLDOWN + 0.1).timeout
	await use("keypad", 0, "submit", {"code": code})
	assert_true(mc.state.has_flag("security_open"), "code opens the security office")
	assert_false(bool(mc.state.entities["door_security"]["locked"]))

	# 7. Bay console raises the shutter; walk out.
	put(Vector3(17.6, 0.05, 14.2))
	assert_true(await use("bay_console"))
	assert_true(mc.state.has_flag("bay_open"), "console opens the bay")
	assert_eq(int(mc.state.phase), int(MatchState.Phase.FINAL))
	var shutter: GarageDoor = mc.entities["bay_shutter"]
	shutter.open_seconds = 1.5
	var results: Array = []
	mc.match_finished.connect(func(r: Dictionary) -> void: results.append(r))
	await get_tree().create_timer(2.5).timeout
	assert_true(shutter.progress() >= 1.0, "shutter fully open")
	player.set_physics_process(true)
	player.global_position = Vector3(4, 0.1, -4.5)
	await frames(10)
	assert_eq(results.size(), 1, "match finished once")
	if results.is_empty():
		return
	assert_eq(results[0]["outcome"], "victory")
	for id in ["explore", "staff", "power", "security", "bay", "escape"]:
		assert_true((results[0]["objectives_completed"] as Array).has(id), "objective " + id)


func test_console_refuses_without_power() -> void:
	if not await build("black_ward", "normal", 9):
		return
	mc.set_entity_state("door_security", {"open": true, "locked": false})
	put(Vector3(17.6, 0.05, 14.2))
	assert_true(await use("bay_console"))
	assert_false(mc.state.has_flag("bay_open"), "no power, no shutter")
	assert_false(bool(mc.state.entities["bay_console"]["done"]))


func test_monitors_dark_until_power() -> void:
	if not await build("black_ward", "normal", 10):
		return
	var m: MonitorClue = mc.entities["monitor_3"]
	assert_false(m.powered, "dark before power")
	assert_true(int(mc.state.entities["monitor_3"]["digit"]) >= 0, "the reading is seeded state")
	mc.set_flag("ward_power")
	assert_true(m.powered, "lit after power")
