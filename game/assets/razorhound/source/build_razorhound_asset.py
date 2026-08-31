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
from build_bulwark_asset import BufferBuilder, add_beveled_box, add_box, add_cylinder, add_uv_sphere, quat  # noqa: E402
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "organic_families" / "source"))
from build_authored_organic_assets import add_organic_lobe  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "razorhound.gltf"
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
    return entry


def main() -> None:
    builder = BufferBuilder()
    materials = [
        material("Razorhound wet chitin", [0.08, 0.11, 0.12, 1.0], 0.2, 0.3, "shell", 0.28),
        material("Razorhound shell ridge", [0.24, 0.28, 0.28, 1.0], 0.16, 0.42, "shell", 0.30),
        material("Razorhound flesh", [0.18, 0.05, 0.04, 1.0], 0.0, 0.74, "tissue", 0.18),
        material("Razorhound bone", [0.52, 0.44, 0.32, 1.0], 0.0, 0.6, "shell", 0.32),
        material("Razorhound threat eye", [0.3, 0.03, 0.008, 1.0], 0.0, 0.28, "signal", 0.08, [1.0, 0.06, 0.01]),
        material("Razorhound tendon", [0.26, 0.08, 0.07, 1.0], 0.0, 0.55, "tissue", 0.18),
        material("Razorhound mouth seam", [0.035, 0.012, 0.014, 1.0], 0.0, 0.62, "tissue", 0.12),
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

    wet, shell, flesh, bone, eye, tendon, mouth = range(7)
    mesh_ids = {
        # Spend the close-camera tessellation budget on the wet body and
        # articulated head surfaces so highlights roll across the predator
        # rather than breaking into the old low-radial facets.
        "Core": mesh("Core", add_uv_sphere(builder, 0.5, wet, 24, 36)),
        "Segment": mesh("Segment", add_uv_sphere(builder, 0.42, shell, 24, 36)),
        "Rib": mesh("Rib", add_beveled_box(builder, (1.08, 0.12, 0.18), shell, 0.025)),
        "Head": mesh("Head", add_uv_sphere(builder, 0.34, wet, 24, 36)),
        "Snout": mesh("Snout", add_uv_sphere(builder, 0.33, shell, 24, 36)),
        "Cheek": mesh("Cheek", add_beveled_box(builder, (0.18, 0.34, 0.7), shell, 0.03)),
        # Razorhound's cheek sockets sit directly on the close-camera head
        # silhouette. Keep the old mesh for the fallback contract, while the
        # authored node below uses a denser folded living shell.
        "CheekLobe": mesh("CheekLobe", add_organic_lobe(builder, (0.26, 0.34, 0.72), shell, lobes=3, rings=9, sides=40, scallop_amplitude=0.12, leading_extension=0.22, fold_strength=0.82)),
        "BrowGuard": mesh("BrowGuard", add_organic_lobe(builder, (0.24, 0.12, 0.46), shell, lobes=2, rings=8, sides=36, scallop_amplitude=0.09, leading_extension=0.18, fold_strength=0.76)),
        # The bite line is a close-camera identity cue. These closed lobes
        # replace the visual gap between the snout and cheek plates while the
        # existing socket nodes remain authoritative for gameplay and motion.
        "JawLobe": mesh("JawLobe", add_organic_lobe(builder, (0.34, 0.18, 0.30), flesh, lobes=3, rings=10, sides=40, scallop_amplitude=0.10, leading_extension=0.18, fold_strength=0.78)),
        "MuzzleGuard": mesh("MuzzleGuard", add_organic_lobe(builder, (0.54, 0.14, 0.28), shell, lobes=4, rings=9, sides=40, scallop_amplitude=0.08, leading_extension=0.16, fold_strength=0.74)),
        "Nostril": mesh("Nostril", add_uv_sphere(builder, 0.046, mouth, 16, 24)),
        "Ear": mesh("Ear", add_uv_sphere(builder, 0.16, bone, 24, 32)),
        "Eye": mesh("Eye", add_uv_sphere(builder, 0.07, eye, 20, 28)),
        "Fang": mesh("Fang", add_cylinder(builder, 0.052, 0.62, bone, 24)),
        "Spine": mesh("Spine", add_cylinder(builder, 0.06, 0.72, bone, 24)),
        "Leg": mesh("Leg", add_cylinder(builder, 0.08, 1.12, tendon, 24)),
        "Talon": mesh("Talon", add_cylinder(builder, 0.055, 0.62, bone, 24)),
        "Tail": mesh("Tail", add_cylinder(builder, 0.075, 1.2, tendon, 24)),
        "Fastener": mesh("Fastener", add_uv_sphere(builder, 0.04, bone, 20, 28)),
    }

    nodes: list[dict] = [{"name": "RazorhoundModel", "children": [], "extras": {"ironwright_asset_id": "razorhound.predator.v1", "asset_quality": "authored_high_definition", "socket_contract": "snout, cheek_plates, fangs, spine_tail"}}]

    def add_node(name: str, mesh_id: int | None = None, translation: Sequence[float] = (0.0, 0.0, 0.0), rotation: Sequence[float] = (0.0, 0.0, 0.0), scale: Sequence[float] | None = None, extras: dict | None = None, parent: int = 0) -> int:
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

    torso = add_node("Torso", extras={"surface": "layered_wet_chitin"})
    add_node("TorsoCore", mesh_ids["Core"], (0.0, 0.58, 0.18), parent=torso, extras={"release_material_family": "chitin"})
    for index in range(3):
        z = -0.42 + index * 0.46
        add_node("TorsoSegment%d" % index, mesh_ids["Segment"], (0.0, 0.58, z), parent=torso)
        add_node("RazorhoundThoraxRib%d" % index, mesh_ids["Rib"], (0.0, 0.96, z), parent=torso)
        add_node("RazorhoundThoraxFastenerL%d" % index, mesh_ids["Fastener"], (-0.45, 0.84, z), parent=torso)
        add_node("RazorhoundThoraxFastenerR%d" % index, mesh_ids["Fastener"], (0.45, 0.84, z), parent=torso)
    head = add_node("RazorhoundHead", mesh_ids["Head"], (0.0, 0.84, -0.82))
    snout = add_node("RazorhoundSnout", mesh_ids["Snout"], (0.0, 0.78, -1.18), extras={"socket_type": "snout"})
    add_node("RazorhoundMuzzleGuard", mesh_ids["MuzzleGuard"], (0.0, 0.10, -0.12), scale=(1.08, 1.0, 0.96), parent=snout, extras={"surface": "layered_muzzle_guard"})
    add_node("RazorhoundThroatLobe", mesh_ids["JawLobe"], (0.0, -0.18, -0.10), scale=(1.28, 1.02, 1.0), parent=snout, extras={"surface": "articulated_bite_line"})
    for side in (-1.0, 1.0):
        add_node("RazorhoundNostril%s" % ("L" if side < 0.0 else "R"), mesh_ids["Nostril"], (side * 0.09, 0.05, -0.25), scale=(1.0, 0.72, 0.68), parent=snout, extras={"surface": "muzzle_sensor_detail"})
    add_node("OrganicDorsalPlate", mesh_ids["Rib"], (0.0, 1.04, 0.16), rotation=(0.0, 0.0, 0.05), extras={"surface": "layered_shell_break"})
    for side in (-1.0, 1.0):
        side_name = "L" if side < 0.0 else "R"
        add_node("RazorhoundCheekPlate%s" % side_name, mesh_ids["CheekLobe"], (side * 0.44, 0.82, -0.94))
        add_node("RazorhoundEar%s" % side_name, mesh_ids["Ear"], (side * 0.28, 1.14, -0.9), rotation=(0.0, 0.0, side * 0.28))
        add_node("RazorhoundEye%s" % side_name, mesh_ids["Eye"], (side * 0.2, 1.02, -1.27), extras={"socket_type": "threat_eye"})
        # This node is parented to the head, so keep the eye-guard placement
        # head-local; the target world position remains around y=1.1, z=-1.22.
        add_node("RazorhoundBrowGuard%s" % side_name, mesh_ids["BrowGuard"], (side * 0.2, 0.26, -0.4), rotation=(0.0, side * 0.08, side * 0.12), parent=head, extras={"surface": "folded_eye_guard"})
        add_node("RazorhoundFang%s" % side_name, mesh_ids["Fang"], (side * 0.17, 0.54, -1.45), rotation=(0.78, 0.0, side * 0.1))
    for index in range(4):
        z = -0.5 + index * 0.38
        add_node("RazorhoundSpine%d" % index, mesh_ids["Spine"], (0.0, 1.18 + (index % 2) * 0.08, z), rotation=(0.0, 0.0, -0.18 + index * 0.11))
    for index in range(3):
        z = -0.58 + index * 0.56
        for side in (-1.0, 1.0):
            side_name = "L" if side < 0.0 else "R"
            add_node("RazorhoundLeg%s%d" % (side_name, index), mesh_ids["Leg"], (side * 0.55, 0.4, z), rotation=(0.0, 0.0, side * 0.74))
            add_node("RazorhoundTalon%s%d" % (side_name, index), mesh_ids["Talon"], (side * 0.86, 0.14, z - 0.04), rotation=(0.0, 0.0, side * 0.42))
    add_node("RazorhoundTail", mesh_ids["Tail"], (0.0, 0.64, 1.12), rotation=(-0.42, 0.0, 0.0), extras={"socket_type": "tail"})
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "razorhound.predator.v1", "source": "original_shared_mesh_builder"})

    node_index = {node["name"]: index for index, node in enumerate(nodes)}
    if len(node_index) != len(nodes):
        raise RuntimeError("Razorhound nodes must have globally unique stable names")

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

    def rotation_channel(target: str, times: list[float], frames: Sequence[Sequence[float]]) -> tuple[str, str, list[float], list[float]]:
        return target, "rotation", times, [value for frame in frames for value in quat(frame)]

    def ear_channels(times: list[float], fold: Sequence[float]) -> list[tuple[str, str, list[float], list[float]]]:
        return [
            rotation_channel(
                "RazorhoundEar%s" % side_name,
                times,
                [(0.0, 0.0, side * (0.28 + delta)) for delta in fold],
            )
            for side, side_name in ((-1.0, "L"), (1.0, "R"))
        ]

    def cheek_channels(times: list[float], motion: Sequence[float], axis: str = "y") -> list[tuple[str, str, list[float], list[float]]]:
        channels = []
        for side, side_name in ((-1.0, "L"), (1.0, "R")):
            frames = [(0.0, side * value, 0.0) if axis == "y" else (0.0, 0.0, side * value) for value in motion]
            channels.append(rotation_channel("RazorhoundCheekPlate%s" % side_name, times, frames))
        return channels

    def fang_channels(times: list[float], pitch: Sequence[float], flare: Sequence[float]) -> list[tuple[str, str, list[float], list[float]]]:
        return [
            rotation_channel(
                "RazorhoundFang%s" % side_name,
                times,
                [(pitch[index], 0.0, side * flare[index]) for index in range(len(times))],
            )
            for side, side_name in ((-1.0, "L"), (1.0, "R"))
        ]

    def spine_channels(times: list[float], offsets: Sequence[float]) -> list[tuple[str, str, list[float], list[float]]]:
        return [
            rotation_channel(
                "RazorhoundSpine%d" % index,
                times,
                [(0.0, 0.0, -0.18 + index * 0.11 + offset) for offset in offsets],
            )
            for index in range(4)
        ]

    def leg_channels(times: list[float], forward: float, back: float) -> list[tuple[str, str, list[float], list[float]]]:
        channels = []
        for index in range(3):
            for side, side_name in ((-1.0, "L"), (1.0, "R")):
                gait_sign = 1.0 if (index + (0 if side < 0.0 else 1)) % 2 == 0 else -1.0
                channels.append(rotation_channel(
                    "RazorhoundLeg%s%d" % (side_name, index),
                    times,
                    [
                        (forward * gait_sign, 0.0, side * 0.74),
                        (back * gait_sign, 0.0, side * 0.74),
                        (forward * gait_sign, 0.0, side * 0.74),
                    ],
                ))
        return channels

    idle_times = [0.0, 0.8, 1.6]
    walk_times = [0.0, 0.22, 0.44]
    attack_times = [0.0, 0.24, 0.48]
    hit_times = [0.0, 0.10, 0.24]
    feed_times = [0.0, 0.3, 0.6]
    nest_times = [0.0, 0.5, 1.0]
    death_times = [0.0, 0.28, 0.64]

    animations = [
        animation("Idle", [
            ("RazorhoundModel", "translation", idle_times, [0.0, 0.0, 0.0, 0.0, 0.014, 0.0, 0.0, 0.0, 0.0]),
            rotation_channel("Torso", idle_times, [(0.012, 0.0, 0.0), (-0.012, 0.0, 0.0), (0.012, 0.0, 0.0)]),
            rotation_channel("RazorhoundTail", idle_times, [(-0.42, 0.04, 0.0), (-0.38, -0.08, 0.0), (-0.42, 0.04, 0.0)]),
        ] + ear_channels(idle_times, [0.0, -0.07, 0.0])
          + cheek_channels(idle_times, [0.02, -0.02, 0.02])
          + spine_channels(idle_times, [0.0, -0.06, 0.0])),
        animation("Walk", leg_channels(walk_times, 0.22, -0.22) + [
            rotation_channel("Torso", walk_times, [(0.05, 0.0, 0.0), (-0.05, 0.0, 0.0), (0.05, 0.0, 0.0)]),
            rotation_channel("RazorhoundTail", walk_times, [(-0.32, 0.0, 0.0), (-0.5, 0.0, 0.0), (-0.32, 0.0, 0.0)]),
        ] + spine_channels(walk_times, [0.06, -0.12, 0.06])
          + cheek_channels(walk_times, [0.08, -0.08, 0.08], "z")
          + fang_channels(walk_times, [0.78, 0.70, 0.78], [0.10, 0.06, 0.10])),
        animation("Attack", [
            ("RazorhoundSnout", "translation", attack_times, [0.0, 0.78, -1.18, 0.0, 0.75, -1.3, 0.0, 0.78, -1.18]),
            rotation_channel("Torso", attack_times, [(0.05, 0.0, 0.0), (-0.12, 0.0, 0.0), (0.05, 0.0, 0.0)]),
            rotation_channel("RazorhoundTail", attack_times, [(-0.42, 0.0, 0.0), (-0.2, 0.0, 0.0), (-0.42, 0.0, 0.0)]),
        ] + cheek_channels(attack_times, [0.08, 0.18, 0.08], "z")
          + fang_channels(attack_times, [0.78, 0.58, 0.78], [0.10, 0.16, 0.10])
          + ear_channels(attack_times, [0.0, -0.18, 0.0])),
        animation("Hit", [
            ("RazorhoundModel", "translation", hit_times, [0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.0, 0.0]),
            rotation_channel("Torso", hit_times, [(0.0, 0.0, 0.0), (-0.16, 0.08, 0.0), (0.0, 0.0, 0.0)]),
            rotation_channel("RazorhoundTail", hit_times, [(-0.42, 0.0, 0.0), (-0.28, 0.12, 0.0), (-0.42, 0.0, 0.0)]),
        ] + ear_channels(hit_times, [0.0, 0.18, 0.0])
          + cheek_channels(hit_times, [0.0, 0.18, 0.0])),
        animation("Feed", [
            ("RazorhoundModel", "translation", feed_times, [0.0, 0.0, 0.0, 0.0, -0.12, -0.08, 0.0, 0.0, 0.0]),
            rotation_channel("Torso", feed_times, [(0.02, 0.0, 0.0), (0.16, 0.0, 0.0), (0.02, 0.0, 0.0)]),
            ("RazorhoundSnout", "translation", feed_times, [0.0, 0.78, -1.18, 0.0, 0.7, -1.12, 0.0, 0.78, -1.18]),
        ] + fang_channels(feed_times, [0.78, 0.90, 0.78], [0.10, 0.10, 0.10])
          + ear_channels(feed_times, [0.0, 0.10, 0.0])),
        animation("Nest", [
            ("RazorhoundModel", "translation", nest_times, [0.0, 0.0, 0.0, 0.0, 0.08, 0.0, 0.0, 0.0, 0.0]),
            rotation_channel("Torso", nest_times, [(0.025, 0.0, 0.0), (-0.025, 0.0, 0.0), (0.025, 0.0, 0.0)]),
            rotation_channel("RazorhoundTail", nest_times, [(-0.42, 0.0, 0.0), (-0.56, 0.0, 0.0), (-0.42, 0.0, 0.0)]),
        ] + ear_channels(nest_times, [0.0, -0.10, 0.0])
          + spine_channels(nest_times, [0.0, 0.10, 0.0])),
        animation("Retreat", leg_channels(walk_times, 0.28, -0.16) + [
            rotation_channel("Torso", walk_times, [(0.12, 0.0, 0.0), (0.22, 0.0, 0.0), (0.12, 0.0, 0.0)]),
            rotation_channel("RazorhoundTail", walk_times, [(-0.42, 0.0, 0.0), (-0.64, 0.0, 0.0), (-0.42, 0.0, 0.0)]),
        ] + ear_channels(walk_times, [0.0, -0.20, 0.0])
          + cheek_channels(walk_times, [0.0, 0.16, 0.0])),
        animation("Death", [
            rotation_channel("RazorhoundModel", death_times, [(0.0, 0.0, 0.0), (0.34, 0.08, 0.2), (0.78, 0.16, 0.42)]),
            rotation_channel("Torso", death_times, [(0.0, 0.0, 0.0), (0.18, 0.0, 0.0), (0.46, 0.0, 0.0)]),
            rotation_channel("RazorhoundTail", death_times, [(-0.42, 0.0, 0.0), (-0.18, 0.12, 0.0), (0.12, 0.28, 0.0)]),
        ] + ear_channels(death_times, [0.0, 0.18, 0.34])),
    ]

    for clip in animations:
        targets = [(channel["target"]["node"], channel["target"]["path"]) for channel in clip["channels"]]
        if len(targets) != len(set(targets)):
            raise RuntimeError(f"Razorhound {clip['name']} contains duplicate animation target paths")
    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright deterministic Razorhound HD PBR builder"},
        "scene": 0, "scenes": [{"name": "Razorhound", "nodes": [0]}], "nodes": nodes, "meshes": meshes, "materials": materials,
        "images": [
            {"uri": TEXTURE_URIS[key], "name": "Razorhound %s" % key}
            for key in ("shell_base", "tissue_base", "shell_normal", "tissue_normal", "shell_orm", "tissue_orm", "emissive")
        ],
        "textures": [{"sampler": 0, "source": index} for index in range(7)],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
        "accessors": builder.accessors, "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": "razorhound.predator.v1",
            "surface_profile": "shared_organic_pbr_v1",
            "required_nodes": [
                "RazorhoundModel", "Torso", "TorsoCore", "RazorhoundSnout", "RazorhoundMuzzleGuard",
                "RazorhoundThroatLobe", "RazorhoundNostrilL", "RazorhoundNostrilR",
                "RazorhoundCheekPlateL", "RazorhoundCheekPlateR", "RazorhoundBrowGuardL", "RazorhoundBrowGuardR",
                "RazorhoundFangL", "RazorhoundFangR", "RazorhoundSpine0", "RazorhoundTail", "ProductionAssetMarker",
            ],
            "animation_clips": ["Idle", "Walk", "Attack", "Hit", "Feed", "Nest", "Retreat", "Death"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
