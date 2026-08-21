extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")
const ROBOT_SCENE := preload("res://scenes/actors/robot_unit_3d.tscn")
const ENEMY_SCENE := preload("res://scenes/actors/organic_enemy_3d.tscn")
const OUTPOST_SCENE := preload("res://scenes/world/outpost_3d.tscn")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    var world := MAIN_SCENE.instantiate()
    root.add_child(world)
    await process_frame
    await physics_frame
    await process_frame

    _expect(world is IronwrightBeautifulWorld3D, "The main scene must boot the aesthetic-overhaul world.")
    _expect(world.get_node_or_null("AestheticDirector") is AestheticDirector3D, "The aesthetic director must exist at runtime.")
    var audio_director := world.get_node_or_null("AudioFeedbackDirector") as AudioFeedbackDirector3D
    _expect(audio_director != null, "The world must provide spatial survival audio feedback.")
    if audio_director != null:
        for profile in [&"pistol", &"machine_weapon", &"salvage", &"forge", &"organic_attack", &"organic_death", &"heartforge_damage", &"noise_pulse", &"region_transition", &"endgame_start", &"endgame_stage", &"endgame_complete", &"endgame_failure"]:
            _expect(audio_director.has_profile(profile), "The audio director must provide the %s profile." % profile)
        if world.noise_system != null:
            var construction_audio_before := audio_director.event_count
            world.noise_system.emit_noise(Vector3(0.0, 0.0, -12.0), 27.0, 0.72, &"outpost_construction")
            _expect(audio_director.event_count > construction_audio_before, "Outpost construction noise must produce spatial audio feedback.")
            _expect(audio_director.last_profile == &"noise_pulse", "Outpost construction noise must use the bounded noise-pulse audio language.")
            audio_director.stop_all()
    _expect(world.get_node_or_null("CozyHeartforgeCamp") != null, "The Heartforge must receive an inhabited cozy camp layer.")
    _expect(world.get_node_or_null("UrbanAestheticPass") != null, "The ruined city must receive the urban storytelling pass.")
    _expect(world.get_node_or_null("HeartforgeVerticalSlice/HeartforgeMaintenanceDetail") != null, "The Heartforge must expose a dedicated presentation-only maintenance detail layer.")
    _expect(world.get_node_or_null("HeartforgeVerticalSlice/HeartforgePlazaDetail/HeartforgeServiceRing/ForgeRecessedServiceRing") != null, "The Heartforge plaza must expose a readable recessed service ring around its focal machine.")
    var route_marker := _find_named(world, "ThresholdRouteMarkerCore") as MeshInstance3D
    if route_marker != null:
        var route_material := route_marker.material_override as StandardMaterial3D
        _expect(route_material != null and route_material.emission.r > route_material.emission.b, "The opening route marker must use the promised amber visual language.")
    var presentation_feedback := world.get_node_or_null("AestheticDirector/PresentationFeedback") as Node
    _expect(presentation_feedback != null, "The aesthetic director must own transient presentation feedback.")
    if presentation_feedback != null:
        var hostile_sample := get_first_node_in_group(&"organic_enemies") as OrganicEnemy3D
        if hostile_sample != null and world.player != null:
            presentation_feedback.call("_on_attack_started", hostile_sample, world.player)
            var telegraph := world.get_node_or_null("OrganicAttackTelegraph") as Node3D
            _expect(telegraph != null, "Organic attacks must create a bounded world-space warning telegraph.")
            _expect(telegraph != null and telegraph.get_node_or_null("OrganicAttackTelegraphRing") != null, "Organic attack warnings must expose a bright readable ring at the target area.")
        var labor_pile := get_first_node_in_group(&"salvage_piles") as SalvagePile3D
        var labor_robot := get_first_node_in_group(&"friendly_robots") as RobotUnit3D
        if labor_pile != null and labor_robot != null:
            paused = false
            labor_robot.global_position = labor_pile.global_position + Vector3(1.4, 0.0, 0.0)
            labor_robot.hold_position = true
            labor_robot.begin_robot_salvage(labor_pile)
            labor_robot.state_name = &"salvaging"
            presentation_feedback.call("_refresh_autonomous_labor_signatures", 0.016)
            _expect(int(presentation_feedback.call("active_labor_signature_count")) == 1, "Autonomous salvage must expose one bounded machine-to-wreck labor signature.")
        var outpost_director := world.get_node_or_null("OutpostDirector") as OutpostDirector3D
        var construction_site := outpost_director.get_site(&"site.north_transit_yard") if outpost_director != null else null
        if outpost_director != null and construction_site != null and labor_robot != null:
            var original_robot_position := labor_robot.global_position
            labor_robot.global_position = construction_site.global_position + Vector3(2.0, 0.0, 0.5)
            outpost_director.operation = {
                "kind": &"build",
                "state": &"working",
                "site": construction_site,
                "members": [labor_robot],
            }
            presentation_feedback.call("_refresh_autonomous_construction_signature", 0.016)
            _expect(int(presentation_feedback.call("active_construction_signature_count")) == 1, "Autonomous construction must expose one bounded machine-to-site labor signature.")
            outpost_director.operation.clear()
            labor_robot.global_position = original_robot_position
            presentation_feedback.call("_refresh_autonomous_construction_signature", 0.016)
            _expect(int(presentation_feedback.call("active_construction_signature_count")) == 0, "Construction feedback must clear when the remote operation leaves its working state.")
    var encounter_dressing := world.get_node_or_null("RegionEncounterDressingDirector") as RegionEncounterDressingDirector3D
    var region_director := world.get_node_or_null("WorldRegionDirector") as WorldRegionDirector3D
    _expect(encounter_dressing != null, "The complete world must provide discovery-driven authored region dressing.")
    if encounter_dressing != null and region_director != null:
        for raw_region_id in region_director.region_data.keys():
            region_director.discover_region(StringName(raw_region_id))
        await process_frame
        for raw_region_id in region_director.region_data.keys():
            var landmark := region_director.get_landmark(StringName(raw_region_id))
            if landmark == null or landmark.region_kind == &"sanctuary":
                continue
            _expect(landmark.get_node_or_null("PersistentRegionCollision/PersistentRegionGround") != null, "Each non-sanctuary region must retain a persistent ground collision shape for physical traversal.")
            _expect(landmark.get_node_or_null("PersistentRegionGeometry/AuthoredEncounterDressing") != null, "Each non-sanctuary region must receive stable authored encounter dressing on discovery.")
            _expect(landmark.get_node_or_null("PersistentRegionGeometry/AuthoredDistrictSurfaceFinish") != null, "Each non-sanctuary region must receive a bounded authored surface-finish layer.")
            _expect(landmark.get_node_or_null("PersistentRegionGeometry/RegionPracticalLight0") != null and landmark.get_node_or_null("PersistentRegionGeometry/RegionPracticalLight1") != null, "Each non-sanctuary region must receive two bounded palette-aware practical lights.")
            _expect(landmark.find_child("*Facade*", true, false) != null, "Each non-sanctuary region must expose a readable district-specific surface signature.")
            if landmark.region_kind == &"industrial":
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/WestGridAuthoredModel") != null, "West Grid must expose its authored turbine-hall and transformer-yard landmark shell.")
                _expect(landmark.find_child("WestGridWindowFrame0", true, false) != null and landmark.find_child("WestGridWindowMullion0", true, false) != null, "West Grid must expose turbine-hall window framing and mullions.")
                _expect(landmark.find_child("WestGridTankValve0", true, false) != null and landmark.find_child("WestGridTankLadder0", true, false) != null, "West Grid must expose pressure-tank service hardware.")
                _expect(landmark.find_child("WestGridTransformerCap0", true, false) != null and landmark.find_child("WestGridTransformerBrace0", true, false) != null, "West Grid must expose layered transformer-yard hardware.")
                _expect(landmark.find_child("WestGridPipeFlange0", true, false) != null and landmark.find_child("WestGridWarningHousing0", true, false) != null, "West Grid must expose service-pipe and warning hardware.")
                _expect(landmark.find_child("WestGridOrganicTendril0_0", true, false) != null, "West Grid organic growth must expose secondary tendril anatomy.")
                var grid_signal := landmark.find_child("WestGridTankSignal0", true, false) as Node3D
                var grid_warning := landmark.find_child("WestGridWarningLight0", true, false) as Node3D
                var grid_growth := landmark.find_child("WestGridOrganicCreep0", true, false) as Node3D
                var grid_valve := landmark.find_child("WestGridTankValve0", true, false) as Node3D
                var grid_tendril := landmark.find_child("WestGridOrganicTendril0_0", true, false) as Node3D
                _expect(grid_signal != null and grid_warning != null and grid_growth != null and grid_valve != null and grid_tendril != null, "West Grid must expose named signal, warning, valve, organic-growth and tendril motion sockets.")
                if grid_signal != null and grid_warning != null and grid_growth != null and grid_valve != null and grid_tendril != null:
                    landmark.set_presentation_detail_level(0)
                    var grid_signal_before := grid_signal.scale
                    var grid_warning_before := grid_warning.scale
                    var grid_growth_before := grid_growth.scale
                    var grid_valve_before := grid_valve.rotation
                    var grid_tendril_before := grid_tendril.rotation
                    landmark.call("_process", 0.5)
                    _expect(not grid_signal.scale.is_equal_approx(grid_signal_before), "West Grid tank signal must pulse as a restrained presentation cue.")
                    _expect(not grid_warning.scale.is_equal_approx(grid_warning_before), "West Grid warning light must carry deterministic presentation motion.")
                    _expect(not grid_growth.scale.is_equal_approx(grid_growth_before), "West Grid organic growth must carry deterministic presentation motion.")
                    _expect(not grid_valve.rotation.is_equal_approx(grid_valve_before), "West Grid tank valve must carry restrained service motion.")
                    _expect(not grid_tendril.rotation.is_equal_approx(grid_tendril_before), "West Grid organic tendril must carry deterministic presentation motion.")
            if landmark.region_kind == &"endgame":
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/RootCisternAuthoredModel") != null, "The Root Cistern must expose its authored landmark shell.")
                _expect(landmark.find_child("RootCisternBasin", true, false) != null, "The Root Cistern must expose an authored basin floor to anchor the capstone encounter.")
                _expect(landmark.find_child("RootCisternCoreHalo", true, false) != null, "The Root Cistern must expose an authored luminous core halo.")
                var cistern_pulse := landmark.find_child("RootCisternPulse0", true, false) as Node3D
                _expect(cistern_pulse != null, "The Root Cistern must expose a signal pulse socket on the authored pylon hierarchy.")
            if landmark.region_kind == &"nest":
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/NestOccluderShell") != null, "The nest must isolate its close-range opaque shell for camera-safe presentation.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/CathedralAuthoredModel") != null, "Cathedral Quarter must expose its authored nave and choir landmark shell.")
                var cathedral_choir_signal := landmark.find_child("CathedralChoirSignal", true, false) as Node3D
                var cathedral_bell := landmark.find_child("CathedralBell", true, false) as Node3D
                _expect(cathedral_choir_signal != null and cathedral_bell != null, "Cathedral Quarter must expose named choir and bell motion sockets.")
                if cathedral_choir_signal != null and cathedral_bell != null:
                    var choir_signal_before := cathedral_choir_signal.scale
                    var bell_before := cathedral_bell.rotation.z
                    landmark.call("_process", 0.5)
                    _expect(not cathedral_choir_signal.scale.is_equal_approx(choir_signal_before), "Cathedral choir signal must pulse as a restrained presentation cue.")
                    _expect(absf(cathedral_bell.rotation.z - bell_before) > 0.001, "Cathedral bell must carry deterministic presentation motion.")
            if landmark.region_kind == &"commercial":
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/FloodMarketIdentityDetails") != null, "Flood Market must expose authored stall canopies and hanging signs.")
                _expect(landmark.find_child("MarketFloodChannel", true, false) != null, "Flood Market must expose bounded presentation-only water channels.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/FloodMarketAuthoredModel") != null, "Flood Market must expose its authored canopy and service landmark shell.")
                _expect(landmark.find_child("FloodMarketCanopyRib0_0", true, false) != null and landmark.find_child("FloodMarketStallFrame0", true, false) != null, "Flood Market must expose secondary canopy and stall framing detail.")
                _expect(landmark.find_child("FloodMarketWaterFoam0_0", true, false) != null and landmark.find_child("FloodMarketCraneWheel", true, false) != null, "Flood Market must expose water-edge and service-crane detail.")
                _expect(landmark.find_child("FloodMarketOrganicTendril0_0", true, false) != null, "Flood Market organic growth must expose secondary tendril anatomy.")
                var market_light := landmark.find_child("FloodMarketWaterline0", true, false) as Node3D
                var market_growth := landmark.find_child("FloodMarketOrganicGrowth0", true, false) as Node3D
                _expect(market_light != null and market_growth != null, "Flood Market must expose named waterline and organic-growth motion sockets.")
                if market_light != null and market_growth != null:
                    landmark.set_presentation_detail_level(0)
                    var market_light_before := market_light.scale
                    var market_growth_before := market_growth.scale
                    landmark.call("_process", 0.5)
                    _expect(not market_light.scale.is_equal_approx(market_light_before), "Flood Market waterline must pulse as a restrained presentation cue.")
                    _expect(not market_growth.scale.is_equal_approx(market_growth_before), "Flood Market organic growth must carry deterministic presentation motion.")
            if landmark.region_kind == &"archive":
                _expect(landmark.find_child("ArchiveCivicFacade", true, false) != null, "North Ruins must expose an authored civic archive facade.")
                _expect(landmark.find_child("ArchiveVaultDoor", true, false) != null, "North Ruins must expose a readable archive vault entrance.")
                _expect(landmark.find_child("ArchiveRoofBeacon", true, false) != null, "North Ruins must expose a surviving archive beacon silhouette.")
                _expect(landmark.find_child("ArchiveWindowFrameL", true, false) != null and landmark.find_child("ArchiveWindowMullionL", true, false) != null, "North Ruins must expose civic window framing and mullion detail.")
                _expect(landmark.find_child("ArchiveVaultDoorJambL", true, false) != null and landmark.find_child("ArchiveVaultDoorLintel", true, false) != null and landmark.find_child("ArchiveCivicPlaque", true, false) != null, "North Ruins must expose layered vault entrance framing and civic identity detail.")
                _expect(landmark.find_child("ArchiveBeaconCollar", true, false) != null and landmark.find_child("ArchiveBeaconBraceL", true, false) != null, "North Ruins must expose roof beacon service hardware.")
                _expect(landmark.find_child("ArchiveShelfDivider0_0", true, false) != null and landmark.find_child("ArchiveShelfRail0", true, false) != null, "North Ruins must expose archive stack filing hardware.")
                _expect(landmark.find_child("ArchiveOrganicTendril0_0", true, false) != null, "North Ruins organic growth must expose secondary tendril anatomy.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/ArchiveAuthoredModel") != null, "North Ruins must expose its authored civic archive landmark shell.")
                var archive_beacon := landmark.find_child("ArchiveRoofBeaconLight", true, false) as Node3D
                var archive_creep := landmark.find_child("ArchiveOrganicCreep0", true, false) as Node3D
                var archive_collar := landmark.find_child("ArchiveBeaconCollar", true, false) as Node3D
                var archive_tendril := landmark.find_child("ArchiveOrganicTendril0_0", true, false) as Node3D
                _expect(archive_beacon != null and archive_creep != null and archive_collar != null and archive_tendril != null, "North Ruins must expose named beacon, collar, creep and tendril motion sockets.")
                if archive_beacon != null and archive_creep != null and archive_collar != null and archive_tendril != null:
                    landmark.set_presentation_detail_level(0)
                    var beacon_before := archive_beacon.scale
                    var creep_before := archive_creep.scale
                    var collar_before := archive_collar.scale
                    var tendril_before := archive_tendril.rotation
                    landmark.call("_process", 0.5)
                    _expect(not archive_beacon.scale.is_equal_approx(beacon_before), "North Ruins beacon must pulse as a restrained presentation cue.")
                    _expect(not archive_creep.scale.is_equal_approx(creep_before), "North Ruins organic creep must carry deterministic presentation motion.")
                    _expect(not archive_collar.scale.is_equal_approx(collar_before), "North Ruins beacon collar must carry restrained service motion.")
                    _expect(not archive_tendril.rotation.is_equal_approx(tendril_before), "North Ruins organic tendril must carry deterministic presentation motion.")
            if landmark.region_kind == &"greenhouse":
                _expect(landmark.find_child("GreenhouseLightCanopy", true, false) != null, "Municipal Glasshouse must expose an authored light canopy.")
                _expect(landmark.find_child("GreenhouseClimateLouver", true, false) != null, "Municipal Glasshouse must expose readable climate infrastructure.")
                _expect(landmark.find_child("GlasshouseRoofRib0", true, false) != null and landmark.find_child("GlasshousePaneLatch0", true, false) != null, "Municipal Glasshouse must expose secondary roof and glazing hardware.")
                _expect(landmark.find_child("GlasshouseClimateActuator", true, false) != null, "Municipal Glasshouse must expose climate actuator hardware.")
                _expect(landmark.find_child("GreenhouseBrokenSkylight", true, false) != null, "Municipal Glasshouse must expose a broken skylight silhouette.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/GlasshouseAuthoredModel") != null, "Municipal Glasshouse must expose its authored climate-frame landmark shell.")
                _expect(landmark.find_child("GlasshouseBedEdge0", true, false) != null and landmark.find_child("GlasshouseGrowthTendril0_0", true, false) != null and landmark.find_child("GlasshouseLightHousing0", true, false) != null, "Municipal Glasshouse growth beds must expose secondary service and organic detail.")
                var glasshouse_canopy := landmark.find_child("GlasshouseCanopyPulse", true, false) as Node3D
                var glasshouse_growth := landmark.find_child("GlasshouseGrowthPulse0_0", true, false) as Node3D
                var glasshouse_tendril := landmark.find_child("GlasshouseGrowthTendril0_0", true, false) as Node3D
                var glasshouse_actuator := landmark.find_child("GlasshouseClimateActuator", true, false) as Node3D
                _expect(glasshouse_canopy != null and glasshouse_growth != null and glasshouse_tendril != null and glasshouse_actuator != null, "Municipal Glasshouse must expose named canopy, growth, tendril and climate motion sockets.")
                if glasshouse_canopy != null and glasshouse_growth != null and glasshouse_tendril != null and glasshouse_actuator != null:
                    landmark.set_presentation_detail_level(0)
                    var canopy_before := glasshouse_canopy.scale
                    var growth_before := glasshouse_growth.scale
                    var tendril_before := glasshouse_tendril.rotation.z
                    var actuator_before := glasshouse_actuator.rotation.z
                    landmark.call("_process", 0.5)
                    _expect(not glasshouse_canopy.scale.is_equal_approx(canopy_before), "Municipal Glasshouse canopy signal must pulse as a restrained presentation cue.")
                    _expect(not glasshouse_growth.scale.is_equal_approx(growth_before), "Municipal Glasshouse growth must carry deterministic presentation motion.")
                    _expect(not is_equal_approx(glasshouse_tendril.rotation.z, tendril_before), "Municipal Glasshouse organic tendrils must carry deterministic environmental motion.")
                    _expect(not is_equal_approx(glasshouse_actuator.rotation.z, actuator_before), "Municipal Glasshouse climate hardware must carry deterministic functional motion.")
            if landmark.region_kind == &"rail":
                _expect(landmark.find_child("TramMaintenanceBay", true, false) != null, "Tram Graveyard must expose an authored maintenance bay.")
                _expect(landmark.find_child("TramCarriageDoor", true, false) != null, "Tram Graveyard must expose a readable carriage door.")
                _expect(landmark.find_child("TramCarriageAFrontWindow0", true, false) != null and landmark.find_child("TramCarriageAFrontDoor", true, false) != null, "Tram Graveyard must expose approach-facing carriage hardware.")
                _expect(landmark.find_child("TramInspectionPit", true, false) != null, "Tram Graveyard must expose a bounded inspection-pit signature.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/TramGraveyardAuthoredModel") != null, "Tram Graveyard must expose its authored carriage and maintenance landmark shell.")
                var tram_signal := landmark.find_child("TramSignalLamp", true, false) as Node3D
                var tram_seep := landmark.find_child("TramOrganicSeep0", true, false) as Node3D
                _expect(tram_signal != null and tram_seep != null, "Tram Graveyard must expose named signal and organic seepage motion sockets.")
                if tram_signal != null and tram_seep != null:
                    landmark.set_presentation_detail_level(0)
                    var tram_mast := landmark.find_child("TramSignalMast", true, false) as Node3D
                    _expect(tram_mast != null and tram_signal.global_position.distance_to(tram_mast.global_position + Vector3.UP * 3.25) < 0.25, "Tram signal lamp must remain attached to the authored mast socket.")
                    var signal_before := tram_signal.scale
                    var seep_before := tram_seep.scale
                    landmark.call("_process", 0.5)
                    _expect(not tram_signal.scale.is_equal_approx(signal_before), "Tram signal lamp must pulse as a restrained presentation cue.")
                    _expect(not tram_seep.scale.is_equal_approx(seep_before), "Tram organic seepage must carry deterministic presentation motion.")
            if landmark.region_kind == &"observatory":
                _expect(landmark.find_child("ObservatoryOpticsStation", true, false) != null, "Observatory Ridge must expose an authored optics station.")
                _expect(landmark.find_child("ObservatoryLensBarrel", true, false) != null, "Observatory Ridge must expose a readable survey lens.")
                _expect(landmark.find_child("ObservatoryStarMapPanel", true, false) != null, "Observatory Ridge must expose a readable survey console.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/ObservatoryAuthoredModel") != null, "Observatory Ridge must expose its authored radio-observatory landmark shell.")
                _expect(landmark.find_child("ObservatoryServiceDeck", true, false) != null, "Observatory Ridge must expose an authored survey service deck.")
                _expect(landmark.find_child("ObservatoryControlWindow0", true, false) != null, "Observatory Ridge must expose readable control-cabin windows.")
                _expect(landmark.find_child("ObservatoryFrontConsole", true, false) != null, "Observatory Ridge must expose an approach-facing survey console.")
                _expect(landmark.find_child("ObservatorySurveyRail0", true, false) != null, "Observatory Ridge must expose a bounded survey-deck rail silhouette.")
                _expect(landmark.find_child("ObservatoryDishRib0", true, false) != null and landmark.find_child("ObservatoryDishActuator", true, false) != null and landmark.find_child("ObservatoryFeedCollar", true, false) != null, "Observatory Ridge must expose dish structural and feed hardware.")
                _expect(landmark.find_child("ObservatoryMastCollar", true, false) != null and landmark.find_child("ObservatoryDeckPost0", true, false) != null, "Observatory Ridge must expose mast and service-deck hardware.")
                _expect(landmark.find_child("ObservatoryControlWindowFrame0", true, false) != null and landmark.find_child("ObservatoryControlWindowMullion0", true, false) != null and landmark.find_child("ObservatoryFrontConsoleFrame", true, false) != null, "Observatory Ridge must expose cabin and console framing detail.")
                _expect(landmark.find_child("ObservatoryCableAnchor0", true, false) != null and landmark.find_child("ObservatorySurveyLightHousing0", true, false) != null, "Observatory Ridge must expose survey-cable and deck-light hardware.")
                var observatory_dish := landmark.find_child("ObservatoryDish", true, false) as Node3D
                var observatory_feed := landmark.find_child("ObservatoryFeedSignal", true, false) as Node3D
                var observatory_actuator := landmark.find_child("ObservatoryDishActuator", true, false) as Node3D
                var observatory_collar := landmark.find_child("ObservatoryFeedCollar", true, false) as Node3D
                var observatory_mast_collar := landmark.find_child("ObservatoryMastCollar", true, false) as Node3D
                _expect(observatory_dish != null and observatory_feed != null and observatory_actuator != null and observatory_collar != null and observatory_mast_collar != null, "Observatory Ridge must expose named dish, actuator, feed, collar and mast motion sockets.")
                if observatory_dish != null and observatory_feed != null and observatory_actuator != null and observatory_collar != null and observatory_mast_collar != null:
                    var dish_before := observatory_dish.rotation.y
                    var feed_before := observatory_feed.scale
                    var actuator_before := observatory_actuator.rotation
                    var collar_before := observatory_collar.scale
                    var mast_collar_before := observatory_mast_collar.scale
                    landmark.call("_process", 0.5)
                    _expect(absf(observatory_dish.rotation.y - dish_before) > 0.01, "Observatory dish must carry deterministic presentation motion.")
                    _expect(not observatory_feed.scale.is_equal_approx(feed_before), "Observatory feed signal must pulse as a restrained presentation cue.")
                    _expect(not observatory_actuator.rotation.is_equal_approx(actuator_before), "Observatory dish actuator must carry restrained mechanical motion.")
                    _expect(not observatory_collar.scale.is_equal_approx(collar_before), "Observatory feed collar must carry restrained signal motion.")
                    _expect(not observatory_mast_collar.scale.is_equal_approx(mast_collar_before), "Observatory mast collar must carry restrained service motion.")
            if landmark.region_kind == &"waterfront":
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/WaterfrontIdentityDetails/RiverworksSluiceDetails") != null, "Riverworks must expose an authored sluice assembly.")
                _expect(landmark.find_child("RiverWaterlineBreak", true, false) != null, "Riverworks must expose bounded waterline breaks at the dock edge.")
                _expect(landmark.find_child("RiverWaterChannel", true, false) != null, "Riverworks must expose a readable shallow water channel.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/RiverworksAuthoredModel") != null, "Riverworks must expose its authored pump landmark shell.")
                _expect(landmark.find_child("RiverworksPumpPanel", true, false) != null and landmark.find_child("RiverworksRotorHub", true, false) != null and landmark.find_child("RiverworksValveHandle", true, false) != null, "Riverworks must expose pump service and maintenance hardware.")
                _expect(landmark.find_child("RiverworksSluiceRail", true, false) != null and landmark.find_child("RiverworksSluiceLatch", true, false) != null and landmark.find_child("RiverworksSluiceSignalHousing", true, false) != null, "Riverworks must expose layered sluice and flow-signal hardware.")
                _expect(landmark.find_child("RiverworksCableClamp", true, false) != null and landmark.find_child("RiverworksGrowthTendril0_0", true, false) != null, "Riverworks must expose maintenance-cable and organic detail.")
                var riverworks_rotor := landmark.find_child("RiverworksRotor", true, false) as Node3D
                var riverworks_signal := landmark.find_child("RiverworksSluiceSignal", true, false) as Node3D
                var riverworks_valve_handle := landmark.find_child("RiverworksValveHandle", true, false) as Node3D
                var riverworks_signal_housing := landmark.find_child("RiverworksSluiceSignalHousing", true, false) as Node3D
                var riverworks_tendril := landmark.find_child("RiverworksGrowthTendril0_0", true, false) as Node3D
                _expect(riverworks_rotor != null and riverworks_signal != null and riverworks_valve_handle != null and riverworks_signal_housing != null and riverworks_tendril != null, "Riverworks must expose named pump, flow, valve, signal-housing and tendril motion sockets.")
                if riverworks_rotor != null and riverworks_signal != null and riverworks_valve_handle != null and riverworks_signal_housing != null and riverworks_tendril != null:
                    var riverworks_gate := landmark.find_child("RiverworksSluiceGate", true, false) as Node3D
                    var riverworks_rib := landmark.find_child("RiverworksSluiceRib1", true, false) as Node3D
                    _expect(riverworks_gate != null and riverworks_rib != null and riverworks_rib.global_position.distance_to(riverworks_gate.global_position + Vector3(0.0, 0.0, -0.17)) < 0.25, "Riverworks sluice ribs must remain attached to the authored gate assembly.")
                    var rotor_before := riverworks_rotor.rotation.y
                    var signal_before := riverworks_signal.scale
                    var valve_handle_before := riverworks_valve_handle.rotation
                    var signal_housing_before := riverworks_signal_housing.scale
                    var tendril_before := riverworks_tendril.rotation
                    landmark.call("_process", 0.5)
                    _expect(absf(riverworks_rotor.rotation.y - rotor_before) > 0.1, "Riverworks pump rotor must carry deterministic presentation motion.")
                    _expect(not riverworks_signal.scale.is_equal_approx(signal_before), "Riverworks flow signal must pulse as a restrained presentation cue.")
                    _expect(not riverworks_valve_handle.rotation.is_equal_approx(valve_handle_before), "Riverworks maintenance handle must carry restrained service motion.")
                    _expect(not riverworks_signal_housing.scale.is_equal_approx(signal_housing_before), "Riverworks flow-signal housing must carry restrained signal motion.")
                    _expect(not riverworks_tendril.rotation.is_equal_approx(tendril_before), "Riverworks organic tendril must carry deterministic presentation motion.")
            if landmark.region_kind == &"research":
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/BuriedLaboratoriesIdentityDetails") != null, "Buried Laboratories must expose its authored containment vignette.")
                _expect(landmark.find_child("LabContainmentVessel", true, false) != null, "Buried Laboratories must expose readable containment vessels.")
                _expect(landmark.find_child("LabTransferRail", true, false) != null, "Buried Laboratories must expose an overhead transfer rail.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/BuriedLabsAuthoredModel") != null, "Buried Laboratories must expose its authored containment-hall landmark shell.")
                _expect(landmark.find_child("BuriedLabsVesselPort0", true, false) != null and landmark.find_child("BuriedLabsVesselClampL0", true, false) != null, "Buried Laboratories must expose vessel service ports and clamps.")
                _expect(landmark.find_child("BuriedLabsTransferCarriage", true, false) != null and landmark.find_child("BuriedLabsTransferRailStopL", true, false) != null, "Buried Laboratories must expose transfer-carriage and rail-stop detail.")
                _expect(landmark.find_child("BuriedLabsContainmentDoorJambL", true, false) != null and landmark.find_child("BuriedLabsContainmentDoorLintel", true, false) != null and landmark.find_child("BuriedLabsWarningPanelFrame", true, false) != null, "Buried Laboratories must expose layered sealed-door and warning-panel framing.")
                _expect(landmark.find_child("BuriedLabsCableClamp0", true, false) != null and landmark.find_child("BuriedLabsOrganicTendril0_0", true, false) != null, "Buried Laboratories must expose service-cable and organic detail.")
                var labs_light := landmark.find_child("BuriedLabsVesselLight0", true, false) as Node3D
                var labs_seep := landmark.find_child("BuriedLabsOrganicSeep0", true, false) as Node3D
                var labs_port := landmark.find_child("BuriedLabsVesselPort0", true, false) as Node3D
                var labs_carriage := landmark.find_child("BuriedLabsTransferCarriage", true, false) as Node3D
                var labs_tendril := landmark.find_child("BuriedLabsOrganicTendril0_0", true, false) as Node3D
                _expect(labs_light != null and labs_seep != null and labs_port != null and labs_carriage != null and labs_tendril != null, "Buried Laboratories must expose named light, port, carriage, seep and tendril motion sockets.")
                if labs_light != null and labs_seep != null and labs_port != null and labs_carriage != null and labs_tendril != null:
                    landmark.set_presentation_detail_level(0)
                    var labs_light_before := labs_light.scale
                    var labs_seep_before := labs_seep.scale
                    var labs_port_before := labs_port.rotation
                    var labs_carriage_before := labs_carriage.position
                    var labs_tendril_before := labs_tendril.rotation
                    landmark.call("_process", 0.5)
                    _expect(not labs_light.scale.is_equal_approx(labs_light_before), "Buried Laboratories containment light must pulse as a restrained presentation cue.")
                    _expect(not labs_seep.scale.is_equal_approx(labs_seep_before), "Buried Laboratories organic contamination must carry deterministic presentation motion.")
                    _expect(not labs_port.rotation.is_equal_approx(labs_port_before), "Buried Laboratories vessel port must carry restrained service motion.")
                    _expect(not labs_carriage.position.is_equal_approx(labs_carriage_before), "Buried Laboratories transfer carriage must carry restrained mechanical motion.")
                    _expect(not labs_tendril.rotation.is_equal_approx(labs_tendril_before), "Buried Laboratories organic tendril must carry deterministic presentation motion.")
            if landmark.region_kind == &"tenement":
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/AuthoredEncounterDressing/TenementVerticalLifeDetails") != null, "East Tenements must expose an authored vertical residential vignette.")
                _expect(landmark.find_child("TenementFireEscapeLadder", true, false) != null, "East Tenements must expose a readable fire-escape route signature.")
                _expect(landmark.find_child("TenementRoofWaterTank", true, false) != null, "East Tenements must expose a rooftop service identity.")
                _expect(landmark.find_child("TenementFrontWindowL0_0", true, false) != null and landmark.find_child("TenementBlockLEdgeL", true, false) != null, "East Tenements must expose approach-facing windows and facade edge breaks.")
                _expect(landmark.find_child("TenementFrontWindowLintelL0_0", true, false) != null and landmark.find_child("TenementFrontWindowSillL0_0", true, false) != null, "East Tenements must expose approach-facing window framing detail.")
                _expect(landmark.find_child("TenementBalconyBrace0_L", true, false) != null and landmark.find_child("TenementTankValve", true, false) != null, "East Tenements must expose structural balcony and roof-tank service detail.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/TenementAuthoredModel") != null, "East Tenements must expose its authored residential block landmark shell.")
                var tenement_creep := landmark.find_child("TenementOrganicCreep0", true, false) as Node3D
                _expect(tenement_creep != null, "East Tenements must expose a named organic-creep motion socket.")
                _expect(landmark.find_child("TenementLaundryLine0", true, false) != null and landmark.find_child("TenementLightHousingL", true, false) != null and landmark.find_child("TenementOrganicTendril0_0", true, false) != null, "East Tenements must expose lived-in laundry, window-light and organic detail.")
                if tenement_creep != null:
                    landmark.set_presentation_detail_level(0)
                    var tenement_ladder := landmark.find_child("TenementFireEscapeLadder", true, false) as Node3D
                    var tenement_rail := landmark.find_child("TenementFireEscapeRail", true, false) as Node3D
                    _expect(tenement_ladder != null and tenement_rail != null and tenement_rail.global_position.distance_to(tenement_ladder.global_position + Vector3(0.0, 0.0, 1.5)) < 0.25, "East Tenements fire-escape rail must remain attached to the authored ladder.")
                    var tenement_before := tenement_creep.scale
                    landmark.call("_process", 0.5)
                    _expect(not tenement_creep.scale.is_equal_approx(tenement_before), "East Tenements organic creep must carry deterministic presentation motion.")
    var region_atmosphere := world.get_node_or_null("RegionAtmosphereDirector") as RegionAtmosphereDirector3D
    _expect(region_atmosphere != null, "The complete world must install region-aware atmosphere presentation.")
    if region_atmosphere != null:
        var industrial_palette := region_atmosphere.palette_for_kind(&"industrial")
        var endgame_palette := region_atmosphere.palette_for_kind(&"endgame")
        _expect(float(industrial_palette.get("fog_density", 0.0)) > float(region_atmosphere.palette_for_kind(&"sanctuary").get("fog_density", 0.0)), "Industrial regions must carry a denser particulate atmosphere than the sanctuary.")
        _expect(industrial_palette.get("fog") != endgame_palette.get("fog"), "Late organic regions must have a distinct fog palette from industrial districts.")
        world.player.global_position = Vector3(-92.0, 0.0, 18.0)
        var audio_event_count_before_region := audio_director.event_count if audio_director != null else 0
        region_atmosphere.refresh_now()
        _expect(region_atmosphere.current_region_id == &"region.west_grid", "Moving the player to West Grid must select the persistent industrial region.")
        _expect(region_atmosphere.current_kind == &"industrial", "West Grid must resolve to its authored industrial atmosphere kind.")
        if audio_director != null:
            _expect(audio_director.event_count > audio_event_count_before_region, "Crossing into a region must emit one restrained spatial transition cue.")
            _expect(audio_director.last_profile == &"region_transition", "Region crossing audio must use the dedicated transition profile.")
            audio_director.stop_all()
    var region_lod := world.get_node_or_null("RegionPresentationLodDirector") as RegionPresentationLodDirector3D
    _expect(region_lod != null, "The complete world must install presentation LOD for persistent region landmarks.")
    if region_lod != null and region_atmosphere != null:
        region_lod.refresh_now()
        _expect(region_lod.detail_mode_for(&"region.west_grid") == 0, "The player’s current region must retain full landmark detail.")
        _expect(region_lod.detail_mode_for(&"region.root_cistern") == 2, "Distant endgame landmarks must reduce to beacon detail without leaving the world state.")
    var heartforge := world.get_node_or_null("Heartforge") as Heartforge3D
    _expect(heartforge != null, "The aesthetic test needs the Heartforge progression model.")
    if heartforge != null:
        _expect(heartforge.find_child("CoreCladdingDetail", true, false) != null, "The Heartforge must expose a layered high-definition core cladding detail.")
        _expect(heartforge.find_child("CoreServiceLouver", true, false) != null, "The Heartforge must expose a readable powered service louver.")
        _expect(heartforge.find_child("CoreInspectionPort", true, false) != null, "The Heartforge must expose a readable inspection port.")
        heartforge.set_progression_tier(5)
        _expect(heartforge.find_child("AdaptiveHeartforgeGeometry", true, false) != null, "Heartforge progression must own a dedicated adaptive geometry layer.")
        _expect(heartforge.find_child("Tier2Buttress", true, false) != null, "Tier 2 Heartforge geometry must add structural buttresses.")
        _expect(heartforge.find_child("Tier3SignalConduit", true, false) != null, "Tier 3 Heartforge geometry must add signal conduits.")
        _expect(heartforge.find_child("Tier4SignalMast", true, false) != null, "Tier 4 Heartforge geometry must add the signal mast.")
        _expect(heartforge.find_child("Tier5SovereigntyCrown", true, false) != null, "Tier 5 Heartforge geometry must culminate in a readable crown.")

    var environment_node := _find_world_environment(world)
    _expect(environment_node != null and environment_node.environment != null, "The world needs a configured environment.")
    if environment_node != null and environment_node.environment != null:
        var environment := environment_node.environment
        _expect(environment.ambient_light_energy >= 0.45, "The overhaul must remain readable rather than pitch-black.")
        _expect(environment.fog_density <= 0.015, "Fog may shape depth but must not crush visibility.")
        _expect(environment.tonemap_mode == Environment.TONE_MAPPER_ACES, "ACES tonemapping should provide stable cinematic contrast.")

    var player := get_first_node_in_group("player_character") as Node3D
    _expect(player != null, "The aesthetic test needs the Mechromancer.")
    if player != null:
        var player_presentation := player.get_node_or_null("MechromancerPresentation3D") as MechromancerPresentation3D
        _expect(player_presentation != null, "The Mechromancer must receive authored animation presentation.")
        _expect(_find_named(player, "ProductionAssetMarker") != null, "The Mechromancer must use the authored asset contract.")
        _expect(_find_named(player, "PistolMuzzle") != null, "The authored Mechromancer must expose the pistol muzzle socket.")
        _expect(_model_has_details(player), "The Mechromancer must receive additional authored silhouette detail.")
        _expect(_find_named(player, "FieldShoulderGuard") != null and _find_named(player, "FieldCommsPanel") != null and _find_named(player, "FieldCommsBeacon") != null, "The Mechromancer must carry the finished asymmetrical field-kit silhouette.")
        var player_model := player.get_node_or_null("MechromancerModel") as Node3D
        _expect(player_model != null and player_model.scale.x >= 1.2, "The authored Mechromancer must be legible at tactical-camera distance.")
        _expect(_find_named(player, "RespiratorCollarCore") != null and _find_named(player, "FieldPackCornerCap") != null, "The Mechromancer must receive beveled authored equipment surfaces.")
        if player_presentation != null:
            _expect(player_presentation.animation_player != null, "The authored Mechromancer must expose an imported animation player.")
            if player_presentation.animation_player != null:
                for clip_name in [&"Idle", &"Walk", &"Fire", &"Work", &"Hit"]:
                    _expect(_animation_player_has_clip(player_presentation.animation_player, clip_name), "The authored Mechromancer must expose the %s animation clip." % clip_name)
        if audio_director != null:
            var event_count_before := audio_director.event_count
            audio_director.play_profile(&"pistol", player.global_position)
            _expect(audio_director.event_count == event_count_before + 1, "The spatial audio director must emit a pistol event at runtime.")
            audio_director.stop_all()

    var robots := get_nodes_in_group("friendly_robots")
    _expect(not robots.is_empty(), "The opening companion must exist.")
    if not robots.is_empty():
        var robot := robots[0] as Node3D
        _expect(robot.get_node_or_null("ProceduralAnimator3D") is ProceduralAnimator3D, "Robots must receive procedural gait and recoil animation.")
        _expect(_model_has_details(robot), "Robots must receive additional role-readable detail.")
        _expect(_find_named(robot, "ShoulderPlate") != null, "Robots must expose layered shoulder armour.")
        _expect(_find_named(robot, "ChassisDetailPanel") != null, "Robots must expose a layered high-detail chassis panel.")
        _expect(_find_named(robot, "Chassis") != null and _find_named(robot, "ChassisCore") != null and _find_named(robot, "ChassisCornerCap") != null, "Robots must use the original beveled chassis treatment.")
        _expect(_find_named(robot, "OpticLens") != null, "Robots must expose a readable optic lens.")
        _expect(_find_named(robot, "CompanionCrown") != null, "The companion must expose a distinct crown silhouette.")
        _expect(_find_named(robot, "BulwarkShieldArc") != null, "The Bulwark must expose a readable protection field signature.")
        _expect(_find_named(robot, "BulwarkShieldEmitter") != null, "The Bulwark must expose a dedicated shield emitter.")
        var shield_arc := _find_named(robot, "BulwarkShieldArc") as MeshInstance3D
        if shield_arc != null:
            var shield_mesh := shield_arc.mesh as TorusMesh
            var shield_material := shield_arc.material_override as StandardMaterial3D
            _expect(shield_mesh != null and shield_mesh.outer_radius <= 0.8, "The Bulwark protection arc must stay compact at tactical distance.")
            _expect(shield_material != null and shield_material.emission_energy_multiplier <= 1.0, "The Bulwark protection arc must preserve the Heartforge focal hierarchy.")
        _expect(_find_named(robot, "BulwarkAuthoredModel") != null, "The opening companion must use the authored Bulwark model shell.")
        _expect(_find_named(robot, "ProductionAssetMarker") != null, "The authored Bulwark model must expose its production asset marker.")

    var role_samples: Array[RobotUnit3D] = []
    var role_names := [&"salvager", &"guardian", &"scout", &"engineer"]
    for index in role_names.size():
        var sample := ROBOT_SCENE.instantiate() as RobotUnit3D
        sample.configure(role_names[index], 1)
        sample.position = Vector3(15.0 + float(index) * 2.4, 0.0, 10.0)
        root.add_child(sample)
        role_samples.append(sample)
    await process_frame
    for index in role_samples.size():
        _expect(_role_model_has_details(role_samples[index], role_names[index]), "The %s robot must expose a role-readable high-detail silhouette." % role_names[index])
        if role_names[index] == &"salvager":
            _expect(_find_named(role_samples[index], "ScrapperAuthoredModel") != null, "The salvager must use the authored Scrapper model shell.")
            _expect(_find_named(role_samples[index], "ProductionAssetMarker") != null, "The authored Scrapper model must expose its production asset marker.")
        elif role_names[index] == &"scout":
            _expect(_find_named(role_samples[index], "PathfinderAuthoredModel") != null, "The scout must use the authored Pathfinder model shell.")
            _expect(_find_named(role_samples[index], "ProductionAssetMarker") != null, "The authored Pathfinder model must expose its production asset marker.")
        elif role_names[index] == &"engineer":
            _expect(_find_named(role_samples[index], "EngineerAuthoredModel") != null, "The engineer must use the authored Engineer model shell.")
            _expect(_find_named(role_samples[index], "ProductionAssetMarker") != null, "The authored Engineer model must expose its production asset marker.")
        role_samples[index].queue_free()

    var authored_warden := ROBOT_SCENE.instantiate() as RobotUnit3D
    authored_warden.configure(&"guardian", 1)
    authored_warden.position = Vector3(30.0, 0.0, 28.0)
    root.add_child(authored_warden)
    await process_frame
    _expect(_find_named(authored_warden, "WardenAuthoredModel") != null, "The guardian must use the authored Warden model shell.")
    _expect(_find_named(authored_warden, "ProductionAssetMarker") != null, "The authored Warden model must expose its production asset marker.")
    authored_warden.queue_free()

    var evolved_robot := ROBOT_SCENE.instantiate() as RobotUnit3D
    evolved_robot.configure(&"guardian", 3)
    evolved_robot.position = Vector3(20.0, 0.0, 28.0)
    root.add_child(evolved_robot)
    await process_frame
    _expect(_find_named(evolved_robot, "Tier2ShoulderRail") != null, "Level 3 frames must expose the evolved shoulder rail finish.")
    _expect(_find_named(evolved_robot, "Tier2DorsalServicePanel") != null, "Level 3 frames must expose the evolved dorsal service panel.")
    _expect(_find_named(evolved_robot, "Tier3CrownRing") != null and _find_named(evolved_robot, "Tier3CrownBeacon") != null, "Level 3 frames must culminate in a readable crown and status beacons.")
    evolved_robot.queue_free()

    var outpost_samples: Array[Outpost3D] = []
    var outpost_roles := [&"resource", &"defence", &"scout", &"repair"]
    for index in outpost_roles.size():
        var outpost := OUTPOST_SCENE.instantiate() as Outpost3D
        outpost.configure(StringName("aesthetic.site.%d" % index), outpost_roles[index], 3, world.run_state)
        outpost.position = Vector3(42.0 + float(index) * 7.0, 0.0, 12.0)
        root.add_child(outpost)
        outpost_samples.append(outpost)
    await process_frame
    for index in outpost_samples.size():
        var sample := outpost_samples[index]
        _expect(_find_named(sample, "OutpostRoleSignature") != null, "Outposts must expose one bounded role-signature presentation root.")
        _expect(_find_named(sample, "CoreShelterCore") != null and _find_named(sample, "CoreVent") != null, "Outposts must use the high-definition shelter and service-surface treatment.")
        _expect(_find_named(sample, "TierFrame1") != null and _find_named(sample, "TierFrame2") != null and _find_named(sample, "TierFrame3") != null, "Tier 3 outposts must expose three stable structural frames.")
        _expect(_outpost_model_has_details(sample, outpost_roles[index]), "The %s outpost must expose a role-readable high-detail silhouette." % outpost_roles[index])
        sample.queue_free()

    var enemy_samples: Array[OrganicEnemy3D] = []
    var species_names := [&"skitterling", &"razorhound", &"roofleaper", &"glassmoth", &"veilstalker", &"burrower", &"sporecaster", &"broodmass", &"miremaw", &"carrionbell", &"rootweaver", &"apex"]
    var sample_player := get_first_node_in_group("player_character") as Node3D
    var sample_forge := world.get_node_or_null("Heartforge") as Node3D
    for index in species_names.size():
        var sample := ENEMY_SCENE.instantiate() as OrganicEnemy3D
        sample.configure(species_names[index], sample_player, sample_forge)
        sample.position = Vector3(20.0 + float(index) * 2.4, 0.0, 18.0)
        root.add_child(sample)
        enemy_samples.append(sample)
    await process_frame
    for index in enemy_samples.size():
        _expect(_enemy_model_has_details(enemy_samples[index], species_names[index]), "The %s organic family must expose a role-readable silhouette." % species_names[index])
        _expect(_find_named(enemy_samples[index], "OrganicDorsalPlate") != null, "The %s organic family must expose a layered shell material break." % species_names[index])
        _expect(_find_named(enemy_samples[index], "TorsoCore") != null and _find_named(enemy_samples[index], "TorsoSegment0") != null, "The %s organic family must expose segmented high-definition torso anatomy." % species_names[index])
        if species_names[index] == &"razorhound":
            _expect(_find_named(enemy_samples[index], "RazorhoundAuthoredModel") != null and _find_named(enemy_samples[index], "ProductionAssetMarker") != null, "The Razorhound must expose its authored production asset contract.")
        if species_names[index] in [&"roofleaper", &"glassmoth", &"miremaw", &"carrionbell", &"rootweaver"]:
            var authored_marker_name := "%sAuthoredModel" % String(species_names[index]).capitalize()
            _expect(_find_named(enemy_samples[index], authored_marker_name) != null and _find_named(enemy_samples[index], "ProductionAssetMarker") != null, "The %s must expose its authored production asset contract." % species_names[index])
        match species_names[index]:
            &"roofleaper":
                _expect(_find_named(enemy_samples[index], "RoofleaperFineVeinL") != null and _find_named(enemy_samples[index], "RoofleaperFineVeinR") != null, "The Roofleaper must expose fine vascular wing detail on both membranes.")
            &"glassmoth":
                _expect(_find_named(enemy_samples[index], "GlassmothFineVeinL0") != null and _find_named(enemy_samples[index], "GlassmothFineVeinR0") != null, "The Glassmoth must expose fine luminous wing-vein detail on both wing pairs.")
            &"miremaw":
                _expect(_find_named(enemy_samples[index], "MiremawGillRidgeL") != null and _find_named(enemy_samples[index], "MiremawGillRidgeR") != null, "The Miremaw must expose layered gill-ridge surface detail.")
            &"carrionbell":
                _expect(_find_named(enemy_samples[index], "CarrionbellResonatorRing") != null, "The Carrion Bell must expose a raised resonator lip for its signal anatomy.")
            &"rootweaver":
                _expect(_find_named(enemy_samples[index], "RootweaverKnuckleL") != null and _find_named(enemy_samples[index], "RootweaverKnuckleR") != null, "The Rootweaver must expose joint detail where its route arms meet the body.")
        if species_names[index] == &"apex":
            var apex_crown := _find_named(enemy_samples[index], "ApexCrown") as Node3D
            var apex_plate := _find_named(enemy_samples[index], "ApexCrownPlate") as Node3D
            _expect(apex_crown != null and apex_plate != null and apex_plate.position.distance_to(Vector3(0.0, 0.3, 0.16)) < 0.01, "Cistern Apex crown plating must remain attached through a local authored socket.")
        if species_names[index] == &"broodmass":
            var brood_maw := _find_named(enemy_samples[index], "BroodmassMaw") as Node3D
            var brood_plate := _find_named(enemy_samples[index], "BroodmassMawPlate") as Node3D
            var brood_hook := _find_named(enemy_samples[index], "BroodmassMawHookL") as Node3D
            _expect(brood_maw != null and brood_plate != null and brood_hook != null and brood_plate.position.distance_to(Vector3(0.0, 0.24, -0.02)) < 0.01 and brood_hook.position.distance_to(Vector3(-0.34, -0.42, -0.24)) < 0.01, "Broodmass maw hardware must remain attached through local authored sockets.")
        if species_names[index] == &"sporecaster":
            var spore_cowl := _find_named(enemy_samples[index], "SporecasterCowl") as Node3D
            var spore_oculus := _find_named(enemy_samples[index], "SporecasterOculusL") as Node3D
            var spore_plate := _find_named(enemy_samples[index], "SporecasterCowlPlateL") as Node3D
            _expect(spore_cowl != null and spore_oculus != null and spore_plate != null and spore_oculus.position.distance_to(Vector3(-0.23, 0.16, -0.39)) < 0.01 and spore_plate.position.distance_to(Vector3(-0.32, 0.08, -0.09)) < 0.01, "Sporecaster sensory-cowl details must remain attached through local authored sockets.")
        _expect_family_attack_motion(enemy_samples[index], _family_attack_signature_node(species_names[index]))
        enemy_samples[index].queue_free()

    var veilstalker: Node3D
    for enemy in get_nodes_in_group("organic_enemies"):
        if not enemy is Node3D:
            continue
        var species_value: Variant = enemy.get("species")
        if species_value != null and StringName(str(species_value)) == &"veilstalker":
            veilstalker = enemy as Node3D
            break
    _expect(veilstalker != null, "The opening presentation needs a visible Veilstalker family member.")
    if veilstalker != null:
        var veilstalker_animator := veilstalker.get_node_or_null("ProceduralAnimator3D") as ProceduralAnimator3D
        _expect(veilstalker_animator != null, "The authored organic family must receive readable motion presentation.")
        _expect(veilstalker.find_child("VeilstalkerCowl", true, false) != null, "The Veilstalker must expose a distinct sensory crown silhouette.")
        _expect(veilstalker.find_child("VeilstalkerVeil", true, false) != null, "The Veilstalker must expose layered membrane anatomy.")
        _expect(veilstalker.find_child("VeilstalkerTendril", true, false) != null, "The Veilstalker must expose readable sensory tendrils.")
        _expect(veilstalker.find_child("VeilstalkerThoraxDorsalRib", true, false) != null, "The Veilstalker must expose a ribbed high-detail thorax construction.")
        _expect(veilstalker.find_child("VeilstalkerAuthoredModel", true, false) != null and _find_named(veilstalker, "ProductionAssetMarker") != null, "The Veilstalker must expose its authored production asset contract.")

    var beautiful_hud := get_first_node_in_group("beautiful_hud")
    _expect(beautiful_hud is IronwrightBeautifulHUD3D, "The native HUD must use the quieter cinematic skin.")
    if beautiful_hud is IronwrightHUD3D:
        _expect((beautiful_hud as IronwrightHUD3D).player_portrait != null, "The HUD must expose the Mechromancer portrait.")
        _expect((beautiful_hud as IronwrightHUD3D).player_portrait.texture != null, "The Mechromancer portrait must have a texture.")
        _expect(not (beautiful_hud as IronwrightHUD3D).player_portrait.visible, "The tactical HUD must keep the portrait asset out of the world frame so it cannot expand into a screen-fixed figure.")
    if beautiful_hud is IronwrightBeautifulHUD3D:
        var cinematic_hud := beautiful_hud as IronwrightBeautifulHUD3D
        cinematic_hud._process(IronwrightBeautifulHUD3D.TACTICAL_HINT_SECONDS + 2.0)
        _expect(not cinematic_hud.help_label.visible, "The cinematic HUD must clear the permanent control legend after onboarding.")
        _expect(cinematic_hud.sanctuary_badge != null and not cinematic_hud.sanctuary_badge.visible, "The healthy sanctuary badge must fade from the tactical frame.")
        cinematic_hud.set_sanctuary_integrity(0.45)
        _expect(cinematic_hud.sanctuary_badge.visible, "Critical sanctuary status must reappear as a relevant exception.")

    var omni_count := _count_omni_lights(world)
    _expect(omni_count >= 10, "The environment must use deliberate local practical lighting instead of global darkness.")

    var opening_slice := world.get_node_or_null("HeartforgeVerticalSlice") as Node3D
    _expect(opening_slice != null, "The opening lighting pass must remain attached to the Heartforge vertical slice.")
    if opening_slice != null:
        var opening_roles: Dictionary = {}
        var strongest_opening_light := 0.0
        for child in opening_slice.get_children():
            if not child is OmniLight3D:
                continue
            var opening_light := child as OmniLight3D
            var role: Variant = opening_light.get_meta(&"opening_light_role", &"")
            if role != &"":
                opening_roles[role] = true
                strongest_opening_light = maxf(strongest_opening_light, float(opening_light.get_meta(&"vertical_base_energy", opening_light.light_energy)))
        _expect(opening_roles.has(&"heartforge_key"), "The opening lighting hierarchy must retain a warm Heartforge key light.")
        _expect(opening_roles.has(&"cool_route"), "The opening lighting hierarchy must retain a cool route separation light.")
        _expect(strongest_opening_light <= 2.3, "The opening key light must avoid washing the wet district surface into a white pool.")

    var opening_environment := _find_world_environment(world)
    if opening_environment != null and opening_environment.environment != null:
        _expect(opening_environment.environment.glow_bloom <= 0.08, "The opening bloom budget must keep puddles and concrete readable.")

    var atmosphere := world.get_node_or_null("RegionAtmosphereDirector") as RegionAtmosphereDirector3D
    if atmosphere != null:
        var sanctuary_palette: Dictionary = atmosphere.palette_for_kind(&"sanctuary")
        _expect(float(sanctuary_palette.get("glow", 1.0)) <= 0.46, "The opening sanctuary palette must preserve material separation around the Heartforge.")

    if failures.is_empty():
        print("Project Ironwright aesthetic overhaul tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Project Ironwright aesthetic overhaul tests failed: %d" % failures.size())
    quit(1)


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _find_world_environment(node: Node) -> WorldEnvironment:
    if node is WorldEnvironment:
        return node as WorldEnvironment
    for child in node.get_children():
        var nested := _find_world_environment(child)
        if nested != null:
            return nested
    return null


