"""Build the original high-definition West Grid industrial landmark glTF."""

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


OUTPUT_PATH = SOURCE_DIR / "west_grid.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "West Grid concrete", "pbrMetallicRoughness": {"baseColorFactor": [0.13, 0.17, 0.18, 1.0], "metallicFactor": 0.08, "roughnessFactor": 0.88}},
        {"name": "West Grid steel", "pbrMetallicRoughness": {"baseColorFactor": [0.14, 0.22, 0.24, 1.0], "metallicFactor": 0.72, "roughnessFactor": 0.48}},
        {"name": "West Grid painted iron", "pbrMetallicRoughness": {"baseColorFactor": [0.22, 0.32, 0.33, 1.0], "metallicFactor": 0.56, "roughnessFactor": 0.5}},
        {"name": "West Grid rust", "pbrMetallicRoughness": {"baseColorFactor": [0.46, 0.17, 0.055, 1.0], "metallicFactor": 0.36, "roughnessFactor": 0.7}, "emissiveFactor": [0.08, 0.012, 0.002]},
        {"name": "West Grid signal", "pbrMetallicRoughness": {"baseColorFactor": [0.04, 0.34, 0.36, 1.0], "metallicFactor": 0.2, "roughnessFactor": 0.3}, "emissiveFactor": [0.18, 0.85, 0.88]},
        {"name": "West Grid amber", "pbrMetallicRoughness": {"baseColorFactor": [0.63, 0.28, 0.06, 1.0], "metallicFactor": 0.22, "roughnessFactor": 0.5}, "emissiveFactor": [0.26, 0.045, 0.004]},
        {"name": "West Grid organic", "pbrMetallicRoughness": {"baseColorFactor": [0.16, 0.025, 0.11, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.84}, "emissiveFactor": [0.24, 0.01, 0.08]},
        {"name": "West Grid ceramic", "pbrMetallicRoughness": {"baseColorFactor": [0.32, 0.36, 0.35, 1.0], "metallicFactor": 0.18, "roughnessFactor": 0.62}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    concrete, steel, painted_iron, rust, signal, amber, organic, ceramic = range(8)
    mesh_ids = {
        "Floor": mesh("WestGridFloor", add_box(builder, (26.0, 0.16, 22.0), concrete)),
        "Hall": mesh("WestGridTurbineHall", add_box(builder, (11.5, 6.6, 5.0), steel)),
        "Roof": mesh("WestGridRoof", add_box(builder, (12.3, 0.32, 5.5), painted_iron)),
        "Window": mesh("WestGridWindow", add_box(builder, (1.65, 1.25, 0.08), signal)),
        "Tank": mesh("WestGridPressureTank", add_cylinder(builder, 1.15, 3.8, ceramic, 20)),
        "TankBand": mesh("WestGridTankBand", add_cylinder(builder, 1.22, 0.12, rust, 20)),
        "Transformer": mesh("WestGridTransformer", add_box(builder, (2.4, 1.7, 2.0), painted_iron)),
        "Fin": mesh("WestGridTransformerFin", add_box(builder, (0.12, 1.2, 1.7), ceramic)),
        "Pipe": mesh("WestGridPipe", add_cylinder(builder, 0.085, 5.6, rust, 12)),
        "Rail": mesh("WestGridRail", add_cylinder(builder, 0.065, 4.0, painted_iron, 12)),
        "Signal": mesh("WestGridSignalLight", add_uv_sphere(builder, 0.16, signal, 10, 16)),
        "Amber": mesh("WestGridWarningLight", add_uv_sphere(builder, 0.18, amber, 10, 16)),
        "Organic": mesh("WestGridOrganicCreep", add_uv_sphere(builder, 0.58, organic, 14, 20)),
        "Marker": mesh("WestGridMarker", add_box(builder, (0.7, 0.08, 0.7), rust)),
    }

    nodes: list[dict] = [{
        "name": "WestGridModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "west.grid.substation.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "turbine_hall, pressure_tanks, transformers, pipe_bridge, signal_lights, organic_creep",
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

    add_node("WestGridFloor", mesh_ids["Floor"], (0.0, 0.08, 0.0), extras={"socket_type": "industrial_floor"})
    hall = add_node("WestGridTurbineHall", mesh_ids["Hall"], (-4.8, 3.3, -2.8), extras={"socket_type": "turbine_hall"})
    add_node("WestGridRoofCap", mesh_ids["Roof"], (0.0, 3.4, 0.0), parent=hall)
    for index, x in enumerate((-8.2, -5.0, -1.8)):
        add_node("WestGridWindow%d" % index, mesh_ids["Window"], (x, 3.55, -5.34), extras={"socket_type": "hall_window"})
    for index, (x, z) in enumerate(((5.3, -5.2), (9.0, -5.0), (7.2, 3.9))):
        add_node("WestGridPressureTank%d" % index, mesh_ids["Tank"], (x, 2.15, z), extras={"socket_type": "pressure_tank"})
        add_node("WestGridPressureTankBand%d" % index, mesh_ids["TankBand"], (x, 2.15, z), parent=0)
        add_node("WestGridTankSignal%d" % index, mesh_ids["Signal"], (x, 4.18, z), extras={"socket_type": "tank_signal"})
    for index, (x, z) in enumerate(((2.2, -1.5), (6.4, -1.5))):
        transformer = add_node("WestGridTransformer%d" % index, mesh_ids["Transformer"], (x, 0.98, z), extras={"socket_type": "transformer"})
        for fin_index in range(4):
            add_node("WestGridTransformerFin%d_%d" % (index, fin_index), mesh_ids["Fin"], (-0.82 + float(fin_index) * 0.55, 0.02, -1.05), parent=transformer)
    add_node("WestGridPipeBridge", mesh_ids["Rail"], (0.0, 4.1, 2.8), rotation=(0.0, 0.0, math.pi * 0.5), extras={"socket_type": "pipe_bridge"})
    for index, x in enumerate((-5.8, -2.0, 1.8, 5.6)):
        add_node("WestGridPipeSupport%d" % index, mesh_ids["Rail"], (x, 2.0, 2.8))
    for index, x in enumerate((-3.8, 0.0, 3.8)):
        add_node("WestGridServicePipe%d" % index, mesh_ids["Pipe"], (x, 3.7, 2.8), rotation=(0.0, 0.0, math.pi * 0.5), extras={"socket_type": "service_pipe"})
    for index, (x, z) in enumerate(((-9.8, -6.2), (0.0, -6.3), (10.2, 1.0))):
        add_node("WestGridWarningLight%d" % index, mesh_ids["Amber"], (x, 2.15, z), extras={"socket_type": "warning_light"})
    for index, (x, y, z, scale) in enumerate(((-9.0, 0.48, 3.7, (1.2, 0.75, 0.9)), (1.0, 0.55, -5.8, (0.85, 0.65, 1.2)), (9.0, 0.52, 4.8, (1.05, 0.72, 0.86)))):
        add_node("WestGridOrganicCreep%d" % index, mesh_ids["Organic"], (x, y, z), scale=scale, extras={"socket_type": "organic_creep"})
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "west.grid.substation.v1", "source": "original_procedural_mesh_builder"})

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original West Grid asset builder"},
        "scene": 0,
        "scenes": [{"name": "WestGrid", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {
            "ironwright_asset_id": "west.grid.substation.v1",
            "required_nodes": ["WestGridModel", "WestGridTurbineHall", "WestGridPressureTank0", "WestGridTransformer0", "WestGridPipeBridge", "WestGridWarningLight0", "WestGridOrganicCreep0", "ProductionAssetMarker"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
