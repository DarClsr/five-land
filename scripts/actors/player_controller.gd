class_name PlayerController
extends CharacterBody3D

signal died
signal stance_changed(element: int, display_name: String, color: Color)
signal equipment_visual_changed(outfit_index: int, weapon_index: int)
signal attack_landed(
	applied_damage: int,
	multiplier: float,
	relation: int,
	attacker_element: int,
	defender_element: int
)

const HEALTH_COMPONENT_SCRIPT = preload("res://scripts/components/health_component.gd")
const HURTBOX_COMPONENT_SCRIPT = preload("res://scripts/components/hurtbox_component.gd")
const HITBOX_COMPONENT_SCRIPT = preload("res://scripts/components/hitbox_component.gd")
const ELEMENT_COMPONENT_SCRIPT = preload("res://scripts/components/element_component.gd")
const ELEMENT_DEFINITION_SCRIPT = preload("res://scripts/combat/element_definition.gd")
const EARTH_DEFINITION = preload("res://data/elements/earth.tres")
const WATER_DEFINITION = preload("res://data/elements/water.tres")
const DIRECTIONAL_SPRITE_FRAMES = preload("res://scripts/actors/directional_sprite_frames.gd")
const OUTFIT_ATLASES: Array[Texture2D] = [
	preload("res://assets/characters/wuyang/modular/outfit_wanderer_8dir_atlas.png"),
	preload("res://assets/characters/wuyang/modular/outfit_earth_guard_8dir_atlas.png"),
]
const WEAPON_ATLASES: Array[Texture2D] = [
	preload("res://assets/characters/wuyang/modular/weapon_none_8dir_atlas.png"),
	preload("res://assets/characters/wuyang/modular/weapon_dual_daggers_8dir_atlas.png"),
]

@export var move_speed: float = 4.5
@export var dodge_speed: float = 10.0
@export var dodge_duration: float = 0.18
@export var dodge_cooldown: float = 0.45
@export var attack_duration: float = 0.16
@export var attack_cooldown: float = 0.32
@export var attack_range: float = 0.95
@export var knockback_duration: float = 0.14
@export var idle_direction_atlas: Texture2D
@export var walk_direction_atlas: Texture2D
@export var validation_frame: Texture2D
@export_file("*.png") var validation_frame_path: String = ""
@export var use_validation_frame: bool = false
## The GLB remains available as an offline animation/render source. Runtime uses
## the eight-direction sprite by default to preserve the 2.5D visual contract.
@export var use_3d_model: bool = false
@export var model_turn_speed: float = 14.0
@export var model_yaw_offset: float = 0.0

@onready var visual: AnimatedSprite3D = $Visual
@onready var visual_3d: Node3D = $Visual3D
@onready var model_animation_player: AnimationPlayer = $Visual3D/WuyangModel/AnimationPlayer
@onready var health_component: HEALTH_COMPONENT_SCRIPT = $HealthComponent
@onready var hurtbox_component: HURTBOX_COMPONENT_SCRIPT = $HurtboxComponent
@onready var attack_hitbox: HITBOX_COMPONENT_SCRIPT = $AttackHitbox
@onready var element_component: ELEMENT_COMPONENT_SCRIPT = $ElementComponent

var facing_direction: Vector3 = Vector3.FORWARD
var facing_screen_direction: StringName = &"screen_s"
var dodge_direction: Vector3 = Vector3.ZERO
var dodge_time_remaining: float = 0.0
var dodge_cooldown_remaining: float = 0.0
var attack_time_remaining: float = 0.0
var attack_cooldown_remaining: float = 0.0
var _attack_requested: bool = false
var _dodge_requested: bool = false
var _stance_switch_requested: bool = false
var _knockback_velocity: Vector3 = Vector3.ZERO
var _knockback_time_remaining: float = 0.0
var _base_visual_color: Color = Color.WHITE
var _visual_tween: Tween
var _dead: bool = false
var _model_animation: StringName = &""
var _model_materials: Array[StandardMaterial3D] = []
var _model_material_roles: Array[StringName] = []
var _model_source_colors: Array[Color] = []
var _model_base_colors: Array[Color] = []
var _model_tint: Color = Color.WHITE
var outfit_visual_index: int = 0
var weapon_visual_index: int = 1
var _composed_equipment_atlas: ImageTexture


