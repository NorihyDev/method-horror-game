extends Node
## Autoload "Session": content registries, match orchestration and app
## lifecycle (background/resume, Android back).

signal app_paused_changed(paused: bool)

const MAP_PATHS: PackedStringArray = [
	"res://resources/maps/tutorial.tres",
	"res://resources/maps/house.tres",
	"res://resources/maps/black_ward.tres",
	"res://resources/maps/last_train.tres",
	"res://resources/maps/silent_school.tres",
	"res://resources/maps/method_facility.tres",
]
const DIFFICULTY_PATHS: PackedStringArray = [
	"res://resources/difficulties/story.tres",
	"res://resources/difficulties/normal.tres",
	"res://resources/difficulties/hard.tres",
	"res://resources/difficulties/nightmare.tres",
]
const ITEM_PATHS: PackedStringArray = [
	"res://resources/items/fuse.tres",
	"res://resources/items/study_key.tres",
	"res://resources/items/drive_belt.tres",
	"res://resources/items/drive_gear.tres",
	"res://resources/items/drive_assembly.tres",
	"res://resources/items/battery.tres",
	"res://resources/items/orientation_key.tres",
]

var app: App
var maps: Array[MapDefinition] = []
var difficulties: Array[DifficultyDefinition] = []
var items: Dictionary = {}
## Config of the match being loaded or played (mode, map_id, difficulty_id, seed, ...).
var match_config: Dictionary = {}
var last_result: Dictionary = {}
var in_background := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_registries()


func register_app(p_app: App) -> void:
	app = p_app


func _load_registries() -> void:
	maps.clear()
	for path in MAP_PATHS:
		var m: MapDefinition = load(path)
		if m:
			maps.append(m)
		else:
			Log.error("session", "Missing map definition", {"path": path})
	maps.sort_custom(func(a: MapDefinition, b: MapDefinition) -> bool: return a.sort_order < b.sort_order)
	difficulties.clear()
	for path in DIFFICULTY_PATHS:
		var d: DifficultyDefinition = load(path)
		if d:
			difficulties.append(d)
	difficulties.sort_custom(func(a: DifficultyDefinition, b: DifficultyDefinition) -> bool:
		return a.sort_order < b.sort_order)
	items.clear()
	for path in ITEM_PATHS:
		var it: ItemDefinition = load(path)
		if it:
			items[String(it.id)] = it


func map_def(id: String) -> MapDefinition:
	for m in maps:
		if String(m.id) == id:
			return m
	return null


func difficulty(id: String) -> DifficultyDefinition:
	for d in difficulties:
		if String(d.id) == id:
			return d
	return difficulties[1] if difficulties.size() > 1 else null


func item(id: String) -> ItemDefinition:
	return items.get(id)


func stack_limits() -> Dictionary:
	var out := {}
	for id in items:
		out[id] = (items[id] as ItemDefinition).stack_max
	return out


func new_match_id() -> String:
	return Crypto.new().generate_random_bytes(12).hex_encode()


# --- Solo flow --------------------------------------------------------------

func start_solo(map_id: String, difficulty_id: String, resume_snapshot: Dictionary = {}) -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	match_config = {
		"mode": "solo",
		"map_id": map_id,
		"difficulty_id": difficulty_id,
		"seed": rng.randi(),
		"match_id": new_match_id(),
		"player_count": 1,
		"resume": resume_snapshot,
	}
	if not resume_snapshot.is_empty():
		match_config["seed"] = int(resume_snapshot.get("seed", 0))
		match_config["match_id"] = str(resume_snapshot.get("match_id", new_match_id()))
	app.reset_to("loading", match_config)


func continue_from_checkpoint() -> bool:
	var snap := Saves.load_checkpoint()
	if snap.is_empty():
		return false
	var map := map_def(str(snap.get("map_id", "")))
	if map == null or not map.is_playable():
		Saves.clear_checkpoint()
		return false
	start_solo(str(snap["map_id"]), str(snap.get("difficulty_id", "normal")), snap)
	return true


## Called by the match when it ends. `result` comes from MatchController.
func finish_match(result: Dictionary) -> void:
	last_result = result
	if str(match_config.get("mode", "")) == "solo":
		_apply_solo_progress(result)
	app.post_fx.set_active(false)
	app.reset_to("results", result)


func quit_to_menu() -> void:
	app.post_fx.set_active(false)
	app._dynres.active_in_gameplay = false
	AudioService.stop_all_world()
	get_tree().paused = false
	match_config = {}
	app.reset_to("main_menu")


func _apply_solo_progress(result: Dictionary) -> void:
	var map_id := str(result.get("map_id", ""))
	var escaped := str(result.get("outcome", "")) == "victory"
	var new_collectibles := Saves.record_collectibles(map_id, PackedStringArray(result.get("collectibles", [])))
	var first := escaped and not Saves.is_map_completed(map_id)
	var map := map_def(map_id)
	var diff := difficulty(str(result.get("difficulty_id", "normal")))
	var rewards := {}
	if map and diff and not bool(result.get("tutorial", false)):
		rewards = RewardCalculator.compute(map, diff, {
			"escaped": escaped,
			"optional_completed": int(result.get("optional_completed", 0)),
			"new_collectibles": new_collectibles,
			"first_completion": first,
		})
	if escaped:
		Saves.record_completion(map_id, str(result.get("difficulty_id", "")), float(result.get("time", 0.0)))
		Saves.clear_checkpoint()
	if bool(result.get("tutorial", false)) and escaped:
		Saves.set_tutorial_done()
	result["rewards"] = rewards
	result["first_completion"] = first
	var total := int(rewards.get("total", 0))
	# Reward id = match id: retrying the results screen can never pay twice.
	result["reward_applied"] = Saves.apply_local_reward("match:" + str(result.get("match_id", "")), total, "match")
	Saves.save()


# --- Dedicated server -------------------------------------------------------

func start_dedicated_server() -> void:
	var server_script: Script = load("res://scripts/network/dedicated_server.gd")
	if server_script == null:
		Log.error("session", "Dedicated server script missing")
		get_tree().quit(2)
		return
	var server: Node = server_script.new()
	app.add_child(server)


# --- Lifecycle ----------------------------------------------------------------

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if app:
				app.request_back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			if not in_background:
				in_background = true
				app_paused_changed.emit(true)
				Saves.save()
		NOTIFICATION_APPLICATION_RESUMED, NOTIFICATION_APPLICATION_FOCUS_IN:
			if in_background:
				in_background = false
				app_paused_changed.emit(false)
