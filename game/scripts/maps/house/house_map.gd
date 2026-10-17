extends MapBase
## Map 1 — The Abandoned House ("METHOD Field Site 01").
##
## Layout (meters, +X east, +Z south, ground floor y=0, basement y=-3.2):
##   Kitchen  x0-8   z0-7   | Dining x8-14 z0-7  | Garage x14-24 z0-10 (exit north)
##   Hallway  x0-14  z7-10
##   Living   x0-6   z10-18 | Foyer x6-10 z10-18 | Study x10-14 z10-18 (locked)
##   Utility  x14-21 z10-18 (fuse panel) | Stairwell x21-24 z10-18 (maglock)
##   Basement x12-24 z18-28 (cage x12-16 z24-28, keypad)
##   West wing x-6-0: Pantry z0-7 (off the kitchen) | Bathroom z7-10 | Nursery
##   z10-18 (off the living room) — a loop back round to the hallway.

const H := 2.9
const BY := -3.2
const DOOR_TOP := 2.2
const WIN_BOTTOM := 0.95
const WIN_TOP := 2.05

var garage_door: GarageDoor


func build_level() -> void:
	prepare()
	PropFactory.rng.seed = 4242
	configure_environment(Color(0.2, 0.23, 0.3), 1.1, Color(0.03, 0.034, 0.045), 0.03)
	_rooms()
	_shell()
	_interior_walls()
	_floors_and_ceilings()
	_stairs()
	_basement()
	_west_wing()
	_outside()
	_props()
	_lighting()
	_entities()
	_spawns()
	finalize()


# --- Geometry ------------------------------------------------------------------------------


func _rooms() -> void:
	add_room("kitchen", AABB(Vector3(0, 0, 0), Vector3(8, H, 7)), "concrete")
	add_room("dining", AABB(Vector3(8, 0, 0), Vector3(6, H, 7)), "wood")
	add_room("garage", AABB(Vector3(14, 0, 0), Vector3(10, H, 10)), "concrete")
	add_room("hallway", AABB(Vector3(0, 0, 7), Vector3(14, H, 3)), "wood")
	add_room("living", AABB(Vector3(0, 0, 10), Vector3(6, H, 8)), "wood")
	add_room("foyer", AABB(Vector3(6, 0, 10), Vector3(4, H, 8)), "wood")
	add_room("study", AABB(Vector3(10, 0, 10), Vector3(4, H, 8)), "carpet")
	add_room("utility", AABB(Vector3(14, 0, 10), Vector3(7, H, 8)), "concrete")
	add_room("stairwell", AABB(Vector3(21, BY, 10), Vector3(3, H - BY, 8)), "metal")
	add_room("basement", AABB(Vector3(12, BY, 18), Vector3(12, H, 10)), "concrete")
	add_room("pantry", AABB(Vector3(-6, 0, 0), Vector3(6, H, 7)), "concrete")
	add_room("bathroom", AABB(Vector3(-6, 0, 7), Vector3(6, H, 3)), "concrete")
	add_room("nursery", AABB(Vector3(-6, 0, 10), Vector3(6, H, 8)), "carpet")


func _shell() -> void:
	var b := builder
	b.room = "shell"
	# North (z=0): kitchen window, dining window, garage door opening.
	b.wall_x(0, 0, 8, 0, H, "exterior", "tile_wall", [_win(3, 5)])
	b.wall_x(0, 8, 14, 0, H, "exterior", "wallpaper_green", [_win(10, 12)])
	b.wall_x(0, 14, 24, 0, H, "exterior", "blocks", [{"from": 16.0, "to": 22.0, "top": 2.6}])
	# South (z=18): living window, front door, study window, utility window.
	b.wall_x(18, 0, 6, 0, H, "wallpaper_red", "exterior", [_win(2, 4)])
	b.wall_x(18, 6, 10, 0, H, "wallpaper", "exterior", [_doorway(7.4, 8.6)])
	b.wall_x(18, 10, 14, 0, H, "dark_wood", "exterior", [_win(11.2, 12.8)])
	b.wall_x(18, 14, 21, 0, H, "plaster", "exterior", [_win(16.0, 17.5)])
	# West wing outer walls (x=-6, and its ends at z=0 / z=18).
	b.wall_z(-6, 0, 7, 0, H, "exterior", "plaster", [_win(1.8, 3.2)])
	b.wall_z(-6, 7, 10, 0, H, "exterior", "tile_wall")
	b.wall_z(-6, 10, 18, 0, H, "exterior", "wallpaper_green", [_win(11.6, 13.2)])
	b.wall_x(0, -6, 0, 0, H, "exterior", "plaster")
	b.wall_x(18, -6, 0, 0, H, "wallpaper_green", "exterior")
	# x=0: the house's old west wall, now opening into the wing.
	b.wall_z(0, 0, 7, 0, H, "plaster", "tile_wall", [_doorway(2.9, 4.1)])
	b.wall_z(0, 7, 10, 0, H, "tile_wall", "wallpaper")
	b.wall_z(0, 10, 18, 0, H, "wallpaper_green", "wallpaper_red", [_doorway(13.4, 14.6)])
	# East (x=24)
	b.wall_z(24, 0, 10, 0, H, "blocks", "exterior")
	b.wall_z(24, 10, 18, BY, H - BY, "plaster", "exterior")


