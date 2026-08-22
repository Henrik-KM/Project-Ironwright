class_name StoryArchiveDirector3D
extends Node

## Sparse, replay-compatible environmental history. Records unlock from real
## discoveries and recovered components, then remain available through the
## on-demand Town Archive instead of becoming another recurring task.

signal record_unlocked(record_id: StringName, display_name: String, description: String)

const DATA_PATH := "res://data/story_archive.json"

var run_state: RunState3D
var region_director: WorldRegionDirector3D
var site_source: Node
var records: Dictionary = {}
var arcs: Array[Dictionary] = []
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


func connect_event_source(source: Node) -> void:
    if source == null:
        return
    if source.has_signal(&"operation_changed"):
        var operation_callback := Callable(self, "_on_operation_changed")
        if not source.is_connected(&"operation_changed", operation_callback):
            source.connect(&"operation_changed", operation_callback)
    if source.has_signal(&"site_discovered"):
        site_source = source
        var site_callback := Callable(self, "_on_site_discovered")
        if not source.is_connected(&"site_discovered", site_callback):
            source.connect(&"site_discovered", site_callback)
    if source.has_signal(&"endgame_completed"):
        var endgame_callback := Callable(self, "_on_endgame_completed")
        if not source.is_connected(&"endgame_completed", endgame_callback):
            source.connect(&"endgame_completed", endgame_callback)


func unlock_opening_record() -> void:
    _unlock_trigger(&"opening", &"")


func record_machine_witness(witness_id: StringName) -> void:
    _unlock_trigger(&"machine_witness", witness_id)


func reconcile_discovered_state() -> void:
    unlock_opening_record()
    if region_director == null:
        return
    for region in region_director.discovered_regions():
        _unlock_trigger(&"region_discovered", StringName(str(region.get("id", ""))))
    if site_source != null and site_source.has_method(&"discovered_sites"):
        for site in site_source.discovered_sites():
            if site != null and is_instance_valid(site):
                _unlock_trigger(&"site_discovered", StringName(str(site.get("site_id"))))


func has_record(record_id: StringName) -> bool:
    return bool(unlocked_records.get(record_id, false))


func record_count() -> int:
    return unlocked_records.size()


func archive_records() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    result.append_array(story_arc_summaries())
    for record in _sorted_records():
        var record_id := StringName(str(record.get("id", "")))
        if not has_record(record_id):
            continue
        result.append(record.duplicate(true))
    result.append_array(_observed_ecology_records())
    result.append_array(_pressure_chronicle_records())
    return result


## Returns the current run-level narrative threads as read-only archive entries.
## Progress is derived from already-unlocked physical records, so it remains
## correct across save/load without creating a second quest or task system.
func story_arc_summaries() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for arc in arcs:
        var required_ids: Array = arc.get("record_ids", [])
        var recovered := 0
        var missing_names: Array[String] = []
        for raw_id in required_ids:
            var record_id := StringName(str(raw_id))
            if has_record(record_id):
                recovered += 1
            else:
                var missing: Variant = records.get(record_id, {})
                if missing is Dictionary:
                    missing_names.append(str((missing as Dictionary).get("display_name", String(record_id))))
        var total := required_ids.size()
        var stage_description := str(arc.get("description", "The thread has not yet found its shape."))
        var selected_stage := -1
        for raw_stage in arc.get("stages", []):
            if not (raw_stage is Dictionary):
                continue
            var stage := raw_stage as Dictionary
            var stage_count := int(stage.get("count", 0))
            if recovered >= stage_count and stage_count >= selected_stage:
                selected_stage = stage_count
                stage_description = str(stage.get("description", stage_description))
        var status_line := "THREAD PROGRESS · %d/%d PHYSICAL CLUES RECOVERED" % [recovered, total]
        var continuation := ""
        if recovered >= total:
            continuation = "The thread is complete. Its meaning now belongs to the run's ending."
        elif not missing_names.is_empty():
            var visible_missing := missing_names.slice(0, mini(2, missing_names.size()))
            continuation = "NEXT TRACE · %s" % ", ".join(visible_missing)
        result.append({
            "id": "thread.%s" % str(arc.get("id", "unknown")),
            "kind": "story_thread",
            "display_name": "THREAD · %s · %d/%d" % [str(arc.get("display_name", "Unknown")), recovered, total],
            "description": "%s\n\n%s\n%s" % [status_line, stage_description, continuation],
            "source_name": str(arc.get("source_name", "Run-level story")),
            "arc": str(arc.get("id", "story")),
            "sequence": int(arc.get("sequence", 0)),
            "progress": recovered,
            "total": total,
        })
    return result


