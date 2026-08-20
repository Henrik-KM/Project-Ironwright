class_name PerformanceDirector3D
extends Node

signal performance_snapshot(snapshot: Dictionary)

var focus_provider: Callable
var target_fps: int = 60
var active_radius: float = 58.0
var medium_radius: float = 118.0
var reduced_tick_interval: float = 0.45
var evaluation_interval: float = 0.32
var evaluation_clock: float = 0.0
var reduced_tick_clock: float = 0.0
var frames_clock: float = 0.0
var frames_count: int = 0
var measured_fps: float = 60.0
var active_entities: int = 0
var medium_entities: int = 0
var reduced_entities: int = 0
var reduced_enemies: Array[OrganicEnemyRelease3D] = []
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

    for raw_enemy in get_tree().get_nodes_in_group(&"organic_enemies"):
        if not is_instance_valid(raw_enemy) or not (raw_enemy is Node3D):
            continue
        var enemy_node := raw_enemy as Node3D
        var distance := focus.distance_to(enemy_node.global_position)
        if raw_enemy is OrganicEnemyRelease3D:
            var enemy := raw_enemy as OrganicEnemyRelease3D
            if distance <= active_radius:
                enemy.set_reduced_detail(false)
                enemy.set_visual_lod(0)
                active_entities += 1
            elif distance <= medium_radius:
                enemy.set_reduced_detail(false)
                enemy.set_visual_lod(1)
                medium_entities += 1
            else:
                enemy.set_reduced_detail(true)
                enemy.set_visual_lod(2)
                reduced_enemies.append(enemy)
                reduced_entities += 1
        else:
            active_entities += 1

    for raw_robot in get_tree().get_nodes_in_group(&"friendly_robots"):
        if not is_instance_valid(raw_robot) or not (raw_robot is Node3D):
            continue
        var distance := focus.distance_to((raw_robot as Node3D).global_position)
        if raw_robot is RobotUnitRelease3D:
            var robot := raw_robot as RobotUnitRelease3D
            if distance <= active_radius:
                robot.set_visual_lod(0)
                active_entities += 1
            elif distance <= medium_radius:
                robot.set_visual_lod(1)
                medium_entities += 1
            else:
                robot.set_visual_lod(2)
                reduced_entities += 1
        else:
            active_entities += 1

    last_snapshot = {
        "measured_fps": measured_fps,
        "target_fps": target_fps,
        "active_radius": active_radius,
        "medium_radius": medium_radius,
        "active_entities": active_entities,
        "medium_entities": medium_entities,
        "reduced_entities": reduced_entities,
    }
    performance_snapshot.emit(last_snapshot.duplicate(true))


func _tick_reduced_entities(delta: float) -> void:
    for enemy in reduced_enemies:
        if is_instance_valid(enemy):
            enemy.reduced_detail_tick(delta)


func _adapt_budgets() -> void:
    if measured_fps < float(target_fps) * 0.78:
        active_radius = maxf(42.0, active_radius - 3.0)
        medium_radius = maxf(active_radius + 36.0, medium_radius - 5.0)
        reduced_tick_interval = minf(0.8, reduced_tick_interval + 0.05)
    elif measured_fps > float(target_fps) * 1.08:
        active_radius = minf(72.0, active_radius + 1.0)
        medium_radius = minf(148.0, medium_radius + 2.0)
        reduced_tick_interval = maxf(0.32, reduced_tick_interval - 0.02)


func snapshot() -> Dictionary:
    return last_snapshot.duplicate(true)


func force_evaluate_for_test() -> void:
    _evaluate_entities()


func to_dictionary() -> Dictionary:
    return {
        "schema_version": 1,
        "target_fps": target_fps,
        "active_radius": active_radius,
        "medium_radius": medium_radius,
        "reduced_tick_interval": reduced_tick_interval,
    }


func restore_from_dictionary(data: Dictionary) -> void:
    target_fps = clampi(int(data.get("target_fps", target_fps)), 30, 120)
    active_radius = clampf(float(data.get("active_radius", active_radius)), 38.0, 80.0)
    medium_radius = clampf(float(data.get("medium_radius", medium_radius)), active_radius + 24.0, 170.0)
    reduced_tick_interval = clampf(float(data.get("reduced_tick_interval", reduced_tick_interval)), 0.25, 1.0)
