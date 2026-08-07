extends SceneTree

var failures: int = 0


func _init() -> void:
	var packed := load("res://scenes/hd2d_game.tscn") as PackedScene
	_expect(packed != null, "loads the HD-2D runtime shell")
	if packed == null:
		quit(failures)
		return
	var runtime := packed.instantiate()
	root.add_child(runtime)
	var container := runtime.get_node_or_null("PixelViewportContainer") as SubViewportContainer
	var viewport := runtime.get_node_or_null("PixelViewportContainer/GameViewport") as SubViewport
	var world := runtime.get_node_or_null(
		"PixelViewportContainer/GameViewport/XumenPrologueGreybox"
	)
	_expect(container != null, "runtime has a pixel viewport container")
	_expect(viewport != null, "runtime has a game subviewport")
	_expect(world != null, "runtime embeds the playable world")
	if container != null:
		_expect(container.stretch, "pixel viewport scales with the window")
		_expect(container.stretch_shrink == 1, "3D prototype renders at window resolution")
		_expect(
			container.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR,
			"HD viewport uses linear scaling"
		)
		var ink_material := container.material as ShaderMaterial
		_expect(ink_material != null, "runtime applies the ink-wash post material")
		if ink_material != null:
			_expect(ink_material.shader != null, "ink-wash material has a shader")
			_expect(
				is_equal_approx(
					float(ink_material.get_shader_parameter(&"vermilion_keep")), 1.0
				),
				"ink wash preserves the heroine's vermilion accents"
			)
			_expect(
				is_equal_approx(float(ink_material.get_shader_parameter(&"posterize_steps")), 3.0),
				"HD-2D post pass posterizes lighting into three bands"
			)
	if viewport != null:
		_expect(viewport.size == Vector2i(1280, 720), "runtime base resolution is 1280x720")
		_expect(
			ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa") == 2,
			"runtime uses sharp SMAA for HD-2D edges"
		)
	if world != null:
		var player := world.get_node_or_null("Entities/Player")
		var camera := world.get_node_or_null("FollowCameraRig/Camera3D") as Camera3D
		_expect(player != null, "runtime contains the player")
		_expect(camera != null, "runtime contains the fixed camera")
		if player != null:
			var visual := player.get_node("Visual") as AnimatedSprite3D
			var player_material := visual.material_override as ShaderMaterial
			_expect(
				player_material.get_shader_parameter(&"rim_strength") >= 0.3
					and player_material.get_shader_parameter(&"rim_strength") <= 0.4,
				"heroine receives a restrained cyan rim in dark scenes"
			)
			_expect(
				is_equal_approx(float(player_material.get_shader_parameter(&"outline_width")), 3.0),
				"heroine keeps a three-pixel all-angle silhouette"
			)
			_expect(
				is_equal_approx(float(player_material.get_shader_parameter(&"warm_light_strength")), 0.3)
					and is_equal_approx(float(player_material.get_shader_parameter(&"cold_shadow_strength")), 0.25),
				"heroine receives warm key and cold shadow tinting"
			)
			player.set("visual", visual)
			player.call(&"_configure_directional_animations")
			_expect(visual.visible, "runtime Q pixel sprite is visible")
			_expect(
				visual.sprite_frames.get_frame_texture(&"idle_screen_s", 0).get_size()
					== Vector2(128, 128),
				"runtime uses the canonical 128px Q pixel front frame"
			)
			var readability_light := player.get_node_or_null("ReadabilityLight") as OmniLight3D
			_expect(
				readability_light != null
					and readability_light.light_energy <= 0.7
					and readability_light.omni_range < 4.0,
				"runtime separates the heroine with restrained local light"
			)
		var post_material := container.material as ShaderMaterial
		_expect(
			post_material != null
				and float(post_material.get_shader_parameter(&"vignette_strength")) >= 0.25,
			"runtime applies a global vignette that conceals frame edges"
		)
		if camera != null:
			_expect(
				camera.projection == Camera3D.PROJECTION_ORTHOGONAL,
				"runtime camera uses orthographic projection"
			)
			_expect(
				camera.position.is_equal_approx(Vector3(0.0, 12.0, 10.0))
					and camera.basis.x.is_equal_approx(Vector3.RIGHT)
					and is_equal_approx(camera.size, 6.2),
				"runtime camera uses the exploration three-quarter view"
			)
			_expect(camera.attributes != null, "runtime camera has diorama depth of field")
			var rig := camera.get_parent() as FollowCameraRig
			_expect(
				rig.catchup_speed > 0.0 and rig.settle_distance <= 0.002,
				"follow camera catches up during fast movement and settles without jitter"
			)
			_expect(
				is_equal_approx(rig.presentation_size, 6.2)
					and is_equal_approx(rig.combat_size, 5.2),
				"camera exposes exploration and combat framing sizes"
			)
			rig.enter_combat()
			_expect(is_equal_approx(rig.presentation_size, 5.2), "combat framing tightens the view")
			rig.exit_combat()
			_expect(is_equal_approx(rig.presentation_size, 6.2), "exploration framing restores the wide view")
	runtime.free()
	if failures == 0:
		print("PASS: HD-2D runtime")
	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: " + message)
