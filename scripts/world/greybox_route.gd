class_name GreyboxRoute
extends Node3D

const GROUND_COLOR: Color = Color(0.28, 0.26, 0.22, 1.0)
const BRIDGE_COLOR: Color = Color(0.34, 0.31, 0.25, 1.0)
const WALL_COLOR: Color = Color(0.47, 0.45, 0.39, 1.0)
const CORRUPTION_COLOR: Color = Color(0.19, 0.28, 0.25, 1.0)
const SEAL_COLOR: Color = Color(0.56, 0.45, 0.25, 1.0)
const TOMBSTONE_COLOR: Color = Color(0.82, 0.81, 0.76, 1.0)
const VEIN_COLOR: Color = Color(0.3, 0.55, 0.48, 1.0)
const VEIN_GLOW: Color = Color(0.18, 0.42, 0.36, 1.0)
const CRACK_COLOR: Color = Color(0.11, 0.11, 0.1, 1.0)
const RUIN_COLOR: Color = Color(0.38, 0.37, 0.33, 1.0)

## Meters of world-space floor covered by one tile of a terrain texture.
const TERRAIN_TILE_METERS: float = 2.5

const GROUND_SOIL_TEXTURE: Texture2D = preload("res://assets/textures/terrain/ground_soil.png")
const GRAVE_STONE_TEXTURE: Texture2D = preload("res://assets/textures/terrain/grave_stone.png")
const CORRUPTION_GROUND_TEXTURE: Texture2D = preload("res://assets/textures/terrain/corruption_ground.png")

const GROUND_SOIL_NORMAL_PATH: String = "res://assets/textures/terrain/ground_soil_n.png"
const GRAVE_STONE_NORMAL_PATH: String = "res://assets/textures/terrain/grave_stone_n.png"
const CORRUPTION_GROUND_NORMAL_PATH: String = "res://assets/textures/terrain/corruption_ground_n.png"

const ORGANIC_ROCK_SHADER: Shader = preload("res://assets/shaders/organic_rock.gdshader")

var _terrain_normal_lookup: Dictionary = {
	GROUND_SOIL_TEXTURE: GROUND_SOIL_NORMAL_PATH,
	GRAVE_STONE_TEXTURE: GRAVE_STONE_NORMAL_PATH,
	CORRUPTION_GROUND_TEXTURE: CORRUPTION_GROUND_NORMAL_PATH,
}
var _terrain_normal_cache: Dictionary[String, Texture2D] = {}
var _organic_rock_materials: Dictionary[String, ShaderMaterial] = {}

var _materials: Dictionary[String, StandardMaterial3D] = {}
var _terrain_materials: Dictionary[String, StandardMaterial3D] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 20260805
	_build_deep_exit()
	_build_bridge()
	_build_xumen_gate()
	_build_burial_road()
	_build_seal_courtyard()
	_build_boss_approach()
	_build_boss_arena()
	_build_backdrop_walls()


func has_section(section_name: StringName) -> bool:
	return has_node(NodePath(section_name))


func _build_deep_exit() -> void:
	var section: Node3D = _create_section(&"DeepExit", Vector3(0.0, -0.2, 8.0), Vector3(9.0, 0.4, 8.0), GROUND_COLOR, GROUND_SOIL_TEXTURE)
	_add_side_rails(section, Vector3(0.0, 0.0, 8.0), Vector2(9.0, 8.0))
	_add_block(section, &"BrokenRearWall", Vector3(0.0, 0.75, 12.0), Vector3(9.0, 1.5, 0.5), WALL_COLOR)
	_add_block(section, &"InvertedSteleLeft", Vector3(-2.4, 1.35, 8.2), Vector3(0.8, 2.7, 0.8), WALL_COLOR)
	_add_block(section, &"InvertedSteleRight", Vector3(2.1, 1.8, 6.6), Vector3(0.9, 3.6, 0.9), WALL_COLOR)
	_add_crack(section, &"ExitCrack", Vector3(1.2, 0.01, 9.8), Vector3(0.18, 0.06, 2.6))
	_add_tombstone(section, &"ExitTomb", Vector3(-3.0, 0.0, 10.2), 0.9, 1.7)
	_add_tombstone(section, &"ExitTombBroken", Vector3(3.4, 0.0, 9.2), 0.7, 1.1)
	_add_rock_pile(section, &"ExitRocks", Vector3(-3.9, 0.0, 6.4), 0.45, 4)
	_add_rock_pile(section, &"ExitRocks2", Vector3(3.9, 0.0, 10.0), 0.4, 3)
	_add_dead_tree(section, &"ExitTree", Vector3(-3.7, 0.0, 11.0), 2.6)
	_add_label(section, "归墟出口", Vector3(0.0, 3.2, 9.5))


