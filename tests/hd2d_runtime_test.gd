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
			_expect(not player.use_3d_model, "runtime disables the visible 3D heroine")
			_expect(player.use_validation_frame, "runtime enables the approved-frame slot")
			_expect(player.get_node("Visual").visible, "runtime HD sprite is visible")
			_expect(not player.get_node("Visual3D").visible, "runtime GLB source is hidden")
		if camera != null:
			_expect(
				camera.projection == Camera3D.PROJECTION_ORTHOGONAL,
				"runtime camera uses orthographic projection"
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
