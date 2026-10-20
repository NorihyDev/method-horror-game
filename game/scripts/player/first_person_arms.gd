class_name FirstPersonArms
extends Node3D
## The player's own arms in first person: the chosen character's model cut
## down to its arms and hands (jersey sleeves included) and posed every frame
## with two-bone IK. The right hand grips the flashlight wherever the
## viewmodel sways it; the left hand hangs out of view, pumps when sprinting,
## and reaches out to use or pick things up. Lives in camera space (+X right,
## +Y up, -Z forward).

const ARM_PREFIXES := ["clavicle", "upperarm", "lowerarm", "hand", "thumb", "index", "middle", "ring", "pinky"]
const DROP_MESHES := ["head", "hair", "shoe", "eye", "teeth", "tongue", "brow", "lash"]
const FINGERS := ["index", "middle", "ring", "pinky"]
## Where the shoulders sit below the eye. How far forward depends on the arm
## length: the flashlight grip sits at about 85 % of the arm's reach.
const SHOULDER_DROP := -0.24
const GRIP_REACH := 0.48

var skeleton: Skeleton3D
var ready_ok := false
## 0..1 how far the left hand is brought into play, and what it is doing.
var left_mix := 0.0
var left_action := ""
## Roll of each hand about its fingers, in radians. The characters' knuckle
## line sits a quarter turn from the side the viewmodel names: at PI / 2 the
## player sees the backs of the hands (a fist round the flashlight, a reach
## back-of-hand up); at 0 the palms faced the camera.
var hand_roll := {"l": PI / 2, "r": PI / 2}

var _model: Node3D
var _skel_xf := Transform3D.IDENTITY
var _bone := {}
var _rest := {}
var _len := {}
var _curl_axis := {}
var _palm_sign := {}
var _curl_axes := {}
var _grip_cache := {}


func setup(character_id: String) -> bool:
	var path := CharacterCatalog.scene_path(character_id)
	if not ResourceLoader.exists(path):
		return false
	var packed := load(path) as PackedScene
	if packed == null:
		return false
	_model = packed.instantiate() as Node3D
	add_child(_model)
	skeleton = _model.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton == null:
		_model.queue_free()
		return false
	for ap in _model.find_children("*", "AnimationPlayer", true, false):
		ap.free()
	for side in ["l", "r"]:
		for b in ["clavicle", "upperarm", "lowerarm", "hand", "middle_01", "thumb_01", "index_01", "pinky_01"]:
			var idx := skeleton.find_bone("%s_%s" % [b, side])
			if idx < 0:
				_model.queue_free()
				return false
			_bone["%s_%s" % [b, side]] = idx
	for i in skeleton.get_bone_count():
		_rest[i] = skeleton.get_bone_rest(i)
	for mi: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		var lower := String(mi.name).to_lower()
		var drop := false
		for word in DROP_MESHES:
			drop = drop or lower.contains(word)
		var arms := null if drop else _arms_only(mi)
		if arms == null:
			mi.queue_free()
			continue
		mi.mesh = arms
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 2.0
	_measure()
	_place()
	ready_ok = true
	return true


## Keeps only the triangles skinned (mostly) to clavicle, arm, hand and
## finger bones: no torso, legs or head ever enter the view.
func _arms_only(mi: MeshInstance3D) -> ArrayMesh:
	var src := mi.mesh
	var skin := mi.skin
	if src == null or skin == null:
		return null
	var is_arm: Array[bool] = []
	for b in skin.get_bind_count():
		var bone_name := String(skin.get_bind_name(b))
		if bone_name.is_empty():
			bone_name = skeleton.get_bone_name(skin.get_bind_bone(b))
		var arm := false
		for p in ARM_PREFIXES:
			arm = arm or bone_name.begins_with(p)
		is_arm.append(arm)
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		if verts.is_empty() or bones.is_empty():
			continue
		var per := bones.size() / verts.size()
		var keep := PackedByteArray()
		keep.resize(verts.size())
		for v in verts.size():
			var w := 0.0
			for k in per:
				var bi := bones[v * per + k]
				if bi < is_arm.size() and is_arm[bi]:
					w += weights[v * per + k]
			keep[v] = 1 if w >= 0.5 else 0
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			for v in verts.size():
				idx.append(v)
		var kept := PackedInt32Array()
		for t in range(0, idx.size() - 2, 3):
			if keep[idx[t]] and keep[idx[t + 1]] and keep[idx[t + 2]]:
				kept.append_array([idx[t], idx[t + 1], idx[t + 2]])
		if kept.is_empty():
			continue
		arrays[Mesh.ARRAY_INDEX] = kept
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		var mat := mi.get_surface_override_material(s)
		out.surface_set_material(out.get_surface_count() - 1, mat if mat else src.surface_get_material(s))
	return out if out.get_surface_count() > 0 else null


