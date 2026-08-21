#!/usr/bin/env python3
"""Generate Project Ironwright's original release texture and audio library.

The outputs use only Python's standard library. They are deterministic, contain
no third-party source material, and are intended to be committed after running
this script so normal Godot import and export remain straightforward.
"""

from __future__ import annotations

import argparse
import math
import random
import struct
import wave
import zlib
from pathlib import Path
from typing import Callable, Iterable

ROOT = Path(__file__).resolve().parents[1]
ASSET_ROOT = ROOT / "game" / "assets" / "release"
TEXTURE_ROOT = ASSET_ROOT / "textures"
AUDIO_ROOT = ASSET_ROOT / "audio"
TAU = math.tau
SAMPLE_RATE = 22_050


def clamp(value: float, low: float = 0.0, high: float = 255.0) -> int:
    return int(max(low, min(high, round(value))))


def hash_noise(x: int, y: int, seed: int) -> float:
    value = (x * 0x1F123BB5) ^ (y * 0x5F356495) ^ (seed * 0x9E3779B9)
    value ^= value >> 16
    value *= 0x7FEB352D
    value ^= value >> 15
    value *= 0x846CA68B
    value ^= value >> 16
    return (value & 0xFFFF) / 32767.5 - 1.0


def smooth_noise(x: float, y: float, seed: int, scale: float = 16.0) -> float:
    gx = x / scale
    gy = y / scale
    x0 = math.floor(gx)
    y0 = math.floor(gy)
    tx = gx - x0
    ty = gy - y0
    tx = tx * tx * (3.0 - 2.0 * tx)
    ty = ty * ty * (3.0 - 2.0 * ty)
    n00 = hash_noise(x0, y0, seed)
    n10 = hash_noise(x0 + 1, y0, seed)
    n01 = hash_noise(x0, y0 + 1, seed)
    n11 = hash_noise(x0 + 1, y0 + 1, seed)
    a = n00 * (1.0 - tx) + n10 * tx
    b = n01 * (1.0 - tx) + n11 * tx
    return a * (1.0 - ty) + b * ty


def fractal_noise(x: float, y: float, seed: int) -> float:
    return (
        smooth_noise(x, y, seed, 30.0) * 0.54
        + smooth_noise(x, y, seed + 11, 12.0) * 0.31
        + smooth_noise(x, y, seed + 29, 4.5) * 0.15
    )


def png_chunk(kind: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)


