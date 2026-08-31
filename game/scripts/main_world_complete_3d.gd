class_name IronwrightCompleteGameWorld3D
extends IronwrightFullGameWorld3D

const REGION_ATMOSPHERE_SCRIPT := preload("res://scripts/presentation/region_atmosphere_director_3d.gd")
const REGION_LOD_SCRIPT := preload("res://scripts/presentation/region_presentation_lod_director_3d.gd")
const ENDGAME_ESCALATION_SCRIPT := preload("res://scripts/presentation/endgame_escalation_director_3d.gd")
const REGION_ENCOUNTER_SCRIPT := preload("res://scripts/presentation/region_encounter_dressing_director_3d.gd")
const STORY_ARCHIVE_SCRIPT := preload("res://scripts/systems/story_archive_director_3d.gd")
const ADAPTIVE_DEFENSE_SCRIPT := preload("res://scripts/systems/adaptive_defense_director_3d.gd")

var region_director: WorldRegionDirector3D
var region_atmosphere_director: RegionAtmosphereDirector3D
var region_lod_director: RegionPresentationLodDirector3D
var endgame_escalation_director: EndgameEscalationDirector3D
var region_encounter_dressing_director: RegionEncounterDressingDirector3D
var story_archive_director: StoryArchiveDirector3D
var long_operation_director: LongRangeOperationDirector3D
var machine_society_director: MachineSocietyDirector3D
var strategic_ecology_director: StrategicEcologyDirector3D
var endgame_director: EndgameDirector3D
var operations_hud: OperationsCommandHUD3D
var adaptive_defense_director: AdaptiveDefenseDirector3D
var continuity_used: bool = false
var first_victory_achieved: bool = false
var sanctuary_continuation: bool = false
var adaptive_defense_review_capture_path: String = ""
var adaptive_defense_review_capture_frames: int = 0
var spawned_region_salvage: Dictionary = {}
var machine_relationship_moments: Dictionary = {}
var _current_objective_title: String = ""
var _current_objective_detail: String = ""
var _current_objective_prompt: String = ""


func _ready() -> void:
    super._ready()
    _setup_complete_game_services()
    _connect_complete_game_services()
    progression.set_context_provider(Callable(self, "_progression_context"))
    refresh_input_legend()
    run_state.log_event("The complete systemic run is active. Survive, expand autonomy, recover the root components, and choose how the town ends.")
    hud.push_notification(_localized_text("notification.complete.systems_online", "TOWN NETWORKS OPEN · P LONG-RANGE OPERATIONS · V FINAL PROTOCOLS"))
    hud.push_notification(_localized_text("notification.complete.bulwark_online", "BULWARK ONLINE · THE HEARTFORGE HAS A PERSONAL GUARD"))


func _process(delta: float) -> void:
    super._process(delta)
    if operations_hud == null or long_operation_director == null or endgame_director == null:
        return
    operations_hud.update_operations(
        long_operation_director.available_operations(),
        _localized_long_operations_summary(),
        long_operation_director.has_active_operations(),
        long_operation_director.active_operation_count(),
        long_operation_director.active_operation_limit()
    )
    operations_hud.update_protocols(endgame_director.available_protocols(), endgame_director.status_summary())
    if adaptive_defense_director != null:
        strategic_hud.update_adaptation(adaptive_defense_director.available_plans(), adaptive_defense_director.proposal_summary())

    if game_ended:
        return

    if not endgame_director.active_protocol.is_empty():
        var protocol_status := _localized_endgame_status_summary()
        hud.set_operation(protocol_status)
        # The resource panel already carries the live protocol percentage. A
        # second bottom badge duplicates that status and competes with the
        # hold-the-Heartforge prompt during the final crisis.
        hud.set_operation_badge("", false)
    elif not long_operation_director.active_operation.is_empty():
        var operation_status := _localized_long_operation_summary()
        hud.set_operation(operation_status)
        hud.set_operation_badge(operation_status, true, _localized_text("hud.active_operation_prefix", "ACTIVE OPERATION"))
    else:
        hud.set_operation("No remote operation")
        hud.set_operation_badge("", false)

    if not game_ended:
        _update_complete_game_objective()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        var key_event := event as InputEventKey
        var key := key_event.keycode

        if operations_hud != null and operations_hud.is_open():
            match key:
                KEY_ESCAPE, KEY_L, KEY_P, KEY_V:
                    _close_operations_hud()
                KEY_LEFT:
                    operations_hud.select_previous()
                KEY_RIGHT:
                    operations_hud.select_next()
                KEY_ENTER, KEY_SPACE:
                    if operations_hud.mode == &"recap":
                        return
                    if operations_hud.mode == &"endgame":
                        _initiate_protocol(operations_hud.selected_protocol_id())
                    else:
                        _authorize_long_operation(operations_hud.selected_operation_id())
            return

        if game_ended and first_victory_achieved and key in [KEY_ENTER, KEY_SPACE]:
            sanctuary_continuation = true
            game_ended = false
            hud.dismiss_ending()
            if has_method(&"_restore_sanctuary_continuation_presentation"):
                call(&"_restore_sanctuary_continuation_presentation")
            hud.push_notification(_localized_text("notification.complete.sanctuary_continues", "SANCTUARY CONTINUES · THE FIRST ARCHIVE IS NOW AVAILABLE THROUGH P"))
            return

        if not paused and not game_ended and not hud.forge_open and not strategic_hud.is_open():
            if key == KEY_P:
                _open_operations_hud()
                return
            if key == KEY_V:
                _open_endgame_hud()
                return
            if key == KEY_L:
                _open_story_archive()
                return
            if key == KEY_G:
                _cycle_follow_operation()
                return

    super._unhandled_input(event)


func _setup_complete_game_services() -> void:
    region_director = WorldRegionDirector3D.new()
    region_director.name = "WorldRegionDirector"
    region_director.process_mode = Node.PROCESS_MODE_PAUSABLE
    region_director.configure(self)
    add_child(region_director)

    story_archive_director = STORY_ARCHIVE_SCRIPT.new() as StoryArchiveDirector3D
    story_archive_director.name = "StoryArchiveDirector"
    story_archive_director.process_mode = Node.PROCESS_MODE_ALWAYS
    story_archive_director.configure(run_state, region_director)
    story_archive_director.record_unlocked.connect(_on_story_record_unlocked)
    story_archive_director.thread_advanced.connect(_on_story_thread_advanced)
    add_child(story_archive_director)
    for raw_landmark in region_director.landmarks.values():
        var landmark := raw_landmark as RegionLandmark3D
        if landmark != null:
            landmark.connect_story_archive(story_archive_director)
    var aesthetic := get_node_or_null("AestheticDirector") as AestheticDirector3D
    if aesthetic != null:
        aesthetic.connect_story_archive(story_archive_director)
    story_archive_director.connect_event_source(autonomy_director)
    story_archive_director.connect_event_source(outpost_director)

    region_atmosphere_director = REGION_ATMOSPHERE_SCRIPT.new() as RegionAtmosphereDirector3D
    region_atmosphere_director.name = "RegionAtmosphereDirector"
    region_atmosphere_director.process_mode = Node.PROCESS_MODE_ALWAYS
    region_atmosphere_director.configure(self, region_director, player)
    add_child(region_atmosphere_director)
    if audio_director != null:
        audio_director.register_region_atmosphere(region_atmosphere_director)

    region_lod_director = REGION_LOD_SCRIPT.new() as RegionPresentationLodDirector3D
    region_lod_director.name = "RegionPresentationLodDirector"
    region_lod_director.process_mode = Node.PROCESS_MODE_ALWAYS
    region_lod_director.configure(region_director, player, Callable(self, "_release_focus_position"))
    add_child(region_lod_director)

    region_encounter_dressing_director = REGION_ENCOUNTER_SCRIPT.new() as RegionEncounterDressingDirector3D
    region_encounter_dressing_director.name = "RegionEncounterDressingDirector"
    region_encounter_dressing_director.configure(region_director)
    add_child(region_encounter_dressing_director)

    long_operation_director = LongRangeOperationDirector3D.new()
    long_operation_director.name = "LongRangeOperationDirector"
    long_operation_director.process_mode = Node.PROCESS_MODE_PAUSABLE
    long_operation_director.configure(
        run_state,
        progression,
        region_director,
        noise_system,
        autonomy_director,
        outpost_director,
        heartforge,
        Callable(self, "_spawn_enemy"),
        operation_detail_director,
        Callable(self, "_progression_context")
    )
    add_child(long_operation_director)
    story_archive_director.connect_component_source(long_operation_director)
    story_archive_director.connect_event_source(long_operation_director)

    machine_society_director = MachineSocietyDirector3D.new()
    machine_society_director.name = "MachineSocietyDirector"
    machine_society_director.process_mode = Node.PROCESS_MODE_PAUSABLE
    machine_society_director.configure(
        run_state,
        progression,
        autonomy_director,
        heartforge,
        noise_system,
        Callable(self, "_spawn_robot")
    )
    add_child(machine_society_director)

    strategic_ecology_director = StrategicEcologyDirector3D.new()
    strategic_ecology_director.name = "StrategicEcologyDirector"
    strategic_ecology_director.process_mode = Node.PROCESS_MODE_PAUSABLE
    strategic_ecology_director.configure(region_director, Callable(self, "_spawn_enemy"), run_state)
    add_child(strategic_ecology_director)

    endgame_director = EndgameDirector3D.new()
    endgame_director.name = "EndgameDirector"
    endgame_director.process_mode = Node.PROCESS_MODE_PAUSABLE
    endgame_director.configure(
        run_state,
        progression,
        long_operation_director,
        outpost_director,
        region_director,
        strategic_ecology_director,
        heartforge,
        Callable(self, "_spawn_enemy")
    )
    add_child(endgame_director)
    story_archive_director.connect_event_source(endgame_director)

    adaptive_defense_director = ADAPTIVE_DEFENSE_SCRIPT.new() as AdaptiveDefenseDirector3D
    adaptive_defense_director.name = "AdaptiveDefenseDirector"
    adaptive_defense_director.process_mode = Node.PROCESS_MODE_PAUSABLE
    adaptive_defense_director.configure(run_state, progression, region_director, heartforge)
    add_child(adaptive_defense_director)

    endgame_escalation_director = ENDGAME_ESCALATION_SCRIPT.new() as EndgameEscalationDirector3D
    endgame_escalation_director.name = "EndgameEscalationDirector"
    endgame_escalation_director.configure(self, heartforge, endgame_director)
    add_child(endgame_escalation_director)
    if audio_director != null:
        audio_director.register_endgame(endgame_director)

    operations_hud = OperationsCommandHUD3D.new()
    operations_hud.name = "OperationsCommandHUD"
    add_child(operations_hud)

    _ensure_region_salvage(&"region.heartforge_district")


