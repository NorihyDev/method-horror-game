extends MapRules
## The Silent School — objective chain, solvability model and seeded variants.
##
## Chain: find a way out (the front doors are chained) → open the east wing
## (its key lies beside a music box left playing somewhere: follow the
## sound) → restore power at the caretaker's main breaker → play the bell
## tune over the staff-room PA (loud: it carries through the school) → play
## the same four notes on the music-room chimes, which releases the
## headmistress's office → take the bolt cutters → cut the chain → escape.

const FILE_IDS: PackedStringArray = [
	"file_class_a", "file_class_b", "file_class_c", "file_library", "file_staff", "file_music"
]
const BATTERY_SPAWNS: PackedStringArray = [
	"bt_class_a", "bt_class_b", "bt_class_c", "bt_library", "bt_staff", "bt_caretaker", "bt_hall", "bt_corridor"
]
const FILES_NEEDED := 3
const NOTES := 4


func setup(p_player_count: int, p_difficulty: DifficultyDefinition) -> void:
	super.setup(p_player_count, p_difficulty)
	power_flag = "school_power"
	phase_flags = {"school_power": MatchState.Phase.ESCALATE, "office_open": MatchState.Phase.FINAL}
	_objectives()
	_solvability()


func _objectives() -> void:
	var o := graph.define("explore", "COBJ_EXPLORE", "exit_found")
	o.hint_keys = ["CHINT_EXPLORE_1", "CHINT_EXPLORE_2"]
	o = graph.define("wing", "COBJ_WING", "wing_open", ["explore"])
	o.hint_keys = ["CHINT_WING_1", "CHINT_WING_2", "CHINT_WING_3"]
	o = graph.define("power", "COBJ_POWER", "school_power", ["wing"])
	o.hint_keys = ["CHINT_POWER_1", "CHINT_POWER_2"]
	o = graph.define("tune", "COBJ_TUNE", "tune_heard", ["power"])
	o.hint_keys = ["CHINT_TUNE_1", "CHINT_TUNE_2"]
	o = graph.define("chimes", "COBJ_CHIMES", "office_open", ["tune"])
	o.hint_keys = ["CHINT_CHIMES_1", "CHINT_CHIMES_2", "CHINT_CHIMES_3"]
	o = graph.define("doors", "COBJ_DOORS", "doors_open", ["chimes"])
	o.hint_keys = ["CHINT_DOORS_1", "CHINT_DOORS_2"]
	o = graph.define("escape", "COBJ_ESCAPE", "escaped", ["doors"])
	o.is_final = true
	o.hint_keys = ["CHINT_ESCAPE_1"]
	o = graph.define("files", "OBJ_FILES", "files_all")
	o.optional = true
	o.counter = "files"
	o.counter_target = FILES_NEEDED
	o = graph.define("tape", "COBJ_TAPE", "tape_heard")
	o.optional = true
	o = graph.define("unseen", "COBJ_UNSEEN", "unseen")
	o.optional = true


func _solvability() -> void:
	solver.start_zone = "west"
	solver.goal_flag = "escaped"
	solver.add_zone("west")
	solver.add_zone("east", ["wing_key"])
	solver.add_zone("office", [], ["office_open"])
	solver.add_action("breaker", "west", {}, [], ["school_power"])
	solver.add_action("pa", "west", {}, ["school_power"], ["tune_known"])
	solver.add_action("chimes", "east", {}, ["tune_known"], ["office_open"])
	solver.add_action("cut", "west", {"bolt_cutters": 1}, [], ["doors_open"])
	solver.add_action("escape", "west", {}, ["doors_open"], ["escaped"])

	for sp in [
		"sp_class_a_desk",
		"sp_class_a_teacher",
		"sp_class_b_desk",
		"sp_class_b_cubby",
		"sp_class_c_desk",
		"sp_class_c_teacher",
		"sp_library_table",
		"sp_library_shelf",
		"sp_staff_table",
		"sp_hall_bench",
		"sp_caretaker_bench",
	]:
		add_spawn(sp, "west")
	for sp in ["sp_office_desk", "sp_office_cabinet", "sp_office_shelf"]:
		add_spawn(sp, "office")

	# First candidate of each slot = canonical layout used for validation.
	add_slot(
		"wing_key",
		"wing_key",
		[
			"sp_class_b_desk",
			"sp_class_a_desk",
			"sp_class_c_teacher",
			"sp_library_table",
			"sp_class_a_teacher",
			"sp_class_b_cubby",
			"sp_class_c_desk",
			"sp_library_shelf",
		]
	)
	add_slot("bolt_cutters", "bolt_cutters", ["sp_office_desk", "sp_office_cabinet", "sp_office_shelf"])


func generate_puzzle(rng: RandomNumberGenerator) -> Dictionary:
	# The bell tune: each of the four bars once, never straight up or down.
	var tune: Array = []
	while true:
		tune = [1, 2, 3, 4]
		_shuffle(tune, rng)
		if tune != [1, 2, 3, 4] and tune != [4, 3, 2, 1]:
			break
	var files: Array = []
	files.append_array(FILE_IDS)
	_shuffle(files, rng)
	var batteries: Array = []
	batteries.append_array(BATTERY_SPAWNS)
	_shuffle(batteries, rng)
	var battery_count := clampi(2 + difficulty.scaled_extra_batteries(player_count), 0, BATTERY_SPAWNS.size())
	return {
		"tune": tune,
		"files": files.slice(0, FILES_NEEDED),
		"batteries": batteries.slice(0, battery_count),
	}


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
