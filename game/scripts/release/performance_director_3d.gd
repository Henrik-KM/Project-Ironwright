class_name PerformanceDirector3D
extends Node

signal performance_snapshot(snapshot: Dictionary)

var focus_provider: Callable
var target_fps: int = 60
var active_radius: float = 58.0
var medium_radius: float = 118.0
var active_entity_budget: int = 24
var medium_entity_budget: int = 40
var reduced_tick_interval: float = 0.45
var medium_tick_interval: float = 0.22
var evaluation_interval: float = 0.32
var evaluation_clock: float = 0.0
var reduced_tick_clock: float = 0.0
var medium_tick_clock: float = 0.0
var frames_clock: float = 0.0
var frames_count: int = 0
var measured_fps: float = 60.0
var active_entities: int = 0
var medium_entities: int = 0
var reduced_entities: int = 0
var reduced_enemies: Array[OrganicEnemyRelease3D] = []
var reduced_robots: Array[RobotUnitRelease3D] = []
var medium_enemies: Array[OrganicEnemyRelease3D] = []
var medium_robots: Array[RobotUnitRelease3D] = []
var last_snapshot: Dictionary = {}


func configure(next_focus_provider: Callable, next_target_fps: int = 60) -> void:
    focus_provider = next_focus_provider
    target_fps = clampi(next_target_fps, 30, 120)


func _ready() -> void:
    add_to_group(&"performance_director")


func _process(delta: float) -> void:
    frames_count += 1
    frames_clock += delta
    evaluation_clock += delta
    reduced_tick_clock += delta
    medium_tick_clock += delta
    if frames_clock >= 1.0:
        measured_fps = float(frames_count) / maxf(0.001, frames_clock)
        frames_count = 0
        frames_clock = 0.0
        _adapt_budgets()
    if evaluation_clock >= evaluation_interval:
        evaluation_clock = 0.0
        _evaluate_entities()
    if reduced_tick_clock >= reduced_tick_interval:
        var step := reduced_tick_clock
        reduced_tick_clock = 0.0
        _tick_reduced_entities(step)
    if medium_tick_clock >= medium_tick_interval:
        var medium_step := medium_tick_clock
        medium_tick_clock = 0.0
        _tick_medium_entities(medium_step)


func _focus_position() -> Vector3:
    if focus_provider.is_valid():
        var value: Variant = focus_provider.call()
        if value is Vector3:
            return value
        if value is Node3D and is_instance_valid(value):
            return (value as Node3D).global_position
    return Vector3.ZERO


func _evaluate_entities() -> void:
    var focus := _focus_position()
    active_entities = 0
    medium_entities = 0
    reduced_entities = 0
    reduced_enemies.clear()
    reduced_robots.clear()
    medium_enemies.clear()
    medium_robots.clear()
    var candidates: Array[Dictionary] = []

    for raw_enemy in get_tree().get_nodes_in_group(&"organic_enemies"):
        if not is_instance_valid(raw_enemy) or not (raw_enemy is Node3D):
            continue
        if raw_enemy is OrganicEnemyRelease3D:
            var enemy_node := raw_enemy as Node3D
            candidates.append({"node": raw_enemy, "distance": focus.distance_to(enemy_node.global_position)})

    for raw_robot in get_tree().get_nodes_in_group(&"friendly_robots"):
        if not is_instance_valid(raw_robot) or not (raw_robot is Node3D):
            continue
        if raw_robot is RobotUnitRelease3D:
            candidates.append({"node": raw_robot, "distance": focus.distance_to((raw_robot as Node3D).global_position)})

    candidates.sort_custom(Callable(self, "_sort_candidates_by_distance"))
    for candidate in candidates:
        var actor := candidate["node"] as Node
        var distance := float(candidate["distance"])
        var lod_level := 2
        if distance <= active_radius and active_entities < active_entity_budget:
            lod_level = 0
            active_entities += 1
        elif distance <= medium_radius and active_entities + medium_entities < medium_entity_budget:
            lod_level = 1
            medium_entities += 1
        else:
            reduced_entities += 1

        if actor is OrganicEnemyRelease3D:
            var enemy := actor as OrganicEnemyRelease3D
            enemy.set_reduced_detail(lod_level == 2)
            enemy.set_coarse_simulation(lod_level == 1)
            enemy.set_visual_lod(lod_level)
            if lod_level == 2:
                reduced_enemies.append(enemy)
            elif lod_level == 1:
                medium_enemies.append(enemy)
        elif actor is RobotUnitRelease3D:
            var robot := actor as RobotUnitRelease3D
            robot.set_reduced_detail(lod_level == 2)
            robot.set_coarse_simulation(lod_level == 1)
            robot.set_visual_lod(lod_level)
            if lod_level == 2:
                reduced_robots.append(robot)
            elif lod_level == 1:
                medium_robots.append(robot)

    last_snapshot = {
        "measured_fps": measured_fps,
        "target_fps": target_fps,
        "active_radius": active_radius,
        "medium_radius": medium_radius,
        "active_entity_budget": active_entity_budget,
        "medium_entity_budget": medium_entity_budget,
        "active_entities": active_entities,
        "medium_entities": medium_entities,
        "reduced_entities": reduced_entities,
    }
    performance_snapshot.emit(last_snapshot.duplicate(true))


