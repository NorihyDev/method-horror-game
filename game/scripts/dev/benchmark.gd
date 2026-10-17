class_name Benchmark
extends Node
## Frame-time benchmark for device profiling (development builds only).
##
## For each playable map, at the current graphics settings: builds the level,
## walks the player along the map's patrol route with the enemy present, runs
## half the time in darkness and half with the power on, and records frame
## times as the player gets them (their cap and vsync) plus the engine's own
## per-frame cost — GPU time, CPU render time, script and physics time —
## which shows the real headroom regardless of vsync. Also draw calls and
## memory. Results go to user://bench/<time>.json and
## are returned as a summary. Start it from Settings → Graphics (debug
## builds) or with `-- --bench` on the command line.

signal progress(text: String)
signal finished(report: Dictionary)

const SECONDS_PER_MAP := 20.0
const WARMUP := 2.0
const WALK_SPEED := 2.4
const SUMMARY_LINE := (
	"%s: %.1f fps · frame p95 %.1f ms · GPU %.2f ms (p95 %.2f) · CPU render %.2f ms"
	+ " · scripts %.2f ms · physics %.2f ms · %d draw calls · %.0f%% frames under 30 fps"
)

var app: App
var _samples: Array[float] = []
var _draw_calls: Array[int] = []
var _primitives: Array[int] = []
var _gpu: Array[float] = []
var _cpu_render: Array[float] = []
var _process: Array[float] = []
var _physics: Array[float] = []


static func allowed() -> bool:
	return AppInfo.is_dev_build()


func run() -> Dictionary:
	var report := {
		"when": Time.get_datetime_string_from_system(true),
		"device": OS.get_model_name(),
		"os": "%s %s" % [OS.get_name(), OS.get_version()],
		"gpu": RenderingServer.get_video_adapter_name(),
		"renderer": str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
		"godot": Engine.get_version_info().get("string", ""),
		"viewport": str(get_viewport().get_visible_rect().size),
		"settings": Settings.snapshot(),
		"frame_cap": Engine.max_fps,
		"maps": [],
	}
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	for map_def in Session.maps:
		if not map_def.is_playable() or map_def.is_tutorial:
			continue
		var result := await _run_map(String(map_def.id))
		report["maps"].append(result)
	RenderingServer.viewport_set_measure_render_time(vp, false)
	_save(report)
	# Also to stdout / logcat, so phone runs can be read with `adb logcat`.
	print("BENCH " + JSON.stringify(report))
	print(summary_text(report))
	finished.emit(report)
	return report


func _run_map(map_id: String) -> Dictionary:
	app.set_world(null)
	await get_tree().process_frame
	var config := {
		"mode": "solo", "map_id": map_id, "difficulty_id": "normal", "seed": 1, "match_id": "bench", "player_count": 1
	}
	Session.match_config = config
	var built := LevelLoader.build(app.world_root, config)
	if not built["ok"]:
		return {"map": map_id, "error": str(built["error"])}
	var map: MapBase = built["map"]
	var mc: MatchController = built["match"]
	app.set_world(map)
	var player := LevelLoader.spawn_local_player(map, mc, 1, "Bench")
	player.input_enabled = false
	player.set_physics_process(false)
	mc.apply_all_states()
	mc.begin()
	await map.wait_for_navigation()
	mc.set("_enemy_arrival_at", 0.0)
	var route: Array[Vector3] = map.patrol_points.duplicate()
	if route.is_empty():
		route = [player.global_position]
	_samples.clear()
	_draw_calls.clear()
	_primitives.clear()
	_gpu.clear()
	_cpu_render.clear()
	_process.clear()
	_physics.clear()
	var vp := get_viewport().get_viewport_rid()
	# Re-arm the GPU timer for each level; it can go stale across world swaps.
	RenderingServer.viewport_set_measure_render_time(vp, false)
	await get_tree().process_frame
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var elapsed := 0.0
	var leg := 0
	var target := map.closest_nav_point(route[0])
	var powered := false
	while elapsed < SECONDS_PER_MAP + WARMUP:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		elapsed += dt
		if not powered and elapsed > WARMUP + SECONDS_PER_MAP * 0.5:
			powered = true
			map.set_power(true)
		# Walk toward the next patrol point, looking where we go.
		var to := target - player.global_position
		to.y = 0.0
		if to.length() < 0.4:
			leg = (leg + 1) % route.size()
			target = map.closest_nav_point(route[leg])
		else:
			var step := to.normalized() * minf(WALK_SPEED * dt, to.length())
			player.global_position = Vector3(
				player.global_position.x + step.x, target.y, player.global_position.z + step.z
			)
			player.set("_yaw", atan2(-to.x, -to.z))
		player.call("_tick_presentation", dt, Vector2(0, -1))
		mc.state.players[1]["pos"] = MatchState.vec_to_array(player.global_position)
		if elapsed > WARMUP:
			_samples.append(dt * 1000.0)
			_draw_calls.append(
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			)
			_primitives.append(
				RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			)
			_gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(vp))
			_cpu_render.append(RenderingServer.viewport_get_measured_render_time_cpu(vp))
			_process.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			_physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		progress.emit("%s  %d / %d s" % [tr(map.definition.title_key), int(elapsed), int(SECONDS_PER_MAP + WARMUP)])
	var result := _summarize(map_id)
	result["video_mem_mb"] = snappedf(
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, 0.1
	)
	result["static_mem_mb"] = snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1)
	result["enemy_spawned"] = not mc.enemies.is_empty()
	AudioService.stop_all_world()
	app.set_world(null)
	await get_tree().process_frame
	return result


