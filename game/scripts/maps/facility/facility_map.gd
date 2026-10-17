extends MapBase
## Map 5 — METHOD Facility (Headquarters, sub-level 2).
##
## Layout (meters, +X east, +Z south, one level):
##   Corridor x0-48 z16-20.
##   North (z6-16): security x0-8 (card door), archive x8-18, observation
##     x18-30 (cell monitors), generator x30-40 (maglock), freight lift bay
##     x40-48 with the lift shaft x42-46 z3-6.
##   South (z20-30): containment x0-14 (four cells behind bars from z26),
##     lobby x14-26 (to z32: the dead passenger lift), director's office
##     x26-36 (keypad), break room x36-48.
##
## Subject Zero hunts by sound in the dark and gains sight once the
## generator runs: the map swaps its profile when the power returns.

const FacilityRules = preload("res://scripts/maps/facility/facility_rules.gd")
const H := 3.4
const DOOR_TOP := 2.2

var monitors: Array[MonitorClue] = []
var lift: EvacTrain
var _sight_check := 0.0


func build_level() -> void:
	prepare()
	PropFactory.rng.seed = 5505
	configure_environment(Color(0.15, 0.16, 0.18), 1.0, Color(0.02, 0.025, 0.03), 0.03)
	_rooms()
	_shell()
	_north_rooms()
	_south_rooms()
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
	add_room("corridor", AABB(Vector3(0, 0, 16), Vector3(48, H, 4)), "concrete")
	add_room("security", AABB(Vector3(0, 0, 6), Vector3(8, H, 10)), "concrete")
	add_room("archive", AABB(Vector3(8, 0, 6), Vector3(10, H, 10)), "carpet")
	add_room("observation", AABB(Vector3(18, 0, 6), Vector3(12, H, 10)), "concrete")
	add_room("generator", AABB(Vector3(30, 0, 6), Vector3(10, H, 10)), "metal")
	add_room("liftbay", AABB(Vector3(40, 0, 3), Vector3(8, H, 13)), "concrete")
	add_room("containment", AABB(Vector3(0, 0, 20), Vector3(14, H, 10)), "concrete")
	add_room("lobby", AABB(Vector3(14, 0, 20), Vector3(12, H, 12)), "concrete")
	add_room("director", AABB(Vector3(26, 0, 20), Vector3(10, H, 10)), "carpet")
	add_room("break", AABB(Vector3(36, 0, 20), Vector3(12, H, 10)), "concrete")


func _shell() -> void:
	var b := builder
	# Corridor floor and ceiling in 8 m pieces (at most 8 lamps light a mesh
	# on the Mobile renderer).
	for x0 in range(0, 48, 8):
		b.room = "corridor_%d" % x0
		b.floor_rect(x0, 16, x0 + 8.0, 20, 0.0, "lab_floor")
	# Ceiling and hazard stripes share the 16 m wall bands' batches (fewer draw calls).
	for x0 in range(0, 48, 16):
		b.room = _band(x0 + 1.0, 16.0)
		b.ceiling_rect(x0, 16, x0 + 16.0, 20, H, "ceiling_panel")
		b.box(Vector3(x0 + 8.0, 0.004, 16.15), Vector3(16, 0.01, 0.14), "safety_yellow", false, GeoBuilder.FACE_PY)
		b.room = _band(x0 + 1.0, 20.0)
		b.box(Vector3(x0 + 8.0, 0.004, 19.85), Vector3(16, 0.01, 0.14), "safety_yellow", false, GeoBuilder.FACE_PY)
	b.room = "walls_n_0"
	b.wall_x(16, 0, 8, 0, H, "ward_paint", "lab_tile", [_doorway(5.0, 6.4)])
	b.room = "walls_n_0"
	b.wall_x(16, 8, 18, 0, H, "plaster", "lab_tile", [_doorway(11.0, 12.4)])
	b.room = "walls_n_1"
	b.wall_x(16, 18, 30, 0, H, "lab_tile", "lab_tile", [_doorway(21.0, 22.4)])
	b.room = "walls_n_2"
	b.wall_x(16, 30, 40, 0, H, "blocks", "lab_tile", [_doorway(31.0, 32.4)])
	b.room = "walls_n_2"
	b.wall_x(16, 40, 48, 0, H, "blocks", "lab_tile", [_doorway(41.0, 42.4)])
	b.room = "walls_s_0"
	b.wall_x(20, 0, 14, 0, H, "lab_tile", "lab_tile", [_doorway(9.0, 10.4)])
	b.room = "walls_s_1"
	b.wall_x(20, 14, 26, 0, H, "lab_tile", "lab_tile", [{"from": 16.0, "to": 24.0, "top": 3.0}])
	b.room = "walls_s_1"
	b.wall_x(20, 26, 36, 0, H, "lab_tile", "wallpaper", [_doorway(27.0, 28.4)])
	b.room = "walls_s_2"
	b.wall_x(20, 36, 48, 0, H, "lab_tile", "lab_tile", [_doorway(37.0, 38.4)])
	b.room = "walls_s_0"
	b.wall_z(0, 16, 20, 0, H, "lab_tile", "lab_tile")
	b.room = "walls_s_3"
	b.wall_z(48, 16, 20, 0, H, "lab_tile", "lab_tile")


