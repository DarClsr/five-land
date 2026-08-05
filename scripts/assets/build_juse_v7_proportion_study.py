"""Build a non-runtime Juse v7 proportion and hair silhouette study.

This deliberately excludes costume work. It lets us compare the body, head,
shoulder line, and waist-length high ponytail against the approved turnaround
before committing to a new production mesh.
"""

from __future__ import annotations

import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Vector


ROOT = Path(__file__).resolve().parents[2]
BASE = ROOT / "assets/characters/wuyang/3d/source/base_cc0/Superhero_Female_FullBody.gltf"
OUT_DIR = ROOT / "assets/characters/juse/3d/studies"


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def material(name: str, color: tuple[float, float, float, float], roughness: float) -> bpy.types.Material:
    result = bpy.data.materials.new(name)
    result.diffuse_color = color
    result.roughness = roughness
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    if shader is not None:
        shader.inputs["Base Color"].default_value = color
        shader.inputs["Roughness"].default_value = roughness
    return result


def add_hair_curve(
    name: str,
    points: list[tuple[float, float, float]],
    radius: float,
    hair_material: bpy.types.Material,
) -> bpy.types.Object:
    curve = bpy.data.curves.new(name + "Curve", type="CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 6
    curve.bevel_depth = radius
    curve.bevel_resolution = 3
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for point, coordinate in zip(spline.bezier_points, points):
        point.co = coordinate
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(hair_material)
    return obj


def build_long_high_ponytail(hair_material: bpy.types.Material, tie_material: bpy.types.Material) -> None:
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=40,
        ring_count=24,
        location=(0.0, 0.018, 1.79),
        scale=(0.132, 0.126, 0.155),
    )
    cap = bpy.context.object
    cap.name = "Study_HairCap"
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bm = bmesh.new()
    bm.from_mesh(cap.data)
    remove = [vertex for vertex in bm.verts if vertex.co.y < -0.02 and vertex.co.z < 0.045]
    bmesh.ops.delete(bm, geom=remove, context="VERTS")
    bm.to_mesh(cap.data)
    bm.free()
    cap.data.materials.append(hair_material)

    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=32,
        ring_count=18,
        location=(0.0, 0.105, 1.905),
        scale=(0.060, 0.060, 0.070),
    )
    knot = bpy.context.object
    knot.name = "Study_HighPonytailKnot"
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    knot.data.materials.append(hair_material)

    # Three overlapping locks create the long, narrow silhouette in the turnaround.
    add_hair_curve(
        "Study_PonytailCenter",
        [(0.0, 0.13, 1.91), (0.02, 0.20, 1.72), (-0.01, 0.21, 1.42), (0.02, 0.18, 1.10), (-0.02, 0.13, 0.88)],
        0.040,
        hair_material,
    )
    add_hair_curve(
        "Study_PonytailLeft",
        [(-0.025, 0.13, 1.90), (-0.055, 0.20, 1.70), (-0.060, 0.20, 1.39), (-0.035, 0.17, 1.08), (-0.065, 0.12, 0.91)],
        0.027,
        hair_material,
    )
    add_hair_curve(
        "Study_PonytailRight",
        [(0.025, 0.13, 1.90), (0.060, 0.20, 1.69), (0.055, 0.21, 1.37), (0.075, 0.16, 1.07), (0.040, 0.11, 0.90)],
        0.027,
        hair_material,
    )
    add_hair_curve(
        "Study_FaceLockL",
        [(-0.090, -0.092, 1.79), (-0.108, -0.115, 1.68), (-0.095, -0.105, 1.56)],
        0.010,
        hair_material,
    )
    add_hair_curve(
        "Study_FaceLockR",
        [(0.090, -0.092, 1.79), (0.108, -0.115, 1.68), (0.095, -0.105, 1.56)],
        0.010,
        hair_material,
    )
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.060,
        minor_radius=0.010,
        major_segments=32,
        minor_segments=8,
        location=(0.0, 0.105, 1.895),
        rotation=(math.pi * 0.5, 0.0, 0.0),
    )
    bpy.context.object.data.materials.append(tie_material)


def pose_neutral_a(rig: bpy.types.Object) -> None:
    for bone_name, z_angle in (("upperarm_l", -0.90), ("upperarm_r", 0.90)):
        bone = rig.pose.bones[bone_name]
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = Vector((0.0, 0.0, z_angle))


def add_lighting(scene: bpy.types.Scene) -> None:
    bpy.ops.object.light_add(type="AREA", location=(-2.5, -3.0, 4.0))
    key = bpy.context.object
    key.data.energy = 720.0
    key.data.size = 4.0
    bpy.ops.object.light_add(type="AREA", location=(2.5, 1.8, 3.0))
    rim = bpy.context.object
    rim.data.energy = 380.0
    rim.data.color = (0.35, 0.48, 0.72)
    rim.data.size = 3.0
    scene.world.color = (0.035, 0.035, 0.035)


def render_view(scene: bpy.types.Scene, name: str, location: tuple[float, float, float]) -> None:
    bpy.ops.object.camera_add(location=location)
    camera = bpy.context.object
    camera.name = "StudyCamera_" + name
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.15
    camera.rotation_euler = (Vector((0.0, 0.0, 0.95)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    scene.render.filepath = str(OUT_DIR / f"juse_v7_proportion_{name}.png")
    bpy.ops.render.render(write_still=True)
    bpy.data.objects.remove(camera, do_unlink=True)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(BASE))
    rig = bpy.data.objects["Armature"]
    rig.name = "Juse_StudyRig"
    # A restrained correction: slightly taller and narrower, while preserving the production topology.
    rig.scale = (0.93, 0.92, 1.06)
    pose_neutral_a(rig)

    hair = material("M_Juse_StudyHair", (0.008, 0.010, 0.014, 1.0), 0.65)
    tie = material("M_Juse_StudyRedTie", (0.34, 0.018, 0.015, 1.0), 0.78)
    build_long_high_ponytail(hair, tie)

    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 640
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    add_lighting(scene)
    scene.frame_set(1)

    render_view(scene, "front", (0.0, -4.0, 1.08))
    render_view(scene, "side", (4.0, 0.0, 1.08))
    render_view(scene, "back", (0.0, 4.0, 1.08))
    source = OUT_DIR / "juse_v7_proportion_study.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    print(f"Juse v7 proportion study: {source}")


if __name__ == "__main__":
    main()
