class_name UI
extends RefCounted
## Small widget factory so every screen shares spacing, typography and sound.

const T = preload("res://scripts/ui/theme_factory.gd")


static func label(text: String, size: int = T.FONT_BODY, color: Color = T.TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## For untrusted text (player names): never translated, never markup.
static func plain(text: String, size: int = T.FONT_BODY, color: Color = T.TEXT) -> Label:
	var l := label(text, size, color)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	return l


static func para(text: String, size: int = T.FONT_BODY, color: Color = T.TEXT_DIM) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120
	return l


static func title(text: String, size: int = T.FONT_H1) -> Label:
	var l := label(text, size, T.TEXT)
	l.add_theme_font_override("font", T.title_font())
	return l


static func heading(text: String) -> Label:
	var l := label(text, T.FONT_H2, T.TEXT)
	l.add_theme_font_override("font", T.title_font())
	return l


static func caption(text: String) -> Label:
	var l := label(text, T.FONT_SMALL, T.TEXT_DIM)
	l.uppercase = true
	l.add_theme_constant_override("outline_size", 0)
	return l


static func button(text: String, on_pressed: Callable, primary: bool = false, min_width: int = 0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_width, T.MIN_TOUCH)
	b.focus_mode = Control.FOCUS_ALL
	if primary:
		b.add_theme_stylebox_override("normal", T.flat(Color(T.CRIMSON, 0.85), T.CRIMSON_HI, 1, 2, 26, 12))
		b.add_theme_stylebox_override("hover", T.flat(T.CRIMSON_HI, T.TEXT, 1, 2, 26, 12))
		b.add_theme_stylebox_override("pressed", T.flat(Color(T.CRIMSON, 1.0).darkened(0.25), T.TEXT, 1, 2, 26, 12))
	if on_pressed.is_valid():
		b.pressed.connect(func() -> void:
			AudioService.play_ui("ui_confirm" if primary else "ui_click")
			on_pressed.call())
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			AudioService.play_ui("ui_hover", -8.0))
	b.focus_entered.connect(func() -> void: AudioService.play_ui("ui_hover", -10.0))
	return b


## Disabled button that explains why on press attempt (tooltip + caption).
static func disabled_button(text: String, reason_key: String, min_width: int = 0) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var b := button(text, Callable(), false, min_width)
	b.disabled = true
	b.tooltip_text = reason_key
	box.add_child(b)
	var why := label(reason_key, T.FONT_SMALL, T.TEXT_FAINT)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.custom_minimum_size.x = maxf(min_width, 200)
	box.add_child(why)
	return box


static func vbox(separation: int = 12) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


static func hbox(separation: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separation)
	return h


static func panel(padding: int = 24) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", T.flat(Color(T.SURFACE, 0.93), T.LINE, 1, 3, padding, padding))
	return p


static func spacer(height: float = 12.0, expand: bool = false) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	if expand:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


static func hspacer(expand: bool = true, width: float = 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size.x = width
	if expand:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return c


static func rule() -> ColorRect:
	var r := ColorRect.new()
	r.color = T.LINE
	r.custom_minimum_size.y = 1
	return r


static func accent_bar(width: float = 64.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = T.CRIMSON
	r.custom_minimum_size = Vector2(width, 3)
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return r


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


static func center(child: Control) -> CenterContainer:
	var cc := CenterContainer.new()
	full_rect(cc)
	cc.add_child(child)
	return cc


static func margin(child: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(child)
	return m


static func slider(min_v: float, max_v: float, step: float, value: float, on_change: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.custom_minimum_size = Vector2(220, 40)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(on_change)
	return s


static func toggle(value: bool, on_change: Callable) -> CheckButton:
	var c := CheckButton.new()
	c.button_pressed = value
	c.custom_minimum_size = Vector2(0, T.MIN_TOUCH - 8)
	c.focus_mode = Control.FOCUS_ALL
	c.toggled.connect(func(on: bool) -> void:
		AudioService.play_ui("ui_click")
		on_change.call(on))
	return c


## Option picker. `values` are stored values, `labels` translation keys.
static func options(values: Array, labels: Array, current: Variant, on_change: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.custom_minimum_size = Vector2(220, T.MIN_TOUCH - 8)
	o.focus_mode = Control.FOCUS_ALL
	for i in values.size():
		o.add_item(str(labels[i]), i)
		if str(values[i]) == str(current):
			o.select(i)
	o.item_selected.connect(func(idx: int) -> void:
		AudioService.play_ui("ui_click")
		on_change.call(values[idx]))
	return o


## Label + control row used by settings and setup screens.
static func row(label_key: String, control: Control, tooltip_key: String = "") -> HBoxContainer:
	var h := hbox(16)
	h.custom_minimum_size.y = T.MIN_TOUCH - 4
	var l := label(label_key, T.FONT_BODY, T.TEXT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size.x = 260
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if not tooltip_key.is_empty():
		l.tooltip_text = tooltip_key
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		h.tooltip_text = tooltip_key
	h.add_child(l)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	control.size_flags_stretch_ratio = 0.9
	h.add_child(control)
	return h


static func scroll(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func scroll_h(child: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	s.custom_minimum_size.y = ThemeFactory.MIN_TOUCH + 8
	s.add_child(child)
	return s


static func format_time(seconds: float) -> String:
	var s := int(seconds)
	return "%d:%02d" % [s / 60, s % 60]


## Coin glyph drawn as a small crimson-rimmed disc (no font dependency).
static func coin_label(amount: int, size: int = T.FONT_BODY) -> HBoxContainer:
	var h := hbox(8)
	var icon := CoinIcon.new()
	icon.custom_minimum_size = Vector2(size, size)
	h.add_child(icon)
	var l := plain(str(amount), size, T.TEXT)
	h.add_child(l)
	return h


class CoinIcon:
	extends Control

	func _draw() -> void:
		var r := minf(size.x, size.y) * 0.5
		var c := size * 0.5
		draw_circle(c, r, ThemeFactory.CRIMSON)
		draw_circle(c, r * 0.72, ThemeFactory.SURFACE)
		draw_circle(c, r * 0.36, ThemeFactory.TEXT)
