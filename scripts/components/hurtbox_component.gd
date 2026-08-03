class_name HurtboxComponent
extends Area3D

signal hurt(damage_amount: int, hit_direction: Vector3, knockback_force: float)

const HEALTH_COMPONENT_SCRIPT = preload("res://scripts/components/health_component.gd")
const ELEMENT_COMPONENT_SCRIPT = preload("res://scripts/components/element_component.gd")

@export var health_component: HEALTH_COMPONENT_SCRIPT
@export var element_component: ELEMENT_COMPONENT_SCRIPT
@export_range(0.0, 10.0, 0.01) var invulnerability_duration: float = 0.0

var _enabled: bool = true
var _invulnerability_remaining: float = 0.0


func _ready() -> void:
	monitoring = false
	monitorable = _enabled


func _physics_process(delta: float) -> void:
	_invulnerability_remaining = maxf(0.0, _invulnerability_remaining - delta)


func receive_hit(
	damage: int,
	hit_direction: Vector3 = Vector3.ZERO,
	knockback_force: float = 0.0
) -> bool:
	if not _enabled or damage <= 0 or is_invulnerable() or health_component == null:
		return false
	_invulnerability_remaining = invulnerability_duration
	hurt.emit(damage, hit_direction, knockback_force)
	health_component.take_damage(damage)
	return true


func set_enabled(enabled: bool) -> void:
	_enabled = enabled
	set_deferred("monitorable", enabled)


func reset() -> void:
	_invulnerability_remaining = 0.0
	set_enabled(true)


func is_invulnerable() -> bool:
	return _invulnerability_remaining > 0.0


func get_element() -> int:
	if element_component == null:
		return -1
	return element_component.get_element()
