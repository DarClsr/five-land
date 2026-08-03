class_name ElementComponent
extends Node

signal element_changed(element: int, display_name: String, color: Color)

const ELEMENT_DEFINITION_SCRIPT = preload("res://scripts/combat/element_definition.gd")

@export var available_elements: Array[ELEMENT_DEFINITION_SCRIPT] = []
@export_range(0, 4, 1) var initial_index: int = 0

var current_index: int = 0


func _ready() -> void:
	if not available_elements.is_empty():
		set_index(initial_index)


func configure(definitions: Array[ELEMENT_DEFINITION_SCRIPT], start_index: int = 0) -> void:
	available_elements = definitions
	set_index(start_index)


func cycle_next() -> bool:
	if available_elements.size() < 2:
		return false
	set_index((current_index + 1) % available_elements.size())
	return true


func set_index(index: int) -> void:
	if available_elements.is_empty():
		push_error("ElementComponent requires at least one element definition.")
		return
	current_index = clampi(index, 0, available_elements.size() - 1)
	var definition: ELEMENT_DEFINITION_SCRIPT = available_elements[current_index]
	element_changed.emit(definition.element, definition.display_name, definition.color)


func get_element() -> int:
	if available_elements.is_empty():
		return -1
	return available_elements[current_index].element


func get_definition() -> ELEMENT_DEFINITION_SCRIPT:
	if available_elements.is_empty():
		return null
	return available_elements[current_index]
