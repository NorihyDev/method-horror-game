extends MapBase
## Map 2 — The Black Ward ("METHOD Clinical Annex 02").
##
## Layout (meters, +X east, +Z south, one floor, ceiling H):
##   Bay x0-8 z0-8 (shutter exit north) | Reception x8-16 z0-8 (start)
##   Triage x16-22 z0-8 | Maintenance x22-30 z0-8
##   Main corridor x0-30 z8-11
##   Ward x0-8 z11-24 | Generator x8-13 z11-17 | Pharmacy x8-13 z17-24
##   Staff corridor x13-16 z11-24 (staff card) | Security x16-21 z11-16 (keypad)
##   Staff room x16-21 z16-24 | Observation corridor x21-30 z11-14 (security card)
##   Observation rooms A/B/C x21-30 z14-19 | Cells x21-30 z19-24 (behind glass)
##   Morgue x0-8 z24-31 (off the ward, one way in) | Cold store x8-13 z24-31

const WardRules = preload("res://scripts/maps/ward/ward_rules.gd")
const H := 3.0
const DOOR_TOP := 2.2
const WIN_BOTTOM := 1.0
const WIN_TOP := 2.1

var shutter: GarageDoor
var monitors: Array[MonitorClue] = []


func build_level() -> void:
	prepare()
	PropFactory.rng.seed = 5151
	configure_environment(Color(0.16, 0.2, 0.2), 1.0, Color(0.02, 0.035, 0.035), 0.03)
	_rooms()
	_shell()
	_interior_walls()
	_floors_and_ceilings()
	_observation_glass()
	_outside()
	_props()
	_lighting()
	_entities()
	_spawns()
	finalize()


func set_power(on: bool) -> void:
	super.set_power(on)
	for m in monitors:
		m.set_powered(on)


# --- Geometry ------------------------------------------------------------------------------


func _rooms() -> void:
	add_room("bay", AABB(Vector3(0, 0, 0), Vector3(8, H, 8)), "concrete")
	add_room("reception", AABB(Vector3(8, 0, 0), Vector3(8, H, 8)), "concrete")
	add_room("triage", AABB(Vector3(16, 0, 0), Vector3(6, H, 8)), "concrete")
	add_room("maint", AABB(Vector3(22, 0, 0), Vector3(8, H, 8)), "concrete")
	add_room("corridor", AABB(Vector3(0, 0, 8), Vector3(30, H, 3)), "concrete")
	add_room("ward", AABB(Vector3(0, 0, 11), Vector3(8, H, 13)), "concrete")
	add_room("generator", AABB(Vector3(8, 0, 11), Vector3(5, H, 6)), "metal")
	add_room("pharmacy", AABB(Vector3(8, 0, 17), Vector3(5, H, 7)), "concrete")
	add_room("staffcorr", AABB(Vector3(13, 0, 11), Vector3(3, H, 13)), "concrete")
	add_room("security", AABB(Vector3(16, 0, 11), Vector3(5, H, 5)), "carpet")
	add_room("staffroom", AABB(Vector3(16, 0, 16), Vector3(5, H, 8)), "carpet")
	add_room("obscorr", AABB(Vector3(21, 0, 11), Vector3(9, H, 3)), "concrete")
	add_room("obs_a", AABB(Vector3(21, 0, 14), Vector3(3, H, 5)), "carpet")
	add_room("obs_b", AABB(Vector3(24, 0, 14), Vector3(3, H, 5)), "carpet")
	add_room("obs_c", AABB(Vector3(27, 0, 14), Vector3(3, H, 5)), "carpet")
	add_room("cells", AABB(Vector3(21, 0, 19), Vector3(9, H, 5)), "concrete")
	add_room("morgue", AABB(Vector3(0, 0, 24), Vector3(8, H, 7)), "concrete")
	add_room("coldstore", AABB(Vector3(8, 0, 24), Vector3(5, H, 7)), "concrete")


func _shell() -> void:
	var b := builder
	b.room = "shell"
	# North (z=0): shutter opening in the bay, windows elsewhere.
	b.wall_x(0, 0, 8, 0, H, "exterior", "concrete", [{"from": 1.5, "to": 6.5, "top": 2.8}])
	b.wall_x(0, 8, 16, 0, H, "exterior", "ward_paint", [_win(10.5, 13.0)])
	b.wall_x(0, 16, 22, 0, H, "exterior", "ward_paint", [_win(18.2, 19.8)])
	b.wall_x(0, 22, 30, 0, H, "exterior", "blocks", [_win(25.0, 27.0)])
	# South (z=24).
	b.wall_x(24, 0, 8, 0, H, "ward_paint", "tile_wall", [_win(2.0, 4.0), _doorway(5.4, 6.6)])
	b.wall_x(24, 8, 13, 0, H, "tile_wall", "tile_wall")
	# The morgue below the ward: its own outer walls.
	b.wall_x(31, 0, 13, 0, H, "tile_wall", "exterior")
	b.wall_z(0, 24, 31, 0, H, "exterior", "tile_wall")
	b.wall_z(13, 24, 31, 0, H, "tile_wall", "exterior")
	b.wall_z(8, 24, 31, 0, H, "tile_wall", "tile_wall", [_doorway(26.0, 27.2)])
	b.wall_x(24, 13, 16, 0, H, "ward_tile", "exterior")
	b.wall_x(24, 16, 21, 0, H, "ward_paint", "exterior")
	b.wall_x(24, 21, 30, 0, H, "tile_wall", "exterior")
	# West (x=0).
	b.wall_z(0, 0, 8, 0, H, "exterior", "concrete")
	b.wall_z(0, 8, 11, 0, H, "exterior", "ward_tile")
	b.wall_z(0, 11, 24, 0, H, "exterior", "ward_paint", [_win(14.0, 16.0), _win(19.0, 21.0)])
	# East (x=30).
	b.wall_z(30, 0, 8, 0, H, "blocks", "exterior")
	b.wall_z(30, 8, 14, 0, H, "ward_tile", "exterior")
	b.wall_z(30, 14, 19, 0, H, "ward_paint", "exterior")
	b.wall_z(30, 19, 24, 0, H, "tile_wall", "exterior")


