class_name AutonomyDirector3D
extends Node

signal robot_registered(robot: RobotUnit3D)
signal robot_lost(robot_name: String, position: Vector3)
signal operation_changed(kind: StringName, state: StringName, detail: String)
signal expedition_core_secured
signal expedition_returned

const GROUP_SALVAGE: StringName = &"salvage_group"
const GROUP_EXPEDITION: StringName = &"north_expedition"
const NORTH_RUINS := Vector3(0.0, 0.0, -66.0)

var run_state: RunState3D
var noise_system: NoiseSystem3D
var player_reference: Mechromancer3D
var heartforge_reference: Heartforge3D
var robots: Array[RobotUnit3D] = []
var salvage_operation: Dictionary = {}
var expedition_operation: Dictionary = {}
var assignment_clock: float = 0.0
var _robot_serial: int = 1


func configure(
        next_run_state: RunState3D,
        next_noise_system: NoiseSystem3D,
        player: Mechromancer3D,
        heartforge: Heartforge3D
    ) -> void:
    run_state = next_run_state
    noise_system = next_noise_system
    player_reference = player
    heartforge_reference = heartforge


func register_robot(robot: RobotUnit3D) -> void:
    if robot in robots:
        return
    _robot_serial += 1
    robot.name = "%s_%02d" % [String(robot.archetype).capitalize(), _robot_serial]
    robot.player_reference = player_reference
    robot.heartforge_reference = heartforge_reference
    robot.destroyed.connect(_on_robot_destroyed)
    robot.salvage_completed.connect(_on_robot_salvage_completed)
    robots.append(robot)
    robot_registered.emit(robot)


func living_robots(archetype_filter: StringName = &"") -> Array[RobotUnit3D]:
    var result: Array[RobotUnit3D] = []
    for robot in robots:
        if not is_instance_valid(robot) or not robot.is_alive():
            continue
        if archetype_filter != &"" and robot.archetype != archetype_filter:
            continue
        result.append(robot)
    return result


func count_robots(archetype_filter: StringName = &"") -> int:
    return living_robots(archetype_filter).size()


func _process(delta: float) -> void:
    if run_state == null:
        return
    assignment_clock += delta
    _update_operation(expedition_operation, delta)
    if expedition_operation.is_empty():
        _update_operation(salvage_operation, delta)

    if assignment_clock >= 0.45:
        assignment_clock = 0.0
        _refresh_macro_assignments()


func _refresh_macro_assignments() -> void:
    _remove_invalid_robots()
    if not expedition_operation.is_empty():
        _keep_unassigned_defending()
        return

    match run_state.focus:
        RunState3D.FOCUS_SALVAGE:
            if salvage_operation.is_empty():
                _try_start_salvage_operation()
            _keep_unassigned_defending()
        RunState3D.FOCUS_EXPEDITION:
            _keep_unassigned_defending()
        _:
            if not salvage_operation.is_empty():
                _abort_operation(salvage_operation, "Global focus returned to Heartforge defence.")
                salvage_operation.clear()
            _assign_defensive_ring()


func _assign_defensive_ring() -> void:
    var defenders := living_robots()
    var slot := 0
    for robot in defenders:
        if robot.archetype == &"companion":
            continue
        var angle := TAU * float(slot) / maxf(1.0, float(defenders.size() - 1))
        var radius := 7.0 + float(slot % 2) * 2.0
        var position := heartforge_reference.global_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
        robot.set_group(&"defence", slot)
        robot.set_goal(position, "Holding an automatically selected defensive arc around the only Heartforge.", robot.move_speed * 0.76)
        slot += 1


func _keep_unassigned_defending() -> void:
    var reserved: Array[RobotUnit3D] = []
    reserved.append_array(_members_from_operation(salvage_operation))
    reserved.append_array(_members_from_operation(expedition_operation))
    var slot := 0
    for robot in living_robots():
        if robot.archetype == &"companion" or robot in reserved:
            continue
        var angle := TAU * float(slot) / 6.0
        var position := heartforge_reference.global_position + Vector3(cos(angle) * 8.5, 0.0, sin(angle) * 8.5)
        robot.set_group(&"reserve", slot)
        robot.set_goal(position, "Remaining at the Heartforge because the active operation already has enough machines.", robot.move_speed * 0.72)
        slot += 1


