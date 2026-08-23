class_name AutonomyDirector3D
extends Node

signal robot_registered(robot: RobotUnit3D)
signal robot_lost(robot_name: String, position: Vector3)
signal robot_casualty(record: Dictionary)
signal operation_changed(kind: StringName, state: StringName, detail: String)
signal expedition_core_secured
signal expedition_returned

const GROUP_SALVAGE: StringName = &"salvage_network"
const GROUP_EXPEDITION: StringName = &"north_expedition"
const NORTH_RUINS := Vector3(0.0, 0.0, -66.0)
const SALVAGE_PLAYER_SPLIT_DISTANCE: float = 9.0
const SALVAGE_WIDE_SPLIT_DISTANCE: float = 22.0
const SALVAGE_DEPOSIT_RADIUS: float = 4.6
const SALVAGE_REPLAN_SECONDS: float = 0.9

var run_state: RunState3D
var noise_system: NoiseSystem3D
var player_reference: Mechromancer3D
var heartforge_reference: Heartforge3D
var operation_detail_director: Variant
var robots: Array[RobotUnit3D] = []
var salvage_operation: Dictionary = {}
var expedition_operation: Dictionary = {}
var assignment_clock: float = 0.0
var _robot_serial: int = 1


func configure(
        next_run_state: RunState3D,
        next_noise_system: NoiseSystem3D,
        player: Mechromancer3D,
        heartforge: Heartforge3D,
        next_operation_detail_director: Variant = null
    ) -> void:
    run_state = next_run_state
    noise_system = next_noise_system
    player_reference = player
    heartforge_reference = heartforge
    operation_detail_director = next_operation_detail_director


func register_robot(robot: RobotUnit3D) -> void:
    if robot in robots:
        return
    _robot_serial += 1
    robot.name = "%s_%02d" % [String(robot.archetype).capitalize(), _robot_serial]
    var family_serial := 1
    for existing in robots:
        if is_instance_valid(existing) and existing.archetype == robot.archetype and existing.is_alive():
            family_serial += 1
    robot.assign_callsign(family_serial)
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
            if not salvage_operation.is_empty():
                _refresh_distributed_salvagers()
                _refresh_salvage_escort_assignments()
                _position_salvage_scouts()
            _keep_unassigned_defending()
        RunState3D.FOCUS_EXPEDITION:
            _keep_unassigned_defending()
        _:
            if not salvage_operation.is_empty():
                _abort_operation(salvage_operation, "Global focus returned to Heartforge defence.")
                salvage_operation.clear()
            _assign_defensive_ring()


func _remove_invalid_robots() -> void:
    for index in range(robots.size() - 1, -1, -1):
        var robot := robots[index]
        if not is_instance_valid(robot) or not robot.is_alive():
            robots.remove_at(index)


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
    reserved.append_array(_salvage_guardians(&"salvage_guardians"))
    reserved.append_array(_salvage_guardians(&"player_guardians"))
    reserved.append_array(_salvage_scouts())
    var slot := 0
    for robot in living_robots():
        if robot.archetype == &"companion" or robot in reserved:
            continue
        var angle := TAU * float(slot) / 6.0
        var position := heartforge_reference.global_position + Vector3(cos(angle) * 8.5, 0.0, sin(angle) * 8.5)
        robot.set_group(&"reserve", slot)
        robot.set_goal(position, "Remaining at the Heartforge because the active machine network already has enough coverage.", robot.move_speed * 0.72)
        slot += 1


# -----------------------------------------------------------------------------
# Distributed autonomous salvage
# -----------------------------------------------------------------------------

func _try_start_salvage_operation() -> bool:
    var salvagers := living_robots(&"salvager")
    if salvagers.is_empty() or _available_salvage_piles().is_empty():
        return false

    salvage_operation = {
        "id": GROUP_SALVAGE,
        "kind": &"salvage",
        "state": &"distributed",
        "distributed": true,
        "members": salvagers.duplicate(),
        "assignments": {},
        "salvage_guardians": [],
        "player_guardians": [],
        "salvage_scouts": [],
        "anchor": heartforge_reference.global_position,
        "target_node": null,
        "target_position": heartforge_reference.global_position,
        "last_forward": Vector3(0.0, 0.0, -1.0),
        "cargo": 0,
        "delivered": 0,
        "replan_clock": 0.0,
        "idle_clock": 0.0,
    }
    _refresh_distributed_salvagers()
    # Prime the first salvage cells immediately so a focus change has an
    # inspectable plan before the next process tick.
    _update_distributed_salvage(salvage_operation, 0.0)
    _refresh_salvage_escort_assignments()
    _position_salvage_scouts()
    operation_changed.emit(
        &"salvage",
        &"distributed",
        "Scrappers are running independent salvage cells. They choose separate wrecks, re-plan as sites empty or become dangerous, and Wardens distribute protection across the active cells and Mechromancer."
    )
    return true


func _refresh_distributed_salvagers() -> void:
    if salvage_operation.is_empty() or not bool(salvage_operation.get("distributed", false)):
        return
    var members: Array[RobotUnit3D] = []
    members.append_array(living_robots(&"salvager"))
    salvage_operation["members"] = members

    var existing_assignments: Dictionary = salvage_operation.get("assignments", {})
    var live_keys: Dictionary = {}
    for robot in members:
        live_keys[_assignment_key(robot)] = true
        if not existing_assignments.has(_assignment_key(robot)):
            existing_assignments[_assignment_key(robot)] = _blank_salvage_assignment(robot)
    for raw_key in existing_assignments.keys():
        var key := str(raw_key)
        if live_keys.has(key):
            continue
        _release_salvage_assignment(existing_assignments[key])
        existing_assignments.erase(raw_key)
    salvage_operation["assignments"] = existing_assignments

    var scouts := living_robots(&"scout")
    var active_scouts: Array[RobotUnit3D] = []
    if not scouts.is_empty():
        active_scouts.append(scouts[0])
    salvage_operation["salvage_scouts"] = active_scouts