func _count_omni_lights(node: Node) -> int:
    var count := 1 if node is OmniLight3D else 0
    for child in node.get_children():
        count += _count_omni_lights(child)
    return count


func _model_has_details(actor: Node3D) -> bool:
    for model_name in ["MechromancerModel", "RobotModel", "OrganicModel"]:
        var model := actor.get_node_or_null(NodePath(model_name))
        if model != null and model.get_node_or_null("AestheticDetails") != null:
            return true
    return false


func _find_named(root: Node, node_name: String) -> Node:
    return root.find_child(node_name, true, false)


func _animation_player_has_clip(player: AnimationPlayer, clip_name: StringName) -> bool:
    if player.has_animation(clip_name):
        return true
    for candidate in player.get_animation_list():
        if String(candidate).ends_with("/" + String(clip_name)) or String(candidate).ends_with(String(clip_name)):
            return true
    return false


func _family_attack_signature_node(species: StringName) -> StringName:
    match species:
        &"skitterling": return &"SkitterlingMandibleL"
        &"razorhound": return &"RazorhoundSnout"
        &"roofleaper": return &"RoofleaperWingL"
        &"glassmoth": return &"GlassmothWingL0"
        &"veilstalker": return &"VeilstalkerVeil"
        &"burrower": return &"BurrowerDrill"
        &"sporecaster": return &"SporecasterSac0"
        &"broodmass": return &"BroodmassMaw"
        &"miremaw": return &"MiremawJawHookL"
        &"carrionbell": return &"CarrionbellResonator"
        &"rootweaver": return &"RootweaverArmL"
        &"apex": return &"ApexJawL"
    return &""


