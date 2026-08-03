class_name ElementDefinition
extends Resource

const FIVE_ELEMENT_RULES = preload("res://scripts/combat/five_element_rules.gd")

@export var element: FIVE_ELEMENT_RULES.Element = FIVE_ELEMENT_RULES.Element.EARTH
@export var display_name: String = "土"
@export var color: Color = Color.WHITE
