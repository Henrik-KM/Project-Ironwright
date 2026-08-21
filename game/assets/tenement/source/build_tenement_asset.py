"""Build the original high-definition East Tenements landmark glTF."""

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


OUTPUT_PATH = SOURCE_DIR / "tenement.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Tenement brick", "pbrMetallicRoughness": {"baseColorFactor": [0.18, 0.075, 0.065, 1.0], "metallicFactor": 0.03, "roughnessFactor": 0.92}},
        {"name": "Tenement concrete", "pbrMetallicRoughness": {"baseColorFactor": [0.19, 0.21, 0.21, 1.0], "metallicFactor": 0.05, "roughnessFactor": 0.88}},
        {"name": "Tenement iron", "pbrMetallicRoughness": {"baseColorFactor": [0.06, 0.09, 0.11, 1.0], "metallicFactor": 0.72, "roughnessFactor": 0.44}},
        {"name": "Tenement rust", "pbrMetallicRoughness": {"baseColorFactor": [0.52, 0.20, 0.07, 1.0], "metallicFactor": 0.38, "roughnessFactor": 0.68}, "emissiveFactor": [0.12, 0.02, 0.005]},
        {"name": "Tenement window", "alphaMode": "BLEND", "doubleSided": True, "pbrMetallicRoughness": {"baseColorFactor": [0.12, 0.25, 0.30, 0.44], "metallicFactor": 0.10, "roughnessFactor": 0.26}, "emissiveFactor": [0.02, 0.10, 0.12]},
        {"name": "Tenement cloth", "pbrMetallicRoughness": {"baseColorFactor": [0.33, 0.10, 0.18, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.92}},
        {"name": "Tenement organic", "pbrMetallicRoughness": {"baseColorFactor": [0.20, 0.035, 0.13, 1.0], "metallicFactor": 0.01, "roughnessFactor": 0.86}, "emissiveFactor": [0.28, 0.01, 0.08]},
        {"name": "Tenement tank", "pbrMetallicRoughness": {"baseColorFactor": [0.17, 0.22, 0.22, 1.0], "metallicFactor": 0.64, "roughnessFactor": 0.52}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    brick, concrete, iron, rust, window, cloth, organic, tank = range(8)
    mesh_ids = {
        "Floor": mesh("TenementFloor", add_box(builder, (18.0, 0.16, 14.0), concrete)),
        "Block": mesh("TenementBlock", add_box(builder, (6.0, 9.0, 4.7), brick)),
        "BlockEdge": mesh("TenementBlockEdge", add_box(builder, (0.28, 9.0, 4.9), concrete)),
        "Window": mesh("TenementWindow", add_box(builder, (1.05, 1.25, 0.08), window)),
        "Balcony": mesh("TenementBalcony", add_box(builder, (3.0, 0.20, 1.35), iron)),
        "Rail": mesh("TenementRail", add_cylinder(builder, 0.07, 3.0, rust, 12)),
        "Ladder": mesh("TenementLadder", add_cylinder(builder, 0.08, 8.8, iron, 12)),
        "Tank": mesh("TenementWaterTank", add_cylinder(builder, 1.15, 2.2, tank, 20)),
        "TankCap": mesh("TenementTankCap", add_cylinder(builder, 1.28, 0.16, rust, 20)),
        "Cloth": mesh("TenementCloth", add_box(builder, (1.35, 1.15, 0.06), cloth)),
        "Creep": mesh("TenementOrganicCreep", add_uv_sphere(builder, 0.52, organic, 14, 20)),
        "Light": mesh("TenementWindowLight", add_uv_sphere(builder, 0.13, rust, 12, 18)),
        "Cable": mesh("TenementCable", add_cylinder(builder, 0.045, 5.2, rust, 10)),
        "Marker": mesh("TenementMarker", add_box(builder, (0.7, 0.08, 0.7), rust)),
    }

    nodes: list[dict] = [{
        "name": "TenementModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "tenement.east_blocks.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "residential_blocks, balconies, fire_escape, roof_tank, windows, cloth, organic_creep",
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

    add_node("TenementFloor", mesh_ids["Floor"], (0.0, 0.08, 0.0), extras={"socket_type": "residential_floor"})
    add_node("TenementBlockL", mesh_ids["Block"], (-5.0, 4.5, 0.0), extras={"socket_type": "residential_block"})
    add_node("TenementBlockR", mesh_ids["Block"], (5.0, 4.5, 2.4), rotation=(0.0, -0.03, 0.0), extras={"socket_type": "residential_block"})
    for index, x in enumerate((-7.0, -3.0, 3.0, 7.0)):
        for level in range(3):
            add_node("TenementWindow%d_%d" % (index, level), mesh_ids["Window"], (x, 1.65 + float(level) * 2.25, -2.42), extras={"socket_type": "residential_window"})
    for index, z in enumerate((-1.0, 2.0, 5.0)):
        balcony = add_node("TenementBalcony%d" % index, mesh_ids["Balcony"], (-0.1, 1.25 + float(index) * 2.25, z), extras={"socket_type": "balcony"})
        for side in (-1.0, 1.0):
            add_node("TenementBalconyRail%d_%s" % (index, "L" if side < 0 else "R"), mesh_ids["Rail"], (side * 1.35, 0.85, 0.0), rotation=(math.pi * 0.5, 0.0, 0.0), parent=balcony)
    escape = add_node("TenementFireEscapeLadder", mesh_ids["Ladder"], (-8.3, 4.4, 3.2), rotation=(0.0, 0.0, 0.0), extras={"socket_type": "fire_escape"})
    add_node("TenementFireEscapeRail", mesh_ids["Rail"], (-8.3, 4.4, 4.7), rotation=(math.pi * 0.5, 0.0, 0.0), parent=escape)
    add_node("TenementRoofWaterTank", mesh_ids["Tank"], (5.8, 10.4, 2.6), extras={"socket_type": "roof_water_tank"})
    add_node("TenementRoofWaterTankCap", mesh_ids["TankCap"], (5.8, 11.55, 2.6), parent=0)
    for index, (x, y, z) in enumerate(((-4.2, 2.35, 3.9), (0.8, 4.55, 6.0), (5.1, 1.4, -2.9))):
        add_node("TenementHangingCloth%d" % index, mesh_ids["Cloth"], (x, y, z), rotation=(0.0, 0.04 * float(index - 1), 0.06 * float(index - 1)), extras={"socket_type": "hanging_cloth"})
    add_node("TenementServiceCable", mesh_ids["Cable"], (7.4, 7.0, 2.8), rotation=(0.0, 0.0, math.pi * 0.5), extras={"socket_type": "service_cable"})
    add_node("TenementWindowLight", mesh_ids["Light"], (-3.0, 5.25, -2.50), extras={"socket_type": "window_light"})
    for index, (x, z, scale) in enumerate(((-7.2, 5.2, (1.1, 0.8, 1.0)), (6.8, -3.9, (0.82, 0.65, 1.25)))):
        add_node("TenementOrganicCreep%d" % index, mesh_ids["Creep"], (x, 0.50, z), scale=scale, extras={"socket_type": "organic_creep"})
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "tenement.east_blocks.v1", "source": "original_procedural_mesh_builder"})

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original East Tenements asset builder"},
        "scene": 0,
        "scenes": [{"name": "Tenement", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {
            "ironwright_asset_id": "tenement.east_blocks.v1",
            "required_nodes": ["TenementModel", "TenementBlockL", "TenementBalcony0", "TenementFireEscapeLadder", "TenementRoofWaterTank", "TenementOrganicCreep0", "ProductionAssetMarker"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
