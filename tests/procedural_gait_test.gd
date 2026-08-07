extends SceneTree

const PlayerController = preload("res://scripts/actors/player_controller.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 7.4, 10.2)
	camera.current = true
	root.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	var packed := load("res://scenes/actors/player.tscn") as PackedScene
	var player := packed.instantiate() as PlayerController
	root.add_child(player)
	await physics_frame
	await process_frame

	var rest_y: float = player._visual_rest_position.y
	_expect(rest_y > 0.0, "captures the sprite rest height from the scene")

	## Standing still must still breathe: the sprite height has to change over
	## time, but stay inside the small idle amplitude.
	var idle_samples: Array[float] = await _sample_visual_heights(player, 40)
	var idle_span: float = idle_samples.max() - idle_samples.min()
	_expect(idle_span > 0.0005, "idle bob moves the sprite")
	_expect(
		idle_samples.max() - rest_y <= PlayerController.IDLE_BOB_HEIGHT + 0.0001,
		"idle bob stays within the idle amplitude"
	)

	## Walking has to produce a visibly stronger bounce than idle breathing.
	Input.action_press(&"move_up")
	for _frame: int in 30:
		await physics_frame
		await process_frame
	var walk_samples: Array[float] = await _sample_visual_heights(player, 40)
	Input.action_release(&"move_up")
	var walk_span: float = walk_samples.max() - walk_samples.min()
	_expect(walk_span > idle_span * 1.5, "walk bounce is stronger than the idle bob")
	_expect(
		walk_samples.max() - rest_y <= PlayerController.WALK_BOB_HEIGHT + 0.0001,
		"walk bounce stays within the walk amplitude"
	)
	_expect(player.visual.scale.y != 1.0, "squash and stretch drives the sprite scale")
	_expect(
		player.ground_shadow.scale.x <= player._shadow_rest_scale.x + 0.0001,
		"the ground shadow never grows past its rest size"
	)

	## Coming to a stop must settle back toward the idle gait, not stay bouncing.
	for _frame: int in 40:
		await physics_frame
		await process_frame
	_expect(player._gait_weight < 0.05, "the gait blends back to idle after stopping")

	player.free()
	camera.free()
	if failures == 0:
		print("PASS: procedural gait")
	quit(failures)


func _sample_visual_heights(player: PlayerController, frames: int) -> Array[float]:
	var samples: Array[float] = []
	for _frame: int in frames:
		await physics_frame
		await process_frame
		samples.append(player.visual.position.y)
	return samples


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
