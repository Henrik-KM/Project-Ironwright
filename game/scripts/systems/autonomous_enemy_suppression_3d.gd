class_name AutonomousEnemySuppression3D
extends Node

signal suppression_patrol_changed(active_wardens: int, target_cells: int, reason: String)

var world: Node
var progression: EnemyTierProgressionDirector3D
var autonomy_node: Node
var heartforge: Node3D
var progression_node: Node
var evaluation_clock: float = 0.0
var reevaluation_seconds: float = 8.0
var unlock_heartforge_tier: int = 3
var density_threshold: int = 18
var maximum_wardens: int = 3
var patrol_radius: float = 52.0
var assigned_wardens: Array[Node] = []
var target_cells: Array[Vector3] = []
var active_reason: String = ""


func configure(next_world: Node, next_progression: EnemyTierProgressionDirector3D) -> void:
    world = next_world
    progression = next_progression


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE
    call_deferred("_bind_world")


func _process(delta: float) -> void:
    evaluation_clock += delta
    if evaluation_clock < reevaluation_seconds:
        _maintain_assignments()
        return
    evaluation_clock = 0.0
    _evaluate_suppression_need()


func _bind_world() -> void:
    if world == null:
        world = get_tree().current_scene
    if progression == null:
        progression = get_tree().get_first_node_in_group(&"enemy_tier_progression") as EnemyTierProgressionDirector3D
    autonomy_node = _find_node_with_method(world, &"living_robots")
    progression_node = _find_node_with_method(world, &"current_phase_data")
    heartforge = _find_node_named(world, "heartforge")
    if progression != null:
        var settings: Dictionary = progression.config.get("autonomous_suppression", {})
        unlock_heartforge_tier = maxi(1, int(settings.get("unlock_heartforge_tier", 3)))
        density_threshold = maxi(1, int(settings.get("tier_1_density_threshold", 18)))
        maximum_wardens = clampi(int(settings.get("maximum_wardens", 3)), 1, 8)
        patrol_radius = maxf(12.0, float(settings.get("patrol_radius", 52.0)))
        reevaluation_seconds = maxf(2.0, float(settings.get("reevaluation_seconds", 8.0)))


func _evaluate_suppression_need() -> void:
    if progression == null or autonomy_node == null:
        return
    if _heartforge_tier() < unlock_heartforge_tier:
        _release_all("Suppression autonomy is not yet understood by the machine society.")
        return
    var tier_one_count := int(progression.population.get(1, 0))
    if tier_one_count < density_threshold:
        _release_all("Feral population is below the autonomous suppression threshold.")
        return
    var clusters := _find_tier_one_clusters()
    if clusters.is_empty():
        _release_all("No concentrated feral population is close enough to justify a patrol.")
        return
    var wardens := _available_wardens()
    if wardens.is_empty():
        _release_all("All Wardens are committed to higher-priority protection or remote operations.")
        return
    target_cells.clear()
    var target_count := mini(clusters.size(), maximum_wardens)
    for index in range(target_count):
        target_cells.append(clusters[index])
    assigned_wardens.clear()
    for index in range(mini(mini(wardens.size(), target_cells.size()), maximum_wardens)):
        var warden := wardens[index]
        assigned_wardens.append(warden)
        _assign_warden(warden, target_cells[index], index)
    active_reason = "Wardens are autonomously thinning saturated Tier-1 concentrations before they can drive higher-tier escalation."
    suppression_patrol_changed.emit(assigned_wardens.size(), target_cells.size(), active_reason)


func _maintain_assignments() -> void:
    if assigned_wardens.is_empty() or target_cells.is_empty():
        return
    var living: Array[Node] = []
    for index in range(assigned_wardens.size()):
        var warden := assigned_wardens[index]
        if warden == null or not is_instance_valid(warden):
            continue
        if warden.has_method(&"is_alive") and not bool(warden.call(&"is_alive")):
            continue
        if _is_committed_to_major_operation(warden):
            warden.remove_meta(&"enemy_suppression_assignment")
            continue
        living.append(warden)
        _assign_warden(warden, target_cells[index % target_cells.size()], index)
    assigned_wardens = living


func _assign_warden(warden: Node, target: Vector3, index: int) -> void:
    if not warden.has_method(&"set_goal"):
        return
    var angle := TAU * float(index) / maxf(1.0, float(maximum_wardens))
    var offset := Vector3(cos(angle) * 4.5, 0.0, sin(angle) * 4.5)
    warden.set_meta(&"enemy_suppression_assignment", true)
    warden.set_meta(&"enemy_suppression_target", target)
    warden.call(
        &"set_goal",
        target + offset,
        "Autonomously suppressing a dense feral population so Tier-1 replenishment is spent replacing weak organisms instead of escalating upward.",
        maxf(2.4, float(warden.get("move_speed")) * 0.78)
    )
    if warden.has_method(&"set_group"):
        warden.call(&"set_group", &"ecology_suppression", index)


