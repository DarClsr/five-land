class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal damaged(amount: int, current: int)
signal died

@export var max_health := 100
var current_health := 0


func _ready() -> void:
	reset()


func reset() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func take_damage(amount: int) -> int:
	if amount <= 0 or is_dead():
		return 0

	var applied := mini(amount, current_health)
	current_health -= applied
	damaged.emit(applied, current_health)
	health_changed.emit(current_health, max_health)
	if is_dead():
		died.emit()
	return applied


func is_dead() -> bool:
	return current_health == 0
