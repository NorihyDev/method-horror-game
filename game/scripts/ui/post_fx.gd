class_name PostFX
extends ColorRect
## Cheap screen overlay: vignette, film grain, damage edge, locker slats and
## a scare flash. It draws on top of the 3D view without reading the screen
## texture, so it costs one full-screen quad with simple math.

const SHADER := """
shader_type canvas_item;
render_mode blend_mix;

uniform float vignette = 0.0;
uniform float grain = 0.0;
uniform float damage = 0.0;
uniform float slats = 0.0;
uniform float flash = 0.0;
uniform float fade_black = 0.0;
uniform float aspect = 1.777;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	vec2 c = (uv - 0.5) * vec2(aspect, 1.0);
	float d = length(c);
	float vig = smoothstep(0.6, 1.35, d) * vignette;
	float n = hash(uv * vec2(1920.0, 1080.0) + fract(TIME * 13.17) * 100.0);
	float g = (n - 0.5) * grain;
	float dmg = smoothstep(0.35, 1.0, d) * damage;
	// Horizontal slats with soft gaps, used while hiding in a locker.
	float band = abs(fract(uv.y * 9.0) - 0.5) * 2.0;
	float slat = slats * (1.0 - smoothstep(0.18, 0.32, 1.0 - band));
	slat = max(slat, slats * smoothstep(0.32, 0.5, abs(uv.x - 0.5)));
	vec3 col = mix(vec3(0.0), vec3(0.45, 0.02, 0.02), clamp(dmg * 1.4, 0.0, 1.0));
	float a = clamp(vig + dmg + slat * 0.94 + fade_black, 0.0, 1.0);
	col = mix(col, vec3(0.92, 0.88, 0.8), flash);
	a = max(a, flash * 0.7);
	// Grain: brighten or darken slightly regardless of other layers.
	col += vec3(g);
	a = max(a, abs(g) * 0.9);
	COLOR = vec4(col, a);
}
"""

var damage := 0.0
var slats := 0.0
var flash := 0.0
var _mat: ShaderMaterial
var _active := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	material = _mat
	color = Color.WHITE
	visible = false


## Enabled during gameplay only.
func set_active(on: bool) -> void:
	_active = on
	damage = 0.0
	slats = 0.0
	flash = 0.0
	visible = on


func pulse_flash(strength: float = 1.0) -> void:
	if Settings.b("reduced_flashing"):
		strength *= 0.25
	flash = maxf(flash, strength)


func _process(delta: float) -> void:
	if not _active:
		return
	var vp := get_viewport_rect().size
	_mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
	_mat.set_shader_parameter("vignette", 0.55 if Settings.b("vignette") else 0.0)
	_mat.set_shader_parameter("grain", 0.07 if Settings.b("film_grain") else 0.0)
	_mat.set_shader_parameter("damage", damage)
	_mat.set_shader_parameter("slats", slats)
	_mat.set_shader_parameter("flash", flash)
	flash = move_toward(flash, 0.0, delta * 2.5)
