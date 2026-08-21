#!/usr/bin/env python3
"""Validate the native aesthetic, vertical slice and pre-alpha presentation integration."""
from pathlib import Path
import json
import sys

ROOT = Path(__file__).resolve().parents[1]

REQUIRED = [
    "game/scripts/main_world_beautiful_3d.gd",
    "game/scripts/main_world_full_game_3d.gd",
    "game/scripts/main_world_production_3d.gd",
    "game/scripts/main_world_complete_3d.gd",
    "game/scripts/main_world_prealpha_3d.gd",
    "game/scripts/presentation/aesthetic_director_3d.gd",
    "game/scripts/presentation/sanctuary_decorator_3d.gd",
    "game/scripts/presentation/urban_decorator_3d.gd",
    "game/scripts/presentation/presentation_feedback_3d.gd",
    "game/scripts/presentation/procedural_animator_3d.gd",
    "game/scripts/presentation/mechromancer_presentation_3d.gd",
    "game/scripts/presentation/objective_guidance_3d.gd",
    "game/scripts/presentation/vertical_slice_director_3d.gd",
    "game/scripts/presentation/vertical_slice_actor_art_3d.gd",
    "game/scripts/ui/ironwright_beautiful_hud_3d.gd",
    "game/scripts/ui/ironwright_prealpha_hud_3d.gd",
    "game/scripts/ui/operations_command_hud_3d.gd",
    "game/tests/aesthetic_test_runner.gd",
    "game/tests/presentation_and_salvage_escort_test_runner.gd",
    "game/tests/intelligence_and_vertical_slice_test_runner.gd",
    "docs/PRESENTATION_QUALITY_GATE.md",
    "docs/VERTICAL_SLICE_INTELLIGENCE.md",
    "game/assets/mechromancer/mechromancer.gltf",
    "game/assets/mechromancer/mechromancer.bin",
    "game/assets/mechromancer/source/mechromancer.blend",
    "game/assets/mechromancer/mechromancer_portrait.png",
    "game/assets/mechromancer/mechromancer_coat.png",
    "game/assets/mechromancer/mechromancer_leather.png",
    "game/assets/mechromancer/mechromancer_metal.png",
    "game/assets/mechromancer/mechromancer_skin.png",
    "game/assets/mechromancer/mechromancer_coat_normal.png",
    "game/assets/mechromancer/mechromancer_leather_normal.png",
    "game/assets/mechromancer/mechromancer_metal_normal.png",
    "game/assets/mechromancer/mechromancer_skin_normal.png",
    "game/assets/mechromancer/source/build_mechromancer_blend.py",
    "game/assets/mechromancer/source/build_mechromancer_asset.py",
    "game/data/mechromancer_asset_manifest.json",
    "game/assets/organic_families/source/build_authored_organic_assets.py",
    "game/assets/riverworks/source/build_riverworks_asset.py",
    "game/assets/riverworks/riverworks.gltf",
    "game/data/riverworks_asset_manifest.json",
    "game/assets/cathedral/source/build_cathedral_asset.py",
    "game/assets/cathedral/cathedral.gltf",
    "game/data/cathedral_asset_manifest.json",
    "game/assets/observatory/source/build_observatory_asset.py",
    "game/assets/observatory/observatory.gltf",
    "game/data/observatory_asset_manifest.json",
    "game/assets/tram_graveyard/source/build_tram_graveyard_asset.py",
    "game/assets/tram_graveyard/tram_graveyard.gltf",
    "game/data/tram_graveyard_asset_manifest.json",
    "game/assets/buried_labs/source/build_buried_labs_asset.py",
    "game/assets/buried_labs/buried_labs.gltf",
    "game/data/buried_labs_asset_manifest.json",
    "game/assets/glasshouse/source/build_glasshouse_asset.py",
    "game/assets/glasshouse/glasshouse.gltf",
    "game/data/glasshouse_asset_manifest.json",
    "game/assets/archive/source/build_archive_asset.py",
    "game/assets/archive/archive.gltf",
    "game/data/archive_asset_manifest.json",
    "game/assets/tenement/source/build_tenement_asset.py",
    "game/assets/tenement/tenement.gltf",
    "game/data/tenement_asset_manifest.json",
    "game/assets/flood_market/source/build_flood_market_asset.py",
    "game/assets/flood_market/flood_market.gltf",
    "game/data/flood_market_asset_manifest.json",
    "game/assets/west_grid/source/build_west_grid_asset.py",
    "game/assets/west_grid/west_grid.gltf",
    "game/data/west_grid_asset_manifest.json",
]

