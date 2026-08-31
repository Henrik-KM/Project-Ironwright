"""Build the remaining original high-definition organic family shells.

The seven assets in this builder deliberately share a small production mesh kit
while keeping distinct silhouettes and stable anatomy names. They are imported
as presentation shells; gameplay collision, ecology and tier data remain owned
by the runtime enemy actor.
"""

from __future__ import annotations

import base64
import hashlib
import json
import math
import sys
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parent
ASSET_ROOT = SOURCE_DIR.parents[1]
sys.path.insert(0, str(ASSET_ROOT / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, _geometry, add_beveled_box, add_cylinder, add_ellipsoid, add_uv_sphere, quat  # noqa: E402


TEXTURE_URIS = {
    "shell_base_color": "../organic_families/textures/organic_shell_base_color.png",
    "shell_normal": "../organic_families/textures/organic_shell_normal.png",
    "shell_orm": "../organic_families/textures/organic_shell_orm.png",
    "tissue_base_color": "../organic_families/textures/organic_tissue_base_color.png",
    "tissue_normal": "../organic_families/textures/organic_tissue_normal.png",
    "tissue_orm": "../organic_families/textures/organic_tissue_orm.png",
    "emissive": "../organic_families/textures/organic_emissive.png",
}
TEXTURE_ORDER = tuple(TEXTURE_URIS)
TEXTURE_SIZE = 1024
SURFACE_PROFILE = "shared_organic_pbr_v1"
ANIMATION_CLIPS = ["Idle", "Walk", "Attack", "Hit", "Feed", "Nest", "Retreat", "Death"]
ANATOMY_BASE_NODES = [
    "OrganicPulseRim",
    "OrganicGrowthPlate",
    "OrganicVascularVeinL",
    "OrganicVascularVeinR",
    "OrganicVascularNodeL",
    "OrganicVascularNodeR",
]


FAMILIES = {
    "roofleaper": {
        "display": "Roofleaper",
        "asset_id": "roofleaper.ambusher.v1",
        "colors": ([0.035, 0.055, 0.07, 1.0], [0.16, 0.22, 0.25, 1.0], [0.10, 0.28, 0.34, 1.0], [0.48, 0.39, 0.28, 1.0], [0.75, 0.22, 0.04, 1.0], [0.30, 0.09, 0.08, 1.0]),
        "body_profile": ((1.25, 0.74, 1.55), (1.08, 0.66, 1.20), 0.04),
        "socket_contract": "crown, wing_membranes, talons, threat_eyes",
        "signature_nodes": ["RoofleaperFineVeinL", "RoofleaperFineVeinR", "RoofleaperWingFrameL", "RoofleaperWingFastenerR"],
        "anatomy_scale": 0.88,
        "anatomy_accent": "de7c9a",
        "focal_nodes": ["RoofleaperSensoryTalonL", "RoofleaperSensoryTalonR", "RoofleaperCentralOculus"],
    },
    "glassmoth": {
        "display": "Glassmoth",
        "asset_id": "glassmoth.swarm.v1",
        "colors": ([0.025, 0.07, 0.075, 1.0], [0.19, 0.38, 0.39, 1.0], [0.27, 0.16, 0.34, 1.0], [0.64, 0.58, 0.43, 1.0], [0.12, 0.72, 0.68, 1.0], [0.20, 0.24, 0.26, 1.0]),
        "body_profile": ((0.94, 1.04, 1.18), (0.88, 0.82, 1.02), 0.035),
        "socket_contract": "wing_pairs, antennae, luminous_eyes, thorax",
        "signature_nodes": ["GlassmothFineVeinL0", "GlassmothFineVeinR0", "GlassmothWingFrameL0", "GlassmothWingFastenerR1"],
        "anatomy_scale": 0.82,
        "anatomy_accent": "8ee7d0",
        "focal_nodes": ["GlassmothOcellus0", "GlassmothOcellus1", "GlassmothOcellus2", "GlassmothLensCollar"],
    },
    "miremaw": {
        "display": "Miremaw",
        "asset_id": "miremaw.amphibious.v1",
        "colors": ([0.035, 0.065, 0.045, 1.0], [0.22, 0.28, 0.18, 1.0], [0.25, 0.07, 0.045, 1.0], [0.52, 0.44, 0.29, 1.0], [0.82, 0.32, 0.05, 1.0], [0.28, 0.12, 0.075, 1.0]),
        "body_profile": ((1.45, 0.76, 1.34), (1.28, 0.66, 1.10), 0.025),
        "socket_contract": "maw, gill_fan, water_fins, jaw_hooks",
        "signature_nodes": ["MiremawGillRidgeL", "MiremawGillRidgeR", "MiremawJawPlateL", "MiremawGillSpineR", "MiremawGillCollarL"],
        "anatomy_scale": 1.18,
        "anatomy_accent": "df9b63",
        "focal_nodes": ["MiremawMawGuard", "MiremawMawLatchL", "MiremawMawLatchR"],
    },
    "carrionbell": {
        "display": "Carrion Bell",
        "asset_id": "carrionbell.signal.v1",
        "colors": ([0.065, 0.035, 0.06, 1.0], [0.25, 0.12, 0.22, 1.0], [0.35, 0.08, 0.24, 1.0], [0.56, 0.45, 0.32, 1.0], [0.9, 0.22, 0.14, 1.0], [0.34, 0.09, 0.16, 1.0]),
        "body_profile": ((1.32, 1.15, 1.18), (1.18, 0.86, 1.02), 0.02),
        "socket_contract": "resonator, bell_mantle, signal_tendrils, crown_plate",
        "signature_nodes": ["CarrionbellResonatorRing", "CarrionbellResonatorCore", "CarrionbellResonatorRootCollar", "CarrionbellBellRib0"],
        "anatomy_scale": 1.05,
        "anatomy_accent": "dd6e92",
        "focal_nodes": ["CarrionbellThroatCollar", "CarrionbellThroatNodule"],
    },
    "rootweaver": {
        "display": "Rootweaver",
        "asset_id": "rootweaver.route_controller.v1",
        "colors": ([0.035, 0.05, 0.04, 1.0], [0.20, 0.23, 0.14, 1.0], [0.29, 0.06, 0.12, 1.0], [0.48, 0.38, 0.24, 1.0], [0.16, 0.72, 0.63, 1.0], [0.28, 0.08, 0.09, 1.0]),
        "body_profile": ((1.18, 1.05, 1.45), (1.04, 0.84, 1.18), 0.025),
        "socket_contract": "root_arms, route_spines, spore_fan, crown_oculi",
        "signature_nodes": ["RootweaverKnuckleL", "RootweaverKnuckleR", "RootweaverCrownPlate0", "RootweaverJawPlateL", "RootweaverJawPlateR", "RootweaverRootSpineR"],
        "anatomy_scale": 1.28,
        "anatomy_accent": "b85ce1",
        "focal_nodes": ["RootweaverRouteMask", "RootweaverRouteKeel", "RootweaverRouteTendrilL", "RootweaverRouteTendrilR"],
    },
    "thornback": {
        "display": "Thornback",
        "asset_id": "thornback.territorial.v1",
        "colors": ([0.055, 0.045, 0.035, 1.0], [0.30, 0.19, 0.10, 1.0], [0.36, 0.12, 0.08, 1.0], [0.57, 0.46, 0.30, 1.0], [0.92, 0.38, 0.08, 1.0], [0.34, 0.12, 0.07, 1.0]),
        "body_profile": ((1.50, 0.82, 1.45), (1.34, 0.75, 1.25), 0.03),
        "socket_contract": "thorn_crown, dorsal_spines, jaw_plates, threat_eyes",
        "signature_nodes": ["ThornbackCrown", "ThornbackSpineL", "ThornbackSpineR", "ThornbackJawPlateL", "ThornbackBarb0"],
        "anatomy_scale": 1.12,
        "anatomy_accent": "e3b45d",
        "focal_nodes": ["ThornbackFaceShield", "ThornbackFaceBarb"],
    },
    "ashmantle": {
        "display": "Ashmantle",
        "asset_id": "ashmantle.route_predator.v1",
        "colors": ([0.035, 0.045, 0.055, 1.0], [0.16, 0.20, 0.24, 1.0], [0.20, 0.27, 0.32, 1.0], [0.52, 0.48, 0.38, 1.0], [0.94, 0.23, 0.08, 1.0], [0.18, 0.10, 0.08, 1.0]),
        "body_profile": ((1.48, 0.82, 1.42), (1.30, 0.72, 1.22), 0.03),
        "socket_contract": "heat_mantle, louver_fins, route_siphon, sensory_tendrils",
        "signature_nodes": ["AshmantleMantle", "AshmantleHeatLouverL", "AshmantleHeatLouverR", "AshmantleSiphon", "AshmantleSiphonRing"],
        "anatomy_scale": 1.20,
        "anatomy_accent": "f07b4a",
        "focal_nodes": ["AshmantleThermalCollar", "AshmantleThermalCore"],
    },
}


def color_from_hex(value: str) -> list[float]:
    """Convert a six-digit authored colour into glTF linear-factor channels."""
    value = value.removeprefix("#")
    if len(value) != 6:
        raise ValueError(f"Expected a six-digit RGB colour, got {value!r}")
    return [int(value[index:index + 2], 16) / 255.0 for index in (0, 2, 4)] + [1.0]


def darkened(color: Sequence[float], amount: float) -> list[float]:
    return [float(channel) * (1.0 - amount) for channel in color[:3]] + [float(color[3])]


def lerped(color: Sequence[float], target: Sequence[float], amount: float) -> list[float]:
    return [
        float(color[index]) + (float(target[index]) - float(color[index])) * amount
        for index in range(4)
    ]


def matrix_multiply(left: Sequence[Sequence[float]], right: Sequence[Sequence[float]]) -> list[list[float]]:
    return [
        [sum(float(left[row][axis]) * float(right[axis][column]) for axis in range(4)) for column in range(4)]
        for row in range(4)
    ]


def node_matrix(node: dict) -> list[list[float]]:
    translation = node.get("translation", [0.0, 0.0, 0.0])
    scale = node.get("scale", [1.0, 1.0, 1.0])
    x, y, z, w = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    rotation = [
        [1.0 - 2.0 * (y * y + z * z), 2.0 * (x * y - w * z), 2.0 * (x * z + w * y), 0.0],
        [2.0 * (x * y + w * z), 1.0 - 2.0 * (x * x + z * z), 2.0 * (y * z - w * x), 0.0],
        [2.0 * (x * z - w * y), 2.0 * (y * z + w * x), 1.0 - 2.0 * (x * x + y * y), 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ]
    scaling = [
        [float(scale[0]), 0.0, 0.0, 0.0],
        [0.0, float(scale[1]), 0.0, 0.0],
        [0.0, 0.0, float(scale[2]), 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ]
    result = matrix_multiply(rotation, scaling)
    for axis in range(3):
        result[axis][3] = float(translation[axis])
    return result


def aggregate_geometry_bounds(nodes: Sequence[dict], meshes: Sequence[dict], builder: BufferBuilder) -> tuple[list[float], list[float]]:
    """Measure the final package from transformed glTF accessor envelopes."""
    minimum = [math.inf, math.inf, math.inf]
    maximum = [-math.inf, -math.inf, -math.inf]
    identity = [[1.0 if row == column else 0.0 for column in range(4)] for row in range(4)]

    def walk(node_index: int, parent_matrix: Sequence[Sequence[float]]) -> None:
        node = nodes[node_index]
        world = matrix_multiply(parent_matrix, node_matrix(node))
        if "mesh" in node:
            for primitive in meshes[node["mesh"]]["primitives"]:
                accessor = builder.accessors[primitive["attributes"]["POSITION"]]
                accessor_minimum = accessor.get("min")
                accessor_maximum = accessor.get("max")
                if not isinstance(accessor_minimum, list) or not isinstance(accessor_maximum, list):
                    raise ValueError("Aggregate bounds require explicit POSITION accessor bounds")
                for corner_index in range(8):
                    position = tuple(
                        float(accessor_maximum[axis] if corner_index & (1 << axis) else accessor_minimum[axis])
                        for axis in range(3)
                    )
                    transformed = [
                        sum(world[row][axis] * (*position, 1.0)[axis] for axis in range(4))
                        for row in range(3)
                    ]
                    for axis in range(3):
                        minimum[axis] = min(minimum[axis], transformed[axis])
                        maximum[axis] = max(maximum[axis], transformed[axis])
        for child_index in node.get("children", []):
            walk(child_index, world)

    walk(0, identity)
    if any(not math.isfinite(value) for value in (*minimum, *maximum)):
        raise ValueError("Authored organic package contains no finite geometry bounds")
    return ([round(value, 6) for value in minimum], [round(value, 6) for value in maximum])


def add_convex_sheet(
    builder: BufferBuilder,
    size: Sequence[float],
    material: int,
    rings: int = 5,
    sides: int = 24,
) -> tuple[int, int, int, int, int, int]:
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
) -> tuple[int, int, int, int, int, int]:
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
) -> tuple[int, int, int, int, int, int]:
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
) -> tuple[int, int, int, int, int, int]:
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
) -> tuple[int, int, int, int, int, int]:
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


