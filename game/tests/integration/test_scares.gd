extends HouseFixture
## The scare director: every kind can play somewhere in a real map, none of
## them touch the shared match state, and they stay out of chases.

var _scares: ScareDirector


func _make_director() -> void:
	_scares = ScareDirector.new()
	add_child(_scares)
	_scares.setup(mc, player, map, null)
	player.input_enabled = true


func after_each() -> void:
	if _scares and is_instance_valid(_scares):
		_scares.queue_free()
	Settings.set_value("jump_scares", "full", false)
	await super.after_each()


func test_every_kind_plays_without_changing_match_state() -> void:
	if not await build("house"):
		return
	_make_director()
	var before := JSON.stringify(mc.state.entities)
	var played := {}
	# Stand in the long hallway, facing down it: walls to knock on, lamps,
	# doors, and a clear corridor for the figure.
	put(map.closest_nav_point(Vector3(1.0, 0.0, 8.5)))
	player.set("_yaw", -PI / 2)
	player.head.rotation = Vector3(0, -PI / 2, 0)
	for lamp in map.find_children("*", "FlickerLight", true, false):
		(lamp as FlickerLight).set_powered(true)
	await frames(3)
	for kind in ScareDirector.KINDS:
		if _scares.trigger(kind):
			played[kind] = true
		await frames(2)
	await frames(90)
	for kind in [
		"whisper", "knock", "run_past", "lights_out", "flashlight_fail", "phantom", "distant_scream", "door_slam"
	]:
		assert_true(played.has(kind), "%s can play in the hallway" % kind)
	assert_eq(JSON.stringify(mc.state.entities), before, "scares never change entity state")
	assert_true(_scares.get("_phantom") == null, "the figure vanishes on its own")


func test_reduced_setting_only_picks_mild_scares() -> void:
	if not await build("house"):
		return
	_make_director()
	Settings.set_value("jump_scares", "reduced", false)
	for i in 60:
		assert_true(_scares.pick_kind() in ScareDirector.MILD, "mild only")


func test_no_scares_while_the_enemy_is_close() -> void:
	if not await build("house"):
		return
	_make_director()
	put(map.closest_nav_point(Vector3(1.0, 0.0, 8.5)))
	assert_true(_scares.call("_quiet_moment"), "quiet with no enemy around")
	var stand_in := Node3D.new()
	map.add_child(stand_in)
	stand_in.global_position = player.global_position + Vector3(3, 0, 0)
	mc.enemies.append(stand_in)
	assert_false(_scares.call("_quiet_moment"), "enemy 3 m away: no scare")
	mc.enemies.erase(stand_in)
	player.set("hidden_spot", PlayerController.HiddenInfo.new())
	assert_false(_scares.call("_quiet_moment"), "hiding: no scare")
	player.set("hidden_spot", null)


func test_gaps_shrink_with_difficulty() -> void:
	if not await build("house", "story"):
		return
	_make_director()
	var story := 0.0
	for i in 40:
		story += _scares.gap()
	map.queue_free()
	await frames(2)
	if not await build("house", "nightmare"):
		return
	_scares.queue_free()
	_make_director()
	var nightmare := 0.0
	for i in 40:
		nightmare += _scares.gap()
	assert_true(nightmare < story * 0.6, "nightmare scares come far more often (%d vs %d)" % [nightmare, story])