func _build_bridge() -> void:
	var section: Node3D = _create_section(&"OuterBridge", Vector3(0.0, -0.2, 0.0), Vector3(3.2, 0.4, 8.0), BRIDGE_COLOR)
	_add_side_rails(section, Vector3(0.0, 0.0, 0.0), Vector2(3.2, 8.0))
	_add_block(section, &"FractureMarker", Vector3(0.75, 0.08, 0.4), Vector3(1.3, 0.16, 1.8), CORRUPTION_COLOR)
	_add_crack(section, &"BridgeCrack", Vector3(-0.4, 0.01, -2.2), Vector3(2.2, 0.06, 0.16))
	_add_ruin_pillar(section, &"BridgePillarLeft", Vector3(-2.4, 0.0, -1.5), 0.5, 2.4)
	_add_ruin_pillar(section, &"BridgePillarRight", Vector3(2.4, 0.0, -3.5), 0.45, 1.9)
	_add_rock_pile(section, &"BridgeRocks", Vector3(1.2, 0.0, 2.6), 0.35, 3)


func _build_xumen_gate() -> void:
	var section: Node3D = _create_section(&"XumenGate", Vector3(0.0, -0.2, -7.0), Vector3(10.0, 0.4, 6.0), GROUND_COLOR, GROUND_SOIL_TEXTURE)
	_add_side_rails(section, Vector3(0.0, 0.0, -7.0), Vector2(10.0, 6.0))
	_add_block(section, &"GatePillarLeft", Vector3(-3.1, 2.2, -8.0), Vector3(1.2, 4.4, 1.2), WALL_COLOR)
	_add_block(section, &"GatePillarRight", Vector3(3.1, 2.2, -8.0), Vector3(1.2, 4.4, 1.2), WALL_COLOR)
	_add_block(section, &"GateLintel", Vector3(0.0, 4.0, -8.0), Vector3(7.4, 0.7, 1.0), WALL_COLOR)
	_add_corruption_patch(section, &"GateCorruption", Vector3(-1.6, 0.01, -6.4), Vector3(2.4, 0.05, 2.0))
	_add_tombstone(section, &"GateTombLeft", Vector3(-4.6, 0.0, -6.2), 0.8, 1.5)
	_add_tombstone(section, &"GateTombRight", Vector3(4.4, 0.0, -7.6), 0.9, 1.9)
	_add_rock_pile(section, &"GateRocks", Vector3(-4.6, 0.0, -9.0), 0.4, 4)
	_add_dead_tree(section, &"GateTree", Vector3(4.6, 0.0, -5.2), 2.2)
	_add_label(section, "墟门", Vector3(0.0, 5.1, -8.0))