func _try_start_salvage_operation() -> bool:
    var salvagers := living_robots(&"salvager")
    if salvagers.is_empty():
        return false
    var target := _nearest_available_salvage()
    if target == null:
        return false

    var members: Array[RobotUnit3D] = []
    members.append_array(salvagers.slice(0, mini(2, salvagers.size())))
    var guardians := living_robots(&"guardian")
    if not guardians.is_empty():
        members.append(guardians[0])
    var scouts := living_robots(&"scout")
    if not scouts.is_empty():
        members.push_front(scouts[0])

    if not target.reserve(GROUP_SALVAGE):
        return false
    salvage_operation = _new_operation(GROUP_SALVAGE, &"salvage", members, target.global_position, target)
    operation_changed.emit(&"salvage", &"outbound", "A coordinated group is physically leaving for %s." % target.display_name)
    return true


func can_authorize_expedition() -> bool:
    return (
        expedition_operation.is_empty()
        and count_robots(&"scout") >= 1
        and count_robots(&"guardian") >= 1
        and count_robots(&"salvager") >= 1
    )


func authorize_north_expedition() -> bool:
    if not can_authorize_expedition():
        return false
    if not salvage_operation.is_empty():
        _abort_operation(salvage_operation, "Machines recalled to form the North Ruins expedition.")
        salvage_operation.clear()

    var members: Array[RobotUnit3D] = []
    members.append(living_robots(&"scout")[0])
    members.append(living_robots(&"guardian")[0])
    members.append(living_robots(&"salvager")[0])
    var extra_guardians := living_robots(&"guardian")
    if extra_guardians.size() > 1:
        members.append(extra_guardians[1])

    expedition_operation = _new_operation(GROUP_EXPEDITION, &"expedition", members, NORTH_RUINS, null)
    expedition_operation["work_duration"] = 7.0
    operation_changed.emit(&"expedition", &"outbound", "The expedition is departing as one formation. Its pace is limited by cohesion, not the fastest chassis.")
    return true


func _new_operation(
        group_id: StringName,
        kind: StringName,
        members: Array[RobotUnit3D],
        target_position: Vector3,
        target_node: Node
    ) -> Dictionary:
    var route := _route_between(heartforge_reference.global_position, target_position)
    for index in range(members.size()):
        members[index].set_group(group_id, index)
    return {
        "id": group_id,
        "kind": kind,
        "state": &"outbound",
        "members": members,
        "target_node": target_node,
        "target_position": target_position,
        "anchor": heartforge_reference.global_position,
        "route": route,
        "route_index": 1,
        "work_clock": 0.0,
        "work_duration": 5.5,
        "cargo": 0,
        "core_secured": false,
        "last_forward": Vector3(0.0, 0.0, -1.0),
    }


func _update_operation(operation: Dictionary, delta: float) -> void:
    if operation.is_empty():
        return
    var members := _members_from_operation(operation)
    if members.is_empty():
        _abort_operation(operation, "All machines assigned to the operation were lost.")
        operation.clear()
        return

    var state: StringName = operation.get("state", &"outbound")
    if state == &"working":
        _update_operation_work(operation, delta)
        _position_members(operation, 0.0)
        return

    var route: PackedVector3Array = operation.get("route", PackedVector3Array())
    var route_index := int(operation.get("route_index", 1))
    if route.is_empty() or route_index >= route.size():
        if state == &"outbound":
            operation["state"] = &"working"
            operation["work_clock"] = 0.0
            operation_changed.emit(operation.get("kind", &"operation"), &"working", "The group arrived together and began the objective.")
        else:
            _complete_return(operation)
        return

    var anchor: Vector3 = operation.get("anchor", heartforge_reference.global_position)
    var waypoint: Vector3 = route[route_index]
    var direction := waypoint - anchor
    direction.y = 0.0
    if direction.length() < 0.7:
        operation["route_index"] = route_index + 1
        return
    direction = direction.normalized()
    operation["last_forward"] = direction

    var max_separation := _maximum_member_separation(operation)
    var pace_multiplier := FormationRules3D.pace_multiplier(max_separation)
    var base_pace := _operation_base_pace(members, operation.get("kind", &"operation"))
    var hostile_close := _hostile_near_anchor(anchor, 9.5)
    if hostile_close:
        pace_multiplier = 0.0
        operation_changed.emit(operation.get("kind", &"operation"), &"engaged", "The group is holding formation while its escorts handle nearby organisms.")

    anchor += direction * base_pace * pace_multiplier * delta
    operation["anchor"] = anchor
    _position_members(operation, base_pace * pace_multiplier)