func _interior_walls() -> void:
	var b := builder
	b.room = "interior"
	# Front block.
	b.wall_z(8, 0, 8, 0, H, "concrete", "ward_paint", [_doorway(3.2, 4.8)])
	b.wall_z(16, 0, 8, 0, H, "ward_paint", "ward_paint")
	b.wall_z(22, 0, 8, 0, H, "ward_paint", "blocks")
	# Corridor, north side (rooms face -Z, corridor faces +Z).
	b.wall_x(8, 0, 8, 0, H, "concrete", "ward_tile")
	b.wall_x(8, 8, 16, 0, H, "ward_paint", "ward_tile", [{"from": 11.0, "to": 13.0, "top": 2.5}])
	b.wall_x(8, 16, 22, 0, H, "ward_paint", "ward_tile", [_doorway(18.4, 19.6)])
	b.wall_x(8, 22, 30, 0, H, "blocks", "ward_tile", [_doorway(25.4, 26.6)])
	# Corridor, south side.
	b.wall_x(11, 0, 8, 0, H, "ward_tile", "ward_paint", [{"from": 3.0, "to": 5.0, "top": 2.5}])
	b.wall_x(11, 8, 13, 0, H, "ward_tile", "concrete")
	b.wall_x(11, 13, 16, 0, H, "ward_tile", "ward_tile", [_doorway(13.8, 15.2)])
	b.wall_x(11, 16, 21, 0, H, "ward_tile", "ward_paint")
	b.wall_x(11, 21, 30, 0, H, "ward_tile", "ward_tile", [_doorway(22.0, 23.4)])
	# Ward | generator & pharmacy.
	b.wall_z(8, 11, 24, 0, H, "ward_paint", "concrete")
	b.wall_x(17, 8, 13, 0, H, "concrete", "tile_wall")
	# Staff corridor sides.
	b.wall_z(13, 11, 17, 0, H, "concrete", "ward_tile", [_doorway(12.6, 13.8)])
	b.wall_z(13, 17, 24, 0, H, "tile_wall", "ward_tile", [_doorway(20.0, 21.2)])
	b.wall_z(16, 11, 16, 0, H, "ward_tile", "ward_paint", [_doorway(12.2, 13.4)])
	b.wall_z(16, 16, 24, 0, H, "ward_tile", "ward_paint", [_doorway(19.2, 20.4)])
	b.wall_x(16, 16, 21, 0, H, "ward_paint", "ward_paint")
	# Observation wing.
	b.wall_z(21, 11, 14, 0, H, "ward_paint", "ward_tile")
	b.wall_z(21, 14, 19, 0, H, "ward_paint", "ward_paint")
	b.wall_z(21, 19, 24, 0, H, "ward_paint", "tile_wall")
	b.wall_x(
		14, 21, 30, 0, H, "ward_tile", "ward_paint", [_doorway(22.2, 23.2), _doorway(25.2, 26.2), _doorway(28.2, 29.2)]
	)
	for x in [24.0, 27.0]:
		b.wall_z(x, 14, 19, 0, H, "ward_paint", "ward_paint")
		b.wall_z(x, 19, 24, 0, H, "fabric", "fabric")
	var glass_cut := []
	for x0 in [21.6, 24.6, 27.6]:
		glass_cut.append({"from": x0, "to": x0 + 1.8, "bottom": WIN_BOTTOM, "top": WIN_TOP})
	b.wall_x(19, 21, 30, 0, H, "ward_paint", "fabric", glass_cut)


func _floors_and_ceilings() -> void:
	var b := builder
	var floors := [
		["bay", 0, 0, 8, 8, "concrete_floor", "concrete"],
		["reception", 8, 0, 16, 8, "linoleum", "ceiling_panel"],
		["triage", 16, 0, 22, 8, "linoleum", "ceiling_panel"],
		["maint", 22, 0, 30, 8, "concrete_floor", "concrete"],
		["corridor", 0, 8, 30, 11, "linoleum", "ceiling_panel"],
		["ward", 0, 11, 8, 24, "linoleum", "ceiling_panel"],
		["generator", 8, 11, 13, 17, "concrete_floor", "concrete"],
		["pharmacy", 8, 17, 13, 24, "tile", "ceiling_panel"],
		["staffcorr", 13, 11, 16, 24, "linoleum", "ceiling_panel"],
		["security", 16, 11, 21, 16, "carpet", "ceiling_panel"],
		["staffroom", 16, 16, 21, 24, "carpet", "ceiling_panel"],
		["obscorr", 21, 11, 30, 14, "linoleum", "ceiling_panel"],
		["obs", 21, 14, 30, 19, "carpet", "ceiling_panel"],
		["cells", 21, 19, 30, 24, "tile", "ceiling"],
		["morgue", 0, 24, 8, 31, "tile", "ceiling_panel"],
		["coldstore", 8, 24, 13, 31, "concrete_floor", "concrete"],
	]
	for f in floors:
		b.room = f[0]
		b.floor_rect(f[1], f[2], f[3], f[4], 0.0, f[5])
		b.ceiling_rect(f[1], f[2], f[3], f[4], H, f[6])