func _expect_family_attack_motion(enemy: OrganicEnemy3D, signature_name: StringName) -> void:
    if enemy == null or signature_name == &"":
        return
    var animator := enemy.get_node_or_null("ProceduralAnimator3D") as ProceduralAnimator3D
    var signature := _find_named(enemy, signature_name) as Node3D
    _expect(animator != null and signature != null, "%s must expose a runtime attack signature node and animator." % enemy.get("species"))
    if animator == null or signature == null:
        return
    var before := signature.transform
    var previous_state: StringName = StringName(enemy.get(&"state_name"))
    var previous_windup := float(enemy.get(&"attack_windup_remaining"))
    enemy.set(&"state_name", &"attacking")
    enemy.set(&"attack_windup_remaining", 0.34)
    animator._restore_base_transforms()
    animator._animate_organic(0.0)
    _expect(signature.transform != before, "%s attack wind-up must visibly load its authored family signature." % enemy.get("species"))
    enemy.set(&"state_name", previous_state)
    enemy.set(&"attack_windup_remaining", previous_windup)


func _role_model_has_details(robot: RobotUnit3D, role: StringName) -> bool:
    if robot == null or robot.get_node_or_null("RobotModel") == null:
        return false
    match role:
        &"salvager":
            return _find_named(robot, "CargoLip") != null and _find_named(robot, "DismantlerTool") != null and _find_named(robot, "SalvageDrum") != null and _find_named(robot, "ScrapperIntake") != null
        &"guardian":
            return _find_named(robot, "WeaponBarrel") != null and _find_named(robot, "WeaponMuzzle") != null and _find_named(robot, "ShieldRib") != null and _find_named(robot, "WardenHeatExchanger") != null
        &"scout":
            return _find_named(robot, "ScoutFin") != null and _find_named(robot, "BeaconRing") != null and _find_named(robot, "ScoutOptic") != null and _find_named(robot, "PathfinderSensorPod") != null
        &"engineer":
            return _find_named(robot, "PistonJoint") != null and _find_named(robot, "ToolHead") != null and _find_named(robot, "ForgeCoil") != null
    return false


