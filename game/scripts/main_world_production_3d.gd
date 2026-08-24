class_name IronwrightProductionWorld3D
extends IronwrightCompleteGameWorld3D

## Production entrypoint. It preserves the long-run systems while owning the
## first-session guidance and progression gates that should not leak into the
## lower-level simulation world.

var objective_guidance: ObjectiveGuidance3D


func _ready() -> void:
    super._ready()
    objective_guidance = ObjectiveGuidance3D.new()
    objective_guidance.name = "ObjectiveGuidance"
    objective_guidance.configure(player)
    add_child(objective_guidance)
    run_state.log_event("The Bulwark projects a visible route to the nearest recoverable wreck.")


func _process(delta: float) -> void:
    super._process(delta)
    _update_first_session_guidance()
    # The opening guidance still runs for the release shell, but an active
    # physical operation is the stronger exception and must replace stale
    # salvage/forge instructions in the same frame.
    if long_operation_director != null and not long_operation_director.active_operation.is_empty():
        _update_complete_game_objective()


func _extend_forge_interface() -> void:
    if hud == null or hud.forge_content_box == null:
        return
    var box := hud.forge_content_box
    box.add_child(HSeparator.new())
    var engineer_build := hud._forge_button(box, "7  BUILD ENGINEER · 56 Scrap · 7.6 s", func() -> void: _start_manual_build(&"engineer"), "forge.build.engineer")
    var engineer_upgrade := hud._forge_button(box, "8  UPGRADE ALL ENGINEERS", func() -> void: _start_manual_upgrade(&"engineer"), "forge.upgrade.engineer")
    var heartforge_upgrade := hud._forge_button(box, "9  EVOLVE HEARTFORGE TIER · manual, loud, exposed", _start_heartforge_tier_upgrade, "forge.evolve")
    if hud is IronwrightBeautifulHUD3D:
        var beautiful := hud as IronwrightBeautifulHUD3D
        beautiful._style_button(engineer_build)
        beautiful._style_button(engineer_upgrade)
        beautiful._style_button(heartforge_upgrade)
    hud.apply_safe_layout(Vector2(get_viewport().get_visible_rect().size))


func _start_manual_build(archetype: StringName) -> void:
    if archetype == &"engineer" and (progression == null or not progression.has_effect(&"engineer_build_available")):
        if hud != null:
            hud.push_notification("ENGINEER FRAME LOCKED · EVOLVE THE HEARTFORGE TO TIER 2")
        return
    super._start_manual_build(archetype)


func _start_manual_upgrade(archetype: StringName) -> void:
    if archetype == &"engineer" and (progression == null or not progression.has_effect(&"engineer_build_available")):
        if hud != null:
            hud.push_notification("ENGINEER UPGRADES LOCKED · EVOLVE THE HEARTFORGE TO TIER 2")
        return
    super._start_manual_upgrade(archetype)


