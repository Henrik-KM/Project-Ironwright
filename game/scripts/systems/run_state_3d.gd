class_name RunState3D
extends Node

signal scrap_changed(total: int)
signal rare_cores_changed(total: int)
signal focus_changed(focus: StringName)
signal robot_level_changed(archetype: StringName, level: int)
signal event_logged(message: String)

const FOCUS_DEFEND: StringName = &"defend"
const FOCUS_SALVAGE: StringName = &"salvage"
const FOCUS_EXPEDITION: StringName = &"expedition"
const ROBOT_ARCHETYPES: Array[StringName] = [
    &"companion",
    &"salvager",
    &"guardian",
    &"scout",
    &"engineer",
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
}
var elapsed_seconds: float = 0.0
var manual_scrap_recovered: int = 0
var autonomous_scrap_recovered: int = 0
var robots_built: int = 1
var expedition_core_recovered: bool = false
var event_log: Array[String] = []


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
    scrap_changed.emit(scrap)


func can_spend_scrap(amount: int) -> bool:
    return amount >= 0 and scrap >= amount


func spend_scrap(amount: int) -> bool:
    if not can_spend_scrap(amount):
        return false
    scrap -= amount
    scrap_changed.emit(scrap)
    return true


func refund_scrap(amount: int) -> void:
    if amount <= 0:
        return
    scrap += amount
    scrap_changed.emit(scrap)


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
        "schema_version": 2,
        "scrap": scrap,
        "rare_cores": rare_cores,
        "focus": String(focus),
        "robot_levels": serialized_levels,
        "elapsed_seconds": elapsed_seconds,
        "manual_scrap_recovered": manual_scrap_recovered,
        "autonomous_scrap_recovered": autonomous_scrap_recovered,
        "robots_built": robots_built,
        "expedition_core_recovered": expedition_core_recovered,
        "event_log": event_log.duplicate(),
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
    event_log.clear()
    for item in data.get("event_log", []):
        event_log.append(str(item))
    scrap_changed.emit(scrap)
    rare_cores_changed.emit(rare_cores)
    focus_changed.emit(focus)