func _ready() -> void:
	_configure_directional_animations()
	_configure_visual_mode()
	element_component.element_changed.connect(_on_element_changed)
	attack_hitbox.hit_resolved.connect(_on_attack_hit_resolved)
	hurtbox_component.hurt.connect(_on_hurt)
	var stances: Array[ELEMENT_DEFINITION_SCRIPT] = [EARTH_DEFINITION, WATER_DEFINITION]
	element_component.configure(stances)
	hurtbox_component.health_component = health_component
	hurtbox_component.element_component = element_component
	attack_hitbox.source_element_component = element_component
	health_component.died.connect(_on_died)


func _exit_tree() -> void:
	if element_component != null and element_component.element_changed.is_connected(_on_element_changed):
		element_component.element_changed.disconnect(_on_element_changed)
	if attack_hitbox != null and attack_hitbox.hit_resolved.is_connected(_on_attack_hit_resolved):
		attack_hitbox.hit_resolved.disconnect(_on_attack_hit_resolved)
	if hurtbox_component != null and hurtbox_component.hurt.is_connected(_on_hurt):
		hurtbox_component.hurt.disconnect(_on_hurt)
	if health_component != null and health_component.died.is_connected(_on_died):
		health_component.died.disconnect(_on_died)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attack"):
		_attack_requested = true
	if event.is_action_pressed(&"dodge"):
		_dodge_requested = true
	if event.is_action_pressed(&"switch_stance"):
		_stance_switch_requested = true
	if event.is_action_pressed(&"cycle_outfit"):
		equip_outfit_visual((outfit_visual_index + 1) % OUTFIT_ATLASES.size())
	if event.is_action_pressed(&"cycle_weapon"):
		equip_weapon_visual((weapon_visual_index + 1) % WEAPON_ATLASES.size())


func _physics_process(delta: float) -> void:
	tick_timers(delta)
	if _dead:
		velocity = Vector3.ZERO
		return
	if _knockback_time_remaining > 0.0:
		velocity = _knockback_velocity
		velocity.y = 0.0
		move_and_slide()
		return
	var input_vector: Vector2 = Input.get_vector(
		&"move_left", &"move_right", &"move_down", &"move_up"
	)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var move_direction: Vector3 = Vector3.ZERO
	if camera:
		move_direction = camera_relative_direction(
			input_vector, camera.global_basis.x, -camera.global_basis.z
		)
	if _stance_switch_requested:
		try_cycle_stance()
		_stance_switch_requested = false
	if _dodge_requested:
		try_start_dodge(move_direction)
		_dodge_requested = false
	if _attack_requested:
		try_start_attack(move_direction)
		_attack_requested = false

	if is_invulnerable():
		velocity = dodge_direction * dodge_speed
	else:
		velocity = move_direction * move_speed
		if not move_direction.is_zero_approx():
			facing_direction = move_direction
			facing_screen_direction = resolve_screen_direction(
				input_vector, facing_screen_direction
			)
	if use_3d_model:
		var model_turn_direction := dodge_direction if is_invulnerable() else move_direction
		if not model_turn_direction.is_zero_approx():
			_update_model_facing(model_turn_direction, delta)
	_update_movement_animation(move_direction)
	velocity.y = 0.0
	move_and_slide()


static func camera_relative_direction(input: Vector2, right: Vector3, forward: Vector3) -> Vector3:
	right.y = 0.0
	forward.y = 0.0
	return (right.normalized() * input.x + forward.normalized() * input.y).normalized()


