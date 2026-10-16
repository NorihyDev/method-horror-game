class_name ClueMark
extends Interactable
## A digit painted in red beside a symbol. Values come from the seeded
## puzzle, published as public entity state so every client sees them.

var _digit_label: Label3D
var _glyph_holder: Node3D


func _ready() -> void:
	prompt_key = "PROMPT_EXAMINE"
	_digit_label = Label3D.new()
	_digit_label.font_size = 160
	_digit_label.pixel_size = 0.0028
	_digit_label.modulate = Color(0.55, 0.05, 0.04)
	_digit_label.outline_size = 0
	_digit_label.shaded = true
	_digit_label.double_sided = false
	_digit_label.position = Vector3(0.12, 0, 0.005)
	add_child(_digit_label)
	_glyph_holder = Node3D.new()
	_glyph_holder.position = Vector3(-0.18, 0, 0.005)
	add_child(_glyph_holder)
	add_target(Vector3(0.7, 0.5, 0.15))


func initial_state() -> Dictionary:
	return {"digit": -1, "symbol": -1}


func apply_state(new_state: Dictionary) -> void:
	super.apply_state(new_state)
	var digit := int(new_state.get("digit", -1))
	_digit_label.text = str(digit) if digit >= 0 else ""
	for c in _glyph_holder.get_children():
		c.queue_free()
	var symbol := int(new_state.get("symbol", -1))
	if symbol >= 0:
		var mat := MaterialLib.flat(Color(0.55, 0.05, 0.04), 0.9)
		_glyph_holder.add_child(Glyphs.build(symbol, 0.26, mat))


func client_intercept(_pid: int, _sub: int) -> bool:
	var digit := int(state.get("digit", -1))
	var symbol := int(state.get("symbol", -1))
	if digit >= 0 and symbol >= 0 and match_ctrl:
		match_ctrl.notified.emit(tr("CLUE_EXAMINE") % [digit, tr(Glyphs.NAMES[symbol])])
	return true