func _north_rooms() -> void:
	var b := builder
	for r: Array in [
		["security", 0.0, 8.0, "lab_floor", "ward_paint"],
		["archive", 8.0, 18.0, "carpet", "plaster"],
		["observation", 18.0, 30.0, "lab_floor", "lab_tile"],
		["generator", 30.0, 40.0, "concrete_floor", "blocks"],
	]:
		b.room = str(r[0])
		b.floor_rect(r[1], 6, r[2], 16, 0.0, str(r[3]))
		b.room = _band((r[1] + r[2]) * 0.5, 11.0)
		b.ceiling_rect(r[1], 6, r[2], 16, H, "ceiling_panel")
		b.room = str(r[0])
		b.wall_x(6, r[1], r[2], 0, H, str(r[4]), str(r[4]))
	b.room = "liftbay"
	b.floor_rect(40, 6, 48, 16, 0.0, "concrete_floor")
	b.room = _band(44.0, 11.0)
	b.ceiling_rect(40, 6, 48, 16, H, "ceiling_panel")
	b.room = "liftbay"
	b.room = "walls_n_2"
	b.wall_x(6, 40, 48, 0, H, "blocks", "blocks", [{"from": 42.2, "to": 45.8, "top": H}])
	# Freight lift shaft behind the bay.
	b.floor_rect(42, 3, 46, 6, 0.0, "concrete_floor")
	b.room = "walls_n_2"
	b.wall_z(42, 3, 6, 0, H + 6.0, "concrete", "concrete")
	b.room = "walls_n_2"
	b.wall_z(46, 3, 6, 0, H + 6.0, "concrete", "concrete")
	b.room = "walls_n_2"
	b.wall_x(3, 42, 46, 0, H + 6.0, "concrete", "concrete")
	b.box(Vector3(44, 0.004, 6.35), Vector3(3.6, 0.01, 0.3), "safety_yellow", false, GeoBuilder.FACE_PY)
	b.room = "walls_n_0"
	b.wall_z(0, 6, 16, 0, H, "ward_paint", "ward_paint")
	b.room = "walls_n_0"
	b.wall_z(8, 6, 16, 0, H, "ward_paint", "plaster")
	b.room = "walls_n_1"
	b.wall_z(18, 6, 16, 0, H, "plaster", "lab_tile")
	b.room = "walls_n_1"
	b.wall_z(30, 6, 16, 0, H, "lab_tile", "blocks")
	b.room = "walls_n_2"
	b.wall_z(40, 6, 16, 0, H, "blocks", "blocks")
	b.room = "walls_n_3"
	b.wall_z(48, 6, 16, 0, H, "blocks", "blocks")