func _interior_walls() -> void:
	var b := builder
	b.room = "interior"
	b.wall_x(7, 0, 8, 0, H, "tile_wall", "wallpaper", [{"from": 2.5, "to": 3.7, "top": 2.3}])
	b.wall_x(7, 8, 14, 0, H, "wallpaper_green", "wallpaper", [_doorway(10.4, 11.6)])
	b.wall_z(8, 0, 7, 0, H, "tile_wall", "wallpaper_green", [{"from": 2.8, "to": 4.2, "top": 2.3}])
	b.wall_z(14, 0, 7, 0, H, "wallpaper_green", "blocks")
	b.wall_z(14, 7, 10, 0, H, "wallpaper", "blocks", [_doorway(8.2, 9.4)])
	b.wall_z(14, 10, 18, 0, H, "dark_wood", "plaster")
	b.wall_x(10, 0, 6, 0, H, "wallpaper", "wallpaper_red", [_doorway(2.0, 3.2)])
	b.wall_x(10, 6, 10, 0, H, "wallpaper", "wallpaper", [{"from": 7.2, "to": 8.8, "top": 2.35}])
	b.wall_x(10, 10, 14, 0, H, "wallpaper", "dark_wood", [_doorway(11.4, 12.6)])
	b.wall_x(10, 14, 21, 0, H, "blocks", "plaster", [_doorway(15.4, 16.6)])
	b.wall_x(10, 21, 24, BY, H - BY, "blocks", "plaster")
	b.wall_z(6, 10, 18, 0, H, "wallpaper_red", "wallpaper", [{"from": 14.0, "to": 15.4, "top": 2.3}])
	b.wall_z(10, 10, 18, 0, H, "wallpaper", "dark_wood")
	# Utility | stairwell, full pit height, maglocked door at the top landing.
	b.wall_z(
		21, 10, 18, BY, H - BY, "plaster", "plaster", [{"from": 10.3, "to": 11.4, "bottom": -BY, "top": -BY + DOOR_TOP}]
	)
	# Stairwell south wall continues down to the basement opening.
	b.wall_x(18, 21, 24, BY, H - BY, "plaster", "concrete", [{"from": 21.5, "to": 23.5, "top": 2.3}])


func _floors_and_ceilings() -> void:
	var b := builder
	var floors := [
		["kitchen", 0, 0, 8, 7, "tile"],
		["dining", 8, 0, 14, 7, "wood_floor"],
		["garage", 14, 0, 24, 10, "concrete_floor"],
		["hallway", 0, 7, 14, 10, "wood_floor"],
		["living", 0, 10, 6, 18, "wood_floor"],
		["foyer", 6, 10, 10, 18, "wood_floor"],
		["study", 10, 10, 14, 18, "carpet"],
		["utility", 14, 10, 21, 18, "concrete_floor"],
	]
	for f in floors:
		b.room = f[0]
		b.floor_rect(f[1], f[2], f[3], f[4], 0.0, f[5])
		b.ceiling_rect(f[1], f[2], f[3], f[4], H, "concrete" if f[0] == "garage" else "ceiling")
	b.room = "stairwell"
	b.floor_rect(21, 10, 24, 11.4, 0.0, "concrete_floor")
	b.ceiling_rect(21, 10, 24, 18, H, "ceiling")
	b.floor_rect(21, 11.4, 24, 18, BY, "concrete_floor")


func _stairs() -> void:
	builder.room = "stairwell"
	builder.stairs_z(21.08, 23.92, 11.4, 17.0, 0.0, BY, 16, "dark_wood", BY)
	# Handrail along the open side.
	PropFactory.pipe_run(builder, Vector3(23.75, 0.95, 11.4), Vector3(23.75, BY + 0.95, 17.0), 0.025, "metal")


func _basement() -> void:
	var b := builder
	b.room = "basement"
	b.floor_rect(12, 18, 24, 28, BY, "concrete_floor")
	b.ceiling_rect(12, 17.9, 24, 28, -0.3, "concrete")
	b.wall_z(12, 18, 28, BY, H, "concrete", "concrete")
	b.wall_z(24, 18, 28, BY, H, "concrete", "concrete")
	b.wall_x(28, 12, 24, BY, H, "concrete", "concrete")
	b.wall_x(18, 12, 21, BY, H, "concrete", "concrete")
	# Storage cage: chain-link fence along z=24 (gate gap) and x=16.
	_fence_x(24.0, 12.0, 13.6)
	_fence_x(24.0, 14.8, 16.0)
	_fence_z(16.0, 24.0, 28.0)
	# Pipes under the ceiling.
	PropFactory.pipe_run(b, Vector3(12.3, -0.55, 18.5), Vector3(23.7, -0.55, 18.5), 0.07)
	PropFactory.pipe_run(b, Vector3(12.3, -0.75, 19.0), Vector3(23.7, -0.75, 19.0), 0.045, "metal")
	PropFactory.pipe_run(b, Vector3(22.5, -0.55, 18.5), Vector3(22.5, -0.55, 27.5), 0.07)
	PropFactory.pipe_run(b, Vector3(17.0, -0.6, 19.0), Vector3(17.0, -0.6, 27.6), 0.05)


