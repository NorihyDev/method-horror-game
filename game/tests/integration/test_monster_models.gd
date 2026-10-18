extends TestCase
## Every map's enemy uses its imported monster, with every clip the AI plays,
## scaled to fit through doors, and actually moving when a clip plays.
## The models come from third-party packs kept out of the repository: a
## checkout without them skips this and plays the procedural monsters.


func test_every_monster_loads_animates_and_fits() -> void:
	for style in MonsterCatalog.MODELS:
		if MonsterCatalog.entry(style).is_empty():
			print("  (no model for %s on this machine: procedural body)" % style)
			continue
		var rig := WatcherRig.new()
		rig.style = style
		add_child(rig)
		assert_true(rig.model != null, "%s: imported model in use" % style)
		if rig.model == null:
			rig.queue_free()
			continue
		for clip in WatcherRig.ANIMS:
			if clip != "freeze":
				assert_true(rig.anim.has_animation(clip), "%s has %s" % [style, clip])
		var skel := rig.model.find_child("Skeleton3D", true, false) as Skeleton3D
		var before := _pose(skel)
		rig.play("walk", 0.0)
		for i in 12:
			await get_tree().process_frame
		assert_eq(rig.current(), "walk", "%s plays walk" % style)
		assert_true(_pose(skel).distance_to(before) > 0.01, "%s moves when walking" % style)
		var top := 0.0
		for mi: MeshInstance3D in rig.model.find_children("*", "MeshInstance3D", true, false):
			top = maxf(top, (mi.get_aabb().end.y) * rig.model.scale.y)
		assert_true(top > 1.2 and top < 2.4, "%s fits under a 2.2 m door frame-ish (%.2f m)" % [style, top])
		if rig.headlamp:
			var fwd := rig.global_basis.z
			var beam := -rig.headlamp.global_basis.z
			assert_true(beam.dot(fwd) > 0.5, "%s: lamp shines forward (%.2f)" % [style, beam.dot(fwd)])
		rig.play("freeze")
		await get_tree().process_frame
		assert_true(_pose(skel).distance_to(_rest(skel)) > 0.01, "%s: freezing never snaps to the rest pose" % style)
		rig.queue_free()
	await get_tree().process_frame


static func _pose(skel: Skeleton3D) -> Vector4:
	var acc := Vector4.ZERO
	for b in skel.get_bone_count():
		var q := skel.get_bone_pose_rotation(b)
		acc += Vector4(q.x, q.y, q.z, q.w)
	return acc


static func _rest(skel: Skeleton3D) -> Vector4:
	var acc := Vector4.ZERO
	for b in skel.get_bone_count():
		var q := skel.get_bone_rest(b).basis.get_rotation_quaternion()
		acc += Vector4(q.x, q.y, q.z, q.w)
	return acc
