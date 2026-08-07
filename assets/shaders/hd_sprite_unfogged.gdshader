shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D albedo_texture : source_color, filter_nearest, repeat_disable;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform vec4 outline_color : source_color = vec4(0.04, 0.035, 0.03, 0.9);
uniform float outline_width : hint_range(0.5, 4.0, 0.25) = 1.5;
uniform float character_brightness : hint_range(0.5, 2.0, 0.01) = 1.0;
uniform float character_saturation : hint_range(0.0, 2.0, 0.01) = 1.0;
uniform float vermilion_boost : hint_range(0.0, 0.5, 0.01) = 0.0;

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
	ALBEDO = mix(adjusted, outline_color.rgb, edge * outline_color.a);
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}