func _west_wing() -> void:
	var b := builder
	b.room = "interior"
	b.wall_x(7, -6, 0, 0, H, "plaster", "tile_wall", [_doorway(-3.6, -2.4)])
	b.wall_x(10, -6, 0, 0, H, "tile_wall", "wallpaper_green", [{"from": -3.6, "to": -2.4, "top": 2.3}])
	for f in [["pantry", 0, 7, "linoleum"], ["bathroom", 7, 10, "tile"], ["nursery", 10, 18, "carpet"]]:
		b.room = f[0]
		b.floor_rect(-6, f[1], 0, f[2], 0.0, f[3])
		b.ceiling_rect(-6, f[1], 0, f[2], H, "ceiling")
	# Pantry: shelves of tins, a chest freezer, sacks.
	b.room = "pantry"
	PropFactory.shelf(b, Vector3(-5.75, 0, 4.6), 90, 1.8, 2.0)
	PropFactory.shelf(b, Vector3(-3.2, 0, 0.25), 0, 1.6, 2.0)
	PropFactory.part(b, Vector3(-1.2, 0, 0.5), 0, Vector3(0, 0.45, 0), Vector3(1.3, 0.9, 0.7), "painted_wood", true)
	PropFactory.part(b, Vector3(-1.2, 0, 0.5), 0, Vector3(0, 0.92, 0), Vector3(1.32, 0.04, 0.72), "metal")
	PropFactory.crate(b, Vector3(-5.2, 0, 6.3), Vector3(0.7, 0.5, 0.6), 15)
	PropFactory.crate(b, Vector3(-4.4, 0, 6.4), Vector3(0.6, 0.4, 0.5), -10, "fabric")
	PropFactory.debris(b, Vector3(-3, 0, 4), 1.6, 6)
	# Bathroom: tub, toilet, sink cabinet and a cracked mirror.
	b.room = "bathroom"
	PropFactory.part(b, Vector3(-5.1, 0, 7.5), 0, Vector3(0, 0.28, 0), Vector3(1.6, 0.56, 0.75), "tile", true)
	PropFactory.part(b, Vector3(-5.1, 0, 7.5), 0, Vector3(0, 0.5, 0), Vector3(1.4, 0.1, 0.55), "metal_dark")
	PropFactory.part(b, Vector3(-0.5, 0, 7.45), 0, Vector3(0, 0.22, 0), Vector3(0.4, 0.44, 0.55), "tile", true)
	PropFactory.part(b, Vector3(-0.5, 0, 7.45), 0, Vector3(0, 0.62, -0.2), Vector3(0.45, 0.4, 0.18), "tile")
	PropFactory.cabinet(b, Vector3(-1.4, 0, 9.65), 180, 0.8, 0.8, 0.45, "painted_wood")
	PropFactory.picture(b, Vector3(-1.4, 1.55, 9.9), 180, 0.6, 0.7, 7.0)
	# Nursery: crib, rocking chair, toy shelf, a rug.
	b.room = "nursery"
	var crib := Vector3(-3.4, 0, 17.3)
	PropFactory.part(b, crib, 0, Vector3(0, 0.35, 0), Vector3(1.3, 0.06, 0.7), "painted_wood", true)
	for i in 12:
		var x := -0.62 + i * 0.113
		for z in [-0.33, 0.33]:
			PropFactory.part(b, crib, 0, Vector3(x, 0.6, z), Vector3(0.025, 0.5, 0.025), "painted_wood")
	for z in [-0.33, 0.33]:
		PropFactory.part(b, crib, 0, Vector3(0, 0.86, z), Vector3(1.3, 0.04, 0.05), "painted_wood")
	PropFactory.part(b, crib, 0, Vector3(0, 0.42, 0), Vector3(1.2, 0.08, 0.6), "fabric_blue")
	PropFactory.armchair(b, Vector3(-1.3, 0, 16.6), 225)
	PropFactory.shelf(b, Vector3(-0.25, 0, 11.6), -90, 1.4, 1.6)
	PropFactory.rug(b, Vector3(-3, 0, 14), Vector2(2.6, 2.0))
	PropFactory.debris(b, Vector3(-3.5, 0, 12.5), 1.4, 5)
	var words := Label3D.new()
	words.text = "SHE IS NOT\nHIS MOTHER"
	words.font_size = 40
	words.pixel_size = 0.0024
	words.modulate = Color(0.38, 0.05, 0.04)
	words.shaded = true
	words.position = Vector3(-3.4, 1.75, 17.91)
	words.rotation.y = PI
	lights_root.add_child(words)


func _fence_x(z: float, x0: float, x1: float) -> void:
	var b := builder
	var h := 2.4
	b.box(Vector3((x0 + x1) * 0.5, BY + h * 0.5, z), Vector3(x1 - x0, h, 0.05), "metal_dark", true, 0)
	var n := int((x1 - x0) / 0.12)
	for i in n + 1:
		b.box(
			Vector3(x0 + i * (x1 - x0) / maxf(n, 1), BY + h * 0.5, z),
			Vector3(0.012, h, 0.012),
			"metal_dark",
			false,
			GeoBuilder.FACE_ALL,
			Basis.IDENTITY,
			false
		)
	for y in [0.05, 1.2, h - 0.03]:
		b.box(Vector3((x0 + x1) * 0.5, BY + y, z), Vector3(x1 - x0, 0.04, 0.04), "metal", false)


func _fence_z(x: float, z0: float, z1: float) -> void:
	var b := builder
	var h := 2.4
	b.box(Vector3(x, BY + h * 0.5, (z0 + z1) * 0.5), Vector3(0.05, h, z1 - z0), "metal_dark", true, 0)
	var n := int((z1 - z0) / 0.12)
	for i in n + 1:
		b.box(
			Vector3(x, BY + h * 0.5, z0 + i * (z1 - z0) / maxf(n, 1)),
			Vector3(0.012, h, 0.012),
			"metal_dark",
			false,
			GeoBuilder.FACE_ALL,
			Basis.IDENTITY,
			false
		)
	for y in [0.05, 1.2, h - 0.03]:
		b.box(Vector3(x, BY + y, (z0 + z1) * 0.5), Vector3(0.04, 0.04, z1 - z0), "metal", false)


