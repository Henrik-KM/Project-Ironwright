class_name OutpostDirector3D
extends Node

signal site_discovered(site: OutpostSite3D)
signal operation_changed(kind: StringName, state: StringName, detail: String)
signal outpost_changed(outpost: Outpost3D)
signal outpost_destroyed(outpost: Outpost3D)
signal haul_returned(amount: int)

const ROLES: Array[StringName] = [&"resource", &"defence", &"scout", &"repair"]
const ROLE_EFFECTS: Dictionary = {
    &"resource": &"outpost_role_resource",
    &"defence": &"outpost_role_defence",
    &"scout": &"outpost_role_scout",
    &"repair": &"outpost_role_repair",
}

var run_state: RunState3D
var progression: ProgressionDirector3D
var noise_system: NoiseSystem3D
var autonomy_director: AutonomyDirector3D
var heartforge: Heartforge3D
var world_parent: Node3D
var operation_detail_director: Variant
var sites: Array[OutpostSite3D] = []
var operation: Dictionary = {}
var maintenance_clock: float = 0.0
var notification_cooldown: float = 0.0


func configure(
        next_run_state: RunState3D,
        next_progression: ProgressionDirector3D,
        next_noise_system: NoiseSystem3D,
        next_autonomy_director: AutonomyDirector3D,
        next_heartforge: Heartforge3D,
        next_world_parent: Node3D,
        next_operation_detail_director: Variant = null
    ) -> void:
    run_state = next_run_state
    progression = next_progression
    noise_system = next_noise_system
    autonomy_director = next_autonomy_director
    heartforge = next_heartforge
    world_parent = next_world_parent
    operation_detail_director = next_operation_detail_director


func register_site(site: OutpostSite3D) -> void:
    if site in sites:
        return
    sites.append(site)
    site.site_discovered.connect(_on_site_discovered)


func discover_sites_by(source_id: StringName) -> int:
    var count := 0
    for site in sites:
        if site.discovered_by == source_id and site.discover():
            count += 1
    return count


func discover_site(site_id: StringName) -> bool:
    var site := get_site(site_id)
    return site.discover() if site != null else false


func get_site(site_id: StringName) -> OutpostSite3D:
    for site in sites:
        if site.site_id == site_id:
            return site
    return null


func discovered_sites() -> Array[OutpostSite3D]:
    var result: Array[OutpostSite3D] = []
    for site in sites:
        if site.discovered:
            result.append(site)
    return result


func role_available(role: StringName) -> bool:
    if role not in ROLES or progression == null:
        return false
    var effect := StringName(ROLE_EFFECTS.get(role, &""))
    return effect != &"" and progression.has_effect(effect)


func build_cost(role: StringName, tier: int = 1) -> int:
    var base_cost := 76
    match role:
        &"defence":
            base_cost = 82
        &"scout":
            base_cost = 68
        &"repair":
            base_cost = 88
    return int(round(float(base_cost) * (1.0 + float(maxi(0, tier - 1)) * 0.72)))


func upgrade_cost(outpost: Outpost3D) -> int:
    return 9999 if outpost == null else 58 + outpost.tier * 42


func rebuild_cost(outpost: Outpost3D) -> int:
    if outpost == null:
        return 9999
    return maxi(28, int(round(float(build_cost(outpost.role, outpost.tier)) * 0.62)))


func can_authorize_build(site_id: StringName, role: StringName) -> bool:
    var site := get_site(site_id)
    if site == null or not site.discovered or site.has_outpost():
        return false
    if progression == null or progression.heartforge_tier < 2 or not role_available(role):
        return false
    if not operation.is_empty() or _other_remote_operation_active():
        return false
    if run_state.scrap < build_cost(role, 1):
        return false
    return not _select_team(&"build").is_empty()


func authorize_build(site_id: StringName, role: StringName) -> bool:
    if not can_authorize_build(site_id, role):
        return false
    var site := get_site(site_id)
    var cost := build_cost(role, 1)
    if not run_state.spend_scrap(cost):
        return false
    var team := _select_team(&"build")
    if not _start_operation(&"build", site, team, role, 1, cost):
        run_state.refund_scrap(cost)
        return false
    operation_changed.emit(&"outpost_build", &"outbound", "An Engineer and escort are physically travelling to %s." % site.display_name)
    return true


