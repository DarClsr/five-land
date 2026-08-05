extends SceneTree

const DirectionFrames = preload("res://scripts/actors/directional_sprite_frames.gd")
const IDLE_ATLAS = preload(
	"res://assets/characters/wuyang/hd2d/wuyang_idle_8dir_atlas.png"
)
const WALK_ATLAS = preload(
	"res://assets/characters/wuyang/hd2d/wuyang_walk_8dir_atlas.png"
)

var failures := 0


func _init() -> void:
	var manifest_text := FileAccess.get_file_as_string(
		"res://assets/characters/wuyang/hd2d/wuyang_hd2d_manifest.json"
	)
	var manifest := JSON.parse_string(manifest_text) as Dictionary
	_expect(not manifest.is_empty(), "loads the HD-2D render manifest")
	_expect(
		str(manifest.get("source", "")).ends_with("wuyang_master_v3.blend"),
		"direction atlases come from the v3 character master"
	)
	_expect(IDLE_ATLAS.get_size() == Vector2(4096, 4096), "idle atlas is 4096 square")
	_expect(WALK_ATLAS.get_size() == Vector2(4096, 4096), "walk atlas is 4096 square")
	var frames := DirectionFrames.build(IDLE_ATLAS, WALK_ATLAS)
	_expect(frames.get_animation_names().size() == 16, "builds idle and walk for eight directions")
	for direction: StringName in DirectionFrames.DIRECTIONS:
		for motion: StringName in [&"idle", &"walk"]:
			var animation := StringName("%s_%s" % [motion, direction])
			_expect(frames.has_animation(animation), "has %s" % animation)
			_expect(frames.get_frame_count(animation) == 8, "%s has eight frames" % animation)
			var first := frames.get_frame_texture(animation, 0) as AtlasTexture
			var expected_row := DirectionFrames.DIRECTIONS.find(direction)
			_expect(
				first.region == Rect2(0, expected_row * 512, 512, 512),
				"%s uses the correct atlas row" % animation
			)
	if failures == 0:
		print("PASS: directional animation")
	call_deferred("quit", failures)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
