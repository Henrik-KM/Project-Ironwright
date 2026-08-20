extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")
const TEST_SAVE_ROOT := "user://ironwright_complete_integration_test"
const TEST_SAVE_PATH := "user://ironwright_complete_integration_test/world_0.json"

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightReleaseWorld3D
    root.add_child(world)
    await process_frame
    await physics_frame
    await process_frame

    _expect(world != null, "The main scene must boot the complete-game world.")
    if world == null:
        _finish()
        return

    world.ecology_director.set_process(false)
    world.strategic_ecology_director.set_process(false)
    world.long_operation_director.spawn_enemy_callback = Callable()
    world.endgame_director.spawn_enemy_callback = Callable()
    _clear_enemies()

    _expect(world.region_director.region_data.size() >= 7, "The complete alpha must load all persistent regions.")
    _expect(world.region_director.is_discovered(&"region.heartforge_district"), "The Heartforge district must begin discovered.")
    _expect(not world.region_director.is_discovered(&"region.root_cistern"), "The Root Cistern must remain hidden during the opening.")
    _expect(world.long_operation_director.available_operations().is_empty(), "Long-range operations must be gated during the weak opening.")
    _expect(world.operations_hud != null, "The complete alpha must provide the long-range operation interface.")
    var opening_ecology := world.strategic_ecology_director.population_state(&"region.heartforge_district")
    _expect(opening_ecology.has("population") and opening_ecology.has("hunger") and opening_ecology.has("nesting"), "Regional ecology must persist population, hunger, and nesting state.")
    var disturbance_before := float(opening_ecology.get("disturbance", 0.0))
    world.strategic_ecology_director.record_disturbance(Vector3.ZERO, 1.0, &"test_signal")
    var disturbed_ecology := world.strategic_ecology_director.population_state(&"region.heartforge_district")
    _expect(float(disturbed_ecology.get("disturbance", 0.0)) > disturbance_before, "A causal signal must raise persistent regional disturbance.")

    world.run_state.scrap = 12000
    world.run_state.rare_cores = 24
    world.run_state.manual_scrap_recovered = 80
    world.run_state.autonomous_scrap_recovered = 120
    world.run_state.robots_built = 12
    world.run_state.expedition_core_recovered = true
    world.run_state.scrap_changed.emit(world.run_state.scrap)
    world.run_state.rare_cores_changed.emit(world.run_state.rare_cores)

    _spawn_complete_team(world)
    world.progression._evaluate_automatic_technologies()
    _expect(world.progression.purchase(&"tech.machine.group_coordination"), "Group Coordination must unlock the complete operation architecture.")
    _expect(world.progression.purchase(&"tech.heartforge.tier_2"), "The recovered core must permit Heartforge tier 2.")
    world.progression._evaluate_automatic_technologies()
    _expect(world.progression.heartforge_tier == 2, "The run must reach Heartforge tier 2.")

    world.outpost_director.discover_sites_by(&"expedition.north_ruins")
    world.region_director.discover_region(&"region.north_ruins")
    var first_site := world.outpost_director.get_site(&"site.north_transit_yard")
    var second_site := world.outpost_director.get_site(&"site.hospital_service_court")
    var third_site := world.outpost_director.get_site(&"site.south_municipal_watch")
    _expect(first_site != null and second_site != null and third_site != null, "The initial expedition must expose three bounded support sites.")
    world.outpost_director._spawn_outpost(first_site, &"resource", 1)

    var cores_before_west := world.run_state.rare_cores
    world.transactional_save_service.configure(TEST_SAVE_ROOT, 3)
    _expect(world.long_operation_director.authorize(&"operation.west_grid_survey"), "A long-range operation must be authorizable before checkpoint testing.")
    var checkpoint_id := StringName(world.long_operation_director.active_operation.get("id", &""))
    world._save_game()
    _expect(FileAccess.file_exists(TEST_SAVE_PATH), "The complete-world save hook must write while a long-range group is in flight.")
    world._load_game()
    _expect(StringName(world.long_operation_director.active_operation.get("id", &"")) == checkpoint_id, "Loading must restore the active long-range operation identity.")
    _expect(_finish_active_operation(world), "A checkpointed long-range operation must resume and complete physically.")
    _expect(world.run_state.rare_cores == cores_before_west + 1, "Checkpointed operation rewards must be delivered only after physical return.")
    _cleanup_save_files()

    _expect(world.long_operation_director.has_completed(&"operation.west_grid_survey"), "The West Grid survey must remain completed after return.")
    _expect(world.region_director.is_discovered(&"region.west_grid"), "The West Grid must be physically discovered by the returned operation.")
    _expect(world.run_state.rare_cores == cores_before_west + 1, "Operation rewards must be delivered only after physical return.")
    _expect(world.outpost_director.get_site(&"site.west_substation").discovered, "The West Grid survey must reveal its fixed support site.")

    _expect(world.progression.purchase(&"tech.heartforge.tier_3"), "West Grid data and one outpost must permit Heartforge tier 3.")
    _expect(world.progression.heartforge_tier == 3, "The run must reach Heartforge tier 3.")
    _expect(world.progression.purchase(&"tech.machine.forge_assistance"), "Tier 3 must permit autonomous ordinary replacement.")
    _expect(world.progression.purchase(&"tech.doctrine.deep_operations"), "Tier 3 must permit deep-operation doctrine.")

    var robots_before_replacement := world.run_state.robots_built
    # Tier 3 expects at least three Scrappers; the prepared team contains two.
    world.machine_society_director.fabrication_clock = 0.0
    world.machine_society_director._evaluate_society()
    _expect(world.run_state.robots_built == robots_before_replacement + 1, "Forge Assistance must replace a missing ordinary frame without a production queue.")

    _expect(_complete_operation(world, &"operation.flood_market_recovery"), "The Vital Membrane operation must complete physically.")
    _expect(world.long_operation_director.has_component(&"component.vital_membrane"), "The Vital Membrane must become a persistent unique component.")

    world.outpost_director._spawn_outpost(second_site, &"repair", 1)
    _expect(_functioning_outposts(world) >= 2, "The Cathedral operation must depend on two functioning support posts.")
    _expect(_complete_operation(world, &"operation.cathedral_brood_suppression"), "The Cathedral Brood suppression must complete physically.")
    _expect(world.long_operation_director.has_component(&"component.choral_gland"), "The Choral Gland must become a persistent unique component.")
    _expect(world.region_director.get_landmark(&"region.cathedral_quarter").suppression > 0.0, "Suppressing the brood must causally reduce its regional pressure.")

    _expect(world.progression.purchase(&"tech.heartforge.tier_4"), "Two components and two outposts must permit Heartforge tier 4.")
    _expect(world.progression.heartforge_tier == 4, "The run must reach Heartforge tier 4.")
    _expect(_complete_operation(world, &"operation.buried_lab_excavation"), "The Genome Prism excavation must complete physically.")
    _expect(world.long_operation_director.has_component(&"component.genome_prism"), "The Genome Prism must become a persistent unique component.")

    world.outpost_director._spawn_outpost(third_site, &"scout", 1)
    _expect(_functioning_outposts(world) >= 3, "Root mapping must require a bounded three-post support network.")
    _expect(_complete_operation(world, &"operation.root_cistern_mapping"), "The Root Cistern mapping operation must complete physically.")
    _expect(world.long_operation_director.has_component(&"component.root_map"), "The Root Map must complete the final component set.")
    _expect(world.region_director.is_discovered(&"region.root_cistern"), "The Root Cistern must be revealed by the returned mapping group.")

    _expect(world.progression.purchase(&"tech.heartforge.tier_5"), "Three biological components and three outposts must permit Heartforge tier 5.")
    _expect(world.progression.heartforge_tier == 5, "The run must reach Heartforge tier 5.")
    _expect(world.progression.purchase(&"tech.endgame.severance"), "Tier 5 and the Root Map must permit Severance research.")

    var protocols := world.endgame_director.available_protocols()
    _expect(not protocols.is_empty(), "At least one player-triggered final protocol must become available.")
    _expect(world.endgame_director.initiate(&"protocol.severance"), "The player must be able to initiate the complete victory path deliberately.")
    _expect(not world.endgame_director.active_protocol.is_empty(), "The final protocol must be an active causal process rather than an instant ending.")
    _expect(world.endgame_escalation_director != null, "The final protocol must have a dedicated bounded presentation director.")
    _expect(world.endgame_escalation_director.current_state == &"active", "Starting a final protocol must raise its Heartforge lattice presentation.")
    _expect(world.get_node_or_null("EndgameProtocolVisuals") != null, "The final protocol must attach a visible lattice to the Heartforge without changing collision geometry.")
    world.endgame_director._process(0.1)
    _expect(world.endgame_escalation_director.current_progress > 0.0, "Final protocol progress must drive the visual lattice continuously.")
    var severance := world.endgame_director.protocol(&"protocol.severance")
    world.endgame_director._process(float(severance.get("duration_seconds", 210.0)) + 1.0)
    _expect(world.endgame_director.completed_protocol == &"protocol.severance", "The final protocol must complete after its sustained defence interval.")
    _expect(world.endgame_escalation_director.current_state == &"completed", "Final protocol completion must resolve the crisis lattice into the sanctuary crown.")
    _expect(world.get_node("EndgameProtocolVisuals/SanctuaryCrown").visible, "The completed protocol must leave a calm capstone presentation at the Heartforge.")
    _expect(world.first_victory_achieved, "Completing a final protocol must produce the first victory.")
    _expect(world.game_ended, "The complete systemic run must have a real end state.")
    _expect(not world.long_operation_director.available_operations().any(func(entry: Dictionary) -> bool: return StringName(str(entry.get("id", ""))) == &"operation.post_victory_archive"), "The post-victory archive must remain unavailable behind the victory boundary until continuation is chosen.")

    var continue_event := InputEventKey.new()
    continue_event.keycode = KEY_ENTER
    continue_event.pressed = true
    world._unhandled_input(continue_event)
    _expect(not world.game_ended and world.sanctuary_continuation, "The victory boundary must support an explicit continuation into the living sanctuary.")
    _expect(world.long_operation_director.available_operations().any(func(entry: Dictionary) -> bool: return StringName(str(entry.get("id", ""))) == &"operation.post_victory_archive"), "The post-victory archive must become available after the player continues.")
    _expect(_complete_operation(world, &"operation.post_victory_archive"), "The post-victory archive must remain a physical autonomous operation.")
    _expect(world.long_operation_director.has_component(&"component.town_archive"), "The post-victory archive must deliver its persistent town record component.")

    var region_save := world.region_director.to_dictionary()
    var operation_save := world.long_operation_director.to_dictionary()
    var society_save := world.machine_society_director.to_dictionary()
    var ecology_save := world.strategic_ecology_director.to_dictionary()
    _expect(ecology_save.has("population_states") and int(ecology_save.get("schema_version", 0)) >= 3, "Ecology saves must include versioned population states.")
    var saved_population := float(world.strategic_ecology_director.population_state(&"region.heartforge_district").get("population", 0.0))
    var endgame_save := world.endgame_director.to_dictionary()

    world.region_director.restore_from_dictionary(region_save)
    world.long_operation_director.restore_from_dictionary(operation_save)
    world.machine_society_director.restore_from_dictionary(society_save)
    world.strategic_ecology_director.restore_from_dictionary(ecology_save)
    _expect(is_equal_approx(float(world.strategic_ecology_director.population_state(&"region.heartforge_district").get("population", 0.0)), saved_population), "Ecology population state must survive in-memory restoration.")
    world.endgame_director.restore_from_dictionary(endgame_save)
    _expect(world.long_operation_director.component_count() >= 4, "Save restoration must preserve all recovered components.")
    _expect(world.endgame_director.completed_protocol == &"protocol.severance", "Save restoration must preserve the chosen completed ending.")
    _expect(world.region_director.is_discovered(&"region.root_cistern"), "Save restoration must preserve late-region discovery.")

    world.transactional_save_service.configure(TEST_SAVE_ROOT, 3)
    _expect(world.transactional_save_service != null, "The complete world must install the transactional save service.")
    world._save_game()
    _expect(FileAccess.file_exists(TEST_SAVE_PATH), "The complete-world save hook must write the unified envelope.")
    world.first_victory_achieved = false
    world.game_ended = false
    world.region_director.region_data[&"region.root_cistern"]["discovered"] = false
    world._load_game()
    _expect(world.first_victory_achieved, "The unified save/load path must restore complete-world victory state.")
    _expect(world.sanctuary_continuation, "The unified save/load path must restore the continuing sanctuary state.")
    _expect(world.region_director.is_discovered(&"region.root_cistern"), "The unified save/load path must restore complete-world discovery state.")
    _cleanup_save_files()

    # The player chooses one final protocol per run. Re-open the isolated
    # director fixture after the Severance assertions so the alternate
    # Containment branch is exercised through the same prerequisite, cost,
    # sustained-response, and completion code paths.
    world.endgame_director.completed_protocol = &""
    world.endgame_director.active_protocol.clear()
    world.first_victory_achieved = false
    world.game_ended = false
    _expect(world.progression.purchase(&"tech.endgame.containment"), "The complete run must support researching the alternate Containment protocol.")
    _expect(world.endgame_director.available_protocols().any(func(entry: Dictionary) -> bool: return StringName(str(entry.get("id", ""))) == &"protocol.containment"), "Containment must appear only after its full technology and outpost prerequisites are met.")
    _expect(world.endgame_director.initiate(&"protocol.containment"), "The player must be able to initiate the alternate Containment path deliberately.")
    var containment := world.endgame_director.protocol(&"protocol.containment")
    world.endgame_director._process(float(containment.get("duration_seconds", 300.0)) + 1.0)
    _expect(world.endgame_director.completed_protocol == &"protocol.containment", "Containment must complete after its longer sustained defence interval.")
    _expect(world.first_victory_achieved, "Completing Containment must produce the first victory state.")

    _finish()


