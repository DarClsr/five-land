class_name PlayerController
extends CharacterBody3D

signal died
signal stance_changed(element: int, display_name: String, color: Color)
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
const WUYANG_WALK_ATLAS: Texture2D = preload("res://assets/characters/wuyang/pixel/wuyang_walk_8x8_v1.png")
const WUYANG_DIRECTION_PATHS := {
	&"screen_n": "res://assets/characters/wuyang/pixel/wuyang_idle_screen_n_v1.png",
	&"screen_ne": "res://assets/characters/wuyang/pixel/wuyang_idle_screen_ne_v1.png",
	&"screen_e": "res://assets/characters/wuyang/pixel/wuyang_idle_screen_e_v1.png",
	&"screen_se": "res://assets/characters/wuyang/pixel/wuyang_idle_screen_se_v1.png",
	&"screen_s": "res://assets/characters/wuyang/pixel/wuyang_idle_screen_s_v1.png",
	&"screen_sw": "res://assets/characters/wuyang/pixel/wuyang_idle_screen_sw_v1.png",
	&"screen_w": "res://assets/characters/wuyang/pixel/wuyang_idle_screen_w_v1.png",
	&"screen_nw": "res://assets/characters/wuyang/pixel/wuyang_idle_screen_nw_v1.png",
}

## Procedural sprite motion. The eight directional atlases are single-frame
## stills, so idle and walk are driven by transforming the sprite rather than
## by stepping through frames. This keeps every direction perfectly consistent
## and lets real frame animation drop in later without touching the controller.
const IDLE_BOB_HEIGHT: float = 0.018
const IDLE_BOB_HZ: float = 0.7
const IDLE_BREATH: float = 0.022
const WALK_BOB_HEIGHT: float = 0.055
## One gait cycle covers two footfalls, so the sprite bounces twice per cycle.
const WALK_CYCLE_HZ: float = 1.7
const WALK_SQUASH: float = 0.085
## How fast the pose crossfades between the idle and walk gaits.
const GAIT_BLEND_SPEED: float = 9.0
## How much the ground shadow tightens when the character is at full lift.
const SHADOW_LIFT_SHRINK: float = 0.22
## The source atlas has a deliberately chunky Q-pixel silhouette. Compressing
## only X keeps the heroine tall and readable without letting the twin blades
## dominate the corridor width.
const VISUAL_BASE_SCALE: Vector3 = Vector3(0.86, 1.0, 1.0)

@export var move_speed: float = 4.5
@export var dodge_speed: float = 10.0
@export var dodge_duration: float = 0.18
@export var dodge_cooldown: float = 0.45
@export var attack_duration: float = 0.16
@export var attack_cooldown: float = 0.32
@export var attack_range: float = 0.95
@export var knockback_duration: float = 0.14

@onready var visual: AnimatedSprite3D = $Visual
@onready var ground_shadow: Sprite3D = $GroundShadow
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
var _gait_phase: float = 0.0
var _gait_weight: float = 0.0
var _visual_rest_position: Vector3 = Vector3.ZERO
var _shadow_rest_scale: Vector3 = Vector3.ONE
var _weapon_feedback_time: float = 0.0
var _dead: bool = false


func _ready() -> void:
	_configure_directional_animations()
	visual.frame_changed.connect(_sync_visual_shader_frame)
	_visual_rest_position = visual.position
	if ground_shadow != null:
		_shadow_rest_scale = ground_shadow.scale
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
	if visual != null and visual.frame_changed.is_connected(_sync_visual_shader_frame):
		visual.frame_changed.disconnect(_sync_visual_shader_frame)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"attack"):
		_attack_requested = true
	if event.is_action_pressed(&"dodge"):
		_dodge_requested = true
	if event.is_action_pressed(&"switch_stance"):
		_stance_switch_requested = true


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


func _process(delta: float) -> void:
	_update_procedural_pose(delta)
	_weapon_feedback_time = maxf(0.0, _weapon_feedback_time - delta)
	var shader_material := visual.material_override as ShaderMaterial
	if shader_material != null:
		var feedback_ratio: float = _weapon_feedback_time / 0.3
		shader_material.set_shader_parameter(&"weapon_attack_boost", 1.0 + feedback_ratio * 2.0)


