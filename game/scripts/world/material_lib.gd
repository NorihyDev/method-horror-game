class_name MaterialLib
extends RefCounted
## Shared materials. Every surface uses one shader with different uniforms so
## the renderer can batch state changes. Texture resolution follows the
## "texture_quality" setting at map load time.

const TEX_DIR := "res://assets/generated/textures/"
const SURFACE_SHADER := preload("res://assets/materials/surface.gdshader")

## name -> [texture, tint, tiles_per_meter, roughness, metallic, normal_strength, variation, grime]
const SURFACES := {
	"wallpaper": ["wallpaper", Color(1, 1, 1), 0.5, 0.9, 0.0, 0.6, 0.45, 0.45],
	"wallpaper_green": ["wallpaper", Color(0.78, 0.9, 0.8), 0.5, 0.9, 0.0, 0.6, 0.45, 0.45],
	"wallpaper_red": ["wallpaper", Color(0.95, 0.72, 0.68), 0.5, 0.9, 0.0, 0.6, 0.45, 0.45],
	"plaster": ["plaster", Color(1, 1, 1), 0.4, 0.95, 0.0, 0.5, 0.25, 0.3],
	"ceiling": ["plaster", Color(0.8, 0.78, 0.74), 0.35, 0.95, 0.0, 0.35, 0.2, 0.0],
	"wood_floor": ["wood_floor", Color(1, 1, 1), 0.35, 0.7, 0.0, 0.8, 0.35, 0.0],
	"concrete": ["concrete", Color(1, 1, 1), 0.33, 0.92, 0.0, 0.9, 0.3, 0.4],
	"concrete_floor": ["concrete", Color(0.85, 0.85, 0.85), 0.3, 0.88, 0.0, 0.9, 0.55, 0.0],
	"tile": ["tile", Color(1, 1, 1), 0.6, 0.45, 0.0, 0.6, 0.3, 0.0],
	"tile_wall": ["wall_tile", Color(0.95, 0.96, 0.92), 0.5, 0.35, 0.0, 0.5, 0.3, 0.35],
	"metal": ["metal", Color(1, 1, 1), 0.6, 0.55, 0.65, 0.5, 0.25, 0.0],
	"metal_dark": ["metal", Color(0.45, 0.47, 0.5), 0.6, 0.6, 0.6, 0.5, 0.25, 0.0],
	"metal_green": ["metal", Color(0.5, 0.6, 0.52), 0.6, 0.6, 0.5, 0.5, 0.25, 0.0],
	"dark_wood": ["dark_wood", Color(1, 1, 1), 0.8, 0.65, 0.0, 0.6, 0.2, 0.0],
	"painted_wood": ["dark_wood", Color(1.05, 1.0, 0.92), 0.8, 0.75, 0.0, 0.4, 0.2, 0.0],
	"fabric": ["fabric", Color(1, 1, 1), 1.0, 1.0, 0.0, 0.5, 0.3, 0.0],
	"fabric_blue": ["fabric", Color(0.7, 0.8, 1.0), 1.0, 1.0, 0.0, 0.5, 0.3, 0.0],
	"blocks": ["blocks", Color(1, 1, 1), 0.5, 0.9, 0.0, 0.9, 0.4, 0.4],
	"carpet": ["carpet", Color(1, 1, 1), 0.5, 1.0, 0.0, 0.4, 0.2, 0.0],
	"exterior": ["blocks", Color(0.35, 0.36, 0.4), 0.4, 0.95, 0.0, 0.6, 0.5, 0.0],
	"ground": ["concrete", Color(0.25, 0.27, 0.24), 0.2, 1.0, 0.0, 0.6, 0.6, 0.0],
	# The Black Ward
	"linoleum": ["linoleum", Color(1, 1, 1), 0.35, 0.55, 0.0, 0.4, 0.3, 0.0],
	"ceiling_panel": ["ceiling_panel", Color(0.9, 0.9, 0.88), 0.5, 0.95, 0.0, 0.5, 0.2, 0.0],
	"ward_tile": ["wall_tile", Color(0.72, 0.88, 0.8), 0.6, 0.3, 0.0, 0.5, 0.3, 0.35],
	"ward_paint": ["plaster", Color(0.78, 0.86, 0.8), 0.4, 0.9, 0.0, 0.4, 0.25, 0.35],
	# Last Train
	"subway_tile": ["wall_tile", Color(1.0, 0.95, 0.82), 0.9, 0.3, 0.0, 0.5, 0.3, 0.45],
	"subway_band": ["wall_tile", Color(0.55, 0.16, 0.12), 0.9, 0.35, 0.0, 0.5, 0.3, 0.3],
	"platform": ["concrete", Color(0.7, 0.69, 0.66), 0.3, 0.85, 0.0, 0.8, 0.5, 0.0],
	"tunnel": ["blocks", Color(0.4, 0.38, 0.36), 0.35, 0.95, 0.0, 0.9, 0.6, 0.6],
	"ballast": ["ballast", Color(1, 1, 1), 0.6, 1.0, 0.0, 1.0, 0.4, 0.0],
	"rust": ["rust", Color(1, 1, 1), 0.5, 0.85, 0.35, 0.8, 0.3, 0.0],
	"rail": ["metal", Color(0.55, 0.52, 0.5), 1.0, 0.35, 0.85, 0.3, 0.2, 0.0],
	"safety_yellow": ["concrete", Color(0.95, 0.75, 0.15), 0.5, 0.8, 0.0, 0.5, 0.3, 0.3],
	# The Silent School
	"parquet": ["wood_floor", Color(0.95, 0.8, 0.6), 0.45, 0.65, 0.0, 0.8, 0.35, 0.0],
	"school_paint": ["plaster", Color(0.9, 0.86, 0.7), 0.4, 0.9, 0.0, 0.4, 0.25, 0.35],
	"school_dado": ["plaster", Color(0.48, 0.6, 0.52), 0.4, 0.85, 0.0, 0.4, 0.25, 0.4],
	"school_tile": ["wall_tile", Color(0.86, 0.85, 0.76), 0.6, 0.35, 0.0, 0.5, 0.3, 0.35],
	"chalkboard": ["plaster", Color(0.12, 0.19, 0.15), 0.4, 0.95, 0.0, 0.3, 0.15, 0.0],
	"cork": ["fabric", Color(0.78, 0.56, 0.36), 1.2, 1.0, 0.0, 0.6, 0.3, 0.0],
	# METHOD Facility
	"lab_tile": ["wall_tile", Color(0.9, 0.93, 0.95), 0.6, 0.3, 0.0, 0.5, 0.25, 0.3],
	"lab_floor": ["linoleum", Color(0.66, 0.69, 0.73), 0.35, 0.55, 0.0, 0.4, 0.3, 0.0],
	"lab_panel": ["metal", Color(0.78, 0.8, 0.83), 0.6, 0.5, 0.5, 0.4, 0.2, 0.0],
	"tank": ["metal", Color(0.12, 0.2, 0.17), 0.4, 0.15, 0.3, 0.2, 0.3, 0.0],
}

