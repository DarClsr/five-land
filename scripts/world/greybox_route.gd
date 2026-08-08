class_name GreyboxRoute
extends Node3D

const GROUND_COLOR: Color = Color(0.28, 0.26, 0.22, 1.0)
const BRIDGE_COLOR: Color = Color(0.46, 0.43, 0.37, 1.0)
const WALL_COLOR: Color = Color(0.47, 0.45, 0.39, 1.0)
const CORRUPTION_COLOR: Color = Color(0.19, 0.28, 0.25, 1.0)
const SEAL_COLOR: Color = Color(0.56, 0.45, 0.25, 1.0)
const TOMBSTONE_COLOR: Color = Color(0.82, 0.81, 0.76, 1.0)
const VEIN_COLOR: Color = Color(0.3, 0.55, 0.48, 1.0)
const VEIN_GLOW: Color = Color(0.18, 0.42, 0.36, 1.0)
const CRACK_COLOR: Color = Color(0.11, 0.11, 0.1, 1.0)
const RUIN_COLOR: Color = Color(0.38, 0.37, 0.33, 1.0)
const ABYSS_GROUND_COLOR: Color = Color(0.14, 0.19, 0.2, 1.0)
const ABYSS_STONE_COLOR: Color = Color(0.23, 0.3, 0.32, 1.0)
const GROUT_COLOR: Color = Color(0.2, 0.19, 0.18, 1.0)

## Meters of world-space floor covered by one tile of a terrain texture.
const TERRAIN_TILE_METERS: float = 2.5

## Half-width in meters that the orthographic camera actually shows at
## size 5.0 on a 16:9 viewport. Orthographic projection has no perspective
## spread, so scenery beyond this X never reaches the screen no matter how
## tall it is: canyon walls have to sit inside this bound to frame the shot.
const VIEW_HALF_WIDTH: float = 4.45

## Wet stone reads as damp when it keeps a tight specular highlight, so the
## walking surfaces stay far below the dry-rock roughness used elsewhere.
const WET_GROUND_ROUGHNESS: float = 0.92
const WET_PATH_ROUGHNESS: float = 0.42

## The limestone source texture is a bright quarry grey. Knocking it down keeps
## the walking path from out-brightening the lantern pools, while staying
## lighter than the surrounding gravel so it still reads as a route.
const PATH_TINT: Color = Color(0.66, 0.62, 0.54, 1.0)

## Flagstone reads at a tighter repeat than open ground, otherwise a single
## slab shows one giant stone face and looks untextured.
const PATH_TILE_METERS: float = 1.05

## Number of discrete tone / gloss variants a flagstone slab can pick from.
## Quantising the jitter keeps the terrain material cache small: without it,
## every slab would allocate its own StandardMaterial3D.
const PATH_TONE_STEPS: int = 5
const PATH_GLOSS_STEPS: int = 3

## Route segments: [x_center, z_center, length, path_half_width, yaw_degrees].
## Positive yaw bends the authored -Z route toward world -X.
const CANYON_SEGMENTS: Array = [
	[0.0, 8.0, 9.0, 4.88, 0.0],
	[-2.0, 0.0, 9.2, 1.7, 30.0],
	[-4.0, -7.0, 7.0, 6.0, 0.0],
	[0.0, -16.5, 16.2, 2.5, -30.0],
	[4.0, -27.0, 10.0, 7.0, 0.0],
	[1.0, -34.0, 8.2, 1.85, 50.0],
	[-2.0, -44.0, 15.0, 9.0, 0.0],
]

## Continuous collision corridor. Visual canyon segments intentionally leave
## overlaps and gaps for composition, so gameplay boundaries are authored
## separately and include the bridge between DeepExit and XumenGate.
const NAVIGATION_SEGMENTS: Array = [
	[0.0, 8.0, 9.0, 3.55, 0.0],
	[-2.0, 0.0, 9.2, 1.6, 30.0],
	[-4.0, -7.0, 7.0, 5.8, 0.0],
	[0.0, -16.5, 16.2, 2.5, -30.0],
	[4.0, -27.0, 10.0, 6.8, 0.0],
	[1.0, -34.0, 8.2, 1.75, 50.0],
	[-2.0, -44.0, 15.0, 8.8, 0.0],
]

const ROUGH_GROUND_PIXEL_TEXTURE: Texture2D = preload("res://assets/textures/terrain/cave_flagstone_64.png")
const ROUGH_WALL_PIXEL_TEXTURE: Texture2D = preload("res://assets/textures/terrain/cave_rock_wall_64.png")
const BRIDGE_PIXEL_TEXTURE: Texture2D = preload("res://assets/textures/terrain/cave_bridge_64.png")
const TIMBER_PIXEL_TEXTURE: Texture2D = preload("res://assets/textures/terrain/cave_timber_64.png")
const MOSS_DECAL_TEXTURE: Texture2D = preload("res://assets/textures/terrain/cave_moss_decal_32.png")
# Legacy semantic slots now deliberately resolve to the authored pixel set.
const GROUND_SOIL_TEXTURE: Texture2D = ROUGH_GROUND_PIXEL_TEXTURE
const GRAVE_STONE_TEXTURE: Texture2D = ROUGH_WALL_PIXEL_TEXTURE
const CORRUPTION_GROUND_TEXTURE: Texture2D = ROUGH_WALL_PIXEL_TEXTURE

const ORGANIC_ROCK_SHADER: Shader = preload("res://assets/shaders/organic_rock.gdshader")
const PIXEL_GROUND_SHADER: Shader = preload("res://assets/shaders/pixel_ground_variation.gdshader")
const VOID_EDGE_SHADER: Shader = preload("res://assets/shaders/pixel_void_edge.gdshader")
const HD2D_MATERIAL_LIBRARY = preload("res://scripts/world/hd2d_material_library.gd")
## Stone cells stay physically small while the floor footprint remains wide:
## more cells fill the same chamber instead of stretching a few large slabs.
const PIXEL_TERRAIN_TILE_METERS: float = 0.6

var _organic_rock_materials: Dictionary[String, ShaderMaterial] = {}
var _ground_detail_textures: Dictionary[int, Texture2D] = {}

var _materials: Dictionary[String, ShaderMaterial] = {}
var _terrain_materials: Dictionary[String, Material] = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _deep_exit_soil_texture: Texture2D = ROUGH_GROUND_PIXEL_TEXTURE
var _weathered_limestone_texture: Texture2D = ROUGH_WALL_PIXEL_TEXTURE
var _abyss_material: StandardMaterial3D
var _abyss_ground_material: StandardMaterial3D
var _grout_material: StandardMaterial3D
var _corruption_glow_material: StandardMaterial3D


func _ready() -> void:
	_rng.seed = 20260805
	_build_deep_exit()
	_build_bridge()
	_build_fog_abyss_cemetery()
	_build_xumen_gate()
	_build_burial_road()
	_build_seal_courtyard()
	_build_boss_approach()
	_build_boss_arena()
	_build_navigation_boundaries()
	_build_backdrop_walls()
	_build_depth_silhouettes()
	_build_void_boundaries()
	_build_ground_detail_decals()


func has_section(section_name: StringName) -> bool:
	return has_node(NodePath(section_name))