func _tick_reduced_entities(delta: float) -> void:
    for enemy in reduced_enemies:
        if is_instance_valid(enemy):
            enemy.reduced_detail_tick(delta)
    for robot in reduced_robots:
        if is_instance_valid(robot):
            robot.reduced_detail_tick(delta)


func _tick_medium_entities(delta: float) -> void:
    for enemy in medium_enemies:
        if is_instance_valid(enemy):
            enemy.coarse_detail_tick(delta)
    for robot in medium_robots:
        if is_instance_valid(robot):
            robot.coarse_detail_tick(delta)


func _sort_candidates_by_distance(left: Dictionary, right: Dictionary) -> bool:
    return float(left.get("distance", INF)) < float(right.get("distance", INF))


func _adapt_budgets() -> void:
    if measured_fps < float(target_fps) * 0.78:
        active_radius = maxf(42.0, active_radius - 3.0)
        medium_radius = maxf(active_radius + 36.0, medium_radius - 5.0)
        active_entity_budget = maxi(12, active_entity_budget - 3)
        medium_entity_budget = maxi(active_entity_budget + 8, medium_entity_budget - 5)
        reduced_tick_interval = minf(0.8, reduced_tick_interval + 0.05)
    elif measured_fps > float(target_fps) * 1.08:
        active_radius = minf(72.0, active_radius + 1.0)
        medium_radius = minf(148.0, medium_radius + 2.0)
        active_entity_budget = mini(32, active_entity_budget + 1)
        medium_entity_budget = mini(52, medium_entity_budget + 2)
        reduced_tick_interval = maxf(0.32, reduced_tick_interval - 0.02)


func snapshot() -> Dictionary:
    return last_snapshot.duplicate(true)


func force_evaluate_for_test() -> void:
    _evaluate_entities()


func to_dictionary() -> Dictionary:
    return {
        "schema_version": 2,
        "target_fps": target_fps,
        "active_radius": active_radius,
        "medium_radius": medium_radius,
        "active_entity_budget": active_entity_budget,
        "medium_entity_budget": medium_entity_budget,
        "reduced_tick_interval": reduced_tick_interval,
    }


func restore_from_dictionary(data: Dictionary) -> void:
    target_fps = clampi(int(data.get("target_fps", target_fps)), 30, 120)
    active_radius = clampf(float(data.get("active_radius", active_radius)), 38.0, 80.0)
    medium_radius = clampf(float(data.get("medium_radius", medium_radius)), active_radius + 24.0, 170.0)
    active_entity_budget = clampi(int(data.get("active_entity_budget", active_entity_budget)), 8, 48)
    medium_entity_budget = clampi(int(data.get("medium_entity_budget", medium_entity_budget)), active_entity_budget + 8, 96)
    reduced_tick_interval = clampf(float(data.get("reduced_tick_interval", reduced_tick_interval)), 0.25, 1.0)