static func choose_dodge_direction(input_direction: Vector3, fallback: Vector3) -> Vector3:
	if input_direction.is_zero_approx():
		return fallback.normalized()
	return input_direction.normalized()


func animation_for_movement(direction: Vector3) -> StringName:
	return &"idle" if direction.is_zero_approx() else &"walk"


static func resolve_screen_direction(
	input: Vector2, fallback: StringName = &"screen_s"
) -> StringName:
	if input.is_zero_approx():
		return fallback
	var sector := posmod(int(round(atan2(input.y, input.x) / (PI / 4.0))), 8)
	match sector:
		0:
			return &"screen_e"
		1:
			return &"screen_ne"
		2:
			return &"screen_n"
		3:
			return &"screen_nw"
		4:
			return &"screen_w"
		5:
			return &"screen_sw"
		6:
			return &"screen_s"
		_:
			return &"screen_se"


static func model_yaw_for_direction(direction: Vector3, yaw_offset: float = 0.0) -> float:
	if direction.is_zero_approx():
		return yaw_offset
	# Blender's local -Y character front becomes local +Z after glTF import.
	return atan2(direction.x, direction.z) + yaw_offset


func _configure_directional_animations() -> void:
	if use_validation_frame:
		if validation_frame == null:
			validation_frame = _load_validation_frame()
		if validation_frame == null:
			push_error("Player is missing the HD validation frame")
			return
		visual.sprite_frames = DIRECTIONAL_SPRITE_FRAMES.build_validation_frame(
			validation_frame
		)
		_set_visual_shader_texture(validation_frame)
		visual.play(&"idle_screen_s")
		return
	if idle_direction_atlas == null or walk_direction_atlas == null:
		push_error("Player is missing the HD2D direction atlases")
		return
	_composed_equipment_atlas = _compose_equipment_atlas(
		OUTFIT_ATLASES[outfit_visual_index], WEAPON_ATLASES[weapon_visual_index]
	)
	visual.sprite_frames = DIRECTIONAL_SPRITE_FRAMES.build(
		_composed_equipment_atlas, _composed_equipment_atlas
	)
	_set_visual_shader_texture(_composed_equipment_atlas)
	visual.play(&"idle_screen_s")


func _load_validation_frame() -> Texture2D:
	if validation_frame_path.is_empty() or not FileAccess.file_exists(validation_frame_path):
		return null
	var image := Image.load_from_file(validation_frame_path)
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _set_visual_shader_texture(texture: Texture2D) -> void:
	var shader_material := visual.material_override as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter(&"albedo_texture", texture)


func _compose_equipment_atlas(outfit_atlas: Texture2D, weapon_atlas: Texture2D) -> ImageTexture:
	var outfit_image: Image = outfit_atlas.get_image()
	var weapon_image: Image = weapon_atlas.get_image()
	assert(outfit_image.get_size() == weapon_image.get_size(), "Equipment atlases must align")
	outfit_image.convert(Image.FORMAT_RGBA8)
	weapon_image.convert(Image.FORMAT_RGBA8)
	outfit_image.blend_rect(
		weapon_image,
		Rect2i(Vector2i.ZERO, weapon_image.get_size()),
		Vector2i.ZERO
	)
	return ImageTexture.create_from_image(outfit_image)


func equip_outfit_visual(index: int) -> bool:
	if index < 0 or index >= OUTFIT_ATLASES.size():
		return false
	outfit_visual_index = index
	_configure_directional_animations()
	_apply_model_equipment_visuals()
	equipment_visual_changed.emit(outfit_visual_index, weapon_visual_index)
	return true


func equip_weapon_visual(index: int) -> bool:
	if index < 0 or index >= WEAPON_ATLASES.size():
		return false
	weapon_visual_index = index
	_configure_directional_animations()
	_apply_model_equipment_visuals()
	equipment_visual_changed.emit(outfit_visual_index, weapon_visual_index)
	return true


