class_name IronwrightFullGameWorld3D
extends IronwrightBeautifulWorld3D

const WORLD_SITES_PATH := "res://data/world_sites.json"

var progression: ProgressionDirector3D
var outpost_director: OutpostDirector3D
var strategic_hud: StrategicCommandHUD3D
var outpost_sites: Array[OutpostSite3D] = []
var full_game_milestone_complete: bool = false


func _ready() -> void:
    super._ready()
    _setup_full_game_services()
    _extend_forge_interface()
    run_state.log_event("Full-game progression is active. The North Ruins are now the beginning rather than the ending.")
    hud.push_notification("MACHINE SOCIETY AWAKENING · T EVOLUTION · O OUTPOSTS AFTER DISCOVERY")


func _process(delta: float) -> void:
    super._process(delta)
    if progression == null or outpost_director == null or strategic_hud == null:
        return
    var phase_data := progression.current_phase_data()
    strategic_hud.update_progression(
        _strategic_technologies(),
        str(phase_data.get("display_name", String(progression.current_phase))),
        progression.heartforge_tier,
        run_state.scrap,
        run_state.rare_cores,
        progression.active_doctrine_display_name()
    )
    strategic_hud.update_outposts(outpost_director.site_statuses(), outpost_director.operation_summary())
    if not outpost_director.operation.is_empty():
        hud.set_operation(outpost_director.operation_summary())
    _check_full_game_foundation_milestone()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        var key_event := event as InputEventKey
        var key := key_event.keycode

        if strategic_hud != null and strategic_hud.is_open():
            match key:
                KEY_ESCAPE, KEY_T, KEY_O:
                    _close_strategic_hud()
                KEY_LEFT:
                    strategic_hud.select_previous()
                KEY_RIGHT:
                    strategic_hud.select_next()
                KEY_COMMA:
                    strategic_hud.select_previous_role()
                KEY_PERIOD:
                    strategic_hud.select_next_role()
                KEY_ENTER, KEY_SPACE:
                    if strategic_hud.mode == &"evolution":
                        _purchase_technology(strategic_hud.selected_technology_id())
                    elif strategic_hud.mode == &"adaptation":
                        _authorize_adaptation(strategic_hud.selected_adaptation_id())
                    else:
                        _authorize_outpost_build(strategic_hud.selected_site_id(), strategic_hud.selected_role())
                KEY_B:
                    _authorize_outpost_build(strategic_hud.selected_site_id(), strategic_hud.selected_role())
                KEY_U:
                    _authorize_outpost_upgrade(strategic_hud.selected_site_id())
            return

        if hud != null and hud.forge_open:
            match key:
                KEY_7:
                    _start_manual_build(&"engineer")
                    return
                KEY_8:
                    _start_manual_upgrade(&"engineer")
                    return
                KEY_9:
                    _start_heartforge_tier_upgrade()
                    return

        if not paused and not game_ended:
            if key == KEY_T:
                _open_evolution_hud()
                return
            if key == KEY_O:
                _open_outpost_hud()
                return

    super._unhandled_input(event)


func _setup_full_game_services() -> void:
    progression = ProgressionDirector3D.new()
    progression.name = "ProgressionDirector"
    progression.process_mode = Node.PROCESS_MODE_PAUSABLE
    progression.configure(run_state)
    add_child(progression)

    outpost_director = OutpostDirector3D.new()
    outpost_director.name = "OutpostDirector"
    outpost_director.process_mode = Node.PROCESS_MODE_PAUSABLE
    outpost_director.configure(run_state, progression, noise_system, autonomy_director, heartforge, self, operation_detail_director)
    add_child(outpost_director)

    strategic_hud = StrategicCommandHUD3D.new()
    strategic_hud.name = "StrategicCommandHUD"
    add_child(strategic_hud)

    strategic_hud.technology_requested.connect(_purchase_technology)
    strategic_hud.outpost_build_requested.connect(_authorize_outpost_build)
    strategic_hud.outpost_upgrade_requested.connect(_authorize_outpost_upgrade)
    strategic_hud.close_requested.connect(_close_strategic_hud)

    progression.technology_unlocked.connect(_on_technology_unlocked)
    progression.phase_changed.connect(_on_phase_changed)
    progression.heartforge_tier_changed.connect(_on_heartforge_tier_changed)
    progression.progression_changed.connect(_refresh_progression_modifiers)
    _refresh_progression_modifiers()

    outpost_director.operation_changed.connect(_on_outpost_operation_changed)
    outpost_director.outpost_changed.connect(_on_outpost_changed)
    outpost_director.outpost_destroyed.connect(_on_outpost_destroyed)
    outpost_director.haul_returned.connect(_on_outpost_haul_returned)

    _spawn_world_sites()


