class_name HandGrip
extends RefCounted
## Where a character's hand holds something, from its own finger bones: the
## middle of the closed fist (between the knuckles, a little towards the
## palm), the knuckle line (pinky to index, the axis a held flashlight runs
## along) and the axis each finger bone curls around. Shared by the
## first-person arms and the teammate models.

const FINGERS := ["index", "middle", "ring", "pinky", "thumb"]
## Which way round the fingers' axis folds the thumb into the palm.
const THUMB_FOLD := -1.0


## Fist centre in the hand bone's own space.
static func grip_local(skel: Skeleton3D, side: String) -> Vector3:
	var hand := skel.find_bone("hand_" + side)
	var g := skel.get_bone_global_rest(hand)
	var inv := g.affine_inverse()
	var knuckles := Vector3.ZERO
	for f in ["index", "middle", "ring", "pinky"]:
		knuckles += inv * skel.get_bone_global_rest(skel.find_bone("%s_01_%s" % [f, side])).origin
	knuckles /= 4.0
	return knuckles * 0.85 + palm_local(skel, side) * 0.022


## Unit vector out of the palm, in the hand bone's space.
static func palm_local(skel: Skeleton3D, side: String) -> Vector3:
	var g := skel.get_bone_global_rest(skel.find_bone("hand_" + side))
	var f := _pos(skel, "middle_01_" + side) - g.origin
	var across := _pos(skel, "index_01_" + side) - _pos(skel, "pinky_01_" + side)
	var thumb := _pos(skel, "thumb_01_" + side) - g.origin
	var palm := f.cross(across).normalized()
	if palm.dot(thumb) < 0.0:
		palm = -palm
	return (g.basis.orthonormalized().inverse() * palm).normalized()


## Knuckle line (pinky -> index) in the hand bone's space, square to the
## fingers (the index knuckle sits further along the hand than the pinky's).
static func across_local(skel: Skeleton3D, side: String) -> Vector3:
	var g := skel.get_bone_global_rest(skel.find_bone("hand_" + side))
	var f := (_pos(skel, "middle_01_" + side) - g.origin).normalized()
	var across := _pos(skel, "index_01_" + side) - _pos(skel, "pinky_01_" + side)
	across -= f * across.dot(f)
	return (g.basis.orthonormalized().inverse() * across).normalized()


## Finger bone index -> [local curl axis, share of the curl], for one hand.
static func curl_axes(skel: Skeleton3D, side: String) -> Dictionary:
	var out := {}
	var g := skel.get_bone_global_rest(skel.find_bone("hand_" + side))
	var f := _pos(skel, "middle_01_" + side) - g.origin
	var across := _pos(skel, "index_01_" + side) - _pos(skel, "pinky_01_" + side)
	var palm := g.basis.orthonormalized() * palm_local(skel, side)
	# Curling turns the finger from pointing along `f` towards the palm.
	var axis := f.cross(palm).normalized()
	if axis.length() < 0.5:
		axis = across.normalized()
	for finger in FINGERS:
		for j in [1, 2, 3]:
			var bi := skel.find_bone("%s_%02d_%s" % [finger, j, side])
			if bi < 0:
				continue
			var gb := skel.get_bone_global_rest(bi).basis.orthonormalized()
			# The thumb folds across the palm (round the fingers' axis).
			var ax := f.normalized() * THUMB_FOLD if finger == "thumb" else axis
			var share := 0.8 if finger == "thumb" else (1.2 if j == 1 else 1.45)
			out[bi] = [(gb.inverse() * ax).normalized(), share]
	return out


## Applies a curl (0 open .. 1 fist) on top of the current pose.
static func apply_curl(skel: Skeleton3D, axes: Dictionary, curl: float, from_rest: bool) -> void:
	for bi: int in axes:
		var entry: Array = axes[bi]
		var base := (
			skel.get_bone_rest(bi).basis.get_rotation_quaternion() if from_rest else skel.get_bone_pose_rotation(bi)
		)
		skel.set_bone_pose_rotation(bi, base * Quaternion(entry[0], curl * float(entry[1])))


static func _pos(skel: Skeleton3D, bone: String) -> Vector3:
	return skel.get_bone_global_rest(skel.find_bone(bone)).origin
