"""Build the original high-definition Riverworks pump landmark glTF."""

from __future__ import annotations

import base64
import json
import math
import sys
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, add_beveled_box, add_box, add_cylinder, add_uv_sphere, quat  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "riverworks.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Riverworks wet alloy", "pbrMetallicRoughness": {"baseColorFactor": [0.10, 0.16, 0.18, 1.0], "metallicFactor": 0.76, "roughnessFactor": 0.34}},
        {"name": "Riverworks oxidized iron", "pbrMetallicRoughness": {"baseColorFactor": [0.30, 0.13, 0.075, 1.0], "metallicFactor": 0.38, "roughnessFactor": 0.62}},
        {"name": "Riverworks ceramic", "pbrMetallicRoughness": {"baseColorFactor": [0.24, 0.29, 0.28, 1.0], "metallicFactor": 0.22, "roughnessFactor": 0.48}},
        {"name": "Riverworks cold water", "pbrMetallicRoughness": {"baseColorFactor": [0.025, 0.18, 0.22, 1.0], "metallicFactor": 0.18, "roughnessFactor": 0.24}, "emissiveFactor": [0.02, 0.38, 0.50]},
        {"name": "Riverworks maintenance amber", "pbrMetallicRoughness": {"baseColorFactor": [0.52, 0.24, 0.08, 1.0], "metallicFactor": 0.18, "roughnessFactor": 0.42}, "emissiveFactor": [0.55, 0.16, 0.035]},
        {"name": "Riverworks growth", "pbrMetallicRoughness": {"baseColorFactor": [0.075, 0.25, 0.18, 1.0], "metallicFactor": 0.04, "roughnessFactor": 0.68}, "emissiveFactor": [0.02, 0.26, 0.14]},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    alloy, rust, ceramic, water, amber, growth = range(6)
    mesh_ids = {
        "Housing": mesh("Housing", add_beveled_box(builder, (4.8, 2.8, 3.9), alloy, 0.18)),
        "HousingCap": mesh("HousingCap", add_beveled_box(builder, (5.2, 0.28, 4.3), ceramic, 0.06)),
        "Pump": mesh("Pump", add_uv_sphere(builder, 1.0, alloy, 24, 36)),
        "Pipe": mesh("Pipe", add_cylinder(builder, 0.30, 5.0, rust, 24)),
        "PipeCollar": mesh("PipeCollar", add_cylinder(builder, 0.48, 0.22, ceramic, 24)),
        "Sluice": mesh("Sluice", add_beveled_box(builder, (5.8, 1.8, 0.26), alloy, 0.08)),
        "SluiceRib": mesh("SluiceRib", add_beveled_box(builder, (0.16, 1.55, 0.38), rust, 0.025)),
        "Rotor": mesh("Rotor", add_cylinder(builder, 0.92, 0.18, water, 32)),
        "Valve": mesh("Valve", add_cylinder(builder, 0.44, 0.16, amber, 24)),
        "Signal": mesh("Signal", add_uv_sphere(builder, 0.20, amber, 18, 28)),
        "Growth": mesh("Growth", add_uv_sphere(builder, 0.42, growth, 18, 28)),
        "Cable": mesh("Cable", add_cylinder(builder, 0.07, 3.8, amber, 12)),
        "PumpPanel": mesh("PumpPanel", add_beveled_box(builder, (3.65, 0.12, 2.75), ceramic, 0.03)),
        "PumpBrace": mesh("PumpBrace", add_beveled_box(builder, (0.12, 2.65, 0.12), rust, 0.025)),
        "RotorHub": mesh("RotorHub", add_cylinder(builder, 0.28, 0.24, amber, 20)),
        "ValveHandle": mesh("ValveHandle", add_cylinder(builder, 0.56, 0.08, rust, 20)),
        "SluiceRail": mesh("SluiceRail", add_beveled_box(builder, (6.2, 0.14, 0.16), rust, 0.025)),
        "SluiceLatch": mesh("SluiceLatch", add_beveled_box(builder, (0.24, 0.52, 0.18), amber, 0.025)),
        "SignalHousing": mesh("SignalHousing", add_cylinder(builder, 0.14, 0.16, ceramic, 16)),
        "CableClamp": mesh("CableClamp", add_beveled_box(builder, (0.24, 0.14, 0.24), amber, 0.03)),
        "GrowthTendril": mesh("GrowthTendril", add_cylinder(builder, 0.045, 0.78, growth, 14)),
    }
    nodes: list[dict] = [{
        "name": "RiverworksModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "riverworks.landmark.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "pump_housings, sluice_gate, impeller, maintenance_valve, water_signal, growth_markers",
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

    pump_core = add_node("RiverworksPumpCore", extras={"surface": "sealed_pump_housing"})
    add_node("RiverworksPumpHousing", mesh_ids["Housing"], (0.0, 1.55, 0.0), scale=(1.0, 1.0, 0.94), parent=pump_core, extras={"release_material_family": "metal"})
    add_node("RiverworksPumpHousingCap", mesh_ids["HousingCap"], (0.0, 3.02, 0.0), parent=pump_core)
    add_node("RiverworksPump", mesh_ids["Pump"], (0.0, 1.65, -1.98), scale=(1.18, 0.82, 0.68), parent=pump_core, extras={"socket_type": "pump_core"})
    add_node("RiverworksPumpPanel", mesh_ids["PumpPanel"], (0.0, 1.55, -2.05), parent=pump_core, extras={"surface": "pump_service_panel"})
    add_node("RiverworksPumpBraceL", mesh_ids["PumpBrace"], (-2.10, 1.55, -2.02), parent=pump_core, extras={"surface": "pump_brace"})
    add_node("RiverworksPumpBraceR", mesh_ids["PumpBrace"], (2.10, 1.55, -2.02), parent=pump_core, extras={"surface": "pump_brace"})
    for index, x in enumerate((-1.65, 0.0, 1.65)):
        add_node("RiverworksPipe%d" % index, mesh_ids["Pipe"], (x, 3.9, 0.55), rotation=(math.pi * 0.5, 0.0, 0.0), parent=pump_core, extras={"socket_type": "service_pipe"})
        add_node("RiverworksPipeCollar%d" % index, mesh_ids["PipeCollar"], (x, 3.9, 0.55), rotation=(math.pi * 0.5, 0.0, 0.0), parent=pump_core)
    add_node("RiverworksRotor", mesh_ids["Rotor"], (0.0, 1.68, -2.67), rotation=(math.pi * 0.5, 0.0, 0.0), parent=pump_core, extras={"socket_type": "water_impeller"})
    add_node("RiverworksRotorHub", mesh_ids["RotorHub"], (0.0, 1.68, -2.67), rotation=(math.pi * 0.5, 0.0, 0.0), parent=pump_core, extras={"surface": "impeller_hub"})
    add_node("RiverworksMaintenanceValve", mesh_ids["Valve"], (2.65, 2.15, -0.65), rotation=(0.0, math.pi * 0.5, 0.0), parent=pump_core, extras={"socket_type": "maintenance_valve"})
    add_node("RiverworksValveHandle", mesh_ids["ValveHandle"], (2.65, 2.15, -0.65), rotation=(0.0, math.pi * 0.5, 0.0), parent=pump_core, extras={"surface": "maintenance_handle"})

    sluice = add_node("RiverworksSluiceGate", mesh_ids["Sluice"], (0.0, 1.0, 5.8), extras={"socket_type": "sluice_gate"})
    for index, x in enumerate((-2.0, 0.0, 2.0)):
        # Sluice ribs inherit the gate's position. These offsets must remain
        # local or the ribs drift away from the gate in the world.
        add_node("RiverworksSluiceRib%d" % index, mesh_ids["SluiceRib"], (x, 0.0, -0.17), parent=sluice)
    add_node("RiverworksSluiceRail", mesh_ids["SluiceRail"], (0.0, 0.92, -0.17), parent=sluice, extras={"surface": "sluice_top_rail"})
    add_node("RiverworksSluiceLatch", mesh_ids["SluiceLatch"], (0.0, 0.18, -0.38), parent=sluice, extras={"surface": "sluice_latch"})
    add_node("RiverworksSluiceSignalHousing", mesh_ids["SignalHousing"], (0.0, 4.32, 5.8), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "flow_signal_housing"})
    add_node("RiverworksSluiceSignal", mesh_ids["Signal"], (0.0, 4.32, 5.8), extras={"socket_type": "flow_signal"})
    for index, (x, z) in enumerate(((-5.5, 6.6), (5.5, 6.6), (-5.5, -2.8), (5.5, -2.8))):
        add_node("RiverworksGrowth%d" % index, mesh_ids["Growth"], (x, 0.45, z), scale=(1.0, 0.7, 1.15), extras={"socket_type": "ecology_growth"})
        for tendril_index, tendril_x in enumerate((-0.20, 0.15)):
            add_node("RiverworksGrowthTendril%d_%d" % (index, tendril_index), mesh_ids["GrowthTendril"], (x + tendril_x, 0.80, z), rotation=(0.0, 0.0, -0.22 + float(tendril_index) * 0.38), extras={"surface": "organic_tendril"})
    add_node("RiverworksCable", mesh_ids["Cable"], (3.5, 2.2, -0.25), rotation=(0.0, 0.0, math.pi * 0.5), scale=(1.0, 1.0, 1.15), extras={"socket_type": "maintenance_cable"})
    add_node("RiverworksCableClamp", mesh_ids["CableClamp"], (3.5, 2.2, 1.70), rotation=(0.0, math.pi * 0.5, 0.0), extras={"surface": "maintenance_cable_clamp"})
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "riverworks.landmark.v1", "source": "original_shared_mesh_builder"})

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Riverworks asset builder"},
        "scene": 0,
        "scenes": [{"name": "Riverworks", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {
            "ironwright_asset_id": "riverworks.landmark.v1",
            "required_nodes": ["RiverworksModel", "RiverworksPumpCore", "RiverworksPumpHousing", "RiverworksPumpPanel", "RiverworksRotor", "RiverworksRotorHub", "RiverworksMaintenanceValve", "RiverworksValveHandle", "RiverworksSluiceGate", "RiverworksSluiceRail", "RiverworksSluiceLatch", "RiverworksSluiceSignalHousing", "RiverworksSluiceSignal", "RiverworksCableClamp", "RiverworksGrowth0", "RiverworksGrowthTendril0_0", "ProductionAssetMarker"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
