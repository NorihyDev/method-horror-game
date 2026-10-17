class_name ControlConsole
extends Interactable
## A one-shot control (security console, station help point): when every
## required flag is set, holding Interact sets `set_flag`; otherwise it says
## what is missing. Styles: "console" (desk with a big button) and
## "help_point" (wall intercom).

@export var required_flags: PackedStringArray = []
@export var set_flag := ""
@export var missing_message := "CONSOLE_NO_POWER"
@export var done_prompt_key := "PROMPT_CONSOLE_DONE"
@export var activate_sound := "switch"
@export var noise_radius := 6.0
@export var style := "console"

var _lamp_mat: StandardMaterial3D


func _ready() -> void:
	if hold_time <= 0.0:
		hold_time = 0.8
	_lamp_mat = MaterialLib.glow(Color(0.8, 0.12, 0.08), 1.2)
	if style == "help_point":
		add_mesh(
			box_mesh(Vector3(0.36, 0.52, 0.12)),
			MaterialLib.flat(Color(0.12, 0.3, 0.55), 0.6),
			Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.06))
		)
		for i in 6:
			add_mesh(
				box_mesh(Vector3(0.22, 0.012, 0.01)),
				MaterialLib.flat(Color(0.05, 0.05, 0.05), 0.8),
				Transform3D(Basis.IDENTITY, Vector3(0, 0.16 - i * 0.025, 0.002))
			)
		add_mesh(box_mesh(Vector3(0.1, 0.1, 0.04)), _lamp_mat, Transform3D(Basis.IDENTITY, Vector3(0, -0.12, 0.01)))
		var label := Label3D.new()
		label.text = "HELP  ·  EMERGENCY"
		label.font_size = 26
		label.pixel_size = 0.0016
		label.shaded = true
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.position = Vector3(0, 0.22, 0.003)
		add_child(label)
		add_target(Vector3(0.4, 0.56, 0.16))
		return
	add_mesh(
		box_mesh(Vector3(1.2, 0.08, 0.6)),
		MaterialLib.surface("metal_dark"),
		Transform3D(Basis.IDENTITY, Vector3(0, 0.9, 0))
	)
	add_mesh(
		box_mesh(Vector3(1.1, 0.86, 0.5)),
		MaterialLib.surface("metal"),
		Transform3D(Basis.IDENTITY, Vector3(0, 0.43, 0))
	)
	var screen := add_mesh(
		box_mesh(Vector3(0.5, 0.32, 0.03)),
		MaterialLib.glow(Color(0.05, 0.12, 0.1), 0.8),
		Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-15)), Vector3(-0.2, 1.1, -0.15))
	)
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_mesh(box_mesh(Vector3(0.14, 0.05, 0.14)), _lamp_mat, Transform3D(Basis.IDENTITY, Vector3(0.3, 0.96, 0.05)))
	add_target(Vector3(1.2, 0.4, 0.7), Vector3(0, 0.95, 0))


func initial_state() -> Dictionary:
	return {"done": false}


func apply_state(new_state: Dictionary) -> void:
	super.apply_state(new_state)
	var done := bool(new_state.get("done", false))
	_lamp_mat.albedo_color = Color(0.3, 0.9, 0.35) if done else Color(0.8, 0.12, 0.08)
	_lamp_mat.emission = _lamp_mat.albedo_color


func interact_origin() -> Vector3:
	return global_position + (Vector3.ZERO if style == "help_point" else Vector3(0, 0.95, 0))


func get_prompt(_pid: int, _sub: int) -> String:
	return tr(done_prompt_key) if bool(state.get("done", false)) else tr(prompt_key)


func get_hold_time(_pid: int, _sub: int) -> float:
	return 0.0 if bool(state.get("done", false)) else hold_time


func authority_interact(ctx: Dictionary) -> void:
	if bool(state.get("done", false)):
		return
	var pid: int = ctx["player_id"]
	for f in required_flags:
		if not match_ctrl.state.has_flag(f):
			world_sound("card_deny", -4.0, 12.0)
			match_ctrl.notify_player(pid, missing_message)
			return
	match_ctrl.set_entity_state(entity_id, {"done": true})
	world_sound(activate_sound, 0.0, 24.0)
	match_ctrl.emit_noise(interact_origin(), noise_radius, "console", pid)
	if not set_flag.is_empty():
		match_ctrl.set_flag(set_flag)