func _update_distributed_salvage(operation: Dictionary, delta: float) -> void:
    _refresh_distributed_salvagers()
    var members := _members_from_operation(operation)
    if members.is_empty():
        _abort_operation(operation, "All Scrappers assigned to Salvage focus were lost.")
        operation.clear()
        return

    operation["replan_clock"] = float(operation.get("replan_clock", 0.0)) + delta
    var assignments: Dictionary = operation.get("assignments", {})
    var used_targets: Array[Node] = []
    for raw_assignment in assignments.values():
        if raw_assignment is Dictionary:
            var target: Node = (raw_assignment as Dictionary).get("target")
            if target != null and is_instance_valid(target) and target not in used_targets:
                used_targets.append(target)

    var has_work := false
    var total_carried := 0
    for robot in members:
        var key := _assignment_key(robot)
        var assignment: Dictionary = assignments.get(key, _blank_salvage_assignment(robot))
        assignment["robot"] = robot
        var state: StringName = StringName(str(assignment.get("state", "idle")))
        var target: Node = assignment.get("target")
        var target_valid := _salvage_target_valid_for_assignment(target, assignment)

        if state == &"idle" or not target_valid and state not in [&"returning", &"depositing"]:
            _release_salvage_assignment(assignment)
            assignment = _blank_salvage_assignment(robot)
            if _assign_best_salvage_target(robot, assignment, used_targets):
                target = assignment.get("target")
                used_targets.append(target)
                state = &"outbound"
                has_work = true
            else:
                state = &"idle"
                robot.set_group(&"salvage_wait", 0)
                robot.set_goal(
                    heartforge_reference.global_position + _salvage_wait_offset(robot),
                    "No safe unclaimed wreck is currently worth sending this Scrapper to; waiting for a site to free up rather than piling onto another machine's target.",
                    robot.move_speed * 0.65
                )

        state = StringName(str(assignment.get("state", state)))
        target = assignment.get("target")
        match state:
            &"outbound":
                if target != null and is_instance_valid(target):
                    has_work = true
                    robot.set_group(&"salvage_cell", int(robot.get_instance_id() % 997))
                    robot.set_goal(
                        target.global_position,
                        "Travelling to an independently selected wreck. Scrappers spread across useful sites instead of dog-piling the same scrap.",
                        robot.move_speed * 0.9
                    )
                    if robot.global_position.distance_to(target.global_position) <= 2.1:
                        robot.begin_robot_salvage(target)
                        assignment["state"] = &"working"
                        assignment["work_clock"] = 0.0
                        if noise_system != null:
                            noise_system.emit_noise(target.global_position, 19.0, 0.55, &"robot_salvage")
            &"working":
                has_work = true
                assignment["work_clock"] = float(assignment.get("work_clock", 0.0)) + delta
                if target == null or not is_instance_valid(target) or not target.has_method(&"has_scrap") or not bool(target.call(&"has_scrap")):
                    _send_scrapper_home(assignment)
                elif _danger_score(target.global_position) >= 3.4 and int(assignment.get("cargo", 0)) > 0:
                    _send_scrapper_home(assignment)
                elif robot.salvage_target == null and float(assignment.get("work_clock", 0.0)) >= 0.2:
                    robot.begin_robot_salvage(target)
            &"returning":
                has_work = true
                robot.set_group(&"salvage_return", int(robot.get_instance_id() % 997))
                robot.set_goal(
                    heartforge_reference.global_position + _deposit_offset(robot),
                    "Returning its own cargo physically while other Scrappers continue working elsewhere.",
                    robot.move_speed * 0.92
                )
                if robot.global_position.distance_to(heartforge_reference.global_position) <= SALVAGE_DEPOSIT_RADIUS:
                    _deposit_scrapper_cargo(assignment)
                    _release_salvage_assignment(assignment)
                    assignment = _blank_salvage_assignment(robot)
                    if _assign_best_salvage_target(robot, assignment, used_targets):
                        var next_target: Node = assignment.get("target")
                        used_targets.append(next_target)
                        has_work = true
            _:
                pass

        total_carried += int(assignment.get("cargo", 0))
        assignments[key] = assignment

    operation["assignments"] = assignments
    operation["cargo"] = total_carried
    _update_salvage_network_anchor(operation)
    if operation_detail_director != null:
        var detail_mode: StringName = operation_detail_director.update_operation(GROUP_SALVAGE, operation.get("anchor", heartforge_reference.global_position))
        operation["detail_mode"] = detail_mode
    _refresh_salvage_escort_assignments()
    _position_salvage_scouts()
    if operation_detail_director != null and StringName(operation.get("detail_mode", &"active")) == &"reduced":
        operation_detail_director.apply_reduced_salvage(assignments, heartforge_reference.global_position)

    var available := _available_salvage_piles()
    if not has_work and available.is_empty() and total_carried <= 0:
        operation["idle_clock"] = float(operation.get("idle_clock", 0.0)) + delta
        if float(operation.get("idle_clock", 0.0)) >= 1.0:
            _complete_distributed_salvage(operation)
    else:
        operation["idle_clock"] = 0.0


func _blank_salvage_assignment(robot: RobotUnit3D) -> Dictionary:
    return {
        "robot": robot,
        "state": &"idle",
        "target": null,
        "reservation": &"",
        "cargo": 0,
        "work_clock": 0.0,
        "cycles": 0,
    }


func _assignment_key(robot: RobotUnit3D) -> String:
    return str(robot.get_instance_id())


func _reservation_id(robot: RobotUnit3D) -> StringName:
    return StringName("salvage_%s" % _assignment_key(robot))