func _connect_complete_game_services() -> void:
    strategic_hud.adaptation_requested.connect(_authorize_adaptation)
    operations_hud.operation_requested.connect(_authorize_long_operation)
    operations_hud.protocol_requested.connect(_initiate_protocol)
    operations_hud.close_requested.connect(_close_operations_hud)

    region_director.region_discovered.connect(_on_region_discovered)
    long_operation_director.operation_changed.connect(_on_long_operation_changed)
    long_operation_director.operation_returned.connect(_on_long_operation_returned)
    long_operation_director.component_recovered.connect(_on_component_recovered)
    long_operation_director.site_discovery_requested.connect(_on_site_discovery_requested)
    long_operation_director.machine_recovered.connect(_on_machine_recovered)

    machine_society_director.autonomous_machine_built.connect(_on_autonomous_machine_built)
    strategic_ecology_director.ecology_report.connect(_on_ecology_report)
    endgame_director.endgame_started.connect(_on_endgame_started)
    endgame_director.endgame_progress.connect(_on_endgame_progress)
    endgame_director.endgame_completed.connect(_on_endgame_completed)
    endgame_director.endgame_failed.connect(_on_endgame_failed)
    adaptive_defense_director.proposal_available.connect(_on_adaptive_defense_proposal)
    adaptive_defense_director.adaptation_changed.connect(_on_adaptation_changed)
    adaptive_defense_director.adaptation_completed.connect(_on_adaptation_completed)

    noise_system.noise_emitted.connect(_on_complete_game_noise)


func _progression_context() -> Dictionary:
    var context: Dictionary = {}
    if region_director != null:
        context.merge(region_director.context_dictionary(), true)
    if long_operation_director != null:
        context.merge(long_operation_director.context_dictionary(), true)
    if machine_society_director != null:
        context.merge(machine_society_director.context_dictionary(), true)
    if endgame_director != null:
        context.merge(endgame_director.context_dictionary(), true)

    var functioning_outposts := 0
    var outpost_roles: Array[String] = []
    if outpost_director != null:
        for site in outpost_director.discovered_sites():
            if site.has_functioning_outpost():
                functioning_outposts += 1
                var role := String(site.outpost.role)
                if role not in outpost_roles:
                    outpost_roles.append(role)
    context["functioning_outposts"] = functioning_outposts
    context["outpost_roles"] = outpost_roles
    context["sanctuary_continuation"] = sanctuary_continuation
    return context


func _open_operations_hud() -> void:
    if player.is_channeling() or hud.forge_open or strategic_hud.is_open():
        return
    operations_hud.open_operations()
    player.input_enabled = false


func _start_dynamic_operation_review() -> void:
    if progression == null or region_director == null or long_operation_director == null or operations_hud == null:
        return
    progression.set_heartforge_tier(2)
    run_state.scrap = maxi(run_state.scrap, 260)
    run_state.scrap_changed.emit(run_state.scrap)
    var required_roles: Array[StringName] = [&"scout", &"guardian", &"engineer"]
    var spawn_positions: Array[Vector3] = [Vector3(-3.0, 0.0, 4.0), Vector3(0.0, 0.0, 5.0), Vector3(3.0, 0.0, 4.0)]
    for index in range(required_roles.size()):
        if world_role_count(required_roles[index]) <= 0:
            _spawn_robot(required_roles[index], spawn_positions[index], 1)
    region_director.discover_region(&"region.west_grid")
    var west_landmark := region_director.get_landmark(&"region.west_grid")
    if west_landmark != null:
        west_landmark.set_pressure(1.12)
    _ensure_region_salvage(&"region.west_grid")
    operations_hud.open_operations()
    player.input_enabled = false
    hud.push_notification(_localized_text("notification.complete.response_offer", "WORLD-STATE RESPONSE OFFER · PRESSURE HAS BECOME A CHOICE"))


func _start_adaptive_defense_review() -> void:
    adaptive_defense_review_capture_path = _adaptive_defense_review_capture_argument()
    adaptive_defense_review_capture_frames = 0
    if progression != null:
        progression.set_heartforge_tier(5)
        progression.unlocked_effects[&"unlock_adaptive_defence"] = true
        progression.progression_changed.emit()
    if run_state != null:
        run_state.scrap = 900
        run_state.expedition_core_recovered = true
        # This fixture represents a late-run Heartforge, so the production
        # shell must hand objective ownership to the complete-game guidance
        # instead of showing first-session salvage instructions afterward.
        full_game_milestone_complete = true
    if heartforge != null:
        heartforge.set_progression_tier(5)
        heartforge.current_health = heartforge.maximum_health * 0.55
        heartforge.health_changed.emit(heartforge.current_health, heartforge.maximum_health)
    if adaptive_defense_director != null:
        adaptive_defense_director.evaluate_now()
        if adaptive_defense_director.has_pending_proposal():
            strategic_hud.open_adaptation(adaptive_defense_director.available_plans(), adaptive_defense_director.proposal_summary())
            player.input_enabled = false


func _adaptive_defense_review_capture_argument() -> String:
    var arguments: Array = OS.get_cmdline_args()
    arguments.append_array(OS.get_cmdline_user_args())
    for index in arguments.size():
        var argument := str(arguments[index])
        if argument.begins_with("--adaptive-defense-review-screenshot="):
            return argument.get_slice("=", 1)
        if argument == "--adaptive-defense-review-screenshot" and index + 1 < arguments.size():
            return str(arguments[index + 1])
    return ""


func _authored_operation_review_id() -> StringName:
    var arguments: Array = OS.get_cmdline_args()
    arguments.append_array(OS.get_cmdline_user_args())
    for argument in arguments:
        var argument_text := str(argument)
        if argument_text.begins_with("--authored-operation-review="):
            return StringName(argument_text.get_slice("=", 1))
    return &"operation.west_grid_survey"


func _start_authored_operation_review() -> void:
    if long_operation_director == null or operations_hud == null:
        return
    var authored_operation_id := _authored_operation_review_id()
    var authored_operation := long_operation_director.operation(authored_operation_id)
    if authored_operation.is_empty():
        push_error("Authored operation review requested an unknown operation: %s" % authored_operation_id)
        return
    authored_operation = long_operation_director._with_route_preview(authored_operation)
    var locale_service := get_tree().get_first_node_in_group(&"localization_service") as LocalizationService3D
    var ready_status: String = locale_service.text("command.operations.ready") if locale_service != null else "A physical authored operation is ready to authorize."
    operations_hud.update_operations([authored_operation], ready_status, false)
    operations_hud.open_operations()
    var capture_path := _authored_operation_review_capture_argument()
    if not capture_path.is_empty():
        call_deferred("_capture_authored_operation_review", capture_path)
    # Freeze the ordinary world refresh so this non-saving presentation fixture
    # keeps the authored entry visible instead of replacing it with the normal
    # progression-gated offer list on the next frame.
    set_process(false)
    player.input_enabled = false
    hud.push_notification(_localized_text("notification.complete.operation_review_generic", "AUTHORED OPERATION REVIEW · THE SELECTED BRIEFING IS READY"))


