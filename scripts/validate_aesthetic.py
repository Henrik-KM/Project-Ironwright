#!/usr/bin/env python3
"""Validate the native aesthetic, vertical slice and pre-alpha presentation integration."""
import ast
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
    "game/scripts/presentation/authored_actor_animation_3d.gd",
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
    "game/assets/thornback/thornback.gltf",
    "game/data/thornback_asset_manifest.json",
    "game/assets/ashmantle/ashmantle.gltf",
    "game/data/ashmantle_asset_manifest.json",
    "game/assets/skitterling/source/build_skitterling_asset.py",
    "game/assets/skitterling/skitterling.gltf",
    "game/data/skitterling_asset_manifest.json",
    "game/assets/burrower/source/build_burrower_asset.py",
    "game/assets/burrower/burrower.gltf",
    "game/data/burrower_asset_manifest.json",
    "game/assets/sporecaster/source/build_sporecaster_asset.py",
    "game/assets/sporecaster/sporecaster.gltf",
    "game/data/sporecaster_asset_manifest.json",
    "game/assets/broodmass/source/build_broodmass_asset.py",
    "game/assets/broodmass/broodmass.gltf",
    "game/data/broodmass_asset_manifest.json",
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
    "game/assets/root_cistern/source/build_root_cistern_asset.py",
    "game/assets/root_cistern/root_cistern.gltf",
    "game/data/root_cistern_asset_manifest.json",
]