func _build_burial_road() -> void:
	var section: Node3D = _create_section(&"BurialRoad", Vector3(0.0, -0.2, -17.0), Vector3(5.0, 0.4, 14.0), BRIDGE_COLOR, GRAVE_STONE_TEXTURE)
	_add_side_rails(section, Vector3(0.0, 0.0, -17.0), Vector2(5.0, 14.0))
	_add_block(section, &"OverturnedCart", Vector3(-1.25, 0.45, -15.5), Vector3(1.8, 0.9, 1.0), CORRUPTION_COLOR)
	_add_block(section, &"BurialStele", Vector3(1.5, 1.25, -20.0), Vector3(0.7, 2.5, 0.7), WALL_COLOR)
	_add_vein_patch(section, &"VeinRoad1", Vector3(0.0, 0.02, -13.5), Vector3(0.7, 0.08, 1.6))
	_add_vein_patch(section, &"VeinRoad2", Vector3(-1.1, 0.02, -18.5), Vector3(1.9, 0.08, 0.5))
	_add_crack(section, &"RoadCrack1", Vector3(0.6, 0.01, -21.2), Vector3(0.16, 0.06, 3.0))
	_add_tombstone(section, &"RoadTomb1", Vector3(-1.7, 0.0, -16.4), 0.8, 1.4)
	_add_tombstone(section, &"RoadTomb2", Vector3(1.8, 0.0, -18.2), 0.7, 1.2)
	_add_tombstone(section, &"RoadTomb3", Vector3(-1.5, 0.0, -21.0), 0.85, 1.6)
	_add_tombstone(section, &"RoadTomb4", Vector3(1.7, 0.0, -23.4), 0.6, 1.0)
	_add_corruption_patch(section, &"RoadCorruption1", Vector3(-0.8, 0.01, -19.6), Vector3(1.6, 0.05, 1.4))
	_add_corruption_patch(section, &"RoadCorruption2", Vector3(1.0, 0.01, -22.8), Vector3(1.3, 0.05, 1.1))
	_add_rock_pile(section, &"RoadRocks1", Vector3(-2.2, 0.0, -15.0), 0.4, 4)
	_add_rock_pile(section, &"RoadRocks2", Vector3(2.2, 0.0, -22.0), 0.35, 3)
	_add_dead_tree(section, &"RoadTree1", Vector3(-2.1, 0.0, -19.0), 2.8)
	_add_dead_tree(section, &"RoadTree2", Vector3(2.2, 0.0, -24.5), 2.0)
	_add_label(section, "送葬道", Vector3(0.0, 3.0, -18.0))


func _build_seal_courtyard() -> void:
	var section: Node3D = _create_section(&"SealCourtyard", Vector3(0.0, -0.2, -29.0), Vector3(12.0, 0.4, 10.0), GROUND_COLOR, GRAVE_STONE_TEXTURE)
	_add_side_rails(section, Vector3(0.0, 0.0, -29.0), Vector2(12.0, 10.0))
	for index: int in range(3):
		var x_position: float = -3.0 + index * 3.0
		_add_block(section, StringName("SealPost%d" % (index + 1)), Vector3(x_position, 1.15, -29.5), Vector3(0.8, 2.3, 0.8), SEAL_COLOR)
	_add_block(section, &"GraveGateLeft", Vector3(-2.3, 1.8, -33.1), Vector3(1.2, 3.6, 1.1), WALL_COLOR)
	_add_block(section, &"GraveGateRight", Vector3(2.3, 1.8, -33.1), Vector3(1.2, 3.6, 1.1), WALL_COLOR)
	_add_crack(section, &"CourtyardCrack", Vector3(0.0, 0.01, -27.5), Vector3(3.2, 0.06, 0.18))
	_add_vein_patch(section, &"VeinCourtyard1", Vector3(-4.2, 0.02, -28.0), Vector3(0.5, 0.08, 2.2))
	_add_vein_patch(section, &"VeinCourtyard2", Vector3(4.0, 0.02, -30.5), Vector3(2.4, 0.08, 0.5))
	_add_tombstone(section, &"CourtyardTomb1", Vector3(-4.8, 0.0, -31.2), 0.9, 1.8)
	_add_tombstone(section, &"CourtyardTomb2", Vector3(4.7, 0.0, -27.6), 0.8, 1.3)
	_add_tombstone(section, &"CourtyardTomb3", Vector3(5.0, 0.0, -32.0), 0.7, 1.5)
	_add_corruption_patch(section, &"CourtyardCorruption", Vector3(-2.6, 0.01, -31.0), Vector3(2.2, 0.05, 1.8))
	_add_rock_pile(section, &"CourtyardRocks1", Vector3(-5.4, 0.0, -26.8), 0.45, 5)
	_add_rock_pile(section, &"CourtyardRocks2", Vector3(5.4, 0.0, -33.0), 0.4, 4)
	_add_dead_tree(section, &"CourtyardTree", Vector3(-5.6, 0.0, -31.0), 3.0)
	_add_label(section, "封印庭院", Vector3(0.0, 3.8, -29.0))


