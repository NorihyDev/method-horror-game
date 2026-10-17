extends MapBase
## Map 3 — Last Train ("METHOD Transit Annex 03", Kessel Street station).
##
## Layout (meters, +X east, +Z south):
##   Concourse (street level, y=0) x6-30 z21-33: ticket gates, kiosk, ticket
##     office x6-11 z26-33, collapsed street exit in the south wall.
##   Stair shaft x14-18 z13-21 from the platform (y=PY) up to the concourse.
##   Platform (y=PY) x0-40 z7-13, beside two tracks: track 2 (near, the
##     evacuation train) at z≈5.3 and track 1 (far, ghost trains) at z≈1.7,
##     both continuing into tunnels to x=-40 and x=80.
##   Maintenance (y=PY, behind a locked door at x34-35.4): corridor x33-36
##     z13-25, signal box x25-33 z15-25, store room x36-40 z15-25.

const StationRules = preload("res://scripts/maps/station/station_rules.gd")
const PY := -5.0
const CH := 4.0
const PLATFORM_H := 4.5
const ROOM_H := 3.2
const DOOR_TOP := 2.2

var evac_train: EvacTrain
var ghost_train: GhostTrain


func build_level() -> void:
	prepare()
	PropFactory.rng.seed = 6363
	configure_environment(Color(0.17, 0.17, 0.2), 1.0, Color(0.025, 0.025, 0.03), 0.03)
	_rooms()
	_concourse()
	_stair_shaft()
	_platform()
	_tunnels()
	_maintenance()
	_props()
	_lighting()
	_entities()
	_spawns()
	finalize()


func noise_mask(pos: Vector3, kind: String) -> float:
	if kind == "train" or ghost_train == null or match_ctrl == null:
		return 1.0
	# A passing train drowns out everything near the tracks.
	return 0.3 if ghost_train.masks(pos, match_ctrl.state.elapsed) else 1.0


# --- Geometry ------------------------------------------------------------------------------


func _rooms() -> void:
	add_room("concourse", AABB(Vector3(11, 0, 21), Vector3(19, CH, 12)), "concrete")
	add_room("office", AABB(Vector3(6, 0, 26), Vector3(5, ROOM_H, 7)), "wood")
	add_room("concourse_west", AABB(Vector3(6, 0, 21), Vector3(5, CH, 5)), "concrete")
	add_room("stairs", AABB(Vector3(14, PY, 13), Vector3(4, 3.0 - PY, 8)), "concrete")
	add_room("platform", AABB(Vector3(0, PY, 7), Vector3(40, PLATFORM_H, 6)), "concrete")
	add_room("corridor", AABB(Vector3(33, PY, 13), Vector3(3, ROOM_H, 12)), "metal")
	add_room("signal_box", AABB(Vector3(25, PY, 15), Vector3(8, ROOM_H, 10)), "wood")
	add_room("store", AABB(Vector3(36, PY, 15), Vector3(4, ROOM_H, 10)), "concrete")