func _refresh_progression_modifiers() -> void:
    if player != null and player.has_method(&"apply_progression_visuals"):
        player.call(&"apply_progression_visuals", progression.unlocked_effects, progression.heartforge_tier)
    for robot in autonomy_director.living_robots():
        robot.set_progression(progression)


func _spawn_world_sites() -> void:
    var file := FileAccess.open(WORLD_SITES_PATH, FileAccess.READ)
    if file == null:
        run_state.log_event("World site registry is missing; outpost discovery is unavailable.")
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        run_state.log_event("World site registry is invalid; outpost discovery is unavailable.")
        return
    var entries: Array = (parsed as Dictionary).get("sites", [])
    for raw_entry in entries:
        if not (raw_entry is Dictionary):
            continue
        var site := OutpostSite3D.new()
        site.configure(raw_entry as Dictionary)
        add_child(site)
        outpost_sites.append(site)
        outpost_director.register_site(site)


func _extend_forge_interface() -> void:
    if hud == null or hud.forge_panel == null or hud.forge_panel.get_child_count() == 0:
        return
    hud.forge_panel.position = Vector2(-330, -350)
    hud.forge_panel.size = Vector2(660, 700)
    var box := hud.forge_panel.get_child(0) as VBoxContainer
    if box == null:
        return
    box.add_child(HSeparator.new())
    hud._forge_button(box, "7  BUILD ENGINEER · 56 Scrap · 7.6 s", func() -> void: _start_manual_build(&"engineer"))
    hud._forge_button(box, "8  UPGRADE ALL ENGINEERS", func() -> void: _start_manual_upgrade(&"engineer"))
    hud._forge_button(box, "9  EVOLVE HEARTFORGE TIER · manual, loud, exposed", _start_heartforge_tier_upgrade)


func _open_evolution_hud() -> void:
    if player.is_channeling() or hud.forge_open:
        return
    strategic_hud.open_evolution()
    player.input_enabled = false


func _open_outpost_hud() -> void:
    if player.is_channeling() or hud.forge_open:
        return
    strategic_hud.open_outposts()
    player.input_enabled = false


func _close_strategic_hud() -> void:
    if strategic_hud != null:
        strategic_hud.close()
    if player != null and not player.is_channeling():
        player.input_enabled = true


func _strategic_technologies() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for technology in progression.available_technologies():
        var effects: Array = technology.get("effects", [])
        if "heartforge_tier_2" in effects or "heartforge_tier_3" in effects or "heartforge_tier_4" in effects or "heartforge_tier_5" in effects:
            continue
        result.append(technology)
    return result


func _purchase_technology(technology_id: StringName) -> void:
    if technology_id == &"":
        return
    if progression.purchase(technology_id):
        hud.push_notification("EVOLUTION AUTHORIZED · %s" % str(progression.technology(technology_id).get("display_name", String(technology_id))).to_upper())
        _close_strategic_hud()
    else:
        hud.push_notification("EVOLUTION UNAVAILABLE · REQUIREMENTS OR MATERIAL RESERVES ARE INSUFFICIENT")


func _start_heartforge_tier_upgrade() -> void:
    if not forge_in_range or player.is_channeling():
        hud.push_notification("MOVE TO THE HEARTFORGE ASSEMBLY PLATE FIRST")
        return
    var technology_id := StringName("tech.heartforge.tier_%d" % (progression.heartforge_tier + 1))
    if not progression.can_purchase(technology_id):
        var technology := progression.technology(technology_id)
        var cost: Dictionary = technology.get("cost", {})
        hud.push_notification("HEARTFORGE EVOLUTION LOCKED · NEED PREREQUISITES, %d SCRAP AND %d COGNITION CORE" % [
            int(cost.get("scrap", 0)),
            int(cost.get("rare_cores", 0)),
        ])
        return
    _close_forge_menu()
    heartforge.set_operation(&"heartforge_evolution")
    player.begin_channel(
        &"heartforge_evolution",
        heartforge,
        11.0 + float(progression.heartforge_tier) * 2.0,
        "EVOLVING HEARTFORGE TIER %d" % (progression.heartforge_tier + 1),
        {"technology_id": String(technology_id)},
        false,
        35.0,
        1.35
    )