func can_authorize_upgrade(site_id: StringName) -> bool:
    var site := get_site(site_id)
    if site == null or not site.has_functioning_outpost():
        return false
    if progression == null or site.outpost.tier >= progression.maximum_outpost_tier():
        return false
    if not operation.is_empty() or _other_remote_operation_active():
        return false
    if run_state.scrap < upgrade_cost(site.outpost):
        return false
    return not _select_team(&"upgrade").is_empty()


func authorize_upgrade(site_id: StringName) -> bool:
    if not can_authorize_upgrade(site_id):
        return false
    var site := get_site(site_id)
    var next_tier := site.outpost.tier + 1
    var cost := upgrade_cost(site.outpost)
    if not run_state.spend_scrap(cost):
        return false
    var team := _select_team(&"upgrade")
    if not _start_operation(&"upgrade", site, team, site.outpost.role, next_tier, cost):
        run_state.refund_scrap(cost)
        return false
    operation_changed.emit(&"outpost_upgrade", &"outbound", "The protected upgrade team is travelling to %s." % site.display_name)
    return true


func _process(delta: float) -> void:
    maintenance_clock += delta
    notification_cooldown = maxf(0.0, notification_cooldown - delta)
    if not operation.is_empty():
        _update_operation(delta)
        return
    if maintenance_clock < 1.0:
        return
    maintenance_clock = 0.0
    if _other_remote_operation_active():
        return
    if _try_schedule_automatic_rebuild():
        return
    _try_schedule_resource_haul()


func _start_operation(
        kind: StringName,
        site: OutpostSite3D,
        members: Array[RobotUnit3D],
        role: StringName,
        target_tier: int,
        committed_scrap: int
    ) -> bool:
    if site == null or members.is_empty() or autonomy_director == null:
        return false
    if _other_remote_operation_active():
        return false

    autonomy_director.set_process(false)
    var group_id := StringName("outpost_%s" % String(kind))
    for index in range(members.size()):
        members[index].set_group(group_id, index)
    _hold_nonmembers_at_heartforge(members)

    operation = {
        "kind": kind,
        "state": &"outbound",
        "site": site,
        "members": members,
        "role": role,
        "target_tier": target_tier,
        "committed_scrap": committed_scrap,
        "route": _route_between(heartforge.global_position, site.global_position),
        "route_index": 1,
        "anchor": heartforge.global_position,
        "last_forward": Vector3(0.0, 0.0, -1.0),
        "work_clock": 0.0,
        "noise_clock": 0.0,
        "cargo": 0,
    }
    return true


func _update_operation(delta: float) -> void:
    var members := _living_operation_members()
    if members.is_empty():
        _abort_operation("Every robot assigned to the remote operation was lost.")
        return

    if operation_detail_director != null:
        operation["detail_mode"] = operation_detail_director.update_operation(StringName("outpost_%s" % String(operation.get("kind", &"operation"))), operation.get("anchor", heartforge.global_position))

    var state := StringName(operation.get("state", &"outbound"))
    if state == &"working":
        _update_work(delta)
        _position_members(0.0)
        _apply_reduced_detail()
        return

    var route: PackedVector3Array = operation.get("route", PackedVector3Array())
    var route_index := int(operation.get("route_index", 1))
    if route.is_empty() or route_index >= route.size():
        if state == &"outbound":
            operation["state"] = &"working"
            operation["work_clock"] = 0.0
            operation["noise_clock"] = 0.0
            operation_changed.emit(StringName(operation.get("kind", &"outpost")), &"working", "The complete group arrived and began autonomous work.")
        else:
            _complete_return()
        return

    var anchor: Vector3 = operation.get("anchor", heartforge.global_position)
    var waypoint: Vector3 = route[route_index]
    var direction := waypoint - anchor
    direction.y = 0.0
    if direction.length() <= 0.7:
        operation["route_index"] = route_index + 1
        return
    direction = direction.normalized()
    operation["last_forward"] = direction

    var separation := _maximum_separation(anchor, members)
    var pace_multiplier := FormationRules3D.pace_multiplier(separation)
    if _hostile_near(anchor, 9.5):
        pace_multiplier = 0.0
    var pace := _operation_pace(members) * pace_multiplier
    anchor += direction * pace * delta
    operation["anchor"] = anchor
    _position_members(pace)
    _apply_reduced_detail()


