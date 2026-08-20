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
        {"name": "Observatory weathered concrete", "pbrMetallicRoughness": {"baseColorFactor": [0.24, 0.27, 0.29, 1.0], "metallicFactor": 0.18, "roughnessFactor": 0.82}},
        {"name": "Observatory dark alloy", "pbrMetallicRoughness": {"baseColorFactor": [0.07, 0.10, 0.13, 1.0], "metallicFactor": 0.80, "roughnessFactor": 0.38}},
        {"name": "Observatory oxidized trim", "pbrMetallicRoughness": {"baseColorFactor": [0.38, 0.18, 0.08, 1.0], "metallicFactor": 0.48, "roughnessFactor": 0.60}},
        {"name": "Observatory violet dish", "pbrMetallicRoughness": {"baseColorFactor": [0.18, 0.12, 0.30, 1.0], "metallicFactor": 0.38, "roughnessFactor": 0.42}, "emissiveFactor": [0.18, 0.08, 0.42]},
        {"name": "Observatory cyan signal", "pbrMetallicRoughness": {"baseColorFactor": [0.04, 0.24, 0.30, 1.0], "metallicFactor": 0.22, "roughnessFactor": 0.26}, "emissiveFactor": [0.08, 0.72, 0.86]},
        {"name": "Observatory warm console", "pbrMetallicRoughness": {"baseColorFactor": [0.58, 0.24, 0.06, 1.0], "metallicFactor": 0.18, "roughnessFactor": 0.38}, "emissiveFactor": [0.90, 0.20, 0.035]},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    concrete, alloy, rust, dish, cyan, warm = range(6)
    mesh_ids = {
        "Platform": mesh("Platform", add_box(builder, (11.0, 0.38, 8.0), concrete)),
        "Control": mesh("Control", add_box(builder, (2.8, 2.4, 2.5), alloy)),
        "ControlCap": mesh("ControlCap", add_box(builder, (3.1, 0.18, 2.8), rust)),
        "Dish": mesh("Dish", add_uv_sphere(builder, 3.0, dish, 18, 28)),
        "DishRim": mesh("DishRim", add_box(builder, (6.5, 0.16, 0.22), rust)),
        "DishBrace": mesh("DishBrace", add_box(builder, (0.16, 3.5, 0.26), alloy)),
        "FeedArm": mesh("FeedArm", add_cylinder(builder, 0.16, 4.6, alloy, 16)),
        "Feed": mesh("Feed", add_uv_sphere(builder, 0.30, cyan, 14, 20)),
        "Mast": mesh("Mast", add_cylinder(builder, 0.20, 6.0, rust, 16)),
        "Cable": mesh("Cable", add_cylinder(builder, 0.045, 4.5, warm, 10)),
        "Console": mesh("Console", add_box(builder, (1.1, 0.55, 0.12), warm)),
        "Light": mesh("Light", add_uv_sphere(builder, 0.10, warm, 12, 16)),
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

    add_node("ObservatoryDish", mesh_ids["Dish"], (-0.4, 3.05, 1.0), scale=(1.0, 0.28, 0.82), rotation=(math.pi * 0.12, 0.0, 0.0), extras={"socket_type": "dish"})
    add_node("ObservatoryDishRim", mesh_ids["DishRim"], (-0.4, 3.15, -1.52), rotation=(0.0, 0.0, 0.0))
    add_node("ObservatoryDishBraceL", mesh_ids["DishBrace"], (-2.2, 3.25, 1.0), rotation=(0.0, 0.0, 0.08))
    add_node("ObservatoryDishBraceR", mesh_ids["DishBrace"], (1.4, 3.25, 1.0), rotation=(0.0, 0.0, -0.08))
    add_node("ObservatoryFeedArm", mesh_ids["FeedArm"], (-0.4, 4.1, -0.75), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("ObservatoryFeedSignal", mesh_ids["Feed"], (-0.4, 4.1, -3.05), extras={"socket_type": "feed_signal"})
    add_node("ObservatoryMast", mesh_ids["Mast"], (-4.0, 3.0, 2.2), extras={"socket_type": "mast"})
    add_node("ObservatoryMastLight", mesh_ids["Light"], (-4.0, 6.1, 2.2))

    for index, side in enumerate((-1.0, 1.0)):
        add_node("ObservatoryCable%d" % index, mesh_ids["Cable"], (side * 2.8, 2.65, 2.3), rotation=(0.0, side * 0.28, side * 0.24), extras={"socket_type": "survey_cable"})
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
            "required_nodes": ["ObservatoryModel", "ObservatoryDish", "ObservatoryFeedSignal", "ObservatoryMast", "ObservatoryConsole", "ProductionAssetMarker"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
