class_name PerformanceDirector3D
extends Node

signal performance_snapshot(snapshot: Dictionary)

var focus_provider: Callable
var _spatial_index: SpatialIndex3D
var target_fps: int = 60
const ACTIVE_SHADOW_CASTER_BUDGET := 4
const ACTIVE_AUTHORED_VISUAL_BUDGET := 8
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
var reduced_tick_cursor: int = 0
var medium_tick_cursor: int = 0
var frames_clock: float = 0.0
var frames_count: int = 0
var measured_fps: float = 60.0
var active_entities: int = 0
var active_visual_entities: int = 0
var medium_entities: int = 0
var reduced_entities: int = 0
var reduced_enemies: Array[OrganicEnemyRelease3D] = []
var reduced_robots: Array[RobotUnitRelease3D] = []
var medium_enemies: Array[OrganicEnemyRelease3D] = []
var medium_robots: Array[RobotUnitRelease3D] = []
var last_snapshot: Dictionary = {}
var last_candidate_count: int = 0
var last_sorted_candidate_count: int = 0
var active_shadow_casters: int = 0


func configure(next_focus_provider: Callable, next_target_fps: int = 60) -> void:
    focus_provider = next_focus_provider
    target_fps = clampi(next_target_fps, 30, 120)


func _ready() -> void:
    add_to_group(&"performance_director")
    call_deferred("_resolve_spatial_index")


func _resolve_spatial_index() -> void:
    _spatial_index = get_tree().get_first_node_in_group(&"spatial_index_service") as SpatialIndex3D


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
    _schedule_reduced_ticks()
    _schedule_medium_ticks()


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
    active_visual_entities = 0
    medium_entities = 0
    reduced_entities = 0
    reduced_enemies.clear()
    reduced_robots.clear()
    medium_enemies.clear()
    medium_robots.clear()
    active_shadow_casters = 0
    var nearby_candidates: Array[Dictionary] = []
    last_candidate_count = 0
    var active_radius_squared := active_radius * active_radius
    var medium_radius_squared := medium_radius * medium_radius

    for raw_enemy in _indexed_or_group_nodes(&"organic_enemies"):
        if not is_instance_valid(raw_enemy) or not (raw_enemy is Node3D):
            continue
        if raw_enemy is OrganicEnemyRelease3D:
            var enemy_node := raw_enemy as Node3D
            var distance_squared := focus.distance_squared_to(enemy_node.global_position)
            last_candidate_count += 1
            if distance_squared > medium_radius_squared:
                _apply_actor_detail(raw_enemy, 2)
                reduced_entities += 1
            else:
                nearby_candidates.append({"node": raw_enemy, "distance_squared": distance_squared})

    for raw_robot in _indexed_or_group_nodes(&"friendly_robots"):
        if not is_instance_valid(raw_robot) or not (raw_robot is Node3D):
            continue
        if raw_robot is RobotUnitRelease3D:
            var distance_squared := focus.distance_squared_to((raw_robot as Node3D).global_position)
            last_candidate_count += 1
            if distance_squared > medium_radius_squared:
                _apply_actor_detail(raw_robot, 2)
                reduced_entities += 1
            else:
                nearby_candidates.append({"node": raw_robot, "distance_squared": distance_squared})

    nearby_candidates.sort_custom(Callable(self, "_sort_candidates_by_distance"))
    last_sorted_candidate_count = nearby_candidates.size()
    for candidate in nearby_candidates:
        var actor := candidate["node"] as Node
        var distance_squared := float(candidate["distance_squared"])
        var lod_level := 2
        if distance_squared <= active_radius_squared and active_entities < active_entity_budget:
            lod_level = 0
            active_entities += 1
        elif active_entities + medium_entities < medium_entity_budget:
            lod_level = 1
            medium_entities += 1
        else:
            reduced_entities += 1

        var visual_lod_level := lod_level
        if lod_level == 0:
            if active_visual_entities < ACTIVE_AUTHORED_VISUAL_BUDGET:
                active_visual_entities += 1
            else:
                # Keep the actor fully simulated and targetable, but reserve
                # expensive authored shells for the nearest active subjects.
                # The lightweight silhouette still communicates presence and
                # motion until the actor becomes one of the nearest subjects.
                visual_lod_level = 1
        _apply_actor_detail(actor, lod_level, visual_lod_level)
        var shadow_enabled := visual_lod_level == 0 and active_shadow_casters < ACTIVE_SHADOW_CASTER_BUDGET
        if shadow_enabled:
            active_shadow_casters += 1
        _apply_actor_shadow_budget(actor, shadow_enabled)
        if actor is OrganicEnemyRelease3D:
            var enemy := actor as OrganicEnemyRelease3D
            if lod_level == 2:
                reduced_enemies.append(enemy)
            elif lod_level == 1:
                medium_enemies.append(enemy)
        elif actor is RobotUnitRelease3D:
            var robot := actor as RobotUnitRelease3D
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
        "active_visual_entities": active_visual_entities,
        "active_authored_visual_budget": ACTIVE_AUTHORED_VISUAL_BUDGET,
        "medium_entity_budget": medium_entity_budget,
        "active_shadow_casters": active_shadow_casters,
        "active_shadow_caster_budget": ACTIVE_SHADOW_CASTER_BUDGET,
        "active_entities": active_entities,
        "medium_entities": medium_entities,
        "reduced_entities": reduced_entities,
        "candidate_count": last_candidate_count,
        "sorted_candidate_count": last_sorted_candidate_count,
    }
    performance_snapshot.emit(last_snapshot.duplicate(true))


