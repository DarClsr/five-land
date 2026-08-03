class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal damaged(amount: int)
signal healed(amount: int)
signal died

@export_range(1, 10000, 1) var max_health: int = 100

var current_health: int = 0
var _dead: bool = false


func _ready() -> void:
	reset_health()


func take_damage(amount: int) -> int:
	if amount <= 0 or _dead:
		return 0
	var applied_damage: int = mini(amount, current_health)
	current_health -= applied_damage
	damaged.emit(applied_damage)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		_dead = true
		died.emit()
	return applied_damage


func heal(amount: int) -> int:
	if amount <= 0 or _dead:
		return 0
	var previous_health: int = current_health
	current_health = mini(max_health, current_health + amount)
	var applied_healing: int = current_health - previous_health
	if applied_healing > 0:
		healed.emit(applied_healing)
		health_changed.emit(current_health, max_health)
	return applied_healing


func reset_health() -> void:
	_dead = false
	current_health = max_health
	health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return _dead