func _south_rooms() -> void:
	var b := builder
	for r: Array in [
		["containment", 0.0, 14.0, "lab_floor", "lab_tile"],
		["director", 26.0, 36.0, "carpet", "wallpaper"],
		["break", 36.0, 48.0, "lab_floor", "lab_tile"],
	]:
		b.room = str(r[0])
		b.floor_rect(r[1], 20, r[2], 30, 0.0, str(r[3]))
		b.room = _band((r[1] + r[2]) * 0.5, 25.0)
		b.ceiling_rect(r[1], 20, r[2], 30, H, "ceiling_panel")
		b.room = str(r[0])
		b.wall_x(30, r[1], r[2], 0, H, str(r[4]), str(r[4]))
	b.room = "walls_s_0"
	b.wall_z(0, 20, 30, 0, H, "lab_tile", "lab_tile")
	b.room = "walls_s_2"
	b.wall_z(36, 20, 30, 0, H, "wallpaper", "lab_tile")
	b.room = "walls_s_3"
	b.wall_z(48, 20, 30, 0, H, "lab_tile", "lab_tile")
	# Containment cells: partitions between the four cells behind the bars.
	b.room = "containment"
	for x in [3.5, 7.0, 10.5]:
		b.wall_z(x, 26, 30, 0, H, "lab_tile", "lab_tile")
	for i in 4:
		var x0 := i * 3.5
		FinaleProps.cell_bars(b, x0, x0 + 3.5, 26.0, x0 + 1.0, x0 + 2.2)
	# Lobby: tiled, with the dead passenger lift in its south wall.
	b.room = "lobby"
	b.floor_rect(14, 20, 26, 32, 0.0, "tile")
	b.room = _band(20.0, 25.0)
	b.ceiling_rect(14, 20, 26, 32, H, "ceiling_panel")
	b.room = "lobby"
	b.room = "walls_s_0"
	b.wall_z(14, 20, 32, 0, H, "lab_tile", "lab_tile")
	b.room = "walls_s_1"
	b.wall_z(26, 20, 32, 0, H, "lab_tile", "wallpaper")
	b.room = "walls_s_1"
	b.wall_x(32, 14, 26, 0, H, "lab_tile", "lab_tile")
	for side in [-1, 1]:
		b.box(Vector3(20.0 + side * 0.5, 1.1, 31.9), Vector3(0.98, 2.2, 0.06), "metal", false)
	b.box(Vector3(20.0, 1.15, 31.95), Vector3(2.4, 2.4, 0.04), "metal_dark", false)


# --- Props ----------------------------------------------------------------------------------