func _assign_best_salvage_target(robot: RobotUnit3D, assignment: Dictionary, used_targets: Array[Node]) -> bool:
    var candidates := _available_salvage_piles()
    var best: SalvagePile3D
    var best_score := INF
    for pile in candidates:
        if pile in used_targets:
            continue
        var reservation := _reservation_id(robot)
        if pile.reserved_by_group != &"" and pile.reserved_by_group != reservation:
            continue
        var score := _salvage_site_score(robot, pile, used_targets)
        if score < best_score:
            best = pile
            best_score = score
    if best == null:
        return false
    var reservation_id := _reservation_id(robot)
    if not best.reserve(reservation_id):
        return false
    assignment["target"] = best
    assignment["reservation"] = reservation_id
    assignment["state"] = &"outbound"
    assignment["work_clock"] = 0.0
    assignment["site_score"] = best_score
    return true


func _salvage_site_score(robot: RobotUnit3D, pile: SalvagePile3D, used_targets: Array[Node]) -> float:
    var travel := robot.global_position.distance_to(pile.global_position)
    var home_distance := heartforge_reference.global_position.distance_to(pile.global_position)
    var danger := _danger_score(pile.global_position)
    var value_bonus := minf(13.0, float(pile.remaining_scrap) * 0.12)
    var crowd_penalty := 0.0
    for other in used_targets:
        if other == null or not is_instance_valid(other) or not (other is Node3D):
            continue
        var separation := pile.global_position.distance_to((other as Node3D).global_position)
        if separation < 10.0:
            crowd_penalty += (10.0 - separation) * 2.8
    # The score deliberately values nearby, high-yield and relatively safe
    # sites, but preserves enough spacing that several Scrappers create a
    # distributed salvage network rather than a single moving blob.
    return travel + home_distance * 0.07 + danger * 7.0 + crowd_penalty - value_bonus


func _salvage_target_valid_for_assignment(target: Node, assignment: Dictionary) -> bool:
    if target == null or not is_instance_valid(target) or not (target is SalvagePile3D):
        return false
    var pile := target as SalvagePile3D
    if not pile.has_scrap():
        return false
    var reservation: StringName = assignment.get("reservation", &"")
    return pile.reserved_by_group == &"" or pile.reserved_by_group == reservation


func _send_scrapper_home(assignment: Dictionary) -> void:
    var robot: RobotUnit3D = assignment.get("robot")
    if robot != null and is_instance_valid(robot):
        robot.salvage_target = null
        robot.salvage_progress = 0.0
    assignment["state"] = &"returning"


func _deposit_scrapper_cargo(assignment: Dictionary) -> void:
    var cargo := int(assignment.get("cargo", 0))
    if cargo <= 0:
        return
    var robot: RobotUnit3D = assignment.get("robot")
    run_state.add_scrap(cargo, true)
    salvage_operation["delivered"] = int(salvage_operation.get("delivered", 0)) + cargo
    run_state.log_event("%s returned independently with %d Scrap while the wider salvage network kept operating." % [robot.name if robot != null else "A Scrapper", cargo])
    assignment["cargo"] = 0


func _release_salvage_assignment(assignment: Dictionary) -> void:
    if assignment.is_empty():
        return
    var target: Node = assignment.get("target")
    var reservation: StringName = assignment.get("reservation", &"")
    if target != null and is_instance_valid(target) and target.has_method(&"release_reservation") and reservation != &"":
        target.call(&"release_reservation", reservation)
    var robot: RobotUnit3D = assignment.get("robot")
    if robot != null and is_instance_valid(robot):
        robot.salvage_target = null
        robot.salvage_progress = 0.0
    assignment["target"] = null
    assignment["reservation"] = &""


func _available_salvage_piles() -> Array[SalvagePile3D]:
    var result: Array[SalvagePile3D] = []
    for candidate in get_tree().get_nodes_in_group(&"salvage_piles"):
        if not is_instance_valid(candidate) or not (candidate is SalvagePile3D):
            continue
        var pile := candidate as SalvagePile3D
        if pile.has_scrap():
            result.append(pile)
    return result


func _danger_score(position: Vector3) -> float:
    var score := 0.0
    for enemy in get_tree().get_nodes_in_group(&"organic_enemies"):
        if not is_instance_valid(enemy) or not (enemy is Node3D):
            continue
        var distance := position.distance_to((enemy as Node3D).global_position)
        if distance <= 7.0:
            score += 1.4
        elif distance <= 13.0:
            score += 0.65
        elif distance <= 21.0:
            score += 0.18
    return score


func _update_salvage_network_anchor(operation: Dictionary) -> void:
    var assignments: Dictionary = operation.get("assignments", {})
    var points: Array[Vector3] = []
    var first_target: Node = null
    for raw_assignment in assignments.values():
        if not (raw_assignment is Dictionary):
            continue
        var assignment := raw_assignment as Dictionary
        var robot: RobotUnit3D = assignment.get("robot")
        var target: Node = assignment.get("target")
        var state: StringName = assignment.get("state", &"idle")
        if target != null and is_instance_valid(target) and state in [&"outbound", &"working"]:
            points.append((target as Node3D).global_position)
            if first_target == null:
                first_target = target
        elif robot != null and is_instance_valid(robot) and state == &"returning":
            points.append(robot.global_position)
    if points.is_empty():
        operation["anchor"] = heartforge_reference.global_position
        operation["target_node"] = null
        operation["target_position"] = heartforge_reference.global_position
        return
    var centroid := Vector3.ZERO
    for point in points:
        centroid += point
    centroid /= float(points.size())
    var old_anchor: Vector3 = operation.get("anchor", centroid)
    var forward := centroid - old_anchor
    forward.y = 0.0
    if forward.length_squared() > 0.05:
        operation["last_forward"] = forward.normalized()
    operation["anchor"] = centroid
    operation["target_node"] = first_target
    operation["target_position"] = centroid


