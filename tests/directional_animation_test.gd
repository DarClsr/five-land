extends SceneTree

const DirectionFrames = preload("res://scripts/actors/directional_sprite_frames.gd")
const DIRECTION_PATHS := {
	&"screen_n": "res://assets/characters/wuyang/pixel/wuyang_idle_screen_n_v1.png",
	&"screen_ne": "res://assets/characters/wuyang/pixel/wuyang_idle_screen_ne_v1.png",
	&"screen_e": "res://assets/characters/wuyang/pixel/wuyang_idle_screen_e_v1.png",
	&"screen_se": "res://assets/characters/wuyang/pixel/wuyang_idle_screen_se_v1.png",
	&"screen_s": "res://assets/characters/wuyang/pixel/wuyang_idle_screen_s_v1.png",
	&"screen_sw": "res://assets/characters/wuyang/pixel/wuyang_idle_screen_sw_v1.png",
	&"screen_w": "res://assets/characters/wuyang/pixel/wuyang_idle_screen_w_v1.png",
	&"screen_nw": "res://assets/characters/wuyang/pixel/wuyang_idle_screen_nw_v1.png",
}

var failures := 0


func _init() -> void:
	var textures: Dictionary = {}
	for direction: StringName in DIRECTION_PATHS:
		var image := Image.load_from_file(DIRECTION_PATHS[direction])
		_expect(not image.is_empty(), "loads %s Q pixel direction" % direction)
		textures[direction] = ImageTexture.create_from_image(image)
	var frames := DirectionFrames.build_static(textures)
	_expect(frames.get_animation_names().size() == 16, "builds idle and walk for eight directions")
	for direction: StringName in DirectionFrames.DIRECTIONS:
		for motion: StringName in [&"idle", &"walk"]:
			var animation := StringName("%s_%s" % [motion, direction])
			_expect(frames.has_animation(animation), "has %s" % animation)
			_expect(frames.get_frame_count(animation) == 1, "%s uses one static direction frame" % animation)
			_expect(
				frames.get_frame_texture(animation, 0).get_size() == Vector2(128, 128),
				"%s uses a 128px Q pixel frame" % animation
			)
	if failures == 0:
		print("PASS: directional animation")
	call_deferred("quit", failures)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
