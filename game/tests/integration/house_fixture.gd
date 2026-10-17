class_name HouseFixture
extends TestCase
## Shared setup: builds a real solo match of a map headlessly and drives it
## through the same authority entry points a client uses.

var map: MapBase
var mc: MatchController
var player: PlayerController


func build(
	map_id: String = "house", difficulty_id: String = "normal", seed_value: int = 777, resume: Dictionary = {}
) -> bool:
	var cfg := {
		"mode": "solo",
		"map_id": map_id,
		"difficulty_id": difficulty_id,
		"seed": seed_value,
		"match_id": "it-%s-%d" % [map_id, seed_value],
		"player_count": 1,
		"resume": resume,
	}
	Session.match_config = cfg
	Log.min_level = Log.Level.DEBUG
	var built := LevelLoader.build(self, cfg)
	if not built["ok"]:
		fail("build failed: " + str(built.get("error")))
		return false
	map = built["map"]
	mc = built["match"]
	mc.enemy_enabled = false
	player = LevelLoader.spawn_local_player(map, mc, 1, "Tester")
	# Tests drive the player record directly; the node must not overwrite it.
	player.set_physics_process(false)
	player.input_enabled = false
	mc.apply_all_states()
	mc.begin()
	await map.wait_for_navigation()
	assert_true(map.navigation_ready(), "navigation synced")
	return true


func after_each() -> void:
	Log.min_level = Log.Level.INFO
	if map and is_instance_valid(map):
		map.queue_free()
	get_tree().paused = false
	await frames(2)


## Places the player record at a walkable point near an entity.
func approach(entity_id: String) -> void:
	var ent: Interactable = mc.entities.get(entity_id)
	if ent == null:
		fail("no entity " + entity_id)
		return
	var origin := ent.interact_origin()
	var spot := map.closest_nav_point(Vector3(origin.x, origin.y - 1.0, origin.z))
	put(spot)


func put(pos: Vector3) -> void:
	mc.state.players[1]["pos"] = MatchState.vec_to_array(pos)
	player.global_position = pos


## Sends an interaction like a client would (waits out the rate limit first).
func use(entity_id: String, sub: int = 0, action: String = "use", args: Dictionary = {}) -> bool:
	# Wall clock, like the rate limit itself (scene timers follow smoothed frame
	# deltas and can fire a little early under load).
	var until := Time.get_ticks_msec() + int((MatchController.INTERACT_MIN_INTERVAL + 0.02) * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame
	return mc.server_interact(1, entity_id, sub, action, args)


func take(pickup_id: String) -> void:
	var ent: Interactable = mc.entities.get(pickup_id)
	if ent == null:
		fail("missing pickup " + pickup_id)
		return
	var parent := ent.get_parent()
	while parent and not parent is MapBase:
		if parent is DrawerEntity:
			var drawer: DrawerEntity = parent
			if not bool(drawer.state.get("open", false)):
				approach(drawer.entity_id)
				await use(drawer.entity_id)
				await frames(30)
		parent = parent.get_parent()
	approach(pickup_id)
	var ok := await use(pickup_id)
	assert_true(ok, "interaction accepted for " + pickup_id)
	assert_true(bool(mc.state.entities[pickup_id].get("taken", false)), pickup_id + " taken")


func pickup_for_slot(slot: String) -> String:
	return "pickup_" + slot


func spawn_of(slot: String) -> String:
	return str(mc.state.variant["placements"][slot])


func has(item: String, n: int = 1) -> bool:
	return mc.has_item(1, item, n)
