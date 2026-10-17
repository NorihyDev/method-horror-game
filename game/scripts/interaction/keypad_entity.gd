class_name KeypadEntity
extends Interactable
## Four-digit keypad. Its plate shows the symbol order; the digits are painted
## around the map beside matching symbols. The client opens a keypad UI and
## submits a code; the authority validates it with a per-attempt cooldown.

signal open_ui_requested(keypad: KeypadEntity)

const CODE_LENGTH := 4
const ATTEMPT_COOLDOWN := 1.0

## Door entity opened on success.
@export var target_door := ""
@export var success_flag := "cage_open"
## False when the order comes from elsewhere (a duty roster, not glyphs).
@export var show_order := true

var _screen_mat: StandardMaterial3D
var _glyph_root: Node3D
var _last_attempt := -10.0


func _ready() -> void:
	prompt_key = "PROMPT_KEYPAD"
	add_mesh(
		box_mesh(Vector3(0.26, 0.36, 0.06)),
		MaterialLib.surface("metal_dark"),
		Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.03))
	)
	_screen_mat = MaterialLib.glow(Color(0.5, 0.08, 0.06), 1.4)
	add_mesh(box_mesh(Vector3(0.2, 0.05, 0.01)), _screen_mat, Transform3D(Basis.IDENTITY, Vector3(0, 0.12, 0.002)))
	var key_mat := MaterialLib.flat(Color(0.7, 0.68, 0.62), 0.6)
	for row in 4:
		for col in 3:
			add_mesh(
				box_mesh(Vector3(0.05, 0.04, 0.015)),
				key_mat,
				Transform3D(Basis.IDENTITY, Vector3(-0.065 + col * 0.065, 0.05 - row * 0.055, 0.005))
			)
	_glyph_root = Node3D.new()
	_glyph_root.position = Vector3(0, 0.3, 0.005)
	add_child(_glyph_root)
	var plate := Label3D.new()
	plate.text = "ORDER"
	plate.font_size = 24
	plate.pixel_size = 0.0014
	plate.modulate = Color(0.8, 0.77, 0.7)
	plate.shaded = true
	plate.position = Vector3(0, 0.38, 0.005)
	plate.visible = show_order
	add_child(plate)
	add_target(Vector3(0.3, 0.5, 0.12), Vector3(0, 0.1, 0.04))


func initial_state() -> Dictionary:
	return {"solved": false, "order": []}


func apply_state(new_state: Dictionary) -> void:
	super.apply_state(new_state)
	var solved := bool(new_state.get("solved", false))
	_screen_mat.albedo_color = Color(0.2, 0.75, 0.3) if solved else Color(0.5, 0.08, 0.06)
	_screen_mat.emission = _screen_mat.albedo_color
	for c in _glyph_root.get_children():
		c.queue_free()
	var order: Array = new_state.get("order", [])
	var mat := MaterialLib.flat(Color(0.82, 0.78, 0.7), 0.6)
	for i in order.size():
		var g := Glyphs.build(int(order[i]), 0.05, mat)
		g.position = Vector3(-0.09 + i * 0.06, 0, 0)
		_glyph_root.add_child(g)


func symbol_order() -> Array:
	return state.get("order", [])


func is_solved() -> bool:
	return bool(state.get("solved", false))


func get_prompt(_pid: int, _sub: int) -> String:
	return tr("PROMPT_KEYPAD_DONE") if is_solved() else tr("PROMPT_KEYPAD")


func client_intercept(_pid: int, _sub: int) -> bool:
	if not is_solved():
		open_ui_requested.emit(self)
	return true


func authority_interact(ctx: Dictionary) -> void:
	if ctx["action"] != "submit" or is_solved():
		return
	var pid: int = ctx["player_id"]
	var now := match_ctrl.state.elapsed
	if now - _last_attempt < ATTEMPT_COOLDOWN:
		return
	_last_attempt = now
	var code := str(ctx["args"].get("code", ""))
	if code.length() != CODE_LENGTH or not code.is_valid_int():
		return
	var answer := str(match_ctrl.puzzle().get("code", ""))
	if code != answer or answer.is_empty():
		world_sound("keypad_error", -2.0, 14.0)
		match_ctrl.emit_noise(interact_origin(), 6.0, "keypad", pid)
		match_ctrl.notify_player(pid, "KEYPAD_WRONG")
		var s := state.duplicate()
		s["attempts"] = int(s.get("attempts", 0)) + 1
		match_ctrl.set_entity_state(entity_id, s)
		return
	var solved := state.duplicate()
	solved["solved"] = true
	match_ctrl.set_entity_state(entity_id, solved)
	world_sound("keypad_success", 0.0, 16.0)
	var door: DoorEntity = match_ctrl.entities.get(target_door) as DoorEntity
	if door:
		door.force_unlock(true)
	match_ctrl.set_flag(success_flag)
