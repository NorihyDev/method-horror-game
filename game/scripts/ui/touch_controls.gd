class_name TouchControls
extends Control
## On-screen controls with real multitouch: every finger is tracked by its
## index, so moving, looking and pressing buttons work at the same time.
## Touches on buttons never rotate the camera, and the look area ignores
## fingers that started on a button.

signal pressed(button: String)
signal released(button: String)

## name -> [default normalized position (right-handed), radius px, label key]
const BUTTONS := {
	"interact": [Vector2(0.86, 0.66), 64.0, "TOUCH_USE"],
	"sprint": [Vector2(0.73, 0.82), 44.0, "TOUCH_RUN"],
	"crouch": [Vector2(0.94, 0.42), 40.0, "TOUCH_CROUCH"],
	"flashlight": [Vector2(0.94, 0.24), 36.0, "TOUCH_LIGHT"],
	"inventory": [Vector2(0.73, 0.52), 38.0, "TOUCH_BAG"],
	"pause": [Vector2(0.96, 0.07), 28.0, "TOUCH_PAUSE"],
	"ping": [Vector2(0.84, 0.24), 32.0, "TOUCH_PING"],
}
const JOY_RADIUS := 86.0
const JOY_DEFAULT := Vector2(0.15, 0.7)

var enabled_buttons: PackedStringArray = ["interact", "sprint", "crouch", "flashlight", "inventory", "pause"]
var highlight_interact := false:
	set(v):
		if v != highlight_interact:
			highlight_interact = v
			queue_redraw()
var editing := false

var _held: Dictionary = {}
## finger index -> "joy" | "look" | button name
var _fingers: Dictionary = {}
var _joy_origin := Vector2.ZERO
var _joy_pos := Vector2.ZERO
var _joy_finger := -1
var _look_accum := Vector2.ZERO
var _layout: Dictionary = {}


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_layout = Settings.get_value("touch_layout")
	Settings.changed.connect(
		func(k: String, _v: Variant) -> void:
			if k.begins_with("touch_") or k == "left_handed" or k == "joystick_mode":
				_layout = Settings.get_value("touch_layout")
				queue_redraw()
	)


## Whether on-screen controls should show on this device.
static func should_show() -> bool:
	match Settings.s("touch_controls"):
		"on":
			return true
		"off":
			return false
	return AppInfo.touch_available() and AppInfo.is_mobile()


func move_vector() -> Vector2:
	if _joy_finger < 0:
		return Vector2.ZERO
	var v := (_joy_pos - _joy_origin) / (JOY_RADIUS * _scale())
	var dz := Settings.f("joystick_deadzone")
	var l := v.length()
	if l < dz:
		return Vector2.ZERO
	return v.normalized() * clampf((l - dz) / (1.0 - dz), 0.0, 1.0)


func consume_look() -> Vector2:
	var d := _look_accum
	_look_accum = Vector2.ZERO
	return d


func is_held(button: String) -> bool:
	return bool(_held.get(button, false))


func release_all() -> void:
	for b in _held.keys():
		if _held[b]:
			released.emit(b)
	_held.clear()
	_fingers.clear()
	_joy_finger = -1
	_look_accum = Vector2.ZERO
	queue_redraw()


func _scale() -> float:
	return Settings.f("touch_button_scale")


func button_center(button: String) -> Vector2:
	var vp := get_viewport_rect().size
	var n: Vector2 = BUTTONS[button][0]
	if _layout.has(button):
		var saved: Variant = _layout[button]
		if saved is Array and saved.size() == 2:
			n = Vector2(float(saved[0]), float(saved[1]))
	if Settings.b("left_handed"):
		n.x = 1.0 - n.x
	var m := Session.app.safe_margins() if Session.app else Vector4.ZERO
	var area := Rect2(Vector2(m.x, m.y), vp - Vector2(m.x + m.z, m.y + m.w))
	return area.position + n * area.size


func button_radius(button: String) -> float:
	return float(BUTTONS[button][1]) * _scale()


func joystick_home() -> Vector2:
	var vp := get_viewport_rect().size
	var n := JOY_DEFAULT
	if Settings.b("left_handed"):
		n.x = 1.0 - n.x
	return n * vp


func _in_move_zone(p: Vector2) -> bool:
	var half := get_viewport_rect().size.x * 0.45
	return p.x > get_viewport_rect().size.x - half if Settings.b("left_handed") else p.x < half


func _button_at(p: Vector2) -> String:
	for b in enabled_buttons:
		if p.distance_to(button_center(b)) <= button_radius(b) * 1.15:
			return b
	return ""


func _input(event: InputEvent) -> void:
	if not visible or editing:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var b := _button_at(t.position)
			if not b.is_empty():
				_fingers[t.index] = b
				_held[b] = true
				pressed.emit(b)
				if b != "pause":
					_vibrate_light()
			elif _in_move_zone(t.position):
				_fingers[t.index] = "joy"
				_joy_finger = t.index
				_joy_origin = t.position if Settings.s("joystick_mode") == "floating" else joystick_home()
				_joy_pos = t.position
			else:
				_fingers[t.index] = "look"
			get_viewport().set_input_as_handled()
			queue_redraw()
		else:
			var role: String = _fingers.get(t.index, "")
			_fingers.erase(t.index)
			if role == "joy":
				_joy_finger = -1
			elif not role.is_empty() and role != "look":
				_held[role] = false
				released.emit(role)
			if not role.is_empty():
				get_viewport().set_input_as_handled()
			queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		var role: String = _fingers.get(d.index, "")
		if role == "joy":
			_joy_pos = d.position
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif role == "look":
			_look_accum += d.screen_relative
			get_viewport().set_input_as_handled()


func _vibrate_light() -> void:
	var k := Settings.f("haptics")
	if k > 0.05 and AppInfo.is_mobile():
		Input.vibrate_handheld(int(20 * k), 0.3 * k)


func _draw() -> void:
	var alpha := Settings.f("touch_opacity")
	var font := get_theme_default_font()
	# Joystick
	var base := _joy_origin if _joy_finger >= 0 else joystick_home()
	var r := JOY_RADIUS * _scale()
	draw_circle(base, r, Color(0, 0, 0, 0.25 * alpha))
	draw_arc(base, r, 0, TAU, 40, Color(ThemeFactory.TEXT, 0.45 * alpha), 2.0, true)
	var knob := base
	if _joy_finger >= 0:
		knob = base + (_joy_pos - base).limit_length(r)
	draw_circle(knob, r * 0.42, Color(ThemeFactory.TEXT, 0.35 * alpha))
	# Buttons
	for b in enabled_buttons:
		var c := button_center(b)
		var br := button_radius(b)
		var held := is_held(b)
		var fill := Color(ThemeFactory.CRIMSON, 0.55 * alpha) if held else Color(0, 0, 0, 0.35 * alpha)
		if b == "interact" and highlight_interact and not held:
			fill = Color(ThemeFactory.CRIMSON, 0.4 * alpha + 0.2)
		draw_circle(c, br, fill)
		draw_arc(c, br, 0, TAU, 36, Color(ThemeFactory.TEXT, 0.6 * alpha), 2.0, true)
		var label := tr(str(BUTTONS[b][2]))
		var fs := int(clampf(br * 0.36, 13, 22))
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(
			font,
			c + Vector2(-w * 0.5, fs * 0.35),
			label,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			fs,
			Color(ThemeFactory.TEXT, minf(1.0, alpha + 0.3))
		)


func _process(_delta: float) -> void:
	if editing:
		queue_redraw()
