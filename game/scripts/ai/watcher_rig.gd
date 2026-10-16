class_name WatcherRig
extends Node3D
## Procedural articulated body for The Watcher with an AnimationPlayer
## library authored in code. Joints are Node3D pivots so animations are plain
## rotation tracks. Replacement path: an imported rigged model exposing the
## same animation names (see docs/asset-replacement.md).

signal foot_planted

const ANIMS: PackedStringArray = [
	"idle",
	"walk",
	"run",
	"search",
	"alert",
	"windup",
	"strike",
	"recover",
	"hit",
	"open_door",
]

var anim: AnimationPlayer
var joints: Dictionary = {}
var lens_mat: StandardMaterial3D
var _coat: Node3D
var _current := ""


func _ready() -> void:
	_build_body()
	anim = AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	add_child(anim)
	anim.root_node = anim.get_path_to(self)
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _idle())
	lib.add_animation("walk", _gait(1.25, 26.0, 16.0, 12.0, 0.05))
	lib.add_animation("run", _gait(0.72, 38.0, 28.0, 28.0, 0.09, true))
	lib.add_animation("search", _search())
	lib.add_animation("alert", _alert())
	lib.add_animation("windup", _windup())
	lib.add_animation("strike", _strike())
	lib.add_animation("recover", _recover())
	lib.add_animation("hit", _hit())
	lib.add_animation("open_door", _open_door())
	anim.add_animation_library("", lib)
	play("idle")


func play(anim_name: String, blend: float = 0.25, speed: float = 1.0) -> void:
	if anim == null:
		return
	if anim_name == _current and anim.is_playing():
		anim.speed_scale = speed
		return
	_current = anim_name
	anim.play(anim_name, blend)
	anim.speed_scale = speed


func current() -> String:
	return _current


func set_lens_intensity(k: float) -> void:
	if lens_mat:
		lens_mat.emission_energy_multiplier = lerpf(0.6, 4.0, clampf(k, 0.0, 1.0))


## Called by the foot-plant method track.
func _on_foot() -> void:
	foot_planted.emit()


# --- Body ----------------------------------------------------------------------------


func _joint(joint_name: String, parent: Node3D, pos: Vector3) -> Node3D:
	var j := Node3D.new()
	j.name = joint_name
	j.position = pos
	parent.add_child(j)
	joints[joint_name] = j
	return j


