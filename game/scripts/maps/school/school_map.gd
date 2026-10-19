extends MapBase
## Map 4 — The Silent School ("METHOD Field Site 04", Hollins Primary).
##
## Layout (meters, +X east, +Z south, one storey):
##   Corridor x0-52 z14-18; a locked wing door at x=36 closes the east wing.
##   North (z4-14): classroom A x0-10, classroom B x10-20, staff room
##     x20-28 (PA), caretaker x28-36 (main breaker) | east wing: music room
##     x36-44 (chimes), headmistress's office x44-52 (tuned lock).
##   South (z18-28): classroom C x0-12, entrance hall x12-24 (to z30, the
##     chained front doors), library x24-36 | east wing: classroom D x36-46,
##     art store x46-52. Porch outside the front doors x15-21 z30-33.

const SchoolRules = preload("res://scripts/maps/school/school_rules.gd")
const H := 3.3
const DOOR_TOP := 2.2
const WIN_BOTTOM := 1.0
const WIN_TOP := 2.5
## Seconds between the PA chime and the first note, and between notes.
const TUNE_LEAD := 1.8
const TUNE_STEP := 1.4
## Corridor PA horns: the bell tune plays from all of them at once.
const SPEAKERS: Array[Vector3] = [
	Vector3(6.0, 2.95, 17.8), Vector3(18.0, 2.95, 14.2), Vector3(30.0, 2.95, 17.8), Vector3(44.0, 2.95, 14.2)
]

var music_box: MusicBox
var _chain: Node3D
var _pa_uses_seen := 0
## Pending notes: [seconds_left, bar].
var _tune_queue: Array = []


func build_level() -> void:
	prepare()
	PropFactory.rng.seed = 4404
	configure_environment(Color(0.16, 0.16, 0.18), 1.0, Color(0.02, 0.02, 0.025), 0.035)
	_rooms()
	_shell()
	_north_rooms()
	_south_rooms()
	_props()
	_lighting()
	_entities()
	_spawns()
	finalize()


# --- Geometry ------------------------------------------------------------------------------


func _rooms() -> void:
	add_room("corridor", AABB(Vector3(0, 0, 14), Vector3(36, H, 4)), "concrete")
	add_room("east_corridor", AABB(Vector3(36, 0, 14), Vector3(16, H, 4)), "concrete")
	add_room("class_a", AABB(Vector3(0, 0, 4), Vector3(10, H, 10)), "wood")
	add_room("class_b", AABB(Vector3(10, 0, 4), Vector3(10, H, 10)), "wood")
	add_room("staff", AABB(Vector3(20, 0, 4), Vector3(8, H, 10)), "carpet")
	add_room("caretaker", AABB(Vector3(28, 0, 4), Vector3(8, H, 10)), "concrete")
	add_room("music", AABB(Vector3(36, 0, 4), Vector3(8, H, 10)), "wood")
	add_room("office", AABB(Vector3(44, 0, 4), Vector3(8, H, 10)), "carpet")
	add_room("class_c", AABB(Vector3(0, 0, 18), Vector3(12, H, 10)), "wood")
	add_room("hall", AABB(Vector3(12, 0, 18), Vector3(12, H, 12)), "concrete")
	add_room("library", AABB(Vector3(24, 0, 18), Vector3(12, H, 10)), "carpet")
	add_room("class_d", AABB(Vector3(36, 0, 18), Vector3(10, H, 10)), "wood")
	add_room("art", AABB(Vector3(46, 0, 18), Vector3(6, H, 10)), "concrete")
	add_room("porch", AABB(Vector3(15, 0, 30), Vector3(6, H, 3)), "concrete")


