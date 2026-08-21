class_name StrategicCommandHUD3D
extends CanvasLayer

signal technology_requested(technology_id: StringName)
signal adaptation_requested(adaptation_id: StringName)
signal outpost_build_requested(site_id: StringName, role: StringName)
signal outpost_upgrade_requested(site_id: StringName)
signal close_requested

const ROLES: Array[StringName] = [&"resource", &"defence", &"scout", &"repair"]

var backdrop: ColorRect
var panel: PanelContainer
var scroll: ScrollContainer
var title_label: Label
var summary_label: Label
var selection_label: Label
var detail_label: Label
var cost_label: Label
var previous_button: Button
var next_button: Button
var primary_button: Button
var secondary_button: Button
var mode: StringName = &"evolution"
var technologies: Array[Dictionary] = []
var sites: Array[Dictionary] = []
var adaptations: Array[Dictionary] = []
var selected_index: int = 0
var selected_role_index: int = 0
var phase_name: String = "Embers"
var heartforge_tier: int = 1
var scrap: int = 0
var rare_cores: int = 0
var doctrine_name: String = "Uncommitted"
var operation_summary: String = ""
var adaptation_summary: String = ""


func _ready() -> void:
    layer = 35
    _build_ui()
    var viewport := get_viewport()
    if viewport != null:
        viewport.size_changed.connect(_on_viewport_resized)
        call_deferred("apply_safe_layout", Vector2(viewport.get_visible_rect().size))


func _build_ui() -> void:
    backdrop = ColorRect.new()
    backdrop.name = "StrategicBackdrop"
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.color = Color(0.004, 0.012, 0.016, 0.78)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    backdrop.visible = false
    add_child(backdrop)

    panel = PanelContainer.new()
    panel.name = "StrategicCommandPanel"
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.visible = false
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.add_theme_stylebox_override("panel", _panel_style())
    add_child(panel)

    scroll = ScrollContainer.new()
    scroll.name = "StrategicScroll"
    scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.add_child(scroll)

    var box := VBoxContainer.new()
    box.name = "StrategicContent"
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    box.add_theme_constant_override("separation", 10)
    scroll.add_child(box)

    title_label = _label("STRATEGIC COMMAND", 27, Color("edf2ef"))
    box.add_child(title_label)

    summary_label = _label("", 15, Color("aebbb8"))
    summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    summary_label.custom_minimum_size = Vector2(0, 64)
    box.add_child(summary_label)

    var selection_row := HBoxContainer.new()
    selection_row.name = "SelectionRow"
    selection_row.add_theme_constant_override("separation", 8)
    box.add_child(selection_row)

    previous_button = _button("◀ PREVIOUS", select_previous)
    previous_button.custom_minimum_size = Vector2(132, 44)
    selection_row.add_child(previous_button)

    selection_label = _label("", 20, Color("f4dfc6"))
    selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    selection_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    selection_label.custom_minimum_size = Vector2(300, 44)
    selection_row.add_child(selection_label)

    next_button = _button("NEXT ▶", select_next)
    next_button.custom_minimum_size = Vector2(132, 44)
    selection_row.add_child(next_button)

    detail_label = _label("", 17, Color("d3ddda"))
    detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    detail_label.custom_minimum_size = Vector2(0, 210)
    box.add_child(detail_label)

    cost_label = _label("", 16, Color("e7ad68"))
    cost_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    cost_label.custom_minimum_size = Vector2(0, 58)
    box.add_child(cost_label)

    primary_button = _button("AUTHORIZE", _activate_primary)
    primary_button.custom_minimum_size = Vector2(0, 52)
    box.add_child(primary_button)

    secondary_button = _button("", _activate_secondary)
    secondary_button.custom_minimum_size = Vector2(0, 48)
    secondary_button.visible = false
    box.add_child(secondary_button)

    var close_button := _button("CLOSE · ESC", func() -> void: close_requested.emit())
    close_button.custom_minimum_size = Vector2(0, 44)
    box.add_child(close_button)


func open_evolution() -> void:
    mode = &"evolution"
    selected_index = 0
    backdrop.visible = true
    panel.visible = true
    apply_safe_layout(Vector2(get_viewport().get_visible_rect().size))
    _refresh()


func open_outposts() -> void:
    mode = &"outposts"
    selected_index = 0
    backdrop.visible = true
    panel.visible = true
    apply_safe_layout(Vector2(get_viewport().get_visible_rect().size))
    _refresh()


func open_adaptation(next_adaptations: Array[Dictionary], next_summary: String) -> void:
    mode = &"adaptation"
    adaptations = next_adaptations
    adaptation_summary = next_summary
    selected_index = 0
    backdrop.visible = true
    panel.visible = true
    apply_safe_layout(Vector2(get_viewport().get_visible_rect().size))
    _refresh()


func close() -> void:
    backdrop.visible = false
    panel.visible = false


func is_open() -> bool:
    return panel != null and panel.visible