func _authored_operation_review_capture_argument() -> String:
    var arguments: Array = OS.get_cmdline_args()
    arguments.append_array(OS.get_cmdline_user_args())
    for index in arguments.size():
        var argument := str(arguments[index])
        if argument.begins_with("--authored-operation-review-screenshot="):
            return argument.get_slice("=", 1)
        if argument == "--authored-operation-review-screenshot" and index + 1 < arguments.size():
            return str(arguments[index + 1])
    return ""


func _capture_authored_operation_review(capture_path: String) -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    var review_image := get_viewport().get_texture().get_image()
    var capture_error := review_image.save_png(capture_path)
    if capture_error == OK:
        print("Authored operation review screenshot written to %s" % capture_path)
    else:
        push_error("Authored operation review screenshot failed: %s" % capture_error)


func _start_route_memory_review() -> void:
    if progression == null or region_director == null or long_operation_director == null or operations_hud == null:
        return
    progression.set_heartforge_tier(2)
    run_state.scrap = maxi(run_state.scrap, 260)
    run_state.scrap_changed.emit(run_state.scrap)
    var required_roles: Array[StringName] = [&"scout", &"guardian", &"engineer"]
    var spawn_positions: Array[Vector3] = [Vector3(-3.0, 0.0, 4.0), Vector3(0.0, 0.0, 5.0), Vector3(3.0, 0.0, 4.0)]
    for index in range(required_roles.size()):
        if world_role_count(required_roles[index]) <= 0:
            _spawn_robot(required_roles[index], spawn_positions[index], 1)
    region_director.discover_region(&"region.west_grid")
    var west_landmark := region_director.get_landmark(&"region.west_grid")
    if west_landmark != null:
        west_landmark.set_pressure(1.12)
    _ensure_region_salvage(&"region.west_grid")
    var primary_route := region_director.route_from_heartforge(&"region.west_grid", heartforge.global_position)
    long_operation_director.route_memory["region.west_grid"] = {
        "risk": 1.0,
        "preferred_variant": 1,
        "recoveries": 1,
        "has_block_position": true,
        "last_block_position": primary_route[1] if primary_route.size() > 1 else heartforge.global_position,
    }
    operations_hud.open_operations()
    player.input_enabled = false
    hud.push_notification(_localized_text("notification.complete.route_memory_review", "ROUTE MEMORY REVIEW · THE CLEAREST AUTHORED DETOUR IS PROPOSED"))


func _start_route_recovery_marker_review() -> void:
    if operation_detail_director == null:
        return
    # This development-only fixture isolates the autonomous presentation cue
    # while the real route-recovery logic remains covered by the scenario tests.
    # Pausing the operation director prevents its idle cleanup from removing the
    # marker before the reviewer can inspect the grounded housing and arrows.
    if long_operation_director != null:
        long_operation_director.set_process(false)
    operation_detail_director.show_route_recovery(
        &"operation.detour",
        Vector3(-2.0, 0.0, 9.0),
        1,
        3
    )
    var review_beacon := operation_detail_director.get_node_or_null("AutonomousRouteRecoveryBeacon") as Node3D
    if review_beacon != null:
        review_beacon.scale = Vector3.ONE * 1.2
    hud.push_notification(_localized_text("notification.complete.route_recovery_marker_review", "ROUTE RECOVERY MARKER REVIEW · SILENT AUTONOMOUS DETOUR CUE"))


func _start_casualty_recovery_review() -> void:
    if progression == null or region_director == null or long_operation_director == null or operations_hud == null:
        return
    progression.set_heartforge_tier(2)
    run_state.scrap = maxi(run_state.scrap, 320)
    run_state.robots_built = maxi(run_state.robots_built, 4)
    if not progression.has_technology(&"tech.machine.group_coordination"):
        progression.purchase(&"tech.machine.group_coordination")
    run_state.scrap_changed.emit(run_state.scrap)
    var required_roles: Array[StringName] = [&"scout", &"guardian", &"engineer"]
    var spawn_positions: Array[Vector3] = [Vector3(-3.0, 0.0, 4.0), Vector3(0.0, 0.0, 5.0), Vector3(3.0, 0.0, 4.0)]
    for index in range(required_roles.size()):
        if world_role_count(required_roles[index]) <= 0:
            _spawn_robot(required_roles[index], spawn_positions[index], 1)
    if world_role_count(&"engineer") < 2:
        _spawn_robot(&"engineer", Vector3(5.0, 0.0, 4.0), 1)
    region_director.discover_region(&"region.west_grid")
    var casualty_machine := autonomy_director.living_robots(&"engineer")[0]
    casualty_machine.global_position = region_director.center(&"region.west_grid") + Vector3(3.0, 0.0, -2.0)
    casualty_machine.apply_damage(casualty_machine.maximum_health * 2.0)
    long_operation_director._sync_casualty_recovery_marker()
    operations_hud.open_operations()
    player.input_enabled = false
    hud.push_notification(_localized_text("notification.field_casualty", "FIELD CASUALTY SIGNAL · RECOVERY IS A STRATEGIC CHOICE"))


func world_role_count(role: StringName) -> int:
    return autonomy_director.living_robots(role).size() if autonomy_director != null else 0


func _open_evolution_hud() -> void:
    if adaptive_defense_director != null and adaptive_defense_director.has_pending_proposal():
        strategic_hud.open_adaptation(adaptive_defense_director.available_plans(), adaptive_defense_director.proposal_summary())
        player.input_enabled = false
        return
    super._open_evolution_hud()


func _open_endgame_hud() -> void:
    if player.is_channeling() or hud.forge_open or strategic_hud.is_open():
        return
    operations_hud.open_endgame()
    player.input_enabled = false


func _close_operations_hud() -> void:
    if operations_hud != null:
        operations_hud.close()
    if player != null and not player.is_channeling():
        player.input_enabled = true


func _authorize_long_operation(operation_id: StringName) -> void:
    if operation_id == &"":
        hud.push_notification(_localized_text("notification.long_operation.none", "NO LONG-RANGE OPERATION IS CURRENTLY AVAILABLE"))
        return
    if long_operation_director.authorize(operation_id):
        _close_operations_hud()
        long_operation_director.set_follow_operation(operation_id)
        follow_operation = true
        hud.push_notification(_localized_text("notification.long_operation.authorized", "LONG-RANGE OPERATION AUTHORIZED · FOLLOWS REAL STREETS · F TO TOGGLE FOLLOW"))
    else:
        hud.push_notification(_localized_text("notification.long_operation.unavailable", "OPERATION UNAVAILABLE · CHECK HEARTFORGE TIER, OUTPOSTS, SCRAP, TEAM COMPOSITION AND ACTIVE OPERATIONS"))


func _cycle_follow_operation() -> void:
    if long_operation_director == null:
        return
    var snapshot := long_operation_director.cycle_follow_operation()
    if snapshot.is_empty():
        hud.push_notification(_localized_text("notification.follow.none", "NO ACTIVE MACHINE GROUP TO FOLLOW"))
        return
    follow_operation = true
    var operation_id := StringName(str(snapshot.get("id", "operation")))
    var operation_name := _localized_operation_name(operation_id, str(snapshot.get("display_name", "Operation")))
    var group_index := int(snapshot.get("index", 0)) + 1
    var group_count := int(snapshot.get("count", 1))
    hud.push_notification(_localized_text(
        "notification.follow.cycled",
        "FOLLOWING {0} · GROUP {1}/{2} · G NEXT GROUP · F RETURN TO MECHROMANCER",
        [operation_name.to_upper(), group_index, group_count]
    ))


func _authorize_adaptation(adaptation_id: StringName) -> void:
    if adaptive_defense_director != null and adaptive_defense_director.authorize(adaptation_id):
        _close_strategic_hud()
        hud.push_notification(_localized_text(
            "notification.adaptive.authorized",
            "ADAPTIVE DEFENCE AUTHORIZED · MACHINES ARE RETROFITTING THE HEARTFORGE WITHOUT MANUAL PLACEMENT"
        ))
    else:
        hud.push_notification(_localized_text(
            "notification.adaptive.unavailable",
            "ADAPTIVE DEFENCE UNAVAILABLE · CHECK THE PROPOSAL AND SCRAP RESERVE"
        ))


func _initiate_protocol(protocol_id: StringName) -> void:
    if protocol_id == &"":
        hud.push_notification(_localized_text("notification.final_protocol.locked", "FINAL PROTOCOL LOCKED · COMPLETE THE ROOT CISTERN CHAIN AND TIER 5 RESEARCH"))
        return
    if endgame_director.initiate(protocol_id):
        _close_operations_hud()
        hud.push_notification(_localized_text("notification.final_protocol.initiated", "FINAL PROTOCOL INITIATED · THE RESPONSE IS CAUSAL AND IRREVERSIBLE"))
    else:
        hud.push_notification(_localized_text("notification.final_protocol.unavailable", "FINAL PROTOCOL UNAVAILABLE · CHECK RESEARCH, COMPONENTS, OUTPOSTS, SCRAP, CORES AND ACTIVE OPERATIONS"))


