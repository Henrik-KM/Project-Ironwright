class_name IronwrightPreAlphaHUD3D
extends IronwrightBeautifulHUD3D

## Desktop survival-strategy HUD. Persistent information stays available but
## the world, machines and threats are allowed to dominate the frame.

var _command_help_panel: PanelContainer
var _sanctuary_badge: PanelContainer
var _health_panel: PanelContainer


func _ready() -> void:
    super._ready()
    _command_help_panel = root_control.get_node_or_null("CommandHelpPanel") as PanelContainer
    _sanctuary_badge = root_control.get_node_or_null("SanctuaryBadge") as PanelContainer
    _health_panel = root_control.get_node_or_null("HealthPanel") as PanelContainer
    _apply_desktop_density()
    _apply_compact_layout(Vector2(get_viewport().get_visible_rect().size))


func _apply_desktop_density() -> void:
    if help_label != null:
        help_label.visible = false
    if _command_help_panel != null:
        _command_help_panel.visible = false
    if _sanctuary_badge != null:
        _sanctuary_badge.visible = sanctuary_integrity < 0.78

    if objective_panel != null:
        objective_panel.modulate = Color(1.0, 1.0, 1.0, 0.82)
    if objective_label != null:
        objective_label.add_theme_font_size_override("font_size", 15)
        objective_label.add_theme_constant_override("outline_size", 3)
    if prompt_panel != null:
        prompt_panel.modulate = Color(1.0, 1.0, 1.0, 0.82)
    if prompt_label != null:
        prompt_label.add_theme_font_size_override("font_size", 14)
    if resource_panel != null:
        resource_panel.modulate = Color(1.0, 1.0, 1.0, 0.8)
    if resource_label != null:
        resource_label.add_theme_font_size_override("font_size", 20)
    if focus_label != null:
        focus_label.add_theme_font_size_override("font_size", 13)
    if operation_label != null:
        operation_label.add_theme_font_size_override("font_size", 12)
    if notification_panel != null:
        notification_panel.modulate = Color(1.0, 1.0, 1.0, 0.84)


func _refresh_contextual_chrome() -> void:
    super._refresh_contextual_chrome()
    # The release shell has already taught the opening controls through the
    # objective and direct prompt. Keep its tactical frame stricter than the
    # generic cinematic skin: the command legend and healthy sanctuary badge
    # never return unless a relevant exception is active.
    if help_label != null:
        help_label.visible = false
        help_label.modulate.a = 0.0
    if _command_help_panel != null:
        _command_help_panel.visible = false
    if _sanctuary_badge != null:
        _sanctuary_badge.visible = sanctuary_integrity < 0.78


func apply_safe_layout(viewport_size: Vector2) -> void:
    super.apply_safe_layout(viewport_size)
    if is_inside_tree():
        _apply_compact_layout(viewport_size)


