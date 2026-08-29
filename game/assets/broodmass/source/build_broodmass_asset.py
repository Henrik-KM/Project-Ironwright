"""Build the original high-definition Broodmass organic glTF."""

from __future__ import annotations

import base64
import json
import math
import sys
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, _geometry, add_beveled_box, add_box, add_cylinder, add_uv_sphere, quat  # noqa: E402
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "organic_families" / "source"))
from build_authored_organic_assets import add_capsule, add_convex_sheet, add_organic_lobe  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "broodmass.gltf"


def add_tapered_cylinder(
    builder: BufferBuilder,
    bottom_radius: float,
    top_radius: float,
    height: float,
    material: int,
    sides: int = 24,
) -> tuple[int, int, int, int]:
    """Build a smooth pointed spine without changing the node/socket contract."""
    sides = max(sides, 24)
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []
    bottom = len(positions) // 3
    for y, radius in ((-height * 0.5, bottom_radius), (height * 0.5, top_radius)):
        for side in range(sides):
            angle = math.tau * side / sides
            positions.extend([math.cos(angle) * radius, y, math.sin(angle) * radius])
            slope = (bottom_radius - top_radius) / max(height, 0.001)
            normal = [math.cos(angle), slope, math.sin(angle)]
            normal_length = math.sqrt(sum(value * value for value in normal)) or 1.0
            normals.extend(value / normal_length for value in normal)
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
        # Broodmass is a late-family close-camera specimen. Keep the smooth
        # flesh and shell surfaces at the same density as the final Apex so
        # the nest organism does not read as a visibly coarser cousin.
        "Core": mesh("Core", add_uv_sphere(builder, 0.74, flesh, 24, 36)),
        "Segment": mesh("Segment", add_uv_sphere(builder, 0.58, shell, 24, 32)),
        "Lobe": mesh("Lobe", add_uv_sphere(builder, 0.42, flesh, 24, 36)),
        # Thorax ribs are rounded living struts; keep separate convex plates
        # for the dorsal and maw surfaces so those surfaces retain their
        # broad shell read without turning the repeated ribs into flat bars.
        "Rib": mesh("Rib", add_capsule(builder, 0.14, 1.5, shell, sides=24, cap_segments=6)),
        "Plate": mesh("Plate", add_convex_sheet(builder, (1.5, 0.15, 0.24), shell, rings=5, sides=24)),
        # The dorsal and maw plates sit on the late-family review silhouette.
        # Give them a closed folded volume so they read as living shell lobes
        # instead of horizontal manufactured sheets at tactical distance.
        "FoldedPlate": mesh("FoldedPlate", add_organic_lobe(builder, (1.58, 0.36, 0.72), shell, lobes=5, rings=10, sides=40, scallop_amplitude=0.14, leading_extension=0.34, fold_strength=0.9)),
        "Fan": mesh("Fan", add_beveled_box(builder, (0.18, 1.4, 0.8), membrane, 0.025)),
        "Maw": mesh("Maw", add_uv_sphere(builder, 0.44, membrane, 24, 36)),
        # Pointed crown spines keep the nest silhouette organic instead of
        # reading as a row of identical manufactured bars at review distance.
        "Spine": mesh("Spine", add_tapered_cylinder(builder, 0.13, 0.026, 0.98, bone, 24)),
        "Leg": mesh("Leg", add_cylinder(builder, 0.12, 1.72, tendon, 24)),
        "Hook": mesh("Hook", add_cylinder(builder, 0.075, 0.78, bone, 24)),
        "Eye": mesh("Eye", add_uv_sphere(builder, 0.105, eye, 20, 28)),
        "Tendon": mesh("Tendon", add_cylinder(builder, 0.065, 0.82, tendon, 28)),
        "Fastener": mesh("Fastener", add_uv_sphere(builder, 0.055, bone, 20, 28)),
        "LobeRidge": mesh("LobeRidge", add_beveled_box(builder, (0.5, 0.08, 0.16), bone, 0.018)),
        "MawRidge": mesh("MawRidge", add_beveled_box(builder, (0.62, 0.09, 0.14), bone, 0.018)),
        "CrownFastener": mesh("CrownFastener", add_uv_sphere(builder, 0.065, bone, 16, 24)),
        "CrownCap": mesh("CrownCap", add_uv_sphere(builder, 0.28, shell, 24, 36)),
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
        add_node("BroodmassThoraxRib%d" % index, mesh_ids["Rib"], (0.0, 1.42 - index * 0.025, z), rotation=(0.0, 0.0, math.pi * 0.5 + 0.05), parent=torso)
        add_node("BroodmassFastenerL%d" % index, mesh_ids["Fastener"], (-0.75, 1.28, z), parent=torso)
        add_node("BroodmassFastenerR%d" % index, mesh_ids["Fastener"], (0.75, 1.28, z), parent=torso)
    add_node("OrganicDorsalPlate", mesh_ids["FoldedPlate"], (-0.15, 1.68, 0.18), scale=(1.3, 0.9, 1.2), extras={"surface": "layered_shell_break"})

    for side in (-1.0, 1.0):
        suffix = "L" if side < 0 else "R"
        add_node("BroodmassLobe%s" % suffix, mesh_ids["Lobe"], (side * 0.78, 1.28, 0.5), scale=(1.32, 0.9, 1.2), extras={"socket_type": "brood_lobe"})
        add_node("BroodmassLobeRidge%s" % suffix, mesh_ids["LobeRidge"], (side * 0.78, 1.58, 0.46), rotation=(0.0, side * 0.2, side * 0.12), scale=(0.82, 1.0, 0.9), extras={"surface": "lobe_ridge"})
        add_node("BroodmassEye%s" % suffix, mesh_ids["Eye"], (side * 0.35, 1.66, -1.02), extras={"socket_type": "threat_eye"})
        add_node("BroodmassTendon%s" % suffix, mesh_ids["Tendon"], (side * 0.45, 1.0, -1.15), rotation=(0.7, 0.0, side * 0.12))

    maw = add_node("BroodmassMaw", mesh_ids["Maw"], (0.0, 1.16, -1.52), scale=(1.28, 0.75, 1.4), extras={"socket_type": "brood_maw"})
    # Maw hardware is parented to the maw shell; use local offsets so it does
    # not double-apply the shell's world-space position.
    add_node("BroodmassMawPlate", mesh_ids["FoldedPlate"], (0.0, 0.24, -0.02), scale=(0.86, 0.82, 1.1), parent=maw)
    # The nest maw needs a lower living volume beneath its upper plate. Keep it
    # on the existing animated maw socket so the added depth follows attack and
    # preserves one clear motion owner.
    add_node("BroodmassMawLower", mesh_ids["FoldedPlate"], (0.0, -0.38, -0.12), rotation=(0.24, 0.0, 0.0), scale=(0.72, 0.70, 0.82), extras={"surface": "lower_maw_shell"}, parent=maw)
    add_node("BroodmassMawRidge", mesh_ids["MawRidge"], (0.0, 0.34, -0.28), scale=(0.88, 1.0, 0.9), parent=maw, extras={"surface": "maw_ridge"})
    for side in (-1.0, 1.0):
        add_node("BroodmassMawHook%s" % ("L" if side < 0 else "R"), mesh_ids["Hook"], (side * 0.34, -0.42, -0.24), rotation=(0.78, 0.0, side * 0.15), parent=maw)

    for index in range(7):
        x = -1.1 + index * 0.367
        add_node("CrownSpine%d" % index, mesh_ids["Spine"], (x, 2.0 + (index % 2) * 0.1, 0.18), rotation=(0.0, 0.0, -0.25 + index * 0.08), extras={"surface": "bone_ridge"})
        add_node("CrownFastener%d" % index, mesh_ids["CrownFastener"], (x, 1.9 + (index % 2) * 0.1, 0.14), extras={"surface": "crown_socket"})

    # A compact elevated crown cap unifies the spine row into a single nest
    # silhouette. It is deliberately presentation-only and does not change
    # collision, health or the broodmass's ecology contract.
    crown_cap = add_node(
        "BroodmassCrownCap",
        mesh_ids["CrownCap"],
        (0.0, 2.12, 0.16),
        scale=(1.55, 0.72, 1.2),
        extras={"socket_type": "brood_crown_cap"},
    )
    add_node(
        "BroodmassCrownCapPlate",
        mesh_ids["LobeRidge"],
        (0.0, 0.16, 0.02),
        scale=(0.88, 0.86, 0.72),
        parent=crown_cap,
        extras={"surface": "crown_cap_plate"},
    )

    for side in (-1.0, 1.0):
        suffix = "L" if side < 0 else "R"
        for index in range(4):
            z = -0.74 + index * 0.5
            add_node("BroodmassLeg%s%d" % (suffix, index), mesh_ids["Leg"], (side * (0.85 + index * 0.06), 0.58, z), rotation=(0.0, 0.0, side * (0.76 - index * 0.06)))
            add_node("BroodmassHook%s%d" % (suffix, index), mesh_ids["Hook"], (side * (1.28 + index * 0.04), 0.14, z - 0.03), rotation=(0.0, 0.0, side * 0.38))
        add_node("BroodmassFan%s" % suffix, mesh_ids["Fan"], (side * 1.28, 1.62, 0.3), rotation=(0.0, side * 0.2, side * 0.08), scale=(0.22, 1.3, 0.44), extras={"surface": "dorsal_membrane"})

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
        animation("Idle", [
            ("BroodmassModel", "translation", [0.0, 0.9, 1.8], [0.0, 0.0, 0.0, 0.0, 0.018, 0.0, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.9, 1.8], quat((0.012, 0.0, 0.0)) + quat((-0.012, 0.0, 0.0)) + quat((0.012, 0.0, 0.0))),
        ]),
        animation("Walk", [
            ("BroodmassLegL0", "rotation", [0.0, 0.28, 0.56], quat((0.2, 0.0, 0.0)) + quat((-0.2, 0.0, 0.0)) + quat((0.2, 0.0, 0.0))),
            ("Torso", "rotation", [0.0, 0.28, 0.56], quat((0.05, 0.0, 0.0)) + quat((-0.05, 0.0, 0.0)) + quat((0.05, 0.0, 0.0))),
        ]),
        animation("Attack", [
            ("BroodmassMaw", "translation", [0.0, 0.26, 0.52], [0.0, 1.16, -1.52, 0.0, 1.16, -1.76, 0.0, 1.16, -1.52]),
            ("Torso", "rotation", [0.0, 0.26, 0.52], quat((0.04, 0.0, 0.0)) + quat((-0.1, 0.0, 0.0)) + quat((0.04, 0.0, 0.0))),
        ]),
        animation("Hit", [
            ("BroodmassModel", "translation", [0.0, 0.10, 0.24], [0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((-0.16, 0.08, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Feed", [
            ("BroodmassModel", "translation", [0.0, 0.3, 0.6], [0.0, 0.0, 0.0, 0.0, -0.12, -0.08, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.3, 0.6], quat((0.02, 0.0, 0.0)) + quat((0.16, 0.0, 0.0)) + quat((0.02, 0.0, 0.0))),
        ]),
        animation("Nest", [
            ("BroodmassModel", "translation", [0.0, 0.5, 1.0], [0.0, 0.0, 0.0, 0.0, 0.08, 0.0, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.5, 1.0], quat((0.025, 0.0, 0.0)) + quat((-0.025, 0.0, 0.0)) + quat((0.025, 0.0, 0.0))),
        ]),
        animation("Retreat", [
            ("BroodmassLegL0", "rotation", [0.0, 0.28, 0.56], quat((0.28, 0.0, 0.0)) + quat((-0.16, 0.0, 0.0)) + quat((0.28, 0.0, 0.0))),
            ("Torso", "rotation", [0.0, 0.28, 0.56], quat((0.12, 0.0, 0.0)) + quat((0.22, 0.0, 0.0)) + quat((0.12, 0.0, 0.0))),
        ]),
        animation("Death", [
            ("BroodmassModel", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.34, 0.08, 0.2)) + quat((0.78, 0.16, 0.42))),
            ("Torso", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.18, 0.0, 0.0)) + quat((0.46, 0.0, 0.0))),
        ]),
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
            "required_nodes": ["BroodmassModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "BroodmassLobeL", "BroodmassLobeRidgeL", "BroodmassMaw", "BroodmassMawRidge", "CrownSpine0", "CrownFastener0", "BroodmassCrownCap", "BroodmassCrownCapPlate", "BroodmassFanL", "ProductionAssetMarker"],
            "animation_clips": ["Idle", "Walk", "Attack", "Hit", "Feed", "Nest", "Retreat", "Death"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
