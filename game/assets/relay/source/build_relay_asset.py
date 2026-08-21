"""Build the original high-definition Signal Relay glTF shell."""

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


OUTPUT_PATH = SOURCE_DIR / "relay.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Relay charcoal chassis", "pbrMetallicRoughness": {"baseColorFactor": [0.055, 0.09, 0.1, 1.0], "metallicFactor": 0.82, "roughnessFactor": 0.34}},
        {"name": "Relay weathered ceramic", "pbrMetallicRoughness": {"baseColorFactor": [0.34, 0.42, 0.42, 1.0], "metallicFactor": 0.7, "roughnessFactor": 0.38}},
        {"name": "Relay amber spine", "pbrMetallicRoughness": {"baseColorFactor": [0.42, 0.17, 0.045, 1.0], "metallicFactor": 0.42, "roughnessFactor": 0.42}, "emissiveFactor": [0.42, 0.08, 0.015]},
        {"name": "Relay cyan signal", "pbrMetallicRoughness": {"baseColorFactor": [0.025, 0.24, 0.27, 1.0], "metallicFactor": 0.3, "roughnessFactor": 0.22}, "emissiveFactor": [0.1, 0.9, 0.95]},
        {"name": "Relay rubber cable", "pbrMetallicRoughness": {"baseColorFactor": [0.012, 0.018, 0.02, 1.0], "metallicFactor": 0.04, "roughnessFactor": 0.9}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({
            "name": name,
            "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}],
        })
        return len(meshes) - 1

    chassis, ceramic, amber, cyan, rubber = range(5)
    mesh_ids = {
        "Chassis": mesh("Chassis", add_box(builder, (1.22, 0.68, 1.42), chassis)),
        "Core": mesh("Core", add_box(builder, (0.9, 0.28, 1.08), amber)),
        "Face": mesh("Face", add_box(builder, (0.76, 0.28, 0.08), ceramic)),
        "HeatSink": mesh("HeatSink", add_box(builder, (0.8, 0.3, 0.14), ceramic)),
        "Corner": mesh("Corner", add_cylinder(builder, 0.1, 0.14, ceramic, 10)),
        "Leg": mesh("Leg", add_cylinder(builder, 0.095, 0.58, rubber, 12)),
        "Foot": mesh("Foot", add_box(builder, (0.25, 0.12, 0.42), ceramic)),
        "OpticHousing": mesh("OpticHousing", add_box(builder, (0.38, 0.2, 0.12), chassis)),
        "Optic": mesh("Optic", add_uv_sphere(builder, 0.085, cyan)),
        "Mast": mesh("Mast", add_cylinder(builder, 0.07, 1.18, rubber, 12)),
        "Collar": mesh("Collar", add_cylinder(builder, 0.115, 0.08, amber, 12)),
        "Dish": mesh("Dish", add_cylinder(builder, 0.34, 0.12, ceramic, 16)),
        "DishRim": mesh("DishRim", add_cylinder(builder, 0.39, 0.04, cyan, 16)),
        "Beacon": mesh("Beacon", add_uv_sphere(builder, 0.095, cyan)),
        "Brace": mesh("Brace", add_box(builder, (0.08, 0.12, 0.58), chassis)),
        "Panel": mesh("Panel", add_box(builder, (0.24, 0.3, 0.08), cyan)),
        "Fastener": mesh("Fastener", add_cylinder(builder, 0.04, 0.04, amber, 10)),
    }

    nodes: list[dict] = [{
        "name": "RelayModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "relay.signal.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "sensor, signal_mast, directional_dish, signal_beacon",
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

    chassis_node = add_node("Chassis", mesh_ids["Chassis"], (0.0, 0.82, 0.0), extras={"surface": "beveled_primary_body"})
    add_node("ChassisCore", mesh_ids["Core"], (0.0, 0.1, 0.0), parent=chassis_node)
    add_node("RelayServiceFace", mesh_ids["Face"], (0.0, 1.15, -0.74), extras={"socket_type": "service_face"})
    add_node("RelayHeatSink", mesh_ids["HeatSink"], (0.0, 0.92, 0.74), extras={"socket_type": "heat_sink"})
    for side in (-1.0, 1.0):
        for front in (-1.0, 1.0):
            add_node("RelayCornerCap", mesh_ids["Corner"], (side * 0.48, 0.82, front * 0.56))
        add_node("RelayLeg%s" % ("Left" if side < 0 else "Right"), mesh_ids["Leg"], (side * 0.43, 0.43, 0.0))
        add_node("RelayFoot%s" % ("Left" if side < 0 else "Right"), mesh_ids["Foot"], (side * 0.5, 0.12, -0.04))
        add_node("RelayBrace%s" % ("Left" if side < 0 else "Right"), mesh_ids["Brace"], (side * 0.53, 1.17, 0.12), rotation=(0.0, 0.0, side * 0.28))
        add_node("RelaySignalPanel%s" % ("Left" if side < 0 else "Right"), mesh_ids["Panel"], (side * 0.69, 1.0, 0.0), rotation=(0.0, 0.0, side * 0.2), extras={"socket_type": "signal_panel"})
    add_node("OpticHousing", mesh_ids["OpticHousing"], (0.0, 1.36, -0.82))
    add_node("Sensor", mesh_ids["Optic"], (0.0, 1.36, -0.93), extras={"socket_type": "sensor"})
    add_node("OpticLens", mesh_ids["Optic"], (0.0, 1.36, -0.98), extras={"socket_type": "optic"})
    add_node("RelayMast", mesh_ids["Mast"], (0.0, 1.68, 0.08), extras={"socket_type": "signal_mast"})
    add_node("RelayMastCollar", mesh_ids["Collar"], (0.0, 1.58, 0.08))
    add_node("RelayDirectionalDish", mesh_ids["Dish"], (0.0, 2.12, 0.0), rotation=(0.55, 0.0, 0.0), extras={"socket_type": "directional_dish"})
    add_node("RelayDishRim", mesh_ids["DishRim"], (0.0, 2.19, 0.02), rotation=(0.55, 0.0, 0.0))
    add_node("RelayBeacon", mesh_ids["Beacon"], (0.0, 2.3, -0.04), extras={"socket_type": "signal_beacon"})
    for side in (-1.0, 1.0):
        add_node("RelayDishRib%s" % ("Left" if side < 0 else "Right"), mesh_ids["Brace"], (side * 0.18, 2.38, 0.0), rotation=(0.0, 0.0, side * 0.2))
    add_node("RelayFastenerLeft", mesh_ids["Fastener"], (-0.39, 1.19, -0.79), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("RelayFastenerRight", mesh_ids["Fastener"], (0.39, 1.19, -0.79), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "relay.signal.v1", "source": "original_shared_mesh_builder"})

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
            ("RelayModel", "translation", [0.0, 0.8, 1.6], [0.0, 0.0, 0.0, 0.0, 0.012, 0.0, 0.0, 0.0, 0.0]),
            ("RelayBeacon", "rotation", [0.0, 0.8, 1.6], quat((0.0, -0.08, 0.0)) + quat((0.0, 0.08, 0.0)) + quat((0.0, -0.08, 0.0))),
            ("RelayDirectionalDish", "rotation", [0.0, 0.8, 1.6], quat((0.52, 0.0, -0.03)) + quat((0.55, 0.0, 0.03)) + quat((0.52, 0.0, -0.03))),
        ]),
        animation("Walk", [
            ("RelayLegLeft", "rotation", [0.0, 0.22, 0.44], quat((0.18, 0.0, 0.0)) + quat((-0.18, 0.0, 0.0)) + quat((0.18, 0.0, 0.0))),
            ("RelayLegRight", "rotation", [0.0, 0.22, 0.44], quat((-0.18, 0.0, 0.0)) + quat((0.18, 0.0, 0.0)) + quat((-0.18, 0.0, 0.0))),
            ("RelayModel", "rotation", [0.0, 0.22, 0.44], quat((0.025, 0.0, 0.0)) + quat((-0.025, 0.0, 0.0)) + quat((0.025, 0.0, 0.0))),
        ]),
        animation("Work", [
            ("RelayDirectionalDish", "rotation", [0.0, 0.5, 1.0], quat((0.55, 0.0, -0.12)) + quat((0.55, 0.0, 0.12)) + quat((0.55, 0.0, -0.12))),
            ("RelayBeacon", "rotation", [0.0, 0.5, 1.0], quat((0.0, 0.0, -0.1)) + quat((0.0, 0.0, 0.1)) + quat((0.0, 0.0, -0.1))),
        ]),
        animation("Fire", [
            ("RelayBeacon", "rotation", [0.0, 0.08, 0.18], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.22, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("RelayModel", "translation", [0.0, 0.08, 0.18], [0.0, 0.0, 0.0, 0.0, 0.045, 0.0, 0.0, 0.0, 0.0]),
        ]),
        animation("Hit", [
            ("RelayModel", "translation", [0.0, 0.1, 0.24], [0.0, 0.0, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0]),
            ("RelayDirectionalDish", "rotation", [0.0, 0.1, 0.24], quat((0.55, 0.0, 0.0)) + quat((0.46, 0.1, 0.0)) + quat((0.55, 0.0, 0.0))),
        ]),
        animation("Retreat", [
            ("RelayModel", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.12)) + quat((0.0, 0.0, 0.0))),
            ("RelayBeacon", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.18)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Death", [
            ("RelayModel", "translation", [0.0, 0.18, 0.42], [0.0, 0.0, 0.0, 0.0, -0.08, 0.0, 0.0, -0.22, 0.0]),
            ("RelayModel", "rotation", [0.0, 0.18, 0.42], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.16, 0.22)) + quat((0.0, 0.22, 0.32))),
        ]),
    ]

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Signal Relay asset builder"},
        "scene": 0,
        "scenes": [{"name": "Signal Relay", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": "relay.signal.v1",
            "required_nodes": ["RelayModel", "Sensor", "OpticLens", "RelayMast", "RelayDirectionalDish", "RelayBeacon", "ProductionAssetMarker"],
            "animation_clips": ["Idle", "Walk", "Work", "Fire", "Hit", "Retreat", "Death"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
