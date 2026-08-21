class_name AdaptiveDefenseDirector3D
extends Node

## Presents one rare Heartforge adaptation proposal after Tier IV. The player
## chooses the principle; machines perform the physical retrofit and retain
## the resulting profile through save/load.

signal proposal_available(summary: String)
signal adaptation_changed(adaptation_id: StringName, state: StringName, detail: String)
signal adaptation_completed(adaptation_id: StringName, display_name: String)

const ADAPTATIONS_PATH := "res://data/heartforge_adaptations.json"
const EVALUATION_INTERVAL_SECONDS := 1.0

var run_state: RunState3D
var progression: ProgressionDirector3D
var region_director: WorldRegionDirector3D
var heartforge: Heartforge3D
var adaptations: Dictionary = {}
var pending_reason: String = ""
var active_adaptation: Dictionary = {}
var completed_adaptation: StringName = &""
var evaluation_clock: float = 0.0
var last_reported_progress: int = -1
var load_errors: Array[String] = []


func configure(
        next_run_state: RunState3D,
        next_progression: ProgressionDirector3D,
        next_region_director: WorldRegionDirector3D,
        next_heartforge: Heartforge3D
    ) -> void:
    run_state = next_run_state
    progression = next_progression
    region_director = next_region_director
    heartforge = next_heartforge


func _ready() -> void:
    _load_adaptations()
    if heartforge != null:
        heartforge.health_changed.connect(_on_heartforge_health_changed)


func _process(delta: float) -> void:
    if not active_adaptation.is_empty():
        _update_active_adaptation(delta)
        return
    if has_pending_proposal() or completed_adaptation != &"":
        return
    evaluation_clock += delta
    if evaluation_clock < EVALUATION_INTERVAL_SECONDS:
        return
    evaluation_clock = 0.0
    evaluate_now()


func _load_adaptations() -> void:
    adaptations.clear()
    load_errors.clear()
    var file := FileAccess.open(ADAPTATIONS_PATH, FileAccess.READ)
    if file == null:
        load_errors.append("Missing %s" % ADAPTATIONS_PATH)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        load_errors.append("Invalid Heartforge adaptation JSON")
        return
    for raw_entry in (parsed as Dictionary).get("adaptations", []):
        if not (raw_entry is Dictionary):
            continue
        var entry := (raw_entry as Dictionary).duplicate(true)
        var adaptation_id := StringName(str(entry.get("id", "")))
        if adaptation_id == &"":
            continue
        adaptations[adaptation_id] = entry


func _on_heartforge_health_changed(current: float, maximum: float) -> void:
    if maximum <= 0.0 or current / maximum > 0.82:
        return
    if not active_adaptation.is_empty() or completed_adaptation != &"":
        return
    evaluate_now()


func adaptation(adaptation_id: StringName) -> Dictionary:
    var raw: Variant = adaptations.get(adaptation_id, {})
    return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func has_pending_proposal() -> bool:
    return not pending_reason.is_empty() and completed_adaptation == &""


func proposal_summary() -> String:
    return pending_reason if has_pending_proposal() else "No adaptive Heartforge proposal is waiting."


func available_plans() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if not has_pending_proposal():
        return result
    for raw_id in adaptations:
        result.append(adaptation(raw_id as StringName))
    result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return str(a.get("display_name", "")) < str(b.get("display_name", ""))
    )
    return result


func evaluate_now() -> bool:
    if progression == null or heartforge == null or completed_adaptation != &"":
        return false
    if not progression.has_effect(&"unlock_adaptive_defence"):
        return false
    if not pending_reason.is_empty() or not active_adaptation.is_empty():
        return false
    var integrity := heartforge.current_health / maxf(1.0, heartforge.maximum_health)
    var pressure := region_director.effective_pressure(&"region.heartforge_district") if region_director != null else 0.0
    if integrity > 0.82 and pressure < 0.65:
        return false
    if integrity <= 0.82:
        pending_reason = "The Heartforge architect found repeated perimeter damage at %d%% integrity and proposes one structural response." % int(round(integrity * 100.0))
    else:
        pending_reason = "The Heartforge architect detected organic pressure at %.0f%% around the district and proposes a quieter defensive principle." % (pressure * 100.0)
    var detail := "Machines will handle geometry, escorts, construction and reconstruction. Choose one principle; this proposal is a rare run-level commitment."
    proposal_available.emit("%s\n%s" % [pending_reason, detail])
    if run_state != null:
        run_state.log_event("Adaptive Heartforge proposal available: %s" % pending_reason)
    return true


