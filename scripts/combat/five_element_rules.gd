class_name FiveElementRules
extends RefCounted

enum Element { NONE, WOOD, FIRE, EARTH, METAL, WATER }


static func generates(source: int, target: int) -> bool:
	return [source, target] in [
		[Element.WOOD, Element.FIRE],
		[Element.FIRE, Element.EARTH],
		[Element.EARTH, Element.METAL],
		[Element.METAL, Element.WATER],
		[Element.WATER, Element.WOOD],
	]


static func overcomes(attacker: int, defender: int) -> bool:
	return [attacker, defender] in [
		[Element.WOOD, Element.EARTH],
		[Element.EARTH, Element.WATER],
		[Element.WATER, Element.FIRE],
		[Element.FIRE, Element.METAL],
		[Element.METAL, Element.WOOD],
	]


static func modify_damage(base_damage: int, attacker: int, defender: int) -> int:
	if base_damage <= 0:
		return 0
	if overcomes(attacker, defender):
		return base_damage * 6 / 5
	if overcomes(defender, attacker):
		return base_damage * 4 / 5
	return base_damage
