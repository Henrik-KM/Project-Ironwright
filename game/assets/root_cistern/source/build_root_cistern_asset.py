"""Build the original high-definition Root Cistern landmark glTF."""

from __future__ import annotations

import base64
import json
import math
import sys
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, _geometry, add_beveled_box, add_box, add_cylinder, add_ellipsoid, add_uv_sphere, quat  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "root_cistern.gltf"


def add_torus(
    builder: BufferBuilder,
    major_radius: float,
    minor_radius: float,
    material: int,
    major_segments: int = 48,
    minor_segments: int = 8,
) -> tuple[int, int, int, int, int, int]:
    """Build a rounded relay ring for the capstone's signal hardware."""
    positions: list[float] = []
    normals: list[float] = []
    indices: list[int] = []
    for major in range(major_segments):
        major_angle = math.tau * major / major_segments
        major_cos = math.cos(major_angle)
        major_sin = math.sin(major_angle)
        for minor in range(minor_segments):
            minor_angle = math.tau * minor / minor_segments
            minor_cos = math.cos(minor_angle)
            minor_sin = math.sin(minor_angle)
            ring_radius = major_radius + minor_radius * minor_cos
            positions.extend([ring_radius * major_cos, minor_radius * minor_sin, ring_radius * major_sin])
            normals.extend([minor_cos * major_cos, minor_sin, minor_cos * major_sin])
    for major in range(major_segments):
        next_major = (major + 1) % major_segments
        for minor in range(minor_segments):
            next_minor = (minor + 1) % minor_segments
            a = major * minor_segments + minor
            b = next_major * minor_segments + minor
            c = next_major * minor_segments + next_minor
            d = major * minor_segments + next_minor
            indices.extend([a, b, c, a, c, d])
    return _geometry(builder, positions, normals, indices, material)


