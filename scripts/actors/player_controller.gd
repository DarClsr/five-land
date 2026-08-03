class_name PlayerController
extends CharacterBody3D

@export var move_speed := 4.5
@export var dodge_speed := 10.0
@export var dodge_duration := 0.18
@export var dodge_cooldown := 0.45

@onready var visual: Sprite3D = $Visual

var facing_direction := Vector3.FORWARD
var dodge_direction := Vector3.ZERO
var dodge_time_remaining := 0.0
var dodge_cooldown_remaining := 0.0


func _physics_process(delta: float) -> void:
	tick_timers(delta)
	var input_vector := Input.get_vector("move_left", "move_right", "move_down", "move_up")
	var camera := get_viewport().get_camera_3d()
	var move_direction := Vector3.ZERO
	if camera:
		move_direction = camera_relative_direction(
			input_vector, camera.global_basis.x, -camera.global_basis.z
		)
	if Input.is_action_just_pressed("dodge"):
		try_start_dodge(move_direction)

	if is_invulnerable():
		velocity = dodge_direction * dodge_speed
	else:
		velocity = move_direction * move_speed
		if not move_direction.is_zero_approx():
			facing_direction = move_direction
			if not is_zero_approx(input_vector.x):
				visual.flip_h = input_vector.x < 0.0
	velocity.y = 0.0
	move_and_slide()


static func camera_relative_direction(input: Vector2, right: Vector3, forward: Vector3) -> Vector3:
	right.y = 0.0
	forward.y = 0.0
	return (right.normalized() * input.x + forward.normalized() * input.y).normalized()


static func choose_dodge_direction(input_direction: Vector3, fallback: Vector3) -> Vector3:
	if input_direction.is_zero_approx():
		return fallback.normalized()
	return input_direction.normalized()


func try_start_dodge(input_direction: Vector3) -> bool:
	if dodge_cooldown_remaining > 0.0:
		return false
	dodge_direction = choose_dodge_direction(input_direction, facing_direction)
	dodge_time_remaining = dodge_duration
	dodge_cooldown_remaining = dodge_cooldown
	return true


func tick_timers(delta: float) -> void:
	dodge_time_remaining = maxf(0.0, dodge_time_remaining - delta)
	dodge_cooldown_remaining = maxf(0.0, dodge_cooldown_remaining - delta)


func is_invulnerable() -> bool:
	return dodge_time_remaining > 0.0
