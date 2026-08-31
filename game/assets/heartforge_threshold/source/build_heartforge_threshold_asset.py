"""Build the original high-definition Heartforge refuge threshold.

The threshold is a presentation-only civic landmark.  It consolidates the
release threshold, route arch, and gate-sensor silhouette into one deterministic
authored package while deliberately leaving collision, navigation, power, and
gameplay state to the existing world runtime.
"""

from __future__ import annotations

import base64
import json
import math
import struct
import sys
import zlib
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parent
ASSET_ROOT = SOURCE_DIR.parents[1]
sys.path.insert(0, str(ASSET_ROOT / "bulwark" / "source"))
from build_bulwark_asset import (  # noqa: E402
    BufferBuilder,
    add_beveled_box,
    add_cylinder,
    add_ellipsoid,
    add_uv_sphere,
    quat,
)


ASSET_DIR = ASSET_ROOT / "heartforge_threshold"
OUTPUT_PATH = ASSET_DIR / "heartforge_threshold.gltf"
MANIFEST_PATH = ASSET_ROOT.parent / "data" / "heartforge_threshold_asset_manifest.json"
TEXTURE_SIZE = 1024
TEXTURE_PATHS = {
    "base_color": ASSET_DIR / "heartforge_threshold_base_color.png",
    "normal": ASSET_DIR / "heartforge_threshold_normal.png",
    "orm": ASSET_DIR / "heartforge_threshold_orm.png",
    "emissive": ASSET_DIR / "heartforge_threshold_emissive.png",
}

ASSET_ID = "heartforge.threshold.v1"
ROOT_NAME = "AuthoredHeartforgeThreshold"
CLEAR_OPENING_WIDTH = 7.38
CLEAR_OPENING_HEIGHT = 3.03
CLEAR_OPENING_EDGES = (-3.69, 3.69)
WORLD_PLACEMENT_HINT = (0.0, 0.0, -5.8)

MATERIAL_NAMES = [
    "Threshold foundation iron",
    "Threshold forged shell",
    "Threshold warm copper",
    "Threshold weathered plate",
    "Threshold route amber",
    "Threshold service cyan",
]

STABLE_NODES = [
    ROOT_NAME,
    "ThresholdStructure",
    "LeftPillar",
    "RightPillar",
    "ThresholdPillarL",
    "ThresholdPillarR",
    "LeftThresholdFoot",
    "RightThresholdFoot",
    "ThresholdFootL",
    "ThresholdFootR",
    "ThresholdLintel",
    "ThresholdCrown",
    "RouteThresholdAmberBand",
    "ThresholdServiceLayer",
    "ThresholdServicePanel",
    "LeftServicePanel",
    "RightServicePanel",
    "ThresholdSignalLayer",
    "LeftRouteLamp",
    "RightRouteLamp",
    "ThresholdLamp00",
    "ThresholdLamp01",
    "ThresholdLamp02",
    "LeftRouteSensor",
    "RightRouteSensor",
    "ThresholdRouteMarker",
    "ThresholdOrganicMachineLayer",
    "ProductionAssetMarker",
]

AUTHORED_DETAIL_NODES = [
    "LeftPillarOuterShield",
    "RightPillarOuterShield",
    "LeftPillarCopperSpine",
    "RightPillarCopperSpine",
    "LeftServicePanel",
    "RightServicePanel",
    "LeftRouteLamp",
    "RightRouteLamp",
    "ThresholdCenterLamp",
    "LeftRouteSensor",
    "RightRouteSensor",
    "ThresholdCrown",
    "ThresholdCrownKeystone",
    "RouteThresholdAmberBand",
    "ThresholdRouteMarker",
    "LeftThresholdRootAssembly",
    "RightThresholdRootAssembly",
    "LeftThresholdConduit",
    "RightThresholdConduit",
]


def _png_chunk(chunk_type: bytes, data: bytes) -> bytes:
    payload = chunk_type + data
    return struct.pack(">I", len(data)) + payload + struct.pack(">I", zlib.crc32(payload) & 0xFFFFFFFF)


