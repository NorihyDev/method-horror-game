extends Screen
## Brief METHOD studio splash. Tap / any key skips.

var _done := false


func build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := UI.vbox(14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	var word := HorrorTitle.new("METHOD", 104, false)
	word.set_alignment(HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(word)
	var bar := UI.accent_bar(240)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(bar)
	var sub := UI.caption("SPLASH_PRESENTS")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	var cc := UI.center(box)
	add_child(cc)
	box.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(box, "modulate:a", 1.0, 0.9)
	t.tween_interval(1.1)
	t.tween_property(box, "modulate:a", 0.0, 0.6)
	t.tween_callback(_next)


func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch) and event.is_pressed():
		_next()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		_next()


func _next() -> void:
	if _done:
		return
	_done = true
	app.goto("notice", {}, true)


func handle_back() -> bool:
	_next()
	return true
