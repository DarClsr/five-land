"""Refine the ponytail prototype for an adult wuxia silhouette and game readability."""

from __future__ import annotations

from pathlib import Path

import bpy
from mathutils import Matrix, Vector


PREFIX = "V5_"


def repository_root() -> Path:
    return Path(bpy.data.filepath).resolve().parents[5]


def reset_pose(rig: bpy.types.Object) -> None:
    rig.animation_data_create()
    rig.animation_data.action = None
    for pose_bone in rig.pose.bones:
        pose_bone.matrix_basis = Matrix.Identity(4)
    bpy.context.scene.frame_set(1)
    bpy.context.view_layer.update()


def set_color(name: str, color: tuple[float, float, float, float]) -> None:
    material = bpy.data.materials[name]
    material.diffuse_color = color
    if material.node_tree is not None:
        principled = material.node_tree.nodes.get("Principled BSDF")
        if principled is not None:
            principled.inputs["Base Color"].default_value = color


def tune_readable_palette() -> None:
    set_color("M_HairWhite", (0.012, 0.015, 0.024, 1.0))
    set_color("M_HairShadow", (0.035, 0.042, 0.060, 1.0))
    set_color("M_BlueGray", (0.075, 0.105, 0.155, 1.0))
    set_color("M_InkBlue", (0.035, 0.060, 0.105, 1.0))
    set_color("M_Charcoal", (0.025, 0.030, 0.043, 1.0))
    set_color("M_Cinnabar", (0.52, 0.045, 0.035, 1.0))
    set_color("M_GrayWhite", (0.28, 0.30, 0.32, 1.0))
    set_color("M_CyanEye", (0.10, 0.045, 0.022, 1.0))


def rigid_parent(obj: bpy.types.Object, rig: bpy.types.Object, bone_name: str) -> None:
    world = obj.matrix_world.copy()
    obj.parent = rig
    obj.parent_type = "BONE"
    obj.parent_bone = bone_name
    obj.matrix_world = world


def scale_about(
    obj: bpy.types.Object,
    pivot: Vector,
    position_scale: Vector,
    shape_scale: Vector,
) -> None:
    world = obj.matrix_world.copy()
    offset = world.translation - pivot
    world.translation = pivot + Vector(
        (
            offset.x * position_scale.x,
            offset.y * position_scale.y,
            offset.z * position_scale.z,
        )
    )
    obj.matrix_world = world
    obj.scale = Vector(
        (
            obj.scale.x * shape_scale.x,
            obj.scale.y * shape_scale.y,
            obj.scale.z * shape_scale.z,
        )
    )


def refine_proportions(rig: bpy.types.Object) -> None:
    head_pivot = (rig.matrix_world @ rig.pose.bones["head"].matrix).translation
    head_names = (
        "Head",
        "HairCap",
        "HairBack",
        "BangL",
        "BangR",
        "V3_HairOrnament",
        "V3_HairPin",
    )
    for name in head_names:
        obj = bpy.data.objects.get(name)
        if obj is not None:
            scale_about(obj, head_pivot, Vector((0.80, 0.84, 0.82)), Vector((0.80, 0.84, 0.82)))

    # Keep animation joints untouched; slim only the rigid visual pieces.
    for name in ("Torso", "SkirtCore"):
        obj = bpy.data.objects.get(name)
        if obj is not None:
            obj.scale.x *= 0.78
            obj.scale.y *= 0.78
    for prefix in ("UpperArm_", "Forearm_", "Thigh_", "Shin_"):
        for obj in bpy.data.objects:
            if obj.name.startswith(prefix):
                obj.scale.x *= 0.80
                obj.scale.y *= 0.80
    for name in ("Boot_-1", "Boot_1"):
        obj = bpy.data.objects.get(name)
        if obj is not None:
            obj.scale.x *= 0.82


def rebuild_face(rig: bpy.types.Object) -> None:
    for name in (
        "BangL",
        "BangR",
        "V3_EyeL",
        "V3_EyeR",
        "V3_PupilL",
        "V3_PupilR",
        "V3_BrowL",
        "V3_BrowR",
        "V3_Nose",
        "V3_Mouth",
    ):
        obj = bpy.data.objects.get(name)
        if obj is not None:
            bpy.data.objects.remove(obj, do_unlink=True)

    for side, x in (("L", -0.098), ("R", 0.052)):
        bpy.ops.mesh.primitive_uv_sphere_add(
            segments=12,
            ring_count=6,
            location=(x, -0.345, 2.47),
            scale=(0.052, 0.010, 0.016),
        )
        eye = bpy.context.object
        eye.name = PREFIX + "Eye" + side
        eye.data.materials.append(bpy.data.materials["M_HairShadow"])
        rigid_parent(eye, rig, "head")
    bpy.ops.mesh.primitive_cube_add(location=(-0.023, -0.348, 2.385))
    mouth = bpy.context.object
    mouth.name = PREFIX + "Mouth"
    mouth.dimensions = (0.07, 0.012, 0.010)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mouth.data.materials.append(bpy.data.materials["M_Cinnabar"])
    rigid_parent(mouth, rig, "head")



