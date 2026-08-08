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

## Runtime budgets are kept here so low-end tuning never requires hunting
## through scene nodes or changing authored level content.
const EFFECT_CULL_INTERVAL: float = 0.2
const EFFECT_DISTANCE: float = 18.0
const MAX_ACTIVE_LANTERNS: int = 5
const MAX_SHADOWED_LANTERNS: int = 3
const MAX_ACTIVE_AMBIENT_EMITTERS: int = 3
const MAX_RUNE_LIGHTS: int = 6
const TORCH_RANGE: float = 7.2
const TORCH_CORE_EMISSION: float = 3.25
const TORCH_GROUND_GLOW_ALPHA: float = 0.18
const TORCH_SPARK_COUNT: int = 7
const DUST_PARTICLE_COUNT: int = 96
const CORRUPTION_PARTICLE_COUNT: int = 72
const RUNE_COLOR: Color = Color(0.28, 0.82, 0.78, 1.0)
const WEB_COLOR: Color = Color(0.68, 0.72, 0.68, 0.42)
const WEB_POSITIONS: Array = [
	[Vector3(-1.15, 0.24, -29.15), Vector3(0.0, 18.0, -4.0), 0.72],
	[Vector3(8.55, 0.28, -29.65), Vector3(0.0, -22.0, 3.0), 0.65],
	[Vector3(-11.45, 0.35, -6.35), Vector3(0.0, 12.0, -6.0), 0.62],
]
const SPIDER_PATHS: Array = [
	[Vector3(-1.55, 0.07, -28.2), Vector3(-3.65, 0.07, -30.15), 0.18],
	[Vector3(9.05, 0.07, -25.55), Vector3(12.25, 0.07, -24.75), 0.67],
]

## Lantern rhythm: [position, base_energy, phase, lit]. Paired lamps mark the
## bridge thresholds; single lamps alternate along the safe route, while the
## last pair at the far bridge threshold has gone dark.
const LANTERNS: Array = [
	[Vector3(-4.4, 0.0, 8.65), 2.25, 0.0, true],
	[Vector3(4.4, 0.0, 7.55), 2.15, 1.3, true],
	[Vector3(-0.45, 0.0, 3.25), 2.0, 2.6, true],
	[Vector3(-3.55, 0.0, -3.25), 2.0, 3.9, true],
	[Vector3(-7.0, 0.0, -5.0), 1.85, 0.7, true],
	[Vector3(-2.2, 0.0, -8.8), 1.9, 2.0, true],
	[Vector3(-5.6, 0.0, -9.2), 0.0, 3.3, false],
	[Vector3(-2.1, 0.0, -10.1), 0.0, 4.6, false],
	[Vector3(-10.0, 0.0, -7.1), 2.35, 1.1, true],
	[Vector3(-2.4, 0.0, -13.0), 1.9, 2.4, true],
	[Vector3(2.1, 0.0, -20.8), 1.8, 3.7, true],
	[Vector3(11.7, 0.0, -27.1), 2.25, 5.0, true],
	[Vector3(0.3, 0.0, -25.9), 1.9, 2.9, true],
	[Vector3(4.0, 0.0, -29.2), 1.95, 4.2, true],
	[Vector3(1.2, 0.0, -34.0), 1.25, 1.9, true],
	[Vector3(7.7, 0.0, -44.4), 2.6, 3.2, true],
]

const DUST_EMITTERS: Array = [
	[Vector3(0.0, 0.65, 8.0), Vector3(6.2, 0.45, 3.5)],
	[Vector3(0.0, 0.8, -16.5), Vector3(10.0, 0.6, 16.0)],
	[Vector3(4.0, 0.8, -27.0), Vector3(18.0, 0.6, 10.0)],
]

const CORRUPTION_EMITTERS: Array = [
	[Vector3(-8.0, 0.8, -44.0), Vector3(5.0, 1.0, 4.0)],
	[Vector3(4.0, 0.8, -45.5), Vector3(5.0, 1.0, 4.0)],
	[Vector3(-2.0, 0.8, -47.0), Vector3(3.0, 1.0, 3.0)],
]