func _concourse() -> void:
	var b := builder
	b.room = "concourse"
	b.floor_rect(6, 21, 30, 33, 0.0, "platform")
	b.ceiling_rect(6, 21, 30, 33, CH, "concrete")
	b.wall_x(21, 6, 30, 0, CH, "tunnel", "subway_tile", [{"from": 14.0, "to": 18.0, "top": 2.8}])
	b.wall_x(33, 6, 30, 0, CH, "subway_tile", "exterior", [{"from": 15.0, "to": 21.0, "top": 3.4}])
	b.wall_z(6, 21, 33, 0, CH, "exterior", "subway_tile")
	b.wall_z(30, 21, 33, 0, CH, "subway_tile", "exterior")
	# Ticket office.
	b.room = "office"
	b.wall_z(11, 26, 33, 0, CH, "painted_wood", "subway_tile", [_doorway(28.0, 29.2)])
	b.wall_x(26, 6, 11, 0, CH, "subway_tile", "painted_wood")
	b.ceiling_rect(6, 26, 11, 33, ROOM_H, "ceiling")
	# A maroon tile band around the hall.
	for band in [[Vector3(18, 1.1, 21.1), Vector3(24, 0.18, 0.02)], [Vector3(18, 1.1, 32.9), Vector3(24, 0.18, 0.02)]]:
		b.box(band[0], band[1], "subway_band", false)
	b.box(Vector3(6.1, 1.1, 23.5), Vector3(0.02, 0.18, 5), "subway_band", false)
	b.box(Vector3(29.9, 1.1, 27), Vector3(0.02, 0.18, 12), "subway_band", false)
	# The street stairs came down: rubble fills the exit.
	b.room = "rubble"
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for i in 14:
		var p := Vector3(rng.randf_range(15.3, 20.7), rng.randf_range(0.2, 2.6), rng.randf_range(32.4, 33.6))
		var size := Vector3(rng.randf_range(0.5, 1.4), rng.randf_range(0.3, 0.9), rng.randf_range(0.4, 1.0))
		b.box(p, size, "concrete", false, GeoBuilder.FACE_ALL, Basis(Vector3.UP, rng.randf() * TAU), true)
	b.box(Vector3(18, 1.6, 33.4), Vector3(6.2, 3.4, 0.8), "concrete", true, GeoBuilder.FACE_NZ)
	b.box(
		Vector3(17.2, 2.3, 32.7),
		Vector3(4.5, 0.25, 0.25),
		"rust",
		false,
		GeoBuilder.FACE_ALL,
		Basis(Vector3.BACK, 0.35)
	)


func _stair_shaft() -> void:
	var b := builder
	b.room = "stairs"
	b.wall_z(14, 13, 21, PY, 3.0 - PY, "subway_tile", "subway_tile")
	b.wall_z(18, 13, 21, PY, 3.0 - PY, "subway_tile", "subway_tile")
	b.wall_x(13, 14, 18, PY + PLATFORM_H, 3.0 - PY - PLATFORM_H, "subway_tile", "subway_tile")
	b.ceiling_rect(14, 13, 18, 21, 3.0, "concrete")
	b.stairs_z(14.08, 17.92, 13.0, 21.0, PY, 0.0, 26, "platform", PY)
	PropFactory.pipe_run(b, Vector3(14.15, PY + 0.95, 13.0), Vector3(14.15, 0.95, 21.0), 0.025, "metal")
	PropFactory.pipe_run(b, Vector3(17.85, PY + 0.95, 13.0), Vector3(17.85, 0.95, 21.0), 0.025, "metal")


func _platform() -> void:
	var b := builder
	b.room = "platform"
	b.floor_rect(0, 7, 40, 13, PY, "platform")
	b.box(Vector3(20, PY + 0.003, 7.25), Vector3(40, 0.01, 0.4), "safety_yellow", false, GeoBuilder.FACE_PY)
	b.box(Vector3(20, PY - 0.5, 7.0), Vector3(40, 1.0, 0.1), "concrete", false, GeoBuilder.FACE_NZ)
	b.ceiling_rect(0, 0, 40, 13, PY + PLATFORM_H, "concrete")
	b.wall_x(
		13,
		0,
		40,
		PY,
		PLATFORM_H,
		"subway_tile",
		"tunnel",
		[{"from": 14.0, "to": 18.0, "top": PLATFORM_H}, _doorway(34.0, 35.4)]
	)
	b.box(Vector3(20, PY + 1.1, 12.9), Vector3(40, 0.18, 0.02), "subway_band", false)
	for x in [0.0, 40.0]:
		b.wall_z(x, 7, 13, PY, PLATFORM_H, "subway_tile", "subway_tile")
		b.wall_z(x, 0, 7, PY + 3.2, PLATFORM_H - 3.2, "tunnel", "tunnel")
	b.wall_x(0, 0, 40, PY - 1.0, PLATFORM_H + 1.0, "tunnel", "tunnel")
	# Invisible edge barrier along the platform; the train fills the door gaps.
	for seg: Vector2 in [Vector2(0.0, 15.0), Vector2(17.0, 23.0), Vector2(25.0, 40.0)]:
		b.collider(Vector3((seg.x + seg.y) * 0.5, PY + 1.2, 7.0), Vector3(seg.y - seg.x, 2.4, 0.1))
	# Track bed under the platform section (visual only: nobody walks there).
	b.room = "tracks"
	b.box(Vector3(20, PY - 1.05, 3.5), Vector3(120, 0.1, 7), "ballast", false, GeoBuilder.FACE_PY)
	FacilityProps.track_x(b, -40.0, 80.0, 1.7, PY - 0.75)
	FacilityProps.track_x(b, -40.0, 80.0, 5.3, PY - 0.75)


