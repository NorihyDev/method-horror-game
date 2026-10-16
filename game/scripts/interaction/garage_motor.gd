class_name GarageMotor
extends Interactable
## Garage door motor. Step 1: install the drive assembly. Step 2 (needs
## power): crank-start it by pressing while the gauge needle is inside the
## marked window, three times. Misses are loud. A second player standing close
## steadies the motor and widens the window (co-op assist, never required).

const CYCLE_SECONDS := 1.6
const SUCCESSES_NEEDED := 3
const ASSIST_RADIUS := 2.6
const ASSIST_FACTOR := 1.6
const CRANK_COOLDOWN := 0.45
## How far in the past a client's press time may be honored (lag compensation).
const MAX_PRESS_LAG := 0.4

@export var assembly_item := "drive_assembly"
@export var repaired_flag := "motor_repaired"
@export var power_flag := "power_on"
@export var open_flag := "garage_open"

var _belt: Node3D
var _last_crank := -10.0


func _ready() -> void:
	var metal := MaterialLib.surface("metal_dark")
	add_mesh(box_mesh(Vector3(0.6, 0.35, 0.45)), metal)
	add_mesh(
		box_mesh(Vector3(0.12, 0.12, 0.6)),
		MaterialLib.surface("metal"),
		Transform3D(Basis.IDENTITY, Vector3(0.36, 0, 0))
	)
	var crank := MaterialLib.flat(Color(0.5, 0.08, 0.07), 0.5, 0.4)
	add_mesh(box_mesh(Vector3(0.04, 0.3, 0.04)), crank, Transform3D(Basis.IDENTITY, Vector3(-0.32, -0.28, 0.25)))
	add_mesh(box_mesh(Vector3(0.14, 0.04, 0.04)), crank, Transform3D(Basis.IDENTITY, Vector3(-0.27, -0.43, 0.25)))
	_belt = ItemVisuals.build("assembly")
	_belt.rotation = Vector3(PI / 2, 0, 0)
	_belt.position = Vector3(0.36, 0, 0.32)
	_belt.scale = Vector3.ONE * 1.6
	_belt.visible = false
	add_child(_belt)
	var tag := Label3D.new()
	tag.text = "LIFT-MASTER  ·  HAND START"
	tag.font_size = 18
	tag.pixel_size = 0.0015
	tag.shaded = true
	tag.modulate = Color(0.8, 0.77, 0.7)
	tag.position = Vector3(0, 0.1, 0.23)
	add_child(tag)
	add_target(Vector3(0.9, 0.8, 0.8), Vector3(0, -0.1, 0.1))


func initial_state() -> Dictionary:
	return {"repaired": false, "successes": 0, "started": false}


func apply_state(new_state: Dictionary) -> void:
	super.apply_state(new_state)
	_belt.visible = bool(new_state.get("repaired", false))


func interact_origin() -> Vector3:
	return global_position


func is_crank_ready() -> bool:
	return (
		match_ctrl != null
		and bool(state.get("repaired", false))
		and match_ctrl.state.has_flag(power_flag)
		and not bool(state.get("started", false))
	)


## Needle phase 0..1 derived from match time (identical on authority and clients).
func needle_phase(at_time: float = -1.0) -> float:
	if match_ctrl == null:
		return 0.0
	var t := match_ctrl.state.elapsed if at_time < 0.0 else at_time
	return fmod(t / CYCLE_SECONDS, 1.0)


## Window width as a fraction of the cycle for a given player.
func window_for(pid: int) -> float:
	var w := match_ctrl.difficulty.timing_window if match_ctrl else 0.16
	if _assisted(pid):
		w *= ASSIST_FACTOR
	return w


static func needle_position(phase: float) -> float:
	# Ping-pong sweep 0 → 1 → 0 across the gauge.
	return 1.0 - absf(phase * 2.0 - 1.0)


func needle_in_window(pid: int, at_time: float = -1.0) -> bool:
	return absf(needle_position(needle_phase(at_time)) - 0.5) <= window_for(pid) * 0.5


## Client-side: arguments sent with a crank press (the match time it happened).
func crank_args() -> Dictionary:
	return {"t": match_ctrl.state.elapsed if match_ctrl else 0.0}


func _assisted(pid: int) -> bool:
	if match_ctrl == null:
		return false
	for other in match_ctrl.state.players:
		if int(other) == pid:
			continue
		var p: Dictionary = match_ctrl.state.players[other]
		if (
			p["status"] == MatchState.STATUS_ALIVE
			and MatchState.array_to_vec(p["pos"]).distance_to(global_position) < ASSIST_RADIUS + 1.5
		):
			return true
	return false


func get_prompt(pid: int, _sub: int) -> String:
	if bool(state.get("started", false)):
		return tr("PROMPT_MOTOR_RUNNING")
	if not bool(state.get("repaired", false)):
		return tr("PROMPT_INSTALL") if match_ctrl and match_ctrl.has_item(pid, assembly_item) else tr("PROMPT_MOTOR")
	if match_ctrl and not match_ctrl.state.has_flag(power_flag):
		return tr("PROMPT_MOTOR_NO_POWER")
	return tr("PROMPT_CRANK") % [int(state.get("successes", 0)), SUCCESSES_NEEDED]


func get_hold_time(pid: int, _sub: int) -> float:
	if not bool(state.get("repaired", false)) and match_ctrl and match_ctrl.has_item(pid, assembly_item):
		return 1.5
	return 0.0


func authority_interact(ctx: Dictionary) -> void:
	var pid: int = ctx["player_id"]
	match_ctrl.set_flag("exit_found")
	if bool(state.get("started", false)):
		return
	if not bool(state.get("repaired", false)):
		if match_ctrl.take_item(pid, assembly_item):
			var s := state.duplicate()
			s["repaired"] = true
			match_ctrl.set_entity_state(entity_id, s)
			world_sound("workbench", -2.0, 16.0)
			match_ctrl.set_flag(repaired_flag)
		else:
			match_ctrl.notify_player(pid, "MOTOR_BROKEN")
		return
	if not match_ctrl.state.has_flag(power_flag):
		match_ctrl.notify_player(pid, "MOTOR_NO_POWER")
		return
	var now := match_ctrl.state.elapsed
	if now - _last_crank < CRANK_COOLDOWN:
		return
	_last_crank = now
	# Honor the client's press time if it is recent; never a future time.
	var press_time := now
	if ctx["args"].has("t"):
		var t := float(ctx["args"]["t"])
		if t <= now + 0.05 and t >= now - MAX_PRESS_LAG:
			press_time = minf(t, now)
	var s := state.duplicate()
	if needle_in_window(pid, press_time):
		s["successes"] = int(s.get("successes", 0)) + 1
		world_sound("crank_ok", 0.0, 22.0)
		match_ctrl.emit_noise(interact_origin(), 8.0, "crank")
		if int(s["successes"]) >= SUCCESSES_NEEDED:
			s["started"] = true
			match_ctrl.set_entity_state(entity_id, s)
			match_ctrl.set_flag(open_flag)
			return
	else:
		world_sound("crank_clank", 3.0, 35.0)
		match_ctrl.emit_noise(interact_origin(), 22.0, "clank")
		match_ctrl.notify_player(pid, "CRANK_MISS")
	match_ctrl.set_entity_state(entity_id, s)
