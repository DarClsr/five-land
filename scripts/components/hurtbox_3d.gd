class_name Hurtbox3D
extends Area3D

@export var health: HealthComponent
@export var actor: Node
var invulnerable := false


func receive_hit(amount: int) -> bool:
	if invulnerable or not health or health.is_dead():
		return false
	return health.take_damage(amount) > 0
