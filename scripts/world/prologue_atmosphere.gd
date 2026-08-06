class_name PrologueAtmosphere
extends Node3D

## Runtime atmosphere for the Xumen prologue greybox:
## warm stone lanterns with breathing light, drifting dust along the
## burial road, and rising corruption motes in the boss arena.

const LANTERN_COLOR: Color = Color(1.0, 0.62, 0.32, 1.0)
const DUST_COLOR: Color = Color(0.78, 0.72, 0.58, 0.35)
const CORRUPTION_COLOR: Color = Color(0.36, 0.68, 0.56, 0.5)
const STONE_COLOR: Color = Color(0.42, 0.4, 0.35, 1.0)

## Lantern positions along the route: [position, base_energy, phase].
const LANTERNS: Array = [
	[Vector3(-3.4, 0.0, 8.4), 2.2, 0.0],
	[Vector3(3.4, 0.0, 7.2), 2.2, 1.3],
	[Vector3(-2.6, 0.0, -0.4), 1.8, 2.6],
	[Vector3(2.6, 0.0, 0.6), 1.8, 3.9],
	[Vector3(-4.2, 0.0, -7.4), 2.6, 0.7],
	[Vector3(4.2, 0.0, -8.6), 2.6, 2.0],
	[Vector3(-2.7, 0.0, -13.2), 2.0, 3.3],
	[Vector3(2.7, 0.0, -13.8), 2.0, 4.6],
	[Vector3(-2.7, 0.0, -20.4), 1.8, 1.1],
	[Vector3(2.7, 0.0, -21.0), 1.8, 2.4],
	[Vector3(-5.4, 0.0, -28.2), 2.4, 3.7],
	[Vector3(5.4, 0.0, -29.0), 2.4, 5.0],
	[Vector3(-2.4, 0.0, -36.6), 1.6, 1.9],
	[Vector3(2.4, 0.0, -37.4), 1.6, 3.2],
	[Vector3(-6.2, 0.0, -46.4), 2.8, 4.5],
	[Vector3(6.2, 0.0, -47.6), 2.8, 5.8],
]

const DUST_EMITTERS: Array = [
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


func _ready() -> void:
	_build_lanterns()
	_build_dust()
	_build_corruption()


func _process(delta: float) -> void:
	_time += delta
	for i: int in _lantern_lights.size():
		var light: OmniLight3D = _lantern_lights[i]
		var base: float = _lantern_energy[i]
		var breath: float = 0.82 + 0.18 * sin(_time * 1.9 + _lantern_phases[i])
		light.light_energy = base * breath


func _build_lanterns() -> void:
	for entry: Array in LANTERNS:
		var position: Vector3 = entry[0]
		var energy: float = float(entry[1]) * 0.6
		var phase: float = entry[2]
		var lantern: Node3D = Node3D.new()
		lantern.name = &"Lantern"
		lantern.position = position
		add_child(lantern)

		var base_mesh: MeshInstance3D = _box_mesh(Vector3(0.7, 0.16, 0.7), STONE_COLOR)
		base_mesh.position = Vector3(0.0, 0.08, 0.0)
		lantern.add_child(base_mesh)

		var post_mesh: MeshInstance3D = _cylinder_mesh(0.07, 0.09, 1.3, STONE_COLOR)
		post_mesh.position = Vector3(0.0, 0.8, 0.0)
		lantern.add_child(post_mesh)

		var head_mesh: MeshInstance3D = _box_mesh(Vector3(0.34, 0.24, 0.34), LANTERN_COLOR, true)
		head_mesh.position = Vector3(0.0, 1.55, 0.0)
		lantern.add_child(head_mesh)

		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = LANTERN_COLOR
		light.light_energy = energy
		light.omni_range = 5.8
		light.omni_attenuation = 1.6
		light.position = Vector3(0.0, 1.7, 0.0)
		lantern.add_child(light)
		_lantern_lights.append(light)
		_lantern_energy.append(energy)
		_lantern_phases.append(phase)


func _build_dust() -> void:
	for entry: Array in DUST_EMITTERS:
		var center: Vector3 = entry[0]
		var extents: Vector3 = entry[1]
		var particles: GPUParticles3D = _make_particles(
			center, extents, DUST_COLOR, 42, 6.0, Vector2(0.15, 0.5), Vector2(0.25, 0.7)
		)
		particles.name = &"Dust"
		add_child(particles)


func _build_corruption() -> void:
	for entry: Array in CORRUPTION_EMITTERS:
		var center: Vector3 = entry[0]
		var extents: Vector3 = entry[1]
		var particles: GPUParticles3D = _make_particles(
			center, extents, CORRUPTION_COLOR, 26, 3.2, Vector2(0.1, 0.35), Vector2(0.12, 0.3)
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
	material.albedo_texture = _make_soft_dot_texture()
	material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	particles.material_override = material
	return particles


func _cylinder_mesh(top_radius: float, bottom_radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = top_radius
	cylinder_mesh.bottom_radius = bottom_radius
	cylinder_mesh.height = height
	mesh_instance.mesh = cylinder_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh_instance.material_override = material
	return mesh_instance


func _box_mesh(size: Vector3, color: Color, emissive: bool = false) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	if emissive:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = 1.05
	mesh_instance.material_override = material
	return mesh_instance


## Generates a small soft radial dot texture for particle sprites.
func _make_soft_dot_texture(size: int = 48) -> ImageTexture:
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y: int in range(size):
		for x: int in range(size):
			var dx: float = (float(x) + 0.5) / float(size) * 2.0 - 1.0
			var dy: float = (float(y) + 0.5) / float(size) * 2.0 - 1.0
			var distance: float = sqrt(dx * dx + dy * dy)
			var alpha: float = clampf(1.0 - distance * 1.5, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha * alpha))
	return ImageTexture.create_from_image(image)
