class_name Log
extends RefCounted
## Structured, redacting logger. Never pass raw secrets in messages; put
## context in `data` so sensitive keys are redacted automatically.

enum Level { DEBUG, INFO, WARN, ERROR }

const REDACTED := "[redacted]"
const SENSITIVE_KEYS: PackedStringArray = [
	"token",
	"ticket",
	"password",
	"secret",
	"session",
	"authorization",
	"key",
	"signature",
]

static var min_level: Level = Level.INFO


static func debug(scope: String, message: String, data: Dictionary = {}) -> void:
	_emit(Level.DEBUG, scope, message, data)


static func info(scope: String, message: String, data: Dictionary = {}) -> void:
	_emit(Level.INFO, scope, message, data)


static func warn(scope: String, message: String, data: Dictionary = {}) -> void:
	_emit(Level.WARN, scope, message, data)


static func error(scope: String, message: String, data: Dictionary = {}) -> void:
	_emit(Level.ERROR, scope, message, data)


static func redact(data: Dictionary) -> Dictionary:
	var out := {}
	for key in data:
		var lowered := str(key).to_lower()
		var sensitive := false
		for marker in SENSITIVE_KEYS:
			if lowered.contains(marker):
				sensitive = true
				break
		if sensitive:
			out[key] = REDACTED
		elif data[key] is Dictionary:
			out[key] = redact(data[key])
		else:
			out[key] = data[key]
	return out


static func _emit(level: Level, scope: String, message: String, data: Dictionary) -> void:
	if level < min_level:
		return
	var line := "[%s] %s: %s" % [Level.keys()[level], scope, message]
	if not data.is_empty():
		line += " " + JSON.stringify(redact(data))
	match level:
		Level.ERROR:
			push_error(line)
			printerr(line)
		Level.WARN:
			push_warning(line)
			print(line)
		_:
			print(line)