func _observed_ecology_records() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if run_state == null or run_state.observed_species.is_empty():
        return result
    var species_keys: Array[String] = []
    for raw_key in run_state.observed_species:
        species_keys.append(str(raw_key))
    species_keys.sort()
    var sequence := 800
    for species_key in species_keys:
        var entry: Dictionary = run_state.observed_species.get(species_key, {})
        var behaviour_names: Array[String] = []
        for raw_behaviour in entry.get("behaviours", []):
            behaviour_names.append(str(raw_behaviour).replace("_", " "))
        var display_name: String = species_key.replace("_", " ").capitalize()
        var behaviour_text := ", ".join(behaviour_names) if not behaviour_names.is_empty() else "unclassified movement"
        result.append({
            "id": "bestiary.%s" % species_key,
            "display_name": "Bestiary · %s" % display_name,
            "description": "Field evidence identifies %s. Observed behaviour: %s. This is a remembered ecological pattern, not a command or recurring task." % [display_name, behaviour_text],
            "source_name": "Regional ecology",
            "arc": "bestiary",
            "sequence": sequence,
        })
        sequence += 1
    return result


func _pressure_chronicle_records() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if run_state == null or run_state.observed_region_pressure.is_empty():
        return result
    var region_keys: Array[String] = []
    for raw_key in run_state.observed_region_pressure:
        region_keys.append(str(raw_key))
    region_keys.sort()
    var sequence := 900
    for region_key in region_keys:
        var entry: Dictionary = run_state.observed_region_pressure.get(region_key, {})
        var display_name := str(entry.get("display_name", region_key))
        var peak := int(round(float(entry.get("peak_pressure", 0.0)) * 100.0))
        result.append({
            "id": "pressure.%s" % region_key,
            "display_name": "Pressure Chronicle · %s" % display_name,
            "description": "%s reached %d%% ecological pressure during the run. The trace remains a remembered regional consequence, not a command or recurring task." % [display_name, peak],
            "source_name": "Regional ecology",
            "arc": "pressure",
            "sequence": sequence,
        })
        sequence += 1
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


func _on_site_discovered(site: Node) -> void:
    if site == null or not is_instance_valid(site):
        return
    _unlock_trigger(&"site_discovered", StringName(str(site.get("site_id"))))


func _on_component_recovered(component_id: StringName) -> void:
    _unlock_trigger(&"component_recovered", component_id)


func _on_operation_changed(kind: StringName, state: StringName, _detail: String) -> void:
    var trigger_id := StringName("%s:%s" % [String(kind), String(state)])
    _unlock_trigger(&"operation_state", trigger_id)


func _on_endgame_completed(protocol_id: StringName, _display_name: String, _ending: String) -> void:
    _unlock_trigger(&"endgame_completed", protocol_id)


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
    arcs.clear()
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
    var arc_entries: Variant = (parsed as Dictionary).get("arcs", [])
    if arc_entries is Array:
        for entry in arc_entries:
            if entry is Dictionary and not str((entry as Dictionary).get("id", "")).is_empty():
                arcs.append((entry as Dictionary).duplicate(true))
        arcs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
            var a_sequence := int(a.get("sequence", 0))
            var b_sequence := int(b.get("sequence", 0))
            if a_sequence == b_sequence:
                return str(a.get("id", "")) < str(b.get("id", ""))
            return a_sequence < b_sequence
        )
