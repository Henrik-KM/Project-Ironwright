"""Build the original high-definition Municipal Glasshouse landmark glTF."""

from __future__ import annotations

import base64
import json
import math
import sys
from pathlib import Path
from typing import Sequence


SOURCE_DIR = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "bulwark" / "source"))
from build_bulwark_asset import BufferBuilder, add_box, add_cylinder, add_uv_sphere, quat  # noqa: E402


OUTPUT_PATH = SOURCE_DIR / "glasshouse.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Glasshouse frame", "pbrMetallicRoughness": {"baseColorFactor": [0.08, 0.16, 0.17, 1.0], "metallicFactor": 0.72, "roughnessFactor": 0.42}},
        {"name": "Glasshouse oxidized trim", "pbrMetallicRoughness": {"baseColorFactor": [0.38, 0.16, 0.08, 1.0], "metallicFactor": 0.42, "roughnessFactor": 0.66}},
        {"name": "Glasshouse cold glass", "alphaMode": "BLEND", "doubleSided": True, "pbrMetallicRoughness": {"baseColorFactor": [0.10, 0.27, 0.28, 0.30], "metallicFactor": 0.08, "roughnessFactor": 0.28}, "emissiveFactor": [0.01, 0.07, 0.07]},
        {"name": "Glasshouse grow light", "pbrMetallicRoughness": {"baseColorFactor": [0.18, 0.30, 0.20, 1.0], "metallicFactor": 0.08, "roughnessFactor": 0.48}, "emissiveFactor": [0.16, 0.70, 0.34]},
        {"name": "Glasshouse organic growth", "pbrMetallicRoughness": {"baseColorFactor": [0.06, 0.28, 0.17, 1.0], "metallicFactor": 0.02, "roughnessFactor": 0.78}, "emissiveFactor": [0.03, 0.28, 0.12]},
        {"name": "Glasshouse soil", "pbrMetallicRoughness": {"baseColorFactor": [0.17, 0.12, 0.08, 1.0], "metallicFactor": 0.03, "roughnessFactor": 0.92}},
        {"name": "Glasshouse service amber", "pbrMetallicRoughness": {"baseColorFactor": [0.64, 0.25, 0.05, 1.0], "metallicFactor": 0.10, "roughnessFactor": 0.40}, "emissiveFactor": [0.85, 0.18, 0.02]},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    frame, rust, glass, grow_light, growth, soil, amber = range(7)
    mesh_ids = {
        "Floor": mesh("GlasshouseFloor", add_box(builder, (18.0, 0.16, 14.0), frame)),
        "Post": mesh("GlasshousePost", add_box(builder, (0.20, 6.6, 0.20), frame)),
        "Beam": mesh("GlasshouseBeam", add_box(builder, (0.22, 0.22, 12.2), rust)),
        "Glass": mesh("GlasshouseGlass", add_box(builder, (0.06, 4.9, 5.0), glass)),
        "RoofGlass": mesh("GlasshouseRoofGlass", add_box(builder, (5.0, 0.06, 5.8), glass)),
        "Bed": mesh("GrowthBed", add_box(builder, (3.0, 0.30, 1.20), soil)),
        "Growth": mesh("GrowthCluster", add_uv_sphere(builder, 0.62, growth, 18, 28)),
        "GrowthLight": mesh("GrowthLight", add_uv_sphere(builder, 0.15, grow_light, 16, 24)),
        "Louver": mesh("ClimateLouver", add_box(builder, (2.6, 1.05, 0.16), frame)),
        "LouverSlat": mesh("ClimateLouverSlat", add_box(builder, (2.3, 0.08, 0.10), grow_light)),
        "Door": mesh("GlasshouseServiceDoor", add_box(builder, (2.2, 4.2, 0.18), frame)),
        "DoorTrim": mesh("GlasshouseDoorTrim", add_box(builder, (2.5, 0.14, 0.22), amber)),
        "Skylight": mesh("BrokenSkylight", add_box(builder, (2.9, 0.07, 2.0), glass)),
        "Cable": mesh("ClimateCable", add_cylinder(builder, 0.04, 5.0, amber, 10)),
        "Marker": mesh("GlasshouseMarker", add_box(builder, (0.7, 0.08, 0.7), amber)),
        "RoofRib": mesh("GlasshouseRoofRib", add_box(builder, (0.14, 0.14, 5.8), rust)),
        "PaneLatch": mesh("GlasshousePaneLatch", add_box(builder, (0.16, 0.18, 0.10), amber)),
        "BedEdge": mesh("GlasshouseBedEdge", add_box(builder, (3.25, 0.16, 0.14), frame)),
        "GrowthTendril": mesh("GlasshouseGrowthTendril", add_cylinder(builder, 0.045, 0.92, growth, 14)),
        "LightHousing": mesh("GlasshouseLightHousing", add_cylinder(builder, 0.11, 0.16, frame, 16)),
        "ClimateActuator": mesh("GlasshouseClimateActuator", add_cylinder(builder, 0.08, 0.54, amber, 14)),
    }

    nodes: list[dict] = [{
        "name": "GlasshouseModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "glasshouse.municipal.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "greenhouse_frame, climate_louver, growth_beds, broken_skylight, service_door",
        },
    }]

    def add_node(
        name: str,
        mesh_id: int | None = None,
        translation: Sequence[float] = (0.0, 0.0, 0.0),
        rotation: Sequence[float] = (0.0, 0.0, 0.0),
        scale: Sequence[float] | None = None,
        extras: dict | None = None,
        parent: int = 0,
    ) -> int:
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

    add_node("GlasshouseFloor", mesh_ids["Floor"], (0.0, 0.08, 0.0), extras={"socket_type": "greenhouse_floor"})
    for index, x in enumerate((-8.0, -4.0, 0.0, 4.0, 8.0)):
        add_node("GlasshouseFrameBay%d" % index, mesh_ids["Post"], (x, 3.3, -5.4), extras={"socket_type": "greenhouse_frame"})
        add_node("GlasshouseFrameBay%dRear" % index, mesh_ids["Post"], (x, 3.3, 5.4), extras={"socket_type": "greenhouse_frame"})
    add_node("GlasshouseFrontBeam", mesh_ids["Beam"], (0.0, 6.45, -5.4), rotation=(0.0, math.pi * 0.5, 0.0))
    add_node("GlasshouseRearBeam", mesh_ids["Beam"], (0.0, 6.45, 5.4), rotation=(0.0, math.pi * 0.5, 0.0))
    add_node("GlasshouseSideBeamL", mesh_ids["Beam"], (-8.0, 6.45, 0.0), rotation=(0.0, 0.0, math.pi * 0.5))
    add_node("GlasshouseSideBeamR", mesh_ids["Beam"], (8.0, 6.45, 0.0), rotation=(0.0, 0.0, math.pi * 0.5))
    for index, x in enumerate((-6.0, -2.0, 2.0, 6.0)):
        add_node("GlasshouseRoofRib%d" % index, mesh_ids["RoofRib"], (x, 6.15, 0.0), extras={"surface": "roof_structural_rib"})
    for index, x in enumerate((-6.0, -2.0, 2.0, 6.0)):
        add_node("GlasshouseGlassPanel%d" % index, mesh_ids["Glass"], (x, 3.0, -5.32), rotation=(0.0, 0.0, 0.0))
        add_node("GlasshouseGlassPanel%dRear" % index, mesh_ids["Glass"], (x, 3.0, 5.32), rotation=(0.0, math.pi, 0.0))
        add_node("GlasshousePaneLatch%d" % index, mesh_ids["PaneLatch"], (x, 3.0, -5.47), extras={"surface": "glazing_latch"})

    for index, x in enumerate((-4.5, 0.0, 4.5)):
        bed = add_node("GlasshouseGrowthBed%d" % index, mesh_ids["Bed"], (x, 0.25, 1.8), extras={"socket_type": "growth_bed"})
        add_node("GlasshouseBedEdge%d" % index, mesh_ids["BedEdge"], (0.0, 0.48, 0.0), extras={"surface": "bed_service_edge"}, parent=bed)
        for offset, z in enumerate((1.45, 1.95, 2.45)):
            add_node("GlasshouseGrowthPulse%d_%d" % (index, offset), mesh_ids["Growth"], (0.0, 0.78 + 0.18 * float(offset % 2), z - 1.8), scale=(0.72, 1.15, 0.72), extras={"socket_type": "growth_pulse"}, parent=bed)
        for tendril_index, tendril_x in enumerate((-0.92, 0.88)):
            add_node("GlasshouseGrowthTendril%d_%d" % (index, tendril_index), mesh_ids["GrowthTendril"], (tendril_x, 1.02, 0.0), rotation=(0.0, 0.0, -0.28 + float(tendril_index) * 0.56), extras={"surface": "growth_tendril"}, parent=bed)
        add_node("GlasshouseBedLight%d" % index, mesh_ids["GrowthLight"], (0.0, 1.65, -0.10), extras={"socket_type": "grow_light"}, parent=bed)
        add_node("GlasshouseLightHousing%d" % index, mesh_ids["LightHousing"], (0.0, 1.65, -0.10), extras={"surface": "grow_light_housing"}, parent=bed)

    louver = add_node("GlasshouseClimateLouver", mesh_ids["Louver"], (-6.2, 3.35, 5.28), extras={"socket_type": "climate_louver"})
    for index in range(4):
        add_node("GlasshouseClimateLouverSlat%d" % index, mesh_ids["LouverSlat"], (0.0, -0.30 + float(index) * 0.20, -0.10), rotation=(0.0, 0.0, 0.06 * float(index - 1)), parent=louver)
    add_node("GlasshouseClimateActuator", mesh_ids["ClimateActuator"], (-5.0, 3.35, 5.28), rotation=(0.0, 0.0, math.pi * 0.5), extras={"surface": "climate_actuator"})
    add_node("GlasshouseServiceDoor", mesh_ids["Door"], (0.0, 2.28, -5.72), extras={"socket_type": "service_door"})
    add_node("GlasshouseServiceDoorTrim", mesh_ids["DoorTrim"], (0.0, 4.48, -5.88), extras={"socket_type": "door_trim"})
    add_node("GlasshouseBrokenSkylight", mesh_ids["Skylight"], (3.2, 6.50, 1.0), rotation=(0.16, 0.08, -0.12), extras={"socket_type": "broken_skylight"})
    add_node("GlasshouseCanopyPulse", mesh_ids["GrowthLight"], (0.0, 6.25, 0.6), scale=(8.0, 0.55, 0.55), extras={"socket_type": "canopy_signal"})
    add_node("GlasshouseClimateCable0", mesh_ids["Cable"], (-6.2, 3.0, 4.8), rotation=(0.0, 0.0, math.pi * 0.5), extras={"socket_type": "climate_cable"})
    add_node("GlasshouseClimateCable1", mesh_ids["Cable"], (6.2, 3.0, 4.8), rotation=(0.0, 0.0, math.pi * 0.5), extras={"socket_type": "climate_cable"})
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "glasshouse.municipal.v1", "source": "original_procedural_mesh_builder"})

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Municipal Glasshouse asset builder"},
        "scene": 0,
        "scenes": [{"name": "Glasshouse", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {
            "ironwright_asset_id": "glasshouse.municipal.v1",
            "required_nodes": ["GlasshouseModel", "GlasshouseFrameBay0", "GlasshouseRoofRib0", "GlasshousePaneLatch0", "GlasshouseClimateLouver", "GlasshouseClimateActuator", "GlasshouseBrokenSkylight", "GlasshouseGrowthBed0", "GlasshouseBedEdge0", "GlasshouseGrowthTendril0_0", "GlasshouseLightHousing0", "GlasshouseServiceDoor", "ProductionAssetMarker"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
