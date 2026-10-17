class_name MusicBox
extends Interactable
## A wind-up music box left playing somewhere in the school. The map seeds
## where it sits each match (next to the key it guards), so players find it
## by ear: the tinkling tune is a positional loop, captioned with direction
## when sound captions are on. Closing the lid silences it.

var _lid: Node3D
var _dancer: Node3D
var _emitter: AudioStreamPlayer3D
var _spin := 0.0


func _ready() -> void:
	prompt_key = "PROMPT_MUSIC_BOX"
	var wood := MaterialLib.surface("dark_wood")
	add_mesh(box_mesh(Vector3(0.22, 0.09, 0.15)), wood, Transform3D(Basis.IDENTITY, Vector3(0, 0.045, 0)))
	add_mesh(
		box_mesh(Vector3(0.2, 0.005, 0.13)),
		MaterialLib.flat(Color(0.45, 0.08, 0.1), 0.9),
		Transform3D(Basis.IDENTITY, Vector3(0, 0.092, 0))
	)
	_lid = Node3D.new()
	_lid.position = Vector3(0, 0.09, -0.075)
	add_child(_lid)
	add_mesh(box_mesh(Vector3(0.22, 0.015, 0.15)), wood, Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.075)), _lid)
	_dancer = Node3D.new()
	_dancer.position = Vector3(0, 0.095, 0)
	add_child(_dancer)
	var porcelain := MaterialLib.flat(Color(0.88, 0.86, 0.82), 0.3)
	add_mesh(
		box_mesh(Vector3(0.012, 0.05, 0.012)), porcelain, Transform3D(Basis.IDENTITY, Vector3(0, 0.025, 0)), _dancer
	)
	add_mesh(box_mesh(Vector3(0.04, 0.008, 0.04)), porcelain, Transform3D(Basis.IDENTITY, Vector3(0, 0.03, 0)), _dancer)
	_emitter = AudioService.make_emitter("music_box_loop", -1.0, 22.0)
	_emitter.position = Vector3(0, 0.1, 0)
	add_child(_emitter)
	add_target(Vector3(0.3, 0.2, 0.25), Vector3(0, 0.08, 0))
	_present()


func initial_state() -> Dictionary:
	return {"pos": [], "playing": true}


func apply_state(new_state: Dictionary) -> void:
	super.apply_state(new_state)
	var pos: Array = new_state.get("pos", [])
	if pos.size() == 3:
		position = Vector3(float(pos[0]), float(pos[1]), float(pos[2]))
	if is_inside_tree():
		_present()


func is_playing() -> bool:
	return bool(state.get("playing", true))


func _present() -> void:
	var on := is_playing() and not (state.get("pos", []) as Array).is_empty()
	_lid.rotation.x = deg_to_rad(-100.0) if is_playing() else 0.0
	_dancer.visible = is_playing()
	if on and not _emitter.playing:
		_emitter.play()
	elif not on and _emitter.playing:
		_emitter.stop()


func _process(delta: float) -> void:
	if is_playing():
		_spin += delta * 2.4
		_dancer.rotation.y = _spin


func get_prompt(_pid: int, _sub: int) -> String:
	return tr(prompt_key) if is_playing() else ""


func authority_interact(ctx: Dictionary) -> void:
	if not is_playing():
		return
	var s := state.duplicate(true)
	s["playing"] = false
	match_ctrl.set_entity_state(entity_id, s)
	world_sound("drawer", -10.0, 8.0)
	match_ctrl.emit_noise(interact_origin(), 2.0, "music_box", int(ctx["player_id"]))