func _props() -> void:
	var b := builder
	b.room = "security"
	PropFactory.table(b, Vector3(4.0, 0, 9.0), 0, 1.8, 0.9, "metal_dark")
	FinaleProps.terminal(b, Vector3(3.6, 0, 9.0), 0)
	PropFactory.chair(b, Vector3(4.0, 0, 9.8), 180)
	PropFactory.shelf(b, Vector3(7.6, 0, 9.0), -90, 1.8, 2.0, 0.4, "metal_dark")
	for x in [2.0, 3.0, 4.0]:
		b.box(Vector3(x, 2.0, 6.12), Vector3(0.8, 0.5, 0.06), "metal_dark", false)
	b.room = "archive"
	for x in [10.5, 15.0]:
		PropFactory.shelf(b, Vector3(x, 0, 6.25), 0, 2.4, 2.0, 0.4, "dark_wood")
	PropFactory.shelf(b, Vector3(8.25, 0, 11.0), 90, 2.4, 2.0, 0.4, "dark_wood")
	PropFactory.table(b, Vector3(13.0, 0, 11.0), 0, 2.0, 1.0, "dark_wood")
	PropFactory.chair(b, Vector3(12.4, 0, 11.8), 180)
	PropFactory.cabinet(b, Vector3(17.6, 0, 9.0), -90, 0.9, 1.3, 0.45, "metal_green")
	b.room = "observation"
	FinaleProps.lab_bench(b, Vector3(24.0, 0, 15.6), 180, 2.4)
	FinaleProps.terminal(b, Vector3(24.6, 0, 15.6), 180, 0.92)
	FinaleProps.specimen_tank(b, Vector3(28.4, 0, 11.0))
	PropFactory.chair(b, Vector3(23.2, 0, 14.6), 0)
	b.room = "generator"
	PropFactory.workbench(b, Vector3(35.0, 0, 6.45), 0)
	PropFactory.boiler(b, Vector3(31.0, 0, 7.0))
	PropFactory.part(b, Vector3(33.5, 0, 12.0), 0, Vector3(0, 0.8, 0), Vector3(2.4, 1.6, 1.4), "metal_green", true)
	PropFactory.pipe_run(b, Vector3(31.0, 2.9, 7.0), Vector3(31.0, 2.9, 15.6), 0.08)
	for z in [10.0, 12.0]:
		FinaleProps.server_rack(b, Vector3(39.5, 0, z), -90)
	b.room = "liftbay"
	PropFactory.crate(b, Vector3(47.0, 0, 13.0), Vector3(0.9, 0.8, 0.8), 6, "metal_dark")
	PropFactory.crate(b, Vector3(46.8, 0, 14.6), Vector3(0.8, 0.6, 0.7), -10, "dark_wood")
	b.room = "containment"
	PropFactory.table(b, Vector3(12.0, 0, 22.5), 90, 1.6, 0.8, "metal_dark")
	FinaleProps.terminal(b, Vector3(12.0, 0, 22.8), 90)
	for i in 4:
		PropFactory.crate(b, Vector3(i * 3.5 + 1.75, 0, 29.4), Vector3(1.6, 0.45, 0.7), 0, "fabric")
	b.room = "lobby"
	FacilityProps.reception_desk(b, Vector3(16.5, 0, 25.5), 90, 3.0)
	FacilityProps.platform_bench(b, Vector3(23.5, 0, 26.3), -90)
	FacilityProps.waiting_chairs(b, Vector3(20.0, 0, 21.2), 0, 4)
	PropFactory.picture(b, Vector3(25.9, 1.8, 28.0), -90, 1.2, 0.8)
	b.room = "director"
	FinaleProps.teacher_desk(b, Vector3(31.0, 0, 25.8), 0)
	PropFactory.chair(b, Vector3(31.0, 0, 26.6), 180)
	PropFactory.shelf(b, Vector3(35.6, 0, 23.0), -90, 2.0, 2.0, 0.4, "dark_wood")
	PropFactory.armchair(b, Vector3(27.2, 0, 28.6), 45)
	PropFactory.rug(b, Vector3(31.0, 0, 25.0), Vector2(3.4, 2.4))
	b.room = "break"
	PropFactory.table(b, Vector3(41.0, 0, 25.0), 0, 1.8, 0.9, "painted_wood")
	for p: Array in [[Vector3(40.4, 0, 25.8), 180.0], [Vector3(41.6, 0, 24.2), 0.0]]:
		PropFactory.chair(b, p[0], p[1])
	PropFactory.counter(b, Vector3(47.6, 0, 24.5), -90, 3.0, true)
	FacilityProps.vending_machine(b, Vector3(36.5, 0, 22.0), 90)
	FacilityProps.vending_machine(b, Vector3(36.5, 0, 23.1), 90)
	b.room = "corridor"
	PropFactory.debris(b, Vector3(24.0, 0, 18.0), 8.0, 14)
	var sign := Label3D.new()
	sign.text = "METHOD  —  HEADQUARTERS · SUB-LEVEL 2\nCONTAINMENT · OBSERVATION · ARCHIVE"
	sign.font_size = 30
	sign.pixel_size = 0.0024
	sign.modulate = Color(0.62, 0.12, 0.09)
	sign.shaded = true
	sign.position = Vector3(20.0, 3.1, 20.08)
	lights_root.add_child(sign)
	var cells := Label3D.new()
	cells.text = "CELL 1          CELL 2          CELL 3          CELL 4"
	cells.font_size = 30
	cells.pixel_size = 0.0025
	cells.modulate = Color(0.85, 0.82, 0.74)
	cells.shaded = true
	cells.position = Vector3(7.0, 2.75, 26.1)
	cells.rotation.y = PI
	cells.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lights_root.add_child(cells)


