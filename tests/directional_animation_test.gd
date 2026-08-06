extends SceneTree

const DirectionFrames = preload("res://scripts/actors/directional_sprite_frames.gd")
const VALIDATION_FRAME_PATH := (
	"res://assets/characters/wuyang/hd2d/wuyang_idle_front_right_validation_v1.png"
)

var failures := 0


func _init() -> void:
	var image := Image.load_from_file(VALIDATION_FRAME_PATH)
	_expect(not image.is_empty(), "loads the canonical black-haired validation frame")
	var texture := ImageTexture.create_from_image(image)
	var frames := DirectionFrames.build_validation_frame(texture)
	_expect(frames.get_animation_names().size() == 16, "builds idle and walk for eight directions")
	for direction: StringName in DirectionFrames.DIRECTIONS:
		for motion: StringName in [&"idle", &"walk"]:
			var animation := StringName("%s_%s" % [motion, direction])
			_expect(frames.has_animation(animation), "has %s" % animation)
			_expect(frames.get_frame_count(animation) == 1, "%s uses the approved proof frame" % animation)
	if failures == 0:
		print("PASS: directional animation")
	call_deferred("quit", failures)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
