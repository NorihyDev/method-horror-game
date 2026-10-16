class_name Localization
extends RefCounted
## Loads JSON string tables from res://localization/<locale>.json into the
## TranslationServer. JSON keeps the tables diff-friendly and avoids generated
## .translation import artifacts.

const SUPPORTED: PackedStringArray = ["en", "fr"]
const FALLBACK := "en"

static var _loaded := false


static func load_all() -> void:
	if _loaded:
		return
	for locale in SUPPORTED:
		var path := "res://localization/%s.json" % locale
		var text := FileAccess.get_file_as_string(path)
		var parsed: Variant = JSON.parse_string(text)
		if not parsed is Dictionary:
			Log.error("i18n", "Missing or invalid string table", {"path": path})
			continue
		var translation := Translation.new()
		translation.locale = locale
		var table: Dictionary = parsed
		for key in table:
			translation.add_message(StringName(key), StringName(str(table[key])))
		TranslationServer.add_translation(translation)
	_loaded = true


static func resolve_locale(preference: String) -> String:
	if preference in SUPPORTED:
		return preference
	var os_lang := OS.get_locale_language()
	if os_lang in SUPPORTED:
		return os_lang
	return FALLBACK


static func apply(preference: String) -> void:
	load_all()
	TranslationServer.set_locale(resolve_locale(preference))
