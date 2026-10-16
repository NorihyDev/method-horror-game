extends HouseFixture
## The Watcher's perception and state machine on the real house geometry.

var watcher: Watcher


func _spawn_watcher_at(pos: Vector3, yaw: float) -> void:
	watcher = Watcher.new()
	map.enemies_root.add_child(watcher)
	watcher.global_position = pos
	watcher.rotation.y = yaw
	watcher.setup(mc, map)
	mc.enemies.append(watcher)
	await frames(2)


## Keeps it standing (still sensing) so a test controls what it faces.
func _hold_still(seconds: float) -> void:
	watcher.set("_pause", seconds)


func test_spawn_never_near_or_visible_to_players() -> void:
	if not await build("house", "normal", 11):
		return
	put(Vector3(8.0, 0.05, 15.6))
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var enemy: Node3D = map.spawn_enemy(mc, rng)
	assert_true(enemy != null, "a safe spawn exists")
	if enemy:
		assert_true(enemy.global_position.distance_to(Vector3(8.0, 0.05, 15.6)) >= MapBase.MIN_ENEMY_SPAWN_DISTANCE)
		enemy.queue_free()


func test_hears_noise_and_investigates() -> void:
	if not await build("house", "normal", 12):
		return
	put(Vector3(3.0, 0.05, 14.0))
	await _spawn_watcher_at(Vector3(4.0, 0.05, 3.5), 0.0)
	assert_eq(watcher.state, Watcher.S.PATROL)
	mc.emit_noise(Vector3(4.0, 0.0, 6.0), 20.0, "short")
	assert_eq(watcher.state, Watcher.S.INVESTIGATE, "loud noise nearby triggers investigation")


func test_quiet_noise_far_away_is_ignored() -> void:
	if not await build("house", "normal", 13):
		return
	put(Vector3(3.0, 0.05, 14.0))
	await _spawn_watcher_at(Vector3(20.0, -3.15, 26.0), 0.0)
	mc.emit_noise(Vector3(3.0, 0.0, 14.0), MatchController.NOISE_CROUCH, "step")
	assert_eq(watcher.state, Watcher.S.PATROL, "crouched steps across the house are inaudible")


func test_sees_lit_player_in_front_and_chases() -> void:
	if not await build("house", "normal", 14):
		return
	# Hallway: watcher at the west end looking east (+X), player 6 m ahead.
	put(Vector3(8.0, 0.05, 8.5))
	mc.state.players[1]["flashlight"] = true
	await _spawn_watcher_at(Vector3(2.0, 0.05, 8.5), -PI / 2)
	_hold_still(3.0)
	for i in 150:
		await get_tree().physics_frame
		if watcher.state == Watcher.S.CHASE:
			break
	assert_true(watcher.state in [Watcher.S.CHASE, Watcher.S.ATTACK], "should chase a visible player")


func test_does_not_see_through_walls() -> void:
	if not await build("house", "normal", 15):
		return
	# Player in the kitchen, watcher in the dining room facing the shared wall.
	put(Vector3(6.5, 0.05, 1.5))
	mc.state.players[1]["flashlight"] = true
	await _spawn_watcher_at(Vector3(9.5, 0.05, 1.5), PI / 2)
	_hold_still(3.0)
	for i in 90:
		await get_tree().physics_frame
	assert_false(watcher.state in [Watcher.S.CHASE, Watcher.S.ATTACK], "no x-ray vision")


func test_attacks_with_windup_and_damages_once_per_strike() -> void:
	if not await build("house", "normal", 16):
		return
	put(Vector3(5.0, 0.05, 8.5))
	mc.state.players[1]["flashlight"] = true
	await _spawn_watcher_at(Vector3(3.6, 0.05, 8.5), -PI / 2)
	var hits_seen: Array = []
	mc.player_damaged.connect(func(_pid: int, hits: int) -> void: hits_seen.append(hits))
	var saw_windup := false
	for i in 240:
		await get_tree().physics_frame
		if watcher.state == Watcher.S.ATTACK and hits_seen.is_empty():
			saw_windup = true
		if not hits_seen.is_empty():
			break
	assert_true(saw_windup, "telegraphed wind-up before damage")
	assert_eq(hits_seen.size(), 1, "exactly one hit landed")
	for i in 20:
		await get_tree().physics_frame
	assert_eq(hits_seen.size(), 1, "no repeated damage from the same strike")


func test_saw_player_hide_then_checks_spot() -> void:
	if not await build("house", "normal", 17):
		return
	put(Vector3(15.3, 0.05, 6.4))
	mc.state.players[1]["flashlight"] = true
	await _spawn_watcher_at(Vector3(21.5, 0.05, 9.2), PI / 2 - 0.35)
	_hold_still(3.0)
	for i in 150:
		await get_tree().physics_frame
		if watcher.state == Watcher.S.CHASE:
			break
	assert_eq(watcher.state, Watcher.S.CHASE, "chasing before the player hides")
	approach("hide_garage")
	await use("hide_garage")
	assert_eq(str(mc.state.players[1]["hiding"]), "hide_garage")
	var checked := false
	for i in 300:
		await get_tree().physics_frame
		if watcher.state == Watcher.S.CHECK_HIDING or str(mc.state.players[1]["hiding"]).is_empty():
			checked = true
			break
	assert_true(checked, "it saw the player get in, so it checks the locker")
