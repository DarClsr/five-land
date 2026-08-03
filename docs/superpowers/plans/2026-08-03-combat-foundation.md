# Combat Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build one repeatable melee combat loop with damage, a stationary counterattacking dummy, player death, and automatic scene retry.

**Architecture:** Native Godot components separate attack data, health, hit detection, player attack timing, and dummy behavior. Existing movement remains in `PlayerController`; scene composition wires the components together without importing a third-party combat framework.

**Tech Stack:** Godot 4.7, GDScript, `Resource`, `Area3D`, `AnimationPlayer`, signals, framework-free headless self-checks.

---

### Task 1: Attack Data And Health

**Files:**
- Create: `resources/combat/attack_data.gd`
- Create: `scripts/components/health_component.gd`
- Create: `tests/combat_foundation_test.gd`

- [ ] **Step 1: Write the failing health self-check**

Create `tests/combat_foundation_test.gd`:

```gdscript
extends SceneTree

const AttackData = preload("res://resources/combat/attack_data.gd")
const HealthComponent = preload("res://scripts/components/health_component.gd")

var failures := 0


func _init() -> void:
	var attack := AttackData.new()
	_expect(attack.damage == 25, "default attack deals 25 damage")
	_expect(is_equal_approx(attack.total_duration(), 0.45), "attack totals 0.45 seconds")

	var health := HealthComponent.new()
	health.max_health = 100
	health.reset()
	var died_count := [0]
	health.died.connect(func() -> void: died_count[0] += 1)
	_expect(health.take_damage(25) == 25, "health accepts positive damage")
	_expect(health.current_health == 75, "health subtracts damage")
	_expect(health.take_damage(100) == 75, "damage clamps at zero")
	_expect(health.is_dead(), "health reports death")
	_expect(died_count[0] == 1, "death emits once")
	_expect(health.take_damage(25) == 0, "dead health ignores damage")
	health.free()

	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _finish() -> void:
	if failures == 0:
		print("PASS: combat foundation")
	call_deferred("quit", failures)
```

- [ ] **Step 2: Run the check and verify RED**

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/combat_foundation_test.gd
```

Expected: non-zero exit because both production scripts are absent.

- [ ] **Step 3: Implement attack data**

Create `resources/combat/attack_data.gd`:

```gdscript
class_name AttackData
extends Resource

@export var damage := 25
@export var windup := 0.12
@export var active := 0.10
@export var recovery := 0.23


func total_duration() -> float:
	return windup + active + recovery
```

- [ ] **Step 4: Implement health**

Create `scripts/components/health_component.gd`:

```gdscript
class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal damaged(amount: int, current: int)
signal died

@export var max_health := 100
var current_health := 0


func _ready() -> void:
	reset()


func reset() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func take_damage(amount: int) -> int:
	if amount <= 0 or is_dead():
		return 0
	var applied := mini(amount, current_health)
	current_health -= applied
	damaged.emit(applied, current_health)
	health_changed.emit(current_health, max_health)
	if current_health == 0:
		died.emit()
	return applied


func is_dead() -> bool:
	return current_health == 0
```

- [ ] **Step 5: Run GREEN and commit**

Run the Step 2 command. Expected: exit `0` with `PASS: combat foundation`.

```powershell
git add resources/combat/attack_data.gd scripts/components/health_component.gd tests/combat_foundation_test.gd
git commit -m "feat: add combat data and health"
```

### Task 2: Hitbox And Hurtbox

**Files:**
- Create: `scripts/components/hitbox_3d.gd`
- Create: `scripts/components/hurtbox_3d.gd`
- Modify: `tests/combat_foundation_test.gd`

- [ ] **Step 1: Add failing component checks**

Add preloads and these assertions before `_finish()`:

```gdscript
const Hitbox3D = preload("res://scripts/components/hitbox_3d.gd")
const Hurtbox3D = preload("res://scripts/components/hurtbox_3d.gd")

	var target_health := HealthComponent.new()
	target_health.reset()
	var hurtbox := Hurtbox3D.new()
	hurtbox.health = target_health
	var hitbox := Hitbox3D.new()
	hitbox.damage = 25
	hitbox.begin_swing()
	_expect(hitbox.try_hit(hurtbox), "first overlap deals damage")
	_expect(not hitbox.try_hit(hurtbox), "same swing cannot hit twice")
	_expect(target_health.current_health == 75, "hitbox routes damage")
	hitbox.end_swing()
	hitbox.begin_swing()
	hurtbox.invulnerable = true
	_expect(not hitbox.try_hit(hurtbox), "invulnerable hurtbox rejects damage")
	hitbox.free()
	hurtbox.free()
	target_health.free()
