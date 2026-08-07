shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

uniform float progress : hint_range(0.0, 1.0, 0.01) = 1.0;
uniform vec4 fill_color : source_color = vec4(0.82, 0.18, 0.12, 1.0);
uniform vec4 empty_color : source_color = vec4(0.08, 0.055, 0.07, 0.92);
uniform vec4 border_color : source_color = vec4(0.025, 0.02, 0.03, 1.0);
uniform vec2 pixel_grid = vec2(32.0, 8.0);


void fragment() {
	vec2 pixel_uv = (floor(UV * pixel_grid) + 0.5) / pixel_grid;
	bool border = pixel_uv.x < 0.06 || pixel_uv.x > 0.94
		|| pixel_uv.y < 0.2 || pixel_uv.y > 0.8;
	float fill_edge = mix(0.07, 0.93, progress);
	vec4 bar_color = pixel_uv.x <= fill_edge ? fill_color : empty_color;
	bar_color = border ? border_color : bar_color;
	ALBEDO = bar_color.rgb;
	ALPHA = bar_color.a;
}
