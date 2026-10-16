class_name Hud
extends Control
## Minimal gameplay HUD. Elements appear only when relevant and stay clear of
## touch controls and the safe area. Status is never conveyed by color alone:
## bars carry labels/percentages and states have text.

var player: PlayerController
var match_ctrl: MatchController
var touch_mode := false

var _reticle: Reticle
var _prompt: Label
var _objective_box: VBoxContainer
var _objective_title: Label
var _objective_list: VBoxContainer
var _hint_badge: Label
var _feed: VBoxContainer
var _stamina: ProgressBar
var _stamina_box: Control
var _battery: ProgressBar
var _battery_label: Label
var _battery_box: Control
var _battery_show_time := 0.0
var _hotbar: HBoxContainer
var _slots: Array[ItemIcon] = []
var _gauge: CrankGauge
var _status_label: Label
var _focus: Interactable
var _hint_new := false


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(p_player: PlayerController, p_match: MatchController, p_touch: bool) -> void:
	player = p_player
	match_ctrl = p_match
	touch_mode = p_touch
	_build()
	player.focus_changed.connect(_on_focus)
	player.hold_progress_changed.connect(func(v: float) -> void: _reticle.progress = v)
	player.stamina_changed.connect(_on_stamina)
	player.battery_changed.connect(_on_battery)
	match_ctrl.notified.connect(push_notice)
	match_ctrl.objectives_changed.connect(_refresh_objectives)
	match_ctrl.hint_unlocked.connect(func(_id: String, _tier: int) -> void:
		_hint_new = true
		_refresh_objectives())
	match_ctrl.inventory_changed.connect(func(pid: int) -> void:
		if pid == player.player_id:
			_refresh_inventory()
			player.refresh_focus())
	match_ctrl.entity_changed.connect(func(_id: String, _s: Dictionary) -> void: player.refresh_focus())
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "ui_scale" or k == "high_contrast":
			_reticle.queue_redraw())
	_refresh_objectives()
	_refresh_inventory()


func _build() -> void:
	var m := Session.app.safe_margins() if Session.app else Vector4.ZERO
	var pad := 24.0
	# Reticle + prompt (center).
	_reticle = Reticle.new()
	_reticle.set_anchors_preset(Control.PRESET_CENTER)
	_reticle.custom_minimum_size = Vector2(64, 64)
	_reticle.size = Vector2(64, 64)
	_reticle.position = -_reticle.size * 0.5
	add_child(_reticle)
	_prompt = UI.label("", ThemeFactory.FONT_BODY)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.set_anchors_preset(Control.PRESET_CENTER)
	_prompt.size = Vector2(600, 40)
	_prompt.position = Vector2(-300, 40)
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	add_child(_prompt)
	# Objectives (top-left).
	_objective_box = UI.vbox(4)
	_objective_box.position = Vector2(m.x + pad, m.y + pad)
	_objective_box.custom_minimum_size.x = 380
	_objective_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_objective_box)
	var cap := UI.caption("HUD_OBJECTIVE")
	_objective_box.add_child(cap)
	_objective_title = UI.label("", ThemeFactory.FONT_BODY + 2)
	_objective_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_objective_title.custom_minimum_size.x = 380
	_objective_title.add_theme_constant_override("outline_size", 5)
	_objective_title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_objective_box.add_child(_objective_title)
	_objective_list = UI.vbox(2)
	_objective_box.add_child(_objective_list)
	_hint_badge = UI.label("HUD_HINT_AVAILABLE", ThemeFactory.FONT_SMALL, ThemeFactory.WARN)
	_hint_badge.visible = false
	_objective_box.add_child(_hint_badge)
	# Notification feed (under objectives).
	_feed = UI.vbox(4)
	_feed.position = Vector2(m.x + pad, m.y + 170)
	_feed.custom_minimum_size.x = 420
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)
	# Status line (escaped / downed) center-top.
	_status_label = UI.label("", ThemeFactory.FONT_H2)
	_status_label.add_theme_font_override("font", ThemeFactory.title_font())
	_status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.size = Vector2(800, 50)
	_status_label.position = Vector2(-400, m.y + 80)
	add_child(_status_label)
	# Stamina (bottom center, above hotbar).
	_stamina_box = _bar_box("HUD_STAMINA")
	_stamina = _stamina_box.get_meta("bar")
	add_child(_stamina_box)
	_stamina_box.visible = false
	# Battery (bottom-left on desktop, top-right-ish on touch to avoid the joystick).
	_battery_box = _bar_box("HUD_BATTERY")
	_battery = _battery_box.get_meta("bar")
	_battery_label = _battery_box.get_meta("value")
	add_child(_battery_box)
	_battery_box.visible = false
	# Hotbar.
	_hotbar = UI.hbox(6)
	_hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hotbar)
	for i in Inventory.DEFAULT_CAPACITY:
		var icon := ItemIcon.new()
		icon.custom_minimum_size = Vector2(54, 54)
		_hotbar.add_child(icon)
		_slots.append(icon)
	# Crank gauge.
	_gauge = CrankGauge.new()
	_gauge.visible = false
	_gauge.set_anchors_preset(Control.PRESET_CENTER)
	_gauge.size = Vector2(320, 70)
	_gauge.position = Vector2(-160, 90)
	add_child(_gauge)
	_layout()


