"""Build the deterministic authored Mechromancer HD runtime package.

The neighboring Blender file remains an editable visual reference. This
dependency-free builder owns the game-facing glTF, external buffer, and four
original 1024 px PBR maps so repeated builds are byte-identical. The character
continues to use rigid animated nodes; this pass deliberately adds no skeleton.
"""

from __future__ import annotations

import json
import math
import struct
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Callable, Iterable, Sequence


ASSET_DIR = Path(__file__).resolve().parents[1]
GLTF_PATH = ASSET_DIR / "mechromancer.gltf"
BIN_PATH = ASSET_DIR / "mechromancer.bin"
ASSET_ID = "mechromancer.player.v1"
TEXTURE_SIZE = 1024
ROUNDED_BOX_SUBDIVISIONS = 4
ELLIPSOID_RINGS = 18
ELLIPSOID_SIDES = 36
CYLINDER_SIDES = 32
PIPE_SIDES = 24
TORUS_MAJOR_SEGMENTS = 36
TORUS_MINOR_SEGMENTS = 12
TEXTURES = {
    "base_color": "mechromancer_base_color.png",
    "normal": "mechromancer_normal.png",
    "orm": "mechromancer_orm.png",
    "emissive": "mechromancer_emissive.png",
}
CLIPS = ["Idle", "Walk", "Fire", "Work", "Upgrade", "Hit"]
REQUIRED_NODES = [
    "MechromancerModel", "FaceAnchor", "Hood", "HoodLowerSeam",
    "VisorBrow", "VisorMountLeft", "VisorMountRight", "ChestShell",
    "ChestArmorPlate", "FieldPack", "FieldCommsYoke",
    "FieldCommsAntenna", "FieldCommsBeacon", "FieldCommsCable",
    "ShoulderLamp", "LeftArm", "RightArm", "LeftLeg", "RightLeg",
    "CoatTailLeft", "CoatTailRight", "FieldTool", "WeakPistol",
    "PistolMuzzle", "ProductionAssetMarker",
]
Vec2 = tuple[float, float]
Vec3 = tuple[float, float, float]
Vec4 = tuple[float, float, float, float]


def clamp(value: float, low: float = 0.0, high: float = 1.0) -> float:
    return max(low, min(high, value))


