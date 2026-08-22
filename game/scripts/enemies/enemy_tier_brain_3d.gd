class_name EnemyTierBrain3D
extends Node

signal behaviour_changed(enemy: Node3D, tier: int, behaviour: StringName, reason: String)
signal detection_shared(enemy: Node3D, target: Node3D, position: Vector3)

var enemy: CharacterBody3D
var director
var enemy_tier: int = 1
var home_nest_id: StringName = &""
var home_nest: Node3D
var behaviour: StringName = &"roam"
var behaviour_reason: String = "Newly emerged and wandering without purpose."
var goal_position: Vector3
var has_goal: bool = false
var current_target: Node3D
var last_known_target_position: Vector3
var last_known_target_seconds: float = 0.0
var territory_center: Vector3
var territory_radius: float = 18.0
var decision_clock: float = 0.0
var remote_clock: float = 0.0
var state_elapsed: float = 0.0
var roam_serial: int = 0
var scout_serial: int = 0
var pack_id: StringName = &""
var spatial_index: Node
var world: Node
var remote_update_interval: float = 0.45
var active_distance: float = 115.0
var simulation_lod: int = 0
var initialized: bool = false


func configure(
        next_enemy: Node,
        next_director,
        next_tier: int,
        next_home_nest_id: StringName
    ) -> void:
    enemy = next_enemy as CharacterBody3D
    director = next_director
    enemy_tier = clampi(next_tier, 1, 5)
    home_nest_id = next_home_nest_id
    if is_inside_tree():
        _initialize()


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_PAUSABLE
    call_deferred("_initialize")


func _process(delta: float) -> void:
    # Release LOD systems may try to re-enable the parent enemy's legacy
    # physics loop. Tier intelligence remains the single movement authority.
    if enemy != null and is_instance_valid(enemy) and enemy.is_physics_processing():
        enemy.set_physics_process(false)


func set_simulation_lod(level_value: int) -> void:
    simulation_lod = clampi(level_value, 0, 2)
    set_physics_process(simulation_lod == 0)
    if enemy != null and is_instance_valid(enemy):
        # The tier brain is the sole movement authority for authored release
        # enemies, regardless of the parent's legacy physics callback state.
        enemy.set_physics_process(false)


func reduced_detail_tick(delta: float) -> void:
    if not initialized or simulation_lod != 2:
        return
    _simulation_tick(delta)


func coarse_detail_tick(delta: float) -> void:
    if not initialized or simulation_lod != 1:
        return
    _simulation_tick(delta)


func _initialize() -> void:
    if initialized or enemy == null or not is_instance_valid(enemy):
        return
    initialized = true
    world = get_tree().current_scene
    spatial_index = get_tree().get_first_node_in_group(&"spatial_index_service")
    home_nest = null
    if director != null:
        var raw_home_nest: Variant = director.nests.get(home_nest_id, null)
        if raw_home_nest is Node3D:
            home_nest = raw_home_nest as Node3D
    territory_center = home_nest.global_position if home_nest != null else enemy.global_position
    territory_radius = [28.0, 24.0, 42.0, 58.0, 92.0][enemy_tier - 1]
    pack_id = StringName("pack.%s.tier_%d" % [String(home_nest_id) if home_nest_id != &"" else "feral", enemy_tier])
    enemy.add_to_group(StringName("enemy_tier_%d" % enemy_tier))
    enemy.add_to_group(&"enemy_tier_brained")
    enemy.set_meta(&"enemy_behaviour", String(behaviour))
    enemy.set_meta(&"enemy_behaviour_reason", behaviour_reason)
    enemy.set_meta(&"enemy_pack_id", String(pack_id))
    enemy.set_physics_process(false)
    _choose_next_behaviour(true)
    set_process(false)


func _physics_process(delta: float) -> void:
    if simulation_lod != 0:
        return
    _simulation_tick(delta)


func _simulation_tick(delta: float) -> void:
    if not initialized or enemy == null or not is_instance_valid(enemy):
        return
    if enemy.has_method(&"is_alive") and not bool(enemy.call(&"is_alive")):
        return
    decision_clock += delta
    state_elapsed += delta
    enemy.set("attack_cooldown", maxf(0.0, float(enemy.get("attack_cooldown")) - delta))
    last_known_target_seconds = maxf(0.0, last_known_target_seconds - delta)
    var focus := _simulation_focus_position()
    var remote := enemy.global_position.distance_to(focus) > active_distance
    if remote:
        remote_clock += delta
        if remote_clock < remote_update_interval:
            return
        delta = remote_clock
        remote_clock = 0.0
    else:
        remote_clock = 0.0
    if decision_clock >= _decision_interval():
        decision_clock = 0.0
        _choose_next_behaviour(false)
    _execute_behaviour(delta, remote)


