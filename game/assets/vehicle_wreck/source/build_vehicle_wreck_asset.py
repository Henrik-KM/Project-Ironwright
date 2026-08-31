"""Build the original high-definition civic vehicle wreck glTF."""

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

OUTPUT_PATH = SOURCE_DIR / "vehicle_wreck.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Civic oxidized steel", "pbrMetallicRoughness": {"baseColorFactor": [0.18, 0.21, 0.21, 1.0], "metallicFactor": 0.82, "roughnessFactor": 0.46}},
        {"name": "Civic dark machinery", "pbrMetallicRoughness": {"baseColorFactor": [0.035, 0.045, 0.047, 1.0], "metallicFactor": 0.72, "roughnessFactor": 0.42}},
        {"name": "Civic oxide", "pbrMetallicRoughness": {"baseColorFactor": [0.34, 0.12, 0.055, 1.0], "metallicFactor": 0.58, "roughnessFactor": 0.60}},
        {"name": "Civic rubber", "pbrMetallicRoughness": {"baseColorFactor": [0.014, 0.018, 0.019, 1.0], "metallicFactor": 0.04, "roughnessFactor": 0.94}},
        {"name": "Civic glass", "pbrMetallicRoughness": {"baseColorFactor": [0.16, 0.29, 0.30, 0.48], "metallicFactor": 0.12, "roughnessFactor": 0.18}, "alphaMode": "BLEND", "emissiveFactor": [0.03, 0.13, 0.14]},
        {"name": "Civic amber status", "pbrMetallicRoughness": {"baseColorFactor": [0.52, 0.18, 0.035, 1.0], "metallicFactor": 0.22, "roughnessFactor": 0.34}, "emissiveFactor": [0.95, 0.23, 0.025]},
        {"name": "Civic cyan service", "pbrMetallicRoughness": {"baseColorFactor": [0.025, 0.18, 0.20, 1.0], "metallicFactor": 0.26, "roughnessFactor": 0.28}, "emissiveFactor": [0.08, 0.76, 0.82]},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    steel, dark, oxide, rubber, glass, amber, cyan = range(7)
    mesh_ids = {
        "Chassis": mesh("Chassis", add_ellipsoid(builder, (1.28, 0.38, 0.70), steel, 24, 40)),
        "LowerChassis": mesh("LowerChassis", add_beveled_box(builder, (2.42, 0.16, 1.16), steel, 0.08)),
        "Cab": mesh("Cab", add_beveled_box(builder, (1.56, 0.60, 1.04), dark, 0.15)),
        "Roof": mesh("Roof", add_beveled_box(builder, (1.44, 0.13, 0.98), oxide, 0.09)),
        "Glass": mesh("Glass", add_beveled_box(builder, (1.08, 0.32, 0.07), glass, 0.025)),
        "SideGlass": mesh("SideGlass", add_beveled_box(builder, (0.72, 0.28, 0.07), glass, 0.022)),
        "Wheel": mesh("Wheel", add_cylinder(builder, 0.22, 0.16, rubber, 32)),
        "Hub": mesh("Hub", add_cylinder(builder, 0.11, 0.19, steel, 28)),
        "Rim": mesh("Rim", add_torus(builder, 0.16, 0.025, oxide, 36, 12)),
        "Axle": mesh("Axle", add_cylinder(builder, 0.055, 1.90, oxide, 28)),
        "Bumper": mesh("Bumper", add_beveled_box(builder, (0.18, 0.20, 1.30), oxide, 0.07)),
        "Headlamp": mesh("Headlamp", add_uv_sphere(builder, 0.11, cyan, 18, 32)),
        "GrilleBar": mesh("GrilleBar", add_beveled_box(builder, (0.07, 0.12, 0.66), dark, 0.018)),
        "Panel": mesh("Panel", add_beveled_box(builder, (0.64, 0.08, 0.20), dark, 0.025)),
        "Warning": mesh("Warning", add_beveled_box(builder, (0.13, 0.045, 0.12), amber, 0.018)),
        "Lens": mesh("Lens", add_uv_sphere(builder, 0.09, amber, 18, 32)),
        "Service": mesh("Service", add_beveled_box(builder, (0.82, 0.055, 0.34), cyan, 0.025)),
        "Cable": mesh("Cable", add_cylinder(builder, 0.028, 0.70, cyan, 24)),
        "Shard": mesh("Shard", add_beveled_box(builder, (0.22, 0.04, 0.14), glass, 0.015)),
        "Fastener": mesh("Fastener", add_cylinder(builder, 0.026, 0.035, amber, 20)),
    }

    nodes: list[dict] = [{"name": "VehicleWreckModel", "children": [], "extras": {"ironwright_asset_id": "vehicle_wreck.civic_shell.v1", "asset_quality": "authored_high_definition", "socket_contract": "civic_wreck_shell, service_panel, status_lens"}}]

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

    add_node("VehicleChassis", mesh_ids["Chassis"], (0.0, 0.58, 0.0), extras={"surface": "rounded_civic_shell"})
    add_node("VehicleLowerChassis", mesh_ids["LowerChassis"], (0.0, 0.75, 0.0))
    add_node("VehicleCab", mesh_ids["Cab"], (-0.42, 1.02, 0.0), rotation=(0.0, 0.0, 0.05))
    add_node("VehicleCabRoof", mesh_ids["Roof"], (-0.42, 1.37, 0.0), rotation=(0.0, 0.0, 0.05))
    add_node("VehicleWindshield", mesh_ids["Glass"], (-0.42, 1.14, -0.54), rotation=(0.0, 0.0, 0.08))
    add_node("VehicleRearWindow", mesh_ids["SideGlass"], (-0.42, 1.14, 0.54), rotation=(0.0, 0.0, -0.08))
    add_node("VehicleFrontBumper", mesh_ids["Bumper"], (1.30, 0.52, 0.0))
    add_node("VehicleHeadlampL", mesh_ids["Headlamp"], (1.405, 0.74, -0.43), extras={"surface": "front_service_lamp"})
    add_node("VehicleHeadlampR", mesh_ids["Headlamp"], (1.405, 0.74, 0.43), extras={"surface": "front_service_lamp"})
    add_node("VehicleFrontGrilleUpper", mesh_ids["GrilleBar"], (1.405, 0.62, 0.0), extras={"surface": "front_grille"})
    add_node("VehicleFrontGrilleLower", mesh_ids["GrilleBar"], (1.405, 0.48, 0.0), extras={"surface": "front_grille"})
    for wheel_index, (x, z) in enumerate(((-0.92, -0.68), (0.92, -0.68), (-0.92, 0.68), (0.92, 0.68))):
        wheel_position = (x, 0.31, z)
        add_node("VehicleWheel%02d" % wheel_index, mesh_ids["Wheel"], wheel_position, rotation=(math.pi * 0.5, 0.0, 0.0))
        add_node("VehicleWheelHub%02d" % wheel_index, mesh_ids["Hub"], wheel_position, rotation=(math.pi * 0.5, 0.0, 0.0))
        add_node("VehicleWheelRim%02d" % wheel_index, mesh_ids["Rim"], wheel_position, rotation=(math.pi * 0.5, 0.0, 0.0))
    add_node("VehicleAxle00", mesh_ids["Axle"], (0.0, 0.34, -0.68), rotation=(0.0, 0.0, math.pi * 0.5))
    add_node("VehicleAxle01", mesh_ids["Axle"], (0.0, 0.34, 0.68), rotation=(0.0, 0.0, math.pi * 0.5))
    add_node("VehicleServicePanel", mesh_ids["Service"], (0.68, 0.84, -0.60), rotation=(0.0, 0.0, -0.08), extras={"surface": "maintenance_access"})
    for index in range(4):
        add_node("VehicleServiceFastener%02d" % index, mesh_ids["Fastener"], (0.48 + index * 0.13, 0.91, -0.64))
    add_node("VehicleStatusLens", mesh_ids["Lens"], (1.34, 0.74, -0.62), extras={"socket_type": "status_lens"})
    for index in range(3):
        add_node("VehicleWarningStripe%02d" % index, mesh_ids["Warning"], (0.38 + index * 0.24, 0.88, -0.66), rotation=(0.0, 0.0, 0.15))
    for index, (start, end) in enumerate((((-0.34, 0.78, 0.50), (0.46, 0.90, 0.63)), ((-0.18, 0.83, 0.56), (0.62, 0.92, 0.68)))):
        direction = tuple(end[i] - start[i] for i in range(3))
        length = math.sqrt(sum(value * value for value in direction))
        midpoint = tuple((start[i] + end[i]) * 0.5 for i in range(3))
        pitch = math.atan2(math.sqrt(direction[0] ** 2 + direction[2] ** 2), direction[1])
        yaw = math.atan2(direction[2], direction[0])
        add_node("VehicleCableBundle%02d" % index, mesh_ids["Cable"], midpoint, rotation=(pitch * math.cos(yaw), -pitch * math.sin(yaw), 0.0))
    for index in range(3):
        add_node("VehicleGlassShard%02d" % index, mesh_ids["Shard"], (-0.92 + index * 0.38, 1.46 + (index % 2) * 0.05, -0.56), rotation=(-0.14, 0.24 * index, 0.34))
    add_node("ProductionAssetMarker", extras={"asset_contract": "vehicle_wreck.civic_shell.v1", "source": "original_shared_mesh_builder"})

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original civic vehicle wreck builder"},
        "scene": 0,
        "scenes": [{"name": "VehicleWreck", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {"ironwright_asset_id": "vehicle_wreck.civic_shell.v1", "required_nodes": ["VehicleWreckModel", "VehicleChassis", "VehicleCab", "VehicleCabRoof", "VehicleWindshield", "VehicleServicePanel", "VehicleStatusLens", "VehicleHeadlampL", "VehicleFrontGrilleUpper", "VehicleAxle00", "VehicleCableBundle00", "VehicleGlassShard00", "ProductionAssetMarker"]},
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