func _shell() -> void:
	var b := builder
	# Corridor floor and ceiling in 8 m pieces: the Mobile renderer lights each
	# mesh with at most 8 lamps, and a 52 m corridor touches far more.
	for x0 in range(0, 52, 8):
		var x1 := minf(x0 + 8.0, 52.0)
		b.room = "corridor_%d" % x0
		b.floor_rect(x0, 14, x1, 18, 0.0, "tile")
	# Ceiling and the green dado band share the 16 m wall bands' batches (fewer draw calls).
	for x0 in range(0, 52, 16):
		var x1 := minf(x0 + 16.0, 52.0)
		b.room = _band(x0 + 1.0, 14.0)
		b.ceiling_rect(x0, 14, x1, 18, H, "ceiling_panel")
		b.box(Vector3((x0 + x1) * 0.5, 1.05, 14.1), Vector3(x1 - x0, 0.08, 0.02), "school_dado", false)
		b.room = _band(x0 + 1.0, 18.0)
		b.box(Vector3((x0 + x1) * 0.5, 1.05, 17.9), Vector3(x1 - x0, 0.08, 0.02), "school_dado", false)
	# Corridor walls: room side first (north rooms on -Z of z=14, south on +Z of z=18).
	b.room = "walls_n_0"
	b.wall_x(14, 0, 10, 0, H, "school_paint", "school_tile", [_doorway(7.0, 8.4)])
	b.room = "walls_n_0"
	b.wall_x(14, 10, 20, 0, H, "school_paint", "school_tile", [_doorway(17.0, 18.4)])
	b.room = "walls_n_1"
	b.wall_x(14, 20, 28, 0, H, "wallpaper_green", "school_tile", [_doorway(21.0, 22.4)])
	b.room = "walls_n_2"
	b.wall_x(14, 28, 36, 0, H, "blocks", "school_tile", [_doorway(29.0, 30.4)])
	b.room = "walls_n_2"
	b.wall_x(14, 36, 44, 0, H, "school_paint", "school_tile", [_doorway(37.0, 38.4)])
	b.room = "walls_n_3"
	b.wall_x(14, 44, 52, 0, H, "wallpaper_red", "school_tile", [_doorway(45.0, 46.4)])
	b.room = "walls_s_0"
	b.wall_x(18, 0, 12, 0, H, "school_tile", "school_paint", [_doorway(9.0, 10.4)])
	b.room = "walls_s_1"
	b.wall_x(18, 12, 24, 0, H, "school_tile", "school_paint", [{"from": 13.5, "to": 22.5, "top": 2.9}])
	b.room = "walls_s_1"
	b.wall_x(18, 24, 36, 0, H, "school_tile", "wallpaper", [_doorway(25.0, 26.4)])
	b.room = "walls_s_2"
	b.wall_x(18, 36, 46, 0, H, "school_tile", "school_paint", [_doorway(37.0, 38.4)])
	b.room = "walls_s_3"
	b.wall_x(18, 46, 52, 0, H, "school_tile", "blocks", [_doorway(47.0, 48.4)])
	b.room = "walls_n_0"
	b.wall_z(0, 14, 18, 0, H, "school_tile", "school_tile")
	b.room = "walls_n_3"
	b.wall_z(52, 14, 18, 0, H, "school_tile", "school_tile")
	b.room = "east_corridor"
	b.wall_z(36, 14, 18, 0, H, "school_tile", "school_tile", [_doorway(15.3, 16.7)])


func _north_rooms() -> void:
	var b := builder
	for r: Array in [
		["class_a", 0.0, 10.0, "parquet", "school_paint"],
		["class_b", 10.0, 20.0, "parquet", "school_paint"],
		["staff", 20.0, 28.0, "carpet", "wallpaper_green"],
		["caretaker", 28.0, 36.0, "concrete_floor", "blocks"],
		["music", 36.0, 44.0, "parquet", "school_paint"],
		["office", 44.0, 52.0, "carpet", "wallpaper_red"],
	]:
		b.room = str(r[0])
		b.floor_rect(r[1], 4, r[2], 14, 0.0, str(r[3]))
		b.room = _band((r[1] + r[2]) * 0.5, 9.0)
		b.ceiling_rect(r[1], 4, r[2], 14, H, "ceiling_panel")
		b.room = str(r[0])
		var wins: Array = [] if str(r[0]) in ["caretaker", "office"] else [_win(r[1] + 2.0, r[2] - 2.0)]
		b.wall_x(4, r[1], r[2], 0, H, str(r[4]), str(r[4]), wins)
		if not wins.is_empty():
			PropFactory.boarded_window(
				b,
				Vector3((r[1] + r[2]) * 0.5, (WIN_BOTTOM + WIN_TOP) * 0.5, 4.06),
				r[2] - r[1] - 4.0,
				WIN_TOP - WIN_BOTTOM,
				true
			)
	b.room = "walls_n_0"
	b.wall_z(0, 4, 14, 0, H, "school_paint", "school_paint")
	b.room = "walls_n_0"
	b.wall_z(10, 4, 14, 0, H, "school_paint", "school_paint")
	b.room = "walls_n_1"
	b.wall_z(20, 4, 14, 0, H, "school_paint", "wallpaper_green")
	b.room = "walls_n_1"
	b.wall_z(28, 4, 14, 0, H, "wallpaper_green", "blocks")
	b.room = "walls_n_2"
	b.wall_z(36, 4, 14, 0, H, "blocks", "school_paint")
	b.room = "walls_n_2"
	b.wall_z(44, 4, 14, 0, H, "school_paint", "wallpaper_red")
	b.room = "walls_n_3"
	b.wall_z(52, 4, 14, 0, H, "wallpaper_red", "wallpaper_red")


