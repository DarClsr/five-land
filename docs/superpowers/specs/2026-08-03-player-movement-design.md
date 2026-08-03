# Player Movement Design

## Goal

Add the smallest playable controller for the HD-2D prototype: camera-relative movement, persistent facing, and directional dodge. Continue using the existing placeholder sprite; final animation assets remain out of scope.

## Scene Structure

Create `scenes/actors/player.tscn` as a reusable `CharacterBody3D`. Give it a capsule collision shape and keep the billboard `Sprite3D` as its visual child. Add a static collision body matching the existing ground mesh.

Keep `scenes/hd2d_test.tscn` responsible for terrain, lighting, fog, camera, and the player instance. It must not own the player's internal nodes. Future Xumen areas can instance the same player scene without duplicating controller setup.

Attach one `scripts/actors/player_controller.gd` script to the player. A state-machine abstraction is unnecessary while the controller has only normal movement and dodge states.

## Controls And Motion

- Map WASD onto the fixed camera's horizontal right and forward vectors.
- Move at `4.5 m/s` with immediate response and normalized diagonal speed.
- Remember the last non-zero movement direction as facing.
- Flip the placeholder sprite horizontally when the screen-horizontal direction changes.
- On Space, dodge in the current input direction. With no input, use the saved facing direction.
- Dodge at `10 m/s` for `0.18s`; a new dodge cannot start until `0.45s` after the previous dodge began.
- Expose the dodge's active period as invulnerable for the later damage system.

Movement remains constrained to the ground plane. Collision response uses Godot's native `CharacterBody3D.move_and_slide()` behavior.

## Extension Boundaries

Five Land will keep its gameplay core in native Godot code. Later combat work may add health, posture, element, hitbox, and hurtbox components beside the controller, but this movement change does not scaffold them early. Attack and element values will use Godot `Resource` data so combat rules remain separate from HD-2D visuals.

The Meowa HD-2D template is a presentation reference for billboards, environment, and debug tuning. Cairnfall is a reference for real-time combat timing and telegraphs. Their complete scene trees and combat systems will not be imported.

## Validation

Add one framework-free Godot self-check for normalized movement input, no-input dodge fallback, and dodge timing. Run it headlessly, smoke-run the main scene, inspect logs, and capture the game at 1280x720 to confirm the player remains visible and correctly framed.