## One-way observation glass: solid for movement, dark and reflective-looking.
func _observation_glass() -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.06, 0.08, 0.08, 0.55)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	glass.metallic = 0.6
	for x0 in [21.6, 24.6, 27.6]:
		var pane := MeshInstance3D.new()
		var m := BoxMesh.new()
		m.size = Vector3(1.8, WIN_TOP - WIN_BOTTOM, 0.03)
		pane.mesh = m
		pane.material_override = glass
		pane.position = Vector3(x0 + 0.9, (WIN_BOTTOM + WIN_TOP) * 0.5, 19.0)
		lights_root.add_child(pane)
		builder.collider(Vector3(x0 + 0.9, (WIN_BOTTOM + WIN_TOP) * 0.5, 19.0), Vector3(1.8, WIN_TOP - WIN_BOTTOM, 0.1))


func _outside() -> void:
	var b := builder
	b.room = "outside"
	b.floor_rect(-6, -14, 36, 0, 0.0, "ground", 0.3)
	b.floor_rect(-6, 31, 36, 37, 0.0, "ground", 0.3)
	b.floor_rect(13, 24, 36, 31, 0.0, "ground", 0.3)
	b.floor_rect(-6, 0, 0, 31, 0.0, "ground", 0.3)
	b.floor_rect(30, 0, 36, 24, 0.0, "ground", 0.3)
	# Invisible fence around the ambulance apron.
	for wall in [
		[Vector3(-0.5, 1.5, -6), Vector3(0.2, 3, 12)],
		[Vector3(9.0, 1.5, -6), Vector3(0.2, 3, 12)],
		[Vector3(4.25, 1.5, -11.5), Vector3(9.5, 3, 0.2)]
	]:
		b.collider(wall[0], wall[1])
	# An abandoned ambulance and the canopy over the apron.
	PropFactory.part(b, Vector3(4.0, 0, -7.5), 90, Vector3(0, 1.15, 0), Vector3(5.6, 2.1, 2.3), "painted_wood", true)
	PropFactory.part(b, Vector3(4.0, 0, -7.5), 90, Vector3(2.2, 0.75, 0), Vector3(1.4, 1.5, 2.3), "metal_dark")
	PropFactory.part(b, Vector3(4.0, 0, -7.5), 90, Vector3(0, 1.55, 1.16), Vector3(4.0, 0.3, 0.02), "subway_band")
	b.box(Vector3(4, 3.2, -2.5), Vector3(9, 0.15, 5), "metal_dark", false)
	for x in [0.3, 7.7]:
		b.box(Vector3(x, 1.6, -4.8), Vector3(0.15, 3.2, 0.15), "metal_dark", false)


# --- Props ----------------------------------------------------------------------------------


