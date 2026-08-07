class_name PrologueAtmosphere
extends Node3D

## Runtime atmosphere for the Xumen prologue greybox:
## warm stone lanterns with breathing light, drifting dust along the
## burial road, and rising corruption motes in the boss arena.

const LANTERN_COLOR: Color = Color(1.0, 0.62, 0.32, 1.0)
const DUST_COLOR: Color = Color(0.72, 0.70, 0.64, 0.045)
const CORRUPTION_COLOR: Color = Color(0.36, 0.68, 0.56, 0.08)
const STONE_COLOR: Color = Color(0.42, 0.4, 0.35, 1.0)
const HD2D_MATERIAL_LIBRARY = preload("res://scripts/world/hd2d_material_library.gd")
const HEIGHT_FOG_SHADER: Shader = preload("res://assets/shaders/animated_height_fog.gdshader")
const PIXEL_EMISSIVE_GRID_SHADER: Shader = preload("res://assets/shaders/pixel_emissive_grid.gdshader")
const ROUGH_STONE_TEXTURE: Texture2D = preload("res://assets/textures/terrain/cave_rock_wall_64.png")
const LANTERN_GRATE_TEXTURE: Texture2D = preload("res://assets/textures/terrain/cave_lantern_grate_8.png")

## Lantern rhythm: [position, base_energy, phase, lit]. Paired lamps mark the
## bridge thresholds; single lamps alternate along the safe route, while the
## last pair at the far bridge threshold has gone dark.
const LANTERNS: Array = [
	[Vector3(-2.85, 0.0, 8.65), 2.25, 0.0, true],
	[Vector3(2.85, 0.0, 7.55), 2.15, 1.3, true],
	[Vector3(-1.24, 0.0, 3.35), 2.0, 2.6, true],
	[Vector3(1.24, 0.0, 3.35), 2.0, 3.9, true],
	[Vector3(-1.26, 0.0, 0.75), 1.85, 0.7, true],
	[Vector3(1.26, 0.0, -1.35), 1.9, 2.0, true],
	[Vector3(-1.24, 0.0, -3.35), 0.0, 3.3, false],
	[Vector3(1.24, 0.0, -3.35), 0.0, 4.6, false],
	[Vector3(-2.7, 0.0, -7.2), 2.35, 1.1, true],
	[Vector3(1.9, 0.0, -14.0), 1.9, 2.4, true],
	[Vector3(-1.9, 0.0, -20.5), 1.8, 3.7, true],
	[Vector3(5.25, 0.0, -29.1), 2.25, 5.0, true],
	[Vector3(-1.28, 0.0, -37.0), 1.6, 1.9, true],
	[Vector3(6.0, 0.0, -47.4), 2.6, 3.2, true],
]

const DUST_EMITTERS: Array = [
	[Vector3(0.0, 0.65, 8.0), Vector3(4.2, 0.45, 3.5)],
	[Vector3(0.0, 0.8, -17.0), Vector3(5.0, 0.6, 12.0)],
	[Vector3(0.0, 0.8, -29.0), Vector3(11.0, 0.6, 9.0)],
]

const CORRUPTION_EMITTERS: Array = [
	[Vector3(-3.0, 0.8, -48.0), Vector3(4.0, 1.0, 4.0)],
	[Vector3(3.0, 0.8, -49.5), Vector3(4.0, 1.0, 4.0)],
	[Vector3(0.0, 0.8, -50.5), Vector3(3.0, 1.0, 3.0)],
]

var _lantern_lights: Array[OmniLight3D] = []
var _lantern_energy: Array[float] = []
var _lantern_phases: Array[float] = []
var _time: float = 0.0
var _light_cull_time: float = 0.0
var _camera: Camera3D
static var _shared_soft_dot_texture: ImageTexture


func _ready() -> void:
	_build_cold_shadow_fill()
	_build_deep_exit_crevice_light()
	_build_height_fog()
	_build_lanterns()
	_build_dust()
	_build_corruption()


func _process(delta: float) -> void:
	_time += delta
	_light_cull_time -= delta
	if _light_cull_time <= 0.0:
		_light_cull_time = 0.2
		_update_lantern_visibility()
	for i: int in _lantern_lights.size():
		var light: OmniLight3D = _lantern_lights[i]
		if not light.visible:
			continue
		var base: float = _lantern_energy[i]
		var breath: float = 0.82 + 0.18 * sin(_time * 1.9 + _lantern_phases[i])
		light.light_energy = base * breath