func _outside() -> void:
	var b := builder
	b.room = "outside"
	b.floor_rect(-12, -16, 30, 0, 0.0, "ground", 0.3)
	b.floor_rect(-12, 18, 30, 30, 0.0, "ground", 0.3)
	b.floor_rect(-12, 0, -6, 18, 0.0, "ground", 0.3)
	b.floor_rect(24, 0, 30, 18, 0.0, "ground", 0.3)
	# Invisible boundary around the driveway.
	for wall in [
		[Vector3(12, 1.5, -10), Vector3(0.2, 3, 20)],
		[Vector3(26, 1.5, -10), Vector3(0.2, 3, 20)],
		[Vector3(19, 1.5, -12), Vector3(14, 3, 0.2)]
	]:
		b.collider(wall[0], wall[1])
	# Driveway, hedges and a distant gate: silhouettes against the night.
	b.box(Vector3(19, 0.01, -5), Vector3(6.5, 0.02, 10), "concrete_floor", false, GeoBuilder.FACE_PY)
	for x in [13.0, 25.0]:
		b.box(Vector3(x, 0.8, -6), Vector3(1.2, 1.6, 12), "fabric", false)
	for i in 9:
		b.box(Vector3(14 + i * 1.25, 0.9, -11.5), Vector3(0.08, 1.8, 0.08), "metal_dark", false)
	b.box(Vector3(19, 1.75, -11.5), Vector3(11, 0.06, 0.06), "metal_dark", false)
	b.box(Vector3(19, 0.25, -11.5), Vector3(11, 0.06, 0.06), "metal_dark", false)


# --- Props ----------------------------------------------------------------------------------