func _update_camera(delta: float) -> void:
    if follow_operation and long_operation_director != null and not long_operation_director.active_operation.is_empty():
        var target := long_operation_director.get_follow_target()
        if target != null:
            var desired_position := target.global_position + Vector3(0.0, camera_height, camera_distance)
            camera.global_position = camera.global_position.lerp(desired_position, 1.0 - exp(-delta * 6.5))
            camera.look_at(target.global_position + Vector3.UP * 0.7, Vector3.UP)
            return
    super._update_camera(delta)


func _on_expedition_returned() -> void:
    super._on_expedition_returned()
    if region_director != null:
        region_director.discover_region(&"region.north_ruins")
        _ensure_region_salvage(&"region.north_ruins")


func _on_enemy_killed(enemy: OrganicEnemy3D, killer: Node) -> void:
    var position := enemy.global_position
    var species := enemy.species
    super._on_enemy_killed(enemy, killer)
    if strategic_ecology_director != null:
        strategic_ecology_director.record_organic_kill(position, species)


func _on_heartforge_destroyed() -> void:
    if progression != null and progression.has_effect(&"single_continuity_recovery") and not continuity_used:
        continuity_used = true
        heartforge.current_health = heartforge.maximum_health * 0.48
        heartforge.health_changed.emit(heartforge.current_health, heartforge.maximum_health)
        run_state.scrap = maxi(0, run_state.scrap - 180)
        run_state.record_scrap_spend(180, "continuity recovery")
        run_state.scrap_changed.emit(run_state.scrap)
        run_state.log_event("Distributed Continuity rebuilt the Heartforge after catastrophic failure. The one-use reserve is gone.")
        hud.push_notification(_localized_text("notification.continuity.consumed", "DISTRIBUTED CONTINUITY CONSUMED · HEARTFORGE RECOVERED AT 48% · {0} SCRAP LOST", [180]))
        return
    if endgame_director != null and not endgame_director.active_protocol.is_empty():
        endgame_director.fail_active_protocol("The Heartforge failed before the final protocol completed.")
    super._on_heartforge_destroyed()
    if hud != null:
        hud.show_failure_report(_build_collapse_report())


func _build_collapse_report() -> String:
    var duration_seconds := int(round(run_state.elapsed_seconds)) if run_state != null else 0
    var duration_minutes := duration_seconds / 60
    var duration_hours := duration_minutes / 60
    var duration_text := "%dh %02dm" % [duration_hours, duration_minutes % 60] if duration_hours > 0 else "%dm" % duration_minutes

    var evolution_names: Array[String] = []
    if progression != null:
        for technology_id in progression.unlocked_technologies:
            evolution_names.append(str(progression.technology(technology_id).get("display_name", String(technology_id))))
    var evolution_text := ", ".join(evolution_names.slice(0, 5)) if not evolution_names.is_empty() else _localized_text("hud.collapse.no_major_evolution", "No major evolution had been recorded.")
    if evolution_names.size() > 5:
        evolution_text += " · +%d more" % (evolution_names.size() - 5)

    var species_text := run_state.observed_species_report() if run_state != null else _localized_text("hud.collapse.species_unavailable", "Persistent species observations were unavailable.")

    var machine_losses := 0
    var loss_archetypes: Array[String] = []
    var balance_node := get_tree().get_first_node_in_group(&"balance_director")
    var balance_samples: Variant = balance_node.get("pressure_samples") if balance_node != null else []
    if balance_samples is Array:
        for sample in balance_samples:
            if not (sample is Dictionary):
                continue
            if str(sample.get("kind", "")) != "machine_loss":
                continue
            machine_losses += 1
            var archetype := str(sample.get("archetype", "unknown"))
            if archetype not in loss_archetypes:
                loss_archetypes.append(archetype)
    var loss_key := "hud.collapse.machine_loss.one" if machine_losses == 1 else "hud.collapse.machine_loss.many"
    var loss_text := _localized_text(loss_key, "%d recorded machine loss%s" % [machine_losses, "" if machine_losses == 1 else "es"], [machine_losses])
    if not loss_archetypes.is_empty():
        loss_text += " (%s)" % ", ".join(loss_archetypes)

    var decisive_events: Array[String] = []
    if run_state != null:
        for event in run_state.event_log:
            var lower := event.to_lower()
            if lower.contains("technology") or lower.contains("operation") or lower.contains("adaptive") or lower.contains("machine witness") or lower.contains("protocol"):
                decisive_events.append(event)
            if decisive_events.size() >= 3:
                break
    var events_text := "\n".join(decisive_events) if not decisive_events.is_empty() else _localized_text("hud.collapse.no_decisive_event", "No decisive event was recorded before collapse.")

    var pressure_text := _localized_pressure_summary()
    var resource_text := _localized_text("hud.collapse.resource_totals", "SCRAP {0} · CORES {1} · MANUAL RECOVERED {2} · AUTONOMOUS RECOVERED {3}", [run_state.scrap, run_state.rare_cores, run_state.manual_scrap_recovered, run_state.autonomous_scrap_recovered])
    var resource_decline_text := run_state.resource_decline_report() if run_state != null else _localized_text("hud.collapse.resource_history_unavailable", "Resource history was unavailable.")
    var remote_support_text := _localized_text("hud.collapse.remote_support", "{0} functioning remote support post{1}", [_functioning_outpost_count(), "" if _functioning_outpost_count() == 1 else "s"])
    var doctrine_text := _localized_doctrine_display_name()
    var alternatives := _localized_text("hud.collapse.no_unspent_response", "No unspent response was recorded.")
    if progression != null:
        var available := progression.available_technologies()
        var names: Array[String] = []
        for entry in available.slice(0, 3):
            names.append(str(entry.get("display_name", "Unnamed response")))
        if not names.is_empty():
            alternatives = ", ".join(names)
    return _localized_text(
        "hud.collapse.report",
        "WORLD DURATION · {0}\nMAJOR EVOLUTIONS · {1}\nECOLOGY OBSERVATIONS · {2}\nDECISIVE TIMELINE\n{3}\nRESOURCE POSITION · {4}\nFIRST SUSTAINED RESOURCE DECLINE · {5}\nMACHINE-LOSS PATTERN · {6}\nUNRESOLVED THREAT · {7}\nALTERNATIVE RESPONSES OBSERVED OR UNLOCKED · {8}\nSTRATEGIC DOCTRINE · {9}\nREMOTE SUPPORT · {10}",
        [duration_text, evolution_text, species_text, events_text, resource_text, resource_decline_text, loss_text, pressure_text, alternatives, doctrine_text, remote_support_text]
    )