func _indexed_or_group_nodes(group_name: StringName) -> Array[Node3D]:
    if _spatial_index == null or not is_instance_valid(_spatial_index):
        _resolve_spatial_index()
    if _spatial_index != null and is_instance_valid(_spatial_index) and _spatial_index.has_method(&"indexed_nodes"):
        var indexed: Variant = _spatial_index.call(&"indexed_nodes", group_name)
        if indexed is Array:
            return indexed as Array[Node3D]
    var fallback: Array[Node3D] = []
    for candidate in get_tree().get_nodes_in_group(group_name):
        if candidate is Node3D:
            fallback.append(candidate as Node3D)
    return fallback


func _tick_reduced_entities(delta: float) -> void:
    for enemy in reduced_enemies:
        if is_instance_valid(enemy):
            enemy.reduced_detail_tick(delta)
    for robot in reduced_robots:
        if is_instance_valid(robot):
            robot.reduced_detail_tick(delta)


func _schedule_reduced_ticks() -> void:
    var total := reduced_enemies.size() + reduced_robots.size()
    if total <= 0:
        reduced_tick_clock = 0.0
        reduced_tick_cursor = 0
        return
    var updates_due := int(floor((reduced_tick_clock / reduced_tick_interval) * float(total)))
    if updates_due <= 0:
        return
    reduced_tick_clock -= float(updates_due) / float(total) * reduced_tick_interval
    reduced_tick_cursor = _tick_reduced_round_robin(updates_due, reduced_tick_cursor, reduced_tick_interval)


func _tick_reduced_round_robin(update_count: int, cursor: int, step: float) -> int:
    var total := reduced_enemies.size() + reduced_robots.size()
    if total <= 0:
        return 0
    var next_cursor := posmod(cursor, total)
    for _index in range(update_count):
        if next_cursor < reduced_enemies.size():
            var enemy := reduced_enemies[next_cursor]
            if is_instance_valid(enemy):
                enemy.reduced_detail_tick(step)
        else:
            var robot_index := next_cursor - reduced_enemies.size()
            if robot_index < reduced_robots.size():
                var robot := reduced_robots[robot_index]
                if is_instance_valid(robot):
                    robot.reduced_detail_tick(step)
        next_cursor = (next_cursor + 1) % total
    return next_cursor


