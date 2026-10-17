class_name SpectatorCamera
extends Camera3D
## Over-the-shoulder view of a living teammate after the local player died
## or escaped in multiplayer. Kept out of walls with a short ray probe.

signal target_changed(display_name: String)

const BACK := 2.3
const UP := 1.95
const PROBE_MASK := GeoBuilder.LAYER_WORLD | GeoBuilder.LAYER_PROP | DoorEntity.LAYER_DOOR

var match_ctrl: MatchController
var local_pid := 0
var target_pid := -1


func _ready() -> void:
	near = 0.05
	far = 60.0
	fov = Settings.f("fov")


func candidates() -> Array[int]:
	var out: Array[int] = []
	var ids := match_ctrl.state.players.keys()
	ids.sort()
	for pid in ids:
		var p: Dictionary = match_ctrl.state.players[pid]
		var watchable := str(p["status"]) in [MatchState.STATUS_ALIVE, MatchState.STATUS_DOWNED]
		if int(pid) != local_pid and watchable and not bool(p.get("away", false)) and match_ctrl.players.has(pid):
			out.append(int(pid))
	return out


## Moves to the next watchable teammate. Returns false if there is none.
func next_target() -> bool:
	var list := candidates()
	if list.is_empty():
		if target_pid != -1:
			target_pid = -1
			target_changed.emit("")
		return false
	var idx := list.find(target_pid)
	target_pid = list[(idx + 1) % list.size()]
	target_changed.emit(str(match_ctrl.state.players[target_pid].get("name", "")))
	return true


func _process(delta: float) -> void:
	if match_ctrl == null:
		return
	if not candidates().has(target_pid):
		if not next_target():
			return
	var node := match_ctrl.players.get(target_pid) as Node3D
	if node == null or not is_instance_valid(node):
		return
	var head := node.global_position + Vector3(0, UP * 0.85, 0)
	var forward := Basis(Vector3.UP, node.global_rotation.y) * Vector3.FORWARD
	var desired := head - forward * BACK + Vector3(0, UP * 0.15, 0)
	var q := PhysicsRayQueryParameters3D.create(head, desired, PROBE_MASK)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		desired = (hit["position"] as Vector3) + (head - desired).normalized() * 0.25
	var k := clampf(delta * 6.0, 0.0, 1.0)
	global_position = global_position.lerp(desired, k) if global_position.distance_to(desired) < 6.0 else desired
	if global_position.distance_to(head) > 0.05:
		look_at(head, Vector3.UP)
