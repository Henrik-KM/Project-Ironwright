class_name IronwrightHUD3D
extends CanvasLayer

const MECHROMANCER_PORTRAIT: Texture2D = preload("res://assets/mechromancer/mechromancer_portrait.png")

signal forge_build_selected(archetype: StringName)
signal forge_upgrade_selected(archetype: StringName)
signal forge_closed
signal expedition_authorized

const NOTIFICATION_LIFETIME_SECONDS: float = 6.5
const MAX_VISIBLE_NOTIFICATIONS: int = 2

var root_control: Control
var objective_panel: PanelContainer
var prompt_panel: PanelContainer
var resource_panel: PanelContainer
var notification_panel: PanelContainer
var objective_label: Label
var objective_heading: Label
var prompt_label: Label
var resource_label: Label
var reserve_heading: Label
var focus_label: Label
var operation_label: Label
var player_bar: ProgressBar
var companion_bar: ProgressBar
var forge_bar: ProgressBar
var player_portrait: TextureRect
var forge_label: Label
var forge_backdrop: ColorRect
var forge_panel: PanelContainer
var forge_scroll: ScrollContainer
var forge_content_box: VBoxContainer
var forge_close_button: Button
var forge_title: Label
var forge_copy: Label
var forge_reserve_label: Label
var forge_buttons: Array[Button] = []
var notification_label: Label
var notification_heading: Label
var map_banner: Label
var help_label: Label
var player_status_label: Label
var companion_status_label: Label
var focus_help_label: Label
var operation_badge: PanelContainer
var operation_badge_label: Label
var ending_panel: Control
var forge_open: bool = false
var transient_feedback_locked: bool = false
var notifications: Array[String] = []
var notification_ages: Array[float] = []
var displayed_scrap: int = 24
var displayed_rare_cores: int = 0
var displayed_focus: StringName = &"defend"


func _ready() -> void:
    layer = 20
    _build_ui()
    var viewport := get_viewport()
    if viewport != null:
        viewport.size_changed.connect(_on_viewport_resized)
        call_deferred("apply_safe_layout", Vector2(viewport.get_visible_rect().size))


func _process(delta: float) -> void:
    if notification_ages.is_empty():
        return
    var changed := false
    for index in range(notification_ages.size() - 1, -1, -1):
        notification_ages[index] += delta
        if notification_ages[index] >= NOTIFICATION_LIFETIME_SECONDS:
            notification_ages.remove_at(index)
            notifications.remove_at(index)
            changed = true
    if changed:
        _refresh_notifications()


