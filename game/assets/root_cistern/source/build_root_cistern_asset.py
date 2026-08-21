"""Build the original high-definition Root Cistern landmark glTF."""

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


OUTPUT_PATH = SOURCE_DIR / "root_cistern.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Cistern wet root", "pbrMetallicRoughness": {"baseColorFactor": [0.14, 0.035, 0.08, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.4}, "emissiveFactor": [0.12, 0.005, 0.04]},
        {"name": "Cistern layered bark", "pbrMetallicRoughness": {"baseColorFactor": [0.27, 0.07, 0.13, 1.0], "metallicFactor": 0.04, "roughnessFactor": 0.52}, "emissiveFactor": [0.08, 0.005, 0.03]},
        {"name": "Cistern bone", "pbrMetallicRoughness": {"baseColorFactor": [0.52, 0.34, 0.28, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.62}},
        {"name": "Cistern buried alloy", "pbrMetallicRoughness": {"baseColorFactor": [0.15, 0.25, 0.27, 1.0], "metallicFactor": 0.62, "roughnessFactor": 0.42}},
        {"name": "Cistern cold signal", "pbrMetallicRoughness": {"baseColorFactor": [0.03, 0.20, 0.24, 1.0], "metallicFactor": 0.18, "roughnessFactor": 0.26}, "emissiveFactor": [0.08, 0.85, 0.95]},
        {"name": "Cistern root pulse", "pbrMetallicRoughness": {"baseColorFactor": [0.28, 0.025, 0.10, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.44}, "emissiveFactor": [0.38, 0.015, 0.08]},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    root, bark, bone, alloy, signal, pulse = range(6)
    mesh_ids = {
        "Core": mesh("Core", add_uv_sphere(builder, 0.8, root, 20, 28)),
        "Layer": mesh("Layer", add_uv_sphere(builder, 0.55, bark, 16, 24)),
        "Rib": mesh("Rib", add_box(builder, (0.48, 0.24, 2.2), bone)),
        "Pylon": mesh("Pylon", add_cylinder(builder, 0.28, 4.8, alloy, 16)),
        "Signal": mesh("Signal", add_cylinder(builder, 0.11, 2.7, signal, 12)),
        "Pulse": mesh("Pulse", add_uv_sphere(builder, 0.18, pulse, 12, 18)),
        "Cable": mesh("Cable", add_cylinder(builder, 0.055, 4.0, pulse, 10)),
        "Basin": mesh("Basin", add_cylinder(builder, 5.8, 0.22, alloy, 32)),
        "BasinWater": mesh("BasinWater", add_cylinder(builder, 4.9, 0.06, root, 32)),
        "BasinRim": mesh("BasinRim", add_box(builder, (2.45, 0.18, 0.24), bone)),
        "CoreHalo": mesh("CoreHalo", add_uv_sphere(builder, 0.34, pulse, 14, 22)),
        "CoreSpine": mesh("CoreSpine", add_cylinder(builder, 0.14, 4.2, signal, 16)),
    }
    nodes: list[dict] = [{
        "name": "RootCisternModel",
        "children": [],
        "extras": {"ironwright_asset_id": "root_cistern.landmark.v1", "asset_quality": "authored_high_definition", "socket_contract": "root_core, crown_ribs, signal_pylons, root_cables"},
    }]

    def add_node(name: str, mesh_id: int | None = None, translation: Sequence[float] = (0.0, 0.0, 0.0), rotation: Sequence[float] = (0.0, 0.0, 0.0), scale: Sequence[float] | None = None, extras: dict | None = None, parent: int = 0) -> int:
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

    add_node("RootCisternBasin", mesh_ids["Basin"], (0.0, 0.11, 0.0), extras={"socket_type": "basin_floor"})
    add_node("RootCisternBasinWater", mesh_ids["BasinWater"], (0.0, 0.27, 0.0), extras={"socket_type": "basin_water"})
    for index in range(8):
        angle = 6.283185307179586 * index / 8.0
        add_node("RootCisternBasinRim%d" % index, mesh_ids["BasinRim"], (math.cos(angle) * 5.2, 0.38, math.sin(angle) * 5.2), rotation=(0.0, angle, 0.0), extras={"socket_type": "basin_rim"})
    core = add_node("RootCisternCore", extras={"surface": "layered_root_organ"})
    add_node("RootCisternCoreMass", mesh_ids["Core"], (0.0, 1.45, 0.0), scale=(3.25, 1.55, 3.25), parent=core, extras={"release_material_family": "organic"})
    add_node("RootCisternCoreHalo", mesh_ids["CoreHalo"], (0.0, 3.0, 0.0), scale=(2.7, 0.86, 2.7), parent=core, extras={"socket_type": "core_halo"})
    add_node("RootCisternCoreSpine", mesh_ids["CoreSpine"], (0.0, 2.7, 0.0), parent=core, extras={"socket_type": "core_spine"})
    for index in range(6):
        angle = 6.283185307179586 * index / 6.0
        x, z = math.cos(angle) * 2.0, math.sin(angle) * 2.0
        add_node("RootCisternLayer%d" % index, mesh_ids["Layer"], (x * 1.15, 1.5, z * 1.15), rotation=(0.0, -angle, 0.0), scale=(1.5, 0.95, 2.2), parent=core)
        add_node("RootCisternRib%d" % index, mesh_ids["Rib"], (x * 1.5, 2.1, z * 1.5), rotation=(0.32, -angle, 0.0), scale=(1.0, 1.0, 1.25), parent=core)
    for index in range(6):
        angle = 6.283185307179586 * index / 6.0 + 0.22
        x, z = math.cos(angle) * 8.2, math.sin(angle) * 8.2
        pylon = add_node("RootCisternPylon%d" % index, mesh_ids["Pylon"], (x, 2.4, z), rotation=(0.0, -angle, 0.0), parent=0, extras={"socket_type": "signal_pylon"})
        add_node("RootCisternSignal%d" % index, mesh_ids["Signal"], (0.0, 3.15, 0.0), rotation=(0.0, -angle, 0.0), parent=pylon)
        add_node("RootCisternPulse%d" % index, mesh_ids["Pulse"], (0.0, 4.55, 0.0), parent=pylon)
        add_node("RootCisternCable%d" % index, mesh_ids["Cable"], (x * 0.52, 2.4, z * 0.52), rotation=(0.0, -angle, 0.38), scale=(1.0, 1.0, 1.0), parent=0)
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "root_cistern.landmark.v1", "source": "original_shared_mesh_builder"})
    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Root Cistern asset builder"},
        "scene": 0,
        "scenes": [{"name": "RootCistern", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {"ironwright_asset_id": "root_cistern.landmark.v1", "required_nodes": ["RootCisternModel", "RootCisternBasin", "RootCisternBasinWater", "RootCisternCore", "RootCisternCoreMass", "RootCisternCoreHalo", "RootCisternLayer0", "RootCisternRib0", "RootCisternPylon0", "RootCisternSignal0", "RootCisternCable0", "ProductionAssetMarker"]},
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
