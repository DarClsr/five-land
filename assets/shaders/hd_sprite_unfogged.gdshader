shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.01) = 0.1;
uniform vec4 outline_color : source_color = vec4(0.04, 0.035, 0.03, 0.9);
uniform float outline_width : hint_range(0.5, 4.0, 0.25) = 1.5;

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

	ALBEDO = mix(color.rgb, outline_color.rgb, edge * outline_color.a);
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}