func _decision_interval() -> float:
    return [2.8, 1.8, 1.1, 0.72, 0.5][enemy_tier - 1]


func _choose_next_behaviour(force: bool) -> void:
    if enemy == null:
        return
    current_target = _validate_target(current_target)
    if current_target != null:
        var retention_radius: float = [16.0, 30.0, 58.0, 88.0, 145.0][enemy_tier - 1]
        if enemy.global_position.distance_to(current_target.global_position) > retention_radius:
            current_target = null
    if current_target != null:
        var retention_radius: float = [16.0, 30.0, 58.0, 88.0, 145.0][enemy_tier - 1]
        if enemy.global_position.distance_to(current_target.global_position) > retention_radius:
            current_target = null
    if current_target != null:
        last_known_target_position = current_target.global_position
        last_known_target_seconds = 9.0 + float(enemy_tier) * 4.0
    var visible := _best_visible_target()
    if visible != null:
        current_target = visible
        last_known_target_position = visible.global_position
        last_known_target_seconds = 8.0 + float(enemy_tier) * 5.0
        if enemy_tier >= 3:
            _share_detection(visible)

    match enemy_tier:
        1:
            _decide_tier_one(force)
        2:
            _decide_tier_two(force)
        3:
            _decide_tier_three(force)
        4:
            _decide_tier_four(force)
        _:
            _decide_tier_five(force)


func _decide_tier_one(force: bool) -> void:
    if current_target != null:
        _set_behaviour(&"chase", "A visible machine or Mechromancer entered primitive sensory range.")
        return
    if force or not has_goal or enemy.global_position.distance_to(goal_position) < 1.4 or state_elapsed > 13.0:
        roam_serial += 1
        # Feral organisms perform a broad random walk. A very weak home bias
        # prevents permanent drift outside the authored world without turning
        # the movement into nest patrol or purposeful defense.
        var wandering_center := enemy.global_position.lerp(territory_center, 0.12)
        goal_position = _random_point(wandering_center, territory_radius * 1.45, roam_serial * 31 + 7)
        has_goal = true
        _set_behaviour(&"roam", "Wandering continuously through the town without patrol, scouting, or a strategic purpose.")


func _decide_tier_two(force: bool) -> void:
    var nest_threat := _nearest_hostile_to_home(18.0)
    if nest_threat != null:
        current_target = nest_threat
        _set_behaviour(&"guard_nest", "Protecting the home nest from a nearby intruder.")
        return
    if current_target != null:
        _set_behaviour(&"territorial_chase", "Driving a detected intruder out of its territory.")
        return
    if _has_recent_noise():
        goal_position = _investigate_position()
        has_goal = true
        _set_behaviour(&"investigate_noise", "Responding purposefully to recent disturbance inside its territory.")
        return
    if force or not has_goal or enemy.global_position.distance_to(goal_position) < 1.4 or state_elapsed > 16.0:
        roam_serial += 1
        var angle := fmod(float(roam_serial * 137), 360.0) * PI / 180.0
        var radius := territory_radius * (0.55 + float(roam_serial % 4) * 0.1)
        goal_position = territory_center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
        has_goal = true
        _set_behaviour(&"patrol_territory", "Patrolling a repeatable ring around the home nest.")


func _decide_tier_three(force: bool) -> void:
    var vulnerable := _best_vulnerable_machine_target(46.0)
    if vulnerable != null:
        current_target = vulnerable
        _set_behaviour(&"hunt_vulnerable", "Hunting a vulnerable Scrapper, Engineer, Pathfinder, or exposed Mechromancer.")
        _share_detection(vulnerable)
        return
    if current_target != null:
        _set_behaviour(&"coordinated_hunt", "Maintaining contact and sharing the prey position with nearby hunters.")
        return
    if last_known_target_seconds > 0.0:
        goal_position = last_known_target_position
        has_goal = true
        _set_behaviour(&"track_last_known", "Tracking the last shared machine position instead of forgetting immediately.")
        return
    if _should_retreat():
        goal_position = territory_center
        has_goal = true
        _set_behaviour(&"retreat", "Withdrawing toward the nest after an unfavorable encounter.")
        return
    if force or not has_goal or enemy.global_position.distance_to(goal_position) < 1.8 or state_elapsed > 20.0:
        scout_serial += 1
        goal_position = _scouting_goal(scout_serial)
        has_goal = true
        _set_behaviour(&"scout", "Scouting machine routes beyond its territory and returning with information.")