func _apply_reduced_detail() -> void:
    if operation_detail_director == null or StringName(operation.get("detail_mode", &"active")) != &"reduced":
        return
    operation_detail_director.apply_reduced_formation(
        operation.get("anchor", heartforge.global_position),
        operation.get("last_forward", Vector3.FORWARD),
        operation.get("members", [])
    )


func _position_members(group_speed: float) -> void:
    var members := _living_operation_members()
    var anchor: Vector3 = operation.get("anchor", heartforge.global_position)
    var forward: Vector3 = operation.get("last_forward", Vector3.FORWARD)
    for index in range(members.size()):
        var robot := members[index]
        var offset := FormationRules3D.formation_offset(index, robot.archetype)
        if robot.archetype == &"engineer":
            offset = Vector3(0.0, 0.0, 1.2 + float(index % 2))
        var desired := anchor + FormationRules3D.rotated_offset(offset, forward)
        robot.set_goal(
            desired,
            "Maintaining an escorted %s formation; the group slows and regroups instead of abandoning builders." % String(operation.get("kind", &"operation")),
            maxf(1.5, group_speed + 1.05)
        )


func _update_work(delta: float) -> void:
    operation["work_clock"] = float(operation.get("work_clock", 0.0)) + delta
    operation["noise_clock"] = float(operation.get("noise_clock", 0.0)) + delta
    var site := operation.get("site") as OutpostSite3D
    if site == null or not is_instance_valid(site):
        _abort_operation("The target site no longer exists.")
        return

    if float(operation.get("noise_clock", 0.0)) >= 1.15:
        operation["noise_clock"] = 0.0
        if noise_system != null:
            noise_system.emit_noise(site.global_position, 27.0, 0.72, &"outpost_construction")

    var kind := StringName(operation.get("kind", &"build"))
    var work_duration := (7.5 + float(int(operation.get("target_tier", 1))) * 2.2) / _construction_rate()
    if kind == &"haul":
        work_duration = 2.4
    if float(operation.get("work_clock", 0.0)) < work_duration:
        return

    match kind:
        &"build":
            var outpost := _spawn_outpost(site, StringName(operation.get("role", &"resource")), int(operation.get("target_tier", 1)))
            operation_changed.emit(&"outpost_build", &"constructed", "%s is now autonomous. The builders are returning home." % site.display_name)
            outpost_changed.emit(outpost)
        &"upgrade":
            if site.has_functioning_outpost():
                site.outpost.upgrade_to(int(operation.get("target_tier", site.outpost.tier + 1)))
                outpost_changed.emit(site.outpost)
                operation_changed.emit(&"outpost_upgrade", &"complete", "%s reached tier %d." % [site.display_name, site.outpost.tier])
        &"rebuild":
            if site.has_outpost():
                site.outpost.rebuild(int(operation.get("target_tier", site.outpost.tier)))
                outpost_changed.emit(site.outpost)
                operation_changed.emit(&"outpost_rebuild", &"complete", "%s was rebuilt automatically using reserved Scrap." % site.display_name)
        &"haul":
            if site.has_functioning_outpost():
                operation["cargo"] = site.outpost.take_stored_scrap(42)
                operation_changed.emit(&"outpost_haul", &"loaded", "The convoy loaded %d Scrap and is returning physically." % int(operation.get("cargo", 0)))
    _begin_return()


func _begin_return() -> void:
    operation["state"] = &"returning"
    var route: PackedVector3Array = operation.get("route", PackedVector3Array())
    var reverse_route := PackedVector3Array()
    for index in range(route.size() - 1, -1, -1):
        reverse_route.append(route[index])
    operation["route"] = reverse_route
    operation["route_index"] = 1
    var site := operation.get("site") as OutpostSite3D
    operation["anchor"] = site.global_position if site != null else heartforge.global_position
    operation["last_forward"] = Vector3(0.0, 0.0, 1.0)
    operation_changed.emit(StringName(operation.get("kind", &"outpost")), &"returning", "The machines are returning along the same persistent streets.")


