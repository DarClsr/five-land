class_name GreyboxRoute
extends Node3D

const GROUND_COLOR: Color = Color(0.28, 0.26, 0.22, 1.0)
const BRIDGE_COLOR: Color = Color(0.34, 0.31, 0.25, 1.0)
const WALL_COLOR: Color = Color(0.47, 0.45, 0.39, 1.0)
const CORRUPTION_COLOR: Color = Color(0.19, 0.28, 0.25, 1.0)
const SEAL_COLOR: Color = Color(0.56, 0.45, 0.25, 1.0)

var _materials: Dictionary[String, StandardMaterial3D] = {}


func _ready() -> void:
	_build_deep_exit()
	_build_bridge()
	_build_xumen_gate()
	_build_burial_road()
	_build_seal_courtyard()
	_build_boss_approach()
	_build_boss_arena()


func has_section(section_name: StringName) -> bool:
	return has_node(NodePath(section_name))


func _build_deep_exit() -> void:
	var section: Node3D = _create_section(&"DeepExit", Vector3(0.0, -0.2, 8.0), Vector3(9.0, 0.4, 8.0))
	_add_side_rails(section, Vector3(0.0, 0.0, 8.0), Vector2(9.0, 8.0))
	_add_block(section, &"BrokenRearWall", Vector3(0.0, 0.75, 12.0), Vector3(9.0, 1.5, 0.5), WALL_COLOR)
	_add_block(section, &"InvertedSteleLeft", Vector3(-2.4, 1.35, 8.2), Vector3(0.8, 2.7, 0.8), WALL_COLOR)
	_add_block(section, &"InvertedSteleRight", Vector3(2.1, 1.8, 6.6), Vector3(0.9, 3.6, 0.9), WALL_COLOR)
	_add_label(section, "归墟出口", Vector3(0.0, 3.2, 9.5))


func _build_bridge() -> void:
	var section: Node3D = _create_section(&"OuterBridge", Vector3(0.0, -0.2, 0.0), Vector3(3.2, 0.4, 8.0), BRIDGE_COLOR)
	_add_side_rails(section, Vector3(0.0, 0.0, 0.0), Vector2(3.2, 8.0))
	_add_block(section, &"FractureMarker", Vector3(0.75, 0.08, 0.4), Vector3(1.3, 0.16, 1.8), CORRUPTION_COLOR)


func _build_xumen_gate() -> void:
	var section: Node3D = _create_section(&"XumenGate", Vector3(0.0, -0.2, -7.0), Vector3(10.0, 0.4, 6.0))
	_add_side_rails(section, Vector3(0.0, 0.0, -7.0), Vector2(10.0, 6.0))
	_add_block(section, &"GatePillarLeft", Vector3(-3.1, 2.2, -8.0), Vector3(1.2, 4.4, 1.2), WALL_COLOR)
	_add_block(section, &"GatePillarRight", Vector3(3.1, 2.2, -8.0), Vector3(1.2, 4.4, 1.2), WALL_COLOR)
	_add_block(section, &"GateLintel", Vector3(0.0, 4.0, -8.0), Vector3(7.4, 0.7, 1.0), WALL_COLOR)
	_add_label(section, "墟门", Vector3(0.0, 5.1, -8.0))


func _build_burial_road() -> void:
	var section: Node3D = _create_section(&"BurialRoad", Vector3(0.0, -0.2, -17.0), Vector3(5.0, 0.4, 14.0), BRIDGE_COLOR)
	_add_side_rails(section, Vector3(0.0, 0.0, -17.0), Vector2(5.0, 14.0))
	_add_block(section, &"OverturnedCart", Vector3(-1.25, 0.45, -15.5), Vector3(1.8, 0.9, 1.0), CORRUPTION_COLOR)
	_add_block(section, &"BurialStele", Vector3(1.5, 1.25, -20.0), Vector3(0.7, 2.5, 0.7), WALL_COLOR)
	_add_label(section, "送葬道", Vector3(0.0, 3.0, -18.0))


