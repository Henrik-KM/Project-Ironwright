class_name LongRangeOperationDirector3D
extends Node

signal operation_changed(operation_id: StringName, state: StringName, detail: String)
signal operation_returned(operation_id: StringName, display_name: String, rewards: Dictionary)
signal component_recovered(component_id: StringName)
signal site_discovery_requested(site_id: StringName)

const OPERATIONS_PATH := "res://data/strategic_operations.json"
const ROUTE_BLOCK_GRACE_SECONDS := 2.4
const MAX_ROUTE_RECOVERIES := 3
const ROUTE_RECOVERY_LATERAL_OFFSET := 11.0
const ROUTE_MEMORY_SWITCH_THRESHOLD := 1.0
const ROUTE_MEMORY_SUCCESS_DECAY := 0.22
const ROUTE_MEMORY_MAX_ENTRIES := 24

var run_state: RunState3D
var progression: ProgressionDirector3D
var region_director: WorldRegionDirector3D
var noise_system: NoiseSystem3D
var autonomy_director: AutonomyDirector3D
var outpost_director: OutpostDirector3D
var heartforge: Heartforge3D
var operation_detail_director: Variant
var spawn_enemy_callback: Callable
var context_provider: Callable
var operations: Dictionary = {}
var completed_operations: Array[StringName] = []
var recovered_components: Array[StringName] = []
var active_operation: Dictionary = {}
var route_memory: Dictionary = {}
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
        next_spawn_enemy_callback: Callable,
        next_operation_detail_director: Variant = null,
        next_context_provider: Callable = Callable()
    ) -> void:
    run_state = next_run_state
    progression = next_progression
    region_director = next_region_director
    noise_system = next_noise_system
    autonomy_director = next_autonomy_director
    outpost_director = next_outpost_director
    heartforge = next_heartforge
    spawn_enemy_callback = next_spawn_enemy_callback
    operation_detail_director = next_operation_detail_director
    context_provider = next_context_provider


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
    if requirements.has("endgame_completed") and bool(requirements["endgame_completed"]):
        if not _context_flag(&"endgame_completed"):
            return false
    if requirements.has("sanctuary_continuation") and bool(requirements["sanctuary_continuation"]):
        if not _context_flag(&"sanctuary_continuation"):
            return false
    if requirements.has("components_min") and component_count() < int(requirements["components_min"]):
        return false
    if requirements.has("functioning_outposts_min"):
        if _functioning_outpost_count() < int(requirements["functioning_outposts_min"]):
            return false
    return true


func _context_flag(flag: StringName) -> bool:
    if not context_provider.is_valid():
        return false
    var raw_context: Variant = context_provider.call()
    if not (raw_context is Dictionary):
        return false
    return bool((raw_context as Dictionary).get(flag, false))


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
    var route_variant := _preferred_route_variant(region_id)
    var route := region_director.route_from_heartforge_variant(region_id, heartforge.global_position, route_variant)
    for index in range(team.size()):
        team[index].set_group(&"long_range_operation", index)

    active_operation = {
        "id": operation_id,
        "data": entry,
        "state": &"outbound",
        "members": team,
        "region_id": region_id,
        "route": route,
        "route_variant": route_variant,
        "route_index": 1,
        "anchor": heartforge.global_position,
        "last_forward": Vector3(0.0, 0.0, -1.0),
        "work_clock": 0.0,
        "noise_clock": 0.0,
        "threat_clock": 0.0,
        "blocked_clock": 0.0,
        "route_recovery_count": 0,
        "route_recovery_active": false,
        "route_recovery_target": Vector3.ZERO,
        "pending_rewards": {},
    }
    autonomy_director.set_process(false)
    if outpost_director != null:
        outpost_director.set_process(false)
    _hold_nonmembers_at_home(team)
    var route_detail := "%s has departed as a cohesive physical group." % str(entry.get("display_name", String(operation_id)))
    if _active_relay_count() > 0:
        route_detail += " Signal Relay coverage is holding one bounded recovery margin for the deep route."
    if route_variant > 0:
        route_detail += " Route memory selected the %s after earlier disruption." % region_director.route_variant_label(region_id, route_variant)
    operation_changed.emit(operation_id, &"outbound", route_detail)
    return true


