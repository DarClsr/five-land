"""Render Wuyang's rigged Blender master into deterministic Godot atlases.

Run from the repository root:
    D:\\Blender\\blender.exe --background \
        assets/characters/wuyang/3d/source/wuyang_master_v3.blend \
        --python scripts/assets/render_wuyang_hd2d.py
"""

from __future__ import annotations

import json
import math
import tempfile
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector


CELL_SIZE = 512
FRAME_COUNT = 8
FPS = 8.0
ACTION_FRAMES = (1, 4, 7, 10, 13, 16, 19, 22)
DIRECTIONS = (
    ("screen_n", Vector((0.0, 1.0))),
    ("screen_ne", Vector((1.0, 1.0)).normalized()),
    ("screen_e", Vector((1.0, 0.0))),
    ("screen_se", Vector((1.0, -1.0)).normalized()),
    ("screen_s", Vector((0.0, -1.0))),
    ("screen_sw", Vector((-1.0, -1.0)).normalized()),
    ("screen_w", Vector((-1.0, 0.0))),
    ("screen_nw", Vector((-1.0, 1.0)).normalized()),
)
ACTIONS = (("idle", "wuyang_idle"), ("walk", "wuyang_walk"))


def repository_root() -> Path:
    blend_path = Path(bpy.data.filepath).resolve()
    return blend_path.parents[5]


