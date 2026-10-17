class_name PickupEntity
extends Interactable
## An item lying in the world. Taking it is an authoritative, atomic state
## change: two players pressing at once cannot both receive it.

static var _glint_tex: Texture2D

@export var item_id := ""
@export var count := 1
var dropped := false
var _visual: Node3D
var _glint: MeshInstance3D
var _glint_mat: StandardMaterial3D
var _time := 0.0


func _ready() -> void:
	prompt_key = "PROMPT_TAKE"
	_visual = ItemVisuals.build(item_id)
	add_child(_visual)
	_visual.rotation.y = randf() * TAU
	add_target(Vector3(0.3, 0.2, 0.3), Vector3(0, 0.08, 0))
	# A faint glint so items stay discoverable in the dark without a HUD marker.
	_glint = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	_glint.mesh = q
	_glint_mat = StandardMaterial3D.new()
	_glint_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glint_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_glint_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glint_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_glint_mat.albedo_texture = _glint_texture()
	_glint_mat.no_depth_test = false
	_glint.material_override = _glint_mat
	_glint.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glint.position = Vector3(0, 0.1, 0)
	add_child(_glint)


func _process(delta: float) -> void:
	_time += delta
	var strength := 0.55 if Settings.b("high_contrast") else 0.28
	_glint_mat.albedo_color = Color(1, 0.95, 0.85, strength * (0.55 + 0.45 * sin(_time * 2.4)))


func initial_state() -> Dictionary:
	return {"taken": false}


func apply_state(new_state: Dictionary) -> void:
	super.apply_state(new_state)
	var taken := bool(new_state.get("taken", false))
	visible = not taken
	for child in get_children():
		if child is StaticBody3D:
			(child as StaticBody3D).collision_layer = 0 if taken else LAYER_INTERACT


func get_prompt(_pid: int, _sub: int) -> String:
	var def: ItemDefinition = Session.item(item_id)
	return tr("PROMPT_TAKE_ITEM") % tr(def.name_key if def else item_id)


func authority_interact(ctx: Dictionary) -> void:
	if bool(state.get("taken", false)):
		return
	var drawer := _drawer()
	if drawer and not bool(drawer.state.get("open", false)):
		return  # cannot reach into a closed drawer
	var pid: int = ctx["player_id"]
	if not match_ctrl.give_item(pid, item_id, count):
		return
	var new_state := state.duplicate()
	new_state["taken"] = true
	match_ctrl.set_entity_state(entity_id, new_state)
	world_sound("pickup", -6.0, 10.0)
	match_ctrl.emit_noise(interact_origin(), 2.0, "pickup", pid)
	var def: ItemDefinition = Session.item(item_id)
	match_ctrl.notify_player(pid, "PICKED_UP", [tr(def.name_key if def else item_id)])


func _drawer() -> DrawerEntity:
	var n := get_parent()
	while n and not n is MapBase:
		if n is DrawerEntity:
			return n
		n = n.get_parent()
	return null


static func _glint_texture() -> Texture2D:
	if _glint_tex:
		return _glint_tex
	var size := 32
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y in size:
		for x in size:
			var d := Vector2(x - size / 2.0 + 0.5, y - size / 2.0 + 0.5)
			var r := d.length() / (size / 2.0)
			var star := (
				maxf(0.0, 1.0 - absf(d.x) * 0.5) * maxf(0.0, 1.0 - r)
				+ maxf(0.0, 1.0 - absf(d.y) * 0.5) * maxf(0.0, 1.0 - r)
			)
			var a := clampf(pow(maxf(0.0, 1.0 - r), 3.0) + star * 0.6, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_glint_tex = ImageTexture.create_from_image(img)
	return _glint_tex
