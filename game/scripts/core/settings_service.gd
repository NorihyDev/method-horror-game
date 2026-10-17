extends Node
## Autoload "Settings": persistent local preferences.
##
## Every key in SCHEMA is consumed somewhere real. Keys a platform cannot honor
## are flagged (`desktop_only`) so the settings screen hides them instead of
## showing a switch that does nothing.

signal changed(key: String, value: Variant)

const PATH := "user://settings.json"

const CAT_GRAPHICS := "graphics"
const CAT_AUDIO := "audio"
const CAT_CONTROLS := "controls"
const CAT_GAMEPLAY := "gameplay"
const CAT_ACCESS := "accessibility"

## reload: change applies the next time a map loads.
const SCHEMA := {
	# --- Graphics -----------------------------------------------------------
	"quality_preset": {"cat": CAT_GRAPHICS, "default": "auto", "options": ["low", "medium", "high", "custom"]},
	"render_scale": {"cat": CAT_GRAPHICS, "default": 1.0, "min": 0.5, "max": 1.0, "step": 0.05},
	"upscaler": {"cat": CAT_GRAPHICS, "default": "fsr", "options": ["bilinear", "fsr"]},
	"dynamic_resolution": {"cat": CAT_GRAPHICS, "default": false},
	"msaa": {"cat": CAT_GRAPHICS, "default": 0, "options": [0, 2, 4]},
	"shadows": {"cat": CAT_GRAPHICS, "default": "low", "options": ["off", "low", "high"]},
	"light_quality": {"cat": CAT_GRAPHICS, "default": "low", "options": ["low", "high"]},
	"texture_quality": {"cat": CAT_GRAPHICS, "default": "high", "options": ["low", "high"], "reload": true},
	"particles": {"cat": CAT_GRAPHICS, "default": "low", "options": ["off", "low", "high"]},
	"light_shafts": {"cat": CAT_GRAPHICS, "default": true},
	"draw_distance": {"cat": CAT_GRAPHICS, "default": "near", "options": ["near", "far"]},
	"glow": {"cat": CAT_GRAPHICS, "default": true},
	"vignette": {"cat": CAT_GRAPHICS, "default": true},
	"film_grain": {"cat": CAT_GRAPHICS, "default": true},
	"exposure": {"cat": CAT_GRAPHICS, "default": 1.0, "min": 0.6, "max": 1.6, "step": 0.05},
	"fov": {"cat": CAT_GRAPHICS, "default": 75.0, "min": 65.0, "max": 95.0, "step": 1.0},
	"frame_cap": {"cat": CAT_GRAPHICS, "default": 60, "options": [30, 60, 90, 120, 0]},
	"battery_saver": {"cat": CAT_GRAPHICS, "default": false},
	"vsync": {"cat": CAT_GRAPHICS, "default": true, "desktop_only": true},
	"window_mode":
	{"cat": CAT_GRAPHICS, "default": "windowed", "options": ["windowed", "fullscreen"], "desktop_only": true},
	"window_size":
	{
		"cat": CAT_GRAPHICS,
		"default": "1280x720",
		"options": ["1280x720", "1600x900", "1920x1080", "2560x1440"],
		"desktop_only": true
	},
	# --- Audio --------------------------------------------------------------
	"vol_master": {"cat": CAT_AUDIO, "default": 0.9, "min": 0.0, "max": 1.0, "step": 0.05},
	"vol_music": {"cat": CAT_AUDIO, "default": 0.7, "min": 0.0, "max": 1.0, "step": 0.05},
	"vol_ambience": {"cat": CAT_AUDIO, "default": 0.8, "min": 0.0, "max": 1.0, "step": 0.05},
	"vol_sfx": {"cat": CAT_AUDIO, "default": 0.9, "min": 0.0, "max": 1.0, "step": 0.05},
	"vol_ui": {"cat": CAT_AUDIO, "default": 0.7, "min": 0.0, "max": 1.0, "step": 0.05},
	"mute": {"cat": CAT_AUDIO, "default": false},
	"dynamic_range": {"cat": CAT_AUDIO, "default": "full", "options": ["full", "night"]},
	"mono_audio": {"cat": CAT_AUDIO, "default": false},
	"subtitles": {"cat": CAT_AUDIO, "default": true},
	"sound_captions": {"cat": CAT_AUDIO, "default": false},
	"caption_size": {"cat": CAT_AUDIO, "default": "medium", "options": ["small", "medium", "large"]},
	"caption_background": {"cat": CAT_AUDIO, "default": 0.6, "min": 0.0, "max": 1.0, "step": 0.1},
	# --- Controls -----------------------------------------------------------
	"mouse_sensitivity": {"cat": CAT_CONTROLS, "default": 1.0, "min": 0.2, "max": 3.0, "step": 0.05},
	"touch_sensitivity": {"cat": CAT_CONTROLS, "default": 1.0, "min": 0.2, "max": 3.0, "step": 0.05},
	"pad_sensitivity": {"cat": CAT_CONTROLS, "default": 1.0, "min": 0.2, "max": 3.0, "step": 0.05},
	"invert_y": {"cat": CAT_CONTROLS, "default": false},
	"look_acceleration": {"cat": CAT_CONTROLS, "default": true},
	"pad_deadzone": {"cat": CAT_CONTROLS, "default": 0.2, "min": 0.05, "max": 0.45, "step": 0.01},
	"joystick_mode": {"cat": CAT_CONTROLS, "default": "floating", "options": ["floating", "fixed"]},
	"joystick_deadzone": {"cat": CAT_CONTROLS, "default": 0.12, "min": 0.0, "max": 0.4, "step": 0.01},
	"sprint_mode": {"cat": CAT_CONTROLS, "default": "hold", "options": ["hold", "toggle"]},
	"crouch_mode": {"cat": CAT_CONTROLS, "default": "toggle", "options": ["hold", "toggle"]},
	"haptics": {"cat": CAT_CONTROLS, "default": 0.7, "min": 0.0, "max": 1.0, "step": 0.1},
	"touch_controls": {"cat": CAT_CONTROLS, "default": "auto", "options": ["auto", "on", "off"]},
	"touch_button_scale": {"cat": CAT_CONTROLS, "default": 1.0, "min": 0.75, "max": 1.5, "step": 0.05},
	"touch_opacity": {"cat": CAT_CONTROLS, "default": 0.55, "min": 0.15, "max": 1.0, "step": 0.05},
	"left_handed": {"cat": CAT_CONTROLS, "default": false},
	"touch_layout": {"cat": CAT_CONTROLS, "default": {}, "hidden": true},
	"key_bindings": {"cat": CAT_CONTROLS, "default": {}, "hidden": true},
	# --- Gameplay -----------------------------------------------------------
	"language": {"cat": CAT_GAMEPLAY, "default": "auto", "options": ["auto", "en", "fr"]},
	"hints": {"cat": CAT_GAMEPLAY, "default": "normal", "options": ["off", "normal", "frequent"]},
	"jump_scares": {"cat": CAT_GAMEPLAY, "default": "full", "options": ["full", "reduced"]},
	"show_ping": {"cat": CAT_GAMEPLAY, "default": false},
	"auto_reconnect": {"cat": CAT_GAMEPLAY, "default": true},
	# --- Accessibility -----------------------------------------------------
	"ui_scale": {"cat": CAT_ACCESS, "default": 1.0, "min": 0.85, "max": 1.3, "step": 0.05},
	"high_contrast": {"cat": CAT_ACCESS, "default": false},
	"reduced_flashing": {"cat": CAT_ACCESS, "default": false},
	"reduced_motion": {"cat": CAT_ACCESS, "default": false},
	"head_bob": {"cat": CAT_ACCESS, "default": true},
	"camera_shake": {"cat": CAT_ACCESS, "default": true},
}