# --- Lighting --------------------------------------------------------------------------------


func _lighting() -> void:
	var fixtures: Array = []
	for x in [4.0, 12.0, 20.0, 28.0, 36.0, 44.0]:
		fixtures.append(["corridor", Vector3(x, H, 18.0)])
	fixtures.append(["security", Vector3(4.0, H, 11.0)])
	fixtures.append(["archive", Vector3(13.0, H, 11.0)])
	for x in [21.0, 27.0]:
		fixtures.append(["observation", Vector3(x, H, 11.0)])
	fixtures.append(["generator", Vector3(35.0, H, 11.0)])
	fixtures.append(["liftbay", Vector3(44.0, H, 11.0)])
	for x in [3.5, 10.5]:
		fixtures.append(["containment", Vector3(x, H, 23.0)])
	for z in [23.0, 28.0]:
		fixtures.append(["lobby", Vector3(20.0, H, z)])
	fixtures.append(["director", Vector3(31.0, H, 25.0)])
	fixtures.append(["break", Vector3(42.0, H, 25.0)])
	for f in fixtures:
		var top: Vector3 = f[1]
		builder.room = "fixtures"
		FacilityProps.strip_light(builder, top, 90.0)
		add_lamp(top + Vector3(0, -0.25, 0), f[0], 1.3, Color(0.88, 0.95, 1.0), true, str(f[0]) == "lobby", 7.0)
	# Red emergency beacons: enough to move by, never enough to be seen in.
	var red := Color(0.95, 0.12, 0.08)
	for x in [2.0, 24.0, 46.0]:
		add_lamp(Vector3(x, 3.0, 19.8), "corridor", 0.55, red, false, false, 6.0)
	add_lamp(Vector3(20.0, 3.0, 31.6), "lobby", 0.6, red, false, false, 6.5)
	add_lamp(Vector3(7.0, 3.0, 20.4), "containment", 0.5, red, false, false, 6.0)
	add_lamp(Vector3(4.0, 2.6, 6.6), "security", 0.6, Color(0.4, 0.7, 1.0), false, false, 4.5)
	add_lamp(Vector3(44.0, 3.0, 6.6), "liftbay", 0.5, Color(1.0, 0.6, 0.15), false, false, 5.0)
	add_dust(AABB(Vector3(0, 0, 16), Vector3(48, H, 4)), 70)
	add_dust(AABB(Vector3(0, 0, 20), Vector3(14, H, 10)), 40)
	apply_graphics_settings()


# --- Entities ----------------------------------------------------------------------------


