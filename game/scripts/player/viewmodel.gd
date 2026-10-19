class_name Viewmodel
extends Node3D
## First-person arms + flashlight. The arms are the player's own character
## (FirstPersonArms, posed by IK): the right hand grips the flashlight and
## follows its sway, bob and sprint pumping; the left hand reaches out to use
## and pick things up. A sleeve and hand built from boxes remain as the
## fallback when the character model is unavailable.

var flashlight: SpotLight3D
var _pivot: Node3D
var _rig: Node3D
var _lens_mat: StandardMaterial3D
var _body_mat: StandardMaterial3D
var _sway := Vector2.ZERO
var _last_cam_basis: Basis
var _anim_offset := Vector3.ZERO
var _tween: Tween
var _fill: OmniLight3D
var _arms: FirstPersonArms
var _box_hand: Array[MeshInstance3D] = []
var _left_kind := ""
var _left_time := 0.0
var _left_w := 0.0
var _inspecting := false


func _ready() -> void:
	_pivot = Node3D.new()
	_pivot.position = Vector3(0.26, -0.27, -0.44)
	# Soft bounce light so the immediate surroundings stay readable.
	_fill = OmniLight3D.new()
	_fill.light_color = Color(0.9, 0.88, 0.82)
	_fill.omni_range = 3.2
	_fill.light_energy = 0.18
	_fill.light_specular = 0.0
	_fill.position = Vector3(0, 0, -0.6)
	add_child(_fill)
	add_child(_pivot)
	_rig = Node3D.new()
	_pivot.add_child(_rig)
	_build_mesh()
	flashlight = SpotLight3D.new()
	flashlight.name = "Flashlight"
	flashlight.position = Vector3(0, 0.03, -0.2)
	flashlight.spot_range = 19.0
	flashlight.spot_angle = 34.0
	flashlight.spot_angle_attenuation = 0.75
	flashlight.spot_attenuation = 0.9
	flashlight.light_energy = 3.0
	flashlight.light_color = Color(1.0, 0.94, 0.82)
	flashlight.shadow_enabled = true
	flashlight.shadow_bias = 0.05
	flashlight.light_specular = 0.4
	# Aim the beam slightly inward so it converges on the reticle.
	flashlight.rotation = Vector3(deg_to_rad(2.5), deg_to_rad(4.0), 0)
	_rig.add_child(flashlight)
	BeamCone.attach(flashlight, true, 0.2)
	_arms = FirstPersonArms.new()
	_arms.name = "Arms"
	add_child(_arms)
	if _arms.setup(Saves.character()):
		for mi in _box_hand:
			mi.visible = false
	else:
		_arms.queue_free()
		_arms = null


func _build_mesh() -> void:
	var skin := MaterialLib.flat(Color(0.1, 0.085, 0.075), 0.65)
	var sleeve := MaterialLib.flat(Color(0.16, 0.17, 0.16), 0.95)
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.16, 0.16, 0.17)
	_body_mat.roughness = 0.4
	_body_mat.metallic = 0.6
	_lens_mat = MaterialLib.glow(Color(1.0, 0.95, 0.8), 2.0)
	_box_hand.append(_add_box(Vector3(0.09, 0.09, 0.32), sleeve, Vector3(0.03, -0.06, 0.2), Vector3(0.15, 0, 0)))
	_box_hand.append(_add_box(Vector3(0.075, 0.06, 0.1), skin, Vector3(0.0, -0.02, 0.0), Vector3.ZERO))
	for i in 4:
		_box_hand.append(
			_add_box(Vector3(0.016, 0.02, 0.05), skin, Vector3(-0.03 + i * 0.019, 0.015, -0.03), Vector3(0.3, 0, 0))
		)
	var body := CylinderMesh.new()
	body.top_radius = 0.022
	body.bottom_radius = 0.02
	body.height = 0.2
	body.radial_segments = 12
	_add_mesh(body, _body_mat, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.02, -0.06)))
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.032
	head_mesh.bottom_radius = 0.024
	head_mesh.height = 0.05
	head_mesh.radial_segments = 14
	_add_mesh(head_mesh, _body_mat, Transform3D(Basis(Vector3.RIGHT, -PI / 2), Vector3(0, 0.02, -0.18)))
	var lens := CylinderMesh.new()
	lens.top_radius = 0.028
	lens.bottom_radius = 0.028
	lens.height = 0.004
	lens.radial_segments = 14
	_add_mesh(lens, _lens_mat, Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0.02, -0.206)))


func _add_box(size: Vector3, mat: Material, pos: Vector3, rot: Vector3) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	return _add_mesh(m, mat, Transform3D(Basis.from_euler(rot), pos))