func _on_channel_completed(kind: StringName, target: Node, metadata: Dictionary) -> void:
    if kind != &"heartforge_evolution":
        super._on_channel_completed(kind, target, metadata)
        return
    hud.hide_channel()
    heartforge.set_operation(&"")
    var technology_id := StringName(str(metadata.get("technology_id", "")))
    if progression.purchase(technology_id):
        hud.push_notification("HEARTFORGE TIER %d ONLINE · ENGINEER AND OUTPOST PROTOCOLS AVAILABLE" % progression.heartforge_tier)
    else:
        hud.push_notification("HEARTFORGE EVOLUTION FAILED · REQUIRED MATERIAL WAS NO LONGER AVAILABLE")
    player.input_enabled = true


func _on_channel_cancelled(kind: StringName, target: Node, metadata: Dictionary) -> void:
    if kind != &"heartforge_evolution":
        super._on_channel_cancelled(kind, target, metadata)
        return
    hud.hide_channel()
    heartforge.set_operation(&"")
    player.input_enabled = true
    hud.push_notification("HEARTFORGE EVOLUTION INTERRUPTED · NO MATERIAL CONSUMED")


func _authorize_outpost_build(site_id: StringName, role: StringName) -> void:
    if outpost_director.authorize_build(site_id, role):
        _close_strategic_hud()
        follow_operation = true
        hud.push_notification("OUTPOST PROJECT AUTHORIZED · BUILDERS AND ESCORT ARE LEAVING PHYSICALLY")
    else:
        hud.push_notification("OUTPOST BUILD UNAVAILABLE · CHECK SITE, ROLE TECHNOLOGY, SCRAP, ENGINEER, WARDEN AND ACTIVE OPERATIONS")


func _authorize_outpost_upgrade(site_id: StringName) -> void:
    if outpost_director.authorize_upgrade(site_id):
        _close_strategic_hud()
        follow_operation = true
        hud.push_notification("OUTPOST UPGRADE AUTHORIZED · THE PROTECTED TEAM WILL TRAVEL, REBUILD AND RETURN")
    else:
        hud.push_notification("OUTPOST UPGRADE UNAVAILABLE · CHECK HEARTFORGE TIER, SCRAP, ENGINEER, ESCORT AND ACTIVE OPERATIONS")


func _authorize_adaptation(_adaptation_id: StringName) -> void:
    hud.push_notification("ADAPTIVE DEFENCE IS UNAVAILABLE BEFORE HEARTFORGE TIER IV")


func _on_expedition_returned() -> void:
    if not run_state.expedition_core_recovered:
        return
    var discovered_count := outpost_director.discover_sites_by(&"expedition.north_ruins")
    hud.push_notification("COGNITION CORE RETURNED · %d VIABLE OUTPOST FOUNDATIONS DISCOVERED" % discovered_count)
    run_state.log_event("North Ruins data revealed fixed foundations for autonomous support posts. The run continues.")


func _update_camera(delta: float) -> void:
    if follow_operation and outpost_director != null and not outpost_director.operation.is_empty():
        var target := outpost_director.get_follow_target()
        if target != null:
            var desired_position := target.global_position + Vector3(0.0, camera_height, camera_distance)
            camera.global_position = camera.global_position.lerp(desired_position, 1.0 - exp(-delta * 6.5))
            camera.look_at(target.global_position + Vector3.UP * 0.7, Vector3.UP)
            return
    super._update_camera(delta)


func _update_objective() -> void:
    if progression == null or outpost_director == null:
        return
    if not run_state.expedition_core_recovered:
        super._update_objective()
        return
    if not progression.has_technology(&"tech.machine.group_coordination"):
        hud.set_objective("UNDERSTAND THE FORMATION", "Press T and authorize Group Coordination. Major Heartforge evolution requires a proven coordinated machine doctrine.")
        return
    if progression.heartforge_tier < 2:
        hud.set_objective("EVOLVE THE HEARTFORGE", "Recover enough Scrap, return to the forge, press %s, then choose 9. The rebuild is loud and disables the pistol." % _input_binding_hint(&"iw_interact", "E"))
        return
    if autonomy_director.count_robots(&"engineer") < 1:
        hud.set_objective("FORGE AN ENGINEER", "At the Heartforge, press %s and choose 7. Outposts are never placed manually; this machine constructs them under escort." % _input_binding_hint(&"iw_interact", "E"))
        return
    var functioning := 0
    var highest_tier := 0
    for site in outpost_director.discovered_sites():
        if site.has_functioning_outpost():
            functioning += 1
            highest_tier = maxi(highest_tier, site.outpost.tier)
    if functioning == 0:
        hud.set_objective("AUTHORIZE AN OUTPOST", "Press O. Choose one discovered site and strategic role; machines handle team, route, construction, repair and rebuilding.")
    elif highest_tier < 2:
        hud.set_objective("PROVE AUTONOMOUS GROWTH", "Press O and authorize a tier 2 upgrade. Another protected physical construction operation will travel to the site.")
    else:
        hud.set_objective("THE LONG RUN BEGINS", "The first autonomous network is operational. Continue evolving machines, Heartforge and doctrine while the organic world keeps pressing inward.")