func _props() -> void:
	var b := builder
	# Kitchen
	b.room = "kitchen"
	PropFactory.counter(b, Vector3(2.4, 0, 0.42), 0, 4.2, true)
	PropFactory.stove(b, Vector3(5.0, 0, 0.45), 0)
	PropFactory.fridge(b, Vector3(7.4, 0, 0.5), 0)
	PropFactory.counter(b, Vector3(7.62, 0, 3.0), -90, 2.0)
	PropFactory.table(b, Vector3(4.0, 0, 4.5), 0, 1.4, 0.9)
	PropFactory.chair(b, Vector3(3.3, 0, 3.7), 0)
	PropFactory.chair(b, Vector3(4.8, 0, 5.4), 180)
	PropFactory.chair(b, Vector3(5.3, 0, 3.6), 0, true)
	PropFactory.debris(b, Vector3(4, 0, 3), 2.5, 10)
	# Dining
	b.room = "dining"
	PropFactory.table(b, Vector3(11, 0, 3.5), 90, 2.4, 1.1)
	for z in [2.6, 3.5, 4.4]:
		PropFactory.chair(b, Vector3(10.2, 0, z), -90)
		PropFactory.chair(b, Vector3(11.8, 0, z), 90)
	PropFactory.cabinet(b, Vector3(13.55, 0, 5.8), -90, 1.6, 0.9, 0.5)
	PropFactory.picture(b, Vector3(11, 1.7, 0.1), 0, 1.0, 0.7, 4.0)
	PropFactory.rug(b, Vector3(11, 0, 3.5), Vector2(3.0, 4.0))
	# Hallway
	b.room = "hallway"
	PropFactory.cabinet(b, Vector3(5.0, 0, 7.3), 0, 1.2, 0.8, 0.35)
	PropFactory.clock(b, Vector3(13.6, 0, 8.0), -90)
	PropFactory.picture(b, Vector3(8.5, 1.6, 9.9), 180, 0.6, 0.8, -6.0)
	PropFactory.picture(b, Vector3(1.0, 1.7, 7.1), 0, 0.5, 0.6, 3.0)
	PropFactory.radiator(b, Vector3(5.2, 0, 9.8), 180, 1.0)
	# Living
	b.room = "living"
	PropFactory.fireplace(b, Vector3(0.28, 0, 11.6), 90)
	PropFactory.sofa(b, Vector3(3.2, 0, 13.2), 180, 2.2)
	PropFactory.armchair(b, Vector3(1.8, 0, 16.4), 45)
	PropFactory.rug(b, Vector3(3, 0, 13.5), Vector2(3.5, 2.8))
	PropFactory.shelf(b, Vector3(5.75, 0, 16.6), -90, 1.6, 2.0)
	PropFactory.table(b, Vector3(3.2, 0, 11.7), 0, 1.0, 0.5)
	PropFactory.picture(b, Vector3(3.0, 1.7, 17.9), 180, 1.2, 0.8, 2.0)
	PropFactory.debris(b, Vector3(3, 0, 15), 2.0, 8)
	# Foyer
	b.room = "foyer"
	PropFactory.cabinet(b, Vector3(9.6, 0, 16.4), -90, 0.9, 0.85, 0.4)
	PropFactory.picture(b, Vector3(6.1, 1.6, 12.5), 90, 0.7, 0.9, -3.0)
	PropFactory.rug(b, Vector3(8, 0, 15.5), Vector2(1.8, 3.0))
	# Study
	b.room = "study"
	PropFactory.table(b, Vector3(12.3, 0, 12.0), 0, 1.6, 0.8, "dark_wood")
	PropFactory.chair(b, Vector3(12.3, 0, 12.8), 180)
	PropFactory.shelf(b, Vector3(13.75, 0, 15.0), -90, 1.8, 2.2)
	PropFactory.shelf(b, Vector3(10.3, 0, 13.0), 90, 1.4, 2.2)
	PropFactory.debris(b, Vector3(12, 0, 15), 1.4, 9)
	# Garage
	b.room = "garage"
	PropFactory.covered_car(b, Vector3(19.2, 0, 5.8), 0)
	PropFactory.shelf(b, Vector3(14.3, 0, 3.4), 90, 1.8, 2.0, 0.45, "metal_dark")
	PropFactory.workbench(b, Vector3(23.55, 0, 5.0), -90)
	PropFactory.crate(b, Vector3(22.6, 0, 8.6), Vector3(0.8, 0.6, 0.8), 10)
	PropFactory.crate(b, Vector3(22.7, 0.6, 8.5), Vector3(0.6, 0.5, 0.6), -8)
	# Kept clear of the hallway and utility doors (it used to block both).
	PropFactory.crate(b, Vector3(21.6, 0, 9.4), Vector3(0.9, 0.7, 0.7), 4)
	# Utility
	b.room = "utility"
	PropFactory.washer(b, Vector3(17.2, 0, 17.55), 180)
	PropFactory.washer(b, Vector3(17.95, 0, 17.55), 180)
	PropFactory.shelf(b, Vector3(20.6, 0, 14.0), -90, 1.6, 2.0, 0.4, "metal_dark")
	PropFactory.crate(b, Vector3(15.0, 0, 16.9), Vector3(0.7, 0.5, 0.7))
	PropFactory.pipe_run(b, Vector3(14.3, 2.6, 10.5), Vector3(20.7, 2.6, 10.5), 0.05)
	# Basement
	b.room = "basement"
	PropFactory.boiler(b, Vector3(22.6, BY, 26.4))
	PropFactory.shelf(b, Vector3(18.0, BY, 27.6), 180, 1.8, 2.0, 0.45, "metal_dark")
	PropFactory.shelf(b, Vector3(12.3, BY, 21.0), 90, 1.8, 2.0, 0.45, "metal_dark")
	PropFactory.shelf(b, Vector3(13.0, BY, 27.6), 180, 1.4, 2.0, 0.4, "metal_dark")
	PropFactory.crate(b, Vector3(19.5, BY, 22.0), Vector3(1.0, 0.8, 0.8), 12)
	PropFactory.crate(b, Vector3(20.6, BY, 22.3), Vector3(0.7, 0.6, 0.7), -20)
	PropFactory.crate(b, Vector3(14.0, BY, 19.2), Vector3(0.9, 0.7, 0.9))
	PropFactory.table(b, Vector3(17.2, BY, 20.0), 0, 1.6, 0.8)
	PropFactory.debris(b, Vector3(18, BY, 23), 3.0, 10)
	# Window boards (and the backing that hides the void outside).
	b.room = "shell"
	for w in [
		[Vector3(4, 1.5, 0), true],
		[Vector3(11, 1.5, 0), true],
		[Vector3(3, 1.5, 18), true],
		[Vector3(12, 1.5, 18), true],
		[Vector3(16.75, 1.5, 18), true],
		[Vector3(-6, 1.5, 2.5), false],
		[Vector3(-6, 1.5, 12.4), false]
	]:
		var p: Vector3 = w[0]
		var axis_x: bool = w[1]
		var inward := Vector3(0, 0, 0.02) if p.z == 0 else (Vector3(0, 0, -0.02) if axis_x else Vector3(0.02, 0, 0))
		PropFactory.boarded_window(b, p + inward, 2.0 if axis_x else 1.6, 1.1, axis_x)
	# METHOD signage in the hallway: environmental storytelling.
	var sign_label := Label3D.new()
	sign_label.text = "METHOD  —  FIELD SITE 01\nOBSERVATION IN PROGRESS · DO NOT ENGAGE"
	sign_label.font_size = 34
	sign_label.pixel_size = 0.0022
	sign_label.modulate = Color(0.62, 0.1, 0.08)
	sign_label.shaded = true
	sign_label.position = Vector3(7.0, 2.25, 9.9)
	sign_label.rotation.y = PI
	lights_root.add_child(sign_label)
	var stencil := Label3D.new()
	stencil.text = "SUBJECT 07 — CARETAKER\nPERCEPTION TRIAL: ONGOING"
	stencil.font_size = 30
	stencil.pixel_size = 0.0022
	stencil.modulate = Color(0.55, 0.52, 0.47)
	stencil.shaded = true
	stencil.position = Vector3(23.9, BY + 2.0, 20.5)
	stencil.rotation.y = -PI / 2
	lights_root.add_child(stencil)


# --- Lighting --------------------------------------------------------------------------------


