extends SceneTree

const PlayerController = preload("res://scripts/actors/player_controller.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(8.6, 7.4, 10.2)
	camera.current = true
	root.add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	var packed := load("res://scenes/actors/player.tscn") as PackedScene
	var player := packed.instantiate() as PlayerController
	root.add_child(player)
	await physics_frame

	var cases: Array[Dictionary] = [
		{"action": &"move_up", "direction": &"screen_n", "key": "W"},
		{"action": &"move_left", "direction": &"screen_w", "key": "A"},
		{"action": &"move_down", "direction": &"screen_s", "key": "S"},
		{"action": &"move_right", "direction": &"screen_e", "key": "D"},
	]
	for test_case: Dictionary in cases:
		var action := test_case["action"] as StringName
		Input.action_press(action)
		for _frame: int in 24:
			await physics_frame
		Input.action_release(action)
		await physics_frame
		var expected := test_case["direction"] as StringName
		_expect(
			player.facing_screen_direction == expected,
			"%s records the %s screen direction" % [test_case["key"], expected]
		)
		_expect(
			player.visual.animation == StringName("idle_%s" % expected),
			"%s keeps the %s sprite direction after stopping" % [
				test_case["key"], expected
			]
		)

	player.free()
	camera.free()
	if failures == 0:
		print("PASS: player WASD sprite-facing integration")
	quit(failures)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
