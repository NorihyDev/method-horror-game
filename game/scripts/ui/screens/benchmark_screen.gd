extends Screen
## Development builds only: runs the frame-time benchmark over every playable
## map with the world visible, then shows the summary and where the full
## report was saved.

var _bench: Benchmark
var _label: Label
var _panel: PanelContainer


func _init() -> void:
	super._init()
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func on_enter(p: Dictionary) -> void:
	if _bench:
		return
	params = p
	var root := safe_root(24)
	var col := UI.vbox(10)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(col)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = UI.label("BENCH_RUNNING", ThemeFactory.FONT_BODY + 2)
	_label.add_theme_constant_override("outline_size", 6)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	col.add_child(_label)
	app.post_fx.set_active(true)
	_bench = Benchmark.new()
	_bench.app = app
	add_child(_bench)
	_bench.progress.connect(func(text: String) -> void: _label.text = text)
	var report := await _bench.run()
	if not is_inside_tree():
		return
	_show(report)


func _show(report: Dictionary) -> void:
	app.post_fx.set_active(false)
	_label.text = ""
	var bg := ColorRect.new()
	bg.color = Color(ThemeFactory.BG, 0.96)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_panel = UI.panel(28)
	var v := UI.vbox(14)
	_panel.add_child(v)
	v.add_child(UI.heading("BENCH_DONE"))
	v.add_child(UI.accent_bar())
	var summary := UI.plain(Benchmark.summary_text(report), ThemeFactory.FONT_SMALL + 2)
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.custom_minimum_size.x = 900
	v.add_child(summary)
	var where := UI.plain(
		tr("BENCH_SAVED") % str(report.get("path", "")), ThemeFactory.FONT_SMALL, ThemeFactory.TEXT_DIM
	)
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	where.custom_minimum_size.x = 900
	v.add_child(where)
	var back := UI.button("BACK_TO_MENU", func() -> void: Session.quit_to_menu(), true, 260)
	v.add_child(back)
	add_child(UI.center(_panel))
	back.grab_focus.call_deferred()


func handle_back() -> bool:
	if _panel:
		Session.quit_to_menu()
	return true
