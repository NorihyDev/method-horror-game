extends HouseFixture
## No object blocks the way: on every map, with every door open, the player
## can walk from the spawn to within arm's reach (and sight) of every item
## spot, every interactable and every patrol point.
##
## Pure geometry, no navigation mesh: a 0.25 m grid over every room; a cell
## counts if the player's own capsule (crouched) fits on the floor there; two
## neighbouring cells connect if the step between them is climbable and the
## capsule fits between them. A flood fill from the spawn gives every place a
## player can actually get to.

const CELL := 0.25
const MAX_STEP := 0.35
const REACH := 2.1
const EYE := 1.5
const MASK := GeoBuilder.LAYER_WORLD | GeoBuilder.LAYER_PROP

var _space: PhysicsDirectSpaceState3D
var _capsule := PhysicsShapeQueryParameters3D.new()
## Vector3i(ix, iz, level) -> floor height, for standable cells.
var _cells: Dictionary = {}
## Vector2i(ix, iz) -> Array of reached floor heights.
var _reached: Dictionary = {}


func test_every_map_is_walkable_end_to_end() -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = PlayerController.RADIUS
	shape.height = PlayerController.CROUCH_HEIGHT
	_capsule.shape = shape
	_capsule.collision_mask = MASK
	for m in Session.maps:
		if m.is_playable():
			await _check_map(String(m.id))


func _check_map(map_id: String) -> void:
	if not await build(map_id, "normal", 7):
		return
	# Unlocked doors are on their own layer, which the player can open, so
	# their panels never count as obstacles here.
	for ent in mc.entities.values():
		if ent is DoorEntity:
			mc.set_entity_state((ent as DoorEntity).entity_id, {"open": true, "locked": false})
	await frames(30)
	_space = map.get_world_3d().direct_space_state
	_cells.clear()
	_reached.clear()
	for room in map.rooms.values():
		_scan(room["aabb"])
	_flood(map.player_spawn(0).origin)
	var targets := {}
	for id in map.spawn_points:
		# Spots inside drawers are relative to the drawer; the drawer itself is checked.
		if str(map.spawn_points[id].get("drawer", "")).is_empty():
			targets["item spot " + str(id)] = (map.spawn_points[id]["xform"] as Transform3D).origin
	for ent in mc.entities.values():
		var e := ent as Interactable
		if e == null or not e.is_inside_tree() or _look_only(e):
			continue
		targets["%s %s" % [_kind(e), e.entity_id]] = e.interact_origin()
	for i in map.patrol_points.size():
		targets["patrol point %d" % i] = map.patrol_points[i] + Vector3(0, EYE, 0)
	var problems: PackedStringArray = []
	for label in targets:
		if not _reachable(targets[label]):
			problems.append("%s at %s" % [label, (targets[label] as Vector3).snapped(Vector3.ONE * 0.1)])
	for p in problems:
		print("  BLOCKED %s: %s" % [map_id, p])
	assert_empty(problems, "%s: places a player cannot reach" % map_id)
	map.queue_free()
	map = null
	await frames(2)


## Things that are seen or heard, not walked up to.
static func _look_only(e: Interactable) -> bool:
	return e is ClueMark or e is GhostTrain or e is EvacTrain or e is PickupEntity or e.global_position.y < -4.0


static func _kind(e: Interactable) -> String:
	var script := e.get_script() as Script
	return script.resource_path.get_file().get_basename() if script else e.get_class()


func _scan(box: AABB) -> void:
	var top := box.position.y + box.size.y - 0.15
	for ix in range(floori(box.position.x / CELL), ceili(box.end.x / CELL)):
		for iz in range(floori(box.position.z / CELL), ceili(box.end.z / CELL)):
			var x := (ix + 0.5) * CELL
			var z := (iz + 0.5) * CELL
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, top, z), Vector3(x, box.position.y - 0.6, z), MASK)
			var hit := _space.intersect_ray(q)
			if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
				continue
			var y: float = (hit["position"] as Vector3).y
			if _fits(Vector3(x, y, z)):
				_cells[Vector3i(ix, iz, roundi(y * 4.0))] = y


func _fits(foot: Vector3) -> bool:
	_capsule.transform = Transform3D(Basis.IDENTITY, foot + Vector3(0, PlayerController.CROUCH_HEIGHT * 0.5 + 0.06, 0))
	return _space.intersect_shape(_capsule, 1).is_empty()


func _flood(spawn: Vector3) -> void:
	var start := Vector3i.ZERO
	var best := INF
	for key: Vector3i in _cells:
		var d := Vector3((key.x + 0.5) * CELL, float(_cells[key]), (key.y + 0.5) * CELL).distance_to(spawn)
		if d < best:
			best = d
			start = key
	var seen := {start: true}
	var queue: Array[Vector3i] = [start]
	while not queue.is_empty():
		var c: Vector3i = queue.pop_back()
		var y: float = _cells[c]
		var col := Vector2i(c.x, c.y)
		if not _reached.has(col):
			_reached[col] = []
		(_reached[col] as Array).append(y)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			for dl in range(-2, 3):
				var n := Vector3i(c.x + d.x, c.y + d.y, c.z + dl)
				if seen.has(n) or not _cells.has(n):
					continue
				var ny: float = _cells[n]
				if absf(ny - y) > MAX_STEP:
					continue
				var mid := Vector3((c.x + n.x + 1) * 0.5 * CELL, maxf(y, ny), (c.y + n.y + 1) * 0.5 * CELL)
				if not _fits(mid):
					continue
				seen[n] = true
				queue.append(n)


## Some reached spot within arm's reach of `target`, with a clear view of it.
func _reachable(target: Vector3) -> bool:
	var r := ceili(REACH / CELL)
	var cx := floori(target.x / CELL)
	var cz := floori(target.z / CELL)
	for ix in range(cx - r, cx + r + 1):
		for iz in range(cz - r, cz + r + 1):
			for y in _reached.get(Vector2i(ix, iz), []):
				var eye := Vector3((ix + 0.5) * CELL, float(y) + EYE, (iz + 0.5) * CELL)
				if eye.distance_to(target) > REACH:
					continue
				var los := PhysicsRayQueryParameters3D.create(eye, target, GeoBuilder.LAYER_WORLD)
				var block := _space.intersect_ray(los)
				if block.is_empty() or (block["position"] as Vector3).distance_to(target) < 0.3:
					return true
	return false
