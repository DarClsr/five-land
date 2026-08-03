# Five-Element Rules Design

## Goal

Add a framework-free five-element rules core that can be tested without scenes or nodes. Preserve all existing non-elemental combat behavior and defer stance integration until the rule checks pass.

## Rules

Define six identifiers: `NONE`, `WOOD`, `FIRE`, `EARTH`, `METAL`, and `WATER`.

Generation follows wood to fire, fire to earth, earth to metal, metal to water, and water to wood. Overcoming follows wood over earth, earth over water, water over fire, fire over metal, and metal over wood.

Generation is queryable but does not modify direct damage in this milestone. One function calculates integer damage from base damage and the attacker and defender elements:

- Non-positive base damage returns `0`.
- `NONE`, equal elements, generation, and unrelated pairs keep `100%` damage.
- An attacker that overcomes the defender deals `120%` damage.
- An attacker overcome by the defender deals `80%` damage.

Integer arithmetic keeps results deterministic. A base attack of `25` remains `25` without elements, earth against water deals `30`, and water against earth deals `20`.

## Structure And Data Flow

Create one stateless GDScript containing the identifiers, relationship queries, and damage calculation. It depends only on Godot built-ins. Callers pass plain integer values and receive an integer result; no nodes, resources, signals, or global state are added.

The current `AttackData`, hitboxes, hurtboxes, scenes, and attacks remain unchanged. Earth and water stance data will consume this API in the next milestone.

## Validation

Add one framework-free headless test script covering every generation and overcoming link, reverse-direction checks, neutral behavior, non-positive damage, and the `25/30/20` acceptance examples. Run the existing combat checks as regression coverage.

## Out Of Scope

Do not add stance switching, scene wiring, UI, effects, skill trees, status effects, resistances, or new enemy behavior.
