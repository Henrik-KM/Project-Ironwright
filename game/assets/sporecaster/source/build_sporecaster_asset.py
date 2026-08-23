"""Build the original high-definition Sporecaster organic glTF."""

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


OUTPUT_PATH = SOURCE_DIR / "sporecaster.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Sporecaster wet flesh", "pbrMetallicRoughness": {"baseColorFactor": [0.055, 0.07, 0.075, 1.0], "metallicFactor": 0.12, "roughnessFactor": 0.34}},
        {"name": "Sporecaster shell", "pbrMetallicRoughness": {"baseColorFactor": [0.18, 0.20, 0.18, 1.0], "metallicFactor": 0.15, "roughnessFactor": 0.44}},
        {"name": "Sporecaster membrane", "pbrMetallicRoughness": {"baseColorFactor": [0.18, 0.035, 0.11, 0.88], "metallicFactor": 0.0, "roughnessFactor": 0.36}, "emissiveFactor": [0.05, 0.004, 0.025]},
        {"name": "Sporecaster bone", "pbrMetallicRoughness": {"baseColorFactor": [0.49, 0.42, 0.31, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.57}},
        {"name": "Sporecaster spore eye", "pbrMetallicRoughness": {"baseColorFactor": [0.48, 0.17, 0.025, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.23}, "emissiveFactor": [1.0, 0.16, 0.02]},
        {"name": "Sporecaster tendon", "pbrMetallicRoughness": {"baseColorFactor": [0.32, 0.11, 0.16, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.52}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    flesh, shell, membrane, bone, eye, tendon = range(6)
    mesh_ids = {
        "Core": mesh("Core", add_uv_sphere(builder, 0.58, flesh, 20, 32)),
        "Segment": mesh("Segment", add_uv_sphere(builder, 0.44, shell, 18, 28)),
        "Cowl": mesh("Cowl", add_uv_sphere(builder, 0.38, shell, 20, 32)),
        "Rib": mesh("Rib", add_beveled_box(builder, (1.04, 0.12, 0.22), shell, 0.025)),
        "Gill": mesh("Gill", add_beveled_box(builder, (0.16, 1.25, 0.74), membrane, 0.025)),
        "Sac": mesh("Sac", add_uv_sphere(builder, 0.30, membrane, 20, 32)),
        "Eye": mesh("Eye", add_uv_sphere(builder, 0.085, eye, 16, 24)),
        "Stem": mesh("Stem", add_cylinder(builder, 0.045, 0.54, tendon, 24)),
        "Leg": mesh("Leg", add_cylinder(builder, 0.09, 1.25, tendon, 24)),
        "Talon": mesh("Talon", add_cylinder(builder, 0.055, 0.62, bone, 24)),
        "Spine": mesh("Spine", add_cylinder(builder, 0.075, 0.84, bone, 24)),
        "Fastener": mesh("Fastener", add_uv_sphere(builder, 0.04, bone, 16, 24)),
        "GillRib": mesh("GillRib", add_cylinder(builder, 0.026, 0.86, bone, 24)),
        "SacCap": mesh("SacCap", add_uv_sphere(builder, 0.12, bone, 16, 24)),
    }

    nodes: list[dict] = [{
        "name": "SporecasterModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "sporecaster.infestation.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "gill_fan, spore_sacs, oculi, stalks",
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

    torso = add_node("Torso", extras={"surface": "layered_spore_carapace"})
    add_node("TorsoCore", mesh_ids["Core"], (0.0, 0.72, 0.14), scale=(1.28, 0.84, 1.42), parent=torso, extras={"release_material_family": "flesh"})
    for index in range(3):
        z = -0.55 + index * 0.5
        add_node("TorsoSegment%d" % index, mesh_ids["Segment"], (0.0, 0.77, z), scale=(1.1 - index * 0.04, 0.78, 1.14 - index * 0.05), parent=torso)
        add_node("SporecasterThoraxRib%d" % index, mesh_ids["Rib"], (0.0, 1.13 - index * 0.03, z), rotation=(0.0, 0.0, 0.04), parent=torso)
        add_node("SporecasterFastenerL%d" % index, mesh_ids["Fastener"], (-0.48, 1.02, z), parent=torso)
        add_node("SporecasterFastenerR%d" % index, mesh_ids["Fastener"], (0.48, 1.02, z), parent=torso)
    add_node("OrganicDorsalPlate", mesh_ids["Rib"], (0.0, 1.3, 0.18), scale=(1.25, 1.0, 1.2), extras={"surface": "layered_shell_break"})

    cowl = add_node("SporecasterCowl", mesh_ids["Cowl"], (0.0, 1.18, -0.92), scale=(1.18, 0.9, 1.3), extras={"socket_type": "sensory_cowl"})
    for side in (-1.0, 1.0):
        # Both sensory details follow the cowl shell and therefore use cowl-
        # local offsets rather than repeating the shell's world position.
        add_node("SporecasterOculus%s" % ("L" if side < 0 else "R"), mesh_ids["Eye"], (side * 0.23, 0.16, -0.39), parent=cowl, extras={"socket_type": "spore_eye"})
        add_node("SporecasterCowlPlate%s" % ("L" if side < 0 else "R"), mesh_ids["Rib"], (side * 0.32, 0.08, -0.09), rotation=(0.0, 0.0, side * 0.2), parent=cowl)

    for index in range(7):
        angle = math.pi * (-0.82 + index * 0.273)
        side = -1.0 if index < 3 else (1.0 if index > 3 else 0.0)
        x = side * (0.62 + abs(index - 3) * 0.16)
        z = 0.12 + math.sin(angle) * 0.36
        add_node("SporecasterGillFan%d" % index, mesh_ids["Gill"], (x, 1.25 + abs(index - 3) * 0.08, z), rotation=(0.0, side * 0.16, side * (0.54 - index * 0.08)), scale=(1.0, 0.82 + abs(index - 3) * 0.12, 0.72), extras={"surface": "layered_gill_membrane"})
        add_node("SporecasterGillRib%d" % index, mesh_ids["GillRib"], (x, 1.3 + abs(index - 3) * 0.08, z), rotation=(0.0, side * 0.16, side * (0.54 - index * 0.08)), scale=(0.72, 1.0, 0.82), extras={"surface": "gill_rib"})

    sac_positions = [(-0.62, 1.62, 0.12), (-0.3, 1.8, 0.34), (0.0, 1.92, 0.46), (0.3, 1.8, 0.34), (0.62, 1.62, 0.12)]
    for index, (x, y, z) in enumerate(sac_positions):
        add_node("SporecasterStem%d" % index, mesh_ids["Stem"], (x, y - 0.26, z), rotation=(0.0, 0.0, x * -0.3), extras={"socket_type": "spore_stem"})
        add_node("SporecasterSac%d" % index, mesh_ids["Sac"], (x, y, z), scale=(0.78, 1.18, 0.78), extras={"socket_type": "spore_sac"})
        add_node("SporecasterSacCap%d" % index, mesh_ids["SacCap"], (x, y + 0.22, z - 0.02), scale=(0.9, 0.7, 0.9), extras={"surface": "spore_cap"})
        add_node("SporecasterOculusSac%d" % index, mesh_ids["Eye"], (x, y + 0.23, z - 0.16), extras={"socket_type": "spore_eye"})

    for index in range(6):
        x = -0.78 + index * 0.31
        add_node("SporecasterSpine%d" % index, mesh_ids["Spine"], (x, 1.36, 0.38), rotation=(0.0, 0.0, -0.24 + index * 0.08), extras={"surface": "bone_ridge"})

    for side in (-1.0, 1.0):
        for index in range(3):
            z = -0.5 + index * 0.52
            add_node("SporecasterLeg%s%d" % ("L" if side < 0 else "R", index), mesh_ids["Leg"], (side * (0.58 + index * 0.05), 0.34, z), rotation=(0.0, 0.0, side * 0.72))
            add_node("SporecasterTalon%s%d" % ("L" if side < 0 else "R", index), mesh_ids["Talon"], (side * 0.9, 0.12, z - 0.04), rotation=(0.0, 0.0, side * 0.36))

    add_node("ProductionAssetMarker", None, extras={"asset_contract": "sporecaster.infestation.v1", "source": "original_shared_mesh_builder"})
    node_index = {node["name"]: index for index, node in enumerate(nodes)}

    def animation(name: str, channels: list[tuple[str, str, list[float], list[float]]]) -> dict:
        samplers: list[dict] = []
        entries: list[dict] = []
        types = {"translation": ("VEC3", 3), "rotation": ("VEC4", 4), "scale": ("VEC3", 3)}
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
            ("SporecasterModel", "translation", [0.0, 0.8, 1.6], [0.0, 0.0, 0.0, 0.0, 0.015, 0.0, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.8, 1.6], quat((0.015, 0.0, 0.0)) + quat((-0.015, 0.0, 0.0)) + quat((0.015, 0.0, 0.0))),
        ]),
        animation("Walk", [
            ("SporecasterLegL0", "rotation", [0.0, 0.24, 0.48], quat((0.2, 0.0, 0.0)) + quat((-0.2, 0.0, 0.0)) + quat((0.2, 0.0, 0.0))),
            ("Torso", "rotation", [0.0, 0.24, 0.48], quat((0.04, 0.0, 0.0)) + quat((-0.04, 0.0, 0.0)) + quat((0.04, 0.0, 0.0))),
        ]),
        animation("Attack", [
            ("SporecasterSac2", "scale", [0.0, 0.22, 0.44], [0.78, 1.18, 0.78, 0.96, 1.36, 0.96, 0.78, 1.18, 0.78]),
            ("Torso", "rotation", [0.0, 0.22, 0.44], quat((0.04, 0.0, 0.0)) + quat((-0.08, 0.0, 0.0)) + quat((0.04, 0.0, 0.0))),
        ]),
        animation("Hit", [
            ("SporecasterModel", "translation", [0.0, 0.10, 0.24], [0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((-0.16, 0.08, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Feed", [
            ("SporecasterModel", "translation", [0.0, 0.3, 0.6], [0.0, 0.0, 0.0, 0.0, -0.12, -0.08, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.3, 0.6], quat((0.02, 0.0, 0.0)) + quat((0.16, 0.0, 0.0)) + quat((0.02, 0.0, 0.0))),
        ]),
        animation("Nest", [
            ("SporecasterModel", "translation", [0.0, 0.5, 1.0], [0.0, 0.0, 0.0, 0.0, 0.08, 0.0, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.5, 1.0], quat((0.025, 0.0, 0.0)) + quat((-0.025, 0.0, 0.0)) + quat((0.025, 0.0, 0.0))),
        ]),
        animation("Retreat", [
            ("SporecasterLegL0", "rotation", [0.0, 0.24, 0.48], quat((0.28, 0.0, 0.0)) + quat((-0.16, 0.0, 0.0)) + quat((0.28, 0.0, 0.0))),
            ("Torso", "rotation", [0.0, 0.24, 0.48], quat((0.12, 0.0, 0.0)) + quat((0.22, 0.0, 0.0)) + quat((0.12, 0.0, 0.0))),
        ]),
        animation("Death", [
            ("SporecasterModel", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.34, 0.08, 0.2)) + quat((0.78, 0.16, 0.42))),
            ("Torso", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.18, 0.0, 0.0)) + quat((0.46, 0.0, 0.0))),
        ]),
    ]
    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Sporecaster asset builder"},
        "scene": 0,
        "scenes": [{"name": "Sporecaster", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": "sporecaster.infestation.v1",
            "required_nodes": ["SporecasterModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "SporecasterGillFan0", "SporecasterGillRib0", "SporecasterSac0", "SporecasterSacCap0", "SporecasterStem0", "SporecasterOculusL", "ProductionAssetMarker"],
            "animation_clips": ["Idle", "Walk", "Attack", "Hit", "Feed", "Nest", "Retreat", "Death"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
