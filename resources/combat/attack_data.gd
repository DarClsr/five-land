class_name AttackData
extends Resource

@export var damage := 25
@export var windup := 0.12
@export var active := 0.10
@export var recovery := 0.23


func total_duration() -> float:
	return windup + active + recovery