func _update_active_operation(delta: float) -> void:
    var members := _living_members()
    if members.is_empty():
        _abort("Every machine assigned to the operation was lost in the persistent world.")
        return

    if operation_detail_director != null:
        active_operation["detail_mode"] = operation_detail_director.update_operation(StringName(active_operation.get("id", &"operation")), active_operation.get("anchor", heartforge.global_position))

    var state := StringName(active_operation.get("state", &"outbound"))
    if state == &"working":
        _update_work(delta)
        _position_members(0.0)
        _apply_reduced_detail(members)
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
        elif state == &"retreating":
            _abort("The cohesive group reached the Heartforge after abandoning an obstructed route.")
        else:
            _complete_return()
        return

    var anchor: Vector3 = active_operation.get("anchor", heartforge.global_position)
    var route_recovery_active := bool(active_operation.get("route_recovery_active", false))
    var waypoint: Vector3 = route[route_index]
    var direction := waypoint - anchor
    direction.y = 0.0
    if direction.length() <= 0.75:
        active_operation["route_index"] = route_index + 1
        if route_recovery_active:
            active_operation["route_recovery_active"] = false
            active_operation["route_recovery_target"] = Vector3.ZERO
            active_operation["blocked_clock"] = 0.0
            operation_changed.emit(
                StringName(active_operation.get("id", &"")),
                &"outbound",
                "The group cleared the obstruction and resumed its authored route in formation."
            )
        return
    direction = direction.normalized()
    active_operation["last_forward"] = direction

    if state != &"retreating" and _should_preserve_members(members):
        _begin_route_retreat("Preservation doctrine detected a damaged frame before the objective was complete.")
        return

    var separation := _maximum_separation(anchor, members)
    var pace_multiplier := FormationRules3D.pace_multiplier(separation)
    var hostile_blocking := state != &"retreating" and _hostile_near(anchor, 10.0)
    var block_grace_seconds := ROUTE_BLOCK_GRACE_SECONDS
    if progression != null and progression.has_effect(&"doctrine_predation"):
        block_grace_seconds *= 0.62
    if hostile_blocking and not route_recovery_active:
        active_operation["blocked_clock"] = float(active_operation.get("blocked_clock", 0.0)) + delta
        if float(active_operation.get("blocked_clock", 0.0)) >= block_grace_seconds:
            if int(active_operation.get("route_recovery_count", 0)) >= _route_recovery_limit():
                _begin_route_retreat("The route remained blocked after %d bounded recovery attempts; the cohesive group is retreating with its machines intact." % _route_recovery_limit())
                return
            _record_route_disruption(
                StringName(active_operation.get("region_id", &"region.heartforge_district")),
                int(active_operation.get("route_variant", 0))
            )
            _insert_route_recovery(anchor, waypoint, route_index)
            route_recovery_active = true
            route = active_operation.get("route", PackedVector3Array()) as PackedVector3Array
            waypoint = route[route_index]
            direction = waypoint - anchor
            direction.y = 0.0
            if direction.length() > 0.01:
                direction = direction.normalized()
            active_operation["last_forward"] = direction
            operation_changed.emit(
                StringName(active_operation.get("id", &"")),
                &"rerouting",
                "Organic pressure blocked the street. The group is taking a bounded side route while preserving formation cohesion."
            )
        else:
            pace_multiplier = 0.0
    elif not hostile_blocking:
        active_operation["blocked_clock"] = 0.0
    if hostile_blocking and not route_recovery_active:
        pace_multiplier = 0.0
    var pace := _group_pace(members) * pace_multiplier
    anchor += direction * pace * delta
    active_operation["anchor"] = anchor
    _position_members(pace)
    _apply_reduced_detail(members)


func _insert_route_recovery(anchor: Vector3, waypoint: Vector3, route_index: int) -> void:
    var direction := waypoint - anchor
    direction.y = 0.0
    if direction.length() <= 0.01:
        direction = active_operation.get("last_forward", Vector3.FORWARD)
        direction.y = 0.0
    direction = direction.normalized()
    var lateral := Vector3(-direction.z, 0.0, direction.x)
    var side := -1.0 if int(active_operation.get("route_recovery_count", 0)) % 2 == 0 else 1.0
    var detour := anchor + direction * 5.0 + lateral * side * ROUTE_RECOVERY_LATERAL_OFFSET
    var route: PackedVector3Array = active_operation.get("route", PackedVector3Array())
    var rerouted := PackedVector3Array()
    for index in range(route_index):
        rerouted.append(route[index])
    rerouted.append(detour)
    for index in range(route_index, route.size()):
        rerouted.append(route[index])
    active_operation["route"] = rerouted
    active_operation["route_recovery_count"] = int(active_operation.get("route_recovery_count", 0)) + 1
    active_operation["route_recovery_active"] = true
    active_operation["route_recovery_target"] = detour
    active_operation["blocked_clock"] = 0.0