func _build_ui() -> void:
    root_control = Control.new()
    root_control.name = "HUDRoot"
    root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root_control)

    objective_panel = _panel(Vector2(22, 22), Vector2(440, 148))
    objective_panel.name = "ObjectivePanel"
    objective_heading = _label(objective_panel, "CURRENT OBJECTIVE", 12, Color("87a4a5"))
    objective_heading.position = Vector2(18, 12)
    objective_heading.size = Vector2(400, 20)
    objective_label = _label(objective_panel, "FIRST LIGHT\nSurvive beside the Heartforge.", 19, Color("e5ece9"))
    objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    objective_label.position = Vector2(18, 34)
    objective_label.size = Vector2(400, 96)
    objective_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

    prompt_panel = _panel(Vector2(-340, -108), Vector2(680, 68), true, true)
    prompt_panel.name = "ImmediateInteractionPanel"
    prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    prompt_panel.position = Vector2(-340, -108)
    prompt_label = _label(prompt_panel, "", 17, Color("d4a267"))
    prompt_label.position = Vector2(20, 12)
    prompt_label.size = Vector2(640, 44)
    prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

    resource_panel = _panel(Vector2(-406, 22), Vector2(384, 224), true)
    resource_panel.name = "ResourcePanel"
    reserve_heading = _label(resource_panel, "MATERIAL RESERVES", 12, Color("87a4a5"))
    reserve_heading.position = Vector2(18, 10)
    reserve_heading.size = Vector2(344, 20)
    resource_label = _label(resource_panel, "SCRAP  24\nCOGNITION CORES  0", 21, Color("d9e1de"))
    resource_label.position = Vector2(18, 34)
    resource_label.size = Vector2(344, 74)
    resource_label.add_theme_constant_override("line_spacing", 6)
    focus_label = _label(resource_panel, "FOCUS · DEFEND", 17, Color("78d3d7"))
    focus_label.position = Vector2(18, 122)
    focus_label.size = Vector2(344, 30)
    operation_label = _label(resource_panel, "No remote operation", 14, Color("9aa9a6"))
    operation_label.position = Vector2(18, 166)
    operation_label.size = Vector2(344, 46)
    operation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    notification_panel = _panel(Vector2(-446, 266), Vector2(424, 206), true)
    notification_panel.name = "NotificationToastPanel"
    notification_panel.visible = false
    notification_heading = _label(notification_panel, "MACHINE REPORTS", 12, Color("87a4a5"))
    notification_heading.position = Vector2(18, 10)
    notification_heading.size = Vector2(388, 20)
    notification_label = _label(notification_panel, "", 14, Color("dce5e2"))
    notification_label.position = Vector2(18, 34)
    notification_label.size = Vector2(388, 158)
    notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notification_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    notification_label.clip_text = true
    notification_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

    var health_panel := _panel(Vector2(22, -142), Vector2(440, 118), false, true)
    health_panel.name = "HealthPanel"
    player_portrait = TextureRect.new()
    player_portrait.name = "MechromancerPortrait"
    player_portrait.texture = MECHROMANCER_PORTRAIT
    # The authored portrait remains available to the character/HUD contract,
    # but the square source is not rendered into the tactical frame. The
    # previous anchored layout could expand it into a screen-fixed figure that
    # obscured the world and competed with the real in-world Mechromancer.
    player_portrait.visible = false
    player_portrait.position = Vector2(14, 14)
    player_portrait.size = Vector2(68, 90)
    player_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    player_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    player_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _content_parent(health_panel).add_child(player_portrait)
    player_status_label = _label(health_panel, "MECHROMANCER · WEAK PISTOL", 14, Color("d9e1de"))
    player_status_label.position = Vector2(96, 10)
    player_status_label.size = Vector2(326, 22)
    player_bar = _progress(health_panel, Vector2(96, 34), Vector2(326, 18), Color("79d8dc"))
    companion_status_label = _label(health_panel, "BULWARK · PRIMARY PROTECTION", 14, Color("d9e1de"))
    companion_status_label.position = Vector2(96, 61)
    companion_status_label.size = Vector2(326, 22)
    companion_bar = _progress(health_panel, Vector2(96, 87), Vector2(326, 16), Color("d6a665"))

    var focus_panel := _panel(Vector2(-520, -102), Vector2(498, 78), true, true)
    focus_panel.name = "CommandHelpPanel"
    focus_help_label = _label(focus_panel, "1 DEFEND    2 SALVAGE    3 EXPEDITION    T EVOLVE    O OUTPOSTS    M MAP    F FOLLOW    G NEXT GROUP", 14, Color("b8c5c2"))
    focus_help_label.position = Vector2(16, 13)
    focus_help_label.size = Vector2(466, 50)
    focus_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    focus_help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    var channel_panel := _panel(Vector2(-250, -188), Vector2(500, 72), true, true)
    channel_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    channel_panel.position = Vector2(-250, -188)
    channel_panel.name = "ChannelPanel"
    channel_panel.visible = false
    forge_label = _label(channel_panel, "", 15, Color("f0dfc6"))
    forge_label.position = Vector2(16, 8)
    forge_label.size = Vector2(468, 24)
    forge_bar = _progress(channel_panel, Vector2(16, 38), Vector2(468, 18), Color("d4a267"))

    map_banner = _label(root_control, "COMMAND MAP · LIVE PHYSICAL POSITIONS · F TO FOLLOW ACTIVE GROUP · G NEXT GROUP", 17, Color("79d8dc"))
    map_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    map_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    map_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
    map_banner.offset_left = 18
    map_banner.offset_right = -18
    map_banner.offset_top = 16
    map_banner.offset_bottom = 52
    map_banner.visible = false

    operation_badge = PanelContainer.new()
    operation_badge.name = "ActiveOperationBadge"
    operation_badge.set_anchors_preset(Control.PRESET_CENTER_TOP)
    operation_badge.position = Vector2(-240, 66)
    operation_badge.size = Vector2(480, 42)
    operation_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    operation_badge.visible = false
    root_control.add_child(operation_badge)
    operation_badge_label = _label(operation_badge, "", 14, Color("f0d19b"))
    operation_badge_label.position = Vector2(12, 7)
    operation_badge_label.size = Vector2(456, 28)
    operation_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    operation_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    operation_badge_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    help_label = _label(root_control, "WASD MOVE · HOLD E TO SALVAGE · E AT FORGE · ESC CLOSE · F5 SAVE · F9 LOAD", 13, Color("788682"))
    help_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    help_label.offset_top = -22
    help_label.offset_bottom = -4
    help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    forge_panel = _build_forge_panel()


