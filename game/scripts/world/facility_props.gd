class_name FacilityProps
extends RefCounted
## Procedural set dressing for the ward (Map 2) and the station (Map 3),
## built from PropFactory primitives. `rot` is a yaw in degrees; geometry is
## merged into the builder's batches and collision is added only where it
## matters for movement (prop layer: blocks movement, navigation and sight).

const P = preload("res://scripts/world/prop_factory.gd")

# --- Ward --------------------------------------------------------------------------------


static func hospital_bed(b: GeoBuilder, pos: Vector3, rot: float, raised: bool = false) -> void:
	var frame := "metal"
	P.part(b, pos, rot, Vector3(0, 0.5, 0), Vector3(0.95, 0.12, 2.0), frame)
	P.part(b, pos, rot, Vector3(0, 0.62, 0.05), Vector3(0.88, 0.14, 1.85), "fabric_blue")
	var head_tilt := Basis(Vector3.RIGHT, deg_to_rad(-35.0 if raised else 0.0))
	var head_pos := pos + P._basis(rot) * Vector3(0, 0.74 if not raised else 0.85, -0.7)
	b.box(head_pos, Vector3(0.7, 0.1, 0.4), "fabric", false, GeoBuilder.FACE_ALL, P._basis(rot) * head_tilt)
	for sz in [-1, 1]:
		P.part(b, pos, rot, Vector3(0, 0.8, sz * 0.98), Vector3(0.95, 0.6, 0.04), frame)
	for sx in [-1, 1]:
		P.part(b, pos, rot, Vector3(sx * 0.47, 0.85, 0.1), Vector3(0.03, 0.03, 1.2), frame)
		for sz in [-1, 1]:
			P.part(b, pos, rot, Vector3(sx * 0.42, 0.25, sz * 0.9), Vector3(0.05, 0.5, 0.05), frame)
	P.solid(b, pos, rot, Vector3(0, 0.45, 0), Vector3(0.95, 0.9, 2.0))


## Privacy curtain hanging from a ceiling rail between two points (no collision:
## you can slip through, but nobody sees you behind it).
static func curtain(b: GeoBuilder, from: Vector3, to: Vector3, top: float = 2.6, open_amount: float = 0.0) -> void:
	var dir := to - from
	var length := dir.length()
	if length < 0.1:
		return
	var yaw := atan2(-dir.z, dir.x)
	var basis := Basis(Vector3.UP, yaw)
	var mid := (from + to) * 0.5
	b.box(Vector3(mid.x, top, mid.z), Vector3(length, 0.03, 0.03), "metal", false, GeoBuilder.FACE_ALL, basis, false)
	var hung := length * (1.0 - open_amount)
	var folds := maxi(2, int(hung / 0.25))
	for i in folds:
		var t := (float(i) + 0.5) / folds * (hung / length)
		var p := from.lerp(to, t)
		var depth := 0.05 if i % 2 == 0 else -0.05
		b.box(
			Vector3(p.x, top - 0.98, p.z) + basis * Vector3(0, 0, depth),
			Vector3(hung / folds + 0.02, 1.9, 0.02),
			"fabric_blue",
			false,
			GeoBuilder.FACE_ALL,
			basis,
			false
		)


static func iv_stand(b: GeoBuilder, pos: Vector3) -> void:
	b.box(pos + Vector3(0, 0.9, 0), Vector3(0.025, 1.8, 0.025), "metal", false)
	for a in 4:
		var basis := Basis(Vector3.UP, a * PI / 2)
		b.box(
			pos + basis * Vector3(0.14, 0.03, 0), Vector3(0.28, 0.03, 0.03), "metal", false, GeoBuilder.FACE_ALL, basis
		)
	b.box(pos + Vector3(0, 1.8, 0), Vector3(0.3, 0.02, 0.02), "metal", false)
	b.box(pos + Vector3(0.12, 1.62, 0), Vector3(0.09, 0.16, 0.04), "plaster", false)


