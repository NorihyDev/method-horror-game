class_name HidingSpot
extends Interactable
## Locker or wardrobe a player can hide in. Hiding hides you from sight, not
## from consequences: if the Watcher saw you get in, or searches the exact spot
## where it lost you, it will check here (see docs/game-design.md#hiding).

@export var style := "locker"
## Where the hidden player's camera sits (local space).
@export var view_offset := Vector3(0, 1.55, -0.05)
## Where the player stands after leaving (local space).
@export var exit_offset := Vector3(0, 0, 0.9)
## Optional flag set when someone hides here (tutorial objectives).
@export var hide_flag := ""

var _door: Node3D
var _tween: Tween


func _ready() -> void:
	var mat := MaterialLib.surface("metal_green" if style == "locker" else "dark_wood")
	var w := 0.7 if style == "locker" else 1.1
	var d := 0.6
	var h := 2.0
	# Shell (back, sides, top, bottom) as an open box.
	var body := StaticBody3D.new()
	body.collision_layer = GeoBuilder.LAYER_WORLD
	body.collision_mask = 0
	add_child(body)
	for part in [
		[Vector3(w, h, 0.03), Vector3(0, h * 0.5, -d * 0.5)],
		[Vector3(0.03, h, d), Vector3(-w * 0.5, h * 0.5, 0)],
		[Vector3(0.03, h, d), Vector3(w * 0.5, h * 0.5, 0)],
		[Vector3(w, 0.03, d), Vector3(0, h, 0)],
		[Vector3(w, 0.03, d), Vector3(0, 0.015, 0)],
	]:
		add_mesh(box_mesh(part[0]), mat, Transform3D(Basis.IDENTITY, part[1]))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = part[0]
		cs.shape = bs
		cs.position = part[1]
		body.add_child(cs)
	# Front blocker so nothing walks into an occupied locker.
	var front := CollisionShape3D.new()
	var fs := BoxShape3D.new()
	fs.size = Vector3(w, h, 0.04)
	front.shape = fs
	front.position = Vector3(0, h * 0.5, d * 0.5)
	body.add_child(front)
	_door = Node3D.new()
	_door.position = Vector3(-w * 0.5, 0, d * 0.5)
	add_child(_door)
	add_mesh(
		box_mesh(Vector3(w, h - 0.02, 0.03)), mat, Transform3D(Basis.IDENTITY, Vector3(w * 0.5, h * 0.5, 0)), _door
	)
	if style == "locker":
		var slat_mat := MaterialLib.flat(Color(0.05, 0.05, 0.05), 0.9)
		for i in 5:
			add_mesh(
				box_mesh(Vector3(w * 0.6, 0.02, 0.035)),
				slat_mat,
				Transform3D(Basis.IDENTITY, Vector3(w * 0.5, 1.45 + i * 0.06, 0)),
				_door
			)
	add_target(Vector3(w, h, 0.2), Vector3(0, h * 0.5, d * 0.5))


func initial_state() -> Dictionary:
	return {"occupant": 0}


func apply_state(new_state: Dictionary) -> void:
	var before := int(state.get("occupant", 0))
	super.apply_state(new_state)
	var now := int(new_state.get("occupant", 0))
	if before != now:
		_swing()


func _swing() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_door, "rotation:y", deg_to_rad(-75), 0.25)
	_tween.tween_property(_door, "rotation:y", 0.0, 0.3)


func occupant() -> int:
	return int(state.get("occupant", 0))


func view_transform() -> Transform3D:
	return global_transform * Transform3D(Basis.IDENTITY, view_offset)


func exit_position() -> Vector3:
	return global_transform * exit_offset


func interact_origin() -> Vector3:
	return global_transform * Vector3(0, 1.1, 0.3)


func get_prompt(pid: int, _sub: int) -> String:
	var occ := occupant()
	if occ == pid:
		return tr("PROMPT_LEAVE_HIDING")
	if occ != 0:
		return tr("PROMPT_OCCUPIED")
	return tr("PROMPT_HIDE")


func authority_interact(ctx: Dictionary) -> void:
	var pid: int = ctx["player_id"]
	var occ := occupant()
	if occ == pid:
		release(pid)
		return
	if occ != 0:
		return
	match_ctrl.set_entity_state(entity_id, {"occupant": pid})
	match_ctrl.set_player_hiding(pid, entity_id)
	if not hide_flag.is_empty():
		match_ctrl.set_flag(hide_flag)
	world_sound("locker_open" if style == "locker" else "door_creak", -6.0, 12.0)
	match_ctrl.emit_noise(interact_origin(), 3.5, "hide", pid)
	for e in match_ctrl.enemies:
		if is_instance_valid(e):
			e.call("on_player_hid", pid, self)


## Authority: player leaves (voluntarily or pulled out).
func release(pid: int) -> void:
	if occupant() != pid:
		return
	match_ctrl.set_entity_state(entity_id, {"occupant": 0})
	match_ctrl.set_player_hiding(pid, "")
	world_sound("locker_close" if style == "locker" else "door_close", -6.0, 14.0)
	match_ctrl.emit_noise(interact_origin(), 4.0, "hide", pid)