func _lighting() -> void:
	var lamp_points := [
		["kitchen", Vector3(4, H, 3.5)],
		["dining", Vector3(11, H, 3.5)],
		["hallway", Vector3(3.5, H, 8.5)],
		["hallway", Vector3(10.5, H, 8.5)],
		["living", Vector3(3, H, 14)],
		["foyer", Vector3(8, H, 14)],
		["study", Vector3(12, H, 14.5)],
		["utility", Vector3(17.5, H, 14)],
		["garage", Vector3(19, H, 3)],
		["garage", Vector3(17, H, 8.5)],
		["stairwell", Vector3(22.5, H, 11)],
		["basement", Vector3(16, -0.3, 21)],
		["basement", Vector3(21, -0.3, 25)],
		["basement", Vector3(14, -0.3, 26)],
		["pantry", Vector3(-3, H, 3.5)],
		["bathroom", Vector3(-2.2, H, 8.5)],
		["nursery", Vector3(-3, H, 14)],
	]
	for lp in lamp_points:
		var top: Vector3 = lp[1]
		builder.room = "fixtures"
		PropFactory.lamp_fixture(builder, top)
		var shadows: bool = lp[0] in ["hallway", "basement"]
		add_lamp(top + Vector3(0, -0.55, 0), lp[0], 1.3, Color(1.0, 0.78, 0.55), true, shadows)
	# METHOD emergency lighting: dim crimson, battery-backed, guides the way.
	add_lamp(Vector3(14.4, 2.4, 13.0), "utility", 0.9, Color(0.9, 0.12, 0.08), false, false, 5.0)
	add_lamp(Vector3(15.0, 2.4, 1.0), "garage", 0.8, Color(0.9, 0.12, 0.08), false, false, 6.0)
	add_lamp(Vector3(7.0, 2.5, 7.4), "hallway", 0.5, Color(0.9, 0.12, 0.08), false, false, 4.5)
	# The caretaker's oil lamp, still burning in the foyer.
	add_lamp(Vector3(9.55, 1.0, 16.4), "foyer", 0.9, Color(1.0, 0.62, 0.3), false, true, 5.0)
	add_moonlight(Vector3(4, 2.2, -1.5), Vector3(4, 0, 2.5))
	add_moonlight(Vector3(3, 2.2, 19.5), Vector3(3, 0, 15.5))
	add_moonlight(Vector3(12, 2.2, 19.5), Vector3(12, 0, 15.5), 1.2)
	add_moonlight(Vector3(-7.5, 2.2, 12.4), Vector3(-3.5, 0, 12.4), 1.2)
	add_moonlight(Vector3(-7.5, 2.2, 2.5), Vector3(-3.5, 0, 2.5), 1.0)
	# A child's night light that never needed the mains.
	add_lamp(Vector3(-0.4, 0.35, 15.6), "nursery", 0.35, Color(0.95, 0.35, 0.3), false, false, 3.0)
	var outside := OmniLight3D.new()
	outside.light_color = Color(0.5, 0.6, 0.85)
	outside.light_energy = 1.4
	outside.omni_range = 16.0
	outside.position = Vector3(19, 4.5, -8)
	lights_root.add_child(outside)
	add_dust(AABB(Vector3(0, 0, 0), Vector3(14, H, 10)), 80)
	add_dust(AABB(Vector3(12, BY, 18), Vector3(12, 2.9, 10)), 50)
	add_dust(AABB(Vector3(-6, 0, 0), Vector3(6, H, 18)), 40)
	apply_graphics_settings()


# --- Entities ----------------------------------------------------------------------------


