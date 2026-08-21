"""Build the original high-definition Flood Market landmark glTF."""

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


OUTPUT_PATH = SOURCE_DIR / "flood_market.gltf"


def main() -> None:
    builder = BufferBuilder()
    materials = [
        {"name": "Market frame", "pbrMetallicRoughness": {"baseColorFactor": [0.08, 0.14, 0.16, 1.0], "metallicFactor": 0.70, "roughnessFactor": 0.46}},
        {"name": "Market canopy", "pbrMetallicRoughness": {"baseColorFactor": [0.34, 0.12, 0.10, 1.0], "metallicFactor": 0.08, "roughnessFactor": 0.76}},
        {"name": "Market oxidized trim", "pbrMetallicRoughness": {"baseColorFactor": [0.52, 0.22, 0.07, 1.0], "metallicFactor": 0.42, "roughnessFactor": 0.68}, "emissiveFactor": [0.13, 0.025, 0.005]},
        {"name": "Market dark water", "alphaMode": "BLEND", "doubleSided": True, "pbrMetallicRoughness": {"baseColorFactor": [0.04, 0.22, 0.25, 0.60], "metallicFactor": 0.22, "roughnessFactor": 0.18}, "emissiveFactor": [0.01, 0.12, 0.13]},
        {"name": "Market waterline", "pbrMetallicRoughness": {"baseColorFactor": [0.18, 0.55, 0.50, 1.0], "metallicFactor": 0.24, "roughnessFactor": 0.24}, "emissiveFactor": [0.05, 0.32, 0.25]},
        {"name": "Market sign", "pbrMetallicRoughness": {"baseColorFactor": [0.10, 0.22, 0.22, 1.0], "metallicFactor": 0.35, "roughnessFactor": 0.36}, "emissiveFactor": [0.03, 0.25, 0.22]},
        {"name": "Market organic growth", "pbrMetallicRoughness": {"baseColorFactor": [0.07, 0.26, 0.16, 1.0], "metallicFactor": 0.02, "roughnessFactor": 0.78}, "emissiveFactor": [0.03, 0.26, 0.11]},
    ]
    meshes: list[dict] = []

    def mesh(name: str, geometry: tuple[int, int, int, int]) -> int:
        position, normal, indices, material = geometry
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": position, "NORMAL": normal}, "indices": indices, "material": material}]})
        return len(meshes) - 1

    frame, canopy, rust, water, waterline, sign, organic = range(7)
    mesh_ids = {
        "Floor": mesh("MarketFloor", add_box(builder, (18.0, 0.16, 14.0), frame)),
        "Post": mesh("MarketPost", add_box(builder, (0.16, 3.2, 0.16), frame)),
        "Beam": mesh("MarketBeam", add_box(builder, (0.18, 0.18, 6.2), rust)),
        "Canopy": mesh("MarketCanopy", add_box(builder, (6.8, 0.16, 3.1), canopy)),
        "Stall": mesh("MarketStall", add_box(builder, (3.8, 0.28, 1.4), rust)),
        "Water": mesh("MarketWater", add_box(builder, (3.6, 0.04, 1.5), water)),
        "Waterline": mesh("MarketWaterline", add_box(builder, (3.0, 0.035, 0.06), waterline)),
        "Sign": mesh("MarketSign", add_box(builder, (1.6, 0.72, 0.08), sign)),
        "Crane": mesh("MarketCrane", add_cylinder(builder, 0.08, 4.8, frame, 12)),
        "Growth": mesh("MarketGrowth", add_uv_sphere(builder, 0.52, organic, 14, 20)),
        "Glow": mesh("MarketGlow", add_uv_sphere(builder, 0.14, waterline, 12, 18)),
        "Cable": mesh("MarketCable", add_cylinder(builder, 0.04, 4.2, rust, 10)),
        "Marker": mesh("MarketMarker", add_box(builder, (0.7, 0.08, 0.7), rust)),
    }

    nodes: list[dict] = [{
        "name": "FloodMarketModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "flood.market.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "market_canopies, stalls, flood_channels, waterline_signals, service_crane, organic_growth",
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

    add_node("FloodMarketFloor", mesh_ids["Floor"], (0.0, 0.08, 0.0), extras={"socket_type": "market_floor"})
    for index, x in enumerate((-6.0, 0.0, 6.0)):
        canopy_root = add_node("FloodMarketCanopy%d" % index, extras={"socket_type": "market_canopy"})
        add_node("FloodMarketCanopyRoof%d" % index, mesh_ids["Canopy"], (x, 4.0, 1.5), extras={"socket_type": "market_canopy_roof"}, parent=canopy_root)
        for side in (-1.0, 1.0):
            add_node("FloodMarketCanopyPost%d_%s" % (index, "L" if side < 0 else "R"), mesh_ids["Post"], (x + side * 2.7, 1.8, 1.5), parent=canopy_root)
    for index, x in enumerate((-6.0, 0.0, 6.0)):
        add_node("FloodMarketStall%d" % index, mesh_ids["Stall"], (x, 0.36, 1.2), extras={"socket_type": "market_stall"})
        add_node("FloodMarketWaterChannel%d" % index, mesh_ids["Water"], (x, 0.23, 8.8), extras={"socket_type": "flood_channel"})
        add_node("FloodMarketWaterline%d" % index, mesh_ids["Waterline"], (x, 0.31, 8.0), extras={"socket_type": "waterline_signal"})
        add_node("FloodMarketGrowthLight%d" % index, mesh_ids["Glow"], (x, 3.55, 1.5), extras={"socket_type": "stall_light"})
    add_node("FloodMarketMarketSign", mesh_ids["Sign"], (0.0, 3.2, 1.08), rotation=(0.0, 0.0, 0.03), extras={"socket_type": "market_sign"})
    add_node("FloodMarketServiceCrane", mesh_ids["Crane"], (-7.6, 2.5, 5.6), extras={"socket_type": "service_crane"})
    add_node("FloodMarketCraneArm", mesh_ids["Beam"], (-4.4, 4.8, 5.6), rotation=(0.0, math.pi * 0.5, 0.0), extras={"socket_type": "crane_arm"})
    add_node("FloodMarketServiceCable", mesh_ids["Cable"], (-5.8, 3.7, 5.6), rotation=(0.0, 0.0, math.pi * 0.5), extras={"socket_type": "service_cable"})
    for index, (x, z, scale) in enumerate(((-7.2, 5.1, (1.0, 0.8, 1.15)), (6.8, -3.6, (0.85, 0.66, 1.2)))):
        add_node("FloodMarketOrganicGrowth%d" % index, mesh_ids["Growth"], (x, 0.52, z), scale=scale, extras={"socket_type": "organic_growth"})
    add_node("ProductionAssetMarker", None, extras={"asset_contract": "flood.market.v1", "source": "original_procedural_mesh_builder"})

    document = {
        "asset": {"version": "2.0", "generator": "Project Ironwright original Flood Market asset builder"},
        "scene": 0,
        "scenes": [{"name": "FloodMarket", "nodes": [0]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "accessors": builder.accessors,
        "bufferViews": builder.views,
        "buffers": [{"byteLength": len(builder.data), "uri": "data:application/octet-stream;base64," + base64.b64encode(builder.data).decode("ascii")}],
        "extras": {
            "ironwright_asset_id": "flood.market.v1",
            "required_nodes": ["FloodMarketModel", "FloodMarketCanopy0", "FloodMarketStall0", "FloodMarketWaterChannel0", "FloodMarketWaterline0", "FloodMarketServiceCrane", "FloodMarketOrganicGrowth0", "ProductionAssetMarker"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
