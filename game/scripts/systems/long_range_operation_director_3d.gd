class_name LongRangeOperationDirector3D
extends Node

signal operation_changed(operation_id: StringName, state: StringName, detail: String)
signal operation_returned(operation_id: StringName, display_name: String, rewards: Dictionary)
signal component_recovered(component_id: StringName)
signal site_discovery_requested(site_id: StringName)

const OPERATIONS_PATH := "res://data/strategic_operations.json"

var run_state: RunState3D
var progression: ProgressionDirector3D
var region_director: WorldRegionDirector3D
var noise_system: NoiseSystem3D
var autonomy_director: AutonomyDirector3D
var outpost_director: OutpostDirector3D
var heartforge: Heartforge3D
var spawn_enemy_callback: Callable
var operations: Dictionary = {}
var completed_operations: Array[StringName] = []
var recovered_components: Array[StringName] = []
var active_operation: Dictionary = {}
var load_errors: Array[String] = []
var threat_serial: int = 0
var endgame_pressure_reduction: float = 0.0


func configure(
        next_run_state: RunState3D,
        next_progression: ProgressionDirector3D,
        next_region_director: WorldRegionDirector3D,
        next_noise_system: NoiseSystem3D,
        next_autonomy_director: AutonomyDirector3D,
        next_outpost_director: OutpostDirector3D,
        next_heartforge: Heartforge3D,
        next_spawn_enemy_callback: Callable
    ) -> void:
    run_state = next_run_state
    progression = next_progression
    region_director = next_region_director
    noise_system = next_noise_system
    autonomy_director = next_autonomy_director
    outpost_director = next_outpost_director
    heartforge = next_heartforge
    spawn_enemy_callback = next_spawn_enemy_callback


func _ready() -> void:
    _load_operations()


func _process(delta: float) -> void:
    if active_operation.is_empty():
        return
    _update_active_operation(delta)


func _load_operations() -> void:
    operations.clear()
    load_errors.clear()
    var file := FileAccess.open(OPERATIONS_PATH, FileAccess.READ)
    if file == null:
        load_errors.append("Missing %s" % OPERATIONS_PATH)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        load_errors.append("Invalid operations JSON")
        return
    for raw_entry in (parsed as Dictionary).get("operations", []):
        if not (raw_entry is Dictionary):
            continue
        var entry := (raw_entry as Dictionary).duplicate(true)
        var operation_id := StringName(str(entry.get("id", "")))
        if operation_id == &"":
            load_errors.append("Operation without stable id")
            continue
        operations[operation_id] = entry


func operation(operation_id: StringName) -> Dictionary:
    var raw: Variant = operations.get(operation_id, {})
    return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func has_completed(operation_id: StringName) -> bool:
    return operation_id in completed_operations


func component_count() -> int:
    return recovered_components.size()


func has_component(component_id: StringName) -> bool:
    return component_id in recovered_components


func available_operations() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for raw_id in operations:
        var operation_id := raw_id as StringName
        if has_completed(operation_id):
            continue
        var entry := operation(operation_id)
        if requirements_met(entry):
            result.append(entry)
    result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return str(a.get("display_name", "")) < str(b.get("display_name", ""))
    )
    return result


func requirements_met(entry: Dictionary) -> bool:
    if progression == null or run_state == null:
        return false
    var requirements: Dictionary = entry.get("requirements", {})
    if progression.heartforge_tier < int(requirements.get("heartforge_tier", 1)):
        return false
    if requirements.has("technology"):
        if not progression.has_technology(StringName(str(requirements["technology"]))):
            return false
    if requirements.has("completed_operation"):
        if not has_completed(StringName(str(requirements["completed_operation"]))):
            return false
    if requirements.has("components_min") and component_count() < int(requirements["components_min"]):
        return false
    if requirements.has("functioning_outposts_min"):
        if _functioning_outpost_count() < int(requirements["functioning_outposts_min"]):
            return false
    return true


func can_authorize(operation_id: StringName) -> bool:
    if not active_operation.is_empty() or _other_operation_active():
        return false
    if has_completed(operation_id):
        return false
    var entry := operation(operation_id)
    if entry.is_empty() or not requirements_met(entry):
        return false
    if run_state.scrap < int(entry.get("scrap_cost", 0)):
        return false
    return not _select_team(entry.get("team_roles", [])).is_empty()


