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

## Half-width in meters that the orthographic camera actually shows at
## size 5.0 on a 16:9 viewport. Orthographic projection has no perspective
## spread, so scenery beyond this X never reaches the screen no matter how
## tall it is: canyon walls have to sit inside this bound to frame the shot.
const VIEW_HALF_WIDTH: float = 4.45

## Wet stone reads as damp when it keeps a tight specular highlight, so the
## walking surfaces stay far below the dry-rock roughness used elsewhere.
const WET_GROUND_ROUGHNESS: float = 0.62
const WET_PATH_ROUGHNESS: float = 0.42

## The limestone source texture is a bright quarry grey. Knocking it down keeps
## the walking path from out-brightening the lantern pools, while staying
## lighter than the surrounding gravel so it still reads as a route.
const PATH_TINT: Color = Color(0.66, 0.65, 0.63, 1.0)

## Flagstone reads at a tighter repeat than open ground, otherwise a single
## slab shows one giant stone face and looks untextured.
const PATH_TILE_METERS: float = 1.1

## Number of discrete tone / gloss variants a flagstone slab can pick from.
## Quantising the jitter keeps the terrain material cache small: without it,
## every slab would allocate its own StandardMaterial3D.
const PATH_TONE_STEPS: int = 5
const PATH_GLOSS_STEPS: int = 3

## Canyon segments that ring the route: [z_center, z_length, path_half_width].
## Walls hug the path edge so the corridor sections read as a narrow gorge.
const CANYON_SEGMENTS: Array = [
	[8.0, 9.0, 2.95],
	[-7.0, 7.0, 3.4],
	[-17.0, 15.0, 2.5],
	[-29.0, 11.0, 6.0],
	[-37.0, 7.0, 1.75],
	[-47.0, 15.0, 8.0],
]

const GROUND_SOIL_TEXTURE: Texture2D = preload("res://assets/textures/terrain/ground_soil.png")
const GRAVE_STONE_TEXTURE: Texture2D = preload("res://assets/textures/terrain/grave_stone.png")
const CORRUPTION_GROUND_TEXTURE: Texture2D = preload("res://assets/textures/terrain/corruption_ground.png")
const DEEP_EXIT_SOIL_PATH: String = "res://assets/textures/terrain/deep_exit_soil.png"
const WEATHERED_LIMESTONE_PATH: String = "res://assets/textures/terrain/weathered_limestone.png"

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
var _deep_exit_soil_texture: ImageTexture
var _weathered_limestone_texture: ImageTexture


