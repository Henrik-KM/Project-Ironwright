class_name IronwrightBeautifulHUD3D
extends IronwrightHUD3D

## A quieter, warmer HUD skin for the native 3D game. Presentation remains
## separate from simulation while keeping first-session information readable.

var vignette: ColorRect
var impact_overlay: ColorRect
var sanctuary_label: Label
var sanctuary_badge: PanelContainer
var notification_flash: float = 0.0
var prompt_pulse: float = 0.0
var elapsed: float = 0.0
var damage_intensity: float = 0.0
var sanctuary_integrity: float = 1.0
var tactical_hint_elapsed: float = 0.0

const TACTICAL_HINT_SECONDS: float = 12.0
const SANCTUARY_BADGE_SECONDS: float = 8.0


func _ready() -> void:
    super._ready()
    add_to_group(&"beautiful_hud")
    _apply_visual_theme()
    _build_atmospheric_overlays()
    _add_sanctuary_badge()


func _process(delta: float) -> void:
    super._process(delta)
    elapsed += delta
    tactical_hint_elapsed += delta
    notification_flash = move_toward(notification_flash, 0.0, delta * 1.9)
    prompt_pulse = move_toward(prompt_pulse, 0.0, delta * 2.2)
    damage_intensity = move_toward(damage_intensity, 0.0, delta * 1.25)

    if notification_label != null:
        var glow := 0.82 + notification_flash * 0.18
        notification_label.modulate = Color(glow, glow, glow, 1.0)
    if prompt_label != null:
        var pulse := 0.92 + sin(elapsed * 3.0) * 0.04 + prompt_pulse * 0.04
        prompt_label.modulate = Color(pulse, pulse, pulse, 1.0)
    if impact_overlay != null:
        impact_overlay.color.a = damage_intensity * 0.32
    if sanctuary_label != null:
        var status := "COZY LIGHT · MACHINES ACTIVE"
        if sanctuary_integrity < 0.35:
            status = "SANCTUARY CRITICAL · THE WARM LIGHT IS FAILING"
        elif sanctuary_integrity < 0.7:
            status = "SANCTUARY DAMAGED · HOLD THE HEARTFORGE"
        sanctuary_label.text = status
        sanctuary_label.modulate = Color("ff9270") if sanctuary_integrity < 0.35 else Color("ffd9a2")
    _refresh_contextual_chrome()


func _refresh_contextual_chrome() -> void:
    if help_label != null and prompt_panel != null and map_banner != null:
        var onboarding_hint := tactical_hint_elapsed < TACTICAL_HINT_SECONDS
        var direct_interaction := prompt_panel.visible
        var map_open := map_banner.visible
        help_label.visible = onboarding_hint and not direct_interaction and not map_open and not forge_open
        help_label.modulate.a = 1.0 if help_label.visible else 0.0
    if sanctuary_badge != null:
        var critical_status := sanctuary_integrity < 0.7
        var badge_fade := clampf(1.0 - maxf(0.0, tactical_hint_elapsed - SANCTUARY_BADGE_SECONDS) / 1.8, 0.0, 1.0)
        sanctuary_badge.visible = critical_status or badge_fade > 0.0
        sanctuary_badge.modulate.a = 1.0 if critical_status else badge_fade


func _apply_visual_theme() -> void:
    if root_control == null:
        return
    root_control.add_theme_color_override("font_color", Color("e7efed"))
    root_control.add_theme_color_override("font_outline_color", Color(0.02, 0.035, 0.045, 0.92))
    _style_recursive(root_control)

    if objective_label != null:
        objective_label.add_theme_font_size_override("font_size", 19)
        objective_label.add_theme_constant_override("outline_size", 4)
        objective_label.add_theme_color_override("font_color", Color("edf3f0"))
    if prompt_label != null:
        prompt_label.add_theme_font_size_override("font_size", 17)
        prompt_label.add_theme_constant_override("outline_size", 4)
        prompt_label.add_theme_color_override("font_color", Color("ffc77c"))
    if resource_label != null:
        resource_label.add_theme_font_size_override("font_size", 21)
        resource_label.add_theme_constant_override("outline_size", 4)
        resource_label.add_theme_color_override("font_color", Color("f0e7d8"))
    if focus_label != null:
        focus_label.add_theme_color_override("font_color", Color("7adce1"))
    if operation_label != null:
        operation_label.add_theme_color_override("font_color", Color("b3c2c0"))
    if help_label != null:
        help_label.add_theme_color_override("font_color", Color(0.65, 0.72, 0.72, 0.88))
        help_label.add_theme_constant_override("outline_size", 3)
    if notification_label != null:
        notification_label.add_theme_constant_override("outline_size", 4)
        notification_label.add_theme_color_override("font_color", Color("e4edeb"))

    _polish_progress_bar(player_bar, Color("65d5da"))
    _polish_progress_bar(companion_bar, Color("e0aa64"))
    _polish_progress_bar(forge_bar, Color("efad5d"))


func _style_recursive(node: Node) -> void:
    for child in node.get_children():
        if child is PanelContainer:
            (child as PanelContainer).add_theme_stylebox_override("panel", _panel_style())
        elif child is Button:
            _style_button(child as Button)
        elif child is Label:
            var label := child as Label
            label.add_theme_constant_override("outline_size", 3)
            label.add_theme_color_override("font_outline_color", Color(0.015, 0.025, 0.03, 0.94))
        _style_recursive(child)


