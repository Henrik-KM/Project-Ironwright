class_name RunVariationDirector3D
extends Node

## Selects one authored, deterministic world condition for a run and applies it
## only to presentation. The selected seed and stable profile ID live in the
## existing run state so save/load never silently changes the town's identity.

const DATA_PATH := "res://data/run_variants.json"

var run_state: RunState3D
var vertical_slice: VerticalSliceDirector3D
var region_atmosphere: RegionAtmosphereDirector3D
var profiles: Dictionary = {}
var _applied_variant_id: StringName = &""


func configure(
        next_run_state: RunState3D,
        next_vertical_slice: VerticalSliceDirector3D,
        next_region_atmosphere: RegionAtmosphereDirector3D
    ) -> void:
    run_state = next_run_state
    vertical_slice = next_vertical_slice
    region_atmosphere = next_region_atmosphere


func _ready() -> void:
    _load_profiles()
    call_deferred("ensure_current_variant")


func ensure_current_variant() -> void:
    if run_state == null:
        return
    var ids := profile_ids()
    if ids.is_empty():
        push_error("Run variation data contains no usable profiles.")
        return
    run_state.ensure_world_variant(ids)
    apply_current()


func apply_current() -> void:
    if run_state == null:
        return
    var variant_id := run_state.world_variant_id
    var profile: Dictionary = profiles.get(variant_id, {})
    if profile.is_empty():
        # Older saves predate authored run variation and have no variant ID.
        # Reconcile them through the same deterministic seed path used by a
        # new run instead of applying an empty profile and leaving the load in
        # a partially restored presentation state.
        var ids := profile_ids()
        if ids.is_empty():
            push_error("Run variation profile is missing and no fallback profiles are available: %s" % String(variant_id))
            return
        run_state.ensure_world_variant(ids)
        variant_id = run_state.world_variant_id
        profile = profiles.get(variant_id, {})
        if profile.is_empty():
            push_error("Run variation fallback profile is missing: %s" % String(variant_id))
            return
    var normalized := profile.duplicate(true)
    normalized["rain_color"] = Color(str(profile.get("rain_color", "#7895a3")))
    if vertical_slice != null:
        vertical_slice.apply_weather_profile(normalized)
    if region_atmosphere != null:
        region_atmosphere.apply_run_variation(normalized)
    if _applied_variant_id != variant_id:
        _applied_variant_id = variant_id
        run_state.log_event("World condition: %s — %s" % [str(profile.get("display_name", String(variant_id))), str(profile.get("description", ""))])


func profile_ids() -> Array[StringName]:
    var ids: Array[StringName] = []
    for raw_id in profiles.keys():
        ids.append(raw_id as StringName)
    ids.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
    return ids


func current_display_name() -> String:
    if run_state == null:
        return ""
    return str((profiles.get(run_state.world_variant_id, {}) as Dictionary).get("display_name", String(run_state.world_variant_id)))


func current_profile() -> Dictionary:
    if run_state == null:
        return {}
    return (profiles.get(run_state.world_variant_id, {}) as Dictionary).duplicate(true)


func _load_profiles() -> void:
    profiles.clear()
    if not FileAccess.file_exists(DATA_PATH):
        push_error("Run variation data is missing: %s" % DATA_PATH)
        return
    var file := FileAccess.open(DATA_PATH, FileAccess.READ)
    if file == null:
        push_error("Run variation data could not be opened: %s" % DATA_PATH)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        push_error("Run variation data is not a JSON object: %s" % DATA_PATH)
        return
    var entries: Variant = (parsed as Dictionary).get("variants", [])
    if not (entries is Array):
        push_error("Run variation data has no variants array: %s" % DATA_PATH)
        return
    for entry in entries:
        if not (entry is Dictionary):
            continue
        var profile := (entry as Dictionary).duplicate(true)
        var raw_id := str(profile.get("id", ""))
        if raw_id.is_empty():
            continue
        profiles[StringName(raw_id)] = profile
