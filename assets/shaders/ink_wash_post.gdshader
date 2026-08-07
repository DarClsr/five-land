shader_type canvas_item;
render_mode unshaded;

uniform float desaturation : hint_range(0.0, 1.0) = 0.68;
uniform float ink_strength : hint_range(0.0, 1.0) = 0.42;
uniform float wash_softness : hint_range(0.0, 1.0) = 0.12;
uniform float paper_grain : hint_range(0.0, 0.2) = 0.025;
uniform float vermilion_keep : hint_range(0.0, 1.0) = 0.78;
uniform float posterize_steps : hint_range(2.0, 6.0, 1.0) = 3.0;
uniform float posterize_strength : hint_range(0.0, 1.0, 0.01) = 0.18;
uniform float vignette_strength : hint_range(0.0, 1.0, 0.01) = 0.2;
uniform float vignette_inner : hint_range(0.0, 1.0, 0.01) = 0.32;
uniform float vignette_outer : hint_range(0.5, 2.0, 0.01) = 1.22;
uniform vec4 paper_tint : source_color = vec4(0.92, 0.90, 0.82, 1.0);
uniform vec4 ink_tint : source_color = vec4(0.09, 0.105, 0.105, 1.0);


float luminance(vec3 color) {
	return dot(color, vec3(0.299, 0.587, 0.114));
}


float paper_noise(vec2 uv) {
	vec2 cell = floor(uv * vec2(1280.0, 720.0) * 0.48);
	return fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
}


void fragment() {
	vec2 pixel = TEXTURE_PIXEL_SIZE;
	vec3 center = texture(TEXTURE, UV).rgb;
	vec3 north = texture(TEXTURE, UV + vec2(0.0, -pixel.y)).rgb;
	vec3 south = texture(TEXTURE, UV + vec2(0.0, pixel.y)).rgb;
	vec3 east = texture(TEXTURE, UV + vec2(pixel.x, 0.0)).rgb;
	vec3 west = texture(TEXTURE, UV + vec2(-pixel.x, 0.0)).rgb;
	vec3 soft = (north + south + east + west) * 0.25;
	vec3 washed = mix(center, soft, wash_softness);

	float luma = luminance(washed);
	float edge_x = luminance(east) - luminance(west);
	float edge_y = luminance(south) - luminance(north);
	float edge = smoothstep(0.055, 0.22, length(vec2(edge_x, edge_y)));

	float red_difference = washed.r - max(washed.g, washed.b);
	float vermilion = smoothstep(0.025, 0.18, red_difference) * vermilion_keep;
	vec3 muted = mix(washed, vec3(luma), desaturation * (1.0 - vermilion));

	float paper_mix = smoothstep(0.18, 0.9, luma) * 0.07 * (1.0 - vermilion * 0.9);
	vec3 water_color = mix(muted, paper_tint.rgb, paper_mix);
	water_color = mix(water_color, ink_tint.rgb, edge * ink_strength);
	vec3 posterized_color = floor(water_color * posterize_steps + 0.5) / posterize_steps;
	float scene_posterize = posterize_strength * (1.0 - vermilion * 0.7);
	water_color = mix(water_color, posterized_color, scene_posterize);
	vec2 vignette_uv = UV * 2.0 - 1.0;
	float vignette = smoothstep(vignette_inner, vignette_outer, dot(vignette_uv, vignette_uv));
	water_color *= 1.0 - vignette * vignette_strength;

	float grain = (paper_noise(UV) - 0.5) * paper_grain;
	water_color += grain * mix(0.35, 1.0, luma);
	COLOR = vec4(clamp(water_color, vec3(0.0), vec3(1.0)), 1.0);
}