func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.045, 0.055, 0.82)
    style.border_color = Color(0.34, 0.55, 0.57, 0.32)
    style.border_width_left = 1
    style.border_width_right = 1
    style.border_width_top = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 9
    style.corner_radius_top_right = 9
    style.corner_radius_bottom_left = 9
    style.corner_radius_bottom_right = 9
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
    style.shadow_size = 8
    style.content_margin_left = 8.0
    style.content_margin_right = 8.0
    style.content_margin_top = 6.0
    style.content_margin_bottom = 6.0
    return style


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = border
    style.border_width_left = 1
    style.border_width_right = 1
    style.border_width_top = 1
    style.border_width_bottom = 1
    style.corner_radius_top_left = 6
    style.corner_radius_top_right = 6
    style.corner_radius_bottom_left = 6
    style.corner_radius_bottom_right = 6
    style.content_margin_left = 14.0
    style.content_margin_right = 14.0
    style.content_margin_top = 8.0
    style.content_margin_bottom = 8.0
    return style


func _style_button(button: Button) -> void:
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size", 15)
    button.add_theme_color_override("font_color", Color("dce8e5"))
    button.add_theme_color_override("font_hover_color", Color("fff0d9"))
    button.add_theme_stylebox_override("normal", _button_style(Color(0.04, 0.075, 0.085, 0.92), Color(0.34, 0.58, 0.59, 0.32)))
    button.add_theme_stylebox_override("hover", _button_style(Color(0.12, 0.15, 0.14, 0.96), Color(0.95, 0.64, 0.34, 0.65)))
    button.add_theme_stylebox_override("pressed", _button_style(Color(0.19, 0.13, 0.085, 0.98), Color(1.0, 0.67, 0.35, 0.88)))


func _polish_progress_bar(bar: ProgressBar, fill_color: Color) -> void:
    if bar == null:
        return
    var fill := StyleBoxFlat.new()
    fill.bg_color = fill_color
    fill.corner_radius_top_left = 5
    fill.corner_radius_top_right = 5
    fill.corner_radius_bottom_left = 5
    fill.corner_radius_bottom_right = 5
    fill.shadow_color = Color(fill_color.r, fill_color.g, fill_color.b, 0.3)
    fill.shadow_size = 4
    var background := StyleBoxFlat.new()
    background.bg_color = Color(0.015, 0.025, 0.03, 0.88)
    background.border_color = Color(0.45, 0.58, 0.59, 0.22)
    background.border_width_left = 1
    background.border_width_right = 1
    background.border_width_top = 1
    background.border_width_bottom = 1
    background.corner_radius_top_left = 5
    background.corner_radius_top_right = 5
    background.corner_radius_bottom_left = 5
    background.corner_radius_bottom_right = 5
    bar.add_theme_stylebox_override("fill", fill)
    bar.add_theme_stylebox_override("background", background)


func _build_atmospheric_overlays() -> void:
    vignette = ColorRect.new()
    vignette.name = "AtmosphericVignette"
    vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vignette.z_index = -10
    var shader := Shader.new()
    shader.code = """
shader_type canvas_item;
render_mode unshaded;
void fragment() {
    vec2 centered = UV * 2.0 - 1.0;
    float distance_from_center = dot(centered, centered);
    float edge = smoothstep(0.38, 1.42, distance_from_center);
    vec3 blue_hour = vec3(0.025, 0.052, 0.07);
    COLOR = vec4(blue_hour, edge * 0.48);
}
"""
    var material := ShaderMaterial.new()
    material.shader = shader
    vignette.material = material
    root_control.add_child(vignette)
    root_control.move_child(vignette, 0)

    impact_overlay = ColorRect.new()
    impact_overlay.name = "DamageOverlay"
    impact_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    impact_overlay.color = Color(0.55, 0.035, 0.02, 0.0)
    impact_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    impact_overlay.z_index = 100
    root_control.add_child(impact_overlay)


func _add_sanctuary_badge() -> void:
    sanctuary_badge = PanelContainer.new()
    sanctuary_badge.name = "SanctuaryBadge"
    sanctuary_badge.set_anchors_preset(Control.PRESET_CENTER_TOP)
    sanctuary_badge.position = Vector2(-210, 18)
    sanctuary_badge.size = Vector2(420, 38)
    sanctuary_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
    sanctuary_badge.add_theme_stylebox_override("panel", _button_style(Color(0.08, 0.07, 0.055, 0.78), Color(0.95, 0.62, 0.32, 0.45)))
    root_control.add_child(sanctuary_badge)

    sanctuary_label = Label.new()
    sanctuary_label.text = "COZY LIGHT · MACHINES ACTIVE"
    sanctuary_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    sanctuary_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    sanctuary_label.add_theme_font_size_override("font_size", 13)
    sanctuary_label.add_theme_constant_override("outline_size", 3)
    sanctuary_label.add_theme_color_override("font_color", Color("ffd9a2"))
    sanctuary_badge.add_child(sanctuary_label)


func push_notification(message: String) -> void:
    super.push_notification(message)
    notification_flash = 1.0


func set_prompt(text_value: String) -> void:
    super.set_prompt(text_value)
    prompt_pulse = 1.0
    _refresh_contextual_chrome()


func show_map_banner(visible_value: bool) -> void:
    super.show_map_banner(visible_value)
    _refresh_contextual_chrome()


func show_channel(kind: StringName, progress: float, description: String) -> void:
    super.show_channel(kind, progress, description)
    var color := Color("70dbe0") if kind == &"manual_salvage" else Color("f0ad5e")
    _polish_progress_bar(forge_bar, color)


func flash_damage(severity: float = 0.5) -> void:
    damage_intensity = maxf(damage_intensity, clampf(0.42 + severity * 0.58, 0.0, 1.0))


func set_sanctuary_integrity(value: float) -> void:
    sanctuary_integrity = clampf(value, 0.0, 1.0)
    if sanctuary_integrity < 0.7:
        tactical_hint_elapsed = 0.0
    _refresh_contextual_chrome()
