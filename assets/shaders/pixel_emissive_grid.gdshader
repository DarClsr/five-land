shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 base_color : source_color = vec4(0.22, 0.09, 0.025, 1.0);
uniform vec4 glow_color : source_color = vec4(1.0, 0.48, 0.16, 1.0);
uniform sampler2D grate_texture : source_color, filter_nearest, repeat_enable;
uniform bool use_grate_texture = true;
uniform vec2 grid_cells = vec2(8.0, 6.0);
uniform float bar_width : hint_range(0.02, 0.45, 0.01) = 0.16;
uniform float emission_energy : hint_range(0.0, 12.0, 0.1) = 4.2;
uniform float posterize_steps : hint_range(2.0, 6.0, 1.0) = 3.0;

void fragment() {
	vec2 grid = fract(UV * grid_cells);
	float open_x = step(bar_width, grid.x) * step(grid.x, 1.0 - bar_width);
	float open_y = step(bar_width, grid.y) * step(grid.y, 1.0 - bar_width);
	float opening = open_x * open_y;
	if (use_grate_texture) {
		vec3 grate = texture(grate_texture, UV).rgb;
		opening = smoothstep(0.32, 0.6, dot(grate, vec3(0.299, 0.587, 0.114)));
	}
	vec3 surface = mix(base_color.rgb, glow_color.rgb, opening);
	ALBEDO = floor(surface * 8.0 + 0.5) / 8.0;
	EMISSION = glow_color.rgb * opening * emission_energy;
	ROUGHNESS = 0.94;
}