func _limb(parent: Node3D, size: Vector3, offset: Vector3, mat: Material, capsule: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if capsule:
		var c := CapsuleMesh.new()
		c.radius = size.x * 0.5
		c.height = size.y
		c.radial_segments = 8
		c.rings = 2
		mi.mesh = c
	else:
		var b := BoxMesh.new()
		b.size = size
		mi.mesh = b
	mi.material_override = mat
	mi.position = offset
	parent.add_child(mi)
	return mi


func _build_body() -> void:
	var skin := MaterialLib.flat(Color(0.36, 0.34, 0.31), 0.85)
	var cloth := MaterialLib.flat(Color(0.07, 0.07, 0.075), 0.95)
	var coat := MaterialLib.flat(Color(0.11, 0.1, 0.09), 0.95)
	var bandage := MaterialLib.flat(Color(0.34, 0.31, 0.26), 0.95)
	var brass := MaterialLib.flat(Color(0.45, 0.36, 0.18), 0.35, 0.8)
	lens_mat = StandardMaterial3D.new()
	lens_mat.albedo_color = Color(0.5, 0.05, 0.03)
	lens_mat.emission_enabled = true
	lens_mat.emission = Color(0.75, 0.08, 0.04)
	lens_mat.emission_energy_multiplier = 0.6
	lens_mat.roughness = 0.1

	var hips := _joint("Hips", self, Vector3(0, 1.08, 0))
	_limb(hips, Vector3(0.36, 0.18, 0.2), Vector3.ZERO, cloth)
	var spine := _joint("Spine", hips, Vector3(0, 0.1, 0))
	_limb(spine, Vector3(0.3, 0.32, 0.18), Vector3(0, 0.16, 0), cloth)
	var chest := _joint("Chest", spine, Vector3(0, 0.32, 0))
	_limb(chest, Vector3(0.44, 0.34, 0.22), Vector3(0, 0.15, 0), coat)
	var neck := _joint("Neck", chest, Vector3(0, 0.34, 0.02))
	_limb(neck, Vector3(0.09, 0.2, 0.09), Vector3(0, 0.08, 0), skin, true)
	var head := _joint("Head", neck, Vector3(0, 0.2, 0.02))
	_limb(head, Vector3(0.21, 0.34, 0.21), Vector3(0, 0.12, 0), bandage, true)
	for i in 4:
		var wrap := _limb(head, Vector3(0.225, 0.025, 0.225), Vector3(0, 0.04 + i * 0.06, 0), bandage)
		wrap.rotation = Vector3(0.12 * (1 if i % 2 == 0 else -1), i * 0.5, 0)
	# Brass optical apparatus: a ring and uneven lenses where the eyes should be.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.075
	torus.outer_radius = 0.1
	torus.rings = 16
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = brass
	ring.rotation = Vector3(PI / 2, 0, 0)
	ring.position = Vector3(0, 0.15, 0.1)
	head.add_child(ring)
	for lens_pos in [Vector3(-0.035, 0.17, 0.12), Vector3(0.04, 0.155, 0.12), Vector3(0.0, 0.11, 0.12)]:
		var lens := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.017
		sphere.height = 0.034
		sphere.radial_segments = 8
		sphere.rings = 4
		lens.mesh = sphere
		lens.material_override = lens_mat
		lens.position = lens_pos
		head.add_child(lens)

	for side in [-1, 1]:
		var tag := "L" if side < 0 else "R"
		var shoulder := _joint("Shoulder" + tag, chest, Vector3(side * 0.26, 0.28, 0))
		_limb(shoulder, Vector3(0.08, 0.5, 0.08), Vector3(0, -0.24, 0), coat, true)
		var elbow := _joint("Elbow" + tag, shoulder, Vector3(0, -0.48, 0))
		_limb(elbow, Vector3(0.065, 0.48, 0.065), Vector3(0, -0.23, 0), skin, true)
		var hand := _joint("Hand" + tag, elbow, Vector3(0, -0.47, 0))
		_limb(hand, Vector3(0.07, 0.1, 0.03), Vector3(0, -0.04, 0), skin)
		for f in 3:
			var finger := _limb(hand, Vector3(0.012, 0.17, 0.012), Vector3((f - 1) * 0.022, -0.16, 0), skin)
			finger.rotation.z = (f - 1) * 0.08
		var hip := _joint("Hip" + tag, hips, Vector3(side * 0.12, -0.06, 0))
		_limb(hip, Vector3(0.1, 0.52, 0.1), Vector3(0, -0.25, 0), cloth, true)
		var knee := _joint("Knee" + tag, hip, Vector3(0, -0.5, 0))
		_limb(knee, Vector3(0.08, 0.5, 0.08), Vector3(0, -0.24, 0), cloth, true)
		var foot := _joint("Foot" + tag, knee, Vector3(0, -0.5, 0))
		_limb(foot, Vector3(0.1, 0.06, 0.26), Vector3(0, -0.02, 0.06), cloth)
	# Long coat skirt hanging from the chest; sways with the hips.
	_coat = _joint("Coat", chest, Vector3(0, 0.0, 0))
	for side in [-1, 1]:
		var panel := _limb(_coat, Vector3(0.24, 0.95, 0.03), Vector3(side * 0.12, -0.42, 0.13), coat)
		panel.rotation.x = deg_to_rad(-6)
		var back := _limb(_coat, Vector3(0.24, 1.0, 0.03), Vector3(side * 0.12, -0.45, -0.12), coat)
		back.rotation.x = deg_to_rad(6)
	for m in _coat.get_children():
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


# --- Animation authoring -----------------------------------------------------------------


func _track(a: Animation, joint: String, keys: Array, interp: int = Animation.INTERPOLATION_CUBIC) -> void:
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(_path(joint) + ":rotation"))
	a.track_set_interpolation_type(t, interp)
	for k in keys:
		var e: Vector3 = k[1]
		a.track_insert_key(t, float(k[0]), Vector3(deg_to_rad(e.x), deg_to_rad(e.y), deg_to_rad(e.z)))


func _pos_track(a: Animation, joint: String, keys: Array) -> void:
	var t := a.add_track(Animation.TYPE_VALUE)
	a.track_set_path(t, NodePath(_path(joint) + ":position"))
	a.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	for k in keys:
		a.track_insert_key(t, float(k[0]), k[1])


func _method_track(a: Animation, times: Array) -> void:
	var t := a.add_track(Animation.TYPE_METHOD)
	a.track_set_path(t, NodePath("."))
	for time in times:
		a.track_insert_key(t, float(time), {"method": "_on_foot", "args": []})


func _path(joint: String) -> String:
	var node: Node = joints[joint]
	return str(get_path_to(node))