func _update_complete_game_objective() -> void:
    if long_operation_director == null or endgame_director == null:
        return
    _current_objective_title = ""
    _current_objective_detail = ""
    _current_objective_prompt = ""

    if endgame_director.completed_protocol != &"":
        _set_complete_objective("objective.complete.victory.title", "FIRST VICTORY", "objective.complete.victory.detail", "The final protocol completed. The surviving machine sanctuary continues beyond the first victory.", [], "objective.complete.victory.prompt", "PRESS P · REVIEW THE CONTINUING SANCTUARY")
        return

    # An adaptive Heartforge response is a rare strategic commitment and must
    # replace any earlier progression objective while it is waiting or being
    # built. Otherwise the player can authorize a late-run retrofit while the
    # HUD still instructs them to recover the first Scrap.
    if adaptive_defense_director != null and adaptive_defense_director.has_pending_proposal():
        _set_complete_objective(
            "objective.adaptive.pending.title",
            "REVIEW HEARTFORGE ADAPTATION",
            "objective.adaptive.pending.detail",
            "The Heartforge architect proposes one rare structural response. Press T to compare principles and authorize the machines.",
            [],
            "objective.adaptive.pending.prompt",
            "PRESS T · REVIEW THE HEARTFORGE ADAPTATION"
        )
        return

    if adaptive_defense_director != null and not adaptive_defense_director.active_adaptation.is_empty():
        var active_id := StringName(str(adaptive_defense_director.active_adaptation.get("id", "")))
        var active_entry := adaptive_defense_director.localized_adaptation(active_id)
        var active_name := str(active_entry.get("construction_name", active_entry.get("display_name", String(active_id))))
        var active_data_variant: Variant = adaptive_defense_director.active_adaptation.get("data", {})
        var active_data: Dictionary = active_data_variant as Dictionary if active_data_variant is Dictionary else {}
        var duration := maxf(1.0, float(active_data.get("build_seconds", 12.0)))
        var elapsed := maxf(0.0, float(adaptive_defense_director.active_adaptation.get("elapsed", 0.0)))
        var progress_percent := int(round(clampf(elapsed / duration, 0.0, 1.0) * 100.0))
        _set_complete_objective(
            "objective.adaptive.building.title",
            "HOLD THE HEARTFORGE",
            "objective.adaptive.building.detail",
            "Machines are building {0} · {1}%. Stay near the Heartforge while the retrofit completes; geometry and repair remain delegated.",
            [active_name, progress_percent],
            "objective.adaptive.building.prompt",
            "HOLD THE HEARTFORGE · MACHINES ARE BUILDING THE RETROFIT"
        )
        return

    if not long_operation_director.active_operation.is_empty():
        var active_operation_status := _localized_long_operation_summary()
        var locale_service := get_tree().get_first_node_in_group(&"localization_service") as LocalizationService3D
        var objective_title := "FOLLOW THE ACTIVE MACHINE GROUP"
        var objective_detail := "%s. Press F to follow the physical formation or P to review its route, state and recovery affordance." % active_operation_status
        var objective_prompt := "F FOLLOW ACTIVE MACHINE GROUP · P REVIEW OPERATION STATUS"
        if locale_service != null:
            objective_title = locale_service.text("objective.active_operation.title")
            objective_detail = locale_service.text("objective.active_operation.detail", [active_operation_status])
            objective_prompt = locale_service.text("objective.active_operation.prompt")
        _current_objective_title = objective_title
        _current_objective_detail = objective_detail
        _current_objective_prompt = objective_prompt
        hud.set_objective(
            objective_title,
            objective_detail
        )
        hud.set_prompt(objective_prompt)
        var guidance := get_node_or_null("ObjectiveGuidance")
        if guidance != null and guidance.has_method(&"clear_guidance"):
            guidance.call(&"clear_guidance")
        return

    if not run_state.expedition_core_recovered or not full_game_milestone_complete:
        return

    if not long_operation_director.has_completed(&"operation.west_grid_survey"):
        _set_complete_objective("objective.complete.survey.title", "SURVEY THE WEST GRID", "objective.complete.survey.detail", "Press P and authorize the first long-range operation. The group travels through real streets, works under pressure, and delivers only after returning.", [], "objective.complete.survey.prompt", "PRESS P · REVIEW AVAILABLE LONG-RANGE OPERATIONS")
        return
    if progression.heartforge_tier < 3:
        var tier_three_hint := _input_binding_hint(&"iw_interact", "E")
        _set_complete_objective("objective.complete.tier3.title", "EVOLVE THE HEARTFORGE TO TIER III", "objective.complete.tier3.detail", "Return to the forge, press {0}, and choose 9. The West Grid archive now permits deeper autonomy and ordinary machine replacement research.", [tier_three_hint], "objective.complete.tier3.prompt", "PRESS {0} · EVOLVE THE HEARTFORGE TO TIER III")
        return
    if not progression.has_technology(&"tech.machine.forge_assistance"):
        _set_complete_objective("objective.complete.forge_assistance.title", "REMOVE ORDINARY REPLACEMENT WORK", "objective.complete.forge_assistance.detail", "Press T and authorize Forge Assistance. The machine society will then replace missing ordinary frames without a maintained production queue.", [], "objective.complete.forge_assistance.prompt", "PRESS T · AUTHORIZE FORGE ASSISTANCE")
        return
    if not long_operation_director.has_completed(&"operation.flood_market_recovery"):
        _set_complete_objective("objective.complete.vital_membrane.title", "RECOVER THE VITAL MEMBRANE", "objective.complete.vital_membrane.detail", "Press P to authorize the Flood Market operation. The recovered biological component is required for later Heartforge evolution.", [], "objective.complete.vital_membrane.prompt", "PRESS P · AUTHORIZE THE FLOOD MARKET OPERATION")
        return
    if _functioning_outpost_count() < 2:
        _set_complete_objective("objective.complete.support_post.title", "ESTABLISH A SECOND SUPPORT POST", "objective.complete.support_post.detail", "Press O and authorize another bounded outpost. Machines choose the Engineer, escort, route, construction, repair and rebuilding.", [], "objective.complete.support_post.prompt", "PRESS O · AUTHORIZE ANOTHER AUTONOMOUS OUTPOST")
        return
    if not long_operation_director.has_completed(&"operation.cathedral_brood_suppression"):
        _set_complete_objective("objective.complete.cathedral.title", "SILENCE THE CATHEDRAL BROOD", "objective.complete.cathedral.detail", "Press P. This suppression operation requires two functioning outposts and a heavily escorted physical group.", [], "objective.complete.cathedral.prompt", "PRESS P · REVIEW THE CATHEDRAL OPERATION")
        return
    if progression.heartforge_tier < 4:
        _set_complete_objective("objective.complete.tier4.title", "EVOLVE THE HEARTFORGE TO TIER IV", "objective.complete.tier4.detail", "Return to the forge and choose 9. The Vital Membrane and Choral Gland permit adaptive multi-region awareness.", [], "objective.complete.tier4.prompt", "PRESS 9 · EVOLVE THE HEARTFORGE TO TIER IV")
        return
    if not long_operation_director.has_completed(&"operation.buried_lab_excavation"):
        _set_complete_objective("objective.complete.genome.title", "EXCAVATE THE GENOME PRISM", "objective.complete.genome.detail", "Press P to send the Engineer-led excavation group to the Buried Laboratories.", [], "objective.complete.genome.prompt", "PRESS P · AUTHORIZE THE LABORATORY EXCAVATION")
        return
    if _functioning_outpost_count() < 3:
        _set_complete_objective("objective.complete.support_three.title", "PREPARE THREE REMOTE SUPPORT NODES", "objective.complete.support_three.detail", "Use O to maintain three functioning autonomous outposts before mapping the Root Cistern.", [], "objective.complete.support_three.prompt", "PRESS O · REVIEW AUTONOMOUS SUPPORT POSTS")
        return
    if not long_operation_director.has_completed(&"operation.root_cistern_mapping"):
        _set_complete_objective("objective.complete.root_cistern.title", "MAP THE ROOT CISTERN", "objective.complete.root_cistern.detail", "Press P. This final deep expedition identifies where the Heartforge can reach the coordinating organic signal.", [], "objective.complete.root_cistern.prompt", "PRESS P · AUTHORIZE THE ROOT CISTERN EXPEDITION")
        return
    if progression.heartforge_tier < 5:
        _set_complete_objective("objective.complete.tier5.title", "EVOLVE THE HEARTFORGE TO TIER V", "objective.complete.tier5.detail", "Return to the forge and choose 9. The recovered components can now be integrated into a final-protocol lattice.", [], "objective.complete.tier5.prompt", "PRESS 9 · EVOLVE THE HEARTFORGE TO TIER V")
        return
    if not progression.has_technology(&"tech.endgame.severance") and not progression.has_technology(&"tech.endgame.containment"):
        _set_complete_objective("objective.complete.ending_choice.title", "CHOOSE WHAT THE TOWN BECOMES", "objective.complete.ending_choice.detail", "Press T and research Severance, Containment, Transformation, or more than one. This is a strategic ending choice, not a recurring wave upgrade.", [], "objective.complete.ending_choice.prompt", "PRESS T · RESEARCH THE FINAL PROTOCOLS")
        return
    if endgame_director.active_protocol.is_empty():
        _set_complete_objective("objective.complete.initiate.title", "INITIATE THE FINAL PROTOCOL", "objective.complete.initiate.detail", "Press V, choose an available protocol, and deliberately provoke the final ecological response when the Heartforge and machine society are ready.", [], "objective.complete.initiate.prompt", "PRESS V · REVIEW IRREVERSIBLE FINAL PROTOCOLS")
    else:
        var locale_service := get_tree().get_first_node_in_group(&"localization_service") as LocalizationService3D
        var objective_title := "HOLD THE HEARTFORGE"
        var objective_detail := "%s. Routine machines and outposts continue acting autonomously; intervene only where the final response breaks through." % _localized_endgame_status_summary()
        var objective_prompt := "HOLD THE HEARTFORGE · INTERVENE ONLY IF THE FINAL RESPONSE BREAKS THROUGH"
        if locale_service != null:
            objective_title = locale_service.text("objective.endgame.active.title")
            objective_detail = locale_service.text("objective.endgame.active.detail", [_localized_endgame_status_summary()])
            objective_prompt = locale_service.text("objective.endgame.active.prompt")
        _current_objective_title = objective_title
        _current_objective_detail = objective_detail
        _current_objective_prompt = objective_prompt
        hud.set_objective(objective_title, objective_detail)
        hud.set_prompt(objective_prompt)


func _on_region_discovered(region_id: StringName, display_name: String) -> void:
    _ensure_region_salvage(region_id)
    hud.push_notification(_localized_text("notification.region.discovered", "REGION DISCOVERED · {0} · PHYSICAL ROUTES NOW KNOWN", [display_name.to_upper()]))


func _on_story_record_unlocked(record_id: StringName, display_name: String, description: String) -> void:
    var localized_name := display_name
    var localized_description := description
    var locale_service := get_tree().get_first_node_in_group(&"localization_service") as LocalizationService3D
    if locale_service != null:
        var record_key := String(record_id).replace("story.", "").replace(".", "_")
        var name_key := "story.record.%s.name" % record_key
        var description_key := "story.record.%s.description" % record_key
        var name_candidate := locale_service.text(name_key)
        var description_candidate := locale_service.text(description_key)
        if name_candidate != name_key:
            localized_name = name_candidate
        if description_candidate != description_key:
            localized_description = description_candidate
    var notification := "TOWN RECORD · %s\n%s" % [localized_name.to_upper(), localized_description]
    if locale_service != null:
        notification = locale_service.text("notification.town_record", [localized_name.to_upper(), localized_description])
    hud.push_notification(notification)


