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
from build_bulwark_asset import BufferBuilder, add_box, add_cylinder, add_uv_sphere, quat  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "cathedral.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Cathedral weathered stone", "pbrMetallicRoughness": {"baseColorFactor": [0.20, 0.23, 0.25, 1.0], "metallicFactor": 0.18, "roughnessFactor": 0.84}},
        {"name": "Cathedral soot brick", "pbrMetallicRoughness": {"baseColorFactor": [0.18, 0.115, 0.10, 1.0], "metallicFactor": 0.12, "roughnessFactor": 0.88}},
        {"name": "Cathedral oxidized iron", "pbrMetallicRoughness": {"baseColorFactor": [0.32, 0.16, 0.10, 1.0], "metallicFactor": 0.46, "roughnessFactor": 0.64}},
        {"name": "Cathedral cold glass", "pbrMetallicRoughness": {"baseColorFactor": [0.08, 0.20, 0.28, 1.0], "metallicFactor": 0.12, "roughnessFactor": 0.22}, "emissiveFactor": [0.06, 0.28, 0.44]},
        {"name": "Cathedral rose glass", "pbrMetallicRoughness": {"baseColorFactor": [0.36, 0.10, 0.20, 1.0], "metallicFactor": 0.08, "roughnessFactor": 0.28}, "emissiveFactor": [0.42, 0.05, 0.18]},
        {"name": "Cathedral organic membrane", "pbrMetallicRoughness": {"baseColorFactor": [0.26, 0.055, 0.10, 1.0], "metallicFactor": 0.02, "roughnessFactor": 0.86}, "emissiveFactor": [0.25, 0.015, 0.06]},
        {"name": "Cathedral warm votive", "pbrMetallicRoughness": {"baseColorFactor": [0.55, 0.23, 0.07, 1.0], "metallicFactor": 0.12, "roughnessFactor": 0.42}, "emissiveFactor": [0.85, 0.18, 0.035]},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    stone, brick, iron, blue_glass, rose_glass, membrane, warm = range(7)
    mesh_ids = {
        "NaveWall": mesh("NaveWall", add_box(builder, (12.0, 2.8, 0.50), stone)),
        "NaveSide": mesh("NaveSide", add_box(builder, (0.55, 2.8, 6.0), stone)),
        "NaveCap": mesh("NaveCap", add_box(builder, (12.6, 0.32, 0.34), iron)),
        "Brick": mesh("Brick", add_box(builder, (2.2, 1.1, 0.22), brick)),
        "Tower": mesh("Tower", add_box(builder, (3.4, 8.4, 3.4), brick)),
        "TowerCap": mesh("TowerCap", add_box(builder, (3.9, 0.38, 3.9), iron)),
        "Glass": mesh("Glass", add_cylinder(builder, 1.42, 0.16, blue_glass, 24)),
        "Rose": mesh("Rose", add_cylinder(builder, 0.72, 0.18, rose_glass, 20)),
        "Rib": mesh("Rib", add_box(builder, (0.14, 3.0, 0.22), iron)),
        "Buttress": mesh("Buttress", add_box(builder, (0.72, 3.8, 1.0), stone)),
        "Choir": mesh("Choir", add_uv_sphere(builder, 0.72, membrane, 16, 24)),
        "Spine": mesh("Spine", add_cylinder(builder, 0.14, 3.0, membrane, 18)),
        "Vein": mesh("Vein", add_cylinder(builder, 0.075, 3.8, membrane, 12)),
        "Signal": mesh("Signal", add_uv_sphere(builder, 0.14, rose_glass, 14, 20)),
        "Bell": mesh("Bell", add_uv_sphere(builder, 0.42, iron, 16, 22)),
        "Lamp": mesh("Lamp", add_uv_sphere(builder, 0.10, warm, 12, 16)),
        "Aisle": mesh("Aisle", add_box(builder, (0.42, 0.18, 5.0), iron)),
        "Cross": mesh("Cross", add_box(builder, (0.18, 1.8, 0.18), iron)),
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
    add_node("CathedralNaveRearWall", mesh_ids["NaveWall"], (0.0, 1.45, 4.15), extras={"surface": "weathered_nave_rear"})
    add_node("CathedralNaveSideL", mesh_ids["NaveSide"], (-5.72, 1.45, 1.15))
    add_node("CathedralNaveSideR", mesh_ids["NaveSide"], (5.72, 1.45, 1.15))
    add_node("CathedralNaveCap", mesh_ids["NaveCap"], (0.0, 3.0, 1.15))
    add_node("CathedralTower", mesh_ids["Tower"], (-4.15, 4.2, -0.75), extras={"surface": "soot_brick_tower"})
    add_node("CathedralTowerCap", mesh_ids["TowerCap"], (-4.15, 8.58, -0.75))
    add_node("CathedralBell", mesh_ids["Bell"], (-4.15, 6.45, -2.48), extras={"socket_type": "bell"})
    add_node("CathedralTowerCross", mesh_ids["Cross"], (-4.15, 9.45, -0.75), rotation=(0.0, 0.0, 0.0))

    add_node("CathedralRoseWindow", mesh_ids["Glass"], (0.0, 3.15, -2.08), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"socket_type": "rose_window"})
    add_node("CathedralRoseCore", mesh_ids["Rose"], (0.0, 3.15, -2.20), rotation=(math.pi * 0.5, 0.0, 0.0))
    for index, angle in enumerate((0.0, math.pi * 0.25, math.pi * 0.5, math.pi * 0.75)):
        add_node("CathedralRoseRib%d" % index, mesh_ids["Rib"], (math.cos(angle) * 0.78, 3.15 + math.sin(angle) * 0.78, -2.32), rotation=(0.0, 0.0, angle), extras={"socket_type": "rose_frame"})

    for side in (-1.0, 1.0):
        for index in range(3):
            x = side * (5.35 - float(index) * 0.25)
            add_node("CathedralButtress", mesh_ids["Buttress"], (x, 1.9, -0.4 + float(index) * 2.8), rotation=(0.0, 0.0, side * 0.06))
        add_node("CathedralAisle", mesh_ids["Aisle"], (side * 3.2, 0.22, 1.4), rotation=(0.0, 0.0, 0.0))
        add_node("CathedralAisleLamp", mesh_ids["Lamp"], (side * 3.2, 1.05, -1.2))

    for index, x in enumerate((-4.5, -1.5, 1.5, 4.5)):
        add_node("CathedralRoofRib%d" % index, mesh_ids["Rib"], (x, 5.35, 1.2), rotation=(0.0, 0.0, math.pi * 0.5), extras={"socket_type": "roof_rib"})
        add_node("CathedralWindowBlue%d" % index, mesh_ids["Rose"], (x, 2.72, -2.18), rotation=(math.pi * 0.5, 0.0, 0.0))

    add_node("CathedralChoirSpine", mesh_ids["Spine"], (0.0, 1.65, 4.45), extras={"socket_type": "choir_spine"})
    add_node("CathedralChoirCore", mesh_ids["Choir"], (0.0, 1.45, 4.45), extras={"socket_type": "choir_core"})
    add_node("CathedralChoirSignal", mesh_ids["Signal"], (0.0, 3.15, 4.45), extras={"socket_type": "choir_signal"})
    for index, side in enumerate((-1.0, 1.0)):
        for height in (1.7, 2.8):
            add_node("CathedralOrganicVein%d" % (index * 2 + int(height * 10)), mesh_ids["Vein"], (side * 0.72, height, 4.45), rotation=(0.0, side * 0.36, side * 0.10), extras={"socket_type": "organic_vein"})

    add_node("ProductionAssetMarker", None, extras={"asset_contract": "cathedral.quarter.v1", "source": "original_procedural_mesh_builder"})

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
            "required_nodes": ["CathedralModel", "CathedralNave", "CathedralRoseWindow", "CathedralChoirCore", "CathedralChoirSignal", "CathedralBell", "ProductionAssetMarker"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
