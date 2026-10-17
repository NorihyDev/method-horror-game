extends HouseFixture
## The Sister (The Black Ward): blind, hunts by sound. Behavior on the real
## ward geometry through the shared enemy brain with the "sister" profile.

var sister: Watcher


func _spawn_sister_at(pos: Vector3, yaw: float) -> void:
	sister = Watcher.new()
	sister.profile = EnemyProfile.sister()
	map.enemies_root.add_child(sister)
	sister.global_position = pos
	sister.rotation.y = yaw
	sister.setup(mc, map)
	mc.enemies.append(sister)
	await frames(2)


func _hold_still(seconds: float) -> void:
	sister.set("_pause", seconds)


func test_profile_comes_from_the_map() -> void:
	if not await build("black_ward", "normal", 21):
		return
	var w := Watcher.new()
	map.enemies_root.add_child(w)
	w.setup(mc, map)
	assert_eq(w.profile.id, "sister", "the ward's enemy uses the sister profile")
	assert_false(w.profile.sees, "she is blind")
	w.queue_free()


func test_ignores_a_lit_player_in_plain_sight() -> void:
	if not await build("black_ward", "normal", 22):
		return
	# Corridor: long straight line, nothing in between.
	put(Vector3(10.0, 0.05, 9.5))
	mc.state.players[1]["flashlight"] = true
	await _spawn_sister_at(Vector3(16.0, 0.05, 9.5), PI / 2)
	_hold_still(3.0)
	await frames(90)
	assert_ne(sister.state, Watcher.S.CHASE, "light and line of sight mean nothing to her")


func test_hunts_close_footsteps_but_not_crouching() -> void:
	if not await build("black_ward", "normal", 23):
		return
	put(Vector3(10.0, 0.05, 9.5))
	await _spawn_sister_at(Vector3(13.5, 0.05, 9.5), PI / 2)
	_hold_still(5.0)
	# Crouch-walking 3.5 m away: inaudible.
	mc.emit_noise(Vector3(10.0, 0.0, 9.5), MatchController.NOISE_CROUCH, "step", 1)
	await frames(10)
	assert_ne(sister.state, Watcher.S.CHASE, "crouched steps are too quiet to hunt")
	# Walking at the same distance: she hunts the source.
	mc.emit_noise(Vector3(10.0, 0.0, 9.5), MatchController.NOISE_WALK, "step", 1)
	await frames(2)
	assert_eq(sister.state, Watcher.S.CHASE, "a close footstep starts a hunt")
	assert_eq(int(sister.get("_chase_pid")), 1, "hunting the player who made the noise")


func test_far_noise_is_investigated_not_hunted() -> void:
	if not await build("black_ward", "normal", 24):
		return
	put(Vector3(4.0, 0.05, 9.5))
	await _spawn_sister_at(Vector3(24.0, 0.05, 9.5), PI / 2)
	_hold_still(3.0)
	# Audible 10 m away, but outside the hunting band (55% of what she hears).
	mc.emit_noise(Vector3(14.0, 0.0, 9.5), 11.0, "step", 1)
	await frames(2)
	assert_eq(sister.state, Watcher.S.INVESTIGATE, "distant noise: she goes to listen, not to kill")
	# Machines (no player behind the noise) are only ever investigated.
	sister.call("_enter", Watcher.S.PATROL)
	mc.emit_noise(Vector3(22.0, 0.0, 9.5), 30.0, "power")
	await frames(2)
	assert_eq(sister.state, Watcher.S.INVESTIGATE, "world noise is investigated, never hunted")


func test_silence_loses_her() -> void:
	if not await build("black_ward", "normal", 25):
		return
	put(Vector3(10.0, 0.05, 9.5))
	await _spawn_sister_at(Vector3(13.5, 0.05, 9.5), PI / 2)
	mc.emit_noise(Vector3(10.0, 0.0, 9.5), MatchController.NOISE_WALK, "step", 1)
	await frames(2)
	assert_eq(sister.state, Watcher.S.CHASE)
	# Move away silently (no more noise): she loses track after a few seconds.
	put(Vector3(4.0, 0.05, 13.0))
	var lost := false
	for i in 600:
		await get_tree().physics_frame
		if sister.state in [Watcher.S.LOST, Watcher.S.SEARCH]:
			lost = true
			break
	assert_true(lost, "without more noise she loses the trail")


func test_touch_finds_you() -> void:
	if not await build("black_ward", "normal", 26):
		return
	put(Vector3(12.0, 0.05, 9.5))
	await _spawn_sister_at(Vector3(13.2, 0.05, 9.5), PI / 2)
	_hold_still(1.0)
	await frames(20)
	assert_eq(sister.state, Watcher.S.CHASE, "bumping into her is not safe")