def add_tapered_cylinder_mesh(
    builder: BufferBuilder,
    top_radius: float,
    bottom_radius: float,
    height: float,
    material: int,
    sides: int = 32,
    rings: int = 3,
) -> tuple[int, int, int, int, int, int]:
    """Build the runtime tapered-cylinder profile along local Y."""
    top_radius = max(0.001, float(top_radius))
    bottom_radius = max(0.001, float(bottom_radius))
    height = max(0.001, float(height))
    sides = max(24, int(sides))
    rings = max(1, int(rings))
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []
    side_rings: list[list[int]] = []
    slope = (bottom_radius - top_radius) / height
    normal_length = math.sqrt(1.0 + slope * slope)
    for ring_index in range(rings + 1):
        fraction = ring_index / rings
        y = -height * 0.5 + height * fraction
        radius = bottom_radius + (top_radius - bottom_radius) * fraction
        ring: list[int] = []
        for side in range(sides):
            angle = math.tau * side / sides
            cosine = math.cos(angle)
            sine = math.sin(angle)
            ring.append(len(positions) // 3)
            positions.extend([radius * cosine, y, radius * sine])
            normals.extend([cosine / normal_length, slope / normal_length, sine / normal_length])
        side_rings.append(ring)
    for ring_index in range(rings):
        current = side_rings[ring_index]
        next_ring = side_rings[ring_index + 1]
        for side in range(sides):
            next_side = (side + 1) % sides
            indices.extend([
                current[side], current[next_side], next_ring[next_side],
                current[side], next_ring[next_side], next_ring[side],
            ])
    bottom_center = len(positions) // 3
    positions.extend([0.0, -height * 0.5, 0.0])
    normals.extend([0.0, -1.0, 0.0])
    top_center = len(positions) // 3
    positions.extend([0.0, height * 0.5, 0.0])
    normals.extend([0.0, 1.0, 0.0])
    for side in range(sides):
        next_side = (side + 1) % sides
        indices.extend([bottom_center, side_rings[0][next_side], side_rings[0][side]])
        indices.extend([top_center, side_rings[-1][side], side_rings[-1][next_side]])
    return _geometry(builder, positions, normals, indices, material)


def add_torus(
    builder: BufferBuilder,
    major_radius: float,
    minor_radius: float,
    material: int,
    major_segments: int = 36,
    minor_segments: int = 10,
) -> tuple[int, int, int, int, int, int]:
    """Build a smooth resonator ring around a living signal core."""
    major_segments = max(24, major_segments)
    minor_segments = max(6, minor_segments)
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
    anatomy_scale = float(spec["anatomy_scale"])
    anatomy_accent = color_from_hex(spec["anatomy_accent"])
    anatomy_tissue_color = lerped(color_from_hex("3d202b"), darkened(anatomy_accent, 0.72), 0.28)
    anatomy_signal_color = darkened(anatomy_accent, 0.42)
    # Core glTF bounds emissiveFactor components to [0, 1]. Preserve as much
    # of the former 1.35 runtime energy as the core format permits without
    # introducing an optional extension that could import inconsistently.
    anatomy_emissive = [min(1.0, float(channel) * 1.35) for channel in anatomy_accent[:3]]
    membrane_tone = [channel * 0.62 if index < 3 else channel for index, channel in enumerate(colors[2])]
    # Glassmoth is the luminous territorial swarm. Its wing membranes should
    # carry a cool living-light identity instead of inheriting the warmer
    # threat palette used by the terrestrial families.
    glassmoth_vein_material: int | None = None
    if name == "glassmoth":
        membrane_tone = [0.07, 0.34, 0.36, 1.0]
    threat_emissive = [0.14, 0.86, 0.72] if name == "glassmoth" else [1.0, 0.18, 0.04]

    def surface_material(
        material_name: str,
        color: Sequence[float],
        metallic: float,
        roughness: float,
        surface: str,
        normal_scale: float,
        emissive_factor: Sequence[float] | None = None,
    ) -> dict:
        if surface == "shell":
            base_index, normal_index, orm_index = 0, 1, 2
        elif surface in {"tissue", "signal"}:
            base_index, normal_index, orm_index = 3, 4, 5
        else:
            raise ValueError(f"Unknown organic surface class: {surface}")
        entry = {
            "name": material_name,
            "pbrMetallicRoughness": {
                "baseColorFactor": list(color),
                "baseColorTexture": {"index": base_index},
                "metallicFactor": metallic,
                "roughnessFactor": roughness,
                "metallicRoughnessTexture": {"index": orm_index},
            },
            "normalTexture": {"index": normal_index, "scale": normal_scale},
            "occlusionTexture": {"index": orm_index, "strength": 0.88},
            "extras": {
                "ironwright_surface_class": surface,
                "ironwright_surface_profile": SURFACE_PROFILE,
                "surface_profile": SURFACE_PROFILE,
            },
        }
        if emissive_factor is not None:
            if surface != "signal":
                raise ValueError(f"{material_name}: emissive organic materials must use the signal surface class")
            entry["emissiveTexture"] = {"index": 6}
            entry["emissiveFactor"] = list(emissive_factor)
        return entry

    materials = [
        surface_material(f"{spec['display']} wet shell", colors[0], 0.18, 0.32, "shell", 0.28),
        surface_material(f"{spec['display']} layered plate", colors[1], 0.14, 0.42, "shell", 0.34),
        surface_material(f"{spec['display']} membrane", membrane_tone, 0.02, 0.58, "tissue", 0.18),
        surface_material(f"{spec['display']} bone", colors[3], 0.0, 0.62, "shell", 0.22),
        surface_material(f"{spec['display']} threat light", colors[4], 0.0, 0.22, "signal", 0.08, threat_emissive),
        surface_material(f"{spec['display']} tendon", colors[5], 0.0, 0.55, "tissue", 0.16),
    ]
    if name == "glassmoth":
        # A muted cyan living vein separates the broad luminous membrane from
        # the pale structural spars without turning the wing into a glowing
        # grid. It remains presentation-only under the existing wing rig.
        glassmoth_vein_material = len(materials)
        materials.append(surface_material(
            "Glassmoth wing vascular detail",
            [0.40, 0.66, 0.60, 1.0],
            0.02,
            0.44,
            "signal",
            0.10,
            [0.035, 0.24, 0.20],
        ))
    anatomy_tissue = len(materials)
    materials.append(surface_material(
        f"{spec['display']} anatomy tissue",
        anatomy_tissue_color,
        0.02,
        0.72,
        "tissue",
        0.16,
    ))
    anatomy_signal = len(materials)
    materials.append(surface_material(
        f"{spec['display']} anatomy signal",
        anatomy_signal_color,
        0.04,
        0.44,
        "signal",
        0.08,
        anatomy_emissive,
    ))
    meshes: list[dict] = []

    def mesh(mesh_name: str, geometry: tuple[int, int, int, int, int, int]) -> int:
        position, normal, uv, tangent, indices, material = geometry
        meshes.append({"name": mesh_name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal, "TEXCOORD_0": uv, "TANGENT": tangent}, "indices": indices, "material": material}]})
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
        # The shared torso ribs are individually detailed, but their gaps can
        # still read as a stack of floating plates at close review distance.
        # This vertical folded sheath gives every late family one continuous
        # ventral body surface while keeping the existing rib and socket
        # hardware visible above it. It is presentation-only geometry.
        "VentralSheath": mesh(
            "VentralSheath",
            add_organic_lobe(
                builder,
                (1.34, 0.28, 1.62),
                shell,
                lobes=5,
                rings=12,
                sides=56,
                scallop_amplitude=0.16,
                leading_extension=0.28,
                fold_strength=0.94,
            ),
        ),
    }
    # These meshes are package-owned versions of the former runtime anatomy
    # finish. Their dimensions already include the family scale factor, while
    # the nodes below retain the original runtime positions and rotations.
    mesh_ids["OrganicPulseRim"] = mesh(
        "OrganicPulseRim",
        add_torus(builder, 0.48 * anatomy_scale, 0.036 * anatomy_scale, anatomy_signal, 32, 6),
    )
    mesh_ids["OrganicVascularVein"] = mesh(
        "OrganicVascularVein",
        add_capsule(builder, 0.032 * anatomy_scale, 0.48 * anatomy_scale, anatomy_tissue, 32, 8),
    )
    mesh_ids["OrganicVascularNode"] = mesh(
        "OrganicVascularNode",
        add_uv_sphere(builder, 0.07 * anatomy_scale, anatomy_signal, 24, 32),
    )
    if name == "glassmoth":
        if glassmoth_vein_material is None:
            raise RuntimeError("Glassmoth vascular material must be authored before its wing mesh")
        mesh_ids["GlassmothWingVein"] = mesh(
            "GlassmothWingVein",
            add_capsule(builder, 0.024, 0.92, glassmoth_vein_material, 24),
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
        # The gill fan needs a central living root where it meets the thorax.
        # A dense folded sternum closes that transition without changing the
        # fan socket, collision, ecology or runtime animation ownership.
        mesh_ids["MiremawGillSternum"] = mesh(
            "MiremawGillSternum",
            add_organic_lobe(
                builder,
                (0.58, 0.24, 0.48),
                membrane,
                lobes=5,
                rings=11,
                sides=48,
                scallop_amplitude=0.12,
                leading_extension=0.22,
                fold_strength=0.84,
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
        mesh_ids["CarrionbellResonatorRootCollar"] = mesh(
            "CarrionbellResonatorRootCollar",
            add_organic_lobe(
                builder,
                (0.96, 0.34, 0.68),
                shell,
                lobes=6,
                rings=11,
                sides=48,
                scallop_amplitude=0.13,
                leading_extension=0.28,
                fold_strength=0.88,
            ),
        )
    # Rootweaver's paired crown plates frame the route-controller oculi. Give
    # those existing sockets a closed folded shell so they read as living
    # crown petals rather than two broad horizontal service plates.
    if name == "rootweaver":
        # The route-controller face needs a living collar where the front
        # mask meets the segmented thorax. Keep this transition torso-owned so
        # it follows the existing body breath and never becomes a detached
        # plate in the close gallery. It remains presentation-only.
        mesh_ids["RootweaverThoraxCollar"] = mesh(
            "RootweaverThoraxCollar",
            add_organic_lobe(
                builder,
                (0.82, 0.28, 0.52),
                shell,
                lobes=5,
                rings=11,
                sides=48,
                scallop_amplitude=0.13,
                leading_extension=0.28,
                fold_strength=0.86,
            ),
        )
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
    used_node_names = {root_name}

    def add_node(
        node_name: str,
        mesh_id: int | None = None,
        translation: Sequence[float] = (0.0, 0.0, 0.0),
        rotation: Sequence[float] = (0.0, 0.0, 0.0),
        scale: Sequence[float] | None = None,
        extras: dict | None = None,
        parent: int = 0,
    ) -> int:
        if node_name in used_node_names:
            raise ValueError(f"{name}: duplicate stable node name {node_name}")
        used_node_names.add(node_name)
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

    def add_anatomy_plate(
        node_name: str,
        radius: float,
        translation: Sequence[float],
        scale: Sequence[float],
    ) -> int:
        """Author the former runtime organic plate as one package hierarchy."""
        plate_root = add_node(
            node_name,
            translation=translation,
            scale=scale,
            extras={"surface": "source_owned_anatomy_plate", "presentation_only": True},
        )
        shell_mesh = mesh(
            f"{node_name}Shell",
            add_uv_sphere(builder, radius, anatomy_tissue, 24, 36),
        )
        ridge_mesh = mesh(
            f"{node_name}Ridge",
            add_uv_sphere(builder, radius * 0.76, anatomy_signal, 24, 36),
        )
        seam_mesh = mesh(
            f"{node_name}Seam",
            add_torus(builder, radius * 0.68, max(0.018, radius * 0.052), anatomy_signal, 40, 8),
        )
        add_node(
            f"{node_name}Shell",
            shell_mesh,
            parent=plate_root,
            extras={"surface": "anatomy_tissue"},
        )
        add_node(
            f"{node_name}Ridge",
            ridge_mesh,
            (0.0, radius * 0.42, -radius * 0.08),
            scale=(1.0, 0.16, 0.88),
            parent=plate_root,
            extras={"surface": "anatomy_signal"},
        )
        add_node(
            f"{node_name}Seam",
            seam_mesh,
            (0.0, radius * 0.34, -radius * 0.08),
            scale=(1.0, 0.42, 0.86),
            parent=plate_root,
            extras={"surface": "anatomy_signal"},
        )
        return plate_root

    def add_package_anatomy() -> None:
        """Place the former runtime finish directly under the authored root."""
        add_node(
            "OrganicPulseRim",
            mesh_ids["OrganicPulseRim"],
            (0.0, 1.08 * anatomy_scale, 0.12),
            extras={"surface": "anatomy_signal", "presentation_only": True},
        )
        add_anatomy_plate(
            "OrganicGrowthPlate",
            0.18 * anatomy_scale,
            (-0.1 * anatomy_scale, 1.34 * anatomy_scale, 0.22),
            (1.1, 0.48, 1.25),
        )
        for side in (-1.0, 1.0):
            suffix = "L" if side < 0.0 else "R"
            add_node(
                f"OrganicVascularVein{suffix}",
                mesh_ids["OrganicVascularVein"],
                (side * 0.28 * anatomy_scale, 1.02 * anatomy_scale, -0.1),
                rotation=(0.22, 0.0, side * 0.3),
                extras={"surface": "anatomy_tissue", "presentation_only": True},
            )
            add_node(
                f"OrganicVascularNode{suffix}",
                mesh_ids["OrganicVascularNode"],
                (side * 0.31 * anatomy_scale, 1.28 * anatomy_scale, -0.08),
                scale=(1.0, 0.78, 0.92),
                extras={"surface": "anatomy_signal", "presentation_only": True},
            )

        if name == "roofleaper":
            sensory_talon_mesh = mesh(
                "RoofleaperSensoryTalon",
                add_capsule(builder, 0.045 * anatomy_scale, 0.34 * anatomy_scale, anatomy_signal, 32, 8),
            )
            central_oculus_mesh = mesh(
                "RoofleaperCentralOculus",
                add_uv_sphere(builder, 0.085 * anatomy_scale, anatomy_signal, 24, 32),
            )
            for side in (-1.0, 1.0):
                suffix = "L" if side < 0.0 else "R"
                add_node(
                    f"RoofleaperSensoryTalon{suffix}",
                    sensory_talon_mesh,
                    (side * 0.23 * anatomy_scale, 1.34 * anatomy_scale, -0.34 * anatomy_scale),
                    rotation=(0.0, side * 0.36, side * 0.58),
                    extras={"surface": "anatomy_signal", "presentation_only": True},
                )
            add_node(
                "RoofleaperCentralOculus",
                central_oculus_mesh,
                (0.0, 1.35 * anatomy_scale, -0.42 * anatomy_scale),
                scale=(1.35, 0.72, 0.78),
                extras={"surface": "anatomy_signal", "presentation_only": True},
            )
        elif name == "glassmoth":
            for index, position in enumerate(((-0.16, 1.37, -0.36), (0.0, 1.43, -0.43), (0.16, 1.37, -0.36))):
                radius = (0.07 if index == 1 else 0.052) * anatomy_scale
                ocellus_mesh = mesh(
                    f"GlassmothOcellus{index}",
                    add_uv_sphere(builder, radius, anatomy_signal, 24, 32),
                )
                add_node(
                    f"GlassmothOcellus{index}",
                    ocellus_mesh,
                    tuple(component * anatomy_scale for component in position),
                    scale=(1.0, 0.76, 0.66),
                    extras={"surface": "anatomy_signal", "presentation_only": True},
                )
            lens_collar_mesh = mesh(
                "GlassmothLensCollar",
                add_torus(builder, 0.22 * anatomy_scale, 0.022 * anatomy_scale, anatomy_signal, 32, 6),
            )
            add_node(
                "GlassmothLensCollar",
                lens_collar_mesh,
                (0.0, 1.34 * anatomy_scale, -0.35 * anatomy_scale),
                rotation=(math.pi * 0.5, 0.0, 0.0),
                extras={"surface": "anatomy_signal", "presentation_only": True},
            )
        elif name == "miremaw":
            add_anatomy_plate(
                "MiremawMawGuard",
                0.24 * anatomy_scale,
                (0.0, 0.84 * anatomy_scale, -0.46 * anatomy_scale),
                (1.72, 0.52, 0.82),
            )
            maw_latch_mesh = mesh(
                "MiremawMawLatch",
                add_capsule(builder, 0.038 * anatomy_scale, 0.26 * anatomy_scale, anatomy_signal, 32, 8),
            )
            for side in (-1.0, 1.0):
                suffix = "L" if side < 0.0 else "R"
                add_node(
                    f"MiremawMawLatch{suffix}",
                    maw_latch_mesh,
                    (side * 0.28 * anatomy_scale, 0.92 * anatomy_scale, -0.57 * anatomy_scale),
                    rotation=(0.0, side * 0.52, 0.0),
                    extras={"surface": "anatomy_signal", "presentation_only": True},
                )
        elif name == "carrionbell":
            throat_collar_mesh = mesh(
                "CarrionbellThroatCollar",
                add_torus(builder, 0.34 * anatomy_scale, 0.058 * anatomy_scale, anatomy_signal, 40, 8),
            )
            throat_nodule_mesh = mesh(
                "CarrionbellThroatNodule",
                add_uv_sphere(builder, 0.13 * anatomy_scale, anatomy_signal, 24, 32),
            )
            add_node(
                "CarrionbellThroatCollar",
                throat_collar_mesh,
                (0.0, 1.08 * anatomy_scale, -0.45 * anatomy_scale),
                rotation=(math.pi * 0.5, 0.0, 0.0),
                extras={"surface": "anatomy_signal", "presentation_only": True},
            )
            add_node(
                "CarrionbellThroatNodule",
                throat_nodule_mesh,
                (0.0, 1.08 * anatomy_scale, -0.49 * anatomy_scale),
                scale=(1.0, 0.72, 0.72),
                extras={"surface": "anatomy_signal", "presentation_only": True},
            )
        elif name == "rootweaver":
            add_anatomy_plate(
                "RootweaverRouteMask",
                0.22 * anatomy_scale,
                (0.0, 1.25 * anatomy_scale, -0.46 * anatomy_scale),
                (1.28, 0.8, 0.7),
            )
            route_keel_mesh = mesh(
                "RootweaverRouteKeel",
                add_capsule(builder, 0.052 * anatomy_scale, 0.66 * anatomy_scale, anatomy_signal, 32, 8),
            )
            route_tendril_mesh = mesh(
                "RootweaverRouteTendril",
                add_capsule(builder, 0.035 * anatomy_scale, 0.38 * anatomy_scale, anatomy_signal, 32, 8),
            )
            add_node(
                "RootweaverRouteKeel",
                route_keel_mesh,
                (0.0, 1.24 * anatomy_scale, -0.60 * anatomy_scale),
                extras={"surface": "anatomy_signal", "presentation_only": True},
            )
            for side in (-1.0, 1.0):
                suffix = "L" if side < 0.0 else "R"
                add_node(
                    f"RootweaverRouteTendril{suffix}",
                    route_tendril_mesh,
                    (side * 0.19 * anatomy_scale, 1.15 * anatomy_scale, -0.44 * anatomy_scale),
                    rotation=(0.0, side * 0.34, side * 0.3),
                    extras={"surface": "anatomy_signal", "presentation_only": True},
                )
        elif name == "thornback":
            add_anatomy_plate(
                "ThornbackFaceShield",
                0.25 * anatomy_scale,
                (0.0, 1.22 * anatomy_scale, -0.48 * anatomy_scale),
                (1.42, 1.0, 0.72),
            )
            face_barb_mesh = mesh(
                "ThornbackFaceBarb",
                add_tapered_cylinder_mesh(
                    builder,
                    0.065 * anatomy_scale,
                    0.018 * anatomy_scale,
                    0.42 * anatomy_scale,
                    anatomy_signal,
                ),
            )
            add_node(
                "ThornbackFaceBarb",
                face_barb_mesh,
                (0.0, 1.46 * anatomy_scale, -0.5 * anatomy_scale),
                extras={"surface": "anatomy_signal", "presentation_only": True},
            )
        elif name == "ashmantle":
            thermal_collar_mesh = mesh(
                "AshmantleThermalCollar",
                add_torus(builder, 0.29 * anatomy_scale, 0.052 * anatomy_scale, anatomy_signal, 40, 8),
            )
            thermal_core_mesh = mesh(
                "AshmantleThermalCore",
                add_uv_sphere(builder, 0.14 * anatomy_scale, anatomy_signal, 24, 32),
            )
            add_node(
                "AshmantleThermalCollar",
                thermal_collar_mesh,
                (0.0, 0.98 * anatomy_scale, -0.48 * anatomy_scale),
                rotation=(math.pi * 0.5, 0.0, 0.0),
                extras={"surface": "anatomy_signal", "presentation_only": True},
            )
            add_node(
                "AshmantleThermalCore",
                thermal_core_mesh,
                (0.0, 0.99 * anatomy_scale, -0.52 * anatomy_scale),
                scale=(1.05, 0.78, 0.7),
                extras={"surface": "anatomy_signal", "presentation_only": True},
            )

    torso = add_node("Torso", extras={"surface": "layered_wet_chitin"})
    core_scale, segment_scale, segment_taper = spec["body_profile"]
    add_node("TorsoCore", mesh_ids["Core"], (0.0, 0.92, 0.08), scale=core_scale, parent=torso, extras={"release_material_family": "chitin"})
    for index in range(4):
        z = -0.62 + index * 0.43
        segment_width = max(0.72, float(segment_scale[0]) - index * segment_taper)
        segment_depth = max(0.78, float(segment_scale[2]) - index * segment_taper * 0.8)
        add_node(f"TorsoSegment{index}", mesh_ids["Segment"], (0.0, 0.89 - index * 0.024, z), scale=(segment_width, segment_scale[1], segment_depth), parent=torso)
        add_node(f"{name.capitalize()}ThoraxRib{index}", mesh_ids["ShellPlate"], (0.0, 1.35 - index * 0.045, z), rotation=(0.0, 0.0, 0.03 * (index - 1)), scale=(1.0, 1.0, 0.84), parent=torso, extras={"surface": "layered_shell_break"} if index == 1 else None)
        add_node(f"{name.capitalize()}ThoraxFastener{index}L", mesh_ids["Fastener"], (-0.56, 1.18, z), parent=torso)
        add_node(f"{name.capitalize()}ThoraxFastener{index}R", mesh_ids["Fastener"], (0.56, 1.18, z), parent=torso)
        # Paired surface veins break up the shared torso kit at close camera
        # distance. They are deliberately thin and recessed into the front
        # face, adding living vascular rhythm without becoming gameplay
        # sockets, collision geometry, or a new runtime dependency.
        for side in (-1.0, 1.0):
            suffix = "L" if side < 0.0 else "R"
            add_node(f"{name.capitalize()}TorsoSurfaceVein{index}{suffix}", mesh_ids["SurfaceVein"], (side * 0.31, 1.19, z - 0.54), rotation=(0.0, 0.0, side * 0.08), scale=(1.0, 1.0, 0.72), parent=torso, extras={"surface": "vascular_surface_detail"})
    add_node(
        "VentralSheath",
        mesh_ids["VentralSheath"],
        (0.0, 1.02, -0.04),
        rotation=(math.pi * 0.5, 0.0, 0.0),
        scale=(1.0, 1.0, 0.84),
        parent=torso,
        extras={"surface": "continuous_ventral_shell"},
    )
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
        add_node("MiremawGillSternum", mesh_ids["MiremawGillSternum"], (0.0, 1.40, -0.40), rotation=(0.16, 0.0, 0.0), scale=(0.92, 1.0, 0.86), extras={"surface": "gill_sternum"}, parent=torso)
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
        # Close the signal organ into the upper mantle with a folded root
        # collar. It is owned by the resonator socket so the existing
        # resonator animation carries the attachment as one living part.
        add_node("CarrionbellResonatorRootCollar", mesh_ids["CarrionbellResonatorRootCollar"], (0.0, -0.16, 0.18), rotation=(0.18, 0.0, 0.0), scale=(1.08, 0.94, 0.96), extras={"surface": "resonator_root_attachment"}, parent=resonator)
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
        add_node(
            "RootweaverThoraxCollar",
            mesh_ids["RootweaverThoraxCollar"],
            (0.0, 1.34, -0.42),
            rotation=(0.12, 0.0, 0.0),
            scale=(0.94, 1.0, 0.86),
            extras={"surface": "route_controller_thorax_collar"},
            parent=torso,
        )
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

    add_package_anatomy()
    add_node("ProductionAssetMarker", None, extras={"asset_contract": spec["asset_id"], "source": "original_shared_mesh_builder"})
    node_index = {node["name"]: index for index, node in enumerate(nodes)}

    def animation(animation_name: str, channels: list[tuple[str, str, list[float], list[float]]]) -> dict:
        samplers: list[dict] = []
        entries: list[dict] = []
        used_targets: set[tuple[str, str]] = set()
        types = {"translation": ("VEC3", 3), "rotation": ("VEC4", 4)}
        for target_name, path, times, values in channels:
            target_key = (target_name, path)
            if target_key in used_targets:
                raise ValueError(f"{name}/{animation_name}: duplicate animation target {target_name}.{path}")
            if target_name not in node_index:
                raise ValueError(f"{name}/{animation_name}: missing animation target {target_name}")
            used_targets.add(target_key)
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
        # Replace the shared walk-node placeholder with the talon's authored
        # rest-relative retreat arc; one node/path must have one owner.
        retreat_channels = [channel for channel in retreat_channels if channel[0] != "RoofleaperTalonsL"]
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
        walk_channels = [channel for channel in walk_channels if channel[0] != "RootweaverArmL"]
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
        walk_channels = [channel for channel in walk_channels if channel[0] != "MiremawWaterFinL"]
        retreat_channels = [channel for channel in retreat_channels if channel[0] != "MiremawWaterFinL"]
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
        walk_channels = [channel for channel in walk_channels if channel[0] != "GlassmothWingL0"]
        retreat_channels = [channel for channel in retreat_channels if channel[0] != "GlassmothWingL0"]
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
        walk_channels = [channel for channel in walk_channels if channel[0] != "CarrionbellMantle"]
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
        walk_channels = [channel for channel in walk_channels if channel[0] != "ThornbackSpineL"]
        retreat_channels = [channel for channel in retreat_channels if channel[0] != "ThornbackSpineL"]
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
        walk_channels = [channel for channel in walk_channels if channel[0] != "AshmantleHeatLouverL"]
        retreat_channels = [channel for channel in retreat_channels if channel[0] != "AshmantleHeatLouverL"]
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
    required_nodes = [
        root_name,
        "Torso",
        "TorsoCore",
        "VentralSheath",
        "OrganicDorsalPlate",
        *spec["signature_nodes"],
        *ANATOMY_BASE_NODES,
        *spec["focal_nodes"],
        "ProductionAssetMarker",
    ]
    socket_nodes = {
        node["name"]: node.get("extras", {}).get("socket_type")
        for node in nodes
        if node.get("extras", {}).get("socket_type")
    }
    document = {
        "asset": {"version": "2.0", "generator": f"Project Ironwright deterministic {spec['display']} HD builder"},
        "scene": 0,
        "scenes": [{"name": spec["display"], "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "textures": [{"sampler": 0, "source": index} for index in range(len(TEXTURE_ORDER))],
        "images": [
            {"uri": TEXTURE_URIS[key], "name": f"Project Ironwright organic {key}"}
            for key in TEXTURE_ORDER
        ],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": spec["asset_id"],
            "asset_quality": "authored_high_definition",
            "texture_resolution": TEXTURE_SIZE,
            "material_contract": "textured_metallic_roughness_pbr",
            "surface_profile": SURFACE_PROFILE,
            "required_nodes": required_nodes,
            "authored_anatomy_nodes": [*ANATOMY_BASE_NODES, *spec["focal_nodes"]],
            "animation_clips": ANIMATION_CLIPS,
            "deterministic_build": True,
            "presentation_only": True,
            "collision": False,
            "gameplay_state": "none",
            "source_type": "original_project_ironwright_deterministic_mesh_builder",
        },
    }
    output_path = ASSET_ROOT / name / f"{name}.gltf"
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    texture_paths = {
        key: (output_path.parent / uri).resolve()
        for key, uri in TEXTURE_URIS.items()
    }
    missing_textures = [str(path) for path in texture_paths.values() if not path.is_file()]
    if missing_textures:
        raise FileNotFoundError(f"{name}: shared organic textures missing: {missing_textures}")
    position_accessors = [
        primitive["attributes"]["POSITION"]
        for mesh_entry in meshes
        for primitive in mesh_entry["primitives"]
    ]
    index_accessors = [
        primitive["indices"]
        for mesh_entry in meshes
        for primitive in mesh_entry["primitives"]
    ]
    bounds_min, bounds_max = aggregate_geometry_bounds(nodes, meshes, builder)
    dimensions = [bounds_max[index] - bounds_min[index] for index in range(3)]
    manifest = {
        "asset_id": spec["asset_id"],
        "asset_quality": "authored_high_definition",
        "quality": "authored_high_definition",
        "display_name": spec["display"],
        "runtime_model": f"res://assets/{name}/{name}.gltf",
        "runtime_path": f"res://assets/{name}/{name}.gltf",
        "textures": {
            key: f"res://assets/organic_families/textures/{Path(uri).name}"
            for key, uri in TEXTURE_URIS.items()
        },
        "texture_resolution": TEXTURE_SIZE,
        "material_workflow": "metallic_roughness_pbr",
        "surface_profile": SURFACE_PROFILE,
        "normal_scale_range": [0.08, 0.34],
        "material_names": [material["name"] for material in materials],
        "emissive_materials": [material["name"] for material in materials if "emissiveTexture" in material],
        "source": "res://assets/organic_families/source/build_authored_organic_assets.py",
        "source_builder": "res://assets/organic_families/source/build_authored_organic_assets.py",
        "source_type": "original_project_ironwright_deterministic_mesh_builder",
        "provenance": "Original Project Ironwright organic asset; deterministic source geometry and shared textures; no third-party runtime art.",
        "third_party_assets": [],
        "world_scale_m": round(max(dimensions), 6),
        "aggregate_bounds": {"min": bounds_min, "max": bounds_max},
        "source_visual_scale": 1.0,
        "runtime_visual_scale": 1.0,
        "presentation_only": True,
        "collision": False,
        "gameplay_state": "none",
        "skins": 0,
        "deterministic_build": True,
        "required_accessors": ["POSITION", "NORMAL", "TEXCOORD_0", "TANGENT"],
        "indexed_primitives": True,
        "unique_node_names": True,
        "unique_animation_target_paths": True,
        "required_nodes": required_nodes,
        "stable_nodes": required_nodes,
        "authored_anatomy_nodes": [*ANATOMY_BASE_NODES, *spec["focal_nodes"]],
        "socket_contract": socket_nodes,
        "animation_clips": ANIMATION_CLIPS,
        "geometry_metrics": {
            "node_count": len(nodes),
            "mesh_count": len(meshes),
            "primitive_count": sum(len(mesh_entry["primitives"]) for mesh_entry in meshes),
            "vertex_count": sum(builder.accessors[index]["count"] for index in position_accessors),
            "triangle_count": sum(builder.accessors[index]["count"] for index in index_accessors) // 3,
        },
        "artifact_hashes": {
            "source_builder_sha256": hashlib.sha256(Path(__file__).read_bytes()).hexdigest().upper(),
            "runtime_model_sha256": hashlib.sha256(output_path.read_bytes()).hexdigest().upper(),
            **{
                f"{key}_sha256": hashlib.sha256(path.read_bytes()).hexdigest().upper()
                for key, path in texture_paths.items()
            },
        },
    }
    manifest_path = ASSET_ROOT.parent / "data" / f"{name}_asset_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {output_path} with {len(nodes)} named nodes and {len(meshes)} meshes")


def main() -> None:
    for name, spec in FAMILIES.items():
        build_family(name, spec)


if __name__ == "__main__":
    main()
