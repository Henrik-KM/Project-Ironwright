"""Build the original high-definition Skitterling organic glTF."""

from __future__ import annotations

import base64
import json
import sys
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, add_beveled_box, add_box, add_cylinder, add_ellipsoid, add_uv_sphere, quat  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "skitterling.gltf"
TEXTURE_SIZE = 1024
TEXTURE_URIS = [
    "../organic_families/textures/organic_shell_base_color.png",
    "../organic_families/textures/organic_shell_normal.png",
    "../organic_families/textures/organic_shell_orm.png",
    "../organic_families/textures/organic_tissue_base_color.png",
    "../organic_families/textures/organic_tissue_normal.png",
    "../organic_families/textures/organic_tissue_orm.png",
    "../organic_families/textures/organic_emissive.png",
]


def organic_material(
    name: str,
    color: Sequence[float],
    metallic: float,
    roughness: float,
    lane: str,
    normal_scale: float,
    emissive: Sequence[float] | None = None,
) -> dict:
    """Bind one family tint to the frozen shared organic PBR surface set."""
    if lane == "shell":
        base_color_texture, normal_texture, orm_texture, maximum_normal_scale = 0, 1, 2, 0.35
    elif lane == "tissue":
        base_color_texture, normal_texture, orm_texture, maximum_normal_scale = 3, 4, 5, 0.22
    elif lane == "signal":
        base_color_texture, normal_texture, orm_texture, maximum_normal_scale = 3, 4, 5, 0.12
    else:
        raise ValueError(f"Unknown organic material lane: {lane}")
    if normal_scale > maximum_normal_scale:
        raise ValueError(f"{name} normal scale {normal_scale} exceeds {lane} ceiling {maximum_normal_scale}")
    entry = {
        "name": name,
        "pbrMetallicRoughness": {
            "baseColorFactor": list(color),
            "baseColorTexture": {"index": base_color_texture},
            "metallicFactor": metallic,
            "roughnessFactor": roughness,
            "metallicRoughnessTexture": {"index": orm_texture},
        },
        "normalTexture": {"index": normal_texture, "scale": normal_scale},
        "occlusionTexture": {"index": orm_texture, "strength": 0.82},
    }
    if emissive is not None:
        if lane != "signal":
            raise ValueError(f"Only genuine signal materials may emit: {name}")
        entry["emissiveFactor"] = list(emissive)
        entry["emissiveTexture"] = {"index": 6}
    return entry