func _ready() -> void:
	_rng.seed = 20260805
	_deep_exit_soil_texture = _load_source_texture(DEEP_EXIT_SOIL_PATH)
	_weathered_limestone_texture = _load_source_texture(WEATHERED_LIMESTONE_PATH)
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
	var section: Node3D = _create_section(&"DeepExit", Vector3(0.0, -0.2, 8.0), Vector3(9.0, 0.4, 8.0), GROUND_COLOR, _deep_exit_soil_texture)
	_add_deep_exit_rails(section)
	var broken_wall_profile := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 0.72),
		Vector2(0.86, 0.82), Vector2(0.7, 0.66), Vector2(0.54, 0.94),
		Vector2(0.34, 0.77), Vector2(0.17, 1.0), Vector2(0.0, 0.82),
	])
	_add_profile_body(section, &"BrokenRearWallLeft", Vector3(-2.15, 0.55, 12.0), Vector3(1.9, 1.1, 0.5), broken_wall_profile, _weathered_limestone_texture)
	_add_profile_body(section, &"BrokenRearWallRight", Vector3(2.15, 0.42, 12.0), Vector3(1.9, 0.84, 0.5), broken_wall_profile, _weathered_limestone_texture, Vector3(0.0, 180.0, 0.0))
	var stele_profile := PackedVector2Array([
		Vector2(0.12, 0.0), Vector2(0.88, 0.0), Vector2(1.0, 0.72),
		Vector2(0.82, 0.96), Vector2(0.62, 0.9), Vector2(0.42, 1.0),
		Vector2(0.14, 0.86), Vector2(0.0, 0.34),
	])
	_add_profile_body(section, &"InvertedSteleLeft", Vector3(-1.95, 1.25, 8.2), Vector3(0.58, 2.5, 0.42), stele_profile, _weathered_limestone_texture, Vector3(-5.0, -8.0, 7.0))
	_add_profile_body(section, &"InvertedSteleRight", Vector3(1.8, 1.55, 6.6), Vector3(0.66, 3.1, 0.46), stele_profile, _weathered_limestone_texture, Vector3(4.0, 10.0, -6.0))
	var exit_crack_a := _make_decor_body(section, &"ExitCrackA", Vector3(1.15, 0.005, 9.3), Vector3(0.1, 0.025, 0.9), CRACK_COLOR)
	exit_crack_a.rotation_degrees.y = -12.0
	var exit_crack_b := _make_decor_body(section, &"ExitCrackB", Vector3(1.28, 0.005, 10.05), Vector3(0.09, 0.025, 0.7), CRACK_COLOR)
	exit_crack_b.rotation_degrees.y = 11.0
	var exit_crack_c := _make_decor_body(section, &"ExitCrackC", Vector3(1.48, 0.005, 10.58), Vector3(0.07, 0.025, 0.45), CRACK_COLOR)
	exit_crack_c.rotation_degrees.y = 24.0
	_add_deep_exit_tombstone(section, &"ExitTomb", Vector3(-2.3, 0.0, 10.2), 0.9, 1.7, false)
	_add_deep_exit_tombstone(section, &"ExitTombBroken", Vector3(2.35, 0.0, 9.2), 0.7, 1.1, true)
	_add_rock_pile(section, &"ExitRocks", Vector3(-2.5, 0.0, 6.4), 0.45, 4)
	_add_rock_pile(section, &"ExitRocks2", Vector3(2.5, 0.0, 10.0), 0.4, 3)
	_add_dead_tree(section, &"ExitTree", Vector3(-2.55, 0.0, 11.0), 2.6)
	_add_stone_path(section, &"ExitPath", 12.0, 4.5, 2.4)
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
	_add_side_rails(section, Vector3(0.0, 0.0, -7.0), Vector2(6.7, 6.0))
	_add_block(section, &"GatePillarLeft", Vector3(-2.45, 2.2, -8.0), Vector3(1.2, 4.4, 1.2), WALL_COLOR)
	_add_block(section, &"GatePillarRight", Vector3(2.45, 2.2, -8.0), Vector3(1.2, 4.4, 1.2), WALL_COLOR)
	_add_block(section, &"GateLintel", Vector3(0.0, 4.0, -8.0), Vector3(6.1, 0.7, 1.0), WALL_COLOR)
	_add_corruption_patch(section, &"GateCorruption", Vector3(-1.6, 0.01, -6.4), Vector3(2.4, 0.05, 2.0))
	_add_tombstone(section, &"GateTombLeft", Vector3(-2.6, 0.0, -6.2), 0.8, 1.5)
	_add_tombstone(section, &"GateTombRight", Vector3(2.5, 0.0, -7.6), 0.9, 1.9)
	_add_rock_pile(section, &"GateRocks", Vector3(-2.6, 0.0, -9.0), 0.4, 4)
	_add_dead_tree(section, &"GateTree", Vector3(2.6, 0.0, -5.2), 2.2)
	_add_stone_path(section, &"GatePath", -4.0, -10.0, 2.6)
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
	_add_rock_pile(section, &"RoadRocks1", Vector3(-1.95, 0.0, -15.0), 0.4, 4)
	_add_rock_pile(section, &"RoadRocks2", Vector3(1.95, 0.0, -22.0), 0.35, 3)
	_add_dead_tree(section, &"RoadTree1", Vector3(-1.9, 0.0, -19.0), 2.8)
	_add_dead_tree(section, &"RoadTree2", Vector3(1.95, 0.0, -24.5), 2.0)
	_add_stone_path(section, &"RoadPath", -10.5, -24.0, 2.2)
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
	_add_ruin_pillar(section, &"PassagePillar", Vector3(-1.25, 0.0, -39.6), 0.5, 2.8)
	_add_rock_pile(section, &"PassageRocks", Vector3(-1.3, 0.0, -36.8), 0.35, 3)
	_add_stone_path(section, &"PassagePath", -34.0, -40.0, 1.6)


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
## collision; they sit just outside the rail bounds the player can reach so
## they read as a gorge wall instead of a distant backdrop.
func _build_backdrop_walls() -> void:
	var backdrop: Node3D = Node3D.new()
	backdrop.name = &"BackdropWalls"
	add_child(backdrop)
	for index: int in CANYON_SEGMENTS.size():
		var segment: Array = CANYON_SEGMENTS[index]
		_add_canyon_side(backdrop, index, segment[0], segment[1], segment[2], 1.0)
		_add_canyon_side(backdrop, index, segment[0], segment[1], segment[2], -1.0)
	## Rear cap behind the boss arena.
	for index: int in range(5):
		var x: float = -8.0 + index * 4.0
		_add_organic_cliff(
			backdrop, StringName("RearWall%d" % index),
			Vector3(x, 0.0, -57.0), Vector3(3.6, 8.0 + _rng.randf_range(-1.5, 1.5), 2.2),
			_rng.randf_range(-3.0, 3.0)
		)


