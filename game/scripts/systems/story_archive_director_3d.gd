class_name StoryArchiveDirector3D
extends Node

## Sparse, replay-compatible environmental history. Records unlock from real
## discoveries and recovered components, then remain available through the
## on-demand Town Archive instead of becoming another recurring task.

signal record_unlocked(record_id: StringName, display_name: String, description: String)

const DATA_PATH := "res://data/story_archive.json"

var run_state: RunState3D
var region_director: WorldRegionDirector3D
var records: Dictionary = {}
var unlocked_records: Dictionary = {}
var load_errors: Array[String] = []


func configure(next_run_state: RunState3D, next_region_director: WorldRegionDirector3D) -> void:
    run_state = next_run_state
    region_director = next_region_director


func _ready() -> void:
    _load_records()
    if region_director != null and not region_director.is_connected(&"region_discovered", Callable(self, "_on_region_discovered")):
        region_director.region_discovered.connect(_on_region_discovered)
    call_deferred("unlock_opening_record")


func connect_component_source(source: Node) -> void:
    if source == null or not source.has_signal(&"component_recovered"):
        return
    var callback := Callable(self, "_on_component_recovered")
    if not source.is_connected(&"component_recovered", callback):
        source.connect(&"component_recovered", callback)


func unlock_opening_record() -> void:
    _unlock_trigger(&"opening", &"")


func reconcile_discovered_state() -> void:
    unlock_opening_record()
    if region_director == null:
        return
    for region in region_director.discovered_regions():
        _unlock_trigger(&"region_discovered", StringName(str(region.get("id", ""))))


func has_record(record_id: StringName) -> bool:
    return bool(unlocked_records.get(record_id, false))


func record_count() -> int:
    return unlocked_records.size()


func archive_records() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for record in _sorted_records():
        var record_id := StringName(str(record.get("id", "")))
        if not has_record(record_id):
            continue
        result.append(record.duplicate(true))
    return result


func to_dictionary() -> Dictionary:
    var ids: Array[String] = []
    for record in _sorted_records():
        var record_id := StringName(str(record.get("id", "")))
        if has_record(record_id):
            ids.append(String(record_id))
    return {
        "schema_version": 1,
        "unlocked_records": ids,
    }


func restore_from_dictionary(data: Dictionary) -> void:
    unlocked_records.clear()
    for raw_id in data.get("unlocked_records", []):
        var record_id := StringName(str(raw_id))
        if records.has(record_id):
            unlocked_records[record_id] = true


func _on_region_discovered(region_id: StringName, _display_name: String) -> void:
    _unlock_trigger(&"region_discovered", region_id)


func _on_component_recovered(component_id: StringName) -> void:
    _unlock_trigger(&"component_recovered", component_id)


func _unlock_trigger(trigger: StringName, trigger_id: StringName) -> void:
    for record in _sorted_records():
        if StringName(str(record.get("trigger", ""))) != trigger:
            continue
        if StringName(str(record.get("trigger_id", ""))) != trigger_id:
            continue
        _unlock_record(StringName(str(record.get("id", ""))))


func _unlock_record(record_id: StringName) -> void:
    if record_id == &"" or has_record(record_id):
        return
    var value: Variant = records.get(record_id, {})
    if not (value is Dictionary):
        return
    var record := value as Dictionary
    unlocked_records[record_id] = true
    var display_name := str(record.get("display_name", String(record_id)))
    var description := str(record.get("description", ""))
    if run_state != null:
        run_state.log_event("Town record recovered: %s" % display_name)
    record_unlocked.emit(record_id, display_name, description)


func _sorted_records() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for value in records.values():
        if value is Dictionary:
            result.append((value as Dictionary).duplicate(true))
    result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        var a_sequence := int(a.get("sequence", 0))
        var b_sequence := int(b.get("sequence", 0))
        if a_sequence == b_sequence:
            return str(a.get("id", "")) < str(b.get("id", ""))
        return a_sequence < b_sequence
    )
    return result


func _load_records() -> void:
    records.clear()
    load_errors.clear()
    var file := FileAccess.open(DATA_PATH, FileAccess.READ)
    if file == null:
        load_errors.append("Missing %s" % DATA_PATH)
        push_error(load_errors.back())
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        load_errors.append("Invalid story archive JSON")
        push_error(load_errors.back())
        return
    var entries: Variant = (parsed as Dictionary).get("records", [])
    if not (entries is Array):
        load_errors.append("Story archive has no records array")
        push_error(load_errors.back())
        return
    for entry in entries:
        if not (entry is Dictionary):
            continue
        var record := (entry as Dictionary).duplicate(true)
        var record_id := StringName(str(record.get("id", "")))
        if record_id == &"":
            continue
        records[record_id] = record