func _anim(length: float, loop: bool) -> Animation:
	var a := Animation.new()
	a.length = length
	a.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	return a


func _idle() -> Animation:
	var a := _anim(3.2, true)
	_track(a, "Spine", [[0, Vector3(14, 0, 0)], [1.6, Vector3(17, 0, 1)], [3.2, Vector3(14, 0, 0)]])
	_track(a, "Chest", [[0, Vector3(8, 0, 0)], [1.6, Vector3(11, 0, 0)], [3.2, Vector3(8, 0, 0)]])
	_track(a, "Neck", [[0, Vector3(10, 0, 0)], [2.2, Vector3(8, 0, 0)], [3.2, Vector3(10, 0, 0)]])
	_track(
		a,
		"Head",
		[[0, Vector3(-6, 0, 8)], [1.4, Vector3(-4, 12, 14)], [2.4, Vector3(-8, -6, 4)], [3.2, Vector3(-6, 0, 8)]]
	)
	for s in ["L", "R"]:
		var sign := -1.0 if s == "L" else 1.0
		_track(
			a,
			"Shoulder" + s,
			[[0, Vector3(4, 0, sign * 6)], [1.6, Vector3(8, 0, sign * 8)], [3.2, Vector3(4, 0, sign * 6)]]
		)
		_track(a, "Elbow" + s, [[0, Vector3(-12, 0, 0)], [1.6, Vector3(-16, 0, 0)], [3.2, Vector3(-12, 0, 0)]])
		_track(
			a,
			"Hand" + s,
			[[0, Vector3(0, 0, 0)], [0.8, Vector3(-18, 0, 0)], [0.9, Vector3(5, 0, 0)], [3.2, Vector3(0, 0, 0)]]
		)
		_track(a, "Hip" + s, [[0, Vector3(-6, 0, 0)], [3.2, Vector3(-6, 0, 0)]])
		_track(a, "Knee" + s, [[0, Vector3(10, 0, 0)], [3.2, Vector3(10, 0, 0)]])
		_track(a, "Foot" + s, [[0, Vector3(-4, 0, 0)], [3.2, Vector3(-4, 0, 0)]])
	_pos_track(a, "Hips", [[0, Vector3(0, 1.04, 0)], [1.6, Vector3(0, 1.02, 0)], [3.2, Vector3(0, 1.04, 0)]])
	return a


## Generic gait: `swing` thigh amplitude, `arm` arm swing, `lean` torso lean.
func _gait(length: float, swing: float, arm: float, lean: float, bounce: float, reaching: bool = false) -> Animation:
	var a := _anim(length, true)
	var h := length * 0.5
	var q := length * 0.25
	_track(
		a,
		"Spine",
		[
			[0, Vector3(16 + lean * 0.5, 4, 0)],
			[h, Vector3(16 + lean * 0.5, -4, 0)],
			[length, Vector3(16 + lean * 0.5, 4, 0)]
		]
	)
	_track(
		a,
		"Chest",
		[
			[0, Vector3(6 + lean * 0.5, -6, 0)],
			[h, Vector3(6 + lean * 0.5, 6, 0)],
			[length, Vector3(6 + lean * 0.5, -6, 0)]
		]
	)
	_track(a, "Neck", [[0, Vector3(-lean * 0.4, 0, 0)], [length, Vector3(-lean * 0.4, 0, 0)]])
	_track(a, "Head", [[0, Vector3(-8, 4, 3)], [h, Vector3(-6, -4, -3)], [length, Vector3(-8, 4, 3)]])
	_pos_track(
		a,
		"Hips",
		[
			[0, Vector3(0, 1.06, 0)],
			[q, Vector3(0, 1.06 - bounce, 0)],
			[h, Vector3(0, 1.06, 0)],
			[h + q, Vector3(0, 1.06 - bounce, 0)],
			[length, Vector3(0, 1.06, 0)]
		]
	)
	for s in ["L", "R"]:
		var phase := 0.0 if s == "L" else h
		var sign := -1.0 if s == "L" else 1.0
		var hip_keys := []
		var knee_keys := []
		var foot_keys := []
		for i in 5:
			var t := fmod(phase + i * q, length)
			var stage := i % 4
			var hip_angle: float = [-swing, 0.0, swing * 0.8, 0.0][stage]
			var knee_angle: float = [8.0, 12.0, 8.0, swing * 1.6][stage]
			var foot_angle: float = [-10.0, 0.0, 12.0, -6.0][stage]
			hip_keys.append([t, Vector3(hip_angle, 0, 0)])
			knee_keys.append([t, Vector3(knee_angle, 0, 0)])
			foot_keys.append([t, Vector3(foot_angle, 0, 0)])
		hip_keys.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		knee_keys.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		foot_keys.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		_close_loop(hip_keys, length)
		_close_loop(knee_keys, length)
		_close_loop(foot_keys, length)
		_track(a, "Hip" + s, hip_keys)
		_track(a, "Knee" + s, knee_keys)
		_track(a, "Foot" + s, foot_keys)
		var arm_phase := h - phase
		if reaching:
			# Arms stretched forward while running: a key part of its silhouette.
			_track(
				a,
				"Shoulder" + s,
				[
					[0, Vector3(-62 + sign * 6, 0, sign * 10)],
					[h, Vector3(-58 - sign * 6, 0, sign * 10)],
					[length, Vector3(-62 + sign * 6, 0, sign * 10)]
				]
			)
			_track(a, "Elbow" + s, [[0, Vector3(-18, 0, 0)], [h, Vector3(-28, 0, 0)], [length, Vector3(-18, 0, 0)]])
		else:
			_track(
				a,
				"Shoulder" + s,
				[
					[0, Vector3(arm * (1.0 if arm_phase == 0.0 else -1.0), 0, sign * 6)],
					[h, Vector3(arm * (-1.0 if arm_phase == 0.0 else 1.0), 0, sign * 6)],
					[length, Vector3(arm * (1.0 if arm_phase == 0.0 else -1.0), 0, sign * 6)]
				]
			)
			_track(a, "Elbow" + s, [[0, Vector3(-14, 0, 0)], [length, Vector3(-14, 0, 0)]])
	_method_track(a, [0.0, h])
	return a


