extends TestCase
## Accessibility audit: text contrast (WCAG 2.2 AA, 4.5:1 for body text),
## touch-target size, a name for every control a screen reader can reach,
## and keyboard/controller focus on every menu screen.

## Screens that open without match or network context.
const SCREENS: PackedStringArray = [
	"splash",
	"notice",
	"name_entry",
	"main_menu",
	"solo_setup",
	"multiplayer",
	"settings",
	"shop",
	"progress",
	"profile",
	"credits",
]
const SETTINGS_TABS := 5
const MIN_CONTRAST := 4.5
## Smallest interactive control, in base-resolution pixels (720 px tall).
const MIN_TARGET := ThemeFactory.MIN_TOUCH - 8


static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var lin := func(v: float) -> float: return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)


static func _over(fg: Color, bg: Color) -> Color:
	return Color(bg.lerp(Color(fg, 1.0), fg.a), 1.0)


func test_text_colours_meet_aa() -> void:
	var texts := {
		"TEXT": ThemeFactory.TEXT,
		"TEXT_DIM": ThemeFactory.TEXT_DIM,
		"TEXT_FAINT": ThemeFactory.TEXT_FAINT,
		"DANGER": ThemeFactory.DANGER,
		"WARN": ThemeFactory.WARN,
		"OK": ThemeFactory.OK,
	}
	var panel := _over(Color(ThemeFactory.SURFACE, 0.93), ThemeFactory.BG)
	var backgrounds := {
		"BG": ThemeFactory.BG, "SURFACE": ThemeFactory.SURFACE, "SURFACE_2": ThemeFactory.SURFACE_2, "panel": panel
	}
	for t in texts:
		for b in backgrounds:
			var ratio := contrast(texts[t], backgrounds[b])
			assert_true(ratio >= MIN_CONTRAST, "%s on %s is %.2f:1" % [t, b, ratio])


func test_button_text_contrast() -> void:
	var theme := ThemeFactory.theme()
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := theme.get_stylebox(state, "Button")
		if not box is StyleBoxFlat or not (box as StyleBoxFlat).draw_center:
			continue  # the focus ring is an outline over the normal slab
		var bg := _over((box as StyleBoxFlat).bg_color, ThemeFactory.SURFACE)
		var colour_name := "font_color" if state == "normal" else "font_%s_color" % state
		if not theme.has_color(colour_name, "Button"):
			colour_name = "font_color"
		var fg := theme.get_color(colour_name, "Button")
		var ratio := contrast(fg, bg)
		assert_true(ratio >= MIN_CONTRAST, "Button %s text is %.2f:1" % [state, ratio])
	# Primary buttons: off-white on crimson.
	var primary := _over(Color(ThemeFactory.CRIMSON, 0.85), ThemeFactory.SURFACE)
	assert_true(contrast(ThemeFactory.TEXT, primary) >= MIN_CONTRAST, "primary button text")
	assert_true(contrast(ThemeFactory.TEXT, ThemeFactory.CRIMSON_HI) >= MIN_CONTRAST, "primary button hover text")


func test_menu_screens() -> void:
	var app: App = Session.app
	if not Saves.has_name():
		Saves.set_display_name("Audit")
	for screen_name in SCREENS:
		var screen := app.reset_to(screen_name)
		await frames(4)
		if screen_name == "settings":
			for tab in SETTINGS_TABS:
				screen.set("_tab", tab)
				screen.call("_render")
				await frames(3)
				_audit(screen, "settings tab %d" % tab)
		else:
			_audit(screen, screen_name)
	await _clear(app)


func test_dialogs() -> void:
	var app: App = Session.app
	app.reset_to("main_menu")
	await frames(2)
	app.confirm("QUIT_TITLE", "QUIT_BODY", "QUIT_CONFIRM", func() -> void: pass)
	await frames(3)
	_audit(app.modal_layer, "confirm dialog")
	await _clear(app)


## Leaves the app as the test runner found it: no screens, no menu world
## (the menu diorama's camera and lights would leak into later tests).
func _clear(app: App) -> void:
	app.close_all_modals()
	for s in app._stack:
		s.on_exit()
		s.queue_free()
	app._stack.clear()
	app.set_world(null)
	AudioService.stop_all_world()
	AudioService.stop_music(0.0)
	await frames(2)