func _build_boss_approach() -> void:
	var section: Node3D = _create_section(&"GravePassage", Vector3(0.0, -0.2, -37.0), Vector3(3.5, 0.4, 6.0), BRIDGE_COLOR, GRAVE_STONE_TEXTURE)
	_add_side_rails(section, Vector3(0.0, 0.0, -37.0), Vector2(3.5, 6.0))
	_add_vein_patch(section, &"VeinPassage", Vector3(0.2, 0.02, -38.4), Vector3(0.6, 0.08, 2.6))
	_add_tombstone(section, &"PassageTomb", Vector3(1.2, 0.0, -36.2), 0.7, 1.3)
	_add_ruin_pillar(section, &"PassagePillar", Vector3(-1.8, 0.0, -39.6), 0.5, 2.8)
	_add_rock_pile(section, &"PassageRocks", Vector3(-1.6, 0.0, -36.8), 0.35, 3)


func _build_boss_arena() -> void:
	var section: Node3D = _create_section(&"BossArena", Vector3(0.0, -0.2, -47.0), Vector3(16.0, 0.4, 14.0), CORRUPTION_COLOR, CORRUPTION_GROUND_TEXTURE)
	_add_side_rails(section, Vector3(0.0, 0.0, -47.0), Vector2(16.0, 14.0))
	_add_block(section, &"BurdenStoneLeft", Vector3(-5.2, 1.8, -47.5), Vector3(1.2, 3.6, 1.2), WALL_COLOR)
	_add_block(section, &"BurdenStoneRight", Vector3(5.0, 2.4, -45.5), Vector3(1.4, 4.8, 1.4), WALL_COLOR)
	_add_block(section, &"BurdenStoneRear", Vector3(0.0, 2.8, -52.0), Vector3(1.8, 5.6, 1.8), WALL_COLOR)
	_add_crack(section, &"ArenaCrack1", Vector3(-2.8, 0.01, -48.6), Vector3(3.4, 0.06, 0.18))
	_add_crack(section, &"ArenaCrack2", Vector3(2.2, 0.01, -50.2), Vector3(0.2, 0.06, 3.6))
	_add_vein_patch(section, &"VeinArena", Vector3(-1.0, 0.02, -46.2), Vector3(0.9, 0.08, 1.8))
	_add_tombstone(section, &"ArenaTomb", Vector3(3.6, 0.0, -48.8), 1.0, 2.0)
	_add_ruin_pillar(section, &"ArenaPillarLeft", Vector3(-6.4, 0.0, -45.6), 0.6, 3.4)
	_add_ruin_pillar(section, &"ArenaPillarRight", Vector3(6.2, 0.0, -50.4), 0.55, 2.9)
	_add_rock_pile(section, &"ArenaRocks1", Vector3(-6.8, 0.0, -50.0), 0.5, 5)
	_add_rock_pile(section, &"ArenaRocks2", Vector3(6.8, 0.0, -48.0), 0.45, 4)
	_add_dead_tree(section, &"ArenaTree", Vector3(-5.0, 0.0, -53.0), 2.6)
	_add_label(section, "负碑兽场地", Vector3(0.0, 5.0, -48.0))


## Rings the playable route with tall irregular rock walls that block the
## view of the empty void beyond the level. Walls are pure visuals with no
## collision; they sit well outside the rail bounds the player can reach.
func _build_backdrop_walls() -> void:
	var backdrop: Node3D = Node3D.new()
	backdrop.name = &"BackdropWalls"
	add_child(backdrop)
	## Right side (positive X): from the deep exit to past the boss arena.
	for index: int in range(10):
		var z: float = 15.0 - index * 7.0
		_add_organic_cliff(
			backdrop, StringName("RightWall%d" % index),
			Vector3(11.5, 0.0, z), Vector3(2.4, 7.0 + _rng.randf_range(-1.5, 1.5), 6.8),
			_rng.randf_range(-4.0, 4.0)
		)
	## Left side (negative X).
	for index: int in range(10):
		var z: float = 15.0 - index * 7.0
		_add_organic_cliff(
			backdrop, StringName("LeftWall%d" % index),
			Vector3(-11.5, 0.0, z), Vector3(2.4, 7.0 + _rng.randf_range(-1.5, 1.5), 6.8),
			_rng.randf_range(-4.0, 4.0)
		)
	## Rear cap behind the boss arena.
	for index: int in range(5):
		var x: float = -8.0 + index * 4.0
		_add_organic_cliff(
			backdrop, StringName("RearWall%d" % index),
			Vector3(x, 0.0, -57.0), Vector3(3.6, 8.0 + _rng.randf_range(-1.5, 1.5), 2.2),
			_rng.randf_range(-3.0, 3.0)
		)
	## Front cap behind the deep exit (player starts facing away from it).
	for index: int in range(5):
		var x: float = -8.0 + index * 4.0
		_add_organic_cliff(
			backdrop, StringName("FrontWall%d" % index),
			Vector3(x, 0.0, 17.5), Vector3(3.6, 8.0 + _rng.randf_range(-1.5, 1.5), 2.2),
			_rng.randf_range(-3.0, 3.0)
		)


