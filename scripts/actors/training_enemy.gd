class_name TrainingEnemy
extends CharacterBody3D

signal died
signal state_changed(previous: State, current: State)
signal attack_phase_changed(phase: AttackPhase)

enum State { IDLE, CHASE, ATTACK, HURT, DEAD }
enum AttackPhase { WINDUP, ACTIVE, RECOVERY }

const HEALTH_COMPONENT_SCRIPT = preload("res://scripts/components/health_component.gd")
const HURTBOX_COMPONENT_SCRIPT = preload("res://scripts/components/hurtbox_component.gd")
const HITBOX_COMPONENT_SCRIPT = preload("res://scripts/components/hitbox_component.gd")
const ELEMENT_COMPONENT_SCRIPT = preload("res://scripts/components/element_component.gd")
const ELEMENT_DEFINITION_SCRIPT = preload("res://scripts/combat/element_definition.gd")
const WATER_DEFINITION = preload("res://data/elements/water.tres")

@export_range(0.1, 20.0, 0.1) var move_speed: float = 2.2
@export_range(0.1, 30.0, 0.1) var detection_range: float = 7.0
@export_range(0.1, 40.0, 0.1) var disengage_range: float = 9.0
@export_range(0.1, 5.0, 0.05) var attack_range: float = 1.35
@export_range(0.05, 3.0, 0.01) var windup_duration: float = 0.45
@export_range(0.01, 1.0, 0.01) var active_duration: float = 0.14
@export_range(0.05, 3.0, 0.01) var recovery_duration: float = 0.55
@export_range(0.01, 1.0, 0.01) var hurt_duration: float = 0.18

@onready var visual: Sprite3D = $Visual
@onready var body_collision: CollisionShape3D = $CollisionShape3D
@onready var health_component: HEALTH_COMPONENT_SCRIPT = $HealthComponent
@onready var hurtbox_component: HURTBOX_COMPONENT_SCRIPT = $HurtboxComponent
@onready var contact_hitbox: HITBOX_COMPONENT_SCRIPT = $ContactHitbox
@onready var element_component: ELEMENT_COMPONENT_SCRIPT = $ElementComponent
@onready var attack_tell: Sprite3D = $AttackTell
@onready var health_bar_sprite: Sprite3D = $EnemyHealthSprite

var _health_bar_material: ShaderMaterial

var _target: Node3D
var _state: State = State.IDLE
var _attack_phase: AttackPhase = AttackPhase.WINDUP
var _state_time_remaining: float = 0.0
var _knockback_velocity: Vector3 = Vector3.ZERO
var _facing_direction: Vector3 = Vector3.FORWARD
var _base_visual_color: Color = Color.WHITE
var _visual_tween: Tween


