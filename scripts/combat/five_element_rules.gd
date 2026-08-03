class_name FiveElementRules
extends RefCounted

enum Element {
	WOOD,
	FIRE,
	EARTH,
	METAL,
	WATER,
}

enum Relation {
	NEUTRAL,
	GENERATES,
	GENERATED_BY,
	OVERCOMES,
	OVERCOME_BY,
}

const GENERATING_MULTIPLIER: float = 0.8
const OVERCOMING_MULTIPLIER: float = 1.5
const OVERCOME_BY_MULTIPLIER: float = 0.7


static func get_relation(attacker: int, defender: int) -> Relation:
	if attacker == defender:
		return Relation.NEUTRAL
	if _generates(attacker, defender):
		return Relation.GENERATES
	if _generates(defender, attacker):
		return Relation.GENERATED_BY
	if _overcomes(attacker, defender):
		return Relation.OVERCOMES
	if _overcomes(defender, attacker):
		return Relation.OVERCOME_BY
	return Relation.NEUTRAL


static func damage_multiplier(attacker: int, defender: int) -> float:
	match get_relation(attacker, defender):
		Relation.GENERATES:
			return GENERATING_MULTIPLIER
		Relation.OVERCOMES:
			return OVERCOMING_MULTIPLIER
		Relation.OVERCOME_BY:
			return OVERCOME_BY_MULTIPLIER
		_:
			return 1.0


static func resolve_damage(base_damage: int, attacker: int, defender: int) -> int:
	if base_damage <= 0:
		return 0
	return maxi(1, roundi(float(base_damage) * damage_multiplier(attacker, defender)))


static func element_name(element: int) -> String:
	match element:
		Element.WOOD:
			return "木"
		Element.FIRE:
			return "火"
		Element.EARTH:
			return "土"
		Element.METAL:
			return "金"
		Element.WATER:
			return "水"
	return "无"


static func relation_text(attacker: int, defender: int) -> String:
	var attacker_name: String = element_name(attacker)
	var defender_name: String = element_name(defender)
	match get_relation(attacker, defender):
		Relation.GENERATES:
			return "%s生%s" % [attacker_name, defender_name]
		Relation.GENERATED_BY:
			return "%s得%s生" % [attacker_name, defender_name]
		Relation.OVERCOMES:
			return "%s克%s" % [attacker_name, defender_name]
		Relation.OVERCOME_BY:
			return "%s受%s克" % [attacker_name, defender_name]
		_:
			return "同元素"


static func _generates(source: int, target: int) -> bool:
	return (
		(source == Element.WOOD and target == Element.FIRE)
		or (source == Element.FIRE and target == Element.EARTH)
		or (source == Element.EARTH and target == Element.METAL)
		or (source == Element.METAL and target == Element.WATER)
		or (source == Element.WATER and target == Element.WOOD)
	)


static func _overcomes(source: int, target: int) -> bool:
	return (
		(source == Element.WOOD and target == Element.EARTH)
		or (source == Element.EARTH and target == Element.WATER)
		or (source == Element.WATER and target == Element.FIRE)
		or (source == Element.FIRE and target == Element.METAL)
		or (source == Element.METAL and target == Element.WOOD)
	)
