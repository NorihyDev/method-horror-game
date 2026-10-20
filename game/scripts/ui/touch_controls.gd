class_name TouchControls
extends Control
## On-screen controls with real multitouch: every finger is tracked by its
## index, so moving, looking and pressing buttons work at the same time.
## Touches on buttons never rotate the camera, and the look area ignores
## fingers that started on a button.

signal pressed(button: String)
signal released(button: String)

## name -> [default offset (px, right-handed) in from the bottom-right corner
## of the safe area (top-right for pause), radius px, label key].
## The defaults form an arc the right thumb sweeps without stretching: USE
## where the thumb rests, RUN and DUCK one short reach away, LIGHT and BAG
## above, so the middle of the right half stays free for looking around.
const BUTTONS := {
	"interact": [Vector2(132, 150), 66.0, "TOUCH_USE"],
	"sprint": [Vector2(240, 268), 46.0, "TOUCH_RUN"],
	"crouch": [Vector2(292, 128), 46.0, "TOUCH_CROUCH"],
	"flashlight": [Vector2(84, 318), 42.0, "TOUCH_LIGHT"],
	"inventory": [Vector2(76, 446), 40.0, "TOUCH_BAG"],
	"pause": [Vector2(52, 46), 30.0, "TOUCH_PAUSE"],
	"ping": [Vector2(196, 400), 36.0, "TOUCH_PING"],
}
const TOP_ANCHORED: Array[String] = ["pause"]
const JOY_RADIUS := 86.0
## Joystick home, in from the bottom-left corner of the safe area.
const JOY_OFFSET := Vector2(200, 210)
## Pushing the stick this far past its ring runs (no button needed).
const AUTO_RUN_AT := 1.18
## Finger slop around buttons: thumbs land off-centre.
const HIT_SLOP := 1.3

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
var _auto_run := false


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


## The stick is pushed past its ring: run while it stays there.
func auto_sprint() -> bool:
	return _auto_run


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
	_auto_run = false
	_look_accum = Vector2.ZERO
	queue_redraw()


func _scale() -> float:
	return Settings.f("touch_button_scale")


func _safe_area() -> Rect2:
	var vp := get_viewport_rect().size
	var m := Session.app.safe_margins() if Session.app else Vector4.ZERO
	return Rect2(Vector2(m.x, m.y), vp - Vector2(m.x + m.z, m.y + m.w))


func button_center(button: String) -> Vector2:
	var area := _safe_area()
	if _layout.has(button):
		var saved: Variant = _layout[button]
		if saved is Array and saved.size() == 2:
			var n := Vector2(float(saved[0]), float(saved[1]))
			if Settings.b("left_handed"):
				n.x = 1.0 - n.x
			return area.position + n * area.size
	# Defaults keep their distance from the corner (in px, scaled with the
	# buttons) so wide phones don't stretch the arc out of the thumb's reach.
	var off: Vector2 = BUTTONS[button][0] * lerpf(1.0, _scale(), 0.8)
	var x := area.end.x - off.x
	if Settings.b("left_handed"):
		x = area.position.x + off.x
	var y := area.position.y + off.y if button in TOP_ANCHORED else area.end.y - off.y
	var c := Vector2(x, y)
	if button not in TOP_ANCHORED:
		# On short screens (or big buttons) the upper ones reach the pause
		# button: slide them inward until they clear it.
		var p := button_center("pause")
		var gap := button_radius("pause") + button_radius(button) + 10.0
		if c.distance_to(p) < gap:
			var dy := absf(c.y - p.y)
			var dx := sqrt(maxf(gap * gap - dy * dy, 0.0))
			c.x = p.x + dx if Settings.b("left_handed") else p.x - dx
	return c


func button_radius(button: String) -> float:
	return float(BUTTONS[button][1]) * _scale()


func joystick_home() -> Vector2:
	var area := _safe_area()
	var off := JOY_OFFSET * lerpf(1.0, _scale(), 0.8)
	var x := area.end.x - off.x if Settings.b("left_handed") else area.position.x + off.x
	return Vector2(x, area.end.y - off.y)


