class_name GripModifier
extends SkeletonModifier3D
## Closes a teammate's right hand round their flashlight, on top of whatever
## clip is playing (the clips are authored with open hands).

var curl := 0.9
var _axes := {}


func _ready() -> void:
	var skel := get_skeleton()
	if skel and skel.find_bone("hand_r") >= 0 and skel.find_bone("index_01_r") >= 0:
		_axes = HandGrip.curl_axes(skel, "r")


func _process_modification_with_delta(_delta: float) -> void:
	var skel := get_skeleton()
	if skel and not _axes.is_empty():
		HandGrip.apply_curl(skel, _axes, curl, false)
