extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    await _test_fresh_ecology_review_startup()
    var world := MAIN_SCENE.instantiate() as IronwrightReleaseWorld3D
    _expect(world != null, "The ecology integration test must instantiate the release world.")
    if world == null:
        _finish()
        return

    world.pending_launch_mode = &"new"
    root.add_child(world)
    for _frame in range(10):
        await process_frame
    await physics_frame
    await _await_enemy_tier_bootstrap(world)

    var bootstrap := world.get_node_or_null("EnemyTierProgressionBootstrap") as EnemyTierProgressionBootstrap3D
    var canonical: EnemyTierProgressionDirector3D = bootstrap.director if bootstrap != null else null
    _expect(bootstrap != null and bootstrap.initialized, "The release scene must initialize its enemy-tier bootstrap.")
    _expect(canonical != null, "The release scene must install the canonical population director.")
    _expect(world.ecology_director != null, "The release scene must retain its local ecology director.")
    _expect(world.strategic_ecology_director != null, "The release scene must retain its strategic ecology director.")
    if bootstrap == null or canonical == null or world.ecology_director == null or world.strategic_ecology_director == null:
        await _clean_up(world)
        _finish()
        return

    _test_single_population_authority(canonical)
    await _test_command_map_camera_round_trip(world)
    await _test_single_command_map_hud(world, bootstrap)
    _test_birth_handoff(world)
    await _test_local_attention_process(world)
    await _test_strategic_state_process(world)
    await _test_physical_migration_without_birth(world, canonical)
    _test_canonical_caps(canonical)
    await _test_ecology_review_fixture(world, canonical)

    await _clean_up(world)
    _finish()


func _test_fresh_ecology_review_startup() -> void:
    var fresh_world := MAIN_SCENE.instantiate() as IronwrightTieredWorld3D
    _expect(fresh_world != null, "A fresh ecology review must instantiate the tiered production world.")
    if fresh_world == null:
        return
    fresh_world.pending_launch_mode = &"new"
    root.add_child(fresh_world)
    await fresh_world._start_ecology_runtime_review()

    var bootstrap := fresh_world.get_node_or_null("EnemyTierProgressionBootstrap") as EnemyTierProgressionBootstrap3D
    var canonical: EnemyTierProgressionDirector3D = bootstrap.director if bootstrap != null else null
    _expect(bootstrap != null and bootstrap.initialized, "A fresh ecology review must wait for the canonical bootstrap.")
    _expect(canonical != null and canonical.world_bound and not canonical.nests.is_empty(), "Bootstrap readiness must include the bound physical nest network.")
    if canonical != null:
        var nearest_compatible_distance := INF
        for raw_nest in canonical.nests.values():
            if raw_nest is Node3D and is_instance_valid(raw_nest) and raw_nest.has_method(&"can_spawn_tier") and bool(raw_nest.call(&"can_spawn_tier", 2)):
                nearest_compatible_distance = minf(nearest_compatible_distance, fresh_world.player.global_position.distance_to((raw_nest as Node3D).global_position))
        _expect(nearest_compatible_distance <= 16.0, "A fresh ecology review must stage beside a compatible physical nest after real bootstrap ordering.")
    await _clean_up(fresh_world)


func _await_enemy_tier_bootstrap(world: Node) -> void:
    for _attempt in range(600):
        var bootstrap := world.get_node_or_null("EnemyTierProgressionBootstrap") as EnemyTierProgressionBootstrap3D if world != null else null
        if bootstrap != null and bootstrap.initialized:
            return
        await create_timer(0.025, true, false, true).timeout
        await process_frame


func _test_single_population_authority(canonical: EnemyTierProgressionDirector3D) -> void:
    var canonical_nodes := get_nodes_in_group(&"enemy_tier_progression")
    var active_canonical := 0
    for node in canonical_nodes:
        if node is EnemyTierProgressionDirector3D:
            var candidate := node as EnemyTierProgressionDirector3D
            if candidate.enabled and candidate.is_processing():
                active_canonical += 1
    _expect(canonical_nodes.size() == 1, "Exactly one canonical enemy-tier population director may exist in the release world.")
    _expect(active_canonical == 1 and canonical.enabled and canonical.is_processing(), "The one canonical population director must be active.")

    var active_legacy := 0
    for node in get_nodes_in_group(&"enemy_tier_director"):
        if node is EnemyTierDirector3D:
            var legacy := node as EnemyTierDirector3D
            if legacy.simulation_enabled or legacy.materialization_enabled:
                active_legacy += 1
    _expect(active_legacy == 0, "No legacy enemy-tier population director may simulate or materialize beside the canonical director.")


