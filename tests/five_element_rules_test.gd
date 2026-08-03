extends SceneTree

const FiveElementRules = preload("res://scripts/combat/five_element_rules.gd")

var failures := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var generation_pairs := [
		[FiveElementRules.Element.WOOD, FiveElementRules.Element.FIRE],
		[FiveElementRules.Element.FIRE, FiveElementRules.Element.EARTH],
		[FiveElementRules.Element.EARTH, FiveElementRules.Element.METAL],
		[FiveElementRules.Element.METAL, FiveElementRules.Element.WATER],
		[FiveElementRules.Element.WATER, FiveElementRules.Element.WOOD],
	]
	for pair in generation_pairs:
		_expect(FiveElementRules.generates(pair[0], pair[1]), "generation link should match")
		_expect(not FiveElementRules.generates(pair[1], pair[0]), "generation should be directional")

	var overcoming_pairs := [
		[FiveElementRules.Element.WOOD, FiveElementRules.Element.EARTH],
		[FiveElementRules.Element.EARTH, FiveElementRules.Element.WATER],
		[FiveElementRules.Element.WATER, FiveElementRules.Element.FIRE],
		[FiveElementRules.Element.FIRE, FiveElementRules.Element.METAL],
		[FiveElementRules.Element.METAL, FiveElementRules.Element.WOOD],
	]
	for pair in overcoming_pairs:
		_expect(FiveElementRules.overcomes(pair[0], pair[1]), "overcoming link should match")
		_expect(not FiveElementRules.overcomes(pair[1], pair[0]), "overcoming should be directional")

	_expect(FiveElementRules.modify_damage(0, FiveElementRules.Element.EARTH, FiveElementRules.Element.WATER) == 0, "zero damage should stay zero")
	_expect(FiveElementRules.modify_damage(-1, FiveElementRules.Element.EARTH, FiveElementRules.Element.WATER) == 0, "negative damage should become zero")
	_expect(FiveElementRules.modify_damage(25, FiveElementRules.Element.NONE, FiveElementRules.Element.WATER) == 25, "non-elemental damage should stay neutral")
	_expect(FiveElementRules.modify_damage(25, FiveElementRules.Element.EARTH, FiveElementRules.Element.EARTH) == 25, "equal elements should stay neutral")
	_expect(FiveElementRules.modify_damage(25, FiveElementRules.Element.WOOD, FiveElementRules.Element.FIRE) == 25, "generation should not modify direct damage")
	_expect(FiveElementRules.modify_damage(25, FiveElementRules.Element.EARTH, FiveElementRules.Element.WATER) == 30, "earth should deal 120 percent damage to water")
	_expect(FiveElementRules.modify_damage(25, FiveElementRules.Element.WATER, FiveElementRules.Element.EARTH) == 20, "water should deal 80 percent damage to earth")

	if failures == 0:
		print("PASS: five-element rules")
	call_deferred("quit", failures)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
