extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")
const RELEASE_SLOT: StringName = &"world_0"
const TEST_SAVE_ROOT := "user://ironwright_long_run_soak"
const TEST_SAVE_PATH := "user://ironwright_long_run_soak/world_0.json"
const TEST_SIDECAR_PATH := "user://ironwright_long_run_soak/world_0.enemy_tiers.json"
const CHECKPOINT_COUNT := 600
const CHECKPOINT_SECONDS := 600.0
const EXPECTED_SIMULATED_SECONDS := float(CHECKPOINT_COUNT) * CHECKPOINT_SECONDS
const SAVE_INTERVAL := 12

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightReleaseWorld3D
    root.add_child(world)
    for _index in range(8):
        await process_frame
    await physics_frame

    _expect(world != null, "The long-run soak must boot the complete release world.")
    if world == null:
        _finish()
        return
    if world.settings_service != null:
        world.settings_service.set_value(&"language", "en", false)
    if world.localization_service != null:
        world.localization_service.set_locale(&"en")

    var bootstrap := world.get_node_or_null("EnemyTierProgressionBootstrap") as EnemyTierProgressionBootstrap3D
    var tier_director: EnemyTierProgressionDirector3D = bootstrap.director if bootstrap != null else null
    _expect(world.transactional_save_service != null, "The long-run soak must use the release transactional save service.")
    _expect(bootstrap != null and tier_director != null, "The long-run soak must use the canonical enemy-tier director.")
    if world.transactional_save_service == null or tier_director == null:
        _finish()
        return

    _prepare_deterministic_simulation(world, bootstrap, tier_director)
    world.transactional_save_service.configure(TEST_SAVE_ROOT, 3)
    _cleanup_save_files()

    var maximum_save_bytes := 0
    var first_save_bytes := 0
    for checkpoint in range(CHECKPOINT_COUNT):
        await _advance_simulation(world, tier_director, CHECKPOINT_SECONDS)
        if checkpoint % 10 == 0:
            world.run_state.log_event("LONG-RUN SOAK · checkpoint %d/%d" % [checkpoint + 1, CHECKPOINT_COUNT])
        _assert_bounded_state(world, tier_director)

        if (checkpoint + 1) % SAVE_INTERVAL != 0:
            continue
        var expected_seconds := float(checkpoint + 1) * CHECKPOINT_SECONDS
        var save_succeeded := world._save_release_game()
        if not save_succeeded:
            print("SOAK_SAVE_FAILED checkpoint=%d channeling=%s reason=%s" % [checkpoint + 1, str(world.player.is_channeling()), world.transactional_save_service.last_error])
        _expect(save_succeeded, "Transactional save must succeed at simulated %.1f hours." % (expected_seconds / 3600.0))
        _expect(FileAccess.file_exists(TEST_SAVE_PATH), "The current verified save must exist at checkpoint %d." % (checkpoint + 1))
        _expect(FileAccess.file_exists(TEST_SIDECAR_PATH), "The enemy-tier sidecar must exist at checkpoint %d." % (checkpoint + 1))
        var save_bytes := FileAccess.get_file_as_bytes(TEST_SAVE_PATH).size()
        maximum_save_bytes = maxi(maximum_save_bytes, save_bytes)
        if first_save_bytes == 0:
            first_save_bytes = save_bytes
        _expect(save_bytes > 0, "The verified save must not be empty at checkpoint %d." % (checkpoint + 1))
        _expect(save_bytes <= 4 * 1024 * 1024, "The verified save must remain bounded at checkpoint %d." % (checkpoint + 1))

        var payload := world.transactional_save_service.load_snapshot(RELEASE_SLOT)
        _expect(not payload.is_empty(), "The current save must be readable at checkpoint %d." % (checkpoint + 1))
        var saved_base: Dictionary = payload.get("base", {})
        var saved_run_state: Dictionary = saved_base.get("run_state", {})
        _expect(is_equal_approx(float(saved_run_state.get("elapsed_seconds", -1.0)), expected_seconds), "The saved run clock must preserve the simulated time at checkpoint %d." % (checkpoint + 1))

        if (checkpoint + 1) % (SAVE_INTERVAL * 2) == 0:
            _expect(world._load_release_game(), "The complete release load path must restore at checkpoint %d." % (checkpoint + 1))
            bootstrap._process(0.0)
            _expect(is_equal_approx(world.run_state.elapsed_seconds, expected_seconds), "The loaded run clock must preserve the simulated time at checkpoint %d." % (checkpoint + 1))
            _expect(int(tier_director.get("elapsed_seconds")) >= int(expected_seconds), "The enemy-tier sidecar must restore the simulated time at checkpoint %d." % (checkpoint + 1))
            _prepare_deterministic_simulation(world, bootstrap, tier_director, false)

    _expect(is_equal_approx(world.run_state.elapsed_seconds, EXPECTED_SIMULATED_SECONDS), "The soak must advance the release run by exactly one hundred simulated hours.")
    _expect(maximum_save_bytes > 0 and maximum_save_bytes <= maxi(first_save_bytes * 4, 4 * 1024 * 1024), "Save size must remain bounded across the full soak.")
    _assert_bounded_state(world, tier_director)
    _cleanup_save_files()
    world.queue_free()
    await process_frame
    _finish()


