# HD-2D Project Skeleton Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create and verify one runnable Godot 4 HD-2D composition scene.

**Architecture:** A single `Node3D` scene contains primitive 3D environment geometry, one billboard placeholder, lighting, fog, and a fixed low-FOV camera. Godot AI MCP performs scene edits; Godot CLI provides an independent startup check.

**Tech Stack:** Godot 4.7.1, Godot AI MCP 3.0.5, GDScript-free `.tscn` resources.

---

### Task 1: Configure the runnable project

**Files:**
- Modify: `project.godot`

- [x] Set Forward+ as the project renderer and keep the 1280×720 viewport.
- [x] Set `display/window/stretch/mode` to `canvas_items` through `project_manage(op="settings_set")`.
- [x] After the scene exists, set `application/run/main_scene` to `res://scenes/hd2d_test.tscn`.
- [x] Add `move_up`, `move_down`, `move_left`, `move_right`, `dodge`, and `attack` input bindings through `input_map_manage`.

### Task 2: Build the HD-2D composition

**Files:**
- Create: `scenes/hd2d_test.tscn`

- [x] Create a `Node3D` scene named `Main` through `scene_manage(op="create")`.
- [x] Add a broad earth-toned `BoxMesh` ground, a pale stone landmark, and two smaller framing stones.
- [x] Add a `Sprite3D` placeholder with a generated low-resolution texture, billboard mode, and a stable foot-level position.
- [x] Add `WorldEnvironment` fog plus a warm `DirectionalLight3D`.
- [x] Add a current `Camera3D` at a fixed tilt with `fov = 28`.
- [x] Save the scene and inspect the hierarchy.

### Task 3: Verify the result

**Files:**
- Verify: `project.godot`
- Verify: `scenes/hd2d_test.tscn`

- [x] Run the current scene through `project_run` and confirm the game helper becomes live.
- [x] Read editor and game logs with details; require zero parser and missing-resource errors.
- [x] Capture a cinematic screenshot showing ground, landmark, placeholder, and depth cues.
- [x] Stop the project and run:

```powershell
& $godotConsole --headless --path . --editor --quit-after 3
git diff --check
```

Expected: Godot exits successfully without parser/resource errors; `git diff --check` prints nothing.
