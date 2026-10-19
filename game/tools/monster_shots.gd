extends SceneTree
## Development tool: renders every monster mid-clip into a contact sheet.
## Usage: godot --path game --resolution 1280x720 -s res://tools/monster_shots.gd -- <out_dir>

const CLIPS := ["idle", "walk", "run", "windup", "strike", "search"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var out: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://monster_shots"
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.12, 0.12, 0.14)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.55)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.look_at_from_position(Vector3(0, 1.1, 3.0), Vector3(0, 0.95, 0))
	cam.current = true
	for style in MonsterCatalog.MODELS:
		var rig := WatcherRig.new()
		rig.style = style
		root.add_child(rig)
		await process_frame
		for clip in CLIPS:
			rig.play(clip, 0.0)
			# Mid-clip, not the first frame.
			var length := rig.anim.current_animation_length if rig.anim else 1.0
			rig.anim.seek(length * 0.35, true)
			rig.anim.speed_scale = 0.0
			for i in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [style, clip]))
			rig.anim.speed_scale = 1.0
		rig.queue_free()
		await process_frame
	print("monster shots done")
	quit(0)
