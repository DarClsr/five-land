"""Create the black high-ponytail Wuyang 3D style prototype.

Run from the repository root:
    D:\\Blender\\blender.exe --background \
        assets/characters/wuyang/3d/source/wuyang_master_v3.blend \
        --python scripts/assets/refine_wuyang_v4_ponytail.py
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


PREFIX = "V4_"


def repository_root() -> Path:
    return Path(bpy.data.filepath).resolve().parents[5]


def set_material_color(name: str, color: tuple[float, float, float, float]) -> None:
    material = bpy.data.materials[name]
    material.diffuse_color = color
    material.roughness = 0.82
    if material.use_nodes:
        principled = material.node_tree.nodes.get("Principled BSDF")
        if principled is not None:
            principled.inputs["Base Color"].default_value = color
            principled.inputs["Roughness"].default_value = material.roughness


def configure_palette() -> None:
    set_material_color("M_HairWhite", (0.008, 0.010, 0.014, 1.0))
    set_material_color("M_HairShadow", (0.022, 0.026, 0.038, 1.0))
    set_material_color("M_BlueGray", (0.055, 0.070, 0.100, 1.0))
    set_material_color("M_InkBlue", (0.022, 0.035, 0.060, 1.0))
    set_material_color("M_GrayWhite", (0.16, 0.17, 0.19, 1.0))
    set_material_color("M_Charcoal", (0.015, 0.018, 0.025, 1.0))
    set_material_color("M_Cinnabar", (0.42, 0.035, 0.030, 1.0))
    set_material_color("M_Skin", (0.78, 0.53, 0.42, 1.0))
    set_material_color("M_CyanEye", (0.16, 0.075, 0.035, 1.0))
    dagger = bpy.data.materials["M_Dagger"]
    dagger.diffuse_color = (0.18, 0.19, 0.21, 1.0)
    dagger.metallic = 0.72
    dagger.roughness = 0.32
    if dagger.use_nodes:
        principled = dagger.node_tree.nodes.get("Principled BSDF")
        if principled is not None:
            principled.inputs["Base Color"].default_value = dagger.diffuse_color
            principled.inputs["Metallic"].default_value = dagger.metallic
            principled.inputs["Roughness"].default_value = dagger.roughness


def rigid_parent(obj: bpy.types.Object, rig: bpy.types.Object, bone_name: str) -> None:
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    obj.matrix_world = world


def add_ellipsoid(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material_name: str,
    rig: bpy.types.Object,
    bone_name: str,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=2, radius=1.0, location=location, rotation=rotation
    )
    obj = bpy.context.object
    obj.name = PREFIX + name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(bpy.data.materials[material_name])
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    rigid_parent(obj, rig, bone_name)
    return obj


def add_tapered_ribbon(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    rotation: tuple[float, float, float],
    rig: bpy.types.Object,
) -> None:
    bpy.ops.mesh.primitive_cone_add(
        vertices=4,
        radius1=1.0,
        radius2=0.28,
        depth=2.0,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = PREFIX + name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(bpy.data.materials["M_Cinnabar"])
    rigid_parent(obj, rig, "head")


def remove_old_side_braids() -> None:
    for obj in list(bpy.data.objects):
        if obj.name.startswith("Braid"):
            bpy.data.objects.remove(obj, do_unlink=True)


def remove_legacy_face_parts() -> None:
    # v3 added a smaller authored face without deleting the v2 eye spheres.
    # Keeping both sets creates the wide, startled expression seen in old previews.
    for name in ("EyeL", "EyeR"):
        obj = bpy.data.objects.get(name)
        if obj is not None:
            bpy.data.objects.remove(obj, do_unlink=True)


def mature_head_proportions(rig: bpy.types.Object) -> None:
    head_pivot = (rig.matrix_world @ rig.pose.bones["head"].matrix).translation
    for obj in bpy.data.objects:
        if obj.type != "MESH" or obj.parent_bone != "head":
            continue
        world = obj.matrix_world.copy()
        offset = world.translation - head_pivot
        world.translation = head_pivot + offset * 0.89
        obj.matrix_world = world
        obj.scale *= 0.89


def build_high_ponytail(rig: bpy.types.Object) -> None:
    # A large top knot and a curved chain of tapered locks make the hairstyle
    # readable from the game's elevated orthographic camera.
    add_ellipsoid("TopKnot", (0.0, 0.105, 2.82), (0.15, 0.16, 0.13), "M_HairWhite", rig, "head")
    add_ellipsoid("Ponytail01", (0.0, 0.26, 2.78), (0.15, 0.24, 0.22), "M_HairWhite", rig, "head", (0.18, 0.0, 0.0))
    add_ellipsoid("Ponytail02", (0.035, 0.43, 2.57), (0.135, 0.22, 0.25), "M_HairWhite", rig, "head", (0.42, 0.0, -0.08))
    add_ellipsoid("Ponytail03", (-0.01, 0.51, 2.31), (0.115, 0.18, 0.25), "M_HairShadow", rig, "head", (0.58, 0.0, 0.08))
    add_ellipsoid("PonytailTip", (-0.05, 0.52, 2.08), (0.075, 0.12, 0.20), "M_HairWhite", rig, "head", (0.68, 0.0, 0.12))
    add_ellipsoid("HairTie", (0.0, 0.20, 2.82), (0.17, 0.055, 0.055), "M_Cinnabar", rig, "head")
    add_tapered_ribbon("RibbonL", (-0.09, 0.30, 2.54), (0.035, 0.05, 0.28), (0.38, 0.0, -0.13), rig)
    add_tapered_ribbon("RibbonR", (0.10, 0.29, 2.58), (0.032, 0.045, 0.24), (0.34, 0.0, 0.16), rig)


def refine_costume(rig: bpy.types.Object) -> None:
    # Preserve the rig while improving the reference-inspired asymmetric silhouette.
    right_shoulder = bpy.data.objects.get("V3_ShoulderR")
    if right_shoulder is not None:
        right_shoulder.data.materials.clear()
        right_shoulder.data.materials.append(bpy.data.materials["M_Dagger"])
        right_shoulder.scale *= Vector((1.08, 1.05, 1.08))
    left_shoulder = bpy.data.objects.get("V3_ShoulderL")
    if left_shoulder is not None:
        left_shoulder.scale *= 0.72

    add_ellipsoid("JadeToken", (0.22, -0.32, 1.31), (0.055, 0.025, 0.075), "M_CyanEye", rig, "pelvis")


def reset_pose(rig: bpy.types.Object) -> None:
    rig.animation_data_create()
    rig.animation_data.action = None
    for pose_bone in rig.pose.bones:
        pose_bone.matrix_basis = Matrix.Identity(4)
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()


def configure_preview(scene: bpy.types.Scene, rig: bpy.types.Object, path: Path) -> None:
    camera = bpy.data.objects["HD2D_Camera"]
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.55
    camera.location = (4.8, -7.5, 4.8)
    camera.rotation_euler = (
        Vector((0.0, 0.0, 1.42)) - camera.location
    ).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    rig.animation_data.action = bpy.data.actions["wuyang_idle"]
    scene.frame_set(7)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True)


def main() -> None:
    root = repository_root()
    rig = bpy.data.objects["Wuyang_Rig"]
    reset_pose(rig)
    configure_palette()
    remove_old_side_braids()
    remove_legacy_face_parts()
    mature_head_proportions(rig)
    build_high_ponytail(rig)
    refine_costume(rig)
    for action_name in ("wuyang_idle", "wuyang_walk"):
        bpy.data.actions[action_name].use_fake_user = True

    source = root / "assets/characters/wuyang/3d/source/wuyang_ponytail_v4.blend"
    runtime = root / "assets/characters/wuyang/3d/wuyang_ponytail_v4.glb"
    preview = root / "assets/characters/wuyang/3d/previews/wuyang_ponytail_v4_preview.png"
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    bpy.ops.export_scene.gltf(
        filepath=str(runtime),
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
    )
    configure_preview(bpy.context.scene, rig, preview)
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    print(f"Wuyang ponytail v4 source: {source}")
    print(f"Wuyang ponytail v4 runtime: {runtime}")
    print(f"Wuyang ponytail v4 preview: {preview}")


if __name__ == "__main__":
    main()
