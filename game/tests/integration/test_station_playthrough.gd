extends HouseFixture
## Plays Last Train start to finish through authoritative interactions, and
## checks the Lineman's headlamp sight and the ghost trains' noise masking.

const PY := -5.0


func test_full_escape() -> void:
	if not await build("last_train", "normal", 5151):
		return
	assert_empty(mc.rules.validate(), "rules")
	var puzzle := mc.puzzle()

	# 1. The street stairs have collapsed.
	put(Vector3(18.0, 0.05, 31.0))
	assert_true(await use("street_exit"))
	assert_true(mc.state.has_flag("exit_found"), "inspecting the rubble completes 'find a way out'")

	# 2. Help point refuses before a route is set.
	put(Vector3(21.6, PY + 0.05, 11.6))
	assert_true(await use("help_point"))
	assert_false(mc.state.has_flag("train_called"), "no route, no train")

	# 3. Maintenance key → tunnels.
	approach("door_maint")
	assert_true(await use("door_maint"))
	assert_true(bool(mc.state.entities["door_maint"]["locked"]), "locked without the key")
	await take(pickup_for_slot("maint_key"))
	approach("door_maint")
	assert_true(await use("door_maint"))
	assert_true(mc.state.has_flag("maint_open"), "key opens the maintenance door")

	# 4. Levers without power: the plunger refuses.
	put(Vector3(29.0, PY + 0.05, 16.8))
	assert_true(await use("lever_frame", LeverFrame.SUB_SET))
	assert_false(mc.state.has_flag("route_set"), "no power to the frame")

	# 5. Two power cells charge the rack.
	await take(pickup_for_slot("cell_1"))
	await take(pickup_for_slot("cell_2"))
	assert_true(has("power_cell", 2), "both cells carried")
	put(Vector3(26.6, PY + 0.05, 20.0))
	assert_true(await use("battery_rack"))
	assert_eq(int(mc.state.entities["battery_rack"]["filled"]), 1)
	assert_false(mc.state.has_flag("signal_power"), "one cell is not enough")
	assert_true(await use("battery_rack"))
	assert_true(mc.state.has_flag("signal_power"), "two cells power the signal box")
	assert_eq(int(mc.state.phase), int(MatchState.Phase.ESCALATE))

	# 6. Route card vs levers: a wrong set rings the bell, the right set locks the route.
	var route: Array = puzzle["route"]
	var card: Array = mc.state.entities["note_route"]["args"]
	for i in LeverFrame.LEVERS:
		assert_eq(card[i], "@LEVER_REVERSE" if bool(route[i]) else "@LEVER_NORMAL", "route card matches")
	put(Vector3(29.0, PY + 0.05, 16.8))
	assert_true(await use("lever_frame", LeverFrame.SUB_SET))
	assert_false(mc.state.has_flag("route_set"), "all-normal is never the route")
	for i in LeverFrame.LEVERS:
		if bool(route[i]):
			assert_true(await use("lever_frame", i + 1))
	assert_true(await use("lever_frame", LeverFrame.SUB_SET))
	assert_true(mc.state.has_flag("route_set"), "matching levers set the route")

	# 7. Call the train, hold out, board.
	put(Vector3(21.6, PY + 0.05, 11.6))
	assert_true(await use("help_point"))
	assert_true(mc.state.has_flag("train_called"))
	assert_eq(int(mc.state.phase), int(MatchState.Phase.FINAL))
	var train: EvacTrain = mc.entities["evac_train"]
	train.arrival_seconds = 1.5
	var results: Array = []
	mc.match_finished.connect(func(r: Dictionary) -> void: results.append(r))
	await get_tree().create_timer(2.5).timeout
	assert_true(mc.state.has_flag("train_arrived"), "the train arrives")
	player.set_physics_process(true)
	player.global_position = Vector3(20.0, PY + 0.1, 5.6)
	await frames(10)
	assert_eq(results.size(), 1, "match finished once")
	if results.is_empty():
		return
	assert_eq(results[0]["outcome"], "victory")
	for id in ["explore", "maint", "power", "route", "call", "hold", "escape"]:
		assert_true((results[0]["objectives_completed"] as Array).has(id), "objective " + id)


func test_platform_edge_is_closed_until_the_train_is_in() -> void:
	if not await build("last_train", "normal", 77):
		return
	player.set_physics_process(true)
	player.global_position = Vector3(16.0, PY + 0.05, 8.0)
	player.velocity = Vector3.ZERO
	await frames(2)
	# Push toward the tracks for a moment: the gate holds.
	for i in 30:
		player.velocity = Vector3(0, 0, -4.0)
		player.move_and_slide()
		await get_tree().physics_frame
	assert_true(player.global_position.z > 6.8, "cannot step onto the track (z=%.2f)" % player.global_position.z)


func test_ghost_train_masks_noise_near_the_tracks() -> void:
	if not await build("last_train", "normal", 78):
		return
	var station := map
	var ghost: GhostTrain = mc.entities["ghost_train"]
	var platform := Vector3(20.0, PY, 8.0)
	assert_eq(station.noise_mask(platform, "step"), 1.0, "quiet station: normal hearing")
	# Start a pass so the train is level with x=20 right now.
	mc.state.elapsed += 20.0
	var t_mid := (20.0 - ghost.track_from.x) / (ghost.track_to.x - ghost.track_from.x) * ghost.pass_seconds
	mc.set_entity_state("ghost_train", {"start": mc.state.elapsed - t_mid, "dir": 1})
	assert_true(absf(station.noise_mask(platform, "step") - 0.3) < 0.001, "a passing train drowns out footsteps")
	assert_eq(station.noise_mask(Vector3(18.0, 0.0, 30.0), "step"), 1.0, "the concourse is too far to be masked")
	assert_eq(station.noise_mask(platform, "train"), 1.0, "the train itself is not masked")


func test_lineman_sees_along_his_beam_only() -> void:
	if not await build("last_train", "normal", 79):
		return
	var lineman := Watcher.new()
	map.enemies_root.add_child(lineman)
	lineman.setup(mc, map)
	assert_eq(lineman.profile.id, "lineman", "the station's enemy uses the lineman profile")
	mc.enemies.append(lineman)
	# Standing on the platform facing west (-X).
	lineman.global_position = Vector3(30.0, PY + 0.05, 10.0)
	lineman.rotation.y = PI / 2
	lineman.set("_pause", 5.0)
	await frames(3)
	# Off to the side of the beam (about 40°) in the dark: unseen even close-ish.
	put(Vector3(25.0, PY + 0.05, 13.0 - 0.6))
	mc.state.players[1]["flashlight"] = false
	await frames(40)
	assert_ne(lineman.state, Watcher.S.CHASE, "outside the narrow beam")
	# Straight down the beam, 12 m away in the dark: seen (his lamp lights you).
	put(Vector3(18.0, PY + 0.05, 10.0))
	var seen := false
	for i in 120:
		await get_tree().physics_frame
		if lineman.state == Watcher.S.CHASE:
			seen = true
			break
	assert_true(seen, "inside the beam, darkness does not hide you")
