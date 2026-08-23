"""Build the original high-definition Burrower organic glTF."""

from __future__ import annotations

import base64
import json
import sys
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, add_beveled_box, add_box, add_cylinder, add_uv_sphere, quat  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "burrower.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Burrower wet shell", "pbrMetallicRoughness": {"baseColorFactor": [0.045, 0.06, 0.064, 1.0], "metallicFactor": 0.22, "roughnessFactor": 0.3}},
        {"name": "Burrower layered plate", "pbrMetallicRoughness": {"baseColorFactor": [0.19, 0.21, 0.19, 1.0], "metallicFactor": 0.16, "roughnessFactor": 0.43}},
        {"name": "Burrower flesh", "pbrMetallicRoughness": {"baseColorFactor": [0.12, 0.035, 0.035, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.72}},
        {"name": "Burrower bone", "pbrMetallicRoughness": {"baseColorFactor": [0.48, 0.4, 0.27, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.6}},
        {"name": "Burrower bore lamp", "pbrMetallicRoughness": {"baseColorFactor": [0.56, 0.16, 0.025, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.2}, "emissiveFactor": [1.0, 0.12, 0.01]},
        {"name": "Burrower tendon", "pbrMetallicRoughness": {"baseColorFactor": [0.3, 0.08, 0.075, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.53}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    wet, shell, flesh, bone, eye, tendon = range(6)
    mesh_ids = {
        "Core": mesh("Core", add_uv_sphere(builder, 0.62, wet, 20, 32)),
        "Segment": mesh("Segment", add_uv_sphere(builder, 0.48, shell, 18, 28)),
        "Drill": mesh("Drill", add_cylinder(builder, 0.25, 0.7, bone, 24)),
        "Ring": mesh("Ring", add_cylinder(builder, 0.3, 0.14, shell, 24)),
        "Tip": mesh("Tip", add_uv_sphere(builder, 0.2, wet, 16, 28)),
        "Jaw": mesh("Jaw", add_cylinder(builder, 0.065, 0.62, bone, 24)),
        "Fin": mesh("Fin", add_beveled_box(builder, (0.12, 0.7, 0.58), shell, 0.022)),
        "Eye": mesh("Eye", add_uv_sphere(builder, 0.08, eye, 16, 24)),
        "Leg": mesh("Leg", add_cylinder(builder, 0.08, 1.15, tendon, 24)),
        "Talon": mesh("Talon", add_cylinder(builder, 0.05, 0.58, bone, 24)),
        "Spine": mesh("Spine", add_cylinder(builder, 0.09, 0.92, bone, 24)),
        "Fastener": mesh("Fastener", add_uv_sphere(builder, 0.04, bone, 16, 24)),
        "DrillFlute": mesh("DrillFlute", add_cylinder(builder, 0.035, 0.56, bone, 24)),
        "LampGuard": mesh("LampGuard", add_beveled_box(builder, (0.18, 0.08, 0.12), shell, 0.018)),
    }

    nodes: list[dict] = [{
        "name": "BurrowerModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "burrower.drill.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "drill, bore_tip, drill_rings, lamps, fins",
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

    torso = add_node("Torso", extras={"surface": "layered_burrow_shell"})
    add_node("TorsoCore", mesh_ids["Core"], (0.0, 0.72, 0.26), scale=(1.42, 0.72, 1.7), parent=torso, extras={"release_material_family": "chitin"})
    for index in range(4):
        z = -0.62 + index * 0.54
        add_node("TorsoSegment%d" % index, mesh_ids["Segment"], (0.0, 0.74, z), scale=(1.24 - index * 0.06, 0.72, 1.32 - index * 0.04), parent=torso)
        add_node("BurrowerThoraxRib%d" % index, mesh_ids["Fin"], (0.0, 1.16, z), rotation=(0.0, 0.0, 0.08), scale=(5.0, 0.64, 1.1), parent=torso)
        add_node("BurrowerFastenerL%d" % index, mesh_ids["Fastener"], (-0.56, 1.04, z), parent=torso)
        add_node("BurrowerFastenerR%d" % index, mesh_ids["Fastener"], (0.56, 1.04, z), parent=torso)
    add_node("OrganicDorsalPlate", mesh_ids["Fin"], (0.0, 1.36, 0.2), scale=(6.0, 0.78, 1.5), extras={"surface": "layered_shell_break"})

    drill_parent = add_node("BurrowerDrillAssembly", translation=(0.0, 0.82, -1.4), extras={"socket_type": "drill_assembly"})
    for index in range(3):
        add_node("BurrowerDrillRing%d" % index, mesh_ids["Ring"], (0.0, 0.0, -index * 0.2), scale=(1.0 - index * 0.12, 1.0, 1.0 - index * 0.12), parent=drill_parent)
        add_node("BurrowerDrillFlute%d" % index, mesh_ids["DrillFlute"], (0.0, 0.0, -0.1 - index * 0.2), rotation=(0.0, 0.0, index * 1.0472), scale=(0.8 - index * 0.08, 1.0, 0.8 - index * 0.08), parent=drill_parent, extras={"surface": "drill_flute"})
    add_node("BurrowerDrill", mesh_ids["Drill"], (0.0, 0.0, -0.45), rotation=(1.5708, 0.0, 0.0), scale=(1.0, 1.0, 1.25), parent=drill_parent, extras={"socket_type": "drill"})
    add_node("BurrowerTip", mesh_ids["Tip"], (0.0, 0.0, -0.84), scale=(1.0, 0.7, 1.3), parent=drill_parent, extras={"socket_type": "bore_tip"})
    for side in (-1.0, 1.0):
        suffix = "L" if side < 0 else "R"
        add_node("BurrowerLamp%s" % suffix, mesh_ids["Eye"], (side * 0.22, 0.17, -0.78), parent=drill_parent, extras={"socket_type": "bore_lamp"})
        add_node("BurrowerLampGuard%s" % suffix, mesh_ids["LampGuard"], (side * 0.22, 0.17, -0.78), rotation=(0.0, side * 0.2, 0.0), parent=drill_parent, extras={"surface": "lamp_guard"})
        add_node("BurrowerJaw%s" % suffix, mesh_ids["Jaw"], (side * 0.25, 0.18, -1.02), rotation=(0.76, 0.0, side * 0.16), extras={"socket_type": "jaw"})

    for index in range(5):
        x = -0.82 + index * 0.41
        add_node("BurrowSpine%d" % index, mesh_ids["Spine"], (x, 1.45, 0.34), rotation=(0.0, 0.0, -0.22 + index * 0.09), extras={"surface": "bone_ridge"})

    for side in (-1.0, 1.0):
        suffix = "L" if side < 0 else "R"
        for index in range(3):
            z = -0.48 + index * 0.54
            add_node("BurrowerLeg%s%d" % (suffix, index), mesh_ids["Leg"], (side * (0.62 + index * 0.05), 0.32, z), rotation=(0.0, 0.0, side * 0.72))
            add_node("BurrowerTalon%s%d" % (suffix, index), mesh_ids["Talon"], (side * 0.92, 0.1, z - 0.04), rotation=(0.0, 0.0, side * 0.36))
        add_node("BurrowerFin%s" % suffix, mesh_ids["Fin"], (side * 1.0, 1.08, 0.2), rotation=(0.0, side * 0.18, side * 0.12), scale=(0.35, 1.1, 0.8), extras={"surface": "side_fan"})

    add_node("ProductionAssetMarker", None, extras={"asset_contract": "burrower.drill.v1", "source": "original_shared_mesh_builder"})
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
            ("BurrowerModel", "translation", [0.0, 0.8, 1.6], [0.0, 0.0, 0.0, 0.0, 0.014, 0.0, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.8, 1.6], quat((0.014, 0.0, 0.0)) + quat((-0.014, 0.0, 0.0)) + quat((0.014, 0.0, 0.0))),
            ("BurrowerLampL", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.05, 0.0)) + quat((0.0, -0.04, 0.0)) + quat((0.0, 0.05, 0.0))),
            ("BurrowerLampR", "rotation", [0.0, 0.8, 1.6], quat((0.0, -0.05, 0.0)) + quat((0.0, 0.04, 0.0)) + quat((0.0, -0.05, 0.0))),
            ("BurrowerFinL", "rotation", [0.0, 0.8, 1.6], quat((0.0, -0.18, -0.12)) + quat((0.0, -0.28, -0.16)) + quat((0.0, -0.18, -0.12))),
            ("BurrowerFinR", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.18, 0.12)) + quat((0.0, 0.28, 0.16)) + quat((0.0, 0.18, 0.12))),
            ("BurrowerDrillRing0", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.22, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Walk", [
            ("BurrowerLegL0", "rotation", [0.0, 0.24, 0.48], quat((0.2, 0.0, 0.0)) + quat((-0.2, 0.0, 0.0)) + quat((0.2, 0.0, 0.0))),
            ("Torso", "rotation", [0.0, 0.24, 0.48], quat((0.045, 0.0, 0.0)) + quat((-0.045, 0.0, 0.0)) + quat((0.045, 0.0, 0.0))),
            ("BurrowerLegR0", "rotation", [0.0, 0.24, 0.48], quat((-0.16, 0.0, 0.0)) + quat((0.24, 0.0, 0.0)) + quat((-0.16, 0.0, 0.0))),
            ("BurrowerFinL", "rotation", [0.0, 0.24, 0.48], quat((0.0, -0.18, -0.12)) + quat((0.0, -0.34, -0.2)) + quat((0.0, -0.18, -0.12))),
            ("BurrowerFinR", "rotation", [0.0, 0.24, 0.48], quat((0.0, 0.18, 0.12)) + quat((0.0, 0.34, 0.2)) + quat((0.0, 0.18, 0.12))),
            ("BurrowerDrillFlute0", "rotation", [0.0, 0.24, 0.48], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.6, 0.0)) + quat((0.0, 1.1, 0.0))),
        ]),
        animation("Attack", [
            ("BurrowerDrillAssembly", "translation", [0.0, 0.22, 0.44], [0.0, 0.82, -1.4, 0.0, 0.82, -1.68, 0.0, 0.82, -1.4]),
            ("Torso", "rotation", [0.0, 0.22, 0.44], quat((0.04, 0.0, 0.0)) + quat((-0.11, 0.0, 0.0)) + quat((0.04, 0.0, 0.0))),
            ("BurrowerLampL", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.24, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("BurrowerLampR", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.0, 0.0)) + quat((0.0, -0.24, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("BurrowerJawL", "rotation", [0.0, 0.22, 0.44], quat((0.76, 0.0, 0.16)) + quat((0.52, 0.0, 0.3)) + quat((0.76, 0.0, 0.16))),
            ("BurrowerJawR", "rotation", [0.0, 0.22, 0.44], quat((0.76, 0.0, -0.16)) + quat((0.52, 0.0, -0.3)) + quat((0.76, 0.0, -0.16))),
        ]),
        animation("Hit", [
            ("BurrowerModel", "translation", [0.0, 0.10, 0.24], [0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((-0.16, 0.08, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("BurrowerLampL", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.24)) + quat((0.0, 0.0, 0.0))),
            ("BurrowerLampR", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, -0.24)) + quat((0.0, 0.0, 0.0))),
            ("BurrowerDrillRing1", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((0.18, 0.0, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Feed", [
            ("BurrowerModel", "translation", [0.0, 0.3, 0.6], [0.0, 0.0, 0.0, 0.0, -0.12, -0.08, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.3, 0.6], quat((0.02, 0.0, 0.0)) + quat((0.16, 0.0, 0.0)) + quat((0.02, 0.0, 0.0))),
            ("BurrowerJawL", "rotation", [0.0, 0.3, 0.6], quat((0.76, 0.0, 0.16)) + quat((0.98, 0.0, 0.16)) + quat((0.76, 0.0, 0.16))),
            ("BurrowerJawR", "rotation", [0.0, 0.3, 0.6], quat((0.76, 0.0, -0.16)) + quat((0.98, 0.0, -0.16)) + quat((0.76, 0.0, -0.16))),
            ("BurrowerLampL", "rotation", [0.0, 0.3, 0.6], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.12, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Nest", [
            ("BurrowerModel", "translation", [0.0, 0.5, 1.0], [0.0, 0.0, 0.0, 0.0, 0.08, 0.0, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.5, 1.0], quat((0.025, 0.0, 0.0)) + quat((-0.025, 0.0, 0.0)) + quat((0.025, 0.0, 0.0))),
            ("BurrowerFinL", "rotation", [0.0, 0.5, 1.0], quat((0.0, -0.18, -0.12)) + quat((0.0, -0.08, -0.08)) + quat((0.0, -0.18, -0.12))),
            ("BurrowerFinR", "rotation", [0.0, 0.5, 1.0], quat((0.0, 0.18, 0.12)) + quat((0.0, 0.08, 0.08)) + quat((0.0, 0.18, 0.12))),
            ("BurrowerDrillRing0", "rotation", [0.0, 0.5, 1.0], quat((0.0, 0.0, 0.0)) + quat((0.0, -0.14, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Retreat", [
            ("BurrowerLegL0", "rotation", [0.0, 0.24, 0.48], quat((0.28, 0.0, 0.0)) + quat((-0.16, 0.0, 0.0)) + quat((0.28, 0.0, 0.0))),
            ("Torso", "rotation", [0.0, 0.24, 0.48], quat((0.12, 0.0, 0.0)) + quat((0.22, 0.0, 0.0)) + quat((0.12, 0.0, 0.0))),
            ("BurrowerLegR0", "rotation", [0.0, 0.24, 0.48], quat((-0.16, 0.0, 0.0)) + quat((0.28, 0.0, 0.0)) + quat((-0.16, 0.0, 0.0))),
            ("BurrowerFinL", "rotation", [0.0, 0.24, 0.48], quat((0.0, -0.18, -0.12)) + quat((0.0, -0.38, -0.2)) + quat((0.0, -0.18, -0.12))),
            ("BurrowerFinR", "rotation", [0.0, 0.24, 0.48], quat((0.0, 0.18, 0.12)) + quat((0.0, 0.38, 0.2)) + quat((0.0, 0.18, 0.12))),
        ]),
        animation("Death", [
            ("BurrowerModel", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.34, 0.08, 0.2)) + quat((0.78, 0.16, 0.42))),
            ("Torso", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.18, 0.0, 0.0)) + quat((0.46, 0.0, 0.0))),
            ("BurrowerDrillAssembly", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.26, 0.0)) + quat((0.0, 0.56, 0.0))),
            ("BurrowerLampL", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.2)) + quat((0.0, 0.0, 0.42))),
        ]),
    ]
    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Burrower asset builder"},
        "scene": 0,
        "scenes": [{"name": "Burrower", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": "burrower.drill.v1",
            "required_nodes": ["BurrowerModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "BurrowerDrill", "BurrowerTip", "BurrowerDrillRing0", "BurrowerDrillFlute0", "BurrowerLampL", "BurrowerLampGuardL", "ProductionAssetMarker"],
            "animation_clips": ["Idle", "Walk", "Attack", "Hit", "Feed", "Nest", "Retreat", "Death"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
