"""Build the original high-definition Tram Graveyard landmark glTF."""

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


OUTPUT_PATH = SOURCE_DIR / "tram_graveyard.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Tram weathered teal", "pbrMetallicRoughness": {"baseColorFactor": [0.13, 0.27, 0.29, 1.0], "metallicFactor": 0.38, "roughnessFactor": 0.68}},
        {"name": "Tram oxidized iron", "pbrMetallicRoughness": {"baseColorFactor": [0.42, 0.19, 0.09, 1.0], "metallicFactor": 0.48, "roughnessFactor": 0.64}},
        {"name": "Tram dark undercarriage", "pbrMetallicRoughness": {"baseColorFactor": [0.045, 0.065, 0.075, 1.0], "metallicFactor": 0.74, "roughnessFactor": 0.42}},
        {"name": "Tram cold window", "pbrMetallicRoughness": {"baseColorFactor": [0.04, 0.20, 0.27, 1.0], "metallicFactor": 0.16, "roughnessFactor": 0.24}, "emissiveFactor": [0.04, 0.30, 0.46]},
        {"name": "Tram service amber", "pbrMetallicRoughness": {"baseColorFactor": [0.62, 0.25, 0.055, 1.0], "metallicFactor": 0.14, "roughnessFactor": 0.38}, "emissiveFactor": [0.95, 0.22, 0.025]},
        {"name": "Tram concrete", "pbrMetallicRoughness": {"baseColorFactor": [0.24, 0.27, 0.27, 1.0], "metallicFactor": 0.10, "roughnessFactor": 0.88}},
        {"name": "Tram organic seepage", "pbrMetallicRoughness": {"baseColorFactor": [0.22, 0.045, 0.10, 1.0], "metallicFactor": 0.02, "roughnessFactor": 0.86}, "emissiveFactor": [0.30, 0.018, 0.08]},
        {"name": "Tram ceramic insulator", "pbrMetallicRoughness": {"baseColorFactor": [0.38, 0.42, 0.40, 1.0], "metallicFactor": 0.16, "roughnessFactor": 0.54}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    tram, rust, dark, window, amber, concrete, organic, ceramic = range(8)
    mesh_ids = {
        "Carriage": mesh("Carriage", add_beveled_box(builder, (8.6, 3.25, 2.45), tram, 0.18)),
        "CarriageRoof": mesh("CarriageRoof", add_beveled_box(builder, (8.95, 0.24, 2.72), rust, 0.07)),
        "Window": mesh("Window", add_beveled_box(builder, (1.35, 0.82, 0.10), window, 0.035)),
        "WindowFrameVertical": mesh("WindowFrameVertical", add_beveled_box(builder, (0.10, 0.96, 0.14), rust, 0.025)),
        "WindowFrameHorizontal": mesh("WindowFrameHorizontal", add_beveled_box(builder, (1.52, 0.10, 0.14), rust, 0.025)),
        "Door": mesh("Door", add_beveled_box(builder, (1.55, 1.92, 0.12), dark, 0.035)),
        "DoorTrim": mesh("DoorTrim", add_beveled_box(builder, (1.70, 0.12, 0.18), rust, 0.03)),
        "DoorHandle": mesh("DoorHandle", add_cylinder(builder, 0.07, 0.42, amber, 16)),
        "BeltRail": mesh("BeltRail", add_beveled_box(builder, (7.65, 0.14, 0.14), rust, 0.03)),
        "LowerPanel": mesh("LowerPanel", add_beveled_box(builder, (1.45, 0.62, 0.10), dark, 0.025)),
        "Undercarriage": mesh("Undercarriage", add_beveled_box(builder, (7.5, 0.52, 1.75), dark, 0.08)),
        "BogiePlate": mesh("BogiePlate", add_beveled_box(builder, (1.35, 0.24, 1.34), dark, 0.055)),
        "Wheel": mesh("Wheel", add_cylinder(builder, 0.62, 0.22, dark, 28)),
        "Rail": mesh("Rail", add_cylinder(builder, 0.11, 15.0, rust, 20)),
        "Sleeper": mesh("Sleeper", add_beveled_box(builder, (4.6, 0.18, 0.34), concrete, 0.04)),
        "RailFastener": mesh("RailFastener", add_cylinder(builder, 0.08, 0.10, rust, 16)),
        "Pit": mesh("Pit", add_beveled_box(builder, (5.4, 0.42, 3.2), dark, 0.08)),
        "PitEdge": mesh("PitEdge", add_beveled_box(builder, (0.32, 0.24, 4.0), concrete, 0.05)),
        "PitRung": mesh("PitRung", add_beveled_box(builder, (0.12, 0.74, 0.12), rust, 0.025)),
        "SignalMast": mesh("SignalMast", add_cylinder(builder, 0.14, 6.2, rust, 16)),
        "Signal": mesh("Signal", add_uv_sphere(builder, 0.22, amber, 18, 28)),
        "SignalHousing": mesh("SignalHousing", add_cylinder(builder, 0.30, 0.22, dark, 20)),
        "SignalVisor": mesh("SignalVisor", add_beveled_box(builder, (0.50, 0.12, 0.32), rust, 0.03)),
        "OverheadBeam": mesh("OverheadBeam", add_beveled_box(builder, (15.0, 0.20, 0.20), dark, 0.04)),
        "Cable": mesh("Cable", add_cylinder(builder, 0.045, 5.0, amber, 10)),
        "CableClamp": mesh("CableClamp", add_cylinder(builder, 0.10, 0.14, amber, 16)),
        "PantographArm": mesh("PantographArm", add_beveled_box(builder, (2.6, 0.10, 0.10), dark, 0.025)),
        "PantographInsulator": mesh("PantographInsulator", add_cylinder(builder, 0.10, 0.22, ceramic, 18)),
        "RoofVent": mesh("RoofVent", add_beveled_box(builder, (0.92, 0.16, 0.42), rust, 0.035)),
        "HeadlampHousing": mesh("HeadlampHousing", add_cylinder(builder, 0.17, 0.20, dark, 22)),
        "HeadlampLens": mesh("HeadlampLens", add_cylinder(builder, 0.11, 0.07, amber, 22)),
        "Seep": mesh("Seep", add_uv_sphere(builder, 0.48, organic, 18, 28)),
        "SeepTendril": mesh("SeepTendril", add_cylinder(builder, 0.055, 0.82, organic, 14)),
        "ServiceLamp": mesh("ServiceLamp", add_uv_sphere(builder, 0.10, amber, 16, 24)),
        "Marker": mesh("Marker", add_beveled_box(builder, (0.7, 0.08, 0.7), amber, 0.025)),
    }

    nodes: list[dict] = [{
        "name": "TramGraveyardModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "tram.graveyard.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "carriages, doors, windows, maintenance_pit, rails, signal_mast, organic_seepage",
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

    def carriage(prefix: str, position: tuple[float, float, float], yaw: float, parent: int = 0) -> int:
        carriage_root = add_node(prefix, extras={"surface": "damaged_tram_carriage"}, translation=position, rotation=(0.0, yaw, 0.0), parent=parent)
        add_node(prefix + "Body", mesh_ids["Carriage"], (0.0, 1.95, 0.0), parent=carriage_root)
        add_node(prefix + "Roof", mesh_ids["CarriageRoof"], (0.0, 3.62, 0.0), parent=carriage_root)
        add_node(prefix + "RoofVent0", mesh_ids["RoofVent"], (-2.4, 3.82, 0.0), parent=carriage_root)
        add_node(prefix + "RoofVent1", mesh_ids["RoofVent"], (2.0, 3.82, 0.0), parent=carriage_root)
        add_node(prefix + "BeltRailFront", mesh_ids["BeltRail"], (0.0, 1.25, 1.40), parent=carriage_root)
        add_node(prefix + "BeltRailRear", mesh_ids["BeltRail"], (0.0, 1.25, -1.40), parent=carriage_root)
        add_node(prefix + "Door", mesh_ids["Door"], (0.0, 1.52, -1.28), extras={"socket_type": "carriage_door"}, parent=carriage_root)
        add_node(prefix + "DoorTrim", mesh_ids["DoorTrim"], (0.0, 2.54, -1.36), parent=carriage_root)
        add_node(prefix + "DoorHandle", mesh_ids["DoorHandle"], (0.0, 1.48, -1.49), extras={"socket_type": "carriage_handle"}, parent=carriage_root)
        add_node(prefix + "FrontDoorHandle", mesh_ids["DoorHandle"], (0.0, 1.48, 1.49), extras={"socket_type": "approach_handle"}, parent=carriage_root)
        for index, x in enumerate((-2.75, -0.92, 0.92, 2.75)):
            add_node(prefix + "Window%d" % index, mesh_ids["Window"], (x, 2.30, -1.27), extras={"socket_type": "carriage_window"}, parent=carriage_root)
            add_node(prefix + "FrontWindow%d" % index, mesh_ids["Window"], (x, 2.30, 1.27), extras={"socket_type": "approach_window"}, parent=carriage_root)
            add_node(prefix + "WindowFrameFront%d" % index, mesh_ids["WindowFrameVertical"], (x - 0.70, 2.30, 1.38), parent=carriage_root)
            add_node(prefix + "WindowFrameRear%d" % index, mesh_ids["WindowFrameVertical"], (x + 0.70, 2.30, 1.38), parent=carriage_root)
            add_node(prefix + "WindowSill%d" % index, mesh_ids["WindowFrameHorizontal"], (x, 1.82, 1.38), parent=carriage_root)
        add_node(prefix + "FrontDoor", mesh_ids["Door"], (0.0, 1.52, 1.28), extras={"socket_type": "approach_door"}, parent=carriage_root)
        add_node(prefix + "FrontDoorTrim", mesh_ids["DoorTrim"], (0.0, 2.54, 1.36), parent=carriage_root)
        add_node(prefix + "FrontHeadlampHousing", mesh_ids["HeadlampHousing"], (0.0, 2.84, 1.48), parent=carriage_root)
        add_node(prefix + "FrontHeadlampLens", mesh_ids["HeadlampLens"], (0.0, 2.84, 1.60), extras={"socket_type": "approach_service_light"}, parent=carriage_root)
        add_node(prefix + "FrontServiceLamp", mesh_ids["ServiceLamp"], (0.0, 3.05, 1.42), extras={"socket_type": "approach_service_light"}, parent=carriage_root)
        add_node(prefix + "LowerPanelFront", mesh_ids["LowerPanel"], (0.0, 0.98, 1.37), parent=carriage_root)
        add_node(prefix + "LowerPanelRear", mesh_ids["LowerPanel"], (0.0, 0.98, -1.37), parent=carriage_root)
        add_node(prefix + "Undercarriage", mesh_ids["Undercarriage"], (0.0, 0.45, 0.0), parent=carriage_root)
        for index, x in enumerate((-2.55, 2.55)):
            add_node(prefix + "BogiePlate%d" % index, mesh_ids["BogiePlate"], (x, 0.70, 0.0), parent=carriage_root)
            add_node(prefix + "Wheel%d" % index, mesh_ids["Wheel"], (x, 0.28, -0.62), rotation=(math.pi * 0.5, 0.0, 0.0), parent=carriage_root)
        pantograph = add_node(prefix + "Pantograph", extras={"socket_type": "roof_power_pickup"}, parent=carriage_root)
        add_node(prefix + "PantographArmL", mesh_ids["PantographArm"], (-0.82, 4.13, 0.0), rotation=(0.0, 0.0, -0.20), parent=pantograph)
        add_node(prefix + "PantographArmR", mesh_ids["PantographArm"], (0.82, 4.13, 0.0), rotation=(0.0, 0.0, 0.20), parent=pantograph)
        add_node(prefix + "PantographInsulatorL", mesh_ids["PantographInsulator"], (-1.0, 3.95, 0.0), parent=pantograph)
        add_node(prefix + "PantographInsulatorR", mesh_ids["PantographInsulator"], (1.0, 3.95, 0.0), parent=pantograph)
        return carriage_root

    carriage("TramCarriageA", (-2.9, 0.0, 2.0), -0.035)
    carriage("TramCarriageB", (3.6, 0.0, -2.8), 0.08)

    pit = add_node("TramMaintenancePit", mesh_ids["Pit"], (0.0, 0.22, -5.3), extras={"socket_type": "maintenance_pit"})
    add_node("TramPitEdgeL", mesh_ids["PitEdge"], (-2.85, 0.28, -5.3), parent=pit)
    add_node("TramPitEdgeR", mesh_ids["PitEdge"], (2.85, 0.28, -5.3), parent=pit)
    add_node("TramPitLight0", mesh_ids["ServiceLamp"], (-1.8, 0.68, -5.3), extras={"socket_type": "pit_light"})
    add_node("TramPitLight1", mesh_ids["ServiceLamp"], (1.8, 0.68, -5.3), extras={"socket_type": "pit_light"})
    for index, x in enumerate((-2.2, -1.1, 0.0, 1.1, 2.2)):
        add_node("TramPitRung%d" % index, mesh_ids["PitRung"], (x, 0.72, -6.82), parent=pit)

    for index, x in enumerate((-1.55, 1.55)):
        add_node("TramRail%d" % index, mesh_ids["Rail"], (x, 0.38, 0.0), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"socket_type": "rail"})
    for index, z in enumerate((-6.0, -3.0, 0.0, 3.0, 6.0)):
        add_node("TramSleeper%d" % index, mesh_ids["Sleeper"], (0.0, 0.18, z), extras={"socket_type": "sleeper"})
        add_node("TramRailFastenerL%d" % index, mesh_ids["RailFastener"], (-1.55, 0.52, z), parent=0)
        add_node("TramRailFastenerR%d" % index, mesh_ids["RailFastener"], (1.55, 0.52, z), parent=0)

    signal = add_node("TramSignalMast", mesh_ids["SignalMast"], (-7.0, 3.1, -2.4), extras={"socket_type": "signal_mast"})
    # The mast owns the lamp transform. Keep this offset local so the signal
    # remains attached when the authored landmark is rotated or repositioned.
    add_node("TramSignalHousing", mesh_ids["SignalHousing"], (0.0, 3.25, 0.0), extras={"socket_type": "signal_housing"}, parent=signal)
    add_node("TramSignalLamp", mesh_ids["Signal"], (0.0, 3.25, 0.0), extras={"socket_type": "signal_lamp"}, parent=signal)
    add_node("TramSignalVisor", mesh_ids["SignalVisor"], (0.0, 3.35, 0.22), parent=signal)
    add_node("TramOverheadBeam", mesh_ids["OverheadBeam"], (0.0, 6.1, 0.8), extras={"socket_type": "overhead_service"})
    for index, x in enumerate((-5.0, 5.0)):
        add_node("TramServiceCable%d" % index, mesh_ids["Cable"], (x, 4.8, 0.8), rotation=(0.0, (-0.34 if index == 0 else 0.34), 0.0), extras={"socket_type": "service_cable"})
        add_node("TramCableClamp%d" % index, mesh_ids["CableClamp"], (x, 4.8, 0.8), extras={"socket_type": "service_clamp"})

    for index, (x, z, scale) in enumerate(((-6.1, 4.8, (1.2, 0.85, 1.0)), (5.6, -4.1, (0.9, 0.72, 1.35)), (-4.6, -6.2, (1.0, 0.64, 1.15)))):
        seep = add_node("TramOrganicSeep%d" % index, mesh_ids["Seep"], (x, 0.52, z), scale=scale, extras={"socket_type": "organic_seepage"})
        add_node("TramOrganicSeepTendril%d_0" % index, mesh_ids["SeepTendril"], (-0.20, 0.46, 0.15), rotation=(0.0, 0.0, -0.20), parent=seep)
        add_node("TramOrganicSeepTendril%d_1" % index, mesh_ids["SeepTendril"], (0.24, 0.40, -0.10), rotation=(0.0, 0.0, 0.24), parent=seep)
    add_node("TramServiceMarker", mesh_ids["Marker"], (7.0, 0.20, 4.6), extras={"socket_type": "service_marker"})
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "tram.graveyard.v1", "source": "original_procedural_mesh_builder"})

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Tram Graveyard asset builder"},
        "scene": 0,
        "scenes": [{"name": "TramGraveyard", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {
            "ironwright_asset_id": "tram.graveyard.v1",
            "required_nodes": ["TramGraveyardModel", "TramCarriageA", "TramCarriageAFrontWindow0", "TramCarriageAFrontDoor", "TramCarriageAFrontHeadlampHousing", "TramCarriageABogiePlate0", "TramCarriageAPantograph", "TramMaintenancePit", "TramPitRung0", "TramSignalMast", "TramSignalHousing", "TramSignalLamp", "TramCableClamp0", "TramOrganicSeep0", "TramOrganicSeepTendril0_0", "ProductionAssetMarker"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