def add3(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub3(a: Vec3, b: Vec3) -> Vec3:
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def mul3(a: Vec3, scalar: float) -> Vec3:
    return (a[0] * scalar, a[1] * scalar, a[2] * scalar)


def dot3(a: Vec3, b: Vec3) -> float:
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def cross3(a: Vec3, b: Vec3) -> Vec3:
    return (
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    )


def normalize3(value: Vec3, fallback: Vec3 = (0.0, 1.0, 0.0)) -> Vec3:
    length = math.sqrt(max(0.0, dot3(value, value)))
    if length <= 1.0e-9:
        return fallback
    return (value[0] / length, value[1] / length, value[2] / length)


def quat_euler_xyz(euler: Vec3) -> Vec4:
    x, y, z = (component * 0.5 for component in euler)
    cx, sx = math.cos(x), math.sin(x)
    cy, sy = math.cos(y), math.sin(y)
    cz, sz = math.cos(z), math.sin(z)
    return (
        sx * cy * cz - cx * sy * sz,
        cx * sy * cz + sx * cy * sz,
        cx * cy * sz - sx * sy * cz,
        cx * cy * cz + sx * sy * sz,
    )


def quat_mul(a: Vec4, b: Vec4) -> Vec4:
    ax, ay, az, aw = a
    bx, by, bz, bw = b
    return (
        aw * bx + ax * bw + ay * bz - az * by,
        aw * by - ax * bz + ay * bw + az * bx,
        aw * bz + ax * by - ay * bx + az * bw,
        aw * bw - ax * bx - ay * by - az * bz,
    )


def quat_from_y(direction: Vec3) -> Vec4:
    target = normalize3(direction)
    cosine = target[1]
    if cosine < -0.999999:
        return (1.0, 0.0, 0.0, 0.0)
    result = (target[2], 0.0, -target[0], 1.0 + cosine)
    length = math.sqrt(sum(component * component for component in result))
    return tuple(component / length for component in result)  # type: ignore[return-value]


def png_chunk(name: bytes, payload: bytes) -> bytes:
    crc = zlib.crc32(name + payload) & 0xFFFFFFFF
    return struct.pack(">I", len(payload)) + name + payload + struct.pack(">I", crc)


def write_png(path: Path, pixel: Callable[[int, int], tuple[int, int, int, int]]) -> None:
    rows = bytearray()
    for y in range(TEXTURE_SIZE):
        rows.append(0)
        for x in range(TEXTURE_SIZE):
            rows.extend(pixel(x, y))
    header = struct.pack(">IIBBBBB", TEXTURE_SIZE, TEXTURE_SIZE, 8, 6, 0, 0, 0)
    payload = b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", header)
    payload += png_chunk(b"IDAT", zlib.compress(bytes(rows), 9))
    payload += png_chunk(b"IEND", b"")
    path.write_bytes(payload)


def surface_height(u: float, v: float) -> float:
    """Broad authored relief that remains stable through tactical-camera mipmaps."""
    primary = math.sin((u * 2.10 + 0.13) * math.tau) * math.cos((v * 1.65 - 0.21) * math.tau) * 0.34
    secondary = math.cos((u * 3.70 - v * 2.35 + 0.17) * math.tau) * 0.14
    soft_scuff = math.sin((u * 6.20 + v * 4.70 + 0.31) * math.tau) * 0.055
    return primary + secondary + soft_scuff


def build_textures() -> None:
    def base_pixel(x: int, y: int) -> tuple[int, int, int, int]:
        u, v = (x + 0.5) / TEXTURE_SIZE, (y + 0.5) / TEXTURE_SIZE
        broad = surface_height(u, v)
        faded_patch = math.sin((u * 1.35 - 0.08) * math.tau) * math.sin((v * 1.15 + 0.19) * math.tau)
        edge_wear = math.cos((u * 4.20 + 0.30) * math.tau) * math.cos((v * 3.10 - 0.11) * math.tau)
        value = clamp(0.805 + broad * 0.055 + faded_patch * 0.025 + edge_wear * 0.012)
        warm = clamp(value * (0.992 + 0.010 * math.sin(v * math.tau * 2.2)))
        cool = clamp(value * (1.008 + 0.008 * math.cos(u * math.tau * 2.7)))
        return (round(value * 255), round(warm * 255), round(cool * 255), 255)

    def normal_pixel(x: int, y: int) -> tuple[int, int, int, int]:
        u, v = (x + 0.5) / TEXTURE_SIZE, (y + 0.5) / TEXTURE_SIZE
        step = 1.0 / TEXTURE_SIZE
        dx = (surface_height(u + step, v) - surface_height(u - step, v)) / (2.0 * step)
        dy = (surface_height(u, v + step) - surface_height(u, v - step)) / (2.0 * step)
        normal = normalize3((-dx * 0.014, -dy * 0.014, 1.0), (0.0, 0.0, 1.0))
        return tuple(round((component * 0.5 + 0.5) * 255) for component in normal) + (255,)  # type: ignore[return-value]

    def orm_pixel(x: int, y: int) -> tuple[int, int, int, int]:
        u, v = (x + 0.5) / TEXTURE_SIZE, (y + 0.5) / TEXTURE_SIZE
        relief = abs(surface_height(u, v))
        occlusion = clamp(0.94 - relief * 0.085 - (0.5 + 0.5 * math.sin((u * 1.3 + v * 1.1) * math.tau)) * 0.035)
        roughness = clamp(0.46 + (0.5 + 0.5 * math.sin((v * 1.20 - u * 0.55) * math.tau)) * 0.37 + relief * 0.055)
        metallic = clamp(0.50 + math.sin((u * 1.05 + 0.18) * math.tau) * math.cos((v * 0.85 - 0.12) * math.tau) * 0.44)
        return (round(occlusion * 255), round(roughness * 255), round(metallic * 255), 255)

    def emissive_pixel(x: int, y: int) -> tuple[int, int, int, int]:
        u, v = (x + 0.5) / TEXTURE_SIZE, (y + 0.5) / TEXTURE_SIZE
        band_distance = abs(v - 0.50)
        band = clamp(1.0 - max(0.0, band_distance - 0.055) / 0.035)
        left_node = clamp(1.0 - math.hypot((u - 0.24) / 0.11, (v - 0.24) / 0.10))
        right_node = clamp(1.0 - math.hypot((u - 0.76) / 0.12, (v - 0.76) / 0.11))
        intensity = clamp(max(band * 0.78, left_node * 0.92, right_node * 0.86))
        return (round(intensity * 45), round(intensity * 230), round(intensity * 255), 255)

    write_png(ASSET_DIR / TEXTURES["base_color"], base_pixel)
    write_png(ASSET_DIR / TEXTURES["normal"], normal_pixel)
    write_png(ASSET_DIR / TEXTURES["orm"], orm_pixel)
    write_png(ASSET_DIR / TEXTURES["emissive"], emissive_pixel)


class BufferBuilder:
    def __init__(self) -> None:
        self.data = bytearray()
        self.views: list[dict] = []
        self.accessors: list[dict] = []

    def _align(self) -> None:
        while len(self.data) % 4:
            self.data.append(0)

    def accessor(self, values: Sequence[float] | Sequence[int], component_type: int,
                 accessor_type: str, count: int, target: int | None = None,
                 minimum: Sequence[float] | None = None,
                 maximum: Sequence[float] | None = None) -> int:
        self._align()
        offset = len(self.data)
        if component_type == 5126:
            self.data.extend(struct.pack(f"<{len(values)}f", *values))
        elif component_type == 5123:
            self.data.extend(struct.pack(f"<{len(values)}H", *values))
        else:
            raise ValueError(component_type)
        view: dict = {"buffer": 0, "byteOffset": offset, "byteLength": len(self.data) - offset}
        if target is not None:
            view["target"] = target
        view_index = len(self.views)
        self.views.append(view)
        accessor: dict = {"bufferView": view_index, "componentType": component_type,
                          "count": count, "type": accessor_type}
        if minimum is not None:
            accessor["min"] = list(minimum)
        if maximum is not None:
            accessor["max"] = list(maximum)
        self.accessors.append(accessor)
        return len(self.accessors) - 1


@dataclass
class Geometry:
    positions: list[Vec3]
    normals: list[Vec3]
    uvs: list[Vec2]
    indices: list[int]


def flatten(values: Iterable[Sequence[float]]) -> list[float]:
    return [component for value in values for component in value]


def compute_tangents(geometry: Geometry) -> list[Vec4]:
    accumulated = [(0.0, 0.0, 0.0) for _ in geometry.positions]
    for offset in range(0, len(geometry.indices), 3):
        ia, ib, ic = geometry.indices[offset:offset + 3]
        p0, p1, p2 = geometry.positions[ia], geometry.positions[ib], geometry.positions[ic]
        uv0, uv1, uv2 = geometry.uvs[ia], geometry.uvs[ib], geometry.uvs[ic]
        e1, e2 = sub3(p1, p0), sub3(p2, p0)
        du1, dv1 = uv1[0] - uv0[0], uv1[1] - uv0[1]
        du2, dv2 = uv2[0] - uv0[0], uv2[1] - uv0[1]
        denominator = du1 * dv2 - du2 * dv1
        if abs(denominator) <= 1.0e-10:
            continue
        tangent = mul3(sub3(mul3(e1, dv2), mul3(e2, dv1)), 1.0 / denominator)
        for index in (ia, ib, ic):
            accumulated[index] = add3(accumulated[index], tangent)
    result: list[Vec4] = []
    for normal, tangent in zip(geometry.normals, accumulated):
        tangent = sub3(tangent, mul3(normal, dot3(normal, tangent)))
        if dot3(tangent, tangent) <= 1.0e-10:
            tangent = cross3((0.0, 1.0, 0.0), normal)
            if dot3(tangent, tangent) <= 1.0e-10:
                tangent = cross3((1.0, 0.0, 0.0), normal)
        tangent = normalize3(tangent, (1.0, 0.0, 0.0))
        result.append((tangent[0], tangent[1], tangent[2], 1.0))
    return result


def add_triangle(indices: list[int], positions: Sequence[Vec3], normals: Sequence[Vec3],
                 a: int, b: int, c: int) -> None:
    face = cross3(sub3(positions[b], positions[a]), sub3(positions[c], positions[a]))
    reference = normalize3(add3(add3(normals[a], normals[b]), normals[c]))
    indices.extend((a, c, b) if dot3(face, reference) < 0.0 else (a, b, c))


def rounded_box(size: Vec3, bevel: float = 0.035,
                subdivisions: int = ROUNDED_BOX_SUBDIVISIONS) -> Geometry:
    extents = tuple(component * 0.5 for component in size)
    bevel = min(bevel, min(extents) * 0.44)
    core = tuple(max(0.001, component - bevel) for component in extents)
    positions: list[Vec3] = []
    normals: list[Vec3] = []
    uvs: list[Vec2] = []
    indices: list[int] = []
    for axis, first, second in ((0, 1, 2), (1, 2, 0), (2, 0, 1)):
        for sign in (-1.0, 1.0):
            start = len(positions)
            for row in range(subdivisions + 1):
                v = -1.0 + 2.0 * row / subdivisions
                for column in range(subdivisions + 1):
                    u = -1.0 + 2.0 * column / subdivisions
                    raw = [0.0, 0.0, 0.0]
                    raw[axis] = sign * extents[axis]
                    raw[first] = u * extents[first]
                    raw[second] = v * extents[second]
                    clamped = [clamp(raw[i], -core[i], core[i]) for i in range(3)]
                    offset = tuple(raw[i] - clamped[i] for i in range(3))
                    fallback = tuple(sign if i == axis else 0.0 for i in range(3))
                    normal = normalize3(offset, fallback)  # type: ignore[arg-type]
                    positions.append(tuple(clamped[i] + normal[i] * bevel for i in range(3)))  # type: ignore[arg-type]
                    normals.append(normal)
                    uvs.append((column / subdivisions, 1.0 - row / subdivisions))
            stride = subdivisions + 1
            for row in range(subdivisions):
                for column in range(subdivisions):
                    a = start + row * stride + column
                    b, c, d = a + 1, a + stride + 1, a + stride
                    add_triangle(indices, positions, normals, a, b, c)
                    add_triangle(indices, positions, normals, a, c, d)
    return Geometry(positions, normals, uvs, indices)


def ellipsoid(scale: Vec3, rings: int = ELLIPSOID_RINGS,
              sides: int = ELLIPSOID_SIDES) -> Geometry:
    positions: list[Vec3] = []
    normals: list[Vec3] = []
    uvs: list[Vec2] = []
    indices: list[int] = []
    for ring in range(rings + 1):
        latitude = -math.pi * 0.5 + math.pi * ring / rings
        cos_lat, sin_lat = math.cos(latitude), math.sin(latitude)
        for side in range(sides + 1):
            longitude = math.tau * side / sides
            unit = (cos_lat * math.cos(longitude), sin_lat, cos_lat * math.sin(longitude))
            positions.append((scale[0] * unit[0], scale[1] * unit[1], scale[2] * unit[2]))
            normals.append(normalize3((unit[0] / scale[0], unit[1] / scale[1], unit[2] / scale[2])))
            uvs.append((side / sides, 1.0 - ring / rings))
    stride = sides + 1
    for ring in range(rings):
        for side in range(sides):
            a = ring * stride + side
            b, c, d = a + stride, a + stride + 1, a + 1
            add_triangle(indices, positions, normals, a, b, c)
            add_triangle(indices, positions, normals, a, c, d)
    return Geometry(positions, normals, uvs, indices)


def cylinder(radius: float, height: float, sides: int = CYLINDER_SIDES,
             top_radius: float | None = None) -> Geometry:
    top = radius if top_radius is None else top_radius
    positions: list[Vec3] = []
    normals: list[Vec3] = []
    uvs: list[Vec2] = []
    indices: list[int] = []
    slope = (radius - top) / max(height, 0.001)
    for ring, (y, current_radius) in enumerate(((-height * 0.5, radius), (height * 0.5, top))):
        for side in range(sides + 1):
            angle = math.tau * side / sides
            positions.append((math.cos(angle) * current_radius, y, math.sin(angle) * current_radius))
            normals.append(normalize3((math.cos(angle), slope, math.sin(angle))))
            uvs.append((side / sides, float(ring)))
    stride = sides + 1
    for side in range(sides):
        a, b, c, d = side, side + 1, stride + side + 1, stride + side
        add_triangle(indices, positions, normals, a, b, c)
        add_triangle(indices, positions, normals, a, c, d)
    for cap_index, (y, current_radius, normal) in enumerate((
        (-height * 0.5, radius, (0.0, -1.0, 0.0)),
        (height * 0.5, top, (0.0, 1.0, 0.0)),
    )):
        center = len(positions)
        positions.append((0.0, y, 0.0)); normals.append(normal); uvs.append((0.5, 0.5))
        rim = len(positions)
        for side in range(sides + 1):
            angle = math.tau * side / sides
            positions.append((math.cos(angle) * current_radius, y, math.sin(angle) * current_radius))
            normals.append(normal)
            uvs.append((0.5 + math.cos(angle) * 0.5, 0.5 + math.sin(angle) * 0.5))
        for side in range(sides):
            indices.extend((center, rim + side + 1, rim + side) if cap_index == 0
                           else (center, rim + side, rim + side + 1))
    return Geometry(positions, normals, uvs, indices)


def torus(major_radius: float, minor_radius: float,
          major_segments: int = TORUS_MAJOR_SEGMENTS,
          minor_segments: int = TORUS_MINOR_SEGMENTS) -> Geometry:
    positions: list[Vec3] = []
    normals: list[Vec3] = []
    uvs: list[Vec2] = []
    indices: list[int] = []
    for major in range(major_segments + 1):
        u = math.tau * major / major_segments
        for minor in range(minor_segments + 1):
            v = math.tau * minor / minor_segments
            radial = major_radius + minor_radius * math.cos(v)
            positions.append((radial * math.cos(u), minor_radius * math.sin(v), radial * math.sin(u)))
            normals.append((math.cos(v) * math.cos(u), math.sin(v), math.cos(v) * math.sin(u)))
            uvs.append((major / major_segments, minor / minor_segments))
    stride = minor_segments + 1
    for major in range(major_segments):
        for minor in range(minor_segments):
            a = major * stride + minor
            b, c, d = (major + 1) * stride + minor, (major + 1) * stride + minor + 1, a + 1
            add_triangle(indices, positions, normals, a, b, c)
            add_triangle(indices, positions, normals, a, c, d)
    return Geometry(positions, normals, uvs, indices)


def cloth_panel(outline: Sequence[Vec2], depth: float) -> Geometry:
    positions: list[Vec3] = []
    normals: list[Vec3] = []
    uvs: list[Vec2] = []
    indices: list[int] = []
    min_x, max_x = min(p[0] for p in outline), max(p[0] for p in outline)
    min_y, max_y = min(p[1] for p in outline), max(p[1] for p in outline)
    width, height = max(0.001, max_x - min_x), max(0.001, max_y - min_y)
    count = len(outline)
    for z, normal in ((depth * 0.5, (0.0, 0.0, 1.0)), (-depth * 0.5, (0.0, 0.0, -1.0))):
        start = len(positions)
        for x, y in outline:
            positions.append((x, y, z)); normals.append(normal)
            uvs.append(((x - min_x) / width, (y - min_y) / height))
        for index in range(1, count - 1):
            indices.extend((start, start + index, start + index + 1) if z > 0.0
                           else (start, start + index + 1, start + index))
    for index in range(count):
        next_index = (index + 1) % count
        a, b = outline[index], outline[next_index]
        edge_normal = normalize3((b[1] - a[1], a[0] - b[0], 0.0), (1.0, 0.0, 0.0))
        start = len(positions)
        positions.extend(((a[0], a[1], depth * 0.5), (b[0], b[1], depth * 0.5),
                          (b[0], b[1], -depth * 0.5), (a[0], a[1], -depth * 0.5)))
        normals.extend((edge_normal,) * 4)
        uvs.extend(((0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0)))
        add_triangle(indices, positions, normals, start, start + 1, start + 2)
        add_triangle(indices, positions, normals, start, start + 2, start + 3)
    return Geometry(positions, normals, uvs, indices)


def build_materials() -> list[dict]:
    def surface(name: str, color: Vec4, metallic: float, roughness: float,
                normal_scale: float = 0.72) -> dict:
        return {
            "name": name,
            "pbrMetallicRoughness": {
                "baseColorFactor": list(color), "baseColorTexture": {"index": 0},
                "metallicFactor": metallic, "roughnessFactor": roughness,
                "metallicRoughnessTexture": {"index": 2},
            },
            "normalTexture": {"index": 1, "scale": normal_scale},
            "occlusionTexture": {"index": 2, "strength": 0.86},
        }

    result = [
        surface("Worn charcoal coat", (0.095, 0.12, 0.135, 1.0), 0.10, 0.98, 0.18),
        surface("Faded coat folds", (0.14, 0.16, 0.17, 1.0), 0.08, 1.0, 0.16),
        surface("Heavy charcoal coat tails", (0.10, 0.135, 0.15, 1.0), 0.09, 1.0, 0.20),
        surface("Oxidized field metal", (0.35, 0.38, 0.39, 1.0), 1.0, 0.68, 0.12),
        surface("Weathered leather", (0.30, 0.15, 0.075, 1.0), 0.12, 0.98, 0.16),
        surface("Human skin", (0.54, 0.31, 0.20, 1.0), 0.0, 1.0, 0.06),
        surface("Hood interior", (0.055, 0.065, 0.07, 1.0), 0.0, 1.0, 0.08),
        surface("Weak sidearm gunmetal", (0.16, 0.18, 0.19, 1.0), 1.0, 0.52, 0.10),
    ]
    for name, color, factor, metallic, roughness in (
        ("Smoked cyan visor", (0.075, 0.30, 0.34, 1.0), (0.18, 0.90, 1.0), 0.52, 0.46),
        ("Cognition cyan lens", (0.08, 0.42, 0.45, 1.0), (0.10, 0.92, 1.0), 0.42, 0.40),
        ("Warm utility lens", (0.56, 0.25, 0.07, 1.0), (1.0, 0.34, 0.07), 0.22, 0.62),
    ):
        entry = surface(name, color, metallic, roughness, 0.08)
        entry["emissiveTexture"] = {"index": 3}
        entry["emissiveFactor"] = list(factor)
        result.append(entry)
    return result


def build_asset() -> dict:
    buffer = BufferBuilder()
    meshes: list[dict] = []
    nodes: list[dict] = []
    indices_by_name: dict[str, int] = {}
    base_rotations: dict[str, Vec4] = {}
    material_indices = {
        "coat": 0, "fold": 1, "tail": 2, "metal": 3, "leather": 4,
        "skin": 5, "inner": 6, "gun": 7, "visor": 8, "cyan": 9,
        "warm": 10,
    }

    def add_mesh(name: str, geometry: Geometry, material: str) -> int:
        tangents = compute_tangents(geometry)
        mins = [min(point[axis] for point in geometry.positions) for axis in range(3)]
        maxs = [max(point[axis] for point in geometry.positions) for axis in range(3)]
        attributes = {
            "POSITION": buffer.accessor(flatten(geometry.positions), 5126, "VEC3", len(geometry.positions), 34962, mins, maxs),
            "NORMAL": buffer.accessor(flatten(geometry.normals), 5126, "VEC3", len(geometry.normals), 34962),
            "TEXCOORD_0": buffer.accessor(flatten(geometry.uvs), 5126, "VEC2", len(geometry.uvs), 34962),
            "TANGENT": buffer.accessor(flatten(tangents), 5126, "VEC4", len(tangents), 34962),
        }
        index_accessor = buffer.accessor(geometry.indices, 5123, "SCALAR", len(geometry.indices), 34963)
        meshes.append({
            "name": f"{name}Mesh",
            "primitives": [{"attributes": attributes, "indices": index_accessor,
                            "material": material_indices[material]}],
        })
        return len(meshes) - 1

    def node(name: str, geometry: Geometry | None = None, material: str = "coat",
             position: Vec3 = (0.0, 0.0, 0.0), rotation: Vec4 | None = None,
             parent: int | None = 0, extras: dict | None = None) -> int:
        if name in indices_by_name:
            raise ValueError(f"Duplicate authored node name: {name}")
        entry: dict = {"name": name}
        if geometry is not None:
            entry["mesh"] = add_mesh(name, geometry, material)
        if position != (0.0, 0.0, 0.0):
            entry["translation"] = list(position)
        if rotation is not None and rotation != (0.0, 0.0, 0.0, 1.0):
            entry["rotation"] = list(rotation)
        if extras is not None:
            entry["extras"] = extras
        index = len(nodes)
        nodes.append(entry)
        indices_by_name[name] = index
        base_rotations[name] = rotation or (0.0, 0.0, 0.0, 1.0)
        if parent is not None:
            nodes[parent].setdefault("children", []).append(index)
        return index

    root = node("MechromancerModel", parent=None, extras={
        "ironwright_asset_id": ASSET_ID, "deterministic_build": True,
        "presentation_only": True, "collision": False,
        "gameplay_state": "none",
    })
    body = node("BodyAnchor", parent=root, extras={"socket_type": "body_anchor"})

    def box_node(name: str, size: Vec3, position: Vec3, material: str,
                 bevel: float = 0.035, rotation: Vec4 | None = None,
                 parent: int = body, extras: dict | None = None) -> int:
        return node(name, rounded_box(size, bevel), material, position, rotation, parent, extras)

    def sphere_node(name: str, scale: Vec3, position: Vec3, material: str,
                    parent: int = body, extras: dict | None = None) -> int:
        return node(name, ellipsoid(scale), material, position, None, parent, extras)

    def cylinder_node(name: str, radius: float, height: float, position: Vec3,
                      material: str, rotation: Vec4 | None = None,
                      parent: int = body, top_radius: float | None = None,
                      extras: dict | None = None) -> int:
        return node(name, cylinder(radius, height, CYLINDER_SIDES, top_radius), material,
                    position, rotation, parent, extras)

    def torus_node(name: str, major: float, minor: float, position: Vec3,
                   material: str, rotation: Vec4 | None = None,
                   parent: int = body) -> int:
        return node(name, torus(major, minor), material, position, rotation, parent)

    def panel_node(name: str, outline: Sequence[Vec2], depth: float,
                   position: Vec3, material: str, rotation: Vec4 | None = None,
                   parent: int = body) -> int:
        return node(name, cloth_panel(outline, depth), material, position, rotation, parent)

    def pipe_node(name: str, start: Vec3, end: Vec3, radius: float,
                  material: str, parent: int = body,
                  extras: dict | None = None) -> int:
        direction = sub3(end, start)
        length = math.sqrt(dot3(direction, direction))
        midpoint = mul3(add3(start, end), 0.5)
        return node(name, cylinder(radius, length, PIPE_SIDES, radius * 0.82), material,
                    midpoint, quat_from_y(direction), parent, extras)

    # Layered human core.
    box_node("Torso", (0.56, 0.74, 0.34), (0.0, 1.34, 0.0), "coat", 0.11)
    sphere_node("ChestShell", (0.32, 0.38, 0.105), (0.0, 1.39, 0.23), "fold")
    sphere_node("ChestArmorPlate", (0.255, 0.25, 0.052), (0.0, 1.41, 0.335), "metal")
    panel_node("FieldVest", [(-0.23, -0.22), (0.23, -0.22), (0.20, 0.20), (0.10, 0.30), (-0.11, 0.29), (-0.21, 0.18)], 0.095, (0.0, 1.44, 0.22), "leather")
    panel_node("ChestInset", [(-0.14, -0.09), (0.15, -0.09), (0.13, 0.12), (0.04, 0.17), (-0.10, 0.15)], 0.034, (0.0, 1.50, 0.28), "metal")
    pipe_node("ChestShellSeamLeft", (-0.19, 1.14, 0.33), (-0.14, 1.60, 0.34), 0.012, "fold")
    pipe_node("ChestShellSeamRight", (0.19, 1.14, 0.33), (0.14, 1.60, 0.34), 0.012, "fold")
    cylinder_node("ChestShellLatch", 0.033, 0.042, (0.0, 1.40, 0.36), "metal", quat_euler_xyz((math.pi * 0.5, 0.0, 0.0)))
    pipe_node("VestLapelsLeft", (-0.17, 1.30, 0.29), (-0.08, 1.68, 0.29), 0.027, "coat")
    pipe_node("VestLapelsRight", (0.17, 1.30, 0.29), (0.08, 1.68, 0.29), 0.027, "coat")
    torus_node("ScarfCollar", 0.205, 0.047, (0.0, 1.78, 0.005), "leather")
    panel_node("ScarfTail", [(-0.08, 0.13), (0.10, 0.12), (0.08, -0.20), (-0.04, -0.26)], 0.075, (-0.10, 1.63, 0.20), "leather", quat_euler_xyz((0.0, -0.12, 0.0)))
    panel_node("Collar", [(-0.24, -0.04), (0.24, -0.04), (0.16, 0.13), (-0.16, 0.13)], 0.13, (0.0, 1.79, 0.06), "coat")
    box_node("RespiratorCollarCore", (0.54, 0.15, 0.25), (0.0, 1.76, 0.14), "metal", 0.055, quat_euler_xyz((-0.06, 0.0, 0.0)))
    box_node("ChestHarness", (0.74, 0.075, 0.055), (0.0, 1.42, 0.38), "leather", 0.018)
    pipe_node("HarnessStrapLeft", (-0.24, 1.69, 0.37), (-0.05, 1.12, 0.37), 0.020, "leather")
    pipe_node("HarnessStrapRight", (0.24, 1.69, 0.37), (0.05, 1.12, 0.37), 0.020, "leather")
    sphere_node("HarnessFastener", (0.055, 0.055, 0.040), (-0.25, 1.42, 0.42), "warm")
    sphere_node("HarnessFastenerRight", (0.055, 0.055, 0.040), (0.25, 1.42, 0.42), "warm")

    # Hood, visible face, and visor.
    sphere_node("DeepHood", (0.345, 0.34, 0.30), (0.0, 2.07, -0.10), "coat")
    sphere_node("Hood", (0.325, 0.32, 0.275), (0.0, 2.08, -0.14), "coat")
    panel_node("HoodBackDrape", [(-0.29, 0.27), (0.31, 0.26), (0.23, -0.29), (-0.24, -0.31)], 0.18, (0.0, 1.88, -0.29), "coat")
    panel_node("HoodDrapeLeft", [(-0.13, 0.20), (0.10, 0.18), (0.08, -0.22), (-0.12, -0.25)], 0.10, (-0.22, 1.84, -0.18), "fold", quat_euler_xyz((0.0, -0.12, 0.0)))
    panel_node("HoodDrapeRight", [(-0.10, 0.18), (0.13, 0.20), (0.12, -0.24), (-0.08, -0.22)], 0.10, (0.22, 1.84, -0.18), "fold", quat_euler_xyz((0.0, 0.12, 0.0)))
    pipe_node("HoodBackSeam", (0.0, 1.78, -0.40), (0.0, 2.20, -0.40), 0.018, "leather")
    pipe_node("HoodFoldLeft", (-0.20, 1.92, -0.39), (-0.15, 2.20, -0.39), 0.014, "fold")
    pipe_node("HoodFoldRight", (0.20, 1.92, -0.39), (0.15, 2.20, -0.39), 0.014, "fold")
    torus_node("FieldHoodRim", 0.25, 0.030, (0.0, 2.05, 0.31), "leather", quat_euler_xyz((math.pi * 0.5, 0.0, 0.0)))
    box_node("HoodLowerSeam", (0.30, 0.047, 0.030), (0.0, 1.91, 0.42), "leather", 0.012, extras={"surface": "hood_lower_seam"})
    panel_node("HoodOpening", [(-0.19, 0.11), (0.19, 0.11), (0.17, -0.13), (-0.17, -0.13)], 0.028, (0.0, 2.05, 0.35), "inner")
    node("FaceAnchor", position=(0.0, 2.05, 0.30), parent=body, extras={"socket_type": "face_anchor"})
    sphere_node("Face", (0.17, 0.21, 0.12), (0.0, 2.05, 0.35), "skin")
    sphere_node("Chin", (0.11, 0.085, 0.08), (0.0, 1.94, 0.42), "skin")
    sphere_node("CheekLeft", (0.067, 0.075, 0.050), (-0.095, 2.00, 0.415), "skin")
    sphere_node("CheekRight", (0.067, 0.075, 0.050), (0.095, 2.00, 0.415), "skin")
    sphere_node("Nose", (0.028, 0.042, 0.028), (0.0, 2.02, 0.47), "skin")
    sphere_node("EarLeft", (0.038, 0.061, 0.028), (-0.175, 2.04, 0.35), "skin")
    sphere_node("EarRight", (0.038, 0.061, 0.028), (0.175, 2.04, 0.35), "skin")
    box_node("Brow", (0.21, 0.042, 0.042), (0.0, 2.145, 0.455), "skin", 0.012)
    box_node("MouthShadow", (0.11, 0.017, 0.018), (0.0, 1.955, 0.475), "inner", 0.006)
    box_node("FieldVisorHousing", (0.30, 0.115, 0.060), (0.0, 2.085, 0.445), "metal", 0.026)
    box_node("Visor", (0.23, 0.054, 0.026), (0.0, 2.085, 0.480), "visor", 0.012)
    box_node("VisorGlow", (0.16, 0.016, 0.014), (0.0, 2.085, 0.497), "cyan", 0.005)
    box_node("VisorBrow", (0.27, 0.047, 0.036), (0.0, 2.148, 0.465), "metal", 0.014, extras={"surface": "visor_protection"})
    sphere_node("VisorMountLeft", (0.030, 0.030, 0.030), (-0.15, 2.085, 0.493), "metal")
    sphere_node("VisorMountRight", (0.030, 0.030, 0.030), (0.15, 2.085, 0.493), "metal")
    cylinder_node("Neck", 0.11, 0.16, (0.0, 1.83, 0.0), "skin")

    # Shoulders, lamps, comms, arms, and hands.
    sphere_node("LeftShoulder", (0.19, 0.16, 0.13), (-0.37, 1.66, 0.01), "coat")
    sphere_node("RightShoulder", (0.19, 0.16, 0.13), (0.37, 1.66, 0.01), "coat")
    panel_node("LeftShoulderPad", [(-0.15, 0.06), (0.15, 0.08), (0.11, -0.09), (-0.13, -0.11)], 0.12, (-0.39, 1.70, 0.08), "leather", quat_euler_xyz((0.0, -0.16, 0.0)))
    panel_node("RightShoulderPad", [(-0.15, 0.08), (0.15, 0.06), (0.13, -0.11), (-0.11, -0.09)], 0.12, (0.39, 1.70, 0.08), "leather", quat_euler_xyz((0.0, 0.16, 0.0)))
    box_node("FieldShoulderGuard", (0.50, 0.18, 0.25), (-0.44, 1.64, -0.03), "metal", 0.06, quat_euler_xyz((0.0, 0.0, 0.12)))
    node("ShoulderLamp", position=(-0.43, 1.77, 0.19), parent=body, extras={"socket_type": "light_mount"})
    box_node("FieldShoulderLampHousing", (0.22, 0.18, 0.17), (-0.43, 1.77, 0.20), "metal", 0.05)
    cylinder_node("LampRing", 0.077, 0.052, (-0.43, 1.77, 0.315), "metal", quat_euler_xyz((math.pi * 0.5, 0.0, 0.0)))
    sphere_node("LampCore", (0.050, 0.050, 0.038), (-0.43, 1.77, 0.35), "cyan")
    sphere_node("FieldShoulderLampLens", (0.069, 0.069, 0.045), (-0.43, 1.77, 0.365), "cyan")
    box_node("LampMount", (0.065, 0.23, 0.070), (-0.43, 1.68, 0.11), "leather", 0.012)
    cylinder_node("WarmLamp", 0.052, 0.118, (0.31, 1.45, 0.21), "warm", quat_euler_xyz((math.pi * 0.5, 0.0, 0.0)))
    box_node("FieldCommsYoke", (0.19, 0.20, 0.15), (0.44, 1.78, 0.12), "metal", 0.045, quat_euler_xyz((0.0, 0.14, 0.0)), extras={"socket_type": "comms_mount"})
    box_node("FieldCommsPanel", (0.32, 0.34, 0.065), (0.37, 1.48, -0.02), "metal", 0.035)
    pipe_node("FieldCommsAntenna", (0.49, 1.84, 0.17), (0.60, 2.08, 0.17), 0.019, "metal", extras={"socket_type": "antenna"})
    sphere_node("FieldCommsBeacon", (0.045, 0.045, 0.045), (0.60, 2.10, 0.17), "warm", extras={"socket_type": "signal_beacon"})
    pipe_node("FieldCommsCable", (0.44, 1.72, 0.03), (0.18, 1.48, 0.22), 0.013, "leather", extras={"socket_type": "service_cable"})
    pipe_node("LeftArm", (-0.36, 1.62, 0.0), (-0.48, 1.30, 0.04), 0.108, "coat")
    pipe_node("RightArm", (0.36, 1.62, 0.0), (0.48, 1.30, 0.04), 0.108, "coat")
    pipe_node("LeftForearmGuard", (-0.48, 1.30, 0.04), (-0.47, 1.08, 0.22), 0.084, "metal")
    pipe_node("RightForearmGuard", (0.48, 1.30, 0.04), (0.56, 1.08, 0.22), 0.084, "metal")
    sphere_node("LeftGlove", (0.11, 0.10, 0.115), (-0.47, 1.01, 0.27), "leather")
    sphere_node("RightGlove", (0.11, 0.10, 0.115), (0.58, 1.01, 0.28), "leather")
    sphere_node("FieldWorkGloveLeft", (0.085, 0.15, 0.09), (-0.49, 0.93, 0.34), "leather")
    sphere_node("FieldWorkGloveRight", (0.085, 0.15, 0.09), (0.60, 0.93, 0.34), "leather")
    sphere_node("LeftGloveThumb", (0.047, 0.043, 0.068), (-0.55, 1.03, 0.33), "leather")
    sphere_node("RightGloveThumb", (0.047, 0.043, 0.068), (0.66, 1.03, 0.33), "leather")
    for hand, x, side in (("Left", -0.47, -1.0), ("Right", 0.58, 1.0)):
        box_node(f"{hand}GloveKnucklePlate", (0.18, 0.055, 0.13), (x, 1.045, 0.34), "metal", 0.018)
        for finger in range(3):
            box_node(f"{hand}GloveFinger{finger + 1}", (0.042, 0.065, 0.12),
                     (x + side * (finger - 1) * 0.038, 0.97, 0.34), "leather", 0.014)
    box_node("FieldForearmDiagnostic", (0.24, 0.24, 0.07), (-0.50, 1.18, 0.35), "metal", 0.035, quat_euler_xyz((0.0, 0.0, 0.12)))
    sphere_node("FieldForearmDiagnosticLens", (0.047, 0.047, 0.035), (-0.50, 1.23, 0.405), "cyan")
    cylinder_node("FieldCableClamp", 0.046, 0.125, (-0.48, 1.27, -0.02), "warm", quat_euler_xyz((math.pi * 0.5, 0.0, 0.0)))

    # Legs, boots, and heavy split coat tails.
    pipe_node("LeftLeg", (-0.17, 0.98, -0.04), (-0.20, 0.57, -0.01), 0.122, "leather")
    pipe_node("RightLeg", (0.17, 0.98, -0.04), (0.20, 0.57, -0.01), 0.122, "leather")
    pipe_node("LeftShin", (-0.20, 0.57, -0.01), (-0.17, 0.26, 0.01), 0.107, "leather")
    pipe_node("RightShin", (0.20, 0.57, -0.01), (0.17, 0.26, 0.01), 0.107, "leather")
    sphere_node("LeftBoot", (0.15, 0.11, 0.22), (-0.17, 0.16, 0.07), "leather")
    sphere_node("RightBoot", (0.15, 0.11, 0.22), (0.17, 0.16, 0.07), "leather")
    box_node("LeftBootToe", (0.28, 0.14, 0.35), (-0.17, 0.13, 0.18), "leather", 0.045)
    box_node("RightBootToe", (0.28, 0.14, 0.35), (0.17, 0.13, 0.18), "leather", 0.045)
    box_node("LeftBootStrap", (0.27, 0.045, 0.045), (-0.17, 0.19, 0.30), "metal", 0.012)
    box_node("RightBootStrap", (0.27, 0.045, 0.045), (0.17, 0.19, 0.30), "metal", 0.012)
    box_node("FieldKneeGuardLeft", (0.25, 0.31, 0.14), (-0.20, 0.58, 0.30), "metal", 0.045, quat_euler_xyz((-0.06, 0.0, 0.08)))
    box_node("FieldKneeGuardRight", (0.25, 0.31, 0.14), (0.20, 0.58, 0.30), "metal", 0.045, quat_euler_xyz((-0.06, 0.0, -0.08)))
    box_node("FieldBootCuffLeft", (0.20, 0.14, 0.33), (-0.20, 0.30, 0.04), "leather", 0.04)
    box_node("FieldBootCuffRight", (0.20, 0.14, 0.33), (0.20, 0.30, 0.04), "leather", 0.04)
    left_tail = [(-0.20, 0.51), (0.18, 0.48), (0.26, 0.22), (0.29, -0.20), (0.18, -0.53), (-0.23, -0.51), (-0.28, -0.19), (-0.24, 0.16)]
    right_tail = [(-0.18, 0.48), (0.21, 0.51), (0.25, 0.18), (0.20, -0.24), (0.25, -0.51), (-0.17, -0.53), (-0.25, -0.20), (-0.22, 0.22)]
    panel_node("CoatTailLeft", left_tail, 0.24, (-0.24, 0.70, -0.09), "tail", quat_euler_xyz((0.0, -0.045, 0.0)))
    panel_node("CoatTailRight", right_tail, 0.24, (0.24, 0.70, -0.10), "tail", quat_euler_xyz((0.0, 0.065, 0.0)))
    box_node("FieldCoatHemLeft", (0.34, 0.10, 0.25), (-0.24, 0.20, 0.02), "leather", 0.035)
    box_node("FieldCoatHemRight", (0.34, 0.10, 0.25), (0.24, 0.20, 0.02), "leather", 0.035)
    pipe_node("CoatBackSplit", (0.0, 1.12, -0.23), (0.0, 0.21, -0.23), 0.018, "leather")
    pipe_node("CoatFabricFoldLeft", (-0.14, 1.10, -0.23), (-0.18, 0.27, -0.23), 0.016, "fold")
    pipe_node("CoatFabricFoldRight", (0.15, 1.08, -0.23), (0.19, 0.27, -0.23), 0.016, "fold")
    pipe_node("CoatTailEdgeLeft", (-0.34, 1.04, -0.23), (-0.42, 0.30, -0.23), 0.013, "fold")
    pipe_node("CoatTailEdgeRight", (0.34, 1.04, -0.23), (0.42, 0.30, -0.23), 0.013, "fold")
    for side, label in ((-1.0, "Left"), (1.0, "Right")):
        for stitch in range(5):
            box_node(f"CoatStitch{label}{stitch + 1}", (0.055, 0.018, 0.018),
                     (side * 0.39, 0.34 + stitch * 0.14, 0.035), "leather", 0.005)

    # Belt and asymmetric field pack migrated from the runtime overlay.
    box_node("UtilityBelt", (0.69, 0.12, 0.11), (0.0, 1.06, 0.20), "leather", 0.035)
    box_node("BeltBuckle", (0.13, 0.095, 0.044), (0.0, 1.06, 0.265), "metal", 0.018)
    box_node("BeltPouchLeft", (0.17, 0.19, 0.15), (-0.29, 0.98, 0.23), "leather", 0.035)
    box_node("BeltPouchRight", (0.16, 0.18, 0.14), (0.29, 0.98, 0.23), "leather", 0.035)
    box_node("ToolLoop", (0.060, 0.23, 0.040), (-0.38, 1.12, 0.24), "leather", 0.012)
    box_node("FieldPack", (0.60, 0.74, 0.35), (-0.25, 1.35, -0.34), "leather", 0.085, extras={"socket_type": "equipment_mount"})
    box_node("FieldPackBackplate", (0.50, 0.48, 0.055), (-0.25, 1.36, -0.54), "metal", 0.045)
    cylinder_node("FieldPackTopRoll", 0.115, 0.50, (-0.25, 1.77, -0.36), "leather", quat_euler_xyz((0.0, 0.0, math.pi * 0.5)))
    panel_node("PackFlap", [(-0.22, 0.14), (0.22, 0.14), (0.18, -0.16), (-0.18, -0.16)], 0.046, (-0.25, 1.54, -0.54), "leather")
    box_node("PackBuckleLeft", (0.060, 0.075, 0.026), (-0.37, 1.56, -0.58), "metal", 0.012)
    box_node("PackBuckleRight", (0.060, 0.075, 0.026), (-0.13, 1.56, -0.58), "metal", 0.012)
    box_node("PackPocketLeft", (0.21, 0.23, 0.16), (-0.53, 1.23, -0.45), "leather", 0.045)
    box_node("PackPocketRight", (0.20, 0.21, 0.15), (0.03, 1.23, -0.45), "leather", 0.045)
    cylinder_node("PackSideCanister", 0.080, 0.27, (-0.60, 1.36, -0.35), "metal", quat_euler_xyz((0.0, 0.0, math.pi * 0.5)))
    pipe_node("PackStrapLeft", (-0.39, 1.61, -0.54), (-0.28, 1.12, -0.54), 0.019, "leather")
    pipe_node("PackStrapRight", (-0.12, 1.61, -0.54), (-0.22, 1.12, -0.54), 0.019, "leather")
    pipe_node("BackHarness", (0.10, 1.72, -0.23), (-0.12, 1.05, -0.23), 0.021, "leather")
    for side, label in ((-1.0, "Left"), (1.0, "Right")):
        x = -0.25 + side * 0.25
        box_node(f"FieldPackFrameRail{label}", (0.070, 0.64, 0.080), (x, 1.36, -0.59), "metal", 0.022)
        sphere_node(f"FieldPackAnchor{label}", (0.060, 0.060, 0.045), (x, 1.68, -0.57), "warm")
    sphere_node("FieldPackCornerCap", (0.060, 0.060, 0.050), (-0.50, 1.04, -0.57), "metal")
    sphere_node("FieldPackCornerCapRight", (0.060, 0.060, 0.050), (0.00, 1.04, -0.57), "metal")
    pipe_node("FieldPackServiceCable", (-0.59, 1.64, -0.42), (-0.52, 1.20, -0.55), 0.027, "cyan")
    cylinder_node("CableSpool", 0.18, 0.46, (-0.49, 1.08, -0.42), "metal", quat_euler_xyz((0.0, 0.0, math.pi * 0.5)))
    cylinder_node("CableSpoolAxle", 0.046, 0.50, (-0.49, 1.08, -0.42), "gun", quat_euler_xyz((0.0, 0.0, math.pi * 0.5)))
    box_node("ToolRoll", (0.25, 0.51, 0.19), (0.47, 0.92, -0.31), "leather", 0.055)
    cylinder_node("FieldUtilityCanister", 0.135, 0.31, (-0.62, 0.78, -0.04), "metal", quat_euler_xyz((0.0, 0.0, math.pi * 0.5)))
    cylinder_node("FieldUtilityCanisterClamp", 0.044, 0.35, (-0.62, 0.78, 0.13), "gun", quat_euler_xyz((0.0, 0.0, math.pi * 0.5)))
    box_node("FieldToolDeck", (0.39, 0.23, 0.13), (0.62, 0.72, -0.22), "metal", 0.045)
    box_node("FieldToolClamp", (0.065, 0.27, 0.21), (0.53, 0.86, -0.22), "warm", 0.026)

    # Weak improvised pistol with exact nested muzzle socket.
    pistol = box_node("WeakPistol", (0.20, 0.14, 0.34), (0.60, 1.08, 0.29), "gun", 0.045,
                      parent=body, extras={"socket_type": "weapon_mount"})
    cylinder_node("PistolBarrel", 0.043, 0.36, (0.0, 0.03, 0.28), "gun", quat_euler_xyz((math.pi * 0.5, 0.0, 0.0)), pistol)
    box_node("PistolGrip", (0.12, 0.26, 0.14), (0.0, -0.15, -0.02), "leather", 0.035, quat_euler_xyz((-0.20, 0.0, 0.0)), pistol)
    box_node("PistolSlide", (0.18, 0.06, 0.21), (0.0, 0.075, 0.39), "gun", 0.025, parent=pistol)
    torus_node("PistolTriggerGuard", 0.060, 0.013, (0.0, -0.02, 0.04), "gun", quat_euler_xyz((math.pi * 0.5, 0.0, 0.0)), pistol)
    cylinder_node("PistolMuzzleCollar", 0.057, 0.075, (0.0, 0.03, 0.44), "gun", quat_euler_xyz((math.pi * 0.5, 0.0, 0.0)), pistol)
    box_node("PistolFrontSight", (0.056, 0.075, 0.070), (0.0, 0.135, 0.36), "metal", 0.014, parent=pistol)
    cylinder_node("PistolRecoilRod", 0.018, 0.25, (0.0, -0.015, 0.30), "metal", quat_euler_xyz((math.pi * 0.5, 0.0, 0.0)), pistol)
    sphere_node("PistolServiceScrewLeft", (0.018, 0.018, 0.012), (-0.105, 0.03, 0.12), "warm", pistol)
    sphere_node("PistolServiceScrewRight", (0.018, 0.018, 0.012), (0.105, 0.03, 0.12), "warm", pistol)
    node("PistolMuzzle", position=(0.0, 0.03, 0.50), parent=pistol, extras={"socket_type": "weapon_muzzle"})
    pipe_node("FieldTool", (-0.42, 1.04, 0.20), (-0.40, 1.38, 0.20), 0.039, "metal", extras={"socket_type": "field_tool"})
    box_node("FieldToolHead", (0.21, 0.08, 0.08), (-0.43, 1.43, 0.21), "metal", 0.025)
    box_node("WristToolLoop", (0.11, 0.35, 0.15), (-0.53, 0.87, 0.37), "leather", 0.035)
    node("ProductionAssetMarker", parent=body, extras={"asset_contract": ASSET_ID})

    missing = [name for name in REQUIRED_NODES if name not in indices_by_name]
    if missing:
        raise RuntimeError(f"Missing required nodes: {missing}")

    animations: list[dict] = []

    def keyed_translation(name: str, times: list[float], values: list[Vec3]) -> tuple[str, str, list[float], list[float]]:
        return (name, "translation", times, flatten(values))

    def keyed_rotation(name: str, times: list[float], deltas: list[Vec3]) -> tuple[str, str, list[float], list[float]]:
        base = base_rotations[name]
        values = [quat_mul(base, quat_euler_xyz(delta)) for delta in deltas]
        return (name, "rotation", times, flatten(values))

    def animation(name: str, channels: list[tuple[str, str, list[float], list[float]]]) -> None:
        samplers: list[dict] = []
        channel_entries: list[dict] = []
        widths = {"translation": ("VEC3", 3), "rotation": ("VEC4", 4)}
        for target_name, path, times, values in channels:
            input_accessor = buffer.accessor(times, 5126, "SCALAR", len(times), minimum=[min(times)], maximum=[max(times)])
            accessor_type, width = widths[path]
            output_accessor = buffer.accessor(values, 5126, accessor_type, len(values) // width)
            sampler_index = len(samplers)
            samplers.append({"input": input_accessor, "output": output_accessor, "interpolation": "LINEAR"})
            channel_entries.append({"sampler": sampler_index, "target": {"node": indices_by_name[target_name], "path": path}})
        animations.append({"name": name, "samplers": samplers, "channels": channel_entries})

    idle = [1.0 / 24.0, 20.0 / 24.0, 40.0 / 24.0]
    walk = [1.0 / 24.0, 6.0 / 24.0, 12.0 / 24.0]
    fire = [1.0 / 24.0, 3.0 / 24.0, 5.0 / 24.0]
    work = [1.0 / 24.0, 12.0 / 24.0, 24.0 / 24.0]
    hit = [1.0 / 24.0, 3.0 / 24.0, 7.0 / 24.0]
    animation("Idle", [
        keyed_translation("MechromancerModel", idle, [(0.0, 0.0, 0.0), (0.0, 0.012, 0.0), (0.0, 0.0, 0.0)]),
        keyed_translation("Hood", idle, [(0.0, 2.08, -0.14), (0.0, 2.092, -0.14), (0.0, 2.08, -0.14)]),
        keyed_rotation("CoatTailLeft", idle, [(0.0, -0.015, 0.0), (0.0, 0.02, 0.0), (0.0, -0.015, 0.0)]),
        keyed_rotation("CoatTailRight", idle, [(0.0, 0.015, 0.0), (0.0, -0.02, 0.0), (0.0, 0.015, 0.0)]),
        keyed_translation("FieldPack", idle, [(-0.25, 1.35, -0.34), (-0.25, 1.36, -0.34), (-0.25, 1.35, -0.34)]),
        keyed_rotation("FieldCommsAntenna", idle, [(0.0, -0.035, 0.0), (0.0, 0.045, 0.0), (0.0, -0.035, 0.0)]),
        keyed_translation("FieldCommsBeacon", idle, [(0.60, 2.10, 0.17), (0.60, 2.115, 0.17), (0.60, 2.10, 0.17)]),
    ])
    animation("Walk", [
        keyed_translation("MechromancerModel", walk, [(0.0, 0.0, 0.0), (0.0, 0.025, 0.0), (0.0, 0.0, 0.0)]),
        keyed_rotation("LeftLeg", walk, [(0.20, 0.0, 0.0), (-0.28, 0.0, 0.0), (0.20, 0.0, 0.0)]),
        keyed_rotation("RightLeg", walk, [(-0.28, 0.0, 0.0), (0.20, 0.0, 0.0), (-0.28, 0.0, 0.0)]),
        keyed_rotation("CoatTailLeft", walk, [(0.08, -0.10, 0.0), (0.20, 0.14, 0.0), (0.08, -0.10, 0.0)]),
        keyed_rotation("CoatTailRight", walk, [(0.08, 0.10, 0.0), (0.20, -0.14, 0.0), (0.08, 0.10, 0.0)]),
        keyed_translation("FieldPack", walk, [(-0.25, 1.34, -0.34), (-0.25, 1.39, -0.34), (-0.25, 1.34, -0.34)]),
        keyed_rotation("FieldCommsAntenna", walk, [(0.0, 0.0, -0.02), (0.0, 0.0, 0.05), (0.0, 0.0, -0.02)]),
        keyed_rotation("BodyAnchor", walk, [(0.0, -0.015, 0.0), (0.0, 0.025, 0.0), (0.0, -0.015, 0.0)]),
    ])
    animation("Fire", [
        keyed_translation("WeakPistol", fire, [(0.60, 1.08, 0.29), (0.60, 1.08, 0.36), (0.60, 1.08, 0.29)]),
        keyed_rotation("RightArm", fire, [(0.0, 0.0, 0.0), (-0.06, 0.0, -0.06), (0.0, 0.0, 0.0)]),
        keyed_rotation("ShoulderLamp", fire, [(0.0, 0.0, 0.0), (0.0, 0.08, 0.0), (0.0, 0.0, 0.0)]),
        keyed_rotation("FieldCommsAntenna", fire, [(0.0, 0.0, 0.0), (0.0, -0.08, 0.0), (0.0, 0.0, 0.0)]),
    ])
    animation("Work", [
        keyed_rotation("LeftArm", work, [(0.0, 0.0, 0.0), (-0.30, 0.0, -0.15), (0.0, 0.0, 0.0)]),
        keyed_rotation("RightArm", work, [(0.0, 0.0, 0.0), (-0.52, 0.0, 0.15), (0.0, 0.0, 0.0)]),
        keyed_rotation("CoatTailLeft", work, [(0.0, -0.02, 0.0), (0.10, 0.08, 0.0), (0.0, -0.02, 0.0)]),
        keyed_rotation("CoatTailRight", work, [(0.0, 0.02, 0.0), (0.10, -0.08, 0.0), (0.0, 0.02, 0.0)]),
        keyed_rotation("FieldCommsYoke", work, [(0.0, 0.0, 0.0), (0.0, 0.08, 0.0), (0.0, 0.0, 0.0)]),
        keyed_rotation("FieldCommsAntenna", work, [(0.0, 0.0, 0.0), (0.0, 0.10, 0.0), (0.0, 0.0, 0.0)]),
    ])
    animation("Upgrade", [
        keyed_rotation("LeftArm", work, [(0.0, 0.0, 0.0), (-0.44, 0.0, -0.18), (0.0, 0.0, 0.0)]),
        keyed_rotation("RightArm", work, [(0.0, 0.0, 0.0), (-0.64, 0.0, 0.18), (0.0, 0.0, 0.0)]),
        keyed_rotation("FieldTool", work, [(0.0, 0.0, 0.0), (0.0, -0.42, 0.0), (0.0, 0.0, 0.0)]),
        keyed_rotation("ShoulderLamp", work, [(0.0, 0.0, 0.0), (0.0, 0.14, 0.0), (0.0, 0.0, 0.0)]),
        keyed_rotation("FieldCommsAntenna", work, [(0.0, 0.0, 0.0), (0.0, -0.12, 0.0), (0.0, 0.0, 0.0)]),
    ])
    animation("Hit", [
        keyed_rotation("MechromancerModel", hit, [(0.0, 0.0, 0.0), (0.10, 0.0, 0.05), (0.0, 0.0, 0.0)]),
        keyed_rotation("FieldPack", hit, [(0.0, 0.0, 0.0), (0.0, -0.08, 0.0), (0.0, 0.0, 0.0)]),
        keyed_rotation("CoatTailLeft", hit, [(0.0, 0.0, 0.0), (0.10, 0.0, -0.03), (0.0, 0.0, 0.0)]),
        keyed_rotation("CoatTailRight", hit, [(0.0, 0.0, 0.0), (0.10, 0.0, 0.03), (0.0, 0.0, 0.0)]),
    ])

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright deterministic Mechromancer HD builder"},
        "scene": 0,
        "scenes": [{"name": "Mechromancer", "nodes": [root]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": build_materials(),
        "textures": [{"sampler": 0, "source": index} for index in range(4)],
        "images": [{"uri": TEXTURES[key], "name": f"Mechromancer {key}"}
                   for key in ("base_color", "normal", "orm", "emissive")],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
        "animations": animations,
        "accessors": buffer.accessors,
        "bufferViews": buffer.views,
        "buffers": [{"byteLength": len(buffer.data), "uri": BIN_PATH.name}],
        "extras": {
            "ironwright_asset_id": ASSET_ID,
            "texture_resolution": TEXTURE_SIZE,
            "material_contract": "textured_metallic_roughness_pbr",
            "required_nodes": REQUIRED_NODES,
            "animation_clips": CLIPS,
            "deterministic_build": True,
            "presentation_only": True,
            "collision": False,
            "gameplay_state": "none",
            "source_type": "original_project_ironwright_deterministic_mesh_builder",
        },
    }
    BIN_PATH.write_bytes(buffer.data)
    return document


def main() -> None:
    build_textures()
    document = build_asset()
    GLTF_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8", newline="\n")
    print(f"Wrote deterministic Mechromancer HD package: {len(document['nodes'])} nodes, {len(document['meshes'])} meshes")


if __name__ == "__main__":
    main()
