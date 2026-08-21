"""Build the original high-definition Razorhound organic glTF."""

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


OUTPUT_PATH = SOURCE_DIR / "razorhound.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Razorhound wet chitin", "pbrMetallicRoughness": {"baseColorFactor": [0.045, 0.06, 0.068, 1.0], "metallicFactor": 0.2, "roughnessFactor": 0.3}},
        {"name": "Razorhound shell ridge", "pbrMetallicRoughness": {"baseColorFactor": [0.16, 0.19, 0.19, 1.0], "metallicFactor": 0.16, "roughnessFactor": 0.42}},
        {"name": "Razorhound flesh", "pbrMetallicRoughness": {"baseColorFactor": [0.12, 0.04, 0.035, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.74}},
        {"name": "Razorhound bone", "pbrMetallicRoughness": {"baseColorFactor": [0.42, 0.38, 0.3, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.6}},
        {"name": "Razorhound threat eye", "pbrMetallicRoughness": {"baseColorFactor": [0.3, 0.03, 0.008, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.28}, "emissiveFactor": [1.0, 0.06, 0.01]},
        {"name": "Razorhound tendon", "pbrMetallicRoughness": {"baseColorFactor": [0.26, 0.08, 0.07, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.55}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    wet, shell, flesh, bone, eye, tendon = range(6)
    mesh_ids = {
        "Core": mesh("Core", add_uv_sphere(builder, 0.5, wet, 12, 22)),
        "Segment": mesh("Segment", add_uv_sphere(builder, 0.42, shell, 10, 18)),
        "Rib": mesh("Rib", add_box(builder, (1.08, 0.12, 0.18), shell)),
        "Head": mesh("Head", add_uv_sphere(builder, 0.34, wet, 11, 20)),
        "Snout": mesh("Snout", add_uv_sphere(builder, 0.33, shell, 10, 18)),
        "Cheek": mesh("Cheek", add_box(builder, (0.18, 0.34, 0.7), shell)),
        "Ear": mesh("Ear", add_uv_sphere(builder, 0.16, bone, 8, 14)),
        "Eye": mesh("Eye", add_uv_sphere(builder, 0.07, eye, 8, 12)),
        "Fang": mesh("Fang", add_cylinder(builder, 0.052, 0.62, bone, 12)),
        "Spine": mesh("Spine", add_cylinder(builder, 0.06, 0.72, bone, 12)),
        "Leg": mesh("Leg", add_cylinder(builder, 0.08, 1.12, tendon, 12)),
        "Talon": mesh("Talon", add_cylinder(builder, 0.055, 0.62, bone, 12)),
        "Tail": mesh("Tail", add_cylinder(builder, 0.075, 1.2, tendon, 12)),
        "Fastener": mesh("Fastener", add_uv_sphere(builder, 0.04, bone, 6, 10)),
    }

    nodes: list[dict] = [{"name": "RazorhoundModel", "children": [], "extras": {"ironwright_asset_id": "razorhound.predator.v1", "asset_quality": "authored_high_definition", "socket_contract": "snout, cheek_plates, fangs, spine_tail"}}]

    def add_node(name: str, mesh_id: int | None = None, translation: Sequence[float] = (0.0, 0.0, 0.0), rotation: Sequence[float] = (0.0, 0.0, 0.0), extras: dict | None = None, parent: int = 0) -> int:
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

    torso = add_node("Torso", extras={"surface": "layered_wet_chitin"})
    add_node("TorsoCore", mesh_ids["Core"], (0.0, 0.58, 0.18), parent=torso, extras={"release_material_family": "chitin"})
    for index in range(3):
        z = -0.42 + index * 0.46
        add_node("TorsoSegment%d" % index, mesh_ids["Segment"], (0.0, 0.58, z), parent=torso)
        add_node("RazorhoundThoraxRib", mesh_ids["Rib"], (0.0, 0.96, z), parent=torso)
        add_node("ThoraxFastener", mesh_ids["Fastener"], (-0.45, 0.84, z), parent=torso)
        add_node("ThoraxFastener", mesh_ids["Fastener"], (0.45, 0.84, z), parent=torso)
    add_node("RazorhoundHead", mesh_ids["Head"], (0.0, 0.84, -0.82))
    add_node("RazorhoundSnout", mesh_ids["Snout"], (0.0, 0.78, -1.18), extras={"socket_type": "snout"})
    add_node("OrganicDorsalPlate", mesh_ids["Rib"], (0.0, 1.04, 0.16), rotation=(0.0, 0.0, 0.05), extras={"surface": "layered_shell_break"})
    for side in (-1.0, 1.0):
        add_node("RazorhoundCheekPlate", mesh_ids["Cheek"], (side * 0.44, 0.82, -0.94))
        add_node("RazorhoundEar", mesh_ids["Ear"], (side * 0.28, 1.14, -0.9), rotation=(0.0, 0.0, side * 0.28))
        add_node("RazorhoundEye", mesh_ids["Eye"], (side * 0.2, 1.02, -1.27), extras={"socket_type": "threat_eye"})
        add_node("RazorhoundFang", mesh_ids["Fang"], (side * 0.17, 0.54, -1.45), rotation=(0.78, 0.0, side * 0.1))
    for index in range(4):
        z = -0.5 + index * 0.38
        add_node("RazorhoundSpine", mesh_ids["Spine"], (0.0, 1.18 + (index % 2) * 0.08, z), rotation=(0.0, 0.0, -0.18 + index * 0.11))
    for index in range(3):
        z = -0.58 + index * 0.56
        for side in (-1.0, 1.0):
            add_node("RazorhoundLeg", mesh_ids["Leg"], (side * 0.55, 0.4, z), rotation=(0.0, 0.0, side * 0.74))
            add_node("RazorhoundTalon", mesh_ids["Talon"], (side * 0.86, 0.14, z - 0.04), rotation=(0.0, 0.0, side * 0.42))
    add_node("RazorhoundTail", mesh_ids["Tail"], (0.0, 0.64, 1.12), rotation=(-0.42, 0.0, 0.0), extras={"socket_type": "tail"})
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "razorhound.predator.v1", "source": "original_shared_mesh_builder"})

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
            ("RazorhoundModel", "translation", [0.0, 0.8, 1.6], [0.0, 0.0, 0.0, 0.0, 0.014, 0.0, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.8, 1.6], quat((0.012, 0.0, 0.0)) + quat((-0.012, 0.0, 0.0)) + quat((0.012, 0.0, 0.0))),
        ]),
        animation("Walk", [
            ("RazorhoundLeg", "rotation", [0.0, 0.22, 0.44], quat((0.22, 0.0, 0.0)) + quat((-0.22, 0.0, 0.0)) + quat((0.22, 0.0, 0.0))),
            ("Torso", "rotation", [0.0, 0.22, 0.44], quat((0.05, 0.0, 0.0)) + quat((-0.05, 0.0, 0.0)) + quat((0.05, 0.0, 0.0))),
        ]),
        animation("Attack", [
            ("RazorhoundSnout", "translation", [0.0, 0.24, 0.48], [0.0, 0.78, -1.18, 0.0, 0.75, -1.3, 0.0, 0.78, -1.18]),
            ("Torso", "rotation", [0.0, 0.24, 0.48], quat((0.05, 0.0, 0.0)) + quat((-0.12, 0.0, 0.0)) + quat((0.05, 0.0, 0.0))),
        ]),
        animation("Hit", [
            ("RazorhoundModel", "translation", [0.0, 0.10, 0.24], [0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((-0.16, 0.08, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Feed", [
            ("RazorhoundModel", "translation", [0.0, 0.3, 0.6], [0.0, 0.0, 0.0, 0.0, -0.12, -0.08, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.3, 0.6], quat((0.02, 0.0, 0.0)) + quat((0.16, 0.0, 0.0)) + quat((0.02, 0.0, 0.0))),
        ]),
        animation("Nest", [
            ("RazorhoundModel", "translation", [0.0, 0.5, 1.0], [0.0, 0.0, 0.0, 0.0, 0.08, 0.0, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.5, 1.0], quat((0.025, 0.0, 0.0)) + quat((-0.025, 0.0, 0.0)) + quat((0.025, 0.0, 0.0))),
        ]),
        animation("Retreat", [
            ("RazorhoundLeg", "rotation", [0.0, 0.22, 0.44], quat((0.28, 0.0, 0.0)) + quat((-0.16, 0.0, 0.0)) + quat((0.28, 0.0, 0.0))),
            ("Torso", "rotation", [0.0, 0.22, 0.44], quat((0.12, 0.0, 0.0)) + quat((0.22, 0.0, 0.0)) + quat((0.12, 0.0, 0.0))),
        ]),
        animation("Death", [
            ("RazorhoundModel", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.34, 0.08, 0.2)) + quat((0.78, 0.16, 0.42))),
            ("Torso", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.18, 0.0, 0.0)) + quat((0.46, 0.0, 0.0))),
        ]),
    ]
    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Razorhound asset builder"},
        "scene": 0, "scenes": [{"name": "Razorhound", "nodes": [0]}], "nodes": nodes, "meshes": meshes, "materials": materials,
        "accessors": builder.accessors, "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {"ironwright_asset_id": "razorhound.predator.v1", "required_nodes": ["RazorhoundModel", "Torso", "TorsoCore", "RazorhoundSnout", "RazorhoundCheekPlate", "RazorhoundFang", "RazorhoundSpine", "RazorhoundTail", "ProductionAssetMarker"], "animation_clips": ["Idle", "Walk", "Attack", "Hit", "Feed", "Nest", "Retreat", "Death"]},
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
