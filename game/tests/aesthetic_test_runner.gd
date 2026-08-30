extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")
const ROBOT_SCENE := preload("res://scenes/actors/robot_unit_3d.tscn")
const ENEMY_SCENE := preload("res://scenes/actors/organic_enemy_3d.tscn")
const MECHROMANCER_SCENE := preload("res://scenes/actors/mechromancer_3d.tscn")
const OUTPOST_SCENE := preload("res://scenes/world/outpost_3d.tscn")
const SCRAPPER_ASSET_SCENE := preload("res://assets/scrapper/scrapper.gltf")
const PATHFINDER_ASSET_SCENE := preload("res://assets/pathfinder/pathfinder.gltf")
const ENGINEER_ASSET_SCENE := preload("res://assets/engineer/engineer.gltf")
const RAZORHOUND_ASSET_SCENE := preload("res://assets/razorhound/razorhound.gltf")
const SPORECASTER_ASSET_SCENE := preload("res://assets/sporecaster/sporecaster.gltf")
const SKITTERLING_ASSET_SCENE := preload("res://assets/skitterling/skitterling.gltf")
const ROOFLEAPER_ASSET_SCENE := preload("res://assets/roofleaper/roofleaper.gltf")
const GLASSMOTH_ASSET_SCENE := preload("res://assets/glassmoth/glassmoth.gltf")
const VEILSTALKER_ASSET_SCENE := preload("res://assets/veilstalker/veilstalker.gltf")
const BURROWER_ASSET_SCENE := preload("res://assets/burrower/burrower.gltf")
const BROODMASSS_ASSET_SCENE := preload("res://assets/broodmass/broodmass.gltf")
const MIREMAW_ASSET_SCENE := preload("res://assets/miremaw/miremaw.gltf")
const CARRIONBELL_ASSET_SCENE := preload("res://assets/carrionbell/carrionbell.gltf")
const ROOTWEAVER_ASSET_SCENE := preload("res://assets/rootweaver/rootweaver.gltf")
const THORNBACK_ASSET_SCENE := preload("res://assets/thornback/thornback.gltf")
const ASHMANTLE_ASSET_SCENE := preload("res://assets/ashmantle/ashmantle.gltf")

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
    var startup_lod := world.get_node_or_null("RegionPresentationLodDirector") as RegionPresentationLodDirector3D
    _expect(startup_lod != null and startup_lod.streamed_region_count() < 11, "Startup must keep the authored stream ring bounded instead of importing every remote district before the first frame.")
    if startup_lod != null:
        _expect(not startup_lod.is_region_streamed(&"region.root_cistern"), "The distant endgame package must remain unloaded during the opening frame.")
    var audio_director := world.get_node_or_null("AudioFeedbackDirector") as AudioFeedbackDirector3D
    _expect(audio_director != null, "The world must provide spatial survival audio feedback.")
    if audio_director != null:
        _expect(audio_director._should_quiet_audio(["--quiet-audio"]), "The spatial audio director must honor the explicit quiet-audio review flag.")
        _expect(audio_director._should_quiet_audio(["--new-world"]), "Fresh-world development fixtures must automatically use the quiet audio ceiling.")
        _expect(audio_director._should_quiet_audio(["--presentation-review"]), "Presentation review fixtures must automatically use the quiet audio ceiling.")
        _expect(not audio_director._should_quiet_audio(["--headless", "--path", "game"]), "Ordinary non-review launches must retain their authored spatial audio mix.")
        audio_director.quiet_audio = true
        _expect(is_equal_approx(audio_director._safe_volume_db(0.0), -30.0), "Spatial audio review mode must cap a full-scale cue at a very low playback level.")
        _expect(is_equal_approx(audio_director._safe_volume_db(-36.0), -36.0), "Spatial audio review mode must preserve already-quiet cues without boosting them.")
        audio_director.quiet_audio = false
        for profile in [&"pistol", &"machine_weapon", &"machine_impact", &"player_impact", &"salvage", &"forge", &"organic_attack", &"organic_impact", &"organic_death", &"heartforge_damage", &"heartforge_critical", &"noise_pulse", &"region_transition", &"endgame_start", &"endgame_stage", &"endgame_complete", &"endgame_failure"]:
            _expect(audio_director.has_profile(profile), "The audio director must provide the %s profile." % profile)
        for species in [&"veilstalker", &"razorhound", &"apex", &"sporecaster", &"broodmass", &"burrower", &"skitterling", &"roofleaper", &"glassmoth", &"miremaw", &"carrionbell", &"rootweaver", &"thornback", &"ashmantle"]:
            _expect(audio_director.has_profile(audio_director.organic_profile_id(species)), "Each organic species must provide a distinct attack vocal signature.")
            _expect(audio_director.has_profile(audio_director.organic_profile_id(species, true)), "Each organic species must provide a distinct death vocal signature.")
        for archetype in [&"companion", &"guardian", &"salvager", &"scout", &"engineer", &"relay"]:
            _expect(audio_director.has_profile(audio_director.robot_profile_id(archetype)), "Each friendly robot archetype must provide a distinct weapon signature.")
            _expect(audio_director.has_profile(audio_director.robot_profile_id(archetype, true)), "Each friendly robot archetype must provide a distinct shutdown signature.")
        if world.heartforge != null:
            var original_heartforge_health: float = world.heartforge.current_health
            audio_director.heartforge_critical_clock = 0.0
            world.heartforge.current_health = world.heartforge.maximum_health * 0.2
            var critical_audio_before := audio_director.event_count
            audio_director.call("_process", 0.016)
            _expect(audio_director.last_profile == &"heartforge_critical" and audio_director.event_count == critical_audio_before + 1, "Critical Heartforge integrity must emit a readable warning cue.")
            var rate_limited_audio_count := audio_director.event_count
            audio_director.call("_process", 1.0)
            _expect(audio_director.event_count == rate_limited_audio_count, "Critical Heartforge warning audio must be rate-limited instead of becoming an alarm loop.")
            audio_director.call("_process", 3.5)
            _expect(audio_director.event_count == rate_limited_audio_count + 1 and audio_director.last_profile == &"heartforge_critical", "Critical Heartforge warning audio must repeat only after its bounded interval.")
            world.heartforge.current_health = original_heartforge_health
            audio_director.heartforge_critical_clock = 0.0
            audio_director.stop_all()
        if world.noise_system != null:
            var construction_audio_before := audio_director.event_count
            world.noise_system.emit_noise(Vector3(0.0, 0.0, -12.0), 27.0, 0.72, &"outpost_construction")
            _expect(audio_director.event_count > construction_audio_before, "Outpost construction noise must produce spatial audio feedback.")
            _expect(audio_director.last_profile == &"noise_pulse", "Outpost construction noise must use the bounded noise-pulse audio language.")
            audio_director.stop_all()
    var camp := world.get_node_or_null("CozyHeartforgeCamp") as Node3D
    _expect(camp != null, "The Heartforge must receive an inhabited cozy camp layer.")
    _expect(camp != null and camp.get_node_or_null("HeartforgeCampHighDefinitionService") != null, "The inhabited Heartforge camp must carry a bounded high-definition service layer.")
    _expect(camp != null and camp.find_child("CampToolControlFace", true, false) != null and camp.find_child("CampServiceBatteryPod", true, false) != null and camp.find_child("CampBatteryStatusLens", true, false) != null, "The Heartforge camp service layer must retain readable tool and battery hardware.")
    _expect(camp != null and camp.get_node_or_null("MemoryWitnessRelay") != null, "The sanctuary must carry a physical memory relay for machine-society history.")
    var warm_bulb := camp.find_child("WarmBulb", true, false) as MeshInstance3D if camp != null else null
    var warm_bulb_material := warm_bulb.material_override as StandardMaterial3D if warm_bulb != null else null
    _expect(warm_bulb_material != null and warm_bulb_material.emission_energy_multiplier <= 0.9, "Sanctuary string bulbs must retain an amber, non-clipping emission budget in the opening frame.")
    _expect(camp != null and camp.find_child("WitnessFrameTop", true, false) != null and camp.find_child("WitnessRecordPlate00", true, false) != null and camp.find_child("WitnessSignalLens00", true, false) != null, "The memory relay must expose a layered frame, record plate and readable signal lens.")
    var witness_relay := camp.get_node_or_null("MemoryWitnessRelay") as Node3D
    var witness_lens := camp.find_child("WitnessSignalLens00", true, false) as Node3D
    _expect(witness_relay != null and witness_lens != null and witness_lens.visible, "The opening archive record must light the first physical memory relay lens.")
    if witness_relay != null and witness_lens != null:
        var witness_scale_before := witness_lens.scale
        camp.get_parent().get_node_or_null("AestheticDirector/SanctuaryDecorator").call("_process", 0.7)
        _expect(not witness_lens.scale.is_equal_approx(witness_scale_before), "The active memory relay lens must carry restrained environmental motion.")
    _expect(world.get_node_or_null("UrbanAestheticPass") != null, "The ruined city must receive the urban storytelling pass.")
    var urban_pass := world.get_node_or_null("UrbanAestheticPass") as Node3D
    _expect(urban_pass != null and urban_pass.find_child("ClinicSign", true, false) != null and urban_pass.find_child("WorkshopSign", true, false) != null, "The urban pass must retain layered civic sign hardware.")
    _expect(urban_pass != null and urban_pass.find_child("StreetBench", true, false) != null and urban_pass.find_child("MunicipalBin", true, false) != null and urban_pass.find_child("BinLid", true, false) != null, "The urban pass must retain beveled street furniture and service props.")
    var city := world.get_node_or_null("ProceduralUrbanDistrict") as ProceduralCity3D
    _expect(city != null and city.get_node_or_null("HighDefinitionStreetDetails") != null, "The central town must carry a bounded high-definition street-detail layer.")
    if city != null:
        _expect(city.find_child("CivicBenchSeat", true, false) != null and city.find_child("CivicServiceCabinet", true, false) != null, "The street-detail layer must expose readable civic furniture and maintenance hardware.")
        _expect(city.find_child("CivicPlanterGrowth", true, false) != null and city.find_child("CivicRouteSign", true, false) != null, "The street-detail layer must expose vegetation and civic route identity.")
        _expect(city.get_node_or_null("HighDefinitionCivicInfrastructure") != null, "The central town must carry a bounded civic-infrastructure layer beyond isolated street props.")
        _expect(city.find_child("CivicDrainJunction00", true, false) != null and city.find_child("CivicDrainSlot00", true, false) != null, "Civic infrastructure must expose readable storm-drain junction hardware.")
        _expect(city.find_child("CivicUtilityRiser00", true, false) != null and city.find_child("CivicRiserServiceFace", true, false) != null, "Civic infrastructure must expose layered utility-riser service hardware.")
        _expect(city.find_child("CivicSignalMast00", true, false) != null and city.find_child("CivicSignalLens", true, false) != null, "Civic infrastructure must expose a readable signal-mast scale cue.")
        _expect(city.find_child("CivicOverheadCable00A", true, false) != null and city.find_child("CivicOverheadCable03B", true, false) != null, "Civic infrastructure must preserve bounded overhead service-cable continuity.")
        _expect(city.get_node_or_null("HighDefinitionDebrisDetail") != null, "The central town must carry a bounded high-definition debris layer.")
        _expect(city.find_child("StreetDebris00", true, false) != null and city.find_child("RubbleChunk00", true, false) != null, "Street debris must expose beveled authored rubble chunks.")
        _expect(city.find_child("RubbleRebar00", true, false) != null and city.find_child("RubbleRebar01", true, false) != null, "Street debris must expose restrained reinforcement detail.")
        var vehicle_detail := city.get_node_or_null("VehicleWreck00/VehicleHighDefinitionDetail")
        _expect(vehicle_detail != null and vehicle_detail.get_node_or_null("VehicleCab") != null and vehicle_detail.get_node_or_null("VehicleStatusLens") != null, "Central vehicle wrecks must carry high-definition cab and status detail.")
        _expect(city.get_node_or_null("HighDefinitionFacadeDetails") != null, "The ordinary urban blocks must carry a shared high-definition facade layer beyond their collision shells.")
        _expect(city.find_child("FacadeDetail00", true, false) != null and city.find_child("FacadeWindowBay00_00", true, false) != null, "Facade detail must expose layered window bays and floor-scale structure.")
        _expect(city.find_child("FacadeServiceShutter", true, false) != null and city.find_child("FacadeRainDownpipe", true, false) != null, "Facade detail must expose readable service and weathering hardware.")
        _expect(city.find_child("FacadeDamageBraceA", true, false) != null and city.find_child("FacadeRoofParapet", true, false) != null, "Facade detail must preserve authored damage and roofline identity cues.")
        _expect(city.find_child("ShellCore", true, false) != null and city.find_child("BuildingRoofSlab", true, false) != null, "Ordinary urban buildings must use beveled massing and a readable roof slab rather than broad collision cubes.")
        _expect(city.find_child("CollapsedRoofCore", true, false) != null and city.find_child("CollapsedRoofFragment00", true, false) != null and city.find_child("CollapsedRoofRebar00", true, false) != null, "Ruined-building collapse silhouettes must expose fractured rubble and restrained structural reinforcement detail.")
        _expect(city.find_child("FacadeSideDetail00", true, false) != null and city.find_child("FacadeSideWindow00_00", true, false) != null, "Ordinary urban buildings must carry authored side-elevation windows and floor plates.")
        _expect(city.find_child("FacadeRoofUtility00", true, false) != null and city.find_child("FacadeRoofVent", true, false) != null, "Ordinary urban buildings must carry bounded rooftop utility and ventilation detail.")
        _expect(city.get_node_or_null("HighDefinitionSkylineDetail") != null, "The central town must carry a bounded high-definition skyline layer beyond the close tactical blocks.")
        _expect(city.find_child("SkylineTower00", true, false) != null and city.find_child("SkylineTower03", true, false) != null, "The skyline layer must expose multiple distant civic silhouettes.")
        _expect(city.find_child("SkylineWindowBand00", true, false) != null and city.find_child("SkylineAntenna", true, false) != null and city.find_child("SkylineWarningBeacon", true, false) != null, "Distant civic silhouettes must retain window, utility and signal identity cues.")
    var nest_sample := EnemyTierNest3D.new()
    nest_sample.configure({"id": "aesthetic.high_definition_nest", "position": [72.0, 0.0, 72.0], "maturity": 1.0, "supported_tiers": [3]})
    root.add_child(nest_sample)
    await process_frame
    _expect(nest_sample.find_child("NestHighDefinitionDetail", true, false) != null, "Tiered organic nests must carry a bounded high-definition anatomy layer.")
    _expect(nest_sample.find_child("NestDorsalCarapace", true, false) != null and nest_sample.find_child("NestRootCollar", true, false) != null, "Tiered organic nests must expose layered carapace and root-collar detail.")
    _expect(nest_sample.find_child("NestMembranePlate00", true, false) != null and nest_sample.find_child("NestVeinChannel00", true, false) != null and nest_sample.find_child("NestFineSpine00", true, false) != null, "Tiered organic nests must expose membrane, vascular and fine-spine sockets.")
    nest_sample.apply_damage(9999.0)
    await process_frame
    _expect(not nest_sample.is_alive() and nest_sample.visible, "Destroyed tiered nests must remain visible as persistent ecological landmarks.")
    _expect(nest_sample.find_child("DestroyedTierNestPresentation", true, false) != null, "Destroyed tiered nests must expose a dedicated failure presentation root.")
    _expect(nest_sample.find_child("DestroyedNestCarapace", true, false) != null and nest_sample.find_child("DestroyedNestRootCollar", true, false) != null, "Destroyed tiered nests must expose fractured carapace and an exposed root collar.")
    _expect(nest_sample.find_child("DestroyedNestShard00", true, false) != null and nest_sample.find_child("DestroyedNestVein00", true, false) != null and nest_sample.find_child("DestroyedNestSignal", true, false) != null, "Destroyed tiered nests must expose shell fragments, dead vascular channels and a spent signal core.")
    nest_sample.queue_free()
    var ordinary_nest_sample := OrganicNest3D.new()
    ordinary_nest_sample.configure({"id": "aesthetic.ordinary_high_definition_nest", "maturity": 0.7, "supported_tiers": [1]})
    root.add_child(ordinary_nest_sample)
    await process_frame
    _expect(ordinary_nest_sample.find_child("NestHighDefinitionDetail", true, false) != null, "Ordinary organic nests must carry the same bounded close-range anatomy quality bar as tiered nests.")
    _expect(ordinary_nest_sample.find_child("NestDorsalCarapace", true, false) != null and ordinary_nest_sample.find_child("NestRootCollar", true, false) != null, "Ordinary organic nests must expose layered carapace and root-collar detail.")
    _expect(ordinary_nest_sample.find_child("NestMembranePlate00", true, false) != null and ordinary_nest_sample.find_child("NestVeinChannel00", true, false) != null and ordinary_nest_sample.find_child("NestFineSpine00", true, false) != null, "Ordinary organic nests must expose membrane, vascular and fine-spine sockets.")
    ordinary_nest_sample.apply_damage(9999.0)
    await process_frame
    _expect(not ordinary_nest_sample.is_alive(), "Destroying an ordinary organic nest must preserve its hostile-structure state transition.")
    _expect(ordinary_nest_sample.find_child("DestroyedNestPresentation", true, false) != null, "Destroyed ordinary nests must expose a dedicated failure presentation root.")
    _expect(ordinary_nest_sample.find_child("DestroyedNestCarapace", true, false) != null and ordinary_nest_sample.find_child("DestroyedNestRootCollar", true, false) != null, "Destroyed ordinary nests must expose fractured carapace and an exposed root collar.")
    _expect(ordinary_nest_sample.find_child("DestroyedNestShard00", true, false) != null and ordinary_nest_sample.find_child("DestroyedNestVein00", true, false) != null and ordinary_nest_sample.find_child("DestroyedNestSignal", true, false) != null, "Destroyed ordinary nests must expose shell fragments, dead vascular channels and a spent signal core.")
    ordinary_nest_sample.queue_free()
    var salvage_sample := SalvagePile3D.new()
    salvage_sample.remaining_scrap = 56
    root.add_child(salvage_sample)
    await process_frame
    _expect(salvage_sample.find_child("HighDefinitionSalvageDetail", true, false) != null, "The first salvage target must carry a bounded high-definition wreck detail layer.")
    _expect(salvage_sample.find_child("WreckServicePanel", true, false) != null and salvage_sample.find_child("SalvageAxle00", true, false) != null, "The salvage wreck must expose authored service and axle anatomy.")
    _expect(salvage_sample.find_child("SalvageCableBundle00", true, false) != null and salvage_sample.find_child("BrokenGlassShard00", true, false) != null and salvage_sample.find_child("SalvageStatusLens", true, false) != null, "The salvage wreck must expose cable, damage and readable status detail.")
    salvage_sample.queue_free()
    var site_sample := OutpostSite3D.new()
    site_sample.configure({"id": "aesthetic.site_marker", "display_name": "Marker", "recommended_outpost_role": "scout", "position": [64.0, 0.0, 64.0]})
    root.add_child(site_sample)
    await process_frame
    var site_marker := site_sample.get_node_or_null("HighDefinitionSiteMarker") as Node3D
    _expect(site_marker != null and not site_marker.visible, "Undiscovered outpost sites must keep their authored marker hidden.")
    _expect(site_sample.discover(), "A fresh outpost site must transition into its discovered state once.")
    await process_frame
    _expect(site_marker != null and site_marker.visible, "Discovered outpost sites must reveal their authored survey marker.")
    _expect(site_sample.find_child("SurveyFoundation", true, false) != null and site_sample.find_child("SurveyFoundationInset", true, false) != null, "Outpost sites must expose layered foundation hardware rather than a flat placeholder disc.")
    _expect(site_sample.find_child("SurveyMastCollar", true, false) != null and site_sample.find_child("SurveyMastBraceL", true, false) != null and site_sample.find_child("SurveyMastBraceR", true, false) != null, "Outpost sites must expose a braced survey-mast silhouette.")
    _expect(site_sample.find_child("SurveyServicePanel", true, false) != null and site_sample.find_child("SurveyIdentityPanel", true, false) != null, "Outpost sites must expose readable service and identity hardware.")
    var site_lens := site_sample.find_child("SurveyBeaconLens", true, false) as Node3D
    _expect(site_lens != null and site_sample.find_child("SurveyBeaconHousing", true, false) != null and site_sample.find_child("SurveyBeaconRing", true, false) != null, "Outpost sites must expose a layered beacon housing and lens.")
    if site_lens != null:
        var site_lens_before := site_lens.scale
        site_sample._process(0.7)
        _expect(site_lens.scale != site_lens_before, "Discovered outpost beacons must carry a restrained readable pulse.")
    site_sample.queue_free()
    var site_identity_cases := {
        "site.north_archive_sublevel": "ArchiveShelfLeft",
        "site.east_roof_reservoir": "RoofReservoirTank",
        "site.west_cooling_station": "CoolingStationTank",
        "site.root_signal_ledge": "RootSignalSpineA",
    }
    for raw_identity_id in site_identity_cases:
        var identity_site := OutpostSite3D.new()
        identity_site.configure({"id": raw_identity_id, "display_name": raw_identity_id, "recommended_outpost_role": "scout", "position": [64.0, 0.0, 64.0]})
        root.add_child(identity_site)
        await process_frame
        identity_site.discover()
        await process_frame
        _expect(identity_site.find_child(str(site_identity_cases[raw_identity_id]), true, false) != null, "%s must expose its stable presentation identity kit." % raw_identity_id)
        identity_site.queue_free()
    _expect(world.get_node_or_null("HeartforgeVerticalSlice/HeartforgeMaintenanceDetail") != null, "The Heartforge must expose a dedicated presentation-only maintenance detail layer.")
    _expect(world.get_node_or_null("HeartforgeVerticalSlice/HeartforgePlazaDetail/HeartforgeServiceRing/ForgeRecessedServiceRing") != null, "The Heartforge plaza must expose a readable recessed service ring around its focal machine.")
    _expect(_find_named(world, "RouteThresholdAmberBand") != null, "The opening service lane must expose a far amber threshold landmark for the first objective.")
    _expect(_find_named(world, "AmberRouteChevron") != null, "The opening service lane must carry repeated amber route chevrons beyond the Heartforge.")
    _expect(_find_named(world, "AmberRouteGuideLamp") != null, "The opening service lane must expose near amber guide lamps at the starting frame.")
    for facade_socket in ["PharmacySign", "OccupiedWindow", "WorkshopFascia", "MunicipalLintel", "FireEscape"]:
        _expect(_find_named(world, "%sCore" % facade_socket) != null and _find_named(world, "%sCornerCap" % facade_socket) != null, "The opening facade identity %s must use bounded manufactured depth." % facade_socket)
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
            presentation_feedback.call("_on_actor_health_changed", hostile_sample, hostile_sample.current_health - 1.0, hostile_sample.maximum_health)
            _expect(world.find_children("ActorImpactResponse", "CPUParticles3D", true, false).size() > 0, "Non-lethal organic damage must create a bounded world-space impact response.")
            audio_director.call("_on_actor_health_changed", hostile_sample, hostile_sample.current_health - 1.0, hostile_sample.maximum_health)
            _expect(audio_director.last_profile == &"organic_impact", "Non-lethal organic damage must use the organic impact audio profile.")
        var friendly_sample := get_first_node_in_group(&"friendly_robots") as RobotUnit3D
        if friendly_sample != null:
            _expect(friendly_sample.find_child("HeroSignalCollar", true, false) != null and friendly_sample.find_child("HeroServiceFace", true, false) != null and friendly_sample.find_child("HeroHarnessAnchorL", true, false) != null, "Authored friendly chassis must expose the shared high-definition service collar and harness language.")
            presentation_feedback.call("_on_actor_health_changed", friendly_sample, friendly_sample.current_health - 1.0, friendly_sample.maximum_health)
            _expect(world.find_children("ActorImpactResponse", "CPUParticles3D", true, false).size() > 0, "Non-lethal machine damage must create a bounded world-space impact response.")
            audio_director.call("_on_actor_health_changed", friendly_sample, friendly_sample.current_health - 1.0, friendly_sample.maximum_health)
            _expect(audio_director.last_profile == &"machine_impact", "Non-lethal machine damage must use the machine impact audio profile.")
            audio_director.call("_on_robot_weapon_fired", Vector3.ZERO, Vector3.FORWARD, null, friendly_sample)
            _expect(audio_director.last_profile == audio_director.robot_profile_id(friendly_sample.archetype), "Friendly robot weapon events must use the archetype-specific audio profile.")
            audio_director.call("_on_robot_destroyed", friendly_sample)
            _expect(audio_director.last_profile == audio_director.robot_profile_id(friendly_sample.archetype, true), "Friendly robot losses must use the archetype-specific shutdown profile.")
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
    var story_archive := world.get_node_or_null("StoryArchiveDirector") as StoryArchiveDirector3D
    var release_art := world.get_node_or_null("ReleaseWorldArtDirector") as ReleaseWorldArtDirector3D
    _expect(encounter_dressing != null, "The complete world must provide discovery-driven authored region dressing.")
    if release_art != null:
        var late_family_tints: Array[Color] = [
            release_art._organic_family_tint(&"carrionbell"),
            release_art._organic_family_tint(&"rootweaver"),
            release_art._organic_family_tint(&"thornback"),
            release_art._organic_family_tint(&"ashmantle"),
        ]
        for first_index in late_family_tints.size():
            for second_index in range(first_index + 1, late_family_tints.size()):
                var first_tint := late_family_tints[first_index]
                var second_tint := late_family_tints[second_index]
                var tint_distance := Vector4(first_tint.r, first_tint.g, first_tint.b, 1.0).distance_to(Vector4(second_tint.r, second_tint.g, second_tint.b, 1.0))
                _expect(tint_distance >= 0.18, "Late-organic family tints must remain visibly separated under the shared membrane atlas.")
        _expect(late_family_tints[1].g > late_family_tints[1].r and late_family_tints[2].r > late_family_tints[2].b and late_family_tints[3].b > late_family_tints[3].r, "Late-organic release colours must preserve distinct algae, amber and slate-biological lanes.")
        for tint in late_family_tints:
            var tint_max := maxf(tint.r, maxf(tint.g, tint.b))
            var tint_min := minf(tint.r, minf(tint.g, tint.b))
            _expect(tint_max - tint_min <= 0.40, "Late-organic family tints must stay restrained enough for broad membranes to read as mineral biology rather than toy-saturated plates.")
            _expect(tint.get_luminance() <= 0.52, "Late-organic family tints must keep broad gallery membranes below the pastel value range under the shared blue-hour key.")
    _expect(story_archive != null, "The complete world must provide the persistent Town Archive director.")
    if encounter_dressing != null and region_director != null:
        if startup_lod != null:
            # The catalogue audit deliberately promotes every district. Keep
            # the live focus evaluator from undoing that explicit promotion
            # while threaded packages and release dressing finish together.
            startup_lod.set_process(false)
        for raw_region_id in region_director.region_data.keys():
            region_director.discover_region(StringName(raw_region_id))
        await process_frame
        await process_frame
        if story_archive != null:
            var expected_regional_records := {
                "region.north_ruins": &"story.north_ruins.ledger",
                "region.west_grid": &"story.west_grid.reroute",
                "region.east_tenements": &"story.east_tenements.bridge",
                "region.glasshouse": &"story.glasshouse.cultivation",
                "region.flood_market": &"story.flood_market.inventory",
                "region.riverworks": &"story.riverworks.pumpwatch",
                "region.tram_graveyard": &"story.tram_graveyard.last_route",
                "region.cathedral_quarter": &"story.cathedral.choir",
                "region.observatory_ridge": &"story.observatory.migration",
                "region.buried_labs": &"story.buried_labs.protocol",
                "region.root_cistern": &"story.root_cistern.signal",
            }
            var expected_story_evidence_kinds := {
                "region.north_ruins": "ledger",
                "region.west_grid": "reroute",
                "region.east_tenements": "bridge",
                "region.glasshouse": "cultivation",
                "region.flood_market": "inventory",
                "region.riverworks": "pumpwatch",
                "region.tram_graveyard": "route",
                "region.cathedral_quarter": "choir",
                "region.observatory_ridge": "migration",
                "region.buried_labs": "protocol",
                "region.root_cistern": "signal",
            }

            for raw_region_id in expected_regional_records:
                var expected_record: StringName = expected_regional_records[raw_region_id]
                _expect(story_archive.has_record(expected_record), "Discovering %s must unlock its persistent Town Archive record." % raw_region_id)
                var discovered_landmark := region_director.get_landmark(StringName(raw_region_id))
                var discovered_witness_lens := discovered_landmark.find_child("RegionalStoryWitnessLens", true, false) as Node3D if discovered_landmark != null else null
                _expect(discovered_witness_lens != null and discovered_witness_lens.visible, "The physical witness at %s must light when its Town Archive record is recovered." % raw_region_id)
                var evidence_kind := str(expected_story_evidence_kinds.get(raw_region_id, ""))
                var discovered_story_evidence := discovered_landmark.find_child("RegionalStoryEvidence_%s" % evidence_kind, true, false) as Node3D if discovered_landmark != null else null
                _expect(evidence_kind != "" and discovered_story_evidence != null and discovered_story_evidence.get_child_count() >= 2, "The physical witness at %s must carry a distinct high-definition evidence object rather than a generic reused panel." % raw_region_id)
            var witness_lens_02 := camp.find_child("WitnessSignalLens02", true, false) as Node3D
            _expect(witness_lens_02 != null and witness_lens_02.visible, "A sustained discovery run must progressively light the sanctuary's later memory relay lens.")
        var authored_package_name_by_kind := {
            &"industrial": "WestGridAuthoredScene",
            &"commercial": "FloodMarketAuthoredScene",
            &"archive": "ArchiveAuthoredScene",
            &"tenement": "TenementAuthoredScene",
            &"greenhouse": "GlasshouseAuthoredScene",
            &"waterfront": "RiverworksAuthoredScene",
            &"rail": "TramGraveyardAuthoredScene",
            &"observatory": "ObservatoryAuthoredScene",
            &"nest": "CathedralAuthoredScene",
            &"research": "BuriedLabsAuthoredScene",
            &"endgame": "RootCisternAuthoredScene",
        }
        for raw_region_id in region_director.region_data.keys():
            var landmark := region_director.get_landmark(StringName(raw_region_id))
            if landmark == null or landmark.region_kind == &"sanctuary":
                continue
            # Authoring checks below inspect every authored package in one
            # pass. Promote each landmark explicitly for the inspection, then
            # let the camera-focused LOD checks below stream the distant
            # package back out.
            # This is a catalogue inspection, not a focus simulation. Promote
            # the landmark directly so the LOD signal cannot rebuild release
            # dressing while the threaded package is attaching.
            landmark.set_streamed_in(true)
            await _wait_for_authored_package(landmark, authored_package_name_by_kind.get(landmark.region_kind, ""))
            if release_art != null:
                release_art.ensure_region_dressing(landmark.region_id)
            if startup_lod != null:
                # Keep the director's stream-state ledger consistent for the
                # later camera-driven release/re-entry assertions. The
                # package and release dressing are ready before this signal.
                startup_lod.set_region_streamed(landmark.region_id, true)
            var authored_package_name := str(authored_package_name_by_kind.get(landmark.region_kind, ""))
            var authored_package := landmark.get_node_or_null("PersistentRegionGeometry/%s" % authored_package_name) as Node3D
            _expect(authored_package != null and authored_package.get_child_count() > 0, "Each non-sanctuary region must instantiate its authored package when promoted into the inspection ring.")
            _expect(landmark.get_node_or_null("PersistentRegionCollision/PersistentRegionGround") != null, "Each non-sanctuary region must retain a persistent ground collision shape for physical traversal.")
            _expect(landmark.get_node_or_null("PersistentRegionGeometry/AuthoredEncounterDressing") != null, "Each non-sanctuary region must receive stable authored encounter dressing on discovery.")
            _expect(landmark.get_node_or_null("PersistentRegionGeometry/AuthoredDistrictSurfaceFinish") != null, "Each non-sanctuary region must receive a bounded authored surface-finish layer.")
            var regional_marker := landmark.find_child("RegionalFrontMarkerCore", true, false) as MeshInstance3D
            var regional_marker_material := regional_marker.get_active_material(0) as StandardMaterial3D if regional_marker != null else null
            _expect(regional_marker_material != null and regional_marker_material.emission_energy_multiplier <= 0.65, "Remote district perimeter markers must preserve material hierarchy instead of blooming over the authored landmark.")
            _expect(landmark.find_child("DistrictSurfaceSeam00", true, false) != null and landmark.find_child("DistrictSurfaceDebris00", true, false) != null, "Each non-sanctuary region must break its broad apron into authored seams and debris.")
            _expect(landmark.find_child("DistrictSurfaceDrain00", true, false) != null and landmark.find_child("DistrictSurfaceEdgeBraceL", true, false) != null, "Each non-sanctuary region must expose bounded service and edge hardware.")
            _expect(landmark.get_node_or_null("PersistentRegionGeometry/RegionPracticalLight0") != null and landmark.get_node_or_null("PersistentRegionGeometry/RegionPracticalLight1") != null, "Each non-sanctuary region must receive two bounded palette-aware practical lights.")
            _expect(landmark.get_node_or_null("PersistentRegionGeometry/RegionalPressureRead") != null, "Each discovered non-sanctuary region must expose a bounded pressure-growth presentation layer.")
            _expect(landmark.find_child("RegionalPressurePlate00", true, false) != null and landmark.find_child("RegionalPressureSignal00", true, false) != null, "Regional pressure growth must expose stable plate and signal anatomy sockets.")
            _expect(landmark.find_child("RegionalStoryWitnessFrame", true, false) != null and landmark.find_child("RegionalStoryWitnessPlate", true, false) != null, "Each non-sanctuary region must expose a bounded physical Town Archive witness panel.")
            _expect(landmark.get_node_or_null("ReducedRegionProxy") != null, "Each non-sanctuary region must expose a bounded coarse proxy for distant presentation LOD.")
            var district_breadth := landmark.get_node_or_null("PersistentRegionGeometry/AuthoredEncounterDressing/DistrictBreadthLayer") as Node3D
            _expect(district_breadth != null, "Each discovered non-sanctuary region must expose a bounded district-breadth presentation layer.")
            if district_breadth != null:
                _expect(district_breadth.find_child("DistrictBreadthServicePad", true, false) != null, "District breadth must carry a readable service-edge anchor.")
                _expect(district_breadth.find_child("DistrictBreadthGrowth0", true, false) != null, "District breadth must carry restrained overgrowth detail.")
                _expect(district_breadth.find_child("DistrictBreadthIdentity_%s" % String(landmark.region_kind), true, false) != null, "District breadth must preserve a region-specific identity motif.")
                var secondary_breadth := district_breadth.find_child("DistrictBreadthSecondaryKit", true, false) as Node3D
                _expect(secondary_breadth != null, "District breadth must carry a second bounded service-edge assembly rather than one isolated landmark prop.")
                if secondary_breadth != null:
                    _expect(secondary_breadth.find_child("DistrictBreadthSecondaryPod", true, false) != null and secondary_breadth.find_child("DistrictBreadthSecondaryBadge", true, false) != null, "The secondary district kit must expose a layered service pod and readable identity badge.")
                    var secondary_identity_names := {
                        &"archive": "DistrictBreadthArchiveShelf",
                        &"industrial": "DistrictBreadthTransformerCap",
                        &"tenement": "DistrictBreadthBalconyFrame",
                        &"greenhouse": "DistrictBreadthIrrigationValve",
                        &"commercial": "DistrictBreadthMarketCrate",
                        &"waterfront": "DistrictBreadthMooringPost",
                        &"rail": "DistrictBreadthRailSwitch",
                        &"nest": "DistrictBreadthBroodVeil",
                        &"observatory": "DistrictBreadthSurveyMast",
                        &"research": "DistrictBreadthContainmentLatch",
                        &"endgame": "DistrictBreadthRootAnchor",
                    }
                    var secondary_identity_name := str(secondary_identity_names.get(landmark.region_kind, ""))
                    _expect(secondary_identity_name != "" and secondary_breadth.find_child(secondary_identity_name, true, false) != null, "District breadth must preserve a second region-specific identity motif.")
            var pressure_read := landmark.get_node_or_null("PersistentRegionGeometry/RegionalPressureRead") as Node3D
            var pressure_signal := landmark.find_child("RegionalPressureSignal00", true, false) as Node3D
            var pressure_signal_mesh := pressure_signal as MeshInstance3D
            var pressure_signal_material := pressure_signal_mesh.get_active_material(0) as StandardMaterial3D if pressure_signal_mesh != null else null
            _expect(pressure_signal_material != null and pressure_signal_material.emission_energy_multiplier <= 0.70, "Regional pressure signals must retain a bounded emission ceiling instead of blooming into white points across the landmark.")
            if pressure_read != null and pressure_signal != null:
                landmark.set_pressure(0.9)
                landmark.set_presentation_detail_level(0)
                var pressure_scale_before := pressure_read.scale
                var pressure_signal_before := pressure_signal.scale
                landmark.call("_process", 0.5)
                _expect(not pressure_read.scale.is_equal_approx(pressure_scale_before), "Regional pressure growth must pulse at the current ecological intensity.")
                _expect(not pressure_signal.scale.is_equal_approx(pressure_signal_before), "Regional pressure signals must carry a readable living pulse.")
                landmark.add_suppression(0.55)
                _expect(landmark.effective_pressure() < 0.9, "Regional suppression must reduce the pressure value driving the presentation layer.")
            _expect(landmark.find_child("*Facade*", true, false) != null, "Each non-sanctuary region must expose a readable district-specific surface signature.")
            if landmark.region_kind == &"industrial":
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/WestGridAuthoredModel") != null, "West Grid must expose its authored turbine-hall and transformer-yard landmark shell.")
                _expect(landmark.find_child("WestGridWindowFrame0", true, false) != null and landmark.find_child("WestGridWindowMullion0", true, false) != null, "West Grid must expose turbine-hall window framing and mullions.")
                _expect(landmark.find_child("WestGridTurbineAccessHousing", true, false) != null and landmark.find_child("WestGridTurbineAccessRing", true, false) != null and landmark.find_child("WestGridTurbineAccessHub", true, false) != null and landmark.find_child("WestGridTurbineAccessBolt0", true, false) != null, "West Grid must expose the authored turbine-access focal assembly.")
                _expect(landmark.find_child("WestGridHallSkinRib0", true, false) != null and landmark.find_child("WestGridHallSkinRailTop", true, false) != null and landmark.find_child("WestGridHallSkinPlate0", true, false) != null, "West Grid must expose maintained upper hall skin ribs and inspection plates.")
                _expect(landmark.find_child("WestGridTankValve0", true, false) != null and landmark.find_child("WestGridTankLadder0", true, false) != null, "West Grid must expose pressure-tank service hardware.")
                _expect(landmark.find_child("WestGridTransformerCap0", true, false) != null and landmark.find_child("WestGridTransformerBrace0", true, false) != null and landmark.find_child("WestGridTransformerBushing0_0", true, false) != null and landmark.find_child("WestGridTransformerBushingCap0_0", true, false) != null, "West Grid must expose layered transformer-yard hardware and readable ceramic bushings.")
                _expect(landmark.find_child("WestGridPipeFlange0", true, false) != null and landmark.find_child("WestGridWarningHousing0", true, false) != null, "West Grid must expose service-pipe and warning hardware.")
                _expect(landmark.find_child("WestGridOrganicTendril0_0", true, false) != null, "West Grid organic growth must expose secondary tendril anatomy.")
                var west_grid_reroute_witness := landmark.find_child("WestGridRerouteWitness", true, false) as Node3D
                _expect(west_grid_reroute_witness != null and west_grid_reroute_witness.find_child("WestGridRerouteBoard", true, false) != null and west_grid_reroute_witness.find_child("WestGridRerouteRouteMap", true, false) != null and west_grid_reroute_witness.find_child("WestGridRerouteServiceCable", true, false) != null, "West Grid must expose a bounded physical reroute witness that anchors its archive record in the encounter space.")
                var west_grid_hall := landmark.find_child("WestGridTurbineHall", true, false) as MeshInstance3D
                var west_grid_turbine_ring := landmark.find_child("WestGridTurbineAccessRing", true, false) as MeshInstance3D
                var west_grid_transformer := landmark.find_child("WestGridTransformer0", true, false) as MeshInstance3D
                _expect(west_grid_hall != null and west_grid_transformer != null and west_grid_turbine_ring != null and _mesh_vertex_count(west_grid_hall) >= 48 and _mesh_vertex_count(west_grid_transformer) >= 48 and _mesh_vertex_count(west_grid_turbine_ring) >= 384, "West Grid authored hall, transformer and turbine collar must retain high-definition geometry.")
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
                    # Avoid making the acceptance gate depend on one exact
                    # sine phase; hosted runners can enter this sample at a
                    # slightly different elapsed time.
                    if grid_signal.scale.is_equal_approx(grid_signal_before):
                        landmark.call("_process", 0.17)
                    _expect(not grid_signal.scale.is_equal_approx(grid_signal_before), "West Grid tank signal must pulse as a restrained presentation cue.")
                    _expect(not grid_warning.scale.is_equal_approx(grid_warning_before), "West Grid warning light must carry deterministic presentation motion.")
                    _expect(not grid_growth.scale.is_equal_approx(grid_growth_before), "West Grid organic growth must carry deterministic presentation motion.")
                    _expect(not grid_valve.rotation.is_equal_approx(grid_valve_before), "West Grid tank valve must carry restrained service motion.")
                    _expect(not grid_tendril.rotation.is_equal_approx(grid_tendril_before), "West Grid organic tendril must carry deterministic presentation motion.")
            if landmark.region_kind == &"endgame":
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/RootCisternAuthoredModel") != null, "The Root Cistern must expose its authored landmark shell.")
                _expect(landmark.find_child("RootCisternBasin", true, false) != null, "The Root Cistern must expose an authored basin floor to anchor the capstone encounter.")
                _expect(landmark.find_child("RootCisternCoreHalo", true, false) != null, "The Root Cistern must expose an authored luminous core halo.")
                _expect(landmark.find_child("RootCisternCoreCollar", true, false) != null and landmark.find_child("RootCisternCoreRoot0", true, false) != null, "The Root Cistern must expose a grounded core collar and radial root braces.")
                _expect(landmark.find_child("RootCisternCorePlate0", true, false) != null and landmark.find_child("RootCisternCoreClaw0", true, false) != null and landmark.find_child("RootCisternCoreVein0", true, false) != null, "The Root Cistern must expose layered core surface and vein hardware.")
                _expect(landmark.find_child("RootCisternPylonCollar0", true, false) != null and landmark.find_child("RootCisternPylonFoot0", true, false) != null and landmark.find_child("RootCisternPylonShoulder0", true, false) != null and landmark.find_child("RootCisternPylonCrown0", true, false) != null and landmark.find_child("RootCisternPylonRing0", true, false) != null and landmark.find_child("RootCisternCoreCrownRing", true, false) != null and landmark.find_child("RootCisternPulseCap0", true, false) != null and landmark.find_child("RootCisternCableClamp0", true, false) != null, "The Root Cistern must expose detailed rounded pylon and crown service hardware.")
                _expect(landmark.find_child("RootCisternBasinSpine0", true, false) != null and landmark.find_child("RootCisternBasinRootTendril0", true, false) != null, "The Root Cistern must expose basin rim and organic-root detail.")
                _expect(landmark.find_child("RootCisternBasinInlay00", true, false) != null and landmark.find_child("RootCisternBasinSocket00", true, false) != null, "The Root Cistern must expose a repeated basin signal-inlay layer.")
                _expect(landmark.find_child("RootCisternCoreCrownPlate00", true, false) != null and landmark.find_child("RootCisternCoreCrownSocket00", true, false) != null, "The Root Cistern must expose a readable crown hardware ring above the core.")
                _expect(landmark.find_child("RootCisternCoreCapPlate", true, false) != null and landmark.find_child("RootCisternCoreCapCollar", true, false) != null and landmark.find_child("RootCisternCoreCapSocket", true, false) != null and landmark.find_child("RootCisternCoreCapRib00", true, false) != null and landmark.find_child("RootCisternCoreCapSocket00", true, false) != null, "The Root Cistern capstone must expose a distinct buried-alloy plate, collar, radial ribs and signal sockets.")
                var cistern_release_detail := release_art.region_dressing_root(&"region.root_cistern") if release_art != null else null
                var cistern_control_deck := cistern_release_detail.find_child("CisternControlDeck", true, false) as Node3D if cistern_release_detail != null else null
                var cistern_control_deck_core := cistern_control_deck.get_node_or_null("CisternControlDeckCore") as MeshInstance3D if cistern_control_deck != null else null
                var cistern_panel_brace := cistern_release_detail.find_child("CisternPanelBraceL", true, false) as MeshInstance3D if cistern_release_detail != null else null
                _expect(cistern_control_deck_core != null and cistern_control_deck_core.mesh != null and cistern_control_deck_core.mesh.get_aabb().size.x <= 6.5 and cistern_control_deck_core.mesh.get_aabb().size.z <= 1.2, "The Root Cistern control deck must remain a bounded approach cue beneath the capstone silhouette.")
                _expect(cistern_panel_brace != null and cistern_panel_brace.mesh != null and cistern_panel_brace.mesh.get_aabb().size.y <= 1.2, "The Root Cistern protocol braces must remain low enough to preserve the central relay silhouette.")
                var cistern_approach := landmark.find_child("RootCisternApproachCauseway", true, false) as Node3D
                _expect(cistern_approach != null and cistern_approach.find_child("RootCisternCausewaySlab0", true, false) != null and cistern_approach.find_child("RootCisternCausewaySignal0", true, false) != null, "The Root Cistern encounter must expose a segmented approach causeway with a readable machine signal line.")
                _expect(cistern_approach != null and cistern_approach.find_child("RootCisternCausewayRail", true, false) != null and cistern_approach.find_child("RootCisternCausewayGrowthL", true, false) != null and cistern_approach.find_child("RootCisternCausewayGrowthR", true, false) != null, "The Root Cistern approach must bind machine-built edge rails to organic takeover detail.")
                var cistern_approach_lamp := cistern_approach.find_child("RootCisternCausewayLamp0", true, false) as Node3D if cistern_approach != null else null
                var cistern_approach_growth := cistern_approach.find_child("RootCisternCausewayGrowthL", true, false) as Node3D if cistern_approach != null else null
                var cistern_core_mass := landmark.find_child("RootCisternCoreMass", true, false) as Node3D
                var cistern_layer_0 := landmark.find_child("RootCisternLayer0", true, false) as Node3D
                var cistern_layer_1 := landmark.find_child("RootCisternLayer1", true, false) as Node3D
                _expect(cistern_core_mass != null and cistern_core_mass.scale.y >= 2.20, "The Root Cistern capstone must retain a raised vertical core profile rather than flattening into a saucer.")
                _expect(cistern_layer_0 != null and cistern_layer_1 != null and not cistern_layer_0.scale.is_equal_approx(cistern_layer_1.scale), "The Root Cistern mantle must retain staggered layered anatomy instead of identical repeated petals.")
                var cistern_mantle_0 := landmark.find_child("RootCisternCoreMantle0", true, false) as Node3D
                var cistern_mantle_1 := landmark.find_child("RootCisternCoreMantle1", true, false) as Node3D
                _expect(cistern_mantle_0 != null and cistern_mantle_1 != null, "The Root Cistern focal shell must expose its overlapping mantle lobes.")
                _expect(cistern_mantle_0 != null and cistern_mantle_1 != null and (not cistern_mantle_0.scale.is_equal_approx(cistern_mantle_1.scale) or not is_equal_approx(cistern_mantle_0.position.y, cistern_mantle_1.position.y)), "The Root Cistern focal shell must retain alternating overlapping mantle lobes instead of a smooth unbroken mass.")
                var cistern_pulse := landmark.find_child("RootCisternPulse0", true, false) as Node3D
                var cistern_collar := landmark.find_child("RootCisternPylonCollar0", true, false) as Node3D
                var cistern_pylon_ring := landmark.find_child("RootCisternPylonRing0", true, false) as MeshInstance3D
                var cistern_crown_ring := landmark.find_child("RootCisternCoreCrownRing", true, false) as MeshInstance3D
                var cistern_vein := landmark.find_child("RootCisternCoreVein0", true, false) as Node3D
                var cistern_tendril := landmark.find_child("RootCisternBasinRootTendril0", true, false) as Node3D
                _expect(cistern_pylon_ring != null and cistern_crown_ring != null and _mesh_vertex_count(cistern_pylon_ring) >= 384 and _mesh_vertex_count(cistern_crown_ring) >= 384, "The Root Cistern relay hardware must retain smooth high-definition rings.")
                _expect(cistern_pulse != null and cistern_collar != null and cistern_vein != null and cistern_tendril != null, "The Root Cistern must expose signal, pylon, vein and basin motion sockets.")
                if cistern_pulse != null and cistern_collar != null and cistern_vein != null and cistern_tendril != null:
                    landmark.set_presentation_detail_level(0)
                    var pulse_before := cistern_pulse.scale
                    var collar_before := cistern_collar.scale
                    var vein_before := cistern_vein.rotation.y
                    var tendril_before := cistern_tendril.rotation.z
                    var approach_lamp_before := cistern_approach_lamp.scale if cistern_approach_lamp != null else Vector3.ZERO
                    var approach_growth_before := cistern_approach_growth.rotation.y if cistern_approach_growth != null else 0.0
                    landmark.call("_process", 0.5)
                    _expect(not cistern_pulse.scale.is_equal_approx(pulse_before), "The Root Cistern pulse must carry a restrained presentation cue.")
                    _expect(not cistern_collar.scale.is_equal_approx(collar_before), "The Root Cistern pylon collar must carry a restrained signal cue.")
                    _expect(not is_equal_approx(cistern_vein.rotation.y, vein_before), "The Root Cistern core veins must carry deterministic organic motion.")
                    _expect(not is_equal_approx(cistern_tendril.rotation.z, tendril_before), "The Root Cistern basin tendrils must carry deterministic organic motion.")
                    _expect(cistern_approach_lamp != null and not cistern_approach_lamp.scale.is_equal_approx(approach_lamp_before), "The Root Cistern causeway lamps must carry a restrained signal pulse.")
                    _expect(cistern_approach_growth != null and not is_equal_approx(cistern_approach_growth.rotation.y, approach_growth_before), "The Root Cistern causeway growth must carry deterministic organic motion.")
            if landmark.region_kind == &"nest":
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/NestOccluderShell") != null, "The nest must isolate its close-range opaque shell for camera-safe presentation.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/CathedralAuthoredModel") != null, "Cathedral Quarter must expose its authored nave and choir landmark shell.")
                var cathedral_nave := landmark.find_child("CathedralNave", true, false) as MeshInstance3D
                var cathedral_gable := landmark.find_child("CathedralNaveGable", true, false) as MeshInstance3D
                var cathedral_tower := landmark.find_child("CathedralTower", true, false) as MeshInstance3D
                _expect(cathedral_nave != null and cathedral_gable != null and cathedral_tower != null and _mesh_vertex_count(cathedral_nave) >= 48 and _mesh_vertex_count(cathedral_gable) >= 24 and _mesh_vertex_count(cathedral_tower) >= 48, "Cathedral authored nave, gable and tower must retain high-definition geometry.")
                var cathedral_choir_signal := landmark.find_child("CathedralChoirSignal", true, false) as Node3D
                var cathedral_choir_ring := landmark.find_child("CathedralChoirSignalRing", true, false) as Node3D
                var cathedral_door_post := landmark.find_child("CathedralDoorPostL", true, false) as Node3D
                var cathedral_tower_slit := landmark.find_child("CathedralTowerSlit0", true, false) as Node3D
                var cathedral_rose_latch := landmark.find_child("CathedralRoseLatch0", true, false) as Node3D
                var cathedral_rose_rim := landmark.find_child("CathedralRoseRim", true, false) as MeshInstance3D
                var cathedral_choir_rib := landmark.find_child("CathedralChoirRibL", true, false) as Node3D
                var cathedral_bell := landmark.find_child("CathedralBell", true, false) as Node3D
                var cathedral_clapper := landmark.find_child("CathedralBellClapper", true, false) as Node3D
                var cathedral_vein_knuckle := landmark.find_child("CathedralOrganicVeinKnuckle17", true, false) as Node3D
                _expect(cathedral_choir_signal != null and cathedral_bell != null, "Cathedral Quarter must expose named choir and bell motion sockets.")
                _expect(cathedral_choir_ring != null and cathedral_door_post != null and cathedral_tower_slit != null and cathedral_rose_latch != null and cathedral_rose_rim != null and cathedral_choir_rib != null and cathedral_clapper != null and cathedral_vein_knuckle != null, "Cathedral Quarter must expose secondary entry, rose-window, tower, choir and bell hardware detail.")
                _expect(cathedral_rose_rim != null and _mesh_vertex_count(cathedral_rose_rim) >= 384, "Cathedral rose-window rim must retain dense curved high-definition geometry.")
                var cathedral_yard_plinth := landmark.find_child("CathedralChoirYardPlinth", true, false) as Node3D
                var cathedral_yard_louver := landmark.find_child("CathedralChoirYardServiceLouver0", true, false) as Node3D
                var cathedral_yard_crossbeam := landmark.find_child("CathedralChoirYardCrossbeam", true, false) as Node3D
                var cathedral_yard_resonator := landmark.find_child("CathedralChoirYardResonator", true, false) as Node3D
                var cathedral_yard_root := landmark.find_child("CathedralChoirYardRootPlate", true, false) as Node3D
                _expect(cathedral_yard_plinth != null and cathedral_yard_louver != null and cathedral_yard_crossbeam != null, "Cathedral Quarter must expose a bounded choir-yard service edge around the authored landmark.")
                _expect(cathedral_yard_resonator != null and cathedral_yard_root != null, "Cathedral Quarter choir-yard hardware must retain resonator and organic anchor detail.")
                var cathedral_release_detail := release_art.dressing_root.find_child("CathedralReleaseFacade", true, false) if release_art != null and release_art.dressing_root != null else null
                _expect(cathedral_release_detail != null and cathedral_release_detail.find_child("CathedralReleaseNave", true, false) != null and cathedral_release_detail.find_child("CathedralReleaseTowerL", true, false) != null and cathedral_release_detail.find_child("CathedralReleaseTowerR", true, false) != null, "Cathedral Quarter release dressing must expose a shallow nave and paired civic towers.")
                _expect(cathedral_release_detail != null and cathedral_release_detail.find_child("CathedralReleaseGableL", true, false) != null and cathedral_release_detail.find_child("CathedralReleaseGableR", true, false) != null and cathedral_release_detail.find_child("CathedralReleaseGableCrossV", true, false) != null, "Cathedral Quarter release dressing must expose a front gable and central cross.")
                _expect(cathedral_release_detail != null and cathedral_release_detail.find_child("CathedralReleaseNaveCourse00L", true, false) != null and cathedral_release_detail.find_child("CathedralReleaseNaveLancetL", true, false) != null and cathedral_release_detail.find_child("CathedralReleaseDoorArchL", true, false) != null, "Cathedral Quarter release dressing must expose shallow nave masonry, lancet and doorway framing detail.")
                var cathedral_release_rose_rim := cathedral_release_detail.find_child("CathedralReleaseRoseRim", true, false) as MeshInstance3D if cathedral_release_detail != null else null
                _expect(cathedral_release_detail != null and cathedral_release_detail.find_child("CathedralReleaseRoseFrame", true, false) != null and cathedral_release_detail.find_child("CathedralReleaseRoseGlass", true, false) != null and cathedral_release_rose_rim != null, "Cathedral Quarter release dressing must expose a readable rose-window focal cue.")
                _expect(cathedral_release_rose_rim != null and _mesh_vertex_count(cathedral_release_rose_rim) >= 384, "Cathedral release rose-window rim must retain dense curved high-definition geometry.")
                var cathedral_bell_yard := release_art.dressing_root.find_child("CathedralBellYardWitness", true, false) if release_art != null and release_art.dressing_root != null else null
                _expect(cathedral_bell_yard != null and cathedral_bell_yard.find_child("CathedralBellYardBell", true, false) != null and cathedral_bell_yard.find_child("CathedralBellYardSuppressionPlate", true, false) != null, "Cathedral Quarter release dressing must retain a readable bell-yard witness for its authored suppression history.")
                if cathedral_choir_signal != null and cathedral_bell != null and cathedral_choir_ring != null and cathedral_vein_knuckle != null:
                    var choir_signal_before := cathedral_choir_signal.scale
                    var choir_ring_before := cathedral_choir_ring.scale
                    var bell_before := cathedral_bell.rotation.z
                    var vein_knuckle_before := cathedral_vein_knuckle.rotation.x
                    landmark.call("_process", 0.5)
                    _expect(not cathedral_choir_signal.scale.is_equal_approx(choir_signal_before), "Cathedral choir signal must pulse as a restrained presentation cue.")
                    _expect(not cathedral_choir_ring.scale.is_equal_approx(choir_ring_before), "Cathedral choir signal ring must pulse with the choir cue.")
                    _expect(absf(cathedral_bell.rotation.z - bell_before) > 0.001, "Cathedral bell must carry deterministic presentation motion.")
                    _expect(not is_equal_approx(cathedral_vein_knuckle.rotation.x, vein_knuckle_before), "Cathedral organic vein joints must carry deterministic presentation motion.")
            if landmark.region_kind == &"commercial":
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/FloodMarketIdentityDetails") != null, "Flood Market must expose authored stall canopies and hanging signs.")
                _expect(landmark.find_child("MarketFloodChannel", true, false) != null, "Flood Market must expose bounded presentation-only water channels.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/FloodMarketAuthoredModel") != null, "Flood Market must expose its authored canopy and service landmark shell.")
                _expect(landmark.find_child("FloodMarketCanopyRib0_0", true, false) != null and landmark.find_child("FloodMarketStallFrame0", true, false) != null, "Flood Market must expose secondary canopy and stall framing detail.")
                _expect(landmark.find_child("FloodMarketWaterFoam0_0", true, false) != null and landmark.find_child("FloodMarketCraneWheel", true, false) != null, "Flood Market must expose water-edge and service-crane detail.")
                _expect(landmark.find_child("FloodMarketOrganicTendril0_0", true, false) != null, "Flood Market organic growth must expose secondary tendril anatomy.")
                _expect(landmark.find_child("FloodMarketServiceBox0", true, false) != null and landmark.find_child("FloodMarketServiceLatch0", true, false) != null and landmark.find_child("FloodMarketCargoCrate0", true, false) != null, "Flood Market must expose authored stall service and cargo hardware.")
                _expect(landmark.find_child("FloodMarketDrainGrate0", true, false) != null and landmark.find_child("FloodMarketCanopyAnchor0L", true, false) != null and landmark.find_child("FloodMarketHangingHook0", true, false) != null, "Flood Market must expose drainage, canopy-anchor and hanging hardware.")
                _expect(landmark.find_child("FloodMarketTideGatePost0", true, false) != null and landmark.find_child("FloodMarketTideGateBeam", true, false) != null and landmark.find_child("FloodMarketTideGateFin0", true, false) != null, "Flood Market must expose a readable tide-control arch and structural fins.")
                _expect(landmark.find_child("FloodMarketTideBeacon0", true, false) != null and landmark.find_child("FloodMarketFloodDeck0", true, false) != null and landmark.find_child("FloodMarketFloodDeckRail0L", true, false) != null, "Flood Market must expose elevated flood-deck and signal hardware for vertical encounter identity.")
                _expect(landmark.find_child("FloodMarketBanner0", true, false) != null and landmark.find_child("FloodMarketForegroundWater0", true, false) != null and landmark.find_child("FloodMarketForegroundFoam0", true, false) != null, "Flood Market must carry suspended vendor banners and a readable foreground waterline.")
                var market_release_detail := release_art.dressing_root.find_child("HighDefinitionMarketDressing", true, false) if release_art != null and release_art.dressing_root != null else null
                _expect(market_release_detail != null and market_release_detail.find_child("MarketCanopyVolume00_02", true, false) != null and market_release_detail.find_child("MarketCanopyRib00_01", true, false) != null and not market_release_detail.find_children("MarketCanopyHem00_*", "Node3D", true, false).is_empty(), "Flood Market release dressing must expose folded canopy volume, ribs and edge hems.")
                var market_canopy := landmark.find_child("FloodMarketCanopyRoof0", true, false) as MeshInstance3D
                var market_stall := landmark.find_child("FloodMarketStall0", true, false) as MeshInstance3D
                _expect(market_canopy != null and market_stall != null and _mesh_vertex_count(market_canopy) >= 48 and _mesh_vertex_count(market_stall) >= 48, "Flood Market authored canopy and stall must retain beveled high-definition geometry.")
                var canopy_depth := market_canopy.mesh.get_aabb().size.y if market_canopy != null and market_canopy.mesh != null else 0.0
                _expect(canopy_depth >= 0.30, "Flood Market authored canopies must retain measurable sag and cloth volume rather than reverting to flat slabs.")
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
            if landmark.region_kind == &"research":
                var labs_spine := landmark.find_child("BuriedLabsContainmentSpine", true, false) as Node3D
                _expect(labs_spine != null, "Buried Laboratories must expose a bounded containment spine in the discovered encounter space.")
                if labs_spine != null:
                    _expect(labs_spine.find_child("LabContainmentBackwall", true, false) != null and labs_spine.find_child("LabAirlockDoor", true, false) != null and labs_spine.find_child("LabAirlockReader", true, false) != null, "Buried Laboratories must expose an approach-facing airlock and sealed backwall.")
                    _expect(labs_spine.find_child("LabContainmentVessel", true, false) != null and labs_spine.find_child("LabContainmentCore", true, false) != null and labs_spine.find_child("LabContainmentCollar", true, false) != null and labs_spine.find_child("LabContainmentCap", true, false) != null, "Buried Laboratories must expose layered central containment-vessel anatomy.")
                    _expect(labs_spine.find_child("LabSpineCoolingLouver", true, false) != null and labs_spine.find_child("LabSpineInstrumentFace", true, false) != null and labs_spine.find_child("LabSpineTransferPipe", true, false) != null, "Buried Laboratories must expose cooling, instrument and transfer hardware around the vessel.")
                    var labs_vessel := labs_spine.find_child("LabContainmentVessel", true, false) as MeshInstance3D
                    var labs_collar := labs_spine.find_child("LabContainmentCollar", true, false) as MeshInstance3D
                    _expect(labs_vessel != null and _mesh_vertex_count(labs_vessel) >= 48 and labs_collar != null and _mesh_vertex_count(labs_collar) >= 300, "Buried Laboratories containment hardware must retain dense curved high-definition geometry.")
                    var labs_light := labs_spine.find_child("EncounterPractical", true, false) as OmniLight3D
                    _expect(labs_light != null and labs_light.light_energy <= 0.60, "Buried Laboratories containment lighting must remain a restrained violet cue instead of blooming over the encounter.")
            if landmark.region_kind == &"archive":
                _expect(landmark.find_child("ArchiveCivicFacade", true, false) != null, "North Ruins must expose an authored civic archive facade.")
                _expect(landmark.find_child("ArchiveFacadeCornice", true, false) != null and landmark.find_child("ArchiveFacadePilasterL", true, false) != null, "North Ruins must expose layered facade edge treatment and civic pilaster detail.")
                _expect(landmark.find_child("ArchiveVaultInset", true, false) != null, "North Ruins must expose a readable recessed vault surround.")
                _expect(landmark.find_child("ArchiveVaultDoor", true, false) != null, "North Ruins must expose a readable archive vault entrance.")
                _expect(landmark.find_child("ArchiveRoofBeacon", true, false) != null, "North Ruins must expose a surviving archive beacon silhouette.")
                _expect(landmark.find_child("ArchiveWindowFrameL", true, false) != null and landmark.find_child("ArchiveWindowMullionL", true, false) != null, "North Ruins must expose civic window framing and mullion detail.")
                _expect(landmark.find_child("ArchiveVaultDoorJambL", true, false) != null and landmark.find_child("ArchiveVaultDoorLintel", true, false) != null and landmark.find_child("ArchiveCivicPlaque", true, false) != null, "North Ruins must expose layered vault entrance framing and civic identity detail.")
                _expect(landmark.find_child("ArchiveBeaconCollar", true, false) != null and landmark.find_child("ArchiveBeaconBraceL", true, false) != null, "North Ruins must expose roof beacon service hardware.")
                _expect(landmark.find_child("ArchiveShelfDivider0_0", true, false) != null and landmark.find_child("ArchiveShelfRail0", true, false) != null, "North Ruins must expose archive stack filing hardware.")
                _expect(landmark.find_child("ArchiveOrganicTendril0_0", true, false) != null, "North Ruins organic growth must expose secondary tendril anatomy.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/ArchiveAuthoredModel") != null, "North Ruins must expose its authored civic archive landmark shell.")
                var archive_facade := landmark.find_child("ArchiveCivicFacade", true, false) as MeshInstance3D
                var archive_cornice := landmark.find_child("ArchiveFacadeCornice", true, false) as MeshInstance3D
                _expect(archive_facade != null and archive_cornice != null and _mesh_vertex_count(archive_facade) >= 48 and _mesh_vertex_count(archive_cornice) >= 48, "North Ruins authored facade pieces must retain beveled high-definition geometry.")
                var archive_beacon := landmark.find_child("ArchiveRoofBeaconLight", true, false) as Node3D
                var archive_creep := landmark.find_child("ArchiveOrganicCreep0", true, false) as Node3D
                var archive_collar := landmark.find_child("ArchiveBeaconCollar", true, false) as Node3D
                var archive_tendril := landmark.find_child("ArchiveOrganicTendril0_0", true, false) as Node3D
                _expect(archive_beacon != null and archive_creep != null and archive_collar != null and archive_tendril != null, "North Ruins must expose named beacon, collar, creep and tendril motion sockets.")
                var archive_paper := landmark.find_child("ArchivePaperStack0_0", true, false) as MeshInstance3D
                var archive_brace := landmark.find_child("ArchiveBeaconBraceL", true, false) as MeshInstance3D
                _expect(archive_paper != null and _mesh_vertex_count(archive_paper) >= 48 and archive_brace != null and _mesh_vertex_count(archive_brace) >= 48, "North Ruins archive stacks and beacon braces must retain chamfered high-definition prop geometry.")
                var archive_release_detail := release_art.dressing_root.find_child("HighDefinitionArchiveDressing", true, false) if release_art != null and release_art.dressing_root != null else null
                var archive_sublevel := archive_release_detail.find_child("ArchiveSublevelWitness", true, false) as Node3D if archive_release_detail != null else null
                _expect(archive_sublevel != null and archive_sublevel.find_child("ArchiveSublevelRecordCase", true, false) != null, "North Ruins release dressing must expose a physical sealed-catalogue witness beside the civic gateway.")
                if archive_sublevel != null:
                    _expect(archive_sublevel.find_child("ArchiveSublevelStep00", true, false) != null and archive_sublevel.find_child("ArchiveSublevelIndex", true, false) != null and archive_sublevel.find_child("ArchiveSublevelLamp", true, false) != null, "North Ruins sealed-catalogue witness must retain layered steps, index hardware and a restrained service lamp.")
                if archive_beacon != null and archive_creep != null and archive_collar != null and archive_tendril != null:
                    landmark.set_presentation_detail_level(0)
                    var beacon_before := archive_beacon.scale
                    var creep_before := archive_creep.scale
                    var collar_before := archive_collar.scale
                    var tendril_before := archive_tendril.rotation
                    landmark.call("_process", 0.5)
                    # A presentation pulse is continuous, so a single fixed
                    # sample can land on the same phase on a different
                    # runner. Take one bounded follow-up sample only when the
                    # first sample is phase-aligned; this keeps the check
                    # about observable motion rather than frame timing.
                    if archive_beacon.scale.is_equal_approx(beacon_before):
                        landmark.call("_process", 0.17)
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
                var greenhouse_release_detail := release_art.dressing_root.find_child("HighDefinitionGreenhouseDressing", true, false) if release_art != null and release_art.dressing_root != null else null
                _expect(greenhouse_release_detail != null and greenhouse_release_detail.find_child("GlasshouseFacadePane00", true, false) != null and greenhouse_release_detail.find_child("GlasshouseFacadePaneRear00", true, false) != null, "Municipal Glasshouse release dressing must expose front and rear cold-glass facade bays.")
                _expect(greenhouse_release_detail != null and greenhouse_release_detail.find_child("GlasshouseRoofPaneFront00", true, false) != null and greenhouse_release_detail.find_child("GlasshouseRoofPaneRear00", true, false) != null, "Municipal Glasshouse release dressing must expose a split roof canopy for readable climate volume.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/GlasshouseAuthoredModel") != null, "Municipal Glasshouse must expose its authored climate-frame landmark shell.")
                _expect(landmark.find_child("GlasshouseBedEdge0", true, false) != null and landmark.find_child("GlasshouseGrowthTendril0_0", true, false) != null and landmark.find_child("GlasshouseLightHousing0", true, false) != null and landmark.find_child("GlasshouseBedTrellis0", true, false) != null and landmark.find_child("GlasshouseTrellisRail0", true, false) != null and landmark.find_child("GlasshouseTrellisGrowth0_0", true, false) != null, "Municipal Glasshouse growth beds must expose secondary service, trellis and organic detail.")
                _expect(landmark.find_child("GlasshouseServiceTrolley", true, false) != null and landmark.find_child("GlasshouseTrolleyBody", true, false) != null and landmark.find_child("GlasshouseTrolleyTray", true, false) != null and landmark.find_child("GlasshouseTrolleyWheelL", true, false) != null and landmark.find_child("GlasshouseTrolleyCanister", true, false) != null and landmark.find_child("GlasshouseTrolleyHandleL", true, false) != null, "Municipal Glasshouse must expose a bounded human-scale service trolley in the cultivation aisle.")
                var greenhouse_bed_light := landmark.find_child("GlasshouseBedLight0", true, false) as MeshInstance3D
                var greenhouse_canopy_signal := landmark.find_child("GlasshouseCanopyPulse", true, false) as MeshInstance3D
                var greenhouse_bed_material := greenhouse_bed_light.material_override as StandardMaterial3D if greenhouse_bed_light != null else null
                var greenhouse_canopy_material := greenhouse_canopy_signal.material_override as StandardMaterial3D if greenhouse_canopy_signal != null else null
                _expect(greenhouse_bed_material != null and greenhouse_bed_material.emission_energy_multiplier <= 0.40 and greenhouse_bed_material.emission.g > greenhouse_bed_material.emission.r, "Municipal Glasshouse bed lights must retain a bounded green signal instead of blooming white.")
                _expect(greenhouse_canopy_material != null and greenhouse_canopy_material.emission_energy_multiplier <= 0.30 and greenhouse_canopy_material.emission.g > greenhouse_canopy_material.emission.r, "Municipal Glasshouse canopy signal must retain a restrained green emission budget.")
                var glasshouse_post := landmark.find_child("GlasshouseFrameBay0", true, false) as MeshInstance3D
                var glasshouse_rib := landmark.find_child("GlasshouseRoofRib0", true, false) as MeshInstance3D
                _expect(glasshouse_post != null and glasshouse_rib != null and _mesh_vertex_count(glasshouse_post) >= 48 and _mesh_vertex_count(glasshouse_rib) >= 48, "Municipal Glasshouse authored frame must retain beveled high-definition structure.")
                var release_greenhouse_layer := release_art.dressing_root.find_child("HighDefinitionGreenhouseServiceLayer", true, false) if release_art != null and release_art.dressing_root != null else null
                _expect(release_greenhouse_layer != null and release_greenhouse_layer.find_child("GlasshouseServiceWalkway", true, false) != null and release_greenhouse_layer.find_child("GlasshouseIrrigationManifold", true, false) != null, "Municipal Glasshouse must expose a bounded service walkway and irrigation manifold in its release dressing.")
                _expect(release_greenhouse_layer != null and release_greenhouse_layer.find_child("GlasshouseClimateConsole", true, false) != null and release_greenhouse_layer.find_child("GlasshouseIrrigationHeader", true, false) != null and release_greenhouse_layer.find_child("GlasshouseBrokenGlazingBrace00", true, false) != null, "Municipal Glasshouse service depth must preserve climate, irrigation and damaged-glazing identity hardware.")
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
                _expect(landmark.find_child("TramWreckCarriage", true, false) != null and landmark.find_child("TramWreckCarriageRoof", true, false) != null, "Tram Graveyard must expose a banked wreck carriage with authored roof hardware.")
                _expect(landmark.find_child("TramCarriageAFrontWindow0", true, false) != null and landmark.find_child("TramCarriageAFrontDoor", true, false) != null, "Tram Graveyard must expose approach-facing carriage hardware.")
                _expect(landmark.find_child("TramInspectionPit", true, false) != null, "Tram Graveyard must expose a bounded inspection-pit signature.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/TramGraveyardAuthoredModel") != null, "Tram Graveyard must expose its authored carriage and maintenance landmark shell.")
                var tram_carriage_body := landmark.find_child("TramCarriageABody", true, false) as MeshInstance3D
                var tram_carriage_roof := landmark.find_child("TramCarriageARoof", true, false) as MeshInstance3D
                var tram_wheel_rim := landmark.find_child("TramCarriageAWheelRimFront0", true, false) as MeshInstance3D
                _expect(tram_carriage_body != null and tram_carriage_roof != null and _mesh_vertex_count(tram_carriage_body) >= 48 and _mesh_vertex_count(tram_carriage_roof) >= 48, "Tram authored carriage shell must retain beveled high-definition geometry.")
                _expect(tram_wheel_rim != null and _mesh_vertex_count(tram_wheel_rim) >= 384, "Tram authored carriage wheels must retain smooth high-definition rims.")
                _expect(landmark.find_child("TramCarriageAFrontHeadlampHousing", true, false) != null and landmark.find_child("TramCarriageABogiePlate0", true, false) != null and landmark.find_child("TramCarriageABogieCrossbar0", true, false) != null and landmark.find_child("TramCarriageAWheelHubFront0", true, false) != null and landmark.find_child("TramCarriageARoofRib0", true, false) != null and landmark.find_child("TramCarriageACornerPostFront0", true, false) != null and landmark.find_child("TramCarriageAPantograph", true, false) != null, "Tram Graveyard must expose layered carriage service hardware.")
                _expect(landmark.find_child("TramCarriageASidePanelFront0", true, false) != null and landmark.find_child("TramYardDeck", true, false) != null, "Tram Graveyard must expose maintained carriage side panels and a grounded rail-yard deck.")
                _expect(landmark.find_child("TramPitRung0", true, false) != null and landmark.find_child("TramCableClamp0", true, false) != null and landmark.find_child("TramSignalHousing", true, false) != null and landmark.find_child("TramYardCrate0", true, false) != null and landmark.find_child("TramCableReel0", true, false) != null and landmark.find_child("TramYardDebris0", true, false) != null, "Tram Graveyard must expose maintenance-pit, overhead-service and derelict-yard details.")
                var tram_signal := landmark.find_child("TramSignalLamp", true, false) as Node3D
                var tram_seep := landmark.find_child("TramOrganicSeep0", true, false) as Node3D
                var tram_signal_housing := landmark.find_child("TramSignalHousing", true, false) as Node3D
                var tram_headlamp := landmark.find_child("TramCarriageAFrontHeadlampLens", true, false) as Node3D
                var tram_tendril := landmark.find_child("TramOrganicSeepTendril0_0", true, false) as Node3D
                _expect(tram_signal != null and tram_seep != null and tram_signal_housing != null and tram_headlamp != null and tram_tendril != null, "Tram Graveyard must expose named signal, headlamp, housing and organic motion sockets.")
                var tram_yard_crate := landmark.find_child("TramYardCrate0", true, false) as MeshInstance3D
                var tram_cable_reel := landmark.find_child("TramCableReel0", true, false) as MeshInstance3D
                var tram_yard_debris := landmark.find_child("TramYardDebris0", true, false) as MeshInstance3D
                _expect(tram_yard_crate != null and tram_cable_reel != null and tram_yard_debris != null and _mesh_vertex_count(tram_yard_crate) >= 48 and _mesh_vertex_count(tram_cable_reel) >= 48 and _mesh_vertex_count(tram_yard_debris) >= 48, "Tram Graveyard yard remnants must retain dense beveled geometry at approach distance.")
                if tram_signal != null and tram_seep != null and tram_signal_housing != null and tram_headlamp != null and tram_tendril != null:
                    landmark.set_presentation_detail_level(0)
                    var tram_mast := landmark.find_child("TramSignalMast", true, false) as Node3D
                    _expect(tram_mast != null and tram_signal.global_position.distance_to(tram_mast.global_position + Vector3.UP * 3.25) < 0.25, "Tram signal lamp must remain attached to the authored mast socket.")
                    var signal_before := tram_signal.scale
                    var seep_before := tram_seep.scale
                    var housing_before := tram_signal_housing.scale
                    var headlamp_before := tram_headlamp.scale
                    var tendril_before := tram_tendril.rotation.z
                    landmark.call("_process", 0.5)
                    _expect(not tram_signal.scale.is_equal_approx(signal_before), "Tram signal lamp must pulse as a restrained presentation cue.")
                    _expect(not tram_seep.scale.is_equal_approx(seep_before), "Tram organic seepage must carry deterministic presentation motion.")
                    _expect(not tram_signal_housing.scale.is_equal_approx(housing_before), "Tram signal housing must carry restrained service motion.")
                    _expect(not tram_headlamp.scale.is_equal_approx(headlamp_before), "Tram headlamp lens must carry a restrained powered cue.")
                    _expect(not is_equal_approx(tram_tendril.rotation.z, tendril_before), "Tram organic seepage tendrils must carry deterministic environmental motion.")
            if landmark.region_kind == &"observatory":
                _expect(landmark.find_child("ObservatoryOpticsStation", true, false) != null, "Observatory Ridge must expose an authored optics station.")
                _expect(landmark.find_child("ObservatoryLensBarrel", true, false) != null, "Observatory Ridge must expose a readable survey lens.")
                _expect(landmark.find_child("ObservatoryStarMapPanel", true, false) != null, "Observatory Ridge must expose a readable survey console.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/ObservatoryAuthoredModel") != null, "Observatory Ridge must expose its authored radio-observatory landmark shell.")
                _expect(landmark.find_child("ObservatoryServiceDeck", true, false) != null, "Observatory Ridge must expose an authored survey service deck.")
                _expect(landmark.find_child("ObservatoryControlWindow0", true, false) != null, "Observatory Ridge must expose readable control-cabin windows.")
                _expect(landmark.find_child("ObservatoryFrontConsole", true, false) != null, "Observatory Ridge must expose an approach-facing survey console.")
                _expect(landmark.find_child("ObservatorySurveyRail0", true, false) != null, "Observatory Ridge must expose a bounded survey-deck rail silhouette.")
                _expect(landmark.find_child("ObservatoryDishRib0", true, false) != null and landmark.find_child("ObservatoryDishActuator", true, false) != null and landmark.find_child("ObservatoryFeedHorn", true, false) != null and landmark.find_child("ObservatoryFeedHornRim", true, false) != null and landmark.find_child("ObservatoryFeedHornLens", true, false) != null and landmark.find_child("ObservatoryFeedCollar", true, false) != null, "Observatory Ridge must expose dish structural and feed hardware.")
                _expect(landmark.find_child("ObservatoryDishRimRing", true, false) != null, "Observatory Ridge must expose a continuous high-definition dish service rim.")
                _expect(landmark.find_child("ObservatoryDishPedestal", true, false) != null and landmark.find_child("ObservatoryDishSupportRing", true, false) != null and landmark.find_child("ObservatoryDishPivotHousing", true, false) != null and landmark.find_child("ObservatoryDishPivotBand", true, false) != null, "Observatory Ridge must ground the reflector in a layered azimuth pedestal and pivot housing.")
                _expect(landmark.find_child("ObservatoryMastCollar", true, false) != null and landmark.find_child("ObservatoryDeckPost0", true, false) != null, "Observatory Ridge must expose mast and service-deck hardware.")
                _expect(landmark.find_child("ObservatoryControlWindowFrame0", true, false) != null and landmark.find_child("ObservatoryControlWindowMullion0", true, false) != null and landmark.find_child("ObservatoryFrontConsoleFrame", true, false) != null, "Observatory Ridge must expose cabin and console framing detail.")
                _expect(landmark.find_child("ObservatoryCableAnchor0", true, false) != null and landmark.find_child("ObservatorySurveyLightHousing0", true, false) != null, "Observatory Ridge must expose survey-cable and deck-light hardware.")
                _expect(landmark.find_child("ObservatoryRidgePylonL", true, false) != null and landmark.find_child("ObservatoryRidgeBeam", true, false) != null and landmark.find_child("ObservatoryRidgeSignalFrame", true, false) != null and landmark.find_child("ObservatoryRidgeSignalPanel", true, false) != null, "Observatory Ridge must expose a readable survey-gantry silhouette and framed signal panel.")
                _expect(landmark.find_child("ObservatoryRidgeLadder", true, false) != null and landmark.find_child("ObservatoryRidgeBraceL", true, false) != null and landmark.find_child("ObservatoryRidgeBeacon0", true, false) != null and landmark.find_child("ObservatoryRidgeSensor0", true, false) != null, "Observatory Ridge must expose service access, structural bracing and instrument beacons.")
                var observatory_release_detail := release_art.dressing_root.find_child("HighDefinitionObservatoryDressing", true, false) if release_art != null and release_art.dressing_root != null else null
                _expect(observatory_release_detail != null and observatory_release_detail.find_child("ObservatoryArrayFrame", true, false) != null and observatory_release_detail.find_child("ObservatoryArrayControlPod", true, false) != null and observatory_release_detail.find_child("ObservatoryArrayApproachControlPod", true, false) != null, "Observatory Ridge release dressing must frame the dish with a bounded instrument array and approach-facing control pods.")
                _expect(observatory_release_detail != null and observatory_release_detail.find_child("ObservatoryRidgeFoundation", true, false) != null and observatory_release_detail.find_child("ObservatoryRidgeFoundationSlab", true, false) != null and observatory_release_detail.find_child("ObservatoryRidgeInstrumentPad", true, false) != null, "Observatory Ridge release dressing must ground the station in a bounded instrument foundation instead of leaving it floating on a bare plane.")
                _expect(observatory_release_detail != null and observatory_release_detail.find_child("ObservatoryRidgeApproachPlate00", true, false) != null and observatory_release_detail.find_child("ObservatoryRidgeApproachConduit", true, false) != null and observatory_release_detail.find_child("ObservatoryRidgeBoundarySignalL00", true, false) != null, "Observatory Ridge release dressing must expose a readable approach path and powered boundary markers around the survey station.")
                _expect(observatory_release_detail != null and observatory_release_detail.find_child("ObservatoryDishApertureRing", true, false) != null and observatory_release_detail.find_child("ObservatoryBaseCollar", true, false) != null, "Observatory Ridge release dressing must expose a raised aperture contour and a restrained foundation collar for the hero reflector.")
                _expect(observatory_release_detail != null and observatory_release_detail.find_child("ObservatoryArrayCrossbar00", true, false) != null and observatory_release_detail.find_child("ObservatoryArrayRelayMast", true, false) != null, "Observatory Ridge release dressing must expose crossbar and relay structure for a readable survey silhouette.")
                var observatory_array_pylon := observatory_release_detail.find_child("ObservatoryArrayPylon00", true, false) as Node3D if observatory_release_detail != null else null
                _expect(observatory_array_pylon != null and observatory_array_pylon.position.z <= -3.0, "Observatory Ridge's release array must stay behind the reflector instead of recreating a foreground occluding frame.")
                _expect(observatory_release_detail != null and observatory_release_detail.find_child("ObservatoryMigrationWitness", true, false) != null and observatory_release_detail.find_child("ObservatoryMigrationMapPlate", true, false) != null, "Observatory Ridge must expose a physical migration-map witness beside the survey instrument.")
                _expect(observatory_release_detail != null and observatory_release_detail.find_child("ObservatoryMigrationTrace00", true, false) != null and observatory_release_detail.find_child("ObservatoryMigrationNode02", true, false) != null and observatory_release_detail.find_child("ObservatoryMigrationCalibrationLens", true, false) != null, "The migration witness must retain layered route traces and calibration hardware.")
                var observatory_dish := landmark.find_child("ObservatoryDish", true, false) as Node3D
                var observatory_feed := landmark.find_child("ObservatoryFeedSignal", true, false) as Node3D
                var observatory_actuator := landmark.find_child("ObservatoryDishActuator", true, false) as Node3D
                var observatory_collar := landmark.find_child("ObservatoryFeedCollar", true, false) as Node3D
                var observatory_mast_collar := landmark.find_child("ObservatoryMastCollar", true, false) as Node3D
                _expect(observatory_dish != null and observatory_feed != null and observatory_actuator != null and observatory_collar != null and observatory_mast_collar != null, "Observatory Ridge must expose named dish, actuator, feed, collar and mast motion sockets.")
                if observatory_dish != null and observatory_feed != null and observatory_actuator != null and observatory_collar != null and observatory_mast_collar != null:
                    _expect(observatory_dish is MeshInstance3D and _mesh_vertex_count(observatory_dish as MeshInstance3D) >= 900, "Observatory hero dish must retain a dense parabolic reflector mesh instead of a low-detail proxy.")
                    if observatory_dish is MeshInstance3D:
                        var dish_world_depth := (observatory_dish as MeshInstance3D).mesh.get_aabb().size.y * observatory_dish.scale.y
                        _expect(dish_world_depth >= 0.70, "Observatory hero dish must retain a deep parabolic bowl rather than collapsing into a shallow disc.")
                    var observatory_dish_rib := landmark.find_child("ObservatoryDishRib0", true, false) as MeshInstance3D
                    _expect(observatory_dish_rib != null and _mesh_vertex_count(observatory_dish_rib) >= 48, "Observatory dish ribs must retain dense rounded structural geometry rather than flat bars.")
                    var observatory_feed_arm := landmark.find_child("ObservatoryFeedArm", true, false) as MeshInstance3D
                    _expect(observatory_feed_arm != null and observatory_feed_arm.mesh.get_aabb().size.x <= 0.24, "Observatory feed arm must retain a slim approach-facing profile so it does not become a dark centre bar across the reflector.")
                    var observatory_feed_horn := landmark.find_child("ObservatoryFeedHorn", true, false) as MeshInstance3D
                    var observatory_feed_lens := landmark.find_child("ObservatoryFeedHornLens", true, false) as MeshInstance3D
                    _expect(observatory_feed_horn != null and _mesh_vertex_count(observatory_feed_horn) >= 96 and observatory_feed_lens != null and _mesh_vertex_count(observatory_feed_lens) >= 240, "Observatory receiver horn must retain dense tapered hardware and a rounded signal lens.")
                    var observatory_control := landmark.find_child("ObservatoryControl", true, false) as MeshInstance3D
                    var observatory_deck := landmark.find_child("ObservatoryServiceDeck", true, false) as MeshInstance3D
                    var observatory_ridge_panel := landmark.find_child("ObservatoryRidgeSignalPanel", true, false) as MeshInstance3D
                    _expect(observatory_control != null and _mesh_vertex_count(observatory_control) >= 48 and observatory_deck != null and _mesh_vertex_count(observatory_deck) >= 48 and observatory_ridge_panel != null and _mesh_vertex_count(observatory_ridge_panel) >= 48, "Observatory control, service-deck and ridge-signal hardware must retain chamfered high-definition geometry.")
                    var observatory_ridge_beam := landmark.find_child("ObservatoryRidgeBeam", true, false) as Node3D
                    _expect(observatory_ridge_beam != null and observatory_ridge_beam.position.z <= -3.0, "Observatory Ridge's authored gantry must frame the reflector from behind instead of occluding the approach-facing dish.")
                    var observatory_pedestal := landmark.find_child("ObservatoryDishPedestal", true, false) as MeshInstance3D
                    var observatory_pivot := landmark.find_child("ObservatoryDishPivotHousing", true, false) as MeshInstance3D
                    var observatory_base := observatory_release_detail.find_child("ObservatoryBase", true, false) as MeshInstance3D if observatory_release_detail != null else null
                    _expect(observatory_base != null and observatory_base.mesh.get_aabb().size.y <= 0.9, "Observatory release foundation must remain a low grounding plinth instead of a tall proxy drum.")
                    _expect(observatory_pedestal != null and _mesh_vertex_count(observatory_pedestal) >= 48 and observatory_pedestal.mesh.get_aabb().size.y >= 1.8 and observatory_pivot != null and _mesh_vertex_count(observatory_pivot) >= 240, "Observatory reflector support must retain a dense grounded pedestal and rounded pivot housing rather than a thin placeholder post.")
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
                var riverworks_retaining_edge := landmark.find_child("RetainingWall", true, false) as Node3D
                var riverworks_retaining_core := riverworks_retaining_edge.get_node_or_null("RetainingWallCore") as MeshInstance3D if riverworks_retaining_edge != null else null
                _expect(riverworks_retaining_core != null and riverworks_retaining_core.mesh != null and riverworks_retaining_core.mesh.get_aabb().size.y <= 0.75 and riverworks_retaining_core.mesh.get_aabb().size.x <= 12.0, "Riverworks retaining edge must remain a low, bounded foreground cue so the authored pump stays readable.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/RiverworksAuthoredModel") != null, "Riverworks must expose its authored pump landmark shell.")
                _expect(landmark.find_child("RiverworksPumpPanel", true, false) != null and landmark.find_child("RiverworksRotorHub", true, false) != null and landmark.find_child("RiverworksPumpVoluteRing", true, false) != null and landmark.find_child("RiverworksRotorBlade00", true, false) != null and landmark.find_child("RiverworksRotorBlade03", true, false) != null and landmark.find_child("RiverworksValveHandle", true, false) != null, "Riverworks must expose pump service, impeller and maintenance hardware.")
                var riverworks_housing := landmark.find_child("RiverworksPumpHousing", true, false) as MeshInstance3D
                var riverworks_sluice := landmark.find_child("RiverworksSluiceGate", true, false) as MeshInstance3D
                _expect(riverworks_housing != null and riverworks_sluice != null and _mesh_vertex_count(riverworks_housing) >= 48 and _mesh_vertex_count(riverworks_sluice) >= 48, "Riverworks authored housing and sluice pieces must retain beveled high-definition geometry.")
                _expect(landmark.find_child("RiverworksSluiceRail", true, false) != null and landmark.find_child("RiverworksSluiceLatch", true, false) != null and landmark.find_child("RiverworksSluiceSignalHousing", true, false) != null, "Riverworks must expose layered sluice and flow-signal hardware.")
                _expect(landmark.find_child("RiverworksCableClamp", true, false) != null and landmark.find_child("RiverworksGrowthTendril0_0", true, false) != null, "Riverworks must expose maintenance-cable and organic detail.")
                var riverworks_rotor := landmark.find_child("RiverworksRotor", true, false) as Node3D
                var riverworks_volute := landmark.find_child("RiverworksPumpVoluteRing", true, false) as MeshInstance3D
                var riverworks_signal := landmark.find_child("RiverworksSluiceSignal", true, false) as Node3D
                var riverworks_valve_handle := landmark.find_child("RiverworksValveHandle", true, false) as Node3D
                var riverworks_signal_housing := landmark.find_child("RiverworksSluiceSignalHousing", true, false) as Node3D
                var riverworks_tendril := landmark.find_child("RiverworksGrowthTendril0_0", true, false) as Node3D
                _expect(riverworks_rotor != null and riverworks_volute != null and riverworks_signal != null and riverworks_valve_handle != null and riverworks_signal_housing != null and riverworks_tendril != null, "Riverworks must expose named pump, volute, flow, valve, signal-housing and tendril motion sockets.")
                _expect(riverworks_volute != null and _mesh_vertex_count(riverworks_volute) >= 480, "Riverworks hero pump volute must retain dense curved high-definition geometry.")
                var riverworks_blade := landmark.find_child("RiverworksRotorBlade00", true, false) as MeshInstance3D
                _expect(riverworks_blade != null and _mesh_vertex_count(riverworks_blade) >= 48, "Riverworks hero pump impeller blades must retain bounded beveled geometry.")
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
                var riverworks_dock_assembly := landmark.find_child("RiverworksDockAssembly", true, false) as Node3D
                _expect(riverworks_dock_assembly != null, "Riverworks must expose a bounded discovered-space dock assembly around its water-management focal.")
                if riverworks_dock_assembly != null:
                    _expect(riverworks_dock_assembly.find_child("RiverworksEncounterSluice", true, false) != null and riverworks_dock_assembly.find_child("RiverworksEncounterGate", true, false) != null and riverworks_dock_assembly.find_child("RiverworksEncounterGateLouver", true, false) != null, "Riverworks discovered space must expose a framed sluice gate with readable service detail.")
                    _expect(riverworks_dock_assembly.find_child("RiverworksEncounterManifold", true, false) != null and riverworks_dock_assembly.find_child("RiverworksEncounterPumpHousing", true, false) != null and riverworks_dock_assembly.find_child("RiverworksEncounterHeaderManifold", true, false) != null, "Riverworks discovered space must expose a pump housing and raised header manifold.")
                    var encounter_rotor_ring := riverworks_dock_assembly.find_child("RiverworksEncounterRotorRing", true, false) as MeshInstance3D
                    var encounter_light := riverworks_dock_assembly.find_child("EncounterPractical", true, false) as OmniLight3D
                    _expect(encounter_rotor_ring != null and _mesh_vertex_count(encounter_rotor_ring) >= 300, "Riverworks discovered pump hardware must retain dense curved high-definition geometry.")
                    _expect(encounter_light != null and encounter_light.light_energy <= 0.50, "Riverworks discovered practical lighting must remain a restrained cyan cue instead of blooming over the waterline.")
            if landmark.region_kind == &"research":
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/BuriedLaboratoriesIdentityDetails") != null, "Buried Laboratories must expose its authored containment vignette.")
                _expect(landmark.find_child("LabContainmentVessel", true, false) != null, "Buried Laboratories must expose readable containment vessels.")
                _expect(landmark.find_child("LabTransferRail", true, false) != null, "Buried Laboratories must expose an overhead transfer rail.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/BuriedLabsAuthoredModel") != null, "Buried Laboratories must expose its authored containment-hall landmark shell.")
                _expect(landmark.find_child("BuriedLabsVesselPort0", true, false) != null and landmark.find_child("BuriedLabsVesselClampL0", true, false) != null, "Buried Laboratories must expose vessel service ports and clamps.")
                _expect(landmark.find_child("BuriedLabsVesselCollarTop0", true, false) != null and landmark.find_child("BuriedLabsVesselCollarBottom0", true, false) != null and landmark.find_child("BuriedLabsVesselBaseRing0", true, false) != null and landmark.find_child("BuriedLabsVesselNeck0", true, false) != null, "Buried Laboratories must expose rounded vessel service collars and a neck assembly.")
                var labs_viewport := landmark.find_child("BuriedLabsVesselViewport0", true, false) as MeshInstance3D
                var labs_viewport_ring := landmark.find_child("BuriedLabsVesselViewportRing0", true, false) as MeshInstance3D
                _expect(labs_viewport != null and labs_viewport_ring != null and _mesh_vertex_count(labs_viewport) >= 96 and _mesh_vertex_count(labs_viewport_ring) >= 240 and labs_viewport.get_parent().name == "BuriedLabsVessel0" and labs_viewport_ring.get_parent().name == "BuriedLabsVessel0", "Buried Laboratories containment vessels must expose dense parented observation viewports and service rings.")
                _expect(landmark.find_child("BuriedLabsTransferCarriage", true, false) != null and landmark.find_child("BuriedLabsTransferRailStopL", true, false) != null, "Buried Laboratories must expose transfer-carriage and rail-stop detail.")
                _expect(landmark.find_child("BuriedLabsContainmentDoorJambL", true, false) != null and landmark.find_child("BuriedLabsContainmentDoorLintel", true, false) != null and landmark.find_child("BuriedLabsWarningPanelFrame", true, false) != null, "Buried Laboratories must expose layered sealed-door and warning-panel framing.")
                _expect(landmark.find_child("BuriedLabsCableClamp0", true, false) != null and landmark.find_child("BuriedLabsOrganicTendril0_0", true, false) != null, "Buried Laboratories must expose service-cable and organic detail.")
                _expect(landmark.find_child("BuriedLabsExtractionPylonL", true, false) != null and landmark.find_child("BuriedLabsExtractionBeam", true, false) != null, "Buried Laboratories must expose a vertical genome-extraction gantry.")
                _expect(landmark.find_child("BuriedLabsExtractionCradle", true, false) != null and landmark.find_child("BuriedLabsGenomePrism", true, false) != null and landmark.find_child("BuriedLabsGenomePrismRing", true, false) != null, "Buried Laboratories must expose the suspended genome-prism focal assembly.")
                _expect(landmark.find_child("BuriedLabsExtractionServicePanelFrame", true, false) != null, "Buried Laboratories must expose a readable extraction service face.")
                var labs_vessel_mesh := landmark.find_child("BuriedLabsVesselBody0", true, false) as MeshInstance3D
                var labs_collar_mesh := landmark.find_child("BuriedLabsVesselCollarTop0", true, false) as MeshInstance3D
                _expect(labs_vessel_mesh != null and labs_collar_mesh != null and _mesh_vertex_count(labs_vessel_mesh) >= 880 and _mesh_vertex_count(labs_collar_mesh) >= 384, "Buried Laboratories vessels must retain smooth high-definition envelopes and service collars.")
                var labs_rail_mesh := landmark.find_child("BuriedLabsTransferRail", true, false) as MeshInstance3D
                var labs_door_mesh := landmark.find_child("BuriedLabsContainmentDoor", true, false) as MeshInstance3D
                var labs_gantry_mesh := landmark.find_child("BuriedLabsExtractionBeam", true, false) as MeshInstance3D
                _expect(labs_rail_mesh != null and _mesh_vertex_count(labs_rail_mesh) > 24, "Buried Laboratories transfer rails must use chamfered high-definition geometry rather than flat bars.")
                _expect(labs_door_mesh != null and _mesh_vertex_count(labs_door_mesh) > 24, "Buried Laboratories containment doors must use chamfered high-definition geometry rather than flat slabs.")
                _expect(labs_gantry_mesh != null and _mesh_vertex_count(labs_gantry_mesh) > 24, "Buried Laboratories extraction gantries must use chamfered high-definition geometry rather than flat beams.")
                var labs_light := landmark.find_child("BuriedLabsVesselLight0", true, false) as Node3D
                var labs_seep := landmark.find_child("BuriedLabsOrganicSeep0", true, false) as Node3D
                var labs_port := landmark.find_child("BuriedLabsVesselPort0", true, false) as Node3D
                var labs_carriage := landmark.find_child("BuriedLabsTransferCarriage", true, false) as Node3D
                var labs_tendril := landmark.find_child("BuriedLabsOrganicTendril0_0", true, false) as Node3D
                var labs_beacon := landmark.find_child("BuriedLabsExtractionBeaconL", true, false) as Node3D
                var labs_prism := landmark.find_child("BuriedLabsGenomePrism", true, false) as Node3D
                var labs_prism_ring := landmark.find_child("BuriedLabsGenomePrismRing", true, false) as Node3D
                var labs_cradle := landmark.find_child("BuriedLabsExtractionCradle", true, false) as Node3D
                _expect(labs_light != null and labs_seep != null and labs_port != null and labs_carriage != null and labs_tendril != null and labs_beacon != null and labs_prism != null and labs_prism_ring != null and labs_cradle != null, "Buried Laboratories must expose named containment, extraction, seep and focal-object motion sockets.")
                if labs_light != null and labs_seep != null and labs_port != null and labs_carriage != null and labs_tendril != null and labs_beacon != null and labs_prism != null and labs_prism_ring != null and labs_cradle != null:
                    landmark.set_presentation_detail_level(0)
                    var labs_light_before := labs_light.scale
                    var labs_seep_before := labs_seep.scale
                    var labs_port_before := labs_port.rotation
                    var labs_carriage_before := labs_carriage.position
                    var labs_tendril_before := labs_tendril.rotation
                    var labs_beacon_before := labs_beacon.scale
                    var labs_prism_before := labs_prism.rotation
                    var labs_prism_ring_before := labs_prism_ring.scale
                    var labs_cradle_before := labs_cradle.position
                    landmark.call("_process", 0.5)
                    # The restrained containment pulse is continuous; a
                    # fixed sample can land on its same scale phase on a
                    # different runner. Take one bounded follow-up sample
                    # only when the first sample is phase-aligned.
                    if labs_light.scale.is_equal_approx(labs_light_before):
                        landmark.call("_process", 0.17)
                    _expect(not labs_light.scale.is_equal_approx(labs_light_before), "Buried Laboratories containment light must pulse as a restrained presentation cue.")
                    _expect(not labs_seep.scale.is_equal_approx(labs_seep_before), "Buried Laboratories organic contamination must carry deterministic presentation motion.")
                    _expect(not labs_port.rotation.is_equal_approx(labs_port_before), "Buried Laboratories vessel port must carry restrained service motion.")
                    _expect(not labs_carriage.position.is_equal_approx(labs_carriage_before), "Buried Laboratories transfer carriage must carry restrained mechanical motion.")
                    _expect(not labs_tendril.rotation.is_equal_approx(labs_tendril_before), "Buried Laboratories organic tendril must carry deterministic presentation motion.")
                    _expect(not labs_beacon.scale.is_equal_approx(labs_beacon_before), "Buried Laboratories extraction beacon must pulse as a restrained signal cue.")
                    _expect(not labs_prism.rotation.is_equal_approx(labs_prism_before), "Buried Laboratories genome prism must carry deterministic focal motion.")
                    _expect(not labs_prism_ring.scale.is_equal_approx(labs_prism_ring_before), "Buried Laboratories prism ring must pulse with the extraction signal.")
                    _expect(not labs_cradle.position.is_equal_approx(labs_cradle_before), "Buried Laboratories extraction cradle must carry restrained suspension motion.")
            if landmark.region_kind == &"tenement":
                var tenement_floor := landmark.find_child("TenementFloor", true, false) as MeshInstance3D
                var tenement_floor_material := tenement_floor.material_override as StandardMaterial3D if tenement_floor != null else null
                _expect(tenement_floor_material != null and tenement_floor_material.albedo_color.r < 0.16 and tenement_floor_material.albedo_color.g < 0.3 and not tenement_floor_material.emission_enabled, "East Tenements must keep the broad authored floor dark enough to preserve the residential block silhouette under the review key.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/AuthoredEncounterDressing/TenementVerticalLifeDetails") != null, "East Tenements must expose an authored vertical residential vignette.")
                var tenement_facade_shell := landmark.find_child("TenementFacadeShellCore", true, false) as MeshInstance3D
                var tenement_facade_material := tenement_facade_shell.material_override as StandardMaterial3D if tenement_facade_shell != null else null
                _expect(tenement_facade_material != null and tenement_facade_material.albedo_color.r < 0.3 and not tenement_facade_material.emission_enabled, "East Tenements encounter dressing must keep its broad facade shell dark enough to support attached residential detail.")
                _expect(landmark.find_child("TenementFireEscapeLadder", true, false) != null, "East Tenements must expose a readable fire-escape route signature.")
                _expect(landmark.find_child("TenementRoofWaterTank", true, false) != null, "East Tenements must expose a rooftop service identity.")
                var tenement_roof_housing := landmark.find_child("TenementLeftRoofServiceHousing", true, false) as MeshInstance3D
                var tenement_roof_vent := landmark.find_child("TenementLeftRoofVent", true, false) as MeshInstance3D
                _expect(tenement_roof_housing != null and tenement_roof_vent != null and _mesh_vertex_count(tenement_roof_housing) >= 48 and _mesh_vertex_count(tenement_roof_vent) >= 48, "East Tenements must retain a layered left-roof maintenance housing and vent silhouette.")
                _expect(landmark.find_child("TenementLeftRoofVentCap", true, false) != null and landmark.find_child("TenementLeftRoofPipe", true, false) != null, "East Tenements left-roof service hardware must retain a cap and connected pipe detail.")
                _expect(landmark.find_child("TenementFrontWindowL0_0", true, false) != null and landmark.find_child("TenementBlockLEdgeL", true, false) != null, "East Tenements must expose approach-facing windows and facade edge breaks.")
                var tenement_facade_band := landmark.find_child("TenementFacadeBandL0", true, false) as MeshInstance3D
                var tenement_facade_pillar := landmark.find_child("TenementFacadePillarL", true, false) as MeshInstance3D
                _expect(tenement_facade_band != null and tenement_facade_pillar != null, "East Tenements must expose authored floor bands and a central approach-facing facade spine.")
                _expect(tenement_facade_band != null and _mesh_vertex_count(tenement_facade_band) >= 48 and tenement_facade_pillar != null and _mesh_vertex_count(tenement_facade_pillar) >= 48, "East Tenements facade bands and spine must retain beveled high-definition geometry.")
                _expect(landmark.find_child("TenementFrontWindowRevealL0_0", true, false) != null and landmark.find_child("TenementFrontWindowJambL0_0", true, false) != null and landmark.find_child("TenementFrontWindowMullionL0_0", true, false) != null, "East Tenements must expose recessed window bays with vertical frame hardware.")
                _expect(landmark.find_child("TenementFrontWindowLintelL0_0", true, false) != null and landmark.find_child("TenementFrontWindowSillL0_0", true, false) != null, "East Tenements must expose approach-facing window framing detail.")
                _expect(landmark.find_child("TenementBalconyBrace0_L", true, false) != null and landmark.find_child("TenementTankValve", true, false) != null, "East Tenements must expose structural balcony and roof-tank service detail.")
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/TenementAuthoredModel") != null, "East Tenements must expose its authored residential block landmark shell.")
                var tenement_block := landmark.find_child("TenementBlockL", true, false) as MeshInstance3D
                var tenement_edge := landmark.find_child("TenementBlockLEdgeL", true, false) as MeshInstance3D
                _expect(tenement_block != null and tenement_edge != null and _mesh_vertex_count(tenement_block) >= 48 and _mesh_vertex_count(tenement_edge) >= 48, "East Tenements authored blocks must retain beveled high-definition facade geometry.")
                var tenement_creep := landmark.find_child("TenementOrganicCreep0", true, false) as Node3D
                _expect(tenement_creep != null, "East Tenements must expose a named organic-creep motion socket.")
                _expect(landmark.find_child("TenementLaundryLine0", true, false) != null and landmark.find_child("TenementLightHousingL", true, false) != null and landmark.find_child("TenementOrganicTendril0_0", true, false) != null, "East Tenements must expose lived-in laundry, window-light and organic detail.")
                var tenement_laundry := landmark.find_child("TenementLaundry", true, false) as Node3D
                var tenement_laundry_core := tenement_laundry.get_node_or_null("TenementLaundryCore") as MeshInstance3D if tenement_laundry != null else null
                var tenement_laundry_material := tenement_laundry_core.material_override as StandardMaterial3D if tenement_laundry_core != null else null
                _expect(tenement_laundry != null and tenement_laundry.get_child_count() >= 5 and tenement_laundry_material != null and tenement_laundry_material.albedo_color.r < 0.8 and tenement_laundry_material.albedo_color.g < 0.75, "East Tenements laundry must retain beveled cloth detail with muted residential tones rather than saturated placeholder cards.")
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
        for _frame in range(8):
            await process_frame
        _expect(region_lod.detail_mode_for(&"region.west_grid") == 0, "The player’s current region must retain full landmark detail.")
        _expect(region_lod.detail_mode_for(&"region.root_cistern") == 2, "Distant endgame landmarks must reduce to beacon detail without leaving the world state.")
        var distant_root := region_director.get_landmark(&"region.root_cistern")
        var distant_proxy := distant_root.get_node_or_null("ReducedRegionProxy") as Node3D if distant_root != null else null
        var distant_detail := distant_root.get_node_or_null("PersistentRegionGeometry") as Node3D if distant_root != null else null
        var distant_authored_package := distant_root.get_node_or_null("PersistentRegionGeometry/RootCisternAuthoredScene") as Node3D if distant_root != null else null
        _expect(distant_proxy != null and distant_proxy.visible, "Distant endgame regions must retain a readable coarse authored proxy.")
        _expect(distant_detail != null and not distant_detail.visible, "Distant region detail must be hidden while the coarse proxy is active.")
        _expect(distant_authored_package != null and distant_authored_package.get_child_count() == 0, "A distant endgame region must release its imported authored package nodes rather than merely hiding them.")
        _expect(not region_lod.is_region_streamed(&"region.root_cistern"), "A landmark beyond the camera stream ring must release its authored dressing while retaining the reduced-detail proxy.")
        var distant_release_detail := release_art.region_dressing_root(&"region.root_cistern") if release_art != null else null
        _expect(distant_release_detail != null and not distant_release_detail.visible, "Distant regions must hide their separate high-definition release dressing while the coarse proxy is active.")
        _expect(distant_release_detail != null and distant_release_detail.get_child_count() == 0, "Distant regions must release their separate high-definition encounter dressing nodes rather than merely hiding them.")
        world.player.global_position = distant_root.global_position if distant_root != null else Vector3(128.0, 0.0, -116.0)
        region_atmosphere.refresh_now()
        region_lod.refresh_now()
        # Authored region packages attach on the next idle frame so imported
        # renderer resources finish their threaded-load handoff safely. The
        # release dressing also waits for its bounded renderer-settle window
        # after a stream-out before creating fresh procedural meshes.
        for _frame in range(6):
            await process_frame
        _expect(region_lod.detail_mode_for(&"region.root_cistern") == 0 and distant_proxy != null and not distant_proxy.visible, "Entering a distant region must restore full detail and retire its coarse proxy.")
        _expect(distant_authored_package != null and distant_authored_package.get_child_count() > 0, "Entering a distant region must re-instantiate its imported authored package nodes.")
        _expect(distant_release_detail != null and distant_release_detail.get_child_count() > 0, "Entering a distant region must re-instantiate its high-definition encounter dressing nodes.")
        _expect(distant_release_detail != null and distant_release_detail.visible, "Entering a region must restore its separate high-definition release dressing with the full landmark detail.")
        world.player.global_position = Vector3(-92.0, 0.0, 18.0)
        region_atmosphere.refresh_now()
        region_lod.refresh_now()
        for _frame in range(8):
            await process_frame
        _expect(not region_lod.is_region_streamed(&"region.root_cistern"), "A region beyond the camera stream ring must release its authored dressing while retaining its persistent landmark state.")
        _expect(distant_authored_package != null and distant_authored_package.get_child_count() == 0, "Leaving a restored region must release its imported authored package nodes again.")
        _expect(distant_release_detail != null and distant_release_detail.get_child_count() == 0, "Leaving a restored region must release its high-definition encounter dressing nodes again.")
        _expect(distant_proxy != null and distant_proxy.visible, "A streamed-out discovered region must retain its coarse proxy beacon.")
        world.player.global_position = Vector3(-92.0, 0.0, 18.0)
        region_atmosphere.refresh_now()
        region_lod.refresh_now()
        for _frame in range(8):
            await process_frame
    var heartforge := world.get_node_or_null("Heartforge") as Heartforge3D
    _expect(heartforge != null, "The aesthetic test needs the Heartforge progression model.")
    if heartforge != null:
        var heartforge_presentation := heartforge.get_node_or_null("HeartforgePresentation3D") as HeartforgePresentation3D
        _expect(heartforge_presentation != null, "The Heartforge must receive authored progression presentation.")
        _expect(heartforge.find_child("HeartforgeAuthoredModel", true, false) != null, "The Heartforge must use the authored production shell.")
        _expect(_find_named(heartforge, "ProductionAssetMarker") != null, "The authored Heartforge must expose its production asset marker.")
        _expect(heartforge.find_child("CoreCladdingDetail", true, false) != null, "The Heartforge must expose a layered high-definition core cladding detail.")
        _expect(heartforge.find_child("CoreServiceLouver", true, false) != null, "The Heartforge must expose a readable powered service louver.")
        _expect(heartforge.find_child("CoreInspectionPort", true, false) != null, "The Heartforge must expose a readable inspection port.")
        _expect(heartforge.find_child("HeartforgeFocalDetail", true, false) != null, "The Heartforge must expose a bounded focal reactor/control detail layer.")
        _expect(heartforge.find_child("HeartforgeUpperCollar", true, false) != null and heartforge.find_child("HeartforgeFocalControlFace", true, false) != null, "The Heartforge focal layer must expose an upper reactor collar and player-facing control face.")
        _expect(heartforge.find_child("HeartforgeFocalRadialFin00", true, false) != null and heartforge.find_child("HeartforgeFocalSignalLens01", true, false) != null, "The Heartforge focal layer must expose radial heat hardware and a readable tri-signal lens bank.")
        _expect(heartforge.find_child("HeartforgeCoolantPipeLeft", true, false) != null and heartforge.find_child("HeartforgeServiceLatchLeft", true, false) != null and heartforge.find_child("HeartforgeConduitClipLeft", true, false) != null, "The authored Heartforge must expose layered coolant routing and service-latch hardware.")
        _expect(heartforge.find_child("HeartforgeThermalShroud00", true, false) != null and heartforge.find_child("HeartforgeThermalShroudCap00", true, false) != null and heartforge.find_child("ForgeBenchBraceLeft", true, false) != null, "The Heartforge focal and fabrication surfaces must expose manufactured shrouds and bench bracing.")
        _expect(_find_named(heartforge, "HeartforgeFoundationBolt00") != null, "The authored Heartforge must expose anchored foundation hardware.")
        var authored_heartforge := heartforge.find_child("HeartforgeAuthoredModel", true, false) as Node3D
        var authored_housing := heartforge.find_child("CoreHousingShell", true, false) as MeshInstance3D
        var authored_furnace := heartforge.find_child("FurnaceCore", true, false) as MeshInstance3D
        _expect(authored_housing != null and _mesh_vertex_count(authored_housing) >= 900, "The Heartforge reactor housing must retain a dense smooth focal envelope.")
        _expect(authored_furnace != null and _mesh_vertex_count(authored_furnace) >= 900, "The Heartforge furnace must retain a dense smooth focal envelope.")
        var authored_bench := heartforge.find_child("ForgeBench", true, false) as MeshInstance3D
        var authored_plate := heartforge.find_child("AssemblyPlate", true, false) as MeshInstance3D
        _expect(authored_bench != null and _mesh_vertex_count(authored_bench) > 24, "The Heartforge fabrication bench must use chamfered high-definition geometry rather than a flat box.")
        _expect(authored_plate != null and _mesh_vertex_count(authored_plate) > 24, "The Heartforge assembly plate must use chamfered high-definition geometry rather than a flat box.")
        var authored_emission_peak := 0.0
        if authored_heartforge != null:
            for raw_mesh in authored_heartforge.find_children("*", "MeshInstance3D", true, false):
                var mesh_instance := raw_mesh as MeshInstance3D
                if mesh_instance == null or mesh_instance.mesh == null:
                    continue
                for surface_index in range(mesh_instance.mesh.get_surface_count()):
                    var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
                    if material != null and material.emission_enabled:
                        authored_emission_peak = maxf(authored_emission_peak, material.emission_energy_multiplier)
        _expect(authored_emission_peak <= 0.91, "The authored Heartforge shell must cap thermal/service emission so the focal machinery retains material separation.")
        heartforge.set_operation(&"")
        var heartforge_lights := heartforge.find_children("*", "OmniLight3D", true, false)
        var strongest_heartforge_light := 0.0
        for raw_light in heartforge_lights:
            strongest_heartforge_light = maxf(strongest_heartforge_light, (raw_light as OmniLight3D).light_energy)
        _expect(strongest_heartforge_light <= Heartforge3D.RESTING_CORE_LIGHT_ENERGY + 0.01, "The resting Heartforge light must preserve a warm focal key without flattening the district.")
        heartforge.set_progression_tier(5)
        _expect(heartforge.find_child("AdaptiveHeartforgeGeometry", true, false) != null, "Heartforge progression must own a dedicated adaptive geometry layer.")
        _expect(heartforge.find_child("Tier2Buttress", true, false) != null, "Tier 2 Heartforge geometry must add structural buttresses.")
        _expect(heartforge.find_child("Tier3SignalConduit", true, false) != null, "Tier 3 Heartforge geometry must add signal conduits.")
        var heat_ring := heartforge.find_child("Tier3HeatRing", true, false) as MeshInstance3D
        _expect(heat_ring != null and heat_ring.mesh is ArrayMesh, "Tier 3 Heartforge thermal hardware must retain an open ring silhouette rather than a filled plate.")
        _expect(heartforge.find_child("Tier4SignalMast", true, false) != null, "Tier 4 Heartforge geometry must add the signal mast.")
        var crown := heartforge.find_child("Tier5SovereigntyCrown", true, false) as MeshInstance3D
        _expect(crown != null and crown.mesh is TorusMesh, "Tier 5 Heartforge geometry must culminate in a readable open crown ring rather than a filled plate.")
        var crown_material := crown.material_override as StandardMaterial3D if crown != null else null
        var crown_mesh := crown.mesh as TorusMesh if crown != null else null
        _expect(crown_mesh != null and crown_mesh.outer_radius <= 2.75, "The Tier 5 crown ring must leave the reactor and service face visible instead of spanning the opening frame.")
        _expect(crown_material != null and crown_material.emission_energy_multiplier <= 0.4, "The Tier 5 crown ring must retain a restrained warm accent instead of becoming the brightest surface in the tactical frame.")
        var crown_fin := heartforge.find_child("Tier5CrownFinCore", true, false) as MeshInstance3D
        var crown_fin_material := crown_fin.material_override as StandardMaterial3D if crown_fin != null else null
        _expect(crown_fin_material != null and crown_fin_material.emission_energy_multiplier <= 0.5, "The Tier 5 crown fins must retain a restrained cyan accent instead of clipping into white bars around the ring.")
        if heartforge_presentation != null:
            var settings_service := get_first_node_in_group("release_settings_service") as ReleaseSettingsService3D
            var previous_reduced_motion := bool(settings_service.get_value(&"reduced_motion", false)) if settings_service != null else false
            if settings_service != null:
                settings_service.set_value(&"reduced_motion", false, false)
            var beacon := heartforge.find_child("Tier5CrownBeacon", true, false) as Node3D
            var beacon_mesh := beacon as MeshInstance3D
            var beacon_material := beacon_mesh.material_override as StandardMaterial3D if beacon_mesh != null else null
            _expect(beacon_material != null and beacon_material.emission_energy_multiplier <= 0.56, "The Tier 5 crown beacon must retain a restrained warm accent instead of clipping the opening frame.")
            var beacon_scale_before := beacon.scale if beacon != null else Vector3.ONE
            heartforge_presentation.progression_time = 0.0
            heartforge_presentation._process(0.0)
            heartforge_presentation.progression_time = 0.8
            heartforge_presentation._process(0.0)
            var beacon_scale_after := beacon.scale if beacon != null else Vector3.ONE
            _expect(beacon != null and not beacon_scale_before.is_equal_approx(beacon_scale_after), "Tier 5 Heartforge hardware must carry restrained progression-state motion.")
            if settings_service != null:
                settings_service.set_value(&"reduced_motion", true, false)
                var reduced_motion_scale := beacon.scale if beacon != null else Vector3.ONE
                heartforge_presentation.progression_time = 1.6
                heartforge_presentation._process(0.0)
                _expect(beacon != null and reduced_motion_scale.is_equal_approx(beacon.scale), "Heartforge progression motion must pause when reduced motion is enabled.")
                settings_service.set_value(&"reduced_motion", previous_reduced_motion, false)
        var adaptation_settings_service := get_first_node_in_group("release_settings_service") as ReleaseSettingsService3D
        var adaptation_previous_reduced_motion := bool(adaptation_settings_service.get_value(&"reduced_motion", false)) if adaptation_settings_service != null else false
        if adaptation_settings_service != null:
            adaptation_settings_service.set_value(&"reduced_motion", false, false)
        heartforge.set_adaptation_preview(&"adaptation.pending", 0.22)
        var adaptation_preview := heartforge.get_node_or_null("HeartforgeModel/HeartforgeAdaptationPreview") as Node3D
        _expect(adaptation_preview != null and adaptation_preview.visible, "The adaptive Heartforge must expose a visible proposal footprint before authorization.")
        _expect(heartforge.find_child("AdaptationPreviewRing", true, false) != null, "The adaptive proposal footprint must use a bounded open perimeter ring.")
        var adaptation_worksite := heartforge.find_child("AdaptationWorksiteCrew", true, false) as Node3D
        _expect(adaptation_worksite != null and adaptation_worksite.get_child_count() == 3, "The adaptive proposal footprint must expose a bounded three-machine construction crew.")
        _expect(heartforge.find_child("AdaptationBuilderTool00", true, false) != null and heartforge.find_child("AdaptationBuilderBeacon00", true, false) != null, "The adaptive construction crew must expose a readable tool arm and work beacon.")
        if heartforge_presentation != null and adaptation_worksite != null:
            heartforge_presentation.progression_time = 0.0
            heartforge_presentation._process(0.0)
            var worksite_rotation_before := adaptation_worksite.rotation.y
            heartforge_presentation.progression_time = 0.8
            heartforge_presentation._process(0.0)
            _expect(not is_equal_approx(worksite_rotation_before, adaptation_worksite.rotation.y), "The adaptive construction crew must carry a restrained perimeter work motion.")
        var adaptation_preview_scale := adaptation_preview.scale if adaptation_preview != null else Vector3.ZERO
        heartforge.set_adaptation_preview(&"adaptation.pending", 0.72)
        _expect(heartforge.adaptation_preview_progress > 0.7 and adaptation_preview != null and not adaptation_preview_scale.is_equal_approx(adaptation_preview.scale), "The adaptive proposal footprint must advance through a readable bounded reveal.")
        heartforge.set_adaptation_profile(&"adaptation.anchored_shell")
        _expect(heartforge.find_child("HeartforgeAdaptationDetail", true, false) != null, "The adaptive Heartforge must expose a visible authored retrofit detail layer.")
        _expect(heartforge.find_child("AnchorShellBrace", true, false) != null and heartforge.find_child("AnchorShellSignalRing", true, false) != null and heartforge.find_child("AnchorShellFooting", true, false) != null and heartforge.find_child("AnchorShellAnchorPin", true, false) != null, "The anchored-shell response must expose structural braces, anchored footings and a signal ring.")
        _expect(heartforge.adaptive_collision_shape_count() == 4 and heartforge.find_child("AnchorShellCollisionWest", false, false) != null and heartforge.find_child("AnchorShellCollisionSouth", false, false) != null, "The anchored-shell response must add four bounded physical perimeter braces after authorization.")
        heartforge.set_adaptation_profile(&"adaptation.anchored_shell")
        _expect(heartforge.adaptive_collision_shape_count() == 4 and heartforge.get_node_or_null("AnchorShellCollisionWest") != null and heartforge.get_node_or_null("AnchorShellCollisionEast") != null, "Restoring the same adaptive profile immediately must rebuild exactly one stable collision layer without duplicate sockets.")
        if heartforge_presentation != null:
            var anchor_ring := heartforge.find_child("AnchorShellSignalRing", true, false) as Node3D
            var anchor_ring_before := anchor_ring.rotation.z if anchor_ring != null else 0.0
            heartforge_presentation.progression_time = 0.8
            heartforge_presentation._process(0.0)
            _expect(anchor_ring != null and not is_equal_approx(anchor_ring_before, anchor_ring.rotation.z), "The anchored-shell response must carry a restrained structural pulse after construction.")
        heartforge.set_adaptation_profile(&"adaptation.sacrificial_hollow")
        _expect(heartforge.find_child("SacrificialHollowRib", true, false) != null and heartforge.find_child("SacrificialHollowCap", true, false) != null and heartforge.find_child("SacrificialHollowService", true, false) != null, "The sacrificial-hollow response must expose replaceable outer ribs, capped service hardware and an expendable service face.")
        _expect(heartforge.adaptive_collision_shape_count() == 8 and heartforge.find_child("SacrificialHollowCollision00", false, false) != null, "The sacrificial-hollow response must add one physical shell piece per replaceable rib.")
        heartforge.set_adaptation_profile(&"adaptation.quiet_core")
        _expect(heartforge.find_child("QuietCoreShroud", true, false) != null and heartforge.find_child("QuietCoreDampenerBaffle", true, false) != null and heartforge.find_child("QuietCoreSignalPanel", true, false) != null, "The quiet-core response must expose damped shrouds, baffles and signal-panel detail.")
        _expect(heartforge.adaptive_collision_shape_count() == 2 and heartforge.find_child("QuietCoreCollisionWest", false, false) != null, "The quiet-core response must retain two bounded physical dampener housings.")
        heartforge.set_adaptation_profile(&"")
        _expect(heartforge.adaptive_collision_shape_count() == 0 and heartforge.find_child("HeartforgeCoreCollision", false, false) != null, "Clearing an adaptation must remove only its profile shell and retain the permanent Heartforge core collision.")
        if adaptation_settings_service != null:
            adaptation_settings_service.set_value(&"reduced_motion", adaptation_previous_reduced_motion, false)
        _expect(heartforge.find_child("HeartforgeDamagePresentation", true, false) != null, "The Heartforge must expose a bounded damage-memory presentation layer.")
        _expect(heartforge.find_child("HeartforgeDamageScar00", true, false) != null and heartforge.find_child("HeartforgeDamageLeak00", true, false) != null, "The Heartforge damage layer must expose stable scar and leak sockets.")
        heartforge.apply_damage(heartforge.maximum_health * 0.68)
        var damage_layer := heartforge.find_child("HeartforgeDamagePresentation", true, false) as Node3D
        var damage_scar := heartforge.find_child("HeartforgeDamageScar00", true, false) as Node3D
        _expect(damage_layer != null and damage_layer.visible, "Heartforge damage must visibly expose the failure memory after integrity loss.")
        _expect(damage_scar != null and damage_scar.visible, "Heartforge damage must reveal the first scar at meaningful integrity loss.")
        heartforge.repair(heartforge.maximum_health)
        _expect(damage_layer != null and not damage_layer.visible, "Heartforge repair must clear the damage-memory layer when integrity is restored.")

    var environment_node := _find_world_environment(world)
    _expect(environment_node != null and environment_node.environment != null, "The world needs a configured environment.")
    if environment_node != null and environment_node.environment != null:
        var environment := environment_node.environment
        _expect(float(environment.get_meta(&"ambient_readability_floor", 0.0)) >= 0.50, "The authored atmosphere must publish a shared ambient readability floor for every region.")
        _expect(environment.ambient_light_energy >= 0.50, "The opening readability pass must retain a readable ambient floor rather than collapsing the wet district into black.")
        _expect(environment.fog_density <= 0.015, "Fog may shape depth but must not crush visibility.")
        _expect(environment.tonemap_mode == Environment.TONE_MAPPER_ACES, "ACES tonemapping should provide stable cinematic contrast.")
        if environment.sky != null and environment.sky.sky_material is ProceduralSkyMaterial:
            var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
            _expect(sky_material.sun_angle_max <= 7.0, "The blue-hour sun disk must remain a restrained atmospheric accent instead of a white tactical-frame plate.")

    var player := get_first_node_in_group("player_character") as Node3D
    _expect(player != null, "The aesthetic test needs the Mechromancer.")
    if player != null:
        var player_presentation := player.get_node_or_null("MechromancerPresentation3D") as MechromancerPresentation3D
        _expect(player_presentation != null, "The Mechromancer must receive authored animation presentation.")
        _expect(_find_named(player, "ProductionAssetMarker") != null, "The Mechromancer must use the authored asset contract.")
        _expect(_find_named(player, "PistolMuzzle") != null, "The authored Mechromancer must expose the pistol muzzle socket.")
        _expect(_model_has_details(player), "The Mechromancer must receive additional authored silhouette detail.")
        _expect(_find_named(player, "FieldShoulderGuard") != null and _find_named(player, "FieldCommsPanel") != null and _find_named(player, "FieldCommsBeacon") != null, "The Mechromancer must carry the finished asymmetrical field-kit silhouette.")
        _expect(_find_named(player, "ChestHarness") != null and _find_named(player, "PistolGrip") != null and _find_named(player, "PistolMuzzleCollar") != null and _find_named(player, "PistolFrontSight") != null and _find_named(player, "HarnessFastener") != null, "The Mechromancer focal harness and weak-pistol assembly must retain layered high-definition hardware.")
        var player_model := player.get_node_or_null("MechromancerModel") as Node3D
        _expect(player_model != null and player_model.scale.x >= 1.2, "The authored Mechromancer must be legible at tactical-camera distance.")
        _expect(_find_named(player, "RespiratorCollarCore") != null and _find_named(player, "FieldPackCornerCap") != null, "The Mechromancer must receive beveled authored equipment surfaces.")
        _expect(_find_named(player, "FieldShoulderLampLens") != null and _find_named(player, "FieldUtilityCanister") != null and _find_named(player, "FieldToolDeck") != null, "The Mechromancer must receive a second high-definition field-instrument detail layer.")
        _expect(_find_named(player, "FieldForearmDiagnostic") != null and _find_named(player, "FieldForearmDiagnosticLens") != null, "The Mechromancer must expose a readable forearm diagnostic detail.")
        _expect(_find_named(player, "FieldKneeGuardLeft") != null and _find_named(player, "FieldKneeGuardRight") != null and _find_named(player, "FieldCableClamp") != null, "The Mechromancer micro-detail pass must preserve protected field hardware.")
        _expect(_find_named(player, "FieldHoodRim") != null and _find_named(player, "FieldVisorHousing") != null, "The Mechromancer field-finish pass must retain a readable hood and visor material break.")
        _expect(_find_named(player, "FieldWorkGloveLeft") != null and _find_named(player, "FieldWorkGloveRight") != null and _find_named(player, "FieldCoatHemLeft") != null and _find_named(player, "FieldCoatHemRight") != null, "The Mechromancer field-finish pass must retain paired work gloves and grounded coat-hem hardware.")
        _expect(_find_named(player, "FieldPackBackplate") != null and _find_named(player, "FieldPackFrameRailLeft") != null and _find_named(player, "FieldPackTopRoll") != null and _find_named(player, "FieldPackServiceCable") != null, "The Mechromancer hero surface pass must retain a framed rear pack and readable service cable.")
        _expect(_find_named(player, "FieldCommsYoke") != null and _find_named(player, "FieldCommsAntenna") != null and _find_named(player, "FieldCommsBeacon") != null and _find_named(player, "FieldCommsCable") != null, "The Mechromancer must retain the asymmetrical communications yoke with antenna, beacon and service cable.")
        _expect(_find_named(player, "HoodLowerSeam") != null and _find_named(player, "VisorBrow") != null and _find_named(player, "VisorMountLeft") != null and _find_named(player, "VisorMountRight") != null, "The authored Mechromancer must retain the protective hood seam and fastened visor brow finish.")
        if player_presentation != null:
            _expect(player_presentation.animation_player != null, "The authored Mechromancer must expose an imported animation player.")
            if player_presentation.animation_player != null:
                for clip_name in [&"Idle", &"Walk", &"Fire", &"Work", &"Upgrade", &"Hit"]:
                    _expect(_animation_player_has_clip(player_presentation.animation_player, clip_name), "The authored Mechromancer must expose the %s animation clip." % clip_name)
                    _expect(_animation_player_track_count(player_presentation.animation_player, clip_name) >= 2, "The authored Mechromancer %s clip must carry body and equipment motion channels." % clip_name)
                player_presentation._on_channel_started(&"forge_upgrade", 1.0, "Upgrade the Heartforge.")
                _expect(_animation_clip_matches(player_presentation.active_clip, &"Upgrade"), "The forge_upgrade channel must select the authored Mechromancer Upgrade clip.")
                player.apply_progression_visuals({
                    &"unlock_machine_society": true,
                    &"unlock_adaptive_defence": true,
                    &"unlock_final_protocol_research": true,
                    &"machine_signal_lattice": true,
                }, 5)
                var cognition_node := player.get_node_or_null("MechromancerProgressionVisuals/MechromancerTierIIICognitionNode") as Node3D
                var sensor_lens := player.get_node_or_null("MechromancerProgressionVisuals/MechromancerTierIVBioSensorLens") as Node3D
                var shoulder_brace := player.get_node_or_null("MechromancerProgressionVisuals/MechromancerTierIIShoulderBrace") as Node3D
                var protocol_clasp := player.get_node_or_null("MechromancerProgressionVisuals/MechromancerTierVProtocolClasp") as Node3D
                _expect(cognition_node != null and sensor_lens != null, "The progression animation test must expose cognition and sensor hardware.")
                _expect(shoulder_brace != null and protocol_clasp != null and shoulder_brace.position.y > 1.0 and protocol_clasp.position.y > 1.0 and shoulder_brace.position.z < 0.0 and protocol_clasp.position.z < 0.0, "Mechromancer progression hardware must attach to the body volume rather than falling below the presentation floor.")
                if cognition_node != null and sensor_lens != null:
                    player_presentation.progression_time = 0.0
                    player_presentation._animate_progression_hardware()
                    var initial_cognition_scale := cognition_node.scale
                    var initial_sensor_rotation := sensor_lens.rotation.y
                    player_presentation.progression_time = 0.8
                    player_presentation._animate_progression_hardware()
                    _expect(not initial_cognition_scale.is_equal_approx(cognition_node.scale), "The cognition node must carry a bounded progression pulse.")
                    _expect(not is_equal_approx(initial_sensor_rotation, sensor_lens.rotation.y), "The adaptive sensor must carry a readable sweep response.")
        if audio_director != null:
            var event_count_before := audio_director.event_count
            audio_director.play_profile(&"pistol", player.global_position)

            _expect(audio_director.event_count == event_count_before + 1, "The spatial audio director must emit a pistol event at runtime.")
            audio_director.stop_all()

    var disabled_mechromancer := MECHROMANCER_SCENE.instantiate() as Mechromancer3D
    disabled_mechromancer.position = Vector3(36.0, 0.0, 28.0)
    root.add_child(disabled_mechromancer)
    await process_frame
    disabled_mechromancer.apply_damage(disabled_mechromancer.maximum_health * 2.0)
    _expect(disabled_mechromancer.current_health <= 0.0, "A lethal Mechromancer hit must preserve the game-over health state.")
    _expect(disabled_mechromancer.death_presentation_remaining > 0.0, "The Mechromancer must retain a bounded presentation window after death.")
    _expect(_find_named(disabled_mechromancer, "MechromancerDeathPresentation") != null and bool(_find_named(disabled_mechromancer, "MechromancerDeathPresentation").visible), "The Mechromancer must expose a visible collapse presentation before the ending overlay resolves.")
    _expect(_find_named(disabled_mechromancer, "MechromancerDeathCollapsedTorso") != null and _find_named(disabled_mechromancer, "MechromancerDeathRespiratorCollar") != null, "The Mechromancer death presentation must retain readable field-kit failure anatomy.")
    _expect(_find_named(disabled_mechromancer, "MechromancerDeathSignal") != null and _find_named(disabled_mechromancer, "MechromancerDeathShard00") != null, "The Mechromancer death presentation must expose a spent signal and fractured equipment fragments.")
    disabled_mechromancer.heal_full()
    _expect(not bool(_find_named(disabled_mechromancer, "MechromancerDeathPresentation").visible), "Healing a test Mechromancer must clear the death presentation state.")
    disabled_mechromancer.queue_free()

    var robots := get_nodes_in_group("friendly_robots")
    _expect(not robots.is_empty(), "The opening companion must exist.")
    if not robots.is_empty():
        var robot := robots[0] as Node3D
        _expect(robot.get_node_or_null("ProceduralAnimator3D") is ProceduralAnimator3D, "Robots must receive procedural gait and recoil animation.")
        var robot_animation := robot.get_node_or_null("AuthoredActorAnimation3D") as AuthoredActorAnimation3D
        _expect(robot_animation != null and robot_animation.animation_player != null, "Robots must route authored animation clips through a runtime presentation bridge.")
        if robot_animation != null and robot_animation.animation_player != null:
            _expect(_animation_player_has_clip(robot_animation.animation_player, &"Idle"), "Robot authored models must expose an Idle clip.")
            _expect(_animation_player_has_clip(robot_animation.animation_player, &"Walk"), "Robot authored models must expose a Walk clip.")
            _expect(_animation_player_track_count(robot_animation.animation_player, &"Idle") >= 2, "Robot Idle clips must carry primary and secondary authored motion channels.")
            _expect(_animation_player_track_count(robot_animation.animation_player, &"Walk") >= 2, "Robot Walk clips must carry body and locomotion authored motion channels.")
            _expect(_animation_player_track_count(robot_animation.animation_player, &"Fire") >= 2, "Robot Fire clips must carry weapon and reaction authored motion channels.")
            _expect(_animation_player_has_clip(robot_animation.animation_player, &"Hit"), "Robot authored models must expose a Hit clip.")
            _expect(_animation_player_track_count(robot_animation.animation_player, &"Hit") >= 2, "Robot Hit clips must carry body and sensor reaction authored motion channels.")
            _expect(_animation_player_has_clip(robot_animation.animation_player, &"Retreat"), "Robot authored models must expose a Retreat clip.")
            _expect(_animation_player_track_count(robot_animation.animation_player, &"Retreat") >= 2, "Robot Retreat clips must carry body and sensor withdrawal channels.")
            _expect(_animation_player_has_clip(robot_animation.animation_player, &"Death"), "Robot authored models must expose a Death clip.")
            _expect(_animation_player_track_count(robot_animation.animation_player, &"Death") >= 2, "Robot Death clips must carry body collapse channels.")
            robot_animation._on_weapon_fired(Vector3.ZERO, Vector3.FORWARD, null)
            _expect(_animation_clip_matches(robot_animation.active_clip, &"Fire"), "Robot weapon events must select the authored Fire clip.")
            robot_animation._on_health_changed(robot, 40.0, 90.0)
            _expect(_animation_clip_matches(robot_animation.active_clip, &"Hit"), "Robot damage events must select the authored Hit clip.")
            robot.state_name = &"retreating"
            robot_animation.one_shot_remaining = 0.0
            robot_animation._select_loop_clip()
            _expect(_animation_clip_matches(robot_animation.active_clip, &"Retreat"), "Robot retreat state must select the authored Retreat clip.")
        _expect(_model_has_details(robot), "Robots must receive additional role-readable detail.")
        _expect(_find_named(robot, "ShoulderPlate") != null, "Robots must expose layered shoulder armour.")
        _expect(_find_named(robot, "ChassisDetailPanel") != null, "Robots must expose a layered high-detail chassis panel.")
        _expect(_find_named(robot, "Chassis") != null and _find_named(robot, "ChassisCore") != null and _find_named(robot, "ChassisCornerCap") != null, "Robots must use the original beveled chassis treatment.")
        _expect(_find_named(robot, "RaisedArmorPanelCore") != null and _find_named(robot, "RaisedArmorPanelCornerCap") != null, "Robots must retain beveled shared armor feedback hardware.")
        _expect(_find_named(robot, "OpticLens") != null, "Robots must expose a readable optic lens.")
        if robot.get(&"archetype") in [&"companion", &"guardian"]:
            _expect(_find_named(robot, "ProtectiveBrowCore") != null and _find_named(robot, "ProtectiveBrowCornerCap") != null, "Protection-oriented robots must retain beveled brow hardware.")
        elif robot.get(&"archetype") not in [&"scout"]:
            _expect(_find_named(robot, "ScrapBasketCore") != null and _find_named(robot, "ScrapBasketCornerCap") != null, "Utility robots must retain beveled salvage-basket hardware.")
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
        _expect(_find_named(robot, "BulwarkRadiatorLouver") != null and _find_named(robot, "BulwarkFrontSensorVisor") != null and _find_named(robot, "BulwarkEmitterCollar") != null, "The Bulwark must receive a second high-definition protection hardware layer.")
        _expect(_find_named(robot, "BulwarkEmitterAperture") != null and _find_named(robot, "BulwarkEmitterLensInset") != null and _find_named(robot, "BulwarkEmitterFastener00") != null, "The Bulwark protection instrument must retain its nested aperture, inset lens and service fasteners.")
        _expect(_find_named(robot, "BulwarkServiceFace") != null and _find_named(robot, "BulwarkServiceLatchLeft") != null and _find_named(robot, "BulwarkShoulderRailLeft") != null and _find_named(robot, "BulwarkFootPlateLeft") != null, "The Bulwark must expose its refined service face, shoulder rail and foot hardware.")
        _expect(_find_named(robot, "BulwarkActuatorRingLeft") != null and _find_named(robot, "BulwarkActuatorRingRight") != null and _find_named(robot, "BulwarkSideHeatPanelLeft") != null and _find_named(robot, "BulwarkServiceWindowFrame") != null, "The Bulwark hero surface pass must retain paired actuator, heat-panel and diagnostic-window depth.")
        var bulwark_chassis := _find_named(robot, "Chassis") as MeshInstance3D
        var bulwark_plate := _find_named(robot, "ArmorPlate") as MeshInstance3D
        _expect(bulwark_chassis != null and _mesh_vertex_count(bulwark_chassis) >= 600, "The Bulwark chassis must retain dense rounded high-definition geometry.")
        _expect(bulwark_plate != null and _mesh_vertex_count(bulwark_plate) >= 300, "The Bulwark armor plate must retain dense rounded high-definition geometry.")
        if robot_animation != null and robot_animation.animation_player != null and _find_named(robot, "BulwarkAuthoredModel") != null:
            _expect(_animation_player_track_count(robot_animation.animation_player, &"Idle") >= 6, "Bulwark Idle must carry shield-emitter and guard breathing channels.")
            _expect(_animation_player_track_count(robot_animation.animation_player, &"Walk") >= 7, "Bulwark Walk must carry shield-emitter and guard locomotion channels.")
            _expect(_animation_player_track_count(robot_animation.animation_player, &"Fire") >= 7, "Bulwark Fire must carry emitter, guard and radiator reaction channels.")
            _expect(_animation_player_track_count(robot_animation.animation_player, &"Hit") >= 5, "Bulwark Hit must carry emitter and guard impact channels.")
            _expect(_animation_player_track_count(robot_animation.animation_player, &"Retreat") >= 6, "Bulwark Retreat must carry shield withdrawal and crown response channels.")
            _expect(_animation_player_track_count(robot_animation.animation_player, &"Death") >= 4, "Bulwark Death must carry shield and radiator collapse channels.")

    var organic_actors := get_nodes_in_group("organic_enemies")
    if not organic_actors.is_empty():
        var organic := organic_actors[0] as Node3D
        var organic_animation := organic.get_node_or_null("AuthoredActorAnimation3D") as AuthoredActorAnimation3D
        _expect(organic_animation != null and organic_animation.animation_player != null, "Organic actors must route authored animation clips through a runtime presentation bridge.")
        if organic_animation != null and organic_animation.animation_player != null:
            _expect(_animation_player_has_clip(organic_animation.animation_player, &"Idle"), "Organic authored models must expose an Idle clip.")
            _expect(_animation_player_has_clip(organic_animation.animation_player, &"Walk"), "Organic authored models must expose a Walk clip.")
            _expect(_animation_player_has_clip(organic_animation.animation_player, &"Attack"), "Organic authored models must expose an Attack clip.")
            _expect(_animation_player_track_count(organic_animation.animation_player, &"Idle") >= 2, "Organic Idle clips must carry body and breathing authored motion channels.")
            _expect(_animation_player_track_count(organic_animation.animation_player, &"Walk") >= 2, "Organic Walk clips must carry body and locomotion authored motion channels.")
            _expect(_animation_player_track_count(organic_animation.animation_player, &"Attack") >= 2, "Organic Attack clips must carry body and threat authored motion channels.")
            organic_animation._on_attack_started(organic, player)
            _expect(_animation_clip_matches(organic_animation.active_clip, &"Attack"), "Organic attack signals must select the authored Attack clip.")

    var role_samples: Array[RobotUnit3D] = []
    var role_names := [&"salvager", &"guardian", &"scout", &"engineer", &"relay"]
    for index in role_names.size():
        var sample := ROBOT_SCENE.instantiate() as RobotUnit3D
        sample.configure(role_names[index], 1)
        sample.position = Vector3(15.0 + float(index) * 2.4, 0.0, 10.0)
        root.add_child(sample)
        if role_names[index] == &"relay":
            var relay_animation_component := AuthoredActorAnimation3D.new()
            relay_animation_component.name = "AuthoredActorAnimation3D"
            relay_animation_component.configure(sample)
            sample.add_child(relay_animation_component)
        role_samples.append(sample)
    await process_frame
    for index in role_samples.size():
        _expect(_role_model_has_details(role_samples[index], role_names[index]), "The %s robot must expose a role-readable high-detail silhouette." % role_names[index])
        var role_chassis := _find_named(role_samples[index], "Chassis") as MeshInstance3D
        _expect(role_chassis != null and _mesh_vertex_count(role_chassis) >= 600, "The %s robot must retain a dense rounded chassis envelope." % role_names[index])
        if role_names[index] != &"relay":
            var role_plate := _find_named(role_samples[index], "ArmorPlate") as MeshInstance3D
            _expect(role_plate != null and _mesh_vertex_count(role_plate) >= 300, "The %s robot must retain a dense rounded front plate." % role_names[index])
        if role_names[index] == &"salvager":
            _expect(_find_named(role_samples[index], "ScrapperAuthoredModel") != null, "The salvager must use the authored Scrapper model shell.")
            _expect(_find_named(role_samples[index], "ProductionAssetMarker") != null, "The authored Scrapper model must expose its production asset marker.")
            _expect(_find_named(role_samples[index], "ScrapperHopperRim") != null and _find_named(role_samples[index], "ScrapperDismantlerCollarLeft") != null, "The authored Scrapper model must expose maintained hopper and tool-collar hardware.")
            _expect(_find_named(role_samples[index], "ScrapperMagnetCoilRight") != null and _find_named(role_samples[index], "ScrapperCuttingGuard") != null, "The authored Scrapper model must expose close-camera pickup and cutting hardware.")
        elif role_names[index] == &"scout":
            _expect(_find_named(role_samples[index], "PathfinderAuthoredModel") != null, "The scout must use the authored Pathfinder model shell.")
            _expect(_find_named(role_samples[index], "ProductionAssetMarker") != null, "The authored Pathfinder model must expose its production asset marker.")
            _expect(_find_named(role_samples[index], "PathfinderMastBraceLeft") != null and _find_named(role_samples[index], "PathfinderMastCollar") != null, "The authored Pathfinder model must expose braced mast hardware.")
            _expect(_find_named(role_samples[index], "PathfinderDishRibLeft") != null and _find_named(role_samples[index], "PathfinderSignalCanister") != null, "The authored Pathfinder model must expose dish-rib and signal-service hardware.")
        elif role_names[index] == &"engineer":
            _expect(_find_named(role_samples[index], "EngineerAuthoredModel") != null, "The engineer must use the authored Engineer model shell.")
            _expect(_find_named(role_samples[index], "ProductionAssetMarker") != null, "The authored Engineer model must expose its production asset marker.")
            _expect(_find_named(role_samples[index], "EngineerCradleLatch") != null and _find_named(role_samples[index], "EngineerForgeGuard") != null, "The authored Engineer model must expose maintained cradle and forge-guard hardware.")
            _expect(_find_named(role_samples[index], "EngineerToolCollarLeft") != null and _find_named(role_samples[index], "EngineerClampJawRight") != null, "The authored Engineer model must expose close-camera tool and clamp hardware.")
            _expect(_find_named(role_samples[index], "EngineerForgeStatusPanel") != null and _find_named(role_samples[index], "EngineerForgeStatusLens") != null, "The authored Engineer model must expose a readable forge status face.")
            var engineer_service_rib := _find_named(role_samples[index], "EngineerServiceRibLeft") as MeshInstance3D
            var engineer_service_hatch := _find_named(role_samples[index], "EngineerServiceHatchRight") as MeshInstance3D
            _expect(engineer_service_rib != null and engineer_service_hatch != null and _mesh_vertex_count(engineer_service_rib) >= 48 and _mesh_vertex_count(engineer_service_hatch) >= 48, "The Engineer must retain a layered front service bay with raised ribs and a split access hatch.")
            _expect(_find_named(role_samples[index], "EngineerServiceLatchLeft") != null, "The Engineer service bay must expose captive latch hardware rather than a flat decorative panel.")
        elif role_names[index] == &"relay":
            _expect(_find_named(role_samples[index], "RelayAuthoredModel") != null, "The Signal Relay must use the authored Relay model shell.")
            _expect(_find_named(role_samples[index], "ProductionAssetMarker") != null, "The authored Signal Relay model must expose its production asset marker.")
            _expect(_find_named(role_samples[index], "RelaySignalBeacon") != null and _find_named(role_samples[index], "RelayDirectionalDish") != null, "The Signal Relay must expose a distinct mast, dish and beacon silhouette.")
            var relay_dish := _find_named(role_samples[index], "RelayDirectionalDish") as MeshInstance3D
            _expect(relay_dish != null and _mesh_vertex_count(relay_dish) >= 200, "The Signal Relay directional dish must retain a dense parabolic bowl profile rather than a flat low-detail plate.")
            var relay_face := _find_named(role_samples[index], "RelayServiceFace") as MeshInstance3D
            var relay_heat_sink := _find_named(role_samples[index], "RelayHeatSink") as MeshInstance3D
            var relay_panel := _find_named(role_samples[index], "RelaySignalPanelLeft") as MeshInstance3D
            _expect(relay_face != null and _mesh_vertex_count(relay_face) >= 48 and relay_heat_sink != null and _mesh_vertex_count(relay_heat_sink) >= 48 and relay_panel != null and _mesh_vertex_count(relay_panel) >= 48, "Signal Relay service face, heat sink and signal panels must retain chamfered high-definition geometry.")
            var relay_animation := role_samples[index].get_node_or_null("AuthoredActorAnimation3D") as AuthoredActorAnimation3D
            _expect(relay_animation != null and relay_animation.animation_player != null, "The Signal Relay must route authored animation clips through a runtime presentation bridge.")
            if relay_animation != null and relay_animation.animation_player != null:
                for clip_name in [&"Idle", &"Walk", &"Work", &"Fire", &"Hit"]:
                    _expect(_animation_player_has_clip(relay_animation.animation_player, clip_name), "The authored Signal Relay must expose the %s animation clip." % clip_name)
                    _expect(_animation_player_track_count(relay_animation.animation_player, clip_name) >= 2, "The Signal Relay %s clip must carry primary and secondary authored motion channels." % clip_name)
                _expect(_animation_player_track_count(relay_animation.animation_player, &"Idle") >= 6, "Signal Relay Idle must carry mast-collar, heat-sink and service-face channels.")
                _expect(_animation_player_track_count(relay_animation.animation_player, &"Walk") >= 6, "Signal Relay Walk must carry mast-brace and mast articulation channels.")
                _expect(_animation_player_track_count(relay_animation.animation_player, &"Work") >= 5, "Signal Relay Work must carry dish-rim, hub and signal-cable channels.")
                _expect(_animation_player_track_count(relay_animation.animation_player, &"Fire") >= 4, "Signal Relay Fire must carry dish hub and rim response channels.")
                _expect(_animation_player_track_count(relay_animation.animation_player, &"Hit") >= 5, "Signal Relay Hit must carry service-face, mast-collar and dish-rim impact channels.")
                _expect(_animation_player_has_clip(relay_animation.animation_player, &"Retreat"), "The authored Signal Relay must expose a Retreat clip.")
                _expect(_animation_player_track_count(relay_animation.animation_player, &"Retreat") >= 5, "Signal Relay Retreat must carry mast-brace and collar withdrawal channels.")
                _expect(_animation_player_has_clip(relay_animation.animation_player, &"Death"), "The authored Signal Relay must expose a Death clip.")
                _expect(_animation_player_track_count(relay_animation.animation_player, &"Death") >= 4, "Signal Relay Death must carry dish and beacon-cap collapse channels.")
        if role_names[index] == &"guardian":
            _expect(_find_named(role_samples[index], "WardenTargetingFace") != null and _find_named(role_samples[index], "WardenRecoilCollarLeft") != null, "The Warden must expose its maintained targeting and recoil hardware.")
            _expect(_find_named(role_samples[index], "WardenThermalFinLeft") != null and _find_named(role_samples[index], "WardenOpticShroud") != null and _find_named(role_samples[index], "WardenBreechClamp") != null, "The Warden must expose its third-pass thermal, optic and breech hardware.")
            _expect(_find_named(role_samples[index], "WardenCounterweight") != null, "The Warden must retain a layered counterweight silhouette.")
        elif role_names[index] == &"salvager":
            _expect(_find_named(role_samples[index], "ScrapperHopperLatch") != null and _find_named(role_samples[index], "ScrapperCargoFastenerLeft") != null, "The Scrapper must expose its maintained hopper hardware.")
            _expect(_find_named(role_samples[index], "ScrapperHopperLip") != null and _find_named(role_samples[index], "ScrapperDrumLeft") != null and _find_named(role_samples[index], "ScrapperCuttingGuard") != null, "The Scrapper must expose its third-pass hopper, drum and cutting hardware.")
            _expect(_find_named(role_samples[index], "ScrapClaw") != null, "The Scrapper must retain layered dismantler claw hardware.")
            var scrapper_asset := SCRAPPER_ASSET_SCENE.instantiate()
            root.add_child(scrapper_asset)
            await process_frame
            var scrapper_chassis := _find_named(scrapper_asset, "Chassis") as MeshInstance3D
            var scrapper_cargo := _find_named(scrapper_asset, "CargoBin") as MeshInstance3D
            _expect(scrapper_chassis != null and scrapper_cargo != null and _mesh_vertex_count(scrapper_chassis) >= 600 and _mesh_vertex_count(scrapper_cargo) >= 48, "The authored Scrapper chassis and cargo bin must retain dense high-definition manufactured surfaces.")
            var scrapper_hopper_rail := _find_named(scrapper_asset, "ScrapperHopperSideRail") as MeshInstance3D
            var scrapper_intake_deck := _find_named(scrapper_asset, "ScrapperIntakeDeck") as MeshInstance3D
            _expect(scrapper_hopper_rail != null and scrapper_intake_deck != null and _mesh_vertex_count(scrapper_hopper_rail) >= 48 and _mesh_vertex_count(scrapper_intake_deck) >= 48, "The Scrapper must retain raised hopper rails and a readable intake deck for its salvage role silhouette.")
            var scrapper_animation := role_samples[index].get_node_or_null("AuthoredActorAnimation3D") as AuthoredActorAnimation3D
            if scrapper_animation != null and scrapper_animation.animation_player != null:
                _expect(_animation_player_track_count(scrapper_animation.animation_player, &"Idle") >= 6, "Scrapper Idle must carry hopper-latch and paired magnet-coil channels.")
                _expect(_animation_player_track_count(scrapper_animation.animation_player, &"Walk") >= 7, "Scrapper Walk must carry intake-tooth and magnet-coil locomotion channels.")
                _expect(_animation_player_track_count(scrapper_animation.animation_player, &"Work") >= 7, "Scrapper Work must carry dismantler, magnet and salvage-drum channels.")
                _expect(_animation_player_track_count(scrapper_animation.animation_player, &"Hit") >= 5, "Scrapper Hit must carry cutting-guard and paired collar impact channels.")
                _expect(_animation_player_track_count(scrapper_animation.animation_player, &"Retreat") >= 5, "Scrapper Retreat must carry magnet withdrawal and hopper response channels.")
                _expect(_animation_player_track_count(scrapper_animation.animation_player, &"Death") >= 4, "Scrapper Death must carry drum and hopper collapse channels.")
            scrapper_asset.queue_free()
        elif role_names[index] == &"scout":
            _expect(_find_named(role_samples[index], "PathfinderMastBraceLeft") != null and _find_named(role_samples[index], "PathfinderSurveyBeacon") != null, "The Pathfinder must expose its braced mast and survey beacon hardware.")
            _expect(_find_named(role_samples[index], "PathfinderMastCollar") != null and _find_named(role_samples[index], "PathfinderDishRibLeft") != null and _find_named(role_samples[index], "PathfinderSignalCanister") != null, "The Pathfinder must expose its third-pass mast, dish and signal hardware.")
            _expect(_find_named(role_samples[index], "PathfinderSensorWing") != null, "The Pathfinder must retain layered survey-wing hardware.")
            var pathfinder_asset := PATHFINDER_ASSET_SCENE.instantiate()
            root.add_child(pathfinder_asset)
            await process_frame
            var pathfinder_chassis := _find_named(pathfinder_asset, "Chassis") as MeshInstance3D
            var pathfinder_sensor_pod := _find_named(pathfinder_asset, "PathfinderSensorPod") as MeshInstance3D
            _expect(pathfinder_chassis != null and pathfinder_sensor_pod != null and _mesh_vertex_count(pathfinder_chassis) >= 600 and _mesh_vertex_count(pathfinder_sensor_pod) >= 48, "The authored Pathfinder chassis and sensor pod must retain dense high-definition manufactured surfaces.")
            var pathfinder_console := _find_named(pathfinder_asset, "PathfinderSurveyConsole") as MeshInstance3D
            var pathfinder_dish_rim := _find_named(pathfinder_asset, "PathfinderDishRim") as MeshInstance3D
            _expect(pathfinder_console != null and pathfinder_dish_rim != null and _mesh_vertex_count(pathfinder_console) >= 48 and _mesh_vertex_count(pathfinder_dish_rim) >= 64, "The Pathfinder must retain a maintained survey console and dense dish rim for its scout role silhouette.")
            var pathfinder_animation := role_samples[index].get_node_or_null("AuthoredActorAnimation3D") as AuthoredActorAnimation3D
            if pathfinder_animation != null and pathfinder_animation.animation_player != null:
                _expect(_animation_player_track_count(pathfinder_animation.animation_player, &"Idle") >= 6, "Pathfinder Idle must carry sensor-pod, mast-collar and signal-canister channels.")
                _expect(_animation_player_track_count(pathfinder_animation.animation_player, &"Walk") >= 6, "Pathfinder Walk must carry sensor-wing and mast-brace locomotion channels.")
                _expect(_animation_player_track_count(pathfinder_animation.animation_player, &"Survey") >= 6, "Pathfinder Survey must carry dish-rib and signal-service channels.")
                _expect(_animation_player_track_count(pathfinder_animation.animation_player, &"Hit") >= 5, "Pathfinder Hit must carry wing, mast-collar and dish-hub impact channels.")
                _expect(_animation_player_track_count(pathfinder_animation.animation_player, &"Retreat") >= 5, "Pathfinder Retreat must carry brace and sensor-pod withdrawal channels.")
                _expect(_animation_player_track_count(pathfinder_animation.animation_player, &"Death") >= 4, "Pathfinder Death must carry dish and survey-beacon collapse channels.")
            pathfinder_asset.queue_free()
        elif role_names[index] == &"engineer":
            _expect(_find_named(role_samples[index], "EngineerToolControl") != null and _find_named(role_samples[index], "EngineerForgeGuard") != null, "The Engineer must expose its tool-control and forge-guard hardware.")
            _expect(_find_named(role_samples[index], "EngineerCableSpool") != null and _find_named(role_samples[index], "EngineerWeldingShield") != null and _find_named(role_samples[index], "EngineerClampJaw") != null, "The Engineer must expose its third-pass cable, welding and clamp hardware.")
            _expect(_find_named(role_samples[index], "EngineerClamp") != null, "The Engineer must retain layered clamp hardware.")
            var engineer_asset := ENGINEER_ASSET_SCENE.instantiate()
            root.add_child(engineer_asset)
            await process_frame
            var engineer_chassis := _find_named(engineer_asset, "Chassis") as MeshInstance3D
            var engineer_cradle := _find_named(engineer_asset, "MaterialCradle") as MeshInstance3D
            _expect(engineer_chassis != null and engineer_cradle != null and _mesh_vertex_count(engineer_chassis) >= 600 and _mesh_vertex_count(engineer_cradle) >= 48, "The authored Engineer chassis and material cradle must retain dense high-definition manufactured surfaces.")
            var engineer_animation := role_samples[index].get_node_or_null("AuthoredActorAnimation3D") as AuthoredActorAnimation3D
            if engineer_animation != null and engineer_animation.animation_player != null:
                _expect(_animation_player_track_count(engineer_animation.animation_player, &"Idle") >= 7, "Engineer Idle must carry cradle-latch, forge-coil and paired spool channels.")
                _expect(_animation_player_track_count(engineer_animation.animation_player, &"Walk") >= 7, "Engineer Walk must carry tool-collar and paired spool locomotion channels.")
                _expect(_animation_player_track_count(engineer_animation.animation_player, &"Work") >= 7, "Engineer Work must carry welding-shield and paired clamp channels.")
                _expect(_animation_player_track_count(engineer_animation.animation_player, &"Hit") >= 5, "Engineer Hit must carry forge-guard and paired collar impact channels.")
                _expect(_animation_player_track_count(engineer_animation.animation_player, &"Retreat") >= 5, "Engineer Retreat must carry welding-shield and cradle withdrawal channels.")
                _expect(_animation_player_track_count(engineer_animation.animation_player, &"Death") >= 4, "Engineer Death must carry forge-coil and cradle collapse channels.")
            engineer_asset.queue_free()
        elif role_names[index] == &"relay":
            _expect(_find_named(role_samples[index], "RelayMastCollar") != null and _find_named(role_samples[index], "RelayDishRibLeft") != null and _find_named(role_samples[index], "RelaySignalFace") != null, "The Signal Relay must expose maintained mast, dish-rib and signal-face hardware.")
        role_samples[index].queue_free()

    var authored_warden := ROBOT_SCENE.instantiate() as RobotUnit3D
    authored_warden.configure(&"guardian", 1)
    authored_warden.position = Vector3(30.0, 0.0, 28.0)
    root.add_child(authored_warden)
    await process_frame
    _expect(_find_named(authored_warden, "WardenAuthoredModel") != null, "The guardian must use the authored Warden model shell.")
    _expect(_find_named(authored_warden, "ProductionAssetMarker") != null, "The authored Warden model must expose its production asset marker.")
    _expect(_find_named(authored_warden, "WardenTargetingFace") != null and _find_named(authored_warden, "WardenOpticShroud") != null, "The authored Warden model must expose maintained targeting and optic-shroud hardware.")
    var warden_targeting_bezel := _find_named(authored_warden, "WardenTargetingBezel") as MeshInstance3D
    _expect(warden_targeting_bezel != null and _mesh_vertex_count(warden_targeting_bezel) >= 48 and _find_named(authored_warden, "WardenTargetingApertureRight") != null, "The Warden must expose a dense targeting bezel and paired optic apertures for a readable guardian face.")
    _expect(_find_named(authored_warden, "WardenRecoilCollarLeft") != null and _find_named(authored_warden, "WardenThermalFinRight") != null and _find_named(authored_warden, "WardenBreechClamp") != null, "The authored Warden model must expose close-camera recoil, thermal and breech hardware.")
    var warden_shoulder_guard := _find_named(authored_warden, "WardenShoulderGuard") as MeshInstance3D
    var warden_weapon_rail := _find_named(authored_warden, "WardenWeaponRail") as MeshInstance3D
    _expect(warden_shoulder_guard != null and warden_weapon_rail != null and _mesh_vertex_count(warden_shoulder_guard) >= 48 and _mesh_vertex_count(warden_weapon_rail) >= 48, "The Warden must retain shoulder protection and weapon rails that distinguish its guardian role at tactical range.")
    _expect(_find_named(authored_warden, "RearShieldCore") != null and _find_named(authored_warden, "RearShieldCornerCap") != null, "The Warden must expose beveled rear protection hardware.")
    _expect(_find_named(authored_warden, "ShieldRibCore") != null and _find_named(authored_warden, "ShieldRibCornerCap") != null, "The Warden must expose a beveled protection-rib assembly.")
    var warden_chassis := _find_named(authored_warden, "Chassis") as MeshInstance3D
    var warden_breech := _find_named(authored_warden, "WardenBreech") as MeshInstance3D
    _expect(warden_chassis != null and warden_breech != null and _mesh_vertex_count(warden_chassis) >= 600 and _mesh_vertex_count(warden_breech) >= 48, "The authored Warden chassis and breech must retain dense high-definition manufactured surfaces.")
    var warden_animation := authored_warden.get_node_or_null("AuthoredActorAnimation3D") as AuthoredActorAnimation3D
    if warden_animation != null and warden_animation.animation_player != null:
        _expect(_animation_player_track_count(warden_animation.animation_player, &"Idle") >= 6, "Warden Idle must carry exchanger breathing and paired thermal-fin channels.")
        _expect(_animation_player_track_count(warden_animation.animation_player, &"Walk") >= 6, "Warden Walk must carry thermal-fin and counterweight locomotion channels.")
        _expect(_animation_player_track_count(warden_animation.animation_player, &"Fire") >= 6, "Warden Fire must carry breech, clamp and paired recoil-collar channels.")
        _expect(_animation_player_track_count(warden_animation.animation_player, &"Hit") >= 5, "Warden Hit must carry targeting-face and thermal-fin impact channels.")
        _expect(_animation_player_track_count(warden_animation.animation_player, &"Retreat") >= 5, "Warden Retreat must carry thermal-fin and rear-shield withdrawal channels.")
        _expect(_animation_player_track_count(warden_animation.animation_player, &"Death") >= 4, "Warden Death must carry exchanger and thermal-fin collapse channels.")
    authored_warden.queue_free()

    var disabled_robot := ROBOT_SCENE.instantiate() as RobotUnit3D
    disabled_robot.configure(&"guardian", 2)
    disabled_robot.position = Vector3(34.0, 0.0, 28.0)
    root.add_child(disabled_robot)
    await process_frame
    disabled_robot.apply_damage(disabled_robot.maximum_health * 2.0)
    _expect(not disabled_robot.is_alive(), "A lethal robot hit must enter the disabled state before cleanup.")
    _expect(disabled_robot.disabled_presentation_remaining > 0.0, "Disabled robots must retain a bounded presentation window before cleanup.")
    _expect(_find_named(disabled_robot, "RobotDisabledPresentation") != null and bool(_find_named(disabled_robot, "RobotDisabledPresentation").visible), "Disabled robots must expose a visible fractured failure assembly.")
    _expect(_find_named(disabled_robot, "RobotDisabledCarapace") != null and _find_named(disabled_robot, "RobotDisabledRootCollar") != null, "Disabled robots must expose collapsed shell and service-root anatomy.")
    _expect(_find_named(disabled_robot, "RobotDisabledSignal") != null and _find_named(disabled_robot, "RobotDisabledShard00") != null, "Disabled robots must expose a spent signal core and bounded shell fragments.")
    disabled_robot.disabled_presentation_remaining = 0.0
    disabled_robot._refresh_disabled_presentation()
    _expect(not bool(_find_named(disabled_robot, "RobotDisabledPresentation").visible), "Expired disabled presentation must hide before the robot is freed.")
    disabled_robot.queue_free()

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
        _expect(_find_named(sample, "OutpostAuthoredModel") != null, "Outposts must use the authored shelter model shell.")
        _expect(_find_named(sample, "ProductionAssetMarker") != null, "The authored outpost shelter must expose its production asset marker.")
        _expect(_find_named(sample, "ShelterWindowFrame00") != null and _find_named(sample, "ShelterWindowMullion00") != null, "The authored outpost shelter must expose layered window-frame and mullion hardware.")
        _expect(_find_named(sample, "ShelterServiceDoor") != null and _find_named(sample, "RoofServiceRib01") != null and _find_named(sample, "FoundationAnchor00") != null, "The authored outpost shelter must expose service-door, roof-rib and foundation-anchor detail.")
        _expect(_find_named(sample, "OutpostDamagePresentation") != null and _find_named(sample, "OutpostDamageScar00") != null and _find_named(sample, "OutpostDamageLeak00") != null, "Outposts must expose bounded integrity damage-memory presentation sockets.")
        _expect(_find_named(sample, "CoreShelterCore") != null and _find_named(sample, "CoreVent") != null, "Outposts must use the high-definition shelter and service-surface treatment.")
        _expect(_find_named(sample, "OutpostServiceSpine") != null and _find_named(sample, "ServiceSpineHousing") != null and _find_named(sample, "ServiceSpinePanel") != null, "Tiered outposts must expose a coherent high-definition service spine behind their role hardware.")
        _expect(_find_named(sample, "OutpostLoadPylonLF") != null and _find_named(sample, "OutpostLoadPylonRB") != null and _find_named(sample, "OutpostLoadPylonCollar3LF") != null, "Tiered outposts must expose continuous load pylons and tier collars so stacked frames read as one grounded machine structure.")
        _expect(_find_named(sample, "ServiceSpineLouver") != null and _find_named(sample, "ServiceSpineRoleBadge") != null and _find_named(sample, "ServiceSpineBeacon") != null, "Tiered outposts must expose bounded service ventilation, role identity and status hardware.")
        var shell_core := _find_named(sample, "CoreShelterCore") as MeshInstance3D
        var shell_vertices := PackedVector3Array()
        if shell_core != null and shell_core.mesh is ArrayMesh:
            var shell_arrays := (shell_core.mesh as ArrayMesh).surface_get_arrays(0)
            if shell_arrays.size() > Mesh.ARRAY_VERTEX:
                shell_vertices = shell_arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
        _expect(shell_vertices.size() > 24, "The authored outpost shelter core must use chamfered high-definition geometry rather than a flat six-face box.")
        _expect(_find_named(sample, "TierFrame1") != null and _find_named(sample, "TierFrame2") != null and _find_named(sample, "TierFrame3") != null, "Tier 3 outposts must expose three stable structural frames.")
        _expect(_find_named(sample, "TierFrame1Deck") != null and _find_named(sample, "TierFrame3Deck") != null and _find_named(sample, "TierFrame2DeckInset") != null, "Tier 3 outposts must expose recessed structural decks rather than empty repeated frames.")
        _expect(_find_named(sample, "TierFrame1ServiceRimNorth") != null and _find_named(sample, "TierFrame3ServiceRimEast") != null, "Tier 3 outposts must expose nested service rims that turn open decks into maintained machine surfaces.")
        _expect(_find_named(sample, "TierFrame1RolePlate") != null and _find_named(sample, "TierFrame2RolePlate") != null and _find_named(sample, "TierFrame3RolePlate") != null, "Tier 3 outposts must expose role-coded articulation plates on every structural frame.")
        _expect(_find_named(sample, "TierFrame1RoleNode") != null and _find_named(sample, "TierFrame3RoleNode") != null and _find_named(sample, "TierFrame3RoleBraceLeft") != null, "Tier 3 outposts must expose bounded role signal nodes and frame braces.")
        _expect(_outpost_model_has_details(sample, outpost_roles[index]), "The %s outpost must expose a role-readable high-detail silhouette." % outpost_roles[index])
        _expect(not bool(_find_named(sample, "OutpostDamagePresentation").visible), "Healthy outposts must keep damage-memory presentation hidden.")
        _expect(sample.presentation_status == &"idle" and is_zero_approx(sample.presentation_activity), "Healthy outposts must begin with a quiet presentation state.")
        sample._set_presentation_activity(StringName(outpost_roles[index]), 1.0, 0.6)
        _expect(sample.presentation_status == StringName(outpost_roles[index]) and sample.presentation_activity > 0.9, "Outpost presentation activity must expose the autonomous role action without changing simulation state.")
        sample._process(0.5)
        _expect(sample.presentation_activity < 1.0 and sample.presentation_activity > 0.0, "Outpost presentation activity must decay after a bounded work pulse.")
        sample.apply_damage(sample.maximum_health * 0.68)
        _expect(bool(_find_named(sample, "OutpostDamagePresentation").visible) and bool(_find_named(sample, "OutpostDamageLeak00").visible), "Damaged outposts must reveal scar and leak presentation at meaningful integrity loss.")
        sample.repair(sample.maximum_health)
        _expect(not bool(_find_named(sample, "OutpostDamagePresentation").visible), "Repair must clear outpost damage-memory presentation when integrity is restored.")
        sample.apply_damage(sample.maximum_health)
        _expect(_find_named(sample, "DestroyedFoundationCore") != null and _find_named(sample, "DestroyedFoundationInsetCore") != null and _find_named(sample, "RubbleRebar00") != null and _find_named(sample, "DestroyedServiceRailCore") != null, "Destroyed outposts must expose a fractured high-definition foundation, reinforcement and service-rail failure read.")
        sample.rebuild()
        _expect(_find_named(sample, "OutpostAuthoredModel") != null and _find_named(sample, "TierFrame3RolePlate") != null and sample.is_alive(), "Rebuilding an outpost must restore the authored shelter, tier articulation and alive state.")
        sample.queue_free()

    var enemy_samples: Array[OrganicEnemy3D] = []
    var species_names := [&"skitterling", &"razorhound", &"roofleaper", &"glassmoth", &"veilstalker", &"burrower", &"sporecaster", &"broodmass", &"miremaw", &"carrionbell", &"rootweaver", &"thornback", &"ashmantle", &"apex"]
    var sample_player := get_first_node_in_group("player_character") as Node3D
    var sample_forge := world.get_node_or_null("Heartforge") as Node3D
    for index in species_names.size():
        var sample := ENEMY_SCENE.instantiate() as OrganicEnemy3D
        sample.configure(species_names[index], sample_player, sample_forge)
        sample.position = Vector3(20.0 + float(index) * 2.4, 0.0, 18.0)
        root.add_child(sample)
        var authored_animation := AuthoredActorAnimation3D.new()
        authored_animation.name = "AuthoredActorAnimation3D"
        authored_animation.configure(sample)
        sample.add_child(authored_animation)
        enemy_samples.append(sample)
    await process_frame
    for index in enemy_samples.size():
        _expect(_enemy_model_has_details(enemy_samples[index], species_names[index]), "The %s organic family must expose a role-readable silhouette." % species_names[index])
        var organic_model := enemy_samples[index].get_node_or_null("OrganicModel") as Node
        _expect(organic_model != null and organic_model.has_meta(&"ironwright_organic_family") and String(organic_model.get_meta(&"ironwright_organic_family")) == String(species_names[index]), "The %s organic presentation must retain species metadata for release palette application." % species_names[index])
        _expect(_find_named(enemy_samples[index], "OrganicDorsalPlate") != null, "The %s organic family must expose a layered shell material break." % species_names[index])
        _expect(_find_named(enemy_samples[index], "TorsoCore") != null and _find_named(enemy_samples[index], "TorsoSegment0") != null, "The %s organic family must expose segmented high-definition torso anatomy." % species_names[index])
        if species_names[index] in [&"roofleaper", &"glassmoth", &"miremaw", &"carrionbell", &"rootweaver", &"thornback", &"ashmantle"]:
            _expect(_find_named(enemy_samples[index], "OrganicFamilyAnatomyFinish") != null and _find_named(enemy_samples[index], "OrganicPulseRim") != null and _find_named(enemy_samples[index], "OrganicGrowthPlate") != null, "The %s authored family must expose a bounded living anatomy finish rather than a static shell." % species_names[index])
            var dorsal_plate := _find_named(enemy_samples[index], "OrganicDorsalPlate") as Node3D
            var dorsal_mesh := _find_first_mesh(dorsal_plate)
            _expect(dorsal_mesh != null and _mesh_vertex_count(dorsal_mesh) >= 48, "The %s authored dorsal plate must retain the beveled close-camera edge treatment." % species_names[index])
            var convex_sheet_name := &"RoofleaperWingL"
            match species_names[index]:
                &"glassmoth": convex_sheet_name = &"GlassmothWingL0"
                &"miremaw": convex_sheet_name = &"MiremawWaterFinL"
                &"carrionbell": convex_sheet_name = &"CarrionbellCrownPlate"
                &"rootweaver": convex_sheet_name = &"RootweaverSporeFan"
                &"thornback": convex_sheet_name = &"ThornbackCrownPlate"
                &"ashmantle": convex_sheet_name = &"AshmantleHeatLouverL"
            var convex_sheet := _find_first_mesh(_find_named(enemy_samples[index], convex_sheet_name) as Node3D)
            _expect(convex_sheet != null and _mesh_vertex_count(convex_sheet) >= 200, "The %s shared anatomy sheet must retain dense convex close-camera geometry." % species_names[index])
            var focal_anatomy_name := &"RoofleaperCentralOculus"
            match species_names[index]:
                &"glassmoth": focal_anatomy_name = &"GlassmothLensCollar"
                &"miremaw": focal_anatomy_name = &"MiremawMawGuard"
                &"carrionbell": focal_anatomy_name = &"CarrionbellThroatCollar"
                &"rootweaver": focal_anatomy_name = &"RootweaverRouteMask"
                &"thornback": focal_anatomy_name = &"ThornbackFaceShield"
                &"ashmantle": focal_anatomy_name = &"AshmantleThermalCollar"
            var focal_anatomy := _find_named(enemy_samples[index], focal_anatomy_name) as Node3D
            _expect(focal_anatomy != null and _find_first_mesh(focal_anatomy) != null, "The %s late-family focal organ must remain present as readable presentation anatomy." % species_names[index])
            if species_names[index] == &"thornback":
                var thornback_crown_depth := convex_sheet.mesh.get_aabb().size.y if convex_sheet != null and convex_sheet.mesh != null else 0.0
                _expect(thornback_crown_depth >= 0.30, "The Thornback crown shield must retain folded living depth rather than collapsing into a thin plate.")
            if species_names[index] == &"ashmantle":
                var ash_louver_depth := convex_sheet.mesh.get_aabb().size.y if convex_sheet != null and convex_sheet.mesh != null else 0.0
                _expect(ash_louver_depth >= 0.24, "The Ashmantle heat louver must retain folded living depth rather than collapsing into a thin thermal bar.")
                var ash_rib := _find_first_mesh(_find_named(enemy_samples[index], "AshmantleMantleRib0") as Node3D)
                _expect(ash_rib != null and _mesh_vertex_count(ash_rib) >= 500, "The Ashmantle mantle ribs must retain dense folded organic geometry around the thermal shell.")
            if species_names[index] == &"carrionbell":
                var carrionbell_crown_depth := convex_sheet.mesh.get_aabb().size.y if convex_sheet != null and convex_sheet.mesh != null else 0.0
                _expect(carrionbell_crown_depth >= 0.28, "The Carrion Bell crown must retain folded living depth above the resonator rather than collapsing into a thin signal bar.")
            if species_names[index] == &"rootweaver":
                var rootweaver_crown_depth := convex_sheet.mesh.get_aabb().size.y if convex_sheet != null and convex_sheet.mesh != null else 0.0
                _expect(rootweaver_crown_depth >= 0.24, "The Rootweaver crown plates must retain folded living depth around the route oculi rather than collapsing into thin service bars.")
            if species_names[index] in [&"roofleaper", &"glassmoth", &"miremaw", &"rootweaver"]:
                _expect(convex_sheet != null and _mesh_vertex_count(convex_sheet) >= 600, "The %s living membrane must retain the dense tapered-lobe geometry used for the late-family silhouette pass." % species_names[index])
            if species_names[index] in [&"miremaw", &"rootweaver"]:
                var lobe_depth := convex_sheet.mesh.get_aabb().size.y if convex_sheet != null and convex_sheet.mesh != null else 0.0
                _expect(lobe_depth >= 0.70, "The %s living membrane must retain measurable folded depth rather than collapsing back to a thin plate." % species_names[index])
        if species_names[index] == &"sporecaster":
            var spore_gill_fan := _find_named(enemy_samples[index], "SporecasterGillFan0") as Node3D
            _expect(spore_gill_fan != null and spore_gill_fan.scale.z >= 0.45, "The Sporecaster gill fan must retain presentation depth rather than collapsing into a flat horizontal membrane.")
        _expect(_find_named(enemy_samples[index], "OrganicDeathPresentation") != null, "The %s organic family must expose a dedicated high-definition death presentation root." % species_names[index])
        _expect(_find_named(enemy_samples[index], "OrganicDeathCarapace") != null and _find_named(enemy_samples[index], "OrganicDeathRootCollar") != null, "The %s death presentation must expose fractured shell and exposed root anatomy." % species_names[index])
        _expect(_find_named(enemy_samples[index], "OrganicDeathShard00") != null and _find_named(enemy_samples[index], "OrganicDeathVein00") != null and _find_named(enemy_samples[index], "OrganicDeathSignal") != null, "The %s death presentation must expose shell shards, dead vascular channels and a spent signal core." % species_names[index])
        var tiered_sample := enemy_samples[index] as OrganicEnemyTiered3D
        _expect(tiered_sample != null and _find_named(enemy_samples[index], "TierHighDefinitionDetail") != null, "The %s must expose the shared high-definition tier anatomy layer." % species_names[index])
        if tiered_sample != null:
            _expect(_find_named(enemy_samples[index], "TierDorsalPlate00") != null and _find_named(enemy_samples[index], "TierVascularChannelL00") != null and _find_named(enemy_samples[index], "TierVascularChannelR00") != null, "The %s must expose paired tier dorsal and vascular anatomy." % species_names[index])
            _expect(_find_named(enemy_samples[index], "TierCrownRing") != null and _find_named(enemy_samples[index], "TierCrownNode00") != null, "The %s must expose the stable tier crown ring presentation socket." % species_names[index])
            var tier_animator := enemy_samples[index].get_node_or_null("ProceduralAnimator3D") as ProceduralAnimator3D
            var tier_channel := _find_named(enemy_samples[index], "TierVascularChannelL00") as Node3D
            if tier_animator != null and tier_channel != null:
                var tier_before := tier_channel.transform
                tier_animator.idle_phase = 0.73
                tier_animator._restore_base_transforms()
                tier_animator._animate_organic(0.0)
                _expect(tier_channel.transform != tier_before, "%s tier vascular channels must carry a visible living pulse." % species_names[index])
        if species_names[index] == &"razorhound":
            _expect(_find_named(enemy_samples[index], "RazorhoundAuthoredModel") != null and _find_named(enemy_samples[index], "ProductionAssetMarker") != null, "The Razorhound must expose its authored production asset contract.")
        if species_names[index] in [&"skitterling", &"roofleaper", &"glassmoth", &"miremaw", &"carrionbell", &"rootweaver", &"thornback", &"ashmantle"]:
            var authored_marker_name := "%sAuthoredModel" % String(species_names[index]).capitalize()
            _expect(_find_named(enemy_samples[index], authored_marker_name) != null and _find_named(enemy_samples[index], "ProductionAssetMarker") != null, "The %s must expose its authored production asset contract." % species_names[index])
        if species_names[index] == &"veilstalker":
            _expect(_find_named(enemy_samples[index], "VeilstalkerCowlPlateL") != null and _find_named(enemy_samples[index], "VeilstalkerCowlPlateR") != null, "The Veilstalker must expose paired layered cowl brow plates for readable sensory anatomy.")
        match species_names[index]:
            &"skitterling":
                _expect(_find_named(enemy_samples[index], "SkitterlingCarapaceCap0") != null and _find_named(enemy_samples[index], "SkitterlingMandiblePlateL") != null, "The Skitterling must expose shell caps and mandible plates for close-camera readability.")
            &"burrower":
                _expect(_find_named(enemy_samples[index], "BurrowerDrillFlute0") != null and _find_named(enemy_samples[index], "BurrowerLampGuardL") != null, "The Burrower must expose drill flutes and protected bore lamps.")
                _expect(_find_named(enemy_samples[index], "BurrowerDrillCutter0") != null, "The Burrower must expose a readable four-tooth drill cutting crown.")
            &"sporecaster":
                _expect(_find_named(enemy_samples[index], "SporecasterGillRib0") != null and _find_named(enemy_samples[index], "SporecasterSacCap0") != null, "The Sporecaster must expose layered gill ribs and capped spore sacs.")
                _expect(_find_named(enemy_samples[index], "SporecasterSacRim0") != null and _find_named(enemy_samples[index], "SporecasterSacPore0") != null, "The Sporecaster must expose layered sac rims and visible pore apertures for ranged-infestation readability.")
            &"broodmass":
                _expect(_find_named(enemy_samples[index], "BroodmassLobeRidgeL") != null and _find_named(enemy_samples[index], "BroodmassMawRidge") != null and _find_named(enemy_samples[index], "BroodmassMawLower") != null and _find_named(enemy_samples[index], "CrownFastener0") != null, "The Broodmass must expose layered lobe, maw and crown hardware.")
            &"roofleaper":
                _expect(_find_named(enemy_samples[index], "RoofleaperFineVeinL") != null and _find_named(enemy_samples[index], "RoofleaperFineVeinR") != null, "The Roofleaper must expose fine vascular wing detail on both membranes.")
                _expect(_find_named(enemy_samples[index], "RoofleaperWingFrameL") != null and _find_named(enemy_samples[index], "RoofleaperWingFastenerR") != null, "The Roofleaper must expose structural wing spars and socket fasteners.")
                var roofleaper_wing_l := _find_named(enemy_samples[index], "RoofleaperWingL") as Node3D
                var roofleaper_wing_r := _find_named(enemy_samples[index], "RoofleaperWingR") as Node3D
                _expect(roofleaper_wing_l != null and roofleaper_wing_r != null and absf(roofleaper_wing_l.basis.y.z) >= 0.10 and absf(roofleaper_wing_r.basis.y.z) >= 0.10 and roofleaper_wing_l.basis.y.z * roofleaper_wing_r.basis.y.z < 0.0, "The Roofleaper wing pair must carry opposing pitch so its ambush membranes read as a lifted V-shaped silhouette rather than coplanar discs.")
            &"glassmoth":
                _expect(_find_named(enemy_samples[index], "GlassmothFineVeinL0") != null and _find_named(enemy_samples[index], "GlassmothFineVeinR0") != null, "The Glassmoth must expose fine luminous wing-vein detail on both wing pairs.")
                _expect(_find_named(enemy_samples[index], "GlassmothWingFrameL0") != null and _find_named(enemy_samples[index], "GlassmothWingFastenerR1") != null, "The Glassmoth must expose structural spars and socket fasteners on its luminous wings.")
                var glassmoth_wing_l := _find_named(enemy_samples[index], "GlassmothWingL0") as Node3D
                var glassmoth_wing_r := _find_named(enemy_samples[index], "GlassmothWingR0") as Node3D
                _expect(glassmoth_wing_l != null and glassmoth_wing_r != null and absf(glassmoth_wing_l.basis.y.z) >= 0.12 and absf(glassmoth_wing_r.basis.y.z) >= 0.12 and glassmoth_wing_l.basis.y.z * glassmoth_wing_r.basis.y.z < 0.0, "The Glassmoth wing pair must carry opposing pitch so its luminous membranes read as a living V-shaped silhouette rather than coplanar discs.")
            &"miremaw":
                _expect(_find_named(enemy_samples[index], "MiremawGillRidgeL") != null and _find_named(enemy_samples[index], "MiremawGillRidgeR") != null, "The Miremaw must expose layered gill-ridge surface detail.")
                _expect(_find_named(enemy_samples[index], "MiremawJawPlateL") != null and _find_named(enemy_samples[index], "MiremawJawLower") != null and _find_named(enemy_samples[index], "MiremawGillSpineR") != null, "The Miremaw must expose a layered articulated jaw and gill spines for readable amphibious anatomy.")
                _expect(_find_named(enemy_samples[index], "MiremawGillCollarL") != null and _find_named(enemy_samples[index], "MiremawGillCollarR") != null, "The Miremaw must expose paired folded gill collars so its breathing anatomy reads in layered profile.")
                _expect(_find_named(enemy_samples[index], "MiremawJawHingeL") != null and _find_named(enemy_samples[index], "MiremawJawHingeR") != null, "The Miremaw must expose paired jaw hinges so the amphibious maw reads as articulated anatomy.")
                var miremaw_fin_l := _find_named(enemy_samples[index], "MiremawWaterFinL") as Node3D
                var miremaw_fin_r := _find_named(enemy_samples[index], "MiremawWaterFinR") as Node3D
                _expect(miremaw_fin_l != null and miremaw_fin_r != null and absf(miremaw_fin_l.basis.y.z) >= 0.14 and absf(miremaw_fin_r.basis.y.z) >= 0.14 and miremaw_fin_l.basis.y.z * miremaw_fin_r.basis.y.z < 0.0, "The Miremaw water-fin pair must carry opposing pitch so its amphibious membranes read as lifted fins rather than horizontal discs.")
            &"carrionbell":
                _expect(_find_named(enemy_samples[index], "CarrionbellResonatorRing") != null, "The Carrion Bell must expose a raised resonator lip for its signal anatomy.")
                _expect(_find_named(enemy_samples[index], "CarrionbellResonatorCore") != null and _find_named(enemy_samples[index], "CarrionbellBellRib0") != null, "The Carrion Bell must expose a layered resonator core and bell ribs.")
                var resonator_ring_mesh := _find_first_mesh(_find_named(enemy_samples[index], "CarrionbellResonatorRing") as Node3D)
                _expect(resonator_ring_mesh != null and _mesh_vertex_count(resonator_ring_mesh) >= 240, "The Carrion Bell resonator must use a dense curved ring mesh rather than a flat cylinder lip.")
                var resonator_bell_lip := _find_named(enemy_samples[index], "CarrionbellResonatorBellLip") as MeshInstance3D
                var resonator_clapper := _find_named(enemy_samples[index], "CarrionbellResonatorClapper") as MeshInstance3D
                var resonator_clapper_tip := _find_named(enemy_samples[index], "CarrionbellResonatorClapperTip") as MeshInstance3D
                _expect(resonator_bell_lip != null and _mesh_vertex_count(resonator_bell_lip) >= 500 and resonator_bell_lip.mesh.get_aabb().size.y >= 0.16, "The Carrion Bell resonator must retain a dense closed bell lip with readable depth.")
                _expect(resonator_clapper != null and resonator_clapper_tip != null and resonator_clapper.get_parent().name == "CarrionbellResonator" and resonator_clapper_tip.get_parent().name == "CarrionbellResonator", "The Carrion Bell clapper assembly must stay parented to the animated resonator socket.")
            &"rootweaver":
                _expect(_find_named(enemy_samples[index], "RootweaverKnuckleL") != null and _find_named(enemy_samples[index], "RootweaverKnuckleR") != null, "The Rootweaver must expose joint detail where its route arms meet the body.")
                _expect(_find_named(enemy_samples[index], "RootweaverCrownPlate0") != null and _find_named(enemy_samples[index], "RootweaverRootSpineR") != null, "The Rootweaver must expose crown plating and layered route spines.")
                _expect(_find_named(enemy_samples[index], "RootweaverJawPlateL") != null and _find_named(enemy_samples[index], "RootweaverJawPlateR") != null, "The Rootweaver must expose paired folded jaw plates beneath its route-controller oculi.")
                var rootweaver_fan := _find_named(enemy_samples[index], "RootweaverSporeFan") as Node3D
                _expect(rootweaver_fan != null and absf(rootweaver_fan.basis.y.z) >= 0.18, "The Rootweaver spore fan must carry a raised authored cant so its route-control membrane reads as an elevated fan rather than a horizontal disc.")
            &"thornback":
                _expect(_find_named(enemy_samples[index], "ThornbackSpineL") != null and _find_named(enemy_samples[index], "ThornbackSpineR") != null, "The Thornback must expose paired dorsal spines for its territorial silhouette.")
                _expect(_find_named(enemy_samples[index], "ThornbackJawPlateL") != null and _find_named(enemy_samples[index], "ThornbackCrown") != null, "The Thornback must expose layered jaw and crown hardware.")
                var thornback_barb := _find_named(enemy_samples[index], "ThornbackBarb0") as MeshInstance3D
                _expect(thornback_barb != null and _mesh_vertex_count(thornback_barb) >= 96 and _find_named(enemy_samples[index], "ThornbackBarb2") != null, "The Thornback must expose a dense three-barb dorsal threat edge rather than a flat ridge-only back.")
                var thornback_tooth_l := _find_named(enemy_samples[index], "ThornbackJawToothL0") as MeshInstance3D
                var thornback_tooth_r := _find_named(enemy_samples[index], "ThornbackJawToothR1") as MeshInstance3D
                _expect(thornback_tooth_l != null and thornback_tooth_r != null and _mesh_vertex_count(thornback_tooth_l) >= 96 and thornback_tooth_l.get_parent().name == "ThornbackJawPlateL" and thornback_tooth_r.get_parent().name == "ThornbackJawPlateR", "The Thornback jaw plates must carry a dense paired tooth edge under their existing animated sockets.")
            &"ashmantle":
                _expect(_find_named(enemy_samples[index], "AshmantleHeatLouverL") != null and _find_named(enemy_samples[index], "AshmantleHeatLouverR") != null, "The Ashmantle must expose paired heat-louver anatomy.")
                _expect(_find_named(enemy_samples[index], "AshmantleSiphon") != null and _find_named(enemy_samples[index], "AshmantleTendrilR") != null, "The Ashmantle must expose a route siphon and sensory tendril signature.")
                var ash_siphon_ring := _find_named(enemy_samples[index], "AshmantleSiphonRing") as MeshInstance3D
                _expect(ash_siphon_ring != null and _mesh_vertex_count(ash_siphon_ring) >= 96 and _find_named(enemy_samples[index], "AshmantleSiphonApertureR") != null, "The Ashmantle must expose a dense thermal siphon collar and paired hot apertures rather than a soft front mass alone.")
        if species_names[index] == &"apex":
            var apex_crown := _find_named(enemy_samples[index], "ApexCrown") as Node3D
            var apex_plate := _find_named(enemy_samples[index], "ApexCrownPlate") as Node3D
            _expect(apex_crown != null and apex_plate != null and apex_plate.position.distance_to(Vector3(0.0, 0.3, 0.16)) < 0.01, "Cistern Apex crown plating must remain attached through a local authored socket.")
            _expect(_find_named(enemy_samples[index], "ApexCrownRidgeL") != null and _find_named(enemy_samples[index], "ApexCrownFastenerR") != null, "Cistern Apex crown must expose paired ridge and socket hardware for close-camera readability.")
            var apex_jaw_latch := _find_named(enemy_samples[index], "ApexJawLatchR") as Node3D
            var apex_membrane_rib := _find_named(enemy_samples[index], "ApexMembraneRibL0") as Node3D
            var apex_jaw_tooth := _find_named(enemy_samples[index], "ApexJawToothL0") as MeshInstance3D
            _expect(apex_jaw_latch != null and apex_membrane_rib != null and apex_jaw_tooth != null, "Cistern Apex jaw, tooth and membrane assemblies must expose stable authored detail sockets.")
            var apex_crown_plate := _find_named(enemy_samples[index], "ApexCrownPlate") as MeshInstance3D
            var apex_jaw_latch_mesh := apex_jaw_latch as MeshInstance3D
            _expect(apex_crown_plate != null and _mesh_vertex_count(apex_crown_plate) >= 48 and apex_jaw_latch_mesh != null and _mesh_vertex_count(apex_jaw_latch_mesh) >= 48 and _mesh_vertex_count(apex_jaw_tooth) >= 48, "Cistern Apex crown plate, jaw latch and tooth edge must retain chamfered high-definition attack hardware.")
        if species_names[index] == &"broodmass":
            var brood_maw := _find_named(enemy_samples[index], "BroodmassMaw") as Node3D
            var brood_plate := _find_named(enemy_samples[index], "BroodmassMawPlate") as Node3D
            var brood_lower := _find_named(enemy_samples[index], "BroodmassMawLower") as Node3D
            var brood_hook := _find_named(enemy_samples[index], "BroodmassMawHookL") as Node3D
            var brood_crown_cap := _find_named(enemy_samples[index], "BroodmassCrownCap") as Node3D
            var brood_crown_plate := _find_named(enemy_samples[index], "BroodmassCrownCapPlate") as Node3D
            _expect(brood_maw != null and brood_plate != null and brood_lower != null and brood_lower.get_parent() == brood_maw and brood_plate.position.distance_to(Vector3(0.0, 0.24, -0.02)) < 0.01 and brood_hook != null and brood_hook.position.distance_to(Vector3(-0.34, -0.42, -0.24)) < 0.01, "Broodmass maw hardware must remain attached through local authored sockets.")
            _expect(brood_crown_cap != null and brood_crown_plate != null and brood_crown_plate.position.distance_to(Vector3(0.0, 0.16, 0.02)) < 0.01, "Broodmass crown cap must retain its local plate socket for a unified late-family silhouette.")
        if species_names[index] == &"sporecaster":
            var spore_cowl := _find_named(enemy_samples[index], "SporecasterCowl") as Node3D
            var spore_oculus := _find_named(enemy_samples[index], "SporecasterOculusL") as Node3D
            var spore_plate := _find_named(enemy_samples[index], "SporecasterCowlPlateL") as Node3D
            _expect(spore_cowl != null and spore_oculus != null and spore_plate != null and spore_oculus.position.distance_to(Vector3(-0.23, 0.16, -0.39)) < 0.01 and spore_plate.position.distance_to(Vector3(-0.32, 0.08, -0.09)) < 0.01, "Sporecaster sensory-cowl details must remain attached through local authored sockets.")
        var authored_animation := enemy_samples[index].get_node_or_null("AuthoredActorAnimation3D") as AuthoredActorAnimation3D
        _expect(authored_animation != null and authored_animation.animation_player != null, "%s must expose its imported authored animation bridge." % species_names[index])
        if authored_animation != null and authored_animation.animation_player != null:
            for clip_name in [&"Idle", &"Walk", &"Attack", &"Hit", &"Feed", &"Nest", &"Retreat", &"Death"]:
                _expect(_animation_player_has_clip(authored_animation.animation_player, clip_name), "%s must import the authored %s clip." % [species_names[index], clip_name])
                _expect(_animation_player_track_count(authored_animation.animation_player, clip_name) >= 2, "%s authored %s clip must carry multiple readable channels." % [species_names[index], clip_name])
            if species_names[index] == &"veilstalker":
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Idle") >= 4, "Veilstalker Idle must carry mandible breathing channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Attack") >= 6, "Veilstalker Attack must carry mandible and cowl-spine threat channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Feed") >= 4, "Veilstalker Feed must carry mandible motion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Retreat") >= 4, "Veilstalker Retreat must carry cowl-spine response channels.")
            if species_names[index] == &"skitterling":
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Idle") >= 6, "Skitterling Idle must carry antenna and sensory-fan breathing channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Walk") >= 6, "Skitterling Walk must carry paired-leg and sensory-rib locomotion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Attack") >= 6, "Skitterling Attack must carry paired mandible, plate and sensory-fan threat channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Hit") >= 5, "Skitterling Hit must carry antenna and carapace impact channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Feed") >= 5, "Skitterling Feed must carry paired mandible and sensory-fan motion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Nest") >= 5, "Skitterling Nest must carry carapace, fan and antenna-joint motion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Retreat") >= 5, "Skitterling Retreat must carry paired-leg and antenna withdrawal channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Death") >= 4, "Skitterling Death must carry carapace and antenna collapse channels.")
            if species_names[index] == &"razorhound":
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Idle") >= 6, "Razorhound Idle must carry ear, tail and dorsal-spine breathing channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Walk") >= 6, "Razorhound Walk must carry tail, spine, cheek and fang locomotion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Attack") >= 6, "Razorhound Attack must carry cheek, fang, ear and tail threat channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Hit") >= 5, "Razorhound Hit must carry ear, cheek and tail impact channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Feed") >= 5, "Razorhound Feed must carry snout, fang and ear motion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Nest") >= 5, "Razorhound Nest must carry tail, ear and dorsal-spine watch channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Retreat") >= 5, "Razorhound Retreat must carry tail, ear and cheek withdrawal channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Death") >= 4, "Razorhound Death must carry tail and ear collapse channels.")
            if species_names[index] == &"burrower":
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Idle") >= 6, "Burrower Idle must carry lamp, fin, thorax and drill breathing channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Walk") >= 6, "Burrower Walk must carry paired-leg, fin and drill locomotion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Attack") >= 6, "Burrower Attack must carry drill, lamp and jaw threat channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Hit") >= 5, "Burrower Hit must carry lamp and drill impact channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Feed") >= 5, "Burrower Feed must carry paired jaw and lamp motion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Nest") >= 5, "Burrower Nest must carry paired fin and drill watch channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Retreat") >= 5, "Burrower Retreat must carry paired-leg and fin withdrawal channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Death") >= 4, "Burrower Death must carry drill and lamp collapse channels.")
            if species_names[index] == &"sporecaster":
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Idle") >= 6, "Sporecaster Idle must carry cowl, gill, spine and stem breathing channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Walk") >= 6, "Sporecaster Walk must carry paired-leg, gill and stem locomotion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Attack") >= 6, "Sporecaster Attack must carry sac, cowl, gill and stem threat channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Hit") >= 5, "Sporecaster Hit must carry cowl, gill and sac impact channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Feed") >= 5, "Sporecaster Feed must carry sac, stem and gill motion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Nest") >= 5, "Sporecaster Nest must carry paired gill and spine watch channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Retreat") >= 5, "Sporecaster Retreat must carry paired-leg and gill withdrawal channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Death") >= 4, "Sporecaster Death must carry cowl and gill collapse channels.")
            if species_names[index] == &"roofleaper":
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Idle") >= 6, "Roofleaper Idle must carry paired membrane and vascular-wing breathing channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Walk") >= 6, "Roofleaper Walk must carry paired wing and spar locomotion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Attack") >= 8, "Roofleaper Attack must carry paired wing, spar and crown-ridge threat channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Hit") >= 5, "Roofleaper Hit must carry paired wing and crown impact channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Feed") >= 5, "Roofleaper Feed must carry crown and vascular-wing motion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Nest") >= 5, "Roofleaper Nest must carry paired spar and crown-ridge watch channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Retreat") >= 5, "Roofleaper Retreat must carry paired-wing and talon withdrawal channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Death") >= 4, "Roofleaper Death must carry crown and wing-spar collapse channels.")
            if species_names[index] == &"apex":
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Idle") >= 4, "Apex Idle must carry living membrane flex channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Attack") >= 6, "Apex Attack must carry jaw and membrane threat channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Feed") >= 4, "Apex Feed must carry jaw motion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Retreat") >= 4, "Apex Retreat must carry membrane withdrawal channels.")
            if species_names[index] == &"rootweaver":
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Idle") >= 5, "Rootweaver Idle must carry spore-fan and rib breathing channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Walk") >= 4, "Rootweaver Walk must carry paired root-arm channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Attack") >= 6, "Rootweaver Attack must carry fan, rib and root-spine threat channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Feed") >= 5, "Rootweaver Feed must carry fan and root-arm motion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Retreat") >= 5, "Rootweaver Retreat must carry paired root-spine withdrawal channels.")
            if species_names[index] == &"miremaw":
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Idle") >= 7, "Miremaw Idle must carry gill-fan, folded-collar and ridge breathing channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Walk") >= 4, "Miremaw Walk must carry paired water-fin channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Attack") >= 8, "Miremaw Attack must carry folded-collar, jaw-hook and jaw-plate threat channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Feed") >= 7, "Miremaw Feed must carry folded-collar, jaw and gill-fan motion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Retreat") >= 7, "Miremaw Retreat must carry folded-collar, water-fin and gill withdrawal channels.")
            if species_names[index] == &"glassmoth":
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Idle") >= 6, "Glassmoth Idle must carry paired wing breathing channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Walk") >= 6, "Glassmoth Walk must carry paired wing flight channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Attack") >= 8, "Glassmoth Attack must carry wing flare and antenna threat channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Feed") >= 6, "Glassmoth Feed must carry wing and antenna motion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Retreat") >= 6, "Glassmoth Retreat must carry paired wing withdrawal channels.")
            if species_names[index] == &"carrionbell":
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Idle") >= 5, "Carrionbell Idle must carry mantle-seam and resonator-ring breathing channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Walk") >= 5, "Carrionbell Walk must carry mantle and seam motion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Attack") >= 7, "Carrionbell Attack must carry resonator and bell-rib threat channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Feed") >= 6, "Carrionbell Feed must carry resonator and mantle motion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Retreat") >= 6, "Carrionbell Retreat must carry ring and tendril withdrawal channels.")
            if species_names[index] == &"thornback":
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Idle") >= 6, "Thornback Idle must carry paired jaw and dorsal-spine breathing channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Walk") >= 5, "Thornback Walk must carry paired spine and dorsal-ridge motion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Attack") >= 7, "Thornback Attack must carry jaw, spine and crown threat channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Feed") >= 6, "Thornback Feed must carry paired jaw and spine motion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Retreat") >= 6, "Thornback Retreat must carry paired spine withdrawal channels.")
            if species_names[index] == &"ashmantle":
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Idle") >= 6, "Ashmantle Idle must carry paired heat-louver and rib breathing channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Walk") >= 6, "Ashmantle Walk must carry paired louver and rib motion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Attack") >= 9, "Ashmantle Attack must carry siphon, louver and tendril threat channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Feed") >= 7, "Ashmantle Feed must carry siphon, louver and tendril motion channels.")
                _expect(_animation_player_track_count(authored_animation.animation_player, &"Retreat") >= 6, "Ashmantle Retreat must carry paired louver withdrawal channels.")
            var previous_state: StringName = StringName(enemy_samples[index].get(&"state_name"))
            enemy_samples[index].set(&"state_name", &"feeding")
            enemy_samples[index].set_meta(&"enemy_behaviour", "feed")
            authored_animation.one_shot_remaining = 0.0
            authored_animation._select_loop_clip()
            _expect(_animation_clip_matches(authored_animation.active_clip, &"Feed"), "%s feeding state must select Feed." % species_names[index])
            enemy_samples[index].set(&"state_name", &"nest_guard")
            enemy_samples[index].set_meta(&"enemy_behaviour", "guard_nest")
            authored_animation.one_shot_remaining = 0.0
            authored_animation._select_loop_clip()
            _expect(_animation_clip_matches(authored_animation.active_clip, &"Nest"), "%s nest guard state must select Nest." % species_names[index])
            enemy_samples[index].set(&"state_name", &"retreating")
            enemy_samples[index].set_meta(&"enemy_behaviour", "retreat")
            authored_animation.one_shot_remaining = 0.0
            authored_animation._select_loop_clip()
            _expect(_animation_clip_matches(authored_animation.active_clip, &"Retreat"), "%s retreat state must select Retreat." % species_names[index])
            var procedural_animator := enemy_samples[index].get_node_or_null("ProceduralAnimator3D") as ProceduralAnimator3D
            if procedural_animator != null:
                var action_transforms: Dictionary = {}
                for action_state in [&"feeding", &"nest_guard", &"retreating"]:
                    enemy_samples[index].set(&"state_name", action_state)
                    procedural_animator.idle_phase = 0.61
                    procedural_animator.phase = 0.37
                    procedural_animator._restore_base_transforms()
                    procedural_animator._animate_organic(0.0)
                    action_transforms[action_state] = procedural_animator.model_root.transform
                _expect(action_transforms[&"feeding"] != action_transforms[&"nest_guard"], "%s feeding and nest-guard poses must be visibly distinct." % species_names[index])
                _expect(action_transforms[&"nest_guard"] != action_transforms[&"retreating"], "%s nest-guard and retreat poses must be visibly distinct." % species_names[index])
                var heads := procedural_animator._nodes_with_prefix(procedural_animator.model_root, "Head")
                if not heads.is_empty():
                    procedural_animator._restore_base_transforms()
                    procedural_animator.hit_impulse = 0.0
                    procedural_animator._animate_organic(0.0)
                    var neutral_head_transform: Transform3D = heads[0].transform
                    procedural_animator._restore_base_transforms()
                    procedural_animator.hit_impulse = 1.0
                    procedural_animator._animate_organic(0.0)
                    _expect(heads[0].transform != neutral_head_transform, "%s non-lethal hits must recoil the sensory head." % species_names[index])
                    procedural_animator.hit_impulse = 0.0
            authored_animation._on_health_changed(enemy_samples[index], 20.0, 30.0)
            _expect(_animation_clip_matches(authored_animation.active_clip, &"Hit"), "%s damage events must select Hit." % species_names[index])
            enemy_samples[index].set(&"state_name", previous_state)
            enemy_samples[index].remove_meta(&"enemy_behaviour")
        _expect_family_attack_motion(enemy_samples[index], _family_attack_signature_node(species_names[index]))
        if authored_animation != null:
            enemy_samples[index].apply_damage(99999.0)
            _expect(not enemy_samples[index].is_alive(), "%s death must mark gameplay state dead immediately." % species_names[index])
            _expect(enemy_samples[index].death_presentation_remaining > 0.0, "%s death must retain a short presentation window." % species_names[index])
            _expect(_animation_clip_matches(authored_animation.active_clip, &"Death"), "%s death must select the authored Death clip." % species_names[index])
            var death_presentation := _find_named(enemy_samples[index], "OrganicDeathPresentation") as Node3D
            _expect(death_presentation != null and death_presentation.visible, "%s death must reveal its bounded failure presentation before cleanup." % species_names[index])
            enemy_samples[index].death_presentation_remaining = 0.0
            enemy_samples[index]._refresh_death_presentation()
            _expect(death_presentation != null and not death_presentation.visible, "%s death presentation must hide when its existing cleanup window expires." % species_names[index])
        enemy_samples[index].queue_free()

    var razorhound_asset := RAZORHOUND_ASSET_SCENE.instantiate()
    var sporecaster_asset := SPORECASTER_ASSET_SCENE.instantiate()
    var skitterling_asset := SKITTERLING_ASSET_SCENE.instantiate()
    var roofleaper_asset := ROOFLEAPER_ASSET_SCENE.instantiate()
    var glassmoth_asset := GLASSMOTH_ASSET_SCENE.instantiate()
    var razorhound_cheek := _find_named(razorhound_asset, "RazorhoundCheekPlate") as MeshInstance3D
    var razorhound_brow := _find_named(razorhound_asset, "RazorhoundBrowGuard") as MeshInstance3D
    var razorhound_muzzle := _find_named(razorhound_asset, "RazorhoundMuzzleGuard") as MeshInstance3D
    var razorhound_throat := _find_named(razorhound_asset, "RazorhoundThroatLobe") as MeshInstance3D
    var razorhound_nostril := _find_named(razorhound_asset, "RazorhoundNostrilL") as MeshInstance3D
    _expect(_mesh_vertex_count(_find_named(razorhound_asset, "OrganicDorsalPlate") as MeshInstance3D) >= 48 and _mesh_vertex_count(razorhound_cheek) >= 48 and _mesh_vertex_count(razorhound_brow) >= 96, "The authored Razorhound dorsal, cheek and eye-guard plates must retain dense high-definition anatomy edges.")
    _expect(razorhound_cheek != null and razorhound_cheek.mesh.get_aabb().size.y >= 0.28, "The Razorhound cheek plates must retain closed folded volume around the bite line rather than reading as rectangular bars.")
    _expect(razorhound_brow != null and razorhound_brow.get_parent().name == "RazorhoundHead" and razorhound_brow.mesh.get_aabb().size.y >= 0.10, "The Razorhound brow guard must remain a dense child of the authored head so its eye silhouette does not detach.")
    _expect(razorhound_muzzle != null and _mesh_vertex_count(razorhound_muzzle) >= 500 and razorhound_muzzle.get_parent().name == "RazorhoundSnout" and razorhound_muzzle.mesh.get_aabb().size.y >= 0.12, "The Razorhound muzzle guard must retain a dense parented shell that follows the existing bite socket.")
    _expect(razorhound_throat != null and _mesh_vertex_count(razorhound_throat) >= 500 and razorhound_throat.get_parent().name == "RazorhoundSnout" and razorhound_throat.mesh.get_aabb().size.y >= 0.16, "The Razorhound throat lobe must close the bite line as a parented articulated living surface.")
    _expect(razorhound_nostril != null and razorhound_nostril.get_parent().name == "RazorhoundSnout", "The Razorhound muzzle must retain paired parented nostril sensor details.")
    var spore_sac_rim := _find_named(sporecaster_asset, "SporecasterSacRim0") as MeshInstance3D
    var spore_sac_pore := _find_named(sporecaster_asset, "SporecasterSacPore0") as MeshInstance3D
    _expect(_mesh_vertex_count(_find_named(sporecaster_asset, "OrganicDorsalPlate") as MeshInstance3D) >= 48 and _mesh_vertex_count(_find_named(sporecaster_asset, "SporecasterGillFan0") as MeshInstance3D) >= 48 and _mesh_vertex_count(spore_sac_rim) >= 100 and _mesh_vertex_count(spore_sac_pore) >= 48, "The authored Sporecaster dorsal, gill and sac-aperture surfaces must retain beveled high-definition anatomy edges.")
    var skitterling_fan := _find_named(skitterling_asset, "SkitterlingSensoryFan0") as MeshInstance3D
    var skitterling_head := _find_named(skitterling_asset, "SkitterlingHeadShield") as MeshInstance3D
    var skitterling_head_ridge := _find_named(skitterling_asset, "SkitterlingHeadRidge") as MeshInstance3D
    _expect(_mesh_vertex_count(_find_named(skitterling_asset, "OrganicDorsalPlate") as MeshInstance3D) >= 48 and _mesh_vertex_count(skitterling_fan) >= 500, "The authored Skitterling dorsal and sensory membranes must retain dense high-definition anatomy edges.")
    _expect(skitterling_head != null and _mesh_vertex_count(skitterling_head) >= 500 and skitterling_head_ridge != null, "The authored Skitterling must retain a smooth cephalic shield and raised ridge for tactical-distance head readability.")
    _expect(skitterling_fan != null and skitterling_fan.mesh.get_aabb().size.x >= 0.16, "The Skitterling sensory fans must retain closed rounded membrane volume rather than reading as thin bars.")
    _expect(_mesh_vertex_count(_find_named(roofleaper_asset, "RoofleaperWingL") as MeshInstance3D) >= 700, "The authored Roofleaper wing must retain a dense swept membrane silhouette rather than a low-detail disc.")
    _expect(_mesh_vertex_count(_find_named(glassmoth_asset, "GlassmothWingL0") as MeshInstance3D) >= 700, "The authored Glassmoth wing must retain a dense swept membrane silhouette rather than a low-detail disc.")
    var glassmoth_wing := _find_named(glassmoth_asset, "GlassmothWingL0") as Node3D
    _expect(glassmoth_wing != null and absf(glassmoth_wing.rotation.x) >= 0.30 and glassmoth_wing.scale.z <= 0.80, "The authored Glassmoth wing pair must retain a pitched, depth-separated flight silhouette.")
    var glassmoth_vein := _find_named(glassmoth_asset, "GlassmothWingVeinL0A") as MeshInstance3D
    _expect(glassmoth_vein != null and _mesh_vertex_count(glassmoth_vein) >= 48 and glassmoth_vein.get_parent() == glassmoth_wing, "The Glassmoth wing must retain a dense parented vascular lattice that follows the existing wing animation.")
    razorhound_asset.queue_free()
    sporecaster_asset.queue_free()
    skitterling_asset.queue_free()
    roofleaper_asset.queue_free()
    glassmoth_asset.queue_free()

    var veilstalker_asset := VEILSTALKER_ASSET_SCENE.instantiate()
    var burrower_asset := BURROWER_ASSET_SCENE.instantiate()
    var broodmass_asset := BROODMASSS_ASSET_SCENE.instantiate()
    _expect(_mesh_vertex_count(_find_named(veilstalker_asset, "OrganicDorsalPlate") as MeshInstance3D) >= 48 and _mesh_vertex_count(_find_named(veilstalker_asset, "VeilstalkerDorsalPlate") as MeshInstance3D) >= 48, "The authored Veilstalker dorsal plates must retain beveled high-definition anatomy edges.")
    var veilstalker_dorsal := _find_named(veilstalker_asset, "OrganicDorsalPlate") as MeshInstance3D
    _expect(veilstalker_dorsal != null and veilstalker_dorsal.mesh.get_aabb().size.y >= 0.28, "The Veilstalker dorsal plates must retain closed folded volume across the thorax rather than reading as rectangular bars.")
    _expect(_mesh_vertex_count(_find_named(veilstalker_asset, "VeilstalkerMandibleL") as MeshInstance3D) >= 48 and _mesh_vertex_count(_find_named(veilstalker_asset, "VeilstalkerCowlSpineL") as MeshInstance3D) >= 48 and _mesh_vertex_count(_find_named(veilstalker_asset, "VeilstalkerCowlPlateL") as MeshInstance3D) >= 48, "The authored Veilstalker must retain dense mouth, cowl and layered brow silhouette hardware.")
    _expect(_mesh_vertex_count(_find_named(burrower_asset, "OrganicDorsalPlate") as MeshInstance3D) >= 48 and _mesh_vertex_count(_find_named(burrower_asset, "BurrowerLampGuardL") as MeshInstance3D) >= 48 and _mesh_vertex_count(_find_named(burrower_asset, "BurrowerDrillCutter0") as MeshInstance3D) >= 24, "The authored Burrower dorsal, lamp guards and drill cutters must retain beveled high-definition anatomy edges.")
    var broodmass_dorsal := _find_named(broodmass_asset, "OrganicDorsalPlate") as MeshInstance3D
    var broodmass_maw_plate := _find_named(broodmass_asset, "BroodmassMawPlate") as MeshInstance3D
    var broodmass_maw_lower := _find_named(broodmass_asset, "BroodmassMawLower") as MeshInstance3D
    _expect(_mesh_vertex_count(broodmass_dorsal) >= 48 and _mesh_vertex_count(_find_named(broodmass_asset, "BroodmassFanL") as MeshInstance3D) >= 48, "The authored Broodmass dorsal and membrane hardware must retain beveled high-definition anatomy edges.")
    _expect(broodmass_dorsal != null and broodmass_dorsal.mesh.get_aabb().size.y >= 0.30 and broodmass_maw_plate != null and broodmass_maw_plate.mesh.get_aabb().size.y >= 0.30, "The authored Broodmass dorsal and maw plates must retain closed folded volume rather than broad horizontal sheets.")
    _expect(broodmass_maw_lower != null and _mesh_vertex_count(broodmass_maw_lower) >= 500 and broodmass_maw_lower.mesh.get_aabb().size.y >= 0.20 and broodmass_maw_lower.get_parent().name == "BroodmassMaw", "Broodmass's lower maw must retain a dense folded shell with readable depth on the animated maw socket.")
    var broodmass_rib := _find_named(broodmass_asset, "BroodmassThoraxRib0") as MeshInstance3D
    _expect(broodmass_rib != null and _mesh_vertex_count(broodmass_rib) >= 200 and absf(broodmass_rib.rotation.z) >= 1.4, "The authored Broodmass thorax ribs must retain dense rounded struts rather than horizontal flat bars.")
    veilstalker_asset.queue_free()
    burrower_asset.queue_free()
    broodmass_asset.queue_free()

    var miremaw_asset := MIREMAW_ASSET_SCENE.instantiate()
    var carrionbell_asset := CARRIONBELL_ASSET_SCENE.instantiate()
    var rootweaver_asset := ROOTWEAVER_ASSET_SCENE.instantiate()
    var thornback_asset := THORNBACK_ASSET_SCENE.instantiate()
    var ashmantle_asset := ASHMANTLE_ASSET_SCENE.instantiate()
    var deep_membrane_names: Array[String] = [
        "MiremawGillFan", "MiremawWaterFinL", "RootweaverSporeFan",
    ]
    var deep_membrane_assets: Array[Node] = [miremaw_asset, miremaw_asset, rootweaver_asset]
    for index in deep_membrane_names.size():
        var deep_membrane := _find_named(deep_membrane_assets[index], deep_membrane_names[index]) as MeshInstance3D
        _expect(deep_membrane != null and _mesh_vertex_count(deep_membrane) >= 1000, "%s must retain the dense folded late-organic membrane profile." % deep_membrane_names[index])
        _expect(deep_membrane != null and deep_membrane.mesh.get_aabb().size.y >= 0.45, "%s must retain closed depth rather than reading as a thin horizontal sheet." % deep_membrane_names[index])
    _expect(_mesh_vertex_count(_find_named(carrionbell_asset, "CarrionbellCrownPlate") as MeshInstance3D) >= 500, "Carrion Bell must retain a dense folded crown silhouette.")
    _expect(_mesh_vertex_count(_find_named(thornback_asset, "ThornbackCrownPlate") as MeshInstance3D) >= 500, "Thornback must retain a dense folded territorial crown silhouette.")
    _expect(_mesh_vertex_count(_find_named(ashmantle_asset, "AshmantleHeatLouverL") as MeshInstance3D) >= 700, "Ashmantle must retain a dense folded heat-louver silhouette.")
    var miremaw_collar_l := _find_named(miremaw_asset, "MiremawGillCollarL") as MeshInstance3D
    var miremaw_collar_r := _find_named(miremaw_asset, "MiremawGillCollarR") as MeshInstance3D
    _expect(miremaw_collar_l != null and miremaw_collar_r != null and _mesh_vertex_count(miremaw_collar_l) >= 700 and _mesh_vertex_count(miremaw_collar_r) >= 700, "Miremaw's paired folded gill collars must retain dense scalloped close-camera geometry.")
    _expect(miremaw_collar_l != null and miremaw_collar_r != null and miremaw_collar_l.mesh.get_aabb().size.y >= 0.20 and miremaw_collar_r.mesh.get_aabb().size.y >= 0.20, "Miremaw's folded gill collars must retain closed membrane depth rather than collapsing into thin plates.")
    var miremaw_jaw_lower := _find_named(miremaw_asset, "MiremawJawLower") as MeshInstance3D
    _expect(miremaw_jaw_lower != null and _mesh_vertex_count(miremaw_jaw_lower) >= 900 and miremaw_jaw_lower.mesh.get_aabb().size.y >= 0.20, "Miremaw's lower jaw must retain a dense folded shell with readable depth.")
    _expect(_mesh_vertex_count(_find_named(miremaw_asset, "MiremawJawHingeL") as MeshInstance3D) >= 48 and _mesh_vertex_count(_find_named(miremaw_asset, "MiremawJawHingeR") as MeshInstance3D) >= 48, "Miremaw's paired jaw hinges must retain rounded close-camera hardware geometry.")
    var carrionbell_crown := _find_named(carrionbell_asset, "CarrionbellCrownPlate") as Node3D
    var thornback_crown := _find_named(thornback_asset, "ThornbackCrownPlate") as Node3D
    var ashmantle_louver := _find_named(ashmantle_asset, "AshmantleHeatLouverL") as Node3D
    _expect(carrionbell_crown != null and absf(carrionbell_crown.rotation.x) >= 0.14, "Carrion Bell's folded crown must retain a raised forward pitch for readable bell depth.")
    _expect(thornback_crown != null and absf(thornback_crown.rotation.x) >= 0.12, "Thornback's territorial crown must retain a raised forward pitch for readable shield depth.")
    _expect(ashmantle_louver != null and absf(ashmantle_louver.rotation.x) >= 0.16, "Ashmantle's heat louver must retain a pitched vent profile instead of a horizontal fin silhouette.")
    miremaw_asset.queue_free()
    carrionbell_asset.queue_free()
    rootweaver_asset.queue_free()
    thornback_asset.queue_free()
    ashmantle_asset.queue_free()

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
        _expect(veilstalker.find_child("VeilstalkerMandibleL", true, false) != null and veilstalker.find_child("VeilstalkerMandibleR", true, false) != null, "The Veilstalker must expose paired attack mandibles.")
        _expect(veilstalker.find_child("VeilstalkerCowlSpineL", true, false) != null and veilstalker.find_child("VeilstalkerCowlSpineR", true, false) != null, "The Veilstalker must expose paired cowl spines.")
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
    var pharmacy_interior := world.get_node_or_null("ProceduralUrbanDistrict/RuinedBuilding00/VerticalSliceFacade/PharmacyInteriorVignette") as Node3D
    _expect(pharmacy_interior != null, "The opening district must expose a bounded inhabited pharmacy interior vignette.")
    if pharmacy_interior != null:
        _expect(pharmacy_interior.find_child("PharmacyInteriorBackWall", true, false) != null and pharmacy_interior.find_child("PharmacyInteriorCounter", true, false) != null, "The pharmacy interior must expose room depth and a readable service counter.")
        _expect(pharmacy_interior.find_child("PharmacyInteriorShelf0", true, false) != null and pharmacy_interior.find_child("PharmacyInteriorVial0_0", true, false) != null, "The pharmacy interior must expose high-definition shelving and stored medical detail.")
        _expect(pharmacy_interior.find_child("PharmacyInteriorEmergencyLamp", true, false) != null and pharmacy_interior.find_child("PharmacyInteriorDroppedSign", true, false) != null, "The pharmacy interior must expose an interrupted-life light and service trace.")
    var workshop_interior := world.get_node_or_null("ProceduralUrbanDistrict/RuinedBuilding02/VerticalSliceFacade/WorkshopInteriorVignette") as Node3D
    _expect(workshop_interior != null, "The opening district must expose a bounded failed-workshop interior vignette.")
    if workshop_interior != null:
        _expect(workshop_interior.find_child("WorkshopInteriorBackWall", true, false) != null and workshop_interior.find_child("WorkshopInteriorBench", true, false) != null, "The workshop interior must expose room depth and a readable workbench.")
        _expect(workshop_interior.find_child("WorkshopInteriorToolHandle00", true, false) != null and workshop_interior.find_child("WorkshopInteriorPegboard", true, false) != null, "The workshop interior must expose tool storage and pegboard anatomy.")
        _expect(workshop_interior.find_child("WorkshopInteriorBatteryCabinet", true, false) != null and workshop_interior.find_child("WorkshopInteriorWorkLamp", true, false) != null, "The workshop interior must expose service power and interrupted task lighting.")
    _expect(world.camera_heading.x > 0.5 and world.camera_heading.z > 0.6, "The opening camera must preserve a diagonal cast-separation heading so the Mechromancer and Bulwark do not collapse into one silhouette.")
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
        _expect(opening_roles.has(&"cast_cool_key"), "The opening cast must retain a restrained cool separation light for the technician and Bulwark silhouettes.")
        _expect(opening_roles.has(&"cast_warm_fill"), "The opening cast must retain a restrained warm fill that keeps maintained hardware readable against the cool foreground.")
        var heartforge_key_energy := 0.0
        var cast_cool_energy := 0.0
        var cast_warm_energy := 0.0
        for opening_light in opening_slice.get_children():
            if not opening_light is OmniLight3D:
                continue
            match opening_light.get_meta(&"opening_light_role", &""):
                &"heartforge_key":
                    heartforge_key_energy = float(opening_light.get_meta(&"vertical_base_energy", opening_light.light_energy))
                &"cast_cool_key":
                    cast_cool_energy = float(opening_light.get_meta(&"vertical_base_energy", opening_light.light_energy))
                &"cast_warm_fill":
                    cast_warm_energy = float(opening_light.get_meta(&"vertical_base_energy", opening_light.light_energy))
        _expect(heartforge_key_energy <= 1.85 and cast_cool_energy >= 0.8 and cast_warm_energy >= 0.45, "The opening light hierarchy must give the Mechromancer and Bulwark readable foreground separation while preserving the Heartforge as the warm focal source.")
        _expect(strongest_opening_light <= 2.3, "The opening key light must avoid washing the wet district surface into a white pool.")

    var opening_environment := _find_world_environment(world)
    if opening_environment != null and opening_environment.environment != null:
        _expect(opening_environment.environment.glow_bloom <= 0.08, "The opening bloom budget must keep puddles and concrete readable.")

    var atmosphere := world.get_node_or_null("RegionAtmosphereDirector") as RegionAtmosphereDirector3D
    if atmosphere != null:
        var sanctuary_palette: Dictionary = atmosphere.palette_for_kind(&"sanctuary")
        _expect(float(sanctuary_palette.get("glow", 1.0)) <= 0.46, "The opening sanctuary palette must preserve material separation around the Heartforge.")

    var release_world := world as IronwrightReleaseWorld3D
    _expect(release_world != null, "The aesthetic review fixture must expose the release presentation world.")
    if release_world != null:
        release_world._start_presentation_review()
        release_world._show_presentation_review_page(1)
        _expect(release_world.presentation_review_camera_desired.z <= 9.5 and release_world.presentation_review_camera_target.y >= 1.1, "The early and late organic galleries must use a closer detail frame so authored creature anatomy remains judgeable at review distance.")
        var skitterling_review_actor: Node3D
        for review_actor in release_world.presentation_review_pages[1]:
            var candidate := review_actor as Node3D
            if candidate != null and candidate.name.to_lower().begins_with("skitterling"):
                skitterling_review_actor = candidate
                break
        var skitterling_review_root := skitterling_review_actor.get_node_or_null("OrganicModel") as Node3D if skitterling_review_actor != null else null
        _expect(skitterling_review_root != null and skitterling_review_root.scale.x >= 1.2, "The small Skitterling must receive a bounded gallery-only scale compensation so its authored anatomy is judgeable beside the early predators.")
        release_world._show_presentation_review_page(12)
        var buried_labs_review_actor: Node3D
        for review_actor in release_world.presentation_review_pages[12]:
            var candidate := review_actor as Node3D
            if candidate != null and candidate.name.to_lower().begins_with("buriedlabs"):
                buried_labs_review_actor = candidate
                break
        var buried_vessel := _find_named(buried_labs_review_actor, "BuriedLabsVesselBody0") as MeshInstance3D if buried_labs_review_actor != null else null
        var buried_vessel_material := buried_vessel.material_override as StandardMaterial3D if buried_vessel != null else null
        _expect(buried_vessel_material != null and buried_vessel_material.emission_energy_multiplier <= 0.50 and buried_vessel_material.albedo_color.get_luminance() <= 0.30, "Buried Laboratories review vessels must retain glass/metal separation instead of clipping into flat cyan bodies.")

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


