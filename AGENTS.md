# Repository Guidelines

## Project Structure & Module Organization

This repository contains the design foundation and Godot 4 prototype for **Five Land**. `project.godot` defines the project, `scenes/` contains playable scenes, and `addons/godot_ai/` provides the editor MCP integration. `README.md` is the project entry point, `TODO.md` tracks the vertical slice, and `docs/` holds world, art, character, story, and implementation specifications. Keep final game assets in purpose-specific directories when introduced; do not place them inside the addon.

## Development & Validation Commands

Run these commands from the repository root with Godot 4.7+ available as `godot`:

```powershell
godot --editor --path .
godot --headless --path . --quit-after 3
git diff --check
```

The first command opens the editor and Godot AI dock. The second smoke-runs the main scene headlessly; it must exit without parser or resource errors. `git diff --check` catches whitespace errors.

## Coding Style & Naming Conventions

Write Markdown with ATX headings (`#`, `##`) and short sections. Preserve Chinese narrative terminology and full-width punctuation. Use kebab-case for documents such as `docs/world-map-and-art.md`, and snake_case for scenes and future GDScript files such as `scenes/hd2d_test.tscn`. Use PascalCase for Godot node names (`MainCamera`) and snake_case for script members. Keep quest IDs stable: main quests use `FL-P00`; side quests use `FL-S01`.

## Testing Guidelines

No automated suite or coverage target exists yet. For scene changes, run the headless smoke command, inspect Godot editor/game logs, and attach a 1280×720 screenshot. Review documentation links, headings, tables, Mermaid diagrams, and terminology. Future gameplay logic must add the focused self-checks listed in `TODO.md`, especially five-element rules, health, and quest order.

## Commit & Pull Request Guidelines

Recent commits use Conventional Commit-style prefixes with imperative summaries, such as `docs: detail Xumen prologue quests` and `chore: initialize five land`. Keep each commit limited to one coherent change. Pull requests should explain the scope, list affected documents or systems, and note validation performed. Link the relevant issue or `TODO.md` item. Include screenshots or recordings for future scene, UI, animation, or visual-effect changes; they are unnecessary for text-only edits.
