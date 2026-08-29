extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")
const ORGANIC_SPECIES: Array[StringName] = [
    &"veilstalker", &"razorhound", &"apex", &"sporecaster", &"broodmass", &"burrower",
    &"skitterling", &"roofleaper", &"glassmoth", &"miremaw", &"carrionbell", &"rootweaver",
]
const ROBOT_ARCHETYPES: Array[StringName] = [&"guardian", &"salvager", &"scout", &"engineer", &"relay"]

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightReleaseWorld3D
    root.add_child(world)
    for _index in range(8):
        await process_frame
    await physics_frame

    _expect(world != null and world.performance_director != null, "The stress scenario must boot the release performance director.")
    if world == null or world.performance_director == null:
        _finish()
        return

    var actors: Array[Node] = []
    for index in range(96):
        var band := index % 4
        var distance := 18.0 if band == 0 else (86.0 if band == 1 else (140.0 if band == 2 else 260.0))
        var angle := float(index) * 0.67
        var anchor := world.player.global_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
        var enemy := world._spawn_enemy(anchor, ORGANIC_SPECIES[index % ORGANIC_SPECIES.size()]) as OrganicEnemyRelease3D
        var robot := world._spawn_robot(ROBOT_ARCHETYPES[index % ROBOT_ARCHETYPES.size()], anchor + Vector3(2.0, 0.0, 1.5), 1) as RobotUnitRelease3D
        actors.append(enemy)
        actors.append(robot)

    await process_frame
    await process_frame
    world.spatial_index.rebuild()
    world.performance_director.force_evaluate_for_test()
    var snapshot := world.performance_director.snapshot()
    _expect(int(snapshot.get("active_entities", 0)) <= world.performance_director.active_entity_budget, "Large populations must respect the active actor budget.")
    _expect(int(snapshot.get("medium_entities", 0)) <= world.performance_director.medium_entity_budget, "Large populations must respect the medium actor budget.")
    _expect(int(snapshot.get("reduced_entities", 0)) >= 64, "Large populations must place distant actors into reduced-detail simulation.")
    _expect(int(snapshot.get("candidate_count", 0)) >= 192, "The stress population must register every spawned actor with the detail director.")
    _expect(int(snapshot.get("sorted_candidate_count", 0)) < int(snapshot.get("candidate_count", 0)), "Large populations must sort only the medium-detail neighborhood instead of every distant actor.")
    _expect(int(snapshot.get("active_shadow_casters", 0)) <= int(snapshot.get("active_shadow_caster_budget", 0)), "Large populations must cap expensive actor shadow casters without changing authored model detail.")

    var near_enemy := actors[0] as OrganicEnemyRelease3D
    var near_robot := actors[1] as RobotUnitRelease3D
    var medium_enemy := actors[2] as OrganicEnemyRelease3D
    var medium_robot := actors[3] as RobotUnitRelease3D
    var far_enemy := actors[46] as OrganicEnemyRelease3D
    var far_robot := actors[47] as RobotUnitRelease3D
    _expect(near_enemy != null and near_enemy.get_node_or_null("OrganicModel") != null, "A nearby organic actor must retain its authored presentation shell.")
    _expect(near_robot != null and near_robot.get_node_or_null("RobotModel") != null, "A nearby machine actor must retain its authored presentation shell.")
    _expect(near_enemy != null and _tier_brain_is_sole_movement_authority(near_enemy, true), "An active tiered organic actor must use its tier brain as the sole movement authority.")
    _expect(medium_enemy != null and medium_enemy.get_node_or_null("OrganicModel") == null and medium_enemy.get_node_or_null("DeferredVisualProxy") != null, "A medium-distance organic actor must remain on a lightweight proxy until active promotion.")
    _expect(medium_robot != null and medium_robot.get_node_or_null("RobotModel") == null and medium_robot.get_node_or_null("DeferredVisualProxy") != null, "A medium-distance machine actor must remain on a lightweight proxy until active promotion.")
    _expect(medium_enemy != null and _tier_brain_is_sole_movement_authority(medium_enemy, false), "A medium-distance tiered organic actor must suspend both legacy and tier-brain physics callbacks while coarse simulation is scheduled.")
    _expect(medium_enemy != null and not _presentation_controller_processing(medium_enemy), "A medium-distance organic actor must suspend presentation-only controller ticks while its proxy is active.")
    _expect(medium_robot != null and not _presentation_controller_processing(medium_robot), "A medium-distance machine actor must suspend presentation-only controller ticks while its proxy is active.")
    _expect(far_enemy != null and far_enemy.get_node_or_null("OrganicModel") == null and far_enemy.get_node_or_null("DeferredVisualProxy") != null, "A distant organic actor must begin with only a lightweight deferred proxy.")
    _expect(far_robot != null and far_robot.get_node_or_null("RobotModel") == null and far_robot.get_node_or_null("DeferredVisualProxy") != null, "A distant machine actor must begin with only a lightweight deferred proxy.")
    var medium_enemy_proxy := medium_enemy.get_node_or_null("DeferredVisualProxy/ReducedDetailProxy") as MeshInstance3D if medium_enemy != null else null
    var far_enemy_proxy := far_enemy.get_node_or_null("DeferredVisualProxy/ReducedDetailProxy") as MeshInstance3D if far_enemy != null else null
    var medium_robot_proxy := medium_robot.get_node_or_null("DeferredVisualProxy/ReducedDetailProxy") as MeshInstance3D if medium_robot != null else null
    var far_robot_proxy := far_robot.get_node_or_null("DeferredVisualProxy/ReducedDetailProxy") as MeshInstance3D if far_robot != null else null
    _expect(medium_enemy_proxy != null and far_enemy_proxy != null and medium_enemy_proxy.mesh == far_enemy_proxy.mesh, "Organic reduced-detail actors must share one proxy mesh resource.")
    _expect(medium_robot_proxy != null and far_robot_proxy != null and medium_robot_proxy.mesh == far_robot_proxy.mesh, "Machine reduced-detail actors must share one proxy mesh resource.")
    _expect(far_enemy != null and far_enemy.reduced_detail and far_enemy.visual_lod_level == 2, "A distant organic actor must retain reduced-detail state at scale.")
    _expect(far_robot != null and far_robot.reduced_detail and far_robot.visual_lod_level == 2, "A distant machine actor must retain reduced-detail state at scale.")
    _expect(far_enemy != null and _tier_brain_is_sole_movement_authority(far_enemy, false), "A distant tiered organic actor must suspend both legacy and tier-brain physics callbacks while reduced simulation is scheduled.")
    if far_enemy != null and far_robot != null:
        var far_enemy_position := far_enemy.global_position
        var far_robot_position := far_robot.global_position
        world.performance_director.active_entity_budget = 96
        world.performance_director.medium_entity_budget = 128
        far_enemy.global_position = world.player.global_position + Vector3(8.0, 0.0, 0.0)
        far_robot.global_position = world.player.global_position + Vector3(10.0, 0.0, 0.0)
        world.spatial_index.rebuild()
        world.performance_director.force_evaluate_for_test()
        _expect(far_enemy.get_node_or_null("OrganicModel") != null, "Promoting a deferred organic actor to active detail must materialize its authored presentation shell.")
        _expect(far_robot.get_node_or_null("RobotModel") != null, "Promoting a deferred machine actor to active detail must materialize its authored presentation shell.")
        _expect(_presentation_controller_processing(far_enemy), "Promoting an organic actor to active detail must resume presentation-only controller ticks.")
        _expect(_presentation_controller_processing(far_robot), "Promoting a machine actor to active detail must resume presentation-only controller ticks.")
        far_enemy.global_position = far_enemy_position
        far_robot.global_position = far_robot_position
        world.spatial_index.rebuild()
        world.performance_director.force_evaluate_for_test()
    if far_enemy != null:
        var enemy_before := far_enemy.global_position
        if far_robot != null:
            far_robot.global_position = enemy_before + Vector3(40.0, 0.0, 0.0)
        far_enemy.investigate_position = enemy_before + Vector3(12.0, 0.0, 4.0)
        far_enemy.investigate_seconds = 5.0
        far_enemy.reduced_detail_tick(1.0)
        _expect(far_enemy.global_position.distance_to(enemy_before) > 0.01, "Distant organic actors must continue causal movement under reduced detail.")
    if far_robot != null:
        var robot_before := far_robot.global_position
        far_robot.current_target = null
        far_robot.has_goal = true
        far_robot.goal_position = robot_before + Vector3(10.0, 0.0, 3.0)
        far_robot.reduced_detail_tick(1.0)
        _expect(far_robot.global_position.distance_to(robot_before) > 0.01, "Distant machine actors must continue causal movement under reduced detail.")

    for actor in actors:
        if actor != null and is_instance_valid(actor):
            actor.queue_free()
    await process_frame
    world.queue_free()
    await process_frame
    _finish()


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)


func _presentation_controller_processing(actor: Node) -> bool:
    for child_name in [&"ProceduralAnimator3D", &"AuthoredActorAnimation3D", &"ReleaseSecondaryMotion3D"]:
        var controller := actor.get_node_or_null(NodePath(String(child_name)))
        if controller != null and controller.has_method(&"is_processing") and bool(controller.call(&"is_processing")):
            return true
    return false


func _tier_brain_is_sole_movement_authority(actor: Node, brain_active: bool) -> bool:
    if actor == null or not is_instance_valid(actor):
        return false
    var brain := actor.get_node_or_null("EnemyTierBrain")
    if brain == null:
        return false
    return not actor.is_physics_processing() and bool(brain.is_physics_processing()) == brain_active


func _finish() -> void:
    if failures.is_empty():
        print("Project Ironwright large-population performance tests passed.")
        quit(0)
    else:
        print("Project Ironwright large-population performance tests failed: %d" % failures.size())
        quit(1)
