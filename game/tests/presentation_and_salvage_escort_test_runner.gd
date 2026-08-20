extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")
const REGION_SCRIPT := preload("res://scripts/world/region_landmark_3d.gd")
const GUIDANCE_SCRIPT := preload("res://scripts/presentation/objective_guidance_3d.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
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


func _test_salvage_escort_split() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightPreAlphaWorld3D
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

    _expect("escort" in world.autonomy_director.operation_summary().to_lower(), "The permanent operation summary must communicate the distributed escort state.")
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
    _expect(landmark._label != null and not landmark._label.fixed_size, "District labels must not be fixed-size screen billboards.")
    _expect(not landmark._label.visible, "District names must stay out of the tactical view by default.")
    landmark.set_map_emphasis(true)
    _expect(landmark._label.visible, "District names should appear when the player deliberately enters command-map mode.")
    landmark.free()


func _test_prealpha_hud_is_quiet() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightPreAlphaWorld3D
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
