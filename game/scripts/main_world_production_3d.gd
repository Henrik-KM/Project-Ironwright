class_name IronwrightProductionWorld3D
extends IronwrightFullGameWorld3D

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


func _extend_forge_interface() -> void:
    if hud == null or hud.forge_content_box == null:
        return
    var box := hud.forge_content_box
    box.add_child(HSeparator.new())
    var engineer_build := hud._forge_button(box, "7  BUILD ENGINEER · 56 Scrap · 7.6 s", func() -> void: _start_manual_build(&"engineer"))
    var engineer_upgrade := hud._forge_button(box, "8  UPGRADE ALL ENGINEERS", func() -> void: _start_manual_upgrade(&"engineer"))
    var heartforge_upgrade := hud._forge_button(box, "9  EVOLVE HEARTFORGE TIER · manual, loud, exposed", _start_heartforge_tier_upgrade)
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

    if run_state.manual_scrap_recovered < 20:
        var wreck := _opening_salvage_target()
        if wreck == null:
            objective_guidance.clear_guidance()
            return
        objective_guidance.set_guidance(
            wreck,
            "SALVAGE WRECK",
            "HOLD E · LOUD",
            Color("f2b365")
        )
        hud.set_objective(
            "RECOVER YOUR FIRST SCRAP",
            "Follow the amber ground lights to the highlighted municipal wreck (%s). Hold E to dismantle it; the pistol goes offline and the noise attracts organisms." % objective_guidance.route_summary()
        )
        if nearest_salvage == null:
            hud.set_prompt("FOLLOW THE AMBER ROUTE · STAY WITHIN THE BULWARK'S PROTECTION")
        else:
            hud.set_prompt("HOLD E · DISMANTLE THE HIGHLIGHTED WRECK · PISTOL OFFLINE · NOISE ATTRACTS ORGANISMS")
        return

    if autonomy_director.count_robots(&"salvager") < 1:
        objective_guidance.set_guidance(
            heartforge,
            "HEARTFORGE",
            "PRESS E · BUILD SCRAPPER",
            Color("72dce1")
        )
        hud.set_objective(
            "BUILD YOUR FIRST SCRAPPER",
            "Return along the cyan route to the Heartforge (%s). Press E at the assembly plate and choose Build Scrapper. Fabrication is loud and leaves you dependent on the Bulwark." % objective_guidance.route_summary()
        )
        if forge_in_range:
            hud.set_prompt("PRESS E · OPEN THE HEARTFORGE · BUILD SCRAPPER")
        else:
            hud.set_prompt("FOLLOW THE CYAN ROUTE BACK TO THE HEARTFORGE")
        return

    if run_state.autonomous_scrap_recovered < 30:
        objective_guidance.clear_guidance()
        hud.set_objective(
            "LET THE SCRAPPER TAKE OVER",
            "Press 2 to set Salvage focus. The machines choose a wreck, form a protected group, travel there physically, recover Scrap, and return without individual orders."
        )
        if autonomy_director.salvage_operation.is_empty():
            hud.set_prompt("PRESS 2 · AUTHORIZE ROUTINE MACHINE SALVAGE")
        return

    if autonomy_director.count_robots(&"guardian") < 1 or autonomy_director.count_robots(&"scout") < 1:
        objective_guidance.set_guidance(
            heartforge,
            "HEARTFORGE",
            "PRESS E · BUILD ESCORT GROUP",
            Color("72dce1")
        )
        hud.set_objective(
            "PREPARE THE NORTH RUINS GROUP",
            "Return to the forge and manually fabricate one Warden and one Pathfinder. The Warden protects vulnerable machines; the Pathfinder keeps the expedition coherent."
        )
        if forge_in_range:
            hud.set_prompt("PRESS E · BUILD THE MISSING WARDEN OR PATHFINDER")
        else:
            hud.set_prompt("FOLLOW THE CYAN ROUTE TO THE HEARTFORGE")
        return

    objective_guidance.clear_guidance()


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
