class_name WorkbenchEntity
extends Interactable
## Combines repair components into an assembly. Recipe ingredients must all be
## in the interacting player's inventory.

@export var inputs: PackedStringArray = ["drive_belt", "drive_gear"]
@export var output := "drive_assembly"


func _ready() -> void:
	prompt_key = "PROMPT_WORKBENCH"
	hold_time = 1.2
	add_target(Vector3(1.8, 0.4, 0.7), Vector3(0, 0.95, 0))


func interact_origin() -> Vector3:
	return global_position + Vector3(0, 0.95, 0)


func get_prompt(pid: int, _sub: int) -> String:
	if match_ctrl and _has_all(pid):
		return tr("PROMPT_COMBINE")
	return tr("PROMPT_WORKBENCH")


func get_hold_time(pid: int, _sub: int) -> float:
	return hold_time if match_ctrl and _has_all(pid) else 0.0


func _has_all(pid: int) -> bool:
	for item in inputs:
		if not match_ctrl.has_item(pid, item):
			return false
	return true


func authority_interact(ctx: Dictionary) -> void:
	var pid: int = ctx["player_id"]
	var missing: PackedStringArray = []
	for item in inputs:
		if not match_ctrl.has_item(pid, item):
			var def: ItemDefinition = Session.item(item)
			missing.append(tr(def.name_key if def else item))
	if not missing.is_empty():
		match_ctrl.notify_player(pid, "WORKBENCH_MISSING", [", ".join(missing)])
		return
	var inv := match_ctrl.inventory(pid)
	# Output takes the slot freed by the inputs, so this cannot fail on space.
	for item in inputs:
		match_ctrl.take_item(pid, item)
	if not inv.can_add(output):
		for item in inputs:
			match_ctrl.give_item(pid, item)
		return
	match_ctrl.give_item(pid, output)
	world_sound("workbench", -2.0, 18.0)
	match_ctrl.emit_noise(interact_origin(), 9.0, "workbench")
	var def: ItemDefinition = Session.item(output)
	match_ctrl.notify_player(pid, "CRAFTED", [tr(def.name_key if def else output)])