func _props() -> void:
	var b := builder
	b.room = "bay"
	PropFactory.shelf(b, Vector3(7.6, 0, 6.5), -90, 1.8, 2.0, 0.45, "metal_dark")
	FacilityProps.gurney(b, Vector3(2.0, 0, 6.5), 0)
	FacilityProps.wheelchair(b, Vector3(5.6, 0, 7.2), 200)
	PropFactory.crate(b, Vector3(0.8, 0, 1.5), Vector3(0.9, 0.7, 0.7), 8, "metal_dark")
	b.room = "reception"
	FacilityProps.reception_desk(b, Vector3(12.0, 0, 6.2), 0, 4.0)
	FacilityProps.waiting_chairs(b, Vector3(12.0, 0, 0.75), 0, 5)
	# Clear of the bay door (3.2-4.8), which they used to block.
	FacilityProps.waiting_chairs(b, Vector3(8.75, 0, 6.1), -90, 3)
	PropFactory.picture(b, Vector3(15.9, 1.7, 3.5), -90, 1.2, 0.8, 0.0)
	PropFactory.debris(b, Vector3(12, 0, 3.5), 2.5, 10)
	b.room = "triage"
	FacilityProps.hospital_bed(b, Vector3(17.5, 0, 3.0), 0, true)
	FacilityProps.hospital_bed(b, Vector3(20.3, 0, 3.0), 0)
	FacilityProps.curtain(b, Vector3(18.9, 0, 1.0), Vector3(18.9, 0, 5.2), 2.6, 0.2)
	FacilityProps.iv_stand(b, Vector3(18.4, 0, 1.6))
	PropFactory.cabinet(b, Vector3(21.6, 0, 6.2), -90, 1.0, 0.9, 0.45, "painted_wood")
	b.room = "maint"
	PropFactory.workbench(b, Vector3(29.55, 0, 3.0), -90)
	PropFactory.shelf(b, Vector3(22.4, 0, 4.0), 90, 1.8, 2.0, 0.45, "metal_dark")
	FacilityProps.locker_bank(b, Vector3(26.0, 0, 0.3), 0, 4)
	PropFactory.crate(b, Vector3(28.8, 0, 7.2), Vector3(0.8, 0.6, 0.8), 15, "metal_dark")
	PropFactory.pipe_run(b, Vector3(22.3, 2.6, 0.5), Vector3(29.7, 2.6, 0.5), 0.06)
	b.room = "corridor"
	FacilityProps.gurney(b, Vector3(5.5, 0, 9.6), 90)
	FacilityProps.wheelchair(b, Vector3(14.8, 0, 9.0), 75)
	FacilityProps.iv_stand(b, Vector3(20.5, 0, 10.5))
	PropFactory.radiator(b, Vector3(9.5, 0, 8.15), 0, 1.0)
	b.room = "ward"
	for row in [[1.45, 90.0], [6.55, -90.0]]:
		for z in [13.5, 17.0, 20.5]:
			FacilityProps.hospital_bed(b, Vector3(float(row[0]), 0, z), float(row[1]), z == 17.0)
	for z in [15.25, 18.75]:
		FacilityProps.curtain(b, Vector3(0.2, 0, z), Vector3(2.9, 0, z), 2.6, 0.1)
		FacilityProps.curtain(b, Vector3(5.1, 0, z), Vector3(7.8, 0, z), 2.6, 0.3)
	PropFactory.cabinet(b, Vector3(1.2, 0, 15.2), 90, 0.6, 0.8, 0.45, "painted_wood")
	PropFactory.cabinet(b, Vector3(6.8, 0, 22.4), -90, 0.6, 0.8, 0.45, "painted_wood")
	FacilityProps.iv_stand(b, Vector3(2.6, 0, 12.4))
	FacilityProps.iv_stand(b, Vector3(5.3, 0, 21.6))
	PropFactory.debris(b, Vector3(4, 0, 17), 2.0, 12)
	b.room = "generator"
	PropFactory.boiler(b, Vector3(11.0, 0, 15.2))
	PropFactory.shelf(b, Vector3(12.6, 0, 16.2), -90, 1.2, 2.0, 0.4, "metal_dark")
	PropFactory.pipe_run(b, Vector3(8.3, 2.5, 11.5), Vector3(12.7, 2.5, 11.5), 0.08)
	PropFactory.pipe_run(b, Vector3(11.0, 2.5, 11.5), Vector3(11.0, 2.5, 14.0), 0.08)
	b.room = "pharmacy"
	PropFactory.shelf(b, Vector3(8.4, 0, 20.5), 90, 1.8, 2.0, 0.4, "painted_wood")
	PropFactory.shelf(b, Vector3(8.4, 0, 22.5), 90, 1.6, 2.0, 0.4, "painted_wood")
	FacilityProps.medicine_fridge(b, Vector3(12.4, 0, 23.4), 180)
	PropFactory.counter(b, Vector3(10.5, 0, 17.4), 180, 2.4, true)
	b.room = "staffcorr"
	FacilityProps.locker_bank(b, Vector3(13.3, 0, 17.5), 90, 3)
	FacilityProps.iv_stand(b, Vector3(15.5, 0, 23.0))
	b.room = "security"
	PropFactory.table(b, Vector3(19.6, 0, 11.9), 0, 2.2, 0.7, "painted_wood")
	PropFactory.chair(b, Vector3(19.6, 0, 12.8), 180)
	for x in [18.9, 19.6, 20.3]:
		PropFactory.part(b, Vector3(x, 0.77, 11.75), 0, Vector3(0, 0.2, 0), Vector3(0.55, 0.4, 0.3), "metal_dark")
	PropFactory.cabinet(b, Vector3(16.5, 0, 15.5), 90, 0.9, 1.2, 0.45, "metal_green")
	b.room = "staffroom"
	PropFactory.table(b, Vector3(18.5, 0, 21.0), 0, 1.4, 0.9)
	PropFactory.chair(b, Vector3(17.7, 0, 21.0), 90)
	PropFactory.chair(b, Vector3(19.3, 0, 21.0), -90, true)
	PropFactory.sofa(b, Vector3(18.5, 0, 23.3), 180, 2.0)
	PropFactory.counter(b, Vector3(20.68, 0, 18.4), -90, 2.0, true)
	PropFactory.fridge(b, Vector3(20.6, 0, 16.6), -90)
	b.room = "obscorr"
	# Against the north wall: in front of the rooms they blocked observation room B.
	FacilityProps.waiting_chairs(b, Vector3(26.5, 0, 11.4), 0, 3)
	FacilityProps.wheelchair(b, Vector3(29.0, 0, 11.8), -30)
	b.room = "obs"
	for x in [22.5, 25.5, 28.5]:
		PropFactory.table(b, Vector3(x, 0, 17.9), 0, 1.4, 0.6, "painted_wood")
		PropFactory.chair(b, Vector3(x, 0, 17.0), 0)
	_morgue_props(b)
	b.room = "cells"
	for x in [22.5, 25.5, 28.5]:
		FacilityProps.hospital_bed(b, Vector3(x, 0, 22.5), 90)
	PropFactory.debris(b, Vector3(25.5, 0, 21), 3.5, 8)
	# Boarded south windows and the METHOD stencil over the observation glass.
	b.room = "shell"
	for w in [[Vector3(3.0, 1.55, 24), true], [Vector3(0, 1.55, 15), false], [Vector3(0, 1.55, 20), false]]:
		var p: Vector3 = w[0]
		var axis_x: bool = w[1]
		var inward := Vector3(0, 0, -0.02) if axis_x else Vector3(0.02, 0, 0)
		PropFactory.boarded_window(b, p + inward, 2.0, 1.1, axis_x)
	var stencil := Label3D.new()
	stencil.text = "METHOD  —  CLINICAL ANNEX 02\nOBSERVATION · SUBJECTS 09–11 · AUDITORY ISOLATION"
	stencil.font_size = 30
	stencil.pixel_size = 0.0022
	stencil.modulate = Color(0.6, 0.12, 0.09)
	stencil.shaded = true
	stencil.position = Vector3(25.5, 2.55, 14.08)
	lights_root.add_child(stencil)
	var sign_label := Label3D.new()
	sign_label.text = "AMBULANCE BAY  →"
	sign_label.font_size = 40
	sign_label.pixel_size = 0.0022
	sign_label.modulate = Color(0.75, 0.72, 0.65)
	sign_label.shaded = true
	sign_label.position = Vector3(8.1, 2.5, 4.0)
	sign_label.rotation.y = PI / 2
	lights_root.add_child(sign_label)