func _begin_route_retreat(reason: String) -> void:
    var route: PackedVector3Array = active_operation.get("route", PackedVector3Array())
    var route_index := clampi(int(active_operation.get("route_index", 1)), 1, route.size())
    var retreat_route := PackedVector3Array()
    retreat_route.append(active_operation.get("anchor", heartforge.global_position))
    for index in range(route_index - 1, -1, -1):
        retreat_route.append(route[index])
    if retreat_route.size() == 1:
        retreat_route.append(heartforge.global_position)
    active_operation["state"] = &"retreating"
    active_operation["route"] = retreat_route
    active_operation["route_index"] = 1
    active_operation["route_recovery_active"] = false
    active_operation["blocked_clock"] = 0.0
    active_operation["last_forward"] = (retreat_route[1] - retreat_route[0]).normalized()
    operation_changed.emit(
        StringName(active_operation.get("id", &"")),
        &"retreating",
        "%s The group is returning through the persistent streets without delivering an incomplete objective." % reason
    )


func _apply_reduced_detail(members: Array[RobotUnit3D]) -> void:
    if operation_detail_director == null or StringName(active_operation.get("detail_mode", &"active")) != &"reduced":
        return
    operation_detail_director.apply_reduced_formation(
        active_operation.get("anchor", heartforge.global_position),
        active_operation.get("last_forward", Vector3.FORWARD),
        members
    )


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
    active_operation["blocked_clock"] = 0.0
    active_operation["route_recovery_active"] = false
    active_operation["route_recovery_target"] = Vector3.ZERO
    operation_changed.emit(StringName(active_operation.get("id", &"")), &"returning", "The machines are returning through the same physical streets with the secured objective.")


func _complete_return() -> void:
    var operation_id := StringName(active_operation.get("id", &""))
    var entry: Dictionary = active_operation.get("data", {})
    var rewards: Dictionary = active_operation.get("pending_rewards", {})
    _record_route_success(
        StringName(active_operation.get("region_id", &"region.heartforge_district")),
        int(active_operation.get("route_variant", 0)),
        int(active_operation.get("route_recovery_count", 0))
    )
    _apply_rewards(rewards)
    if operation_id not in completed_operations:
        completed_operations.append(operation_id)
    for robot in _living_members():
        robot.set_group(&"reserve", 0)
        robot.set_goal(heartforge.global_position, "The long-range objective is complete; returning to the general autonomous machine pool.", robot.move_speed * 0.72)
    active_operation.clear()
    if operation_detail_director != null:
        operation_detail_director.clear_operation(operation_id)
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
    if operation_detail_director != null:
        operation_detail_director.clear_operation(operation_id)
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
    if progression != null:
        if progression.has_effect(&"doctrine_preservation"):
            pace_factor = 0.56
        elif progression.has_effect(&"doctrine_defiance"):
            pace_factor = 0.68
        elif progression.has_effect(&"doctrine_predation"):
            pace_factor = 0.72
        elif progression.has_effect(&"doctrine_rapid_march"):
            pace_factor = 0.78
    return slowest * pace_factor


func _route_recovery_limit() -> int:
    var relay_bonus := 1 if _active_relay_count() > 0 else 0
    if progression != null and progression.has_effect(&"doctrine_defiance"):
        return MAX_ROUTE_RECOVERIES + 2 + relay_bonus
    return MAX_ROUTE_RECOVERIES + relay_bonus


func _active_relay_count() -> int:
    if active_operation.is_empty():
        return 0
    var count := 0
    for robot in _living_members():
        if robot.archetype == &"relay":
            count += 1
    return count


func _should_preserve_members(members: Array[RobotUnit3D]) -> bool:
    if progression == null or not progression.has_effect(&"doctrine_preservation"):
        return false
    for robot in members:
        if robot == null or not robot.is_alive():
            continue
        if robot.current_health / maxf(1.0, robot.maximum_health) <= 0.55:
            return true
    return false


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
        "route_memory": _serialize_route_memory(),
    }


func to_dictionary() -> Dictionary:
    var completed: Array[String] = []
    var components: Array[String] = []
    for operation_id in completed_operations:
        completed.append(String(operation_id))
    for component_id in recovered_components:
        components.append(String(component_id))
    return {
        "schema_version": 3,
        "completed_operations": completed,
        "recovered_components": components,
        "endgame_pressure_reduction": endgame_pressure_reduction,
        "route_memory": _serialize_route_memory(),
        "active_operation": _serialize_active_operation(),
    }