func _in_move_zone(p: Vector2) -> bool:
	var half := get_viewport_rect().size.x * 0.45
	return p.x > get_viewport_rect().size.x - half if Settings.b("left_handed") else p.x < half


## The nearest enabled button whose (generous) circle contains `p`.
func _button_at(p: Vector2) -> String:
	var best := ""
	var best_d := INF
	for b in enabled_buttons:
		var d := p.distance_to(button_center(b)) / button_radius(b)
		if d <= HIT_SLOP and d < best_d:
			best = b
			best_d = d
	return best


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
				_auto_run = false
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
			var run := (_joy_pos - _joy_origin).length() > JOY_RADIUS * _scale() * AUTO_RUN_AT
			if run != _auto_run:
				_auto_run = run
				if run:
					_vibrate_light()
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
	# Direction arrows round the ring: this is for moving.
	if _joy_finger < 0:
		var tip_col := Color(ThemeFactory.TEXT, 0.5 * alpha)
		for k in 4:
			var d := Vector2.from_angle(k * PI / 2.0)
			var tip := base + d * r * 0.8
			var side := d.orthogonal() * r * 0.09
			draw_colored_polygon(
				PackedVector2Array([tip, tip - d * r * 0.13 + side, tip - d * r * 0.13 - side]), tip_col
			)
	# Auto-run: an outer ring shows where pushing past starts running.
	var run_r := r * AUTO_RUN_AT
	var run_col := (
		Color(ThemeFactory.CRIMSON, 0.75 * alpha + 0.2) if _auto_run else Color(ThemeFactory.TEXT, 0.12 * alpha)
	)
	draw_arc(base, run_r, -PI * 0.85, -PI * 0.15, 24, run_col, 4.0 if _auto_run else 2.0, true)
	if _auto_run:
		var run_label := tr("TOUCH_RUN")
		var rw := font.get_string_size(run_label, HORIZONTAL_ALIGNMENT_CENTER, -1, 16).x
		draw_string(
			font,
			base + Vector2(-rw * 0.5, -run_r - 10),
			run_label,
			HORIZONTAL_ALIGNMENT_CENTER,
			-1,
			16,
			Color(ThemeFactory.TEXT, 0.9)
		)
	# Buttons: a dark disc, an icon, and a small label under it.
	for b in enabled_buttons:
		var c := button_center(b)
		var br := button_radius(b)
		var held := is_held(b)
		var fill := Color(ThemeFactory.CRIMSON, 0.6 * alpha + 0.1) if held else Color(0.03, 0.03, 0.035, 0.42 * alpha)
		var ring := Color(ThemeFactory.TEXT, 0.55 * alpha)
		if b == "interact" and highlight_interact and not held:
			# Something usable is in front of you: the USE button glows.
			var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0)
			fill = Color(ThemeFactory.CRIMSON, (0.35 + 0.2 * pulse) * alpha + 0.15)
			ring = Color(ThemeFactory.CRIMSON.lightened(0.4), 0.9)
		draw_circle(c, br, fill)
		draw_arc(c, br, 0, TAU, 40, ring, 2.5 if held else 2.0, true)
		var ink := Color(ThemeFactory.TEXT, minf(1.0, alpha + 0.35))
		var small := b == "pause"
		var icon_s := br * (0.5 if small else (0.36 if b == "interact" else 0.46))
		TouchIcons.draw(self, b, c + Vector2(0, 0 if small else -br * 0.14), icon_s, ink)
		if small:
			continue
		var label := tr(str(BUTTONS[b][2]))
		var fs := int(clampf(br * 0.22, 10, 15))
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(
			font, c + Vector2(-w * 0.5, br * 0.7), label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs, Color(ink, ink.a * 0.85)
		)


func _process(_delta: float) -> void:
	if editing or highlight_interact:
		queue_redraw()
