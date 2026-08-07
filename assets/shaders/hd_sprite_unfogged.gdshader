shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_disable;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform vec4 outline_color : source_color = vec4(0.04, 0.035, 0.03, 0.9);
uniform float outline_width : hint_range(0.5, 4.0, 0.25) = 1.5;
uniform float character_brightness : hint_range(0.5, 2.0, 0.01) = 1.0;
uniform float character_saturation : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float vermilion_boost : hint_range(0.0, 0.5, 0.01) = 0.0;
uniform vec4 rim_color : source_color = vec4(0.416, 0.549, 0.686, 1.0);
uniform float rim_strength : hint_range(0.0, 2.0, 0.02) = 0.42;
uniform vec2 rim_direction = vec2(-0.72, -0.69);
uniform float rim_fill : hint_range(0.0, 1.0, 0.05) = 0.32;
uniform vec4 warm_light_color : source_color = vec4(1.0, 0.62, 0.28, 1.0);
uniform float warm_light_strength : hint_range(0.0, 1.0, 0.01) = 0.3;
uniform vec4 cold_shadow_color : source_color = vec4(0.16, 0.24, 0.42, 1.0);
uniform float cold_shadow_strength : hint_range(0.0, 1.0, 0.01) = 0.25;
uniform vec4 weapon_emission_color : source_color = vec4(0.816, 0.91, 1.0, 1.0);
uniform float weapon_attack_boost : hint_range(1.0, 3.0, 0.01) = 1.0;

void fragment() {
	vec2 texel = 1.0 / vec2(textureSize(albedo_texture, 0));
	vec4 color = texture(albedo_texture, UV);

	// Cartoon outline: sample 8 neighbours; if any neighbour is transparent
	// while we are opaque, we are on the silhouette edge -> blend in outline.
	float edge = 0.0;
	vec2 step_uv = texel * outline_width;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			if (x == 0 && y == 0) {
				continue;
			}
			float a = texture(albedo_texture, UV + vec2(float(x), float(y)) * step_uv).a;
			if (a < alpha_scissor_threshold) {
				edge = 1.0;
			}
		}
	}

	vec3 adjusted = color.rgb;
	float luma = dot(adjusted, vec3(0.299, 0.587, 0.114));
	adjusted = mix(vec3(luma), adjusted, character_saturation);
	float red_difference = adjusted.r - max(adjusted.g, adjusted.b);
	float vermilion = smoothstep(0.035, 0.22, red_difference);
	adjusted.r += vermilion * vermilion_boost;
	adjusted *= character_brightness;
	vec2 radial_direction = normalize(UV - vec2(0.5) + vec2(0.0001));
	float warm_side = max(dot(radial_direction, -normalize(rim_direction)), 0.0);
	float cold_side = max(dot(radial_direction, normalize(rim_direction)), 0.0);
	adjusted = mix(adjusted, adjusted * warm_light_color.rgb, warm_side * warm_light_strength);
	adjusted = mix(adjusted, adjusted * cold_shadow_color.rgb, cold_side * cold_shadow_strength);
	ALBEDO = mix(adjusted, outline_color.rgb, edge * outline_color.a);
	float directional_rim = max(dot(radial_direction, normalize(rim_direction)), 0.0);
	float rim_mask = edge * mix(rim_fill, 1.3, directional_rim);
	float weapon_luma = dot(color.rgb, vec3(0.299, 0.587, 0.114));
	float weapon_mask = smoothstep(0.5, 0.82, weapon_luma) * smoothstep(-0.02, 0.2, color.b - color.r);
	float weapon_breath = 0.78 + 0.22 * sin(TIME * 2.6);
	float trail_mask = 0.0;
	for (int i = 1; i <= 3; i++) {
		vec4 trail_sample = texture(albedo_texture, UV + normalize(rim_direction) * texel * float(i) * 2.0);
		float trail_luma = dot(trail_sample.rgb, vec3(0.299, 0.587, 0.114));
		trail_mask += smoothstep(0.58, 0.86, trail_luma) * trail_sample.a * 0.18;
	}
	EMISSION = rim_color.rgb * rim_strength * rim_mask;
	EMISSION += weapon_emission_color.rgb * weapon_mask * weapon_breath * weapon_attack_boost;
	EMISSION += weapon_emission_color.rgb * trail_mask * max(weapon_attack_boost - 1.0, 0.0);
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}
