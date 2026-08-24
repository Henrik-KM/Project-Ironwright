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
from build_bulwark_asset import BufferBuilder, add_beveled_box, add_cylinder, add_uv_sphere, quat  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "west_grid.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "West Grid concrete", "pbrMetallicRoughness": {"baseColorFactor": [0.012, 0.026, 0.035, 1.0], "metallicFactor": 0.08, "roughnessFactor": 0.88}},
        {"name": "West Grid steel", "pbrMetallicRoughness": {"baseColorFactor": [0.02, 0.05, 0.065, 1.0], "metallicFactor": 0.20, "roughnessFactor": 0.62}},
        {"name": "West Grid painted iron", "pbrMetallicRoughness": {"baseColorFactor": [0.045, 0.10, 0.12, 1.0], "metallicFactor": 0.22, "roughnessFactor": 0.62}},
        {"name": "West Grid rust", "pbrMetallicRoughness": {"baseColorFactor": [0.46, 0.17, 0.055, 1.0], "metallicFactor": 0.36, "roughnessFactor": 0.7}, "emissiveFactor": [0.08, 0.012, 0.002]},
        {"name": "West Grid signal", "pbrMetallicRoughness": {"baseColorFactor": [0.02, 0.20, 0.24, 1.0], "metallicFactor": 0.2, "roughnessFactor": 0.3}, "emissiveFactor": [0.05, 0.32, 0.36]},
        {"name": "West Grid amber", "pbrMetallicRoughness": {"baseColorFactor": [0.63, 0.28, 0.06, 1.0], "metallicFactor": 0.22, "roughnessFactor": 0.5}, "emissiveFactor": [0.26, 0.045, 0.004]},
        {"name": "West Grid organic", "pbrMetallicRoughness": {"baseColorFactor": [0.16, 0.025, 0.11, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.84}, "emissiveFactor": [0.24, 0.01, 0.08]},
        {"name": "West Grid ceramic", "pbrMetallicRoughness": {"baseColorFactor": [0.05, 0.10, 0.11, 1.0], "metallicFactor": 0.10, "roughnessFactor": 0.68}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    concrete, steel, painted_iron, rust, signal, amber, organic, ceramic = range(8)
    mesh_ids = {
        "Floor": mesh("WestGridFloor", add_beveled_box(builder, (26.0, 0.16, 22.0), concrete, 0.04)),
        "Hall": mesh("WestGridTurbineHall", add_beveled_box(builder, (11.5, 6.6, 5.0), steel, 0.20)),
        "Roof": mesh("WestGridRoof", add_beveled_box(builder, (12.3, 0.32, 5.5), painted_iron, 0.07)),
        "Window": mesh("WestGridWindow", add_beveled_box(builder, (1.65, 1.25, 0.08), signal, 0.03)),
        "Tank": mesh("WestGridPressureTank", add_cylinder(builder, 1.15, 3.8, ceramic, 28)),
        "TankBand": mesh("WestGridTankBand", add_cylinder(builder, 1.22, 0.12, rust, 28)),
        "Transformer": mesh("WestGridTransformer", add_beveled_box(builder, (2.4, 1.7, 2.0), painted_iron, 0.10)),
        "Fin": mesh("WestGridTransformerFin", add_beveled_box(builder, (0.12, 1.2, 1.7), ceramic, 0.025)),
        "Pipe": mesh("WestGridPipe", add_cylinder(builder, 0.085, 5.6, rust, 12)),
        "Rail": mesh("WestGridRail", add_cylinder(builder, 0.065, 4.0, painted_iron, 12)),
        "Signal": mesh("WestGridSignalLight", add_uv_sphere(builder, 0.16, signal, 14, 22)),
        "Amber": mesh("WestGridWarningLight", add_uv_sphere(builder, 0.18, amber, 14, 22)),
        "Organic": mesh("WestGridOrganicCreep", add_uv_sphere(builder, 0.58, organic, 18, 28)),
        "Marker": mesh("WestGridMarker", add_beveled_box(builder, (0.7, 0.08, 0.7), rust, 0.025)),
        "WindowFrame": mesh("WestGridWindowFrame", add_beveled_box(builder, (1.86, 0.10, 1.46), painted_iron, 0.03)),
        "WindowMullion": mesh("WestGridWindowMullion", add_beveled_box(builder, (0.10, 1.25, 0.12), painted_iron, 0.025)),
        "TankValve": mesh("WestGridTankValve", add_cylinder(builder, 0.14, 0.22, rust, 18)),
        "TankLadder": mesh("WestGridTankLadder", add_cylinder(builder, 0.055, 2.8, painted_iron, 12)),
        "TransformerCap": mesh("WestGridTransformerCap", add_beveled_box(builder, (2.62, 0.12, 2.2), ceramic, 0.03)),
        "TransformerBrace": mesh("WestGridTransformerBrace", add_beveled_box(builder, (0.10, 0.12, 2.05), rust, 0.025)),
        "PipeFlange": mesh("WestGridPipeFlange", add_cylinder(builder, 0.17, 0.14, rust, 18)),
        "WarningHousing": mesh("WestGridWarningHousing", add_cylinder(builder, 0.12, 0.16, painted_iron, 16)),
        "OrganicTendril": mesh("WestGridOrganicTendril", add_cylinder(builder, 0.05, 0.84, organic, 14)),
        "HallDoor": mesh("WestGridHallServiceDoor", add_beveled_box(builder, (2.5, 2.8, 0.12), ceramic, 0.06)),
        "HallDoorFrame": mesh("WestGridHallServiceDoorFrame", add_beveled_box(builder, (2.82, 3.1, 0.16), painted_iron, 0.04)),
        "HallLouver": mesh("WestGridHallLouver", add_beveled_box(builder, (0.18, 1.05, 2.1), ceramic, 0.025)),
        "HallLouverRail": mesh("WestGridHallLouverRail", add_beveled_box(builder, (2.3, 0.10, 0.12), rust, 0.02)),
        "HallSkinRib": mesh("WestGridHallSkinRib", add_beveled_box(builder, (0.14, 2.4, 0.16), rust, 0.025)),
        "HallSkinRail": mesh("WestGridHallSkinRail", add_beveled_box(builder, (8.8, 0.12, 0.16), painted_iron, 0.025)),
        "HallSkinPlate": mesh("WestGridHallSkinPlate", add_beveled_box(builder, (0.84, 0.48, 0.10), ceramic, 0.035)),
        "RoofVent": mesh("WestGridRoofServiceVent", add_beveled_box(builder, (1.8, 0.48, 1.25), ceramic, 0.08)),
        "RoofVentCap": mesh("WestGridRoofServiceVentCap", add_beveled_box(builder, (2.1, 0.10, 1.5), rust, 0.03)),
        "RoofSignal": mesh("WestGridRoofServiceSignal", add_uv_sphere(builder, 0.14, signal, 14, 22)),
        "ServicePanel": mesh("WestGridServicePanel", add_beveled_box(builder, (1.3, 0.9, 0.08), painted_iron, 0.03)),
        "ServicePanelLine": mesh("WestGridServicePanelLine", add_beveled_box(builder, (0.95, 0.08, 0.04), signal, 0.01)),
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
        add_node("WestGridWindow%d" % index, mesh_ids["Window"], (x, 3.55, -0.26), extras={"socket_type": "hall_window"})
        add_node("WestGridWindowFrame%d" % index, mesh_ids["WindowFrame"], (x, 3.55, -0.19), extras={"surface": "hall_window_frame"})
        add_node("WestGridWindowMullion%d" % index, mesh_ids["WindowMullion"], (x, 3.55, -0.11), extras={"surface": "hall_window_mullion"})
    add_node("WestGridHallServiceDoor", mesh_ids["HallDoor"], (-4.8, 1.58, -0.31), extras={"surface": "hall_service_door"})
    add_node("WestGridHallServiceDoorFrame", mesh_ids["HallDoorFrame"], (-4.8, 1.58, -0.20), extras={"surface": "hall_service_door_frame"})
    for index, x in enumerate((-7.1, -5.7, -3.9, -2.5)):
        add_node("WestGridHallLouver%d" % index, mesh_ids["HallLouver"], (x, 2.58, -0.16), extras={"surface": "hall_louver"})
    add_node("WestGridHallLouverRailTop", mesh_ids["HallLouverRail"], (-4.8, 3.16, -0.13), extras={"surface": "hall_louver_rail"})
    add_node("WestGridHallLouverRailBottom", mesh_ids["HallLouverRail"], (-4.8, 2.02, -0.13), extras={"surface": "hall_louver_rail"})
    # Break the broad upper turbine-hall skin into maintained service bays.
    # These are shallow authored ribs and inspection plates, presentation
    # only, so the industrial facade gains depth without new collision.
    for index, x in enumerate((-8.4, -6.6, -4.8, -3.0, -1.2)):
        add_node("WestGridHallSkinRib%d" % index, mesh_ids["HallSkinRib"], (x, 5.0, -0.12), extras={"surface": "hall_skin_rib"})
    add_node("WestGridHallSkinRailTop", mesh_ids["HallSkinRail"], (-4.8, 6.05, -0.12), extras={"surface": "hall_skin_rail"})
    add_node("WestGridHallSkinRailBottom", mesh_ids["HallSkinRail"], (-4.8, 4.02, -0.12), extras={"surface": "hall_skin_rail"})
    for index, x in enumerate((-7.5, -5.7, -3.9, -2.1)):
        add_node("WestGridHallSkinPlate%d" % index, mesh_ids["HallSkinPlate"], (x, 5.2, -0.21), extras={"surface": "hall_skin_inspection_plate"})
    for index, (x, z) in enumerate(((-6.7, -1.7), (-2.8, -1.7))):
        add_node("WestGridRoofServiceVent%d" % index, mesh_ids["RoofVent"], (x, 6.76, z), extras={"surface": "roof_service_vent"})
        add_node("WestGridRoofServiceVentCap%d" % index, mesh_ids["RoofVentCap"], (x, 7.04, z), extras={"surface": "roof_service_vent_cap"})
        add_node("WestGridRoofServiceSignal%d" % index, mesh_ids["RoofSignal"], (x, 7.34, z), extras={"socket_type": "roof_service_signal"})
    add_node("WestGridServicePanel", mesh_ids["ServicePanel"], (1.2, 1.42, -0.35), extras={"surface": "yard_service_panel"})
    for index, x in enumerate((0.86, 1.2, 1.54)):
        add_node("WestGridServicePanelLine%d" % index, mesh_ids["ServicePanelLine"], (x, 1.62, -0.40), extras={"surface": "yard_service_panel_signal"})
    for index, (x, z) in enumerate(((5.3, -5.2), (9.0, -5.0), (7.2, 3.9))):
        add_node("WestGridPressureTank%d" % index, mesh_ids["Tank"], (x, 2.15, z), extras={"socket_type": "pressure_tank"})
        add_node("WestGridPressureTankBand%d" % index, mesh_ids["TankBand"], (x, 2.15, z), parent=0)
        add_node("WestGridTankSignal%d" % index, mesh_ids["Signal"], (x, 4.18, z), extras={"socket_type": "tank_signal"})
        add_node("WestGridTankValve%d" % index, mesh_ids["TankValve"], (x, 4.28, z), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "pressure_service_valve"})
        add_node("WestGridTankLadder%d" % index, mesh_ids["TankLadder"], (x - 0.92, 2.15, z), rotation=(0.0, 0.0, math.pi * 0.5), extras={"surface": "pressure_tank_ladder"})
    for index, (x, z) in enumerate(((2.2, -1.5), (6.4, -1.5))):
        transformer = add_node("WestGridTransformer%d" % index, mesh_ids["Transformer"], (x, 0.98, z), extras={"socket_type": "transformer"})
        add_node("WestGridTransformerCap%d" % index, mesh_ids["TransformerCap"], (x, 1.9, z), parent=transformer, extras={"surface": "transformer_cap"})
        for fin_index in range(4):
            add_node("WestGridTransformerFin%d_%d" % (index, fin_index), mesh_ids["Fin"], (-0.82 + float(fin_index) * 0.55, 0.02, -1.05), parent=transformer)
        add_node("WestGridTransformerBrace%d" % index, mesh_ids["TransformerBrace"], (0.0, 0.88, -1.08), parent=transformer, extras={"surface": "transformer_brace"})
    add_node("WestGridPipeBridge", mesh_ids["Rail"], (0.0, 4.1, 2.8), rotation=(0.0, 0.0, math.pi * 0.5), extras={"socket_type": "pipe_bridge"})
    for index, x in enumerate((-5.8, -2.0, 1.8, 5.6)):
        add_node("WestGridPipeSupport%d" % index, mesh_ids["Rail"], (x, 2.0, 2.8))
    for index, x in enumerate((-3.8, 0.0, 3.8)):
        add_node("WestGridServicePipe%d" % index, mesh_ids["Pipe"], (x, 3.7, 2.8), rotation=(0.0, 0.0, math.pi * 0.5), extras={"socket_type": "service_pipe"})
        add_node("WestGridPipeFlange%d" % index, mesh_ids["PipeFlange"], (x, 3.7, 2.8), rotation=(0.0, 0.0, math.pi * 0.5), extras={"surface": "service_pipe_flange"})
    for index, (x, z) in enumerate(((-9.8, -6.2), (0.0, -6.3), (10.2, 1.0))):
        add_node("WestGridWarningHousing%d" % index, mesh_ids["WarningHousing"], (x, 2.15, z), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "warning_housing"})
        add_node("WestGridWarningLight%d" % index, mesh_ids["Amber"], (x, 2.15, z), extras={"socket_type": "warning_light"})
    for index, (x, y, z, scale) in enumerate(((-9.0, 0.48, 3.7, (1.2, 0.75, 0.9)), (1.0, 0.55, -5.8, (0.85, 0.65, 1.2)), (9.0, 0.52, 4.8, (1.05, 0.72, 0.86)))):
        add_node("WestGridOrganicCreep%d" % index, mesh_ids["Organic"], (x, y, z), scale=scale, extras={"socket_type": "organic_creep"})
        for tendril_index, tendril_x in enumerate((-0.24, 0.18)):
            add_node("WestGridOrganicTendril%d_%d" % (index, tendril_index), mesh_ids["OrganicTendril"], (x + tendril_x, y + 0.34, z), rotation=(0.0, 0.0, -0.24 + float(tendril_index) * 0.40), extras={"surface": "organic_tendril"})
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
            "required_nodes": ["WestGridModel", "WestGridTurbineHall", "WestGridWindowFrame0", "WestGridWindowMullion0", "WestGridHallServiceDoor", "WestGridHallServiceDoorFrame", "WestGridHallLouver0", "WestGridHallLouverRailTop", "WestGridHallSkinRib0", "WestGridHallSkinRailTop", "WestGridHallSkinPlate0", "WestGridRoofServiceVent0", "WestGridRoofServiceVentCap0", "WestGridRoofServiceSignal0", "WestGridServicePanel", "WestGridServicePanelLine0", "WestGridPressureTank0", "WestGridTankValve0", "WestGridTankLadder0", "WestGridTransformer0", "WestGridTransformerCap0", "WestGridTransformerBrace0", "WestGridPipeBridge", "WestGridPipeFlange0", "WestGridWarningHousing0", "WestGridWarningLight0", "WestGridOrganicCreep0", "WestGridOrganicTendril0_0", "ProductionAssetMarker"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
