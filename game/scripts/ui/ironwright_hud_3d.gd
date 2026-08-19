class_name IronwrightHUD3D
extends CanvasLayer

signal forge_build_selected(archetype: StringName)
signal forge_upgrade_selected(archetype: StringName)
signal forge_closed
signal expedition_authorized

const NOTIFICATION_LIFETIME_SECONDS: float = 6.5
const MAX_VISIBLE_NOTIFICATIONS: int = 3

var root_control: Control
var objective_panel: PanelContainer
var prompt_panel: PanelContainer
var resource_panel: PanelContainer
var notification_panel: PanelContainer
var objective_label: Label
var prompt_label: Label
var resource_label: Label
var focus_label: Label
var operation_label: Label
var player_bar: ProgressBar
var companion_bar: ProgressBar
var forge_bar: ProgressBar
var forge_label: Label
var forge_backdrop: ColorRect
var forge_panel: PanelContainer
var forge_scroll: ScrollContainer
var forge_content_box: VBoxContainer
var notification_label: Label
var map_banner: Label
var help_label: Label
var forge_open: bool = false
var notifications: Array[String] = []
var notification_ages: Array[float] = []


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
    var objective_heading := _label(objective_panel, "CURRENT OBJECTIVE", 12, Color("87a4a5"))
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
    var reserve_heading := _label(resource_panel, "MATERIAL RESERVES", 12, Color("87a4a5"))
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

    notification_panel = _panel(Vector2(-446, 266), Vector2(424, 170), true)
    notification_panel.name = "NotificationToastPanel"
    notification_panel.visible = false
    var notification_heading := _label(notification_panel, "MACHINE REPORTS", 12, Color("87a4a5"))
    notification_heading.position = Vector2(18, 10)
    notification_heading.size = Vector2(388, 20)
    notification_label = _label(notification_panel, "", 15, Color("dce5e2"))
    notification_label.position = Vector2(18, 34)
    notification_label.size = Vector2(388, 122)
    notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    notification_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

    var health_panel := _panel(Vector2(22, -142), Vector2(370, 118), false, true)
    health_panel.name = "HealthPanel"
    var player_text := _label(health_panel, "MECHROMANCER · WEAK PISTOL", 14, Color("d9e1de"))
    player_text.position = Vector2(16, 10)
    player_text.size = Vector2(338, 22)
    player_bar = _progress(health_panel, Vector2(16, 34), Vector2(338, 18), Color("79d8dc"))
    var companion_text := _label(health_panel, "BULWARK · PRIMARY PROTECTION", 14, Color("d9e1de"))
    companion_text.position = Vector2(16, 61)
    companion_text.size = Vector2(338, 22)
    companion_bar = _progress(health_panel, Vector2(16, 87), Vector2(338, 16), Color("d6a665"))

    var focus_panel := _panel(Vector2(-520, -102), Vector2(498, 78), true, true)
    focus_panel.name = "CommandHelpPanel"
    var focus_help := _label(focus_panel, "1 DEFEND    2 SALVAGE    3 EXPEDITION    T EVOLVE    O OUTPOSTS    M MAP    F FOLLOW", 14, Color("b8c5c2"))
    focus_help.position = Vector2(16, 13)
    focus_help.size = Vector2(466, 50)
    focus_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    focus_help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    var channel_panel := _panel(Vector2(-250, -188), Vector2(500, 72), true, true)
    channel_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    channel_panel.position = Vector2(-250, -188)
    channel_panel.name = "ChannelPanel"
    channel_panel.visible = false
    forge_label = _label(channel_panel, "", 15, Color("f0dfc6"))
    forge_label.position = Vector2(16, 8)
    forge_label.size = Vector2(468, 24)
    forge_bar = _progress(channel_panel, Vector2(16, 38), Vector2(468, 18), Color("d4a267"))

    map_banner = _label(root_control, "COMMAND MAP · LIVE PHYSICAL POSITIONS · F TO FOLLOW ACTIVE GROUP", 17, Color("79d8dc"))
    map_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    map_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
    map_banner.offset_top = 20
    map_banner.offset_bottom = 52
    map_banner.visible = false

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
    forge_scroll.offset_bottom = -10.0
    forge_scroll.mouse_filter = Control.MOUSE_FILTER_STOP
    shell.add_child(forge_scroll)

    forge_content_box = VBoxContainer.new()
    forge_content_box.name = "ForgeContent"
    forge_content_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    forge_content_box.add_theme_constant_override("separation", 10)
    forge_scroll.add_child(forge_content_box)

    var title := Label.new()
    title.text = "HEARTFORGE · MANUAL FABRICATION"
    title.add_theme_font_size_override("font_size", 25)
    title.add_theme_color_override("font_color", Color("e8ddd0"))
    forge_content_box.add_child(title)

    var copy := Label.new()
    copy.text = "The Mechromancer must build every early machine personally. Fabrication takes time, emits noise, and disables the pistol. Automation is a later evolution."
    copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    copy.custom_minimum_size = Vector2(0, 64)
    copy.add_theme_font_size_override("font_size", 15)
    copy.add_theme_color_override("font_color", Color("aeb8b5"))
    forge_content_box.add_child(copy)

    _forge_button(forge_content_box, "1  BUILD SCRAPPER · 42 Scrap · 6.5 s", func() -> void: forge_build_selected.emit(&"salvager"))
    _forge_button(forge_content_box, "2  BUILD WARDEN · 68 Scrap · 8.0 s", func() -> void: forge_build_selected.emit(&"guardian"))
    _forge_button(forge_content_box, "3  BUILD PATHFINDER · 58 Scrap · 7.2 s", func() -> void: forge_build_selected.emit(&"scout"))
    forge_content_box.add_child(HSeparator.new())
    _forge_button(forge_content_box, "4  UPGRADE ALL SCRAPPERS", func() -> void: forge_upgrade_selected.emit(&"salvager"))
    _forge_button(forge_content_box, "5  UPGRADE ALL WARDENS", func() -> void: forge_upgrade_selected.emit(&"guardian"))
    _forge_button(forge_content_box, "6  UPGRADE ALL PATHFINDERS", func() -> void: forge_upgrade_selected.emit(&"scout"))
    _forge_button(forge_content_box, "ESC  CLOSE", func() -> void: forge_closed.emit())
    return panel


