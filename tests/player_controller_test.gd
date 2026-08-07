extends SceneTree

const PlayerController = preload("res://scripts/actors/player_controller.gd")

var failures := 0

func _init() -> void:
	var diagonal := PlayerController.camera_relative_direction(
		Vector2(1.0, 1.0), Vector3.RIGHT, Vector3.FORWARD
	)
	_expect_vector(diagonal, Vector3(1.0, 0.0, -1.0).normalized(), "normalizes diagonal movement")
	var screen_directions := {
		Vector2(0.0, 1.0): &"screen_n",
		Vector2(1.0, 1.0): &"screen_ne",
		Vector2.RIGHT: &"screen_e",
		Vector2(1.0, -1.0): &"screen_se",
		Vector2(0.0, -1.0): &"screen_s",
		Vector2(-1.0, -1.0): &"screen_sw",
		Vector2.LEFT: &"screen_w",
		Vector2(-1.0, 1.0): &"screen_nw",
	}
	for screen_input: Vector2 in screen_directions:
		_expect(
			PlayerController.resolve_screen_direction(screen_input) == screen_directions[screen_input],
			"maps %s to %s" % [screen_input, screen_directions[screen_input]]
		)
	_expect(
		PlayerController.resolve_screen_direction(Vector2.ZERO, &"screen_w") == &"screen_w",
		"keeps the last direction while idle"
	)
	_expect_vector(
		PlayerController.choose_dodge_direction(Vector3.ZERO, Vector3.LEFT),
		Vector3.LEFT,
		"uses facing when dodge has no input"
	)

	var player := PlayerController.new()
	player.facing_direction = Vector3.LEFT
	_expect(player.try_start_dodge(Vector3.ZERO), "starts first dodge")
	_expect(player.is_invulnerable(), "is invulnerable during dodge")
	player.tick_timers(player.dodge_duration)
	_expect(not player.is_invulnerable(), "ends invulnerability with dodge")
	_expect(not player.try_start_dodge(Vector3.RIGHT), "blocks dodge during cooldown")
	player.tick_timers(player.dodge_cooldown - player.dodge_duration)
	_expect(player.try_start_dodge(Vector3.RIGHT), "allows dodge after cooldown")

	var player_scene := load("res://scenes/actors/player.tscn") as PackedScene
	_expect(player_scene != null, "loads reusable player scene")
	if player_scene:
		var player_instance := player_scene.instantiate()
		_expect(player_instance is CharacterBody3D, "player scene uses CharacterBody3D")
		_expect(player_instance.get_node_or_null("CollisionShape3D") != null, "player has collision")
		var visual := player_instance.get_node_or_null("Visual") as AnimatedSprite3D
		_expect(visual != null, "player has Q pixel visual")
		if visual:
			player_instance.set("visual", visual)
			player_instance.call(&"_configure_directional_animations")
			_expect(visual.sprite_frames.get_frame_count("idle_screen_s") == 1, "validation idle uses one frame")
			_expect(visual.sprite_frames.get_frame_count("walk_screen_e") == 8, "validation walk uses eight frames")
			_expect(is_equal_approx(visual.position.y, 0.93), "player visual feet align with ground")
			_expect(is_equal_approx(visual.pixel_size, 0.0165), "Q pixel frame reads at gameplay scale")
			_expect(visual.scale.is_equal_approx(Vector3(0.86, 1.0, 1.0)), "Q pixel silhouette is narrowed without losing height")
			_expect(visual.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Q pixel art uses nearest filtering")
			_expect(
				visual.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"player uses only the authored ground shadow"
			)
			player_instance.facing_screen_direction = &"screen_e"
			player_instance.call(&"_update_movement_animation", Vector3.RIGHT)
			_expect(visual.animation == &"walk_screen_e", "uses east walk animation while moving")
			var shader_material := visual.material_override as ShaderMaterial
			var walk_texture := shader_material.get_shader_parameter(&"albedo_texture") as Texture2D
			_expect(
				walk_texture.get_size() == Vector2(1024, 1024),
				"walk preview samples the eight-direction Q pixel atlas"
			)
			player_instance.call(&"_update_movement_animation", Vector3.ZERO)
			_expect(visual.animation == &"idle_screen_e", "keeps east facing while stopped")
		player_instance.free()

	var level_scene := load("res://scenes/hd2d_test.tscn") as PackedScene
	var level_instance := level_scene.instantiate()
	_expect(level_instance.get_node_or_null("GroundBody/CollisionShape3D") != null, "level has ground collision")
	level_instance.free()
	player.free()

	if failures == 0:
		print("PASS: player controller")
	call_deferred("quit", failures)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _expect_vector(actual: Vector3, expected: Vector3, message: String) -> void:
	_expect(actual.is_equal_approx(expected), message)