var _lantern_lights: Array[OmniLight3D] = []
var _lantern_energy: Array[float] = []
var _lantern_phases: Array[float] = []
var _lantern_core_materials: Array[ShaderMaterial] = []
var _lantern_glow_materials: Array[StandardMaterial3D] = []
var _lantern_sparks: Array[GPUParticles3D] = []
var _ambient_emitters: Array[GPUParticles3D] = []
var _rune_lights: Array[OmniLight3D] = []
var _guide_lights: Array[OmniLight3D] = []
var _rune_visuals: Array[Sprite3D] = []
var _rune_base_modulates: Array[Color] = []
var _mechanism_visuals: Array[Sprite3D] = []
var _webs: Array[Node3D] = []
var _spiders: Array[Node3D] = []
var _spider_progress: Array[float] = []
var _spider_direction: Array[float] = []
var _time: float = 0.0
var _light_cull_time: float = 0.0
var _camera: Camera3D
var _player: Node3D
var _player_material: ShaderMaterial
static var _shared_soft_dot_texture: ImageTexture


func _ready() -> void:
	_build_cold_shadow_fill()
	_build_deep_exit_crevice_light()
	_build_height_fog()
	_build_lanterns()
	_build_rune_effects()
	_build_boss_gate_guidance()
	_build_dust()
	_build_corruption()
	_build_cave_life()
	_cache_player_material()
	_update_effect_visibility()


func _process(delta: float) -> void:
	_time += delta
	_light_cull_time -= delta
	if _light_cull_time <= 0.0:
		_light_cull_time = EFFECT_CULL_INTERVAL
		_update_effect_visibility()
	for i: int in _lantern_lights.size():
		var light: OmniLight3D = _lantern_lights[i]
		if not light.visible:
			continue
		var base: float = _lantern_energy[i]
		var phase: float = _lantern_phases[i]
		## Three incommensurate waves avoid the metronomic pulse of one sine.
		var flicker: float = 0.88 \
			+ sin(_time * 1.73 + phase) * 0.07 \
			+ sin(_time * 4.37 + phase * 1.7) * 0.035 \
			+ sin(_time * 7.91 + phase * 0.6) * 0.015
		light.light_energy = base * flicker
		_lantern_core_materials[i].set_shader_parameter(
			&"emission_energy", TORCH_CORE_EMISSION * flicker
		)
		var glow_material: StandardMaterial3D = _lantern_glow_materials[i]
		if glow_material != null:
			var glow_color: Color = glow_material.albedo_color
			glow_color.a = TORCH_GROUND_GLOW_ALPHA * flicker
			glow_material.albedo_color = glow_color
			glow_material.emission_energy_multiplier = 0.38 * flicker
	_update_runes_and_mechanisms()
	_update_player_torch_influence()
	_update_cave_life(delta)


func _update_lantern_visibility() -> void:
	_update_effect_visibility()


func _update_effect_visibility() -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if _camera == null:
		return
	var active_lights: int = 0
	var active_shadows: int = 0
	var active_distance_squared: float = EFFECT_DISTANCE * EFFECT_DISTANCE
	for light: OmniLight3D in _lantern_lights:
		light.visible = false
		light.shadow_enabled = false
	## Nearest lights win the active cap, otherwise array order would starve
	## later route sections whose lamps sit closer to the camera.
	var candidates: Array = []
	for index: int in _lantern_lights.size():
		var light: OmniLight3D = _lantern_lights[index]
		if not bool(light.get_meta(&"lit", true)):
			_lantern_sparks[index].emitting = false
			continue
		candidates.append({
			"light": light,
			"index": index,
			"distance": light.global_position.distance_squared_to(_camera.global_position),
		})
	candidates.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool:
			return a.distance < b.distance
	)
	for entry: Dictionary in candidates:
		var light: OmniLight3D = entry.light
		if entry.distance > active_distance_squared or active_lights >= MAX_ACTIVE_LANTERNS:
			_lantern_sparks[entry.index].emitting = false
			continue
		light.visible = true
		light.shadow_enabled = active_shadows < MAX_SHADOWED_LANTERNS
		_lantern_sparks[entry.index].emitting = true
		active_lights += 1
		active_shadows += 1 if light.shadow_enabled else 0
	var active_ambient: int = 0
	for emitter: GPUParticles3D in _ambient_emitters:
		var in_range: bool = emitter.global_position.distance_squared_to(
			_camera.global_position
		) <= active_distance_squared
		emitter.emitting = in_range and active_ambient < MAX_ACTIVE_AMBIENT_EMITTERS
		active_ambient += 1 if emitter.emitting else 0
	for light: OmniLight3D in _rune_lights:
		light.visible = light.get_parent().is_visible_in_tree() and light.global_position.distance_squared_to(
			_camera.global_position
		) <= active_distance_squared
	for light: OmniLight3D in _guide_lights:
		light.visible = light.global_position.distance_squared_to(
			_camera.global_position
		) <= active_distance_squared


