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
        {"name": "Market signal ceramic", "pbrMetallicRoughness": {"baseColorFactor": [0.12, 0.42, 0.43, 1.0], "metallicFactor": 0.28, "roughnessFactor": 0.32}, "emissiveFactor": [0.03, 0.28, 0.24]},
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

    frame, canopy, rust, signal_ceramic, water, waterline, sign, organic = range(8)
    mesh_ids = {
        "Floor": mesh("MarketFloor", add_box(builder, (18.0, 0.16, 14.0), frame)),
        "Post": mesh("MarketPost", add_box(builder, (0.16, 3.2, 0.16), frame)),
        "Beam": mesh("MarketBeam", add_box(builder, (0.18, 0.18, 6.2), rust)),
        "Canopy": mesh("MarketCanopy", add_box(builder, (6.8, 0.16, 3.1), canopy)),
        "Stall": mesh("MarketStall", add_box(builder, (3.8, 0.28, 1.4), rust)),
        "Water": mesh("MarketWater", add_box(builder, (3.6, 0.04, 1.5), water)),
        "Waterline": mesh("MarketWaterline", add_box(builder, (3.0, 0.035, 0.06), waterline)),
        "Sign": mesh("MarketSign", add_box(builder, (1.6, 0.72, 0.08), sign)),
        "Crane": mesh("MarketCrane", add_cylinder(builder, 0.08, 4.8, frame, 18)),
        "Growth": mesh("MarketGrowth", add_uv_sphere(builder, 0.52, organic, 18, 28)),
        "Glow": mesh("MarketGlow", add_uv_sphere(builder, 0.14, waterline, 16, 24)),
        "Cable": mesh("MarketCable", add_cylinder(builder, 0.04, 4.2, rust, 10)),
        "Marker": mesh("MarketMarker", add_box(builder, (0.7, 0.08, 0.7), rust)),
        "CanopyRib": mesh("MarketCanopyRib", add_box(builder, (0.10, 0.12, 2.82), rust)),
        "StallFrame": mesh("MarketStallFrame", add_box(builder, (3.9, 0.10, 1.55), frame)),
        "WaterFoam": mesh("MarketWaterFoam", add_box(builder, (2.65, 0.025, 0.10), waterline)),
        "CraneWheel": mesh("MarketCraneWheel", add_cylinder(builder, 0.26, 0.12, rust, 20)),
        "GrowthTendril": mesh("MarketGrowthTendril", add_cylinder(builder, 0.045, 0.78, organic, 14)),
        "GlowHousing": mesh("MarketGlowHousing", add_cylinder(builder, 0.11, 0.14, frame, 16)),
        "ServiceBox": mesh("MarketServiceBox", add_box(builder, (0.72, 0.32, 0.64), frame)),
        "ServiceLatch": mesh("MarketServiceLatch", add_box(builder, (0.12, 0.16, 0.3), waterline)),
        "CargoCrate": mesh("MarketCargoCrate", add_box(builder, (0.72, 0.62, 0.72), rust)),
        "CargoBand": mesh("MarketCargoBand", add_box(builder, (0.8, 0.08, 0.08), sign)),
        "DrainGrate": mesh("MarketDrainGrate", add_box(builder, (1.1, 0.06, 0.42), frame)),
        "CanopyAnchor": mesh("MarketCanopyAnchor", add_cylinder(builder, 0.12, 0.14, rust, 16)),
        "HangingHook": mesh("MarketHangingHook", add_cylinder(builder, 0.05, 0.32, frame, 12)),
        "TideGatePost": mesh("MarketTideGatePost", add_cylinder(builder, 0.18, 5.6, frame, 18)),
        "TideGateBeam": mesh("MarketTideGateBeam", add_box(builder, (15.2, 0.22, 0.22), rust)),
        "TideGateFin": mesh("MarketTideGateFin", add_box(builder, (0.12, 2.4, 0.72), signal_ceramic)),
        "FloodDeck": mesh("MarketFloodDeck", add_box(builder, (4.8, 0.16, 1.35), frame)),
        "FloodDeckRail": mesh("MarketFloodDeckRail", add_box(builder, (0.07, 0.62, 1.28), rust)),
        "Banner": mesh("MarketBanner", add_box(builder, (1.35, 1.0, 0.06), canopy)),
        "TideBeacon": mesh("MarketTideBeacon", add_uv_sphere(builder, 0.18, signal_ceramic, 16, 24)),
        "TideBeaconStem": mesh("MarketTideBeaconStem", add_cylinder(builder, 0.045, 0.52, frame, 12)),
        "ForegroundWater": mesh("MarketForegroundWater", add_box(builder, (4.2, 0.035, 1.2), water)),
        "ForegroundFoam": mesh("MarketForegroundFoam", add_box(builder, (3.1, 0.025, 0.08), waterline)),
    }

    nodes: list[dict] = [{
        "name": "FloodMarketModel",
        "children": [],
        "extras": {
            "ironwright_asset_id": "flood.market.v1",
            "asset_quality": "authored_high_definition",
            "socket_contract": "market_canopies, stalls, flood_channels, waterline_signals, service_crane, organic_growth, service_hardware",
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
        for rib_index, rib_offset in enumerate((-2.0, 0.0, 2.0)):
            add_node("FloodMarketCanopyRib%d_%d" % (index, rib_index), mesh_ids["CanopyRib"], (x + rib_offset, 4.08, 1.5), extras={"surface": "canopy_structural_rib"}, parent=canopy_root)
        for side in (-1.0, 1.0):
            add_node("FloodMarketCanopyPost%d_%s" % (index, "L" if side < 0 else "R"), mesh_ids["Post"], (x + side * 2.7, 1.8, 1.5), parent=canopy_root)
    for index, x in enumerate((-6.0, 0.0, 6.0)):
        add_node("FloodMarketStall%d" % index, mesh_ids["Stall"], (x, 0.36, 1.2), extras={"socket_type": "market_stall"})
        add_node("FloodMarketStallFrame%d" % index, mesh_ids["StallFrame"], (x, 0.58, 1.2), extras={"surface": "stall_service_frame"})
        add_node("FloodMarketServiceBox%d" % index, mesh_ids["ServiceBox"], (x + 1.18, 0.72, 0.5), extras={"socket_type": "stall_service_hardware"})
        add_node("FloodMarketServiceLatch%d" % index, mesh_ids["ServiceLatch"], (x + 1.18, 0.94, 0.15), extras={"surface": "service_latch"})
        add_node("FloodMarketCargoCrate%d" % index, mesh_ids["CargoCrate"], (x - 1.25, 0.7, 0.45), extras={"socket_type": "market_cargo"})
        add_node("FloodMarketCargoBand%d" % index, mesh_ids["CargoBand"], (x - 1.25, 1.03, 0.45), extras={"surface": "cargo_binding"})
        add_node("FloodMarketDrainGrate%d" % index, mesh_ids["DrainGrate"], (x, 0.38, -0.15), extras={"surface": "flood_drainage"})
        add_node("FloodMarketCanopyAnchor%dL" % index, mesh_ids["CanopyAnchor"], (x - 2.7, 3.56, 1.5), extras={"surface": "canopy_anchor"})
        add_node("FloodMarketCanopyAnchor%dR" % index, mesh_ids["CanopyAnchor"], (x + 2.7, 3.56, 1.5), extras={"surface": "canopy_anchor"})
        add_node("FloodMarketHangingHook%d" % index, mesh_ids["HangingHook"], (x, 3.44, 0.74), extras={"surface": "market_hanging_hardware"})
        add_node("FloodMarketWaterChannel%d" % index, mesh_ids["Water"], (x, 0.23, 8.8), extras={"socket_type": "flood_channel"})
        add_node("FloodMarketWaterline%d" % index, mesh_ids["Waterline"], (x, 0.31, 8.0), extras={"socket_type": "waterline_signal"})
        for foam_index, foam_z in enumerate((5.6, -1.2)):
            add_node("FloodMarketWaterFoam%d_%d" % (index, foam_index), mesh_ids["WaterFoam"], (x, 0.34, foam_z), extras={"surface": "water_foam_band"})
        add_node("FloodMarketGlowHousing%d" % index, mesh_ids["GlowHousing"], (x, 3.55, 1.5), extras={"surface": "stall_light_housing"})
        add_node("FloodMarketGrowthLight%d" % index, mesh_ids["Glow"], (x, 3.55, 1.5), extras={"socket_type": "stall_light"})
    add_node("FloodMarketMarketSign", mesh_ids["Sign"], (0.0, 3.2, 1.08), rotation=(0.0, 0.0, 0.03), extras={"socket_type": "market_sign"})
    # The civic market needs a strong vertical read from the approach: a
    # tide-control arch and suspended vendor banners make the flooded district
    # legible before the player reaches the stalls.
    for index, x in enumerate((-7.2, 7.2)):
        add_node("FloodMarketTideGatePost%d" % index, mesh_ids["TideGatePost"], (x, 2.8, 6.8), extras={"socket_type": "tide_gate_post"})
    add_node("FloodMarketTideGateBeam", mesh_ids["TideGateBeam"], (0.0, 5.45, 6.8), extras={"socket_type": "tide_gate_beam"})
    for index, x in enumerate((-4.8, -1.6, 1.6, 4.8)):
        add_node("FloodMarketTideGateFin%d" % index, mesh_ids["TideGateFin"], (x, 4.02, 6.68), rotation=(0.0, 0.0, -0.08 + float(index % 2) * 0.16), extras={"surface": "tide_gate_fin"})
        add_node("FloodMarketTideBeacon%d" % index, mesh_ids["TideBeacon"], (x, 5.7, 6.72), extras={"socket_type": "tide_beacon"})
        add_node("FloodMarketTideBeaconStem%d" % index, mesh_ids["TideBeaconStem"], (x, 5.4, 6.72), extras={"surface": "tide_beacon_stem"})
    for index, x in enumerate((-4.0, 0.0, 4.0)):
        add_node("FloodMarketFloodDeck%d" % index, mesh_ids["FloodDeck"], (x, 0.58, 5.25), extras={"socket_type": "flood_deck"})
        add_node("FloodMarketFloodDeckRail%dL" % index, mesh_ids["FloodDeckRail"], (x - 2.35, 0.92, 5.25), extras={"surface": "flood_deck_rail"})
        add_node("FloodMarketFloodDeckRail%dR" % index, mesh_ids["FloodDeckRail"], (x + 2.35, 0.92, 5.25), extras={"surface": "flood_deck_rail"})
        add_node("FloodMarketBanner%d" % index, mesh_ids["Banner"], (x, 3.05, 5.1), rotation=(0.0, 0.0, -0.06 + float(index) * 0.06), extras={"surface": "suspended_vendor_banner"})
    for index, x in enumerate((-5.0, 0.0, 5.0)):
        add_node("FloodMarketForegroundWater%d" % index, mesh_ids["ForegroundWater"], (x, 0.13, -2.0), extras={"socket_type": "foreground_flood_channel"})
        add_node("FloodMarketForegroundFoam%d" % index, mesh_ids["ForegroundFoam"], (x, 0.18, -1.38), extras={"surface": "foreground_waterline"})
    add_node("FloodMarketServiceCrane", mesh_ids["Crane"], (-7.6, 2.5, 5.6), extras={"socket_type": "service_crane"})
    add_node("FloodMarketCraneArm", mesh_ids["Beam"], (-4.4, 4.8, 5.6), rotation=(0.0, math.pi * 0.5, 0.0), extras={"socket_type": "crane_arm"})
    add_node("FloodMarketCraneWheel", mesh_ids["CraneWheel"], (-6.0, 2.6, 5.6), rotation=(math.pi * 0.5, 0.0, 0.0), extras={"surface": "crane_service_wheel"})
    add_node("FloodMarketServiceCable", mesh_ids["Cable"], (-5.8, 3.7, 5.6), rotation=(0.0, 0.0, math.pi * 0.5), extras={"socket_type": "service_cable"})
    for index, (x, z, scale) in enumerate(((-7.2, 5.1, (1.0, 0.8, 1.15)), (6.8, -3.6, (0.85, 0.66, 1.2)))):
        add_node("FloodMarketOrganicGrowth%d" % index, mesh_ids["Growth"], (x, 0.52, z), scale=scale, extras={"socket_type": "organic_growth"})
        for tendril_index, tendril_x in enumerate((-0.22, 0.16)):
            add_node("FloodMarketOrganicTendril%d_%d" % (index, tendril_index), mesh_ids["GrowthTendril"], (x + tendril_x, 0.82, z), rotation=(0.0, 0.0, -0.26 + float(tendril_index) * 0.42), extras={"surface": "organic_tendril"})
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
            "required_nodes": ["FloodMarketModel", "FloodMarketCanopy0", "FloodMarketCanopyRib0_0", "FloodMarketStall0", "FloodMarketStallFrame0", "FloodMarketServiceBox0", "FloodMarketServiceLatch0", "FloodMarketCargoCrate0", "FloodMarketDrainGrate0", "FloodMarketCanopyAnchor0L", "FloodMarketHangingHook0", "FloodMarketWaterChannel0", "FloodMarketWaterline0", "FloodMarketWaterFoam0_0", "FloodMarketTideGatePost0", "FloodMarketTideGateBeam", "FloodMarketTideGateFin0", "FloodMarketTideBeacon0", "FloodMarketFloodDeck0", "FloodMarketFloodDeckRail0L", "FloodMarketBanner0", "FloodMarketForegroundWater0", "FloodMarketForegroundFoam0", "FloodMarketServiceCrane", "FloodMarketCraneWheel", "FloodMarketOrganicGrowth0", "FloodMarketOrganicTendril0_0", "ProductionAssetMarker"],
        },
    }
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_PATH.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT_PATH} with {len(nodes)} named nodes and {len(meshes)} meshes")


if __name__ == "__main__":
    main()
