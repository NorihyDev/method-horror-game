extends Screen
## Drag touch buttons to new positions. Saved as normalized coordinates in
## the right-handed layout (left-handed mode mirrors them).

var _controls: TouchControls
var _dragging := ""
var _layout: Dictionary = {}


func build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.07, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_layout = (Settings.get_value("touch_layout") as Dictionary).duplicate()
	_controls = TouchControls.new()
	_controls.editing = true
	_controls.enabled_buttons = PackedStringArray(TouchControls.BUTTONS.keys())
	add_child(_controls)
	var bar := UI.hbox(10)
	bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	bar.position = Vector2(-330, 24 + app.safe_margins().y)
	bar.add_child(UI.button("BACK", func() -> void: app.back(), false, 120))
	bar.add_child(UI.button("TOUCH_LAYOUT_SAVE", _save, true, 160))
	bar.add_child(UI.button("TOUCH_LAYOUT_RESET", func() -> void:
		_layout.clear()
		Settings.set_value("touch_layout", {})
		_controls.queue_redraw(), false, 200))
	add_child(bar)
	var hint := UI.label("TOUCH_LAYOUT_HINT", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_DIM)
	hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	hint.position = Vector2(-300, -20)
	hint.size = Vector2(600, 40)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)


func _gui_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var down := false
	var moving := false
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		pos = event.position
		down = event.is_pressed()
		if down:
			_dragging = ""
			for b in _controls.enabled_buttons:
				if pos.distance_to(_controls.button_center(b)) <= _controls.button_radius(b) * 1.2:
					_dragging = b
		else:
			_dragging = ""
	elif event is InputEventScreenDrag or event is InputEventMouseMotion:
		pos = event.position
		moving = true
	if moving and not _dragging.is_empty():
		var vp := get_viewport_rect().size
		var n := Vector2(clampf(pos.x / vp.x, 0.04, 0.96), clampf(pos.y / vp.y, 0.06, 0.94))
		if Settings.b("left_handed"):
			n.x = 1.0 - n.x
		_layout[_dragging] = [n.x, n.y]
		Settings.set_value("touch_layout", _layout, false)
		_controls.queue_redraw()


func _save() -> void:
	Settings.set_value("touch_layout", _layout)
	app.toast(tr("TOUCH_LAYOUT_SAVED"))
	app.back()
