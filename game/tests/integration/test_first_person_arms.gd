extends TestCase
## The first-person arms: every character's model cut down to arms and hands,
## and the IK puts each wrist where the viewmodel asks.


func test_every_character_gives_arms_that_reach_their_targets() -> void:
	for id in CharacterCatalog.ids():
		var arms := FirstPersonArms.new()
		add_child(arms)
		assert_true(arms.setup(id), "%s: arms built" % id)
		if not arms.ready_ok:
			arms.queue_free()
			continue
		var tris := 0
		for mi: MeshInstance3D in arms.find_children("*", "MeshInstance3D", true, false):
			if mi.is_queued_for_deletion():
				continue
			var lower := String(mi.name).to_lower()
			assert_false(lower.contains("head") or lower.contains("hair"), "%s: no head or hair (%s)" % [id, mi.name])
			for s in mi.mesh.get_surface_count():
				tris += mi.mesh.surface_get_array_index_len(s) / 3
		assert_true(tris > 500 and tris < 20000, "%s: arms only (%d triangles)" % [id, tris])
		for side in ["r", "l"]:
			var x := 0.06 if side == "r" else -0.12
			var target := Vector3(x, -0.25, -0.38)
			arms.pose_arm(side, target, Vector3(0, 0, -1), Vector3.UP, Vector3(1 if side == "r" else -1, -1, 0.4), 0.8)
			var hand := arms.skeleton.find_bone("hand_" + side)
			var xf: Transform3D = arms.get("_skel_xf")
			var at := (xf * arms.skeleton.get_bone_global_pose(hand)).origin
			assert_true(
				at.distance_to(target) < 0.02,
				"%s: %s wrist on target (%.3f m off)" % [id, side, at.distance_to(target)]
			)
		arms.queue_free()
	await get_tree().process_frame
