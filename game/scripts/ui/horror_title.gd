class_name HorrorTitle
extends Control
## Distressed title: worn print with a blood-red echo behind it. Every few
## seconds it glitches (the echo tears sideways, the letters jump and
## flicker). Still with reduced motion or reduced flashing.

var main: Label
var ghost: Label
var _rng := RandomNumberGenerator.new()
var _next := 2.5
var _burst := 0.0


func _init(text: String, font_size: int, translate: bool = true) -> void:
	ghost = UI.title(text, font_size)
	ghost.add_theme_color_override("font_color", Color(ThemeFactory.CRIMSON_HI, 0.55))
	ghost.material = null
	main = UI.title(text, font_size)
	for l: Label in [ghost, main]:
		l.add_theme_constant_override("outline_size", 0)
		if not translate:
			l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		add_child(l)
	_rng.randomize()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_alignment(a: HorizontalAlignment) -> void:
	main.horizontal_alignment = a
	ghost.horizontal_alignment = a


func _get_minimum_size() -> Vector2:
	return main.get_combined_minimum_size() if main else Vector2.ZERO


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_READY:
		for l: Label in [ghost, main]:
			l.size = size
		_rest()


func _process(delta: float) -> void:
	if Settings.b("reduced_motion") or Settings.b("reduced_flashing"):
		if _burst > 0.0:
			_burst = 0.0
			_rest()
		return
	_next -= delta
	if _next <= 0.0 and _burst <= 0.0:
		_burst = _rng.randf_range(0.16, 0.34)
		_next = _rng.randf_range(3.0, 7.5)
	if _burst > 0.0:
		_burst -= delta
		if _burst <= 0.0:
			_rest()
			return
		ghost.position = Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-2, 2))
		ghost.modulate.a = _rng.randf_range(0.6, 1.0)
		main.position = Vector2(_rng.randf_range(-2.5, 2.5), 0)
		main.modulate.a = 0.35 if _rng.randf() < 0.25 else 1.0


func _rest() -> void:
	if ghost == null:
		return
	ghost.position = Vector2(3, 2)
	ghost.modulate.a = 0.6
	main.position = Vector2.ZERO
	main.modulate.a = 1.0