func _update_lantern_visibility() -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if _camera == null:
		return
	const ACTIVE_DISTANCE_SQUARED: float = 18.0 * 18.0
	for light: OmniLight3D in _lantern_lights:
		var is_lit: bool = bool(light.get_meta(&"lit", true))
		light.visible = is_lit and light.global_position.distance_squared_to(
			_camera.global_position
		) <= ACTIVE_DISTANCE_SQUARED


func _build_lanterns() -> void:
	for entry: Array in LANTERNS:
		var position: Vector3 = entry[0]
		var is_deep_exit: bool = position.z > 5.0
		var is_lit: bool = bool(entry[3])
		var energy: float = float(entry[1]) * (1.72 if is_deep_exit else 1.18)
		var phase: float = entry[2]
		var lantern: Node3D = Node3D.new()
		lantern.name = &"Lantern"
		lantern.position = position
		add_child(lantern)

		_build_stone_lantern(lantern, is_lit)
		_add_lantern_companion(lantern, int(_lantern_lights.size()))
		if is_lit:
			_add_lantern_ground_glow(lantern, 1.35 if is_deep_exit else 1.22)

		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = LANTERN_COLOR
		light.light_energy = energy
		light.omni_range = 10.8 if is_deep_exit else 11.2
		## Godot's attenuation exponent of 2.0 gives a smooth inverse-square
		## falloff instead of the old bright sphere / hard range boundary.
		light.omni_attenuation = 2.0
		light.shadow_enabled = is_deep_exit
		light.shadow_opacity = 0.64
		light.shadow_bias = 0.08
		light.shadow_normal_bias = 0.55
		light.light_size = 0.42
		light.light_volumetric_fog_energy = 0.42 if is_deep_exit else 0.0
		light.position = Vector3(0.0, 1.34 if is_deep_exit else 1.7, 0.0)
		light.set_meta(&"lit", is_lit)
		light.visible = is_lit
		lantern.add_child(light)
		_lantern_lights.append(light)
		_lantern_energy.append(energy)
		_lantern_phases.append(phase)


func _build_cold_shadow_fill() -> void:
	var fill := OmniLight3D.new()
	fill.name = &"ColdShadowFill"
	fill.position = Vector3(-3.2, 3.4, 4.0)
	fill.light_color = Color("1a2040")
	fill.light_energy = 0.16
	fill.omni_range = 13.0
	fill.omni_attenuation = 1.35
	fill.shadow_enabled = false
	fill.light_volumetric_fog_energy = 0.18
	add_child(fill)


func _build_deep_exit_crevice_light() -> void:
	## The old floating moon pool had no visible source. A narrow emissive seam
	## now sits in the right canyon wall and the shaft follows the same direction.
	var crevice := Node3D.new()
	crevice.name = &"CaveLightCrevice"
	crevice.position = Vector3(3.15, 3.5, 4.3)
	crevice.rotation_degrees.z = -7.0
	add_child(crevice)

	var seam := _box_mesh(Vector3(0.055, 2.15, 0.32), Color(1.0, 0.72, 0.42, 1.0), true)
	seam.name = &"EmissiveSeam"
	crevice.add_child(seam)
	for offset: Vector3 in [Vector3(-0.11, 0.05, 0.0), Vector3(0.11, -0.08, 0.0)]:
		var lip := _box_mesh(Vector3(0.12, 2.42, 0.48), Color(0.19, 0.18, 0.17, 1.0))
		lip.position = offset
		lip.rotation_degrees.z = 4.0 * signf(offset.x)
		crevice.add_child(lip)

	var light := SpotLight3D.new()
	light.name = &"DeepExitCreviceShaft"
	light.position = Vector3(3.0, 4.6, 4.3)
	light.look_at_from_position(light.position, Vector3(0.7, 0.05, 3.4), Vector3.UP)
	light.light_color = Color(1.0, 0.69, 0.39, 1.0)
	light.light_energy = 2.15
	light.light_volumetric_fog_energy = 1.75
	light.light_size = 0.62
	light.spot_range = 8.5
	light.spot_angle = 24.0
	light.spot_attenuation = 2.0
	light.shadow_enabled = true
	light.shadow_opacity = 0.58
	light.shadow_bias = 0.08
	light.shadow_normal_bias = 0.5
	add_child(light)


