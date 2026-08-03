extends SceneTree

const AttackData = preload("res://resources/combat/attack_data.gd")
const HealthComponent = preload("res://scripts/components/health_component.gd")
const Hitbox3D = preload("res://scripts/components/hitbox_3d.gd")
const Hurtbox3D = preload("res://scripts/components/hurtbox_3d.gd")

var failures := 0


func _init() -> void:
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

	if failures == 0:
		print("PASS: combat foundation")
	call_deferred("quit", failures)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
