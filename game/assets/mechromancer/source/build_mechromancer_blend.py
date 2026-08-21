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
            wave = (
                math.sin(x * 0.045 + seed) * 0.035
                + math.sin(y * 0.031 - seed * 0.7) * 0.028
                + math.sin((x - y) * 0.013 + seed * 0.2) * 0.018
            )
            grain = (rng.random() - 0.5) * 0.055
            wear = max(0.0, math.sin((x + y * 1.7) * 0.023 + seed) - 0.88) * 0.34
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
            height_x = math.cos(x * 0.072 + phase) * 0.18 + math.sin((x + y) * 0.026) * 0.08
            height_y = math.sin(y * 0.084 - phase) * 0.16 + math.cos((x - y) * 0.021) * 0.07
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
        bump.inputs["Strength"].default_value = 0.06
        bump.inputs["Distance"].default_value = 0.035
        result.node_tree.links.new(noise.outputs["Fac"], bump.inputs["Height"])
        result.node_tree.links.new(bump.outputs["Normal"], shader.inputs["Normal"])
    if normal is not None:
        normal_texture = result.node_tree.nodes.new("ShaderNodeTexImage")
        normal_texture.name = f"{name} normal map"
        normal_texture.image = normal
        normal_texture.interpolation = "Linear"
        normal_map = result.node_tree.nodes.new("ShaderNodeNormalMap")
        normal_map.inputs["Strength"].default_value = 0.07
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


def project_uv(mesh: bpy.types.Mesh) -> None:
    """Give authored meshes deterministic planar UVs for the original wear maps."""
    if len(mesh.vertices) == 0:
        return
    x_values = [vertex.co.x for vertex in mesh.vertices]
    z_values = [vertex.co.z for vertex in mesh.vertices]
    x_center = (min(x_values) + max(x_values)) * 0.5
    z_center = (min(z_values) + max(z_values)) * 0.5
    x_extent = max(0.001, max(x_values) - min(x_values))
    z_extent = max(0.001, max(z_values) - min(z_values))
    layer = mesh.uv_layers.new(name="UVMap")
    for loop in mesh.loops:
        coordinate = mesh.vertices[loop.vertex_index].co
        layer.data[loop.index].uv = (
            (coordinate.x - x_center) / x_extent + 0.5,
            (coordinate.z - z_center) / z_extent + 0.5,
        )


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
    project_uv(mesh)
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
    project_uv(mesh)
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


def cloth_panel(
    name: str,
    outline: list[tuple[float, float]],
    depth: float,
    location: tuple[float, float, float],
    parent: bpy.types.Object,
    mat: bpy.types.Material,
    bevel_amount: float = 0.028,
) -> bpy.types.Object:
    """Extrude an irregular X/Z cloth panel with enough volume to catch light."""
    count = len(outline)
    vertices: list[tuple[float, float, float]] = []
    for x, z in outline:
        vertices.append((x, -depth * 0.5, z))
    for x, z in outline:
        vertices.append((x, depth * 0.5, z))
    faces: list[tuple[int, ...]] = [
        tuple(range(count - 1, -1, -1)),
        tuple(count + index for index in range(count)),
    ]
    for index in range(count):
        next_index = (index + 1) % count
        faces.append((index, next_index, count + next_index, count + index))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    project_uv(mesh)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    attach(obj, parent, location)
    obj.data.materials.append(mat)
    # Keep the bevel deliberately shallow: the panel's irregular outline is
    # authored for silhouette readability, while a single segment catches a
    # practical edge highlight without the pathological cost of a multi-
    # segment bevel on an n-gon.
    return apply_bevel(obj, min(bevel_amount, 0.020), 1)


