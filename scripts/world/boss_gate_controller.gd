class_name BossGateController
extends StaticBody3D

## Four-state boss gate for the GravePassage: locked, interactable (player
## nearby), unlocking (one seal down) and opened (both seals). The 256px
## gate sheet is split into two atlas halves so the door can slide apart on
## its own plane, while procedural stone frame parts give the flat sprite a
## solid 3/4-perspective presence.

enum State { LOCKED, INTERACTABLE, UNLOCKING, OPENED }

const GATE_TEXTURE: Texture2D = preload("res://assets/props/xumen/pixel/xumen_boss_seal_gate_v1.png")
const ROUGH_STONE_TEXTURE: Texture2D = preload("res://assets/textures/terrain/cave_rock_wall_64.png")
const MOSS_DECAL_TEXTURE: Texture2D = preload("res://assets/textures/terrain/cave_moss_decal_32.png")
const HD2D_MATERIAL_LIBRARY = preload("res://scripts/world/hd2d_material_library.gd")

## Door sheet scale: 256 px at 0.02 m/px keeps a clean integer pixel grid and
## grows the door ~18% over the old 0.017 m/px sheet.
const PIXEL_SIZE: float = 0.02
const SHEET_HALF_WIDTH: float = 256.0 * 0.5 * PIXEL_SIZE
const SHEET_HEIGHT: float = 256.0 * PIXEL_SIZE
const GAP_PX: float = 4.0
const SPLIT_OFFSET_PX: float = 65.0 * PIXEL_SIZE

const COLLISION_SIZE: Vector3 = Vector3(3.8, 3.4, 0.7)

const FRAME_COLOR: Color = Color(0.52, 0.5, 0.44, 1.0)
const FRAME_DARK: Color = Color(0.34, 0.33, 0.29, 1.0)
const SOIL_COLOR: Color = Color(0.26, 0.25, 0.22, 1.0)
const CORE_COLOR: Color = Color(0.28, 0.82, 0.78, 1.0)
const RED_ALERT: Color = Color(0.85, 0.2, 0.18, 1.0)
const FOG_COOL: Color = Color(0.45, 0.65, 0.8, 1.0)
## Slightly over-unity tint: compensates the red alert layer and the dark
## ambient while keeping the sheet's warm gray (kills any violet cast).
const DOOR_TINT: Color = Color(1.06, 1.0, 0.92, 1.0)

const EFFECT_DISTANCE: float = 18.0
const CULL_INTERVAL: float = 0.2
const PLAYER_PROXIMITY: float = 9.0
const PROXIMITY_EXIT: float = 11.0

const OPEN_SLIDE: float = 1.7
const OPEN_DURATION: float = 0.8
const FOG_FADE_DURATION: float = 1.6
const SHAKE_AMPLITUDE: float = 0.015
const SHAKE_FREQUENCY: float = 38.0

const CORE_LIGHT_ENERGY: float = 0.5
const CORE_LIGHT_UNLOCKING: float = 0.8
const CORE_LIGHT_RANGE: float = 4.2
const DEBRIS_COUNT: int = 14
const DUST_COUNT: int = 20

var state: State = State.LOCKED
var _seal_count: int = 0
var _time: float = 0.0
var _cull_timer: float = 0.0
var _camera: Camera3D
var _player: Node3D
var _base_position: Vector3
var _collision: CollisionShape3D
var _tween: Tween
var _left_half: Sprite3D
var _right_half: Sprite3D
var _red_overlay: Sprite3D
var _core_light: OmniLight3D
var _debris: GPUParticles3D
var _dust: GPUParticles3D
var _fog_quad: MeshInstance3D
var _fog_light: SpotLight3D
var _fog_light_on: bool = false
static var _shadow_texture: ImageTexture


func _ready() -> void:
	_base_position = position
	collision_layer = 1
	collision_mask = 0
	_collision = CollisionShape3D.new()
	_collision.name = &"CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = COLLISION_SIZE
	_collision.shape = shape
	add_child(_collision)
	_build_door_panels()
	_build_red_overlay()
	_build_frame()
	_build_ground_contact()
	_build_core_light()
	_build_particles()
	_build_afterglow()
	add_to_group(&"rune_source")


