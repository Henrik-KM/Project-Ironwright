"""Build the original high-definition Pathfinder scout glTF."""

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


OUTPUT_PATH = SOURCE_DIR / "pathfinder.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Pathfinder charcoal chassis", "pbrMetallicRoughness": {"baseColorFactor": [0.04, 0.07, 0.065, 1.0], "metallicFactor": 0.76, "roughnessFactor": 0.42}},
        {"name": "Pathfinder survey steel", "pbrMetallicRoughness": {"baseColorFactor": [0.24, 0.32, 0.29, 1.0], "metallicFactor": 0.82, "roughnessFactor": 0.34}},
        {"name": "Pathfinder oxide trim", "pbrMetallicRoughness": {"baseColorFactor": [0.28, 0.14, 0.07, 1.0], "metallicFactor": 0.56, "roughnessFactor": 0.6}},
        {"name": "Pathfinder green signal", "pbrMetallicRoughness": {"baseColorFactor": [0.05, 0.25, 0.14, 1.0], "metallicFactor": 0.26, "roughnessFactor": 0.24}, "emissiveFactor": [0.2, 0.92, 0.42]},
        {"name": "Pathfinder cyan optics", "pbrMetallicRoughness": {"baseColorFactor": [0.025, 0.2, 0.22, 1.0], "metallicFactor": 0.3, "roughnessFactor": 0.22}, "emissiveFactor": [0.1, 0.82, 0.9]},
        {"name": "Pathfinder rubber", "pbrMetallicRoughness": {"baseColorFactor": [0.014, 0.018, 0.02, 1.0], "metallicFactor": 0.04, "roughnessFactor": 0.92}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({
            "name": name,
            "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}],
        })
        return len(meshes) - 1

    chassis, steel, oxide, green, cyan, rubber = range(6)
    mesh_ids = {
        "Chassis": mesh("Chassis", add_box(builder, (1.18, 0.58, 1.38), chassis)),
        "Core": mesh("Core", add_box(builder, (0.94, 0.28, 1.1), oxide)),
        "Plate": mesh("Plate", add_box(builder, (1.04, 0.15, 0.13), steel)),
        "Corner": mesh("Corner", add_cylinder(builder, 0.1, 0.14, steel, 10)),
        "Leg": mesh("Leg", add_cylinder(builder, 0.1, 0.68, rubber, 12)),
        "Foot": mesh("Foot", add_box(builder, (0.25, 0.11, 0.36), oxide)),
        "OpticHousing": mesh("OpticHousing", add_box(builder, (0.42, 0.22, 0.12), chassis)),
        "Optic": mesh("Optic", add_uv_sphere(builder, 0.08, cyan)),
        "Fin": mesh("Fin", add_box(builder, (0.16, 0.34, 0.82), steel)),
        "Mast": mesh("Mast", add_cylinder(builder, 0.055, 1.82, chassis, 12)),
        "Dish": mesh("Dish", add_uv_sphere(builder, 0.3, steel, 8, 16)),
        "DishHub": mesh("DishHub", add_cylinder(builder, 0.1, 0.16, cyan, 12)),
        "BeaconRing": mesh("BeaconRing", add_cylinder(builder, 0.16, 0.08, oxide, 14)),
        "Beacon": mesh("Beacon", add_uv_sphere(builder, 0.11, green)),
        "SensorPod": mesh("SensorPod", add_box(builder, (0.64, 0.25, 0.18), chassis)),
        "SensorRail": mesh("SensorRail", add_box(builder, (0.72, 0.05, 0.06), green)),
        "Cable": mesh("Cable", add_cylinder(builder, 0.03, 0.7, rubber, 8)),
    }

    nodes: list[dict] = [{
        "name": "PathfinderModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "pathfinder.scout.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "sensor, survey_mast, beacon",
        },
    }]

    def add_node(
        name: str,
        mesh_id: int | None = None,
        translation: Sequence[float] = (0.0, 0.0, 0.0),
        rotation: Sequence[float] = (0.0, 0.0, 0.0),
        extras: dict | None = None,
        parent: int = 0,
    ) -> int:
        entry: dict = {"name": name, "translation": list(translation)}
        if mesh_id is not None:
            entry["mesh"] = mesh_id
        if rotation != (0.0, 0.0, 0.0):
            entry["rotation"] = quat(rotation)
        if extras:
            entry["extras"] = extras
        nodes.append(entry)
        nodes[parent].setdefault("children", []).append(len(nodes) - 1)
        return len(nodes) - 1

    add_node("Chassis", mesh_ids["Chassis"], (0.0, 0.8, 0.0), extras={"surface": "beveled_primary_body"})
    add_node("ChassisCore", mesh_ids["Core"], (0.0, 0.88, 0.0))
    add_node("ArmorPlate", mesh_ids["Plate"], (0.0, 1.1, -0.72))
    add_node("LowerChassis", mesh_ids["Plate"], (0.0, 0.39, 0.04))
    add_node("ChassisDetailPanel", mesh_ids["Plate"], (0.0, 1.27, -0.7))
    for side in (-1.0, 1.0):
        for front in (-1.0, 1.0):
            add_node("ChassisCornerCap", mesh_ids["Corner"], (side * 0.52, 0.8, front * 0.56))
            add_node("Leg", mesh_ids["Leg"], (side * 0.45, 0.4, front * 0.38), rotation=(0.0, 0.0, side * 0.24))
            add_node("Foot", mesh_ids["Foot"], (side * 0.54, 0.1, front * 0.38))
        add_node("ScoutFin", mesh_ids["Fin"], (side * 0.72, 1.0, 0.1), rotation=(0.0, 0.0, side * 0.16))
        add_node("PathfinderCable", mesh_ids["Cable"], (side * 0.56, 0.88, 0.04), rotation=(0.0, 0.0, side * 0.16))
    add_node("OpticHousing", mesh_ids["OpticHousing"], (0.0, 1.06, -0.8))
    add_node("Sensor", mesh_ids["Optic"], (0.0, 1.06, -0.9), extras={"socket_type": "sensor"})
    add_node("OpticLens", mesh_ids["Optic"], (0.0, 1.06, -0.95), extras={"socket_type": "optic"})
    add_node("ScoutOptic", mesh_ids["Optic"], (-0.2, 1.1, -0.94), extras={"socket_type": "scout_optic"})
    add_node("ScoutOptic", mesh_ids["Optic"], (0.2, 1.1, -0.94), extras={"socket_type": "scout_optic"})
    add_node("PathfinderSensorPod", mesh_ids["SensorPod"], (0.0, 1.38, -0.04), extras={"socket_type": "survey_pod"})
    add_node("PathfinderSensorRail", mesh_ids["SensorRail"], (0.0, 1.55, -0.13))
    add_node("Antenna", mesh_ids["Mast"], (0.0, 1.92, 0.12), extras={"socket_type": "survey_mast"})
    add_node("PathfinderDish", mesh_ids["Dish"], (0.0, 2.78, 0.12))
    add_node("PathfinderDishHub", mesh_ids["DishHub"], (0.0, 2.78, -0.12))
    add_node("BeaconRing", mesh_ids["BeaconRing"], (0.0, 3.1, 0.12))
    add_node("Beacon", mesh_ids["Beacon"], (0.0, 3.2, 0.12), extras={"socket_type": "beacon"})
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "pathfinder.scout.v1", "source": "original_shared_mesh_builder"})

    node_index = {node["name"]: index for index, node in enumerate(nodes)}

    def animation(name: str, channels: list[tuple[str, str, list[float], list[float]]]) -> dict:
        samplers: list[dict] = []
        entries: list[dict] = []
        types = {"translation": ("VEC3", 3), "rotation": ("VEC4", 4)}
        for target_name, path, times, values in channels:
            time_accessor = builder.accessor(times, 5126, "SCALAR", len(times), minimum=[min(times)], maximum=[max(times)])
            type_name, width = types[path]
            output_accessor = builder.accessor(values, 5126, type_name, len(values) // width)
            sampler_index = len(samplers)
            samplers.append({"input": time_accessor, "output": output_accessor, "interpolation": "LINEAR"})
            entries.append({"sampler": sampler_index, "target": {"node": node_index[target_name], "path": path}})
        return {"name": name, "samplers": samplers, "channels": entries}

    animations = [
        animation("Idle", [
            ("PathfinderModel", "translation", [0.0, 0.8, 1.6], [0.0, 0.0, 0.0, 0.0, 0.012, 0.0, 0.0, 0.0, 0.0]),
            ("Sensor", "rotation", [0.0, 0.8, 1.6], quat((0.0, -0.08, 0.0)) + quat((0.0, 0.08, 0.0)) + quat((0.0, -0.08, 0.0))),
            ("Beacon", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.0, -0.04)) + quat((0.0, 0.0, 0.04)) + quat((0.0, 0.0, -0.04))),
        ]),
        animation("Walk", [
            ("Leg", "rotation", [0.0, 0.22, 0.44], quat((0.25, 0.0, 0.0)) + quat((-0.25, 0.0, 0.0)) + quat((0.25, 0.0, 0.0))),
            ("Chassis", "rotation", [0.0, 0.22, 0.44], quat((0.034, 0.0, 0.0)) + quat((-0.034, 0.0, 0.0)) + quat((0.034, 0.0, 0.0))),
            ("PathfinderSensorRail", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.0, 0.035)) + quat((0.0, 0.0, -0.035)) + quat((0.0, 0.0, 0.035))),
        ]),
        animation("Survey", [
            ("PathfinderDish", "rotation", [0.0, 0.7, 1.4], quat((0.0, -0.2, 0.0)) + quat((0.0, 0.2, 0.0)) + quat((0.0, -0.2, 0.0))),
            ("PathfinderDishHub", "rotation", [0.0, 0.7, 1.4], quat((0.0, 0.0, -0.16)) + quat((0.0, 0.0, 0.16)) + quat((0.0, 0.0, -0.16))),
            ("Beacon", "rotation", [0.0, 0.7, 1.4], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.08)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Hit", [
            ("PathfinderModel", "translation", [0.0, 0.10, 0.24], [0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.0, 0.0]),
            ("Sensor", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((-0.15, 0.08, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
    ]

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Pathfinder asset builder"},
        "scene": 0,
        "scenes": [{"name": "Pathfinder", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": "pathfinder.scout.v1",
            "required_nodes": ["PathfinderModel", "Sensor", "OpticLens", "ScoutFin", "BeaconRing", "ScoutOptic", "PathfinderSensorPod", "ProductionAssetMarker"],
            "animation_clips": ["Idle", "Walk", "Survey", "Hit"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