```

- [ ] **Step 2: Run RED**

Run the Task 1 test command. Expected: non-zero exit because hitbox scripts are absent.

- [ ] **Step 3: Implement Hurtbox3D**

```gdscript
class_name Hurtbox3D
extends Area3D

@export var health: HealthComponent
@export var actor: Node
var invulnerable := false


func receive_hit(amount: int) -> bool:
	if invulnerable or not health or health.is_dead():
		return false
	return health.take_damage(amount) > 0
```

- [ ] **Step 4: Implement Hitbox3D**

```gdscript
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
	if hit_targets.has(target_id):
		return false
	if not hurtbox.receive_hit(damage):
		return false
	hit_targets[target_id] = true
	return true


func _on_area_entered(area: Area3D) -> void:
	if area is Hurtbox3D:
		try_hit(area)
```

- [ ] **Step 5: Run GREEN and commit**

Run the Task 1 test command. Expected: exit `0` with `PASS: combat foundation`.

```powershell
git add scripts/components/hitbox_3d.gd scripts/components/hurtbox_3d.gd tests/combat_foundation_test.gd
git commit -m "feat: add 3D damage components"
```

### Task 3: Player Attack And Death Retry

**Files:**
- Create: `scripts/actors/player_combat.gd`
- Modify: `scripts/actors/player_controller.gd`
- Modify: `scenes/actors/player.tscn`
- Modify: `tests/combat_foundation_test.gd`

- [ ] **Step 1: Add a failing attack-timing check**

Preload `PlayerCombat`, then assert:

```gdscript
const PlayerCombat = preload("res://scripts/actors/player_combat.gd")

	var combat := PlayerCombat.new()
	combat.attack_data = attack
	combat.hitbox = Hitbox3D.new()
	combat.add_child(combat.hitbox)
	_expect(combat.start_attack(Vector3.LEFT), "idle player starts attack")
	_expect(combat.is_attacking(), "attack locks player")
	combat.tick_attack(attack.windup)
	_expect(combat.hitbox.monitoring, "hitbox activates after windup")
	combat.tick_attack(attack.active)
	_expect(not combat.hitbox.monitoring, "hitbox ends after active time")
	combat.tick_attack(attack.recovery)
	_expect(not combat.is_attacking(), "attack unlocks after recovery")
	combat.free()
```

- [ ] **Step 2: Run RED**

Run the combat check. Expected: non-zero exit because `player_combat.gd` is absent.

- [ ] **Step 3: Implement PlayerCombat**

Create `scripts/actors/player_combat.gd`:

```gdscript
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
```

- [ ] **Step 4: Integrate player health and control locking**

Replace `scripts/actors/player_controller.gd` with:

```gdscript
class_name PlayerController
extends CharacterBody3D

@export var move_speed := 4.5
@export var dodge_speed := 10.0
@export var dodge_duration := 0.18
@export var dodge_cooldown := 0.45

@onready var visual: Sprite3D = $Visual
@onready var combat: PlayerCombat = $PlayerCombat
@onready var health: HealthComponent = $Health
@onready var hurtbox: Hurtbox3D = $Hurtbox3D

var facing_direction := Vector3.FORWARD
var dodge_direction := Vector3.ZERO
var dodge_time_remaining := 0.0
var dodge_cooldown_remaining := 0.0


func _ready() -> void:
	health.died.connect(_on_died)


