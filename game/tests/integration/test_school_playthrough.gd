extends HouseFixture
## Plays The Silent School start to finish through authoritative interactions
## (PA refused without power, a wrong tune on the chimes), and checks the
## Headmistress's rule: she cannot move while watched in light.


func test_full_escape() -> void:
	if not await build("silent_school", "normal", 4404):
		return
	assert_empty(mc.rules.validate(), "rules")
	var puzzle := mc.puzzle()
	var school := map

	# 1. The front doors are chained: trying them completes "find a way out".
	approach("door_front")
	assert_true(await use("door_front"))
	assert_true(mc.state.has_flag("exit_found"), "trying the chained doors completes 'find a way out'")
	assert_true(bool(mc.state.entities["door_front"]["locked"]), "still chained")

	# 2. The music box plays beside the wing key; the key opens the east wing.
	var box_state: Dictionary = mc.state.entities["music_box"]
	var key_spawn := str(mc.state.entities[pickup_for_slot("wing_key")]["spawn"])
	var key_pos: Vector3 = (school.spawn_points[key_spawn]["xform"] as Transform3D).origin
	var box_pos := Vector3(box_state["pos"][0], box_state["pos"][1], box_state["pos"][2])
	assert_true(box_pos.distance_to(key_pos) < 0.5, "the music box sits beside the key")
	assert_true(bool(box_state["playing"]), "it is playing")
	put(school.closest_nav_point(box_pos))
	assert_true(await use("music_box"))
	assert_false(bool(mc.state.entities["music_box"]["playing"]), "closing the lid silences it")
	await take(pickup_for_slot("wing_key"))
	approach("door_wing")
	assert_true(await use("door_wing"))
	assert_true(mc.state.has_flag("wing_open"), "the key opens the east wing")

	# 3. The PA is dead without power; the main breaker brings it back.
	put(Vector3(26.0, 0.05, 5.6))
	assert_true(await use("pa_console"))
	assert_false(mc.state.has_flag("tune_heard"), "no power, no PA")
	put(Vector3(32.5, 0.05, 5.6))
	assert_true(await use("main_breaker"))
	assert_true(mc.state.has_flag("school_power"), "the breaker restores power")
	assert_eq(int(mc.state.phase), int(MatchState.Phase.ESCALATE))
	assert_true(map.is_lit_at(Vector3(15.0, 1.0, 9.0)), "classrooms are lit once powered")

	# 4. The PA plays the four-note tune (and can play it again).
	put(Vector3(26.0, 0.05, 5.6))
	assert_true(await use("pa_console"))
	assert_true(mc.state.has_flag("tune_heard"), "the bell tune plays")
	await frames(2)
	assert_eq((school.get("_tune_queue") as Array).size(), 4, "four notes queued for the speakers")
	assert_true(await use("pa_console"))
	assert_eq(int(mc.state.entities["pa_console"]["uses"]), 2, "the PA replays on request")

	# 5. Chimes: a plain scale is never the tune; the right four notes open the office.
	put(Vector3(40.0, 0.05, 10.6))
	for bar in [1, 2, 3, 4]:
		assert_true(await use("chime_board", bar))
	assert_false(mc.state.has_flag("chimes_solved"), "a scale is wrong")
	assert_eq((mc.state.entities["chime_board"]["entered"] as Array).size(), 0, "a wrong tune resets the board")
	for bar in puzzle["tune"]:
		assert_true(await use("chime_board", int(bar)))
	assert_true(mc.state.has_flag("chimes_solved"), "the bell tune solves the chimes")
	assert_true(mc.state.has_flag("office_open"), "the tuned lock releases the office")
	assert_false(bool(mc.state.entities["door_office"]["locked"]))
	assert_eq(int(mc.state.phase), int(MatchState.Phase.FINAL))

	# 6. Bolt cutters from the office cut the chain.
	await take(pickup_for_slot("bolt_cutters"))
	approach("door_front")
	assert_true(await use("door_front"))
	assert_true(mc.state.has_flag("doors_open"), "the chain is cut")

	# 7. Out onto the porch.
	var results: Array = []
	mc.match_finished.connect(func(r: Dictionary) -> void: results.append(r))
	player.set_physics_process(true)
	player.global_position = Vector3(18.0, 0.1, 31.8)
	await frames(10)
	assert_eq(results.size(), 1, "match finished once")
	if results.is_empty():
		return
	assert_eq(results[0]["outcome"], "victory")
	for id in ["explore", "wing", "power", "tune", "chimes", "doors", "escape"]:
		assert_true((results[0]["objectives_completed"] as Array).has(id), "objective " + id)


func test_headmistress_holds_still_while_watched_in_light() -> void:
	if not await build("silent_school", "normal", 41):
		return
	var her := Watcher.new()
	map.enemies_root.add_child(her)
	her.setup(mc, map)
	assert_eq(her.profile.id, "headmistress", "the school's enemy uses the headmistress profile")
	assert_true(her.profile.freezes_when_watched)
	mc.enemies.append(her)
	# Classroom B is dark until the breaker: only a flashlight can hold her there.
	her.global_position = Vector3(15.0, 0.05, 8.0)
	her.rotation.y = PI
	await frames(3)
	put(Vector3(15.0, 0.05, 12.5))
	mc.state.players[1]["yaw"] = 0.0  # looking north, straight at her
	mc.state.players[1]["flashlight"] = false
	assert_false(her.is_watched(), "looked at in the dark: not held")
	mc.state.players[1]["flashlight"] = true
	assert_true(her.is_watched(), "in the torch beam: held")
	mc.state.players[1]["yaw"] = PI
	assert_false(her.is_watched(), "looking away releases her")
	# Watched, she does not move even while hunting the player in front of her.
	mc.state.players[1]["yaw"] = 0.0
	await frames(15)  # let her senses register the gaze
	var start := her.global_position
	for i in 60:
		await get_tree().physics_frame
	var drift := Vector2(her.global_position.x - start.x, her.global_position.z - start.z).length()
	assert_true(drift < 0.02, "held still under the beam (moved %.3f m)" % drift)
	assert_eq(her.rig.current(), "freeze", "frozen mid-pose")
	# The moment the beam leaves her, she comes.
	mc.state.players[1]["flashlight"] = false
	var moved := false
	for i in 150:
		await get_tree().physics_frame
		if her.global_position.distance_to(start) > 0.5:
			moved = true
			break
	assert_true(moved, "unwatched, she moves")


func test_lit_rooms_hold_her_without_a_torch() -> void:
	if not await build("silent_school", "normal", 42):
		return
	var her := Watcher.new()
	map.enemies_root.add_child(her)
	her.setup(mc, map)
	mc.enemies.append(her)
	her.global_position = Vector3(15.0, 0.05, 8.0)
	await frames(3)
	put(Vector3(15.0, 0.05, 12.5))
	mc.state.players[1]["yaw"] = 0.0
	mc.state.players[1]["flashlight"] = false
	assert_false(her.is_watched(), "dark classroom")
	mc.set_flag("school_power")
	assert_true(her.is_watched(), "once the lights are on, a look is enough")
