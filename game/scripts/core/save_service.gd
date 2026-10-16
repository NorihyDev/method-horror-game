extends Node
## Autoload "Saves": local profile, progression, local wallet and checkpoint.
##
## Trust model: everything here is local and tamperable. The local wallet is
## never imported into the verified online wallet. See docs/economy.md.

signal profile_changed
signal wallet_changed(balance: int)
signal progress_changed

const PROFILE_PATH := "user://profile.json"
const CHECKPOINT_PATH := "user://checkpoint.json"
const AVATAR_COLORS: Array[Color] = [
	Color(0.55, 0.12, 0.12),
	Color(0.78, 0.74, 0.64),
	Color(0.32, 0.42, 0.48),
	Color(0.36, 0.44, 0.30),
	Color(0.52, 0.40, 0.22),
	Color(0.40, 0.30, 0.48),
]

var data: Dictionary = {}
var profile_path := PROFILE_PATH
var checkpoint_path := CHECKPOINT_PATH
var wallet := Wallet.new()
var catalog := CosmeticCatalog.new()
## Set when the primary file was corrupt and a backup or defaults were used.
var load_recovered := false


func _ready() -> void:
	if AppInfo.uses_isolated_storage():
		# Automated tests never touch the player's real profile.
		profile_path = "user://test_profile.json"
		checkpoint_path = "user://test_checkpoint.json"
		SaveIO.delete_all(profile_path)
		SaveIO.delete_all(checkpoint_path)
	load_profile()


func load_profile() -> void:
	var res := SaveIO.read_with_recovery(profile_path)
	load_recovered = bool(res["recovered"])
	if res["data"] is Dictionary:
		data = migrate(res["data"])
	else:
		data = _new_profile()
	_ensure_shape()
	wallet.load_dict(data["wallet"])
	wallet.grant_defaults(catalog)
	if load_recovered:
		Log.warn("saves", "Profile recovered from backup or reset", {"source": res["source"]})
	save()


func save() -> void:
	data["wallet"] = wallet.to_dict()
	var err := SaveIO.write_atomic(profile_path, data)
	if err != OK:
		Log.error("saves", "Could not write profile", {"error": error_string(err)})


## Applies schema migrations in order. Public for tests.
static func migrate(raw: Dictionary) -> Dictionary:
	var d := raw.duplicate(true)
	var version := int(d.get("schema_version", 0))
	if version < 1:
		# v0 (pre-release prototype): flat {"name", "coins", "completed": [map ids]}
		var maps := {}
		for map_id in d.get("completed", []):
			maps[str(map_id)] = {"completed": true, "completions": 1, "best_time": 0.0, "collectibles": []}
		d = {
			"schema_version": 1,
			"profile":
			{
				"local_id": _generate_local_id(),
				"display_name": str(d.get("name", "")),
				"avatar_color": 0,
				"created_at": int(Time.get_unix_time_from_system())
			},
			"progress": {"maps": maps, "tutorial_done": false},
			"wallet": {"balance": maxi(0, int(d.get("coins", 0)))},
		}
		version = 1
	d["schema_version"] = version
	return d


func has_name() -> bool:
	return not display_name().is_empty()


func display_name() -> String:
	return str(data["profile"].get("display_name", ""))


func local_id() -> String:
	return str(data["profile"]["local_id"])


func set_display_name(raw: String) -> bool:
	if NameValidator.validate(raw) != NameValidator.Result.OK:
		return false
	data["profile"]["display_name"] = NameValidator.normalize(raw)
	save()
	profile_changed.emit()
	return true


func avatar_color_index() -> int:
	return clampi(int(data["profile"].get("avatar_color", 0)), 0, AVATAR_COLORS.size() - 1)


func avatar_color() -> Color:
	return AVATAR_COLORS[avatar_color_index()]


func set_avatar_color(index: int) -> void:
	data["profile"]["avatar_color"] = clampi(index, 0, AVATAR_COLORS.size() - 1)
	save()
	profile_changed.emit()


# --- Progress ---------------------------------------------------------------


func map_progress(map_id: String) -> Dictionary:
	var maps: Dictionary = data["progress"]["maps"]
	if not maps.has(map_id):
		maps[map_id] = {
			"completed": false, "completions": 0, "best_time": 0.0, "best_difficulty": "", "collectibles": []
		}
	return maps[map_id]


func is_map_completed(map_id: String) -> bool:
	return bool(map_progress(map_id).get("completed", false))


