# Combat Foundation Design

## Goal

Create the smallest repeatable real-time combat loop for Five Land: one facing-based melee attack, damage exchange with a stationary training dummy, player death, and automatic retry. Keep final art, elements, posture, combos, targeting, loot, and full enemy AI out of scope.

## Components

The player keeps movement in `PlayerController` and gains a separate `PlayerCombat` child. `PlayerCombat` owns attack timing and an `AttackData` resource containing damage, windup, active, and recovery durations. The first attack deals `25` damage with `0.12s` windup, `0.10s` active time, and `0.23s` recovery.

Reusable `HealthComponent`, `Hitbox3D`, and `Hurtbox3D` nodes handle damage independently of visuals. Health emits `health_changed`, `damaged`, and `died`. A hitbox remembers targets already hit during the current swing so overlapping physics frames cannot apply duplicate damage. `Hurtbox3D` exposes an `invulnerable` flag; the player controller keeps it synchronized with dodge state.

## Player Flow

Left click starts one attack in the player's saved facing direction. Facing is locked when the attack begins. Movement and dodge remain disabled through windup, active time, and recovery; new attacks are ignored until recovery ends. Taking damage does not interrupt an action in this first pass. `AnimationPlayer` provides only a temporary lunge and hit feedback while combat timing remains controlled by tested gameplay code.

The player starts with `100` health. On death, input and collisions stop, the placeholder visual dims, and the current scene reloads after `1.0s`. Reloading resets the player, dummy, and combat state without introducing save or checkpoint systems.

## Training Dummy

Add one stationary dummy with `100` health and a clear placeholder visual. After receiving a player hit, it aims toward the player's current position, waits `0.50s`, enables one counterattack hitbox for `0.15s`, then returns idle. The counterattack deals `25` damage and is cancelled if the dummy dies first. It does not move, chase, drop rewards, or count as the later training-enemy roadmap item.

## Validation

Add framework-free headless checks for health changes and death signals, one hit per swing, dodge invulnerability, attack timing, and scene structure. Through Godot MCP, verify four player hits defeat the dummy, dummy counterattacks reduce player health, repeated damage triggers death, and the player returns at the spawn point after automatic retry. Capture a fresh 1280x720 frame and require zero editor or game errors.