func _position_members(operation: Dictionary, group_speed: float) -> void:
    var members := _members_from_operation(operation)
    var anchor: Vector3 = operation.get("anchor", heartforge_reference.global_position)
    var forward: Vector3 = operation.get("last_forward", Vector3.FORWARD)
    for index in range(members.size()):
        var robot := members[index]
        var offset := FormationRules3D.formation_offset(index, robot.archetype)
        var desired := anchor + FormationRules3D.rotated_offset(offset, forward)
        var reason := "Maintaining the %s formation slot; the group will slow or regroup rather than abandon stragglers." % String(operation.get("kind", &"operation"))
        robot.set_goal(desired, reason, maxf(1.5, group_speed + 1.0))


func _update_operation_work(operation: Dictionary, delta: float) -> void:
    operation["work_clock"] = float(operation.get("work_clock", 0.0)) + delta
    var kind: StringName = operation.get("kind", &"operation")
    if kind == &"salvage":
        var target: Node = operation.get("target_node")
        if target == null or not is_instance_valid(target) or not target.has_method("has_scrap") or not bool(target.call("has_scrap")):
            _begin_return(operation)
            return
        var members := _members_from_operation(operation)
        var assigned := false
        for robot in members:
            if robot.archetype == &"salvager" and robot.salvage_target == null:
                robot.begin_robot_salvage(target)
                assigned = true
        if assigned and noise_system != null:
            noise_system.emit_noise(target.global_position, 19.0, 0.55, &"robot_salvage")
        if int(operation.get("cargo", 0)) >= 32 or float(operation.get("work_clock", 0.0)) >= 15.0:
            _begin_return(operation)
    else:
        if noise_system != null and int(float(operation.get("work_clock", 0.0)) * 2.0) % 3 == 0:
            noise_system.emit_noise(NORTH_RUINS, 31.0, 0.8, &"expedition_recovery")
        if float(operation.get("work_clock", 0.0)) >= float(operation.get("work_duration", 7.0)):
            operation["core_secured"] = true
            expedition_core_secured.emit()
            _begin_return(operation)


func _begin_return(operation: Dictionary) -> void:
    operation["state"] = &"returning"
    var route: PackedVector3Array = operation.get("route", PackedVector3Array())
    var reverse_route := PackedVector3Array()
    for index in range(route.size() - 1, -1, -1):
        reverse_route.append(route[index])
    operation["route"] = reverse_route
    operation["route_index"] = 1
    operation["anchor"] = operation.get("target_position", NORTH_RUINS)
    operation["last_forward"] = Vector3(0.0, 0.0, 1.0)
    operation_changed.emit(operation.get("kind", &"operation"), &"returning", "The machines are returning physically along the same persistent streets.")


func _complete_return(operation: Dictionary) -> void:
    var kind: StringName = operation.get("kind", &"operation")
    if kind == &"salvage":
        var cargo := int(operation.get("cargo", 0))
        if cargo > 0:
            run_state.add_scrap(cargo, true)
            run_state.log_event("Salvage group returned with %d Scrap." % cargo)
        var target: Node = operation.get("target_node")
        if target != null and is_instance_valid(target) and target.has_method("release_reservation"):
            target.call("release_reservation", GROUP_SALVAGE)
        salvage_operation.clear()
        operation_changed.emit(&"salvage", &"complete", "The group returned and deposited its cargo without player routing or unit orders.")
    else:
        if bool(operation.get("core_secured", false)):
            run_state.add_rare_core(1)
            run_state.log_event("North Ruins expedition returned with a rare Cognition Core.")
        expedition_operation.clear()
        expedition_returned.emit()
        operation_changed.emit(&"expedition", &"complete", "The coordinated expedition has returned to the Heartforge.")


