class_name ProgressionDirector3D
extends Node

signal phase_changed(phase_id: StringName, display_name: String)
signal technology_unlocked(technology_id: StringName, display_name: String, effects: Array)
signal heartforge_tier_changed(tier: int)
signal progression_changed

const TECHNOLOGY_PATH := "res://data/technology_tree.json"
const PHASE_PATH := "res://data/progression_phases.json"

var run_state: RunState3D
var context_provider: Callable
var heartforge_tier: int = 1
var current_phase: StringName = &"embers"
var unlocked_technologies: Array[StringName] = []
var unlocked_effects: Dictionary = {}
var technologies: Dictionary = {}
var phases: Array[Dictionary] = []
var evaluation_clock: float = 0.0
var content_errors: Array[String] = []


func configure(next_run_state: RunState3D) -> void:
    run_state = next_run_state


func set_context_provider(provider: Callable) -> void:
    context_provider = provider
    _evaluate_automatic_technologies()
    _refresh_phase()


func _ready() -> void:
    _load_content()
    _evaluate_automatic_technologies()
    _refresh_phase()


func _process(delta: float) -> void:
    if run_state == null:
        return
    evaluation_clock += delta
    if evaluation_clock < 0.5:
        return
    evaluation_clock = 0.0
    _evaluate_automatic_technologies()
    _refresh_phase()


func _load_content() -> void:
    technologies.clear()
    phases.clear()
    content_errors.clear()

    var technology_data := _load_json_dictionary(TECHNOLOGY_PATH)
    var technology_entries: Array = technology_data.get("technologies", [])
    for raw_entry in technology_entries:
        if not (raw_entry is Dictionary):
            content_errors.append("Technology entry is not an object.")
            continue
        var entry := raw_entry as Dictionary
        var identifier := StringName(str(entry.get("id", "")))
        if identifier == &"":
            content_errors.append("Technology entry has no stable id.")
            continue
        technologies[identifier] = entry.duplicate(true)

    var phase_data := _load_json_dictionary(PHASE_PATH)
    var phase_entries: Array = phase_data.get("phases", [])
    for raw_phase in phase_entries:
        if raw_phase is Dictionary:
            phases.append((raw_phase as Dictionary).duplicate(true))

    if technologies.is_empty():
        content_errors.append("No technologies were loaded.")
    if phases.is_empty():
        content_errors.append("No progression phases were loaded.")


func _load_json_dictionary(path: String) -> Dictionary:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        content_errors.append("Missing content file: %s" % path)
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        content_errors.append("Invalid JSON object: %s" % path)
        return {}
    return parsed as Dictionary


func has_technology(technology_id: StringName) -> bool:
    return technology_id in unlocked_technologies


func has_effect(effect_id: StringName) -> bool:
    return bool(unlocked_effects.get(effect_id, false))


func modifier_value(modifier_id: StringName, fallback: float = 0.0) -> float:
    var total := fallback
    for technology_id in unlocked_technologies:
        var entry := technology(technology_id)
        var modifiers: Dictionary = entry.get("modifiers", {})
        total += float(modifiers.get(String(modifier_id), modifiers.get(modifier_id, 0.0)))
    return total


func technology(technology_id: StringName) -> Dictionary:
    var raw: Variant = technologies.get(technology_id, {})
    return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func available_technologies() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for technology_id in technologies:
        var identifier := technology_id as StringName
        if has_technology(identifier):
            continue
        var entry := technology(identifier)
        if bool(entry.get("automatic", false)):
            continue
        if _exclusive_group_locked(entry):
            continue
        if requirements_met(entry):
            result.append(entry)
    result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return str(a.get("display_name", "")) < str(b.get("display_name", ""))
    )
    return result


func requirements_met(entry: Dictionary) -> bool:
    if run_state == null:
        return false
    var requirements: Dictionary = entry.get("requirements", {})
    var context := _current_context()

    if requirements.has("manual_scrap_recovered"):
        if run_state.manual_scrap_recovered < int(requirements["manual_scrap_recovered"]):
            return false
    if requirements.has("robots_built"):
        if run_state.robots_built < int(requirements["robots_built"]):
            return false
    if requirements.has("technology"):
        if not has_technology(StringName(str(requirements["technology"]))):
            return false
    if requirements.has("technologies_all"):
        for raw_technology in requirements["technologies_all"]:
            if not has_technology(StringName(str(raw_technology))):
                return false
    if requirements.has("expedition_core_recovered"):
        if bool(requirements["expedition_core_recovered"]) and not run_state.expedition_core_recovered:
            return false
    if requirements.has("heartforge_tier"):
        if heartforge_tier < int(requirements["heartforge_tier"]):
            return false
    if requirements.has("completed_operation"):
        var completed: Array = context.get("completed_operations", [])
        if str(requirements["completed_operation"]) not in completed:
            return false
    if requirements.has("completed_operations_all"):
        var completed_all: Array = context.get("completed_operations", [])
        for raw_operation in requirements["completed_operations_all"]:
            if str(raw_operation) not in completed_all:
                return false
    if requirements.has("components_min"):
        if int(context.get("components_count", 0)) < int(requirements["components_min"]):
            return false
    if requirements.has("functioning_outposts_min"):
        if int(context.get("functioning_outposts", 0)) < int(requirements["functioning_outposts_min"]):
            return false
    if requirements.has("regions_discovered_min"):
        if int(context.get("regions_discovered_count", 0)) < int(requirements["regions_discovered_min"]):
            return false
    if requirements.has("region_discovered"):
        var discovered: Array = context.get("regions_discovered", [])
        if str(requirements["region_discovered"]) not in discovered:
            return false
    return true