## Lays one flank of a canyon segment as overlapping cliff blocks. The blocks
## are stepped along Z with jittered height and yaw so the silhouette breaks
## up instead of reading as one long extruded wall.
func _add_canyon_side(
	backdrop: Node3D,
	segment_index: int,
	z_center: float,
	z_length: float,
	path_half_width: float,
	side: float
) -> void:
	const BLOCK_DEPTH: float = 2.8
	const BLOCK_WIDTH: float = 2.4
	var step: float = 2.4
	var count: int = int(ceil(z_length / step)) + 1
	var z_start: float = z_center + z_length * 0.5
	## Offset so the inner face lands flush with the path edge.
	var x: float = side * (path_half_width + BLOCK_WIDTH * 0.5 - 0.05)
	var side_tag: String = "Right" if side > 0.0 else "Left"
	for index: int in range(count):
		var z: float = z_start - index * step
		var height: float = _rng.randf_range(5.0, 8.5)
		_add_organic_cliff(
			backdrop, StringName("Canyon%s%d_%d" % [side_tag, segment_index, index]),
			Vector3(x + side * _rng.randf_range(0.0, 0.5), 0.0, z),
			Vector3(BLOCK_WIDTH, height, BLOCK_DEPTH),
			_rng.randf_range(-6.0, 6.0),
			0.62
		)


func _add_organic_cliff(
	parent: Node3D,
	block_name: StringName,
	center: Vector3,
	size: Vector3,
	yaw: float,
	darken: float = 0.2
) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = block_name
	mesh_instance.position = center
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = _get_organic_rock_material(size, darken)
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


func _add_side_rails(parent: Node3D, center: Vector3, floor_size: Vector2, texture: Texture2D = null, height: float = 0.85) -> void:
	var rail_size: Vector3 = Vector3(0.35, height, floor_size.y)
	var edge_x: float = floor_size.x * 0.5 - rail_size.x * 0.5
	_add_block(parent, &"RailLeft", center + Vector3(-edge_x, height * 0.5, 0.0), rail_size, WALL_COLOR, texture)
	_add_block(parent, &"RailRight", center + Vector3(edge_x, height * 0.5, 0.0), rail_size, WALL_COLOR, texture)


func _add_deep_exit_rails(parent: Node3D) -> void:
	var profile := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 0.62),
		Vector2(0.86, 0.78), Vector2(0.7, 0.58), Vector2(0.5, 0.9),
		Vector2(0.28, 0.7), Vector2(0.12, 1.0), Vector2(0.0, 0.76),
	])
	_add_profile_body(parent, &"RailLeft", Vector3(-2.75, 0.225, 8.0), Vector3(8.0, 0.45, 0.35), profile, _weathered_limestone_texture, Vector3(0.0, 90.0, 0.0))
	_add_profile_body(parent, &"RailRight", Vector3(2.75, 0.225, 8.0), Vector3(8.0, 0.45, 0.35), profile, _weathered_limestone_texture, Vector3(0.0, 90.0, 0.0))


func _add_deep_exit_tombstone(parent: Node3D, block_name: StringName, center: Vector3, width: float, height: float, broken: bool) -> void:
	var base_profile := PackedVector2Array([
		Vector2(0.08, 0.0), Vector2(0.92, 0.0), Vector2(1.0, 0.55),
		Vector2(0.85, 1.0), Vector2(0.15, 0.9), Vector2(0.0, 0.45),
	])
	_add_profile_body(parent, StringName("%sBase" % block_name), center + Vector3(0.0, 0.11, 0.0), Vector3(width, 0.22, 0.55), base_profile, _weathered_limestone_texture)
	var slab_profile := PackedVector2Array([
		Vector2(0.08, 0.0), Vector2(0.92, 0.0), Vector2(1.0, 0.72),
		Vector2(0.78, 0.95 if broken else 1.0), Vector2(0.58, 0.84 if broken else 0.96),
		Vector2(0.35, 1.0), Vector2(0.08, 0.84), Vector2(0.0, 0.38),
	])
	var rotation := Vector3(0.0, -7.0 if broken else 5.0, 9.0 if broken else -4.0)
	_add_profile_body(parent, StringName("%sSlab" % block_name), center + Vector3(0.0, 0.22 + height * 0.5, 0.0), Vector3(width * 0.58, height, 0.24), slab_profile, _weathered_limestone_texture, rotation)


