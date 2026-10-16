class_name ItemIcon
extends Control
## Procedural 2D item icon (no texture/font dependency). Shapes follow
## ItemDefinition.shape so icons stay consistent with the 3D models.

var item_id := "":
	set(v):
		item_id = v
		queue_redraw()
var count := 0:
	set(v):
		count = v
		queue_redraw()
var selected := false:
	set(v):
		selected = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(r, Color(0.04, 0.04, 0.045, 0.82))
	draw_rect(r, ThemeFactory.CRIMSON_HI if selected else ThemeFactory.LINE, false, 2.0 if selected else 1.0)
	if item_id.is_empty():
		return
	var def: ItemDefinition = Session.item(item_id)
	var col := def.icon_color if def else ThemeFactory.TEXT
	var shape := String(def.shape) if def else "box"
	var c := size * 0.5
	var s := minf(size.x, size.y) * 0.32
	match shape:
		"fuse":
			draw_rect(Rect2(c - Vector2(s * 0.9, s * 0.35), Vector2(s * 1.8, s * 0.7)), Color(0.85, 0.8, 0.68))
			draw_rect(Rect2(c - Vector2(s * 1.15, s * 0.42), Vector2(s * 0.35, s * 0.84)), col)
			draw_rect(Rect2(c + Vector2(s * 0.8, -s * 0.42), Vector2(s * 0.35, s * 0.84)), col)
		"key":
			draw_arc(c - Vector2(s * 0.6, 0), s * 0.38, 0, TAU, 20, col, s * 0.18, true)
			draw_line(c - Vector2(s * 0.22, 0), c + Vector2(s * 1.0, 0), col, s * 0.18)
			draw_line(c + Vector2(s * 0.6, 0), c + Vector2(s * 0.6, s * 0.35), col, s * 0.16)
			draw_line(c + Vector2(s * 0.9, 0), c + Vector2(s * 0.9, s * 0.25), col, s * 0.16)
		"belt":
			draw_arc(c, s * 0.8, 0, TAU, 28, col.lightened(0.15), s * 0.22, true)
		"gear", "assembly":
			draw_circle(c, s * 0.62, col)
			for i in 10:
				var a := TAU * i / 10.0
				draw_line(c + Vector2(cos(a), sin(a)) * s * 0.55, c + Vector2(cos(a), sin(a)) * s * 0.9, col, s * 0.2)
			draw_circle(c, s * 0.2, Color(0.04, 0.04, 0.045))
			if shape == "assembly":
				draw_arc(c, s * 1.0, 0, TAU, 28, Color(0.25, 0.25, 0.27), s * 0.14, true)
		"battery":
			draw_rect(Rect2(c - Vector2(s * 0.45, s * 0.85), Vector2(s * 0.9, s * 1.7)), Color(0.15, 0.15, 0.16))
			draw_rect(Rect2(c - Vector2(s * 0.45, s * 0.85), Vector2(s * 0.9, s * 0.45)), Color(0.6, 0.12, 0.1))
			draw_rect(Rect2(c - Vector2(s * 0.18, s * 1.02), Vector2(s * 0.36, s * 0.17)), Color(0.7, 0.7, 0.7))
		"card":
			draw_rect(Rect2(c - Vector2(s, s * 0.62), Vector2(s * 2.0, s * 1.24)), col)
			draw_rect(Rect2(c - Vector2(s * 0.75, s * 0.35), Vector2(s * 0.6, s * 0.3)), ThemeFactory.CRIMSON)
		_:
			draw_rect(Rect2(c - Vector2(s, s) * 0.7, Vector2(s, s) * 1.4), col)
	if count > 1:
		var font := get_theme_default_font()
		draw_string(font, Vector2(size.x - 20, size.y - 6), "×%d" % count, HORIZONTAL_ALIGNMENT_RIGHT, 18, 15, ThemeFactory.TEXT)
