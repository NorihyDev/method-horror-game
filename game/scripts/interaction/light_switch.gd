class_name LightSwitch
extends Interactable
## Wall switch for a room's lamps. Light makes you easier to see; darkness
## makes you harder to see but slower to navigate.

@export var room := ""
var _lever: MeshInstance3D


func _ready() -> void:
	add_mesh(box_mesh(Vector3(0.08, 0.12, 0.015)), MaterialLib.flat(Color(0.78, 0.74, 0.66), 0.6))
	_lever = add_mesh(
		box_mesh(Vector3(0.015, 0.04, 0.02)),
		MaterialLib.flat(Color(0.3, 0.28, 0.25), 0.5),
		Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.012))
	)
	add_target(Vector3(0.2, 0.25, 0.1))


func initial_state() -> Dictionary:
	return {"on": true}


func apply_state(new_state: Dictionary) -> void:
	super.apply_state(new_state)
	var on := bool(new_state.get("on", true))
	_lever.rotation.x = deg_to_rad(-25 if on else 25)
	var map := _map()
	if map:
		for lamp in map.lamps:
			if lamp.room == room:
				lamp.set_switched(on)


func _map() -> MapBase:
	var n: Node = self
	while n and not n is MapBase:
		n = n.get_parent()
	return n as MapBase


func get_prompt(_pid: int, _sub: int) -> String:
	return tr("PROMPT_LIGHTS_OFF") if bool(state.get("on", true)) else tr("PROMPT_LIGHTS_ON")


func authority_interact(_ctx: Dictionary) -> void:
	match_ctrl.set_entity_state(entity_id, {"on": not bool(state.get("on", true))})
	world_sound("switch", -6.0, 8.0)
	match_ctrl.emit_noise(interact_origin(), 2.5, "switch")
