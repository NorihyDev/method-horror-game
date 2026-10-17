class_name MonitorClue
extends Interactable
## Patient monitor in an observation room. Dark until emergency power returns;
## then it shows its bed number and the last reading's digit (seeded, public
## state, like any clue the world displays). Once powered it beeps, faster
## when The Sister is near: the ward's version of flickering lamps.

const NEAR_ENEMY := 9.0
## Closeness (0..1) from which the beeping counts as fast.
const FAST_BEEP := 0.5

var powered := false
var _screen_mat: StandardMaterial3D
var _label: Label3D
var _beep_timer := 0.0


func _ready() -> void:
	prompt_key = "PROMPT_EXAMINE"
	add_mesh(
		box_mesh(Vector3(0.42, 0.32, 0.14)),
		MaterialLib.flat(Color(0.62, 0.62, 0.58), 0.6),
		Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.07))
	)
	_screen_mat = MaterialLib.glow(Color(0.02, 0.04, 0.03), 0.0)
	var screen := add_mesh(
		box_mesh(Vector3(0.34, 0.24, 0.01)), _screen_mat, Transform3D(Basis.IDENTITY, Vector3(0, 0.01, 0.002))
	)
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_label = Label3D.new()
	_label.font_size = 64
	_label.pixel_size = 0.0018
	_label.modulate = Color(0.35, 1.0, 0.5)
	_label.shaded = false
	_label.position = Vector3(0, 0.01, 0.01)
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.visible = false
	add_child(_label)
	add_target(Vector3(0.46, 0.36, 0.2))


func initial_state() -> Dictionary:
	return {"bed": 0, "digit": -1}


func apply_state(new_state: Dictionary) -> void:
	super.apply_state(new_state)
	_refresh()


func set_powered(on: bool) -> void:
	powered = on
	_refresh()


func _refresh() -> void:
	var digit := int(state.get("digit", -1))
	_label.visible = powered and digit >= 0
	_label.text = "BED %d\n♥ %d" % [int(state.get("bed", 0)), digit]
	_screen_mat.albedo_color = Color(0.02, 0.12, 0.06) if powered else Color(0.02, 0.04, 0.03)
	_screen_mat.emission = _screen_mat.albedo_color
	_screen_mat.emission_energy_multiplier = 1.5 if powered else 0.0


func client_intercept(_pid: int, _sub: int) -> bool:
	if match_ctrl == null:
		return true
	if not powered:
		match_ctrl.notified.emit(tr("MONITOR_DARK"))
	else:
		match_ctrl.notified.emit(tr("MONITOR_EXAMINE") % [int(state.get("bed", 0)), int(state.get("digit", -1))])
	return true


func _process(delta: float) -> void:
	if not powered or match_ctrl == null:
		return
	_beep_timer -= delta
	if _beep_timer > 0.0:
		return
	var near := 0.0
	for e in match_ctrl.enemies:
		if is_instance_valid(e):
			near = maxf(near, 1.0 - (e as Node3D).global_position.distance_to(global_position) / NEAR_ENEMY)
	_beep_timer = lerpf(1.4, 0.3, clampf(near, 0.0, 1.0))
	var map := get_parent()
	while map and not map is MapBase:
		map = map.get_parent()
	if map:
		AudioService.play_3d("monitor_beep", map, global_position, -14.0 + near * 6.0, 9.0)
		# The fast beep is the cue that she is close: caption it for players who cannot hear it.
		if near >= FAST_BEEP:
			AudioService.caption_at("CAP_MONITOR_FAST", global_position, 4.0)
