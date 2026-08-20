extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")
const ENEMY_SCENE := preload("res://scenes/actors/organic_enemy_3d.tscn")
const TEST_SAVE_PATH := "user://ironwright_autonomy_checkpoint_test.json"

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    await _test_distributed_scrapper_decisions()
    await _test_organic_ecology_behaviours()
    await _test_vertical_slice_presentation()

    if failures.is_empty():
        print("Project Ironwright intelligence and vertical-slice tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Project Ironwright intelligence and vertical-slice tests failed: %d" % failures.size())
    quit(1)


func _test_distributed_scrapper_decisions() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightPreAlphaWorld3D
    root.add_child(world)
    await process_frame
    await physics_frame

    for enemy in get_nodes_in_group(&"organic_enemies"):
        if is_instance_valid(enemy):
            enemy.free()
    await process_frame

    world._spawn_robot(&"salvager", Vector3(-1.2, 0.0, 4.0), 1)
    world._spawn_robot(&"salvager", Vector3(1.2, 0.0, 4.0), 1)
    world._spawn_robot(&"salvager", Vector3(0.0, 0.0, 5.2), 1)
    world._spawn_robot(&"guardian", Vector3(-2.2, 0.0, 4.4), 1)
    world._spawn_robot(&"guardian", Vector3(2.2, 0.0, 4.4), 1)
    await physics_frame

    world.run_state.set_focus(RunState3D.FOCUS_SALVAGE)
    world.autonomy_director._refresh_macro_assignments()
    var operation := world.autonomy_director.salvage_operation
    _expect(bool(operation.get("distributed", false)), "Salvage focus must create a distributed salvage network rather than one convoy target.")
    var assignments: Dictionary = operation.get("assignments", {})
    _expect(assignments.size() >= 3, "Every available Scrapper should receive its own autonomous salvage assignment.")

    var targets: Array[Node] = []
    for raw_assignment in assignments.values():
        if not (raw_assignment is Dictionary):
            continue
        var target: Node = (raw_assignment as Dictionary).get("target")
        if target != null:
            targets.append(target)
    var unique_target_ids: Dictionary = {}
    for target in targets:
        unique_target_ids[target.get_instance_id()] = true
    _expect(targets.size() >= 3, "Three available Scrappers should find three useful wrecks when the world contains enough salvage.")
    _expect(unique_target_ids.size() == targets.size(), "Scrappers must not dog-pile the same wreck; target reservations should be unique while enough sites exist.")

    var snapshot := world.autonomy_director.salvage_coverage_snapshot()
    _expect(int(snapshot.get("scrappers", 0)) >= 3, "Salvage coverage must report the distributed Scrapper population.")
    _expect(int(snapshot.get("active_sites", 0)) >= 2, "The salvage network should span more than one physical site.")
    _expect("sites" in world.autonomy_director.operation_summary().to_lower(), "The operation summary must communicate that salvage is distributed over several sites.")

    world.save_service.configure(TEST_SAVE_PATH)
    world._save_game()
    _expect(FileAccess.file_exists(TEST_SAVE_PATH), "The save hook must write while distributed salvage is active.")
    world._load_game()
    var restored_operation: Dictionary = world.autonomy_director.salvage_operation
    _expect(bool(restored_operation.get("distributed", false)), "Loading must restore the distributed salvage network.")
    _expect((restored_operation.get("assignments", {}) as Dictionary).size() >= 3, "Loading must restore each Scrapper assignment.")

    assignments = restored_operation.get("assignments", {})
    var first_assignment: Dictionary = assignments.values()[0]
    var first_robot: RobotUnit3D = first_assignment.get("robot")
    var first_target: SalvagePile3D = first_assignment.get("target")
    if first_target != null:
        first_target.extract_for_robot(first_target.remaining_scrap)
    world.autonomy_director._update_operation(world.autonomy_director.salvage_operation, 0.25)
    var replanned: Dictionary = world.autonomy_director.salvage_operation.get("assignments", {}).get(str(first_robot.get_instance_id()), {})
    _expect(StringName(str(replanned.get("state", "idle"))) in [&"outbound", &"working", &"returning", &"idle"], "A depleted site must transition through a valid autonomous re-plan state.")
    if replanned.get("target") != null:
        _expect(replanned.get("target") != first_target, "A depleted wreck may not remain the Scrapper's active target.")

    world.free()
    _cleanup_save_files()
    await process_frame