static func gurney(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	P.part(b, pos, rot, Vector3(0, 0.78, 0), Vector3(0.65, 0.08, 1.9), "metal")
	P.part(b, pos, rot, Vector3(0, 0.85, 0.05), Vector3(0.6, 0.08, 1.75), "fabric")
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			P.part(b, pos, rot, Vector3(sx * 0.28, 0.4, sz * 0.85), Vector3(0.04, 0.78, 0.04), "metal")
			P.part(b, pos, rot, Vector3(sx * 0.28, 0.05, sz * 0.85), Vector3(0.06, 0.08, 0.1), "metal_dark")
	P.solid(b, pos, rot, Vector3(0, 0.45, 0), Vector3(0.65, 0.9, 1.9))


## Row of linked plastic waiting-room chairs along local +X.
static func waiting_chairs(b: GeoBuilder, pos: Vector3, rot: float, count: int = 4) -> void:
	var w := 0.55
	P.part(b, pos, rot, Vector3(0, 0.38, 0.1), Vector3(count * w, 0.05, 0.08), "metal_dark")
	for i in count:
		var x := (i - (count - 1) * 0.5) * w
		P.part(b, pos, rot, Vector3(x, 0.45, 0), Vector3(w - 0.06, 0.05, 0.45), "fabric_blue")
		P.part(b, pos, rot, Vector3(x, 0.72, -0.21), Vector3(w - 0.06, 0.5, 0.04), "fabric_blue")
	for sx in [-1, 1]:
		P.part(b, pos, rot, Vector3(sx * count * w * 0.45, 0.2, 0.1), Vector3(0.05, 0.4, 0.4), "metal_dark")
	P.solid(b, pos, rot, Vector3(0, 0.45, 0), Vector3(count * w, 0.9, 0.5))


## Reception desk: work surface behind a high front panel (along local +X).
static func reception_desk(b: GeoBuilder, pos: Vector3, rot: float, length: float) -> void:
	P.part(b, pos, rot, Vector3(0, 0.55, 0.25), Vector3(length, 1.1, 0.08), "painted_wood")
	P.part(b, pos, rot, Vector3(0, 1.12, 0.3), Vector3(length + 0.04, 0.04, 0.3), "dark_wood")
	P.part(b, pos, rot, Vector3(0, 0.74, -0.1), Vector3(length - 0.1, 0.04, 0.6), "dark_wood")
	P.part(b, pos, rot, Vector3(length * 0.25, 0.92, -0.15), Vector3(0.45, 0.32, 0.06), "metal_dark")
	P.solid(b, pos, rot, Vector3(0, 0.55, 0.05), Vector3(length, 1.1, 0.7))


## Bank of steel lockers along local +X (decor; hiding lockers are entities).
static func locker_bank(b: GeoBuilder, pos: Vector3, rot: float, count: int = 3) -> void:
	var w := 0.42
	for i in count:
		var x := (i - (count - 1) * 0.5) * w
		P.part(b, pos, rot, Vector3(x, 0.95, 0), Vector3(w - 0.02, 1.9, 0.45), "metal_green")
		for k in 3:
			P.part(b, pos, rot, Vector3(x, 1.6 + k * 0.05, 0.226), Vector3(w * 0.6, 0.012, 0.01), "metal_dark")
	P.solid(b, pos, rot, Vector3(0, 0.95, 0), Vector3(count * w, 1.9, 0.45))


static func medicine_fridge(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	P.part(b, pos, rot, Vector3(0, 0.95, 0), Vector3(0.8, 1.9, 0.65), "metal", true)
	P.part(b, pos, rot, Vector3(0, 1.1, 0.33), Vector3(0.66, 1.3, 0.02), "metal_dark")
	P.part(b, pos, rot, Vector3(0.3, 1.1, 0.35), Vector3(0.03, 0.4, 0.03), "metal")


static func wheelchair(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	P.part(b, pos, rot, Vector3(0, 0.48, 0), Vector3(0.45, 0.05, 0.42), "fabric")
	P.part(b, pos, rot, Vector3(0, 0.75, -0.2), Vector3(0.45, 0.5, 0.04), "fabric")
	for sx in [-1, 1]:
		var t := Transform3D(
			P._basis(rot) * Basis(Vector3.BACK, PI / 2), pos + P._basis(rot) * Vector3(sx * 0.27, 0.3, -0.05)
		)
		P.cylinder(b, "metal_dark", t, 0.3, 0.03, 14)
	P.solid(b, pos, rot, Vector3(0, 0.45, 0), Vector3(0.6, 0.9, 0.6))


## Fluorescent ceiling fitting (the light itself is added by the map).
static func strip_light(b: GeoBuilder, ceiling_point: Vector3, rot: float = 0.0) -> void:
	P.part(b, ceiling_point + Vector3(0, -0.05, 0), rot, Vector3.ZERO, Vector3(1.2, 0.08, 0.22), "metal", false, false)
	P.part(b, ceiling_point + Vector3(0, -0.1, 0), rot, Vector3.ZERO, Vector3(1.1, 0.02, 0.16), "plaster", false, false)


# --- Station -------------------------------------------------------------------------------


## Straight track along X from x0 to x1 with its top-of-rail at `y`.
static func track_x(b: GeoBuilder, x0: float, x1: float, z: float, y: float) -> void:
	var n := int((x1 - x0) / 0.65)
	for i in n:
		var x := x0 + 0.32 + i * 0.65
		b.box(Vector3(x, y - 0.2, z), Vector3(0.25, 0.12, 2.5), "dark_wood", false)
	for sz in [-0.72, 0.72]:
		b.box(Vector3((x0 + x1) * 0.5, y - 0.08, z + sz), Vector3(x1 - x0, 0.16, 0.08), "rail", false)


static func platform_bench(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	P.part(b, pos, rot, Vector3(0, 0.45, 0), Vector3(1.8, 0.06, 0.45), "dark_wood")
	P.part(b, pos, rot, Vector3(0, 0.75, -0.2), Vector3(1.8, 0.35, 0.05), "dark_wood")
	for sx in [-1, 1]:
		P.part(b, pos, rot, Vector3(sx * 0.8, 0.3, 0), Vector3(0.06, 0.6, 0.45), "metal_dark")
	P.solid(b, pos, rot, Vector3(0, 0.45, 0), Vector3(1.8, 0.9, 0.5))


static func ticket_gate(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	P.part(b, pos, rot, Vector3(0, 0.55, 0), Vector3(0.3, 1.1, 1.2), "metal", true)
	P.part(b, pos, rot, Vector3(0, 1.12, -0.35), Vector3(0.22, 0.04, 0.3), "metal_dark")
	P.part(b, pos, rot, Vector3(0.45, 0.85, 0), Vector3(0.6, 0.04, 0.04), "metal_dark")


static func vending_machine(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	P.part(b, pos, rot, Vector3(0, 0.95, 0), Vector3(0.9, 1.9, 0.75), "metal_dark", true)
	P.part(b, pos, rot, Vector3(-0.12, 1.15, 0.38), Vector3(0.55, 1.2, 0.02), "metal")
	P.part(b, pos, rot, Vector3(0.33, 1.2, 0.38), Vector3(0.14, 0.5, 0.02), "metal")


## Iron tunnel rib: an arch of boxes across the tunnel at `x`.
static func tunnel_rib(b: GeoBuilder, x: float, z0: float, z1: float, y0: float, height: float) -> void:
	b.box(Vector3(x, y0 + height * 0.5, z0 + 0.1), Vector3(0.25, height, 0.2), "rust", false)
	b.box(Vector3(x, y0 + height * 0.5, z1 - 0.1), Vector3(0.25, height, 0.2), "rust", false)
	b.box(Vector3(x, y0 + height - 0.1, (z0 + z1) * 0.5), Vector3(0.25, 0.2, z1 - z0), "rust", false)


static func signal_post(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	P.part(b, pos, rot, Vector3(0, 1.0, 0), Vector3(0.12, 2.0, 0.12), "metal_dark")
	P.part(b, pos, rot, Vector3(0, 2.2, 0.05), Vector3(0.35, 0.6, 0.2), "metal_dark")


static func kiosk(b: GeoBuilder, pos: Vector3, rot: float) -> void:
	P.part(b, pos, rot, Vector3(0, 0.55, 0), Vector3(2.0, 1.1, 1.2), "painted_wood", true)
	P.part(b, pos, rot, Vector3(0, 2.3, 0), Vector3(2.2, 0.1, 1.4), "metal_dark")
	for sx in [-1, 1]:
		P.part(b, pos, rot, Vector3(sx * 0.95, 1.7, 0.55), Vector3(0.06, 1.2, 0.06), "metal_dark")
