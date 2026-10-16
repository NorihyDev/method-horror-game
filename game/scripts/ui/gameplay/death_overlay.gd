class_name DeathOverlay
extends OverlayPanel
## Solo defeat choices: retry from the last checkpoint, restart, or give up.

signal retry_checkpoint
signal restart
signal give_up

var can_checkpoint := false


func build() -> void:
	closable = false
	panel.custom_minimum_size = Vector2(560, 0)
	var t := UI.title("DEATH_TITLE", 52)
	t.add_theme_color_override("font_color", Color(0.75, 0.12, 0.1))
	body.add_child(t)
	body.add_child(UI.accent_bar(96))
	body.add_child(UI.para("DEATH_BODY"))
	body.add_child(UI.spacer(6))
	if can_checkpoint:
		body.add_child(UI.button("DEATH_CHECKPOINT", func() -> void: retry_checkpoint.emit(), true, 380))
	body.add_child(UI.button("DEATH_RESTART", func() -> void: restart.emit(), not can_checkpoint, 380))
	body.add_child(UI.button("DEATH_GIVE_UP", func() -> void: give_up.emit(), false, 380))
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 1.2)


func handle_back() -> bool:
	return true
