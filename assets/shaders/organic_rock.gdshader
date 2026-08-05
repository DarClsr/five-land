shader_type spatial;
render_mode cull_disabled;

uniform float strength : hint_range(0.0, 2.0, 0.05) = 0.9;
uniform float frequency : hint_range(0.3, 8.0, 0.1) = 1.6;
uniform float horizontal_strength : hint_range(0.0, 1.0, 0.05) = 0.35;
uniform vec4 albedo_color : source_color = vec4(0.32, 0.3, 0.27, 1.0);
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.97;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	// Position-driven displacement: same XZ noise applied to every vertex on
	// the mesh, so seams (where adjacent faces share an XZ) stay continuous
	// and the box reads as one organic rock instead of cracked plates.
	vec2 xz = vec2(VERTEX.x, VERTEX.z) * frequency;
	float n = vnoise(xz);
	float n2 = vnoise(xz * 2.3 + 7.7);
	float vertical_offset = (n * 0.7 + n2 * 0.3 - 0.5) * strength;
	float h_offset_x = (n2 - 0.5) * strength * horizontal_strength;
	float h_offset_z = (n - 0.5) * strength * horizontal_strength;
	VERTEX += vec3(h_offset_x, vertical_offset, h_offset_z);
}

void fragment() {
	ALBEDO = albedo_color.rgb;
	ROUGHNESS = roughness;
	vec3 displaced_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	NORMAL = mix(NORMAL, displaced_normal, 0.85);
}