class_name PropModels
extends RefCounted
## Real 3D furniture (Poly Haven, CC0; converted by tools/props/) placed in
## place of the procedural box pieces. Each model is fitted to the footprint
## the box version had (width along local X, depth along local Z, height),
## so tables keep their top height for items and the colliders, navigation
## and puzzles are unchanged. Missing models fall back to the boxes.

const DIR := "res://assets/props/"
const INFO := "res://assets/props/props.json"
## Largest height stretch allowed against the footprint fit, so a model
## never looks squashed or pulled.
const MAX_STRETCH := 1.25

static var _info: Dictionary = {}
static var _scenes: Dictionary = {}
static var _loaded := false
static var _glass: StandardMaterial3D


static func available(id: String) -> bool:
	_load_info()
	return _info.has(id) and ResourceLoader.exists(DIR + id + ".glb")


## Places model `id` at `pos` (floor), turned `rot` degrees, fitted to
## `fit` = (width, height, depth). `lie` tips it onto its back (a fallen chair).
## `stretch` caps how far the height may differ from the footprint scale.
## Returns false when the model is missing, so the caller builds boxes instead.
static func place(
	b: GeoBuilder, id: String, pos: Vector3, rot: float, fit: Vector3, lie: bool = false, stretch: float = MAX_STRETCH
) -> bool:
	if not available(id):
		return false
	var size: Array = _info[id]["size"]
	var mx := float(size[0])
	var my := float(size[1])
	var mz := float(size[2])
	# Turn the model a quarter only if both are clearly long and the long
	# sides run different ways (near-square pieces keep their front).
	var long_fit := maxf(fit.x, fit.z) / maxf(minf(fit.x, fit.z), 0.01) > 1.25
	var long_model := maxf(mx, mz) / maxf(minf(mx, mz), 0.01) > 1.25
	var quarter := long_fit and long_model and (fit.x > fit.z) != (mx > mz)
	if quarter:
		var tmp := mx
		mx = mz
		mz = tmp
	var s := minf(fit.x / maxf(mx, 0.01), fit.z / maxf(mz, 0.01))
	var sy := clampf(fit.y / maxf(my, 0.01), s / stretch, s * stretch)
	var node := _scene(id).instantiate() as Node3D
	var basis := Basis(Vector3.UP, deg_to_rad(rot) + (PI / 2 if quarter else 0.0))
	if lie:
		basis = basis * Basis(Vector3.RIGHT, -PI / 2)
	node.transform = Transform3D(basis.scaled_local(Vector3(s, sy, s)), pos)
	b.root.add_child(node)
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		mi.visibility_range_end = 30.0
		mi.visibility_range_end_margin = 4.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
	return true


## Places a flat model (a framed picture) centred on `center`, stretched to
## `w` x `h` in the plane of `basis` (its +Z faces out of the wall).
static func place_flat(b: GeoBuilder, id: String, center: Vector3, basis: Basis, w: float, h: float) -> bool:
	if not available(id):
		return false
	var size: Array = _info[id]["size"]
	var sx := w / maxf(float(size[0]), 0.01)
	var sy := h / maxf(float(size[1]), 0.01)
	var node := _scene(id).instantiate() as Node3D
	node.transform = Transform3D(basis.scaled_local(Vector3(sx, sy, (sx + sy) * 0.5)), center - basis.y * h * 0.5)
	b.root.add_child(node)
	# Its tinted glass reads as a black pane in torchlight: clear, faint glass.
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat and mat.resource_name.contains("glass"):
				mi.set_surface_override_material(i, _clear_glass())
	return true


static func _clear_glass() -> StandardMaterial3D:
	if _glass == null:
		_glass = StandardMaterial3D.new()
		_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glass.albedo_color = Color(0.9, 0.95, 1.0, 0.06)
		_glass.roughness = 0.05
		_glass.metallic_specular = 0.8
	return _glass


static func _scene(id: String) -> PackedScene:
	if not _scenes.has(id):
		_scenes[id] = load(DIR + id + ".glb")
	return _scenes[id]


static func _load_info() -> void:
	if _loaded:
		return
	_loaded = true
	if not FileAccess.file_exists(INFO):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(INFO))
	if parsed is Dictionary:
		_info = parsed