func _active_salvage_protection_points() -> Array[Vector3]:
    var result: Array[Vector3] = []
    if salvage_operation.is_empty():
        return result
    var assignments: Dictionary = salvage_operation.get("assignments", {})
    for raw_assignment in assignments.values():
        if not (raw_assignment is Dictionary):
            continue
        var assignment := raw_assignment as Dictionary
        var robot: RobotUnit3D = assignment.get("robot")
        var target: Node = assignment.get("target")
        var state: StringName = assignment.get("state", &"idle")
        var point := Vector3.ZERO
        var valid := false
        if target != null and is_instance_valid(target) and state in [&"outbound", &"working"]:
            point = (target as Node3D).global_position
            valid = true
        elif robot != null and is_instance_valid(robot) and state == &"returning":
            point = robot.global_position
            valid = true
        if not valid:
            continue
        var too_close := false
        for existing in result:
            if existing.distance_to(point) < 5.0:
                too_close = true
                break
        if not too_close:
            result.append(point)
    if result.is_empty():
        result.append(salvage_operation.get("anchor", heartforge_reference.global_position))
    return result


func _salvage_wait_offset(robot: RobotUnit3D) -> Vector3:
    var angle := fmod(float(robot.get_instance_id()) * 0.731, TAU)
    return Vector3(cos(angle) * 5.8, 0.0, sin(angle) * 5.8)


func _deposit_offset(robot: RobotUnit3D) -> Vector3:
    var angle := fmod(float(robot.get_instance_id()) * 1.177, TAU)
    return Vector3(cos(angle) * 2.8, 0.0, sin(angle) * 2.8)


func _complete_distributed_salvage(operation: Dictionary) -> void:
    var delivered := int(operation.get("delivered", 0))
    for raw_assignment in (operation.get("assignments", {}) as Dictionary).values():
        if raw_assignment is Dictionary:
            _release_salvage_assignment(raw_assignment as Dictionary)
    for robot in _salvage_guardians(&"salvage_guardians") + _salvage_guardians(&"player_guardians") + _salvage_scouts():
        if is_instance_valid(robot):
            robot.set_group(&"reserve", 0)
    salvage_operation.clear()
    if operation_detail_director != null:
        operation_detail_director.clear_operation(GROUP_SALVAGE)
    operation_changed.emit(&"salvage", &"complete", "The distributed salvage network exhausted its currently useful wrecks after returning %d Scrap." % delivered)


func _on_robot_salvage_completed(robot: RobotUnit3D, pile: Node, amount: int) -> void:
    if salvage_operation.is_empty() or not bool(salvage_operation.get("distributed", false)):
        return
    var assignments: Dictionary = salvage_operation.get("assignments", {})
    var key := _assignment_key(robot)
    if not assignments.has(key):
        return
    var assignment: Dictionary = assignments[key]
    assignment["cargo"] = int(assignment.get("cargo", 0)) + max(0, amount)
    assignment["cycles"] = int(assignment.get("cycles", 0)) + 1
    assignment["work_clock"] = 0.0
    if amount > 0:
        run_state.log_event("%s dismantled %d Scrap at its own assigned wreck." % [robot.name, amount])

    var capacity := 34 + robot.level * 8
    var pile_empty := pile == null or not is_instance_valid(pile) or not pile.has_method(&"has_scrap") or not bool(pile.call(&"has_scrap"))
    var dangerous := pile != null and is_instance_valid(pile) and _danger_score((pile as Node3D).global_position) >= 3.2
    if int(assignment.get("cargo", 0)) >= capacity or pile_empty or dangerous:
        _send_scrapper_home(assignment)
    else:
        # Re-evaluate after each extraction. If another unclaimed site is
        # materially better, move instead of mindlessly stripping one pile to
        # zero. Otherwise continue working the current useful wreck.
        var used: Array[Node] = []
        for raw_other in assignments.values():
            if raw_other is Dictionary:
                var other_target: Node = (raw_other as Dictionary).get("target")
                if other_target != null and is_instance_valid(other_target) and other_target != pile:
                    used.append(other_target)
        var current_score := _salvage_site_score(robot, pile as SalvagePile3D, used) if not pile_empty else INF
        var alternative := _best_unreserved_salvage_for_robot(robot, used)
        if alternative != null:
            var alternative_score := _salvage_site_score(robot, alternative, used)
            if alternative_score + 7.0 < current_score:
                _release_salvage_assignment(assignment)
                _assign_specific_salvage_target(robot, assignment, alternative)
            else:
                robot.begin_robot_salvage(pile)
        elif not pile_empty:
            robot.begin_robot_salvage(pile)
    assignments[key] = assignment
    salvage_operation["assignments"] = assignments


func _best_unreserved_salvage_for_robot(robot: RobotUnit3D, used: Array[Node]) -> SalvagePile3D:
    var best: SalvagePile3D
    var best_score := INF
    for pile in _available_salvage_piles():
        if pile in used or pile.reserved_by_group != &"":
            continue
        var score := _salvage_site_score(robot, pile, used)
        if score < best_score:
            best = pile
            best_score = score
    return best


func _assign_specific_salvage_target(robot: RobotUnit3D, assignment: Dictionary, pile: SalvagePile3D) -> bool:
    var reservation := _reservation_id(robot)
    if pile == null or not pile.reserve(reservation):
        return false
    assignment["target"] = pile
    assignment["reservation"] = reservation
    assignment["state"] = &"outbound"
    assignment["work_clock"] = 0.0
    return true