func _south_rooms() -> void:
	var b := builder
	for r: Array in [
		["class_c", 0.0, 12.0, "parquet", "school_paint"],
		["library", 24.0, 36.0, "carpet", "wallpaper"],
		["class_d", 36.0, 46.0, "parquet", "school_paint"],
		["art", 46.0, 52.0, "concrete_floor", "blocks"],
	]:
		b.room = str(r[0])
		b.floor_rect(r[1], 18, r[2], 28, 0.0, str(r[3]))
		b.room = _band((r[1] + r[2]) * 0.5, 23.0)
		b.ceiling_rect(r[1], 18, r[2], 28, H, "ceiling_panel")
		b.room = str(r[0])
		var wins: Array = [_win(r[1] + 2.0, r[2] - 2.0)] if r[2] - r[1] >= 8.0 else []
		b.wall_x(28, r[1], r[2], 0, H, str(r[4]), str(r[4]), wins)
		if not wins.is_empty():
			PropFactory.boarded_window(
				b,
				Vector3((r[1] + r[2]) * 0.5, (WIN_BOTTOM + WIN_TOP) * 0.5, 27.94),
				r[2] - r[1] - 4.0,
				WIN_TOP - WIN_BOTTOM,
				true
			)
	b.room = "walls_s_0"
	b.wall_z(0, 18, 28, 0, H, "school_paint", "school_paint")
	b.room = "walls_s_2"
	b.wall_z(36, 18, 28, 0, H, "wallpaper", "school_paint")
	b.room = "walls_s_2"
	b.wall_z(46, 18, 28, 0, H, "school_paint", "blocks")
	b.room = "walls_s_3"
	b.wall_z(52, 18, 28, 0, H, "blocks", "blocks")
	# Entrance hall, two storeys of tile and the chained front doors.
	b.room = "hall"
	b.floor_rect(12, 18, 24, 30, 0.0, "tile")
	b.room = _band(18.0, 24.0)
	b.ceiling_rect(12, 18, 24, 30, H, "ceiling_panel")
	b.room = "hall"
	b.room = "walls_s_0"
	b.wall_z(12, 18, 30, 0, H, "school_paint", "school_tile")
	b.room = "walls_s_1"
	b.wall_z(24, 18, 30, 0, H, "school_tile", "wallpaper")
	b.wall_x(30, 12, 24, 0, H, "school_tile", "exterior", [{"from": 17.0, "to": 19.0, "top": 2.4}])
	b.box(Vector3(18, 1.05, 29.9), Vector3(12, 0.08, 0.02), "school_dado", false)
	# Porch: night air beyond the doors.
	b.room = "porch"
	b.floor_rect(15, 30, 21, 33, 0.0, "concrete")
	b.ceiling_rect(15, 30, 21, 33, H, "concrete")
	b.room = "walls_s_0"
	b.wall_z(15, 30, 33, 0, H, "exterior", "exterior")
	b.room = "walls_s_1"
	b.wall_z(21, 30, 33, 0, H, "exterior", "exterior")
	b.wall_x(33, 15, 21, 0, H, "exterior", "exterior")


# --- Props ----------------------------------------------------------------------------------


