extends TestCase
## Teammates are drawn as the animated Punky model, and the clip follows
## what the player is doing.


func test_model_loads_with_every_clip_and_a_hand_bone() -> void:
	var model := TeammateModel.create()
	assert_true(model != null, "punky.glb loads")
	if model == null:
		return
	add_child(model)
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
	assert_true(tris > 5000 and tris < 30000, "mobile triangle budget (%d)" % tris)
	assert_true(top > 1.55 and top < 1.95, "human height (%.2f m)" % top)
	model.queue_free()


func test_clip_follows_motion() -> void:
	var model := TeammateModel.create()
	if model == null:
		fail("model missing")
		return
	add_child(model)
	var cases := [
		[0.0, false, false, "idle"],
		[2.7, false, false, "walk"],
		[4.7, false, false, "run"],
		[0.0, true, false, "crouch_idle"],
		[1.35, true, false, "crouch_walk"],
		[0.0, false, true, "downed"],
		[4.7, true, true, "downed"],
	]
	for c in cases:
		model.update_motion(c[0], c[1], c[2])
		assert_eq(model.current, c[3], "speed %s crouch %s downed %s" % [c[0], c[1], c[2]])
		assert_true(model.anim.speed_scale > 0.0 and model.anim.speed_scale < 2.21, "playback rate")
	model.queue_free()


func test_remote_avatar_uses_model_and_follows_status() -> void:
	var avatar := RemoteAvatar.new()
	add_child(avatar)
	var model := avatar.find_child("Punky", true, false) as TeammateModel
	assert_true(model != null, "avatar shows Punky")
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
