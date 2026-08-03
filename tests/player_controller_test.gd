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
	call_deferred("quit", failures)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _expect_vector(actual: Vector3, expected: Vector3, message: String) -> void:
	_expect(actual.is_equal_approx(expected), message)