func _entities() -> void:
	# Doors (node origin = hinge, panel extends along local +X).
	_door("door_dining", Vector3(10.4, 0, 7), 0, 1.2)
	_door("door_living", Vector3(2.0, 0, 10), 0, 1.2)
	_door("door_study", Vector3(11.4, 0, 10), 0, 1.2, "item:study_key", "DOOR_LOCKED_KEY", {"material": "dark_wood"})
	_door("door_garage", Vector3(14, 0, 8.2), -90, 1.2)
	_door("door_utility", Vector3(15.4, 0, 10), 0, 1.2)
	_door("door_basement", Vector3(21, 0, 10.3), -90, 1.1, "flag:power_on", "DOOR_MAGLOCK", {"material": "metal_dark"})
	_door(
		"door_front", Vector3(7.4, 0, 18), 0, 1.2, "chained", "DOOR_CHAINED", {"try_flag": "exit_found", "swing": -1.0}
	)
	_door("door_pantry", Vector3(0, 0, 2.9), -90, 1.2)
	_door("door_nursery", Vector3(0, 0, 13.4), -90, 1.2, "", "DOOR_LOCKED", {"material": "painted_wood"})
	_door("door_bathroom", Vector3(-3.6, 0, 7), 0, 1.2)
	_door("cage_gate", Vector3(13.6, BY, 24), 0, 1.2, "external", "CAGE_LOCKED", {"style": "cage", "height": 2.3})

	var panel := FusePanel.new()
	panel.entity_id = "fuse_panel"
	add_entity(panel, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(14.1, 1.45, 13.0)))
	var keypad := KeypadEntity.new()
	keypad.entity_id = "keypad"
	keypad.target_door = "cage_gate"
	add_entity(keypad, Transform3D(Basis(Vector3.UP, PI), Vector3(15.3, BY + 1.35, 23.95)))
	var bench := WorkbenchEntity.new()
	bench.entity_id = "workbench"
	add_entity(bench, Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(23.55, 0, 5.0)))
	var motor := GarageMotor.new()
	motor.entity_id = "garage_motor"
	add_entity(motor, Transform3D(Basis.IDENTITY, Vector3(15.1, 1.3, 0.35)))
	garage_door = GarageDoor.new()
	garage_door.entity_id = "garage_door"
	garage_door.open_seconds = _door_seconds()
	add_entity(garage_door, Transform3D(Basis.IDENTITY, Vector3(19, 0, 0)))
	var zone := EscapeZone.new()
	zone.match_ctrl = match_ctrl
	zone.position = Vector3(19, 1.0, -5.5)
	zone.setup_box(Vector3(10, 2.5, 6))
	add_child(zone)

	# Painted clues (values seeded in apply_variant).
	_clue("clue_kitchen", Vector3(7.91, 1.65, 5.6), -90)
	_clue("clue_living", Vector3(0.09, 2.15, 11.6), 90)
	_clue("clue_garage", Vector3(14.09, 1.75, 1.6), 90)
	_clue("clue_basement", Vector3(23.91, BY + 1.7, 21.5), -90)

	# Notes, tape, collectibles.
	_note("note_welcome", Vector3(9.45, 0.86, 16.0), "NOTE_WELCOME_T", "NOTE_WELCOME_B", "paper", 0)
	_note("note_breaker", Vector3(0.09, 1.5, 5.2), "NOTE_BREAKER_T", "NOTE_BREAKER_B", "wall", 90)
	_note("note_diary", Vector3(10.8, 0.77, 2.8), "NOTE_DIARY_T", "NOTE_DIARY_B", "paper", 20)
	_note("note_keypad", Vector3(17.0, BY + 0.77, 20.1), "NOTE_KEYPAD_T", "NOTE_KEYPAD_B", "clipboard", 0)
	_note("note_study", Vector3(11.8, 0.77, 11.8), "NOTE_STUDY_T", "NOTE_STUDY_B", "paper", -10)
	_note("note_nursery", Vector3(-1.4, 0.84, 9.6), "NOTE_NURSERY_T", "NOTE_NURSERY_B", "paper", 170)
	_note("note_garage", Vector3(23.2, 0.93, 5.6), "NOTE_GARAGE_T", "NOTE_GARAGE_B", "clipboard", -90)
	var tape := TapeRecorder.new()
	tape.entity_id = "tape_study"
	tape.line_keys = ["TAPE_HOUSE_1", "TAPE_HOUSE_2", "TAPE_HOUSE_3", "TAPE_HOUSE_4"]
	add_entity(tape, Transform3D(Basis(Vector3.UP, 0.3), Vector3(12.8, 0.81, 12.0)))
	var files := {
		"file_kitchen": Vector3(6.9, 0.93, 0.45),
		"file_living": Vector3(3.2, 0.77, 11.7),
		"file_study": Vector3(13.6, 1.12, 15.4),
		"file_garage": Vector3(22.6, 0.61, 8.6),
		"file_utility": Vector3(17.95, 0.91, 17.55),
		"file_basement": Vector3(14.0, BY + 0.71, 19.2),
	}
	for id in files:
		var c := CollectibleEntity.new()
		c.entity_id = id
		c.collectible_id = "house_" + str(id).substr(5)
		add_entity(c, Transform3D(Basis(Vector3.UP, randf() * 0.6), files[id]))

	# Hiding spots.
	_hide("hide_pantry", Vector3(0.45, 0, 1.4), 90, "locker")
	_hide("hide_garage", Vector3(14.45, 0, 6.2), 90, "locker")
	_hide("hide_living", Vector3(0.5, 0, 16.6), 90, "wardrobe")
	_hide("hide_study", Vector3(10.7, 0, 17.55), 180, "wardrobe")
	_hide("hide_utility", Vector3(20.4, 0, 17.55), 180, "locker")
	_hide("hide_basement", Vector3(23.55, BY, 23.6), -90, "locker")
	_hide("hide_nursery", Vector3(-5.5, 0, 15.4), 90, "wardrobe")
	_hide("hide_pantry_back", Vector3(-5.55, 0, 1.2), 90, "locker")

	# Light switches next to doorways.
	_switch("switch_kitchen", "kitchen", Vector3(2.3, 1.3, 6.91), 180)
	_switch("switch_dining", "dining", Vector3(10.2, 1.3, 6.91), 180)
	_switch("switch_living", "living", Vector3(3.4, 1.3, 10.09), 0)
	_switch("switch_study", "study", Vector3(12.8, 1.3, 10.09), 0)

	var drawer := DrawerEntity.new()
	drawer.entity_id = "drawer_kitchen"
	add_entity(drawer, Transform3D(Basis.IDENTITY, Vector3(1.0, 0.68, 0.52)))


func _door_seconds() -> float:
	match String(match_ctrl.difficulty.id):
		"story":
			return 30.0
		"hard":
			return 45.0
		"nightmare":
			return 50.0
	return 40.0


## `props` are applied before the door enters the tree (its visuals and
## collision are built in `_ready`).
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


func _clue(id: String, pos: Vector3, rot_deg: float) -> void:
	var c := ClueMark.new()
	c.entity_id = id
	add_entity(c, Transform3D(Basis(Vector3.UP, deg_to_rad(rot_deg)), pos))


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


func _switch(id: String, room: String, pos: Vector3, rot_deg: float) -> void:
	var s := LightSwitch.new()
	s.entity_id = id
	s.room = room
	add_entity(s, Transform3D(Basis(Vector3.UP, deg_to_rad(rot_deg)), pos))


# --- Spawns / navigation hints ------------------------------------------------------------


