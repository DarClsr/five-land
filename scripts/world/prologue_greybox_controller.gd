class_name PrologueGreyboxController
extends Node3D

signal zone_changed(zone_name: StringName, display_name: String, objective: String)

const PLAYER_CONTROLLER_SCRIPT = preload("res://scripts/actors/player_controller.gd")
const TRAINING_ENEMY_SCRIPT = preload("res://scripts/actors/training_enemy.gd")
const ELEMENT_DEFINITION_SCRIPT = preload("res://scripts/combat/element_definition.gd")
const FOLLOW_CAMERA_RIG_SCRIPT = preload("res://scripts/world/follow_camera_rig.gd")

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


func _ready() -> void:
	camera_rig.set_target(player)
	burial_road_enemy.set_target(player)
	player.health_component.health_changed.connect(_on_player_health_changed)
	player.stance_changed.connect(_on_stance_changed)
	player.attack_landed.connect(_on_attack_landed)
	player.died.connect(_on_player_died)
	burial_road_enemy.died.connect(_on_burial_road_enemy_died)
	hit_stop_timer.timeout.connect(_on_hit_stop_finished)
	_connect_zone_triggers()
	_on_player_health_changed(player.health_component.current_health, player.health_component.max_health)
	var definition: ELEMENT_DEFINITION_SCRIPT = player.element_component.get_definition()
	_on_stance_changed(definition.element, definition.display_name, definition.color)
	_update_zone(&"DeepExit")
	status_label.text = "WASD 移动｜Q 架势｜C 换装｜V 武器｜空格闪避｜J 攻击"


func _exit_tree() -> void:
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false
	for trigger: Area3D in _trigger_callbacks:
		var callback: Callable = _trigger_callbacks[trigger]
		if is_instance_valid(trigger) and trigger.body_entered.is_connected(callback):
			trigger.body_entered.disconnect(callback)
	_trigger_callbacks.clear()
	if player != null:
		if player.health_component.health_changed.is_connected(_on_player_health_changed):
			player.health_component.health_changed.disconnect(_on_player_health_changed)
		if player.stance_changed.is_connected(_on_stance_changed):
			player.stance_changed.disconnect(_on_stance_changed)
		if player.attack_landed.is_connected(_on_attack_landed):
			player.attack_landed.disconnect(_on_attack_landed)
		if player.died.is_connected(_on_player_died):
			player.died.disconnect(_on_player_died)
	if burial_road_enemy != null and burial_road_enemy.died.is_connected(_on_burial_road_enemy_died):
		burial_road_enemy.died.disconnect(_on_burial_road_enemy_died)
	if hit_stop_timer != null and hit_stop_timer.timeout.is_connected(_on_hit_stop_finished):
		hit_stop_timer.timeout.disconnect(_on_hit_stop_finished)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"retry"):
		get_tree().reload_current_scene()


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
	if get_tree().paused:
		return
	get_tree().paused = true
	hit_stop_timer.start(0.045)


func _on_hit_stop_finished() -> void:
	get_tree().paused = false


func _on_player_died() -> void:
	status_label.text = "无央倒下了。按 R 从归墟出口重新开始"


func _on_burial_road_enemy_died() -> void:
	if _current_zone == &"BurialRoad":
		objective_label.text = "目标：道路已清理，前往封印庭院"
