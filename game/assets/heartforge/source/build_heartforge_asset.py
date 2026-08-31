"""Build the original high-definition Heartforge primary shell.

The asset owns the permanent machine silhouette and stable presentation
sockets. Progression tiers, adaptation retrofits, damage memory, lighting and
the interaction/collision contract remain runtime systems.
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


ASSET_DIR = ASSET_ROOT / "heartforge"
OUTPUT_PATH = ASSET_DIR / "heartforge.gltf"
TEXTURE_SIZE = 1024
TEXTURE_PATHS = {
    "base_color": ASSET_DIR / "heartforge_base_color.png",
    "normal": ASSET_DIR / "heartforge_normal.png",
    "orm": ASSET_DIR / "heartforge_orm.png",
    "emissive": ASSET_DIR / "heartforge_emissive.png",
}


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
    value = (x * 374761393 + y * 668265263 + salt * 2246822519 + 0x48F01A7D) & 0xFFFFFFFF
    value = ((value ^ (value >> 13)) * 1274126177) & 0xFFFFFFFF
    return (value ^ (value >> 16)) & 0xFF


def _irregular_spot(x: int, y: int, cell_size: int, salt: int, cutoff: int) -> float:
    """Return a sparse, softly irregular spot without a repeating panel grid."""
    cell_x = x // cell_size
    cell_y = y // cell_size
    seed = _texture_noise(cell_x, cell_y, salt)
    if seed < cutoff:
        return 0.0
    local_x = x - cell_x * cell_size
    local_y = y - cell_y * cell_size
    center_x = cell_size * (0.24 + 0.52 * _texture_noise(cell_x, cell_y, salt + 1) / 255.0)
    center_y = cell_size * (0.24 + 0.52 * _texture_noise(cell_x, cell_y, salt + 2) / 255.0)
    radius_x = cell_size * (0.055 + 0.11 * _texture_noise(cell_x, cell_y, salt + 3) / 255.0)
    radius_y = cell_size * (0.045 + 0.095 * _texture_noise(cell_x, cell_y, salt + 4) / 255.0)
    angle = math.tau * _texture_noise(cell_x, cell_y, salt + 5) / 255.0
    cosine = math.cos(angle)
    sine = math.sin(angle)
    delta_x = local_x - center_x
    delta_y = local_y - center_y
    spot_x = (delta_x * cosine - delta_y * sine) / max(radius_x, 1.0)
    spot_y = (delta_x * sine + delta_y * cosine) / max(radius_y, 1.0)
    distance = spot_x * spot_x + spot_y * spot_y
    edge = 0.13 * math.sin(local_x * 0.31 + local_y * 0.17 + seed)
    edge += 0.07 * (_texture_noise(x // 3, y // 3, salt + 6) / 255.0 - 0.5)
    return max(0.0, min(1.0, (1.0 + edge - distance) * 3.2))


def _scratch_mask(x: int, y: int) -> float:
    cell_width = 128
    cell_height = 64
    cell_x = x // cell_width
    cell_y = y // cell_height
    seed = _texture_noise(cell_x, cell_y, 31)
    if seed < 232:
        return 0.0
    local_x = x - cell_x * cell_width
    local_y = y - cell_y * cell_height
    start_x = 8.0 + 44.0 * _texture_noise(cell_x, cell_y, 32) / 255.0
    start_y = 8.0 + 48.0 * _texture_noise(cell_x, cell_y, 33) / 255.0
    length = 24.0 + 68.0 * _texture_noise(cell_x, cell_y, 34) / 255.0
    slope = (_texture_noise(cell_x, cell_y, 35) / 255.0 - 0.5) * 0.18
    along = local_x - start_x
    if along < 0.0 or along > length:
        return 0.0
    distance = abs(local_y - (start_y + along * slope))
    return max(0.0, min(1.0, 1.35 - distance))


def _build_texture_set() -> None:
    """Write original, dependency-free Heartforge industrial PBR maps."""
    def channel(value: float) -> int:
        return max(0, min(255, round(value)))

    def base_color(x: int, y: int) -> tuple[int, int, int, int]:
        grain = (_texture_noise(x, y, 1) - 128) / 128.0
        brushed = 1.7 * math.sin(y * 0.31 + math.sin(x * 0.007) * 1.9)
        brushed += 0.75 * math.sin(y * 1.23 + x * 0.014)
        warped_x = x + 21.0 * math.sin(y * 0.0043) + 8.0 * math.sin((x + y) * 0.0027)
        warped_y = y + 17.0 * math.sin(x * 0.0051) - 6.0 * math.sin((x - y) * 0.0039)
        pitted = _irregular_spot(x, y, 79, 41, 210)
        oxidized = _irregular_spot(x + 37, y + 19, 137, 53, 216)
        scratched = _scratch_mask(x, y)
        soot = max(0.0, math.sin(warped_x * 0.004 - warped_y * 0.006) - 0.78) * 8.0
        base = (
            190 + brushed + grain * 7 - soot,
            197 + brushed * 0.84 + grain * 6 - soot,
            194 + brushed * 0.76 + grain * 5 - soot,
        )
        oxide_mix = oxidized * (0.54 + 0.12 * grain)
        pit_mix = pitted * (0.42 + 0.10 * grain)
        result = tuple(
            base[index] * (1.0 - oxide_mix) + target * oxide_mix
            for index, target in enumerate((161.0, 137.0, 113.0))
        )
        result = tuple(
            result[index] * (1.0 - pit_mix) + target * pit_mix
            for index, target in enumerate((144.0, 150.0, 147.0))
        )
        if scratched > 0.0:
            result = tuple(value * (1.0 - scratched * 0.42) + 216.0 * scratched * 0.42 for value in result)
        return (channel(result[0]), channel(result[1]), channel(result[2]), 255)

    def normal(x: int, y: int) -> tuple[int, int, int, int]:
        # Fine forged-metal grooves and sparse dents retain a neutral-blue
        # tangent-space average without introducing panel seams or tiling cues.
        phase = y * 0.49 + math.sin(x * 0.007) * 2.2 + math.sin((x + y) * 0.016) * 0.9
        jitter_x = (_texture_noise(x + 2, y, 5) - _texture_noise(x - 2, y, 5)) / 255.0
        jitter_y = (_texture_noise(x, y + 2, 6) - _texture_noise(x, y - 2, 6)) / 255.0
        dent_field = (
            math.sin(x * 0.019 + y * 0.013)
            + math.sin(x * 0.041 - y * 0.026)
            + math.sin(x * 0.008 + y * 0.047)
        )
        dent = 0.018 if dent_field > 2.78 and _texture_noise(x, y, 7) > 218 else 0.0
        dx = 0.012 * math.cos((x + y) * 0.027) + jitter_x * 0.022 + dent
        dy = 0.026 * math.cos(phase) + 0.010 * math.cos(y * 1.31 + x * 0.017) + jitter_y * 0.021 - dent
        nx, ny, nz = -dx, -dy, 1.0
        length = math.sqrt(nx * nx + ny * ny + nz * nz)
        return (
            round((nx / length * 0.5 + 0.5) * 255),
            round((ny / length * 0.5 + 0.5) * 255),
            round((nz / length * 0.5 + 0.5) * 255),
            255,
        )

    def orm(x: int, y: int) -> tuple[int, int, int, int]:
        grain = (_texture_noise(x, y, 8) - 128) / 128.0
        brushed = math.sin(y * 0.21 + math.sin(x * 0.006) * 2.1 + math.sin((x + y) * 0.012))
        pitted = _irregular_spot(x, y, 79, 41, 210)
        oxidized = _irregular_spot(x + 37, y + 19, 137, 53, 216)
        ao = 238 + grain * 5 + brushed * 2
        roughness = 163 + grain * 12 + brushed * 5
        metallic = 231 + grain * 6 - brushed * 2
        ao -= pitted * 18 + oxidized * 7
        roughness += pitted * 22 + oxidized * 15
        metallic -= pitted * 12 + oxidized * 19
        return (channel(ao), channel(roughness), channel(metallic), 255)

    def emissive(x: int, y: int) -> tuple[int, int, int, int]:
        grain = (_texture_noise(x, y, 11) - 128) / 128.0
        scan = 0.85 * math.sin(y * 0.29 + x * 0.005 + math.sin(x * 0.008))
        service_wear = 1.15 * math.sin(x * 0.018 + y * 0.012)
        intensity = 234 + scan + service_wear + grain * 1.7
        if _texture_noise(x // 3, y // 3, 12) > 253 and _texture_noise(x, y, 13) > 210:
            intensity -= 15
        value = channel(intensity)
        return (value, value, value, 255)

    _write_png_rgba(TEXTURE_PATHS["base_color"], base_color)
    _write_png_rgba(TEXTURE_PATHS["normal"], normal)
    _write_png_rgba(TEXTURE_PATHS["orm"], orm)
    _write_png_rgba(TEXTURE_PATHS["emissive"], emissive)


def build() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    _build_texture_set()
    builder = BufferBuilder()
    dark, iron, cladding, rust, heat, cyan = range(6)

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
            "normalTexture": {"index": 1, "scale": 0.68},
            "occlusionTexture": {"index": 2, "strength": 0.8},
        }
        if emissive is not None:
            entry["emissiveFactor"] = list(emissive)
            entry["emissiveTexture"] = {"index": 3}
        return entry

    materials = [
        material("Heartforge foundation", (0.035, 0.045, 0.047), 0.72, 0.56),
        material("Heartforge iron shell", (0.14, 0.18, 0.19), 0.78, 0.42),
        material("Heartforge cladding", (0.28, 0.34, 0.35), 0.7, 0.38),
        material("Heartforge weathered copper", (0.36, 0.18, 0.095), 0.48, 0.66),
        material("Heartforge thermal core", (0.48, 0.16, 0.035), 0.24, 0.34, (0.18, 0.03, 0.006)),
        material("Heartforge service cyan", (0.035, 0.28, 0.3), 0.28, 0.24, (0.03, 0.3, 0.34)),
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
        "foundation": mesh("Foundation", add_cylinder(builder, 2.55, 0.7, dark, 32)),
        "housing": mesh("CoreHousing", add_ellipsoid(builder, (1.75, 1.7, 1.75), iron, 22, 48)),
        "furnace": mesh("FurnaceCore", add_ellipsoid(builder, (1.1, 1.25, 1.1), heat, 22, 48)),
        "ring_lower": mesh("LowerRing", add_cylinder(builder, 2.15, 0.22, rust, 32)),
        "ring_upper": mesh("UpperRing", add_cylinder(builder, 2.08, 0.22, rust, 32)),
        "cladding": mesh("CoreCladdingSegment", add_beveled_box(builder, (0.34, 2.42, 0.62), cladding, 0.06)),
        "cladding_cap": mesh("CoreCladdingCap", add_beveled_box(builder, (0.38, 0.12, 0.68), rust, 0.025)),
        "louver_core": mesh("CoreServiceLouverCore", add_beveled_box(builder, (0.72, 0.92, 0.1), dark, 0.025)),
        "louver": mesh("CoreServiceLouver", add_beveled_box(builder, (0.12, 0.48, 0.08), cyan, 0.018)),
        "inspection": mesh("CoreInspectionPort", add_beveled_box(builder, (0.56, 0.64, 0.1), dark, 0.03)),
        "rail": mesh("CoreSignalRail", add_cylinder(builder, 0.08, 1.8, cyan, 28)),
        "collar": mesh("HeartforgeUpperCollar", add_cylinder(builder, 1.48, 0.18, rust, 32)),
        "fin": mesh("HeartforgeFocalRadialFin", add_beveled_box(builder, (0.16, 0.58, 0.34), iron, 0.035)),
        "control": mesh("HeartforgeFocalControlFace", add_beveled_box(builder, (1.22, 0.68, 0.12), dark, 0.045)),
        "lens": mesh("HeartforgeFocalSignalLens", add_uv_sphere(builder, 0.075, cyan, 16, 24)),
        "cable": mesh("HeartforgeFocalCableBranch", add_cylinder(builder, 0.055, 1.1, rust, 24)),
        "stack": mesh("ForgeStack", add_cylinder(builder, 0.36, 2.6, iron, 28)),
        "bench": mesh("ForgeBench", add_beveled_box(builder, (3.0, 0.35, 1.8), iron, 0.12)),
        "plate": mesh("AssemblyPlate", add_beveled_box(builder, (2.18, 0.18, 1.06), dark, 0.045)),
        "plate_glow": mesh("AssemblyPlateGlow", add_beveled_box(builder, (1.68, 0.06, 0.72), cyan, 0.018)),
        "slot": mesh("AssemblyPlateSlot", add_beveled_box(builder, (0.1, 0.025, 0.42), dark, 0.008)),
        "rib": mesh("Rib", add_beveled_box(builder, (0.24, 2.1, 0.42), rust, 0.035)),
        "coolant_pipe": mesh("HeartforgeCoolantPipe", add_cylinder(builder, 0.065, 1.25, cyan, 20)),
        "service_latch": mesh("HeartforgeServiceLatch", add_beveled_box(builder, (0.12, 0.18, 0.38), cyan, 0.018)),
        "conduit_clip": mesh("HeartforgeConduitClip", add_beveled_box(builder, (0.18, 0.12, 0.24), cladding, 0.02)),
        "thermal_shroud": mesh("HeartforgeThermalShroud", add_beveled_box(builder, (0.18, 0.46, 0.54), iron, 0.035)),
        "thermal_shroud_cap": mesh("HeartforgeThermalShroudCap", add_beveled_box(builder, (0.22, 0.08, 0.6), rust, 0.022)),
        "bench_brace": mesh("ForgeBenchBrace", add_beveled_box(builder, (0.18, 0.34, 0.52), rust, 0.03)),
        "foundation_bolt": mesh("HeartforgeFoundationBolt", add_cylinder(builder, 0.12, 0.14, cladding, 20)),
        "service_coolant_stack": mesh("ForgeCoolantStack", add_cylinder(builder, 0.18, 3.0, iron, 28)),
        "service_pressure_pipe": mesh("ForgePressurePipe", add_cylinder(builder, 0.12, 1.92, rust, 24)),
        "service_pump": mesh("ForgePump", add_beveled_box(builder, (0.72, 0.6, 0.52), dark, 0.08)),
        "service_clamp": mesh("ForgeTopClamp", add_beveled_box(builder, (0.36, 0.18, 0.52), rust, 0.04)),
        "service_cabinet": mesh("ForgeControlCabinet", add_beveled_box(builder, (0.38, 0.92, 0.88), dark, 0.07)),
        "diagnostic_panel": mesh("ForgeDiagnosticPanel", add_beveled_box(builder, (0.055, 0.48, 0.56), cyan, 0.018)),
    }

    nodes: list[dict] = []
    node_name_counts: dict[str, int] = {}

    def node(
        name: str,
        mesh_id: int | None = None,
        translation: tuple[float, float, float] | None = None,
        children: list[int] | None = None,
        extras: dict | None = None,
        rotation: tuple[float, float, float] | None = None,
    ) -> int:
        occurrence = node_name_counts.get(name, 0) + 1
        node_name_counts[name] = occurrence
        unique_name = name if occurrence == 1 else f"{name}{occurrence:02d}"
        value: dict = {"name": unique_name}
        if mesh_id is not None:
            value["mesh"] = mesh_id
        if translation is not None:
            value["translation"] = list(translation)
        if rotation is not None:
            value["rotation"] = quat(rotation)
        if children:
            value["children"] = children
        if extras:
            value["extras"] = extras
        nodes.append(value)
        return len(nodes) - 1

    foundation = node("Foundation", mesh_ids["foundation"], (0.0, 0.35, 0.0), extras={"socket_type": "heartforge_anchor"})
    housing_children = [node("CoreHousingShell", mesh_ids["housing"]), node("FurnaceCore", mesh_ids["furnace"])]
    housing_children.extend([
        node("HeartforgeCoolantPipeLeft", mesh_ids["coolant_pipe"], (-1.72, 0.0, -0.52)),
        node("HeartforgeCoolantPipeRight", mesh_ids["coolant_pipe"], (1.72, 0.0, -0.52)),
        node("HeartforgeServiceLatchLeft", mesh_ids["service_latch"], (-1.74, -0.5, -0.52)),
        node("HeartforgeServiceLatchRight", mesh_ids["service_latch"], (1.74, -0.5, -0.52)),
        node("HeartforgeConduitClipLeft", mesh_ids["conduit_clip"], (-1.74, 0.32, -0.52)),
        node("HeartforgeConduitClipRight", mesh_ids["conduit_clip"], (1.74, 0.32, -0.52)),
    ])
    housing = node("CoreHousing", None, (0.0, 2.0, 0.0), housing_children, {"socket_type": "primary_reactor_shell"})
    node("LowerRing", mesh_ids["ring_lower"], (0.0, 1.0, 0.0))
    node("UpperRing", mesh_ids["ring_upper"], (0.0, 2.9, 0.0))

    cladding_children: list[int] = []
    for segment in range(8):
        # The segment mesh is already centred around its authored panel; the
        # transforms create the octagonal manufactured shell language.
        angle = 2.0 * math.pi * segment / 8.0 + math.pi * 0.125
        position = (math.cos(angle) * 1.7, 2.0, math.sin(angle) * 1.7)
        cladding_children.append(node("CoreCladdingSegment%02d" % segment, mesh_ids["cladding"], position, rotation=(0.0, -angle, 0.0)))
        cladding_children.append(node("CoreCladdingCap%02d" % segment, mesh_ids["cladding_cap"], (position[0], position[1] + 1.08, position[2]), rotation=(0.0, -angle, 0.0)))
    cladding_children.append(node("CoreServiceLouverCore", mesh_ids["louver_core"], (0.0, 2.12, 1.84)))
    for index in range(4):
        cladding_children.append(node("CoreServiceLouver%02d" % index, mesh_ids["louver"], (-0.27 + index * 0.18, 2.12, 1.91)))
    cladding_children.append(node("CoreInspectionPort", mesh_ids["inspection"], (0.0, 1.12, 1.88)))
    cladding_children.append(node("CoreSignalRailLeft", mesh_ids["rail"], (-1.86, 2.05, 0.0)))
    cladding_children.append(node("CoreSignalRailRight", mesh_ids["rail"], (1.86, 2.05, 0.0)))
    cladding = node("CoreCladdingDetail", None, children=cladding_children, extras={"socket_type": "manufactured_cladding"})

    focal_children = [node("HeartforgeUpperCollar", mesh_ids["collar"], (0.0, 3.78, 0.0))]
    for index in range(8):
        angle = 2.0 * math.pi * index / 8.0 + math.pi * 0.125
        focal_children.append(node("HeartforgeFocalRadialFin%02d" % index, mesh_ids["fin"], (math.cos(angle) * 1.45, 3.78, math.sin(angle) * 1.45), rotation=(0.0, -angle, 0.0)))
    focal_children.append(node("HeartforgeFocalControlFace", mesh_ids["control"], (0.0, 2.7, 1.92), extras={"socket_type": "player_facing_control"}))
    for index in range(3):
        focal_children.append(node("HeartforgeFocalSignalLens%02d" % index, mesh_ids["lens"], (-0.34 + index * 0.34, 2.73, 2.01), extras={"socket_type": "service_signal"}))
    focal_children.append(node("HeartforgeFocalCableBranchLeft", mesh_ids["cable"], (-1.26, 2.66, 1.88), rotation=(0.0, 0.0, math.pi * 0.5)))
    focal_children.append(node("HeartforgeFocalCableBranchRight", mesh_ids["cable"], (1.26, 2.66, 1.88), rotation=(0.0, 0.0, math.pi * 0.5)))
    focal_children.extend([
        node("HeartforgeThermalShroud00", mesh_ids["thermal_shroud"], (-0.86, 3.25, 0.0)),
        node("HeartforgeThermalShroud01", mesh_ids["thermal_shroud"], (0.86, 3.25, 0.0)),
        node("HeartforgeThermalShroudCap00", mesh_ids["thermal_shroud_cap"], (-0.86, 3.52, 0.0)),
        node("HeartforgeThermalShroudCap01", mesh_ids["thermal_shroud_cap"], (0.86, 3.52, 0.0)),
    ])
    focal = node("HeartforgeFocalDetail", None, children=focal_children, extras={"socket_type": "reactor_control_layer"})

    west_stack = node("WestStack", mesh_ids["stack"], (-1.85, 1.7, 0.0))
    east_stack = node("EastStack", mesh_ids["stack"], (1.85, 1.7, 0.0))
    bench_children = [node("AssemblyPlate", mesh_ids["plate"], (0.0, 0.24, 0.0)), node("AssemblyPlateGlow", mesh_ids["plate_glow"], (0.0, 0.36, 0.0))]
    bench_children.extend([
        node("ForgeBenchBraceLeft", mesh_ids["bench_brace"], (-1.18, 0.0, 0.0)),
        node("ForgeBenchBraceRight", mesh_ids["bench_brace"], (1.18, 0.0, 0.0)),
    ])
    for slot in range(3):
        bench_children.append(node("AssemblyPlateSlot%02d" % slot, mesh_ids["slot"], (-0.48 + slot * 0.48, 0.4, 0.0)))
    bench = node("ForgeBench", mesh_ids["bench"], (0.0, 0.48, 3.25), bench_children, {"socket_type": "manual_fabrication_surface"})

    ribs: list[int] = []
    for index in range(8):
        angle = 2.0 * math.pi * index / 8.0
        ribs.append(node("Rib%02d" % index, mesh_ids["rib"], (math.cos(angle) * 2.35, 1.75, math.sin(angle) * 2.35), rotation=(0.0, -angle, 0.0)))

    # This authored service layer replaces the static, model-local
    # VerticalSliceForgeArt dressing. Side-qualified names make every piece
    # addressable while leaving lights, damage, tiers, and gameplay at runtime.
    service_children: list[int] = []
    for side in (-1.0, 1.0):
        side_name = "Left" if side < 0.0 else "Right"
        service_children.append(node(
            f"ForgeCoolantStack{side_name}",
            mesh_ids["service_coolant_stack"],
            (side * 2.15, 1.6, 0.9),
            rotation=(0.0, 0.0, side * 0.12),
            extras={"service_hardware": "coolant_stack", "assembly_side": side_name.lower()},
        ))
        service_children.append(node(
            f"ForgePressurePipe{side_name}",
            mesh_ids["service_pressure_pipe"],
            (side * 1.7, 2.2, -1.667565178),
            rotation=(1.05, 0.0, side * 0.18),
            extras={"service_hardware": "pressure_line", "assembly_side": side_name.lower()},
        ))
        service_children.append(node(
            f"ForgePump{side_name}",
            mesh_ids["service_pump"],
            (side * 2.15, 0.72, 1.2),
            extras={"service_hardware": "coolant_pump", "assembly_side": side_name.lower()},
        ))
    for index in range(5):
        angle = -1.1 + float(index) * 0.55
        service_children.append(node(
            "ForgeTopClamp%02d" % index,
            mesh_ids["service_clamp"],
            (math.cos(angle) * 1.9, 3.45, math.sin(angle) * 1.9),
            rotation=(0.0, -angle, 0.08),
            extras={"service_hardware": "upper_shell_clamp", "clamp_slot": index},
        ))
    service_children.append(node(
        "ForgeControlCabinet",
        mesh_ids["service_cabinet"],
        (-2.04, 1.12, -0.22),
        extras={"service_hardware": "control_cabinet"},
    ))
    service_children.append(node(
        "ForgeDiagnosticPanel",
        mesh_ids["diagnostic_panel"],
        (-2.258, 1.16, -0.22),
        extras={"service_hardware": "diagnostic_surface", "presentation_signal": "service_cyan"},
    ))
    service_detail = node(
        "VerticalSliceForgeArt",
        None,
        children=service_children,
        extras={"presentation_only": True, "authored_static_detail": True},
    )
    foundation_hardware: list[int] = []
    for index, position in enumerate(((-1.92, 0.83, -1.55), (1.92, 0.83, -1.55), (-1.92, 0.83, 1.55), (1.92, 0.83, 1.55))):
        foundation_hardware.append(node("HeartforgeFoundationBolt%02d" % index, mesh_ids["foundation_bolt"], position))
    marker = node("ProductionAssetMarker", None, extras={"asset_id": "heartforge.core.v1", "presentation_only": True})
    root = node("HeartforgeModel", None, children=[foundation, housing, cladding, focal, west_stack, east_stack, bench, *ribs, service_detail, *foundation_hardware, marker], extras={"ironwright_asset_id": "heartforge.core.v1", "asset_quality": "authored_high_definition", "manufactured_surface_profile": "textured_chamfered_high_definition", "socket_contract": "heartforge_anchor, primary_reactor_shell, player_facing_control, manual_fabrication_surface, service_hardware"})

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Heartforge asset builder"},
        "scene": 0,
        "scenes": [{"name": "Heartforge Core", "nodes": [root]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "samplers": [{
            "name": "Heartforge repeating PBR sampler",
            "magFilter": 9729,
            "minFilter": 9987,
            "wrapS": 10497,
            "wrapT": 10497,
        }],
        "images": [
            {"name": "Heartforge base color", "uri": TEXTURE_PATHS["base_color"].name},
            {"name": "Heartforge tangent-space normal", "uri": TEXTURE_PATHS["normal"].name},
            {"name": "Heartforge occlusion roughness metallic", "uri": TEXTURE_PATHS["orm"].name},
            {"name": "Heartforge emissive mask", "uri": TEXTURE_PATHS["emissive"].name},
        ],
        "textures": [
            {"name": "Heartforge base color", "sampler": 0, "source": 0},
            {"name": "Heartforge tangent-space normal", "sampler": 0, "source": 1},
            {"name": "Heartforge occlusion roughness metallic", "sampler": 0, "source": 2},
            {"name": "Heartforge emissive mask", "sampler": 0, "source": 3},
        ],
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {
            "ironwright_asset_id": "heartforge.core.v1",
            "required_nodes": ["HeartforgeModel", "Foundation", "CoreHousing", "FurnaceCore", "LowerRing", "UpperRing", "CoreCladdingDetail", "CoreServiceLouverCore", "CoreInspectionPort", "HeartforgeFocalDetail", "HeartforgeUpperCollar", "HeartforgeFocalControlFace", "HeartforgeFocalRadialFin00", "HeartforgeFocalSignalLens01", "ForgeBench", "AssemblyPlate", "HeartforgeCoolantPipeLeft", "HeartforgeThermalShroud00", "ForgeBenchBraceLeft", "HeartforgeFoundationBolt00", "VerticalSliceForgeArt", "ForgeCoolantStackLeft", "ForgeCoolantStackRight", "ForgePressurePipeLeft", "ForgePressurePipeRight", "ForgePumpLeft", "ForgePumpRight", "ForgeTopClamp00", "ForgeControlCabinet", "ForgeDiagnosticPanel", "ProductionAssetMarker"],
            "material_contract": "textured_metallic_roughness_pbr",
            "texture_resolution": TEXTURE_SIZE,
            "animation_clips": [],
        },
    }
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    build()
