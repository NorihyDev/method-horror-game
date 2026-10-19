class_name MenuAtmosphere
extends ColorRect
## Dread over every menu screen: a heavy vignette, drifting film grain, faint
## scanlines, a slow red pulse rising from the floor and, now and then, the
## light failing for a moment. Hidden during play (gameplay screens pass input
## to the world). Grain follows the film-grain setting; the failing light and
## its tear line are skipped with reduced flashing.

const SHADER := """
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

uniform float aspect = 1.78;
uniform float grain = 0.06;
uniform float dim = 0.0;
uniform float pulse = 0.0;
uniform float tear_y = -1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 c = (uv - 0.5) * vec2(aspect, 1.0);
	float vig = smoothstep(0.42, 1.18, length(c)) * 0.82;
	// Darker corners at the top: the light comes from below, like a hallway.
	vig += (1.0 - uv.y) * 0.06;
	float n = hash(floor(FRAGCOORD.xy / 2.0) + floor(TIME * 24.0) * 1.7) - 0.5;
	float scan = sin(FRAGCOORD.y * 1.6) * 0.012;
	float glow = pow(uv.y, 3.0) * (0.035 + pulse * 0.05);
	vec3 add = vec3(glow * 1.0, glow * 0.12, glow * 0.1);
	add += vec3(max(n, 0.0) * grain);
	float tear = tear_y < 0.0 ? 0.0 : smoothstep(0.006, 0.0, abs(uv.y - tear_y));
	add += vec3(0.16, 0.03, 0.03) * tear;
	float a = clamp(vig + max(-n, 0.0) * grain * 1.4 + scan + dim, 0.0, 0.97);
	COLOR = vec4(add, a);
}
"""

var app: App
var _mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _next_fail := 6.0
var _fail_left := 0.0
var _t := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	var shader := Shader.new()
	shader.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = shader
	material = _mat
	_rng.randomize()


func _process(delta: float) -> void:
	var cur := app.current() if app else null
	visible = cur != null and not cur.passes_input
	if not visible:
		return
	_t += delta
	var vp := get_viewport_rect().size
	_mat.set_shader_parameter("aspect", vp.x / maxf(vp.y, 1.0))
	_mat.set_shader_parameter("grain", 0.07 if Settings.b("film_grain") else 0.0)
	_mat.set_shader_parameter("pulse", 0.5 + 0.5 * sin(_t * 0.9))
	var dim := 0.0
	var tear := -1.0
	if not Settings.b("reduced_flashing"):
		_next_fail -= delta
		if _next_fail <= 0.0:
			_next_fail = _rng.randf_range(7.0, 15.0)
			_fail_left = _rng.randf_range(0.25, 0.45)
		if _fail_left > 0.0:
			_fail_left -= delta
			# A few uneven blinks, never fully black.
			dim = 0.38 if fmod(_fail_left * 23.0, 2.0) < 1.0 else 0.08
			tear = fmod(_t * 3.7, 1.0)
	_mat.set_shader_parameter("dim", dim)
	_mat.set_shader_parameter("tear_y", tear)