func _on_story_thread_advanced(_thread_id: StringName, display_name: String, stage_count: int, description: String) -> void:
    hud.push_notification(_localized_text("notification.story.thread_advanced", "STORY THREAD ADVANCED · {0} · {1} CLUES\n{2}", [display_name.to_upper(), stage_count, description]))


func _open_story_archive() -> void:
    if operations_hud == null or story_archive_director == null:
        return
    operations_hud.open_archive(story_archive_director.archive_records())
    player.input_enabled = false


func _show_session_recap() -> void:
    if operations_hud == null or hud == null or heartforge == null or run_state == null:
        return
    _update_complete_game_objective()
    var integrity := int(round(100.0 * heartforge.current_health / maxf(1.0, heartforge.maximum_health)))
    var world_condition := String(run_state.world_variant_id)
    var variation_director := get_node_or_null("RunVariationDirector")
    if variation_director != null and variation_director.has_method(&"current_display_name"):
        var display_name := str(variation_director.call(&"current_display_name"))
        if not display_name.is_empty():
            world_condition = display_name
    var condition_key := String(run_state.world_variant_id).trim_prefix("weather.").replace(".", "_")
    world_condition = _localized_text("world.condition.%s.name" % condition_key, world_condition)
    var condition := _localized_text(
        "command.recap.condition",
        "WORLD CONDITION · {0}\nHEARTFORGE {1}% INTEGRITY · TIER {2} · SCRAP {3} · CORES {4}",
        [world_condition, integrity, progression.heartforge_tier, run_state.scrap, run_state.rare_cores]
    )
    var unresolved_problem := _localized_text("command.recap.unresolved_fallback", "No unresolved strategic problem is recorded.")
    if not _current_objective_title.strip_edges().is_empty():
        unresolved_problem = "%s\n%s" % [_current_objective_title, _current_objective_detail]
    var expedition := _localized_text("command.recap.no_operation", "No long-range operation is in motion. Press P to review the next physical route.")
    if long_operation_director != null and not long_operation_director.active_operation.is_empty():
        expedition = _localized_long_operation_summary()
    var threats := _localized_pressure_summary()
    var recent_threats := _recent_threat_recap()
    if not recent_threats.is_empty():
        threats = "%s\n%s" % [threats, recent_threats]
    var next_choices := _localized_text("command.recap.current_objective", "Review the current objective on the tactical HUD.")
    if not _current_objective_prompt.strip_edges().is_empty():
        next_choices = _current_objective_prompt
    if adaptive_defense_director != null and adaptive_defense_director.has_pending_proposal():
        next_choices = _localized_text("command.recap.adaptation_choice", "PRESS T · REVIEW THE HEARTFORGE'S PROPOSED ADAPTATION")
    operations_hud.open_recap(condition, unresolved_problem, expedition, threats, next_choices)
    player.input_enabled = false


func _recent_threat_recap() -> String:
    if strategic_ecology_director == null:
        return ""
    var summary := strategic_ecology_director.pressure_summary_data()
    var region_id := StringName(str(summary.get("region_id", "region.heartforge_district")))
    var region_name := _localized_region_name(region_id)
    var pressure := float(summary.get("pressure", 0.0))
    if pressure <= 0.01:
        return _localized_text("command.recap.no_recent_threats", "No unfamiliar threat signal was recorded since the last return.")
    return _localized_text(
        "command.recap.recent_pressure",
        "Recent ecology remains active around {0} · pressure {1}.",
        [region_name, "%.2f" % pressure]
    )


func _ensure_region_salvage(region_id: StringName) -> void:
    if bool(spawned_region_salvage.get(region_id, false)):
        return
    spawned_region_salvage[region_id] = true
    if region_id == &"region.heartforge_district":
        return
    var center := region_director.center(region_id)
    var region_name := str(region_director.get_region_data(region_id).get("display_name", String(region_id)))
    _spawn_salvage(center + Vector3(7.0, 0.0, 5.0), 110, "%s utility wreck" % region_name)
    _spawn_salvage(center + Vector3(-8.0, 0.0, -4.0), 135, "%s structural salvage" % region_name)


func _localized_text(key: String, fallback: String, replacements: Array = []) -> String:
    var service := get_tree().get_first_node_in_group(&"localization_service") as LocalizationService3D
    if service != null:
        return service.text(key, replacements)
    var result := fallback
    for index in range(replacements.size()):
        result = result.replace("{%d}" % index, str(replacements[index]))
    return result


func _localized_pressure_summary() -> String:
    if strategic_ecology_director == null:
        return _localized_text("command.recap.pressure_unavailable", "Regional pressure is not currently resolved.")
    var summary := strategic_ecology_director.pressure_summary_data()
    var region_id := StringName(str(summary.get("region_id", "region.heartforge_district")))
    var region_name := _localized_region_name(region_id)
    var pressure := float(summary.get("pressure", 0.0))
    var migration_tendency := float(summary.get("migration_tendency", 0.0))
    return _localized_text("command.recap.pressure_summary", "{0} · pressure {1} · migration tendency {2}", [region_name, "%.2f" % pressure, "%.2f" % migration_tendency])


func _set_complete_objective(title_key: String, title_fallback: String, detail_key: String, detail_fallback: String, replacements: Array = [], prompt_key: String = "", prompt_fallback: String = "") -> void:
    _current_objective_title = _localized_text(title_key, title_fallback, replacements)
    _current_objective_detail = _localized_text(detail_key, detail_fallback, replacements)
    _current_objective_prompt = _localized_text(prompt_key, prompt_fallback, replacements) if not prompt_key.is_empty() else ""
    if hud == null:
        return
    hud.set_objective(_current_objective_title, _current_objective_detail)
    if not prompt_key.is_empty():
        hud.set_prompt(_current_objective_prompt)


func _localized_region_name(region_id: StringName) -> String:
    var fallback := String(region_id).trim_prefix("region.").replace("_", " ")
    var service := get_tree().get_first_node_in_group(&"localization_service") as LocalizationService3D
    if service == null:
        return fallback
    var key := "world.region.%s" % String(region_id).trim_prefix("region.")
    var localized := service.text(key)
    return fallback if localized == key else localized


func _localized_operation_name(operation_id: StringName, fallback: String) -> String:
    if long_operation_director == null:
        return fallback
    var entry := long_operation_director.operation(operation_id)
    if entry.is_empty():
        return fallback
    var service := get_tree().get_first_node_in_group(&"localization_service") as LocalizationService3D
    if service == null:
        return str(entry.get("display_name", fallback))
    var key_base := String(operation_id)
    var replacements: Array = []
    var template_id := str(entry.get("dynamic_template_id", ""))
    if not template_id.is_empty():
        var template_key := template_id.trim_prefix("dynamic.")
        key_base = "operation.dynamic.%s" % template_key
        replacements.append(_localized_region_name(StringName(str(entry.get("localization_region_id", entry.get("region_id", ""))))))
        if template_key == "machine_recovery":
            replacements.push_front(str(entry.get("localization_machine_name", "disabled machine")))
    var key := "%s.name" % key_base
    var localized := service.text(key, replacements)
    return str(entry.get("display_name", fallback)) if localized == key else localized


func _localized_long_operation_summary() -> String:
    if long_operation_director == null or long_operation_director.active_operation.is_empty():
        return _localized_text("hud.operation.none", "No long-range operation")
    var entry: Dictionary = long_operation_director.active_operation.get("data", {})
    var operation_id := StringName(str(long_operation_director.active_operation.get("id", "operation")))
    var fallback_name := str(entry.get("display_name", "Operation"))
    var operation_name := _localized_operation_name(operation_id, fallback_name)
    var state := String(long_operation_director.active_operation.get("state", "unknown"))
    var localized_state := _localized_text("operation.state.%s" % state, state.capitalize())
    return _localized_text("hud.operation.summary", "%s · %s", [operation_name, localized_state])


func _localized_long_operations_summary() -> String:
    if long_operation_director == null:
        return _localized_text("hud.operation.none", "No long-range operation")
    var active_operations: Array[Dictionary] = long_operation_director.active_operations
    if active_operations.is_empty():
        return _localized_text("hud.operation.none", "No long-range operation")
    var summaries: Array[String] = []
    for operation in active_operations:
        var operation_id := StringName(str(operation.get("id", "operation")))
        var entry: Dictionary = operation.get("data", {})
        var operation_name := _localized_operation_name(operation_id, str(entry.get("display_name", "Operation")))
        var state := String(str(operation.get("state", "unknown")))
        var localized_state := _localized_text("operation.state.%s" % state, state.capitalize())
        summaries.append(_localized_text("hud.operation.summary", "{0} · {1}", [operation_name, localized_state]))
    if summaries.size() == 1:
        return summaries[0]
    return _localized_text("command.operations.active_summary", "{0} long-range groups active · {1}", [summaries.size(), " · ".join(summaries)])


