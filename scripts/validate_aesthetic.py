#!/usr/bin/env python3
"""Validate the native aesthetic, vertical slice and pre-alpha presentation integration."""
import ast
import base64
import binascii
from collections import Counter
from pathlib import Path
import hashlib
import json
import math
import struct
import sys
import zlib

ROOT = Path(__file__).resolve().parents[1]

MECHROMANCER_TEXTURE_ROLES = ("base_color", "normal", "orm", "emissive")
MECHROMANCER_ASSET_ID = "mechromancer.player.v1"
MECHROMANCER_ROOT = "MechromancerModel"
MECHROMANCER_REQUIRED_NODES = (
    MECHROMANCER_ROOT,
    "FaceAnchor",
    "Hood",
    "HoodLowerSeam",
    "VisorBrow",
    "VisorMountLeft",
    "VisorMountRight",
    "ChestShell",
    "ChestArmorPlate",
    "FieldPack",
    "FieldCommsYoke",
    "FieldCommsAntenna",
    "FieldCommsBeacon",
    "FieldCommsCable",
    "ShoulderLamp",
    "LeftArm",
    "RightArm",
    "LeftLeg",
    "RightLeg",
    "CoatTailLeft",
    "CoatTailRight",
    "FieldTool",
    "WeakPistol",
    "PistolMuzzle",
    "ProductionAssetMarker",
)
MECHROMANCER_ANIMATION_CLIPS = ("Idle", "Walk", "Fire", "Work", "Upgrade", "Hit")
MECHROMANCER_ANIMATION_REQUIRED_TARGETS = {
    "Idle": {MECHROMANCER_ROOT, "CoatTailLeft", "CoatTailRight", "FieldPack"},
    "Walk": {MECHROMANCER_ROOT, "CoatTailLeft", "CoatTailRight", "FieldPack", "LeftLeg", "RightLeg"},
    "Fire": {"WeakPistol", "RightArm"},
    "Work": {"CoatTailLeft", "CoatTailRight", "LeftArm", "RightArm"},
    "Upgrade": {"FieldTool", "LeftArm", "RightArm", "ShoulderLamp"},
    "Hit": {MECHROMANCER_ROOT, "CoatTailLeft", "CoatTailRight", "FieldPack"},
}
MECHROMANCER_MATERIAL_NAMES = (
    "Worn charcoal coat",
    "Faded coat folds",
    "Heavy charcoal coat tails",
    "Oxidized field metal",
    "Weathered leather",
    "Human skin",
    "Hood interior",
    "Weak sidearm gunmetal",
    "Smoked cyan visor",
    "Cognition cyan lens",
    "Warm utility lens",
)
MECHROMANCER_EMISSIVE_MATERIALS = (
    "Smoked cyan visor",
    "Cognition cyan lens",
    "Warm utility lens",
)
MECHROMANCER_BOUNDS_MIN = (-0.795, 0.05, -0.63)
MECHROMANCER_BOUNDS_MAX = (0.815, 2.41, 0.785)
MECHROMANCER_BOUNDS_MIN_ENVELOPE = ((-1.1, -0.35), (-0.15, 0.25), (-1.1, -0.15))
MECHROMANCER_BOUNDS_MAX_ENVELOPE = ((0.35, 1.1), (1.8, 2.75), (0.15, 1.2))
MECHROMANCER_BOUNDS_SIZE_ENVELOPE = ((0.9, 2.1), (1.8, 2.85), (0.7, 2.1))
MECHROMANCER_FROZEN_SHA256 = {
    "game/assets/mechromancer/source/build_mechromancer_asset.py": "f5251ef51bcb6f5627b92f10f4eab3bca586d3b89862618afef715dbffc82baa",
    "game/data/mechromancer_asset_manifest.json": "da53e0895410a0e4426669d0c287fd990ccf0fbea5ae29663e3f2f0a55a23d95",
    "game/assets/mechromancer/mechromancer.gltf": "1ccfc4fd2187297d5c2ced5e5ab2d0c9e5ad9a7d5d6c71ffae5b37429ba27ae2",
    "game/assets/mechromancer/mechromancer.bin": "3576ce1ca76e1bd7ca9716326a803d4c26295b8199926a02c33a14f7922d0dca",
    "game/assets/mechromancer/mechromancer_base_color.png": "ddf3ecfacdd7b7d3ca922def69929c0aff40d7b80d9597b9876fe2151783a7b9",
    "game/assets/mechromancer/mechromancer_normal.png": "377a67cd36bdbcba735a74eb337f28dfd13bab6fb0792e2a0cab01e79281b49b",
    "game/assets/mechromancer/mechromancer_orm.png": "efacbcf45da2cf6706575a12c880f2301cdda3dadb51c1223624751e7fa10eb5",
    "game/assets/mechromancer/mechromancer_emissive.png": "e45c20b47b451ab8aee1cf8b66139a70c5fffa012b892a6ca734924a4280c4fc",
}

BULWARK_TEXTURE_ROLES = ("base_color", "normal", "orm", "emissive")
BULWARK_WALK_TARGETS = (
    "LegFrontLeft",
    "FootFrontLeft",
    "LegRearLeft",
    "FootRearLeft",
    "LegFrontRight",
    "FootFrontRight",
    "LegRearRight",
    "FootRearRight",
)
BULWARK_FIRE_TARGETS = ("BulwarkGunLeft", "BulwarkGunRight")
BULWARK_STATIC_DETAILS = (
    "BulwarkRadiatorLouver",
    "BulwarkFrontSensorVisor",
    "BulwarkServiceFace",
    "BulwarkServiceLatchLeft",
    "BulwarkServiceLatchRight",
    "BulwarkShoulderRailLeft",
    "BulwarkShoulderRailRight",
    "BulwarkFootPlateLeft",
    "BulwarkFootPlateRight",
    "BulwarkActuatorRingLeft",
    "BulwarkActuatorRingRight",
    "BulwarkActuatorCapLeft",
    "BulwarkActuatorCapRight",
    "BulwarkSideHeatPanelLeft",
    "BulwarkSideHeatPanelRight",
    "BulwarkServiceWindowFrame",
)

HEARTFORGE_TEXTURE_ROLES = ("base_color", "normal", "orm", "emissive")
HEARTFORGE_STABLE_NODES = (
    "HeartforgeModel",
    "Foundation",
    "CoreHousing",
    "FurnaceCore",
    "CoreCladdingDetail",
    "CoreServiceLouverCore",
    "CoreInspectionPort",
    "HeartforgeFocalDetail",
    "HeartforgeUpperCollar",
    "HeartforgeFocalControlFace",
    "ForgeBench",
    "HeartforgeCoolantPipeLeft",
    "HeartforgeThermalShroud00",
    "ForgeBenchBraceLeft",
    "HeartforgeFoundationBolt00",
    "ProductionAssetMarker",
)
HEARTFORGE_AUTHORED_DETAIL_ROOT = "VerticalSliceForgeArt"
HEARTFORGE_AUTHORED_DETAIL_NODES = (
    "ForgeCoolantStackLeft",
    "ForgeCoolantStackRight",
    "ForgePressurePipeLeft",
    "ForgePressurePipeRight",
    "ForgePumpLeft",
    "ForgePumpRight",
    "ForgeTopClamp00",
    "ForgeTopClamp01",
    "ForgeTopClamp02",
    "ForgeTopClamp03",
    "ForgeTopClamp04",
    "ForgeControlCabinet",
    "ForgeDiagnosticPanel",
)
HEARTFORGE_SERVICE_HARDWARE = {
    "ForgeCoolantStackLeft": "coolant_stack",
    "ForgeCoolantStackRight": "coolant_stack",
    "ForgePressurePipeLeft": "pressure_line",
    "ForgePressurePipeRight": "pressure_line",
    "ForgePumpLeft": "coolant_pump",
    "ForgePumpRight": "coolant_pump",
    "ForgeTopClamp00": "upper_shell_clamp",
    "ForgeTopClamp01": "upper_shell_clamp",
    "ForgeTopClamp02": "upper_shell_clamp",
    "ForgeTopClamp03": "upper_shell_clamp",
    "ForgeTopClamp04": "upper_shell_clamp",
    "ForgeControlCabinet": "control_cabinet",
    "ForgeDiagnosticPanel": "diagnostic_surface",
}
HEARTFORGE_SOCKET_NODES = {
    "Foundation": "heartforge_anchor",
    "CoreHousing": "primary_reactor_shell",
    "CoreCladdingDetail": "manufactured_cladding",
    "HeartforgeFocalControlFace": "player_facing_control",
    "HeartforgeFocalSignalLens00": "service_signal",
    "HeartforgeFocalSignalLens01": "service_signal",
    "HeartforgeFocalSignalLens02": "service_signal",
    "HeartforgeFocalDetail": "reactor_control_layer",
    "ForgeBench": "manual_fabrication_surface",
}
HEARTFORGE_MANIFEST_SOCKET_TYPES = {
    "heartforge_anchor",
    "primary_reactor_shell",
    "player_facing_control",
    "manual_fabrication_surface",
    "service_hardware",
}
HEARTFORGE_CRITICAL_TRANSLATIONS = {
    "Foundation": (0.0, 0.35, 0.0),
    "CoreHousing": (0.0, 2.0, 0.0),
    "HeartforgeFocalControlFace": (0.0, 2.7, 1.92),
    "HeartforgeFocalSignalLens00": (-0.34, 2.73, 2.01),
    "HeartforgeFocalSignalLens01": (0.0, 2.73, 2.01),
    "HeartforgeFocalSignalLens02": (0.34, 2.73, 2.01),
    "ForgeBench": (0.0, 0.48, 3.25),
}
HEARTFORGE_MATERIAL_NAMES = {
    "Heartforge foundation",
    "Heartforge iron shell",
    "Heartforge cladding",
    "Heartforge weathered copper",
    "Heartforge thermal core",
    "Heartforge service cyan",
}
HEARTFORGE_EMISSIVE_MATERIALS = {
    "Heartforge thermal core",
    "Heartforge service cyan",
}
HEARTFORGE_BOUNDS_MIN = (-2.55, 0.0, -2.56)
HEARTFORGE_BOUNDS_MAX = (2.55, 4.07, 4.15)

