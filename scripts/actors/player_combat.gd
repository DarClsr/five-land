class_name PlayerCombat
extends Node3D

enum State { IDLE, WINDUP, ACTIVE, RECOVERY }

@export var attack_data: AttackData
@export var hitbox: Hitbox3D
@export var animation_player: AnimationPlayer

var state := State.IDLE
var state_elapsed := 0.0
var attack_direction := Vector3.FORWARD


func _ready() -> void:
	if hitbox:
		hitbox.end_swing()


func _physics_process(delta: float) -> void:
	tick_attack(delta)


func start_attack(direction: Vector3) -> bool:
	if state != State.IDLE or not attack_data or not hitbox or direction.is_zero_approx():
		return false
	attack_direction = direction.normalized()
	hitbox.position.x = attack_direction.x * 0.9
	hitbox.position.z = attack_direction.z * 0.9
	state = State.WINDUP
	state_elapsed = 0.0
	if animation_player and animation_player.has_animation(&"attack"):
		animation_player.play(&"attack")
	return true


func tick_attack(delta: float) -> void:
	if state == State.IDLE:
		return
	state_elapsed += delta
	while state != State.IDLE and state_elapsed >= _state_duration():
		state_elapsed -= _state_duration()
		_advance_state()


func is_attacking() -> bool:
	return state != State.IDLE


func cancel_attack() -> void:
	if hitbox:
		hitbox.end_swing()
	if animation_player:
		animation_player.stop()
	state = State.IDLE
	state_elapsed = 0.0


func _state_duration() -> float:
	match state:
		State.WINDUP:
			return attack_data.windup
		State.ACTIVE:
			return attack_data.active
		State.RECOVERY:
			return attack_data.recovery
	return 0.0


func _advance_state() -> void:
	match state:
		State.WINDUP:
			state = State.ACTIVE
			hitbox.damage = attack_data.damage
			hitbox.begin_swing()
		State.ACTIVE:
			state = State.RECOVERY
			hitbox.end_swing()
		State.RECOVERY:
			state = State.IDLE
			state_elapsed = 0.0