func _build_lanterns() -> void:
	for entry: Array in LANTERNS:
		var position: Vector3 = entry[0]
		var is_deep_exit: bool = position.z > 5.0
		var is_lit: bool = bool(entry[3])
		var energy: float = float(entry[1]) * (1.18 if is_deep_exit else 1.02)
		var phase: float = entry[2]
		var lantern: Node3D = Node3D.new()
		lantern.name = &"Lantern"
		lantern.position = position
		add_child(lantern)

		_build_stone_lantern(lantern, is_lit)
		_add_lantern_companion(lantern, int(_lantern_lights.size()))
		var core := lantern.get_node("StonePart3") as MeshInstance3D
		_lantern_core_materials.append(core.material_override as ShaderMaterial)
		var glow_material: StandardMaterial3D
		if is_lit:
			glow_material = _add_lantern_ground_glow(
				lantern, 1.0 if is_deep_exit else 0.9
			)
		_lantern_glow_materials.append(glow_material)
		_lantern_sparks.append(_add_flame_sparks(lantern, is_lit))

		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = LANTERN_COLOR
		light.light_energy = energy
		light.omni_range = TORCH_RANGE
		## Godot's attenuation exponent of 2.0 gives a smooth inverse-square
		## falloff instead of the old bright sphere / hard range boundary.
		light.omni_attenuation = 2.0
		light.shadow_enabled = false
		light.shadow_opacity = 0.45
		light.shadow_bias = 0.08
		light.shadow_normal_bias = 0.4
		light.light_size = 0.42
		light.light_volumetric_fog_energy = 0.24 if is_deep_exit else 0.06
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
	light.light_energy = 1.55
	light.light_volumetric_fog_energy = 1.05
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
	fog_volume.position = Vector3(0.0, 1.2, -18.0)
	fog_volume.size = Vector3(28.0, 4.0, 68.0)
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


func _add_lantern_ground_glow(lantern: Node3D, radius: float) -> StandardMaterial3D:
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
	material.albedo_color.a = TORCH_GROUND_GLOW_ALPHA
	material.emission_enabled = true
	material.emission = Color(1.0, 0.24, 0.09, 1.0)
	material.emission_energy_multiplier = 0.38
	glow.material_override = material
	lantern.add_child(glow)
	return material


func _add_flame_sparks(lantern: Node3D, is_lit: bool) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = &"FlameSparks"
	particles.position = Vector3(0.0, 1.34, 0.0)
	particles.amount = TORCH_SPARK_COUNT
	particles.lifetime = 0.9
	particles.randomness = 0.72
	particles.fixed_fps = 20
	particles.local_coords = true
	particles.emitting = false
	particles.visibility_aabb = AABB(Vector3(-0.45, -0.2, -0.45), Vector3(0.9, 1.8, 0.9))
	var quad := QuadMesh.new()
	quad.size = Vector2(0.08, 0.08)
	particles.draw_pass_1 = quad
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3.UP
	process_material.spread = 26.0
	process_material.gravity = Vector3(0.0, 0.18, 0.0)
	process_material.initial_velocity_min = 0.24
	process_material.initial_velocity_max = 0.62
	process_material.scale_min = 0.25
	process_material.scale_max = 0.7
	process_material.color = Color(1.0, 0.56, 0.22, 0.72 if is_lit else 0.0)
	particles.process_material = process_material
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = _make_soft_dot_texture()
	particles.material_override = material
	lantern.add_child(particles)
	return particles


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


