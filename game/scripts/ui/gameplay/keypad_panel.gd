class_name KeypadPanel
extends OverlayPanel
## Keypad entry UI. Shows the symbol order printed on the keypad plate and
## sends the typed code to the authority. Works with touch, mouse, keyboard
## digits and controller focus.

var keypad: KeypadEntity
var match_ctrl: MatchController
var _code := ""
var _display: Label
var _order: SymbolStrip


func build() -> void:
	panel.custom_minimum_size = Vector2(420, 0)
	header("KEYPAD_TITLE")
	body.add_child(UI.caption("KEYPAD_ORDER"))
	_order = SymbolStrip.new()
	_order.order = keypad.symbol_order()
	_order.custom_minimum_size = Vector2(360, 56)
	body.add_child(_order)
	_display = UI.label("", 40)
	_display.add_theme_font_override("font", ThemeFactory.mono_font())
	_display.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_display.custom_minimum_size = Vector2(360, 56)
	_display.add_theme_stylebox_override(
		"normal", ThemeFactory.flat(Color(0.05, 0.02, 0.02), ThemeFactory.CRIMSON, 1, 2, 10, 4)
	)
	_display.add_theme_color_override("font_color", Color(0.95, 0.35, 0.25))
	body.add_child(_display)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	body.add_child(grid)
	for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "CLR", "0", "OK"]:
		var k: String = key
		var label := k
		if k == "CLR":
			label = "KEYPAD_CLEAR"
		elif k == "OK":
			label = "KEYPAD_ENTER"
		var b := UI.button(label, func() -> void: _press(k), k == "OK", 112)
		b.custom_minimum_size.y = 64
		grid.add_child(b)
	body.add_child(UI.button("CLOSE", func() -> void: close()))
	_update()
	match_ctrl.entity_changed.connect(
		func(id: String, s: Dictionary) -> void:
			if id == keypad.entity_id and bool(s.get("solved", false)) and is_inside_tree():
				close()
	)


func _press(k: String) -> void:
	match k:
		"CLR":
			_code = ""
		"OK":
			if _code.length() == KeypadEntity.CODE_LENGTH:
				match_ctrl.request_interact(keypad.entity_id, 0, "submit", {"code": _code})
				_code = ""
		_:
			if _code.length() < KeypadEntity.CODE_LENGTH:
				_code += k
				AudioService.play_2d("keypad_beep", AudioService.BUS_SFX, -6.0)
	_update()


func _update() -> void:
	var shown := _code
	while shown.length() < KeypadEntity.CODE_LENGTH:
		shown += "·"
	_display.text = " ".join(shown.split(""))


func _unhandled_input(event: InputEvent) -> void:
	super._unhandled_input(event)
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		var uni := key.unicode
		if uni >= 48 and uni <= 57:
			_press(char(uni))
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_BACKSPACE:
			_code = _code.substr(0, maxi(0, _code.length() - 1))
			_update()
			get_viewport().set_input_as_handled()
		elif key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
			_press("OK")
			get_viewport().set_input_as_handled()


class SymbolStrip:
	extends Control
	var order: Array = []

	func _draw() -> void:
		var n := maxi(order.size(), 1)
		var cell := size.x / n
		for i in order.size():
			var c := Vector2(cell * (i + 0.5), size.y * 0.5)
			Glyphs.draw_2d(self, int(order[i]), c, size.y * 0.8, ThemeFactory.TEXT, 3.0)
			if i < order.size() - 1:
				draw_line(
					Vector2(cell * (i + 1) - 6, size.y * 0.5),
					Vector2(cell * (i + 1) + 6, size.y * 0.5),
					ThemeFactory.TEXT_FAINT,
					2.0
				)
