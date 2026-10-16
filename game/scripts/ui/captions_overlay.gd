class_name CaptionsOverlay
extends Control
## Subtitles (with speaker labels) and directional sound captions.
## Direction is spelled out in words so it never relies on color or icons.

const MAX_LINES := 3

var _box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_END
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_box.add_theme_constant_override("separation", 6)
	add_child(_box)
	AudioService.caption_requested.connect(_on_caption)
	AudioService.subtitle_requested.connect(_on_subtitle)


func _process(_delta: float) -> void:
	var vp := get_viewport_rect().size
	_box.size.x = minf(vp.x * 0.7, 900.0)
	_box.position = Vector2((vp.x - _box.size.x) * 0.5, vp.y - _box.size.y - vp.y * 0.2)


func clear() -> void:
	for c in _box.get_children():
		c.queue_free()


func _on_caption(text_key: String, direction_deg: float, duration: float) -> void:
	var dir_key := "CAP_DIR_AHEAD"
	var a := absf(direction_deg)
	if a > 135.0:
		dir_key = "CAP_DIR_BEHIND"
	elif a > 35.0:
		dir_key = "CAP_DIR_RIGHT" if direction_deg > 0.0 else "CAP_DIR_LEFT"
	_add("[%s — %s]" % [tr(text_key), tr(dir_key)], duration, ThemeFactory.TEXT_DIM)


func _on_subtitle(speaker_key: String, text_key: String, duration: float) -> void:
	_add("%s: %s" % [tr(speaker_key).to_upper(), tr(text_key)], duration, ThemeFactory.TEXT)


func _add(text: String, duration: float, color: Color) -> void:
	var size_px := {"small": 18, "medium": 22, "large": 28}.get(Settings.s("caption_size"), 22) as int
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", ThemeFactory.flat(
		Color(0, 0, 0, Settings.f("caption_background")), Color.TRANSPARENT, 0, 2, 14, 6))
	var l := Label.new()
	l.text = text
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	panel.add_child(l)
	_box.add_child(panel)
	while _box.get_child_count() > MAX_LINES:
		var old := _box.get_child(0)
		_box.remove_child(old)
		old.queue_free()
	var t := create_tween()
	t.tween_interval(duration)
	t.tween_property(panel, "modulate:a", 0.0, 0.4)
	t.tween_callback(panel.queue_free)
