extends SceneTree
## Loads every GDScript under res://scripts, res://tests and res://tools so
## parse/compile errors are reported with file and line. Exit code 1 on error.
## Usage: godot --headless --path game --script res://tools/parse_all.gd

const ROOTS: PackedStringArray = ["res://scripts", "res://tests", "res://tools"]


func _initialize() -> void:
	var files: PackedStringArray = []
	for root in ROOTS:
		_collect(root, files)
	var failed: PackedStringArray = []
	for path in files:
		var script := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as GDScript
		if script == null:
			failed.append(path)
		elif not script.can_instantiate():
			failed.append(path)
	print("Parsed %d scripts, %d failed." % [files.size(), failed.size()])
	for f in failed:
		printerr("FAILED: " + f)
	quit(1 if not failed.is_empty() else 0)


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_collect(dir_path.path_join(sub), out)
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