func _build_rune_effects() -> void:
	var sources: Array[Node] = get_tree().get_nodes_in_group(&"rune_source")
	for source: Node in sources:
		if _rune_lights.size() >= MAX_RUNE_LIGHTS:
			break
		if not source is Node3D:
			continue
		var source_3d := source as Node3D
		var visual := source_3d.get_node_or_null("Visual") as Sprite3D
		if visual == null:
			continue
		var light := OmniLight3D.new()
		light.name = &"RuneSpill"
		light.position = Vector3(0.0, 0.28, 0.0)
		light.light_color = RUNE_COLOR
		light.light_energy = 0.28
		light.omni_range = 2.45
		light.omni_attenuation = 2.0
		light.shadow_enabled = false
		light.light_volumetric_fog_energy = 0.08
		source_3d.add_child(light)
		_rune_lights.append(light)
		_rune_visuals.append(visual)
		_rune_base_modulates.append(visual.modulate)
	for source: Node in get_tree().get_nodes_in_group(&"mechanism_motion"):
		if source is Node3D:
			var visual := (source as Node3D).get_node_or_null("Visual") as Sprite3D
			if visual != null:
				_mechanism_visuals.append(visual)


## The boss gate sits at the dark end of the diagonal passage; two cool flank
## lights and a rune glow pool give the approach a readable target instead of
## dropping into pure black. The lights join the rune culling budget.
func _build_boss_gate_guidance() -> void:
	var level := get_parent()
	if level == null:
		return
	var gate := level.get_node_or_null("GreyboxRoute/GravePassage/BossGate") as Node3D
	if gate == null:
		return
	var guidance := Node3D.new()
	guidance.name = &"BossGateGuidance"
	add_child(guidance)
	var right: Vector3 = gate.basis.x
	var forward: Vector3 = -gate.basis.z
	var gate_position: Vector3 = gate.global_position
	for side: int in [-1, 1]:
		var light := OmniLight3D.new()
		light.name = &"GuideLightL" if side < 0 else &"GuideLightR"
		light.position = gate_position + right * (2.1 * side) + Vector3.UP * 1.5
		light.light_color = Color(0.52, 0.68, 0.78, 1.0)
		light.light_energy = 0.55
		light.omni_range = 6.0
		light.omni_attenuation = 2.0
		light.shadow_enabled = false
		light.light_volumetric_fog_energy = 0.1
		guidance.add_child(light)
		_guide_lights.append(light)
		var flank_glow := _make_rune_glow_quad(
			guidance, &"GlowFlankL" if side < 0 else &"GlowFlankR",
			gate_position + forward * 1.6 + right * (1.7 * side), 0.55, 0.14
		)
	var front_glow := _make_rune_glow_quad(
		guidance, &"GlowFront", gate_position + forward * 2.3, 0.95, 0.11
	)


func _make_rune_glow_quad(
	parent: Node3D, glow_name: StringName, position: Vector3, radius: float, alpha: float
) -> MeshInstance3D:
	var glow := MeshInstance3D.new()
	glow.name = glow_name
	glow.position = position
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
	material.albedo_color = RUNE_COLOR.lerp(Color.WHITE, 0.3)
	material.albedo_color.a = alpha
	material.emission_enabled = true
	material.emission = RUNE_COLOR
	material.emission_energy_multiplier = 0.65
	glow.material_override = material
	parent.add_child(glow)
	return glow


func _cache_player_material() -> void:
	var level := get_parent()
	if level == null:
		return
	_player = level.get_node_or_null("Entities/Player") as Node3D
	if _player == null:
		return
	var visual := _player.get_node_or_null("Visual") as AnimatedSprite3D
	if visual != null:
		_player_material = visual.material_override as ShaderMaterial


func _update_runes_and_mechanisms() -> void:
	for index: int in _rune_lights.size():
		var light: OmniLight3D = _rune_lights[index]
		if not light.visible:
			continue
		var pulse: float = 0.5 + 0.5 * sin(_time * 0.72 + float(index) * 1.41)
		light.light_energy = lerpf(0.26, 0.42, pulse)
		_rune_visuals[index].modulate = _rune_base_modulates[index].lerp(
			RUNE_COLOR, lerpf(0.055, 0.1, pulse)
		)
	for visual: Sprite3D in _mechanism_visuals:
		if visual.is_visible_in_tree() and (
			_camera == null
			or visual.global_position.distance_squared_to(_camera.global_position)
				<= EFFECT_DISTANCE * EFFECT_DISTANCE
		):
			visual.rotation.z = fmod(_time * 0.075, TAU)
	for index: int in _guide_lights.size():
		var light: OmniLight3D = _guide_lights[index]
		if not light.visible:
			continue
		var pulse: float = 0.5 + 0.5 * sin(_time * 0.55 + float(index) * 2.1)
		light.light_energy = lerpf(0.42, 0.68, pulse)


