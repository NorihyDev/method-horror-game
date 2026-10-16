class_name PauseMenu
extends OverlayPanel
## Pause / objectives / hints. In solo the world is paused; online it is not
## (a pause menu must never freeze a shared match).

signal resume_requested
signal settings_requested
signal restart_checkpoint_requested
signal restart_requested
signal quit_requested

var match_ctrl: MatchController
var is_online := false


func build() -> void:
	panel.custom_minimum_size = Vector2(760, 0)
	header("PAUSE_TITLE")
	if is_online:
		body.add_child(UI.para("PAUSE_ONLINE_NOTE", ThemeFactory.FONT_SMALL, ThemeFactory.WARN))
	var columns := UI.hbox(28)
	body.add_child(columns)
	var left := UI.vbox(10)
	left.custom_minimum_size.x = 260
	columns.add_child(left)
	left.add_child(UI.button("PAUSE_RESUME", func() -> void: resume_requested.emit(), true, 240))
	left.add_child(UI.button("MENU_SETTINGS", func() -> void: settings_requested.emit(), false, 240))
	if not is_online:
		if Saves.has_checkpoint() and match_ctrl.difficulty.checkpoints_enabled and not match_ctrl.map_def.is_tutorial:
			left.add_child(UI.button("PAUSE_CHECKPOINT", func() -> void: restart_checkpoint_requested.emit(), false, 240))
		left.add_child(UI.button("PAUSE_RESTART", func() -> void: restart_requested.emit(), false, 240))
	left.add_child(UI.button("PAUSE_QUIT", func() -> void: quit_requested.emit(), false, 240))
	var right := UI.vbox(8)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.custom_minimum_size.x = 400
	columns.add_child(right)
	right.add_child(UI.caption("PAUSE_OBJECTIVES"))
	var graph := match_ctrl.rules.graph
	for id in graph.active_ids(match_ctrl.state.objectives, true):
		var def := graph.get_def(id)
		if def.complete_flag == "unseen":
			continue
		var title := UI.label(("" if not def.optional else tr("PAUSE_OPTIONAL") + " ") + match_ctrl.objective_title(def),
			ThemeFactory.FONT_BODY, ThemeFactory.TEXT)
		title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		right.add_child(title)
		if def.optional:
			continue
		var tier := match_ctrl.hint_tier(id)
		for i in tier:
			var h := UI.para(tr("HINT_PREFIX") % (i + 1) + " " + tr(def.hint_keys[i]), ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_DIM)
			h.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			right.add_child(h)
		if tier < def.hint_keys.size():
			var delay := match_ctrl.effective_hint_delay()
			var hint_text := ""
			if delay <= 0.0:
				hint_text = tr("HINTS_DISABLED")
			else:
				var entry: Dictionary = match_ctrl.state.objectives.get(id, {})
				var next_at := float(entry.get("activated_at", 0.0)) + delay * (tier + 1)
				hint_text = tr("HINT_NEXT_IN") % UI.format_time(maxf(0.0, next_at - match_ctrl.state.elapsed))
			right.add_child(UI.label(hint_text, ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT))
	right.add_child(UI.spacer(8))
	var meta := UI.label(tr("PAUSE_META") % [tr(match_ctrl.map_def.title_key), tr(match_ctrl.difficulty.title_key),
		UI.format_time(match_ctrl.state.elapsed)], ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_FAINT)
	meta.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	right.add_child(meta)


func handle_back() -> bool:
	resume_requested.emit()
	return true