func restore_from_dictionary(data: Dictionary) -> void:
    completed_operations.clear()
    recovered_components.clear()
    active_operation.clear()
    for raw_operation in data.get("completed_operations", []):
        var operation_id := StringName(str(raw_operation))
        if operation_id in operations and operation_id not in completed_operations:
            completed_operations.append(operation_id)
    for raw_component in data.get("recovered_components", []):
        var component_id := StringName(str(raw_component))
        if component_id != &"" and component_id not in recovered_components:
            recovered_components.append(component_id)
    endgame_pressure_reduction = clampf(float(data.get("endgame_pressure_reduction", 0.0)), 0.0, 0.55)
    route_memory.clear()
    for raw_memory in data.get("route_memory", []):
        if not (raw_memory is Dictionary):
            continue
        var saved_memory := raw_memory as Dictionary
        var region_id := str(saved_memory.get("region_id", ""))
        if region_id.is_empty() or route_memory.size() >= ROUTE_MEMORY_MAX_ENTRIES:
            continue
        route_memory[region_id] = {
            "risk": clampf(float(saved_memory.get("risk", 0.0)), 0.0, 6.0),
            "preferred_variant": maxi(0, int(saved_memory.get("preferred_variant", 0))),
            "recoveries": maxi(0, int(saved_memory.get("recoveries", 0))),
        }
    _restore_active_operation(data.get("active_operation", {}))


func _preferred_route_variant(region_id: StringName) -> int:
    if region_director == null:
        return 0
    var variant_count := region_director.route_variant_count(region_id)
    if variant_count <= 0:
        return 0
    var memory: Variant = route_memory.get(String(region_id), {})
    if not (memory is Dictionary):
        return 0
    if float((memory as Dictionary).get("risk", 0.0)) < ROUTE_MEMORY_SWITCH_THRESHOLD:
        return 0
    return clampi(int((memory as Dictionary).get("preferred_variant", 1)), 1, variant_count)


func _record_route_disruption(region_id: StringName, current_variant: int) -> void:
    var key := String(region_id)
    if not route_memory.has(key) and route_memory.size() >= ROUTE_MEMORY_MAX_ENTRIES:
        var oldest_key := str(route_memory.keys()[0])
        route_memory.erase(oldest_key)
    var memory: Dictionary = route_memory.get(key, {
        "risk": 0.0,
        "preferred_variant": 0,
        "recoveries": 0,
    })
    memory["risk"] = clampf(float(memory.get("risk", 0.0)) + 1.0, 0.0, 6.0)
    memory["recoveries"] = maxi(0, int(memory.get("recoveries", 0))) + 1
    var variant_count := region_director.route_variant_count(region_id) if region_director != null else 0
    if variant_count > 0:
        var recovery_number := int(memory.get("recoveries", 1))
        var next_variant := ((recovery_number - 1) % variant_count) + 1
        if next_variant == current_variant:
            next_variant = (next_variant % variant_count) + 1
        memory["preferred_variant"] = next_variant
    route_memory[key] = memory


func _record_route_success(region_id: StringName, route_variant: int, recovery_count: int) -> void:
    var key := String(region_id)
    if not route_memory.has(key):
        return
    var memory: Dictionary = route_memory[key]
    if recovery_count <= 0:
        memory["risk"] = maxf(0.0, float(memory.get("risk", 0.0)) - ROUTE_MEMORY_SUCCESS_DECAY)
        if float(memory.get("risk", 0.0)) < ROUTE_MEMORY_SWITCH_THRESHOLD:
            memory["preferred_variant"] = 0
    else:
        memory["risk"] = minf(6.0, float(memory.get("risk", 0.0)) + 0.15)
    route_memory[key] = memory


func _serialize_route_memory() -> Array[Dictionary]:
    var serialized: Array[Dictionary] = []
    var keys: Array[String] = []
    for raw_key in route_memory.keys():
        keys.append(str(raw_key))
    keys.sort()
    for key in keys:
        if serialized.size() >= ROUTE_MEMORY_MAX_ENTRIES:
            break
        var memory: Variant = route_memory.get(key, {})
        if not (memory is Dictionary):
            continue
        var value := memory as Dictionary
        serialized.append({
            "region_id": key,
            "risk": clampf(float(value.get("risk", 0.0)), 0.0, 6.0),
            "preferred_variant": maxi(0, int(value.get("preferred_variant", 0))),
            "recoveries": maxi(0, int(value.get("recoveries", 0))),
        })
    return serialized


