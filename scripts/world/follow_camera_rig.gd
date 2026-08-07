class_name FollowCameraRig
extends Node3D

## 刚性跟随已取代距离阻尼；以下三个导出字段仅为场景与测试兼容保留。
@export_range(0.1, 30.0, 0.1) var follow_speed: float = 9.5
@export_range(0.0, 12.0, 0.1) var catchup_speed: float = 3.5
@export_range(0.0001, 0.05, 0.0001) var settle_distance: float = 0.002
@export_range(4.0, 7.5, 0.05) var presentation_size: float = 6.2
@export_range(4.0, 7.5, 0.05) var combat_size: float = 5.2
@export_range(0.2, 10.0, 0.1) var zoom_speed: float = 3.0
@export_range(0.5, 8.0, 0.1) var focus_half_width: float = 3.2
@export_range(1.0, 12.0, 0.1) var far_blur_transition: float = 6.0
## Seconds the clamped result crossfades after zone bounds switch.
@export_range(0.1, 2.0, 0.05) var bounds_transition_duration: float = 0.5

var _target: Node3D
var _last_focus_distance: float = -1.0
var _movement_bounds: Rect2 = Rect2(-100000.0, -100000.0, 200000.0, 200000.0)
var _previous_bounds: Rect2 = _movement_bounds
var _bounds_blend: float = 1.0
var _exploration_size: float = 6.2
@onready var _camera: Camera3D = $Camera3D


func _ready() -> void:
	_exploration_size = presentation_size


func _process(delta: float) -> void:
	if _camera != null and not is_equal_approx(_camera.size, presentation_size):
		var zoom_weight: float = 1.0 - exp(-zoom_speed * delta)
		_camera.size = lerpf(_camera.size, presentation_size, zoom_weight)
	if not is_instance_valid(_target):
		return
	var target_position: Vector3 = _bounded_position(
		_target.get_global_transform_interpolated().origin, delta
	)
	## 玩家移动逐帧刚性同步；区域交叉过渡只发生在 _bounded_position 的钳制结果中。
	global_position = target_position
	_update_player_focus()


func set_target(target: Node3D, snap: bool = true) -> void:
	_target = target
	if snap and is_instance_valid(_target):
		global_position = _bounded_position(_target.global_position)
		reset_physics_interpolation()
		_update_player_focus()


func get_target() -> Node3D:
	return _target


func enter_combat() -> void:
	presentation_size = combat_size


func exit_combat() -> void:
	presentation_size = _exploration_size


## Instant snap used by encounter retries: completes any in-flight bounds
## crossfade, then places the rig exactly on the target within the new bounds.
func snap_to_target() -> void:
	if not is_instance_valid(_target):
		return
	_bounds_blend = 1.0
	global_position = _clamp_to_rect(_target.global_position, _movement_bounds)
	reset_physics_interpolation()
	_update_player_focus()


func set_movement_bounds(bounds: Rect2) -> void:
	if bounds.is_equal_approx(_movement_bounds):
		return
	_previous_bounds = _movement_bounds
	_movement_bounds = bounds
	_bounds_blend = 0.0


func get_movement_bounds() -> Rect2:
	return _movement_bounds


func _bounded_position(world_position: Vector3, delta: float = 0.0) -> Vector3:
	var clamped_new: Vector3 = _clamp_to_rect(world_position, _movement_bounds)
	## Zone switches swap the clamp rect instantly, which would yank the camera
	## at boundaries like the stone bridge. Crossfade the clamped result from
	## the old rect to the new one so the rig slides into the new frame.
	if _bounds_blend < 1.0:
		_bounds_blend = minf(1.0, _bounds_blend + delta / bounds_transition_duration)
		var clamped_old: Vector3 = _clamp_to_rect(world_position, _previous_bounds)
		var t: float = smoothstep(0.0, 1.0, _bounds_blend)
		return clamped_old.lerp(clamped_new, t)
	return clamped_new


static func _clamp_to_rect(world_position: Vector3, bounds: Rect2) -> Vector3:
	var bounds_end: Vector2 = bounds.end
	world_position.x = clampf(world_position.x, bounds.position.x, bounds_end.x)
	world_position.z = clampf(world_position.z, bounds.position.y, bounds_end.y)
	return world_position


## Keeps the diorama's sharp band centred on the sprite. The camera and
## player move together, but deriving the distance here also survives future
## camera height/angle changes without hand-tuning the Environment resource.
func _update_player_focus() -> void:
	if not is_instance_valid(_target) or _camera == null:
		return
	var attributes := _camera.attributes as CameraAttributesPractical
	if attributes == null:
		return
	var focus_point: Vector3 = _target.global_position + Vector3.UP * 0.9
	var focus_distance: float = _camera.global_position.distance_to(focus_point)
	if is_equal_approx(focus_distance, _last_focus_distance):
		return
	_last_focus_distance = focus_distance
	attributes.dof_blur_near_enabled = true
	attributes.dof_blur_near_distance = maxf(0.5, focus_distance - focus_half_width)
	attributes.dof_blur_near_transition = focus_half_width
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = focus_distance + focus_half_width
	attributes.dof_blur_far_transition = far_blur_transition
