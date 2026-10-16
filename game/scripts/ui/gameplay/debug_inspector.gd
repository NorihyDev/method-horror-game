class_name DebugInspector
extends PanelContainer
## Development-only objective/puzzle inspector (F3). Never created in release
## builds because it reveals puzzle answers.

var match_ctrl: MatchController
var _label: Label
var _timer := 0.0


static func allowed() -> bool:
	return OS.is_debug_build()


func _ready() -> void:
	add_theme_stylebox_override("panel", ThemeFactory.flat(Color(0, 0, 0, 0.8), ThemeFactory.WARN, 1, 2, 12, 10))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2(20, 220)
	_label = Label.new()
	_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_label.add_theme_font_override("font", ThemeFactory.mono_font())
	_label.add_theme_font_size_override("font_size", 13)
	add_child(_label)
	visible = false


func _process(delta: float) -> void:
	if not visible or match_ctrl == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.25
	var lines: PackedStringArray = ["DEV OBJECTIVE INSPECTOR (F3)  fps=%d" % Engine.get_frames_per_second()]
	var graph := match_ctrl.rules.graph
	for def in graph.defs():
		var st: Dictionary = match_ctrl.state.objectives.get(def.id, {})
		lines.append(
			(
				"  %-8s %-9s hint=%d %s"
				% [
					def.id,
					["LOCKED", "ACTIVE", "COMPLETE"][int(st.get("state", 0))],
					match_ctrl.hint_tier(def.id),
					"(opt)" if def.optional else ""
				]
			)
		)
	lines.append("flags: " + ", ".join(PackedStringArray(match_ctrl.state.flags.keys())))
	lines.append("counters: " + str(match_ctrl.state.counters))
	var puzzle := match_ctrl.puzzle()
	lines.append("code=%s faulty=%s" % [str(puzzle.get("code", "?")), str(puzzle.get("faulty_socket", "?"))])
	lines.append("placements: " + str(match_ctrl.state.variant.get("placements", {})))
	var errors := match_ctrl.rules.validate()
	lines.append("validation: " + ("OK" if errors.is_empty() else "; ".join(errors)))
	for e in match_ctrl.enemies:
		if is_instance_valid(e) and e.has_method("debug_text"):
			lines.append(str(e.call("debug_text")))
	_label.text = "\n".join(lines)
