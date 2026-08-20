class_name EnemyTierEventBridge3D
extends Node

const DATA_PATH := "res://data/enemy_tier_event_modifiers.json"

var enemy_tier_director: EnemyTierDirector3D
var long_operation_director: LongRangeOperationDirector3D
var progression_director: ProgressionDirector3D
var endgame_director: EndgameDirector3D
var modifiers: Dictionary = {}
var applied_events: Dictionary = {}
var load_errors: Array[String] = []


func configure(
        next_enemy_tier_director: EnemyTierDirector3D,
        next_long_operation_director: LongRangeOperationDirector3D,
        next_progression_director: ProgressionDirector3D,
        next_endgame_director: EndgameDirector3D
    ) -> void:
    enemy_tier_director = next_enemy_tier_director
    long_operation_director = next_long_operation_director
    progression_director = next_progression_director
    endgame_director = next_endgame_director


func _ready() -> void:
    _load_modifiers()
    _connect_events()


func _load_modifiers() -> void:
    modifiers.clear()
    load_errors.clear()
    var file := FileAccess.open(DATA_PATH, FileAccess.READ)
    if file == null:
        load_errors.append("Missing enemy tier event modifiers")
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        modifiers = (parsed as Dictionary).duplicate(true)
    else:
        load_errors.append("Enemy tier event modifiers are not a JSON object")


func _connect_events() -> void:
    if long_operation_director != null:
        var operation_callback := Callable(self, "_on_operation_returned")
        if not long_operation_director.operation_returned.is_connected(operation_callback):
            long_operation_director.operation_returned.connect(operation_callback)
    if progression_director != null:
        var technology_callback := Callable(self, "_on_technology_unlocked")
        if not progression_director.technology_unlocked.is_connected(technology_callback):
            progression_director.technology_unlocked.connect(technology_callback)
    if endgame_director != null:
        var endgame_callback := Callable(self, "_on_endgame_started")
        if not endgame_director.endgame_started.is_connected(endgame_callback):
            endgame_director.endgame_started.connect(endgame_callback)


func _on_operation_returned(operation_id: StringName, display_name: String, rewards: Dictionary) -> void:
    _apply_event_once(&"operation", operation_id, "operations")


func _on_technology_unlocked(technology_id: StringName, display_name: String, effects: Array) -> void:
    _apply_event_once(&"technology", technology_id, "technologies")


func _on_endgame_started(protocol_id: StringName, display_name: String) -> void:
    _apply_event_once(&"endgame", protocol_id, "endgame")


func _apply_event_once(kind: StringName, event_id: StringName, section_name: String) -> bool:
    if enemy_tier_director == null:
        return false
    var unique_key := "%s:%s" % [String(kind), String(event_id)]
    if bool(applied_events.get(unique_key, false)):
        return false
    var section: Variant = modifiers.get(section_name, {})
    if not (section is Dictionary):
        return false
    var raw_effect: Variant = (section as Dictionary).get(String(event_id), (section as Dictionary).get(event_id, null))
    if not (raw_effect is Dictionary):
        return false
    var effect := (raw_effect as Dictionary).duplicate(true)
    var reason := str(effect.get("reason", "%s altered the ecology." % String(event_id)))
    enemy_tier_director.apply_ecology_effect(effect, reason)
    applied_events[unique_key] = true
    return true


func apply_event_for_test(kind: StringName, event_id: StringName) -> bool:
    var section := "operations"
    if kind == &"technology":
        section = "technologies"
    elif kind == &"endgame":
        section = "endgame"
    return _apply_event_once(kind, event_id, section)


func to_dictionary() -> Dictionary:
    var applied: Array[String] = []
    for raw_key in applied_events:
        if bool(applied_events[raw_key]):
            applied.append(str(raw_key))
    applied.sort()
    return {"schema_version": 1, "applied_events": applied}


func restore_from_dictionary(data: Dictionary) -> void:
    applied_events.clear()
    for raw_key in data.get("applied_events", []):
        applied_events[str(raw_key)] = true