func _release_all(reason: String) -> void:
    if assigned_wardens.is_empty():
        return
    for index in range(assigned_wardens.size()):
        var warden := assigned_wardens[index]
        if warden == null or not is_instance_valid(warden):
            continue
        warden.remove_meta(&"enemy_suppression_assignment")
        warden.remove_meta(&"enemy_suppression_target")
        if heartforge != null and warden.has_method(&"set_goal"):
            var angle := TAU * float(index) / maxf(1.0, float(assigned_wardens.size()))
            var goal := heartforge.global_position + Vector3(cos(angle) * 8.0, 0.0, sin(angle) * 8.0)
            warden.call(&"set_goal", goal, reason, maxf(2.2, float(warden.get("move_speed")) * 0.72))
        if warden.has_method(&"set_group"):
            warden.call(&"set_group", &"reserve", index)
    assigned_wardens.clear()
    target_cells.clear()
    active_reason = reason
    suppression_patrol_changed.emit(0, 0, reason)


func _find_tier_one_clusters() -> Array[Vector3]:
    var cell_size := 18.0
    var buckets: Dictionary = {}
    var anchors: Array[Vector3] = []
    if heartforge != null:
        anchors.append(heartforge.global_position)
    for outpost in get_tree().get_nodes_in_group(&"outposts"):
        if outpost is Node3D and (not outpost.has_method(&"is_alive") or bool(outpost.call(&"is_alive"))):
            anchors.append(outpost.global_position)
    for enemy in get_tree().get_nodes_in_group(&"enemy_tier_1"):
        if not (enemy is Node3D) or not is_instance_valid(enemy):
            continue
        if enemy.has_method(&"is_alive") and not bool(enemy.call(&"is_alive")):
            continue
        var position := (enemy as Node3D).global_position
        var relevant := anchors.is_empty()
        for anchor in anchors:
            if anchor.distance_to(position) <= patrol_radius:
                relevant = true
                break
        if not relevant:
            continue
        var cell := Vector2i(floori(position.x / cell_size), floori(position.z / cell_size))
        if not buckets.has(cell):
            buckets[cell] = {"count": 0, "sum": Vector3.ZERO}
        var bucket: Dictionary = buckets[cell]
        bucket["count"] = int(bucket["count"]) + 1
        bucket["sum"] = (bucket["sum"] as Vector3) + position
        buckets[cell] = bucket
    var scored: Array[Dictionary] = []
    for cell in buckets:
        var bucket: Dictionary = buckets[cell]
        var count := int(bucket["count"])
        if count < 3:
            continue
        scored.append({"count": count, "position": (bucket["sum"] as Vector3) / float(count)})
    scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return int(a["count"]) > int(b["count"])
    )
    var result: Array[Vector3] = []
    for entry in scored:
        result.append(entry["position"] as Vector3)
    return result


func _available_wardens() -> Array[Node]:
    var result: Array[Node] = []
    var raw: Variant = autonomy_node.call(&"living_robots", &"guardian") if autonomy_node.has_method(&"living_robots") else []
    if not (raw is Array):
        return result
    for robot in raw:
        if robot == null or not is_instance_valid(robot):
            continue
        if _is_committed_to_major_operation(robot):
            continue
        result.append(robot)
    result.sort_custom(func(a: Node, b: Node) -> bool:
        var a_distance := heartforge.global_position.distance_to((a as Node3D).global_position) if heartforge != null else 0.0
        var b_distance := heartforge.global_position.distance_to((b as Node3D).global_position) if heartforge != null else 0.0
        return a_distance < b_distance
    )
    return result


func _is_committed_to_major_operation(robot: Node) -> bool:
    var group_id := StringName(str(robot.get("assigned_group")))
    var text := String(group_id)
    if text.contains("salvage") or text.contains("expedition") or text.contains("outpost") or text.contains("operation") or text.contains("escort"):
        return true
    return false


func _heartforge_tier() -> int:
    return int(progression_node.get("heartforge_tier")) if progression_node != null else 1


func _find_node_with_method(root: Node, method_name: StringName) -> Node:
    if root == null:
        return null
    if root.has_method(method_name):
        return root
    for child in root.get_children():
        var found := _find_node_with_method(child, method_name)
        if found != null:
            return found
    return null


func _find_node_named(root: Node, fragment: String) -> Node3D:
    if root == null:
        return null
    if root is Node3D and String(root.name).to_lower().contains(fragment):
        return root as Node3D
    for child in root.get_children():
        var found := _find_node_named(child, fragment)
        if found != null:
            return found
    return null


func status_summary() -> String:
    if assigned_wardens.is_empty():
        return "No autonomous feral-suppression patrol is currently required."
    return "%d Warden%s covering %d feral concentration%s." % [
        assigned_wardens.size(),
        "" if assigned_wardens.size() == 1 else "s",
        target_cells.size(),
        "" if target_cells.size() == 1 else "s",
    ]