func _spawns() -> void:
	player_spawns = [
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(8.0, 0.05, 15.6)),
		Transform3D(Basis(Vector3.UP, 0.3), Vector3(7.2, 0.05, 15.0)),
		Transform3D(Basis(Vector3.UP, -0.3), Vector3(8.8, 0.05, 15.0)),
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(7.4, 0.05, 13.6)),
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(8.6, 0.05, 13.6)),
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(8.0, 0.05, 12.4)),
	]
	enemy_spawns = [
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(8.0, 0.05, 17.0)),
		Transform3D(Basis(Vector3.UP, PI), Vector3(21.5, 0.05, 1.5)),
		Transform3D(Basis(Vector3.UP, PI / 2), Vector3(1.2, 0.05, 3.0)),
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(12.0, 0.05, 1.2)),
	]
	patrol_points = [
		Vector3(4, 0, 3.5),
		Vector3(11, 0, 5.6),
		Vector3(3, 0, 8.5),
		Vector3(11, 0, 8.5),
		Vector3(3, 0, 15),
		Vector3(8, 0, 12.5),
		Vector3(12, 0, 15),
		Vector3(17, 0, 8),
		Vector3(22, 0, 2.5),
		Vector3(17.5, 0, 14),
		Vector3(22.5, 0, 10.7),
		Vector3(16, BY, 21),
		Vector3(21, BY, 21.5),
		Vector3(20, BY, 26),
		Vector3(-3, 0, 3.5),
		Vector3(-3, 0, 8.5),
		Vector3(-3, 0, 14),
	]
	prowl_points = [
		Vector3(-7.5, 0, 4),
		Vector3(-7.5, 0, 14),
		Vector3(4, 0, 19.5),
		Vector3(12, 0, 19.5),
		Vector3(18, 0, 19.5),
		Vector3(25.5, 0, 6),
		Vector3(25.5, 0, 15),
		Vector3(4, 0, -1.5),
		Vector3(11, 0, -1.5),
	]
	var spawns := {
		"sp_kitchen_table": Vector3(4.3, 0.77, 4.7),
		"sp_kitchen_counter": Vector3(1.4, 0.93, 0.5),
		"sp_dining_table": Vector3(11.2, 0.77, 3.2),
		"sp_dining_cabinet": Vector3(13.5, 0.94, 5.6),
		"sp_living_shelf": Vector3(5.7, 1.06, 16.6),
		"sp_living_sofa": Vector3(2.6, 0.52, 13.15),
		"sp_hall_table": Vector3(5.2, 0.84, 7.32),
		"sp_foyer_stand": Vector3(9.6, 0.87, 16.8),
		"sp_garage_shelf": Vector3(14.35, 0.97, 3.0),
		"sp_garage_crate": Vector3(15.4, 0.71, 8.8),
		"sp_utility_shelf": Vector3(20.65, 0.97, 14.2),
		"sp_utility_washer": Vector3(17.2, 0.91, 17.55),
		"sp_study_desk": Vector3(12.0, 0.77, 12.2),
		"sp_study_shelf": Vector3(13.7, 1.55, 14.6),
		"sp_base_shelf_a": Vector3(18.2, BY + 0.97, 27.6),
		"sp_base_shelf_b": Vector3(12.35, BY + 1.45, 21.3),
		"sp_base_crate": Vector3(19.5, BY + 0.81, 22.0),
		"sp_base_boiler": Vector3(21.6, BY + 0.02, 25.6),
		"sp_cage_shelf": Vector3(13.0, BY + 0.97, 27.6),
		"bt_kitchen": Vector3(7.62, 0.93, 2.6),
		"bt_hall": Vector3(4.6, 0.84, 7.32),
		"bt_living": Vector3(3.6, 0.77, 11.7),
		"bt_garage": Vector3(23.2, 0.93, 4.4),
		"bt_utility": Vector3(15.0, 0.51, 16.9),
		"bt_basement": Vector3(17.6, BY + 0.77, 19.8),
		"bt_foyer": Vector3(9.6, 0.87, 16.0),
		"bt_dining": Vector3(10.7, 0.77, 4.6),
		"sp_pantry_shelf": Vector3(-5.7, 1.06, 4.6),
		"sp_pantry_freezer": Vector3(-1.2, 0.96, 0.5),
		"sp_bath_cabinet": Vector3(-1.4, 0.84, 9.65),
		"sp_nursery_crib": Vector3(-3.4, 0.47, 17.3),
		"sp_nursery_shelf": Vector3(-0.3, 0.86, 11.6),
		"bt_pantry": Vector3(-3.2, 1.06, 0.3),
		"bt_nursery": Vector3(-1.3, 0.5, 16.6),
	}
	for id in spawns:
		add_spawn_point(id, Transform3D(Basis.IDENTITY, spawns[id]))
	add_spawn_point("sp_kitchen_drawer", Transform3D(Basis.IDENTITY, Vector3(0, -0.05, 0.02)), "drawer_kitchen")


# --- Variant / tick ----------------------------------------------------------------------------


func apply_variant(mc: MatchController, variant: Dictionary) -> void:
	if not mc.is_authority or variant.is_empty():
		return
	var placements: Dictionary = variant.get("placements", {})
	for slot in placements:
		place_pickup_state(mc, "pickup_" + str(slot), mc.rules.item_for_slot(slot), placements[slot])
	var puzzle: Dictionary = variant.get("puzzle", {})
	var batteries: Array = puzzle.get("batteries", [])
	for i in batteries.size():
		place_pickup_state(mc, "battery_%d" % i, "battery", batteries[i])
	var clue_ids: PackedStringArray = ["clue_kitchen", "clue_living", "clue_garage", "clue_basement"]
	var symbols: Array = puzzle.get("clue_symbols", [])
	var digits: Array = puzzle.get("clue_digits", [])
	for i in mini(clue_ids.size(), symbols.size()):
		seed_state(mc, clue_ids[i], {"digit": int(digits[i]), "symbol": int(symbols[i])})
	seed_state(mc, "keypad", {"solved": false, "order": puzzle.get("keypad_order", [])})
	seed_state(mc, "note_breaker", {"args": [FusePanel.LABELS[int(puzzle.get("faulty_socket", 0))]]})
	var files: Array = puzzle.get("files", [])
	for id in ["file_kitchen", "file_living", "file_study", "file_garage", "file_utility", "file_basement"]:
		seed_state(mc, id, {"taken": false, "active": files.has(id)})


func authority_tick(_match: MatchController, delta: float) -> void:
	if garage_door:
		garage_door.authority_tick(delta)


# --- Helpers -------------------------------------------------------------------------------------


static func _win(a: float, b: float) -> Dictionary:
	return {"from": a, "to": b, "bottom": WIN_BOTTOM, "top": WIN_TOP}


static func _doorway(a: float, b: float) -> Dictionary:
	return {"from": a, "to": b, "top": DOOR_TOP}