func _tunnels() -> void:
	var b := builder
	b.room = "tunnels"
	for span: Vector2 in [Vector2(-40.0, 0.0), Vector2(40.0, 80.0)]:
		var mid := (span.x + span.y) * 0.5
		var length := span.y - span.x
		b.box(Vector3(mid, PY + 3.2 + 0.1, 3.5), Vector3(length, 0.2, 7.2), "tunnel", false, GeoBuilder.FACE_NY)
		b.box(Vector3(mid, PY + 1.1, 7.05), Vector3(length, 4.2, 0.1), "tunnel", false, GeoBuilder.FACE_NZ)
		b.box(Vector3(mid, PY + 1.1, -0.05), Vector3(length, 4.2, 0.1), "tunnel", false, GeoBuilder.FACE_PZ)
		var x := span.x + 2.5
		while x < span.y:
			FacilityProps.tunnel_rib(b, x, 0.0, 7.0, PY - 1.0, 4.2)
			x += 5.0
	for x in [-40.0, 80.0]:
		b.box(Vector3(x, PY + 1.1, 3.5), Vector3(0.2, 4.2, 7), "tunnel", false)


func _maintenance() -> void:
	var b := builder
	b.room = "corridor"
	b.floor_rect(33, 13, 36, 25, PY, "concrete_floor")
	b.ceiling_rect(33, 13, 36, 25, PY + ROOM_H, "concrete")
	b.wall_z(33, 13, 25, PY, ROOM_H, "blocks", "blocks", [_doorway(19.0, 20.2)])
	b.wall_z(36, 13, 25, PY, ROOM_H, "blocks", "blocks", [_doorway(19.0, 20.2)])
	b.wall_x(25, 25, 40, PY, ROOM_H, "blocks", "exterior")
	b.room = "signal_box"
	b.floor_rect(25, 15, 33, 25, PY, "wood_floor")
	b.ceiling_rect(25, 15, 33, 25, PY + ROOM_H, "ceiling")
	b.wall_x(15, 25, 33, PY, ROOM_H, "exterior", "painted_wood")
	b.wall_z(25, 15, 25, PY, ROOM_H, "exterior", "painted_wood")
	b.room = "store"
	b.floor_rect(36, 15, 40, 25, PY, "concrete_floor")
	b.ceiling_rect(36, 15, 40, 25, PY + ROOM_H, "concrete")
	b.wall_x(15, 36, 40, PY, ROOM_H, "exterior", "blocks")
	b.wall_z(40, 13, 25, PY, ROOM_H, "blocks", "exterior")
	PropFactory.pipe_run(b, Vector3(33.3, PY + 2.8, 13.3), Vector3(33.3, PY + 2.8, 24.7), 0.07)
	PropFactory.pipe_run(b, Vector3(35.7, PY + 2.6, 13.3), Vector3(35.7, PY + 2.6, 24.7), 0.04, "metal")


# --- Props ----------------------------------------------------------------------------------


