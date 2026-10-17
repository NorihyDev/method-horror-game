class_name BeamCone
extends MeshInstance3D
## Visible light in dusty air: a soft additive cone that follows a SpotLight3D
## (child of it). Cheap fake volumetrics for the Mobile renderer: one cone,
## one depth read, no light marching.
##
## From inside the beam (the player's own flashlight) the haze builds up with
## how far each ray travels through the beam before it hits a surface; seen
## from outside (a teammate's light) it is brightest through the thickest
## part of the cone. Both fade where the beam meets walls, so it never shows
## a hard edge. "Light shafts" in Settings turns it off.

const SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec3 tint : source_color = vec3(1.0, 0.94, 0.82);
uniform float strength = 0.1;
uniform float beam_range = 19.0;
uniform float half_angle = 0.3;
uniform bool inside = true;
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec3 axis_view;
varying vec3 apex_view;

void vertex() {
	// The cone points down its local -Y (see BeamCone._fit).
	axis_view = normalize((MODELVIEW_MATRIX * vec4(0.0, -1.0, 0.0, 0.0)).xyz);
	apex_view = (MODELVIEW_MATRIX * vec4(0.0, beam_range * 0.5, 0.0, 1.0)).xyz;
}

void fragment() {
	float depth = textureLod(depth_tex, SCREEN_UV, 0.0).r;
	vec4 scene = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene_dist = length(scene.xyz / scene.w);
	float frag_dist = length(VERTEX);
	vec3 ray = normalize(VERTEX);
	float glow;
	if (inside) {
		// Air travelled through the beam, weighted by the light's falloff.
		float d = clamp(min(scene_dist, frag_dist) / beam_range, 0.0, 1.0);
		float travelled = 1.0 - pow(1.0 - d, 3.0);
		float off_axis = acos(clamp(dot(ray, axis_view), -1.0, 1.0));
		float core = 1.0 - smoothstep(half_angle * 0.15, half_angle, off_axis);
		glow = travelled * core * core;
	} else {
		float thick = abs(dot(NORMAL, VIEW));
		float along = clamp(dot(VERTEX - apex_view, axis_view) / beam_range, 0.0, 1.0);
		float soft = clamp((scene_dist - frag_dist) / 0.5, 0.0, 1.0);
		glow = thick * thick * pow(1.0 - along, 2.0) * smoothstep(0.0, 0.06, along) * soft;
	}
	// Slow drifting unevenness, like dust moving through the light.
	vec3 w = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float drift = 0.8 + 0.2 * sin(w.x * 3.1 + TIME * 0.7) * sin(w.y * 2.3 - TIME * 0.5) * sin(w.z * 2.7 + TIME * 0.3);
	ALBEDO = tint * strength * glow * drift;
}
"""

static var _shader: Shader

var light: SpotLight3D
var inside := true
## Haze brightness at full light energy.
var strength := 0.12
var _mat: ShaderMaterial


## Adds a beam to `p_light`. `p_inside` is true for the camera's own light.
static func attach(p_light: SpotLight3D, p_inside: bool, p_strength: float = 0.12) -> BeamCone:
	var cone := BeamCone.new()
	cone.light = p_light
	cone.inside = p_inside
	cone.strength = p_strength
	p_light.add_child(cone)
	return cone


func _ready() -> void:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = _shader
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_fit()
	_apply_setting()
	Settings.changed.connect(_on_setting)


func _on_setting(key: String, _v: Variant) -> void:
	if key in ["light_shafts", "quality_preset"]:
		_apply_setting()


func _apply_setting() -> void:
	set_process(Settings.b("light_shafts"))
	visible = Settings.b("light_shafts") and light != null and light.visible


## A cone from the light's origin to its range, opening at its spot angle.
func _fit() -> void:
	var length := light.spot_range
	var radius := tan(deg_to_rad(light.spot_angle)) * length
	var m := CylinderMesh.new()
	m.top_radius = 0.01
	m.bottom_radius = radius
	m.height = length
	m.radial_segments = 20
	m.rings = 1
	m.cap_top = false
	m.cap_bottom = false
	mesh = m
	# Cylinder runs along Y; turn it so its wide end lies down the light's -Z.
	transform = Transform3D(Basis(Vector3.RIGHT, PI / 2), Vector3(0, 0, -length * 0.5))
	_mat.set_shader_parameter("beam_range", length)
	_mat.set_shader_parameter("half_angle", deg_to_rad(light.spot_angle))
	_mat.set_shader_parameter("inside", inside)
	_mat.set_shader_parameter("tint", Vector3(light.light_color.r, light.light_color.g, light.light_color.b))
	# Never let the camera clip it away near the lens.
	extra_cull_margin = 2.0


func _process(_delta: float) -> void:
	var on := light.visible and light.is_visible_in_tree() and light.light_energy > 0.05
	visible = on
	if on:
		var k := strength * clampf(light.light_energy / 3.0, 0.0, 1.5)
		if not inside:
			k *= _facing_fade()
		_mat.set_shader_parameter("strength", k)


## Someone else's beam pointed at the camera: the haze fades out (from in
## there you'd see the lamp's glare, not a shaft of light).
func _facing_fade() -> float:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return 1.0
	var to_cam := (cam.global_position - light.global_position).normalized()
	var aim := -light.global_basis.z
	var c := cos(deg_to_rad(light.spot_angle))
	return 1.0 - smoothstep(lerpf(c, 1.0, -0.3), lerpf(c, 1.0, 0.3), aim.dot(to_cam))