## Turns the body to face -Z and puts its shoulders just below the eye.
func _place() -> void:
	var rel := Transform3D.IDENTITY
	var n: Node = skeleton
	while n != _model and n is Node3D:
		rel = (n as Node3D).transform * rel
		n = n.get_parent()
	var mid := (
		(
			skeleton.get_bone_global_rest(_bone["upperarm_l"]).origin
			+ skeleton.get_bone_global_rest(_bone["upperarm_r"]).origin
		)
		* 0.5
	)
	var turn := Basis(Vector3.UP, PI)
	var reach := minf(_len["a_r"] + _len["b_r"], _len["a_l"] + _len["b_l"])
	var shoulders := Vector3(0.0, SHOULDER_DROP, reach - GRIP_REACH)
	_model.transform = Transform3D(turn, shoulders - turn * (rel * mid))
	_skel_xf = _model.transform * rel


func _measure() -> void:
	for side in ["l", "r"]:
		var u := skeleton.get_bone_global_rest(_bone["upperarm_" + side]).origin
		var l := skeleton.get_bone_global_rest(_bone["lowerarm_" + side]).origin
		var h := skeleton.get_bone_global_rest(_bone["hand_" + side])
		_len["a_" + side] = u.distance_to(l)
		_len["b_" + side] = l.distance_to(h.origin)
		# Fingers bend around the axis running across the knuckles; which way
		# is "into the palm" comes from where the thumb sits.
		var f := skeleton.get_bone_global_rest(_bone["middle_01_" + side]).origin - h.origin
		var across := (
			skeleton.get_bone_global_rest(_bone["index_01_" + side]).origin
			- skeleton.get_bone_global_rest(_bone["pinky_01_" + side]).origin
		)
		var thumb := skeleton.get_bone_global_rest(_bone["thumb_01_" + side]).origin - h.origin
		var palm := f.cross(across).normalized()
		_palm_sign[side] = 1.0 if palm.dot(thumb) >= 0.0 else -1.0
		for finger in FINGERS + ["thumb"]:
			for j in [1, 2, 3]:
				var bi := skeleton.find_bone("%s_%02d_%s" % [finger, j, side])
				if bi >= 0:
					var g := skeleton.get_bone_global_rest(bi).basis.orthonormalized()
					_curl_axis[bi] = (g.inverse() * across.normalized()).normalized()