func apply_safe_layout(viewport_size: Vector2) -> void:
    if panel == null:
        return
    var safe_width := minf(780.0, maxf(320.0, viewport_size.x - 32.0))
    var safe_height := minf(650.0, maxf(340.0, viewport_size.y - 32.0))
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.offset_left = -safe_width * 0.5
    panel.offset_right = safe_width * 0.5
    panel.offset_top = -safe_height * 0.5
    panel.offset_bottom = safe_height * 0.5


func _on_viewport_resized() -> void:
    apply_safe_layout(Vector2(get_viewport().get_visible_rect().size))


func update_progression(
        next_technologies: Array[Dictionary],
        next_phase_name: String,
        next_heartforge_tier: int,
        next_scrap: int,
        next_rare_cores: int,
        next_doctrine_name: String = "Uncommitted"
    ) -> void:
    technologies = next_technologies
    phase_name = next_phase_name
    heartforge_tier = next_heartforge_tier
    scrap = next_scrap
    rare_cores = next_rare_cores
    doctrine_name = next_doctrine_name
    _clamp_selection()
    _refresh()


func update_outposts(next_sites: Array[Dictionary], next_operation_summary: String) -> void:
    sites = next_sites
    operation_summary = next_operation_summary
    _clamp_selection()
    _refresh()


func update_adaptation(next_adaptations: Array[Dictionary], next_summary: String) -> void:
    adaptations = next_adaptations
    adaptation_summary = next_summary
    _clamp_selection()
    if mode == &"adaptation":
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


func select_previous_role() -> void:
    selected_role_index = posmod(selected_role_index - 1, ROLES.size())
    _refresh()


func select_next_role() -> void:
    selected_role_index = posmod(selected_role_index + 1, ROLES.size())
    _refresh()


func selected_technology_id() -> StringName:
    if technologies.is_empty():
        return &""
    return StringName(str(technologies[selected_index].get("id", "")))


func selected_site_id() -> StringName:
    if sites.is_empty():
        return &""
    return StringName(str(sites[selected_index].get("site_id", "")))


func selected_adaptation_id() -> StringName:
    if adaptations.is_empty():
        return &""
    return StringName(str(adaptations[selected_index].get("id", "")))


func selected_role() -> StringName:
    return ROLES[selected_role_index]


func _activate_primary() -> void:
    if mode == &"evolution":
        var technology_id := selected_technology_id()
        if technology_id != &"":
            technology_requested.emit(technology_id)
    elif mode == &"adaptation":
        var adaptation_id := selected_adaptation_id()
        if adaptation_id != &"":
            adaptation_requested.emit(adaptation_id)
    else:
        var site_id := selected_site_id()
        if site_id != &"":
            outpost_build_requested.emit(site_id, selected_role())


func _activate_secondary() -> void:
    if mode != &"outposts":
        return
    var site_id := selected_site_id()
    if site_id != &"":
        outpost_upgrade_requested.emit(site_id)


func _current_count() -> int:
    if mode == &"evolution":
        return technologies.size()
    if mode == &"adaptation":
        return adaptations.size()
    return sites.size()


func _clamp_selection() -> void:
    var count := _current_count()
    selected_index = 0 if count <= 0 else clampi(selected_index, 0, count - 1)


func _set_navigation_state(count: int) -> void:
    var show_navigation := count > 1
    previous_button.visible = show_navigation
    next_button.visible = show_navigation
    previous_button.disabled = not show_navigation
    next_button.disabled = not show_navigation


func _refresh() -> void:
    if panel == null:
        return
    _set_navigation_state(_current_count())
    if mode == &"evolution":
        _refresh_evolution()
    elif mode == &"adaptation":
        _refresh_adaptation()
    else:
        _refresh_outposts()


func _refresh_adaptation() -> void:
    title_label.text = "ADAPTIVE DEFENCE · HEARTFORGE TIER %d" % heartforge_tier
    secondary_button.visible = false
    if adaptations.is_empty():
        summary_label.text = "No structural proposal is waiting. Machines continue ordinary defence without opening a maintenance task."
        selection_label.text = "NO PROPOSAL"
        detail_label.text = adaptation_summary
        cost_label.text = "Status: the architect will speak only when a real structural decision exists."
        primary_button.text = "NO PROPOSAL"
        primary_button.disabled = true
        return
    summary_label.text = adaptation_summary
    primary_button.text = "AUTHORIZE MACHINE RETROFIT"
    primary_button.disabled = false
    var adaptation := adaptations[selected_index]
    selection_label.text = str(adaptation.get("display_name", "Unknown response")).to_upper()
    detail_label.text = "%s\n\nProblem addressed: %s\n\nTrade-off: %s" % [
        str(adaptation.get("description", "")),
        str(adaptation.get("problem", "")),
        str(adaptation.get("tradeoff", "")),
    ]
    var cost: Dictionary = adaptation.get("cost", {})
    cost_label.text = "Machine construction: %.1f seconds · Cost: %d Scrap · geometry and repair remain delegated" % [
        float(adaptation.get("build_seconds", 12.0)),
        int(cost.get("scrap", 0)),
    ]