func authorize(operation_id: StringName) -> bool:
    if not can_authorize(operation_id):
        return false
    var entry := operation(operation_id)
    var team := _select_team(entry.get("team_roles", []))
    if team.is_empty():
        return false
    var scrap_cost := int(entry.get("scrap_cost", 0))
    if not run_state.spend_scrap(scrap_cost):
        return false

    var region_id := StringName(str(entry.get("region_id", "region.heartforge_district")))
    var route := region_director.route_from_heartforge(region_id, heartforge.global_position)
    for index in range(team.size()):
        team[index].set_group(&"long_range_operation", index)

    active_operation = {
        "id": operation_id,
        "data": entry,
        "state": &"outbound",
        "members": team,
        "region_id": region_id,
        "route": route,
        "route_index": 1,
        "anchor": heartforge.global_position,
        "last_forward": Vector3(0.0, 0.0, -1.0),
        "work_clock": 0.0,
        "noise_clock": 0.0,
        "threat_clock": 0.0,
        "pending_rewards": {},
    }
    autonomy_director.set_process(false)
    if outpost_director != null:
        outpost_director.set_process(false)
    _hold_nonmembers_at_home(team)
    operation_changed.emit(operation_id, &"outbound", "%s has departed as a cohesive physical group." % str(entry.get("display_name", String(operation_id))))
    return true


func _update_active_operation(delta: float) -> void:
    var members := _living_members()
    if members.is_empty():
        _abort("Every machine assigned to the operation was lost in the persistent world.")
        return

    var state := StringName(active_operation.get("state", &"outbound"))
    if state == &"working":
        _update_work(delta)
        _position_members(0.0)
        return

    var route: PackedVector3Array = active_operation.get("route", PackedVector3Array())
    var route_index := int(active_operation.get("route_index", 1))
    if route.is_empty() or route_index >= route.size():
        if state == &"outbound":
            active_operation["state"] = &"working"
            active_operation["work_clock"] = 0.0
            active_operation["noise_clock"] = 0.0
            active_operation["threat_clock"] = 0.0
            var operation_id := StringName(active_operation.get("id", &""))
            operation_changed.emit(operation_id, &"working", "The entire group arrived and began the objective under escort.")
        else:
            _complete_return()
        return

    var anchor: Vector3 = active_operation.get("anchor", heartforge.global_position)
    var waypoint: Vector3 = route[route_index]
    var direction := waypoint - anchor
    direction.y = 0.0
    if direction.length() <= 0.75:
        active_operation["route_index"] = route_index + 1
        return
    direction = direction.normalized()
    active_operation["last_forward"] = direction

    var separation := _maximum_separation(anchor, members)
    var pace_multiplier := FormationRules3D.pace_multiplier(separation)
    if _hostile_near(anchor, 10.0):
        pace_multiplier = 0.0
    var pace := _group_pace(members) * pace_multiplier
    anchor += direction * pace * delta
    active_operation["anchor"] = anchor
    _position_members(pace)


func _position_members(group_speed: float) -> void:
    var members := _living_members()
    var anchor: Vector3 = active_operation.get("anchor", heartforge.global_position)
    var forward: Vector3 = active_operation.get("last_forward", Vector3.FORWARD)
    var operation_name := str((active_operation.get("data", {}) as Dictionary).get("display_name", "operation"))
    for index in range(members.size()):
        var robot := members[index]
        var offset := FormationRules3D.formation_offset(index, robot.archetype)
        if robot.archetype == &"salvager" or robot.archetype == &"engineer":
            offset.z += 1.4
        var destination := anchor + FormationRules3D.rotated_offset(offset, forward)
        robot.set_goal(
            destination,
            "Maintaining the %s formation; escorts screen vulnerable work frames and the group regroups rather than abandoning stragglers." % operation_name,
            maxf(1.5, group_speed + 1.0)
        )


func _update_work(delta: float) -> void:
    var entry: Dictionary = active_operation.get("data", {})
    var operation_id := StringName(active_operation.get("id", &""))
    var region_id := StringName(active_operation.get("region_id", &"region.heartforge_district"))
    active_operation["work_clock"] = float(active_operation.get("work_clock", 0.0)) + delta
    active_operation["noise_clock"] = float(active_operation.get("noise_clock", 0.0)) + delta
    active_operation["threat_clock"] = float(active_operation.get("threat_clock", 0.0)) + delta

    if float(active_operation.get("noise_clock", 0.0)) >= 1.2:
        active_operation["noise_clock"] = 0.0
        if noise_system != null:
            noise_system.emit_noise(
                region_director.center(region_id),
                float(entry.get("noise_radius", 35.0)),
                minf(1.8, 0.7 + float(entry.get("threat_level", 1.0)) * 0.28),
                &"strategic_operation"
            )
        region_director.add_pressure(region_id, 0.0035 * float(entry.get("threat_level", 1.0)))

    var threat_interval := maxf(4.5, 9.5 - float(entry.get("threat_level", 1.0)) * 1.4)
    if float(active_operation.get("threat_clock", 0.0)) >= threat_interval:
        active_operation["threat_clock"] = 0.0
        _spawn_work_threat(region_id, float(entry.get("threat_level", 1.0)))

    if float(active_operation.get("work_clock", 0.0)) < float(entry.get("work_seconds", 14.0)):
        return
    active_operation["pending_rewards"] = (entry.get("rewards", {}) as Dictionary).duplicate(true)
    operation_changed.emit(operation_id, &"secured", "The objective is secured. Rewards remain with the group until it physically returns.")
    _begin_return()