func _test_organic_ecology_behaviours() -> void:
    var forge := Node3D.new()
    forge.name = "DummyForge"
    forge.position = Vector3.ZERO
    root.add_child(forge)

    var patrol := ENEMY_SCENE.instantiate() as OrganicEnemy3D
    patrol.configure(&"burrower", null, forge)
    patrol.position = Vector3(18.0, 0.0, 18.0)
    patrol.configure_ecology(Vector3(18.0, 0.0, 18.0), 12.0, &"patrol")
    root.add_child(patrol)
    await physics_frame
    var patrol_start := patrol.global_position
    for index in range(30):
        await physics_frame
    _expect(patrol.state_name in [&"patrolling", &"investigating", &"hunting"], "A territorial Burrower should actively patrol instead of idling indefinitely.")
    _expect(patrol.global_position.distance_to(patrol_start) > 0.1, "Patrolling organisms should physically move around their territory without player provocation.")

    var guard := ENEMY_SCENE.instantiate() as OrganicEnemy3D
    guard.configure(&"sporecaster", null, forge)
    guard.position = Vector3(-18.0, 0.0, -18.0)
    guard.configure_ecology(Vector3(-18.0, 0.0, -18.0), 9.0, &"protect_nest")
    root.add_child(guard)
    await physics_frame
    _expect(guard.ecology_directive == &"protect_nest", "Nest organisms need an explicit territorial protection role.")
    _expect(guard.behaviour_target.distance_to(guard.territory_origin) <= guard.territory_radius * 1.05, "Nest guards should patrol their nest envelope rather than wander arbitrarily across the map.")

    var scout := ENEMY_SCENE.instantiate() as OrganicEnemy3D
    scout.configure(&"veilstalker", null, forge)
    scout.position = Vector3(34.0, 0.0, -20.0)
    scout.configure_ecology(Vector3(34.0, 0.0, -20.0), 14.0, &"scout")
    root.add_child(scout)
    await physics_frame
    _expect(scout.state_name == &"scouting", "Veilstalker scouting behaviour should generate proactive excursions.")
    _expect(scout.behaviour_target.distance_to(scout.territory_origin) > 3.0, "Scouts should move beyond the nest center instead of hanging around their spawn point.")

    var pack_a := ENEMY_SCENE.instantiate() as OrganicEnemy3D
    var pack_b := ENEMY_SCENE.instantiate() as OrganicEnemy3D
    pack_a.configure(&"razorhound", null, forge)
    pack_b.configure(&"razorhound", null, forge)
    pack_a.position = Vector3(12.0, 0.0, 4.0)
    pack_b.position = Vector3(14.0, 0.0, 5.0)
    pack_a.configure_ecology(Vector3(20.0, 0.0, 10.0), 16.0, &"hunt")
    pack_b.configure_ecology(Vector3(20.0, 0.0, 10.0), 16.0, &"hunt")
    root.add_child(pack_a)
    root.add_child(pack_b)
    await physics_frame
    pack_a.hear_noise(Vector3(8.0, 0.0, 4.0), 20.0, 1.0, &"manual_salvage")
    _expect(pack_b.investigate_seconds > 0.0, "Razorhounds should share nearby prey/noise information as a hunting pack.")
    _expect(pack_b.state_name in [&"pack_hunt", &"investigating", &"hunting"], "Pack alerts should produce an active hunting response.")

    patrol.free()
    guard.free()
    scout.free()
    pack_a.free()
    pack_b.free()
    forge.free()
    await process_frame


func _test_vertical_slice_presentation() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightPreAlphaWorld3D
    root.add_child(world)
    await process_frame
    await process_frame
    await physics_frame

    _expect(world.vertical_slice != null, "The main world must install the serious Heartforge vertical presentation slice.")
    _expect(world.vertical_slice_actor_art != null, "The vertical slice must include the stronger opening actor silhouette pass.")
    _expect(world.camera.fov <= 44.0, "The representative tactical frame should use the tighter cinematic camera.")

    var slice_root := world.get_node_or_null("HeartforgeVerticalSlice") as Node3D
    _expect(slice_root != null, "The Heartforge vertical slice must build a dedicated environment root.")
    if slice_root != null:
        _expect(slice_root.find_child("HeartforgePlazaDetail", true, false) != null, "The opening plaza must contain detailed ground and drainage rather than a featureless polygon.")
        _expect(slice_root.find_child("ImprovisedSanctuaryPerimeter", true, false) != null, "The Heartforge must read as an improvised lived-in refuge.")
        _expect(slice_root.find_child("ForgeMaintenanceGantry", true, false) != null, "The Heartforge needs industrial maintenance structure around it.")
        _expect(slice_root.find_child("LocalRain", true, false) != null, "The representative slice should include weather for depth, motion and wet-surface context.")
        var visible_nests := slice_root.find_child("VisibleOrganicNests", true, false)
        _expect(visible_nests != null and visible_nests.get_child_count() >= 4, "Organic nests should exist visibly in the same world the creatures patrol and protect.")

    var city := _find_city(world)
    _expect(city != null, "The systemic city must remain present under the vertical presentation slice.")
    if city != null:
        var central := city.get_node_or_null("RuinedBuilding00")
        _expect(central != null and central.get_node_or_null("VerticalSliceFacade") != null, "The closest building blocks should use broken readable facades rather than giant opaque cubes.")
        if central != null:
            var shell := central.get_node_or_null("Shell") as MeshInstance3D
            _expect(shell != null and not shell.visible, "The old solid central-building shell must be hidden in the representative slice.")

    var player_art := world.player.get_node_or_null("MechromancerModel/VerticalSliceCharacterArt")
    var companion_art := world.companion.get_node_or_null("RobotModel/VerticalSliceMachineArt")
    var forge_art := world.heartforge.get_node_or_null("HeartforgeModel/VerticalSliceForgeArt")
    _expect(player_art != null, "The Mechromancer needs a layered field-mechanic silhouette in the vertical slice.")
    _expect(companion_art != null, "The Bulwark needs a heavier bespoke machine silhouette.")
    _expect(forge_art != null, "The Heartforge needs service pipework and industrial detail beyond the base primitive model.")

    var hud := world.hud as IronwrightPreAlphaHUD3D
    _expect(hud != null and hud.objective_panel.size.x <= 405.0, "The objective UI should be a restrained desktop overlay rather than a large mobile card.")
    _expect(hud != null and hud.notifications.size() <= IronwrightHUD3D.MAX_VISIBLE_NOTIFICATIONS, "Tactical notifications must remain bounded by the established readability contract.")

    world.free()
    await process_frame


func _find_city(node: Node) -> ProceduralCity3D:
    if node is ProceduralCity3D:
        return node as ProceduralCity3D
    for child in node.get_children():
        var found := _find_city(child)
        if found != null:
            return found
    return null


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _cleanup_save_files() -> void:
    for path in [TEST_SAVE_PATH, TEST_SAVE_PATH + ".bak1", TEST_SAVE_PATH + ".bak2", TEST_SAVE_PATH + ".tmp"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