func _forge_button(parent: VBoxContainer, text_value: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(0, 48)
    button.add_theme_font_size_override("font_size", 16)
    button.focus_mode = Control.FOCUS_NONE
    button.pressed.connect(callback)
    parent.add_child(button)
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

    if viewport_size.x < 980.0:
        objective_panel.size.x = 370.0
        objective_label.size.x = 330.0
        resource_panel.size = Vector2(330.0, 224.0)
        resource_panel.position.x = -352.0
        resource_label.size.x = 294.0
        focus_label.size.x = 294.0
        operation_label.size.x = 294.0
        notification_panel.size.x = 370.0
        notification_panel.position.x = -392.0
        notification_label.size.x = 334.0
    else:
        objective_panel.size.x = 440.0
        objective_label.size.x = 400.0
        resource_panel.size = Vector2(384.0, 224.0)
        resource_panel.position.x = -406.0
        resource_label.size.x = 344.0
        focus_label.size.x = 344.0
        operation_label.size.x = 344.0
        notification_panel.size.x = 424.0
        notification_panel.position.x = -446.0
        notification_label.size.x = 388.0


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
    if parent is PanelContainer:
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
    prompt_label.text = text_value
    prompt_panel.visible = not text_value.strip_edges().is_empty()


func set_resources(scrap: int, rare_cores: int) -> void:
    resource_label.text = "SCRAP  %d\nCOGNITION CORES  %d" % [scrap, rare_cores]


func set_focus(focus: StringName) -> void:
    focus_label.text = "FOCUS · %s" % String(focus).to_upper()


func set_operation(text_value: String) -> void:
    operation_label.text = text_value


func set_player_health(current: float, maximum: float) -> void:
    player_bar.value = 100.0 * current / maxf(1.0, maximum)


func set_companion_health(current: float, maximum: float) -> void:
    companion_bar.value = 100.0 * current / maxf(1.0, maximum)


func show_channel(kind: StringName, progress: float, description: String) -> void:
    var panel := root_control.get_node("ChannelPanel") as PanelContainer
    panel.visible = true
    forge_label.text = "%s · pistol offline" % description
    forge_bar.value = clampf(progress, 0.0, 1.0) * 100.0


func hide_channel() -> void:
    var panel := root_control.get_node("ChannelPanel") as PanelContainer
    panel.visible = false


func show_forge_menu() -> void:
    forge_open = true
    forge_backdrop.visible = true
    forge_panel.visible = true
    apply_safe_layout(Vector2(get_viewport().get_visible_rect().size))


func hide_forge_menu() -> void:
    forge_open = false
    forge_backdrop.visible = false
    forge_panel.visible = false


func show_map_banner(visible_value: bool) -> void:
    map_banner.visible = visible_value


func push_notification(message: String) -> void:
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


func _refresh_notifications() -> void:
    notification_panel.visible = not notifications.is_empty()
    if notifications.is_empty():
        notification_label.text = ""
        return
    var formatted: Array[String] = []
    for message in notifications:
        formatted.append("• %s" % message.replace("\n", "  "))
    notification_label.text = "\n\n".join(formatted)


func show_ending(victory: bool, detail: String) -> void:
    var panel := _panel(Vector2(-330, -155), Vector2(660, 310), true, true)
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.position = Vector2(-330, -155)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var label := _label(panel, ("FIRST LIGHT SECURED" if victory else "THE HEARTFORGE FELL") + "\n\n" + detail + "\n\nPress ENTER to restart.", 24, Color("79d8dc") if victory else Color("e06b5f"))
    label.position = Vector2(28, 28)
    label.size = Vector2(604, 254)
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
