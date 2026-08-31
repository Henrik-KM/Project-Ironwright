"""Build Project Ironwright's deterministic shared organic PBR texture library.

The maps deliberately contain only broad, seamless surface variation. Family
colour and identity remain authored by each glTF material's factors, while this
library supplies stable shell/tissue relief, packed ORM response, and a sparse
signal mask suitable for tactical-camera mip levels.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import struct
import zlib
from pathlib import Path
from typing import Iterable


TEXTURE_SIZE = 1024
SURFACE_PROFILE = "shared_organic_pbr_v1"
SOURCE_DIR = Path(__file__).resolve().parent
DEFAULT_OUTPUT_DIR = SOURCE_DIR.parent / "textures"
TEXTURE_FILENAMES = {
    "shell_base_color": "organic_shell_base_color.png",
    "shell_normal": "organic_shell_normal.png",
    "shell_orm": "organic_shell_orm.png",
    "tissue_base_color": "organic_tissue_base_color.png",
    "tissue_normal": "organic_tissue_normal.png",
    "tissue_orm": "organic_tissue_orm.png",
    "emissive": "organic_emissive.png",
}

# Frequencies are deliberately capped at seven cycles across the tile. This
# keeps every repeating signal well below the dense weave/checker range that
# can shimmer at the production tactical-camera distance.
SHELL_WAVES = (
    (0.420, 2, 1, 0.31),
    (0.250, 1, -3, 1.47),
    (0.170, 4, 2, 2.36),
    (0.090, 5, -1, 4.10),
    (0.055, 7, 3, 0.92),
)
TISSUE_WAVES = (
    (0.480, 1, 2, 0.58),
    (0.260, 3, -1, 2.04),
    (0.140, 2, 4, 3.37),
    (0.075, 5, 2, 4.61),
    (0.045, 6, -3, 1.19),
)


def _clamp01(value: float) -> float:
    return max(0.0, min(1.0, value))


def _channel(value: float) -> int:
    return max(0, min(255, round(_clamp01(value) * 255.0)))


def _smoothstep(edge0: float, edge1: float, value: float) -> float:
    if edge0 == edge1:
        return 0.0
    amount = _clamp01((value - edge0) / (edge1 - edge0))
    return amount * amount * (3.0 - 2.0 * amount)


def _wave_field(
    u: float,
    v: float,
    waves: Iterable[tuple[float, int, int, float]],
) -> tuple[float, float, float]:
    """Return a seamless broad field and its analytical UV derivatives."""
    value = 0.0
    derivative_u = 0.0
    derivative_v = 0.0
    for amplitude, frequency_u, frequency_v, phase_offset in waves:
        phase = math.tau * (frequency_u * u + frequency_v * v) + phase_offset
        sine = math.sin(phase)
        cosine = math.cos(phase)
        value += amplitude * sine
        derivative_u += amplitude * cosine * math.tau * frequency_u
        derivative_v += amplitude * cosine * math.tau * frequency_v
    return value, derivative_u, derivative_v


def _normal_pixel(derivative_u: float, derivative_v: float, strength: float) -> tuple[int, int, int, int]:
    normal_x = -derivative_u * strength
    normal_y = -derivative_v * strength
    normal_z = 1.0
    length = math.sqrt(normal_x * normal_x + normal_y * normal_y + normal_z * normal_z)
    return (
        _channel(normal_x / length * 0.5 + 0.5),
        _channel(normal_y / length * 0.5 + 0.5),
        _channel(normal_z / length * 0.5 + 0.5),
        255,
    )


def _toroidal_delta(value: float, centre: float) -> float:
    return (value - centre + 0.5) % 1.0 - 0.5


def _signal_island(u: float, v: float, centre_u: float, centre_v: float, radius_u: float, radius_v: float) -> float:
    delta_u = _toroidal_delta(u, centre_u) / radius_u
    delta_v = _toroidal_delta(v, centre_v) / radius_v
    distance = math.sqrt(delta_u * delta_u + delta_v * delta_v)
    if distance >= 1.0:
        return 0.0
    return 1.0 - _smoothstep(0.0, 1.0, distance)


def _png_chunk(chunk_type: bytes, data: bytes) -> bytes:
    payload = chunk_type + data
    return struct.pack(">I", len(data)) + payload + struct.pack(">I", zlib.crc32(payload) & 0xFFFFFFFF)


def _write_png_rgba(path: Path, raw_rows: bytes) -> None:
    header = struct.pack(">IIBBBBB", TEXTURE_SIZE, TEXTURE_SIZE, 8, 6, 0, 0, 0)
    payload = (
        b"\x89PNG\r\n\x1a\n"
        + _png_chunk(b"IHDR", header)
        + _png_chunk(b"IDAT", zlib.compress(raw_rows, level=9))
        + _png_chunk(b"IEND", b"")
    )
    path.write_bytes(payload)


def _percentile(histogram: list[int], fraction: float, scale: float = 1.0) -> float:
    population = sum(histogram)
    target = max(0, math.ceil(population * fraction) - 1)
    cumulative = 0
    for index, count in enumerate(histogram):
        cumulative += count
        if cumulative > target:
            return index * scale
    return (len(histogram) - 1) * scale


def _channel_summary(histogram: list[int]) -> dict[str, float | int]:
    population = sum(histogram)
    populated = [index for index, count in enumerate(histogram) if count]
    return {
        "min": populated[0],
        "max": populated[-1],
        "mean": round(sum(index * count for index, count in enumerate(histogram)) / population, 4),
    }


def _difference_summary(histogram: list[int]) -> dict[str, float]:
    population = sum(histogram)
    return {
        "mean": round(sum(index * count for index, count in enumerate(histogram)) / population, 4),
        "p95": _percentile(histogram, 0.95),
        "p99": _percentile(histogram, 0.99),
    }


def build_texture_library(output_dir: Path) -> dict[str, object]:
    """Write all seven maps and return deterministic hashes and signal statistics."""
    output_dir.mkdir(parents=True, exist_ok=True)
    raw_rows = {key: bytearray() for key in TEXTURE_FILENAMES}
    channel_histograms = {key: [[0] * 256 for _ in range(3)] for key in TEXTURE_FILENAMES}
    base_difference_histograms = {
        "shell_base_color": [0] * 256,
        "tissue_base_color": [0] * 256,
    }
    normal_joint_histograms = {
        "shell_normal": [0] * (256 * 256),
        "tissue_normal": [0] * (256 * 256),
    }
    normal_length_histograms = {
        "shell_normal": [0] * 2049,
        "tissue_normal": [0] * 2049,
    }
    normal_difference_histograms = {
        "shell_normal": [0] * 2049,
        "tissue_normal": [0] * 2049,
    }
    previous_base_rows = {
        "shell_base_color": [0] * TEXTURE_SIZE,
        "tissue_base_color": [0] * TEXTURE_SIZE,
    }
    previous_normal_rows = {
        "shell_normal": [(0.0, 0.0)] * TEXTURE_SIZE,
        "tissue_normal": [(0.0, 0.0)] * TEXTURE_SIZE,
    }

    for y in range(TEXTURE_SIZE):
        for output in raw_rows.values():
            output.append(0)  # PNG filter type: None
        current_base_rows = {key: [0] * TEXTURE_SIZE for key in previous_base_rows}
        current_normal_rows = {key: [(0.0, 0.0)] * TEXTURE_SIZE for key in previous_normal_rows}
        for x in range(TEXTURE_SIZE):
            u = (x + 0.5) / TEXTURE_SIZE
            v = (y + 0.5) / TEXTURE_SIZE
            shell_height, shell_du, shell_dv = _wave_field(u, v, SHELL_WAVES)
            tissue_height, tissue_du, tissue_dv = _wave_field(u, v, TISSUE_WAVES)
            slow_a = math.sin(math.tau * (u - 2.0 * v) + 0.72)
            slow_b = math.cos(math.tau * (3.0 * u + v) + 1.19)
            slow_c = math.sin(math.tau * (2.0 * u + 3.0 * v) + 2.41)

            shell_luminance = 0.735 + shell_height * 0.083 + slow_a * 0.025 - slow_b * 0.014
            tissue_luminance = 0.755 + tissue_height * 0.092 + slow_b * 0.027 + slow_c * 0.012
            shell_base = (
                _channel(shell_luminance * 0.945 + slow_c * 0.008),
                _channel(shell_luminance * 0.982 + slow_a * 0.006),
                _channel(shell_luminance * 0.952 - slow_b * 0.006),
                255,
            )
            tissue_base = (
                _channel(tissue_luminance * 1.018 + slow_a * 0.008),
                _channel(tissue_luminance * 0.952 + slow_c * 0.005),
                _channel(tissue_luminance * 0.922 - slow_b * 0.005),
                255,
            )
            shell_normal = _normal_pixel(shell_du, shell_dv, 0.0115)
            tissue_normal = _normal_pixel(tissue_du, tissue_dv, 0.0080)

            shell_occlusion = 0.925 - abs(shell_height) * 0.058 + slow_b * 0.018
            shell_roughness = 0.655 + (slow_a * 0.5 + 0.5) * 0.165 + abs(shell_height) * 0.038
            mineral_field = (slow_c * 0.5 + 0.5) * (slow_b * 0.5 + 0.5)
            shell_metallic = _smoothstep(0.86, 0.98, mineral_field) * 0.024
            shell_orm = (
                _channel(shell_occlusion),
                _channel(shell_roughness),
                _channel(shell_metallic),
                255,
            )

            tissue_occlusion = 0.905 - abs(tissue_height) * 0.072 + slow_a * 0.020
            tissue_roughness = 0.715 + (slow_c * 0.5 + 0.5) * 0.155 + abs(tissue_height) * 0.040
            tissue_orm = (_channel(tissue_occlusion), _channel(tissue_roughness), 0, 255)

            signal = max(
                _signal_island(u, v, 0.18, 0.22, 0.060, 0.045),
                _signal_island(u, v, 0.72, 0.29, 0.075, 0.052),
                _signal_island(u, v, 0.46, 0.75, 0.062, 0.078),
                _signal_island(u, v, 0.86, 0.73, 0.047, 0.058),
            )
            signal *= 0.93 + 0.07 * math.sin(math.tau * (2.0 * u + v) + 0.44)
            signal_value = _channel(signal)
            emissive = (signal_value, signal_value, signal_value, 255)

            pixels = {
                "shell_base_color": shell_base,
                "shell_normal": shell_normal,
                "shell_orm": shell_orm,
                "tissue_base_color": tissue_base,
                "tissue_normal": tissue_normal,
                "tissue_orm": tissue_orm,
                "emissive": emissive,
            }
            for key, pixel in pixels.items():
                raw_rows[key].extend(pixel)
                for channel_index in range(3):
                    channel_histograms[key][channel_index][pixel[channel_index]] += 1

            for key, pixel in (("shell_base_color", shell_base), ("tissue_base_color", tissue_base)):
                luminance = round((pixel[0] + pixel[1] + pixel[2]) / 3.0)
                current_base_rows[key][x] = luminance
                if x > 0:
                    base_difference_histograms[key][abs(luminance - current_base_rows[key][x - 1])] += 1
                if y > 0:
                    base_difference_histograms[key][abs(luminance - previous_base_rows[key][x])] += 1

            for key, pixel in (("shell_normal", shell_normal), ("tissue_normal", tissue_normal)):
                normal_x = pixel[0] / 127.5 - 1.0
                normal_y = pixel[1] / 127.5 - 1.0
                normal_z = pixel[2] / 127.5 - 1.0
                current_normal_rows[key][x] = (normal_x, normal_y)
                normal_joint_histograms[key][pixel[0] * 256 + pixel[1]] += 1
                length = math.sqrt(normal_x * normal_x + normal_y * normal_y + normal_z * normal_z)
                length_bin = min(2048, round(length / 1.2 * 2048))
                normal_length_histograms[key][length_bin] += 1
                if x > 0:
                    left_x, left_y = current_normal_rows[key][x - 1]
                    difference = math.hypot(normal_x - left_x, normal_y - left_y)
                    normal_difference_histograms[key][min(2048, round(difference / 0.2 * 2048))] += 1
                if y > 0:
                    above_x, above_y = previous_normal_rows[key][x]
                    difference = math.hypot(normal_x - above_x, normal_y - above_y)
                    normal_difference_histograms[key][min(2048, round(difference / 0.2 * 2048))] += 1

        previous_base_rows = current_base_rows
        previous_normal_rows = current_normal_rows

    report_files: dict[str, object] = {}
    for key, filename in TEXTURE_FILENAMES.items():
        path = output_dir / filename
        _write_png_rgba(path, bytes(raw_rows[key]))
        entry: dict[str, object] = {
            "bytes": path.stat().st_size,
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest().upper(),
            "channels": {
                channel_name: _channel_summary(channel_histograms[key][channel_index])
                for channel_index, channel_name in enumerate(("r", "g", "b"))
            },
        }
        if key in base_difference_histograms:
            entry["adjacent_luminance_delta"] = _difference_summary(base_difference_histograms[key])
        if key in normal_joint_histograms:
            xy_values: list[tuple[float, int]] = []
            for packed, count in enumerate(normal_joint_histograms[key]):
                if count:
                    red, green = divmod(packed, 256)
                    normal_x = red / 127.5 - 1.0
                    normal_y = green / 127.5 - 1.0
                    xy_values.append((math.hypot(normal_x, normal_y), count))
            xy_values.sort()
            population = sum(count for _, count in xy_values)

            def xy_percentile(fraction: float) -> float:
                target = max(0, math.ceil(population * fraction) - 1)
                cumulative = 0
                for value, count in xy_values:
                    cumulative += count
                    if cumulative > target:
                        return value
                return xy_values[-1][0]

            entry["normal_signal"] = {
                "xy_mean": round(sum(value * count for value, count in xy_values) / population, 5),
                "xy_p95": round(xy_percentile(0.95), 5),
                "xy_p99": round(xy_percentile(0.99), 5),
                "xy_max": round(xy_values[-1][0], 5),
                "length_p01": round(_percentile(normal_length_histograms[key], 0.01, 1.2 / 2048), 5),
                "length_p99": round(_percentile(normal_length_histograms[key], 0.99, 1.2 / 2048), 5),
                "neighbor_xy_delta": _difference_summary(normal_difference_histograms[key]),
            }
            neighbor = entry["normal_signal"]["neighbor_xy_delta"]  # type: ignore[index]
            neighbor["mean"] = round(neighbor["mean"] * 0.2 / 2048, 6)  # type: ignore[index]
            neighbor["p95"] = round(neighbor["p95"] * 0.2 / 2048, 6)  # type: ignore[index]
            neighbor["p99"] = round(neighbor["p99"] * 0.2 / 2048, 6)  # type: ignore[index]
        if key in ("shell_orm", "tissue_orm"):
            metallic_histogram = channel_histograms[key][2]
            entry["metallic_zero_fraction"] = round(metallic_histogram[0] / sum(metallic_histogram), 6)
        if key == "emissive":
            brightness_histogram = channel_histograms[key][0]
            population = sum(brightness_histogram)
            entry["dark_fraction_le_8"] = round(sum(brightness_histogram[:9]) / population, 6)
            entry["lit_fraction_ge_48"] = round(sum(brightness_histogram[48:]) / population, 6)
        report_files[filename] = entry

    return {
        "generator": "original_project_ironwright_deterministic_organic_surface_library",
        "surface_profile": SURFACE_PROFILE,
        "texture_size": TEXTURE_SIZE,
        "maximum_repeating_frequency_cycles": 7,
        "recommended_normal_scale_ceiling": {"shell": 0.35, "tissue": 0.22},
        "files": report_files,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Destination directory; defaults to the canonical shared texture folder.",
    )
    args = parser.parse_args()
    report = build_texture_library(args.output_dir.resolve())
    print(json.dumps(report, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