func _add_profile_body(
	parent: Node3D,
	block_name: StringName,
	center: Vector3,
	size: Vector3,
	profile: PackedVector2Array,
	texture: Texture2D,
	rotation: Vector3 = Vector3.ZERO
) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = block_name
	body.position = center
	body.rotation_degrees = rotation
	parent.add_child(body)
	var visual := MeshInstance3D.new()
	visual.name = &"Visual"
	visual.mesh = _make_extruded_profile(profile, size)
	var material := _get_terrain_material(texture, size).duplicate() as StandardMaterial3D
	material.albedo_color = Color(0.62, 0.64, 0.61, 1.0)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = material
	body.add_child(visual)
	var collision := CollisionShape3D.new()
	collision.name = &"CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)
	return body


func _make_extruded_profile(profile: PackedVector2Array, size: Vector3) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var triangles := Geometry2D.triangulate_polygon(profile)
	for offset: int in range(0, triangles.size(), 3):
		for vertex_index: int in [triangles[offset], triangles[offset + 1], triangles[offset + 2]]:
			_add_profile_vertex(surface, profile[vertex_index], size.z * 0.5, size)
		for vertex_index: int in [triangles[offset + 2], triangles[offset + 1], triangles[offset]]:
			_add_profile_vertex(surface, profile[vertex_index], size.z * -0.5, size)
	for index: int in profile.size():
		var next: int = (index + 1) % profile.size()
		var a := profile[index]
		var b := profile[next]
		_add_profile_vertex(surface, a, size.z * -0.5, size, Vector2(0.0, 0.0))
		_add_profile_vertex(surface, b, size.z * -0.5, size, Vector2(1.0, 0.0))
		_add_profile_vertex(surface, b, size.z * 0.5, size, Vector2(1.0, 1.0))
		_add_profile_vertex(surface, a, size.z * -0.5, size, Vector2(0.0, 0.0))
		_add_profile_vertex(surface, b, size.z * 0.5, size, Vector2(1.0, 1.0))
		_add_profile_vertex(surface, a, size.z * 0.5, size, Vector2(0.0, 1.0))
	surface.generate_normals()
	return surface.commit()


func _add_profile_vertex(surface: SurfaceTool, point: Vector2, z: float, size: Vector3, uv: Vector2 = Vector2(-1.0, -1.0)) -> void:
	surface.set_uv(point if uv.x < 0.0 else uv)
	surface.add_vertex(Vector3((point.x - 0.5) * size.x, (point.y - 0.5) * size.y, z))


