"""Build the original high-definition Bulwark companion glTF.

The runtime asset is deliberately dependency-free so repository validation can
rebuild it without Blender. It uses layered industrial geometry, authored
materials, stable named sockets, and small animation clips that are useful to
tools while the in-game procedural animator remains the source of motion.
"""

from __future__ import annotations

import base64
import json
import math
import struct
from pathlib import Path
from typing import Iterable, Sequence


ASSET_DIR = Path(__file__).resolve().parents[1]
OUTPUT_PATH = ASSET_DIR / "bulwark.gltf"


class BufferBuilder:
    def __init__(self) -> None:
        self.data = bytearray()
        self.views: list[dict] = []
        self.accessors: list[dict] = []

    def _align(self) -> None:
        while len(self.data) % 4:
            self.data.append(0)

    def accessor(
        self,
        values: Sequence[float] | Sequence[int],
        component_type: int,
        accessor_type: str,
        count: int,
        target: int | None = None,
        minimum: Sequence[float] | Sequence[int] | None = None,
        maximum: Sequence[float] | Sequence[int] | None = None,
    ) -> int:
        self._align()
        offset = len(self.data)
        if component_type == 5126:
            self.data.extend(struct.pack("<%sf" % len(values), *values))
            component_size = 4
        elif component_type == 5123:
            self.data.extend(struct.pack("<%sH" % len(values), *values))
            component_size = 2
        else:
            raise ValueError(component_type)
        view_index = len(self.views)
        self.views.append({
            "buffer": 0,
            "byteOffset": offset,
            "byteLength": len(self.data) - offset,
            **({"target": target} if target is not None else {}),
        })
        accessor: dict = {
            "bufferView": view_index,
            "componentType": component_type,
            "count": count,
            "type": accessor_type,
        }
        if component_size == 2:
            accessor["normalized"] = False
        if minimum is not None:
            accessor["min"] = list(minimum)
        if maximum is not None:
            accessor["max"] = list(maximum)
        self.accessors.append(accessor)
        return len(self.accessors) - 1


def vec_min_max(values: Iterable[Sequence[float]], width: int = 3) -> tuple[list[float], list[float]]:
    rows = [list(row[:width]) for row in values]
    return (
        [min(row[index] for row in rows) for index in range(width)],
        [max(row[index] for row in rows) for index in range(width)],
    )


def quat(euler_xyz: Sequence[float]) -> list[float]:
    x, y, z = (value * 0.5 for value in euler_xyz)
    cx, sx = math.cos(x), math.sin(x)
    cy, sy = math.cos(y), math.sin(y)
    cz, sz = math.cos(z), math.sin(z)
    return [
        sx * cy * cz - cx * sy * sz,
        cx * sy * cz + sx * cy * sz,
        cx * cy * sz - sx * sy * cz,
        cx * cy * cz + sx * sy * sz,
    ]


