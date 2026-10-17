class_name ItemReceptacle
extends Interactable
## A rack that takes `slots` of one item (the signal box's power cells). Each
## insertion advances a counter; filling it sets `flag`.

@export var item := "power_cell"
@export var slots := 2
@export var flag := "signal_power"
@export var counter := "cells_installed"

var _bays: Array[Node3D] = []
var _lamps: Array[StandardMaterial3D] = []


func _ready() -> void:
	hold_time = 0.8
	var frame := MaterialLib.surface("metal_dark")
	var width := 0.42 * slots + 0.1
	add_mesh(box_mesh(Vector3(width, 0.04, 0.4)), frame, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0)))
	add_mesh(box_mesh(Vector3(width, 0.04, 0.4)), frame, Transform3D(Basis.IDENTITY, Vector3(0, 0.34, 0)))
	add_mesh(box_mesh(Vector3(width, 0.38, 0.02)), frame, Transform3D(Basis.IDENTITY, Vector3(0, 0.17, -0.19)))
	for i in slots:
		var x := -width * 0.5 + 0.26 + i * 0.42
		var bay := ItemVisuals.build(item)
		bay.position = Vector3(x, 0.03, 0.0)
		bay.scale = Vector3.ONE * 1.6
		bay.visible = false
		add_child(bay)
		_bays.append(bay)
		var lamp := MaterialLib.glow(Color(0.8, 0.12, 0.08), 1.0)
		add_mesh(box_mesh(Vector3(0.05, 0.03, 0.01)), lamp, Transform3D(Basis.IDENTITY, Vector3(x, 0.3, 0.2)))
		_lamps.append(lamp)
	add_target(Vector3(width, 0.4, 0.45), Vector3(0, 0.17, 0))


func initial_state() -> Dictionary:
	return {"filled": 0}


func filled() -> int:
	return int(state.get("filled", 0))


func apply_state(new_state: Dictionary) -> void:
	super.apply_state(new_state)
	var n := int(new_state.get("filled", 0))
	for i in _bays.size():
		_bays[i].visible = i < n
		_lamps[i].albedo_color = Color(0.3, 0.9, 0.35) if i < n else Color(0.8, 0.12, 0.08)
		_lamps[i].emission = _lamps[i].albedo_color


func interact_origin() -> Vector3:
	return global_position + Vector3(0, 0.2, 0)


func get_prompt(pid: int, _sub: int) -> String:
	if filled() >= slots:
		return tr("PROMPT_RACK_FULL")
	var def: ItemDefinition = Session.item(item)
	var item_name := tr(def.name_key) if def else item
	if match_ctrl and match_ctrl.has_item(pid, item):
		return tr("PROMPT_RACK_INSERT") % [item_name, filled(), slots]
	return tr("PROMPT_RACK") % [filled(), slots]


func get_hold_time(pid: int, _sub: int) -> float:
	return hold_time if match_ctrl and filled() < slots and match_ctrl.has_item(pid, item) else 0.0


func authority_interact(ctx: Dictionary) -> void:
	var pid: int = ctx["player_id"]
	if filled() >= slots:
		return
	if not match_ctrl.has_item(pid, item):
		var def: ItemDefinition = Session.item(item)
		match_ctrl.notify_player(pid, "RACK_NEEDS", [tr(def.name_key) if def else item])
		return
	match_ctrl.take_item(pid, item)
	var n := filled() + 1
	match_ctrl.set_entity_state(entity_id, {"filled": n})
	match_ctrl.add_counter(counter)
	world_sound("battery_insert", 0.0, 14.0)
	match_ctrl.emit_noise(interact_origin(), 4.0, "rack", pid)
	if n >= slots:
		world_sound("power_on", 2.0, 40.0)
		match_ctrl.emit_noise(interact_origin(), 12.0, "power")
		match_ctrl.set_flag(flag)
