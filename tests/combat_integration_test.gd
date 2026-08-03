extends SceneTree

const PlayerControllerScript = preload("res://scripts/actors/player_controller.gd")
const TrainingEnemyScript = preload("res://scripts/actors/training_enemy.gd")
const FIVE_ELEMENT_RULES = preload("res://scripts/combat/five_element_rules.gd")

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
	enemy.contact_hitbox.set_active(false)
	player.position = Vector3.ZERO
	enemy.position = Vector3(-1.0, 0.0, 0.0)
	var enemy_health_before: int = enemy.health_component.current_health
	_expect(player.try_start_attack(Vector3.LEFT), "player starts an attack")
	for _frame: int in range(4):
		await physics_frame
	_expect(
		enemy.health_component.current_health == enemy_health_before - 15,
		"earth stance gains overcoming damage against water enemy"
	)
	player.tick_timers(player.attack_cooldown)
	_expect(player.try_cycle_stance(), "player can cycle stance after attack")
	_expect(
		player.element_component.get_element() == FIVE_ELEMENT_RULES.Element.WATER,
		"Q stance cycle changes earth to water"
	)

	player.position = Vector3.ZERO
	enemy.position = Vector3(-0.4, 0.0, 0.0)
	var player_health_before: int = player.health_component.current_health
	enemy.contact_hitbox.set_active(true)
	for _frame: int in range(4):
		await physics_frame
	_expect(
		player.health_component.current_health == player_health_before - enemy.contact_hitbox.damage,
		"same-element enemy contact uses neutral damage after switching to water"
	)

	enemy.health_component.take_damage(1000)
	_expect(enemy.is_dead(), "lethal damage marks the enemy dead")
	player.health_component.take_damage(1000)
	_expect(player.is_dead(), "lethal damage marks the player dead")
	var status: Label = level.get_node("HUD/Margin/Rows/Status") as Label
	_expect(status.text.contains("按 R"), "death state exposes retry instruction")
	var stance: Label = level.get_node("HUD/Margin/Rows/Stance") as Label
	_expect(stance.text.contains("水"), "HUD shows the current water stance")

	level.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: combat integration")
	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
