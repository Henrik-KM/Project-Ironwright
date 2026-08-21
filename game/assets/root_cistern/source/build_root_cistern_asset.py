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
        "Core": mesh("Core", add_uv_sphere(builder, 0.8, root, 24, 36)),
        "Layer": mesh("Layer", add_uv_sphere(builder, 0.55, bark, 20, 28)),
        "Rib": mesh("Rib", add_box(builder, (0.48, 0.24, 2.2), bone)),
        "Pylon": mesh("Pylon", add_cylinder(builder, 0.28, 4.8, alloy, 20)),
        "PylonCollar": mesh("PylonCollar", add_cylinder(builder, 0.38, 0.18, alloy, 20)),
        "PylonBrace": mesh("PylonBrace", add_box(builder, (0.12, 1.85, 0.12), alloy)),
        "Signal": mesh("Signal", add_cylinder(builder, 0.11, 2.7, signal, 18)),
        "Pulse": mesh("Pulse", add_uv_sphere(builder, 0.18, pulse, 18, 28)),
        "PulseCap": mesh("PulseCap", add_cylinder(builder, 0.18, 0.16, pulse, 18)),
        "Cable": mesh("Cable", add_cylinder(builder, 0.055, 4.0, pulse, 14)),
        "CableClamp": mesh("CableClamp", add_cylinder(builder, 0.10, 0.14, alloy, 16)),
        "Basin": mesh("Basin", add_cylinder(builder, 5.8, 0.22, alloy, 40)),
        "BasinWater": mesh("BasinWater", add_cylinder(builder, 4.9, 0.06, root, 40)),
        "BasinRim": mesh("BasinRim", add_box(builder, (2.45, 0.18, 0.24), bone)),
        "BasinSpine": mesh("BasinSpine", add_box(builder, (0.12, 0.16, 2.4), bone)),
        "BasinRootTendril": mesh("BasinRootTendril", add_cylinder(builder, 0.055, 0.90, root, 14)),
        "CorePlate": mesh("CorePlate", add_box(builder, (1.55, 0.16, 0.16), bark)),
        "CoreClaw": mesh("CoreClaw", add_cylinder(builder, 0.11, 1.5, bone, 16)),
        "CoreVein": mesh("CoreVein", add_cylinder(builder, 0.06, 1.8, pulse, 14)),
        "CoreHalo": mesh("CoreHalo", add_uv_sphere(builder, 0.34, pulse, 18, 28)),
        "CoreSpine": mesh("CoreSpine", add_cylinder(builder, 0.14, 4.2, signal, 20)),
        "BasinInlay": mesh("BasinInlay", add_box(builder, (0.10, 0.08, 3.4), signal)),
        "BasinSocket": mesh("BasinSocket", add_uv_sphere(builder, 0.12, pulse, 14, 20)),
        "CoreCrownPlate": mesh("CoreCrownPlate", add_box(builder, (0.16, 0.18, 0.72), bone)),
        "CoreCrownSocket": mesh("CoreCrownSocket", add_uv_sphere(builder, 0.105, signal, 14, 20)),
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
        rim = add_node("RootCisternBasinRim%d" % index, mesh_ids["BasinRim"], (math.cos(angle) * 5.2, 0.38, math.sin(angle) * 5.2), rotation=(0.0, angle, 0.0), extras={"socket_type": "basin_rim"})
        add_node("RootCisternBasinSpine%d" % index, mesh_ids["BasinSpine"], (0.0, 0.10, 1.25), rotation=(0.0, 0.0, 0.16), parent=rim)
        add_node("RootCisternBasinRootTendril%d" % index, mesh_ids["BasinRootTendril"], (0.72, 0.16, -0.22), rotation=(0.0, 0.0, -0.28), parent=rim)
    for index in range(12):
        angle = 6.283185307179586 * index / 12.0 + 0.13
        x, z = math.cos(angle) * 3.82, math.sin(angle) * 3.82
        add_node("RootCisternBasinInlay%02d" % index, mesh_ids["BasinInlay"], (x, 0.38, z), rotation=(0.0, -angle, 0.0), scale=(1.0, 1.0, 0.92), extras={"socket_type": "basin_signal_inlay"})
        add_node("RootCisternBasinSocket%02d" % index, mesh_ids["BasinSocket"], (x * 1.02, 0.50, z * 1.02), extras={"socket_type": "basin_signal_socket"})
    core = add_node("RootCisternCore", extras={"surface": "layered_root_organ"})
    add_node("RootCisternCoreMass", mesh_ids["Core"], (0.0, 1.45, 0.0), scale=(3.25, 1.55, 3.25), parent=core, extras={"release_material_family": "organic"})
    add_node("RootCisternCoreHalo", mesh_ids["CoreHalo"], (0.0, 3.0, 0.0), scale=(2.7, 0.86, 2.7), parent=core, extras={"socket_type": "core_halo"})
    add_node("RootCisternCoreSpine", mesh_ids["CoreSpine"], (0.0, 2.7, 0.0), parent=core, extras={"socket_type": "core_spine"})
    for index in range(6):
        angle = 6.283185307179586 * index / 6.0
        x, z = math.cos(angle) * 2.65, math.sin(angle) * 2.65
        add_node("RootCisternCorePlate%d" % index, mesh_ids["CorePlate"], (x, 1.88, z), rotation=(0.0, -angle, 0.0), parent=core, extras={"socket_type": "core_surface_plate"})
        add_node("RootCisternCoreClaw%d" % index, mesh_ids["CoreClaw"], (x * 0.88, 2.62, z * 0.88), rotation=(0.0, -angle, 0.48), parent=core, extras={"socket_type": "core_claw"})
        add_node("RootCisternCoreVein%d" % index, mesh_ids["CoreVein"], (x * 0.72, 2.22, z * 0.72), rotation=(0.0, -angle, 0.22), parent=core, extras={"socket_type": "core_vein"})
    for index in range(6):
        angle = 6.283185307179586 * index / 6.0
        x, z = math.cos(angle) * 2.0, math.sin(angle) * 2.0
        add_node("RootCisternLayer%d" % index, mesh_ids["Layer"], (x * 1.15, 1.5, z * 1.15), rotation=(0.0, -angle, 0.0), scale=(1.5, 0.95, 2.2), parent=core)
        add_node("RootCisternRib%d" % index, mesh_ids["Rib"], (x * 1.5, 2.1, z * 1.5), rotation=(0.32, -angle, 0.0), scale=(1.0, 1.0, 1.25), parent=core)
    for index in range(8):
        angle = 6.283185307179586 * index / 8.0 + 0.18
        x, z = math.cos(angle) * 1.92, math.sin(angle) * 1.92
        add_node("RootCisternCoreCrownPlate%02d" % index, mesh_ids["CoreCrownPlate"], (x, 3.08, z), rotation=(0.18, -angle, 0.0), extras={"socket_type": "core_crown_plate"}, parent=core)
        add_node("RootCisternCoreCrownSocket%02d" % index, mesh_ids["CoreCrownSocket"], (x * 0.92, 3.24, z * 0.92), extras={"socket_type": "core_crown_socket"}, parent=core)
    for index in range(6):
        angle = 6.283185307179586 * index / 6.0 + 0.22
        x, z = math.cos(angle) * 8.2, math.sin(angle) * 8.2
        pylon = add_node("RootCisternPylon%d" % index, mesh_ids["Pylon"], (x, 2.4, z), rotation=(0.0, -angle, 0.0), parent=0, extras={"socket_type": "signal_pylon"})
        add_node("RootCisternPylonCollar%d" % index, mesh_ids["PylonCollar"], (0.0, 1.1, 0.0), parent=pylon, extras={"socket_type": "pylon_collar"})
        add_node("RootCisternPylonBrace%d" % index, mesh_ids["PylonBrace"], (0.0, 1.75, -0.20), rotation=(0.0, 0.0, 0.16), parent=pylon, extras={"socket_type": "pylon_brace"})
        add_node("RootCisternSignal%d" % index, mesh_ids["Signal"], (0.0, 3.15, 0.0), rotation=(0.0, -angle, 0.0), parent=pylon)
        add_node("RootCisternPulse%d" % index, mesh_ids["Pulse"], (0.0, 4.55, 0.0), parent=pylon)
        add_node("RootCisternPulseCap%d" % index, mesh_ids["PulseCap"], (0.0, 4.78, 0.0), parent=pylon)
        add_node("RootCisternCable%d" % index, mesh_ids["Cable"], (x * 0.52, 2.4, z * 0.52), rotation=(0.0, -angle, 0.38), scale=(1.0, 1.0, 1.0), parent=0)
        add_node("RootCisternCableClamp%d" % index, mesh_ids["CableClamp"], (x * 0.38, 2.4, z * 0.38), rotation=(0.0, -angle, 0.0), parent=0, extras={"socket_type": "cable_clamp"})
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
        "extras": {"ironwright_asset_id": "root_cistern.landmark.v1", "required_nodes": ["RootCisternModel", "RootCisternBasin", "RootCisternBasinWater", "RootCisternBasinSpine0", "RootCisternBasinRootTendril0", "RootCisternBasinInlay00", "RootCisternBasinSocket00", "RootCisternCore", "RootCisternCoreMass", "RootCisternCoreHalo", "RootCisternCorePlate0", "RootCisternCoreClaw0", "RootCisternCoreVein0", "RootCisternCoreCrownPlate00", "RootCisternCoreCrownSocket00", "RootCisternLayer0", "RootCisternRib0", "RootCisternPylon0", "RootCisternPylonCollar0", "RootCisternPylonBrace0", "RootCisternSignal0", "RootCisternPulseCap0", "RootCisternCable0", "RootCisternCableClamp0", "ProductionAssetMarker"]},
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