func _entities() -> void:
	_door(
		"door_security",
		Vector3(5.0, 0, 16.0),
		0,
		1.4,
		"item:security_card",
		"DOOR_SECURITY_ONLY",
		{"card_reader": true, "material": "metal_dark", "unlock_flag": "security_open"}
	)
	_door("door_archive", Vector3(11.0, 0, 16.0), 0, 1.4)
	_door("door_observation", Vector3(21.0, 0, 16.0), 0, 1.4, "", "DOOR_LOCKED", {"material": "metal"})
	_door("door_generator", Vector3(31.0, 0, 16.0), 0, 1.4, "external", "DOOR_MAGLOCK", {"material": "metal_dark"})
	_door("door_liftbay", Vector3(41.0, 0, 16.0), 0, 1.4, "", "DOOR_LOCKED", {"material": "metal_dark"})
	_door("door_containment", Vector3(9.0, 0, 20.0), 0, 1.4, "", "DOOR_LOCKED", {"material": "metal"})
	_door("door_director", Vector3(27.0, 0, 20.0), 0, 1.4, "external", "DOOR_KEYPAD_LOCKED", {"material": "dark_wood"})
	_door("door_break", Vector3(37.0, 0, 20.0), 0, 1.4)

	var dead := InspectSpot.new()
	dead.entity_id = "lift_dead"
	dead.flag = "exit_found"
	dead.message = "FACILITY_LIFT_DEAD"
	dead.target_size = Vector3(2.6, 2.6, 0.6)
	add_entity(dead, Transform3D(Basis(Vector3.UP, PI), Vector3(20.0, 1.3, 31.7)))
	var release := ControlConsole.new()
	release.entity_id = "release_locks"
	release.prompt_key = "PROMPT_RELEASE_LOCKS"
	release.done_prompt_key = "PROMPT_LOCKS_RELEASED"
	release.set_flag = "locks_released"
	release.activate_sound = "relay_click"
	release.noise_radius = 8.0
	release.hold_time = 0.8
	add_entity(release, Transform3D(Basis.IDENTITY, Vector3(1.8, 0, 6.5)))
	var rack := ItemReceptacle.new()
	rack.entity_id = "generator_rack"
	rack.item = "power_cell"
	rack.slots = 2
	rack.flag = "facility_power"
	rack.counter = "cells_installed"
	add_entity(rack, Transform3D(Basis.IDENTITY, Vector3(35.0, 0.93, 6.55)))
	var spots := [
		Vector3(20.0, 1.6, 6.12), Vector3(22.6, 1.6, 6.12), Vector3(25.2, 1.6, 6.12), Vector3(27.8, 1.6, 6.12)
	]
	for i in spots.size():
		var m := MonitorClue.new()
		m.entity_id = "monitor_%d" % (i + 1)
		m.unit_label = "MONITOR_UNIT_CELL"
		m.examine_key = "FMONITOR_EXAMINE"
		add_entity(m, Transform3D(Basis.IDENTITY, spots[i]))
		monitors.append(m)
	var keypad := KeypadEntity.new()
	keypad.entity_id = "keypad"
	keypad.target_door = "door_director"
	keypad.success_flag = "office_open"
	keypad.show_order = false
	add_entity(keypad, Transform3D(Basis(Vector3.UP, PI), Vector3(29.0, 1.35, 19.9)))
	var console := ControlConsole.new()
	console.entity_id = "lift_console"
	console.prompt_key = "PROMPT_CALL_LIFT"
	console.done_prompt_key = "PROMPT_LIFT_CALLED"
	console.required_flags = ["facility_power"]
	console.set_flag = "lift_called"
	console.missing_message = "LIFT_NO_POWER"
	console.activate_sound = "lift_call"
	console.noise_radius = 12.0
	console.hold_time = 1.0
	add_entity(console, Transform3D(Basis(Vector3.UP, PI), Vector3(34.4, 0, 29.5)))
	lift = EvacTrain.new()
	lift.entity_id = "freight_lift"
	lift.style = "lift"
	lift.length = 3.4
	lift.door_offsets = PackedFloat32Array([0.0])
	lift.door_width = 1.8
	lift.call_flag = "lift_called"
	lift.arrived_flag = "lift_arrived"
	lift.arrival_seconds = _arrival_seconds()
	lift.arrive_sound = "lift_arrive"
	lift.eta_key = "LIFT_ETA"
	lift.arrived_key = "LIFT_ARRIVED"
	lift.noise_kind = "lift"
	add_entity(lift, Transform3D(Basis.IDENTITY, Vector3(44.0, 0, 6.0)))
	var zone := EscapeZone.new()
	zone.match_ctrl = match_ctrl
	zone.required_flag = "lift_arrived"
	zone.position = Vector3(44.0, 1.2, 4.6)
	zone.setup_box(Vector3(3.0, 2.4, 2.2))
	add_child(zone)

	_note("note_protocol", Vector3(13.4, 0.79, 11.2), "NOTE_PROTOCOL_T", "NOTE_PROTOCOL_B", "clipboard", 8)
	_note("note_security", Vector3(4.6, 0.79, 9.1), "NOTE_FSECURITY_T", "NOTE_FSECURITY_B", "paper", -12)
	_note("note_memo", Vector3(16.4, 0.77, 26.4), "NOTE_MEMO_T", "NOTE_MEMO_B", "paper", 80)
	_note("note_cells", Vector3(12.0, 0.79, 22.1), "NOTE_CELLS_T", "NOTE_CELLS_B", "clipboard", 90)
	_note("note_freight", Vector3(41.5, 1.5, 15.88), "NOTE_FREIGHT_T", "NOTE_FREIGHT_B", "wall", 180)
	_note("note_director", Vector3(30.4, 0.79, 25.7), "NOTE_DIRECTOR_T", "NOTE_DIRECTOR_B", "paper", 10)
	var tape := TapeRecorder.new()
	tape.entity_id = "tape_director"
	tape.line_keys = ["TAPE_FACILITY_1", "TAPE_FACILITY_2", "TAPE_FACILITY_3", "TAPE_FACILITY_4", "TAPE_FACILITY_5"]
	add_entity(tape, Transform3D(Basis(Vector3.UP, 0.3), Vector3(31.8, 0.79, 25.9)))
	var files := {
		"file_security": Vector3(7.6, 1.05, 8.4),
		"file_archive": Vector3(15.0, 1.05, 6.3),
		"file_observation": Vector3(23.4, 0.93, 15.6),
		"file_cells": Vector3(5.25, 0.46, 29.4),
		"file_break": Vector3(47.6, 0.93, 23.6),
		"file_director": Vector3(35.6, 1.05, 22.4),
	}
	for id in files:
		var c := CollectibleEntity.new()
		c.entity_id = id
		c.collectible_id = "facility_" + str(id).substr(5)
		add_entity(c, Transform3D(Basis(Vector3.UP, 0.4), files[id]))

	_hide("hide_security", Vector3(0.45, 0, 13.5), 90, "locker")
	_hide("hide_corridor_w", Vector3(14.0, 0, 16.45), 0, "locker")
	_hide("hide_corridor_e", Vector3(36.0, 0, 16.45), 0, "locker")
	_hide("hide_observation", Vector3(18.45, 0, 13.0), 90, "locker")
	_hide("hide_generator", Vector3(39.55, 0, 14.6), -90, "locker")
	_hide("hide_lobby", Vector3(25.55, 0, 23.0), -90, "locker")
	_hide("hide_director", Vector3(35.4, 0, 28.4), -90, "wardrobe")
	_hide("hide_break", Vector3(36.6, 0, 28.0), 90, "locker")
	_hide("hide_cells", Vector3(13.55, 0, 24.6), -90, "locker")


