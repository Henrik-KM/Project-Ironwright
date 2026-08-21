extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")
const ORGANIC_SPECIES: Array[StringName] = [
    &"veilstalker", &"razorhound", &"apex", &"sporecaster", &"broodmass", &"burrower",
    &"skitterling", &"roofleaper", &"glassmoth", &"miremaw", &"carrionbell", &"rootweaver",
]
const ROBOT_ARCHETYPES: Array[StringName] = [&"guardian", &"salvager", &"scout", &"engineer"]

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
    for index in range(24):
        var band := index % 3
        var distance := 18.0 if band == 0 else (86.0 if band == 1 else 260.0)
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
    _expect(int(snapshot.get("reduced_entities", 0)) >= 16, "Large populations must place distant actors into reduced-detail simulation.")

    var far_enemy := actors[46] as OrganicEnemyRelease3D
    var far_robot := actors[47] as RobotUnitRelease3D
    _expect(far_enemy != null and far_enemy.reduced_detail and far_enemy.visual_lod_level == 2, "A distant organic actor must retain reduced-detail state at scale.")
    _expect(far_robot != null and far_robot.reduced_detail and far_robot.visual_lod_level == 2, "A distant machine actor must retain reduced-detail state at scale.")
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


func _finish() -> void:
    if failures.is_empty():
        print("Project Ironwright large-population performance tests passed.")
        quit(0)
    else:
        print("Project Ironwright large-population performance tests failed: %d" % failures.size())
        quit(1)
