extends HouseFixture
## Plays The Abandoned House start to finish through authoritative
## interactions, including the failure branches players will hit.


func test_full_escape() -> void:
	if not await build("house", "normal", 777):
		return
	assert_empty(mc.rules.validate(), "rules")
	# 1. Find a way out: the front door is chained.
	approach("door_front")
	assert_true(await use("door_front"))
	assert_true(mc.state.has_flag("exit_found"), "trying the front door completes 'find a way out'")
	assert_false(bool(mc.state.entities["door_front"]["open"]), "front door never opens")
	assert_true(mc.rules.graph.is_complete(mc.state.objectives, "explore"))

	# 2. Study key (may be in a drawer), then the study if needed.
	await take(pickup_for_slot("study_key"))
	assert_true(has("study_key"))
	approach("door_study")
	assert_true(await use("door_study"))
	assert_false(bool(mc.state.entities["door_study"]["locked"]), "study unlocked with key")

	# 3. Fuses.
	for slot in ["fuse_1", "fuse_2", "fuse_3"]:
		await take(pickup_for_slot(slot))
	assert_true(has("fuse", 3), "three fuses")

	# 4. Fuse panel: the scorched socket shorts out and drops the fuse.
	var faulty := int(mc.puzzle()["faulty_socket"])
	approach("fuse_panel")
	assert_true(await use("fuse_panel", faulty + 1))
	assert_true(has("fuse", 2), "shorted fuse left the inventory")
	var drop_id := ""
	for id in mc.state.entities:
		if (
			str(mc.state.entities[id].get("kind", "")) == "dropped"
			and str(mc.state.entities[id].get("item", "")) == "fuse"
		):
			drop_id = id
	assert_ne(drop_id, "", "fuse dropped on the floor")
	await take(drop_id)
	assert_true(has("fuse", 3), "fuse recovered")
	approach("fuse_panel")
	for i in 4:
		if i != faulty:
			assert_true(await use("fuse_panel", i + 1))
	assert_true(mc.state.has_flag("power_on"), "power restored")
	assert_eq(int(mc.state.phase), int(MatchState.Phase.ESCALATE), "phase escalates with power")

	# 5. Basement maglock released; keypad (wrong code first).
	approach("door_basement")
	assert_true(await use("door_basement"))
	assert_false(bool(mc.state.entities["door_basement"]["locked"]))
	approach("keypad")
	var code: String = mc.puzzle()["code"]
	var wrong := "0000" if code != "0000" else "1111"
	assert_true(await use("keypad", 0, "submit", {"code": wrong}))
	assert_false(mc.state.has_flag("cage_open"), "wrong code rejected")
	await get_tree().create_timer(KeypadEntity.ATTEMPT_COOLDOWN + 0.1).timeout
	await use("keypad", 0, "submit", {"code": code})
	assert_true(mc.state.has_flag("cage_open"), "correct code opens the cage")
	assert_true(bool(mc.state.entities["cage_gate"]["open"]))

	# 6. Repair: gear + belt → workbench → motor.
	await take(pickup_for_slot("drive_gear"))
	await take(pickup_for_slot("drive_belt"))
	approach("workbench")
	assert_true(await use("workbench"))
	assert_true(has("drive_assembly"), "assembled")
	assert_false(has("drive_belt") or has("drive_gear"), "inputs consumed")
	approach("garage_motor")
	assert_true(await use("garage_motor"))
	assert_true(mc.state.has_flag("motor_repaired"))

	# 7. Crank start: one deliberate miss, then three timed pulls.
	var motor: GarageMotor = mc.entities["garage_motor"]
	await get_tree().create_timer(0.2).timeout
	await _wait_needle(motor, false)
	mc.server_interact(1, "garage_motor", 0, "use", motor.crank_args())
	assert_eq(int(mc.state.entities["garage_motor"]["successes"]), 0, "miss does not count")
	var guard := 0
	while not mc.state.has_flag("garage_open") and guard < 12:
		guard += 1
		await get_tree().create_timer(GarageMotor.CRANK_COOLDOWN + 0.05).timeout
		await _wait_needle(motor, true)
		# Simulate network delay: the request arrives later than the press.
		var pressed := motor.crank_args()
		await frames(6)
		mc.server_interact(1, "garage_motor", 0, "use", pressed)
	assert_true(mc.state.has_flag("garage_open"), "motor started")
	assert_eq(int(mc.state.phase), int(MatchState.Phase.FINAL))

	# 8. Door rises; walk out through the escape zone.
	var door: GarageDoor = mc.entities["garage_door"]
	door.open_seconds = 1.5
	var results: Array = []
	mc.match_finished.connect(func(r: Dictionary) -> void: results.append(r))
	await get_tree().create_timer(2.5).timeout
	assert_true(door.progress() >= 1.0, "door fully open")
	player.set_physics_process(true)
	player.global_position = Vector3(19, 0.1, -5.5)
	await frames(10)
	assert_eq(results.size(), 1, "match finished once")
	if results.is_empty():
		return
	var result: Dictionary = results[0]
	assert_eq(result["outcome"], "victory")
	for id in ["explore", "power", "cage", "repair", "start", "escape"]:
		assert_true((result["objectives_completed"] as Array).has(id), "objective " + id)
	assert_true((result["objectives_completed"] as Array).has("unseen"), "never caught → optional")

	# 9. Rewards apply exactly once even if the results flow repeats.
	var before := Saves.wallet.balance
	var r1 := result.duplicate(true)
	Session.match_config = {"mode": "solo"}
	Session._apply_solo_progress(r1)
	var r2 := result.duplicate(true)
	Session._apply_solo_progress(r2)
	assert_true(bool(r1["reward_applied"]))
	assert_false(bool(r2["reward_applied"]), "second application refused")
	assert_eq(Saves.wallet.balance, before + int(r1["rewards"]["total"]))
	assert_true(Saves.is_map_completed("house"))


