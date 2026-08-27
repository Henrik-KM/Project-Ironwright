extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")
const CASES: Array[Dictionary] = [
    {"label": "compact", "size": Vector2i(800, 520)},
    {"label": "release", "size": Vector2i(1024, 576)},
    {"label": "wide", "size": Vector2i(1280, 720)},
]
const ACCESSIBLE_TEXT_SCALE := 1.35

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    for test_case in CASES:
        await _run_case(str(test_case.get("label", "viewport")), test_case.get("size", Vector2i(800, 520)))
    _finish()


func _run_case(label: String, viewport_size: Vector2i) -> void:
    var test_viewport := SubViewport.new()
    test_viewport.name = "ResolutionAccessibilityViewport_%s" % label
    test_viewport.size = viewport_size
    test_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(test_viewport)

    var world := MAIN_SCENE.instantiate() as IronwrightProductionWorld3D
    test_viewport.add_child(world)
    await process_frame
    await physics_frame
    await process_frame

    _expect(world != null, "%s resolution must instantiate the production scene." % label)
    if world == null:
        test_viewport.queue_free()
        await process_frame
        return

    if world.localization_service != null:
        world.localization_service.set_locale(&"en")
    if world.settings_service != null:
        world.settings_service.set_value(&"text_scale", ACCESSIBLE_TEXT_SCALE, false)
        world.settings_service.apply_accessibility_to_tree(world)

    var hud := world.hud as IronwrightBeautifulHUD3D
    _expect(hud != null, "%s resolution must expose the cinematic HUD." % label)
    if hud != null:
        var health_panel := hud.root_control.get_node_or_null("HealthPanel") as PanelContainer
        _expect(_fits(hud.objective_panel, viewport_size), "%s resolution must keep the objective panel inside the viewport at large text." % label)
        _expect(_fits(hud.resource_panel, viewport_size), "%s resolution must keep the resource panel inside the viewport at large text." % label)
        _expect(_fits(health_panel, viewport_size), "%s resolution must keep the health panel inside the viewport at large text." % label)

        hud.show_forge_menu()
        await process_frame
        _expect(_fits(hud.forge_panel, viewport_size), "%s resolution must keep the forge panel inside the viewport at large text." % label)
        _expect(_fits(hud.forge_close_button, viewport_size), "%s resolution must keep the forge close action inside the viewport at large text." % label)
        if hud.forge_scroll != null and hud.forge_close_button != null:
            _expect(hud.forge_scroll.get_global_rect().end.y <= hud.forge_close_button.get_global_rect().position.y, "%s resolution must keep forge content above its fixed close footer at large text." % label)
        hud.hide_forge_menu()

    var strategic := world.strategic_hud
    if strategic != null:
        strategic.update_outposts([], "No outpost operation is active.")
        strategic.open_outposts()
        await process_frame
        _expect(_fits(strategic.panel, viewport_size), "%s resolution must keep the strategic command panel inside the viewport at large text." % label)
        _expect(_fits(strategic.close_button, viewport_size), "%s resolution must keep the strategic close action inside the viewport at large text." % label)
        if strategic.scroll != null and strategic.close_button != null:
            _expect(strategic.scroll.get_global_rect().end.y <= strategic.close_button.get_global_rect().position.y, "%s resolution must keep strategic content above its fixed close footer at large text." % label)
        strategic.close()

    var operations := world.operations_hud
    if operations != null:
        operations.update_operations([], "No long-range operation is active.")
        operations.open_operations()
        await process_frame
        _expect(_fits(operations.panel, viewport_size), "%s resolution must keep the operations panel inside the viewport at large text." % label)
        _expect(_fits(operations.close_button, viewport_size), "%s resolution must keep the operations close action inside the viewport at large text." % label)
        operations.close()

    print("Resolution accessibility diagnostic · case=%s viewport=%s text_scale=%.2f" % [label, str(viewport_size), ACCESSIBLE_TEXT_SCALE])
    world.queue_free()
    test_viewport.queue_free()
    await process_frame


func _fits(control: Control, viewport_size: Vector2i) -> bool:
    if control == null:
        return false
    var rect := control.get_global_rect()
    return (
        rect.position.x >= -0.5
        and rect.position.y >= -0.5
        and rect.end.x <= float(viewport_size.x) + 0.5
        and rect.end.y <= float(viewport_size.y) + 0.5
    )


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _finish() -> void:
    if failures.is_empty():
        print("Project Ironwright resolution accessibility tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Project Ironwright resolution accessibility tests failed: %d" % failures.size())
    quit(1)