func _props() -> void:
	var b := builder
	b.room = "concourse"
	for i in 11:
		FacilityProps.ticket_gate(b, Vector3(12.0 + i * 1.6, 0, 25.0), 0)
	FacilityProps.vending_machine(b, Vector3(6.55, 0, 22.4), 90)
	FacilityProps.vending_machine(b, Vector3(6.55, 0, 23.5), 90)
	FacilityProps.kiosk(b, Vector3(25.5, 0, 30.5), 180)
	FacilityProps.platform_bench(b, Vector3(20.0, 0, 27.6), 180)
	FacilityProps.platform_bench(b, Vector3(14.0, 0, 27.6), 180)
	PropFactory.debris(b, Vector3(18, 0, 30), 3.0, 14)
	b.room = "office"
	PropFactory.table(b, Vector3(8.5, 0, 31.5), 0, 1.6, 0.8, "painted_wood")
	PropFactory.chair(b, Vector3(8.5, 0, 30.7), 0)
	PropFactory.shelf(b, Vector3(6.3, 0, 29.0), 90, 1.6, 2.0, 0.4, "painted_wood")
	PropFactory.cabinet(b, Vector3(10.6, 0, 32.4), -90, 0.9, 1.1, 0.45, "metal_green")
	b.room = "platform"
	for x in [8.0, 20.0, 32.0]:
		FacilityProps.platform_bench(b, Vector3(x, PY, 12.3), 180)
	FacilityProps.signal_post(b, Vector3(0.6, PY, 7.7), 0)
	FacilityProps.signal_post(b, Vector3(39.4, PY, 7.7), 0)
	PropFactory.crate(b, Vector3(37.5, PY, 11.8), Vector3(0.9, 0.7, 0.8), 6, "metal_dark")
	FacilityProps.vending_machine(b, Vector3(2.6, PY, 12.55), 180)
	PropFactory.debris(b, Vector3(20, PY, 10), 6.0, 16)
	b.room = "corridor"
	PropFactory.crate(b, Vector3(34.5, PY, 24.3), Vector3(0.8, 0.6, 0.8), 12, "metal_dark")
	PropFactory.crate(b, Vector3(35.3, PY, 14.2), Vector3(0.7, 0.5, 0.7), -8, "metal_dark")
	b.room = "signal_box"
	PropFactory.table(b, Vector3(31.0, PY, 23.0), 0, 1.4, 0.8, "dark_wood")
	PropFactory.chair(b, Vector3(31.0, PY, 22.2), 0)
	PropFactory.workbench(b, Vector3(25.55, PY, 20.0), 90)
	for z in [17.0, 18.0]:
		PropFactory.part(b, Vector3(32.6, PY, z), -90, Vector3(0, 0.95, 0), Vector3(0.8, 1.9, 0.5), "metal_dark", true)
	b.room = "store"
	PropFactory.shelf(b, Vector3(39.55, PY, 18.0), -90, 1.8, 2.0, 0.45, "metal_dark")
	PropFactory.shelf(b, Vector3(39.55, PY, 22.0), -90, 1.8, 2.0, 0.45, "metal_dark")
	PropFactory.workbench(b, Vector3(37.5, PY, 24.55), 180)
	# Station name boards and a METHOD stencil on the platform wall.
	for x in [6.0, 26.0]:
		var board := Label3D.new()
		board.text = "KESSEL STREET"
		board.font_size = 64
		board.pixel_size = 0.004
		board.modulate = Color(0.9, 0.88, 0.82)
		board.shaded = true
		board.position = Vector3(x, PY + 2.6, 12.9)
		board.rotation.y = PI
		lights_root.add_child(board)
	var stencil := Label3D.new()
	stencil.text = "METHOD  —  TRANSIT ANNEX 03\nSERVICE SUSPENDED · AUDITORY TRIALS IN PROGRESS"
	stencil.font_size = 28
	stencil.pixel_size = 0.0022
	stencil.modulate = Color(0.62, 0.12, 0.09)
	stencil.shaded = true
	stencil.position = Vector3(20.0, 2.9, 21.1)
	lights_root.add_child(stencil)
	var plate := Label3D.new()
	plate.text = "PLATFORM 2  ·  EVACUATION SERVICE"
	plate.font_size = 32
	plate.pixel_size = 0.0025
	plate.modulate = Color(0.95, 0.75, 0.2)
	plate.shaded = true
	plate.position = Vector3(16.0, PY + 3.4, 12.9)
	plate.rotation.y = PI
	lights_root.add_child(plate)


# --- Lighting --------------------------------------------------------------------------------