func can_authorize(adaptation_id: StringName) -> bool:
    if not has_pending_proposal() or not active_adaptation.is_empty():
        return false
    var entry := adaptation(adaptation_id)
    if entry.is_empty() or run_state == null:
        return false
    return run_state.scrap >= int((entry.get("cost", {}) as Dictionary).get("scrap", 0))


func authorize(adaptation_id: StringName) -> bool:
    if not can_authorize(adaptation_id):
        return false
    var entry := adaptation(adaptation_id)
    var cost := int((entry.get("cost", {}) as Dictionary).get("scrap", 0))
    if not run_state.spend_scrap(cost):
        return false
    active_adaptation = {
        "id": adaptation_id,
        "data": entry,
        "elapsed": 0.0,
    }
    pending_reason = ""
    last_reported_progress = -1
    if heartforge != null:
        heartforge.set_operation(&"heartforge_adaptation")
    adaptation_changed.emit(adaptation_id, &"building", "The machine society is travelling to the Heartforge perimeter to build the selected response.")
    return true


func _update_active_adaptation(delta: float) -> void:
    if active_adaptation.is_empty():
        return
    active_adaptation["elapsed"] = float(active_adaptation.get("elapsed", 0.0)) + maxf(0.0, delta)
    var entry: Dictionary = active_adaptation.get("data", {})
    var duration := maxf(1.0, float(entry.get("build_seconds", 12.0)))
    var adaptation_id := StringName(active_adaptation.get("id", &""))
    var progress_percent := int(round(clampf(float(active_adaptation.get("elapsed", 0.0)) / duration, 0.0, 1.0) * 100.0))
    var progress_report := int(floor(float(progress_percent) / 10.0))
    if progress_report != last_reported_progress:
        last_reported_progress = progress_report
        adaptation_changed.emit(adaptation_id, &"building", "Machines are building %s · %d%%" % [str(entry.get("display_name", String(adaptation_id))), progress_percent])
    if float(active_adaptation.get("elapsed", 0.0)) < duration:
        return
    completed_adaptation = adaptation_id
    pending_reason = ""
    active_adaptation.clear()
    last_reported_progress = -1
    if heartforge != null:
        heartforge.set_adaptation_profile(completed_adaptation)
        heartforge.set_operation(&"")
    var display_name := str(entry.get("display_name", String(completed_adaptation)))
    if run_state != null:
        run_state.log_event("Adaptive Heartforge response completed: %s" % display_name)
    adaptation_changed.emit(completed_adaptation, &"complete", "%s is online. Routine geometry remains machine-managed." % display_name)
    adaptation_completed.emit(completed_adaptation, display_name)


func activity_noise_multiplier() -> float:
    if completed_adaptation == &"":
        return 1.0
    return float(adaptation(completed_adaptation).get("noise_multiplier", 1.0))


func damage_multiplier() -> float:
    if completed_adaptation == &"":
        return 1.0
    return float(adaptation(completed_adaptation).get("damage_multiplier", 1.0))


func to_dictionary() -> Dictionary:
    var serialized_active: Dictionary = {}
    if not active_adaptation.is_empty():
        serialized_active = {
            "id": String(active_adaptation.get("id", &"")),
            "elapsed": float(active_adaptation.get("elapsed", 0.0)),
        }
    return {
        "schema_version": 1,
        "pending_reason": pending_reason,
        "active_adaptation": serialized_active,
        "completed_adaptation": String(completed_adaptation),
    }


func restore_from_dictionary(data: Dictionary) -> void:
    pending_reason = str(data.get("pending_reason", ""))
    completed_adaptation = StringName(str(data.get("completed_adaptation", "")))
    active_adaptation.clear()
    last_reported_progress = -1
    var saved_active: Variant = data.get("active_adaptation", {})
    if saved_active is Dictionary:
        var saved := saved_active as Dictionary
        var adaptation_id := StringName(str(saved.get("id", "")))
        var entry := adaptation(adaptation_id)
        if not entry.is_empty() and completed_adaptation == &"":
            active_adaptation = {
                "id": adaptation_id,
                "data": entry,
                "elapsed": maxf(0.0, float(saved.get("elapsed", 0.0))),
            }
    if heartforge != null:
        if completed_adaptation != &"":
            heartforge.set_adaptation_profile(completed_adaptation)
        elif not active_adaptation.is_empty():
            heartforge.set_operation(&"heartforge_adaptation")
