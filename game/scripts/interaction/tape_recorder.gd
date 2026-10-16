class_name TapeRecorder
extends Interactable
## Plays a recorded message with subtitles (speaker label + lines). The voice
## is a procedural, unintelligible placeholder; subtitles carry the content.

@export var speaker_key := "SPEAKER_VARGA"
@export var line_keys: PackedStringArray = []
@export var line_seconds := 4.5
@export var heard_flag := "tape_heard"
@export var subtitle_radius := 12.0

var _reel_a: MeshInstance3D
var _reel_b: MeshInstance3D
var _playing_until := -1.0


func _ready() -> void:
	prompt_key = "PROMPT_PLAY_TAPE"
	add_mesh(box_mesh(Vector3(0.32, 0.09, 0.22)), MaterialLib.flat(Color(0.16, 0.15, 0.14), 0.6, 0.3))
	add_mesh(box_mesh(Vector3(0.3, 0.005, 0.2)), MaterialLib.flat(Color(0.32, 0.3, 0.27), 0.5, 0.4), Transform3D(Basis.IDENTITY, Vector3(0, 0.047, 0)))
	var reel := CylinderMesh.new()
	reel.top_radius = 0.045
	reel.bottom_radius = 0.045
	reel.height = 0.012
	reel.radial_segments = 10
	_reel_a = add_mesh(reel, MaterialLib.flat(Color(0.7, 0.68, 0.6), 0.5), Transform3D(Basis.IDENTITY, Vector3(-0.07, 0.055, 0)))
	_reel_b = add_mesh(reel, MaterialLib.flat(Color(0.7, 0.68, 0.6), 0.5), Transform3D(Basis.IDENTITY, Vector3(0.07, 0.055, 0)))
	add_target(Vector3(0.4, 0.2, 0.3))


func initial_state() -> Dictionary:
	return {"plays": 0}


func apply_state(new_state: Dictionary) -> void:
	var previous := int(state.get("plays", 0))
	super.apply_state(new_state)
	if int(new_state.get("plays", 0)) > previous and match_ctrl and match_ctrl.running:
		_present()


func _process(delta: float) -> void:
	if _playing_until > 0.0 and match_ctrl and match_ctrl.state.elapsed < _playing_until:
		_reel_a.rotate_y(delta * 3.0)
		_reel_b.rotate_y(delta * 3.0)


## Client presentation: subtitles for players within earshot.
func _present() -> void:
	_playing_until = match_ctrl.state.elapsed + line_seconds * line_keys.size()
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(global_position) > subtitle_radius:
		return
	for i in line_keys.size():
		get_tree().create_timer(i * line_seconds).timeout.connect(func() -> void:
			if is_inside_tree():
				AudioService.play_dialogue("tape_voice", speaker_key, line_keys[i], line_seconds - 0.3))


func authority_interact(_ctx: Dictionary) -> void:
	if match_ctrl.state.elapsed < _playing_until:
		return
	match_ctrl.set_entity_state(entity_id, {"plays": int(state.get("plays", 0)) + 1})
	match_ctrl.emit_noise(interact_origin(), 7.0, "tape")
	match_ctrl.set_flag(heard_flag)