## Records collectibles; returns how many were new.
func record_collectibles(map_id: String, ids: PackedStringArray) -> int:
	var prog := map_progress(map_id)
	var known: Array = prog["collectibles"]
	var added := 0
	for id in ids:
		if not known.has(id):
			known.append(id)
			added += 1
	return added


func record_completion(map_id: String, difficulty_id: String, time_seconds: float) -> void:
	var prog := map_progress(map_id)
	prog["completed"] = true
	prog["completions"] = int(prog.get("completions", 0)) + 1
	var best := float(prog.get("best_time", 0.0))
	if best <= 0.0 or time_seconds < best:
		prog["best_time"] = time_seconds
	prog["best_difficulty"] = difficulty_id
	progress_changed.emit()


func set_tutorial_done() -> void:
	data["progress"]["tutorial_done"] = true
	save()


func tutorial_done() -> bool:
	return bool(data["progress"].get("tutorial_done", false))


# --- Wallet (local) --------------------------------------------------------


func apply_local_reward(reward_id: String, amount: int, reason: String) -> bool:
	var ok := wallet.apply_reward(reward_id, amount, reason, int(Time.get_unix_time_from_system()))
	if ok:
		save()
		wallet_changed.emit(wallet.balance)
	return ok


func purchase(item_id: String) -> Wallet.PurchaseResult:
	var result := wallet.purchase(item_id, catalog, int(Time.get_unix_time_from_system()))
	if result == Wallet.PurchaseResult.OK:
		save()
		wallet_changed.emit(wallet.balance)
	return result


func equip(item_id: String) -> bool:
	var ok := wallet.equip(item_id, catalog)
	if ok:
		save()
		profile_changed.emit()
	return ok


func equipped_item(slot: String) -> Dictionary:
	return catalog.get_item(wallet.equipped_in(slot, catalog))


# --- Checkpoint ------------------------------------------------------------


func save_checkpoint(snapshot: Dictionary) -> void:
	var err := SaveIO.write_atomic(checkpoint_path, {"schema_version": 1, "snapshot": snapshot})
	if err != OK:
		Log.error("saves", "Could not write checkpoint", {"error": error_string(err)})


func load_checkpoint() -> Dictionary:
	var res := SaveIO.read_with_recovery(checkpoint_path)
	if res["data"] is Dictionary:
		var snap: Variant = res["data"].get("snapshot")
		if snap is Dictionary:
			return snap
	return {}


func has_checkpoint() -> bool:
	return not load_checkpoint().is_empty()


func clear_checkpoint() -> void:
	SaveIO.delete_all(checkpoint_path)


# --- Reset -----------------------------------------------------------------


## Deletes all local data (profile, wallet, checkpoint, settings).
func reset_all_local_data() -> void:
	SaveIO.delete_all(profile_path)
	SaveIO.delete_all(checkpoint_path)
	SaveIO.delete_all(Settings.path)
	data = _new_profile()
	_ensure_shape()
	wallet = Wallet.new()
	wallet.grant_defaults(catalog)
	save()
	Settings.reset_all()
	profile_changed.emit()
	wallet_changed.emit(wallet.balance)
	progress_changed.emit()


func _new_profile() -> Dictionary:
	return {
		"schema_version": AppInfo.SAVE_SCHEMA_VERSION,
		"profile":
		{
			"local_id": _generate_local_id(),
			"display_name": "",
			"avatar_color": 0,
			"created_at": int(Time.get_unix_time_from_system())
		},
		"progress": {"maps": {}, "tutorial_done": false},
		"wallet": {},
	}


func _ensure_shape() -> void:
	if not data.get("profile") is Dictionary:
		data["profile"] = {}
	if str(data["profile"].get("local_id", "")).length() < 16:
		data["profile"]["local_id"] = _generate_local_id()
	var stored_name := str(data["profile"].get("display_name", ""))
	if not stored_name.is_empty() and NameValidator.validate(stored_name) != NameValidator.Result.OK:
		data["profile"]["display_name"] = ""
	if not data.get("progress") is Dictionary:
		data["progress"] = {}
	if not data["progress"].get("maps") is Dictionary:
		data["progress"]["maps"] = {}
	if not data.get("wallet") is Dictionary:
		data["wallet"] = {}


static func _generate_local_id() -> String:
	var crypto := Crypto.new()
	return crypto.generate_random_bytes(16).hex_encode()
