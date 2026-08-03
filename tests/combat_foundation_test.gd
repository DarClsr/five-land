extends SceneTree

const AttackData = preload("res://resources/combat/attack_data.gd")
const HealthComponent = preload("res://scripts/components/health_component.gd")
const Hitbox3D = preload("res://scripts/components/hitbox_3d.gd")
const Hurtbox3D = preload("res://scripts/components/hurtbox_3d.gd")
const PlayerCombat = preload("res://scripts/actors/player_combat.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var attack_data := AttackData.new()
	_expect(attack_data.damage == 25, "AttackData default damage should be 25")
	_expect(is_equal_approx(attack_data.windup, 0.12), "AttackData default windup should be 0.12")
	_expect(is_equal_approx(attack_data.active, 0.10), "AttackData default active should be 0.10")
	_expect(is_equal_approx(attack_data.recovery, 0.23), "AttackData default recovery should be 0.23")
	_expect(is_equal_approx(attack_data.total_duration(), 0.45), "AttackData total duration should be 0.45")

	var health := HealthComponent.new()
	health.max_health = 100
	var died_count := [0]
	var health_changed_events: Array[Array] = []
	var damaged_events: Array[Array] = []
	health.health_changed.connect(func(current: int, maximum: int) -> void: health_changed_events.append([current, maximum]))
	health.damaged.connect(func(amount: int, current: int) -> void: damaged_events.append([amount, current]))
	health.died.connect(func() -> void: died_count[0] += 1)
	health.reset()
	_expect(health_changed_events == [[100, 100]], "HealthComponent reset should emit health_changed(100, 100)")
	_expect(health.take_damage(0) == 0, "HealthComponent should reject zero damage")
	_expect(health.take_damage(-1) == 0, "HealthComponent should reject negative damage")
	_expect(damaged_events.is_empty(), "Rejected damage should not emit damaged")
	_expect(health_changed_events == [[100, 100]], "Rejected damage should not emit health_changed")
	_expect(died_count[0] == 0, "Rejected damage should not emit died")
	_expect(health.take_damage(25) == 25, "HealthComponent should apply 25 damage")
	_expect(health.current_health == 75, "HealthComponent current health should be 75")
	_expect(damaged_events == [[25, 75]], "HealthComponent should emit damaged(25, 75)")
	_expect(health_changed_events == [[100, 100], [75, 100]], "HealthComponent should emit health_changed(75, 100)")
	_expect(health.take_damage(100) == 75, "HealthComponent should clamp lethal damage")
	_expect(health.is_dead(), "HealthComponent should be dead at zero health")
	_expect(died_count[0] == 1, "HealthComponent should emit died once")
	_expect(health.take_damage(1) == 0, "HealthComponent should reject damage after death")
	health.free()

	var target_health := HealthComponent.new()
	target_health.reset()
	var hurtbox := Hurtbox3D.new()
	hurtbox.health = target_health
	var hitbox := Hitbox3D.new()
	hitbox.damage = 25
	hitbox.begin_swing()
	_expect(hitbox.try_hit(hurtbox), "Hitbox3D should damage the first overlap")
	_expect(not hitbox.try_hit(hurtbox), "Hitbox3D should reject a duplicate hit in one swing")
	_expect(target_health.current_health == 75, "Hitbox3D should route damage to health")
	hitbox.end_swing()
	hitbox.begin_swing()
	hurtbox.invulnerable = true
	_expect(not hitbox.try_hit(hurtbox), "Hurtbox3D should reject damage while invulnerable")
	_expect(target_health.current_health == 75, "Invulnerability should preserve health")
	hitbox.free()
	hurtbox.free()
	target_health.free()

	var combat := PlayerCombat.new()
	combat.attack_data = attack_data
	combat.hitbox = Hitbox3D.new()
	combat.add_child(combat.hitbox)
	_expect(combat.start_attack(Vector3.LEFT), "PlayerCombat should start while idle")
	_expect(combat.is_attacking(), "PlayerCombat should lock during attack")
	combat.tick_attack(attack_data.windup)
	_expect(combat.hitbox.monitoring, "PlayerCombat should activate hitbox after windup")
	combat.tick_attack(attack_data.active)
	_expect(not combat.hitbox.monitoring, "PlayerCombat should end hitbox after active time")
	combat.tick_attack(attack_data.recovery)
	_expect(not combat.is_attacking(), "PlayerCombat should unlock after recovery")
	combat.free()

	var dummy_scene := load("res://scenes/actors/training_dummy.tscn") as PackedScene
	_expect(dummy_scene != null, "Training dummy scene should load")
	if dummy_scene:
		var dummy := dummy_scene.instantiate()
		root.add_child(dummy)
		dummy.set_physics_process(false)
		_expect(dummy.get_node_or_null("Health") is HealthComponent, "Training dummy should have health")
		_expect(dummy.get_node_or_null("Hurtbox3D") is Hurtbox3D, "Training dummy should have a hurtbox")
		var counter := dummy.get_node_or_null("CounterHitbox3D") as Hitbox3D
		_expect(counter != null, "Training dummy should have a counter hitbox")
		_expect(dummy.get_node_or_null("Visual") is Sprite3D, "Training dummy should have a visual")
		var dummy_health := dummy.get_node("Health") as HealthComponent
		dummy_health.take_damage(25)
		dummy.tick_counter(0.5)
		_expect(counter.monitoring, "Training dummy counter should activate after windup")
		dummy.tick_counter(0.15)
		_expect(not counter.monitoring, "Training dummy counter should end after active time")
		dummy.queue_free()

	var level_scene := load("res://scenes/hd2d_test.tscn") as PackedScene
	var level := level_scene.instantiate()
	_expect(level.get_node_or_null("TrainingDummy") != null, "Level should instance the training dummy")
	level.free()

	if failures == 0:
		print("PASS: combat foundation")
	call_deferred("quit", failures)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
