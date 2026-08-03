# Five-Element Rules Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a deterministic, independently tested five-element relationship and damage rules core without changing current combat behavior.

**Architecture:** One stateless GDScript owns element identifiers, generation and overcoming queries, and integer damage modification. One framework-free `SceneTree` script verifies the complete relation cycles and acceptance examples; current nodes, resources, and scenes remain untouched.

**Tech Stack:** Godot 4.7, GDScript, framework-free headless self-checks.

---

### Task 1: Five-Element Rules Core

**Files:**
- Create: `scripts/combat/five_element_rules.gd`
- Create: `tests/five_element_rules_test.gd`
- Modify: `TODO.md`

- [ ] **Step 1: Write the failing self-check**

Create `tests/five_element_rules_test.gd`:

```gdscript
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
```

- [ ] **Step 2: Run the self-check and verify RED**

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/five_element_rules_test.gd
```

Expected: non-zero exit because `scripts/combat/five_element_rules.gd` does not exist.

- [ ] **Step 3: Add the minimal rules implementation**

Create `scripts/combat/five_element_rules.gd`:

```gdscript
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
```

- [ ] **Step 4: Run GREEN and existing regressions**

```powershell
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/five_element_rules_test.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/combat_foundation_test.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/player_controller_test.gd
Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 3
```

Expected: every command exits `0`; the focused checks print their `PASS` lines and the smoke run reports no parser or resource errors.

- [ ] **Step 5: Update the roadmap**

In `TODO.md`, mark the rule-definition and rule-self-check items complete. Replace the current-next-step summary with the next approved milestone: integrate earth and water stance switching and minimal combat feedback while leaving skill trees, polished effects, and new enemy AI deferred.

- [ ] **Step 6: Verify and commit**

```powershell
git diff --check
git status --short
git add scripts/combat/five_element_rules.gd tests/five_element_rules_test.gd TODO.md
git commit -m "feat: add five-element rules core"
```

Expected: `git diff --check` prints nothing, only the planned files are staged, and the commit succeeds.
