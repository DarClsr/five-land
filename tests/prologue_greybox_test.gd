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
	var player_spawn_transform: Transform3D = player.global_transform
	var enemy_spawn_transform: Transform3D = level.burial_road_enemy.global_transform
	_expect(player.get_collision_layer_value(6), "player body uses its dedicated trigger layer")
	_expect(level.camera_rig.get_target() == player, "follow camera receives the player target")
	_expect(level.burial_road_enemy.get_target() == player, "burial road enemy receives the player target")
	level.burial_road_enemy.detection_range = 0.1

	var floor_body: StaticBody3D = route.get_node("DeepExit/Floor") as StaticBody3D
	var floor_collision: CollisionShape3D = floor_body.get_node("CollisionShape3D") as CollisionShape3D
	var floor_visual: MeshInstance3D = floor_body.get_node("Visual") as MeshInstance3D
	var floor_material: ShaderMaterial = floor_visual.material_override as ShaderMaterial
	_expect(floor_collision.shape is BoxShape3D, "greybox floor has primitive collision")
	_expect((floor_collision.shape as BoxShape3D).size.x >= 11.0, "deep exit opens into a wider playable chamber")
	_expect(floor_body.scale.is_equal_approx(Vector3.ONE), "greybox physics bodies are not scaled")
	_expect(
		(floor_material.get_shader_parameter(&"albedo_texture") as Texture2D).resource_path
			== "res://assets/textures/terrain/cave_flagstone_64.png",
		"deep exit uses the rough pixel ground material"
	)
	_expect(
		floor_material.get_shader_parameter(&"roughness") >= 0.92,
		"rough pixel ground suppresses smooth highlights"
	)
	_expect(
		floor_material.get_shader_parameter(&"macro_strength") > 0.0,
		"pixel ground blends a low-frequency anti-tiling variant"
	)
	var exit_path := route.get_node("DeepExit/ExitPath") as Node3D
	_expect(exit_path.get_child_count() <= 15, "flagstone path batches tone and gloss variants")
	for slab_batch: Node in exit_path.get_children():
		_expect(slab_batch is MultiMeshInstance3D, "flagstone batches render through MultiMesh")
	var grout_bed := route.get_node("DeepExit/ExitPathGroutBed") as MeshInstance3D
	var grout_material := grout_bed.material_override as StandardMaterial3D
	_expect(grout_material.emission_enabled, "recessed grout keeps a visible shadow floor")
	_expect(
		grout_material.albedo_color.get_luminance() >= 0.18,
		"flagstone grout does not quantize to pure black"
	)
	var wall_visual: MeshInstance3D = route.get_node("DeepExit/BrokenRearWallLeft/Visual") as MeshInstance3D
	var wall_material: ShaderMaterial = wall_visual.material_override as ShaderMaterial
	_expect(wall_material != null, "deep exit stonework uses the stylized triplanar shader")
	_expect(
		wall_material.get_shader_parameter(&"derive_normal_from_albedo") == true,
		"prototype stone derives carved normals from its triplanar albedo"
	)
	_expect(
		wall_material.get_shader_parameter(&"roughness") >= 0.9,
		"stylized stone remains matte instead of plastic"
	)
	_expect(wall_visual.mesh is ArrayMesh, "deep exit wall uses a broken profile mesh")
	var wall_collision: CollisionShape3D = route.get_node("DeepExit/BrokenRearWallLeft/CollisionShape3D") as CollisionShape3D
	_expect(wall_collision.shape is BoxShape3D, "deep exit detailed wall keeps simple collision")
	var stele_visual: MeshInstance3D = route.get_node("DeepExit/InvertedSteleLeft/Visual") as MeshInstance3D
	var tomb_visual: MeshInstance3D = route.get_node("DeepExit/ExitTombSlab/Visual") as MeshInstance3D
	_expect(stele_visual.mesh is ArrayMesh, "deep exit stele uses a damaged profile mesh")
	_expect(tomb_visual.mesh is ArrayMesh, "deep exit tombstone uses a damaged profile mesh")
	var gate_tomb_visual: MeshInstance3D = route.get_node("XumenGate/GateTombLeftSlab/Visual") as MeshInstance3D
	_expect(gate_tomb_visual.mesh is ArrayMesh, "route tombstones use chipped profile meshes")
	var gate_tomb_material := gate_tomb_visual.material_override as ShaderMaterial
	_expect(
		gate_tomb_material.get_shader_parameter(&"derive_normal_from_albedo") == true,
		"tombstones derive carved normals from the new pixel albedo"
	)
	var canyon_visual: MeshInstance3D = route.get_node("BackdropWalls/CanyonRight0_0") as MeshInstance3D
	var canyon_material: ShaderMaterial = canyon_visual.material_override as ShaderMaterial
	var canyon_texture: Texture2D = canyon_material.get_shader_parameter(&"albedo_texture") as Texture2D
	_expect(
		canyon_texture.resource_path == "res://assets/textures/terrain/cave_rock_wall_64.png",
		"canyon walls use the rough pixel wall texture"
	)
	_expect(route.get_node_or_null("DeepExit/BrokenRearWall") == null, "deep exit rear wall leaves the center sightline open")
	_expect(route.get_node_or_null("BackdropWalls/FrontWall0") == null, "deep exit view has no foreground cliff cap")
	var atmosphere: Node3D = level.get_node("Atmosphere") as Node3D
	var first_lantern: Node3D = atmosphere.get_node("Lantern") as Node3D
	_expect(first_lantern.has_node("StonePart4"), "deep exit uses the layered stone lantern")
	var lantern_stone: MeshInstance3D = first_lantern.get_node("StonePart0") as MeshInstance3D
	_expect(
		lantern_stone.material_override is ShaderMaterial,
		"stone lanterns share the stylized triplanar material"
	)
	var lantern_light: OmniLight3D = first_lantern.get_child(first_lantern.get_child_count() - 1) as OmniLight3D
	_expect(is_equal_approx(lantern_light.omni_attenuation, 2.0), "lantern light uses inverse-square attenuation")
	_expect(lantern_light.omni_range >= 10.8, "lantern light creates a broad warm pool")
	_expect(lantern_light.light_size >= 0.4, "lantern light has a broad soft-shadow source")
	var lantern_emissive: MeshInstance3D = first_lantern.get_node("StonePart3") as MeshInstance3D
	var lantern_emissive_material := lantern_emissive.material_override as ShaderMaterial
	_expect(
		lantern_emissive_material != null
			and float(lantern_emissive_material.get_shader_parameter(&"emission_energy")) >= 4.0
			and Vector2(lantern_emissive_material.get_shader_parameter(&"grid_cells")).x >= 4.0,
		"lantern housing uses a pixel grid with HDR emission"
	)
	var dust: GPUParticles3D = atmosphere.get_node("Dust") as GPUParticles3D
	_expect(dust.amount >= 120, "fine ambient dust density is doubled")
	var dust_material := dust.material_override as StandardMaterial3D
	_expect(dust_material.proximity_fade_enabled, "ambient particles use soft depth fading")
	var crevice_shaft: SpotLight3D = atmosphere.get_node("DeepExitCreviceShaft") as SpotLight3D
	_expect(crevice_shaft.shadow_enabled, "visible wall crevice casts the focused shaft")
	_expect(atmosphere.has_node("CaveLightCrevice/EmissiveSeam"), "light shaft has a visible emissive rock seam source")
	var cold_fill: OmniLight3D = atmosphere.get_node("ColdShadowFill") as OmniLight3D
	_expect(cold_fill.light_energy >= 0.1 and cold_fill.light_energy <= 0.2, "dark side has a restrained cold fill")
	atmosphere.call(&"_update_lantern_visibility")
	var visible_lantern_lights: int = 0
	for child: Node in atmosphere.get_children():
		if child.name == &"Lantern":
			var candidate := child.get_child(child.get_child_count() - 1) as OmniLight3D
			visible_lantern_lights += 1 if candidate.visible else 0
	_expect(visible_lantern_lights > 0 and visible_lantern_lights < 16, "distant lantern lights are culled around the camera")
	var height_fog: FogVolume = atmosphere.get_node("BurialRoadHeightFog") as FogVolume
	_expect(height_fog.material is ShaderMaterial, "burial road uses animated local height fog")

	var world_environment: WorldEnvironment = level.get_node("WorldEnvironment") as WorldEnvironment
	var environment: Environment = world_environment.environment
	_expect(environment.ssao_enabled, "Forward+ environment enables SSAO contact shading")
	_expect(not environment.ssr_enabled, "matte pixel cave does not spend GPU time on SSR")
	_expect(environment.ambient_light_energy >= 0.11, "cold ambient fill prevents dead-black shadows")
	_expect(environment.tonemap_mode == 4, "environment uses AgX color mapping")
	_expect(not environment.adjustment_enabled, "color grading is consolidated into the HD-2D post pass")
	var moon_key := level.get_node("MoonKey") as DirectionalLight3D
	_expect(moon_key.directional_shadow_max_distance >= 80.0, "directional shadows cover the complete route")
	_expect(route.has_node("GroundDetailDecals/GroundDetail0"), "ground receives moss, crack and damp decals")
	_expect(route.has_node("VoidBoundary/ForegroundDissolve"), "foreground floor edge dissolves into the void")
	_expect(route.has_node("VoidBoundary/LeftDissolve0"), "left floor edge dissolves into boundary fog")
	_expect(route.has_node("VoidBoundary/RightDissolve0"), "right floor edge dissolves into boundary fog")
	_expect(route.has_node("VoidBoundary/RearDissolve"), "rear route edge dissolves into boundary fog")
	_expect(route.has_node("VoidBoundary/ForegroundCliff0"), "foreground cliff hides the rectangular floor end")
	_expect(route.has_node("NavigationBoundaries/LeftWall0"), "route has a solid left gameplay boundary")
	_expect(route.has_node("NavigationBoundaries/RightWall1"), "bridge has a solid right gameplay boundary")
	_expect(route.has_node("NavigationBoundaries/LeftShoulder0"), "wide rooms close around narrow corridor seams")
	_expect(route.has_node("NavigationBoundaries/ForegroundCap"), "foreground edge blocks the player capsule")
	var boundary_shape := route.get_node(
		"NavigationBoundaries/ForegroundCap/CollisionShape3D"
	) as CollisionShape3D
	_expect(boundary_shape.shape is BoxShape3D, "map boundaries use stable primitive collision")
	var edge_collision: KinematicCollision3D = player.move_and_collide(
		Vector3(0.0, 0.0, 5.0), true
	)
	_expect(edge_collision != null, "player sweep cannot cross the foreground map edge")
	_expect(route.has_node("DepthSilhouettes/FarPillarLeft"), "far rock silhouettes reinforce depth")
	var camera: Camera3D = level.get_node("FollowCameraRig/Camera3D") as Camera3D
	var camera_bounds: Rect2 = level.camera_rig.get_movement_bounds()
	_expect(
		camera_bounds.is_equal_approx(PrologueGreyboxController.CAMERA_BOUNDS[&"DeepExit"]),
		"camera starts inside the authored deep-exit bounds"
	)
	player.global_position = Vector3(0.0, 0.0, 5.0)
	player.reset_physics_interpolation()
	for _frame: int in range(12):
		await process_frame
	_expect(
		absf(level.camera_rig.global_position.z - player.global_position.z) < 0.35,
		"distance-adaptive camera catches up smoothly during sustained movement"
	)
	player.global_transform = player_spawn_transform
	player.reset_physics_interpolation()
	level.camera_rig.set_target(player, true)
	var camera_attributes := camera.attributes as CameraAttributesPractical
	_expect(camera_attributes.exposure_multiplier >= 1.0, "cave exposure floor stays at or above neutral")
	_expect(not camera_attributes.auto_exposure_enabled, "cave exposure stays stable without brightness pumping")
	_expect(camera_attributes.dof_blur_near_enabled, "diorama DOF softens the foreground")
	_expect(camera_attributes.dof_blur_far_enabled, "diorama DOF softens the distant background")

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
	_expect(
		level.camera_rig.get_movement_bounds().is_equal_approx(
			PrologueGreyboxController.CAMERA_BOUNDS[&"BossArena"]
		),
		"boss arena switches the camera to its authored safe bounds"
	)
	_expect(level.objective_label.text.contains("首领"), "boss arena exposes the greybox endpoint")

	level.call(&"_on_attack_landed", 1, 1.0, 0, 0, 0)
	_expect(not player.is_physics_processing(), "hit stop freezes the combat actors locally")
	_expect(not paused, "hit stop leaves atmosphere and camera processing active")
	await create_timer(0.08).timeout
	_expect(player.is_physics_processing(), "local hit stop restores actor processing")
	player.health_component.take_damage(25)
	level.burial_road_enemy.health_component.take_damage(10)
	level.call(&"_reset_encounter")
	_expect(
		level.camera_rig.global_position.is_equal_approx(player.global_position),
		"retry snaps the follow camera to the restored player position"
	)
	_expect(player.global_transform.is_equal_approx(player_spawn_transform), "retry restores the player spawn without scene reload")
	_expect(level.burial_road_enemy.global_transform.is_equal_approx(enemy_spawn_transform), "retry restores the enemy spawn")
	_expect(player.health_component.current_health == player.health_component.max_health, "retry restores player health")
	_expect(level.burial_road_enemy.health_component.current_health == level.burial_road_enemy.health_component.max_health, "retry restores enemy health")

	level.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: prologue greybox")
	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
