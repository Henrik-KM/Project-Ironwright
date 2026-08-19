extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    root.size = Vector2i(800, 520)
    var world := MAIN_SCENE.instantiate() as IronwrightProductionWorld3D
    root.add_child(world)
    await process_frame
    await physics_frame
    await process_frame

    _expect(world != null, "The production scene must instantiate for first-session UX testing.")
    if world == null:
        _finish()
        return

    var hud := world.hud as IronwrightBeautifulHUD3D
    _expect(hud != null, "The production scene must use the cinematic HUD.")
    if hud == null:
        _finish()
        return

    hud.apply_safe_layout(Vector2(800, 520))
    hud.show_forge_menu()
    await process_frame
    var forge_rect := hud.forge_panel.get_global_rect()
    _expect(_rect_fits_viewport(forge_rect, Vector2(800, 520)), "The forge menu must remain fully inside an 800×520 viewport.")
    _expect(hud.forge_scroll != null, "The forge menu must scroll instead of clipping tall fabrication content.")
    _expect(hud.forge_content_box != null and hud.forge_content_box.get_child_count() >= 12, "The responsive forge must expose all base and full-game fabrication actions.")
    hud.hide_forge_menu()

    var objective_rect := hud.objective_panel.get_global_rect()
    hud.push_notification("FIRST MACHINE REPORT")
    hud.push_notification("SECOND MACHINE REPORT")
    hud.push_notification("THIRD MACHINE REPORT")
    hud.push_notification("FOURTH MACHINE REPORT")
    await process_frame
    var notification_rect := hud.notification_panel.get_global_rect()
    _expect(not objective_rect.intersects(notification_rect), "Persistent objective text and transient reports must occupy separate regions.")
    _expect(hud.notifications.size() == IronwrightHUD3D.MAX_VISIBLE_NOTIFICATIONS, "The visible report stack must remain strictly bounded.")
    _expect(hud.notification_panel.visible, "New reports must appear in the dedicated toast panel.")
    hud._process(IronwrightHUD3D.NOTIFICATION_LIFETIME_SECONDS + 0.2)
    _expect(hud.notifications.is_empty() and not hud.notification_panel.visible, "Reports must expire instead of permanently burying the objective.")

    _expect(hud.resource_label.get_theme_font_size("font_size") >= 20, "Resource values must use a readable font size.")
    _expect(hud.resource_label.position.y + hud.resource_label.size.y < hud.focus_label.position.y, "Resource values must not collide with machine focus text.")
    _expect(hud.focus_label.position.y + hud.focus_label.size.y <= hud.operation_label.position.y, "Machine focus must not collide with operation status.")
    _expect(hud.prompt_panel != hud.objective_panel, "Immediate interactions must have a dedicated panel separate from the persistent objective.")

    var strategic := world.strategic_hud
    strategic.update_progression([], "Embers", 1, world.run_state.scrap, world.run_state.rare_cores)
    strategic.open_evolution()
    await process_frame
    _expect(not strategic.previous_button.visible and not strategic.next_button.visible, "Empty evolution state must hide meaningless Previous and Next controls.")
    _expect(strategic.primary_button.disabled, "Empty evolution state must not expose an actionable authorization button.")
    _expect(strategic.primary_button.text == "NO EVOLUTION AVAILABLE", "Empty evolution state must state clearly that no choice exists.")
    _expect("No strategic decision" in strategic.summary_label.text, "Empty evolution state must explain that no decision is currently required.")
    strategic.close()

    world._process(0.1)
    await process_frame
    _expect(world.objective_guidance != null and world.objective_guidance.is_guiding(), "The opening must immediately guide the player to a physical objective.")
    _expect(world.objective_guidance.target is SalvagePile3D, "The opening guidance target must be a real salvage wreck.")
    _expect("HOLD E" in world.objective_guidance.marker_label.text, "The wreck marker must show the immediate interaction.")
    _expect("RECOVER YOUR FIRST SCRAP" in hud.objective_label.text, "The opening objective must name the concrete next action.")
    _expect("AMBER" in hud.prompt_label.text, "The immediate prompt must point the player toward the visible route cue.")
    world.objective_guidance._process(0.1)
    var visible_route_dots := 0
    for dot in world.objective_guidance.route_dots:
        if dot.visible:
            visible_route_dots += 1
    _expect(visible_route_dots > 0, "The opening must display a world-space route cue to the wreck.")

    world.run_state.manual_scrap_recovered = 20
    world._process(0.1)
    _expect(world.objective_guidance.target == world.heartforge, "After first salvage, guidance must lead back to the Heartforge rather than disappear.")
    _expect("BUILD YOUR FIRST SCRAPPER" in hud.objective_label.text, "The next objective must clearly identify the first fabrication action.")

    _finish()


func _rect_fits_viewport(rect: Rect2, viewport_size: Vector2) -> bool:
    return (
        rect.position.x >= -0.5
        and rect.position.y >= -0.5
        and rect.end.x <= viewport_size.x + 0.5
        and rect.end.y <= viewport_size.y + 0.5
    )


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _finish() -> void:
    if failures.is_empty():
        print("Project Ironwright first-session UX tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Project Ironwright first-session UX tests failed: %d" % failures.size())
    quit(1)