func _physics_process(delta: float) -> void:
	tick_timers(delta)
	hurtbox.invulnerable = is_invulnerable()
	if health.is_dead():
		velocity = Vector3.ZERO
		return
	if not is_invulnerable() and Input.is_action_just_pressed("attack"):
		combat.start_attack(facing_direction)
	if combat.is_attacking():
		velocity = Vector3.ZERO
		move_and_slide()
		return

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


func _on_died() -> void:
	set_physics_process(false)
	combat.cancel_attack()
	velocity = Vector3.ZERO
	$CollisionShape3D.set_deferred(&"disabled", true)
	hurtbox.set_deferred(&"monitorable", false)
	visual.modulate = Color(0.35, 0.35, 0.35, 1.0)
	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()
```

- [ ] **Step 5: Compose player scene**

Replace `scenes/actors/player.tscn` with:

```ini
[gd_scene load_steps=16 format=3]

[ext_resource type="Script" path="res://scripts/actors/player_controller.gd" id="1_controller"]
[ext_resource type="Script" path="res://scripts/components/health_component.gd" id="2_health"]
[ext_resource type="Script" path="res://scripts/components/hurtbox_3d.gd" id="3_hurtbox"]
[ext_resource type="Script" path="res://scripts/actors/player_combat.gd" id="4_combat"]
[ext_resource type="Script" path="res://scripts/components/hitbox_3d.gd" id="5_hitbox"]
[ext_resource type="Script" path="res://resources/combat/attack_data.gd" id="6_attack"]

[sub_resource type="Gradient" id="Gradient_player"]
offsets = PackedFloat32Array(0, 0.28, 0.72, 1)
colors = PackedColorArray(0.7882353, 0.72156864, 0.6, 1, 0.20392157, 0.23137255, 0.21960784, 1, 0.16470589, 0.1882353, 0.18039216, 1, 0.09019608, 0.1254902, 0.11764706, 1)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_player"]
gradient = SubResource("Gradient_player")
width = 16
height = 24

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_player"]
radius = 0.35
height = 1.8

[sub_resource type="Resource" id="AttackData_player"]
script = ExtResource("6_attack")
damage = 25
windup = 0.12
active = 0.1
recovery = 0.23

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_hurtbox"]
radius = 0.4
height = 1.8

[sub_resource type="BoxShape3D" id="BoxShape3D_hitbox"]
size = Vector3(0.9, 1.2, 1.0)

[sub_resource type="Animation" id="Animation_reset"]
resource_name = "RESET"
length = 0.0
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("Visual:scale")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {"times": PackedFloat32Array(0), "transitions": PackedFloat32Array(1), "update": 0, "values": [Vector3(1, 1, 1)]}

[sub_resource type="Animation" id="Animation_attack"]
resource_name = "attack"
length = 0.45
tracks/0/type = "value"
tracks/0/imported = false
tracks/0/enabled = true
tracks/0/path = NodePath("Visual:scale")
tracks/0/interp = 1
tracks/0/loop_wrap = true
tracks/0/keys = {"times": PackedFloat32Array(0, 0.12, 0.22, 0.45), "transitions": PackedFloat32Array(1, 1, 1, 1), "update": 0, "values": [Vector3(1, 1, 1), Vector3(1.15, 1.15, 1.15), Vector3(1.05, 1.05, 1.05), Vector3(1, 1, 1)]}

[sub_resource type="AnimationLibrary" id="AnimationLibrary_player"]
_data = {&"RESET": SubResource("Animation_reset"), &"attack": SubResource("Animation_attack")}

[node name="Player" type="CharacterBody3D" groups=["player"]]
script = ExtResource("1_controller")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
position = Vector3(0, 0.9, 0)
shape = SubResource("CapsuleShape3D_player")

[node name="Visual" type="Sprite3D" parent="."]
position = Vector3(0, 0.84, 0)
pixel_size = 0.07
billboard = 1
texture_filter = 0
texture = SubResource("GradientTexture2D_player")

