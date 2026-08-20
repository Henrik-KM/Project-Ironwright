class_name EnemyTierHUD3D
extends CanvasLayer

var panel: PanelContainer
var title_label: Label
var summary_label: Label
var tier_rows: Array[Label] = []
var footer_label: Label
var latest_snapshot: Dictionary = {}
var map_visible: bool = false


func _ready() -> void:
    layer = 28
    _build_ui()
    set_map_visible(false)


func _build_ui() -> void:
    panel = PanelContainer.new()
    panel.name = "EcologicalIntelligencePanel"
    panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    panel.offset_left = -410.0
    panel.offset_right = -22.0
    panel.offset_top = 76.0
    panel.offset_bottom = 432.0
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.018, 0.035, 0.04, 0.94)
    style.border_color = Color(0.49, 0.66, 0.63, 0.38)
    style.set_border_width_all(1)
    style.set_corner_radius_all(9)
    style.content_margin_left = 18.0
    style.content_margin_right = 18.0
    style.content_margin_top = 14.0
    style.content_margin_bottom = 14.0
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)

    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", 7)
    panel.add_child(box)

    title_label = _label("ECOLOGICAL INTELLIGENCE", 17, Color("dce8e4"))
    box.add_child(title_label)
    summary_label = _label("No tier estimate available.", 14, Color("c7d2cf"))
    summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    summary_label.custom_minimum_size.y = 54.0
    box.add_child(summary_label)
    box.add_child(HSeparator.new())

    for tier in range(1, 6):
        var row := _label("TIER %d · UNCONFIRMED" % tier, 14, Color("8fa09d"))
        row.custom_minimum_size.y = 34.0
        row.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
        tier_rows.append(row)
        box.add_child(row)

    box.add_child(HSeparator.new())
    footer_label = _label("Destroy nests to reduce long-term replenishment. Killing organisms creates temporary population headroom.", 13, Color("d5a86a"))
    footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    footer_label.custom_minimum_size.y = 54.0
    box.add_child(footer_label)


func set_snapshot(snapshot: Dictionary) -> void:
    latest_snapshot = snapshot.duplicate(true)
    _refresh()


func set_map_visible(value: bool) -> void:
    map_visible = value
    panel.visible = value
    if value:
        _refresh()


func _refresh() -> void:
    if panel == null or latest_snapshot.is_empty():
        return
    var highest := int(latest_snapshot.get("highest_observed_tier", 1))
    var active_nests := int(latest_snapshot.get("active_nests", 0))
    var total_nests := int(latest_snapshot.get("total_nests", 0))
    var trend := str(latest_snapshot.get("trend", "unknown"))
    summary_label.text = "Highest confirmed tier: %d\nPopulation trend: %s · active brood sites: %d/%d" % [highest, trend.to_upper(), active_nests, total_nests]

    var tiers: Array = latest_snapshot.get("tiers", [])
    for index in range(tier_rows.size()):
        var tier_number := index + 1
        var row := tier_rows[index]
        var data := _find_tier_data(tiers, tier_number)
        if data.is_empty() or tier_number > highest:
            row.text = "TIER %d · UNCONFIRMED" % tier_number
            row.modulate = Color("7d8b88")
            continue
        var density := str(data.get("density", "unknown")).to_upper()
        var display_name := str(data.get("display_name", "Tier %d" % tier_number)).to_upper()
        var intelligence := str(data.get("intelligence_label", "unknown"))
        var saturated := bool(data.get("saturated", false))
        var flow := _replenishment_description(float(data.get("replenishment_per_minute", 0.0)), saturated)
        row.text = "TIER %d · %s · %s\n%s · %s" % [tier_number, display_name, density, intelligence, flow]
        row.modulate = _tier_color(tier_number, saturated)


func _find_tier_data(tiers: Array, tier_number: int) -> Dictionary:
    for raw_data in tiers:
        if raw_data is Dictionary and int((raw_data as Dictionary).get("tier", 0)) == tier_number:
            return (raw_data as Dictionary).duplicate(true)
    return {}


func _replenishment_description(rate: float, saturated: bool) -> String:
    if saturated:
        return "SATURATED — ESCALATION PRESSURE MOVING UPWARD"
    if rate <= 0.001:
        return "replenishment dormant"
    if rate < 1.0:
        return "slow replenishment"
    if rate < 4.0:
        return "steady replenishment"
    if rate < 9.0:
        return "rapid replenishment"
    return "extreme replenishment"


func _tier_color(tier: int, saturated: bool) -> Color:
    if saturated:
        return Color("f07764")
    match tier:
        1:
            return Color("b8c5ba")
        2:
            return Color("dfaa68")
        3:
            return Color("d97c88")
        4:
            return Color("b897e8")
        5:
            return Color("f05a73")
    return Color.WHITE


func _label(value: String, size_value: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_size_override("font_size", size_value)
    label.add_theme_constant_override("outline_size", 3)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.88))
    return label