func _process(delta: float) -> void:
	_time += delta
	_cull_timer -= delta
	if _cull_timer <= 0.0:
		_cull_timer = CULL_INTERVAL
		_update_proximity()
		_update_culling()
	if state == State.LOCKED and not _red_overlay.is_visible_in_tree():
		return
	if state == State.UNLOCKING:
		var shake: float = sin(_time * SHAKE_FREQUENCY) * SHAKE_AMPLITUDE
		position = _base_position + basis.x * shake
	if state == State.LOCKED:
		_red_overlay.modulate.a = 0.13 + sin(_time * 1.1) * 0.04 \
			+ sin(_time * 13.0 + 2.0) * 0.05 * maxf(0.0, sin(_time * 0.5))
	if _core_light.visible:
		var pulse: float = 0.5 + 0.5 * sin(_time * (1.6 if state == State.INTERACTABLE else 0.72))
		_core_light.light_energy = (
			CORE_LIGHT_UNLOCKING if state == State.UNLOCKING else CORE_LIGHT_ENERGY
		) * (1.0 + 0.22 * pulse)


func set_seal_count(count: int) -> void:
	_seal_count = count
	if _seal_count >= 2:
		open_gate()
	elif _seal_count == 1 and state != State.OPENED:
		_enter_state(State.UNLOCKING)


func open_gate() -> void:
	if state == State.OPENED:
		return
	_enter_state(State.OPENED)
	_collision.set_deferred("disabled", true)
	_play_open_tween()


func reset_state() -> void:
	_seal_count = 0
	if _tween != null and _tween.is_valid():
		_tween.kill()
	position = _base_position
	_collision.set_deferred("disabled", false)
	_left_half.position = Vector3(-SPLIT_OFFSET_PX, 0.0, 0.0)
	_right_half.position = Vector3(SPLIT_OFFSET_PX, 0.0, 0.0)
	_left_half.modulate.a = 1.0
	_right_half.modulate.a = 1.0
	_red_overlay.modulate.a = 0.25
	_fog_quad.transparency = 1.0
	_fog_light_on = false
	_enter_state(State.LOCKED)


func _enter_state(next: State) -> void:
	if next == state:
		return
	state = next
	if state == State.UNLOCKING:
		_debris.emitting = true
		_dust.emitting = true
	elif state == State.OPENED:
		_debris.emitting = false
		_dust.emitting = false
	elif state == State.LOCKED:
		_debris.emitting = false
		_dust.emitting = false


func _update_proximity() -> void:
	if state != State.LOCKED:
		return
	if not is_instance_valid(_player):
		_player = get_parent().get_node_or_null("Entities/Player") as Node3D
	if not is_instance_valid(_player):
		return
	var distance: float = global_position.distance_to(_player.global_position)
	if distance < PLAYER_PROXIMITY:
		state = State.INTERACTABLE
	elif distance > PROXIMITY_EXIT:
		state = State.LOCKED


func _update_culling() -> void:
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	if _camera == null:
		return
	var in_range: bool = global_position.distance_squared_to(
		_camera.global_position
	) <= EFFECT_DISTANCE * EFFECT_DISTANCE
	_core_light.visible = in_range
	_debris.emitting = _debris.emitting and in_range and state == State.UNLOCKING
	_dust.emitting = _dust.emitting and in_range and state == State.UNLOCKING
	_red_overlay.visible = in_range
	_fog_light.visible = in_range and _fog_light_on


func _build_door_panels() -> void:
	var door := Node3D.new()
	door.name = &"Door"
	add_child(door)
	_left_half = _make_half_sprite(&"LeftHalf", Rect2(0.0, 0.0, 126.0, 256.0))
	_left_half.position = Vector3(-SPLIT_OFFSET_PX, 0.0, 0.0)
	_right_half = _make_half_sprite(&"RightHalf", Rect2(130.0, 0.0, 126.0, 256.0))
	_right_half.position = Vector3(SPLIT_OFFSET_PX, 0.0, 0.0)
	door.add_child(_left_half)
	door.add_child(_right_half)
	_build_split_edge(&"SeamInnerL", -0.55)
	_build_split_edge(&"SeamInnerR", 0.55)