func _complete_return() -> void:
    var detail_key := StringName("outpost_%s" % String(operation.get("kind", &"operation")))
    var cargo := int(operation.get("cargo", 0))
    if cargo > 0:
        run_state.add_scrap(cargo, true)
        haul_returned.emit(cargo)
    for robot in _living_operation_members():
        robot.set_group(&"reserve", 0)
        robot.set_goal(heartforge.global_position, "Remote operation complete; returning to the general machine pool.", robot.move_speed * 0.72)
    operation.clear()
    if operation_detail_director != null:
        operation_detail_director.clear_operation(detail_key)
    autonomy_director.set_process(true)
    operation_changed.emit(&"outpost", &"idle", "The remote group has returned to the Heartforge.")


func _abort_operation(reason: String) -> void:
    var detail_key := StringName("outpost_%s" % String(operation.get("kind", &"operation")))
    for robot in _living_operation_members():
        robot.set_group(&"reserve", 0)
        robot.set_goal(heartforge.global_position, reason, robot.move_speed * 0.72)
    operation.clear()
    if operation_detail_director != null:
        operation_detail_director.clear_operation(detail_key)
    if autonomy_director != null:
        autonomy_director.set_process(true)
    operation_changed.emit(&"outpost", &"aborted", reason)


func _spawn_outpost(site: OutpostSite3D, role: StringName, tier: int) -> Outpost3D:
    var outpost := Outpost3D.new()
    outpost.configure(site.site_id, role, tier, run_state)
    outpost.position = site.position
    world_parent.add_child(outpost)
    site.attach_outpost(outpost)
    _connect_outpost(outpost)
    return outpost


func _connect_outpost(outpost: Outpost3D) -> void:
    outpost.destroyed.connect(_on_outpost_destroyed)
    outpost.threat_detected.connect(_on_outpost_threat)
    outpost.cargo_ready.connect(_on_outpost_cargo_ready)
    outpost.state_changed.connect(_on_outpost_state_changed)


func _try_schedule_automatic_rebuild() -> bool:
    if progression == null or progression.heartforge_tier < 2:
        return false
    for site in sites:
        if not site.discovered or not site.has_outpost() or site.outpost.is_alive():
            continue
        var team := _select_team(&"rebuild")
        if team.is_empty():
            return false
        var cost := rebuild_cost(site.outpost)
        if not run_state.spend_scrap(cost):
            return false
        if _start_operation(&"rebuild", site, team, site.outpost.role, site.outpost.tier, cost):
            operation_changed.emit(&"outpost_rebuild", &"outbound", "%s was destroyed. An autonomous rebuild convoy has departed." % site.display_name)
            return true
        run_state.refund_scrap(cost)
    return false


func _try_schedule_resource_haul() -> bool:
    for site in sites:
        if not site.has_functioning_outpost() or site.outpost.role != &"resource" or site.outpost.stored_scrap < 20:
            continue
        var team := _select_team(&"haul")
        if team.is_empty():
            return false
        if _start_operation(&"haul", site, team, &"resource", site.outpost.tier, 0):
            operation_changed.emit(&"outpost_haul", &"outbound", "A protected hauler group is travelling to collect output from %s." % site.display_name)
            return true
    return false


func _select_team(kind: StringName) -> Array[RobotUnit3D]:
    var result: Array[RobotUnit3D] = []
    if autonomy_director == null:
        return result
    if kind == &"haul":
        var salvagers := autonomy_director.living_robots(&"salvager")
        var guards := autonomy_director.living_robots(&"guardian")
        if salvagers.is_empty() or guards.is_empty():
            return result
        result.append(salvagers[0])
        result.append(guards[0])
    else:
        var engineers := autonomy_director.living_robots(&"engineer")
        var guardians := autonomy_director.living_robots(&"guardian")
        if engineers.is_empty() or guardians.is_empty():
            return result
        result.append(engineers[0])
        result.append(guardians[0])
    var scouts := autonomy_director.living_robots(&"scout")
    if not scouts.is_empty() and scouts[0] not in result:
        result.push_front(scouts[0])
    return result


func _hold_nonmembers_at_heartforge(members: Array[RobotUnit3D]) -> void:
    var slot := 0
    for robot in autonomy_director.living_robots():
        if robot in members or robot.archetype == &"companion":
            continue
        var angle := TAU * float(slot) / 6.0
        var goal := heartforge.global_position + Vector3(cos(angle) * 8.0, 0.0, sin(angle) * 8.0)
        robot.set_group(&"outpost_reserve", slot)
        robot.set_goal(goal, "Remaining at the Heartforge while the autonomous remote group is away.", robot.move_speed * 0.72)
        slot += 1


