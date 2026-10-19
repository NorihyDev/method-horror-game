extends HouseFixture
## Furniture faces the way it would in real life: chairs face the table or
## desk they stand at, cabinets, sofas, shelves and the stove turn their
## fronts to the room (not the wall), and pictures hang with their backs to
## the wall. Models face +Z (the game's convention for furniture).

const SEATS := ["ArmChair_01", "SchoolChair_01", "painted_wooden_chair_02"]
const TABLES := ["dining_table", "small_wooden_table_01", "SchoolDesk_01", "metal_office_desk", "WoodenTable_03"]
const AGAINST_WALL := [
	"ArmChair_01",
	"sofa_03",
	"vintage_day_bed",
	"painted_wooden_cabinet",
	"vintage_wooden_drawer_01",
	"wooden_bookshelf_worn",
	"electric_stove",
	"metal_tool_chest",
	"vintage_grandfather_clock_01",
	"WoodenTable_03",
	"metal_office_desk",
]
const ON_WALL := ["hanging_picture_frame_01", "wall_clock"]


func test_furniture_faces_the_right_way_on_every_map() -> void:
	for m in Session.maps:
		if m.is_playable():
			await _check(String(m.id))


func _check(map_id: String) -> void:
	if not await build(map_id, "normal", 5):
		return
	await frames(3)
	var props := get_tree().get_nodes_in_group(PropModels.PLACED)
	var tables: Array[Node3D] = []
	for n: Node3D in props:
		if str(n.get_meta("prop")) in TABLES:
			tables.append(n)
	var wrong: PackedStringArray = []
	for n: Node3D in props:
		var id := str(n.get_meta("prop"))
		if bool(n.get_meta("lying", false)):
			continue
		var fwd := n.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var at := n.global_position
		var where := (
			"%s %s at %s facing %d°" % [map_id, id, at.snapped(Vector3.ONE * 0.1), int(rad_to_deg(atan2(fwd.x, fwd.z)))]
		)
		if id in SEATS:
			var near := _nearest(at, tables, 0.75)
			if near:
				var to := _closest_on(near, at) - at
				to.y = 0.0
				if to.length() > 0.05 and fwd.dot(to.normalized()) < 0.2:
					wrong.append(where + ": turned away from its " + str(near.get_meta("prop")))
					continue
			elif _wall(at, fwd, 0.55) and not _wall(at, -fwd, 0.55):
				wrong.append(where + ": seat faces the wall")
				continue
		if id == "old_bed_frame":
			# Headboard (-Z) to the wall, foot end to the room.
			if _wall(at, fwd, 1.3) and not _wall(at, -fwd, 1.3):
				wrong.append(where + ": foot end against the wall")
		if id in AGAINST_WALL:
			var reach := 0.75
			if _wall(at, fwd, reach) and not _wall(at, -fwd, reach):
				wrong.append(where + ": front against the wall, back to the room")
		if id in ON_WALL:
			var c := at + n.global_basis.y.normalized() * 0.2
			if _wall(c - Vector3(0, 0.6, 0), fwd, 0.3) and not _wall(c - Vector3(0, 0.6, 0), -fwd, 0.3):
				wrong.append(where + ": hangs facing the wall")
	for w in wrong:
		print("  WRONG WAY ", w)
	assert_empty(wrong, "%s: furniture facing the wrong way" % map_id)
	map.queue_free()
	map = null
	await frames(2)


## The table or desk whose edge is nearest (within `within` metres).
func _nearest(at: Vector3, nodes: Array[Node3D], within: float) -> Node3D:
	var best: Node3D = null
	var best_d := within
	for n in nodes:
		var p := _closest_on(n, at)
		var d := Vector2(p.x - at.x, p.z - at.z).length()
		if d < best_d:
			best_d = d
			best = n
	return best


## Closest point of a model's footprint to `at` (world AABB of its meshes).
func _closest_on(n: Node3D, at: Vector3) -> Vector3:
	var box := AABB()
	var first := true
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var b := mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return Vector3(clampf(at.x, box.position.x, box.end.x), at.y, clampf(at.z, box.position.z, box.end.z))


## A wall within `reach` of the piece's middle, at chest height.
func _wall(at: Vector3, dir: Vector3, reach: float) -> bool:
	var from := at + Vector3(0, 0.6, 0)
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach, GeoBuilder.LAYER_WORLD)
	return not map.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
