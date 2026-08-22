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
var spawned_region_salvage: Dictionary = {}
var machine_relationship_moments: Dictionary = {}


func _ready() -> void:
    super._ready()
    _setup_complete_game_services()
    _connect_complete_game_services()
    progression.set_context_provider(Callable(self, "_progression_context"))
    refresh_input_legend()
    run_state.log_event("The complete systemic run is active. Survive, expand autonomy, recover the root components, and choose how the town ends.")
    hud.push_notification("TOWN NETWORKS OPEN · P LONG-RANGE OPERATIONS · V FINAL PROTOCOLS")
    hud.push_notification("BULWARK ONLINE · THE HEARTFORGE HAS A PERSONAL GUARD")


func _process(delta: float) -> void:
    super._process(delta)
    if operations_hud == null or long_operation_director == null or endgame_director == null:
        return
    operations_hud.update_operations(long_operation_director.available_operations(), long_operation_director.operation_summary())
    operations_hud.update_protocols(endgame_director.available_protocols(), endgame_director.status_summary())
    if adaptive_defense_director != null:
        strategic_hud.update_adaptation(adaptive_defense_director.available_plans(), adaptive_defense_director.proposal_summary())

    if not endgame_director.active_protocol.is_empty():
        hud.set_operation(endgame_director.status_summary())
    elif not long_operation_director.active_operation.is_empty():
        hud.set_operation(long_operation_director.operation_summary())

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
            hud.push_notification("SANCTUARY CONTINUES · THE FIRST ARCHIVE IS NOW AVAILABLE THROUGH P")
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
    var aesthetic := get_node_or_null("AestheticDirector") as AestheticDirector3D
    if aesthetic != null:
        aesthetic.connect_story_archive(story_archive_director)
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
    region_lod_director.configure(region_director, player)
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
        hud.push_notification("NO LONG-RANGE OPERATION IS CURRENTLY AVAILABLE")
        return
    if long_operation_director.authorize(operation_id):
        _close_operations_hud()
        follow_operation = true
        hud.push_notification("LONG-RANGE OPERATION AUTHORIZED · FOLLOWS REAL STREETS · F TO TOGGLE FOLLOW")
    else:
        hud.push_notification("OPERATION UNAVAILABLE · CHECK HEARTFORGE TIER, OUTPOSTS, SCRAP, TEAM COMPOSITION AND ACTIVE OPERATIONS")


func _authorize_adaptation(adaptation_id: StringName) -> void:
    if adaptive_defense_director != null and adaptive_defense_director.authorize(adaptation_id):
        _close_strategic_hud()
        hud.push_notification("ADAPTIVE DEFENCE AUTHORIZED · MACHINES ARE RETROFITTING THE HEARTFORGE WITHOUT MANUAL PLACEMENT")
    else:
        hud.push_notification("ADAPTIVE DEFENCE UNAVAILABLE · CHECK THE PROPOSAL AND SCRAP RESERVE")


func _initiate_protocol(protocol_id: StringName) -> void:
    if protocol_id == &"":
        hud.push_notification("FINAL PROTOCOL LOCKED · COMPLETE THE ROOT CISTERN CHAIN AND TIER 5 RESEARCH")
        return
    if endgame_director.initiate(protocol_id):
        _close_operations_hud()
        hud.push_notification("FINAL PROTOCOL INITIATED · THE RESPONSE IS CAUSAL AND IRREVERSIBLE")
    else:
        hud.push_notification("FINAL PROTOCOL UNAVAILABLE · CHECK RESEARCH, COMPONENTS, OUTPOSTS, SCRAP, CORES AND ACTIVE OPERATIONS")


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
        hud.push_notification("DISTRIBUTED CONTINUITY CONSUMED · HEARTFORGE RECOVERED AT 48% · 180 SCRAP LOST")
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
    var evolution_text := ", ".join(evolution_names.slice(0, 5)) if not evolution_names.is_empty() else "No major evolution had been recorded."
    if evolution_names.size() > 5:
        evolution_text += " · +%d more" % (evolution_names.size() - 5)

    var species_text := run_state.observed_species_report() if run_state != null else "Persistent species observations were unavailable."

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
    var loss_text := "%d recorded machine loss%s" % [machine_losses, "" if machine_losses == 1 else "es"]
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
    var events_text := "\n".join(decisive_events) if not decisive_events.is_empty() else "No decisive event was recorded before collapse."

    var pressure_text := strategic_ecology_director.pressure_summary() if strategic_ecology_director != null else "Regional pressure was unavailable."
    var resource_text := "SCRAP %d · CORES %d · MANUAL RECOVERED %d · AUTONOMOUS RECOVERED %d" % [run_state.scrap, run_state.rare_cores, run_state.manual_scrap_recovered, run_state.autonomous_scrap_recovered]
    var resource_decline_text := run_state.resource_decline_report() if run_state != null else "Resource history was unavailable."
    var alternatives := "No unspent response was recorded."
    if progression != null:
        var available := progression.available_technologies()
        var names: Array[String] = []
        for entry in available.slice(0, 3):
            names.append(str(entry.get("display_name", "Unnamed response")))
        if not names.is_empty():
            alternatives = ", ".join(names)
    return "WORLD DURATION · %s\nMAJOR EVOLUTIONS · %s\nECOLOGY OBSERVATIONS · %s\nDECISIVE TIMELINE\n%s\nRESOURCE POSITION · %s\nFIRST SUSTAINED RESOURCE DECLINE · %s\nMACHINE-LOSS PATTERN · %s\nUNRESOLVED THREAT · %s\nALTERNATIVE RESPONSES OBSERVED OR UNLOCKED · %s" % [duration_text, evolution_text, species_text, events_text, resource_text, resource_decline_text, loss_text, pressure_text, alternatives]


