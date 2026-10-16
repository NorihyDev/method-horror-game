class_name NoteReader
extends OverlayPanel
## Reads a note on aged paper. Text is plain (no BBCode).

var title_text := ""
var body_text := ""


func build() -> void:
	panel.add_theme_stylebox_override("panel", ThemeFactory.flat(Color(0.8, 0.76, 0.66), Color(0.45, 0.4, 0.32), 1, 2, 40, 34))
	panel.custom_minimum_size = Vector2(640, 0)
	var t := UI.label(title_text, ThemeFactory.FONT_H2, Color(0.12, 0.1, 0.08))
	t.add_theme_font_override("font", ThemeFactory.title_font())
	t.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	t.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	body.add_child(t)
	var rule := ColorRect.new()
	rule.color = Color(0.45, 0.08, 0.06)
	rule.custom_minimum_size = Vector2(80, 2)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	body.add_child(rule)
	var b := Label.new()
	b.text = body_text
	b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(560, 0)
	b.add_theme_color_override("font_color", Color(0.14, 0.12, 0.1))
	b.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	b.add_theme_font_size_override("font_size", int(ThemeFactory.FONT_BODY * 1.0))
	b.add_theme_font_override("font", ThemeFactory.title_font())
	b.add_theme_constant_override("line_spacing", 6)
	body.add_child(b)
	var close_btn := UI.button("CLOSE", func() -> void: close())
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_END
	body.add_child(close_btn)
