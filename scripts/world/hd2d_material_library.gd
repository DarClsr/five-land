class_name HD2DMaterialLibrary
extends RefCounted

const STONE_SHADER: Shader = preload("res://assets/shaders/organic_rock.gdshader")

static var _stone_materials: Dictionary[String, ShaderMaterial] = {}


static func get_stone(
	texture: Texture2D,
	tint: Color,
	triplanar_scale: float,
	pixel_world_size: float = 0.075,
	texture_strength: float = 0.86,
	texture_contrast: float = 0.7,
	roughness: float = 0.95,
	normal_strength: float = 0.68,
	ao_strength: float = 0.7,
	displacement_strength: float = 0.0
) -> ShaderMaterial:
	var texture_id: String = texture.resource_path if texture != null else "none"
	var key := "%s|%s|%.3f|%.3f|%.2f|%.2f|%.2f|%.2f|%.2f|%.2f" % [
		texture_id, tint.to_html(), triplanar_scale, pixel_world_size,
		texture_strength, texture_contrast, roughness, normal_strength,
		ao_strength, displacement_strength,
	]
	if _stone_materials.has(key):
		return _stone_materials[key]
	var material := ShaderMaterial.new()
	material.shader = STONE_SHADER
	material.set_shader_parameter(&"albedo_color", tint)
	material.set_shader_parameter(&"use_albedo_texture", texture != null)
	material.set_shader_parameter(&"albedo_texture", texture)
	material.set_shader_parameter(&"texture_strength", texture_strength)
	material.set_shader_parameter(&"texture_contrast", texture_contrast)
	material.set_shader_parameter(&"triplanar_scale", triplanar_scale)
	material.set_shader_parameter(&"pixel_world_size", pixel_world_size)
	material.set_shader_parameter(&"roughness", roughness)
	material.set_shader_parameter(&"ao_strength", ao_strength)
	material.set_shader_parameter(&"normal_strength", normal_strength)
	material.set_shader_parameter(&"use_normal_texture", false)
	material.set_shader_parameter(&"derive_normal_from_albedo", texture != null)
	material.set_shader_parameter(&"strength", displacement_strength)
	material.set_shader_parameter(&"tiling_warp", 0.3)
	_stone_materials[key] = material
	return material