func _decide_tier_four(force: bool) -> void:
    if _should_retreat():
        var reinforcement := _nearest_living_nest()
        goal_position = reinforcement.global_position if reinforcement != null else territory_center
        has_goal = true
        _set_behaviour(&"withdraw_and_reinforce", "Abandoning a bad fight and drawing it back toward nest reinforcements.")
        return
    var strategic_target := _best_strategic_target(72.0)
    if strategic_target != null:
        current_target = strategic_target
        var role := _target_role(strategic_target)
        _set_behaviour(&"strategic_attack", "Deliberately targeting %s because it weakens remote machine operations." % role)
        _share_detection(strategic_target)
        return
    if last_known_target_seconds > 0.0:
        var predicted := last_known_target_position + _target_velocity_hint(current_target) * 2.5
        goal_position = predicted
        has_goal = true
        _set_behaviour(&"route_ambush", "Moving ahead of a known machine route rather than following directly.")
        return
    if force or not has_goal or enemy.global_position.distance_to(goal_position) < 2.2 or state_elapsed > 24.0:
        goal_position = _machine_route_probe_goal()
        has_goal = true
        _set_behaviour(&"probe_defences", "Probing the edge of machine sensor and outpost coverage for a weak approach.")


func _decide_tier_five(force: bool) -> void:
    _influence_lower_tiers()
    var target := _best_regional_target()
    if target != null:
        current_target = target
        var role := _target_role(target)
        _set_behaviour(&"regional_predation", "Selecting %s as a regional strategic constraint rather than attacking randomly." % role)
        _share_detection(target)
        return
    if force or not has_goal or enemy.global_position.distance_to(goal_position) < 3.0 or state_elapsed > 30.0:
        goal_position = _large_territory_goal()
        has_goal = true
        _set_behaviour(&"maintain_large_territory", "Patrolling a large territory and changing how lower tiers move through it.")


func _execute_behaviour(delta: float, remote: bool) -> void:
    current_target = _validate_target(current_target)
    if current_target != null:
        var retention_radius: float = [16.0, 30.0, 58.0, 88.0, 145.0][enemy_tier - 1]
        if enemy.global_position.distance_to(current_target.global_position) > retention_radius:
            current_target = null
    if current_target != null:
        var retention_radius: float = [16.0, 30.0, 58.0, 88.0, 145.0][enemy_tier - 1]
        if enemy.global_position.distance_to(current_target.global_position) > retention_radius:
            current_target = null
    if current_target != null:
        last_known_target_position = current_target.global_position
        last_known_target_seconds = maxf(last_known_target_seconds, 4.0)
        var distance := enemy.global_position.distance_to(current_target.global_position)
        var attack_range := maxf(0.5, float(enemy.get("attack_range")))
        if distance <= attack_range:
            _stop_motion(remote)
            _attack_target(current_target)
            return
        goal_position = _approach_position(current_target)
        has_goal = true
    if not has_goal:
        _stop_motion(remote)
        return
    _move_toward_goal(delta, remote)


func _move_toward_goal(delta: float, remote: bool) -> void:
    var direction := goal_position - enemy.global_position
    direction.y = 0.0
    if direction.length() <= 0.65:
        has_goal = false
        _stop_motion(remote)
        return
    direction = direction.normalized()
    var speed := maxf(0.5, float(enemy.get("move_speed")))
    if behaviour in [&"retreat", &"withdraw_and_reinforce"]:
        speed *= 1.12
    elif behaviour in [&"guard_nest", &"strategic_attack", &"regional_predation"]:
        speed *= 1.04
    if remote:
        enemy.global_position += direction * speed * delta * 0.78
        enemy.rotation.y = atan2(direction.x, direction.z)
        enemy.set("velocity", direction * speed * 0.78)
        return
    var velocity := enemy.velocity
    velocity.x = move_toward(velocity.x, direction.x * speed, 14.0 * delta)
    velocity.z = move_toward(velocity.z, direction.z * speed, 14.0 * delta)
    velocity.y = -0.8
    enemy.velocity = velocity
    enemy.rotation.y = lerp_angle(enemy.rotation.y, atan2(direction.x, direction.z), 0.16 + float(enemy_tier) * 0.018)
    enemy.move_and_slide()


