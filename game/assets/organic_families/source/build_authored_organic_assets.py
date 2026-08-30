"""Build the remaining original high-definition organic family shells.

The seven assets in this builder deliberately share a small production mesh kit
while keeping distinct silhouettes and stable anatomy names. They are imported
as presentation shells; gameplay collision, ecology and tier data remain owned
by the runtime enemy actor.
"""

from __future__ import annotations

import base64
import json
import math
import sys
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parent
ASSET_ROOT = SOURCE_DIR.parents[1]
sys.path.insert(0, str(ASSET_ROOT / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, _geometry, add_beveled_box, add_cylinder, add_ellipsoid, add_uv_sphere, quat  # noqa: E402


FAMILIES = {
    "roofleaper": {
        "display": "Roofleaper",
        "asset_id": "roofleaper.ambusher.v1",
        "colors": ([0.035, 0.055, 0.07, 1.0], [0.16, 0.22, 0.25, 1.0], [0.10, 0.28, 0.34, 1.0], [0.48, 0.39, 0.28, 1.0], [0.75, 0.22, 0.04, 1.0], [0.30, 0.09, 0.08, 1.0]),
        "body_profile": ((1.25, 0.74, 1.55), (1.08, 0.66, 1.20), 0.04),
        "socket_contract": "crown, wing_membranes, talons, threat_eyes",
        "signature_nodes": ["RoofleaperFineVeinL", "RoofleaperFineVeinR", "RoofleaperWingFrameL", "RoofleaperWingFastenerR"],
    },
    "glassmoth": {
        "display": "Glassmoth",
        "asset_id": "glassmoth.swarm.v1",
        "colors": ([0.025, 0.07, 0.075, 1.0], [0.19, 0.38, 0.39, 1.0], [0.27, 0.16, 0.34, 1.0], [0.64, 0.58, 0.43, 1.0], [0.12, 0.72, 0.68, 1.0], [0.20, 0.24, 0.26, 1.0]),
        "body_profile": ((0.94, 1.04, 1.18), (0.88, 0.82, 1.02), 0.035),
        "socket_contract": "wing_pairs, antennae, luminous_eyes, thorax",
        "signature_nodes": ["GlassmothFineVeinL0", "GlassmothFineVeinR0", "GlassmothWingFrameL0", "GlassmothWingFastenerR1"],
    },
    "miremaw": {
        "display": "Miremaw",
        "asset_id": "miremaw.amphibious.v1",
        "colors": ([0.035, 0.065, 0.045, 1.0], [0.22, 0.28, 0.18, 1.0], [0.25, 0.07, 0.045, 1.0], [0.52, 0.44, 0.29, 1.0], [0.82, 0.32, 0.05, 1.0], [0.28, 0.12, 0.075, 1.0]),
        "body_profile": ((1.45, 0.76, 1.34), (1.28, 0.66, 1.10), 0.025),
        "socket_contract": "maw, gill_fan, water_fins, jaw_hooks",
        "signature_nodes": ["MiremawGillRidgeL", "MiremawGillRidgeR", "MiremawJawPlateL", "MiremawGillSpineR", "MiremawGillCollarL"],
    },
    "carrionbell": {
        "display": "Carrion Bell",
        "asset_id": "carrionbell.signal.v1",
        "colors": ([0.065, 0.035, 0.06, 1.0], [0.25, 0.12, 0.22, 1.0], [0.35, 0.08, 0.24, 1.0], [0.56, 0.45, 0.32, 1.0], [0.9, 0.22, 0.14, 1.0], [0.34, 0.09, 0.16, 1.0]),
        "body_profile": ((1.32, 1.15, 1.18), (1.18, 0.86, 1.02), 0.02),
        "socket_contract": "resonator, bell_mantle, signal_tendrils, crown_plate",
        "signature_nodes": ["CarrionbellResonatorRing", "CarrionbellResonatorCore", "CarrionbellBellRib0"],
    },
    "rootweaver": {
        "display": "Rootweaver",
        "asset_id": "rootweaver.route_controller.v1",
        "colors": ([0.035, 0.05, 0.04, 1.0], [0.20, 0.23, 0.14, 1.0], [0.29, 0.06, 0.12, 1.0], [0.48, 0.38, 0.24, 1.0], [0.16, 0.72, 0.63, 1.0], [0.28, 0.08, 0.09, 1.0]),
        "body_profile": ((1.18, 1.05, 1.45), (1.04, 0.84, 1.18), 0.025),
        "socket_contract": "root_arms, route_spines, spore_fan, crown_oculi",
        "signature_nodes": ["RootweaverKnuckleL", "RootweaverKnuckleR", "RootweaverCrownPlate0", "RootweaverJawPlateL", "RootweaverJawPlateR", "RootweaverRootSpineR"],
    },
    "thornback": {
        "display": "Thornback",
        "asset_id": "thornback.territorial.v1",
        "colors": ([0.055, 0.045, 0.035, 1.0], [0.30, 0.19, 0.10, 1.0], [0.36, 0.12, 0.08, 1.0], [0.57, 0.46, 0.30, 1.0], [0.92, 0.38, 0.08, 1.0], [0.34, 0.12, 0.07, 1.0]),
        "body_profile": ((1.50, 0.82, 1.45), (1.34, 0.75, 1.25), 0.03),
        "socket_contract": "thorn_crown, dorsal_spines, jaw_plates, threat_eyes",
        "signature_nodes": ["ThornbackCrown", "ThornbackSpineL", "ThornbackSpineR", "ThornbackJawPlateL", "ThornbackBarb0"],
    },
    "ashmantle": {
        "display": "Ashmantle",
        "asset_id": "ashmantle.route_predator.v1",
        "colors": ([0.035, 0.045, 0.055, 1.0], [0.16, 0.20, 0.24, 1.0], [0.20, 0.27, 0.32, 1.0], [0.52, 0.48, 0.38, 1.0], [0.94, 0.23, 0.08, 1.0], [0.18, 0.10, 0.08, 1.0]),
        "body_profile": ((1.48, 0.82, 1.42), (1.30, 0.72, 1.22), 0.03),
        "socket_contract": "heat_mantle, louver_fins, route_siphon, sensory_tendrils",
        "signature_nodes": ["AshmantleMantle", "AshmantleHeatLouverL", "AshmantleHeatLouverR", "AshmantleSiphon", "AshmantleSiphonRing"],
    },
}


def add_convex_sheet(
    builder: BufferBuilder,
    size: Sequence[float],
    material: int,
    rings: int = 5,
    sides: int = 24,
) -> tuple[int, int, int, int]:
    """Build a smooth organic plate or membrane with a raised center and edge rim.

    The old shared kit used beveled boxes for both shell plates and membranes.
    That kept the node/socket contract stable but left broad anatomy reading as
    manufactured flat bars in the compact review gallery. This sheet keeps the
    same authored dimensions while giving the key light a continuous convex
    surface and a real perimeter break.
    """
    width, thickness, depth = (max(0.001, float(value)) for value in size)
    rings = max(4, rings)
    sides = max(24, sides)
    half_width = width * 0.5
    half_thickness = thickness * 0.5
    half_depth = depth * 0.5
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []

    def add_vertex(point: Sequence[float], normal: Sequence[float]) -> int:
        index = len(positions) // 3
        positions.extend(point)
        length = math.sqrt(sum(value * value for value in normal)) or 1.0
        normals.extend(value / length for value in normal)
        return index

    surfaces: dict[int, list[list[int]]] = {}
    for sign in (1, -1):
        center = add_vertex((0.0, sign * half_thickness, 0.0), (0.0, sign, 0.0))
        ring_indices: list[list[int]] = []
        for ring in range(1, rings + 1):
            radius = ring / rings
            y = sign * half_thickness * (0.34 + 0.66 * (1.0 - radius * radius))
            current: list[int] = []
            for side in range(sides):
                angle = math.tau * side / sides
                cosine = math.cos(angle)
                sine = math.sin(angle)
                current.append(add_vertex(
                    (half_width * radius * cosine, y, half_depth * radius * sine),
                    (sign * 0.95 * radius * cosine, sign, sign * 0.95 * radius * sine),
                ))
            ring_indices.append(current)
            previous = ring_indices[-2] if len(ring_indices) > 1 else None
            for side in range(sides):
                next_side = (side + 1) % sides
                if previous is None:
                    if sign > 0:
                        indices.extend([center, current[next_side], current[side]])
                    else:
                        indices.extend([center, current[side], current[next_side]])
                elif sign > 0:
                    indices.extend([
                        previous[side], previous[next_side], current[next_side],
                        previous[side], current[next_side], current[side],
                    ])
                else:
                    indices.extend([
                        previous[side], current[side], current[next_side],
                        previous[side], current[next_side], previous[next_side],
                    ])
        surfaces[sign] = ring_indices

    rim_front: list[int] = []
    rim_back: list[int] = []
    rim_y = half_thickness * 0.34
    for side in range(sides):
        angle = math.tau * side / sides
        cosine = math.cos(angle)
        sine = math.sin(angle)
        rim_normal = (cosine, 0.0, sine)
        rim_front.append(add_vertex((half_width * cosine, rim_y, half_depth * sine), rim_normal))
        rim_back.append(add_vertex((half_width * cosine, -rim_y, half_depth * sine), rim_normal))
    for side in range(sides):
        next_side = (side + 1) % sides
        indices.extend([
            rim_front[side], rim_front[next_side], rim_back[next_side],
            rim_front[side], rim_back[next_side], rim_back[side],
        ])

    return _geometry(builder, positions, normals, indices, material)


def add_organic_lobe(
    builder: BufferBuilder,
    size: Sequence[float],
    material: int,
    lobes: int = 3,
    rings: int = 8,
    sides: int = 36,
    scallop_amplitude: float = 0.16,
    leading_extension: float = 0.42,
    fold_strength: float = 0.88,
) -> tuple[int, int, int, int]:
    """Build a tapered living lobe instead of a repeated oval disc.

    The late-family membranes are broad enough to carry silhouette identity,
    but the old shared ellipsoid made every creature read as a stack of flat
    dishes. This closed petal-like form keeps a dense convex highlight while
    tapering the leading edge and giving the perimeter a restrained biological
    scallop. It remains a presentation shell; sockets and collision stay with
    the runtime actor.
    """
    width, thickness, depth = (max(0.001, float(value)) for value in size)
    rings = max(6, int(rings))
    sides = max(32, int(sides))
    lobes = max(2, int(lobes))
    half_width = width * 0.5
    half_thickness = thickness * 0.5
    half_depth = depth * 0.5
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []

    def add_vertex(point: Sequence[float], normal: Sequence[float]) -> int:
        index = len(positions) // 3
        positions.extend(point)
        length = math.sqrt(sum(value * value for value in normal)) or 1.0
        normals.extend(value / length for value in normal)
        return index

    scallop_amplitude = max(0.0, float(scallop_amplitude))
    leading_extension = max(0.0, float(leading_extension))
    fold_strength = max(0.0, float(fold_strength))
    for sign in (1.0, -1.0):
        center = add_vertex((0.0, sign * half_thickness * 1.58, -half_depth * 0.24), (0.0, sign, 0.0))
        ring_indices: list[list[int]] = []
        for ring in range(1, rings + 1):
            radius = ring / rings
            current: list[int] = []
            for side in range(sides):
                angle = math.tau * side / sides
                cosine = math.cos(angle)
                sine = math.sin(angle)
                scallop = 1.0 + scallop_amplitude * math.cos(float(lobes) * angle)
                # The front edge is slightly longer and sharper, like a
                # living fin or leaf, while the rear edge stays broad enough
                # to catch a readable rim highlight.
                leading_edge = 1.0 + leading_extension * max(0.0, -sine)
                x = half_width * radius * cosine * scallop
                z = half_depth * radius * sine * leading_edge - half_depth * 0.18 * (1.0 - radius)
                crown = 0.26 + 0.74 * (1.0 - radius * radius)
                fold = half_thickness * fold_strength * abs(cosine) * (1.0 - radius * 0.22)
                y = sign * (half_thickness * crown + fold)
                y += sign * half_thickness * 0.16 * math.sin(float(lobes) * angle) * radius
                current.append(add_vertex(
                    (x, y, z),
                    (sign * 0.8 * radius * cosine, sign, sign * 0.95 * radius * sine),
                ))
            ring_indices.append(current)
            previous = ring_indices[-2] if len(ring_indices) > 1 else None
            for side in range(sides):
                next_side = (side + 1) % sides
                if previous is None:
                    if sign > 0.0:
                        indices.extend([center, current[next_side], current[side]])
                    else:
                        indices.extend([center, current[side], current[next_side]])
                elif sign > 0.0:
                    indices.extend([
                        previous[side], previous[next_side], current[next_side],
                        previous[side], current[next_side], current[side],
                    ])
                else:
                    indices.extend([
                        previous[side], current[side], current[next_side],
                        previous[side], current[next_side], previous[next_side],
                    ])

    rim_front: list[int] = []
    rim_back: list[int] = []
    rim_radius = 1.0
    for side in range(sides):
        angle = math.tau * side / sides
        cosine = math.cos(angle)
        sine = math.sin(angle)
        scallop = 1.0 + scallop_amplitude * math.cos(float(lobes) * angle)
        leading_edge = 1.0 + leading_extension * max(0.0, -sine)
        x = half_width * cosine * scallop
        z = half_depth * sine * leading_edge
        rim_front.append(add_vertex((x, half_thickness * 0.32, z), (cosine, 0.0, sine)))
        rim_back.append(add_vertex((x, -half_thickness * 0.32, z), (cosine, 0.0, sine)))
    for side in range(sides):
        next_side = (side + 1) % sides
        indices.extend([
            rim_front[side], rim_front[next_side], rim_back[next_side],
            rim_front[side], rim_back[next_side], rim_back[side],
        ])

    return _geometry(builder, positions, normals, indices, material)


def add_swept_wing_membrane(
    builder: BufferBuilder,
    size: Sequence[float],
    material: int,
    rings: int = 9,
    sides: int = 40,
) -> tuple[int, int, int, int]:
    """Build a tapered wing with a raised keel instead of an oval sheet.

    Airborne early families need a directional leading edge and a readable
    root-to-tip sweep. The shared oval membrane was technically convex but
    still collapsed into a stack of discs at gallery distance. This mesh keeps
    the same local socket dimensions while tightening the outer edge, adding a
    restrained four-lobed scallop and lifting a shallow living keel through
    the centre.
    """
    width, thickness, depth = (max(0.001, float(value)) for value in size)
    rings = max(6, int(rings))
    sides = max(32, int(sides))
    half_width = width * 0.5
    half_thickness = thickness * 0.5
    half_depth = depth * 0.5
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []

    def add_vertex(point: Sequence[float], normal: Sequence[float]) -> int:
        index = len(positions) // 3
        positions.extend(point)
        length = math.sqrt(sum(value * value for value in normal)) or 1.0
        normals.extend(value / length for value in normal)
        return index

    for sign in (1.0, -1.0):
        center = add_vertex((0.0, sign * half_thickness * 1.18, -half_depth * 0.12), (0.0, sign, 0.0))
        ring_indices: list[list[int]] = []
        for ring in range(1, rings + 1):
            radius = ring / rings
            current: list[int] = []
            for side in range(sides):
                angle = math.tau * side / sides
                cosine = math.cos(angle)
                sine = math.sin(angle)
                # Narrow the root-facing rear edge and sharpen the forward
                # sweep so the silhouette reads as a wing, not a plate.
                rear_taper = 0.78 + 0.22 * max(0.0, -cosine)
                forward_sweep = 1.0 + 0.34 * max(0.0, -sine)
                scallop = 1.0 + 0.14 * math.cos(4.0 * angle)
                x = half_width * radius * cosine * rear_taper * scallop
                z = half_depth * radius * sine * forward_sweep * scallop - half_depth * 0.12 * (1.0 - radius)
                crown = 0.34 + 0.66 * (1.0 - radius * radius)
                keel = 0.12 * abs(cosine) * (1.0 - radius * 0.42)
                y = sign * (half_thickness * crown + keel)
                y += sign * half_thickness * 0.12 * math.sin(4.0 * angle) * radius
                current.append(add_vertex(
                    (x, y, z),
                    (sign * 0.9 * radius * cosine, sign, sign * 1.05 * radius * sine),
                ))
            ring_indices.append(current)
            previous = ring_indices[-2] if len(ring_indices) > 1 else None
            for side in range(sides):
                next_side = (side + 1) % sides
                if previous is None:
                    if sign > 0.0:
                        indices.extend([center, current[next_side], current[side]])
                    else:
                        indices.extend([center, current[side], current[next_side]])
                elif sign > 0.0:
                    indices.extend([
                        previous[side], previous[next_side], current[next_side],
                        previous[side], current[next_side], current[side],
                    ])
                else:
                    indices.extend([
                        previous[side], current[side], current[next_side],
                        previous[side], current[next_side], previous[next_side],
                    ])

    rim_front: list[int] = []
    rim_back: list[int] = []
    for side in range(sides):
        angle = math.tau * side / sides
        cosine = math.cos(angle)
        sine = math.sin(angle)
        rear_taper = 0.78 + 0.22 * max(0.0, -cosine)
        forward_sweep = 1.0 + 0.34 * max(0.0, -sine)
        scallop = 1.0 + 0.14 * math.cos(4.0 * angle)
        x = half_width * cosine * rear_taper * scallop
        z = half_depth * sine * forward_sweep * scallop
        rim_front.append(add_vertex((x, half_thickness * 0.34, z), (cosine, 0.0, sine)))
        rim_back.append(add_vertex((x, -half_thickness * 0.34, z), (cosine, 0.0, sine)))
    for side in range(sides):
        next_side = (side + 1) % sides
        indices.extend([
            rim_front[side], rim_front[next_side], rim_back[next_side],
            rim_front[side], rim_back[next_side], rim_back[side],
        ])

    return _geometry(builder, positions, normals, indices, material)


def add_capsule(
    builder: BufferBuilder,
    radius: float,
    height: float,
    material: int,
    sides: int = 24,
    cap_segments: int = 6,
) -> tuple[int, int, int, int]:
    """Build a smooth vertical capsule for living structural details.

    The shared family kit previously used capped cylinders for every bone,
    wing spar and tendon. At the compact review distance those flat ends read
    as manufactured rods and caught the shadow as black bars. Rounded caps
    keep the same dimensions and material contract while giving each detail a
    softer, more biological silhouette.
    """
    radius = max(0.001, float(radius))
    height = max(float(height), radius * 2.05)
    sides = max(24, int(sides))
    cap_segments = max(4, int(cap_segments))
    half_body = max(0.0, height * 0.5 - radius)
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []
    rings: list[list[int]] = []

    def add_ring(y: float, ring_radius: float, normal_y: float) -> None:
        ring: list[int] = []
        for side in range(sides):
            angle = math.tau * side / sides
            cosine = math.cos(angle)
            sine = math.sin(angle)
            normal = (ring_radius * cosine, normal_y, ring_radius * sine)
            normal_length = math.sqrt(sum(value * value for value in normal)) or 1.0
            ring.append(len(positions) // 3)
            positions.extend([ring_radius * cosine, y, ring_radius * sine])
            normals.extend(value / normal_length for value in normal)
        rings.append(ring)

    for index in range(cap_segments + 1):
        theta = -math.pi * 0.5 + math.pi * 0.5 * index / cap_segments
        add_ring(-half_body + math.sin(theta) * radius, math.cos(theta) * radius, math.sin(theta))
    if half_body > 0.0:
        add_ring(half_body, radius, 0.0)
    for index in range(1, cap_segments + 1):
        theta = math.pi * 0.5 * index / cap_segments
        add_ring(half_body + math.sin(theta) * radius, math.cos(theta) * radius, math.sin(theta))

    for ring_index in range(len(rings) - 1):
        current = rings[ring_index]
        next_ring = rings[ring_index + 1]
        for side in range(sides):
            next_side = (side + 1) % sides
            indices.extend([
                current[side], current[next_side], next_ring[next_side],
                current[side], next_ring[next_side], next_ring[side],
            ])
    return _geometry(builder, positions, normals, indices, material)


def add_tapered_thorn(
    builder: BufferBuilder,
    base_radius: float,
    height: float,
    material: int,
    sides: int = 32,
) -> tuple[int, int, int, int]:
    """Build a rounded-base, sharply tapered organic barb along local Y."""
    base_radius = max(0.001, float(base_radius))
    height = max(float(height), base_radius * 2.2)
    sides = max(24, int(sides))
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []
    rings: list[list[int]] = []
    ring_data = (
        (-height * 0.5, base_radius * 0.72),
        (-height * 0.28, base_radius),
        (height * 0.08, base_radius * 0.62),
        (height * 0.5, base_radius * 0.035),
    )
    for y, radius in ring_data:
        ring: list[int] = []
        for side in range(sides):
            angle = math.tau * side / sides
            cosine = math.cos(angle)
            sine = math.sin(angle)
            slope = (base_radius * 0.55) / height
            normal = (cosine, slope, sine)
            length = math.sqrt(sum(value * value for value in normal)) or 1.0
            ring.append(len(positions) // 3)
            positions.extend([radius * cosine, y, radius * sine])
            normals.extend(value / length for value in normal)
        rings.append(ring)
    for ring_index in range(len(rings) - 1):
        current = rings[ring_index]
        next_ring = rings[ring_index + 1]
        for side in range(sides):
            next_side = (side + 1) % sides
            indices.extend([
                current[side], current[next_side], next_ring[next_side],
                current[side], next_ring[next_side], next_ring[side],
            ])
    bottom_center = len(positions) // 3
    positions.extend([0.0, -height * 0.5, 0.0])
    normals.extend([0.0, -1.0, 0.0])
    for side in range(sides):
        next_side = (side + 1) % sides
        indices.extend([bottom_center, rings[0][next_side], rings[0][side]])
    return _geometry(builder, positions, normals, indices, material)


def add_torus(
    builder: BufferBuilder,
    major_radius: float,
    minor_radius: float,
    material: int,
    major_segments: int = 36,
    minor_segments: int = 10,
) -> tuple[int, int, int, int]:
    """Build a smooth resonator ring around a living signal core."""
    major_segments = max(24, major_segments)
    minor_segments = max(8, minor_segments)
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []
    for major_index in range(major_segments):
        major_angle = math.tau * major_index / major_segments
        major_cosine = math.cos(major_angle)
        major_sine = math.sin(major_angle)
        for minor_index in range(minor_segments):
            minor_angle = math.tau * minor_index / minor_segments
            minor_cosine = math.cos(minor_angle)
            minor_sine = math.sin(minor_angle)
            ring_radius = major_radius + minor_radius * minor_cosine
            positions.extend([
                ring_radius * major_cosine,
                minor_radius * minor_sine,
                ring_radius * major_sine,
            ])
            normals.extend([
                minor_cosine * major_cosine,
                minor_sine,
                minor_cosine * major_sine,
            ])
    for major_index in range(major_segments):
        next_major = (major_index + 1) % major_segments
        for minor_index in range(minor_segments):
            next_minor = (minor_index + 1) % minor_segments
            a = major_index * minor_segments + minor_index
            b = next_major * minor_segments + minor_index
            c = next_major * minor_segments + next_minor
            d = major_index * minor_segments + next_minor
            indices.extend([a, b, c, a, c, d])
    return _geometry(builder, positions, normals, indices, material)


def build_family(name: str, spec: dict) -> None:
    builder = BufferBuilder()
    wet, shell, membrane, bone, eye, tendon = range(6)
    colors = spec["colors"]
    membrane_tone = [channel * 0.62 if index < 3 else channel for index, channel in enumerate(colors[2])]
    # Glassmoth is the luminous territorial swarm. Its wing membranes should
    # carry a cool living-light identity instead of inheriting the warmer
    # threat palette used by the terrestrial families.
    if name == "glassmoth":
        membrane_tone = [0.07, 0.34, 0.36, 1.0]
    threat_emissive = [0.14, 0.86, 0.72] if name == "glassmoth" else [1.0, 0.18, 0.04]
    materials = [
        {"name": f"{spec['display']} wet shell", "pbrMetallicRoughness": {"baseColorFactor": list(colors[0]), "metallicFactor": 0.18, "roughnessFactor": 0.32}},
        {"name": f"{spec['display']} layered plate", "pbrMetallicRoughness": {"baseColorFactor": list(colors[1]), "metallicFactor": 0.14, "roughnessFactor": 0.42}},
        {"name": f"{spec['display']} membrane", "pbrMetallicRoughness": {"baseColorFactor": membrane_tone, "metallicFactor": 0.02, "roughnessFactor": 0.58}},
        {"name": f"{spec['display']} bone", "pbrMetallicRoughness": {"baseColorFactor": list(colors[3]), "metallicFactor": 0.0, "roughnessFactor": 0.62}},
        {"name": f"{spec['display']} threat light", "pbrMetallicRoughness": {"baseColorFactor": list(colors[4]), "metallicFactor": 0.0, "roughnessFactor": 0.22}, "emissiveFactor": threat_emissive},
        {"name": f"{spec['display']} tendon", "pbrMetallicRoughness": {"baseColorFactor": list(colors[5]), "metallicFactor": 0.0, "roughnessFactor": 0.55}},
    ]
    if name == "glassmoth":
        # A muted cyan living vein separates the broad luminous membrane from
        # the pale structural spars without turning the wing into a glowing
        # grid. It remains presentation-only under the existing wing rig.
        materials.append({
            "name": "Glassmoth wing vascular detail",
            "pbrMetallicRoughness": {
                "baseColorFactor": [0.40, 0.66, 0.60, 1.0],
                "metallicFactor": 0.02,
                "roughnessFactor": 0.44,
            },
            "emissiveFactor": [0.035, 0.24, 0.20],
        })
    meshes: list[dict] = []

    def mesh(mesh_name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": mesh_name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    mesh_ids = {
        # The close tactical camera makes the old low radial counts read as
        # faceted on the wet core and family crowns. Keep the dependency-free
        # builder, but spend the extra geometry where the silhouette catches
        # light instead of hiding the issue behind a material-only pass.
        "Core": mesh("Core", add_uv_sphere(builder, 0.62, wet, 24, 36)),
        "Segment": mesh("Segment", add_uv_sphere(builder, 0.48, shell, 24, 36)),
        # The torso ribs are the dominant close-gallery surface. A thin sheet
        # made them read as repeated manufactured bars at 1280x720, even
        # though the family-specific sockets were present. Keep the original
        # Plate mesh for narrow crowns and fins, but make the shared torso
        # layer a rounded ellipsoidal shell with a softer biological highlight
        # rolloff.
        "Plate": mesh("Plate", add_convex_sheet(builder, (1.52, 0.16, 0.28), shell, rings=5, sides=24)),
        "ShellPlate": mesh("ShellPlate", add_organic_lobe(builder, (0.76, 0.18, 0.30), shell, lobes=4, rings=9, sides=40, scallop_amplitude=0.18, leading_extension=0.28, fold_strength=0.82)),
        # The membrane layer is the largest shared silhouette on the late
        # family gallery page. A symmetric ellipsoid still read as a stack of
        # repeated dishes, so use a deeper six-lobed fold with a denser
        # perimeter. The extra radial resolution is spent on the broad
        # silhouette surfaces that catch the compact gallery key light; the
        # socket dimensions and runtime ownership remain unchanged.
        "Membrane": mesh("Membrane", add_organic_lobe(builder, (1.26, 0.52, 1.08), membrane, lobes=6, rings=16, sides=64, scallop_amplitude=0.22, leading_extension=0.56, fold_strength=1.42)),
        "WingMembrane": mesh("WingMembrane", add_swept_wing_membrane(builder, (1.38, 0.26, 1.08), membrane, rings=14, sides=64)),
        "Bone": mesh("Bone", add_capsule(builder, 0.09, 0.86, bone, 24)),
        "LongBone": mesh("LongBone", add_capsule(builder, 0.065, 1.35, bone, 24)),
        "Tendon": mesh("Tendon", add_capsule(builder, 0.07, 1.15, tendon, 24)),
        "Eye": mesh("Eye", add_uv_sphere(builder, 0.095, eye, 24, 36)),
        "Soft": mesh("Soft", add_uv_sphere(builder, 0.34, membrane, 24, 36)),
        "Fastener": mesh("Fastener", add_uv_sphere(builder, 0.045, bone, 24, 36)),
        "FineVein": mesh("FineVein", add_capsule(builder, 0.026, 1.22, bone, 24)),
        "SurfaceVein": mesh("SurfaceVein", add_capsule(builder, 0.024, 0.88, tendon, 24)),
        "Ridge": mesh("Ridge", add_beveled_box(builder, (1.24, 0.07, 0.10), bone, 0.018)),
        "ResonatorRing": mesh("ResonatorRing", add_torus(builder, 0.19, 0.035, bone)),
        "RootKnuckle": mesh("RootKnuckle", add_uv_sphere(builder, 0.14, bone, 24, 36)),
        "WingFrame": mesh("WingFrame", add_capsule(builder, 0.045, 1.58, bone, 24)),
        "MembraneRib": mesh("MembraneRib", add_capsule(builder, 0.03, 0.82, bone, 24)),
        "GillSpine": mesh("GillSpine", add_capsule(builder, 0.045, 0.78, bone, 24)),
        "BellRib": mesh("BellRib", add_capsule(builder, 0.04, 0.92, bone, 24)),
        "RootSpine": mesh("RootSpine", add_capsule(builder, 0.055, 1.42, bone, 24)),
        "PlateCap": mesh("PlateCap", add_convex_sheet(builder, (0.44, 0.10, 0.18), bone, rings=4, sides=24)),
        "CrownFastener": mesh("CrownFastener", add_uv_sphere(builder, 0.06, bone, 24, 36)),
        # Keep the new late-family profile at the end of the shared mesh table
        # so existing mesh indices remain stable in generated assets.
        "DeepMembrane": mesh("DeepMembrane", add_organic_lobe(builder, (1.18, 0.62, 1.02), membrane, lobes=5, rings=16, sides=64, scallop_amplitude=0.18, leading_extension=0.42, fold_strength=1.68)),
    }
    if name == "glassmoth":
        mesh_ids["GlassmothWingVein"] = mesh(
            "GlassmothWingVein",
            add_capsule(builder, 0.024, 0.92, len(materials) - 1, 24),
        )
        # The broad luminous membranes need a living transition into the
        # thorax. A small folded root collar gives the wing socket a readable
        # load-bearing break instead of leaving the membrane to meet the body
        # as a thin sheet. It is parented to each existing wing node below so
        # the imported wing motion remains its sole animation owner.
        mesh_ids["GlassmothWingRootCollar"] = mesh(
            "GlassmothWingRootCollar",
            add_organic_lobe(
                builder,
                (0.56, 0.24, 0.42),
                shell,
                lobes=4,
                rings=9,
                sides=40,
                scallop_amplitude=0.14,
                leading_extension=0.22,
                fold_strength=0.76,
            ),
        )
    if name == "roofleaper":
        # The ambusher membranes need a living shoulder transition into the
        # broad thorax. A paired folded collar closes that root silhouette
        # without changing the existing wing socket or animation ownership.
        mesh_ids["RoofleaperWingRootCollar"] = mesh(
            "RoofleaperWingRootCollar",
            add_organic_lobe(
                builder,
                (0.56, 0.24, 0.46),
                shell,
                lobes=4,
                rings=9,
                sides=40,
                scallop_amplitude=0.15,
                leading_extension=0.24,
                fold_strength=0.82,
            ),
        )
        mesh_ids["RoofleaperCrownKeel"] = mesh(
            "RoofleaperCrownKeel",
            add_organic_lobe(
                builder,
                (0.70, 0.36, 0.62),
                shell,
                lobes=5,
                rings=10,
                sides=48,
                scallop_amplitude=0.16,
                leading_extension=0.26,
                fold_strength=0.92,
            ),
        )
    # Thornback's crown is a broad territorial shield. Build its thicker
    # folded lobe only for that family so the other six assets remain stable
    # when this focused pass changes.
    if name == "thornback":
        mesh_ids["ThornbackCrownLobe"] = mesh("ThornbackCrownLobe", add_organic_lobe(builder, (1.42, 0.38, 1.02), shell, lobes=4, rings=10, sides=40, scallop_amplitude=0.14, leading_extension=0.36, fold_strength=0.82))
        mesh_ids["ThornbackBarb"] = mesh("ThornbackBarb", add_tapered_thorn(builder, 0.14, 0.78, bone))
        # The territorial jaw needs a small, readable tooth edge beneath the
        # broad plates. Keep the teeth as children of those existing sockets so
        # the authored attack motion remains the sole motion owner.
        mesh_ids["ThornbackJawTooth"] = mesh("ThornbackJawTooth", add_tapered_thorn(builder, 0.07, 0.42, bone, sides=28))
    # Miremaw's gill fan is its breathing, amphibious identity. Add a paired
    # folded collar around the existing fan so the side profile carries a
    # layered membrane break instead of one broad plate. The collar is
    # presentation-only; the existing gill socket remains the animation and
    # runtime ownership anchor.
    if name == "miremaw":
        mesh_ids["MiremawGillCollar"] = mesh(
            "MiremawGillCollar",
            add_organic_lobe(
                builder,
                (0.82, 0.24, 0.52),
                membrane,
                lobes=5,
                rings=12,
                sides=48,
                scallop_amplitude=0.13,
                leading_extension=0.30,
                fold_strength=0.86,
            ),
        )
        # The amphibious maw is the closest-facing identity cue in the compact
        # release gallery. Give its lower jaw a closed folded shell so the head
        # reads as articulated living anatomy instead of two thin side plates.
        mesh_ids["MiremawJawLobe"] = mesh(
            "MiremawJawLobe",
            add_organic_lobe(
                builder,
                (0.62, 0.24, 0.42),
                bone,
                lobes=5,
                rings=11,
                sides=48,
                scallop_amplitude=0.13,
                leading_extension=0.24,
                fold_strength=0.84,
            ),
        )
    # Ashmantle's heat louvers and mantle ribs are its vented thermal identity.
    # Give those existing sockets a thicker folded living surface so the
    # family does not fall back to broad horizontal bars at gallery distance.
    if name == "ashmantle":
        mesh_ids["AshmantleHeatLouver"] = mesh(
            "AshmantleHeatLouver",
            add_organic_lobe(
                builder,
                (1.22, 0.38, 0.62),
                shell,
                lobes=4,
                rings=9,
                sides=40,
                scallop_amplitude=0.16,
                leading_extension=0.34,
                fold_strength=0.92,
            ),
        )
        mesh_ids["AshmantleMantleRib"] = mesh(
            "AshmantleMantleRib",
            add_organic_lobe(
                builder,
                (0.82, 0.18, 0.28),
                bone,
                lobes=3,
                rings=8,
                sides=36,
                scallop_amplitude=0.12,
                leading_extension=0.22,
                fold_strength=0.76,
            ),
        )
    # Carrion Bell's crown plate sits directly above the resonator and is the
    # family's strongest readable signal shape. Replace its broad shared
    # sheet with a thicker folded lobe while keeping the crown socket and
    # animation channel stable.
    if name == "carrionbell":
        mesh_ids["CarrionbellCrownLobe"] = mesh(
            "CarrionbellCrownLobe",
            add_organic_lobe(
                builder,
                (1.58, 0.34, 0.62),
                shell,
                lobes=5,
                rings=10,
                sides=40,
                scallop_amplitude=0.15,
                leading_extension=0.38,
                fold_strength=0.90,
            ),
        )
        # The Carrion Bell's signal organ needs a readable mouth and depth
        # cue, not only a thin torus around a glowing core. Keep the detail
        # parented to the existing resonator socket so its authored attack and
        # pulse animation remain the sole motion owner.
        mesh_ids["CarrionbellResonatorBellLip"] = mesh(
            "CarrionbellResonatorBellLip",
            add_organic_lobe(
                builder,
                (0.78, 0.22, 0.46),
                bone,
                lobes=6,
                rings=10,
                sides=48,
                scallop_amplitude=0.12,
                leading_extension=0.22,
                fold_strength=0.72,
            ),
        )
        mesh_ids["CarrionbellResonatorClapper"] = mesh(
            "CarrionbellResonatorClapper",
            add_capsule(builder, 0.055, 0.42, bone, 24),
        )
    # Rootweaver's paired crown plates frame the route-controller oculi. Give
    # those existing sockets a closed folded shell so they read as living
    # crown petals rather than two broad horizontal service plates.
    if name == "rootweaver":
        mesh_ids["RootweaverCrownLobe"] = mesh(
            "RootweaverCrownLobe",
            add_organic_lobe(
                builder,
                (0.92, 0.30, 0.58),
                shell,
                lobes=4,
                rings=9,
                sides=40,
                scallop_amplitude=0.16,
                leading_extension=0.32,
                fold_strength=0.9,
            ),
        )
        # The route-controller head needs a lower facial frame beneath the
        # paired oculi. These folded jaw plates turn the front of the broad
        # torso into a readable living face instead of leaving the crown to
        # float above an unbroken shell.
        mesh_ids["RootweaverJawLobe"] = mesh(
            "RootweaverJawLobe",
            add_organic_lobe(
                builder,
                (0.68, 0.22, 0.42),
                bone,
                lobes=5,
                rings=10,
                sides=48,
                scallop_amplitude=0.12,
                leading_extension=0.22,
                fold_strength=0.78,
            ),
        )

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
    core_scale, segment_scale, segment_taper = spec["body_profile"]
    add_node("TorsoCore", mesh_ids["Core"], (0.0, 0.92, 0.08), scale=core_scale, parent=torso, extras={"release_material_family": "chitin"})
    for index in range(4):
        z = -0.62 + index * 0.43
        segment_width = max(0.72, float(segment_scale[0]) - index * segment_taper)
        segment_depth = max(0.78, float(segment_scale[2]) - index * segment_taper * 0.8)
        add_node(f"TorsoSegment{index}", mesh_ids["Segment"], (0.0, 0.89 - index * 0.024, z), scale=(segment_width, segment_scale[1], segment_depth), parent=torso)
        add_node(f"{name.capitalize()}ThoraxRib", mesh_ids["ShellPlate"], (0.0, 1.35 - index * 0.045, z), rotation=(0.0, 0.0, 0.03 * (index - 1)), scale=(1.0, 1.0, 0.84), parent=torso, extras={"surface": "layered_shell_break"} if index == 1 else None)
        add_node("ThoraxFastener", mesh_ids["Fastener"], (-0.56, 1.18, z), parent=torso)
        add_node("ThoraxFastener", mesh_ids["Fastener"], (0.56, 1.18, z), parent=torso)
        # Paired surface veins break up the shared torso kit at close camera
        # distance. They are deliberately thin and recessed into the front
        # face, adding living vascular rhythm without becoming gameplay
        # sockets, collision geometry, or a new runtime dependency.
        for side in (-1.0, 1.0):
            suffix = "L" if side < 0.0 else "R"
            add_node(f"{name.capitalize()}TorsoSurfaceVein{index}{suffix}", mesh_ids["SurfaceVein"], (side * 0.31, 1.19, z - 0.54), rotation=(0.0, 0.0, side * 0.08), scale=(1.0, 1.0, 0.72), parent=torso, extras={"surface": "vascular_surface_detail"})
    dorsal = add_node("OrganicDorsalPlate", mesh_ids["ShellPlate"], (-0.12, 1.54, 0.18), rotation=(0.0, 0.0, -0.04), scale=(1.08, 1.0, 1.4), extras={"surface": "beveled_layered_shell_break"})

    if name == "roofleaper":
        crown_node = add_node("RoofleaperCrown", mesh_ids["Soft"], (0.0, 1.3, -1.02), scale=(1.15, 0.82, 1.05), extras={"socket_type": "crown"})
        add_node("RoofleaperCrownKeel", mesh_ids["RoofleaperCrownKeel"], (0.0, -0.26, -0.40), scale=(0.94, 1.08, 0.96), extras={"surface": "crown_sternum"}, parent=crown_node)
        for index, side in enumerate((-1.0, 1.0)):
            add_node(f"RoofleaperCrownRidge{index}", mesh_ids["Ridge"], (side * 0.22, 1.58, -1.06), rotation=(0.0, side * 0.16, side * 0.14), scale=(0.42, 1.0, 0.72), extras={"surface": "crown_ridge"})
        for side in (-1.0, 1.0):
            suffix = "L" if side < 0 else "R"
            wing_pitch = 0.16
            wing_node = add_node(f"RoofleaperWing{suffix}", mesh_ids["WingMembrane"], (side * 0.92, 1.18, 0.05), rotation=(side * wing_pitch, side * 0.18, side * 0.1), scale=(1.15, 1.0, 1.1), extras={"socket_type": "wing_membrane"})
            add_node(f"RoofleaperWingFrame{suffix}", mesh_ids["WingFrame"], (side * 1.18, 1.2, 0.05), rotation=(side * (wing_pitch + 0.04), side * 0.35, side * 0.72), scale=(0.72, 1.0, 1.0), extras={"surface": "wing_spar"})
            add_node(f"RoofleaperWingVein{suffix}", mesh_ids["Bone"], (side * 1.12, 1.2, 0.05), rotation=(side * (wing_pitch + 0.04), side * 0.35, side * 0.72), scale=(0.6, 1.0, 1.0))
            add_node(f"RoofleaperFineVein{suffix}", mesh_ids["FineVein"], (side * 0.92, 1.2, 0.04), rotation=(side * (wing_pitch + 0.02), side * 0.32, side * 0.28), scale=(0.72, 1.0, 0.88), extras={"surface": "membrane_vascular_detail"})
            add_node(f"RoofleaperWingFastener{suffix}", mesh_ids["CrownFastener"], (side * 0.58, 1.28, -0.02), extras={"surface": "wing_socket"})
            add_node(f"RoofleaperTalons{suffix}", mesh_ids["LongBone"], (side * 0.54, 0.3, -0.72), rotation=(side * 0.76, 0.0, side * 0.18), extras={"socket_type": "talon"})
            add_node(f"RoofleaperEye{suffix}", mesh_ids["Eye"], (side * 0.22, 1.5, -1.45), extras={"socket_type": "threat_eye"})
            add_node(
                f"RoofleaperWingRootCollar{suffix}",
                mesh_ids["RoofleaperWingRootCollar"],
                (-side * 0.30, 0.04, -0.03),
                rotation=(0.0, -side * 0.10, side * 0.08),
                scale=(0.92, 0.86, 0.82),
                extras={"surface": "folded_wing_root"},
                parent=wing_node,
            )
        walk_node = "RoofleaperTalonsL"
        attack_node = "RoofleaperWingL"
    elif name == "glassmoth":
        add_node("GlassmothThorax", mesh_ids["Soft"], (0.0, 1.12, 0.18), scale=(0.92, 1.42, 0.88), extras={"socket_type": "thorax"})
        for side in (-1.0, 1.0):
            suffix = "L" if side < 0 else "R"
            for level in range(2):
                wing_pitch = 0.36 + level * 0.10
                wing_node = add_node(f"GlassmothWing{suffix}{level}", mesh_ids["WingMembrane"], (side * (0.88 + level * 0.16), 1.18 + level * 0.22, 0.12 + level * 0.28), rotation=(side * wing_pitch, side * (0.28 + level * 0.10), side * 0.24), scale=(1.3 - level * 0.12, 0.82, 0.76), extras={"socket_type": "wing_pair"})
                # Three fine radial veins give each broad membrane a living
                # root-to-edge rhythm. Parenting them to the existing wing
                # node keeps the imported animation hierarchy authoritative.
                for vein_index in range(3):
                    add_node(
                        f"GlassmothWingVein{suffix}{level}{chr(65 + vein_index)}",
                        mesh_ids["GlassmothWingVein"],
                        (side * (0.10 + level * 0.03), 0.14, -0.25 + vein_index * 0.25),
                        rotation=(math.pi * 0.5, side * (0.12 + level * 0.04), side * 0.06),
                        scale=(1.0, 0.92, 1.0),
                        extras={"surface": "luminous_wing_vascular_detail"},
                        parent=wing_node,
                    )
                add_node(f"GlassmothWingFrame{suffix}{level}", mesh_ids["WingFrame"], (side * (1.10 + level * 0.16), 1.22 + level * 0.16, 0.12 + level * 0.18), rotation=(side * (wing_pitch + 0.04), side * (0.28 + level * 0.08), side * 0.64), scale=(0.62, 1.0, 0.82), extras={"surface": "glasswing_spar"})
                add_node(f"GlassmothWingFastener{suffix}{level}", mesh_ids["CrownFastener"], (side * (0.58 + level * 0.12), 1.22 + level * 0.14, 0.08 + level * 0.16), extras={"surface": "wing_socket"})
                add_node(f"GlassmothFineVein{suffix}{level}", mesh_ids["FineVein"], (side * (0.9 + level * 0.15), 1.2 + level * 0.15, 0.14 + level * 0.17), rotation=(side * (wing_pitch + 0.02), side * (0.26 + level * 0.06), side * 0.24), scale=(0.65, 1.0, 0.76), extras={"surface": "luminous_wing_vein"})
                if level == 0:
                    add_node(
                        f"GlassmothWingRootCollar{suffix}",
                        mesh_ids["GlassmothWingRootCollar"],
                        (-side * 0.34, 0.02, -0.02),
                        rotation=(0.0, -side * 0.10, side * 0.08),
                        scale=(0.92, 0.86, 0.82),
                        extras={"surface": "folded_wing_root"},
                        parent=wing_node,
                    )
            add_node(f"GlassmothAntenna{suffix}", mesh_ids["Tendon"], (side * 0.2, 1.45, -0.98), rotation=(0.48, 0.0, side * 0.22), extras={"socket_type": "antenna"})
            add_node(f"GlassmothOculus{suffix}", mesh_ids["Eye"], (side * 0.2, 1.3, -1.12), extras={"socket_type": "luminous_eye"})
        walk_node = "GlassmothWingL0"
        attack_node = "GlassmothWingR1"
    elif name == "miremaw":
        add_node("MiremawHead", mesh_ids["Soft"], (0.0, 0.78, -1.18), scale=(1.3, 0.8, 1.2), extras={"socket_type": "maw"})
        add_node("MiremawJawLower", mesh_ids["MiremawJawLobe"], (0.0, 0.56, -1.50), rotation=(0.18, 0.0, 0.0), scale=(1.12, 0.86, 0.74), extras={"surface": "lower_jaw_shell"})
        add_node("MiremawHeadRidge0", mesh_ids["Ridge"], (-0.42, 1.15, -1.5), rotation=(0.0, -0.2, -0.12), scale=(0.62, 1.0, 0.72), extras={"surface": "head_ridge"})
        add_node("MiremawHeadRidge1", mesh_ids["Ridge"], (0.42, 1.15, -1.5), rotation=(0.0, 0.2, 0.12), scale=(0.62, 1.0, 0.72), extras={"surface": "head_ridge"})
        add_node("MiremawGillFan", mesh_ids["DeepMembrane"], (0.0, 1.25, 0.35), rotation=(0.0, 0.0, 1.5708), scale=(0.72, 1.0, 0.78), extras={"socket_type": "gill_fan"})
        add_node("MiremawGillCollarL", mesh_ids["MiremawGillCollar"], (-0.46, 1.18, 0.48), rotation=(0.18, -0.28, -0.18), scale=(0.78, 1.0, 0.92), extras={"surface": "folded_gill_collar"})
        add_node("MiremawGillCollarR", mesh_ids["MiremawGillCollar"], (0.46, 1.18, 0.48), rotation=(-0.18, 0.28, 0.18), scale=(0.78, 1.0, 0.92), extras={"surface": "folded_gill_collar"})
        for side in (-1.0, 1.0):
            suffix = "L" if side < 0 else "R"
            add_node(f"MiremawJawHook{suffix}", mesh_ids["LongBone"], (side * 0.42, 0.55, -1.62), rotation=(side * 0.72, 0.0, side * 0.18), extras={"socket_type": "jaw_hook"})
            add_node(f"MiremawJawPlate{suffix}", mesh_ids["MiremawJawLobe"], (side * 0.44, 0.68, -1.42), rotation=(side * 0.36, 0.0, side * 0.12), scale=(0.82, 1.0, 0.76), extras={"surface": "jaw_plate"})
            add_node(f"MiremawJawHinge{suffix}", mesh_ids["CrownFastener"], (side * 0.53, 0.76, -1.52), scale=(1.35, 1.15, 1.10), extras={"surface": "jaw_hinge"})
            fin_pitch = 0.20
            add_node(f"MiremawWaterFin{suffix}", mesh_ids["DeepMembrane"], (side * 1.08, 0.68, 0.18), rotation=(side * fin_pitch, side * 0.28, side * 0.08), scale=(0.62, 0.84, 1.1), extras={"socket_type": "water_fin"})
            add_node(f"MiremawGillSpine{suffix}", mesh_ids["GillSpine"], (side * 0.62, 1.30, 0.38), rotation=(0.0, side * 0.28, side * 0.22), scale=(0.78, 1.0, 0.82), extras={"surface": "gill_spine"})
            add_node(f"MiremawFinRay{suffix}", mesh_ids["MembraneRib"], (side * 1.18, 0.72, 0.18), rotation=(side * (fin_pitch + 0.04), side * 0.3, side * 0.28), scale=(0.62, 1.0, 0.9), extras={"surface": "water_fin_ray"})
            add_node(f"MiremawGillRidge{suffix}", mesh_ids["Ridge"], (side * 0.48, 1.28, 0.38), rotation=(0.0, side * 0.22, side * 0.08), scale=(0.72, 1.0, 0.62), extras={"surface": "gill_ridge"})
            add_node(f"MiremawEye{suffix}", mesh_ids["Eye"], (side * 0.26, 1.24, -1.62), extras={"socket_type": "threat_eye"})
        walk_node = "MiremawWaterFinL"
        attack_node = "MiremawJawHookL"
    elif name == "carrionbell":
        add_node("CarrionbellMantle", mesh_ids["Soft"], (0.0, 1.18, 0.12), scale=(1.25, 1.55, 1.2), extras={"socket_type": "bell_mantle"})
        add_node("CarrionbellMantleSeamL", mesh_ids["Ridge"], (-0.72, 1.25, 0.06), rotation=(0.0, -0.24, -0.08), scale=(0.68, 1.0, 0.88), extras={"surface": "mantle_seam"})
        add_node("CarrionbellMantleSeamR", mesh_ids["Ridge"], (0.72, 1.25, 0.06), rotation=(0.0, 0.24, 0.08), scale=(0.68, 1.0, 0.88), extras={"surface": "mantle_seam"})
        resonator = add_node("CarrionbellResonator", mesh_ids["Eye"], (0.0, 1.92, -0.35), scale=(1.4, 0.8, 1.0), extras={"socket_type": "resonator"})
        add_node("CarrionbellResonatorCore", mesh_ids["Eye"], (0.0, 1.92, -0.44), scale=(0.62, 0.62, 0.72), extras={"surface": "resonator_core"})
        add_node("CarrionbellResonatorRing", mesh_ids["ResonatorRing"], (0.0, 1.92, -0.35), rotation=(1.5708, 0.0, 0.0), scale=(1.8, 1.0, 1.35), extras={"surface": "resonator_lip"})
        add_node("CarrionbellResonatorBellLip", mesh_ids["CarrionbellResonatorBellLip"], (0.0, -0.04, 0.08), rotation=(0.24, 0.0, 0.0), scale=(1.28, 0.92, 1.12), extras={"surface": "resonator_bell_lip"}, parent=resonator)
        add_node("CarrionbellResonatorClapper", mesh_ids["CarrionbellResonatorClapper"], (0.0, -0.24, 0.13), rotation=(0.16, 0.0, 0.0), scale=(0.76, 0.92, 0.76), extras={"surface": "resonator_clapper"}, parent=resonator)
        add_node("CarrionbellResonatorClapperTip", mesh_ids["CrownFastener"], (0.0, -0.46, 0.13), scale=(1.18, 1.18, 1.18), extras={"surface": "resonator_clapper_tip"}, parent=resonator)
        # The resonant crown is a raised bell lip, not a horizontal cap. A
        # small forward pitch exposes its folded depth to the key light while
        # keeping the stable crown socket and animation target unchanged.
        add_node("CarrionbellCrownPlate", mesh_ids["CarrionbellCrownLobe"], (0.0, 2.32, 0.18), rotation=(0.18, 0.0, 0.12), scale=(1.3, 1.0, 0.92), extras={"socket_type": "crown_plate"})
        for index in range(4):
            side = -1.0 if index < 2 else 1.0
            add_node(f"CarrionbellBellRib{index}", mesh_ids["BellRib"], (side * (0.42 + (index % 2) * 0.2), 1.62, -0.24 + (index % 2) * 0.18), rotation=(0.0, side * 0.32, side * 0.52), scale=(0.7, 1.0, 0.82), extras={"surface": "bell_rib"})
        for index in range(5):
            x = -0.64 + index * 0.32
            add_node(f"CarrionbellSignalTendril{index}", mesh_ids["Tendon"], (x, 0.68, -0.72 - (index % 2) * 0.12), rotation=(0.32, 0.0, (index - 2) * 0.12), extras={"socket_type": "signal_tendril"})
        walk_node = "CarrionbellMantle"
        attack_node = "CarrionbellResonator"
    elif name == "rootweaver":
        add_node("RootweaverCrown", mesh_ids["Soft"], (0.0, 1.55, -0.42), scale=(1.28, 1.2, 1.18), extras={"socket_type": "crown_oculi"})
        add_node("RootweaverCrownPlate0", mesh_ids["RootweaverCrownLobe"], (-0.36, 1.92, -0.44), rotation=(0.0, -0.22, -0.08), scale=(0.72, 1.0, 0.84), extras={"surface": "crown_plate"})
        add_node("RootweaverCrownPlate1", mesh_ids["RootweaverCrownLobe"], (0.36, 1.92, -0.44), rotation=(0.0, 0.22, 0.08), scale=(0.72, 1.0, 0.84), extras={"surface": "crown_plate"})
        for side in (-1.0, 1.0):
            suffix = "L" if side < 0.0 else "R"
            add_node(f"RootweaverJawPlate{suffix}", mesh_ids["RootweaverJawLobe"], (side * 0.34, 1.57, -0.82), rotation=(0.0, side * 0.2, side * 0.12), scale=(0.84, 0.92, 0.96), extras={"surface": "jaw_plate"})
        fan_pitch = 0.24
        add_node("RootweaverSporeFan", mesh_ids["DeepMembrane"], (0.0, 1.76, 0.24), rotation=(fan_pitch, 0.0, 1.5708), scale=(1.0, 1.0, 1.24), extras={"socket_type": "spore_fan"})
        add_node("RootweaverSporeRib0", mesh_ids["MembraneRib"], (-0.38, 1.76, 0.24), rotation=(fan_pitch, -0.18, -0.46), scale=(0.78, 1.0, 0.84), extras={"surface": "spore_fan_rib"})
        add_node("RootweaverSporeRib1", mesh_ids["MembraneRib"], (0.38, 1.76, 0.24), rotation=(fan_pitch, 0.18, 0.46), scale=(0.78, 1.0, 0.84), extras={"surface": "spore_fan_rib"})
        for side in (-1.0, 1.0):
            suffix = "L" if side < 0 else "R"
            add_node(f"RootweaverArm{suffix}", mesh_ids["LongBone"], (side * 0.82, 0.95, -0.2), rotation=(0.0, side * 0.2, side * 0.8), scale=(1.0, 1.0, 1.28), extras={"socket_type": "root_arm"})
            add_node(f"RootweaverKnuckle{suffix}", mesh_ids["RootKnuckle"], (side * 1.18, 0.62, -0.42), scale=(1.25, 0.82, 1.0), extras={"surface": "root_joint_detail"})
            add_node(f"RootweaverKnuckleCap{suffix}", mesh_ids["CrownFastener"], (side * 1.20, 0.72, -0.48), scale=(1.3, 1.0, 1.1), extras={"surface": "root_joint_cap"})
            add_node(f"RootweaverRouteSpine{suffix}", mesh_ids["Bone"], (side * 0.86, 1.34, 0.4), rotation=(0.0, side * 0.22, side * 0.28), extras={"socket_type": "route_spine"})
            add_node(f"RootweaverRootSpine{suffix}", mesh_ids["RootSpine"], (side * 0.92, 1.14, 0.22), rotation=(0.0, side * 0.28, side * 0.4), scale=(0.86, 1.0, 0.82), extras={"surface": "root_spine"})
            add_node(f"RootweaverOculus{suffix}", mesh_ids["Eye"], (side * 0.26, 1.92, -0.82), extras={"socket_type": "crown_oculus"})
        walk_node = "RootweaverArmL"
        attack_node = "RootweaverSporeFan"
    elif name == "thornback":
        add_node("ThornbackCrown", mesh_ids["Soft"], (0.0, 1.22, -1.02), scale=(1.28, 0.86, 1.16), extras={"socket_type": "thorn_crown"})
        # Thornback's territorial shield rises toward an approaching threat;
        # pitching the folded crown keeps its layered face legible instead of
        # turning it into a broad horizontal plate.
        add_node("ThornbackCrownPlate", mesh_ids["ThornbackCrownLobe"], (0.0, 1.58, -0.96), rotation=(0.16, 0.0, 0.08), scale=(1.16, 1.0, 0.8), extras={"surface": "crown_lobe"})
        for side in (-1.0, 1.0):
            suffix = "L" if side < 0 else "R"
            jaw_plate = add_node(f"ThornbackJawPlate{suffix}", mesh_ids["PlateCap"], (side * 0.42, 0.94, -1.20), rotation=(side * 0.38, 0.0, side * 0.12), scale=(0.82, 1.0, 0.74), extras={"surface": "jaw_plate"})
            # Keep the rounded tooth bases intersecting the lower jaw edge;
            # the points may hang below the plate, but the assembly must never
            # read as detached hardware in the close gallery frame.
            for tooth_index, tooth_position in enumerate(((-0.13, -0.07, -0.04), (0.13, -0.07, -0.14))):
                add_node(f"ThornbackJawTooth{suffix}{tooth_index}", mesh_ids["ThornbackJawTooth"], tooth_position, scale=(0.82, 1.0, 0.82), extras={"surface": "jaw_tooth"}, parent=jaw_plate)
            add_node(f"ThornbackSpine{suffix}", mesh_ids["LongBone"], (side * 0.76, 1.42, 0.14), rotation=(0.0, side * 0.24, side * 0.34), scale=(0.82, 1.0, 0.86), extras={"socket_type": "dorsal_spine"})
            add_node(f"ThornbackEye{suffix}", mesh_ids["Eye"], (side * 0.24, 1.34, -1.36), extras={"socket_type": "threat_eye"})
        for index in range(3):
            add_node(f"ThornbackDorsalRidge{index}", mesh_ids["Ridge"], (-0.18 + index * 0.18, 1.56 + index * 0.06, -0.24 + index * 0.42), rotation=(0.0, 0.0, -0.12 + index * 0.08), scale=(0.66, 1.0, 0.78), extras={"surface": "dorsal_ridge"})
        barb_positions = ((-0.48, 1.74, -0.18), (0.0, 1.86, 0.24), (0.48, 1.76, 0.66))
        for index, (x, y, z) in enumerate(barb_positions):
            side = -1.0 if index == 0 else (1.0 if index == 2 else 0.0)
            add_node(f"ThornbackBarb{index}", mesh_ids["ThornbackBarb"], (x, y, z), rotation=(0.22, side * 0.24, side * 0.12), scale=(0.9, 1.0 + 0.08 * (index == 1), 0.9), extras={"surface": "dorsal_barb"})
        walk_node = "ThornbackSpineL"
        attack_node = "ThornbackJawPlateL"
    else:
        add_node("AshmantleMantle", mesh_ids["Soft"], (0.0, 1.28, 0.18), scale=(1.5, 0.92, 1.34), extras={"socket_type": "heat_mantle"})
        add_node("AshmantleSiphon", mesh_ids["Soft"], (0.0, 0.82, -1.42), scale=(0.72, 0.64, 1.14), extras={"socket_type": "route_siphon"})
        add_node("AshmantleSiphonRing", mesh_ids["ResonatorRing"], (0.0, 0.82, -1.60), rotation=(1.5708, 0.0, 0.0), scale=(1.34, 1.0, 1.08), extras={"surface": "heated_siphon_collar"})
        for side in (-1.0, 1.0):
            suffix = "L" if side < 0.0 else "R"
            add_node(f"AshmantleSiphonAperture{suffix}", mesh_ids["Eye"], (side * 0.18, 0.84, -1.72), scale=(0.72, 0.72, 0.54), extras={"surface": "heated_siphon_aperture"})
        for side in (-1.0, 1.0):
            suffix = "L" if side < 0 else "R"
            # Pitch the paired thermal petals into a vented mantle profile so
            # Ashmantle reads as a living route predator rather than a stack
            # of flat fins in the close tactical camera.
            add_node(f"AshmantleHeatLouver{suffix}", mesh_ids["AshmantleHeatLouver"], (side * 0.82, 1.20, 0.28), rotation=(side * 0.20, side * 0.28, side * 0.12), scale=(0.72, 1.0, 1.12), extras={"surface": "heat_louver"})
            add_node(f"AshmantleLouverRib{suffix}", mesh_ids["MembraneRib"], (side * 1.04, 1.24, 0.30), rotation=(side * 0.12, side * 0.34, side * 0.22), scale=(0.7, 1.0, 0.86), extras={"surface": "louver_rib"})
            add_node(f"AshmantleTendril{suffix}", mesh_ids["Tendon"], (side * 0.28, 1.18, -1.58), rotation=(0.5, 0.0, side * 0.2), extras={"socket_type": "sensory_tendril"})
            add_node(f"AshmantleEye{suffix}", mesh_ids["Eye"], (side * 0.22, 1.34, -1.62), extras={"socket_type": "threat_eye"})
        for index in range(4):
            add_node(f"AshmantleMantleRib{index}", mesh_ids["AshmantleMantleRib"], (-0.54 + index * 0.36, 1.66, 0.18), rotation=(0.0, (index - 1.5) * 0.08, 0.0), scale=(0.72, 1.0, 0.64), extras={"surface": "mantle_rib"})
        walk_node = "AshmantleHeatLouverL"
        attack_node = "AshmantleSiphon"

    add_node("ProductionAssetMarker", None, extras={"asset_contract": spec["asset_id"], "source": "original_shared_mesh_builder"})
    node_index = {node["name"]: index for index, node in enumerate(nodes)}

    def animation(animation_name: str, channels: list[tuple[str, str, list[float], list[float]]]) -> dict:
        samplers: list[dict] = []
        entries: list[dict] = []
        types = {"translation": ("VEC3", 3), "rotation": ("VEC4", 4)}
        for target_name, path, times, values in channels:
            type_name, width = types[path]
            time_accessor = builder.accessor(times, 5126, "SCALAR", len(times), minimum=[min(times)], maximum=[max(times)])
            output_accessor = builder.accessor(values, 5126, type_name, len(values) // width)
            sampler_index = len(samplers)
            samplers.append({"input": time_accessor, "output": output_accessor, "interpolation": "LINEAR"})
            entries.append({"sampler": sampler_index, "target": {"node": node_index[target_name], "path": path}})
        return {"name": animation_name, "samplers": samplers, "channels": entries}

    idle_channels = [
            (root_name, "translation", [0.0, 0.8, 1.6], [0.0, 0.0, 0.0, 0.0, 0.014, 0.0, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.8, 1.6], quat((0.012, 0.0, 0.0)) + quat((-0.012, 0.0, 0.0)) + quat((0.012, 0.0, 0.0))),
        ]
    walk_channels = [
            (walk_node, "rotation", [0.0, 0.22, 0.44], quat((0.2, 0.0, 0.0)) + quat((-0.2, 0.0, 0.0)) + quat((0.2, 0.0, 0.0))),
            ("Torso", "rotation", [0.0, 0.22, 0.44], quat((0.04, 0.0, 0.0)) + quat((-0.04, 0.0, 0.0)) + quat((0.04, 0.0, 0.0))),
        ]
    attack_channels = [
            (attack_node, "translation", [0.0, 0.24, 0.48], [0.0, 0.0, 0.0, 0.0, 0.0, -0.16, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.24, 0.48], quat((0.05, 0.0, 0.0)) + quat((-0.09, 0.0, 0.0)) + quat((0.05, 0.0, 0.0))),
        ]
    hit_channels = [
            (root_name, "translation", [0.0, 0.10, 0.24], [0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((-0.16, 0.08, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]
    feed_channels = [
            (root_name, "translation", [0.0, 0.3, 0.6], [0.0, 0.0, 0.0, 0.0, -0.12, -0.08, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.3, 0.6], quat((0.02, 0.0, 0.0)) + quat((0.16, 0.0, 0.0)) + quat((0.02, 0.0, 0.0))),
        ]
    nest_channels = [
            (root_name, "translation", [0.0, 0.5, 1.0], [0.0, 0.0, 0.0, 0.0, 0.08, 0.0, 0.0, 0.0, 0.0]),
            ("Torso", "rotation", [0.0, 0.5, 1.0], quat((0.025, 0.0, 0.0)) + quat((-0.025, 0.0, 0.0)) + quat((0.025, 0.0, 0.0))),
        ]
    retreat_channels = [
            (walk_node, "rotation", [0.0, 0.22, 0.44], quat((0.28, 0.0, 0.0)) + quat((-0.16, 0.0, 0.0)) + quat((0.28, 0.0, 0.0))),
            ("Torso", "rotation", [0.0, 0.22, 0.44], quat((0.12, 0.0, 0.0)) + quat((0.22, 0.0, 0.0)) + quat((0.12, 0.0, 0.0))),
        ]
    death_channels = [
            (root_name, "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.34, 0.08, 0.2)) + quat((0.78, 0.16, 0.42))),
            ("Torso", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.18, 0.0, 0.0)) + quat((0.46, 0.0, 0.0))),
        ]

    if name == "roofleaper":
        # Roofleaper's identity is carried by paired membrane wings, spars,
        # vascular veins and the crown/talon ambush profile. Give those
        # authored surfaces their own restrained channels so the vertical
        # ambusher does not collapse into a torso-only beat at review distance.
        idle_channels.extend([
            ("RoofleaperWingL", "rotation", [0.0, 0.8, 1.6], quat((-0.16, -0.18, -0.1)) + quat((0.08, -0.24, -0.16)) + quat((-0.16, -0.18, -0.1))),
            ("RoofleaperWingR", "rotation", [0.0, 0.8, 1.6], quat((0.16, 0.18, 0.1)) + quat((-0.08, 0.24, 0.16)) + quat((0.16, 0.18, 0.1))),
            ("RoofleaperFineVeinL", "rotation", [0.0, 0.8, 1.6], quat((-0.18, -0.32, -0.28)) + quat((0.04, -0.38, -0.34)) + quat((-0.18, -0.32, -0.28))),
            ("RoofleaperFineVeinR", "rotation", [0.0, 0.8, 1.6], quat((0.18, 0.32, 0.28)) + quat((-0.04, 0.38, 0.34)) + quat((0.18, 0.32, 0.28))),
        ])
        walk_channels.extend([
            ("RoofleaperWingL", "rotation", [0.0, 0.22, 0.44], quat((-0.16, -0.18, -0.1)) + quat((0.18, -0.32, -0.24)) + quat((-0.16, -0.18, -0.1))),
            ("RoofleaperWingR", "rotation", [0.0, 0.22, 0.44], quat((0.16, 0.18, 0.1)) + quat((-0.18, 0.32, 0.24)) + quat((0.16, 0.18, 0.1))),
            ("RoofleaperWingFrameL", "rotation", [0.0, 0.22, 0.44], quat((-0.20, -0.35, -0.72)) + quat((0.16, -0.44, -0.84)) + quat((-0.20, -0.35, -0.72))),
            ("RoofleaperWingFrameR", "rotation", [0.0, 0.22, 0.44], quat((0.20, 0.35, 0.72)) + quat((-0.16, 0.44, 0.84)) + quat((0.20, 0.35, 0.72))),
        ])
        attack_channels.extend([
            ("RoofleaperWingL", "rotation", [0.0, 0.24, 0.48], quat((-0.16, -0.18, -0.1)) + quat((-0.22, -0.46, -0.34)) + quat((-0.16, -0.18, -0.1))),
            ("RoofleaperWingR", "rotation", [0.0, 0.24, 0.48], quat((0.16, 0.18, 0.1)) + quat((0.22, 0.46, 0.34)) + quat((0.16, 0.18, 0.1))),
            ("RoofleaperWingFrameL", "rotation", [0.0, 0.24, 0.48], quat((-0.20, -0.35, -0.72)) + quat((-0.28, -0.56, -0.94)) + quat((-0.20, -0.35, -0.72))),
            ("RoofleaperWingFrameR", "rotation", [0.0, 0.24, 0.48], quat((0.20, 0.35, 0.72)) + quat((0.28, 0.56, 0.94)) + quat((0.20, 0.35, 0.72))),
            ("RoofleaperCrownRidge0", "rotation", [0.0, 0.24, 0.48], quat((0.0, -0.16, -0.14)) + quat((0.18, -0.24, -0.22)) + quat((0.0, -0.16, -0.14))),
            ("RoofleaperCrownRidge1", "rotation", [0.0, 0.24, 0.48], quat((0.0, 0.16, 0.14)) + quat((0.18, 0.24, 0.22)) + quat((0.0, 0.16, 0.14))),
        ])
        hit_channels.extend([
            ("RoofleaperWingL", "rotation", [0.0, 0.10, 0.24], quat((-0.16, -0.18, -0.1)) + quat((0.0, 0.18, 0.2)) + quat((-0.16, -0.18, -0.1))),
            ("RoofleaperWingR", "rotation", [0.0, 0.10, 0.24], quat((0.16, 0.18, 0.1)) + quat((0.0, -0.18, -0.2)) + quat((0.16, 0.18, 0.1))),
            ("RoofleaperCrown", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((-0.16, 0.08, 0.0)) + quat((0.0, 0.0, 0.0))),
        ])
        feed_channels.extend([
            ("RoofleaperCrown", "rotation", [0.0, 0.3, 0.6], quat((0.0, 0.0, 0.0)) + quat((0.16, 0.0, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("RoofleaperFineVeinL", "rotation", [0.0, 0.3, 0.6], quat((-0.18, -0.32, -0.28)) + quat((0.0, -0.22, -0.2)) + quat((-0.18, -0.32, -0.28))),
            ("RoofleaperFineVeinR", "rotation", [0.0, 0.3, 0.6], quat((0.18, 0.32, 0.28)) + quat((0.0, 0.22, 0.2)) + quat((0.18, 0.32, 0.28))),
        ])
        nest_channels.extend([
            ("RoofleaperWingFrameL", "rotation", [0.0, 0.5, 1.0], quat((-0.20, -0.35, -0.72)) + quat((0.0, -0.24, -0.58)) + quat((-0.20, -0.35, -0.72))),
            ("RoofleaperWingFrameR", "rotation", [0.0, 0.5, 1.0], quat((0.20, 0.35, 0.72)) + quat((0.0, 0.24, 0.58)) + quat((0.20, 0.35, 0.72))),
            ("RoofleaperCrownRidge0", "rotation", [0.0, 0.5, 1.0], quat((0.0, -0.16, -0.14)) + quat((0.0, -0.08, -0.08)) + quat((0.0, -0.16, -0.14))),
        ])
        retreat_channels.extend([
            ("RoofleaperWingL", "rotation", [0.0, 0.22, 0.44], quat((-0.16, -0.18, -0.1)) + quat((0.28, -0.42, -0.3)) + quat((-0.16, -0.18, -0.1))),
            ("RoofleaperWingR", "rotation", [0.0, 0.22, 0.44], quat((0.16, 0.18, 0.1)) + quat((-0.28, 0.42, 0.3)) + quat((0.16, 0.18, 0.1))),
            ("RoofleaperTalonsL", "rotation", [0.0, 0.22, 0.44], quat((-0.76, 0.0, -0.18)) + quat((-0.58, 0.0, -0.1)) + quat((-0.76, 0.0, -0.18))),
        ])
        death_channels.extend([
            ("RoofleaperCrown", "rotation", [0.0, 0.28, 0.64], quat((0.0, 0.0, 0.0)) + quat((0.34, 0.08, 0.2)) + quat((0.78, 0.16, 0.42))),
            ("RoofleaperWingFrameL", "rotation", [0.0, 0.28, 0.64], quat((-0.20, -0.35, -0.72)) + quat((0.22, -0.16, -0.38)) + quat((0.54, 0.0, 0.0))),
        ])
    elif name == "rootweaver":
        # The route-controller silhouette is carried by the spore fan and the
        # paired root arms. Keep the motion small enough for reduced-detail
        # transitions while giving the close release camera living secondary
        # anatomy to read between the broad torso beats.
        idle_channels.extend([
            ("RootweaverSporeFan", "rotation", [0.0, 0.8, 1.6], quat((0.24, 0.0, 1.48)) + quat((0.30, 0.0, 1.66)) + quat((0.24, 0.0, 1.48))),
            ("RootweaverSporeRib0", "rotation", [0.0, 0.8, 1.6], quat((0.24, -0.18, -0.46)) + quat((0.28, -0.18, -0.42)) + quat((0.24, -0.18, -0.46))),
            ("RootweaverSporeRib1", "rotation", [0.0, 0.8, 1.6], quat((0.24, 0.18, 0.46)) + quat((0.20, 0.18, 0.42)) + quat((0.24, 0.18, 0.46))),
        ])
        walk_channels.extend([
            ("RootweaverArmL", "rotation", [0.0, 0.22, 0.44], quat((0.0, -0.2, -0.8)) + quat((0.14, -0.24, -0.72)) + quat((0.0, -0.2, -0.8))),
            ("RootweaverArmR", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.2, 0.8)) + quat((-0.14, 0.24, 0.72)) + quat((0.0, 0.2, 0.8))),
        ])
        attack_channels.extend([
            ("RootweaverSporeFan", "rotation", [0.0, 0.24, 0.48], quat((0.24, 0.0, 1.57)) + quat((0.12, 0.0, 1.22)) + quat((0.24, 0.0, 1.57))),
            ("RootweaverSporeRib0", "rotation", [0.0, 0.24, 0.48], quat((0.24, -0.18, -0.46)) + quat((0.18, -0.2, -0.34)) + quat((0.24, -0.18, -0.46))),
            ("RootweaverSporeRib1", "rotation", [0.0, 0.24, 0.48], quat((0.24, 0.18, 0.46)) + quat((-0.18, 0.2, 0.34)) + quat((0.24, 0.18, 0.46))),
            ("RootweaverRootSpineL", "rotation", [0.0, 0.24, 0.48], quat((0.0, -0.28, -0.4)) + quat((0.12, -0.34, -0.48)) + quat((0.0, -0.28, -0.4))),
        ])
        feed_channels.extend([
            ("RootweaverSporeFan", "rotation", [0.0, 0.3, 0.6], quat((0.24, 0.0, 1.57)) + quat((0.16, 0.0, 1.34)) + quat((0.24, 0.0, 1.57))),
            ("RootweaverArmL", "rotation", [0.0, 0.3, 0.6], quat((0.0, -0.2, -0.8)) + quat((0.16, -0.28, -0.68)) + quat((0.0, -0.2, -0.8))),
            ("RootweaverArmR", "rotation", [0.0, 0.3, 0.6], quat((0.0, 0.2, 0.8)) + quat((0.16, 0.28, 0.68)) + quat((0.0, 0.2, 0.8))),
        ])
        retreat_channels.extend([
            ("RootweaverArmR", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.2, 0.8)) + quat((0.28, 0.3, 0.92)) + quat((0.0, 0.2, 0.8))),
            ("RootweaverRootSpineL", "rotation", [0.0, 0.22, 0.44], quat((0.0, -0.28, -0.4)) + quat((-0.14, -0.34, -0.48)) + quat((0.0, -0.28, -0.4))),
            ("RootweaverRootSpineR", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.28, 0.4)) + quat((-0.14, 0.34, 0.48)) + quat((0.0, 0.28, 0.4))),
        ])
    elif name == "miremaw":
        # Miremaw's amphibious identity lives in the gill fan, jaw hooks and
        # water fins. Articulate those surfaces independently so the wet
        # silhouette does not read as a static shell when it is close enough
        # for the release camera to judge the family.
        idle_channels.extend([
            ("MiremawGillFan", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.0, 1.48)) + quat((0.0, 0.0, 1.66)) + quat((0.0, 0.0, 1.48))),
            ("MiremawGillCollarL", "rotation", [0.0, 0.8, 1.6], quat((0.18, -0.28, -0.18)) + quat((0.08, -0.34, -0.24)) + quat((0.18, -0.28, -0.18))),
            ("MiremawGillCollarR", "rotation", [0.0, 0.8, 1.6], quat((-0.18, 0.28, 0.18)) + quat((-0.08, 0.34, 0.24)) + quat((-0.18, 0.28, 0.18))),
            ("MiremawGillRidgeL", "rotation", [0.0, 0.8, 1.6], quat((0.0, -0.22, -0.08)) + quat((0.04, -0.24, -0.03)) + quat((0.0, -0.22, -0.08))),
            ("MiremawGillRidgeR", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.22, 0.08)) + quat((-0.04, 0.24, 0.03)) + quat((0.0, 0.22, 0.08))),
        ])
        walk_channels.extend([
            ("MiremawWaterFinL", "rotation", [0.0, 0.22, 0.44], quat((-0.20, -0.28, -0.08)) + quat((0.12, -0.34, -0.18)) + quat((-0.20, -0.28, -0.08))),
            ("MiremawWaterFinR", "rotation", [0.0, 0.22, 0.44], quat((0.20, 0.28, 0.08)) + quat((-0.12, 0.34, 0.18)) + quat((0.20, 0.28, 0.08))),
        ])
        attack_channels.extend([
            ("MiremawGillCollarL", "rotation", [0.0, 0.24, 0.48], quat((0.18, -0.28, -0.18)) + quat((0.32, -0.44, -0.30)) + quat((0.18, -0.28, -0.18))),
            ("MiremawGillCollarR", "rotation", [0.0, 0.24, 0.48], quat((-0.18, 0.28, 0.18)) + quat((-0.32, 0.44, 0.30)) + quat((-0.18, 0.28, 0.18))),
            ("MiremawJawHookL", "rotation", [0.0, 0.24, 0.48], quat((-0.72, 0.0, -0.18)) + quat((-0.98, 0.0, -0.28)) + quat((-0.72, 0.0, -0.18))),
            ("MiremawJawHookR", "rotation", [0.0, 0.24, 0.48], quat((0.72, 0.0, 0.18)) + quat((0.98, 0.0, 0.28)) + quat((0.72, 0.0, 0.18))),
            ("MiremawJawPlateL", "rotation", [0.0, 0.24, 0.48], quat((-0.36, 0.0, -0.12)) + quat((-0.58, 0.0, -0.18)) + quat((-0.36, 0.0, -0.12))),
            ("MiremawJawPlateR", "rotation", [0.0, 0.24, 0.48], quat((0.36, 0.0, 0.12)) + quat((0.58, 0.0, 0.18)) + quat((0.36, 0.0, 0.12))),
            ("MiremawJawLower", "rotation", [0.0, 0.24, 0.48], quat((0.18, 0.0, 0.0)) + quat((0.42, 0.0, 0.0)) + quat((0.18, 0.0, 0.0))),
        ])
        feed_channels.extend([
            ("MiremawGillCollarL", "rotation", [0.0, 0.3, 0.6], quat((0.18, -0.28, -0.18)) + quat((0.02, -0.14, -0.10)) + quat((0.18, -0.28, -0.18))),
            ("MiremawGillCollarR", "rotation", [0.0, 0.3, 0.6], quat((-0.18, 0.28, 0.18)) + quat((-0.02, 0.14, 0.10)) + quat((-0.18, 0.28, 0.18))),
            ("MiremawJawHookL", "rotation", [0.0, 0.3, 0.6], quat((-0.72, 0.0, -0.18)) + quat((-0.88, 0.0, -0.24)) + quat((-0.72, 0.0, -0.18))),
            ("MiremawJawHookR", "rotation", [0.0, 0.3, 0.6], quat((0.72, 0.0, 0.18)) + quat((0.88, 0.0, 0.24)) + quat((0.72, 0.0, 0.18))),
            ("MiremawGillFan", "rotation", [0.0, 0.3, 0.6], quat((0.0, 0.0, 1.57)) + quat((0.0, 0.0, 1.32)) + quat((0.0, 0.0, 1.57))),
            ("MiremawJawLower", "rotation", [0.0, 0.3, 0.6], quat((0.18, 0.0, 0.0)) + quat((0.34, 0.0, 0.0)) + quat((0.18, 0.0, 0.0))),
        ])
        retreat_channels.extend([
            ("MiremawGillCollarL", "rotation", [0.0, 0.22, 0.44], quat((0.18, -0.28, -0.18)) + quat((-0.10, -0.38, -0.26)) + quat((0.18, -0.28, -0.18))),
            ("MiremawGillCollarR", "rotation", [0.0, 0.22, 0.44], quat((-0.18, 0.28, 0.18)) + quat((0.10, 0.38, 0.26)) + quat((-0.18, 0.28, 0.18))),
            ("MiremawWaterFinL", "rotation", [0.0, 0.22, 0.44], quat((-0.20, -0.28, -0.08)) + quat((-0.14, -0.36, -0.2)) + quat((-0.20, -0.28, -0.08))),
            ("MiremawWaterFinR", "rotation", [0.0, 0.22, 0.44], quat((0.20, 0.28, 0.08)) + quat((0.14, 0.36, 0.2)) + quat((0.20, 0.28, 0.08))),
            ("MiremawGillFan", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.0, 1.57)) + quat((0.0, 0.0, 1.82)) + quat((0.0, 0.0, 1.57))),
        ])
    elif name == "glassmoth":
        # Glassmoth reads as a living light-trap through its paired wing
        # membranes, spars and antennae. Keep those surfaces breathing in
        # concert so the high-definition silhouette does not freeze into a
        # decorative plane during close tactical views.
        idle_channels.extend([
            ("GlassmothWingL0", "rotation", [0.0, 0.8, 1.6], quat((-0.2, -0.2, -0.18)) + quat((0.08, -0.24, -0.26)) + quat((-0.2, -0.2, -0.18))),
            ("GlassmothWingR0", "rotation", [0.0, 0.8, 1.6], quat((0.2, 0.2, 0.18)) + quat((-0.08, 0.24, 0.26)) + quat((0.2, 0.2, 0.18))),
            ("GlassmothWingL1", "rotation", [0.0, 0.8, 1.6], quat((-0.25, -0.28, -0.24)) + quat((0.06, -0.32, -0.3)) + quat((-0.25, -0.28, -0.24))),
            ("GlassmothWingR1", "rotation", [0.0, 0.8, 1.6], quat((0.25, 0.28, 0.24)) + quat((-0.06, 0.32, 0.3)) + quat((0.25, 0.28, 0.24))),
        ])
        walk_channels.extend([
            ("GlassmothWingL0", "rotation", [0.0, 0.22, 0.44], quat((-0.2, -0.2, -0.18)) + quat((0.16, -0.28, -0.32)) + quat((-0.2, -0.2, -0.18))),
            ("GlassmothWingR0", "rotation", [0.0, 0.22, 0.44], quat((0.2, 0.2, 0.18)) + quat((-0.16, 0.28, 0.32)) + quat((0.2, 0.2, 0.18))),
            ("GlassmothWingL1", "rotation", [0.0, 0.22, 0.44], quat((-0.25, -0.28, -0.24)) + quat((0.12, -0.36, -0.34)) + quat((-0.25, -0.28, -0.24))),
            ("GlassmothWingR1", "rotation", [0.0, 0.22, 0.44], quat((0.25, 0.28, 0.24)) + quat((-0.12, 0.36, 0.34)) + quat((0.25, 0.28, 0.24))),
        ])
        attack_channels.extend([
            ("GlassmothWingL1", "rotation", [0.0, 0.24, 0.48], quat((-0.25, -0.28, -0.24)) + quat((-0.22, -0.4, -0.42)) + quat((-0.25, -0.28, -0.24))),
            ("GlassmothWingR1", "rotation", [0.0, 0.24, 0.48], quat((0.25, 0.28, 0.24)) + quat((0.22, 0.4, 0.42)) + quat((0.25, 0.28, 0.24))),
            ("GlassmothWingL0", "rotation", [0.0, 0.24, 0.48], quat((-0.2, -0.2, -0.18)) + quat((-0.16, -0.32, -0.34)) + quat((-0.2, -0.2, -0.18))),
            ("GlassmothWingR0", "rotation", [0.0, 0.24, 0.48], quat((0.2, 0.2, 0.18)) + quat((0.16, 0.32, 0.34)) + quat((0.2, 0.2, 0.18))),
            ("GlassmothAntennaL", "rotation", [0.0, 0.24, 0.48], quat((0.48, 0.0, -0.22)) + quat((0.72, 0.0, -0.32)) + quat((0.48, 0.0, -0.22))),
            ("GlassmothAntennaR", "rotation", [0.0, 0.24, 0.48], quat((0.48, 0.0, 0.22)) + quat((0.72, 0.0, 0.32)) + quat((0.48, 0.0, 0.22))),
        ])
        feed_channels.extend([
            ("GlassmothWingL0", "rotation", [0.0, 0.3, 0.6], quat((-0.2, -0.2, -0.18)) + quat((0.12, -0.28, -0.26)) + quat((-0.2, -0.2, -0.18))),
            ("GlassmothWingR0", "rotation", [0.0, 0.3, 0.6], quat((0.2, 0.2, 0.18)) + quat((-0.12, 0.28, 0.26)) + quat((0.2, 0.2, 0.18))),
            ("GlassmothAntennaL", "rotation", [0.0, 0.3, 0.6], quat((0.48, 0.0, -0.22)) + quat((0.62, 0.0, -0.28)) + quat((0.48, 0.0, -0.22))),
            ("GlassmothAntennaR", "rotation", [0.0, 0.3, 0.6], quat((0.48, 0.0, 0.22)) + quat((0.62, 0.0, 0.28)) + quat((0.48, 0.0, 0.22))),
        ])
        retreat_channels.extend([
            ("GlassmothWingL1", "rotation", [0.0, 0.22, 0.44], quat((-0.25, -0.28, -0.24)) + quat((0.26, -0.42, -0.38)) + quat((-0.25, -0.28, -0.24))),
            ("GlassmothWingR1", "rotation", [0.0, 0.22, 0.44], quat((0.25, 0.28, 0.24)) + quat((-0.26, 0.42, 0.38)) + quat((0.25, 0.28, 0.24))),
            ("GlassmothWingL0", "rotation", [0.0, 0.22, 0.44], quat((-0.2, -0.2, -0.18)) + quat((0.18, -0.34, -0.3)) + quat((-0.2, -0.2, -0.18))),
            ("GlassmothWingR0", "rotation", [0.0, 0.22, 0.44], quat((0.2, 0.2, 0.18)) + quat((-0.18, 0.34, 0.3)) + quat((0.2, 0.2, 0.18))),
        ])
    elif name == "carrionbell":
        # Carrionbell's threat is a resonant, living instrument: the mantle
        # breathes around the ring, the bell ribs answer the core, and the
        # low tendrils trail the signal. Keep those layers articulated rather
        # than asking the torso beat to carry the entire silhouette.
        idle_channels.extend([
            ("CarrionbellMantleSeamL", "rotation", [0.0, 0.8, 1.6], quat((0.0, -0.24, -0.08)) + quat((0.06, -0.28, -0.12)) + quat((0.0, -0.24, -0.08))),
            ("CarrionbellMantleSeamR", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.24, 0.08)) + quat((-0.06, 0.28, 0.12)) + quat((0.0, 0.24, 0.08))),
            ("CarrionbellResonatorRing", "rotation", [0.0, 0.8, 1.6], quat((1.5708, 0.0, 0.0)) + quat((1.5708, 0.04, 0.0)) + quat((1.5708, 0.0, 0.0))),
        ])
        walk_channels.extend([
            ("CarrionbellMantle", "rotation", [0.0, 0.22, 0.44], quat((0.18, 0.0, 0.0)) + quat((-0.18, 0.0, 0.0)) + quat((0.18, 0.0, 0.0))),
            ("CarrionbellMantleSeamL", "rotation", [0.0, 0.22, 0.44], quat((0.0, -0.24, -0.08)) + quat((0.12, -0.3, -0.16)) + quat((0.0, -0.24, -0.08))),
            ("CarrionbellMantleSeamR", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.24, 0.08)) + quat((-0.12, 0.3, 0.16)) + quat((0.0, 0.24, 0.08))),
        ])
        attack_channels.extend([
            ("CarrionbellResonator", "rotation", [0.0, 0.24, 0.48], quat((0.0, 0.0, 0.0)) + quat((-0.18, 0.0, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("CarrionbellResonatorCore", "rotation", [0.0, 0.24, 0.48], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.22)) + quat((0.0, 0.0, 0.0))),
            ("CarrionbellResonatorRing", "rotation", [0.0, 0.24, 0.48], quat((1.5708, 0.0, 0.0)) + quat((1.5708, 0.0, 0.34)) + quat((1.5708, 0.0, 0.0))),
            ("CarrionbellBellRib0", "rotation", [0.0, 0.24, 0.48], quat((0.0, -0.32, -0.52)) + quat((0.18, -0.46, -0.68)) + quat((0.0, -0.32, -0.52))),
            ("CarrionbellBellRib1", "rotation", [0.0, 0.24, 0.48], quat((0.0, -0.32, -0.52)) + quat((0.18, -0.46, -0.68)) + quat((0.0, -0.32, -0.52))),
        ])
        feed_channels.extend([
            ("CarrionbellResonatorCore", "rotation", [0.0, 0.3, 0.6], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.16)) + quat((0.0, 0.0, 0.0))),
            ("CarrionbellResonatorRing", "rotation", [0.0, 0.3, 0.6], quat((1.5708, 0.0, 0.0)) + quat((1.5708, 0.0, 0.24)) + quat((1.5708, 0.0, 0.0))),
            ("CarrionbellMantleSeamL", "rotation", [0.0, 0.3, 0.6], quat((0.0, -0.24, -0.08)) + quat((0.1, -0.28, -0.12)) + quat((0.0, -0.24, -0.08))),
            ("CarrionbellMantleSeamR", "rotation", [0.0, 0.3, 0.6], quat((0.0, 0.24, 0.08)) + quat((-0.1, 0.28, 0.12)) + quat((0.0, 0.24, 0.08))),
        ])
        retreat_channels.extend([
            ("CarrionbellMantleSeamL", "rotation", [0.0, 0.22, 0.44], quat((0.0, -0.24, -0.08)) + quat((-0.18, -0.34, -0.2)) + quat((0.0, -0.24, -0.08))),
            ("CarrionbellMantleSeamR", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.24, 0.08)) + quat((0.18, 0.34, 0.2)) + quat((0.0, 0.24, 0.08))),
            ("CarrionbellResonatorRing", "rotation", [0.0, 0.22, 0.44], quat((1.5708, 0.0, 0.0)) + quat((1.5708, 0.0, -0.28)) + quat((1.5708, 0.0, 0.0))),
            ("CarrionbellSignalTendril2", "rotation", [0.0, 0.22, 0.44], quat((0.32, 0.0, 0.0)) + quat((0.48, 0.0, 0.18)) + quat((0.32, 0.0, 0.0))),
        ])
    elif name == "thornback":
        # Thornback's readable danger is the layered jaw-and-spine profile.
        # Give the paired plates, dorsal spines and crown ridges their own
        # restrained response so the armored family does not become a static
        # shell with only the shared torso beat moving underneath it.
        idle_channels.extend([
            ("ThornbackJawPlateL", "rotation", [0.0, 0.8, 1.6], quat((-0.38, 0.0, -0.12)) + quat((-0.44, 0.0, -0.16)) + quat((-0.38, 0.0, -0.12))),
            ("ThornbackJawPlateR", "rotation", [0.0, 0.8, 1.6], quat((0.38, 0.0, 0.12)) + quat((0.44, 0.0, 0.16)) + quat((0.38, 0.0, 0.12))),
            ("ThornbackSpineL", "rotation", [0.0, 0.8, 1.6], quat((0.0, -0.24, -0.34)) + quat((0.04, -0.28, -0.4)) + quat((0.0, -0.24, -0.34))),
            ("ThornbackSpineR", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.24, 0.34)) + quat((-0.04, 0.28, 0.4)) + quat((0.0, 0.24, 0.34))),
        ])
        walk_channels.extend([
            ("ThornbackSpineL", "rotation", [0.0, 0.22, 0.44], quat((0.0, -0.24, -0.34)) + quat((0.16, -0.34, -0.48)) + quat((0.0, -0.24, -0.34))),
            ("ThornbackSpineR", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.24, 0.34)) + quat((-0.16, 0.34, 0.48)) + quat((0.0, 0.24, 0.34))),
            ("ThornbackDorsalRidge0", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.0, -0.12)) + quat((0.1, 0.0, -0.2)) + quat((0.0, 0.0, -0.12))),
        ])
        attack_channels.extend([
            ("ThornbackJawPlateL", "rotation", [0.0, 0.24, 0.48], quat((-0.38, 0.0, -0.12)) + quat((-0.72, 0.0, -0.24)) + quat((-0.38, 0.0, -0.12))),
            ("ThornbackJawPlateR", "rotation", [0.0, 0.24, 0.48], quat((0.38, 0.0, 0.12)) + quat((0.72, 0.0, 0.24)) + quat((0.38, 0.0, 0.12))),
            ("ThornbackSpineL", "rotation", [0.0, 0.24, 0.48], quat((0.0, -0.24, -0.34)) + quat((-0.12, -0.38, -0.54)) + quat((0.0, -0.24, -0.34))),
            ("ThornbackSpineR", "rotation", [0.0, 0.24, 0.48], quat((0.0, 0.24, 0.34)) + quat((0.12, 0.38, 0.54)) + quat((0.0, 0.24, 0.34))),
            ("ThornbackCrownPlate", "rotation", [0.0, 0.24, 0.48], quat((0.0, 0.0, 0.08)) + quat((-0.18, 0.0, 0.16)) + quat((0.0, 0.0, 0.08))),
        ])
        feed_channels.extend([
            ("ThornbackJawPlateL", "rotation", [0.0, 0.3, 0.6], quat((-0.38, 0.0, -0.12)) + quat((-0.58, 0.0, -0.2)) + quat((-0.38, 0.0, -0.12))),
            ("ThornbackJawPlateR", "rotation", [0.0, 0.3, 0.6], quat((0.38, 0.0, 0.12)) + quat((0.58, 0.0, 0.2)) + quat((0.38, 0.0, 0.12))),
            ("ThornbackSpineL", "rotation", [0.0, 0.3, 0.6], quat((0.0, -0.24, -0.34)) + quat((0.12, -0.3, -0.42)) + quat((0.0, -0.24, -0.34))),
            ("ThornbackSpineR", "rotation", [0.0, 0.3, 0.6], quat((0.0, 0.24, 0.34)) + quat((-0.12, 0.3, 0.42)) + quat((0.0, 0.24, 0.34))),
        ])
        retreat_channels.extend([
            ("ThornbackSpineL", "rotation", [0.0, 0.22, 0.44], quat((0.0, -0.24, -0.34)) + quat((0.28, -0.4, -0.52)) + quat((0.0, -0.24, -0.34))),
            ("ThornbackSpineR", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.24, 0.34)) + quat((-0.28, 0.4, 0.52)) + quat((0.0, 0.24, 0.34))),
            ("ThornbackJawPlateL", "rotation", [0.0, 0.22, 0.44], quat((-0.38, 0.0, -0.12)) + quat((-0.22, 0.0, -0.06)) + quat((-0.38, 0.0, -0.12))),
            ("ThornbackJawPlateR", "rotation", [0.0, 0.22, 0.44], quat((0.38, 0.0, 0.12)) + quat((0.22, 0.0, 0.06)) + quat((0.38, 0.0, 0.12))),
        ])
    elif name == "ashmantle":
        # Ashmantle's identity is a hot, vented organic shell rather than a
        # generic blob. Let the paired louvers breathe around the siphon,
        # with mantle ribs and sensory tendrils carrying its threat response.
        idle_channels.extend([
            ("AshmantleHeatLouverL", "rotation", [0.0, 0.8, 1.6], quat((0.0, -0.28, -0.12)) + quat((0.05, -0.34, -0.18)) + quat((0.0, -0.28, -0.12))),
            ("AshmantleHeatLouverR", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.28, 0.12)) + quat((-0.05, 0.34, 0.18)) + quat((0.0, 0.28, 0.12))),
            ("AshmantleLouverRibL", "rotation", [0.0, 0.8, 1.6], quat((0.0, -0.34, -0.22)) + quat((0.04, -0.38, -0.28)) + quat((0.0, -0.34, -0.22))),
            ("AshmantleLouverRibR", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.34, 0.22)) + quat((-0.04, 0.38, 0.28)) + quat((0.0, 0.34, 0.22))),
        ])
        walk_channels.extend([
            ("AshmantleHeatLouverL", "rotation", [0.0, 0.22, 0.44], quat((0.0, -0.28, -0.12)) + quat((0.16, -0.38, -0.24)) + quat((0.0, -0.28, -0.12))),
            ("AshmantleHeatLouverR", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.28, 0.12)) + quat((-0.16, 0.38, 0.24)) + quat((0.0, 0.28, 0.12))),
            ("AshmantleLouverRibL", "rotation", [0.0, 0.22, 0.44], quat((0.0, -0.34, -0.22)) + quat((0.12, -0.42, -0.3)) + quat((0.0, -0.34, -0.22))),
            ("AshmantleLouverRibR", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.34, 0.22)) + quat((-0.12, 0.42, 0.3)) + quat((0.0, 0.34, 0.22))),
        ])
        attack_channels.extend([
            ("AshmantleSiphon", "rotation", [0.0, 0.24, 0.48], quat((0.5, 0.0, 0.0)) + quat((0.82, 0.0, 0.0)) + quat((0.5, 0.0, 0.0))),
            ("AshmantleHeatLouverL", "rotation", [0.0, 0.24, 0.48], quat((0.0, -0.28, -0.12)) + quat((-0.2, -0.42, -0.28)) + quat((0.0, -0.28, -0.12))),
            ("AshmantleHeatLouverR", "rotation", [0.0, 0.24, 0.48], quat((0.0, 0.28, 0.12)) + quat((0.2, 0.42, 0.28)) + quat((0.0, 0.28, 0.12))),
            ("AshmantleLouverRibL", "rotation", [0.0, 0.24, 0.48], quat((0.0, -0.34, -0.22)) + quat((-0.16, -0.5, -0.36)) + quat((0.0, -0.34, -0.22))),
            ("AshmantleLouverRibR", "rotation", [0.0, 0.24, 0.48], quat((0.0, 0.34, 0.22)) + quat((0.16, 0.5, 0.36)) + quat((0.0, 0.34, 0.22))),
            ("AshmantleTendrilL", "rotation", [0.0, 0.24, 0.48], quat((0.5, 0.0, -0.2)) + quat((0.76, 0.0, -0.34)) + quat((0.5, 0.0, -0.2))),
            ("AshmantleTendrilR", "rotation", [0.0, 0.24, 0.48], quat((0.5, 0.0, 0.2)) + quat((0.76, 0.0, 0.34)) + quat((0.5, 0.0, 0.2))),
        ])
        feed_channels.extend([
            ("AshmantleSiphon", "rotation", [0.0, 0.3, 0.6], quat((0.5, 0.0, 0.0)) + quat((0.7, 0.0, 0.0)) + quat((0.5, 0.0, 0.0))),
            ("AshmantleHeatLouverL", "rotation", [0.0, 0.3, 0.6], quat((0.0, -0.28, -0.12)) + quat((0.12, -0.36, -0.2)) + quat((0.0, -0.28, -0.12))),
            ("AshmantleHeatLouverR", "rotation", [0.0, 0.3, 0.6], quat((0.0, 0.28, 0.12)) + quat((-0.12, 0.36, 0.2)) + quat((0.0, 0.28, 0.12))),
            ("AshmantleTendrilL", "rotation", [0.0, 0.3, 0.6], quat((0.5, 0.0, -0.2)) + quat((0.64, 0.0, -0.28)) + quat((0.5, 0.0, -0.2))),
            ("AshmantleTendrilR", "rotation", [0.0, 0.3, 0.6], quat((0.5, 0.0, 0.2)) + quat((0.64, 0.0, 0.28)) + quat((0.5, 0.0, 0.2))),
        ])
        retreat_channels.extend([
            ("AshmantleHeatLouverL", "rotation", [0.0, 0.22, 0.44], quat((0.0, -0.28, -0.12)) + quat((0.28, -0.44, -0.3)) + quat((0.0, -0.28, -0.12))),
            ("AshmantleHeatLouverR", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.28, 0.12)) + quat((-0.28, 0.44, 0.3)) + quat((0.0, 0.28, 0.12))),
            ("AshmantleLouverRibL", "rotation", [0.0, 0.22, 0.44], quat((0.0, -0.34, -0.22)) + quat((0.2, -0.46, -0.32)) + quat((0.0, -0.34, -0.22))),
            ("AshmantleLouverRibR", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.34, 0.22)) + quat((-0.2, 0.46, 0.32)) + quat((0.0, 0.34, 0.22))),
        ])

    animations = [
        animation("Idle", idle_channels),
        animation("Walk", walk_channels),
        animation("Attack", attack_channels),
        animation("Hit", hit_channels),
        animation("Feed", feed_channels),
        animation("Nest", nest_channels),
        animation("Retreat", retreat_channels),
        animation("Death", death_channels),
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
            "required_nodes": [root_name, "Torso", "TorsoCore", "OrganicDorsalPlate", *spec["signature_nodes"], "ProductionAssetMarker"],
            "animation_clips": ["Idle", "Walk", "Attack", "Hit", "Feed", "Nest", "Retreat", "Death"],
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