func _props() -> void:
	var b := builder
	# Classrooms A and B: rows of desks facing the board on the north wall.
	for room: Array in [["class_a", 0.0], ["class_b", 10.0]]:
		b.room = str(room[0])
		var ox: float = room[1]
		FinaleProps.chalkboard(b, Vector3(ox + 5.0, 0, 4.08), 0)
		FinaleProps.teacher_desk(b, Vector3(ox + 5.0, 0, 5.4), 180)
		PropFactory.chair(b, Vector3(ox + 5.0, 0, 4.7), 0)
		for row in 3:
			for col in 3:
				var tipped := (row + col + int(ox)) % 5 == 3
				FinaleProps.school_desk(b, Vector3(ox + 2.5 + col * 2.5, 0, 7.0 + row * 2.0), 0, tipped)
	b.room = "class_b"
	FinaleProps.cubbies(b, Vector3(10.25, 0, 11.5), 90, 2.0)
	# Classroom C faces its board on the south wall.
	b.room = "class_c"
	FinaleProps.chalkboard(b, Vector3(6.0, 0, 27.92), 180)
	FinaleProps.teacher_desk(b, Vector3(6.0, 0, 26.6), 0)
	for row in 2:
		for col in 3:
			FinaleProps.school_desk(b, Vector3(3.0 + col * 2.6, 0, 24.0 - row * 2.2), 180, row == 1 and col == 0)
	FinaleProps.cubbies(b, Vector3(0.25, 0, 21.5), 90, 2.4)
	# Staff room.
	b.room = "staff"
	PropFactory.table(b, Vector3(24.0, 0, 10.0), 0, 1.8, 0.9, "painted_wood")
	for p: Array in [[Vector3(23.4, 0, 10.75), 180.0], [Vector3(24.6, 0, 10.75), 180.0], [Vector3(24.0, 0, 9.25), 0.0]]:
		PropFactory.chair(b, p[0], p[1])
	PropFactory.sofa(b, Vector3(27.5, 0, 9.0), -90, 1.8)
	PropFactory.counter(b, Vector3(20.4, 0, 7.0), 90, 2.2, true)
	PropFactory.fridge(b, Vector3(20.45, 0, 5.0), 90)
	b.box(Vector3(24.0, 1.6, 13.88), Vector3(2.4, 1.2, 0.03), "cork", false)
	# Caretaker's room.
	b.room = "caretaker"
	PropFactory.workbench(b, Vector3(35.45, 0, 9.3), -90)
	PropFactory.boiler(b, Vector3(29.4, 0, 5.4))
	PropFactory.shelf(b, Vector3(35.6, 0, 6.0), -90, 1.8, 2.0, 0.45, "metal_dark")
	PropFactory.pipe_run(b, Vector3(28.3, 2.9, 4.4), Vector3(35.7, 2.9, 4.4), 0.06)
	PropFactory.crate(b, Vector3(30.2, 0, 12.8), Vector3(0.8, 0.6, 0.6), 8, "dark_wood")
	# Hall.
	b.room = "hall"
	FinaleProps.coat_bench(b, Vector3(12.3, 0, 24.0), 90, 2.8)
	FinaleProps.coat_bench(b, Vector3(23.7, 0, 24.0), -90, 2.8)
	PropFactory.cabinet(b, Vector3(13.0, 0, 29.6), 180, 1.4, 1.8, 0.45, "dark_wood")
	# Library.
	b.room = "library"
	for z in [20.5, 23.5]:
		PropFactory.shelf(b, Vector3(35.75, 0, z + 0.5), -90, 2.2, 2.0, 0.4, "dark_wood")
	PropFactory.shelf(b, Vector3(28.0, 0, 27.75), 180, 2.4, 2.0, 0.4, "dark_wood")
	PropFactory.shelf(b, Vector3(32.0, 0, 27.75), 180, 2.4, 2.0, 0.4, "dark_wood")
	PropFactory.table(b, Vector3(30.0, 0, 23.0), 90, 2.0, 1.0, "dark_wood")
	for z in [22.4, 23.6]:
		PropFactory.chair(b, Vector3(28.9, 0, z), 90)
		PropFactory.chair(b, Vector3(31.1, 0, z), -90)
	PropFactory.rug(b, Vector3(30.0, 0, 23.0), Vector2(4.0, 3.0))
	# Music room.
	b.room = "music"
	FinaleProps.piano(b, Vector3(38.2, 0, 4.4), 0)
	for i in 6:
		var a := deg_to_rad(-60.0 + i * 24.0)
		PropFactory.chair(b, Vector3(40.0 + sin(a) * 3.0, 0, 9.5 + cos(a) * 3.0), rad_to_deg(a) + 180.0)
	FinaleProps.cubbies(b, Vector3(43.75, 0, 7.0), -90, 2.4)
	# Headmistress's office.
	b.room = "office"
	FinaleProps.teacher_desk(b, Vector3(48.0, 0, 8.0), 180)
	PropFactory.chair(b, Vector3(48.0, 0, 7.2), 0)
	PropFactory.cabinet(b, Vector3(51.6, 0, 6.0), -90, 0.9, 1.1, 0.45, "metal_green")
	PropFactory.shelf(b, Vector3(44.3, 0, 10.0), 90, 1.8, 2.0, 0.4, "dark_wood")
	PropFactory.rug(b, Vector3(48.0, 0, 9.0), Vector2(3.0, 2.2))
	PropFactory.wall_clock(b, Vector3(48.0, 2.45, 4.13), 0)
	# Classroom D and the art store (east wing).
	b.room = "class_d"
	FinaleProps.chalkboard(b, Vector3(41.0, 0, 27.92), 180)
	for col in 3:
		FinaleProps.school_desk(b, Vector3(38.5 + col * 2.5, 0, 23.0), 180, col == 2)
	b.room = "art"
	PropFactory.table(b, Vector3(49.0, 0, 23.0), 0, 2.0, 1.0, "painted_wood")
	PropFactory.shelf(b, Vector3(51.75, 0, 21.0), -90, 2.0, 2.0, 0.4, "metal_dark")
	PropFactory.debris(b, Vector3(49.0, 0, 25.5), 1.5, 8)
	# PA horns in the corridor.
	b.room = "corridor"
	for sp in SPEAKERS:
		b.box(sp, Vector3(0.3, 0.22, 0.25), "metal_dark", false)
	PropFactory.debris(b, Vector3(20.0, 0, 16.0), 6.0, 10)
	PropFactory.debris(b, Vector3(42.0, 0, 16.0), 4.0, 6)
	# Painted motto above the hall arch; the METHOD stencil the night staff left.
	var motto := Label3D.new()
	motto.text = "HOLLINS PRIMARY  ·  QUIET MINDS LEARN"
	motto.font_size = 40
	motto.pixel_size = 0.0028
	motto.modulate = Color(0.78, 0.74, 0.62)
	motto.shaded = true
	motto.position = Vector3(18.0, 3.05, 18.1)
	lights_root.add_child(motto)
	var stencil := Label3D.new()
	stencil.text = "METHOD  —  FIELD SITE 04\nAUDITORY CONDITIONING · DO NOT LOOK AWAY"
	stencil.font_size = 28
	stencil.pixel_size = 0.0022
	stencil.modulate = Color(0.62, 0.12, 0.09)
	stencil.shaded = true
	stencil.position = Vector3(44.0, 2.2, 17.85)
	stencil.rotation.y = PI
	lights_root.add_child(stencil)
	# The chain across the front doors (gone once cut): one merged mesh.
	var links := SurfaceTool.new()
	links.begin(Mesh.PRIMITIVE_TRIANGLES)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.035
	torus.outer_radius = 0.06
	torus.rings = 8
	torus.ring_segments = 5
	for i in 9:
		var basis := Basis.from_euler(Vector3(PI / 2 if i % 2 == 0 else 0.0, 0, PI / 2))
		links.append_from(torus, 0, Transform3D(basis, Vector3(-0.9 + i * 0.225, sin(i * 0.7) * 0.05, 0)))
	var padlock := BoxMesh.new()
	padlock.size = Vector3(0.1, 0.13, 0.05)
	links.append_from(padlock, 0, Transform3D(Basis.IDENTITY, Vector3(0.05, -0.12, 0)))
	_chain = MeshInstance3D.new()
	(_chain as MeshInstance3D).mesh = links.commit()
	(_chain as MeshInstance3D).material_override = MaterialLib.flat(Color(0.5, 0.48, 0.45), 0.35, 0.85)
	_chain.position = Vector3(18.0, 1.15, 29.82)
	lights_root.add_child(_chain)


