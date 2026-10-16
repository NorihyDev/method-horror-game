extends Node
## Runs every test_*.gd under res://tests/unit and res://tests/integration.
## Started by the App when launched with `-- --test`. Exits 0 on success,
## 1 on failure, 2 on watchdog timeout. Optional `--filter=<substring>`.

const DIRS: PackedStringArray = ["res://tests/unit", "res://tests/integration"]
const WATCHDOG_SECONDS := 240.0

var _total := 0
var _failed := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var watchdog := get_tree().create_timer(WATCHDOG_SECONDS, true, false, true)
	watchdog.timeout.connect(
		func() -> void:
			printerr("TEST WATCHDOG: tests exceeded %ds" % WATCHDOG_SECONDS)
			get_tree().quit(2)
	)
	_run.call_deferred()


func _run() -> void:
	var filter := AppInfo.arg_value("--filter", "")
	var started := Time.get_ticks_msec()
	# Saves/Settings already use isolated test_* files in --test mode.
	for dir_path in DIRS:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		var files := Array(dir.get_files())
		files.sort()
		for f in files:
			if not (f.begins_with("test_") and f.ends_with(".gd")):
				continue
			if not filter.is_empty() and not str(f).contains(filter):
				continue
			await _run_file(dir_path.path_join(f))
	var ms := Time.get_ticks_msec() - started
	print("")
	print("==== %d tests, %d failed (%.1fs) ====" % [_total, _failed, ms / 1000.0])
	get_tree().paused = false
	get_tree().quit(1 if _failed > 0 else 0)


func _run_file(path: String) -> void:
	var script: Script = load(path)
	if script == null:
		_failed += 1
		printerr("FAILED TO LOAD " + path)
		return
	var methods: PackedStringArray = []
	for m in script.get_script_method_list():
		var n: String = m["name"]
		if n.begins_with("test_") and not methods.has(n):
			methods.append(n)
	print("-- " + path.get_file())
	for method in methods:
		var tc: TestCase = script.new()
		tc.app_root = get_parent()
		add_child(tc)
		tc.current_test = method
		await tc.before_each()
		var t0 := Time.get_ticks_msec()
		await tc.call(method)
		await tc.after_each()
		_total += 1
		if tc.failures.is_empty():
			print("   ok   %s (%dms)" % [method, Time.get_ticks_msec() - t0])
		else:
			_failed += 1
			print("   FAIL %s" % method)
			for f in tc.failures:
				printerr("        " + f)
		tc.queue_free()
		await get_tree().process_frame