func _localized_long_operation_report(operation_id: StringName, state: StringName, detail: String) -> String:
    var operation_name := _localized_operation_name(operation_id, String(operation_id).replace("operation.", "").replace("_", " "))
    var key := "notification.long_operation.%s" % String(state)
    var localized := _localized_text(key, "", [operation_name])
    if not localized.is_empty() and localized != key:
        return localized
    return "%s · %s\n%s" % [operation_name.to_upper(), String(state).to_upper(), detail]


func _on_long_operation_changed(operation_id: StringName, state: StringName, detail: String) -> void:
    hud.push_notification(_localized_long_operation_report(operation_id, state, detail))
    var release_audio := get_node_or_null("ReleaseAudioDirector") as ReleaseAudioDirector3D
    if release_audio != null:
        var anchor := heartforge.global_position if heartforge != null else Vector3.ZERO
        if long_operation_director != null and not long_operation_director.active_operation.is_empty():
            anchor = long_operation_director.active_operation.get("anchor", anchor)
        release_audio.notify_operation(operation_id, state, detail, anchor)


func _on_adaptive_defense_proposal(summary: String) -> void:
    hud.push_notification(_localized_text(
        "notification.adaptive.proposal",
        "ADAPTIVE DEFENCE PROPOSAL · PRESS T TO CHOOSE\n{0}",
        [summary]
    ))
    _update_complete_game_objective()


func _on_adaptation_changed(adaptation_id: StringName, state: StringName, detail: String) -> void:
    var adaptation_name := String(adaptation_id).replace("adaptation.", "").replace("_", " ")
    if adaptive_defense_director != null:
        var localized_entry := adaptive_defense_director.localized_adaptation(adaptation_id)
        adaptation_name = str(localized_entry.get("display_name", adaptation_name))
    var localized_state := _localized_text("adaptive.state.label.%s" % String(state), String(state).capitalize())
    hud.push_notification(_localized_text(
        "notification.adaptive.state",
        "HEARTFORGE ADAPTATION · %s · %s\n%s",
        [adaptation_name.to_upper(), localized_state.to_upper(), detail]
    ))
    _update_complete_game_objective()


func _on_adaptation_completed(_adaptation_id: StringName, display_name: String) -> void:
    hud.push_notification(_localized_text(
        "notification.adaptive.complete",
        "HEARTFORGE RESPONSE ONLINE · %s · THE NEW STRUCTURE IS NOW MACHINE-MAINTAINED",
        [display_name.to_upper()]
    ))
    _update_complete_game_objective()


func _on_long_operation_returned(operation_id: StringName, display_name: String, rewards: Dictionary) -> void:
    hud.push_notification(_localized_text("notification.long_operation.returned", "OPERATION COMPLETE · %s · REWARDS DELIVERED PHYSICALLY", [_localized_operation_name(operation_id, display_name)]))
    if not bool(machine_relationship_moments.get("first_return", false)):
        machine_relationship_moments["first_return"] = true
        var witness := _machine_witness_identity()
        var moment := "%s brought the group home through the same streets it learned on; the Heartforge answers with a warmer signal." % witness
        run_state.log_event("MACHINE WITNESS · %s" % moment)
        hud.push_notification(_localized_text("notification.machine.witness.return", "MACHINE WITNESS · {0} BROUGHT THE GROUP HOME THROUGH THE SAME STREETS IT LEARNED ON; THE HEARTFORGE ANSWERS WITH A WARMER SIGNAL.", [witness.to_upper()]))
        if story_archive_director != null:
            story_archive_director.record_machine_witness(&"machine.first_return")
    progression._evaluate_automatic_technologies()


func _on_component_recovered(component_id: StringName) -> void:
    hud.push_notification(_localized_text("notification.component.recovered", "UNIQUE BIOLOGICAL COMPONENT RECOVERED · {0}", [String(component_id).replace("component.", "").replace("_", " ").to_upper()]))


func _on_machine_recovered(record: Dictionary) -> void:
    var archetype := StringName(str(record.get("archetype", "salvager")))
    var level := clampi(int(record.get("level", 1)), 1, 3)
    var robot := _spawn_robot(archetype, heartforge.global_position + Vector3(2.6, 0.0, 3.2), level)
    robot.restore_callsign(record.get("callsign", ""))
    robot.current_health = robot.maximum_health * 0.68
    robot.health_changed.emit(robot, robot.current_health, robot.maximum_health)
    var identity := robot.display_identity()
    hud.push_notification(_localized_text("notification.machine_recovered", "MACHINE RECOVERED · %s · RETURNED DAMAGED BUT ALIVE", [identity.to_upper()]))
    run_state.log_event("MACHINE WITNESS · %s returned from a field casualty beacon and rejoined the Heartforge." % identity)
    if story_archive_director != null:
        story_archive_director.record_machine_witness(&"machine.first_recovery")


func _on_site_discovery_requested(site_id: StringName) -> void:
    outpost_director.discover_site(site_id)


func _on_autonomous_machine_built(archetype: StringName, level: int, reason: String) -> void:
    var identity := _machine_identity_for_archetype(archetype)
    hud.push_notification(_localized_text("notification.machine.autonomous_replacement", "AUTONOMOUS REPLACEMENT · LEVEL {0} {1} · {2}", [level, identity.to_upper(), String(archetype).to_upper()]))
    if not bool(machine_relationship_moments.get("first_replacement", false)):
        machine_relationship_moments["first_replacement"] = true
        var moment := "%s took its place without a queue or command; the machine society is beginning to remember what the town needs." % identity
        run_state.log_event("MACHINE WITNESS · %s" % moment)
        hud.push_notification(_localized_text("notification.machine.witness.replacement", "MACHINE WITNESS · {0} TOOK ITS PLACE WITHOUT A QUEUE OR COMMAND; THE MACHINE SOCIETY IS BEGINNING TO REMEMBER WHAT THE TOWN NEEDS.", [identity.to_upper()]))
        if story_archive_director != null:
            story_archive_director.record_machine_witness(&"machine.first_replacement")


func _machine_identity_for_archetype(archetype: StringName) -> String:
    var members := autonomy_director.living_robots(archetype)
    if not members.is_empty():
        return members[members.size() - 1].display_identity()
    return String(archetype).capitalize()


func _machine_witness_identity() -> String:
    var companions := autonomy_director.living_robots(&"companion")
    if not companions.is_empty():
        return companions[0].display_identity()
    var members := autonomy_director.living_robots()
    if not members.is_empty():
        return members[0].display_identity()
    return "The machine group"


func _on_ecology_report(message: String) -> void:
    hud.push_notification(_localized_ecology_report(message))


func _localized_ecology_report(message: String) -> String:
    var concentration_prefix := "Organic activity is concentrating around "
    if message.begins_with(concentration_prefix):
        var after_marker := message.find(" after ", concentration_prefix.length())
        if after_marker > concentration_prefix.length():
            var landmark := message.substr(concentration_prefix.length(), after_marker - concentration_prefix.length()).trim_suffix(".")
            var source := message.substr(after_marker + 7).trim_suffix(".").replace("_", " ")
            return _localized_text("notification.ecology.concentrating", "ORGANIC ACTIVITY CONCENTRATING AROUND {0} AFTER {1}", [landmark.to_upper(), source.to_upper()])
    var migration_prefix := "A hunting migration has left "
    var migration_marker := message.find(" and entered the connecting streets.")
    if message.begins_with(migration_prefix) and migration_marker > migration_prefix.length():
        var source_region := message.substr(migration_prefix.length(), migration_marker - migration_prefix.length())
        return _localized_text("notification.ecology.migration", "HUNTING MIGRATION LEFT {0} · ENTERING CONNECTING STREETS", [source_region.to_upper()])
    return message.to_upper()


func _on_complete_game_noise(position: Vector3, radius: float, intensity: float, source_kind: StringName) -> void:
    var adjusted := intensity
    if progression != null and progression.has_effect(&"signal_dampening") and source_kind not in [&"heartforge_evolution", &"strategic_operation"]:
        adjusted *= maxf(0.35, 0.68 - progression.modifier_value(&"noise_reduction"))
    if adaptive_defense_director != null:
        adjusted *= adaptive_defense_director.activity_noise_multiplier()
    strategic_ecology_director.record_disturbance(position, adjusted, source_kind)


func _on_endgame_started(protocol_id: StringName, display_name: String) -> void:
    var localized_name := display_name
    var locale_service := get_tree().get_first_node_in_group(&"localization_service") as LocalizationService3D
    if locale_service != null:
        localized_name = _localized_endgame_protocol_name(display_name, locale_service)
    hud.push_notification(_localized_text("notification.final_protocol.converging", "FINAL PROTOCOL · {0} · ORGANIC PRESSURE IS CONVERGING", [localized_name.to_upper()]))


