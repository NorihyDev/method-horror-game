class_name TeamHud
extends Control
## Multiplayer additions to the HUD: teammate status list, ping markers,
## revive / bleed-out progress, spectating caption and optional round-trip
## time. Purely presentation: every value shown comes from the server.

const PING_SECONDS := 6.0
const PING_LABEL_KEYS := ["PING_HERE", "PING_ITEM", "PING_DANGER", "PING_HELP"]

var match_ctrl: MatchController
var net: NetBridge
var player: PlayerController
var touch_mode := false

var _list: VBoxContainer
var _rtt: Label
var _bar_box: VBoxContainer
var _bar_label: Label
var _bar: ProgressBar
var _spectate_label: Label
var _markers: PingMarkers
var _revives: Dictionary = {}
var _downed_since := -1.0
var _refresh_timer := 0.0
var _spectating_name := ""


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func bind(p_match: MatchController, p_net: NetBridge, p_player: PlayerController, p_touch: bool) -> void:
	match_ctrl = p_match
	net = p_net
	player = p_player
	touch_mode = p_touch
	_markers = PingMarkers.new()
	add_child(_markers)
	var box := UI.vbox(4)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.custom_minimum_size.x = 250
	box.name = "Team"
	add_child(box)
	box.add_child(UI.caption("TEAM_TITLE"))
	_list = UI.vbox(2)
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_list)
	_rtt = UI.label("", ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT)
	_rtt.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(_rtt)
	_bar_box = UI.vbox(4)
	_bar_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_box.visible = false
	add_child(_bar_box)
	_bar_label = UI.label("", ThemeFactory.FONT_BODY)
	_bar_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_label.add_theme_constant_override("outline_size", 6)
	_bar_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_bar_box.add_child(_bar_label)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(360, 12)
	_bar.show_percentage = false
	_bar.max_value = 1.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_box.add_child(_bar)
	_spectate_label = UI.label("", ThemeFactory.FONT_BODY + 2)
	_spectate_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_spectate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_spectate_label.add_theme_constant_override("outline_size", 6)
	_spectate_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_spectate_label.visible = false
	add_child(_spectate_label)
	net.revive_changed.connect(_on_revive_changed)
	net.ping_received.connect(_on_ping)
	match_ctrl.player_status_changed.connect(
		func(pid: int, status: String) -> void:
			if pid == player.player_id:
				_downed_since = match_ctrl.state.elapsed if status == MatchState.STATUS_DOWNED else -1.0
			_refresh_list()
	)
	_refresh_list()


func set_spectating(display_name: String) -> void:
	_spectating_name = display_name
	_spectate_label.visible = true
	var hint := tr("SPECTATE_NEXT_TOUCH") if touch_mode else tr("SPECTATE_NEXT")
	if display_name.is_empty():
		_spectate_label.text = tr("SPECTATE_NOBODY")
	else:
		_spectate_label.text = tr("SPECTATE_WATCHING") % display_name + "\n" + hint


func _layout() -> void:
	var vp := get_viewport_rect().size
	var m := Session.app.safe_margins() if Session.app else Vector4.ZERO
	var team := get_node("Team") as Control
	if touch_mode:
		# Opposite the button cluster, under the notification feed.
		var left := not Settings.b("left_handed")
		team.position = Vector2(m.x + 24 if left else vp.x - m.z - 270, m.y + 290)
	else:
		team.position = Vector2(vp.x - m.z - 270, m.y + 24)
	_bar_box.position = Vector2((vp.x - 360) * 0.5, vp.y * 0.62)
	_spectate_label.size = Vector2(vp.x, 80)
	_spectate_label.position = Vector2(0, vp.y - m.w - (230 if touch_mode else 150))


func _process(delta: float) -> void:
	if match_ctrl == null:
		return
	_layout()
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = 0.5
		_refresh_list()
		var rtt := net.rtt_ms()
		_rtt.visible = Settings.b("show_ping") and rtt >= 0
		_rtt.text = tr("LOBBY_PING") % rtt if rtt >= 0 else ""
	_update_bar()


func _refresh_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	var ids := match_ctrl.state.players.keys()
	ids.sort()
	for pid in ids:
		if int(pid) == player.player_id:
			continue
		var p: Dictionary = match_ctrl.state.players[pid]
		var status := str(p.get("status", ""))
		var key := (
			"TEAM_AWAY"
			if bool(p.get("away", false)) and status == MatchState.STATUS_ALIVE
			else "TEAM_" + status.to_upper()
		)
		var row := UI.hbox(8)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var n := UI.plain(str(p.get("name", "")), ThemeFactory.FONT_SMALL + 1)
		n.custom_minimum_size.x = 140
		n.clip_text = true
		n.add_theme_constant_override("outline_size", 5)
		n.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		row.add_child(n)
		var danger := status == MatchState.STATUS_DOWNED
		var s := UI.label(key, ThemeFactory.FONT_SMALL, ThemeFactory.DANGER if danger else ThemeFactory.TEXT_DIM)
		s.add_theme_constant_override("outline_size", 5)
		s.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		row.add_child(s)
		_list.add_child(row)