def limb_between(
    name: str,
    start: tuple[float, float, float],
    end: tuple[float, float, float],
    radius: float,
    parent: bpy.types.Object,
    mat: bpy.types.Material,
    taper: float = 1.0,
    bevel_amount: float = 0.018,
) -> bpy.types.Object:
    """Create a softly tapered limb between two authored anatomical landmarks."""
    start_vector = Vector(start)
    end_vector = Vector(end)
    direction = end_vector - start_vector
    length = direction.length
    bpy.ops.mesh.primitive_cone_add(
        vertices=14,
        radius1=radius,
        radius2=radius * taper,
        depth=length,
        location=(0.0, 0.0, 0.0),
    )
    obj = finish_mesh(bpy.context.object, name, parent, mat)
    obj.location = (start_vector + end_vector) * 0.5
    obj.rotation_euler = direction.to_track_quat("Z", "Y").to_euler()
    return smooth_shade(apply_bevel(obj, bevel_amount, 2))


def arc_ribbon(
    name: str,
    center: tuple[float, float, float],
    radius: float,
    width: float,
    depth: float,
    parent: bpy.types.Object,
    mat: bpy.types.Material,
    start_angle: float,
    end_angle: float,
) -> bpy.types.Object:
    """Make a broad curved fabric rim instead of a hard circular sensor-like tube."""
    segments = 18
    vertices: list[tuple[float, float, float]] = []
    for y in (-depth * 0.5, depth * 0.5):
        for radius_offset in (width * 0.5, -width * 0.5):
            for index in range(segments + 1):
                angle = start_angle + (end_angle - start_angle) * index / segments
                current_radius = radius + radius_offset
                vertices.append((
                    math.cos(angle) * current_radius,
                    y,
                    math.sin(angle) * current_radius,
                ))
    ring = segments + 1
    faces: list[tuple[int, ...]] = []
    for index in range(segments):
        next_index = index + 1
        faces.append((index, next_index, ring + next_index, ring + index))
        faces.append((2 * ring + index, 3 * ring + index, 3 * ring + next_index, 2 * ring + next_index))
        faces.append((index, 2 * ring + index, 2 * ring + next_index, next_index))
        faces.append((ring + index, ring + next_index, 3 * ring + next_index, 3 * ring + index))
    faces.extend([
        (0, ring, 3 * ring, 2 * ring),
        (segments, 3 * ring - 1, 4 * ring - 1, 2 * ring - 1),
    ])
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    project_uv(mesh)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    attach(obj, parent, center)
    obj.data.materials.append(mat)
    return smooth_shade(obj)


