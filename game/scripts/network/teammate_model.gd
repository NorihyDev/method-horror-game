class_name TeammateModel
extends Node3D
## The animated character other players see (Punky, built with MPFB in
## Blender: see docs/characters.md). Picks a looping clip from the avatar's
## speed, crouch and downed state, and holds a flashlight in the right hand.

const SCENE := "res://assets/characters/punky/punky.glb"
const CLIPS: Array[String] = ["idle", "walk", "run", "crouch_idle", "crouch_walk", "downed"]
## Speed (m/s) each cycle was authored at, printed by the Blender export.
const CLIP_SPEED := {"walk": 1.125, "run": 3.5, "crouch_walk": 0.733}
const RUN_ABOVE := 3.6
const MOVING_ABOVE := 0.3
const BLEND := 0.2
## Hair, brows, lashes and the clear cornea shell over each eye are cut out by
## their texture's alpha: scissored (no sorting, cheap on mobile).
const CARD_MATERIALS: Array[String] = ["hair", "eyebrow", "eyelash", "high-poly"]

var anim: AnimationPlayer
var current := ""


## Null when the model is missing, so callers can fall back to simple shapes.
static func create() -> TeammateModel:
	var packed := load(SCENE) as PackedScene if ResourceLoader.exists(SCENE) else null
	if packed == null:
		return null
	var model := TeammateModel.new()
	model.name = "Punky"
	var inst := packed.instantiate() as Node3D
	# Exported facing +Z; the game's forward is -Z.
	inst.rotation.y = PI
	model.add_child(inst)
	model.anim = inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	model._setup(inst)
	return model


func _setup(inst: Node3D) -> void:
	if anim:
		for clip in CLIPS:
			if anim.has_animation(clip):
				anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	for mi: MeshInstance3D in inst.find_children("*", "MeshInstance3D", true, false):
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for s in mi.get_surface_override_material_count():
			var mat := mi.mesh.surface_get_material(s) as BaseMaterial3D
			if mat and _is_card(mat.resource_name):
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				mat.alpha_scissor_threshold = 0.4
				mat.cull_mode = BaseMaterial3D.CULL_DISABLED
				if not "high-poly" in mat.resource_name:
					mat.roughness = 1.0
					mat.metallic_specular = 0.2
	var skel := inst.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel and skel.find_bone("hand_r") >= 0:
		var hold := BoneAttachment3D.new()
		hold.bone_name = "hand_r"
		skel.add_child(hold)
		var torch := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.022
		cyl.bottom_radius = 0.018
		cyl.height = 0.2
		torch.mesh = cyl
		torch.material_override = MaterialLib.flat(Color(0.15, 0.15, 0.16), 0.4, 0.6)
		torch.position = Vector3(0, 0.06, 0.03)
		hold.add_child(torch)
	play("idle")


static func _is_card(material_name: String) -> bool:
	for key in CARD_MATERIALS:
		if key in material_name.to_lower():
			return true
	return false


## Choose the clip for this frame. `speed` is horizontal m/s.
func update_motion(speed: float, crouch: bool, downed: bool) -> void:
	var clip := "idle"
	var scale := 1.0
	if downed:
		clip = "downed"
		scale = 0.4 if speed < MOVING_ABOVE else 1.0
	elif crouch:
		clip = "crouch_walk" if speed > MOVING_ABOVE else "crouch_idle"
	elif speed > RUN_ABOVE:
		clip = "run"
	elif speed > MOVING_ABOVE:
		clip = "walk"
	if CLIP_SPEED.has(clip):
		scale = clampf(speed / float(CLIP_SPEED[clip]), 0.6, 2.2)
	play(clip, scale)


func play(clip: String, scale: float = 1.0) -> void:
	if anim == null or not anim.has_animation(clip):
		return
	if clip != current:
		current = clip
		anim.play(clip, BLEND)
	anim.speed_scale = scale