func _begin_return() -> void:
    active_operation["state"] = &"returning"
    var route: PackedVector3Array = active_operation.get("route", PackedVector3Array())
    var reversed := PackedVector3Array()
    for index in range(route.size() - 1, -1, -1):
        reversed.append(route[index])
    active_operation["route"] = reversed
    active_operation["route_index"] = 1
    active_operation["anchor"] = region_director.center(StringName(active_operation.get("region_id", &"region.heartforge_district")))
    active_operation["last_forward"] = Vector3(0.0, 0.0, 1.0)
    operation_changed.emit(StringName(active_operation.get("id", &"")), &"returning", "The machines are returning through the same physical streets with the secured objective.")


func _complete_return() -> void:
    var operation_id := StringName(active_operation.get("id", &""))
    var entry: Dictionary = active_operation.get("data", {})
    var rewards: Dictionary = active_operation.get("pending_rewards", {})
    _apply_rewards(rewards)
    if operation_id not in completed_operations:
        completed_operations.append(operation_id)
    for robot in _living_members():
        robot.set_group(&"reserve", 0)
        robot.set_goal(heartforge.global_position, "The long-range objective is complete; returning to the general autonomous machine pool.", robot.move_speed * 0.72)
    active_operation.clear()
    autonomy_director.set_process(true)
    if outpost_director != null:
        outpost_director.set_process(true)
    run_state.log_event("Long-range operation complete: %s" % str(entry.get("display_name", String(operation_id))))
    operation_returned.emit(operation_id, str(entry.get("display_name", String(operation_id))), rewards.duplicate(true))
    operation_changed.emit(operation_id, &"complete", "The complete group returned to the Heartforge and delivered the objective.")


func _apply_rewards(rewards: Dictionary) -> void:
    if rewards.has("rare_cores"):
        run_state.add_rare_core(int(rewards["rare_cores"]))
    if rewards.has("component"):
        var component_id := StringName(str(rewards["component"]))
        if component_id != &"" and component_id not in recovered_components:
            recovered_components.append(component_id)
            component_recovered.emit(component_id)
    if rewards.has("discover_region"):
        region_director.discover_region(StringName(str(rewards["discover_region"])))
    if rewards.has("discover_sites"):
        for raw_site in rewards["discover_sites"]:
            site_discovery_requested.emit(StringName(str(raw_site)))
    if rewards.has("suppress_region"):
        region_director.suppress_region(StringName(active_operation.get("region_id", &"")), float(rewards["suppress_region"]))
    if rewards.has("endgame_pressure_reduction"):
        endgame_pressure_reduction = clampf(endgame_pressure_reduction + float(rewards["endgame_pressure_reduction"]), 0.0, 0.55)


func _abort(reason: String) -> void:
    var operation_id := StringName(active_operation.get("id", &""))
    for robot in _living_members():
        robot.set_group(&"reserve", 0)
        robot.set_goal(heartforge.global_position, reason, robot.move_speed * 0.7)
    active_operation.clear()
    autonomy_director.set_process(true)
    if outpost_director != null:
        outpost_director.set_process(true)
    operation_changed.emit(operation_id, &"aborted", reason)


func _select_team(raw_roles: Array) -> Array[RobotUnit3D]:
    var team: Array[RobotUnit3D] = []
    var used: Array[RobotUnit3D] = []
    if autonomy_director == null:
        return team
    for raw_role in raw_roles:
        var role := StringName(str(raw_role))
        var selected: RobotUnit3D
        for robot in autonomy_director.living_robots(role):
            if robot not in used:
                selected = robot
                break
        if selected == null:
            return []
        used.append(selected)
        team.append(selected)
    return team