func _living_operation_members() -> Array[RobotUnit3D]:
    var result: Array[RobotUnit3D] = []
    if operation.is_empty():
        return result
    var raw: Array = operation.get("members", [])
    for member in raw:
        if is_instance_valid(member) and member is RobotUnit3D and member.is_alive():
            result.append(member)
    operation["members"] = result
    return result


func _maximum_separation(anchor: Vector3, members: Array[RobotUnit3D]) -> float:
    var maximum := 0.0
    for robot in members:
        maximum = maxf(maximum, robot.global_position.distance_to(anchor))
    return maximum


func _operation_pace(members: Array[RobotUnit3D]) -> float:
    var slowest := 999.0
    for robot in members:
        slowest = minf(slowest, robot.move_speed)
    return slowest * 0.64


func _construction_rate() -> float:
    var rate := 1.0
    for robot in _living_operation_members():
        if robot.archetype == &"engineer":
            rate = maxf(rate, robot.construction_rate)
    return rate


func _hostile_near(position: Vector3, radius: float) -> bool:
    for enemy in get_tree().get_nodes_in_group(&"organic_enemies"):
        if is_instance_valid(enemy) and enemy is Node3D and position.distance_to(enemy.global_position) <= radius:
            return true
    return false


func _other_remote_operation_active() -> bool:
    if autonomy_director == null:
        return false
    return not autonomy_director.salvage_operation.is_empty() or not autonomy_director.expedition_operation.is_empty()


func _route_between(origin: Vector3, destination: Vector3) -> PackedVector3Array:
    var route := PackedVector3Array()
    route.append(origin)
    var midpoint := Vector3(origin.x, 0.0, destination.z)
    if absf(destination.x - origin.x) > absf(destination.z - origin.z):
        midpoint = Vector3(destination.x, 0.0, origin.z)
    route.append(midpoint)
    route.append(destination)
    return route


func get_follow_target() -> Node3D:
    var members := _living_operation_members()
    return members[0] if not members.is_empty() else null


func operation_summary() -> String:
    if operation.is_empty():
        var alive_count := 0
        for site in sites:
            if site.has_functioning_outpost():
                alive_count += 1
        return "%d autonomous outpost%s · no active convoy" % [alive_count, "" if alive_count == 1 else "s"]
    var site := operation.get("site") as OutpostSite3D
    return "%s · %s · %s" % [
        String(operation.get("kind", &"operation")).capitalize(),
        String(operation.get("state", &"unknown")).capitalize(),
        site.display_name if site != null else "unknown site",
    ]


func site_statuses() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for site in discovered_sites():
        result.append({
            "site_id": String(site.site_id),
            "display_name": site.display_name,
            "recommended_role": String(site.recommended_role),
            "status": site.status_text(),
            "has_outpost": site.has_outpost(),
            "alive": site.has_functioning_outpost(),
            "tier": site.outpost.tier if site.has_outpost() else 0,
            "role": String(site.outpost.role) if site.has_outpost() else "",
            "stored_scrap": site.outpost.stored_scrap if site.has_outpost() else 0,
        })
    return result


func to_dictionary() -> Dictionary:
    var serialized_sites: Array[Dictionary] = []
    for site in sites:
        serialized_sites.append(site.to_dictionary())
    return {
        "schema_version": 2,
        "sites": serialized_sites,
        "active_operation": _serialize_active_operation(),
    }


func restore_from_dictionary(data: Dictionary) -> void:
    clear_outposts()
    var saved_sites: Array = data.get("sites", [])
    for raw_saved in saved_sites:
        if not (raw_saved is Dictionary):
            continue
        var saved := raw_saved as Dictionary
        var site := get_site(StringName(str(saved.get("site_id", ""))))
        if site == null:
            continue
        site.set_discovered(bool(saved.get("discovered", false)))
        var outpost_data: Variant = saved.get("outpost", null)
        if outpost_data is Dictionary:
            var role := StringName(str(outpost_data.get("role", "resource")))
            var tier := int(outpost_data.get("tier", 1))
            var outpost := _spawn_outpost(site, role, tier)
            outpost.restore_from_dictionary(outpost_data)
    _restore_active_operation(data.get("active_operation", {}))


