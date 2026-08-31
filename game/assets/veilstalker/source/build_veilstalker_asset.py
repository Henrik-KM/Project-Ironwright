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
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "organic_families" / "source"))
from build_authored_organic_assets import add_organic_lobe  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "veilstalker.gltf"
AGGREGATE_BOUNDS = {
    "min": [-1.381196, -0.193051, -1.858913],
    "max": [1.381196, 2.080635, 1.67],
}
TEXTURE_URIS = {
    "shell_base": "../organic_families/textures/organic_shell_base_color.png",
    "tissue_base": "../organic_families/textures/organic_tissue_base_color.png",
    "shell_normal": "../organic_families/textures/organic_shell_normal.png",
    "tissue_normal": "../organic_families/textures/organic_tissue_normal.png",
    "shell_orm": "../organic_families/textures/organic_shell_orm.png",
    "tissue_orm": "../organic_families/textures/organic_tissue_orm.png",
    "emissive": "../organic_families/textures/organic_emissive.png",
}


def material(
    name: str,
    base_color: Sequence[float],
    metallic: float,
    roughness: float,
    surface: str,
    normal_scale: float,
    emissive: Sequence[float] | None = None,
    alpha_mode: str | None = None,
) -> dict:
    base_texture = 0 if surface in {"shell", "signal"} else 1
    normal_texture = 2 if surface in {"shell", "signal"} else 3
    orm_texture = 4 if surface in {"shell", "signal"} else 5
    entry = {
        "name": name,
        "pbrMetallicRoughness": {
            "baseColorFactor": list(base_color),
            "baseColorTexture": {"index": base_texture},
            "metallicFactor": metallic,
            "roughnessFactor": roughness,
            "metallicRoughnessTexture": {"index": orm_texture},
        },
        "normalTexture": {"index": normal_texture, "scale": normal_scale},
        "occlusionTexture": {"index": orm_texture, "strength": 1.0},
        "extras": {
            "ironwright_surface_profile": "shared_organic_pbr_v1",
            "ironwright_surface_class": surface,
        },
    }
    if emissive is not None:
        entry["emissiveFactor"] = list(emissive)
        entry["emissiveTexture"] = {"index": 6}
    if alpha_mode is not None:
        entry["alphaMode"] = alpha_mode
    return entry