func _configure_visual_mode() -> void:
	visual.visible = not use_3d_model
	visual_3d.visible = use_3d_model
	if not use_3d_model:
		return
	_model_materials.clear()
	_model_material_roles.clear()
	_model_source_colors.clear()
	_model_base_colors.clear()
	for animation_name: StringName in [&"wuyang_idle", &"wuyang_walk"]:
		var animation := model_animation_player.get_animation(animation_name)
		if animation != null:
			animation.loop_mode = Animation.LOOP_LINEAR
	for node: Node in visual_3d.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var source_material := mesh_instance.get_active_material(0) as StandardMaterial3D
		if source_material == null:
			continue
		var toon_material := source_material.duplicate(true) as StandardMaterial3D
		toon_material.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
		toon_material.specular_mode = BaseMaterial3D.SPECULAR_TOON
		toon_material.roughness = 0.82
		toon_material.rim_enabled = true
		toon_material.rim = 0.3
		toon_material.rim_tint = 0.22
		mesh_instance.material_override = toon_material
		_model_materials.append(toon_material)
		_model_material_roles.append(source_material.resource_name)
		_model_source_colors.append(toon_material.albedo_color)
		_model_base_colors.append(toon_material.albedo_color)
	_apply_model_equipment_visuals()
	_play_model_animation(&"wuyang_idle")


func _apply_model_equipment_visuals() -> void:
	if not use_3d_model or visual_3d == null:
		return
	for index: int in _model_materials.size():
		var color := _model_source_colors[index]
		if outfit_visual_index == 1:
			match _model_material_roles[index]:
				&"M_BlueGray", &"M_Wuyang_IndigoCloth":
					color = Color("384139")
				&"M_InkBlue", &"M_Wuyang_InkCloth":
					color = Color("1f2924")
				&"M_Cinnabar", &"M_Wuyang_Vermilion":
					color = Color("815022")
		_model_base_colors[index] = color
		_model_materials[index].albedo_color = color * _model_tint
	var show_weapon := weapon_visual_index == 1
	for node: Node in visual_3d.find_children("*", "MeshInstance3D", true, false):
		if node.name.begins_with("Dagger") or node.name.begins_with("V3_Pommel"):
			(node as MeshInstance3D).visible = show_weapon


func _update_model_facing(direction: Vector3, delta: float) -> void:
	var target_yaw := model_yaw_for_direction(direction, model_yaw_offset)
	visual_3d.rotation.y = lerp_angle(
		visual_3d.rotation.y, target_yaw, clampf(model_turn_speed * delta, 0.0, 1.0)
	)


func _play_model_animation(animation_name: StringName) -> void:
	if _model_animation == animation_name:
		return
	if not model_animation_player.has_animation(animation_name):
		push_error("Wuyang 3D model is missing animation: %s" % animation_name)
		return
	_model_animation = animation_name
	model_animation_player.play(animation_name, 0.12)


func _update_movement_animation(direction: Vector3) -> void:
	if use_3d_model:
		var model_animation := StringName("wuyang_%s" % animation_for_movement(direction))
		_play_model_animation(model_animation)
		return
	var next_animation := StringName(
		"%s_%s" % [animation_for_movement(direction), facing_screen_direction]
	)
	if visual.animation == next_animation:
		return
	visual.play(next_animation)
	var frame_texture := visual.sprite_frames.get_frame_texture(next_animation, 0)
	if frame_texture is AtlasTexture:
		_set_visual_shader_texture((frame_texture as AtlasTexture).atlas)
	elif frame_texture != null:
		_set_visual_shader_texture(frame_texture)


func try_start_dodge(input_direction: Vector3) -> bool:
	if _dead or dodge_cooldown_remaining > 0.0 or attack_time_remaining > 0.0:
		return false
	dodge_direction = choose_dodge_direction(input_direction, facing_direction)
	dodge_time_remaining = dodge_duration
	dodge_cooldown_remaining = dodge_cooldown
	if hurtbox_component != null:
		hurtbox_component.set_enabled(false)
	return true


