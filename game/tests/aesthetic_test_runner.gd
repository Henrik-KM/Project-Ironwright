extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")

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
    _expect(world.get_node_or_null("CozyHeartforgeCamp") != null, "The Heartforge must receive an inhabited cozy camp layer.")
    _expect(world.get_node_or_null("UrbanAestheticPass") != null, "The ruined city must receive the urban storytelling pass.")

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
        _expect(player.get_node_or_null("MechromancerPresentation3D") is MechromancerPresentation3D, "The Mechromancer must receive authored animation presentation.")
        _expect(_find_named(player, "ProductionAssetMarker") != null, "The Mechromancer must use the authored asset contract.")
        _expect(_find_named(player, "PistolMuzzle") != null, "The authored Mechromancer must expose the pistol muzzle socket.")
        _expect(_model_has_details(player), "The Mechromancer must receive additional authored silhouette detail.")

    var robots := get_nodes_in_group("friendly_robots")
    _expect(not robots.is_empty(), "The opening companion must exist.")
    if not robots.is_empty():
        var robot := robots[0] as Node3D
        _expect(robot.get_node_or_null("ProceduralAnimator3D") is ProceduralAnimator3D, "Robots must receive procedural gait and recoil animation.")
        _expect(_model_has_details(robot), "Robots must receive additional role-readable detail.")

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
