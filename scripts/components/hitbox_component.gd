class_name HitboxComponent
extends Area3D

signal hit(target_hurtbox: Area3D)
signal hit_resolved(
	target_hurtbox: Area3D,
	applied_damage: int,
	multiplier: float,
	relation: int,
	attacker_element: int,
	defender_element: int
)

const HURTBOX_COMPONENT_SCRIPT = preload("res://scripts/components/hurtbox_component.gd")
const ELEMENT_COMPONENT_SCRIPT = preload("res://scripts/components/element_component.gd")
const FIVE_ELEMENT_RULES = preload("res://scripts/combat/five_element_rules.gd")

@export_range(1, 10000, 1) var damage: int = 10
@export var active_on_ready: bool = false
@export_range(0.0, 10.0, 0.01) var repeat_interval: float = 0.0
@export_range(0.0, 30.0, 0.1) var knockback_force: float = 0.0
@export var source_element_component: ELEMENT_COMPONENT_SCRIPT

var _active: bool = false
var _target_cooldowns: Dictionary[int, float] = {}


func _ready() -> void:
	monitorable = false
	set_active(active_on_ready)


func _physics_process(delta: float) -> void:
	if not _active or not monitoring:
		return
	_tick_target_cooldowns(delta)
	for area: Area3D in get_overlapping_areas():
		_try_hit(area)


func set_active(active: bool) -> void:
	if active and not _active:
		_target_cooldowns.clear()
	elif not active:
		_target_cooldowns.clear()
	_active = active
	set_deferred("monitoring", active)


func is_active() -> bool:
	return _active


func _try_hit(area: Area3D) -> void:
	if area is not HURTBOX_COMPONENT_SCRIPT:
		return
	var target: HURTBOX_COMPONENT_SCRIPT = area as HURTBOX_COMPONENT_SCRIPT
	var target_id: int = target.get_instance_id()
	if _target_cooldowns.has(target_id):
		return
	var attacker_element: int = -1
	if source_element_component != null:
		attacker_element = source_element_component.get_element()
	var defender_element: int = target.get_element()
	var multiplier: float = 1.0
	var relation: int = FIVE_ELEMENT_RULES.Relation.NEUTRAL
	var resolved_damage: int = damage
	if attacker_element >= 0 and defender_element >= 0:
		multiplier = FIVE_ELEMENT_RULES.damage_multiplier(attacker_element, defender_element)
		relation = FIVE_ELEMENT_RULES.get_relation(attacker_element, defender_element)
		resolved_damage = FIVE_ELEMENT_RULES.resolve_damage(
			damage, attacker_element, defender_element
		)
	var hit_direction: Vector3 = target.global_position - global_position
	hit_direction.y = 0.0
	hit_direction = hit_direction.normalized()
	if target.receive_hit(resolved_damage, hit_direction, knockback_force):
		hit.emit(target)
		hit_resolved.emit(
			target,
			resolved_damage,
			multiplier,
			relation,
			attacker_element,
			defender_element
		)
		_target_cooldowns[target_id] = repeat_interval if repeat_interval > 0.0 else INF


func _tick_target_cooldowns(delta: float) -> void:
	if _target_cooldowns.is_empty():
		return
	var expired_targets: Array[int] = []
	for target_id: int in _target_cooldowns:
		var remaining: float = _target_cooldowns[target_id]
		if is_inf(remaining):
			continue
		remaining -= delta
		if remaining <= 0.0:
			expired_targets.append(target_id)
		else:
			_target_cooldowns[target_id] = remaining
	for target_id: int in expired_targets:
		_target_cooldowns.erase(target_id)
