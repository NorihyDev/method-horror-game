class_name PropFactory
extends RefCounted
## Procedural furniture and set dressing. Everything is merged into the
## builder's static batches; collision is added only where it matters for
## movement. `rot` is a yaw in degrees.

static var rng := RandomNumberGenerator.new()


static func _basis(rot: float) -> Basis:
	return Basis(Vector3.UP, deg_to_rad(rot))


## Adds a box at a local offset from `pos` rotated by `rot`.
static func part(b: GeoBuilder, pos: Vector3, rot: float, offset: Vector3, size: Vector3, mat: String,
		collide: bool = false, shadow: bool = true) -> void:
	var basis := _basis(rot)
	b.box(pos + basis * offset, size, mat, false, GeoBuilder.FACE_ALL, basis, shadow)
	if collide:
		b.prop_collider(pos + basis * offset, size, basis)


static func solid(b: GeoBuilder, pos: Vector3, rot: float, offset: Vector3, size: Vector3) -> void:
	var basis := _basis(rot)
	b.prop_collider(pos + basis * offset, size, basis)


static func cylinder(b: GeoBuilder, mat: String, xform: Transform3D, radius: float, height: float,
		segments: int = 12) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	cm.radial_segments = segments
	cm.rings = 1
	var st := b._batch(mat, true)
	st.append_from(cm, 0, xform)


# --- Furniture --------------------------------------------------------------------

static func table(b: GeoBuilder, pos: Vector3, rot: float, w: float = 1.6, d: float = 0.9, mat: String = "dark_wood") -> void:
	part(b, pos, rot, Vector3(0, 0.74, 0), Vector3(w, 0.05, d), mat)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			part(b, pos, rot, Vector3(sx * (w * 0.5 - 0.08), 0.36, sz * (d * 0.5 - 0.08)), Vector3(0.07, 0.72, 0.07), mat)
	solid(b, pos, rot, Vector3(0, 0.4, 0), Vector3(w, 0.8, d))


static func chair(b: GeoBuilder, pos: Vector3, rot: float, tipped: bool = false, mat: String = "dark_wood") -> void:
	if tipped:
		var basis := _basis(rot) * Basis(Vector3.RIGHT, deg_to_rad(-88))
		b.box(pos + Vector3(0, 0.24, 0), Vector3(0.45, 0.05, 0.45), mat, false, GeoBuilder.FACE_ALL, basis)
		b.box(pos + _basis(rot) * Vector3(0, 0.03, -0.4), Vector3(0.45, 0.05, 0.5), mat, false, GeoBuilder.FACE_ALL, _basis(rot))
		return
	part(b, pos, rot, Vector3(0, 0.45, 0), Vector3(0.45, 0.05, 0.45), mat)
	part(b, pos, rot, Vector3(0, 0.75, -0.2), Vector3(0.45, 0.55, 0.05), mat)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			part(b, pos, rot, Vector3(sx * 0.19, 0.22, sz * 0.19), Vector3(0.05, 0.44, 0.05), mat)
	solid(b, pos, rot, Vector3(0, 0.45, 0), Vector3(0.45, 0.9, 0.45))


static func sofa(b: GeoBuilder, pos: Vector3, rot: float, w: float = 2.0, mat: String = "fabric") -> void:
	part(b, pos, rot, Vector3(0, 0.22, 0), Vector3(w, 0.44, 0.85), mat, true)
	part(b, pos, rot, Vector3(0, 0.62, -0.34), Vector3(w, 0.55, 0.18), mat, true)
	part(b, pos, rot, Vector3(-w * 0.5 + 0.1, 0.55, 0.0), Vector3(0.2, 0.3, 0.85), mat)
	part(b, pos, rot, Vector3(w * 0.5 - 0.1, 0.55, 0.0), Vector3(0.2, 0.3, 0.85), mat)
	part(b, pos, rot, Vector3(-w * 0.22, 0.5, 0.05), Vector3(w * 0.42, 0.12, 0.62), mat)
	part(b, pos, rot, Vector3(w * 0.22, 0.48, 0.07), Vector3(w * 0.42, 0.1, 0.6), mat)