func _ready() -> void:
	var elements: Array[ELEMENT_DEFINITION_SCRIPT] = [WATER_DEFINITION]
	element_component.configure(elements)
	hurtbox_component.health_component = health_component
	hurtbox_component.element_component = element_component
	contact_hitbox.source_element_component = element_component
	contact_hitbox.set_active(false)
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	hurtbox_component.hurt.connect(_on_hurt)
	_base_visual_color = WATER_DEFINITION.color.lightened(0.12)
	visual.modulate = _base_visual_color
	_health_bar_material = (health_bar_sprite.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	health_bar_sprite.material_override = _health_bar_material
	_on_health_changed(health_component.current_health, health_component.max_health)
	_enter_state(State.IDLE)


func _exit_tree() -> void:
	if health_component != null:
		if health_component.health_changed.is_connected(_on_health_changed):
			health_component.health_changed.disconnect(_on_health_changed)
		if health_component.died.is_connected(_on_died):
			health_component.died.disconnect(_on_died)
	if hurtbox_component != null and hurtbox_component.hurt.is_connected(_on_hurt):
		hurtbox_component.hurt.disconnect(_on_hurt)


func _physics_process(delta: float) -> void:
	if _state == State.DEAD:
		return
	_state_time_remaining = maxf(0.0, _state_time_remaining - delta)
	match _state:
		State.IDLE:
			_tick_idle()
		State.CHASE:
			_tick_chase()
		State.ATTACK:
			_tick_attack()
		State.HURT:
			_tick_hurt()


func set_target(target: Node3D) -> void:
	_target = target


func get_target() -> Node3D:
	return _target


func get_state() -> State:
	return _state


func get_attack_phase() -> AttackPhase:
	return _attack_phase


func is_dead() -> bool:
	return _state == State.DEAD


func reset_runtime_state(spawn_transform: Transform3D) -> void:
	global_transform = spawn_transform
	_state = State.IDLE
	_attack_phase = AttackPhase.WINDUP
	_state_time_remaining = 0.0
	_knockback_velocity = Vector3.ZERO
	velocity = Vector3.ZERO
	contact_hitbox.set_active(false)
	attack_tell.visible = false
	hurtbox_component.reset()
	body_collision.set_deferred(&"disabled", false)
	health_component.reset_health()
	health_bar_sprite.visible = true
	visual.modulate = _base_visual_color
	set_process(true)
	set_physics_process(true)


func _tick_idle() -> void:
	_stop_moving()
	if _has_valid_target() and _horizontal_distance_to_target() <= detection_range:
		_enter_state(State.CHASE)


func _tick_chase() -> void:
	if not _has_valid_target() or _horizontal_distance_to_target() > disengage_range:
		_enter_state(State.IDLE)
		return
	if _horizontal_distance_to_target() <= attack_range:
		_enter_state(State.ATTACK)
		return
	var direction: Vector3 = _horizontal_direction_to_target()
	_face(direction)
	velocity = direction * move_speed
	velocity.y = 0.0
	move_and_slide()


func _tick_attack() -> void:
	_stop_moving()
	if _state_time_remaining > 0.0:
		return
	match _attack_phase:
		AttackPhase.WINDUP:
			_set_attack_phase(AttackPhase.ACTIVE)
		AttackPhase.ACTIVE:
			_set_attack_phase(AttackPhase.RECOVERY)
		AttackPhase.RECOVERY:
			if _has_valid_target() and _horizontal_distance_to_target() <= disengage_range:
				_enter_state(State.CHASE)
			else:
				_enter_state(State.IDLE)


func _tick_hurt() -> void:
	velocity = _knockback_velocity
	velocity.y = 0.0
	move_and_slide()
	if _state_time_remaining == 0.0:
		if _has_valid_target() and _horizontal_distance_to_target() <= disengage_range:
			_enter_state(State.CHASE)
		else:
			_enter_state(State.IDLE)


func _enter_state(next_state: State) -> void:
	if _state == State.DEAD and next_state != State.DEAD:
		return
	var previous: State = _state
	_state = next_state
	contact_hitbox.set_active(false)
	attack_tell.visible = false
	match _state:
		State.IDLE, State.CHASE:
			_state_time_remaining = 0.0
			visual.modulate = _base_visual_color
		State.ATTACK:
			var direction: Vector3 = _horizontal_direction_to_target()
			if not direction.is_zero_approx():
				_face(direction)
			_set_attack_phase(AttackPhase.WINDUP)
		State.HURT:
			_state_time_remaining = hurt_duration
		State.DEAD:
			_state_time_remaining = 0.0
			_stop_moving()
	state_changed.emit(previous, _state)


func _set_attack_phase(next_phase: AttackPhase) -> void:
	_attack_phase = next_phase
	match _attack_phase:
		AttackPhase.WINDUP:
			_state_time_remaining = windup_duration
			attack_tell.visible = true
			attack_tell.modulate = Color(1.0, 0.72, 0.2, 0.78)
			visual.modulate = _base_visual_color.lightened(0.28)
		AttackPhase.ACTIVE:
			_state_time_remaining = active_duration
			attack_tell.visible = true
			attack_tell.modulate = Color(1.0, 0.18, 0.1, 0.95)
			contact_hitbox.position = _facing_direction * 0.72
			contact_hitbox.set_active(true)
		AttackPhase.RECOVERY:
			_state_time_remaining = recovery_duration
			contact_hitbox.set_active(false)
			attack_tell.visible = false
			visual.modulate = _base_visual_color.darkened(0.12)
	attack_phase_changed.emit(_attack_phase)


func _face(direction: Vector3) -> void:
	_facing_direction = direction.normalized()
	attack_tell.position = _facing_direction * 0.72 + Vector3(0.0, 0.08, 0.0)
	if not is_zero_approx(_facing_direction.x):
		visual.flip_h = _facing_direction.x < 0.0


func _horizontal_direction_to_target() -> Vector3:
	if not _has_valid_target():
		return Vector3.ZERO
	var direction: Vector3 = _target.global_position - global_position
	direction.y = 0.0
	return direction.normalized()


func _horizontal_distance_to_target() -> float:
	if not _has_valid_target():
		return INF
	var offset: Vector3 = _target.global_position - global_position
	offset.y = 0.0
	return offset.length()


func _has_valid_target() -> bool:
	return is_instance_valid(_target) and not _target.is_queued_for_deletion()


func _stop_moving() -> void:
	velocity = Vector3.ZERO


func _on_health_changed(current: int, maximum: int) -> void:
	if _health_bar_material != null:
		_health_bar_material.set_shader_parameter(&"progress", clampf(float(current) / maxf(float(maximum), 1.0), 0.0, 1.0))


func _on_hurt(_damage: int, hit_direction: Vector3, knockback_force: float) -> void:
	if _state == State.DEAD:
		return
	_knockback_velocity = hit_direction * knockback_force
	_enter_state(State.HURT)
	_flash_hurt()


func _flash_hurt() -> void:
	if _visual_tween != null:
		_visual_tween.kill()
	visual.modulate = Color.WHITE
	_visual_tween = create_tween()
	_visual_tween.tween_interval(0.05)
	_visual_tween.tween_property(visual, "modulate", _base_visual_color, 0.08)


func _on_died() -> void:
	if _visual_tween != null:
		_visual_tween.kill()
	_enter_state(State.DEAD)
	hurtbox_component.set_enabled(false)
	body_collision.set_deferred("disabled", true)
	health_bar_sprite.visible = false
	visual.modulate = Color(0.2, 0.2, 0.2, 0.45)
	died.emit()