[node name="Health" type="Node" parent="."]
script = ExtResource("2_health")

[node name="Hurtbox3D" type="Area3D" parent="." node_paths=PackedStringArray("health", "actor")]
collision_layer = 2
collision_mask = 0
monitoring = false
script = ExtResource("3_hurtbox")
health = NodePath("../Health")
actor = NodePath("..")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Hurtbox3D"]
position = Vector3(0, 0.9, 0)
shape = SubResource("CapsuleShape3D_hurtbox")

[node name="PlayerCombat" type="Node3D" parent="." node_paths=PackedStringArray("hitbox", "animation_player")]
script = ExtResource("4_combat")
attack_data = SubResource("AttackData_player")
hitbox = NodePath("Hitbox3D")
animation_player = NodePath("../AnimationPlayer")

[node name="Hitbox3D" type="Area3D" parent="PlayerCombat" node_paths=PackedStringArray("source_actor")]
position = Vector3(0, 0.8, -0.9)
collision_layer = 0
collision_mask = 2
monitorable = false
script = ExtResource("5_hitbox")
source_actor = NodePath("../..")

[node name="CollisionShape3D" type="CollisionShape3D" parent="PlayerCombat/Hitbox3D"]
shape = SubResource("BoxShape3D_hitbox")

[node name="AnimationPlayer" type="AnimationPlayer" parent="."]
libraries = {&"": SubResource("AnimationLibrary_player")}
```

- [ ] **Step 6: Run focused checks and commit**

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/combat_foundation_test.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/player_controller_test.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 3
```

Expected: all exit `0`; focused tests print their PASS lines.

```powershell
git add scripts/actors/player_combat.gd scripts/actors/player_controller.gd scenes/actors/player.tscn tests/combat_foundation_test.gd
git commit -m "feat: add player combat and retry"
```

### Task 4: Counterattacking Training Dummy And Verification

**Files:**
- Create: `scripts/actors/training_dummy.gd`
- Create: `scenes/actors/training_dummy.tscn`
- Modify: `scenes/hd2d_test.tscn`
- Modify: `tests/combat_foundation_test.gd`
- Modify: `TODO.md`

- [ ] **Step 1: Add failing dummy scene assertions**

Add this block before `_finish()` in `tests/combat_foundation_test.gd`:

```gdscript
	var dummy_scene := load("res://scenes/actors/training_dummy.tscn") as PackedScene
	_expect(dummy_scene != null, "loads training dummy scene")
	if dummy_scene:
		var dummy := dummy_scene.instantiate()
		root.add_child(dummy)
		_expect(dummy.get_node_or_null("Health") is HealthComponent, "dummy has health")
		_expect(dummy.get_node_or_null("Hurtbox3D") is Hurtbox3D, "dummy has hurtbox")
		var counter := dummy.get_node_or_null("CounterHitbox3D") as Hitbox3D
		_expect(counter != null, "dummy has counter hitbox")
		_expect(dummy.get_node_or_null("Visual") is Sprite3D, "dummy has visual")
		var dummy_health := dummy.get_node("Health") as HealthComponent
		dummy_health.take_damage(25)
		dummy.tick_counter(0.5)
		_expect(counter.monitoring, "counter activates after telegraph")
		dummy.tick_counter(0.15)
		_expect(not counter.monitoring, "counter ends after active window")
		dummy.queue_free()

	var level_scene := load("res://scenes/hd2d_test.tscn") as PackedScene
	var level := level_scene.instantiate()
	_expect(level.get_node_or_null("TrainingDummy") != null, "level instances training dummy")
	level.free()
```

- [ ] **Step 2: Run RED**

Run the combat check. Expected: non-zero exit because the dummy scene is absent.

- [ ] **Step 3: Implement the stationary dummy**

Create `scripts/actors/training_dummy.gd`:

```gdscript
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
```

- [ ] **Step 4: Compose and instance the dummy**

Create `scenes/actors/training_dummy.tscn`:

