extends MapBase
## "METHOD Orientation Wing" — a short, safe tutorial corridor.
## Rooms along +Z: A (0-6) start · B (6-12) dark room with keycard ·
## C (12-18) locker + code clues + keypad · D (18-24) exit.

const H := 2.8


func build_level() -> void:
	prepare()
	configure_environment(Color(0.22, 0.24, 0.3), 1.2, Color(0.03, 0.03, 0.04), 0.02)
	var b := builder
	add_room("a", AABB(Vector3(0, 0, 0), Vector3(6, H, 6)), "concrete")
	add_room("b", AABB(Vector3(0, 0, 6), Vector3(6, H, 6)), "wood")
	add_room("c", AABB(Vector3(0, 0, 12), Vector3(6, H, 6)), "concrete")
	add_room("d", AABB(Vector3(0, 0, 18), Vector3(6, H, 6)), "concrete")
	for r in [["a", 0.0, "concrete_floor", "blocks"], ["b", 6.0, "wood_floor", "wallpaper"],
			["c", 12.0, "concrete_floor", "plaster"], ["d", 18.0, "concrete_floor", "blocks"]]:
		b.room = r[0]
		var z0: float = r[1]
		b.floor_rect(0, z0, 6, z0 + 6, 0.0, r[2])
		b.ceiling_rect(0, z0, 6, z0 + 6, H, "ceiling")
		b.wall_z(0, z0, z0 + 6, 0, H, "exterior", r[3])
		b.wall_z(6, z0, z0 + 6, 0, H, r[3], "exterior")
	b.room = "walls"
	b.wall_x(0, 0, 6, 0, H, "exterior", "blocks")
	b.wall_x(6, 0, 6, 0, H, "blocks", "wallpaper", [{"from": 2.4, "to": 3.6, "top": 2.2}])
	b.wall_x(12, 0, 6, 0, H, "wallpaper", "plaster", [{"from": 2.4, "to": 3.6, "top": 2.2}])
	b.wall_x(18, 0, 6, 0, H, "plaster", "blocks", [{"from": 2.4, "to": 3.6, "top": 2.2}])
	b.wall_x(24, 0, 6, 0, H, "blocks", "exterior", [{"from": 2.2, "to": 3.8, "top": 2.3}])
	b.room = "b"
	PropFactory.rng.seed = 99
	PropFactory.table(b, Vector3(1.4, 0, 8.5), 90, 1.2, 0.7)
	PropFactory.shelf(b, Vector3(5.75, 0, 10.0), -90, 1.4, 2.0)
	PropFactory.chair(b, Vector3(4.0, 0, 7.5), 30, true)
	PropFactory.debris(b, Vector3(3, 0, 9), 2.0, 8)
	b.room = "c"
	PropFactory.crate(b, Vector3(1.0, 0, 16.8), Vector3(0.8, 0.7, 0.8))
	# Lights: A and D lit; B dark (flashlight lesson); C emergency red.
	add_lamp(Vector3(3, 2.3, 3), "a", 1.3, Color(1.0, 0.85, 0.7), false)
	add_lamp(Vector3(3, 2.3, 21), "d", 1.4, Color(0.85, 0.9, 1.0), false)
	add_lamp(Vector3(5.6, 2.4, 15), "c", 0.9, Color(0.9, 0.12, 0.08), false, false, 6.0)
	add_dust(AABB(Vector3(0, 0, 0), Vector3(6, H, 24)), 50)
	_signs()
	_entities()
	player_spawns = [Transform3D(Basis(Vector3.UP, PI), Vector3(3, 0.05, 1.2))]
	patrol_points = [Vector3(3, 0, 3)]
	add_spawn_point("tsp_b_table", Transform3D(Basis.IDENTITY, Vector3(1.4, 0.77, 8.3)))
	add_spawn_point("tsp_b_shelf", Transform3D(Basis.IDENTITY, Vector3(5.7, 1.06, 10.0)))
	finalize()


func _sign(text_key: String, pos: Vector3, rot: float, size: int = 30) -> void:
	var l := Label3D.new()
	l.text = tr(text_key)
	l.font_size = size
	l.pixel_size = 0.0025
	l.width = 900
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = Color(0.85, 0.82, 0.74)
	l.outline_size = 6
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.position = pos
	l.rotation.y = rot
	lights_root.add_child(l)


