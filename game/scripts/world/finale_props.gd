class_name FinaleProps
extends RefCounted
## Procedural set dressing for The Silent School (Map 4) and the METHOD
## Facility (Map 5), built from PropFactory primitives. `rot` is a yaw in
## degrees. Collision only where it matters for movement (prop layer).

const P = preload("res://scripts/world/prop_factory.gd")

## Height of a pupil's desk top (pickups rest at DESK_TOP + 0.01).
const DESK_TOP := 0.72

# --- School ------------------------------------------------------------------------------


## Pupil desk with its chair tucked in on the near side (+Z local).
static func school_desk(b: GeoBuilder, pos: Vector3, rot: float, tipped: bool = false) -> void:
	P.part(b, pos, rot, Vector3(0, DESK_TOP - 0.02, 0), Vector3(0.62, 0.04, 0.46), "painted_wood")
	P.part(b, pos, rot, Vector3(0, DESK_TOP - 0.12, 0), Vector3(0.58, 0.16, 0.42), "metal_green")
	for sx in [-1, 1]:
		P.part(b, pos, rot, Vector3(sx * 0.27, (DESK_TOP - 0.2) * 0.5, 0), Vector3(0.04, DESK_TOP - 0.2, 0.4), "metal")
	P.solid(b, pos, rot, Vector3(0, DESK_TOP * 0.5, 0), Vector3(0.62, DESK_TOP, 0.46))
	var chair := pos + P._basis(rot) * Vector3(0, 0, 0.42)
	P.chair(b, chair, rot + 180.0, tipped, "painted_wood")


