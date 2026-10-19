extends SceneTree
## Development tool: renders every furniture model seen from +Z (its front,
## by the game's convention) into <out_dir>/<id>.png.
## Usage: godot --path game --resolution 640x640 -s res://tools/prop_shots.gd -- <out_dir>


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://prop_shots"
	DirAccess.make_dir_recursive_absolute(out)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.22, 0.24, 0.27)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-35), deg_to_rad(20), 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/props/props.json"))
	for id: String in info:
		var size: Array = info[id]["size"]
		var node := (load("res://assets/props/%s.glb" % id) as PackedScene).instantiate() as Node3D
		root.add_child(node)
		var big := maxf(float(size[0]), maxf(float(size[1]), float(size[2])))
		var h := float(size[1])
		# From the front (+Z), a little above and to the side.
		cam.look_at_from_position(Vector3(big * 0.5, h * 0.5 + big * 0.55, big * 1.9), Vector3(0, h * 0.45, 0))
		for i in 3:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png(out.path_join(id + ".png"))
		node.queue_free()
		await process_frame
	print("prop shots done")
	quit(0)
