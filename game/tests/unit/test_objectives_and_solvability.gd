extends TestCase
## Objective dependency graph and item-placement solvability.

const HOUSE_RULES = preload("res://scripts/maps/house/house_rules.gd")
const WARD_RULES = preload("res://scripts/maps/ward/ward_rules.gd")


func _graph() -> ObjectiveGraph:
	var g := ObjectiveGraph.new()
	g.define("a", "A", "fa")
	g.define("b", "B", "fb", ["a"])
	var c := g.define("c", "C", "fc", ["b"])
	c.is_final = true
	var o := g.define("opt", "O", "fo")
	o.optional = true
	return g


func test_activation_order_and_completion() -> void:
	var g := _graph()
	var states := {}
	var flags := {}
	g.evaluate(states, flags, 0.0)
	assert_eq(int(states["a"]["state"]), ObjectiveGraph.State.ACTIVE)
	assert_eq(int(states["b"]["state"]), ObjectiveGraph.State.LOCKED)
	flags["fa"] = true
	g.evaluate(states, flags, 5.0)
	assert_eq(int(states["a"]["state"]), ObjectiveGraph.State.COMPLETE)
	assert_eq(int(states["b"]["state"]), ObjectiveGraph.State.ACTIVE)
	assert_eq(float(states["b"]["activated_at"]), 5.0)


func test_flag_set_early_completes_on_activation() -> void:
	var g := _graph()
	var states := {}
	var flags := {"fb": true}
	g.evaluate(states, flags, 0.0)
	assert_eq(int(states["b"]["state"]), ObjectiveGraph.State.LOCKED, "b locked until a completes")
	flags["fa"] = true
	g.evaluate(states, flags, 1.0)
	assert_eq(int(states["b"]["state"]), ObjectiveGraph.State.COMPLETE, "b completes immediately once active")
	assert_eq(int(states["c"]["state"]), ObjectiveGraph.State.ACTIVE)


func test_validation_detects_problems() -> void:
	var g := ObjectiveGraph.new()
	g.define("x", "X", "fx", ["y"])
	g.define("y", "Y", "fy", ["x"])
	var errors := g.validate()
	assert_true(errors.size() >= 2, "cycle and missing final expected")
	var joined := " ".join(errors)
	assert_true(joined.contains("cycle"), "cycle detected")
	assert_true(joined.contains("final"), "final objective check")
	var g2 := ObjectiveGraph.new()
	var opt := g2.define("o", "O", "fo")
	opt.optional = true
	var fin := g2.define("f", "F", "ff", ["o", "missing"])
	fin.is_final = true
	var e2 := " ".join(g2.validate())
	assert_true(e2.contains("unknown"), "unknown requirement")
	assert_true(e2.contains("depends on optional"), "required on optional")


func test_hint_tiers() -> void:
	var g := _graph()
	var def := g.get_def("a")
	def.hint_keys = ["h1", "h2"]
	assert_eq(g.hint_tier(def, 0.0, 50.0, 60.0), 0)
	assert_eq(g.hint_tier(def, 0.0, 61.0, 60.0), 1)
	assert_eq(g.hint_tier(def, 0.0, 500.0, 60.0), 2)
	assert_eq(g.hint_tier(def, 0.0, 500.0, 0.0), 0, "delay 0 disables hints")


func test_key_behind_its_own_door_is_unsolvable() -> void:
	var s := ReachabilitySolver.new()
	s.start_zone = "hall"
	s.goal_flag = "out"
	s.add_zone("hall")
	s.add_zone("vault", ["vault_key"])
	s.add_action("exit", "vault", {}, [], ["out"])
	assert_false(s.solve([{"item": "vault_key", "zone": "vault"}])["ok"], "key inside its own room")
	assert_true(s.solve([{"item": "vault_key", "zone": "hall"}])["ok"], "key outside")


func test_consumed_items_must_be_sufficient() -> void:
	var s := ReachabilitySolver.new()
	s.start_zone = "g"
	s.goal_flag = "power"
	s.add_zone("g")
	s.add_action("panel", "g", {"fuse": 3}, [], ["power"])
	var two := [{"item": "fuse", "zone": "g"}, {"item": "fuse", "zone": "g"}]
	assert_false(s.solve(two)["ok"])
	two.append({"item": "fuse", "zone": "g"})
	assert_true(s.solve(two)["ok"])