func _update_complete_game_objective() -> void:
    if not run_state.expedition_core_recovered or not full_game_milestone_complete:
        return
    if long_operation_director == null or endgame_director == null:
        return

    if not long_operation_director.has_completed(&"operation.west_grid_survey"):
        hud.set_objective("SURVEY THE WEST GRID", "Press P and authorize the first long-range operation. The group travels through real streets, works under pressure, and delivers only after returning.")
        hud.set_prompt("PRESS P · REVIEW AVAILABLE LONG-RANGE OPERATIONS")
        return
    if progression.heartforge_tier < 3:
        hud.set_objective("EVOLVE THE HEARTFORGE TO TIER III", "Return to the forge, press %s, and choose 9. The West Grid archive now permits deeper autonomy and ordinary machine replacement research." % _input_binding_hint(&"iw_interact", "E"))
        return
    if not progression.has_technology(&"tech.machine.forge_assistance"):
        hud.set_objective("REMOVE ORDINARY REPLACEMENT WORK", "Press T and authorize Forge Assistance. The machine society will then replace missing ordinary frames without a maintained production queue.")
        return
    if not long_operation_director.has_completed(&"operation.flood_market_recovery"):
        hud.set_objective("RECOVER THE VITAL MEMBRANE", "Press P to authorize the Flood Market operation. The recovered biological component is required for later Heartforge evolution.")
        return
    if _functioning_outpost_count() < 2:
        hud.set_objective("ESTABLISH A SECOND SUPPORT POST", "Press O and authorize another bounded outpost. Machines choose the Engineer, escort, route, construction, repair and rebuilding.")
        return
    if not long_operation_director.has_completed(&"operation.cathedral_brood_suppression"):
        hud.set_objective("SILENCE THE CATHEDRAL BROOD", "Press P. This suppression operation requires two functioning outposts and a heavily escorted physical group.")
        return
    if progression.heartforge_tier < 4:
        hud.set_objective("EVOLVE THE HEARTFORGE TO TIER IV", "Return to the forge and choose 9. The Vital Membrane and Choral Gland permit adaptive multi-region awareness.")
        return
    if not long_operation_director.has_completed(&"operation.buried_lab_excavation"):
        hud.set_objective("EXCAVATE THE GENOME PRISM", "Press P to send the Engineer-led excavation group to the Buried Laboratories.")
        return
    if _functioning_outpost_count() < 3:
        hud.set_objective("PREPARE THREE REMOTE SUPPORT NODES", "Use O to maintain three functioning autonomous outposts before mapping the Root Cistern.")
        return
    if not long_operation_director.has_completed(&"operation.root_cistern_mapping"):
        hud.set_objective("MAP THE ROOT CISTERN", "Press P. This final deep expedition identifies where the Heartforge can reach the coordinating organic signal.")
        return
    if progression.heartforge_tier < 5:
        hud.set_objective("EVOLVE THE HEARTFORGE TO TIER V", "Return to the forge and choose 9. The recovered components can now be integrated into a final-protocol lattice.")
        return
    if not progression.has_technology(&"tech.endgame.severance") and not progression.has_technology(&"tech.endgame.containment"):
        hud.set_objective("CHOOSE WHAT THE TOWN BECOMES", "Press T and research Severance, Containment, or both. This is a strategic ending choice, not a recurring wave upgrade.")
        return
    if endgame_director.completed_protocol != &"":
        hud.set_objective("FIRST VICTORY", "The final protocol completed. The surviving machine sanctuary continues beyond the first victory.")
        return
    if endgame_director.active_protocol.is_empty():
        hud.set_objective("INITIATE THE FINAL PROTOCOL", "Press V, choose an available protocol, and deliberately provoke the final ecological response when the Heartforge and machine society are ready.")
        hud.set_prompt("PRESS V · REVIEW IRREVERSIBLE FINAL PROTOCOLS")
    else:
        hud.set_objective("HOLD THE HEARTFORGE", "%s. Routine machines and outposts continue acting autonomously; intervene only where the final response breaks through." % endgame_director.status_summary())