func _arrival_seconds() -> float:
	match String(match_ctrl.difficulty.id):
		"story":
			return 40.0
		"hard":
			return 75.0
		"nightmare":
			return 90.0
	return 60.0


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
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(20.0, 0.05, 28.0)),
		Transform3D(Basis(Vector3.UP, 0.3), Vector3(19.0, 0.05, 28.6)),
		Transform3D(Basis(Vector3.UP, -0.3), Vector3(21.0, 0.05, 28.6)),
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(19.0, 0.05, 29.6)),
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(21.0, 0.05, 29.6)),
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(20.0, 0.05, 30.4)),
	]
	enemy_spawns = [
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(13.0, 0.05, 9.0)),
		Transform3D(Basis(Vector3.UP, PI), Vector3(26.0, 0.05, 12.0)),
		Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(45.0, 0.05, 27.0)),
		Transform3D(Basis(Vector3.UP, PI / 2), Vector3(46.0, 0.05, 10.0)),
	]
	patrol_points = [
		Vector3(2, 0, 18),
		Vector3(12, 0, 18),
		Vector3(24, 0, 18),
		Vector3(34, 0, 18),
		Vector3(46, 0, 18),
		Vector3(4, 0, 12),
		Vector3(13, 0, 13.5),
		Vector3(24, 0, 10),
		Vector3(35, 0, 9.5),
		Vector3(44, 0, 10),
		Vector3(7, 0, 23),
		Vector3(5.2, 0, 28),
		Vector3(20, 0, 24),
		Vector3(31, 0, 22.5),
		Vector3(42, 0, 27.5),
		Vector3(44, 0, 21.5),
	]
	prowl_points = [
		Vector3(1, 0, 18), Vector3(47, 0, 18), Vector3(1.75, 0, 28), Vector3(47, 0, 28.5), Vector3(44, 0, 7.5)
	]
	var spawns := {
		"sp_lobby_desk": Vector3(16.4, 0.77, 25.0),
		"sp_lobby_bench": Vector3(23.5, 0.49, 26.8),
		"sp_cell_1": Vector3(1.75, 0.46, 29.4),
		"sp_cell_3": Vector3(8.75, 0.46, 29.4),
		"sp_cells_desk": Vector3(11.8, 0.79, 22.1),
		"sp_break_table": Vector3(41.3, 0.79, 25.0),
		"sp_break_counter": Vector3(47.6, 0.93, 25.4),
		"sp_archive_table": Vector3(13.6, 0.79, 10.8),
		"sp_archive_shelf": Vector3(10.5, 1.05, 6.3),
		"sp_obs_bench": Vector3(25.0, 0.93, 15.6),
		"sp_liftbay_crate": Vector3(47.0, 0.81, 13.0),
		"sp_security_desk": Vector3(4.6, 0.79, 8.7),
		"sp_security_shelf": Vector3(7.6, 1.05, 9.6),
		"bt_lobby": Vector3(23.0, 0.49, 26.0),
		"bt_cells": Vector3(12.2, 0.79, 23.0),
		"bt_break": Vector3(40.6, 0.79, 25.2),
		"bt_archive": Vector3(8.3, 1.05, 11.5),
		"bt_observation": Vector3(23.0, 0.93, 15.7),
		"bt_security": Vector3(3.3, 0.79, 9.2),
		"bt_corridor": Vector3(47.6, 0.93, 23.0),
		"bt_liftbay": Vector3(46.8, 0.61, 14.6),
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
	seed_state(mc, "note_protocol", {"args": (puzzle.get("check_order", []) as Array).duplicate()})
	var digits: Array = puzzle.get("cell_digits", [])
	for i in digits.size():
		seed_state(mc, "monitor_%d" % (i + 1), {"bed": i + 1, "digit": int(digits[i])})
	seed_state(mc, "keypad", {"solved": false, "order": []})
	var files: Array = puzzle.get("files", [])
	for id in FacilityRules.FILE_IDS:
		seed_state(mc, id, {"taken": false, "active": files.has(id)})


func on_flag(mc: MatchController, flag: String) -> void:
	if flag == "locks_released" and mc.is_authority:
		var gen: DoorEntity = mc.entities.get("door_generator") as DoorEntity
		if gen and gen.is_locked():
			gen.force_unlock(false)
	if flag == "facility_power":
		_restore_sight()


func authority_tick(_match: MatchController, delta: float) -> void:
	if lift:
		lift.authority_tick(delta)


## On every peer: once the lights are back, Subject Zero sees again. Also
## catches an enemy (or a client's puppet) that spawned after the switch.
func _process(delta: float) -> void:
	_sight_check -= delta
	if _sight_check > 0.0:
		return
	_sight_check = 0.5
	if power_on:
		_restore_sight()


func _restore_sight() -> void:
	if enemies_root == null:
		return
	for e in enemies_root.get_children():
		var w := e as Watcher
		if w and w.profile and w.profile.id == "subject" and not w.profile.sees:
			w.set_profile(EnemyProfile.subject_lit())


## Batch name for geometry around (x, z): 16 m bands north/south of the
## corridor's middle, small enough to stay under the 8-lamps-per-mesh limit.
static func _band(x: float, z: float) -> String:
	return "walls_%s_%d" % ["n" if z <= 16.5 else "s", int(x / 16.0)]


static func _doorway(a: float, b: float) -> Dictionary:
	return {"from": a, "to": b, "top": DOOR_TOP}
