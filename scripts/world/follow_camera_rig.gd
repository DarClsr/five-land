class_name FollowCameraRig
extends Node3D

@export_range(0.1, 30.0, 0.1) var follow_speed: float = 7.0

var _target: Node3D


func _process(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	var target_position: Vector3 = _target.get_global_transform_interpolated().origin
	var weight: float = 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(target_position, weight)


func set_target(target: Node3D, snap: bool = true) -> void:
	_target = target
	if snap and is_instance_valid(_target):
		global_position = _target.global_position
		reset_physics_interpolation()


func get_target() -> Node3D:
	return _target