func test_house_rules_validate_cleanly() -> void:
	var rules: MapRules = HOUSE_RULES.new()
	rules.setup(1, Session.difficulty("normal"))
	assert_empty(rules.validate(), "house rules validation")


func test_tutorial_rules_validate_cleanly() -> void:
	var rules: MapRules = load("res://scripts/maps/tutorial/tutorial_rules.gd").new()
	rules.setup(1, Session.difficulty("story"))
	assert_empty(rules.validate(), "tutorial rules validation")


func test_house_every_seed_is_solvable_and_deterministic() -> void:
	var rules: MapRules = HOUSE_RULES.new()
	rules.setup(2, Session.difficulty("hard"))
	for seed_value in 300:
		var v := rules.generate_variant(seed_value * 7919 + 13)
		assert_false(v.is_empty(), "variant for seed %d" % seed_value)
		if v.is_empty():
			return
		assert_true(rules.is_solvable(v["placements"]), "seed %d solvable" % seed_value)
		var used := {}
		for slot in v["placements"]:
			var sp: String = v["placements"][slot]
			assert_false(used.has(sp), "spawn reused for seed %d" % seed_value)
			used[sp] = true
		var code: String = v["puzzle"]["code"]
		assert_eq(code.length(), 4)
	var a := rules.generate_variant(42)
	var b := rules.generate_variant(42)
	assert_eq(JSON.stringify(a), JSON.stringify(b), "same seed → same variant")


func test_house_code_matches_clues() -> void:
	var rules: MapRules = HOUSE_RULES.new()
	rules.setup(1, Session.difficulty("normal"))
	var p: Dictionary = rules.generate_variant(1234)["puzzle"]
	var expected := ""
	for sym in p["keypad_order"]:
		expected += str(p["clue_digits"][(p["clue_symbols"] as Array).find(sym)])
	assert_eq(p["code"], expected)


func test_validator_catches_broken_candidate() -> void:
	var rules: MapRules = HOUSE_RULES.new()
	rules.setup(1, Session.difficulty("normal"))
	# A study key that spawns inside the locked study must be rejected.
	rules.item_slots[0]["candidates"] = PackedStringArray(["sp_kitchen_drawer", "sp_study_desk"])
	var joined := " ".join(rules.validate())
	assert_true(joined.contains("sp_study_desk"), "validator must flag the key-behind-its-door candidate")


func test_every_playable_map_validates() -> void:
	for map in Session.maps:
		if not map.is_playable():
			continue
		var rules: MapRules = map.rules_script.new()
		rules.setup(4, Session.difficulty("hard"))
		assert_empty(rules.validate(), "%s rules validation" % map.id)


func test_ward_every_seed_is_solvable_and_consistent() -> void:
	var rules: MapRules = WARD_RULES.new()
	rules.setup(2, Session.difficulty("normal"))
	for seed_value in 300:
		var v := rules.generate_variant(seed_value * 104729 + 7)
		assert_false(v.is_empty(), "variant for seed %d" % seed_value)
		if v.is_empty():
			return
		assert_true(rules.is_solvable(v["placements"]), "seed %d solvable" % seed_value)
		var p: Dictionary = v["puzzle"]
		var live := 0
		for on in p["circuit"]:
			live += 1 if bool(on) else 0
		assert_true(live >= 2 and live <= 3, "two or three live circuits (seed %d)" % seed_value)
		var expected := ""
		for bed in p["round_order"]:
			expected += str(p["bed_digits"][int(bed) - 1])
		assert_eq(p["code"], expected, "code = bed readings in round order (seed %d)" % seed_value)
		var used := {}
		for slot in v["placements"]:
			assert_false(used.has(v["placements"][slot]), "spawn reused for seed %d" % seed_value)
			used[v["placements"][slot]] = true
	assert_eq(JSON.stringify(rules.generate_variant(9)), JSON.stringify(rules.generate_variant(9)), "deterministic")


func test_ward_validator_catches_card_behind_its_own_door() -> void:
	var rules: MapRules = WARD_RULES.new()
	rules.setup(1, Session.difficulty("normal"))
	# A staff card spawning in the staff wing could never be reached.
	rules.item_slots[0]["candidates"] = PackedStringArray(["sp_ward_cabinet", "sp_staff_table"])
	assert_true(" ".join(rules.validate()).contains("sp_staff_table"), "validator flags the staff card behind its door")
