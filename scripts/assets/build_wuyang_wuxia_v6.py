"""Build Wuyang v6 from a CC0 game-ready female humanoid base.

The imported Quaternius base is CC0. This script adds original Five Land hair,
costume, weapon attachments, palette, and lightweight runtime animations.
"""

from __future__ import annotations

import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector


def repository_root() -> Path:
    return Path(__file__).resolve().parents[2]


def clear_scene() -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def make_material(
    name: str,
    color: tuple[float, float, float, float],
    roughness: float = 0.82,
    metallic: float = 0.0,
) -> bpy.types.Material:
    material = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    material.diffuse_color = color
    material.roughness = roughness
    material.metallic = metallic
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    if principled is not None:
        principled.inputs["Base Color"].default_value = color
        principled.inputs["Roughness"].default_value = roughness
        principled.inputs["Metallic"].default_value = metallic
    return material


def build_palette() -> dict[str, bpy.types.Material]:
    return {
        "hair": make_material("M_Wuyang_Hair", (0.008, 0.012, 0.020, 1.0), 0.72),
        "hair_high": make_material("M_Wuyang_HairHighlight", (0.035, 0.050, 0.075, 1.0), 0.68),
        "ink": make_material("M_Wuyang_InkCloth", (0.025, 0.045, 0.075, 1.0), 0.9),
        "blue": make_material("M_Wuyang_IndigoCloth", (0.055, 0.105, 0.165, 1.0), 0.9),
        "red": make_material("M_Wuyang_Vermilion", (0.52, 0.025, 0.020, 1.0), 0.78),
        "jade": make_material("M_Wuyang_Jade", (0.055, 0.34, 0.28, 1.0), 0.42),
        "metal": make_material("M_Wuyang_AgedSilver", (0.24, 0.27, 0.29, 1.0), 0.36, 0.68),
        "leather": make_material("M_Wuyang_Leather", (0.065, 0.035, 0.025, 1.0), 0.72),
    }


def bone_parent(obj: bpy.types.Object, rig: bpy.types.Object, bone_name: str) -> None:
    # A one-bone armature bind is stable in Blender and Godot. Bone parenting
    # caused rest-pose offsets on exported rigid costume pieces.
    group = obj.vertex_groups.new(name=bone_name)
    group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    modifier = obj.modifiers.new(name="WuyangRig", type="ARMATURE")
    modifier.object = rig
    obj.parent = rig
    obj.matrix_parent_inverse = rig.matrix_world.inverted()


def add_bevel(obj: bpy.types.Object, width: float = 0.008, segments: int = 2) -> None:
    bevel = obj.modifiers.new(name="SoftEdge", type="BEVEL")
    bevel.width = width
    bevel.segments = segments
    bevel.limit_method = "ANGLE"


