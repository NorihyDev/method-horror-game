extends MapRules
## The Abandoned House — objective chain, solvability model and seeded variants.
##
## Chain: find a way out → restore power (3 fuses, circuit clue) → open the
## basement cage (code from painted digits) → repair the garage motor (belt +
## gear at the workbench) → crank-start the motor (timing) → escape.

const CLUE_IDS: PackedStringArray = ["clue_kitchen", "clue_living", "clue_garage", "clue_basement"]
const FILE_IDS: PackedStringArray = ["file_kitchen", "file_living", "file_study", "file_garage", "file_utility", "file_basement"]
const BATTERY_SPAWNS: PackedStringArray = [
	"bt_kitchen", "bt_hall", "bt_living", "bt_garage", "bt_utility", "bt_basement", "bt_foyer", "bt_dining",
]
const FILES_NEEDED := 3


func setup(p_player_count: int, p_difficulty: DifficultyDefinition) -> void:
	super.setup(p_player_count, p_difficulty)
	_objectives()
	_solvability()


func _objectives() -> void:
	var o := graph.define("explore", "OBJ_EXPLORE", "exit_found")
	o.hint_keys = ["HINT_EXPLORE_1", "HINT_EXPLORE_2"]
	o = graph.define("power", "OBJ_POWER", "power_on", ["explore"])
	o.counter = "fuses_installed"
	o.counter_target = 3
	o.hint_keys = ["HINT_POWER_1", "HINT_POWER_2", "HINT_POWER_3"]
	o = graph.define("cage", "OBJ_CAGE", "cage_open", ["power"])
	o.hint_keys = ["HINT_CAGE_1", "HINT_CAGE_2", "HINT_CAGE_3"]
	o = graph.define("repair", "OBJ_REPAIR", "motor_repaired", ["cage"])
	o.hint_keys = ["HINT_REPAIR_1", "HINT_REPAIR_2", "HINT_REPAIR_3"]
	o = graph.define("start", "OBJ_START", "garage_open", ["repair"])
	o.hint_keys = ["HINT_START_1", "HINT_START_2"]
	o = graph.define("escape", "OBJ_ESCAPE", "escaped", ["start"])
	o.is_final = true
	o.hint_keys = ["HINT_ESCAPE_1"]
	o = graph.define("files", "OBJ_FILES", "files_all")
	o.optional = true
	o.counter = "files"
	o.counter_target = FILES_NEEDED
	o = graph.define("tape", "OBJ_TAPE", "tape_heard")
	o.optional = true
	o = graph.define("unseen", "OBJ_UNSEEN", "unseen")
	o.optional = true


func _solvability() -> void:
	solver.start_zone = "ground"
	solver.goal_flag = "escaped"
	solver.add_zone("ground")
	solver.add_zone("study", ["study_key"])
	solver.add_zone("basement", [], ["power_on"])
	solver.add_zone("cage", [], ["cage_open"])
	solver.add_action("fuse_panel", "ground", {"fuse": 3}, [], ["power_on"])
	solver.add_action("read_clues", "basement", {}, [], ["code_known"])
	solver.add_action("keypad", "basement", {}, ["code_known"], ["cage_open"])
	solver.add_action("workbench", "ground", {"drive_belt": 1, "drive_gear": 1}, [], [], {"drive_assembly": 1})
	solver.add_action("install", "ground", {"drive_assembly": 1}, [], ["motor_repaired"])
	solver.add_action("crank", "ground", {}, ["motor_repaired", "power_on"], ["garage_open"])
	solver.add_action("escape", "ground", {}, ["garage_open"], ["escaped"])

	for sp in ["sp_kitchen_table", "sp_kitchen_counter", "sp_kitchen_drawer", "sp_dining_table", "sp_dining_cabinet",
			"sp_living_shelf", "sp_living_sofa", "sp_hall_table", "sp_foyer_stand", "sp_garage_shelf",
			"sp_garage_crate", "sp_utility_shelf", "sp_utility_washer"]:
		add_spawn(sp, "ground")
	for sp in ["sp_study_desk", "sp_study_shelf"]:
		add_spawn(sp, "study")
	for sp in ["sp_base_shelf_a", "sp_base_shelf_b", "sp_base_crate", "sp_base_boiler"]:
		add_spawn(sp, "basement")
	add_spawn("sp_cage_shelf", "cage")

	# First candidate of each slot = canonical layout used for validation.
	add_slot("study_key", "study_key", ["sp_kitchen_drawer", "sp_living_shelf", "sp_dining_cabinet", "sp_foyer_stand",
		"sp_garage_shelf", "sp_hall_table"])
	add_slot("fuse_1", "fuse", ["sp_dining_table", "sp_living_sofa", "sp_kitchen_counter", "sp_hall_table", "sp_utility_washer"])
	add_slot("fuse_2", "fuse", ["sp_study_desk", "sp_study_shelf", "sp_garage_crate", "sp_kitchen_table", "sp_living_shelf"])
	add_slot("fuse_3", "fuse", ["sp_garage_shelf", "sp_utility_shelf", "sp_foyer_stand", "sp_dining_cabinet", "sp_kitchen_drawer"])
	add_slot("drive_belt", "drive_belt", ["sp_base_shelf_a", "sp_study_shelf", "sp_base_crate", "sp_utility_shelf",
		"sp_base_boiler", "sp_garage_crate"])
	add_slot("drive_gear", "drive_gear", ["sp_cage_shelf"])


func generate_puzzle(rng: RandomNumberGenerator) -> Dictionary:
	var symbols := [0, 1, 2, 3]
	_shuffle(symbols, rng)
	var digits := []
	for i in 4:
		digits.append(rng.randi_range(0, 9))
	var order := [0, 1, 2, 3]
	_shuffle(order, rng)
	var code := ""
	for sym in order:
		code += str(digits[symbols.find(sym)])
	# Copy explicitly: `Array(CONST)` is constant-folded into one shared
	# instance, and shuffling it would leak state between matches.
	var files: Array = []
	files.append_array(FILE_IDS)
	_shuffle(files, rng)
	var batteries: Array = []
	batteries.append_array(BATTERY_SPAWNS)
	_shuffle(batteries, rng)
	var battery_count := clampi(2 + difficulty.scaled_extra_batteries(player_count), 0, BATTERY_SPAWNS.size())
	return {
		"faulty_socket": rng.randi_range(0, 3),
		"clue_symbols": symbols,
		"clue_digits": digits,
		"keypad_order": order,
		"code": code,
		"files": files.slice(0, FILES_NEEDED),
		"batteries": batteries.slice(0, battery_count),
	}


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
