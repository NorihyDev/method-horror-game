class_name RemoteAvatar
extends CharacterBody3D
## Another player as seen by this peer. On the server it is also the physics
## proxy that escape zones detect. Names are untrusted text: shown with a
## Label3D (no markup parsing) and never used for logic.

var player_id := 0
var display_name := ""
var color := Color(0.5, 0.5, 0.55)
var status := MatchState.STATUS_ALIVE

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _body: Node3D
## Animated character; null falls back to the simple capsule figure.
var _model: TeammateModel
var _light: SpotLight3D
var _label: Label3D
var _revive: ReviveTarget
var _hidden := false
var _away := false
var _crouch := false
var _bob := 0.0


func get_player_id() -> int:
	return player_id


func _ready() -> void:
	collision_layer = PlayerController.LAYER_PLAYER
	collision_mask = 0
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.33
	cap.height = 1.75
	cs.shape = cap
	cs.position.y = 0.875
	add_child(cs)
	_body = Node3D.new()
	add_child(_body)
	_model = TeammateModel.create()
	if _model:
		_body.add_child(_model)
	else:
		_build_figure()
	_light = SpotLight3D.new()
	_light.position = Vector3(0.22, 1.3, -0.4)
	_light.spot_range = 14.0
	_light.spot_angle = 30.0
	_light.light_energy = 2.2
	_light.shadow_enabled = false
	_body.add_child(_light)
	_label = Label3D.new()
	_label.text = display_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 36
	_label.pixel_size = 0.004
	_label.outline_size = 8
	_label.modulate = Color(0.92, 0.88, 0.8)
	_label.position = Vector3(0, 2.05, 0)
	_label.no_depth_test = false
	add_child(_label)
	_revive = ReviveTarget.new()
	_revive.avatar = self
	_revive.position = Vector3(0, 0.3, 0)
	add_child(_revive)
	_target_pos = global_position


func _build_figure() -> void:
	var coat := MaterialLib.flat(color.darkened(0.35), 0.85)
	var skin := MaterialLib.flat(Color(0.55, 0.45, 0.38), 0.8)
	_part(CapsuleMesh.new(), coat, Vector3(0, 0.95, 0), Vector3(0.34, 0.95, 0.34))
	_part(SphereMesh.new(), skin, Vector3(0, 1.62, 0), Vector3(0.22, 0.24, 0.22))
	_part(BoxMesh.new(), MaterialLib.flat(Color(0.1, 0.1, 0.11), 0.9), Vector3(0, 0.25, 0), Vector3(0.3, 0.5, 0.2))
	_part(
		CylinderMesh.new(),
		MaterialLib.flat(Color(0.15, 0.15, 0.16), 0.4, 0.6),
		Vector3(0.22, 1.25, -0.25),
		Vector3(0.05, 0.22, 0.05),
		Vector3(PI / 2, 0, 0)
	)


func _part(mesh: PrimitiveMesh, mat: Material, pos: Vector3, size: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = size
	_body.add_child(mi)


## Server: authoritative placement from validated motion.
func server_place(pos: Vector3, yaw: float) -> void:
	global_position = pos
	_target_pos = pos
	_target_yaw = yaw
	rotation.y = yaw


## Client: interpolation target from the server's 15 Hz packets.
func target(pos: Vector3, yaw: float, snap: bool = false, flags: int = 0) -> void:
	_target_pos = pos
	_target_yaw = yaw
	_crouch = flags & 1 != 0
	if _light:
		_light.visible = flags & 4 != 0 and status == MatchState.STATUS_ALIVE and not _hidden
	if snap:
		global_position = pos
		rotation.y = yaw


func _process(delta: float) -> void:
	var before := global_position
	global_position = global_position.lerp(_target_pos, clampf(delta * 12.0, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, _target_yaw, clampf(delta * 12.0, 0.0, 1.0))
	var speed := (global_position - before).length() / maxf(delta, 0.001)
	_bob += delta * speed * 2.0
	if _model:
		_model.update_motion(speed, _crouch, status == MatchState.STATUS_DOWNED)
	elif _body and status == MatchState.STATUS_ALIVE:
		_body.position.y = absf(sin(_bob)) * 0.04 if speed > 0.3 else 0.0
		_body.scale.y = lerpf(_body.scale.y, 0.68 if _crouch else 1.0, clampf(delta * 8.0, 0.0, 1.0))


func set_status(value: String) -> void:
	status = value
	if _body == null:
		return
	var downed := value == MatchState.STATUS_DOWNED
	_body.rotation.x = deg_to_rad(-80) if downed else 0.0
	# Tipped face down; the model's "downed" clip crawls in that pose.
	_body.position.y = (0.12 if _model else 0.3) if downed else 0.0
	visible = value in [MatchState.STATUS_ALIVE, MatchState.STATUS_DOWNED] and not _away
	_light.visible = _light.visible and value == MatchState.STATUS_ALIVE
	_label.modulate = Color(0.9, 0.3, 0.25) if downed else Color(0.92, 0.88, 0.8)
	collision_layer = PlayerController.LAYER_PLAYER if value == MatchState.STATUS_ALIVE and not _away else 0


func set_hidden(hidden: bool) -> void:
	_hidden = hidden
	if _body:
		_body.visible = not hidden
		_label.visible = not hidden


func set_away(away: bool) -> void:
	_away = away
	set_status(status)


func is_downed() -> bool:
	return status == MatchState.STATUS_DOWNED