func _build_deep_exit() -> void:
	var section: Node3D = _create_section(&"DeepExit", Vector3(0.0, -0.2, 8.0), Vector3(11.0, 0.4, 8.0), GROUND_COLOR, _deep_exit_soil_texture)
	_add_deep_exit_rails(section)
	var broken_wall_profile := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 0.72),
		Vector2(0.86, 0.82), Vector2(0.7, 0.66), Vector2(0.54, 0.94),
		Vector2(0.34, 0.77), Vector2(0.17, 1.0), Vector2(0.0, 0.82),
	])
	_add_profile_body(section, &"BrokenRearWallLeft", Vector3(-2.7, 0.55, 12.0), Vector3(1.9, 1.1, 0.5), broken_wall_profile, _weathered_limestone_texture)
	_add_profile_body(section, &"BrokenRearWallRight", Vector3(2.7, 0.42, 12.0), Vector3(1.9, 0.84, 0.5), broken_wall_profile, _weathered_limestone_texture, Vector3(0.0, 180.0, 0.0))
	var stele_profile := PackedVector2Array([
		Vector2(0.12, 0.0), Vector2(0.88, 0.0), Vector2(1.0, 0.72),
		Vector2(0.82, 0.96), Vector2(0.62, 0.9), Vector2(0.42, 1.0),
		Vector2(0.14, 0.86), Vector2(0.0, 0.34),
	])
	_add_profile_body(section, &"InvertedSteleLeft", Vector3(-2.5, 1.25, 8.2), Vector3(0.58, 2.5, 0.42), stele_profile, _weathered_limestone_texture, Vector3(-5.0, -8.0, 7.0))
	_add_profile_body(section, &"InvertedSteleRight", Vector3(2.35, 1.55, 6.6), Vector3(0.66, 3.1, 0.46), stele_profile, _weathered_limestone_texture, Vector3(4.0, 10.0, -6.0))
	var exit_crack_a := _make_decor_body(section, &"ExitCrackA", Vector3(1.15, 0.005, 9.3), Vector3(0.1, 0.025, 0.9), CRACK_COLOR)
	exit_crack_a.rotation_degrees.y = -12.0
	var exit_crack_b := _make_decor_body(section, &"ExitCrackB", Vector3(1.28, 0.005, 10.05), Vector3(0.09, 0.025, 0.7), CRACK_COLOR)
	exit_crack_b.rotation_degrees.y = 11.0
	var exit_crack_c := _make_decor_body(section, &"ExitCrackC", Vector3(1.48, 0.005, 10.58), Vector3(0.07, 0.025, 0.45), CRACK_COLOR)
	exit_crack_c.rotation_degrees.y = 24.0
	_add_deep_exit_tombstone(section, &"ExitTomb", Vector3(-3.0, 0.0, 10.2), 0.9, 1.7, false)
	_add_deep_exit_tombstone(section, &"ExitTombBroken", Vector3(3.05, 0.0, 9.2), 0.7, 1.1, true)
	_add_rock_pile(section, &"ExitRocks", Vector3(-4.55, 0.0, 6.4), 0.28, 3)
	_add_rock_pile(section, &"ExitRocks2", Vector3(4.55, 0.0, 10.0), 0.26, 3)
	_add_dead_tree(section, &"ExitTree", Vector3(-4.95, 0.0, 11.0), 1.55)
	_add_stone_path(section, &"ExitPath", 12.0, 4.5, 2.4)


func _build_bridge() -> void:
	var center := Vector3(-2.0, -0.2, 0.0)
	var section: Node3D = _create_section(
		&"OuterBridge", center, Vector3(3.4, 0.4, 9.2),
		BRIDGE_COLOR, BRIDGE_PIXEL_TEXTURE, 30.0
	)
	_add_bridge_underside(section)
	_add_broken_bridge_rails(section)
	_add_corruption_patch(section, &"BridgeWear", Vector3(-1.45, 0.012, 0.5), Vector3(0.9, 0.025, 1.45))
	_add_crack(section, &"BridgeCrack", Vector3(-2.7, 0.01, -2.0), Vector3(2.2, 0.06, 0.16))
	_add_oriented_stone_path(section, &"BridgePath", center, 9.0, 2.72, 30.0)


func _add_bridge_underside(parent: Node3D) -> void:
	var underside := _add_silhouette_box(
		parent, &"BridgeUnderside", Vector3(-2.0, -0.95, 0.0),
		Vector3(3.7, 1.55, 9.5), ABYSS_GROUND_COLOR
	)
	underside.rotation_degrees.y = 30.0
	underside.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


func _add_broken_bridge_rails(parent: Node3D) -> void:
	var center := Vector3(-2.0, 0.0, 0.0)
	var basis := Basis(Vector3.UP, deg_to_rad(30.0))
	for side: float in [-1.0, 1.0]:
		var side_name: String = "Right" if side > 0.0 else "Left"
		for index: int in range(5):
			if (index == 1 and side < 0.0) or (index == 3 and side > 0.0):
				continue
			var local_position := Vector3(side * 1.55, 0.18, 3.6 - index * 1.8)
			var stone := _make_decor_body(
				parent, StringName("Bridge%sBoundary%d" % [side_name, index]),
				center + basis * local_position, Vector3(0.32, 0.36, 0.62),
				Color(0.25, 0.28, 0.27, 1.0), ROUGH_WALL_PIXEL_TEXTURE
			)
			stone.rotation_degrees.y = 30.0 + _rng.randf_range(-6.0, 6.0)


func _build_fog_abyss_cemetery() -> void:
	var cemetery := Node3D.new()
	cemetery.name = &"FogAbyssCemetery"
	add_child(cemetery)
	_add_silhouette_box(
		cemetery, &"LowerGroundLeft", Vector3(-5.05, -1.78, 0.0),
		Vector3(6.6, 0.34, 10.8), ABYSS_GROUND_COLOR
	)
	_add_silhouette_box(
		cemetery, &"LowerGroundRight", Vector3(5.05, -1.78, 0.0),
		Vector3(6.6, 0.34, 10.8), ABYSS_GROUND_COLOR
	)
	var grave_data: Array = [
		[-2.45, 3.5, 0.55, 1.35, -8.0], [-3.1, 2.4, 0.48, 1.0, 7.0],
		[-4.0, 3.8, 0.7, 1.75, -12.0], [-5.0, 2.0, 0.5, 1.15, 5.0],
		[-2.7, 0.6, 0.62, 1.55, 11.0], [-3.7, -0.7, 0.45, 0.95, -6.0],
		[-5.1, -1.6, 0.68, 1.45, 13.0], [-2.55, -2.7, 0.52, 1.1, -9.0],
		[-4.2, -3.6, 0.58, 1.32, 8.0],
		[2.5, 3.0, 0.5, 1.2, 9.0], [3.3, 1.8, 0.66, 1.58, -11.0],
		[4.7, 3.7, 0.46, 0.92, 6.0], [5.3, 1.1, 0.72, 1.7, -7.0],
		[2.65, 0.0, 0.58, 1.42, -12.0], [3.8, -1.2, 0.44, 0.88, 10.0],
		[5.2, -2.4, 0.62, 1.35, -5.0], [2.7, -3.4, 0.5, 1.05, 8.0],
		[4.25, -3.7, 0.68, 1.52, -13.0],
	]
	for index: int in grave_data.size():
		var entry: Array = grave_data[index]
		_add_abyss_grave(
			cemetery, StringName("MistGrave%d" % index),
			Vector3(float(entry[0]), -1.6, float(entry[1])),
			float(entry[2]), float(entry[3]), float(entry[4])
		)
	_add_abyss_monument(cemetery, &"DistantSteleLeft", Vector3(-6.2, -1.6, 1.2), Vector3(1.25, 5.4, 0.72), -13.0)
	_add_abyss_monument(cemetery, &"DistantSteleRight", Vector3(6.0, -1.6, -2.3), Vector3(1.05, 4.6, 0.66), 16.0)
	_add_abyss_monument(cemetery, &"BrokenColumnLeft", Vector3(-4.6, -1.6, -0.1), Vector3(0.72, 2.6, 0.72), 8.0)
	_add_abyss_monument(cemetery, &"BrokenColumnRight", Vector3(4.8, -1.6, 2.5), Vector3(0.66, 2.2, 0.66), -10.0)
	_add_stone_beast_silhouette(cemetery, &"StoneBeastLeft", Vector3(-3.55, -1.55, 1.25), -1.0)
	_add_stone_beast_silhouette(cemetery, &"StoneBeastRight", Vector3(3.7, -1.55, -2.65), 1.0)
	_add_fallen_unlit_lantern(cemetery, &"FallenLanternLeft", Vector3(-4.5, -1.5, -2.5), -68.0)
	_add_fallen_unlit_lantern(cemetery, &"FallenLanternRight", Vector3(4.4, -1.5, 0.2), 73.0)
	_add_abyss_corruption(cemetery, &"AbyssCorruptionLeft", Vector3(-3.45, -1.57, 2.15), Vector3(1.25, 0.035, 0.62))
	_add_abyss_corruption(cemetery, &"AbyssCorruptionRight", Vector3(4.1, -1.57, -1.35), Vector3(1.0, 0.035, 0.72))


func _add_abyss_grave(
	parent: Node3D, grave_name: StringName, base_position: Vector3,
	width: float, height: float, yaw: float
) -> void:
	var grave := Node3D.new()
	grave.name = grave_name
	grave.position = base_position
	grave.rotation_degrees = Vector3(0.0, yaw, _rng.randf_range(-7.0, 7.0))
	parent.add_child(grave)
	_add_silhouette_box(
		grave, &"Slab", Vector3(0.0, height * 0.5, 0.0),
		Vector3(width, height, 0.24), ABYSS_STONE_COLOR
	)
	var crown := _add_silhouette_box(
		grave, &"Crown", Vector3(0.0, height + 0.03, 0.0),
		Vector3(width * 0.72, 0.2, 0.34), ABYSS_STONE_COLOR
	)
	crown.rotation_degrees.y = 45.0
	_add_silhouette_box(
		grave, &"Foot", Vector3(0.0, 0.08, 0.0),
		Vector3(width * 1.35, 0.16, 0.42), ABYSS_STONE_COLOR
	)


