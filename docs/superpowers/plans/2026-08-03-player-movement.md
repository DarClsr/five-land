# Player Movement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable HD-2D player scene with camera-relative movement, persistent facing, and directional dodge.

**Architecture:** A single `CharacterBody3D` controller owns movement and dodge state. The player scene owns collision and placeholder visuals; the test level owns terrain, lighting, camera, and the player instance. Combat components remain out of scope.

**Tech Stack:** Godot 4.7, GDScript, native `CharacterBody3D`, framework-free headless self-checks.

---

### Task 1: Movement And Dodge Controller

**Files:**
- Create: `tests/player_controller_test.gd`
- Create: `scripts/actors/player_controller.gd`

- [ ] **Step 1: Write the failing self-check**

Create `tests/player_controller_test.gd`:

```gdscript
extends SceneTree

const PlayerController = preload("res://scripts/actors/player_controller.gd")

var failures := 0


func _init() -> void:
	var diagonal := PlayerController.camera_relative_direction(
		Vector2(1.0, 1.0), Vector3.RIGHT, Vector3.FORWARD
	)
	_expect_vector(diagonal, Vector3(1.0, 0.0, -1.0).normalized(), "normalizes diagonal movement")
	_expect_vector(
		PlayerController.choose_dodge_direction(Vector3.ZERO, Vector3.LEFT),
		Vector3.LEFT,
		"uses facing when dodge has no input"
	)

	var player := PlayerController.new()
	player.facing_direction = Vector3.LEFT
	_expect(player.try_start_dodge(Vector3.ZERO), "starts first dodge")
	_expect(player.is_invulnerable(), "is invulnerable during dodge")
	player.tick_timers(player.dodge_duration)
	_expect(not player.is_invulnerable(), "ends invulnerability with dodge")
	_expect(not player.try_start_dodge(Vector3.RIGHT), "blocks dodge during cooldown")
	player.tick_timers(player.dodge_cooldown - player.dodge_duration)
	_expect(player.try_start_dodge(Vector3.RIGHT), "allows dodge after cooldown")
	player.free()

	if failures == 0:
		print("PASS: player controller")
	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _expect_vector(actual: Vector3, expected: Vector3, message: String) -> void:
	_expect(actual.is_equal_approx(expected), message)
```

- [ ] **Step 2: Run the self-check and verify RED**

Run:

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/player_controller_test.gd
```

Expected: non-zero exit because `res://scripts/actors/player_controller.gd` does not exist.

- [ ] **Step 3: Implement the minimal controller**

Create `scripts/actors/player_controller.gd`:

```gdscript
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
```

- [ ] **Step 4: Run the self-check and verify GREEN**

Run the Step 2 command. Expected: exit `0` and `PASS: player controller`.

- [ ] **Step 5: Commit the controller**

```powershell
git add tests/player_controller_test.gd scripts/actors/player_controller.gd
git commit -m "feat: add player movement controller"
```

### Task 2: Reusable Player And Level Collision

**Files:**
- Create: `scenes/actors/player.tscn`
- Modify: `scenes/hd2d_test.tscn`
- Modify: `tests/player_controller_test.gd`

- [ ] **Step 1: Add a failing player-scene assertion**

Before `player.free()` in the self-check, add:

```gdscript
	var player_scene := load("res://scenes/actors/player.tscn") as PackedScene
	_expect(player_scene != null, "loads reusable player scene")
	if player_scene:
		var player_instance := player_scene.instantiate()
		_expect(player_instance is CharacterBody3D, "player scene uses CharacterBody3D")
		_expect(player_instance.get_node_or_null("CollisionShape3D") != null, "player has collision")
		_expect(player_instance.get_node_or_null("Visual") is Sprite3D, "player has HD-2D visual")
		player_instance.free()

	var level_scene := load("res://scenes/hd2d_test.tscn") as PackedScene
	var level_instance := level_scene.instantiate()
	_expect(level_instance.get_node_or_null("GroundBody/CollisionShape3D") != null, "level has ground collision")
	level_instance.free()
```

- [ ] **Step 2: Run the self-check and verify RED**

Run the Task 1 command. Expected: non-zero exit with `FAIL: loads reusable player scene` and `FAIL: level has ground collision`.

- [ ] **Step 3: Create the player scene**

Create `scenes/actors/player.tscn`:

```ini
[gd_scene load_steps=5 format=3]

[ext_resource type="Script" path="res://scripts/actors/player_controller.gd" id="1_controller"]

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

[node name="Player" type="CharacterBody3D"]
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
```

- [ ] **Step 4: Instance the player and add ground collision**

In `scenes/hd2d_test.tscn`:

```ini
[ext_resource type="PackedScene" path="res://scenes/actors/player.tscn" id="1_player"]
```

Remove the local player gradient resources and `WuyangPlaceholder`. Add:

```gdscript
[sub_resource type="BoxShape3D" id="BoxShape3D_ground"]
size = Vector3(14, 0.35, 10)

[node name="GroundBody" type="StaticBody3D" parent="."]

[node name="CollisionShape3D" type="CollisionShape3D" parent="GroundBody"]
position = Vector3(0, -0.175, 0)
shape = SubResource("BoxShape3D_ground")

[node name="Player" parent="." instance=ExtResource("1_player")]
position = Vector3(0, 0, 1)
```

- [ ] **Step 5: Run focused and scene checks**

Run:

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/player_controller_test.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 3
```

Expected: both commands exit `0`; the first prints `PASS: player controller`.

- [ ] **Step 6: Commit the scene integration**

```powershell
git add scenes/actors/player.tscn scenes/hd2d_test.tscn tests/player_controller_test.gd
git commit -m "feat: add reusable player scene"
```

### Task 3: Gameplay And Visual Verification

**Files:**
- Modify: `TODO.md`

- [ ] **Step 1: Run the project through Godot MCP**

Activate the `five-elements-land` Godot session, clear editor and game logs, and call `project_run`. Send `move_right` for one second, release it, then send `dodge`. Confirm through the running scene tree that `Player` changes position and remains inside the level bounds.

- [ ] **Step 2: Inspect the rendered result**

Capture a fresh 1280x720 game screenshot. Confirm the player is visible, remains grounded, does not blur, and is still framed by the fixed camera. Read detailed editor and game logs; expected error count is zero.

- [ ] **Step 3: Mark the completed roadmap item**

Change this line in `TODO.md`:

```markdown
- [x] 实现角色移动、朝向和闪避。
```

- [ ] **Step 4: Run final verification**

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/player_controller_test.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 3
git diff --check
```

Expected: both Godot commands exit `0`, the self-check prints `PASS: player controller`, and `git diff --check` prints nothing.

- [ ] **Step 5: Commit verification state**

```powershell
git add TODO.md
git commit -m "docs: mark player movement complete"
```
