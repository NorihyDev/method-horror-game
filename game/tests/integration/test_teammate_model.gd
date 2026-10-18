extends TestCase
## Teammates are drawn as the animated Punky model, and the clip follows
## what the player is doing.


func test_every_character_loads_with_every_clip_and_a_hand_bone() -> void:
	for id in CharacterCatalog.ids():
		await _check_character(id)


func _check_character(id: String) -> void:
	var model := TeammateModel.create(id)
	assert_true(model != null, "%s loads" % id)
	if model == null:
		return
	add_child(model)
	assert_eq(String(model.name), CharacterCatalog.display_name(id))
	assert_true(model.anim != null, "has an AnimationPlayer")
	for clip in TeammateModel.CLIPS:
		assert_true(model.anim.has_animation(clip), "clip %s" % clip)
		if model.anim.has_animation(clip):
			assert_eq(model.anim.get_animation(clip).loop_mode, Animation.LOOP_LINEAR, "%s loops" % clip)
	var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
	assert_true(skel != null and skel.find_bone("hand_r") >= 0, "skeleton with hand_r")
	var tris := 0
	var top := 0.0
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh is ArrayMesh:
			for s in mi.mesh.get_surface_count():
				tris += (mi.mesh as ArrayMesh).surface_get_array_index_len(s) / 3
			top = maxf(top, mi.mesh.get_aabb().end.y)
	assert_true(tris > 5000 and tris < 35000, "%s: mobile triangle budget (%d)" % [id, tris])
	assert_true(top > 1.55 and top < 1.95, "%s: human height (%.2f m)" % [id, top])
	assert_true(CharacterCatalog.portrait(id) != null, "%s has a portrait" % id)
	model.queue_free()


func test_clip_follows_motion() -> void:
	var model := TeammateModel.create()
	if model == null:
		fail("model missing")
		return
	add_child(model)
	var cases := [
		[0.0, false, false, "idle"],
		[1.2, false, false, "walk"],
		[2.7, false, false, "jog"],
		[4.7, false, false, "run"],
		[0.0, true, false, "crouch_idle"],
		[1.35, true, false, "crouch_walk"],
		[0.0, false, true, "downed"],
		[4.7, true, true, "downed"],
	]
	for c in cases:
		model.update_motion(c[0], c[1], c[2])
		assert_eq(model.current, c[3], "speed %s crouch %s downed %s" % [c[0], c[1], c[2]])
		assert_true(model.anim.speed_scale > 0.0 and model.anim.speed_scale < 1.61, "playback rate")
	model.queue_free()


func test_remote_avatar_uses_model_and_follows_status() -> void:
	var avatar := RemoteAvatar.new()
	add_child(avatar)
	var model := (
		avatar.find_child(CharacterCatalog.display_name(CharacterCatalog.DEFAULT), true, false) as TeammateModel
	)
	assert_true(model != null, "avatar shows the default character")
	avatar.set_status(MatchState.STATUS_DOWNED)
	avatar._process(0.016)
	if model:
		assert_eq(model.current, "downed")
	avatar.set_status(MatchState.STATUS_ALIVE)
	avatar.target(avatar.global_position, 0.0, false, 1)
	avatar._process(0.016)
	if model:
		assert_eq(model.current, "crouch_idle")
	avatar.queue_free()


func test_avatar_shows_the_chosen_character_and_rejects_unknown_ones() -> void:
	for pair in [["tsila", "Tsila"], ["punky", "Punky"], ["<b>evil</b>", "Norihy"], ["", "Norihy"]]:
		var avatar := RemoteAvatar.new()
		avatar.character = pair[0]
		add_child(avatar)
		assert_true(avatar.find_child(pair[1], true, false) is TeammateModel, "%s -> %s" % pair)
		avatar.queue_free()
	await get_tree().process_frame


func test_character_choice_travels_with_the_player() -> void:
	var before := Saves.character()
	Saves.set_character("tsila")
	assert_eq(Saves.character(), "tsila", "saved on the profile")
	var hello := {"lan_id": "0123456789abcdef", "name": "Tester", "color": 1, "char": Saves.character()}
	assert_eq(NetProtocol.identify(hello, false, "", "")["char"], "tsila", "sent when joining")
	hello["char"] = 42
	assert_eq(NetProtocol.identify(hello, false, "", "")["char"], CharacterCatalog.DEFAULT, "junk is ignored")
	var s := MatchState.new()
	s.add_player(2, "Tester")["char"] = "tsila"
	var copy := MatchState.from_snapshot(JSON.parse_string(JSON.stringify(s.to_snapshot())))
	assert_eq(copy.player(2).get("char"), "tsila", "kept in snapshots")
	Saves.set_character(before)