func _add_abyss_monument(
	parent: Node3D, monument_name: StringName, base_position: Vector3,
	size: Vector3, lean: float
) -> void:
	var monument := _add_silhouette_box(
		parent, monument_name, base_position + Vector3(0.0, size.y * 0.5, 0.0),
		size, ABYSS_STONE_COLOR
	)
	monument.rotation_degrees = Vector3(0.0, _rng.randf_range(-12.0, 12.0), lean)


func _add_stone_beast_silhouette(
	parent: Node3D, beast_name: StringName, base_position: Vector3, facing: float
) -> void:
	var beast := Node3D.new()
	beast.name = beast_name
	beast.position = base_position
	parent.add_child(beast)
	_add_silhouette_box(beast, &"Body", Vector3(0.0, 0.38, 0.0), Vector3(0.95, 0.62, 0.52), ABYSS_STONE_COLOR)
	_add_silhouette_box(beast, &"Head", Vector3(facing * 0.52, 0.65, 0.0), Vector3(0.38, 0.42, 0.38), ABYSS_STONE_COLOR)
	_add_silhouette_box(beast, &"Tail", Vector3(-facing * 0.55, 0.48, 0.0), Vector3(0.42, 0.18, 0.18), ABYSS_STONE_COLOR).rotation_degrees.z = 28.0 * facing


func _add_fallen_unlit_lantern(
	parent: Node3D, lantern_name: StringName, base_position: Vector3, lean: float
) -> void:
	var fallen := Node3D.new()
	fallen.name = lantern_name
	fallen.position = base_position
	fallen.rotation_degrees.z = lean
	parent.add_child(fallen)
	_add_silhouette_box(fallen, &"Post", Vector3(0.0, 0.55, 0.0), Vector3(0.18, 1.1, 0.18), ABYSS_STONE_COLOR)
	_add_silhouette_box(fallen, &"Head", Vector3(0.0, 1.15, 0.0), Vector3(0.46, 0.36, 0.46), ABYSS_STONE_COLOR)


func _add_abyss_corruption(
	parent: Node3D, patch_name: StringName, center: Vector3, size: Vector3
) -> void:
	var patch := _add_silhouette_box(parent, patch_name, center, size, ABYSS_STONE_COLOR)
	patch.material_override = _get_corruption_glow_material()


