class_name FusePanel
extends Interactable
## Breaker panel with four sockets (I-IV). One socket, chosen by the match
## seed, is scorched internally: a fuse placed there shorts out loudly and pops
## back onto the floor (recoverable). The caretaker's breaker chart (a note)
## names the bad socket. Filling the three good sockets restores power.

const SOCKETS := 4
const LABELS: PackedStringArray = ["I", "II", "III", "IV"]

@export var power_flag := "power_on"
@export var counter := "fuses_installed"

var _fuse_nodes: Array[Node3D] = []
var _lamp_mat: StandardMaterial3D


func _ready() -> void:
	var body := MaterialLib.surface("metal_green")
	add_mesh(box_mesh(Vector3(0.7, 0.9, 0.14)), body, Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.07)))
	add_mesh(
		box_mesh(Vector3(0.62, 0.82, 0.02)),
		MaterialLib.flat(Color(0.08, 0.08, 0.08), 0.8),
		Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.005))
	)
	# Open hinged cover.
	add_mesh(box_mesh(Vector3(0.02, 0.9, 0.66)), body, Transform3D(Basis.IDENTITY, Vector3(-0.36, 0, 0.33)))
	var stencil := Label3D.new()
	stencil.text = "METHOD  ·  CIRCUIT B"
	stencil.font_size = 22
	stencil.pixel_size = 0.0015
	stencil.modulate = Color(0.85, 0.82, 0.74)
	stencil.shaded = true
	stencil.position = Vector3(0, 0.36, 0.02)
	add_child(stencil)
	for i in SOCKETS:
		var x := -0.21 + i * 0.14
		var socket_pos := Vector3(x, -0.02, 0.02)
		add_mesh(
			box_mesh(Vector3(0.1, 0.22, 0.03)),
			MaterialLib.flat(Color(0.75, 0.72, 0.62), 0.6),
			Transform3D(Basis.IDENTITY, socket_pos)
		)
		var label := Label3D.new()
		label.text = LABELS[i]
		label.font_size = 40
		label.pixel_size = 0.0018
		label.modulate = Color(0.1, 0.1, 0.1)
		label.shaded = true
		label.position = socket_pos + Vector3(0, 0.16, 0.002)
		add_child(label)
		var fuse := ItemVisuals.build("fuse")
		fuse.rotation = Vector3(0, 0, PI / 2)
		fuse.position = socket_pos + Vector3(0, 0, 0.03)
		fuse.scale = Vector3.ONE * 1.4
		fuse.visible = false
		add_child(fuse)
		_fuse_nodes.append(fuse)
		add_target(Vector3(0.13, 0.3, 0.12), socket_pos + Vector3(0, 0, 0.04), i + 1)
	_lamp_mat = MaterialLib.glow(Color(0.8, 0.1, 0.08), 0.0)
	var lamp := add_mesh(
		box_mesh(Vector3(0.05, 0.05, 0.02)), _lamp_mat, Transform3D(Basis.IDENTITY, Vector3(0.24, -0.33, 0.02))
	)
	lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func initial_state() -> Dictionary:
	return {"sockets": [false, false, false, false], "powered": false}


func apply_state(new_state: Dictionary) -> void:
	super.apply_state(new_state)
	var sockets: Array = new_state.get("sockets", [])
	for i in mini(sockets.size(), _fuse_nodes.size()):
		_fuse_nodes[i].visible = bool(sockets[i])
	var powered := bool(new_state.get("powered", false))
	_lamp_mat.albedo_color = Color(0.3, 0.9, 0.35) if powered else Color(0.8, 0.1, 0.08)
	_lamp_mat.emission = _lamp_mat.albedo_color
	_lamp_mat.emission_energy_multiplier = 2.5 if powered else 1.2


func interact_origin() -> Vector3:
	return global_position


func get_prompt(pid: int, sub: int) -> String:
	if sub <= 0 or bool(state.get("powered", false)):
		return tr("PROMPT_PANEL_DONE") if bool(state.get("powered", false)) else tr("PROMPT_PANEL")
	var sockets: Array = state.get("sockets", [])
	if sub - 1 < sockets.size() and bool(sockets[sub - 1]):
		return tr("PROMPT_SOCKET_FULL") % LABELS[sub - 1]
	if match_ctrl and match_ctrl.has_item(pid, "fuse"):
		return tr("PROMPT_INSERT_FUSE") % LABELS[sub - 1]
	return tr("PROMPT_SOCKET_EMPTY") % LABELS[sub - 1]


func get_hold_time(_pid: int, sub: int) -> float:
	return 0.6 if sub > 0 else 0.0


func authority_interact(ctx: Dictionary) -> void:
	var pid: int = ctx["player_id"]
	var sub: int = ctx["sub"]
	if bool(state.get("powered", false)) or sub < 1 or sub > SOCKETS:
		return
	var sockets: Array = (state.get("sockets", [false, false, false, false]) as Array).duplicate()
	var idx := sub - 1
	if bool(sockets[idx]):
		return
	if not match_ctrl.has_item(pid, "fuse"):
		match_ctrl.notify_player(pid, "FUSE_NEEDED")
		return
	var faulty := int(match_ctrl.puzzle().get("faulty_socket", -1))
	if idx == faulty:
		# Short circuit: loud, visible, and the fuse lands on the floor.
		match_ctrl.take_item(pid, "fuse")
		world_sound("short_circuit", 4.0, 40.0)
		match_ctrl.emit_noise(interact_origin(), 24.0, "short")
		match_ctrl.notify_player(pid, "FUSE_SHORTED")
		# The panel faces local +Z; the fuse lands on the floor in front of it.
		var front := global_position + global_basis.z * 0.55
		var drop_pos := match_ctrl.map.safe_drop_position(Vector3(front.x, global_position.y - 1.0, front.z), 0.0)
		var id := match_ctrl.state.allocate_dynamic_id("drop")
		match_ctrl.map.spawn_dropped_item(match_ctrl, id, "fuse", drop_pos)
		match_ctrl.set_entity_state(
			id, {"kind": "dropped", "item": "fuse", "pos": MatchState.vec_to_array(drop_pos), "taken": false}
		)
		if match_ctrl.net:
			match_ctrl.net.call("broadcast_spawn_drop", id, "fuse", drop_pos)
		var node: Node = match_ctrl.players.get(pid)
		if node and node.has_method("on_shocked"):
			node.call("on_shocked")
		return
	match_ctrl.take_item(pid, "fuse")
	sockets[idx] = true
	var filled := 0
	for i in SOCKETS:
		if bool(sockets[i]) and i != faulty:
			filled += 1
	var needed := SOCKETS - 1
	var powered := filled >= needed
	match_ctrl.set_entity_state(entity_id, {"sockets": sockets, "powered": powered})
	match_ctrl.add_counter(counter)
	world_sound("fuse_insert", -2.0, 12.0)
	if powered:
		world_sound("power_on", 2.0, 40.0)
		match_ctrl.emit_noise(interact_origin(), 14.0, "power")
		match_ctrl.set_flag(power_flag)