func _stop_motion(remote: bool) -> void:
    if remote:
        enemy.set("velocity", Vector3.ZERO)
        return
    var velocity := enemy.velocity
    velocity.x = move_toward(velocity.x, 0.0, 0.8)
    velocity.z = move_toward(velocity.z, 0.0, 0.8)
    velocity.y = -0.8
    enemy.velocity = velocity
    enemy.move_and_slide()


func _attack_target(target: Node3D) -> void:
    if target == null or not is_instance_valid(target):
        return
    if enemy.has_method(&"_attack_target"):
        enemy.call(&"_attack_target", target)
        return
    var cooldown := float(enemy.get("attack_cooldown"))
    if cooldown > 0.0:
        enemy.set("attack_cooldown", maxf(0.0, cooldown - get_physics_process_delta_time()))
        return
    enemy.set("attack_cooldown", maxf(0.2, float(enemy.get("attack_interval"))))
    if target.has_method(&"apply_damage"):
        target.call(&"apply_damage", maxf(1.0, float(enemy.get("attack_damage"))), enemy)


func _best_visible_target() -> Node3D:
    var radius: float = [11.0, 18.0, 30.0, 42.0, 58.0][enemy_tier - 1]
    var candidates := _query_targets(radius)
    var best: Node3D
    var best_score := -INF
    for candidate in candidates:
        if not _target_is_alive(candidate):
            continue
        var distance := enemy.global_position.distance_to(candidate.global_position)
        var score := -distance
        if enemy_tier >= 3:
            score += _vulnerability_score(candidate) * 12.0
        if enemy_tier >= 4:
            score += _strategic_value(candidate) * 16.0
        if score > best_score:
            best = candidate
            best_score = score
    return best


func _query_targets(radius: float) -> Array[Node3D]:
    var result: Array[Node3D] = []
    if spatial_index != null and is_instance_valid(spatial_index) and spatial_index.has_method(&"query_radius"):
        for group_name in [&"friendly_robots", &"outposts"]:
            for node in spatial_index.call(&"query_radius", group_name, enemy.global_position, radius):
                if node is Node3D:
                    result.append(node)
    else:
        for group_name in [&"friendly_robots", &"outposts"]:
            for node in get_tree().get_nodes_in_group(group_name):
                if node is Node3D and enemy.global_position.distance_to(node.global_position) <= radius:
                    result.append(node)
    var player := get_tree().get_first_node_in_group(&"player_character") as Node3D
    if player != null and enemy.global_position.distance_to(player.global_position) <= radius:
        result.append(player)
    return result


func _best_vulnerable_machine_target(radius: float) -> Node3D:
    var best: Node3D
    var best_score := -INF
    for target in _query_targets(radius):
        if not _target_is_alive(target):
            continue
        var score := _vulnerability_score(target) * 18.0 - enemy.global_position.distance_to(target.global_position)
        if score > best_score:
            best = target
            best_score = score
    return best


func _best_strategic_target(radius: float) -> Node3D:
    var best: Node3D
    var best_score := -INF
    for target in _query_targets(radius):
        if not _target_is_alive(target):
            continue
        var score := _strategic_value(target) * 24.0 + _vulnerability_score(target) * 8.0 - enemy.global_position.distance_to(target.global_position) * 0.42
        if score > best_score:
            best = target
            best_score = score
    return best


func _best_regional_target() -> Node3D:
    var candidates := _query_targets(130.0)
    var heartforge := _find_node_with_method(get_tree().current_scene, &"set_operation") as Node3D
    if heartforge != null and heartforge.is_in_group(&"heartforge"):
        candidates.append(heartforge)
    var best: Node3D
    var best_score := -INF
    for target in candidates:
        if not _target_is_alive(target):
            continue
        var score := _strategic_value(target) * 35.0 - enemy.global_position.distance_to(target.global_position) * 0.18
        if score > best_score:
            best = target
            best_score = score
    return best


