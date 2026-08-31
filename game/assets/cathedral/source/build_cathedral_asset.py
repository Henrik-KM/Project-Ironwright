"""Build the original high-definition Cathedral Quarter landmark glTF."""

from __future__ import annotations

import base64
import json
import math
import sys
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, _geometry, add_beveled_box, add_box, add_cylinder, add_ellipsoid, add_uv_sphere, quat  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "cathedral.gltf"


def add_torus(
    builder: BufferBuilder,
    major_radius: float,
    minor_radius: float,
    material: int,
    major_segments: int = 48,
    minor_segments: int = 8,
) -> tuple[int, int, int, int, int, int]:
    """Build a dense circular iron rim for the front rose-window silhouette."""
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []
    for major in range(major_segments):
        major_angle = math.tau * major / major_segments
        major_cos = math.cos(major_angle)
        major_sin = math.sin(major_angle)
        for minor in range(minor_segments):
            minor_angle = math.tau * minor / minor_segments
            minor_cos = math.cos(minor_angle)
            minor_sin = math.sin(minor_angle)
            ring_radius = major_radius + minor_radius * minor_cos
            positions.extend([ring_radius * major_cos, minor_radius * minor_sin, ring_radius * major_sin])
            normals.extend([minor_cos * major_cos, minor_sin, minor_cos * major_sin])
    for major in range(major_segments):
        next_major = (major + 1) % major_segments
        for minor in range(minor_segments):
            next_minor = (minor + 1) % minor_segments
            a = major * minor_segments + minor
            b = next_major * minor_segments + minor
            c = next_major * minor_segments + next_minor
            d = major * minor_segments + next_minor
            indices.extend([a, b, c, a, c, d])
    return _geometry(builder, positions, normals, indices, material)