def add_trapezoid_panel(
    name: str,
    center: tuple[float, float, float],
    top_width: float,
    bottom_width: float,
    height: float,
    depth: float,
    material_name: str,
    rig: bpy.types.Object,
) -> bpy.types.Object:
    tw = top_width * 0.5
    bw = bottom_width * 0.5
    hh = height * 0.5
    hd = depth * 0.5
    vertices = [
        (-tw, -hd, hh), (tw, -hd, hh), (tw, hd, hh), (-tw, hd, hh),
        (-bw, -hd, -hh), (bw, -hd, -hh), (bw, hd, -hh), (-bw, hd, -hh),
    ]
    faces = [
        (0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1),
        (1, 5, 6, 2), (2, 6, 7, 3), (4, 0, 3, 7),
    ]
    mesh = bpy.data.meshes.new(PREFIX + name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(PREFIX + name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = center
    obj.data.materials.append(bpy.data.materials[material_name])
    bevel = obj.modifiers.new(name="SoftClothEdge", type="BEVEL")
    bevel.width = 0.015
    bevel.segments = 2
    rigid_parent(obj, rig, "pelvis")
    return obj


def rebuild_coat(rig: bpy.types.Object) -> None:
    for name in (
        "FrontPanelL", "FrontPanelR", "V3_SidePanelL", "V3_SidePanelR", "V3_BackPanel"
    ):
        obj = bpy.data.objects.get(name)
        if obj is not None:
            bpy.data.objects.remove(obj, do_unlink=True)
    left = add_trapezoid_panel(
        "OutfitWanderer_FrontL", (-0.18, -0.30, 1.08), 0.22, 0.34, 0.76, 0.055,
        "M_BlueGray", rig,
    )
    left.rotation_euler.z = -0.07
    right = add_trapezoid_panel(
        "OutfitWanderer_FrontR", (0.18, -0.30, 1.05), 0.22, 0.32, 0.70, 0.055,
        "M_InkBlue", rig,
    )
    right.rotation_euler.z = 0.06
    add_trapezoid_panel(
        "OutfitWanderer_Back", (0.0, 0.27, 1.06), 0.40, 0.62, 0.82, 0.07,
        "M_InkBlue", rig,
    )
    sash = add_trapezoid_panel(
        "OutfitWanderer_RedSash", (0.38, -0.04, 1.02), 0.07, 0.13, 0.80, 0.035,
        "M_Cinnabar", rig,
    )
    sash.rotation_euler.z = -0.12


def refine_ponytail() -> None:
    # Make the ponytail a long tapered gesture instead of a stack of round beads.
    for name in ("V4_Ponytail01", "V4_Ponytail02", "V4_Ponytail03", "V4_PonytailTip"):
        obj = bpy.data.objects.get(name)
        if obj is not None:
            obj.scale.x *= 0.66
            obj.scale.y *= 0.82
    top = bpy.data.objects.get("V4_TopKnot")
    if top is not None:
        top.scale *= 0.72


def configure_preview(scene: bpy.types.Scene, rig: bpy.types.Object, path: Path) -> None:
    camera = bpy.data.objects["HD2D_Camera"]
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 3.35
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
    tune_readable_palette()
    refine_proportions(rig)
    rebuild_face(rig)
    refine_ponytail()
    for action_name in ("wuyang_idle", "wuyang_walk"):
        bpy.data.actions[action_name].use_fake_user = True

    source = root / "assets/characters/wuyang/3d/source/wuyang_ponytail_v5.blend"
    runtime = root / "assets/characters/wuyang/3d/wuyang_ponytail_v5.glb"
    preview = root / "assets/characters/wuyang/3d/previews/wuyang_ponytail_v5_preview.png"
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    bpy.ops.export_scene.gltf(
        filepath=str(runtime),
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
    )
    configure_preview(bpy.context.scene, rig, preview)
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    print(f"Wuyang ponytail v5 source: {source}")
    print(f"Wuyang ponytail v5 runtime: {runtime}")
    print(f"Wuyang ponytail v5 preview: {preview}")


if __name__ == "__main__":
    main()
