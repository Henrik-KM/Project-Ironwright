"""Build the original high-definition Warden guardian glTF.

The geometry helpers are shared with the Bulwark builder so both production
machine assets keep a common material and node-contract language without
sharing a runtime scene or gameplay code.
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
from build_bulwark_asset import BufferBuilder, add_box, add_cylinder, add_uv_sphere, quat  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "warden.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Warden charcoal chassis", "pbrMetallicRoughness": {"baseColorFactor": [0.04, 0.055, 0.06, 1.0], "metallicFactor": 0.84, "roughnessFactor": 0.4}},
        {"name": "Warden field steel", "pbrMetallicRoughness": {"baseColorFactor": [0.25, 0.3, 0.3, 1.0], "metallicFactor": 0.86, "roughnessFactor": 0.32}},
        {"name": "Warden oxide armour", "pbrMetallicRoughness": {"baseColorFactor": [0.3, 0.12, 0.06, 1.0], "metallicFactor": 0.62, "roughnessFactor": 0.55}},
        {"name": "Warden warm optic", "pbrMetallicRoughness": {"baseColorFactor": [0.45, 0.2, 0.04, 1.0], "metallicFactor": 0.28, "roughnessFactor": 0.3}, "emissiveFactor": [1.0, 0.34, 0.05]},
        {"name": "Warden cyan status", "pbrMetallicRoughness": {"baseColorFactor": [0.025, 0.18, 0.2, 1.0], "metallicFactor": 0.35, "roughnessFactor": 0.22}, "emissiveFactor": [0.1, 0.85, 0.9]},
        {"name": "Warden rubber", "pbrMetallicRoughness": {"baseColorFactor": [0.014, 0.018, 0.02, 1.0], "metallicFactor": 0.04, "roughnessFactor": 0.92}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({
            "name": name,
            "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}],
        })
        return len(meshes) - 1

    chassis, steel, oxide, warm, cyan, rubber = range(6)
    mesh_ids = {
        "Chassis": mesh("Chassis", add_box(builder, (1.8, 0.86, 1.76), chassis)),
        "Core": mesh("Core", add_box(builder, (1.48, 0.44, 1.42), oxide)),
        "Plate": mesh("Plate", add_box(builder, (1.55, 0.2, 0.16), steel)),
        "SidePlate": mesh("SidePlate", add_box(builder, (0.22, 0.72, 1.34), steel)),
        "Corner": mesh("Corner", add_cylinder(builder, 0.13, 0.18, oxide, 20)),
        "Leg": mesh("Leg", add_cylinder(builder, 0.13, 0.74, rubber, 20)),
        "Foot": mesh("Foot", add_box(builder, (0.3, 0.13, 0.44), oxide)),
        "OpticHousing": mesh("OpticHousing", add_box(builder, (0.58, 0.3, 0.14), chassis)),
        "Optic": mesh("Optic", add_uv_sphere(builder, 0.095, warm)),
        "Breech": mesh("Breech", add_box(builder, (0.66, 0.42, 0.62), oxide)),
        "Cannon": mesh("Cannon", add_cylinder(builder, 0.14, 1.52, chassis, 24)),
        "Muzzle": mesh("Muzzle", add_cylinder(builder, 0.18, 0.15, warm, 24)),
        "RecoilRing": mesh("RecoilRing", add_cylinder(builder, 0.18, 0.09, cyan, 24)),
        "HeatPanel": mesh("HeatPanel", add_box(builder, (0.92, 0.24, 0.16), chassis)),
        "Louver": mesh("Louver", add_box(builder, (0.7, 0.045, 0.08), steel)),
        "Counterweight": mesh("Counterweight", add_box(builder, (1.68, 0.16, 0.5), chassis)),
        "Antenna": mesh("Antenna", add_cylinder(builder, 0.045, 0.72, rubber, 20)),
        "Beacon": mesh("Beacon", add_uv_sphere(builder, 0.1, cyan)),
        "Fastener": mesh("Fastener", add_cylinder(builder, 0.045, 0.045, warm, 20)),
        # Close-camera guardian hardware: these restrained service surfaces
        # make the targeting and recoil language read as maintained machinery
        # rather than a single barrel laid over a box chassis.
        "TargetingFace": mesh("TargetingFace", add_box(builder, (0.88, 0.16, 0.08), steel)),
        "OpticShroud": mesh("OpticShroud", add_box(builder, (0.72, 0.16, 0.18), oxide)),
        "RecoilCollar": mesh("RecoilCollar", add_cylinder(builder, 0.14, 0.08, cyan, 24)),
        "ThermalFin": mesh("ThermalFin", add_box(builder, (0.09, 0.34, 0.42), steel)),
        "BreechClamp": mesh("BreechClamp", add_cylinder(builder, 0.17, 0.08, warm, 24)),
    }

    nodes: list[dict] = [{
        "name": "WardenModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "warden.guardian.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "weapon_muzzle, sensor, recoil_ring",
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

    add_node("Chassis", mesh_ids["Chassis"], (0.0, 0.87, 0.0), extras={"surface": "beveled_primary_body"})
    add_node("ChassisCore", mesh_ids["Core"], (0.0, 0.93, 0.0))
    add_node("ArmorPlate", mesh_ids["Plate"], (0.0, 1.25, -0.86), rotation=(0.03, 0.0, 0.0))
    add_node("LowerChassis", mesh_ids["Plate"], (0.0, 0.46, 0.05))
    add_node("ChassisDetailPanel", mesh_ids["Plate"], (0.0, 1.4, -0.86))
    for side in (-1.0, 1.0):
        add_node("WardenSidePlate", mesh_ids["SidePlate"], (side * 0.96, 0.91, 0.04), rotation=(0.0, 0.0, side * 0.08))
        for front in (-1.0, 1.0):
            add_node("ChassisCornerCap", mesh_ids["Corner"], (side * 0.8, 0.88, front * 0.72))
            add_node("Leg", mesh_ids["Leg"], (side * 0.61, 0.45, front * 0.5), rotation=(0.0, 0.0, side * 0.22))
            add_node("Foot", mesh_ids["Foot"], (side * 0.72, 0.12, front * 0.5))
        add_node("WardenFastener", mesh_ids["Fastener"], (side * 0.83, 1.16, -0.86), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("OpticHousing", mesh_ids["OpticHousing"], (0.0, 1.18, -0.96))
    add_node("Sensor", mesh_ids["Optic"], (0.0, 1.18, -1.07), extras={"socket_type": "sensor"})
    add_node("OpticLens", mesh_ids["Optic"], (0.0, 1.18, -1.13), extras={"socket_type": "optic"})
    add_node("WardenTargetingFace", mesh_ids["TargetingFace"], (0.0, 1.2, -1.16))
    add_node("WardenOpticShroud", mesh_ids["OpticShroud"], (0.0, 1.2, -1.19))
    add_node("WardenBreech", mesh_ids["Breech"], (0.0, 1.48, -0.58))
    add_node("WardenBreechClamp", mesh_ids["BreechClamp"], (0.0, 1.72, -0.72), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("WardenAutocannon", mesh_ids["Cannon"], (0.0, 1.48, -1.18), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"socket_type": "weapon_mount"})
    add_node("Weapon", mesh_ids["Cannon"], (0.0, 1.48, -1.36), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("WeaponBarrel", mesh_ids["Cannon"], (0.0, 1.48, -1.62), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("WeaponMuzzle", mesh_ids["Muzzle"], (0.0, 1.48, -2.18), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"socket_type": "weapon_muzzle"})
    for side in (-1.0, 1.0):
        add_node("WardenRecoilRing", mesh_ids["RecoilRing"], (side * 0.24, 1.48, -1.9), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"socket_type": "recoil_ring"})
        add_node("WardenRecoilCollar%s" % ("Left" if side < 0.0 else "Right"), mesh_ids["RecoilCollar"], (side * 0.24, 1.48, -1.82), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"socket_type": "recoil_collar"})
    add_node("WardenCounterweight", mesh_ids["Counterweight"], (0.0, 0.55, 0.82), rotation=(0.0, 0.0, -0.04))
    add_node("WardenHeatExchanger", mesh_ids["HeatPanel"], (-0.5, 1.42, -0.92))
    add_node("WardenAmmunitionPanel", mesh_ids["HeatPanel"], (0.5, 1.38, -0.9))
    for side in (-1.0, 1.0):
        for index in range(4):
            add_node("WardenHeatLouver", mesh_ids["Louver"], (side * 0.5, 1.3 + index * 0.09, -1.02))
        add_node("WardenLamp", mesh_ids["Beacon"], (side * 0.34, 1.4, -1.02), extras={"socket_type": "status_light"})
        add_node("WardenThermalFin%s" % ("Left" if side < 0.0 else "Right"), mesh_ids["ThermalFin"], (side * 0.86, 1.34, -0.76), rotation=(0.0, 0.0, side * 0.12), extras={"socket_type": "thermal_fin"})
    add_node("WardenSensorMast", mesh_ids["Antenna"], (0.0, 1.84, 0.18), extras={"socket_type": "sensor_mast"})
    add_node("WardenSensorBeacon", mesh_ids["Beacon"], (0.0, 2.22, 0.18))
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "warden.guardian.v1", "source": "original_shared_mesh_builder"})

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
            ("WardenModel", "translation", [0.0, 0.8, 1.6], [0.0, 0.0, 0.0, 0.0, 0.01, 0.0, 0.0, 0.0, 0.0]),
            ("Sensor", "rotation", [0.0, 0.8, 1.6], quat((0.0, -0.05, 0.0)) + quat((0.0, 0.05, 0.0)) + quat((0.0, -0.05, 0.0))),
            ("WardenSensorBeacon", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.05)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Walk", [
            ("Leg", "rotation", [0.0, 0.22, 0.44], quat((0.2, 0.0, 0.0)) + quat((-0.2, 0.0, 0.0)) + quat((0.2, 0.0, 0.0))),
            ("Chassis", "rotation", [0.0, 0.22, 0.44], quat((0.03, 0.0, 0.0)) + quat((-0.03, 0.0, 0.0)) + quat((0.03, 0.0, 0.0))),
            ("WardenSensorMast", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.0, 0.04)) + quat((0.0, 0.0, -0.04)) + quat((0.0, 0.0, 0.04))),
        ]),
        animation("Fire", [
            ("WardenAutocannon", "translation", [0.0, 0.08, 0.18], [0.0, 1.48, -1.18, 0.0, 1.48, -1.28, 0.0, 1.48, -1.18]),
            ("Sensor", "rotation", [0.0, 0.08, 0.18], quat((0.0, 0.0, 0.0)) + quat((0.0, -0.1, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Hit", [
            ("WardenModel", "translation", [0.0, 0.10, 0.24], [0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.0, 0.0]),
            ("Sensor", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((-0.15, 0.08, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Retreat", [
            ("WardenModel", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.12)) + quat((0.0, 0.0, 0.0))),
            ("Sensor", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.0)) + quat((0.0, -0.12, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Death", [
            ("WardenModel", "translation", [0.0, 0.18, 0.42], [0.0, 0.0, 0.0, 0.0, -0.08, 0.0, 0.0, -0.22, 0.0]),
            ("WardenModel", "rotation", [0.0, 0.18, 0.42], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.16, 0.22)) + quat((0.0, 0.22, 0.32))),
        ]),
    ]

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Warden asset builder"},
        "scene": 0,
        "scenes": [{"name": "Warden", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": "warden.guardian.v1",
            "required_nodes": ["WardenModel", "Sensor", "OpticLens", "WardenAutocannon", "WeaponMuzzle", "WardenHeatExchanger", "WardenTargetingFace", "WardenOpticShroud", "WardenRecoilCollarLeft", "WardenThermalFinRight", "WardenBreechClamp", "ProductionAssetMarker"],
            "animation_clips": ["Idle", "Walk", "Fire", "Hit", "Retreat", "Death"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
