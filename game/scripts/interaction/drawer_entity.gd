class_name DrawerEntity
extends Interactable
## Sliding drawer. Pickups parented to `tray` ride along when it opens.

@export var size := Vector3(0.5, 0.16, 0.45)
@export var material := "dark_wood"

var tray: Node3D
var _tween: Tween


func _ready() -> void:
	tray = Node3D.new()
	tray.name = "Tray"
	add_child(tray)
	var mat := MaterialLib.surface(material)
	add_mesh(box_mesh(Vector3(size.x, size.y, 0.02)), mat, Transform3D(Basis.IDENTITY, Vector3(0, 0, size.z * 0.5)), tray)
	add_mesh(box_mesh(Vector3(size.x - 0.04, 0.01, size.z)), mat, Transform3D(Basis.IDENTITY, Vector3(0, -size.y * 0.5 + 0.01, 0)), tray)
	add_mesh(box_mesh(Vector3(0.1, 0.02, 0.03)), MaterialLib.flat(Color(0.55, 0.45, 0.25), 0.35, 0.8),
		Transform3D(Basis.IDENTITY, Vector3(0, 0, size.z * 0.5 + 0.02)), tray)
	add_target(Vector3(size.x, size.y, 0.1), Vector3(0, 0, size.z * 0.5 + 0.02), 0, tray)


func initial_state() -> Dictionary:
	return {"open": false}


func apply_state(new_state: Dictionary) -> void:
	super.apply_state(new_state)
	var target := size.z * 0.75 if bool(new_state.get("open", false)) else 0.0
	if _tween:
		_tween.kill()
	if not is_inside_tree():
		tray.position.z = target
		return
	_tween = create_tween()
	_tween.tween_property(tray, "position:z", target, 0.35).set_trans(Tween.TRANS_SINE)


func interact_origin() -> Vector3:
	return global_transform * Vector3(0, 0, size.z * 0.5)


func get_prompt(_pid: int, _sub: int) -> String:
	return tr("PROMPT_CLOSE_DRAWER") if bool(state.get("open", false)) else tr("PROMPT_OPEN_DRAWER")


func authority_interact(_ctx: Dictionary) -> void:
	match_ctrl.set_entity_state(entity_id, {"open": not bool(state.get("open", false))})
	world_sound("drawer", -4.0, 10.0)
	match_ctrl.emit_noise(interact_origin(), 3.0, "drawer")
