extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")
const REGION_SCRIPT := preload("res://scripts/world/region_landmark_3d.gd")
const GUIDANCE_SCRIPT := preload("res://scripts/presentation/objective_guidance_3d.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    await _test_remote_ground_continuity()
    await _test_directional_camera_reframe()
    await _test_threat_camera_readability()
    await _test_salvage_escort_split()
    await _test_world_labels_are_not_screen_fixed()
    await _test_prealpha_hud_is_quiet()

    if failures.is_empty():
        print("Project Ironwright presentation reset and salvage escort tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Project Ironwright presentation reset and salvage escort tests failed: %d" % failures.size())
    quit(1)


func _test_remote_ground_continuity() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightReleaseWorld3D
    root.add_child(world)
    await process_frame
    await physics_frame
    world.player.global_position = Vector3(-92.0, 0.8, 18.0)
    for _step in range(90):
        await physics_frame
    _expect(world.player.is_on_floor(), "The Mechromancer must remain grounded when entering a remote region beyond the city collision floor.")
    _expect(world.player.global_position.y > -0.1, "Remote-region ground continuity must prevent the Mechromancer from falling through the persistent world.")
    var remote_landmark := world.region_director.get_landmark(&"region.west_grid")
    _expect(remote_landmark != null and remote_landmark.get_node_or_null("PersistentRegionCollision/PersistentRegionGround") != null, "Remote regions must own a persistent ground collision shape outside the authored city floor.")
    world.free()
    await process_frame


func _test_directional_camera_reframe() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightReleaseWorld3D
    root.add_child(world)
    await process_frame
    await physics_frame
    world.player.input_enabled = false
    world.camera_heading = Vector3(0.0, 0.0, 1.0)
    world.camera_target_velocity = Vector3.ZERO
    world.player.velocity = Vector3(5.0, 0.0, 0.0)
    world._update_camera(0.65)
    _expect(world.camera_heading.x < -0.5, "The tactical camera must move behind the player's travel direction so east/west routes stay in view.")
    _expect(world._is_remote_camera_context(Vector3(-92.0, 0.0, 18.0)), "A remote district must opt into the wider tactical composition.")
    _expect(not world._is_remote_camera_context(Vector3.ZERO), "The Heartforge opening must retain its close tactical composition.")
    var remote_expansion := world._remote_camera_expansion()
    _expect(remote_expansion.x >= 4.0 and remote_expansion.x <= 6.0 and remote_expansion.y >= 5.0 and remote_expansion.y <= 7.0, "Remote camera widening must preserve district breadth without dropping the expedition cast out of the tactical frame.")
    var heading_after_motion := world.camera_heading
    world.player.velocity = Vector3.ZERO
    world._update_camera(0.65)
    _expect(world.camera_heading.distance_to(heading_after_motion) < 0.05, "The tactical camera must hold its established heading when the player stops instead of rotating during idle play.")
    world.free()
    await process_frame


func _test_threat_camera_readability() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightReleaseWorld3D
    root.add_child(world)
    await process_frame
    await physics_frame
    var enemy := world._spawn_enemy(world.player.global_position + Vector3(3.0, 0.0, 0.0), &"sporecaster")
    await physics_frame
    var bias := world._nearby_threat_camera_bias(world.player.global_position)
    _expect(bias.y > 0.0, "Nearby threats must raise the tactical camera enough to preserve the defensive envelope.")
    _expect(bias.z <= 0.0, "Nearby threats must not pull the tactical camera farther away from readable organic silhouettes.")
    if enemy != null and is_instance_valid(enemy):
        enemy.queue_free()
    world.free()
    await process_frame


func _test_salvage_escort_split() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightReleaseWorld3D
    root.add_child(world)
    await process_frame
    await physics_frame

    for enemy in get_nodes_in_group(&"organic_enemies"):
        if is_instance_valid(enemy):
            enemy.free()
    await process_frame

    world._spawn_robot(&"salvager", Vector3(0.0, 0.0, 4.0), 1)
    for index in range(4):
        world._spawn_robot(&"guardian", Vector3(-2.0 + float(index) * 1.3, 0.0, 5.0), 1)
    await physics_frame

    world.run_state.set_focus(RunState3D.FOCUS_SALVAGE)
    world.autonomy_director._refresh_macro_assignments()
    var near_snapshot := world.autonomy_director.salvage_coverage_snapshot()
    _expect(bool(near_snapshot.get("active", false)), "Salvage focus with a Scrapper must start a physical salvage operation.")
    _expect(int(near_snapshot.get("salvage_guardians", 0)) == 4, "When the Mechromancer is close, all four Wardens should form broad salvage coverage because the Bulwark already provides personal interception.")
    _expect(int(near_snapshot.get("player_guardians", 0)) == 0, "Wardens should not crowd the Mechromancer when the salvage perimeter already covers both groups.")
    _expect(bool(near_snapshot.get("bulwark_personal_guard", false)), "The Bulwark must remain the guaranteed personal guard during salvage focus.")

    var salvage_guardians := world.autonomy_director._salvage_guardians(&"salvage_guardians")
    _expect(salvage_guardians.size() == 4, "All four Wardens must be represented in the salvage coverage assignment.")
    var min_x := INF
    var max_x := -INF
    var min_z := INF
    var max_z := -INF
    for guardian in salvage_guardians:
        _expect(guardian.assigned_group == &"salvage_escort", "Salvage-cover Wardens must be assigned to the salvage_escort group.")
        min_x = minf(min_x, guardian.goal_position.x)
        max_x = maxf(max_x, guardian.goal_position.x)
        min_z = minf(min_z, guardian.goal_position.z)
        max_z = maxf(max_z, guardian.goal_position.z)
    _expect(max_x - min_x >= 7.0, "Salvage Wardens must spread across both flanks instead of stacking on one side.")
    _expect(max_z - min_z >= 7.0, "Salvage Wardens must cover front and rear approaches instead of forming a narrow line.")

    world.player.global_position = Vector3(32.0, 0.0, 30.0)
    world.autonomy_director._refresh_macro_assignments()
    var split_snapshot := world.autonomy_director.salvage_coverage_snapshot()
    var salvage_count := int(split_snapshot.get("salvage_guardians", 0))
    var player_count := int(split_snapshot.get("player_guardians", 0))
    _expect(salvage_count >= 1, "The vulnerable Scrappers must never lose all Warden coverage when the player moves away.")
    _expect(player_count >= 1, "Wardens must automatically peel off to protect a distant Mechromancer.")
    _expect(salvage_count + player_count == 4, "Every available Warden should contribute to salvage-mode protection rather than idling at the Heartforge.")

    for guardian in world.autonomy_director._salvage_guardians(&"player_guardians"):
        _expect(guardian.assigned_group == &"mechromancer_escort", "Player-cover Wardens must use the Mechromancer escort assignment.")
        _expect(guardian.goal_position.distance_to(world.player.global_position) <= 5.0, "Player-cover Wardens must occupy a useful protective radius around the Mechromancer.")

    _expect(world.autonomy_director.operation_summary().to_lower().contains("escort"), "The permanent operation summary must communicate the distributed escort state.")
    world.free()
    await process_frame


func _test_world_labels_are_not_screen_fixed() -> void:
    var guidance := GUIDANCE_SCRIPT.new() as ObjectiveGuidance3D
    var dummy_player := Node3D.new()
    root.add_child(dummy_player)
    guidance.configure(dummy_player)
    root.add_child(guidance)
    await process_frame
    _expect(guidance.marker_label != null, "Objective guidance must build a world label.")
    _expect(not guidance.marker_label.fixed_size, "Objective guidance text must use physical world scale instead of giant fixed screen size.")
    _expect(guidance.marker_label.font_size <= 24, "Objective world labels must remain visually restrained.")
    _expect(guidance.marker_label.position.y <= 3.0 and guidance.get_node("ObjectiveBeacon/BeaconCrown").position.y <= 2.5, "Objective guidance must keep its physical beacon compact enough to avoid becoming a screen-dominating vertical bar.")
    _expect(guidance.get_node_or_null("ObjectiveBeacon/BeaconStem") != null and guidance.get_node_or_null("ObjectiveBeacon/BeaconCrown") != null, "Opening objective guidance must retain a physical beacon mast and crown above local occlusion.")
    _expect(guidance.get_node_or_null("ObjectiveBeacon/BeaconSignalRing") != null, "Opening objective guidance must expose a bounded signal ring so the salvage target remains legible in the tactical composition.")
    guidance.free()
    dummy_player.free()

    var landmark := REGION_SCRIPT.new() as RegionLandmark3D
    landmark.configure({
        "id": "region.test",
        "display_name": "Test District",
        "kind": "industrial",
        "center": [0.0, 0.0, 0.0],
        "radius": 20.0,
        "initially_discovered": true,
        "base_pressure": 0.5,
    })
    root.add_child(landmark)
    await process_frame
    # Close-detail inspection is an explicit focus promotion now that authored
    # packages are released while a district is outside the stream ring.
    landmark.set_streamed_in(true)
    _expect(landmark._label != null and not landmark._label.fixed_size, "District labels must not be fixed-size screen billboards.")
    _expect(not landmark._label.visible, "District names must stay out of the tactical view by default.")
    _expect(landmark.find_child("WestGridTurbineHall", true, false) != null, "West Grid must retain a readable authored industrial structural shell.")
    _expect(landmark.find_child("WestGridRoofCap", true, false) != null, "West Grid must retain a high-definition roof break instead of a single flat cube.")
    _expect(landmark.find_child("WestGridWindow0", true, false) != null, "West Grid windows need layered industrial signal detail at tactical distance.")
    landmark.set_map_emphasis(true)
    _expect(landmark._label.visible, "District names should appear when the player deliberately enters command-map mode.")
    landmark.free()

    for kind in [&"archive", &"tenement", &"greenhouse", &"waterfront", &"rail", &"observatory"]:
        var identity_landmark := REGION_SCRIPT.new() as RegionLandmark3D
        identity_landmark.configure({
            "id": "region.%s.test" % String(kind),
            "display_name": "%s Test District" % String(kind).capitalize(),
            "kind": String(kind),
            "center": [60.0 + float(identity_landmark.get_instance_id() % 30), 0.0, 60.0],
            "radius": 20.0,
            "initially_discovered": true,
            "base_pressure": 0.8,
        })
        root.add_child(identity_landmark)
        await process_frame
        _expect(identity_landmark.get_node_or_null("PersistentRegionGeometry/%sIdentityDetails" % String(kind.capitalize())) != null, "%s regions must have an identity-specific landmark signature." % String(kind))
        identity_landmark.free()


func _test_prealpha_hud_is_quiet() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightReleaseWorld3D
    root.add_child(world)
    await process_frame
    var hud := world.hud as IronwrightPreAlphaHUD3D
    _expect(hud != null, "The main scene must use the quieter desktop pre-alpha HUD.")
    if hud != null:
        _expect(not hud.help_label.visible, "The duplicate permanent bottom control legend must be hidden.")
        var command_help := hud.root_control.get_node_or_null("CommandHelpPanel") as PanelContainer
        _expect(command_help != null and not command_help.visible, "The large permanent command-help dashboard must not occupy the tactical view.")
        var sanctuary := hud.root_control.get_node_or_null("SanctuaryBadge") as PanelContainer
        _expect(sanctuary != null and not sanctuary.visible, "Healthy-state sanctuary banners must stay hidden until they communicate an actual problem.")
    _expect(world.camera.fov <= 46.0, "The tactical camera should use the less distorted desktop framing from the presentation reset.")
    world.free()
    await process_frame


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
