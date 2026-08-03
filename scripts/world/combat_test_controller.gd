extends Node3D

const PLAYER_CONTROLLER_SCRIPT = preload("res://scripts/actors/player_controller.gd")
const TRAINING_ENEMY_SCRIPT = preload("res://scripts/actors/training_enemy.gd")
const FIVE_ELEMENT_RULES = preload("res://scripts/combat/five_element_rules.gd")
const ELEMENT_DEFINITION_SCRIPT = preload("res://scripts/combat/element_definition.gd")

@onready var player: PLAYER_CONTROLLER_SCRIPT = $Player
@onready var enemy: TRAINING_ENEMY_SCRIPT = $TrainingEnemy
@onready var player_health_label: Label = $HUD/Margin/Rows/PlayerHealth
@onready var stance_label: Label = $HUD/Margin/Rows/Stance
@onready var enemy_health_label: Label = $HUD/Margin/Rows/EnemyHealth
@onready var element_feedback_label: Label = $HUD/Margin/Rows/ElementFeedback
@onready var status_label: Label = $HUD/Margin/Rows/Status
@onready var hit_stop_timer: Timer = $HitStopTimer


func _ready() -> void:
	enemy.set_target(player)
	player.health_component.health_changed.connect(_on_player_health_changed)
	enemy.health_component.health_changed.connect(_on_enemy_health_changed)
	player.stance_changed.connect(_on_stance_changed)
	player.attack_landed.connect(_on_attack_landed)
	player.died.connect(_on_player_died)
	enemy.died.connect(_on_enemy_died)
	hit_stop_timer.timeout.connect(_on_hit_stop_finished)
	_on_player_health_changed(
		player.health_component.current_health, player.health_component.max_health
	)
	_on_enemy_health_changed(
		enemy.health_component.current_health, enemy.health_component.max_health
	)
	var definition: ELEMENT_DEFINITION_SCRIPT = player.element_component.get_definition()
	_on_stance_changed(definition.element, definition.display_name, definition.color)
	element_feedback_label.text = "土克水增伤｜水受土克减伤"
	status_label.text = "WASD 移动｜Q 切换架势｜空格闪避｜左键或 J 攻击"


func _exit_tree() -> void:
	if get_tree() != null and get_tree().paused:
		get_tree().paused = false
	if hit_stop_timer != null and hit_stop_timer.timeout.is_connected(_on_hit_stop_finished):
		hit_stop_timer.timeout.disconnect(_on_hit_stop_finished)
	if player != null:
		if player.health_component.health_changed.is_connected(_on_player_health_changed):
			player.health_component.health_changed.disconnect(_on_player_health_changed)
		if player.stance_changed.is_connected(_on_stance_changed):
			player.stance_changed.disconnect(_on_stance_changed)
		if player.attack_landed.is_connected(_on_attack_landed):
			player.attack_landed.disconnect(_on_attack_landed)
		if player.died.is_connected(_on_player_died):
			player.died.disconnect(_on_player_died)
	if enemy != null:
		if enemy.health_component.health_changed.is_connected(_on_enemy_health_changed):
			enemy.health_component.health_changed.disconnect(_on_enemy_health_changed)
		if enemy.died.is_connected(_on_enemy_died):
			enemy.died.disconnect(_on_enemy_died)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"retry"):
		get_tree().reload_current_scene()


func _on_player_health_changed(current: int, maximum: int) -> void:
	player_health_label.text = "无咎生命：%d / %d" % [current, maximum]


func _on_enemy_health_changed(current: int, maximum: int) -> void:
	var element_name: String = FIVE_ELEMENT_RULES.element_name(
		enemy.element_component.get_element()
	)
	enemy_health_label.text = "训练敌人（%s）：%d / %d" % [element_name, current, maximum]


func _on_stance_changed(_element: int, display_name: String, color: Color) -> void:
	stance_label.text = "当前架势：%s｜Q 切换" % display_name
	stance_label.modulate = color.lightened(0.28)


func _on_attack_landed(
	applied_damage: int,
	multiplier: float,
	_relation: int,
	attacker_element: int,
	defender_element: int
) -> void:
	var relation_text: String = FIVE_ELEMENT_RULES.relation_text(
		attacker_element, defender_element
	)
	element_feedback_label.text = "%s｜×%.1f｜造成 %d 伤害" % [
		relation_text, multiplier, applied_damage
	]
	_start_hit_stop(0.045)
	if multiplier > 1.0:
		element_feedback_label.modulate = Color(0.58, 1.0, 0.62, 1.0)
	elif multiplier < 1.0:
		element_feedback_label.modulate = Color(1.0, 0.58, 0.5, 1.0)
	else:
		element_feedback_label.modulate = Color.WHITE


func _on_player_died() -> void:
	status_label.text = "无咎倒下了。按 R 重新挑战"


func _on_enemy_died() -> void:
	status_label.text = "训练敌人已击败。按 R 重新挑战"


func _start_hit_stop(duration: float) -> void:
	if duration <= 0.0 or get_tree().paused:
		return
	get_tree().paused = true
	hit_stop_timer.start(duration)


func _on_hit_stop_finished() -> void:
	get_tree().paused = false
