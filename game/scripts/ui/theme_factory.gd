class_name ThemeFactory
extends RefCounted
## Builds the METHOD visual language as a Godot Theme: charcoal surfaces,
## aged off-white type, restrained crimson accents.

const BG := Color("0b0b0d")
const SURFACE := Color("141416")
const SURFACE_2 := Color("1c1c1f")
const LINE := Color("2c2b2e")
const TEXT := Color("e8e2d4")
const TEXT_DIM := Color("9d978b")
## Quietest readable text: still 4.5:1 on every surface (WCAG AA).
const TEXT_FAINT := Color("8d877d")
## Disabled controls only (exempt from contrast rules); never for information.
const DISABLED := Color("625e57")
const CRIMSON := Color("8e1b1b")
const CRIMSON_HI := Color("b42727")
## Crimson for text (status, warnings): readable on dark surfaces.
const DANGER := Color("e35d5d")
const WARN := Color("c9a227")
const OK := Color("7f9c6b")

const FONT_BODY := 20
const FONT_SMALL := 16
const FONT_H2 := 28
const FONT_H1 := 44
const MIN_TOUCH := 56

static var _theme: Theme
static var _title_font: Font
static var _mono_font: Font


static func theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## Serif display face for titles (system font, engine default fallback).
static func title_font() -> Font:
	if _title_font == null:
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(
			[
				"Georgia",
				"Times New Roman",
				"Noto Serif",
				"DejaVu Serif",
				"Liberation Serif",
				"serif",
			]
		)
		sys.font_weight = 400
		var variation := FontVariation.new()
		variation.base_font = sys
		variation.spacing_glyph = 3
		_title_font = variation
	return _title_font


static func mono_font() -> Font:
	if _mono_font == null:
		var sys := SystemFont.new()
		sys.font_names = PackedStringArray(
			["Consolas", "Courier New", "Noto Sans Mono", "DejaVu Sans Mono", "monospace"]
		)
		_mono_font = sys
	return _mono_font