func _bar_box(label_key: String) -> Control:
	var box := UI.hbox(8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UI.caption(label_key)
	l.custom_minimum_size.x = 90
	box.add_child(l)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(180, 10)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(bar)
	var value := UI.label("", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_DIM)
	value.custom_minimum_size.x = 48
	box.add_child(value)
	box.set_meta("bar", bar)
	box.set_meta("value", value)
	return box


func _layout() -> void:
	var vp := get_viewport_rect().size
	var m := Session.app.safe_margins() if Session.app else Vector4.ZERO
	var hotbar_w := _slots.size() * 60.0
	if touch_mode:
		# Keep the hotbar top-center, away from thumbs and system gestures.
		_hotbar.position = Vector2((vp.x - hotbar_w) * 0.5, m.y + 14)
		_stamina_box.position = Vector2((vp.x - 330) * 0.5, m.y + 80)
		_battery_box.position = Vector2((vp.x - 330) * 0.5, m.y + 104)
	else:
		_hotbar.position = Vector2((vp.x - hotbar_w) * 0.5, vp.y - m.w - 78)
		_stamina_box.position = Vector2((vp.x - 330) * 0.5, vp.y - m.w - 108)
		_battery_box.position = Vector2(m.x + 24, vp.y - m.w - 46)


func _process(delta: float) -> void:
	_layout()
	if _battery_show_time > 0.0:
		_battery_show_time -= delta
	_battery_box.visible = player != null and (_battery_show_time > 0.0 or player.battery < 0.3)
	_gauge.visible = _focus is GarageMotor and (_focus as GarageMotor).is_crank_ready()
	if _gauge.visible:
		var motor := _focus as GarageMotor
		_gauge.needle = GarageMotor.needle_position(motor.needle_phase())
		_gauge.window = motor.window_for(player.player_id)
		_gauge.successes = int(motor.state.get("successes", 0))
	if touch_mode and get_parent().has_method("set_interact_highlight"):
		get_parent().call("set_interact_highlight", not _prompt.text.is_empty())


func _on_focus(prompt: String, ent: Interactable, _sub: int) -> void:
	_focus = ent
	var key_hint := ""
	if not touch_mode and not prompt.is_empty():
		key_hint = "[%s] " % InputSetup.key_label(InputSetup.key_for("interact", Settings.get_value("key_bindings")))
	_prompt.text = key_hint + prompt
	_reticle.focused = not prompt.is_empty()


func _on_stamina(v: float) -> void:
	_stamina.value = v
	(_stamina_box.get_meta("value") as Label).text = "%d%%" % int(v * 100)
	_stamina_box.visible = v < 0.99


func _on_battery(v: float) -> void:
	_battery.value = v
	_battery_label.text = "%d%%" % int(round(v * 100))
	var low := v < 0.15
	_battery.add_theme_stylebox_override("fill", ThemeFactory.flat(ThemeFactory.CRIMSON_HI if low else ThemeFactory.TEXT, Color.TRANSPARENT, 0, 2, 0, 0))
	_battery_show_time = 3.0


func push_notice(text: String) -> void:
	var l := UI.label(text, ThemeFactory.FONT_SMALL + 2)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 420
	l.add_theme_constant_override("outline_size", 5)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_feed.add_child(l)
	while _feed.get_child_count() > 4:
		var old := _feed.get_child(0)
		_feed.remove_child(old)
		old.queue_free()
	var t := l.create_tween()
	t.tween_interval(4.0)
	t.tween_property(l, "modulate:a", 0.0, 0.6)
	t.tween_callback(l.queue_free)


func set_status(text_key: String) -> void:
	_status_label.text = text_key


func _refresh_objectives() -> void:
	if match_ctrl == null:
		return
	var graph := match_ctrl.rules.graph
	var main := graph.active_ids(match_ctrl.state.objectives, false)
	_objective_title.text = match_ctrl.objective_title(graph.get_def(main[0])) if not main.is_empty() else tr("HUD_ALL_DONE")
	for c in _objective_list.get_children():
		c.queue_free()
	for def in graph.defs():
		if not def.optional:
			continue
		var done := graph.is_complete(match_ctrl.state.objectives, def.id)
		if def.complete_flag == "unseen":
			continue
		var text := "• " + match_ctrl.objective_title(def) + ("  — " + tr("HUD_DONE") if done else "")
		var l := UI.label(text, ThemeFactory.FONT_SMALL,
			ThemeFactory.TEXT_FAINT if done else ThemeFactory.TEXT_DIM)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		l.add_theme_constant_override("outline_size", 5)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_objective_list.add_child(l)
	var any_hint := false
	for id in main:
		if match_ctrl.hint_tier(id) > 0:
			any_hint = true
	_hint_badge.visible = any_hint and _hint_new
	_hint_badge.text = tr("HUD_HINT_AVAILABLE_TOUCH") if touch_mode else tr("HUD_HINT_AVAILABLE")


func clear_hint_badge() -> void:
	_hint_new = false
	_hint_badge.visible = false


func _refresh_inventory() -> void:
	var inv := match_ctrl.inventory(player.player_id)
	for i in _slots.size():
		if inv and i < inv.slots.size():
			_slots[i].item_id = inv.slots[i]["id"]
			_slots[i].count = int(inv.slots[i]["count"])
		else:
			_slots[i].item_id = ""
			_slots[i].count = 0


class Reticle:
	extends Control
	var focused := false:
		set(v):
			focused = v
			queue_redraw()
	var progress := 0.0:
		set(v):
			progress = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var hc := Settings.b("high_contrast")
		if focused:
			var col := Color(1, 1, 1) if hc else ThemeFactory.TEXT
			draw_arc(c, 10.0, 0, TAU, 24, Color(0, 0, 0, 0.6), 4.0, true)
			draw_arc(c, 10.0, 0, TAU, 24, col, 2.0, true)
			if hc:
				draw_arc(c, 14.0, 0, TAU, 24, ThemeFactory.WARN, 2.0, true)
		else:
			draw_circle(c, 2.5 if not hc else 3.5, Color(0, 0, 0, 0.5))
			draw_circle(c, 1.8 if not hc else 2.6, Color(ThemeFactory.TEXT, 0.8))
		if progress > 0.0:
			draw_arc(c, 18.0, -PI / 2, -PI / 2 + TAU * progress, 32, ThemeFactory.CRIMSON_HI, 4.0, true)


class CrankGauge:
	extends Control
	var needle := 0.0
	var window := 0.16
	var successes := 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_d: float) -> void:
		if visible:
			queue_redraw()

	func _draw() -> void:
		var r := Rect2(Vector2(0, 18), Vector2(size.x, 22))
		draw_rect(r, Color(0, 0, 0, 0.7))
		var w := r.size.x * window
		var zone := Rect2(Vector2(r.position.x + r.size.x * 0.5 - w * 0.5, r.position.y), Vector2(w, r.size.y))
		draw_rect(zone, Color(ThemeFactory.OK, 0.6))
		# Hatched edges so the zone is visible without relying on color.
		draw_rect(zone, ThemeFactory.TEXT, false, 2.0)
		draw_rect(r, ThemeFactory.LINE, false, 1.0)
		var x := r.position.x + r.size.x * needle
		draw_line(Vector2(x, r.position.y - 6), Vector2(x, r.end.y + 6), ThemeFactory.CRIMSON_HI, 3.0)
		var font := get_theme_default_font()
		var text := tr("HUD_CRANK") % [successes, GarageMotor.SUCCESSES_NEEDED]
		draw_string(font, Vector2(0, 12), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, ThemeFactory.TEXT)
