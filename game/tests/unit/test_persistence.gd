extends TestCase
## SaveIO atomic writes, checksum/tamper detection, backup recovery, and
## schema migrations for profile and settings.

const P := "user://test_tmp/save_io.json"


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_tmp")
	SaveIO.delete_all(P)


func test_round_trip() -> void:
	var data := {"a": 1, "b": "text", "c": [1, 2, 3], "d": {"x": true}}
	assert_eq(SaveIO.write_atomic(P, data), OK)
	var res := SaveIO.read_with_recovery(P)
	assert_eq(res["source"], SaveIO.Source.PRIMARY)
	assert_false(res["recovered"])
	assert_eq(int(res["data"]["a"]), 1)
	assert_eq(res["data"]["b"], "text")
	assert_eq((res["data"]["c"] as Array).size(), 3)


func test_second_write_keeps_backup() -> void:
	SaveIO.write_atomic(P, {"v": 1})
	SaveIO.write_atomic(P, {"v": 2})
	assert_true(FileAccess.file_exists(P + SaveIO.BACKUP_SUFFIX), "backup should exist")
	assert_false(FileAccess.file_exists(P + SaveIO.TEMP_SUFFIX), "temp file should be gone")
	assert_eq(int(SaveIO.read_with_recovery(P)["data"]["v"]), 2)


func test_corrupted_primary_recovers_from_backup() -> void:
	SaveIO.write_atomic(P, {"v": 1})
	SaveIO.write_atomic(P, {"v": 2})
	var f := FileAccess.open(P, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	var res := SaveIO.read_with_recovery(P)
	assert_eq(res["source"], SaveIO.Source.BACKUP)
	assert_true(res["recovered"], "recovery should be reported")
	assert_eq(int(res["data"]["v"]), 1)


func test_tampered_payload_is_rejected() -> void:
	SaveIO.write_atomic(P, {"coins": 10})
	var text := FileAccess.get_file_as_string(P)
	var tampered := text.replace("10", "99999")
	var f := FileAccess.open(P, FileAccess.WRITE)
	f.store_string(tampered)
	f.close()
	assert_eq(SaveIO.decode(tampered), null, "checksum mismatch must be detected")
	var res := SaveIO.read_with_recovery(P)
	assert_eq(res["source"], SaveIO.Source.NONE)
	assert_true(res["recovered"])


func test_missing_file() -> void:
	var res := SaveIO.read_with_recovery("user://test_tmp/does_not_exist.json")
	assert_eq(res["source"], SaveIO.Source.NONE)
	assert_false(res["recovered"])
	assert_eq(res["data"], null)


func test_profile_migration_from_v0() -> void:
	var v0 := {"name": "Ada", "coins": 75, "completed": ["house"]}
	var migrated: Dictionary = Saves.migrate(v0)
	assert_eq(int(migrated["schema_version"]), 1)
	assert_eq(migrated["profile"]["display_name"], "Ada")
	assert_true(str(migrated["profile"]["local_id"]).length() >= 16)
	assert_eq(int(migrated["wallet"]["balance"]), 75)
	assert_true(bool(migrated["progress"]["maps"]["house"]["completed"]))


func test_profile_migration_negative_coins_clamped() -> void:
	var migrated: Dictionary = Saves.migrate({"name": "X", "coins": -500})
	assert_eq(int(migrated["wallet"]["balance"]), 0)


func test_current_schema_is_untouched() -> void:
	var v1 := {"schema_version": 1, "profile": {"display_name": "B", "local_id": "0123456789abcdef0"}, "progress": {"maps": {}}, "wallet": {}}
	var out: Dictionary = Saves.migrate(v1)
	assert_eq(out["profile"]["display_name"], "B")


func test_profile_persists_through_reload() -> void:
	Saves.set_display_name("  Night   Owl ")
	Saves.set_avatar_color(3)
	Saves.load_profile()
	assert_eq(Saves.display_name(), "Night Owl")
	assert_eq(Saves.avatar_color_index(), 3)


func test_invalid_stored_name_is_cleared() -> void:
	Saves.data["profile"]["display_name"] = "[b]bad[/b]"
	Saves.save()
	Saves.load_profile()
	assert_eq(Saves.display_name(), "")