func _wait_for_authored_package(landmark: RegionLandmark3D, package_name: Variant) -> void:
    if landmark == null:
        return
    var package := landmark.get_node_or_null("PersistentRegionGeometry/%s" % str(package_name)) as Node3D
    for _frame in range(120):
        if package != null and package.get_child_count() > 0:
            return
        await process_frame


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


func _find_first_mesh(node: Node) -> MeshInstance3D:
    if node == null or not is_instance_valid(node):
        return null
    if node is MeshInstance3D:
        return node as MeshInstance3D
    for child in node.get_children():
        var result := _find_first_mesh(child as Node)
        if result != null:
            return result
    return null


func _mesh_vertex_count(mesh_instance: MeshInstance3D) -> int:
    if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
        return 0
    var arrays := mesh_instance.mesh.surface_get_arrays(0)
    if arrays.size() <= Mesh.ARRAY_VERTEX or arrays[Mesh.ARRAY_VERTEX] == null:
        return 0
    return (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()


func _find_named(root: Node, node_name: String) -> Node:
    return root.find_child(node_name, true, false)


func _animation_player_has_clip(player: AnimationPlayer, clip_name: StringName) -> bool:
    if player.has_animation(clip_name):
        return true
    for candidate in player.get_animation_list():
        if String(candidate).ends_with("/" + String(clip_name)) or String(candidate).ends_with(String(clip_name)):
            return true
    return false


func _animation_player_track_count(player: AnimationPlayer, clip_name: StringName) -> int:
    if player == null:
        return 0
    var resolved := clip_name
    if not player.has_animation(resolved):
        for candidate in player.get_animation_list():
            var candidate_text := String(candidate)
            if candidate_text.ends_with("/" + String(clip_name)) or candidate_text.ends_with(String(clip_name)):
                resolved = StringName(candidate_text)
                break
    if not player.has_animation(resolved):
        return 0
    var animation := player.get_animation(resolved)
    return animation.get_track_count() if animation != null else 0


func _animation_clip_matches(active_clip: StringName, clip_name: StringName) -> bool:
    return String(active_clip).ends_with("/" + String(clip_name)) or String(active_clip).ends_with(String(clip_name))


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
        &"thornback": return &"ThornbackJawPlateL"
        &"ashmantle": return &"AshmantleSiphon"
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
        &"relay":
            return _find_named(robot, "RelayMast") != null and _find_named(robot, "RelayDirectionalDish") != null and _find_named(robot, "RelayBeacon") != null
    return false


func _outpost_model_has_details(outpost: Outpost3D, role: StringName) -> bool:
    if outpost == null or outpost.get_node_or_null("OutpostModel") == null:
        return false
    match role:
        &"resource":
            return _find_named(outpost, "ResourceHopper") != null and _find_named(outpost, "ResourceHopperLouver") != null and _find_named(outpost, "ResourceExtractorArm") != null and _find_named(outpost, "ResourceIntakeBeacon") != null and _find_named(outpost, "ResourceHopperRibLeft") != null and _find_named(outpost, "ResourceIntakeCollar") != null
        &"defence":
            return _find_named(outpost, "DefenceTurretHousing") != null and _find_named(outpost, "DefenceBarrel") != null and _find_named(outpost, "DefenceMuzzleGlow") != null and _find_named(outpost, "DefenceTurretCollar") != null and _find_named(outpost, "DefenceRecoilGuardLeft") != null
        &"scout":
            return _find_named(outpost, "ScoutSensorHousing") != null and _find_named(outpost, "ScoutSensorDish") != null and _find_named(outpost, "ScoutDishRib") != null and _find_named(outpost, "ScoutMastBraceLeft") != null and _find_named(outpost, "ScoutDishHubRing") != null
        &"repair":
            return _find_named(outpost, "RepairPad") != null and _find_named(outpost, "RepairPadPanel") != null and _find_named(outpost, "RepairFieldEmitter") != null and _find_named(outpost, "RepairFieldRing") != null and _find_named(outpost, "RepairArmCollarLeft") != null
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
        &"thornback":
            return _find_named(enemy, "ThornbackCrown") != null and _find_named(enemy, "ThornbackSpineL") != null and _find_named(enemy, "ThornbackJawPlateL") != null
        &"ashmantle":
            return _find_named(enemy, "AshmantleMantle") != null and _find_named(enemy, "AshmantleHeatLouverL") != null and _find_named(enemy, "AshmantleSiphon") != null
    return false
