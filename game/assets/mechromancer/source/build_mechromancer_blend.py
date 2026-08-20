"""Build the original Blender source and textured glTF for the Mechromancer.

Run with Blender in background mode:

    blender -b --python build_mechromancer_blend.py

The generated .blend is the editable source of truth. The paired glTF and BIN
files keep the runtime import self-contained while preserving the stable
Godot-facing node and animation contract.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

import bpy
from mathutils import Vector


ASSET_DIR = Path(__file__).resolve().parents[1]
BLEND_PATH = ASSET_DIR / "source" / "mechromancer.blend"
GLTF_PATH = ASSET_DIR / "mechromancer.gltf"
PORTRAIT_PATH = ASSET_DIR / "mechromancer_portrait.png"


def texture_image(
    filename: str,
    base: tuple[float, float, float],
    accent: tuple[float, float, float],
    seed: int,
) -> bpy.types.Image:
    """Create a small original surface texture with deterministic wear variation."""
    size = 256
    rng = random.Random(seed)
    pixels: list[float] = []
    for y in range(size):
        for x in range(size):
            wave = (math.sin(x * 0.17 + seed) + math.sin(y * 0.11 - seed * 0.7)) * 0.08
            grain = (rng.random() - 0.5) * 0.16
            wear = max(0.0, math.sin((x + y * 1.7) * 0.065 + seed) - 0.78) * 0.8
            blend = max(0.0, min(1.0, 0.5 + wave + grain + wear))
            for channel in range(3):
                value = base[channel] * (1.0 - blend) + accent[channel] * blend
                pixels.append(max(0.0, min(1.0, value)))
            pixels.append(1.0)
    image = bpy.data.images.new(filename, width=size, height=size, alpha=True)
    image.pixels = pixels
    image.filepath_raw = str(ASSET_DIR / filename)
    image.file_format = "PNG"
    image.save()
    return image


def normal_image(filename: str, seed: int, strength: float) -> bpy.types.Image:
    """Create an original tangent-space normal map for small-scale surface relief."""
    size = 256
    pixels: list[float] = []
    for y in range(size):
        for x in range(size):
            phase = seed * 0.37
            height_x = math.cos(x * 0.19 + phase) * 0.42 + math.sin((x + y) * 0.07) * 0.18
            height_y = math.sin(y * 0.23 - phase) * 0.38 + math.cos((x - y) * 0.05) * 0.16
            nx = max(0.0, min(1.0, 0.5 - height_x * strength))
            ny = max(0.0, min(1.0, 0.5 - height_y * strength))
            pixels.extend((nx, ny, 1.0, 1.0))
    image = bpy.data.images.new(filename, width=size, height=size, alpha=True)
    image.pixels = pixels
    image.filepath_raw = str(ASSET_DIR / filename)
    image.file_format = "PNG"
    image.colorspace_settings.name = "Non-Color"
    image.save()
    return image


def material(
    name: str,
    color: tuple[float, float, float, float],
    metallic: float,
    roughness: float,
    emission: tuple[float, float, float, float] | None = None,
    image: bpy.types.Image | None = None,
    normal: bpy.types.Image | None = None,
) -> bpy.types.Material:
    result = bpy.data.materials.new(name)
    result.diffuse_color = color
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    if shader is None:
        return result
    shader.inputs["Base Color"].default_value = color
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    if image is not None:
        texture = result.node_tree.nodes.new("ShaderNodeTexImage")
        texture.name = f"{name} wear texture"
        texture.image = image
        texture.interpolation = "Linear"
        result.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
        noise = result.node_tree.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 18.0
        noise.inputs["Detail"].default_value = 3.0
        bump = result.node_tree.nodes.new("ShaderNodeBump")
        bump.inputs["Strength"].default_value = 0.12
        bump.inputs["Distance"].default_value = 0.035
        result.node_tree.links.new(noise.outputs["Fac"], bump.inputs["Height"])
        result.node_tree.links.new(bump.outputs["Normal"], shader.inputs["Normal"])
    if normal is not None:
        normal_texture = result.node_tree.nodes.new("ShaderNodeTexImage")
        normal_texture.name = f"{name} normal map"
        normal_texture.image = normal
        normal_texture.interpolation = "Linear"
        normal_map = result.node_tree.nodes.new("ShaderNodeNormalMap")
        normal_map.inputs["Strength"].default_value = 0.12
        result.node_tree.links.new(normal_texture.outputs["Color"], normal_map.inputs["Color"])
        result.node_tree.links.new(normal_map.outputs["Normal"], shader.inputs["Normal"])
    if emission is not None:
        emission_input = shader.inputs.get("Emission Color") or shader.inputs.get("Emission")
        if emission_input is not None:
            emission_input.default_value = emission
        strength_input = shader.inputs.get("Emission Strength")
        if strength_input is not None:
            strength_input.default_value = 3.0
    return result


def attach(obj: bpy.types.Object, parent: bpy.types.Object, location: tuple[float, float, float]) -> bpy.types.Object:
    obj.parent = parent
    obj.location = location
    return obj


def finish_mesh(obj: bpy.types.Object, name: str, parent: bpy.types.Object, mat: bpy.types.Material) -> bpy.types.Object:
    obj.name = name
    attach(obj, parent, (0.0, 0.0, 0.0))
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.select_set(False)
    return obj


def apply_bevel(obj: bpy.types.Object, amount: float = 0.035, segments: int = 2) -> bpy.types.Object:
    if amount <= 0.0:
        return obj
    modifier = obj.modifiers.new("softened authored edges", "BEVEL")
    modifier.width = amount
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)
    return obj


def smooth_shade(obj: bpy.types.Object) -> bpy.types.Object:
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def box(
    name: str,
    size: tuple[float, float, float],
    location: tuple[float, float, float],
    parent: bpy.types.Object,
    mat: bpy.types.Material,
    bevel_amount: float = 0.035,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(0.0, 0.0, 0.0))
    obj = finish_mesh(bpy.context.object, name, parent, mat)
    obj.dimensions = size
    obj.location = location
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.select_set(False)
    return apply_bevel(obj, bevel_amount)


def cylinder(
    name: str,
    radius: float,
    depth: float,
    location: tuple[float, float, float],
    parent: bpy.types.Object,
    mat: bpy.types.Material,
    vertices: int = 10,
    bevel_amount: float = 0.018,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=(0.0, 0.0, 0.0))
    obj = finish_mesh(bpy.context.object, name, parent, mat)
    obj.location = location
    return smooth_shade(apply_bevel(obj, bevel_amount, 2))


def cone(
    name: str,
    bottom_radius: float,
    top_radius: float,
    depth: float,
    location: tuple[float, float, float],
    parent: bpy.types.Object,
    mat: bpy.types.Material,
    bevel_amount: float = 0.022,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(
        vertices=10,
        radius1=bottom_radius,
        radius2=top_radius,
        depth=depth,
        location=(0.0, 0.0, 0.0),
    )
    obj = finish_mesh(bpy.context.object, name, parent, mat)
    obj.location = location
    return smooth_shade(apply_bevel(obj, bevel_amount, 2))


def uv_sphere(
    name: str,
    scale: tuple[float, float, float],
    location: tuple[float, float, float],
    parent: bpy.types.Object,
    mat: bpy.types.Material,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, location=(0.0, 0.0, 0.0))
    obj = finish_mesh(bpy.context.object, name, parent, mat)
    obj.scale = scale
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.location = location
    obj.select_set(False)
    return smooth_shade(obj)


def torus(
    name: str,
    major_radius: float,
    minor_radius: float,
    location: tuple[float, float, float],
    parent: bpy.types.Object,
    mat: bpy.types.Material,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(
        major_segments=20,
        minor_segments=8,
        major_radius=major_radius,
        minor_radius=minor_radius,
        location=(0.0, 0.0, 0.0),
    )
    obj = finish_mesh(bpy.context.object, name, parent, mat)
    obj.location = location
    return smooth_shade(obj)


def tapered_prism(
    name: str,
    bottom_width: float,
    top_width: float,
    bottom_depth: float,
    top_depth: float,
    height: float,
    location: tuple[float, float, float],
    parent: bpy.types.Object,
    mat: bpy.types.Material,
    bevel_amount: float = 0.035,
) -> bpy.types.Object:
    bottom = [
        (-bottom_width * 0.5, -bottom_depth * 0.5, -height * 0.5),
        (bottom_width * 0.5, -bottom_depth * 0.5, -height * 0.5),
        (bottom_width * 0.5, bottom_depth * 0.5, -height * 0.5),
        (-bottom_width * 0.5, bottom_depth * 0.5, -height * 0.5),
    ]
    top = [
        (-top_width * 0.5, -top_depth * 0.5, height * 0.5),
        (top_width * 0.5, -top_depth * 0.5, height * 0.5),
        (top_width * 0.5, top_depth * 0.5, height * 0.5),
        (-top_width * 0.5, top_depth * 0.5, height * 0.5),
    ]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(bottom + top, [], [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)])
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    attach(obj, parent, location)
    obj.data.materials.append(mat)
    return apply_bevel(obj, bevel_amount)


def sectioned_form(
    name: str,
    sections: list[tuple[float, float, float]],
    location: tuple[float, float, float],
    parent: bpy.types.Object,
    mat: bpy.types.Material,
    segments: int = 16,
) -> bpy.types.Object:
    """Build a smooth human-scale form from elliptical body cross-sections."""
    vertices: list[tuple[float, float, float]] = []
    for z, radius_x, radius_y in sections:
        for segment in range(segments):
            angle = (math.tau * segment) / segments
            vertices.append((math.cos(angle) * radius_x, math.sin(angle) * radius_y, z))
    faces: list[tuple[int, ...]] = []
    faces.append(tuple(range(segments - 1, -1, -1)))
    top_start = (len(sections) - 1) * segments
    faces.append(tuple(top_start + segment for segment in range(segments)))
    for section in range(len(sections) - 1):
        current = section * segments
        next_ring = (section + 1) * segments
        for segment in range(segments):
            next_segment = (segment + 1) % segments
            faces.append((current + segment, next_ring + segment, next_ring + next_segment, current + next_segment))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    attach(obj, parent, location)
    obj.data.materials.append(mat)
    return smooth_shade(obj)


def cloth_surface(obj: bpy.types.Object, level: int = 1) -> bpy.types.Object:
    """Round authored cloth edges without turning the silhouette into a primitive box."""
    modifier = obj.modifiers.new("cloth volume", "SUBSURF")
    modifier.subdivision_type = "CATMULL_CLARK"
    modifier.levels = level
    modifier.render_levels = level
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.select_set(False)
    return smooth_shade(obj)


def socket(name: str, parent: bpy.types.Object, location: tuple[float, float, float]) -> bpy.types.Object:
    obj = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(obj)
    obj.empty_display_type = "SPHERE"
    obj.empty_display_size = 0.08
    attach(obj, parent, location)
    return obj


def multi_action(
    name: str,
    bindings: list[tuple[bpy.types.Object, list[tuple[str, int, list[tuple[float, float]]]]]],
) -> bpy.types.Action:
    result = bpy.data.actions.new(name)
    layer = result.layers.new("Layer")
    strip = layer.strips.new(type="KEYFRAME")
    for obj, curves in bindings:
        slot = result.slots.new("OBJECT", obj.name)
        channelbag = strip.channelbag(slot, ensure=True)
        for data_path, index, keys in curves:
            fcurve = channelbag.fcurves.new(data_path=data_path, index=index)
            for frame, value in keys:
                point = fcurve.keyframe_points.insert(frame, value)
                point.interpolation = "LINEAR"
        obj.animation_data_create()
        obj.animation_data.action = result
        obj.animation_data.action_slot = slot
    return result


def render_portrait() -> None:
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.render.filepath = str(PORTRAIT_PATH)
    bpy.ops.object.camera_add(location=(2.8, -5.0, 2.55))
    camera = bpy.context.object
    camera.name = "PortraitCamera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.75
    camera.rotation_euler = (Vector((0.0, -0.02, 1.30)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera
    for location, energy, color, size in [
        ((2.0, -3.0, 4.0), 850.0, (1.0, 0.72, 0.52), 3.0),
        ((-2.4, -1.5, 2.2), 500.0, (0.22, 0.62, 0.82), 2.5),
    ]:
        bpy.ops.object.light_add(type="AREA", location=location)
        light = bpy.context.object
        light.data.energy = energy
        light.data.color = color
        light.data.shape = "DISK"
        light.data.size = size
        light.rotation_euler = (Vector((0.0, 0.0, 1.25)) - light.location).to_track_quat("-Z", "Y").to_euler()
    world = scene.world
    if world is not None:
        world.use_nodes = True
        background = world.node_tree.nodes.get("Background")
        if background is not None:
            background.inputs["Color"].default_value = (0.004, 0.006, 0.008, 1.0)
            background.inputs["Strength"].default_value = 0.18
    try:
        bpy.ops.render.render(write_still=True)
    finally:
        for obj in list(bpy.context.scene.objects):
            if obj.name == "PortraitCamera" or obj.name.startswith("Area"):
                bpy.data.objects.remove(obj, do_unlink=True)


def main() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.frame_start = 1
    scene.frame_end = 48
    scene.render.fps = 24

    root = bpy.data.objects.new("MechromancerModel", None)
    bpy.context.collection.objects.link(root)
    root.empty_display_type = "PLAIN_AXES"
    root.empty_display_size = 0.1
    root["ironwright_asset_id"] = "mechromancer.player.v1"

    coat_texture = texture_image("mechromancer_coat.png", (0.035, 0.048, 0.060), (0.16, 0.13, 0.10), 11)
    metal_texture = texture_image("mechromancer_metal.png", (0.10, 0.13, 0.15), (0.34, 0.20, 0.12), 23)
    leather_texture = texture_image("mechromancer_leather.png", (0.075, 0.034, 0.018), (0.27, 0.12, 0.045), 37)
    skin_texture = texture_image("mechromancer_skin.png", (0.17, 0.085, 0.055), (0.40, 0.21, 0.13), 47)
    coat_normal = normal_image("mechromancer_coat_normal.png", 11, 0.20)
    metal_normal = normal_image("mechromancer_metal_normal.png", 23, 0.16)
    leather_normal = normal_image("mechromancer_leather_normal.png", 37, 0.18)
    skin_normal = normal_image("mechromancer_skin_normal.png", 47, 0.08)
    coat = material("Worn charcoal coat", (0.035, 0.048, 0.060, 1.0), 0.04, 0.92, image=coat_texture, normal=coat_normal)
    coat_fold = material("Faded coat folds", (0.055, 0.065, 0.070, 1.0), 0.02, 0.96, image=coat_texture, normal=coat_normal)
    metal = material("Oxidized field metal", (0.10, 0.13, 0.15, 1.0), 0.68, 0.50, image=metal_texture, normal=metal_normal)
    leather = material("Weathered leather", (0.075, 0.034, 0.018, 1.0), 0.02, 0.88, image=leather_texture, normal=leather_normal)
    skin = material("Skin", (0.17, 0.085, 0.055, 1.0), 0.0, 0.78, image=skin_texture, normal=skin_normal)
    hood_inner = material("Hood interior", (0.026, 0.032, 0.036, 1.0), 0.0, 0.98)
    glass = material("Smoked cyan visor", (0.018, 0.08, 0.09, 1.0), 0.34, 0.24, (0.06, 0.45, 0.52, 1.0))
    cyan = material("Cognition cyan", (0.025, 0.24, 0.27, 1.0), 0.28, 0.25, (0.12, 0.8, 0.85, 1.0))
    warm = material("Warm utility light", (0.46, 0.20, 0.06, 1.0), 0.12, 0.56, (0.95, 0.31, 0.08, 1.0))
    gun = material("Weak sidearm", (0.025, 0.030, 0.034, 1.0), 0.84, 0.32, image=metal_texture)

    torso = sectioned_form(
        "Torso",
        [(-0.40, 0.23, 0.15), (-0.28, 0.28, 0.17), (0.02, 0.31, 0.19), (0.28, 0.34, 0.18), (0.40, 0.15, 0.12)],
        (0.0, 0.0, 1.42),
        root,
        coat,
    )
    tapered_prism("FieldVest", 0.36, 0.29, 0.08, 0.06, 0.36, (0.0, -0.245, 1.47), root, leather, 0.030)
    tapered_prism("ChestInset", 0.25, 0.20, 0.035, 0.028, 0.17, (0.0, -0.292, 1.51), root, metal, 0.012)
    vest_left = box("VestLapelsLeft", (0.07, 0.035, 0.34), (-0.16, -0.285, 1.52), root, coat, 0.014)
    vest_left.rotation_euler.y = -0.18
    vest_right = box("VestLapelsRight", (0.07, 0.035, 0.34), (0.16, -0.285, 1.52), root, coat, 0.014)
    vest_right.rotation_euler.y = 0.18
    scarf = tapered_prism("Scarf", 0.40, 0.32, 0.18, 0.14, 0.11, (0.0, -0.03, 1.79), root, leather, 0.025)
    scarf.rotation_euler.y = -0.04
    scarf_tail = box("ScarfTail", (0.12, 0.05, 0.22), (-0.12, -0.15, 1.69), root, leather, 0.015)
    scarf_tail.rotation_euler.y = -0.18
    box("Collar", (0.38, 0.20, 0.11), (0.0, -0.08, 1.80), root, coat, 0.030)

    hood = uv_sphere("Hood", (0.35, 0.23, 0.27), (0.0, 0.22, 2.11), root, coat)
    hood.rotation_euler.x = -0.10
    tapered_prism("HoodBackDrape", 0.62, 0.40, 0.18, 0.10, 0.56, (0.0, 0.29, 1.91), root, coat, 0.040)
    hood_drape_left = tapered_prism("HoodDrapeLeft", 0.22, 0.12, 0.10, 0.07, 0.38, (-0.23, 0.24, 1.78), root, coat, 0.025)
    hood_drape_left.rotation_euler.y = -0.12
    hood_drape_right = tapered_prism("HoodDrapeRight", 0.22, 0.12, 0.10, 0.07, 0.38, (0.23, 0.24, 1.78), root, coat, 0.025)
    hood_drape_right.rotation_euler.y = 0.12
    box("HoodBackSeam", (0.045, 0.035, 0.36), (0.0, 0.385, 1.92), root, leather, 0.012)
    hood_fold_left = box("HoodFoldLeft", (0.035, 0.025, 0.26), (-0.18, 0.405, 2.06), root, coat_fold, 0.010)
    hood_fold_left.rotation_euler.y = -0.12
    hood_fold_right = box("HoodFoldRight", (0.035, 0.025, 0.24), (0.18, 0.405, 2.05), root, coat_fold, 0.010)
    hood_fold_right.rotation_euler.y = 0.12
    hood_brim = tapered_prism("HoodBrim", 0.46, 0.38, 0.16, 0.12, 0.055, (0.0, -0.16, 2.255), root, coat, 0.022)
    hood_brim.rotation_euler.x = -0.12
    box("HoodBrimTrim", (0.36, 0.020, 0.022), (0.0, -0.255, 2.235), root, leather, 0.008)
    tapered_prism("HoodShadow", 0.38, 0.31, 0.045, 0.035, 0.32, (0.0, -0.18, 2.06), root, hood_inner, 0.020)
    hood_left = tapered_prism("HoodSideLeft", 0.18, 0.12, 0.08, 0.06, 0.38, (-0.235, -0.01, 2.08), root, coat, 0.020)
    hood_left.rotation_euler.y = -0.18
    hood_right = tapered_prism("HoodSideRight", 0.18, 0.12, 0.08, 0.06, 0.38, (0.235, -0.01, 2.08), root, coat, 0.020)
    hood_right.rotation_euler.y = 0.18
    socket("FaceAnchor", root, (0.0, -0.275, 2.05))["socket_type"] = "face_anchor"
    uv_sphere("Face", (0.16, 0.115, 0.21), (0.0, -0.245, 2.05), root, skin)
    uv_sphere("Chin", (0.105, 0.075, 0.085), (0.0, -0.32, 1.93), root, skin)
    uv_sphere("Nose", (0.024, 0.024, 0.036), (0.0, -0.362, 2.015), root, skin)
    uv_sphere("EarLeft", (0.035, 0.025, 0.055), (-0.17, -0.245, 2.04), root, skin)
    uv_sphere("EarRight", (0.035, 0.025, 0.055), (0.17, -0.245, 2.04), root, skin)
    box("Brow", (0.20, 0.045, 0.045), (0.0, -0.35, 2.145), root, skin, 0.012)
    box("VisorFrame", (0.26, 0.055, 0.088), (0.0, -0.335, 2.08), root, metal, 0.022)
    box("Visor", (0.21, 0.022, 0.043), (0.0, -0.372, 2.085), root, glass, 0.012)
    box("VisorGlow", (0.15, 0.010, 0.014), (0.0, -0.389, 2.085), root, cyan, 0.005)
    cylinder("Neck", 0.12, 0.17, (0.0, 0.0, 1.83), root, skin, 16, 0.015)

    left_shoulder = uv_sphere("LeftShoulder", (0.22, 0.18, 0.14), (-0.39, -0.01, 1.68), root, coat)
    right_shoulder = uv_sphere("RightShoulder", (0.22, 0.18, 0.14), (0.39, -0.01, 1.68), root, coat)
    box("LeftShoulderPad", (0.25, 0.24, 0.075), (-0.41, -0.03, 1.76), root, leather, 0.030).rotation_euler.y = -0.12
    box("RightShoulderPad", (0.25, 0.24, 0.075), (0.41, -0.03, 1.76), root, leather, 0.030).rotation_euler.y = 0.12

    left_arm = cone("LeftArm", 0.095, 0.125, 0.70, (-0.49, -0.01, 1.36), root, coat, 0.025)
    left_arm.rotation_euler.y = -0.10
    right_arm = cone("RightArm", 0.095, 0.125, 0.70, (0.49, -0.01, 1.36), root, coat, 0.025)
    right_arm.rotation_euler.y = 0.10
    cylinder("LeftForearmGuard", 0.105, 0.20, (-0.52, -0.10, 1.12), root, metal, 10, 0.018).rotation_euler.x = math.pi * 0.5
    cylinder("RightForearmGuard", 0.105, 0.20, (0.52, -0.10, 1.12), root, metal, 10, 0.018).rotation_euler.x = math.pi * 0.5
    left_glove = box("LeftGlove", (0.14, 0.12, 0.18), (-0.53, -0.19, 0.98), root, leather, 0.040)
    left_glove.rotation_euler.y = -0.12
    right_glove = box("RightGlove", (0.14, 0.12, 0.18), (0.53, -0.19, 0.98), root, leather, 0.040)
    right_glove.rotation_euler.y = 0.12
    uv_sphere("LeftGloveThumb", (0.045, 0.040, 0.065), (-0.60, -0.245, 0.99), root, leather)
    uv_sphere("RightGloveThumb", (0.045, 0.040, 0.065), (0.60, -0.245, 0.99), root, leather)

    left_leg = cone("LeftLeg", 0.115, 0.145, 0.68, (-0.19, 0.02, 0.52), root, leather, 0.025)
    right_leg = cone("RightLeg", 0.115, 0.145, 0.68, (0.19, 0.02, 0.52), root, leather, 0.025)
    box("LeftBoot", (0.25, 0.38, 0.17), (-0.19, -0.11, 0.14), root, leather, 0.045)
    box("RightBoot", (0.25, 0.38, 0.17), (0.19, -0.11, 0.14), root, leather, 0.045)
    box("LeftBootToe", (0.25, 0.16, 0.055), (-0.19, -0.235, 0.10), root, metal, 0.018)
    box("RightBootToe", (0.25, 0.16, 0.055), (0.19, -0.235, 0.10), root, metal, 0.018)
    box("LeftBootStrap", (0.26, 0.045, 0.045), (-0.19, -0.315, 0.19), root, leather, 0.010)
    box("RightBootStrap", (0.26, 0.045, 0.045), (0.19, -0.315, 0.19), root, leather, 0.010)

    coat_left = tapered_prism("CoatTailLeft", 0.44, 0.32, 0.24, 0.16, 0.98, (-0.24, 0.07, 0.70), root, coat, 0.045)
    coat_left.rotation_euler.y = -0.035
    cloth_surface(coat_left)
    coat_right = tapered_prism("CoatTailRight", 0.44, 0.32, 0.24, 0.16, 0.98, (0.24, 0.07, 0.70), root, coat, 0.045)
    coat_right.rotation_euler.y = 0.055
    cloth_surface(coat_right)
    box("CoatHemLeft", (0.42, 0.20, 0.055), (-0.24, 0.06, 0.225), root, leather, 0.018)
    box("CoatHemRight", (0.42, 0.20, 0.055), (0.24, 0.06, 0.225), root, leather, 0.018)
    box("CoatBackSplit", (0.045, 0.035, 0.76), (0.0, 0.205, 0.72), root, leather, 0.012)
    box("CoatBackStrapLeft", (0.045, 0.035, 0.68), (-0.36, 0.205, 0.70), root, leather, 0.010).rotation_euler.y = -0.08
    box("CoatBackStrapRight", (0.045, 0.035, 0.68), (0.36, 0.205, 0.70), root, leather, 0.010).rotation_euler.y = 0.08
    coat_fold_left = box("CoatFabricFoldLeft", (0.035, 0.025, 0.64), (-0.13, 0.215, 0.72), root, coat_fold, 0.010)
    coat_fold_left.rotation_euler.y = -0.06
    coat_fold_right = box("CoatFabricFoldRight", (0.035, 0.025, 0.58), (0.13, 0.215, 0.68), root, coat_fold, 0.010)
    coat_fold_right.rotation_euler.y = 0.08
    box("CoatTailStrapLeft", (0.045, 0.035, 0.70), (-0.36, -0.18, 0.70), root, leather, 0.010).rotation_euler.y = -0.08
    box("CoatTailStrapRight", (0.045, 0.035, 0.70), (0.36, -0.18, 0.70), root, leather, 0.010).rotation_euler.y = 0.08

    box("UtilityBelt", (0.64, 0.09, 0.13), (0.0, -0.22, 1.08), root, leather, 0.028)
    box("BeltBuckle", (0.12, 0.035, 0.10), (0.0, -0.285, 1.08), root, metal, 0.016)
    for side in (-1.0, 1.0):
        box("BeltPouch" + ("Left" if side < 0 else "Right"), (0.14, 0.13, 0.16), (side * 0.28, -0.25, 1.00), root, leather, 0.025)
    harness_left = box("HarnessLeft", (0.055, 0.040, 0.62), (-0.17, -0.255, 1.42), root, leather, 0.012)
    harness_left.rotation_euler.y = -0.24
    harness_right = box("HarnessRight", (0.055, 0.040, 0.62), (0.17, -0.255, 1.42), root, leather, 0.012)
    harness_right.rotation_euler.y = 0.24
    harness_cross = box("HarnessCross", (0.055, 0.040, 0.72), (-0.03, -0.268, 1.43), root, leather, 0.012)
    harness_cross.rotation_euler.y = -0.52
    coat_fold_left = box("CoatFoldLeft", (0.035, 0.022, 0.58), (-0.28, -0.215, 0.70), root, leather, 0.009)
    coat_fold_left.rotation_euler.y = -0.06
    coat_fold_right = box("CoatFoldRight", (0.035, 0.022, 0.48), (0.28, -0.215, 0.66), root, leather, 0.009)
    coat_fold_right.rotation_euler.y = 0.10

    pack = tapered_prism("FieldPack", 0.50, 0.39, 0.30, 0.22, 0.66, (-0.23, 0.31, 1.33), root, leather, 0.065)
    pack["socket_type"] = "equipment_mount"
    pack_roll = cylinder("PackTopRoll", 0.095, 0.40, (-0.23, 0.31, 1.70), root, leather, 16, 0.025)
    pack_roll.rotation_euler.y = math.pi * 0.5
    box("PackBackPanel", (0.30, 0.035, 0.34), (-0.23, 0.475, 1.33), root, metal, 0.025)
    box("PackPocketLeft", (0.18, 0.14, 0.20), (-0.47, 0.43, 1.20), root, leather, 0.040)
    box("PackPocketRight", (0.18, 0.14, 0.20), (0.01, 0.43, 1.20), root, leather, 0.040)
    box("PackStrapLeft", (0.045, 0.025, 0.50), (-0.36, 0.50, 1.36), root, leather, 0.012)
    box("PackStrapRight", (0.045, 0.025, 0.50), (-0.10, 0.50, 1.36), root, leather, 0.012)
    back_harness = box("BackHarness", (0.055, 0.035, 0.88), (0.10, 0.23, 1.30), root, leather, 0.012)
    back_harness.rotation_euler.y = -0.34

    shoulder_lamp = socket("ShoulderLamp", root, (-0.43, -0.20, 1.78))
    shoulder_lamp["socket_type"] = "light_mount"
    tapered_prism("ShoulderLampHousing", 0.17, 0.13, 0.16, 0.11, 0.14, (-0.43, -0.20, 1.78), root, metal, 0.030)
    cylinder("LampRing", 0.068, 0.045, (-0.43, -0.315, 1.78), root, metal, 12, 0.012).rotation_euler.x = math.pi * 0.5
    cylinder("LampCore", 0.041, 0.035, (-0.43, -0.345, 1.78), root, cyan, 12, 0.008).rotation_euler.x = math.pi * 0.5
    box("LampMount", (0.055, 0.20, 0.06), (-0.43, -0.12, 1.69), root, leather, 0.012)
    cylinder("WarmLamp", 0.048, 0.11, (0.31, -0.22, 1.46), root, warm, 10, 0.010).rotation_euler.x = math.pi * 0.5

    pistol = box("WeakPistol", (0.18, 0.27, 0.115), (0.54, -0.29, 1.08), root, gun, 0.025)
    pistol["socket_type"] = "weapon_mount"
    barrel = cylinder("PistolBarrel", 0.040, 0.30, (0.0, -0.27, 0.015), pistol, gun, 10, 0.010)
    barrel.rotation_euler.x = math.pi * 0.5
    grip = box("PistolGrip", (0.11, 0.13, 0.25), (0.0, 0.02, -0.14), pistol, gun, 0.022)
    grip.rotation_euler.x = -0.20
    box("PistolSlide", (0.16, 0.18, 0.055), (0.0, -0.39, 0.07), pistol, gun, 0.014)
    trigger_guard = torus("PistolTriggerGuard", 0.055, 0.012, (0.0, -0.02, -0.02), pistol, gun)
    trigger_guard.rotation_euler.x = math.pi * 0.5
    trigger_guard.scale.x = 0.80
    bpy.context.view_layer.objects.active = trigger_guard
    trigger_guard.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    trigger_guard.select_set(False)
    muzzle = socket("PistolMuzzle", pistol, (0.0, -0.43, 0.015))
    muzzle["socket_type"] = "weapon_muzzle"
    field_tool = box("FieldTool", (0.075, 0.075, 0.34), (-0.34, -0.20, 1.28), root, metal, 0.020)
    field_tool.rotation_euler.y = -0.18
    box("FieldToolHead", (0.20, 0.08, 0.075), (-0.39, -0.21, 1.43), root, metal, 0.018).rotation_euler.y = -0.18
    marker = socket("ProductionAssetMarker", root, (0.0, 0.0, 0.0))
    marker["asset_contract"] = "mechromancer.player.v1"

    multi_action("Idle", [
        (root, [("location", 2, [(1.0, 0.0), (20.0, 0.012), (40.0, 0.0)])]),
        (hood, [("location", 2, [(1.0, 2.08), (20.0, 2.092), (40.0, 2.08)])]),
        (coat_left, [("rotation_euler", 1, [(1.0, -0.015), (20.0, 0.02), (40.0, -0.015)])]),
        (coat_right, [("rotation_euler", 1, [(1.0, 0.015), (20.0, -0.02), (40.0, 0.015)])]),
        (pack, [("location", 2, [(1.0, 1.34), (20.0, 1.35), (40.0, 1.34)])]),
    ])
    multi_action("Walk", [
        (root, [("location", 2, [(1.0, 0.0), (6.0, 0.025), (12.0, 0.0)]), ("rotation_euler", 1, [(1.0, -0.015), (6.0, 0.025), (12.0, -0.015)])]),
        (left_leg, [("rotation_euler", 0, [(1.0, 0.20), (6.0, -0.28), (12.0, 0.20)])]),
        (right_leg, [("rotation_euler", 0, [(1.0, -0.28), (6.0, 0.20), (12.0, -0.28)])]),
        (coat_left, [("rotation_euler", 1, [(1.0, -0.10), (6.0, 0.14), (12.0, -0.10)])]),
        (coat_right, [("rotation_euler", 1, [(1.0, 0.10), (6.0, -0.14), (12.0, 0.10)])]),
        (pack, [("location", 2, [(1.0, 1.33), (6.0, 1.38), (12.0, 1.33)])]),
    ])
    multi_action("Fire", [
        (pistol, [("location", 1, [(1.0, -0.29), (3.0, -0.36), (5.0, -0.29)]), ("rotation_euler", 0, [(1.0, 0.0), (3.0, -0.06), (5.0, 0.0)])]),
        (right_arm, [("rotation_euler", 1, [(1.0, 0.10), (3.0, 0.04), (5.0, 0.10)])]),
    ])
    multi_action("Work", [
        (left_arm, [("rotation_euler", 0, [(1.0, 0.0), (12.0, -0.28), (24.0, 0.0)])]),
        (right_arm, [("rotation_euler", 0, [(1.0, 0.0), (12.0, -0.48), (24.0, 0.0)])]),
        (coat_left, [("rotation_euler", 1, [(1.0, -0.02), (12.0, 0.08), (24.0, -0.02)])]),
        (coat_right, [("rotation_euler", 1, [(1.0, 0.02), (12.0, -0.08), (24.0, 0.02)])]),
    ])
    multi_action("Hit", [
        (root, [("rotation_euler", 1, [(1.0, 0.0), (3.0, 0.10), (7.0, 0.0)])]),
        (pack, [("rotation_euler", 1, [(1.0, 0.0), (3.0, -0.08), (7.0, 0.0)])]),
        (coat_left, [("rotation_euler", 1, [(1.0, 0.0), (3.0, 0.10), (7.0, 0.0)])]),
        (coat_right, [("rotation_euler", 1, [(1.0, 0.0), (3.0, 0.10), (7.0, 0.0)])]),
    ])

    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = root
    scene["ironwright_asset_id"] = "mechromancer.player.v1"
    scene["required_nodes"] = "MechromancerModel,PistolMuzzle,ShoulderLamp,FaceAnchor,FieldPack,CoatTailLeft,CoatTailRight"
    scene["animation_clips"] = "Idle,Walk,Fire,Work,Hit"
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.export_scene.gltf(
        filepath=str(GLTF_PATH),
        export_format="GLTF_SEPARATE",
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_nla_strips=False,
        export_current_frame=False,
        export_extras=True,
        export_materials="EXPORT",
        export_yup=True,
        use_selection=True,
    )
    render_portrait()
    backup_path = BLEND_PATH.with_suffix(BLEND_PATH.suffix + "1")
    if backup_path.exists():
        backup_path.unlink()
    print(f"Wrote {BLEND_PATH}")
    print(f"Wrote {GLTF_PATH}")


if __name__ == "__main__":
    main()