def add_gable_prism(
    builder: BufferBuilder,
    half_width: float,
    height: float,
    depth: float,
    material: int,
) -> tuple[int, int, int, int, int, int]:
    """Build a compact triangular nave gable with a closed stone volume."""
    half_width = max(0.001, float(half_width))
    height = max(0.001, float(height))
    half_depth = max(0.001, float(depth) * 0.5)
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []

    def add_face(points: Sequence[Sequence[float]], normal: Sequence[float]) -> None:
        start = len(positions) // 3
        for point in points:
            positions.extend(point)
            normals.extend(normal)
        indices.extend([start, start + 1, start + 2])

    front_left = (-half_width, 0.0, -half_depth)
    front_right = (half_width, 0.0, -half_depth)
    front_peak = (0.0, height, -half_depth)
    back_left = (-half_width, 0.0, half_depth)
    back_right = (half_width, 0.0, half_depth)
    back_peak = (0.0, height, half_depth)
    add_face((front_left, front_peak, front_right), (0.0, 0.0, -1.0))
    add_face((back_left, back_right, back_peak), (0.0, 0.0, 1.0))
    add_face((front_left, back_left, back_peak), (-0.87, 0.0, 0.5))
    add_face((front_left, back_peak, front_peak), (-0.87, 0.0, 0.5))
    add_face((front_right, front_peak, back_peak), (0.87, 0.0, 0.5))
    add_face((front_right, back_peak, back_right), (0.87, 0.0, 0.5))
    add_face((front_left, front_right, back_right), (0.0, -1.0, 0.0))
    add_face((front_left, back_right, back_left), (0.0, -1.0, 0.0))
    return _geometry(builder, positions, normals, indices, material)


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Cathedral weathered stone", "pbrMetallicRoughness": {"baseColorFactor": [0.025, 0.040, 0.050, 1.0], "metallicFactor": 0.08, "roughnessFactor": 0.94}},
        {"name": "Cathedral soot brick", "pbrMetallicRoughness": {"baseColorFactor": [0.050, 0.012, 0.008, 1.0], "metallicFactor": 0.04, "roughnessFactor": 0.94}},
        {"name": "Cathedral oxidized iron", "pbrMetallicRoughness": {"baseColorFactor": [0.16, 0.045, 0.015, 1.0], "metallicFactor": 0.28, "roughnessFactor": 0.76}},
        {"name": "Cathedral cold glass", "pbrMetallicRoughness": {"baseColorFactor": [0.015, 0.09, 0.15, 1.0], "metallicFactor": 0.06, "roughnessFactor": 0.38}, "emissiveFactor": [0.0, 0.10, 0.18]},
        {"name": "Cathedral rose glass", "pbrMetallicRoughness": {"baseColorFactor": [0.18, 0.025, 0.08, 1.0], "metallicFactor": 0.04, "roughnessFactor": 0.42}, "emissiveFactor": [0.16, 0.0, 0.05]},
        {"name": "Cathedral organic membrane", "pbrMetallicRoughness": {"baseColorFactor": [0.055, 0.018, 0.030, 1.0], "metallicFactor": 0.01, "roughnessFactor": 0.96}, "emissiveFactor": [0.015, 0.0, 0.006]},
        {"name": "Cathedral warm votive", "pbrMetallicRoughness": {"baseColorFactor": [0.40, 0.10, 0.015, 1.0], "metallicFactor": 0.06, "roughnessFactor": 0.52}, "emissiveFactor": [0.32, 0.06, 0.006]},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int, int, int]) -> int:
        position, normal, uv, tangent, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal, "TEXCOORD_0": uv, "TANGENT": tangent}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    stone, brick, iron, blue_glass, rose_glass, membrane, warm = range(7)
    mesh_ids = {
        "NaveWall": mesh("NaveWall", add_beveled_box(builder, (12.0, 2.8, 0.50), stone, 0.16)),
        "NaveGable": mesh("NaveGable", add_gable_prism(builder, 5.8, 3.25, 0.62, stone)),
        "NaveSide": mesh("NaveSide", add_beveled_box(builder, (0.55, 2.8, 6.0), stone, 0.14)),
        "NaveCap": mesh("NaveCap", add_beveled_box(builder, (12.6, 0.32, 0.34), iron, 0.12)),
        "Brick": mesh("Brick", add_beveled_box(builder, (2.2, 1.1, 0.22), brick, 0.12)),
        "Tower": mesh("Tower", add_beveled_box(builder, (3.4, 8.4, 3.4), brick, 0.16)),
        "TowerCap": mesh("TowerCap", add_beveled_box(builder, (3.9, 0.38, 3.9), iron, 0.14)),
        "Glass": mesh("Glass", add_cylinder(builder, 1.42, 0.16, blue_glass, 32)),
        "Rose": mesh("Rose", add_ellipsoid(builder, (0.72, 0.10, 0.72), rose_glass, rings=18, sides=36)),
        "Rib": mesh("Rib", add_ellipsoid(builder, (0.11, 1.50, 0.11), iron, rings=18, sides=36)),
        "Buttress": mesh("Buttress", add_beveled_box(builder, (0.72, 3.8, 1.0), stone, 0.16)),
        "Choir": mesh("Choir", add_ellipsoid(builder, (0.72, 0.94, 0.62), membrane, rings=20, sides=40)),
        "Spine": mesh("Spine", add_ellipsoid(builder, (0.14, 1.50, 0.14), membrane, rings=18, sides=36)),
        "Vein": mesh("Vein", add_ellipsoid(builder, (0.075, 1.90, 0.075), membrane, rings=18, sides=36)),
        "Signal": mesh("Signal", add_uv_sphere(builder, 0.14, rose_glass, 18, 26)),
        "Bell": mesh("Bell", add_ellipsoid(builder, (0.42, 0.50, 0.42), iron, rings=18, sides=36)),
        "Lamp": mesh("Lamp", add_uv_sphere(builder, 0.10, warm, 16, 22)),
        "Aisle": mesh("Aisle", add_beveled_box(builder, (0.42, 0.18, 5.0), iron, 0.12)),
        "Cross": mesh("Cross", add_beveled_box(builder, (0.18, 1.8, 0.18), iron, 0.12)),
        "DoorPost": mesh("DoorPost", add_beveled_box(builder, (0.18, 2.45, 0.22), iron, 0.12)),
        "DoorLintel": mesh("DoorLintel", add_beveled_box(builder, (3.5, 0.18, 0.22), iron, 0.12)),
        "TowerSlit": mesh("TowerSlit", add_beveled_box(builder, (0.18, 0.82, 0.12), blue_glass, 0.12)),
        "WindowLatch": mesh("WindowLatch", add_uv_sphere(builder, 0.075, iron, 14, 20)),
        "RoseRim": mesh("RoseWindowRim", add_torus(builder, 1.42, 0.10, iron)),
        "ChoirRib": mesh("ChoirRib", add_ellipsoid(builder, (0.055, 1.20, 0.055), iron, rings=18, sides=36)),
        "ChoirRing": mesh("ChoirRing", add_cylinder(builder, 0.24, 0.08, rose_glass, 24)),
        "BellClapper": mesh("BellClapper", add_ellipsoid(builder, (0.075, 0.36, 0.075), iron, rings=18, sides=36)),
        "ButtressCap": mesh("ButtressCap", add_beveled_box(builder, (0.88, 0.18, 1.08), iron, 0.12)),
        "VeinKnuckle": mesh("VeinKnuckle", add_uv_sphere(builder, 0.11, rose_glass, 14, 20)),
        "RoofDrain": mesh("RoofDrain", add_cylinder(builder, 0.075, 1.1, iron, 18)),
    }

    nodes: list[dict] = [{
        "name": "CathedralModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "cathedral.quarter.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "nave, rose_window, choir_core, choir_signal, bell, organic_veins",
        },
    }]

    def add_node(
        name: str,
        mesh_id: int | None = None,
        translation: Sequence[float] = (0.0, 0.0, 0.0),
        rotation: Sequence[float] = (0.0, 0.0, 0.0),
        scale: Sequence[float] | None = None,
        extras: dict | None = None,
        parent: int = 0,
    ) -> int:
        entry: dict = {"name": name, "translation": list(translation)}
        if mesh_id is not None:
            entry["mesh"] = mesh_id
        if rotation != (0.0, 0.0, 0.0):
            entry["rotation"] = quat(rotation)
        if scale is not None:
            entry["scale"] = list(scale)
        if extras:
            entry["extras"] = extras
        nodes.append(entry)
        nodes[parent].setdefault("children", []).append(len(nodes) - 1)
        return len(nodes) - 1

    add_node("CathedralNave", mesh_ids["NaveWall"], (0.0, 1.45, -1.85), extras={"surface": "weathered_nave_facade"})
    add_node("CathedralNaveGable", mesh_ids["NaveGable"], (0.0, 2.72, -1.84), extras={"surface": "weathered_nave_gable"})
    add_node("CathedralNaveRearWall", mesh_ids["NaveWall"], (0.0, 1.45, 4.15), extras={"surface": "weathered_nave_rear"})
    add_node("CathedralNaveSideL", mesh_ids["NaveSide"], (-5.72, 1.45, 1.15))
    add_node("CathedralNaveSideR", mesh_ids["NaveSide"], (5.72, 1.45, 1.15))
    add_node("CathedralNaveCap", mesh_ids["NaveCap"], (0.0, 3.0, 1.15))
    add_node("CathedralTower", mesh_ids["Tower"], (-4.15, 4.2, -0.75), extras={"surface": "soot_brick_tower"})
    add_node("CathedralTowerCap", mesh_ids["TowerCap"], (-4.15, 8.58, -0.75))
    add_node("CathedralBell", mesh_ids["Bell"], (-4.15, 6.45, -2.48), extras={"socket_type": "bell"})
    add_node("CathedralBellClapper", mesh_ids["BellClapper"], (-4.15, 6.18, -2.48), rotation=(0.0, 0.0, 0.12), extras={"surface": "bell_clapper"})
    add_node("CathedralTowerCross", mesh_ids["Cross"], (-4.15, 9.45, -0.75), rotation=(0.0, 0.0, 0.0))
    for index, height in enumerate((3.45, 4.75, 6.05)):
        add_node("CathedralTowerSlit%d" % index, mesh_ids["TowerSlit"], (-4.15, height, -2.48), extras={"surface": "tower_lancet"})

    add_node("CathedralDoorPostL", mesh_ids["DoorPost"], (-1.72, 1.32, -2.22), extras={"surface": "nave_entry_frame"})
    add_node("CathedralDoorPostR", mesh_ids["DoorPost"], (1.72, 1.32, -2.22), extras={"surface": "nave_entry_frame"})
    add_node("CathedralDoorLintel", mesh_ids["DoorLintel"], (0.0, 2.52, -2.22), extras={"surface": "nave_entry_frame"})

    add_node("CathedralRoseWindow", mesh_ids["Glass"], (0.0, 3.15, -2.08), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"socket_type": "rose_window"})
    add_node("CathedralRoseCore", mesh_ids["Rose"], (0.0, 3.15, -2.20), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("CathedralRoseRim", mesh_ids["RoseRim"], (0.0, 3.15, -2.34), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "rose_window_rim"})
    for index, angle in enumerate((0.0, math.pi * 0.25, math.pi * 0.5, math.pi * 0.75, math.pi, math.pi * 1.25, math.pi * 1.5, math.pi * 1.75)):
        add_node("CathedralRoseRib%d" % index, mesh_ids["Rib"], (math.cos(angle) * 0.78, 3.15 + math.sin(angle) * 0.78, -2.32), rotation=(0.0, 0.0, angle), extras={"socket_type": "rose_frame"})
        add_node("CathedralRoseLatch%d" % index, mesh_ids["WindowLatch"], (math.cos(angle) * 1.02, 3.15 + math.sin(angle) * 1.02, -2.36), extras={"surface": "rose_window_latch"})

    for side in (-1.0, 1.0):
        for index in range(3):
            x = side * (5.35 - float(index) * 0.25)
            add_node("CathedralButtress", mesh_ids["Buttress"], (x, 1.9, -0.4 + float(index) * 2.8), rotation=(0.0, 0.0, side * 0.06))
            add_node("CathedralButtressCap%d_%d" % (0 if side < 0 else 1, index), mesh_ids["ButtressCap"], (x, 3.9, -0.4 + float(index) * 2.8), rotation=(0.0, 0.0, side * 0.06), extras={"surface": "buttress_cap"})
        add_node("CathedralAisle", mesh_ids["Aisle"], (side * 3.2, 0.22, 1.4), rotation=(0.0, 0.0, 0.0))
        add_node("CathedralAisleLamp", mesh_ids["Lamp"], (side * 3.2, 1.05, -1.2))

    for index, x in enumerate((-4.5, -1.5, 1.5, 4.5)):
        add_node("CathedralRoofRib%d" % index, mesh_ids["Rib"], (x, 5.35, 1.2), rotation=(0.0, 0.0, math.pi * 0.5), extras={"socket_type": "roof_rib"})
        add_node("CathedralWindowBlue%d" % index, mesh_ids["Rose"], (x, 2.72, -2.18), rotation=(math.pi * 0.5, 0.0, 0.0))
        add_node("CathedralRoofDrain%d" % index, mesh_ids["RoofDrain"], (x, 4.55, 1.25), rotation=(0.0, 0.0, math.pi * 0.5), extras={"surface": "roof_drain"})

    add_node("CathedralChoirSpine", mesh_ids["Spine"], (0.0, 1.65, 4.45), extras={"socket_type": "choir_spine"})
    add_node("CathedralChoirCore", mesh_ids["Choir"], (0.0, 1.45, 4.45), extras={"socket_type": "choir_core"})
    add_node("CathedralChoirSignal", mesh_ids["Signal"], (0.0, 3.15, 4.45), extras={"socket_type": "choir_signal"})
    add_node("CathedralChoirSignalRing", mesh_ids["ChoirRing"], (0.0, 3.15, 4.45), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "choir_signal_ring"})
    add_node("CathedralChoirRibL", mesh_ids["ChoirRib"], (-0.68, 2.05, 4.45), rotation=(0.0, 0.0, 0.16), extras={"surface": "choir_rib"})
    add_node("CathedralChoirRibR", mesh_ids["ChoirRib"], (0.68, 2.05, 4.45), rotation=(0.0, 0.0, -0.16), extras={"surface": "choir_rib"})
    for index, side in enumerate((-1.0, 1.0)):
        for height in (1.7, 2.8):
            add_node("CathedralOrganicVein%d" % (index * 2 + int(height * 10)), mesh_ids["Vein"], (side * 0.72, height, 4.45), rotation=(0.0, side * 0.36, side * 0.10), extras={"socket_type": "organic_vein"})
            add_node("CathedralOrganicVeinKnuckle%d" % (index * 2 + int(height * 10)), mesh_ids["VeinKnuckle"], (side * 0.72, height + 0.26, 4.34), extras={"surface": "organic_vein_joint"})

    add_node("ProductionAssetMarker", None, extras={"asset_contract": "cathedral.quarter.v1", "source": "original_authored_landmark_builder"})

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Cathedral Quarter asset builder"},
        "scene": 0,
        "scenes": [{"name": "CathedralQuarter", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {
            "ironwright_asset_id": "cathedral.quarter.v1",
            "required_nodes": ["CathedralModel", "CathedralNave", "CathedralRoseWindow", "CathedralRoseRim", "CathedralDoorPostL", "CathedralTowerSlit0", "CathedralRoseLatch0", "CathedralChoirCore", "CathedralChoirSignal", "CathedralChoirSignalRing", "CathedralChoirRibL", "CathedralBell", "CathedralBellClapper", "CathedralOrganicVeinKnuckle17", "ProductionAssetMarker"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
