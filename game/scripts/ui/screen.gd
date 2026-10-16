class_name Screen
extends Control
## Base class for full-screen UI states managed by App.

var app: App
var params: Dictionary = {}
## Gameplay screens let unhandled input through to the world.
var passes_input := false
var _built := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


## Override to construct the UI. Called once before the first enter.
func build() -> void:
	pass


## Called each time the screen becomes visible.
func on_enter(_params: Dictionary) -> void:
	pass


func on_exit() -> void:
	pass


## Return true if the back request was consumed.
func handle_back() -> bool:
	return false


## Builds a full-rect container honoring the device safe area.
func safe_root(extra: int = 32) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margins := app.safe_margins() if app else Vector4.ZERO
	m.add_theme_constant_override("margin_left", int(margins.x) + extra)
	m.add_theme_constant_override("margin_top", int(margins.y) + extra * 3 / 4)
	m.add_theme_constant_override("margin_right", int(margins.z) + extra)
	m.add_theme_constant_override("margin_bottom", int(margins.w) + extra * 3 / 4)
	add_child(m)
	return m


func ensure_built() -> void:
	if not _built:
		_built = true
		build()


## Focuses the first focusable control for keyboard/controller users.
func focus_first(root: Control = null) -> void:
	var start := root if root else self
	var found := _find_focusable(start)
	if found:
		found.grab_focus.call_deferred()


func _find_focusable(node: Node) -> Control:
	for child in node.get_children():
		if child is Control and child.visible:
			var c: Control = child
			if c.focus_mode == Control.FOCUS_ALL and not (c is BaseButton and (c as BaseButton).disabled):
				return c
			var nested := _find_focusable(c)
			if nested:
				return nested
	return null