func _morgue_props(b: GeoBuilder) -> void:
	b.room = "morgue"
	# A wall of body drawers along the far wall, one hanging open.
	for col in 4:
		for row in 3:
			var c := Vector3(1.4 + col * 1.6, 0.45 + row * 0.75, 30.7)
			var open := col == 2 and row == 0
			b.box(c, Vector3(1.4, 0.68, 0.5), "metal", true)
			b.box(c + Vector3(0, 0, -0.27 - (0.9 if open else 0.0)), Vector3(1.32, 0.6, 0.04), "metal_dark", false)
			b.box(c + Vector3(0.45, 0.12, -0.31 - (0.9 if open else 0.0)), Vector3(0.18, 0.04, 0.05), "metal", false)
	PropFactory.part(b, Vector3(4.6, 0, 29.75), 0, Vector3(0, 0.38, 0), Vector3(1.2, 0.05, 1.4), "metal", true)
	PropFactory.part(b, Vector3(4.6, 0, 29.75), 0, Vector3(0, 0.44, 0.1), Vector3(0.5, 0.1, 1.1), "fabric")
	# The examination slab, a covered shape on a gurney, a steel sink.
	var slab := Vector3(3.2, 0, 27.0)
	PropFactory.part(b, slab, 90, Vector3(0, 0.88, 0), Vector3(0.8, 0.08, 2.1), "metal", true)
	PropFactory.part(b, slab, 90, Vector3(0, 0.43, 0), Vector3(0.25, 0.86, 0.25), "metal_dark")
	PropFactory.part(b, slab, 90, Vector3(0, 0.95, 0.65), Vector3(0.45, 0.07, 0.6), "fabric")
	FacilityProps.gurney(b, Vector3(6.8, 0, 27.6), 0)
	PropFactory.part(b, Vector3(6.8, 0, 27.6), 0, Vector3(0, 0.98, -0.15), Vector3(0.48, 0.2, 1.3), "fabric")
	PropFactory.part(b, Vector3(6.8, 0, 27.6), 0, Vector3(0, 1.02, 0.7), Vector3(0.3, 0.16, 0.25), "fabric")
	PropFactory.counter(b, Vector3(0.42, 0, 26.6), 90, 1.6, true)
	FacilityProps.iv_stand(b, Vector3(1.6, 0, 28.8))
	PropFactory.debris(b, Vector3(4, 0, 27.5), 2.0, 6)
	b.room = "coldstore"
	PropFactory.shelf(b, Vector3(12.6, 0, 26.5), -90, 1.8, 2.0, 0.45, "metal_dark")
	PropFactory.shelf(b, Vector3(10.5, 0, 30.6), 180, 1.8, 2.0, 0.45, "metal_dark")
	PropFactory.crate(b, Vector3(9.0, 0, 30.2), Vector3(0.8, 0.6, 0.7), 6, "metal_dark")
	FacilityProps.gurney(b, Vector3(10.4, 0, 27.0), 90)
	PropFactory.part(b, Vector3(10.4, 0, 27.0), 90, Vector3(0, 0.98, 0), Vector3(0.5, 0.22, 1.6), "fabric_blue")
	var tag := Label3D.new()
	tag.text = "MORGUE — AUTHORISED STAFF ONLY\nNO VISITING AFTER LIGHTS-OUT"
	tag.font_size = 30
	tag.pixel_size = 0.0022
	tag.modulate = Color(0.62, 0.12, 0.09)
	tag.shaded = true
	tag.position = Vector3(6.0, 2.55, 24.1)
	lights_root.add_child(tag)


# --- Lighting --------------------------------------------------------------------------------