func _update_player_torch_influence() -> void:
	if _player == null or not is_instance_valid(_player) or _player_material == null:
		_cache_player_material()
	if _player == null or _player_material == null:
		return
	var influence: float = 0.0
	for light: OmniLight3D in _lantern_lights:
		if not light.visible:
			continue
		var distance: float = _player.global_position.distance_to(light.global_position)
		influence = maxf(influence, 1.0 - distance / TORCH_RANGE)
	_player_material.set_shader_parameter(
		&"warm_light_strength", lerpf(0.1, 0.38, smoothstep(0.0, 1.0, influence))
	)


func _build_cave_life() -> void:
	var life := Node3D.new()
	life.name = &"CaveLife"
	add_child(life)
	for index: int in WEB_POSITIONS.size():
		var entry: Array = WEB_POSITIONS[index]
		var web := _build_spider_web(float(entry[2]))
		web.name = StringName("SpiderWeb%d" % (index + 1))
		web.position = entry[0]
		web.rotation_degrees = entry[1]
		web.set_meta(&"base_rotation_z", web.rotation_degrees.z)
		web.set_meta(&"phase", float(index) * 1.7)
		life.add_child(web)
		_webs.append(web)
	for index: int in SPIDER_PATHS.size():
		var entry: Array = SPIDER_PATHS[index]
		var spider := _build_spider()
		spider.name = StringName("Spider%d" % (index + 1))
		spider.position = entry[0]
		spider.set_meta(&"path_start", entry[0])
		spider.set_meta(&"path_end", entry[1])
		life.add_child(spider)
		_spiders.append(spider)
		_spider_progress.append(float(entry[2]))
		_spider_direction.append(1.0)


func _build_spider_web(radius: float) -> MeshInstance3D:
	var web := MeshInstance3D.new()
	web.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := ImmediateMesh.new()
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.albedo_color = WEB_COLOR
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, material)
	const SPOKES: int = 6
	for spoke: int in range(SPOKES):
		var angle: float = (PI * 0.5) * float(spoke) / float(SPOKES - 1)
		_add_web_strand(
			mesh, Vector2.ZERO, Vector2(cos(angle), sin(angle)) * radius, 0.018
		)
	for ring: float in [0.32, 0.58, 0.82]:
		for spoke: int in range(SPOKES - 1):
			var angle_a: float = (PI * 0.5) * float(spoke) / float(SPOKES - 1)
			var angle_b: float = (PI * 0.5) * float(spoke + 1) / float(SPOKES - 1)
			_add_web_strand(
				mesh,
				Vector2(cos(angle_a), sin(angle_a)) * radius * ring,
				Vector2(cos(angle_b), sin(angle_b)) * radius * ring,
				0.014
			)
	mesh.surface_end()
	web.mesh = mesh
	return web


func _add_web_strand(mesh: ImmediateMesh, start: Vector2, end: Vector2, thickness: float) -> void:
	var direction: Vector2 = (end - start).normalized()
	var normal := Vector2(-direction.y, direction.x) * thickness * 0.5
	for point: Vector2 in [start - normal, end - normal, end + normal, start - normal, end + normal, start + normal]:
		mesh.surface_set_color(WEB_COLOR)
		mesh.surface_add_vertex(Vector3(point.x, point.y, 0.0))


