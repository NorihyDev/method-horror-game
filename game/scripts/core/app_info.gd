class_name AppInfo
extends RefCounted
## Static build and platform facts. Keep this free of state.

const GAME_TITLE := "METHOD HORROR"
const STUDIO := "METHOD"
const ENGINE_VERSION := "4.7.2-stable"
## Bump whenever RPC signatures or snapshot layouts change.
const PROTOCOL_VERSION := 1
const SAVE_SCHEMA_VERSION := 1
const SETTINGS_SCHEMA_VERSION := 1


static func version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))


static func is_dev_build() -> bool:
	return OS.is_debug_build()


static func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.get_name() == "Android" or OS.get_name() == "iOS"


static func is_desktop() -> bool:
	return not is_mobile() and not is_headless()


static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


static func is_dedicated_server() -> bool:
	return OS.has_feature("dedicated_server") or has_arg("--server")


static func has_arg(arg_name: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg == arg_name or arg.begins_with(arg_name + "="):
			return true
	return false


static func arg_value(arg_name: String, default_value: String = "") -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(arg_name + "="):
			return arg.substr(arg_name.length() + 1)
	return default_value


## Automated runs (tests, smoke, screenshot and --script tools, bots) and
## dedicated servers use separate test_* save files so they never touch a
## player's real profile.
static func uses_isolated_storage() -> bool:
	for flag in ["--test", "--autoshot", "--uishots", "--smoke", "--bot", "--server"]:
		if has_arg(flag):
			return true
	var args := OS.get_cmdline_args()
	return args.has("--script") or args.has("-s")


static func touch_available() -> bool:
	return DisplayServer.is_touchscreen_available()