## Poses one arm. `wrist`, `fingers` (wrist to knuckles), `thumb_up` (index-
## finger side of the hand) and `pole` (where the elbow points) are in camera space;
## `curl` closes the fingers (0 open, 1 fist).
func pose_arm(side: String, wrist: Vector3, fingers: Vector3, thumb_up: Vector3, pole: Vector3, curl: float) -> void:
	if not ready_ok:
		return
	var inv := _skel_xf.affine_inverse()
	var target := inv * wrist
	var f_des := (inv.basis * fingers).normalized()
	var t_des := (inv.basis * thumb_up).normalized().rotated(f_des, float(hand_roll[side]))
	var pole_s := (inv.basis * pole).normalized()
	var ua: int = _bone["upperarm_" + side]
	var la: int = _bone["lowerarm_" + side]
	var hd: int = _bone["hand_" + side]
	var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(ua))
	var lu: Transform3D = _rest[ua]
	var ll: Transform3D = _rest[la]
	var lh: Transform3D = _rest[hd]
	var gu := parent * lu
	var s := gu.origin
	var a: float = _len["a_" + side]
	var b: float = _len["b_" + side]
	var to := target - s
	var d := clampf(to.length(), 0.05, a + b - 0.001)
	var dir := to.normalized()
	var perp := pole_s - dir * pole_s.dot(dir)
	perp = perp.normalized() if perp.length() > 0.001 else Vector3.UP
	var cos_a := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var elbow := s + dir * a * cos_a + perp * a * sqrt(1.0 - cos_a * cos_a)
	var hand_at := s + dir * d
	# Upper arm towards the elbow.
	var e0 := (gu * ll).origin
	var bu := Basis(Quaternion((e0 - s).normalized(), (elbow - s).normalized())) * gu.basis
	skeleton.set_bone_pose_rotation(ua, (parent.basis.inverse() * bu).get_rotation_quaternion())
	gu = Transform3D(bu, s)
	# Forearm towards the wrist.
	var gl := gu * ll
	var h0 := (gl * lh).origin
	var bl := Basis(Quaternion((h0 - gl.origin).normalized(), (hand_at - gl.origin).normalized())) * gl.basis
	skeleton.set_bone_pose_rotation(la, (gu.basis.inverse() * bl).get_rotation_quaternion())
	gl = Transform3D(bl, gl.origin)
	# Hand: match the fingers' direction and the thumb's side.
	var gh := gl * lh
	var mid := (gh * (_rest[_bone["middle_01_" + side]] as Transform3D)).origin - gh.origin
	# The knuckle line (pinky to index) says which way the hand is rolled.
	var idx := (gh * (_rest[_bone["index_01_" + side]] as Transform3D)).origin
	var pky := (gh * (_rest[_bone["pinky_01_" + side]] as Transform3D)).origin
	var bh := _frame(f_des, t_des) * _frame(mid, idx - pky).inverse() * gh.basis
	skeleton.set_bone_pose_rotation(hd, (gl.basis.inverse() * bh).get_rotation_quaternion())
	_curl(side, curl)


## Poses an arm so the fist closes round a held object: `grip` is where the
## object passes through the fist, `along` the object's axis (it runs along
## the knuckle line, index side first), `fingers` the back of the hand's
## direction (wrist to knuckles). All in camera space.
func pose_grip(side: String, grip: Vector3, along: Vector3, fingers: Vector3, pole: Vector3, curl: float) -> void:
	if not ready_ok:
		return
	var inv := _skel_xf.affine_inverse()
	var f_s := (inv.basis * fingers).normalized()
	var a_s := (inv.basis * along).normalized()
	var mid_loc := (_rest[_bone["middle_01_" + side]] as Transform3D).origin
	# Rest-pose hand geometry never changes: work it out once per hand.
	if not _grip_cache.has(side):
		_grip_cache[side] = [HandGrip.across_local(skeleton, side), HandGrip.grip_local(skeleton, side)]
	var cached: Array = _grip_cache[side]
	var bh := _frame(f_s, a_s) * _frame(mid_loc, cached[0]).inverse()
	var wrist_s := inv * grip - bh * (cached[1] as Vector3)
	# pose_arm rolls its index-side vector by hand_roll: pre-roll it back.
	var f_c := fingers.normalized()
	var t_c := along.normalized().rotated(f_c, -float(hand_roll[side]))
	pose_arm(side, _skel_xf * wrist_s, f_c, t_c, pole, curl)


static func _frame(f: Vector3, t: Vector3) -> Basis:
	var x := f.normalized()
	var y := (t - x * t.dot(x)).normalized()
	return Basis(x, y, x.cross(y))


func _curl(side: String, curl: float) -> void:
	if not _curl_axes.has(side):
		_curl_axes[side] = HandGrip.curl_axes(skeleton, side)
	HandGrip.apply_curl(skeleton, _curl_axes[side], curl, true)