func _add_silhouette_box(
	parent: Node3D, mesh_name: StringName, center: Vector3,
	size: Vector3, color: Color
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = mesh_name
	mesh_instance.position = center
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.material_override = _get_abyss_material(color)
	parent.add_child(mesh_instance)
	return mesh_instance


func _get_abyss_material(color: Color) -> StandardMaterial3D:
	if color == ABYSS_GROUND_COLOR and _abyss_ground_material != null:
		return _abyss_ground_material
	if color == ABYSS_STONE_COLOR and _abyss_material != null:
		return _abyss_material
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.albedo_texture = (
		ROUGH_GROUND_PIXEL_TEXTURE if color == ABYSS_GROUND_COLOR
		else ROUGH_WALL_PIXEL_TEXTURE
	)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 1.0
	if color == ABYSS_GROUND_COLOR:
		_abyss_ground_material = material
	else:
		_abyss_material = material
	return material


func _get_corruption_glow_material() -> StandardMaterial3D:
	if _corruption_glow_material != null:
		return _corruption_glow_material
	_corruption_glow_material = StandardMaterial3D.new()
	_corruption_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_corruption_glow_material.albedo_color = Color(0.08, 0.2, 0.15, 1.0)
	_corruption_glow_material.emission_enabled = true
	_corruption_glow_material.emission = Color(0.12, 0.42, 0.28, 1.0)
	_corruption_glow_material.emission_energy_multiplier = 0.65
	return _corruption_glow_material


func _build_xumen_gate() -> void:
	var section: Node3D = _create_section(&"XumenGate", Vector3(-4.0, -0.2, -7.0), Vector3(12.0, 0.4, 6.0), GROUND_COLOR, GROUND_SOIL_TEXTURE)
	_add_side_rails(section, Vector3(-4.0, 0.0, -7.0), Vector2(12.0, 6.0))
	_add_block(section, &"GatePillarLeft", Vector3(-6.45, 2.2, -8.0), Vector3(1.2, 4.4, 1.2), WALL_COLOR)
	_add_block(section, &"GatePillarRight", Vector3(-1.55, 2.2, -8.0), Vector3(1.2, 4.4, 1.2), WALL_COLOR)
	_add_block(section, &"GateLintel", Vector3(-4.0, 4.0, -8.0), Vector3(6.1, 0.7, 1.0), WALL_COLOR)
	_add_corruption_patch(section, &"GateCorruption", Vector3(-5.6, 0.01, -6.4), Vector3(2.4, 0.05, 2.0))
	_add_tombstone(section, &"GateTombLeft", Vector3(-8.6, 0.0, -6.2), 0.8, 1.5)
	_add_tombstone(section, &"GateTombRight", Vector3(0.5, 0.0, -7.6), 0.9, 1.9)
	_add_rock_pile(section, &"GateRocks", Vector3(-8.8, 0.0, -8.8), 0.4, 4)
	_add_dead_tree(section, &"GateTree", Vector3(1.1, 0.0, -5.2), 2.2)
	_add_stone_path_at_x(section, &"GatePath", -4.0, -4.0, -10.0, 2.6)


func _build_burial_road() -> void:
	var center := Vector3(0.0, -0.2, -16.5)
	var section: Node3D = _create_section(
		&"BurialRoad", center, Vector3(5.0, 0.4, 16.2),
		BRIDGE_COLOR, GRAVE_STONE_TEXTURE, -30.0
	)
	_add_side_rails(section, Vector3(0.0, 0.0, -16.5), Vector2(5.0, 16.2), null, 0.85, -30.0)
	_add_block(section, &"OverturnedCart", Vector3(-2.0, 0.45, -13.5), Vector3(1.8, 0.9, 1.0), Color(0.42, 0.3, 0.22), TIMBER_PIXEL_TEXTURE)
	_add_tombstone(section, &"BurialStele", Vector3(3.0, 0.0, -20.5), 1.0, 2.5, GRAVE_STONE_TEXTURE)
	_add_vein_patch(section, &"VeinRoad1", Vector3(-2.1, 0.02, -12.7), Vector3(0.7, 0.08, 1.6))
	_add_vein_patch(section, &"VeinRoad2", Vector3(0.8, 0.02, -18.5), Vector3(1.9, 0.08, 0.5))
	_add_crack(section, &"RoadCrack1", Vector3(3.0, 0.01, -21.5), Vector3(0.16, 0.06, 3.0))
	_add_tombstone(section, &"RoadTomb1", Vector3(-2.6, 0.0, -14.8), 0.8, 1.4)
	_add_tombstone(section, &"RoadTomb2", Vector3(0.5, 0.0, -16.7), 0.7, 1.2)
	_add_tombstone(section, &"RoadTomb3", Vector3(0.8, 0.0, -20.0), 0.85, 1.6)
	_add_tombstone(section, &"RoadTomb4", Vector3(4.2, 0.0, -22.5), 0.6, 1.0)
	_add_corruption_patch(section, &"RoadCorruption1", Vector3(0.5, 0.01, -18.5), Vector3(1.6, 0.05, 1.4))
	_add_corruption_patch(section, &"RoadCorruption2", Vector3(3.0, 0.01, -21.8), Vector3(1.3, 0.05, 1.1))
	_add_rock_pile(section, &"RoadRocks1", Vector3(-2.4, 0.0, -13.2), 0.4, 4)
	_add_rock_pile(section, &"RoadRocks2", Vector3(4.0, 0.0, -22.0), 0.35, 3)
	_add_dead_tree(section, &"RoadTree1", Vector3(0.2, 0.0, -19.0), 2.8)
	_add_dead_tree(section, &"RoadTree2", Vector3(4.4, 0.0, -23.0), 2.0)
	_add_oriented_stone_path(section, &"RoadPath", center, 15.8, 2.2, -30.0)


func _build_seal_courtyard() -> void:
	var section: Node3D = _create_section(&"SealCourtyard", Vector3(4.0, -0.2, -27.0), Vector3(14.0, 0.4, 10.0), GROUND_COLOR, GRAVE_STONE_TEXTURE)
	_add_side_rails(section, Vector3(4.0, 0.0, -27.0), Vector2(14.0, 10.0))
	for index: int in range(3):
		var x_position: float = 1.0 + index * 3.0
		_add_block(section, StringName("SealPost%d" % (index + 1)), Vector3(x_position, 1.15, -27.5), Vector3(0.8, 2.3, 0.8), SEAL_COLOR)
	_add_block(section, &"GraveGateLeft", Vector3(1.7, 1.8, -31.1), Vector3(1.2, 3.6, 1.1), WALL_COLOR)
	_add_block(section, &"GraveGateRight", Vector3(6.3, 1.8, -31.1), Vector3(1.2, 3.6, 1.1), WALL_COLOR)
	_add_crack(section, &"CourtyardCrack", Vector3(4.0, 0.01, -25.5), Vector3(3.2, 0.06, 0.18))
	_add_vein_patch(section, &"VeinCourtyard1", Vector3(-1.2, 0.02, -26.0), Vector3(0.5, 0.08, 2.2))
	_add_vein_patch(section, &"VeinCourtyard2", Vector3(9.0, 0.02, -28.5), Vector3(2.4, 0.08, 0.5))
	_add_tombstone(section, &"CourtyardTomb1", Vector3(-1.8, 0.0, -29.2), 0.9, 1.8)
	_add_tombstone(section, &"CourtyardTomb2", Vector3(9.7, 0.0, -25.6), 0.8, 1.3)
	_add_tombstone(section, &"CourtyardTomb3", Vector3(10.0, 0.0, -30.0), 0.7, 1.5)
	_add_corruption_patch(section, &"CourtyardCorruption", Vector3(1.4, 0.01, -29.0), Vector3(2.2, 0.05, 1.8))
	_add_rock_pile(section, &"CourtyardRocks1", Vector3(-2.4, 0.0, -24.8), 0.45, 5)
	_add_rock_pile(section, &"CourtyardRocks2", Vector3(10.4, 0.0, -31.0), 0.4, 4)
	_add_dead_tree(section, &"CourtyardTree", Vector3(-2.6, 0.0, -29.0), 3.0)


func _build_boss_approach() -> void:
	var center := Vector3(1.0, -0.2, -34.0)
	var section: Node3D = _create_section(
		&"GravePassage", center, Vector3(3.7, 0.4, 8.2),
		BRIDGE_COLOR, GRAVE_STONE_TEXTURE, 50.0
	)
	_add_side_rails(section, Vector3(1.0, 0.0, -34.0), Vector2(3.7, 8.2), null, 0.85, 50.0)
	_add_vein_patch(section, &"VeinPassage", Vector3(-0.2, 0.02, -35.0), Vector3(0.6, 0.08, 2.6))
	_add_tombstone(section, &"PassageTomb", Vector3(2.4, 0.0, -33.4), 0.7, 1.3)
	_add_ruin_pillar(section, &"PassagePillar", Vector3(-2.0, 0.0, -36.5), 0.5, 2.8)
	_add_rock_pile(section, &"PassageRocks", Vector3(2.0, 0.0, -32.4), 0.35, 3)
	_add_oriented_stone_path(section, &"PassagePath", center, 8.0, 1.6, 50.0)


func _build_boss_arena() -> void:
	var section: Node3D = _create_section(&"BossArena", Vector3(-2.0, -0.2, -44.0), Vector3(18.0, 0.4, 14.0), CORRUPTION_COLOR, CORRUPTION_GROUND_TEXTURE)
	_add_side_rails(section, Vector3(-2.0, 0.0, -44.0), Vector2(18.0, 14.0))
	_add_block(section, &"BurdenStoneLeft", Vector3(-8.2, 1.8, -44.5), Vector3(1.2, 3.6, 1.2), WALL_COLOR)
	_add_block(section, &"BurdenStoneRight", Vector3(5.0, 2.4, -42.5), Vector3(1.4, 4.8, 1.4), WALL_COLOR)
	_add_block(section, &"BurdenStoneRear", Vector3(-2.0, 2.8, -49.0), Vector3(1.8, 5.6, 1.8), WALL_COLOR)
	_add_crack(section, &"ArenaCrack1", Vector3(-4.8, 0.01, -45.6), Vector3(3.4, 0.06, 0.18))
	_add_crack(section, &"ArenaCrack2", Vector3(0.2, 0.01, -47.2), Vector3(0.2, 0.06, 3.6))
	_add_vein_patch(section, &"VeinArena", Vector3(-3.0, 0.02, -43.2), Vector3(0.9, 0.08, 1.8))
	_add_tombstone(section, &"ArenaTomb", Vector3(2.6, 0.0, -45.8), 1.0, 2.0)
	_add_ruin_pillar(section, &"ArenaPillarLeft", Vector3(-9.4, 0.0, -42.6), 0.6, 3.4)
	_add_ruin_pillar(section, &"ArenaPillarRight", Vector3(5.2, 0.0, -47.4), 0.55, 2.9)
	_add_rock_pile(section, &"ArenaRocks1", Vector3(-9.8, 0.0, -47.0), 0.5, 5)
	_add_rock_pile(section, &"ArenaRocks2", Vector3(5.8, 0.0, -45.0), 0.45, 4)
	_add_dead_tree(section, &"ArenaTree", Vector3(-7.0, 0.0, -50.0), 2.6)


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
		_add_canyon_side(
			backdrop, index, float(segment[0]), float(segment[1]),
			float(segment[2]), float(segment[3]), float(segment[4]), 1.0
		)
		_add_canyon_side(
			backdrop, index, float(segment[0]), float(segment[1]),
			float(segment[2]), float(segment[3]), float(segment[4]), -1.0
		)
	## Rear cap behind the boss arena.
	for index: int in range(5):
		var x: float = -8.0 + index * 4.0
		_add_organic_cliff(
			backdrop, StringName("RearWall%d" % index),
			Vector3(x - 2.0, 0.0, -52.0), Vector3(3.6, 8.0 + _rng.randf_range(-1.5, 1.5), 2.2),
			_rng.randf_range(-3.0, 3.0)
		)
	_build_cliff_branches(backdrop)


func _build_cliff_branches(parent: Node3D) -> void:
	var branch_data: Array = [
		[Vector3(-5.05, 4.8, 6.0), Vector3(0.1, 1.7, 0.1), -42.0],
		[Vector3(5.1, 5.3, 3.4), Vector3(0.09, 1.85, 0.09), 37.0],
		[Vector3(-3.35, 5.6, -15.0), Vector3(0.11, 2.4, 0.11), -31.0],
		[Vector3(3.45, 4.9, -20.5), Vector3(0.09, 2.1, 0.09), 46.0],
	]
	for index: int in branch_data.size():
		var entry: Array = branch_data[index]
		var branch := _add_silhouette_box(
			parent, StringName("CliffBranch%d" % index), entry[0], entry[1],
			Color(0.045, 0.065, 0.072, 1.0)
		)
		branch.rotation_degrees.z = float(entry[2])


## Lays one flank of a canyon segment as overlapping cliff blocks. The blocks
## are stepped along Z with jittered height and yaw so the silhouette breaks
## up instead of reading as one long extruded wall.
func _add_canyon_side(
	backdrop: Node3D,
	segment_index: int,
	x_center: float,
	z_center: float,
	z_length: float,
	path_half_width: float,
	yaw: float,
	side: float
) -> void:
	const BLOCK_DEPTH: float = 2.8
	const BLOCK_WIDTH: float = 2.4
	var step: float = 2.4
	var count: int = int(ceil(z_length / step)) + 1
	var center := Vector3(x_center, 0.0, z_center)
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	var z_start: float = z_length * 0.5
	var x: float = side * (path_half_width + BLOCK_WIDTH * 0.5 - 0.05)
	var side_tag: String = "Right" if side > 0.0 else "Left"
	for index: int in range(count):
		var z: float = z_start - index * step
		var local_position := Vector3(x + side * _rng.randf_range(0.0, 0.5), 0.0, z)
		var world_position: Vector3 = center + basis * local_position
		## Camera-facing blocks frame the floor instead of covering it. Rear walls
		## keep the full canyon height while foreground walls drop below the actor.
		var height: float = (
			_rng.randf_range(2.4, 4.0)
			if world_position.z > center.z + 0.35
			else _rng.randf_range(5.0, 8.5)
		)
		var cliff := _add_organic_cliff(
			backdrop, StringName("Canyon%s%d_%d" % [side_tag, segment_index, index]),
			world_position,
			Vector3(BLOCK_WIDTH, height, BLOCK_DEPTH),
			yaw + _rng.randf_range(-6.0, 6.0),
			0.62
		)
		cliff.add_to_group(&"camera_foreground")
		cliff.transparency = 0.18


func _add_organic_cliff(
	parent: Node3D,
	block_name: StringName,
	center: Vector3,
	size: Vector3,
	yaw: float,
	darken: float = 0.2
) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = block_name
	mesh_instance.position = center
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	box_mesh.subdivide_width = 4
	box_mesh.subdivide_height = clampi(int(round(size.y * 1.5)), 4, 12)
	box_mesh.subdivide_depth = 4
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = _get_organic_rock_material(size, darken)
	mesh_instance.rotation_degrees = Vector3(0.0, yaw, 0.0)
	parent.add_child(mesh_instance)
	return mesh_instance


func _create_section(
	section_name: StringName,
	floor_position: Vector3,
	floor_size: Vector3,
	color: Color = GROUND_COLOR,
	_floor_texture: Texture2D = null,
	yaw: float = 0.0
) -> Node3D:
	var section: Node3D = Node3D.new()
	section.name = section_name
	add_child(section)
	# Keep one authored cave surface language across the route. The bridge is the
	# only deliberate variant; legacy soil/limestone arguments are ignored.
	var floor_texture: Texture2D = BRIDGE_PIXEL_TEXTURE if section_name == &"OuterBridge" else ROUGH_GROUND_PIXEL_TEXTURE
	_add_block(section, &"Floor", floor_position, floor_size, color, floor_texture)
	var floor := section.get_node("Floor") as StaticBody3D
	floor.rotation_degrees.y = yaw
	return section


func _add_side_rails(
	parent: Node3D,
	center: Vector3,
	floor_size: Vector2,
	texture: Texture2D = null,
	height: float = 0.85,
	yaw: float = 0.0
) -> void:
	var rail_size: Vector3 = Vector3(0.35, height, floor_size.y)
	var edge_x: float = floor_size.x * 0.5 - rail_size.x * 0.5
	var basis := Basis(Vector3.UP, deg_to_rad(yaw))
	for side: float in [-1.0, 1.0]:
		var rail_name: StringName = &"RailRight" if side > 0.0 else &"RailLeft"
		var rail := _make_decor_body(
			parent, rail_name,
			center + basis * Vector3(side * edge_x, height * 0.5, 0.0),
			rail_size, WALL_COLOR, texture
		)
		rail.rotation_degrees.y = yaw


func _add_deep_exit_rails(parent: Node3D) -> void:
	var profile := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(1.0, 0.0), Vector2(1.0, 0.62),
		Vector2(0.86, 0.78), Vector2(0.7, 0.58), Vector2(0.5, 0.9),
		Vector2(0.28, 0.7), Vector2(0.12, 1.0), Vector2(0.0, 0.76),
	])
	_add_profile_body(parent, &"RailLeft", Vector3(-3.55, 0.225, 8.0), Vector3(8.0, 0.45, 0.35), profile, _weathered_limestone_texture, Vector3(0.0, 90.0, 0.0))
	_add_profile_body(parent, &"RailRight", Vector3(3.55, 0.225, 8.0), Vector3(8.0, 0.45, 0.35), profile, _weathered_limestone_texture, Vector3(0.0, 90.0, 0.0))


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
	var material := _get_stylized_stone_material(
		texture,
		Color(0.62, 0.64, 0.61, 1.0),
		1.0 / maxf(PIXEL_TERRAIN_TILE_METERS, 0.01)
	)
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


