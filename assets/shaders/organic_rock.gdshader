shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;

// Stylized triplanar stone for HD-2D scenery. Texture coordinates are world
// aligned, so cliffs, rocks, steles and lanterns share the same texel density
// without visible UV seams.
uniform vec4 albedo_color : source_color = vec4(0.32, 0.3, 0.27, 1.0);
uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool use_albedo_texture = false;
uniform float texture_strength : hint_range(0.0, 1.0, 0.05) = 0.9;
uniform float texture_contrast : hint_range(0.0, 1.5, 0.01) = 0.72;
uniform float triplanar_scale : hint_range(0.05, 8.0, 0.05) = 1.15;
uniform float triplanar_sharpness : hint_range(1.0, 16.0, 0.5) = 6.0;
uniform float pixel_world_size : hint_range(0.01, 0.5, 0.01) = 0.08;
uniform float color_steps : hint_range(0.0, 32.0, 1.0) = 12.0;
// Low-frequency world-space warp that breaks the visible grid of repeated
// triplanar tiles without introducing seams between neighbouring surfaces.
uniform float tiling_warp : hint_range(0.0, 1.0, 0.01) = 0.0;

uniform sampler2D normal_texture : hint_normal, filter_nearest_mipmap, repeat_enable;
uniform bool use_normal_texture = false;
uniform bool derive_normal_from_albedo = true;
uniform bool derive_normal_from_geometry = true;
uniform float normal_strength : hint_range(0.0, 2.0, 0.05) = 0.8;

uniform sampler2D roughness_texture : filter_nearest_mipmap, repeat_enable;
uniform bool use_roughness_texture = false;
uniform float roughness : hint_range(0.0, 1.0, 0.01) = 0.94;
uniform float roughness_texture_strength : hint_range(0.0, 1.0, 0.05) = 0.55;

uniform sampler2D ao_texture : filter_nearest_mipmap, repeat_enable;
uniform bool use_ao_texture = false;
uniform float ao_strength : hint_range(0.0, 1.0, 0.05) = 0.72;
uniform float ao_light_affect : hint_range(0.0, 1.0, 0.05) = 0.35;

uniform float strength : hint_range(0.0, 2.0, 0.05) = 0.0;
uniform float frequency : hint_range(0.3, 8.0, 0.1) = 1.6;
uniform float horizontal_strength : hint_range(0.0, 1.0, 0.05) = 0.35;
uniform vec3 rim_color : source_color = vec3(0.12, 0.17, 0.24);
uniform float rim_strength : hint_range(0.0, 1.0, 0.02) = 0.12;

varying vec3 world_position;
varying vec3 world_normal;


float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}


float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}


vec3 blend_weights(vec3 normal_value) {
	vec3 weights = pow(abs(normal_value), vec3(triplanar_sharpness));
	return weights / max(dot(weights, vec3(1.0)), 0.0001);
}


vec3 sample_triplanar_color(sampler2D map_texture, vec3 position, vec3 weights) {
	vec3 x_sample = texture(map_texture, position.zy).rgb;
	vec3 y_sample = texture(map_texture, position.xz).rgb;
	vec3 z_sample = texture(map_texture, position.xy).rgb;
	return x_sample * weights.x + y_sample * weights.y + z_sample * weights.z;
}


float sample_triplanar_channel(sampler2D map_texture, vec3 position, vec3 weights) {
	float x_sample = texture(map_texture, position.zy).r;
	float y_sample = texture(map_texture, position.xz).r;
	float z_sample = texture(map_texture, position.xy).r;
	return x_sample * weights.x + y_sample * weights.y + z_sample * weights.z;
}


vec3 sample_triplanar_normal(vec3 position, vec3 geometric_normal, vec3 weights) {
	vec3 axis_sign = sign(geometric_normal);
	axis_sign += vec3(lessThan(abs(axis_sign), vec3(0.5)));
	vec3 nx = texture(normal_texture, position.zy).xyz * 2.0 - 1.0;
	vec3 ny = texture(normal_texture, position.xz).xyz * 2.0 - 1.0;
	vec3 nz = texture(normal_texture, position.xy).xyz * 2.0 - 1.0;
	nx.xy *= normal_strength;
	ny.xy *= normal_strength;
	nz.xy *= normal_strength;
	vec3 world_x = normalize(vec3(nx.z * axis_sign.x, nx.y, nx.x));
	vec3 world_y = normalize(vec3(ny.x, ny.z * axis_sign.y, ny.y));
	vec3 world_z = normalize(vec3(nz.x, nz.y, nz.z * axis_sign.z));
	return normalize(world_x * weights.x + world_y * weights.y + world_z * weights.z);
}


float albedo_height(vec2 uv) {
	vec3 sample_color = texture(albedo_texture, uv).rgb;
	return dot(sample_color, vec3(0.299, 0.587, 0.114));
}


