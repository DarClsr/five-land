"""Build the first refined Wuyang v3 master from the stable v2 rig.

Run from the repository root:
    D:\\Blender\\blender.exe --background \
        assets/characters/wuyang/3d/source/wuyang_hd2d_master_v2.blend \
        --python scripts/assets/refine_wuyang_v3.py
"""

from __future__ import annotations

import math
from pathlib import Path

import bpy
from mathutils import Matrix, Vector


DETAIL_PREFIX = "V3_"


def repository_root() -> Path:
    return Path(bpy.data.filepath).resolve().parents[5]


def reset_pose(rig: bpy.types.Object) -> None:
    rig.animation_data_create()
    rig.animation_data.action = None
    for pose_bone in rig.pose.bones:
        pose_bone.matrix_basis = Matrix.Identity(4)
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()


def material(name: str) -> bpy.types.Material:
    return bpy.data.materials[name]


def tune_materials() -> None:
    cloth_names = ("M_BlueGray", "M_Charcoal", "M_GrayWhite", "M_InkBlue")
    for name in cloth_names:
        material(name).roughness = 0.88
        material(name).metallic = 0.0
    material("M_HairWhite").roughness = 0.72
    material("M_HairShadow").roughness = 0.78
    material("M_Skin").roughness = 0.82
    material("M_Boot").roughness = 0.68
    material("M_Dagger").roughness = 0.28
    material("M_Dagger").metallic = 0.72
    material("M_Cinnabar").roughness = 0.62
    material("M_CyanEye").roughness = 0.32


def rigid_parent(obj: bpy.types.Object, rig: bpy.types.Object, bone_name: str) -> None:
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    obj.matrix_world = world


def add_bevel(obj: bpy.types.Object, width: float = 0.018, segments: int = 2) -> None:
    modifier = obj.modifiers.new(name="V3_SoftEdges", type="BEVEL")
    modifier.width = width
    modifier.segments = segments
    modifier.limit_method = "ANGLE"


