class_name ReviveTarget
extends Interactable
## Client-side focus target on a downed teammate. It never changes state
## itself: it asks the server to start a revive, and the server re-checks
## distance, statuses and continuity every tick for the full revive time.

var avatar: RemoteAvatar


func _ready() -> void:
	interact_range = 2.0
	add_target(Vector3(0.9, 0.6, 1.6))


func get_prompt(_pid: int, _sub: int) -> String:
	if avatar == null or not avatar.is_downed():
		return ""
	return tr("PROMPT_REVIVE") % avatar.display_name


func get_hold_time(_pid: int, _sub: int) -> float:
	return 0.35


func can_interact(_pid: int, _sub: int) -> bool:
	return avatar != null and avatar.is_downed()


func client_intercept(_pid: int, _sub: int) -> bool:
	var mc := avatar.get_parent()
	while mc and not mc is MapBase:
		mc = mc.get_parent()
	var map := mc as MapBase
	if map and map.match_ctrl and map.match_ctrl.net:
		map.match_ctrl.net.call("send_revive", avatar.player_id, true)
	return true