# --- Lighting --------------------------------------------------------------------------------


func _lighting() -> void:
	var fixtures: Array = []
	for x in [3.0, 7.0]:
		fixtures.append(["class_a", Vector3(x, H, 9.0)])
	for x in [13.0, 17.0]:
		fixtures.append(["class_b", Vector3(x, H, 9.0)])
	fixtures.append(["staff", Vector3(24.0, H, 9.0)])
	fixtures.append(["caretaker", Vector3(32.0, H, 9.0)])
	fixtures.append(["music", Vector3(40.0, H, 9.0)])
	fixtures.append(["office", Vector3(48.0, H, 9.0)])
	for x in [3.0, 9.0]:
		fixtures.append(["class_c", Vector3(x, H, 23.0)])
	fixtures.append(["library", Vector3(30.0, H, 23.0)])
	fixtures.append(["class_d", Vector3(41.0, H, 23.0)])
	fixtures.append(["art", Vector3(49.0, H, 23.0)])
	for x in [6.0, 14.0, 22.0, 30.0]:
		fixtures.append(["corridor", Vector3(x, H, 16.0)])
	for x in [40.0, 48.0]:
		fixtures.append(["east_corridor", Vector3(x, H, 16.0)])
	for z in [21.0, 26.0]:
		fixtures.append(["hall", Vector3(18.0, H, z)])
	for f in fixtures:
		var top: Vector3 = f[1]
		builder.room = "fixtures"
		FacilityProps.strip_light(builder, top, 0.0)
		add_lamp(top + Vector3(0, -0.25, 0), f[0], 1.25, Color(1.0, 0.93, 0.8), true, str(f[0]) == "hall", 7.0)
	# Battery-backed exit signs and a night light: the only light before the breaker.
	var green := Color(0.35, 1.0, 0.5)
	add_lamp(Vector3(18.0, 2.7, 29.7), "hall", 0.55, green, false, false, 5.5)
	add_lamp(Vector3(1.0, 2.7, 16.0), "corridor", 0.45, green, false, false, 5.0)
	add_lamp(Vector3(35.6, 2.7, 16.0), "corridor", 0.45, green, false, false, 5.0)
	add_lamp(Vector3(51.0, 2.7, 16.0), "east_corridor", 0.45, green, false, false, 5.0)
	add_lamp(Vector3(5.0, 2.2, 4.6), "class_a", 0.35, Color(0.6, 0.65, 1.0), false, false, 4.0)
	add_lamp(Vector3(31.0, 2.4, 13.4), "caretaker", 0.5, Color(1.0, 0.5, 0.15), false, false, 5.0)
	add_moonlight(Vector3(5.0, 2.4, 3.6), Vector3(5.0, 0.0, 9.0), 1.2)
	add_moonlight(Vector3(40.0, 2.4, 3.6), Vector3(40.0, 0.0, 9.0), 1.0)
	add_moonlight(Vector3(6.0, 2.4, 28.4), Vector3(6.0, 0.0, 22.0), 1.1)
	add_dust(AABB(Vector3(0, 0, 14), Vector3(52, H, 4)), 70)
	add_dust(AABB(Vector3(12, 0, 18), Vector3(12, H, 12)), 50)
	apply_graphics_settings()


