class_name OperationsCommandHUD3D
extends CanvasLayer

signal operation_requested(operation_id: StringName)
signal protocol_requested(protocol_id: StringName)
signal close_requested

var backdrop: ColorRect
var panel: PanelContainer
var scroll: ScrollContainer
var title_label: Label
var status_label: Label
var selection_label: Label
var description_label: Label
var requirements_label: Label
var previous_button: Button
var next_button: Button
var authorize_button: Button
var close_button: Button
var mode: StringName = &"operations"
var operations: Array[Dictionary] = []
var protocols: Array[Dictionary] = []
var archive_records: Array[Dictionary] = []
var selected_index: int = 0
var current_operation_status: String = "No long-range operation"
var operation_active: bool = false
var endgame_status: String = "No final protocol active"


func _ready() -> void:
    layer = 38
    _build_ui()
    var viewport := get_viewport()
    if viewport != null:
        viewport.size_changed.connect(_on_viewport_resized)
        call_deferred("apply_safe_layout", Vector2(viewport.get_visible_rect().size))


func _build_ui() -> void:
    backdrop = ColorRect.new()
    backdrop.name = "OperationsBackdrop"
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    # Keep persistent HUD toasts from bleeding through the fixed recap footer
    # while retaining a faint sense of the world behind strategic readouts.
    backdrop.color = Color(0.004, 0.012, 0.016, 0.94)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    backdrop.visible = false
    add_child(backdrop)

    panel = PanelContainer.new()
    panel.name = "OperationsCommandPanel"
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.clip_contents = true
    panel.visible = false
    panel.add_theme_stylebox_override("panel", _panel_style())
    add_child(panel)

    var shell := Control.new()
    shell.name = "OperationsViewportShell"
    panel.add_child(shell)

    scroll = ScrollContainer.new()
    scroll.name = "OperationsScroll"
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.offset_left = 12.0
    scroll.offset_top = 12.0
    scroll.offset_right = -12.0
    # Keep the close action available while long descriptions remain scrollable
    # on short release windows.
    scroll.offset_bottom = -70.0
    shell.add_child(scroll)

    var content := VBoxContainer.new()
    content.name = "OperationsContent"
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 12)
    scroll.add_child(content)

    title_label = _label("LONG-RANGE OPERATIONS", 28, Color("edf2ef"))
    content.add_child(title_label)

    status_label = _label("", 15, Color("9fb2af"))
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    status_label.custom_minimum_size = Vector2(0, 62)
    content.add_child(status_label)

    var navigation := HBoxContainer.new()
    navigation.add_theme_constant_override("separation", 8)
    content.add_child(navigation)

    previous_button = _button("◀ PREVIOUS", select_previous)
    previous_button.custom_minimum_size = Vector2(132, 44)
    navigation.add_child(previous_button)

    selection_label = _label("", 21, Color("f2d9bb"))
    selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    selection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    selection_label.custom_minimum_size = Vector2(320, 52)
    navigation.add_child(selection_label)

    next_button = _button("NEXT ▶", select_next)
    next_button.custom_minimum_size = Vector2(132, 44)
    navigation.add_child(next_button)

    description_label = _label("", 17, Color("d4dedb"))
    description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    description_label.custom_minimum_size = Vector2(0, 220)
    content.add_child(description_label)

    requirements_label = _label("", 15, Color("e4aa67"))
    requirements_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    requirements_label.custom_minimum_size = Vector2(0, 92)
    content.add_child(requirements_label)

    authorize_button = _button("AUTHORIZE", _authorize_selected)
    authorize_button.custom_minimum_size = Vector2(0, 54)
    content.add_child(authorize_button)

    var footer := HBoxContainer.new()
    footer.name = "OperationsFooter"
    footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    footer.offset_left = 12.0
    footer.offset_right = -12.0
    footer.offset_top = -58.0
    footer.offset_bottom = -12.0
    footer.mouse_filter = Control.MOUSE_FILTER_STOP
    shell.add_child(footer)

    close_button = _button("CLOSE · ESC", func() -> void: close_requested.emit())
    close_button.name = "OperationsCloseButton"
    close_button.custom_minimum_size = Vector2(0, 44)
    close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    footer.add_child(close_button)


