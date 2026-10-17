class_name DoorEntity
extends Interactable
## Hinged door. The node origin is the hinge; the panel extends along +X.
##
## Lock rules (`lock`): "" (unlocked), "item:<id>", "flag:<flag>", "chained"
## (never opens; used for the front door), "external" (opened by another
## entity such as a keypad). Locked doors also block the navigation mesh, so
## the enemy cannot path through them; unlocking triggers a re-bake.

const LAYER_DOOR := 1 << 4

@export var width := 1.0
@export var height := 2.15
@export var thickness := 0.06
@export var lock := ""
## Message shown when locked and the requirement is missing.
@export var locked_message := "DOOR_LOCKED"
## Swing direction: +1 or -1.
@export var swing := 1.0
@export var open_angle := 100.0
@export var material := "painted_wood"
## Flag set the first time someone tries this door (e.g. "exit_found").
@export var try_flag := ""
## Flag set when the door is unlocked (keeps objective logic data-driven).
@export var unlock_flag := ""
@export var style := "panel"
## Access-card door: a wall reader beside the frame shows red/green and
## beeps instead of rattling.
@export var card_reader := false

var panel: AnimatableBody3D
var _reader_mat: StandardMaterial3D
var _tween: Tween
var _angle := 0.0


func _ready() -> void:
	prompt_key = "PROMPT_OPEN"
	panel = AnimatableBody3D.new()
	panel.name = "Panel"
	panel.sync_to_physics = false
	panel.collision_mask = 0
	add_child(panel)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, thickness + 0.04)
	shape.shape = box
	shape.position = Vector3(width * 0.5, height * 0.5, 0)
	panel.add_child(shape)
	_build_visual()
	if card_reader:
		_build_reader()
	add_target(Vector3(width, height, thickness + 0.1), Vector3(width * 0.5, height * 0.5, 0), 0, panel)
	_update_layers(not lock.is_empty())


func _build_reader() -> void:
	# Mounted on the wall beside the latch side, on both faces.
	for face in [-1, 1]:
		add_mesh(
			box_mesh(Vector3(0.09, 0.14, 0.03)),
			MaterialLib.flat(Color(0.15, 0.15, 0.16), 0.5),
			Transform3D(Basis.IDENTITY, Vector3(width + 0.2, 1.2, face * 0.1))
		)
	_reader_mat = MaterialLib.glow(Color(0.8, 0.1, 0.08), 1.6)
	for face in [-1, 1]:
		var lamp := add_mesh(
			box_mesh(Vector3(0.05, 0.02, 0.01)),
			_reader_mat,
			Transform3D(Basis.IDENTITY, Vector3(width + 0.2, 1.25, face * 0.118))
		)
		lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_visual() -> void:
	var mat := MaterialLib.surface(material)
	if style == "ward":
		_build_ward_visual(mat)
		return
	if style == "cage":
		var steel := MaterialLib.surface("metal_dark")
		for i in 7:
			add_mesh(
				box_mesh(Vector3(0.025, height, 0.025)),
				steel,
				Transform3D(Basis.IDENTITY, Vector3(0.05 + i * (width - 0.1) / 6.0, height * 0.5, 0)),
				panel
			)
		for y in [0.1, height * 0.5, height - 0.08]:
			add_mesh(
				box_mesh(Vector3(width, 0.04, 0.03)),
				steel,
				Transform3D(Basis.IDENTITY, Vector3(width * 0.5, y, 0)),
				panel
			)
		return
	add_mesh(
		box_mesh(Vector3(width, height, thickness)),
		mat,
		Transform3D(Basis.IDENTITY, Vector3(width * 0.5, height * 0.5, 0)),
		panel
	)
	# Raised panels for silhouette and handle.
	for y in [height * 0.3, height * 0.72]:
		add_mesh(
			box_mesh(Vector3(width * 0.7, height * 0.32, thickness + 0.02)),
			mat,
			Transform3D(Basis.IDENTITY, Vector3(width * 0.5, y, 0)),
			panel
		)
	var brass := MaterialLib.flat(Color(0.55, 0.45, 0.25), 0.35, 0.8)
	for side in [-1, 1]:
		add_mesh(
			box_mesh(Vector3(0.12, 0.03, 0.05)),
			brass,
			Transform3D(Basis.IDENTITY, Vector3(width - 0.12, 1.0, side * (thickness * 0.5 + 0.03))),
			panel
		)
	if lock == "chained":
		var chain := MaterialLib.flat(Color(0.3, 0.3, 0.32), 0.4, 0.9)
		for i in 5:
			add_mesh(
				box_mesh(Vector3(0.05, 0.05, 0.02)),
				chain,
				Transform3D(
					Basis(Vector3.BACK, 0.4 * (1 if i % 2 == 0 else -1)),
					Vector3(width - 0.3 + i * 0.12, 1.05, -thickness)
				),
				panel
			)
		add_mesh(
			box_mesh(Vector3(0.1, 0.14, 0.05)),
			chain,
			Transform3D(Basis.IDENTITY, Vector3(width - 0.05, 0.95, -thickness - 0.03)),
			panel
		)