def main() -> None:
    builder = BufferBuilder()
    materials = [
        material("Veilstalker wet chitin", [0.09, 0.06, 0.08, 1.0], 0.22, 0.28, "shell", 0.28),
        material("Veilstalker shell ridge", [0.25, 0.12, 0.15, 1.0], 0.12, 0.42, "shell", 0.30),
        material("Veilstalker deep flesh", [0.14, 0.03, 0.045, 1.0], 0.0, 0.72, "tissue", 0.18),
        material("Veilstalker bone hooks", [0.48, 0.36, 0.27, 1.0], 0.0, 0.62, "shell", 0.32),
        material("Veilstalker membrane", [0.22, 0.018, 0.065, 0.82], 0.0, 0.5, "tissue", 0.16, alpha_mode="BLEND"),
        material("Veilstalker threat eyes", [0.24, 0.018, 0.008, 1.0], 0.0, 0.3, "signal", 0.08, [1.0, 0.05, 0.012]),
        material("Veilstalker tendon", [0.28, 0.06, 0.08, 1.0], 0.0, 0.55, "tissue", 0.18),
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int, int, int]) -> int:
        position, normal, uv, tangent, indices, material_index = geometry
        meshes.append({
            "name": name,
            "primitives": [{
                "attributes": {"POSITION": position, "NORMAL": normal, "TEXCOORD_0": uv, "TANGENT": tangent},
                "indices": indices,
                "material": material_index,
            }],
        })
        return len(meshes) - 1

    wet, shell, flesh, bone, membrane, eye, tendon = range(7)
    mesh_ids = {
        "Core": mesh("ThoraxCore", add_uv_sphere(builder, 0.62, wet, 20, 32)),
        "CoreDetail": mesh("ThoraxCoreDetail", add_uv_sphere(builder, 0.62, flesh, 20, 32)),
        "Segment": mesh("ThoraxSegment", add_uv_sphere(builder, 0.5, shell, 16, 28)),
        "Rib": mesh("ThoraxRib", add_beveled_box(builder, (1.38, 0.13, 0.18), shell, 0.028)),
        "Abdomen": mesh("Abdomen", add_uv_sphere(builder, 0.48, flesh, 16, 28)),
        "Head": mesh("Cowl", add_uv_sphere(builder, 0.48, shell, 16, 28)),
        "Eye": mesh("ThreatEye", add_uv_sphere(builder, 0.09, eye, 16, 24)),
        "Plate": mesh("DorsalLobe", add_organic_lobe(builder, (1.30, 0.34, 0.54), shell, lobes=4, rings=9, sides=40, scallop_amplitude=0.13, leading_extension=0.24, fold_strength=0.82)),
        "Spine": mesh("DorsalSpine", add_cylinder(builder, 0.09, 0.58, bone, 24)),
        "Veil": mesh("VeilMembrane", add_uv_sphere(builder, 0.34, membrane, 16, 28)),
        "Limb": mesh("Forelimb", add_cylinder(builder, 0.075, 1.35, tendon, 24)),
        "Hook": mesh("Hook", add_cylinder(builder, 0.06, 0.9, bone, 24)),
        "Tendril": mesh("Tendril", add_cylinder(builder, 0.035, 0.8, tendon, 24)),
        "Tail": mesh("Tail", add_uv_sphere(builder, 0.19, flesh, 16, 24)),
        "Fastener": mesh("ShellFastener", add_uv_sphere(builder, 0.045, eye, 16, 24)),
        "EyeRim": mesh("ThreatEyeRim", add_beveled_box(builder, (0.18, 0.12, 0.24), shell, 0.025)),
        "Mandible": mesh("Mandible", add_beveled_box(builder, (0.16, 0.12, 0.48), bone, 0.032)),
        "MandibleRidge": mesh("MandibleRidge", add_beveled_box(builder, (0.11, 0.08, 0.36), shell, 0.022)),
        "CowlSpine": mesh("CowlSpine", add_cylinder(builder, 0.075, 0.5, bone, 24)),
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

    torso = add_node("Torso", None, (0.0, 0.0, 0.0), extras={"surface": "layered_wet_chitin"})
    torso_core = add_node("TorsoCore", mesh_ids["Core"], (0.0, 0.92, -0.12), parent=torso, extras={"release_material_family": "chitin", "source_owned_runtime_anchor": True})
    # The runtime historically added a second compact Torso/TorsoCore sphere
    # because the authored package did not own that inner depth cue at its
    # stable anchor. Keep the broad shell unchanged and consolidate the exact
    # compact tissue volume inside it so presentation can use one source-owned
    # hierarchy without changing the silhouette or aggregate bounds.
    add_node(
        "VeilstalkerTorsoCoreDetail",
        mesh_ids["CoreDetail"],
        (0.0, 0.06, 0.22),
        scale=(0.85, 0.37, 0.66),
        parent=torso_core,
        extras={"release_material_family": "tissue", "source_owned_runtime_core": True},
    )
    for index in range(4):
        z = -0.72 + index * 0.44
        add_node("TorsoSegment%d" % index, mesh_ids["Segment"], (0.0, 0.91 - index * 0.015, z), parent=torso)
        add_node("VeilstalkerThoraxDorsalRib%d" % index, mesh_ids["Rib"], (0.0, 1.42 - index * 0.045, z), rotation=(0.0, 0.0, 0.0), parent=torso)
        add_node("VeilstalkerThoraxFastenerL%d" % index, mesh_ids["Fastener"], (-0.58, 1.28 - index * 0.02, z - 0.08), parent=torso)
        add_node("VeilstalkerThoraxFastenerR%d" % index, mesh_ids["Fastener"], (0.58, 1.28 - index * 0.02, z - 0.08), parent=torso)
    add_node("VeilstalkerAbdomen", mesh_ids["Abdomen"], (-0.22, 1.06, 0.84))
    add_node("VeilstalkerCowl", mesh_ids["Head"], (0.0, 1.38, -1.02), extras={"socket_type": "sensory_cowl"})
    for side in (-1.0, 1.0):
        side_name = "L" if side < 0.0 else "R"
        add_node("VeilstalkerEye%s" % side_name, mesh_ids["Eye"], (side * 0.27, 1.48, -1.37), extras={"socket_type": "threat_eye"})
        add_node("VeilstalkerEyeRim%s" % side_name, mesh_ids["EyeRim"], (side * 0.27, 1.48, -1.3), rotation=(0.0, 0.0, side * 0.18), extras={"surface": "protected_threat_eye"})
        add_node("VeilstalkerCowlPlate%s" % side_name, mesh_ids["Plate"], (side * 0.34, 1.60, -1.17), rotation=(0.0, 0.0, side * 0.18), scale=(0.40, 0.76, 0.34), extras={"surface": "layered_cowl_brow"})
        add_node("VeilstalkerMandible%s" % side_name, mesh_ids["Mandible"], (side * 0.24, 1.17, -1.43), rotation=(0.0, 0.0, side * 0.28), extras={"socket_type": "attack_mandible"})
        add_node("VeilstalkerMandibleRidge%s" % side_name, mesh_ids["MandibleRidge"], (side * 0.28, 1.34, -1.36), rotation=(0.0, 0.0, side * 0.12), extras={"surface": "layered_mouth_ridge"})
        add_node("VeilstalkerCowlSpine%s" % side_name, mesh_ids["CowlSpine"], (side * 0.39, 1.7, -1.08), rotation=(0.0, 0.0, side * 0.32), extras={"surface": "cowl_bone_spine"})
        add_node("VeilstalkerVeil%s" % side_name, mesh_ids["Veil"], (side * 0.98, 1.08, -0.16), rotation=(0.0, side * 0.08, side * 0.11), extras={"socket_type": "attack_membrane"})
        add_node("VeilstalkerForelimb%s" % side_name, mesh_ids["Limb"], (side * 0.78, 0.72, -0.62), rotation=(0.0, 0.0, side * 0.34))
        add_node("VeilstalkerHook%s" % side_name, mesh_ids["Hook"], (side * 0.93, 0.22, -1.02), rotation=(0.58, 0.0, side * 0.2), extras={"socket_type": "attack_hook"})
    for index in range(3):
        plate_z = -0.68 + index * 0.44
        add_node("VeilstalkerDorsalPlate%d" % index, mesh_ids["Plate"], (0.0, 1.58 - index * 0.05, plate_z), rotation=(0.0, 0.0, 0.03 * (index - 1)))
        add_node("VeilstalkerDorsalSpine%d" % index, mesh_ids["Spine"], (0.0, 1.78 - index * 0.03, plate_z + 0.04), rotation=(0.0, 0.0, 0.16 * (index - 1)))
    add_node("OrganicDorsalPlate", mesh_ids["Plate"], (0.0, 1.5, 0.2), rotation=(0.0, 0.0, -0.03), extras={"surface": "layered_shell_break"})
    for index in range(3):
        side = -1.0 if index % 2 == 0 else 1.0
        add_node("VeilstalkerTendril%d" % index, mesh_ids["Tendril"], (side * (0.16 + index * 0.08), 1.12, -1.52 - index * 0.05), rotation=(0.55, 0.0, side * 0.18), extras={"socket_type": "sensory_tendril"})
    for index in range(3):
        add_node("VeilstalkerTail%d" % index, mesh_ids["Tail"], (-0.22 + index * 0.08, 0.98 - index * 0.06, 0.72 + index * 0.38))
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "veilstalker.predator.v1", "source": "original_shared_mesh_builder"})

    node_index = {node["name"]: index for index, node in enumerate(nodes)}
    if len(node_index) != len(nodes):
        raise RuntimeError("Veilstalker nodes must have globally unique stable names")

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
            ("VeilstalkerMandibleL", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.0, -0.31)) + quat((0.0, 0.0, -0.22)) + quat((0.0, 0.0, -0.31))),
            ("VeilstalkerMandibleR", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.0, 0.31)) + quat((0.0, 0.0, 0.22)) + quat((0.0, 0.0, 0.31))),
        ]),
        animation("Walk", [
            ("TorsoSegment0", "rotation", [0.0, 0.22, 0.44], quat((0.12, 0.0, 0.0)) + quat((-0.12, 0.0, 0.0)) + quat((0.12, 0.0, 0.0))),
            ("Torso", "rotation", [0.0, 0.22, 0.44], quat((0.05, 0.0, 0.0)) + quat((-0.05, 0.0, 0.0)) + quat((0.05, 0.0, 0.0))),
        ]),
        animation("Attack", [
            ("VeilstalkerVeilL", "rotation", [0.0, 0.34, 0.68], quat((0.0, -0.08, -0.11)) + quat((0.0, -0.18, -0.30)) + quat((0.0, -0.08, -0.11))),
            ("VeilstalkerVeilR", "rotation", [0.0, 0.34, 0.68], quat((0.0, 0.08, 0.11)) + quat((0.0, 0.18, 0.30)) + quat((0.0, 0.08, 0.11))),
            ("Torso", "rotation", [0.0, 0.34, 0.68], quat((0.04, 0.0, 0.0)) + quat((-0.1, 0.0, 0.0)) + quat((0.04, 0.0, 0.0))),
            ("VeilstalkerMandibleL", "rotation", [0.0, 0.34, 0.68], quat((0.0, 0.0, -0.28)) + quat((0.0, 0.0, -0.62)) + quat((0.0, 0.0, -0.28))),
            ("VeilstalkerMandibleR", "rotation", [0.0, 0.34, 0.68], quat((0.0, 0.0, 0.28)) + quat((0.0, 0.0, 0.62)) + quat((0.0, 0.0, 0.28))),
            ("VeilstalkerCowlSpineL", "rotation", [0.0, 0.34, 0.68], quat((0.0, 0.0, -0.32)) + quat((0.0, 0.0, -0.46)) + quat((0.0, 0.0, -0.32))),
            ("VeilstalkerCowlSpineR", "rotation", [0.0, 0.34, 0.68], quat((0.0, 0.0, 0.32)) + quat((0.0, 0.0, 0.46)) + quat((0.0, 0.0, 0.32))),
        ]),
        animation("Hit", [
            ("VeilstalkerModel", "translation", [0.0, 0.10, 0.24], [0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((-0.16, 0.08, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("VeilstalkerMandibleL", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, -0.28)) + quat((0.0, 0.0, -0.18)) + quat((0.0, 0.0, -0.28))),
            ("VeilstalkerMandibleR", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.28)) + quat((0.0, 0.0, 0.18)) + quat((0.0, 0.0, 0.28))),
        ]),
        animation("Feed", [
            ("VeilstalkerModel", "translation", [0.0, 0.3, 0.6], [0.0, 0.0, 0.0, 0.0, -0.12, -0.08, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.3, 0.6], quat((0.02, 0.0, 0.0)) + quat((0.16, 0.0, 0.0)) + quat((0.02, 0.0, 0.0))),
            ("VeilstalkerMandibleL", "rotation", [0.0, 0.3, 0.6], quat((0.0, 0.0, -0.28)) + quat((0.0, 0.0, -0.54)) + quat((0.0, 0.0, -0.28))),
            ("VeilstalkerMandibleR", "rotation", [0.0, 0.3, 0.6], quat((0.0, 0.0, 0.28)) + quat((0.0, 0.0, 0.54)) + quat((0.0, 0.0, 0.28))),
        ]),
        animation("Nest", [
            ("VeilstalkerModel", "translation", [0.0, 0.5, 1.0], [0.0, 0.0, 0.0, 0.0, 0.08, 0.0, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.5, 1.0], quat((0.025, 0.0, 0.0)) + quat((-0.025, 0.0, 0.0)) + quat((0.025, 0.0, 0.0))),
        ]),
        animation("Retreat", [
            ("TorsoSegment0", "rotation", [0.0, 0.22, 0.44], quat((0.28, 0.0, 0.0)) + quat((-0.16, 0.0, 0.0)) + quat((0.28, 0.0, 0.0))),
            ("Torso", "rotation", [0.0, 0.22, 0.44], quat((0.12, 0.0, 0.0)) + quat((0.22, 0.0, 0.0)) + quat((0.12, 0.0, 0.0))),
            ("VeilstalkerCowlSpineL", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.0, -0.32)) + quat((0.0, 0.0, -0.18)) + quat((0.0, 0.0, -0.32))),
            ("VeilstalkerCowlSpineR", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.0, 0.32)) + quat((0.0, 0.0, 0.18)) + quat((0.0, 0.0, 0.32))),
        ]),
        animation("Death", [
            ("VeilstalkerModel", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.34, 0.08, 0.2)) + quat((0.78, 0.16, 0.42))),
            ("Torso", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.18, 0.0, 0.0)) + quat((0.46, 0.0, 0.0))),
        ]),
    ]

    for clip in animations:
        targets = [
            (channel["target"]["node"], channel["target"]["path"])
            for channel in clip["channels"]
        ]
        if len(targets) != len(set(targets)):
            raise RuntimeError("Animation %s contains duplicate target paths" % clip["name"])

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright deterministic HD PBR Veilstalker asset builder"},
        "scene": 0,
        "scenes": [{"name": "Veilstalker", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "images": [
            {"uri": uri}
            for uri in TEXTURE_URIS.values()
        ],
        "textures": [{"sampler": 0, "source": index} for index in range(7)],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": "veilstalker.predator.v1",
            "surface_profile": "shared_organic_pbr_v1",
            "aggregate_bounds": AGGREGATE_BOUNDS,
            "required_nodes": [
                "VeilstalkerModel",
                "Torso",
                "TorsoCore",
                "VeilstalkerTorsoCoreDetail",
                "VeilstalkerCowl",
                "VeilstalkerVeilL",
                "VeilstalkerVeilR",
                "VeilstalkerTendril0",
                "VeilstalkerThoraxDorsalRib0",
                "ProductionAssetMarker",
            ],
            "animation_clips": ["Idle", "Walk", "Attack", "Hit", "Feed", "Nest", "Retreat", "Death"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