func open_operations() -> void:
    mode = &"operations"
    selected_index = 0
    backdrop.visible = true
    panel.visible = true
    scroll.scroll_vertical = 0
    apply_safe_layout(Vector2(get_viewport().get_visible_rect().size))
    _refresh()


func open_endgame() -> void:
    mode = &"endgame"
    selected_index = 0
    backdrop.visible = true
    panel.visible = true
    scroll.scroll_vertical = 0
    apply_safe_layout(Vector2(get_viewport().get_visible_rect().size))
    _refresh()


func open_archive(next_records: Array[Dictionary]) -> void:
    mode = &"archive"
    archive_records = next_records.duplicate(true)
    selected_index = 0
    backdrop.visible = true
    panel.visible = true
    scroll.scroll_vertical = 0
    apply_safe_layout(Vector2(get_viewport().get_visible_rect().size))
    _refresh()


func open_recap(condition: String, unresolved_problem: String, expedition: String, threats: String, next_choices: String) -> void:
    mode = &"recap"
    selected_index = 0
    current_operation_status = condition
    archive_records = [{
        "display_name": "RETURNING TO THE HEARTFORGE",
        "description": "CURRENT UNRESOLVED PROBLEM\n%s\n\nACTIVE OR PROPOSED EXPEDITION\n%s\n\nUNFAMILIAR THREATS RECENTLY OBSERVED\n%s" % [unresolved_problem, expedition, threats],
        "recap_choices": next_choices,
    }]
    backdrop.visible = true
    panel.visible = true
    scroll.scroll_vertical = 0
    apply_safe_layout(Vector2(get_viewport().get_visible_rect().size))
    _refresh()


func close() -> void:
    backdrop.visible = false
    panel.visible = false


func is_open() -> bool:
    return panel != null and panel.visible


func update_operations(next_operations: Array[Dictionary], status: String, active: bool = false) -> void:
    operations = next_operations
    operation_active = active
    if mode != &"recap":
        current_operation_status = status
    _clamp_selection()
    _refresh()


func update_protocols(next_protocols: Array[Dictionary], status: String) -> void:
    protocols = next_protocols
    if mode != &"recap":
        endgame_status = status
    _clamp_selection()
    _refresh()


func select_previous() -> void:
    var count := _current_count()
    if count <= 1:
        return
    selected_index = posmod(selected_index - 1, count)
    _refresh()


func select_next() -> void:
    var count := _current_count()
    if count <= 1:
        return
    selected_index = posmod(selected_index + 1, count)
    _refresh()


func _authorize_selected() -> void:
    if mode == &"archive" or mode == &"recap":
        return
    if mode == &"endgame":
        var protocol_id := selected_protocol_id()
        if protocol_id != &"":
            protocol_requested.emit(protocol_id)
    else:
        var operation_id := selected_operation_id()
        if operation_id != &"":
            operation_requested.emit(operation_id)


func selected_operation_id() -> StringName:
    if operations.is_empty():
        return &""
    return StringName(str(operations[selected_index].get("id", "")))


func selected_protocol_id() -> StringName:
    if protocols.is_empty():
        return &""
    return StringName(str(protocols[selected_index].get("id", "")))


func apply_safe_layout(viewport_size: Vector2) -> void:
    if panel == null:
        return
    var width := minf(820.0, maxf(340.0, viewport_size.x - 40.0))
    var height := minf(680.0, maxf(360.0, viewport_size.y - 40.0))
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.offset_left = -width * 0.5
    panel.offset_right = width * 0.5
    panel.offset_top = -height * 0.5
    panel.offset_bottom = height * 0.5


func _on_viewport_resized() -> void:
    apply_safe_layout(Vector2(get_viewport().get_visible_rect().size))


