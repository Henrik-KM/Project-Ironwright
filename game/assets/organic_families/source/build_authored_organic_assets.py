"""Build the remaining original high-definition organic family shells.

The five assets in this builder deliberately share a small production mesh kit
while keeping distinct silhouettes and stable anatomy names. They are imported
as presentation shells; gameplay collision, ecology and tier data remain owned
by the runtime enemy actor.
"""

from __future__ import annotations

import base64
import json
import sys
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parent
ASSET_ROOT = SOURCE_DIR.parents[1]
sys.path.insert(0, str(ASSET_ROOT / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, add_box, add_cylinder, add_uv_sphere, quat  # noqa: E402


FAMILIES = {
    "roofleaper": {
        "display": "Roofleaper",
        "asset_id": "roofleaper.ambusher.v1",
        "colors": ([0.035, 0.055, 0.07, 1.0], [0.16, 0.22, 0.25, 1.0], [0.10, 0.28, 0.34, 1.0], [0.48, 0.39, 0.28, 1.0], [0.75, 0.22, 0.04, 1.0], [0.30, 0.09, 0.08, 1.0]),
        "socket_contract": "crown, wing_membranes, talons, threat_eyes",
    },
    "glassmoth": {
        "display": "Glassmoth",
        "asset_id": "glassmoth.swarm.v1",
        "colors": ([0.025, 0.07, 0.075, 1.0], [0.19, 0.38, 0.39, 1.0], [0.27, 0.16, 0.34, 1.0], [0.64, 0.58, 0.43, 1.0], [0.12, 0.72, 0.68, 1.0], [0.20, 0.24, 0.26, 1.0]),
        "socket_contract": "wing_pairs, antennae, luminous_eyes, thorax",
    },
    "miremaw": {
        "display": "Miremaw",
        "asset_id": "miremaw.amphibious.v1",
        "colors": ([0.035, 0.065, 0.045, 1.0], [0.22, 0.28, 0.18, 1.0], [0.25, 0.07, 0.045, 1.0], [0.52, 0.44, 0.29, 1.0], [0.82, 0.32, 0.05, 1.0], [0.28, 0.12, 0.075, 1.0]),
        "socket_contract": "maw, gill_fan, water_fins, jaw_hooks",
    },
    "carrionbell": {
        "display": "Carrion Bell",
        "asset_id": "carrionbell.signal.v1",
        "colors": ([0.065, 0.035, 0.06, 1.0], [0.25, 0.12, 0.22, 1.0], [0.35, 0.08, 0.24, 1.0], [0.56, 0.45, 0.32, 1.0], [0.9, 0.22, 0.14, 1.0], [0.34, 0.09, 0.16, 1.0]),
        "socket_contract": "resonator, bell_mantle, signal_tendrils, crown_plate",
    },
    "rootweaver": {
        "display": "Rootweaver",
        "asset_id": "rootweaver.route_controller.v1",
        "colors": ([0.035, 0.05, 0.04, 1.0], [0.20, 0.23, 0.14, 1.0], [0.29, 0.06, 0.12, 1.0], [0.48, 0.38, 0.24, 1.0], [0.16, 0.72, 0.63, 1.0], [0.28, 0.08, 0.09, 1.0]),
        "socket_contract": "root_arms, route_spines, spore_fan, crown_oculi",
    },
}


def build_family(name: str, spec: dict) -> None:
    builder = BufferBuilder()
    wet, shell, membrane, bone, eye, tendon = range(6)
    colors = spec["colors"]
    materials = [
        {"name": f"{spec['display']} wet shell", "pbrMetallicRoughness": {"baseColorFactor": list(colors[0]), "metallicFactor": 0.18, "roughnessFactor": 0.32}},
        {"name": f"{spec['display']} layered plate", "pbrMetallicRoughness": {"baseColorFactor": list(colors[1]), "metallicFactor": 0.14, "roughnessFactor": 0.42}},
        {"name": f"{spec['display']} membrane", "pbrMetallicRoughness": {"baseColorFactor": list(colors[2]), "metallicFactor": 0.02, "roughnessFactor": 0.58}},
        {"name": f"{spec['display']} bone", "pbrMetallicRoughness": {"baseColorFactor": list(colors[3]), "metallicFactor": 0.0, "roughnessFactor": 0.62}},
        {"name": f"{spec['display']} threat light", "pbrMetallicRoughness": {"baseColorFactor": list(colors[4]), "metallicFactor": 0.0, "roughnessFactor": 0.22}, "emissiveFactor": [1.0, 0.18, 0.04]},
        {"name": f"{spec['display']} tendon", "pbrMetallicRoughness": {"baseColorFactor": list(colors[5]), "metallicFactor": 0.0, "roughnessFactor": 0.55}},
    ]
    meshes: list[dict] = []

    def mesh(mesh_name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": mesh_name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    mesh_ids = {
        "Core": mesh("Core", add_uv_sphere(builder, 0.62, wet, 16, 26)),
        "Segment": mesh("Segment", add_uv_sphere(builder, 0.48, shell, 14, 24)),
        "Plate": mesh("Plate", add_box(builder, (1.52, 0.16, 0.28), shell)),
        "Membrane": mesh("Membrane", add_box(builder, (1.26, 0.045, 1.08), membrane)),
        "Bone": mesh("Bone", add_cylinder(builder, 0.09, 0.86, bone, 14)),
        "LongBone": mesh("LongBone", add_cylinder(builder, 0.065, 1.35, bone, 14)),
        "Tendon": mesh("Tendon", add_cylinder(builder, 0.07, 1.15, tendon, 14)),
        "Eye": mesh("Eye", add_uv_sphere(builder, 0.095, eye, 12, 18)),
        "Soft": mesh("Soft", add_uv_sphere(builder, 0.34, membrane, 14, 22)),
        "Fastener": mesh("Fastener", add_uv_sphere(builder, 0.045, bone, 8, 12)),
    }

    root_name = f"{name.capitalize()}Model"
    nodes: list[dict] = [{
        "name": root_name,
        "children": [],
        "extras": {
            "ironwright_asset_id": spec["asset_id"],
            "asset_quality": "authored_high_definition",
            "socket_contract": spec["socket_contract"],
        },
    }]

    def add_node(
        node_name: str,
        mesh_id: int | None = None,
        translation: Sequence[float] = (0.0, 0.0, 0.0),
        rotation: Sequence[float] = (0.0, 0.0, 0.0),
        scale: Sequence[float] | None = None,
        extras: dict | None = None,
        parent: int = 0,
    ) -> int:
        entry: dict = {"name": node_name, "translation": list(translation)}
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
    add_node("TorsoCore", mesh_ids["Core"], (0.0, 0.92, 0.08), scale=(1.45, 0.82, 1.62), parent=torso, extras={"release_material_family": "chitin"})
    for index in range(4):
        z = -0.62 + index * 0.43
        add_node(f"TorsoSegment{index}", mesh_ids["Segment"], (0.0, 0.89 - index * 0.018, z), scale=(1.22 - index * 0.04, 0.72, 1.25 - index * 0.03), parent=torso)
        add_node(f"{name.capitalize()}ThoraxRib", mesh_ids["Plate"], (0.0, 1.37 - index * 0.035, z), rotation=(0.0, 0.0, 0.03 * (index - 1)), scale=(1.0, 1.0, 0.74), parent=torso, extras={"surface": "layered_shell_break"} if index == 1 else None)
        add_node("ThoraxFastener", mesh_ids["Fastener"], (-0.56, 1.18, z), parent=torso)
        add_node("ThoraxFastener", mesh_ids["Fastener"], (0.56, 1.18, z), parent=torso)
    dorsal = add_node("OrganicDorsalPlate", mesh_ids["Plate"], (-0.12, 1.54, 0.18), rotation=(0.0, 0.0, -0.04), scale=(1.08, 1.0, 1.4), extras={"surface": "layered_shell_break"})

    if name == "roofleaper":
        add_node("RoofleaperCrown", mesh_ids["Soft"], (0.0, 1.3, -1.02), scale=(1.15, 0.82, 1.05), extras={"socket_type": "crown"})
        for side in (-1.0, 1.0):
            suffix = "L" if side < 0 else "R"
            add_node(f"RoofleaperWing{suffix}", mesh_ids["Membrane"], (side * 0.92, 1.18, 0.05), rotation=(0.0, side * 0.18, side * 0.1), scale=(1.15, 1.0, 1.1), extras={"socket_type": "wing_membrane"})
            add_node(f"RoofleaperWingVein{suffix}", mesh_ids["Bone"], (side * 1.12, 1.2, 0.05), rotation=(0.0, side * 0.35, side * 0.72), scale=(0.6, 1.0, 1.0))
            add_node(f"RoofleaperTalons{suffix}", mesh_ids["LongBone"], (side * 0.54, 0.3, -0.72), rotation=(side * 0.76, 0.0, side * 0.18), extras={"socket_type": "talon"})
            add_node(f"RoofleaperEye{suffix}", mesh_ids["Eye"], (side * 0.22, 1.5, -1.45), extras={"socket_type": "threat_eye"})
        walk_node = "RoofleaperTalonsL"
        attack_node = "RoofleaperWingL"
    elif name == "glassmoth":
        add_node("GlassmothThorax", mesh_ids["Soft"], (0.0, 1.12, 0.18), scale=(0.92, 1.42, 0.88), extras={"socket_type": "thorax"})
        for side in (-1.0, 1.0):
            suffix = "L" if side < 0 else "R"
            for level in range(2):
                add_node(f"GlassmothWing{suffix}{level}", mesh_ids["Membrane"], (side * (0.88 + level * 0.16), 1.18 + level * 0.16, 0.12 + level * 0.18), rotation=(0.0, side * (0.2 + level * 0.08), side * 0.18), scale=(1.3 - level * 0.12, 0.82, 1.0), extras={"socket_type": "wing_pair"})
            add_node(f"GlassmothAntenna{suffix}", mesh_ids["Tendon"], (side * 0.2, 1.45, -0.98), rotation=(0.48, 0.0, side * 0.22), extras={"socket_type": "antenna"})
            add_node(f"GlassmothOculus{suffix}", mesh_ids["Eye"], (side * 0.2, 1.3, -1.12), extras={"socket_type": "luminous_eye"})
        walk_node = "GlassmothWingL0"
        attack_node = "GlassmothWingR1"
    elif name == "miremaw":
        add_node("MiremawHead", mesh_ids["Soft"], (0.0, 0.78, -1.18), scale=(1.3, 0.8, 1.2), extras={"socket_type": "maw"})
        add_node("MiremawGillFan", mesh_ids["Membrane"], (0.0, 1.25, 0.35), rotation=(0.0, 0.0, 1.5708), scale=(0.72, 1.0, 0.78), extras={"socket_type": "gill_fan"})
        for side in (-1.0, 1.0):
            suffix = "L" if side < 0 else "R"
            add_node(f"MiremawJawHook{suffix}", mesh_ids["LongBone"], (side * 0.42, 0.55, -1.62), rotation=(side * 0.72, 0.0, side * 0.18), extras={"socket_type": "jaw_hook"})
            add_node(f"MiremawWaterFin{suffix}", mesh_ids["Membrane"], (side * 1.08, 0.68, 0.18), rotation=(0.0, side * 0.28, side * 0.08), scale=(0.62, 0.84, 1.1), extras={"socket_type": "water_fin"})
            add_node(f"MiremawEye{suffix}", mesh_ids["Eye"], (side * 0.26, 1.24, -1.62), extras={"socket_type": "threat_eye"})
        walk_node = "MiremawWaterFinL"
        attack_node = "MiremawJawHookL"
    elif name == "carrionbell":
        add_node("CarrionbellMantle", mesh_ids["Soft"], (0.0, 1.18, 0.12), scale=(1.25, 1.55, 1.2), extras={"socket_type": "bell_mantle"})
        add_node("CarrionbellResonator", mesh_ids["Eye"], (0.0, 1.92, -0.35), scale=(1.4, 0.8, 1.0), extras={"socket_type": "resonator"})
        add_node("CarrionbellCrownPlate", mesh_ids["Plate"], (0.0, 2.32, 0.18), rotation=(0.0, 0.0, 0.12), scale=(1.3, 1.0, 0.92), extras={"socket_type": "crown_plate"})
        for index in range(5):
            x = -0.64 + index * 0.32
            add_node(f"CarrionbellSignalTendril{index}", mesh_ids["Tendon"], (x, 0.68, -0.72 - (index % 2) * 0.12), rotation=(0.32, 0.0, (index - 2) * 0.12), extras={"socket_type": "signal_tendril"})
        walk_node = "CarrionbellMantle"
        attack_node = "CarrionbellResonator"
    else:
        add_node("RootweaverCrown", mesh_ids["Soft"], (0.0, 1.55, -0.42), scale=(1.28, 1.2, 1.18), extras={"socket_type": "crown_oculi"})
        add_node("RootweaverSporeFan", mesh_ids["Membrane"], (0.0, 1.76, 0.24), rotation=(0.0, 0.0, 1.5708), scale=(1.0, 1.0, 1.24), extras={"socket_type": "spore_fan"})
        for side in (-1.0, 1.0):
            suffix = "L" if side < 0 else "R"
            add_node(f"RootweaverArm{suffix}", mesh_ids["LongBone"], (side * 0.82, 0.95, -0.2), rotation=(0.0, side * 0.2, side * 0.8), scale=(1.0, 1.0, 1.28), extras={"socket_type": "root_arm"})
            add_node(f"RootweaverRouteSpine{suffix}", mesh_ids["Bone"], (side * 0.86, 1.34, 0.4), rotation=(0.0, side * 0.22, side * 0.28), extras={"socket_type": "route_spine"})
            add_node(f"RootweaverOculus{suffix}", mesh_ids["Eye"], (side * 0.26, 1.92, -0.82), extras={"socket_type": "crown_oculus"})
        walk_node = "RootweaverArmL"
        attack_node = "RootweaverSporeFan"

    add_node("ProductionAssetMarker", None, extras={"asset_contract": spec["asset_id"], "source": "original_shared_mesh_builder"})
    node_index = {node["name"]: index for index, node in enumerate(nodes)}

    def animation(animation_name: str, target_name: str, path: str, times: list[float], values: list[float]) -> dict:
        type_name, width = (("VEC3", 3) if path == "translation" else ("VEC4", 4))
        time_accessor = builder.accessor(times, 5126, "SCALAR", len(times), minimum=[min(times)], maximum=[max(times)])
        output_accessor = builder.accessor(values, 5126, type_name, len(values) // width)
        return {"name": animation_name, "samplers": [{"input": time_accessor, "output": output_accessor, "interpolation": "LINEAR"}], "channels": [{"sampler": 0, "target": {"node": node_index[target_name], "path": path}}]}

    animations = [
        animation("Idle", root_name, "translation", [0.0, 0.8, 1.6], [0.0, 0.0, 0.0, 0.0, 0.014, 0.0, 0.0, 0.0, 0.0]),
        animation("Walk", walk_node, "rotation", [0.0, 0.22, 0.44], quat((0.2, 0.0, 0.0)) + quat((-0.2, 0.0, 0.0)) + quat((0.2, 0.0, 0.0))),
        animation("Attack", attack_node, "translation", [0.0, 0.24, 0.48], [0.0, 0.0, 0.0, 0.0, 0.0, -0.16, 0.0, 0.0, 0.0]),
    ]
    document = {
        "asset": {"version": "2.0", "generator": f"Project Ironwright original {spec['display']} asset builder"},
        "scene": 0,
        "scenes": [{"name": spec["display"], "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": spec["asset_id"],
            "required_nodes": [root_name, "Torso", "TorsoCore", "OrganicDorsalPlate", "ProductionAssetMarker"],
            "animation_clips": ["Idle", "Walk", "Attack"],
        },
    }
    output_path = ASSET_ROOT / name / f"{name}.gltf"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {output_path} with {len(nodes)} named nodes and {len(meshes)} meshes")


def main() -> None:
    for name, spec in FAMILIES.items():
        build_family(name, spec)


if __name__ == "__main__":
    main()