## Teacher's desk: a solid pedestal desk (top at 0.78, like PropFactory.table).
static func teacher_desk(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	P.part(b, pos, rot, Vector3(0, 0.76, 0), Vector3(1.5, 0.05, 0.75), "dark_wood")
	P.part(b, pos, rot, Vector3(-0.5, 0.37, 0), Vector3(0.45, 0.74, 0.7), "dark_wood")
	P.part(b, pos, rot, Vector3(0.62, 0.37, 0), Vector3(0.06, 0.74, 0.7), "dark_wood")
	P.part(b, pos, rot, Vector3(0.1, 0.4, -0.33), Vector3(1.0, 0.7, 0.03), "dark_wood")
	P.solid(b, pos, rot, Vector3(0, 0.39, 0), Vector3(1.5, 0.78, 0.75))


## Wall-mounted chalkboard (`pos` on the wall surface, facing +Z local).
static func chalkboard(b: GeoBuilder, pos: Vector3, rot: float, w: float = 3.2) -> void:
	P.part(b, pos, rot, Vector3(0, 1.55, 0.03), Vector3(w, 1.15, 0.03), "chalkboard", false, false)
	P.part(b, pos, rot, Vector3(0, 1.55, 0.02), Vector3(w + 0.12, 1.27, 0.02), "dark_wood", false, false)
	P.part(b, pos, rot, Vector3(0, 0.95, 0.07), Vector3(w, 0.03, 0.08), "dark_wood", false, false)


## Low pigeonhole shelf along a wall (top at 0.92).
static func cubbies(b: GeoBuilder, pos: Vector3, rot: float, w: float = 2.0) -> void:
	P.part(b, pos, rot, Vector3(0, 0.9, 0), Vector3(w, 0.04, 0.38), "painted_wood")
	P.part(b, pos, rot, Vector3(0, 0.45, -0.17), Vector3(w, 0.9, 0.03), "painted_wood")
	P.part(b, pos, rot, Vector3(0, 0.45, 0), Vector3(w, 0.03, 0.36), "painted_wood")
	var cells := maxi(2, int(w / 0.4))
	for i in cells + 1:
		var x := -w * 0.5 + i * (w / cells)
		P.part(b, pos, rot, Vector3(x, 0.45, 0), Vector3(0.03, 0.9, 0.36), "painted_wood")
	P.solid(b, pos, rot, Vector3(0, 0.46, 0), Vector3(w, 0.92, 0.38))


## Upright piano against a wall (keys toward +Z local).
static func piano(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	P.part(b, pos, rot, Vector3(0, 0.62, 0), Vector3(1.5, 1.24, 0.52), "dark_wood")
	P.part(b, pos, rot, Vector3(0, 0.72, 0.36), Vector3(1.3, 0.05, 0.22), "painted_wood")
	P.part(b, pos, rot, Vector3(0, 0.66, 0.4), Vector3(1.4, 0.1, 0.1), "dark_wood")
	P.solid(b, pos, rot, Vector3(0, 0.62, 0.1), Vector3(1.5, 1.24, 0.72))


## A row of corridor coat pegs with a bench underneath (bench top 0.45).
static func coat_bench(b: GeoBuilder, pos: Vector3, rot: float, w: float = 2.4) -> void:
	P.part(b, pos, rot, Vector3(0, 0.43, 0), Vector3(w, 0.05, 0.36), "painted_wood")
	for sx in [-1, 1]:
		P.part(b, pos, rot, Vector3(sx * (w * 0.5 - 0.08), 0.21, 0), Vector3(0.05, 0.42, 0.32), "painted_wood")
	P.part(b, pos, rot, Vector3(0, 1.55, -0.16), Vector3(w, 0.12, 0.03), "painted_wood")
	var pegs := int(w / 0.3)
	for i in pegs:
		P.part(b, pos, rot, Vector3(-w * 0.5 + 0.15 + i * 0.3, 1.5, -0.1), Vector3(0.025, 0.025, 0.1), "metal")
	P.solid(b, pos, rot, Vector3(0, 0.23, 0), Vector3(w, 0.46, 0.36))


# --- Facility ---------------------------------------------------------------------------


## Laboratory bench: steel top at 0.92 over cupboards, against a wall.
static func lab_bench(b: GeoBuilder, pos: Vector3, rot: float, length: float = 2.4) -> void:
	P.part(b, pos, rot, Vector3(0, 0.9, 0), Vector3(length, 0.04, 0.7), "metal")
	P.part(b, pos, rot, Vector3(0, 0.44, -0.02), Vector3(length - 0.04, 0.86, 0.64), "lab_panel")
	P.part(b, pos, rot, Vector3(0, 1.45, -0.33), Vector3(length, 1.0, 0.03), "lab_tile", false, false)
	P.solid(b, pos, rot, Vector3(0, 0.46, 0), Vector3(length, 0.92, 0.7))


## Server rack (2 m tall) with its door facing +Z local.
static func server_rack(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	P.part(b, pos, rot, Vector3(0, 1.0, 0), Vector3(0.62, 2.0, 0.9), "metal_dark")
	for i in 8:
		P.part(b, pos, rot, Vector3(0, 0.3 + i * 0.2, 0.455), Vector3(0.54, 0.08, 0.01), "metal", false, false)
	P.solid(b, pos, rot, Vector3(0, 1.0, 0), Vector3(0.62, 2.0, 0.9))


## Containment cell front along X at `z`, from x0 to x1: steel bars with an
## open gap (the broken cell door) from gap_x0 to gap_x1.
static func cell_bars(b: GeoBuilder, x0: float, x1: float, z: float, gap_x0: float, gap_x1: float) -> void:
	var x := x0 + 0.08
	while x < x1:
		if x < gap_x0 or x > gap_x1:
			b.box(Vector3(x, 1.25, z), Vector3(0.04, 2.5, 0.04), "metal_dark", false)
		x += 0.16
	b.box(Vector3((x0 + x1) * 0.5, 2.55, z), Vector3(x1 - x0, 0.1, 0.08), "metal_dark", false)
	b.box(Vector3((x0 + x1) * 0.5, 0.05, z), Vector3(x1 - x0, 0.1, 0.08), "metal_dark", false)
	for seg: Vector2 in [Vector2(x0, gap_x0), Vector2(gap_x1, x1)]:
		if seg.y - seg.x > 0.05:
			b.prop_collider(Vector3((seg.x + seg.y) * 0.5, 1.25, z), Vector3(seg.y - seg.x, 2.5, 0.1))
	# The torn-off door lies inside the cell.
	b.box(
		Vector3((gap_x0 + gap_x1) * 0.5, 0.06, z - 0.9),
		Vector3(gap_x1 - gap_x0, 0.06, 1.2),
		"metal_dark",
		false,
		GeoBuilder.FACE_ALL,
		Basis(Vector3.UP, 0.3)
	)


## Specimen tank: a steel plinth and a dark, murky cylinder.
static func specimen_tank(b: GeoBuilder, pos: Vector3) -> void:
	P.cylinder(b, "metal_dark", Transform3D(Basis.IDENTITY, pos + Vector3(0, 0.15, 0)), 0.6, 0.3)
	P.cylinder(b, "tank", Transform3D(Basis.IDENTITY, pos + Vector3(0, 1.2, 0)), 0.5, 1.8)
	P.cylinder(b, "metal_dark", Transform3D(Basis.IDENTITY, pos + Vector3(0, 2.18, 0)), 0.55, 0.16)
	b.prop_collider(pos + Vector3(0, 1.1, 0), Vector3(1.1, 2.2, 1.1))


## Desk terminal: a monitor and keyboard on a surface at height `top`.
static func terminal(b: GeoBuilder, pos: Vector3, rot: float, top: float = 0.78) -> void:
	P.part(b, pos, rot, Vector3(0, top + 0.22, -0.1), Vector3(0.45, 0.32, 0.06), "metal_dark")
	P.part(b, pos, rot, Vector3(0, top + 0.05, -0.1), Vector3(0.08, 0.1, 0.06), "metal_dark")
	P.part(b, pos, rot, Vector3(0, top + 0.012, 0.12), Vector3(0.42, 0.02, 0.14), "metal_dark")