def main() -> None:
    builder = BufferBuilder()
    materials = [
        organic_material("Skitterling wet carapace", [0.09, 0.12, 0.125, 1.0], 0.24, 0.3, "shell", 0.34),
        organic_material("Skitterling shell ridge", [0.28, 0.31, 0.26, 1.0], 0.14, 0.4, "shell", 0.32),
        organic_material("Skitterling tendon", [0.27, 0.065, 0.08, 1.0], 0.0, 0.52, "tissue", 0.18),
        organic_material("Skitterling bone", [0.58, 0.46, 0.3, 1.0], 0.0, 0.58, "shell", 0.25),
        organic_material("Skitterling scavenger eye", [0.42, 0.16, 0.02, 1.0], 0.0, 0.2, "signal", 0.10, [1.0, 0.13, 0.015]),
        organic_material("Skitterling membrane", [0.14, 0.025, 0.06, 0.82], 0.0, 0.38, "tissue", 0.16),
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int, int, int]) -> int:
        position, normal, uv, tangent, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal, "TEXCOORD_0": uv, "TANGENT": tangent}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    wet, shell, tendon, bone, eye, membrane = range(6)
    mesh_ids = {
        "Core": mesh("Core", add_uv_sphere(builder, 0.38, wet, 20, 32)),
        "Segment": mesh("Segment", add_uv_sphere(builder, 0.3, shell, 18, 28)),
        "Ridge": mesh("Ridge", add_beveled_box(builder, (0.72, 0.12, 0.18), shell, 0.025)),
        "Antenna": mesh("Antenna", add_cylinder(builder, 0.035, 0.72, tendon, 24)),
        "Mandible": mesh("Mandible", add_cylinder(builder, 0.045, 0.56, bone, 24)),
        "Eye": mesh("Eye", add_uv_sphere(builder, 0.065, eye, 16, 24)),
        "Leg": mesh("Leg", add_cylinder(builder, 0.06, 0.78, tendon, 24)),
        "Claw": mesh("Claw", add_cylinder(builder, 0.04, 0.42, bone, 24)),
        # The sensory fans are small lateral skirt vanes, not dorsal sails.
        # Their broad axes stay in the torso's horizontal plane so no gallery
        # angle or action clip can turn them into upright red bars.
        "Fan": mesh("Fan", add_ellipsoid(builder, (0.14, 0.025, 0.10), membrane, rings=16, sides=36)),
        "Fastener": mesh("Fastener", add_uv_sphere(builder, 0.03, bone, 16, 24)),
        "CarapaceCap": mesh("CarapaceCap", add_beveled_box(builder, (0.42, 0.08, 0.14), shell, 0.02)),
        # A shallow shell tie anchors each vane against the flank. A compact
        # beveled plate avoids the long cylindrical silhouette of the former
        # rib while retaining authored UV, normal and tangent data.
        "SensoryRib": mesh("SensoryRib", add_beveled_box(builder, (0.16, 0.024, 0.036), bone, 0.006)),
        # A small smooth cephalic envelope keeps the common Tier-I silhouette
        # readable at tactical distance without hiding the paired eyes.
        "HeadShield": mesh("HeadShield", add_ellipsoid(builder, (0.30, 0.12, 0.14), shell, rings=18, sides=36)),
        "HeadRidge": mesh("HeadRidge", add_beveled_box(builder, (0.38, 0.06, 0.08), bone, 0.018)),
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
        add_node("SkitterlingCarapaceCap%d" % index, mesh_ids["CarapaceCap"], (0.0, 0.87, z - 0.02), rotation=(0.0, 0.0, 0.04), scale=(0.82 - index * 0.04, 1.0, 0.82), parent=torso, extras={"surface": "shell_cap"})
        add_node("SkitterlingFastenerL%d" % index, mesh_ids["Fastener"], (-0.32, 0.68, z), parent=torso)
        add_node("SkitterlingFastenerR%d" % index, mesh_ids["Fastener"], (0.32, 0.68, z), parent=torso)
    add_node("OrganicDorsalPlate", mesh_ids["Ridge"], (-0.1, 0.92, 0.18), scale=(1.1, 0.9, 1.2), extras={"surface": "layered_shell_break"})
    add_node("SkitterlingHeadShield", mesh_ids["HeadShield"], (0.0, 0.72, -0.79), extras={"surface": "cephalic_shell"})
    add_node("SkitterlingHeadRidge", mesh_ids["HeadRidge"], (0.0, 0.84, -0.75), extras={"surface": "cephalic_ridge"})

    for side in (-1.0, 1.0):
        suffix = "L" if side < 0 else "R"
        add_node("SkitterlingEye%s" % suffix, mesh_ids["Eye"], (side * 0.16, 0.8, -0.92), extras={"socket_type": "scavenger_eye"})
        add_node("SkitterlingAntenna%s" % suffix, mesh_ids["Antenna"], (side * 0.2, 0.74, -0.82), rotation=(0.56, 0.0, side * 0.18), extras={"socket_type": "antenna"})
        add_node("SkitterlingAntennaJoint%s" % suffix, mesh_ids["Fastener"], (side * 0.2, 0.76, -0.84), extras={"surface": "antenna_socket"})
        add_node("SkitterlingMandible%s" % suffix, mesh_ids["Mandible"], (side * 0.18, 0.42, -1.02), rotation=(0.8, 0.0, side * 0.22), extras={"socket_type": "mandible"})
        add_node("SkitterlingMandiblePlate%s" % suffix, mesh_ids["CarapaceCap"], (side * 0.2, 0.5, -1.0), rotation=(0.8, 0.0, side * 0.22), scale=(0.58, 1.0, 0.7), extras={"surface": "mandible_plate"})

    sensory_fan_rotations: dict[int, tuple[float, float, float]] = {}
    for index in range(4):
        # Two paired rows form a restrained skirt along the front/mid torso
        # flanks. Roll is deliberately zero: only shallow pitch and yaw may
        # articulate these vanes, so their width can never become screen-up.
        side = -1.0 if index % 2 == 0 else 1.0
        row = index // 2
        fan_rotation = (0.010 - row * 0.006, side * (0.14 + row * 0.025), 0.0)
        sensory_fan_rotations[index] = fan_rotation
        z = -0.30 + row * 0.27
        y = 0.62 - row * 0.025
        add_node(
            "SkitterlingSensoryFan%d" % index,
            mesh_ids["Fan"],
            (side * (0.39 + row * 0.01), y, z),
            rotation=fan_rotation,
            scale=(1.0 - row * 0.06, 1.0, 1.0 - row * 0.04),
            extras={"surface": "sensory_membrane", "attachment": "torso_flank"},
            parent=torso,
        )
        add_node(
            "SkitterlingSensoryRib%d" % index,
            mesh_ids["SensoryRib"],
            (side * (0.32 + row * 0.01), y - 0.014, z),
            rotation=(0.0, side * (0.06 + row * 0.015), 0.0),
            extras={"surface": "sensory_rib", "attachment": "torso_flank"},
            parent=torso,
        )

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

    def fan_motion(
        times: list[float],
        pitch_delta: float,
        yaw_delta: float,
    ) -> list[tuple[str, str, list[float], list[float]]]:
        """Move the complete flank skirt with pitch/yaw only and zero roll."""
        channels: list[tuple[str, str, list[float], list[float]]] = []
        for index in range(4):
            side = -1.0 if index % 2 == 0 else 1.0
            base = sensory_fan_rotations[index]
            articulated = (base[0] + pitch_delta, base[1] + side * yaw_delta, 0.0)
            channels.append((
                "SkitterlingSensoryFan%d" % index,
                "rotation",
                times,
                quat(base) + quat(articulated) + quat(base),
            ))
        return channels

    animations = [
        animation("Idle", [
            ("SkitterlingModel", "translation", [0.0, 0.7, 1.4], [0.0, 0.0, 0.0, 0.0, 0.01, 0.0, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.7, 1.4], quat((0.015, 0.0, 0.0)) + quat((-0.015, 0.0, 0.0)) + quat((0.015, 0.0, 0.0))),
            ("SkitterlingAntennaL", "rotation", [0.0, 0.7, 1.4], quat((0.56, 0.0, -0.18)) + quat((0.52, 0.0, -0.06)) + quat((0.56, 0.0, -0.18))),
            ("SkitterlingAntennaR", "rotation", [0.0, 0.7, 1.4], quat((0.56, 0.0, 0.18)) + quat((0.52, 0.0, 0.06)) + quat((0.56, 0.0, 0.18))),
        ] + fan_motion([0.0, 0.7, 1.4], 0.012, 0.018)),
        animation("Walk", [
            ("SkitterlingLegL0", "rotation", [0.0, 0.18, 0.36], quat((0.22, 0.0, 0.0)) + quat((-0.22, 0.0, 0.0)) + quat((0.22, 0.0, 0.0))),
            ("Torso", "rotation", [0.0, 0.18, 0.36], quat((0.045, 0.0, 0.0)) + quat((-0.045, 0.0, 0.0)) + quat((0.045, 0.0, 0.0))),
            ("SkitterlingLegR0", "rotation", [0.0, 0.18, 0.36], quat((-0.22, 0.0, 0.0)) + quat((0.22, 0.0, 0.0)) + quat((-0.22, 0.0, 0.0))),
            ("SkitterlingLegL1", "rotation", [0.0, 0.18, 0.36], quat((-0.18, 0.0, 0.0)) + quat((0.18, 0.0, 0.0)) + quat((-0.18, 0.0, 0.0))),
            ("SkitterlingLegR1", "rotation", [0.0, 0.18, 0.36], quat((0.18, 0.0, 0.0)) + quat((-0.18, 0.0, 0.0)) + quat((0.18, 0.0, 0.0))),
        ] + fan_motion([0.0, 0.18, 0.36], 0.015, 0.020)),
        animation("Attack", [
            ("SkitterlingMandibleL", "translation", [0.0, 0.2, 0.4], [0.0, 0.42, -1.02, 0.0, 0.42, -1.16, 0.0, 0.42, -1.02]),
            ("Torso", "rotation", [0.0, 0.2, 0.4], quat((0.04, 0.0, 0.0)) + quat((-0.1, 0.0, 0.0)) + quat((0.04, 0.0, 0.0))),
            ("SkitterlingMandibleR", "translation", [0.0, 0.2, 0.4], [0.0, 0.42, -1.02, 0.0, 0.42, -1.16, 0.0, 0.42, -1.02]),
            ("SkitterlingMandiblePlateL", "rotation", [0.0, 0.2, 0.4], quat((0.8, 0.0, -0.22)) + quat((0.72, 0.0, -0.34)) + quat((0.8, 0.0, -0.22))),
            ("SkitterlingMandiblePlateR", "rotation", [0.0, 0.2, 0.4], quat((0.8, 0.0, 0.22)) + quat((0.72, 0.0, 0.34)) + quat((0.8, 0.0, 0.22))),
        ] + fan_motion([0.0, 0.2, 0.4], -0.020, 0.035)),
        animation("Hit", [
            ("SkitterlingModel", "translation", [0.0, 0.10, 0.24], [0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((-0.16, 0.08, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("SkitterlingAntennaL", "rotation", [0.0, 0.10, 0.24], quat((0.56, 0.0, -0.18)) + quat((0.42, 0.0, -0.36)) + quat((0.56, 0.0, -0.18))),
            ("SkitterlingAntennaR", "rotation", [0.0, 0.10, 0.24], quat((0.56, 0.0, 0.18)) + quat((0.42, 0.0, 0.36)) + quat((0.56, 0.0, 0.18))),
            ("SkitterlingCarapace0", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.04)) + quat((0.10, 0.08, 0.12)) + quat((0.0, 0.0, 0.04))),
        ]),
        animation("Feed", [
            ("SkitterlingModel", "translation", [0.0, 0.3, 0.6], [0.0, 0.0, 0.0, 0.0, -0.12, -0.08, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.3, 0.6], quat((0.02, 0.0, 0.0)) + quat((0.16, 0.0, 0.0)) + quat((0.02, 0.0, 0.0))),
            ("SkitterlingMandibleL", "translation", [0.0, 0.3, 0.6], [0.0, 0.42, -1.02, 0.0, 0.48, -1.12, 0.0, 0.42, -1.02]),
            ("SkitterlingMandibleR", "translation", [0.0, 0.3, 0.6], [0.0, 0.42, -1.02, 0.0, 0.48, -1.12, 0.0, 0.42, -1.02]),
        ] + fan_motion([0.0, 0.3, 0.6], 0.025, -0.015)),
        animation("Nest", [
            ("SkitterlingModel", "translation", [0.0, 0.5, 1.0], [0.0, 0.0, 0.0, 0.0, 0.08, 0.0, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.5, 1.0], quat((0.025, 0.0, 0.0)) + quat((-0.025, 0.0, 0.0)) + quat((0.025, 0.0, 0.0))),
            ("SkitterlingCarapace0", "rotation", [0.0, 0.5, 1.0], quat((0.0, 0.0, 0.04)) + quat((0.0, 0.0, 0.12)) + quat((0.0, 0.0, 0.04))),
            ("SkitterlingAntennaJointL", "rotation", [0.0, 0.5, 1.0], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.12)) + quat((0.0, 0.0, 0.0))),
        ] + fan_motion([0.0, 0.5, 1.0], -0.012, -0.025)),
        animation("Retreat", [
            ("SkitterlingLegL0", "rotation", [0.0, 0.18, 0.36], quat((0.28, 0.0, 0.0)) + quat((-0.16, 0.0, 0.0)) + quat((0.28, 0.0, 0.0))),
            ("Torso", "rotation", [0.0, 0.18, 0.36], quat((0.12, 0.0, 0.0)) + quat((0.22, 0.0, 0.0)) + quat((0.12, 0.0, 0.0))),
            ("SkitterlingLegR0", "rotation", [0.0, 0.18, 0.36], quat((-0.28, 0.0, 0.0)) + quat((0.16, 0.0, 0.0)) + quat((-0.28, 0.0, 0.0))),
            ("SkitterlingAntennaL", "rotation", [0.0, 0.18, 0.36], quat((0.56, 0.0, -0.18)) + quat((0.44, 0.0, -0.02)) + quat((0.56, 0.0, -0.18))),
            ("SkitterlingAntennaR", "rotation", [0.0, 0.18, 0.36], quat((0.56, 0.0, 0.18)) + quat((0.44, 0.0, 0.02)) + quat((0.56, 0.0, 0.18))),
        ] + fan_motion([0.0, 0.18, 0.36], 0.018, 0.025)),
        animation("Death", [
            ("SkitterlingModel", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.34, 0.08, 0.2)) + quat((0.78, 0.16, 0.42))),
            ("Torso", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.18, 0.0, 0.0)) + quat((0.46, 0.0, 0.0))),
            ("SkitterlingCarapace0", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.04)) + quat((0.20, 0.08, 0.16)) + quat((0.46, 0.16, 0.28))),
            ("SkitterlingAntennaL", "rotation", [0.0, 0.28, 0.64], quat((0.56, 0.0, -0.18)) + quat((0.34, 0.0, -0.40)) + quat((0.12, 0.0, -0.52))),
        ]),
    ]
    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Skitterling asset builder"},
        "scene": 0,
        "scenes": [{"name": "Skitterling", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "samplers": [{"name": "Shared organic repeating PBR sampler", "magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
        "images": [
            {"name": "Organic shell base color", "uri": TEXTURE_URIS[0]},
            {"name": "Organic shell tangent-space normal", "uri": TEXTURE_URIS[1]},
            {"name": "Organic shell occlusion roughness metallic", "uri": TEXTURE_URIS[2]},
            {"name": "Organic tissue base color", "uri": TEXTURE_URIS[3]},
            {"name": "Organic tissue tangent-space normal", "uri": TEXTURE_URIS[4]},
            {"name": "Organic tissue occlusion roughness metallic", "uri": TEXTURE_URIS[5]},
            {"name": "Organic signal emissive mask", "uri": TEXTURE_URIS[6]},
        ],
        "textures": [
            {"name": image_name, "sampler": 0, "source": index}
            for index, image_name in enumerate([
                "Organic shell base color", "Organic shell tangent-space normal", "Organic shell occlusion roughness metallic",
                "Organic tissue base color", "Organic tissue tangent-space normal", "Organic tissue occlusion roughness metallic",
                "Organic signal emissive mask",
            ])
        ],
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": "skitterling.scavenger.v1",
            "required_nodes": ["SkitterlingModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "SkitterlingCarapace0", "SkitterlingCarapaceCap0", "SkitterlingHeadShield", "SkitterlingHeadRidge", "SkitterlingAntennaL", "SkitterlingAntennaJointL", "SkitterlingMandibleL", "SkitterlingMandiblePlateL", "SkitterlingSensoryFan0", "SkitterlingSensoryFan3", "SkitterlingSensoryRib0", "SkitterlingSensoryRib3", "ProductionAssetMarker"],
            "animation_clips": ["Idle", "Walk", "Attack", "Hit", "Feed", "Nest", "Retreat", "Death"],
            "material_contract": "shared_textured_metallic_roughness_pbr",
            "surface_profile": "shared_organic_pbr_v1",
            "texture_resolution": TEXTURE_SIZE,
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