vec3 sample_triplanar_height_normal(vec3 position, vec3 geometric_normal, vec3 weights) {
	float sample_step = max(pixel_world_size * triplanar_scale, 0.005);
	vec2 offset_u = vec2(sample_step, 0.0);
	vec2 offset_v = vec2(0.0, sample_step);
	vec2 uv_x = position.zy;
	vec2 uv_y = position.xz;
	vec2 uv_z = position.xy;
	vec3 nx = normalize(vec3(
		(albedo_height(uv_x - offset_u) - albedo_height(uv_x + offset_u)) * normal_strength,
		(albedo_height(uv_x - offset_v) - albedo_height(uv_x + offset_v)) * normal_strength,
		1.0
	));
	vec3 ny = normalize(vec3(
		(albedo_height(uv_y - offset_u) - albedo_height(uv_y + offset_u)) * normal_strength,
		(albedo_height(uv_y - offset_v) - albedo_height(uv_y + offset_v)) * normal_strength,
		1.0
	));
	vec3 nz = normalize(vec3(
		(albedo_height(uv_z - offset_u) - albedo_height(uv_z + offset_u)) * normal_strength,
		(albedo_height(uv_z - offset_v) - albedo_height(uv_z + offset_v)) * normal_strength,
		1.0
	));
	vec3 axis_sign = sign(geometric_normal);
	axis_sign += vec3(lessThan(abs(axis_sign), vec3(0.5)));
	vec3 world_x = normalize(vec3(nx.z * axis_sign.x, nx.y, nx.x));
	vec3 world_y = normalize(vec3(ny.x, ny.z * axis_sign.y, ny.y));
	vec3 world_z = normalize(vec3(nz.x, nz.y, nz.z * axis_sign.z));
	return normalize(world_x * weights.x + world_y * weights.y + world_z * weights.z);
}


void vertex() {
	vec2 sample_position = vec2(
		VERTEX.x + VERTEX.y * 0.41,
		VERTEX.z + VERTEX.y * 0.67
	) * frequency;
	float n = vnoise(sample_position);
	float n2 = vnoise(sample_position * 2.3 + 7.7);
	float displacement = (n * 0.7 + n2 * 0.3 - 0.5) * strength;
	VERTEX += NORMAL * displacement;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}


void fragment() {
	vec3 snapped_position = floor(world_position / pixel_world_size + 0.5) * pixel_world_size;
	vec3 map_position = snapped_position * triplanar_scale;
	if (tiling_warp > 0.001) {
		vec2 warp_uv = vec2(world_position.x + world_position.z * 0.37, world_position.z - world_position.x * 0.29);
		float warp = (vnoise(warp_uv * 0.11) - 0.5) * tiling_warp;
		map_position += vec3(warp, warp, warp) * triplanar_scale;
	}
	vec3 weights = blend_weights(world_normal);
	vec3 surface_color = albedo_color.rgb;
	vec3 texture_detail = vec3(1.0);
	if (use_albedo_texture) {
		texture_detail = sample_triplanar_color(albedo_texture, map_position, weights);
		texture_detail = vec3(0.5) + (texture_detail - vec3(0.5)) * texture_contrast;
		surface_color = mix(surface_color, texture_detail * albedo_color.rgb, texture_strength);
	}
	if (color_steps > 1.0) {
		surface_color = floor(surface_color * color_steps + 0.5) / color_steps;
	}
	ALBEDO = surface_color;

	float mapped_roughness = roughness;
	if (use_roughness_texture) {
		float rough_sample = sample_triplanar_channel(roughness_texture, map_position, weights);
		mapped_roughness = mix(roughness, rough_sample, roughness_texture_strength);
	}
	ROUGHNESS = clamp(mapped_roughness, 0.72, 1.0);
	METALLIC = 0.0;
	SPECULAR = 0.22;

	float mapped_ao = 1.0;
	if (use_ao_texture) {
		mapped_ao = sample_triplanar_channel(ao_texture, map_position, weights);
	} else if (use_albedo_texture) {
		mapped_ao = mix(1.0, smoothstep(0.08, 0.72, dot(texture_detail, vec3(0.299, 0.587, 0.114))), 0.24);
	}
	AO = mix(1.0, mapped_ao, ao_strength);
	AO_LIGHT_AFFECT = ao_light_affect;

	vec3 detail_normal = world_normal;
	if (use_normal_texture) {
		detail_normal = sample_triplanar_normal(map_position, world_normal, weights);
	} else if (derive_normal_from_albedo && use_albedo_texture) {
		detail_normal = sample_triplanar_height_normal(map_position, world_normal, weights);
	} else if (derive_normal_from_geometry) {
		vec3 derivative_normal = normalize(cross(dFdx(world_position), dFdy(world_position)));
		if (dot(derivative_normal, world_normal) < 0.0) {
			derivative_normal *= -1.0;
		}
		detail_normal = normalize(mix(world_normal, derivative_normal, normal_strength * 0.7));
	}
	NORMAL = normalize(mat3(VIEW_MATRIX) * detail_normal);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = rim_color * rim * rim_strength;
}