AUTHORED_ORGANIC_ASSETS = {
    "roofleaper": {
        "asset_id": "roofleaper.ambusher.v1",
        "root": "RoofleaperModel",
        "required": ["RoofleaperModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "RoofleaperCrown", "RoofleaperWingL", "RoofleaperFineVeinL", "RoofleaperFineVeinR", "ProductionAssetMarker"],
    },
    "glassmoth": {
        "asset_id": "glassmoth.swarm.v1",
        "root": "GlassmothModel",
        "required": ["GlassmothModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "GlassmothThorax", "GlassmothWingL0", "GlassmothFineVeinL0", "GlassmothFineVeinR0", "ProductionAssetMarker"],
    },
    "miremaw": {
        "asset_id": "miremaw.amphibious.v1",
        "root": "MiremawModel",
        "required": ["MiremawModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "MiremawHead", "MiremawGillFan", "MiremawGillRidgeL", "MiremawGillRidgeR", "ProductionAssetMarker"],
    },
    "carrionbell": {
        "asset_id": "carrionbell.signal.v1",
        "root": "CarrionbellModel",
        "required": ["CarrionbellModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "CarrionbellMantle", "CarrionbellResonator", "CarrionbellResonatorRing", "ProductionAssetMarker"],
    },
    "rootweaver": {
        "asset_id": "rootweaver.route_controller.v1",
        "root": "RootweaverModel",
        "required": ["RootweaverModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "RootweaverCrown", "RootweaverSporeFan", "RootweaverKnuckleL", "RootweaverKnuckleR", "ProductionAssetMarker"],
    },
}

AUTHORED_REGION_ASSETS = {
    "riverworks": {
        "asset_id": "riverworks.landmark.v1",
        "root": "RiverworksModel",
        "required": [
            "RiverworksModel",
            "RiverworksPumpCore",
            "RiverworksPumpHousing",
            "RiverworksPumpPanel",
            "RiverworksRotor",
            "RiverworksRotorHub",
            "RiverworksMaintenanceValve",
            "RiverworksValveHandle",
            "RiverworksSluiceGate",
            "RiverworksSluiceRail",
            "RiverworksSluiceLatch",
            "RiverworksSluiceSignalHousing",
            "RiverworksSluiceSignal",
            "RiverworksCableClamp",
            "RiverworksGrowth0",
            "RiverworksGrowthTendril0_0",
            "ProductionAssetMarker",
        ],
    },
    "cathedral": {
        "asset_id": "cathedral.quarter.v1",
        "root": "CathedralModel",
        "required": [
            "CathedralModel",
            "CathedralNave",
            "CathedralRoseWindow",
            "CathedralChoirCore",
            "CathedralChoirSignal",
            "CathedralBell",
            "ProductionAssetMarker",
        ],
    },
    "observatory": {
        "asset_id": "observatory.ridge.v1",
        "root": "ObservatoryModel",
        "required": [
            "ObservatoryModel",
            "ObservatoryDish",
            "ObservatoryDishRib0",
            "ObservatoryDishActuator",
            "ObservatoryFeedSignal",
            "ObservatoryFeedCollar",
            "ObservatoryMast",
            "ObservatoryMastCollar",
            "ObservatoryConsole",
            "ObservatoryFrontConsole",
            "ObservatoryFrontConsoleFrame",
            "ObservatoryServiceDeck",
            "ObservatoryDeckPost0",
            "ObservatoryControlWindow0",
            "ObservatoryControlWindowFrame0",
            "ObservatoryControlWindowMullion0",
            "ObservatorySurveyRail0",
            "ObservatoryCableAnchor0",
            "ObservatorySurveyLightHousing0",
            "ProductionAssetMarker",
        ],
    },
    "tram_graveyard": {
        "asset_id": "tram.graveyard.v1",
        "root": "TramGraveyardModel",
        "required": [
            "TramGraveyardModel",
            "TramCarriageA",
            "TramCarriageADoor",
            "TramCarriageAFrontWindow0",
            "TramCarriageAFrontDoor",
            "TramCarriageAFrontHeadlampHousing",
            "TramCarriageABogiePlate0",
            "TramCarriageAPantograph",
            "TramMaintenancePit",
            "TramPitRung0",
            "TramSignalMast",
            "TramSignalHousing",
            "TramSignalLamp",
            "TramCableClamp0",
            "TramOrganicSeep0",
            "TramOrganicSeepTendril0_0",
            "ProductionAssetMarker",
        ],
    },
    "buried_labs": {
        "asset_id": "buried.labs.v1",
        "root": "BuriedLabsModel",
        "required": [
            "BuriedLabsModel",
            "BuriedLabsContainmentHall",
            "BuriedLabsVessel0",
            "BuriedLabsVesselCore0",
            "BuriedLabsVesselPort0",
            "BuriedLabsVesselClampL0",
            "BuriedLabsTransferRail",
            "BuriedLabsTransferCarriage",
            "BuriedLabsTransferRailStopL",
            "BuriedLabsContainmentDoor",
            "BuriedLabsContainmentDoorJambL",
            "BuriedLabsContainmentDoorLintel",
            "BuriedLabsWarningPanelFrame",
            "BuriedLabsCableClamp0",
            "BuriedLabsOrganicSeep0",
            "BuriedLabsOrganicTendril0_0",
            "ProductionAssetMarker",
        ],
    },
    "glasshouse": {
        "asset_id": "glasshouse.municipal.v1",
        "root": "GlasshouseModel",
        "required": [
            "GlasshouseModel",
            "GlasshouseFrameBay0",
            "GlasshouseRoofRib0",
            "GlasshousePaneLatch0",
            "GlasshouseClimateLouver",
            "GlasshouseClimateActuator",
            "GlasshouseBrokenSkylight",
            "GlasshouseGrowthBed0",
            "GlasshouseBedEdge0",
            "GlasshouseGrowthTendril0_0",
            "GlasshouseLightHousing0",
            "GlasshouseServiceDoor",
            "ProductionAssetMarker",
        ],
    },
    "archive": {
        "asset_id": "archive.north_ruins.v1",
        "root": "ArchiveModel",
        "required": [
            "ArchiveModel",
            "ArchiveCivicFacade",
            "ArchiveFacadeWindowL",
            "ArchiveWindowFrameL",
            "ArchiveWindowMullionL",
            "ArchiveVaultDoor",
            "ArchiveVaultDoorJambL",
            "ArchiveVaultDoorLintel",
            "ArchiveCivicPlaque",
            "ArchiveRoofBeacon",
            "ArchiveBeaconCollar",
            "ArchiveBeaconBraceL",
            "ArchiveStack0",
            "ArchiveShelfDivider0_0",
            "ArchiveShelfRail0",
            "ArchiveOrganicCreep0",
            "ArchiveOrganicTendril0_0",
            "ProductionAssetMarker",
        ],
    },
    "tenement": {
        "asset_id": "tenement.east_blocks.v1",
        "root": "TenementModel",
        "required": [
            "TenementModel",
            "TenementBlockL",
            "TenementFrontWindowL0_0",
            "TenementFrontWindowLintelL0_0",
            "TenementFrontWindowSillL0_0",
            "TenementBlockLEdgeL",
            "TenementBalcony0",
            "TenementBalconyBrace0_L",
            "TenementFireEscapeLadder",
            "TenementRoofWaterTank",
            "TenementTankValve",
            "TenementLaundryLine0",
            "TenementLightHousingL",
            "TenementOrganicCreep0",
            "TenementOrganicTendril0_0",
            "ProductionAssetMarker",
        ],
    },
    "flood_market": {
        "asset_id": "flood.market.v1",
        "root": "FloodMarketModel",
        "required": [
            "FloodMarketModel",
            "FloodMarketCanopy0",
            "FloodMarketCanopyRib0_0",
            "FloodMarketStall0",
            "FloodMarketStallFrame0",
            "FloodMarketWaterChannel0",
            "FloodMarketWaterline0",
            "FloodMarketWaterFoam0_0",
            "FloodMarketServiceCrane",
            "FloodMarketCraneWheel",
            "FloodMarketOrganicGrowth0",
            "FloodMarketOrganicTendril0_0",
            "ProductionAssetMarker",
        ],
    },
    "west_grid": {
        "asset_id": "west.grid.substation.v1",
        "root": "WestGridModel",
        "required": [
            "WestGridModel",
            "WestGridTurbineHall",
            "WestGridWindowFrame0",
            "WestGridWindowMullion0",
            "WestGridPressureTank0",
            "WestGridTankValve0",
            "WestGridTankLadder0",
            "WestGridTransformer0",
            "WestGridTransformerCap0",
            "WestGridTransformerBrace0",
            "WestGridPipeBridge",
            "WestGridPipeFlange0",
            "WestGridWarningHousing0",
            "WestGridWarningLight0",
            "WestGridOrganicCreep0",
            "WestGridOrganicTendril0_0",
            "ProductionAssetMarker",
        ],
    },
}


def fail(message: str) -> None:
    raise RuntimeError(message)


def validate_mechromancer_asset() -> None:
    manifest_path = ROOT / "game/data/mechromancer_asset_manifest.json"
    gltf_path = ROOT / "game/assets/mechromancer/mechromancer.gltf"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    gltf = json.loads(gltf_path.read_text(encoding="utf-8"))
    if manifest.get("asset_id") != "mechromancer.player.v1":
        fail("Mechromancer asset manifest has an unexpected stable asset ID.")
    if manifest.get("runtime_model") != "res://assets/mechromancer/mechromancer.gltf":
        fail("Mechromancer asset manifest points at an unexpected runtime model.")
    if manifest.get("runtime_buffer") != "res://assets/mechromancer/mechromancer.bin":
        fail("Mechromancer asset manifest must document the glTF buffer.")
    root_node_extras = next(
        (
            node.get("extras", {})
            for node in gltf.get("nodes", [])
            if node.get("name") == "MechromancerModel"
        ),
        {},
    )
    gltf_asset_id = gltf.get("extras", {}).get("ironwright_asset_id") or root_node_extras.get("ironwright_asset_id")
    if gltf_asset_id != manifest["asset_id"]:
        fail("Mechromancer glTF and manifest asset IDs must match.")
    node_names = {str(node.get("name")) for node in gltf.get("nodes", [])}
    for required in manifest.get("required_nodes", []):
        if required not in node_names:
            fail(f"Mechromancer glTF is missing required node: {required}")
    animation_names = {str(animation.get("name")) for animation in gltf.get("animations", [])}
    for required in manifest.get("animation_clips", []):
        if required not in animation_names:
            fail(f"Mechromancer glTF is missing required animation clip: {required}")
    if not str(manifest.get("portrait", "")).endswith("mechromancer_portrait.png"):
        fail("Mechromancer manifest must point to the authored portrait.")
    image_uris = {str(image.get("uri")) for image in gltf.get("images", [])}
    for texture_path in manifest.get("textures", []):
        if Path(str(texture_path)).name not in image_uris:
            fail(f"Mechromancer glTF is missing manifest texture: {texture_path}")


def validate_authored_organic_assets() -> None:
    for family, expected in AUTHORED_ORGANIC_ASSETS.items():
        manifest_path = ROOT / f"game/data/{family}_asset_manifest.json"
        gltf_path = ROOT / f"game/assets/{family}/{family}.gltf"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        gltf = json.loads(gltf_path.read_text(encoding="utf-8"))
        if manifest.get("asset_id") != expected["asset_id"]:
            fail(f"{family} asset manifest has an unexpected stable asset ID.")
        if manifest.get("runtime_path") != f"res://assets/{family}/{family}.gltf":
            fail(f"{family} asset manifest points at an unexpected runtime model.")
        root_node_extras = next(
            (node.get("extras", {}) for node in gltf.get("nodes", []) if node.get("name") == expected["root"]),
            {},
        )
        gltf_asset_id = gltf.get("extras", {}).get("ironwright_asset_id") or root_node_extras.get("ironwright_asset_id")
        if gltf_asset_id != expected["asset_id"]:
            fail(f"{family} glTF and manifest asset IDs must match.")
        node_names = {str(node.get("name")) for node in gltf.get("nodes", [])}
        for required in expected["required"]:
            if required not in node_names:
                fail(f"{family} glTF is missing required node: {required}")
        animation_names = {str(animation.get("name")) for animation in gltf.get("animations", [])}
        for required in manifest.get("animation_clips", []):
            if required not in animation_names:
                fail(f"{family} glTF is missing required animation clip: {required}")


def validate_authored_region_assets() -> None:
    for family, expected in AUTHORED_REGION_ASSETS.items():
        manifest_path = ROOT / f"game/data/{family}_asset_manifest.json"
        gltf_path = ROOT / f"game/assets/{family}/{family}.gltf"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        gltf = json.loads(gltf_path.read_text(encoding="utf-8"))
        if manifest.get("asset_id") != expected["asset_id"]:
            fail(f"{family} landmark manifest has an unexpected stable asset ID.")
        if manifest.get("runtime_model") != f"game/assets/{family}/{family}.gltf":
            fail(f"{family} landmark manifest points at an unexpected runtime model.")
        root_node_extras = next(
            (node.get("extras", {}) for node in gltf.get("nodes", []) if node.get("name") == expected["root"]),
            {},
        )
        gltf_asset_id = gltf.get("extras", {}).get("ironwright_asset_id") or root_node_extras.get("ironwright_asset_id")
        if gltf_asset_id != expected["asset_id"]:
            fail(f"{family} landmark glTF and manifest asset IDs must match.")
        node_names = {str(node.get("name")) for node in gltf.get("nodes", [])}
        for required in expected["required"]:
            if required not in node_names:
                fail(f"{family} landmark glTF is missing required node: {required}")


def main() -> int:
    try:
        for relative in REQUIRED:
            path = ROOT / relative
            if not path.is_file() or path.stat().st_size < 100:
                fail(f"Missing or unexpectedly empty aesthetic file: {relative}")

        validate_mechromancer_asset()
        validate_authored_organic_assets()
        validate_authored_region_assets()

        main_scene = (ROOT / "game/scenes/main_3d.tscn").read_text(encoding="utf-8")
        if all(entrypoint not in main_scene for entrypoint in ["main_world_prealpha_3d.gd", "main_world_release_3d.gd", "main_world_tiered_3d.gd"]):
            fail("The native entrypoint must boot the merged vertical-slice, release, or tiered world.")

        prealpha = (ROOT / "game/scripts/main_world_prealpha_3d.gd").read_text(encoding="utf-8")
        release = (ROOT / "game/scripts/main_world_release_3d.gd").read_text(encoding="utf-8")
        tiered = (ROOT / "game/scripts/main_world_tiered_3d.gd").read_text(encoding="utf-8")
        complete = (ROOT / "game/scripts/main_world_complete_3d.gd").read_text(encoding="utf-8")
        production = (ROOT / "game/scripts/main_world_production_3d.gd").read_text(encoding="utf-8")
        full_game = (ROOT / "game/scripts/main_world_full_game_3d.gd").read_text(encoding="utf-8")
        beautiful = (ROOT / "game/scripts/main_world_beautiful_3d.gd").read_text(encoding="utf-8")
        if "extends IronwrightProductionWorld3D" not in prealpha:
            fail("Vertical-slice world must preserve the production systemic game.")
        for token in ["_resolve_camera_occlusion", "set_map_emphasis", "VerticalSliceDirector3D", "VerticalSliceActorArt3D", "_nearby_threat_camera_bias"]:
            if token not in prealpha:
                fail(f"Pre-alpha vertical-slice world is missing {token}")
        if "extends IronwrightFullGameWorld3D" not in complete:
            fail("Complete-game world must preserve the full-game layer.")
        if "extends IronwrightCompleteGameWorld3D" not in production:
            fail("Production world must preserve the complete systemic game.")
        if "extends IronwrightBeautifulWorld3D" not in full_game:
            fail("Full-game world must preserve the aesthetic layer.")
        if "AestheticDirector3D" not in beautiful:
            fail("Beautiful world must still install the aesthetic director.")
        if "main_world_release_3d.gd" in main_scene:
            for token in ["extends IronwrightProductionWorld3D", "_setup_vertical_slice_presentation", "VerticalSliceDirector3D", "VerticalSliceActorArt3D"]:
                if token not in release:
                    fail(f"Release entrypoint is missing merged presentation behaviour: {token}")
        if "main_world_tiered_3d.gd" in main_scene:
            for token in ["extends IronwrightReleaseWorld3D", "EnemyTierDirector3D", "EnemyTierEventBridge3D", "EnemyTierHUD3D"]:
                if token not in tiered:
                    fail(f"Tiered entrypoint is missing merged release/ecology behaviour: {token}")

        hud_scene = (ROOT / "game/scenes/ui/ironwright_hud_3d.tscn").read_text(encoding="utf-8")
        if "ironwright_prealpha_hud_3d.gd" not in hud_scene:
            fail("The native HUD scene must use the quieter desktop pre-alpha skin.")

        presentation_sources = "\n".join(
            (ROOT / relative).read_text(encoding="utf-8")
            for relative in [
                "game/scripts/presentation/aesthetic_director_3d.gd",
                "game/scripts/presentation/sanctuary_decorator_3d.gd",
                "game/scripts/presentation/urban_decorator_3d.gd",
                "game/scripts/presentation/presentation_feedback_3d.gd",
            ]
        )
        required_tokens = [
            "ambient_light_energy = 0.56",
            "fog_density = 0.0085",
            "CozyHeartforgeCamp",
            "UrbanAestheticPass",
            "HeartforgeEmbers",
            "ProceduralAnimator3D",
            "_spawn_noise_ring",
            "_add_actor_details",
        ]
        for token in required_tokens:
            if token not in presentation_sources:
                fail(f"Presentation layer is missing required behaviour: {token}")

        vertical = (ROOT / "game/scripts/presentation/vertical_slice_director_3d.gd").read_text(encoding="utf-8")
        for token in [
            "HeartforgeVerticalSlice",
            "VerticalSliceFacade",
            "HeartforgePlazaDetail",
            "ImprovisedSanctuaryPerimeter",
            "ForgeMaintenanceGantry",
            "VisibleOrganicNests",
            "LocalRain",
            "StreetSteam",
        ]:
            if token not in vertical:
                fail(f"Heartforge vertical slice is missing {token}")

        actor_art = (ROOT / "game/scripts/presentation/vertical_slice_actor_art_3d.gd").read_text(encoding="utf-8")
        for token in [
            "VerticalSliceCharacterArt",
            "VerticalSliceMachineArt",
            "VerticalSliceForgeArt",
            "DeepHood",
            "BulwarkFrontPlate",
            "WardenAutocannon",
            "DeepScrapHopper",
            "PathfinderDish",
        ]:
            if token not in actor_art:
                fail(f"Vertical-slice actor art is missing {token}")

        animator = (ROOT / "game/scripts/presentation/procedural_animator_3d.gd").read_text(encoding="utf-8")
        for token in ["_animate_mechromancer", "_animate_robot", "_animate_organic", "recoil", "hit_impulse"]:
            if token not in animator:
                fail(f"Procedural animator is missing {token}")

        guidance = (ROOT / "game/scripts/presentation/objective_guidance_3d.gd").read_text(encoding="utf-8")
        if "marker_label.fixed_size = false" not in guidance:
            fail("Objective labels may not return to giant fixed-size screen billboards.")

        landmark = (ROOT / "game/scripts/world/region_landmark_3d.gd").read_text(encoding="utf-8")
        for token in ["_label.fixed_size = false", "set_map_emphasis", "_label.visible = false"]:
            if token not in landmark:
                fail(f"Region label reset is missing {token}")

        prealpha_hud = (ROOT / "game/scripts/ui/ironwright_prealpha_hud_3d.gd").read_text(encoding="utf-8")
        for token in ["CommandHelpPanel", "help_label.visible = false", "sanctuary_integrity < 0.78", "_apply_compact_layout"]:
            if token not in prealpha_hud:
                fail(f"Desktop HUD vertical-slice presentation is missing {token}")

        operations_hud = (ROOT / "game/scripts/ui/operations_command_hud_3d.gd").read_text(encoding="utf-8")
        for token in ["LONG-RANGE OPERATIONS", "FINAL PROTOCOLS", "persistent world", "apply_safe_layout"]:
            if token not in operations_hud:
                fail(f"Complete-game command presentation is missing {token}")

        quality_gate = (ROOT / "docs/PRESENTATION_QUALITY_GATE.md").read_text(encoding="utf-8").lower()
        for phrase in [
            "pre-alpha production prototype",
            "release-readiness rule",
            "world-label rule",
            "hud rule",
            "organic-behaviour rule",
            "heartforge vertical-slice rule",
        ]:
            if phrase not in quality_gate:
                fail(f"Presentation quality gate is missing {phrase!r}")

        intelligence_contract = (ROOT / "docs/VERTICAL_SLICE_INTELLIGENCE.md").read_text(encoding="utf-8").lower()
        for phrase in ["distributed salvage focus", "protect nest", "scout", "regional ecology", "heartforge vertical presentation slice"]:
            if phrase not in intelligence_contract:
                fail(f"Vertical-slice intelligence contract is missing {phrase!r}")

        print("Project Ironwright aesthetic and vertical-slice integration validation passed.")
        return 0
    except Exception as exc:
        print(f"AESTHETIC VALIDATION FAILED: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