func _test_command_map_camera_round_trip(world: IronwrightReleaseWorld3D) -> void:
    world.follow_operation = false
    world.game_ended = false
    world.paused = false

    var initial_tactical_distance := world.camera.global_position.distance_to(world.player.global_position)
    _expect(initial_tactical_distance < 40.0, "A newly started release world must begin with the tactical camera near the Mechromancer.")

    world.map_mode = true
    for _frame in range(12):
        world._update_camera(0.1)
        await process_frame
    var map_height := world.camera.global_position.y - world.player.global_position.y
    _expect(map_height > 40.0, "Command-map mode must establish a high town-scale camera.")

    world.map_mode = false
    for _frame in range(4):
        world._update_camera(0.1)
        await process_frame
    var restored_tactical_distance := world.camera.global_position.distance_to(world.player.global_position)
    _expect(restored_tactical_distance < 40.0, "Closing the command map must restore a bounded tactical camera around the Mechromancer.")


func _test_single_command_map_hud(world: IronwrightReleaseWorld3D, bootstrap: EnemyTierProgressionBootstrap3D) -> void:
    world.map_mode = true
    await process_frame
    await process_frame

    var visible_tier_huds := 0
    for node in world.find_children("*", "CanvasLayer", true, false):
        if node is EnemyTierIntelHUD3D and (node as EnemyTierIntelHUD3D).visible:
            visible_tier_huds += 1
        elif node is EnemyTierHUD3D:
            var legacy_hud := node as EnemyTierHUD3D
            if legacy_hud.visible and legacy_hud.panel != null and legacy_hud.panel.visible:
                visible_tier_huds += 1

    _expect(bootstrap.intel_hud != null and bootstrap.intel_hud.visible, "The canonical ecology-intelligence HUD must be visible in command-map mode.")
    _expect(visible_tier_huds == 1, "Command-map mode must show exactly one enemy-tier intelligence HUD.")
    world.map_mode = false
    await process_frame


func _test_birth_handoff(world: IronwrightReleaseWorld3D) -> void:
    var local := world.ecology_director
    var strategic := world.strategic_ecology_director
    _expect(local.get_meta(&"population_controlled_by_enemy_tiers", false), "Local ecology must record the canonical population handoff.")
    _expect(strategic.get_meta(&"population_controlled_by_enemy_tiers", false), "Strategic ecology must record the canonical population handoff.")
    _expect(local.external_population_control, "Local ecology must remain in external-population-control mode.")
    _expect(strategic.external_population_control, "Strategic ecology must remain in external-population-control mode.")
    _expect(not local.spawn_enemy_callable.is_valid(), "The legacy local birth callback must be disconnected.")
    _expect(not strategic.spawn_enemy_callback.is_valid(), "The legacy regional birth callback must be disconnected.")
    _expect(local.is_processing(), "Local ecology processing must remain active after its birth callback is handed off.")
    _expect(strategic.is_processing(), "Strategic ecology processing must remain active after its birth callback is handed off.")
    _expect(strategic.active_enemy_cap > 0, "Birth handoff must not erase the strategic ecology's bounded runtime cap.")


func _test_local_attention_process(world: IronwrightReleaseWorld3D) -> void:
    var local := world.ecology_director
    _expect(not local.nest_positions.is_empty(), "The attention fixture requires at least one local nest position.")
    if local.nest_positions.is_empty():
        return

    local.nest_active[0] = true
    local.nest_activity[0] = &"roam"
    local.pending_noise_budget = 0.0
    local.world_pressure = 0.2
    local.strategic_clock = 13.0
    var local_spawn_serial := local.spawn_serial
    local.noise_system.emit_noise(local.nest_positions[0], 34.0, 1.0, &"runtime_ecology_test")
    _expect(local.pending_noise_budget >= 0.89, "Noise must remain an attention signal after legacy births are disabled.")

    await process_frame
    _expect(local.strategic_clock < 13.0, "The local ecology strategic clock must advance through the live process loop.")
    _expect(local.nest_activity[0] == &"hunt", "A nearby strong noise must still change local nest posture to hunt.")
    _expect(local.spawn_serial == local_spawn_serial, "Attention processing must not materialize an organism through the disabled legacy callback.")