func _apply_compact_layout(viewport_size: Vector2) -> void:
    if objective_panel == null:
        return
    var narrow := viewport_size.x < 1050.0
    var text_scale := _accessibility_text_scale()
    # The opening objective is intentionally explanatory. At the largest
    # supported text scale its copy needs a taller measured card so it cannot
    # paint into the health stack below it.
    var objective_height := 148.0 + maxf(0.0, text_scale - 1.0) * 220.0

    objective_panel.position = Vector2(18.0, 18.0)
    # The first salvage objective is deliberately explanatory. Give its copy
    # a measured card instead of letting the health stack cover the last line
    # in the compact release viewport.
    objective_panel.size = Vector2(360.0 if narrow else 405.0, objective_height)
    objective_label.position = Vector2(18.0, 34.0)
    objective_label.size.x = objective_panel.size.x - 36.0
    objective_panel.size.y = maxf(objective_panel.size.y, objective_label.get_combined_minimum_size().y + 48.0)
    objective_label.size.y = objective_panel.size.y - 48.0

    resource_panel.size = Vector2(296.0 if narrow else 318.0, 174.0)
    # The base HUD uses right-anchored offsets, but the compact release scene
    # also runs inside real SubViewports and small exported windows where that
    # anchor can resolve against an unmeasured parent during the first layout
    # pass. Place the tactical cards in viewport coordinates so the persistent
    # resource/focus readout cannot disappear off the left edge.
    resource_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    resource_panel.position = Vector2(maxf(18.0, viewport_size.x - resource_panel.size.x - 18.0), 18.0)
    resource_label.position = Vector2(18.0, 31.0)
    resource_label.size = Vector2(resource_panel.size.x - 36.0, 66.0)
    focus_label.position = Vector2(18.0, 108.0)
    focus_label.size = Vector2(resource_panel.size.x - 36.0, 24.0)
    operation_label.position = Vector2(18.0, 136.0)
    operation_label.size = Vector2(resource_panel.size.x - 36.0, 32.0)

    _refresh_operation_density()

    notification_panel.size = Vector2(330.0, 126.0)
    notification_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    notification_panel.position = Vector2(maxf(18.0, viewport_size.x - notification_panel.size.x - 18.0), 206.0)
    notification_label.position = Vector2(18.0, 32.0)
    notification_label.size = Vector2(294.0, 82.0)

    var prompt_width := minf(600.0, maxf(360.0, viewport_size.x * 0.48))
    prompt_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    prompt_panel.offset_left = -prompt_width * 0.5
    prompt_panel.offset_right = prompt_width * 0.5
    prompt_panel.offset_top = -78.0
    prompt_panel.offset_bottom = -26.0
    prompt_label.position = Vector2(16.0, 8.0)
    prompt_label.size = Vector2(prompt_width - 32.0, 36.0)

    if operation_badge != null:
        var badge_width := minf(600.0, maxf(360.0, viewport_size.x * 0.62))
        operation_badge.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
        operation_badge.offset_left = -badge_width * 0.5
        operation_badge.offset_right = badge_width * 0.5
        operation_badge.offset_top = -130.0
        operation_badge.offset_bottom = -88.0
        operation_badge_label.position = Vector2(12.0, 7.0)
        operation_badge_label.size = Vector2(badge_width - 24.0, 28.0)

    if _health_panel != null:
        _health_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
        # Keep the two vulnerable silhouettes' health bars visible under the
        # opening objective rather than letting a bottom-left anchor resolve
        # to a negative y-coordinate in the compact release viewport.
        _health_panel.position = Vector2(18.0, objective_panel.position.y + objective_panel.size.y + 10.0)
        _health_panel.size = Vector2(312.0, 112.0)
        var content := _health_panel.get_node_or_null("PanelContent") as Control
        if content != null:
            for child in content.get_children():
                if child is Label:
                    (child as Label).add_theme_font_size_override("font_size", 12)
            if player_bar != null:
                player_bar.position = Vector2(96.0, 34.0)
                player_bar.size = Vector2(200.0, 11.0)
            if companion_bar != null:
                companion_bar.position = Vector2(96.0, 87.0)
                companion_bar.size = Vector2(200.0, 10.0)


func _accessibility_text_scale() -> float:
    var settings := get_tree().get_first_node_in_group(&"release_settings_service") as Node
    if settings != null and settings.has_method(&"get_value"):
        return clampf(float(settings.get_value(&"text_scale", 1.0)), 0.75, 1.6)
    return 1.0


func set_objective(title: String, detail: String) -> void:
    super.set_objective(title, detail)
    if is_inside_tree() and get_viewport() != null:
        _apply_compact_layout(Vector2(get_viewport().get_visible_rect().size))


func set_sanctuary_integrity(value: float) -> void:
    super.set_sanctuary_integrity(value)
    if _sanctuary_badge != null:
        _sanctuary_badge.visible = sanctuary_integrity < 0.78


func set_operation(text_value: String) -> void:
    super.set_operation(text_value)
    _refresh_operation_density()
    if operation_label != null and operation_label.text.length() > 76:
        operation_label.text = operation_label.text.left(73) + "…"


func _refresh_operation_density() -> void:
    if resource_panel == null or operation_label == null:
        return
    var status := operation_label.text.strip_edges()
    var has_live_status := not status.is_empty() and status != "No remote operation"
    operation_label.visible = has_live_status
    resource_panel.size.y = 174.0 if has_live_status else 132.0
