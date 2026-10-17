class_name ChimeBoard
extends Interactable
## Music-room chime bars. Four bars, lowest (1) to highest (4); striking one
## plays its note for everyone nearby. Four strikes are checked against the
## school bell tune (seeded, never sent to clients): right → `solved_flag`;
## wrong → a sour chord, loud enough to carry, and the board resets.
## Sub-targets 1-4 are the bars. The tune itself is heard over the PA.

const BARS := 4
const COLORS: Array[Color] = [
	Color(0.62, 0.12, 0.1), Color(0.75, 0.5, 0.1), Color(0.2, 0.5, 0.25), Color(0.15, 0.3, 0.6)
]

@export var solved_flag := "chimes_solved"

var _bar_mats: Array[StandardMaterial3D] = []
var _flash := 0.0
var _flash_bar := -1
var _seen_strikes := 0


func _ready() -> void:
	prompt_key = "PROMPT_CHIME"
	var wood := MaterialLib.surface("dark_wood")
	add_mesh(box_mesh(Vector3(1.2, 0.06, 0.5)), wood, Transform3D(Basis.IDENTITY, Vector3(0, 0.78, 0)))
	for sx in [-1, 1]:
		add_mesh(box_mesh(Vector3(0.05, 0.78, 0.4)), wood, Transform3D(Basis.IDENTITY, Vector3(sx * 0.55, 0.39, 0)))
	for i in BARS:
		var x := -0.42 + i * 0.28
		var length := 0.46 - i * 0.07
		# Own copy per bar: each glows on its own when struck.
		var mat := MaterialLib.flat(COLORS[i], 0.35, 0.6).duplicate() as StandardMaterial3D
		_bar_mats.append(mat)
		add_mesh(box_mesh(Vector3(0.16, 0.03, length)), mat, Transform3D(Basis.IDENTITY, Vector3(x, 0.83, 0)))
		var num := Label3D.new()
		num.text = str(i + 1)
		num.font_size = 48
		num.pixel_size = 0.002
		num.shaded = true
		num.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		num.rotation.x = -PI / 2
		num.position = Vector3(x, 0.814, length * 0.5 + 0.05)
		add_child(num)
		add_target(Vector3(0.24, 0.2, 0.5), Vector3(x, 0.85, 0), i + 1)
	_set_glow()


func initial_state() -> Dictionary:
	return {"entered": [], "solved": false, "strikes": 0, "last": 0}


func is_solved() -> bool:
	return bool(state.get("solved", false))


func apply_state(new_state: Dictionary) -> void:
	super.apply_state(new_state)
	var strikes := int(new_state.get("strikes", 0))
	if strikes != _seen_strikes and is_inside_tree():
		_flash_bar = int(new_state.get("last", 0)) - 1
		_flash = 1.0
	_seen_strikes = strikes
	_set_glow()


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 2.0)
		_set_glow()


func _set_glow() -> void:
	for i in _bar_mats.size():
		var m := _bar_mats[i]
		var lit := 0.0
		if is_solved():
			lit = 0.8
		elif i == _flash_bar:
			lit = _flash * 2.5
		m.emission_enabled = lit > 0.0
		m.emission = COLORS[i]
		m.emission_energy_multiplier = lit


func get_prompt(_pid: int, sub: int) -> String:
	if is_solved():
		return ""
	if sub >= 1 and sub <= BARS:
		return tr("PROMPT_CHIME") % sub
	return tr("PROMPT_CHIME_BOARD")


func authority_interact(ctx: Dictionary) -> void:
	var pid: int = ctx["player_id"]
	var sub: int = ctx["sub"]
	if is_solved() or sub < 1 or sub > BARS:
		return
	var s := state.duplicate(true)
	var entered: Array = s["entered"]
	entered.append(sub)
	s["strikes"] = int(s.get("strikes", 0)) + 1
	s["last"] = sub
	world_sound("chime_%d" % sub, 0.0, 22.0)
	match_ctrl.emit_noise(interact_origin(), 7.0, "chime", pid)
	if entered.size() < BARS:
		match_ctrl.set_entity_state(entity_id, s)
		return
	var tune: Array = match_ctrl.puzzle().get("tune", [])
	if tune.size() == BARS and _same(entered, tune):
		s["solved"] = true
		s["entered"] = []
		match_ctrl.set_entity_state(entity_id, s)
		world_sound("keypad_success", 0.0, 16.0)
		match_ctrl.set_flag(solved_flag)
		return
	s["entered"] = []
	match_ctrl.set_entity_state(entity_id, s)
	world_sound("chime_wrong", 4.0, 35.0)
	match_ctrl.emit_noise(interact_origin(), 18.0, "chime", pid)
	match_ctrl.notify_player(pid, "CHIMES_WRONG")


static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if int(a[i]) != int(b[i]):
			return false
	return true
