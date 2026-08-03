extends SceneTree

const FIVE_ELEMENT_RULES = preload("res://scripts/combat/five_element_rules.gd")
const ELEMENT_COMPONENT_SCRIPT = preload("res://scripts/components/element_component.gd")
const ELEMENT_DEFINITION_SCRIPT = preload("res://scripts/combat/element_definition.gd")
const EARTH_DEFINITION = preload("res://data/elements/earth.tres")
const WATER_DEFINITION = preload("res://data/elements/water.tres")

var failures: int = 0


func _init() -> void:
	_expect(
		FIVE_ELEMENT_RULES.get_relation(
			FIVE_ELEMENT_RULES.Element.EARTH, FIVE_ELEMENT_RULES.Element.WATER
		) == FIVE_ELEMENT_RULES.Relation.OVERCOMES,
		"earth overcomes water"
	)
	_expect(
		FIVE_ELEMENT_RULES.resolve_damage(
			10, FIVE_ELEMENT_RULES.Element.EARTH, FIVE_ELEMENT_RULES.Element.WATER
		) == 15,
		"overcoming attack gains damage"
	)
	_expect(
		FIVE_ELEMENT_RULES.resolve_damage(
			10, FIVE_ELEMENT_RULES.Element.WATER, FIVE_ELEMENT_RULES.Element.EARTH
		) == 7,
		"overcome attacker loses damage"
	)
	_expect(
		FIVE_ELEMENT_RULES.resolve_damage(
			10, FIVE_ELEMENT_RULES.Element.WOOD, FIVE_ELEMENT_RULES.Element.FIRE
		) == 8,
		"generating attack is partially absorbed"
	)
	_expect(
		FIVE_ELEMENT_RULES.resolve_damage(
			10, FIVE_ELEMENT_RULES.Element.EARTH, FIVE_ELEMENT_RULES.Element.EARTH
		) == 10,
		"same element keeps neutral damage"
	)

	var component: ELEMENT_COMPONENT_SCRIPT = ELEMENT_COMPONENT_SCRIPT.new()
	var definitions: Array[ELEMENT_DEFINITION_SCRIPT] = [EARTH_DEFINITION, WATER_DEFINITION]
	component.configure(definitions)
	_expect(
		component.get_element() == FIVE_ELEMENT_RULES.Element.EARTH,
		"stance starts as earth"
	)
	_expect(component.cycle_next(), "stance cycles when two elements are available")
	_expect(
		component.get_element() == FIVE_ELEMENT_RULES.Element.WATER,
		"stance cycles from earth to water"
	)
	component.free()

	if failures == 0:
		print("PASS: five element rules")
	call_deferred("quit", failures)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
