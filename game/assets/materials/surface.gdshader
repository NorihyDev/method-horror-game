// METHOD HORROR shared surface shader.
// Geometry is generated with world-scaled UVs (1 UV unit = 1 m), so a single
// texture sample gives correct tiling and normal-map tangents. A second,
// low-frequency sample of the same albedo breaks visible repetition, and a
// floor-proximity term adds grime. Two albedo + one normal sample per pixel.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float tiles_per_meter = 0.5;
uniform float roughness = 0.85;
uniform float metallic = 0.0;
uniform float normal_strength = 1.0;
uniform float variation = 0.35;
uniform float floor_grime = 0.35;
// Height of each storey; grime is applied near the bottom of every storey.
uniform float storey_height = 3.2;
uniform float storey_offset = 0.0;

// Surface wear: dust settles on upward faces, damp grime streaks down walls,
// crevices (from the normal map) darken, and gloss varies with the texture.
uniform float dust = 0.35;
uniform float streaks = 0.25;
uniform float cavity = 0.6;
uniform float gloss_variation = 0.35;

varying float world_y;
varying vec3 world_pos;
varying vec3 world_nrm;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_y = world_pos.y;
	world_nrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x), mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x), mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void fragment() {
	vec2 uv = UV * tiles_per_meter;
	vec3 base = texture(albedo_tex, uv).rgb;
	vec2 big_uv = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * UV * 0.071;
	float big = dot(texture(albedo_tex, big_uv).rgb, vec3(0.333));
	base *= mix(1.0, 0.55 + big * 1.1, variation);
	vec3 nm = texture(normal_tex, uv).rgb;
	// Crevices: where the normal map tilts away, light reaches less.
	float tilt = clamp(length(nm.xy * 2.0 - 1.0) * 1.6, 0.0, 1.0);
	base *= 1.0 - cavity * 0.35 * tilt;
	float local_y = mod(world_y - storey_offset, storey_height);
	float grime = 1.0 - floor_grime * (1.0 - smoothstep(0.0, 0.9, local_y));
	// Dust on surfaces facing up, patchy.
	float n1 = vnoise(world_pos * 3.1);
	float n2 = vnoise(world_pos * 11.0);
	float up = smoothstep(0.55, 0.95, world_nrm.y);
	float dust_k = dust * up * smoothstep(0.35, 0.75, n1 * 0.7 + n2 * 0.3);
	// Damp streaks running down vertical surfaces.
	float side = 1.0 - abs(world_nrm.y);
	float streak = vnoise(vec3(world_pos.x * 7.0 + world_pos.z * 7.0, world_y * 0.6, 0.0));
	float streak_k = streaks * side * smoothstep(0.55, 0.9, streak) * (0.5 + 0.5 * n1);
	vec3 col = base * tint.rgb * grime;
	col = mix(col, vec3(0.42, 0.4, 0.36), dust_k * 0.6);
	col *= 1.0 - streak_k * 0.45;
	ALBEDO = col;
	NORMAL_MAP = nm;
	NORMAL_MAP_DEPTH = normal_strength;
	float lum = dot(texture(albedo_tex, uv).rgb, vec3(0.333));
	ROUGHNESS = clamp(roughness + (0.5 - lum) * gloss_variation + dust_k * 0.3 - streak_k * 0.15, 0.05, 1.0);
	METALLIC = metallic * (1.0 - dust_k);
}