func test_crank_rejects_future_or_stale_press_times() -> void:
	if not await build("house", "normal", 31):
		return
	var motor: GarageMotor = mc.entities["garage_motor"]
	mc.set_entity_state("garage_motor", {"repaired": true, "successes": 0, "started": false})
	mc.set_flag("power_on")
	approach("garage_motor")
	# Find a moment when the needle is outside the window, then claim a
	# stale time that was inside it: the claim must be ignored.
	await _wait_needle(motor, true)
	var stale := mc.state.elapsed
	await get_tree().create_timer(GarageMotor.MAX_PRESS_LAG + 0.3).timeout
	await _wait_needle(motor, false)
	mc.server_interact(1, "garage_motor", 0, "use", {"t": stale})
	assert_eq(int(mc.state.entities["garage_motor"]["successes"]), 0, "stale press time ignored")
	await get_tree().create_timer(0.5).timeout
	await _wait_needle(motor, false)
	mc.server_interact(1, "garage_motor", 0, "use", {"t": mc.state.elapsed + 5.0})
	assert_eq(int(mc.state.entities["garage_motor"]["successes"]), 0, "future press time ignored")


func _wait_needle(motor: GarageMotor, inside: bool) -> void:
	for i in 400:
		if motor.needle_in_window(1) == inside:
			return
		await get_tree().physics_frame


func test_rejects_invalid_and_remote_requests() -> void:
	if not await build("house", "normal", 99):
		return
	var pickup := pickup_for_slot("fuse_1")
	put(Vector3(23, 0.05, 9))
	assert_false(await use(pickup), "out of range")
	approach(pickup)
	assert_false(await use("no_such_entity"), "unknown entity")
	assert_false(await use(pickup, 99), "sub out of range")
	assert_false(await use(pickup, 0, "use", {"x": NAN}), "non-finite number")
	assert_false(await use(pickup, 0, "use", {"s": "x".repeat(64)}), "oversized string")
	assert_false(await use(pickup, 0, "use", {"o": [1, 2]}), "unsupported type")
	assert_false(mc.server_interact(2, pickup, 0, "use", {}), "unknown player id")
	assert_true(await use(pickup), "valid request accepted")
	var count := mc.inventory(1).count("fuse")
	await use(pickup)
	assert_eq(mc.inventory(1).count("fuse"), count, "duplicate pickup ignored")


