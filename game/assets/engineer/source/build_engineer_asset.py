"""Build the original high-definition Engineer construction-machine glTF."""

from __future__ import annotations

import base64
import json
import math
import sys
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, add_beveled_box, add_box, add_cylinder, add_ellipsoid, add_uv_sphere, quat  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "engineer.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Engineer charcoal chassis", "pbrMetallicRoughness": {"baseColorFactor": [0.05, 0.06, 0.07, 1.0], "metallicFactor": 0.8, "roughnessFactor": 0.42}},
        {"name": "Engineer workshop steel", "pbrMetallicRoughness": {"baseColorFactor": [0.26, 0.3, 0.3, 1.0], "metallicFactor": 0.84, "roughnessFactor": 0.34}},
        {"name": "Engineer oxide tooling", "pbrMetallicRoughness": {"baseColorFactor": [0.3, 0.13, 0.06, 1.0], "metallicFactor": 0.6, "roughnessFactor": 0.58}},
        {"name": "Engineer forge amber", "pbrMetallicRoughness": {"baseColorFactor": [0.45, 0.18, 0.035, 1.0], "metallicFactor": 0.26, "roughnessFactor": 0.32}, "emissiveFactor": [1.0, 0.3, 0.04]},
        {"name": "Engineer status cyan", "pbrMetallicRoughness": {"baseColorFactor": [0.025, 0.2, 0.22, 1.0], "metallicFactor": 0.3, "roughnessFactor": 0.22}, "emissiveFactor": [0.1, 0.84, 0.9]},
        {"name": "Engineer rubber", "pbrMetallicRoughness": {"baseColorFactor": [0.014, 0.018, 0.02, 1.0], "metallicFactor": 0.04, "roughnessFactor": 0.92}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({
            "name": name,
            "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}],
        })
        return len(meshes) - 1

    chassis, steel, oxide, amber, cyan, rubber = range(6)
    mesh_ids = {
        # Keep the construction machine's established envelope and sockets,
        # but remove the repeated box read from its primary shell.
        "Chassis": mesh("Chassis", add_ellipsoid(builder, (0.71, 0.35, 0.79), chassis)),
        "Core": mesh("Core", add_ellipsoid(builder, (0.58, 0.17, 0.64), oxide)),
        "Plate": mesh("Plate", add_ellipsoid(builder, (0.65, 0.09, 0.07), steel, 14, 32)),
        "Corner": mesh("Corner", add_cylinder(builder, 0.11, 0.15, steel, 20)),
        "Leg": mesh("Leg", add_cylinder(builder, 0.11, 0.7, rubber, 20)),
        "Foot": mesh("Foot", add_beveled_box(builder, (0.27, 0.12, 0.4), oxide, 0.03)),
        "OpticHousing": mesh("OpticHousing", add_beveled_box(builder, (0.48, 0.25, 0.12), chassis, 0.03)),
        "Optic": mesh("Optic", add_uv_sphere(builder, 0.085, cyan)),
        "Cradle": mesh("Cradle", add_beveled_box(builder, (0.98, 0.46, 0.82), chassis, 0.06)),
        "CradleLip": mesh("CradleLip", add_beveled_box(builder, (1.08, 0.08, 0.9), oxide, 0.025)),
        "Joint": mesh("Joint", add_uv_sphere(builder, 0.13, chassis)),
        "Arm": mesh("Arm", add_cylinder(builder, 0.1, 1.18, oxide, 20)),
        "ToolHead": mesh("ToolHead", add_beveled_box(builder, (0.24, 0.2, 0.34), steel, 0.03)),
        "ForgeCoil": mesh("ForgeCoil", add_cylinder(builder, 0.13, 0.17, amber, 24)),
        "Glow": mesh("Glow", add_uv_sphere(builder, 0.08, amber)),
        "Fastener": mesh("Fastener", add_cylinder(builder, 0.04, 0.04, amber, 20)),
        "Cable": mesh("Cable", add_cylinder(builder, 0.03, 0.7, rubber, 12)),
        # Construction-machine close-camera hardware: cradle latches, tool
        # collars, cable spools, welding shields and clamp jaws make the
        # engineer read as maintained fabrication equipment at approach range.
        "CradleLatch": mesh("CradleLatch", add_cylinder(builder, 0.06, 0.12, amber, 20)),
        "ForgeGuard": mesh("ForgeGuard", add_beveled_box(builder, (0.4, 0.1, 0.12), steel, 0.022)),
        "ForgeStatusPanel": mesh("ForgeStatusPanel", add_beveled_box(builder, (0.42, 0.11, 0.07), steel, 0.018)),
        "ForgeStatusLens": mesh("ForgeStatusLens", add_uv_sphere(builder, 0.055, cyan, 12, 20)),
        "ToolCollar": mesh("ToolCollar", add_cylinder(builder, 0.13, 0.08, cyan, 24)),
        "CableSpool": mesh("CableSpool", add_cylinder(builder, 0.13, 0.12, oxide, 24)),
        "WeldingShield": mesh("WeldingShield", add_beveled_box(builder, (0.3, 0.12, 0.16), steel, 0.025)),
        "ClampJaw": mesh("ClampJaw", add_beveled_box(builder, (0.18, 0.16, 0.28), steel, 0.025)),
        # The front service bay is a second readable layer at roster and
        # approach distance: raised ribs, a split access hatch and captive
        # fasteners break up the broad chassis without changing its envelope.
        "ServiceRib": mesh("ServiceRib", add_beveled_box(builder, (0.11, 0.34, 0.14), steel, 0.024)),
        "ServiceHatch": mesh("ServiceHatch", add_beveled_box(builder, (0.30, 0.12, 0.055), chassis, 0.018)),
        "ServiceLatch": mesh("ServiceLatch", add_cylinder(builder, 0.045, 0.055, amber, 16)),
    }

    nodes: list[dict] = [{
        "name": "EngineerModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "engineer.constructor.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "sensor, construction_tool, forge_coil",
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

    chassis_node = add_node("Chassis", mesh_ids["Chassis"], (0.0, 0.84, 0.0), extras={"surface": "beveled_primary_body"})
    add_node("ChassisCore", mesh_ids["Core"], (0.0, 0.08, 0.0), parent=chassis_node)
    add_node("ArmorPlate", mesh_ids["Plate"], (0.0, 1.18, -0.82))
    add_node("LowerChassis", mesh_ids["Plate"], (0.0, 0.43, 0.04))
    add_node("ChassisDetailPanel", mesh_ids["Plate"], (0.0, 1.34, -0.8))
    for side in (-1.0, 1.0):
        for front in (-1.0, 1.0):
            add_node("ChassisCornerCap", mesh_ids["Corner"], (side * 0.61, 0.84, front * 0.64))
            add_node("Leg", mesh_ids["Leg"], (side * 0.5, 0.43, front * 0.44), rotation=(0.0, 0.0, side * 0.22))
            add_node("Foot", mesh_ids["Foot"], (side * 0.61, 0.12, front * 0.44))
        add_node("EngineerFastener", mesh_ids["Fastener"], (side * 0.5, 1.22, -0.82), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("OpticHousing", mesh_ids["OpticHousing"], (0.0, 1.1, -0.88))
    add_node("Sensor", mesh_ids["Optic"], (0.0, 1.1, -0.98), extras={"socket_type": "sensor"})
    add_node("OpticLens", mesh_ids["Optic"], (0.0, 1.1, -1.04), extras={"socket_type": "optic"})
    add_node("MaterialCradle", mesh_ids["Cradle"], (0.0, 1.52, 0.24), extras={"socket_type": "material_cradle"})
    add_node("CradleLip", mesh_ids["CradleLip"], (0.0, 1.77, 0.24))
    add_node("EngineerCradleLatch", mesh_ids["CradleLatch"], (0.0, 1.86, -0.2), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("EngineerForgeGuard", mesh_ids["ForgeGuard"], (0.0, 1.48, 0.02))
    add_node("EngineerForgeStatusPanel", mesh_ids["ForgeStatusPanel"], (0.0, 1.18, -0.79), extras={"surface": "forge_status_face"})
    add_node("EngineerForgeStatusLens", mesh_ids["ForgeStatusLens"], (0.0, 1.18, -0.865), extras={"socket_type": "forge_status"})
    for side in (-1.0, 1.0):
        add_node("PistonJoint", mesh_ids["Joint"], (side * 0.72, 1.05, -0.1))
        add_node("EngineerToolCollar%s" % ("Left" if side < 0.0 else "Right"), mesh_ids["ToolCollar"], (side * 0.72, 1.05, -0.1), extras={"socket_type": "construction_tool_collar"})
        add_node("WelderArm", mesh_ids["Arm"], (side * 0.72, 1.05, -0.1), rotation=(0.0, 0.0, side * 1.0), extras={"socket_type": "construction_tool"})
        add_node("AssemblyArm", mesh_ids["Arm"], (side * 0.52, 1.25, 0.1), rotation=(0.0, 0.0, -side * 0.82))
        add_node("ToolHead", mesh_ids["ToolHead"], (side * 1.15, 0.74, -0.1), rotation=(0.0, 0.0, side * 0.2))
        add_node("AssemblyToolHead", mesh_ids["ToolHead"], (side * 0.92, 0.74, 0.02), rotation=(0.0, 0.0, -side * 0.2))
        add_node("EngineerCableSpool%s" % ("Left" if side < 0.0 else "Right"), mesh_ids["CableSpool"], (side * 0.58, 1.02, 0.02), rotation=(math.pi * 0.5, 0.0, 0.0))
        add_node("EngineerWeldingShield%s" % ("Left" if side < 0.0 else "Right"), mesh_ids["WeldingShield"], (side * 1.15, 0.74, -0.28), rotation=(0.0, 0.0, side * 0.14))
        add_node("EngineerClampJaw%s" % ("Left" if side < 0.0 else "Right"), mesh_ids["ClampJaw"], (side * 0.92, 0.74, -0.12), rotation=(0.0, 0.0, -side * 0.2))
        add_node("WelderGlow", mesh_ids["Glow"], (side * 1.15, 0.74, -0.28))
        add_node("EngineerCable", mesh_ids["Cable"], (side * 0.58, 1.02, 0.02), rotation=(0.0, 0.0, side * 0.18))
        add_node("EngineerServiceRib%s" % ("Left" if side < 0.0 else "Right"), mesh_ids["ServiceRib"], (side * 0.52, 0.98, -0.72), rotation=(0.0, 0.0, side * 0.10), extras={"surface": "raised_service_bay_rib"})
        add_node("EngineerServiceHatch%s" % ("Left" if side < 0.0 else "Right"), mesh_ids["ServiceHatch"], (side * 0.25, 0.91, -0.795), extras={"surface": "split_service_hatch"})
        add_node("EngineerServiceLatch%s" % ("Left" if side < 0.0 else "Right"), mesh_ids["ServiceLatch"], (side * 0.25, 0.92, -0.84), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"socket_type": "service_latch"})
    add_node("ForgeCoil", mesh_ids["ForgeCoil"], (0.0, 1.48, 0.22), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"socket_type": "forge_coil"})
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "engineer.constructor.v1", "source": "original_shared_mesh_builder"})

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
            ("EngineerModel", "translation", [0.0, 0.8, 1.6], [0.0, 0.0, 0.0, 0.0, 0.012, 0.0, 0.0, 0.0, 0.0]),
            ("Sensor", "rotation", [0.0, 0.8, 1.6], quat((0.0, -0.06, 0.0)) + quat((0.0, 0.06, 0.0)) + quat((0.0, -0.06, 0.0))),
            ("MaterialCradle", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.0, -0.025)) + quat((0.0, 0.0, 0.025)) + quat((0.0, 0.0, -0.025))),
            ("EngineerCradleLatch", "rotation", [0.0, 0.8, 1.6], quat((math.pi * 0.5, 0.0, 0.0)) + quat((math.pi * 0.5, 0.0, 0.05)) + quat((math.pi * 0.5, 0.0, 0.0))),
            ("ForgeCoil", "rotation", [0.0, 0.8, 1.6], quat((math.pi * 0.5, 0.0, 0.0)) + quat((math.pi * 0.5, 0.0, 0.0,)) + quat((math.pi * 0.5, 0.0, 0.0))),
            ("EngineerCableSpoolLeft", "rotation", [0.0, 0.8, 1.6], quat((math.pi * 0.5, 0.0, -0.05)) + quat((math.pi * 0.5, 0.0, 0.02)) + quat((math.pi * 0.5, 0.0, -0.05))),
            ("EngineerCableSpoolRight", "rotation", [0.0, 0.8, 1.6], quat((math.pi * 0.5, 0.0, 0.05)) + quat((math.pi * 0.5, 0.0, -0.02)) + quat((math.pi * 0.5, 0.0, 0.05))),
        ]),
        animation("Walk", [
            ("Leg", "rotation", [0.0, 0.22, 0.44], quat((0.22, 0.0, 0.0)) + quat((-0.22, 0.0, 0.0)) + quat((0.22, 0.0, 0.0))),
            ("Chassis", "rotation", [0.0, 0.22, 0.44], quat((0.03, 0.0, 0.0)) + quat((-0.03, 0.0, 0.0)) + quat((0.03, 0.0, 0.0))),
            ("MaterialCradle", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.035, 0.0)) + quat((0.0, -0.035, 0.0)) + quat((0.0, 0.035, 0.0))),
            ("EngineerToolCollarLeft", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.0, -0.08)) + quat((0.0, 0.0, -0.16)) + quat((0.0, 0.0, -0.08))),
            ("EngineerToolCollarRight", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.0, 0.08)) + quat((0.0, 0.0, 0.16)) + quat((0.0, 0.0, 0.08))),
            ("EngineerCableSpoolLeft", "rotation", [0.0, 0.22, 0.44], quat((math.pi * 0.5, 0.0, -0.05)) + quat((math.pi * 0.5, 0.0, -0.16)) + quat((math.pi * 0.5, 0.0, -0.05))),
            ("EngineerCableSpoolRight", "rotation", [0.0, 0.22, 0.44], quat((math.pi * 0.5, 0.0, 0.05)) + quat((math.pi * 0.5, 0.0, 0.16)) + quat((math.pi * 0.5, 0.0, 0.05))),
        ]),
        animation("Work", [
            ("WelderArm", "rotation", [0.0, 0.5, 1.0], quat((0.0, 0.0, 1.0)) + quat((0.18, 0.0, 1.0)) + quat((0.0, 0.0, 1.0))),
            ("AssemblyArm", "rotation", [0.0, 0.5, 1.0], quat((0.0, 0.0, -0.82)) + quat((-0.16, 0.0, -0.82)) + quat((0.0, 0.0, -0.82))),
            ("PistonJoint", "rotation", [0.0, 0.5, 1.0], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.18, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("EngineerWeldingShieldLeft", "rotation", [0.0, 0.5, 1.0], quat((0.0, 0.0, -0.14)) + quat((0.0, 0.0, -0.30)) + quat((0.0, 0.0, -0.14))),
            ("EngineerWeldingShieldRight", "rotation", [0.0, 0.5, 1.0], quat((0.0, 0.0, 0.14)) + quat((0.0, 0.0, 0.30)) + quat((0.0, 0.0, 0.14))),
            ("EngineerClampJawLeft", "rotation", [0.0, 0.5, 1.0], quat((0.0, 0.0, 0.20)) + quat((0.0, 0.0, 0.38)) + quat((0.0, 0.0, 0.20))),
            ("EngineerClampJawRight", "rotation", [0.0, 0.5, 1.0], quat((0.0, 0.0, -0.20)) + quat((0.0, 0.0, -0.38)) + quat((0.0, 0.0, -0.20))),
        ]),
        animation("Hit", [
            ("EngineerModel", "translation", [0.0, 0.10, 0.24], [0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.0, 0.0]),
            ("Sensor", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((-0.15, 0.08, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("EngineerForgeGuard", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((0.10, 0.0, 0.05)) + quat((0.0, 0.0, 0.0))),
            ("EngineerToolCollarLeft", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, -0.08)) + quat((0.0, 0.0, -0.20)) + quat((0.0, 0.0, -0.08))),
            ("EngineerToolCollarRight", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.08)) + quat((0.0, 0.0, 0.20)) + quat((0.0, 0.0, 0.08))),
        ]),
        animation("Retreat", [
            ("EngineerModel", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.12)) + quat((0.0, 0.0, 0.0))),
            ("Sensor", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.0)) + quat((0.0, -0.12, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("EngineerWeldingShieldLeft", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, -0.14)) + quat((0.0, 0.0, -0.02)) + quat((0.0, 0.0, -0.14))),
            ("EngineerWeldingShieldRight", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.14)) + quat((0.0, 0.0, 0.02)) + quat((0.0, 0.0, 0.14))),
            ("EngineerCradleLatch", "rotation", [0.0, 0.28, 0.56], quat((math.pi * 0.5, 0.0, 0.0)) + quat((math.pi * 0.5, 0.0, -0.12)) + quat((math.pi * 0.5, 0.0, 0.0))),
        ]),
        animation("Death", [
            ("EngineerModel", "translation", [0.0, 0.18, 0.42], [0.0, 0.0, 0.0, 0.0, -0.08, 0.0, 0.0, -0.22, 0.0]),
            ("EngineerModel", "rotation", [0.0, 0.18, 0.42], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.16, 0.22)) + quat((0.0, 0.22, 0.32))),
            ("ForgeCoil", "rotation", [0.0, 0.18, 0.42], quat((math.pi * 0.5, 0.0, 0.0)) + quat((math.pi * 0.5, 0.0, 0.20)) + quat((math.pi * 0.5, 0.0, 0.38))),
            ("MaterialCradle", "rotation", [0.0, 0.18, 0.42], quat((0.0, 0.0, -0.025)) + quat((0.0, 0.0, 0.12)) + quat((0.0, 0.0, 0.28))),
        ]),
    ]

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Engineer asset builder"},
        "scene": 0,
        "scenes": [{"name": "Engineer", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": "engineer.constructor.v1",
            "required_nodes": ["EngineerModel", "Sensor", "OpticLens", "MaterialCradle", "PistonJoint", "WelderArm", "ToolHead", "ForgeCoil", "EngineerCradleLatch", "EngineerForgeGuard", "EngineerToolCollarLeft", "EngineerCableSpoolRight", "EngineerWeldingShieldLeft", "EngineerClampJawRight", "EngineerServiceRibLeft", "EngineerServiceHatchRight", "EngineerServiceLatchLeft", "ProductionAssetMarker"],
            "animation_clips": ["Idle", "Walk", "Work", "Hit", "Retreat", "Death"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
