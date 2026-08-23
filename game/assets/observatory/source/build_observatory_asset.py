"""Build the original high-definition Observatory Ridge landmark glTF."""

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


OUTPUT_PATH = SOURCE_DIR / "observatory.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Observatory weathered concrete", "pbrMetallicRoughness": {"baseColorFactor": [0.30, 0.34, 0.36, 1.0], "metallicFactor": 0.18, "roughnessFactor": 0.78}},
        {"name": "Observatory dark alloy", "pbrMetallicRoughness": {"baseColorFactor": [0.11, 0.17, 0.20, 1.0], "metallicFactor": 0.74, "roughnessFactor": 0.42}},
        {"name": "Observatory oxidized trim", "pbrMetallicRoughness": {"baseColorFactor": [0.46, 0.22, 0.09, 1.0], "metallicFactor": 0.42, "roughnessFactor": 0.62}},
        {"name": "Observatory violet dish", "pbrMetallicRoughness": {"baseColorFactor": [0.18, 0.12, 0.30, 1.0], "metallicFactor": 0.38, "roughnessFactor": 0.42}, "emissiveFactor": [0.08, 0.03, 0.20]},
        {"name": "Observatory cyan signal", "pbrMetallicRoughness": {"baseColorFactor": [0.04, 0.24, 0.30, 1.0], "metallicFactor": 0.22, "roughnessFactor": 0.26}, "emissiveFactor": [0.03, 0.34, 0.42]},
        {"name": "Observatory warm console", "pbrMetallicRoughness": {"baseColorFactor": [0.58, 0.24, 0.06, 1.0], "metallicFactor": 0.18, "roughnessFactor": 0.38}, "emissiveFactor": [0.45, 0.10, 0.018]},
        {"name": "Observatory ridge signal", "pbrMetallicRoughness": {"baseColorFactor": [0.06, 0.30, 0.35, 1.0], "metallicFactor": 0.26, "roughnessFactor": 0.30}, "emissiveFactor": [0.01, 0.16, 0.20]},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    concrete, alloy, rust, dish, cyan, warm, ridge_signal = range(7)
    mesh_ids = {
        "Platform": mesh("Platform", add_box(builder, (11.0, 0.38, 8.0), concrete)),
        "Control": mesh("Control", add_box(builder, (2.8, 2.4, 2.5), alloy)),
        "ControlCap": mesh("ControlCap", add_box(builder, (3.1, 0.18, 2.8), rust)),
        "Dish": mesh("Dish", add_uv_sphere(builder, 3.0, dish, 24, 36)),
        "DishRim": mesh("DishRim", add_box(builder, (6.5, 0.16, 0.22), rust)),
        "DishBrace": mesh("DishBrace", add_box(builder, (0.16, 3.5, 0.26), alloy)),
        "FeedArm": mesh("FeedArm", add_cylinder(builder, 0.16, 4.6, alloy, 16)),
        "Feed": mesh("Feed", add_uv_sphere(builder, 0.30, cyan, 18, 28)),
        "Mast": mesh("Mast", add_cylinder(builder, 0.20, 6.0, rust, 20)),
        "Cable": mesh("Cable", add_cylinder(builder, 0.045, 4.5, warm, 10)),
        "Console": mesh("Console", add_box(builder, (1.1, 0.55, 0.12), warm)),
        "Light": mesh("Light", add_uv_sphere(builder, 0.10, warm, 16, 24)),
        "Deck": mesh("Deck", add_box(builder, (6.8, 0.18, 2.9), alloy)),
        "Rail": mesh("Rail", add_cylinder(builder, 0.06, 2.1, rust, 12)),
        "Window": mesh("Window", add_box(builder, (0.92, 0.72, 0.08), cyan)),
        "ServiceCase": mesh("ServiceCase", add_box(builder, (1.1, 0.72, 0.78), rust)),
        "DishRib": mesh("DishRib", add_box(builder, (0.10, 0.12, 5.5), rust)),
        "DishActuator": mesh("DishActuator", add_cylinder(builder, 0.22, 0.28, alloy, 20)),
        "FeedCollar": mesh("FeedCollar", add_cylinder(builder, 0.38, 0.16, cyan, 24)),
        "WindowFrame": mesh("ObservatoryWindowFrame", add_box(builder, (1.14, 0.10, 0.94), alloy)),
        "WindowMullion": mesh("ObservatoryWindowMullion", add_box(builder, (0.08, 0.72, 0.10), alloy)),
        "ConsoleFrame": mesh("ObservatoryConsoleFrame", add_box(builder, (1.38, 0.08, 0.78), alloy)),
        "DeckPost": mesh("ObservatoryDeckPost", add_cylinder(builder, 0.07, 1.35, rust, 14)),
        "MastCollar": mesh("ObservatoryMastCollar", add_cylinder(builder, 0.30, 0.16, rust, 24)),
        "CableAnchor": mesh("ObservatoryCableAnchor", add_cylinder(builder, 0.12, 0.14, warm, 16)),
        "SurveyLightHousing": mesh("ObservatorySurveyLightHousing", add_cylinder(builder, 0.12, 0.16, alloy, 16)),
        "RidgePylon": mesh("ObservatoryRidgePylon", add_cylinder(builder, 0.22, 6.2, alloy, 18)),
        "RidgeBeam": mesh("ObservatoryRidgeBeam", add_box(builder, (10.0, 0.18, 0.18), rust)),
        "RidgeSignalPanel": mesh("ObservatoryRidgeSignalPanel", add_box(builder, (2.8, 1.35, 0.10), ridge_signal)),
        "RidgeSignalFrame": mesh("ObservatoryRidgeSignalFrame", add_box(builder, (3.15, 1.60, 0.12), alloy)),
        "RidgeLadder": mesh("ObservatoryRidgeLadder", add_box(builder, (0.08, 4.8, 0.08), rust)),
        "RidgeBrace": mesh("ObservatoryRidgeBrace", add_cylinder(builder, 0.065, 3.8, alloy, 14)),
        "RidgeBeacon": mesh("ObservatoryRidgeBeacon", add_uv_sphere(builder, 0.18, cyan, 16, 24)),
        "RidgeSensor": mesh("ObservatoryRidgeSensor", add_cylinder(builder, 0.10, 0.34, warm, 16)),
    }

    nodes: list[dict] = [{
        "name": "ObservatoryModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "observatory.ridge.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "dish, feed_signal, mast, console, survey_cables",
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

    add_node("ObservatoryPlatform", mesh_ids["Platform"], (0.0, 0.20, 0.0), extras={"surface": "weathered_observatory_apron"})
    add_node("ObservatoryControl", mesh_ids["Control"], (3.6, 1.35, -2.2), extras={"surface": "survey_control_cabin"})
    add_node("ObservatoryControlCap", mesh_ids["ControlCap"], (3.6, 2.62, -2.2))
    add_node("ObservatoryConsole", mesh_ids["Console"], (3.6, 1.46, -3.48), extras={"socket_type": "survey_console"})
    add_node("ObservatoryConsoleLight", mesh_ids["Light"], (3.6, 1.95, -3.53))
    add_node("ObservatoryServiceDeck", mesh_ids["Deck"], (2.2, 0.48, -3.05), extras={"socket_type": "service_deck"})
    for index, (x, z) in enumerate(((-1.0, -4.3), (5.4, -4.3), (-1.0, -1.8), (5.4, -1.8))):
        add_node("ObservatoryDeckPost%d" % index, mesh_ids["DeckPost"], (x, 1.05, z), extras={"surface": "service_deck_post"})
    for index, (x, z) in enumerate(((0.0, -4.2), (4.4, -4.2), (0.0, -1.9), (4.4, -1.9))):
        add_node("ObservatorySurveyRail%d" % index, mesh_ids["Rail"], (x, 1.55, z), extras={"socket_type": "survey_rail"})
    add_node("ObservatoryControlWindow0", mesh_ids["Window"], (3.05, 1.78, -0.93), extras={"socket_type": "control_window"})
    add_node("ObservatoryControlWindow1", mesh_ids["Window"], (4.15, 1.78, -0.93), extras={"socket_type": "control_window"})
    for index, x in enumerate((3.05, 4.15)):
        add_node("ObservatoryControlWindowFrame%d" % index, mesh_ids["WindowFrame"], (x, 1.78, -0.87), extras={"surface": "control_window_frame"})
        add_node("ObservatoryControlWindowMullion%d" % index, mesh_ids["WindowMullion"], (x, 1.78, -0.79), extras={"surface": "control_window_mullion"})
    add_node("ObservatoryFrontConsole", mesh_ids["Console"], (3.6, 1.42, -0.88), extras={"socket_type": "survey_console_front"})
    add_node("ObservatoryFrontConsoleFrame", mesh_ids["ConsoleFrame"], (3.6, 1.42, -0.82), extras={"surface": "front_console_frame"})
    add_node("ObservatoryServiceCase", mesh_ids["ServiceCase"], (0.2, 0.9, -3.2), extras={"socket_type": "survey_service_case"})

    add_node("ObservatoryDish", mesh_ids["Dish"], (-0.4, 3.05, 1.0), scale=(1.0, 0.28, 0.82), rotation=(math.pi * 0.12, 0.0, 0.0), extras={"socket_type": "dish"})
    add_node("ObservatoryDishRim", mesh_ids["DishRim"], (-0.4, 3.15, -1.52), rotation=(0.0, 0.0, 0.0))
    for index, rotation_y in enumerate((0.0, math.pi * 0.33, -math.pi * 0.33)):
        add_node("ObservatoryDishRib%d" % index, mesh_ids["DishRib"], (-0.4, 3.18, 1.0), rotation=(math.pi * 0.12, rotation_y, 0.0), extras={"surface": "dish_structural_rib"})
    add_node("ObservatoryDishBraceL", mesh_ids["DishBrace"], (-2.2, 3.25, 1.0), rotation=(0.0, 0.0, 0.08))
    add_node("ObservatoryDishBraceR", mesh_ids["DishBrace"], (1.4, 3.25, 1.0), rotation=(0.0, 0.0, -0.08))
    add_node("ObservatoryDishActuator", mesh_ids["DishActuator"], (-0.4, 2.14, 1.0), extras={"socket_type": "dish_actuator"})
    add_node("ObservatoryFeedArm", mesh_ids["FeedArm"], (-0.4, 4.1, -0.75), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("ObservatoryFeedSignal", mesh_ids["Feed"], (-0.4, 4.1, -3.05), extras={"socket_type": "feed_signal"})
    add_node("ObservatoryFeedCollar", mesh_ids["FeedCollar"], (-0.4, 4.1, -3.05), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "feed_signal_collar"})
    add_node("ObservatoryMast", mesh_ids["Mast"], (-4.0, 3.0, 2.2), extras={"socket_type": "mast"})
    add_node("ObservatoryMastLight", mesh_ids["Light"], (-4.0, 6.1, 2.2))
    add_node("ObservatoryMastCollar", mesh_ids["MastCollar"], (-4.0, 5.85, 2.2), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "mast_service_collar"})

    # A survey station needs a horizon silhouette in addition to its dish.
    # This collapsed ridge gantry gives the Observatory a readable civic
    # infrastructure profile while remaining presentation-only.
    add_node("ObservatoryRidgePylonL", mesh_ids["RidgePylon"], (-4.7, 3.1, -2.55), extras={"socket_type": "ridge_pylon"})
    add_node("ObservatoryRidgePylonR", mesh_ids["RidgePylon"], (4.7, 3.1, -2.55), extras={"socket_type": "ridge_pylon"})
    add_node("ObservatoryRidgeBeam", mesh_ids["RidgeBeam"], (0.0, 6.05, -2.55), rotation=(0.0, 0.0, 0.02), extras={"socket_type": "ridge_beam"})
    add_node("ObservatoryRidgeSignalFrame", mesh_ids["RidgeSignalFrame"], (0.0, 4.95, -2.51), rotation=(0.0, 0.0, -0.03), extras={"surface": "ridge_signal_frame"})
    add_node("ObservatoryRidgeSignalPanel", mesh_ids["RidgeSignalPanel"], (0.0, 4.95, -2.44), rotation=(0.0, 0.0, -0.03), extras={"socket_type": "ridge_signal_panel"})
    add_node("ObservatoryRidgeLadder", mesh_ids["RidgeLadder"], (4.25, 3.0, -2.32), extras={"surface": "ridge_service_ladder"})
    add_node("ObservatoryRidgeBraceL", mesh_ids["RidgeBrace"], (-4.25, 3.65, -2.5), rotation=(0.0, 0.0, 0.22), extras={"surface": "ridge_brace"})
    add_node("ObservatoryRidgeBraceR", mesh_ids["RidgeBrace"], (4.25, 3.65, -2.5), rotation=(0.0, 0.0, -0.22), extras={"surface": "ridge_brace"})
    for index, x in enumerate((-3.2, 0.0, 3.2)):
        add_node("ObservatoryRidgeBeacon%d" % index, mesh_ids["RidgeBeacon"], (x, 6.42, -2.46), extras={"socket_type": "ridge_beacon"})
        add_node("ObservatoryRidgeSensor%d" % index, mesh_ids["RidgeSensor"], (x, 6.62, -2.46), extras={"surface": "ridge_sensor"})

    for index, side in enumerate((-1.0, 1.0)):
        add_node("ObservatoryCable%d" % index, mesh_ids["Cable"], (side * 2.8, 2.65, 2.3), rotation=(0.0, side * 0.28, side * 0.24), extras={"socket_type": "survey_cable"})
        add_node("ObservatoryCableAnchor%d" % index, mesh_ids["CableAnchor"], (side * 2.8, 2.65, 2.3), rotation=(0.0, math.pi * 0.5, 0.0), extras={"surface": "survey_cable_anchor"})
        add_node("ObservatorySurveyLightHousing%d" % index, mesh_ids["SurveyLightHousing"], (side * 4.3, 0.75, -2.5), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "survey_light_housing"})
        add_node("ObservatorySurveyLight%d" % index, mesh_ids["Light"], (side * 4.3, 0.75, -2.5))

    add_node("ProductionAssetMarker", None, extras={"asset_contract": "observatory.ridge.v1", "source": "original_procedural_mesh_builder"})

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Observatory Ridge asset builder"},
        "scene": 0,
        "scenes": [{"name": "ObservatoryRidge", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {
            "ironwright_asset_id": "observatory.ridge.v1",
            "required_nodes": ["ObservatoryModel", "ObservatoryDish", "ObservatoryDishRib0", "ObservatoryDishActuator", "ObservatoryFeedSignal", "ObservatoryFeedCollar", "ObservatoryMast", "ObservatoryMastCollar", "ObservatoryConsole", "ObservatoryFrontConsole", "ObservatoryFrontConsoleFrame", "ObservatoryServiceDeck", "ObservatoryControlWindow0", "ObservatoryControlWindowFrame0", "ObservatoryControlWindowMullion0", "ObservatorySurveyRail0", "ObservatoryCableAnchor0", "ObservatorySurveyLightHousing0", "ObservatoryRidgePylonL", "ObservatoryRidgeBeam", "ObservatoryRidgeSignalPanel", "ObservatoryRidgeLadder", "ObservatoryRidgeBraceL", "ObservatoryRidgeBeacon0", "ObservatoryRidgeSensor0", "ProductionAssetMarker"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
