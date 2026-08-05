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
	for model_direction: Vector3 in [
		Vector3.FORWARD,
		Vector3.BACK,
		Vector3.LEFT,
		Vector3.RIGHT,
		Vector3(1.0, 0.0, -1.0).normalized(),
	]:
		var model_yaw := PlayerController.model_yaw_for_direction(model_direction)
		var rendered_forward := Basis(Vector3.UP, model_yaw).z.normalized()
		_expect_vector(
			rendered_forward,
			model_direction,
			"aligns the imported model +Z front with %s" % model_direction
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
		_expect(visual != null, "player has HD-2D visual")
		var visual_3d := player_instance.get_node_or_null("Visual3D") as Node3D
		_expect(visual_3d != null, "player has a real 3D visual root")
		var model_player := player_instance.get_node_or_null(
			"Visual3D/WuyangModel/AnimationPlayer"
		) as AnimationPlayer
		_expect(model_player != null, "3D model imports its AnimationPlayer")
		if model_player:
			_expect(model_player.has_animation("wuyang_idle"), "3D model has idle animation")
			_expect(model_player.has_animation("wuyang_walk"), "3D model has walk animation")
		if visual:
			_expect(not player_instance.use_3d_model, "player defaults to the HD sprite")
			_expect(player_instance.use_validation_frame, "player uses the validation identity frame")
			player_instance.set("visual", visual)
			player_instance.set("visual_3d", visual_3d)
			player_instance.call(&"_configure_visual_mode")
			_expect(visual.visible, "shows the directional sprite by default")
			_expect(not visual_3d.visible, "hides the GLB during gameplay")
			player_instance.call(&"_configure_directional_animations")
			_expect(visual.sprite_frames.get_frame_count("idle_screen_s") == 1, "validation idle uses one frame")
			_expect(visual.sprite_frames.get_frame_count("walk_screen_e") == 1, "validation walk uses one frame")
			_expect(is_equal_approx(visual.position.y, 0.9), "player visual feet align with ground")
			_expect(is_equal_approx(visual.pixel_size, 0.00135), "HD validation frame fits the world scale")
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
				walk_texture.get_size() == Vector2(1089, 1444),
				"walk preview keeps the HD validation texture"
			)
			player_instance.call(&"_update_movement_animation", Vector3.ZERO)
			_expect(visual.animation == &"idle_screen_e", "keeps east facing while stopped")
			_expect(player_instance.equip_outfit_visual(1), "equips the earth-guard outfit")
			_expect(player_instance.outfit_visual_index == 1, "stores the selected outfit")
			_expect(player_instance.equip_weapon_visual(0), "unequips the dual daggers")
			_expect(player_instance.weapon_visual_index == 0, "stores the selected weapon")
		# The model is the active runtime prototype, while sprite mode stays available.
		player_instance.use_3d_model = true
		player_instance.set("visual_3d", visual_3d)
		player_instance.set("model_animation_player", model_player)
		player_instance.call(&"_configure_visual_mode")
		_expect(not visual.visible, "hides the sprite while the 3D model is active")
		_expect(visual_3d.visible, "can explicitly enable the source 3D model")
		_expect(model_player.current_animation == &"wuyang_idle", "3D model starts in idle")
		player_instance.call(&"_update_movement_animation", Vector3.RIGHT)
		_expect(model_player.current_animation == &"wuyang_walk", "3D model walks while moving")
		player_instance.call(&"_update_model_facing", Vector3.RIGHT, 1.0)
		_expect(
			is_equal_approx(visual_3d.rotation.y, PI / 2.0),
			"3D model rotates toward movement"
		)
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
