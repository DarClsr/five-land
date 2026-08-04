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

@export var move_speed: float = 4.5
@export var dodge_speed: float = 10.0
@export var dodge_duration: float = 0.18
@export var dodge_cooldown: float = 0.45
@export var attack_duration: float = 0.16
@export var attack_cooldown: float = 0.32
@export var attack_range: float = 0.95
@export var knockback_duration: float = 0.14

@onready var visual: AnimatedSprite3D = $Visual
@onready var health_component: HEALTH_COMPONENT_SCRIPT = $HealthComponent
@onready var hurtbox_component: HURTBOX_COMPONENT_SCRIPT = $HurtboxComponent
@onready var attack_hitbox: HITBOX_COMPONENT_SCRIPT = $AttackHitbox
@onready var element_component: ELEMENT_COMPONENT_SCRIPT = $ElementComponent

var facing_direction: Vector3 = Vector3.FORWARD
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


func _ready() -> void:
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
			if not is_zero_approx(input_vector.x):
				visual.flip_h = input_vector.x < 0.0
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


func _update_movement_animation(direction: Vector3) -> void:
	var next_animation := animation_for_movement(direction)
	if visual.animation == next_animation:
		return
	visual.play(next_animation)
	var frame_texture := visual.sprite_frames.get_frame_texture(next_animation, 0) as AtlasTexture
	var shader_material := visual.material_override as ShaderMaterial
	shader_material.set_shader_parameter(&"albedo_texture", frame_texture.atlas)


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
