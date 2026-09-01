extends SceneTree

## Fresh-runtime integration gate for the canonical population-driven ecology.
##
## This deliberately uses the real release world, physical nest objects and
## canonical tier director. It does not call private test population setters:
## both cycles must materialize a real Tier-II organism from a living nest.

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")
const CYCLE_COUNT := 2

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightTieredWorld3D
    root.add_child(world)
    await process_frame
    await physics_frame
    await process_frame
    if world != null and world.has_method(&"_await_enemy_tier_bootstrap_initialized"):
        _expect(await world.call(&"_await_enemy_tier_bootstrap_initialized"), "Fresh ecology runtime bootstrap must finish initialization.")

    _expect(world != null, "Fresh ecology runtime must instantiate the tiered release world.")
    if world == null:
        _finish()
        return

    var director := get_first_node_in_group(&"enemy_tier_progression") as EnemyTierProgressionDirector3D
    _expect(director != null and director.enabled, "Fresh ecology runtime must bind the canonical tier director.")
    _expect(director != null and not director.nests.is_empty(), "Fresh ecology runtime must register physical nests.")
    if director == null or director.nests.is_empty():
        world.queue_free()
        await process_frame
        _finish()
        return

    var review_nest: Node3D
    for raw_nest in director.nests.values():
        if raw_nest is Node3D and is_instance_valid(raw_nest) and raw_nest.has_method(&"can_spawn_tier") and bool(raw_nest.call(&"can_spawn_tier", 2)):
            review_nest = raw_nest as Node3D
            break
    _expect(review_nest != null, "Fresh ecology runtime must expose a living nest compatible with Tier II.")
    if review_nest == null:
        world.queue_free()
        await process_frame
        _finish()
        return

    for cycle in range(CYCLE_COUNT):
        await _clear_spawned_tiered_enemies(director)
        director._reconcile_population()
        director.spawn_credit[2] = 1.0
        var target := review_nest.global_position + Vector3(0.0, 0.0, 4.0 + float(cycle))
        var enemy := director.request_causal_threat(target, &"burrower", &"ecology_runtime_integration", 2)
        _expect(enemy != null, "Ecology cycle %d must materialize a causal Tier-II organism." % (cycle + 1))
        if enemy == null:
            continue
        _expect(enemy.get_meta(&"enemy_tier", 0) == 2, "Ecology cycle %d organism must retain Tier II identity." % (cycle + 1))
        _expect(StringName(str(enemy.get_meta(&"home_nest_id", ""))) == StringName(str(review_nest.get("nest_id"))), "Ecology cycle %d organism must retain its physical home nest." % (cycle + 1))
        _expect((enemy as Node3D).global_position.distance_to(review_nest.global_position) > 0.1, "Ecology cycle %d organism must emerge at a physical nest offset." % (cycle + 1))
        _expect(float(director.spawn_credit.get(2, -1.0)) < 0.001, "Ecology cycle %d must consume exactly one bounded Tier-II birth credit." % (cycle + 1))

    await _clear_spawned_tiered_enemies(director)
    await process_frame
    world.queue_free()
    await process_frame
    _finish()


func _clear_spawned_tiered_enemies(director: EnemyTierProgressionDirector3D) -> void:
    for raw_enemy in get_nodes_in_group(&"organic_enemies"):
        if not is_instance_valid(raw_enemy) or raw_enemy.is_in_group(&"enemy_tier_nests"):
            continue
        if raw_enemy.get_meta(&"enemy_tier", 0) == 2:
            raw_enemy.queue_free()
    await process_frame
    director._reconcile_population()


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)


func _finish() -> void:
    if failures.is_empty():
        print("Project Ironwright fresh ecology runtime integration tests passed.")
        quit(0)
    else:
        print("Project Ironwright fresh ecology runtime integration tests failed: %d" % failures.size())
        quit(1)