func _test_strategic_state_process(world: IronwrightReleaseWorld3D) -> void:
    var strategic := world.strategic_ecology_director
    var region_id: StringName = &"region.heartforge_district"
    var before := strategic.population_state(region_id)
    _expect(not before.is_empty(), "Strategic ecology must expose persistent regional state for the Heartforge district.")
    if before.is_empty():
        return

    strategic.evaluation_clock = 3.8
    await process_frame
    await process_frame
    var after := strategic.population_state(region_id)
    _expect(strategic.evaluation_clock < 3.8, "Strategic ecology must execute its regional evaluation through live process frames.")
    _expect(
        not is_equal_approx(float(after.get("hunger", 0.0)), float(before.get("hunger", 0.0)))
        or not is_equal_approx(float(after.get("population", 0.0)), float(before.get("population", 0.0)))
        or not is_equal_approx(float(after.get("nesting", 0.0)), float(before.get("nesting", 0.0))),
        "At least one persistent regional ecology field must advance during a live strategic evaluation."
    )

    strategic.migration_clock = 0.0
    var migration_tendency_before := float(after.get("migration_tendency", 0.0))
    strategic.record_disturbance(world.region_director.center(region_id), 0.8, &"runtime_ecology_test")
    var disturbed := strategic.population_state(region_id)
    _expect(float(disturbed.get("migration_tendency", 0.0)) > migration_tendency_before, "Regional disturbance must still feed migration tendency under canonical population control.")
    await process_frame
    _expect(strategic.migration_clock > 0.0, "The strategic migration clock must remain live after birth handoff.")


func _test_physical_migration_without_birth(world: IronwrightReleaseWorld3D, canonical: EnemyTierProgressionDirector3D) -> void:
    var strategic := world.strategic_ecology_director
    strategic._ensure_population_states()
    var source_id: StringName = &""
    for raw_region_id in world.region_director.region_data:
        var candidate := StringName(str(raw_region_id))
        if candidate == &"region.heartforge_district":
            continue
        var candidate_data := world.region_director.get_region_data(candidate)
        var route: Array = candidate_data.get("route_from_heartforge", [])
        if route.size() >= 2:
            source_id = candidate
            break
    _expect(source_id != &"", "The migration fixture requires a routed region outside the Heartforge district.")
    if source_id == &"":
        return

    for raw_region_id in strategic.population_states:
        var state: Dictionary = strategic.population_states[raw_region_id]
        state["migration_tendency"] = 0.0
    var source_state: Dictionary = strategic.population_states[source_id]
    source_state["migration_tendency"] = 1.0
    source_state["disturbance"] = 0.9
    source_state["population"] = maxf(8.0, float(source_state.get("population", 8.0)))
    var source_landmark := world.region_director.get_landmark(source_id)
    _expect(source_landmark != null, "The routed migration region must have a physical landmark.")
    if source_landmark == null:
        return
    source_landmark.set_pressure(1.0)

    var migrant := world._spawn_enemy(world.region_director.center(source_id), &"skitterling")
    _expect(migrant != null, "The migration fixture must create one canonical, capped organism.")
    if migrant == null:
        return
    canonical.assign_enemy_tier(migrant, canonical.infer_tier_for_species(&"skitterling"), &"")
    migrant.set_meta(&"ecology_region", String(source_id))
    await process_frame
    await process_frame

    var population_before := get_nodes_in_group(&"organic_enemies").size()
    var regional_spawn_serial := strategic.spawn_serial
    strategic.migration_clock = 23.0
    await process_frame
    await process_frame
    var population_after := get_nodes_in_group(&"organic_enemies").size()
    var migrated_state := strategic.population_state(source_id)

    _expect(strategic.migration_clock < 23.0, "The live strategic loop must evaluate migration when its bounded clock matures.")
    _expect(migrant.get_meta(&"ecology_origin", "") == "regional_migration", "Regional migration must redirect a living organism instead of creating a replacement birth.")
    _expect(migrant.get_meta(&"ecology_region_previous", "") == String(source_id), "A migrating organism must retain its source-region diagnostic reason.")
    _expect(float(migrated_state.get("migration_tendency", 1.0)) < 1.0, "A completed physical migration must reduce the source region's migration tendency.")
    _expect(population_after == population_before, "Strategic migration under canonical control must move an existing organism without increasing population.")
    _expect(strategic.spawn_serial == regional_spawn_serial, "Strategic migration under canonical control must not use the legacy regional birth path.")