```ini
[gd_scene load_steps=9 format=3]

[ext_resource type="Script" path="res://scripts/actors/training_dummy.gd" id="1_dummy"]
[ext_resource type="Script" path="res://scripts/components/health_component.gd" id="2_health"]
[ext_resource type="Script" path="res://scripts/components/hurtbox_3d.gd" id="3_hurtbox"]
[ext_resource type="Script" path="res://scripts/components/hitbox_3d.gd" id="4_hitbox"]

[sub_resource type="Gradient" id="Gradient_dummy"]
offsets = PackedFloat32Array(0, 0.45, 1)
colors = PackedColorArray(0.58, 0.22, 0.16, 1, 0.22, 0.13, 0.12, 1, 0.08, 0.07, 0.07, 1)

[sub_resource type="GradientTexture2D" id="GradientTexture2D_dummy"]
gradient = SubResource("Gradient_dummy")
width = 16
height = 24

[sub_resource type="CapsuleShape3D" id="CapsuleShape3D_dummy"]
radius = 0.4
height = 1.8

[sub_resource type="BoxShape3D" id="BoxShape3D_counter"]
size = Vector3(1.0, 1.2, 1.3)

[node name="TrainingDummy" type="Node3D"]
script = ExtResource("1_dummy")

[node name="Visual" type="Sprite3D" parent="."]
position = Vector3(0, 0.84, 0)
pixel_size = 0.07
billboard = 1
texture_filter = 0
texture = SubResource("GradientTexture2D_dummy")

[node name="Health" type="Node" parent="."]
script = ExtResource("2_health")

[node name="Hurtbox3D" type="Area3D" parent="." node_paths=PackedStringArray("health", "actor")]
collision_layer = 2
collision_mask = 0
monitoring = false
script = ExtResource("3_hurtbox")
health = NodePath("../Health")
actor = NodePath("..")

[node name="CollisionShape3D" type="CollisionShape3D" parent="Hurtbox3D"]
position = Vector3(0, 0.9, 0)
shape = SubResource("CapsuleShape3D_dummy")

[node name="CounterHitbox3D" type="Area3D" parent="." node_paths=PackedStringArray("source_actor")]
position = Vector3(0, 0.8, 0.9)
collision_layer = 0
collision_mask = 2
monitorable = false
script = ExtResource("4_hitbox")
damage = 25
source_actor = NodePath("..")

[node name="CollisionShape3D" type="CollisionShape3D" parent="CounterHitbox3D"]
shape = SubResource("BoxShape3D_counter")
```

Then add this external resource near the top of `scenes/hd2d_test.tscn`:

```ini
[ext_resource type="PackedScene" path="res://scenes/actors/training_dummy.tscn" id="2_dummy"]
```

Add this instance immediately after the `Player` node:

```ini
[node name="TrainingDummy" parent="." instance=ExtResource("2_dummy")]
position = Vector3(0, 0, -0.7)
```

- [ ] **Step 5: Run Godot MCP gameplay verification**

Start the project through the active Five Land session. Confirm the player and dummy nodes are present. Drive movement and attack inputs to verify player hits reduce dummy health, dummy windup precedes counter damage, dodge avoids counter damage, four hits kill the dummy, and repeated counter damage reloads the scene after `1.0s`. Capture a fresh non-stale 1280x720 game frame; read detailed editor and game logs and require zero errors.

- [ ] **Step 6: Update roadmap and run final checks**

Mark only this item complete in `TODO.md`:

```markdown
- [x] 实现普通攻击、受伤、死亡和重试。
```

Do not mark the later training-enemy item complete because this dummy has no movement or pursuit AI.

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/combat_foundation_test.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/player_controller_test.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 3
git diff --check
```

Expected: all Godot commands exit `0`, both self-checks print PASS, and `git diff --check` prints nothing.

- [ ] **Step 7: Commit**

```powershell
git add scripts/actors/training_dummy.gd scenes/actors/training_dummy.tscn scenes/hd2d_test.tscn tests/combat_foundation_test.gd TODO.md
git commit -m "feat: complete combat foundation"
```
