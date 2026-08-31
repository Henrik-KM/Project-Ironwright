"""Build the original high-definition opening salvage wreck glTF."""

from __future__ import annotations

import base64
import json
import math
import sys
from pathlib import Path

SOURCE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "bulwark" / "source"))
from build_bulwark_asset import (  # noqa: E402
    BufferBuilder,
    add_beveled_box,
    add_cylinder,
    add_ellipsoid,
    add_torus,
    add_uv_sphere,
    quat,
)

OUTPUT_PATH = SOURCE_DIR / "salvage.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Wreck weathered steel", "pbrMetallicRoughness": {"baseColorFactor": [0.20, 0.24, 0.23, 1.0], "metallicFactor": 0.82, "roughnessFactor": 0.46}},
        {"name": "Wreck oxide red", "pbrMetallicRoughness": {"baseColorFactor": [0.34, 0.12, 0.055, 1.0], "metallicFactor": 0.62, "roughnessFactor": 0.58}},
        {"name": "Wreck carbon rubber", "pbrMetallicRoughness": {"baseColorFactor": [0.018, 0.022, 0.023, 1.0], "metallicFactor": 0.05, "roughnessFactor": 0.92}},
        {"name": "Wreck cyan status", "pbrMetallicRoughness": {"baseColorFactor": [0.025, 0.20, 0.22, 1.0], "metallicFactor": 0.28, "roughnessFactor": 0.24}, "emissiveFactor": [0.10, 0.85, 0.90]},
        {"name": "Wreck warm hazard", "pbrMetallicRoughness": {"baseColorFactor": [0.44, 0.18, 0.035, 1.0], "metallicFactor": 0.30, "roughnessFactor": 0.38}, "emissiveFactor": [0.82, 0.20, 0.025]},
        {"name": "Wreck glass", "pbrMetallicRoughness": {"baseColorFactor": [0.20, 0.34, 0.35, 0.42], "metallicFactor": 0.12, "roughnessFactor": 0.18}, "alphaMode": "BLEND", "emissiveFactor": [0.04, 0.16, 0.15]},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int, int, int]) -> int:
        position, normal, uv, tangent, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal, "TEXCOORD_0": uv, "TANGENT": tangent}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    steel, oxide, rubber, cyan, warm, glass = range(6)
    mesh_ids = {
        "Chassis": mesh("Chassis", add_ellipsoid(builder, (1.20, 0.42, 0.78), steel, 24, 40)),
        "Core": mesh("Core", add_ellipsoid(builder, (0.97, 0.22, 0.62), oxide, 20, 32)),
        "Cabin": mesh("Cabin", add_beveled_box(builder, (1.28, 0.42, 0.88), steel, 0.10)),
        "CabinPanel": mesh("CabinPanel", add_beveled_box(builder, (0.82, 0.075, 0.52), oxide, 0.035)),
        "CabinHandle": mesh("CabinHandle", add_beveled_box(builder, (0.42, 0.055, 0.08), warm, 0.018)),
        "Wheel": mesh("Wheel", add_cylinder(builder, 0.43, 0.28, rubber, 28)),
        "Hub": mesh("Hub", add_cylinder(builder, 0.18, 0.31, steel, 28)),
        "Rim": mesh("Rim", add_torus(builder, 0.31, 0.035, oxide, 40, 12)),
        "Rail": mesh("Rail", add_beveled_box(builder, (2.22, 0.10, 0.12), steel, 0.025)),
        "ServicePanel": mesh("ServicePanel", add_beveled_box(builder, (0.88, 0.055, 0.40), oxide, 0.025)),
        "ServiceWindow": mesh("ServiceWindow", add_beveled_box(builder, (0.58, 0.026, 0.13), cyan, 0.012)),
        "Pipe": mesh("Pipe", add_cylinder(builder, 0.055, 1.15, oxide, 24)),
        "PipeJoint": mesh("PipeJoint", add_uv_sphere(builder, 0.09, steel, 18, 28)),
        "Lens": mesh("Lens", add_uv_sphere(builder, 0.12, cyan, 18, 32)),
        "Hazard": mesh("Hazard", add_beveled_box(builder, (0.13, 0.06, 0.36), warm, 0.018)),
        "Glass": mesh("Glass", add_beveled_box(builder, (0.34, 0.035, 0.16), glass, 0.018)),
        "Fastener": mesh("Fastener", add_cylinder(builder, 0.035, 0.04, warm, 20)),
        "Latch": mesh("Latch", add_cylinder(builder, 0.055, 0.045, steel, 20)),
    }

    nodes: list[dict] = [{"name": "SalvageModel", "children": [], "extras": {"ironwright_asset_id": "salvage.opening_wreck.v1", "asset_quality": "authored_high_definition", "socket_contract": "salvage_target, status_lens, service_panel"}}]

    def add_node(name: str, mesh_id: int | None = None, translation: tuple[float, float, float] = (0.0, 0.0, 0.0), rotation: tuple[float, float, float] = (0.0, 0.0, 0.0), extras: dict | None = None) -> None:
        entry: dict = {"name": name, "translation": list(translation)}
        if mesh_id is not None:
            entry["mesh"] = mesh_id
        if rotation != (0.0, 0.0, 0.0):
            entry["rotation"] = quat(rotation)
        if extras:
            entry["extras"] = extras
        nodes.append(entry)
        nodes[0]["children"].append(len(nodes) - 1)

    add_node("WreckChassis", mesh_ids["Chassis"], (0.0, 0.57, 0.0), extras={"surface": "rounded_load_bearing_shell"})
    add_node("WreckCore", mesh_ids["Core"], (0.0, 0.66, -0.03))
    add_node("WreckCabin", mesh_ids["Cabin"], (-0.18, 0.98, 0.12), rotation=(0.0, 0.0, -0.08))
    add_node("WreckCabinPanel", mesh_ids["CabinPanel"], (0.20, 1.05, -0.34), rotation=(0.10, 0.0, 0.04))
    add_node("WreckCabinHandle", mesh_ids["CabinHandle"], (0.20, 1.10, -0.405), rotation=(0.10, 0.0, 0.04), extras={"surface": "cabin_service_grip"})
    for side in (-1.0, 1.0):
        for front in (-1.0, 1.0):
            suffix = ("L" if side < 0 else "R") + ("F" if front < 0 else "B")
            position = (side * 0.90, 0.39, front * 0.55)
            add_node("Wheel%s" % suffix, mesh_ids["Wheel"], position, rotation=(math.pi * 0.5, 0.0, 0.0))
            add_node("WheelHub%s" % suffix, mesh_ids["Hub"], position, rotation=(math.pi * 0.5, 0.0, 0.0))
            add_node("WheelRim%s" % suffix, mesh_ids["Rim"], position, rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("WreckChassisRailFront", mesh_ids["Rail"], (0.0, 0.80, -0.63))
    add_node("WreckChassisRailRear", mesh_ids["Rail"], (0.0, 0.79, 0.63))
    add_node("WreckServicePanel", mesh_ids["ServicePanel"], (-0.64, 0.72, -0.45), rotation=(0.0, math.pi * 0.5, 0.0), extras={"surface": "manual_salvage_access"})
    add_node("WreckServiceWindow", mesh_ids["ServiceWindow"], (-0.70, 0.72, -0.45), rotation=(0.0, math.pi * 0.5, 0.0))
    for index, x in enumerate((-0.44, 0.0, 0.44)):
        add_node("WreckServiceFastener%02d" % index, mesh_ids["Fastener"], (-0.71, 0.82, x), rotation=(0.0, math.pi * 0.5, 0.0))
    for index, x in enumerate((-0.24, 0.24)):
        add_node("WreckServiceLatch%02d" % index, mesh_ids["Latch"], (-0.715, 0.72, -0.45 + x), rotation=(0.0, math.pi * 0.5, 0.0), extras={"surface": "manual_salvage_latch"})
    add_node("WreckPipeLeft", mesh_ids["Pipe"], (-0.82, 0.94, 0.03), rotation=(0.0, 0.0, math.pi * 0.5))
    add_node("WreckPipeRight", mesh_ids["Pipe"], (0.82, 0.94, 0.12), rotation=(0.0, 0.0, math.pi * 0.5))
    add_node("WreckPipeJointLeft", mesh_ids["PipeJoint"], (-0.82, 0.94, -0.56))
    add_node("WreckPipeJointRight", mesh_ids["PipeJoint"], (0.82, 0.94, -0.47))
    add_node("WreckStatusLens", mesh_ids["Lens"], (-0.74, 1.05, -0.64), extras={"socket_type": "status_lens"})
    for index, x in enumerate((-0.42, -0.14, 0.14, 0.42)):
        add_node("WreckHazardStripe%02d" % index, mesh_ids["Hazard"], (x, 1.21, -0.36), rotation=(0.0, 0.0, 0.12))
    for index, position in enumerate(((-0.35, 1.22, -0.10), (0.0, 1.28, 0.08), (0.32, 1.18, 0.18))):
        add_node("BrokenGlassShard%02d" % index, mesh_ids["Glass"], position, rotation=(-0.18, 0.12 * index, 0.28 - 0.18 * index))
    add_node("ProductionAssetMarker", extras={"asset_contract": "salvage.opening_wreck.v1", "source": "original_shared_mesh_builder"})

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original salvage asset builder"},
        "scene": 0,
        "scenes": [{"name": "Salvage", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {"ironwright_asset_id": "salvage.opening_wreck.v1", "required_nodes": ["SalvageModel", "WreckChassis", "WreckCore", "WreckCabin", "WreckCabinHandle", "WreckServicePanel", "WreckStatusLens", "WreckPipeLeft", "WreckServiceLatch00", "BrokenGlassShard00", "ProductionAssetMarker"]},
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
