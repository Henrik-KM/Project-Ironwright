"""Build the original high-definition Cistern Apex organic glTF."""

from __future__ import annotations

import base64
import json
import math
import sys
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, _geometry, add_box, add_cylinder, add_uv_sphere, quat  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "apex.gltf"


def add_tapered_cylinder(
    builder: BufferBuilder,
    bottom_radius: float,
    top_radius: float,
    height: float,
    material: int,
    sides: int = 32,
) -> tuple[int, int, int, int]:
    """Build a smooth pointed crown thorn for the final organic silhouette."""
    sides = max(sides, 24)
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []
    bottom = len(positions) // 3
    slope = (bottom_radius - top_radius) / max(height, 0.001)
    for y, radius in ((-height * 0.5, bottom_radius), (height * 0.5, top_radius)):
        for side in range(sides):
            angle = math.tau * side / sides
            positions.extend([math.cos(angle) * radius, y, math.sin(angle) * radius])
            normal = [math.cos(angle), slope, math.sin(angle)]
            length = math.sqrt(sum(value * value for value in normal)) or 1.0
            normals.extend(value / length for value in normal)
    for side in range(sides):
        next_side = (side + 1) % sides
        indices.extend([
            bottom + side,
            bottom + next_side,
            bottom + sides + next_side,
            bottom + side,
            bottom + sides + next_side,
            bottom + sides + side,
        ])
    bottom_center = len(positions) // 3
    positions.extend([0.0, -height * 0.5, 0.0])
    normals.extend([0.0, -1.0, 0.0])
    top_center = len(positions) // 3
    positions.extend([0.0, height * 0.5, 0.0])
    normals.extend([0.0, 1.0, 0.0])
    for side in range(sides):
        next_side = (side + 1) % sides
        indices.extend([bottom_center, bottom + next_side, bottom + side])
        indices.extend([top_center, bottom + sides + side, bottom + sides + next_side])
    return _geometry(builder, positions, normals, indices, material)


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Apex wet carapace", "pbrMetallicRoughness": {"baseColorFactor": [0.035, 0.045, 0.055, 1.0], "metallicFactor": 0.24, "roughnessFactor": 0.28}},
        {"name": "Apex layered shell", "pbrMetallicRoughness": {"baseColorFactor": [0.17, 0.20, 0.20, 1.0], "metallicFactor": 0.18, "roughnessFactor": 0.4}},
        {"name": "Apex deep flesh", "pbrMetallicRoughness": {"baseColorFactor": [0.16, 0.035, 0.045, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.7}},
        {"name": "Apex bone", "pbrMetallicRoughness": {"baseColorFactor": [0.48, 0.40, 0.29, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.56}},
        {"name": "Apex membrane", "pbrMetallicRoughness": {"baseColorFactor": [0.12, 0.012, 0.028, 0.92], "metallicFactor": 0.0, "roughnessFactor": 0.42}, "emissiveFactor": [0.035, 0.002, 0.006]},
        {"name": "Apex threat eye", "pbrMetallicRoughness": {"baseColorFactor": [0.42, 0.02, 0.006, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.2}, "emissiveFactor": [1.0, 0.05, 0.008]},
        {"name": "Apex tendon", "pbrMetallicRoughness": {"baseColorFactor": [0.34, 0.08, 0.10, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.5}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    wet, shell, flesh, bone, membrane, eye, tendon = range(7)
    mesh_ids = {
        "Core": mesh("Core", add_uv_sphere(builder, 0.88, wet, 24, 36)),
        # The late-game threat is inspected at the same close tactical scale
        # as the other authored families. Spend the extra geometry on the
        # wet segment silhouette, crown and jaw hardware instead of leaving
        # the final creature visibly faceted beside the shared family kit.
        "Segment": mesh("Segment", add_uv_sphere(builder, 0.68, shell, 24, 32)),
        "Crown": mesh("Crown", add_uv_sphere(builder, 0.62, shell, 24, 36)),
        "Jaw": mesh("Jaw", add_cylinder(builder, 0.13, 1.35, bone, 32)),
        "JawPlate": mesh("JawPlate", add_box(builder, (0.32, 0.18, 0.92), bone)),
        "Rib": mesh("Rib", add_box(builder, (1.52, 0.14, 0.24), shell)),
        "Leg": mesh("Leg", add_cylinder(builder, 0.12, 1.72, tendon, 32)),
        "Talon": mesh("Talon", add_cylinder(builder, 0.075, 0.82, bone, 32)),
        # The final threat's crown should terminate in organic thorns, not a
        # repeated row of identical cylindrical bars at approach distance.
        "Spine": mesh("Spine", add_tapered_cylinder(builder, 0.13, 0.022, 1.04, bone, 32)),
        "Membrane": mesh("Membrane", add_uv_sphere(builder, 0.58, membrane, 24, 32)),
        "Root": mesh("Root", add_cylinder(builder, 0.2, 1.3, tendon, 32)),
        "Eye": mesh("Eye", add_uv_sphere(builder, 0.11, eye, 24, 32)),
        "Fastener": mesh("Fastener", add_uv_sphere(builder, 0.055, bone, 24, 32)),
        "CrownRidge": mesh("CrownRidge", add_cylinder(builder, 0.06, 1.08, bone, 32)),
        "JawLatch": mesh("JawLatch", add_box(builder, (0.20, 0.10, 0.44), bone)),
        "MembraneRib": mesh("MembraneRib", add_cylinder(builder, 0.035, 0.82, bone, 32)),
    }

    nodes: list[dict] = [{
        "name": "ApexModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "apex.cistern.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "crown, jaw, dorsal_membrane, flank_roots, threat_eyes",
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

    torso = add_node("Torso", extras={"surface": "layered_cistern_carapace"})
    add_node("TorsoCore", mesh_ids["Core"], (0.0, 1.02, 0.22), scale=(1.28, 0.86, 1.46), parent=torso, extras={"release_material_family": "chitin"})
    for index in range(5):
        z = -0.86 + index * 0.44
        add_node("TorsoSegment%d" % index, mesh_ids["Segment"], (0.0, 1.03, z), scale=(1.18 - index * 0.05, 0.78, 1.18 - index * 0.04), parent=torso)
        add_node("ApexThoraxRib%d" % index, mesh_ids["Rib"], (0.0, 1.48 - index * 0.025, z), rotation=(0.0, 0.0, 0.06), parent=torso)
        add_node("ApexFastenerL%d" % index, mesh_ids["Fastener"], (-0.68, 1.32, z), parent=torso)
        add_node("ApexFastenerR%d" % index, mesh_ids["Fastener"], (0.68, 1.32, z), parent=torso)

    crown = add_node("ApexCrown", mesh_ids["Crown"], (0.0, 2.0, -1.02), scale=(1.34, 0.92, 1.22), extras={"socket_type": "crown"})
    # The plate is authored under the crown; keep its offset local so the
    # layered threat silhouette stays attached to the moving head assembly.
    add_node("ApexCrownPlate", mesh_ids["Rib"], (0.0, 0.3, 0.16), scale=(1.2, 1.0, 0.8), parent=crown)
    for side in (-1.0, 1.0):
        suffix = "L" if side < 0 else "R"
        add_node(
            "ApexCrownRidge%s" % suffix,
            mesh_ids["CrownRidge"],
            (side * 0.34, 0.34, 0.18),
            rotation=(0.0, side * 0.18, side * 0.26),
            scale=(0.72, 1.0, 0.82),
            parent=crown,
            extras={"surface": "crown_ridge"},
        )
        add_node(
            "ApexCrownFastener%s" % suffix,
            mesh_ids["Fastener"],
            (side * 0.48, 0.20, 0.12),
            parent=crown,
            extras={"surface": "crown_socket"},
        )
    add_node("OrganicDorsalPlate", mesh_ids["Rib"], (0.0, 1.74, 0.18), scale=(1.25, 0.9, 1.1), extras={"surface": "layered_shell_break"})
    for side in (-1.0, 1.0):
        add_node("ApexEye%s" % ("L" if side < 0 else "R"), mesh_ids["Eye"], (side * 0.34, 2.16, -1.62), extras={"socket_type": "threat_eye"})
        add_node("ApexCheek%s" % ("L" if side < 0 else "R"), mesh_ids["JawPlate"], (side * 0.64, 1.72, -1.15), rotation=(0.0, 0.0, side * 0.18))
        add_node("ApexJaw%s" % ("L" if side < 0 else "R"), mesh_ids["Jaw"], (side * 0.42, 1.15, -1.78), rotation=(0.82, 0.0, side * 0.12), extras={"socket_type": "jaw"})
        add_node(
            "ApexJawLatch%s" % ("L" if side < 0 else "R"),
            mesh_ids["JawLatch"],
            (side * 0.56, 1.16, -1.95),
            rotation=(0.82, 0.0, side * 0.12),
            extras={"surface": "jaw_hardware"},
        )

    for index in range(9):
        x = -1.35 + index * 0.3375
        add_node("ApexSpine%d" % index, mesh_ids["Spine"], (x, 2.0 + (index % 3) * 0.08, 0.14), rotation=(0.0, 0.0, -0.28 + index * 0.07), extras={"surface": "bone_ridge"})

    for side in (-1.0, 1.0):
        for index in range(4):
            z = -0.72 + index * 0.54
            add_node("ApexLeg%s%d" % ("L" if side < 0 else "R", index), mesh_ids["Leg"], (side * (0.8 + index * 0.06), 0.7, z), rotation=(0.0, 0.0, side * (0.72 - index * 0.08)))
            add_node("ApexTalon%s%d" % ("L" if side < 0 else "R", index), mesh_ids["Talon"], (side * (1.23 + index * 0.04), 0.18, z - 0.04), rotation=(0.0, 0.0, side * 0.36))
        add_node("ApexFlankRoot%s" % ("L" if side < 0 else "R"), mesh_ids["Root"], (side * 1.08, 1.18, 0.28), rotation=(0.0, 0.0, side * 0.46), extras={"socket_type": "flank_root"})
        add_node("ApexMembrane%s" % ("L" if side < 0 else "R"), mesh_ids["Membrane"], (side * 1.36, 1.86, 0.34), rotation=(0.0, side * 0.18, side * 0.06), scale=(0.18, 1.48, 0.42), extras={"surface": "dorsal_membrane"})
        for rib_index in range(3):
            add_node(
                "ApexMembraneRib%s%d" % ("L" if side < 0 else "R", rib_index),
                mesh_ids["MembraneRib"],
                (side * (1.30 + rib_index * 0.03), 1.52 + rib_index * 0.28, 0.04 + rib_index * 0.28),
                rotation=(0.0, side * 0.18, side * (0.42 - rib_index * 0.08)),
                scale=(0.76, 1.0, 0.7),
                extras={"surface": "dorsal_membrane_rib"},
            )

    add_node("ProductionAssetMarker", None, extras={"asset_contract": "apex.cistern.v1", "source": "original_shared_mesh_builder"})

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
            ("ApexModel", "translation", [0.0, 0.8, 1.6], [0.0, 0.0, 0.0, 0.0, 0.018, 0.0, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.8, 1.6], quat((0.012, 0.0, 0.0)) + quat((-0.012, 0.0, 0.0)) + quat((0.012, 0.0, 0.0))),
            ("ApexMembraneL", "rotation", [0.0, 0.8, 1.6], quat((0.0, -0.18, -0.06)) + quat((0.0, -0.24, -0.14)) + quat((0.0, -0.18, -0.06))),
            ("ApexMembraneR", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.18, 0.06)) + quat((0.0, 0.24, 0.14)) + quat((0.0, 0.18, 0.06))),
        ]),
        animation("Walk", [
            ("ApexLegL0", "rotation", [0.0, 0.28, 0.56], quat((0.22, 0.0, 0.0)) + quat((-0.22, 0.0, 0.0)) + quat((0.22, 0.0, 0.0))),
            ("Torso", "rotation", [0.0, 0.28, 0.56], quat((0.055, 0.0, 0.0)) + quat((-0.055, 0.0, 0.0)) + quat((0.055, 0.0, 0.0))),
        ]),
        animation("Attack", [
            ("ApexCrown", "translation", [0.0, 0.24, 0.48], [0.0, 2.0, -1.02, 0.0, 2.0, -1.26, 0.0, 2.0, -1.02]),
            ("Torso", "rotation", [0.0, 0.24, 0.48], quat((0.05, 0.0, 0.0)) + quat((-0.12, 0.0, 0.0)) + quat((0.05, 0.0, 0.0))),
            ("ApexJawL", "rotation", [0.0, 0.24, 0.48], quat((0.82, 0.0, -0.12)) + quat((0.82, 0.0, -0.32)) + quat((0.82, 0.0, -0.12))),
            ("ApexJawR", "rotation", [0.0, 0.24, 0.48], quat((0.82, 0.0, 0.12)) + quat((0.82, 0.0, 0.32)) + quat((0.82, 0.0, 0.12))),
            ("ApexMembraneL", "rotation", [0.0, 0.24, 0.48], quat((0.0, -0.18, -0.06)) + quat((0.0, -0.34, -0.22)) + quat((0.0, -0.18, -0.06))),
            ("ApexMembraneR", "rotation", [0.0, 0.24, 0.48], quat((0.0, 0.18, 0.06)) + quat((0.0, 0.34, 0.22)) + quat((0.0, 0.18, 0.06))),
        ]),
        animation("Hit", [
            ("ApexModel", "translation", [0.0, 0.10, 0.24], [0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((-0.16, 0.08, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Feed", [
            ("ApexModel", "translation", [0.0, 0.3, 0.6], [0.0, 0.0, 0.0, 0.0, -0.12, -0.08, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.3, 0.6], quat((0.02, 0.0, 0.0)) + quat((0.16, 0.0, 0.0)) + quat((0.02, 0.0, 0.0))),
            ("ApexJawL", "rotation", [0.0, 0.3, 0.6], quat((0.82, 0.0, -0.12)) + quat((0.82, 0.0, -0.28)) + quat((0.82, 0.0, -0.12))),
            ("ApexJawR", "rotation", [0.0, 0.3, 0.6], quat((0.82, 0.0, 0.12)) + quat((0.82, 0.0, 0.28)) + quat((0.82, 0.0, 0.12))),
        ]),
        animation("Nest", [
            ("ApexModel", "translation", [0.0, 0.5, 1.0], [0.0, 0.0, 0.0, 0.0, 0.08, 0.0, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.5, 1.0], quat((0.025, 0.0, 0.0)) + quat((-0.025, 0.0, 0.0)) + quat((0.025, 0.0, 0.0))),
        ]),
        animation("Retreat", [
            ("ApexLegL0", "rotation", [0.0, 0.28, 0.56], quat((0.28, 0.0, 0.0)) + quat((-0.16, 0.0, 0.0)) + quat((0.28, 0.0, 0.0))),
            ("Torso", "rotation", [0.0, 0.28, 0.56], quat((0.12, 0.0, 0.0)) + quat((0.22, 0.0, 0.0)) + quat((0.12, 0.0, 0.0))),
            ("ApexMembraneL", "rotation", [0.0, 0.28, 0.56], quat((0.0, -0.18, -0.06)) + quat((0.0, -0.08, 0.02)) + quat((0.0, -0.18, -0.06))),
            ("ApexMembraneR", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.18, 0.06)) + quat((0.0, 0.08, -0.02)) + quat((0.0, 0.18, 0.06))),
        ]),
        animation("Death", [
            ("ApexModel", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.34, 0.08, 0.2)) + quat((0.78, 0.16, 0.42))),
            ("Torso", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.18, 0.0, 0.0)) + quat((0.46, 0.0, 0.0))),
        ]),
    ]
    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Apex asset builder"},
        "scene": 0,
        "scenes": [{"name": "CisternApex", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": "apex.cistern.v1",
            "required_nodes": ["ApexModel", "Torso", "TorsoCore", "ApexCrown", "ApexJawL", "ApexMembraneL", "ApexFlankRootL", "ProductionAssetMarker"],
            "animation_clips": ["Idle", "Walk", "Attack", "Hit", "Feed", "Nest", "Retreat", "Death"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
