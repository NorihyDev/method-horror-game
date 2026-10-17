extends MapRules
## METHOD Facility — objective chain, solvability model and seeded variants.
##
## The finale uses every system the field sites trained: find a way out (the
## passenger lift is dead) → a security card opens the security office →
## its console releases the maglocks → two power cells start the generator
## (Subject Zero can see again) → the observation monitors and the trial
## protocol give the director's keypad code → the director's console calls
## the freight lift → hold out until it arrives → ride it up.

const FILE_IDS: PackedStringArray = [
	"file_security", "file_archive", "file_observation", "file_cells", "file_break", "file_director"
]
const BATTERY_SPAWNS: PackedStringArray = [
	"bt_lobby", "bt_cells", "bt_break", "bt_archive", "bt_observation", "bt_security", "bt_corridor", "bt_liftbay"
]
const FILES_NEEDED := 3
const CELLS := 4


func setup(p_player_count: int, p_difficulty: DifficultyDefinition) -> void:
	super.setup(p_player_count, p_difficulty)
	power_flag = "facility_power"
	phase_flags = {"facility_power": MatchState.Phase.ESCALATE, "lift_called": MatchState.Phase.FINAL}
	_objectives()
	_solvability()


func _objectives() -> void:
	var o := graph.define("explore", "FOBJ_EXPLORE", "exit_found")
	o.hint_keys = ["FHINT_EXPLORE_1", "FHINT_EXPLORE_2"]
	o = graph.define("security", "FOBJ_SECURITY", "security_open", ["explore"])
	o.hint_keys = ["FHINT_SECURITY_1", "FHINT_SECURITY_2"]
	o = graph.define("locks", "FOBJ_LOCKS", "locks_released", ["security"])
	o.hint_keys = ["FHINT_LOCKS_1"]
	o = graph.define("power", "FOBJ_POWER", "facility_power", ["locks"])
	o.counter = "cells_installed"
	o.counter_target = 2
	o.hint_keys = ["FHINT_POWER_1", "FHINT_POWER_2"]
	o = graph.define("code", "FOBJ_CODE", "office_open", ["power"])
	o.hint_keys = ["FHINT_CODE_1", "FHINT_CODE_2", "FHINT_CODE_3"]
	o = graph.define("lift", "FOBJ_LIFT", "lift_called", ["code"])
	o.hint_keys = ["FHINT_LIFT_1"]
	o = graph.define("hold", "FOBJ_HOLD", "lift_arrived", ["lift"])
	o.hint_keys = ["FHINT_HOLD_1"]
	o = graph.define("escape", "FOBJ_ESCAPE", "escaped", ["hold"])
	o.is_final = true
	o.hint_keys = ["FHINT_ESCAPE_1"]
	o = graph.define("files", "OBJ_FILES", "files_all")
	o.optional = true
	o.counter = "files"
	o.counter_target = FILES_NEEDED
	o = graph.define("tape", "FOBJ_TAPE", "tape_heard")
	o.optional = true
	o = graph.define("unseen", "FOBJ_UNSEEN", "unseen")
	o.optional = true


func _solvability() -> void:
	solver.start_zone = "atrium"
	solver.goal_flag = "escaped"
	solver.add_zone("atrium")
	solver.add_zone("security", ["security_card"])
	solver.add_zone("generator", [], ["locks_released"])
	solver.add_zone("director", [], ["office_open"])
	solver.add_action("release", "security", {}, [], ["locks_released"])
	solver.add_action("rack", "generator", {"power_cell": 2}, [], ["facility_power"])
	solver.add_action("monitors", "atrium", {}, ["facility_power"], ["readings_known"])
	solver.add_action("protocol", "atrium", {}, [], ["order_known"])
	solver.add_action("keypad", "atrium", {}, ["readings_known", "order_known"], ["office_open"])
	solver.add_action("lift", "director", {}, ["facility_power"], ["lift_arrived"])
	solver.add_action("escape", "atrium", {}, ["lift_arrived"], ["escaped"])

	for sp in [
		"sp_lobby_desk",
		"sp_lobby_bench",
		"sp_cell_1",
		"sp_cell_3",
		"sp_cells_desk",
		"sp_break_table",
		"sp_break_counter",
		"sp_archive_table",
		"sp_archive_shelf",
		"sp_obs_bench",
		"sp_liftbay_crate",
	]:
		add_spawn(sp, "atrium")
	for sp in ["sp_security_desk", "sp_security_shelf"]:
		add_spawn(sp, "security")

	# First candidate of each slot = canonical layout used for validation.
	add_slot(
		"security_card",
		"security_card",
		["sp_cells_desk", "sp_break_table", "sp_cell_3", "sp_archive_table", "sp_lobby_bench", "sp_break_counter"]
	)
	add_slot(
		"cell_1", "power_cell", ["sp_cell_1", "sp_archive_shelf", "sp_liftbay_crate", "sp_lobby_desk", "sp_obs_bench"]
	)
	add_slot(
		"cell_2",
		"power_cell",
		["sp_security_shelf", "sp_break_counter", "sp_security_desk", "sp_cell_3", "sp_archive_table"]
	)


func generate_puzzle(rng: RandomNumberGenerator) -> Dictionary:
	var digits: Array = []
	for i in CELLS:
		digits.append(rng.randi_range(0, 9))
	# Trial protocol: the order the cells are checked, a permutation of 1..4.
	var order: Array = [1, 2, 3, 4]
	_shuffle(order, rng)
	var code := ""
	for cell: int in order:
		code += str(digits[cell - 1])
	var files: Array = []
	files.append_array(FILE_IDS)
	_shuffle(files, rng)
	var batteries: Array = []
	batteries.append_array(BATTERY_SPAWNS)
	_shuffle(batteries, rng)
	var battery_count := clampi(2 + difficulty.scaled_extra_batteries(player_count), 0, BATTERY_SPAWNS.size())
	return {
		"cell_digits": digits,
		"check_order": order,
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