def add_box(
    name: str,
    location: tuple[float, float, float],
    dimensions: tuple[float, float, float],
    material: bpy.types.Material,
    rig: bpy.types.Object,
    bone_name: str,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    bevel: float = 0.01,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(location=location, rotation=rotation)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel > 0.0:
        add_bevel(obj, bevel)
    bone_parent(obj, rig, bone_name)
    return obj


def add_trapezoid(
    name: str,
    location: tuple[float, float, float],
    top_width: float,
    bottom_width: float,
    height: float,
    depth: float,
    material: bpy.types.Material,
    rig: bpy.types.Object,
    bone_name: str = "pelvis",
    rotation_z: float = 0.0,
) -> bpy.types.Object:
    tw, bw, hh, hd = top_width * 0.5, bottom_width * 0.5, height * 0.5, depth * 0.5
    vertices = [
        (-tw, -hd, hh), (tw, -hd, hh), (tw, hd, hh), (-tw, hd, hh),
        (-bw, -hd, -hh), (bw, -hd, -hh), (bw, hd, -hh), (-bw, hd, -hh),
    ]
    faces = [
        (0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1),
        (1, 5, 6, 2), (2, 6, 7, 3), (4, 0, 3, 7),
    ]
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.location = location
    obj.rotation_euler.z = rotation_z
    obj.data.materials.append(material)
    add_bevel(obj, 0.012, 2)
    bone_parent(obj, rig, bone_name)
    return obj


def add_tapered_piece(
    name: str,
    location: tuple[float, float, float],
    radius_bottom: float,
    radius_top: float,
    depth: float,
    scale_y: float,
    material: bpy.types.Material,
    rig: bpy.types.Object,
    bone_name: str,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=32,
        radius1=radius_bottom,
        radius2=radius_top,
        depth=depth,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    obj.scale.y = scale_y
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    add_bevel(obj, 0.008, 2)
    bone_parent(obj, rig, bone_name)
    return obj


def add_fitted_tunic(
    rig: bpy.types.Object,
    material: bpy.types.Material,
) -> bpy.types.Object:
    """Create a waist-shaped, open V-neck garment instead of a tube."""
    segments = 32
    rings = [
        (1.00, 0.205, 0.135),
        (1.10, 0.185, 0.130),
        (1.25, 0.198, 0.165),
        (1.38, 0.220, 0.190),
        (1.48, 0.225, 0.185),
    ]
    vertices: list[tuple[float, float, float]] = []
    for ring_index, (base_z, radius_x, radius_y) in enumerate(rings):
        for index in range(segments):
            angle = math.tau * float(index) / float(segments)
            x = math.cos(angle) * radius_x
            y = math.sin(angle) * radius_y
            z = base_z
            if ring_index == len(rings) - 1 and y < 0.0:
                front_factor = -y / radius_y
                center_factor = max(0.0, 1.0 - abs(x) / radius_x)
                z -= 0.15 * front_factor * front_factor * center_factor
            vertices.append((x, y, z))
    faces: list[tuple[int, int, int, int]] = []
    for ring_index in range(len(rings) - 1):
        start = ring_index * segments
        next_start = (ring_index + 1) * segments
        for index in range(segments):
            following = (index + 1) % segments
            faces.append((start + index, start + following, next_start + following, next_start + index))
    mesh = bpy.data.meshes.new("Outfit_FittedTunicMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new("Outfit_FittedTunic", mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    add_bevel(obj, 0.006, 2)
    bone_parent(obj, rig, "spine_02")
    return obj


def add_curve_lock(
    name: str,
    points: list[tuple[float, float, float]],
    thickness: float,
    material: bpy.types.Material,
    rig: bpy.types.Object,
) -> bpy.types.Object:
    curve = bpy.data.curves.new(name + "Curve", type="CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 4
    curve.bevel_depth = thickness
    curve.bevel_resolution = 3
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    for point, coordinate in zip(spline.bezier_points, points):
        point.co = coordinate
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    bone_parent(obj, rig, "Head")
    return obj


def add_hair_cap(rig: bpy.types.Object, material: bpy.types.Material) -> None:
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=32,
        ring_count=18,
        location=(0.0, 0.018, 1.69),
        scale=(0.145, 0.135, 0.165),
    )
    cap = bpy.context.object
    cap.name = "Hair_HighPonytail_Cap"
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    mesh = bmesh.new()
    mesh.from_mesh(cap.data)
    # Remove the front/lower quadrant so the authored face remains visible.
    remove = [vertex for vertex in mesh.verts if vertex.co.y < -0.025 and vertex.co.z < 0.055]
    bmesh.ops.delete(mesh, geom=remove, context="VERTS")
    mesh.to_mesh(cap.data)
    mesh.free()
    cap.data.materials.append(material)
    bone_parent(cap, rig, "Head")


def build_hair(rig: bpy.types.Object, palette: dict[str, bpy.types.Material]) -> None:
    add_hair_cap(rig, palette["hair"])
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=24,
        ring_count=12,
        location=(0.0, 0.105, 1.80),
        scale=(0.075, 0.07, 0.065),
    )
    knot = bpy.context.object
    knot.name = "Hair_HighPonytail_Knot"
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    knot.data.materials.append(palette["hair"])
    bone_parent(knot, rig, "Head")
    add_curve_lock(
        "Hair_HighPonytail_Main",
        [(0.0, 0.13, 1.80), (0.02, 0.22, 1.68), (-0.025, 0.25, 1.50), (0.04, 0.20, 1.34)],
        0.055,
        palette["hair"],
        rig,
    )
    add_curve_lock(
        "Hair_HighPonytail_Highlight",
        [(0.025, 0.12, 1.80), (0.05, 0.20, 1.67), (0.02, 0.22, 1.49), (0.07, 0.17, 1.37)],
        0.018,
        palette["hair_high"],
        rig,
    )
    add_curve_lock(
        "Hair_FaceStrand_L",
        [(-0.10, -0.095, 1.72), (-0.115, -0.12, 1.63), (-0.105, -0.11, 1.54)],
        0.012,
        palette["hair"],
        rig,
    )
    add_curve_lock(
        "Hair_FaceStrand_R",
        [(0.10, -0.095, 1.72), (0.115, -0.12, 1.63), (0.105, -0.11, 1.55)],
        0.012,
        palette["hair"],
        rig,
    )
    bpy.ops.mesh.primitive_torus_add(
        major_radius=0.075,
        minor_radius=0.012,
        major_segments=24,
        minor_segments=8,
        location=(0.0, 0.112, 1.79),
        rotation=(math.pi * 0.5, 0.0, 0.0),
    )
    tie = bpy.context.object
    tie.name = "Hair_Vermilion_Tie"
    tie.data.materials.append(palette["red"])
    bone_parent(tie, rig, "Head")


def build_costume(rig: bpy.types.Object, palette: dict[str, bpy.types.Material]) -> None:
    # Smooth layered volumes read as cloth at the game's small 2.5D scale.
    add_fitted_tunic(rig, palette["ink"])
    add_tapered_piece("Outfit_OuterRobe", (0.0, 0.015, 0.74), 0.32, 0.225, 0.62, 0.72, palette["blue"], rig, "pelvis")
    add_box("Outfit_Collar_L", (-0.055, -0.196, 1.42), (0.038, 0.018, 0.27), palette["blue"], rig, "spine_03", (0.0, -0.42, 0.0), 0.005)
    add_box("Outfit_Collar_R", (0.050, -0.198, 1.41), (0.038, 0.018, 0.25), palette["red"], rig, "spine_03", (0.0, 0.42, 0.0), 0.005)
    add_tapered_piece("Outfit_WideBelt", (0.0, -0.002, 0.99), 0.245, 0.245, 0.105, 0.68, palette["leather"], rig, "pelvis")
    add_box("Outfit_BeltAccent", (0.0, -0.173, 0.99), (0.16, 0.022, 0.065), palette["red"], rig, "pelvis", bevel=0.008)
    add_trapezoid("Outfit_RedSash", (0.25, 0.02, 0.72), 0.055, 0.10, 0.52, 0.025, palette["red"], rig, rotation_z=-0.12)
    add_tapered_piece("Outfit_Sleeve_L", (0.34, 0.0, 1.445), 0.095, 0.12, 0.36, 0.82, palette["blue"], rig, "upperarm_l", (0.0, math.pi * 0.5, 0.0))
    add_tapered_piece("Outfit_Sleeve_R", (-0.34, 0.0, 1.445), 0.12, 0.095, 0.36, 0.82, palette["ink"], rig, "upperarm_r", (0.0, math.pi * 0.5, 0.0))
    add_tapered_piece("Outfit_Cuff_L", (0.55, 0.0, 1.445), 0.095, 0.11, 0.16, 0.82, palette["leather"], rig, "lowerarm_l", (0.0, math.pi * 0.5, 0.0))
    add_tapered_piece("Outfit_Cuff_R", (-0.55, 0.0, 1.445), 0.11, 0.095, 0.16, 0.82, palette["leather"], rig, "lowerarm_r", (0.0, math.pi * 0.5, 0.0))
    add_tapered_piece("Outfit_Boot_L", (0.105, 0.01, 0.29), 0.105, 0.085, 0.48, 0.72, palette["ink"], rig, "calf_l")
    add_tapered_piece("Outfit_Boot_R", (-0.105, 0.01, 0.29), 0.105, 0.085, 0.48, 0.72, palette["ink"], rig, "calf_r")
    bpy.ops.mesh.primitive_torus_add(major_radius=0.045, minor_radius=0.014, major_segments=20, minor_segments=8, location=(0.20, -0.175, 0.98))
    jade = bpy.context.object
    jade.name = "Outfit_JadeToken"
    jade.data.materials.append(palette["jade"])
    bone_parent(jade, rig, "pelvis")


def build_weapons(rig: bpy.types.Object, palette: dict[str, bpy.types.Material]) -> None:
    for side, x, hand in (("L", 0.66, "hand_l"), ("R", -0.66, "hand_r")):
        bpy.ops.mesh.primitive_cone_add(
            vertices=4,
            radius1=0.085,
            radius2=0.0,
            depth=0.42,
            location=(x, -0.03, 1.21),
            rotation=(0.0, 0.0, 0.0),
        )
        blade = bpy.context.object
        blade.name = "DaggerBlade_" + side
        blade.data.materials.append(palette["metal"])
        bone_parent(blade, rig, hand)
        add_box("DaggerGrip_" + side, (x, -0.03, 1.45), (0.07, 0.07, 0.16), palette["leather"], rig, hand, bevel=0.008)


def key_pose(action: bpy.types.Action, rig: bpy.types.Object, frame: int, phase: float, walking: bool) -> None:
    rig.animation_data.action = action
    pelvis = rig.pose.bones["pelvis"]
    spine = rig.pose.bones["spine_03"]
    upper_l = rig.pose.bones["upperarm_l"]
    upper_r = rig.pose.bones["upperarm_r"]
    thigh_l = rig.pose.bones["thigh_l"]
    thigh_r = rig.pose.bones["thigh_r"]
    for bone in (pelvis, spine, upper_l, upper_r, thigh_l, thigh_r):
        bone.rotation_mode = "XYZ"
    pelvis.location = Vector((0.0, 0.0, 0.012 * math.sin(phase)))
    spine.rotation_euler = Vector((0.012 * math.sin(phase), 0.0, 0.018 * math.cos(phase)))
    upper_l.rotation_euler = Vector((0.18 * math.sin(phase) if walking else 0.0, 0.0, -1.12))
    upper_r.rotation_euler = Vector((-0.18 * math.sin(phase) if walking else 0.0, 0.0, 1.12))
    thigh_l.rotation_euler = Vector((0.42 * math.sin(phase) if walking else 0.0, 0.0, 0.0))
    thigh_r.rotation_euler = Vector((-0.42 * math.sin(phase) if walking else 0.0, 0.0, 0.0))
    for bone in (pelvis, spine, upper_l, upper_r, thigh_l, thigh_r):
        bone.keyframe_insert(data_path="location", frame=frame, group=bone.name)
        bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone.name)


def build_animations(rig: bpy.types.Object) -> None:
    rig.animation_data_create()
    idle = bpy.data.actions.new("wuyang_idle")
    for frame, phase in ((1, 0.0), (13, math.pi), (25, math.tau)):
        key_pose(idle, rig, frame, phase, False)
    idle.use_fake_user = True
    walk = bpy.data.actions.new("wuyang_walk")
    for frame, phase in ((1, 0.0), (7, math.pi * 0.5), (13, math.pi), (19, math.pi * 1.5), (25, math.tau)):
        key_pose(walk, rig, frame, phase, True)
    walk.use_fake_user = True
    rig.animation_data.action = idle


def configure_preview(scene: bpy.types.Scene, rig: bpy.types.Object, output: Path) -> None:
    bpy.ops.object.camera_add(location=(3.2, -5.2, 2.9))
    camera = bpy.context.object
    camera.name = "WuyangPreviewCamera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.25
    camera.rotation_euler = (Vector((0.0, 0.0, 0.92)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    bpy.ops.object.light_add(type="AREA", location=(-2.2, -3.0, 4.0))
    key = bpy.context.object
    key.data.energy = 650.0
    key.data.shape = "DISK"
    key.data.size = 4.0
    bpy.ops.object.light_add(type="AREA", location=(2.5, 1.5, 2.8))
    rim = bpy.context.object
    rim.data.energy = 450.0
    rim.data.color = (0.32, 0.48, 0.75)
    rim.data.size = 3.0
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 768
    scene.render.resolution_y = 768
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = str(output)
    rig.animation_data.action = bpy.data.actions["wuyang_idle"]
    scene.frame_set(1)
    bpy.ops.render.render(write_still=True)


def main() -> None:
    root = repository_root()
    base = root / "assets/characters/wuyang/3d/source/base_cc0/Superhero_Female_FullBody.gltf"
    clear_scene()
    bpy.ops.import_scene.gltf(filepath=str(base))
    rig = bpy.data.objects["Armature"]
    rig.name = "Wuyang_Rig"
    palette = build_palette()
    build_hair(rig, palette)
    build_costume(rig, palette)
    build_weapons(rig, palette)
    build_animations(rig)

    source = root / "assets/characters/wuyang/3d/source/wuyang_wuxia_v6.blend"
    runtime = root / "assets/characters/wuyang/3d/wuyang_wuxia_v6.glb"
    preview = root / "assets/characters/wuyang/3d/previews/wuyang_wuxia_v6_preview.png"
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    bpy.ops.export_scene.gltf(
        filepath=str(runtime),
        export_format="GLB",
        export_animations=True,
        export_animation_mode="ACTIONS",
    )
    configure_preview(bpy.context.scene, rig, preview)
    bpy.ops.wm.save_as_mainfile(filepath=str(source))
    print(f"Wuyang v6 source: {source}")
    print(f"Wuyang v6 runtime: {runtime}")
    print(f"Wuyang v6 preview: {preview}")


if __name__ == "__main__":
    main()
