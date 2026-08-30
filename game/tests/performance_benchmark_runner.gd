extends SceneTree

## Deterministic release-population benchmark.
##
## This does not set a machine-specific pass/fail FPS target. It records the
## real release scene's population split and wall-clock simulation cost so a
## target-hardware run can be compared without changing gameplay budgets.

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")
const ORGANIC_SPECIES: Array[StringName] = [
    &"veilstalker", &"razorhound", &"apex", &"sporecaster", &"broodmass", &"burrower",
    &"skitterling", &"roofleaper", &"glassmoth", &"miremaw", &"carrionbell", &"rootweaver",
]
const ROBOT_ARCHETYPES: Array[StringName] = [&"guardian", &"salvager", &"scout", &"engineer", &"relay"]
const ACTOR_PAIRS := 96
const WARMUP_FRAMES := 15
const SAMPLE_FRAMES := 90

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_benchmark")


func _run_benchmark() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightReleaseWorld3D
    world.pending_launch_mode = &"new"
    root.add_child(world)
    for _index in range(8):
        await process_frame
    await physics_frame

    _expect(world != null and world.performance_director != null, "Benchmark must boot the release performance director.")
    if world == null or world.performance_director == null:
        _finish()
        return
    _expect(await world._await_enemy_tier_bootstrap_initialized(), "Benchmark must initialize canonical ecology before spawning its tier-brained population.")

    for index in range(ACTOR_PAIRS):
        var band := index % 4
        var distance := 18.0 if band == 0 else (86.0 if band == 1 else (140.0 if band == 2 else 260.0))
        var angle := float(index) * 0.67
        var anchor := world.player.global_position + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
        world._spawn_enemy(anchor, ORGANIC_SPECIES[index % ORGANIC_SPECIES.size()])
        world._spawn_robot(ROBOT_ARCHETYPES[index % ROBOT_ARCHETYPES.size()], anchor + Vector3(2.0, 0.0, 1.5), 1)

    for _index in range(WARMUP_FRAMES):
        await process_frame
    world.spatial_index.rebuild()
    world.performance_director.force_evaluate_for_test()
    var warm_snapshot := world.performance_director.snapshot()

    var started_usec := Time.get_ticks_usec()
    for _index in range(SAMPLE_FRAMES):
        await process_frame
    var elapsed_seconds := float(Time.get_ticks_usec() - started_usec) / 1000000.0
    world.performance_director.force_evaluate_for_test()
    var snapshot := world.performance_director.snapshot()
    var simulation_fps := float(SAMPLE_FRAMES) / maxf(0.001, elapsed_seconds)
    var draw_calls := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
    var rendered_primitives := int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
    var visible_mesh_instances := _count_visible_mesh_instances(world)
    var visible_actor_mesh_instances := _count_visible_actor_mesh_instances()
    var report := {
        "schema_version": 1,
        "actor_pairs": ACTOR_PAIRS,
        "total_actors": ACTOR_PAIRS * 2,
        "warmup_frames": WARMUP_FRAMES,
        "sample_frames": SAMPLE_FRAMES,
        "elapsed_seconds": snappedf(elapsed_seconds, 0.001),
        "simulation_fps": snappedf(simulation_fps, 0.01),
        "simulation_ms_per_frame": snappedf(elapsed_seconds * 1000.0 / float(SAMPLE_FRAMES), 0.01),
        "draw_calls_last_frame": draw_calls,
        "rendered_primitives_last_frame": rendered_primitives,
        "visible_mesh_instances": visible_mesh_instances,
        "visible_actor_mesh_instances": visible_actor_mesh_instances,
        "candidate_count": int(snapshot.get("candidate_count", 0)),
        "sorted_candidate_count": int(snapshot.get("sorted_candidate_count", 0)),
        "warmup_candidate_count": int(warm_snapshot.get("candidate_count", 0)),
        "warmup_sorted_candidate_count": int(warm_snapshot.get("sorted_candidate_count", 0)),
        "active_entities": int(snapshot.get("active_entities", 0)),
        "active_visual_entities": int(snapshot.get("active_visual_entities", 0)),
        "medium_entities": int(snapshot.get("medium_entities", 0)),
        "reduced_entities": int(snapshot.get("reduced_entities", 0)),
        "active_entity_budget": world.performance_director.active_entity_budget,
        "active_authored_visual_budget": int(snapshot.get("active_authored_visual_budget", 0)),
        "medium_entity_budget": world.performance_director.medium_entity_budget,
        "warmup_snapshot": warm_snapshot,
        "status": "pass" if failures.is_empty() else "fail",
    }
    _expect(report["warmup_candidate_count"] >= ACTOR_PAIRS * 2, "Benchmark warmup must register the complete actor population.")
    _expect(report["active_entities"] <= report["active_entity_budget"], "Benchmark must respect the active actor budget.")
    _expect(report["active_visual_entities"] <= report["active_authored_visual_budget"], "Benchmark must respect the active authored-visual budget.")
    _expect(report["medium_entities"] <= report["medium_entity_budget"], "Benchmark must respect the medium actor budget.")
    _expect(report["reduced_entities"] >= 64, "Benchmark must preserve a substantial reduced-detail population.")
    _expect(report["sorted_candidate_count"] < report["candidate_count"], "Benchmark must avoid sorting distant actors.")
    report["status"] = "pass" if failures.is_empty() else "fail"
    print("PERFORMANCE_BENCHMARK_JSON " + JSON.stringify(report))

    world.queue_free()
    await process_frame
    _finish()


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)


func _count_visible_mesh_instances(node: Node) -> int:
    var count := 0
    if node is MeshInstance3D and (node as MeshInstance3D).is_visible_in_tree():
        count += 1
    for child in node.get_children():
        count += _count_visible_mesh_instances(child)
    return count


func _count_visible_actor_mesh_instances() -> int:
    var count := 0
    for group_name in [&"organic_enemies", &"friendly_robots"]:
        for raw_actor in get_nodes_in_group(group_name):
            if is_instance_valid(raw_actor):
                count += _count_visible_mesh_instances(raw_actor)
    return count


func _finish() -> void:
    if failures.is_empty():
        print("Project Ironwright release population benchmark passed.")
        quit(0)
    else:
        print("Project Ironwright release population benchmark failed: %d" % failures.size())
        quit(1)