func _current_context() -> Dictionary:
    if context_provider.is_valid():
        var value: Variant = context_provider.call()
        if value is Dictionary:
            return (value as Dictionary).duplicate(true)
    return {}


func can_purchase(technology_id: StringName) -> bool:
    if run_state == null or has_technology(technology_id):
        return false
    var entry := technology(technology_id)
    if entry.is_empty() or bool(entry.get("automatic", false)):
        return false
    if _exclusive_group_locked(entry):
        return false
    if not requirements_met(entry):
        return false
    var cost: Dictionary = entry.get("cost", {})
    return (
        run_state.scrap >= int(cost.get("scrap", 0))
        and run_state.rare_cores >= int(cost.get("rare_cores", 0))
    )


func purchase(technology_id: StringName) -> bool:
    if not can_purchase(technology_id):
        return false
    var entry := technology(technology_id)
    var cost: Dictionary = entry.get("cost", {})
    var scrap_cost := int(cost.get("scrap", 0))
    var core_cost := int(cost.get("rare_cores", 0))
    if not run_state.spend_scrap(scrap_cost):
        return false
    if not run_state.spend_rare_cores(core_cost):
        run_state.refund_scrap(scrap_cost)
        return false
    _unlock(entry)
    return true


func active_doctrine_id() -> StringName:
    for technology_id in unlocked_technologies:
        var entry := technology(technology_id)
        if str(entry.get("exclusive_group", "")) == "machine_doctrine":
            return technology_id
    return &""


func active_doctrine_display_name() -> String:
    var identifier := active_doctrine_id()
    if identifier == &"":
        return "Uncommitted"
    return str(technology(identifier).get("display_name", String(identifier)))


func has_doctrine(effect_id: StringName) -> bool:
    return has_effect(effect_id)


func _exclusive_group_locked(entry: Dictionary) -> bool:
    var group := str(entry.get("exclusive_group", ""))
    if group.is_empty():
        return false
    for technology_id in unlocked_technologies:
        var unlocked_entry := technology(technology_id)
        if str(unlocked_entry.get("exclusive_group", "")) == group:
            return true
    return false


func _evaluate_automatic_technologies() -> void:
    for technology_id in technologies:
        var identifier := technology_id as StringName
        if has_technology(identifier):
            continue
        var entry := technology(identifier)
        if not bool(entry.get("automatic", false)):
            continue
        if requirements_met(entry):
            _unlock(entry)


func _unlock(entry: Dictionary) -> void:
    var technology_id := StringName(str(entry.get("id", "")))
    if technology_id == &"" or has_technology(technology_id):
        return
    unlocked_technologies.append(technology_id)

    var effects: Array = entry.get("effects", [])
    for raw_effect in effects:
        var effect_id := StringName(str(raw_effect))
        unlocked_effects[effect_id] = true
        if effect_id == &"heartforge_tier_2":
            set_heartforge_tier(maxi(heartforge_tier, 2))
        elif effect_id == &"heartforge_tier_3":
            set_heartforge_tier(maxi(heartforge_tier, 3))
        elif effect_id == &"heartforge_tier_4":
            set_heartforge_tier(maxi(heartforge_tier, 4))
        elif effect_id == &"heartforge_tier_5":
            set_heartforge_tier(maxi(heartforge_tier, 5))

    var display_name := str(entry.get("display_name", String(technology_id)))
    if run_state != null:
        run_state.log_event("Technology unlocked: %s" % display_name)
    technology_unlocked.emit(technology_id, display_name, effects.duplicate())
    progression_changed.emit()
    _refresh_phase()


func set_heartforge_tier(next_tier: int) -> void:
    var clamped := clampi(next_tier, 1, 5)
    if clamped == heartforge_tier:
        return
    heartforge_tier = clamped
    heartforge_tier_changed.emit(heartforge_tier)
    progression_changed.emit()
    _refresh_phase()


func maximum_outpost_tier() -> int:
    if heartforge_tier < 2:
        return 0
    return mini(3, heartforge_tier)


func _refresh_phase() -> void:
    if phases.is_empty():
        return
    var selected: Dictionary = phases[0]
    for phase in phases:
        if heartforge_tier >= int(phase.get("heartforge_tier_min", 1)):
            selected = phase
    var next_phase := StringName(str(selected.get("id", "embers")))
    if next_phase == current_phase:
        return
    current_phase = next_phase
    phase_changed.emit(current_phase, str(selected.get("display_name", String(current_phase))))
    progression_changed.emit()


func current_phase_data() -> Dictionary:
    for phase in phases:
        if StringName(str(phase.get("id", ""))) == current_phase:
            return phase.duplicate(true)
    return {}


func to_dictionary() -> Dictionary:
    var serialized_technologies: Array[String] = []
    for technology_id in unlocked_technologies:
        serialized_technologies.append(String(technology_id))
    return {
        "schema_version": 3,
        "heartforge_tier": heartforge_tier,
        "current_phase": String(current_phase),
        "unlocked_technologies": serialized_technologies,
    }


func restore_from_dictionary(data: Dictionary) -> void:
    heartforge_tier = clampi(int(data.get("heartforge_tier", 1)), 1, 5)
    current_phase = StringName(str(data.get("current_phase", "embers")))
    unlocked_technologies.clear()
    unlocked_effects.clear()
    for raw_identifier in data.get("unlocked_technologies", []):
        var identifier := StringName(str(raw_identifier))
        var entry := technology(identifier)
        if entry.is_empty():
            continue
        unlocked_technologies.append(identifier)
        for raw_effect in entry.get("effects", []):
            unlocked_effects[StringName(str(raw_effect))] = true
    heartforge_tier_changed.emit(heartforge_tier)
    progression_changed.emit()
    _evaluate_automatic_technologies()
    _refresh_phase()
