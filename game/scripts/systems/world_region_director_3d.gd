class_name WorldRegionDirector3D
extends Node

signal region_discovered(region_id: StringName, display_name: String)
signal region_changed(region_id: StringName)

const REGIONS_PATH := "res://data/world_regions.json"

var world_parent: Node3D
var landmarks: Dictionary = {}
var region_data: Dictionary = {}
var load_errors: Array[String] = []


func configure(next_world_parent: Node3D) -> void:
    world_parent = next_world_parent


func _ready() -> void:
    _load_regions()
    _spawn_landmarks()


func _load_regions() -> void:
    landmarks.clear()
    region_data.clear()
    load_errors.clear()
    var file := FileAccess.open(REGIONS_PATH, FileAccess.READ)
    if file == null:
        load_errors.append("Missing %s" % REGIONS_PATH)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        load_errors.append("Invalid region JSON")
        return
    for raw_region in (parsed as Dictionary).get("regions", []):
        if not (raw_region is Dictionary):
            continue
        var data := (raw_region as Dictionary).duplicate(true)
        var region_id := StringName(str(data.get("id", "")))
        if region_id == &"":
            load_errors.append("Region without stable id")
            continue
        region_data[region_id] = data


func _spawn_landmarks() -> void:
    if world_parent == null:
        world_parent = get_parent() as Node3D
    if world_parent == null:
        return
    for region_id in region_data:
        var data: Dictionary = region_data[region_id]
        var landmark := RegionLandmark3D.new()
        landmark.name = "Region_%s" % String(region_id).replace("region.", "").to_pascal_case()
        landmark.configure(data)
        world_parent.add_child(landmark)
        landmarks[region_id] = landmark
        landmark.landmark_changed.connect(func(changed: RegionLandmark3D) -> void:
            region_changed.emit(changed.region_id)
        )


func get_landmark(region_id: StringName) -> RegionLandmark3D:
    var value: Variant = landmarks.get(region_id, null)
    return value as RegionLandmark3D if value is RegionLandmark3D else null


func get_region_data(region_id: StringName) -> Dictionary:
    var value: Variant = region_data.get(region_id, {})
    return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func discover_region(region_id: StringName) -> bool:
    var landmark := get_landmark(region_id)
    if landmark == null or landmark.discovered:
        return false
    landmark.set_discovered(true)
    region_discovered.emit(region_id, landmark.display_name)
    return true


func is_discovered(region_id: StringName) -> bool:
    var landmark := get_landmark(region_id)
    return landmark != null and landmark.discovered


func discovered_count() -> int:
    var count := 0
    for value in landmarks.values():
        var landmark := value as RegionLandmark3D
        if landmark != null and landmark.discovered:
            count += 1
    return count


func discovered_regions() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for region_id in region_data:
        var landmark := get_landmark(region_id)
        if landmark == null or not landmark.discovered:
            continue
        var data := get_region_data(region_id)
        data["pressure"] = landmark.effective_pressure()
        data["suppression"] = landmark.suppression
        result.append(data)
    result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return str(a.get("display_name", "")) < str(b.get("display_name", ""))
    )
    return result


func center(region_id: StringName) -> Vector3:
    var landmark := get_landmark(region_id)
    return landmark.global_position if landmark != null else Vector3.ZERO


func radius(region_id: StringName) -> float:
    var landmark := get_landmark(region_id)
    return landmark.radius if landmark != null else 32.0


func region_for_position(position: Vector3) -> StringName:
    var best_id: StringName = &"region.heartforge_district"
    var best_distance := INF
    for region_id in landmarks:
        var landmark := get_landmark(region_id)
        if landmark == null:
            continue
        var distance := position.distance_to(landmark.global_position)
        if distance < best_distance:
            best_distance = distance
            best_id = region_id
    return best_id


func route_from_heartforge(region_id: StringName, origin: Vector3) -> PackedVector3Array:
    return route_from_heartforge_variant(region_id, origin, 0)


func route_from_heartforge_variant(region_id: StringName, origin: Vector3, variant_index: int = 0) -> PackedVector3Array:
    var result := PackedVector3Array()
    result.append(origin)
    var data := get_region_data(region_id)
    var raw_route: Array = data.get("route_from_heartforge", [])
    if variant_index > 0:
        var variants: Array = data.get("route_variants", [])
        var variant_offset := variant_index - 1
        if variant_offset >= 0 and variant_offset < variants.size():
            var raw_variant: Variant = variants[variant_offset]
            if raw_variant is Dictionary:
                raw_route = (raw_variant as Dictionary).get("points", [])
            elif raw_variant is Array:
                raw_route = raw_variant as Array
    for raw_point in raw_route:
        if raw_point is Array and raw_point.size() >= 3:
            result.append(Vector3(float(raw_point[0]), float(raw_point[1]), float(raw_point[2])))
    var destination := center(region_id)
    if result.is_empty() or result[result.size() - 1].distance_to(destination) > 0.5:
        result.append(destination)
    return result


func route_variant_count(region_id: StringName) -> int:
    var data := get_region_data(region_id)
    var variants: Array = data.get("route_variants", [])
    return variants.size()


func route_variant_label(region_id: StringName, variant_index: int) -> String:
    if variant_index <= 0:
        return "primary route"
    var data := get_region_data(region_id)
    var variants: Array = data.get("route_variants", [])
    var offset := variant_index - 1
    if offset < 0 or offset >= variants.size():
        return "alternate route"
    var raw_variant: Variant = variants[offset]
    if raw_variant is Dictionary:
        var label := str((raw_variant as Dictionary).get("label", "alternate route"))
        return label if not label.is_empty() else "alternate route"
    return "alternate route"


func add_pressure(region_id: StringName, amount: float) -> void:
    var landmark := get_landmark(region_id)
    if landmark == null:
        return
    landmark.set_pressure(landmark.pressure + amount)


func suppress_region(region_id: StringName, amount: float) -> void:
    var landmark := get_landmark(region_id)
    if landmark == null:
        return
    landmark.add_suppression(amount)


func effective_pressure(region_id: StringName) -> float:
    var landmark := get_landmark(region_id)
    return landmark.effective_pressure() if landmark != null else 0.5


func context_dictionary() -> Dictionary:
    var discovered_ids: Array[String] = []
    for region_id in landmarks:
        if is_discovered(region_id):
            discovered_ids.append(String(region_id))
    return {
        "regions_discovered": discovered_ids,
        "regions_discovered_count": discovered_ids.size(),
    }


func to_dictionary() -> Dictionary:
    var serialized: Array[Dictionary] = []
    for region_id in landmarks:
        var landmark := get_landmark(region_id)
        if landmark != null:
            serialized.append(landmark.to_dictionary())
    return {
        "schema_version": 1,
        "regions": serialized,
    }


func restore_from_dictionary(data: Dictionary) -> void:
    for raw_region in data.get("regions", []):
        if not (raw_region is Dictionary):
            continue
        var saved := raw_region as Dictionary
        var region_id := StringName(str(saved.get("region_id", "")))
        var landmark := get_landmark(region_id)
        if landmark != null:
            landmark.restore_from_dictionary(saved)