func _on_endgame_progress(protocol_id: StringName, progress: float, detail: String) -> void:
    if int(progress * 100.0) % 20 == 0:
        hud.set_operation(_localized_endgame_status_summary("%s · %d%%" % [String(protocol_id).replace("protocol.", "").capitalize(), int(round(progress * 100.0))]))


func _localized_endgame_status_summary(raw_status: String = "") -> String:
    var status := raw_status
    if status.is_empty() and endgame_director != null:
        status = endgame_director.status_summary()
    var locale_service := get_tree().get_first_node_in_group(&"localization_service") as LocalizationService3D
    if locale_service == null:
        return status
    if status == "No final protocol active":
        return locale_service.text("command.endgame.none")
    if status.ends_with(" completed"):
        var completed_name := status.trim_suffix(" completed")
        return locale_service.text("command.endgame.completed", [_localized_endgame_protocol_name(completed_name, locale_service)])
    var separator := status.find(" · ")
    if separator > 0:
        var active_name := status.substr(0, separator)
        var progress_text := status.substr(separator + 3)
        return locale_service.text("command.endgame.progress", [_localized_endgame_protocol_name(active_name, locale_service), progress_text])
    return status


func _localized_endgame_protocol_name(raw_name: String, locale_service: LocalizationService3D) -> String:
    var protocol_key := raw_name.to_lower().replace(" ", "_")
    var localized := locale_service.text("endgame.%s.name" % protocol_key)
    return raw_name if localized == "endgame.%s.name" % protocol_key else localized


func _on_endgame_completed(protocol_id: StringName, display_name: String, ending: String) -> void:
    first_victory_achieved = true
    sanctuary_continuation = false
    game_ended = true
    # The crisis can leave the Heartforge below the damaged-badge threshold
    # during its defence interval. Victory restores the sanctuary state; do
    # not carry a stale damage warning into the first-victory frame.
    if hud != null and hud.has_method(&"set_sanctuary_integrity"):
        hud.call(&"set_sanctuary_integrity", 1.0)
    var protocol_key := String(protocol_id).replace("protocol.", "")
    var localized_name := display_name
    var localized_ending := ending
    var locale_service := get_tree().get_first_node_in_group(&"localization_service") as LocalizationService3D
    if locale_service != null:
        var name_key := "endgame.%s.name" % protocol_key
        var ending_key := "endgame.%s.ending" % protocol_key
        var localized_name_candidate := locale_service.text(name_key)
        var localized_ending_candidate := locale_service.text(ending_key)
        if localized_name_candidate != name_key:
            localized_name = localized_name_candidate
        if localized_ending_candidate != ending_key:
            localized_ending = localized_ending_candidate
    var localized_detail := "FIRST VICTORY · %s\n\n%s\n\nThe run reached a complete systemic conclusion without a recurring timed-wave loop." % [localized_name, localized_ending]
    if locale_service != null:
        localized_detail = locale_service.text("hud.ending.first_victory_detail", [localized_name, localized_ending])
    localized_detail += "\n\n" + _build_victory_strategy_epilogue(locale_service)
    # Keep the live completion surface in the selected locale even though the
    # simulation director still owns canonical English data for saves/logs.
    _update_complete_game_objective()
    var victory_status := "FIRST VICTORY · %s" % localized_name
    if locale_service != null:
        victory_status = locale_service.text("notification.first_victory_achieved", [localized_name])
    hud.set_operation(victory_status)
    hud.set_operation_badge("", false)
    hud.show_ending(true, localized_detail, true)


func _build_victory_strategy_epilogue(locale_service: LocalizationService3D) -> String:
    var doctrine_name := _localized_doctrine_display_name(locale_service)
    var component_count := long_operation_director.component_count() if long_operation_director != null else 0
    var outpost_count := _functioning_outpost_count()
    var built_count := run_state.robots_built if run_state != null else 0
    return _localized_text(
        "hud.ending.strategy_epilogue",
        "STRATEGIC LEGACY\nDoctrine: {0} · Remote support posts: {1} · Unique components recovered: {2}\nThe machine society carried {3} constructed frames into the final response. Its choices now belong to the sanctuary's history.",
        [doctrine_name, outpost_count, component_count, built_count]
    )


func _localized_doctrine_display_name(locale_service: LocalizationService3D = null) -> String:
    var doctrine_name := progression.active_doctrine_display_name() if progression != null else "Uncommitted"
    if locale_service == null:
        locale_service = get_tree().get_first_node_in_group(&"localization_service") as LocalizationService3D
    if locale_service != null and progression != null:
        var doctrine_key := "technology.name.%s" % String(progression.active_doctrine_id()).replace(".", "_")
        var localized_doctrine := locale_service.text(doctrine_key)
        if localized_doctrine != doctrine_key:
            doctrine_name = localized_doctrine
    return doctrine_name


func _on_endgame_failed(protocol_id: StringName, reason: String) -> void:
    hud.push_notification(_localized_text("notification.final_protocol.failed", "FINAL PROTOCOL FAILED · {0}", [_localized_endgame_failure_reason(reason).to_upper()]))


func _localized_endgame_failure_reason(reason: String) -> String:
    if reason == "The remote relay network lost too many functioning outposts before the final signal could be severed.":
        return _localized_text("notification.final_protocol.failure.remote_support", "The remote relay network lost too many functioning outposts before the final signal could be severed.")
    if reason == "The Heartforge could not hold the final convergence long enough to complete the protocol.":
        return _localized_text("notification.final_protocol.failure.homefront", "The Heartforge could not hold the final convergence long enough to complete the protocol.")
    return reason


func _functioning_outpost_count() -> int:
    var count := 0
    for site in outpost_director.discovered_sites():
        if site.has_functioning_outpost():
            count += 1
    return count


func _save_game() -> void:
    super._save_game()


func _save_extension_data() -> Dictionary:
    var extensions := super._save_extension_data()
    var full_game_data: Dictionary = extensions.get("full_game", {})
    full_game_data.merge({
        "regions": region_director.to_dictionary(),
        "story_archive": story_archive_director.to_dictionary(),
        "long_operations": long_operation_director.to_dictionary(),
        "machine_society": machine_society_director.to_dictionary(),
        "strategic_ecology": strategic_ecology_director.to_dictionary(),
        "endgame": endgame_director.to_dictionary(),
        "adaptive_defence": adaptive_defense_director.to_dictionary(),
        "continuity_used": continuity_used,
        "first_victory_achieved": first_victory_achieved,
        "sanctuary_continuation": sanctuary_continuation,
        "spawned_region_salvage": _serialize_stringname_dictionary(spawned_region_salvage),
        "machine_relationship_moments": machine_relationship_moments.duplicate(true),
    }, true)
    extensions["full_game"] = full_game_data
    return extensions


func _load_game() -> void:
    _close_operations_hud()
    super._load_game()


func _restore_extension_data(extensions: Variant) -> void:
    super._restore_extension_data(extensions)
    if not (extensions is Dictionary):
        return
    var extension_map := extensions as Dictionary
    var data: Dictionary = extension_map.get("full_game", {})
    if data.is_empty():
        if run_state.expedition_core_recovered:
            region_director.discover_region(&"region.north_ruins")
        return
    region_director.restore_from_dictionary(data.get("regions", {}))
    story_archive_director.restore_from_dictionary(data.get("story_archive", {}))
    long_operation_director.restore_from_dictionary(data.get("long_operations", {}))
    machine_society_director.restore_from_dictionary(data.get("machine_society", {}))
    strategic_ecology_director.restore_from_dictionary(data.get("strategic_ecology", {}))
    endgame_director.restore_from_dictionary(data.get("endgame", {}))
    adaptive_defense_director.restore_from_dictionary(data.get("adaptive_defence", {}))
    if endgame_escalation_director != null:
        endgame_escalation_director.sync_from_endgame_state()
    continuity_used = bool(data.get("continuity_used", false))
    first_victory_achieved = bool(data.get("first_victory_achieved", false))
    sanctuary_continuation = bool(data.get("sanctuary_continuation", first_victory_achieved))
    machine_relationship_moments = data.get("machine_relationship_moments", {}).duplicate(true)
    spawned_region_salvage.clear()
    var saved_salvage: Dictionary = data.get("spawned_region_salvage", {})
    for raw_key in saved_salvage:
        spawned_region_salvage[StringName(str(raw_key))] = bool(saved_salvage[raw_key])
    for region_data in region_director.discovered_regions():
        _ensure_region_salvage(StringName(str(region_data.get("id", ""))))
    story_archive_director.reconcile_discovered_state()
    progression._evaluate_automatic_technologies()
    hud.push_notification(_localized_text("notification.complete.state_restored", "COMPLETE RUN STATE RESTORED · REGIONS, OPERATIONS, ECOLOGY, MACHINE SOCIETY AND ENDGAME RETAINED"))


func _serialize_stringname_dictionary(source: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for raw_key in source:
        result[String(raw_key)] = source[raw_key]
    return result
