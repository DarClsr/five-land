shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 void_color : source_color = vec4(0.018, 0.022, 0.038, 0.96);
uniform vec2 fade_axis = vec2(0.0, 1.0);
uniform float fade_start = 10.5;
uniform float fade_end = 13.2;
uniform float noise_scale = 2.2;
uniform float noise_strength : hint_range(0.0, 1.0, 0.01) = 0.24;
uniform float pixel_world_size : hint_range(0.02, 0.3, 0.01) = 0.12;
uniform float edge_softness : hint_range(0.1, 2.0, 0.05) = 0.9;

varying vec3 world_position;

float hash_21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 snapped = floor(world_position.xz / pixel_world_size) * pixel_world_size;
	float edge_distance = dot(world_position.xz, normalize(fade_axis));
	float noise = hash_21(floor(snapped * noise_scale));
	noise = mix(noise, hash_21(floor(snapped * noise_scale * 0.47) + 19.7), 0.35);
	float threshold = mix(fade_start, fade_end, noise * noise_strength + (1.0 - noise_strength) * 0.5);
	float dissolve = smoothstep(threshold - edge_softness, threshold + edge_softness, edge_distance);
	ALBEDO = void_color.rgb;
	ALPHA = dissolve * void_color.a;
}