func _tick_medium_entities(delta: float) -> void:
    for enemy in medium_enemies:
        if is_instance_valid(enemy):
            enemy.coarse_detail_tick(delta)
    for robot in medium_robots:
        if is_instance_valid(robot):
            robot.coarse_detail_tick(delta)


func _schedule_medium_ticks() -> void:
    var total := medium_enemies.size() + medium_robots.size()
    if total <= 0:
        medium_tick_clock = 0.0
        medium_tick_cursor = 0
        return
    var updates_due := int(floor((medium_tick_clock / medium_tick_interval) * float(total)))
    if updates_due <= 0:
        return
    medium_tick_clock -= float(updates_due) / float(total) * medium_tick_interval
    medium_tick_cursor = _tick_medium_round_robin(updates_due, medium_tick_cursor, medium_tick_interval)


func _tick_medium_round_robin(update_count: int, cursor: int, step: float) -> int:
    var total := medium_enemies.size() + medium_robots.size()
    if total <= 0:
        return 0
    var next_cursor := posmod(cursor, total)
    for _index in range(update_count):
        if next_cursor < medium_enemies.size():
            var enemy := medium_enemies[next_cursor]
            if is_instance_valid(enemy):
                enemy.coarse_detail_tick(step)
        else:
            var robot_index := next_cursor - medium_enemies.size()
            if robot_index < medium_robots.size():
                var robot := medium_robots[robot_index]
                if is_instance_valid(robot):
                    robot.coarse_detail_tick(step)
        next_cursor = (next_cursor + 1) % total
    return next_cursor


func _sort_candidates_by_distance(left: Dictionary, right: Dictionary) -> bool:
    return float(left.get("distance_squared", INF)) < float(right.get("distance_squared", INF))


func _apply_actor_detail(actor: Node, lod_level: int, visual_lod_level: int = -1) -> void:
    var next_visual_lod := lod_level if visual_lod_level < 0 else visual_lod_level
    if actor is OrganicEnemyRelease3D:
        var enemy := actor as OrganicEnemyRelease3D
        enemy.set_reduced_detail(lod_level == 2)
        enemy.set_coarse_simulation(lod_level == 1)
        enemy.set_visual_lod(next_visual_lod)
    elif actor is RobotUnitRelease3D:
        var robot := actor as RobotUnitRelease3D
        robot.set_reduced_detail(lod_level == 2)
        robot.set_coarse_simulation(lod_level == 1)
        robot.set_visual_lod(next_visual_lod)


func _apply_actor_shadow_budget(actor: Node, enabled: bool) -> void:
    if actor != null and actor.has_method(&"set_runtime_shadow_enabled"):
        actor.call(&"set_runtime_shadow_enabled", enabled)


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


func should_defer_authored_visual_spawn(position: Vector3) -> bool:
    # Spawn-time deferral prevents a large burst at one location from building
    # dozens of high-definition shells before the first LOD evaluation. This
    # is intentionally a cold-path query; the hot evaluation path uses the
    # bounded visual budget above.
    var focus := _focus_position()
    if focus.distance_squared_to(position) > active_radius * active_radius:
        return true
    var authored_shells := 0
    for group_name in [&"organic_enemies", &"friendly_robots"]:
        for raw_actor in get_tree().get_nodes_in_group(group_name):
            if not is_instance_valid(raw_actor) or not (raw_actor is Node3D):
                continue
            var actor := raw_actor as Node3D
            if focus.distance_squared_to(actor.global_position) > active_radius * active_radius:
                continue
            if actor.get_node_or_null("OrganicModel") != null or actor.get_node_or_null("RobotModel") != null:
                authored_shells += 1
                if authored_shells >= ACTIVE_AUTHORED_VISUAL_BUDGET:
                    return true
    return false


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