func _lighting() -> void:
	var strips: Array = []
	for x in [9.0, 15.0, 21.0, 27.0]:
		strips.append(["concourse", Vector3(x, CH, 27.0)])
	for x in [4.0, 11.0, 18.0, 25.0, 32.0, 38.0]:
		strips.append(["platform", Vector3(x, PY + PLATFORM_H, 10.0)])
	# Trackside lighting so the tracks read once the power is back.
	for x in [8.0, 20.0, 32.0]:
		strips.append(["platform", Vector3(x, PY + PLATFORM_H, 3.5)])
	strips.append(["office", Vector3(8.5, ROOM_H, 29.5)])
	strips.append(["signal_box", Vector3(29.0, PY + ROOM_H, 20.0)])
	strips.append(["store", Vector3(38.0, PY + ROOM_H, 20.0)])
	strips.append(["corridor", Vector3(34.5, PY + ROOM_H, 19.0)])
	for lp in strips:
		var top: Vector3 = lp[1]
		builder.room = "fixtures"
		FacilityProps.strip_light(builder, top, 90.0)
		add_lamp(top + Vector3(0, -0.25, 0), lp[0], 1.3, Color(1.0, 0.92, 0.78), true, str(lp[0]) == "platform", 7.5)
	# Amber emergency lighting that survived on its own batteries.
	var amber := Color(1.0, 0.55, 0.15)
	for x in [6.0, 20.0, 34.0]:
		add_lamp(Vector3(x, PY + 3.0, 12.6), "platform", 0.7, amber, false, false, 6.5)
	add_lamp(Vector3(16.0, 2.2, 21.4), "concourse", 0.7, amber, false, false, 6.0)
	add_lamp(Vector3(24.0, 3.3, 32.4), "concourse", 0.6, amber, false, false, 6.0)
	add_lamp(Vector3(16.0, -1.0, 17.0), "stairs", 0.6, amber, false, false, 7.0)
	add_lamp(Vector3(34.5, PY + 2.8, 14.0), "corridor", 0.6, Color(0.9, 0.12, 0.08), false, false, 5.0)
	add_lamp(Vector3(26.0, PY + 2.8, 24.0), "signal_box", 0.5, Color(0.9, 0.12, 0.08), false, false, 5.0)
	# Signal lamps glow red in the tunnel mouths.
	add_lamp(Vector3(0.6, PY + 2.4, 7.4), "platform", 0.8, Color(1.0, 0.1, 0.06), false, false, 4.0)
	add_lamp(Vector3(39.4, PY + 2.4, 7.4), "platform", 0.8, Color(1.0, 0.1, 0.06), false, false, 4.0)
	add_dust(AABB(Vector3(0, PY, 0), Vector3(40, PLATFORM_H, 13)), 110)
	add_dust(AABB(Vector3(6, 0, 21), Vector3(24, CH, 12)), 70)
	apply_graphics_settings()


# --- Entities ----------------------------------------------------------------------------