func _update_first_session_guidance() -> void:
    if objective_guidance == null or run_state == null or autonomy_director == null:
        return

    var interact_hint := _input_binding_hint(&"iw_interact", "E")

    if run_state.manual_scrap_recovered < 20:
        var wreck := _opening_salvage_target()
        if wreck == null:
            objective_guidance.clear_guidance()
            return
        objective_guidance.set_guidance(
            wreck,
            _localized_release_text("guidance.salvage", "SALVAGE WRECK"),
            _localized_release_text("guidance.salvage.hold", "HOLD {0} · LOUD", [interact_hint]),
            Color("f2b365")
        )
        hud.set_objective(
            _localized_release_text("objective.opening.salvage.title", "RECOVER YOUR FIRST SCRAP"),
            _localized_release_text("objective.opening.salvage.detail", "Follow the amber ground lights to the highlighted municipal wreck ({0}). Hold {1} to dismantle it; the pistol goes offline and the noise attracts organisms.", [objective_guidance.route_summary(), interact_hint])
        )
        if nearest_salvage == null:
            hud.set_prompt(_localized_release_text("prompt.opening.route", "FOLLOW THE AMBER ROUTE · STAY WITHIN THE BULWARK'S PROTECTION"))
        else:
            hud.set_prompt(_localized_release_text("prompt.opening.salvage", "HOLD {0} · DISMANTLE THE HIGHLIGHTED WRECK · PISTOL OFFLINE · NOISE ATTRACTS ORGANISMS", [interact_hint]))
        return

    if autonomy_director.count_robots(&"salvager") < 1:
        objective_guidance.set_guidance(
            heartforge,
            _localized_release_text("guidance.heartforge", "HEARTFORGE"),
            _localized_release_text("guidance.heartforge.build", "PRESS {0} · BUILD SCRAPPER", [interact_hint]),
            Color("72dce1")
        )
        hud.set_objective(
            _localized_release_text("objective.opening.scrapper.title", "BUILD YOUR FIRST SCRAPPER"),
            _localized_release_text("objective.opening.scrapper.detail", "Return along the cyan route to the Heartforge ({0}). Press {1} at the assembly plate and choose Build Scrapper. Fabrication is loud and leaves you dependent on the Bulwark.", [objective_guidance.route_summary(), interact_hint])
        )
        if forge_in_range:
            hud.set_prompt(_localized_release_text("prompt.opening.forge", "PRESS {0} · OPEN THE HEARTFORGE · BUILD SCRAPPER", [interact_hint]))
        else:
            hud.set_prompt(_localized_release_text("prompt.opening.return", "FOLLOW THE CYAN ROUTE BACK TO THE HEARTFORGE"))
        return

    if run_state.autonomous_scrap_recovered < 30:
        objective_guidance.clear_guidance()
        hud.set_objective(
            _localized_release_text("objective.opening.autonomy.title", "LET THE SCRAPPER TAKE OVER"),
            _localized_release_text("objective.opening.autonomy.detail", "Press 2 to set Salvage focus. The machines choose a wreck, form a protected group, travel there physically, recover Scrap, and return without individual orders.")
        )
        if autonomy_director.salvage_operation.is_empty():
            hud.set_prompt(_localized_release_text("prompt.opening.autonomy", "PRESS 2 · AUTHORIZE ROUTINE MACHINE SALVAGE"))
        return

    if autonomy_director.count_robots(&"guardian") < 1 or autonomy_director.count_robots(&"scout") < 1:
        objective_guidance.set_guidance(
            heartforge,
            _localized_release_text("guidance.heartforge", "HEARTFORGE"),
            _localized_release_text("guidance.heartforge.escort", "PRESS {0} · BUILD ESCORT GROUP", [interact_hint]),
            Color("72dce1")
        )
        hud.set_objective(
            _localized_release_text("objective.opening.expedition.title", "PREPARE THE NORTH RUINS GROUP"),
            _localized_release_text("objective.opening.expedition.detail", "Return to the forge and manually fabricate one Warden and one Pathfinder. The Warden protects vulnerable machines; the Pathfinder keeps the expedition coherent.")
        )
        if forge_in_range:
            hud.set_prompt(_localized_release_text("prompt.opening.escort", "PRESS {0} · BUILD THE MISSING WARDEN OR PATHFINDER", [interact_hint]))
        else:
            hud.set_prompt(_localized_release_text("prompt.opening.return", "FOLLOW THE CYAN ROUTE BACK TO THE HEARTFORGE"))
        return

    objective_guidance.clear_guidance()


func _localized_release_text(key: String, fallback: String, replacements: Array = []) -> String:
    var service := get_tree().get_first_node_in_group(&"localization_service") as LocalizationService3D
    if service != null:
        return service.text(key, replacements)
    var result := fallback
    for index in range(replacements.size()):
        result = result.replace("{%d}" % index, str(replacements[index]))
    return result


func _opening_salvage_target() -> SalvagePile3D:
    var best: SalvagePile3D
    var best_distance := INF
    for candidate in get_tree().get_nodes_in_group(&"salvage_piles"):
        if not is_instance_valid(candidate) or not (candidate is SalvagePile3D):
            continue
        var pile := candidate as SalvagePile3D
        if not pile.has_scrap():
            continue
        var distance := heartforge.global_position.distance_to(pile.global_position)
        if distance < best_distance:
            best = pile
            best_distance = distance
    return best


func _on_heartforge_destroyed() -> void:
    super._on_heartforge_destroyed()
