extends SceneTree

const PROLOGUE_CONTROLLER_SCRIPT = preload("res://scripts/world/prologue_greybox_controller.gd")
const GREYBOX_ROUTE_SCRIPT = preload("res://scripts/world/greybox_route.gd")

var failures: int = 0


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var level_scene: PackedScene = load("res://scenes/xumen_prologue_greybox.tscn") as PackedScene
	var level: PROLOGUE_CONTROLLER_SCRIPT = level_scene.instantiate() as PROLOGUE_CONTROLLER_SCRIPT
	root.add_child(level)
	await physics_frame
	await physics_frame

	var route: GREYBOX_ROUTE_SCRIPT = level.get_node("GreyboxRoute") as GREYBOX_ROUTE_SCRIPT
	for section_name: StringName in [
		&"DeepExit", &"XumenGate", &"BurialRoad", &"SealCourtyard", &"BossArena"
	]:
		_expect(route.has_section(section_name), "route contains %s" % section_name)

	var section_positions: Array[float] = [
		route.get_node("DeepExit/Floor").position.z,
		route.get_node("XumenGate/Floor").position.z,
		route.get_node("BurialRoad/Floor").position.z,
		route.get_node("SealCourtyard/Floor").position.z,
		route.get_node("BossArena/Floor").position.z,
	]
	for index: int in range(1, section_positions.size()):
		_expect(section_positions[index] < section_positions[index - 1], "sections progress along world -Z")

	var player: CharacterBody3D = level.player
	_expect(player.get_collision_layer_value(6), "player body uses its dedicated trigger layer")
	_expect(level.camera_rig.get_target() == player, "follow camera receives the player target")
	_expect(level.burial_road_enemy.get_target() == player, "burial road enemy receives the player target")
	level.burial_road_enemy.detection_range = 0.1

	var floor_body: StaticBody3D = route.get_node("DeepExit/Floor") as StaticBody3D
	var floor_collision: CollisionShape3D = floor_body.get_node("CollisionShape3D") as CollisionShape3D
	var floor_visual: MeshInstance3D = floor_body.get_node("Visual") as MeshInstance3D
	var floor_material: StandardMaterial3D = floor_visual.material_override as StandardMaterial3D
	_expect(floor_collision.shape is BoxShape3D, "greybox floor has primitive collision")
	_expect(floor_body.scale.is_equal_approx(Vector3.ONE), "greybox physics bodies are not scaled")
	_expect(floor_material.albedo_texture.resource_name == "deep_exit_soil.png", "deep exit uses realistic soil material")
	var wall_visual: MeshInstance3D = route.get_node("DeepExit/BrokenRearWallLeft/Visual") as MeshInstance3D
	var wall_material: StandardMaterial3D = wall_visual.material_override as StandardMaterial3D
	_expect(wall_material.albedo_texture.resource_name == "weathered_limestone.png", "deep exit stonework uses weathered limestone")
	_expect(wall_visual.mesh is ArrayMesh, "deep exit wall uses a broken profile mesh")
	var wall_collision: CollisionShape3D = route.get_node("DeepExit/BrokenRearWallLeft/CollisionShape3D") as CollisionShape3D
	_expect(wall_collision.shape is BoxShape3D, "deep exit detailed wall keeps simple collision")
	var stele_visual: MeshInstance3D = route.get_node("DeepExit/InvertedSteleLeft/Visual") as MeshInstance3D
	var tomb_visual: MeshInstance3D = route.get_node("DeepExit/ExitTombSlab/Visual") as MeshInstance3D
	_expect(stele_visual.mesh is ArrayMesh, "deep exit stele uses a damaged profile mesh")
	_expect(tomb_visual.mesh is ArrayMesh, "deep exit tombstone uses a damaged profile mesh")
	_expect(route.get_node_or_null("DeepExit/BrokenRearWall") == null, "deep exit rear wall leaves the center sightline open")
	_expect(route.get_node_or_null("BackdropWalls/FrontWall0") == null, "deep exit view has no foreground cliff cap")
	var atmosphere: Node3D = level.get_node("Atmosphere") as Node3D
	var first_lantern: Node3D = atmosphere.get_node("Lantern") as Node3D
	_expect(first_lantern.has_node("StonePart4"), "deep exit uses the layered stone lantern")
	var moon_pool: SpotLight3D = atmosphere.get_node("DeepExitMoonPool") as SpotLight3D
	_expect(moon_pool.shadow_enabled, "deep exit moon pool casts focused shadows")

	var boss_trigger: Area3D = level.get_node("Triggers/BossArena") as Area3D
	_expect(boss_trigger.get_collision_mask_value(6), "zone triggers scan only the player body layer")
	_expect(level.get_current_zone() == &"DeepExit", "prologue starts at the deep exit")

	player.global_position = Vector3(0.0, 0.0, -7.0)
	player.reset_physics_interpolation()
	for _frame: int in range(3):
		await physics_frame
	_expect(level.get_current_zone() == &"XumenGate", "entering the gate updates the current zone")
	_expect(level.objective_label.text.contains("送葬道"), "gate zone exposes the next route objective")

	player.global_position = Vector3(0.0, 0.0, -47.0)
	player.reset_physics_interpolation()
	for _frame: int in range(3):
		await physics_frame
	_expect(level.get_current_zone() == &"BossArena", "the full route reaches the boss arena")
	_expect(level.objective_label.text.contains("首领"), "boss arena exposes the greybox endpoint")

	level.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: prologue greybox")
	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
