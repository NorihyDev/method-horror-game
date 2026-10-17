class_name EmergencyPanel
extends Interactable
## Emergency power board: five circuit breakers, a socket for the generator's
## starter relay and the start lever. The duty electrician's schematic (a
## note with seeded text) says which circuits must be live; the rest carry a
## fault. Starting with the wrong set trips every breaker open — loudly — and
## the board has to be set again. Sub-targets: 1-5 breakers, 6 relay, 7 lever.

const BREAKERS := 5
const SUB_RELAY := 6
const SUB_START := 7
const LABELS: PackedStringArray = ["C1", "C2", "C3", "C4", "C5"]

@export var power_flag := "ward_power"
@export var relay_item := "starter_relay"

var _handles: Array[Node3D] = []
var _lamps: Array[StandardMaterial3D] = []
var _relay_node: Node3D
var _status_mat: StandardMaterial3D
var _lever: Node3D


func _ready() -> void:
	prompt_key = "PROMPT_EMERGENCY_PANEL"
	var body := MaterialLib.surface("metal_green")
	add_mesh(box_mesh(Vector3(1.3, 1.0, 0.2)), body, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.1)))
	add_mesh(
		box_mesh(Vector3(1.22, 0.92, 0.02)),
		MaterialLib.flat(Color(0.07, 0.07, 0.07), 0.8),
		Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.005))
	)
	var title := _label("METHOD  ·  EMERGENCY SUPPLY", 22, Vector3(0, 0.4, 0.02))
	title.modulate = Color(0.85, 0.82, 0.74)
	var handle_mat := MaterialLib.flat(Color(0.12, 0.12, 0.12), 0.5)
	for i in BREAKERS:
		var x := -0.5 + i * 0.16
		add_mesh(
			box_mesh(Vector3(0.11, 0.22, 0.04)),
			MaterialLib.flat(Color(0.7, 0.68, 0.6), 0.6),
			Transform3D(Basis.IDENTITY, Vector3(x, 0.08, 0.02))
		)
		_label(LABELS[i], 34, Vector3(x, 0.26, 0.022)).modulate = Color(0.85, 0.82, 0.74)
		var pivot := Node3D.new()
		pivot.position = Vector3(x, 0.08, 0.05)
		add_child(pivot)
		add_mesh(
			box_mesh(Vector3(0.05, 0.11, 0.03)), handle_mat, Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), pivot
		)
		_handles.append(pivot)
		var lamp := MaterialLib.glow(Color(0.25, 0.05, 0.04), 0.4)
		var lm := add_mesh(
			box_mesh(Vector3(0.04, 0.03, 0.01)), lamp, Transform3D(Basis.IDENTITY, Vector3(x, -0.08, 0.025))
		)
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_lamps.append(lamp)
		add_target(Vector3(0.13, 0.3, 0.14), Vector3(x, 0.08, 0.06), i + 1)
	# Relay socket (bottom left) and start lever (right).
	add_mesh(
		box_mesh(Vector3(0.16, 0.12, 0.05)),
		MaterialLib.flat(Color(0.2, 0.2, 0.2), 0.6),
		Transform3D(Basis.IDENTITY, Vector3(-0.42, -0.3, 0.02))
	)
	_label("RELAY", 24, Vector3(-0.42, -0.19, 0.022)).modulate = Color(0.85, 0.82, 0.74)
	_relay_node = ItemVisuals.build(relay_item)
	_relay_node.position = Vector3(-0.42, -0.33, 0.06)
	_relay_node.rotation = Vector3(PI / 2, 0, 0)
	_relay_node.scale = Vector3.ONE * 1.6
	_relay_node.visible = false
	add_child(_relay_node)
	add_target(Vector3(0.2, 0.18, 0.12), Vector3(-0.42, -0.3, 0.06), SUB_RELAY)
	_lever = Node3D.new()
	_lever.position = Vector3(0.48, -0.22, 0.06)
	add_child(_lever)
	add_mesh(
		box_mesh(Vector3(0.04, 0.3, 0.04)),
		MaterialLib.surface("metal"),
		Transform3D(Basis.IDENTITY, Vector3(0, 0.15, 0)),
		_lever
	)
	add_mesh(
		box_mesh(Vector3(0.12, 0.06, 0.06)),
		MaterialLib.flat(Color(0.6, 0.08, 0.06), 0.4),
		Transform3D(Basis.IDENTITY, Vector3(0, 0.31, 0)),
		_lever
	)
	_label("START", 24, Vector3(0.48, -0.4, 0.022)).modulate = Color(0.85, 0.82, 0.74)
	add_target(Vector3(0.2, 0.42, 0.14), Vector3(0.48, -0.06, 0.08), SUB_START)
	_status_mat = MaterialLib.glow(Color(0.8, 0.1, 0.08), 1.2)
	add_mesh(box_mesh(Vector3(0.05, 0.05, 0.02)), _status_mat, Transform3D(Basis.IDENTITY, Vector3(0.48, 0.4, 0.02)))


