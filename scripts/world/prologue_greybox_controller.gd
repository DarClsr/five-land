class_name PrologueGreyboxController
extends Node3D

signal zone_changed(zone_name: StringName, display_name: String, objective: String)

const PLAYER_CONTROLLER_SCRIPT = preload("res://scripts/actors/player_controller.gd")
const TRAINING_ENEMY_SCRIPT = preload("res://scripts/actors/training_enemy.gd")
const ELEMENT_DEFINITION_SCRIPT = preload("res://scripts/combat/element_definition.gd")
const FOLLOW_CAMERA_RIG_SCRIPT = preload("res://scripts/world/follow_camera_rig.gd")

## Bounds apply to the camera rig's X/Z centre, not to player collision. They
## keep the orthographic frame inside authored canyon walls while allowing the
## player to traverse each complete gameplay section.
const CAMERA_BOUNDS: Dictionary[StringName, Rect2] = {
	&"DeepExit": Rect2(-1.0, -4.2, 2.0, 13.2),
	&"XumenGate": Rect2(-0.8, -11.0, 1.6, 7.0),
	&"BurialRoad": Rect2(-0.3, -24.5, 0.6, 14.5),
	&"SealCourtyard": Rect2(-1.7, -40.5, 3.4, 17.0),
	&"BossArena": Rect2(-3.2, -50.5, 6.4, 11.0),
}

const ZONE_TITLES: Dictionary = {
	&"DeepExit": "归墟出口",
	&"XumenGate": "墟门",
	&"BurialRoad": "送葬道",
	&"SealCourtyard": "封印庭院",
	&"BossArena": "负碑兽场地",
}
const ZONE_OBJECTIVES: Dictionary = {
	&"DeepExit": "沿倒悬石碑桥抵达墟门",
	&"XumenGate": "穿过城门，沿送葬道调查失踪队伍",
	&"BurialRoad": "击败挡路的水行腐化者",
	&"SealCourtyard": "调查三座土行封印桩",
	&"BossArena": "灰盒终点：首领将在后续任务接入",
}

@onready var player: PLAYER_CONTROLLER_SCRIPT = $Entities/Player
@onready var burial_road_enemy: TRAINING_ENEMY_SCRIPT = $Entities/BurialRoadEnemy
@onready var camera_rig: FOLLOW_CAMERA_RIG_SCRIPT = $FollowCameraRig
@onready var triggers: Node3D = $Triggers
@onready var player_health_label: Label = $HUD/Margin/Rows/PlayerHealth
@onready var stance_label: Label = $HUD/Margin/Rows/Stance
@onready var zone_label: Label = $HUD/Margin/Rows/Zone
@onready var objective_label: Label = $HUD/Margin/Rows/Objective
@onready var status_label: Label = $HUD/Margin/Rows/Status
@onready var hit_stop_timer: Timer = $HitStopTimer

var _current_zone: StringName = &"DeepExit"
var _trigger_callbacks: Dictionary[Area3D, Callable] = {}
var _player_spawn_transform: Transform3D
var _enemy_spawn_transform: Transform3D


func _ready() -> void:
	_player_spawn_transform = player.global_transform
	_enemy_spawn_transform = burial_road_enemy.global_transform
	camera_rig.set_movement_bounds(CAMERA_BOUNDS[&"DeepExit"])
	camera_rig.set_target(player)
	burial_road_enemy.set_target(player)
	player.health_component.health_changed.connect(_on_player_health_changed)
	player.stance_changed.connect(_on_stance_changed)
	player.attack_landed.connect(_on_attack_landed)
	player.died.connect(_on_player_died)
	burial_road_enemy.died.connect(_on_burial_road_enemy_died)
	burial_road_enemy.state_changed.connect(_on_burial_road_enemy_state_changed)
	hit_stop_timer.timeout.connect(_on_hit_stop_finished)
	_connect_zone_triggers()
	_on_player_health_changed(player.health_component.current_health, player.health_component.max_health)
	var definition: ELEMENT_DEFINITION_SCRIPT = player.element_component.get_definition()
	_on_stance_changed(definition.element, definition.display_name, definition.color)
	_update_zone(&"DeepExit")
	status_label.text = "WASD 移动｜Q 架势｜空格闪避｜J 攻击"