func _build_height_fog() -> void:
	var fog_volume := FogVolume.new()
	fog_volume.name = &"BurialRoadHeightFog"
	fog_volume.position = Vector3(0.0, 1.2, -20.0)
	fog_volume.size = Vector3(18.0, 4.0, 72.0)
	var fog_material := ShaderMaterial.new()
	fog_material.shader = HEIGHT_FOG_SHADER
	fog_material.set_shader_parameter(&"fog_color", Vector3(0.18, 0.23, 0.25))
	fog_material.set_shader_parameter(&"base_density", 0.08)
	fog_material.set_shader_parameter(&"base_height", -0.42)
	fog_material.set_shader_parameter(&"height_falloff", 1.75)
	fog_material.set_shader_parameter(&"noise_scale", 0.16)
	fog_material.set_shader_parameter(&"noise_strength", 0.34)
	fog_material.set_shader_parameter(&"clear_path_half_width", 1.55)
	fog_material.set_shader_parameter(&"outer_fog_width", 4.8)
	fog_material.set_shader_parameter(&"flow_speed", Vector2(0.018, -0.012))
	fog_volume.material = fog_material
	add_child(fog_volume)


func _build_stone_lantern(lantern: Node3D, is_lit: bool) -> void:
	var parts: Array[MeshInstance3D] = [
		_cylinder_mesh(0.34, 0.42, 0.14, STONE_COLOR, 8),
		_cylinder_mesh(0.1, 0.14, 0.9, STONE_COLOR, 8),
		_cylinder_mesh(0.22, 0.26, 0.12, STONE_COLOR, 8),
		_box_mesh(
			Vector3(0.3, 0.22, 0.3),
			LANTERN_COLOR if is_lit else Color(0.18, 0.13, 0.12, 1.0),
			is_lit, is_lit
		),
		_cylinder_mesh(0.16, 0.4, 0.22, STONE_COLOR, 4),
		_cylinder_mesh(0.04, 0.09, 0.13, STONE_COLOR, 8),
	]
	var heights := [0.08, 0.58, 1.07, 1.25, 1.48, 1.66]
	for index: int in parts.size():
		parts[index].name = &"StonePart%d" % index
		parts[index].position = Vector3(0.0, heights[index], 0.0)
		lantern.add_child(parts[index])
	for index: int in range(2):
		var eave := _box_mesh(
			Vector3(0.55 - index * 0.08, 0.045, 0.55 - index * 0.08),
			STONE_COLOR.darkened(0.12)
		)
		eave.name = &"Eave%d" % index
		eave.position = Vector3(0.0, 1.43 + index * 0.045, 0.0)
		eave.rotation_degrees.y = 45.0 if index == 0 else 0.0
		lantern.add_child(eave)


func _add_lantern_ground_glow(lantern: Node3D, radius: float) -> void:
	var glow := MeshInstance3D.new()
	glow.name = &"GroundGlow"
	glow.position = Vector3(0.0, 0.028, 0.0)
	glow.rotation_degrees.x = -90.0
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(radius * 2.0, radius * 2.0)
	glow.mesh = quad
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _make_soft_dot_texture()
	material.albedo_color = LANTERN_COLOR.lerp(Color(1.0, 0.12, 0.07, 1.0), 0.3)
	material.albedo_color.a = 0.4
	material.emission_enabled = true
	material.emission = Color(1.0, 0.24, 0.09, 1.0)
	material.emission_energy_multiplier = 0.9
	glow.material_override = material
	lantern.add_child(glow)


func _add_lantern_companion(lantern: Node3D, index: int) -> void:
	var side: float = -1.0 if index % 2 == 0 else 1.0
	var companion := _box_mesh(
		Vector3(0.18, 0.25 + float(index % 3) * 0.055, 0.2),
		Color(0.24, 0.27, 0.26, 1.0)
	)
	companion.name = &"CompanionStone"
	companion.position = Vector3(side * 0.5, 0.125, 0.12)
	companion.rotation_degrees.y = float(index * 19 % 35) - 17.0
	var companion_material := StandardMaterial3D.new()
	companion_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	companion_material.albedo_color = Color(0.16, 0.21, 0.22, 1.0)
	companion_material.albedo_texture = ROUGH_STONE_TEXTURE
	companion_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	companion_material.roughness = 1.0
	companion.material_override = companion_material
	lantern.add_child(companion)


func _build_dust() -> void:
	for entry: Array in DUST_EMITTERS:
		var center: Vector3 = entry[0]
		var extents: Vector3 = entry[1]
		var is_deep_exit: bool = center.z > 5.0
		var dust_color: Color = DUST_COLOR
		if is_deep_exit:
			## 全屏构图下近景尘斑容易叠成浅色团，出口段进一步压低透明度。
			dust_color.a = 0.024
		var particles: GPUParticles3D = _make_particles(
			center, extents, dust_color, 120 if is_deep_exit else 252,
			9.0 if is_deep_exit else 8.0,
			Vector2(0.035, 0.12) if is_deep_exit else Vector2(0.055, 0.18),
			Vector2(0.009, 0.032) if is_deep_exit else Vector2(0.012, 0.04)
		)
		particles.name = &"Dust"
		add_child(particles)