## A white tombstone slab: base + upright stele. The stele is randomly
## tilted and rotated so the row of graves feels irregular, not factory-cut.
func _add_tombstone(parent: Node3D, block_name: StringName, center: Vector3, width: float, height: float, texture: Texture2D = null) -> void:
	var base_size: Vector3 = Vector3(width * 0.9, 0.22, 0.5)
	var slab_size: Vector3 = Vector3(width * 0.55, height, 0.22)
	_add_block(parent, StringName("%sBase" % block_name), center + Vector3(0.0, 0.11, 0.0), base_size, TOMBSTONE_COLOR, texture)
	var slab_yaw: float = _rng.randf_range(-10.0, 10.0)
	var slab_lean: float = _rng.randf_range(2.0, 9.0) * (_rng.randf() < 0.5 as int * 2 - 1)
	var slab_body: StaticBody3D = _make_decor_body(
		parent, StringName("%sSlab" % block_name), center + Vector3(0.0, 0.22 + height * 0.5, 0.0), slab_size, TOMBSTONE_COLOR, texture
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


## Lays a brighter wet flagstone path down the middle of a corridor so the eye
## has something to follow. Slabs are laid as a running-bond grid with dark
## grout gaps between them, and each slab gets its own tone and yaw jitter so
## the run reads as worn paving rather than a painted lane. Visual only: the
## slabs sit a few millimetres above the floor and carry no collision.
func _add_stone_path(parent: Node3D, block_name: StringName, z_from: float, z_to: float, width: float) -> void:
	## Grout gap between neighbouring slabs; the dark floor shows through it.
	const SLAB_GAP: float = 0.07
	## Target slab footprint before jitter, in metres.
	const SLAB_LENGTH: float = 0.95
	const SLAB_WIDTH: float = 0.85
	var path_root: Node3D = Node3D.new()
	path_root.name = block_name
	parent.add_child(path_root)
	var span: float = absf(z_to - z_from)
	var direction: float = signf(z_to - z_from)
	var rows: int = maxi(1, int(round(span / SLAB_LENGTH)))
	var row_length: float = span / float(rows)
	var columns: int = maxi(1, int(round(width / SLAB_WIDTH)))
	var column_width: float = width / float(columns)
	for row: int in range(rows):
		var z: float = z_from + direction * (row + 0.5) * row_length
		## Running bond: every other row is nudged half a slab sideways so the
		## grout lines never form one continuous seam down the corridor.
		var bond_offset: float = 0.0 if row % 2 == 0 else column_width * 0.5
		for column: int in range(columns):
			var x: float = (column + 0.5) * column_width - width * 0.5 + bond_offset
			if absf(x) > width * 0.5:
				continue
			var mesh_instance := MeshInstance3D.new()
			mesh_instance.name = StringName("Slab%d_%d" % [row, column])
			var box_mesh := BoxMesh.new()
			box_mesh.size = Vector3(
				maxf(0.2, column_width - SLAB_GAP),
				0.03,
				maxf(0.2, row_length - SLAB_GAP)
			)
			mesh_instance.mesh = box_mesh
			mesh_instance.position = Vector3(
				x + _rng.randf_range(-0.03, 0.03),
				_rng.randf_range(0.012, 0.022),
				z + _rng.randf_range(-0.03, 0.03)
			)
			mesh_instance.rotation_degrees = Vector3(0.0, _rng.randf_range(-2.5, 2.5), 0.0)
			## Per-slab tone and gloss drift keeps the paving from reading as one
			## flat plate. Both are quantised into a handful of steps so the slabs
			## keep sharing cached materials instead of allocating one each.
			var tone: float = (_rng.randi_range(0, PATH_TONE_STEPS - 1) / float(PATH_TONE_STEPS - 1) - 0.5) * 0.18
			var slab_tint := Color(
				clampf(PATH_TINT.r + tone, 0.0, 1.0),
				clampf(PATH_TINT.g + tone, 0.0, 1.0),
				clampf(PATH_TINT.b + tone, 0.0, 1.0)
			)
			var gloss: float = (_rng.randi_range(0, PATH_GLOSS_STEPS - 1) / float(PATH_GLOSS_STEPS - 1) - 0.5) * 0.12
			mesh_instance.material_override = _get_terrain_material(
				_weathered_limestone_texture,
				box_mesh.size,
				WET_PATH_ROUGHNESS + gloss,
				slab_tint,
				PATH_TILE_METERS
			)
			path_root.add_child(mesh_instance)


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
func _get_organic_rock_material(size: Vector3, darken: float = 0.2) -> ShaderMaterial:
	var key: String = "organic_%s_%s" % [size, darken]
	if _organic_rock_materials.has(key):
		return _organic_rock_materials[key]
	var material := ShaderMaterial.new()
	material.shader = ORGANIC_ROCK_SHADER
	var base_color: Color = RUIN_COLOR.darkened(darken + _rng.randf_range(0.0, 0.12))
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


func _load_source_texture(path: String) -> ImageTexture:
	var image := Image.new()
	if image.load(path) != OK:
		push_error("Failed to load terrain texture: %s" % path)
		return null
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	texture.resource_name = path.get_file()
	return texture


## Returns a cached tiling material for a terrain texture. The UV scale is
## derived from the block's world-space footprint so the pattern repeats at
## a consistent real-world tile size instead of stretching per block.
## NOTE: cache key includes the block size, because different footprint
## blocks must get different UV scales (texture repeats per world meter).
func _get_terrain_material(
	texture: Texture2D,
	size: Vector3,
	roughness: float = WET_GROUND_ROUGHNESS,
	tint: Color = Color.WHITE,
	tile_meters: float = TERRAIN_TILE_METERS
) -> StandardMaterial3D:
	var texture_id: String = texture.resource_path if not texture.resource_path.is_empty() else texture.resource_name
	var key: String = "%s|%s|%s|%s|%s" % [texture_id, size, roughness, tint, tile_meters]
	if _terrain_materials.has(key):
		return _terrain_materials[key]
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	material.roughness = roughness
	## Damp stone bounces a tighter, stronger highlight than dry rock.
	material.metallic_specular = 0.72
	material.uv1_scale = Vector3(
		maxf(1.0, size.x / tile_meters),
		maxf(1.0, size.z / tile_meters),
		1.0
	)
	var normal_tex: Texture2D = _load_normal_for(texture)
	if normal_tex != null:
		material.normal_enabled = true
		material.normal_texture = normal_tex
		material.normal_scale = 0.7
	_terrain_materials[key] = material
	return material