## Every visible interactive control: big enough to touch, named for screen
## readers, reachable by keyboard/controller; and the screen has a focus target.
func _audit(root: Node, where: String) -> void:
	var controls: Array[Control] = []
	_collect(root, controls)
	var focusable := 0
	for c in controls:
		var label := "%s: %s '%s'" % [where, c.get_class(), _name_of(c)]
		var r := c.get_global_rect()
		if c is BaseButton or c is Range or c is LineEdit:
			assert_true(r.size.y >= MIN_TARGET - 0.5, "%s is %d px tall" % [label, int(r.size.y)])
			# Headless font metrics are placeholders, so width is only checked
			# where no text pads the control out (text + 44 px padding is wide enough).
			if not (c is Button and not (c as Button).text.is_empty()):
				assert_true(r.size.x >= MIN_TARGET - 0.5, "%s is %d px wide" % [label, int(r.size.x)])
			assert_false(_name_of(c).is_empty(), "%s has no accessible name" % label)
			assert_ne(c.focus_mode, Control.FOCUS_NONE, "%s cannot take focus" % label)
		if c.focus_mode == Control.FOCUS_ALL:
			focusable += 1
	assert_true(focusable > 0 or controls.is_empty(), "%s: nothing to focus with a keyboard or controller" % where)


func _collect(node: Node, out: Array[Control]) -> void:
	for child in node.get_children():
		if child is Control:
			var c: Control = child
			if not c.is_visible_in_tree():
				continue
			if c is BaseButton or c is Range or c is LineEdit:
				if not (c is ScrollBar):
					out.append(c)
		_collect(child, out)


## What a screen reader would announce: explicit name, else visible text,
## else the tooltip.
static func _name_of(c: Control) -> String:
	if not c.accessibility_name.is_empty():
		return c.accessibility_name
	if c is Button and not (c as Button).text.is_empty():
		return (c as Button).text
	if c is LineEdit and not (c as LineEdit).placeholder_text.is_empty():
		return (c as LineEdit).placeholder_text
	return c.tooltip_text


func test_enemy_cues_are_captioned() -> void:
	for profile in [EnemyProfile.watcher(), EnemyProfile.sister(), EnemyProfile.lineman()]:
		var p: EnemyProfile = profile
		for sound in [p.breath_sound, p.step_sound, p.cue_sound, p.growl_sound, p.screech_sound]:
			if not str(sound).is_empty():
				assert_true(AudioService.CAPTIONS.has(sound), "%s has no caption" % sound)


func test_captions_are_translated() -> void:
	var keys: Array = AudioService.CAPTIONS.values()
	keys.append("CAP_MONITOR_FAST")
	for locale in ["en", "fr"]:
		var t := TranslationServer.get_translation_object(locale)
		for key in keys:
			assert_true(t != null and not str(t.get_message(key)).is_empty(), "%s missing in %s" % [key, locale])


## Long sounds (humming, trains, motors) caption while audible, not only when
## they start; out of earshot or stopped, they stay quiet.
func test_looping_emitters_caption_while_audible() -> void:
	var before := Settings.b("sound_captions")
	Settings.set_value("sound_captions", true, false)
	var root := Node3D.new()
	add_child(root)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.make_current()
	var heard: Array[String] = []
	var on_caption := func(key: String, _dir: float, _dur: float) -> void: heard.append(key)
	AudioService.caption_requested.connect(on_caption)
	var hum := AudioService.make_emitter("sister_hum_loop", 0.0, 16.0)
	root.add_child(hum)
	hum.position = Vector3(2, 0, -4)
	hum.play()
	AudioService._caption_cooldowns.clear()
	AudioService._caption_emitters()
	assert_eq(heard, ["CAP_HUMMING"], "audible humming is captioned")
	heard.clear()
	AudioService._caption_cooldowns.clear()
	hum.position = Vector3(0, 0, -15)
	AudioService._caption_emitters()
	assert_empty(heard, "out of earshot: no caption")
	hum.position = Vector3(2, 0, -4)
	hum.stop()
	AudioService._caption_emitters()
	assert_empty(heard, "stopped: no caption")
	AudioService.caption_requested.disconnect(on_caption)
	Settings.set_value("sound_captions", before, false)
	root.queue_free()
	AudioService._caption_cooldowns.clear()
	await frames(1)