func _save_game() -> void:
    if player.is_channeling():
        hud.push_notification("SAVE DEFERRED · FINISH THE ACTIVE MANUAL CHANNEL")
        return
    super._save_game()


func _save_extension_data() -> Dictionary:
    return {
        "full_game": {
            "schema_version": 2,
            "progression": progression.to_dictionary(),
            "outposts": outpost_director.to_dictionary(),
            "autonomy": autonomy_director.to_dictionary(),
            "foundation_milestone_complete": full_game_milestone_complete,
        },
    }


func _load_game() -> void:
    super._load_game()


func _restore_extension_data(extensions: Variant) -> void:
    if not (extensions is Dictionary):
        return
    var extension_map := extensions as Dictionary
    var data: Dictionary = extension_map.get("full_game", {})
    if data.is_empty():
        if run_state.expedition_core_recovered:
            outpost_director.discover_sites_by(&"expedition.north_ruins")
        return
    progression.restore_from_dictionary(data.get("progression", {}))
    autonomy_director.restore_from_dictionary(data.get("autonomy", {}))
    outpost_director.restore_from_dictionary(data.get("outposts", {}))
    full_game_milestone_complete = bool(data.get("foundation_milestone_complete", false))
    hud.push_notification("FULL-GAME STATE RESTORED · PROGRESSION, DISCOVERIES AND OUTPOSTS RETAINED")


func _on_technology_unlocked(technology_id: StringName, display_name: String, effects: Array) -> void:
    hud.push_notification("TECHNOLOGY ONLINE · %s" % display_name.to_upper())


func _on_phase_changed(phase_id: StringName, display_name: String) -> void:
    hud.push_notification("RUN PHASE · %s" % display_name.to_upper())


func _on_heartforge_tier_changed(tier: int) -> void:
    heartforge.set_progression_tier(tier)
    heartforge.maximum_health = 520.0 + float(tier - 1) * 190.0
    heartforge.current_health = minf(heartforge.maximum_health, heartforge.current_health + 190.0)
    heartforge.health_changed.emit(heartforge.current_health, heartforge.maximum_health)


func _on_outpost_operation_changed(kind: StringName, state: StringName, detail: String) -> void:
    hud.push_notification("%s · %s\n%s" % [String(kind).to_upper(), String(state).to_upper(), detail])
    var release_audio := get_node_or_null("ReleaseAudioDirector") as ReleaseAudioDirector3D
    if release_audio != null:
        var anchor := heartforge.global_position if heartforge != null else Vector3.ZERO
        if outpost_director != null and not outpost_director.operation.is_empty():
            anchor = outpost_director.operation.get("anchor", anchor)
        release_audio.notify_operation(kind, state, detail, anchor)


func _on_outpost_changed(outpost: Outpost3D) -> void:
    if outpost == null:
        return
    run_state.log_event("%s outpost at %s is tier %d with %d%% integrity." % [
        String(outpost.role).capitalize(),
        String(outpost.site_id),
        outpost.tier,
        int(round(100.0 * outpost.current_health / maxf(1.0, outpost.maximum_health))),
    ])
    var tracer_callback := Callable(self, "_spawn_tracer")
    if not outpost.weapon_fired.is_connected(tracer_callback):
        outpost.weapon_fired.connect(tracer_callback)


func _on_outpost_destroyed(outpost: Outpost3D) -> void:
    hud.push_notification("OUTPOST DESTROYED · AUTONOMOUS REBUILD WILL USE SCRAP AND AN ESCORTED ENGINEER TEAM WHEN AVAILABLE")


func _on_outpost_haul_returned(amount: int) -> void:
    hud.push_notification("OUTPOST HAUL RETURNED · %d SCRAP PHYSICALLY DELIVERED" % amount)


func _check_full_game_foundation_milestone() -> void:
    if full_game_milestone_complete:
        return
    for site in outpost_director.discovered_sites():
        if site.has_functioning_outpost() and site.outpost.tier >= 2 and outpost_director.operation.is_empty():
            full_game_milestone_complete = true
            hud.push_notification("FULL-GAME FOUNDATION COMPLETE · PROGRESSION AND A TIER 2 AUTONOMOUS OUTPOST ARE OPERATIONAL")
            run_state.log_event("The first autonomous tier 2 outpost is operational. Play continues without a forced ending.")
            return
