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
	_expect(floor_collision.shape is BoxShape3D, "greybox floor has primitive collision")
	_expect(floor_body.scale.is_equal_approx(Vector3.ONE), "greybox physics bodies are not scaled")

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