func _summarize(map_id: String) -> Dictionary:
	var sorted := _samples.duplicate()
	sorted.sort()
	var n := sorted.size()
	if n == 0:
		return {"map": map_id, "error": "no samples"}
	var total := 0.0
	for s in sorted:
		total += s
	var avg_ms := total / n
	var avg_calls := 0.0
	for c in _draw_calls:
		avg_calls += c
	var avg_prims := 0.0
	for p in _primitives:
		avg_prims += p
	return {
		"map": map_id,
		"frames": n,
		"avg_fps": snappedf(1000.0 / avg_ms, 0.1),
		"avg_ms": snappedf(avg_ms, 0.01),
		"p50_ms": snappedf(sorted[n / 2], 0.01),
		"p95_ms": snappedf(sorted[mini(n - 1, int(n * 0.95))], 0.01),
		"p99_ms": snappedf(sorted[mini(n - 1, int(n * 0.99))], 0.01),
		"max_ms": snappedf(sorted[n - 1], 0.01),
		"under_30fps_pct": snappedf(100.0 * sorted.filter(func(s: float) -> bool: return s > 33.4).size() / n, 0.1),
		"avg_draw_calls": int(avg_calls / maxi(_draw_calls.size(), 1)),
		"avg_primitives": int(avg_prims / maxi(_primitives.size(), 1)),
		"gpu_ms": _cost(_gpu),
		"cpu_render_ms": _cost(_cpu_render),
		"process_ms": _cost(_process),
		"physics_ms": _cost(_physics),
	}


## {avg, p95} of a per-frame cost series in milliseconds.
static func _cost(series: Array[float]) -> Dictionary:
	if series.is_empty():
		return {"avg": 0.0, "p95": 0.0}
	var sorted := series.duplicate()
	sorted.sort()
	var total := 0.0
	for v in sorted:
		total += v
	return {
		"avg": snappedf(total / sorted.size(), 0.01),
		"p95": snappedf(sorted[mini(sorted.size() - 1, int(sorted.size() * 0.95))], 0.01)
	}


func _save(report: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("user://bench")
	var stamp := str(report["when"]).replace(":", "-").replace("T", "_")
	var path := "user://bench/bench_%s.json" % stamp
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(report, "  "))
		report["path"] = ProjectSettings.globalize_path(path)


## One line per map, for the screen and the console.
static func summary_text(report: Dictionary) -> String:
	var lines: PackedStringArray = []
	for m in report.get("maps", []):
		if m.has("error"):
			lines.append("%s: %s" % [m["map"], m["error"]])
			continue
		var values := [
			m["map"],
			m["avg_fps"],
			m["p95_ms"],
			m["gpu_ms"]["avg"],
			m["gpu_ms"]["p95"],
			m["cpu_render_ms"]["avg"],
			m["process_ms"]["avg"],
			m["physics_ms"]["avg"],
			m["avg_draw_calls"],
			m["under_30fps_pct"],
		]
		lines.append(SUMMARY_LINE % values)
	return "\n".join(lines)
