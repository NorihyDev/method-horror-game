class_name LookModifier
extends SkeletonModifier3D
## Tilts a teammate's upper body and head to where they are looking (pitch),
## on top of whatever clip is playing: walking legs, looking up the stairs.
## Applied after the animation every frame, never stored in the clip.

## Share of the pitch taken by each bone, chest to head.
const SPLIT := {"spine_03": 0.2, "neck_01": 0.3, "head": 0.5}

## Radians, positive looks up.
var pitch := 0.0
## Frames the tilt was applied (tests).
var applied := 0
var _axis := {}


func _ready() -> void:
	var skel := get_skeleton()
	if skel == null:
		return
	for bone_name in SPLIT:
		var bi := skel.find_bone(bone_name)
		if bi >= 0:
			# The character's right (it faces +Z in its own space: right is -X),
			# in the bone's own frame.
			var g := skel.get_bone_global_rest(bi).basis.orthonormalized()
			_axis[bi] = [(g.inverse() * Vector3(-1, 0, 0)).normalized(), float(SPLIT[bone_name])]


func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel == null or absf(pitch) < 0.01:
		return
	applied += 1
	for bi: int in _axis:
		var entry: Array = _axis[bi]
		var q := Quaternion(entry[0], pitch * float(entry[1]))
		skel.set_bone_pose_rotation(bi, skel.get_bone_pose_rotation(bi) * q)