func _build_corruption() -> void:
	for entry: Array in CORRUPTION_EMITTERS:
		var center: Vector3 = entry[0]
		var extents: Vector3 = entry[1]
		var particles: GPUParticles3D = _make_particles(
			center, extents, CORRUPTION_COLOR, 156, 5.2, Vector2(0.045, 0.16), Vector2(0.012, 0.038)
		)
		particles.name = &"CorruptionMotes"
		add_child(particles)


func _make_particles(
	center: Vector3,
	extents: Vector3,
	color: Color,
	amount: int,
	lifetime: float,
	velocity_range: Vector2,
	scale_range: Vector2
) -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.position = center
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = lifetime
	particles.fixed_fps = 30
	particles.local_coords = true
	particles.draw_pass_1 = QuadMesh.new()
	var quad: QuadMesh = particles.draw_pass_1 as QuadMesh
	quad.size = Vector2(0.5, 0.5)

	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3(0.0, 1.0, 0.0)
	process_material.spread = 55.0
	process_material.gravity = Vector3(0.0, -0.15, 0.0)
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = extents
	process_material.initial_velocity_min = velocity_range.x
	process_material.initial_velocity_max = velocity_range.y
	process_material.scale_min = scale_range.x
	process_material.scale_max = scale_range.y
	process_material.color = color
	particles.process_material = process_material

	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.proximity_fade_enabled = true
	material.proximity_fade_distance = 0.8
	material.albedo_texture = _make_soft_dot_texture()
	material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	particles.material_override = material
	return particles


func _cylinder_mesh(top_radius: float, bottom_radius: float, height: float, color: Color, radial_segments: int = 24) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	## The lantern fixture must not shadow its own point light; environment
	## geometry still receives and casts the soft shadows.
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = top_radius
	cylinder_mesh.bottom_radius = bottom_radius
	cylinder_mesh.height = height
	cylinder_mesh.radial_segments = radial_segments
	mesh_instance.mesh = cylinder_mesh
	mesh_instance.material_override = _get_stylized_stone_material(color)
	return mesh_instance


func _box_mesh(size: Vector3, color: Color, emissive: bool = false, emissive_grid: bool = false) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	var material: Material
	if emissive:
		var emissive_material := ShaderMaterial.new()
		emissive_material.shader = PIXEL_EMISSIVE_GRID_SHADER
		emissive_material.set_shader_parameter(&"base_color", color.darkened(0.72))
		emissive_material.set_shader_parameter(&"glow_color", color)
		emissive_material.set_shader_parameter(&"grate_texture", LANTERN_GRATE_TEXTURE)
		emissive_material.set_shader_parameter(&"use_grate_texture", emissive_grid)
		emissive_material.set_shader_parameter(&"grid_cells", Vector2(4.0, 3.0) if emissive_grid else Vector2.ONE)
		emissive_material.set_shader_parameter(&"bar_width", 0.18 if emissive_grid else 0.0)
		emissive_material.set_shader_parameter(&"emission_energy", 5.2 if emissive_grid else 3.2)
		material = emissive_material
	else:
		material = _get_stylized_stone_material(color)
	mesh_instance.material_override = material
	return mesh_instance


func _get_stylized_stone_material(color: Color) -> ShaderMaterial:
	return HD2D_MATERIAL_LIBRARY.get_stone(
		ROUGH_STONE_TEXTURE, color, 1.35, 0.065, 0.74, 0.68, 0.96, 0.72, 0.76
	)


## Generates a small soft radial dot texture for particle sprites.
func _make_soft_dot_texture(size: int = 48) -> ImageTexture:
	if _shared_soft_dot_texture != null:
		return _shared_soft_dot_texture
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y: int in range(size):
		for x: int in range(size):
			var dx: float = (float(x) + 0.5) / float(size) * 2.0 - 1.0
			var dy: float = (float(y) + 0.5) / float(size) * 2.0 - 1.0
			var distance: float = sqrt(dx * dx + dy * dy)
			var alpha: float = clampf(1.0 - distance * 1.5, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha * alpha))
	_shared_soft_dot_texture = ImageTexture.create_from_image(image)
	return _shared_soft_dot_texture