func _entities() -> void:
	_door("door_office", Vector3(11, 0, 28.0), -90, 1.2)
	_door(
		"door_maint",
		Vector3(34.0, PY, 13),
		0,
		1.4,
		"item:maint_key",
		"DOOR_MAINT_LOCKED",
		{"material": "metal_dark", "unlock_flag": "maint_open"}
	)
	_door("door_signal_box", Vector3(33, PY, 19.0), -90, 1.2)
	_door("door_store", Vector3(36, PY, 19.0), -90, 1.2)

	var exit := InspectSpot.new()
	exit.entity_id = "street_exit"
	exit.flag = "exit_found"
	exit.message = "STATION_EXIT_COLLAPSED"
	exit.target_size = Vector3(5.5, 2.6, 0.6)
	add_entity(exit, Transform3D(Basis(Vector3.UP, PI), Vector3(18.0, 1.4, 32.6)))
	var rack := ItemReceptacle.new()
	rack.entity_id = "battery_rack"
	add_entity(rack, Transform3D(Basis(Vector3.UP, PI / 2), Vector3(25.6, PY + 0.93, 20.0)))
	var frame := LeverFrame.new()
	frame.entity_id = "lever_frame"
	add_entity(frame, Transform3D(Basis.IDENTITY, Vector3(29.0, PY, 15.6)))
	var help := ControlConsole.new()
	help.entity_id = "help_point"
	help.style = "help_point"
	help.prompt_key = "PROMPT_HELP_POINT"
	help.done_prompt_key = "PROMPT_TRAIN_CALLED"
	help.required_flags = ["route_set"]
	help.set_flag = "train_called"
	help.missing_message = "HELP_POINT_NO_ROUTE"
	help.activate_sound = "radio_static"
	help.noise_radius = 8.0
	add_entity(help, Transform3D(Basis(Vector3.UP, PI), Vector3(21.6, PY + 1.4, 12.9)))
	evac_train = EvacTrain.new()
	evac_train.entity_id = "evac_train"
	evac_train.arrival_seconds = _arrival_seconds()
	add_entity(evac_train, Transform3D(Basis.IDENTITY, Vector3(20.0, PY, 7.0)))
	ghost_train = GhostTrain.new()
	ghost_train.entity_id = "ghost_train"
	ghost_train.track_from = Vector3(-45.0, PY - 1.0, 1.7)
	ghost_train.track_to = Vector3(85.0, PY - 1.0, 1.7)
	ghost_train.lure_z = 7.8
	ghost_train.lure_y = PY
	ghost_train.lure_x_range = Vector2(1.5, 38.5)
	add_entity(ghost_train, Transform3D.IDENTITY)
	var zone := EscapeZone.new()
	zone.match_ctrl = match_ctrl
	zone.required_flag = "train_arrived"
	zone.position = Vector3(20.0, PY + 1.2, 5.6)
	zone.setup_box(Vector3(14, 2.4, 2.2))
	add_child(zone)

	_note("note_route", Vector3(9.0, 0.78, 31.3), "NOTE_ROUTE_T", "NOTE_ROUTE_B", "clipboard", 5)
	_note("note_notice", Vector3(12.0, 1.5, 21.12), "NOTE_NOTICE_T", "NOTE_NOTICE_B", "wall", 0)
	_note("note_signalman", Vector3(30.6, PY + 0.78, 23.2), "NOTE_SIGNALMAN_T", "NOTE_SIGNALMAN_B", "paper", -10)
	_note("note_timetable", Vector3(1.3, PY + 1.5, 12.88), "NOTE_TIMETABLE_T", "NOTE_TIMETABLE_B", "wall", 180)
	_note("note_help", Vector3(22.4, PY + 1.5, 12.88), "NOTE_HELP_T", "NOTE_HELP_B", "wall", 180)
	var tape := TapeRecorder.new()
	tape.entity_id = "tape_signal"
	tape.line_keys = ["TAPE_STATION_1", "TAPE_STATION_2", "TAPE_STATION_3", "TAPE_STATION_4"]
	add_entity(tape, Transform3D(Basis(Vector3.UP, 0.2), Vector3(31.5, PY + 0.81, 23.1)))
	var files := {
		"file_office": Vector3(6.35, 1.53, 29.4),
		"file_kiosk": Vector3(24.9, 1.11, 30.8),
		"file_concourse": Vector3(14.4, 0.49, 27.6),
		"file_platform": Vector3(20.4, PY + 0.49, 12.3),
		"file_signal": Vector3(31.6, PY + 0.78, 22.8),
		"file_store": Vector3(36.9, PY + 0.93, 24.2),
	}
	for id in files:
		var c := CollectibleEntity.new()
		c.entity_id = id
		c.collectible_id = "station_" + str(id).substr(5)
		add_entity(c, Transform3D(Basis(Vector3.UP, 0.4), files[id]))

	_hide("hide_platform_w", Vector3(4.2, PY, 12.55), 180, "locker")
	_hide("hide_platform_e", Vector3(36.0, PY, 12.55), 180, "locker")
	_hide("hide_concourse", Vector3(29.55, 0, 22.4), -90, "locker")
	_hide("hide_office", Vector3(6.45, 0, 32.3), 90, "wardrobe")
	_hide("hide_signal", Vector3(25.45, PY, 23.8), 90, "locker")
	_hide("hide_store", Vector3(39.55, PY, 15.8), -90, "locker")
	_hide("hide_corridor", Vector3(33.45, PY, 23.2), 90, "locker")

	_switch("switch_office", "office", Vector3(10.91, 1.3, 27.4), -90)


