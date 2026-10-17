class_name DecalScatter
extends RefCounted
## Dresses every room with a few decals: dried blood, drag marks and drips,
## bloody handprints, claw scratches, tally marks, water stains and grime.
## Placement is seeded per map, so every player sees the same marks, and
## purely visual (no collision, no effect on rules).

const DIR := "res://assets/generated/decals/"
## name -> [where ("floor"/"wall"), size range (m), weight]
const KINDS := {
	"blood_splat_1": ["floor", Vector2(0.9, 1.5), 1.0],
	"blood_splat_2": ["floor", Vector2(0.8, 1.3), 0.8],
	"blood_splat_3": ["floor", Vector2(1.0, 1.6), 0.8],
	"blood_smear": ["floor", Vector2(1.6, 2.4), 0.8],
	"water_stain": ["floor", Vector2(1.2, 2.2), 1.0],
	"grime": ["wall", Vector2(1.0, 1.8), 1.2],
	"blood_drips": ["wall", Vector2(0.9, 1.3), 0.9],
	"handprints": ["wall", Vector2(0.7, 1.0), 0.8],
	"scratches": ["wall", Vector2(0.8, 1.2), 0.9],
	"tally_marks": ["wall", Vector2(0.7, 1.0), 0.5],
}
## Kinds that are not blood: the only ones in the tutorial.
const CLEAN: Array[String] = ["water_stain", "grime", "tally_marks"]
const MAX_PER_ROOM := 6
const ATTEMPTS := 5
const FADE_BEGIN := 13.0

static var _textures: Dictionary = {}


static func scatter(map: MapBase, seed_value: int, clean_only: bool = false) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var space := map.get_world_3d().direct_space_state
	var placed := 0
	var ids := map.rooms.keys()
	ids.sort()
	for id in ids:
		var box: AABB = map.rooms[id]["aabb"]
		var area := box.size.x * box.size.z
		var count := clampi(int(area / 14.0) + rng.randi_range(0, 2), 2, MAX_PER_ROOM)
		for i in count:
			var kind := _pick(rng, clean_only)
			# A random spot can miss (a doorway, a table top): try a few.
			for attempt in ATTEMPTS:
				if _place(map, space, box, kind, rng):
					placed += 1
					break
	return placed


static func _pick(rng: RandomNumberGenerator, clean_only: bool) -> String:
	var total := 0.0
	for k in KINDS:
		if not clean_only or k in CLEAN:
			total += float(KINDS[k][2])
	var r := rng.randf() * total
	for k in KINDS:
		if clean_only and not k in CLEAN:
			continue
		r -= float(KINDS[k][2])
		if r <= 0.0:
			return k
	return "grime"


static func _place(
	map: MapBase, space: PhysicsDirectSpaceState3D, box: AABB, kind: String, rng: RandomNumberGenerator
) -> bool:
	var spec: Array = KINDS[kind]
	var size := rng.randf_range(spec[1].x, spec[1].y)
	var inner := box.grow(-0.6)
	if inner.size.x <= 0.0 or inner.size.z <= 0.0:
		return false
	var x := rng.randf_range(inner.position.x, inner.end.x)
	var z := rng.randf_range(inner.position.z, inner.end.z)
	var hit: Dictionary
	if spec[0] == "floor":
		hit = _ray(space, Vector3(x, box.position.y + 1.2, z), Vector3(x, box.position.y - 0.4, z))
		if hit.is_empty() or (hit["normal"] as Vector3).y < 0.85:
			return false
	else:
		var from := Vector3(x, box.position.y + rng.randf_range(0.9, 1.8), z)
		var dir := Vector3.FORWARD.rotated(Vector3.UP, rng.randf() * TAU)
		hit = _ray(space, from, from + dir * 6.0)
		if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.2 or not box.grow(0.3).has_point(hit["position"]):
			return false
	var normal: Vector3 = hit["normal"]
	var d := Decal.new()
	d.name = "Decal_" + kind
	d.set_meta("kind", kind)
	d.texture_albedo = _texture(kind)
	d.size = Vector3(size, 0.4, size * (0.6 if kind == "blood_smear" else 1.0))
	d.normal_fade = 0.35
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.distance_fade_enabled = true
	d.distance_fade_begin = FADE_BEGIN
	d.distance_fade_length = 4.0
	d.modulate = Color(1, 1, 1, rng.randf_range(0.75, 1.0))
	map.lights_root.add_child(d)
	if spec[0] == "floor":
		d.global_position = (hit["position"] as Vector3) + Vector3(0, 0.05, 0)
		d.rotation.y = rng.randf() * TAU
	else:
		# Decals project down their -Y: point Y out of the wall and Z down it,
		# so drips run toward the floor.
		var down := Vector3.DOWN
		var basis := Basis(normal.cross(down), normal, down)
		d.global_transform = Transform3D(basis, (hit["position"] as Vector3) + normal * 0.08)
	return true


static func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, GeoBuilder.LAYER_WORLD))


static func _texture(kind: String) -> Texture2D:
	if not _textures.has(kind):
		_textures[kind] = load(DIR + kind + ".png")
	return _textures[kind]