const PRESETS := {
	"low":
	{
		"render_scale": 0.7,
		"upscaler": "bilinear",
		"msaa": 0,
		"shadows": "off",
		"light_quality": "low",
		"texture_quality": "low",
		"particles": "off",
		"light_shafts": false,
		"draw_distance": "near",
		"glow": false,
	},
	"medium":
	{
		"render_scale": 0.85,
		"upscaler": "fsr",
		"msaa": 0,
		"shadows": "low",
		"light_quality": "low",
		"texture_quality": "high",
		"particles": "low",
		"light_shafts": true,
		"draw_distance": "near",
		"glow": true,
	},
	"high":
	{
		"render_scale": 1.0,
		"upscaler": "fsr",
		"msaa": 2,
		"shadows": "high",
		"light_quality": "high",
		"texture_quality": "high",
		"particles": "high",
		"light_shafts": true,
		"draw_distance": "far",
		"glow": true,
	},
}

var load_recovered := false
var path := PATH
var _values: Dictionary = {}


func _ready() -> void:
	if AppInfo.uses_isolated_storage():
		path = "user://test_settings.json"
		SaveIO.delete_all(path)
	load_settings()
	apply_all()


func default_value(key: String) -> Variant:
	var spec: Dictionary = SCHEMA.get(key, {})
	var v: Variant = spec.get("default")
	return v.duplicate(true) if v is Dictionary else v


