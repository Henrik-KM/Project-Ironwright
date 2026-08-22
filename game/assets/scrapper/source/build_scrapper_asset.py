"""Build the original high-definition Scrapper support-machine glTF."""

from __future__ import annotations

import base64
import json
import math
import sys
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, add_box, add_cylinder, add_uv_sphere, quat  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "scrapper.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Scrapper charcoal chassis", "pbrMetallicRoughness": {"baseColorFactor": [0.045, 0.06, 0.065, 1.0], "metallicFactor": 0.78, "roughnessFactor": 0.44}},
        {"name": "Scrapper worn steel", "pbrMetallicRoughness": {"baseColorFactor": [0.23, 0.28, 0.28, 1.0], "metallicFactor": 0.82, "roughnessFactor": 0.4}},
        {"name": "Scrapper oxide bins", "pbrMetallicRoughness": {"baseColorFactor": [0.3, 0.13, 0.065, 1.0], "metallicFactor": 0.58, "roughnessFactor": 0.6}},
        {"name": "Scrapper cyan status", "pbrMetallicRoughness": {"baseColorFactor": [0.03, 0.2, 0.22, 1.0], "metallicFactor": 0.3, "roughnessFactor": 0.24}, "emissiveFactor": [0.1, 0.85, 0.9]},
        {"name": "Scrapper warm work light", "pbrMetallicRoughness": {"baseColorFactor": [0.42, 0.17, 0.04, 1.0], "metallicFactor": 0.26, "roughnessFactor": 0.36}, "emissiveFactor": [1.0, 0.3, 0.04]},
        {"name": "Scrapper rubber", "pbrMetallicRoughness": {"baseColorFactor": [0.014, 0.018, 0.02, 1.0], "metallicFactor": 0.04, "roughnessFactor": 0.92}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({
            "name": name,
            "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}],
        })
        return len(meshes) - 1

    chassis, steel, oxide, cyan, warm, rubber = range(6)
    mesh_ids = {
        "Chassis": mesh("Chassis", add_box(builder, (1.28, 0.64, 1.5), chassis)),
        "Core": mesh("Core", add_box(builder, (1.04, 0.3, 1.22), oxide)),
        "Plate": mesh("Plate", add_box(builder, (1.16, 0.16, 0.14), steel)),
        "Corner": mesh("Corner", add_cylinder(builder, 0.11, 0.15, steel, 20)),
        "Leg": mesh("Leg", add_cylinder(builder, 0.105, 0.7, rubber, 20)),
        "Foot": mesh("Foot", add_box(builder, (0.26, 0.12, 0.38), oxide)),
        "OpticHousing": mesh("OpticHousing", add_box(builder, (0.44, 0.24, 0.12), chassis)),
        "Optic": mesh("Optic", add_uv_sphere(builder, 0.08, cyan)),
        "Cargo": mesh("Cargo", add_box(builder, (1.0, 0.58, 0.86), chassis)),
        "CargoLip": mesh("CargoLip", add_box(builder, (1.12, 0.08, 0.92), oxide)),
        "Strap": mesh("Strap", add_box(builder, (0.12, 0.48, 0.92), oxide)),
        "Arm": mesh("Arm", add_cylinder(builder, 0.09, 1.2, oxide, 20)),
        "Joint": mesh("Joint", add_uv_sphere(builder, 0.14, chassis)),
        "Claw": mesh("Claw", add_box(builder, (0.32, 0.18, 0.48), steel)),
        "CutHead": mesh("CutHead", add_cylinder(builder, 0.18, 0.32, chassis, 24)),
        "Drum": mesh("Drum", add_cylinder(builder, 0.13, 0.22, oxide, 24)),
        "Magnet": mesh("Magnet", add_cylinder(builder, 0.12, 0.16, cyan, 24)),
        "Fastener": mesh("Fastener", add_cylinder(builder, 0.04, 0.04, warm, 20)),
        "Cable": mesh("Cable", add_cylinder(builder, 0.03, 0.7, rubber, 12)),
        # Salvage-machine close-camera hardware: the hopper rim, tool collars,
        # cutter guard and magnetic pickup details make the work identity read
        # as maintained industrial machinery rather than a cargo box with arms.
        "HopperRim": mesh("HopperRim", add_box(builder, (1.18, 0.08, 0.98), steel)),
        "HopperLatch": mesh("HopperLatch", add_cylinder(builder, 0.06, 0.12, warm, 20)),
        "DismantlerCollar": mesh("DismantlerCollar", add_cylinder(builder, 0.12, 0.08, cyan, 24)),
        "CuttingGuard": mesh("CuttingGuard", add_box(builder, (0.46, 0.1, 0.14), steel)),
        "MagnetCoil": mesh("MagnetCoil", add_cylinder(builder, 0.15, 0.06, cyan, 24)),
        "IntakeTooth": mesh("IntakeTooth", add_box(builder, (0.08, 0.12, 0.18), warm)),
    }

    nodes: list[dict] = [{
        "name": "ScrapperModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "scrapper.salvager.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "sensor, salvage_tool, cargo_mount",
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

    chassis_node = add_node("Chassis", mesh_ids["Chassis"], (0.0, 0.82, 0.0), extras={"surface": "beveled_primary_body"})
    # Preserve the runtime release-material contract used by the procedural
    # chassis: the core is a named child of Chassis, not a sibling mesh.
    add_node("ChassisCore", mesh_ids["Core"], (0.0, 0.08, 0.0), parent=chassis_node)
    add_node("ArmorPlate", mesh_ids["Plate"], (0.0, 1.16, -0.78))
    add_node("LowerChassis", mesh_ids["Plate"], (0.0, 0.4, 0.04))
    add_node("ChassisDetailPanel", mesh_ids["Plate"], (0.0, 1.32, -0.76))
    for side in (-1.0, 1.0):
        for front in (-1.0, 1.0):
            add_node("ChassisCornerCap", mesh_ids["Corner"], (side * 0.56, 0.83, front * 0.61))
            add_node("Leg", mesh_ids["Leg"], (side * 0.48, 0.42, front * 0.42), rotation=(0.0, 0.0, side * 0.2))
            add_node("Foot", mesh_ids["Foot"], (side * 0.58, 0.12, front * 0.42))
    add_node("OpticHousing", mesh_ids["OpticHousing"], (0.0, 1.08, -0.85))
    add_node("Sensor", mesh_ids["Optic"], (0.0, 1.08, -0.94), extras={"socket_type": "sensor"})
    add_node("OpticLens", mesh_ids["Optic"], (0.0, 1.08, -1.0), extras={"socket_type": "optic"})
    add_node("CargoBin", mesh_ids["Cargo"], (0.0, 1.45, 0.25), extras={"socket_type": "cargo_mount"})
    add_node("CargoLip", mesh_ids["CargoLip"], (0.0, 1.78, 0.25))
    add_node("ScrapperHopperRim", mesh_ids["HopperRim"], (0.0, 1.84, 0.25))
    add_node("ScrapperHopperLatch", mesh_ids["HopperLatch"], (0.0, 1.86, -0.24), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("CargoStrap", mesh_ids["Strap"], (0.0, 1.47, 0.25))
    add_node("DeepScrapHopper", mesh_ids["Cargo"], (0.0, 1.45, 0.38))
    for side in (-1.0, 1.0):
        add_node("DismantlerJoint", mesh_ids["Joint"], (side * 0.7, 0.96, -0.34))
        add_node("ScrapperDismantlerCollar%s" % ("Left" if side < 0.0 else "Right"), mesh_ids["DismantlerCollar"], (side * 0.7, 0.96, -0.34), extras={"socket_type": "salvage_tool_collar"})
        add_node("Dismantler", mesh_ids["Arm"], (side * 0.7, 0.96, -0.38), rotation=(0.0, 0.0, side * 1.05), extras={"socket_type": "salvage_tool"})
        add_node("DismantlerTool", mesh_ids["Claw"], (side * 1.12, 0.61, -0.48), rotation=(0.0, 0.0, side * 0.14))
        add_node("ScrapMagnet", mesh_ids["Magnet"], (side * 1.12, 0.62, -0.72), rotation=(math.pi * 0.5, 0.0, 0.0))
        add_node("ScrapperMagnetCoil%s" % ("Left" if side < 0.0 else "Right"), mesh_ids["MagnetCoil"], (side * 1.12, 0.62, -0.82), rotation=(math.pi * 0.5, 0.0, 0.0))
        add_node("ScrapManipulatorCable", mesh_ids["Cable"], (side * 0.65, 0.92, -0.04), rotation=(0.0, 0.0, side * 0.2))
        add_node("ScrapperFastener", mesh_ids["Fastener"], (side * 0.45, 1.2, -0.8), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("CuttingHead", mesh_ids["CutHead"], (0.0, 1.13, -0.92), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("ScrapperCuttingGuard", mesh_ids["CuttingGuard"], (0.0, 1.13, -1.1), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("SalvageDrum", mesh_ids["Drum"], (0.0, 1.36, 0.25), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"socket_type": "salvage_drum"})
    add_node("ScrapperIntake", mesh_ids["Plate"], (0.0, 1.43, -0.82))
    for side in (-1.0, 1.0):
        add_node("ScrapperIntakeTooth%s" % ("Left" if side < 0.0 else "Right"), mesh_ids["IntakeTooth"], (side * 0.22, 1.43, -0.93), rotation=(0.0, 0.0, side * 0.12))
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "scrapper.salvager.v1", "source": "original_shared_mesh_builder"})

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
            ("ScrapperModel", "translation", [0.0, 0.8, 1.6], [0.0, 0.0, 0.0, 0.0, 0.012, 0.0, 0.0, 0.0, 0.0]),
            ("Sensor", "rotation", [0.0, 0.8, 1.6], quat((0.0, -0.07, 0.0)) + quat((0.0, 0.07, 0.0)) + quat((0.0, -0.07, 0.0))),
            ("CargoStrap", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.0, -0.04)) + quat((0.0, 0.0, 0.04)) + quat((0.0, 0.0, -0.04))),
        ]),
        animation("Walk", [
            ("Leg", "rotation", [0.0, 0.22, 0.44], quat((0.24, 0.0, 0.0)) + quat((-0.24, 0.0, 0.0)) + quat((0.24, 0.0, 0.0))),
            ("Chassis", "rotation", [0.0, 0.22, 0.44], quat((0.032, 0.0, 0.0)) + quat((-0.032, 0.0, 0.0)) + quat((0.032, 0.0, 0.0))),
            ("CargoBin", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.03, 0.0)) + quat((0.0, -0.03, 0.0)) + quat((0.0, 0.03, 0.0))),
        ]),
        animation("Work", [
            ("Dismantler", "rotation", [0.0, 0.5, 1.0], quat((0.0, 0.0, 1.05)) + quat((0.18, 0.0, 1.05)) + quat((0.0, 0.0, 1.05))),
            ("ScrapperIntake", "rotation", [0.0, 0.5, 1.0], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, -0.12)) + quat((0.0, 0.0, 0.0))),
            ("CargoStrap", "rotation", [0.0, 0.5, 1.0], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.08)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Hit", [
            ("ScrapperModel", "translation", [0.0, 0.10, 0.24], [0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.0, 0.0]),
            ("Sensor", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((-0.15, 0.08, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Retreat", [
            ("ScrapperModel", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.12)) + quat((0.0, 0.0, 0.0))),
            ("Sensor", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.0)) + quat((0.0, -0.12, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Death", [
            ("ScrapperModel", "translation", [0.0, 0.18, 0.42], [0.0, 0.0, 0.0, 0.0, -0.08, 0.0, 0.0, -0.22, 0.0]),
            ("ScrapperModel", "rotation", [0.0, 0.18, 0.42], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.16, 0.22)) + quat((0.0, 0.22, 0.32))),
        ]),
    ]

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Scrapper asset builder"},
        "scene": 0,
        "scenes": [{"name": "Scrapper", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": "scrapper.salvager.v1",
            "required_nodes": ["ScrapperModel", "Sensor", "OpticLens", "CargoBin", "DismantlerTool", "SalvageDrum", "ScrapperIntake", "ScrapperHopperRim", "ScrapperDismantlerCollarLeft", "ScrapperMagnetCoilRight", "ScrapperCuttingGuard", "ProductionAssetMarker"],
            "animation_clips": ["Idle", "Walk", "Work", "Hit", "Retreat", "Death"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