func _lighting() -> void:
	var strips := [
		["reception", Vector3(12, H, 3.5)],
		["triage", Vector3(19, H, 3.5)],
		["maint", Vector3(26, H, 3.5)],
		["bay", Vector3(4, H, 4.5)],
		["corridor", Vector3(3, H, 9.5)],
		["corridor", Vector3(10, H, 9.5)],
		["corridor", Vector3(17, H, 9.5)],
		["corridor", Vector3(24, H, 9.5)],
		["ward", Vector3(4, H, 14)],
		["ward", Vector3(4, H, 20.5)],
		["generator", Vector3(10.5, H, 14)],
		["pharmacy", Vector3(10.5, H, 20.5)],
		["staffcorr", Vector3(14.5, H, 14)],
		["staffcorr", Vector3(14.5, H, 21)],
		["security", Vector3(18.5, H, 13.5)],
		["staffroom", Vector3(18.5, H, 20)],
		["obscorr", Vector3(25.5, H, 12.5)],
		["obs_a", Vector3(22.5, H, 16.5)],
		["obs_b", Vector3(25.5, H, 16.5)],
		["obs_c", Vector3(28.5, H, 16.5)],
		["morgue", Vector3(4, H, 27.5)],
		["coldstore", Vector3(10.5, H, 27.5)],
	]
	for lp in strips:
		var top: Vector3 = lp[1]
		builder.room = "fixtures"
		FacilityProps.strip_light(builder, top, 90.0 if str(lp[0]) == "corridor" else 0.0)
		var shadows: bool = str(lp[0]) in ["corridor", "ward"]
		add_lamp(top + Vector3(0, -0.25, 0), lp[0], 1.2, Color(0.85, 0.95, 0.9), true, shadows, 7.0)
	# Battery-backed emergency lights: dim crimson, enough to find your way.
	add_lamp(Vector3(8.5, 2.6, 4.0), "reception", 0.9, Color(0.9, 0.12, 0.08), false, false, 5.5)
	add_lamp(Vector3(4.0, 2.6, 7.5), "bay", 0.7, Color(0.9, 0.12, 0.08), false, false, 5.0)
	add_lamp(Vector3(15.0, 2.6, 8.4), "corridor", 0.7, Color(0.9, 0.12, 0.08), false, false, 6.0)
	add_lamp(Vector3(4.0, 2.6, 11.4), "ward", 0.6, Color(0.9, 0.12, 0.08), false, false, 6.0)
	add_lamp(Vector3(22.5, 2.6, 7.6), "maint", 0.6, Color(0.9, 0.12, 0.08), false, false, 5.0)
	add_lamp(Vector3(14.5, 2.6, 17.5), "staffcorr", 0.5, Color(0.9, 0.12, 0.08), false, false, 5.0)
	add_lamp(Vector3(27.5, 2.6, 11.4), "obscorr", 0.5, Color(0.9, 0.12, 0.08), false, false, 5.0)
	# The cold store's fridge light never went off.
	add_lamp(Vector3(12.5, 2.6, 28.5), "coldstore", 0.6, Color(0.5, 0.75, 1.0), false, false, 5.5)
	# The cells keep their own sickly night light, visible through the glass.
	add_lamp(Vector3(25.5, 2.7, 21.5), "cells", 0.8, Color(0.55, 0.7, 1.0), false, false, 6.5)
	add_moonlight(Vector3(11.75, 2.2, -1.5), Vector3(11.75, 0, 2.5), 1.3)
	add_moonlight(Vector3(19.0, 2.2, -1.5), Vector3(19.0, 0, 2.5), 1.1)
	add_moonlight(Vector3(-1.5, 2.2, 15.0), Vector3(2.5, 0, 15.0), 1.0)
	var apron := OmniLight3D.new()
	apron.light_color = Color(0.5, 0.6, 0.85)
	apron.light_energy = 1.3
	apron.omni_range = 14.0
	apron.position = Vector3(4, 4.5, -7)
	lights_root.add_child(apron)
	add_dust(AABB(Vector3(0, 0, 0), Vector3(30, H, 11)), 90)
	add_dust(AABB(Vector3(0, 0, 11), Vector3(30, H, 13)), 70)
	add_dust(AABB(Vector3(0, 0, 24), Vector3(13, H, 7)), 30)
	apply_graphics_settings()


# --- Entities ----------------------------------------------------------------------------


