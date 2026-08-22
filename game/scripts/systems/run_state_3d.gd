class_name RunState3D
extends Node

signal scrap_changed(total: int)
signal rare_cores_changed(total: int)
signal focus_changed(focus: StringName)
signal robot_level_changed(archetype: StringName, level: int)
signal event_logged(message: String)
signal world_variant_changed(variant_id: StringName)

const FOCUS_DEFEND: StringName = &"defend"
const FOCUS_SALVAGE: StringName = &"salvage"
const FOCUS_EXPEDITION: StringName = &"expedition"
const ROBOT_ARCHETYPES: Array[StringName] = [
    &"companion",
    &"salvager",
    &"guardian",
    &"scout",
    &"engineer",
    &"relay",
]

var scrap: int = 24
var rare_cores: int = 0
var focus: StringName = FOCUS_DEFEND
var robot_levels: Dictionary = {
    &"companion": 1,
    &"salvager": 1,
    &"guardian": 1,
    &"scout": 1,
    &"engineer": 1,
    &"relay": 1,
}
var elapsed_seconds: float = 0.0
var manual_scrap_recovered: int = 0
var autonomous_scrap_recovered: int = 0
var robots_built: int = 1
var expedition_core_recovered: bool = false
var event_log: Array[String] = []
var world_seed: int = 0
var world_variant_id: StringName = &""
var observed_species: Dictionary = {}
var first_sustained_resource_decline: Dictionary = {}
var scrap_high_water_mark: int = 24
var last_scrap_total: int = 24
var scrap_decline_steps: int = 0


func _process(delta: float) -> void:
    elapsed_seconds += delta


func add_scrap(amount: int, autonomous: bool = false) -> void:
    if amount <= 0:
        return
    scrap += amount
    if autonomous:
        autonomous_scrap_recovered += amount
    else:
        manual_scrap_recovered += amount
    _track_scrap_balance("recovery")
    scrap_changed.emit(scrap)


func can_spend_scrap(amount: int) -> bool:
    return amount >= 0 and scrap >= amount


func spend_scrap(amount: int) -> bool:
    if not can_spend_scrap(amount):
        return false
    scrap -= amount
    _track_scrap_balance("spending")
    scrap_changed.emit(scrap)
    return true


func refund_scrap(amount: int) -> void:
    if amount <= 0:
        return
    scrap += amount
    _track_scrap_balance("recovery")
    scrap_changed.emit(scrap)


func record_scrap_spend(amount: int, cause: String = "spending") -> void:
    if amount <= 0:
        return
    _track_scrap_balance(cause)


func observe_organic_species(species: StringName, behaviour: StringName, region_id: StringName = &"") -> void:
    if species == &"":
        return
    var key := String(species)
    var entry: Dictionary = observed_species.get(key, {
        "species": key,
        "behaviours": [],
        "regions": [],
        "first_observed_seconds": elapsed_seconds,
    })
    var behaviours: Array = entry.get("behaviours", [])
    var behaviour_name := String(behaviour)
    if behaviour_name != "" and behaviour_name not in behaviours:
        behaviours.append(behaviour_name)
    var regions: Array = entry.get("regions", [])
    var region_name := String(region_id)
    if region_name != "" and region_name not in regions:
        regions.append(region_name)
    entry["behaviours"] = behaviours
    entry["regions"] = regions
    observed_species[key] = entry


func observed_species_report(limit: int = 6) -> String:
    if observed_species.is_empty():
        return "No species had been persistently identified before collapse."
    var keys: Array[String] = []
    for raw_key in observed_species:
        keys.append(str(raw_key))
    keys.sort()
    var lines: Array[String] = []
    for key in keys.slice(0, maxi(1, limit)):
        var entry: Dictionary = observed_species.get(key, {})
        var behaviours: Array[String] = []
        for raw_behaviour in entry.get("behaviours", []):
            behaviours.append(str(raw_behaviour).replace("_", " "))
        var display_name: String = key.replace("_", " ").capitalize()
        var behaviour_text := ", ".join(behaviours.slice(0, 3)) if not behaviours.is_empty() else "unclassified movement"
        lines.append("%s [%s]" % [display_name, behaviour_text])
    if keys.size() > limit:
        lines.append("+%d more" % (keys.size() - limit))
    return "; ".join(lines)


