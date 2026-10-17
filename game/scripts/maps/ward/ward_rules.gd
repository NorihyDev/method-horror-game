extends MapRules
## The Black Ward — objective chain, solvability model and seeded variants.
##
## Chain: find a way out (the ambulance-bay shutter has no power) → get a
## staff card → restore emergency power (starter relay + the breaker pattern
## from the electrician's schematic) → read the bed monitors in the
## observation wing (security card) and the night-round order (staff room)
## → enter the security office (keypad) → raise the bay shutter → escape.

const FILE_IDS: PackedStringArray = [
	"file_reception", "file_triage", "file_maint", "file_ward", "file_pharmacy", "file_obs"
]
const BATTERY_SPAWNS: PackedStringArray = [
	"bt_reception", "bt_triage", "bt_maint", "bt_ward", "bt_corridor", "bt_staff", "bt_pharmacy", "bt_obs", "bt_morgue"
]
const FILES_NEEDED := 3
const BEDS := 4


func setup(p_player_count: int, p_difficulty: DifficultyDefinition) -> void:
	super.setup(p_player_count, p_difficulty)
	power_flag = "ward_power"
	phase_flags = {"ward_power": MatchState.Phase.ESCALATE, "bay_open": MatchState.Phase.FINAL}
	_objectives()
	_solvability()


func _objectives() -> void:
	var o := graph.define("explore", "WOBJ_EXPLORE", "exit_found")
	o.hint_keys = ["WHINT_EXPLORE_1", "WHINT_EXPLORE_2"]
	o = graph.define("staff", "WOBJ_STAFF", "staff_open", ["explore"])
	o.hint_keys = ["WHINT_STAFF_1", "WHINT_STAFF_2"]
	o = graph.define("power", "WOBJ_POWER", "ward_power", ["staff"])
	o.hint_keys = ["WHINT_POWER_1", "WHINT_POWER_2", "WHINT_POWER_3"]
	o = graph.define("security", "WOBJ_SECURITY", "security_open", ["power"])
	o.hint_keys = ["WHINT_SECURITY_1", "WHINT_SECURITY_2", "WHINT_SECURITY_3"]
	o = graph.define("bay", "WOBJ_BAY", "bay_open", ["security"])
	o.hint_keys = ["WHINT_BAY_1"]
	o = graph.define("escape", "WOBJ_ESCAPE", "escaped", ["bay"])
	o.is_final = true
	o.hint_keys = ["WHINT_ESCAPE_1"]
	o = graph.define("files", "OBJ_FILES", "files_all")
	o.optional = true
	o.counter = "files"
	o.counter_target = FILES_NEEDED
	o = graph.define("tape", "WOBJ_TAPE", "tape_heard")
	o.optional = true
	o = graph.define("unseen", "WOBJ_UNSEEN", "unseen")
	o.optional = true


func _solvability() -> void:
	solver.start_zone = "admissions"
	solver.goal_flag = "escaped"
	solver.add_zone("admissions")
	solver.add_zone("staff", ["staff_card"])
	solver.add_zone("observation", ["security_card"])
	solver.add_zone("security", [], ["security_open"])
	solver.add_action("schematic", "admissions", {}, [], ["circuit_known"])
	solver.add_action("generator", "staff", {"starter_relay": 1}, ["circuit_known"], ["ward_power"])
	solver.add_action("monitors", "observation", {}, ["ward_power"], ["readings_known"])
	solver.add_action("roster", "staff", {}, [], ["order_known"])
	solver.add_action("keypad", "staff", {}, ["readings_known", "order_known"], ["security_open"])
	solver.add_action("console", "security", {}, ["ward_power"], ["bay_open"])
	solver.add_action("escape", "admissions", {}, ["bay_open"], ["escaped"])

	for sp in [
		"sp_reception_desk",
		"sp_reception_chairs",
		"sp_triage_bed",
		"sp_triage_cabinet",
		"sp_maint_bench",
		"sp_maint_shelf",
		"sp_ward_bed_a",
		"sp_ward_bed_b",
		"sp_ward_cabinet",
		"sp_bay_shelf",
		"sp_corridor_trolley",
		"sp_morgue_slab",
		"sp_morgue_tray",
		"sp_morgue_counter",
		"sp_cold_shelf",
		"sp_cold_crate",
	]:
		add_spawn(sp, "admissions")
	for sp in ["sp_staff_table", "sp_staff_counter", "sp_pharmacy_shelf", "sp_pharmacy_fridge", "sp_gen_shelf"]:
		add_spawn(sp, "staff")
	for sp in ["sp_obs_a_desk", "sp_obs_b_desk", "sp_obs_c_desk", "sp_obscorr_bench"]:
		add_spawn(sp, "observation")

	# First candidate of each slot = canonical layout used for validation.
	add_slot(
		"staff_card",
		"staff_card",
		[
			"sp_ward_cabinet",
			"sp_reception_desk",
			"sp_triage_cabinet",
			"sp_maint_bench",
			"sp_corridor_trolley",
			"sp_bay_shelf",
			"sp_morgue_slab",
			"sp_cold_shelf",
		]
	)
	add_slot(
		"security_card",
		"security_card",
		[
			"sp_staff_table",
			"sp_triage_bed",
			"sp_pharmacy_shelf",
			"sp_ward_bed_a",
			"sp_maint_shelf",
			"sp_staff_counter",
			"sp_morgue_tray",
		]
	)
	add_slot(
		"starter_relay",
		"starter_relay",
		[
			"sp_maint_shelf",
			"sp_gen_shelf",
			"sp_ward_bed_b",
			"sp_pharmacy_fridge",
			"sp_obs_b_desk",
			"sp_reception_chairs",
			"sp_cold_crate",
			"sp_morgue_counter",
		]
	)


func generate_puzzle(rng: RandomNumberGenerator) -> Dictionary:
	# Breaker pattern: two or three live circuits, never all or none.
	var circuit: Array = []
	while true:
		circuit.clear()
		var live := 0
		for i in EmergencyPanel.BREAKERS:
			var on := rng.randf() < 0.5
			circuit.append(on)
			live += 1 if on else 0
		if live >= 2 and live <= 3:
			break
	var digits: Array = []
	for i in BEDS:
		digits.append(rng.randi_range(0, 9))
	# Night-round order: a permutation of beds 1..4.
	var order: Array = [1, 2, 3, 4]
	_shuffle(order, rng)
	var code := ""
	for bed: int in order:
		code += str(digits[bed - 1])
	var files: Array = []
	files.append_array(FILE_IDS)
	_shuffle(files, rng)
	var batteries: Array = []
	batteries.append_array(BATTERY_SPAWNS)
	_shuffle(batteries, rng)
	var battery_count := clampi(2 + difficulty.scaled_extra_batteries(player_count), 0, BATTERY_SPAWNS.size())
	return {
		"circuit": circuit,
		"bed_digits": digits,
		"round_order": order,
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