func _entities() -> void:
	_door("door_bay", Vector3(8, 0, 3.2), -90, 1.6)
	_door("door_triage", Vector3(18.4, 0, 8), 0, 1.2)
	_door("door_maint", Vector3(25.4, 0, 8), 0, 1.2)
	_door(
		"door_staff",
		Vector3(13.8, 0, 11),
		0,
		1.4,
		"item:staff_card",
		"DOOR_STAFF_ONLY",
		{"card_reader": true, "unlock_flag": "staff_open"}
	)
	_door("door_obs", Vector3(22.0, 0, 11), 0, 1.4, "item:security_card", "DOOR_SECURITY_ONLY", {"card_reader": true})
	_door("door_morgue", Vector3(5.4, 0, 24), 0, 1.2, "", "DOOR_LOCKED", {"material": "metal_dark"})
	_door("door_generator", Vector3(13, 0, 12.6), -90, 1.2)
	_door("door_pharmacy", Vector3(13, 0, 20.0), -90, 1.2)
	_door("door_security", Vector3(16, 0, 12.2), -90, 1.2, "external", "DOOR_KEYPAD_LOCKED", {"material": "metal_dark"})
	_door("door_staffroom", Vector3(16, 0, 19.2), -90, 1.2)
	var obs_doors := {"door_obs_a": 22.2, "door_obs_b": 25.2, "door_obs_c": 28.2}
	for id in obs_doors:
		_door(id, Vector3(float(obs_doors[id]), 0, 14), 0, 1.0)

	var panel := EmergencyPanel.new()
	panel.entity_id = "emergency_panel"
	add_entity(panel, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(8.12, 1.45, 14.0)))
	var keypad := KeypadEntity.new()
	keypad.entity_id = "keypad"
	keypad.target_door = "door_security"
	keypad.success_flag = "security_open"
	keypad.show_order = false
	add_entity(keypad, Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(15.9, 1.35, 14.0)))
	var console := ControlConsole.new()
	console.entity_id = "bay_console"
	console.prompt_key = "PROMPT_BAY_CONSOLE"
	console.done_prompt_key = "PROMPT_BAY_OPENING"
	console.required_flags = ["ward_power"]
	console.set_flag = "bay_open"
	console.missing_message = "CONSOLE_NO_POWER"
	console.activate_sound = "power_on"
	console.noise_radius = 10.0
	add_entity(console, Transform3D(Basis(Vector3.UP, PI), Vector3(17.6, 0, 15.3)))
	shutter = GarageDoor.new()
	shutter.entity_id = "bay_shutter"
	shutter.width = 5.0
	shutter.height = 2.8
	shutter.open_flag = "bay_open"
	shutter.stuck_message = "SHUTTER_NO_POWER"
	shutter.door_prompt = "PROMPT_SHUTTER"
	shutter.noise_kind = "shutter"
	shutter.open_seconds = _shutter_seconds()
	add_entity(shutter, Transform3D(Basis.IDENTITY, Vector3(4, 0, 0)))
	var zone := EscapeZone.new()
	zone.match_ctrl = match_ctrl
	zone.required_flag = "bay_open"
	zone.position = Vector3(4, 1.0, -4.5)
	zone.setup_box(Vector3(8, 2.5, 6))
	add_child(zone)

	# Observation monitors: beds 1-2 in room A, bed 3 in B, bed 4 in C.
	var monitor_spots := [
		Vector3(21.12, 1.6, 15.6), Vector3(21.12, 1.6, 17.4), Vector3(24.12, 1.6, 16.5), Vector3(27.12, 1.6, 16.5)
	]
	for i in monitor_spots.size():
		var m := MonitorClue.new()
		m.entity_id = "monitor_%d" % (i + 1)
		add_entity(m, Transform3D(Basis(Vector3.UP, PI / 2), monitor_spots[i]))
		monitors.append(m)

	_note("note_admission", Vector3(11.4, 0.78, 6.0), "NOTE_ADMISSION_T", "NOTE_ADMISSION_B", "clipboard", 10)
	_note("note_schematic", Vector3(29.88, 1.5, 6.0), "NOTE_SCHEMATIC_T", "NOTE_SCHEMATIC_B", "wall", -90)
	_note("note_roster", Vector3(16.12, 1.5, 22.5), "NOTE_ROSTER_T", "NOTE_ROSTER_B", "wall", 90)
	_note("note_sedation", Vector3(10.0, 0.94, 17.3), "NOTE_SEDATION_T", "NOTE_SEDATION_B", "paper", 15)
	_note("note_morgue", Vector3(0.5, 0.94, 26.2), "NOTE_MORGUE_T", "NOTE_MORGUE_B", "clipboard", 80)
	_note("note_isolation", Vector3(22.3, 0.78, 17.8), "NOTE_ISOLATION_T", "NOTE_ISOLATION_B", "clipboard", -5)
	var tape := TapeRecorder.new()
	tape.entity_id = "tape_obs"
	tape.line_keys = ["TAPE_WARD_1", "TAPE_WARD_2", "TAPE_WARD_3", "TAPE_WARD_4"]
	add_entity(tape, Transform3D(Basis(Vector3.UP, 0.2), Vector3(28.6, 0.81, 17.9)))
	var files := {
		"file_reception": Vector3(12.8, 0.78, 6.0),
		"file_triage": Vector3(17.3, 0.71, 2.4),
		"file_maint": Vector3(29.2, 0.93, 3.6),
		"file_ward": Vector3(6.4, 0.71, 13.2),
		"file_pharmacy": Vector3(10.9, 0.94, 17.3),
		"file_obs": Vector3(25.3, 0.78, 17.8),
	}
	for id in files:
		var c := CollectibleEntity.new()
		c.entity_id = id
		c.collectible_id = "ward_" + str(id).substr(5)
		add_entity(c, Transform3D(Basis(Vector3.UP, 0.3), files[id]))

	_hide("hide_ward_a", Vector3(0.45, 0, 23.0), 90, "wardrobe")
	_hide("hide_ward_b", Vector3(7.55, 0, 12.0), -90, "locker")
	_hide("hide_maint", Vector3(29.55, 0, 6.6), -90, "locker")
	_hide("hide_triage", Vector3(16.45, 0, 1.2), 90, "locker")
	_hide("hide_staff", Vector3(13.45, 0, 23.2), 90, "locker")
	_hide("hide_pharmacy", Vector3(12.55, 0, 18.4), -90, "locker")
	_hide("hide_obscorr", Vector3(29.55, 0, 13.3), -90, "locker")
	_hide("hide_coldstore", Vector3(8.45, 0, 29.6), 90, "locker")

	_switch("switch_reception", "reception", Vector3(13.3, 1.3, 7.91), 180)
	_switch("switch_staffroom", "staffroom", Vector3(16.09, 1.3, 21.0), 90)


func _shutter_seconds() -> float:
	match String(match_ctrl.difficulty.id):
		"story":
			return 30.0
		"hard":
			return 45.0
		"nightmare":
			return 50.0
	return 40.0


## `props` are applied before the door enters the tree (its visuals are built
## in `_ready`).
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
	d.style = "ward"
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


func _switch(id: String, room: String, pos: Vector3, rot_deg: float) -> void:
	var s := LightSwitch.new()
	s.entity_id = id
	s.room = room
	add_entity(s, Transform3D(Basis(Vector3.UP, deg_to_rad(rot_deg)), pos))


# --- Spawns / navigation hints ------------------------------------------------------------