func _hold_nonmembers_at_home(members: Array[RobotUnit3D]) -> void:
    var slot := 0
    for robot in autonomy_director.living_robots():
        if robot in members or robot.archetype == &"companion":
            continue
        var angle := TAU * float(slot) / 8.0
        robot.set_group(&"long_range_reserve", slot)
        robot.set_goal(
            heartforge.global_position + Vector3(cos(angle) * 8.5, 0.0, sin(angle) * 8.5),
            "Remaining at the Heartforge because the active long-range operation already has its required composition.",
            robot.move_speed * 0.72
        )
        slot += 1


func _living_members() -> Array[RobotUnit3D]:
    var result: Array[RobotUnit3D] = []
    if active_operation.is_empty():
        return result
    for raw_member in active_operation.get("members", []):
        if is_instance_valid(raw_member) and raw_member is RobotUnit3D and raw_member.is_alive():
            result.append(raw_member)
    active_operation["members"] = result
    return result


func _maximum_separation(anchor: Vector3, members: Array[RobotUnit3D]) -> float:
    var maximum := 0.0
    for robot in members:
        maximum = maxf(maximum, robot.global_position.distance_to(anchor))
    return maximum


func _group_pace(members: Array[RobotUnit3D]) -> float:
    var slowest := 999.0
    for robot in members:
        slowest = minf(slowest, robot.move_speed)
    var pace_factor := 0.64
    if progression != null and progression.has_effect(&"doctrine_rapid_march"):
        pace_factor = 0.78
    return slowest * pace_factor


func _hostile_near(position: Vector3, radius: float) -> bool:
    for enemy in get_tree().get_nodes_in_group(&"organic_enemies"):
        if is_instance_valid(enemy) and enemy is Node3D and position.distance_to(enemy.global_position) <= radius:
            return true
    return false


func _spawn_work_threat(region_id: StringName, threat_level: float) -> void:
    if not spawn_enemy_callback.is_valid():
        return
    threat_serial += 1
    var angle := fmod(float(threat_serial) * 2.399963, TAU)
    var distance := 12.0 + fmod(float(threat_serial * 7), 8.0)
    var position := region_director.center(region_id) + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
    var species: StringName = &"razorhound"
    if threat_level >= 2.4 and threat_serial % 3 == 0:
        species = &"broodmass"
    elif threat_level >= 1.8 and threat_serial % 2 == 0:
        species = &"sporecaster"
    elif threat_level >= 1.25:
        species = &"burrower"
    spawn_enemy_callback.call(position, species)


func _functioning_outpost_count() -> int:
    var count := 0
    if outpost_director == null:
        return count
    for site in outpost_director.discovered_sites():
        if site.has_functioning_outpost():
            count += 1
    return count


func _other_operation_active() -> bool:
    if autonomy_director != null:
        if not autonomy_director.salvage_operation.is_empty() or not autonomy_director.expedition_operation.is_empty():
            return true
    if outpost_director != null and not outpost_director.operation.is_empty():
        return true
    return false


func get_follow_target() -> Node3D:
    var members := _living_members()
    return members[0] if not members.is_empty() else null


func operation_summary() -> String:
    if active_operation.is_empty():
        return "No long-range operation"
    var entry: Dictionary = active_operation.get("data", {})
    return "%s · %s" % [
        str(entry.get("display_name", "Operation")),
        String(active_operation.get("state", &"unknown")).capitalize(),
    ]


func context_dictionary() -> Dictionary:
    var completed: Array[String] = []
    var components: Array[String] = []
    for operation_id in completed_operations:
        completed.append(String(operation_id))
    for component_id in recovered_components:
        components.append(String(component_id))
    return {
        "completed_operations": completed,
        "completed_operations_count": completed.size(),
        "components": components,
        "components_count": components.size(),
        "endgame_pressure_reduction": endgame_pressure_reduction,
    }


func to_dictionary() -> Dictionary:
    var completed: Array[String] = []
    var components: Array[String] = []
    for operation_id in completed_operations:
        completed.append(String(operation_id))
    for component_id in recovered_components:
        components.append(String(component_id))
    return {
        "schema_version": 1,
        "completed_operations": completed,
        "recovered_components": components,
        "endgame_pressure_reduction": endgame_pressure_reduction,
    }


func restore_from_dictionary(data: Dictionary) -> void:
    completed_operations.clear()
    recovered_components.clear()
    for raw_operation in data.get("completed_operations", []):
        var operation_id := StringName(str(raw_operation))
        if operation_id in operations and operation_id not in completed_operations:
            completed_operations.append(operation_id)
    for raw_component in data.get("recovered_components", []):
        var component_id := StringName(str(raw_component))
        if component_id != &"" and component_id not in recovered_components:
            recovered_components.append(component_id)
    endgame_pressure_reduction = clampf(float(data.get("endgame_pressure_reduction", 0.0)), 0.0, 0.55)