static func _close_loop(keys: Array, length: float) -> void:
	if keys.is_empty():
		return
	if float(keys[0][0]) > 0.0:
		keys.push_front([0.0, keys[keys.size() - 1][1]])
	keys.append([length, keys[0][1]])


func _search() -> Animation:
	var a := _anim(3.0, true)
	_track(a, "Spine", [[0, Vector3(12, 0, 0)], [3.0, Vector3(12, 0, 0)]])
	_track(
		a,
		"Chest",
		[
			[0, Vector3(4, 0, 0)],
			[0.8, Vector3(4, 25, 0)],
			[1.6, Vector3(4, 25, 0)],
			[2.2, Vector3(4, -25, 0)],
			[3.0, Vector3(4, 0, 0)]
		]
	)
	_track(
		a,
		"Head",
		[
			[0, Vector3(-4, 0, 0)],
			[0.5, Vector3(-4, 35, 10)],
			[0.6, Vector3(-4, 40, 12)],
			[1.7, Vector3(0, 40, 5)],
			[1.9, Vector3(-4, -45, -10)],
			[2.6, Vector3(-2, -40, -8)],
			[3.0, Vector3(-4, 0, 0)]
		],
		Animation.INTERPOLATION_LINEAR
	)
	for s in ["L", "R"]:
		var sign := -1.0 if s == "L" else 1.0
		_track(a, "Shoulder" + s, [[0, Vector3(-10, 0, sign * 12)], [3.0, Vector3(-10, 0, sign * 12)]])
		_track(a, "Elbow" + s, [[0, Vector3(-30, 0, 0)], [3.0, Vector3(-30, 0, 0)]])
		_track(a, "Hip" + s, [[0, Vector3(-4, 0, 0)], [3.0, Vector3(-4, 0, 0)]])
		_track(a, "Knee" + s, [[0, Vector3(8, 0, 0)], [3.0, Vector3(8, 0, 0)]])
	return a


func _alert() -> Animation:
	var a := _anim(0.7, false)
	_track(a, "Spine", [[0, Vector3(14, 0, 0)], [0.25, Vector3(2, 0, 0)], [0.7, Vector3(6, 0, 0)]])
	_track(
		a,
		"Neck",
		[[0, Vector3(10, 0, 0)], [0.15, Vector3(-10, 0, 0)], [0.7, Vector3(-4, 0, 0)]],
		Animation.INTERPOLATION_LINEAR
	)
	_track(
		a,
		"Head",
		[[0, Vector3(0, 0, 0)], [0.12, Vector3(-15, 0, 25)], [0.7, Vector3(-8, 0, 15)]],
		Animation.INTERPOLATION_LINEAR
	)
	for s in ["L", "R"]:
		var sign := -1.0 if s == "L" else 1.0
		_track(
			a,
			"Shoulder" + s,
			[[0, Vector3(0, 0, sign * 6)], [0.3, Vector3(-25, 0, sign * 30)], [0.7, Vector3(-20, 0, sign * 20)]]
		)
		_track(a, "Elbow" + s, [[0, Vector3(-12, 0, 0)], [0.3, Vector3(-40, 0, 0)], [0.7, Vector3(-30, 0, 0)]])
	return a


