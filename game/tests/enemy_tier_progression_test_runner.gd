extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightTieredWorld3D
    root.add_child(world)
    for index in range(6):
        await process_frame
    await physics_frame

    _expect(world != null, "The main scene must boot the tiered ecological world.")
    if world == null:
        _finish()
        return

    var director := world.enemy_tier_director
    _expect(director is EnemyTierDirector3D, "The tiered world must install an EnemyTierDirector3D.")
    if director == null:
        _finish()
        return

    director.simulation_enabled = false
    director.materialization_enabled = false
    _test_configuration(director)
    _test_exact_saturation_transfer(director)
    _test_population_headroom(director)
    _test_recursive_transfer(director)
    _test_physical_nests(director)
    _test_progression_modifiers(world, director)
    await _test_physical_spawn_source(world, director)
    await _test_intelligence_progression(world, director)
    _test_command_map_intelligence(world, director)
    _test_persistence(world, director)

    world.queue_free()
    await process_frame
    _finish()


func _test_configuration(director: EnemyTierDirector3D) -> void:
    _expect(director.sorted_tiers() == [1, 2, 3, 4, 5], "The ecological ladder must contain exactly five ordered tiers.")
    _expect(is_equal_approx(director.saturation_transfer_factor, 0.1), "Saturation transfer must use the canonical 1/10 factor.")
    _expect(int(director.tier_state(1).get("cap", 0)) == 100, "Tier 1 must use the prototype cap of 100.")
    _expect(int(director.tier_state(2).get("cap", 0)) == 40, "Tier 2 must use the prototype cap of 40.")
    _expect(is_equal_approx(director.tier_1_growth_per_minute_per_minute, 1.0), "Tier-1 replenishment must initially grow by one unit/min per minute.")
    _expect(director.spawn_credit_cap <= 3.0, "Spawn credit must remain bounded and may not become a hidden army backlog.")


func _test_exact_saturation_transfer(director: EnemyTierDirector3D) -> void:
    director.clear_population_overrides_for_test()
    director.set_population_override_for_test(1, 100)
    director.set_population_override_for_test(2, 0)
    director.set_tier_rate_for_test(1, 10.0)
    director.set_tier_rate_for_test(2, 0.0)
    director.force_simulation_step_for_test(0.0)
    _expect(is_equal_approx(float(director.tier_state(1).get("replenishment_per_minute", -1.0)), 0.0), "A saturated tier must zero its own replenishment rate.")
    _expect(is_equal_approx(float(director.tier_state(2).get("replenishment_per_minute", 0.0)), 1.0), "Tier 1 at cap with 10/min must transfer exactly 1/min to Tier 2.")


func _test_population_headroom(director: EnemyTierDirector3D) -> void:
    director.set_population_override_for_test(1, 75)
    director.set_tier_rate_for_test(1, 10.0)
    director.set_tier_rate_for_test(2, 0.0)
    director.force_simulation_step_for_test(0.0)
    _expect(is_equal_approx(float(director.tier_state(1).get("replenishment_per_minute", 0.0)), 10.0), "Tier-1 casualties must create headroom and keep replenishment in Tier 1.")
    _expect(is_equal_approx(float(director.tier_state(2).get("replenishment_per_minute", 0.0)), 0.0), "No advanced-tier transfer may occur while the lower tier has population headroom.")


func _test_recursive_transfer(director: EnemyTierDirector3D) -> void:
    director.set_population_override_for_test(1, 0)
    director.set_population_override_for_test(2, 40)
    director.set_population_override_for_test(3, 0)
    director.set_tier_rate_for_test(1, 0.0)
    director.set_tier_rate_for_test(2, 2.0)
    director.set_tier_rate_for_test(3, 0.0)
    director.force_simulation_step_for_test(0.0)
    _expect(is_equal_approx(float(director.tier_state(2).get("replenishment_per_minute", -1.0)), 0.0), "Tier 2 must zero its rate when saturated.")
    _expect(is_equal_approx(float(director.tier_state(3).get("replenishment_per_minute", 0.0)), 0.2), "Tier 2 at cap with 2/min must transfer exactly 0.2/min to Tier 3.")