func _current_items() -> Array[Dictionary]:
    if mode == &"endgame":
        return protocols
    if mode == &"archive":
        return archive_records
    if mode == &"recap":
        return archive_records
    return operations


func _current_count() -> int:
    return _current_items().size()


func _clamp_selection() -> void:
    var count := _current_count()
    selected_index = 0 if count <= 0 else clampi(selected_index, 0, count - 1)


func _refresh() -> void:
    if panel == null:
        return
    previous_button.text = _text("command.previous", "◀ PREVIOUS")
    next_button.text = _text("command.next", "NEXT ▶")
    close_button.text = _text("command.close", "CLOSE · ESC")
    authorize_button.text = _text("command.authorize", "AUTHORIZE")
    _clamp_selection()
    var items := _current_items()
    var has_navigation := items.size() > 1
    previous_button.visible = has_navigation
    next_button.visible = has_navigation
    previous_button.disabled = not has_navigation
    next_button.disabled = not has_navigation

    if mode == &"recap":
        title_label.text = _text("command.recap.title", "WORLD RECAP")
        status_label.text = "%s\nA short strategic readout for returning to a persistent world." % current_operation_status
        selection_label.text = _text("command.recap.selection", "RETURNING TO THE HEARTFORGE")
        description_label.text = str(items[0].get("description", ""))
        requirements_label.text = "NEXT AVAILABLE MAJOR CHOICES\n%s\n\nPress ESC, P, L or V to close." % str(items[0].get("recap_choices", "Continue the current objective."))
        previous_button.visible = false
        next_button.visible = false
        authorize_button.visible = false
        return

    if mode == &"endgame":
        title_label.text = _text("command.endgame.title", "FINAL PROTOCOLS")
        status_label.text = "%s\nThe final crisis is player-triggered and causal. No recurring wave schedule exists." % endgame_status
    elif mode == &"archive":
        title_label.text = _text("command.archive.title", "TOWN ARCHIVE")
        var thread_count := items.filter(func(item: Dictionary) -> bool: return str(item.get("kind", "")) == "story_thread").size()
        var record_count := items.size() - thread_count
        status_label.text = "%d story thread%s · %d record%s recovered from physical discoveries.\nThreads assemble from what the machines actually found; this history is optional and never creates another maintenance task." % [thread_count, "" if thread_count == 1 else "s", record_count, "" if record_count == 1 else "s"]
    else:
        title_label.text = _text("command.operations.title", "LONG-RANGE OPERATIONS")
        var operation_status := current_operation_status
        if not items.is_empty() and operation_status.to_lower().contains("no long-range operation"):
            operation_status = _text("command.operations.ready", "A physical operation is ready to authorize.")
        status_label.text = "%s\nEvery group travels through the same persistent world and delivers rewards only after returning." % operation_status

    if items.is_empty():
        selection_label.text = _text("command.archive.empty", "NO RECORDS RECOVERED") if mode == &"archive" else (_text("command.operations.empty", "NO OPERATION AVAILABLE") if mode == &"operations" else _text("command.endgame.locked", "FINAL PROTOCOL LOCKED"))
        description_label.text = _empty_state_text()
        requirements_label.text = "Explore and complete real discoveries to recover the town's remaining records." if mode == &"archive" else "Continue the current strategic objective. The screen becomes actionable only when a real choice exists."
        authorize_button.visible = mode != &"archive"
        authorize_button.text = _text("command.operations.empty", "NO OPERATION AVAILABLE") if mode == &"operations" else _text("command.endgame.locked", "FINAL PROTOCOL LOCKED")
        authorize_button.disabled = true
        return

    var item := items[selected_index]
    selection_label.text = str(item.get("display_name", "Unknown")).to_upper()
    description_label.text = str(item.get("description", ""))
    if mode == &"archive":
        authorize_button.visible = false
        var kind_label := "STORY THREAD" if str(item.get("kind", "")) == "story_thread" else "PHYSICAL RECORD"
        requirements_label.text = "%s · SOURCE: %s\nARC: %s · Press L or ESC to close." % [kind_label, str(item.get("source_name", "Unknown")).to_upper(), str(item.get("arc", "town_history")).replace("_", " ").to_upper()]
        return
    authorize_button.visible = true
    authorize_button.disabled = operation_active and mode == &"operations"
    if mode == &"endgame":
        authorize_button.text = _text("command.endgame.authorize", "INITIATE IRREVERSIBLE PROTOCOL")
        requirements_label.text = "Cost: %d Scrap · %d Cognition Core%s · Duration: %d s\nStarting this deliberately provokes the final ecological response." % [
            int(item.get("scrap_cost", 0)),
            int(item.get("rare_core_cost", 0)),
            "" if int(item.get("rare_core_cost", 0)) == 1 else "s",
            int(round(float(item.get("duration_seconds", 0.0)))),
        ]
    else:
        authorize_button.text = _text("command.operations.active", "OPERATION ACTIVE · FOLLOW WITH F")
        if not operation_active:
            authorize_button.text = _text("command.operations.authorize", "AUTHORIZE PHYSICAL OPERATION")
        var operation_prefix := "ACTIVE GROUP · F TO FOLLOW\n" if operation_active else ""
        requirements_label.text = "%s%s\nCost: %d Scrap · Team: %s · Work exposure: %d s · Threat %.1f" % [
            operation_prefix,
            str(item.get("route_brief", "Route: physical route preview unavailable")),
            int(item.get("scrap_cost", 0)),
            ", ".join(item.get("team_roles", [])),
            int(round(float(item.get("work_seconds", 0.0)))),
            float(item.get("threat_level", 1.0)),
        ]


