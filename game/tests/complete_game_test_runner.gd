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
    var complete_world := world as IronwrightCompleteGameWorld3D
    _expect(complete_world != null and complete_world.story_archive_director != null, "The complete run must install the persisted Town Archive director.")
    if complete_world != null and complete_world.story_archive_director != null:
        _expect(complete_world.story_archive_director.has_record(&"story.heartforge.last_light"), "The opening must preserve the first Town Archive record.")
        _expect(complete_world.story_archive_director.has_record(&"story.machine.bulwark"), "The opening must preserve the Bulwark identity as a durable Town Archive record.")
        complete_world._open_story_archive()
        _expect(complete_world.operations_hud.is_open() and complete_world.operations_hud.mode == &"archive", "The Town Archive must be readable through an on-demand archive panel.")
        complete_world._close_operations_hud()

    var opening_companion := world.autonomy_director.living_robots(&"companion")[0]
    _expect(opening_companion.display_identity() == "Bulwark", "The indispensable opening companion must have a stable player-facing callsign.")

    world.ecology_director.set_process(false)
    world.strategic_ecology_director.set_process(false)
    world.long_operation_director.spawn_enemy_callback = Callable()
    world.endgame_director.spawn_enemy_callback = Callable()
    _clear_enemies()

    _expect(world.region_director.region_data.size() >= 12, "The complete alpha must load all twelve persistent regions.")
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
    var route_blocker := Node3D.new()
    route_blocker.name = "RouteRecoveryOrganicBlocker"
    route_blocker.add_to_group(&"organic_enemies")
    world.add_child(route_blocker)
    route_blocker.global_position = world.long_operation_director.active_operation.get("anchor", world.heartforge.global_position)
    world.long_operation_director._update_active_operation(2.5)
    _expect(int(world.long_operation_director.active_operation.get("route_recovery_count", 0)) == 1, "A sustained organic blockage must trigger one bounded route recovery attempt.")
    _expect(bool(world.long_operation_director.active_operation.get("route_recovery_active", false)), "A route recovery must remain an explicit active formation decision until the side route is cleared.")
    var learned_west_route: Variant = world.long_operation_director.route_memory.get("region.west_grid", {})
    _expect(learned_west_route is Dictionary and float((learned_west_route as Dictionary).get("risk", 0.0)) >= 1.0, "A route disruption must become bounded persistent route-risk memory.")
    _expect(world.region_director.route_variant_count(&"region.west_grid") == 1, "The West Grid must expose one authored alternate street route for adaptive selection.")
    _expect(world.long_operation_director._preferred_route_variant(&"region.west_grid") == 1, "Repeated route disruption must make the authored alternate route the next autonomous preference.")
    var primary_west_route := world.region_director.route_from_heartforge(&"region.west_grid", world.heartforge.global_position)
    var alternate_west_route := world.region_director.route_from_heartforge_variant(&"region.west_grid", world.heartforge.global_position, 1)
    _expect(primary_west_route.size() == alternate_west_route.size() and primary_west_route[1] != alternate_west_route[1], "The alternate route must change the physical street waypoints rather than only renaming the report.")
    var recovery_anchor: Vector3 = world.long_operation_director.active_operation.get("anchor", world.heartforge.global_position)
    route_blocker.remove_from_group(&"organic_enemies")
    route_blocker.queue_free()
    await process_frame
    world.long_operation_director._update_active_operation(5.0)
    _expect(world.long_operation_director.active_operation.get("anchor", recovery_anchor).distance_to(recovery_anchor) > 0.1, "A recovered group must resume physical movement instead of remaining frozen at the blockage.")
    world._save_game()
    world._load_game()
    _expect(int(world.long_operation_director.active_operation.get("route_recovery_count", 0)) == 1, "Route-recovery progress must survive an in-flight operation save/load.")
    var restored_west_route_memory: Variant = world.long_operation_director.route_memory.get("region.west_grid", {})
    _expect(restored_west_route_memory is Dictionary and float((restored_west_route_memory as Dictionary).get("risk", 0.0)) >= 1.0, "Learned route-risk memory must survive the unified save/load path.")
    var recovered_operation_snapshot := world.long_operation_director.to_dictionary()
    var retreat_blocker := Node3D.new()
    retreat_blocker.name = "RouteRecoveryRetreatBlocker"
    retreat_blocker.add_to_group(&"organic_enemies")
    world.add_child(retreat_blocker)
    retreat_blocker.global_position = world.long_operation_director.active_operation.get("anchor", world.heartforge.global_position)
    world.long_operation_director.active_operation["route_recovery_count"] = 3
    world.long_operation_director.active_operation["route_recovery_active"] = false
    world.long_operation_director.active_operation["blocked_clock"] = 0.0
    world.long_operation_director._update_active_operation(2.5)
    _expect(StringName(world.long_operation_director.active_operation.get("state", &"")) == &"retreating", "A group that exhausts bounded side routes must enter explainable physical retreat instead of looping forever.")
    retreat_blocker.remove_from_group(&"organic_enemies")
    retreat_blocker.queue_free()
    await process_frame
    world.long_operation_director.restore_from_dictionary(recovered_operation_snapshot)
    _expect(StringName(world.long_operation_director.active_operation.get("state", &"")) == &"outbound", "Restoring the checkpoint after a diagnostic retreat decision must resume the saved outbound operation.")
    _expect(_finish_active_operation(world), "A checkpointed long-range operation must resume and complete physically.")
    _expect(world.run_state.rare_cores == cores_before_west + 1, "Checkpointed operation rewards must be delivered only after physical return.")
    _cleanup_save_files()

    _expect(world.long_operation_director.has_completed(&"operation.west_grid_survey"), "The West Grid survey must remain completed after return.")
    _expect(_event_contains(world, "MACHINE WITNESS"), "The first physically returned operation must create a sparse machine-witness relationship moment.")
    _expect(complete_world.story_archive_director.has_record(&"story.machine.first_return"), "The first returned expedition must preserve its machine-witness moment in the Town Archive.")
    _expect(world.region_director.is_discovered(&"region.west_grid"), "The West Grid must be physically discovered by the returned operation.")
    _expect(world.run_state.rare_cores == cores_before_west + 1, "Operation rewards must be delivered only after physical return.")
    _expect(world.outpost_director.get_site(&"site.west_substation").discovered, "The West Grid survey must reveal its fixed support site.")
    await process_frame
    _expect(world.region_director.get_landmark(&"region.west_grid").get_node_or_null("PersistentRegionGeometry/AuthoredEncounterDressing") != null, "Discovering a remote region must attach its authored encounter dressing without changing the operation contract.")
    _expect(complete_world.story_archive_director.has_record(&"story.north_ruins.ledger") and complete_world.story_archive_director.has_record(&"story.west_grid.reroute"), "Physical regional discoveries must unlock their stable Town Archive records.")

    _expect(world.progression.purchase(&"tech.heartforge.tier_3"), "West Grid data and one outpost must permit Heartforge tier 3.")
    _expect(world.progression.heartforge_tier == 3, "The run must reach Heartforge tier 3.")
    _expect(world.progression.purchase(&"tech.machine.forge_assistance"), "Tier 3 must permit autonomous ordinary replacement.")
    _expect(world.progression.purchase(&"tech.doctrine.deep_operations"), "Tier 3 must permit deep-operation doctrine.")

    var robots_before_replacement := world.run_state.robots_built
    # Tier 3 expects at least three Scrappers; the prepared team contains two.
    world.machine_society_director.fabrication_clock = 0.0
    world.machine_society_director._evaluate_society()
    _expect(world.run_state.robots_built == robots_before_replacement + 1, "Forge Assistance must replace a missing ordinary frame without a production queue.")
    _expect(complete_world.story_archive_director.has_record(&"story.machine.first_replacement"), "The first autonomous replacement must preserve its machine-witness moment in the Town Archive.")

    _expect(_complete_operation(world, &"operation.flood_market_recovery"), "The Vital Membrane operation must complete physically.")
    _expect(world.long_operation_director.has_component(&"component.vital_membrane"), "The Vital Membrane must become a persistent unique component.")

    world.outpost_director._spawn_outpost(second_site, &"repair", 1)
    _expect(_functioning_outposts(world) >= 2, "The Cathedral operation must depend on two functioning support posts.")
    _expect(_complete_operation(world, &"operation.cathedral_brood_suppression"), "The Cathedral Brood suppression must complete physically.")
    _expect(world.long_operation_director.has_component(&"component.choral_gland"), "The Choral Gland must become a persistent unique component.")
    _expect(world.region_director.get_landmark(&"region.cathedral_quarter").suppression > 0.0, "Suppressing the brood must causally reduce its regional pressure.")

    _expect(world.progression.purchase(&"tech.heartforge.tier_4"), "Two components and two outposts must permit Heartforge tier 4.")
    _expect(world.progression.heartforge_tier == 4, "The run must reach Heartforge tier 4.")
    _expect(world.adaptive_defense_director != null, "Heartforge tier 4 must install the adaptive defence director.")
    _expect(world.progression.purchase(&"tech.machine.signal_relay"), "Tier 4 and two recovered components must permit Signal Relay research.")
    for _attempt in range(10):
        if world.autonomy_director.count_robots(&"relay") >= 1:
            break
        world.machine_society_director.fabrication_clock = 0.0
        world.machine_society_director._evaluate_society()
    _expect(world.autonomy_director.count_robots(&"relay") >= 1, "Signal Relay research must let the machine society fabricate one relay automatically without a production queue.")
    world._save_game()
    world._load_game()
    _expect(world.autonomy_director.count_robots(&"relay") >= 1, "The Signal Relay chassis must survive the unified release save/load path.")
    var restored_companion := world.autonomy_director.living_robots(&"companion")[0]
    _expect(restored_companion.display_identity() == "Bulwark", "Robot callsigns must survive the unified save/load path, with the older-save default retaining Bulwark.")
    world.heartforge.current_health = world.heartforge.maximum_health * 0.72
    world.heartforge.health_changed.emit(world.heartforge.current_health, world.heartforge.maximum_health)
    world.adaptive_defense_director.evaluate_now()
    _expect(world.adaptive_defense_director.has_pending_proposal(), "Observed Heartforge damage must create one exceptional adaptive defence proposal.")
    _expect(world.adaptive_defense_director.available_plans().size() == 3, "The architect must present three broad structural principles rather than a tuning panel.")
    world._open_evolution_hud()
    _expect(world.strategic_hud.is_open() and world.strategic_hud.mode == &"adaptation", "A pending adaptive proposal must reuse the strategic surface instead of opening a permanent dashboard.")
    _expect(world.strategic_hud.detail_label.text.contains("Trade-off"), "Each adaptive proposal must explain its accepted trade-off before authorization.")
    var chosen_adaptation := world.strategic_hud.selected_adaptation_id()
    _expect(chosen_adaptation != &"", "The adaptive defence surface must expose a stable selected plan id.")
    world._authorize_adaptation(chosen_adaptation)
    _expect(not world.adaptive_defense_director.active_adaptation.is_empty(), "Authorizing an adaptive response must start an autonomous Heartforge construction operation.")
    var adaptation_checkpoint := world.adaptive_defense_director.to_dictionary()
    world.adaptive_defense_director._process(2.0)
    world.adaptive_defense_director.restore_from_dictionary(adaptation_checkpoint)
    _expect(not world.adaptive_defense_director.active_adaptation.is_empty(), "An in-progress Heartforge adaptation must survive save/load.")
    var adaptation_data: Dictionary = world.adaptive_defense_director.active_adaptation.get("data", {})
    world.adaptive_defense_director._process(float(adaptation_data.get("build_seconds", 12.0)) + 0.1)
    _expect(world.adaptive_defense_director.completed_adaptation == chosen_adaptation, "The selected Heartforge adaptation must complete after its machine-run construction interval.")
    _expect(world.heartforge.get_node_or_null("HeartforgeModel/HeartforgeAdaptationDetail") != null, "The completed adaptation must leave a visible high-definition Heartforge detail layer.")
    var adaptation_snapshot := world.adaptive_defense_director.to_dictionary()
    world.adaptive_defense_director.restore_from_dictionary(adaptation_snapshot)
    _expect(world.adaptive_defense_director.completed_adaptation == chosen_adaptation, "The completed adaptive response must persist as a stable run choice.")
    _expect(world.adaptive_defense_director.activity_noise_multiplier() > 1.0, "Anchor Deeply must expose its intended noise trade-off rather than being a free defensive bonus.")
    world.heartforge.current_health = world.heartforge.maximum_health
    world.heartforge.apply_damage(100.0)
    _expect(world.heartforge.current_health > world.heartforge.maximum_health - 100.0, "The selected adaptive response must reduce incoming Heartforge damage.")
    world.heartforge.current_health = world.heartforge.maximum_health
    world.heartforge.health_changed.emit(world.heartforge.current_health, world.heartforge.maximum_health)
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
    _expect(world.endgame_escalation_director.core_light != null and world.endgame_escalation_director.core_light.light_energy <= 4.0, "The final protocol light budget must preserve readable Heartforge silhouettes instead of blooming over the frame.")
    var capstone_visuals := world.get_node_or_null("EndgameProtocolVisuals") as Node3D
    _expect(capstone_visuals != null and capstone_visuals.global_position.distance_to(world.heartforge.global_position) > 1.5, "The final protocol capstone must anchor toward the player-facing side of the Heartforge so its transformation remains visible.")
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
    world.hud.show_ending(true, "The signal collapses. Organisms remain in the streets, but the intelligence coordinating them is gone. The machines inherit a wounded, survivable town.", true)
    var ending_panel := world.hud.ending_panel
    var ending_label := ending_panel.get_node("PanelContent").get_child(0) as Label
    _expect(ending_label != null and ending_label.text.count("\n") >= 4, "The victory overlay must wrap its long ending copy into readable lines.")
    _expect(ending_panel.offset_left < 0.0 and ending_panel.offset_right > 0.0 and ending_panel.offset_top < 0.0 and ending_panel.offset_bottom > 0.0, "The victory overlay must stay centered inside the viewport-safe offsets.")
    world.hud.dismiss_ending()

    var continue_event := InputEventKey.new()
    continue_event.keycode = KEY_ENTER
    continue_event.pressed = true
    world._unhandled_input(continue_event)
    _expect(not world.game_ended and world.sanctuary_continuation, "The victory boundary must support an explicit continuation into the living sanctuary.")
    _expect(world.long_operation_director.available_operations().any(func(entry: Dictionary) -> bool: return StringName(str(entry.get("id", ""))) == &"operation.post_victory_archive"), "The post-victory archive must become available after the player continues.")
    _expect(_complete_operation(world, &"operation.post_victory_archive"), "The post-victory archive must remain a physical autonomous operation.")
    _expect(world.long_operation_director.has_component(&"component.town_archive"), "The post-victory archive must deliver its persistent town record component.")
    _expect(complete_world.story_archive_director.has_record(&"story.town_archive.continuation"), "The recovered post-victory archive must unlock its persistent Town Archive record.")

    var region_save := world.region_director.to_dictionary()
    var story_archive_save := complete_world.story_archive_director.to_dictionary()
    var operation_save := world.long_operation_director.to_dictionary()
    var society_save := world.machine_society_director.to_dictionary()
    var ecology_save := world.strategic_ecology_director.to_dictionary()
    _expect(ecology_save.has("population_states") and int(ecology_save.get("schema_version", 0)) >= 3, "Ecology saves must include versioned population states.")
    var saved_population := float(world.strategic_ecology_director.population_state(&"region.heartforge_district").get("population", 0.0))
    var endgame_save := world.endgame_director.to_dictionary()

    world.region_director.restore_from_dictionary(region_save)
    complete_world.story_archive_director.restore_from_dictionary(story_archive_save)
    world.long_operation_director.restore_from_dictionary(operation_save)
    world.machine_society_director.restore_from_dictionary(society_save)
    world.strategic_ecology_director.restore_from_dictionary(ecology_save)
    _expect(is_equal_approx(float(world.strategic_ecology_director.population_state(&"region.heartforge_district").get("population", 0.0)), saved_population), "Ecology population state must survive in-memory restoration.")
    world.endgame_director.restore_from_dictionary(endgame_save)
    _expect(world.long_operation_director.component_count() >= 4, "Save restoration must preserve all recovered components.")
    _expect(complete_world.story_archive_director.has_record(&"story.town_archive.continuation"), "Town Archive records must survive in-memory restoration.")
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
    if operation_id == &"operation.root_cistern_mapping":
        _expect(director._route_recovery_limit() >= 4, "A live Signal Relay must add one bounded route recovery to the Root Cistern formation.")
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


func _event_contains(world: IronwrightCompleteGameWorld3D, needle: String) -> bool:
    for event in world.run_state.event_log:
        if str(event).contains(needle):
            return true
    return false


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