func _on_region_discovered(region_id: StringName, display_name: String) -> void:
    _ensure_region_salvage(region_id)
    hud.push_notification("REGION DISCOVERED · %s · PHYSICAL ROUTES NOW KNOWN" % display_name.to_upper())


func _on_story_record_unlocked(_record_id: StringName, display_name: String, description: String) -> void:
    hud.push_notification("TOWN RECORD · %s\n%s" % [display_name.to_upper(), description])


func _on_story_thread_advanced(_thread_id: StringName, display_name: String, stage_count: int, description: String) -> void:
    hud.push_notification("STORY THREAD ADVANCED · %s · %d CLUES\n%s" % [display_name.to_upper(), stage_count, description])


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
    var condition := "WORLD CONDITION · %s\nHEARTFORGE %d%% INTEGRITY · TIER %d · SCRAP %d · CORES %d" % [world_condition, integrity, progression.heartforge_tier, run_state.scrap, run_state.rare_cores]
    var objective_parts := hud.objective_label.text.split("\n", false, 1)
    var unresolved_problem := hud.objective_label.text if objective_parts.is_empty() else "%s\n%s" % [objective_parts[0], objective_parts[1] if objective_parts.size() > 1 else ""]
    var expedition := "No long-range operation is in motion. Press P to review the next physical route."
    if long_operation_director != null and not long_operation_director.active_operation.is_empty():
        expedition = long_operation_director.operation_summary()
    var threats := strategic_ecology_director.pressure_summary() if strategic_ecology_director != null else "Regional pressure is not currently resolved."
    var recent_threats := _recent_threat_recap()
    if not recent_threats.is_empty():
        threats = "%s\n%s" % [threats, recent_threats]
    var next_choices := "Review the current objective on the tactical HUD."
    if not hud.prompt_label.text.strip_edges().is_empty():
        next_choices = hud.prompt_label.text
    if adaptive_defense_director != null and adaptive_defense_director.has_pending_proposal():
        next_choices = "PRESS T · REVIEW THE HEARTFORGE'S PROPOSED ADAPTATION"
    operations_hud.open_recap(condition, unresolved_problem, expedition, threats, next_choices)
    player.input_enabled = false


func _recent_threat_recap() -> String:
    var observations: Array[String] = []
    for event in run_state.event_log:
        var lower := event.to_lower()
        if lower.contains("organic") or lower.contains("pressure") or lower.contains("brood") or lower.contains("destroyed") or lower.contains("protocol"):
            observations.append("• " + event)
        if observations.size() >= 2:
            break
    return "\n".join(observations)


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


func _on_long_operation_changed(operation_id: StringName, state: StringName, detail: String) -> void:
    hud.push_notification("%s · %s\n%s" % [String(operation_id).replace("operation.", "").replace("_", " ").to_upper(), String(state).to_upper(), detail])
    var release_audio := get_node_or_null("ReleaseAudioDirector") as ReleaseAudioDirector3D
    if release_audio != null:
        var anchor := heartforge.global_position if heartforge != null else Vector3.ZERO
        if long_operation_director != null and not long_operation_director.active_operation.is_empty():
            anchor = long_operation_director.active_operation.get("anchor", anchor)
        release_audio.notify_operation(operation_id, state, detail, anchor)


func _on_adaptive_defense_proposal(summary: String) -> void:
    hud.push_notification("ADAPTIVE DEFENCE PROPOSAL · PRESS T TO CHOOSE\n%s" % summary)