func resource_decline_report() -> String:
    if first_sustained_resource_decline.is_empty():
        return "No sustained resource decline was recorded."
    var world_time := int(round(float(first_sustained_resource_decline.get("world_time", 0.0))))
    var minutes := world_time / 60
    var cause := str(first_sustained_resource_decline.get("cause", "spending"))
    return "at %dm · peak %d to %d Scrap · %s" % [minutes, int(first_sustained_resource_decline.get("peak", 0)), int(first_sustained_resource_decline.get("remaining", 0)), cause]


func _track_scrap_balance(cause: String) -> void:
    if scrap > scrap_high_water_mark:
        scrap_high_water_mark = scrap
        scrap_decline_steps = 0
    elif scrap < last_scrap_total:
        scrap_decline_steps += 1
    if first_sustained_resource_decline.is_empty() and scrap_high_water_mark - scrap >= 60 and scrap_decline_steps >= 3:
        first_sustained_resource_decline = {
            "world_time": elapsed_seconds,
            "peak": scrap_high_water_mark,
            "remaining": scrap,
            "cause": cause,
        }
        log_event("RESOURCE DECLINE · Scrap fell from %d to %d after sustained %s." % [scrap_high_water_mark, scrap, cause])
    last_scrap_total = scrap


func add_rare_core(amount: int = 1) -> void:
    rare_cores += maxi(0, amount)
    expedition_core_recovered = rare_cores > 0 or expedition_core_recovered
    rare_cores_changed.emit(rare_cores)


func spend_rare_cores(amount: int) -> bool:
    if amount < 0 or rare_cores < amount:
        return false
    rare_cores -= amount
    rare_cores_changed.emit(rare_cores)
    return true


func set_focus(next_focus: StringName) -> void:
    if next_focus not in [FOCUS_DEFEND, FOCUS_SALVAGE, FOCUS_EXPEDITION]:
        return
    if focus == next_focus:
        return
    focus = next_focus
    focus_changed.emit(focus)
    log_event("Machine focus: %s" % String(focus).capitalize())


func ensure_world_variant(variant_ids: Array[StringName], seed_override: int = 0) -> void:
    if variant_ids.is_empty():
        return
    if world_seed == 0:
        world_seed = seed_override if seed_override != 0 else _new_world_seed()
    if world_variant_id == &"" or world_variant_id not in variant_ids:
        world_variant_id = variant_ids[posmod(world_seed, variant_ids.size())]
        world_variant_changed.emit(world_variant_id)


func set_world_variant(variant_id: StringName, seed: int) -> void:
    if variant_id == &"" or seed == 0:
        return
    world_seed = seed
    if world_variant_id == variant_id:
        return
    world_variant_id = variant_id
    world_variant_changed.emit(world_variant_id)


func _new_world_seed() -> int:
    return int(Time.get_unix_time_from_system()) ^ int(Time.get_ticks_usec())


func build_cost(archetype: StringName) -> int:
    match archetype:
        &"salvager":
            return 42
        &"guardian":
            return 68
        &"scout":
            return 58
        &"engineer":
            return 56
        &"companion":
            return 90
        &"relay":
            return 126
        _:
            return 9999


func build_time(archetype: StringName) -> float:
    match archetype:
        &"salvager":
            return 6.5
        &"guardian":
            return 8.0
        &"scout":
            return 7.2
        &"engineer":
            return 7.6
        &"companion":
            return 9.5
        &"relay":
            return 10.8
        _:
            return 10.0


func upgrade_cost(archetype: StringName) -> Dictionary:
    var current_level := int(robot_levels.get(archetype, 1))
    if current_level >= 3:
        return {"scrap": 0, "cores": 0, "available": false}
    if current_level == 1:
        return {"scrap": 85, "cores": 0, "available": true}
    return {"scrap": 155, "cores": 1, "available": true}