def _write_png_rgba(path: Path, pixel) -> None:
    raw = bytearray()
    for y in range(TEXTURE_SIZE):
        raw.append(0)
        for x in range(TEXTURE_SIZE):
            raw.extend(pixel(x, y))
    header = struct.pack(">IIBBBBB", TEXTURE_SIZE, TEXTURE_SIZE, 8, 6, 0, 0, 0)
    png = (
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", header)
        + _png_chunk(b"IDAT", zlib.compress(bytes(raw), level=9))
        + _png_chunk(b"IEND", b"")
    )
    path.write_bytes(png)


def _texture_noise(x: int, y: int, salt: int = 0) -> int:
    value = (x * 374761393 + y * 668265263 + salt * 2246822519 + 0x7A43E1B9) & 0xFFFFFFFF
    value = ((value ^ (value >> 13)) * 1274126177) & 0xFFFFFFFF
    return (value ^ (value >> 16)) & 0xFF


def _patina_mask(x: int, y: int) -> float:
    """Sparse, softly warped oxidation without a visible tile grid."""
    warp_x = x + 31.0 * math.sin(y * 0.0051) + 9.0 * math.sin((x + y) * 0.0033)
    warp_y = y + 23.0 * math.sin(x * 0.0047) - 7.0 * math.sin((x - y) * 0.0037)
    field = (
        math.sin(warp_x * 0.013 + warp_y * 0.009)
        + math.sin(warp_x * 0.031 - warp_y * 0.019)
        + math.sin(warp_x * 0.007 + warp_y * 0.047)
    )
    threshold = 2.28 + 0.23 * (_texture_noise(x // 11, y // 11, 17) / 255.0)
    return max(0.0, min(1.0, (abs(field) - threshold) * 2.5))


def _scratch_mask(x: int, y: int) -> float:
    cell_x = x // 143
    cell_y = y // 71
    seed = _texture_noise(cell_x, cell_y, 29)
    if seed < 231:
        return 0.0
    local_x = x - cell_x * 143
    local_y = y - cell_y * 71
    start_x = 9.0 + 52.0 * _texture_noise(cell_x, cell_y, 30) / 255.0
    start_y = 7.0 + 49.0 * _texture_noise(cell_x, cell_y, 31) / 255.0
    length = 32.0 + 67.0 * _texture_noise(cell_x, cell_y, 32) / 255.0
    slope = (_texture_noise(cell_x, cell_y, 33) / 255.0 - 0.5) * 0.22
    along = local_x - start_x
    if along < 0.0 or along > length:
        return 0.0
    distance = abs(local_y - (start_y + slope * along))
    return max(0.0, min(1.0, 1.4 - distance))


def _build_texture_set() -> None:
    """Write original threshold-specific industrial PBR maps."""
    def channel(value: float) -> int:
        return max(0, min(255, round(value)))

    def base_color(x: int, y: int) -> tuple[int, int, int, int]:
        grain = (_texture_noise(x, y, 1) - 128) / 128.0
        brushed = 2.4 * math.sin(y * 0.41 + math.sin(x * 0.007) * 2.1)
        brushed += 0.9 * math.sin(y * 1.17 + x * 0.013)
        hammered = 1.6 * math.sin(x * 0.027 + y * 0.019) * math.sin(x * 0.011 - y * 0.023)
        patina = _patina_mask(x, y)
        scratch = _scratch_mask(x, y)
        base = [183.0 + brushed + hammered + grain * 7.0,
                190.0 + brushed * 0.83 + hammered * 0.72 + grain * 6.0,
                188.0 + brushed * 0.74 + hammered * 0.61 + grain * 5.0]
        copper_stain = (155.0, 123.0, 92.0)
        for index in range(3):
            base[index] = base[index] * (1.0 - patina * 0.34) + copper_stain[index] * patina * 0.34
            base[index] = base[index] * (1.0 - scratch * 0.36) + 218.0 * scratch * 0.36
        return (channel(base[0]), channel(base[1]), channel(base[2]), 255)

    def normal(x: int, y: int) -> tuple[int, int, int, int]:
        # A neutral-blue tangent-space surface with fine forged striations,
        # broad hammered variation, and rare shallow scar slopes.
        phase = y * 0.47 + math.sin(x * 0.0065) * 2.35 + math.sin((x + y) * 0.014) * 0.8
        jitter_x = (_texture_noise(x + 2, y, 4) - _texture_noise(x - 2, y, 4)) / 255.0
        jitter_y = (_texture_noise(x, y + 2, 5) - _texture_noise(x, y - 2, 5)) / 255.0
        hammer_x = math.cos(x * 0.028 + y * 0.017) * math.sin(x * 0.012 - y * 0.021)
        hammer_y = math.sin(x * 0.028 + y * 0.017) * math.cos(x * 0.012 - y * 0.021)
        scratch = _scratch_mask(x, y)
        dx = 0.011 * math.cos((x + y) * 0.025) + jitter_x * 0.02 + hammer_x * 0.009 + scratch * 0.022
        dy = 0.026 * math.cos(phase) + jitter_y * 0.02 + hammer_y * 0.009 - scratch * 0.014
        nx, ny, nz = -dx, -dy, 1.0
        length = math.sqrt(nx * nx + ny * ny + nz * nz)
        return (
            round((nx / length * 0.5 + 0.5) * 255),
            round((ny / length * 0.5 + 0.5) * 255),
            round((nz / length * 0.5 + 0.5) * 255),
            255,
        )

    def orm(x: int, y: int) -> tuple[int, int, int, int]:
        grain = (_texture_noise(x, y, 7) - 128) / 128.0
        brushed = math.sin(y * 0.23 + math.sin(x * 0.006) * 2.2 + math.sin((x + y) * 0.011))
        patina = _patina_mask(x, y)
        scratch = _scratch_mask(x, y)
        ao = 237.0 + grain * 5.0 + brushed * 2.0 - patina * 13.0
        roughness = 158.0 + grain * 13.0 + brushed * 5.0 + patina * 24.0 - scratch * 15.0
        metallic = 231.0 + grain * 6.0 - brushed * 2.0 - patina * 27.0 + scratch * 8.0
        return (channel(ao), channel(roughness), channel(metallic), 255)

    def emissive(x: int, y: int) -> tuple[int, int, int, int]:
        grain = (_texture_noise(x, y, 11) - 128) / 128.0
        route_pulse = 0.65 + 0.35 * math.sin((x + y * 0.37) * 0.031)
        scan = 0.82 + 0.18 * math.sin(y * 0.29 + math.sin(x * 0.009) * 0.9)
        intensity = 220.0 + route_pulse * 23.0 + scan * 8.0 + grain * 2.0
        if _texture_noise(x // 4, y // 4, 12) > 253 and _texture_noise(x, y, 13) > 212:
            intensity -= 18.0
        value = channel(intensity)
        return (value, value, value, 255)

    _write_png_rgba(TEXTURE_PATHS["base_color"], base_color)
    _write_png_rgba(TEXTURE_PATHS["normal"], normal)
    _write_png_rgba(TEXTURE_PATHS["orm"], orm)
    _write_png_rgba(TEXTURE_PATHS["emissive"], emissive)


def build() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    _build_texture_set()

    builder = BufferBuilder()
    foundation, shell, copper, plate, amber, cyan = range(6)

    def material(
        name: str,
        color: Sequence[float],
        metallic: float,
        roughness: float,
        emissive: Sequence[float] | None = None,
    ) -> dict:
        entry = {
            "name": name,
            "pbrMetallicRoughness": {
                "baseColorFactor": [*color, 1.0],
                "baseColorTexture": {"index": 0},
                "metallicFactor": metallic,
                "roughnessFactor": roughness,
                "metallicRoughnessTexture": {"index": 2},
            },
            "normalTexture": {"index": 1, "scale": 0.72},
            "occlusionTexture": {"index": 2, "strength": 0.82},
        }
        if emissive is not None:
            entry["emissiveFactor"] = list(emissive)
            entry["emissiveTexture"] = {"index": 3}
        return entry

    materials = [
        material(MATERIAL_NAMES[0], (0.032, 0.041, 0.043), 0.78, 0.58),
        material(MATERIAL_NAMES[1], (0.13, 0.17, 0.18), 0.82, 0.42),
        material(MATERIAL_NAMES[2], (0.42, 0.205, 0.09), 0.64, 0.53),
        material(MATERIAL_NAMES[3], (0.25, 0.30, 0.31), 0.72, 0.46),
        material(MATERIAL_NAMES[4], (0.48, 0.22, 0.055), 0.26, 0.28, (0.58, 0.16, 0.018)),
        material(MATERIAL_NAMES[5], (0.03, 0.28, 0.31), 0.28, 0.23, (0.025, 0.37, 0.42)),
    ]

    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int, int, int]) -> int:
        position, normal, uv, tangent, indices, material_index = geometry
        meshes.append({
            "name": name,
            "primitives": [{
                "attributes": {
                    "POSITION": position,
                    "NORMAL": normal,
                    "TEXCOORD_0": uv,
                    "TANGENT": tangent,
                },
                "indices": indices,
                "material": material_index,
            }],
        })
        return len(meshes) - 1

    mesh_ids = {
        "pillar": mesh("Threshold main pillar", add_beveled_box(builder, (0.42, 3.18, 0.58), shell, 0.10)),
        "foot": mesh("Threshold foundation foot", add_beveled_box(builder, (1.18, 0.18, 1.08), foundation, 0.075)),
        "foot_toe": mesh("Threshold foundation toe", add_beveled_box(builder, (0.48, 0.16, 1.34), plate, 0.06)),
        "outer_shield": mesh("Threshold outer shield", add_beveled_box(builder, (0.20, 2.22, 0.88), plate, 0.075)),
        "copper_spine": mesh("Threshold copper spine", add_beveled_box(builder, (0.11, 2.54, 0.76), copper, 0.035)),
        "rib": mesh("Threshold manufactured rib", add_beveled_box(builder, (0.16, 0.16, 0.94), copper, 0.035)),
        "lintel": mesh("Threshold load lintel", add_beveled_box(builder, (8.12, 0.30, 0.62), shell, 0.095)),
        "lintel_case": mesh("Threshold layered lintel case", add_beveled_box(builder, (7.72, 0.18, 0.86), plate, 0.065)),
        "amber_band": mesh("Threshold amber route band", add_beveled_box(builder, (3.35, 0.16, 0.08), amber, 0.03)),
        "crown_beam": mesh("Threshold crown beam", add_beveled_box(builder, (2.55, 0.24, 0.66), shell, 0.075)),
        "crown_plate": mesh("Threshold crown plate", add_beveled_box(builder, (1.12, 0.34, 0.78), copper, 0.085)),
        "crown_fin": mesh("Threshold crown thermal fin", add_beveled_box(builder, (0.13, 0.62, 0.48), plate, 0.04)),
        "service_panel": mesh("Threshold service panel", add_beveled_box(builder, (0.34, 0.74, 0.12), foundation, 0.04)),
        "service_face": mesh("Threshold service face", add_beveled_box(builder, (0.055, 0.48, 0.26), cyan, 0.018)),
        "service_louver": mesh("Threshold service louver", add_beveled_box(builder, (0.06, 0.10, 0.23), copper, 0.018)),
        "lintel_panel": mesh("Threshold lintel service panel", add_beveled_box(builder, (2.08, 0.24, 0.10), foundation, 0.035)),
        "panel_trace": mesh("Threshold panel signal trace", add_beveled_box(builder, (0.46, 0.055, 0.025), cyan, 0.012)),
        "lamp_housing": mesh("Threshold route lamp housing", add_cylinder(builder, 0.09, 0.20, foundation, 28)),
        "lamp_lens": mesh("Threshold route lamp lens", add_uv_sphere(builder, 0.088, amber, 18, 28)),
        "sensor_housing": mesh("Threshold route sensor housing", add_beveled_box(builder, (0.34, 0.34, 0.24), foundation, 0.06)),
        "sensor_lens": mesh("Threshold route sensor lens", add_uv_sphere(builder, 0.082, cyan, 18, 28)),
        "route_marker": mesh("Threshold route marker", add_beveled_box(builder, (0.76, 0.12, 0.09), amber, 0.025)),
        "pipe": mesh("Threshold machine-grown conduit", add_cylinder(builder, 0.07, 1.0, copper, 28)),
        "pipe_clamp": mesh("Threshold conduit clamp", add_cylinder(builder, 0.105, 0.12, plate, 28)),
        "root_shoe": mesh("Threshold machine root shoe", add_ellipsoid(builder, (0.42, 0.17, 0.54), foundation, 18, 36)),
        "root_knuckle": mesh("Threshold machine root knuckle", add_uv_sphere(builder, 0.115, copper, 16, 28)),
        "bolt": mesh("Threshold exposed fastener", add_cylinder(builder, 0.052, 0.045, plate, 24)),
    }

    nodes: list[dict] = []
    node_names: set[str] = set()

    def node(
        name: str,
        mesh_id: int | None = None,
        translation: tuple[float, float, float] | None = None,
        children: list[int] | None = None,
        extras: dict | None = None,
        rotation: tuple[float, float, float] | None = None,
        scale: tuple[float, float, float] | None = None,
    ) -> int:
        if name in node_names:
            raise ValueError(f"Duplicate authored node name: {name}")
        node_names.add(name)
        value: dict = {"name": name}
        if mesh_id is not None:
            value["mesh"] = mesh_id
        if translation is not None:
            value["translation"] = list(translation)
        if rotation is not None:
            value["rotation"] = quat(rotation)
        if scale is not None:
            value["scale"] = list(scale)
        if children:
            value["children"] = children
        if extras:
            value["extras"] = extras
        nodes.append(value)
        return len(nodes) - 1

    def cylinder_between_xy(
        name: str,
        start: tuple[float, float, float],
        end: tuple[float, float, float],
        mesh_id: int,
        extras: dict | None = None,
    ) -> int:
        delta_x = end[0] - start[0]
        delta_y = end[1] - start[1]
        length = math.sqrt(delta_x * delta_x + delta_y * delta_y)
        center = ((start[0] + end[0]) * 0.5, (start[1] + end[1]) * 0.5, (start[2] + end[2]) * 0.5)
        return node(
            name,
            mesh_id,
            center,
            extras=extras,
            rotation=(0.0, 0.0, -math.atan2(delta_x, delta_y)),
            scale=(1.0, length, 1.0),
        )

    # Exact route throat: x=+-3.9 with 0.42 m pillars leaves 7.38 m
    # between the inner faces.  The 0.30 m lintel centred at y=3.18 leaves
    # 3.03 m vertical clearance.  Decorative detail stays outside that box.
    pillar_groups: list[int] = []
    foot_groups: list[int] = []
    for side in (-1.0, 1.0):
        side_name = "Left" if side < 0.0 else "Right"
        suffix = "L" if side < 0.0 else "R"
        pillar_x = side * 3.9

        foot_mesh_children = [
            node(f"ThresholdFoot{suffix}", mesh_ids["foot"], (pillar_x, 0.14, 0.0), extras={"presentation_role": "threshold_foundation"}),
            node(f"{side_name}ThresholdFootToe", mesh_ids["foot_toe"], (side * 4.26, 0.18, 0.0)),
        ]
        for shoe_index, z in enumerate((-0.44, 0.44)):
            foot_mesh_children.append(node(
                f"{side_name}ThresholdRootShoe{shoe_index:02d}",
                mesh_ids["root_shoe"],
                (side * 4.38, 0.20, z),
                rotation=(0.0, side * (0.12 + shoe_index * 0.07), 0.0),
            ))
        foot_groups.append(node(f"{side_name}ThresholdFoot", None, children=foot_mesh_children, extras={"assembly_side": side_name.lower()}))

        pillar_children = [
            node(f"ThresholdPillar{suffix}", mesh_ids["pillar"], (pillar_x, 1.59, 0.0), extras={"presentation_role": "clear_opening_edge"}),
            node(f"{side_name}PillarOuterShield", mesh_ids["outer_shield"], (side * 4.17, 1.72, 0.0), rotation=(0.0, 0.0, side * 0.025)),
            node(f"{side_name}PillarCopperSpine", mesh_ids["copper_spine"], (side * 4.295, 1.67, 0.0), rotation=(0.0, 0.0, side * 0.018)),
        ]
        for rib_index in range(5):
            pillar_children.append(node(
                f"{side_name}PillarRib{rib_index:02d}",
                mesh_ids["rib"],
                (side * 4.23, 0.68 + rib_index * 0.48, 0.0),
                rotation=(0.0, 0.0, side * (0.02 if rib_index % 2 == 0 else -0.015)),
            ))
        for bolt_index, y in enumerate((0.42, 1.06, 1.70, 2.34, 2.82)):
            pillar_children.append(node(
                f"{side_name}PillarBolt{bolt_index:02d}",
                mesh_ids["bolt"],
                (side * 3.9, y, -0.315),
                rotation=(math.pi * 0.5, 0.0, 0.0),
            ))
        pillar_groups.append(node(f"{side_name}Pillar", None, children=pillar_children, extras={"assembly_side": side_name.lower()}))

    crown_children = [
        node("ThresholdCrownBeamLeft", mesh_ids["crown_beam"], (-2.72, 3.56, 0.0), rotation=(0.0, 0.0, -0.16)),
        node("ThresholdCrownBeamRight", mesh_ids["crown_beam"], (2.72, 3.56, 0.0), rotation=(0.0, 0.0, 0.16)),
        node("ThresholdCrownBeamInnerLeft", mesh_ids["crown_beam"], (-0.96, 3.84, 0.0), rotation=(0.0, 0.0, -0.12)),
        node("ThresholdCrownBeamInnerRight", mesh_ids["crown_beam"], (0.96, 3.84, 0.0), rotation=(0.0, 0.0, 0.12)),
        node("ThresholdCrownKeystone", mesh_ids["crown_plate"], (0.0, 3.98, 0.0), extras={"presentation_role": "refuge_civic_keystone"}),
    ]
    for fin_index in range(5):
        crown_children.append(node(
            f"ThresholdCrownFin{fin_index:02d}",
            mesh_ids["crown_fin"],
            (-0.72 + fin_index * 0.36, 4.42 + 0.06 * abs(2 - fin_index), 0.0),
            rotation=(0.0, 0.0, (fin_index - 2) * 0.055),
        ))
    crown = node("ThresholdCrown", None, children=crown_children, extras={"presentation_role": "layered_industrial_organic_silhouette"})

    lintel_children = [
        node("ThresholdLintelCase", mesh_ids["lintel_case"], (0.0, 0.21, 0.0)),
        node("RouteThresholdAmberBand", mesh_ids["amber_band"], (0.0, 0.13, -0.47), extras={"presentation_signal": "amber_route"}),
    ]
    lintel = node("ThresholdLintel", mesh_ids["lintel"], (0.0, 3.18, 0.0), children=lintel_children, extras={"presentation_role": "clear_opening_header"})
    structure = node("ThresholdStructure", None, children=[*foot_groups, *pillar_groups, lintel, crown], extras={"clear_opening_width_m": CLEAR_OPENING_WIDTH, "clear_opening_height_m": CLEAR_OPENING_HEIGHT})

    service_children: list[int] = []
    service_panel_groups: list[int] = []
    for side in (-1.0, 1.0):
        side_name = "Left" if side < 0.0 else "Right"
        panel_children = [
            node(f"{side_name}ServicePanelShell", mesh_ids["service_panel"], (side * 4.35, 1.74, -0.04)),
            node(f"{side_name}ServicePanelFace", mesh_ids["service_face"], (side * 4.35, 1.74, -0.115)),
        ]
        for louver_index in range(4):
            panel_children.append(node(
                f"{side_name}ServiceLouver{louver_index:02d}",
                mesh_ids["service_louver"],
                (side * 4.35, 1.56 + louver_index * 0.12, -0.155),
            ))
        service_panel_groups.append(node(
            f"{side_name}ServicePanel",
            None,
            children=panel_children,
            extras={"presentation_role": "service_diagnostic", "assembly_side": side_name.lower()},
        ))

    lintel_panel_children = []
    for trace_index in range(3):
        lintel_panel_children.append(node(
            f"ThresholdPanelSignalTrace{trace_index:02d}",
            mesh_ids["panel_trace"],
            (-0.58 + trace_index * 0.58, 0.0, -0.065),
        ))
    lintel_panel = node("ThresholdServicePanel", mesh_ids["lintel_panel"], (0.0, 3.18, -0.34), children=lintel_panel_children, extras={"presentation_role": "threshold_service_hierarchy"})
    service_children.extend([lintel_panel, *service_panel_groups])
    service_layer = node("ThresholdServiceLayer", None, children=service_children, extras={"presentation_only": True})

    signal_children: list[int] = []
    lamp_positions = (-3.0, 0.0, 3.0)
    lamp_group_names = ("LeftRouteLamp", "ThresholdCenterLamp", "RightRouteLamp")
    for lamp_index, (lamp_x, group_name) in enumerate(zip(lamp_positions, lamp_group_names)):
        lamp_parts = [
            node(f"ThresholdLampHousing{lamp_index:02d}", mesh_ids["lamp_housing"], (lamp_x, 3.18, -0.41), rotation=(math.pi * 0.5, 0.0, 0.0)),
            node(f"ThresholdLamp{lamp_index:02d}", mesh_ids["lamp_lens"], (lamp_x, 3.18, -0.54), extras={"presentation_signal": "amber_route"}),
        ]
        signal_children.append(node(group_name, None, children=lamp_parts, extras={"presentation_role": "route_lamp"}))

    for side in (-1.0, 1.0):
        side_name = "Left" if side < 0.0 else "Right"
        sensor_parts = [
            node(f"{side_name}RouteSensorHousing", mesh_ids["sensor_housing"], (side * 4.17, 2.58, -0.43)),
            node(f"{side_name}RouteSensorLens", mesh_ids["sensor_lens"], (side * 4.17, 2.58, -0.58), extras={"presentation_signal": "service_cyan"}),
        ]
        signal_children.append(node(f"{side_name}RouteSensor", None, children=sensor_parts, extras={"presentation_role": "route_sensor", "assembly_side": side_name.lower()}))

    route_marker_children = [
        node("ThresholdRouteMarkerLeft", mesh_ids["route_marker"], (-0.46, 3.53, -0.47), rotation=(0.0, 0.0, -0.48)),
        node("ThresholdRouteMarkerRight", mesh_ids["route_marker"], (0.46, 3.53, -0.47), rotation=(0.0, 0.0, 0.48)),
    ]
    signal_children.append(node("ThresholdRouteMarker", None, children=route_marker_children, extras={"presentation_signal": "amber_route"}))
    signal_layer = node("ThresholdSignalLayer", None, children=signal_children, extras={"presentation_only": True})

    organic_children: list[int] = []
    for side in (-1.0, 1.0):
        side_name = "Left" if side < 0.0 else "Right"
        root_children: list[int] = []
        root_paths = [
            ((side * 4.48, 0.18, 0.34), (side * 4.68, 1.16, 0.34)),
            ((side * 4.68, 1.16, 0.34), (side * 4.53, 2.15, 0.34)),
            ((side * 4.53, 2.15, 0.34), (side * 4.66, 3.14, 0.34)),
        ]
        for segment_index, (start, end) in enumerate(root_paths):
            root_children.append(cylinder_between_xy(
                f"{side_name}ThresholdRootConduit{segment_index:02d}",
                start,
                end,
                mesh_ids["pipe"],
                {"presentation_role": "machine_grown_conduit"},
            ))
            root_children.append(node(
                f"{side_name}ThresholdRootKnuckle{segment_index:02d}",
                mesh_ids["root_knuckle"],
                end,
            ))
        organic_children.append(node(
            f"{side_name}ThresholdRootAssembly",
            None,
            children=root_children,
            extras={"presentation_role": "layered_industrial_organic_silhouette", "assembly_side": side_name.lower()},
        ))

        # A second, straighter service conduit reads as deliberate machine
        # infrastructure beside the more root-like outer braid.
        conduit_children = [
            node(f"{side_name}ThresholdConduitPipe", mesh_ids["pipe"], (side * 4.02, 1.14, 0.43)),
            node(f"{side_name}ThresholdConduitClampLow", mesh_ids["pipe_clamp"], (side * 4.02, 0.72, 0.43)),
            node(f"{side_name}ThresholdConduitClampHigh", mesh_ids["pipe_clamp"], (side * 4.02, 1.56, 0.43)),
        ]
        organic_children.append(node(
            f"{side_name}ThresholdConduit",
            None,
            children=conduit_children,
            extras={"presentation_role": "service_conduit", "assembly_side": side_name.lower()},
        ))
    organic_layer = node("ThresholdOrganicMachineLayer", None, children=organic_children, extras={"presentation_only": True, "silhouette_language": "layered_industrial_organic"})

    marker = node("ProductionAssetMarker", None, extras={"asset_id": ASSET_ID, "presentation_only": True, "collision": False, "gameplay_state": "none"})
    root = node(
        ROOT_NAME,
        None,
        children=[structure, service_layer, signal_layer, organic_layer, marker],
        extras={
            "ironwright_asset_id": ASSET_ID,
            "asset_quality": "authored_high_definition",
            "presentation_only": True,
            "collision": False,
            "gameplay_state": "none",
            "manufactured_surface_profile": "textured_chamfered_high_definition",
            "material_contract": "textured_metallic_roughness_pbr",
            "clear_opening_width_m": CLEAR_OPENING_WIDTH,
            "clear_opening_inner_edges_x": list(CLEAR_OPENING_EDGES),
            "clear_opening_height_m": CLEAR_OPENING_HEIGHT,
            "world_placement_hint": list(WORLD_PLACEMENT_HINT),
        },
    )

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Heartforge threshold asset builder"},
        "scene": 0,
        "scenes": [{"name": ROOT_NAME, "nodes": [root]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "samplers": [{
            "name": "Threshold repeating PBR sampler",
            "magFilter": 9729,
            "minFilter": 9987,
            "wrapS": 10497,
            "wrapT": 10497,
        }],
        "images": [
            {"name": "Threshold base color", "uri": TEXTURE_PATHS["base_color"].name},
            {"name": "Threshold tangent-space normal", "uri": TEXTURE_PATHS["normal"].name},
            {"name": "Threshold occlusion roughness metallic", "uri": TEXTURE_PATHS["orm"].name},
            {"name": "Threshold emissive mask", "uri": TEXTURE_PATHS["emissive"].name},
        ],
        "textures": [
            {"name": "Threshold base color", "sampler": 0, "source": 0},
            {"name": "Threshold tangent-space normal", "sampler": 0, "source": 1},
            {"name": "Threshold occlusion roughness metallic", "sampler": 0, "source": 2},
            {"name": "Threshold emissive mask", "sampler": 0, "source": 3},
        ],
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {
            "ironwright_asset_id": ASSET_ID,
            "root_name": ROOT_NAME,
            "required_nodes": STABLE_NODES,
            "authored_detail_nodes": AUTHORED_DETAIL_NODES,
            "material_contract": "textured_metallic_roughness_pbr",
            "texture_resolution": TEXTURE_SIZE,
            "presentation_only": True,
            "collision": False,
            "gameplay_state": "none",
            "clear_opening": {
                "width_m": CLEAR_OPENING_WIDTH,
                "height_m": CLEAR_OPENING_HEIGHT,
                "inner_edges_x": list(CLEAR_OPENING_EDGES),
            },
            "world_placement_hint": list(WORLD_PLACEMENT_HINT),
            "animation_clips": [],
        },
    }
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")

    manifest = {
        "asset_id": ASSET_ID,
        "asset_quality": "authored_high_definition",
        "root_name": ROOT_NAME,
        "runtime_scene": "res://assets/heartforge_threshold/heartforge_threshold.gltf",
        "textures": {
            "base_color": "res://assets/heartforge_threshold/heartforge_threshold_base_color.png",
            "normal": "res://assets/heartforge_threshold/heartforge_threshold_normal.png",
            "orm": "res://assets/heartforge_threshold/heartforge_threshold_orm.png",
            "emissive": "res://assets/heartforge_threshold/heartforge_threshold_emissive.png",
        },
        "texture_resolution": TEXTURE_SIZE,
        "material_workflow": "metallic_roughness_pbr",
        "source_builder": "game/assets/heartforge_threshold/source/build_heartforge_threshold_asset.py",
        "source_type": "original_project_ironwright_shared_mesh_builder",
        "manufactured_surface_profile": "textured_chamfered_high_definition",
        "third_party_assets": [],
        "presentation_only": True,
        "collision": False,
        "gameplay_state": "none",
        "world_placement_hint": list(WORLD_PLACEMENT_HINT),
        "clear_opening": {
            "width_m": CLEAR_OPENING_WIDTH,
            "height_m": CLEAR_OPENING_HEIGHT,
            "inner_edges_x": list(CLEAR_OPENING_EDGES),
        },
        "stable_nodes": STABLE_NODES,
        "authored_detail_nodes": AUTHORED_DETAIL_NODES,
        "material_names": MATERIAL_NAMES,
        "animation_clips": [],
    }
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(
        f"Wrote {OUTPUT_PATH} and {MANIFEST_PATH} with "
        f"{len(nodes)} unique nodes, {len(meshes)} meshes, and {len(materials)} PBR materials"
    )


if __name__ == "__main__":
    build()
