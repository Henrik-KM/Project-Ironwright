class_name OutpostSite3D
extends Node3D

signal site_discovered(site: OutpostSite3D)
signal site_changed(site: OutpostSite3D)

var site_id: StringName = &"site.unknown"
var display_name: String = "Unknown site"
var recommended_role: StringName = &"resource"
var discovered_by: StringName = &""
var description: String = ""
var discovered: bool = false
var outpost: Outpost3D
var _visual_root: Node3D
var _beacon_light: OmniLight3D
var _beacon_lens: Node3D
var _visual_clock: float = 0.0


func configure(data: Dictionary) -> void:
    site_id = StringName(str(data.get("id", "site.unknown")))
    display_name = str(data.get("display_name", "Unknown site"))
    recommended_role = StringName(str(data.get("recommended_outpost_role", "resource")))
    discovered_by = StringName(str(data.get("discovered_by", "")))
    description = str(data.get("description", ""))
    var raw_position: Array = data.get("position", [0.0, 0.0, 0.0])
    if raw_position.size() >= 3:
        position = Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2]))


func _ready() -> void:
    add_to_group(&"outpost_sites")
    _build_visuals()
    _refresh_visibility()


func _process(delta: float) -> void:
    if _visual_root == null or not discovered:
        return
    _visual_clock += delta
    var pulse := 1.0 + sin(_visual_clock * 1.8) * 0.07
    if _beacon_lens != null:
        _beacon_lens.scale = Vector3.ONE * pulse
    if _beacon_light != null:
        _beacon_light.light_energy = 0.62 + sin(_visual_clock * 1.8) * 0.12


func discover() -> bool:
    if discovered:
        return false
    discovered = true
    _refresh_visibility()
    site_discovered.emit(self)
    site_changed.emit(self)
    return true


func set_discovered(value: bool) -> void:
    discovered = value
    _refresh_visibility()
    site_changed.emit(self)


func attach_outpost(next_outpost: Outpost3D) -> void:
    outpost = next_outpost
    site_changed.emit(self)


func has_outpost() -> bool:
    return outpost != null and is_instance_valid(outpost)


func has_functioning_outpost() -> bool:
    return has_outpost() and outpost.is_alive()


func status_text() -> String:
    if not discovered:
        return "%s · undiscovered" % display_name
    if not has_outpost():
        return "%s · clear site · suggested %s" % [display_name, String(recommended_role)]
    if not outpost.is_alive():
        return "%s · destroyed · autonomous rebuild pending" % display_name
    return "%s · %s tier %d · %d%% integrity" % [
        display_name,
        String(outpost.role).capitalize(),
        outpost.tier,
        int(round(100.0 * outpost.current_health / maxf(1.0, outpost.maximum_health))),
    ]


func to_dictionary() -> Dictionary:
    var data := {
        "site_id": String(site_id),
        "discovered": discovered,
    }
    if has_outpost():
        data["outpost"] = outpost.to_dictionary()
    return data


func _refresh_visibility() -> void:
    if _visual_root == null:
        return
    _visual_root.visible = discovered
    if _beacon_light != null:
        _beacon_light.visible = discovered


func _build_visuals() -> void:
    _visual_root = Node3D.new()
    _visual_root.name = "HighDefinitionSiteMarker"
    add_child(_visual_root)

    var concrete := ModelKit3D.material(Color("434240"), 0.0, 0.92)
    var rust := ModelKit3D.material(Color("79523b"), 0.38, 0.76)
    var dark_steel := ModelKit3D.material(Color("202d2f"), 0.72, 0.34)
    var beacon := ModelKit3D.material(Color("294b50"), 0.25, 0.42, Color("6ce1e7"), 2.5)
    var beacon_edge := ModelKit3D.material(Color("78a9a8"), 0.35, 0.3)
    var amber := ModelKit3D.material(Color("a8663d"), 0.3, 0.46, Color("e8a05d"), 1.6)

    ModelKit3D.add_beveled_box(_visual_root, Vector3(4.6, 0.24, 3.2), Vector3(0.0, 0.12, 0.0), concrete, Vector3.ZERO, "SurveyFoundation", 0.16)
    ModelKit3D.add_beveled_box(_visual_root, Vector3(3.7, 0.16, 2.35), Vector3(0.0, 0.31, 0.0), dark_steel, Vector3.ZERO, "SurveyFoundationInset", 0.18)
    for side in [-1.0, 1.0]:
        var side_name := "L" if side < 0.0 else "R"
        ModelKit3D.add_sphere(_visual_root, 0.13, Vector3(side * 1.85, 0.42, -0.98), amber, Vector3.ONE, "SurveyAnchor%sFront" % side_name)
        ModelKit3D.add_sphere(_visual_root, 0.13, Vector3(side * 1.85, 0.42, 0.98), amber, Vector3.ONE, "SurveyAnchor%sRear" % side_name)
    ModelKit3D.add_beveled_box(_visual_root, Vector3(3.0, 0.18, 0.18), Vector3(0.0, 0.52, 0.0), rust, Vector3(0.0, 0.0, 0.42), "SurveyCrossA", 0.2)
    ModelKit3D.add_beveled_box(_visual_root, Vector3(3.0, 0.18, 0.18), Vector3(0.0, 0.54, 0.0), rust, Vector3(0.0, 0.0, -0.42), "SurveyCrossB", 0.2)
    ModelKit3D.add_tapered_cylinder(_visual_root, 0.095, 0.16, 2.7, Vector3(0.0, 1.83, 0.0), rust, Vector3.ZERO, "SurveyMast")
    ModelKit3D.add_cylinder(_visual_root, 0.27, 0.12, Vector3(0.0, 0.7, 0.0), beacon_edge, Vector3.ZERO, "SurveyMastCollar")
    ModelKit3D.add_beveled_box(_visual_root, Vector3(0.12, 1.2, 0.12), Vector3(0.0, 1.22, 0.0), dark_steel, Vector3(0.0, 0.0, 0.32), "SurveyMastBraceL", 0.22)
    ModelKit3D.add_beveled_box(_visual_root, Vector3(0.12, 1.2, 0.12), Vector3(0.0, 1.22, 0.0), dark_steel, Vector3(0.0, 0.0, -0.32), "SurveyMastBraceR", 0.22)
    ModelKit3D.add_beveled_box(_visual_root, Vector3(0.58, 0.28, 0.58), Vector3(0.0, 3.2, 0.0), dark_steel, Vector3.ZERO, "SurveyBeaconHousing", 0.22)
    ModelKit3D.add_cylinder(_visual_root, 0.23, 0.08, Vector3(0.0, 3.34, 0.0), beacon_edge, Vector3.ZERO, "SurveyBeaconRing")
    _beacon_lens = ModelKit3D.add_sphere(_visual_root, 0.16, Vector3(0.0, 3.42, 0.0), beacon, Vector3(1.0, 0.55, 1.0), "SurveyBeaconLens")
    ModelKit3D.add_louvered_panel(_visual_root, Vector3(0.92, 0.62, 0.16), Vector3(0.72, 1.05, 0.0), dark_steel, beacon_edge, Vector3(0.0, 0.0, -0.08), "SurveyServicePanel", 3)
    ModelKit3D.add_surface_panel(_visual_root, Vector3(0.7, 0.22, 0.12), Vector3(-0.72, 0.9, 0.0), rust, amber, Vector3(0.0, 0.0, 0.08), "SurveyIdentityPanel")
    _beacon_light = ModelKit3D.add_glow_light(_visual_root, Vector3(0.0, 3.42, 0.0), Color("6ce1e7"), 0.7, 6.5)