func can_upgrade(archetype: StringName) -> bool:
    var cost := upgrade_cost(archetype)
    return (
        bool(cost.get("available", false))
        and scrap >= int(cost.get("scrap", 0))
        and rare_cores >= int(cost.get("cores", 0))
    )


func purchase_upgrade(archetype: StringName) -> bool:
    if not can_upgrade(archetype):
        return false
    var cost := upgrade_cost(archetype)
    scrap -= int(cost.get("scrap", 0))
    _track_scrap_balance("upgrade")
    rare_cores -= int(cost.get("cores", 0))
    var next_level := int(robot_levels.get(archetype, 1)) + 1
    robot_levels[archetype] = next_level
    scrap_changed.emit(scrap)
    rare_cores_changed.emit(rare_cores)
    robot_level_changed.emit(archetype, next_level)
    log_event("%s frames upgraded to level %d" % [String(archetype).capitalize(), next_level])
    return true


func level_for(archetype: StringName) -> int:
    return int(robot_levels.get(archetype, 1))


func log_event(message: String) -> void:
    event_log.push_front(message)
    if event_log.size() > 48:
        event_log.resize(48)
    event_logged.emit(message)


func to_dictionary() -> Dictionary:
    var serialized_levels: Dictionary = {}
    for archetype in ROBOT_ARCHETYPES:
        serialized_levels[String(archetype)] = int(robot_levels.get(archetype, 1))
    return {
        "schema_version": 4,
        "scrap": scrap,
        "rare_cores": rare_cores,
        "focus": String(focus),
        "robot_levels": serialized_levels,
        "elapsed_seconds": elapsed_seconds,
        "manual_scrap_recovered": manual_scrap_recovered,
        "autonomous_scrap_recovered": autonomous_scrap_recovered,
        "robots_built": robots_built,
        "expedition_core_recovered": expedition_core_recovered,
        "world_seed": world_seed,
        "world_variant_id": String(world_variant_id),
        "event_log": event_log.duplicate(),
        "observed_species": observed_species.duplicate(true),
        "first_sustained_resource_decline": first_sustained_resource_decline.duplicate(true),
        "scrap_high_water_mark": scrap_high_water_mark,
        "last_scrap_total": last_scrap_total,
        "scrap_decline_steps": scrap_decline_steps,
    }


func restore_from_dictionary(data: Dictionary) -> void:
    scrap = int(data.get("scrap", scrap))
    rare_cores = int(data.get("rare_cores", rare_cores))
    focus = StringName(str(data.get("focus", String(focus))))
    var saved_levels: Dictionary = data.get("robot_levels", {})
    for archetype in ROBOT_ARCHETYPES:
        robot_levels[archetype] = clampi(int(saved_levels.get(String(archetype), saved_levels.get(archetype, 1))), 1, 3)
    elapsed_seconds = float(data.get("elapsed_seconds", 0.0))
    manual_scrap_recovered = int(data.get("manual_scrap_recovered", 0))
    autonomous_scrap_recovered = int(data.get("autonomous_scrap_recovered", 0))
    robots_built = int(data.get("robots_built", 1))
    expedition_core_recovered = bool(data.get("expedition_core_recovered", false))
    world_seed = int(data.get("world_seed", 0))
    world_variant_id = StringName(str(data.get("world_variant_id", "")))
    observed_species.clear()
    var saved_observed_species: Variant = data.get("observed_species", {})
    if saved_observed_species is Dictionary:
        observed_species = (saved_observed_species as Dictionary).duplicate(true)
    var saved_decline: Variant = data.get("first_sustained_resource_decline", {})
    first_sustained_resource_decline = (saved_decline as Dictionary).duplicate(true) if saved_decline is Dictionary else {}
    scrap_high_water_mark = maxi(scrap, int(data.get("scrap_high_water_mark", scrap)))
    last_scrap_total = int(data.get("last_scrap_total", scrap))
    scrap_decline_steps = maxi(0, int(data.get("scrap_decline_steps", 0)))
    event_log.clear()
    for item in data.get("event_log", []):
        event_log.append(str(item))
    scrap_changed.emit(scrap)
    rare_cores_changed.emit(rare_cores)
    focus_changed.emit(focus)