def write_png(path: Path, pixel: Callable[[int, int], tuple[int, int, int, int]], size: int = 256) -> None:
    rows = bytearray()
    for y in range(size):
        rows.append(0)
        for x in range(size):
            rows.extend(pixel(x, y))
    header = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    data = b"\x89PNG\r\n\x1a\n" + png_chunk(b"IHDR", header) + png_chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + png_chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def asphalt(x: int, y: int) -> tuple[int, int, int, int]:
    n = fractal_noise(x, y, 101)
    aggregate = abs(hash_noise(x // 2, y // 2, 17))
    wet = 9.0 * math.sin((x + y) * TAU / 256.0) + 6.0 * math.cos((x - y) * TAU / 128.0)
    crack = abs(math.sin((x * 0.047 + smooth_noise(x, y, 7, 24.0) * 2.2))) < 0.027
    base = 45 + n * 18 + wet * 0.35 + aggregate * 7
    if crack:
        base -= 24
    return clamp(base - 5), clamp(base + 1), clamp(base + 3), 255


def brick(x: int, y: int) -> tuple[int, int, int, int]:
    brick_h = 28
    brick_w = 58
    row = y // brick_h
    offset = brick_w // 2 if row % 2 else 0
    lx = (x + offset) % brick_w
    ly = y % brick_h
    mortar = lx < 3 or ly < 4
    if mortar:
        n = fractal_noise(x, y, 203)
        return clamp(91 + n * 12), clamp(86 + n * 10), clamp(78 + n * 9), 255
    variation = hash_noise((x + offset) // brick_w, row, 204) * 18 + fractal_noise(x, y, 205) * 9
    soot = max(0.0, smooth_noise(x, y, 209, 44.0)) * 18
    return clamp(112 + variation - soot), clamp(62 + variation * 0.45 - soot), clamp(48 + variation * 0.3 - soot), 255


def concrete(x: int, y: int) -> tuple[int, int, int, int]:
    n = fractal_noise(x, y, 301)
    stain = max(0.0, smooth_noise(x, y, 302, 52.0)) * 25
    pore = 13 if abs(hash_noise(x, y, 303)) > 0.985 else 0
    base = 112 + n * 23 - stain - pore
    return clamp(base - 5), clamp(base - 2), clamp(base), 255


def brushed_metal(x: int, y: int) -> tuple[int, int, int, int]:
    horizontal = hash_noise(x, y // 3, 401) * 10 + math.sin(y * 0.39) * 4
    broad = smooth_noise(x, y, 402, 58.0) * 16
    scratch = 22 if hash_noise(x // 2, y, 403) > 0.992 else 0
    base = 116 + horizontal + broad + scratch
    return clamp(base - 14), clamp(base - 5), clamp(base), 255


def rust(x: int, y: int) -> tuple[int, int, int, int]:
    patch = smooth_noise(x, y, 501, 34.0)
    fine = fractal_noise(x, y, 502)
    exposed = patch < -0.22
    if exposed:
        base = 91 + fine * 15
        return clamp(base - 12), clamp(base - 3), clamp(base + 2), 255
    oxide = 0.55 + patch * 0.35 + fine * 0.22
    return clamp(130 + oxide * 62), clamp(64 + oxide * 30), clamp(30 + oxide * 18), 255


def grime(x: int, y: int) -> tuple[int, int, int, int]:
    n = fractal_noise(x, y, 601)
    drip = max(0.0, math.sin(x * 0.09 + smooth_noise(x, y, 602, 26.0) * 5.0)) * max(0.0, (y - 32) / 224.0)
    edge = abs(math.sin((x + y * 0.17) * 0.053)) < 0.06
    base = 53 + n * 24 - drip * 28
    if edge:
        base -= 15
    return clamp(base + 8), clamp(base + 5), clamp(base), 255


def moss(x: int, y: int) -> tuple[int, int, int, int]:
    colony = smooth_noise(x, y, 701, 27.0)
    detail = fractal_noise(x, y, 702)
    tendril = abs(math.sin(x * 0.071 + y * 0.027 + detail * 2.4)) < 0.12
    green = 82 + colony * 52 + detail * 25 + (25 if tendril else 0)
    return clamp(green * 0.47), clamp(green), clamp(green * 0.51), 255


def chitin(x: int, y: int) -> tuple[int, int, int, int]:
    cx = (x % 64) - 32
    cy = (y % 48) - 24
    radius = math.sqrt((cx / 1.2) ** 2 + cy**2)
    ridge = math.cos(radius * 0.42 + smooth_noise(x, y, 801, 18.0) * 1.4)
    seam = abs(cx) > 29 or abs(cy) > 21
    n = fractal_noise(x, y, 802)
    return clamp(54 + ridge * 17 + n * 12 - (15 if seam else 0)), clamp(35 + ridge * 9 + n * 8), clamp(47 + ridge * 13 + n * 11), 255


def membrane(x: int, y: int) -> tuple[int, int, int, int]:
    n = fractal_noise(x, y, 901)
    vein_a = abs(math.sin(x * 0.055 + smooth_noise(x, y, 902, 42.0) * 3.6))
    vein_b = abs(math.sin(y * 0.061 - smooth_noise(x, y, 903, 38.0) * 3.2))
    vein = min(vein_a, vein_b) < 0.075
    pulse = 0.5 + 0.5 * math.sin((x + y) * TAU / 180.0)
    return clamp(91 + n * 28 + pulse * 14), clamp(24 + n * 10 + (19 if vein else 0)), clamp(57 + n * 22 + (34 if vein else 0)), 255


TEXTURES: dict[str, Callable[[int, int], tuple[int, int, int, int]]] = {
    "asphalt_wet.png": asphalt,
    "brick_ruin.png": brick,
    "concrete_wet.png": concrete,
    "metal_brushed.png": brushed_metal,
    "rust_panel.png": rust,
    "grime_decal.png": grime,
    "moss_growth.png": moss,
    "chitin.png": chitin,
    "membrane.png": membrane,
}


NORMAL_TEXTURES: dict[str, tuple[str, float]] = {
    "asphalt_wet_normal.png": ("asphalt_wet.png", 3.4),
    "brick_ruin_normal.png": ("brick_ruin.png", 4.2),
    "chitin_normal.png": ("chitin.png", 5.2),
    "concrete_wet_normal.png": ("concrete_wet.png", 3.0),
    "grime_decal_normal.png": ("grime_decal.png", 2.4),
    "membrane_normal.png": ("membrane.png", 4.8),
    "metal_brushed_normal.png": ("metal_brushed.png", 3.2),
    "moss_growth_normal.png": ("moss_growth.png", 3.8),
    "rust_panel_normal.png": ("rust_panel.png", 4.0),
}


def normal_pixel(source: Callable[[int, int], tuple[int, int, int, int]], strength: float) -> Callable[[int, int], tuple[int, int, int, int]]:
    def sample(x: int, y: int) -> tuple[int, int, int, int]:
        def height(px: int, py: int) -> float:
            red, green, blue, _ = source(px % 256, py % 256)
            return (red * 0.2126 + green * 0.7152 + blue * 0.0722) / 255.0

        dx = height(x + 1, y) - height(x - 1, y)
        dy = height(x, y + 1) - height(x, y - 1)
        nx = -dx * strength
        ny = -dy * strength
        nz = 1.0
        length = math.sqrt(nx * nx + ny * ny + nz * nz)
        nx /= length
        ny /= length
        nz /= length
        return clamp((nx * 0.5 + 0.5) * 255.0), clamp((ny * 0.5 + 0.5) * 255.0), clamp((nz * 0.5 + 0.5) * 255.0), 255

    return sample


def quantized_frequency(frequency: float, duration: float) -> float:
    return round(frequency * duration) / duration


def periodic_noise(t: float, duration: float, seed: int, harmonics: int = 18) -> float:
    rng = random.Random(seed)
    value = 0.0
    weight_sum = 0.0
    for index in range(1, harmonics + 1):
        harmonic = rng.randint(1, 220)
        phase = rng.random() * TAU
        weight = 1.0 / math.sqrt(float(index))
        value += math.sin(TAU * harmonic * t / duration + phase) * weight
        weight_sum += weight
    return value / max(0.001, weight_sum)


def soft_clip(value: float) -> float:
    return math.tanh(value * 1.25) * 0.82


def write_wav(path: Path, duration: float, sample: Callable[[float, float], float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    total = int(round(duration * SAMPLE_RATE))
    frames = bytearray()
    for index in range(total):
        t = index / SAMPLE_RATE
        value = soft_clip(sample(t, duration))
        frames.extend(struct.pack("<h", int(max(-1.0, min(1.0, value)) * 32767)))
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(bytes(frames))


def tone(t: float, duration: float, frequency: float, phase: float = 0.0) -> float:
    return math.sin(TAU * quantized_frequency(frequency, duration) * t + phase)


def ambience_city(t: float, duration: float) -> float:
    wind = periodic_noise(t, duration, 1001, 42) * 0.27
    distant_hum = tone(t, duration, 43.0) * 0.13 + tone(t, duration, 67.0, 0.8) * 0.06
    metal = max(0.0, tone(t, duration, 0.25, 1.3)) ** 18 * tone(t, duration, 349.0) * 0.055
    organic = max(0.0, tone(t, duration, 0.166, 2.1)) ** 28 * tone(t, duration, 121.0) * 0.045
    return wind + distant_hum + metal + organic


def ambience_sanctuary(t: float, duration: float) -> float:
    hum = tone(t, duration, 55.0) * 0.19 + tone(t, duration, 110.0, 0.4) * 0.07
    machinery = tone(t, duration, 6.0) * tone(t, duration, 178.0) * 0.025
    crackle_gate = max(0.0, periodic_noise(t, duration, 1102, 28) - 0.18)
    crackle = crackle_gate * periodic_noise(t, duration, 1103, 60) * 0.12
    chime = max(0.0, tone(t, duration, 0.125, 1.8)) ** 35 * (tone(t, duration, 440.0) + tone(t, duration, 660.0)) * 0.025
    return hum + machinery + crackle + chime


def music_embers(t: float, duration: float) -> float:
    notes = [55.0, 65.406, 73.416, 82.407, 98.0]
    pad = sum(tone(t, duration, note, index * 0.7) for index, note in enumerate(notes[:3])) * 0.075
    melody_index = int((t / duration) * 16) % len(notes)
    local = (t % (duration / 16)) / (duration / 16)
    envelope = math.sin(math.pi * min(1.0, local)) ** 2
    melody = tone(t, duration, notes[melody_index] * 2.0, 0.3) * envelope * 0.09
    pulse = (0.55 + 0.45 * tone(t, duration, 0.5)) * tone(t, duration, 41.2) * 0.08
    return pad + melody + pulse


def music_pressure(t: float, duration: float) -> float:
    beat = (t * 2.0) % 1.0
    kick = math.exp(-beat * 14.0) * tone(t, duration, 48.0) * 0.28
    second = ((t * 4.0 + 0.5) % 1.0)
    hit = math.exp(-second * 20.0) * periodic_noise(t, duration, 1202, 20) * 0.12
    drone = tone(t, duration, 46.25) * 0.11 + tone(t, duration, 69.3, 1.1) * 0.065
    tension = tone(t, duration, 92.5, tone(t, duration, 0.125) * 0.8) * 0.04
    return kick + hit + drone + tension


def music_sovereignty(t: float, duration: float) -> float:
    chord = [55.0, 82.407, 110.0, 146.832]
    pad = sum(tone(t, duration, note, index * 0.45) for index, note in enumerate(chord)) * 0.065
    movement = tone(t, duration, 0.25) * tone(t, duration, 220.0) * 0.035
    bell_gate = max(0.0, tone(t, duration, 0.125, -1.2)) ** 24
    bell = bell_gate * (tone(t, duration, 440.0) + tone(t, duration, 660.0) * 0.5) * 0.075
    return pad + movement + bell


def fade_envelope(t: float, duration: float, attack: float = 0.01, release: float = 0.08) -> float:
    return min(1.0, t / max(0.001, attack), (duration - t) / max(0.001, release))


def sfx_pistol(t: float, duration: float) -> float:
    return fade_envelope(t, duration, 0.001, 0.09) * (periodic_noise(t, duration, 2001, 40) * math.exp(-t * 28.0) * 0.65 + tone(t, duration, 120.0) * math.exp(-t * 18.0) * 0.28)


def sfx_salvage(t: float, duration: float) -> float:
    spin = tone(t, duration, 420.0 + 35.0 * tone(t, duration, 3.0)) * 0.25
    grind = periodic_noise(t, duration, 2002, 50) * (0.25 + 0.2 * abs(tone(t, duration, 6.0)))
    sparks = max(0.0, periodic_noise(t, duration, 2003, 40) - 0.28) * 0.2
    return fade_envelope(t, duration, 0.03, 0.12) * (spin + grind + sparks)


def sfx_forge(t: float, duration: float) -> float:
    beat = (t * 3.0) % 1.0
    hammer = math.exp(-beat * 32.0) * (tone(t, duration, 74.0) * 0.55 + periodic_noise(t, duration, 2004, 18) * 0.28)
    furnace = tone(t, duration, 53.0) * 0.12 + periodic_noise(t, duration, 2005, 32) * 0.09
    return fade_envelope(t, duration, 0.015, 0.1) * (hammer + furnace)


def sfx_organic_hit(t: float, duration: float) -> float:
    return fade_envelope(t, duration, 0.001, 0.16) * (tone(t, duration, 86.0) * math.exp(-t * 12.0) * 0.35 + periodic_noise(t, duration, 2006, 35) * math.exp(-t * 9.0) * 0.45)


def sfx_report(t: float, duration: float) -> float:
    notes = [523.25, 659.25, 783.99]
    segment = int(t / (duration / 3.0))
    local = t % (duration / 3.0)
    return tone(t, duration, notes[min(2, segment)]) * math.exp(-local * 7.0) * 0.24


def sfx_danger(t: float, duration: float) -> float:
    swell = math.sin(math.pi * t / duration) ** 1.4
    return swell * (tone(t, duration, 55.0) * 0.26 + tone(t, duration, 82.5, 0.7) * 0.14 + periodic_noise(t, duration, 2007, 26) * 0.08)


def sfx_ui(t: float, duration: float) -> float:
    return fade_envelope(t, duration, 0.002, 0.08) * (tone(t, duration, 659.25) * 0.18 + tone(t, duration, 987.77, 0.3) * 0.09)


def sfx_victory(t: float, duration: float) -> float:
    chord = [220.0, 277.18, 329.63, 440.0]
    swell = math.sin(math.pi * min(1.0, t / duration)) ** 0.8
    return fade_envelope(t, duration, 0.04, 0.2) * swell * sum(tone(t, duration, note, index * 0.32) for index, note in enumerate(chord)) * 0.09


AUDIO: dict[str, tuple[float, Callable[[float, float], float]]] = {
    "ambience_city.wav": (18.0, ambience_city),
    "ambience_sanctuary.wav": (18.0, ambience_sanctuary),
    "music_embers.wav": (24.0, music_embers),
    "music_pressure.wav": (24.0, music_pressure),
    "music_sovereignty.wav": (24.0, music_sovereignty),
    "sfx_pistol.wav": (0.42, sfx_pistol),
    "sfx_salvage.wav": (2.1, sfx_salvage),
    "sfx_forge.wav": (2.4, sfx_forge),
    "sfx_organic_hit.wav": (0.65, sfx_organic_hit),
    "sfx_machine_report.wav": (0.8, sfx_report),
    "sfx_danger.wav": (2.4, sfx_danger),
    "sfx_ui_confirm.wav": (0.24, sfx_ui),
    "sfx_victory.wav": (4.0, sfx_victory),
}


def generate_textures() -> None:
    for name, function in TEXTURES.items():
        write_png(TEXTURE_ROOT / name, function)
    for name, (source_name, strength) in NORMAL_TEXTURES.items():
        write_png(TEXTURE_ROOT / name, normal_pixel(TEXTURES[source_name], strength))


def generate_audio() -> None:
    for name, (duration, function) in AUDIO.items():
        write_wav(AUDIO_ROOT / name, duration, function)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--textures-only", action="store_true")
    parser.add_argument("--audio-only", action="store_true")
    args = parser.parse_args()
    if not args.audio_only:
        generate_textures()
    if not args.textures_only:
        generate_audio()
    print(f"Generated {len(TEXTURES) + len(NORMAL_TEXTURES)} textures and {len(AUDIO)} audio assets under {ASSET_ROOT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