## A chipped tombstone slab: irregular extruded profiles replace the old box
## silhouette, while collision intentionally stays a stable box.
func _add_tombstone(parent: Node3D, block_name: StringName, center: Vector3, width: float, height: float, texture: Texture2D = null) -> void:
	var base_size: Vector3 = Vector3(width * 0.9, 0.22, 0.5)
	var slab_size: Vector3 = Vector3(width * 0.55, height, 0.22)
	var stone_texture: Texture2D = texture if texture != null else GRAVE_STONE_TEXTURE
	var base_profile := PackedVector2Array([
		Vector2(0.06, 0.0), Vector2(0.94, 0.0), Vector2(1.0, 0.48),
		Vector2(0.88, 0.94), Vector2(0.18, 1.0), Vector2(0.0, 0.42),
	])
	_add_profile_body(
		parent,
		StringName("%sBase" % block_name),
		center + Vector3(0.0, 0.11, 0.0),
		base_size,
		base_profile,
		stone_texture
	)
	var slab_yaw: float = _rng.randf_range(-10.0, 10.0)
	var slab_lean: float = _rng.randf_range(2.0, 9.0) * (_rng.randf() < 0.5 as int * 2 - 1)
	var top_notch: float = _rng.randf_range(0.07, 0.16)
	var slab_profile := PackedVector2Array([
		Vector2(0.08, 0.0), Vector2(0.92, 0.0), Vector2(1.0, 0.3),
		Vector2(0.9, 0.56), Vector2(0.96, 0.78), Vector2(0.78, 0.96),
		Vector2(0.62, 0.88 - top_notch), Vector2(0.47, 1.0),
		Vector2(0.28, 0.91), Vector2(0.1, 0.72), Vector2(0.0, 0.4),
	])
	var slab_body: StaticBody3D = _add_profile_body(
		parent,
		StringName("%sSlab" % block_name),
		center + Vector3(0.0, 0.22 + height * 0.5, 0.0),
		slab_size,
		slab_profile,
		stone_texture
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
		var tone_step: int = i % 3
		var rock_color: Color = RUIN_COLOR.darkened(0.1 + float(tone_step) * 0.05)
		var rock_material := _get_stylized_stone_material(
			ROUGH_WALL_PIXEL_TEXTURE,
			rock_color,
			1.25
		)
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


## Invisible StaticBody walls make the authored cave silhouette authoritative
## for gameplay as well as rendering. They overlap at section seams so dodge
## movement cannot slip through a one-frame gap.
func _build_navigation_boundaries() -> void:
	var boundaries := Node3D.new()
	boundaries.name = &"NavigationBoundaries"
	add_child(boundaries)
	for index: int in NAVIGATION_SEGMENTS.size():
		var segment: Array = NAVIGATION_SEGMENTS[index]
		var center := Vector3(float(segment[0]), 1.5, float(segment[1]))
		var z_length: float = float(segment[2]) + 0.45
		var half_width: float = float(segment[3])
		var yaw: float = float(segment[4])
		var basis := Basis(Vector3.UP, deg_to_rad(yaw))
		for side: float in [-1.0, 1.0]:
			var side_name: String = "Right" if side > 0.0 else "Left"
			_add_invisible_wall(
				boundaries, StringName("%sWall%d" % [side_name, index]),
				center + basis * Vector3(side * half_width, 0.0, 0.0),
				Vector3(0.4, 3.0, z_length), yaw
			)
	## Wide rooms need authored shoulders around each diagonal doorway. Corridor
	## side walls alone cannot close the unused part of a room's open edge.
	_add_room_edge_caps(boundaries, &"DeepExitBack", 0.0, 3.55, 7.1, 3.5)
	_add_room_edge_caps(boundaries, &"GateFront", -4.0, -3.95, 12.0, 3.5)
	_add_room_edge_caps(boundaries, &"GateBack", -4.0, -10.05, 12.0, 5.0)
	_add_room_edge_caps(boundaries, &"CourtyardFront", 4.0, -21.95, 14.0, 5.0)
	_add_room_edge_caps(boundaries, &"CourtyardBack", 4.0, -32.05, 14.0, 3.7)
	_add_room_edge_caps(boundaries, &"ArenaFront", -2.0, -36.95, 18.0, 3.7)
	_add_invisible_wall(
		boundaries, &"ForegroundCap", Vector3(0.0, 1.5, 12.45),
		Vector3(11.8, 3.0, 0.4)
	)
	_add_invisible_wall(
		boundaries, &"RearCap", Vector3(-2.0, 1.5, -51.25),
		Vector3(18.8, 3.0, 0.4)
	)


func _add_room_edge_caps(
	parent: Node3D,
	cap_name: StringName,
	opening_x: float,
	z: float,
	room_width: float,
	opening_width: float
) -> void:
	var side_span: float = (room_width - opening_width) * 0.5
	if side_span <= 0.05:
		return
	var room_left: float = opening_x - room_width * 0.5
	for side: int in range(2):
		var center_x: float = (
			room_left + side_span * 0.5
			if side == 0
			else opening_x + opening_width * 0.5 + side_span * 0.5
		)
		_add_invisible_wall(
			parent, StringName("%s%d" % [cap_name, side]),
			Vector3(center_x, 1.5, z), Vector3(side_span + 0.25, 3.0, 0.45)
		)


func _add_invisible_wall(
	parent: Node3D,
	wall_name: StringName,
	center: Vector3,
	size: Vector3,
	yaw: float = 0.0
) -> void:
	var wall := StaticBody3D.new()
	wall.name = wall_name
	wall.position = center
	wall.rotation_degrees.y = yaw
	wall.collision_layer = 1
	wall.collision_mask = 0
	var collision := CollisionShape3D.new()
	collision.name = &"CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	collision.shape = box
	wall.add_child(collision)
	parent.add_child(wall)


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
	trunk.material_override = _get_stylized_stone_material(TIMBER_PIXEL_TEXTURE, Color(0.4, 0.28, 0.2), 1.45)
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
		branch.material_override = _get_stylized_stone_material(TIMBER_PIXEL_TEXTURE, Color(0.38, 0.25, 0.18), 1.45)
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
## has something to follow. The old running bond is deliberately weathered by
## uneven cells, missing edges, settlement and occasional corrupted stones.
## Visual only: the slabs sit a few millimetres above the floor and carry no collision.
func _add_stone_path_at_x(
	parent: Node3D,
	block_name: StringName,
	x: float,
	z_from: float,
	z_to: float,
	width: float
) -> void:
	var frame := Node3D.new()
	frame.name = StringName("%sFrame" % block_name)
	frame.position.x = x
	parent.add_child(frame)
	_add_stone_path(frame, block_name, z_from, z_to, width)


func _add_oriented_stone_path(
	parent: Node3D,
	block_name: StringName,
	center: Vector3,
	length: float,
	width: float,
	yaw: float
) -> void:
	var frame := Node3D.new()
	frame.name = StringName("%sFrame" % block_name)
	frame.position = Vector3(center.x, 0.0, center.z)
	frame.rotation_degrees.y = yaw
	parent.add_child(frame)
	_add_stone_path(frame, block_name, length * 0.5, -length * 0.5, width)


func _add_stone_path(parent: Node3D, block_name: StringName, z_from: float, z_to: float, width: float) -> void:
	## Grout gap between neighbouring slabs; the dark floor shows through it.
	const SLAB_GAP: float = 0.018
	## Target slab footprint before jitter, in metres.
	const SLAB_LENGTH: float = 1.18
	const SLAB_WIDTH: float = 2.15
	var path_root: Node3D = Node3D.new()
	path_root.name = block_name
	parent.add_child(path_root)
	var transform_groups: Array[Array] = []
	for _group_index: int in range(PATH_TONE_STEPS * PATH_GLOSS_STEPS):
		transform_groups.append([])
	var span: float = absf(z_to - z_from)
	var direction: float = signf(z_to - z_from)
	var rows: int = maxi(1, int(round(span / SLAB_LENGTH)))
	var columns: int = maxi(1, int(round(width / SLAB_WIDTH)))
	var column_width: float = width / float(columns)
	## Weighted cells make the paving genuinely irregular while their normalized
	## sum still covers the authored path and preserves a minimum grout gap.
	var row_weights: Array[float] = []
	var row_weight_total: float = 0.0
	for _row: int in range(rows):
		var row_weight: float = _rng.randf_range(0.85, 1.35)
		row_weights.append(row_weight)
		row_weight_total += row_weight
	var grout_bed := MeshInstance3D.new()
	grout_bed.name = StringName("%sGroutBed" % block_name)
	grout_bed.position = Vector3(0.0, 0.004, (z_from + z_to) * 0.5)
	var grout_mesh := BoxMesh.new()
	grout_mesh.size = Vector3(width + 0.08, 0.016, span + 0.08)
	grout_bed.mesh = grout_mesh
	grout_bed.material_override = _get_grout_material()
	grout_bed.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(grout_bed)
	var z_cursor: float = z_from
	var last_length_damage_row: int = -2
	for row: int in range(rows):
		var row_length: float = span * row_weights[row] / row_weight_total
		var z: float = z_cursor + direction * row_length * 0.5
		z_cursor += direction * row_length
		## Running bond: every other row is nudged half a slab sideways so the
		## grout lines never form one continuous seam down the corridor.
		var bond_offset: float = 0.0
		if columns > 1 and row % 2 != 0:
			bond_offset = column_width * 0.5
		var column_weights: Array[float] = []
		var column_weight_total: float = 0.0
		for _column: int in range(columns):
			## The second multiplier is the widened +/-8% column jitter.
			var column_weight: float = (
				_rng.randf_range(0.85, 1.35) * _rng.randf_range(0.92, 1.08)
			)
			column_weights.append(column_weight)
			column_weight_total += column_weight
		var x_cursor: float = -width * 0.5
		for column: int in range(columns):
			var cell_width: float = width * column_weights[column] / column_weight_total
			var x: float = x_cursor + cell_width * 0.5 + bond_offset
			x_cursor += cell_width
			if absf(x) > width * 0.5:
				continue
			var is_outer_edge: bool = column == 0 or column == columns - 1
			var erode_single_column_edge: bool = columns == 1 and _rng.randf() < 0.15
			if columns > 1 and is_outer_edge and _rng.randf() < 0.15:
				continue
			## The normalized row/column weights already supply the requested
			## 0.85-1.35 size range; fill that cell instead of shrinking it twice.
			var slab_width: float = maxf(0.2, cell_width - SLAB_GAP)
			var slab_length: float = maxf(0.2, row_length - SLAB_GAP)
			var x_room: float = maxf(0.0, (cell_width - SLAB_GAP - slab_width) * 0.5)
			var z_room: float = maxf(0.0, (row_length - SLAB_GAP - slab_length) * 0.5)
			var x_offset: float = clampf(_rng.randf_range(-0.04, 0.04), -x_room, x_room)
			var z_offset: float = clampf(_rng.randf_range(-0.04, 0.04), -z_room, z_room)
			if erode_single_column_edge:
				## A one-column path cannot omit its only slab without severing the road;
				## shave one side instead so the silhouette still loses its ruler edge.
				var edge_loss: float = slab_width * _rng.randf_range(0.12, 0.22)
				var surviving_side: float = -1.0 if _rng.randf() < 0.5 else 1.0
				slab_width -= edge_loss
				x_offset += surviving_side * edge_loss * 0.5
			if _rng.randf() < 0.1:
				## A missing strip reads as a chipped corner at the game's pixel scale.
				## Single-column paths must keep their full row depth; shortening
				## one slab exposes the grout bed across the entire road.
				var damage_ratio: float = (
					_rng.randf_range(0.12, 0.2)
					if columns == 1
					else _rng.randf_range(0.22, 0.32)
				)
				var damage_side: float = -1.0 if _rng.randf() < 0.5 else 1.0
				var damage_width: bool = (
					columns == 1
					or _rng.randf() < 0.7
					or row - last_length_damage_row <= 1
				)
				if damage_width:
					var missing_width: float = slab_width * damage_ratio
					slab_width -= missing_width
					x_offset += damage_side * missing_width * 0.5
				else:
					var missing_length: float = slab_length * damage_ratio
					slab_length -= missing_length
					z_offset += damage_side * missing_length * 0.5
					last_length_damage_row = row
			var slab_y: float = _rng.randf_range(0.010, 0.014)
			if _rng.randf() < 0.05:
				slab_y -= _rng.randf_range(0.008, 0.015)
			var slab_size := Vector3(
				slab_width,
				0.022,
				slab_length
			)
			var slab_position := Vector3(
				x + x_offset,
				slab_y,
				z + z_offset
			)
			var yaw: float = deg_to_rad(_rng.randf_range(-4.0, 4.0))
			var boss_proximity: float = clampf(inverse_lerp(-28.0, -48.0, z), 0.0, 1.0)
			var corruption_chance: float = lerpf(0.05, 0.13, boss_proximity)
			var is_corrupted: bool = _rng.randf() < corruption_chance
			var tone_index: int = (
				PATH_TONE_STEPS - 1
				if is_corrupted
				else _rng.randi_range(0, PATH_TONE_STEPS - 2)
			)
			var gloss_index: int = _rng.randi_range(0, PATH_GLOSS_STEPS - 1)
			var group_index: int = tone_index * PATH_GLOSS_STEPS + gloss_index
			var slab_basis := Basis(Vector3.UP, yaw).scaled(slab_size)
			transform_groups[group_index].append(Transform3D(slab_basis, slab_position))

	var shared_box := BoxMesh.new()
	shared_box.size = Vector3.ONE
	for group_index: int in transform_groups.size():
		var transforms: Array = transform_groups[group_index]
		if transforms.is_empty():
			continue
		var tone_index: int = group_index / PATH_GLOSS_STEPS
		var gloss_index: int = group_index % PATH_GLOSS_STEPS
		var is_corrupted_group: bool = tone_index == PATH_TONE_STEPS - 1
		var normal_tone_steps: int = PATH_TONE_STEPS - 1
		var tone: float = (
			0.0
			if is_corrupted_group
			else (tone_index / float(normal_tone_steps - 1) - 0.5) * 0.24
		)
		var gloss: float = (gloss_index / float(PATH_GLOSS_STEPS - 1) - 0.5) * 0.045
		var slab_tint := Color(
			clampf(PATH_TINT.r + tone, 0.0, 1.0),
			clampf(PATH_TINT.g + tone, 0.0, 1.0),
			clampf(PATH_TINT.b + tone, 0.0, 1.0)
		)
		if is_corrupted_group:
			slab_tint = PATH_TINT.lerp(Color(0.55, 0.62, 0.5, 1.0), 0.25)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = shared_box
		multimesh.instance_count = transforms.size()
		for transform_index: int in transforms.size():
			multimesh.set_instance_transform(transform_index, transforms[transform_index])
		var slab_batch := MultiMeshInstance3D.new()
		slab_batch.name = StringName("SlabsTone%dGloss%d" % [tone_index, gloss_index])
		slab_batch.multimesh = multimesh
		slab_batch.material_override = _get_terrain_material(
				ROUGH_GROUND_PIXEL_TEXTURE,
				Vector3.ONE,
				WET_PATH_ROUGHNESS + gloss * 0.15,
				slab_tint,
				PATH_TILE_METERS
		)
		path_root.add_child(slab_batch)


func _get_grout_material() -> StandardMaterial3D:
	if _grout_material != null:
		return _grout_material
	_grout_material = StandardMaterial3D.new()
	_grout_material.albedo_color = GROUT_COLOR
	_grout_material.roughness = 1.0
	_grout_material.metallic = 0.0
	## Recessed grout receives almost no direct light. A restrained emissive floor
	## keeps the post-process from quantizing it to pure black.
	_grout_material.emission_enabled = true
	_grout_material.emission = GROUT_COLOR
	_grout_material.emission_energy_multiplier = 0.3
	return _grout_material


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
		var texture_tint: Color = color.lerp(Color.WHITE, 0.5) if texture == ROUGH_GROUND_PIXEL_TEXTURE else Color.WHITE
		mesh_instance.material_override = _get_terrain_material(
			texture, size, WET_GROUND_ROUGHNESS, texture_tint
		)
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


func _build_depth_silhouettes() -> void:
	var silhouettes := Node3D.new()
	silhouettes.name = &"DepthSilhouettes"
	add_child(silhouettes)
	_add_organic_cliff(
		silhouettes, &"FarPillarLeft", Vector3(-8.4, 0.0, -10.5),
		Vector3(1.35, 6.8, 1.6), -5.0, 1.65
	)
	_add_organic_cliff(
		silhouettes, &"FarPillarRight", Vector3(8.9, 0.0, -32.5),
		Vector3(1.6, 8.2, 1.8), 7.0, 1.8
	)
	_add_organic_cliff(silhouettes, &"FarPillarRear", Vector3(-7.4, 0.0, -48.5), Vector3(1.8, 9.0, 2.0), -4.0, 1.9)


func _build_void_boundaries() -> void:
	var boundary := Node3D.new()
	boundary.name = &"VoidBoundary"
	add_child(boundary)
	_add_void_edge(
		boundary, &"ForegroundDissolve", Vector3(0.0, 0.065, 14.0),
		Vector2(15.0, 10.0), Vector2(0.0, 1.0), 10.3, 15.2
	)
	for index: int in CANYON_SEGMENTS.size():
		var segment: Array = CANYON_SEGMENTS[index]
		var center := Vector3(float(segment[0]), 0.0, float(segment[1]))
		var z_length: float = float(segment[2])
		var path_half_width: float = float(segment[3])
		var yaw: float = float(segment[4])
		var basis := Basis(Vector3.UP, deg_to_rad(yaw))
		for side: float in [-1.0, 1.0]:
			var side_name: String = "Right" if side > 0.0 else "Left"
			var outward: Vector3 = basis * Vector3(side, 0.0, 0.0)
			var inner_point: Vector3 = center + outward * (path_half_width - 0.35)
			var outer_point: Vector3 = center + outward * (path_half_width + 3.2)
			_add_void_edge(
				boundary,
				StringName("%sDissolve%d" % [side_name, index]),
				center + outward * (path_half_width + 2.35) + Vector3.UP * 0.07,
				Vector2(5.2, z_length + 3.0),
				Vector2(outward.x, outward.z),
				Vector2(inner_point.x, inner_point.z).dot(Vector2(outward.x, outward.z)),
				Vector2(outer_point.x, outer_point.z).dot(Vector2(outward.x, outward.z)),
				yaw
			)
	_add_void_edge(
		boundary, &"RearDissolve", Vector3(-2.0, 0.065, -53.0),
		Vector2(22.0, 10.0), Vector2(0.0, -1.0), 49.0, 54.0
	)
	## A broken cliff face hides the rectangular end of the starting floor.
	## Its uneven silhouette gives the foreground dissolve a physical source.
	var foreground_x_positions: Array[float] = [-6.6, -5.35, 5.35, 6.6]
	for index: int in foreground_x_positions.size():
		var height: float = _rng.randf_range(0.9, 1.35)
		var foreground_cliff := _add_organic_cliff(
			boundary,
			StringName("ForegroundCliff%d" % index),
			Vector3(foreground_x_positions[index], -height * 0.5, 12.95 + _rng.randf_range(-0.12, 0.15)),
			Vector3(1.05, height, 1.15),
			_rng.randf_range(-7.0, 7.0),
			0.58
		)
		foreground_cliff.add_to_group(&"camera_foreground")
		foreground_cliff.transparency = 0.18


func _add_void_edge(
	parent: Node3D,
	edge_name: StringName,
	position: Vector3,
	size: Vector2,
	fade_axis: Vector2,
	fade_start: float,
	fade_end: float,
	yaw: float = 0.0
) -> void:
	var edge := MeshInstance3D.new()
	edge.name = edge_name
	edge.position = position
	edge.rotation_degrees = Vector3(-90.0, yaw, 0.0)
	edge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = size
	edge.mesh = quad
	var material := ShaderMaterial.new()
	material.shader = VOID_EDGE_SHADER
	material.render_priority = 10
	material.set_shader_parameter(&"fade_axis", fade_axis)
	material.set_shader_parameter(&"fade_start", fade_start)
	material.set_shader_parameter(&"fade_end", fade_end)
	material.set_shader_parameter(&"noise_scale", 2.2)
	material.set_shader_parameter(&"noise_strength", 0.28)
	material.set_shader_parameter(&"pixel_world_size", 0.12)
	material.set_shader_parameter(&"edge_softness", 0.9)
	edge.material_override = material
	parent.add_child(edge)


func _add_block(
	parent: Node3D,
	block_name: StringName,
	center: Vector3,
	size: Vector3,
	color: Color,
	texture: Texture2D = null
) -> void:
	_make_decor_body(parent, block_name, center, size, color, texture)


## Sparse moss, crack and damp-stain decals interrupt long repeated floor runs.
## Their masks are deterministic procedural textures, keeping the prototype
## self-contained while allowing authored decal maps to replace them later.
func _build_ground_detail_decals() -> void:
	var details: Array = [
		[Vector3(-1.55, 0.08, 9.8), Vector2(1.4, 0.9), 0, -18.0],
		[Vector3(1.35, 0.08, 6.1), Vector2(1.1, 1.7), 2, 27.0],
		[Vector3(-5.8, 0.08, -5.7), Vector2(1.5, 1.0), 1, 8.0],
		[Vector3(-1.9, 0.08, -8.3), Vector2(1.7, 1.2), 0, 42.0],
		[Vector3(-1.8, 0.08, -14.4), Vector2(1.2, 1.8), 2, -31.0],
		[Vector3(1.7, 0.08, -20.2), Vector2(1.0, 1.5), 1, 16.0],
		[Vector3(0.6, 0.08, -25.1), Vector2(2.2, 1.4), 0, 11.0],
		[Vector3(7.2, 0.08, -28.8), Vector2(1.8, 1.2), 2, -24.0],
		[Vector3(0.2, 0.08, -34.6), Vector2(1.0, 1.5), 1, 35.0],
		[Vector3(2.2, 0.08, -43.1), Vector2(2.4, 1.6), 0, -12.0],
		[Vector3(-5.8, 0.08, -47.2), Vector2(1.8, 2.1), 2, 21.0],
	]
	var decal_root := Node3D.new()
	decal_root.name = &"GroundDetailDecals"
	add_child(decal_root)
	for index: int in details.size():
		var entry: Array = details[index]
		var decal := Decal.new()
		decal.name = StringName("GroundDetail%d" % index)
		decal.position = entry[0]
		var footprint: Vector2 = entry[1]
		decal.size = Vector3(footprint.x, 0.35, footprint.y)
		decal.rotation_degrees.y = float(entry[3])
		decal.texture_albedo = _get_ground_detail_texture(int(entry[2]))
		decal.modulate = (
			Color(0.34, 0.4, 0.36, 0.38)
			if index == 0
			else Color(1.0, 1.0, 1.0, 0.82)
		)
		decal.albedo_mix = 0.32 if index == 0 else 0.7
		decal.upper_fade = 0.22
		decal.lower_fade = 0.22
		decal.normal_fade = 0.55
		decal.distance_fade_enabled = true
		decal.distance_fade_begin = 28.0
		decal.distance_fade_length = 8.0
		decal_root.add_child(decal)


func _get_ground_detail_texture(detail_type: int) -> Texture2D:
	if _ground_detail_textures.has(detail_type):
		return _ground_detail_textures[detail_type]
	if detail_type == 0:
		_ground_detail_textures[detail_type] = MOSS_DECAL_TEXTURE
		return MOSS_DECAL_TEXTURE
	const TEXTURE_SIZE: int = 64
	var image := Image.create(TEXTURE_SIZE, TEXTURE_SIZE, false, Image.FORMAT_RGBA8)
	for y: int in range(TEXTURE_SIZE):
		for x: int in range(TEXTURE_SIZE):
			var uv := Vector2(float(x), float(y)) / float(TEXTURE_SIZE - 1)
			var centered: Vector2 = uv * 2.0 - Vector2.ONE
			var noise: float = fposmod(sin(float(x) * 12.9898 + float(y) * 78.233 + float(detail_type) * 37.71) * 43758.5453, 1.0)
			var color := Color(0.0, 0.0, 0.0, 0.0)
			if detail_type == 0:
				var moss_shape: float = 1.0 - smoothstep(0.35, 0.95, centered.length() + (noise - 0.5) * 0.42)
				color = Color(0.12, 0.22, 0.16, moss_shape * 0.56)
			elif detail_type == 1:
				var crack_line: float = absf(centered.y - sin(centered.x * 7.0) * 0.12)
				var branch: float = absf(centered.y + centered.x * 0.7 - 0.12)
				var branch_side: float = 1.0 if centered.x >= 0.0 else 0.0
				var crack_alpha: float = maxf(1.0 - smoothstep(0.018, 0.075, crack_line), (1.0 - smoothstep(0.015, 0.055, branch)) * branch_side)
				crack_alpha *= 1.0 - smoothstep(0.72, 1.0, absf(centered.x))
				color = Color(0.035, 0.045, 0.055, crack_alpha * 0.72)
			else:
				var ellipse: float = Vector2(centered.x * 0.82, centered.y * 1.18).length()
				var stain_alpha: float = 1.0 - smoothstep(0.48, 1.0, ellipse + (noise - 0.5) * 0.18)
				color = Color(0.09, 0.14, 0.19, stain_alpha * 0.34)
			image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	texture.resource_name = "ground_detail_%d" % detail_type
	_ground_detail_textures[detail_type] = texture
	return texture


func _get_material(color: Color) -> ShaderMaterial:
	var key: String = color.to_html()
	if _materials.has(key):
		return _materials[key]
	var material := ShaderMaterial.new()
	material.shader = ORGANIC_ROCK_SHADER
	material.set_shader_parameter(&"albedo_color", color)
	material.set_shader_parameter(&"use_albedo_texture", true)
	material.set_shader_parameter(&"albedo_texture", ROUGH_WALL_PIXEL_TEXTURE)
	material.set_shader_parameter(&"triplanar_scale", 1.0 / PIXEL_TERRAIN_TILE_METERS)
	material.set_shader_parameter(&"pixel_world_size", 0.075)
	material.set_shader_parameter(&"texture_strength", 0.72)
	material.set_shader_parameter(&"texture_contrast", 0.62)
	material.set_shader_parameter(&"roughness", 0.96)
	material.set_shader_parameter(&"strength", 0.0)
	_materials[key] = material
	return material


## Returns a cached ShaderMaterial that displaces box geometry into rough
## rock via per-vertex value noise (see organic_rock.gdshader). Used by the
## backdrop walls and rock piles so nothing reads as a clean box.
func _get_organic_rock_material(_size: Vector3, darken: float = 0.2) -> ShaderMaterial:
	var tone_step: float = roundf(darken * 4.0) * 0.25
	var key: String = "organic_%.2f" % tone_step
	if _organic_rock_materials.has(key):
		return _organic_rock_materials[key]
	var material := ShaderMaterial.new()
	material.shader = ORGANIC_ROCK_SHADER
	var base_color: Color = Color(0.18, 0.23, 0.25, 1.0).darkened(
		tone_step * 0.38 + 0.11
	)
	material.set_shader_parameter(&"albedo_color", base_color)
	material.set_shader_parameter(&"use_albedo_texture", true)
	material.set_shader_parameter(&"albedo_texture", ROUGH_WALL_PIXEL_TEXTURE)
	material.set_shader_parameter(&"triplanar_scale", 1.0 / PIXEL_TERRAIN_TILE_METERS)
	material.set_shader_parameter(&"pixel_world_size", 0.09)
	material.set_shader_parameter(&"texture_strength", 0.88)
	material.set_shader_parameter(&"texture_contrast", 0.68)
	material.set_shader_parameter(&"roughness", 0.97)
	material.set_shader_parameter(&"ao_strength", 0.78)
	material.set_shader_parameter(&"normal_strength", 0.72)
	material.set_shader_parameter(&"use_normal_texture", false)
	material.set_shader_parameter(&"derive_normal_from_albedo", true)
	material.set_shader_parameter(&"strength", 0.42)
	material.set_shader_parameter(&"horizontal_strength", 0.45)
	material.set_shader_parameter(&"frequency", 1.35)
	_organic_rock_materials[key] = material
	return material


## Shared stylized PBR stone material. It supports authored normal, roughness
## and AO maps, while retaining conservative scalar fallbacks for prototype
## textures that only provide albedo.
func _get_stylized_stone_material(
	texture: Texture2D,
	tint: Color,
	triplanar_scale: float
) -> ShaderMaterial:
	return HD2D_MATERIAL_LIBRARY.get_stone(texture, tint, triplanar_scale)


## Returns a cached world-space tiling material. Geometry size is deliberately
## excluded from the cache key because the shader derives UVs from world
## position; differently sized slabs can therefore share one material.
func _get_terrain_material(
	texture: Texture2D,
	_size: Vector3,
	roughness: float = WET_GROUND_ROUGHNESS,
	tint: Color = Color.WHITE,
	tile_meters: float = TERRAIN_TILE_METERS
) -> Material:
	var texture_id: String = texture.resource_path if not texture.resource_path.is_empty() else texture.resource_name
	var key: String = "%s|%.2f|%s|%.2f" % [texture_id, roughness, tint, tile_meters]
	if _terrain_materials.has(key):
		return _terrain_materials[key]
	if texture == ROUGH_GROUND_PIXEL_TEXTURE:
		var pixel_material := ShaderMaterial.new()
		pixel_material.shader = PIXEL_GROUND_SHADER
		pixel_material.set_shader_parameter(&"albedo_texture", texture)
		pixel_material.set_shader_parameter(&"tint", tint)
		pixel_material.set_shader_parameter(&"texture_scale", 0.5 / maxf(tile_meters, 0.01))
		pixel_material.set_shader_parameter(&"pixel_world_size", 0.075)
		pixel_material.set_shader_parameter(&"variant_scale", 1.13)
		pixel_material.set_shader_parameter(&"macro_scale", 0.1)
		pixel_material.set_shader_parameter(&"macro_strength", 0.075)
		pixel_material.set_shader_parameter(&"texture_contrast", 0.92)
		pixel_material.set_shader_parameter(&"roughness", roughness)
		_terrain_materials[key] = pixel_material
		return pixel_material
	var material := ShaderMaterial.new()
	material.shader = ORGANIC_ROCK_SHADER
	material.set_shader_parameter(&"albedo_color", tint)
	material.set_shader_parameter(&"use_albedo_texture", texture != null)
	material.set_shader_parameter(&"albedo_texture", texture)
	material.set_shader_parameter(&"texture_strength", 0.82)
	material.set_shader_parameter(&"texture_contrast", 0.62)
	material.set_shader_parameter(&"triplanar_scale", 1.0 / maxf(tile_meters, 0.01))
	material.set_shader_parameter(&"pixel_world_size", 0.0625)
	material.set_shader_parameter(&"roughness", roughness)
	material.set_shader_parameter(&"ao_strength", 0.72)
	material.set_shader_parameter(&"use_normal_texture", false)
	material.set_shader_parameter(&"derive_normal_from_albedo", texture != null)
	_terrain_materials[key] = material
	return material
