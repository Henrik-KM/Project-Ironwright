extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")
const ROBOT_SCENE := preload("res://scenes/actors/robot_unit_3d.tscn")
const ENEMY_SCENE := preload("res://scenes/actors/organic_enemy_3d.tscn")

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
        for profile in [&"pistol", &"machine_weapon", &"salvage", &"forge", &"organic_attack", &"organic_death", &"heartforge_damage", &"noise_pulse"]:
            _expect(audio_director.has_profile(profile), "The audio director must provide the %s profile." % profile)
    _expect(world.get_node_or_null("CozyHeartforgeCamp") != null, "The Heartforge must receive an inhabited cozy camp layer.")
    _expect(world.get_node_or_null("UrbanAestheticPass") != null, "The ruined city must receive the urban storytelling pass.")
    var region_atmosphere := world.get_node_or_null("RegionAtmosphereDirector") as RegionAtmosphereDirector3D
    _expect(region_atmosphere != null, "The complete world must install region-aware atmosphere presentation.")
    if region_atmosphere != null:
        var industrial_palette := region_atmosphere.palette_for_kind(&"industrial")
        var endgame_palette := region_atmosphere.palette_for_kind(&"endgame")
        _expect(float(industrial_palette.get("fog_density", 0.0)) > float(region_atmosphere.palette_for_kind(&"sanctuary").get("fog_density", 0.0)), "Industrial regions must carry a denser particulate atmosphere than the sanctuary.")
        _expect(industrial_palette.get("fog") != endgame_palette.get("fog"), "Late organic regions must have a distinct fog palette from industrial districts.")
        world.player.global_position = Vector3(-92.0, 0.0, 18.0)
        region_atmosphere.refresh_now()
        _expect(region_atmosphere.current_region_id == &"region.west_grid", "Moving the player to West Grid must select the persistent industrial region.")
        _expect(region_atmosphere.current_kind == &"industrial", "West Grid must resolve to its authored industrial atmosphere kind.")
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
        role_samples[index].queue_free()

    var enemy_samples: Array[OrganicEnemy3D] = []
    var species_names := [&"skitterling", &"razorhound", &"veilstalker", &"burrower", &"sporecaster", &"broodmass", &"apex"]
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
        enemy_samples[index].queue_free()

    var veilstalker: Node3D
    for enemy in get_nodes_in_group("organic_enemies"):
        if enemy is Node3D and StringName(enemy.get("species")) == &"veilstalker":
            veilstalker = enemy as Node3D
            break
    _expect(veilstalker != null, "The opening presentation needs a visible Veilstalker family member.")
    if veilstalker != null:
        _expect(veilstalker.get_node_or_null("ProceduralAnimator3D") is ProceduralAnimator3D, "The authored organic family must receive readable motion presentation.")
        _expect(veilstalker.find_child("VeilstalkerCowl", true, false) != null, "The Veilstalker must expose a distinct sensory crown silhouette.")
        _expect(veilstalker.find_child("VeilstalkerVeil", true, false) != null, "The Veilstalker must expose layered membrane anatomy.")
        _expect(veilstalker.find_child("VeilstalkerTendril", true, false) != null, "The Veilstalker must expose readable sensory tendrils.")
        _expect(veilstalker.find_child("VeilstalkerThoraxDorsalRib", true, false) != null, "The Veilstalker must expose a ribbed high-detail thorax construction.")

    var beautiful_hud := get_first_node_in_group("beautiful_hud")
    _expect(beautiful_hud is IronwrightBeautifulHUD3D, "The native HUD must use the quieter cinematic skin.")
    if beautiful_hud is IronwrightHUD3D:
        _expect((beautiful_hud as IronwrightHUD3D).player_portrait != null, "The HUD must expose the Mechromancer portrait.")
        _expect((beautiful_hud as IronwrightHUD3D).player_portrait.texture != null, "The Mechromancer portrait must have a texture.")

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
            return _find_named(robot, "CargoLip") != null and _find_named(robot, "DismantlerTool") != null and _find_named(robot, "SalvageDrum") != null
        &"guardian":
            return _find_named(robot, "WeaponBarrel") != null and _find_named(robot, "WeaponMuzzle") != null and _find_named(robot, "ShieldRib") != null
        &"scout":
            return _find_named(robot, "ScoutFin") != null and _find_named(robot, "BeaconRing") != null and _find_named(robot, "ScoutOptic") != null
        &"engineer":
            return _find_named(robot, "PistonJoint") != null and _find_named(robot, "ToolHead") != null and _find_named(robot, "ForgeCoil") != null
    return false


func _enemy_model_has_details(enemy: OrganicEnemy3D, species: StringName) -> bool:
    if enemy == null or enemy.get_node_or_null("OrganicModel") == null:
        return false
    match species:
        &"skitterling":
            return _find_named(enemy, "SkitterlingCarapace") != null and _find_named(enemy, "SkitterlingAntenna") != null
        &"razorhound":
            return _find_named(enemy, "RazorhoundSnout") != null and _find_named(enemy, "RazorhoundTail") != null and _find_named(enemy, "RazorhoundSpine") != null
        &"veilstalker":
            return _find_named(enemy, "VeilstalkerCowl") != null and _find_named(enemy, "VeilstalkerVeil") != null and _find_named(enemy, "VeilstalkerTendril") != null
        &"burrower":
            return _find_named(enemy, "BurrowerDrill") != null and _find_named(enemy, "BurrowerTip") != null
        &"sporecaster":
            return _find_named(enemy, "SporecasterSac") != null and _find_named(enemy, "SporecasterStem") != null and _find_named(enemy, "SporecasterOculus") != null
        &"broodmass":
            return _find_named(enemy, "BroodmassLobe") != null and _find_named(enemy, "CrownSpine") != null
        &"apex":
            return _find_named(enemy, "ApexCrown") != null and _find_named(enemy, "ApexJaw") != null
    return false
