"""Build the original high-definition Veilstalker organic glTF.

The mesh is intentionally assembled from deterministic primitives so it stays
reviewable and dependency-free while presenting a more authored silhouette than
the runtime fallback. Gameplay, collision and ecology remain in GDScript.
"""

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


OUTPUT_PATH = SOURCE_DIR / "veilstalker.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Veilstalker wet chitin", "pbrMetallicRoughness": {"baseColorFactor": [0.055, 0.035, 0.045, 1.0], "metallicFactor": 0.22, "roughnessFactor": 0.28}},
        {"name": "Veilstalker shell ridge", "pbrMetallicRoughness": {"baseColorFactor": [0.16, 0.08, 0.10, 1.0], "metallicFactor": 0.12, "roughnessFactor": 0.42}},
        {"name": "Veilstalker deep flesh", "pbrMetallicRoughness": {"baseColorFactor": [0.10, 0.025, 0.035, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.72}},
        {"name": "Veilstalker bone hooks", "pbrMetallicRoughness": {"baseColorFactor": [0.38, 0.29, 0.23, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.62}},
        {"name": "Veilstalker membrane", "pbrMetallicRoughness": {"baseColorFactor": [0.22, 0.018, 0.065, 0.82], "metallicFactor": 0.0, "roughnessFactor": 0.5}, "alphaMode": "BLEND", "emissiveFactor": [0.16, 0.01, 0.025]},
        {"name": "Veilstalker threat eyes", "pbrMetallicRoughness": {"baseColorFactor": [0.24, 0.018, 0.008, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.3}, "emissiveFactor": [1.0, 0.05, 0.012]},
        {"name": "Veilstalker tendon", "pbrMetallicRoughness": {"baseColorFactor": [0.28, 0.06, 0.08, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.55}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({
            "name": name,
            "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}],
        })
        return len(meshes) - 1

    wet, shell, flesh, bone, membrane, eye, tendon = range(7)
    mesh_ids = {
        "Core": mesh("ThoraxCore", add_uv_sphere(builder, 0.62, wet, 20, 32)),
        "Segment": mesh("ThoraxSegment", add_uv_sphere(builder, 0.5, shell, 16, 28)),
        "Rib": mesh("ThoraxRib", add_beveled_box(builder, (1.38, 0.13, 0.18), shell, 0.028)),
        "Abdomen": mesh("Abdomen", add_uv_sphere(builder, 0.48, flesh, 16, 28)),
        "Head": mesh("Cowl", add_uv_sphere(builder, 0.48, shell, 16, 28)),
        "Eye": mesh("ThreatEye", add_uv_sphere(builder, 0.09, eye, 16, 24)),
        "Plate": mesh("DorsalPlate", add_beveled_box(builder, (1.25, 0.16, 0.46), shell, 0.035)),
        "Spine": mesh("DorsalSpine", add_cylinder(builder, 0.09, 0.58, bone, 24)),
        "Veil": mesh("VeilMembrane", add_uv_sphere(builder, 0.34, membrane, 16, 28)),
        "Limb": mesh("Forelimb", add_cylinder(builder, 0.075, 1.35, tendon, 24)),
        "Hook": mesh("Hook", add_cylinder(builder, 0.06, 0.9, bone, 24)),
        "Tendril": mesh("Tendril", add_cylinder(builder, 0.035, 0.8, tendon, 24)),
        "Tail": mesh("Tail", add_uv_sphere(builder, 0.19, flesh, 16, 24)),
        "Fastener": mesh("ShellFastener", add_uv_sphere(builder, 0.045, eye, 16, 24)),
    }

    nodes: list[dict] = [{
        "name": "VeilstalkerModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "veilstalker.predator.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "sensory_cowl, veil_membranes, tendrils, attack_hooks",
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

    torso = add_node("Torso", None, (0.0, 0.0, 0.0), extras={"surface": "layered_wet_chitin"})
    add_node("TorsoCore", mesh_ids["Core"], (0.0, 0.92, -0.12), parent=torso, extras={"release_material_family": "chitin"})
    for index in range(4):
        z = -0.72 + index * 0.44
        add_node("TorsoSegment%d" % index, mesh_ids["Segment"], (0.0, 0.91 - index * 0.015, z), parent=torso)
        add_node("VeilstalkerThoraxDorsalRib", mesh_ids["Rib"], (0.0, 1.42 - index * 0.045, z), rotation=(0.0, 0.0, 0.0), parent=torso)
        add_node("ThoraxFastener", mesh_ids["Fastener"], (-0.58, 1.28 - index * 0.02, z - 0.08), parent=torso)
        add_node("ThoraxFastener", mesh_ids["Fastener"], (0.58, 1.28 - index * 0.02, z - 0.08), parent=torso)
    add_node("VeilstalkerAbdomen", mesh_ids["Abdomen"], (-0.22, 1.06, 0.84))
    add_node("VeilstalkerCowl", mesh_ids["Head"], (0.0, 1.38, -1.02), extras={"socket_type": "sensory_cowl"})
    for side in (-1.0, 1.0):
        add_node("VeilstalkerEye", mesh_ids["Eye"], (side * 0.27, 1.48, -1.37), extras={"socket_type": "threat_eye"})
        add_node("VeilstalkerVeil", mesh_ids["Veil"], (side * 0.98, 1.08, -0.16), rotation=(0.0, side * 0.08, side * 0.11), extras={"socket_type": "attack_membrane"})
        add_node("VeilstalkerForelimb", mesh_ids["Limb"], (side * 0.78, 0.72, -0.62), rotation=(0.0, 0.0, side * 0.34))
        add_node("VeilstalkerHook", mesh_ids["Hook"], (side * 0.93, 0.22, -1.02), rotation=(0.58, 0.0, side * 0.2), extras={"socket_type": "attack_hook"})
    for index in range(3):
        plate_z = -0.68 + index * 0.44
        add_node("VeilstalkerDorsalPlate", mesh_ids["Plate"], (0.0, 1.58 - index * 0.05, plate_z), rotation=(0.0, 0.0, 0.03 * (index - 1)))
        add_node("VeilstalkerDorsalSpine", mesh_ids["Spine"], (0.0, 1.78 - index * 0.03, plate_z + 0.04), rotation=(0.0, 0.0, 0.16 * (index - 1)))
    add_node("OrganicDorsalPlate", mesh_ids["Plate"], (0.0, 1.5, 0.2), rotation=(0.0, 0.0, -0.03), extras={"surface": "layered_shell_break"})
    for index in range(3):
        side = -1.0 if index % 2 == 0 else 1.0
        add_node("VeilstalkerTendril", mesh_ids["Tendril"], (side * (0.16 + index * 0.08), 1.12, -1.52 - index * 0.05), rotation=(0.55, 0.0, side * 0.18), extras={"socket_type": "sensory_tendril"})
    for index in range(3):
        add_node("VeilstalkerTail", mesh_ids["Tail"], (-0.22 + index * 0.08, 0.98 - index * 0.06, 0.72 + index * 0.38))
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "veilstalker.predator.v1", "source": "original_shared_mesh_builder"})

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
            ("VeilstalkerModel", "translation", [0.0, 0.8, 1.6], [0.0, 0.0, 0.0, 0.0, 0.018, 0.0, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.8, 1.6], quat((0.012, 0.0, 0.0)) + quat((-0.012, 0.0, 0.0)) + quat((0.012, 0.0, 0.0))),
        ]),
        animation("Walk", [
            ("TorsoSegment0", "rotation", [0.0, 0.22, 0.44], quat((0.12, 0.0, 0.0)) + quat((-0.12, 0.0, 0.0)) + quat((0.12, 0.0, 0.0))),
            ("Torso", "rotation", [0.0, 0.22, 0.44], quat((0.05, 0.0, 0.0)) + quat((-0.05, 0.0, 0.0)) + quat((0.05, 0.0, 0.0))),
        ]),
        animation("Attack", [
            ("VeilstalkerVeil", "rotation", [0.0, 0.34, 0.68], quat((0.0, 0.0, -0.16)) + quat((0.0, 0.0, 0.12)) + quat((0.0, 0.0, -0.16))),
            ("Torso", "rotation", [0.0, 0.34, 0.68], quat((0.04, 0.0, 0.0)) + quat((-0.1, 0.0, 0.0)) + quat((0.04, 0.0, 0.0))),
        ]),
        animation("Hit", [
            ("VeilstalkerModel", "translation", [0.0, 0.10, 0.24], [0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((-0.16, 0.08, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Feed", [
            ("VeilstalkerModel", "translation", [0.0, 0.3, 0.6], [0.0, 0.0, 0.0, 0.0, -0.12, -0.08, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.3, 0.6], quat((0.02, 0.0, 0.0)) + quat((0.16, 0.0, 0.0)) + quat((0.02, 0.0, 0.0))),
        ]),
        animation("Nest", [
            ("VeilstalkerModel", "translation", [0.0, 0.5, 1.0], [0.0, 0.0, 0.0, 0.0, 0.08, 0.0, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.5, 1.0], quat((0.025, 0.0, 0.0)) + quat((-0.025, 0.0, 0.0)) + quat((0.025, 0.0, 0.0))),
        ]),
        animation("Retreat", [
            ("TorsoSegment0", "rotation", [0.0, 0.22, 0.44], quat((0.28, 0.0, 0.0)) + quat((-0.16, 0.0, 0.0)) + quat((0.28, 0.0, 0.0))),
            ("Torso", "rotation", [0.0, 0.22, 0.44], quat((0.12, 0.0, 0.0)) + quat((0.22, 0.0, 0.0)) + quat((0.12, 0.0, 0.0))),
        ]),
        animation("Death", [
            ("VeilstalkerModel", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.34, 0.08, 0.2)) + quat((0.78, 0.16, 0.42))),
            ("Torso", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.18, 0.0, 0.0)) + quat((0.46, 0.0, 0.0))),
        ]),
    ]

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Veilstalker asset builder"},
        "scene": 0,
        "scenes": [{"name": "Veilstalker", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": "veilstalker.predator.v1",
            "required_nodes": ["VeilstalkerModel", "Torso", "TorsoCore", "VeilstalkerCowl", "VeilstalkerVeil", "VeilstalkerTendril", "VeilstalkerThoraxDorsalRib", "ProductionAssetMarker"],
            "animation_clips": ["Idle", "Walk", "Attack", "Hit", "Feed", "Nest", "Retreat", "Death"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