func _build_spider() -> Node3D:
	var spider := Node3D.new()
	var spider_material := StandardMaterial3D.new()
	spider_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spider_material.albedo_color = Color(0.2, 0.065, 0.035, 1.0)
	spider_material.emission_enabled = true
	spider_material.emission = Color(0.06, 0.012, 0.006, 1.0)
	spider_material.emission_energy_multiplier = 0.35
	var body := _box_mesh(Vector3(0.15, 0.075, 0.2), Color(0.075, 0.055, 0.045, 1.0))
	body.name = &"Body"
	body.position.y = 0.055
	body.material_override = spider_material
	spider.add_child(body)
	var head := _box_mesh(Vector3(0.11, 0.065, 0.1), Color(0.11, 0.065, 0.045, 1.0))
	head.name = &"Head"
	head.position = Vector3(0.0, 0.052, -0.13)
	head.material_override = spider_material
	spider.add_child(head)
	for side: float in [-1.0, 1.0]:
		for leg_index: int in range(4):
			var leg := _box_mesh(Vector3(0.018, 0.018, 0.16), Color(0.055, 0.045, 0.04, 1.0))
			leg.position = Vector3(side * 0.1, 0.035, -0.075 + float(leg_index) * 0.05)
			leg.rotation_degrees.y = side * (48.0 + float(leg_index) * 10.0)
			leg.material_override = spider_material
			spider.add_child(leg)
	return spider


func _update_cave_life(delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var active_distance_squared: float = EFFECT_DISTANCE * EFFECT_DISTANCE
	for web: Node3D in _webs:
		var in_range: bool = web.global_position.distance_squared_to(_camera.global_position) <= active_distance_squared
		web.visible = in_range
		if in_range:
			var phase: float = float(web.get_meta(&"phase", 0.0))
			var sway: float = sin(_time * 0.62 + phase)
			web.rotation_degrees.z = float(web.get_meta(&"base_rotation_z", 0.0)) + sway * 0.65
			web.scale = Vector3(1.0 - sway * 0.006, 1.0 + sway * 0.012, 1.0)
	for index: int in _spiders.size():
		var spider: Node3D = _spiders[index]
		var in_range: bool = spider.global_position.distance_squared_to(_camera.global_position) <= active_distance_squared
		spider.visible = in_range
		if not in_range:
			continue
		var path_start: Vector3 = spider.get_meta(&"path_start")
		var path_end: Vector3 = spider.get_meta(&"path_end")
		var speed: float = 0.11
		if _player != null and is_instance_valid(_player) and spider.global_position.distance_to(_player.global_position) < 2.5:
			speed = 0.62
			_spider_direction[index] = (
				1.0
				if _player.global_position.distance_squared_to(path_end)
					> _player.global_position.distance_squared_to(path_start)
				else -1.0
			)
		_spider_progress[index] += _spider_direction[index] * speed * delta
		if _spider_progress[index] >= 1.0:
			_spider_progress[index] = 1.0
			_spider_direction[index] = -1.0
		elif _spider_progress[index] <= 0.0:
			_spider_progress[index] = 0.0
			_spider_direction[index] = 1.0
		spider.position = path_start.lerp(path_end, _spider_progress[index])
		spider.position.y += sin(_time * 8.0 + float(index)) * 0.006
		var direction: Vector3 = (path_end - path_start) * _spider_direction[index]
		spider.rotation.y = atan2(direction.x, direction.z)


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
			center, extents, dust_color, DUST_PARTICLE_COUNT,
			9.0 if is_deep_exit else 8.0,
			Vector2(0.035, 0.12) if is_deep_exit else Vector2(0.055, 0.18),
			Vector2(0.009, 0.032) if is_deep_exit else Vector2(0.012, 0.04)
		)
		particles.name = &"Dust"
		add_child(particles)
		_ambient_emitters.append(particles)


func _build_corruption() -> void:
	for entry: Array in CORRUPTION_EMITTERS:
		var center: Vector3 = entry[0]
		var extents: Vector3 = entry[1]
		var particles: GPUParticles3D = _make_particles(
			center, extents, CORRUPTION_COLOR, CORRUPTION_PARTICLE_COUNT,
			5.2, Vector2(0.045, 0.16), Vector2(0.012, 0.038)
		)
		particles.name = &"CorruptionMotes"
		add_child(particles)
		_ambient_emitters.append(particles)


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
	particles.emitting = false
	particles.visibility_aabb = AABB(-extents, extents * 2.0 + Vector3.UP * 2.0)
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
		emissive_material.set_shader_parameter(
			&"emission_energy", TORCH_CORE_EMISSION if emissive_grid else 2.6
		)
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