func _abort_operation(operation: Dictionary, reason: String) -> void:
    var target: Node = operation.get("target_node")
    if target != null and is_instance_valid(target) and target.has_method("release_reservation"):
        target.call("release_reservation", operation.get("id", &""))
    for robot in _members_from_operation(operation):
        robot.set_group(&"reserve", 0)
        robot.set_goal(heartforge_reference.global_position, reason, robot.move_speed * 0.7)
    operation_changed.emit(operation.get("kind", &"operation"), &"aborted", reason)


func _on_robot_salvage_completed(robot: RobotUnit3D, pile: Node, amount: int) -> void:
    if salvage_operation.is_empty() or robot not in _members_from_operation(salvage_operation):
        return
    salvage_operation["cargo"] = int(salvage_operation.get("cargo", 0)) + max(0, amount)
    if amount > 0:
        run_state.log_event("%s dismantled %d Scrap; the group will carry it home." % [robot.name, amount])
    if pile == null or not is_instance_valid(pile) or not pile.has_method("has_scrap") or not bool(pile.call("has_scrap")):
        _begin_return(salvage_operation)


func _on_robot_destroyed(robot: RobotUnit3D) -> void:
    robot_lost.emit(robot.name, robot.global_position)
    robots.erase(robot)
    run_state.log_event("%s was destroyed at %s." % [robot.name, str(robot.global_position)])


func _members_from_operation(operation: Dictionary) -> Array[RobotUnit3D]:
    var result: Array[RobotUnit3D] = []
    if operation.is_empty():
        return result
    var raw_members: Array = operation.get("members", [])
    for member in raw_members:
        if is_instance_valid(member) and member is RobotUnit3D and member.is_alive():
            result.append(member)
    operation["members"] = result
    return result


func _maximum_member_separation(operation: Dictionary) -> float:
    var anchor: Vector3 = operation.get("anchor", heartforge_reference.global_position)
    var maximum := 0.0
    for robot in _members_from_operation(operation):
        maximum = maxf(maximum, robot.global_position.distance_to(anchor))
    return maximum


func _operation_base_pace(members: Array[RobotUnit3D], kind: StringName) -> float:
    var slowest := 999.0
    for robot in members:
        slowest = minf(slowest, robot.move_speed)
    var pace_factor := 0.66
    if kind == &"expedition":
        pace_factor += float(run_state.level_for(&"scout") - 1) * 0.11
    return slowest * pace_factor


func _hostile_near_anchor(anchor: Vector3, radius: float) -> bool:
    for enemy in get_tree().get_nodes_in_group("organic_enemies"):
        if is_instance_valid(enemy) and enemy is Node3D and anchor.distance_to(enemy.global_position) <= radius:
            return true
    return false


func _nearest_available_salvage() -> SalvagePile3D:
    var best: SalvagePile3D
    var best_distance := INF
    for candidate in get_tree().get_nodes_in_group("salvage_piles"):
        if not is_instance_valid(candidate) or not (candidate is SalvagePile3D) or not candidate.has_scrap():
            continue
        if candidate.reserved_by_group != &"":
            continue
        var current_distance := heartforge_reference.global_position.distance_to(candidate.global_position)
        if current_distance < best_distance:
            best = candidate
            best_distance = current_distance
    return best


func _route_between(origin: Vector3, destination: Vector3) -> PackedVector3Array:
    var route := PackedVector3Array()
    route.append(origin)
    if absf(destination.z - origin.z) >= absf(destination.x - origin.x):
        route.append(Vector3(origin.x, 0.0, destination.z))
    else:
        route.append(Vector3(destination.x, 0.0, origin.z))
    route.append(destination)
    return route


func get_follow_target() -> Node3D:
    if not expedition_operation.is_empty():
        var members := _members_from_operation(expedition_operation)
        if not members.is_empty():
            return members[0]
    if not salvage_operation.is_empty():
        var salvage_members := _members_from_operation(salvage_operation)
        if not salvage_members.is_empty():
            return salvage_members[0]
    return null


func operation_summary() -> String:
    if not expedition_operation.is_empty():
        return "North expedition: %s" % String(expedition_operation.get("state", &"unknown")).capitalize()
    if not salvage_operation.is_empty():
        return "Salvage group: %s · cargo %d" % [String(salvage_operation.get("state", &"unknown")).capitalize(), int(salvage_operation.get("cargo", 0))]
    return "No remote operation"
