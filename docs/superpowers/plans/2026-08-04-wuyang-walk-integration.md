# Wuyang Walk Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Play the accepted eight-frame Wuyang walk loop while the player moves and return to idle when movement stops.

**Architecture:** Extend the existing `AnimatedSprite3D` resource and let `PlayerController` select one of two animation names from movement direction. Reuse the current horizontal flip and visual grounding.

**Tech Stack:** Godot 4.7.1, GDScript, native `AnimatedSprite3D`, framework-free headless tests

---

### Task 1: Lock The Behavior With A Failing Test

**Files:**
- Modify: `tests/player_controller_test.gd`

- [x] Assert that `walk` has eight frames.
- [x] Assert that zero movement selects `idle` and nonzero movement selects `walk`.
- [x] Run `Godot_v4.7.1-stable_win64_console.exe --headless --path . --script tests/player_controller_test.gd` and confirm failure because `walk` and the selector do not exist.

### Task 2: Add The Minimal Runtime Integration

**Files:**
- Create: `assets/characters/wuyang/walk/wuyang_walk_iso_front_right.png`
- Modify: `scenes/actors/player.tscn`
- Modify: `scripts/actors/player_controller.gd`

- [x] Copy the accepted corrected sheet without modifying it.
- [x] Add eight 640×640 atlas regions and a looping 10 FPS `walk` animation to the existing `SpriteFrames`.
- [x] Add `animation_for_movement(direction)` returning `walk` for nonzero movement and `idle` otherwise, then apply it after velocity selection.
- [x] Re-run the focused test and confirm it passes.

### Task 3: Verify The Integrated Scene

**Files:**
- Verify: `tests/*.gd`
- Verify: `scenes/hd2d_test.tscn`

- [x] Run all six headless test scripts.
- [x] Run `Godot_v4.7.1-stable_win64_console.exe --headless --path . --quit-after 3`.
- [x] Run `git diff --check`.
- [x] Capture a 1280×720 game image and confirm walk frames advance while the feet remain grounded.