AUTHORED_ORGANIC_ASSETS = {
    "skitterling": {
        "asset_id": "skitterling.scavenger.v1",
        "root": "SkitterlingModel",
        "required": ["SkitterlingModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "SkitterlingCarapace0", "SkitterlingCarapaceCap0", "SkitterlingAntennaL", "SkitterlingAntennaJointL", "SkitterlingMandibleL", "SkitterlingMandiblePlateL", "SkitterlingSensoryFan0", "ProductionAssetMarker"],
    },
    "burrower": {
        "asset_id": "burrower.drill.v1",
        "root": "BurrowerModel",
        "required": ["BurrowerModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "BurrowerDrill", "BurrowerTip", "BurrowerDrillRing0", "BurrowerDrillFlute0", "BurrowerLampL", "BurrowerLampGuardL", "ProductionAssetMarker"],
    },
    "sporecaster": {
        "asset_id": "sporecaster.infestation.v1",
        "root": "SporecasterModel",
        "required": ["SporecasterModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "SporecasterGillFan0", "SporecasterGillRib0", "SporecasterSac0", "SporecasterSacCap0", "SporecasterStem0", "SporecasterOculusL", "ProductionAssetMarker"],
    },
    "broodmass": {
        "asset_id": "broodmass.nest.v1",
        "root": "BroodmassModel",
        "required": ["BroodmassModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "BroodmassLobeL", "BroodmassLobeRidgeL", "BroodmassMaw", "BroodmassMawRidge", "CrownSpine0", "CrownFastener0", "BroodmassFanL", "ProductionAssetMarker"],
    },
    "roofleaper": {
        "asset_id": "roofleaper.ambusher.v1",
        "root": "RoofleaperModel",
        "required": ["RoofleaperModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "RoofleaperCrown", "RoofleaperWingL", "RoofleaperFineVeinL", "RoofleaperFineVeinR", "RoofleaperWingFrameL", "RoofleaperWingFastenerR", "ProductionAssetMarker"],
    },
    "glassmoth": {
        "asset_id": "glassmoth.swarm.v1",
        "root": "GlassmothModel",
        "required": ["GlassmothModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "GlassmothThorax", "GlassmothWingL0", "GlassmothFineVeinL0", "GlassmothFineVeinR0", "GlassmothWingFrameL0", "GlassmothWingFastenerR1", "ProductionAssetMarker"],
    },
    "miremaw": {
        "asset_id": "miremaw.amphibious.v1",
        "root": "MiremawModel",
        "required": ["MiremawModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "MiremawHead", "MiremawGillFan", "MiremawGillRidgeL", "MiremawGillRidgeR", "MiremawJawPlateL", "MiremawGillSpineR", "ProductionAssetMarker"],
    },
    "carrionbell": {
        "asset_id": "carrionbell.signal.v1",
        "root": "CarrionbellModel",
        "required": ["CarrionbellModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "CarrionbellMantle", "CarrionbellResonator", "CarrionbellResonatorRing", "CarrionbellResonatorCore", "CarrionbellBellRib0", "ProductionAssetMarker"],
    },
    "rootweaver": {
        "asset_id": "rootweaver.route_controller.v1",
        "root": "RootweaverModel",
        "required": ["RootweaverModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "RootweaverCrown", "RootweaverSporeFan", "RootweaverKnuckleL", "RootweaverKnuckleR", "RootweaverCrownPlate0", "RootweaverRootSpineR", "ProductionAssetMarker"],
    },
    "thornback": {
        "asset_id": "thornback.territorial.v1",
        "root": "ThornbackModel",
        "required": ["ThornbackModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "ThornbackCrown", "ThornbackSpineL", "ThornbackSpineR", "ThornbackJawPlateL", "ThornbackEyeR", "ProductionAssetMarker"],
    },
    "ashmantle": {
        "asset_id": "ashmantle.route_predator.v1",
        "root": "AshmantleModel",
        "required": ["AshmantleModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "AshmantleMantle", "AshmantleHeatLouverL", "AshmantleHeatLouverR", "AshmantleSiphon", "AshmantleTendrilR", "ProductionAssetMarker"],
    },
}

# These are presentation assets used at tactical-camera and close inspection
# distances.  The floor is intentionally a total POSITION accessor count, not
# a triangle-count target, so it catches an accidental return to coarse
# procedural shells without prescribing a particular mesh decomposition.
ACTOR_GEOMETRY_FLOORS = {
    "mechromancer": 600,
    "bulwark": 1500,
    "relay": 1800,
    "warden": 1500,
    "scrapper": 1500,
    "pathfinder": 1600,
    "engineer": 1600,
    "veilstalker": 3000,
    "razorhound": 2800,
    "apex": 2600,
    "sporecaster": 3400,
    "broodmass": 3600,
    "burrower": 2500,
    "skitterling": 2100,
    "roofleaper": 4300,
    "glassmoth": 4300,
    "miremaw": 4300,
    "carrionbell": 4300,
    "rootweaver": 4300,
    "thornback": 4300,
    "ashmantle": 4300,
}

# These seven production builders predate the shared authored-family builder.
# Keep their source-level primitive floors explicit so a generated glTF can
# remain dense while a later rebuild quietly reintroduces coarse components.
LEGACY_ORGANIC_SOURCE_TESSELLATION_FLOORS = {
    "apex": ("game/assets/apex/source/build_apex_asset.py", 24, 32),
    "broodmass": ("game/assets/broodmass/source/build_broodmass_asset.py", 16, 24),
    "burrower": ("game/assets/burrower/source/build_burrower_asset.py", 16, 24),
    "razorhound": ("game/assets/razorhound/source/build_razorhound_asset.py", 16, 24),
    "skitterling": ("game/assets/skitterling/source/build_skitterling_asset.py", 16, 24),
    "sporecaster": ("game/assets/sporecaster/source/build_sporecaster_asset.py", 16, 24),
    "veilstalker": ("game/assets/veilstalker/source/build_veilstalker_asset.py", 16, 24),
}

MECHROMANCER_SOURCE_TESSELLATION_FLOORS = {
    "HERO_CURVE_VERTICES": 24,
    "HERO_SPHERE_SEGMENTS": 32,
    "HERO_SPHERE_RINGS": 16,
}

ACTOR_ANIMATION_CHANNEL_FLOORS = {
    "mechromancer": 2,
    "bulwark": 2,
    "warden": 2,
    "scrapper": 2,
    "pathfinder": 2,
    "engineer": 2,
    "veilstalker": 2,
    "razorhound": 2,
    "apex": 2,
    "sporecaster": 2,
    "broodmass": 2,
    "burrower": 2,
    "skitterling": 2,
    "roofleaper": 2,
    "glassmoth": 2,
    "miremaw": 2,
    "carrionbell": 2,
    "rootweaver": 2,
    "thornback": 2,
    "ashmantle": 2,
}

ORGANIC_ANIMATION_CLIPS = ["Idle", "Walk", "Attack", "Hit", "Feed", "Nest", "Retreat", "Death"]

FRIENDLY_ROBOT_FAMILIES = {
    "bulwark": ["Idle", "Walk", "Fire", "Hit", "Retreat", "Death"],
    "warden": ["Idle", "Walk", "Fire", "Hit", "Retreat", "Death"],
    "scrapper": ["Idle", "Walk", "Work", "Hit", "Retreat", "Death"],
    "engineer": ["Idle", "Walk", "Work", "Hit", "Retreat", "Death"],
    "pathfinder": ["Idle", "Walk", "Survey", "Hit", "Retreat", "Death"],
    "relay": ["Idle", "Walk", "Work", "Fire", "Hit", "Retreat", "Death"],
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
            "CathedralDoorPostL",
            "CathedralTowerSlit0",
            "CathedralRoseWindow",
            "CathedralRoseLatch0",
            "CathedralChoirCore",
            "CathedralChoirSignal",
            "CathedralChoirSignalRing",
            "CathedralChoirRibL",
            "CathedralBell",
            "CathedralBellClapper",
            "CathedralOrganicVeinKnuckle17",
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
    "root_cistern": {
        "asset_id": "root_cistern.landmark.v1",
        "root": "RootCisternModel",
        "required": [
            "RootCisternModel",
            "RootCisternBasin",
            "RootCisternBasinWater",
            "RootCisternBasinSpine0",
            "RootCisternBasinRootTendril0",
            "RootCisternCore",
            "RootCisternCoreMass",
            "RootCisternCoreHalo",
            "RootCisternCorePlate0",
            "RootCisternCoreClaw0",
            "RootCisternCoreVein0",
            "RootCisternLayer0",
            "RootCisternRib0",
            "RootCisternPylon0",
            "RootCisternPylonCollar0",
            "RootCisternPylonBrace0",
            "RootCisternSignal0",
            "RootCisternPulseCap0",
            "RootCisternCable0",
            "RootCisternCableClamp0",
            "ProductionAssetMarker",
        ],
    },
}


def fail(message: str) -> None:
    raise RuntimeError(message)


def _position_vertex_count(gltf: dict) -> int:
    """Return the total authored POSITION accessor count in a glTF asset."""
    accessors = gltf.get("accessors", [])
    total = 0
    for mesh in gltf.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            position_index = primitive.get("attributes", {}).get("POSITION")
            if isinstance(position_index, int) and 0 <= position_index < len(accessors):
                total += int(accessors[position_index].get("count", 0))
    return total


def validate_actor_geometry_density() -> None:
    for family, floor in ACTOR_GEOMETRY_FLOORS.items():
        gltf_path = ROOT / f"game/assets/{family}/{family}.gltf"
        gltf = json.loads(gltf_path.read_text(encoding="utf-8"))
        vertex_count = _position_vertex_count(gltf)
        if vertex_count < floor:
            fail(
                f"{family} authored actor geometry is below the high-definition density floor: "
                f"{vertex_count} POSITION vertices < {floor}."
            )


def validate_legacy_organic_source_tessellation() -> None:
    """Require dense source primitives in the pre-shared organic builders."""
    for family, (relative, ring_floor, side_floor) in LEGACY_ORGANIC_SOURCE_TESSELLATION_FLOORS.items():
        source_path = ROOT / relative
        tree = ast.parse(source_path.read_text(encoding="utf-8"), filename=str(source_path))
        mesh_assignment = next(
            (
                node
                for node in ast.walk(tree)
                if isinstance(node, ast.Assign)
                and any(isinstance(target, ast.Name) and target.id == "mesh_ids" for target in node.targets)
            ),
            None,
        )
        if mesh_assignment is None:
            fail(f"{family} source builder is missing its mesh_ids contract.")
        for call in ast.walk(mesh_assignment.value):
            if not isinstance(call, ast.Call) or not isinstance(call.func, ast.Name):
                continue
            if call.func.id == "add_uv_sphere":
                if len(call.args) <= 4 or not all(isinstance(call.args[index], ast.Constant) for index in (3, 4)):
                    fail(f"{family} source sphere tessellation must use literal ring and side counts.")
                rings = int(call.args[3].value)
                sides = int(call.args[4].value)
                if rings < ring_floor or sides < side_floor:
                    fail(
                        f"{family} source sphere tessellation is below the high-definition floor: "
                        f"{rings} rings/{sides} sides < {ring_floor}/{side_floor}."
                    )
            elif call.func.id == "add_cylinder":
                if len(call.args) <= 4 or not isinstance(call.args[4], ast.Constant):
                    fail(f"{family} source cylinder tessellation must use a literal side count.")
                sides = int(call.args[4].value)
                if sides < side_floor:
                    fail(
                        f"{family} source cylinder tessellation is below the high-definition floor: "
                        f"{sides} sides < {side_floor}."
                    )


def validate_mechromancer_source_tessellation() -> None:
    """Require dense helper floors in the canonical Blender source builder."""
    source_path = ROOT / "game/assets/mechromancer/source/build_mechromancer_blend.py"
    tree = ast.parse(source_path.read_text(encoding="utf-8"), filename=str(source_path))
    constants: dict[str, int] = {}
    for node in tree.body:
        if not isinstance(node, ast.Assign) or len(node.targets) != 1:
            continue
        target = node.targets[0]
        if isinstance(target, ast.Name) and isinstance(node.value, ast.Constant) and isinstance(node.value.value, int):
            constants[target.id] = int(node.value.value)
    for name, floor in MECHROMANCER_SOURCE_TESSELLATION_FLOORS.items():
        if constants.get(name, 0) < floor:
            fail(
                f"Mechromancer source helper {name} is below the high-definition floor: "
                f"{constants.get(name, 0)} < {floor}."
            )
def validate_actor_animation_breadth() -> None:
    """Require every imported production actor clip to carry multiple channels."""
    for family, floor in ACTOR_ANIMATION_CHANNEL_FLOORS.items():
        gltf_path = ROOT / f"game/assets/{family}/{family}.gltf"
        gltf = json.loads(gltf_path.read_text(encoding="utf-8"))
        animations = gltf.get("animations", [])
        names = [str(animation.get("name", "")) for animation in animations]
        if len(names) != len(set(names)):
            fail(f"{family} authored actor animation names must be unique.")
        for animation in animations:
            channel_count = len(animation.get("channels", []))
            if channel_count < floor:
                fail(
                    f"{family} authored {animation.get('name', '<unnamed>')} animation is too sparse: "
                    f"{channel_count} channels < {floor}."
                )


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
        for required in ORGANIC_ANIMATION_CLIPS:
            if required not in animation_names:
                fail(f"{family} glTF is missing required animation clip: {required}")


def validate_authored_robot_assets() -> None:
    for family, expected_clips in FRIENDLY_ROBOT_FAMILIES.items():
        manifest_path = ROOT / f"game/data/{family}_asset_manifest.json"
        gltf_path = ROOT / f"game/assets/{family}/{family}.gltf"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        gltf = json.loads(gltf_path.read_text(encoding="utf-8"))
        if not manifest.get("asset_id"):
            fail(f"{family} robot asset manifest must carry a stable asset ID.")
        root_name = next(
            (str(node.get("name")) for node in gltf.get("nodes", []) if str(node.get("name", "")).endswith("Model")),
            "",
        )
        root_extras = next(
            (node.get("extras", {}) for node in gltf.get("nodes", []) if node.get("name") == root_name),
            {},
        )
        gltf_asset_id = gltf.get("extras", {}).get("ironwright_asset_id") or root_extras.get("ironwright_asset_id")
        if gltf_asset_id != manifest["asset_id"]:
            fail(f"{family} robot glTF and manifest asset IDs must match.")
        animation_names = {str(animation.get("name")) for animation in gltf.get("animations", [])}
        for required in expected_clips:
            if required not in animation_names:
                fail(f"{family} robot glTF is missing required animation clip: {required}")


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
        validate_legacy_organic_source_tessellation()
        validate_mechromancer_source_tessellation()
        validate_actor_geometry_density()
        validate_actor_animation_breadth()
        validate_authored_robot_assets()
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
            for token in ["ReviewFloor", "ReviewBackdrop", "ReviewFrontFill", "ReviewRimLight", "PRESENTATION_REVIEW_EARLY_ORGANICS"]:
                if token not in release:
                    fail(f"Presentation review gallery is missing material-inspection behaviour: {token}")
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