func _make_half_sprite(sprite_name: StringName, region: Rect2) -> Sprite3D:
	var atlas := AtlasTexture.new()
	atlas.atlas = GATE_TEXTURE
	atlas.region = region
	var sprite := Sprite3D.new()
	sprite.name = sprite_name
	sprite.texture = atlas
	sprite.pixel_size = PIXEL_SIZE
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = true
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	sprite.modulate = DOOR_TINT
	return sprite


## Thin dark strips on the sheet face make the door read as two leaves with a
## real opening line instead of one flat slab.
func _build_split_edge(edge_name: StringName, local_x: float) -> void:
	var strip := MeshInstance3D.new()
	strip.name = edge_name
	strip.position = Vector3(local_x, 0.0, 0.06)
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var box := BoxMesh.new()
	box.size = Vector3(0.09, SHEET_HEIGHT * 0.82, 0.02)
	strip.mesh = box
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.09, 0.09, 0.1, 0.85)
	strip.material_override = material
	get_node("Door").add_child(strip)


## Locked-state warning layer: a red-tinted copy of the sheet that flickers
## softly. No dedicated red-rune sheet exists yet, so this is the closest
## material-level approximation without stretching the art.
func _build_red_overlay() -> void:
	_red_overlay = Sprite3D.new()
	_red_overlay.name = &"RedAlertOverlay"
	_red_overlay.texture = GATE_TEXTURE
	_red_overlay.pixel_size = PIXEL_SIZE
	_red_overlay.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_red_overlay.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_red_overlay.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_red_overlay.position = Vector3(0.0, 0.0, 0.08)
	_red_overlay.modulate = Color(RED_ALERT.r, RED_ALERT.g, RED_ALERT.b, 0.16)
	_red_overlay.visible = false
	add_child(_red_overlay)


func _build_frame() -> void:
	var frame := Node3D.new()
	frame.name = &"Frame"
	add_child(frame)
	var pillar_half_x: float = SHEET_HALF_WIDTH + 0.32
	_add_stone_box(frame, &"PillarLeft", Vector3(-pillar_half_x, 1.85, 0.0), Vector3(0.64, 3.7, 0.64), FRAME_COLOR)
	_add_stone_box(frame, &"PillarRight", Vector3(pillar_half_x, 1.85, 0.0), Vector3(0.64, 3.7, 0.64), FRAME_COLOR)
	_add_stone_box(frame, &"Lintel", Vector3(0.0, 3.85, 0.0), Vector3(5.3, 0.5, 0.72), FRAME_COLOR)
	_add_stone_box(frame, &"Eave", Vector3(0.0, 4.22, 0.0), Vector3(5.9, 0.34, 0.85), FRAME_DARK)
	_add_stone_box(frame, &"Threshold", Vector3(0.0, -0.22, 0.1), Vector3(5.3, 0.44, 1.0), FRAME_DARK)
	_add_stone_box(frame, &"BaseStep", Vector3(0.0, -0.5, 0.22), Vector3(5.8, 0.34, 1.3), FRAME_COLOR)
	_add_stone_box(frame, &"WallLeft", Vector3(-(pillar_half_x + 0.52), 1.1, -0.15), Vector3(0.42, 2.2, 0.5), FRAME_DARK)
	_add_stone_box(frame, &"WallRight", Vector3(pillar_half_x + 0.52, 1.1, -0.15), Vector3(0.42, 2.2, 0.5), FRAME_DARK)
	_add_top_blackout(frame)


## Soft vertical gradient above the eave so the door top does not fuse into
## the black void beyond the passage.
func _add_top_blackout(parent: Node3D) -> void:
	var blackout := MeshInstance3D.new()
	blackout.name = &"TopBlackout"
	blackout.position = Vector3(0.0, 4.62, -0.05)
	blackout.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(6.4, 1.3)
	blackout.mesh = quad
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = _make_top_fade_texture()
	material.albedo_color = Color(0.05, 0.06, 0.07, 0.9)
	blackout.material_override = material
	parent.add_child(blackout)