func _build_seal_courtyard() -> void:
	var section: Node3D = _create_section(&"SealCourtyard", Vector3(0.0, -0.2, -29.0), Vector3(12.0, 0.4, 10.0))
	_add_side_rails(section, Vector3(0.0, 0.0, -29.0), Vector2(12.0, 10.0))
	for index: int in range(3):
		var x_position: float = -3.0 + index * 3.0
		_add_block(section, StringName("SealPost%d" % (index + 1)), Vector3(x_position, 1.15, -29.5), Vector3(0.8, 2.3, 0.8), SEAL_COLOR)
	_add_block(section, &"GraveGateLeft", Vector3(-2.3, 1.8, -33.1), Vector3(1.2, 3.6, 1.1), WALL_COLOR)
	_add_block(section, &"GraveGateRight", Vector3(2.3, 1.8, -33.1), Vector3(1.2, 3.6, 1.1), WALL_COLOR)
	_add_label(section, "封印庭院", Vector3(0.0, 3.8, -29.0))


func _build_boss_approach() -> void:
	var section: Node3D = _create_section(&"GravePassage", Vector3(0.0, -0.2, -37.0), Vector3(3.5, 0.4, 6.0), BRIDGE_COLOR)
	_add_side_rails(section, Vector3(0.0, 0.0, -37.0), Vector2(3.5, 6.0))


func _build_boss_arena() -> void:
	var section: Node3D = _create_section(&"BossArena", Vector3(0.0, -0.2, -47.0), Vector3(16.0, 0.4, 14.0), CORRUPTION_COLOR)
	_add_side_rails(section, Vector3(0.0, 0.0, -47.0), Vector2(16.0, 14.0))
	_add_block(section, &"BurdenStoneLeft", Vector3(-5.2, 1.8, -47.5), Vector3(1.2, 3.6, 1.2), WALL_COLOR)
	_add_block(section, &"BurdenStoneRight", Vector3(5.0, 2.4, -45.5), Vector3(1.4, 4.8, 1.4), WALL_COLOR)
	_add_block(section, &"BurdenStoneRear", Vector3(0.0, 2.8, -52.0), Vector3(1.8, 5.6, 1.8), WALL_COLOR)
	_add_label(section, "负碑兽场地", Vector3(0.0, 5.0, -48.0))


func _create_section(
	section_name: StringName,
	floor_position: Vector3,
	floor_size: Vector3,
	color: Color = GROUND_COLOR
) -> Node3D:
	var section: Node3D = Node3D.new()
	section.name = section_name
	add_child(section)
	_add_block(section, &"Floor", floor_position, floor_size, color)
	return section


func _add_side_rails(parent: Node3D, center: Vector3, floor_size: Vector2) -> void:
	var rail_size: Vector3 = Vector3(0.35, 0.85, floor_size.y)
	var edge_x: float = floor_size.x * 0.5 - rail_size.x * 0.5
	_add_block(parent, &"RailLeft", center + Vector3(-edge_x, 0.425, 0.0), rail_size, WALL_COLOR)
	_add_block(parent, &"RailRight", center + Vector3(edge_x, 0.425, 0.0), rail_size, WALL_COLOR)


func _add_block(parent: Node3D, block_name: StringName, center: Vector3, size: Vector3, color: Color) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = block_name
	body.position = center
	parent.add_child(body)
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = &"Visual"
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = _get_material(color)
	body.add_child(mesh_instance)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = &"CollisionShape3D"
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = size
	collision.shape = box_shape
	body.add_child(collision)


func _add_label(parent: Node3D, label_text: String, label_position: Vector3) -> void:
	var label: Label3D = Label3D.new()
	label.name = &"AreaLabel"
	label.position = label_position
	label.text = label_text
	label.font_size = 42
	label.outline_size = 10
	label.modulate = Color(0.94, 0.85, 0.62, 1.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	parent.add_child(label)


func _get_material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if _materials.has(key):
		return _materials[key]
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	_materials[key] = material
	return material
