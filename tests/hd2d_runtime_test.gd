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
	if viewport != null:
		_expect(viewport.size == Vector2i(1280, 720), "runtime base resolution is 1280x720")
	if world != null:
		var player := world.get_node_or_null("Entities/Player")
		var camera := world.get_node_or_null("FollowCameraRig/Camera3D") as Camera3D
		_expect(player != null, "runtime contains the player")
		_expect(camera != null, "runtime contains the fixed camera")
		if player != null:
			var visual := player.get_node("Visual") as AnimatedSprite3D
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
					and readability_light.light_energy < 1.0
					and readability_light.omni_range < 3.5,
				"runtime separates the heroine with restrained local light"
			)
		if camera != null:
			_expect(
				camera.projection == Camera3D.PROJECTION_ORTHOGONAL,
				"runtime camera uses orthographic projection"
			)
			_expect(
				camera.position.is_equal_approx(Vector3(0.0, 12.0, 10.0))
					and camera.basis.x.is_equal_approx(Vector3.RIGHT)
					and is_equal_approx(camera.size, 5.0),
				"runtime camera uses the close three-quarter view"
			)
			_expect(camera.attributes != null, "runtime camera has diorama depth of field")
	runtime.free()
	if failures == 0:
		print("PASS: HD-2D runtime")
	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: " + message)