func _refresh_salvage_escort_assignments() -> void:
    if salvage_operation.is_empty() or player_reference == null:
        return
    var guardians := living_robots(&"guardian")
    if guardians.is_empty():
        salvage_operation["salvage_guardians"] = []
        salvage_operation["player_guardians"] = []
        return

    var protection_points := _active_salvage_protection_points()
    var nearest_player_distance := INF
    for point in protection_points:
        nearest_player_distance = minf(nearest_player_distance, player_reference.global_position.distance_to(point))
    if nearest_player_distance == INF:
        nearest_player_distance = player_reference.global_position.distance_to(heartforge_reference.global_position)
    # The Bulwark already covers the Mechromancer at the Heartforge. Keep that
    # guaranteed personal interception in the split decision even after the
    # salvage network has moved its operational anchor to a remote wreck.
    nearest_player_distance = minf(
        nearest_player_distance,
        player_reference.global_position.distance_to(heartforge_reference.global_position)
    )

    var player_guard_count := 0
    if guardians.size() >= 2 and nearest_player_distance >= SALVAGE_PLAYER_SPLIT_DISTANCE:
        player_guard_count = 1
    if guardians.size() >= 4 and nearest_player_distance >= SALVAGE_WIDE_SPLIT_DISTANCE:
        player_guard_count = mini(guardians.size() - 1, int(ceil(float(guardians.size()) * 0.45)))
    elif guardians.size() >= 5 and player_reference.is_channeling():
        player_guard_count = maxi(player_guard_count, 2)

    var salvage_guard_count := guardians.size() - player_guard_count
    if salvage_guard_count <= 0:
        salvage_guard_count = 1
        player_guard_count = guardians.size() - 1

    # Put the Wardens most useful to the salvage area there first. The split is
    # re-evaluated continuously, so it changes as the Scrappers and player move.
    guardians.sort_custom(func(a: RobotUnit3D, b: RobotUnit3D) -> bool:
        return _distance_to_nearest_point(a.global_position, protection_points) < _distance_to_nearest_point(b.global_position, protection_points)
    )

    var salvage_guardians: Array[RobotUnit3D] = []
    var player_guardians: Array[RobotUnit3D] = []
    for index in range(guardians.size()):
        if index < salvage_guard_count:
            salvage_guardians.append(guardians[index])
        else:
            player_guardians.append(guardians[index])
    salvage_operation["salvage_guardians"] = salvage_guardians
    salvage_operation["player_guardians"] = player_guardians
    _position_salvage_escort_guardians(salvage_guardians, protection_points)
    _position_player_guardians(player_guardians)


func _position_salvage_escort_guardians(guardians: Array[RobotUnit3D], protection_points: Array[Vector3] = []) -> void:
    if salvage_operation.is_empty():
        return
    if protection_points.is_empty():
        protection_points = _active_salvage_protection_points()
    var forward: Vector3 = salvage_operation.get("last_forward", Vector3.FORWARD)
    for index in range(guardians.size()):
        var guardian := guardians[index]
        var point_index := index % maxi(1, protection_points.size())
        var anchor := protection_points[point_index]
        var local_index := int(index / maxi(1, protection_points.size()))
        var local_count := int(ceil(float(guardians.size()) / float(maxi(1, protection_points.size()))))
        var offset := FormationRules3D.salvage_escort_offset(local_index + point_index, maxi(4, local_count))
        var desired := anchor + FormationRules3D.rotated_offset(offset, forward)
        guardian.set_group(&"salvage_escort", index)
        guardian.set_goal(
            desired,
            "Covering one vulnerable salvage cell while the other Wardens spread across the wider network. Protection follows the Scrappers instead of remaining at the Heartforge.",
            guardian.move_speed * 0.92
        )


func _position_player_guardians(guardians: Array[RobotUnit3D]) -> void:
    if player_reference == null:
        return
    for index in range(guardians.size()):
        var guardian := guardians[index]
        var desired := player_reference.global_position + FormationRules3D.player_escort_offset(index, guardians.size())
        guardian.set_group(&"mechromancer_escort", index)
        guardian.set_goal(
            desired,
            "Covering the Mechromancer outside the Bulwark's immediate interception zone while the rest of the Wardens protect active salvage cells.",
            guardian.move_speed * 0.94
        )


func _position_salvage_scouts() -> void:
    if salvage_operation.is_empty():
        return
    var scouts := _salvage_scouts()
    if scouts.is_empty():
        return
    var points := _active_salvage_protection_points()
    var anchor: Vector3 = salvage_operation.get("anchor", heartforge_reference.global_position)
    var forward: Vector3 = salvage_operation.get("last_forward", Vector3(0.0, 0.0, -1.0))
    if forward.length_squared() < 0.01:
        forward = Vector3(0.0, 0.0, -1.0)
    var right := Vector3(forward.z, 0.0, -forward.x).normalized()
    for index in range(scouts.size()):
        var scout := scouts[index]
        var side := -1.0 if index % 2 == 0 else 1.0
        var desired := anchor + forward.normalized() * 8.0 + right * side * (5.0 + float(index / 2) * 2.0)
        scout.set_group(&"salvage_screen", index)
        scout.set_goal(desired, "Screening ahead of the distributed salvage cells and revealing threats before they reach vulnerable Scrappers.", scout.move_speed * 0.9)


func _distance_to_nearest_point(position: Vector3, points: Array[Vector3]) -> float:
    var best := INF
    for point in points:
        best = minf(best, position.distance_to(point))
    return best


func _salvage_scouts() -> Array[RobotUnit3D]:
    var result: Array[RobotUnit3D] = []
    if salvage_operation.is_empty():
        return result
    for scout in salvage_operation.get("salvage_scouts", []):
        if is_instance_valid(scout) and scout is RobotUnit3D and scout.is_alive():
            result.append(scout)
    salvage_operation["salvage_scouts"] = result
    return result


# -----------------------------------------------------------------------------
# Coordinated expeditions
# -----------------------------------------------------------------------------

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
    if bool(operation.get("distributed", false)) and operation.get("kind", &"") == &"salvage":
        _update_distributed_salvage(operation, delta)
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
        _apply_reduced_detail(operation, members)
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
    _apply_reduced_detail(operation, members)


func _apply_reduced_detail(operation: Dictionary, members: Array[RobotUnit3D]) -> void:
    if operation_detail_director == null:
        return
    var operation_id := StringName(operation.get("id", &"operation"))
    var detail_mode: StringName = operation_detail_director.update_operation(operation_id, operation.get("anchor", heartforge_reference.global_position))
    operation["detail_mode"] = detail_mode
    if detail_mode == &"reduced":
        operation_detail_director.apply_reduced_formation(
            operation.get("anchor", heartforge_reference.global_position),
            operation.get("last_forward", Vector3.FORWARD),
            members
        )


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
    if bool(operation.get("core_secured", false)):
        run_state.add_rare_core(1)
        run_state.log_event("North Ruins expedition returned with a rare Cognition Core.")
    expedition_operation.clear()
    if operation_detail_director != null:
        operation_detail_director.clear_operation(GROUP_EXPEDITION)
    expedition_returned.emit()
    operation_changed.emit(&"expedition", &"complete", "The coordinated expedition has returned to the Heartforge.")


