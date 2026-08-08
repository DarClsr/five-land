extends SceneTree

const PROLOGUE_CONTROLLER_SCRIPT = preload("res://scripts/world/prologue_greybox_controller.gd")
const GREYBOX_ROUTE_SCRIPT = preload("res://scripts/world/greybox_route.gd")
const BOSS_GATE_CONTROLLER_SCRIPT = preload("res://scripts/world/boss_gate_controller.gd")

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
		&"DeepExit", &"XumenGate", &"SmallBranch", &"BurialRoad",
		&"SealCourtyard", &"MechanismBranch", &"BossArena"
	]:
		_expect(route.has_section(section_name), "route contains %s" % section_name)

	var section_positions: Array[Vector3] = [
		(route.get_node("DeepExit/Floor") as Node3D).position,
		(route.get_node("XumenGate/Floor") as Node3D).position,
		(route.get_node("BurialRoad/Floor") as Node3D).position,
		(route.get_node("SealCourtyard/Floor") as Node3D).position,
		(route.get_node("BossArena/Floor") as Node3D).position,
	]
	for index: int in range(1, section_positions.size()):
		_expect(section_positions[index].z < section_positions[index - 1].z, "sections progress along world -Z")
	_expect(
		section_positions[1].x < -3.5
			and section_positions[3].x > 3.5
			and section_positions[4].x < -1.5,
		"major rooms alternate laterally instead of forming one vertical corridor"
	)
	var bridge_floor := route.get_node("OuterBridge/Floor") as StaticBody3D
	var burial_floor := route.get_node("BurialRoad/Floor") as StaticBody3D
	var passage_floor := route.get_node("GravePassage/Floor") as StaticBody3D
	var boss_gate := route.get_node("GravePassage/BossGate") as StaticBody3D
	var gate_controller: BOSS_GATE_CONTROLLER_SCRIPT = boss_gate as BOSS_GATE_CONTROLLER_SCRIPT
	var boss_gate_collision := boss_gate.get_node("CollisionShape3D") as CollisionShape3D
	var pixel_props := {
		"SmallBranch/MemoryStele/Visual": "res://assets/props/xumen/pixel/xumen_echo_stele_v1.png",
		"SmallBranch/SoulfireAltar": "res://assets/props/xumen/pixel/xumen_soulfire_altar_v1.png",
		"SmallBranch/RuneFragments": "res://assets/props/xumen/pixel/xumen_rune_fragments_v1.png",
		"MechanismBranch/BranchSeal/Visual": "res://assets/props/xumen/pixel/xumen_earth_mechanism_core_v1.png",
		"MechanismBranch/Counterweight/Visual": "res://assets/props/xumen/pixel/xumen_chain_counterweight_v1.png",
		"MechanismBranch/ChainBrazier": "res://assets/props/xumen/pixel/xumen_chain_brazier_v1.png",
		"SealCourtyard/SealPost1/Visual": "res://assets/props/xumen/pixel/xumen_seal_pillar_v1.png",
		"SealCourtyard/GuideLantern": "res://assets/props/xumen/pixel/xumen_guide_lantern_v1.png",
		"GravePassage/BossGate/Door/LeftHalf": "res://assets/props/xumen/pixel/xumen_boss_seal_gate_v1.png",
	}
	for visual_path: String in pixel_props:
		var prop_visual := route.get_node(visual_path) as Sprite3D
		_expect(prop_visual != null, "%s exists" % visual_path)
		var expected_path: String = pixel_props[visual_path]
		var texture_path: String = ""
		if prop_visual.texture is AtlasTexture:
			var atlas := prop_visual.texture as AtlasTexture
			texture_path = atlas.atlas.resource_path if atlas.atlas != null else ""
		else:
			texture_path = prop_visual.texture.resource_path
		_expect(texture_path == expected_path, "%s uses its authored pixel prop" % visual_path)
		_expect(prop_visual.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, "%s faces the fixed HD-2D camera" % visual_path)
		_expect(prop_visual.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "%s keeps nearest pixel filtering" % visual_path)
		_expect(prop_visual.shaded, "%s receives authored local lights" % visual_path)
		_expect(
			prop_visual.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED,
			"%s casts an alpha-tested contact shadow" % visual_path
		)
	_expect(boss_gate.visible, "boss gate starts visible")
	_expect(not boss_gate_collision.disabled, "boss gate starts with solid collision")
	_expect((route.get_node("SmallBranch/Floor") as Node3D).position.x < -4.0, "small branch occupies the gate side wing")
	_expect((route.get_node("MechanismBranch/Floor") as Node3D).position.x > 4.0, "mechanism branch occupies the courtyard side wing")
	_expect(route.get_node_or_null("SealCourtyard/CourtyardTree") == null, "courtyard has no tall tree crossing the action layer")
	_expect(route.has_node("SealCourtyard/LeftGuideLantern"), "expanded left wing has a readable light landmark")
	_expect(route.has_node("SealCourtyard/LeftEchoStele"), "expanded left wing has an exploration landmark")
	_expect(route.has_node("SealCourtyard/EntranceMarkerLeft"), "courtyard entrance widens through a ruined threshold")
	_expect(route.get_node_or_null("SealCourtyard/CourtyardCrack") == null, "courtyard no longer has one solid black crack bar")
	for crack_index: int in range(1, 4):
		var crack := route.get_node("SealCourtyard/CourtyardCrack%d" % crack_index)
		_expect(crack is MeshInstance3D and not crack is CollisionObject3D, "courtyard crack %d is short visual detail only" % crack_index)
	for seal_index: int in range(1, 4):
		var shadow := route.get_node("SealCourtyard/SealPost%d/ContactShadow" % seal_index) as MeshInstance3D
		_expect(shadow.mesh is CylinderMesh, "seal post %d has a grounded contact shadow" % seal_index)
		_expect(shadow.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "contact shadow does not double-cast lighting")
	var expected_room_widths := {
		"DeepExit": 14.2,
		"XumenGate": 15.6,
		"SealCourtyard": 18.2,
		"BossArena": 23.4,
	}
	for room_name: String in expected_room_widths:
		var room_floor := route.get_node("%s/Floor" % room_name) as StaticBody3D
		var room_shape := room_floor.get_node("CollisionShape3D") as CollisionShape3D
		_expect(
			is_equal_approx((room_shape.shape as BoxShape3D).size.x, expected_room_widths[room_name]),
			"%s gains real horizontal floor area" % room_name
		)
		_expect(room_floor.scale.is_equal_approx(Vector3.ONE), "%s floor tiles are not scaled" % room_name)
	var small_branch_shape := (route.get_node("SmallBranch/Floor/CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	var mechanism_branch_shape := (route.get_node("MechanismBranch/Floor/CollisionShape3D") as CollisionShape3D).shape as BoxShape3D
	_expect(small_branch_shape.size.x >= 5.0, "small branch extends deeper with original-size terrain sampling")
	_expect(mechanism_branch_shape.size.x >= 5.0, "mechanism branch extends deeper with original-size terrain sampling")
	_expect(absf(bridge_floor.rotation_degrees.y - 30.0) < 0.1, "outer bridge advances on a thirty-degree diagonal")
	_expect(absf(burial_floor.rotation_degrees.y + 30.0) < 0.1, "burial road reverses the diagonal")
	_expect(absf(passage_floor.rotation_degrees.y - 50.0) < 0.1, "boss passage turns back across the composition")
	_expect(route.has_node("BurialRoad/RoadPathFrame/RoadPath"), "diagonal burial road keeps its flagstone guide")
	var route_samples: Array[Vector3] = [
		Vector3(0.0, 0.0, 8.0),
		Vector3(0.0, 0.0, 4.0),
		Vector3(-2.0, 0.0, 0.0),
		Vector3(-4.0, 0.0, -4.0),
		Vector3(-4.0, 0.0, -8.0),
		Vector3(-3.0, 0.0, -11.5),
		Vector3(0.0, 0.0, -16.5),
		Vector3(3.0, 0.0, -21.5),
		Vector3(4.0, 0.0, -27.0),
		Vector3(4.0, 0.0, -31.0),
		Vector3(1.0, 0.0, -34.0),
		Vector3(-2.0, 0.0, -37.0),
		Vector3(-2.0, 0.0, -44.0),
	]
	var space_state: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	for sample: Vector3 in route_samples:
		var ray := PhysicsRayQueryParameters3D.create(
			sample + Vector3.UP * 2.0,
			sample + Vector3.DOWN * 2.0
		)
		var has_floor: bool = false
		for _hit_index: int in range(8):
			var hit: Dictionary = space_state.intersect_ray(ray)
			if hit.is_empty():
				break
			var collider := hit.get("collider") as CollisionObject3D
			if collider != null and collider.name == &"Floor":
				has_floor = true
				break
			if collider == null:
				break
			ray.exclude = ray.exclude + [collider.get_rid()]
		_expect(has_floor, "walkable floor covers route sample %s" % sample)

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
	_expect((floor_collision.shape as BoxShape3D).size.x >= 14.0, "deep exit opens into the expanded playable chamber")
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
	_expect(canyon_visual.transparency >= 0.4, "foreground canyon walls keep the route readable")
	_expect((canyon_visual.mesh as BoxMesh).size.y <= 1.7, "camera-facing canyon walls stay below the action layer")
	var courtyard_vein := route.get_node("SealCourtyard/VeinCourtyard2")
	_expect(courtyard_vein is MeshInstance3D, "earth veins render as flat pixel meshes")
	_expect((courtyard_vein as MeshInstance3D).mesh is QuadMesh, "earth veins use a floor-only quad")
	_expect(absf((courtyard_vein as MeshInstance3D).rotation_degrees.x + 90.0) < 0.1, "earth veins face only the floor")
	_expect(not courtyard_vein is CollisionObject3D, "visual earth veins do not add invisible collision")
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
	_expect(
		lantern_light.omni_range >= 6.5 and lantern_light.omni_range <= 8.0,
		"lantern light keeps a restrained local warm pool"
	)
	_expect(lantern_light.light_size >= 0.4, "lantern light has a broad soft-shadow source")
	var lantern_emissive: MeshInstance3D = first_lantern.get_node("StonePart3") as MeshInstance3D
	var lantern_emissive_material := lantern_emissive.material_override as ShaderMaterial
	_expect(
		lantern_emissive_material != null
			and float(lantern_emissive_material.get_shader_parameter(&"emission_energy")) <= 3.5
			and Vector2(lantern_emissive_material.get_shader_parameter(&"grid_cells")).x >= 4.0,
		"lantern housing keeps a pixel grid without an overexposed core"
	)
	var flame_sparks := first_lantern.get_node("FlameSparks") as GPUParticles3D
	_expect(flame_sparks.amount <= 8, "each torch keeps a small fixed spark budget")
	var dust: GPUParticles3D = atmosphere.get_node("Dust") as GPUParticles3D
	_expect(dust.amount <= 96, "ambient dust stays within the low-end particle budget")
	var dust_material := dust.material_override as StandardMaterial3D
	_expect(dust_material.proximity_fade_enabled, "ambient particles use soft depth fading")
	var crevice_shaft: SpotLight3D = atmosphere.get_node("DeepExitCreviceShaft") as SpotLight3D
	_expect(crevice_shaft.shadow_enabled, "visible wall crevice casts the focused shaft")
	_expect(atmosphere.has_node("CaveLightCrevice/EmissiveSeam"), "light shaft has a visible emissive rock seam source")
	var cold_fill: OmniLight3D = atmosphere.get_node("ColdShadowFill") as OmniLight3D
	_expect(cold_fill.light_energy >= 0.1 and cold_fill.light_energy <= 0.2, "dark side has a restrained cold fill")
	atmosphere.call(&"_update_lantern_visibility")
	var visible_lantern_lights: int = 0
	var shadowed_lantern_lights: int = 0
	var nearest_lit_distance: float = INF
	var furthest_lit_distance: float = -INF
	var lantern_camera: Camera3D = level.get_node("FollowCameraRig/Camera3D") as Camera3D
	for child: Node in atmosphere.get_children():
		if child.get_class() != "Node3D" or child.get_child_count() == 0:
			continue
		var candidate := child.get_child(child.get_child_count() - 1) as OmniLight3D
		if candidate == null or not bool(candidate.get_meta(&"lit", true)):
			continue
		var distance: float = child.global_position.distance_to(lantern_camera.global_position)
		if candidate.visible:
			visible_lantern_lights += 1
			shadowed_lantern_lights += 1 if candidate.shadow_enabled else 0
			nearest_lit_distance = minf(nearest_lit_distance, distance)
		else:
			furthest_lit_distance = maxf(furthest_lit_distance, distance)
	_expect(visible_lantern_lights > 0 and visible_lantern_lights <= 5, "distant lantern lights respect the active-light cap")
	_expect(shadowed_lantern_lights <= 3, "dynamic torch shadows respect the shadow budget")
	_expect(nearest_lit_distance < furthest_lit_distance, "nearest lanterns win the active-light cap over array order")
	_expect(get_nodes_in_group(&"rune_source").size() == 6, "interactive seals share one cyan rune language")
	var gate_guidance: Node3D = atmosphere.get_node_or_null("BossGateGuidance") as Node3D
	_expect(gate_guidance != null, "boss gate keeps a dedicated guidance group")
	if gate_guidance != null:
		var guide_light_count: int = 0
		for child: Node in gate_guidance.get_children():
			if child is OmniLight3D:
				guide_light_count += 1
		_expect(guide_light_count == 2, "the dark passage flanks the gate with two guide lights")
		var front_glow := gate_guidance.get_node_or_null("GlowFront") as MeshInstance3D
		_expect(front_glow != null and front_glow.mesh is QuadMesh, "the gate approach keeps a rune glow pool")
	var height_fog: FogVolume = atmosphere.get_node("BurialRoadHeightFog") as FogVolume
	_expect(height_fog.material is ShaderMaterial, "burial road uses animated local height fog")
	var cave_life := atmosphere.get_node("CaveLife") as Node3D
	_expect(cave_life.get_node("SpiderWeb1") is MeshInstance3D, "courtyard has a lightweight procedural spider web")
	_expect((cave_life.get_node("SpiderWeb1") as MeshInstance3D).mesh is ImmediateMesh, "spider web uses line geometry instead of a large texture")
	_expect(cave_life.get_node("SpiderWeb3") is MeshInstance3D, "side branch has its own spider web")
	for spider_index: int in range(1, 3):
		var spider := cave_life.get_node("Spider%d" % spider_index) as Node3D
		_expect(spider.has_node("Body") and spider.has_node("Head"), "decorative spider %d has a readable tiny silhouette" % spider_index)
		_expect(spider.find_children("*", "CollisionObject3D", true, false).is_empty(), "decorative spider %d has no gameplay collision" % spider_index)

	var world_environment: WorldEnvironment = level.get_node("WorldEnvironment") as WorldEnvironment
	var environment: Environment = world_environment.environment
	_expect(environment.ssao_enabled, "Forward+ environment enables SSAO contact shading")
	_expect(not environment.ssr_enabled, "matte pixel cave does not spend GPU time on SSR")
	_expect(environment.ambient_light_energy >= 0.19, "cold ambient fill keeps the courtyard readable")
	_expect(environment.fog_density <= 0.005, "global fog does not wash the cave into flat grey")
	_expect(environment.glow_bloom <= 0.12, "bloom stays below the restrained pixel-art limit")
	_expect(environment.glow_hdr_threshold >= 1.0, "only deliberate HDR accents enter glow")
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
	var foreground_cliff := route.get_node("VoidBoundary/ForegroundCliff0") as MeshInstance3D
	_expect(
		foreground_cliff.is_in_group(&"camera_foreground")
			and foreground_cliff.transparency >= 0.15,
		"foreground framing can fade without becoming a solid black wall"
	)
	_expect(route.has_node("NavigationBoundaries/LeftWall0"), "route has a solid left gameplay boundary")
	_expect(route.has_node("NavigationBoundaries/RightWall1"), "bridge has a solid right gameplay boundary")
	_expect(route.has_node("NavigationBoundaries/DeepExitBack0"), "wide rooms close around diagonal doorways")
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
	_expect(route.has_node("DepthSilhouettes/OuterLeftNear"), "outer cave mass replaces the visible black void")
	_expect(route.has_node("DepthSilhouettes/OuterRightDeep"), "outer cave mass continues around the deep route")
	_expect(route.has_node("DepthSilhouettes/CourtyardOuterShelf"), "courtyard entrance void has a non-playable cave shelf")
	var camera: Camera3D = level.get_node("FollowCameraRig/Camera3D") as Camera3D
	var camera_bounds: Rect2 = level.camera_rig.get_movement_bounds()
	_expect(level.camera_rig.foreground_rest_transparency >= 0.85, "idle foreground framing exposes the expanded floor")
	_expect(
		camera_bounds.is_equal_approx(PrologueGreyboxController.CAMERA_BOUNDS[&"DeepExit"]),
		"camera starts inside the authored deep-exit bounds"
	)
	player.global_position = Vector3(0.0, 0.0, 5.0)
	player.reset_physics_interpolation()
	for _frame: int in range(12):
		await process_frame
	_expect(
		absf(level.camera_rig.global_position.z - player.global_position.z) < 0.75,
		"camera settles into its forward-biased exploration composition"
	)
	_expect(
		level.camera_rig.get_look_ahead_offset().dot(
			PrologueGreyboxController.ZONE_DIRECTIONS[&"DeepExit"]
		) > 0.35,
		"idle composition reserves screen space along the prologue route"
	)
	player.global_transform = player_spawn_transform
	player.reset_physics_interpolation()
	level.camera_rig.set_target(player, true)
	var camera_attributes := camera.attributes as CameraAttributesPractical
	_expect(camera_attributes.exposure_multiplier >= 1.05, "cave action layer stays readable")
	_expect(not camera_attributes.auto_exposure_enabled, "cave exposure stays stable without brightness pumping")
	_expect(camera_attributes.dof_blur_near_enabled, "diorama DOF softens the foreground")
	_expect(camera_attributes.dof_blur_far_enabled, "diorama DOF softens the distant background")

	var boss_trigger: Area3D = level.get_node("Triggers/BossArena") as Area3D
	var burial_trigger: Area3D = level.get_node("Triggers/BurialRoad") as Area3D
	_expect(boss_trigger.get_collision_mask_value(6), "zone triggers scan only the player body layer")
	_expect(absf(rad_to_deg(burial_trigger.rotation.y) + 30.0) < 0.1, "burial trigger follows the diagonal road")
	_expect(level.get_current_zone() == &"DeepExit", "prologue starts at the deep exit")

	player.global_position = Vector3(-4.0, 0.0, -7.0)
	player.reset_physics_interpolation()
	for _frame: int in range(3):
		await physics_frame
	_expect(level.get_current_zone() == &"XumenGate", "entering the gate updates the current zone")
	_expect(level.objective_label.text.contains("送葬道"), "gate zone exposes the next route objective")

	player.global_position = Vector3(-10.8, 0.0, -5.5)
	player.reset_physics_interpolation()
	for _frame: int in range(3):
		await physics_frame
	_expect(level.get_resolved_seal_count() == 1, "the gate side branch resolves the first seal")
	_expect(level.objective_label.text.contains("1 / 2"), "the first seal updates the route objective")
	_expect(boss_gate.visible, "one resolved seal keeps the boss gate closed")
	_expect(
		gate_controller.state == BOSS_GATE_CONTROLLER_SCRIPT.State.UNLOCKING,
		"one resolved seal starts the unlocking state"
	)
	player.global_position = Vector3(-4.0, 0.0, -7.0)
	player.reset_physics_interpolation()
	for _frame: int in range(3):
		await physics_frame

	player.global_position = Vector3(12.0, 0.0, -25.0)
	player.reset_physics_interpolation()
	for _frame: int in range(3):
		await physics_frame
	_expect(level.get_resolved_seal_count() == 2, "the mechanism branch resolves the second seal")
	_expect(level.objective_label.text.contains("两枚封印已解除"), "both seals expose the boss route objective")
	_expect(
		gate_controller.state == BOSS_GATE_CONTROLLER_SCRIPT.State.OPENED,
		"both seals open the boss gate state"
	)
	await create_timer(0.9).timeout
	var left_half := gate_controller.get_node("Door/LeftHalf") as Sprite3D
	var right_half := gate_controller.get_node("Door/RightHalf") as Sprite3D
	_expect(
		left_half.modulate.a < 0.05 and right_half.modulate.a < 0.05,
		"opened door leaves slide apart and fade out"
	)
	_expect(boss_gate_collision.disabled, "both seals disable the boss gate collision")
	player.global_position = Vector3(4.0, 0.0, -28.5)
	player.reset_physics_interpolation()
	for _frame: int in range(3):
		await physics_frame
	_expect(level.objective_label.text.contains("首领场地"), "returning to the courtyard keeps the opened boss route objective")

	player.global_position = Vector3(-2.0, 0.0, -44.0)
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
	_expect(level.get_resolved_seal_count() == 0, "retry clears resolved seals")
	_expect(
		gate_controller.state == BOSS_GATE_CONTROLLER_SCRIPT.State.LOCKED,
		"retry restores the sealed gate state"
	)
	var reset_left_half := gate_controller.get_node("Door/LeftHalf") as Sprite3D
	_expect(
		reset_left_half.modulate.a > 0.99,
		"retry restores the closed door leaves"
	)
	_expect(
		level.camera_rig.global_position.is_equal_approx(player.global_position),
		"retry snaps the follow camera to the restored player position"
	)
	_expect(player.global_transform.is_equal_approx(player_spawn_transform), "retry restores the player spawn without scene reload")
	_expect(level.burial_road_enemy.global_transform.is_equal_approx(enemy_spawn_transform), "retry restores the enemy spawn")
	_expect(player.health_component.current_health == player.health_component.max_health, "retry restores player health")
	_expect(level.burial_road_enemy.health_component.current_health == level.burial_road_enemy.health_component.max_health, "retry restores enemy health")
	await physics_frame
	_expect(not boss_gate_collision.disabled, "retry restores boss gate collision")

	level.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: prologue greybox")
	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
