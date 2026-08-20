class_name IronwrightPreAlphaHUD3D
extends IronwrightBeautifulHUD3D

## Presentation reset after the first full-game screenshot review. The game is
## a desktop survival-strategy title, not a mobile dashboard: permanent control
## legends and healthy-state status banners stay out of the playfield.

var _command_help_panel: PanelContainer
var _sanctuary_badge: PanelContainer


func _ready() -> void:
    super._ready()
    _command_help_panel = root_control.get_node_or_null("CommandHelpPanel") as PanelContainer
    _sanctuary_badge = root_control.get_node_or_null("SanctuaryBadge") as PanelContainer
    _apply_desktop_density()


func _apply_desktop_density() -> void:
    if help_label != null:
        help_label.visible = false
    if _command_help_panel != null:
        _command_help_panel.visible = false
    if _sanctuary_badge != null:
        _sanctuary_badge.visible = sanctuary_integrity < 0.78

    if objective_panel != null:
        objective_panel.modulate = Color(1.0, 1.0, 1.0, 0.9)
    if objective_label != null:
        objective_label.add_theme_font_size_override("font_size", 16)
        objective_label.add_theme_constant_override("outline_size", 3)
    if prompt_panel != null:
        prompt_panel.modulate = Color(1.0, 1.0, 1.0, 0.88)
    if prompt_label != null:
        prompt_label.add_theme_font_size_override("font_size", 14)
    if resource_panel != null:
        resource_panel.modulate = Color(1.0, 1.0, 1.0, 0.88)
    if resource_label != null:
        # Reduce dashboard chrome around the data, not the legibility of the
        # actual reserve values. The constrained-resolution regression keeps
        # this at desktop-readable size.
        resource_label.add_theme_font_size_override("font_size", 20)
    if focus_label != null:
        focus_label.add_theme_font_size_override("font_size", 14)
    if operation_label != null:
        operation_label.add_theme_font_size_override("font_size", 12)
    if notification_panel != null:
        notification_panel.modulate = Color(1.0, 1.0, 1.0, 0.9)


func set_sanctuary_integrity(value: float) -> void:
    super.set_sanctuary_integrity(value)
    if _sanctuary_badge != null:
        _sanctuary_badge.visible = sanctuary_integrity < 0.78


func set_operation(text_value: String) -> void:
    super.set_operation(text_value)
    # Keep operation text concise in the permanent HUD. Full detail remains in
    # machine reports and strategic screens.
    if operation_label != null and operation_label.text.length() > 92:
        operation_label.text = operation_label.text.left(89) + "…"
