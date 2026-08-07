shader_type fog;

// Local low fog for the burial road. It is densest around/below the slabs,
// fades rapidly above waist height, and drifts slowly instead of looking like
// a static blue screen overlay.
uniform vec3 fog_color : source_color = vec3(0.2902, 0.2706, 0.251);
uniform float base_density : hint_range(0.0, 1.0, 0.001) = 0.04;
uniform float base_height = 0.15;
uniform float height_falloff : hint_range(0.1, 8.0, 0.05) = 2.1;
uniform float noise_scale : hint_range(0.01, 2.0, 0.01) = 0.16;
uniform float noise_strength : hint_range(0.0, 1.0, 0.01) = 0.28;
uniform vec2 flow_speed = vec2(0.018, -0.012);
uniform float clear_path_half_width : hint_range(0.2, 5.0, 0.05) = 1.55;
uniform float outer_fog_width : hint_range(1.0, 10.0, 0.1) = 4.8;

float hash_21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash_21(cell);
	float b = hash_21(cell + vec2(1.0, 0.0));
	float c = hash_21(cell + vec2(0.0, 1.0));
	float d = hash_21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

void fog() {
	float height_density = exp(-max(WORLD_POSITION.y - base_height, 0.0) * height_falloff);
	vec2 drift_uv = WORLD_POSITION.xz * noise_scale + flow_speed * TIME;
	float broad_noise = value_noise(drift_uv);
	float fine_noise = value_noise(drift_uv * 2.07 - flow_speed * TIME * 0.35);
	float moving_noise = mix(broad_noise, fine_noise, 0.32);
	float modulation = mix(1.0 - noise_strength, 1.0 + noise_strength, moving_noise);
	float lateral_fog = smoothstep(
		clear_path_half_width, outer_fog_width, abs(WORLD_POSITION.x)
	);
	float path_clearance = mix(0.22, 1.35, lateral_fog);
	DENSITY = base_density * height_density * modulation * path_clearance;
	ALBEDO = fog_color;
	// 雾渊需要保留一点自身亮度，否则无灯侧会重新坠成纯黑。
	EMISSION = fog_color * 0.025;
}
