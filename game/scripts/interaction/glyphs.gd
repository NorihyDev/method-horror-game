class_name Glyphs
extends RefCounted
## Symbol meshes used by the basement code puzzle: circle, triangle, square,
## cross. Shapes (not colors) carry the meaning so they stay readable for
## color-blind players. Indices: 0 circle, 1 triangle, 2 square, 3 cross.

const NAMES: PackedStringArray = ["SYMBOL_CIRCLE", "SYMBOL_TRIANGLE", "SYMBOL_SQUARE", "SYMBOL_CROSS"]


## Builds a flat glyph facing +Z of roughly `size` meters.
static func build(symbol: int, size: float, mat: Material) -> Node3D:
	var root := Node3D.new()
	var w := size * 0.12
	match symbol:
		0:
			var t := TorusMesh.new()
			t.inner_radius = size * 0.38
			t.outer_radius = size * 0.5
			t.rings = 24
			t.ring_segments = 4
			_add(root, t, mat, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3.ZERO))
		1:
			var pts := [Vector2(0, size * 0.5), Vector2(-size * 0.48, -size * 0.38), Vector2(size * 0.48, -size * 0.38)]
			for i in 3:
				_bar(root, pts[i], pts[(i + 1) % 3], w, mat)
		2:
			var h := size * 0.42
			_bar(root, Vector2(-h, -h), Vector2(h, -h), w, mat)
			_bar(root, Vector2(h, -h), Vector2(h, h), w, mat)
			_bar(root, Vector2(h, h), Vector2(-h, h), w, mat)
			_bar(root, Vector2(-h, h), Vector2(-h, -h), w, mat)
		_:
			var h := size * 0.45
			_bar(root, Vector2(-h, -h), Vector2(h, h), w * 1.2, mat)
			_bar(root, Vector2(-h, h), Vector2(h, -h), w * 1.2, mat)
	return root


static func _bar(root: Node3D, a: Vector2, b: Vector2, width: float, mat: Material) -> void:
	var m := BoxMesh.new()
	var length := a.distance_to(b) + width
	m.size = Vector3(length, width, width * 0.4)
	var mid := (a + b) * 0.5
	var angle := atan2(b.y - a.y, b.x - a.x)
	_add(root, m, mat, Transform3D(Basis(Vector3.BACK, angle), Vector3(mid.x, mid.y, 0)))


static func _add(root: Node3D, mesh: Mesh, mat: Material, xform: Transform3D) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xform
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


## 2D drawing for UI (keypad panel, notes).
static func draw_2d(
	canvas: CanvasItem, symbol: int, center: Vector2, size: float, color: Color, width: float = 3.0
) -> void:
	var h := size * 0.45
	match symbol:
		0:
			canvas.draw_arc(center, h, 0, TAU, 32, color, width, true)
		1:
			var pts := PackedVector2Array(
				[
					center + Vector2(0, -h),
					center + Vector2(h, h * 0.8),
					center + Vector2(-h, h * 0.8),
					center + Vector2(0, -h)
				]
			)
			canvas.draw_polyline(pts, color, width, true)
		2:
			canvas.draw_rect(Rect2(center - Vector2(h, h) * 0.9, Vector2(h, h) * 1.8), color, false, width)
		_:
			canvas.draw_line(center + Vector2(-h, -h), center + Vector2(h, h), color, width, true)
			canvas.draw_line(center + Vector2(-h, h), center + Vector2(h, -h), color, width, true)
