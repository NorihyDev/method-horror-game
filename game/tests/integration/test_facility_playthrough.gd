extends HouseFixture
## Plays the METHOD Facility start to finish through authoritative
## interactions (card door, maglock release, power cells, monitors + protocol
## keypad with a wrong code first, lift hold-out), and checks that Subject
## Zero is blind in the dark and sees once the generator runs.


func test_full_escape() -> void:
	if not await build("method_facility", "normal", 5505):
		return
	assert_empty(mc.rules.validate(), "rules")
	var puzzle := mc.puzzle()

	# 1. The passenger lift is dead.
	put(Vector3(20.0, 0.05, 30.6))
	assert_true(await use("lift_dead"))
	assert_true(mc.state.has_flag("exit_found"), "inspecting the dead lift completes 'find a way out'")

	# 2. Security card → security office.
	approach("door_security")
	assert_true(await use("door_security"))
	assert_true(bool(mc.state.entities["door_security"]["locked"]), "no card, no entry")
	await take(pickup_for_slot("security_card"))
	approach("door_security")
	assert_true(await use("door_security"))
	assert_true(mc.state.has_flag("security_open"), "the card opens security")

	# 3. Generator room is maglocked until the security console releases it.
	assert_true(bool(mc.state.entities["door_generator"]["locked"]), "generator maglocked")
	put(Vector3(1.8, 0.05, 7.6))
	assert_true(await use("release_locks"))
	assert_true(mc.state.has_flag("locks_released"))
	assert_false(bool(mc.state.entities["door_generator"]["locked"]), "maglock released")

	# 4. The lift refuses without power (reached early through an opened door).
	mc.set_entity_state("door_director", {"open": true, "locked": false})
	put(Vector3(34.4, 0.05, 28.4))
	assert_true(await use("lift_console"))
	assert_false(mc.state.has_flag("lift_called"), "no power, no lift")
	mc.set_entity_state("door_director", {"open": false, "locked": true})

	# 5. Two power cells start the generator.
	await take(pickup_for_slot("cell_1"))
	await take(pickup_for_slot("cell_2"))
	assert_true(has("power_cell", 2))
	put(Vector3(35.0, 0.05, 7.6))
	assert_true(await use("generator_rack"))
	assert_false(mc.state.has_flag("facility_power"), "one cell is not enough")
	assert_true(await use("generator_rack"))
	assert_true(mc.state.has_flag("facility_power"), "two cells start the generator")
	assert_eq(int(mc.state.phase), int(MatchState.Phase.ESCALATE))
	assert_true((mc.entities["monitor_1"] as MonitorClue).powered, "monitors wake with the power")

	# 6. Monitors + protocol give the director's code (wrong code first).
	var readings := {}
	for i in 4:
		var st: Dictionary = mc.state.entities["monitor_%d" % (i + 1)]
		readings[int(st["bed"])] = int(st["digit"])
	var code := ""
	for cell in mc.state.entities["note_protocol"]["args"]:
		code += str(readings[int(cell)])
	assert_eq(code, puzzle["code"], "monitors + protocol give the code")
	put(Vector3(29.0, 0.05, 19.0))
	var wrong := "0000" if code != "0000" else "1111"
	assert_true(await use("keypad", 0, "submit", {"code": wrong}))
	assert_false(mc.state.has_flag("office_open"), "wrong code rejected")
	await get_tree().create_timer(KeypadEntity.ATTEMPT_COOLDOWN + 0.1).timeout
	await use("keypad", 0, "submit", {"code": code})
	assert_true(mc.state.has_flag("office_open"), "the code opens the director's office")

	# 7. Call the lift, hold out, ride it up.
	put(Vector3(34.4, 0.05, 28.4))
	assert_true(await use("lift_console"))
	assert_true(mc.state.has_flag("lift_called"))
	assert_eq(int(mc.state.phase), int(MatchState.Phase.FINAL))
	var lift: EvacTrain = mc.entities["freight_lift"]
	assert_eq(lift.style, "lift")
	lift.arrival_seconds = 1.5
	var results: Array = []
	mc.match_finished.connect(func(r: Dictionary) -> void: results.append(r))
	await get_tree().create_timer(2.5).timeout
	assert_true(mc.state.has_flag("lift_arrived"), "the lift arrives")
	player.set_physics_process(true)
	player.global_position = Vector3(44.0, 0.1, 4.6)
	await frames(10)
	assert_eq(results.size(), 1, "match finished once")
	if results.is_empty():
		return
	assert_eq(results[0]["outcome"], "victory")
	for id in ["explore", "security", "locks", "power", "code", "lift", "hold", "escape"]:
		assert_true((results[0]["objectives_completed"] as Array).has(id), "objective " + id)


func test_lift_gate_holds_until_arrival() -> void:
	if not await build("method_facility", "normal", 56):
		return
	player.set_physics_process(true)
	player.global_position = Vector3(44.0, 0.05, 7.2)
	player.velocity = Vector3.ZERO
	await frames(2)
	for i in 30:
		player.velocity = Vector3(0, 0, -4.0)
		player.move_and_slide()
		await get_tree().physics_frame
	assert_true(player.global_position.z > 6.0, "cannot step into the empty shaft (z=%.2f)" % player.global_position.z)


func test_subject_zero_is_blind_until_the_power_returns() -> void:
	if not await build("method_facility", "normal", 57):
		return
	var subject := Watcher.new()
	map.enemies_root.add_child(subject)
	subject.setup(mc, map)
	mc.enemies.append(subject)
	assert_eq(subject.profile.id, "subject", "the facility's enemy is Subject Zero")
	assert_false(subject.profile.sees, "blind in the dark")
	assert_true(subject.profile.hunts_by_sound, "hunts by sound in the dark")
	# A lit, silent player in plain sight is not noticed while it is blind.
	subject.global_position = Vector3(24.0, 0.05, 18.0)
	subject.rotation.y = -PI / 2
	subject.set("_pause", 3.0)
	await frames(3)
	put(Vector3(30.0, 0.05, 18.0))
	mc.state.players[1]["flashlight"] = true
	await frames(40)
	assert_ne(subject.state, Watcher.S.CHASE, "blind: light does not give you away")
	# Power back: its eyes return.
	mc.set_flag("facility_power")
	assert_true(subject.profile.sees, "the generator gives it sight")
	assert_false(subject.profile.hunts_by_sound)
	var seen := false
	for i in 120:
		await get_tree().physics_frame
		if subject.state == Watcher.S.CHASE:
			seen = true
			break
	assert_true(seen, "with the lights on, it sees a lit player in front of it")