func _empty_state_text() -> String:
    if mode == &"archive":
        return "No town records have been recovered yet. The first record is preserved at the Heartforge; later records emerge from physical regional discoveries and the post-victory archive."
    if mode == &"endgame":
        return "Recover the required biological components, map the Root Cistern, evolve the Heartforge to tier 5, and authorize an endgame technology. Until then, no final decision is being hidden."
    return "Complete the current Heartforge, outpost, or technology prerequisite. Routine salvage, repair, rebuilding, and replacement continue without opening another management task."


func refresh_localized_text() -> void:
    _refresh()


func _text(key: String, fallback: String, replacements: Array = []) -> String:
    var service := get_tree().get_first_node_in_group(&"localization_service") as LocalizationService3D
    if service != null:
        return service.text(key, replacements)
    var result := fallback
    for index in range(replacements.size()):
        result = result.replace("{%d}" % index, str(replacements[index]))
    return result


func _label(text_value: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_constant_override("outline_size", 3)
    label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.025, 0.94))
    return label


func _button(text_value: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text_value
    button.add_theme_font_size_override("font_size", 16)
    button.focus_mode = Control.FOCUS_NONE
    button.pressed.connect(callback)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.04, 0.075, 0.085, 0.96)
    normal.border_color = Color(0.35, 0.58, 0.6, 0.4)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(6)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.13, 0.15, 0.13, 0.98)
    hover.border_color = Color(0.95, 0.64, 0.34, 0.75)
    var disabled := normal.duplicate() as StyleBoxFlat
    disabled.bg_color = Color(0.025, 0.04, 0.045, 0.82)
    disabled.border_color = Color(0.25, 0.34, 0.35, 0.24)
    button.add_theme_stylebox_override("normal", normal)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("pressed", hover)
    button.add_theme_stylebox_override("disabled", disabled)
    button.add_theme_color_override("font_disabled_color", Color(0.46, 0.54, 0.54, 0.86))
    return button


func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.045, 0.055, 0.98)
    style.border_color = Color(0.43, 0.62, 0.62, 0.55)
    style.set_border_width_all(1)
    style.set_corner_radius_all(12)
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
    style.shadow_size = 16
    style.content_margin_left = 22.0
    style.content_margin_right = 22.0
    style.content_margin_top = 18.0
    style.content_margin_bottom = 18.0
    return style
