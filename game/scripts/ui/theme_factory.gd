class_name ThemeFactory
extends RefCounted
## Builds the METHOD visual language as a Godot Theme: near-black surfaces,
## bone-white type in worn print and typewriter faces, dried-blood accents.
##
## Fonts (bundled, see docs/asset-manifest.md): IM Fell English SC for titles,
## Special Elite for buttons, labels and captions, Crimson Pro for reading.
## System fonts stay as fallbacks for any missing glyph.

const BG := Color("070607")
const SURFACE := Color("0f0d0e")
const SURFACE_2 := Color("1a1416")
const LINE := Color("2e2426")
## Dark red edge of buttons and panels.
const EDGE := Color("4a1518")
const TEXT := Color("e6dccb")
const TEXT_DIM := Color("9d978b")
## Quietest readable text: still 4.5:1 on every surface (WCAG AA).
const TEXT_FAINT := Color("8d877d")
## Disabled controls only (exempt from contrast rules); never for information.
const DISABLED := Color("625e57")
const CRIMSON := Color("7d0c0c")
const CRIMSON_HI := Color("b01e1e")
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
static var _body_font: Font
static var _type_font: Font
static var _mono_font: Font


static func theme() -> Theme:
	if _theme == null:
		_theme = _build()
	return _theme


## Worn old-print serif for titles and headings.
static func title_font() -> Font:
	if _title_font == null:
		_title_font = _bundled("IMFellEnglishSC-Regular.ttf", ["Georgia", "Times New Roman", "Noto Serif", "serif"], 2)
	return _title_font


## Book serif for reading (the theme default).
static func body_font() -> Font:
	if _body_font == null:
		_body_font = _bundled("CrimsonPro-Variable.ttf", ["Georgia", "Noto Serif", "serif"], 0, 500)
	return _body_font


## Typewriter face for buttons, tabs, captions and fields: case-file notes.
static func type_font() -> Font:
	if _type_font == null:
		_type_font = _bundled("SpecialElite-Regular.ttf", ["Courier New", "Noto Sans Mono", "monospace"], 1)
	return _type_font


static func _bundled(file: String, fallbacks: Array, spacing: int = 0, weight: int = 0) -> Font:
	var v := FontVariation.new()
	var path := "res://assets/fonts/" + file
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(fallbacks)
	if ResourceLoader.exists(path):
		v.base_font = load(path)
		v.fallbacks = [sys]
	else:
		v.base_font = sys
	v.spacing_glyph = spacing
	if weight > 0:
		v.variation_opentype = {"wght": weight}
	return v


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


## Button slab: hairline frame with a thick edge on the left.
static func edged(bg: Color, edge: Color, left: int, pad_h: int = 22, pad_v: int = 12) -> StyleBoxFlat:
	var sb := flat(bg, edge, 1, 0, pad_h, pad_v)
	sb.border_width_left = left
	sb.content_margin_left = pad_h + left
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 2)
	return sb


## Panels: almost black, a rust line along the top, and a deep shadow.
static func panel_box(pad_h: int, pad_v: int, alpha: float = 0.94) -> StyleBoxFlat:
	var sb := flat(Color(SURFACE, alpha), EDGE, 1, 0, pad_h, pad_v)
	sb.border_width_top = 2
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 22
	return sb


static func _build() -> Theme:
	var t := Theme.new()
	t.default_font_size = FONT_BODY
	t.default_font = body_font()

	# Labels
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 1)
	t.set_constant("line_spacing", "Label", 4)

	# Buttons: black slabs with a dried-blood edge on the left that wells up
	# red on hover and press.
	var normal := edged(Color(BG, 0.82), EDGE, 3)
	var hover := edged(Color(CRIMSON, 0.3), CRIMSON_HI, 5)
	var pressed := edged(Color(CRIMSON, 0.62), CRIMSON_HI, 5)
	var disabled := edged(Color(BG, 0.45), Color(LINE, 0.5), 2)
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
		t.set_font("font", type, type_font())
	t.set_constant("h_separation", "Button", 10)
	# Toggles: a plain row with a blood-red switch, not a button slab.
	var row := flat(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0, 12, 10)
	var row_hover := flat(Color(CRIMSON, 0.14), Color.TRANSPARENT, 0, 0, 12, 10)
	for state in ["normal", "pressed", "disabled"]:
		t.set_stylebox(state, "CheckButton", row)
	for state in ["hover", "hover_pressed"]:
		t.set_stylebox(state, "CheckButton", row_hover)
	t.set_icon("checked", "CheckButton", _switch_icon(true, false))
	t.set_icon("unchecked", "CheckButton", _switch_icon(false, false))
	t.set_icon("checked_disabled", "CheckButton", _switch_icon(true, true))
	t.set_icon("unchecked_disabled", "CheckButton", _switch_icon(false, true))
	for type in ["LineEdit", "TabBar", "PopupMenu", "TooltipLabel"]:
		t.set_font("font", type, type_font())

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
	t.set_stylebox("panel", "PanelContainer", panel_box(24, 20))
	t.set_stylebox("panel", "Panel", panel_box(0, 0))

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


## Pill switch, 56x30: red with the knob right when on, dark when off.
static func _switch_icon(on: bool, off_limits: bool) -> Texture2D:
	var w := 56
	var h := 30
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var track := CRIMSON if on else LINE
	var knob := TEXT if on else TEXT_DIM
	if off_limits:
		track = Color(track, 0.45)
		knob = DISABLED
	var r := h / 2.0
	var kx := w - r if on else r
	for y in h:
		for x in w:
			var p := Vector2(x + 0.5, y + 0.5)
			var cx := clampf(p.x, r, w - r)
			var d_track := p.distance_to(Vector2(cx, r)) - (r - 1.0)
			var d_knob := p.distance_to(Vector2(kx, r)) - (r - 5.0)
			var c := Color(track, clampf(0.5 - d_track, 0.0, 1.0))
			var ka := clampf(0.5 - d_knob, 0.0, 1.0)
			c = Color(c.lerp(knob, ka), maxf(c.a, ka))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _circle_icon(size: int, color: Color) -> Texture2D:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := (size - 1) / 2.0
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length()
			var a := clampf(c - d + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(color, a))
	return ImageTexture.create_from_image(img)