func _test_physical_nests(director: EnemyTierDirector3D) -> void:
    _expect(director.nests.size() >= 15, "The complete town must have physical local and regional brood sites.")
    var nest := director.nests[0]
    _expect(nest is OrganicNest3D and nest.is_alive(), "Enemy replenishment must have a living physical nest source.")
    var before_rate := 5.0
    var before_growth := director.tier_1_growth_per_minute_per_minute
    director.set_tier_rate_for_test(1, before_rate)
    nest.apply_damage(nest.maximum_health + 1.0)
    var after_rate := float(director.tier_state(1).get("replenishment_per_minute", before_rate))
    _expect(not nest.is_alive(), "A nest must be physically destructible.")
    _expect(after_rate < before_rate, "Destroying a nest must reduce long-term Tier-1 replenishment.")
    _expect(director.tier_1_growth_per_minute_per_minute < before_growth, "Destroying a nest must reduce Tier-1 replenishment growth when configured.")
    _expect(not nest.can_spawn_tier(1), "A destroyed nest may never produce another organism.")


func _test_progression_modifiers(world: IronwrightTieredWorld3D, director: EnemyTierDirector3D) -> void:
    director.set_tier_rate_for_test(1, 2.0)
    var before := float(director.tier_state(1).get("replenishment_per_minute", 0.0))
    var applied := world.enemy_tier_event_bridge.apply_event_for_test(&"operation", &"operation.flood_market_recovery")
    var after := float(director.tier_state(1).get("replenishment_per_minute", 0.0))
    _expect(applied and after > before, "A disruptive technology expedition must increase configured replenishment.")
    var second_application := world.enemy_tier_event_bridge.apply_event_for_test(&"operation", &"operation.flood_market_recovery")
    _expect(not second_application and is_equal_approx(float(director.tier_state(1).get("replenishment_per_minute", 0.0)), after), "A completed progression event may alter replenishment only once.")


func _test_physical_spawn_source(world: IronwrightTieredWorld3D, director: EnemyTierDirector3D) -> void:
    director.clear_population_overrides_for_test()
    for node in get_nodes_in_group(&"organic_enemies"):
        if node is OrganicEnemy3D and is_instance_valid(node):
            node.free()
    await process_frame
    director.materialization_enabled = true
    director.set_tier_rate_for_test(1, 0.0)
    var state: Dictionary = director.tier_states[1]
    state["spawn_credit"] = 1.0
    director.force_simulation_step_for_test(0.0)
    await process_frame
    var spawned: Array[OrganicEnemyTiered3D] = []
    for node in get_nodes_in_group(&"organic_enemies"):
        if node is OrganicEnemyTiered3D and is_instance_valid(node):
            spawned.append(node as OrganicEnemyTiered3D)
    _expect(spawned.size() == 1, "One unit of spawn credit must materialize one physical organism.")
    if not spawned.is_empty():
        var enemy := spawned[0]
        var nearest_nest_distance := INF
        for nest in director.nests:
            if is_instance_valid(nest) and nest.is_alive() and nest.can_spawn_tier(1):
                nearest_nest_distance = minf(nearest_nest_distance, enemy.global_position.distance_to(nest.global_position))
        _expect(nearest_nest_distance <= director.nest_spawn_radius_max + 0.25, "Every replenishment birth must appear beside a valid physical nest.")
        _expect(enemy.enemy_tier == 1, "Tier-1 credit must create a Tier-1 organism.")
    director.materialization_enabled = false