func _add_stone_box(parent: Node3D, box_name: StringName, center: Vector3, size: Vector3, tint: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = box_name
	instance.position = center
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.material_override = HD2D_MATERIAL_LIBRARY.get_stone(
		ROUGH_STONE_TEXTURE, tint, 1.35, 0.075, 0.86, 0.7, 0.96, 0.72, 0.76
	)
	parent.add_child(instance)
	return instance


func _build_ground_contact() -> void:
	var contact := Node3D.new()
	contact.name = &"GroundContact"
	add_child(contact)
	var shadow := MeshInstance3D.new()
	shadow.name = &"ContactShadow"
	shadow.position = Vector3(0.0, 0.03, 0.25)
	shadow.rotation_degrees.x = -90.0
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(5.4, 1.15)
	shadow.mesh = quad
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = _make_shadow_texture()
	material.albedo_color = Color(0.0, 0.0, 0.02, 0.42)
	shadow.material_override = material
	contact.add_child(shadow)
	var grime := MeshInstance3D.new()
	grime.name = &"Grime"
	grime.position = Vector3(0.0, 0.02, 0.42)
	grime.rotation_degrees.x = -90.0
	grime.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var grime_quad := QuadMesh.new()
	grime_quad.size = Vector2(4.9, 0.55)
	grime.mesh = grime_quad
	var grime_material := StandardMaterial3D.new()
	grime_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grime_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grime_material.albedo_texture = MOSS_DECAL_TEXTURE
	grime_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	grime_material.albedo_color = Color(0.16, 0.17, 0.15, 0.5)
	grime.material_override = grime_material
	contact.add_child(grime)
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260808
	for index: int in range(3):
		var debris := MeshInstance3D.new()
		debris.name = &"DebrisStone%d" % index
		var size: float = rng.randf_range(0.1, 0.2)
		debris.position = Vector3(
			rng.randf_range(-2.2, 2.2), size * 0.5, rng.randf_range(0.5, 1.6)
		)
		debris.rotation_degrees = Vector3(rng.randf_range(-8.0, 8.0), rng.randf_range(0.0, 180.0), rng.randf_range(-8.0, 8.0))
		var box := BoxMesh.new()
		box.size = Vector3(size, size * 0.7, size)
		debris.mesh = box
		debris.material_override = HD2D_MATERIAL_LIBRARY.get_stone(
			ROUGH_STONE_TEXTURE, SOIL_COLOR.lightened(0.08), 1.2, 0.075, 0.86, 0.7, 0.96, 0.72, 0.76
		)
		contact.add_child(debris)


func _build_core_light() -> void:
	_core_light = OmniLight3D.new()
	_core_light.name = &"CoreLight"
	_core_light.position = Vector3(0.0, 2.1, 0.42)
	_core_light.light_color = CORE_COLOR
	_core_light.light_energy = CORE_LIGHT_ENERGY
	_core_light.omni_range = CORE_LIGHT_RANGE
	_core_light.omni_attenuation = 2.0
	_core_light.shadow_enabled = false
	_core_light.light_volumetric_fog_energy = 0.05
	add_child(_core_light)


func _build_particles() -> void:
	_debris = _make_particles(
		&"UnlockDebris", DEBRIS_COUNT, Vector3(2.6, 2.0, 0.2),
		Color(0.5, 0.47, 0.42, 0.85), 0.9, Vector2(0.6, 1.8), Vector2(0.05, 0.12)
	)
	_dust = _make_particles(
		&"UnlockDust", DUST_COUNT, Vector3(3.4, 2.6, 0.3),
		Color(0.55, 0.6, 0.62, 0.3), 1.6, Vector2(0.15, 0.5), Vector2(0.09, 0.24)
	)


func _make_particles(
	particle_name: StringName, amount: int, extents: Vector3,
	color: Color, lifetime: float, velocity: Vector2, scale_range: Vector2
) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = particle_name
	particles.amount = amount
	particles.lifetime = lifetime
	particles.preprocess = 0.0
	particles.fixed_fps = 20
	particles.local_coords = true
	particles.emitting = false
	particles.visibility_aabb = AABB(-extents, extents * 2.0 + Vector3.UP * 1.6)
	particles.draw_pass_1 = QuadMesh.new()
	var quad: QuadMesh = particles.draw_pass_1 as QuadMesh
	quad.size = Vector2(0.09, 0.09)
	var process_material := ParticleProcessMaterial.new()
	process_material.direction = Vector3.UP
	process_material.spread = 70.0
	process_material.gravity = Vector3(0.0, -8.5, 0.0)
	process_material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process_material.emission_box_extents = extents
	process_material.initial_velocity_min = velocity.x
	process_material.initial_velocity_max = velocity.y
	process_material.scale_min = scale_range.x
	process_material.scale_max = scale_range.y
	process_material.color = color
	particles.process_material = process_material
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.vertex_color_use_as_albedo = true
	material.vertex_color_is_srgb = true
	material.albedo_texture = _make_shadow_texture()
	particles.material_override = material
	add_child(particles)
	return particles


## Cold shaft behind the door that fades in while the leaves slide open.
func _build_afterglow() -> void:
	var afterglow := Node3D.new()
	afterglow.name = &"Afterglow"
	add_child(afterglow)
	_fog_quad = MeshInstance3D.new()
	_fog_quad.name = &"CoolFog"
	_fog_quad.position = Vector3(0.0, 2.0, -1.1)
	_fog_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var quad := QuadMesh.new()
	quad.size = Vector2(4.4, 3.4)
	_fog_quad.mesh = quad
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.albedo_texture = _make_shadow_texture()
	material.albedo_color = Color(FOG_COOL.r, FOG_COOL.g, FOG_COOL.b, 0.16)
	material.emission_enabled = true
	material.emission = FOG_COOL
	material.emission_energy_multiplier = 0.7
	_fog_quad.material_override = material
	_fog_quad.transparency = 1.0
	afterglow.add_child(_fog_quad)
	_fog_light = SpotLight3D.new()
	_fog_light.name = &"CoolShaft"
	_fog_light.position = Vector3(0.0, 2.2, -0.4)
	_fog_light.look_at_from_position(Vector3(0.0, 2.2, -0.4), Vector3(0.0, 1.4, -4.5), Vector3.UP)
	_fog_light.light_color = FOG_COOL
	_fog_light.light_energy = 0.5
	_fog_light.light_volumetric_fog_energy = 0.35
	_fog_light.spot_range = 6.5
	_fog_light.spot_angle = 42.0
	_fog_light.spot_attenuation = 1.6
	_fog_light.shadow_enabled = false
	_fog_light.visible = false
	afterglow.add_child(_fog_light)


func _play_open_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(
		_left_half, "position:x", -SPLIT_OFFSET_PX - OPEN_SLIDE, OPEN_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(
		_right_half, "position:x", SPLIT_OFFSET_PX + OPEN_SLIDE, OPEN_DURATION
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_left_half, "modulate:a", 0.0, OPEN_DURATION)
	_tween.tween_property(_right_half, "modulate:a", 0.0, OPEN_DURATION)
	_tween.tween_property(_red_overlay, "modulate:a", 0.0, OPEN_DURATION * 0.4)
	_tween.tween_property(_fog_quad, "transparency", 0.0, FOG_FADE_DURATION)
	_tween.tween_callback(func() -> void: _fog_light_on = true)


static func _make_shadow_texture(size: int = 48) -> ImageTexture:
	if _shadow_texture != null:
		return _shadow_texture
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	for y: int in range(size):
		for x: int in range(size):
			var dx: float = (float(x) + 0.5) / float(size) * 2.0 - 1.0
			var dy: float = (float(y) + 0.5) / float(size) * 2.0 - 1.0
			var distance: float = sqrt(dx * dx + dy * dy)
			var alpha: float = clampf(1.0 - distance * 1.5, 0.0, 1.0)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha * alpha))
	_shadow_texture = ImageTexture.create_from_image(image)
	return _shadow_texture


static func _make_top_fade_texture(width: int = 8, height: int = 64) -> ImageTexture:
	var image := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y: int in range(height):
		var alpha: float = clampf(1.0 - float(y) / float(height) * 1.35, 0.0, 1.0)
		for x: int in range(width):
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha))
	return ImageTexture.create_from_image(image)
