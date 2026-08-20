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
            if landmark.region_kind == &"endgame":
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/RootCisternAuthoredModel") != null, "The Root Cistern must expose its authored landmark shell.")
            if landmark.region_kind == &"nest":
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/NestOccluderShell") != null, "The nest must isolate its close-range opaque shell for camera-safe presentation.")
            if landmark.region_kind == &"commercial":
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/FloodMarketIdentityDetails") != null, "Flood Market must expose authored stall canopies and hanging signs.")
                _expect(landmark.find_child("MarketFloodChannel", true, false) != null, "Flood Market must expose bounded presentation-only water channels.")
            if landmark.region_kind == &"waterfront":
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/WaterfrontIdentityDetails/RiverworksSluiceDetails") != null, "Riverworks must expose an authored sluice assembly.")
                _expect(landmark.find_child("RiverWaterlineBreak", true, false) != null, "Riverworks must expose bounded waterline breaks at the dock edge.")
                _expect(landmark.find_child("RiverWaterChannel", true, false) != null, "Riverworks must expose a readable shallow water channel.")
            if landmark.region_kind == &"research":
                _expect(landmark.get_node_or_null("PersistentRegionGeometry/BuriedLaboratoriesIdentityDetails") != null, "Buried Laboratories must expose its authored containment vignette.")
                _expect(landmark.find_child("LabContainmentVessel", true, false) != null, "Buried Laboratories must expose readable containment vessels.")
                _expect(landmark.find_child("LabTransferRail", true, false) != null, "Buried Laboratories must expose an overhead transfer rail.")
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
        if veilstalker_animator != null:
            var veil := veilstalker.find_child("VeilstalkerVeil", true, false) as Node3D
            var veil_before := veil.transform if veil != null else Transform3D.IDENTITY
            var previous_state: StringName = StringName(veilstalker.get(&"state_name"))
            var previous_windup := float(veilstalker.get(&"attack_windup_remaining"))
            veilstalker.set(&"state_name", &"attacking")
            veilstalker.set(&"attack_windup_remaining", 0.34)
            veilstalker_animator._restore_base_transforms()
            veilstalker_animator._animate_organic(0.0)
            _expect(veil != null and veil.transform != veil_before, "Veilstalker attack wind-up must visibly load its veil silhouette.")
            veilstalker.set(&"state_name", previous_state)
            veilstalker.set(&"attack_windup_remaining", previous_windup)

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
            return _find_named(enemy, "RoofleaperCrown") != null and _find_named(enemy, "RoofleaperWingStrut0") != null and _find_named(enemy, "RoofleaperCrownOculus") != null
        &"glassmoth":
            return _find_named(enemy, "GlassmothThorax") != null and _find_named(enemy, "GlassmothWingRib0") != null and _find_named(enemy, "GlassmothAntenna") != null
        &"miremaw":
            return _find_named(enemy, "MiremawDorsalShell") != null and _find_named(enemy, "MiremawTusk") != null and _find_named(enemy, "MiremawGillFan") != null
        &"carrionbell":
            return _find_named(enemy, "CarrionbellMantle") != null and _find_named(enemy, "CarrionbellCrownPlate") != null and _find_named(enemy, "CarrionbellResonator") != null
        &"rootweaver":
            return _find_named(enemy, "RootweaverCrown") != null and _find_named(enemy, "RootweaverTendril0") != null and _find_named(enemy, "RootweaverSporeFan") != null
    return false