func _abort_operation(operation: Dictionary, reason: String) -> void:
    if operation.is_empty():
        return
    if bool(operation.get("distributed", false)) and operation.get("kind", &"") == &"salvage":
        var assignments: Dictionary = operation.get("assignments", {})
        for raw_assignment in assignments.values():
            if raw_assignment is Dictionary:
                var assignment := raw_assignment as Dictionary
                var cargo := int(assignment.get("cargo", 0))
                var robot: RobotUnit3D = assignment.get("robot")
                # Cargo is physical. An abort does not teleport it into storage;
                # surviving Scrappers are recalled carrying it and will only be
                # credited if the operation is allowed to finish normally.
                _release_salvage_assignment(assignment)
                if robot != null and is_instance_valid(robot):
                    robot.set_group(&"reserve", 0)
                    robot.set_goal(heartforge_reference.global_position, "%s Carrying %d uncredited Scrap home." % [reason, cargo], robot.move_speed * 0.78)
        for robot in _salvage_guardians(&"salvage_guardians") + _salvage_guardians(&"player_guardians") + _salvage_scouts():
            if is_instance_valid(robot):
                robot.set_group(&"reserve", 0)
                robot.set_goal(heartforge_reference.global_position, reason, robot.move_speed * 0.78)
        if operation_detail_director != null:
            operation_detail_director.clear_operation(GROUP_SALVAGE)
        operation_changed.emit(&"salvage", &"aborted", reason)
        return

    var target: Node = operation.get("target_node")
    if target != null and is_instance_valid(target) and target.has_method(&"release_reservation"):
        target.call(&"release_reservation", operation.get("id", &""))
    for robot in _members_from_operation(operation):
        robot.set_group(&"reserve", 0)
        robot.set_goal(heartforge_reference.global_position, reason, robot.move_speed * 0.7)
    operation_changed.emit(operation.get("kind", &"operation"), &"aborted", reason)
    var operation_id := StringName(operation.get("id", &""))
    if operation_detail_director != null and operation_id != &"":
        operation_detail_director.clear_operation(operation_id)


func _on_robot_destroyed(robot: RobotUnit3D) -> void:
    robot_casualty.emit({
        "name": String(robot.name),
        "archetype": String(robot.archetype),
        "level": robot.level,
        "callsign": robot.display_identity(),
        "position": robot.global_position,
    })
    robot_lost.emit(robot.name, robot.global_position)
    if not salvage_operation.is_empty() and bool(salvage_operation.get("distributed", false)):
        var assignments: Dictionary = salvage_operation.get("assignments", {})
        var key := _assignment_key(robot)
        if assignments.has(key):
            _release_salvage_assignment(assignments[key])
            assignments.erase(key)
            salvage_operation["assignments"] = assignments
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


func _salvage_guardians(key: StringName) -> Array[RobotUnit3D]:
    var result: Array[RobotUnit3D] = []
    if salvage_operation.is_empty():
        return result
    var raw_guardians: Array = salvage_operation.get(String(key), salvage_operation.get(key, []))
    for guardian in raw_guardians:
        if is_instance_valid(guardian) and guardian is RobotUnit3D and guardian.is_alive():
            result.append(guardian)
    salvage_operation[String(key)] = result
    return result


func _maximum_member_separation(operation: Dictionary) -> float:
    var anchor: Vector3 = operation.get("anchor", heartforge_reference.global_position)
    var maximum := 0.0
    for robot in _members_from_operation(operation):
        maximum = maxf(maximum, robot.global_position.distance_to(anchor))
    return maximum


func _operation_base_pace(members: Array[RobotUnit3D], kind: StringName) -> float:
    if members.is_empty():
        return 0.0
    var slowest := 999.0
    for robot in members:
        slowest = minf(slowest, robot.move_speed)
    var pace_factor := 0.66
    if kind == &"expedition":
        pace_factor += float(run_state.level_for(&"scout") - 1) * 0.11
    return slowest * pace_factor


func _hostile_near_anchor(anchor: Vector3, radius: float) -> bool:
    for enemy in get_tree().get_nodes_in_group(&"organic_enemies"):
        if is_instance_valid(enemy) and enemy is Node3D and anchor.distance_to(enemy.global_position) <= radius:
            return true
    return false


func _nearest_available_salvage() -> SalvagePile3D:
    var best: SalvagePile3D
    var best_distance := INF
    for candidate in _available_salvage_piles():
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
        # Follow the most exposed active Scrapper, which makes the camera useful
        # during a distributed network rather than always following slot zero.
        var best: RobotUnit3D
        var best_danger := -1.0
        var assignments: Dictionary = salvage_operation.get("assignments", {})
        for raw_assignment in assignments.values():
            if not (raw_assignment is Dictionary):
                continue
            var assignment := raw_assignment as Dictionary
            var robot: RobotUnit3D = assignment.get("robot")
            if robot == null or not is_instance_valid(robot):
                continue
            var danger := _danger_score(robot.global_position)
            if danger > best_danger:
                best = robot
                best_danger = danger
        if best != null:
            return best
    return null


