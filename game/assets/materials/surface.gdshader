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

varying float world_y;

void vertex() {
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	vec2 uv = UV * tiles_per_meter;
	vec3 base = texture(albedo_tex, uv).rgb;
	// Large-scale luminance variation from a heavily scaled, rotated sample.
	vec2 big_uv = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * UV * 0.071;
	float big = dot(texture(albedo_tex, big_uv).rgb, vec3(0.333));
	base *= mix(1.0, 0.55 + big * 1.1, variation);
	float local_y = mod(world_y - storey_offset, storey_height);
	float grime = 1.0 - floor_grime * (1.0 - smoothstep(0.0, 0.9, local_y));
	ALBEDO = base * tint.rgb * grime;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	ROUGHNESS = roughness;
	METALLIC = metallic;
}