HEARTFORGE_THRESHOLD_TEXTURE_ROLES = ("base_color", "normal", "orm", "emissive")
HEARTFORGE_THRESHOLD_ROOT = "AuthoredHeartforgeThreshold"
HEARTFORGE_THRESHOLD_ASSET_ID = "heartforge.threshold.v1"
HEARTFORGE_THRESHOLD_STABLE_NODES = (
    HEARTFORGE_THRESHOLD_ROOT,
    "ThresholdStructure",
    "LeftPillar",
    "RightPillar",
    "ThresholdPillarL",
    "ThresholdPillarR",
    "LeftThresholdFoot",
    "RightThresholdFoot",
    "ThresholdFootL",
    "ThresholdFootR",
    "ThresholdLintel",
    "ThresholdCrown",
    "RouteThresholdAmberBand",
    "ThresholdServiceLayer",
    "ThresholdServicePanel",
    "LeftServicePanel",
    "RightServicePanel",
    "ThresholdSignalLayer",
    "LeftRouteLamp",
    "RightRouteLamp",
    "ThresholdLamp00",
    "ThresholdLamp01",
    "ThresholdLamp02",
    "LeftRouteSensor",
    "RightRouteSensor",
    "ThresholdRouteMarker",
    "ThresholdOrganicMachineLayer",
    "ProductionAssetMarker",
)
HEARTFORGE_THRESHOLD_AUTHORED_DETAIL_NODES = (
    "LeftPillarOuterShield",
    "RightPillarOuterShield",
    "LeftPillarCopperSpine",
    "RightPillarCopperSpine",
    "LeftServicePanel",
    "RightServicePanel",
    "LeftRouteLamp",
    "RightRouteLamp",
    "ThresholdCenterLamp",
    "LeftRouteSensor",
    "RightRouteSensor",
    "ThresholdCrown",
    "ThresholdCrownKeystone",
    "RouteThresholdAmberBand",
    "ThresholdRouteMarker",
    "LeftThresholdRootAssembly",
    "RightThresholdRootAssembly",
    "LeftThresholdConduit",
    "RightThresholdConduit",
)
HEARTFORGE_THRESHOLD_REQUIRED_NODES = tuple(
    dict.fromkeys((*HEARTFORGE_THRESHOLD_STABLE_NODES, *HEARTFORGE_THRESHOLD_AUTHORED_DETAIL_NODES))
)
HEARTFORGE_THRESHOLD_MATERIAL_NAMES = {
    "Threshold foundation iron",
    "Threshold forged shell",
    "Threshold warm copper",
    "Threshold weathered plate",
    "Threshold route amber",
    "Threshold service cyan",
}
HEARTFORGE_THRESHOLD_EMISSIVE_MATERIALS = {
    "Threshold route amber",
    "Threshold service cyan",
}
HEARTFORGE_THRESHOLD_CLEAR_WIDTH = 7.38
HEARTFORGE_THRESHOLD_CLEAR_HEIGHT = 3.03
HEARTFORGE_THRESHOLD_INNER_EDGES_X = (-3.69, 3.69)

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
    "game/scripts/systems/enemy_tier_progression_bootstrap_3d.gd",
    "game/scripts/systems/enemy_tier_progression_director_3d.gd",
    "game/scripts/world/enemy_tier_nest_3d.gd",
    "game/scripts/enemies/enemy_tier_brain_3d.gd",
    "game/scripts/ui/enemy_tier_intel_hud_3d.gd",
    "game/tests/aesthetic_test_runner.gd",
    "game/tests/organic_action_review_test_runner.gd",
    "game/tests/presentation_and_salvage_escort_test_runner.gd",
    "game/tests/intelligence_and_vertical_slice_test_runner.gd",
    "docs/PRESENTATION_QUALITY_GATE.md",
    "docs/VERTICAL_SLICE_INTELLIGENCE.md",
    "game/assets/mechromancer/mechromancer.gltf",
    "game/assets/mechromancer/mechromancer.bin",
    "game/assets/mechromancer/source/mechromancer.blend",
    "game/assets/mechromancer/mechromancer_portrait.png",
    "game/assets/mechromancer/mechromancer_base_color.png",
    "game/assets/mechromancer/mechromancer_normal.png",
    "game/assets/mechromancer/mechromancer_orm.png",
    "game/assets/mechromancer/mechromancer_emissive.png",
    "game/assets/mechromancer/source/build_mechromancer_blend.py",
    "game/assets/mechromancer/source/build_mechromancer_asset.py",
    "game/assets/heartforge_threshold/source/build_heartforge_threshold_asset.py",
    "game/assets/heartforge_threshold/heartforge_threshold.gltf",
    "game/assets/heartforge_threshold/heartforge_threshold_base_color.png",
    "game/assets/heartforge_threshold/heartforge_threshold_normal.png",
    "game/assets/heartforge_threshold/heartforge_threshold_orm.png",
    "game/assets/heartforge_threshold/heartforge_threshold_emissive.png",
    "game/data/heartforge_threshold_asset_manifest.json",
    "game/assets/salvage/source/build_salvage_asset.py",
    "game/assets/salvage/salvage.gltf",
    "game/data/salvage_asset_manifest.json",
    "game/assets/vehicle_wreck/source/build_vehicle_wreck_asset.py",
    "game/assets/vehicle_wreck/vehicle_wreck.gltf",
    "game/data/vehicle_wreck_asset_manifest.json",
    "game/data/mechromancer_asset_manifest.json",
    "game/assets/organic_families/source/build_authored_organic_assets.py",
    "game/assets/organic_families/source/build_organic_surface_library.py",
    "game/assets/organic_families/textures/organic_shell_base_color.png",
    "game/assets/organic_families/textures/organic_shell_normal.png",
    "game/assets/organic_families/textures/organic_shell_orm.png",
    "game/assets/organic_families/textures/organic_tissue_base_color.png",
    "game/assets/organic_families/textures/organic_tissue_normal.png",
    "game/assets/organic_families/textures/organic_tissue_orm.png",
    "game/assets/organic_families/textures/organic_emissive.png",
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
        "required": ["SkitterlingModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "SkitterlingCarapace0", "SkitterlingCarapaceCap0", "SkitterlingHeadShield", "SkitterlingHeadRidge", "SkitterlingAntennaL", "SkitterlingAntennaJointL", "SkitterlingMandibleL", "SkitterlingMandiblePlateL", "SkitterlingSensoryFan0", "SkitterlingSensoryFan3", "SkitterlingSensoryRib0", "SkitterlingSensoryRib3", "ProductionAssetMarker"],
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
        "required": ["BroodmassModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "BroodmassLobeL", "BroodmassLobeRidgeL", "BroodmassMaw", "BroodmassMawLower", "BroodmassMawRidge", "CrownSpine0", "CrownFastener0", "BroodmassCrownCap", "BroodmassCrownCapPlate", "BroodmassFanL", "ProductionAssetMarker"],
    },
    "razorhound": {
        "asset_id": "razorhound.predator.v1",
        "root": "RazorhoundModel",
        "required": ["RazorhoundModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "ProductionAssetMarker"],
    },
    "veilstalker": {
        "asset_id": "veilstalker.predator.v1",
        "root": "VeilstalkerModel",
        "required": ["VeilstalkerModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "ProductionAssetMarker"],
    },
    "apex": {
        "asset_id": "apex.cistern.v1",
        "root": "ApexModel",
        "required": ["ApexModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "ProductionAssetMarker"],
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
        "required": ["MiremawModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "MiremawHead", "MiremawJawLower", "MiremawGillFan", "MiremawGillRidgeL", "MiremawGillRidgeR", "MiremawJawPlateL", "MiremawGillSpineR", "ProductionAssetMarker"],
    },
    "carrionbell": {
        "asset_id": "carrionbell.signal.v1",
        "root": "CarrionbellModel",
        "required": ["CarrionbellModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "CarrionbellMantle", "CarrionbellResonator", "CarrionbellResonatorRing", "CarrionbellResonatorCore", "CarrionbellResonatorRootCollar", "CarrionbellBellRib0", "ProductionAssetMarker"],
    },
    "rootweaver": {
        "asset_id": "rootweaver.route_controller.v1",
        "root": "RootweaverModel",
        "required": ["RootweaverModel", "Torso", "TorsoCore", "OrganicDorsalPlate", "RootweaverCrown", "RootweaverSporeFan", "RootweaverKnuckleL", "RootweaverKnuckleR", "RootweaverCrownPlate0", "RootweaverJawPlateL", "RootweaverJawPlateR", "RootweaverRootSpineR", "ProductionAssetMarker"],
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

# The shared late-organic builder is inspected at close tactical distance. Keep
# its curved shells and small anatomy hardware on the same smooth floor as the
# separately authored Apex and Broodmass specimens.
SHARED_ORGANIC_SOURCE_TESSELLATION = {
    "game/assets/organic_families/source/build_authored_organic_assets.py": (24, 36, 24),
}

SHARED_AUTHORED_ORGANIC_FAMILIES = {
    "roofleaper",
    "glassmoth",
    "miremaw",
    "carrionbell",
    "rootweaver",
    "thornback",
    "ashmantle",
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

EARLY_ORGANIC_MATERIAL_FAMILIES = (
    "skitterling",
    "razorhound",
    "burrower",
    "sporecaster",
    "veilstalker",
)

MECHROMANCER_SOURCE_TESSELLATION_FLOORS = {
    "ROUNDED_BOX_SUBDIVISIONS": 4,
    "ELLIPSOID_RINGS": 18,
    "ELLIPSOID_SIDES": 36,
    "CYLINDER_SIDES": 32,
    "PIPE_SIDES": 24,
    "TORUS_MAJOR_SEGMENTS": 36,
    "TORUS_MINOR_SEGMENTS": 12,
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
ORGANIC_TEXTURE_ROLES = (
    "shell_base_color",
    "shell_normal",
    "shell_orm",
    "tissue_base_color",
    "tissue_normal",
    "tissue_orm",
    "emissive",
)
ORGANIC_TEXTURE_URIS = {
    role: f"res://assets/organic_families/textures/organic_{role}.png"
    for role in ORGANIC_TEXTURE_ROLES
}
ORGANIC_IMAGE_URIS = [f"../organic_families/textures/organic_{role}.png" for role in ORGANIC_TEXTURE_ROLES]
ORGANIC_FROZEN_BOUNDS = {
    "apex": ([-1.6186, -0.2301, -2.5450], [1.6186, 2.8050, 1.5936]),
    "ashmantle": ([-1.4529, 0.3396, -1.9171], [1.4303, 1.8909, 1.2210]),
    "broodmass": ([-1.6143, -0.2500, -2.3146], [1.6143, 2.6049, 1.5496]),
    "burrower": ([-1.1593, -0.1890, -2.5000], [1.1593, 1.9186, 1.5760]),
    "carrionbell": ([-1.1414, 0.1079, -1.1773], [1.2162, 2.8424, 1.1366]),
    "glassmoth": ([-2.0542, 0.2752, -1.3076], [1.9042, 2.0387, 1.2168]),
    "miremaw": ([-1.6666, -0.2003, -2.1140], [1.6702, 1.8909, 1.1692]),
    "razorhound": ([-1.0366, -0.1655, -1.7050], [1.0366, 1.6249, 1.4331]),
    "roofleaper": ([-1.9451, -0.2371, -1.8337], [1.7578, 1.8909, 1.1999]),
    "rootweaver": ([-1.3601, 0.2690, -1.1864], [1.3601, 2.4562, 1.2076]),
    "skitterling": ([-0.7569, -0.1313, -1.2522], [0.7569, 1.0646, 0.8480]),
    "sporecaster": ([-1.5723, -0.1895, -1.5674], [1.2641, 2.4876, 0.9636]),
    "thornback": ([-1.0464, 0.3396, -1.5621], [1.0464, 2.2985, 1.2354]),
    "veilstalker": ([-1.3812, -0.1931, -1.8589], [1.3812, 2.0806, 1.6700]),
}

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
            "RiverworksPumpVoluteRing",
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
            "CathedralRoseRim",
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
            "ObservatoryDishRimRing",
            "ObservatoryDishPedestal",
            "ObservatoryDishSupportRing",
            "ObservatoryDishPivotHousing",
            "ObservatoryDishPivotBand",
            "ObservatoryDishRib0",
            "ObservatoryDishActuator",
            "ObservatoryFeedSignal",
            "ObservatoryFeedHorn",
            "ObservatoryFeedHornRim",
            "ObservatoryFeedHornLens",
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
            "TramWreckCarriage",
            "TramWreckCarriageRoof",
            "TramCarriageADoor",
            "TramCarriageAFrontWindow0",
            "TramCarriageAFrontDoor",
            "TramCarriageAFrontHeadlampHousing",
            "TramCarriageABogiePlate0",
            "TramCarriageAPantograph",
            "TramCarriageASidePanelFront0",
            "TramYardDeck",
            "TramMaintenancePit",
            "TramPitRung0",
            "TramSignalMast",
            "TramSignalHousing",
            "TramSignalLamp",
            "TramCableClamp0",
            "TramOrganicSeep0",
            "TramOrganicSeepTendril0_0",
            "TramYardCrate0",
            "TramYardCrateBand0",
            "TramCableReel0",
            "TramCableReelRim0",
            "TramYardDebris0",
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
            "GlasshouseBedTrellis0",
            "GlasshouseTrellisRail0",
            "GlasshouseTrellisGrowth0_0",
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
            "TenementFrontWindowRevealL0_0",
            "TenementFrontWindowJambL0_0",
            "TenementFrontWindowMullionL0_0",
            "TenementFrontWindowLintelL0_0",
            "TenementFrontWindowSillL0_0",
            "TenementBlockLEdgeL",
            "TenementFacadeBandL0",
            "TenementFacadePillarL",
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
            "WestGridHallSkinRib0",
            "WestGridHallSkinRailTop",
            "WestGridHallSkinPlate0",
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
            "RootCisternCoreCollar",
            "RootCisternCoreMass",
            "RootCisternCoreMantle0",
            "RootCisternCoreHalo",
            "RootCisternCorePlate0",
            "RootCisternCoreClaw0",
            "RootCisternCoreVein0",
            "RootCisternCoreRoot0",
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


def validate_shared_organic_source_tessellation() -> None:
    """Require the shared organic-family builder to retain its close-camera floor."""
    for relative, (ring_floor, side_floor, cylinder_floor) in SHARED_ORGANIC_SOURCE_TESSELLATION.items():
        source_path = ROOT / relative
        source_text = source_path.read_text(encoding="utf-8")
        membrane_uses_rounded_kit = (
            '"Membrane": mesh("Membrane", add_convex_sheet' in source_text
            or '"Membrane": mesh("Membrane", add_ellipsoid' in source_text
            or '"Membrane": mesh("Membrane", add_organic_lobe' in source_text
        )
        if "def add_convex_sheet(" not in source_text or '"Plate": mesh("Plate", add_convex_sheet' not in source_text or not membrane_uses_rounded_kit or "def add_torus(" not in source_text or '"ResonatorRing": mesh("ResonatorRing", add_torus' not in source_text:
            fail("shared organic source builder must use a rounded close-camera kit for plates and membranes.")
        tree = ast.parse(source_text, filename=str(source_path))
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
            fail("shared organic source builder is missing its mesh_ids contract.")
        for call in ast.walk(mesh_assignment.value):
            if not isinstance(call, ast.Call) or not isinstance(call.func, ast.Name):
                continue
            if call.func.id == "add_uv_sphere":
                if len(call.args) <= 4 or not all(isinstance(call.args[index], ast.Constant) for index in (3, 4)):
                    fail("shared organic source sphere tessellation must use literal ring and side counts.")
                rings = int(call.args[3].value)
                sides = int(call.args[4].value)
                if rings < ring_floor or sides < side_floor:
                    fail(
                        "shared organic source sphere tessellation is below the close-camera floor: "
                        f"{rings} rings/{sides} sides < {ring_floor}/{side_floor}."
                    )
            elif call.func.id == "add_cylinder":
                if len(call.args) <= 4 or not isinstance(call.args[4], ast.Constant):
                    fail("shared organic source cylinder tessellation must use a literal side count.")
                sides = int(call.args[4].value)
                if sides < cylinder_floor:
                    fail(
                        "shared organic source cylinder tessellation is below the close-camera floor: "
                        f"{sides} sides < {cylinder_floor}."
                    )
def validate_mechromancer_source_tessellation() -> None:
    """Require dense helper floors in the canonical deterministic source builder."""
    source_path = ROOT / "game/assets/mechromancer/source/build_mechromancer_asset.py"
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
    buffer_path = ROOT / "game/assets/mechromancer/mechromancer.bin"
    source_path = ROOT / "game/assets/mechromancer/source/build_mechromancer_asset.py"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    gltf = json.loads(gltf_path.read_text(encoding="utf-8"))

    for relative, expected_hash in MECHROMANCER_FROZEN_SHA256.items():
        artifact_path = ROOT / relative
        actual_hash = hashlib.sha256(artifact_path.read_bytes()).hexdigest()
        if actual_hash != expected_hash:
            fail(
                "Mechromancer deterministic package artifact drifted from its frozen source build: "
                f"{relative} expected {expected_hash}, got {actual_hash}."
            )

    if manifest.get("asset_id") != MECHROMANCER_ASSET_ID:
        fail("Mechromancer asset manifest has an unexpected stable asset ID.")
    if manifest.get("asset_quality") != "authored_high_definition":
        fail("Mechromancer manifest must retain its authored high-definition quality contract.")
    if manifest.get("runtime_model") != "res://assets/mechromancer/mechromancer.gltf":
        fail("Mechromancer asset manifest points at an unexpected runtime model.")
    if manifest.get("runtime_buffer") != "res://assets/mechromancer/mechromancer.bin":
        fail("Mechromancer asset manifest must document the glTF buffer.")
    canonical_builder_uri = "res://assets/mechromancer/source/build_mechromancer_asset.py"
    if manifest.get("source") != canonical_builder_uri or manifest.get("source_builder") != canonical_builder_uri:
        fail("Mechromancer manifest must point to its canonical deterministic runtime/source builder.")
    if manifest.get("source_reference") != "res://assets/mechromancer/source/mechromancer.blend":
        fail("Mechromancer manifest must preserve the editable Blender visual reference without treating it as runtime authority.")
    if manifest.get("source_type") != "original_project_ironwright_deterministic_mesh_builder":
        fail("Mechromancer manifest must preserve its original deterministic mesh-builder provenance.")
    if manifest.get("third_party_assets") != []:
        fail("Mechromancer must remain an original authored package without undeclared third-party runtime art.")
    if manifest.get("presentation_only") is not True:
        fail("Mechromancer glTF package must remain explicitly presentation-only.")
    if manifest.get("collision") is not False or manifest.get("gameplay_state") != "none":
        fail("Mechromancer authored presentation package must not embed collision or gameplay state.")
    if manifest.get("deterministic_build") is not True:
        fail("Mechromancer manifest must declare its deterministic authored build contract.")
    if manifest.get("texture_resolution") != 1024:
        fail("Mechromancer manifest must preserve the authored 1024 texture resolution.")
    if manifest.get("material_workflow") != "metallic_roughness_pbr":
        fail("Mechromancer manifest must preserve the metallic-roughness PBR workflow.")
    if manifest.get("portrait") != "res://assets/mechromancer/mechromancer_portrait.png":
        fail("Mechromancer manifest must point exactly to the authored portrait.")
    portrait_path = ROOT / "game/assets/mechromancer/mechromancer_portrait.png"
    portrait_width, portrait_height, _, _ = _decode_png_rows(portrait_path, "Mechromancer portrait")
    if (portrait_width, portrait_height) != (512, 512):
        fail(f"Mechromancer authored portrait must remain exactly 512x512, got {portrait_width}x{portrait_height}.")
    _validate_nonflat_base_color_texture(portrait_path, "Mechromancer portrait")
    _require_close_vector(
        (manifest.get("world_scale_m"), manifest.get("source_visual_scale"), manifest.get("runtime_visual_scale")),
        (2.36, 1.0, 1.28),
        1.0e-6,
        "Mechromancer authored and runtime scale contract",
    )
    _require_close_vector(
        (manifest.get("collision_capsule_radius_m"), manifest.get("collision_capsule_height_m")),
        (0.42, 1.75),
        1.0e-6,
        "Mechromancer unchanged runtime collision reference",
    )

    declared_required_nodes = manifest.get("required_nodes")
    if (
        not isinstance(declared_required_nodes, list)
        or tuple(map(str, declared_required_nodes)) != MECHROMANCER_REQUIRED_NODES
    ):
        fail("Mechromancer manifest must preserve the exact ordered stable-node contract.")
    if tuple(map(str, manifest.get("stable_nodes", []))) != MECHROMANCER_REQUIRED_NODES:
        fail("Mechromancer manifest stable_nodes must mirror the exact ordered runtime-node contract.")
    if tuple(map(str, manifest.get("animation_clips", []))) != MECHROMANCER_ANIMATION_CLIPS:
        fail("Mechromancer manifest must preserve the exact ordered six-clip animation contract.")
    declared_material_names = manifest.get("material_names")
    if not isinstance(declared_material_names, list) or tuple(map(str, declared_material_names)) != MECHROMANCER_MATERIAL_NAMES:
        fail("Mechromancer manifest must preserve the exact ordered authored material-family contract.")
    declared_emissive_materials = manifest.get("emissive_materials")
    if not isinstance(declared_emissive_materials, list) or tuple(map(str, declared_emissive_materials)) != MECHROMANCER_EMISSIVE_MATERIALS:
        fail("Mechromancer manifest must preserve the exact ordered emissive material subset.")

    declared_textures = manifest.get("textures")
    if not isinstance(declared_textures, dict) or tuple(declared_textures) != MECHROMANCER_TEXTURE_ROLES:
        fail("Mechromancer manifest must declare exactly ordered base_color, normal, orm and emissive textures.")
    texture_paths: dict[str, Path] = {}
    package_path = (ROOT / "game/assets/mechromancer").resolve()
    for role in MECHROMANCER_TEXTURE_ROLES:
        expected_uri = f"res://assets/mechromancer/mechromancer_{role}.png"
        raw_path = declared_textures.get(role)
        if raw_path != expected_uri:
            fail(f"Mechromancer {role} texture must use the exact authored package URI {expected_uri}.")
        texture_path = _resolve_authored_texture_path(str(raw_path), "mechromancer")
        try:
            texture_path.relative_to(package_path)
        except ValueError:
            fail(f"Mechromancer {role} texture must live inside the authored Mechromancer package.")
        if not texture_path.is_file() or texture_path.stat().st_size < 1024:
            fail(f"Mechromancer {role} texture is missing or unexpectedly small: {raw_path}")
        width, height, _, _ = _decode_png_rows(texture_path, "Mechromancer")
        if (width, height) != (1024, 1024):
            fail(f"Mechromancer {role} texture must be exactly 1024x1024, got {width}x{height}.")
        texture_paths[role] = texture_path
    if len(set(texture_paths.values())) != len(MECHROMANCER_TEXTURE_ROLES):
        fail("Mechromancer PBR roles must resolve to four distinct PNG files.")
    _validate_nonflat_base_color_texture(texture_paths["base_color"], "Mechromancer")
    _validate_mechromancer_base_color_signal(texture_paths["base_color"])
    _validate_neutral_blue_normal_texture(texture_paths["normal"], "Mechromancer")
    _validate_mechromancer_normal_signal(texture_paths["normal"])
    _validate_packed_orm_texture(texture_paths["orm"], "Mechromancer")
    _validate_emissive_mask_texture(texture_paths["emissive"], "Mechromancer")
    _validate_mechromancer_builder_determinism(source_path)

    buffers = gltf.get("buffers", [])
    if len(buffers) != 1 or buffers[0].get("uri") != "mechromancer.bin":
        fail("Mechromancer glTF must use exactly one inspectable external mechromancer.bin buffer.")
    if not buffer_path.is_file() or int(buffers[0].get("byteLength", -1)) != buffer_path.stat().st_size:
        fail("Mechromancer glTF buffer byteLength must exactly match mechromancer.bin.")
    buffer_data = buffer_path.read_bytes()

    nodes = gltf.get("nodes", [])
    node_names = [str(node.get("name", "")) for node in nodes]
    duplicate_names = sorted(name for name, count in Counter(node_names).items() if not name or count != 1)
    if duplicate_names:
        fail(f"Mechromancer glTF node names must be non-empty and globally unique: {duplicate_names}")
    if not set(MECHROMANCER_REQUIRED_NODES).issubset(set(node_names)):
        fail(f"Mechromancer glTF is missing required stable nodes: {sorted(set(MECHROMANCER_REQUIRED_NODES) - set(node_names))}")
    root_indices = [index for index, name in enumerate(node_names) if name == MECHROMANCER_ROOT]
    if len(root_indices) != 1:
        fail("Mechromancer glTF must contain exactly one MechromancerModel package root.")
    default_scene_index = gltf.get("scene", 0)
    scenes = gltf.get("scenes", [])
    if not isinstance(default_scene_index, int) or not (0 <= default_scene_index < len(scenes)):
        fail("Mechromancer glTF must name a valid default scene.")
    if scenes[default_scene_index].get("nodes") != root_indices:
        fail("Mechromancer default scene must expose only its authored package root.")
    reachable: set[int] = set()
    parents: dict[int, int] = {}

    def visit_reachable(node_index: int) -> None:
        if node_index in reachable:
            fail("Mechromancer scene graph must not contain cycles or shared-node aliases.")
        reachable.add(node_index)
        for child_index in nodes[node_index].get("children", []):
            if not isinstance(child_index, int) or not (0 <= child_index < len(nodes)):
                fail("Mechromancer scene graph contains an invalid child index.")
            if child_index in parents:
                fail("Mechromancer authored nodes must each have exactly one package parent.")
            parents[child_index] = node_index
            visit_reachable(child_index)

    visit_reachable(root_indices[0])
    if reachable != set(range(len(nodes))):
        fail("Mechromancer must keep every authored node beneath its single package root.")
    node_index_by_name = {name: index for index, name in enumerate(node_names)}
    pistol_index = node_index_by_name["WeakPistol"]
    muzzle_index = node_index_by_name["PistolMuzzle"]
    if parents.get(muzzle_index) != pistol_index:
        fail("Mechromancer PistolMuzzle must remain a direct child of WeakPistol.")
    expected_sockets = {
        "FaceAnchor": "face_anchor",
        "ShoulderLamp": "light_mount",
        "WeakPistol": "weapon_mount",
        "PistolMuzzle": "weapon_muzzle",
    }
    actual_sockets = {
        name: str(nodes[node_index_by_name[name]].get("extras", {}).get("socket_type", ""))
        for name in expected_sockets
    }
    if actual_sockets != expected_sockets:
        fail(f"Mechromancer authored attachment sockets drifted from the exact runtime contract: {actual_sockets}")

    root_extras = nodes[root_indices[0]].get("extras", {})
    gltf_extras = gltf.get("extras", {})
    gltf_asset_id = gltf_extras.get("ironwright_asset_id") or root_extras.get("ironwright_asset_id")
    if gltf_asset_id != MECHROMANCER_ASSET_ID:
        fail("Mechromancer glTF and manifest asset IDs must match.")
    for key, expected in {
        "texture_resolution": 1024,
        "material_contract": "textured_metallic_roughness_pbr",
        "presentation_only": True,
        "collision": False,
        "gameplay_state": "none",
        "deterministic_build": True,
    }.items():
        if gltf_extras.get(key) != expected:
            fail(f"Mechromancer glTF package metadata must retain {key}={expected!r}.")
    if tuple(map(str, gltf_extras.get("required_nodes", []))) != MECHROMANCER_REQUIRED_NODES:
        fail("Mechromancer glTF must mirror the exact ordered stable-node package contract.")
    if tuple(map(str, gltf_extras.get("animation_clips", []))) != MECHROMANCER_ANIMATION_CLIPS:
        fail("Mechromancer glTF must mirror the exact ordered six-clip package contract.")

    forbidden_name_fragments = (
        "collisionshape",
        "staticbody",
        "characterbody",
        "rigidbody",
        "area3d",
        "navigation",
        "navmesh",
        "interactable",
    )
    forbidden_metadata_fragments = (
        "collision_layer",
        "collision_mask",
        "physics",
        "navigation",
        "navmesh",
        "interaction",
        "interactable",
        "hit_points",
        "health",
        "damage",
        "movement_speed",
        "attack_rate",
        "player_input",
    )
    for node in nodes:
        normalized_name = str(node.get("name", "")).lower().replace("_", "")
        if any(fragment in normalized_name for fragment in forbidden_name_fragments):
            fail(f"Mechromancer presentation asset embeds a gameplay-semantic node: {node.get('name')}")
        extras = node.get("extras", {})
        if not isinstance(extras, dict):
            fail(f"Mechromancer node {node.get('name')} extras must remain inspectable metadata.")
        for raw_key, value in extras.items():
            key = str(raw_key).lower()
            if key == "collision":
                if value is not False:
                    fail(f"Mechromancer node {node.get('name')} must not enable authored collision.")
                continue
            if key == "gameplay_state":
                if value != "none":
                    fail(f"Mechromancer node {node.get('name')} must not carry authored gameplay state.")
                continue
            if any(fragment in key for fragment in forbidden_metadata_fragments):
                fail(f"Mechromancer node {node.get('name')} embeds forbidden gameplay metadata: {raw_key}")
    if gltf.get("skins"):
        fail("Mechromancer authored presentation asset must not embed an unintentional skin or runtime rig.")

    materials = gltf.get("materials", [])
    material_names = [str(material.get("name", "")) for material in materials]
    if material_names != list(map(str, declared_material_names)):
        fail("Mechromancer glTF materials must exactly match the manifest-declared authored order.")
    images = gltf.get("images", [])
    textures = gltf.get("textures", [])
    if len(images) != 4 or len(textures) != 4:
        fail("Mechromancer glTF must expose exactly four shared PBR textures and four external images.")
    image_paths = [_gltf_image_path(gltf_path, image, "Mechromancer") for image in images]
    if len(set(image_paths)) != 4 or set(image_paths) != set(texture_paths.values()):
        fail("Mechromancer glTF images must be the four distinct manifest-declared package textures.")
    for image, image_path in zip(images, image_paths):
        if image.get("uri") != image_path.name:
            fail("Mechromancer glTF image URIs must be exact package-local filenames without aliases or traversal.")
    expected_sources = {role: image_paths.index(path) for role, path in texture_paths.items()}
    texture_sources = [texture.get("source") for texture in textures]
    if sorted(texture_sources) != list(range(4)):
        fail("Mechromancer glTF texture objects must map one-to-one onto the four authored images.")
    emissive_materials = set(map(str, declared_emissive_materials))
    for material in materials:
        material_name = str(material.get("name", "<unnamed>"))
        slots = {
            "base_color": _material_texture_source(gltf, material, "pbrMetallicRoughness", "baseColorTexture"),
            "normal": _material_texture_source(gltf, material, "normalTexture"),
            "orm": _material_texture_source(gltf, material, "pbrMetallicRoughness", "metallicRoughnessTexture"),
        }
        for role, source_index in slots.items():
            if source_index != expected_sources[role]:
                fail(f"Mechromancer material {material_name} must wire {role} to the exact declared texture.")
        normal_scale = material.get("normalTexture", {}).get("scale")
        if not isinstance(normal_scale, (int, float)) or not (0.04 <= float(normal_scale) <= 0.20):
            fail(
                f"Mechromancer material {material_name} normalTexture scale must stay within the restrained "
                f"player-asset range 0.04..0.20, got {normal_scale!r}."
            )
        if _material_texture_source(gltf, material, "occlusionTexture") != expected_sources["orm"]:
            fail(f"Mechromancer material {material_name} must wire occlusion to the declared packed ORM texture.")
        for texture_slot in (
            material.get("pbrMetallicRoughness", {}).get("baseColorTexture", {}),
            material.get("normalTexture", {}),
            material.get("pbrMetallicRoughness", {}).get("metallicRoughnessTexture", {}),
            material.get("occlusionTexture", {}),
        ):
            if texture_slot.get("texCoord", 0) != 0:
                fail(f"Mechromancer material {material_name} must consume the authored TEXCOORD_0 set.")
        pbr = material.get("pbrMetallicRoughness", {})
        for factor_name in ("metallicFactor", "roughnessFactor"):
            factor = pbr.get(factor_name, 1.0)
            if not isinstance(factor, (int, float)) or not (0.0 <= float(factor) <= 1.0):
                fail(f"Mechromancer material {material_name} has an invalid {factor_name}.")
        emissive_source = _material_texture_source(gltf, material, "emissiveTexture")
        emissive_factor = material.get("emissiveFactor", [0.0, 0.0, 0.0])
        has_emissive_factor = (
            isinstance(emissive_factor, list)
            and len(emissive_factor) == 3
            and any(float(channel) > 0.0 for channel in emissive_factor)
        )
        if material_name in emissive_materials:
            if emissive_source != expected_sources["emissive"] or not has_emissive_factor:
                fail(f"Mechromancer emissive material {material_name} must use the declared mask and a positive factor.")
        elif emissive_source >= 0 or has_emissive_factor:
            fail(f"Mechromancer non-emissive material {material_name} must not consume the authored emissive mask.")

    accessors = gltf.get("accessors", [])
    primitive_count = 0
    vertex_count = 0
    expected_attribute_types = {
        "POSITION": "VEC3",
        "NORMAL": "VEC3",
        "TEXCOORD_0": "VEC2",
        "TANGENT": "VEC4",
    }
    mesh_names = [str(mesh.get("name", "")) for mesh in gltf.get("meshes", [])]
    duplicate_mesh_names = sorted(name for name, count in Counter(mesh_names).items() if not name or count != 1)
    if duplicate_mesh_names:
        fail(f"Mechromancer mesh names must be non-empty and globally unique: {duplicate_mesh_names}")
    for mesh in gltf.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            primitive_count += 1
            if primitive.get("mode", 4) != 4:
                fail(f"Mechromancer {mesh.get('name', '<unnamed>')} primitive must remain indexed triangles.")
            attributes = primitive.get("attributes", {})
            if "JOINTS_0" in attributes or "WEIGHTS_0" in attributes:
                fail("Mechromancer authored presentation geometry must not carry unintentional skin attributes.")
            position_count = -1
            for semantic, accessor_type in expected_attribute_types.items():
                accessor_index = attributes.get(semantic)
                if not isinstance(accessor_index, int) or not (0 <= accessor_index < len(accessors)):
                    fail(f"Mechromancer {mesh.get('name', '<unnamed>')} primitive is missing {semantic}.")
                accessor = accessors[accessor_index]
                if accessor.get("type") != accessor_type or accessor.get("componentType") != 5126:
                    fail(f"Mechromancer {mesh.get('name', '<unnamed>')} {semantic} must use float {accessor_type} data.")
                accessor_count = int(accessor.get("count", 0))
                if accessor_count <= 0:
                    fail(f"Mechromancer {mesh.get('name', '<unnamed>')} {semantic} accessor must not be empty.")
                if semantic == "POSITION":
                    position_count = accessor_count
                    vertex_count += accessor_count
                    if not _valid_vec3_bounds(accessor.get("min"), accessor.get("max")):
                        fail(f"Mechromancer {mesh.get('name', '<unnamed>')} POSITION must preserve finite authored bounds.")
                elif accessor_count != position_count:
                    fail(f"Mechromancer {mesh.get('name', '<unnamed>')} {semantic} count must match POSITION.")
            material_index = primitive.get("material")
            if not isinstance(material_index, int) or not (0 <= material_index < len(materials)):
                fail(f"Mechromancer {mesh.get('name', '<unnamed>')} primitive must retain an authored material.")
            index_accessor_index = primitive.get("indices")
            if not isinstance(index_accessor_index, int) or not (0 <= index_accessor_index < len(accessors)):
                fail(f"Mechromancer {mesh.get('name', '<unnamed>')} primitive must retain an indexed triangle surface.")
            index_accessor = accessors[index_accessor_index]
            if (
                index_accessor.get("type") != "SCALAR"
                or index_accessor.get("componentType") not in {5123, 5125}
                or int(index_accessor.get("count", 0)) < 3
                or int(index_accessor.get("count", 0)) % 3 != 0
            ):
                fail(f"Mechromancer {mesh.get('name', '<unnamed>')} triangle index accessor is invalid.")
    if primitive_count < 150 or vertex_count < 40000:
        fail(
            "Mechromancer authored geometry fell below its high-definition production floor: "
            f"{primitive_count} primitives, {vertex_count} POSITION vertices."
        )

    bounds_min, bounds_max = _gltf_aggregate_bounds(gltf)
    bounds_size = tuple(bounds_max[index] - bounds_min[index] for index in range(3))
    _require_close_vector(bounds_min, MECHROMANCER_BOUNDS_MIN, 1.0e-6, "Mechromancer frozen minimum bounds")
    _require_close_vector(bounds_max, MECHROMANCER_BOUNDS_MAX, 1.0e-6, "Mechromancer frozen maximum bounds")
    manifest_bounds = manifest.get("aggregate_bounds")
    if not isinstance(manifest_bounds, dict) or set(manifest_bounds) != {"min", "max"}:
        fail("Mechromancer manifest must declare exact aggregate minimum and maximum bounds.")
    _require_close_vector(manifest_bounds.get("min"), bounds_min, 1.0e-5, "Mechromancer manifest minimum bounds")
    _require_close_vector(manifest_bounds.get("max"), bounds_max, 1.0e-5, "Mechromancer manifest maximum bounds")
    if abs(float(manifest.get("world_scale_m", 0.0)) - bounds_size[1]) > 1.0e-5:
        fail("Mechromancer manifest world scale must equal its measured authored standing height.")
    for axis in range(3):
        if not (MECHROMANCER_BOUNDS_MIN_ENVELOPE[axis][0] <= bounds_min[axis] <= MECHROMANCER_BOUNDS_MIN_ENVELOPE[axis][1]):
            fail(f"Mechromancer minimum bounds drifted outside its authored silhouette envelope: {bounds_min}")
        if not (MECHROMANCER_BOUNDS_MAX_ENVELOPE[axis][0] <= bounds_max[axis] <= MECHROMANCER_BOUNDS_MAX_ENVELOPE[axis][1]):
            fail(f"Mechromancer maximum bounds drifted outside its authored silhouette envelope: {bounds_max}")
        if not (MECHROMANCER_BOUNDS_SIZE_ENVELOPE[axis][0] <= bounds_size[axis] <= MECHROMANCER_BOUNDS_SIZE_ENVELOPE[axis][1]):
            fail(f"Mechromancer aggregate bounds drifted outside its human field-engineer scale: {bounds_size}")

    _validate_mechromancer_animations(gltf, buffer_data, node_names, reachable)


def validate_heartforge_asset() -> None:
    manifest_path = ROOT / "game/data/heartforge_asset_manifest.json"
    gltf_path = ROOT / "game/assets/heartforge/heartforge.gltf"
    source_path = ROOT / "game/assets/heartforge/source/build_heartforge_asset.py"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    gltf = json.loads(gltf_path.read_text(encoding="utf-8"))
    source = source_path.read_text(encoding="utf-8")
    if manifest.get("asset_id") != "heartforge.core.v1":
        fail("Heartforge asset manifest has an unexpected stable asset ID.")
    if manifest.get("runtime_scene") != "res://assets/heartforge/heartforge.gltf":
        fail("Heartforge asset manifest points at an unexpected runtime model.")
    if manifest.get("texture_resolution") != 1024:
        fail("Heartforge manifest must preserve the authored 1024 texture resolution.")
    if manifest.get("material_workflow") != "metallic_roughness_pbr":
        fail("Heartforge manifest must preserve the metallic-roughness PBR workflow.")
    declared_textures = manifest.get("textures")
    if not isinstance(declared_textures, dict) or set(declared_textures) != set(HEARTFORGE_TEXTURE_ROLES):
        fail("Heartforge manifest must declare exactly base_color, normal, orm and emissive textures.")
    texture_paths: dict[str, Path] = {}
    heartforge_package = (ROOT / "game/assets/heartforge").resolve()
    for role in HEARTFORGE_TEXTURE_ROLES:
        raw_path = declared_textures.get(role)
        if not isinstance(raw_path, str) or not raw_path.lower().endswith(".png"):
            fail(f"Heartforge {role} texture declaration must point to a PNG file.")
        texture_path = _resolve_authored_texture_path(raw_path, "heartforge")
        try:
            texture_path.relative_to(heartforge_package)
        except ValueError:
            fail(f"Heartforge {role} texture must live inside the authored Heartforge package.")
        if not texture_path.is_file():
            fail(f"Heartforge {role} texture is missing: {raw_path}")
        if texture_path.stat().st_size < 1024:
            fail(f"Heartforge {role} texture is unexpectedly small: {texture_path.stat().st_size} bytes.")
        width, height, _, _ = _decode_png_rows(texture_path, "Heartforge")
        if (width, height) != (1024, 1024):
            fail(f"Heartforge {role} texture must be exactly 1024x1024, got {width}x{height}.")
        texture_paths[role] = texture_path
    if len(set(texture_paths.values())) != len(HEARTFORGE_TEXTURE_ROLES):
        fail("Heartforge PBR roles must resolve to four distinct PNG files.")
    _validate_neutral_blue_normal_texture(texture_paths["normal"], "Heartforge")

    declared_stable_nodes = manifest.get("stable_nodes")
    if (
        not isinstance(declared_stable_nodes, list)
        or len(declared_stable_nodes) != len(HEARTFORGE_STABLE_NODES)
        or set(map(str, declared_stable_nodes)) != set(HEARTFORGE_STABLE_NODES)
    ):
        fail("Heartforge manifest must preserve the complete stable runtime node contract.")
    if manifest.get("authored_detail_root") != HEARTFORGE_AUTHORED_DETAIL_ROOT:
        fail("Heartforge manifest must name VerticalSliceForgeArt as its imported authored-detail root.")
    declared_detail_nodes = manifest.get("authored_detail_nodes")
    if (
        not isinstance(declared_detail_nodes, list)
        or len(declared_detail_nodes) != len(HEARTFORGE_AUTHORED_DETAIL_NODES)
        or set(map(str, declared_detail_nodes)) != set(HEARTFORGE_AUTHORED_DETAIL_NODES)
    ):
        fail("Heartforge manifest must preserve the complete imported service-detail node contract.")
    if manifest.get("animation_clips") != []:
        fail("Heartforge manifest must declare an empty animation contract.")
    declared_socket_types = {str(socket_type) for socket_type in manifest.get("socket_contract", [])}
    if declared_socket_types != HEARTFORGE_MANIFEST_SOCKET_TYPES:
        fail("Heartforge manifest must preserve the exact anchor, reactor, control, fabrication and service socket roles.")

    if 'mesh("CoreHousing", add_ellipsoid' not in source:
        fail("Heartforge source must retain a smooth high-definition reactor housing.")
    if 'mesh("FurnaceCore", add_ellipsoid' not in source:
        fail("Heartforge source must retain a smooth high-definition furnace envelope.")
    if 'mesh("CoreCladdingSegment", add_beveled_box' not in source:
        fail("Heartforge source must retain chamfered service cladding.")
    root_node_extras = next(
        (node.get("extras", {}) for node in gltf.get("nodes", []) if node.get("name") == "HeartforgeModel"),
        {},
    )
    gltf_asset_id = gltf.get("extras", {}).get("ironwright_asset_id") or root_node_extras.get("ironwright_asset_id")
    if gltf_asset_id != manifest["asset_id"]:
        fail("Heartforge glTF and manifest asset IDs must match.")
    gltf_extras = gltf.get("extras", {})
    if gltf_extras.get("texture_resolution") != 1024:
        fail("Heartforge glTF must preserve its authored 1024 texture-resolution contract.")
    if gltf_extras.get("material_contract") != "textured_metallic_roughness_pbr":
        fail("Heartforge glTF must preserve its textured metallic-roughness material contract.")

    nodes = gltf.get("nodes", [])
    node_names = [str(node.get("name", "")) for node in nodes]
    duplicate_names = sorted(name for name, count in Counter(node_names).items() if not name or count != 1)
    if duplicate_names:
        fail(f"Heartforge glTF node names must be non-empty and globally unique: {duplicate_names}")
    node_name_set = set(node_names)
    node_by_name = {str(node.get("name")): node for node in nodes}
    for required in (*HEARTFORGE_STABLE_NODES, HEARTFORGE_AUTHORED_DETAIL_ROOT, *HEARTFORGE_AUTHORED_DETAIL_NODES):
        if required not in node_name_set:
            fail(f"Heartforge glTF is missing required authored node: {required}")

    detail_root = node_by_name[HEARTFORGE_AUTHORED_DETAIL_ROOT]
    detail_extras = detail_root.get("extras", {})
    if detail_extras.get("presentation_only") is not True or detail_extras.get("authored_static_detail") is not True:
        fail("Heartforge authored-detail root must retain its presentation-only imported-static contract.")
    detail_child_names = {
        node_names[int(child_index)]
        for child_index in detail_root.get("children", [])
        if isinstance(child_index, int) and 0 <= child_index < len(node_names)
    }
    if detail_child_names != set(HEARTFORGE_AUTHORED_DETAIL_NODES):
        fail("Heartforge authored-detail root must directly own every declared migrated service node.")
    for detail_name, service_role in HEARTFORGE_SERVICE_HARDWARE.items():
        detail_node = node_by_name[detail_name]
        if detail_node.get("extras", {}).get("service_hardware") != service_role:
            fail(f"Heartforge authored detail {detail_name} must retain service role {service_role}.")
        if detail_name.endswith("Left") and detail_node.get("extras", {}).get("assembly_side") != "left":
            fail(f"Heartforge authored detail {detail_name} must retain its left-side assembly metadata.")
        if detail_name.endswith("Right") and detail_node.get("extras", {}).get("assembly_side") != "right":
            fail(f"Heartforge authored detail {detail_name} must retain its right-side assembly metadata.")
    for clamp_index in range(5):
        clamp_name = f"ForgeTopClamp{clamp_index:02d}"
        if node_by_name[clamp_name].get("extras", {}).get("clamp_slot") != clamp_index:
            fail(f"Heartforge authored detail {clamp_name} must retain clamp slot {clamp_index}.")

    actual_socket_nodes = {
        str(node.get("name")): str(node.get("extras", {}).get("socket_type"))
        for node in nodes
        if str(node.get("extras", {}).get("socket_type", ""))
    }
    if actual_socket_nodes != HEARTFORGE_SOCKET_NODES:
        fail(f"Heartforge glTF socket nodes drifted from the exact runtime contract: {actual_socket_nodes}")
    for node_name, expected_translation in HEARTFORGE_CRITICAL_TRANSLATIONS.items():
        _require_close_vector(
            node_by_name[node_name].get("translation", [0.0, 0.0, 0.0]),
            expected_translation,
            1.0e-6,
            f"Heartforge {node_name} translation",
        )

    materials = gltf.get("materials", [])
    material_names = [str(material.get("name", "")) for material in materials]
    if len(materials) != 6 or set(material_names) != HEARTFORGE_MATERIAL_NAMES:
        fail(f"Heartforge glTF must preserve exactly its six authored material families: {material_names}")
    if len(gltf.get("textures", [])) != 4 or len(gltf.get("images", [])) != 4:
        fail("Heartforge glTF must expose exactly four shared PBR textures and four external images.")

    accessors = gltf.get("accessors", [])
    primitive_count = 0
    expected_attribute_types = {
        "POSITION": "VEC3",
        "NORMAL": "VEC3",
        "TEXCOORD_0": "VEC2",
        "TANGENT": "VEC4",
    }
    for mesh in gltf.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            primitive_count += 1
            attributes = primitive.get("attributes", {})
            position_count = -1
            for semantic, accessor_type in expected_attribute_types.items():
                accessor_index = attributes.get(semantic)
                if not isinstance(accessor_index, int) or not (0 <= accessor_index < len(accessors)):
                    fail(f"Heartforge {mesh.get('name', '<unnamed>')} primitive is missing {semantic}.")
                accessor = accessors[accessor_index]
                if accessor.get("type") != accessor_type or accessor.get("componentType") != 5126:
                    fail(f"Heartforge {mesh.get('name', '<unnamed>')} {semantic} must use float {accessor_type} data.")
                accessor_count = int(accessor.get("count", 0))
                if accessor_count <= 0:
                    fail(f"Heartforge {mesh.get('name', '<unnamed>')} {semantic} accessor must not be empty.")
                if semantic == "POSITION":
                    position_count = accessor_count
                elif accessor_count != position_count:
                    fail(f"Heartforge {mesh.get('name', '<unnamed>')} {semantic} count must match POSITION.")
            material_index = primitive.get("material")
            if not isinstance(material_index, int) or not (0 <= material_index < len(materials)):
                fail(f"Heartforge {mesh.get('name', '<unnamed>')} primitive must retain an authored material.")
    if primitive_count == 0:
        fail("Heartforge glTF must contain authored mesh primitives.")

    image_paths = [_gltf_image_path(gltf_path, image, "Heartforge") for image in gltf.get("images", [])]
    if len(set(image_paths)) != 4 or set(image_paths) != set(texture_paths.values()):
        fail("Heartforge glTF images must be the four distinct manifest-declared package textures.")
    expected_sources = {role: image_paths.index(path) for role, path in texture_paths.items()}
    for material in materials:
        material_name = str(material.get("name", "<unnamed>"))
        slots = {
            "base_color": _material_texture_source(gltf, material, "pbrMetallicRoughness", "baseColorTexture"),
            "normal": _material_texture_source(gltf, material, "normalTexture"),
            "orm": _material_texture_source(gltf, material, "pbrMetallicRoughness", "metallicRoughnessTexture"),
        }
        for role, source_index in slots.items():
            if source_index != expected_sources[role]:
                fail(f"Heartforge material {material_name} must wire its {role} channel to the declared texture.")
        if _material_texture_source(gltf, material, "occlusionTexture") != expected_sources["orm"]:
            fail(f"Heartforge material {material_name} must wire occlusion to the declared ORM texture.")
        emissive_source = _material_texture_source(gltf, material, "emissiveTexture")
        emissive_factor = material.get("emissiveFactor", [0.0, 0.0, 0.0])
        has_emissive_factor = isinstance(emissive_factor, list) and any(float(channel) > 0.0 for channel in emissive_factor)
        if material_name in HEARTFORGE_EMISSIVE_MATERIALS:
            if emissive_source != expected_sources["emissive"] or not has_emissive_factor:
                fail(f"Heartforge emissive material {material_name} must use the declared mask and a positive emissive factor.")
        elif emissive_source >= 0 or has_emissive_factor:
            fail(f"Heartforge non-emissive material {material_name} must not consume the authored emissive mask.")

    if gltf.get("animations", []) != []:
        fail("Heartforge authored shell must contain zero animations.")

    for radial_index in range(8):
        radial_name = f"HeartforgeFocalRadialFin{radial_index:02d}"
        _require_rotated_node(node_by_name[radial_name], f"Heartforge radial fin {radial_name}")
    expected_cable_rotation = (0.0, 0.0, math.sqrt(0.5), math.sqrt(0.5))
    for cable_name in ("HeartforgeFocalCableBranchLeft", "HeartforgeFocalCableBranchRight"):
        _require_rotated_node(node_by_name[cable_name], f"Heartforge cable {cable_name}")
        _require_close_quaternion(
            node_by_name[cable_name].get("rotation", [0.0, 0.0, 0.0, 1.0]),
            expected_cable_rotation,
            1.0e-6,
            f"Heartforge {cable_name} rotation",
        )

    mesh_by_name = {str(mesh.get("name")): mesh for mesh in gltf.get("meshes", [])}
    for mesh_name, minimum_vertices in {"CoreHousing": 900, "FurnaceCore": 900}.items():
        mesh = mesh_by_name.get(mesh_name)
        if not mesh or not mesh.get("primitives"):
            fail(f"Heartforge glTF is missing the {mesh_name} mesh required for focal review.")
        vertex_count = sum(
            int(accessors[int(primitive.get("attributes", {}).get("POSITION"))].get("count", 0))
            for primitive in mesh.get("primitives", [])
        )
        if vertex_count < minimum_vertices:
            fail(f"Heartforge {mesh_name} must retain at least {minimum_vertices} authored vertices.")

    bounds_min, bounds_max = _gltf_aggregate_bounds(gltf)
    _require_close_vector(bounds_min, HEARTFORGE_BOUNDS_MIN, 1.0e-5, "Heartforge aggregate minimum bounds")
    _require_close_vector(bounds_max, HEARTFORGE_BOUNDS_MAX, 1.0e-5, "Heartforge aggregate maximum bounds")


def validate_heartforge_threshold_asset() -> None:
    manifest_path = ROOT / "game/data/heartforge_threshold_asset_manifest.json"
    gltf_path = ROOT / "game/assets/heartforge_threshold/heartforge_threshold.gltf"
    source_path = ROOT / "game/assets/heartforge_threshold/source/build_heartforge_threshold_asset.py"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    gltf = json.loads(gltf_path.read_text(encoding="utf-8"))

    if manifest.get("asset_id") != HEARTFORGE_THRESHOLD_ASSET_ID:
        fail("Heartforge threshold manifest has an unexpected stable asset ID.")
    if manifest.get("asset_quality") != "authored_high_definition":
        fail("Heartforge threshold manifest must retain its authored high-definition quality contract.")
    if manifest.get("root_name") != HEARTFORGE_THRESHOLD_ROOT:
        fail("Heartforge threshold manifest must name AuthoredHeartforgeThreshold as its package root.")
    if manifest.get("runtime_scene") != "res://assets/heartforge_threshold/heartforge_threshold.gltf":
        fail("Heartforge threshold manifest points at an unexpected runtime model.")
    if manifest.get("source_builder") != "game/assets/heartforge_threshold/source/build_heartforge_threshold_asset.py":
        fail("Heartforge threshold manifest must point to its reproducible authored source builder.")
    if not source_path.is_file():
        fail("Heartforge threshold authored source builder is missing.")
    if manifest.get("texture_resolution") != 1024:
        fail("Heartforge threshold manifest must preserve the authored 1024 texture resolution.")
    if manifest.get("material_workflow") != "metallic_roughness_pbr":
        fail("Heartforge threshold manifest must preserve the metallic-roughness PBR workflow.")
    if manifest.get("manufactured_surface_profile") != "textured_chamfered_high_definition":
        fail("Heartforge threshold manifest must preserve its manufactured high-definition surface profile.")
    if manifest.get("presentation_only") is not True:
        fail("Heartforge threshold must remain explicitly presentation-only.")
    if manifest.get("collision") is not False:
        fail("Heartforge threshold must not embed collision or block the open refuge route.")
    if manifest.get("gameplay_state") != "none":
        fail("Heartforge threshold must not introduce gameplay or player-managed gate state.")
    _require_close_vector(
        manifest.get("world_placement_hint"),
        (0.0, 0.0, -5.8),
        1.0e-6,
        "Heartforge threshold world-placement hint",
    )
    if manifest.get("animation_clips") != []:
        fail("Heartforge threshold manifest must declare an empty animation contract.")
    if manifest.get("third_party_assets") != []:
        fail("Heartforge threshold must remain an original authored package without undeclared third-party runtime assets.")

    clear_opening = manifest.get("clear_opening")
    if not isinstance(clear_opening, dict) or set(clear_opening) != {"width_m", "height_m", "inner_edges_x"}:
        fail("Heartforge threshold manifest must declare exactly width, height and inner-edge clearance metadata.")
    _require_close_vector(
        (clear_opening.get("width_m"), clear_opening.get("height_m")),
        (HEARTFORGE_THRESHOLD_CLEAR_WIDTH, HEARTFORGE_THRESHOLD_CLEAR_HEIGHT),
        1.0e-6,
        "Heartforge threshold declared opening dimensions",
    )
    _require_close_vector(
        clear_opening.get("inner_edges_x"),
        HEARTFORGE_THRESHOLD_INNER_EDGES_X,
        1.0e-6,
        "Heartforge threshold declared inner edges",
    )

    declared_material_names = manifest.get("material_names")
    if (
        not isinstance(declared_material_names, list)
        or len(declared_material_names) != len(HEARTFORGE_THRESHOLD_MATERIAL_NAMES)
        or set(map(str, declared_material_names)) != HEARTFORGE_THRESHOLD_MATERIAL_NAMES
    ):
        fail("Heartforge threshold manifest must declare exactly its six authored material families.")
    declared_stable_nodes = manifest.get("stable_nodes")
    if (
        not isinstance(declared_stable_nodes, list)
        or len(declared_stable_nodes) != len(HEARTFORGE_THRESHOLD_STABLE_NODES)
        or tuple(map(str, declared_stable_nodes)) != HEARTFORGE_THRESHOLD_STABLE_NODES
    ):
        fail("Heartforge threshold manifest must preserve the exact ordered stable-node contract.")
    declared_detail_nodes = manifest.get("authored_detail_nodes")
    if (
        not isinstance(declared_detail_nodes, list)
        or len(declared_detail_nodes) != len(HEARTFORGE_THRESHOLD_AUTHORED_DETAIL_NODES)
        or tuple(map(str, declared_detail_nodes)) != HEARTFORGE_THRESHOLD_AUTHORED_DETAIL_NODES
    ):
        fail("Heartforge threshold manifest must preserve the exact ordered authored-detail contract.")

    declared_textures = manifest.get("textures")
    if not isinstance(declared_textures, dict) or set(declared_textures) != set(HEARTFORGE_THRESHOLD_TEXTURE_ROLES):
        fail("Heartforge threshold manifest must declare exactly base_color, normal, orm and emissive textures.")
    texture_paths: dict[str, Path] = {}
    threshold_package = (ROOT / "game/assets/heartforge_threshold").resolve()
    for role in HEARTFORGE_THRESHOLD_TEXTURE_ROLES:
        raw_path = declared_textures.get(role)
        if not isinstance(raw_path, str) or not raw_path.lower().endswith(".png"):
            fail(f"Heartforge threshold {role} texture declaration must point to a PNG file.")
        texture_path = _resolve_authored_texture_path(raw_path, "heartforge_threshold")
        try:
            texture_path.relative_to(threshold_package)
        except ValueError:
            fail(f"Heartforge threshold {role} texture must live inside the authored threshold package.")
        if not texture_path.is_file():
            fail(f"Heartforge threshold {role} texture is missing: {raw_path}")
        if texture_path.stat().st_size < 1024:
            fail(f"Heartforge threshold {role} texture is unexpectedly small: {texture_path.stat().st_size} bytes.")
        width, height, _, _ = _decode_png_rows(texture_path, "Heartforge threshold")
        if (width, height) != (1024, 1024):
            fail(f"Heartforge threshold {role} texture must be exactly 1024x1024, got {width}x{height}.")
        texture_paths[role] = texture_path
    if len(set(texture_paths.values())) != len(HEARTFORGE_THRESHOLD_TEXTURE_ROLES):
        fail("Heartforge threshold PBR roles must resolve to four distinct PNG files.")
    _validate_neutral_blue_normal_texture(texture_paths["normal"], "Heartforge threshold")

    nodes = gltf.get("nodes", [])
    node_names = [str(node.get("name", "")) for node in nodes]
    duplicate_names = sorted(name for name, count in Counter(node_names).items() if not name or count != 1)
    if duplicate_names:
        fail(f"Heartforge threshold glTF node names must be non-empty and globally unique: {duplicate_names}")
    node_name_set = set(node_names)
    missing_nodes = sorted(set(HEARTFORGE_THRESHOLD_REQUIRED_NODES) - node_name_set)
    if missing_nodes:
        fail(f"Heartforge threshold glTF is missing required authored nodes: {missing_nodes}")
    root_indices = [index for index, name in enumerate(node_names) if name == HEARTFORGE_THRESHOLD_ROOT]
    if len(root_indices) != 1:
        fail("Heartforge threshold glTF must contain exactly one AuthoredHeartforgeThreshold root.")
    root_node = nodes[root_indices[0]]
    root_extras = root_node.get("extras", {})
    gltf_extras = gltf.get("extras", {})
    gltf_asset_id = gltf_extras.get("ironwright_asset_id") or root_extras.get("ironwright_asset_id")
    if gltf_asset_id != HEARTFORGE_THRESHOLD_ASSET_ID:
        fail("Heartforge threshold glTF and manifest asset IDs must match.")
    for key, expected in {
        "texture_resolution": 1024,
        "material_contract": "textured_metallic_roughness_pbr",
        "presentation_only": True,
        "collision": False,
        "gameplay_state": "none",
        "animation_clips": [],
    }.items():
        if gltf_extras.get(key) != expected:
            fail(f"Heartforge threshold package metadata must retain {key}={expected!r}.")
    if tuple(map(str, gltf_extras.get("required_nodes", []))) != HEARTFORGE_THRESHOLD_STABLE_NODES:
        fail("Heartforge threshold glTF must preserve the exact ordered stable-node package contract.")
    if tuple(map(str, gltf_extras.get("authored_detail_nodes", []))) != HEARTFORGE_THRESHOLD_AUTHORED_DETAIL_NODES:
        fail("Heartforge threshold glTF must preserve the exact ordered authored-detail package contract.")
    gltf_clear_opening = gltf_extras.get("clear_opening")
    if not isinstance(gltf_clear_opening, dict) or set(gltf_clear_opening) != {"width_m", "height_m", "inner_edges_x"}:
        fail("Heartforge threshold glTF must expose exact package-level opening-clearance metadata.")
    _require_close_vector(
        (gltf_clear_opening.get("width_m"), gltf_clear_opening.get("height_m")),
        (HEARTFORGE_THRESHOLD_CLEAR_WIDTH, HEARTFORGE_THRESHOLD_CLEAR_HEIGHT),
        1.0e-6,
        "Heartforge threshold package opening dimensions",
    )
    _require_close_vector(
        gltf_clear_opening.get("inner_edges_x"),
        HEARTFORGE_THRESHOLD_INNER_EDGES_X,
        1.0e-6,
        "Heartforge threshold package inner edges",
    )
    _require_close_vector(
        gltf_extras.get("world_placement_hint"),
        (0.0, 0.0, -5.8),
        1.0e-6,
        "Heartforge threshold package placement hint",
    )
    for key, expected in {
        "asset_quality": "authored_high_definition",
        "presentation_only": True,
        "collision": False,
        "gameplay_state": "none",
        "manufactured_surface_profile": "textured_chamfered_high_definition",
        "material_contract": "textured_metallic_roughness_pbr",
    }.items():
        if root_extras.get(key) != expected:
            fail(f"Heartforge threshold root metadata must retain {key}={expected!r}.")
    _require_close_vector(
        root_extras.get("world_placement_hint"),
        (0.0, 0.0, -5.8),
        1.0e-6,
        "Heartforge threshold glTF placement hint",
    )
    _require_close_vector(
        (root_extras.get("clear_opening_width_m"), root_extras.get("clear_opening_height_m")),
        (HEARTFORGE_THRESHOLD_CLEAR_WIDTH, HEARTFORGE_THRESHOLD_CLEAR_HEIGHT),
        1.0e-6,
        "Heartforge threshold glTF opening dimensions",
    )
    _require_close_vector(
        root_extras.get("clear_opening_inner_edges_x"),
        HEARTFORGE_THRESHOLD_INNER_EDGES_X,
        1.0e-6,
        "Heartforge threshold glTF inner edges",
    )

    default_scene_index = gltf.get("scene", 0)
    scenes = gltf.get("scenes", [])
    if not isinstance(default_scene_index, int) or not (0 <= default_scene_index < len(scenes)):
        fail("Heartforge threshold glTF must name a valid default scene.")
    if scenes[default_scene_index].get("nodes") != root_indices:
        fail("Heartforge threshold default scene must expose only its authored package root.")
    reachable: set[int] = set()

    def visit_reachable(node_index: int) -> None:
        if node_index in reachable:
            fail("Heartforge threshold scene graph must not contain cycles or shared-node aliases.")
        reachable.add(node_index)
        for child_index in nodes[node_index].get("children", []):
            if not isinstance(child_index, int) or not (0 <= child_index < len(nodes)):
                fail("Heartforge threshold scene graph contains an invalid child index.")
            visit_reachable(child_index)

    visit_reachable(root_indices[0])
    if reachable != set(range(len(nodes))):
        fail("Heartforge threshold must keep every authored node beneath its single package root.")

    forbidden_name_fragments = (
        "collisionshape",
        "staticbody",
        "characterbody",
        "rigidbody",
        "area3d",
        "navigation",
        "navmesh",
        "interactable",
        "powersource",
        "powergrid",
        "routeblocker",
    )
    forbidden_metadata_fragments = (
        "physics",
        "navigation",
        "navmesh",
        "interaction",
        "interactable",
        "power_network",
        "power_grid",
        "power_source",
        "route_blocker",
        "blocks_route",
        "door_state",
        "socket_type",
    )
    for metadata_label, metadata in (
        ("manifest", manifest),
        ("glTF package", gltf_extras),
        ("glTF root", root_extras),
    ):
        for raw_key in metadata:
            key = str(raw_key).lower()
            if any(fragment in key for fragment in forbidden_metadata_fragments):
                fail(f"Heartforge threshold {metadata_label} embeds forbidden gameplay metadata: {raw_key}")
    for node in nodes:
        normalized_name = str(node.get("name", "")).lower().replace("_", "")
        if any(fragment in normalized_name for fragment in forbidden_name_fragments):
            fail(f"Heartforge threshold presentation asset embeds a gameplay-semantic node: {node.get('name')}")
        extras = node.get("extras", {})
        if not isinstance(extras, dict):
            fail(f"Heartforge threshold node {node.get('name')} extras must remain inspectable metadata.")
        for raw_key, value in extras.items():
            key = str(raw_key).lower()
            if any(fragment in key for fragment in forbidden_metadata_fragments):
                fail(f"Heartforge threshold node {node.get('name')} embeds forbidden gameplay metadata: {raw_key}")
            if key == "collision" and value is not False:
                fail(f"Heartforge threshold node {node.get('name')} must not enable collision.")
            if key == "gameplay_state" and value != "none":
                fail(f"Heartforge threshold node {node.get('name')} must not carry gameplay state.")
    if gltf.get("skins"):
        fail("Heartforge threshold presentation asset must not embed a runtime rig or skin.")
    if gltf.get("animations", []) != []:
        fail("Heartforge threshold authored presentation asset must contain zero animations.")

    materials = gltf.get("materials", [])
    material_names = [str(material.get("name", "")) for material in materials]
    if len(materials) != len(HEARTFORGE_THRESHOLD_MATERIAL_NAMES) or set(material_names) != HEARTFORGE_THRESHOLD_MATERIAL_NAMES:
        fail(f"Heartforge threshold glTF must preserve exactly its six authored material families: {material_names}")
    if len(gltf.get("textures", [])) != 4 or len(gltf.get("images", [])) != 4:
        fail("Heartforge threshold glTF must expose exactly four shared PBR textures and four external images.")

    accessors = gltf.get("accessors", [])
    primitive_count = 0
    expected_attribute_types = {
        "POSITION": "VEC3",
        "NORMAL": "VEC3",
        "TEXCOORD_0": "VEC2",
        "TANGENT": "VEC4",
    }
    for mesh in gltf.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            primitive_count += 1
            attributes = primitive.get("attributes", {})
            position_count = -1
            for semantic, accessor_type in expected_attribute_types.items():
                accessor_index = attributes.get(semantic)
                if not isinstance(accessor_index, int) or not (0 <= accessor_index < len(accessors)):
                    fail(f"Heartforge threshold {mesh.get('name', '<unnamed>')} primitive is missing {semantic}.")
                accessor = accessors[accessor_index]
                if accessor.get("type") != accessor_type or accessor.get("componentType") != 5126:
                    fail(f"Heartforge threshold {mesh.get('name', '<unnamed>')} {semantic} must use float {accessor_type} data.")
                accessor_count = int(accessor.get("count", 0))
                if accessor_count <= 0:
                    fail(f"Heartforge threshold {mesh.get('name', '<unnamed>')} {semantic} accessor must not be empty.")
                if semantic == "POSITION":
                    position_count = accessor_count
                elif accessor_count != position_count:
                    fail(f"Heartforge threshold {mesh.get('name', '<unnamed>')} {semantic} count must match POSITION.")
            material_index = primitive.get("material")
            if not isinstance(material_index, int) or not (0 <= material_index < len(materials)):
                fail(f"Heartforge threshold {mesh.get('name', '<unnamed>')} primitive must retain an authored material.")
    if primitive_count == 0:
        fail("Heartforge threshold glTF must contain authored mesh primitives.")

    image_paths = [_gltf_image_path(gltf_path, image, "Heartforge threshold") for image in gltf.get("images", [])]
    if len(set(image_paths)) != 4 or set(image_paths) != set(texture_paths.values()):
        fail("Heartforge threshold glTF images must be the four distinct manifest-declared package textures.")
    expected_sources = {role: image_paths.index(path) for role, path in texture_paths.items()}
    for material in materials:
        material_name = str(material.get("name", "<unnamed>"))
        slots = {
            "base_color": _material_texture_source(gltf, material, "pbrMetallicRoughness", "baseColorTexture"),
            "normal": _material_texture_source(gltf, material, "normalTexture"),
            "orm": _material_texture_source(gltf, material, "pbrMetallicRoughness", "metallicRoughnessTexture"),
        }
        for role, source_index in slots.items():
            if source_index != expected_sources[role]:
                fail(f"Heartforge threshold material {material_name} must wire its {role} channel to the declared texture.")
        if _material_texture_source(gltf, material, "occlusionTexture") != expected_sources["orm"]:
            fail(f"Heartforge threshold material {material_name} must wire occlusion to the declared ORM texture.")
        emissive_source = _material_texture_source(gltf, material, "emissiveTexture")
        emissive_factor = material.get("emissiveFactor", [0.0, 0.0, 0.0])
        has_emissive_factor = isinstance(emissive_factor, list) and any(float(channel) > 0.0 for channel in emissive_factor)
        if material_name in HEARTFORGE_THRESHOLD_EMISSIVE_MATERIALS:
            if emissive_source != expected_sources["emissive"] or not has_emissive_factor:
                fail(f"Heartforge threshold emissive material {material_name} must use the declared mask and a positive factor.")
        elif emissive_source >= 0 or has_emissive_factor:
            fail(f"Heartforge threshold non-emissive material {material_name} must not consume the authored emissive mask.")

    pillar_bounds = _gltf_named_node_bounds(
        gltf,
        {"ThresholdPillarL", "ThresholdPillarR", "ThresholdLintel"},
        "Heartforge threshold",
    )
    left_inner_edge = pillar_bounds["ThresholdPillarL"][1][0]
    right_inner_edge = pillar_bounds["ThresholdPillarR"][0][0]
    measured_width = right_inner_edge - left_inner_edge
    measured_height = pillar_bounds["ThresholdLintel"][0][1]
    _require_close_vector(
        (left_inner_edge, right_inner_edge, measured_width, measured_height),
        (*HEARTFORGE_THRESHOLD_INNER_EDGES_X, HEARTFORGE_THRESHOLD_CLEAR_WIDTH, HEARTFORGE_THRESHOLD_CLEAR_HEIGHT),
        0.025,
        "Heartforge threshold measured clear opening",
    )

    bounds_min, bounds_max = _gltf_aggregate_bounds(gltf)
    bounds_size = tuple(bounds_max[index] - bounds_min[index] for index in range(3))
    if not (
        -5.5 <= bounds_min[0] <= -3.9
        and 3.9 <= bounds_max[0] <= 5.5
        and -0.25 <= bounds_min[1] <= 0.25
        and 3.18 <= bounds_max[1] <= 5.5
        and -1.75 <= bounds_min[2] <= 0.0
        and 0.0 <= bounds_max[2] <= 1.75
        and 7.8 <= bounds_size[0] <= 11.0
        and 3.18 <= bounds_size[1] <= 5.75
        and 0.3 <= bounds_size[2] <= 3.5
    ):
        fail(
            "Heartforge threshold aggregate bounds drifted outside its bounded refuge-entry envelope: "
            f"min={bounds_min}, max={bounds_max}, size={bounds_size}"
        )


def validate_salvage_asset() -> None:
    manifest_path = ROOT / "game/data/salvage_asset_manifest.json"
    gltf_path = ROOT / "game/assets/salvage/salvage.gltf"
    source_path = ROOT / "game/assets/salvage/source/build_salvage_asset.py"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    gltf = json.loads(gltf_path.read_text(encoding="utf-8"))
    source = source_path.read_text(encoding="utf-8")
    if manifest.get("asset_id") != "salvage.opening_wreck.v1":
        fail("Salvage asset manifest has an unexpected stable asset ID.")
    if manifest.get("runtime_scene") != "res://assets/salvage/salvage.gltf":
        fail("Salvage asset manifest points at an unexpected runtime model.")
    if "add_ellipsoid" not in source or "add_torus" not in source:
        fail("Salvage source must retain smooth chassis and wheel-rim geometry.")
    root_node_extras = next(
        (node.get("extras", {}) for node in gltf.get("nodes", []) if node.get("name") == "SalvageModel"),
        {},
    )
    gltf_asset_id = gltf.get("extras", {}).get("ironwright_asset_id") or root_node_extras.get("ironwright_asset_id")
    if gltf_asset_id != manifest["asset_id"]:
        fail("Salvage glTF and manifest asset IDs must match.")
    node_names = {str(node.get("name")) for node in gltf.get("nodes", [])}
    for required in manifest.get("stable_nodes", []):
        if required not in node_names:
            fail(f"Salvage glTF is missing required node: {required}")
    mesh_by_name = {str(mesh.get("name")): mesh for mesh in gltf.get("meshes", [])}
    for mesh_name, minimum_vertices in {"Chassis": 900, "Wheel": 50}.items():
        mesh = mesh_by_name.get(mesh_name)
        if not mesh or not mesh.get("primitives"):
            fail(f"Salvage glTF is missing the {mesh_name} mesh required for close-camera review.")
        position_accessor_index = mesh["primitives"][0].get("attributes", {}).get("POSITION")
        vertex_count = gltf.get("accessors", [])[position_accessor_index].get("count", 0) if position_accessor_index is not None else 0
        if vertex_count < minimum_vertices:
            fail(f"Salvage {mesh_name} mesh must retain at least {minimum_vertices} authored vertices.")


def validate_vehicle_wreck_asset() -> None:
    manifest_path = ROOT / "game/data/vehicle_wreck_asset_manifest.json"
    gltf_path = ROOT / "game/assets/vehicle_wreck/vehicle_wreck.gltf"
    source_path = ROOT / "game/assets/vehicle_wreck/source/build_vehicle_wreck_asset.py"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    gltf = json.loads(gltf_path.read_text(encoding="utf-8"))
    source = source_path.read_text(encoding="utf-8")
    if manifest.get("asset_id") != "vehicle_wreck.civic_shell.v1":
        fail("Vehicle wreck asset manifest has an unexpected stable asset ID.")
    if manifest.get("runtime_scene") != "res://assets/vehicle_wreck/vehicle_wreck.gltf":
        fail("Vehicle wreck asset manifest points at an unexpected runtime model.")
    if "add_ellipsoid" not in source or "add_torus" not in source:
        fail("Vehicle wreck source must retain smooth chassis and wheel-rim geometry.")
    root_node_extras = next(
        (node.get("extras", {}) for node in gltf.get("nodes", []) if node.get("name") == "VehicleWreckModel"),
        {},
    )
    gltf_asset_id = gltf.get("extras", {}).get("ironwright_asset_id") or root_node_extras.get("ironwright_asset_id")
    if gltf_asset_id != manifest["asset_id"]:
        fail("Vehicle wreck glTF and manifest asset IDs must match.")
    node_names = {str(node.get("name")) for node in gltf.get("nodes", [])}
    for required in manifest.get("stable_nodes", []):
        if required not in node_names:
            fail(f"Vehicle wreck glTF is missing required node: {required}")
    mesh_by_name = {str(mesh.get("name")): mesh for mesh in gltf.get("meshes", [])}
    for mesh_name, minimum_vertices in {"Chassis": 900, "Wheel": 60}.items():
        mesh = mesh_by_name.get(mesh_name)
        if not mesh or not mesh.get("primitives"):
            fail(f"Vehicle wreck glTF is missing the {mesh_name} mesh required for close-camera review.")
        position_accessor_index = mesh["primitives"][0].get("attributes", {}).get("POSITION")
        vertex_count = gltf.get("accessors", [])[position_accessor_index].get("count", 0) if position_accessor_index is not None else 0
        if vertex_count < minimum_vertices:
            fail(f"Vehicle wreck {mesh_name} mesh must retain at least {minimum_vertices} authored vertices.")


def _organic_texture_paths() -> dict[str, Path]:
    return {
        role: ROOT / "game/assets/organic_families/textures" / f"organic_{role}.png"
        for role in ORGANIC_TEXTURE_ROLES
    }


def _validate_organic_base_color_signal(path: Path, asset_name: str) -> None:
    grid = _sample_png_scalar_grid(
        path,
        asset_name,
        lambda red, green, blue: (float(red) + float(green) + float(blue)) / 3.0,
    )
    adjacent_differences: list[float] = []
    for row_index, row in enumerate(grid):
        for column_index, value in enumerate(row):
            if column_index > 0:
                adjacent_differences.append(abs(value - row[column_index - 1]))
            if row_index > 0:
                adjacent_differences.append(abs(value - grid[row_index - 1][column_index]))
            if row_index > 0 and column_index > 0:
                adjacent_differences.append(abs(value - grid[row_index - 1][column_index - 1]))
    adjacent_differences.sort()
    difference_count = len(adjacent_differences)
    percentile_95 = adjacent_differences[int((difference_count - 1) * 0.95)]
    percentile_99 = adjacent_differences[int((difference_count - 1) * 0.99)]
    if sum(adjacent_differences) / difference_count > 2.0 or percentile_95 > 5.0 or percentile_99 > 10.0:
        fail(f"{asset_name} contains excessive local contrast that can shimmer at tactical distance.")

    block_size = 32
    block_means = [
        sum(block) / len(block)
        for row_start in range(0, len(grid), block_size)
        for column_start in range(0, len(grid[0]), block_size)
        for block in [[
            grid[row_index][column_index]
            for row_index in range(row_start, min(row_start + block_size, len(grid)))
            for column_index in range(column_start, min(column_start + block_size, len(grid[0])))
        ]]
    ]
    if max(block_means) - min(block_means) < 5.0:
        fail(f"{asset_name} must retain broad-scale authored biological variation.")
    summaries = _representative_texture_frequency_summaries(grid)
    if max(summary[1] for summary in summaries) < 3.0:
        fail(f"{asset_name} must retain visible low-frequency surface form.")
    maximum_alias_peak = max(summary[2] for summary in summaries)
    mean_alias_fraction = sum(summary[3] for summary in summaries) / len(summaries)
    maximum_alias_fraction = max(summary[3] for summary in summaries)
    if maximum_alias_peak > 1.5 or mean_alias_fraction > 0.20 or maximum_alias_fraction > 0.45:
        fail(
            f"{asset_name} contains dense grid or diagonal alias energy: "
            f"peak={maximum_alias_peak:.4f}, mean_fraction={mean_alias_fraction:.4f}, "
            f"max_fraction={maximum_alias_fraction:.4f}."
        )


def _validate_organic_normal_signal(path: Path, asset_name: str) -> None:
    width, height, channels, rows = _decode_png_rows(path, asset_name)
    normal_x: list[float] = []
    normal_y: list[float] = []
    normal_z: list[float] = []
    xy_magnitudes: list[float] = []
    vector_lengths: list[float] = []
    x_grid: list[list[float]] = []
    y_grid: list[list[float]] = []
    neighbor_differences: list[float] = []
    for row_index in range(0, height, 2):
        row = rows[row_index]
        x_row: list[float] = []
        y_row: list[float] = []
        for pixel_index in range(0, width, 2):
            offset = pixel_index * channels
            x_value = row[offset] / 127.5 - 1.0
            y_value = row[offset + 1] / 127.5 - 1.0
            z_value = row[offset + 2] / 127.5 - 1.0
            x_row.append(x_value)
            y_row.append(y_value)
            normal_x.append(x_value)
            normal_y.append(y_value)
            normal_z.append(z_value)
            xy_magnitudes.append(math.hypot(x_value, y_value))
            vector_lengths.append(math.sqrt(x_value * x_value + y_value * y_value + z_value * z_value))
            if len(x_row) > 1:
                neighbor_differences.append(math.hypot(x_value - x_row[-2], y_value - y_row[-2]))
            if x_grid:
                neighbor_differences.append(
                    math.hypot(x_value - x_grid[-1][len(x_row) - 1], y_value - y_grid[-1][len(y_row) - 1])
                )
        x_grid.append(x_row)
        y_grid.append(y_row)
    xy_magnitudes.sort()
    normal_z.sort()
    vector_lengths.sort()
    neighbor_differences.sort()
    percentile = lambda values, fraction: values[int((len(values) - 1) * fraction)]
    sample_count = len(normal_x)
    if abs(sum(normal_x) / sample_count) > 0.02 or abs(sum(normal_y) / sample_count) > 0.02:
        fail(f"{asset_name} must remain centred around neutral tangent-space XY.")
    if (
        sum(normal_z) / sample_count < 0.965
        or percentile(normal_z, 0.05) < 0.93
        or percentile(xy_magnitudes, 0.95) > 0.24
        or xy_magnitudes[-1] > 0.55
        or percentile(vector_lengths, 0.01) < 0.94
        or percentile(vector_lengths, 0.99) > 1.06
    ):
        fail(f"{asset_name} slopes are too strong or poorly normalized for stable tactical-distance shading.")
    if (
        sum(neighbor_differences) / len(neighbor_differences) > 0.02
        or percentile(neighbor_differences, 0.95) > 0.05
    ):
        fail(f"{asset_name} contains adjacent-pixel slope changes that can shimmer or moire.")
    for channel_name, grid in (("X", x_grid), ("Y", y_grid)):
        summaries = _representative_texture_frequency_summaries(grid)
        if max(summary[1] for summary in summaries) < 0.01:
            fail(f"{asset_name} {channel_name} must retain broad low-frequency relief.")
        if (
            max(summary[2] for summary in summaries) > 0.04
            or sum(summary[3] for summary in summaries) / len(summaries) > 0.20
            or max(summary[3] for summary in summaries) > 0.50
        ):
            fail(f"{asset_name} {channel_name} contains excessive high-frequency alias energy.")


def _validate_organic_orm_texture(path: Path, asset_name: str, tissue: bool) -> None:
    width, height, channels, rows = _decode_png_rows(path, asset_name)
    if (width, height) != (1024, 1024) or channels != 4:
        fail(f"{asset_name} must be an exact 1024x1024 RGBA packed ORM texture.")
    ao: list[int] = []
    roughness: list[int] = []
    metallic: list[int] = []
    alpha_values: set[int] = set()
    for row_index in range(0, height, 2):
        row = rows[row_index]
        for pixel_index in range(0, width, 2):
            offset = pixel_index * channels
            ao.append(row[offset])
            roughness.append(row[offset + 1])
            metallic.append(row[offset + 2])
            alpha_values.add(row[offset + 3])
    if alpha_values != {255}:
        fail(f"{asset_name} alpha must remain fully opaque.")
    if max(ao) - min(ao) < 12 or max(roughness) - min(roughness) < 24:
        fail(f"{asset_name} must retain independent occlusion and roughness response.")
    if sum(left != right for left, right in zip(ao, roughness)) / len(ao) < 0.75:
        fail(f"{asset_name} occlusion and roughness channels must not duplicate one another.")
    if max(metallic) > 16:
        fail(f"{asset_name} metallic channel is implausibly strong for organic tissue and shell.")
    minimum_nonmetal_fraction = 0.95 if tissue else 0.90
    if sum(value <= 8 for value in metallic) / len(metallic) < minimum_nonmetal_fraction:
        fail(f"{asset_name} must remain predominantly non-metallic.")


def _validate_organic_emissive_mask(path: Path) -> None:
    width, height, channels, rows = _decode_png_rows(path, "Organic emissive")
    if (width, height) != (1024, 1024) or channels != 4:
        fail("Organic emissive mask must be an exact 1024x1024 RGBA texture.")
    intensities: list[int] = []
    colors: set[int] = set()
    for row_index in range(0, height, 2):
        row = rows[row_index]
        for pixel_index in range(0, width, 2):
            offset = pixel_index * channels
            red, green, blue, alpha = row[offset:offset + 4]
            if red != green or green != blue or alpha != 255:
                fail("Organic emissive must remain a grayscale, fully opaque authored mask.")
            intensities.append(red)
            colors.add(red)
    dark_fraction = sum(value <= 8 for value in intensities) / len(intensities)
    lit_fraction = sum(value >= 48 for value in intensities) / len(intensities)
    if dark_fraction < 0.90 or not (0.005 <= lit_fraction <= 0.08) or max(intensities) < 160 or len(colors) < 64:
        fail(
            "Organic emissive mask must retain sparse, graded living signals without turning the whole body luminous."
        )


def _validate_organic_surface_library() -> dict[str, Path]:
    source_path = ROOT / "game/assets/organic_families/source/build_organic_surface_library.py"
    try:
        source = source_path.read_text(encoding="utf-8")
        ast.parse(source, filename=str(source_path))
    except (OSError, SyntaxError) as error:
        fail(f"Organic surface-library builder is missing or invalid: {error}")
    for forbidden in ("import datetime", "import secrets", "import time", "import uuid", "os.urandom"):
        if forbidden in source:
            fail(f"Organic surface-library builder must remain deterministic; found {forbidden!r}.")
    for required in ("1024", "shared_organic_pbr_v1", *[f"organic_{role}.png" for role in ORGANIC_TEXTURE_ROLES]):
        if required not in source:
            fail(f"Organic surface-library builder is missing frozen contract token {required!r}.")

    texture_paths = _organic_texture_paths()
    if len(set(texture_paths.values())) != len(ORGANIC_TEXTURE_ROLES):
        fail("Organic PBR roles must resolve to seven distinct PNG files.")
    for role, texture_path in texture_paths.items():
        if not texture_path.is_file():
            fail(f"Organic {role} texture is missing: {texture_path.relative_to(ROOT)}")
        width, height, channels, rows = _decode_png_rows(texture_path, f"Organic {role}")
        if (width, height) != (1024, 1024) or channels != 4:
            fail(f"Organic {role} must be an exact 1024x1024 RGBA texture.")
        if any(row[pixel_index * channels + 3] != 255 for row in rows[::8] for pixel_index in range(0, width, 8)):
            fail(f"Organic {role} texture must retain fully opaque sampled alpha.")
    for role in ("shell_base_color", "tissue_base_color"):
        _validate_nonflat_base_color_texture(texture_paths[role], f"Organic {role}")
        _validate_organic_base_color_signal(texture_paths[role], f"Organic {role}")
    for role in ("shell_normal", "tissue_normal"):
        _validate_neutral_blue_normal_texture(texture_paths[role], f"Organic {role}")
        _validate_organic_normal_signal(texture_paths[role], f"Organic {role}")
    _validate_organic_orm_texture(texture_paths["shell_orm"], "Organic shell ORM", False)
    _validate_organic_orm_texture(texture_paths["tissue_orm"], "Organic tissue ORM", True)
    _validate_organic_emissive_mask(texture_paths["emissive"])
    return texture_paths


def _resolve_manifest_resource(raw_path: str) -> Path:
    if raw_path.startswith("res://"):
        return (ROOT / "game" / raw_path.removeprefix("res://")).resolve()
    candidate = Path(raw_path)
    if candidate.is_absolute():
        return candidate.resolve()
    return (ROOT / candidate).resolve()


def _load_gltf_buffer(gltf: dict, gltf_path: Path, asset_name: str) -> bytes:
    buffers = gltf.get("buffers", [])
    if len(buffers) != 1:
        fail(f"{asset_name} glTF must use exactly one inspectable canonical buffer.")
    uri = str(buffers[0].get("uri", ""))
    if uri.startswith("data:"):
        marker = ";base64,"
        if marker not in uri:
            fail(f"{asset_name} embedded buffer must use base64 encoding.")
        try:
            buffer_data = base64.b64decode(uri.split(marker, 1)[1], validate=True)
        except (ValueError, binascii.Error) as error:
            fail(f"{asset_name} embedded buffer is invalid base64: {error}")
    else:
        if not uri:
            fail(f"{asset_name} glTF buffer URI is missing.")
        buffer_path = (gltf_path.parent / uri).resolve()
        try:
            buffer_path.relative_to(gltf_path.parent.resolve())
        except ValueError:
            fail(f"{asset_name} external buffer must remain inside its authored package.")
        if not buffer_path.is_file():
            fail(f"{asset_name} external buffer is missing: {uri}")
        buffer_data = buffer_path.read_bytes()
    if len(buffer_data) != int(buffers[0].get("byteLength", -1)):
        fail(f"{asset_name} canonical buffer length does not match its glTF declaration.")
    return buffer_data


def _read_float_accessor(
    gltf: dict,
    buffer_data: bytes,
    accessor_index: int,
    expected_type: str,
    label: str,
) -> list[tuple[float, ...]]:
    component_counts = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}
    accessors = gltf.get("accessors", [])
    buffer_views = gltf.get("bufferViews", [])
    if not isinstance(accessor_index, int) or not (0 <= accessor_index < len(accessors)):
        fail(f"{label} references an invalid accessor.")
    accessor = accessors[accessor_index]
    if accessor.get("componentType") != 5126 or accessor.get("type") != expected_type or accessor.get("normalized") is True:
        fail(f"{label} must use non-normalized float {expected_type} data.")
    if accessor.get("sparse"):
        fail(f"{label} must remain directly inspectable, not sparse.")
    view_index = accessor.get("bufferView")
    if not isinstance(view_index, int) or not (0 <= view_index < len(buffer_views)):
        fail(f"{label} references an invalid buffer view.")
    view = buffer_views[view_index]
    if int(view.get("buffer", 0)) != 0:
        fail(f"{label} must live in the canonical organic buffer.")
    component_count = component_counts[expected_type]
    element_size = component_count * 4
    stride = int(view.get("byteStride", element_size))
    count = int(accessor.get("count", 0))
    if count <= 0 or stride < element_size or stride % 4 != 0:
        fail(f"{label} has an invalid float accessor count or stride.")
    view_start = int(view.get("byteOffset", 0))
    start = view_start + int(accessor.get("byteOffset", 0))
    view_end = view_start + int(view.get("byteLength", 0))
    final_end = start + (count - 1) * stride + element_size
    if start < view_start or final_end > view_end or final_end > len(buffer_data):
        fail(f"{label} exceeds its declared buffer view.")
    values = [struct.unpack_from(f"<{component_count}f", buffer_data, start + index * stride) for index in range(count)]
    if any(not math.isfinite(component) for value in values for component in value):
        fail(f"{label} contains non-finite authored values.")
    return values


def _read_index_accessor(gltf: dict, buffer_data: bytes, accessor_index: int, label: str) -> list[int]:
    component_formats = {5121: ("B", 1), 5123: ("H", 2), 5125: ("I", 4)}
    accessors = gltf.get("accessors", [])
    buffer_views = gltf.get("bufferViews", [])
    if not isinstance(accessor_index, int) or not (0 <= accessor_index < len(accessors)):
        fail(f"{label} references an invalid index accessor.")
    accessor = accessors[accessor_index]
    component_type = accessor.get("componentType")
    if accessor.get("type") != "SCALAR" or component_type not in component_formats or accessor.get("normalized") is True:
        fail(f"{label} must use an unsigned non-normalized SCALAR index accessor.")
    if accessor.get("sparse"):
        fail(f"{label} indices must remain directly inspectable, not sparse.")
    view_index = accessor.get("bufferView")
    if not isinstance(view_index, int) or not (0 <= view_index < len(buffer_views)):
        fail(f"{label} references an invalid index buffer view.")
    view = buffer_views[view_index]
    if int(view.get("buffer", 0)) != 0:
        fail(f"{label} indices must live in the canonical organic buffer.")
    component_format, component_size = component_formats[component_type]
    stride = int(view.get("byteStride", component_size))
    count = int(accessor.get("count", 0))
    if count <= 0 or stride < component_size:
        fail(f"{label} has an invalid index count or stride.")
    view_start = int(view.get("byteOffset", 0))
    start = view_start + int(accessor.get("byteOffset", 0))
    view_end = view_start + int(view.get("byteLength", 0))
    final_end = start + (count - 1) * stride + component_size
    if start < view_start or final_end > view_end or final_end > len(buffer_data):
        fail(f"{label} exceeds its declared index buffer view.")
    return [struct.unpack_from(f"<{component_format}", buffer_data, start + index * stride)[0] for index in range(count)]


def _organic_manifest_textures(manifest: dict, family: str) -> dict[str, str]:
    declared = manifest.get("textures")
    if isinstance(declared, dict):
        if set(declared) != set(ORGANIC_TEXTURE_ROLES):
            fail(f"{family} manifest must declare exactly the seven shared organic PBR roles.")
        mapping = {role: str(declared[role]) for role in ORGANIC_TEXTURE_ROLES}
    elif isinstance(declared, list):
        expected_paths = [ORGANIC_TEXTURE_URIS[role] for role in ORGANIC_TEXTURE_ROLES]
        if [str(value) for value in declared] != expected_paths:
            fail(f"{family} manifest shared organic texture order drifted.")
        mapping = {role: str(declared[index]) for index, role in enumerate(ORGANIC_TEXTURE_ROLES)}
    else:
        fail(f"{family} manifest must declare its shared organic texture library.")
    if mapping != ORGANIC_TEXTURE_URIS:
        fail(f"{family} manifest points outside the frozen shared organic texture library.")
    return mapping


def _validate_organic_animations(
    family: str,
    gltf: dict,
    buffer_data: bytes,
    node_names: list[str],
    reachable: set[int],
) -> None:
    animations = gltf.get("animations", [])
    animation_names = [str(animation.get("name", "")) for animation in animations]
    if animation_names != ORGANIC_ANIMATION_CLIPS or len(animation_names) != len(set(animation_names)):
        fail(f"{family} glTF must retain exactly the ordered eight organic clips: {animation_names}")
    accessors = gltf.get("accessors", [])
    expected_output_types = {"translation": "VEC3", "rotation": "VEC4", "scale": "VEC3", "weights": "SCALAR"}
    for animation in animations:
        clip_name = str(animation.get("name", "<unnamed>"))
        channels = animation.get("channels", [])
        samplers = animation.get("samplers", [])
        if len(channels) < 2:
            fail(f"{family} {clip_name} must retain at least primary and secondary authored motion.")
        targeted_properties: set[tuple[int, str]] = set()
        clip_ranges: list[tuple[float, float]] = []
        for channel_index, channel in enumerate(channels):
            sampler_index = channel.get("sampler")
            if not isinstance(sampler_index, int) or not (0 <= sampler_index < len(samplers)):
                fail(f"{family} {clip_name} channel {channel_index} references an invalid sampler.")
            sampler = samplers[sampler_index]
            interpolation = str(sampler.get("interpolation", "LINEAR"))
            if interpolation not in {"LINEAR", "STEP", "CUBICSPLINE"}:
                fail(f"{family} {clip_name} uses unsupported interpolation {interpolation!r}.")
            times = _read_float_scalar_accessor(
                gltf,
                buffer_data,
                sampler.get("input"),
                f"{family} {clip_name} channel {channel_index}",
            )
            if not (0.0 <= times[0] <= 0.05) or not (0.08 <= times[-1] - times[0] <= 5.0):
                fail(f"{family} {clip_name} has an implausible authored timing range.")
            clip_ranges.append((times[0], times[-1]))
            target = channel.get("target", {})
            target_node = target.get("node")
            target_path = str(target.get("path", ""))
            if not isinstance(target_node, int) or target_node not in reachable:
                fail(f"{family} {clip_name} targets an invalid or unreachable node.")
            if target_path not in expected_output_types:
                fail(f"{family} {clip_name} has invalid target path {target_path!r}.")
            target_key = (target_node, target_path)
            if target_key in targeted_properties:
                fail(f"{family} {clip_name} duplicates {target_path} on {node_names[target_node]}.")
            targeted_properties.add(target_key)
            output_index = sampler.get("output")
            if not isinstance(output_index, int) or not (0 <= output_index < len(accessors)):
                fail(f"{family} {clip_name} references an invalid output accessor.")
            expected_type = expected_output_types[target_path]
            output_values = _read_float_accessor(
                gltf,
                buffer_data,
                output_index,
                expected_type,
                f"{family} {clip_name} {node_names[target_node]} {target_path}",
            )
            expected_count = len(times) * (3 if interpolation == "CUBICSPLINE" else 1)
            if len(output_values) != expected_count:
                fail(f"{family} {clip_name} output count does not match its timing accessor.")
            if target_path == "rotation":
                rotation_values = output_values[1::3] if interpolation == "CUBICSPLINE" else output_values
                for quaternion in rotation_values:
                    length = math.sqrt(sum(component * component for component in quaternion))
                    if not 0.98 <= length <= 1.02:
                        fail(f"{family} {clip_name} contains a non-unit authored rotation quaternion.")
        if max(start for start, _ in clip_ranges) - min(start for start, _ in clip_ranges) > 1.0e-5:
            fail(f"{family} {clip_name} channels must start together.")
        if max(end for _, end in clip_ranges) - min(end for _, end in clip_ranges) > 1.0e-5:
            fail(f"{family} {clip_name} channels must end together.")


def _validate_skitterling_sensory_geometry(gltf: dict, buffer_data: bytes) -> None:
    """Freeze the compact, torso-flank sensory-skirt contract."""
    nodes = gltf.get("nodes", [])
    meshes = gltf.get("meshes", [])
    accessors = gltf.get("accessors", [])
    node_names = [str(node.get("name", "")) for node in nodes]
    name_to_index = {name: index for index, name in enumerate(node_names)}
    fan_names = [f"SkitterlingSensoryFan{index}" for index in range(4)]
    rib_names = [f"SkitterlingSensoryRib{index}" for index in range(4)]
    if sorted(name for name in node_names if name.startswith("SkitterlingSensoryFan")) != fan_names:
        fail("Skitterling must retain exactly four stable sensory fan nodes.")
    if sorted(name for name in node_names if name.startswith("SkitterlingSensoryRib")) != rib_names:
        fail("Skitterling must retain exactly four stable sensory rib nodes.")
    torso_index = name_to_index.get("Torso")
    if torso_index is None:
        fail("Skitterling sensory validation requires the stable Torso node.")
    torso_children = set(nodes[torso_index].get("children", []))
    for node_name in (*fan_names, *rib_names):
        node_index = name_to_index[node_name]
        if node_index not in torso_children:
            fail(f"{node_name} must remain directly attached to the animated Skitterling Torso.")
        if nodes[node_index].get("extras", {}).get("attachment") != "torso_flank":
            fail(f"{node_name} must declare its torso-flank attachment contract.")

    def mesh_position_size(mesh_name: str) -> tuple[float, float, float]:
        mesh = next((entry for entry in meshes if entry.get("name") == mesh_name), None)
        if not mesh or len(mesh.get("primitives", [])) != 1:
            fail(f"Skitterling {mesh_name} must remain one indexed authored primitive.")
        position_index = mesh["primitives"][0].get("attributes", {}).get("POSITION")
        if not isinstance(position_index, int) or not (0 <= position_index < len(accessors)):
            fail(f"Skitterling {mesh_name} is missing finite POSITION bounds.")
        accessor = accessors[position_index]
        minimum = accessor.get("min", [])
        maximum = accessor.get("max", [])
        if len(minimum) != 3 or len(maximum) != 3:
            fail(f"Skitterling {mesh_name} POSITION bounds are incomplete.")
        return tuple(float(maximum[axis]) - float(minimum[axis]) for axis in range(3))

    fan_size = mesh_position_size("Fan")
    if not (0.26 <= fan_size[0] <= 0.30 and 0.03 <= fan_size[1] <= 0.06 and 0.18 <= fan_size[2] <= 0.22):
        fail(f"Skitterling sensory fan mesh must remain a small broad flank vane, not an upright bar: {fan_size}")
    rib_size = mesh_position_size("SensoryRib")
    if not (0.14 <= rib_size[0] <= 0.18 and rib_size[1] <= 0.035 and 0.03 <= rib_size[2] <= 0.05):
        fail(f"Skitterling sensory rib must remain a shallow lateral shell tie: {rib_size}")

    measured_names = {*fan_names, *rib_names, "OrganicDorsalPlate"}
    measured = _gltf_named_node_bounds(gltf, measured_names, "Skitterling")
    dorsal_top = measured["OrganicDorsalPlate"][1][1]
    for fan_name in fan_names:
        minimum, maximum = measured[fan_name]
        size = tuple(maximum[axis] - minimum[axis] for axis in range(3))
        center = tuple((minimum[axis] + maximum[axis]) * 0.5 for axis in range(3))
        if size[1] > 0.075 or maximum[1] > dorsal_top - 0.20:
            fail(f"{fan_name} must remain materially below the shell crown with no towering vertical extent: min={minimum}, max={maximum}")
        if not (0.34 <= abs(center[0]) <= 0.44 and 0.56 <= center[1] <= 0.66 and -0.34 <= center[2] <= 0.02):
            fail(f"{fan_name} must remain centered on the front/mid torso flank: center={center}")
        if not (0.27 <= size[0] <= 0.32 and 0.19 <= size[2] <= 0.25):
            fail(f"{fan_name} must read as a small horizontal side vane rather than a vertical rod: size={size}")
        fan_matrix = _gltf_node_matrix(nodes[name_to_index[fan_name]])
        if abs(fan_matrix[1][0]) > 1.0e-5:
            fail(f"{fan_name} must retain zero roll so its broad local X axis cannot turn screen-up.")
    for rib_name in rib_names:
        minimum, maximum = measured[rib_name]
        center = tuple((minimum[axis] + maximum[axis]) * 0.5 for axis in range(3))
        if maximum[1] - minimum[1] > 0.04 or maximum[1] > dorsal_top - 0.20:
            fail(f"{rib_name} must remain a flat body-hugging flank tie below the dorsal shell.")
        if not (0.28 <= abs(center[0]) <= 0.36 and 0.54 <= center[1] <= 0.63 and -0.34 <= center[2] <= 0.02):
            fail(f"{rib_name} must remain centered beneath its matching torso-flank vane: center={center}")

    fan_name_set = set(fan_names)
    rib_name_set = set(rib_names)
    animated_fan_clips: set[str] = set()
    for animation in gltf.get("animations", []):
        animation_name = str(animation.get("name", "<unnamed>"))
        fan_targets: set[str] = set()
        for channel in animation.get("channels", []):
            target = channel.get("target", {})
            target_index = target.get("node")
            if not isinstance(target_index, int) or not (0 <= target_index < len(node_names)):
                continue
            target_name = node_names[target_index]
            if target_name in rib_name_set:
                fail(f"Skitterling {animation_name} must not independently animate a flank rib into a detached bar.")
            if target_name not in fan_name_set:
                continue
            if target.get("path") != "rotation":
                fail(f"Skitterling {animation_name} may animate flank vanes only through restrained rotation.")
            fan_targets.add(target_name)
            sampler_index = channel.get("sampler")
            samplers = animation.get("samplers", [])
            if not isinstance(sampler_index, int) or not (0 <= sampler_index < len(samplers)):
                fail(f"Skitterling {animation_name} has an invalid {target_name} animation sampler.")
            output_index = samplers[sampler_index].get("output")
            rotations = _read_float_accessor(
                gltf,
                buffer_data,
                output_index,
                "VEC4",
                f"Skitterling {animation_name} {target_name} rotations",
            )
            fan_node = nodes[target_index]
            mesh_index = fan_node.get("mesh")
            position_index = meshes[mesh_index]["primitives"][0]["attributes"]["POSITION"]
            accessor = accessors[position_index]
            accessor_min = tuple(float(value) for value in accessor["min"])
            accessor_max = tuple(float(value) for value in accessor["max"])
            for key_index, rotation in enumerate(rotations):
                animated_node = dict(fan_node)
                animated_node["rotation"] = list(rotation)
                matrix = _gltf_node_matrix(animated_node)
                if abs(matrix[1][0]) > 1.0e-4:
                    fail(f"Skitterling {animation_name} {target_name} key {key_index} introduces roll and may turn the vane into a vertical bar.")
                transformed = [
                    _transform_point(
                        matrix,
                        tuple(accessor_max[axis] if corner & (1 << axis) else accessor_min[axis] for axis in range(3)),
                    )
                    for corner in range(8)
                ]
                minimum_y = min(point[1] for point in transformed)
                maximum_y = max(point[1] for point in transformed)
                if maximum_y - minimum_y > 0.075 or maximum_y > dorsal_top - 0.20:
                    fail(f"Skitterling {animation_name} {target_name} key {key_index} leaves the compact flank envelope.")
        if fan_targets:
            animated_fan_clips.add(animation_name)
            if fan_targets != fan_name_set:
                fail(f"Skitterling {animation_name} must animate all four flank vanes together or none of them.")
    if animated_fan_clips != {"Idle", "Walk", "Attack", "Feed", "Nest", "Retreat"}:
        fail(f"Skitterling flank-vane motion contract drifted: {sorted(animated_fan_clips)}")


def validate_authored_organic_assets() -> None:
    texture_paths = _validate_organic_surface_library()
    texture_hashes = {role: hashlib.sha256(path.read_bytes()).hexdigest().upper() for role, path in texture_paths.items()}
    expected_image_uris = set(ORGANIC_IMAGE_URIS)
    for family, expected in AUTHORED_ORGANIC_ASSETS.items():
        manifest_path = ROOT / f"game/data/{family}_asset_manifest.json"
        gltf_path = ROOT / f"game/assets/{family}/{family}.gltf"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        gltf = json.loads(gltf_path.read_text(encoding="utf-8"))
        asset_name = family.capitalize()
        runtime_path = manifest.get("runtime_model") or manifest.get("runtime_path")
        expected_runtime_path = f"res://assets/{family}/{family}.gltf"
        if manifest.get("asset_id") != expected["asset_id"]:
            fail(f"{family} asset manifest has an unexpected stable asset ID.")
        if runtime_path != expected_runtime_path:
            fail(f"{family} asset manifest points at an unexpected runtime model.")
        if (manifest.get("asset_quality") or manifest.get("quality")) != "authored_high_definition":
            fail(f"{family} organic asset must retain authored high-definition quality.")
        if manifest.get("texture_resolution") != 1024:
            fail(f"{family} organic asset must declare the shared 1024px texture contract.")
        if manifest.get("material_workflow") != "metallic_roughness_pbr":
            fail(f"{family} organic asset must declare metallic-roughness PBR.")
        if manifest.get("surface_profile") != "shared_organic_pbr_v1":
            fail(f"{family} organic surface profile drifted from shared_organic_pbr_v1.")
        if manifest.get("presentation_only") is not True or manifest.get("collision") is not False:
            fail(f"{family} authored package must remain presentation-only and collision-free.")
        if manifest.get("gameplay_state") != "none" or manifest.get("deterministic_build") is not True:
            fail(f"{family} authored package must own no gameplay state and remain deterministic.")
        if manifest.get("third_party_assets", []) != [] or int(manifest.get("skins", 0)) != 0:
            fail(f"{family} authored package must remain original project art with zero skins.")
        if set(str(value) for value in manifest.get("required_accessors", [])) < {"POSITION", "NORMAL", "TEXCOORD_0", "TANGENT"}:
            fail(f"{family} manifest must require position, normal, UV0 and tangent accessors.")
        if manifest.get("unique_node_names") is not True:
            fail(f"{family} manifest must freeze globally unique node names.")
        if [str(value) for value in manifest.get("animation_clips", [])] != ORGANIC_ANIMATION_CLIPS:
            fail(f"{family} manifest animation contract drifted from the canonical eight clips.")
        _organic_manifest_textures(manifest, family)

        source_raw = str(manifest.get("source_builder") or manifest.get("source") or "")
        source_path = _resolve_manifest_resource(source_raw)
        if not source_path.is_file():
            fail(f"{family} source builder is missing: {source_raw}")
        try:
            ast.parse(source_path.read_text(encoding="utf-8"), filename=str(source_path))
        except SyntaxError as error:
            fail(f"{family} source builder is not valid Python: {error}")
        artifact_hashes = manifest.get("artifact_hashes", {})
        if str(artifact_hashes.get("source_builder_sha256", "")).upper() != hashlib.sha256(source_path.read_bytes()).hexdigest().upper():
            fail(f"{family} source-builder hash does not match the authored source.")
        if str(artifact_hashes.get("runtime_model_sha256", "")).upper() != hashlib.sha256(gltf_path.read_bytes()).hexdigest().upper():
            fail(f"{family} runtime-model hash does not match the authored glTF.")
        declared_texture_hashes = manifest.get("texture_hashes", {})
        for role, current_hash in texture_hashes.items():
            declared_hash = artifact_hashes.get(f"{role}_sha256")
            if declared_hash is None:
                declared_hash = declared_texture_hashes.get(f"organic_{role}.png")
            if str(declared_hash or "").upper() != current_hash:
                fail(f"{family} {role} hash does not match the frozen shared texture library.")

        extras = gltf.get("extras", {})
        root_node_extras = next(
            (node.get("extras", {}) for node in gltf.get("nodes", []) if node.get("name") == expected["root"]),
            {},
        )
        gltf_asset_id = extras.get("ironwright_asset_id") or root_node_extras.get("ironwright_asset_id")
        if gltf_asset_id != expected["asset_id"]:
            fail(f"{family} glTF and manifest asset IDs must match.")
        if extras.get("surface_profile") != "shared_organic_pbr_v1":
            fail(f"{family} glTF must embed the shared organic surface profile.")

        images = gltf.get("images", [])
        image_uris = [str(image.get("uri", "")) for image in images]
        if len(image_uris) != 7 or len(set(image_uris)) != 7 or set(image_uris) != expected_image_uris:
            fail(f"{family} glTF must reference exactly the seven shared organic PNGs.")
        for image in images:
            image_path = _gltf_image_path(gltf_path, image, asset_name)
            if image_path not in texture_paths.values():
                fail(f"{family} glTF image points outside the shared organic texture library.")
        textures = gltf.get("textures", [])
        if len(textures) != 7 or sorted(texture.get("source") for texture in textures) != list(range(7)):
            fail(f"{family} glTF must expose one texture binding per shared organic image.")
        samplers = gltf.get("samplers", [])
        if not samplers:
            fail(f"{family} glTF is missing its repeat/trilinear texture sampler.")
        for texture in textures:
            sampler_index = texture.get("sampler", 0)
            if not isinstance(sampler_index, int) or not (0 <= sampler_index < len(samplers)):
                fail(f"{family} glTF texture references an invalid sampler.")
            sampler = samplers[sampler_index]
            if sampler.get("magFilter") != 9729 or sampler.get("minFilter") != 9987:
                fail(f"{family} organic sampler must retain linear/trilinear filtering.")
            if sampler.get("wrapS") != 10497 or sampler.get("wrapT") != 10497:
                fail(f"{family} organic sampler must retain repeat wrapping for authored UVs.")
        image_source_by_uri = {uri: index for index, uri in enumerate(image_uris)}

        materials = gltf.get("materials", [])
        material_names = [str(material.get("name", "")) for material in materials]
        if not (6 <= len(materials) <= 9) or len(material_names) != len(set(material_names)) or "" in material_names:
            fail(f"{family} glTF must retain six to nine uniquely named biological PBR materials.")
        if material_names != [str(value) for value in manifest.get("material_names", [])]:
            fail(f"{family} manifest material order does not match the glTF package.")
        emissive_materials = {str(value) for value in manifest.get("emissive_materials", [])}
        if not (1 <= len(emissive_materials) <= 3) or not emissive_materials <= set(material_names):
            fail(f"{family} must declare one to three restrained living signal materials.")
        for material in materials:
            material_name = str(material.get("name"))
            pbr = material.get("pbrMetallicRoughness", {})
            base_source = _material_texture_source(gltf, material, "pbrMetallicRoughness", "baseColorTexture")
            base_uri = image_uris[base_source] if 0 <= base_source < len(image_uris) else ""
            if base_uri == ORGANIC_IMAGE_URIS[0]:
                lane = "shell"
                normal_uri = ORGANIC_IMAGE_URIS[1]
                orm_uri = ORGANIC_IMAGE_URIS[2]
                maximum_normal_scale = 0.35
            elif base_uri == ORGANIC_IMAGE_URIS[3]:
                lane = "tissue"
                normal_uri = ORGANIC_IMAGE_URIS[4]
                orm_uri = ORGANIC_IMAGE_URIS[5]
                maximum_normal_scale = 0.20
            else:
                fail(f"{family} material {material_name} must use the shared shell or tissue base color.")
            if _material_texture_source(gltf, material, "normalTexture") != image_source_by_uri[normal_uri]:
                fail(f"{family} material {material_name} normal map does not match its {lane} lane.")
            if _material_texture_source(gltf, material, "pbrMetallicRoughness", "metallicRoughnessTexture") != image_source_by_uri[orm_uri]:
                fail(f"{family} material {material_name} ORM map does not match its {lane} lane.")
            if _material_texture_source(gltf, material, "occlusionTexture") != image_source_by_uri[orm_uri]:
                fail(f"{family} material {material_name} must wire occlusion to its packed ORM map.")
            normal_scale = float(material.get("normalTexture", {}).get("scale", 1.0))
            if material_name in emissive_materials:
                maximum_normal_scale = min(maximum_normal_scale, 0.10)
            if not 0.0 < normal_scale <= maximum_normal_scale + 1.0e-6:
                fail(f"{family} material {material_name} normal scale is unstable for the {lane} surface lane.")
            base_factor = pbr.get("baseColorFactor", [])
            if not isinstance(base_factor, list) or len(base_factor) != 4 or any(not 0.0 <= float(value) <= 1.0 for value in base_factor):
                fail(f"{family} material {material_name} has an invalid base-color factor.")
            for scalar_name in ("metallicFactor", "roughnessFactor"):
                scalar = float(pbr.get(scalar_name, 1.0))
                if not 0.0 <= scalar <= 1.0:
                    fail(f"{family} material {material_name} has invalid {scalar_name}.")
            material_extras = material.get("extras", {})
            declared_profile = material_extras.get("surface_profile") or material_extras.get("ironwright_surface_profile")
            if declared_profile not in {None, "shared_organic_pbr_v1"}:
                fail(f"{family} material {material_name} declares an unexpected surface profile.")
            if material_name in emissive_materials:
                if _material_texture_source(gltf, material, "emissiveTexture") != image_source_by_uri[ORGANIC_IMAGE_URIS[6]]:
                    fail(f"{family} signal material {material_name} must use the shared emissive mask.")
                emissive_factor = material.get("emissiveFactor", [])
                if (
                    not isinstance(emissive_factor, list)
                    or len(emissive_factor) != 3
                    or max(float(value) for value in emissive_factor) <= 0.0
                    or any(not 0.0 <= float(value) <= 1.0 for value in emissive_factor)
                ):
                    fail(f"{family} signal material {material_name} must retain a positive core-glTF-range emissive tint.")
            else:
                if "emissiveTexture" in material or any(float(value) > 0.0 for value in material.get("emissiveFactor", [0.0, 0.0, 0.0])):
                    fail(f"{family} non-signal material {material_name} must not glow.")

        nodes = gltf.get("nodes", [])
        node_names = [str(node.get("name", "")) for node in nodes]
        duplicate_names = sorted(name for name, count in Counter(node_names).items() if not name or count != 1)
        if duplicate_names:
            fail(f"{family} glTF node names must be non-empty and globally unique: {duplicate_names}")
        required_nodes = set(str(value) for value in expected["required"])
        required_nodes.update(str(value) for value in manifest.get("required_nodes", []))
        required_nodes.update(str(value) for value in manifest.get("stable_nodes", []))
        missing_nodes = sorted(required_nodes - set(node_names))
        if missing_nodes:
            fail(f"{family} glTF is missing required source-owned nodes: {missing_nodes}")
        scenes = gltf.get("scenes", [])
        scene_index = gltf.get("scene", 0)
        if not isinstance(scene_index, int) or not (0 <= scene_index < len(scenes)):
            fail(f"{family} glTF must declare a valid default scene.")
        root_indices = scenes[scene_index].get("nodes", [])
        if len(root_indices) != 1 or node_names[root_indices[0]] != expected["root"]:
            fail(f"{family} glTF default scene must expose exactly its stable authored root.")
        parent_counts = [0] * len(nodes)
        for node_index, node in enumerate(nodes):
            for child_index in node.get("children", []):
                if not isinstance(child_index, int) or not (0 <= child_index < len(nodes)):
                    fail(f"{family} node {node_names[node_index]} references an invalid child.")
                parent_counts[child_index] += 1
        reachable: set[int] = set()
        active: set[int] = set()
        def visit(node_index: int) -> None:
            if node_index in active:
                fail(f"{family} glTF hierarchy contains a cycle.")
            if node_index in reachable:
                return
            active.add(node_index)
            reachable.add(node_index)
            for child_index in nodes[node_index].get("children", []):
                visit(child_index)
            active.remove(node_index)
        visit(root_indices[0])
        if len(reachable) != len(nodes):
            fail(f"{family} glTF contains unreachable authored nodes.")
        for node_index, parent_count in enumerate(parent_counts):
            expected_parent_count = 0 if node_index == root_indices[0] else 1
            if parent_count != expected_parent_count:
                fail(f"{family} node {node_names[node_index]} has {parent_count} parents instead of {expected_parent_count}.")
        if gltf.get("skins") or gltf.get("cameras") or "KHR_lights_punctual" in gltf.get("extensionsUsed", []):
            fail(f"{family} authored presentation package must contain no skins, cameras or lights.")

        buffer_data = _load_gltf_buffer(gltf, gltf_path, asset_name)
        accessors = gltf.get("accessors", [])
        primitive_count = 0
        vertex_count = 0
        triangle_count = 0
        for mesh_index, mesh in enumerate(gltf.get("meshes", [])):
            for primitive_index, primitive in enumerate(mesh.get("primitives", [])):
                primitive_count += 1
                label = f"{family} {mesh.get('name', mesh_index)} primitive {primitive_index}"
                if primitive.get("mode", 4) != 4:
                    fail(f"{label} must remain an indexed triangle list.")
                attributes = primitive.get("attributes", {})
                values_by_semantic: dict[str, list[tuple[float, ...]]] = {}
                for semantic, accessor_type in (("POSITION", "VEC3"), ("NORMAL", "VEC3"), ("TEXCOORD_0", "VEC2"), ("TANGENT", "VEC4")):
                    values_by_semantic[semantic] = _read_float_accessor(
                        gltf,
                        buffer_data,
                        attributes.get(semantic),
                        accessor_type,
                        f"{label} {semantic}",
                    )
                counts = {len(values) for values in values_by_semantic.values()}
                if len(counts) != 1:
                    fail(f"{label} POSITION, NORMAL, UV0 and TANGENT counts must match.")
                primitive_vertices = len(values_by_semantic["POSITION"])
                vertex_count += primitive_vertices
                position_accessor = accessors[attributes["POSITION"]]
                if not _valid_vec3_bounds(position_accessor.get("min"), position_accessor.get("max")):
                    fail(f"{label} POSITION accessor must retain finite explicit bounds.")
                for normal, tangent, uv in zip(
                    values_by_semantic["NORMAL"],
                    values_by_semantic["TANGENT"],
                    values_by_semantic["TEXCOORD_0"],
                ):
                    normal_length = math.sqrt(sum(component * component for component in normal))
                    tangent_length = math.sqrt(sum(component * component for component in tangent[:3]))
                    tangent_dot = sum(normal[index] * tangent[index] for index in range(3))
                    if not 0.97 <= normal_length <= 1.03 or not 0.97 <= tangent_length <= 1.03:
                        fail(f"{label} contains non-unit normals or tangents.")
                    if abs(tangent_dot) > 0.03 or abs(abs(tangent[3]) - 1.0) > 1.0e-4:
                        fail(f"{label} tangent basis is not orthogonal and handed.")
                    if any(abs(component) > 128.0 for component in uv):
                        fail(f"{label} contains an implausible authored UV coordinate.")
                indices = _read_index_accessor(gltf, buffer_data, primitive.get("indices"), f"{label} indices")
                if len(indices) % 3 != 0 or min(indices) < 0 or max(indices) >= primitive_vertices:
                    fail(f"{label} indices do not form valid triangles over the authored vertices.")
                triangle_count += len(indices) // 3
                material_index = primitive.get("material")
                if not isinstance(material_index, int) or not (0 <= material_index < len(materials)):
                    fail(f"{label} must retain a valid authored PBR material.")
        if primitive_count == 0:
            fail(f"{family} glTF contains no authored primitives.")
        metrics = manifest.get("geometry_metrics", {})
        metric_expectations = {
            "nodes": len(nodes),
            "meshes": len(gltf.get("meshes", [])),
            "primitives": primitive_count,
            "vertices": vertex_count,
            "triangles": triangle_count,
        }
        alternate_metric_names = {
            "nodes": "node_count",
            "meshes": "mesh_count",
            "primitives": "primitive_count",
            "vertices": "vertex_count",
            "triangles": "triangle_count",
        }
        for metric_name, actual_value in metric_expectations.items():
            declared_value = metrics.get(metric_name, metrics.get(alternate_metric_names[metric_name]))
            if int(declared_value if declared_value is not None else -1) != actual_value:
                fail(f"{family} manifest {metric_name} metric does not match its authored glTF.")

        measured_min, measured_max = _gltf_aggregate_bounds(gltf)
        manifest_bounds = manifest.get("aggregate_bounds", {})
        _require_close_vector(manifest_bounds.get("min"), measured_min, 5.0e-4, f"{family} manifest minimum bounds")
        _require_close_vector(manifest_bounds.get("max"), measured_max, 5.0e-4, f"{family} manifest maximum bounds")
        frozen_min, frozen_max = ORGANIC_FROZEN_BOUNDS[family]
        _require_close_vector(measured_min, tuple(frozen_min), 5.0e-4, f"{family} frozen minimum bounds")
        _require_close_vector(measured_max, tuple(frozen_max), 5.0e-4, f"{family} frozen maximum bounds")
        if family == "skitterling":
            _validate_skitterling_sensory_geometry(gltf, buffer_data)

        if family in SHARED_AUTHORED_ORGANIC_FAMILIES:
            family_prefix = expected["root"].removesuffix("Model")
            surface_veins = [name for name in node_names if name.startswith(f"{family_prefix}TorsoSurfaceVein")]
            if len(surface_veins) < 8:
                fail(f"{family} glTF must retain at least eight paired authored torso surface veins.")
            source_owned_finish = {"OrganicPulseRim", "OrganicGrowthPlate", "OrganicVascularVeinL", "OrganicVascularVeinR"}
            if not source_owned_finish <= set(node_names) or "OrganicFamilyAnatomyFinish" in node_names:
                fail(f"{family} must directly own its living anatomy without the former runtime finish wrapper.")
        _validate_organic_animations(family, gltf, buffer_data, node_names, reachable)


def validate_early_organic_materials() -> None:
    for family in EARLY_ORGANIC_MATERIAL_FAMILIES:
        gltf_path = ROOT / f"game/assets/{family}/{family}.gltf"
        gltf = json.loads(gltf_path.read_text(encoding="utf-8"))
        materials = gltf.get("materials", [])
        if len(materials) < 2:
            fail(f"{family} glTF must expose a wet base and a structural shell material.")
        shell_factor = materials[1].get("pbrMetallicRoughness", {}).get("baseColorFactor", [])
        if len(shell_factor) < 3 or max(float(channel) for channel in shell_factor[:3]) < 0.24:
            fail(f"{family} structural shell material is too dark for compact tactical review.")


def validate_sporecaster_gill_finish() -> None:
    source_path = ROOT / "game/assets/sporecaster/source/build_sporecaster_asset.py"
    source_text = source_path.read_text(encoding="utf-8")
    if "rounded, scalloped vertical gill" not in source_text or "math.cos(5.0 * angle)" not in source_text:
        fail("sporecaster source builder must retain a scalloped living edge on its close-camera gills.")
    gltf_path = ROOT / "game/assets/sporecaster/sporecaster.gltf"
    gltf = json.loads(gltf_path.read_text(encoding="utf-8"))
    gill = next((mesh for mesh in gltf.get("meshes", []) if mesh.get("name") == "Gill"), None)
    if not gill or not gill.get("primitives"):
        fail("sporecaster glTF is missing the authored Gill mesh required for close-camera review.")
    position_index = gill["primitives"][0].get("attributes", {}).get("POSITION")
    accessors = gltf.get("accessors", [])
    vertex_count = int(accessors[position_index].get("count", 0)) if isinstance(position_index, int) and position_index < len(accessors) else 0
    if vertex_count < 600:
        fail(f"sporecaster Gill mesh must retain dense authored geometry: {vertex_count} POSITION vertices < 600.")


def _resolve_authored_texture_path(raw_path: str, package_name: str) -> Path:
    if raw_path.startswith("res://"):
        return (ROOT / "game" / raw_path.removeprefix("res://")).resolve()
    candidate = Path(raw_path)
    if candidate.is_absolute():
        return candidate.resolve()
    if candidate.parts and candidate.parts[0] == "game":
        return (ROOT / candidate).resolve()
    return (ROOT / "game/assets" / package_name / candidate).resolve()


def _resolve_bulwark_texture_path(raw_path: str) -> Path:
    return _resolve_authored_texture_path(raw_path, "bulwark")


def _require_close_vector(
    actual: object,
    expected: tuple[float, ...],
    tolerance: float,
    label: str,
) -> None:
    if not isinstance(actual, (list, tuple)) or len(actual) != len(expected):
        fail(f"{label} must contain exactly {len(expected)} numeric components.")
    try:
        actual_values = tuple(float(component) for component in actual)
    except (TypeError, ValueError):
        fail(f"{label} must contain only numeric components.")
    if any(abs(actual_values[index] - expected[index]) > tolerance for index in range(len(expected))):
        fail(f"{label} drifted: expected {expected}, got {actual_values}.")


def _require_close_quaternion(
    actual: object,
    expected: tuple[float, float, float, float],
    tolerance: float,
    label: str,
) -> None:
    if not isinstance(actual, list) or len(actual) != 4:
        fail(f"{label} must contain exactly four numeric components.")
    try:
        actual_values = tuple(float(component) for component in actual)
    except (TypeError, ValueError):
        fail(f"{label} must contain only numeric components.")
    direct_error = max(abs(actual_values[index] - expected[index]) for index in range(4))
    inverse_error = max(abs(actual_values[index] + expected[index]) for index in range(4))
    if min(direct_error, inverse_error) > tolerance:
        fail(f"{label} drifted: expected {expected} (or its equivalent negation), got {actual_values}.")


def _require_rotated_node(node: dict, label: str) -> None:
    rotation = node.get("rotation")
    if not isinstance(rotation, list) or len(rotation) != 4:
        fail(f"{label} must retain an explicit quaternion rotation.")
    try:
        quaternion = tuple(float(component) for component in rotation)
    except (TypeError, ValueError):
        fail(f"{label} rotation must contain only numeric components.")
    length_squared = sum(component * component for component in quaternion)
    if abs(length_squared - 1.0) > 1.0e-5:
        fail(f"{label} rotation must remain a normalized quaternion.")
    identity_error = min(
        max(abs(quaternion[index] - (0.0, 0.0, 0.0, 1.0)[index]) for index in range(4)),
        max(abs(quaternion[index] + (0.0, 0.0, 0.0, 1.0)[index]) for index in range(4)),
    )
    if identity_error <= 1.0e-6:
        fail(f"{label} must retain its authored non-identity orientation.")


def _matrix_multiply(left: list[list[float]], right: list[list[float]]) -> list[list[float]]:
    return [
        [sum(left[row][inner] * right[inner][column] for inner in range(4)) for column in range(4)]
        for row in range(4)
    ]


def _gltf_node_matrix(node: dict) -> list[list[float]]:
    raw_matrix = node.get("matrix")
    if isinstance(raw_matrix, list):
        if len(raw_matrix) != 16:
            fail(f"Heartforge node {node.get('name', '<unnamed>')} has an invalid transform matrix.")
        # glTF stores matrices column-major; the validator uses row-major lists.
        return [[float(raw_matrix[column * 4 + row]) for column in range(4)] for row in range(4)]

    translation = node.get("translation", [0.0, 0.0, 0.0])
    rotation = node.get("rotation", [0.0, 0.0, 0.0, 1.0])
    scale = node.get("scale", [1.0, 1.0, 1.0])
    if not isinstance(translation, list) or len(translation) != 3:
        fail(f"Heartforge node {node.get('name', '<unnamed>')} has an invalid translation.")
    if not isinstance(rotation, list) or len(rotation) != 4:
        fail(f"Heartforge node {node.get('name', '<unnamed>')} has an invalid rotation.")
    if not isinstance(scale, list) or len(scale) != 3:
        fail(f"Heartforge node {node.get('name', '<unnamed>')} has an invalid scale.")
    tx, ty, tz = (float(component) for component in translation)
    x, y, z, w = (float(component) for component in rotation)
    sx, sy, sz = (float(component) for component in scale)
    rotation_matrix = [
        [1.0 - 2.0 * (y * y + z * z), 2.0 * (x * y - z * w), 2.0 * (x * z + y * w), 0.0],
        [2.0 * (x * y + z * w), 1.0 - 2.0 * (x * x + z * z), 2.0 * (y * z - x * w), 0.0],
        [2.0 * (x * z - y * w), 2.0 * (y * z + x * w), 1.0 - 2.0 * (x * x + y * y), 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ]
    scale_matrix = [
        [sx, 0.0, 0.0, 0.0],
        [0.0, sy, 0.0, 0.0],
        [0.0, 0.0, sz, 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ]
    result = _matrix_multiply(rotation_matrix, scale_matrix)
    result[0][3] = tx
    result[1][3] = ty
    result[2][3] = tz
    return result


def _transform_point(matrix: list[list[float]], point: tuple[float, float, float]) -> tuple[float, float, float]:
    homogeneous = (*point, 1.0)
    return tuple(sum(matrix[row][column] * homogeneous[column] for column in range(4)) for row in range(3))


def _gltf_aggregate_bounds(gltf: dict) -> tuple[tuple[float, float, float], tuple[float, float, float]]:
    nodes = gltf.get("nodes", [])
    meshes = gltf.get("meshes", [])
    accessors = gltf.get("accessors", [])
    scenes = gltf.get("scenes", [])
    scene_index = gltf.get("scene", 0)
    if not isinstance(scene_index, int) or not (0 <= scene_index < len(scenes)):
        fail("Heartforge glTF must name a valid default scene for aggregate-bounds validation.")
    root_indices = scenes[scene_index].get("nodes", [])
    if not isinstance(root_indices, list) or not root_indices:
        fail("Heartforge glTF default scene must contain an authored root node.")

    identity = [
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ]
    bounds_min = [math.inf, math.inf, math.inf]
    bounds_max = [-math.inf, -math.inf, -math.inf]
    primitive_count = 0
    active_nodes: set[int] = set()

    def visit(node_index: int, parent_matrix: list[list[float]]) -> None:
        nonlocal primitive_count
        if not isinstance(node_index, int) or not (0 <= node_index < len(nodes)):
            fail("Heartforge glTF scene graph contains an invalid node index.")
        if node_index in active_nodes:
            fail("Heartforge glTF scene graph contains a cycle.")
        active_nodes.add(node_index)
        node = nodes[node_index]
        world_matrix = _matrix_multiply(parent_matrix, _gltf_node_matrix(node))
        mesh_index = node.get("mesh")
        if mesh_index is not None:
            if not isinstance(mesh_index, int) or not (0 <= mesh_index < len(meshes)):
                fail(f"Heartforge node {node.get('name', '<unnamed>')} references an invalid mesh.")
            for primitive in meshes[mesh_index].get("primitives", []):
                primitive_count += 1
                position_index = primitive.get("attributes", {}).get("POSITION")
                if not isinstance(position_index, int) or not (0 <= position_index < len(accessors)):
                    fail(f"Heartforge node {node.get('name', '<unnamed>')} cannot contribute aggregate bounds without POSITION.")
                accessor = accessors[position_index]
                accessor_min = accessor.get("min")
                accessor_max = accessor.get("max")
                if not isinstance(accessor_min, list) or not isinstance(accessor_max, list) or len(accessor_min) != 3 or len(accessor_max) != 3:
                    fail(f"Heartforge mesh {meshes[mesh_index].get('name', '<unnamed>')} must preserve explicit POSITION bounds.")
                for corner_index in range(8):
                    corner = tuple(
                        float(accessor_max[axis] if corner_index & (1 << axis) else accessor_min[axis])
                        for axis in range(3)
                    )
                    transformed = _transform_point(world_matrix, corner)
                    for axis in range(3):
                        bounds_min[axis] = min(bounds_min[axis], transformed[axis])
                        bounds_max[axis] = max(bounds_max[axis], transformed[axis])
        for child_index in node.get("children", []):
            visit(child_index, world_matrix)
        active_nodes.remove(node_index)

    for root_index in root_indices:
        visit(root_index, identity)
    if primitive_count == 0:
        fail("Heartforge glTF default scene contains no authored primitives for aggregate-bounds validation.")
    return tuple(bounds_min), tuple(bounds_max)


def _gltf_named_node_bounds(
    gltf: dict,
    target_names: set[str],
    asset_name: str,
) -> dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]]:
    nodes = gltf.get("nodes", [])
    meshes = gltf.get("meshes", [])
    accessors = gltf.get("accessors", [])
    scenes = gltf.get("scenes", [])
    scene_index = gltf.get("scene", 0)
    if not isinstance(scene_index, int) or not (0 <= scene_index < len(scenes)):
        fail(f"{asset_name} glTF must name a valid default scene for measured-clearance validation.")
    root_indices = scenes[scene_index].get("nodes", [])
    if not isinstance(root_indices, list) or not root_indices:
        fail(f"{asset_name} glTF default scene must contain an authored root node.")

    identity = [
        [1.0, 0.0, 0.0, 0.0],
        [0.0, 1.0, 0.0, 0.0],
        [0.0, 0.0, 1.0, 0.0],
        [0.0, 0.0, 0.0, 1.0],
    ]
    measured = {
        name: ([math.inf, math.inf, math.inf], [-math.inf, -math.inf, -math.inf], 0)
        for name in target_names
    }
    active_nodes: set[int] = set()

    def visit(node_index: int, parent_matrix: list[list[float]]) -> None:
        if not isinstance(node_index, int) or not (0 <= node_index < len(nodes)):
            fail(f"{asset_name} glTF scene graph contains an invalid node index.")
        if node_index in active_nodes:
            fail(f"{asset_name} glTF scene graph contains a cycle.")
        active_nodes.add(node_index)
        node = nodes[node_index]
        world_matrix = _matrix_multiply(parent_matrix, _gltf_node_matrix(node))
        node_name = str(node.get("name", ""))
        mesh_index = node.get("mesh")
        if node_name in measured:
            if not isinstance(mesh_index, int) or not (0 <= mesh_index < len(meshes)):
                fail(f"{asset_name} measured node {node_name} must own an authored mesh.")
            node_min, node_max, primitive_count = measured[node_name]
            for primitive in meshes[mesh_index].get("primitives", []):
                position_index = primitive.get("attributes", {}).get("POSITION")
                if not isinstance(position_index, int) or not (0 <= position_index < len(accessors)):
                    fail(f"{asset_name} measured node {node_name} is missing POSITION bounds.")
                accessor = accessors[position_index]
                accessor_min = accessor.get("min")
                accessor_max = accessor.get("max")
                if (
                    not isinstance(accessor_min, list)
                    or not isinstance(accessor_max, list)
                    or len(accessor_min) != 3
                    or len(accessor_max) != 3
                ):
                    fail(f"{asset_name} measured node {node_name} must preserve explicit POSITION bounds.")
                primitive_count += 1
                for corner_index in range(8):
                    corner = tuple(
                        float(accessor_max[axis] if corner_index & (1 << axis) else accessor_min[axis])
                        for axis in range(3)
                    )
                    transformed = _transform_point(world_matrix, corner)
                    for axis in range(3):
                        node_min[axis] = min(node_min[axis], transformed[axis])
                        node_max[axis] = max(node_max[axis], transformed[axis])
            measured[node_name] = (node_min, node_max, primitive_count)
        for child_index in node.get("children", []):
            visit(child_index, world_matrix)
        active_nodes.remove(node_index)

    for root_index in root_indices:
        visit(root_index, identity)

    result: dict[str, tuple[tuple[float, float, float], tuple[float, float, float]]] = {}
    for node_name, (node_min, node_max, primitive_count) in measured.items():
        if primitive_count == 0:
            fail(f"{asset_name} measured node {node_name} contains no authored primitives.")
        result[node_name] = (tuple(node_min), tuple(node_max))
    return result


def _decode_png_rows(path: Path, asset_name: str = "Bulwark") -> tuple[int, int, int, list[bytes]]:
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        fail(f"{asset_name} texture is not a valid PNG: {path.relative_to(ROOT)}")
    offset = 8
    width = height = bit_depth = color_type = interlace = -1
    compressed = bytearray()
    while offset + 12 <= len(data):
        chunk_length = struct.unpack(">I", data[offset:offset + 4])[0]
        chunk_type = data[offset + 4:offset + 8]
        chunk_start = offset + 8
        chunk_end = chunk_start + chunk_length
        if chunk_end + 4 > len(data):
            fail(f"{asset_name} PNG has a truncated {chunk_type!r} chunk: {path.relative_to(ROOT)}")
        chunk_data = data[chunk_start:chunk_end]
        expected_crc = struct.unpack(">I", data[chunk_end:chunk_end + 4])[0]
        actual_crc = zlib.crc32(chunk_type + chunk_data) & 0xFFFFFFFF
        if expected_crc != actual_crc:
            fail(f"{asset_name} PNG has a corrupt {chunk_type!r} chunk: {path.relative_to(ROOT)}")
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(">IIBBBBB", chunk_data)
            if compression != 0 or filtering != 0:
                fail(f"{asset_name} PNG uses unsupported compression or filtering: {path.relative_to(ROOT)}")
        elif chunk_type == b"IDAT":
            compressed.extend(chunk_data)
        elif chunk_type == b"IEND":
            break
        offset = chunk_end + 4
    if width <= 0 or height <= 0 or not compressed:
        fail(f"{asset_name} PNG is missing IHDR or image data: {path.relative_to(ROOT)}")
    if bit_depth != 8 or color_type not in {2, 6} or interlace != 0:
        fail(f"{asset_name} PNG must be non-interlaced 8-bit RGB or RGBA: {path.relative_to(ROOT)}")
    channels = 3 if color_type == 2 else 4
    stride = width * channels
    try:
        filtered = zlib.decompress(bytes(compressed))
    except zlib.error as error:
        fail(f"{asset_name} PNG image data cannot be decoded ({error}): {path.relative_to(ROOT)}")
    if len(filtered) != height * (stride + 1):
        fail(f"{asset_name} PNG scanline payload has an invalid size: {path.relative_to(ROOT)}")

    def paeth(left: int, above: int, upper_left: int) -> int:
        estimate = left + above - upper_left
        left_distance = abs(estimate - left)
        above_distance = abs(estimate - above)
        diagonal_distance = abs(estimate - upper_left)
        if left_distance <= above_distance and left_distance <= diagonal_distance:
            return left
        if above_distance <= diagonal_distance:
            return above
        return upper_left

    rows: list[bytes] = []
    previous = bytearray(stride)
    cursor = 0
    for _ in range(height):
        filter_type = filtered[cursor]
        cursor += 1
        source = filtered[cursor:cursor + stride]
        cursor += stride
        row = bytearray(stride)
        for channel_index, value in enumerate(source):
            left = row[channel_index - channels] if channel_index >= channels else 0
            above = previous[channel_index]
            upper_left = previous[channel_index - channels] if channel_index >= channels else 0
            if filter_type == 0:
                predictor = 0
            elif filter_type == 1:
                predictor = left
            elif filter_type == 2:
                predictor = above
            elif filter_type == 3:
                predictor = (left + above) // 2
            elif filter_type == 4:
                predictor = paeth(left, above, upper_left)
            else:
                fail(f"{asset_name} PNG uses an invalid scanline filter: {path.relative_to(ROOT)}")
            row[channel_index] = (value + predictor) & 0xFF
        rows.append(bytes(row))
        previous = row
    return width, height, channels, rows


def _sample_png_rgb(path: Path, asset_name: str) -> tuple[list[int], list[int], list[int], set[tuple[int, int, int]]]:
    width, height, channels, rows = _decode_png_rows(path, asset_name)
    red_values: list[int] = []
    green_values: list[int] = []
    blue_values: list[int] = []
    unique_colors: set[tuple[int, int, int]] = set()
    for row_index in range(0, height, 2):
        row = rows[row_index]
        for pixel_index in range(0, width, 2):
            offset = pixel_index * channels
            red, green, blue = row[offset], row[offset + 1], row[offset + 2]
            red_values.append(red)
            green_values.append(green)
            blue_values.append(blue)
            if len(unique_colors) < 4096:
                unique_colors.add((red, green, blue))
    if not red_values:
        fail(f"{asset_name} texture has no inspectable RGB samples: {path.relative_to(ROOT)}")
    return red_values, green_values, blue_values, unique_colors


def _validate_nonflat_base_color_texture(path: Path, asset_name: str) -> None:
    red, green, blue, unique_colors = _sample_png_rgb(path, asset_name)
    ranges = (max(red) - min(red), max(green) - min(green), max(blue) - min(blue))
    if len(unique_colors) < 96 or max(ranges) < 16 or sum(channel_range >= 12 for channel_range in ranges) < 2:
        fail(f"{asset_name} base-color texture must retain varied authored material colour and wear.")


def _sample_png_scalar_grid(
    path: Path,
    asset_name: str,
    transform,
    sample_step: int = 2,
) -> list[list[float]]:
    width, height, channels, rows = _decode_png_rows(path, asset_name)
    if width % sample_step != 0 or height % sample_step != 0:
        fail(f"{asset_name} texture dimensions must be divisible by its signal-analysis sample step.")
    return [
        [
            float(transform(row[pixel_index * channels], row[pixel_index * channels + 1], row[pixel_index * channels + 2]))
            for pixel_index in range(0, width, sample_step)
        ]
        for row in rows[::sample_step]
    ]


def _trace_frequency_summary(trace: list[float]) -> tuple[float, float, float, float]:
    sample_count = len(trace)
    if sample_count < 64:
        fail("Mechromancer texture signal traces must retain at least 64 samples.")
    mean = sum(trace) / sample_count
    centered = [value - mean for value in trace]
    rms = math.sqrt(sum(value * value for value in centered) / sample_count)
    total_energy = 0.0
    alias_energy = 0.0
    low_peak = 0.0
    alias_peak = 0.0
    for frequency in range(1, sample_count // 2 + 1):
        angle = math.tau * frequency / sample_count
        cosine_step = math.cos(angle)
        sine_step = math.sin(angle)
        cosine = 1.0
        sine = 0.0
        real = 0.0
        imaginary = 0.0
        for value in centered:
            real += value * cosine
            imaginary -= value * sine
            cosine, sine = (
                cosine * cosine_step - sine * sine_step,
                sine * cosine_step + cosine * sine_step,
            )
        amplitude = 2.0 * math.hypot(real, imaginary) / sample_count
        energy = amplitude * amplitude
        total_energy += energy
        if frequency <= 12:
            low_peak = max(low_peak, amplitude)
        elif frequency >= 16:
            alias_peak = max(alias_peak, amplitude)
            alias_energy += energy
    alias_fraction = alias_energy / max(total_energy, 1.0e-12)
    return rms, low_peak, alias_peak, alias_fraction


def _representative_texture_frequency_summaries(grid: list[list[float]]) -> list[tuple[float, float, float, float]]:
    height = len(grid)
    width = len(grid[0]) if grid else 0
    if width < 64 or height < 64 or any(len(row) != width for row in grid):
        fail("Mechromancer texture signal analysis requires a rectangular high-resolution grid.")
    summaries: list[tuple[float, float, float, float]] = []
    row_positions = [min(height - 1, int((index + 0.5) * height / 8.0)) for index in range(8)]
    column_positions = [min(width - 1, int((index + 0.5) * width / 8.0)) for index in range(8)]
    summaries.extend(_trace_frequency_summary(grid[row_index]) for row_index in row_positions)
    summaries.extend(
        _trace_frequency_summary([grid[row_index][column_index] for row_index in range(height)])
        for column_index in column_positions
    )
    diagonal_size = min(width, height)
    summaries.append(_trace_frequency_summary([grid[index][index] for index in range(diagonal_size)]))
    summaries.append(_trace_frequency_summary([grid[index][width - 1 - index] for index in range(diagonal_size)]))
    return summaries


def _validate_mechromancer_base_color_signal(path: Path) -> None:
    grid = _sample_png_scalar_grid(
        path,
        "Mechromancer base color",
        lambda red, green, blue: (float(red) + float(green) + float(blue)) / 3.0,
    )
    adjacent_differences: list[float] = []
    for row_index, row in enumerate(grid):
        for column_index, value in enumerate(row):
            if column_index > 0:
                adjacent_differences.append(abs(value - row[column_index - 1]))
            if row_index > 0:
                adjacent_differences.append(abs(value - grid[row_index - 1][column_index]))
            if row_index > 0 and column_index > 0:
                adjacent_differences.append(abs(value - grid[row_index - 1][column_index - 1]))
    adjacent_differences.sort()
    difference_count = len(adjacent_differences)
    mean_difference = sum(adjacent_differences) / difference_count
    percentile_95 = adjacent_differences[int((difference_count - 1) * 0.95)]
    percentile_99 = adjacent_differences[int((difference_count - 1) * 0.99)]
    if mean_difference > 1.25 or percentile_95 > 3.0 or percentile_99 > 6.0:
        fail(
            "Mechromancer base-color texture contains excessive local contrast that can alias at tactical distance: "
            f"mean={mean_difference:.3f}, p95={percentile_95:.3f}, p99={percentile_99:.3f}."
        )

    block_size = 32
    block_means: list[float] = []
    for row_start in range(0, len(grid), block_size):
        for column_start in range(0, len(grid[0]), block_size):
            block = [
                grid[row_index][column_index]
                for row_index in range(row_start, min(row_start + block_size, len(grid)))
                for column_index in range(column_start, min(column_start + block_size, len(grid[0])))
            ]
            block_means.append(sum(block) / len(block))
    if max(block_means) - min(block_means) < 4.0:
        fail("Mechromancer base-color texture must retain broad-scale authored wear instead of becoming flat.")

    summaries = _representative_texture_frequency_summaries(grid)
    maximum_alias_peak = max(summary[2] for summary in summaries)
    mean_alias_fraction = sum(summary[3] for summary in summaries) / len(summaries)
    maximum_alias_fraction = max(summary[3] for summary in summaries)
    maximum_low_peak = max(summary[1] for summary in summaries)
    if maximum_low_peak < 2.0:
        fail("Mechromancer base-color texture must retain visible broad low-frequency wear.")
    if maximum_alias_peak > 1.5 or mean_alias_fraction > 0.20 or maximum_alias_fraction > 0.45:
        fail(
            "Mechromancer base-color texture contains dense grid, weave or diagonal alias energy: "
            f"high_peak={maximum_alias_peak:.3f}, mean_high_fraction={mean_alias_fraction:.3f}, "
            f"max_high_fraction={maximum_alias_fraction:.3f}."
        )


def _validate_mechromancer_normal_signal(path: Path) -> None:
    width, height, channels, rows = _decode_png_rows(path, "Mechromancer normal")
    normal_x: list[float] = []
    normal_y: list[float] = []
    normal_z: list[float] = []
    xy_magnitudes: list[float] = []
    vector_lengths: list[float] = []
    x_grid: list[list[float]] = []
    y_grid: list[list[float]] = []
    neighbor_differences: list[float] = []
    for row_index in range(0, height, 2):
        row = rows[row_index]
        x_row: list[float] = []
        y_row: list[float] = []
        for pixel_index in range(0, width, 2):
            offset = pixel_index * channels
            x_value = row[offset] / 127.5 - 1.0
            y_value = row[offset + 1] / 127.5 - 1.0
            z_value = row[offset + 2] / 127.5 - 1.0
            x_row.append(x_value)
            y_row.append(y_value)
            normal_x.append(x_value)
            normal_y.append(y_value)
            normal_z.append(z_value)
            xy_magnitudes.append(math.hypot(x_value, y_value))
            vector_lengths.append(math.sqrt(x_value * x_value + y_value * y_value + z_value * z_value))
            if len(x_row) > 1:
                neighbor_differences.append(math.hypot(x_value - x_row[-2], y_value - y_row[-2]))
            if x_grid:
                neighbor_differences.append(
                    math.hypot(x_value - x_grid[-1][len(x_row) - 1], y_value - y_grid[-1][len(y_row) - 1])
                )
        x_grid.append(x_row)
        y_grid.append(y_row)

    xy_magnitudes.sort()
    normal_z.sort()
    vector_lengths.sort()
    neighbor_differences.sort()
    sample_count = len(normal_x)
    percentile = lambda values, fraction: values[int((len(values) - 1) * fraction)]
    mean_x = sum(normal_x) / sample_count
    mean_y = sum(normal_y) / sample_count
    mean_z = sum(normal_z) / sample_count
    mean_xy = sum(xy_magnitudes) / sample_count
    rms_xy = math.sqrt(sum(value * value for value in xy_magnitudes) / sample_count)
    if abs(mean_x) > 0.015 or abs(mean_y) > 0.015:
        fail(f"Mechromancer normal map must remain centred around +Z: mean XY=({mean_x:.4f}, {mean_y:.4f}).")
    if (
        mean_z < 0.97
        or percentile(normal_z, 0.05) < 0.94
        or normal_z[0] < 0.85
        or mean_xy > 0.12
        or rms_xy > 0.14
        or percentile(xy_magnitudes, 0.95) > 0.22
        or percentile(xy_magnitudes, 0.99) > 0.30
        or xy_magnitudes[-1] > 0.50
    ):
        fail(
            "Mechromancer normal map slopes are too strong for stable tactical-distance shading: "
            f"mean_z={mean_z:.4f}, mean_xy={mean_xy:.4f}, rms_xy={rms_xy:.4f}, "
            f"p95_xy={percentile(xy_magnitudes, 0.95):.4f}, p99_xy={percentile(xy_magnitudes, 0.99):.4f}."
        )
    if percentile(vector_lengths, 0.01) < 0.94 or percentile(vector_lengths, 0.99) > 1.06:
        fail("Mechromancer normal texture must decode to plausibly normalized tangent-space vectors.")
    if (
        sum(neighbor_differences) / len(neighbor_differences) > 0.02
        or percentile(neighbor_differences, 0.95) > 0.05
    ):
        fail("Mechromancer normal texture contains excessive adjacent-pixel slope changes that can shimmer or moire.")

    for channel_name, grid in (("X", x_grid), ("Y", y_grid)):
        summaries = _representative_texture_frequency_summaries(grid)
        maximum_low_peak = max(summary[1] for summary in summaries)
        maximum_alias_peak = max(summary[2] for summary in summaries)
        mean_alias_fraction = sum(summary[3] for summary in summaries) / len(summaries)
        maximum_alias_fraction = max(summary[3] for summary in summaries)
        if maximum_low_peak < 0.01:
            fail(f"Mechromancer normal {channel_name} channel must retain broad low-frequency surface relief.")
        if maximum_alias_peak > 0.04 or mean_alias_fraction > 0.20 or maximum_alias_fraction > 0.50:
            fail(
                f"Mechromancer normal {channel_name} channel contains grid/checker alias energy: "
                f"high_peak={maximum_alias_peak:.4f}, mean_high_fraction={mean_alias_fraction:.3f}, "
                f"max_high_fraction={maximum_alias_fraction:.3f}."
            )


def _validate_packed_orm_texture(path: Path, asset_name: str) -> None:
    occlusion, roughness, metallic, unique_colors = _sample_png_rgb(path, asset_name)
    sample_count = len(occlusion)
    channel_ranges = (
        max(occlusion) - min(occlusion),
        max(roughness) - min(roughness),
        max(metallic) - min(metallic),
    )
    mean_occlusion = sum(occlusion) / sample_count
    mean_roughness = sum(roughness) / sample_count
    sorted_metallic = sorted(metallic)
    metallic_p05 = sorted_metallic[int((sample_count - 1) * 0.05)]
    metallic_p90 = sorted_metallic[int((sample_count - 1) * 0.90)]
    identical_channel_fraction = sum(
        occlusion[index] == roughness[index] == metallic[index]
        for index in range(sample_count)
    ) / sample_count
    if len(unique_colors) < 48:
        fail(f"{asset_name} packed ORM texture must contain varied authored surface classes.")
    if channel_ranges[0] < 12 or channel_ranges[1] < 24 or channel_ranges[2] < 96:
        fail(
            f"{asset_name} packed ORM texture channels are implausibly flat: "
            f"ranges={channel_ranges}."
        )
    if not (96.0 <= mean_occlusion <= 252.0) or not (40.0 <= mean_roughness <= 235.0):
        fail(
            f"{asset_name} packed ORM texture has implausible AO/roughness means: "
            f"AO={mean_occlusion:.1f}, roughness={mean_roughness:.1f}."
        )
    if metallic_p05 > 32 or metallic_p90 < 160:
        fail("Mechromancer packed ORM must distinguish non-metal human gear from authored metal hardware.")
    if identical_channel_fraction > 0.90:
        fail(f"{asset_name} packed ORM must carry independent occlusion, roughness and metallic information.")


def _validate_emissive_mask_texture(path: Path, asset_name: str) -> None:
    red, green, blue, unique_colors = _sample_png_rgb(path, asset_name)
    sample_count = len(red)
    brightness = [max(red[index], green[index], blue[index]) for index in range(sample_count)]
    lit_fraction = sum(value >= 48 for value in brightness) / sample_count
    dark_fraction = sum(value <= 8 for value in brightness) / sample_count
    cyan_weighted_fraction = sum(
        green[index] > red[index] + 12 and blue[index] > red[index] + 12 and max(green[index], blue[index]) >= 64
        for index in range(sample_count)
    ) / sample_count
    if len(unique_colors) < 8 or max(brightness) < 96:
        fail(f"{asset_name} emissive texture must contain a non-flat authored light mask.")
    if not (0.0005 <= lit_fraction <= 0.45) or dark_fraction < 0.45:
        fail(
            f"{asset_name} emissive mask must remain selective rather than flat or globally luminous: "
            f"lit={lit_fraction:.4f}, dark={dark_fraction:.4f}."
        )
    if cyan_weighted_fraction < 0.0002:
        fail("Mechromancer emissive mask must retain readable cyan field-device illumination.")


def _validate_mechromancer_builder_determinism(source_path: Path) -> None:
    if not source_path.is_file():
        fail("Mechromancer canonical Blender source builder is missing.")
    source = source_path.read_text(encoding="utf-8")
    tree = ast.parse(source, filename=str(source_path))
    forbidden_modules = {"datetime", "secrets", "time", "uuid"}
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                if alias.name.split(".")[0] in forbidden_modules:
                    fail(f"Mechromancer deterministic builder must not import {alias.name}.")
        elif isinstance(node, ast.ImportFrom) and str(node.module).split(".")[0] in forbidden_modules:
            fail(f"Mechromancer deterministic builder must not import from {node.module}.")
        elif isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
            owner = node.func.value.id if isinstance(node.func.value, ast.Name) else ""
            if owner == "random" and node.func.attr == "Random" and not node.args and not node.keywords:
                fail("Mechromancer deterministic builder must seed every local random generator explicitly.")
            if owner == "random" and node.func.attr != "Random":
                fail(f"Mechromancer deterministic builder must not use module-global random.{node.func.attr}().")
            if (owner, node.func.attr) in {("os", "urandom"), ("uuid", "uuid4")}:
                fail(f"Mechromancer deterministic builder must not use nondeterministic {owner}.{node.func.attr}().")
    required_source_tokens = (
        MECHROMANCER_ASSET_ID,
        "mechromancer_base_color.png",
        "mechromancer_normal.png",
        "mechromancer_orm.png",
        "mechromancer_emissive.png",
        "1024",
        *MECHROMANCER_REQUIRED_NODES,
        *MECHROMANCER_ANIMATION_CLIPS,
    )
    missing_tokens = [token for token in required_source_tokens if token not in source]
    if missing_tokens:
        fail(f"Mechromancer source builder drifted from its deterministic package contract: {missing_tokens}")


def _valid_vec3_bounds(minimum: object, maximum: object) -> bool:
    if not isinstance(minimum, list) or not isinstance(maximum, list) or len(minimum) != 3 or len(maximum) != 3:
        return False
    try:
        minimum_values = tuple(float(value) for value in minimum)
        maximum_values = tuple(float(value) for value in maximum)
    except (TypeError, ValueError):
        return False
    return all(
        math.isfinite(minimum_values[axis])
        and math.isfinite(maximum_values[axis])
        and minimum_values[axis] <= maximum_values[axis]
        for axis in range(3)
    )


def _read_float_scalar_accessor(gltf: dict, buffer_data: bytes, accessor_index: int, label: str) -> list[float]:
    accessors = gltf.get("accessors", [])
    buffer_views = gltf.get("bufferViews", [])
    if not isinstance(accessor_index, int) or not (0 <= accessor_index < len(accessors)):
        fail(f"{label} references an invalid animation input accessor.")
    accessor = accessors[accessor_index]
    if accessor.get("componentType") != 5126 or accessor.get("type") != "SCALAR" or accessor.get("normalized") is True:
        fail(f"{label} animation timing must use non-normalized float SCALAR data.")
    if accessor.get("sparse"):
        fail(f"{label} animation timing must remain directly inspectable, not sparse.")
    view_index = accessor.get("bufferView")
    if not isinstance(view_index, int) or not (0 <= view_index < len(buffer_views)):
        fail(f"{label} animation timing references an invalid buffer view.")
    view = buffer_views[view_index]
    if view.get("buffer", 0) != 0:
        fail(f"{label} animation timing must live in the canonical external buffer.")
    count = int(accessor.get("count", 0))
    stride = int(view.get("byteStride", 4))
    if count < 2 or stride < 4 or stride % 4 != 0:
        fail(f"{label} animation timing accessor must contain at least two aligned keys.")
    view_offset = int(view.get("byteOffset", 0))
    accessor_offset = int(accessor.get("byteOffset", 0))
    start = view_offset + accessor_offset
    view_end = view_offset + int(view.get("byteLength", 0))
    final_end = start + (count - 1) * stride + 4
    if start < view_offset or final_end > view_end or final_end > len(buffer_data):
        fail(f"{label} animation timing accessor exceeds its declared external buffer view.")
    values = [struct.unpack_from("<f", buffer_data, start + index * stride)[0] for index in range(count)]
    if any(not math.isfinite(value) for value in values):
        fail(f"{label} animation timing contains non-finite key times.")
    if any(values[index] <= values[index - 1] for index in range(1, len(values))):
        fail(f"{label} animation key times must be strictly increasing.")
    accessor_min = accessor.get("min")
    accessor_max = accessor.get("max")
    if (
        not isinstance(accessor_min, list)
        or not isinstance(accessor_max, list)
        or len(accessor_min) != 1
        or len(accessor_max) != 1
        or abs(float(accessor_min[0]) - values[0]) > 1.0e-5
        or abs(float(accessor_max[0]) - values[-1]) > 1.0e-5
    ):
        fail(f"{label} animation timing bounds must exactly describe its authored key range.")
    return values


def _validate_mechromancer_animations(
    gltf: dict,
    buffer_data: bytes,
    node_names: list[str],
    reachable: set[int],
) -> None:
    animations = gltf.get("animations", [])
    animation_names = [str(animation.get("name", "")) for animation in animations]
    if len(animations) != len(MECHROMANCER_ANIMATION_CLIPS) or set(animation_names) != set(MECHROMANCER_ANIMATION_CLIPS):
        fail(f"Mechromancer glTF must contain exactly the six required clips: {animation_names}")
    if len(animation_names) != len(set(animation_names)):
        fail("Mechromancer animation clip names must be unique.")
    accessors = gltf.get("accessors", [])
    expected_output_types = {"translation": "VEC3", "rotation": "VEC4", "scale": "VEC3", "weights": "SCALAR"}
    for animation in animations:
        clip_name = str(animation.get("name", "<unnamed>"))
        channels = animation.get("channels", [])
        samplers = animation.get("samplers", [])
        if len(channels) < len(MECHROMANCER_ANIMATION_REQUIRED_TARGETS[clip_name]):
            fail(f"Mechromancer {clip_name} clip is too sparse for its required primary and secondary motion.")
        targeted_names: set[str] = set()
        targeted_properties: set[tuple[int, str]] = set()
        clip_starts: list[float] = []
        clip_ends: list[float] = []
        for channel_index, channel in enumerate(channels):
            sampler_index = channel.get("sampler")
            if not isinstance(sampler_index, int) or not (0 <= sampler_index < len(samplers)):
                fail(f"Mechromancer {clip_name} channel {channel_index} references an invalid sampler.")
            sampler = samplers[sampler_index]
            interpolation = sampler.get("interpolation", "LINEAR")
            if interpolation not in {"LINEAR", "STEP", "CUBICSPLINE"}:
                fail(f"Mechromancer {clip_name} uses unsupported interpolation {interpolation!r}.")
            times = _read_float_scalar_accessor(
                gltf,
                buffer_data,
                sampler.get("input"),
                f"Mechromancer {clip_name} channel {channel_index}",
            )
            if not (0.0 <= times[0] <= 0.05) or not (0.08 <= times[-1] - times[0] <= 5.0):
                fail(
                    f"Mechromancer {clip_name} has an implausible authored timing range: "
                    f"{times[0]:.5f}..{times[-1]:.5f}."
                )
            clip_starts.append(times[0])
            clip_ends.append(times[-1])
            target = channel.get("target", {})
            target_node = target.get("node")
            target_path = str(target.get("path", ""))
            if not isinstance(target_node, int) or target_node not in reachable:
                fail(f"Mechromancer {clip_name} animation channel targets an invalid or unreachable node.")
            if target_path not in expected_output_types:
                fail(f"Mechromancer {clip_name} animation channel has invalid target path {target_path!r}.")
            target_key = (target_node, target_path)
            if target_key in targeted_properties:
                fail(f"Mechromancer {clip_name} duplicates an authored {target_path} channel on {node_names[target_node]}.")
            targeted_properties.add(target_key)
            targeted_names.add(node_names[target_node])
            output_index = sampler.get("output")
            if not isinstance(output_index, int) or not (0 <= output_index < len(accessors)):
                fail(f"Mechromancer {clip_name} animation sampler references an invalid output accessor.")
            output_accessor = accessors[output_index]
            if output_accessor.get("componentType") != 5126 or output_accessor.get("type") != expected_output_types[target_path]:
                fail(f"Mechromancer {clip_name} {target_path} output must use float {expected_output_types[target_path]} data.")
            expected_output_count = len(times) * (3 if interpolation == "CUBICSPLINE" else 1)
            if int(output_accessor.get("count", 0)) != expected_output_count:
                fail(f"Mechromancer {clip_name} output key count does not match its animation timing.")
        missing_targets = MECHROMANCER_ANIMATION_REQUIRED_TARGETS[clip_name] - targeted_names
        if missing_targets:
            fail(f"Mechromancer {clip_name} is missing required readable motion targets: {sorted(missing_targets)}")
        if max(clip_starts) - min(clip_starts) > 1.0e-5 or max(clip_ends) - min(clip_ends) > 1.0e-5:
            fail(f"Mechromancer {clip_name} channels must share one coherent authored timing range.")


def _validate_neutral_blue_normal_texture(path: Path, asset_name: str) -> None:
    width, height, channels, rows = _decode_png_rows(path, asset_name)
    if (width, height) != (1024, 1024):
        fail(f"{asset_name} normal texture must be exactly 1024x1024, got {width}x{height}.")
    red_total = green_total = blue_total = sample_count = valid_vector_count = 0
    red_min = green_min = blue_min = 255
    red_max = green_max = blue_max = 0
    unique_colors: set[tuple[int, int, int]] = set()
    for row_index in range(0, height, 2):
        row = rows[row_index]
        for pixel_index in range(0, width, 2):
            offset = pixel_index * channels
            red, green, blue = row[offset], row[offset + 1], row[offset + 2]
            red_total += red
            green_total += green
            blue_total += blue
            sample_count += 1
            red_min, red_max = min(red_min, red), max(red_max, red)
            green_min, green_max = min(green_min, green), max(green_max, green)
            blue_min, blue_max = min(blue_min, blue), max(blue_max, blue)
            if len(unique_colors) < 512:
                unique_colors.add((red, green, blue))
            normal_x = red / 127.5 - 1.0
            normal_y = green / 127.5 - 1.0
            normal_z = blue / 127.5 - 1.0
            length_squared = normal_x * normal_x + normal_y * normal_y + normal_z * normal_z
            if normal_z >= 0.0 and 0.55 <= length_squared <= 1.45:
                valid_vector_count += 1
    mean_red = red_total / sample_count
    mean_green = green_total / sample_count
    mean_blue = blue_total / sample_count
    if not (96.0 <= mean_red <= 160.0 and 96.0 <= mean_green <= 160.0):
        fail(f"{asset_name} normal texture must remain centred around neutral tangent-space red and green.")
    if mean_blue < 200.0 or mean_blue < max(mean_red, mean_green) + 55.0 or abs(mean_red - mean_green) > 24.0:
        fail(f"{asset_name} normal texture must retain a valid neutral-blue tangent-space bias.")
    if len(unique_colors) < 16 or max(red_max - red_min, green_max - green_min, blue_max - blue_min) < 8:
        fail(f"{asset_name} normal texture must contain non-flat authored surface relief.")
    if valid_vector_count / sample_count < 0.96:
        fail(f"{asset_name} normal texture must decode predominantly to valid forward-facing unit normals.")


def _validate_bulwark_normal_texture(path: Path) -> None:
    _validate_neutral_blue_normal_texture(path, "Bulwark")


def _gltf_image_path(gltf_path: Path, image: dict, asset_name: str = "Bulwark") -> Path:
    uri = str(image.get("uri", ""))
    if not uri or uri.startswith("data:"):
        fail(f"{asset_name} glTF images must use inspectable external PNG files.")
    return (gltf_path.parent / uri).resolve()


def _material_texture_source(gltf: dict, material: dict, *keys: str) -> int:
    value: object = material
    for key in keys:
        if not isinstance(value, dict):
            return -1
        value = value.get(key)
    if not isinstance(value, dict):
        return -1
    texture_index = value.get("index")
    textures = gltf.get("textures", [])
    if not isinstance(texture_index, int) or not (0 <= texture_index < len(textures)):
        return -1
    source_index = textures[texture_index].get("source")
    return source_index if isinstance(source_index, int) else -1


def validate_bulwark_hd_asset() -> None:
    manifest_path = ROOT / "game/data/bulwark_asset_manifest.json"
    gltf_path = ROOT / "game/assets/bulwark/bulwark.gltf"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    gltf = json.loads(gltf_path.read_text(encoding="utf-8"))

    declared_textures = manifest.get("textures")
    if not isinstance(declared_textures, dict) or set(declared_textures) != set(BULWARK_TEXTURE_ROLES):
        fail("Bulwark manifest must declare exactly base_color, normal, orm and emissive textures.")
    texture_paths: dict[str, Path] = {}
    for role in BULWARK_TEXTURE_ROLES:
        raw_path = declared_textures.get(role)
        if not isinstance(raw_path, str) or not raw_path.lower().endswith(".png"):
            fail(f"Bulwark {role} texture declaration must point to a PNG file.")
        texture_path = _resolve_bulwark_texture_path(raw_path)
        try:
            texture_path.relative_to(ROOT / "game/assets/bulwark")
        except ValueError:
            fail(f"Bulwark {role} texture must live inside the authored Bulwark package.")
        if not texture_path.is_file():
            fail(f"Bulwark {role} texture is missing: {raw_path}")
        width, height, _, _ = _decode_png_rows(texture_path)
        if (width, height) != (1024, 1024):
            fail(f"Bulwark {role} texture must be exactly 1024x1024, got {width}x{height}.")
        texture_paths[role] = texture_path
    if len(set(texture_paths.values())) != len(BULWARK_TEXTURE_ROLES):
        fail("Bulwark PBR roles must resolve to four distinct PNG files.")
    _validate_bulwark_normal_texture(texture_paths["normal"])

    nodes = gltf.get("nodes", [])
    node_names = [str(node.get("name", "")) for node in nodes]
    duplicate_names = sorted(name for name, count in Counter(node_names).items() if not name or count != 1)
    if duplicate_names:
        fail(f"Bulwark glTF node names must be non-empty and globally unique: {duplicate_names}")
    node_name_set = set(node_names)
    for stable_name in manifest.get("stable_nodes", []):
        if str(stable_name) not in node_name_set:
            fail(f"Bulwark glTF is missing declared stable node: {stable_name}")
    for detail_name in BULWARK_STATIC_DETAILS:
        if detail_name not in node_name_set:
            fail(f"Bulwark authored package is missing migrated static detail: {detail_name}")

    expected_socket_types = {"sensor", "optic", "weapon_mount", "weapon_muzzle", "protection_emitter"}
    declared_socket_types = {str(socket) for socket in manifest.get("socket_contract", [])}
    if declared_socket_types != expected_socket_types:
        fail("Bulwark manifest must preserve the complete sensor, weapon and protection socket contract.")
    socket_types = Counter(str(node.get("extras", {}).get("socket_type", "")) for node in nodes)
    for socket_type in expected_socket_types:
        if socket_types[socket_type] < 1:
            fail(f"Bulwark glTF is missing runtime socket type: {socket_type}")

    accessors = gltf.get("accessors", [])
    primitive_count = 0
    for mesh in gltf.get("meshes", []):
        for primitive in mesh.get("primitives", []):
            primitive_count += 1
            attributes = primitive.get("attributes", {})
            for semantic, accessor_type in (("TEXCOORD_0", "VEC2"), ("TANGENT", "VEC4")):
                accessor_index = attributes.get(semantic)
                if not isinstance(accessor_index, int) or not (0 <= accessor_index < len(accessors)):
                    fail(f"Bulwark {mesh.get('name', '<unnamed>')} primitive is missing {semantic}.")
                accessor = accessors[accessor_index]
                if accessor.get("type") != accessor_type or accessor.get("componentType") != 5126:
                    fail(f"Bulwark {mesh.get('name', '<unnamed>')} {semantic} must use float {accessor_type} data.")
                position_index = attributes.get("POSITION")
                if not isinstance(position_index, int) or not (0 <= position_index < len(accessors)):
                    fail(f"Bulwark {mesh.get('name', '<unnamed>')} primitive is missing POSITION.")
                if int(accessor.get("count", -1)) != int(accessors[position_index].get("count", -2)):
                    fail(f"Bulwark {mesh.get('name', '<unnamed>')} {semantic} count must match POSITION.")
            material_index = primitive.get("material")
            if not isinstance(material_index, int) or not (0 <= material_index < len(gltf.get("materials", []))):
                fail(f"Bulwark {mesh.get('name', '<unnamed>')} primitive must retain an authored material.")
    if primitive_count == 0:
        fail("Bulwark glTF must contain authored mesh primitives.")

    image_paths = [_gltf_image_path(gltf_path, image) for image in gltf.get("images", [])]
    for role, texture_path in texture_paths.items():
        if texture_path not in image_paths:
            fail(f"Bulwark glTF does not reference its declared {role} texture.")
    expected_sources = {role: image_paths.index(path) for role, path in texture_paths.items()}
    emissive_material_count = 0
    for material in gltf.get("materials", []):
        material_name = str(material.get("name", "<unnamed>"))
        slots = {
            "base_color": _material_texture_source(gltf, material, "pbrMetallicRoughness", "baseColorTexture"),
            "normal": _material_texture_source(gltf, material, "normalTexture"),
            "orm": _material_texture_source(gltf, material, "pbrMetallicRoughness", "metallicRoughnessTexture"),
        }
        for role, source_index in slots.items():
            if source_index != expected_sources[role]:
                fail(f"Bulwark material {material_name} must wire its {role} channel to the declared texture.")
        if _material_texture_source(gltf, material, "occlusionTexture") != expected_sources["orm"]:
            fail(f"Bulwark material {material_name} must wire occlusion to the declared ORM texture.")
        emissive_factor = material.get("emissiveFactor", [0.0, 0.0, 0.0])
        if isinstance(emissive_factor, list) and any(float(channel) > 0.0 for channel in emissive_factor):
            emissive_material_count += 1
            if _material_texture_source(gltf, material, "emissiveTexture") != expected_sources["emissive"]:
                fail(f"Bulwark emissive material {material_name} must wire the declared emissive mask.")
    if emissive_material_count < 2:
        fail("Bulwark PBR package must retain distinct shield and lamp materials wired to its emissive mask.")

    animations = {str(animation.get("name", "")): animation for animation in gltf.get("animations", [])}
    for clip_name, required_targets in (("Walk", BULWARK_WALK_TARGETS), ("Fire", BULWARK_FIRE_TARGETS)):
        animation = animations.get(clip_name)
        if animation is None:
            fail(f"Bulwark glTF is missing required animation clip: {clip_name}")
        target_names = {
            node_names[int(channel.get("target", {}).get("node"))]
            for channel in animation.get("channels", [])
            if isinstance(channel.get("target", {}).get("node"), int)
            and 0 <= int(channel.get("target", {}).get("node")) < len(node_names)
        }
        missing_targets = [target for target in required_targets if target not in target_names]
        if missing_targets:
            fail(f"Bulwark {clip_name} must animate every required assembly: {missing_targets}")

    chassis_mesh = next((mesh for mesh in gltf.get("meshes", []) if mesh.get("name") == "Chassis"), None)
    if not chassis_mesh or not chassis_mesh.get("primitives"):
        fail("Bulwark glTF must preserve its primary Chassis mesh.")
    chassis_position_index = chassis_mesh["primitives"][0].get("attributes", {}).get("POSITION")
    chassis_accessor = accessors[chassis_position_index] if isinstance(chassis_position_index, int) and 0 <= chassis_position_index < len(accessors) else {}
    bounds_min = chassis_accessor.get("min", [])
    bounds_max = chassis_accessor.get("max", [])
    if len(bounds_min) != 3 or len(bounds_max) != 3:
        fail("Bulwark Chassis must preserve explicit authored bounds.")
    bounds_size = [float(bounds_max[index]) - float(bounds_min[index]) for index in range(3)]
    if not (1.4 <= bounds_size[0] <= 2.2 and 0.7 <= bounds_size[1] <= 1.4 and 1.4 <= bounds_size[2] <= 2.3):
        fail(f"Bulwark Chassis bounds drifted outside the protected silhouette envelope: {bounds_size}")


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
        if family in {"bulwark", "warden", "scrapper", "pathfinder", "engineer", "relay"}:
            source = (ROOT / f"game/assets/{family}/source/build_{family}_asset.py").read_text(encoding="utf-8")
            for token in [
                '"Chassis": mesh("Chassis", add_ellipsoid',
            ]:
                if token not in source:
                    fail(f"{family} source builder is missing rounded high-definition geometry: {token}")
            if family != "relay" and '"Plate": mesh("Plate", add_ellipsoid' not in source:
                fail(f"{family} source builder is missing a rounded high-definition front plate.")
            mesh_by_name = {str(mesh.get("name")): mesh for mesh in gltf.get("meshes", [])}
            required_meshes = {"Chassis": 600}
            if family != "relay":
                required_meshes["Plate"] = 300
            for mesh_name, minimum_vertices in required_meshes.items():
                mesh = mesh_by_name.get(mesh_name)
                if not mesh or not mesh.get("primitives"):
                    fail(f"{family} glTF is missing the {mesh_name} mesh required for close-camera review.")
                position_accessor_index = mesh["primitives"][0].get("attributes", {}).get("POSITION")
                vertex_count = gltf.get("accessors", [])[position_accessor_index].get("count", 0) if position_accessor_index is not None else 0
                if vertex_count < minimum_vertices:
                    fail(f"{family} {mesh_name} mesh must retain at least {minimum_vertices} authored vertices.")


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


def validate_authored_region_surface_channels() -> None:
    """Ensure landmark meshes keep the shared high-definition surface channels."""
    for family in AUTHORED_REGION_ASSETS:
        manifest_path = ROOT / f"game/data/{family}_asset_manifest.json"
        gltf_path = ROOT / f"game/assets/{family}/{family}.gltf"
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        if manifest.get("material_workflow") != "shared_uv_tangent_pbr_geometry":
            fail(f"{family} landmark manifest must declare the shared UV/tangent PBR workflow.")
        gltf = json.loads(gltf_path.read_text(encoding="utf-8"))
        accessors = gltf.get("accessors", [])
        mesh_count = 0
        for mesh in gltf.get("meshes", []):
            for primitive in mesh.get("primitives", []):
                attributes = primitive.get("attributes", {})
                for semantic in ("POSITION", "NORMAL", "TEXCOORD_0", "TANGENT"):
                    accessor_index = attributes.get(semantic)
                    if not isinstance(accessor_index, int) or accessor_index < 0 or accessor_index >= len(accessors):
                        fail(f"{family} landmark primitive is missing a valid {semantic} accessor.")
                mesh_count += 1
        if mesh_count == 0:
            fail(f"{family} landmark glTF must contain authored mesh primitives.")


def validate_asset_manifest_quality_contract() -> None:
    """Require every runtime art manifest to declare authored HD provenance."""
    manifests = sorted((ROOT / "game/data").glob("*_asset_manifest.json"))
    if not manifests:
        fail("No runtime asset manifests were found for the quality contract.")
    for manifest_path in manifests:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
        quality = manifest.get("asset_quality") or manifest.get("quality")
        if quality != "authored_high_definition":
            fail(f"{manifest_path.name} must declare authored_high_definition quality.")
        source = manifest.get("source_builder") or manifest.get("source")
        if not str(source).strip():
            fail(f"{manifest_path.name} must declare an authored source builder.")
        runtime = manifest.get("runtime_scene") or manifest.get("runtime_model") or manifest.get("runtime_path")
        if not str(runtime).strip():
            fail(f"{manifest_path.name} must declare a runtime model path.")


def main() -> int:
    try:
        for relative in REQUIRED:
            path = ROOT / relative
            if not path.is_file() or path.stat().st_size < 100:
                fail(f"Missing or unexpectedly empty aesthetic file: {relative}")

        validate_mechromancer_asset()
        validate_heartforge_asset()
        validate_heartforge_threshold_asset()
        validate_salvage_asset()
        validate_vehicle_wreck_asset()
        validate_legacy_organic_source_tessellation()
        validate_shared_organic_source_tessellation()
        validate_mechromancer_source_tessellation()
        validate_actor_geometry_density()
        validate_actor_animation_breadth()
        validate_asset_manifest_quality_contract()
        validate_bulwark_hd_asset()
        validate_authored_robot_assets()
        validate_authored_organic_assets()
        validate_early_organic_materials()
        validate_sporecaster_gill_finish()
        validate_authored_region_assets()
        validate_authored_region_surface_channels()

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
            for token in ["ReviewFloor", "ReviewBackdrop", "ReviewFrontFill", "ReviewRimLight", "PRESENTATION_REVIEW_EARLY_ORGANICS", "PRESENTATION_REVIEW_REGIONS", "REMOTE · ROOT CISTERN"]:
                if token not in release:
                    fail(f"Presentation review gallery is missing material-inspection behaviour: {token}")
        if "main_world_tiered_3d.gd" in main_scene:
            bootstrap_path = "res://scripts/systems/enemy_tier_progression_bootstrap_3d.gd"
            if main_scene.count(bootstrap_path) != 1:
                fail("Tiered entrypoint must install exactly one canonical enemy-tier bootstrap.")
            if main_scene.count('[node name="EnemyTierProgressionBootstrap"') != 1:
                fail("Tiered entrypoint must contain exactly one canonical enemy-tier bootstrap node.")
            for token in ["EnemyTierDirector3D", "EnemyTierEventBridge3D", "EnemyTierHUD3D"]:
                if token in main_scene:
                    fail(f"Native scene must not install legacy enemy-tier runtime: {token}")
            for token in [
                "extends IronwrightReleaseWorld3D",
                "EnemyTierProgressionDirector3D",
                "_canonical_enemy_tier_director",
                "_spawn_capped_operation_threat",
                "canonical_tier_director.request_causal_threat",
                'release["enemy_tier_progression"]',
                'release.get("enemy_tier_progression", {})',
                "canonical_tier_director.restore_from_dictionary",
                'set_meta(&"enemy_tier_progression_restored_from_unified", true)',
            ]:
                if token not in tiered:
                    fail(f"Tiered entrypoint is missing merged release/ecology behaviour: {token}")
            for token in [
                "EnemyTierDirector3D",
                "EnemyTierEventBridge3D",
                "EnemyTierHUD3D",
                "res://scripts/systems/enemy_tier_director_3d.gd",
                "res://scripts/systems/enemy_tier_event_bridge_3d.gd",
                "res://scripts/ui/enemy_tier_hud_3d.gd",
                'release["enemy_tiers"]',
                'release["enemy_tier_events"]',
                'release.get("enemy_tiers"',
                'release.get("enemy_tier_events"',
            ]:
                if token in tiered:
                    fail(f"Tiered entrypoint still integrates retired parallel ecology runtime: {token}")
            if tiered.count('release["enemy_tier_progression"]') != 1:
                fail("Tiered snapshots must write one unified enemy_tier_progression payload.")
            if tiered.count('release.get("enemy_tier_progression", {})') != 1:
                fail("Tiered restore must read the unified enemy_tier_progression payload once.")
            if "return _spawn_enemy(position, species)" in tiered:
                fail("Causal operation threats must materialize at a living nest or redirect an existing actor.")

            bootstrap = (ROOT / "game/scripts/systems/enemy_tier_progression_bootstrap_3d.gd").read_text(encoding="utf-8")
            for token in [
                "class_name EnemyTierProgressionBootstrap3D",
                "director = EnemyTierProgressionDirector3D.new()",
                "intel_hud = EnemyTierIntelHUD3D.new()",
                'node.call(&"set_external_population_control", true)',
                'node.set("spawn_enemy_callable", Callable())',
                'node.set("spawn_enemy_callback", Callable())',
                'if not bool(world.get_meta(&"enemy_tier_progression_restored_from_unified", false))',
                'world.set_meta(&"enemy_tier_progression_migrated_from_sidecar", true)',
            ]:
                if token not in bootstrap:
                    fail(f"Canonical enemy-tier bootstrap is missing integration behaviour: {token}")
            if bootstrap.count("EnemyTierProgressionDirector3D.new()") != 1:
                fail("Canonical bootstrap must create exactly one enemy-tier population director.")
            if bootstrap.count("EnemyTierIntelHUD3D.new()") != 1:
                fail("Canonical bootstrap must create exactly one ecology-intelligence HUD.")
            if "func _save_sidecar" in bootstrap or "_save_sidecar()" in bootstrap:
                fail("Canonical saves must not create a second enemy-tier sidecar generation.")
            for token in [
                "node.set_process(false)",
                "node.set_physics_process(false)",
                'node.set("active_enemy_cap", 0)',
                'node.set("spawn_interval", 999999.0)',
            ]:
                if token in bootstrap:
                    fail(f"Population handoff must not freeze the living ecology with: {token}")
            for token in ["EnemyTierDirector3D", "EnemyTierEventBridge3D", "EnemyTierHUD3D"]:
                if token in bootstrap:
                    fail(f"Canonical bootstrap must not reference legacy enemy-tier runtime: {token}")

            canonical_director = (ROOT / "game/scripts/systems/enemy_tier_progression_director_3d.gd").read_text(encoding="utf-8")
            for token in [
                'add_to_group(&"enemy_tier_progression")',
                "EVENT_MODIFIERS_PATH",
                "_load_detailed_event_effects",
                "_process_saturation_high_to_low",
                "_enforce_population_caps",
                "_select_spawn_nest",
                "_materialize_from_nest",
                "request_causal_threat",
                "_materialize_from_nest(tier, nest, species)",
                "_redirect_causal_actor",
                "to_dictionary",
                "restore_from_dictionary",
            ]:
                if token not in canonical_director:
                    fail(f"Canonical enemy-tier director is missing causal ecology behaviour: {token}")

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
        for legacy_token in ["VerticalSliceCharacterArt", "DeepHood"]:
            if legacy_token in actor_art:
                fail(f"Mechromancer authored package must not be duplicated by legacy runtime overlay {legacy_token}.")
        player_polish = actor_art.split("func _polish_player", 1)[-1].split("func _polish_robot", 1)[0]
        for token in ["MechromancerModel", "ShoulderLamp", "MechromancerReadabilityLight"]:
            if token not in player_polish:
                fail(f"Mechromancer runtime polish must retain its restrained authored-socket treatment: {token}")
        for forbidden_token in ["material_override", "MeshInstance3D.new", "_add_box(", "_add_cylinder(", "_add_sphere("]:
            if forbidden_token in player_polish:
                fail(f"Mechromancer runtime polish must not recreate source-owned static art: {forbidden_token}")
        for token in [
            "VerticalSliceMachineArt",
            "BulwarkShieldArc",
            "WardenAutocannon",
            "DeepScrapHopper",
            "PathfinderDish",
        ]:
            if token not in actor_art:
                fail(f"Vertical-slice actor art is missing {token}")

        release_art = (ROOT / "game/scripts/release/release_world_art_director_3d.gd").read_text(encoding="utf-8")
        for token in [
            'AUTHORED_MECHROMANCER_ASSET_ID := &"mechromancer.player.v1"',
            'AUTHORED_MECHROMANCER_ROOT_NAME := &"MechromancerModel"',
            'AUTHORED_MECHROMANCER_MATERIAL_FAMILY := &"authored_mechromancer_pbr"',
            "if _is_authored_mechromancer_package_mesh(mesh_instance):",
            'mesh_instance.set_meta(&"release_material_family", AUTHORED_MECHROMANCER_MATERIAL_FAMILY)',
            "func _is_authored_mechromancer_package_mesh",
        ]:
            if token not in release_art:
                fail(f"Release presentation must preserve the authored Mechromancer PBR package: {token}")

        animator = (ROOT / "game/scripts/presentation/procedural_animator_3d.gd").read_text(encoding="utf-8")
        for token in ["_animate_mechromancer", "_animate_robot", "_animate_organic", "recoil", "hit_impulse"]:
            if token not in animator:
                fail(f"Procedural animator is missing {token}")

        guidance = (ROOT / "game/scripts/presentation/objective_guidance_3d.gd").read_text(encoding="utf-8")
        for token in ["marker_label.fixed_size = false", "BeaconStem", "BeaconCrown", "BeaconSignalRing"]:
            if token not in guidance:
                fail(f"Objective guidance is missing the bounded physical cue {token}")

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