func _add_organic_cliff(parent: Node3D, block_name: StringName, center: Vector3, size: Vector3, yaw: float) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = block_name
	mesh_instance.position = center
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = _get_organic_rock_material(size)
	mesh_instance.rotation_degrees = Vector3(0.0, yaw, 0.0)
	parent.add_child(mesh_instance)


func _create_section(
	section_name: StringName,
	floor_position: Vector3,
	floor_size: Vector3,
	color: Color = GROUND_COLOR,
	floor_texture: Texture2D = null
) -> Node3D:
	var section: Node3D = Node3D.new()
	section.name = section_name
	add_child(section)
	_add_block(section, &"Floor", floor_position, floor_size, color, floor_texture)
	return section


func _add_side_rails(parent: Node3D, center: Vector3, floor_size: Vector2) -> void:
	var rail_size: Vector3 = Vector3(0.35, 0.85, floor_size.y)
	var edge_x: float = floor_size.x * 0.5 - rail_size.x * 0.5
	_add_block(parent, &"RailLeft", center + Vector3(-edge_x, 0.425, 0.0), rail_size, WALL_COLOR)
	_add_block(parent, &"RailRight", center + Vector3(edge_x, 0.425, 0.0), rail_size, WALL_COLOR)


## A white tombstone slab: base + upright stele. The stele is randomly
## tilted and rotated so the row of graves feels irregular, not factory-cut.
func _add_tombstone(parent: Node3D, block_name: StringName, center: Vector3, width: float, height: float) -> void:
	var base_size: Vector3 = Vector3(width * 0.9, 0.22, 0.5)
	var slab_size: Vector3 = Vector3(width * 0.55, height, 0.22)
	_add_block(parent, StringName("%sBase" % block_name), center + Vector3(0.0, 0.11, 0.0), base_size, TOMBSTONE_COLOR)
	var slab_yaw: float = _rng.randf_range(-10.0, 10.0)
	var slab_lean: float = _rng.randf_range(2.0, 9.0) * (_rng.randf() < 0.5 as int * 2 - 1)
	var slab_body: StaticBody3D = _make_decor_body(
		parent, StringName("%sSlab" % block_name), center + Vector3(0.0, 0.22 + height * 0.5, 0.0), slab_size, TOMBSTONE_COLOR
	)
	slab_body.rotation_degrees = Vector3(0.0, slab_yaw, slab_lean)


## A pile of rounded boulders used to break up boxy silhouettes; sits on
## the floor with a static body so it reads as solid ground clutter.
func _add_rock_pile(parent: Node3D, block_name: StringName, center: Vector3, radius: float = 0.5, count: int = 4) -> void:
	var pile: StaticBody3D = StaticBody3D.new()
	pile.name = block_name
	pile.position = center
	parent.add_child(pile)
	for i: int in range(count):
		var rock: MeshInstance3D = MeshInstance3D.new()
		rock.name = &"Visual%d" % i
		var sphere: SphereMesh = SphereMesh.new()
		var rock_radius: float = _rng.randf_range(radius * 0.35, radius * 0.8)
		sphere.radius = rock_radius
		sphere.height = rock_radius * _rng.randf_range(1.1, 1.6)
		rock.mesh = sphere
		var rock_material := ShaderMaterial.new()
		rock_material.shader = ORGANIC_ROCK_SHADER
		var rock_color: Color = RUIN_COLOR if i % 2 == 0 else WALL_COLOR
		rock_material.set_shader_parameter(&"albedo_color", rock_color.darkened(_rng.randf_range(0.1, 0.25)))
		rock_material.set_shader_parameter(&"roughness", 0.97)
		rock_material.set_shader_parameter(&"strength", 0.5)
		rock_material.set_shader_parameter(&"horizontal_strength", 0.25)
		rock_material.set_shader_parameter(&"frequency", 2.8)
		rock.material_override = rock_material
		rock.position = Vector3(_rng.randf_range(-radius, radius), rock_radius * 0.6, _rng.randf_range(-radius * 0.6, radius * 0.6))
		rock.rotation_degrees = Vector3(_rng.randf_range(-15.0, 15.0), _rng.randf_range(0.0, 360.0), _rng.randf_range(-15.0, 15.0))
		pile.add_child(rock)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(radius * 2.0, radius * 1.2, radius * 1.2)
	shape.shape = box
	shape.position = Vector3(0.0, radius * 0.55, 0.0)
	pile.add_child(shape)


