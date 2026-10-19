extends HouseFixture
## The enemy never gets stuck: on every map it walks to every patrol point in
## turn, through doors that are shut again before every leg, within a time
## budget per leg. Physics-driven (the real movement, doors and collisions).

const SPEED := 2.1
const SLACK := 10.0

var watcher: Watcher


func test_enemy_reaches_every_patrol_point_on_every_map() -> void:
	# Run the simulation 4x faster than real time, same 60 Hz physics step.
	var ticks := Engine.physics_ticks_per_second
	var steps := Engine.max_physics_steps_per_frame
	Engine.physics_ticks_per_second = 240
	Engine.max_physics_steps_per_frame = 32
	Engine.time_scale = 4.0
	for m in Session.maps:
		if m.is_playable() and String(m.id) != "tutorial":
			await _tour(String(m.id))
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = ticks
	Engine.max_physics_steps_per_frame = steps


func _tour(map_id: String) -> void:
	if not await build(map_id, "normal", 5):
		return
	# Nobody to chase: the only player is out of the building.
	mc.state.players[1]["status"] = MatchState.STATUS_ESCAPED
	put(Vector3(0, -50, 0))
	# Late game: every lock is open, so every patrol point is reachable.
	for ent in mc.entities.values():
		if ent is DoorEntity and (ent as DoorEntity).is_locked():
			mc.set_entity_state((ent as DoorEntity).entity_id, {"open": false, "locked": false})
	map.rebake_navigation()
	await frames(20)
	await map.wait_for_navigation()
	var points := map.patrol_points.duplicate()
	watcher = Watcher.new()
	map.enemies_root.add_child(watcher)
	watcher.global_position = map.closest_nav_point(points[0])
	watcher.setup(mc, map)
	mc.enemies.append(watcher)
	await frames(3)
	var failed: PackedStringArray = []
	var worst := 0.0
	for i in range(1, points.size()):
		var goal: Vector3 = map.closest_nav_point(points[i])
		_close_unlocked_doors()
		var budget := goal.distance_to(watcher.global_position) * 1.8 / SPEED + SLACK
		var t := 0.0
		var dt := Engine.time_scale / Engine.physics_ticks_per_second
		var reached := false
		while t < budget:
			# Keep it on task (a heard door or a search would wander off).
			if watcher.state != Watcher.S.INVESTIGATE:
				watcher.set("_target", goal)
				watcher.set("_has_target", true)
				watcher.call("_enter", Watcher.S.INVESTIGATE)
				watcher.set("_has_target", true)
			await get_tree().physics_frame
			t += dt
			var flat := Vector2(watcher.global_position.x - goal.x, watcher.global_position.z - goal.z).length()
			if flat < 1.3 and absf(watcher.global_position.y - goal.y) < 1.5:
				reached = true
				break
		worst = maxf(worst, t / budget)
		if not reached:
			var ag: NavigationAgent3D = watcher.agent
			(
				failed
				. append(
					(
						"%s -> %s (stopped at %s; finished %s, next %s, path %d pts, state %s, vel %s, pause %.2f, hit %s)"
						% [
							points[i - 1],
							points[i],
							watcher.global_position.snapped(Vector3.ONE * 0.1),
							ag.is_navigation_finished(),
							ag.get_next_path_position().snapped(Vector3.ONE * 0.1),
							ag.get_current_navigation_path().size(),
							watcher.state,
							watcher.velocity.snapped(Vector3.ONE * 0.1),
							float(watcher.get("_pause")),
							(
								watcher.get_last_slide_collision().get_collider()
								if watcher.get_last_slide_collision()
								else null
							),
						]
					)
				)
			)
	print("  %s: %d legs, worst %.0f%% of budget" % [map_id, points.size() - 1, worst * 100.0])
	for f in failed:
		print("  STUCK %s: %s" % [map_id, f])
	assert_empty(failed, "%s: enemy got stuck" % map_id)
	map.queue_free()
	map = null
	await frames(2)


func _close_unlocked_doors() -> void:
	for ent in mc.entities.values():
		if ent is DoorEntity and not (ent as DoorEntity).is_locked() and (ent as DoorEntity).is_open():
			mc.set_entity_state((ent as DoorEntity).entity_id, {"open": false, "locked": false})