## Hospital door: painted panel, wired-glass window, push plate.
func _build_ward_visual(mat: Material) -> void:
	add_mesh(
		box_mesh(Vector3(width, height, thickness)),
		mat,
		Transform3D(Basis.IDENTITY, Vector3(width * 0.5, height * 0.5, 0)),
		panel
	)
	var glass := MaterialLib.flat(Color(0.08, 0.1, 0.1), 0.15, 0.2)
	add_mesh(
		box_mesh(Vector3(width * 0.32, height * 0.28, thickness + 0.012)),
		glass,
		Transform3D(Basis.IDENTITY, Vector3(width * 0.5, height * 0.68, 0)),
		panel
	)
	var steel := MaterialLib.surface("metal")
	add_mesh(
		box_mesh(Vector3(width * 0.8, 0.22, thickness + 0.01)),
		steel,
		Transform3D(Basis.IDENTITY, Vector3(width * 0.5, 0.14, 0)),
		panel
	)
	for side in [-1, 1]:
		add_mesh(
			box_mesh(Vector3(0.1, 0.3, 0.01)),
			steel,
			Transform3D(Basis.IDENTITY, Vector3(width - 0.14, 1.1, side * (thickness * 0.5 + 0.006))),
			panel
		)


func initial_state() -> Dictionary:
	return {"open": false, "locked": not lock.is_empty()}


func apply_state(new_state: Dictionary) -> void:
	var was_locked := bool(state.get("locked", not lock.is_empty()))
	super.apply_state(new_state)
	var target := (open_angle * swing) if bool(new_state.get("open", false)) else 0.0
	_update_layers(bool(new_state.get("locked", false)))
	if _reader_mat:
		var granted := not bool(new_state.get("locked", false))
		_reader_mat.albedo_color = Color(0.3, 0.9, 0.35) if granted else Color(0.8, 0.1, 0.08)
		_reader_mat.emission = _reader_mat.albedo_color
	if (
		was_locked
		and not bool(new_state.get("locked", false))
		and is_inside_tree()
		and match_ctrl
		and match_ctrl.is_authority
	):
		var map := _map()
		if map:
			map.rebake_navigation()
	if is_equal_approx(target, _angle):
		return
	if _tween:
		_tween.kill()
	if not is_inside_tree():
		_set_angle(target)
		return
	_tween = create_tween()
	_tween.tween_method(_set_angle, _angle, target, 0.55).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _set_angle(a: float) -> void:
	_angle = a
	panel.rotation.y = deg_to_rad(a)


func _update_layers(locked: bool) -> void:
	if panel == null:
		return
	# Locked doors count as world geometry for navigation baking.
	panel.collision_layer = LAYER_DOOR | (GeoBuilder.LAYER_WORLD if locked else 0)


func _map() -> MapBase:
	var n: Node = self
	while n and not n is MapBase:
		n = n.get_parent()
	return n as MapBase


func is_open() -> bool:
	return bool(state.get("open", false))


func is_locked() -> bool:
	return bool(state.get("locked", false))


func get_prompt(pid: int, _sub: int) -> String:
	if is_locked():
		if lock.begins_with("item:") and match_ctrl and match_ctrl.has_item(pid, lock.substr(5)):
			return tr("PROMPT_SWIPE_CARD" if card_reader else "PROMPT_UNLOCK")
		return tr("PROMPT_TRY_DOOR")
	return tr("PROMPT_CLOSE") if is_open() else tr("PROMPT_OPEN")


func interact_origin() -> Vector3:
	return global_transform * Vector3(width * 0.5, 1.1, 0)


func authority_interact(ctx: Dictionary) -> void:
	var pid: int = ctx["player_id"]
	if not try_flag.is_empty():
		match_ctrl.set_flag(try_flag)
	if is_locked():
		if _requirement_met(pid):
			_unlock_and_open(pid)
			return
		world_sound("card_deny" if card_reader else "door_locked", -4.0, 14.0)
		match_ctrl.emit_noise(interact_origin(), 4.0, "door", pid)
		match_ctrl.notify_player(pid, locked_message)
		return
	var opening := not is_open()
	match_ctrl.set_entity_state(entity_id, {"open": opening, "locked": false})
	world_sound("door_creak" if opening else "door_close", -2.0, 22.0)
	match_ctrl.emit_noise(interact_origin(), 5.5 if opening else 6.5, "door", pid)


func _requirement_met(pid: int) -> bool:
	if lock.begins_with("item:"):
		return match_ctrl.has_item(pid, lock.substr(5))
	if lock.begins_with("flag:"):
		return match_ctrl.state.has_flag(lock.substr(5))
	return false


func _unlock_and_open(pid: int) -> void:
	match_ctrl.set_entity_state(entity_id, {"open": true, "locked": false})
	world_sound("card_accept" if card_reader else "unlock", 0.0, 16.0)
	match_ctrl.emit_noise(interact_origin(), 5.0, "door", pid)
	if not unlock_flag.is_empty():
		match_ctrl.set_flag(unlock_flag)


## Authority: opened by another entity (keypad) or by power restoration.
func force_unlock(open: bool = true) -> void:
	match_ctrl.set_entity_state(entity_id, {"open": open, "locked": false})
	world_sound("unlock", 0.0, 16.0)
	if not unlock_flag.is_empty():
		match_ctrl.set_flag(unlock_flag)


## Authority: the enemy shoves an unlocked door open (loud on purpose).
func enemy_open() -> void:
	if is_locked() or is_open():
		return
	match_ctrl.set_entity_state(entity_id, {"open": true, "locked": false})
	world_sound("door_creak", 2.0, 28.0)
