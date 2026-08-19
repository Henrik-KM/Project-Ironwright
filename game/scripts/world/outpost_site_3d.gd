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
    _visual_root.name = "SiteMarker"
    add_child(_visual_root)

    var concrete := ModelKit3D.material(Color("434240"), 0.0, 0.92)
    var rust := ModelKit3D.material(Color("79523b"), 0.38, 0.76)
    var beacon := ModelKit3D.material(Color("294b50"), 0.25, 0.42, Color("6ce1e7"), 2.5)

    ModelKit3D.add_cylinder(_visual_root, 2.45, 0.2, Vector3(0.0, 0.1, 0.0), concrete, Vector3.ZERO, "OldFoundation")
    ModelKit3D.add_box(_visual_root, Vector3(2.8, 0.25, 0.25), Vector3(0.0, 0.25, 0.0), rust, Vector3(0.0, 0.42, 0.0), "SurveyCrossA")
    ModelKit3D.add_box(_visual_root, Vector3(2.8, 0.25, 0.25), Vector3(0.0, 0.25, 0.0), rust, Vector3(0.0, -0.42, 0.0), "SurveyCrossB")
    ModelKit3D.add_cylinder(_visual_root, 0.08, 2.2, Vector3(0.0, 1.2, 0.0), rust, Vector3.ZERO, "SurveyPole")
    ModelKit3D.add_sphere(_visual_root, 0.16, Vector3(0.0, 2.35, 0.0), beacon, Vector3.ONE, "SurveyBeacon")
    _beacon_light = ModelKit3D.add_glow_light(_visual_root, Vector3(0.0, 2.35, 0.0), Color("6ce1e7"), 0.7, 5.5)
