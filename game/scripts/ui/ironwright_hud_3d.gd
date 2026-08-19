class_name IronwrightHUD3D
extends CanvasLayer

signal forge_build_selected(archetype: StringName)
signal forge_upgrade_selected(archetype: StringName)
signal forge_closed
signal expedition_authorized

var root_control: Control
var objective_label: Label
var prompt_label: Label
var resource_label: Label
var focus_label: Label
var operation_label: Label
var player_bar: ProgressBar
var companion_bar: ProgressBar
var forge_bar: ProgressBar
var forge_label: Label
var forge_panel: PanelContainer
var notification_label: Label
var map_banner: Label
var help_label: Label
var forge_open: bool = false
var notifications: Array[String] = []


func _ready() -> void:
    layer = 20
    _build_ui()


func _build_ui() -> void:
    root_control = Control.new()
    root_control.name = "HUDRoot"
    root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root_control)

    var left_panel := _panel(Vector2(24, 24), Vector2(390, 176))
    objective_label = _label(left_panel, "FIRST LIGHT\nSurvive beside the Heartforge.", 20, Color("e5ece9"))
    objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    objective_label.position = Vector2(18, 16)
    objective_label.size = Vector2(350, 92)
    prompt_label = _label(left_panel, "", 16, Color("d4a267"))
    prompt_label.position = Vector2(18, 112)
    prompt_label.size = Vector2(350, 48)
    prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    var right_panel := _panel(Vector2(-330, 24), Vector2(306, 150), true)
    resource_label = _label(right_panel, "SCRAP 24\nRARE CORES 0", 18, Color("d9e1de"))
    resource_label.position = Vector2(18, 14)
    resource_label.size = Vector2(270, 60)
    focus_label = _label(right_panel, "FOCUS · DEFEND", 16, Color("78d3d7"))
    focus_label.position = Vector2(18, 78)
    focus_label.size = Vector2(270, 28)
    operation_label = _label(right_panel, "No remote operation", 14, Color("9aa9a6"))
    operation_label.position = Vector2(18, 108)
    operation_label.size = Vector2(270, 28)

    var health_panel := _panel(Vector2(24, -138), Vector2(360, 114), false, true)
    var player_text := _label(health_panel, "MECHROMANCER · WEAK PISTOL", 14, Color("d9e1de"))
    player_text.position = Vector2(16, 10)
    player_text.size = Vector2(320, 22)
    player_bar = _progress(health_panel, Vector2(16, 34), Vector2(328, 18), Color("79d8dc"))
    var companion_text := _label(health_panel, "COMPANION · PRIMARY PROTECTION", 14, Color("d9e1de"))
    companion_text.position = Vector2(16, 60)
    companion_text.size = Vector2(320, 22)
    companion_bar = _progress(health_panel, Vector2(16, 84), Vector2(328, 16), Color("d6a665"))

    var focus_panel := _panel(Vector2(-500, -96), Vector2(476, 72), true, true)
    var focus_help := _label(focus_panel, "1 DEFEND     2 SALVAGE     3 EXPEDITION     X AUTHORIZE     M MAP     F FOLLOW", 14, Color("b8c5c2"))
    focus_help.position = Vector2(16, 15)
    focus_help.size = Vector2(444, 42)
    focus_help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    var channel_panel := _panel(Vector2(-250, -178), Vector2(500, 72), true, true)
    channel_panel.name = "ChannelPanel"
    channel_panel.visible = false
    forge_label = _label(channel_panel, "", 15, Color("f0dfc6"))
    forge_label.position = Vector2(16, 8)
    forge_label.size = Vector2(468, 24)
    forge_bar = _progress(channel_panel, Vector2(16, 38), Vector2(468, 18), Color("d4a267"))

    notification_label = _label(root_control, "", 15, Color("dce5e2"))
    notification_label.position = Vector2(24, 212)
    notification_label.size = Vector2(440, 180)
    notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

    map_banner = _label(root_control, "COMMAND MAP · LIVE PHYSICAL POSITIONS · F TO FOLLOW ACTIVE GROUP", 17, Color("79d8dc"))
    map_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    map_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
    map_banner.offset_top = 20
    map_banner.offset_bottom = 52
    map_banner.visible = false

    help_label = _label(root_control, "WASD MOVE · E HOLD TO SALVAGE · E AT FORGE TO OPEN · ESC CANCEL/CLOSE · F5 SAVE · F9 LOAD", 13, Color("788682"))
    help_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
    help_label.offset_top = -22
    help_label.offset_bottom = -4
    help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

    forge_panel = _build_forge_panel()


func _build_forge_panel() -> PanelContainer:
    var panel := PanelContainer.new()
    panel.name = "ForgeMenu"
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.position = Vector2(-310, -260)
    panel.size = Vector2(620, 520)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.visible = false
    root_control.add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 10)
    panel.add_child(box)
    var title := Label.new()
    title.text = "HEARTFORGE · MANUAL FABRICATION"
    title.add_theme_font_size_override("font_size", 25)
    title.add_theme_color_override("font_color", Color("e8ddd0"))
    box.add_child(title)
    var copy := Label.new()
    copy.text = "The Mechromancer must build every early machine personally. Fabrication takes time, emits noise, and disables the pistol. Automation is a later evolution."
    copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    copy.add_theme_font_size_override("font_size", 15)
    copy.add_theme_color_override("font_color", Color("aeb8b5"))
    box.add_child(copy)

    _forge_button(box, "1  BUILD SCRAPPER · 42 Scrap · 6.5 s", func() -> void: forge_build_selected.emit(&"salvager"))
    _forge_button(box, "2  BUILD WARDEN · 68 Scrap · 8.0 s", func() -> void: forge_build_selected.emit(&"guardian"))
    _forge_button(box, "3  BUILD PATHFINDER · 58 Scrap · 7.2 s", func() -> void: forge_build_selected.emit(&"scout"))
    var divider := HSeparator.new()
    box.add_child(divider)
    _forge_button(box, "4  UPGRADE ALL SCRAPPERS", func() -> void: forge_upgrade_selected.emit(&"salvager"))
    _forge_button(box, "5  UPGRADE ALL WARDENS", func() -> void: forge_upgrade_selected.emit(&"guardian"))
    _forge_button(box, "6  UPGRADE ALL PATHFINDERS", func() -> void: forge_upgrade_selected.emit(&"scout"))
    _forge_button(box, "ESC  CLOSE", func() -> void: forge_closed.emit())
    return panel


func _forge_button(parent: VBoxContainer, text_value: String, callback: Callable) -> void:
    var button := Button.new()
    button.text = text_value
    button.custom_minimum_size = Vector2(0, 46)
    button.add_theme_font_size_override("font_size", 16)
    button.pressed.connect(callback)
    parent.add_child(button)


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
    return panel


func _label(parent: Control, text_value: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = text_value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(label)
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
    parent.add_child(bar)
    return bar


func set_objective(title: String, detail: String) -> void:
    objective_label.text = "%s\n%s" % [title, detail]


func set_prompt(text_value: String) -> void:
    prompt_label.text = text_value


func set_resources(scrap: int, rare_cores: int) -> void:
    resource_label.text = "SCRAP %d\nRARE CORES %d" % [scrap, rare_cores]


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
    forge_panel.visible = true


func hide_forge_menu() -> void:
    forge_open = false
    forge_panel.visible = false


func show_map_banner(visible_value: bool) -> void:
    map_banner.visible = visible_value


func push_notification(message: String) -> void:
    notifications.push_front(message)
    if notifications.size() > 5:
        notifications.resize(5)
    notification_label.text = "\n".join(notifications)


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
