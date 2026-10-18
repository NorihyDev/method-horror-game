class_name TouchIcons
extends RefCounted
## Vector icons for the on-screen buttons, drawn with the canvas so they stay
## sharp at any button size. Each takes the centre, a size (the icon's
## half-height in px) and a colour.


static func draw(ci: CanvasItem, icon: String, c: Vector2, s: float, col: Color) -> void:
	match icon:
		"interact":
			_hand(ci, c, s, col)
		"sprint":
			_runner(ci, c, s, col)
		"crouch":
			_croucher(ci, c, s, col)
		"flashlight":
			_torch(ci, c, s, col)
		"inventory":
			_bag(ci, c, s, col)
		"pause":
			_pause(ci, c, s, col)
		"ping":
			_pin(ci, c, s, col)


## An open hand reaching to grab: palm, four fingers, thumb.
static func _hand(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := s * 0.17
	var palm := Rect2(c + Vector2(-s * 0.48, -s * 0.05), Vector2(s * 0.96, s * 0.85))
	ci.draw_rect(palm, col)
	ci.draw_circle(c + Vector2(0, s * 0.78), s * 0.48, col)
	var tops := [-0.85, -1.0, -0.95, -0.75]
	for i in 4:
		var x := -s * 0.36 + i * s * 0.24
		var top := Vector2(c.x + x, c.y + s * tops[i])
		ci.draw_line(Vector2(c.x + x, c.y + s * 0.1), top, col, w * 1.15)
		ci.draw_circle(top, w * 0.58, col)
	var thumb_base := c + Vector2(-s * 0.45, s * 0.35)
	var thumb_tip := c + Vector2(-s * 0.95, -s * 0.1)
	ci.draw_line(thumb_base, thumb_tip, col, w * 1.2)
	ci.draw_circle(thumb_tip, w * 0.6, col)


## A figure mid-stride: leaning forward, arms and legs swinging.
static func _runner(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := s * 0.2
	var head := c + Vector2(s * 0.35, -s * 0.78)
	var neck := c + Vector2(s * 0.15, -s * 0.45)
	var hip := c + Vector2(-s * 0.15, s * 0.2)
	ci.draw_circle(head, s * 0.2, col)
	ci.draw_line(neck, hip, col, w)
	# Arms: one forward and up, one back.
	ci.draw_polyline(
		PackedVector2Array(
			[neck + Vector2(0, s * 0.08), c + Vector2(s * 0.45, -s * 0.15), c + Vector2(s * 0.7, -s * 0.45)]
		),
		col,
		w * 0.8
	)
	ci.draw_polyline(
		PackedVector2Array(
			[neck + Vector2(0, s * 0.08), c + Vector2(-s * 0.3, -s * 0.2), c + Vector2(-s * 0.55, s * 0.05)]
		),
		col,
		w * 0.8
	)
	# Legs: front knee up, back leg pushing off.
	ci.draw_polyline(
		PackedVector2Array([hip, c + Vector2(s * 0.35, s * 0.35), c + Vector2(s * 0.25, s * 0.85)]), col, w
	)
	ci.draw_polyline(
		PackedVector2Array([hip, c + Vector2(-s * 0.35, s * 0.55), c + Vector2(-s * 0.8, s * 0.6)]), col, w
	)
	# Speed lines.
	for i in 2:
		var y := c.y - s * 0.35 + i * s * 0.3
		ci.draw_line(Vector2(c.x - s * 1.0, y), Vector2(c.x - s * 0.7, y), Color(col, col.a * 0.7), w * 0.45)


## A crouched figure with a down arrow.
static func _croucher(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := s * 0.2
	var head := c + Vector2(s * 0.05, -s * 0.35)
	var hip := c + Vector2(-s * 0.35, s * 0.35)
	ci.draw_circle(head, s * 0.2, col)
	ci.draw_line(head + Vector2(-s * 0.08, s * 0.18), hip, col, w)
	ci.draw_polyline(PackedVector2Array([hip, c + Vector2(s * 0.2, s * 0.35), c + Vector2(s * 0.05, s * 0.8)]), col, w)
	ci.draw_polyline(
		PackedVector2Array(
			[head + Vector2(-s * 0.12, s * 0.3), c + Vector2(s * 0.25, s * 0.15), c + Vector2(s * 0.45, s * 0.35)]
		),
		col,
		w * 0.8
	)
	ci.draw_line(Vector2(c.x - s * 0.35, c.y + s * 0.85), Vector2(c.x + s * 0.4, c.y + s * 0.85), col, w * 0.6)
	# Down chevron on the right.
	var a := c + Vector2(s * 0.75, -s * 0.75)
	ci.draw_line(a, a + Vector2(0, s * 0.6), col, w * 0.6)
	ci.draw_polyline(
		PackedVector2Array([a + Vector2(-s * 0.2, s * 0.4), a + Vector2(0, s * 0.62), a + Vector2(s * 0.2, s * 0.4)]),
		col,
		w * 0.6
	)


## A flashlight throwing a beam.
static func _torch(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var body := PackedVector2Array(
		[
			c + Vector2(-s * 0.95, s * 0.12),
			c + Vector2(-s * 0.15, s * 0.12),
			c + Vector2(-s * 0.15, -s * 0.38),
			c + Vector2(-s * 0.95, -s * 0.38)
		]
	)
	ci.draw_colored_polygon(body, col)
	var head := PackedVector2Array(
		[
			c + Vector2(-s * 0.15, s * 0.28),
			c + Vector2(s * 0.12, s * 0.42),
			c + Vector2(s * 0.12, -s * 0.68),
			c + Vector2(-s * 0.15, -s * 0.54)
		]
	)
	ci.draw_colored_polygon(head, col)
	var beam := PackedVector2Array(
		[
			c + Vector2(s * 0.2, -s * 0.6),
			c + Vector2(s * 1.0, -s * 1.0),
			c + Vector2(s * 1.0, s * 0.75),
			c + Vector2(s * 0.2, s * 0.35)
		]
	)
	ci.draw_colored_polygon(beam, Color(col, col.a * 0.35))
	ci.draw_line(
		c + Vector2(-s * 0.7, -s * 0.13), c + Vector2(-s * 0.45, -s * 0.13), Color(0, 0, 0, col.a * 0.6), s * 0.12
	)


## A backpack: body, flap, pocket and carry loop.
static func _bag(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var w := s * 0.16
	var body := Rect2(c + Vector2(-s * 0.7, -s * 0.5), Vector2(s * 1.4, s * 1.35))
	ci.draw_rect(body, col)
	ci.draw_circle(c + Vector2(-s * 0.35, -s * 0.5), s * 0.35, col)
	ci.draw_circle(c + Vector2(s * 0.35, -s * 0.5), s * 0.35, col)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.35, -s * 0.85), Vector2(s * 0.7, s * 0.4)), col)
	ci.draw_arc(c + Vector2(0, -s * 0.9), s * 0.25, PI, TAU, 12, col, w)
	var dark := Color(0, 0, 0, col.a * 0.55)
	ci.draw_line(c + Vector2(-s * 0.7, -s * 0.05), c + Vector2(s * 0.7, -s * 0.05), dark, w * 0.7)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.35, s * 0.25), Vector2(s * 0.7, s * 0.4)), dark, false, w * 0.6)


static func _pause(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_rect(Rect2(c + Vector2(-s * 0.55, -s * 0.7), Vector2(s * 0.38, s * 1.4)), col)
	ci.draw_rect(Rect2(c + Vector2(s * 0.17, -s * 0.7), Vector2(s * 0.38, s * 1.4)), col)


## A map pin marking a spot.
static func _pin(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	var top := c + Vector2(0, -s * 0.3)
	ci.draw_circle(top, s * 0.55, col)
	ci.draw_colored_polygon(
		PackedVector2Array(
			[top + Vector2(-s * 0.48, s * 0.25), top + Vector2(s * 0.48, s * 0.25), c + Vector2(0, s * 0.95)]
		),
		col
	)
	ci.draw_circle(top, s * 0.2, Color(0, 0, 0, col.a * 0.6))
