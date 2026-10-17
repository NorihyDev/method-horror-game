extends HouseFixture
## Rooms get dressed with decals once the level is built, the same way on
## every peer, and the tutorial gets no blood.


func _decals() -> Array[Node]:
	return map.find_children("*", "Decal", true, false)


func test_rooms_get_decals_deterministically() -> void:
	if not await build("house"):
		return
	await frames(10)
	var first := _decals().map(func(d: Node) -> String: return "%s %s" % [d.name, (d as Decal).global_position])
	assert_true(first.size() >= map.rooms.size(), "about one decal per room or more (%d)" % first.size())
	var again := DecalScatter.scatter(map, hash("house"))
	assert_eq(again, first.size(), "same seed, same number placed")


func test_tutorial_has_no_blood() -> void:
	if not await build("tutorial"):
		return
	await frames(6)
	for d in _decals():
		assert_true(str(d.get_meta("kind")) in DecalScatter.CLEAN, "%s in the tutorial" % d.get_meta("kind"))
