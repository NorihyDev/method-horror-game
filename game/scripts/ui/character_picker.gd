class_name CharacterPicker
extends HFlowContainer
## Portrait cards for every character; the selected one is highlighted.
## Used on first launch (name entry) and in Profile.

signal picked(id: String)

var selected := ""
var _buttons := {}


func _init(p_selected: String, card_width: int = 150) -> void:
	selected = p_selected
	add_theme_constant_override("h_separation", 12)
	add_theme_constant_override("v_separation", 12)
	for id in CharacterCatalog.ids():
		var card := UI.vbox(6)
		var pic := TextureRect.new()
		pic.texture = CharacterCatalog.portrait(id)
		pic.custom_minimum_size = Vector2(card_width, card_width * 300.0 / 256.0)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		card.add_child(pic)
		var pick := UI.button(CharacterCatalog.display_name(id), _on_pick.bind(id), false, card_width)
		pick.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		# Every card the same width, whatever the name.
		pick.clip_text = true
		pick.add_theme_font_size_override("font_size", ThemeFactory.FONT_SMALL + 2)
		pick.name = "Pick_" + id
		card.add_child(pick)
		_buttons[id] = pick
		add_child(card)
	_paint()


func _on_pick(id: String) -> void:
	selected = id
	_paint()
	picked.emit(id)


func _paint() -> void:
	# Tight padding so every name fits a narrow card; the chosen one is red.
	var normal := ThemeFactory.edged(Color(ThemeFactory.BG, 0.82), ThemeFactory.EDGE, 3, 4, 10)
	var hover := ThemeFactory.edged(Color(ThemeFactory.CRIMSON, 0.3), ThemeFactory.CRIMSON_HI, 5, 4, 10)
	var chosen := ThemeFactory.edged(Color(ThemeFactory.CRIMSON, 0.88), ThemeFactory.CRIMSON_HI, 5, 4, 10)
	for id: String in _buttons:
		var b: Button = _buttons[id]
		var on := id == selected
		b.add_theme_stylebox_override("normal", chosen if on else normal)
		b.add_theme_stylebox_override("hover", chosen if on else hover)
		b.add_theme_stylebox_override("pressed", chosen)
