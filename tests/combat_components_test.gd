extends SceneTree

const HealthComponentScript = preload("res://scripts/components/health_component.gd")
const HurtboxComponentScript = preload("res://scripts/components/hurtbox_component.gd")
const HitboxComponentScript = preload("res://scripts/components/hitbox_component.gd")
const ElementComponentScript = preload("res://scripts/components/element_component.gd")
const TrainingEnemyScript = preload("res://scripts/actors/training_enemy.gd")

var failures: int = 0


func _init() -> void:
	_test_health_component()
	_test_hurtbox_component()
	_test_combat_scenes()

	if failures == 0:
		print("PASS: combat components")
	call_deferred("quit", failures)


func _test_health_component() -> void:
	var health: HealthComponentScript = HealthComponentScript.new()
	health.max_health = 30
	health.reset_health()
	_expect(health.current_health == 30, "health resets to maximum")
	_expect(health.take_damage(10) == 10, "damage reports applied amount")
	_expect(health.current_health == 20, "damage reduces health")
	_expect(health.heal(5) == 5, "healing reports applied amount")
	_expect(health.current_health == 25, "healing restores health")
	_expect(health.take_damage(100) == 25, "lethal damage clamps to remaining health")
	_expect(health.is_dead(), "zero health marks entity dead")
	_expect(health.take_damage(1) == 0, "dead entity ignores further damage")
	health.free()


func _test_hurtbox_component() -> void:
	var health: HealthComponentScript = HealthComponentScript.new()
	health.max_health = 20
	health.reset_health()
	var hurtbox: HurtboxComponentScript = HurtboxComponentScript.new()
	hurtbox.health_component = health
	hurtbox.invulnerability_duration = 0.2
	_expect(hurtbox.receive_hit(5), "hurtbox accepts a valid hit")
	_expect(health.current_health == 15, "hurtbox routes damage to health")
	_expect(not hurtbox.receive_hit(5), "hurtbox blocks damage during invulnerability")
	hurtbox._physics_process(0.2)
	_expect(hurtbox.receive_hit(5), "hurtbox accepts damage after invulnerability")
	hurtbox.free()
	health.free()


func _test_combat_scenes() -> void:
	var player_scene: PackedScene = load("res://scenes/actors/player.tscn") as PackedScene
	var player: Node = player_scene.instantiate()
	_expect(player.get_node_or_null("HealthComponent") is HealthComponentScript, "player has health")
	_expect(player.get_node_or_null("HurtboxComponent") is HurtboxComponentScript, "player has hurtbox")
	_expect(player.get_node_or_null("AttackHitbox") is HitboxComponentScript, "player has attack hitbox")
	_expect(player.get_node_or_null("ElementComponent") is ElementComponentScript, "player has element")
	player.free()

	var enemy_scene: PackedScene = load("res://scenes/actors/training_enemy.tscn") as PackedScene
	var enemy: Node = enemy_scene.instantiate()
	_expect(enemy is TrainingEnemyScript, "training enemy scene uses TrainingEnemy")
	_expect(enemy.get_node_or_null("HealthComponent") is HealthComponentScript, "enemy has health")
	_expect(enemy.get_node_or_null("ContactHitbox") is HitboxComponentScript, "enemy has contact hitbox")
	_expect(enemy.get_node_or_null("ElementComponent") is ElementComponentScript, "enemy has element")
	enemy.free()

	var level_scene: PackedScene = load("res://scenes/hd2d_test.tscn") as PackedScene
	var level: Node = level_scene.instantiate()
	_expect(level.get_node_or_null("TrainingEnemy") is TrainingEnemyScript, "level includes training enemy")
	_expect(level.get_node_or_null("HUD/Margin/Rows/Status") is Label, "level includes combat HUD")
	level.free()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
