class_name LeverFrame
extends Interactable
## Signal box lever frame. Four levers each sit Normal or Reverse; the
## evacuation route card (a note with seeded text) gives the setting. The
## "set route" plunger needs power and checks the levers: right → the route
## locks (`route_flag`); wrong → the conflict bell rings, loud enough to carry.
## Sub-targets: 1-4 levers, 5 plunger.

const LEVERS := 4
const SUB_SET := 5
const COLORS: Array[Color] = [
	Color(0.6, 0.1, 0.08), Color(0.08, 0.08, 0.08), Color(0.65, 0.55, 0.1), Color(0.1, 0.25, 0.55)
]

@export var power_flag := "signal_power"
@export var route_flag := "route_set"

var _levers: Array[Node3D] = []
var _route_mat: StandardMaterial3D


func _ready() -> void:
	prompt_key = "PROMPT_LEVER_FRAME"
	var steel := MaterialLib.surface("metal_dark")
	add_mesh(box_mesh(Vector3(1.5, 0.12, 0.5)), steel, Transform3D(Basis.IDENTITY, Vector3(0, 0.06, 0)))
	add_mesh(box_mesh(Vector3(1.5, 0.9, 0.08)), steel, Transform3D(Basis.IDENTITY, Vector3(0, 1.4, -0.3)))
	var diagram := Label3D.new()
	diagram.text = "PLATFORM 2  ⇄  DEPOT LINE\n1      2      3      4"
	diagram.font_size = 30
	diagram.pixel_size = 0.0022
	diagram.shaded = true
	diagram.modulate = Color(0.85, 0.82, 0.74)
	diagram.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	diagram.position = Vector3(0, 1.55, -0.255)
	add_child(diagram)
	for i in LEVERS:
		var x := -0.54 + i * 0.36
		var pivot := Node3D.new()
		pivot.position = Vector3(x, 0.14, 0)
		add_child(pivot)
		add_mesh(
			box_mesh(Vector3(0.06, 1.1, 0.06)),
			MaterialLib.flat(COLORS[i], 0.5),
			Transform3D(Basis.IDENTITY, Vector3(0, 0.55, 0)),
			pivot
		)
		add_mesh(
			box_mesh(Vector3(0.12, 0.1, 0.08)),
			MaterialLib.surface("metal"),
			Transform3D(Basis.IDENTITY, Vector3(0, 1.1, 0)),
			pivot
		)
		var plate := Label3D.new()
		plate.text = str(i + 1)
		plate.font_size = 48
		plate.pixel_size = 0.002
		plate.shaded = true
		plate.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		plate.position = Vector3(x, 0.2, 0.26)
		add_child(plate)
		_levers.append(pivot)
		add_target(Vector3(0.18, 1.2, 0.3), Vector3(x, 0.75, 0.0), i + 1)
	_route_mat = MaterialLib.glow(Color(0.8, 0.12, 0.08), 1.2)
	add_mesh(box_mesh(Vector3(0.14, 0.14, 0.06)), _route_mat, Transform3D(Basis.IDENTITY, Vector3(0.68, 1.15, -0.24)))
	add_mesh(
		box_mesh(Vector3(0.1, 0.1, 0.12)),
		MaterialLib.flat(Color(0.12, 0.12, 0.12), 0.5),
		Transform3D(Basis.IDENTITY, Vector3(0.68, 0.95, -0.22))
	)
	add_target(Vector3(0.22, 0.4, 0.2), Vector3(0.68, 1.05, -0.2), SUB_SET)


func initial_state() -> Dictionary:
	return {"levers": [false, false, false, false], "set": false}


func levers() -> Array:
	return state.get("levers", [])


func apply_state(new_state: Dictionary) -> void:
	super.apply_state(new_state)
	var list: Array = new_state.get("levers", [])
	for i in mini(list.size(), _levers.size()):
		_levers[i].rotation.x = deg_to_rad(28.0 if bool(list[i]) else -28.0)
	var done := bool(new_state.get("set", false))
	_route_mat.albedo_color = Color(0.3, 0.9, 0.35) if done else Color(0.8, 0.12, 0.08)
	_route_mat.emission = _route_mat.albedo_color


func get_prompt(_pid: int, sub: int) -> String:
	if bool(state.get("set", false)):
		return tr("PROMPT_ROUTE_SET")
	if sub >= 1 and sub <= LEVERS:
		var reverse := bool(levers()[sub - 1]) if levers().size() >= sub else false
		return tr("PROMPT_LEVER") % [sub, tr("LEVER_REVERSE" if reverse else "LEVER_NORMAL")]
	if sub == SUB_SET:
		return tr("PROMPT_SET_ROUTE")
	return tr(prompt_key)


func get_hold_time(_pid: int, sub: int) -> float:
	return 0.5 if sub >= 1 and sub <= LEVERS else (0.7 if sub == SUB_SET else 0.0)


func authority_interact(ctx: Dictionary) -> void:
	var pid: int = ctx["player_id"]
	var sub: int = ctx["sub"]
	if bool(state.get("set", false)) or sub < 1 or sub > SUB_SET:
		return
	var s := state.duplicate(true)
	if sub <= LEVERS:
		var list: Array = s["levers"]
		list[sub - 1] = not bool(list[sub - 1])
		match_ctrl.set_entity_state(entity_id, s)
		world_sound("lever_pull", 0.0, 18.0)
		match_ctrl.emit_noise(interact_origin(), 7.0, "lever", pid)
		return
	if not match_ctrl.state.has_flag(power_flag):
		world_sound("card_deny", -4.0, 12.0)
		match_ctrl.notify_player(pid, "FRAME_NO_POWER")
		return
	var wanted: Array = match_ctrl.puzzle().get("route", [])
	if wanted.size() == LEVERS and EmergencyPanel._matches(s["levers"], wanted):
		s["set"] = true
		match_ctrl.set_entity_state(entity_id, s)
		world_sound("relay_click", 0.0, 20.0)
		match_ctrl.set_flag(route_flag)
		return
	world_sound("signal_bell", 4.0, 45.0)
	match_ctrl.emit_noise(interact_origin(), 26.0, "bell", pid)
	match_ctrl.notify_player(pid, "ROUTE_CONFLICT")