## Crossfades between a slow breathing bob and a two-step walk bounce, then
## applies the result as a vertical offset plus squash-and-stretch. Driven by
## the actual planar velocity, so dodging and knockback animate too.
func _update_procedural_pose(delta: float) -> void:
	if visual == null or _dead:
		return
	var planar_speed: float = Vector2(velocity.x, velocity.z).length()
	var target_weight: float = clampf(planar_speed / maxf(0.01, move_speed), 0.0, 1.0)
	_gait_weight = move_toward(_gait_weight, target_weight, GAIT_BLEND_SPEED * delta)
	var cycle_hz: float = lerpf(IDLE_BOB_HZ, WALK_CYCLE_HZ, _gait_weight)
	_gait_phase = fmod(_gait_phase + TAU * cycle_hz * delta, TAU)

	## abs(sin) peaks twice per cycle, which reads as one rise per footfall,
	## while the plain sine gives the idle a single slow breath per cycle.
	var bounce: float = absf(sin(_gait_phase))
	var breath: float = sin(_gait_phase) * 0.5 + 0.5
	var lift: float = lerpf(breath * IDLE_BOB_HEIGHT, bounce * WALK_BOB_HEIGHT, _gait_weight)
	visual.position = _visual_rest_position + Vector3(0.0, lift, 0.0)

	## Stretch at the top of the bounce, squash through the footfall. The width
	## moves opposite the height so the sprite keeps roughly its silhouette area.
	var squash: float = lerpf(
		breath * IDLE_BREATH, (bounce - 0.5) * 2.0 * WALK_SQUASH, _gait_weight
	)
	visual.scale = VISUAL_BASE_SCALE * Vector3(1.0 - squash * 0.6, 1.0 + squash, 1.0)

	if ground_shadow != null:
		## The shadow tightens as the character leaves the ground.
		var lift_ratio: float = clampf(lift / WALK_BOB_HEIGHT, 0.0, 1.0)
		ground_shadow.scale = _shadow_rest_scale * (1.0 - lift_ratio * SHADOW_LIFT_SHRINK)


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


func _configure_directional_animations() -> void:
	var direction_textures := _load_direction_textures()
	visual.sprite_frames = DIRECTIONAL_SPRITE_FRAMES.build_with_walk(
		direction_textures, WUYANG_WALK_ATLAS
	)
	_set_visual_shader_texture(direction_textures[&"screen_s"])
	visual.play(&"idle_screen_s")


func _load_direction_textures() -> Dictionary:
	var textures: Dictionary = {}
	for direction: StringName in WUYANG_DIRECTION_PATHS:
		var texture := load(WUYANG_DIRECTION_PATHS[direction]) as Texture2D
		assert(texture != null, "Missing Wuyang texture for %s" % direction)
		textures[direction] = texture
	return textures


func _set_visual_shader_texture(texture: Texture2D) -> void:
	var shader_material := visual.material_override as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter(&"albedo_texture", texture)


func _sync_visual_shader_frame() -> void:
	var frame_texture := visual.sprite_frames.get_frame_texture(visual.animation, visual.frame)
	if frame_texture is AtlasTexture:
		var atlas_texture := frame_texture as AtlasTexture
		_set_visual_shader_texture(atlas_texture.atlas)
	elif frame_texture != null:
		_set_visual_shader_texture(frame_texture)


func _update_movement_animation(direction: Vector3) -> void:
	var next_animation := StringName(
		"%s_%s" % [animation_for_movement(direction), facing_screen_direction]
	)
	if visual.animation == next_animation:
		return
	visual.play(next_animation)
	_sync_visual_shader_frame()


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
	_weapon_feedback_time = 0.3
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


func reset_runtime_state(spawn_transform: Transform3D) -> void:
	global_transform = spawn_transform
	_dead = false
	velocity = Vector3.ZERO
	_attack_requested = false
	_dodge_requested = false
	_stance_switch_requested = false
	attack_time_remaining = 0.0
	attack_cooldown_remaining = 0.0
	dodge_time_remaining = 0.0
	dodge_cooldown_remaining = 0.0
	_knockback_time_remaining = 0.0
	_weapon_feedback_time = 0.0
	attack_hitbox.set_active(false)
	hurtbox_component.reset()
	health_component.reset_health()
	visual.position = _visual_rest_position
	visual.scale = VISUAL_BASE_SCALE
	visual.modulate = _base_visual_color
	if ground_shadow != null:
		ground_shadow.scale = _shadow_rest_scale
	set_process(true)
	set_physics_process(true)


func _on_died() -> void:
	_dead = true
	velocity = Vector3.ZERO
	if _visual_tween != null:
		_visual_tween.kill()
	attack_hitbox.set_active(false)
	hurtbox_component.set_enabled(false)
	visual.modulate = Color(0.35, 0.12, 0.12, 1.0)
	died.emit()


func _on_element_changed(element: int, display_name: String, color: Color) -> void:
	_base_visual_color = color.lightened(0.18)
	visual.modulate = _base_visual_color
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
