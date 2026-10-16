class_name GarageDoor
extends Interactable
## The exit. Rises slowly once the motor starts; the motor is loud enough to
## draw the Watcher from anywhere in the house (the final escape sequence).

@export var width := 6.0
@export var height := 2.6
@export var open_seconds := 40.0
@export var open_flag := "garage_open"

var panel: AnimatableBody3D
var _emitter: AudioStreamPlayer3D
var _noise_timer := 0.0
var _sync_timer := 0.0
var _progress := 0.0


func _ready() -> void:
	prompt_key = "PROMPT_GARAGE_DOOR"
	panel = AnimatableBody3D.new()
	panel.collision_layer = DoorEntity.LAYER_DOOR | GeoBuilder.LAYER_WORLD
	panel.collision_mask = 0
	add_child(panel)
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, height, 0.12)
	cs.shape = box
	cs.position = Vector3(0, height * 0.5, 0)
	panel.add_child(cs)
	var mat := MaterialLib.surface("metal")
	var sections := 5
	for i in sections:
		var h := height / sections
		add_mesh(
			box_mesh(Vector3(width, h - 0.02, 0.06)),
			mat,
			Transform3D(Basis.IDENTITY, Vector3(0, h * (i + 0.5), 0)),
			panel
		)
		add_mesh(
			box_mesh(Vector3(width, 0.03, 0.09)),
			MaterialLib.surface("metal_dark"),
			Transform3D(Basis.IDENTITY, Vector3(0, h * i + 0.01, 0)),
			panel
		)
	add_target(Vector3(width, height, 0.2), Vector3(0, height * 0.5, 0.05), 0, panel)
	_emitter = AudioService.make_emitter("garage_loop", 4.0, 45.0)
	_emitter.position = Vector3(0, height, 0.5)
	add_child(_emitter)


func initial_state() -> Dictionary:
	return {"progress": 0.0}


func apply_state(new_state: Dictionary) -> void:
	super.apply_state(new_state)
	_progress = clampf(float(new_state.get("progress", 0.0)), 0.0, 1.0)


func progress() -> float:
	return _progress


func _physics_process(delta: float) -> void:
	# Presentation (and physical gap): ease toward the replicated progress.
	var target_y := _progress * (height - 0.25)
	panel.position.y = move_toward(panel.position.y, target_y, delta * 0.5)
	var moving := _progress > 0.0 and _progress < 1.0
	if moving and not _emitter.playing:
		_emitter.play()
	elif not moving and _emitter.playing:
		_emitter.stop()


func get_prompt(_pid: int, _sub: int) -> String:
	if _progress > 0.0:
		return ""
	return tr("PROMPT_GARAGE_DOOR")


func authority_interact(ctx: Dictionary) -> void:
	match_ctrl.set_flag("exit_found")
	if _progress <= 0.0:
		world_sound("door_locked", 0.0, 16.0)
		match_ctrl.notify_player(int(ctx["player_id"]), "GARAGE_STUCK")


## Called by the map on the authority each physics tick.
func authority_tick(delta: float) -> void:
	if not match_ctrl.state.has_flag(open_flag) or _progress >= 1.0:
		return
	var p := minf(1.0, _progress + delta / open_seconds)
	_noise_timer -= delta
	if _noise_timer <= 0.0:
		_noise_timer = 2.0
		match_ctrl.emit_noise(global_position + Vector3(0, 1.5, 1.0), 60.0, "garage")
	_sync_timer -= delta
	if _sync_timer <= 0.0 or p >= 1.0:
		_sync_timer = 0.25
		match_ctrl.set_entity_state(entity_id, {"progress": p})
	else:
		_progress = p
		match_ctrl.state.entities[entity_id] = {"progress": p}