def main() -> None:
    builder = BufferBuilder()
    materials = [
        # Keep the focal organism in a wet mineral-biological lane. The
        # previous red-violet values bloomed pink under the blue-hour review
        # key and made the endgame landmark read like a plastic toy.
        {"name": "Cistern wet root", "pbrMetallicRoughness": {"baseColorFactor": [0.035, 0.009, 0.02, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.58}, "emissiveFactor": [0.015, 0.0, 0.004]},
        {"name": "Cistern layered bark", "pbrMetallicRoughness": {"baseColorFactor": [0.075, 0.025, 0.032, 1.0], "metallicFactor": 0.02, "roughnessFactor": 0.72}, "emissiveFactor": [0.018, 0.002, 0.004]},
        {"name": "Cistern bone", "pbrMetallicRoughness": {"baseColorFactor": [0.12, 0.075, 0.05, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.78}},
        {"name": "Cistern buried alloy", "pbrMetallicRoughness": {"baseColorFactor": [0.055, 0.14, 0.16, 1.0], "metallicFactor": 0.38, "roughnessFactor": 0.56}},
        {"name": "Cistern cold signal", "pbrMetallicRoughness": {"baseColorFactor": [0.01, 0.10, 0.14, 1.0], "metallicFactor": 0.10, "roughnessFactor": 0.38}, "emissiveFactor": [0.01, 0.22, 0.30]},
        {"name": "Cistern root pulse", "pbrMetallicRoughness": {"baseColorFactor": [0.16, 0.035, 0.018, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.60}, "emissiveFactor": [0.12, 0.012, 0.003]},
        {"name": "Cistern deep root", "pbrMetallicRoughness": {"baseColorFactor": [0.028, 0.004, 0.014, 1.0], "metallicFactor": 0.0, "roughnessFactor": 0.60}, "emissiveFactor": [0.012, 0.0, 0.004]},
        {"name": "Cistern capstone plate", "pbrMetallicRoughness": {"baseColorFactor": [0.035, 0.075, 0.085, 1.0], "metallicFactor": 0.34, "roughnessFactor": 0.43}, "emissiveFactor": [0.0, 0.018, 0.022]},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int, int, int]) -> int:
        position, normal, uv, tangent, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal, "TEXCOORD_0": uv, "TANGENT": tangent}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    root, bark, bone, alloy, signal, pulse, deep_root, capstone = range(8)
    mesh_ids = {
        # The core is the late-game focal organism. Use smooth organic
        # envelopes for its mass, layered mantle and radial ribs so the
        # approach silhouette reads as a living relay rather than a stack of
        # boxes and stakes at compact review distance.
        "Core": mesh("Core", add_ellipsoid(builder, (0.80, 1.05, 0.80), deep_root, rings=20, sides=40)),
        "Layer": mesh("Layer", add_ellipsoid(builder, (0.55, 0.28, 0.55), bark, rings=18, sides=36)),
        "Rib": mesh("Rib", add_ellipsoid(builder, (0.20, 0.13, 0.92), bone, rings=18, sides=36)),
        "Pylon": mesh("Pylon", add_ellipsoid(builder, (0.34, 2.05, 0.34), alloy, rings=20, sides=40)),
        "PylonFoot": mesh("PylonFoot", add_ellipsoid(builder, (0.58, 0.25, 0.58), alloy, rings=18, sides=36)),
        "PylonShoulder": mesh("PylonShoulder", add_ellipsoid(builder, (0.43, 0.28, 0.43), alloy, rings=18, sides=36)),
        "PylonCrown": mesh("PylonCrown", add_ellipsoid(builder, (0.38, 0.22, 0.38), alloy, rings=18, sides=36)),
        "PylonRing": mesh("PylonRing", add_torus(builder, 0.43, 0.07, signal)),
        "PylonCollar": mesh("PylonCollar", add_cylinder(builder, 0.38, 0.18, alloy, 20)),
        # Keep the support as a short organic-root brace so it frames the
        # relay rather than reading as a second ring of dark vertical stakes.
        "PylonBrace": mesh("PylonBrace", add_beveled_box(builder, (0.10, 1.15, 0.10), bone, 0.025)),
        "Signal": mesh("Signal", add_ellipsoid(builder, (0.11, 1.35, 0.11), signal, rings=18, sides=36)),
        "Pulse": mesh("Pulse", add_uv_sphere(builder, 0.18, pulse, 18, 28)),
        "PulseCap": mesh("PulseCap", add_cylinder(builder, 0.18, 0.16, pulse, 18)),
        "Cable": mesh("Cable", add_cylinder(builder, 0.055, 5.2, pulse, 14)),
        "CableClamp": mesh("CableClamp", add_cylinder(builder, 0.10, 0.14, alloy, 16)),
        "Basin": mesh("Basin", add_cylinder(builder, 5.8, 0.22, alloy, 40)),
        # A shallow manufactured foundation gives the late basin a visible
        # architectural footprint at the approach distance. It is part of
        # the authored presentation asset only; the runtime landmark keeps
        # ownership of collision and navigation separately.
        "BasinFoundation": mesh("BasinFoundation", add_cylinder(builder, 6.35, 0.18, capstone, 48)),
        "BasinFoundationRim": mesh("BasinFoundationRim", add_torus(builder, 6.08, 0.16, alloy, 64, 10)),
        "BasinWater": mesh("BasinWater", add_cylinder(builder, 4.9, 0.06, root, 40)),
        "BasinRim": mesh("BasinRim", add_beveled_box(builder, (2.45, 0.18, 0.24), bone, 0.06)),
        # These are radial root braces, not vertical stakes. Keeping them
        # close to the basin surface preserves the ring's silhouette and
        # leaves the apex readable from the authored approach camera.
        "BasinSpine": mesh("BasinSpine", add_ellipsoid(builder, (0.28, 0.20, 0.65), bone, rings=18, sides=36)),
        "BasinRootTendril": mesh("BasinRootTendril", add_cylinder(builder, 0.055, 0.90, root, 14)),
        "CorePlate": mesh("CorePlate", add_ellipsoid(builder, (0.78, 0.12, 0.16), bark, rings=18, sides=36)),
        # Overlapping mantle lobes break the smooth focal mass into a living
        # segmented shell without turning the capstone into another crown of
        # rigid stakes.
        "CoreMantle": mesh("CoreMantle", add_ellipsoid(builder, (0.52, 0.34, 0.24), bark, rings=18, sides=36)),
        "CoreClaw": mesh("CoreClaw", add_ellipsoid(builder, (0.12, 0.75, 0.12), bone, rings=18, sides=36)),
        "CoreVein": mesh("CoreVein", add_cylinder(builder, 0.06, 1.8, pulse, 14)),
        "CoreHalo": mesh("CoreHalo", add_uv_sphere(builder, 0.34, pulse, 18, 28)),
        "CoreCollar": mesh("CoreCollar", add_cylinder(builder, 2.82, 0.20, bark, 36)),
        "CoreRoot": mesh("CoreRoot", add_ellipsoid(builder, (0.16, 0.90, 0.16), root, rings=18, sides=32)),
        "CoreSpine": mesh("CoreSpine", add_cylinder(builder, 0.14, 4.2, signal, 20)),
        "BasinInlay": mesh("BasinInlay", add_beveled_box(builder, (0.10, 0.08, 3.4), signal, 0.025)),
        "BasinSocket": mesh("BasinSocket", add_uv_sphere(builder, 0.12, pulse, 14, 20)),
        "CoreCrownPlate": mesh("CoreCrownPlate", add_ellipsoid(builder, (0.16, 0.18, 0.36), bone, rings=18, sides=36)),
        "CoreCrownSocket": mesh("CoreCrownSocket", add_uv_sphere(builder, 0.105, signal, 14, 20)),
        "CoreCrownRing": mesh("CoreCrownRing", add_torus(builder, 1.96, 0.08, pulse)),
        # A buried alloy interface breaks the organic mass at the focal point.
        # Its low profile and radial ribs read as maintained relay hardware,
        # while the surrounding deep-root body keeps the landmark organic.
        "CoreCapPlate": mesh("CoreCapPlate", add_ellipsoid(builder, (1.22, 0.16, 1.22), capstone, rings=20, sides=40)),
        "CoreCapCollar": mesh("CoreCapCollar", add_torus(builder, 1.28, 0.09, capstone)),
        "CoreCapRib": mesh("CoreCapRib", add_ellipsoid(builder, (0.10, 0.10, 0.68), capstone, rings=18, sides=32)),
        "CoreCapSocket": mesh("CoreCapSocket", add_uv_sphere(builder, 0.14, signal, 18, 28)),
    }
    nodes: list[dict] = [{
        "name": "RootCisternModel",
        "children": [],
        "extras": {"ironwright_asset_id": "root_cistern.landmark.v1", "asset_quality": "authored_high_definition", "socket_contract": "root_core, crown_ribs, signal_pylons, root_cables"},
    }]

    def add_node(name: str, mesh_id: int | None = None, translation: Sequence[float] = (0.0, 0.0, 0.0), rotation: Sequence[float] = (0.0, 0.0, 0.0), scale: Sequence[float] | None = None, extras: dict | None = None, parent: int = 0) -> int:
        entry: dict = {"name": name, "translation": list(translation)}
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

    add_node("RootCisternBasinFoundation", mesh_ids["BasinFoundation"], (0.0, 0.05, 0.0), extras={"surface": "basin_foundation"})
    add_node("RootCisternBasinFoundationRim", mesh_ids["BasinFoundationRim"], (0.0, 0.18, 0.0), extras={"surface": "basin_foundation_rim"})
    add_node("RootCisternBasin", mesh_ids["Basin"], (0.0, 0.11, 0.0), extras={"socket_type": "basin_floor"})
    add_node("RootCisternBasinWater", mesh_ids["BasinWater"], (0.0, 0.27, 0.0), extras={"socket_type": "basin_water"})
    for index in range(8):
        angle = 6.283185307179586 * index / 8.0
        rim = add_node("RootCisternBasinRim%d" % index, mesh_ids["BasinRim"], (math.cos(angle) * 5.2, 0.38, math.sin(angle) * 5.2), rotation=(0.0, angle, 0.0), extras={"socket_type": "basin_rim"})
        add_node("RootCisternBasinSpine%d" % index, mesh_ids["BasinSpine"], (0.0, 0.10, 1.25), rotation=(0.0, math.pi * 0.5, 0.10), parent=rim)
        add_node("RootCisternBasinRootTendril%d" % index, mesh_ids["BasinRootTendril"], (0.72, 0.16, -0.22), rotation=(0.0, 0.0, -0.28), parent=rim)
    for index in range(12):
        angle = 6.283185307179586 * index / 12.0 + 0.13
        x, z = math.cos(angle) * 3.82, math.sin(angle) * 3.82
        add_node("RootCisternBasinInlay%02d" % index, mesh_ids["BasinInlay"], (x, 0.38, z), rotation=(0.0, -angle, 0.0), scale=(1.0, 1.0, 0.92), extras={"socket_type": "basin_signal_inlay"})
        add_node("RootCisternBasinSocket%02d" % index, mesh_ids["BasinSocket"], (x * 1.02, 0.50, z * 1.02), extras={"socket_type": "basin_signal_socket"})
    core = add_node("RootCisternCore", extras={"surface": "layered_root_organ"})
    add_node("RootCisternCoreCollar", mesh_ids["CoreCollar"], (0.0, 0.66, 0.0), parent=core, extras={"socket_type": "core_base_collar"})
    # Raise and lengthen the focal organism so the capstone reads as a
    # living root altar rather than a flat pink saucer at the approach angle.
    add_node("RootCisternCoreMass", mesh_ids["Core"], (0.0, 1.58, 0.0), scale=(3.0, 2.25, 3.0), parent=core, extras={"release_material_family": "organic"})
    add_node("RootCisternCoreHalo", mesh_ids["CoreHalo"], (0.0, 3.48, 0.0), scale=(2.50, 1.42, 2.50), parent=core, extras={"socket_type": "core_halo"})
    add_node("RootCisternCoreCrownRing", mesh_ids["CoreCrownRing"], (0.0, 3.48, 0.0), parent=core, extras={"socket_type": "core_crown_ring"})
    add_node("RootCisternCoreSpine", mesh_ids["CoreSpine"], (0.0, 3.02, 0.0), parent=core, extras={"socket_type": "core_spine"})
    add_node("RootCisternCoreCapPlate", mesh_ids["CoreCapPlate"], (0.0, 3.92, 0.0), parent=core, extras={"socket_type": "core_capstone_plate"})
    add_node("RootCisternCoreCapCollar", mesh_ids["CoreCapCollar"], (0.0, 3.82, 0.0), parent=core, extras={"socket_type": "core_capstone_collar"})
    add_node("RootCisternCoreCapSocket", mesh_ids["CoreCapSocket"], (0.0, 4.12, 0.0), parent=core, extras={"socket_type": "core_capstone_socket"})
    for index in range(8):
        angle = 6.283185307179586 * index / 8.0 + 0.18
        x, z = math.cos(angle) * 0.72, math.sin(angle) * 0.72
        add_node("RootCisternCoreCapRib%02d" % index, mesh_ids["CoreCapRib"], (x, 4.04, z), rotation=(0.0, -angle, 0.0), parent=core, extras={"socket_type": "core_capstone_rib"})
        add_node("RootCisternCoreCapSocket%02d" % index, mesh_ids["CoreCapSocket"], (x * 0.92, 4.16, z * 0.92), parent=core, extras={"socket_type": "core_capstone_socket"})
    for index in range(6):
        angle = 6.283185307179586 * index / 6.0
        x, z = math.cos(angle) * 2.65, math.sin(angle) * 2.65
        add_node("RootCisternCorePlate%d" % index, mesh_ids["CorePlate"], (x, 2.02, z), rotation=(0.0, -angle, 0.0), parent=core, extras={"socket_type": "core_surface_plate"})
        add_node("RootCisternCoreClaw%d" % index, mesh_ids["CoreClaw"], (x * 0.88, 2.78, z * 0.88), rotation=(0.0, -angle, 0.38), scale=(1.0, 0.78, 1.0), parent=core, extras={"socket_type": "core_claw"})
        add_node("RootCisternCoreVein%d" % index, mesh_ids["CoreVein"], (x * 0.72, 2.42, z * 0.72), rotation=(0.0, -angle, 0.22), parent=core, extras={"socket_type": "core_vein"})
    for index in range(10):
        angle = 6.283185307179586 * index / 10.0 + 0.08
        x, z = math.cos(angle) * 2.12, math.sin(angle) * 2.12
        mantle_scale = (1.08, 1.0, 1.28) if index % 2 == 0 else (0.92, 1.16, 1.05)
        add_node("RootCisternCoreMantle%d" % index, mesh_ids["CoreMantle"], (x, 1.62 + float(index % 2) * 0.08, z), rotation=(0.0, math.pi * 0.5 - angle, 0.0), scale=mantle_scale, parent=core, extras={"socket_type": "core_mantle_lobe"})
    for index in range(6):
        angle = 6.283185307179586 * index / 6.0 + 0.22
        x, z = math.cos(angle) * 2.75, math.sin(angle) * 2.75
        add_node("RootCisternCoreRoot%d" % index, mesh_ids["CoreRoot"], (x, 1.52, z), rotation=(0.0, -angle, 0.48), scale=(1.0, 1.0, 0.82), parent=core, extras={"socket_type": "core_root_brace"})
    for index in range(6):
        angle = 6.283185307179586 * index / 6.0
        x, z = math.cos(angle) * 2.0, math.sin(angle) * 2.0
        layer_scale = (1.38, 1.08, 2.05) if index % 2 == 0 else (1.58, 0.88, 2.30)
        add_node("RootCisternLayer%d" % index, mesh_ids["Layer"], (x * 1.15, 1.62 + float(index % 2) * 0.10, z * 1.15), rotation=(0.0, -angle, 0.0), scale=layer_scale, parent=core)
        add_node("RootCisternRib%d" % index, mesh_ids["Rib"], (x * 1.5, 2.18 + float(index % 2) * 0.10, z * 1.5), rotation=(0.20, -angle, 0.0), scale=(1.0, 0.82, 1.0), parent=core)
    for index in range(8):
        angle = 6.283185307179586 * index / 8.0 + 0.18
        x, z = math.cos(angle) * 1.92, math.sin(angle) * 1.92
        add_node("RootCisternCoreCrownPlate%02d" % index, mesh_ids["CoreCrownPlate"], (x, 3.48, z), rotation=(0.18, -angle, 0.0), extras={"socket_type": "core_crown_plate"}, parent=core)
        add_node("RootCisternCoreCrownSocket%02d" % index, mesh_ids["CoreCrownSocket"], (x * 0.92, 3.66, z * 0.92), extras={"socket_type": "core_crown_socket"}, parent=core)
    for index in range(6):
        angle = 6.283185307179586 * index / 6.0 + 0.22
        x, z = math.cos(angle) * 8.2, math.sin(angle) * 8.2
        pylon = add_node("RootCisternPylon%d" % index, mesh_ids["Pylon"], (x, 2.2, z), rotation=(0.0, -angle, 0.0), parent=0, extras={"socket_type": "signal_pylon"})
        add_node("RootCisternPylonFoot%d" % index, mesh_ids["PylonFoot"], (0.0, -0.88, 0.0), parent=pylon, extras={"socket_type": "pylon_foot"})
        add_node("RootCisternPylonCollar%d" % index, mesh_ids["PylonCollar"], (0.0, 0.72, 0.0), parent=pylon, extras={"socket_type": "pylon_collar"})
        add_node("RootCisternPylonShoulder%d" % index, mesh_ids["PylonShoulder"], (0.0, 0.92, 0.0), parent=pylon, extras={"socket_type": "pylon_shoulder"})
        add_node("RootCisternPylonBrace%d" % index, mesh_ids["PylonBrace"], (0.0, 0.18, -0.14), rotation=(0.0, 0.0, math.pi * 0.5), parent=pylon, extras={"socket_type": "pylon_brace"})
        add_node("RootCisternPylonCrown%d" % index, mesh_ids["PylonCrown"], (0.0, 1.90, 0.0), parent=pylon, extras={"socket_type": "pylon_crown"})
        add_node("RootCisternPylonRing%d" % index, mesh_ids["PylonRing"], (0.0, 1.90, 0.0), parent=pylon, extras={"socket_type": "pylon_ring"})
        add_node("RootCisternSignal%d" % index, mesh_ids["Signal"], (0.0, 2.85, 0.0), rotation=(0.0, -angle, 0.0), parent=pylon)
        add_node("RootCisternPulse%d" % index, mesh_ids["Pulse"], (0.0, 4.05, 0.0), parent=pylon)
        add_node("RootCisternPulseCap%d" % index, mesh_ids["PulseCap"], (0.0, 4.28, 0.0), parent=pylon)
        add_node("RootCisternCable%d" % index, mesh_ids["Cable"], (x * 0.64, 0.72, z * 0.64), rotation=(math.pi * 0.5, -angle, 0.0), scale=(1.0, 1.0, 1.0), parent=0)
        add_node("RootCisternCableClamp%d" % index, mesh_ids["CableClamp"], (x * 0.64, 0.72, z * 0.64), rotation=(math.pi * 0.5, -angle, 0.0), parent=0, extras={"socket_type": "cable_clamp"})
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "root_cistern.landmark.v1", "source": "original_shared_mesh_builder"})
    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Root Cistern asset builder"},
        "scene": 0,
        "scenes": [{"name": "RootCistern", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {"ironwright_asset_id": "root_cistern.landmark.v1", "required_nodes": ["RootCisternModel", "RootCisternBasinFoundation", "RootCisternBasinFoundationRim", "RootCisternBasin", "RootCisternBasinWater", "RootCisternBasinSpine0", "RootCisternBasinRootTendril0", "RootCisternBasinInlay00", "RootCisternBasinSocket00", "RootCisternCore", "RootCisternCoreCollar", "RootCisternCoreMass", "RootCisternCoreMantle0", "RootCisternCoreHalo", "RootCisternCoreCrownRing", "RootCisternCoreCapPlate", "RootCisternCoreCapCollar", "RootCisternCoreCapSocket", "RootCisternCoreCapRib00", "RootCisternCoreCapSocket00", "RootCisternCorePlate0", "RootCisternCoreClaw0", "RootCisternCoreVein0", "RootCisternCoreRoot0", "RootCisternCoreCrownPlate00", "RootCisternCoreCrownSocket00", "RootCisternLayer0", "RootCisternRib0", "RootCisternPylon0", "RootCisternPylonFoot0", "RootCisternPylonCollar0", "RootCisternPylonShoulder0", "RootCisternPylonBrace0", "RootCisternPylonCrown0", "RootCisternPylonRing0", "RootCisternSignal0", "RootCisternPulseCap0", "RootCisternCable0", "RootCisternCableClamp0", "ProductionAssetMarker"]},
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