func _outpost_model_has_details(outpost: Outpost3D, role: StringName) -> bool:
    if outpost == null or outpost.get_node_or_null("OutpostModel") == null:
        return false
    match role:
        &"resource":
            return _find_named(outpost, "ResourceHopper") != null and _find_named(outpost, "ResourceHopperLouver") != null and _find_named(outpost, "ResourceExtractorArm") != null
        &"defence":
            return _find_named(outpost, "DefenceTurretHousing") != null and _find_named(outpost, "DefenceBarrel") != null and _find_named(outpost, "DefenceMuzzleGlow") != null
        &"scout":
            return _find_named(outpost, "ScoutSensorHousing") != null and _find_named(outpost, "ScoutSensorDish") != null and _find_named(outpost, "ScoutDishRib") != null
        &"repair":
            return _find_named(outpost, "RepairPad") != null and _find_named(outpost, "RepairPadPanel") != null and _find_named(outpost, "RepairFieldEmitter") != null
    return false


func _enemy_model_has_details(enemy: OrganicEnemy3D, species: StringName) -> bool:
    if enemy == null or enemy.get_node_or_null("OrganicModel") == null:
        return false
    match species:
        &"skitterling":
            return _find_named(enemy, "SkitterlingCarapace0") != null and _find_named(enemy, "SkitterlingAntennaL") != null and _find_named(enemy, "SkitterlingMandibleL") != null
        &"razorhound":
            return _find_named(enemy, "RazorhoundSnout") != null and _find_named(enemy, "RazorhoundTail") != null and _find_named(enemy, "RazorhoundSpine") != null
        &"veilstalker":
            return _find_named(enemy, "VeilstalkerCowl") != null and _find_named(enemy, "VeilstalkerVeil") != null and _find_named(enemy, "VeilstalkerTendril") != null
        &"burrower":
            return _find_named(enemy, "BurrowerDrill") != null and _find_named(enemy, "BurrowerTip") != null and _find_named(enemy, "BurrowerLampL") != null
        &"sporecaster":
            return _find_named(enemy, "SporecasterSac0") != null and _find_named(enemy, "SporecasterStem0") != null and _find_named(enemy, "SporecasterOculusL") != null
        &"broodmass":
            return _find_named(enemy, "BroodmassLobeL") != null and _find_named(enemy, "CrownSpine0") != null and _find_named(enemy, "BroodmassMaw") != null
        &"apex":
            return _find_named(enemy, "ApexCrown") != null and _find_named(enemy, "ApexJawL") != null and _find_named(enemy, "ApexMembraneL") != null
        &"roofleaper":
            return _find_named(enemy, "RoofleaperCrown") != null and _find_named(enemy, "RoofleaperWingL") != null and _find_named(enemy, "RoofleaperTalonsL") != null
        &"glassmoth":
            return _find_named(enemy, "GlassmothThorax") != null and _find_named(enemy, "GlassmothWingL0") != null and _find_named(enemy, "GlassmothAntennaL") != null
        &"miremaw":
            return _find_named(enemy, "MiremawHead") != null and _find_named(enemy, "MiremawJawHookL") != null and _find_named(enemy, "MiremawGillFan") != null
        &"carrionbell":
            return _find_named(enemy, "CarrionbellMantle") != null and _find_named(enemy, "CarrionbellCrownPlate") != null and _find_named(enemy, "CarrionbellResonator") != null
        &"rootweaver":
            return _find_named(enemy, "RootweaverCrown") != null and _find_named(enemy, "RootweaverArmL") != null and _find_named(enemy, "RootweaverSporeFan") != null
    return false
