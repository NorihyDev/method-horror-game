extends TestCase
## Offline map progression: each map opens after the previous one is escaped
## on this device, and a locked map cannot be started.

var _saved_progress: Dictionary


func before_each() -> void:
	_saved_progress = (Saves.data["progress"]["maps"] as Dictionary).duplicate(true)
	(Saves.data["progress"]["maps"] as Dictionary).clear()


func after_each() -> void:
	Saves.data["progress"]["maps"] = _saved_progress


func test_maps_unlock_in_order() -> void:
	assert_true(Session.is_map_unlocked("house"), "the house is open from the start")
	assert_true(Session.is_map_unlocked("tutorial"), "the tutorial is always open")
	assert_false(Session.is_map_unlocked("black_ward"), "the ward waits for the house")
	assert_false(Session.is_map_unlocked("last_train"), "the station waits for the ward")
	assert_false(Session.is_map_unlocked("silent_school"), "planned maps are never unlocked")
	Saves.record_completion("house", "story", 600.0)
	assert_true(Session.is_map_unlocked("black_ward"), "escaping the house opens the ward")
	assert_false(Session.is_map_unlocked("last_train"))
	Saves.record_completion("black_ward", "normal", 900.0)
	assert_true(Session.is_map_unlocked("last_train"), "escaping the ward opens the station")
	assert_eq(Array(Session.unlocked_map_ids()), ["house", "black_ward", "last_train"], "LAN rooms offer unlocked maps")


func test_locked_map_cannot_be_started() -> void:
	var before := Session.match_config.duplicate()
	Session.start_solo("last_train", "normal")
	assert_eq(Session.match_config, before, "starting a locked map is refused")