func _build_forge_panel() -> PanelContainer:
    forge_backdrop = ColorRect.new()
    forge_backdrop.name = "ForgeModalBackdrop"
    forge_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    forge_backdrop.color = Color(0.005, 0.012, 0.016, 0.72)
    forge_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    forge_backdrop.visible = false
    root_control.add_child(forge_backdrop)

    var panel := PanelContainer.new()
    panel.name = "ForgeMenu"
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.clip_contents = true
    panel.visible = false
    root_control.add_child(panel)

    # A plain Control intentionally isolates the panel's minimum size from the
    # tall scroll content. Without this shell, ScrollContainer propagates the
    # forge list's minimum size and Godot expands the modal off-screen.
    var shell := Control.new()
    shell.name = "ForgeViewportShell"
    shell.custom_minimum_size = Vector2.ZERO
    shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(shell)

    forge_scroll = ScrollContainer.new()
    forge_scroll.name = "ForgeScroll"
    forge_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    forge_scroll.offset_left = 10.0
    forge_scroll.offset_top = 10.0
    forge_scroll.offset_right = -10.0
    # Reserve a fixed footer so the close action and the last visible row never
    # compete for the same pixels on short release windows.
    forge_scroll.offset_bottom = -70.0
    forge_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    shell.add_child(forge_scroll)

    forge_content_box = VBoxContainer.new()
    forge_content_box.name = "ForgeContent"
    forge_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    forge_content_box.add_theme_constant_override("separation", 10)
    forge_scroll.add_child(forge_content_box)

    forge_title = Label.new()
    forge_title.text = "HEARTFORGE · MANUAL FABRICATION"
    forge_title.add_theme_font_size_override("font_size", 25)
    forge_title.add_theme_color_override("font_color", Color("e8ddd0"))
    forge_content_box.add_child(forge_title)

    forge_copy = Label.new()
    forge_copy.text = "The Mechromancer must build every early machine personally. Fabrication takes time, emits noise, and disables the pistol. Automation is a later evolution."
    forge_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    forge_copy.custom_minimum_size = Vector2(0, 64)
    forge_copy.add_theme_font_size_override("font_size", 15)
    forge_copy.add_theme_color_override("font_color", Color("aeb8b5"))
    forge_content_box.add_child(forge_copy)

    forge_reserve_label = Label.new()
    forge_reserve_label.name = "ForgeReserveStatus"
    forge_reserve_label.custom_minimum_size = Vector2(0, 28)
    forge_reserve_label.add_theme_font_size_override("font_size", 14)
    forge_reserve_label.add_theme_color_override("font_color", Color("f0b36d"))
    forge_reserve_label.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.035, 0.9))
    forge_reserve_label.add_theme_constant_override("outline_size", 3)
    forge_content_box.add_child(forge_reserve_label)

    _forge_button(forge_content_box, "1  BUILD SCRAPPER · 42 Scrap · 6.5 s", func() -> void: forge_build_selected.emit(&"salvager"), "forge.build.scrapper")
    _forge_button(forge_content_box, "2  BUILD WARDEN · 68 Scrap · 8.0 s", func() -> void: forge_build_selected.emit(&"guardian"), "forge.build.warden")
    _forge_button(forge_content_box, "3  BUILD PATHFINDER · 58 Scrap · 7.2 s", func() -> void: forge_build_selected.emit(&"scout"), "forge.build.pathfinder")
    forge_content_box.add_child(HSeparator.new())
    _forge_button(forge_content_box, "4  UPGRADE ALL SCRAPPERS", func() -> void: forge_upgrade_selected.emit(&"salvager"), "forge.upgrade.scrapper")
    _forge_button(forge_content_box, "5  UPGRADE ALL WARDENS", func() -> void: forge_upgrade_selected.emit(&"guardian"), "forge.upgrade.warden")
    _forge_button(forge_content_box, "6  UPGRADE ALL PATHFINDERS", func() -> void: forge_upgrade_selected.emit(&"scout"), "forge.upgrade.pathfinder")

    var footer := HBoxContainer.new()
    footer.name = "ForgeFooter"
    footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    footer.offset_left = 10.0
    footer.offset_right = -10.0
    footer.offset_top = -60.0
    footer.offset_bottom = -10.0
    footer.mouse_filter = Control.MOUSE_FILTER_STOP
    shell.add_child(footer)

    forge_close_button = Button.new()
    forge_close_button.name = "ForgeCloseButton"
    forge_close_button.text = "ESC  CLOSE FORGE"
    forge_close_button.custom_minimum_size = Vector2(0, 48)
    forge_close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    forge_close_button.focus_mode = Control.FOCUS_NONE
    forge_close_button.pressed.connect(func() -> void: forge_closed.emit())
    footer.add_child(forge_close_button)
    return panel