static func flat(
	bg: Color,
	border: Color = Color.TRANSPARENT,
	border_width: int = 0,
	radius: int = 2,
	pad_h: int = 18,
	pad_v: int = 10
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad_h
	sb.content_margin_right = pad_h
	sb.content_margin_top = pad_v
	sb.content_margin_bottom = pad_v
	sb.anti_aliasing = true
	return sb


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_BODY

	# Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_constant("line_spacing", "Label", 4)

	# Buttons: dark slab with a crimson edge on focus/hover.
	var normal := flat(Color(SURFACE, 0.88), LINE, 1, 2, 22, 12)
	var hover := flat(Color(SURFACE_2, 0.95), Color(CRIMSON_HI, 0.8), 1, 2, 22, 12)
	var pressed := flat(Color(CRIMSON, 0.55), CRIMSON_HI, 1, 2, 22, 12)
	var disabled := flat(Color(SURFACE, 0.5), Color(LINE, 0.5), 1, 2, 22, 12)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = TEXT
	focus.set_border_width_all(2)
	focus.set_corner_radius_all(3)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	for type in ["Button", "OptionButton", "CheckButton", "MenuButton"]:
		t.set_stylebox("normal", type, normal)
		t.set_stylebox("hover", type, hover)
		t.set_stylebox("pressed", type, pressed)
		t.set_stylebox("hover_pressed", type, pressed)
		t.set_stylebox("disabled", type, disabled)
		t.set_stylebox("focus", type, focus)
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, Color.WHITE)
		t.set_color("font_pressed_color", type, Color.WHITE)
		t.set_color("font_focus_color", type, Color.WHITE)
		t.set_color("font_disabled_color", type, DISABLED)
	t.set_constant("h_separation", "Button", 10)

	# Inputs
	var field := flat(Color(0.03, 0.03, 0.035, 0.95), LINE, 1, 2, 14, 10)
	var field_focus := flat(Color(0.03, 0.03, 0.035, 0.95), CRIMSON_HI, 1, 2, 14, 10)
	t.set_stylebox("normal", "LineEdit", field)
	t.set_stylebox("focus", "LineEdit", field_focus)
	t.set_stylebox("read_only", "LineEdit", field)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("caret_color", "LineEdit", CRIMSON_HI)
	t.set_color("selection_color", "LineEdit", Color(CRIMSON, 0.6))
	t.set_color("font_placeholder_color", "LineEdit", TEXT_FAINT)

	# Panels
	t.set_stylebox("panel", "PanelContainer", flat(Color(SURFACE, 0.92), LINE, 1, 3, 24, 20))
	t.set_stylebox("panel", "Panel", flat(Color(SURFACE, 0.92), LINE, 1, 3, 0, 0))

	# Sliders
	var track := flat(Color(LINE, 1.0), Color.TRANSPARENT, 0, 2, 0, 3)
	var fill := flat(CRIMSON, Color.TRANSPARENT, 0, 2, 0, 3)
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", flat(CRIMSON_HI, Color.TRANSPARENT, 0, 2, 0, 3))
	t.set_icon("grabber", "HSlider", _circle_icon(22, TEXT))
	t.set_icon("grabber_highlight", "HSlider", _circle_icon(24, Color.WHITE))
	t.set_icon("grabber_disabled", "HSlider", _circle_icon(22, DISABLED))

	# Progress bars
	t.set_stylebox("background", "ProgressBar", flat(Color(0, 0, 0, 0.55), LINE, 1, 2, 0, 0))
	t.set_stylebox("fill", "ProgressBar", flat(TEXT, Color.TRANSPARENT, 0, 2, 0, 0))
	t.set_color("font_color", "ProgressBar", TEXT)

	# Tabs
	t.set_stylebox("tab_selected", "TabBar", flat(Color(SURFACE_2, 1.0), CRIMSON_HI, 0, 0, 20, 12))
	(t.get_stylebox("tab_selected", "TabBar") as StyleBoxFlat).border_width_bottom = 3
	t.set_stylebox("tab_unselected", "TabBar", flat(Color(SURFACE, 0.6), Color.TRANSPARENT, 0, 0, 20, 12))
	t.set_stylebox("tab_hovered", "TabBar", flat(Color(SURFACE_2, 0.9), Color.TRANSPARENT, 0, 0, 20, 12))
	t.set_stylebox("tab_focus", "TabBar", focus)
	t.set_color("font_selected_color", "TabBar", Color.WHITE)
	t.set_color("font_unselected_color", "TabBar", TEXT_DIM)
	t.set_color("font_hovered_color", "TabBar", TEXT)

	# Scroll
	t.set_stylebox("scroll", "VScrollBar", flat(Color(0, 0, 0, 0.2), Color.TRANSPARENT, 0, 2, 4, 0))
	t.set_stylebox("grabber", "VScrollBar", flat(Color(TEXT_DIM, 0.5), Color.TRANSPARENT, 0, 3, 4, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", flat(TEXT_DIM, Color.TRANSPARENT, 0, 3, 4, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", flat(TEXT, Color.TRANSPARENT, 0, 3, 4, 0))

	# Popups
	t.set_stylebox("panel", "PopupMenu", flat(Color(SURFACE, 0.98), LINE, 1, 2, 8, 8))
	t.set_stylebox("hover", "PopupMenu", flat(Color(CRIMSON, 0.5), Color.TRANSPARENT, 0, 2, 8, 6))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_constant("v_separation", "PopupMenu", 14)

	t.set_stylebox("panel", "TooltipPanel", flat(Color(0.05, 0.05, 0.06, 0.97), LINE, 1, 2, 12, 8))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", FONT_SMALL)

	t.set_stylebox("separator", "HSeparator", flat(LINE, Color.TRANSPARENT, 0, 0, 0, 0))
	t.set_constant("separation", "HSeparator", 12)
	return t


static func _circle_icon(size: int, color: Color) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			var a := clampf(c - d + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(color, a))
	return ImageTexture.create_from_image(img)