func _refresh_evolution() -> void:
    title_label.text = "EVOLUTION · %s · HEARTFORGE TIER %d" % [phase_name.to_upper(), heartforge_tier]
    secondary_button.visible = false

    if technologies.is_empty():
        summary_label.text = "No strategic decision is required at this moment. The machines will continue routine work without opening another management task."
        selection_label.text = "NO EVOLUTION AVAILABLE"
        detail_label.text = "Continue the current objective. Recover Scrap, fabricate the required machine class, complete a physical expedition, or meet the next Heartforge prerequisite. The interface will become actionable only when a real choice exists."
        cost_label.text = "Status: locked by world progress — not by a hidden menu selection."
        primary_button.text = "NO EVOLUTION AVAILABLE"
        primary_button.disabled = true
        return

    summary_label.text = "Choose one consequential technology. Routine execution remains delegated to the machines. Scrap %d · Cognition Cores %d · Active doctrine: %s" % [scrap, rare_cores, doctrine_name]
    primary_button.text = "AUTHORIZE EVOLUTION"
    primary_button.disabled = false
    var technology := technologies[selected_index]
    selection_label.text = str(technology.get("display_name", "Unknown technology")).to_upper()
    detail_label.text = "%s\n\nBranch: %s\nEffects: %s" % [
        str(technology.get("description", "")),
        str(technology.get("branch", "unknown")).capitalize(),
        ", ".join(technology.get("effects", [])),
    ]
    var cost: Dictionary = technology.get("cost", {})
    cost_label.text = "Cost: %d Scrap · %d Cognition Core%s" % [
        int(cost.get("scrap", 0)),
        int(cost.get("rare_cores", 0)),
        "" if int(cost.get("rare_cores", 0)) == 1 else "s",
    ]


func _refresh_outposts() -> void:
    title_label.text = "AUTONOMOUS OUTPOST PROJECTS · HEARTFORGE TIER %d" % heartforge_tier
    summary_label.text = "Choose a discovered fixed site and strategic role. Machines choose builders, escorts, route, construction, repair, hauling, and rebuilding."
    primary_button.text = "AUTHORIZE AUTONOMOUS BUILD"
    secondary_button.text = "AUTHORIZE AUTONOMOUS UPGRADE"
    secondary_button.visible = true

    if heartforge_tier < 2:
        selection_label.text = "PROTOCOLS LOCKED"
        detail_label.text = "Autonomous outposts unlock at Heartforge Tier 2. Recover a Cognition Core and authorize the next Heartforge evolution before asking machines to establish a fixed support site."
        cost_label.text = "Status: locked by Heartforge progression · no site placement or worker management is available."
        primary_button.text = "OUTPOST PROTOCOLS LOCKED"
        primary_button.disabled = true
        secondary_button.text = "OUTPOST PROTOCOLS LOCKED"
        secondary_button.disabled = true
        return

    if sites.is_empty():
        selection_label.text = "NO DISCOVERED SITES"
        detail_label.text = "Pathfinders must discover viable foundations through physical excursions. Outposts cannot be placed freely and do not claim territory."
        cost_label.text = "Status: no site decision exists yet. %s" % operation_summary
        primary_button.text = "NO BUILD SITE AVAILABLE"
        primary_button.disabled = true
        secondary_button.text = "NO OUTPOST TO UPGRADE"
        secondary_button.disabled = true
        return

    var site := sites[selected_index]
    selection_label.text = str(site.get("display_name", "Unknown site")).to_upper()
    var chosen_role := selected_role()
    detail_label.text = "%s\n\nSelected role: %s\n%s\n\nCurrent activity: %s\n\nUse , and . to change role." % [
        str(site.get("status", "")),
        String(chosen_role).capitalize(),
        _role_description(chosen_role),
        operation_summary,
    ]
    var has_outpost := bool(site.get("has_outpost", false))
    var alive := bool(site.get("alive", false))
    var tier := int(site.get("tier", 0))
    cost_label.text = "Construction requires Scrap, a free Engineer, a Warden escort, and route capacity. Destroyed posts rebuild automatically when those conditions return."
    primary_button.disabled = heartforge_tier < 2 or has_outpost
    secondary_button.disabled = not alive or tier >= mini(3, heartforge_tier)


func _role_description(value: StringName) -> String:
    match value:
        &"defence":
            return "Automatically attacks nearby organisms and creates a proxy defensive screen away from the Heartforge."
        &"scout":
            return "Extends early warning and reports organic contacts without creating a permanent management task."
        &"repair":
            return "Repairs friendly machines passing through its service radius during remote operations."
        _:
            return "Recovers local Scrap into forward storage; protected haulers physically carry it to the Heartforge."


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
    style.bg_color = Color(0.025, 0.045, 0.055, 0.97)
    style.border_color = Color(0.43, 0.62, 0.62, 0.55)
    style.set_border_width_all(1)
    style.set_corner_radius_all(12)
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
    style.shadow_size = 16
    style.content_margin_left = 22.0
    style.content_margin_right = 22.0
    style.content_margin_top = 18.0
    style.content_margin_bottom = 18.0
    return style
