extends TestCase
## Teammates walk, crouch and look around as their packets arrive, the same
## on the host (fed from client motion) as on clients.


func test_teammate_walks_and_looks_where_they_look() -> void:
	var avatar := RemoteAvatar.new()
	avatar.player_id = 2
	add_child(avatar)
	avatar.server_place(Vector3.ZERO, 0.0)
	await get_tree().process_frame
	var model: TeammateModel = avatar.get("_model")
	if model == null:
		print("  (no character model on this machine)")
		avatar.queue_free()
		return
	# 15 Hz packets moving at a walking pace (2.7 m/s), looking up 0.6 rad.
	var pos := Vector3.ZERO
	var flags := 4 | NetProtocol.pitch_bits(0.6)
	var t := 0.0
	var next := 0.0
	while t < 1.5:
		await get_tree().process_frame
		t += get_process_delta_time()
		if t >= next:
			next += 1.0 / 15.0
			pos += Vector3(0, 0, -2.7 / 15.0)
			avatar.target(pos, 0.0, false, flags)
	assert_true(model.current in ["walk", "jog"], "walks between packets (playing %s)" % model.current)
	var look: LookModifier = avatar.get("_look")
	assert_true(look != null and look.pitch > 0.45, "looks up with the player")
	assert_true((avatar.get("_light") as SpotLight3D).rotation.x > 0.45, "the beam follows the look")
	# The tilt is applied after the clip each frame (and not kept in the pose).
	assert_true(look.applied > 10, "head and chest tilted every frame (%d)" % look.applied)
	assert_eq((look.get("_axis") as Dictionary).size(), 3, "chest, neck and head take part")
	# Crouching.
	for i in 30:
		avatar.target(pos, 0.0, false, 1)
		await get_tree().process_frame
	assert_eq(model.current, "crouch_idle", "crouches")
	assert_eq(NetProtocol.pitch_from_bits(4), 0.0, "old builds' flags read as level")
	avatar.queue_free()
	await get_tree().process_frame