# --- Entities ----------------------------------------------------------------------------


func _entities() -> void:
	for d: Array in [
		["door_class_a", 7.0, 14.0],
		["door_class_b", 17.0, 14.0],
		["door_staff", 21.0, 14.0],
		["door_caretaker", 29.0, 14.0],
		["door_music", 37.0, 14.0],
		["door_class_c", 9.0, 18.0],
		["door_library", 25.0, 18.0],
		["door_class_d", 37.0, 18.0],
		["door_art", 47.0, 18.0],
	]:
		_door(str(d[0]), Vector3(d[1], 0, d[2]), 0, 1.4)
	_door(
		"door_office",
		Vector3(45.0, 0, 14.0),
		0,
		1.4,
		"flag:chimes_solved",
		"OFFICE_TUNED_LOCK",
		{"material": "dark_wood", "unlock_flag": "office_open"}
	)
	_door(
		"door_wing",
		Vector3(36.0, 0, 15.3),
		-90,
		1.4,
		"item:wing_key",
		"DOOR_WING_LOCKED",
		{"material": "metal_green", "unlock_flag": "wing_open"}
	)
	_door(
		"door_front",
		Vector3(17.0, 0, 30.0),
		0,
		2.0,
		"item:bolt_cutters",
		"FRONT_DOORS_CHAINED",
		{"material": "dark_wood", "try_flag": "exit_found", "unlock_flag": "doors_open"}
	)

	music_box = MusicBox.new()
	music_box.entity_id = "music_box"
	add_entity(music_box, Transform3D(Basis.IDENTITY, Vector3(5.0, -5.0, 9.0)))
	var breaker := ControlConsole.new()
	breaker.entity_id = "main_breaker"
	breaker.prompt_key = "PROMPT_MAIN_BREAKER"
	breaker.done_prompt_key = "PROMPT_POWER_RESTORED"
	breaker.set_flag = "school_power"
	breaker.activate_sound = "power_on"
	breaker.noise_radius = 12.0
	breaker.hold_time = 1.0
	add_entity(breaker, Transform3D(Basis.IDENTITY, Vector3(32.5, 0, 4.5)))
	var pa := ControlConsole.new()
	pa.entity_id = "pa_console"
	pa.prompt_key = "PROMPT_PA"
	pa.done_prompt_key = "PROMPT_PA_AGAIN"
	pa.required_flags = ["school_power"]
	pa.set_flag = "tune_heard"
	pa.missing_message = "PA_NO_POWER"
	pa.activate_sound = "pa_chime"
	pa.noise_radius = 26.0
	pa.hold_time = 0.6
	pa.repeatable = true
	add_entity(pa, Transform3D(Basis.IDENTITY, Vector3(26.0, 0, 4.5)))
	var chimes := ChimeBoard.new()
	chimes.entity_id = "chime_board"
	add_entity(chimes, Transform3D(Basis.IDENTITY, Vector3(40.0, 0, 9.5)))
	var zone := EscapeZone.new()
	zone.match_ctrl = match_ctrl
	zone.required_flag = "doors_open"
	zone.position = Vector3(18.0, 1.2, 31.8)
	zone.setup_box(Vector3(5.0, 2.4, 2.0))
	add_child(zone)

	_note("note_bell", Vector3(23.6, 0.79, 10.1), "NOTE_BELL_T", "NOTE_BELL_B", "paper", 12)
	_note("note_lost", Vector3(14.2, 1.5, 29.88), "NOTE_LOST_T", "NOTE_LOST_B", "wall", 180)
	_note("note_caretaker", Vector3(35.4, 0.94, 8.6), "NOTE_CARETAKER_T", "NOTE_CARETAKER_B", "clipboard", -80)
	_note("note_drawing", Vector3(12.0, 1.4, 13.88), "NOTE_DRAWING_T", "NOTE_DRAWING_B", "wall", 180)
	_note("note_sheet", Vector3(38.2, 1.25, 4.4), "NOTE_SHEET_T", "NOTE_SHEET_B", "paper", 0)
	_note("note_method", Vector3(48.0, 0.79, 8.25), "NOTE_SITE04_T", "NOTE_SITE04_B", "paper", -15)
	var tape := TapeRecorder.new()
	tape.entity_id = "tape_office"
	tape.speaker_key = "SPEAKER_ASHDOWN"
	tape.line_keys = ["TAPE_SCHOOL_1", "TAPE_SCHOOL_2", "TAPE_SCHOOL_3", "TAPE_SCHOOL_4"]
	add_entity(tape, Transform3D(Basis(Vector3.UP, -0.3), Vector3(47.5, 0.79, 7.95)))
	var files := {
		"file_class_a": Vector3(2.5, 0.73, 11.0),
		"file_class_b": Vector3(17.5, 0.73, 7.0),
		"file_class_c": Vector3(8.2, 0.73, 21.8),
		"file_library": Vector3(35.7, 1.05, 24.0),
		"file_staff": Vector3(20.5, 0.93, 7.6),
		"file_music": Vector3(43.75, 0.93, 6.4),
	}
	for id in files:
		var c := CollectibleEntity.new()
		c.entity_id = id
		c.collectible_id = "school_" + str(id).substr(5)
		add_entity(c, Transform3D(Basis(Vector3.UP, 0.4), files[id]))

	_hide("hide_corridor_w", Vector3(3.0, 0, 14.45), 0, "locker")
	_hide("hide_corridor_b", Vector3(13.5, 0, 14.45), 0, "locker")
	_hide("hide_corridor_e", Vector3(26.0, 0, 14.45), 0, "locker")
	_hide("hide_corridor_wing", Vector3(42.0, 0, 14.45), 0, "locker")
	_hide("hide_class_a", Vector3(0.45, 0, 12.5), 90, "wardrobe")
	_hide("hide_class_c", Vector3(11.4, 0, 20.0), -90, "wardrobe")
	_hide("hide_library", Vector3(24.6, 0, 26.6), 90, "wardrobe")
	_hide("hide_music", Vector3(43.4, 0, 12.3), -90, "wardrobe")
	_hide("hide_office", Vector3(51.4, 0, 12.4), -90, "wardrobe")