func _label(text: String, size: int, pos: Vector3) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.0016
	l.shaded = true
	l.position = pos
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	add_child(l)
	return l


func initial_state() -> Dictionary:
	return {"breakers": [false, false, false, false, false], "relay": false, "powered": false}


func apply_state(new_state: Dictionary) -> void:
	super.apply_state(new_state)
	var breakers: Array = new_state.get("breakers", [])
	for i in mini(breakers.size(), _handles.size()):
		var on := bool(breakers[i])
		_handles[i].rotation.x = deg_to_rad(-35.0 if on else 35.0)
		_lamps[i].albedo_color = Color(0.9, 0.6, 0.15) if on else Color(0.25, 0.05, 0.04)
		_lamps[i].emission = _lamps[i].albedo_color
		_lamps[i].emission_energy_multiplier = 2.0 if on else 0.4
	_relay_node.visible = bool(new_state.get("relay", false))
	var powered := bool(new_state.get("powered", false))
	_lever.rotation.x = deg_to_rad(-60.0 if powered else 0.0)
	_status_mat.albedo_color = Color(0.3, 0.9, 0.35) if powered else Color(0.8, 0.1, 0.08)
	_status_mat.emission = _status_mat.albedo_color


func breakers() -> Array:
	return state.get("breakers", [])


func is_powered() -> bool:
	return bool(state.get("powered", false))


func get_prompt(pid: int, sub: int) -> String:
	if is_powered():
		return tr("PROMPT_GENERATOR_RUNNING")
	if sub >= 1 and sub <= BREAKERS:
		var on := bool(breakers()[sub - 1]) if breakers().size() >= sub else false
		return tr("PROMPT_BREAKER") % [LABELS[sub - 1], tr("STATE_ON" if on else "STATE_OFF")]
	if sub == SUB_RELAY:
		if bool(state.get("relay", false)):
			return tr("PROMPT_RELAY_FITTED")
		if match_ctrl and match_ctrl.has_item(pid, relay_item):
			return tr("PROMPT_FIT_RELAY")
		return tr("PROMPT_RELAY_EMPTY")
	if sub == SUB_START:
		return tr("PROMPT_START_GENERATOR")
	return tr(prompt_key)


func get_hold_time(_pid: int, sub: int) -> float:
	match sub:
		SUB_RELAY:
			return 0.8
		SUB_START:
			return 1.0
	return 0.0


func authority_interact(ctx: Dictionary) -> void:
	var pid: int = ctx["player_id"]
	var sub: int = ctx["sub"]
	if is_powered() or sub < 1 or sub > SUB_START:
		return
	var s := state.duplicate(true)
	if sub <= BREAKERS:
		var list: Array = s["breakers"]
		list[sub - 1] = not bool(list[sub - 1])
		match_ctrl.set_entity_state(entity_id, s)
		world_sound("breaker_flip", -2.0, 14.0)
		match_ctrl.emit_noise(interact_origin(), 4.5, "breaker", pid)
		return
	if sub == SUB_RELAY:
		if bool(s["relay"]):
			return
		if not match_ctrl.has_item(pid, relay_item):
			match_ctrl.notify_player(pid, "RELAY_NEEDED")
			return
		match_ctrl.take_item(pid, relay_item)
		s["relay"] = true
		match_ctrl.set_entity_state(entity_id, s)
		world_sound("fuse_insert", -2.0, 12.0)
		return
	# Start lever.
	if not bool(s["relay"]):
		world_sound("card_deny", -4.0, 12.0)
		match_ctrl.notify_player(pid, "GENERATOR_NO_RELAY")
		return
	var wanted: Array = match_ctrl.puzzle().get("circuit", [])
	if wanted.size() == BREAKERS and _matches(s["breakers"], wanted):
		s["powered"] = true
		match_ctrl.set_entity_state(entity_id, s)
		world_sound("generator_start", 2.0, 45.0)
		match_ctrl.emit_noise(interact_origin(), 18.0, "power")
		match_ctrl.set_flag(power_flag)
		return
	# Overload: every breaker throws itself open; the board must be set again.
	s["breakers"] = [false, false, false, false, false]
	match_ctrl.set_entity_state(entity_id, s)
	world_sound("breaker_trip", 4.0, 40.0)
	match_ctrl.emit_noise(interact_origin(), 24.0, "short", pid)
	match_ctrl.notify_player(pid, "CIRCUIT_TRIPPED")
	var node: Node = match_ctrl.players.get(pid)
	if node and node.has_method("on_shocked"):
		node.call("on_shocked")


static func _matches(have: Array, want: Array) -> bool:
	if have.size() != want.size():
		return false
	for i in have.size():
		if bool(have[i]) != bool(want[i]):
			return false
	return true