def configure_scene(scene: bpy.types.Scene) -> tuple[bpy.types.Object, bpy.types.Object, bpy.types.Object]:
    camera = bpy.data.objects.get("HD2D_Camera") or bpy.data.objects.get("Camera")
    rig = bpy.data.objects["Wuyang_Rig"]
    root = rig.parent
    if root is None:
        raise RuntimeError("Wuyang_Rig must have a rotatable root parent")

    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.7
    camera.location = (4.8, -7.5, 4.8)
    camera.rotation_euler = (Vector((0.0, 0.0, 1.35)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera

    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = CELL_SIZE
    scene.render.resolution_y = CELL_SIZE
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.image_settings.color_depth = "8"
    scene.render.image_settings.compression = 15
    scene.render.resolution_percentage = 100
    scene.render.use_file_extension = True
    scene.render.filepath = ""
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.film_transparent = True
    scene.render.resolution_x = CELL_SIZE
    scene.render.resolution_y = CELL_SIZE
    scene.render.resolution_percentage = 100
    scene.render.pixel_aspect_x = 1.0
    scene.render.pixel_aspect_y = 1.0
    scene.render.use_file_extension = True
    scene.render.image_settings.file_format = "PNG"
    scene.view_settings.look = "AgX - Medium High Contrast"
    return root, rig, camera


def ensure_actions(rig: bpy.types.Object) -> None:
    """Keep both actions in the source file and rebuild the light idle if absent."""
    rig.animation_data_create()
    idle = bpy.data.actions.get("wuyang_idle")
    if idle is None:
        idle = bpy.data.actions.new("wuyang_idle")
        rig.animation_data.action = idle
        pelvis = rig.pose.bones["pelvis"]
        spine = rig.pose.bones["spine"]
        for frame, bob, sway in (
            (1, 0.0, -0.018),
            (7, 0.025, 0.0),
            (13, 0.0, 0.018),
            (19, -0.015, 0.0),
            (25, 0.0, -0.018),
        ):
            pelvis.location.z = bob
            spine.rotation_mode = "XYZ"
            spine.rotation_euler.y = sway
            pelvis.keyframe_insert(data_path="location", frame=frame, group="pelvis")
            spine.keyframe_insert(data_path="rotation_euler", frame=frame, group="spine")
        pelvis.location = (0.0, 0.0, 0.0)
        spine.rotation_euler = (0.0, 0.0, 0.0)
    idle.use_fake_user = True
    walk = bpy.data.actions.get("wuyang_walk")
    if walk is None:
        raise RuntimeError("Required action wuyang_walk is missing from the master")
    walk.use_fake_user = True


def rotation_for_screen_direction(camera: bpy.types.Object, screen_direction: Vector) -> float:
    camera_right = camera.matrix_world.to_quaternion() @ Vector((1.0, 0.0, 0.0))
    camera_forward = camera.matrix_world.to_quaternion() @ Vector((0.0, 0.0, -1.0))
    camera_right.z = 0.0
    camera_forward.z = 0.0
    camera_right.normalize()
    camera_forward.normalize()
    world_direction = (
        camera_right * screen_direction.x + camera_forward * screen_direction.y
    ).normalized()
    # The master character faces local -Y at zero rotation.
    return math.atan2(world_direction.y, world_direction.x) + math.pi * 0.5


def render_action_atlas(
    scene: bpy.types.Scene,
    root: bpy.types.Object,
    rig: bpy.types.Object,
    camera: bpy.types.Object,
    action_name: str,
    output_path: Path,
) -> None:
    atlas_size = CELL_SIZE * FRAME_COUNT
    atlas_pixels = np.zeros((atlas_size, atlas_size, 4), dtype=np.float32)
    rig.animation_data_create()
    rig.animation_data.action = bpy.data.actions[action_name]

    with tempfile.TemporaryDirectory(prefix="wuyang_hd2d_") as temporary_dir:
        for row, (_, screen_direction) in enumerate(DIRECTIONS):
            root.rotation_euler[2] = rotation_for_screen_direction(camera, screen_direction)
            for column, source_frame in enumerate(ACTION_FRAMES):
                scene.frame_set(source_frame)
                bpy.context.view_layer.update()
                frame_path = Path(temporary_dir) / f"{row}_{column}.png"
                scene.render.filepath = str(frame_path)
                bpy.ops.render.render(write_still=True)
                rendered_frame = bpy.data.images.load(str(frame_path), check_existing=False)
                pixels = np.asarray(rendered_frame.pixels[:], dtype=np.float32).reshape(
                    CELL_SIZE, CELL_SIZE, 4
                )
                bpy.data.images.remove(rendered_frame)
                # Blender pixel buffers start at the lower-left. Reverse logical rows so
                # Godot sees screen_n at the atlas's top edge.
                y0 = atlas_size - (row + 1) * CELL_SIZE
                x0 = column * CELL_SIZE
                atlas_pixels[y0 : y0 + CELL_SIZE, x0 : x0 + CELL_SIZE] = pixels
            print(f"Rendered {action_name}: {DIRECTIONS[row][0]} ({row + 1}/{len(DIRECTIONS)})")

    atlas = bpy.data.images.new(
        output_path.stem,
        width=atlas_size,
        height=atlas_size,
        alpha=True,
        float_buffer=False,
    )
    atlas.pixels.foreach_set(atlas_pixels.ravel())
    atlas.filepath_raw = str(output_path)
    atlas.file_format = "PNG"
    atlas.save()
    bpy.data.images.remove(atlas)


def write_manifest(output_dir: Path) -> None:
    source_path = Path(bpy.data.filepath).resolve()
    relative_source = source_path.relative_to(output_dir.parent).as_posix()
    manifest = {
        "version": 1,
        "cell_size": [CELL_SIZE, CELL_SIZE],
        "atlas_size": [CELL_SIZE * FRAME_COUNT, CELL_SIZE * len(DIRECTIONS)],
        "frames_per_direction": FRAME_COUNT,
        "fps": FPS,
        "row_order_top_to_bottom": [name for name, _ in DIRECTIONS],
        "column_source_frames": list(ACTION_FRAMES),
        "animations": {
            animation: f"wuyang_{animation}_8dir_atlas.png"
            for animation, _ in ACTIONS
        },
        "anchor": "cell_center; AnimatedSprite3D position aligns feet to the ground",
        "source": f"../{relative_source}",
    }
    (output_dir / "wuyang_hd2d_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


def main() -> None:
    scene = bpy.context.scene
    root, rig, camera = configure_scene(scene)
    ensure_actions(rig)
    output_dir = repository_root() / "assets" / "characters" / "wuyang" / "hd2d"
    output_dir.mkdir(parents=True, exist_ok=True)
    for animation_name, action_name in ACTIONS:
        render_action_atlas(
            scene,
            root,
            rig,
            camera,
            action_name,
            output_dir / f"wuyang_{animation_name}_8dir_atlas.png",
        )
    root.rotation_euler[2] = 0.0
    scene.frame_set(1)
    write_manifest(output_dir)
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
    print(f"HD2D atlases written to {output_dir}")


if __name__ == "__main__":
    main()