func tick_timers(delta: float) -> void:
	var was_dodging: bool = is_invulnerable()
	dodge_time_remaining = maxf(0.0, dodge_time_remaining - delta)
	dodge_cooldown_remaining = maxf(0.0, dodge_cooldown_remaining - delta)
	attack_time_remaining = maxf(0.0, attack_time_remaining - delta)
	attack_cooldown_remaining = maxf(0.0, attack_cooldown_remaining - delta)
	_knockback_time_remaining = maxf(0.0, _knockback_time_remaining - delta)
	if was_dodging and not is_invulnerable() and not _dead and hurtbox_component != null:
		hurtbox_component.set_enabled(true)
	if attack_hitbox != null and attack_time_remaining == 0.0 and attack_hitbox.is_active():
		attack_hitbox.set_active(false)


func try_start_attack(input_direction: Vector3) -> bool:
	if _dead or is_invulnerable() or attack_cooldown_remaining > 0.0 or attack_hitbox == null:
		return false
	var attack_direction: Vector3 = choose_dodge_direction(input_direction, facing_direction)
	facing_direction = attack_direction
	attack_hitbox.position = attack_direction * attack_range
	attack_hitbox.set_active(true)
	attack_time_remaining = attack_duration
	attack_cooldown_remaining = attack_cooldown
	return true


func try_cycle_stance() -> bool:
	if _dead or is_invulnerable() or attack_time_remaining > 0.0:
		return false
	return element_component.cycle_next()


func is_invulnerable() -> bool:
	return dodge_time_remaining > 0.0


func is_dead() -> bool:
	return _dead


func _on_died() -> void:
	_dead = true
	velocity = Vector3.ZERO
	if _visual_tween != null:
		_visual_tween.kill()
	attack_hitbox.set_active(false)
	hurtbox_component.set_enabled(false)
	visual.modulate = Color(0.35, 0.12, 0.12, 1.0)
	_set_model_tint(Color(0.42, 0.16, 0.16))
	died.emit()


func _on_element_changed(element: int, display_name: String, color: Color) -> void:
	_base_visual_color = color.lightened(0.18)
	visual.modulate = _base_visual_color
	_set_model_tint(color.lightened(0.72))
	stance_changed.emit(element, display_name, color)


func _on_hurt(_damage: int, hit_direction: Vector3, knockback_force: float) -> void:
	_attack_requested = false
	_dodge_requested = false
	_stance_switch_requested = false
	attack_hitbox.set_active(false)
	attack_time_remaining = 0.0
	_knockback_velocity = hit_direction * knockback_force
	_knockback_time_remaining = knockback_duration if knockback_force > 0.0 else 0.0
	_flash_hurt()


func _flash_hurt() -> void:
	if _visual_tween != null:
		_visual_tween.kill()
	visual.modulate = Color.WHITE
	_visual_tween = create_tween()
	_visual_tween.tween_interval(0.05)
	_visual_tween.tween_property(visual, "modulate", _base_visual_color, 0.08)
	_set_model_emission(Color.WHITE, 1.2)
	_visual_tween.tween_callback(_set_model_emission.bind(Color.BLACK, 0.0))


func _set_model_tint(tint: Color) -> void:
	_model_tint = tint
	for index: int in _model_materials.size():
		_model_materials[index].albedo_color = _model_base_colors[index] * tint


func _set_model_emission(color: Color, energy: float) -> void:
	for material: StandardMaterial3D in _model_materials:
		material.emission_enabled = energy > 0.0
		material.emission = color
		material.emission_energy_multiplier = energy


func _on_attack_hit_resolved(
	_target_hurtbox: Area3D,
	applied_damage: int,
	multiplier: float,
	relation: int,
	attacker_element: int,
	defender_element: int
) -> void:
	attack_landed.emit(
		applied_damage, multiplier, relation, attacker_element, defender_element
	)
