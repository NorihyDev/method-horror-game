class_name MotionGuard
extends RefCounted
## Server-side check of a client's reported movement. Each player has a
## distance budget that refills at the top running speed (with a little
## headroom for network jitter), so sending many small packets can never add
## up to more than real running; and a move may not pass through walls,
## locked doors or furniture.

## Seconds of running the budget can hold (a burst after a lag spike).
const BURST_SECONDS := 1.2
## Headroom over the top speed for timing jitter between packets.
const SPEED_SLACK := 1.25
## Vertical change allowed per packet (stairs, falling into the pit).
const MAX_RISE := 1.2
const MAX_FALL := 4.0

var _budget := {}
var _last := {}


## True if moving `pid` from `old` to `new` is possible; uses up the budget.
func allow(pid: int, old: Vector3, new: Vector3, world: World3D) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	var cap := NetProtocol.MAX_PLAYER_SPEED * SPEED_SLACK * BURST_SECONDS
	var budget := float(_budget.get(pid, cap))
	if _last.has(pid):
		budget = minf(cap, budget + (now - float(_last[pid])) * NetProtocol.MAX_PLAYER_SPEED * SPEED_SLACK)
	_last[pid] = now
	var flat := Vector2(new.x - old.x, new.z - old.z).length()
	var rise := new.y - old.y
	if flat > budget + 0.05 or rise > MAX_RISE or rise < -MAX_FALL:
		_budget[pid] = budget
		return false
	_budget[pid] = budget - flat
	if world and flat > 0.05 and _blocked(old, new, world):
		return false
	return true


## The player's body (at knee and chest height) would cross solid geometry.
static func _blocked(old: Vector3, new: Vector3, world: World3D) -> bool:
	var space := world.direct_space_state
	var mask := GeoBuilder.LAYER_WORLD | GeoBuilder.LAYER_PROP
	for h: float in [0.5, 1.3]:
		var q := PhysicsRayQueryParameters3D.create(old + Vector3(0, h, 0), new + Vector3(0, h, 0), mask)
		if not space.intersect_ray(q).is_empty():
			return true
	return false


func forget(pid: int) -> void:
	_budget.erase(pid)
	_last.erase(pid)