# --- Revives / bleed-out ------------------------------------------------------------------------


func _on_revive_changed(target: int, active: bool) -> void:
	if active:
		_revives[target] = match_ctrl.state.elapsed
	else:
		_revives.erase(target)


func _update_bar() -> void:
	var revive_time := maxf(match_ctrl.difficulty.revive_time, 0.1)
	var me := player.player_id
	if _revives.has(me):
		_show_bar(tr("REVIVE_BEING_REVIVED"), (match_ctrl.state.elapsed - float(_revives[me])) / revive_time)
		return
	var my_pos := player.global_position
	for target in _revives:
		var p: Dictionary = match_ctrl.state.player(int(target))
		if p.is_empty():
			continue
		if MatchState.array_to_vec(p["pos"]).distance_to(my_pos) <= MatchController.REVIVE_RADIUS + 0.5:
			var progress := (match_ctrl.state.elapsed - float(_revives[target])) / revive_time
			_show_bar(tr("REVIVE_REVIVING") % str(p.get("name", "")), progress)
			return
	if _downed_since >= 0.0:
		var left := match_ctrl.difficulty.bleedout_time - (match_ctrl.state.elapsed - _downed_since)
		_show_bar(
			tr("REVIVE_BLEEDING") % maxi(0, ceili(left)),
			clampf(left / maxf(match_ctrl.difficulty.bleedout_time, 1.0), 0, 1)
		)
		return
	_bar_box.visible = false


func _show_bar(text: String, value: float) -> void:
	_bar_box.visible = true
	_bar_label.text = text
	_bar.value = clampf(value, 0.0, 1.0)


# --- Pings ---------------------------------------------------------------------------------------


func _on_ping(pid: int, pos: Vector3, kind: int) -> void:
	var p := match_ctrl.state.player(pid)
	var who := str(p.get("name", "")) if pid != player.player_id else tr("PING_YOU")
	_markers.add(pos, clampi(kind, 0, 3), who)
	AudioService.play_2d("ping", AudioService.BUS_UI, -6.0 if pid == player.player_id else -2.0)


## Pings are drawn in screen space from world positions, with a distinct
## shape per kind so they never rely on color alone.
class PingMarkers:
	extends Control

	var _pings: Array[Dictionary] = []

	func _init() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func add(pos: Vector3, kind: int, who: String) -> void:
		_pings.append({"pos": pos, "kind": kind, "who": who, "t": Time.get_ticks_msec() / 1000.0})
		while _pings.size() > 8:
			_pings.pop_front()

	func _process(_d: float) -> void:
		var now := Time.get_ticks_msec() / 1000.0
		_pings = _pings.filter(func(p: Dictionary) -> bool: return now - float(p["t"]) < TeamHud.PING_SECONDS)
		queue_redraw()

	func _draw() -> void:
		var cam := get_viewport().get_camera_3d()
		if cam == null:
			return
		var font := get_theme_default_font()
		var vp := get_viewport_rect().size
		var now := Time.get_ticks_msec() / 1000.0
		for p in _pings:
			var pos: Vector3 = p["pos"]
			var age := now - float(p["t"])
			var alpha := clampf((TeamHud.PING_SECONDS - age) / 1.0, 0.0, 1.0)
			var screen := cam.unproject_position(pos)
			var behind := cam.is_position_behind(pos)
			if behind:
				screen = Vector2(vp.x - screen.x, vp.y - 40)
			screen = screen.clamp(Vector2(40, 40), vp - Vector2(40, 40))
			var kind := int(p["kind"])
			var col := [ThemeFactory.TEXT, ThemeFactory.WARN, ThemeFactory.CRIMSON_HI, ThemeFactory.OK][kind] as Color
			col.a = alpha
			var outline := Color(0, 0, 0, 0.8 * alpha)
			var r := 11.0
			var shape: PackedVector2Array
			match kind:
				1:
					shape = [
						screen + Vector2(-r, -r),
						screen + Vector2(r, -r),
						screen + Vector2(r, r),
						screen + Vector2(-r, r)
					]
				2:
					shape = [screen + Vector2(0, -r * 1.3), screen + Vector2(r * 1.2, r), screen + Vector2(-r * 1.2, r)]
				_:
					shape = [
						screen + Vector2(0, -r), screen + Vector2(r, 0), screen + Vector2(0, r), screen + Vector2(-r, 0)
					]
			draw_colored_polygon(shape, outline)
			var inner: PackedVector2Array = []
			for v in shape:
				inner.append(screen + (v - screen) * 0.7)
			draw_colored_polygon(inner, col)
			var dist := cam.global_position.distance_to(pos)
			var text := "%s · %s · %d m" % [p["who"], tr(TeamHud.PING_LABEL_KEYS[kind]), int(dist)]
			var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			var at := screen + Vector2(-w * 0.5, -r - 10)
			at.x = clampf(at.x, 8.0, vp.x - w - 8.0)
			at.y = maxf(at.y, 22.0)
			draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 5, outline)
			draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(ThemeFactory.TEXT, alpha))
