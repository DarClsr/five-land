# HD-2D Project Skeleton Design

## Goal

Create the smallest Godot 4 project that proves the repository's HD-2D rendering direction before gameplay or final asset production begins. The result must open and run locally at 1280×720 without parser or missing-resource errors.

## Project Shape

The first implementation adds `project.godot` and one test scene under `scenes/`. The scene uses a 3D root, a simple ground plane, one low-detail landmark, directional lighting, subtle environment fog, a fixed tilted low-FOV perspective camera, and a camera-facing placeholder character plane. No movement, combat, UI, final character art, or reusable framework belongs in this slice.

## Rendering Contract

- Renderer: Forward+.
- Base viewport: 1280×720, stretch mode `canvas_items`.
- Camera: fixed tilt, low field of view, looking toward the playable ground plane.
- Character representation: pixel-art-ready camera-facing 3D surface with nearest-neighbor texture filtering when imported art is introduced.
- Environment: low-detail 3D geometry with restrained lighting, fog, and depth cues.

The placeholder exists only to verify composition and approximate character scale. The approved Wuyang test asset remains a separate follow-up: female, four-head proportion, stitched-vessel design, 96×128 transparent PNG, unarmed neutral pose.

## Validation

Use the installed Godot 4.7.1 console executable to import and run the project. Acceptance requires a clean headless startup, no parser or missing-resource errors, and one visual capture showing the ground, landmark, placeholder character, and HD-2D camera composition. Godot MCP is not available in the current session, so CLI validation is authoritative for this step; MCP integration can be added when the tool becomes available.
