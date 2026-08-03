shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, depth_prepass_alpha;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform float alpha_scissor_threshold : hint_range(0.0, 1.0, 0.01) = 0.1;

void fragment() {
	vec4 color = texture(albedo_texture, UV);
	ALBEDO = color.rgb;
	ALPHA = color.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_scissor_threshold;
}