func salvage_coverage_snapshot() -> Dictionary:
    if salvage_operation.is_empty():
        return {
            "active": false,
            "salvage_guardians": 0,
            "player_guardians": 0,
            "bulwark_personal_guard": count_robots(&"companion") > 0,
            "scrappers": 0,
            "active_sites": 0,
        }
    var active_sites := _active_salvage_protection_points().size()
    return {
        "active": true,
        "salvage_guardians": _salvage_guardians(&"salvage_guardians").size(),
        "player_guardians": _salvage_guardians(&"player_guardians").size(),
        "bulwark_personal_guard": count_robots(&"companion") > 0,
        "player_to_salvage_distance": player_reference.global_position.distance_to(salvage_operation.get("anchor", heartforge_reference.global_position)),
        "scrappers": _members_from_operation(salvage_operation).size(),
        "active_sites": active_sites,
        "delivered": int(salvage_operation.get("delivered", 0)),
    }


func operation_summary() -> String:
    if not expedition_operation.is_empty():
        return "North expedition: %s" % String(expedition_operation.get("state", &"unknown")).capitalize()
    if not salvage_operation.is_empty():
        var coverage := salvage_coverage_snapshot()
        return "Salvage net · %d Scrappers / %d sites · carrying %d · escort %d field / %d mech + Bulwark" % [
            int(coverage.get("scrappers", 0)),
            int(coverage.get("active_sites", 0)),
            int(salvage_operation.get("cargo", 0)),
            int(coverage.get("salvage_guardians", 0)),
            int(coverage.get("player_guardians", 0)),
        ]
    return "No remote operation"


func to_dictionary() -> Dictionary:
    return {
        "schema_version": 1,
        "salvage_operation": _serialize_salvage_operation(),
        "expedition_operation": _serialize_field_operation(expedition_operation),
    }


func restore_from_dictionary(data: Dictionary) -> void:
    salvage_operation.clear()
    expedition_operation.clear()
    _restore_field_operation(data.get("expedition_operation", {}))
    if expedition_operation.is_empty():
        _restore_salvage_operation(data.get("salvage_operation", {}))


func _serialize_field_operation(operation: Dictionary) -> Dictionary:
    if operation.is_empty():
        return {}
    var member_names: Array[String] = []
    for member in operation.get("members", []):
        if is_instance_valid(member) and member is RobotUnit3D:
            member_names.append(String((member as RobotUnit3D).name))
    var route_values: Array = []
    var route: PackedVector3Array = operation.get("route", PackedVector3Array())
    for point in route:
        route_values.append(_vector_to_array(point))
    return {
        "id": String(operation.get("id", &"")),
        "kind": String(operation.get("kind", &"expedition")),
        "state": String(operation.get("state", &"outbound")),
        "member_names": member_names,
        "target_position": _vector_to_array(operation.get("target_position", NORTH_RUINS)),
        "anchor": _vector_to_array(operation.get("anchor", heartforge_reference.global_position)),
        "route": route_values,
        "route_index": int(operation.get("route_index", 1)),
        "work_clock": float(operation.get("work_clock", 0.0)),
        "work_duration": float(operation.get("work_duration", 7.0)),
        "cargo": int(operation.get("cargo", 0)),
        "core_secured": bool(operation.get("core_secured", false)),
        "last_forward": _vector_to_array(operation.get("last_forward", Vector3.FORWARD)),
    }


func _serialize_salvage_operation() -> Dictionary:
    if salvage_operation.is_empty():
        return {}
    var member_names: Array[String] = []
    for member in salvage_operation.get("members", []):
        if is_instance_valid(member) and member is RobotUnit3D:
            member_names.append(String((member as RobotUnit3D).name))
    var assignments: Dictionary = {}
    for raw_assignment in (salvage_operation.get("assignments", {}) as Dictionary).values():
        if not (raw_assignment is Dictionary):
            continue
        var assignment := raw_assignment as Dictionary
        var robot: RobotUnit3D = assignment.get("robot")
        if robot == null or not is_instance_valid(robot):
            continue
        var target: SalvagePile3D = assignment.get("target") as SalvagePile3D
        assignments[String(robot.name)] = {
            "state": String(assignment.get("state", &"idle")),
            "target_position": _vector_to_array(target.global_position) if target != null else [],
            "target_display_name": target.display_name if target != null else "",
            "cargo": int(assignment.get("cargo", 0)),
            "work_clock": float(assignment.get("work_clock", 0.0)),
            "cycles": int(assignment.get("cycles", 0)),
            "site_score": float(assignment.get("site_score", 0.0)),
        }
    return {
        "id": String(salvage_operation.get("id", GROUP_SALVAGE)),
        "kind": String(salvage_operation.get("kind", &"salvage")),
        "state": String(salvage_operation.get("state", &"distributed")),
        "distributed": bool(salvage_operation.get("distributed", true)),
        "member_names": member_names,
        "assignments": assignments,
        "salvage_guardian_names": _robot_names(salvage_operation.get("salvage_guardians", [])),
        "player_guardian_names": _robot_names(salvage_operation.get("player_guardians", [])),
        "salvage_scout_names": _robot_names(salvage_operation.get("salvage_scouts", [])),
        "anchor": _vector_to_array(salvage_operation.get("anchor", heartforge_reference.global_position)),
        "target_position": _vector_to_array(salvage_operation.get("target_position", heartforge_reference.global_position)),
        "cargo": int(salvage_operation.get("cargo", 0)),
        "delivered": int(salvage_operation.get("delivered", 0)),
        "replan_clock": float(salvage_operation.get("replan_clock", 0.0)),
        "idle_clock": float(salvage_operation.get("idle_clock", 0.0)),
        "last_forward": _vector_to_array(salvage_operation.get("last_forward", Vector3.FORWARD)),
    }