def _geometry(builder: BufferBuilder, positions: list[float], normals: list[float], indices: list[int], material: int) -> tuple[int, int, int, int]:
    position_min, position_max = vec_min_max(zip(*[iter(positions)] * 3))
    position_accessor = builder.accessor(
        positions, 5126, "VEC3", len(positions) // 3, 34962, position_min, position_max
    )
    normal_accessor = builder.accessor(normals, 5126, "VEC3", len(normals) // 3, 34962)
    index_accessor = builder.accessor(indices, 5123, "SCALAR", len(indices), 34963)
    return position_accessor, normal_accessor, index_accessor, material


def add_box(builder: BufferBuilder, size: Sequence[float], material: int) -> tuple[int, int, int, int]:
    sx, sy, sz = (value * 0.5 for value in size)
    corners = [
        (-sx, -sy, -sz), (sx, -sy, -sz), (sx, sy, -sz), (-sx, sy, -sz),
        (-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz),
    ]
    faces = [
        ((0, 1, 2, 3), (0.0, 0.0, -1.0)), ((5, 4, 7, 6), (0.0, 0.0, 1.0)),
        ((4, 0, 3, 7), (-1.0, 0.0, 0.0)), ((1, 5, 6, 2), (1.0, 0.0, 0.0)),
        ((3, 2, 6, 7), (0.0, 1.0, 0.0)), ((4, 5, 1, 0), (0.0, -1.0, 0.0)),
    ]
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []
    for face, normal in faces:
        start = len(positions) // 3
        for corner in face:
            positions.extend(corners[corner])
            normals.extend(normal)
        indices.extend([start, start + 1, start + 2, start, start + 2, start + 3])
    return _geometry(builder, positions, normals, indices, material)


HERO_CURVE_SIDES = 24
HERO_SPHERE_RINGS = 16


def add_cylinder(builder: BufferBuilder, radius: float, height: float, material: int, sides: int = 14) -> tuple[int, int, int, int]:
    # Keep every curved authored surface smooth at tactical and close-camera
    # distances, including small fasteners and cable housings whose callers
    # intentionally use compact legacy segment counts.
    sides = max(sides, HERO_CURVE_SIDES)
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []
    bottom = len(positions) // 3
    for y in (-height * 0.5, height * 0.5):
        for side in range(sides):
            angle = math.tau * side / sides
            positions.extend([math.cos(angle) * radius, y, math.sin(angle) * radius])
            normals.extend([math.cos(angle), 0.0, math.sin(angle)])
    for side in range(sides):
        next_side = (side + 1) % sides
        indices.extend([bottom + side, bottom + next_side, bottom + sides + next_side,
                        bottom + side, bottom + sides + next_side, bottom + sides + side])
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


def add_uv_sphere(builder: BufferBuilder, radius: float, material: int, rings: int = 8, sides: int = 16) -> tuple[int, int, int, int]:
    rings = max(rings, HERO_SPHERE_RINGS)
    sides = max(sides, HERO_CURVE_SIDES)
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []
    for ring in range(rings + 1):
        v = ring / rings
        theta = math.pi * v
        for side in range(sides):
            u = side / sides
            phi = math.tau * u
            normal = (math.sin(theta) * math.cos(phi), math.cos(theta), math.sin(theta) * math.sin(phi))
            positions.extend([radius * value for value in normal])
            normals.extend(normal)
    for ring in range(rings):
        for side in range(sides):
            next_side = (side + 1) % sides
            a = ring * sides + side
            b = ring * sides + next_side
            c = (ring + 1) * sides + next_side
            d = (ring + 1) * sides + side
            indices.extend([a, b, c, a, c, d])
    return _geometry(builder, positions, normals, indices, material)


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Bulwark charcoal chassis", "pbrMetallicRoughness": {"baseColorFactor": [0.045, 0.065, 0.072, 1.0], "metallicFactor": 0.78, "roughnessFactor": 0.42}},
        {"name": "Bulwark weathered steel", "pbrMetallicRoughness": {"baseColorFactor": [0.22, 0.28, 0.29, 1.0], "metallicFactor": 0.84, "roughnessFactor": 0.34}},
        {"name": "Bulwark copper oxide", "pbrMetallicRoughness": {"baseColorFactor": [0.29, 0.13, 0.075, 1.0], "metallicFactor": 0.62, "roughnessFactor": 0.54}},
        {"name": "Protection cyan", "pbrMetallicRoughness": {"baseColorFactor": [0.03, 0.22, 0.25, 1.0], "metallicFactor": 0.34, "roughnessFactor": 0.22}, "emissiveFactor": [0.12, 0.9, 0.95]},
        {"name": "Bulwark warm lamps", "pbrMetallicRoughness": {"baseColorFactor": [0.42, 0.17, 0.04, 1.0], "metallicFactor": 0.32, "roughnessFactor": 0.34}, "emissiveFactor": [1.0, 0.28, 0.04]},
        {"name": "Rubber and cable", "pbrMetallicRoughness": {"baseColorFactor": [0.018, 0.022, 0.024, 1.0], "metallicFactor": 0.05, "roughnessFactor": 0.92}},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({
            "name": name,
            "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}],
        })
        return len(meshes) - 1

    chassis = 0
    steel = 1
    oxide = 2
    cyan = 3
    warm = 4
    rubber = 5
    mesh_ids = {
        "Chassis": mesh("Chassis", add_box(builder, (1.55, 0.78, 1.65), chassis)),
        "ChassisCore": mesh("ChassisCore", add_box(builder, (1.28, 0.38, 1.38), oxide)),
        "Plate": mesh("Plate", add_box(builder, (1.44, 0.26, 0.16), steel)),
        "Rail": mesh("Rail", add_box(builder, (0.12, 0.12, 1.24), oxide)),
        "Panel": mesh("Panel", add_box(builder, (0.72, 0.055, 0.46), chassis)),
        "Corner": mesh("Corner", add_cylinder(builder, 0.12, 0.16, steel, 20)),
        "Leg": mesh("Leg", add_cylinder(builder, 0.12, 0.72, rubber, 20)),
        "Foot": mesh("Foot", add_box(builder, (0.28, 0.12, 0.42), oxide)),
        "OpticHousing": mesh("OpticHousing", add_box(builder, (0.5, 0.27, 0.13), chassis)),
        "Optic": mesh("Optic", add_uv_sphere(builder, 0.09, cyan)),
        "Shield": mesh("Shield", add_box(builder, (1.75, 0.72, 0.14), steel)),
        "ShieldRib": mesh("ShieldRib", add_box(builder, (1.42, 0.12, 0.12), oxide)),
        "Gun": mesh("Gun", add_cylinder(builder, 0.11, 1.18, chassis, 24)),
        "Muzzle": mesh("Muzzle", add_cylinder(builder, 0.15, 0.12, cyan, 24)),
        "EmitterSpine": mesh("EmitterSpine", add_cylinder(builder, 0.10, 0.64, oxide, 20)),
        "Emitter": mesh("Emitter", add_uv_sphere(builder, 0.14, cyan)),
        "EmitterGuardRail": mesh("EmitterGuardRail", add_cylinder(builder, 0.045, 0.74, steel, 18)),
        "EmitterGuardBrace": mesh("EmitterGuardBrace", add_box(builder, (0.12, 0.12, 0.46), oxide)),
        "EmitterLensCap": mesh("EmitterLensCap", add_uv_sphere(builder, 0.17, cyan)),
        "ServiceFace": mesh("ServiceFace", add_box(builder, (0.56, 0.14, 0.38), chassis)),
        "ServiceWindow": mesh("ServiceWindow", add_box(builder, (0.34, 0.035, 0.13), cyan)),
        "ServiceFastener": mesh("ServiceFastener", add_cylinder(builder, 0.028, 0.035, warm, 20)),
        "Crown": mesh("Crown", add_box(builder, (0.76, 0.12, 0.2), oxide)),
        "Fin": mesh("Fin", add_box(builder, (0.14, 0.42, 0.64), steel)),
        "Lamp": mesh("Lamp", add_uv_sphere(builder, 0.07, warm)),
        "Cable": mesh("Cable", add_cylinder(builder, 0.035, 0.7, rubber, 12)),
        "Fastener": mesh("Fastener", add_cylinder(builder, 0.045, 0.04, warm, 20)),
    }

    nodes: list[dict] = [{
        "name": "BulwarkModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "bulwark.companion.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "weapon_muzzle, protection_emitter, sensor",
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

    add_node("Chassis", mesh_ids["Chassis"], (0.0, 0.86, 0.0), extras={"surface": "beveled_primary_body"})
    add_node("ChassisCore", mesh_ids["ChassisCore"], (0.0, 0.92, -0.02))
    add_node("ArmorPlate", mesh_ids["Plate"], (0.0, 1.22, -0.86), rotation=(0.04, 0.0, 0.0))
    add_node("LowerChassis", mesh_ids["Panel"], (0.0, 0.48, 0.02))
    add_node("ChassisDetailPanel", mesh_ids["Panel"], (0.0, 1.37, -0.84), extras={"surface": "service_panel"})
    add_node("ChassisSpine", mesh_ids["Rail"], (0.0, 0.92, 0.68))
    for side in (-1.0, 1.0):
        for front in (-1.0, 1.0):
            add_node("ChassisCornerCap", mesh_ids["Corner"], (side * 0.69, 0.85, front * 0.68))
            add_node("Leg", mesh_ids["Leg"], (side * 0.54, 0.43, front * 0.48), rotation=(0.0, 0.0, side * 0.2))
            add_node("Foot", mesh_ids["Foot"], (side * 0.66, 0.12, front * 0.48), rotation=(0.0, 0.0, side * 0.04))
    add_node("OpticHousing", mesh_ids["OpticHousing"], (0.0, 1.16, -0.94))
    add_node("Sensor", mesh_ids["Optic"], (0.0, 1.15, -1.04), extras={"socket_type": "sensor"})
    add_node("OpticLens", mesh_ids["Optic"], (0.0, 1.15, -1.10), extras={"socket_type": "optic"})
    add_node("BulwarkFrontPlate", mesh_ids["Plate"], (0.0, 1.02, -1.01), rotation=(-0.06, 0.0, 0.0))
    add_node("RearShield", mesh_ids["Shield"], (0.0, 0.78, 0.78))
    add_node("ShieldRib", mesh_ids["ShieldRib"], (0.0, 1.04, 0.86))
    for side in (-1.0, 1.0):
        add_node("ShoulderPlate", mesh_ids["Plate"], (side * 0.87, 1.0, -0.04), rotation=(0.0, 0.0, side * 0.1))
        add_node("BulwarkGun", mesh_ids["Gun"], (side * 0.3, 1.38, -0.82), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"socket_type": "weapon_mount"})
        add_node("WeaponBarrel", mesh_ids["Gun"], (side * 0.3, 1.38, -1.1), rotation=(math.pi * 0.5, 0.0, 0.0))
        add_node("WeaponMuzzle", mesh_ids["Muzzle"], (side * 0.3, 1.38, -1.55), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"socket_type": "weapon_muzzle"})
        add_node("BulwarkShoulder", mesh_ids["Plate"], (side * 0.91, 0.84, -0.35), rotation=(0.0, 0.0, side * 0.12))
        add_node("BulwarkShieldGuard", mesh_ids["Fin"], (side * 0.96, 1.02, 0.55), rotation=(0.0, 0.0, side * 0.08))
        add_node("BulwarkLamp", mesh_ids["Lamp"], (side * 0.58, 1.43, -1.1))
        add_node("MachineCable", mesh_ids["Cable"], (side * 0.7, 0.98, 0.06), rotation=(0.0, 0.0, side * 0.2))
        for height in (0.97, 1.23):
            add_node("ArmorFastener", mesh_ids["Fastener"], (side * 0.61, height, -1.03), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("BulwarkRadiator", mesh_ids["Panel"], (0.0, 1.64, 0.45))
    add_node("BulwarkShieldEmitterSpine", mesh_ids["EmitterSpine"], (0.0, 1.95, 0.5), extras={"socket_type": "protection_emitter"})
    add_node("BulwarkShieldEmitter", mesh_ids["Emitter"], (0.0, 2.3, 0.5), extras={"socket_type": "protection_emitter"})
    # The emitter is the companion's defining protection instrument. A
    # guarded, asymmetric cage and a small service face give that instrument
    # manufactured depth at close tactical distance without changing the
    # existing protection socket or gameplay collision.
    add_node("BulwarkEmitterGuardL", mesh_ids["EmitterGuardRail"], (-0.32, 2.18, 0.5), rotation=(0.0, 0.0, -0.22))
    add_node("BulwarkEmitterGuardR", mesh_ids["EmitterGuardRail"], (0.32, 2.18, 0.5), rotation=(0.0, 0.0, 0.28))
    add_node("BulwarkEmitterGuardBraceL", mesh_ids["EmitterGuardBrace"], (-0.32, 2.03, 0.5), rotation=(0.0, 0.0, 0.18))
    add_node("BulwarkEmitterGuardBraceR", mesh_ids["EmitterGuardBrace"], (0.32, 2.03, 0.5), rotation=(0.0, 0.0, -0.24))
    add_node("BulwarkEmitterLensCap", mesh_ids["EmitterLensCap"], (0.0, 2.48, 0.5), extras={"presentation": "protected_emitter_lens"})
    add_node("BulwarkServiceFace", mesh_ids["ServiceFace"], (0.0, 1.03, -1.08), rotation=(0.0, 0.0, -0.04), extras={"surface": "front_service_face"})
    add_node("BulwarkServiceWindow", mesh_ids["ServiceWindow"], (0.0, 1.06, -1.16), rotation=(0.0, 0.0, -0.04))
    for side in (-1.0, 1.0):
        add_node("BulwarkServiceFastener", mesh_ids["ServiceFastener"], (side * 0.2, 1.17, -1.16), rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("CompanionCrown", mesh_ids["Crown"], (0.0, 1.52, 0.18))
    add_node("CompanionCrownMast", mesh_ids["EmitterSpine"], (0.0, 1.88, 0.18))
    for side in (-1.0, 1.0):
        add_node("BulwarkCoolingFin", mesh_ids["Fin"], (side * 0.72, 1.52, 0.42), rotation=(0.0, 0.0, side * 0.35))
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "bulwark.companion.v1", "source": "original_procedural_mesh_builder"})

    node_index = {node["name"]: index for index, node in enumerate(nodes)}

    def animation(name: str, channels: list[tuple[str, str, list[float], list[float]]]) -> dict:
        samplers: list[dict] = []
        channel_entries: list[dict] = []
        output_type = {"translation": ("VEC3", 3), "rotation": ("VEC4", 4)}
        for target_name, path, times, values in channels:
            time_accessor = builder.accessor(times, 5126, "SCALAR", len(times), minimum=[min(times)], maximum=[max(times)])
            type_name, width = output_type[path]
            output_accessor = builder.accessor(values, 5126, type_name, len(values) // width)
            sampler_index = len(samplers)
            samplers.append({"input": time_accessor, "output": output_accessor, "interpolation": "LINEAR"})
            channel_entries.append({"sampler": sampler_index, "target": {"node": node_index[target_name], "path": path}})
        return {"name": name, "samplers": samplers, "channels": channel_entries}

    animations = [
        animation("Idle", [
            ("BulwarkModel", "translation", [0.0, 0.8, 1.6], [0.0, 0.0, 0.0, 0.0, 0.012, 0.0, 0.0, 0.0, 0.0]),
            ("Sensor", "rotation", [0.0, 0.8, 1.6], quat((0.0, -0.06, 0.0)) + quat((0.0, 0.06, 0.0)) + quat((0.0, -0.06, 0.0))),
            ("ShieldRib", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.0, -0.018)) + quat((0.0, 0.0, 0.018)) + quat((0.0, 0.0, -0.018))),
        ]),
        animation("Walk", [
            ("Leg", "rotation", [0.0, 0.22, 0.44], quat((0.22, 0.0, 0.0)) + quat((-0.22, 0.0, 0.0)) + quat((0.22, 0.0, 0.0))),
            ("Foot", "rotation", [0.0, 0.22, 0.44], quat((-0.12, 0.0, 0.0)) + quat((0.12, 0.0, 0.0)) + quat((-0.12, 0.0, 0.0))),
            ("Chassis", "rotation", [0.0, 0.22, 0.44], quat((0.035, 0.0, 0.0)) + quat((-0.035, 0.0, 0.0)) + quat((0.035, 0.0, 0.0))),
            ("CompanionCrown", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.04, 0.0)) + quat((0.0, -0.04, 0.0)) + quat((0.0, 0.04, 0.0))),
        ]),
        animation("Fire", [
            ("BulwarkGun", "translation", [0.0, 0.08, 0.18], [0.0, 0.0, -0.82, 0.0, 0.0, -0.9, 0.0, 0.0, -0.82]),
            ("Sensor", "rotation", [0.0, 0.08, 0.18], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.12, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("ShieldRib", "rotation", [0.0, 0.08, 0.18], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, -0.04)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Hit", [
            ("BulwarkModel", "translation", [0.0, 0.10, 0.24], [0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.0, 0.0]),
            ("Sensor", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((-0.15, 0.08, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Retreat", [
            ("BulwarkModel", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.12)) + quat((0.0, 0.0, 0.0))),
            ("Sensor", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.0)) + quat((0.0, -0.12, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Death", [
            ("BulwarkModel", "translation", [0.0, 0.18, 0.42], [0.0, 0.0, 0.0, 0.0, -0.08, 0.0, 0.0, -0.22, 0.0]),
            ("BulwarkModel", "rotation", [0.0, 0.18, 0.42], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.16, 0.22)) + quat((0.0, 0.22, 0.32))),
        ]),
    ]

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Bulwark asset builder"},
        "scene": 0,
        "scenes": [{"name": "Bulwark", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": "bulwark.companion.v1",
            "required_nodes": ["BulwarkModel", "Sensor", "OpticLens", "WeaponMuzzle", "BulwarkShieldEmitter", "BulwarkEmitterGuardL", "BulwarkEmitterGuardR", "BulwarkServiceFace", "BulwarkServiceWindow", "ProductionAssetMarker"],
            "animation_clips": ["Idle", "Walk", "Fire", "Hit", "Retreat", "Death"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