## A dead twisted tree stump/trunk to break up the rectangular skyline.
func _add_dead_tree(parent: Node3D, block_name: StringName, center: Vector3, height: float = 2.4) -> void:
	var tree: StaticBody3D = StaticBody3D.new()
	tree.name = block_name
	tree.position = center
	parent.add_child(tree)
	var trunk: MeshInstance3D = MeshInstance3D.new()
	trunk.name = &"Trunk"
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = 0.12
	cylinder.bottom_radius = 0.22
	cylinder.height = height
	trunk.mesh = cylinder
	trunk.material_override = _get_material(RUIN_COLOR)
	trunk.position = Vector3(0.0, height * 0.5, 0.0)
	trunk.rotation_degrees = Vector3(_rng.randf_range(-12.0, 12.0), 0.0, _rng.randf_range(-10.0, 10.0))
	tree.add_child(trunk)
	for i: int in range(2):
		var branch: MeshInstance3D = MeshInstance3D.new()
		branch.name = &"Branch%d" % i
		var branch_mesh: CylinderMesh = CylinderMesh.new()
		branch_mesh.top_radius = 0.05
		branch_mesh.bottom_radius = 0.08
		branch_mesh.height = _rng.randf_range(0.7, 1.2)
		branch.mesh = branch_mesh
		branch.material_override = _get_material(RUIN_COLOR)
		branch.position = Vector3(_rng.randf_range(-0.3, 0.3), height * _rng.randf_range(0.5, 0.75), 0.0)
		var branch_dir: float = 1.0 if i == 0 else -1.0
		branch.rotation_degrees = Vector3(0.0, 0.0, _rng.randf_range(35.0, 75.0) * branch_dir)
		tree.add_child(branch)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.5, height * 0.8, 0.5)
	shape.shape = box
	shape.position = Vector3(0.0, height * 0.4, 0.0)
	tree.add_child(shape)


