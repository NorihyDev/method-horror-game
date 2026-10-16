class_name BadgeIcon
extends Control
## Draws a profile badge shape (no font dependency).

var shape := "none":
	set(v):
		shape = v
		queue_redraw()
var tint := Color.WHITE:
	set(v):
		tint = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.42
	match shape:
		"eye":
			var pts := PackedVector2Array()
			for i in 33:
				var a := PI * i / 32.0
				pts.append(c + Vector2(cos(a) * r, -sin(a) * r * 0.55))
			for i in 33:
				var a := PI + PI * i / 32.0
				pts.append(c + Vector2(cos(a) * r, -sin(a) * r * 0.55))
			draw_polyline(pts, tint, 2.5, true)
			draw_circle(c, r * 0.28, tint)
		"key":
			draw_arc(c - Vector2(r * 0.45, 0), r * 0.35, 0, TAU, 24, tint, 3.0, true)
			draw_line(c - Vector2(r * 0.1, 0), c + Vector2(r, 0), tint, 3.0)
			draw_line(c + Vector2(r * 0.6, 0), c + Vector2(r * 0.6, r * 0.35), tint, 3.0)
		"star":
			var pts := PackedVector2Array()
			for i in 11:
				var a := -PI / 2 + TAU * i / 10.0
				var rr := r if i % 2 == 0 else r * 0.45
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_polyline(pts, tint, 2.5, true)
		_:
			draw_arc(c, r * 0.6, 0, TAU, 24, Color(tint, 0.35), 1.5, true)
