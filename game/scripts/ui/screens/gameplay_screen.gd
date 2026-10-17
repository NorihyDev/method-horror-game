extends Screen
## In-match screen: HUD, touch controls, overlays and match lifecycle.

var map: MapBase
var mc: MatchController
var player: PlayerController
var hud: Hud
var touch: TouchControls
var intensity: IntensityController
var inspector: DebugInspector
var team_hud: TeamHud
var spectator: SpectatorCamera
var _overlay: OverlayPanel
var _started := false
var _ending := false
var _online := false
var _net: NetBridge
var _ping_cooldown := 0.0


func _init() -> void:
	super._init()
	passes_input = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func on_enter(p: Dictionary) -> void:
	if _started:
		# Returning from Settings: re-apply and keep the pause menu.
		_refresh_input_mode()
		return
	_started = true
	params = p
	map = p["map"]
	mc = p["match"]
	player = p["player"]
	_online = not mc.is_solo
	var use_touch := TouchControls.should_show()
	hud = Hud.new()
	add_child(hud)
	if use_touch:
		touch = TouchControls.new()
		add_child(touch)
		touch.pressed.connect(_on_touch_pressed)
		if _online:
			touch.enabled_buttons.append("ping")
		player.touch = touch
	hud.bind(player, mc, use_touch)
	if _online and mc.net is NetBridge:
		_net = mc.net
		team_hud = TeamHud.new()
		add_child(team_hud)
		team_hud.bind(mc, _net, player, use_touch)
	if DebugInspector.allowed():
		inspector = DebugInspector.new()
		inspector.match_ctrl = mc
		add_child(inspector)
	intensity = IntensityController.new()
	add_child(intensity)
	intensity.setup(mc, player)
	_connect_match()
	app.post_fx.set_active(true)
	app._dynres.active_in_gameplay = true
	AudioService.play_ambience(String(mc.map_def.ambience_sound), 3.0, -4.0)
	player.input_enabled = true
	_refresh_input_mode()
	# A multiplayer server already began the match at its start barrier.
	if not mc.running:
		mc.begin()
	_apply_local_status(str(mc.state.player(player.player_id).get("status", MatchState.STATUS_ALIVE)))


func on_exit() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if app:
		app._dynres.active_in_gameplay = false


func _connect_match() -> void:
	mc.player_damaged.connect(
		func(pid: int, hits: int) -> void:
			if pid == player.player_id:
				player.on_damaged(hits)
				app.post_fx.damage = 0.9
				create_tween().tween_property(
					app.post_fx, "damage", clampf(float(hits) / mc.difficulty.player_hits, 0.0, 0.6) * 0.6, 1.6
				)
	)
	mc.local_player_died.connect(_on_died)
	mc.player_status_changed.connect(
		func(pid: int, status: String) -> void:
			if pid == player.player_id:
				_apply_local_status(status)
	)
	mc.match_finished.connect(_on_finished)
	mc.phase_changed.connect(
		func(phase: int) -> void:
			if phase == MatchState.Phase.FINAL:
				hud.push_notice(tr("NOTE_FINAL_PHASE"))
	)
	player.hiding_changed.connect(
		func(hidden: bool) -> void:
			create_tween().tween_property(app.post_fx, "slats", 1.0 if hidden else 0.0, 0.35)
			if touch:
				touch.enabled_buttons = ["interact", "pause"] if hidden else _default_touch_buttons()
	)
	for ent in mc.entities.values():
		_connect_entity(ent)
	Session.app_paused_changed.connect(_on_app_paused)


func _default_touch_buttons() -> PackedStringArray:
	var b: PackedStringArray = ["interact", "sprint", "crouch", "flashlight", "inventory", "pause"]
	if _online:
		b.append("ping")
	return b


## Presentation of the local player's server-decided status.
func _apply_local_status(status: String) -> void:
	match status:
		MatchState.STATUS_ESCAPED:
			if player.escaped:
				return
			player.set_downed(false)
			player.on_escaped()
			hud.set_status("HUD_ESCAPED")
			AudioService.play_2d("escape_sting", AudioService.BUS_MUSIC, -2.0)
			_spectate_later()
		MatchState.STATUS_DOWNED:
			player.set_downed(true)
			hud.set_status("HUD_DOWNED")
			if touch:
				touch.release_all()
				touch.enabled_buttons = ["flashlight", "pause"]
		MatchState.STATUS_ALIVE:
			if player.downed:
				player.set_downed(false)
				hud.set_status("")
				if touch:
					touch.enabled_buttons = _default_touch_buttons()
		MatchState.STATUS_DEAD:
			if _online and not player.dead:
				player.set_downed(false)
				player.on_died()
				hud.set_status("HUD_DEAD_MP")
				AudioService.play_2d("defeat_sting", AudioService.BUS_MUSIC, -4.0)
				_spectate_later()