func _on_adaptation_changed(adaptation_id: StringName, state: StringName, detail: String) -> void:
    hud.push_notification("HEARTFORGE ADAPTATION · %s · %s\n%s" % [String(adaptation_id).replace("adaptation.", "").replace("_", " ").to_upper(), String(state).to_upper(), detail])


func _on_adaptation_completed(_adaptation_id: StringName, display_name: String) -> void:
    hud.push_notification("HEARTFORGE RESPONSE ONLINE · %s · THE NEW STRUCTURE IS NOW MACHINE-MAINTAINED" % display_name.to_upper())


func _on_long_operation_returned(operation_id: StringName, display_name: String, rewards: Dictionary) -> void:
    hud.push_notification("OPERATION COMPLETE · %s · REWARDS DELIVERED PHYSICALLY" % display_name.to_upper())
    if not bool(machine_relationship_moments.get("first_return", false)):
        machine_relationship_moments["first_return"] = true
        var witness := _machine_witness_identity()
        var moment := "%s brought the group home through the same streets it learned on; the Heartforge answers with a warmer signal." % witness
        run_state.log_event("MACHINE WITNESS · %s" % moment)
        hud.push_notification("MACHINE WITNESS · %s" % moment.to_upper())
        if story_archive_director != null:
            story_archive_director.record_machine_witness(&"machine.first_return")
    progression._evaluate_automatic_technologies()


func _on_component_recovered(component_id: StringName) -> void:
    hud.push_notification("UNIQUE BIOLOGICAL COMPONENT RECOVERED · %s" % String(component_id).replace("component.", "").replace("_", " ").to_upper())


func _on_site_discovery_requested(site_id: StringName) -> void:
    outpost_director.discover_site(site_id)


func _on_autonomous_machine_built(archetype: StringName, level: int, reason: String) -> void:
    var identity := _machine_identity_for_archetype(archetype)
    hud.push_notification("AUTONOMOUS REPLACEMENT · LEVEL %d %s · %s" % [level, identity.to_upper(), String(archetype).to_upper()])
    if not bool(machine_relationship_moments.get("first_replacement", false)):
        machine_relationship_moments["first_replacement"] = true
        var moment := "%s took its place without a queue or command; the machine society is beginning to remember what the town needs." % identity
        run_state.log_event("MACHINE WITNESS · %s" % moment)
        hud.push_notification("MACHINE WITNESS · %s" % moment.to_upper())
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
    hud.push_notification(message.to_upper())


func _on_complete_game_noise(position: Vector3, radius: float, intensity: float, source_kind: StringName) -> void:
    var adjusted := intensity
    if progression != null and progression.has_effect(&"signal_dampening") and source_kind not in [&"heartforge_evolution", &"strategic_operation"]:
        adjusted *= maxf(0.35, 0.68 - progression.modifier_value(&"noise_reduction"))
    if adaptive_defense_director != null:
        adjusted *= adaptive_defense_director.activity_noise_multiplier()
    strategic_ecology_director.record_disturbance(position, adjusted, source_kind)


func _on_endgame_started(protocol_id: StringName, display_name: String) -> void:
    hud.push_notification("FINAL PROTOCOL · %s · ORGANIC PRESSURE IS CONVERGING" % display_name.to_upper())


func _on_endgame_progress(protocol_id: StringName, progress: float, detail: String) -> void:
    if int(progress * 100.0) % 20 == 0:
        hud.set_operation("%s · %d%%" % [String(protocol_id).replace("protocol.", "").capitalize(), int(round(progress * 100.0))])


func _on_endgame_completed(protocol_id: StringName, display_name: String, ending: String) -> void:
    first_victory_achieved = true
    sanctuary_continuation = false
    game_ended = true
    hud.show_ending(true, "FIRST VICTORY · %s\n\n%s\n\nThe run reached a complete systemic conclusion without a recurring timed-wave loop." % [display_name, ending], true)


func _on_endgame_failed(protocol_id: StringName, reason: String) -> void:
    hud.push_notification("FINAL PROTOCOL FAILED · %s" % reason.to_upper())


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
    hud.push_notification("COMPLETE RUN STATE RESTORED · REGIONS, OPERATIONS, ECOLOGY, MACHINE SOCIETY AND ENDGAME RETAINED")


func _serialize_stringname_dictionary(source: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for raw_key in source:
        result[String(raw_key)] = source[raw_key]
    return result
