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
import zlib
from pathlib import Path
from typing import Iterable, Sequence


ASSET_DIR = Path(__file__).resolve().parents[1]
OUTPUT_PATH = ASSET_DIR / "bulwark.gltf"
TEXTURE_SIZE = 1024
TEXTURE_PATHS = {
    "base_color": ASSET_DIR / "bulwark_base_color.png",
    "normal": ASSET_DIR / "bulwark_normal.png",
    "orm": ASSET_DIR / "bulwark_orm.png",
    "emissive": ASSET_DIR / "bulwark_emissive.png",
}


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


def _texture_noise(x: int, y: int) -> int:
    value = (x * 374761393 + y * 668265263 + 0x5A17C9E3) & 0xFFFFFFFF
    value = ((value ^ (value >> 13)) * 1274126177) & 0xFFFFFFFF
    return (value ^ (value >> 16)) & 0xFF


def _build_texture_set() -> None:
    """Write an original, dependency-free industrial PBR texture set."""
    def channel(value: float) -> int:
        return max(0, min(255, round(value)))

    def base_color(x: int, y: int) -> tuple[int, int, int, int]:
        grain = (_texture_noise(x, y) - 128) / 128.0
        brushed = 1.8 * math.sin(y * 0.37 + math.sin(x * 0.006) * 1.7)
        brushed += 0.8 * math.sin(y * 1.19 + x * 0.011)
        warp_x = 16.0 * math.sin(y * 0.005) + 7.0 * math.sin((x + y) * 0.003)
        warp_y = 13.0 * math.sin(x * 0.006) - 6.0 * math.sin((x - y) * 0.004)
        broad = (
            math.sin((x + warp_x) * 0.013 + (y + warp_y) * 0.009)
            + math.sin((x - warp_y) * 0.031 - (y + warp_x) * 0.021)
            + math.sin((x + warp_y) * 0.007 + (y - warp_x) * 0.043)
        )
        pitted = broad > 2.68 and _texture_noise(x, y) > 214
        oxidized = broad < -2.62 and _texture_noise(x // 3, y // 3) > 194
        scratch_field = _texture_noise(x // 41, y // 9)
        scratch = scratch_field > 252 and (x + y * 5 + scratch_field) % 131 < 2
        if pitted:
            return (channel(169 + grain * 5), channel(174 + grain * 5), channel(172 + grain * 4), 255)
        if oxidized:
            return (channel(181 + grain * 6), channel(164 + grain * 5), channel(145 + grain * 4), 255)
        if scratch:
            return (channel(207 + grain * 4), channel(212 + grain * 4), channel(210 + grain * 3), 255)
        return (
            channel(188 + brushed + grain * 7),
            channel(195 + brushed * 0.82 + grain * 6),
            channel(194 + brushed * 0.78 + grain * 5),
            255,
        )

    def normal(x: int, y: int) -> tuple[int, int, int, int]:
        # Analytic micro-surface slopes keep the map neutral-blue while adding
        # real, non-flat machining grooves and irregular hammered-metal dents.
        phase = y * 0.53 + math.sin(x * 0.008) * 2.1 + math.sin((x + y) * 0.017) * 0.8
        jitter_x = (_texture_noise(x + 2, y) - _texture_noise(x - 2, y)) / 255.0
        jitter_y = (_texture_noise(x, y + 2) - _texture_noise(x, y - 2)) / 255.0
        dx = 0.010 * math.cos((x + y) * 0.029) + jitter_x * 0.018
        dy = 0.021 * math.cos(phase) + 0.009 * math.cos(y * 1.27 + x * 0.019) + jitter_y * 0.018
        nx, ny, nz = -dx, -dy, 1.0
        length = math.sqrt(nx * nx + ny * ny + nz * nz)
        return (
            round((nx / length * 0.5 + 0.5) * 255),
            round((ny / length * 0.5 + 0.5) * 255),
            round((nz / length * 0.5 + 0.5) * 255),
            255,
        )

    def orm(x: int, y: int) -> tuple[int, int, int, int]:
        grain = (_texture_noise(x, y) - 128) / 128.0
        brushed = math.sin(y * 0.19 + math.sin(x * 0.007) * 2.2 + math.sin((x + y) * 0.011))
        pit_field = (
            math.sin(x * 0.017 + y * 0.011)
            + math.sin(x * 0.037 - y * 0.023)
            + math.sin(x * 0.009 + y * 0.047)
        )
        pitted = pit_field > 2.75 and _texture_noise(x, y) > 220
        ao = 237 + grain * 5 + brushed * 2
        roughness = 158 + grain * 13 + brushed * 4
        metallic = 232 + grain * 6 - brushed * 2
        if pitted:
            ao -= 18
            roughness += 19
            metallic -= 11
        return (channel(ao), channel(roughness), channel(metallic), 255)

    def emissive(x: int, y: int) -> tuple[int, int, int, int]:
        grain = (_texture_noise(x, y) - 128) / 128.0
        scan = 0.9 * math.sin(y * 0.33 + x * 0.006 + math.sin(x * 0.009))
        slow_wear = 1.2 * math.sin(x * 0.019 + y * 0.013)
        intensity = 232 + scan + slow_wear + grain * 1.8
        if _texture_noise(x // 3, y // 3) > 253 and _texture_noise(x, y) > 210:
            intensity -= 16
        intensity = channel(intensity)
        return (intensity, intensity, intensity, 255)

    _write_png_rgba(TEXTURE_PATHS["base_color"], base_color)
    _write_png_rgba(TEXTURE_PATHS["normal"], normal)
    _write_png_rgba(TEXTURE_PATHS["orm"], orm)
    _write_png_rgba(TEXTURE_PATHS["emissive"], emissive)


def _uvs_and_tangents(positions: list[float], normals: list[float]) -> tuple[list[float], list[float]]:
    """Create continuous-scale tri-planar UVs and orthonormal tangents."""
    uvs: list[float] = []
    tangents: list[float] = []
    for offset in range(0, len(positions), 3):
        x, y, z = positions[offset:offset + 3]
        nx, ny, nz = normals[offset:offset + 3]
        ax, ay, az = abs(nx), abs(ny), abs(nz)
        if ax >= ay and ax >= az:
            u, v = z * 2.0 + 0.5, y * 2.0 + 0.5
            candidate = (0.0, 0.0, 1.0)
            handedness = -1.0 if nx >= 0.0 else 1.0
        elif ay >= az:
            u, v = x * 2.0 + 0.5, z * 2.0 + 0.5
            candidate = (1.0, 0.0, 0.0)
            handedness = -1.0 if ny >= 0.0 else 1.0
        else:
            u, v = x * 2.0 + 0.5, y * 2.0 + 0.5
            candidate = (1.0, 0.0, 0.0)
            handedness = 1.0 if nz >= 0.0 else -1.0
        dot = candidate[0] * nx + candidate[1] * ny + candidate[2] * nz
        tx = candidate[0] - nx * dot
        ty = candidate[1] - ny * dot
        tz = candidate[2] - nz * dot
        length = math.sqrt(tx * tx + ty * ty + tz * tz)
        if length < 1.0e-6:
            reference = (0.0, 1.0, 0.0) if abs(ny) < 0.9 else (0.0, 0.0, 1.0)
            tx = reference[1] * nz - reference[2] * ny
            ty = reference[2] * nx - reference[0] * nz
            tz = reference[0] * ny - reference[1] * nx
            length = math.sqrt(tx * tx + ty * ty + tz * tz)
        uvs.extend((u, v))
        tangents.extend((tx / length, ty / length, tz / length, handedness))
    return uvs, tangents


def _geometry(
    builder: BufferBuilder,
    positions: list[float],
    normals: list[float],
    indices: list[int],
    material: int,
) -> tuple[int, int, int, int, int, int]:
    position_min, position_max = vec_min_max(zip(*[iter(positions)] * 3))
    uvs, tangents = _uvs_and_tangents(positions, normals)
    position_accessor = builder.accessor(
        positions, 5126, "VEC3", len(positions) // 3, 34962, position_min, position_max
    )
    normal_accessor = builder.accessor(normals, 5126, "VEC3", len(normals) // 3, 34962)
    uv_accessor = builder.accessor(uvs, 5126, "VEC2", len(uvs) // 2, 34962)
    tangent_accessor = builder.accessor(tangents, 5126, "VEC4", len(tangents) // 4, 34962)
    index_accessor = builder.accessor(indices, 5123, "SCALAR", len(indices), 34963)
    return position_accessor, normal_accessor, uv_accessor, tangent_accessor, index_accessor, material


def add_box(builder: BufferBuilder, size: Sequence[float], material: int) -> tuple[int, int, int, int, int, int]:
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


def add_beveled_box(
    builder: BufferBuilder,
    size: Sequence[float],
    material: int,
    bevel: float = 0.06,
) -> tuple[int, int, int, int, int, int]:
    """Build a compact chamfered block for hero-scale manufactured surfaces."""
    extents = [max(0.001, value * 0.5) for value in size]
    bevel = min(bevel, min(extents) * 0.42)
    inset = [extent - bevel for extent in extents]
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []

    def add_vertex(point: Sequence[float], normal: Sequence[float]) -> int:
        index = len(positions) // 3
        positions.extend(point)
        normals.extend(normal)
        return index

    def add_quad(points: Sequence[Sequence[float]], normal: Sequence[float]) -> None:
        start = [add_vertex(point, normal) for point in points]
        indices.extend([start[0], start[1], start[2], start[0], start[2], start[3]])

    axis_data = ((0, 1, 2), (1, 2, 0), (2, 0, 1))
    for axis, first, second in axis_data:
        for sign in (-1.0, 1.0):
            face_normal = [0.0, 0.0, 0.0]
            face_normal[axis] = sign
            points: list[list[float]] = []
            for first_sign, second_sign in ((-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)):
                point = [0.0, 0.0, 0.0]
                point[axis] = sign * extents[axis]
                point[first] = first_sign * inset[first]
                point[second] = second_sign * inset[second]
                points.append(point)
            add_quad(points, face_normal)

    for axis, first, second in axis_data:
        for first_sign in (-1.0, 1.0):
            for second_sign in (-1.0, 1.0):
                normal = [0.0, 0.0, 0.0]
                normal[axis] = first_sign * 0.70710678
                normal[first] = second_sign * 0.70710678
                points = []
                for remaining_sign in (-1.0, 1.0):
                    point = [0.0, 0.0, 0.0]
                    point[axis] = first_sign * extents[axis]
                    point[first] = second_sign * inset[first]
                    point[second] = remaining_sign * inset[second]
                    points.append(point)
                for remaining_sign in (1.0, -1.0):
                    point = [0.0, 0.0, 0.0]
                    point[axis] = first_sign * inset[axis]
                    point[first] = second_sign * extents[first]
                    point[second] = remaining_sign * inset[second]
                    points.append(point)
                add_quad(points, normal)

    for first_sign in (-1.0, 1.0):
        for second_sign in (-1.0, 1.0):
            for third_sign in (-1.0, 1.0):
                normal = [first_sign * 0.57735027, second_sign * 0.57735027, third_sign * 0.57735027]
                points = [
                    [first_sign * extents[0], second_sign * inset[1], third_sign * inset[2]],
                    [first_sign * inset[0], second_sign * extents[1], third_sign * inset[2]],
                    [first_sign * inset[0], second_sign * inset[1], third_sign * extents[2]],
                ]
                start = [add_vertex(point, normal) for point in points]
                indices.extend([start[0], start[1], start[2]])

    return _geometry(builder, positions, normals, indices, material)


HERO_CURVE_SIDES = 24
HERO_SPHERE_RINGS = 16


def add_cylinder(builder: BufferBuilder, radius: float, height: float, material: int, sides: int = 14) -> tuple[int, int, int, int, int, int]:
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


def add_uv_sphere(builder: BufferBuilder, radius: float, material: int, rings: int = 8, sides: int = 16) -> tuple[int, int, int, int, int, int]:
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


def add_ellipsoid(
    builder: BufferBuilder,
    scale: tuple[float, float, float],
    material: int,
    rings: int = 18,
    sides: int = 36,
) -> tuple[int, int, int, int, int, int]:
    """Build a smooth armored envelope with correct ellipsoid normals."""
    rings = max(rings, HERO_SPHERE_RINGS)
    sides = max(sides, HERO_CURVE_SIDES)
    sx, sy, sz = scale
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []
    for ring in range(rings + 1):
        latitude = -math.pi * 0.5 + math.pi * ring / rings
        latitude_cos = math.cos(latitude)
        latitude_sin = math.sin(latitude)
        for side in range(sides):
            longitude = math.tau * side / sides
            longitude_cos = math.cos(longitude)
            longitude_sin = math.sin(longitude)
            positions.extend([
                sx * latitude_cos * longitude_cos,
                sy * latitude_sin,
                sz * latitude_cos * longitude_sin,
            ])
            normal = [
                latitude_cos * longitude_cos / max(sx, 0.001),
                latitude_sin / max(sy, 0.001),
                latitude_cos * longitude_sin / max(sz, 0.001),
            ]
            normal_length = math.sqrt(sum(value * value for value in normal))
            normals.extend([value / max(normal_length, 0.001) for value in normal])
    for ring in range(rings):
        for side in range(sides):
            next_side = (side + 1) % sides
            a = ring * sides + side
            b = (ring + 1) * sides + side
            c = (ring + 1) * sides + next_side
            d = ring * sides + next_side
            indices.extend([a, b, c, a, c, d])
    return _geometry(builder, positions, normals, indices, material)


def add_torus(
    builder: BufferBuilder,
    major_radius: float,
    minor_radius: float,
    material: int,
    major_sides: int = 40,
    minor_sides: int = 12,
) -> tuple[int, int, int, int, int, int]:
    """Build a smooth protective collar or aperture ring for hero hardware."""
    major_sides = max(32, major_sides)
    minor_sides = max(10, minor_sides)
    major_radius = max(0.001, major_radius)
    minor_radius = max(0.001, minor_radius)
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []
    for major in range(major_sides):
        major_angle = math.tau * major / major_sides
        major_cos = math.cos(major_angle)
        major_sin = math.sin(major_angle)
        for minor in range(minor_sides):
            minor_angle = math.tau * minor / minor_sides
            minor_cos = math.cos(minor_angle)
            minor_sin = math.sin(minor_angle)
            ring_radius = major_radius + minor_radius * minor_cos
            positions.extend([
                ring_radius * major_cos,
                minor_radius * minor_sin,
                ring_radius * major_sin,
            ])
            normals.extend([
                minor_cos * major_cos,
                minor_sin,
                minor_cos * major_sin,
            ])
    for major in range(major_sides):
        next_major = (major + 1) % major_sides
        for minor in range(minor_sides):
            next_minor = (minor + 1) % minor_sides
            a = major * minor_sides + minor
            b = next_major * minor_sides + minor
            c = next_major * minor_sides + next_minor
            d = major * minor_sides + next_minor
            indices.extend([a, b, c, a, c, d])
    return _geometry(builder, positions, normals, indices, material)


def main() -> None:
    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    _build_texture_set()
    builder = BufferBuilder()

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
        material("Bulwark charcoal chassis", (0.045, 0.065, 0.072), 0.78, 0.42),
        material("Bulwark weathered steel", (0.22, 0.28, 0.29), 0.84, 0.34),
        material("Bulwark copper oxide", (0.29, 0.13, 0.075), 0.62, 0.54),
        material("Protection cyan", (0.03, 0.22, 0.25), 0.34, 0.22, (0.12, 0.9, 0.95)),
        material("Bulwark warm lamps", (0.42, 0.17, 0.04), 0.32, 0.34, (1.0, 0.28, 0.04)),
        material("Rubber and cable", (0.018, 0.022, 0.024), 0.05, 0.92),
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

    chassis = 0
    steel = 1
    oxide = 2
    cyan = 3
    warm = 4
    rubber = 5
    mesh_ids = {
        # The companion's body is a protective envelope, not a shipping crate.
        # Keep the named meshes and all sockets stable while giving the close
        # camera a continuous highlight roll across the chassis and armor.
        "Chassis": mesh("Chassis", add_ellipsoid(builder, (0.79, 0.43, 0.84), chassis)),
        "ChassisCore": mesh("ChassisCore", add_ellipsoid(builder, (0.66, 0.23, 0.70), oxide)),
        "Plate": mesh("Plate", add_ellipsoid(builder, (0.72, 0.13, 0.10), steel, 14, 32)),
        "Rail": mesh("Rail", add_box(builder, (0.12, 0.12, 1.24), oxide)),
        "Panel": mesh("Panel", add_beveled_box(builder, (0.72, 0.055, 0.46), chassis, 0.02)),
        "Corner": mesh("Corner", add_cylinder(builder, 0.12, 0.16, steel, 20)),
        "Leg": mesh("Leg", add_cylinder(builder, 0.12, 0.72, rubber, 20)),
        "Foot": mesh("Foot", add_beveled_box(builder, (0.28, 0.12, 0.42), oxide, 0.035)),
        "OpticHousing": mesh("OpticHousing", add_beveled_box(builder, (0.5, 0.27, 0.13), chassis, 0.035)),
        "Optic": mesh("Optic", add_uv_sphere(builder, 0.09, cyan)),
        "Shield": mesh("Shield", add_beveled_box(builder, (1.75, 0.72, 0.14), steel, 0.04)),
        "ShieldRib": mesh("ShieldRib", add_beveled_box(builder, (1.42, 0.12, 0.12), oxide, 0.025)),
        "Gun": mesh("Gun", add_cylinder(builder, 0.11, 1.18, chassis, 24)),
        "Muzzle": mesh("Muzzle", add_cylinder(builder, 0.15, 0.12, cyan, 24)),
        "EmitterSpine": mesh("EmitterSpine", add_cylinder(builder, 0.10, 0.64, oxide, 20)),
        "Emitter": mesh("Emitter", add_uv_sphere(builder, 0.14, cyan)),
        "EmitterGuardRail": mesh("EmitterGuardRail", add_cylinder(builder, 0.045, 0.74, steel, 18)),
        "EmitterGuardBrace": mesh("EmitterGuardBrace", add_beveled_box(builder, (0.12, 0.12, 0.46), oxide, 0.025)),
        "EmitterLensCap": mesh("EmitterLensCap", add_uv_sphere(builder, 0.17, cyan)),
        "EmitterCollar": mesh("EmitterCollar", add_torus(builder, 0.22, 0.036, steel, 40, 12)),
        "EmitterAperture": mesh("EmitterAperture", add_torus(builder, 0.135, 0.022, oxide, 36, 10)),
        "EmitterLensInset": mesh("EmitterLensInset", add_ellipsoid(builder, (0.105, 0.105, 0.034), cyan, 18, 36)),
        "EmitterFastener": mesh("EmitterFastener", add_uv_sphere(builder, 0.035, warm, 16, 32)),
        "ServiceFace": mesh("ServiceFace", add_beveled_box(builder, (0.56, 0.14, 0.38), chassis, 0.03)),
        "ServiceWindow": mesh("ServiceWindow", add_beveled_box(builder, (0.34, 0.035, 0.13), cyan, 0.012)),
        "ServiceFastener": mesh("ServiceFastener", add_cylinder(builder, 0.028, 0.035, warm, 20)),
        "Crown": mesh("Crown", add_beveled_box(builder, (0.76, 0.12, 0.2), oxide, 0.025)),
        "Fin": mesh("Fin", add_beveled_box(builder, (0.14, 0.42, 0.64), steel, 0.035)),
        "Lamp": mesh("Lamp", add_uv_sphere(builder, 0.07, warm)),
        "Cable": mesh("Cable", add_cylinder(builder, 0.035, 0.7, rubber, 12)),
        "Fastener": mesh("Fastener", add_cylinder(builder, 0.045, 0.04, warm, 20)),
        "ServiceLatch": mesh("ServiceLatch", add_cylinder(builder, 0.035, 0.055, steel, 20)),
        "ShoulderRail": mesh("ShoulderRail", add_beveled_box(builder, (0.12, 0.10, 0.72), steel, 0.022)),
        "FootPlate": mesh("FootPlate", add_beveled_box(builder, (0.38, 0.045, 0.30), steel, 0.016)),
        "ActuatorRing": mesh("ActuatorRing", add_torus(builder, 0.12, 0.025, steel, 36, 12)),
        "ActuatorCap": mesh("ActuatorCap", add_cylinder(builder, 0.095, 0.065, oxide, 24)),
        "HeatPanel": mesh("HeatPanel", add_beveled_box(builder, (0.42, 0.055, 0.52), oxide, 0.022)),
        "HeatLouver": mesh("HeatLouver", add_beveled_box(builder, (0.31, 0.035, 0.045), steel, 0.012)),
        "WindowFrame": mesh("WindowFrame", add_beveled_box(builder, (0.46, 0.03, 0.21), steel, 0.018)),
        "FrontVisor": mesh("FrontVisor", add_beveled_box(builder, (0.62, 0.12, 0.18), chassis, 0.028)),
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
    node_name_counts = {"BulwarkModel": 1}

    def add_node(
        name: str,
        mesh_id: int | None = None,
        translation: Sequence[float] = (0.0, 0.0, 0.0),
        rotation: Sequence[float] = (0.0, 0.0, 0.0),
        extras: dict | None = None,
        parent: int = 0,
    ) -> int:
        occurrence = node_name_counts.get(name, 0) + 1
        node_name_counts[name] = occurrence
        unique_name = name if occurrence == 1 else f"{name}{occurrence:02d}"
        entry: dict = {"name": unique_name, "translation": list(translation)}
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
            side_name = "Left" if side < 0.0 else "Right"
            position_name = "Front" if front < 0.0 else "Rear"
            add_node("ChassisCornerCap", mesh_ids["Corner"], (side * 0.69, 0.85, front * 0.68))
            leg_angle = side * 0.2
            leg_translation = (side * 0.54, 0.43, front * 0.48)
            leg_index = add_node(
                f"Leg{position_name}{side_name}",
                mesh_ids["Leg"],
                leg_translation,
                rotation=(0.0, 0.0, leg_angle),
                extras={"articulation": "locomotion_leg"},
            )
            world_delta_x = side * 0.12
            world_delta_y = -0.31
            foot_local = (
                math.cos(leg_angle) * world_delta_x + math.sin(leg_angle) * world_delta_y,
                -math.sin(leg_angle) * world_delta_x + math.cos(leg_angle) * world_delta_y,
                0.0,
            )
            add_node(
                f"Foot{position_name}{side_name}",
                mesh_ids["Foot"],
                foot_local,
                rotation=(0.0, 0.0, side * 0.04 - leg_angle),
                extras={"articulation": "locomotion_foot"},
                parent=leg_index,
            )
    add_node("OpticHousing", mesh_ids["OpticHousing"], (0.0, 1.16, -0.94))
    add_node("Sensor", mesh_ids["Optic"], (0.0, 1.15, -1.04), extras={"socket_type": "sensor"})
    add_node("OpticLens", mesh_ids["Optic"], (0.0, 1.15, -1.10), extras={"socket_type": "optic"})
    add_node("BulwarkFrontPlate", mesh_ids["Plate"], (0.0, 1.02, -1.01), rotation=(-0.06, 0.0, 0.0))
    add_node("RearShield", mesh_ids["Shield"], (0.0, 0.78, 0.78))
    add_node("ShieldRib", mesh_ids["ShieldRib"], (0.0, 1.04, 0.86))
    for side in (-1.0, 1.0):
        side_name = "Left" if side < 0.0 else "Right"
        add_node("ShoulderPlate", mesh_ids["Plate"], (side * 0.87, 1.0, -0.04), rotation=(0.0, 0.0, side * 0.1))
        gun_index = add_node(
            f"BulwarkGun{side_name}",
            mesh_ids["Gun"],
            (side * 0.3, 1.38, -0.82),
            rotation=(math.pi * 0.5, 0.0, 0.0),
            extras={"socket_type": "weapon_mount", "articulation": "recoil_assembly"},
        )
        barrel_name = "WeaponBarrel" if side < 0.0 else "WeaponBarrelRight"
        muzzle_name = "WeaponMuzzle" if side < 0.0 else "WeaponMuzzleRight"
        barrel_index = add_node(
            barrel_name,
            mesh_ids["Gun"],
            (0.0, -0.28, 0.0),
            extras={"assembly_side": side_name.lower()},
            parent=gun_index,
        )
        add_node(
            muzzle_name,
            mesh_ids["Muzzle"],
            (0.0, -0.45, 0.0),
            extras={"socket_type": "weapon_muzzle", "assembly_side": side_name.lower()},
            parent=barrel_index,
        )
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
    # The protection instrument is a real manufactured projector: a nested
    # collar, front aperture and inset lens give the companion's signature
    # hardware a readable focal assembly instead of a bare glowing sphere.
    add_node("BulwarkEmitterCollar", mesh_ids["EmitterCollar"], (0.0, 2.3, 0.5), extras={"surface": "projector_collar"})
    add_node("BulwarkEmitterAperture", mesh_ids["EmitterAperture"], (0.0, 2.3, 0.29), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "projector_aperture"})
    add_node("BulwarkEmitterLensInset", mesh_ids["EmitterLensInset"], (0.0, 2.3, 0.265), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"socket_type": "protection_emitter"})
    for index, (x, y) in enumerate(((-0.17, 2.42), (0.17, 2.42), (0.0, 2.17))):
        add_node("BulwarkEmitterFastener%02d" % index, mesh_ids["EmitterFastener"], (x, y, 0.285), extras={"surface": "projector_fastener"})
    add_node("BulwarkServiceFace", mesh_ids["ServiceFace"], (0.0, 1.03, -1.08), rotation=(0.0, 0.0, -0.04), extras={"surface": "front_service_face"})
    add_node("BulwarkServiceWindow", mesh_ids["ServiceWindow"], (0.0, 1.06, -1.16), rotation=(0.0, 0.0, -0.04))
    for side in (-1.0, 1.0):
        add_node("BulwarkServiceFastener", mesh_ids["ServiceFastener"], (side * 0.2, 1.17, -1.16), rotation=(math.pi * 0.5, 0.0, 0.0))
    # These authored nodes replace the production scene's former static
    # dressing pass. Their names remain explicit so attachment validation can
    # distinguish functional hardware from decorative chassis geometry.
    add_node("BulwarkServiceWindowFrame", mesh_ids["WindowFrame"], (0.0, 1.06, -1.14))
    add_node("BulwarkFrontSensorVisor", mesh_ids["FrontVisor"], (0.0, 1.48, -0.98), rotation=(-0.04, 0.0, 0.0))
    for side in (-1.0, 1.0):
        side_name = "Left" if side < 0.0 else "Right"
        add_node(
            f"BulwarkServiceLatch{side_name}",
            mesh_ids["ServiceLatch"],
            (side * 0.22, 1.10, -1.31),
            rotation=(math.pi * 0.5, 0.0, 0.0),
        )
        add_node(
            f"BulwarkShoulderRail{side_name}",
            mesh_ids["ShoulderRail"],
            (side * 0.70, 1.43, -0.34),
            rotation=(0.0, 0.0, side * 0.08),
        )
        add_node(f"BulwarkFootPlate{side_name}", mesh_ids["FootPlate"], (side * 0.68, 0.18, -0.66))
        add_node(
            f"BulwarkActuatorRing{side_name}",
            mesh_ids["ActuatorRing"],
            (side * 0.98, 0.90, -0.45),
            rotation=(math.pi * 0.5, 0.0, 0.0),
        )
        add_node(
            f"BulwarkActuatorCap{side_name}",
            mesh_ids["ActuatorCap"],
            (side * 0.98, 0.90, -0.49),
            rotation=(math.pi * 0.5, 0.0, 0.0),
        )
        add_node(
            f"BulwarkSideHeatPanel{side_name}",
            mesh_ids["HeatPanel"],
            (side * 0.84, 1.0, 0.48),
            rotation=(0.0, side * math.pi * 0.5, 0.0),
        )
        for louver_index, height in enumerate((0.86, 1.0, 1.14), start=1):
            add_node(
                "BulwarkRadiatorLouver",
                mesh_ids["HeatLouver"],
                (side * 1.105, height, 0.48),
                rotation=(0.0, side * math.pi * 0.5, 0.0),
                extras={"assembly_side": side_name.lower(), "louver_slot": louver_index},
            )
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
            ("BulwarkShieldEmitter", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.0, -0.025)) + quat((0.0, 0.0, 0.035)) + quat((0.0, 0.0, -0.025))),
            ("BulwarkEmitterGuardL", "rotation", [0.0, 0.8, 1.6], quat((0.0, -0.08, -0.22)) + quat((0.04, -0.12, -0.28)) + quat((0.0, -0.08, -0.22))),
            ("BulwarkEmitterGuardR", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.08, 0.28)) + quat((-0.04, 0.12, 0.34)) + quat((0.0, 0.08, 0.28))),
            ("BulwarkEmitterCollar", "rotation", [0.0, 0.8, 1.6], quat((0.0, 0.0, -0.018)) + quat((0.0, 0.04, 0.018)) + quat((0.0, 0.0, -0.018))),
            ("BulwarkEmitterAperture", "rotation", [0.0, 0.8, 1.6], quat((math.pi * 0.5, 0.0, -0.025)) + quat((math.pi * 0.5, 0.0, 0.035)) + quat((math.pi * 0.5, 0.0, -0.025))),
        ]),
        animation("Walk", [
            ("LegFrontLeft", "rotation", [0.0, 0.22, 0.44], quat((0.22, 0.0, -0.2)) + quat((-0.22, 0.0, -0.2)) + quat((0.22, 0.0, -0.2))),
            ("FootFrontLeft", "rotation", [0.0, 0.22, 0.44], quat((-0.12, 0.0, 0.16)) + quat((0.12, 0.0, 0.16)) + quat((-0.12, 0.0, 0.16))),
            ("LegRearLeft", "rotation", [0.0, 0.22, 0.44], quat((-0.22, 0.0, -0.2)) + quat((0.22, 0.0, -0.2)) + quat((-0.22, 0.0, -0.2))),
            ("FootRearLeft", "rotation", [0.0, 0.22, 0.44], quat((0.12, 0.0, 0.16)) + quat((-0.12, 0.0, 0.16)) + quat((0.12, 0.0, 0.16))),
            ("LegFrontRight", "rotation", [0.0, 0.22, 0.44], quat((-0.22, 0.0, 0.2)) + quat((0.22, 0.0, 0.2)) + quat((-0.22, 0.0, 0.2))),
            ("FootFrontRight", "rotation", [0.0, 0.22, 0.44], quat((0.12, 0.0, -0.16)) + quat((-0.12, 0.0, -0.16)) + quat((0.12, 0.0, -0.16))),
            ("LegRearRight", "rotation", [0.0, 0.22, 0.44], quat((0.22, 0.0, 0.2)) + quat((-0.22, 0.0, 0.2)) + quat((0.22, 0.0, 0.2))),
            ("FootRearRight", "rotation", [0.0, 0.22, 0.44], quat((-0.12, 0.0, -0.16)) + quat((0.12, 0.0, -0.16)) + quat((-0.12, 0.0, -0.16))),
            ("Chassis", "rotation", [0.0, 0.22, 0.44], quat((0.035, 0.0, 0.0)) + quat((-0.035, 0.0, 0.0)) + quat((0.035, 0.0, 0.0))),
            ("CompanionCrown", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.04, 0.0)) + quat((0.0, -0.04, 0.0)) + quat((0.0, 0.04, 0.0))),
            ("BulwarkShieldEmitter", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.0, -0.025)) + quat((0.12, 0.0, -0.08)) + quat((0.0, 0.0, -0.025))),
            ("BulwarkEmitterGuardL", "rotation", [0.0, 0.22, 0.44], quat((0.0, -0.08, -0.22)) + quat((0.14, -0.16, -0.32)) + quat((0.0, -0.08, -0.22))),
            ("BulwarkEmitterGuardR", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.08, 0.28)) + quat((-0.14, 0.16, 0.38)) + quat((0.0, 0.08, 0.28))),
            ("BulwarkEmitterCollar", "rotation", [0.0, 0.22, 0.44], quat((0.0, 0.0, -0.018)) + quat((0.0, 0.12, 0.02)) + quat((0.0, 0.0, -0.018))),
            ("BulwarkEmitterAperture", "rotation", [0.0, 0.22, 0.44], quat((math.pi * 0.5, 0.0, -0.025)) + quat((math.pi * 0.5, 0.0, 0.08)) + quat((math.pi * 0.5, 0.0, -0.025))),
        ]),
        animation("Fire", [
            ("BulwarkGunLeft", "translation", [0.0, 0.08, 0.18], [-0.3, 1.38, -0.82, -0.3, 1.38, -0.74, -0.3, 1.38, -0.82]),
            ("BulwarkGunRight", "translation", [0.0, 0.08, 0.18], [0.3, 1.38, -0.82, 0.3, 1.38, -0.74, 0.3, 1.38, -0.82]),
            ("Sensor", "rotation", [0.0, 0.08, 0.18], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.12, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("ShieldRib", "rotation", [0.0, 0.08, 0.18], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, -0.04)) + quat((0.0, 0.0, 0.0))),
            ("BulwarkShieldEmitter", "rotation", [0.0, 0.08, 0.18], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.16, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("BulwarkEmitterGuardL", "rotation", [0.0, 0.08, 0.18], quat((0.0, -0.08, -0.22)) + quat((-0.12, -0.16, -0.34)) + quat((0.0, -0.08, -0.22))),
            ("BulwarkEmitterGuardR", "rotation", [0.0, 0.08, 0.18], quat((0.0, 0.08, 0.28)) + quat((0.12, 0.16, 0.4)) + quat((0.0, 0.08, 0.28))),
            ("BulwarkEmitterCollar", "rotation", [0.0, 0.08, 0.18], quat((0.0, 0.0, -0.018)) + quat((0.0, 0.18, 0.018)) + quat((0.0, 0.0, -0.018))),
            ("BulwarkEmitterAperture", "rotation", [0.0, 0.08, 0.18], quat((math.pi * 0.5, 0.0, -0.025)) + quat((math.pi * 0.5, 0.0, 0.16)) + quat((math.pi * 0.5, 0.0, -0.025))),
            ("BulwarkRadiator", "rotation", [0.0, 0.08, 0.18], quat((0.0, 0.0, 0.0)) + quat((-0.1, 0.0, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Hit", [
            ("BulwarkModel", "translation", [0.0, 0.10, 0.24], [0.0, 0.0, 0.0, 0.0, 0.0, 0.12, 0.0, 0.0, 0.0]),
            ("Sensor", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((-0.15, 0.08, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("BulwarkShieldEmitter", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, 0.0)) + quat((0.0, -0.16, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("BulwarkEmitterGuardL", "rotation", [0.0, 0.10, 0.24], quat((0.0, -0.08, -0.22)) + quat((0.14, -0.14, -0.3)) + quat((0.0, -0.08, -0.22))),
            ("BulwarkEmitterGuardR", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.08, 0.28)) + quat((-0.14, 0.14, 0.36)) + quat((0.0, 0.08, 0.28))),
            ("BulwarkEmitterCollar", "rotation", [0.0, 0.10, 0.24], quat((0.0, 0.0, -0.018)) + quat((0.0, -0.14, 0.018)) + quat((0.0, 0.0, -0.018))),
            ("BulwarkEmitterAperture", "rotation", [0.0, 0.10, 0.24], quat((math.pi * 0.5, 0.0, -0.025)) + quat((math.pi * 0.5, 0.0, -0.12)) + quat((math.pi * 0.5, 0.0, -0.025))),
        ]),
        animation("Retreat", [
            ("BulwarkModel", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.0, 0.12)) + quat((0.0, 0.0, 0.0))),
            ("Sensor", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.0)) + quat((0.0, -0.12, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("BulwarkShieldEmitter", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.2, 0.0)) + quat((0.0, 0.0, 0.0))),
            ("BulwarkEmitterGuardL", "rotation", [0.0, 0.28, 0.56], quat((0.0, -0.08, -0.22)) + quat((-0.2, -0.18, -0.34)) + quat((0.0, -0.08, -0.22))),
            ("BulwarkEmitterGuardR", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.08, 0.28)) + quat((0.2, 0.18, 0.4)) + quat((0.0, 0.08, 0.28))),
            ("BulwarkEmitterCollar", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, -0.018)) + quat((0.0, 0.20, 0.02)) + quat((0.0, 0.0, -0.018))),
            ("BulwarkEmitterAperture", "rotation", [0.0, 0.28, 0.56], quat((math.pi * 0.5, 0.0, -0.025)) + quat((math.pi * 0.5, 0.0, 0.20)) + quat((math.pi * 0.5, 0.0, -0.025))),
            ("CompanionCrownMast", "rotation", [0.0, 0.28, 0.56], quat((0.0, 0.0, 0.0)) + quat((0.14, 0.0, 0.0)) + quat((0.0, 0.0, 0.0))),
        ]),
        animation("Death", [
            ("BulwarkModel", "translation", [0.0, 0.18, 0.42], [0.0, 0.0, 0.0, 0.0, -0.08, 0.0, 0.0, -0.22, 0.0]),
            ("BulwarkModel", "rotation", [0.0, 0.18, 0.42], quat((0.0, 0.0, 0.0)) + quat((0.0, 0.16, 0.22)) + quat((0.0, 0.22, 0.32))),
            ("BulwarkShieldEmitter", "rotation", [0.0, 0.18, 0.42], quat((0.0, 0.0, 0.0)) + quat((0.18, 0.0, 0.0)) + quat((0.28, 0.0, 0.0))),
            ("BulwarkRadiator", "rotation", [0.0, 0.18, 0.42], quat((0.0, 0.0, 0.0)) + quat((-0.16, 0.0, 0.0)) + quat((-0.26, 0.0, 0.0))),
            ("BulwarkEmitterCollar", "rotation", [0.0, 0.18, 0.42], quat((0.0, 0.0, -0.018)) + quat((0.18, 0.0, 0.02)) + quat((0.28, 0.0, 0.02))),
            ("BulwarkEmitterAperture", "rotation", [0.0, 0.18, 0.42], quat((math.pi * 0.5, 0.0, -0.025)) + quat((math.pi * 0.5, 0.18, 0.04)) + quat((math.pi * 0.5, 0.28, 0.06))),
        ]),
    ]

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Bulwark asset builder"},
        "scene": 0,
        "scenes": [{"name": "Bulwark", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "samplers": [{
            "name": "Bulwark repeating PBR sampler",
            "magFilter": 9729,
            "minFilter": 9987,
            "wrapS": 10497,
            "wrapT": 10497,
        }],
        "images": [
            {"name": "Bulwark base color", "uri": TEXTURE_PATHS["base_color"].name},
            {"name": "Bulwark tangent-space normal", "uri": TEXTURE_PATHS["normal"].name},
            {"name": "Bulwark occlusion roughness metallic", "uri": TEXTURE_PATHS["orm"].name},
            {"name": "Bulwark emissive mask", "uri": TEXTURE_PATHS["emissive"].name},
        ],
        "textures": [
            {"name": "Bulwark base color", "sampler": 0, "source": 0},
            {"name": "Bulwark tangent-space normal", "sampler": 0, "source": 1},
            {"name": "Bulwark occlusion roughness metallic", "sampler": 0, "source": 2},
            {"name": "Bulwark emissive mask", "sampler": 0, "source": 3},
        ],
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "animations": animations,
        "extras": {
            "ironwright_asset_id": "bulwark.companion.v1",
            "required_nodes": ["BulwarkModel", "Sensor", "OpticLens", "WeaponMuzzle", "BulwarkShieldEmitter", "BulwarkEmitterGuardL", "BulwarkEmitterGuardR", "BulwarkEmitterCollar", "BulwarkEmitterAperture", "BulwarkEmitterLensInset", "BulwarkServiceFace", "BulwarkServiceWindow", "ProductionAssetMarker"],
            "animation_clips": ["Idle", "Walk", "Fire", "Hit", "Retreat", "Death"],
            "material_contract": "textured_metallic_roughness_pbr",
            "texture_resolution": TEXTURE_SIZE,
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