func _test_canonical_caps(canonical: EnemyTierProgressionDirector3D) -> void:
    canonical._reconcile_population()
    var living_by_tier: Dictionary = {}
    for tier in canonical.tier_order:
        living_by_tier[tier] = 0
    for node in get_nodes_in_group(&"organic_enemies"):
        if not is_instance_valid(node) or node.is_in_group(&"enemy_tier_nests"):
            continue
        if node.has_method(&"is_alive") and not bool(node.call(&"is_alive")):
            continue
        var tier := clampi(int(node.get_meta(&"enemy_tier", 1)), 1, canonical.maximum_tier)
        living_by_tier[tier] = int(living_by_tier.get(tier, 0)) + 1
    for tier in canonical.tier_order:
        _expect(int(living_by_tier.get(tier, 0)) <= canonical.unit_cap(tier), "Live Tier %d population must not exceed its canonical cap." % tier)

    var cap := canonical.unit_cap(1)
    canonical.debug_set_population(1, cap + 100)
    _expect(int(canonical.population.get(1, 0)) == cap, "Canonical population state must clamp attempted values to the configured tier cap.")
    canonical.debug_set_anonymous_rate(1, 600.0)
    canonical.spawn_credit[1] = canonical.spawn_credit_cap
    var canonical_spawn_serial := canonical.spawn_serial
    canonical._accumulate_and_spawn(1, 60.0)
    _expect(canonical.spawn_serial == canonical_spawn_serial, "A saturated canonical tier must refuse additional materialization even with queued spawn credit.")
    _expect(int(canonical.population.get(1, 0)) <= cap, "Canonical materialization must never move population above the configured cap.")


func _test_ecology_review_fixture(world: IronwrightReleaseWorld3D, canonical: EnemyTierProgressionDirector3D) -> void:
    _expect(world is IronwrightTieredWorld3D, "The release ecology fixture requires the tiered production world.")
    if not (world is IronwrightTieredWorld3D):
        return

    var tiered_world := world as IronwrightTieredWorld3D
    canonical.spawn_credit[2] = 0.25
    await tiered_world._start_ecology_runtime_review()
    var nearest_compatible_distance := INF
    for raw_nest in canonical.nests.values():
        if not (raw_nest is Node3D) or not is_instance_valid(raw_nest):
            continue
        var nest := raw_nest as Node3D
        if nest.has_method(&"can_spawn_tier") and bool(nest.call(&"can_spawn_tier", 2)):
            nearest_compatible_distance = minf(nearest_compatible_distance, world.player.global_position.distance_to(nest.global_position))

    _expect(nearest_compatible_distance <= 16.0, "The live ecology review must stage the player beside a compatible physical nest.")
    _expect(is_zero_approx(float(canonical.spawn_credit.get(2, 0.0))), "The live ecology review must spend its one review-only Tier-II birth credit through the canonical replenishment budget.")
    _expect(world.camera.global_position.distance_to(world.player.global_position) < 40.0, "The live ecology review must snap back to a readable tactical camera after teleporting.")
    _expect(world.region_lod_director != null and world.region_lod_director.is_processing(), "The live ecology review must keep regional presentation streaming active.")

    world.map_mode = true
    for _frame in range(90):
        await process_frame
    world.map_mode = false
    for _frame in range(8):
        await process_frame

    _expect(not world.paused and not world.game_ended, "The ecology review must remain live while the command map is inspected.")
    _expect(world.camera.global_position.distance_to(world.player.global_position) < 40.0, "Closing the command map during the ecology review must restore the tactical camera.")


func _clean_up(world: Node) -> void:
    if world != null and is_instance_valid(world):
        if world is IronwrightReleaseWorld3D:
            await (world as IronwrightReleaseWorld3D)._await_release_presentation_idle()
        world.propagate_call(&"set_process", [false], true)
        world.propagate_call(&"set_physics_process", [false], true)
        world.queue_free()
    for _frame in range(8):
        await process_frame
    await create_timer(0.25, true, false, true).timeout


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _finish() -> void:
    if failures.is_empty():
        print("Project Ironwright ecology runtime integration tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Project Ironwright ecology runtime integration tests failed: %d" % failures.size())
    quit(1)