def arc_band(
    name: str,
    center: tuple[float, float, float],
    radius: float,
    tube_radius: float,
    parent: bpy.types.Object,
    mat: bpy.types.Material,
    start_angle: float = 0.0,
    end_angle: float = math.pi,
) -> bpy.types.Object:
    """Create a curved cloth rim in the X/Z plane for a hood or collar opening."""
    curve_data = bpy.data.curves.new(name, type="CURVE")
    curve_data.dimensions = "3D"
    curve_data.resolution_u = 16
    curve_data.bevel_depth = tube_radius
    curve_data.bevel_resolution = 3
    spline = curve_data.splines.new("NURBS")
    point_count = 13
    spline.points.add(point_count - 1)
    for index, point in enumerate(spline.points):
        angle = start_angle + (end_angle - start_angle) * index / (point_count - 1)
        point.co = (
            center[0] + math.cos(angle) * radius,
            center[1],
            center[2] + math.sin(angle) * radius,
            1.0,
        )
    spline.order_u = 3
    spline.use_endpoint_u = True
    obj = bpy.data.objects.new(name, curve_data)
    bpy.context.collection.objects.link(obj)
    attach(obj, parent, (0.0, 0.0, 0.0))
    curve_data.materials.append(mat)
    return obj


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
    action_strip = layer.strips.new(type="KEYFRAME")
    for obj, curves in bindings:
        slot = result.slots.new("OBJECT", obj.name)
        channelbag = action_strip.channelbag(slot, ensure=True)
        for data_path, index, keys in curves:
            fcurve = channelbag.fcurves.new(data_path=data_path, index=index)
            for frame, value in keys:
                point = fcurve.keyframe_points.insert(frame, value)
                point.interpolation = "LINEAR"
        obj.animation_data_create()
        track = obj.animation_data.nla_tracks.new()
        track.name = f"Authored_{name}_{obj.name}"
        nla_strip = track.strips.new(name, int(result.frame_start), result)
        nla_strip.action_slot = slot
        nla_strip.action_frame_start = result.frame_start
        nla_strip.action_frame_end = result.frame_end
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

    coat_texture = texture_image("mechromancer_coat.png", (0.025, 0.035, 0.045), (0.10, 0.12, 0.13), 11)
    metal_texture = texture_image("mechromancer_metal.png", (0.10, 0.12, 0.13), (0.30, 0.24, 0.17), 23)
    leather_texture = texture_image("mechromancer_leather.png", (0.075, 0.028, 0.012), (0.31, 0.13, 0.045), 37)
    skin_texture = texture_image("mechromancer_skin.png", (0.24, 0.10, 0.055), (0.56, 0.28, 0.15), 47)
    coat_normal = normal_image("mechromancer_coat_normal.png", 11, 0.20)
    metal_normal = normal_image("mechromancer_metal_normal.png", 23, 0.16)
    leather_normal = normal_image("mechromancer_leather_normal.png", 37, 0.18)
    skin_normal = normal_image("mechromancer_skin_normal.png", 47, 0.08)
    coat = material("Worn charcoal coat", (0.025, 0.035, 0.045, 1.0), 0.04, 0.92, image=coat_texture, normal=coat_normal)
    coat_fold = material("Faded coat folds", (0.075, 0.090, 0.100, 1.0), 0.02, 0.96, image=coat_texture, normal=coat_normal)
    coat_tail = material("Heavy charcoal coat tails", (0.050, 0.068, 0.078, 1.0), 0.03, 0.94, image=coat_texture, normal=coat_normal)
    metal = material("Oxidized field metal", (0.13, 0.15, 0.16, 1.0), 0.68, 0.50, image=metal_texture, normal=metal_normal)
    leather = material("Weathered leather", (0.11, 0.040, 0.014, 1.0), 0.02, 0.88, image=leather_texture, normal=leather_normal)
    skin = material("Skin", (0.30, 0.13, 0.070, 1.0), 0.0, 0.70, image=skin_texture, normal=skin_normal)
    hood_inner = material("Hood interior", (0.026, 0.032, 0.036, 1.0), 0.0, 0.98)
    glass = material("Smoked cyan visor", (0.018, 0.08, 0.09, 1.0), 0.34, 0.24, (0.06, 0.45, 0.52, 1.0))
    cyan = material("Cognition cyan", (0.025, 0.24, 0.27, 1.0), 0.28, 0.25, (0.12, 0.8, 0.85, 1.0))
    warm = material("Warm utility light", (0.46, 0.20, 0.06, 1.0), 0.12, 0.56, (0.95, 0.31, 0.08, 1.0))
    gun = material("Weak sidearm", (0.025, 0.030, 0.034, 1.0), 0.84, 0.32, image=metal_texture)

    torso = sectioned_form(
        "Torso",
        [(-0.37, 0.21, 0.13), (-0.27, 0.25, 0.15), (0.00, 0.29, 0.17), (0.25, 0.28, 0.15), (0.37, 0.19, 0.12)],
        (0.0, 0.0, 1.34),
        root,
        coat,
        20,
    )
    cloth_panel("FieldVest", [(-0.22, -0.20), (0.22, -0.20), (0.19, 0.20), (0.10, 0.29), (-0.11, 0.28), (-0.20, 0.18)], 0.105, (0.0, -0.20, 1.43), root, leather, 0.026)
    cloth_panel("ChestInset", [(-0.13, -0.08), (0.14, -0.08), (0.12, 0.11), (0.04, 0.16), (-0.09, 0.14)], 0.035, (0.0, -0.265, 1.49), root, metal, 0.014)
    vest_left = limb_between("VestLapelsLeft", (-0.16, -0.275, 1.29), (-0.08, -0.275, 1.67), 0.026, root, coat, 0.88, 0.008)
    vest_right = limb_between("VestLapelsRight", (0.16, -0.275, 1.29), (0.08, -0.275, 1.67), 0.026, root, coat, 0.88, 0.008)
    scarf = torus("ScarfCollar", 0.205, 0.045, (0.0, -0.005, 1.78), root, leather)
    scarf_tail = cloth_panel("ScarfTail", [(-0.08, 0.13), (0.10, 0.12), (0.08, -0.20), (-0.04, -0.26)], 0.075, (-0.10, -0.20, 1.62), root, leather, 0.018)
    scarf_tail.rotation_euler.y = -0.12
    cloth_panel("Collar", [(-0.23, -0.03), (0.23, -0.03), (0.16, 0.12), (-0.16, 0.12)], 0.13, (0.0, -0.06, 1.79), root, coat, 0.028)

    hood = uv_sphere("Hood", (0.33, 0.23, 0.28), (0.0, 0.16, 2.08), root, coat)
    hood.rotation_euler.x = -0.10
    cloth_panel("HoodBackDrape", [(-0.28, 0.26), (0.30, 0.25), (0.23, -0.28), (-0.24, -0.30)], 0.18, (0.0, 0.28, 1.88), root, coat, 0.035)
    hood_drape_left = cloth_panel("HoodDrapeLeft", [(-0.13, 0.20), (0.10, 0.18), (0.08, -0.22), (-0.12, -0.25)], 0.10, (-0.22, 0.18, 1.83), root, coat, 0.022)
    hood_drape_left.rotation_euler.y = -0.12
    hood_drape_right = cloth_panel("HoodDrapeRight", [(-0.10, 0.18), (0.13, 0.20), (0.12, -0.24), (-0.08, -0.22)], 0.10, (0.22, 0.18, 1.83), root, coat, 0.022)
    hood_drape_right.rotation_euler.y = 0.12
    limb_between("HoodBackSeam", (0.0, 0.39, 1.78), (0.0, 0.39, 2.18), 0.018, root, leather, 0.80, 0.006)
    limb_between("HoodFoldLeft", (-0.20, 0.38, 1.92), (-0.15, 0.38, 2.19), 0.014, root, coat_fold, 0.80, 0.004)
    limb_between("HoodFoldRight", (0.20, 0.38, 1.92), (0.15, 0.38, 2.19), 0.014, root, coat_fold, 0.80, 0.004)
    arc_ribbon("HoodRim", (0.0, -0.32, 2.03), 0.245, 0.082, 0.050, root, coat_fold, math.pi * 0.10, math.pi * 0.90)
    cloth_panel("HoodOpening", [(-0.18, 0.10), (0.18, 0.10), (0.16, -0.12), (-0.16, -0.12)], 0.028, (0.0, -0.35, 2.05), root, hood_inner, 0.010)
    socket("FaceAnchor", root, (0.0, -0.30, 2.05))["socket_type"] = "face_anchor"
    uv_sphere("Face", (0.17, 0.12, 0.21), (0.0, -0.35, 2.05), root, skin)
    uv_sphere("Chin", (0.11, 0.08, 0.085), (0.0, -0.42, 1.93), root, skin)
    uv_sphere("CheekLeft", (0.065, 0.050, 0.075), (-0.095, -0.415, 2.00), root, skin)
    uv_sphere("CheekRight", (0.065, 0.050, 0.075), (0.095, -0.415, 2.00), root, skin)
    uv_sphere("Nose", (0.026, 0.027, 0.040), (0.0, -0.47, 2.015), root, skin)
    uv_sphere("EarLeft", (0.036, 0.027, 0.060), (-0.175, -0.35, 2.04), root, skin)
    uv_sphere("EarRight", (0.036, 0.027, 0.060), (0.175, -0.35, 2.04), root, skin)
    box("Brow", (0.20, 0.040, 0.040), (0.0, -0.455, 2.145), root, skin, 0.012)
    box("MouthShadow", (0.105, 0.018, 0.016), (0.0, -0.475, 1.955), root, hood_inner, 0.006)
    box("VisorFrame", (0.27, 0.052, 0.090), (0.0, -0.445, 2.085), root, metal, 0.022)
    box("Visor", (0.21, 0.024, 0.044), (0.0, -0.478, 2.085), root, glass, 0.012)
    box("VisorGlow", (0.15, 0.012, 0.014), (0.0, -0.495, 2.085), root, cyan, 0.005)
    cylinder("Neck", 0.11, 0.16, (0.0, 0.0, 1.83), root, skin, 16, 0.015)

    left_shoulder = uv_sphere("LeftShoulder", (0.19, 0.16, 0.12), (-0.37, -0.01, 1.66), root, coat)
    right_shoulder = uv_sphere("RightShoulder", (0.19, 0.16, 0.12), (0.37, -0.01, 1.66), root, coat)
    left_pad = cloth_panel("LeftShoulderPad", [(-0.14, 0.05), (0.14, 0.07), (0.10, -0.08), (-0.12, -0.10)], 0.11, (-0.39, -0.08, 1.70), root, leather, 0.020)
    left_pad.rotation_euler.y = -0.16
    right_pad = cloth_panel("RightShoulderPad", [(-0.14, 0.07), (0.14, 0.05), (0.12, -0.10), (-0.10, -0.08)], 0.11, (0.39, -0.08, 1.70), root, leather, 0.020)
    right_pad.rotation_euler.y = 0.16

    left_arm = limb_between("LeftArm", (-0.36, 0.0, 1.62), (-0.48, -0.04, 1.30), 0.105, root, coat, 0.88, 0.025)
    right_arm = limb_between("RightArm", (0.36, 0.0, 1.62), (0.48, -0.04, 1.30), 0.105, root, coat, 0.88, 0.025)
    limb_between("LeftForearmGuard", (-0.48, -0.04, 1.30), (-0.47, -0.22, 1.08), 0.082, root, metal, 0.88, 0.016)
    limb_between("RightForearmGuard", (0.48, -0.04, 1.30), (0.55, -0.22, 1.08), 0.082, root, metal, 0.88, 0.016)
    left_glove = uv_sphere("LeftGlove", (0.105, 0.095, 0.11), (-0.47, -0.27, 1.01), root, leather)
    right_glove = uv_sphere("RightGlove", (0.105, 0.095, 0.11), (0.57, -0.28, 1.01), root, leather)
    uv_sphere("LeftGloveThumb", (0.045, 0.040, 0.065), (-0.55, -0.33, 1.03), root, leather)
    uv_sphere("RightGloveThumb", (0.045, 0.040, 0.065), (0.64, -0.33, 1.03), root, leather)

    left_leg = limb_between("LeftLeg", (-0.17, 0.04, 0.98), (-0.20, 0.01, 0.57), 0.12, root, leather, 0.86, 0.024)
    right_leg = limb_between("RightLeg", (0.17, 0.04, 0.98), (0.20, 0.01, 0.57), 0.12, root, leather, 0.86, 0.024)
    limb_between("LeftShin", (-0.20, 0.01, 0.57), (-0.17, -0.01, 0.26), 0.105, root, leather, 0.88, 0.020)
    limb_between("RightShin", (0.20, 0.01, 0.57), (0.17, -0.01, 0.26), 0.105, root, leather, 0.88, 0.020)
    uv_sphere("LeftBoot", (0.15, 0.22, 0.105), (-0.17, -0.07, 0.16), root, leather)
    uv_sphere("RightBoot", (0.15, 0.22, 0.105), (0.17, -0.07, 0.16), root, leather)
    tapered_prism("LeftBootToe", 0.27, 0.23, 0.34, 0.27, 0.13, (-0.17, -0.18, 0.13), root, leather, 0.028)
    tapered_prism("RightBootToe", 0.27, 0.23, 0.34, 0.27, 0.13, (0.17, -0.18, 0.13), root, leather, 0.028)
    box("LeftBootStrap", (0.26, 0.045, 0.040), (-0.17, -0.30, 0.19), root, metal, 0.010)
    box("RightBootStrap", (0.26, 0.045, 0.040), (0.17, -0.30, 0.19), root, metal, 0.010)

    coat_left = cloth_panel("CoatTailLeft", [(-0.19, 0.50), (0.17, 0.47), (0.25, 0.22), (0.28, -0.20), (0.18, -0.52), (-0.22, -0.50), (-0.27, -0.19), (-0.23, 0.16)], 0.23, (-0.24, 0.09, 0.70), root, coat_tail, 0.040)
    coat_left.rotation_euler.y = -0.045
    coat_right = cloth_panel("CoatTailRight", [(-0.17, 0.47), (0.20, 0.50), (0.24, 0.18), (0.19, -0.24), (0.24, -0.50), (-0.16, -0.52), (-0.24, -0.20), (-0.21, 0.22)], 0.23, (0.24, 0.10, 0.70), root, coat_tail, 0.040)
    coat_right.rotation_euler.y = 0.065
    cloth_panel("CoatHemLeft", [(-0.22, 0.03), (0.19, 0.03), (0.20, -0.05), (-0.20, -0.05)], 0.25, (-0.24, 0.05, 0.19), root, leather, 0.012)
    cloth_panel("CoatHemRight", [(-0.20, 0.03), (0.22, 0.03), (0.21, -0.05), (-0.21, -0.05)], 0.25, (0.24, 0.06, 0.19), root, leather, 0.012)
    limb_between("CoatBackSplit", (0.0, 0.23, 1.12), (0.0, 0.23, 0.21), 0.018, root, leather, 0.70, 0.006)
    coat_fold_left = limb_between("CoatFabricFoldLeft", (-0.14, 0.23, 1.10), (-0.18, 0.23, 0.27), 0.016, root, coat_fold, 0.80, 0.006)
    coat_fold_left.rotation_euler.y = -0.08
    coat_fold_right = limb_between("CoatFabricFoldRight", (0.15, 0.23, 1.08), (0.19, 0.23, 0.27), 0.016, root, coat_fold, 0.80, 0.006)
    coat_fold_right.rotation_euler.y = 0.10
    limb_between("CoatTailEdgeLeft", (-0.34, 0.23, 1.04), (-0.42, 0.23, 0.30), 0.013, root, coat_fold, 0.80, 0.006)
    limb_between("CoatTailEdgeRight", (0.34, 0.23, 1.04), (0.42, 0.23, 0.30), 0.013, root, coat_fold, 0.80, 0.006)
    harness_left = limb_between("HarnessLeft", (-0.18, -0.28, 1.70), (0.02, -0.28, 1.12), 0.020, root, leather, 0.80, 0.006)
    harness_right = limb_between("HarnessRight", (0.18, -0.28, 1.70), (-0.02, -0.28, 1.12), 0.020, root, leather, 0.80, 0.006)

    box("UtilityBelt", (0.68, 0.10, 0.12), (0.0, -0.20, 1.06), root, leather, 0.026)
    box("BeltBuckle", (0.12, 0.040, 0.095), (0.0, -0.265, 1.06), root, metal, 0.015)
    for side in (-1.0, 1.0):
        pouch = tapered_prism("BeltPouch" + ("Left" if side < 0 else "Right"), 0.16, 0.12, 0.14, 0.11, 0.18, (side * 0.29, -0.23, 0.98), root, leather, 0.026)
        pouch.rotation_euler.y = side * 0.10
    box("ToolLoop", (0.055, 0.035, 0.22), (-0.38, -0.24, 1.12), root, leather, 0.010)

    pack = tapered_prism("FieldPack", 0.58, 0.45, 0.34, 0.22, 0.72, (-0.25, 0.32, 1.35), root, leather, 0.070)
    pack["socket_type"] = "equipment_mount"
    pack_roll = cylinder("PackTopRoll", 0.105, 0.45, (-0.25, 0.32, 1.75), root, leather, 16, 0.026)
    pack_roll.rotation_euler.y = math.pi * 0.5
    cloth_panel("PackFlap", [(-0.20, 0.13), (0.20, 0.13), (0.16, -0.15), (-0.17, -0.15)], 0.045, (-0.25, 0.50, 1.53), root, leather, 0.022)
    box("PackBackPanel", (0.34, 0.040, 0.38), (-0.25, 0.51, 1.33), root, metal, 0.026)
    box("PackBuckleLeft", (0.055, 0.025, 0.070), (-0.36, 0.545, 1.56), root, metal, 0.010)
    box("PackBuckleRight", (0.055, 0.025, 0.070), (-0.14, 0.545, 1.56), root, metal, 0.010)
    tapered_prism("PackPocketLeft", 0.20, 0.15, 0.15, 0.11, 0.22, (-0.50, 0.45, 1.22), root, leather, 0.040)
    tapered_prism("PackPocketRight", 0.19, 0.14, 0.14, 0.10, 0.20, (0.00, 0.45, 1.22), root, leather, 0.040)
    cylinder("PackSideCanister", 0.075, 0.25, (-0.57, 0.34, 1.36), root, metal, 12, 0.018).rotation_euler.y = math.pi * 0.5
    limb_between("PackStrapLeft", (-0.39, 0.53, 1.61), (-0.28, 0.53, 1.12), 0.018, root, leather, 0.80, 0.006)
    limb_between("PackStrapRight", (-0.12, 0.53, 1.61), (-0.22, 0.53, 1.12), 0.018, root, leather, 0.80, 0.006)
    back_harness = limb_between("BackHarness", (0.10, 0.23, 1.72), (-0.12, 0.23, 1.05), 0.020, root, leather, 0.80, 0.006)
    back_harness.rotation_euler.y = -0.18

    shoulder_lamp = socket("ShoulderLamp", root, (-0.43, -0.19, 1.77))
    shoulder_lamp["socket_type"] = "light_mount"
    tapered_prism("ShoulderLampHousing", 0.19, 0.14, 0.17, 0.11, 0.15, (-0.43, -0.19, 1.77), root, metal, 0.032)
    cylinder("LampRing", 0.072, 0.050, (-0.43, -0.315, 1.77), root, metal, 12, 0.012).rotation_euler.x = math.pi * 0.5
    cylinder("LampCore", 0.044, 0.038, (-0.43, -0.348, 1.77), root, cyan, 12, 0.008).rotation_euler.x = math.pi * 0.5
    box("LampMount", (0.060, 0.22, 0.065), (-0.43, -0.11, 1.68), root, leather, 0.012)
    cylinder("WarmLamp", 0.050, 0.115, (0.31, -0.21, 1.45), root, warm, 10, 0.010).rotation_euler.x = math.pi * 0.5

    pistol = tapered_prism("WeakPistol", 0.19, 0.15, 0.32, 0.23, 0.13, (0.60, -0.31, 1.08), root, gun, 0.028)
    pistol["socket_type"] = "weapon_mount"
    barrel = cylinder("PistolBarrel", 0.042, 0.34, (0.0, -0.28, 0.030), pistol, gun, 12, 0.010)
    barrel.rotation_euler.x = math.pi * 0.5
    grip = tapered_prism("PistolGrip", 0.11, 0.085, 0.13, 0.10, 0.25, (0.0, 0.02, -0.15), pistol, gun, 0.022)
    grip.rotation_euler.x = -0.20
    box("PistolSlide", (0.17, 0.19, 0.055), (0.0, -0.40, 0.07), pistol, gun, 0.014)
    trigger_guard = torus("PistolTriggerGuard", 0.058, 0.012, (0.0, -0.02, -0.02), pistol, gun)
    trigger_guard.rotation_euler.x = math.pi * 0.5
    trigger_guard.scale.x = 0.80
    bpy.context.view_layer.objects.active = trigger_guard
    trigger_guard.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    trigger_guard.select_set(False)
    muzzle = socket("PistolMuzzle", pistol, (0.0, -0.47, 0.030))
    muzzle["socket_type"] = "weapon_muzzle"
    field_tool = limb_between("FieldTool", (-0.42, -0.20, 1.04), (-0.40, -0.20, 1.38), 0.038, root, metal, 0.80, 0.012)
    field_tool.rotation_euler.y = -0.18
    box("FieldToolHead", (0.20, 0.08, 0.075), (-0.43, -0.21, 1.43), root, metal, 0.018).rotation_euler.y = -0.18
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