func _nearest_hostile_to_home(radius: float) -> Node3D:
    if home_nest == null or not is_instance_valid(home_nest):
        return null
    var best: Node3D
    var best_distance := radius
    for target in _query_targets(radius + enemy.global_position.distance_to(home_nest.global_position)):
        var distance := home_nest.global_position.distance_to(target.global_position)
        if distance < best_distance and _target_is_alive(target):
            best = target
            best_distance = distance
    return best


func _nearest_living_nest() -> Node3D:
    if director == null:
        return home_nest
    var best: Node3D
    var best_distance := INF
    for nest in director.nests.values():
        if not is_instance_valid(nest) or not (nest is Node3D):
            continue
        if nest.has_method(&"is_alive") and not bool(nest.call(&"is_alive")):
            continue
        var distance := enemy.global_position.distance_to(nest.global_position)
        if distance < best_distance:
            best = nest
            best_distance = distance
    return best


func _vulnerability_score(target: Node3D) -> float:
    var score := 0.0
    if target.is_in_group(&"player_character"):
        score += 1.4
        if target.has_method(&"is_channeling") and bool(target.call(&"is_channeling")):
            score += 2.2
    var archetype := StringName(str(target.get("archetype")))
    match archetype:
        &"salvager":
            score += 2.4
        &"engineer":
            score += 2.6
        &"scout":
            score += 1.5
        &"guardian", &"companion":
            score -= 1.4
    if target.has_method(&"is_alive"):
        var maximum := maxf(1.0, float(target.get("maximum_health")))
        var current := float(target.get("current_health"))
        score += (1.0 - current / maximum) * 1.8
    return score


func _strategic_value(target: Node3D) -> float:
    var score := 0.0
    if target.is_in_group(&"outposts"):
        score += 2.5
        var role := StringName(str(target.get("role")))
        if role in [&"repair", &"scout"]:
            score += 1.1
        elif role == &"resource":
            score += 0.8
    if target.is_in_group(&"heartforge") or String(target.name).to_lower().contains("heartforge"):
        score += 4.5
    score += _vulnerability_score(target)
    return score


func _target_role(target: Node3D) -> String:
    if target == null:
        return "an unknown machine target"
    if target.is_in_group(&"player_character"):
        return "the exposed Mechromancer"
    if target.is_in_group(&"outposts"):
        return "a %s outpost" % str(target.get("role"))
    var archetype := str(target.get("archetype"))
    if not archetype.is_empty() and archetype != "<null>":
        return "a %s frame" % archetype
    if String(target.name).to_lower().contains("heartforge"):
        return "the Heartforge"
    return "a machine asset"


func _approach_position(target: Node3D) -> Vector3:
    if enemy_tier < 4:
        return target.global_position
    var velocity_hint := _target_velocity_hint(target)
    return target.global_position + velocity_hint * (1.2 + float(enemy_tier - 3) * 0.8)


func _target_velocity_hint(target: Node3D) -> Vector3:
    if target == null or not is_instance_valid(target):
        return Vector3.ZERO
    if target is CharacterBody3D:
        return (target as CharacterBody3D).velocity
    return Vector3.ZERO


func _has_recent_noise() -> bool:
    return float(enemy.get("investigate_seconds")) > 0.0


func _investigate_position() -> Vector3:
    var value: Variant = enemy.get("investigate_position")
    return value as Vector3 if value is Vector3 else territory_center


func _should_retreat() -> bool:
    var maximum := maxf(1.0, float(enemy.get("maximum_health")))
    var current := float(enemy.get("current_health"))
    return current / maximum < (0.22 if enemy_tier == 3 else 0.3)


func _scouting_goal(serial: int) -> Vector3:
    var player := get_tree().get_first_node_in_group(&"player_character") as Node3D
    var heartforge := _find_heartforge()
    var anchor := heartforge.global_position if heartforge != null else (player.global_position if player != null else Vector3.ZERO)
    var direction := anchor - territory_center
    direction.y = 0.0
    if direction.length_squared() < 0.1:
        direction = Vector3.FORWARD
    direction = direction.normalized()
    var lateral := Vector3(-direction.z, 0.0, direction.x) * sin(float(serial) * 1.7) * 22.0
    return territory_center + direction * (territory_radius + 18.0 + float(serial % 3) * 7.0) + lateral


