class_name TrainingDummy
extends Node3D

enum State { IDLE, WINDUP, ACTIVE }

@export var counter_windup := 0.5
@export var counter_active := 0.15

@onready var health: HealthComponent = $Health
@onready var hurtbox: Hurtbox3D = $Hurtbox3D
@onready var counter_hitbox: Hitbox3D = $CounterHitbox3D
@onready var visual: Sprite3D = $Visual

var state := State.IDLE
var state_elapsed := 0.0


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	counter_hitbox.damage = 25
	counter_hitbox.end_swing()


func _physics_process(delta: float) -> void:
	tick_counter(delta)


func tick_counter(delta: float) -> void:
	if state == State.IDLE:
		return
	state_elapsed += delta
	if state == State.WINDUP and state_elapsed >= counter_windup:
		state_elapsed -= counter_windup
		state = State.ACTIVE
		counter_hitbox.begin_swing()
	if state == State.ACTIVE and state_elapsed >= counter_active:
		counter_hitbox.end_swing()
		state = State.IDLE
		state_elapsed = 0.0
		visual.modulate = Color.WHITE


func _on_damaged(_amount: int, _current: int) -> void:
	if state != State.IDLE or health.is_dead():
		return
	var target := get_tree().get_first_node_in_group(&"player") as Node3D
	if target:
		var direction := target.global_position - global_position
		direction.y = 0.0
		if not direction.is_zero_approx():
			direction = direction.normalized()
			counter_hitbox.position.x = direction.x * 0.9
			counter_hitbox.position.z = direction.z * 0.9
	state = State.WINDUP
	state_elapsed = 0.0
	visual.modulate = Color(1.0, 0.55, 0.35, 1.0)


func _on_died() -> void:
	state = State.IDLE
	state_elapsed = 0.0
	counter_hitbox.end_swing()
	hurtbox.set_deferred(&"monitorable", false)
	visual.modulate = Color(0.25, 0.25, 0.25, 1.0)
