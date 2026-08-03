class_name Hitbox3D
extends Area3D

@export var damage := 25
@export var source_actor: Node
var hit_targets: Dictionary = {}


func _ready() -> void:
	monitoring = false
	area_entered.connect(_on_area_entered)


func begin_swing() -> void:
	hit_targets.clear()
	monitoring = true


func end_swing() -> void:
	monitoring = false


func try_hit(hurtbox: Hurtbox3D) -> bool:
	if not hurtbox or (source_actor and hurtbox.actor == source_actor):
		return false
	var target_id := hurtbox.get_instance_id()
	if hit_targets.has(target_id) or not hurtbox.receive_hit(damage):
		return false
	hit_targets[target_id] = true
	return true


func _on_area_entered(area: Area3D) -> void:
	if area is Hurtbox3D:
		try_hit(area)