static func armchair(b: GeoBuilder, pos: Vector3, rot: float, mat: String = "fabric") -> void:
	sofa(b, pos, rot, 1.0, mat)


static func bed(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	part(b, pos, rot, Vector3(0, 0.2, 0), Vector3(1.4, 0.3, 2.0), "dark_wood", true)
	part(b, pos, rot, Vector3(0, 0.45, 0.05), Vector3(1.3, 0.2, 1.85), "fabric_blue")
	part(b, pos, rot, Vector3(0, 0.6, -0.75), Vector3(0.9, 0.12, 0.35), "fabric")
	part(b, pos, rot, Vector3(0, 0.7, -1.0), Vector3(1.45, 1.1, 0.08), "dark_wood", true)


static func shelf(b: GeoBuilder, pos: Vector3, rot: float, w: float = 1.2, h: float = 1.9, d: float = 0.38,
		mat: String = "dark_wood", clutter: bool = true) -> void:
	part(b, pos, rot, Vector3(-w * 0.5 + 0.02, h * 0.5, 0), Vector3(0.04, h, d), mat)
	part(b, pos, rot, Vector3(w * 0.5 - 0.02, h * 0.5, 0), Vector3(0.04, h, d), mat)
	part(b, pos, rot, Vector3(0, h * 0.5, -d * 0.5 + 0.01), Vector3(w, h, 0.02), mat)
	var levels := 4
	for i in levels + 1:
		var y := 0.06 + (h - 0.08) * float(i) / levels
		part(b, pos, rot, Vector3(0, y, 0), Vector3(w - 0.04, 0.03, d), mat)
		if clutter and i < levels:
			_clutter(b, pos, rot, y + 0.015, w - 0.1, d * 0.8, (h - 0.08) / levels - 0.06)
	solid(b, pos, rot, Vector3(0, h * 0.5, 0), Vector3(w, h, d))


static func _clutter(b: GeoBuilder, pos: Vector3, rot: float, y: float, w: float, d: float, max_h: float) -> void:
	var x := -w * 0.5
	var mats := ["dark_wood", "fabric", "fabric_blue", "painted_wood", "metal_dark"]
	while x < w * 0.5 - 0.06:
		if rng.randf() < 0.25:
			x += rng.randf_range(0.08, 0.3)
			continue
		var bw := rng.randf_range(0.03, 0.08)
		var bh := rng.randf_range(0.6, 0.95) * max_h
		var bd := rng.randf_range(0.6, 0.95) * d
		if rng.randf() < 0.18:
			# Box or jar instead of a book.
			bw = rng.randf_range(0.12, 0.25)
			bh = rng.randf_range(0.1, 0.6) * max_h
		var lean := Basis.IDENTITY
		if rng.randf() < 0.12:
			lean = Basis(Vector3.BACK, deg_to_rad(rng.randf_range(-20, 20)))
		var basis := _basis(rot) * lean
		b.box(pos + _basis(rot) * Vector3(x + bw * 0.5, y + bh * 0.5, 0), Vector3(bw, bh, bd),
			mats[rng.randi_range(0, mats.size() - 1)], false, GeoBuilder.FACE_ALL, basis, false)
		x += bw + rng.randf_range(0.0, 0.015)


static func cabinet(b: GeoBuilder, pos: Vector3, rot: float, w: float = 1.0, h: float = 0.9, d: float = 0.5,
		mat: String = "dark_wood") -> void:
	part(b, pos, rot, Vector3(0, h * 0.5, 0), Vector3(w, h, d), mat, true)
	part(b, pos, rot, Vector3(0, h + 0.015, 0.01), Vector3(w + 0.04, 0.03, d + 0.04), mat)
	part(b, pos, rot, Vector3(-w * 0.25, h * 0.55, d * 0.5 + 0.01), Vector3(w * 0.44, h * 0.8, 0.02), mat)
	part(b, pos, rot, Vector3(w * 0.25, h * 0.55, d * 0.5 + 0.01), Vector3(w * 0.44, h * 0.8, 0.02), mat)


static func counter(b: GeoBuilder, pos: Vector3, rot: float, length: float, with_sink: bool = false) -> void:
	part(b, pos, rot, Vector3(0, 0.44, 0), Vector3(length, 0.88, 0.6), "painted_wood", true)
	part(b, pos, rot, Vector3(0, 0.9, 0.02), Vector3(length + 0.02, 0.04, 0.64), "tile")
	var doors := int(length / 0.6)
	for i in doors:
		var x := -length * 0.5 + 0.3 + i * (length / doors)
		part(b, pos, rot, Vector3(x, 0.45, 0.305), Vector3(length / doors - 0.06, 0.7, 0.02), "painted_wood")
	if with_sink:
		part(b, pos, rot, Vector3(0, 0.915, 0.0), Vector3(0.6, 0.02, 0.42), "metal_dark")
		part(b, pos, rot, Vector3(0, 1.05, -0.24), Vector3(0.04, 0.3, 0.04), "metal")
		part(b, pos, rot, Vector3(0, 1.18, -0.16), Vector3(0.04, 0.04, 0.18), "metal")


static func fridge(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	part(b, pos, rot, Vector3(0, 0.9, 0), Vector3(0.75, 1.8, 0.7), "painted_wood", true)
	part(b, pos, rot, Vector3(0.3, 1.2, 0.36), Vector3(0.04, 0.4, 0.04), "metal")
	part(b, pos, rot, Vector3(0, 1.32, 0.355), Vector3(0.73, 0.01, 0.01), "metal_dark")


static func stove(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	part(b, pos, rot, Vector3(0, 0.45, 0), Vector3(0.75, 0.9, 0.65), "metal_dark", true)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			part(b, pos, rot, Vector3(sx * 0.18, 0.915, sz * 0.15), Vector3(0.2, 0.02, 0.2), "metal")
	part(b, pos, rot, Vector3(0, 0.45, 0.33), Vector3(0.6, 0.4, 0.02), "metal")


static func wardrobe(b: GeoBuilder, pos: Vector3, rot: float, mat: String = "dark_wood") -> void:
	part(b, pos, rot, Vector3(0, 1.0, 0), Vector3(1.1, 2.0, 0.6), mat, true)
	part(b, pos, rot, Vector3(0, 2.05, 0), Vector3(1.2, 0.1, 0.66), mat)


static func crate(b: GeoBuilder, pos: Vector3, size: Vector3, rot: float = 0.0, mat: String = "dark_wood") -> void:
	part(b, pos, rot, Vector3(0, size.y * 0.5, 0), size, mat, true)
	part(b, pos, rot, Vector3(0, size.y * 0.5, size.z * 0.5 + 0.005), Vector3(size.x * 0.9, 0.06, 0.01), mat)


static func rug(b: GeoBuilder, pos: Vector3, size: Vector2, rot: float = 0.0) -> void:
	part(b, pos, rot, Vector3(0, 0.006, 0), Vector3(size.x, 0.012, size.y), "carpet", false, false)


static func fireplace(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	part(b, pos, rot, Vector3(-0.75, 0.6, 0), Vector3(0.4, 1.2, 0.5), "blocks", true)
	part(b, pos, rot, Vector3(0.75, 0.6, 0), Vector3(0.4, 1.2, 0.5), "blocks", true)
	part(b, pos, rot, Vector3(0, 1.05, 0), Vector3(1.1, 0.3, 0.5), "blocks")
	part(b, pos, rot, Vector3(0, 0.45, -0.15), Vector3(1.1, 0.9, 0.2), "metal_dark")
	part(b, pos, rot, Vector3(0, 1.24, 0.06), Vector3(2.1, 0.08, 0.65), "dark_wood")
	part(b, pos, rot, Vector3(0, 0.03, 0.4), Vector3(1.6, 0.06, 0.4), "blocks")
	solid(b, pos, rot, Vector3(0, 0.6, 0), Vector3(1.9, 1.2, 0.5))


static func clock(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	part(b, pos, rot, Vector3(0, 0.95, 0), Vector3(0.5, 1.9, 0.32), "dark_wood", true)
	part(b, pos, rot, Vector3(0, 1.6, 0.165), Vector3(0.32, 0.32, 0.01), "painted_wood")
	part(b, pos, rot, Vector3(0, 0.9, 0.165), Vector3(0.3, 0.7, 0.01), "metal_dark")


static func picture(b: GeoBuilder, pos: Vector3, rot: float, w: float, h: float, tilt: float = 0.0) -> void:
	var basis := _basis(rot) * Basis(Vector3.BACK, deg_to_rad(tilt))
	b.box(pos, Vector3(w, h, 0.04), "dark_wood", false, GeoBuilder.FACE_ALL, basis, false)
	b.box(pos + _basis(rot) * Vector3(0, 0, 0.022), Vector3(w * 0.82, h * 0.82, 0.005), "fabric",
		false, GeoBuilder.FACE_ALL, basis, false)


## Planks nailed across a window opening. `axis_x` = wall runs along X.
static func boarded_window(b: GeoBuilder, center: Vector3, width: float, height: float, axis_x: bool) -> void:
	var rot := 0.0 if axis_x else 90.0
	var planks := 4
	for i in planks:
		var y := -height * 0.5 + (i + 0.5) * height / planks
		var tilt := rng.randf_range(-8, 8)
		var basis := _basis(rot) * Basis(Vector3.BACK, deg_to_rad(tilt))
		b.box(center + Vector3(0, y, 0), Vector3(width + 0.3, 0.16, 0.04), "dark_wood", false, GeoBuilder.FACE_ALL, basis)
	# Dark backing so the void outside never reads as a hole.
	var back := center + _basis(rot) * Vector3(0, 0, -0.12)
	b.box(back, Vector3(width, height, 0.02) if axis_x else Vector3(0.02, height, width), "exterior", true)


static func pipe_run(b: GeoBuilder, from: Vector3, to: Vector3, radius: float = 0.06, mat: String = "metal_dark") -> void:
	var dir := to - from
	var length := dir.length()
	if length < 0.01:
		return
	var up := dir.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up).normalized()
	var basis := Basis(side, up, fwd)
	cylinder(b, mat, Transform3D(basis, (from + to) * 0.5), radius, length, 10)


static func boiler(b: GeoBuilder, pos: Vector3) -> void:
	cylinder(b, "metal_green", Transform3D(Basis.IDENTITY, pos + Vector3(0, 1.0, 0)), 0.55, 2.0, 18)
	cylinder(b, "metal_dark", Transform3D(Basis.IDENTITY, pos + Vector3(0, 2.05, 0)), 0.3, 0.1, 14)
	b.prop_collider(pos + Vector3(0, 1.0, 0), Vector3(1.1, 2.0, 1.1))
	pipe_run(b, pos + Vector3(0, 2.1, 0), pos + Vector3(0, 2.75, 0), 0.08)


static func workbench(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	part(b, pos, rot, Vector3(0, 0.88, 0), Vector3(2.0, 0.08, 0.8), "dark_wood")
	for sx in [-1, 1]:
		part(b, pos, rot, Vector3(sx * 0.92, 0.42, 0), Vector3(0.08, 0.84, 0.72), "dark_wood")
	part(b, pos, rot, Vector3(0, 0.2, 0), Vector3(1.8, 0.04, 0.7), "dark_wood")
	part(b, pos, rot, Vector3(0, 1.55, -0.39), Vector3(2.0, 1.1, 0.03), "painted_wood")
	for i in 7:
		var x := -0.8 + i * 0.27
		var h := rng.randf_range(0.18, 0.4)
		part(b, pos, rot, Vector3(x, 1.5 + rng.randf_range(-0.2, 0.2), -0.36), Vector3(0.05, h, 0.03), "metal")
	solid(b, pos, rot, Vector3(0, 0.46, 0), Vector3(2.0, 0.92, 0.8))


## A car under a dust sheet: reads as a looming silhouette in the garage.
static func covered_car(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	part(b, pos, rot, Vector3(0, 0.55, 0), Vector3(1.8, 0.75, 4.3), "fabric", true)
	part(b, pos, rot, Vector3(0, 1.1, -0.2), Vector3(1.5, 0.5, 2.2), "fabric", true)
	var basis := _basis(rot) * Basis(Vector3.RIGHT, deg_to_rad(28))
	b.box(pos + _basis(rot) * Vector3(0, 1.0, 1.15), Vector3(1.55, 0.06, 0.8), "fabric", false, GeoBuilder.FACE_ALL, basis)
	basis = _basis(rot) * Basis(Vector3.RIGHT, deg_to_rad(-35))
	b.box(pos + _basis(rot) * Vector3(0, 1.0, -1.45), Vector3(1.55, 0.06, 0.6), "fabric", false, GeoBuilder.FACE_ALL, basis)
	for sx in [-1, 1]:
		var skirt := _basis(rot) * Basis(Vector3.BACK, deg_to_rad(sx * 8))
		b.box(pos + _basis(rot) * Vector3(sx * 0.92, 0.35, 0), Vector3(0.05, 0.7, 4.2), "fabric", false, GeoBuilder.FACE_ALL, skirt)


static func washer(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	part(b, pos, rot, Vector3(0, 0.45, 0), Vector3(0.65, 0.9, 0.65), "painted_wood", true)
	cylinder(b, "metal_dark", Transform3D(_basis(rot) * Basis(Vector3.RIGHT, PI / 2), pos + _basis(rot) * Vector3(0, 0.45, 0.33)), 0.2, 0.02, 16)


static func radiator(b: GeoBuilder, pos: Vector3, rot: float, w: float = 0.9) -> void:
	var fins := int(w / 0.08)
	for i in fins:
		part(b, pos, rot, Vector3(-w * 0.5 + i * 0.08 + 0.04, 0.4, 0), Vector3(0.05, 0.6, 0.12), "metal")
	part(b, pos, rot, Vector3(0, 0.12, 0), Vector3(w, 0.04, 0.06), "metal")


static func debris(b: GeoBuilder, center: Vector3, radius: float, count: int) -> void:
	for i in count:
		var p := center + Vector3(rng.randf_range(-radius, radius), 0.0, rng.randf_range(-radius, radius))
		var kind := rng.randi_range(0, 3)
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		match kind:
			0:
				b.box(p + Vector3(0, 0.003, 0), Vector3(0.21, 0.004, 0.29), "plaster", false, GeoBuilder.FACE_ALL, basis, false)
			1:
				b.box(p + Vector3(0, 0.02, 0), Vector3(0.15, 0.04, 0.22), "fabric", false, GeoBuilder.FACE_ALL, basis, false)
			2:
				b.box(p + Vector3(0, 0.015, 0), Vector3(rng.randf_range(0.3, 0.9), 0.03, 0.08), "dark_wood", false, GeoBuilder.FACE_ALL, basis, false)
			_:
				b.box(p + Vector3(0, 0.03, 0), Vector3(0.06, 0.06, 0.06), "plaster", false, GeoBuilder.FACE_ALL, basis, false)


static func lamp_fixture(b: GeoBuilder, ceiling_point: Vector3) -> void:
	b.box(ceiling_point + Vector3(0, -0.2, 0), Vector3(0.015, 0.4, 0.015), "metal_dark", false)
	cylinder(b, "metal_dark", Transform3D(Basis.IDENTITY, ceiling_point + Vector3(0, -0.45, 0)), 0.16, 0.12, 12)
