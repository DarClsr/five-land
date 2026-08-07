class_name DirectionalSpriteFrames
extends RefCounted

const FRAME_COUNT := 8
const FPS := 8.0
const DIRECTIONS: Array[StringName] = [
	&"screen_n",
	&"screen_ne",
	&"screen_e",
	&"screen_se",
	&"screen_s",
	&"screen_sw",
	&"screen_w",
	&"screen_nw",
]


static func build(idle_atlas: Texture2D, walk_atlas: Texture2D) -> SpriteFrames:
	assert(idle_atlas != null, "The idle direction atlas is required")
	assert(walk_atlas != null, "The walk direction atlas is required")
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	var atlases: Dictionary[StringName, Texture2D] = {
		&"idle": idle_atlas,
		&"walk": walk_atlas,
	}
	for motion: StringName in atlases:
		var atlas: Texture2D = atlases[motion]
		var cell_size := Vector2i(
			atlas.get_width() / FRAME_COUNT,
			atlas.get_height() / DIRECTIONS.size()
		)
		assert(
			cell_size.x == cell_size.y and cell_size.x > 0,
			"Directional atlases must use eight square columns and rows"
		)
		for row: int in DIRECTIONS.size():
			var animation_name := StringName("%s_%s" % [motion, DIRECTIONS[row]])
			sprite_frames.add_animation(animation_name)
			sprite_frames.set_animation_speed(animation_name, FPS)
			sprite_frames.set_animation_loop(animation_name, true)
			for column: int in FRAME_COUNT:
				var frame_texture := AtlasTexture.new()
				frame_texture.atlas = atlas
				frame_texture.region = Rect2(
					Vector2(column * cell_size.x, row * cell_size.y),
					Vector2(cell_size)
				)
				frame_texture.filter_clip = true
				sprite_frames.add_frame(animation_name, frame_texture)
	return sprite_frames


static func build_static(direction_textures: Dictionary) -> SpriteFrames:
	assert(direction_textures.size() == DIRECTIONS.size(), "All eight directions are required")
	var sprite_frames := SpriteFrames.new()
	sprite_frames.remove_animation(&"default")
	for motion: StringName in [&"idle", &"walk"]:
		for direction: StringName in DIRECTIONS:
			var texture := direction_textures.get(direction) as Texture2D
			assert(texture != null, "Missing texture for %s" % direction)
			var animation_name := StringName("%s_%s" % [motion, direction])
			sprite_frames.add_animation(animation_name)
			sprite_frames.set_animation_speed(animation_name, FPS)
			sprite_frames.set_animation_loop(animation_name, true)
			sprite_frames.add_frame(animation_name, texture)
	return sprite_frames