func _spawn_complete_team(world: IronwrightCompleteGameWorld3D) -> void:
    for index in range(2):
        world._spawn_robot(&"salvager", Vector3(2.0 + float(index), 0.0, 4.0), 1)
    for index in range(4):
        world._spawn_robot(&"guardian", Vector3(-3.0 + float(index), 0.0, 5.0), 1)
    for index in range(2):
        world._spawn_robot(&"scout", Vector3(-1.0 + float(index), 0.0, 7.0), 1)
    for index in range(2):
        world._spawn_robot(&"engineer", Vector3(1.0 + float(index), 0.0, 8.0), 1)


func _complete_operation(world: IronwrightCompleteGameWorld3D, operation_id: StringName) -> bool:
    var director := world.long_operation_director
    if not director.authorize(operation_id):
        return false
    return _finish_active_operation(world, operation_id)


func _finish_active_operation(world: IronwrightCompleteGameWorld3D, expected_id: StringName = &"") -> bool:
    var director := world.long_operation_director
    if director.active_operation.is_empty():
        return false
    var completed_id := expected_id
    if completed_id == &"":
        completed_id = StringName(director.active_operation.get("id", &""))
    if expected_id != &"" and StringName(director.active_operation.get("id", &"")) != expected_id:
        return false
    var route: PackedVector3Array = director.active_operation.get("route", PackedVector3Array())
    director.active_operation["route_index"] = route.size()
    director._update_active_operation(0.1)
    if StringName(director.active_operation.get("state", &"")) != &"working":
        return false
    var data: Dictionary = director.active_operation.get("data", {})
    director._update_active_operation(float(data.get("work_seconds", 14.0)) + 0.1)
    if StringName(director.active_operation.get("state", &"")) != &"returning":
        return false
    var reverse_route: PackedVector3Array = director.active_operation.get("route", PackedVector3Array())
    director.active_operation["route_index"] = reverse_route.size()
    director._update_active_operation(0.1)
    return director.active_operation.is_empty() and director.has_completed(completed_id)


func _functioning_outposts(world: IronwrightCompleteGameWorld3D) -> int:
    var count := 0
    for site in world.outpost_director.discovered_sites():
        if site.has_functioning_outpost():
            count += 1
    return count


func _clear_enemies() -> void:
    for enemy in get_nodes_in_group(&"organic_enemies"):
        if is_instance_valid(enemy):
            enemy.free()


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _cleanup_save_files() -> void:
    for path in [TEST_SAVE_PATH, TEST_SAVE_ROOT + "/world_0.backup_1.json", TEST_SAVE_ROOT + "/world_0.backup_2.json", TEST_SAVE_ROOT + "/world_0.backup_3.json", TEST_SAVE_ROOT + "/world_0.tmp"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)


func _finish() -> void:
    if failures.is_empty():
        print("Project Ironwright complete-game alpha tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Project Ironwright complete-game alpha tests failed: %d" % failures.size())
    quit(1)