def add_cube(
    name: str,
    location: tuple[float, float, float],
    dimensions: tuple[float, float, float],
    material_name: str,
    rig: bpy.types.Object,
    bone_name: str,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    bevel: float = 0.018,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = DETAIL_PREFIX + name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        add_bevel(obj, min(bevel, min(dimensions) * 0.22), 2)
    obj.data.materials.append(material(material_name))
    rigid_parent(obj, rig, bone_name)
    return obj


def add_cone(
    name: str,
    location: tuple[float, float, float],
    radius1: float,
    radius2: float,
    depth: float,
    material_name: str,
    rig: bpy.types.Object,
    bone_name: str,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    vertices: int = 8,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius1,
        radius2=radius2,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = DETAIL_PREFIX + name
    obj.data.materials.append(material(material_name))
    rigid_parent(obj, rig, bone_name)
    return obj


def add_uv_sphere(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material_name: str,
    rig: bpy.types.Object,
    bone_name: str,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=16,
        ring_count=8,
        location=location,
        scale=scale,
    )
    obj = bpy.context.object
    obj.name = DETAIL_PREFIX + name
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material(material_name))
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    rigid_parent(obj, rig, bone_name)
    return obj


def refine_existing_shapes(rig: bpy.types.Object) -> None:
    head_pivot = (rig.matrix_world @ rig.pose.bones["head"].matrix).translation
    for obj in bpy.data.objects:
        if obj.type != "MESH" or obj.parent_bone != "head":
            continue
        world = obj.matrix_world.copy()
        offset = world.translation - head_pivot
        world.translation = head_pivot + Vector((offset.x * 0.92, offset.y * 0.92, offset.z * 0.92))
        obj.matrix_world = world
        obj.scale = Vector((obj.scale.x * 0.92, obj.scale.y * 0.92, obj.scale.z * 0.92))

    for eye_name in ("EyeL", "EyeR"):
        eye = bpy.data.objects[eye_name]
        eye.scale.x *= 0.9
        eye.scale.z *= 0.9
        eye.location.y -= 0.012

    for collar_name in ("CollarL", "CollarR"):
        collar = bpy.data.objects[collar_name]
        collar.scale *= 0.78

    smooth_names = ("Head", "HairCap", "HairBack")
    for name in smooth_names:
        for polygon in bpy.data.objects[name].data.polygons:
            polygon.use_smooth = True

    bevel_names = (
        "Torso",
        "Waist",
        "SkirtCore",
        "UpperArm_-1",
        "UpperArm_1",
        "Forearm_-1",
        "Forearm_1",
        "Thigh_-1",
        "Thigh_1",
        "Shin_-1",
        "Shin_1",
        "Boot_-1",
        "Boot_1",
    )
    for name in bevel_names:
        add_bevel(bpy.data.objects[name], 0.016, 2)


def add_face_details(rig: bpy.types.Object) -> None:
    add_uv_sphere("EyeL", (-0.115, -0.425, 2.525), (0.047, 0.013, 0.026), "M_CyanEye", rig, "head")
    add_uv_sphere("EyeR", (0.115, -0.425, 2.525), (0.047, 0.013, 0.026), "M_CyanEye", rig, "head")
    add_uv_sphere("PupilL", (-0.115, -0.439, 2.525), (0.013, 0.007, 0.017), "M_Charcoal", rig, "head")
    add_uv_sphere("PupilR", (0.115, -0.439, 2.525), (0.013, 0.007, 0.017), "M_Charcoal", rig, "head")
    add_cube("BrowL", (-0.115, -0.432, 2.6), (0.12, 0.024, 0.022), "M_HairShadow", rig, "head", rotation=(0.0, 0.0, -0.09), bevel=0.007)
    add_cube("BrowR", (0.115, -0.432, 2.6), (0.12, 0.024, 0.022), "M_HairShadow", rig, "head", rotation=(0.0, 0.0, 0.09), bevel=0.007)
    add_cone("Nose", (0.0, -0.438, 2.48), 0.034, 0.01, 0.06, "M_Skin", rig, "head", rotation=(math.pi * 0.5, 0.0, 0.0), vertices=6)
    add_cube("Mouth", (0.0, -0.426, 2.405), (0.115, 0.018, 0.015), "M_Cinnabar", rig, "head", bevel=0.005)


def add_clothing_layers(rig: bpy.types.Object) -> None:
    add_cube("Belt", (0.0, -0.01, 1.36), (0.76, 0.56, 0.13), "M_Charcoal", rig, "pelvis", bevel=0.025)
    add_cube("BeltAccent", (0.0, -0.305, 1.36), (0.22, 0.035, 0.145), "M_Cinnabar", rig, "pelvis", bevel=0.012)
    add_cube("ShoulderL", (-0.4, -0.005, 1.92), (0.27, 0.35, 0.1), "M_InkBlue", rig, "upper_arm.L", rotation=(0.0, 0.0, -0.1), bevel=0.02)
    add_cube("ShoulderR", (0.4, -0.005, 1.92), (0.27, 0.35, 0.1), "M_InkBlue", rig, "upper_arm.R", rotation=(0.0, 0.0, 0.1), bevel=0.02)
    add_cube("CuffL", (-0.54, -0.105, 1.49), (0.25, 0.28, 0.13), "M_Charcoal", rig, "forearm.L", bevel=0.02)
    add_cube("CuffR", (0.54, -0.105, 1.49), (0.25, 0.28, 0.13), "M_Charcoal", rig, "forearm.R", bevel=0.02)
    add_cube("SidePanelL", (-0.43, 0.015, 1.08), (0.22, 0.42, 0.62), "M_BlueGray", rig, "pelvis", rotation=(0.0, -0.08, 0.04), bevel=0.018)
    add_cube("SidePanelR", (0.43, 0.015, 1.08), (0.22, 0.42, 0.62), "M_BlueGray", rig, "pelvis", rotation=(0.0, 0.08, -0.04), bevel=0.018)
    add_cube("BackPanel", (0.0, 0.39, 1.08), (0.58, 0.12, 0.64), "M_InkBlue", rig, "pelvis", bevel=0.02)


def add_hair_and_weapon_details(rig: bpy.types.Object) -> None:
    add_uv_sphere("HairOrnament", (0.0, 0.01, 2.9), (0.07, 0.07, 0.07), "M_Cinnabar", rig, "head")
    add_cone("HairPin", (0.0, 0.015, 2.9), 0.022, 0.022, 0.36, "M_Dagger", rig, "head", rotation=(0.0, math.pi * 0.5, 0.0), vertices=10)
    add_uv_sphere("PommelL", (-0.7, -0.17, 1.215), (0.065, 0.065, 0.065), "M_Cinnabar", rig, "hand.L")
    add_uv_sphere("PommelR", (0.7, -0.17, 1.215), (0.065, 0.065, 0.065), "M_Cinnabar", rig, "hand.R")


def configure_preview(scene: bpy.types.Scene, rig: bpy.types.Object, preview_path: Path) -> None:
    camera = bpy.data.objects.get("HD2D_Camera")
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.55
    camera.location = (4.8, -7.5, 4.8)
    camera.rotation_euler = (Vector((0.0, 0.0, 1.42)) - camera.location).to_track_quat("-Z", "Y").to_euler()
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
    scene.render.filepath = str(preview_path)
    bpy.ops.render.render(write_still=True)


def main() -> None:
    root = repository_root()
    rig = bpy.data.objects["Wuyang_Rig"]
    reset_pose(rig)
    tune_materials()
    refine_existing_shapes(rig)
    add_face_details(rig)
    add_clothing_layers(rig)
    add_hair_and_weapon_details(rig)
    for action_name in ("wuyang_idle", "wuyang_walk"):
        bpy.data.actions[action_name].use_fake_user = True

    source_path = root / "assets" / "characters" / "wuyang" / "3d" / "source" / "wuyang_master_v3.blend"
    glb_path = root / "assets" / "characters" / "wuyang" / "3d" / "wuyang_master_v3.glb"
    preview_path = root / "assets" / "characters" / "wuyang" / "3d" / "previews" / "wuyang_master_v3_preview.png"
    bpy.ops.wm.save_as_mainfile(filepath=str(source_path))
    bpy.ops.export_scene.gltf(
        filepath=str(glb_path),
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
    )
    configure_preview(bpy.context.scene, rig, preview_path)
    bpy.ops.wm.save_as_mainfile(filepath=str(source_path))
    print(f"Wuyang v3 source: {source_path}")
    print(f"Wuyang v3 runtime: {glb_path}")
    print(f"Wuyang v3 preview: {preview_path}")


if __name__ == "__main__":
    main()