func get_value(key: String) -> Variant:
	if not SCHEMA.has(key):
		push_error("Unknown setting '%s'" % key)
		return null
	return _values.get(key, default_value(key))


func f(key: String) -> float:
	return float(get_value(key))


func b(key: String) -> bool:
	return bool(get_value(key))


func s(key: String) -> String:
	return str(get_value(key))


func is_available(key: String) -> bool:
	var spec: Dictionary = SCHEMA.get(key, {})
	if spec.get("desktop_only", false) and not AppInfo.is_desktop():
		return false
	return true


## Sets and applies a value. Graphics edits switch the preset to "custom".
func set_value(key: String, value: Variant, persist: bool = true) -> void:
	if not SCHEMA.has(key):
		push_error("Unknown setting '%s'" % key)
		return
	var clean: Variant = sanitize(key, value)
	if _values.get(key) == clean and _values.has(key):
		return
	_values[key] = clean
	if key == "quality_preset":
		_apply_preset(str(clean))
	elif _is_preset_key(key) and s("quality_preset") != "custom":
		var preset: Dictionary = PRESETS.get(_effective_preset(), {})
		if preset.get(key) != clean:
			_values["quality_preset"] = "custom"
			changed.emit("quality_preset", "custom")
	_apply_key(key)
	changed.emit(key, clean)
	if persist:
		save_settings()


func snapshot() -> Dictionary:
	return _values.duplicate(true)


## Restores a snapshot (settings screen "Cancel").
func restore(snap: Dictionary) -> void:
	_values = snap.duplicate(true)
	apply_all()
	for key in SCHEMA:
		changed.emit(key, get_value(key))
	save_settings()


func reset_category(cat: String) -> void:
	for key in SCHEMA:
		if SCHEMA[key]["cat"] == cat and not SCHEMA[key].get("hidden", false):
			_values.erase(key)
	if cat == CAT_GRAPHICS:
		_apply_preset(_effective_preset())
	apply_all()
	for key in SCHEMA:
		if SCHEMA[key]["cat"] == cat:
			changed.emit(key, get_value(key))
	save_settings()


func reset_all() -> void:
	_values.clear()
	_apply_preset(_effective_preset())
	apply_all()
	for key in SCHEMA:
		changed.emit(key, get_value(key))
	save_settings()


func sanitize(key: String, value: Variant) -> Variant:
	var spec: Dictionary = SCHEMA[key]
	var def: Variant = spec["default"]
	if spec.has("options"):
		for opt in spec["options"]:
			if typeof(opt) == TYPE_INT and (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT):
				if int(value) == opt:
					return opt
			elif str(opt) == str(value):
				return opt
		if key == "quality_preset" and str(value) == "auto":
			return "auto"
		return def
	match typeof(def):
		TYPE_BOOL:
			return bool(value) if (value is bool or value is int or value is float) else def
		TYPE_FLOAT, TYPE_INT:
			if not (value is float or value is int):
				return def
			var num := float(value)
			if is_nan(num) or is_inf(num):
				return def
			return clampf(num, float(spec.get("min", num)), float(spec.get("max", num)))
		TYPE_DICTIONARY:
			return value.duplicate(true) if value is Dictionary else {}
	return def