func test_cannot_interact_through_walls() -> void:
	if not await build("house", "normal", 5):
		return
	# Hallway side of the locked study wall, within raw range of the desk.
	put(Vector3(12.0, 0.05, 9.4))
	var desk_items := []
	for id in mc.entities:
		var e: Interactable = mc.entities[id]
		if e is PickupEntity and e.global_position.distance_to(Vector3(12.0, 0.77, 12.2)) < 0.4:
			desk_items.append(id)
	if desk_items.is_empty():
		# Make sure something sits on the desk for this check.
		map.place_pickup_state(mc, "probe", "battery", "sp_study_desk")
		mc._restore_dynamic_entities()
		desk_items.append("probe")
	assert_false(await use(desk_items[0]), "blocked by the locked door / wall")


func test_drawer_must_be_open() -> void:
	if not await build("house", "normal", 5):
		return
	map.place_pickup_state(mc, "drawer_probe", "battery", "sp_kitchen_drawer")
	mc._restore_dynamic_entities()
	approach("drawer_kitchen")
	await use("drawer_probe")
	assert_false(bool(mc.state.entities["drawer_probe"]["taken"]), "closed drawer blocks the item")
	await use("drawer_kitchen")
	await frames(30)
	approach("drawer_probe")
	await use("drawer_probe")
	assert_true(bool(mc.state.entities["drawer_probe"]["taken"]), "open drawer item can be taken")


func test_drop_and_recover_key_item() -> void:
	if not await build("house", "normal", 21):
		return
	map.place_pickup_state(mc, "hall_fuse", "fuse", "bt_hall")
	mc._restore_dynamic_entities()
	await take("hall_fuse")
	assert_true(mc.drop_item(1, "fuse"))
	assert_false(has("fuse"))
	var drop := ""
	for id in mc.state.entities:
		if str(mc.state.entities[id].get("kind", "")) == "dropped":
			drop = id
	assert_ne(drop, "", "drop recorded in state")
	await take(drop)
	assert_true(has("fuse"), "recovered")


func test_checkpoint_restore_preserves_world() -> void:
	if not await build("house", "normal", 4242):
		return
	approach("door_front")
	await use("door_front")
	await take(pickup_for_slot("study_key"))
	mc.set_flag("power_on")
	var snap := mc.state.to_snapshot()
	var key_pickup := pickup_for_slot("study_key")
	map.queue_free()
	await frames(2)
	if not await build("house", "normal", 4242, snap):
		return
	assert_true(mc.state.has_flag("power_on"), "flags restored")
	assert_true(has("study_key"), "inventory restored")
	assert_true(bool(mc.state.entities[key_pickup]["taken"]), "taken pickup stays taken")
	assert_false((mc.entities[key_pickup] as Node3D).visible, "and stays hidden")
	assert_eq(str(mc.state.variant["puzzle"]["code"]), str(snap["variant"]["puzzle"]["code"]), "same puzzle answers")
	assert_true(map.power_on, "lights follow restored power")


func test_tutorial_chain() -> void:
	if not await build("tutorial", "story", 3):
		return
	assert_false(mc.enemy_enabled, "tutorial has no hostile enemy")
	mc.set_flag("t_moved")
	await take("pickup_key")
	approach("t_door_bc")
	assert_true(await use("t_door_bc"))
	assert_true(mc.state.has_flag("t_door"))
	approach("t_locker")
	await use("t_locker")
	assert_eq(str(mc.state.players[1]["hiding"]), "t_locker")
	await use("t_locker")
	assert_eq(str(mc.state.players[1]["hiding"]), "")
	approach("t_keypad")
	await use("t_keypad", 0, "submit", {"code": str(mc.puzzle()["code"])})
	assert_true(mc.state.has_flag("t_code"))
	var results: Array = []
	mc.match_finished.connect(func(r: Dictionary) -> void: results.append(r))
	player.set_physics_process(true)
	player.global_position = Vector3(3, 0.1, 23.3)
	await frames(10)
	assert_eq(results.size(), 1, "tutorial finished")
	if not results.is_empty():
		assert_eq(results[0]["outcome"], "victory")
		assert_true(bool(results[0]["tutorial"]))
