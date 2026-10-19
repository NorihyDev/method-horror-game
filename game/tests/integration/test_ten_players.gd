extends HouseFixture
## Up to ten players: every map gives each of them a separate spawn spot on
## walkable floor (maps have six spawn points; the rest stand beside them).


func test_ten_players_get_their_own_spawn_on_every_map() -> void:
	assert_eq(NetProtocol.MAX_PLAYERS, 10)
	assert_eq(NetProtocol.RELAY_MAX_PLAYERS, 10)
	for m in Session.maps:
		if not m.is_playable() or String(m.id) == "tutorial":
			continue
		if not await build(String(m.id), "normal", 3):
			continue
		await map.wait_for_navigation()
		var spots: Array[Vector3] = []
		for i in NetProtocol.MAX_PLAYERS:
			var p := map.player_spawn(i).origin
			var on_floor := map.closest_nav_point(p)
			assert_true(
				Vector2(on_floor.x - p.x, on_floor.z - p.z).length() < 0.6, "%s: player %d on the floor" % [m.id, i + 1]
			)
			for q in spots:
				assert_true(p.distance_to(q) > 0.5, "%s: player %d has their own spot" % [m.id, i + 1])
			spots.append(p)
		map.queue_free()
		map = null
		# The old map's navigation lingers a few frames after it is freed.
		await frames(30)