func _forge_button(parent: VBoxContainer, text_value: String, callback: Callable, localization_key: String = "") -> Button:
    var button := Button.new()
    button.text = text_value
    button.set_meta("localization_key", localization_key)
    button.set_meta("localization_fallback", text_value)
    button.custom_minimum_size = Vector2(0, 48)
    button.add_theme_font_size_override("font_size", 16)
    button.focus_mode = Control.FOCUS_NONE
    button.pressed.connect(callback)
    parent.add_child(button)
    forge_buttons.append(button)
    return button


func apply_safe_layout(viewport_size: Vector2) -> void:
    if forge_panel == null:
        return
    var safe_width := minf(720.0, maxf(300.0, viewport_size.x - 40.0))
    var safe_height := minf(700.0, maxf(320.0, viewport_size.y - 40.0))
    forge_panel.set_anchors_preset(Control.PRESET_CENTER)
    forge_panel.offset_left = -safe_width * 0.5
    forge_panel.offset_right = safe_width * 0.5
    forge_panel.offset_top = -safe_height * 0.5
    forge_panel.offset_bottom = safe_height * 0.5

    if prompt_panel != null:
        var prompt_width := minf(680.0, maxf(300.0, viewport_size.x - 40.0))
        prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
        prompt_panel.offset_left = -prompt_width * 0.5
        prompt_panel.offset_right = prompt_width * 0.5
        prompt_panel.offset_top = -108.0
        prompt_panel.offset_bottom = -40.0
        prompt_label.size.x = prompt_width - 40.0

    if map_banner != null:
        # Keep the deliberate command-map affordance inside the safe viewport
        # at the small release capture size as well as in a wide window.
        map_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
        map_banner.offset_left = 18.0
        map_banner.offset_right = -18.0
        map_banner.offset_top = 16.0
        map_banner.offset_bottom = 52.0

    if operation_badge != null:
        var badge_width := minf(520.0, maxf(320.0, viewport_size.x - 40.0))
        operation_badge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
        operation_badge.offset_left = -badge_width * 0.5
        operation_badge.offset_right = badge_width * 0.5
        operation_badge.offset_top = -130.0
        operation_badge.offset_bottom = -88.0
        operation_badge_label.size.x = badge_width - 24.0

    if viewport_size.x < 980.0:
        objective_panel.size.x = 370.0
        objective_label.size.x = 330.0
        resource_panel.size = Vector2(330.0, 224.0)
        resource_panel.position.x = -352.0
        resource_label.size.x = 294.0
        focus_label.size.x = 294.0
        operation_label.size.x = 294.0
        notification_panel.size.x = 370.0
        notification_panel.size.y = 206.0
        notification_panel.position.x = -392.0
        notification_label.size.x = 334.0
        notification_label.size.y = 158.0
    else:
        objective_panel.size.x = 440.0
        objective_label.size.x = 400.0
        resource_panel.size = Vector2(384.0, 224.0)
        resource_panel.position.x = -406.0
        resource_label.size.x = 344.0
        focus_label.size.x = 344.0
        operation_label.size.x = 344.0
        notification_panel.size.x = 424.0
        notification_panel.size.y = 206.0
        notification_panel.position.x = -446.0
        notification_label.size.x = 388.0
        notification_label.size.y = 158.0
    if ending_panel != null and is_instance_valid(ending_panel):
        _layout_ending_panel(viewport_size)