func load_settings() -> void:
	var res := SaveIO.read_with_recovery(path)
	load_recovered = bool(res["recovered"])
	_values.clear()
	if res["data"] is Dictionary:
		var data: Dictionary = _migrate(res["data"])
		var stored: Dictionary = data.get("values", {})
		for key in stored:
			if SCHEMA.has(key):
				_values[key] = sanitize(key, stored[key])
	if s("quality_preset") == "auto" or not _values.has("quality_preset"):
		_values["quality_preset"] = _effective_preset()
		_apply_preset(str(_values["quality_preset"]))


func save_settings() -> void:
	var err := SaveIO.write_atomic(path, {"schema_version": AppInfo.SETTINGS_SCHEMA_VERSION, "values": _values})
	if err != OK:
		Log.error("settings", "Could not save settings", {"error": error_string(err)})


func apply_all() -> void:
	for key in SCHEMA:
		_apply_key(key)


func effective_frame_cap() -> int:
	var cap := int(get_value("frame_cap"))
	if b("battery_saver"):
		cap = 30 if cap == 0 else mini(cap, 30)
	return cap


func effective_render_scale() -> float:
	var scale := f("render_scale")
	if b("battery_saver"):
		scale = minf(scale, 0.75)
	return scale


func motion_reduced() -> bool:
	return b("reduced_motion")


func _effective_preset() -> String:
	var p := s("quality_preset")
	if p == "auto" or not PRESETS.has(p) and p != "custom":
		return "medium" if AppInfo.is_mobile() else "high"
	return p


func _is_preset_key(key: String) -> bool:
	return PRESETS["high"].has(key)


func _apply_preset(preset: String) -> void:
	if preset == "custom" or not PRESETS.has(preset):
		return
	for k in PRESETS[preset]:
		_values[k] = PRESETS[preset][k]
		_apply_key(k)
		changed.emit(k, _values[k])


func _migrate(data: Dictionary) -> Dictionary:
	var version := int(data.get("schema_version", 0))
	if version < 1:
		# v0 stored the values at the top level.
		data = {"schema_version": 1, "values": data.duplicate()}
	return data


func _apply_key(key: String) -> void:
	if not is_inside_tree():
		return
	var root := get_tree().root
	match key:
		"render_scale", "upscaler", "battery_saver":
			var scale := effective_render_scale()
			root.scaling_3d_scale = scale
			if s("upscaler") == "fsr" and scale < 0.999:
				root.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
			else:
				root.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
			Engine.max_fps = effective_frame_cap()
		"msaa":
			match int(get_value("msaa")):
				2:
					root.msaa_3d = Viewport.MSAA_2X
				4:
					root.msaa_3d = Viewport.MSAA_4X
				_:
					root.msaa_3d = Viewport.MSAA_DISABLED
		"frame_cap":
			Engine.max_fps = effective_frame_cap()
		"vsync":
			if is_available("vsync"):
				DisplayServer.window_set_vsync_mode(
					DisplayServer.VSYNC_ENABLED if b("vsync") else DisplayServer.VSYNC_DISABLED
				)
		"window_mode":
			if is_available("window_mode") and not AppInfo.is_headless():
				var fullscreen := s("window_mode") == "fullscreen"
				DisplayServer.window_set_mode(
					DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
				)
				if not fullscreen:
					_apply_key("window_size")
		"window_size":
			if is_available("window_size") and not AppInfo.is_headless() and s("window_mode") == "windowed":
				var parts := s("window_size").split("x")
				if parts.size() == 2:
					var size := Vector2i(int(parts[0]), int(parts[1]))
					var screen := DisplayServer.screen_get_usable_rect()
					size = size.min(screen.size)
					DisplayServer.window_set_size(size)
					DisplayServer.window_set_position(screen.position + (screen.size - size) / 2)
		"ui_scale":
			root.content_scale_factor = f("ui_scale")
		"language":
			Localization.apply(s("language"))
		"key_bindings", "pad_deadzone":
			InputSetup.apply(get_value("key_bindings"), f("pad_deadzone"))
