extends SceneTree
## Development tool: renders every character's head from the front, left,
## right and back into <out_dir>/<id>_<view>.png (idle pose, neutral light).
## Usage: godot --path game --resolution 512x512 -s res://tools/char_shots.gd -- <out_dir> [id ...]

const VIEWS := {"front": 0.0, "left": 90.0, "right": -90.0, "back": 180.0}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://char_shots"
	var ids: Array = args.slice(1) if args.size() > 1 else Array(CharacterCatalog.ids())
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.42, 0.44, 0.47)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.55)
	root.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-25), deg_to_rad(25), 0)
	key.light_energy = 1.1
	root.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-15), deg_to_rad(205), 0)
	fill.light_energy = 0.5
	root.add_child(fill)
	var cam := Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.current = true
	for id: String in ids:
		var model := TeammateModel.create(id)
		if model == null:
			continue
		root.add_child(model)
		model.play("idle")
		for i in 20:
			await process_frame
		var skel := model.find_child("Skeleton3D", true, false) as Skeleton3D
		var head := skel.global_transform * skel.get_bone_global_pose(skel.find_bone("head"))
		var c := head.origin + Vector3(0, 0.08, 0)
		for view: String in VIEWS:
			var a := deg_to_rad(float(VIEWS[view]))
			# The game's forward is -Z: the face looks towards -Z.
			var eye := c + Vector3(-sin(a), 0.02, -cos(a)) * 0.95
			cam.look_at_from_position(eye, c)
			for i in 2:
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png(out.path_join("%s_%s.png" % [id, view]))
		model.queue_free()
		await process_frame
	print("char shots done")
	quit(0)
