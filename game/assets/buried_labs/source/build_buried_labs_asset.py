"""Build the original high-definition Buried Laboratories landmark glTF."""

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


OUTPUT_PATH = SOURCE_DIR / "buried_labs.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Laboratory ceramic", "pbrMetallicRoughness": {"baseColorFactor": [0.19, 0.24, 0.26, 1.0], "metallicFactor": 0.22, "roughnessFactor": 0.72}},
        {"name": "Laboratory frame", "pbrMetallicRoughness": {"baseColorFactor": [0.055, 0.085, 0.10, 1.0], "metallicFactor": 0.72, "roughnessFactor": 0.40}},
        {"name": "Containment glass", "pbrMetallicRoughness": {"baseColorFactor": [0.05, 0.24, 0.28, 1.0], "metallicFactor": 0.12, "roughnessFactor": 0.20}, "emissiveFactor": [0.03, 0.22, 0.30]},
        {"name": "Containment core", "pbrMetallicRoughness": {"baseColorFactor": [0.18, 0.07, 0.24, 1.0], "metallicFactor": 0.18, "roughnessFactor": 0.28}, "emissiveFactor": [0.36, 0.08, 0.60]},
        {"name": "Laboratory warning", "pbrMetallicRoughness": {"baseColorFactor": [0.64, 0.18, 0.055, 1.0], "metallicFactor": 0.12, "roughnessFactor": 0.42}, "emissiveFactor": [0.78, 0.10, 0.025]},
        {"name": "Laboratory floor", "pbrMetallicRoughness": {"baseColorFactor": [0.10, 0.14, 0.16, 1.0], "metallicFactor": 0.44, "roughnessFactor": 0.78}},
        {"name": "Organic contamination", "pbrMetallicRoughness": {"baseColorFactor": [0.24, 0.035, 0.12, 1.0], "metallicFactor": 0.02, "roughnessFactor": 0.88}, "emissiveFactor": [0.30, 0.012, 0.08]},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    ceramic, frame, glass, core, warning, floor, organic = range(7)
    mesh_ids = {
        "Floor": mesh("LaboratoryFloor", add_box(builder, (17.0, 0.18, 13.0), floor)),
        "Wall": mesh("ContainmentWall", add_box(builder, (0.28, 5.4, 9.0), ceramic)),
        "Frame": mesh("LaboratoryFrame", add_box(builder, (0.18, 5.6, 0.18), frame)),
        "Vessel": mesh("ContainmentVessel", add_cylinder(builder, 1.18, 4.2, glass, 32)),
        "VesselCap": mesh("ContainmentVesselCap", add_cylinder(builder, 1.32, 0.16, frame, 32)),
        "Core": mesh("ContainmentCore", add_cylinder(builder, 0.13, 4.5, core, 20)),
        "Light": mesh("ContainmentLight", add_uv_sphere(builder, 0.18, core, 18, 28)),
        "Rail": mesh("TransferRail", add_box(builder, (15.0, 0.18, 0.22), frame)),
        "Cradle": mesh("TransferCradle", add_box(builder, (1.15, 0.22, 0.95), warning)),
        "Door": mesh("ContainmentDoor", add_box(builder, (3.2, 4.25, 0.22), frame)),
        "DoorTrim": mesh("ContainmentDoorTrim", add_box(builder, (3.55, 0.16, 0.30), warning)),
        "Panel": mesh("SpecimenPanel", add_box(builder, (1.5, 0.95, 0.10), warning)),
        "Cable": mesh("LaboratoryCable", add_cylinder(builder, 0.045, 5.4, warning, 10)),
        "Seep": mesh("OrganicSeep", add_uv_sphere(builder, 0.52, organic, 18, 28)),
        "Brace": mesh("ContainmentBrace", add_box(builder, (0.16, 3.8, 0.16), frame)),
        "VesselPort": mesh("ContainmentVesselPort", add_cylinder(builder, 0.18, 0.16, warning, 18)),
        "VesselClamp": mesh("ContainmentVesselClamp", add_box(builder, (0.12, 0.28, 1.7), frame)),
        "TransferCarriage": mesh("TransferCarriage", add_box(builder, (1.45, 0.16, 1.18), warning)),
        "RailStop": mesh("TransferRailStop", add_cylinder(builder, 0.15, 0.16, warning, 18)),
        "DoorJamb": mesh("ContainmentDoorJamb", add_box(builder, (0.20, 4.4, 0.26), frame)),
        "DoorLintel": mesh("ContainmentDoorLintel", add_box(builder, (3.72, 0.20, 0.28), frame)),
        "PanelFrame": mesh("SpecimenPanelFrame", add_box(builder, (1.72, 1.12, 0.08), frame)),
        "CableClamp": mesh("LaboratoryCableClamp", add_cylinder(builder, 0.12, 0.14, warning, 16)),
        "SeepTendril": mesh("OrganicSeepTendril", add_cylinder(builder, 0.045, 0.82, organic, 14)),
    }

    nodes: list[dict] = [{
        "name": "BuriedLabsModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "buried.labs.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "containment_vessels, transfer_rail, sealed_door, warning_panel, organic_contamination",
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

    add_node("BuriedLabsContainmentHall", mesh_ids["Floor"], (0.0, 0.09, 0.0), extras={"socket_type": "containment_hall"})
    for x in (-8.0, 8.0):
        add_node("BuriedLabsWall", mesh_ids["Wall"], (x, 2.7, 0.0), parent=0)
    for index, x in enumerate((-6.8, -3.4, 0.0, 3.4, 6.8)):
        add_node("BuriedLabsFrame%d" % index, mesh_ids["Frame"], (x, 2.8, -4.35), parent=0)
        add_node("BuriedLabsFrame%dTop" % index, mesh_ids["Frame"], (x, 5.55, -4.35), rotation=(0.0, 0.0, math.pi * 0.5), parent=0)

    for index, x in enumerate((-4.6, 0.0, 4.6)):
        vessel = add_node("BuriedLabsVessel%d" % index, translation=(x, 0.0, 2.35), extras={"socket_type": "containment_vessel"})
        add_node("BuriedLabsVesselBody%d" % index, mesh_ids["Vessel"], (0.0, 2.25, 0.0), parent=vessel)
        add_node("BuriedLabsVesselCap%d" % index, mesh_ids["VesselCap"], (0.0, 4.38, 0.0), parent=vessel)
        add_node("BuriedLabsVesselCore%d" % index, mesh_ids["Core"], (0.0, 2.28, 0.0), extras={"socket_type": "containment_core"}, parent=vessel)
        add_node("BuriedLabsVesselLight%d" % index, mesh_ids["Light"], (0.0, 4.72, 0.0), extras={"socket_type": "containment_light"}, parent=vessel)
        add_node("BuriedLabsVesselPort%d" % index, mesh_ids["VesselPort"], (0.0, 4.84, 0.0), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "containment_service_port"}, parent=vessel)
        add_node("BuriedLabsVesselClampL%d" % index, mesh_ids["VesselClamp"], (-1.22, 2.1, 0.0), rotation=(0.0, 0.0, -0.14), extras={"surface": "containment_clamp"}, parent=vessel)
        add_node("BuriedLabsVesselClampR%d" % index, mesh_ids["VesselClamp"], (1.22, 2.1, 0.0), rotation=(0.0, 0.0, 0.14), extras={"surface": "containment_clamp"}, parent=vessel)
        add_node("BuriedLabsBraceL%d" % index, mesh_ids["Brace"], (-1.22, 2.1, 0.0), rotation=(0.0, 0.0, -0.14), parent=vessel)
        add_node("BuriedLabsBraceR%d" % index, mesh_ids["Brace"], (1.22, 2.1, 0.0), rotation=(0.0, 0.0, 0.14), parent=vessel)

    add_node("BuriedLabsTransferRail", mesh_ids["Rail"], (0.0, 5.65, 1.0), extras={"socket_type": "transfer_rail"})
    add_node("BuriedLabsTransferCradle", mesh_ids["Cradle"], (0.0, 5.30, 1.0), extras={"socket_type": "transfer_cradle"})
    add_node("BuriedLabsTransferCarriage", mesh_ids["TransferCarriage"], (0.0, 5.36, 1.0), extras={"surface": "transfer_carriage"})
    add_node("BuriedLabsTransferRailStopL", mesh_ids["RailStop"], (-6.8, 5.82, 1.0), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "transfer_rail_stop"})
    add_node("BuriedLabsTransferRailStopR", mesh_ids["RailStop"], (6.8, 5.82, 1.0), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "transfer_rail_stop"})
    add_node("BuriedLabsTransferLight", mesh_ids["Light"], (0.0, 5.92, 1.0), extras={"socket_type": "transfer_signal"})
    add_node("BuriedLabsContainmentDoor", mesh_ids["Door"], (0.0, 2.28, -6.05), extras={"socket_type": "sealed_door"})
    add_node("BuriedLabsContainmentDoorTrim", mesh_ids["DoorTrim"], (0.0, 4.48, -6.22), extras={"socket_type": "door_warning"})
    add_node("BuriedLabsContainmentDoorJambL", mesh_ids["DoorJamb"], (-1.78, 2.28, -6.18), extras={"surface": "sealed_door_jamb"})
    add_node("BuriedLabsContainmentDoorJambR", mesh_ids["DoorJamb"], (1.78, 2.28, -6.18), extras={"surface": "sealed_door_jamb"})
    add_node("BuriedLabsContainmentDoorLintel", mesh_ids["DoorLintel"], (0.0, 4.58, -6.18), extras={"surface": "sealed_door_lintel"})
    add_node("BuriedLabsWarningPanel", mesh_ids["Panel"], (-4.8, 2.35, -6.24), extras={"socket_type": "warning_panel"})
    add_node("BuriedLabsWarningPanelFrame", mesh_ids["PanelFrame"], (-4.8, 2.35, -6.29), extras={"surface": "warning_panel_frame"})
    add_node("BuriedLabsCable0", mesh_ids["Cable"], (-4.6, 4.85, 2.35), rotation=(0.0, 0.0, math.pi * 0.5), extras={"socket_type": "service_cable"})
    add_node("BuriedLabsCable1", mesh_ids["Cable"], (4.6, 4.85, 2.35), rotation=(0.0, 0.0, math.pi * 0.5), extras={"socket_type": "service_cable"})
    add_node("BuriedLabsCableClamp0", mesh_ids["CableClamp"], (-4.6, 4.85, 4.95), rotation=(0.0, math.pi * 0.5, 0.0), extras={"surface": "service_cable_clamp"})
    add_node("BuriedLabsCableClamp1", mesh_ids["CableClamp"], (4.6, 4.85, 4.95), rotation=(0.0, math.pi * 0.5, 0.0), extras={"surface": "service_cable_clamp"})
    for index, (x, z, scale) in enumerate(((-7.0, 4.8, (1.25, 0.75, 1.0)), (6.7, -4.6, (0.85, 0.62, 1.35)))):
        add_node("BuriedLabsOrganicSeep%d" % index, mesh_ids["Seep"], (x, 0.52, z), scale=scale, extras={"socket_type": "organic_contamination"})
        for tendril_index, tendril_x in enumerate((-0.22, 0.16)):
            add_node("BuriedLabsOrganicTendril%d_%d" % (index, tendril_index), mesh_ids["SeepTendril"], (x + tendril_x, 0.86, z), rotation=(0.0, 0.0, -0.24 + float(tendril_index) * 0.40), extras={"surface": "organic_tendril"})
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "buried.labs.v1", "source": "original_procedural_mesh_builder"})

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Buried Laboratories asset builder"},
        "scene": 0,
        "scenes": [{"name": "BuriedLabs", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {
            "ironwright_asset_id": "buried.labs.v1",
            "required_nodes": ["BuriedLabsModel", "BuriedLabsContainmentHall", "BuriedLabsVessel0", "BuriedLabsVesselCore0", "BuriedLabsVesselPort0", "BuriedLabsVesselClampL0", "BuriedLabsTransferRail", "BuriedLabsTransferCarriage", "BuriedLabsTransferRailStopL", "BuriedLabsContainmentDoor", "BuriedLabsContainmentDoorJambL", "BuriedLabsContainmentDoorLintel", "BuriedLabsWarningPanelFrame", "BuriedLabsCableClamp0", "BuriedLabsOrganicSeep0", "BuriedLabsOrganicTendril0_0", "ProductionAssetMarker"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