func _spawns() -> void:
	player_spawns = [
		Transform3D(Basis(Vector3.UP, PI), Vector3(12.0, 0.05, 3.2)),
		Transform3D(Basis(Vector3.UP, PI - 0.3), Vector3(11.0, 0.05, 2.6)),
		Transform3D(Basis(Vector3.UP, PI + 0.3), Vector3(13.0, 0.05, 2.6)),
		Transform3D(Basis(Vector3.UP, PI), Vector3(11.0, 0.05, 4.2)),
		Transform3D(Basis(Vector3.UP, PI), Vector3(13.0, 0.05, 4.2)),
		Transform3D(Basis(Vector3.UP, PI), Vector3(12.0, 0.05, 1.8)),
	]
	enemy_spawns = [
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(2.4, 0.05, 22.6)),
		Transform3D(Basis(Vector3.UP, PI / 2), Vector3(28.0, 0.05, 6.0)),
		Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(29.0, 0.05, 9.5)),
		Transform3D(Basis(Vector3.UP, PI), Vector3(20.5, 0.05, 1.4)),
	]
	patrol_points = [
		Vector3(4, 0, 4),
		Vector3(12, 0, 3),
		Vector3(19, 0, 5.5),
		Vector3(26, 0, 4.5),
		Vector3(2, 0, 9.5),
		Vector3(10, 0, 9.5),
		Vector3(19, 0, 9.5),
		Vector3(28, 0, 9.5),
		Vector3(4, 0, 12.5),
		Vector3(4, 0, 17),
		Vector3(4, 0, 22),
		Vector3(14.5, 0, 13),
		Vector3(14.5, 0, 21),
		Vector3(10.5, 0, 13.5),
		Vector3(10.5, 0, 20),
		Vector3(18.5, 0, 18.5),
		Vector3(25.5, 0, 12.5),
		Vector3(4, 0, 26),
		Vector3(10.5, 0, 29),
	]
	prowl_points = [
		Vector3(-1.5, 0, 4),
		Vector3(-1.5, 0, 17),
		Vector3(31.5, 0, 4),
		Vector3(31.5, 0, 18),
		Vector3(15, 0, -1.5),
		Vector3(24, 0, -1.5),
		Vector3(6, 0, 32.5),
		Vector3(18, 0, 25.5),
	]
	var spawns := {
		"sp_reception_desk": Vector3(11.0, 0.77, 6.0),
		"sp_reception_chairs": Vector3(11.0, 0.5, 0.8),
		"sp_triage_bed": Vector3(20.3, 0.71, 3.4),
		"sp_triage_cabinet": Vector3(21.6, 0.94, 6.2),
		"sp_maint_bench": Vector3(29.2, 0.93, 2.4),
		"sp_maint_shelf": Vector3(22.45, 1.05, 4.0),
		"sp_ward_bed_a": Vector3(1.6, 0.71, 13.6),
		"sp_ward_bed_b": Vector3(6.4, 0.71, 20.6),
		"sp_ward_cabinet": Vector3(1.2, 0.84, 15.2),
		"sp_bay_shelf": Vector3(7.55, 1.05, 6.5),
		"sp_corridor_trolley": Vector3(5.5, 0.9, 9.4),
		"sp_staff_table": Vector3(18.3, 0.78, 21.0),
		"sp_staff_counter": Vector3(20.68, 0.93, 18.0),
		"sp_pharmacy_shelf": Vector3(8.45, 1.05, 20.5),
		"sp_pharmacy_fridge": Vector3(12.4, 1.91, 23.4),
		"sp_gen_shelf": Vector3(12.55, 1.05, 16.2),
		"sp_obs_a_desk": Vector3(22.8, 0.78, 17.9),
		"sp_obs_b_desk": Vector3(25.8, 0.78, 17.9),
		"sp_obs_c_desk": Vector3(28.2, 0.78, 17.9),
		"sp_obscorr_bench": Vector3(26.1, 0.5, 11.4),
		"bt_reception": Vector3(13.4, 0.77, 6.0),
		"bt_triage": Vector3(21.6, 0.94, 5.9),
		"bt_maint": Vector3(29.2, 0.93, 3.9),
		"bt_ward": Vector3(6.4, 0.71, 17.2),
		"bt_corridor": Vector3(14.8, 0.5, 9.0),
		"bt_staff": Vector3(18.9, 0.78, 21.2),
		"bt_pharmacy": Vector3(9.9, 0.93, 17.4),
		"bt_obs": Vector3(28.9, 0.78, 17.8),
		"sp_morgue_slab": Vector3(3.2, 0.93, 26.5),
		"sp_morgue_tray": Vector3(4.6, 0.41, 29.4),
		"sp_morgue_counter": Vector3(0.42, 0.93, 27.1),
		"sp_cold_shelf": Vector3(12.55, 1.05, 26.5),
		"sp_cold_crate": Vector3(9.0, 0.61, 30.2),
		"bt_morgue": Vector3(10.5, 1.05, 30.6),
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
	var puzzle: Dictionary = variant.get("puzzle", {})
	var batteries: Array = puzzle.get("batteries", [])
	for i in batteries.size():
		place_pickup_state(mc, "battery_%d" % i, "battery", batteries[i])
	var circuit: Array = puzzle.get("circuit", [])
	var states: Array = []
	for on in circuit:
		states.append("@CIRCUIT_LIVE" if bool(on) else "@CIRCUIT_FAULT")
	seed_state(mc, "note_schematic", {"args": states})
	var order: Array = puzzle.get("round_order", [])
	seed_state(mc, "note_roster", {"args": order.duplicate()})
	var digits: Array = puzzle.get("bed_digits", [])
	for i in digits.size():
		seed_state(mc, "monitor_%d" % (i + 1), {"bed": i + 1, "digit": int(digits[i])})
	seed_state(mc, "keypad", {"solved": false, "order": []})
	var files: Array = puzzle.get("files", [])
	for id in WardRules.FILE_IDS:
		seed_state(mc, id, {"taken": false, "active": files.has(id)})


func authority_tick(_match: MatchController, delta: float) -> void:
	if shutter:
		shutter.authority_tick(delta)


# --- Helpers -------------------------------------------------------------------------------------


static func _win(a: float, b: float) -> Dictionary:
	return {"from": a, "to": b, "bottom": WIN_BOTTOM, "top": WIN_TOP}


static func _doorway(a: float, b: float) -> Dictionary:
	return {"from": a, "to": b, "top": DOOR_TOP}
