class_name GeoBuilder
extends RefCounted
## Builds static level geometry from boxes. Visual faces are merged into one
## mesh per (room, material) to keep draw calls low; collision boxes go into a
## single StaticBody3D on the "world" layer so the navigation mesh can be
## baked from colliders.

const LAYER_WORLD := 1
## Furniture: blocks movement, navigation and enemy sight, but not
## interaction rays (so items on shelves and tables stay reachable).
const LAYER_PROP := 1 << 6
const FACE_ALL := 63
const FACE_NX := 1
const FACE_PX := 2
const FACE_NY := 4
const FACE_PY := 8
const FACE_NZ := 16
const FACE_PZ := 32

var root: Node3D
var body: StaticBody3D
var prop_body: StaticBody3D
var room := "default"
## Mesh instances created by commit(), keyed by room.
var room_meshes: Dictionary = {}
var _batches: Dictionary = {}
var _shape_count := 0


func _init(p_root: Node3D) -> void:
	root = p_root
	body = StaticBody3D.new()
	body.name = "WorldCollision"
	body.collision_layer = LAYER_WORLD
	body.collision_mask = 0
	root.add_child(body)
	prop_body = StaticBody3D.new()
	prop_body.name = "PropCollision"
	prop_body.collision_layer = LAYER_PROP
	prop_body.collision_mask = 0
	root.add_child(prop_body)


# --- Primitives ----------------------------------------------------------------

## Axis-aligned (optionally rotated) box. `faces` limits emitted faces.
func box(center: Vector3, size: Vector3, mat: String, collide: bool = true,
		faces: int = FACE_ALL, basis: Basis = Basis.IDENTITY, shadow: bool = true) -> void:
	if size.x <= 0.001 or size.y <= 0.001 or size.z <= 0.001:
		return
	if faces == 0:
		if collide:
			collider(center, size, basis)
		return
	var st := _batch(mat, shadow)
	var e := size * 0.5
	var corners := [
		Vector3(-e.x, -e.y, -e.z), Vector3(e.x, -e.y, -e.z), Vector3(e.x, e.y, -e.z), Vector3(-e.x, e.y, -e.z),
		Vector3(-e.x, -e.y, e.z), Vector3(e.x, -e.y, e.z), Vector3(e.x, e.y, e.z), Vector3(-e.x, e.y, e.z),
	]
	var w: Array[Vector3] = []
	for c in corners:
		w.append(center + basis * c)
	# Each face: 4 corner indices counter-clockwise when viewed from outside.
	if faces & FACE_NZ:
		_quad(st, w[1], w[0], w[3], w[2], basis * Vector3.FORWARD)
	if faces & FACE_PZ:
		_quad(st, w[4], w[5], w[6], w[7], basis * Vector3.BACK)
	if faces & FACE_NX:
		_quad(st, w[0], w[4], w[7], w[3], basis * Vector3.LEFT)
	if faces & FACE_PX:
		_quad(st, w[5], w[1], w[2], w[6], basis * Vector3.RIGHT)
	if faces & FACE_NY:
		_quad(st, w[0], w[1], w[5], w[4], basis * Vector3.DOWN)
	if faces & FACE_PY:
		_quad(st, w[3], w[7], w[6], w[2], basis * Vector3.UP)
	if collide:
		collider(center, size, basis)


