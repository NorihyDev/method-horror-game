class_name OverlayPanel
extends Control
## Base for in-game overlays (pause, inventory, note, keypad, death).
## Overlays take input focus, release the mouse and close on Back.

signal closed

var panel: PanelContainer
var body: VBoxContainer
var screen: Node
var closable := true


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	panel = UI.panel(28)
	cc.add_child(panel)
	body = UI.vbox(14)
	panel.add_child(body)
	build()
	_focus_first.call_deferred()


## Override to fill `body`.
func build() -> void:
	pass


func close() -> void:
	closed.emit()
	queue_free()


func handle_back() -> bool:
	if closable:
		AudioService.play_ui("ui_back")
		close()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		handle_back()


func _focus_first() -> void:
	var f := _find(self)
	if f:
		f.grab_focus()


func _find(n: Node) -> Control:
	for c in n.get_children():
		if c is BaseButton and (c as BaseButton).visible and not (c as BaseButton).disabled:
			return c
		var nested := _find(c)
		if nested:
			return nested
	return null


func header(title_key: String) -> void:
	body.add_child(UI.heading(title_key))
	body.add_child(UI.accent_bar())