static var _cache: Dictionary = {}
static var _flat_cache: Dictionary = {}
static var _quality := ""


static func surface(mat_name: String) -> Material:
	var quality := "high"
	if Engine.get_main_loop() != null:
		var settings: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Settings")
		if settings:
			quality = str(settings.call("get_value", "texture_quality"))
	if quality != _quality:
		_cache.clear()
		_quality = quality
	if _cache.has(mat_name):
		return _cache[mat_name]
	var spec: Array = SURFACES.get(mat_name, SURFACES["plaster"])
	var suffix := "_lo" if quality == "low" else ""
	var m := ShaderMaterial.new()
	m.shader = SURFACE_SHADER
	m.set_shader_parameter("albedo_tex", _tex(str(spec[0]) + "_albedo" + suffix))
	m.set_shader_parameter("normal_tex", _tex(str(spec[0]) + "_normal" + suffix))
	m.set_shader_parameter("tint", spec[1])
	m.set_shader_parameter("tiles_per_meter", spec[2])
	m.set_shader_parameter("roughness", spec[3])
	m.set_shader_parameter("metallic", spec[4])
	m.set_shader_parameter("normal_strength", spec[5])
	m.set_shader_parameter("variation", spec[6])
	m.set_shader_parameter("floor_grime", spec[7])
	_cache[mat_name] = m
	return m


## Untextured material for small props, emissive parts and interactables.
static func flat(
	color: Color,
	roughness: float = 0.8,
	metallic: float = 0.0,
	emission: Color = Color.BLACK,
	emission_energy: float = 0.0
) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s|%.2f" % [color.to_html(), roughness, metallic, emission.to_html(), emission_energy]
	if _flat_cache.has(key):
		return _flat_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	_flat_cache[key] = m
	return m


## Unshaded glowing material (bulbs, LEDs). Not cached: callers animate it.
static func glow(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func _tex(file_base: String) -> Texture2D:
	var path := TEX_DIR + file_base + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("Missing texture " + path)
	return null


static func clear_cache() -> void:
	_cache.clear()
	_flat_cache.clear()
