class_name SaveIO
extends RefCounted
## Atomic JSON persistence with checksum and one rolling backup.
##
## File layout: {"format": "method-save", "checksum": <sha256 hex>, "payload": "<json text>"}
## The checksum detects corruption and casual edits. It is not a security
## boundary: local saves are always tamperable (see docs/economy.md).

const FORMAT_TAG := "method-save"
const BACKUP_SUFFIX := ".bak"
const TEMP_SUFFIX := ".tmp"

enum Source { PRIMARY, BACKUP, NONE }


static func sha256_text(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	return ctx.finish().hex_encode()


static func encode(data: Dictionary) -> String:
	var payload := JSON.stringify(data)
	var envelope := {"format": FORMAT_TAG, "checksum": sha256_text(payload), "payload": payload}
	return JSON.stringify(envelope, "\t")


## Returns the decoded payload, or null if the text is corrupt or tampered.
static func decode(text: String) -> Variant:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return null
	var envelope: Dictionary = parsed
	if envelope.get("format", "") != FORMAT_TAG:
		return null
	var payload: Variant = envelope.get("payload")
	if not payload is String:
		return null
	if sha256_text(payload) != str(envelope.get("checksum", "")):
		return null
	var data: Variant = JSON.parse_string(payload)
	if not data is Dictionary:
		return null
	return data


static func write_atomic(path: String, data: Dictionary) -> Error:
	var tmp_path := path + TEMP_SUFFIX
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(encode(data))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return write_error
	# Keep the previous good file as a backup before replacing it.
	if FileAccess.file_exists(path):
		var bak_path := path + BACKUP_SUFFIX
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		var bak_err := DirAccess.rename_absolute(path, bak_path)
		if bak_err != OK:
			return bak_err
	return DirAccess.rename_absolute(tmp_path, path)


## Reads `path`, falling back to its backup. Result keys: data, source, recovered.
static func read_with_recovery(path: String) -> Dictionary:
	var primary: Variant = _read_file(path)
	if primary != null:
		return {"data": primary, "source": Source.PRIMARY, "recovered": false}
	var primary_existed := FileAccess.file_exists(path)
	var backup: Variant = _read_file(path + BACKUP_SUFFIX)
	if backup != null:
		return {"data": backup, "source": Source.BACKUP, "recovered": primary_existed}
	return {
		"data": null,
		"source": Source.NONE,
		"recovered": primary_existed or FileAccess.file_exists(path + BACKUP_SUFFIX),
	}


static func delete_all(path: String) -> void:
	for p in [path, path + BACKUP_SUFFIX, path + TEMP_SUFFIX]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)


static func _read_file(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return null
	return decode(text)