func _prepare_deterministic_simulation(world: IronwrightReleaseWorld3D, bootstrap: EnemyTierProgressionBootstrap3D, tier_director: EnemyTierProgressionDirector3D, reset_clock: bool = true) -> void:
    # No frame is allowed to advance the fixture between checkpoints. The
    # directors are then advanced through their real reduced-detail paths below.
    world.set_process(false)
    world.run_state.set_process(false)
    world.strategic_ecology_director.set_process(false)
    world.ecology_director.set_process(false)
    world.outpost_director.set_process(false)
    world.long_operation_director.set_process(false)
    world.balance_director.set_process(false)
    world.performance_director.set_process(false)
    bootstrap.set_process(false)
    tier_director.set_process(false)
    if reset_clock:
        world.run_state.elapsed_seconds = 0.0
        tier_director.elapsed_seconds = 0.0
        tier_director.simulation_clock = 0.0
        tier_director.reconcile_clock = 0.0
        tier_director.intel_clock = 0.0
    world.run_state.scrap = 12000
    world.run_state.rare_cores = 24
    world.run_state.expedition_core_recovered = true
    world.run_state.log_event("LONG-RUN SOAK · deterministic release fixture armed")
    tier_director.enabled = true


func _advance_simulation(world: IronwrightReleaseWorld3D, tier_director: EnemyTierProgressionDirector3D, delta: float) -> void:
    world.run_state._process(delta)
    tier_director._process(delta)
    if world.strategic_ecology_director != null:
        world.strategic_ecology_director._process(delta)
    if world.balance_director != null:
        world.balance_director._process(delta)
    if world.performance_director != null:
        world.performance_director._process(delta)
    await process_frame
    tier_director._reconcile_population()
    tier_director._refresh_nest_sources()


func _assert_bounded_state(world: IronwrightReleaseWorld3D, tier_director: EnemyTierProgressionDirector3D) -> void:
    _expect(world.run_state.event_log.size() <= 48, "The run event history must remain capped at 48 entries.")
    _expect(tier_director.nests.size() <= 24, "The physical nest registry must remain bounded.")
    _expect(tier_director.rate_sources.size() <= tier_director.nests.size() * 5, "The enemy-tier rate-source registry must remain bounded by physical nests.")
    _expect(_organic_actor_count() <= 164, "Population-driven organic actors must remain within the sum of tier caps.")
    for tier in tier_director.tier_order:
        _expect(int(tier_director.population.get(tier, 0)) <= tier_director.unit_cap(tier), "Tier %d population %d must remain below its configured cap %d." % [tier, int(tier_director.population.get(tier, 0)), tier_director.unit_cap(tier)])


func _cleanup_save_files() -> void:
    if world_save_service_exists():
        var service := get_first_node_in_group(&"transactional_save_service") as ReleaseTransactionalSaveService3D
        if service != null:
            service.delete_slot(RELEASE_SLOT)
    for path in [TEST_SAVE_PATH, TEST_SAVE_ROOT + "/world_0.backup_1.json", TEST_SAVE_ROOT + "/world_0.backup_2.json", TEST_SAVE_ROOT + "/world_0.backup_3.json", TEST_SAVE_ROOT + "/world_0.tmp", TEST_SIDECAR_PATH, TEST_SAVE_ROOT + "/world_0.enemy_tiers.tmp", TEST_SAVE_ROOT + "/world_0.enemy_tiers.backup.json"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func world_save_service_exists() -> bool:
    return get_first_node_in_group(&"transactional_save_service") != null


func _organic_actor_count() -> int:
    var count := 0
    for candidate in get_nodes_in_group(&"organic_enemies"):
        if candidate.is_in_group(&"enemy_tier_nests"):
            continue
        # A killed organism may remain briefly for its death presentation, but
        # it no longer belongs to the living population cap being audited.
        if candidate.has_method(&"is_alive") and not bool(candidate.call(&"is_alive")):
            continue
        count += 1
    return count


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)


func _finish() -> void:
    if failures.is_empty():
        print("Project Ironwright one-hundred-hour-equivalent long-run soak tests passed.")
        quit(0)
        return
    print("Project Ironwright one-hundred-hour-equivalent long-run soak tests failed: %d" % failures.size())
    quit(1)
