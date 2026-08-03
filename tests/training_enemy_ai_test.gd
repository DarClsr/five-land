extends SceneTree

const PlayerControllerScript = preload("res://scripts/actors/player_controller.gd")
const TrainingEnemyScript = preload("res://scripts/actors/training_enemy.gd")

var failures: int = 0


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var level_scene: PackedScene = load("res://scenes/hd2d_test.tscn") as PackedScene
	var level: Node3D = level_scene.instantiate() as Node3D
	root.add_child(level)
	await physics_frame
	await physics_frame

	var player: PlayerControllerScript = level.get_node("Player") as PlayerControllerScript
	var enemy: TrainingEnemyScript = level.get_node("TrainingEnemy") as TrainingEnemyScript
	_expect(enemy.get_target() == player, "main scene injects the player target")

	player.position = Vector3(0.0, 0.0, 0.0)
	enemy.position = Vector3(4.0, 0.0, 0.0)
	await physics_frame
	var chase_start: Vector3 = enemy.position
	await physics_frame
	_expect(enemy.get_state() == TrainingEnemyScript.State.CHASE, "enemy enters chase state")
	_expect(enemy.position.x < chase_start.x, "enemy steers toward the player")

	var observed_phases: Array[int] = []
	enemy.attack_phase_changed.connect(
		func(phase: TrainingEnemyScript.AttackPhase) -> void: observed_phases.append(phase)
	)
	enemy.position = Vector3(0.9, 0.0, 0.0)
	var player_health_before: int = player.health_component.current_health
	for _frame: int in range(48):
		await physics_frame
	_expect(
		observed_phases.has(TrainingEnemyScript.AttackPhase.WINDUP),
		"enemy attack exposes a windup phase"
	)
	_expect(
		observed_phases.has(TrainingEnemyScript.AttackPhase.ACTIVE),
		"enemy attack opens an active hit window"
	)
	_expect(
		observed_phases.has(TrainingEnemyScript.AttackPhase.RECOVERY),
		"enemy attack enters recovery"
	)
	_expect(
		player.health_component.current_health < player_health_before,
		"enemy active hit window damages the player"
	)

	enemy.position = Vector3(2.0, 0.0, 0.0)
	var knockback_start: Vector3 = enemy.position
	_expect(
		enemy.hurtbox_component.receive_hit(1, Vector3.RIGHT, 4.0),
		"enemy hurtbox accepts directional damage"
	)
	_expect(enemy.get_state() == TrainingEnemyScript.State.HURT, "damage interrupts into hurt state")
	for _frame: int in range(3):
		await physics_frame
	_expect(enemy.position.x > knockback_start.x, "hurt state applies knockback movement")
	_expect(enemy.health_bar.value == enemy.health_component.current_health, "world health bar tracks health")

	enemy.health_component.take_damage(1000)
	_expect(enemy.get_state() == TrainingEnemyScript.State.DEAD, "lethal damage enters dead state")
	_expect(not enemy.contact_hitbox.is_active(), "dead enemy disables its attack hitbox")
	_expect(not enemy.health_bar_sprite.visible, "dead enemy hides its world health bar")

	level.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: training enemy AI")
	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