func _serialize_active_operation() -> Dictionary:
    if active_operation.is_empty():
        return {}
    var route_values: Array = []
    var route: PackedVector3Array = active_operation.get("route", PackedVector3Array())
    for point in route:
        route_values.append(_vector_to_array(point))
    var member_names: Array[String] = []
    for member in active_operation.get("members", []):
        if is_instance_valid(member) and member is RobotUnit3D:
            member_names.append(String((member as RobotUnit3D).name))
    return {
        "id": String(active_operation.get("id", &"")),
        "state": String(active_operation.get("state", &"outbound")),
        "member_names": member_names,
        "region_id": String(active_operation.get("region_id", &"region.heartforge_district")),
        "route": route_values,
        "route_variant": int(active_operation.get("route_variant", 0)),
        "route_index": int(active_operation.get("route_index", 1)),
        "anchor": _vector_to_array(active_operation.get("anchor", heartforge.global_position)),
        "last_forward": _vector_to_array(active_operation.get("last_forward", Vector3.FORWARD)),
        "work_clock": float(active_operation.get("work_clock", 0.0)),
        "noise_clock": float(active_operation.get("noise_clock", 0.0)),
        "threat_clock": float(active_operation.get("threat_clock", 0.0)),
        "blocked_clock": float(active_operation.get("blocked_clock", 0.0)),
        "route_recovery_count": int(active_operation.get("route_recovery_count", 0)),
        "route_recovery_active": bool(active_operation.get("route_recovery_active", false)),
        "route_recovery_target": _vector_to_array(active_operation.get("route_recovery_target", Vector3.ZERO)),
        "pending_rewards": (active_operation.get("pending_rewards", {}) as Dictionary).duplicate(true),
    }


func _restore_active_operation(raw_data: Variant) -> void:
    if not (raw_data is Dictionary):
        return
    var saved := raw_data as Dictionary
    var operation_id := StringName(str(saved.get("id", "")))
    var entry := operation(operation_id)
    if operation_id == &"" or entry.is_empty():
        return
    var members: Array[RobotUnit3D] = []
    for raw_name in saved.get("member_names", []):
        var member := _find_robot_by_name(str(raw_name))
        if member != null and member.is_alive() and member not in members:
            members.append(member)
    if members.is_empty():
        return
    var route := PackedVector3Array()
    for raw_point in saved.get("route", []):
        route.append(_array_to_vector(raw_point))
    active_operation = {
        "id": operation_id,
        "data": entry,
        "state": StringName(str(saved.get("state", "outbound"))),
        "members": members,
        "region_id": StringName(str(saved.get("region_id", "region.heartforge_district"))),
        "route": route,
        "route_variant": maxi(0, int(saved.get("route_variant", 0))),
        "route_index": maxi(1, int(saved.get("route_index", 1))),
        "anchor": _array_to_vector(saved.get("anchor", [heartforge.global_position.x, heartforge.global_position.y, heartforge.global_position.z])),
        "last_forward": _array_to_vector(saved.get("last_forward", [0.0, 0.0, -1.0])),
        "work_clock": maxf(0.0, float(saved.get("work_clock", 0.0))),
        "noise_clock": maxf(0.0, float(saved.get("noise_clock", 0.0))),
        "threat_clock": maxf(0.0, float(saved.get("threat_clock", 0.0))),
        "blocked_clock": maxf(0.0, float(saved.get("blocked_clock", 0.0))),
        "route_recovery_count": clampi(int(saved.get("route_recovery_count", 0)), 0, MAX_ROUTE_RECOVERIES),
        "route_recovery_active": bool(saved.get("route_recovery_active", false)),
        "route_recovery_target": _array_to_vector(saved.get("route_recovery_target", [0.0, 0.0, 0.0])),
        "pending_rewards": (saved.get("pending_rewards", {}) as Dictionary).duplicate(true),
    }
    for index in range(members.size()):
        members[index].set_group(&"long_range_operation", index)
    autonomy_director.set_process(false)
    if outpost_director != null:
        outpost_director.set_process(false)
    _hold_nonmembers_at_home(members)
    operation_changed.emit(operation_id, StringName(active_operation.get("state", &"outbound")), "The saved long-range group resumed its physical route.")


func _find_robot_by_name(robot_name: String) -> RobotUnit3D:
    for node in get_tree().get_nodes_in_group(&"friendly_robots"):
        if node is RobotUnit3D and String((node as RobotUnit3D).name) == robot_name:
            return node as RobotUnit3D
    return null


func _vector_to_array(value: Vector3) -> Array[float]:
    return [value.x, value.y, value.z]


func _array_to_vector(value: Variant) -> Vector3:
    if value is Array and value.size() >= 3:
        return Vector3(float(value[0]), float(value[1]), float(value[2]))
    return Vector3.ZERO