func clear_outposts() -> void:
    if not operation.is_empty():
        _abort_operation("World state is being restored.")
    for outpost in get_tree().get_nodes_in_group(&"outposts"):
        if is_instance_valid(outpost):
            outpost.free()
    for site in sites:
        site.outpost = null


func _serialize_active_operation() -> Dictionary:
    if operation.is_empty():
        return {}
    var route_values: Array = []
    var route: PackedVector3Array = operation.get("route", PackedVector3Array())
    for point in route:
        route_values.append(_vector_to_array(point))
    var member_names: Array[String] = []
    for member in operation.get("members", []):
        if is_instance_valid(member) and member is RobotUnit3D:
            member_names.append(String((member as RobotUnit3D).name))
    var site := operation.get("site") as OutpostSite3D
    return {
        "kind": String(operation.get("kind", &"build")),
        "state": String(operation.get("state", &"outbound")),
        "site_id": String(site.site_id) if site != null else "",
        "member_names": member_names,
        "role": String(operation.get("role", &"resource")),
        "target_tier": int(operation.get("target_tier", 1)),
        "committed_scrap": int(operation.get("committed_scrap", 0)),
        "route": route_values,
        "route_index": int(operation.get("route_index", 1)),
        "anchor": _vector_to_array(operation.get("anchor", heartforge.global_position)),
        "last_forward": _vector_to_array(operation.get("last_forward", Vector3.FORWARD)),
        "work_clock": float(operation.get("work_clock", 0.0)),
        "noise_clock": float(operation.get("noise_clock", 0.0)),
        "cargo": int(operation.get("cargo", 0)),
    }


func _restore_active_operation(raw_data: Variant) -> void:
    if not (raw_data is Dictionary):
        return
    var saved := raw_data as Dictionary
    var site := get_site(StringName(str(saved.get("site_id", ""))))
    if site == null or not site.discovered:
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
    operation = {
        "kind": StringName(str(saved.get("kind", "build"))),
        "state": StringName(str(saved.get("state", "outbound"))),
        "site": site,
        "members": members,
        "role": StringName(str(saved.get("role", "resource"))),
        "target_tier": maxi(1, int(saved.get("target_tier", 1))),
        "committed_scrap": maxi(0, int(saved.get("committed_scrap", 0))),
        "route": route,
        "route_index": maxi(1, int(saved.get("route_index", 1))),
        "anchor": _array_to_vector(saved.get("anchor", [heartforge.global_position.x, heartforge.global_position.y, heartforge.global_position.z])),
        "last_forward": _array_to_vector(saved.get("last_forward", [0.0, 0.0, -1.0])),
        "work_clock": maxf(0.0, float(saved.get("work_clock", 0.0))),
        "noise_clock": maxf(0.0, float(saved.get("noise_clock", 0.0))),
        "cargo": maxi(0, int(saved.get("cargo", 0))),
    }
    for index in range(members.size()):
        members[index].set_group(StringName("outpost_%s" % String(operation.get("kind", &"build"))), index)
    autonomy_director.set_process(false)
    operation_changed.emit(StringName(operation.get("kind", &"outpost")), StringName(operation.get("state", &"outbound")), "The saved outpost convoy resumed its physical route.")


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


func _on_site_discovered(site: OutpostSite3D) -> void:
    site_discovered.emit(site)
    operation_changed.emit(&"site_discovery", &"complete", "%s is now available for one autonomous outpost project." % site.display_name)


func _on_outpost_destroyed(outpost: Outpost3D) -> void:
    outpost_destroyed.emit(outpost)
    operation_changed.emit(&"outpost", &"destroyed", "%s was destroyed. Rebuild will be attempted automatically when robots and Scrap are available." % String(outpost.site_id))


func _on_outpost_threat(outpost: Outpost3D, enemy: Node3D) -> void:
    if notification_cooldown > 0.0:
        return
    notification_cooldown = 4.0
    operation_changed.emit(&"early_warning", &"contact", "%s detected organic movement near its sensor envelope." % String(outpost.site_id))


func _on_outpost_cargo_ready(outpost: Outpost3D) -> void:
    if operation.is_empty() and not _other_remote_operation_active():
        _try_schedule_resource_haul()


func _on_outpost_state_changed(outpost: Outpost3D) -> void:
    outpost_changed.emit(outpost)