func _door(
	id: String,
	hinge: Vector3,
	rot_deg: float,
	width: float,
	lock: String = "",
	msg: String = "DOOR_LOCKED",
	props: Dictionary = {}
) -> DoorEntity:
	var d := DoorEntity.new()
	d.entity_id = id
	d.width = width
	d.lock = lock
	d.locked_message = msg
	for key in props:
		d.set(key, props[key])
	add_entity(d, Transform3D(Basis(Vector3.UP, deg_to_rad(rot_deg)), hinge))
	return d


func _note(id: String, pos: Vector3, title: String, body: String, style: String, rot_deg: float) -> NoteEntity:
	var n := NoteEntity.new()
	n.entity_id = id
	n.title_key = title
	n.body_key = body
	n.style = style
	add_entity(n, Transform3D(Basis(Vector3.UP, deg_to_rad(rot_deg)), pos))
	return n


func _hide(id: String, pos: Vector3, rot_deg: float, style: String) -> void:
	var h := HidingSpot.new()
	h.entity_id = id
	h.style = style
	if style == "wardrobe":
		h.view_offset = Vector3(0, 1.5, -0.05)
	add_entity(h, Transform3D(Basis(Vector3.UP, deg_to_rad(rot_deg)), pos))


# --- Spawns / navigation hints ------------------------------------------------------------


func _spawns() -> void:
	player_spawns = [
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(18.0, 0.05, 25.0)),
		Transform3D(Basis(Vector3.UP, 0.3), Vector3(17.0, 0.05, 25.6)),
		Transform3D(Basis(Vector3.UP, -0.3), Vector3(19.0, 0.05, 25.6)),
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(17.0, 0.05, 26.6)),
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(19.0, 0.05, 26.6)),
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(18.0, 0.05, 27.4)),
	]
	enemy_spawns = [
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(2.0, 0.05, 5.5)),
		Transform3D(Basis(Vector3.UP, PI), Vector3(14.0, 0.05, 5.5)),
		Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(33.0, 0.05, 26.0)),
		Transform3D(Basis(Vector3.UP, PI / 2), Vector3(2.0, 0.05, 26.5)),
	]
	patrol_points = [
		Vector3(3, 0, 16),
		Vector3(12, 0, 16),
		Vector3(20, 0, 16),
		Vector3(28, 0, 16),
		Vector3(34, 0, 16),
		Vector3(5, 0, 12.6),
		Vector3(15, 0, 12.6),
		Vector3(24, 0, 7),
		Vector3(32, 0, 11),
		Vector3(6, 0, 20),
		Vector3(18, 0, 22),
		Vector3(30, 0, 20.5),
		Vector3(33, 0, 25.5),
		Vector3(40, 0, 16),
		Vector3(49, 0, 16),
		Vector3(40, 0, 12.5),
		Vector3(41, 0, 20.5),
		Vector3(48.5, 0, 11.5),
	]
	prowl_points = [Vector3(1, 0, 16), Vector3(51, 0, 16), Vector3(2, 0, 5), Vector3(34, 0, 26.5), Vector3(13, 0, 19)]
	var spawns := {
		"sp_class_a_desk": Vector3(5.0, 0.73, 9.0),
		"sp_class_a_teacher": Vector3(5.4, 0.79, 5.4),
		"sp_class_b_desk": Vector3(12.5, 0.73, 9.0),
		"sp_class_b_cubby": Vector3(10.3, 0.93, 11.5),
		"sp_class_c_desk": Vector3(5.6, 0.73, 21.8),
		"sp_class_c_teacher": Vector3(6.4, 0.79, 26.6),
		"sp_library_table": Vector3(30.2, 0.79, 23.3),
		"sp_library_shelf": Vector3(35.7, 1.05, 21.0),
		"sp_staff_table": Vector3(24.4, 0.79, 9.9),
		"sp_hall_bench": Vector3(12.4, 0.46, 23.2),
		"sp_caretaker_bench": Vector3(35.5, 0.94, 9.9),
		"sp_office_desk": Vector3(48.55, 0.79, 7.85),
		"sp_office_cabinet": Vector3(51.6, 1.15, 6.0),
		"sp_office_shelf": Vector3(44.35, 1.05, 10.0),
		"bt_class_a": Vector3(7.5, 0.73, 7.0),
		"bt_class_b": Vector3(15.0, 0.73, 11.0),
		"bt_class_c": Vector3(3.0, 0.73, 21.8),
		"bt_library": Vector3(29.6, 0.79, 22.5),
		"bt_staff": Vector3(20.5, 0.93, 6.4),
		"bt_caretaker": Vector3(35.6, 1.05, 6.0),
		"bt_hall": Vector3(23.6, 0.46, 24.8),
		"bt_corridor": Vector3(13.0, 1.84, 29.6),
	}
	for id in spawns:
		add_spawn_point(id, Transform3D(Basis.IDENTITY, spawns[id]))


