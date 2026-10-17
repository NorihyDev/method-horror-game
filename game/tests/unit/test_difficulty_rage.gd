extends TestCase
## Rage: the enemy sharpens the longer it hunts, capped per difficulty.


func _diff(id: String) -> DifficultyDefinition:
	return load("res://resources/difficulties/%s.tres" % id)


func test_story_has_no_rage() -> void:
	assert_eq(_diff("story").rage(60.0), 1.0)


func test_rage_grows_then_caps() -> void:
	var normal := _diff("normal")
	assert_eq(normal.rage(0.0), 1.0, "nothing at arrival")
	assert_true(normal.rage(5.0) > 1.0, "grows over minutes")
	assert_true(absf(normal.rage(500.0) - (1.0 + normal.rage_cap)) < 0.0001, "capped")


func test_harder_means_angrier() -> void:
	var last := 0.0
	for id in ["story", "normal", "hard", "nightmare"]:
		var r := _diff(id).rage(30.0)
		assert_true(r >= last, "%s at least as angry as the easier one" % id)
		last = r
	assert_true(_diff("nightmare").rage(30.0) > _diff("normal").rage(30.0), "nightmare clearly angrier")