func _signs() -> void:
	var touch := TouchControls.should_show()
	_sign("TUT_SIGN_MOVE_TOUCH" if touch else "TUT_SIGN_MOVE", Vector3(3, 1.7, 5.9), PI)
	_sign("TUT_SIGN_LIGHT_TOUCH" if touch else "TUT_SIGN_LIGHT", Vector3(0.1, 1.6, 7.5), PI / 2)
	_sign("TUT_SIGN_HIDE", Vector3(5.9, 1.9, 13.4), -PI / 2)
	_sign("TUT_SIGN_CODE", Vector3(0.1, 2.3, 15.0), PI / 2)
	_sign("TUT_SIGN_EXIT", Vector3(3, 2.45, 23.9), PI)
	var title := Label3D.new()
	title.text = "METHOD — ORIENTATION WING"
	title.font_size = 44
	title.pixel_size = 0.003
	title.modulate = Color(0.6, 0.08, 0.06)
	title.position = Vector3(3, 2.3, 0.1)
	lights_root.add_child(title)


func _entities() -> void:
	var zone := FlagZone.new()
	zone.flag = "t_moved"
	zone.match_ctrl = match_ctrl
	zone.position = Vector3(3, 1, 7.0)
	zone.setup_box(Vector3(5.6, 2, 1.0))
	add_child(zone)
	var d1 := DoorEntity.new()
	d1.entity_id = "t_door_ab"
	add_entity(d1, Transform3D(Basis.IDENTITY, Vector3(2.4, 0, 6)))
	var d2 := DoorEntity.new()
	d2.entity_id = "t_door_bc"
	d2.lock = "item:orientation_key"
	d2.locked_message = "TDOOR_KEYCARD"
	d2.unlock_flag = "t_door"
	d2.material = "metal_dark"
	add_entity(d2, Transform3D(Basis.IDENTITY, Vector3(2.4, 0, 12)))
	var d3 := DoorEntity.new()
	d3.entity_id = "t_door_cd"
	d3.lock = "external"
	d3.locked_message = "TDOOR_CODE"
	d3.material = "metal_dark"
	add_entity(d3, Transform3D(Basis.IDENTITY, Vector3(2.4, 0, 18)))
	var note := NoteEntity.new()
	note.entity_id = "t_note"
	note.title_key = "TNOTE_T"
	note.body_key = "TNOTE_B"
	note.style = "clipboard"
	add_entity(note, Transform3D(Basis.IDENTITY, Vector3(1.0, 0.77, 9.0)))
	var locker := HidingSpot.new()
	locker.entity_id = "t_locker"
	locker.hide_flag = "t_hidden"
	add_entity(locker, Transform3D(Basis(Vector3.UP, -PI / 2), Vector3(5.55, 0, 14.4)))
	var clue_positions := [Vector3(0.09, 1.5, 13.4), Vector3(0.09, 1.5, 14.6), Vector3(0.09, 1.5, 15.8), Vector3(0.09, 1.5, 17.0)]
	for i in 4:
		var c := ClueMark.new()
		c.entity_id = "t_clue_%d" % i
		add_entity(c, Transform3D(Basis(Vector3.UP, PI / 2), clue_positions[i]))
	var keypad := KeypadEntity.new()
	keypad.entity_id = "t_keypad"
	keypad.target_door = "t_door_cd"
	keypad.success_flag = "t_code"
	add_entity(keypad, Transform3D(Basis(Vector3.UP, PI), Vector3(4.2, 1.35, 17.9)))
	var exit := EscapeZone.new()
	exit.required_flag = ""
	exit.match_ctrl = match_ctrl
	exit.position = Vector3(3, 1, 23.3)
	exit.setup_box(Vector3(2.0, 2, 0.8))
	add_child(exit)


func apply_variant(mc: MatchController, variant: Dictionary) -> void:
	if not mc.is_authority or variant.is_empty():
		return
	for slot in variant.get("placements", {}):
		place_pickup_state(mc, "pickup_" + str(slot), mc.rules.item_for_slot(slot), variant["placements"][slot])
	var puzzle: Dictionary = variant.get("puzzle", {})
	for i in 4:
		seed_state(mc, "t_clue_%d" % i, {"digit": int(puzzle["clue_digits"][i]), "symbol": int(puzzle["clue_symbols"][i])})
	seed_state(mc, "t_keypad", {"solved": false, "order": puzzle.get("keypad_order", [])})