# --- Variant / tick ----------------------------------------------------------------------------


func apply_variant(mc: MatchController, variant: Dictionary) -> void:
	if not mc.is_authority or variant.is_empty():
		return
	var placements: Dictionary = variant.get("placements", {})
	for slot in placements:
		place_pickup_state(mc, "pickup_" + str(slot), mc.rules.item_for_slot(slot), placements[slot])
	# The music box plays beside wherever the wing key was left.
	var key_spot: Dictionary = spawn_points.get(str(placements.get("wing_key", "")), {})
	if not key_spot.is_empty():
		var p: Vector3 = (key_spot["xform"] as Transform3D).origin + Vector3(0.2, -0.01, 0.05)
		seed_state(mc, "music_box", {"pos": [p.x, p.y, p.z], "playing": true})
	var puzzle: Dictionary = variant.get("puzzle", {})
	var batteries: Array = puzzle.get("batteries", [])
	for i in batteries.size():
		place_pickup_state(mc, "battery_%d" % i, "battery", batteries[i])
	var files: Array = puzzle.get("files", [])
	for id in SchoolRules.FILE_IDS:
		seed_state(mc, id, {"taken": false, "active": files.has(id)})


func on_flag(mc: MatchController, flag: String) -> void:
	if flag == "doors_open" and _chain:
		_chain.visible = false
	if flag == "chimes_solved" and mc.is_authority:
		var office: DoorEntity = mc.entities.get("door_office") as DoorEntity
		if office and office.is_locked():
			office.force_unlock(true)


func authority_tick(mc: MatchController, delta: float) -> void:
	var uses := int((mc.state.entities.get("pa_console", {}) as Dictionary).get("uses", 0))
	if uses > _pa_uses_seen:
		_pa_uses_seen = uses
		_tune_queue.clear()
		var tune: Array = mc.puzzle().get("tune", [])
		for i in tune.size():
			_tune_queue.append([TUNE_LEAD + i * TUNE_STEP, int(tune[i])])
	if _tune_queue.is_empty():
		return
	for item: Array in _tune_queue:
		item[0] = float(item[0]) - delta
	while not _tune_queue.is_empty() and float(_tune_queue[0][0]) <= 0.0:
		var bar := int(_tune_queue.pop_front()[1])
		for sp in SPEAKERS:
			mc.world_sound("chime_%d" % bar, sp, 2.0, 30.0)
		# The PA carries through the school: whatever listens comes looking.
		mc.emit_noise(SPEAKERS[1], 14.0, "pa")


## Batch name for geometry around (x, z): 16 m bands north/south of the
## corridor's middle, small enough to stay under the 8-lamps-per-mesh limit.
static func _band(x: float, z: float) -> String:
	return "walls_%s_%d" % ["n" if z <= 16.5 else "s", int(x / 16.0)]


static func _doorway(a: float, b: float) -> Dictionary:
	return {"from": a, "to": b, "top": DOOR_TOP}


static func _win(a: float, b: float) -> Dictionary:
	return {"from": a, "to": b, "bottom": WIN_BOTTOM, "top": WIN_TOP}