func _arrival_seconds() -> float:
	match String(match_ctrl.difficulty.id):
		"story":
			return 40.0
		"hard":
			return 75.0
		"nightmare":
			return 90.0
	return 60.0


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
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(18.0, 0.05, 29.0)),
		Transform3D(Basis(Vector3.UP, 0.3), Vector3(17.0, 0.05, 29.6)),
		Transform3D(Basis(Vector3.UP, -0.3), Vector3(19.0, 0.05, 29.6)),
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(17.0, 0.05, 30.6)),
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(19.0, 0.05, 30.6)),
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(18.0, 0.05, 31.2)),
	]
	enemy_spawns = [
		Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(2.0, PY + 0.05, 10.0)),
		Transform3D(Basis(Vector3.UP, PI / 2), Vector3(38.0, PY + 0.05, 10.0)),
		Transform3D(Basis(Vector3.UP, 0.0), Vector3(28.0, 0.05, 22.5)),
		Transform3D(Basis(Vector3.UP, PI), Vector3(8.0, 0.05, 22.5)),
	]
	patrol_points = [
		Vector3(9, 0, 23),
		Vector3(27, 0, 23),
		Vector3(16, 0, 27),
		Vector3(26, 0, 28),
		Vector3(8.5, 0, 29.5),
		Vector3(16, 0, 22),
		Vector3(16, PY, 12),
		Vector3(3, PY, 10),
		Vector3(11, PY, 9),
		Vector3(20, PY, 9.5),
		Vector3(29, PY, 9),
		Vector3(37, PY, 10),
		Vector3(34.5, PY, 17),
		Vector3(34.5, PY, 23),
		Vector3(29, PY, 19),
		Vector3(38, PY, 20),
	]
	prowl_points = [
		Vector3(-3, PY, 3.5),
		Vector3(43, PY, 3.5),
		Vector3(18, 0, 35),
		Vector3(3, 0, 27),
		Vector3(33, 0, 27),
	]
	var spawns := {
		"sp_office_desk": Vector3(8.0, 0.78, 31.5),
		"sp_office_shelf": Vector3(6.35, 1.05, 28.6),
		"sp_kiosk_counter": Vector3(25.5, 1.11, 30.2),
		"sp_concourse_bench": Vector3(19.6, 0.49, 27.6),
		"sp_gate_ledge": Vector3(12.0, 1.15, 24.65),
		"sp_platform_bench_w": Vector3(7.6, PY + 0.49, 12.3),
		"sp_platform_bench_e": Vector3(32.4, PY + 0.49, 12.3),
		"sp_platform_crate": Vector3(37.5, PY + 0.71, 11.8),
		"sp_store_shelf_a": Vector3(39.5, PY + 1.05, 18.0),
		"sp_store_shelf_b": Vector3(39.5, PY + 1.05, 22.0),
		"sp_store_bench": Vector3(37.8, PY + 0.93, 24.2),
		"sp_signal_desk": Vector3(30.9, PY + 0.78, 23.0),
		"sp_corridor_crate": Vector3(34.5, PY + 0.61, 24.3),
		"bt_concourse": Vector3(20.5, 0.49, 27.6),
		"bt_office": Vector3(10.6, 1.14, 32.4),
		"bt_kiosk": Vector3(26.0, 1.11, 30.6),
		"bt_platform_w": Vector3(8.5, PY + 0.49, 12.3),
		"bt_platform_e": Vector3(31.6, PY + 0.49, 12.3),
		"bt_store": Vector3(39.5, PY + 1.53, 20.0),
		"bt_signal": Vector3(30.4, PY + 0.78, 23.2),
		"bt_corridor": Vector3(35.3, PY + 0.51, 14.2),
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
	var route_args: Array = []
	for reverse in puzzle.get("route", []):
		route_args.append("@LEVER_REVERSE" if bool(reverse) else "@LEVER_NORMAL")
	seed_state(mc, "note_route", {"args": route_args})
	var files: Array = puzzle.get("files", [])
	for id in StationRules.FILE_IDS:
		seed_state(mc, id, {"taken": false, "active": files.has(id)})


func authority_tick(_match: MatchController, delta: float) -> void:
	if evac_train:
		evac_train.authority_tick(delta)
	if ghost_train:
		ghost_train.authority_tick(delta)


static func _doorway(a: float, b: float) -> Dictionary:
	return {"from": a, "to": b, "top": DOOR_TOP}
