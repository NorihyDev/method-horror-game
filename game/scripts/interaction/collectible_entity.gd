class_name CollectibleEntity
extends Interactable
## A METHOD file folder. Recorded per match and to local progression.

@export var collectible_id := ""
@export var counter := "files"
@export var target := 3
@export var all_flag := "files_all"


func _ready() -> void:
	prompt_key = "PROMPT_TAKE_FILE"
	add_mesh(box_mesh(Vector3(0.24, 0.02, 0.32)), MaterialLib.flat(Color(0.42, 0.07, 0.06), 0.8))
	add_mesh(
		box_mesh(Vector3(0.22, 0.024, 0.3)),
		MaterialLib.flat(Color(0.82, 0.78, 0.68), 0.9),
		Transform3D(Basis.IDENTITY, Vector3(0.006, 0.0, 0.004))
	)
	var stamp := Label3D.new()
	stamp.text = "METHOD"
	stamp.font_size = 40
	stamp.pixel_size = 0.0012
	stamp.modulate = Color(0.82, 0.78, 0.68)
	stamp.shaded = true
	stamp.rotation = Vector3(-PI / 2, 0, 0)
	stamp.position = Vector3(0, 0.013, 0)
	add_child(stamp)
	add_target(Vector3(0.36, 0.12, 0.4))


func initial_state() -> Dictionary:
	return {"taken": false, "active": false}


func apply_state(new_state: Dictionary) -> void:
	super.apply_state(new_state)
	var shown := bool(new_state.get("active", false)) and not bool(new_state.get("taken", false))
	visible = shown
	for child in get_children():
		if child is StaticBody3D:
			(child as StaticBody3D).collision_layer = LAYER_INTERACT if shown else 0


func authority_interact(ctx: Dictionary) -> void:
	if bool(state.get("taken", false)) or not bool(state.get("active", false)):
		return
	var pid: int = ctx["player_id"]
	var s := state.duplicate()
	s["taken"] = true
	match_ctrl.set_entity_state(entity_id, s)
	match_ctrl.state.collectibles[collectible_id] = pid
	world_sound("page_turn", -4.0, 8.0)
	var n := match_ctrl.add_counter(counter)
	match_ctrl.notify_player(pid, "FILE_FOUND", [n, target])
	if n >= target:
		match_ctrl.set_flag(all_flag)
