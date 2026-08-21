"""Build the original high-definition Broodmass organic glTF."""

from __future__ import annotations

import base64
import json
import sys
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, add_box, add_cylinder, add_uv_sphere, quat  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "broodmass.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Broodmass wet flesh", "pbrMetallicRoughness": {"baseColorFactor": [0.08, 0.045, 0.05, 1.0], "metallicFactor": 0.08, "roughnessFactor": 0.58}},
        {"name": "Broodmass shell", "pbrMetallicRoughness": {"baseColorFactor": [0.12, 0.16, 0.15, 1.0], "metallicFactor": 0.2, "roughnessFactor": 0.36}},
        {"name": "Broodmass membrane", "pbrMetallicRoughness": {"baseColorFactor": [0.16, 0.025, 0.07, 0.86], "metallicFactor": 0.0, "roughnessFactor": 0.4}, "emissiveFactor": [0.045, 0.002, 0.014]},
        {"name": "Broodmass bone", "pbrMetallicRoughness": {"baseColorFactor": [0.43, 0.35, 0.24, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.62}},
        {"name": "Broodmass threat eye", "pbrMetallicRoughness": {"baseColorFactor": [0.36, 0.025, 0.008, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.24}, "emissiveFactor": [1.0, 0.06, 0.008]},
        {"name": "Broodmass tendon", "pbrMetallicRoughness": {"baseColorFactor": [0.26, 0.055, 0.08, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.52}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    flesh, shell, membrane, bone, eye, tendon = range(6)
    mesh_ids = {
        "Core": mesh("Core", add_uv_sphere(builder, 0.74, flesh, 18, 28)),
        "Segment": mesh("Segment", add_uv_sphere(builder, 0.58, shell, 16, 24)),
        "Lobe": mesh("Lobe", add_uv_sphere(builder, 0.42, flesh, 14, 22)),
        "Rib": mesh("Rib", add_box(builder, (1.5, 0.15, 0.24), shell)),
        "Fan": mesh("Fan", add_box(builder, (0.18, 1.4, 0.8), membrane)),
        "Maw": mesh("Maw", add_uv_sphere(builder, 0.44, membrane, 14, 22)),
        "Spine": mesh("Spine", add_cylinder(builder, 0.13, 1.15, bone, 14)),
        "Leg": mesh("Leg", add_cylinder(builder, 0.12, 1.72, tendon, 14)),
        "Hook": mesh("Hook", add_cylinder(builder, 0.075, 0.78, bone, 14)),
        "Eye": mesh("Eye", add_uv_sphere(builder, 0.105, eye, 10, 16)),
        "Tendon": mesh("Tendon", add_cylinder(builder, 0.065, 0.82, tendon, 12)),
        "Fastener": mesh("Fastener", add_uv_sphere(builder, 0.055, bone, 8, 12)),
    }

    nodes: list[dict] = [{
        "name": "BroodmassModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "broodmass.nest.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "lobes, brood_maw, dorsal_fan, crown_spines, tendril_hooks",
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

    torso = add_node("Torso", extras={"surface": "layered_brood_carapace"})
    add_node("TorsoCore", mesh_ids["Core"], (0.0, 0.92, 0.2), scale=(1.42, 0.96, 1.58), parent=torso, extras={"release_material_family": "flesh"})
    for index in range(5):
        z = -0.78 + index * 0.42
        add_node("TorsoSegment%d" % index, mesh_ids["Segment"], (0.0, 0.94, z), scale=(1.34 - index * 0.05, 0.82, 1.28 - index * 0.04), parent=torso)
        add_node("BroodmassThoraxRib%d" % index, mesh_ids["Rib"], (0.0, 1.42 - index * 0.025, z), rotation=(0.0, 0.0, 0.05), parent=torso)
        add_node("BroodmassFastenerL%d" % index, mesh_ids["Fastener"], (-0.75, 1.28, z), parent=torso)
        add_node("BroodmassFastenerR%d" % index, mesh_ids["Fastener"], (0.75, 1.28, z), parent=torso)
    add_node("OrganicDorsalPlate", mesh_ids["Rib"], (-0.15, 1.68, 0.18), scale=(1.3, 0.9, 1.2), extras={"surface": "layered_shell_break"})

    for side in (-1.0, 1.0):
        suffix = "L" if side < 0 else "R"
        add_node("BroodmassLobe%s" % suffix, mesh_ids["Lobe"], (side * 0.78, 1.28, 0.5), scale=(1.32, 0.9, 1.2), extras={"socket_type": "brood_lobe"})
        add_node("BroodmassEye%s" % suffix, mesh_ids["Eye"], (side * 0.35, 1.66, -1.02), extras={"socket_type": "threat_eye"})
        add_node("BroodmassTendon%s" % suffix, mesh_ids["Tendon"], (side * 0.45, 1.0, -1.15), rotation=(0.7, 0.0, side * 0.12))

    maw = add_node("BroodmassMaw", mesh_ids["Maw"], (0.0, 1.16, -1.52), scale=(1.28, 0.75, 1.4), extras={"socket_type": "brood_maw"})
    # Maw hardware is parented to the maw shell; use local offsets so it does
    # not double-apply the shell's world-space position.
    add_node("BroodmassMawPlate", mesh_ids["Rib"], (0.0, 0.24, -0.02), scale=(0.86, 0.82, 1.1), parent=maw)
    for side in (-1.0, 1.0):
        add_node("BroodmassMawHook%s" % ("L" if side < 0 else "R"), mesh_ids["Hook"], (side * 0.34, -0.42, -0.24), rotation=(0.78, 0.0, side * 0.15), parent=maw)

    for index in range(7):
        x = -1.1 + index * 0.367
        add_node("CrownSpine%d" % index, mesh_ids["Spine"], (x, 2.0 + (index % 2) * 0.1, 0.18), rotation=(0.0, 0.0, -0.25 + index * 0.08), extras={"surface": "bone_ridge"})

    for side in (-1.0, 1.0):
        suffix = "L" if side < 0 else "R"
        for index in range(4):
            z = -0.74 + index * 0.5
            add_node("BroodmassLeg%s%d" % (suffix, index), mesh_ids["Leg"], (side * (0.85 + index * 0.06), 0.58, z), rotation=(0.0, 0.0, side * (0.76 - index * 0.06)))
            add_node("BroodmassHook%s%d" % (suffix, index), mesh_ids["Hook"], (side * (1.28 + index * 0.04), 0.14, z - 0.03), rotation=(0.0, 0.0, side * 0.38))
        add_node("BroodmassFan%s" % suffix, mesh_ids["Fan"], (side * 1.28, 1.62, 0.3), rotation=(0.0, side * 0.2, side * 0.08), scale=(0.22, 1.3, 0.86), extras={"surface": "dorsal_membrane"})

    add_node("ProductionAssetMarker", None, extras={"asset_contract": "broodmass.nest.v1", "source": "original_shared_mesh_builder"})
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
        animation("Idle", [("BroodmassModel", "translation", [0.0, 0.9, 1.8], [0.0, 0.0, 0.0, 0.0, 0.018, 0.0, 0.0, 0.0, 0.0])]),
        animation("Walk", [("BroodmassLegL0", "rotation", [0.0, 0.28, 0.56], quat((0.2, 0.0, 0.0)) + quat((-0.2, 0.0, 0.0)) + quat((0.2, 0.0, 0.0)))]),
        animation("Attack", [("BroodmassMaw", "translation", [0.0, 0.26, 0.52], [0.0, 1.16, -1.52, 0.0, 1.16, -1.76, 0.0, 1.16, -1.52])]),
    ]
    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Broodmass asset builder"},
        "scene": 0,
        "scenes": [{"name": "Broodmass", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": "broodmass.nest.v1",
            "required_nodes": ["BroodmassModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "BroodmassLobeL", "BroodmassMaw", "CrownSpine0", "BroodmassFanL", "ProductionAssetMarker"],
            "animation_clips": ["Idle", "Walk", "Attack"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