func _restore_field_operation(raw_data: Variant) -> void:
    if not (raw_data is Dictionary):
        return
    var saved := raw_data as Dictionary
    var members := _robots_by_names(saved.get("member_names", []))
    if members.is_empty():
        return
    var route := PackedVector3Array()
    for raw_point in saved.get("route", []):
        route.append(_array_to_vector(raw_point))
    expedition_operation = {
        "id": StringName(str(saved.get("id", GROUP_EXPEDITION))),
        "kind": StringName(str(saved.get("kind", "expedition"))),
        "state": StringName(str(saved.get("state", "outbound"))),
        "members": members,
        "target_node": null,
        "target_position": _array_to_vector(saved.get("target_position", [NORTH_RUINS.x, NORTH_RUINS.y, NORTH_RUINS.z])),
        "anchor": _array_to_vector(saved.get("anchor", [heartforge_reference.global_position.x, heartforge_reference.global_position.y, heartforge_reference.global_position.z])),
        "route": route,
        "route_index": maxi(1, int(saved.get("route_index", 1))),
        "work_clock": maxf(0.0, float(saved.get("work_clock", 0.0))),
        "work_duration": maxf(0.1, float(saved.get("work_duration", 7.0))),
        "cargo": maxi(0, int(saved.get("cargo", 0))),
        "core_secured": bool(saved.get("core_secured", false)),
        "last_forward": _array_to_vector(saved.get("last_forward", [0.0, 0.0, -1.0])),
    }
    for index in range(members.size()):
        members[index].set_group(GROUP_EXPEDITION, index)
    set_process(false)
    operation_changed.emit(&"expedition", StringName(expedition_operation.get("state", &"outbound")), "The saved expedition resumed its physical route.")


func _restore_salvage_operation(raw_data: Variant) -> void:
    if not (raw_data is Dictionary) or not bool((raw_data as Dictionary).get("distributed", false)):
        return
    var saved := raw_data as Dictionary
    var members := _robots_by_names(saved.get("member_names", []))
    if members.is_empty():
        return
    salvage_operation = {
        "id": StringName(str(saved.get("id", GROUP_SALVAGE))),
        "kind": &"salvage",
        "state": &"distributed",
        "distributed": true,
        "members": members,
        "assignments": {},
        "salvage_guardians": _robots_by_names(saved.get("salvage_guardian_names", [])),
        "player_guardians": _robots_by_names(saved.get("player_guardian_names", [])),
        "salvage_scouts": _robots_by_names(saved.get("salvage_scout_names", [])),
        "anchor": _array_to_vector(saved.get("anchor", [heartforge_reference.global_position.x, heartforge_reference.global_position.y, heartforge_reference.global_position.z])),
        "target_node": null,
        "target_position": _array_to_vector(saved.get("target_position", [heartforge_reference.global_position.x, heartforge_reference.global_position.y, heartforge_reference.global_position.z])),
        "last_forward": _array_to_vector(saved.get("last_forward", [0.0, 0.0, -1.0])),
        "cargo": maxi(0, int(saved.get("cargo", 0))),
        "delivered": maxi(0, int(saved.get("delivered", 0))),
        "replan_clock": maxf(0.0, float(saved.get("replan_clock", 0.0))),
        "idle_clock": maxf(0.0, float(saved.get("idle_clock", 0.0))),
    }
    var saved_assignments: Dictionary = saved.get("assignments", {})
    var restored_assignments: Dictionary = {}
    for raw_name in saved_assignments:
        var robot := _find_robot_by_name(str(raw_name))
        if robot == null or robot not in members or not (saved_assignments[raw_name] is Dictionary):
            continue
        var saved_assignment := saved_assignments[raw_name] as Dictionary
        var assignment := _blank_salvage_assignment(robot)
        assignment["state"] = StringName(str(saved_assignment.get("state", "idle")))
        assignment["cargo"] = maxi(0, int(saved_assignment.get("cargo", 0)))
        assignment["work_clock"] = maxf(0.0, float(saved_assignment.get("work_clock", 0.0)))
        assignment["cycles"] = maxi(0, int(saved_assignment.get("cycles", 0)))
        assignment["site_score"] = float(saved_assignment.get("site_score", 0.0))
        var target := _find_salvage_pile(saved_assignment.get("target_position", []), str(saved_assignment.get("target_display_name", "")))
        if target != null and assignment["state"] != &"idle":
            var reservation := _reservation_id(robot)
            if target.reserve(reservation):
                assignment["target"] = target
                assignment["reservation"] = reservation
            else:
                assignment["state"] = &"idle"
        restored_assignments[_assignment_key(robot)] = assignment
    salvage_operation["assignments"] = restored_assignments
    _refresh_distributed_salvagers()
    _refresh_salvage_escort_assignments()
    set_process(true)
    operation_changed.emit(&"salvage", &"distributed", "The saved salvage network resumed its physical assignments.")


func _robot_names(raw_robots: Variant) -> Array[String]:
    var result: Array[String] = []
    for raw_robot in raw_robots:
        if is_instance_valid(raw_robot) and raw_robot is RobotUnit3D:
            result.append(String((raw_robot as RobotUnit3D).name))
    return result


func _robots_by_names(raw_names: Variant) -> Array[RobotUnit3D]:
    var result: Array[RobotUnit3D] = []
    for raw_name in raw_names:
        var robot := _find_robot_by_name(str(raw_name))
        if robot != null and robot.is_alive() and robot not in result:
            result.append(robot)
    return result


func _find_robot_by_name(robot_name: String) -> RobotUnit3D:
    for node in get_tree().get_nodes_in_group(&"friendly_robots"):
        if node is RobotUnit3D and String((node as RobotUnit3D).name) == robot_name:
            return node as RobotUnit3D
    return null


func _find_salvage_pile(raw_position: Variant, display_name: String) -> SalvagePile3D:
    var position := _array_to_vector(raw_position)
    for node in get_tree().get_nodes_in_group(&"salvage_piles"):
        if not (node is SalvagePile3D) or not is_instance_valid(node):
            continue
        var pile := node as SalvagePile3D
        if pile.global_position.distance_to(position) <= 0.2 and (display_name.is_empty() or pile.display_name == display_name):
            return pile
    return null


func _vector_to_array(value: Vector3) -> Array[float]:
    return [value.x, value.y, value.z]


func _array_to_vector(value: Variant) -> Vector3:
    if value is Array and value.size() >= 3:
        return Vector3(float(value[0]), float(value[1]), float(value[2]))
    return Vector3.ZERO