func _test_intelligence_progression(world: IronwrightTieredWorld3D, director: EnemyTierDirector3D) -> void:
    var origin := Vector3(180.0, 0.0, 180.0)
    var tier_one := world._spawn_enemy(origin, &"skitterling") as OrganicEnemyTiered3D
    tier_one.configure_tier(1, director.tier_config(1), true)
    tier_one.configure_ecology(origin, 24.0, &"hunt")
    var tier_one_speed := tier_one.move_speed
    var before_investigate := tier_one.investigate_seconds
    tier_one.hear_noise(origin + Vector3(3.0, 0.0, 0.0), 20.0, 1.0, &"test_noise")
    _expect(tier_one.enemy_tier == 1 and tier_one.ecology_directive == &"roam", "Tier 1 must ignore purposeful directives and remain feral roaming behavior.")
    _expect(is_equal_approx(tier_one.investigate_seconds, before_investigate), "Tier 1 must not purposefully investigate ordinary noise.")
    _expect(tier_one_speed < 3.5, "Tier 1 must be deliberately slow.")

    var tier_two := world._spawn_enemy(origin + Vector3(8.0, 0.0, 0.0), &"razorhound") as OrganicEnemyTiered3D
    tier_two.configure_tier(2, director.tier_config(2), true)
    tier_two.configure_ecology(origin, 24.0, &"scout")
    _expect(tier_two.enemy_tier == 2 and tier_two.ecology_directive in [&"protect_nest", &"patrol"], "Tier 2 must limit itself to territorial patrol or nest defence.")

    var tier_three := world._spawn_enemy(origin + Vector3(16.0, 0.0, 0.0), &"veilstalker") as OrganicEnemyTiered3D
    tier_three.configure_tier(3, director.tier_config(3), true)
    tier_three.configure_ecology(origin, 30.0, &"scout")
    tier_three.receive_pack_alert(origin + Vector3(5.0, 0.0, 0.0), 0.8)
    _expect(tier_three.enemy_tier == 3 and tier_three.ecology_directive in [&"scout", &"hunt"], "Tier 3 must support purposeful scouting or hunting.")
    _expect(tier_three.has_last_known_prey and tier_three.investigate_seconds > 0.0, "Tier 3 must remember and act on shared prey information.")

    var engineer := world._spawn_robot(&"engineer", origin + Vector3(26.0, 0.0, 0.0), 1)
    var tier_four := world._spawn_enemy(origin + Vector3(23.0, 0.0, 3.0), &"rootweaver") as OrganicEnemyTiered3D
    tier_four.configure_tier(4, director.tier_config(4), true)
    tier_four.configure_ecology(origin, 38.0, &"hunt")
    var strategic_target := tier_four._strategic_interest_target()
    _expect(strategic_target == engineer, "Tier 4 must deliberately prioritize a nearby Engineer as a strategic operational target.")

    var tier_five := world._spawn_enemy(origin + Vector3(30.0, 0.0, 0.0), &"apex") as OrganicEnemyTiered3D
    tier_five.configure_tier(5, director.tier_config(5), true)
    _expect(tier_five.enemy_tier == 5 and tier_five.tier_profile == &"apex", "Tier 5 must be represented as a distinct apex intelligence tier.")

    tier_one.queue_free()
    tier_two.queue_free()
    tier_three.queue_free()
    tier_four.queue_free()
    tier_five.queue_free()
    engineer.queue_free()
    await process_frame


func _test_command_map_intelligence(world: IronwrightTieredWorld3D, director: EnemyTierDirector3D) -> void:
    var snapshot := director.snapshot()
    world.enemy_tier_hud.set_snapshot(snapshot)
    world.enemy_tier_hud.set_map_visible(true)
    _expect(world.enemy_tier_hud.panel.visible, "Ecological intelligence must be available in command-map mode.")
    _expect("Highest confirmed tier" in world.enemy_tier_hud.summary_label.text, "The command map must summarize confirmed tier and trend without requiring a spreadsheet.")
    world.enemy_tier_hud.set_map_visible(false)
    _expect(not world.enemy_tier_hud.panel.visible, "Tier intelligence must not become permanent tactical HUD clutter.")


func _test_persistence(world: IronwrightTieredWorld3D, director: EnemyTierDirector3D) -> void:
    director.set_tier_rate_for_test(1, 6.75)
    director.set_tier_rate_for_test(3, 0.42)
    var saved := director.to_dictionary()
    var snapshot := world._collect_release_snapshot()
    var release: Dictionary = snapshot.get("release", {})
    _expect(release.has("enemy_tiers") and release.has("enemy_tier_events"), "The unified world save must contain tier and applied-event state.")
    director.set_tier_rate_for_test(1, 0.0)
    director.set_tier_rate_for_test(3, 0.0)
    director.restore_from_dictionary(saved)
    _expect(is_equal_approx(float(director.tier_state(1).get("replenishment_per_minute", 0.0)), 6.75), "Save restoration must preserve Tier-1 replenishment.")
    _expect(is_equal_approx(float(director.tier_state(3).get("replenishment_per_minute", 0.0)), 0.42), "Save restoration must preserve advanced-tier replenishment.")


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _finish() -> void:
    if failures.is_empty():
        print("Project Ironwright enemy tier progression tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Project Ironwright enemy tier progression tests failed: %d" % failures.size())
    quit(1)