func _spectate_later() -> void:
	if not _online:
		return
	await get_tree().create_timer(2.0).timeout
	if is_inside_tree() and not _ending:
		_start_spectating()


func _start_spectating() -> void:
	if spectator:
		return
	spectator = SpectatorCamera.new()
	spectator.match_ctrl = mc
	spectator.local_pid = player.player_id
	map.add_child(spectator)
	spectator.global_transform = player.camera.global_transform
	spectator.target_changed.connect(
		func(display_name: String) -> void:
			team_hud.set_spectating(display_name)
			if display_name.is_empty():
				player.camera.current = true
			else:
				spectator.current = true
	)
	hud.set_status("")
	hud.set_minimal(true)
	if touch:
		touch.enabled_buttons = ["interact", "pause"]
	if not spectator.next_target():
		team_hud.set_spectating("")


func _send_ping() -> void:
	if not _online or _ping_cooldown > 0.0 or player.dead or player.downed or player.escaped or player.is_hidden():
		return
	var cam := player.camera
	var from := cam.global_position
	var dir := -cam.global_basis.z
	var mask := GeoBuilder.LAYER_WORLD | GeoBuilder.LAYER_PROP | Interactable.LAYER_INTERACT | DoorEntity.LAYER_DOOR
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 28.0, mask)
	q.exclude = [player.get_rid()]
	var hit := map.get_world_3d().direct_space_state.intersect_ray(q)
	var reach := 28.0 if hit.is_empty() else from.distance_to(hit["position"])
	var pos := from + dir * minf(reach, 12.0) if hit.is_empty() else (hit["position"] as Vector3)
	var kind := 0
	if not hit.is_empty() and (hit["collider"] as Object).has_meta("interactable"):
		kind = 1
	# Danger only for an enemy in front of the first wall: no pinging through walls.
	for e in mc.enemies:
		if not is_instance_valid(e) or not (e as Node3D).is_visible_in_tree():
			continue
		var epos := (e as Node3D).global_position + Vector3(0, 1.2, 0)
		var t := (epos - from).dot(dir)
		if t > 0.0 and t <= reach + 0.5 and (from + dir * t).distance_to(epos) < 1.4:
			kind = 2
			pos = epos
	_ping_cooldown = 1.2
	_net.send_ping(pos, kind)


func _process(delta: float) -> void:
	if _ping_cooldown > 0.0:
		_ping_cooldown -= delta


func _connect_entity(ent: Interactable) -> void:
	if ent is KeypadEntity:
		(ent as KeypadEntity).open_ui_requested.connect(_open_keypad)
	elif ent is NoteEntity:
		(ent as NoteEntity).read_requested.connect(_open_note)


# --- Input -----------------------------------------------------------------------------


func _unhandled_input(event: InputEvent) -> void:
	if _ending or _overlay:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		open_pause()
	elif spectator and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		spectator.next_target()
	elif _online and event.is_action_pressed("ping"):
		get_viewport().set_input_as_handled()
		_send_ping()
	elif event.is_action_pressed("inventory"):
		get_viewport().set_input_as_handled()
		_open_inventory()
	elif (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and (event as InputEventKey).keycode == KEY_F3
		and inspector
	):
		inspector.visible = not inspector.visible
	elif event is InputEventMouseButton and event.pressed and not TouchControls.should_show():
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func handle_back() -> bool:
	if _ending:
		return true
	if _overlay:
		_overlay.handle_back()
	else:
		open_pause()
	return true


func _on_touch_pressed(button: String) -> void:
	if _overlay:
		return
	match button:
		"pause":
			open_pause()
		"ping":
			_send_ping()
		"interact":
			if spectator:
				spectator.next_target()
		"inventory":
			_open_inventory()
		"flashlight":
			player.toggle_flashlight()
		"crouch":
			if Settings.s("crouch_mode") == "toggle":
				player.set_crouch(not player.crouching)
		"sprint":
			if Settings.s("sprint_mode") == "toggle":
				player.toggle_sprint()


func set_interact_highlight(on: bool) -> void:
	if touch:
		touch.highlight_interact = on


func _refresh_input_mode() -> void:
	var blocked := _overlay != null or _ending
	player.input_enabled = not blocked and not player.dead
	if touch:
		touch.visible = not blocked
		if blocked:
			touch.release_all()
	if TouchControls.should_show() or blocked or AppInfo.is_headless():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# --- Overlays ----------------------------------------------------------------------------