func _machine_route_probe_goal() -> Vector3:
    var outposts := get_tree().get_nodes_in_group(&"outposts")
    if not outposts.is_empty():
        var target := outposts[roam_serial % outposts.size()] as Node3D
        roam_serial += 1
        var heartforge := _find_heartforge()
        if heartforge != null:
            return target.global_position.lerp(heartforge.global_position, 0.42 + float(roam_serial % 3) * 0.13)
        return target.global_position
    return _scouting_goal(roam_serial + 3)


func _large_territory_goal() -> Vector3:
    roam_serial += 1
    var angle := fmod(float(roam_serial * 97), 360.0) * PI / 180.0
    var radius := territory_radius * (0.62 + float(roam_serial % 4) * 0.11)
    return territory_center + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _influence_lower_tiers() -> void:
    for other in get_tree().get_nodes_in_group(&"enemy_tier_brained"):
        if other == enemy or not (other is Node3D):
            continue
        var other_enemy := other as Node3D
        if enemy.global_position.distance_to(other_enemy.global_position) > 34.0:
            continue
        var other_tier := int(other_enemy.get_meta(&"enemy_tier", 1))
        if other_tier >= enemy_tier:
            continue
        other_enemy.set_meta(&"apex_influenced_until", Time.get_ticks_msec() + 9000)
        other_enemy.set("aggression", maxf(float(other_enemy.get("aggression")), 0.82))


func _share_detection(target: Node3D) -> void:
    if target == null:
        return
    last_known_target_position = target.global_position
    for other in get_tree().get_nodes_in_group(&"enemy_tier_brained"):
        if other == enemy or not (other is Node3D):
            continue
        var other_enemy := other as Node3D
        if StringName(str(other_enemy.get_meta(&"enemy_pack_id", ""))) != pack_id:
            continue
        if enemy.global_position.distance_to(other_enemy.global_position) > 38.0 + float(enemy_tier) * 4.0:
            continue
        var brain := other_enemy.get_node_or_null("EnemyTierBrain")
        if brain != null and brain.has_method(&"receive_shared_detection"):
            brain.call(&"receive_shared_detection", target, target.global_position, enemy)
    detection_shared.emit(enemy, target, target.global_position)


func receive_shared_detection(target: Node3D, position: Vector3, source_enemy: Node3D) -> void:
    if enemy_tier < 3:
        return
    current_target = target if _target_is_alive(target) else null
    last_known_target_position = position
    last_known_target_seconds = 12.0 + float(enemy_tier) * 5.0
    if current_target == null:
        goal_position = position
        has_goal = true
        _set_behaviour(&"respond_to_shared_detection", "Responding to prey information shared by another advanced organism.")


func _target_is_alive(target: Node3D) -> bool:
    if target == null or not is_instance_valid(target):
        return false
    if target.has_method(&"is_alive"):
        return bool(target.call(&"is_alive"))
    return true


func _validate_target(target: Node3D) -> Node3D:
    return target if _target_is_alive(target) else null


func _find_heartforge() -> Node3D:
    var candidates := get_tree().get_nodes_in_group(&"heartforge")
    if not candidates.is_empty() and candidates[0] is Node3D:
        return candidates[0] as Node3D
    return _find_node_named(get_tree().current_scene, "heartforge")


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


func _simulation_focus_position() -> Vector3:
    var player := get_tree().get_first_node_in_group(&"player_character") as Node3D
    return player.global_position if player != null else Vector3.ZERO


func _random_point(center: Vector3, radius: float, serial: int) -> Vector3:
    var angle := fmod(float(serial * 137 + enemy.get_instance_id() % 101), 360.0) * PI / 180.0
    var fraction := 0.28 + fmod(float(serial * 47 + enemy.get_instance_id() % 67), 71.0) / 100.0
    return center + Vector3(cos(angle) * radius * fraction, 0.0, sin(angle) * radius * fraction)


func _set_behaviour(next: StringName, reason: String) -> void:
    if behaviour == next and behaviour_reason == reason:
        return
    behaviour = next
    behaviour_reason = reason
    state_elapsed = 0.0
    enemy.set_meta(&"enemy_behaviour", String(behaviour))
    enemy.set_meta(&"enemy_behaviour_reason", behaviour_reason)
    enemy.set("state_name", behaviour)
    behaviour_changed.emit(enemy, enemy_tier, behaviour, behaviour_reason)