func _add_mesh(mesh: Mesh, mat: Material, xform: Transform3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xform
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rig.add_child(mi)
	return mi


func set_style(beam: Color, body: Color) -> void:
	if flashlight:
		flashlight.light_color = beam
	if _body_mat:
		_body_mat.albedo_color = body
	if _lens_mat:
		_lens_mat.albedo_color = beam
		_lens_mat.emission = beam


func set_lens_glow(k: float) -> void:
	if _fill:
		_fill.light_energy = 0.18 * clampf(k, 0.0, 1.0)
	if _lens_mat:
		_lens_mat.emission_energy_multiplier = 2.5 * k


## Called every physics tick by the controller.
func update_motion(
	delta: float, speed: float, sprinting: bool, crouching: bool, grounded: bool, bob_phase: float
) -> void:
	var cam := get_parent() as Node3D
	if cam == null:
		return
	var basis := cam.global_basis
	if _last_cam_basis != Basis():
		# Lag behind camera rotation for weight.
		var dq := (_last_cam_basis.inverse() * basis).get_euler()
		_sway = _sway.lerp(Vector2(-dq.y, dq.x) * 1.6, clampf(delta * 10.0, 0.0, 1.0))
	_last_cam_basis = basis
	_sway = _sway.lerp(Vector2.ZERO, clampf(delta * 6.0, 0.0, 1.0))
	var reduced := Settings.motion_reduced()
	var bob := Vector3.ZERO
	if grounded and speed > 0.3 and not reduced:
		bob = Vector3(cos(bob_phase) * 0.012, absf(sin(bob_phase)) * 0.014, 0) * (1.6 if sprinting else 1.0)
		if sprinting:
			# The flashlight arm pumps with the stride.
			bob += Vector3(0.0, 0.015 * cos(bob_phase), -0.05 * sin(bob_phase))
	var t := Time.get_ticks_msec() / 1000.0
	var idle := Vector3(sin(t * 1.1) * 0.003, sin(t * 1.7) * 0.004, 0) if not reduced else Vector3.ZERO
	var lower := Vector3(0.02, -0.06, 0.04) if sprinting else (Vector3(0, -0.02, 0) if crouching else Vector3.ZERO)
	var sway := Vector3(_sway.x, _sway.y, 0) * (0.0 if reduced else 0.35)
	_rig.position = _rig.position.lerp(bob + idle + lower + sway + _anim_offset, clampf(delta * 12.0, 0.0, 1.0))
	_rig.rotation = Vector3(-_sway.y * 0.4 + (deg_to_rad(-12) if sprinting else 0.0), _sway.x * 0.4, 0)
	if _arms:
		_drive_arms(delta, sprinting and grounded and speed > 0.3 and not reduced, crouching, bob_phase)


## Right hand on the flashlight grip; left hand by the side, pumping when
## sprinting, or reaching for whatever is being used.
func _drive_arms(delta: float, pumping: bool, crouching: bool, phase: float) -> void:
	var g := _pivot.transform * _rig.transform
	# The barrel runs through the fist; the forearm comes up from the lower
	# right, so the back of the hand points up and in.
	_arms.pose_grip(
		"r",
		g * Vector3(0.0, 0.02, -0.01),
		g.basis * Vector3(0.0, 0.0, -1.0),
		g.basis * Vector3(-0.6, 0.55, 0.1),
		Vector3(1.0, -1.3, 0.5),
		1.0
	)
	var wrist := Vector3(-0.3, -0.64 - (0.04 if crouching else 0.0), 0.02)
	var fingers := Vector3(0.05, -1.0, -0.25)
	var thumb := Vector3(0.0, 0.0, -1.0)
	var curl := 0.35
	if pumping:
		wrist = Vector3(-0.21, -0.37 + 0.05 * cos(phase), -0.25 + 0.17 * sin(phase))
		fingers = Vector3(0.35, 0.1, -1.0)
		thumb = Vector3(0.0, 1.0, 0.0)
		curl = 0.85
	_left_time = maxf(0.0, _left_time - delta)
	var acting := _inspecting or _left_time > 0.0
	_left_w = move_toward(_left_w, 1.0 if acting else 0.0, delta * (6.0 if acting else 3.5))
	if _left_w > 0.0:
		var aim: Array = _left_target()
		var k := _left_w * _left_w * (3.0 - 2.0 * _left_w)
		wrist = wrist.lerp(aim[0], k)
		fingers = fingers.lerp(aim[1], k)
		thumb = thumb.lerp(aim[2], k)
		curl = lerpf(curl, aim[3], k)
	_arms.pose_arm("l", wrist, fingers, thumb, Vector3(-1.0, -1.2, 0.4), curl)


func _left_target() -> Array:
	match "inspect" if _inspecting else _left_kind:
		"pickup":
			return [Vector3(-0.1, -0.33, -0.42), Vector3(0.1, -0.7, -1.0), Vector3(0.4, 0.3, 0.0), 0.55]
		"use":
			return [Vector3(-0.06, -0.27, -0.3), Vector3(1.0, -0.1, -0.3), Vector3(0.0, 1.0, 0.0), 0.6]
		"inspect":
			return [Vector3(-0.16, -0.24, -0.36), Vector3(0.4, 0.3, -1.0), Vector3(0.0, 0.4, 0.3), 0.4]
	return [Vector3(-0.1, -0.15, -0.47), Vector3(0.05, 0.0, -1.0), Vector3(0.0, 1.0, 0.0), 0.2]


func _left(kind: String, seconds: float) -> void:
	_left_kind = kind
	_left_time = seconds


func _play(offsets: Array[Vector3], times: Array[float]) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	for i in offsets.size():
		_tween.tween_property(self, "_anim_offset", offsets[i], times[i]).set_trans(Tween.TRANS_SINE)


func play_pickup() -> void:
	_play([Vector3(-0.03, -0.12, -0.02), Vector3.ZERO], [0.14, 0.25])
	_left("pickup", 0.5)


func play_reach() -> void:
	_play([Vector3(-0.02, 0.0, -0.08), Vector3.ZERO], [0.1, 0.2])
	_left("reach", 0.42)


func play_use() -> void:
	_play([Vector3(0, -0.15, 0.05), Vector3(0, -0.15, 0.05), Vector3.ZERO], [0.15, 0.25, 0.25])
	_left("use", 0.65)


func play_inspect(on: bool) -> void:
	_play([Vector3(-0.12, 0.08, 0.08) if on else Vector3.ZERO], [0.25])
	_inspecting = on
