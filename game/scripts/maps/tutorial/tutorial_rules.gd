extends MapRules
## Orientation tutorial: safe, no hostile enemy. Teaches movement, the
## flashlight, keycards and locked doors, notes, hiding and the keypad clues.


func setup(p_player_count: int, p_difficulty: DifficultyDefinition) -> void:
	super.setup(p_player_count, p_difficulty)
	var o := graph.define("t_move", "TOBJ_MOVE", "t_moved")
	o.hint_keys = ["THINT_MOVE"]
	o = graph.define("t_key", "TOBJ_KEY", "t_door", ["t_move"])
	o.hint_keys = ["THINT_KEY_1", "THINT_KEY_2"]
	o = graph.define("t_hide", "TOBJ_HIDE", "t_hidden", ["t_key"])
	o.hint_keys = ["THINT_HIDE"]
	o = graph.define("t_code", "TOBJ_CODE", "t_code", ["t_hide"])
	o.hint_keys = ["THINT_CODE_1", "THINT_CODE_2"]
	o = graph.define("t_exit", "TOBJ_EXIT", "escaped", ["t_code"])
	o.is_final = true
	o.hint_keys = ["THINT_EXIT"]
	solver.start_zone = "a"
	solver.goal_flag = "escaped"
	solver.add_zone("a")
	solver.add_zone("b")
	solver.add_zone("c", ["orientation_key"])
	solver.add_zone("d", [], ["t_code"])
	solver.add_action("keypad", "c", {}, [], ["t_code"])
	solver.add_action("exit", "d", {}, [], ["escaped"])
	add_spawn("tsp_b_table", "b")
	add_spawn("tsp_b_shelf", "b")
	add_slot("key", "orientation_key", ["tsp_b_table", "tsp_b_shelf"])


func generate_puzzle(rng: RandomNumberGenerator) -> Dictionary:
	var symbols := [0, 1, 2, 3]
	var digits := []
	for i in 4:
		digits.append(rng.randi_range(1, 9))
	var order := [2, 0, 3, 1]
	var code := ""
	for sym in order:
		code += str(digits[symbols.find(sym)])
	return {"clue_symbols": symbols, "clue_digits": digits, "keypad_order": order, "code": code}
