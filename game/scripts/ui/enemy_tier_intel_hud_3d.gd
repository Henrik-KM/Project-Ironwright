class_name EnemyTierIntelHUD3D
extends CanvasLayer

var panel: PanelContainer
var heading_label: Label
var density_label: Label
var tier_label: Label
var nest_label: Label
var trend_label: Label
var escalation_label: Label
var suppression_label: Label
var current_summary: Dictionary = {}
var suppression_summary: String = ""


func _ready() -> void:
    layer = 24
    _build_ui()
    visible = false


func _build_ui() -> void:
    panel = PanelContainer.new()
    panel.name = "EcologyIntelPanel"
    panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    panel.offset_left = -378.0
    panel.offset_right = -22.0
    panel.offset_top = 260.0
    panel.offset_bottom = 492.0
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.018, 0.035, 0.038, 0.91)
    style.border_color = Color(0.42, 0.62, 0.56, 0.42)
    style.set_border_width_all(1)
    style.set_corner_radius_all(9)
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
    style.shadow_size = 10
    style.content_margin_left = 17.0
    style.content_margin_right = 17.0
    style.content_margin_top = 14.0
    style.content_margin_bottom = 14.0
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 7)
    panel.add_child(box)

    heading_label = _label("ECOLOGY INTELLIGENCE", 15, Color("b9d3ca"))
    box.add_child(heading_label)
    box.add_child(HSeparator.new())
    density_label = _label("Feral population · unknown", 16, Color("e7eee9"))
    box.add_child(density_label)
    tier_label = _label("Highest confirmed tier · I", 16, Color("e7eee9"))
    box.add_child(tier_label)
    nest_label = _label("Active nests · unknown", 15, Color("c0cbc7"))
    box.add_child(nest_label)
    trend_label = _label("Trend · unknown", 15, Color("c0cbc7"))
    box.add_child(trend_label)
    escalation_label = _label("No confirmed saturation transfer.", 14, Color("d5ad72"))
    escalation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    escalation_label.custom_minimum_size.y = 42.0
    box.add_child(escalation_label)
    suppression_label = _label("", 13, Color("91aaa2"))
    suppression_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    suppression_label.custom_minimum_size.y = 42.0
    box.add_child(suppression_label)


func _label(value: String, font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_constant_override("outline_size", 3)
    label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
    return label


func update_intel(summary: Dictionary) -> void:
    current_summary = summary.duplicate(true)
    if panel == null:
        return
    density_label.text = "Feral population · %s" % str(summary.get("tier_1_density", "UNKNOWN"))
    var tier := int(summary.get("highest_confirmed_tier", 1))
    tier_label.text = "Highest confirmed tier · %s · %s" % [_roman(tier), str(summary.get("highest_tier_name", "Unknown"))]
    nest_label.text = "Active reproductive nests · %d" % int(summary.get("active_nests", 0))
    var trend := str(summary.get("trend", "STABLE"))
    trend_label.text = "Ecological trend · %s" % trend
    trend_label.add_theme_color_override("font_color", _trend_color(trend))
    var saturated_tiers: Array = summary.get("saturated_tiers", [])
    if saturated_tiers.is_empty():
        escalation_label.text = "No confirmed tier saturation. Current replenishment is still being spent on existing population levels."
    else:
        var labels: Array[String] = []
        for raw_tier in saturated_tiers:
            labels.append(_roman(int(raw_tier)))
        escalation_label.text = "SATURATION: Tier%s %s converting future replenishment upward at 10:1." % ["s" if labels.size() > 1 else "", ", ".join(labels)]
    suppression_label.text = suppression_summary


func update_suppression(value: String) -> void:
    suppression_summary = value
    if suppression_label != null:
        suppression_label.text = suppression_summary


func set_command_map_visible(value: bool) -> void:
    visible = value


func _roman(value: int) -> String:
    match value:
        1:
            return "I"
        2:
            return "II"
        3:
            return "III"
        4:
            return "IV"
        _:
            return "V"


func _trend_color(value: String) -> Color:
    match value:
        "WORSENING":
            return Color("e29a6c")
        "SUPPRESSED":
            return Color("77d5a6")
        _:
            return Color("c0cbc7")
