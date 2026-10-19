class_name BloodRule
extends Control
## Accent rule under titles: a ragged blood-red stroke with drips that run
## down slowly when the screen opens (already run with reduced motion).

const COLOR := Color("7d0c0c")
const COLOR_HI := Color("a51818")

var _drips: Array[Vector3] = []  # x, max length, width
var _grow := 0.0


func _init(width: float = 64.0) -> void:
	custom_minimum_size = Vector2(width, 14)
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = int(width * 131.0)
	for i in maxi(1, int(width / 34.0)):
		_drips.append(
			Vector3(rng.randf_range(0.08, 0.92) * width, rng.randf_range(4.0, 10.0), rng.randf_range(1.6, 3.0))
		)


func _ready() -> void:
	_grow = 1.0 if Settings.b("reduced_motion") else 0.0


func _process(delta: float) -> void:
	if _grow < 1.0:
		_grow = minf(1.0, _grow + delta / 2.4)
		queue_redraw()


func _draw() -> void:
	var w := size.x
	# Ragged stroke: thicker in the middle, thinning to the ends.
	var steps := 24
	for i in steps:
		var x0 := w * i / steps
		var x1 := w * (i + 1) / steps
		var t := (i + 0.5) / steps
		var h := lerpf(1.2, 3.6, sin(t * PI)) + sin(i * 2.3) * 0.5
		draw_rect(Rect2(x0, 0, x1 - x0 + 0.5, h), COLOR)
	draw_rect(Rect2(w * 0.18, 0.6, w * 0.5, 1.0), COLOR_HI)
	var ease_t := 1.0 - pow(1.0 - _grow, 3.0)
	for d in _drips:
		var length := d.y * ease_t
		draw_rect(Rect2(d.x - d.z * 0.5, 2, d.z, length), COLOR)
		draw_circle(Vector2(d.x, 2 + length), d.z * 0.85, COLOR)
