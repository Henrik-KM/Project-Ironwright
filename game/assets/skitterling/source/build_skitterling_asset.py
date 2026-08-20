"""Build the original high-definition Skitterling organic glTF."""

from __future__ import annotations

import base64
import json
import sys
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, add_box, add_cylinder, add_uv_sphere, quat  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "skitterling.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Skitterling wet carapace", "pbrMetallicRoughness": {"baseColorFactor": [0.055, 0.07, 0.072, 1.0], "metallicFactor": 0.24, "roughnessFactor": 0.3}},
        {"name": "Skitterling shell ridge", "pbrMetallicRoughness": {"baseColorFactor": [0.2, 0.22, 0.19, 1.0], "metallicFactor": 0.14, "roughnessFactor": 0.4}},
        {"name": "Skitterling tendon", "pbrMetallicRoughness": {"baseColorFactor": [0.27, 0.065, 0.08, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.52}},
        {"name": "Skitterling bone", "pbrMetallicRoughness": {"baseColorFactor": [0.5, 0.41, 0.28, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.58}},
        {"name": "Skitterling scavenger eye", "pbrMetallicRoughness": {"baseColorFactor": [0.42, 0.16, 0.02, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.2}, "emissiveFactor": [1.0, 0.13, 0.015]},
        {"name": "Skitterling membrane", "pbrMetallicRoughness": {"baseColorFactor": [0.14, 0.025, 0.06, 0.82], "metallicFactor": 0.0, "roughnessFactor": 0.38}, "emissiveFactor": [0.035, 0.001, 0.01]},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    wet, shell, tendon, bone, eye, membrane = range(6)
    mesh_ids = {
        "Core": mesh("Core", add_uv_sphere(builder, 0.38, wet, 16, 24)),
        "Segment": mesh("Segment", add_uv_sphere(builder, 0.3, shell, 14, 22)),
        "Ridge": mesh("Ridge", add_box(builder, (0.72, 0.12, 0.18), shell)),
        "Antenna": mesh("Antenna", add_cylinder(builder, 0.035, 0.72, tendon, 12)),
        "Mandible": mesh("Mandible", add_cylinder(builder, 0.045, 0.56, bone, 12)),
        "Eye": mesh("Eye", add_uv_sphere(builder, 0.065, eye, 10, 16)),
        "Leg": mesh("Leg", add_cylinder(builder, 0.06, 0.78, tendon, 12)),
        "Claw": mesh("Claw", add_cylinder(builder, 0.04, 0.42, bone, 12)),
        "Fan": mesh("Fan", add_box(builder, (0.08, 0.42, 0.34), membrane)),
        "Fastener": mesh("Fastener", add_uv_sphere(builder, 0.03, bone, 8, 12)),
    }

    nodes: list[dict] = [{
        "name": "SkitterlingModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "skitterling.scavenger.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "carapace, antennae, mandibles, sensory_fan, scavenger_eyes",
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

    torso = add_node("Torso", extras={"surface": "layered_scavenger_carapace"})
    add_node("TorsoCore", mesh_ids["Core"], (0.0, 0.44, 0.18), scale=(1.28, 0.8, 1.48), parent=torso, extras={"release_material_family": "chitin"})
    for index in range(4):
        z = -0.46 + index * 0.34
        add_node("TorsoSegment%d" % index, mesh_ids["Segment"], (0.0, 0.47, z), scale=(1.08 - index * 0.04, 0.72, 1.05 - index * 0.03), parent=torso)
        add_node("SkitterlingCarapace%d" % index, mesh_ids["Ridge"], (0.0, 0.78, z), rotation=(0.0, 0.0, 0.04), scale=(1.0 - index * 0.07, 1.0, 1.0), parent=torso, extras={"surface": "shell_ridge"})
        add_node("SkitterlingFastenerL%d" % index, mesh_ids["Fastener"], (-0.32, 0.68, z), parent=torso)
        add_node("SkitterlingFastenerR%d" % index, mesh_ids["Fastener"], (0.32, 0.68, z), parent=torso)
    add_node("OrganicDorsalPlate", mesh_ids["Ridge"], (-0.1, 0.92, 0.18), scale=(1.1, 0.9, 1.2), extras={"surface": "layered_shell_break"})

    for side in (-1.0, 1.0):
        suffix = "L" if side < 0 else "R"
        add_node("SkitterlingEye%s" % suffix, mesh_ids["Eye"], (side * 0.16, 0.8, -0.92), extras={"socket_type": "scavenger_eye"})
        add_node("SkitterlingAntenna%s" % suffix, mesh_ids["Antenna"], (side * 0.2, 0.74, -0.82), rotation=(0.56, 0.0, side * 0.18), extras={"socket_type": "antenna"})
        add_node("SkitterlingMandible%s" % suffix, mesh_ids["Mandible"], (side * 0.18, 0.42, -1.02), rotation=(0.8, 0.0, side * 0.22), extras={"socket_type": "mandible"})

    for index in range(3):
        side = -1.0 if index % 2 == 0 else 1.0
        add_node("SkitterlingSensoryFan%d" % index, mesh_ids["Fan"], (side * (0.06 + index * 0.06), 0.92, 0.24 + index * 0.16), rotation=(0.0, side * 0.12, side * (0.22 + index * 0.08)), scale=(1.0, 1.0 + index * 0.14, 1.0), extras={"surface": "sensory_membrane"})

    for side in (-1.0, 1.0):
        suffix = "L" if side < 0 else "R"
        for index in range(4):
            z = -0.4 + index * 0.28
            add_node("SkitterlingLeg%s%d" % (suffix, index), mesh_ids["Leg"], (side * (0.38 + index * 0.02), 0.28, z), rotation=(0.0, 0.0, side * 0.78))
            add_node("SkitterlingClaw%s%d" % (suffix, index), mesh_ids["Claw"], (side * 0.62, 0.08, z - 0.02), rotation=(0.0, 0.0, side * 0.34))

    add_node("ProductionAssetMarker", None, extras={"asset_contract": "skitterling.scavenger.v1", "source": "original_shared_mesh_builder"})
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
        animation("Idle", [("SkitterlingModel", "translation", [0.0, 0.7, 1.4], [0.0, 0.0, 0.0, 0.0, 0.01, 0.0, 0.0, 0.0, 0.0])]),
        animation("Walk", [("SkitterlingLegL0", "rotation", [0.0, 0.18, 0.36], quat((0.22, 0.0, 0.0)) + quat((-0.22, 0.0, 0.0)) + quat((0.22, 0.0, 0.0)))]),
        animation("Attack", [("SkitterlingMandibleL", "translation", [0.0, 0.2, 0.4], [0.0, 0.42, -1.02, 0.0, 0.42, -1.16, 0.0, 0.42, -1.02])]),
    ]
    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Skitterling asset builder"},
        "scene": 0,
        "scenes": [{"name": "Skitterling", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": "skitterling.scavenger.v1",
            "required_nodes": ["SkitterlingModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "SkitterlingCarapace0", "SkitterlingAntennaL", "SkitterlingMandibleL", "SkitterlingSensoryFan0", "ProductionAssetMarker"],
            "animation_clips": ["Idle", "Walk", "Attack"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
