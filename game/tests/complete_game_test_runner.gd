extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")
const TEST_SAVE_ROOT := "user://ironwright_complete_integration_test"
const TEST_SAVE_PATH := "user://ironwright_complete_integration_test/world_0.json"

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightReleaseWorld3D
    # The normal graphical release boot intentionally stops at the title scene
    # until the player chooses New World or Continue. This integration runner
    # exercises the complete playable world directly in both headless and
    # graphical validation, so select the same explicit New World path before
    # adding the scene to the tree.
    world.pending_launch_mode = &"new"
    root.add_child(world)
    await process_frame
    await physics_frame
    await process_frame

    _expect(world != null, "The main scene must boot the complete-game world.")
    if world == null:
        _finish()
        return
    # Production Continue and the in-world load shortcut deliberately wait for
    # the canonical ecology bootstrap before restoring a unified generation.
    # Establish that same readiness boundary once for this complete-run fixture
    # so every subsequent save/load assertion observes the completed load, not
    # a deferred coroutine that is still waiting on renderer handoff.
    _expect(await world._await_enemy_tier_bootstrap_initialized(), "The complete-run fixture must initialize canonical ecology before exercising unified save/load.")
    # The release export persists the player's language outside the save
    # envelope. Keep this integration run deterministic after a live locale
    # review and exercise the English authored-content contracts explicitly.
    if world.localization_service != null:
        world.localization_service.set_locale(&"en")
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
    _expect(world.long_operation_director.operations.size() >= 30, "The long-run operation catalogue must retain the roadmap's minimum authored physical objective breadth.")
    for authored_operation_id in [
        &"operation.north_civic_roofline",
        &"operation.west_canal_works_repair",
        &"operation.east_roof_bridge_reinforcement",
        &"operation.glasshouse_service_bay",
        &"operation.flood_market_crane_lift",
        &"operation.observatory_lower_courtyard",
        &"operation.buried_lab_airlock",
        &"operation.north_transit_signal",
        &"operation.north_canal_gate_hold",
        &"operation.west_cooling_station_reclaim",
        &"operation.east_residential_arc_relay",
        &"operation.cathedral_bell_yard_silence",
        &"operation.observatory_service_ring",
        &"operation.root_signal_ledge_watch",
    ]:
        _expect(world.long_operation_director.operations.has(authored_operation_id), "The authored catalogue must load %s." % authored_operation_id)
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
    var active_long_range_members: Array[RobotUnit3D] = []
    active_long_range_members.append_array(world.long_operation_director.active_operation.get("members", []))
    _expect(world.autonomy_director.is_processing(), "A long-range operation must leave the local autonomy director processing the machines that stayed home.")
    _expect(world.outpost_director.is_processing(), "A long-range operation must leave autonomous outpost maintenance processing while the remote group travels.")
    _expect(world.autonomy_director.external_operation_member_count() == active_long_range_members.size(), "The long-range team must be explicitly reserved so local autonomy cannot reassign its members.")
    world.autonomy_director._refresh_macro_assignments()
    for long_range_member in active_long_range_members:
        _expect(long_range_member.assigned_group == &"long_range_operation", "A reserved long-range member must retain its physical expedition group after local assignment refresh.")
    var home_machine: RobotUnit3D
    for candidate in world.autonomy_director.living_robots():
        if candidate not in active_long_range_members and candidate.archetype != &"companion":
            home_machine = candidate
            break
    _expect(home_machine != null, "The complete integration fixture must retain at least one non-expedition machine at the Heartforge.")
    if home_machine != null:
        _expect(home_machine.assigned_group != &"long_range_operation", "A machine remaining at the Heartforge must not be marked as part of the departing formation.")
    first_site.outpost.stored_scrap = 30
    world.outpost_director.maintenance_clock = 2.0
    world.outpost_director._process(1.1)
    _expect(StringName(world.outpost_director.operation.get("kind", &"")) == &"haul", "An autonomous outpost must be able to launch a protected haul while a separate long-range formation is away.")
    _expect(world.autonomy_director.is_processing(), "A concurrent outpost convoy must not pause the local autonomy director.")
    var concurrent_outpost_members: Array[RobotUnit3D] = []
    concurrent_outpost_members.append_array(world.outpost_director.operation.get("members", []))
    for outpost_member in concurrent_outpost_members:
        _expect(outpost_member not in active_long_range_members, "Concurrent long-range and outpost convoys must reserve disjoint machine teams.")
    _expect(world.autonomy_director.external_operation_member_count() == active_long_range_members.size() + concurrent_outpost_members.size(), "Concurrent remote operations must retain the union of both explicit team reservations.")
    world._process(0.1)
    _expect("FOLLOW THE ACTIVE MACHINE GROUP" in world.hud.objective_label.text, "An active long-range operation must replace the previous strategic objective with the physical group follow objective.")
    _expect("F FOLLOW ACTIVE MACHINE GROUP" in world.hud.prompt_label.text, "An active long-range operation must replace stale opening guidance with the direct follow affordance.")
    var follow_focus := world.long_operation_director.get_follow_focus()
    _expect(int(follow_focus.get("member_count", 0)) == active_long_range_members.size(), "The follow focus must represent the complete living long-range formation rather than one arbitrary machine.")
    var expected_center := Vector3.ZERO
    for active_member in active_long_range_members:
        expected_center += active_member.global_position
    expected_center /= float(active_long_range_members.size())
    _expect((follow_focus.get("center", Vector3.INF) as Vector3).distance_to(expected_center) < 0.01, "The follow focus must center the camera on the formation's living midpoint.")
    _expect(float(follow_focus.get("spread", 0.0)) >= 0.0, "The follow focus must expose bounded formation spread for readable camera framing.")
    var checkpoint_id := StringName(world.long_operation_director.active_operation.get("id", &""))
    world._save_game()
    _expect(FileAccess.file_exists(TEST_SAVE_PATH), "The complete-world save hook must write while a long-range group is in flight.")
    world._load_game()
    _expect(StringName(world.long_operation_director.active_operation.get("id", &"")) == checkpoint_id, "Loading must restore the active long-range operation identity.")
    _expect(world.autonomy_director.is_processing(), "Loading an in-flight long-range operation must keep local autonomy processing enabled.")
    _expect(world.autonomy_director.external_operation_member_count() == active_long_range_members.size() + concurrent_outpost_members.size(), "Loading concurrent in-flight operations must restore the union of their explicit team reservations.")
    _expect(StringName(world.outpost_director.operation.get("kind", &"")) == &"haul", "Loading concurrent in-flight operations must restore the autonomous outpost convoy.")
    var restored_outpost_route: PackedVector3Array = world.outpost_director.operation.get("route", PackedVector3Array())
    world.outpost_director.operation["route_index"] = restored_outpost_route.size()
    world.outpost_director._update_operation(0.1)
    world.outpost_director.operation["work_clock"] = 10.0
    world.outpost_director._update_operation(0.1)
    var restored_outpost_return_route: PackedVector3Array = world.outpost_director.operation.get("route", PackedVector3Array())
    world.outpost_director.operation["route_index"] = restored_outpost_return_route.size()
    world.outpost_director._update_operation(0.1)
    _expect(world.outpost_director.operation.is_empty(), "A concurrently restored outpost convoy must physically return and release its reservation.")
    _expect(world.autonomy_director.external_operation_member_count() == active_long_range_members.size(), "Completing the outpost convoy must release only its own team reservation while the long-range formation remains away.")
    var primary_west_route_before_block := world.region_director.route_from_heartforge(&"region.west_grid", world.heartforge.global_position)
    world.long_operation_director.active_operation["anchor"] = primary_west_route_before_block[1]
    world.long_operation_director.active_operation["route_index"] = 2
    var route_blocker := Node3D.new()
    route_blocker.name = "RouteRecoveryOrganicBlocker"
    route_blocker.add_to_group(&"organic_enemies")
    world.add_child(route_blocker)
    route_blocker.global_position = primary_west_route_before_block[1]
    var recovery_direction := primary_west_route_before_block[2] - primary_west_route_before_block[1]
    recovery_direction.y = 0.0
    recovery_direction = recovery_direction.normalized()
    var recovery_lateral := Vector3(-recovery_direction.z, 0.0, recovery_direction.x)
    var left_detour_hazard := Node3D.new()
    left_detour_hazard.name = "RouteRecoveryLeftHazard"
    left_detour_hazard.add_to_group(&"organic_enemies")
    world.add_child(left_detour_hazard)
    left_detour_hazard.global_position = primary_west_route_before_block[1] + recovery_direction * LongRangeOperationDirector3D.ROUTE_RECOVERY_FORWARD_OFFSET - recovery_lateral * LongRangeOperationDirector3D.ROUTE_RECOVERY_LATERAL_OFFSET
    world.long_operation_director._update_active_operation(2.5)
    _expect(int(world.long_operation_director.active_operation.get("route_recovery_count", 0)) == 1, "A sustained organic blockage must trigger one bounded route recovery attempt.")
    _expect(bool(world.long_operation_director.active_operation.get("route_recovery_active", false)), "A route recovery must remain an explicit active formation decision until the side route is cleared.")
    var recovery_beacon := world.operation_detail_director.get_node_or_null("AutonomousRouteRecoveryBeacon") as Node3D
    _expect(recovery_beacon != null and recovery_beacon.visible, "An active route recovery must expose a physical autonomous-detour beacon in the world.")
    if recovery_beacon != null:
        _expect(recovery_beacon.find_child("DetourBaseHousing", true, false) != null and recovery_beacon.find_child("DetourBaseCollar", true, false) != null, "The autonomous detour beacon must have a grounded manufactured housing and collar rather than a floating marker.")
        _expect(recovery_beacon.find_child("DetourDirection00", true, false) != null and recovery_beacon.find_child("DetourDirection03", true, false) != null, "The detour beacon must expose bounded directional plates so the learned side route reads in-world without route editing.")
        var detour_base_core := recovery_beacon.find_child("DetourBaseHousingCore", true, false) as MeshInstance3D
        _expect(detour_base_core != null and detour_base_core.mesh != null and detour_base_core.mesh.get_surface_count() > 0, "The detour beacon housing must use authored beveled geometry for readable close-range presentation.")
    var recovery_target: Vector3 = world.long_operation_director.active_operation.get("route_recovery_target", Vector3.ZERO)
    _expect(recovery_beacon != null and recovery_beacon.global_position.distance_to(recovery_target) < 0.1, "The autonomous-detour beacon must sit on the real inserted recovery waypoint.")
    _expect(int(world.long_operation_director.active_operation.get("route_recovery_side", 0)) == 1, "A bounded recovery must choose the lower-pressure side instead of blindly alternating left and right.")
    _expect(float(world.long_operation_director.active_operation.get("route_recovery_hazard_score", 99.0)) < 0.08, "The selected autonomous detour must record its low local organic-pressure score.")
    var learned_west_route: Variant = world.long_operation_director.route_memory.get("region.west_grid", {})
    _expect(learned_west_route is Dictionary and float((learned_west_route as Dictionary).get("risk", 0.0)) >= 1.0, "A route disruption must become bounded persistent route-risk memory.")
    _expect(learned_west_route is Dictionary and bool((learned_west_route as Dictionary).get("has_block_position", false)), "A route disruption must remember the physical blockage position for future authored-route scoring.")
    _expect(learned_west_route is Dictionary and (learned_west_route as Dictionary).get("last_block_position", Vector3.ZERO).distance_to(route_blocker.global_position) < 0.1, "Route memory must record the actual obstruction position rather than only a region-wide risk value.")
    _expect(learned_west_route is Dictionary and (learned_west_route as Dictionary).get("block_positions", []).size() == 1, "A route disruption must begin a bounded physical blockage history.")
    _expect(world.region_director.route_variant_count(&"region.west_grid") == 2, "The West Grid must expose two authored alternate street routes for segment-aware adaptive selection.")
    _expect(world.long_operation_director._preferred_route_variant(&"region.west_grid") == 2, "A blockage on the primary street must make the clearest authored alternate route the next autonomous preference.")
    var learned_route_preview := world.long_operation_director.route_preview(&"operation.west_grid_survey")
    _expect(int(learned_route_preview.get("route_variant", 0)) == 2, "An operation preview must surface the clearest route-memory alternate selected for the West Grid.")
    _expect(StringName(str(learned_route_preview.get("route_confidence", ""))) == &"guarded", "A route with one remembered disruption must expose a guarded confidence readout before authorization.")
    _expect(str(learned_route_preview.get("route_brief", "")).contains("rail-yard cut-through") and str(learned_route_preview.get("route_brief", "")).contains("waypoint"), "An operation preview must explain the remembered street route and bounded waypoint count.")
    _expect(int(learned_route_preview.get("route_memory_disruptions", 0)) == 1 and str(learned_route_preview.get("route_brief", "")).contains("remembered blockage"), "An operation preview must explain the physical disruption history that shaped its autonomous route.")
    _expect(float(learned_route_preview.get("route_distance", 0.0)) > 0.0, "An operation preview must expose a non-zero physical travel distance.")
    var primary_west_route := world.region_director.route_from_heartforge(&"region.west_grid", world.heartforge.global_position)
    var alternate_west_route := world.region_director.route_from_heartforge_variant(&"region.west_grid", world.heartforge.global_position, 1)
    var clearest_west_route := world.region_director.route_from_heartforge_variant(&"region.west_grid", world.heartforge.global_position, 2)
    _expect(primary_west_route.size() == alternate_west_route.size() and primary_west_route[1] != alternate_west_route[1], "The first alternate route must change the physical street waypoints rather than only renaming the report.")
    _expect(primary_west_route.size() == clearest_west_route.size() and primary_west_route[1] != clearest_west_route[1], "The second alternate route must change the physical street waypoints rather than only renaming the report.")
    var route_contract_regions: Array[StringName] = [
        &"region.north_ruins",
        &"region.west_grid",
        &"region.east_tenements",
        &"region.glasshouse",
        &"region.flood_market",
        &"region.riverworks",
        &"region.tram_graveyard",
        &"region.cathedral_quarter",
        &"region.observatory_ridge",
        &"region.buried_labs",
        &"region.root_cistern",
    ]
    for route_contract_region in route_contract_regions:
        _expect(world.region_director.route_variant_count(route_contract_region) >= 1, "Every discovered town route must expose one bounded alternate route for %s." % String(route_contract_region))
        var primary_contract_route := world.region_director.route_from_heartforge(route_contract_region, world.heartforge.global_position)
        var alternate_contract_route := world.region_director.route_from_heartforge_variant(route_contract_region, world.heartforge.global_position, 1)
        _expect(primary_contract_route.size() == alternate_contract_route.size() and primary_contract_route.size() >= 3 and primary_contract_route[1] != alternate_contract_route[1], "The alternate route for %s must change authored physical waypoints." % String(route_contract_region))
    var recovery_anchor: Vector3 = world.long_operation_director.active_operation.get("anchor", world.heartforge.global_position)
    route_blocker.remove_from_group(&"organic_enemies")
    route_blocker.queue_free()
    left_detour_hazard.remove_from_group(&"organic_enemies")
    left_detour_hazard.queue_free()
    await process_frame
    world.long_operation_director.active_operation["anchor"] = recovery_target
    world.long_operation_director._update_active_operation(0.1)
    _expect(recovery_beacon != null and not recovery_beacon.visible, "The autonomous-detour beacon must clear as soon as the group clears the inserted waypoint.")
    world.long_operation_director._update_active_operation(5.0)
    _expect(world.long_operation_director.active_operation.get("anchor", recovery_anchor).distance_to(recovery_anchor) > 0.1, "A recovered group must resume physical movement instead of remaining frozen at the blockage.")
    world._save_game()
    world._load_game()
    _expect(int(world.long_operation_director.active_operation.get("route_recovery_count", 0)) == 1, "Route-recovery progress must survive an in-flight operation save/load.")
    _expect(int(world.long_operation_director.active_operation.get("route_recovery_side", 0)) == 1, "The selected recovery side must survive an in-flight operation save/load.")
    var restored_west_route_memory: Variant = world.long_operation_director.route_memory.get("region.west_grid", {})
    _expect(restored_west_route_memory is Dictionary and float((restored_west_route_memory as Dictionary).get("risk", 0.0)) >= 1.0, "Learned route-risk memory must survive the unified save/load path.")
    _expect(restored_west_route_memory is Dictionary and bool((restored_west_route_memory as Dictionary).get("has_block_position", false)), "Remembered route blockage state must survive the unified save/load path.")
    _expect(restored_west_route_memory is Dictionary and (restored_west_route_memory as Dictionary).get("last_block_position", Vector3.ZERO).distance_to(recovery_anchor) < 0.1, "The saved route-memory blockage position must restore to the same physical location.")
    _expect(restored_west_route_memory is Dictionary and (restored_west_route_memory as Dictionary).get("block_positions", []).size() == 1, "The bounded physical blockage history must survive the unified save/load path.")
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

    var west_landmark := world.region_director.get_landmark(&"region.west_grid")
    if west_landmark != null:
        west_landmark.set_pressure(1.15)
    var dynamic_pressure_id := &"operation.dynamic.pressure_suppression.region.west_grid"
    var dynamic_route_id := &"operation.dynamic.route_recovery.region.west_grid"
    var dynamic_offers := world.long_operation_director.available_operations()
    _expect(dynamic_offers.any(func(entry: Dictionary) -> bool: return StringName(str(entry.get("id", ""))) == dynamic_pressure_id), "High regional pressure must generate a bounded dynamic suppression proposal.")
    _expect(dynamic_offers.any(func(entry: Dictionary) -> bool: return StringName(str(entry.get("id", ""))) == dynamic_route_id), "Learned route risk must generate a bounded dynamic route-recovery proposal.")
    var dynamic_pressure_entry := world.long_operation_director.operation(dynamic_pressure_id)
    _expect(StringName(str(dynamic_pressure_entry.get("dynamic_template_id", ""))) == &"dynamic.pressure_suppression" and StringName(str(dynamic_pressure_entry.get("region_id", ""))) == &"region.west_grid", "Dynamic proposals must retain stable template and region provenance.")
    _expect(not str(dynamic_pressure_entry.get("generated_from", "")).is_empty() and str(dynamic_pressure_entry.get("description", "")).contains("West Grid"), "Dynamic proposals must explain the world-state cause in player-facing language.")
    var dynamic_route_preview := world.long_operation_director.route_preview(dynamic_route_id)
    _expect(float(dynamic_route_preview.get("route_distance", 0.0)) > 0.0 and int(dynamic_route_preview.get("route_waypoints", 0)) > 0, "Dynamic proposals must use the same physical route preview contract as authored operations.")
    _expect(_complete_operation(world, dynamic_route_id), "A dynamic route-recovery proposal must resolve through the same physical formation and return path.")
    _expect(world.long_operation_director.has_completed(dynamic_route_id), "A completed dynamic proposal must become a stable one-time world record.")
    var dynamic_checkpoint := world.long_operation_director.to_dictionary()
    world.long_operation_director.restore_from_dictionary(dynamic_checkpoint)
    _expect(world.long_operation_director.has_completed(dynamic_route_id), "Completed dynamic proposals must survive operation save/load restoration.")
    _expect(_complete_operation(world, dynamic_pressure_id), "A dynamic pressure proposal must resolve through the same physical formation and return path.")
    _expect(not world.long_operation_director.available_operations().any(func(entry: Dictionary) -> bool: return StringName(str(entry.get("id", ""))) == dynamic_pressure_id or StringName(str(entry.get("id", ""))) == dynamic_route_id), "Dynamic proposals must not become a recurring management queue after resolution.")

    var engineers_before_casualty := world.autonomy_director.count_robots(&"engineer")
    var casualty_machine := world.autonomy_director.living_robots(&"engineer")[0]
    var casualty_identity := casualty_machine.display_identity()
    var casualty_position := world.region_director.center(&"region.west_grid") + Vector3(3.0, 0.0, -2.0)
    casualty_machine.global_position = casualty_position
    casualty_machine.apply_damage(casualty_machine.maximum_health * 2.0)
    world.long_operation_director._sync_casualty_recovery_marker()
    _expect(world.operation_detail_director.is_casualty_recovery_visible(), "A field casualty must expose a visible recovery beacon at the recorded physical position.")
    var casualty_records: Array = world.long_operation_director.to_dictionary().get("casualty_records", [])
    _expect(casualty_records.size() == 1, "A disabled field frame must create one bounded persistent casualty record.")
    var casualty_id := StringName("operation.dynamic.machine_recovery.%s" % str((casualty_records[0] as Dictionary).get("id", "")))
    var casualty_offers := world.long_operation_director.available_operations()
    _expect(casualty_offers.any(func(entry: Dictionary) -> bool: return StringName(str(entry.get("id", ""))) == casualty_id), "A discovered field casualty must generate one recovery proposal.")
    var casualty_entry := world.long_operation_director.operation(casualty_id)
    _expect(StringName(str(casualty_entry.get("dynamic_template_id", ""))) == &"dynamic.machine_recovery", "Recovery proposals must retain their dynamic-template provenance.")
    _expect(StringName(str(casualty_entry.get("generated_from", ""))) == &"disabled_machine", "Recovery proposals must explain that the cause was a disabled machine.")
    _expect(str(casualty_entry.get("display_name", "")).contains(casualty_identity), "The recovery proposal must name the actual disabled machine.")
    var casualty_preview := world.long_operation_director.route_preview(casualty_id)
    _expect(float(casualty_preview.get("route_distance", 0.0)) > 0.0 and int(casualty_preview.get("route_waypoints", 0)) >= 3, "A recovery proposal must expose a physical route to the recorded casualty position.")
    var casualty_snapshot := world.long_operation_director.to_dictionary()
    world.long_operation_director.restore_from_dictionary(casualty_snapshot)
    _expect(world.long_operation_director.casualty_record(StringName(str((casualty_records[0] as Dictionary).get("id", "")))).size() > 0, "Casualty records must survive operation save/load restoration.")
    _expect(_complete_operation(world, casualty_id), "A recovery proposal must travel to the casualty and physically return before restoring the frame.")
    _expect(world.autonomy_director.count_robots(&"engineer") == engineers_before_casualty, "A recovered disabled frame must rejoin its original machine role.")
    _expect(world.long_operation_director.casualty_record(StringName(str((casualty_records[0] as Dictionary).get("id", "")))).is_empty(), "A recovered casualty must clear its one-time field record.")
    _expect(complete_world.story_archive_director.has_record(&"story.machine.first_recovery"), "The first field recovery must preserve a durable machine-witness archive record.")

    _expect(world.progression.purchase(&"tech.heartforge.tier_3"), "West Grid data and one outpost must permit Heartforge tier 3.")
    _expect(world.progression.heartforge_tier == 3, "The run must reach Heartforge tier 3.")
    _expect(world.progression.purchase(&"tech.machine.forge_assistance"), "Tier 3 must permit autonomous ordinary replacement.")
    _expect(world.progression.purchase(&"tech.doctrine.deep_operations"), "Tier 3 must permit deep-operation doctrine.")

    var west_canal_operation := world.long_operation_director.operation(&"operation.west_canal_works_repair")
    _expect(world.long_operation_director.requirements_met(west_canal_operation), "The expanded West Canal Works operation must become actionable after the West Grid survey and tier 3 transition.")
    _expect(_complete_operation(world, &"operation.west_canal_works_repair"), "The expanded West Canal Works operation must travel, work and return through the existing physical operation path.")
    _expect(world.outpost_director.get_site(&"site.west_canal_works").discovered, "The West Canal Works operation must reveal its fixed discovered support site on physical return.")
    _expect(world.region_director.get_landmark(&"region.west_grid").suppression > 0.0, "The West Canal Works operation must apply its authored regional suppression reward.")

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
    var cathedral_bell_yard_operation := world.long_operation_director.operation(&"operation.cathedral_bell_yard_silence")
    _expect(world.long_operation_director.requirements_met(cathedral_bell_yard_operation), "The expanded Cathedral Bell Yard operation must become actionable after the brood suppression and tier 4 transition.")
    _expect(_complete_operation(world, &"operation.cathedral_bell_yard_silence"), "The expanded Cathedral Bell Yard operation must travel, work and return through the existing physical operation path.")
    _expect(world.region_director.get_landmark(&"region.cathedral_quarter").suppression > 0.20, "The Cathedral Bell Yard operation must apply its authored regional suppression reward.")
    _expect(world.adaptive_defense_director != null, "Heartforge tier 4 must install the adaptive defence director.")
    _expect(world.progression.purchase(&"tech.machine.signal_relay"), "Tier 4 and two recovered components must permit Signal Relay research.")
    for _attempt in range(10):
        if world.autonomy_director.count_robots(&"relay") >= 1:
            break
        world.machine_society_director.fabrication_clock = 0.0
        world.machine_society_director._evaluate_society()
    _expect(world.autonomy_director.count_robots(&"relay") >= 1, "Signal Relay research must let the machine society fabricate one relay automatically without a production queue.")
    var companion_before_release_save := world.autonomy_director.living_robots(&"companion")[0]
    companion_before_release_save.callsign = "Bulwark-Archive"
    var archive_records_before_release_save := complete_world.story_archive_director.record_count()
    world._save_game()
    world._load_game()
    _expect(world.autonomy_director.count_robots(&"relay") >= 1, "The Signal Relay chassis must survive the unified release save/load path.")
    var restored_companion := world.autonomy_director.living_robots(&"companion")[0]
    _expect(restored_companion.display_identity() == "Bulwark-Archive", "Robot callsigns must survive the release save/load path instead of being masked by the default Bulwark fallback.")
    _expect(complete_world.story_archive_director.record_count() >= archive_records_before_release_save, "Town Archive records must survive the release save/load path.")
    _expect(complete_world.story_archive_director.has_record(&"story.machine.first_return") and complete_world.story_archive_director.has_record(&"story.machine.first_replacement"), "Machine-witness archive records must survive the release save/load path.")
    _expect(world.operations_hud.is_open() and world.operations_hud.mode == &"recap", "Loading a complete release snapshot must present the multi-session world recap.")
    _expect(world.operations_hud.current_operation_status.contains("WORLD CONDITION"), "The world recap must retain the stable run condition alongside the Heartforge status.")
    _expect(world.operations_hud.description_label.text.contains("CURRENT UNRESOLVED PROBLEM") and world.operations_hud.description_label.text.contains("ACTIVE OR PROPOSED EXPEDITION"), "The world recap must restore the strategic problem and expedition context in one readable surface.")
    _expect(world.operations_hud.requirements_label.text.contains("NEXT AVAILABLE MAJOR CHOICES"), "The world recap must expose the next major choices without opening a management dashboard.")
    _expect(not world.operations_hud.authorize_button.visible, "The world recap must remain read-only and cannot authorize an operation accidentally.")
    _expect(world.operations_hud.backdrop.color.a >= 0.9, "Strategic readouts must sufficiently occlude persistent HUD toasts so the fixed close footer remains readable.")
    if world.localization_service != null:
        _expect(world.localization_service.set_locale(&"sv"), "The complete-game recap localization check must be able to select Swedish.")
        world._show_session_recap()
        var recap_review_capture_path := _recap_review_capture_argument()
        if not recap_review_capture_path.is_empty():
            await process_frame
            var recap_review_image := world.get_viewport().get_texture().get_image()
            var recap_review_error := recap_review_image.save_png(recap_review_capture_path)
            _expect(recap_review_error == OK, "The live Swedish recap review must write its requested screenshot.")
        _expect(world.operations_hud.current_operation_status.contains("VÄRLDSFÖRHÅLLANDE") and world.operations_hud.current_operation_status.contains("HJÄRTSMEDJAN"), "The Swedish world recap must localize its stable condition and Heartforge status instead of leaving the strategic summary in English.")
        _expect(world.operations_hud.description_label.text.contains("tryck") or world.operations_hud.description_label.text.contains("TRYCK"), "The Swedish world recap must localize the regional pressure summary.")
        _expect(world.operations_hud.description_label.text.contains("AKTUELLT OLÖST PROBLEM") and world.operations_hud.description_label.text.contains("AKTIV ELLER FÖRESLAGEN EXPEDITION") and world.operations_hud.description_label.text.contains("NYLIGEN OBSERVERADE OKÄNDA HOT"), "The Swedish world recap must localize every section heading.")
        _expect(not world.operations_hud.description_label.text.contains("CURRENT UNRESOLVED PROBLEM") and not world.operations_hud.description_label.text.contains("ACTIVE OR PROPOSED EXPEDITION") and not world.operations_hud.description_label.text.contains("UNFAMILIAR THREATS RECENTLY OBSERVED") and not world.operations_hud.description_label.text.contains("FOLLOW THE ACTIVE MACHINE GROUP") and not world.operations_hud.description_label.text.contains("Press F"), "The Swedish world recap must not leak stale English objective copy into the localized surface.")
        _expect(not world.operations_hud.requirements_label.text.contains("PRESS ") and not world.operations_hud.requirements_label.text.contains("FOLLOW THE ACTIVE MACHINE GROUP") and not world.operations_hud.requirements_label.text.contains("HOLD THE HEARTFORGE"), "The Swedish world recap must localize its next-action prompt instead of copying the English HUD prompt.")
        _expect(world.localization_service.set_locale(&"en"), "The complete-game recap localization check must restore English.")
        world._show_session_recap()
    world._close_operations_hud()
    world.heartforge.current_health = world.heartforge.maximum_health * 0.72
    world.heartforge.health_changed.emit(world.heartforge.current_health, world.heartforge.maximum_health)
    world.adaptive_defense_director.evaluate_now()
    _expect(world.adaptive_defense_director.has_pending_proposal(), "Observed Heartforge damage must create one exceptional adaptive defence proposal.")
    world._update_complete_game_objective()
    _expect(world.hud.objective_label.text.to_lower().find("adaptation") >= 0, "A pending adaptive proposal must replace stale opening or progression guidance with a Heartforge decision objective.")
    _expect(world.hud.prompt_label.text.to_lower().find("press t") >= 0, "A pending adaptive proposal must expose its strategic review action in the live prompt.")
    var pending_adaptation_preview := world.heartforge.get_node_or_null("HeartforgeModel/HeartforgeAdaptationPreview") as Node3D
    _expect(pending_adaptation_preview != null and pending_adaptation_preview.visible, "A pending adaptive proposal must mark its affected Heartforge perimeter without changing gameplay geometry.")
    _expect(world.heartforge.find_child("AdaptationPreviewRing", true, false) != null, "A pending adaptive proposal must expose a bounded physical footprint before construction begins.")
    _expect(world.heartforge.find_child("AdaptationWorksiteCrew", true, false) != null, "A pending adaptive proposal must expose the bounded autonomous construction crew.")
    _expect(world.adaptive_defense_director.available_plans().size() == 3, "The architect must present three broad structural principles rather than a tuning panel.")
    world._open_evolution_hud()
    _expect(world.strategic_hud.is_open() and world.strategic_hud.mode == &"adaptation", "A pending adaptive proposal must reuse the strategic surface instead of opening a permanent dashboard.")
    _expect(world.strategic_hud.detail_label.text.contains("Trade-off"), "Each adaptive proposal must explain its accepted trade-off before authorization.")
    var chosen_adaptation := world.strategic_hud.selected_adaptation_id()
    _expect(chosen_adaptation != &"", "The adaptive defence surface must expose a stable selected plan id.")
    world._authorize_adaptation(chosen_adaptation)
    _expect(not world.adaptive_defense_director.active_adaptation.is_empty(), "Authorizing an adaptive response must start an autonomous Heartforge construction operation.")
    world._update_complete_game_objective()
    _expect(world.hud.objective_label.text.to_lower().find("heartforge") >= 0 and world.hud.objective_label.text.to_lower().find("recover your first scrap") == -1, "An active adaptive retrofit must replace stale opening guidance while machines build the response.")
    _expect(world.hud.prompt_label.text.to_lower().find("building") >= 0, "An active adaptive retrofit must expose its machine-building state in the live prompt.")
    var construction_preview := world.heartforge.get_node_or_null("HeartforgeModel/HeartforgeAdaptationPreview") as Node3D
    _expect(construction_preview != null and construction_preview.visible, "An authorized adaptive response must keep a visible physical construction preview during the machine-run interval.")
    _expect(world.heartforge.find_child("AdaptationBuilderTool00", true, false) != null, "An authorized adaptive response must retain visible machine tooling during construction.")
    var initial_visible_adaptation_pieces := world.heartforge.adaptation_preview_visible_piece_count()
    var preview_scale_before := construction_preview.scale if construction_preview != null else Vector3.ZERO
    world.adaptive_defense_director._process(2.0)
    _expect(world.heartforge.adaptation_preview_progress > 0.0 and world.heartforge.adaptation_preview_progress < 1.0, "Adaptive construction progress must drive a bounded intermediate Heartforge presentation state.")
    _expect(construction_preview != null and not preview_scale_before.is_equal_approx(construction_preview.scale), "The adaptive construction footprint must visibly advance as the machine operation progresses.")
    world.adaptive_defense_director._process(6.0)
    _expect(world.heartforge.adaptation_preview_visible_piece_count() > initial_visible_adaptation_pieces, "Adaptive construction must reveal retrofit pieces progressively without hiding the autonomous worksite crew.")
    var adaptation_checkpoint := world.adaptive_defense_director.to_dictionary()
    world.adaptive_defense_director.restore_from_dictionary(adaptation_checkpoint)
    _expect(not world.adaptive_defense_director.active_adaptation.is_empty(), "An in-progress Heartforge adaptation must survive save/load.")
    var adaptation_data: Dictionary = world.adaptive_defense_director.active_adaptation.get("data", {})
    world.adaptive_defense_director._process(float(adaptation_data.get("build_seconds", 12.0)) + 0.1)
    _expect(world.adaptive_defense_director.completed_adaptation == chosen_adaptation, "The selected Heartforge adaptation must complete after its machine-run construction interval.")
    _expect(world.heartforge.get_node_or_null("HeartforgeModel/HeartforgeAdaptationPreview") == null, "The temporary adaptive construction preview must resolve when the authored retrofit completes.")
    _expect(world.heartforge.get_node_or_null("HeartforgeModel/HeartforgeAdaptationDetail") != null, "The completed adaptation must leave a visible high-definition Heartforge detail layer.")
    _expect(world.heartforge.adaptive_collision_shape_count() > 0, "The completed adaptive response must leave a bounded physical shell layer, not only a visual retrofit.")
    var adaptation_snapshot := world.adaptive_defense_director.to_dictionary()
    world.adaptive_defense_director.restore_from_dictionary(adaptation_snapshot)
    _expect(world.adaptive_defense_director.completed_adaptation == chosen_adaptation, "The completed adaptive response must persist as a stable run choice.")
    _expect(world.heartforge.adaptive_collision_shape_count() > 0, "Restoring a completed adaptive response must rebuild its physical shell layer.")
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
    _expect(world.endgame_director.active_protocol.get("remote_support_site_id", "") != "", "The final protocol must assign a persistent remote relay support site.")
    _expect(int(world.endgame_director.active_protocol.get("remote_outposts_min", 0)) == 2, "Severance must declare its minimum autonomous remote relay support.")
    _expect(world.endgame_escalation_director != null, "The final protocol must have a dedicated bounded presentation director.")
    _expect(world.endgame_escalation_director.current_state == &"active", "Starting a final protocol must raise its Heartforge lattice presentation.")
    _expect(world.get_node_or_null("EndgameProtocolVisuals") != null, "The final protocol must attach a visible lattice to the Heartforge without changing collision geometry.")
    world._update_camera(0.2)
    _expect(world.camera.global_position.distance_to(world.heartforge.global_position) > 15.0, "The active final protocol must use a calm establishing camera distance so the Heartforge lattice and surviving cast remain readable.")
    _expect(world.endgame_escalation_director.core_light != null and world.endgame_escalation_director.core_light.light_energy <= 4.0, "The final protocol light budget must preserve readable Heartforge silhouettes instead of blooming over the frame.")
    var capstone_visuals := world.get_node_or_null("EndgameProtocolVisuals") as Node3D
    _expect(capstone_visuals != null and capstone_visuals.global_position.distance_to(world.heartforge.global_position) > 1.5, "The final protocol capstone must anchor toward the player-facing side of the Heartforge so its transformation remains visible.")
    var protocol_lattice := world.get_node_or_null("EndgameProtocolVisuals/ProtocolLattice") as Node3D
    var protocol_spines := protocol_lattice.find_children("ProtocolSpine*", "MeshInstance3D", true, false) if protocol_lattice != null else []
    _expect(protocol_spines.size() == 6, "The active final lattice must use six rounded perimeter spines so it frames rather than cages the tactical cast.")
    _expect(world.hud.operation_badge != null and not world.hud.operation_badge.visible, "The final crisis must keep one live protocol status in the resource panel instead of duplicating it in a bottom badge.")
    world.endgame_director._process(0.1)
    _expect(world.endgame_escalation_director.current_progress > 0.0, "Final protocol progress must drive the visual lattice continuously.")
    _expect(world.endgame_director.remote_support_progress() > 0.0 and world.endgame_director.homefront_hold_progress() == 0.0, "The final protocol must begin with a remote relay phase before the home-front hold.")
    var severance := world.endgame_director.protocol(&"protocol.severance")
    world.hud.push_notification("STALE MACHINE REPORT")
    world.hud.set_prompt("STALE INTERACTION PROMPT")
    world.endgame_director._process(float(severance.get("duration_seconds", 210.0)) + 1.0)
    _expect(world.endgame_director.completed_protocol == &"protocol.severance", "The final protocol must complete after its sustained defence interval.")
    _expect(world.endgame_director.remote_support_progress() >= 0.999 and world.endgame_director.homefront_hold_progress() >= 0.999, "Victory must require both remote relay support and a completed Heartforge hold.")
    _expect(world.endgame_escalation_director.current_state == &"completed", "Final protocol completion must resolve the crisis lattice into the sanctuary crown.")
    var severance_crown := world.get_node("EndgameProtocolVisuals/SanctuaryCrown") as Node3D
    _expect(severance_crown != null and severance_crown.visible, "The completed protocol must leave a calm capstone presentation at the Heartforge.")
    _expect(severance_crown != null and severance_crown.scale.x <= 0.64 and world.endgame_escalation_director.core_light.light_energy <= 0.9, "The completed sanctuary crown must remain a compact, restrained backdrop instead of blooming over the surviving cast.")
    _expect(world.first_victory_achieved, "Completing a final protocol must produce the first victory.")
    _expect(world.game_ended, "The complete systemic run must have a real end state.")
    _expect(world.hud.has_method(&"set_sanctuary_integrity") and world.hud.sanctuary_integrity >= 0.7, "The first-victory frame must clear the active crisis damage badge instead of carrying stale sanctuary damage into the ending.")
    _expect(world.hud.operation_label.text.find("%") == -1 and (world.hud.operation_label.text.to_lower().find("victory") >= 0 or world.hud.operation_label.text.to_lower().find("sieg") >= 0), "First victory must replace the stale active-protocol percentage in the live resource panel.")
    _expect(world.hud.objective_label.text.to_lower().find("victory") >= 0 or world.hud.objective_label.text.to_lower().find("sieg") >= 0, "First victory must replace the active hold-the-Heartforge objective.")
    _expect(world.hud.ending_panel != null and world.hud.ending_panel.visible, "First victory must expose the continuing-sanctuary ending surface.")
    var victory_detail_label := world.hud.ending_panel.get_node("PanelContent").get_child(0) as Label
    _expect(victory_detail_label != null and victory_detail_label.text.contains("STRATEGIC LEGACY") and victory_detail_label.text.contains("Remote support posts"), "First victory must explain the doctrine, remote support and machine legacy that shaped the completed run.")
    _expect(world.hud.notifications.is_empty() and not world.hud.notification_panel.visible, "First victory must clear stale machine-report toasts before showing the ending surface.")
    _expect(not world.hud.prompt_panel.visible and world.hud.prompt_label.text.is_empty(), "First victory must clear stale interaction guidance so the ending surface owns the continuation prompt.")
    _expect(not world.long_operation_director.available_operations().any(func(entry: Dictionary) -> bool: return StringName(str(entry.get("id", ""))) == &"operation.post_victory_archive"), "The post-victory archive must remain unavailable behind the victory boundary until continuation is chosen.")
    world.hud.show_ending(true, "The signal collapses. Organisms remain in the streets, but the intelligence coordinating them is gone. The machines inherit a wounded, survivable town.", true)
    var ending_panel := world.hud.ending_panel
    var ending_label := ending_panel.get_node("PanelContent").get_child(0) as Label
    _expect(ending_label != null and ending_label.text.to_lower().find("continue") >= 0, "The victory ending surface must own the explicit continuation prompt.")
    _expect(ending_label != null and ending_label.text.count("\n") >= 4, "The victory overlay must wrap its long ending copy into readable lines.")
    var ending_style := ending_panel.get_theme_stylebox("panel") as StyleBoxFlat
    _expect(ending_style != null and ending_style.bg_color.a >= 0.9 and ending_style.border_color.g > ending_style.border_color.r, "The victory overlay must use an opaque sanctuary panel with a restrained cyan edge.")
    _expect(ending_label != null and ending_label.get_theme_constant("outline_size") >= 3, "The victory overlay text must retain an outline against the live world.")
    _expect(ending_panel.offset_left < 0.0 and ending_panel.offset_right > 0.0 and ending_panel.offset_top < 0.0 and ending_panel.offset_bottom > 0.0, "The victory overlay must stay centered inside the viewport-safe offsets.")
    world.hud.dismiss_ending()

    var report_scrap := world.run_state.scrap
    var report_high_water_mark := world.run_state.scrap_high_water_mark
    var report_last_scrap_total := world.run_state.last_scrap_total
    var report_decline_steps := world.run_state.scrap_decline_steps
    var report_decline := world.run_state.first_sustained_resource_decline.duplicate(true)
    world.run_state.observe_organic_species(&"razorhound", &"hunt", &"region.west_grid")
    world.run_state.observe_organic_species(&"razorhound", &"track_last_known", &"region.west_grid")
    world.run_state.scrap = 300
    world.run_state.scrap_high_water_mark = 300
    world.run_state.last_scrap_total = 300
    world.run_state.scrap_decline_steps = 0
    world.run_state.spend_scrap(80)
    world.run_state.spend_scrap(80)
    world.run_state.spend_scrap(80)
    var collapse_report := world._build_collapse_report()
    _expect(collapse_report.contains("Razorhound") and collapse_report.contains("hunt") and collapse_report.contains("track last known"), "The collapse report must use persistent species and behaviour observations rather than only live enemies.")
    _expect(collapse_report.contains("FIRST SUSTAINED RESOURCE DECLINE") and not world.run_state.first_sustained_resource_decline.is_empty(), "The collapse report must identify the first sustained resource decline.")
    world.hud.show_failure_report(collapse_report)
    var collapse_panel := world.hud.ending_panel
    var collapse_label := collapse_panel.get_node("PanelContent").get_child(0) as Label
    _expect(collapse_label != null and collapse_label.text.contains("POST-COLLAPSE REPORT") and collapse_label.text.contains("UNRESOLVED THREAT"), "The defeat boundary must expose a readable causal post-collapse report.")
    _expect(collapse_label != null and collapse_label.text.contains("STRATEGIC DOCTRINE") and collapse_label.text.contains("REMOTE SUPPORT"), "The defeat report must identify the doctrine and remote-support preparation that shaped the failed run.")
    _expect(bool(collapse_panel.get_meta("expanded_report", false)), "The causal report must use an expanded, viewport-safe reading surface rather than clipping the timeline.")
    world.hud.dismiss_ending()
    if world.localization_service != null:
        _expect(world.localization_service.set_locale(&"sv"), "The collapse-report localization check must be able to select Swedish.")
        var localized_collapse_report := world._build_collapse_report()
        _expect(localized_collapse_report.contains("VÄRLDSDURATION") and localized_collapse_report.contains("OLÖST HOT") and localized_collapse_report.contains("RESURSSTATUS") and localized_collapse_report.contains("STRATEGISK DOKTRIN") and localized_collapse_report.contains("FJÄRRSTÖD"), "The Swedish collapse report must localize its structural headings.")
        _expect(not localized_collapse_report.contains("WORLD DURATION") and not localized_collapse_report.contains("UNRESOLVED THREAT") and not localized_collapse_report.contains("RESOURCE POSITION"), "The Swedish collapse report must not leak English structural headings.")
        _expect(world.localization_service.set_locale(&"en"), "The collapse-report localization check must restore English.")
    world.run_state.scrap = report_scrap
    world.run_state.scrap_high_water_mark = report_high_water_mark
    world.run_state.last_scrap_total = report_last_scrap_total
    world.run_state.scrap_decline_steps = report_decline_steps
    world.run_state.first_sustained_resource_decline = report_decline
    world.run_state.scrap_changed.emit(world.run_state.scrap)

    var continue_event := InputEventKey.new()
    continue_event.keycode = KEY_ENTER
    continue_event.pressed = true
    world._unhandled_input(continue_event)
    _expect(not world.game_ended and world.sanctuary_continuation, "The victory boundary must support an explicit continuation into the living sanctuary.")
    _expect(world.hud.ending_panel != null and not world.hud.ending_panel.visible, "Continuing after victory must hide the ending surface without tearing down the HUD canvas.")
    _expect(world.hud.visible, "Continuing after victory must leave the tactical HUD visible.")
    await process_frame
    var continued_city := world.get_node_or_null("ProceduralUrbanDistrict") as Node3D
    _expect(continued_city != null and continued_city.visible, "Continuing after victory must keep the authored urban world visible (exists=%s, visible=%s, in_tree=%s)." % [continued_city != null, continued_city.visible if continued_city != null else false, continued_city.is_inside_tree() if continued_city != null else false])
    _expect(world.release_world_art != null and world.release_world_art.dressing_root != null and world.release_world_art.dressing_root.visible and world.release_world_art.dressing_root.is_visible_in_tree(), "Continuing after victory must keep the release presentation dressing visible with the living sanctuary.")
    _expect(world.get_node_or_null("Heartforge") is Node3D and (world.get_node("Heartforge") as Node3D).visible, "Continuing after victory must keep the Heartforge visible.")
    _expect(world.get_node_or_null("HeartforgeVerticalSlice") is Node3D and (world.get_node("HeartforgeVerticalSlice") as Node3D).visible, "Continuing after victory must keep the representative sanctuary slice visible.")
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
    _expect(int(endgame_save.get("schema_version", 0)) >= 2, "Endgame saves must version the remote-relay and home-front phase state.")

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

    var fourth_site := world.outpost_director.get_site(&"site.west_substation")
    _expect(fourth_site != null, "The complete run must retain a fourth discovered site for the widest final protocol.")
    if fourth_site != null:
        fourth_site.set_discovered(true)
        if not fourth_site.has_outpost():
            world.outpost_director._spawn_outpost(fourth_site, &"defence", 1)
    _expect(_functioning_outposts(world) >= 4, "Transformation must require and receive the widest autonomous relay network.")
    world.run_state.scrap = 5000
    world.run_state.rare_cores = 20
    world.run_state.scrap_changed.emit(world.run_state.scrap)
    world.run_state.rare_cores_changed.emit(world.run_state.rare_cores)
    world.endgame_director.completed_protocol = &""
    world.endgame_director.active_protocol.clear()
    world.first_victory_achieved = false
    world.game_ended = false
    _expect(world.progression.purchase(&"tech.endgame.transformation"), "The complete run must support researching the third Transformation protocol.")
    _expect(world.endgame_director.available_protocols().any(func(entry: Dictionary) -> bool: return StringName(str(entry.get("id", ""))) == &"protocol.transformation"), "Transformation must appear only after its full research and relay prerequisites are met.")
    _expect(world.endgame_director.initiate(&"protocol.transformation"), "The player must be able to initiate the third Transformation path deliberately.")
    _expect(int(world.endgame_director.active_protocol.get("remote_outposts_min", 0)) == 4, "Transformation must declare its four-post autonomous relay requirement.")
    _expect(world.get_node_or_null("EndgameProtocolVisuals/ProtocolLattice/ProtocolLivingLoopA") != null and world.get_node_or_null("EndgameProtocolVisuals/ProtocolLattice/ProtocolLivingLoopB") != null, "Transformation must expose its distinct living-partnership lattice presentation.")
    var transformation := world.endgame_director.protocol(&"protocol.transformation")
    world.endgame_director._process(float(transformation.get("duration_seconds", 260.0)) + 1.0)
    _expect(world.endgame_director.completed_protocol == &"protocol.transformation", "Transformation must complete after its sustained, lower-pressure defence interval.")
    _expect(world.first_victory_achieved, "Completing Transformation must produce the first victory state.")
    _expect(world.get_node_or_null("EndgameProtocolVisuals/SanctuaryCrown/SanctuaryLivingLoop") != null, "Transformation victory must leave a distinct living-loop sanctuary capstone.")
    var sanctuary_crown := world.get_node_or_null("EndgameProtocolVisuals/SanctuaryCrown") as Node3D
    _expect(sanctuary_crown != null and sanctuary_crown.scale.x <= 0.82, "The completed sanctuary crown must remain a readable backdrop instead of covering the surviving cast.")

    world.endgame_director.completed_protocol = &""
    world.first_victory_achieved = false
    for site in world.outpost_director.discovered_sites():
        if site.has_functioning_outpost():
            site.outpost.apply_damage(9999.0)
    _expect(not world.endgame_director.can_initiate(&"protocol.severance"), "A final protocol must remain unavailable when its autonomous remote relay support has been destroyed.")

    # Signal Lattice is the late-game autonomy gate for parallel long-range
    # work. Keep the player-facing model bounded: two independent formations,
    # one primary follow focus, and no second management dashboard.
    for relay_site in world.outpost_director.discovered_sites():
        if relay_site.has_outpost() and relay_site.outpost != null and not relay_site.outpost.is_alive():
            relay_site.outpost.rebuild()
    if not world.progression.has_technology(&"tech.machine.signal_lattice"):
        _expect(world.progression.purchase(&"tech.machine.signal_lattice"), "Signal Lattice must be researchable before parallel long-range autonomy is used.")
    _expect(world.long_operation_director.active_operation_limit() == 2, "Signal Lattice must raise long-range capacity to exactly two formations.")
    var parallel_operation_ids: Array[StringName] = [&"operation.east_tenement_roofline", &"operation.west_transformer_repair"]
    for parallel_operation_id in parallel_operation_ids:
        _expect(not world.long_operation_director.has_completed(parallel_operation_id), "The parallel-operation fixture must retain an unresolved authored objective: %s." % parallel_operation_id)
    _expect(world.long_operation_director.authorize(parallel_operation_ids[0]), "The first late parallel long-range formation must authorize normally.")
    _expect(world.long_operation_director.authorize(parallel_operation_ids[1]), "Signal Lattice must authorize a second disjoint long-range formation.")
    _expect(world.long_operation_director.active_operation_count() == 2, "Two long-range formations must remain active as separate operation records.")
    var first_parallel_members: Array[RobotUnit3D] = []
    first_parallel_members.append_array(world.long_operation_director.active_operations[0].get("members", []))
    var second_parallel_members: Array[RobotUnit3D] = []
    second_parallel_members.append_array(world.long_operation_director.active_operations[1].get("members", []))
    for first_member in first_parallel_members:
        _expect(first_member not in second_parallel_members, "Parallel long-range formations must reserve disjoint machine teams.")
    _expect(world.autonomy_director.external_operation_member_count() == first_parallel_members.size() + second_parallel_members.size(), "Parallel long-range reservations must remain the union of both physical teams.")
    var first_follow_id := world.long_operation_director.follow_operation_id()
    var cycled_follow := world.long_operation_director.cycle_follow_operation()
    _expect(not cycled_follow.is_empty(), "Parallel long-range formations must expose a followable focus.")
    _expect(StringName(str(cycled_follow.get("id", ""))) != first_follow_id, "The follow-focus cycle must move the camera target to the other independent formation.")
    _expect(int(cycled_follow.get("count", 0)) == 2, "The follow-focus cycle must report the bounded active group count.")
    var parallel_snapshot := world.long_operation_director.to_dictionary()
    _expect((parallel_snapshot.get("active_operations", []) as Array).size() == 2, "Parallel long-range save state must serialize both independent formations.")
    world.long_operation_director.restore_from_dictionary(parallel_snapshot)
    _expect(world.long_operation_director.active_operation_count() == 2, "Parallel long-range save/load must restore both independent formations.")
    _expect(world.long_operation_director.follow_operation_id() == StringName(str(world.long_operation_director.active_operations[0].get("id", ""))), "Save/load must return the follow camera to the stable primary formation.")
    _expect(world.autonomy_director.external_operation_member_count() == first_parallel_members.size() + second_parallel_members.size(), "Parallel long-range save/load must restore both team reservations.")
    if world.localization_service != null:
        world.localization_service.set_locale(&"de")
        var localized_parallel_summary := world._localized_long_operations_summary()
        _expect("Langstreckengruppen" in localized_parallel_summary and "long-range" not in localized_parallel_summary, "The active parallel-operation summary must use the selected release locale.")
        world.localization_service.set_locale(&"en")
    var first_parallel_id := StringName(str(world.long_operation_director.active_operations[0].get("id", "")))
    var second_parallel_id := StringName(str(world.long_operation_director.active_operations[1].get("id", "")))
    _expect(_finish_active_operation(world, first_parallel_id), "The first parallel long-range formation must complete through its physical return path.")
    world.long_operation_director.active_operation = world.long_operation_director.active_operations[1]
    _expect(_finish_active_operation(world, second_parallel_id), "The second parallel long-range formation must complete independently through its physical return path.")
    _expect(world.long_operation_director.active_operation_count() == 0, "Parallel long-range completion must release both operation records without leaving a stale active alias.")

    _finish()


func _recap_review_capture_argument() -> String:
    var arguments := OS.get_cmdline_args()
    arguments.append_array(OS.get_cmdline_user_args())
    for raw_argument in arguments:
        var argument := str(raw_argument)
        if argument.begins_with("--recap-review-screenshot="):
            return argument.get_slice("=", 1)
    return ""


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