func _exit_tree() -> void:
	_set_combat_frozen(false)
	_trigger_callbacks.clear()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"retry"):
		_reset_encounter()
		get_viewport().set_input_as_handled()


func get_current_zone() -> StringName:
	return _current_zone


func _connect_zone_triggers() -> void:
	for child: Node in triggers.get_children():
		var trigger: Area3D = child as Area3D
		if trigger == null:
			continue
		var callback: Callable = _on_zone_body_entered.bind(StringName(trigger.name))
		_trigger_callbacks[trigger] = callback
		trigger.body_entered.connect(callback)


func _on_zone_body_entered(body: Node3D, zone_name: StringName) -> void:
	if body != player:
		return
	_update_zone(zone_name)


func _update_zone(zone_name: StringName) -> void:
	if not ZONE_TITLES.has(zone_name) or not ZONE_OBJECTIVES.has(zone_name):
		return
	_current_zone = zone_name
	if CAMERA_BOUNDS.has(zone_name):
		camera_rig.set_movement_bounds(CAMERA_BOUNDS[zone_name])
	if zone_name == &"BossArena":
		camera_rig.enter_boss()
	var display_name: String = ZONE_TITLES[zone_name]
	var objective: String = ZONE_OBJECTIVES[zone_name]
	zone_label.text = "区域：%s" % display_name
	objective_label.text = "目标：%s" % objective
	zone_changed.emit(zone_name, display_name, objective)


func _on_player_health_changed(current: int, maximum: int) -> void:
	player_health_label.text = "无央生命：%d / %d" % [current, maximum]


func _on_stance_changed(_element: int, display_name: String, color: Color) -> void:
	stance_label.text = "当前架势：%s｜Q 切换" % display_name
	stance_label.modulate = color.lightened(0.28)


func _on_attack_landed(
	_applied_damage: int,
	_multiplier: float,
	_relation: int,
	_attacker_element: int,
	_defender_element: int
) -> void:
	_set_combat_frozen(true)
	hit_stop_timer.start(0.045)


func _on_hit_stop_finished() -> void:
	_set_combat_frozen(false)


func _set_combat_frozen(frozen: bool) -> void:
	for actor: Node in [player, burial_road_enemy]:
		if not is_instance_valid(actor):
			continue
		actor.set_process(not frozen)
		actor.set_physics_process(not frozen)


func _reset_encounter() -> void:
	hit_stop_timer.stop()
	_set_combat_frozen(false)
	player.reset_runtime_state(_player_spawn_transform)
	burial_road_enemy.reset_runtime_state(_enemy_spawn_transform)
	burial_road_enemy.set_target(player)
	_update_zone(&"DeepExit")
	camera_rig.exit_combat()
	## Teleporting out of the boss trigger can deliver its stale overlap signal
	## during this tick. Re-assert the destination bounds before snapping.
	camera_rig.set_movement_bounds(CAMERA_BOUNDS[&"DeepExit"])
	camera_rig.set_target(player, false)
	camera_rig.snap_to_target()
	status_label.text = "WASD 移动｜Q 架势｜空格闪避｜J 攻击"


func _on_player_died() -> void:
	status_label.text = "无央倒下了。按 R 从归墟出口重新开始"


func _on_burial_road_enemy_state_changed(_previous: int, current: int) -> void:
	if current in [
		TRAINING_ENEMY_SCRIPT.State.CHASE,
		TRAINING_ENEMY_SCRIPT.State.ATTACK,
		TRAINING_ENEMY_SCRIPT.State.HURT,
	]:
		camera_rig.enter_combat()
	elif current == TRAINING_ENEMY_SCRIPT.State.IDLE and _current_zone != &"BossArena":
		camera_rig.exit_combat()


func _on_burial_road_enemy_died() -> void:
	camera_rig.exit_combat()
	if _current_zone == &"BurialRoad":
		objective_label.text = "目标：道路已清理，前往封印庭院"
