class_name MatchState
extends RefCounted
## Authoritative match data. Contains only primitives/arrays/dictionaries so it
## can be snapshotted for checkpoints and sent to (re)connecting clients.
## Only the authority mutates it; clients apply snapshots and deltas.

enum Phase { BRIEFING, EXPLORE, ESCALATE, FINAL, ENDED }

const STATUS_ALIVE := "alive"
const STATUS_DOWNED := "downed"
const STATUS_DEAD := "dead"
const STATUS_ESCAPED := "escaped"

const SNAPSHOT_VERSION := 1

var match_id := ""
var map_id := ""
var difficulty_id := ""
var rng_seed := 0
var player_count := 1
var phase: Phase = Phase.BRIEFING
var elapsed := 0.0
var flags: Dictionary = {}
var counters: Dictionary = {}
var objectives: Dictionary = {}
var entities: Dictionary = {}
var players: Dictionary = {}
## Seeded item placements and puzzle answers. Never sent to clients in full:
## see `client_snapshot()`.
var variant: Dictionary = {}
var result := ""
var collectibles: Dictionary = {}
var checkpoint_id := ""
var next_dynamic_id := 1


func add_player(player_id: int, display_name: String) -> Dictionary:
	var record := {
		"name": display_name,
		"status": STATUS_ALIVE,
		"hits": 0,
		"inventory": [],
		"pos": [0.0, 0.0, 0.0],
		"yaw": 0.0,
		"hiding": "",
		"downed_at": -1.0,
		"caught": 0,
	}
	players[player_id] = record
	return record


func player(player_id: int) -> Dictionary:
	return players.get(player_id, {})


func living_player_ids() -> Array[int]:
	var out: Array[int] = []
	for pid in players:
		if players[pid]["status"] == STATUS_ALIVE:
			out.append(int(pid))
	return out


func set_flag(flag: String, value: Variant = true) -> bool:
	if flags.get(flag) == value:
		return false
	flags[flag] = value
	return true


func has_flag(flag: String) -> bool:
	return bool(flags.get(flag, false))


func add_counter(counter: String, delta: int = 1) -> int:
	counters[counter] = int(counters.get(counter, 0)) + delta
	return int(counters[counter])


func entity(id: String) -> Dictionary:
	return entities.get(id, {})


func allocate_dynamic_id(prefix: String) -> String:
	var id := "%s_%d" % [prefix, next_dynamic_id]
	next_dynamic_id += 1
	return id


## Full state for checkpoints (includes secret puzzle answers).
func to_snapshot() -> Dictionary:
	return {
		"v": SNAPSHOT_VERSION,
		"match_id": match_id,
		"map_id": map_id,
		"difficulty_id": difficulty_id,
		"seed": rng_seed,
		"player_count": player_count,
		"phase": int(phase),
		"elapsed": elapsed,
		"flags": flags.duplicate(true),
		"counters": counters.duplicate(true),
		"objectives": objectives.duplicate(true),
		"entities": entities.duplicate(true),
		"players": _players_with_string_keys(),
		"variant": variant.duplicate(true),
		"result": result,
		"collectibles": collectibles.duplicate(true),
		"checkpoint_id": checkpoint_id,
		"next_dynamic_id": next_dynamic_id,
	}


## State safe to send to clients: puzzle answers are omitted. Clients learn
## clues from the world entities (whose public state carries what is visible).
func client_snapshot() -> Dictionary:
	var snap := to_snapshot()
	snap["variant"] = {}
	return snap


static func from_snapshot(data: Dictionary) -> MatchState:
	var s := MatchState.new()
	if int(data.get("v", -1)) != SNAPSHOT_VERSION:
		return null
	s.match_id = str(data.get("match_id", ""))
	s.map_id = str(data.get("map_id", ""))
	s.difficulty_id = str(data.get("difficulty_id", ""))
	s.rng_seed = int(data.get("seed", 0))
	s.player_count = clampi(int(data.get("player_count", 1)), 1, 6)
	s.phase = clampi(int(data.get("phase", 0)), 0, Phase.ENDED) as Phase
	s.elapsed = maxf(0.0, float(data.get("elapsed", 0.0)))
	s.flags = _dict(data.get("flags"))
	s.counters = _dict(data.get("counters"))
	s.objectives = _normalize_objectives(_dict(data.get("objectives")))
	s.entities = _dict(data.get("entities"))
	s.variant = _dict(data.get("variant"))
	s.result = str(data.get("result", ""))
	s.collectibles = _dict(data.get("collectibles"))
	s.checkpoint_id = str(data.get("checkpoint_id", ""))
	s.next_dynamic_id = maxi(1, int(data.get("next_dynamic_id", 1)))
	var raw_players := _dict(data.get("players"))
	for key in raw_players:
		var pid := int(str(key))
		if pid <= 0:
			continue
		var p := _dict(raw_players[key])
		var record := s.add_player(pid, str(p.get("name", "")))
		record["status"] = str(p.get("status", STATUS_ALIVE))
		record["hits"] = int(p.get("hits", 0))
		record["inventory"] = p.get("inventory", []) if p.get("inventory") is Array else []
		var pos: Variant = p.get("pos", [0, 0, 0])
		if pos is Array and pos.size() == 3:
			record["pos"] = [float(pos[0]), float(pos[1]), float(pos[2])]
		record["yaw"] = float(p.get("yaw", 0.0))
		record["hiding"] = str(p.get("hiding", ""))
		record["downed_at"] = float(p.get("downed_at", -1.0))
		record["caught"] = int(p.get("caught", 0))
	return s


func _players_with_string_keys() -> Dictionary:
	# JSON object keys must be strings; keep a stable representation.
	var out := {}
	for pid in players:
		out[str(pid)] = players[pid].duplicate(true)
	return out


static func _dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _normalize_objectives(raw: Dictionary) -> Dictionary:
	var out := {}
	for id in raw:
		var e := _dict(raw[id])
		out[str(id)] = {
			"state": clampi(int(e.get("state", 0)), 0, 2),
			"activated_at": float(e.get("activated_at", -1.0)),
		}
	return out


static func vec_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


static func array_to_vec(a: Variant) -> Vector3:
	if a is Array and a.size() == 3:
		return Vector3(float(a[0]), float(a[1]), float(a[2]))
	return Vector3.ZERO