func _show_overlay(o: OverlayPanel, pause_world: bool) -> void:
	if _overlay:
		_overlay.queue_free()
	_overlay = o
	o.screen = self
	add_child(o)
	o.closed.connect(
		func() -> void:
			if _overlay == o:
				_overlay = null
			if pause_world and not _online:
				get_tree().paused = false
			_refresh_input_mode()
	)
	if pause_world and not _online:
		get_tree().paused = true
	_refresh_input_mode()


func open_pause() -> void:
	# Solo death has its own overlay; dead or spectating online players can still leave.
	if _overlay or _ending or (player.dead and not _online):
		return
	var pm := PauseMenu.new()
	pm.match_ctrl = mc
	pm.is_online = _online
	hud.clear_hint_badge()
	pm.resume_requested.connect(func() -> void: pm.close())
	pm.settings_requested.connect(func() -> void: app.goto("settings", {"in_game": true}))
	pm.restart_checkpoint_requested.connect(
		func() -> void:
			app.confirm(
				"RESTART_TITLE",
				"RESTART_CHECKPOINT_BODY",
				"RESTART_CONFIRM",
				func() -> void:
					_leave_world()
					Session.continue_from_checkpoint(),
				true
			)
	)
	pm.restart_requested.connect(
		func() -> void:
			app.confirm(
				"RESTART_TITLE",
				"RESTART_BODY",
				"RESTART_CONFIRM",
				func() -> void:
					_leave_world()
					Saves.clear_checkpoint()
					Session.start_solo(String(mc.map_def.id), String(mc.difficulty.id)),
				true
			)
	)
	pm.quit_requested.connect(
		func() -> void:
			app.confirm(
				"LEAVE_TITLE",
				"LEAVE_BODY_PROGRESS" if mc.is_solo else "LEAVE_BODY",
				"LEAVE_CONFIRM",
				func() -> void:
					_leave_world()
					Session.quit_to_menu(),
				true
			)
	)
	_show_overlay(pm, true)


func _open_inventory() -> void:
	if _overlay or player.dead or player.downed or player.is_hidden():
		return
	var inv := InventoryPanel.new()
	inv.match_ctrl = mc
	inv.player_id = player.player_id
	player.viewmodel.play_inspect(true)
	inv.closed.connect(func() -> void: player.viewmodel.play_inspect(false))
	_show_overlay(inv, false)


func _open_note(note: NoteEntity) -> void:
	if _overlay:
		return
	var reader := NoteReader.new()
	reader.title_text = tr(note.title_key)
	reader.body_text = note.body_text()
	_show_overlay(reader, false)
	if not note.read_flag.is_empty():
		mc.request_interact(note.entity_id, 0, "read")


func _open_keypad(keypad: KeypadEntity) -> void:
	if _overlay:
		return
	var kp := KeypadPanel.new()
	kp.keypad = keypad
	kp.match_ctrl = mc
	_show_overlay(kp, false)


func _on_died() -> void:
	player.on_died()
	AudioService.play_2d("defeat_sting", AudioService.BUS_MUSIC, -2.0)
	AudioService.stop_music(1.0)
	await get_tree().create_timer(1.6).timeout
	if not is_inside_tree():
		return
	var d := DeathOverlay.new()
	var snap := Saves.load_checkpoint()
	d.can_checkpoint = mc.difficulty.checkpoints_enabled and str(snap.get("match_id", "")) == mc.state.match_id
	d.retry_checkpoint.connect(
		func() -> void:
			_leave_world()
			Session.continue_from_checkpoint()
	)
	d.restart.connect(
		func() -> void:
			_leave_world()
			Saves.clear_checkpoint()
			Session.start_solo(String(mc.map_def.id), String(mc.difficulty.id))
	)
	d.give_up.connect(
		func() -> void:
			d.close()
			mc.give_up()
	)
	_show_overlay(d, false)


func _on_app_paused(paused: bool) -> void:
	if paused and not _overlay and not _ending and is_inside_tree():
		open_pause()


func _on_finished(result: Dictionary) -> void:
	if _ending:
		return
	_ending = true
	_refresh_input_mode()
	await get_tree().create_timer(2.5 if result.get("outcome") == "victory" else 1.2).timeout
	await app.fade_out(0.8)
	_leave_world()
	Session.finish_match(result)
	app.fade_in(0.8)


func _leave_world() -> void:
	get_tree().paused = false
	if intensity:
		intensity.stop()
	AudioService.stop_all_world()
	app.post_fx.set_active(false)
	app.captions.clear()
	app.set_world(null)
