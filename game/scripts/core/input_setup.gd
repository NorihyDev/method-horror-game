class_name InputSetup
extends RefCounted
## Declares gameplay input actions and default bindings in code so keyboard
## rebinding, controller defaults, and touch controls share one source.

const REBINDABLE: PackedStringArray = [
	"move_forward",
	"move_back",
	"move_left",
	"move_right",
	"sprint",
	"crouch",
	"interact",
	"flashlight",
	"inventory",
	"ping",
]

const DEFAULT_KEYS := {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"sprint": KEY_SHIFT,
	"crouch": KEY_C,
	"interact": KEY_E,
	"flashlight": KEY_F,
	"inventory": KEY_TAB,
	"ping": KEY_Q,
	"pause": KEY_ESCAPE,
}

const ALT_KEYS := {
	"move_forward": KEY_UP,
	"move_back": KEY_DOWN,
	"move_left": KEY_LEFT,
	"move_right": KEY_RIGHT,
	"crouch": KEY_CTRL,
	"inventory": KEY_I,
	"pause": KEY_P,
}

const PAD_BUTTONS := {
	"interact": JOY_BUTTON_A,
	"crouch": JOY_BUTTON_B,
	"inventory": JOY_BUTTON_X,
	"flashlight": JOY_BUTTON_Y,
	"sprint": JOY_BUTTON_LEFT_STICK,
	"ping": JOY_BUTTON_RIGHT_SHOULDER,
	"pause": JOY_BUTTON_START,
}

## action -> [axis, direction]
const PAD_AXES := {
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0],
	"move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"move_left": [JOY_AXIS_LEFT_X, -1.0],
	"move_right": [JOY_AXIS_LEFT_X, 1.0],
	"look_up": [JOY_AXIS_RIGHT_Y, -1.0],
	"look_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"look_left": [JOY_AXIS_RIGHT_X, -1.0],
	"look_right": [JOY_AXIS_RIGHT_X, 1.0],
	"sprint": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}

const ALL_ACTIONS: PackedStringArray = [
	"move_forward",
	"move_back",
	"move_left",
	"move_right",
	"look_up",
	"look_down",
	"look_left",
	"look_right",
	"sprint",
	"crouch",
	"interact",
	"flashlight",
	"inventory",
	"ping",
	"pause",
]


## (Re)creates all gameplay actions. `custom_keys` maps action -> physical keycode.
static func apply(custom_keys: Dictionary, deadzone: float) -> void:
	for action in ALL_ACTIONS:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
		InputMap.add_action(action, deadzone)
		var key: int = int(custom_keys.get(action, DEFAULT_KEYS.get(action, KEY_NONE)))
		if key != KEY_NONE:
			_add_key(action, key)
		if ALT_KEYS.has(action) and int(ALT_KEYS[action]) != key:
			_add_key(action, ALT_KEYS[action])
		if PAD_BUTTONS.has(action):
			var jb := InputEventJoypadButton.new()
			jb.button_index = PAD_BUTTONS[action]
			InputMap.action_add_event(action, jb)
		if PAD_AXES.has(action):
			var jm := InputEventJoypadMotion.new()
			jm.axis = PAD_AXES[action][0]
			jm.axis_value = PAD_AXES[action][1]
			InputMap.action_add_event(action, jm)


static func key_for(action: String, custom_keys: Dictionary) -> int:
	return int(custom_keys.get(action, DEFAULT_KEYS.get(action, KEY_NONE)))


static func key_label(keycode: int) -> String:
	if keycode == KEY_NONE:
		return "—"
	# Keys are bound by position: show what that key prints on this keyboard
	# (Z/Q on AZERTY, not W/A).
	if DisplayServer.get_name() != "headless":
		var shown := DisplayServer.keyboard_get_label_from_physical(keycode as Key)
		if shown != KEY_NONE:
			return OS.get_keycode_string(shown)
	return OS.get_keycode_string(keycode)


## Returns the action already using `keycode`, or "" if free.
static func conflict_for(keycode: int, action: String, custom_keys: Dictionary) -> String:
	for other in REBINDABLE:
		if other != action and key_for(other, custom_keys) == keycode:
			return other
	return ""


static func _add_key(action: String, keycode: int) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)