func _windup() -> Animation:
	var a := _anim(1.0, false)
	_track(a, "Spine", [[0, Vector3(14, 0, 0)], [1.0, Vector3(-8, 0, 0)]])
	_track(a, "Chest", [[0, Vector3(6, 0, 0)], [1.0, Vector3(-10, 0, 0)]])
	_track(a, "Head", [[0, Vector3(-6, 0, 0)], [1.0, Vector3(-30, 0, 10)]])
	for s in ["L", "R"]:
		var sign := -1.0 if s == "L" else 1.0
		_track(a, "Shoulder" + s, [[0, Vector3(0, 0, sign * 6)], [1.0, Vector3(-165, 0, sign * 25)]])
		_track(a, "Elbow" + s, [[0, Vector3(-12, 0, 0)], [1.0, Vector3(-45, 0, 0)]])
		_track(a, "Hand" + s, [[0, Vector3(0, 0, 0)], [1.0, Vector3(-30, 0, 0)]])
	return a


func _strike() -> Animation:
	var a := _anim(0.28, false)
	_track(a, "Spine", [[0, Vector3(-8, 0, 0)], [0.28, Vector3(38, 0, 0)]], Animation.INTERPOLATION_LINEAR)
	_track(a, "Chest", [[0, Vector3(-10, 0, 0)], [0.28, Vector3(18, 0, 0)]], Animation.INTERPOLATION_LINEAR)
	_track(a, "Head", [[0, Vector3(-30, 0, 10)], [0.28, Vector3(10, 0, 0)]], Animation.INTERPOLATION_LINEAR)
	for s in ["L", "R"]:
		var sign := -1.0 if s == "L" else 1.0
		_track(
			a,
			"Shoulder" + s,
			[[0, Vector3(-165, 0, sign * 25)], [0.28, Vector3(-40, 0, sign * 8)]],
			Animation.INTERPOLATION_LINEAR
		)
		_track(a, "Elbow" + s, [[0, Vector3(-45, 0, 0)], [0.28, Vector3(-5, 0, 0)]], Animation.INTERPOLATION_LINEAR)
	return a


func _recover() -> Animation:
	var a := _anim(1.2, false)
	_track(a, "Spine", [[0, Vector3(38, 0, 0)], [0.5, Vector3(30, 0, 4)], [1.2, Vector3(14, 0, 0)]])
	_track(a, "Chest", [[0, Vector3(18, 0, 0)], [1.2, Vector3(6, 0, 0)]])
	_track(a, "Head", [[0, Vector3(10, 0, 0)], [0.6, Vector3(0, 0, 18)], [1.2, Vector3(-6, 0, 6)]])
	for s in ["L", "R"]:
		var sign := -1.0 if s == "L" else 1.0
		_track(a, "Shoulder" + s, [[0, Vector3(-40, 0, sign * 8)], [1.2, Vector3(4, 0, sign * 6)]])
		_track(a, "Elbow" + s, [[0, Vector3(-5, 0, 0)], [1.2, Vector3(-12, 0, 0)]])
	return a


func _hit() -> Animation:
	var a := _anim(0.6, false)
	_track(a, "Spine", [[0, Vector3(14, 0, 0)], [0.1, Vector3(-6, 0, -8)], [0.6, Vector3(14, 0, 0)]])
	_track(a, "Head", [[0, Vector3(0, 0, 0)], [0.1, Vector3(-20, 0, -20)], [0.6, Vector3(-6, 0, 0)]])
	return a


func _open_door() -> Animation:
	var a := _anim(0.6, false)
	_track(a, "ShoulderR", [[0, Vector3(4, 0, 6)], [0.25, Vector3(-80, 0, 10)], [0.6, Vector3(-30, 0, 8)]])
	_track(a, "ElbowR", [[0, Vector3(-12, 0, 0)], [0.25, Vector3(-5, 0, 0)], [0.6, Vector3(-12, 0, 0)]])
	_track(a, "Chest", [[0, Vector3(6, 0, 0)], [0.25, Vector3(10, -15, 0)], [0.6, Vector3(6, 0, 0)]])
	return a
