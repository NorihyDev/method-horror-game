extends TestCase
## Settings sanitizing, presets, persistence and reset.

var _snap: Dictionary


func before_each() -> void:
	_snap = Settings.snapshot()


func after_each() -> void:
	Settings.restore(_snap)


func test_sanitize_rejects_out_of_range_and_nan() -> void:
	assert_eq(Settings.sanitize("fov", 500.0), 95.0)
	assert_eq(Settings.sanitize("fov", -3.0), 65.0)
	assert_eq(Settings.sanitize("fov", NAN), 75.0)
	assert_eq(Settings.sanitize("vol_master", INF), 0.9)
	assert_eq(Settings.sanitize("vol_master", "loud"), 0.9)


func test_sanitize_options() -> void:
	assert_eq(Settings.sanitize("shadows", "ultra"), "low")
	assert_eq(Settings.sanitize("msaa", 4.0), 4)
	assert_eq(Settings.sanitize("msaa", 3), 0)
	assert_eq(Settings.sanitize("language", "fr"), "fr")


func test_preset_then_individual_change_becomes_custom() -> void:
	Settings.set_value("quality_preset", "low")
	assert_eq(Settings.get_value("shadows"), "off")
	assert_eq(Settings.get_value("render_scale"), 0.7)
	Settings.set_value("shadows", "high")
	assert_eq(Settings.get_value("quality_preset"), "custom")


func test_values_persist_and_reload() -> void:
	Settings.set_value("fov", 82.0)
	Settings.set_value("invert_y", true)
	Settings.load_settings()
	assert_eq(Settings.get_value("fov"), 82.0)
	assert_eq(Settings.get_value("invert_y"), true)


func test_reset_category_only_touches_that_category() -> void:
	Settings.set_value("vol_music", 0.1)
	Settings.set_value("fov", 90.0)
	Settings.reset_category(Settings.CAT_AUDIO)
	assert_eq(Settings.get_value("vol_music"), 0.7)
	assert_eq(Settings.get_value("fov"), 90.0)


func test_render_scale_applies_to_viewport() -> void:
	Settings.set_value("battery_saver", false)
	Settings.set_value("render_scale", 0.8)
	assert_true(absf(get_tree().root.scaling_3d_scale - 0.8) < 0.001, "viewport scale should follow setting")
	Settings.set_value("battery_saver", true)
	assert_true(get_tree().root.scaling_3d_scale <= 0.75 + 0.001, "battery saver caps scale")
	assert_eq(Engine.max_fps, 30)


func test_settings_v0_migration() -> void:
	var f := FileAccess.open(Settings.path, FileAccess.WRITE)
	f.store_string(SaveIO.encode({"fov": 70.0, "unknown_key": 5}))
	f.close()
	Settings.load_settings()
	assert_eq(Settings.get_value("fov"), 70.0)


func test_every_setting_has_translations() -> void:
	Localization.load_all()
	for key: String in Settings.SCHEMA:
		if Settings.SCHEMA[key].get("hidden", false):
			continue
		var label := "SET_" + key.to_upper()
		TranslationServer.set_locale("en")
		assert_ne(tr(label), label, "missing label for " + key)
		assert_ne(tr(label + "_TIP"), label + "_TIP", "missing tooltip for " + key)
