"""Build the original high-definition Signal Relay glTF shell."""

from __future__ import annotations

import base64
import json
import math
import sys
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, add_beveled_box, add_box, add_cylinder, add_ellipsoid, add_uv_sphere, quat, vec_min_max  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "relay.gltf"


def add_parabolic_dish(
    builder: BufferBuilder,
    radius: float,
    depth: float,
    material: int,
    sides: int = 36,
    rings: int = 6,
) -> tuple[int, int, int, int, int, int]:
    """Build a shallow, smooth signal bowl with a readable concave profile."""
    sides = max(24, sides)
    rings = max(3, rings)
    positions: list[float] = [0.0, -depth * 0.5, 0.0]
    normals: list[float] = [0.0, 1.0, 0.0]
    indices: list[int] = []

    for ring in range(1, rings + 1):
        fraction = ring / rings
        ring_radius = radius * fraction
        ring_y = -depth * 0.5 + depth * fraction * fraction
        slope = depth * 2.0 * fraction / max(radius, 0.001)
        for side in range(sides):
            angle = math.tau * side / sides
            radial_x = math.cos(angle)
            radial_z = math.sin(angle)
            normal_length = math.sqrt(slope * slope + 1.0)
            positions.extend([radial_x * ring_radius, ring_y, radial_z * ring_radius])
            normals.extend([-radial_x * slope / normal_length, 1.0 / normal_length, -radial_z * slope / normal_length])

    first_ring = 1
    for side in range(sides):
        next_side = (side + 1) % sides
        indices.extend([0, first_ring + next_side, first_ring + side])
    for ring in range(1, rings):
        previous_start = 1 + (ring - 1) * sides
        current_start = 1 + ring * sides
        for side in range(sides):
            next_side = (side + 1) % sides
            indices.extend([
                previous_start + side,
                previous_start + next_side,
                current_start + next_side,
                previous_start + side,
                current_start + next_side,
                current_start + side,
            ])

    position_min, position_max = vec_min_max(zip(*[iter(positions)] * 3))
    # The dish is generated locally rather than through the shared primitive
    # helpers, so provide the same stable UV/tangent contract explicitly.
    uvs: list[float] = []
    tangents: list[float] = []
    for index in range(0, len(positions), 3):
        uvs.extend([0.5 + positions[index] / max(radius * 2.0, 0.001), 0.5 + positions[index + 2] / max(radius * 2.0, 0.001)])
        tangents.extend([1.0, 0.0, 0.0, 1.0])
    position_accessor = builder.accessor(
        positions, 5126, "VEC3", len(positions) // 3, 34962, position_min, position_max
    )
    normal_accessor = builder.accessor(normals, 5126, "VEC3", len(normals) // 3, 34962)
    uv_accessor = builder.accessor(uvs, 5126, "VEC2", len(uvs) // 2, 34962)
    tangent_accessor = builder.accessor(tangents, 5126, "VEC4", len(tangents) // 4, 34962)
    index_accessor = builder.accessor(indices, 5123, "SCALAR", len(indices), 34963)
    return position_accessor, normal_accessor, uv_accessor, tangent_accessor, index_accessor, material


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Relay charcoal chassis", "pbrMetallicRoughness": {"baseColorFactor": [0.055, 0.09, 0.1, 1.0], "metallicFactor": 0.82, "roughnessFactor": 0.34}},
        {"name": "Relay weathered ceramic", "pbrMetallicRoughness": {"baseColorFactor": [0.34, 0.42, 0.42, 1.0], "metallicFactor": 0.7, "roughnessFactor": 0.38}},
        {"name": "Relay amber spine", "pbrMetallicRoughness": {"baseColorFactor": [0.42, 0.17, 0.045, 1.0], "metallicFactor": 0.42, "roughnessFactor": 0.42}, "emissiveFactor": [0.42, 0.08, 0.015]},
        {"name": "Relay cyan signal", "pbrMetallicRoughness": {"baseColorFactor": [0.025, 0.24, 0.27, 1.0], "metallicFactor": 0.3, "roughnessFactor": 0.22}, "emissiveFactor": [0.1, 0.9, 0.95]},
        {"name": "Relay rubber cable", "pbrMetallicRoughness": {"baseColorFactor": [0.012, 0.018, 0.02, 1.0], "metallicFactor": 0.04, "roughnessFactor": 0.9}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int, int, int]) -> int:
        position, normal, uv, tangent, indices, material = geometry
        meshes.append({
            "name": name,
            "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal, "TEXCOORD_0": uv, "TANGENT": tangent}, "indices": indices, "material": material}],
        })
        return len(meshes) - 1

    chassis, ceramic, amber, cyan, rubber = range(5)
    mesh_ids = {
        # The signal frame shares the machine family's rounded protective
        # envelope while the mast and dish retain their distinct silhouette.
        "Chassis": mesh("Chassis", add_ellipsoid(builder, (0.61, 0.34, 0.71), chassis)),
        "Core": mesh("Core", add_ellipsoid(builder, (0.45, 0.14, 0.54), amber)),
        "Face": mesh("Face", add_beveled_box(builder, (0.76, 0.28, 0.08), ceramic, 0.018)),
        "HeatSink": mesh("HeatSink", add_beveled_box(builder, (0.8, 0.3, 0.14), ceramic, 0.028)),
        "Corner": mesh("Corner", add_cylinder(builder, 0.1, 0.14, ceramic, 20)),
        "Leg": mesh("Leg", add_cylinder(builder, 0.095, 0.58, rubber, 20)),
        "Foot": mesh("Foot", add_beveled_box(builder, (0.25, 0.12, 0.42), ceramic, 0.028)),
        "OpticHousing": mesh("OpticHousing", add_beveled_box(builder, (0.38, 0.2, 0.12), chassis, 0.022)),
        "Optic": mesh("Optic", add_uv_sphere(builder, 0.085, cyan)),
        "Mast": mesh("Mast", add_cylinder(builder, 0.07, 1.18, rubber, 20)),
        "Collar": mesh("Collar", add_cylinder(builder, 0.115, 0.08, amber, 20)),
        "MastFoot": mesh("MastFoot", add_cylinder(builder, 0.22, 0.10, ceramic, 24)),
        "Dish": mesh("Dish", add_parabolic_dish(builder, 0.40, 0.18, ceramic)),
        "DishRim": mesh("DishRim", add_cylinder(builder, 0.39, 0.04, cyan, 24)),
        "Beacon": mesh("Beacon", add_uv_sphere(builder, 0.095, cyan)),
        "Brace": mesh("Brace", add_beveled_box(builder, (0.08, 0.12, 0.58), chassis, 0.018)),
        "Panel": mesh("Panel", add_beveled_box(builder, (0.24, 0.3, 0.08), cyan, 0.018)),
        "Fastener": mesh("Fastener", add_cylinder(builder, 0.04, 0.04, amber, 20)),
        "MastBraceDetail": mesh("MastBraceDetail", add_beveled_box(builder, (0.10, 0.14, 0.72), rubber, 0.018)),
        "DishHub": mesh("DishHub", add_cylinder(builder, 0.14, 0.13, amber, 24)),
        "SignalCable": mesh("SignalCable", add_cylinder(builder, 0.035, 0.72, rubber, 24)),
        "ServiceLatch": mesh("ServiceLatch", add_beveled_box(builder, (0.14, 0.08, 0.06), ceramic, 0.014)),
        "BeaconCap": mesh("BeaconCap", add_uv_sphere(builder, 0.12, cyan, rings=20, sides=32)),
    }

    nodes: list[dict] = [{
        "name": "RelayModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "relay.signal.v1",
            "asset_quality": "authored_high_definition",
            "manufactured_surface_profile": "chamfered_high_definition",
            "socket_contract": "sensor, signal_mast, directional_dish, signal_beacon",
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
    add_node("ChassisCore", mesh_ids["Core"], (0.0, 0.1, 0.0), parent=chassis_node)
    add_node("RelayServiceFace", mesh_ids["Face"], (0.0, 1.15, -0.74), extras={"socket_type": "service_face"})
    add_node("RelayHeatSink", mesh_ids["HeatSink"], (0.0, 0.92, 0.74), extras={"socket_type": "heat_sink"})
    for side in (-1.0, 1.0):
        for front in (-1.0, 1.0):
            add_node("RelayCornerCap", mesh_ids["Corner"], (side * 0.48, 0.82, front * 0.56))
        add_node("RelayLeg%s" % ("Left" if side < 0 else "Right"), mesh_ids["Leg"], (side * 0.43, 0.43, 0.0))
        add_node("RelayFoot%s" % ("Left" if side < 0 else "Right"), mesh_ids["Foot"], (side * 0.5, 0.12, -0.04))
        add_node("RelayBrace%s" % ("Left" if side < 0 else "Right"), mesh_ids["Brace"], (side * 0.53, 1.17, 0.12), rotation=(0.0, 0.0, side * 0.28))
        add_node("RelaySignalPanel%s" % ("Left" if side < 0 else "Right"), mesh_ids["Panel"], (side * 0.69, 1.0, 0.0), rotation=(0.0, 0.0, side * 0.2), extras={"socket_type": "signal_panel"})
    add_node("OpticHousing", mesh_ids["OpticHousing"], (0.0, 1.36, -0.82))
    add_node("Sensor", mesh_ids["Optic"], (0.0, 1.36, -0.93), extras={"socket_type": "sensor"})
    add_node("OpticLens", mesh_ids["Optic"], (0.0, 1.36, -0.98), extras={"socket_type": "optic"})
    add_node("RelayMast", mesh_ids["Mast"], (0.0, 1.68, 0.08), extras={"socket_type": "signal_mast"})
    # A broad service foot closes the mast-to-chassis load path at close
    # review distance. It is presentation-only; the existing mast socket and
    # animation ownership remain unchanged.
    add_node("RelayMastFoot", mesh_ids["MastFoot"], (0.0, 1.28, 0.08), extras={"surface": "mast_root_service_collar"})
    for side in (-1.0, 1.0):
        add_node("RelayMastFootFastener%s" % ("Left" if side < 0 else "Right"), mesh_ids["Fastener"], (side * 0.14, 1.34, -0.04), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "mast_root_fastener"})
    add_node("RelayMastCollar", mesh_ids["Collar"], (0.0, 1.58, 0.08))
    for side in (-1.0, 1.0):
        add_node("RelayMastBrace%s" % ("Left" if side < 0 else "Right"), mesh_ids["MastBraceDetail"], (side * 0.16, 1.75, 0.08), rotation=(0.0, 0.0, side * 0.34))
    add_node("RelayDirectionalDish", mesh_ids["Dish"], (0.0, 2.12, 0.0), rotation=(0.55, 0.0, 0.0), extras={"socket_type": "directional_dish"})
    add_node("RelayDishRim", mesh_ids["DishRim"], (0.0, 2.19, 0.02), rotation=(0.55, 0.0, 0.0))
    add_node("RelayDishHub", mesh_ids["DishHub"], (0.0, 2.12, -0.12), rotation=(0.55, 0.0, 0.0))
    add_node("RelayBeacon", mesh_ids["Beacon"], (0.0, 2.3, -0.04), extras={"socket_type": "signal_beacon"})
    add_node("RelayBeaconCap", mesh_ids["BeaconCap"], (0.0, 2.34, -0.04))
    for side in (-1.0, 1.0):
        add_node("RelayDishRib%s" % ("Left" if side < 0 else "Right"), mesh_ids["Brace"], (side * 0.18, 2.38, 0.0), rotation=(0.0, 0.0, side * 0.2))
    # A four-point cradle gives the directional bowl a readable load-bearing
    # aperture at close review distance. These are presentation-only braces;
    # the dish remains owned by its existing animated node.
    add_node("RelayDishRibFront", mesh_ids["Brace"], (0.0, 2.38, -0.18), rotation=(0.2, 0.0, 0.0))
    add_node("RelayDishRibRear", mesh_ids["Brace"], (0.0, 2.38, 0.18), rotation=(-0.2, 0.0, 0.0))
    add_node("RelayFastenerLeft", mesh_ids["Fastener"], (-0.39, 1.19, -0.79), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("RelayFastenerRight", mesh_ids["Fastener"], (0.39, 1.19, -0.79), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("RelayServiceLatch", mesh_ids["ServiceLatch"], (0.0, 1.18, -0.8))
    add_node("RelaySignalCable", mesh_ids["SignalCable"], (0.0, 1.42, 0.74), rotation=(0.0, 0.0, 0.12))
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "relay.signal.v1", "source": "original_shared_mesh_builder"})

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
            ("RelayModel", "translation", [0.0, 0.8, 1.6], [0.0, 0.0, 0.0, 0.0, 0.012, 0.0, 0.0, 0.0, 0.0]),
            ("RelayBeacon", "rotation", [0.0, 0.8, 1.6], quat((0.0, -0.08, 0.0)) + quat((0.0, 0.08, 0.0)) + quat((0.0, -0.08, 0.0))),
            ("RelayDirectionalDish", "rotation", [0.0, 0.8, 1.6], quat((0.52, 0.0, -0.03)) + quat((0.55, 0.0, 0.03)) + quat((0.52, 0.0, -0.03))),
            ("RelayMastCollar", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.05)) + quat((0.0, 0.0, 0.0))),
            ("RelayHeatSink", "translation", [0.0, 0.8, 1.6], [0.0, 0.92, 0.74, 0.0, 0.94, 0.74, 0.0, 0.92, 0.74]),
            ("RelayServiceFace", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.025)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Walk", [
            ("RelayLegLeft", "rotation", [0.0, 0.22, 0.44], quat((0.18, 0.0, 0.0)) + quat((-0.18, 0.0, 0.0)) + quat((0.18, 0.0, 0.0))),
            ("RelayLegRight", "rotation", [0.0, 0.22, 0.44], quat((-0.18, 0.0, 0.0)) + quat((0.18, 0.0, 0.0)) + quat((-0.18, 0.0, 0.0))),
            ("RelayModel", "rotation", [0.0, 0.22, 0.44], quat((0.025, 0.0, 0.0)) + quat((-0.025, 0.0, 0.0)) + quat((0.025, 0.0, 0.0))),
            ("RelayMastBraceLeft", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.0, -0.34)) + quat((0.0, 0.0, -0.42)) + quat((0.0, 0.0, -0.34))),
            ("RelayMastBraceRight", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.0, 0.34)) + quat((0.0, 0.0, 0.42)) + quat((0.0, 0.0, 0.34))),
            ("RelayMast", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, -0.04)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Work", [
            ("RelayDirectionalDish", "rotation", [0.0, 0.5, 1.0], quat((0.55, 0.0, -0.12)) + quat((0.55, 0.0, 0.12)) + quat((0.55, 0.0, -0.12))),
            ("RelayBeacon", "rotation", [0.0, 0.5, 1.0], quat((0.0, 0.0, -0.1)) + quat((0.0, 0.0, 0.1)) + quat((0.0, 0.0, -0.1))),
            ("RelayDishRim", "rotation", [0.0, 0.5, 1.0], quat((0.55, 0.0, 0.0)) + quat((0.55, 0.0, 0.10)) + quat((0.55, 0.0, 0.0))),
            ("RelayDishHub", "rotation", [0.0, 0.5, 1.0], quat((0.55, 0.0, 0.0)) + quat((0.55, 0.0, -0.14)) + quat((0.55, 0.0, 0.0))),
            ("RelaySignalCable", "rotation", [0.0, 0.5, 1.0], quat((0.0, 0.0, 0.12)) + quat((0.0, 0.0, 0.22)) + quat((0.0, 0.0, 0.12))),
        ]),
        animation("Fire", [
            ("RelayBeacon", "rotation", [0.0, 0.08, 0.18], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.22, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("RelayModel", "translation", [0.0, 0.08, 0.18], [0.0, 0.0, 0.0, 0.0, 0.045, 0.0, 0.0, 0.0, 0.0]),
            ("RelayDishHub", "rotation", [0.0, 0.08, 0.18], quat((0.55, 0.0, 0.0)) + quat((0.55, -0.12, 0.0)) + quat((0.55, 0.0, 0.0))),
            ("RelayDishRim", "rotation", [0.0, 0.08, 0.18], quat((0.55, 0.0, 0.0)) + quat((0.55, 0.0, 0.16)) + quat((0.55, 0.0, 0.0))),
        ]),
        animation("Hit", [
            ("RelayModel", "translation", [0.0, 0.1, 0.24], [0.0, 0.0, 0.0, 0.0, 0.0, 0.1, 0.0, 0.0, 0.0]),
            ("RelayDirectionalDish", "rotation", [0.0, 0.1, 0.24], quat((0.55, 0.0, 0.0)) + quat((0.46, 0.1, 0.0)) + quat((0.55, 0.0, 0.0))),
            ("RelayServiceFace", "rotation", [0.0, 0.1, 0.24], quat((0.0, 0.0, 0.0)) + quat((0.10, 0.0, 0.05)) + quat((0.0, 0.0, 0.0))),
            ("RelayMastCollar", "rotation", [0.0, 0.1, 0.24], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, -0.16)) + quat((0.0, 0.0, 0.0))),
            ("RelayDishRim", "rotation", [0.0, 0.1, 0.24], quat((0.55, 0.0, 0.0)) + quat((0.46, 0.12, 0.0)) + quat((0.55, 0.0, 0.0))),
        ]),
        animation("Retreat", [
            ("RelayModel", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.12)) + quat((0.0, 0.0, 0.0))),
            ("RelayBeacon", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.18)) + quat((0.0, 0.0, 0.0))),
            ("RelayMastBraceLeft", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, -0.34)) + quat((0.0, 0.0, -0.04)) + quat((0.0, 0.0, -0.34))),
            ("RelayMastBraceRight", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.34)) + quat((0.0, 0.0, 0.04)) + quat((0.0, 0.0, 0.34))),
            ("RelayMastCollar", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, -0.10)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Death", [
            ("RelayModel", "translation", [0.0, 0.18, 0.42], [0.0, 0.0, 0.0, 0.0, -0.08, 0.0, 0.0, -0.22, 0.0]),
            ("RelayModel", "rotation", [0.0, 0.18, 0.42], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.16, 0.22)) + quat((0.0, 0.22, 0.32))),
            ("RelayDirectionalDish", "rotation", [0.0, 0.18, 0.42], quat((0.55, 0.0, 0.0)) + quat((0.40, 0.22, 0.0)) + quat((0.30, 0.38, 0.0))),
            ("RelayBeaconCap", "translation", [0.0, 0.18, 0.42], [0.0, 2.34, -0.04, 0.0, 2.22, -0.04, 0.0, 2.08, -0.04]),
        ]),
    ]

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Signal Relay asset builder"},
        "scene": 0,
        "scenes": [{"name": "Signal Relay", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": "relay.signal.v1",
            "manufactured_surface_profile": "chamfered_high_definition",
            "required_nodes": ["RelayModel", "Sensor", "OpticLens", "RelayMast", "RelayMastFoot", "RelayDirectionalDish", "RelayBeacon", "ProductionAssetMarker"],
            "animation_clips": ["Idle", "Walk", "Work", "Fire", "Hit", "Retreat", "Death"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