func _on_viewport_resized() -> void:
    apply_safe_layout(Vector2(get_viewport().get_visible_rect().size))


func _panel(position_value: Vector2, size_value: Vector2, anchor_right: bool = false, anchor_bottom: bool = false) -> PanelContainer:
    var panel := PanelContainer.new()
    if anchor_right and anchor_bottom:
        panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    elif anchor_right:
        panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    elif anchor_bottom:
        panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
    else:
        panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    panel.position = position_value
    panel.size = size_value
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root_control.add_child(panel)

    # PanelContainer is a layout container; adding several positioned labels
    # directly to it makes Godot stretch every child over the same rectangle.
    # One free-layout content node preserves the intended measured positions.
    var content := Control.new()
    content.name = "PanelContent"
    content.custom_minimum_size = Vector2.ZERO
    content.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(content)
    return panel


func _content_parent(parent: Control) -> Control:
    var content := parent.get_node_or_null("PanelContent") as Control
    if content != null:
        return content
    return parent


func _label(parent: Control, text_value: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _content_parent(parent).add_child(label)
    return label


func _ending_surface() -> Panel:
    var panel := Panel.new()
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.clip_contents = true
    root_control.add_child(panel)
    var content := Control.new()
    content.name = "PanelContent"
    content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    content.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(content)
    return panel


func _progress(parent: Control, position_value: Vector2, size_value: Vector2, color: Color) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.position = position_value
    bar.size = size_value
    bar.min_value = 0.0
    bar.max_value = 100.0
    bar.value = 100.0
    bar.show_percentage = false
    var fill := StyleBoxFlat.new()
    fill.bg_color = color
    fill.corner_radius_top_left = 3
    fill.corner_radius_top_right = 3
    fill.corner_radius_bottom_left = 3
    fill.corner_radius_bottom_right = 3
    var background := StyleBoxFlat.new()
    background.bg_color = Color(0.04, 0.06, 0.07, 0.92)
    bar.add_theme_stylebox_override("fill", fill)
    bar.add_theme_stylebox_override("background", background)
    _content_parent(parent).add_child(bar)
    return bar


func set_objective(title: String, detail: String) -> void:
    objective_label.text = "%s\n%s" % [title, detail]


func set_prompt(text_value: String) -> void:
    if transient_feedback_locked:
        return
    prompt_label.text = text_value
    prompt_panel.visible = not text_value.strip_edges().is_empty()


func set_resources(scrap: int, rare_cores: int) -> void:
    displayed_scrap = scrap
    displayed_rare_cores = rare_cores
    _refresh_resource_text()


func set_focus(focus: StringName) -> void:
    displayed_focus = focus
    focus_label.text = _text("hud.focus", "FOCUS · {0}", [String(focus).to_upper()])


func set_operation(text_value: String) -> void:
    operation_label.text = text_value


func set_operation_badge(text_value: String, active: bool, prefix: String = "ACTIVE OPERATION") -> void:
    if operation_badge == null or operation_badge_label == null:
        return
    operation_badge.visible = active and not text_value.strip_edges().is_empty()
    if not operation_badge.visible:
        operation_badge_label.text = ""
        return
    operation_badge_label.text = _text("hud.active_operation", "{0} · {1} · F FOLLOW", [prefix, text_value.to_upper()])


func set_player_health(current: float, maximum: float) -> void:
    player_bar.value = 100.0 * current / maxf(1.0, maximum)


func set_companion_health(current: float, maximum: float) -> void:
    companion_bar.value = 100.0 * current / maxf(1.0, maximum)


func show_channel(kind: StringName, progress: float, description: String) -> void:
    var panel := root_control.get_node("ChannelPanel") as PanelContainer
    panel.visible = true
    forge_label.text = _text("hud.channel", "{0} · PISTOL OFFLINE", [description])
    forge_bar.value = clampf(progress, 0.0, 1.0) * 100.0


func hide_channel() -> void:
    var panel := root_control.get_node("ChannelPanel") as PanelContainer
    panel.visible = false


func show_forge_menu() -> void:
    refresh_localized_text()
    forge_open = true
    forge_backdrop.visible = true
    forge_panel.visible = true
    forge_scroll.scroll_vertical = 0
    apply_safe_layout(Vector2(get_viewport().get_visible_rect().size))


func hide_forge_menu() -> void:
    forge_open = false
    forge_backdrop.visible = false
    forge_panel.visible = false


func show_map_banner(visible_value: bool) -> void:
    map_banner.visible = visible_value


func push_notification(message: String) -> void:
    if transient_feedback_locked:
        return
    var cleaned := message.strip_edges()
    if cleaned.is_empty():
        return
    if not notifications.is_empty() and notifications[0] == cleaned:
        notification_ages[0] = 0.0
        _refresh_notifications()
        return
    notifications.push_front(cleaned)
    notification_ages.push_front(0.0)
    if notifications.size() > MAX_VISIBLE_NOTIFICATIONS:
        notifications.resize(MAX_VISIBLE_NOTIFICATIONS)
        notification_ages.resize(MAX_VISIBLE_NOTIFICATIONS)
    _refresh_notifications()


func clear_transient_feedback() -> void:
    notifications.clear()
    notification_ages.clear()
    _refresh_notifications()
    set_prompt("")
    hide_channel()
    show_map_banner(false)


func _refresh_notifications() -> void:
    notification_panel.visible = not notifications.is_empty()
    if notifications.is_empty():
        notification_label.text = ""
        return
    var formatted: Array[String] = []
    for message in notifications:
        formatted.append("• %s" % message)
    notification_label.text = "\n\n".join(formatted)


func refresh_localized_text() -> void:
    if objective_heading == null:
        return
    objective_heading.text = _text("hud.current_objective", "CURRENT OBJECTIVE")
    reserve_heading.text = _text("hud.material_reserves", "MATERIAL RESERVES")
    notification_heading.text = _text("hud.machine_reports", "MACHINE REPORTS")
    player_status_label.text = _text("hud.mechromancer_status", "MECHROMANCER · WEAK PISTOL")
    companion_status_label.text = _text("hud.bulwark_status", "BULWARK · PRIMARY PROTECTION")
    focus_help_label.text = _text("hud.command_help", "1 DEFEND    2 SALVAGE    3 EXPEDITION    T EVOLVE    O OUTPOSTS    M MAP    F FOLLOW    G NEXT GROUP")
    _refresh_resource_text()
    forge_title.text = _text("forge.title", "HEARTFORGE · MANUAL FABRICATION")
    forge_copy.text = _text("forge.description", "The Mechromancer must build every early machine personally. Fabrication takes time, emits noise, and disables the pistol. Automation is a later evolution.")
    _refresh_forge_reserve_text()
    forge_close_button.text = _text("forge.close", "ESC  CLOSE FORGE")
    for button in forge_buttons:
        if button == null or not is_instance_valid(button):
            continue
        var key := str(button.get_meta("localization_key", ""))
        if key.is_empty():
            continue
        button.text = _text(key, str(button.get_meta("localization_fallback", button.text)))


func _refresh_resource_text() -> void:
    if resource_label == null:
        return
    resource_label.text = _text("hud.scrap_cores", "SCRAP  {0}\nCOGNITION CORES  {1}", [displayed_scrap, displayed_rare_cores])
    _refresh_forge_reserve_text()


func _refresh_forge_reserve_text() -> void:
    if forge_reserve_label == null:
        return
    forge_reserve_label.text = _text("forge.reserves", "CURRENT RESERVES · {0} Scrap · {1} Cognition Cores", [displayed_scrap, displayed_rare_cores])


func _text(key: String, fallback: String, replacements: Array = []) -> String:
    var service := get_tree().get_first_node_in_group(&"localization_service") as LocalizationService3D
    if service != null:
        return service.text(key, replacements)
    var result := fallback
    for index in range(replacements.size()):
        result = result.replace("{%d}" % index, str(replacements[index]))
    return result


func show_ending(victory: bool, detail: String, allow_continuation: bool = false) -> void:
    dismiss_ending()
    clear_transient_feedback()
    transient_feedback_locked = true
    ending_panel = _ending_surface()
    ending_panel.name = "EndingPanel"
    ending_panel.set_anchors_preset(Control.PRESET_CENTER)
    ending_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var title_key := "hud.ending.first_light_secured" if victory else "hud.ending.heartforge_fell"
    var title_fallback := "FIRST LIGHT SECURED" if victory else "THE HEARTFORGE FELL"
    var prompt_key := "hud.ending.continue" if allow_continuation else "hud.ending.restart"
    var prompt_fallback := "Press ENTER to continue exploring." if allow_continuation else "Press ENTER to restart."
    var prompt := _text(prompt_key, prompt_fallback)
    # Keep the short post-ending paragraph intact at the target 1280px review
    # width. A 76-character split can leave the opening word of that paragraph
    # stranded on its own line in the longer Containment narrative.
    var readable_detail := _wrap_ending_detail(detail, 70)
    var ending_style := StyleBoxFlat.new()
    ending_style.bg_color = Color(0.012, 0.028, 0.034, 0.95) if victory else Color(0.04, 0.022, 0.025, 0.96)
    ending_style.border_color = Color(0.40, 0.85, 0.84, 0.78) if victory else Color(0.82, 0.34, 0.28, 0.78)
    ending_style.set_border_width_all(1)
    ending_style.set_corner_radius_all(14)
    ending_style.shadow_color = Color(0.0, 0.0, 0.0, 0.78)
    ending_style.shadow_size = 24
    ending_style.content_margin_left = 18.0
    ending_style.content_margin_right = 18.0
    ending_style.content_margin_top = 16.0
    ending_style.content_margin_bottom = 16.0
    ending_panel.add_theme_stylebox_override("panel", ending_style)
    var label := _label(ending_panel, _text(title_key, title_fallback) + "\n\n" + readable_detail + "\n\n" + prompt, 19, Color("79d8dc") if victory else Color("e06b5f"))
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.add_theme_constant_override("outline_size", 4)
    label.add_theme_color_override("font_outline_color", Color(0.005, 0.012, 0.015, 0.95))
    label.add_theme_constant_override("line_spacing", 4)
    _layout_ending_panel(Vector2(get_viewport().get_visible_rect().size))


func show_failure_report(detail: String) -> void:
    dismiss_ending()
    ending_panel = _ending_surface()
    ending_panel.name = "EndingPanel"
    ending_panel.set_anchors_preset(Control.PRESET_CENTER)
    ending_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    ending_panel.set_meta("expanded_report", true)
    var report_style := StyleBoxFlat.new()
    report_style.bg_color = Color(0.018, 0.032, 0.04, 0.98)
    report_style.border_color = Color(0.74, 0.38, 0.28, 0.72)
    report_style.set_border_width_all(1)
    report_style.set_corner_radius_all(12)
    report_style.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
    report_style.shadow_size = 18
    report_style.content_margin_left = 22.0
    report_style.content_margin_right = 22.0
    report_style.content_margin_top = 18.0
    report_style.content_margin_bottom = 18.0
    ending_panel.add_theme_stylebox_override("panel", report_style)
    var readable_detail := _wrap_multiline_detail(detail, 76)
    var label := _label(ending_panel, "%s\n\n%s\n\n%s\n\n%s" % [
        _text("hud.ending.heartforge_fell", "THE HEARTFORGE FELL"),
        _text("hud.ending.post_collapse_report", "POST-COLLAPSE REPORT"),
        readable_detail,
        _text("hud.ending.restart", "Press ENTER to restart."),
    ], 15, Color("e8b0a5"))
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
    label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _layout_ending_panel(Vector2(get_viewport().get_visible_rect().size))


func _layout_ending_panel(viewport_size: Vector2) -> void:
    if ending_panel == null or not is_instance_valid(ending_panel):
        return
    var panel_width := minf(820.0, maxf(420.0, viewport_size.x - 40.0))
    var expanded_report := bool(ending_panel.get_meta("expanded_report", false))
    # Victory now includes a compact strategic-legacy epilogue. Give the
    # ordinary ending surface enough vertical room for that evidence while
    # retaining the expanded report's separate reading budget.
    var panel_height := minf(620.0 if expanded_report else 500.0, maxf(260.0, viewport_size.y - 40.0))
    ending_panel.set_anchors_preset(Control.PRESET_CENTER)
    ending_panel.offset_left = -panel_width * 0.5
    ending_panel.offset_right = panel_width * 0.5
    ending_panel.offset_top = -panel_height * 0.5
    ending_panel.offset_bottom = panel_height * 0.5
    var content := ending_panel.get_node_or_null("PanelContent") as Control
    if content == null or content.get_child_count() == 0:
        return
    var label := content.get_child(0) as Label
    if label != null:
        label.position = Vector2(24.0, 20.0)
        label.size = Vector2(panel_width - 48.0, panel_height - 40.0)


func _wrap_ending_detail(detail: String, max_chars: int) -> String:
    var lines: Array[String] = []
    var current := ""
    for word in detail.split(" ", false):
        if current.is_empty():
            current = word
        elif current.length() + word.length() + 1 <= max_chars:
            current += " " + word
        else:
            lines.append(current)
            current = word
    if not current.is_empty():
        lines.append(current)
    return "\n".join(lines)


func _wrap_multiline_detail(detail: String, max_chars: int) -> String:
    var paragraphs: Array[String] = []
    for line in detail.split("\n", true):
        paragraphs.append(_wrap_ending_detail(str(line), max_chars))
    return "\n".join(paragraphs)


func dismiss_ending() -> void:
    transient_feedback_locked = false
    if is_instance_valid(ending_panel):
        # Keep the surface mounted and hide it. Destroying a CanvasItem during
        # the first-victory handoff can invalidate the renderer's next 3D
        # frame on the exported release path, leaving the sanctuary as an
        # empty clear field. Reusing the bounded surface preserves the world
        # while retaining the same visible UI contract.
        ending_panel.visible = false