func collider(center: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> CollisionShape3D:
	return _shape(body, center, size, basis)


func prop_collider(center: Vector3, size: Vector3, basis: Basis = Basis.IDENTITY) -> CollisionShape3D:
	return _shape(prop_body, center, size, basis)


func _shape(owner: StaticBody3D, center: Vector3, size: Vector3, basis: Basis) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = Transform3D(basis, center)
	cs.name = "C%d" % _shape_count
	_shape_count += 1
	owner.add_child(cs)
	return cs


## Floor slab whose top surface is at `top_y`.
func floor_rect(x0: float, z0: float, x1: float, z1: float, top_y: float, mat: String, thickness: float = 0.3) -> void:
	box(Vector3((x0 + x1) * 0.5, top_y - thickness * 0.5, (z0 + z1) * 0.5),
		Vector3(x1 - x0, thickness, z1 - z0), mat, true, FACE_PY)


## Ceiling slab whose bottom surface is at `bottom_y`. Visual only from below.
func ceiling_rect(x0: float, z0: float, x1: float, z1: float, bottom_y: float, mat: String, thickness: float = 0.2) -> void:
	box(Vector3((x0 + x1) * 0.5, bottom_y + thickness * 0.5, (z0 + z1) * 0.5),
		Vector3(x1 - x0, thickness, z1 - z0), mat, true, FACE_NY, Basis.IDENTITY, false)


## Wall running along X at depth `z`, from x0 to x1. `mat_n` faces -Z, `mat_p` faces +Z.
## openings: Array of {"from": x, "to": x, "bottom": y offset, "top": y offset}
func wall_x(z: float, x0: float, x1: float, y0: float, height: float, mat_n: String, mat_p: String,
		openings: Array = [], thickness: float = 0.16) -> void:
	for seg in _segments(x0, x1, height, openings):
		var a: float = seg[0]
		var b: float = seg[1]
		var lo: float = seg[2]
		var hi: float = seg[3]
		var cx := (a + b) * 0.5
		var cy := y0 + (lo + hi) * 0.5
		var size := Vector3(b - a, hi - lo, thickness * 0.5)
		box(Vector3(cx, cy, z - thickness * 0.25), size, mat_n, false, FACE_ALL & ~FACE_PZ)
		box(Vector3(cx, cy, z + thickness * 0.25), size, mat_p, false, FACE_ALL & ~FACE_NZ)
		collider(Vector3(cx, cy, z), Vector3(b - a, hi - lo, thickness))


## Wall running along Z at `x`, from z0 to z1. `mat_n` faces -X, `mat_p` faces +X.
func wall_z(x: float, z0: float, z1: float, y0: float, height: float, mat_n: String, mat_p: String,
		openings: Array = [], thickness: float = 0.16) -> void:
	for seg in _segments(z0, z1, height, openings):
		var a: float = seg[0]
		var b: float = seg[1]
		var lo: float = seg[2]
		var hi: float = seg[3]
		var cz := (a + b) * 0.5
		var cy := y0 + (lo + hi) * 0.5
		var size := Vector3(thickness * 0.5, hi - lo, b - a)
		box(Vector3(x - thickness * 0.25, cy, cz), size, mat_n, false, FACE_ALL & ~FACE_PX)
		box(Vector3(x + thickness * 0.25, cy, cz), size, mat_p, false, FACE_ALL & ~FACE_NX)
		collider(Vector3(x, cy, cz), Vector3(thickness, hi - lo, b - a))


## Straight staircase along +Z (descending when y1 < y0). Visual solid steps
## plus one smooth ramp collider for stable movement and navigation.
func stairs_z(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, steps: int,
		mat: String, base_y: float) -> void:
	var run := (z1 - z0) / steps
	var rise := (y1 - y0) / steps
	for i in steps:
		var top := y0 + rise * (i + 1) if rise > 0.0 else y0 + rise * i
		var za := z0 + run * i
		box(Vector3((x0 + x1) * 0.5, (top + base_y) * 0.5, za + run * 0.5),
			Vector3(x1 - x0, top - base_y, run), mat, false)
	var length := sqrt(pow(z1 - z0, 2) + pow(y1 - y0, 2))
	var angle := atan2(y1 - y0, z1 - z0)
	var ramp_basis := Basis(Vector3.RIGHT, -angle)
	var mid := Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5 - 0.1, (z0 + z1) * 0.5)
	collider(mid, Vector3(x1 - x0, 0.2, length + 0.1), ramp_basis)


# --- Commit --------------------------------------------------------------------

func commit() -> void:
	for key in _batches:
		var batch: Dictionary = _batches[key]
		var st: SurfaceTool = batch["st"]
		st.generate_tangents()
		var mesh := st.commit()
		if mesh.get_surface_count() == 0:
			continue
		mesh.surface_set_material(0, MaterialLib.surface(batch["mat"]))
		var mi := MeshInstance3D.new()
		mi.name = str(key).replace("|", "_")
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if batch["shadow"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		var r: String = batch["room"]
		if not room_meshes.has(r):
			room_meshes[r] = []
		room_meshes[r].append(mi)
	_batches.clear()


# --- Internals -----------------------------------------------------------------

func _batch(mat: String, shadow: bool) -> SurfaceTool:
	var key := "%s|%s|%s" % [room, mat, "s" if shadow else "n"]
	if not _batches.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[key] = {"st": st, "mat": mat, "room": room, "shadow": shadow}
	return _batches[key]["st"]


func _quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, normal: Vector3) -> void:
	var n := normal.normalized()
	var pts := [p0, p1, p2, p3]
	var uvs: Array[Vector2] = []
	for p: Vector3 in pts:
		uvs.append(_uv_for(p, n))
	# Godot treats clockwise winding as front-facing.
	var ccw := (p1 - p0).cross(p2 - p0).dot(n) > 0.0
	var order := [0, 2, 1, 0, 3, 2] if ccw else [0, 1, 2, 0, 2, 3]
	for i in order:
		st.set_normal(n)
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])


## World-scaled planar UVs chosen by the dominant normal axis.
static func _uv_for(p: Vector3, n: Vector3) -> Vector2:
	var a := n.abs()
	if a.y >= a.x and a.y >= a.z:
		return Vector2(p.x, p.z)
	if a.x >= a.z:
		return Vector2(p.z * signf(n.x), -p.y)
	return Vector2(-p.x * signf(n.z), -p.y)


## Splits a wall span into solid rectangles around openings.
## Returns Array of [a, b, lo, hi] in wall-local coordinates.
static func _segments(s0: float, s1: float, height: float, openings: Array) -> Array:
	var out := []
	var sorted := openings.duplicate()
	sorted.sort_custom(func(p: Dictionary, q: Dictionary) -> bool: return float(p["from"]) < float(q["from"]))
	var cursor := s0
	for o: Dictionary in sorted:
		var a := clampf(float(o["from"]), s0, s1)
		var b := clampf(float(o["to"]), s0, s1)
		if a > cursor:
			out.append([cursor, a, 0.0, height])
		var bottom := float(o.get("bottom", 0.0))
		var top := minf(float(o.get("top", height)), height)
		if bottom > 0.0:
			out.append([a, b, 0.0, bottom])
		if top < height:
			out.append([a, b, top, height])
		cursor = maxf(cursor, b)
	if cursor < s1:
		out.append([cursor, s1, 0.0, height])
	return out

