extends TestCase
## The benchmark's pure helpers: cost summaries and the one-line report.


func test_cost_summary() -> void:
	var series: Array[float] = []
	for i in 100:
		series.append(float(i + 1))
	var cost := Benchmark._cost(series)
	assert_true(absf(float(cost["avg"]) - 50.5) < 0.001, "average of 1..100")
	assert_eq(float(cost["p95"]), 96.0, "95th percentile picks the sorted sample")
	var empty: Array[float] = []
	assert_eq(Benchmark._cost(empty), {"avg": 0.0, "p95": 0.0}, "no samples gives zeros")


func test_summary_text() -> void:
	var map := {
		"map": "house",
		"avg_fps": 60.0,
		"p95_ms": 16.7,
		"gpu_ms": {"avg": 2.65, "p95": 5.09},
		"cpu_render_ms": {"avg": 0.67, "p95": 1.0},
		"process_ms": {"avg": 2.11, "p95": 3.0},
		"physics_ms": {"avg": 0.63, "p95": 1.0},
		"avg_draw_calls": 180,
		"under_30fps_pct": 0.0,
	}
	var text := Benchmark.summary_text({"maps": [map, {"map": "black_ward", "error": "no samples"}]})
	var lines := text.split("\n")
	assert_eq(lines.size(), 2, "one line per map")
	assert_true(lines[0].begins_with("house: 60.0 fps"), lines[0])
	assert_true(lines[0].contains("GPU 2.65 ms (p95 5.09)"), lines[0])
	assert_true(lines[0].contains("180 draw calls"), lines[0])
	assert_eq(lines[1], "black_ward: no samples", "errors are reported, not hidden")