## A low emissive vein streak on the floor (green earth veins).
func _add_vein_patch(parent: Node3D, block_name: StringName, center: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = _make_decor_body(parent, block_name, center, size, VEIN_COLOR)
	var glow: MeshInstance3D = body.get_node("Visual") as MeshInstance3D
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = VEIN_COLOR
	material.roughness = 0.8
	material.emission_enabled = true
	material.emission = VEIN_GLOW
	material.emission_energy_multiplier = 1.4
	glow.material_override = material


## A dark corruption stain on the floor.
func _add_corruption_patch(parent: Node3D, block_name: StringName, center: Vector3, size: Vector3) -> void:
	_make_decor_body(parent, block_name, center, size, CORRUPTION_COLOR, CORRUPTION_GROUND_TEXTURE)


## A thin dark crack line across the floor.
func _add_crack(parent: Node3D, block_name: StringName, center: Vector3, size: Vector3) -> void:
	_make_decor_body(parent, block_name, center, size, CRACK_COLOR)


## A broken ruined pillar used for foreground framing; no collision (placed off path).
func _add_ruin_pillar(parent: Node3D, block_name: StringName, center: Vector3, width: float, height: float) -> void:
	var section: Node3D = Node3D.new()
	section.name = block_name
	section.position = center
	parent.add_child(section)
	var shaft: MeshInstance3D = MeshInstance3D.new()
	shaft.name = &"Visual"
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3(width, height, width)
	shaft.mesh = box_mesh
	shaft.material_override = _get_material(RUIN_COLOR)
	shaft.position = Vector3(0.0, height * 0.5, 0.0)
	section.add_child(shaft)
	var cap: MeshInstance3D = MeshInstance3D.new()
	cap.name = &"Cap"
	var cap_mesh: BoxMesh = BoxMesh.new()
	cap_mesh.size = Vector3(width * 1.7, height * 0.14, width * 1.7)
	cap.mesh = cap_mesh
	cap.material_override = _get_material(WALL_COLOR)
	cap.position = Vector3(0.0, height, 0.0)
	cap.rotation_degrees = Vector3(0.0, 0.0, 6.0)
	section.add_child(cap)


func _make_decor_body(
	parent: Node3D,
	block_name: StringName,
	center: Vector3,
	size: Vector3,
	color: Color,
	texture: Texture2D = null
) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = block_name
	body.position = center
	parent.add_child(body)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = &"Visual"
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	if texture != null:
		mesh_instance.material_override = _get_terrain_material(texture, size)
	else:
		mesh_instance.material_override = _get_material(color)
	body.add_child(mesh_instance)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = &"CollisionShape3D"
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	body.add_child(collision)
	return body


func _add_block(
	parent: Node3D,
	block_name: StringName,
	center: Vector3,
	size: Vector3,
	color: Color,
	texture: Texture2D = null
) -> void:
	_make_decor_body(parent, block_name, center, size, color, texture)


func _add_label(parent: Node3D, label_text: String, label_position: Vector3) -> void:
	pass


func _get_material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if _materials.has(key):
		return _materials[key]
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	_materials[key] = material
	return material


## Returns a cached ShaderMaterial that displaces box geometry into rough
## rock via per-vertex value noise (see organic_rock.gdshader). Used by the
## backdrop walls and rock piles so nothing reads as a clean box.
func _get_organic_rock_material(size: Vector3) -> ShaderMaterial:
	var key: String = "organic_%s" % size
	if _organic_rock_materials.has(key):
		return _organic_rock_materials[key]
	var material := ShaderMaterial.new()
	material.shader = ORGANIC_ROCK_SHADER
	var base_color: Color = RUIN_COLOR.darkened(_rng.randf_range(0.1, 0.3))
	material.set_shader_parameter(&"albedo_color", base_color)
	material.set_shader_parameter(&"roughness", 0.97)
	material.set_shader_parameter(&"strength", 1.1)
	material.set_shader_parameter(&"horizontal_strength", 0.45)
	material.set_shader_parameter(&"frequency", 1.0)
	_organic_rock_materials[key] = material
	return material


## Loads the matching normal map PNG and converts it to an ImageTexture so
## we don't need an editor-generated .import file. Result is cached per path.
func _load_normal_for(albedo: Texture2D) -> Texture2D:
	if not _terrain_normal_lookup.has(albedo):
		return null
	var path: String = _terrain_normal_lookup[albedo]
	if _terrain_normal_cache.has(path):
		return _terrain_normal_cache[path]
	if not FileAccess.file_exists(path):
		return null
	var image: Image = Image.new()
	var err: int = image.load(path)
	if err != OK:
		return null
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_terrain_normal_cache[path] = texture
	return texture


## Returns a cached tiling material for a terrain texture. The UV scale is
## derived from the block's world-space footprint so the pattern repeats at
## a consistent real-world tile size instead of stretching per block.
## NOTE: cache key includes the block size, because different footprint
## blocks must get different UV scales (texture repeats per world meter).
func _get_terrain_material(texture: Texture2D, size: Vector3) -> StandardMaterial3D:
	var key: String = "%s|%s" % [texture.resource_path, size]
	if _terrain_materials.has(key):
		return _terrain_materials[key]
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.95
	material.uv1_scale = Vector3(
		maxf(1.0, size.x / TERRAIN_TILE_METERS),
		maxf(1.0, size.z / TERRAIN_TILE_METERS),
		1.0
	)
	var normal_tex: Texture2D = _load_normal_for(texture)
	if normal_tex != null:
		material.normal_enabled = true
		material.normal_texture = normal_tex
		material.normal_scale = 0.7
	_terrain_materials[key] = material
	return material
