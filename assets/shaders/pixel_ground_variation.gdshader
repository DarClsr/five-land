shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

// World-space dual sampling breaks obvious floor repetition while retaining
// crisp pixel texels. A low-frequency mask blends a rotated/scaled variant.
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float texture_scale : hint_range(0.05, 8.0, 0.05) = 1.15;
uniform float pixel_world_size : hint_range(0.02, 0.25, 0.005) = 0.075;
uniform float variant_scale : hint_range(0.5, 2.0, 0.01) = 1.17;
uniform float macro_scale : hint_range(0.01, 1.0, 0.01) = 0.12;
uniform float macro_strength : hint_range(0.0, 0.5, 0.01) = 0.14;
uniform float texture_contrast : hint_range(0.0, 1.5, 0.01) = 0.7;
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.94;
uniform float color_steps : hint_range(0.0, 32.0, 1.0) = 16.0;

varying vec3 world_position;


float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


float value_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	local = local * local * (3.0 - 2.0 * local);
	float a = hash21(cell);
	float b = hash21(cell + vec2(1.0, 0.0));
	float c = hash21(cell + vec2(0.0, 1.0));
	float d = hash21(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	vec2 snapped_world = floor(world_position.xz / pixel_world_size + 0.5) * pixel_world_size;
	vec2 world_uv = snapped_world * texture_scale;
	vec2 rotated_uv = vec2(-world_uv.y, world_uv.x) * variant_scale + vec2(17.31, 9.73);
	float macro = value_noise(world_position.xz * macro_scale);
	float blend_factor = smoothstep(0.28, 0.72, macro) * 0.45;
	vec3 base_sample = texture(albedo_texture, world_uv).rgb;
	vec3 variant_sample = texture(albedo_texture, rotated_uv).rgb;
	vec3 surface_color = mix(base_sample, variant_sample, blend_factor);
	// Source-color textures arrive in linear space. Lift their dark slate range
	// before contrast shaping so grout survives three-band post posterization.
	surface_color = pow(max(surface_color, vec3(0.0001)), vec3(0.58));
	surface_color = vec3(0.25) + (surface_color - vec3(0.25)) * texture_contrast;
	float brightness_variation = mix(1.0 - macro_strength, 1.0 + macro_strength, macro);
	// Keep the authored grout and crack values outside the post-pass shadow
	// clamp. The scene tint still shapes the palette without crushing all
	// 64px texels into the same posterized band.
	vec3 palette_tint = mix(vec3(1.0), tint.rgb, 0.4);
	surface_color *= palette_tint * brightness_variation;
	if (color_steps > 1.0) {
		surface_color = floor(surface_color * color_steps + 0.5) / color_steps;
	}
	ALBEDO = surface_color;
	ROUGHNESS = roughness;
	METALLIC = 0.0;
	SPECULAR = 0.2;
	AO = mix(0.78, 1.0, macro);
	AO_LIGHT_AFFECT = 0.28;
}
