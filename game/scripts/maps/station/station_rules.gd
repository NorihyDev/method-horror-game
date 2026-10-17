extends MapRules
## Last Train — objective chain, solvability model and seeded variants.
##
## Chain: find a way out (the street stairs have collapsed) → get into the
## maintenance tunnels (key) → power the signal box (two power cells) → set
## the evacuation route on the lever frame (route card) → call the train from
## the platform help point → hold out until it arrives → board it.

const FILE_IDS: PackedStringArray = [
	"file_office", "file_kiosk", "file_concourse", "file_platform", "file_signal", "file_store"
]
const BATTERY_SPAWNS: PackedStringArray = [
	"bt_concourse", "bt_office", "bt_kiosk", "bt_platform_w", "bt_platform_e", "bt_store", "bt_signal", "bt_corridor"
]
const FILES_NEEDED := 3


func setup(p_player_count: int, p_difficulty: DifficultyDefinition) -> void:
	super.setup(p_player_count, p_difficulty)
	power_flag = "signal_power"
	phase_flags = {"signal_power": MatchState.Phase.ESCALATE, "train_called": MatchState.Phase.FINAL}
	_objectives()
	_solvability()


func _objectives() -> void:
	var o := graph.define("explore", "SOBJ_EXPLORE", "exit_found")
	o.hint_keys = ["SHINT_EXPLORE_1", "SHINT_EXPLORE_2"]
	o = graph.define("maint", "SOBJ_MAINT", "maint_open", ["explore"])
	o.hint_keys = ["SHINT_MAINT_1", "SHINT_MAINT_2"]
	o = graph.define("power", "SOBJ_POWER", "signal_power", ["maint"])
	o.counter = "cells_installed"
	o.counter_target = 2
	o.hint_keys = ["SHINT_POWER_1", "SHINT_POWER_2"]
	o = graph.define("route", "SOBJ_ROUTE", "route_set", ["power"])
	o.hint_keys = ["SHINT_ROUTE_1", "SHINT_ROUTE_2", "SHINT_ROUTE_3"]
	o = graph.define("call", "SOBJ_CALL", "train_called", ["route"])
	o.hint_keys = ["SHINT_CALL_1"]
	o = graph.define("hold", "SOBJ_HOLD", "train_arrived", ["call"])
	o.hint_keys = ["SHINT_HOLD_1"]
	o = graph.define("escape", "SOBJ_ESCAPE", "escaped", ["hold"])
	o.is_final = true
	o.hint_keys = ["SHINT_ESCAPE_1"]
	o = graph.define("files", "OBJ_FILES", "files_all")
	o.optional = true
	o.counter = "files"
	o.counter_target = FILES_NEEDED
	o = graph.define("tape", "SOBJ_TAPE", "tape_heard")
	o.optional = true
	o = graph.define("unseen", "SOBJ_UNSEEN", "unseen")
	o.optional = true


func _solvability() -> void:
	solver.start_zone = "station"
	solver.goal_flag = "escaped"
	solver.add_zone("station")
	solver.add_zone("maintenance", ["maint_key"])
	solver.add_action("route_card", "station", {}, [], ["route_known"])
	solver.add_action("rack", "maintenance", {"power_cell": 2}, [], ["signal_power"])
	solver.add_action("levers", "maintenance", {}, ["signal_power", "route_known"], ["route_set"])
	solver.add_action("call", "station", {}, ["route_set"], ["train_arrived"])
	solver.add_action("escape", "station", {}, ["train_arrived"], ["escaped"])

	for sp in [
		"sp_office_desk",
		"sp_office_shelf",
		"sp_kiosk_counter",
		"sp_concourse_bench",
		"sp_gate_ledge",
		"sp_platform_bench_w",
		"sp_platform_bench_e",
		"sp_platform_crate",
	]:
		add_spawn(sp, "station")
	for sp in ["sp_store_shelf_a", "sp_store_shelf_b", "sp_store_bench", "sp_signal_desk", "sp_corridor_crate"]:
		add_spawn(sp, "maintenance")

	# First candidate of each slot = canonical layout used for validation.
	add_slot(
		"maint_key",
		"maint_key",
		["sp_office_desk", "sp_kiosk_counter", "sp_platform_bench_w", "sp_concourse_bench", "sp_platform_crate"]
	)
	add_slot(
		"cell_1",
		"power_cell",
		["sp_platform_bench_e", "sp_store_shelf_a", "sp_gate_ledge", "sp_signal_desk", "sp_office_shelf"]
	)
	add_slot(
		"cell_2",
		"power_cell",
		["sp_store_shelf_b", "sp_concourse_bench", "sp_corridor_crate", "sp_kiosk_counter", "sp_store_bench"]
	)


func generate_puzzle(rng: RandomNumberGenerator) -> Dictionary:
	# Evacuation route: one or two levers reversed, never none or all.
	var route: Array = []
	while true:
		route.clear()
		var reversed := 0
		for i in LeverFrame.LEVERS:
			var r := rng.randf() < 0.5
			route.append(r)
			reversed += 1 if r else 0
		if reversed >= 1 and reversed <= 2:
			break
	var files: Array = []
	files.append_array(FILE_IDS)
	_shuffle(files, rng)
	var batteries: Array = []
	batteries.append_array(BATTERY_SPAWNS)
	_shuffle(batteries, rng)
	var battery_count := clampi(2 + difficulty.scaled_extra_batteries(player_count), 0, BATTERY_SPAWNS.size())
	return {
		"route": route,
		"files": files.slice(0, FILES_NEEDED),
		"batteries": batteries.slice(0, battery_count),
	}


static func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
