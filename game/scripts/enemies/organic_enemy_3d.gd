class_name OrganicEnemy3D
extends CharacterBody3D

const AUTHORED_VEILSTALKER_MODEL_SCENE := "res://assets/veilstalker/veilstalker.gltf"
const AUTHORED_RAZORHOUND_MODEL_SCENE := "res://assets/razorhound/razorhound.gltf"
const AUTHORED_APEX_MODEL_SCENE := "res://assets/apex/apex.gltf"
const AUTHORED_SPORECASTER_MODEL_SCENE := "res://assets/sporecaster/sporecaster.gltf"
const AUTHORED_BROODMASS_MODEL_SCENE := "res://assets/broodmass/broodmass.gltf"
const AUTHORED_BURROWER_MODEL_SCENE := "res://assets/burrower/burrower.gltf"
const AUTHORED_SKITTERLING_MODEL_SCENE := "res://assets/skitterling/skitterling.gltf"
const AUTHORED_ROOFLEAPER_MODEL_SCENE := "res://assets/roofleaper/roofleaper.gltf"
const AUTHORED_GLASSMOTH_MODEL_SCENE := "res://assets/glassmoth/glassmoth.gltf"
const AUTHORED_MIREMAW_MODEL_SCENE := "res://assets/miremaw/miremaw.gltf"
const AUTHORED_CARRIONBELL_MODEL_SCENE := "res://assets/carrionbell/carrionbell.gltf"
const AUTHORED_ROOTWEAVER_MODEL_SCENE := "res://assets/rootweaver/rootweaver.gltf"
const AUTHORED_THORNBACK_MODEL_SCENE := "res://assets/thornback/thornback.gltf"
const AUTHORED_ASHMANTLE_MODEL_SCENE := "res://assets/ashmantle/ashmantle.gltf"
const DEATH_PRESENTATION_SECONDS := 0.72

signal killed(enemy: OrganicEnemy3D, killer: Node)
signal attack_started(enemy: OrganicEnemy3D, target: Node)
signal attack_landed(enemy: OrganicEnemy3D, target: Node)
signal health_changed(enemy: OrganicEnemy3D, current: float, maximum: float)
signal behaviour_changed(enemy: OrganicEnemy3D, behaviour: StringName)

var species: StringName = &"skitterling"
var maximum_health: float = 30.0
var current_health: float = 30.0
var move_speed: float = 4.2
var attack_damage: float = 9.0
var attack_range: float = 1.35
var attack_interval: float = 1.25
var detection_range: float = 14.0
var attack_cooldown: float = 0.0
var attack_windup_remaining: float = 0.0
var pending_attack_target: Node3D
var state_name: StringName = &"lurking"
var investigate_position: Vector3
var investigate_seconds: float = 0.0
var aggression: float = 0.2
var player_reference: Node3D
var heartforge_reference: Node3D
var alive: bool = true
var death_presentation_remaining: float = 0.0

# Organic creatures exist in an ecology rather than as stationary combat
# turrets. Every creature has a home territory and a current ecological role.
var territory_origin: Vector3 = Vector3.ZERO
var territory_radius: float = 18.0
var ecology_directive: StringName = &"roam"
var behaviour_clock: float = 0.0
var behaviour_duration: float = 4.0
var behaviour_target: Vector3 = Vector3.ZERO
var behaviour_has_target: bool = false
var behaviour_serial: int = 0
var scouting_outbound: bool = true
var pack_alert_cooldown: float = 0.0
var last_known_prey_position: Vector3 = Vector3.ZERO
var has_last_known_prey: bool = false
var obstacle_recovery_remaining: float = 0.0
var obstacle_recovery_direction: Vector3 = Vector3.ZERO
var movement_reason: String = "Following the current ecological route."

var _target: Node3D
var _model_root: Node3D
var defer_authored_visuals: bool = false
var _deferred_proxy_root: Node3D
var _damage_visual_root: Node3D
var _damage_signal_material: StandardMaterial3D
var _death_visual_root: Node3D
var _death_signal_material: StandardMaterial3D
var _damage_presentation_enabled: bool = true


func _ready() -> void:
    add_to_group(&"organic_enemies")
    collision_layer = 4
    collision_mask = 1 | 2 | 4
    _apply_species_stats()
    if territory_origin == Vector3.ZERO:
        territory_origin = global_position
    if defer_authored_visuals:
        _build_collision()
        _ensure_deferred_proxy_root()
    else:
        _build_visuals()
    _choose_next_ecological_behaviour(true)


func configure(next_species: StringName, player: Node3D, heartforge: Node3D) -> void:
    species = next_species
    player_reference = player
    heartforge_reference = heartforge
    _apply_species_stats()
    if is_inside_tree():
        _refresh_visuals()
        _build_death_presentation()
        _refresh_damage_presentation()
        _refresh_death_presentation()
        _choose_next_ecological_behaviour(true)


func configure_ecology(home_position: Vector3, radius: float, directive: StringName = &"") -> void:
    territory_origin = home_position
    territory_radius = clampf(radius, 7.0, 42.0)
    ecology_directive = directive if directive != &"" else _default_ecology_directive()
    behaviour_clock = 0.0
    behaviour_has_target = false
    _choose_next_ecological_behaviour(true)


func hear_noise(position: Vector3, radius: float, intensity: float, source_kind: StringName) -> void:
    if not alive:
        return
    var distance_to_noise := global_position.distance_to(position)
    if distance_to_noise > radius:
        return
    investigate_position = position
    investigate_seconds = maxf(investigate_seconds, 4.5 + intensity * 4.5)
    aggression = clampf(aggression + intensity * 0.22, 0.0, 1.0)
    last_known_prey_position = position
    has_last_known_prey = true
    _set_state(&"investigating")
    if species in [&"razorhound", &"veilstalker", &"thornback"] and intensity >= 0.55:
        _alert_nearby_pack(position, intensity)


func receive_pack_alert(position: Vector3, intensity: float) -> void:
    if not alive:
        return
    if global_position.distance_to(position) > 26.0:
        return
    last_known_prey_position = position
    has_last_known_prey = true
    investigate_position = position
    investigate_seconds = maxf(investigate_seconds, 3.5 + intensity * 3.0)
    aggression = clampf(aggression + intensity * 0.12, 0.0, 1.0)
    _set_state(&"pack_hunt")


func _physics_process(delta: float) -> void:
    if not alive:
        death_presentation_remaining = maxf(0.0, death_presentation_remaining - delta)
        _refresh_death_presentation()
        if death_presentation_remaining <= 0.0:
            queue_free()
        return
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    if attack_windup_remaining > 0.0:
        attack_windup_remaining = maxf(0.0, attack_windup_remaining - delta)
        _set_state(&"attacking")
        _slow_to_stop(delta)
        if attack_windup_remaining <= 0.0:
            _resolve_pending_attack()
        return
    investigate_seconds = maxf(0.0, investigate_seconds - delta)
    pack_alert_cooldown = maxf(0.0, pack_alert_cooldown - delta)
    behaviour_clock += delta

    _target = _choose_target()
    if _target != null:
        last_known_prey_position = _target.global_position
        has_last_known_prey = true
        var target_distance := global_position.distance_to(_target.global_position)
        if target_distance <= attack_range:
            _attack_target(_target)
            _slow_to_stop(delta)
        else:
            _set_state(&"hunting")
            _move_toward(_target.global_position, _hunt_speed(), delta)
            if species == &"razorhound" and pack_alert_cooldown <= 0.0:
                _alert_nearby_pack(_target.global_position, 0.8)
        return

    if investigate_seconds > 0.0:
        _set_state(&"investigating")
        if global_position.distance_to(investigate_position) <= 1.3:
            _circle_point(investigate_position, 3.5, delta)
        else:
            _move_toward(investigate_position, move_speed * 0.82, delta)
        return

    _update_ecological_behaviour(delta)


func _choose_target() -> Node3D:
    var awareness := detection_range + aggression * 11.0
    match ecology_directive:
        &"hunt":
            awareness *= 1.42
        &"scout":
            awareness *= 1.18
        &"protect_nest":
            awareness *= 1.12

    var best: Node3D
    var best_score := INF
    if player_reference != null and is_instance_valid(player_reference) and player_reference.has_method(&"is_alive") and bool(player_reference.call(&"is_alive")):
        var distance := global_position.distance_to(player_reference.global_position)
        if distance <= awareness and _target_allowed_by_territory(player_reference.global_position):
            var score := distance * _prey_priority_multiplier(player_reference)
            if score < best_score:
                best = player_reference
                best_score = score

    for robot in get_tree().get_nodes_in_group(&"friendly_robots"):
        if not is_instance_valid(robot) or not (robot is Node3D):
            continue
        if robot.has_method(&"is_alive") and not bool(robot.call(&"is_alive")):
            continue
        var distance := global_position.distance_to(robot.global_position)
        if distance > awareness or not _target_allowed_by_territory(robot.global_position):
            continue
        var score := distance * _prey_priority_multiplier(robot)
        if score < best_score:
            best = robot
            best_score = score

    if heartforge_reference != null and is_instance_valid(heartforge_reference) and aggression > 0.72:
        var forge_distance := global_position.distance_to(heartforge_reference.global_position)
        if forge_distance <= awareness * 1.15 and forge_distance < best_score:
            best = heartforge_reference

    return best


func _target_allowed_by_territory(position: Vector3) -> bool:
    if ecology_directive != &"protect_nest":
        return true
    return territory_origin.distance_to(position) <= territory_radius + detection_range * 0.75


func _prey_priority_multiplier(target: Node3D) -> float:
    if species == &"razorhound":
        if target is Mechromancer3D:
            return 0.78
        if target is RobotUnit3D and (target as RobotUnit3D).archetype in [&"salvager", &"scout"]:
            return 0.72
    elif species == &"veilstalker":
        if target is Mechromancer3D:
            return 0.7
    elif species == &"broodmass":
        if target is RobotUnit3D and (target as RobotUnit3D).archetype == &"guardian":
            return 0.82
    elif species == &"ashmantle":
        if target is RobotUnit3D and (target as RobotUnit3D).archetype in [&"engineer", &"salvager"]:
            return 0.68
    elif species == &"thornback":
        if target is Outpost3D:
            return 0.82
    return 1.0


func _hunt_speed() -> float:
    if species == &"razorhound":
        return move_speed * 1.05
    if species == &"veilstalker":
        return move_speed * 0.96
    if species == &"ashmantle":
        return move_speed * 0.94
    return move_speed


func _update_ecological_behaviour(delta: float) -> void:
    if behaviour_clock >= behaviour_duration or not behaviour_has_target or global_position.distance_to(behaviour_target) <= 1.15:
        _choose_next_ecological_behaviour(false)

    match state_name:
        &"nest_guard":
            if territory_origin.distance_to(global_position) > territory_radius * 0.95:
                _move_toward(territory_origin, move_speed * 0.78, delta)
            else:
                _move_toward(behaviour_target, move_speed * 0.55, delta)
        &"patrolling":
            _move_toward(behaviour_target, move_speed * 0.62, delta)
        &"roaming":
            _move_toward(behaviour_target, move_speed * 0.58, delta)
        &"scouting":
            _move_toward(behaviour_target, move_speed * 0.74, delta)
        &"tracking":
            _move_toward(behaviour_target, move_speed * 0.82, delta)
        &"feeding":
            _move_toward(behaviour_target, move_speed * 0.46, delta)
        _:
            _slow_to_stop(delta)


func _choose_next_ecological_behaviour(force: bool) -> void:
    if not force and behaviour_clock < 0.35:
        return
    behaviour_serial += 1
    behaviour_clock = 0.0
    behaviour_duration = 4.0 + _deterministic_unit(behaviour_serial, 3) * 5.0
    behaviour_has_target = true

    var directive := ecology_directive
    if directive == &"":
        directive = _default_ecology_directive()
        ecology_directive = directive

    match directive:
        &"protect_nest":
            if behaviour_serial % 4 == 0:
                _set_state(&"patrolling")
                behaviour_target = _territory_orbit_point(0.72, behaviour_serial)
            else:
                _set_state(&"nest_guard")
                behaviour_target = _territory_orbit_point(0.38 + _deterministic_unit(behaviour_serial, 7) * 0.24, behaviour_serial)
        &"patrol":
            _set_state(&"patrolling")
            behaviour_target = _territory_orbit_point(0.55 + _deterministic_unit(behaviour_serial, 5) * 0.38, behaviour_serial)
        &"scout":
            _set_state(&"scouting")
            behaviour_target = _scouting_waypoint()
        &"hunt":
            _set_state(&"tracking")
            behaviour_target = _hunting_waypoint()
        &"feed":
            var salvage := _nearby_salvage_interest()
            if salvage != null:
                _set_state(&"feeding")
                behaviour_target = salvage.global_position
            else:
                _set_state(&"roaming")
                behaviour_target = _territory_orbit_point(0.65 + _deterministic_unit(behaviour_serial, 2) * 0.48, behaviour_serial)
        _:
            _set_state(&"roaming")
            behaviour_target = _territory_orbit_point(0.45 + _deterministic_unit(behaviour_serial, 9) * 0.65, behaviour_serial)


func _default_ecology_directive() -> StringName:
    match species:
        &"skitterling":
            return &"feed"
        &"razorhound":
            return &"hunt"
        &"veilstalker":
            return &"scout"
        &"burrower":
            return &"patrol"
        &"thornback":
            return &"protect_nest"
        &"ashmantle":
            return &"scout"
        &"sporecaster":
            return &"protect_nest"
        &"broodmass":
            return &"protect_nest"
        &"apex":
            return &"patrol"
        _:
            return &"roam"


func _territory_orbit_point(radius_fraction: float, serial: int) -> Vector3:
    var angle := _deterministic_unit(serial, 13) * TAU + float(serial % 3) * 0.83
    var radius := territory_radius * clampf(radius_fraction, 0.18, 1.2)
    return territory_origin + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _scouting_waypoint() -> Vector3:
    if heartforge_reference == null or not is_instance_valid(heartforge_reference):
        return _territory_orbit_point(1.0, behaviour_serial)
    if scouting_outbound:
        scouting_outbound = false
        var toward_forge := heartforge_reference.global_position - territory_origin
        toward_forge.y = 0.0
        if toward_forge.length_squared() < 1.0:
            return _territory_orbit_point(0.9, behaviour_serial)
        var max_advance := minf(toward_forge.length() * 0.58, territory_radius * 1.75)
        var side := Vector3(toward_forge.z, 0.0, -toward_forge.x).normalized()
        return territory_origin + toward_forge.normalized() * max_advance + side * (_deterministic_unit(behaviour_serial, 17) - 0.5) * 12.0
    scouting_outbound = true
    return _territory_orbit_point(0.42, behaviour_serial)


func _hunting_waypoint() -> Vector3:
    if has_last_known_prey:
        has_last_known_prey = false
        var offset_angle := _deterministic_unit(behaviour_serial, 23) * TAU
        return last_known_prey_position + Vector3(cos(offset_angle) * 4.0, 0.0, sin(offset_angle) * 4.0)
    if heartforge_reference != null and is_instance_valid(heartforge_reference):
        var toward := heartforge_reference.global_position - territory_origin
        toward.y = 0.0
        if toward.length_squared() > 1.0:
            var distance := minf(toward.length() * (0.32 + _deterministic_unit(behaviour_serial, 29) * 0.3), territory_radius * 1.55)
            var side := Vector3(toward.z, 0.0, -toward.x).normalized()
            return territory_origin + toward.normalized() * distance + side * (_deterministic_unit(behaviour_serial, 31) - 0.5) * 14.0
    return _territory_orbit_point(1.05, behaviour_serial)


func _nearby_salvage_interest() -> SalvagePile3D:
    var best: SalvagePile3D
    var best_distance := 24.0
    for candidate in get_tree().get_nodes_in_group(&"salvage_piles"):
        if not is_instance_valid(candidate) or not (candidate is SalvagePile3D) or not candidate.has_scrap():
            continue
        var distance := global_position.distance_to(candidate.global_position)
        if distance < best_distance:
            best = candidate
            best_distance = distance
    return best


func _deterministic_unit(serial: int, salt: int) -> float:
    var value := sin(float(get_instance_id() % 8191) * 0.173 + float(serial) * 12.9898 + float(salt) * 4.1414) * 43758.5453
    return value - floor(value)


func _circle_point(center: Vector3, radius: float, delta: float) -> void:
    var to_center := center - global_position
    to_center.y = 0.0
    if to_center.length_squared() < 0.05:
        to_center = Vector3.FORWARD
    var tangent := Vector3(to_center.z, 0.0, -to_center.x).normalized()
    var radial := to_center.normalized()
    var desired := global_position + tangent * radius * 0.5 + radial * maxf(0.0, to_center.length() - radius)
    _move_toward(desired, move_speed * 0.62, delta)


func _alert_nearby_pack(position: Vector3, intensity: float) -> void:
    pack_alert_cooldown = 3.2
    for enemy in get_tree().get_nodes_in_group(&"organic_enemies"):
        if enemy == self or not is_instance_valid(enemy) or not (enemy is OrganicEnemy3D):
            continue
        var other := enemy as OrganicEnemy3D
        if not other.is_alive() or other.species != species:
            continue
        if global_position.distance_to(other.global_position) <= 24.0:
            other.receive_pack_alert(position, intensity)


func _set_state(next_state: StringName) -> void:
    if state_name == next_state:
        return
    state_name = next_state
    behaviour_changed.emit(self, state_name)


func _move_toward(target_position: Vector3, speed: float, delta: float) -> void:
    obstacle_recovery_remaining = maxf(0.0, obstacle_recovery_remaining - delta)
    var direction := target_position - global_position
    direction.y = 0.0
    if direction.length_squared() < 0.04:
        _slow_to_stop(delta)
        return
    direction = direction.normalized()
    var steering_direction := direction
    if obstacle_recovery_remaining > 0.0 and obstacle_recovery_direction.length_squared() > 0.01:
        steering_direction = (direction + obstacle_recovery_direction * 0.9).normalized()
    velocity.x = move_toward(velocity.x, steering_direction.x * speed, 14.0 * delta)
    velocity.z = move_toward(velocity.z, steering_direction.z * speed, 14.0 * delta)
    velocity.y = -0.9
    rotation.y = lerp_angle(rotation.y, atan2(steering_direction.x, steering_direction.z), 0.22)
    var position_before := global_position
    move_and_slide()
    _register_blocked_route(position_before, direction, speed, delta)


func _register_blocked_route(position_before: Vector3, desired_direction: Vector3, desired_speed: float, delta: float) -> void:
    if desired_speed <= 0.05 or get_slide_collision_count() == 0:
        return
    var flat_displacement := global_position - position_before
    flat_displacement.y = 0.0
    var forward_progress := flat_displacement.dot(desired_direction)
    if forward_progress >= desired_speed * delta * 0.22:
        return
    var wall_normal := Vector3.ZERO
    for index in get_slide_collision_count():
        var collision := get_slide_collision(index)
        if collision.get_normal().y <= 0.72:
            wall_normal += collision.get_normal()
    var tangent: Vector3
    if wall_normal.length_squared() < 0.01:
        tangent = Vector3(-desired_direction.z, 0.0, desired_direction.x).normalized()
    else:
        wall_normal.y = 0.0
        wall_normal = wall_normal.normalized()
        tangent = Vector3(-wall_normal.z, 0.0, wall_normal.x).normalized()
    if tangent.dot(desired_direction) < 0.0:
        tangent = -tangent
    obstacle_recovery_direction = tangent
    obstacle_recovery_remaining = 0.48
    movement_reason = "Taking a short recovery arc around a blocked route while preserving the ecological objective."


func _slow_to_stop(delta: float) -> void:
    velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
    velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
    velocity.y = -0.9
    move_and_slide()


func _attack_target(target: Node) -> void:
    _set_state(&"attacking")
    if attack_cooldown > 0.0 or attack_windup_remaining > 0.0 or not (target is Node3D):
        return
    attack_cooldown = attack_interval
    pending_attack_target = target as Node3D
    attack_windup_remaining = _attack_windup_duration()
    attack_started.emit(self, target)


func _resolve_pending_attack() -> void:
    var target := pending_attack_target
    pending_attack_target = null
    if target == null or not is_instance_valid(target):
        return
    if global_position.distance_to(target.global_position) > attack_range * 1.35:
        return
    if target.has_method(&"apply_damage"):
        target.call(&"apply_damage", attack_damage, self)
    attack_landed.emit(self, target)


func _attack_windup_duration() -> float:
    match species:
        &"sporecaster", &"ashmantle":
            return 0.34
        &"broodmass", &"apex":
            return 0.3
        &"veilstalker":
            return 0.26
        _:
            return 0.22


func apply_damage(amount: float, source: Node = null) -> void:
    if not alive or amount <= 0.0:
        return
    current_health = maxf(0.0, current_health - amount)
    health_changed.emit(self, current_health, maximum_health)
    _refresh_damage_presentation()
    aggression = 1.0
    if source is Node3D:
        investigate_position = source.global_position
        last_known_prey_position = source.global_position
        has_last_known_prey = true
        investigate_seconds = 10.0
        if species in [&"razorhound", &"veilstalker", &"thornback"]:
            _alert_nearby_pack(source.global_position, 1.0)
    if current_health > 0.0:
        return
    alive = false
    _set_state(&"dead")
    velocity = Vector3.ZERO
    attack_windup_remaining = 0.0
    collision_layer = 0
    collision_mask = 0
    death_presentation_remaining = DEATH_PRESENTATION_SECONDS
    _refresh_death_presentation()
    killed.emit(self, source)


func is_alive() -> bool:
    return alive and current_health > 0.0


func _apply_species_stats() -> void:
    attack_range = 1.35
    match species:
        &"razorhound":
            maximum_health = 54.0
            move_speed = 5.1
            attack_damage = 14.0
            detection_range = 17.0
            attack_interval = 1.15
        &"veilstalker":
            maximum_health = 78.0
            move_speed = 4.5
            attack_damage = 18.0
            detection_range = 20.0
            attack_interval = 1.45
        &"burrower":
            maximum_health = 96.0
            move_speed = 5.6
            attack_damage = 16.0
            detection_range = 15.0
            attack_interval = 1.05
        &"sporecaster":
            maximum_health = 88.0
            move_speed = 3.5
            attack_damage = 12.0
            attack_range = 7.2
            detection_range = 22.0
            attack_interval = 2.2
        &"broodmass":
            maximum_health = 185.0
            move_speed = 3.0
            attack_damage = 25.0
            attack_range = 1.9
            detection_range = 24.0
            attack_interval = 1.7
        &"apex":
            maximum_health = 440.0
            move_speed = 3.8
            attack_damage = 34.0
            attack_range = 2.35
            detection_range = 32.0
            attack_interval = 1.55
        &"thornback":
            maximum_health = 74.0
            move_speed = 4.2
            attack_damage = 15.0
            attack_range = 1.6
            detection_range = 18.0
            attack_interval = 1.35
        &"ashmantle":
            maximum_health = 126.0
            move_speed = 3.7
            attack_damage = 17.0
            attack_range = 5.8
            detection_range = 26.0
            attack_interval = 2.0
        _:
            maximum_health = 28.0
            move_speed = 4.4
            attack_damage = 9.0
            detection_range = 13.0
            attack_interval = 1.2
    current_health = maximum_health
    ecology_directive = _default_ecology_directive()


func _build_collision() -> void:
    var collision_radius := 0.5
    var collision_height := 0.9
    if species == &"broodmass":
        collision_radius = 0.85
        collision_height = 1.4
    elif species == &"apex":
        collision_radius = 1.15
        collision_height = 2.0
    elif species == &"thornback":
        collision_radius = 0.68
        collision_height = 1.2
    elif species == &"ashmantle":
        collision_radius = 0.78
        collision_height = 1.55
    if get_node_or_null("CollisionShape3D") == null:
        ModelKit3D.add_collision_capsule(self, collision_radius, collision_height, Vector3(0.0, collision_height * 0.5, 0.0))


func _build_visuals() -> void:
    _build_collision()
    _model_root = Node3D.new()
    _model_root.name = "OrganicModel"
    add_child(_model_root)
    _refresh_visuals()
    _build_damage_presentation()
    _build_death_presentation()


func ensure_authored_visuals() -> void:
    if _model_root != null and is_instance_valid(_model_root):
        return
    if _deferred_proxy_root != null and is_instance_valid(_deferred_proxy_root):
        _deferred_proxy_root.free()
    _deferred_proxy_root = null
    _build_visuals()


func _instantiate_authored_scene(path: String, label: String) -> Node3D:
    var resource := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
    if not (resource is PackedScene):
        push_error("Organic authored scene could not be loaded for %s: %s" % [label, path])
        return null
    var instance := (resource as PackedScene).instantiate() as Node3D
    if instance == null:
        push_error("Organic authored scene could not be instantiated for %s: %s" % [label, path])
    return instance


func set_damage_presentation_enabled(value: bool) -> void:
    _damage_presentation_enabled = value
    _refresh_damage_presentation()


func _build_damage_presentation() -> void:
    if _damage_visual_root != null and is_instance_valid(_damage_visual_root):
        _damage_visual_root.free()
    _damage_visual_root = Node3D.new()
    _damage_visual_root.name = "OrganicDamagePresentation"
    add_child(_damage_visual_root)

    var size_scale := 1.0
    match species:
        &"broodmass":
            size_scale = 1.28
        &"miremaw", &"rootweaver":
            size_scale = 1.42
        &"apex":
            size_scale = 1.7

    _damage_signal_material = ModelKit3D.material(
        Color("3d1422"),
        0.08,
        0.56,
        Color("d82f52"),
        0.95
    )
    var leak_material := ModelKit3D.material(
        Color("4b1b2a"),
        0.02,
        0.48,
        Color("ff5370"),
        2.1
    )
    var positions := [
        Vector3(-0.38, 1.0, -0.72),
        Vector3(0.32, 1.22, -0.6),
        Vector3(0.04, 0.78, 0.7),
    ]
    for index in range(3):
        var position: Vector3 = positions[index] * size_scale
        ModelKit3D.add_beveled_box(
            _damage_visual_root,
            Vector3(0.07, 0.38 + float(index) * 0.1, 0.11) * size_scale,
            position,
            _damage_signal_material,
            Vector3(0.0, 0.0, -0.32 + float(index) * 0.24),
            "OrganicDamageScar%02d" % index,
            0.24 * size_scale
        )
        ModelKit3D.add_sphere(
            _damage_visual_root,
            (0.065 + float(index) * 0.012) * size_scale,
            position + Vector3.UP * (0.23 + float(index) * 0.07) * size_scale,
            leak_material,
            Vector3(1.0, 0.72, 1.0),
            "OrganicDamageLeak%02d" % index
        )
    _refresh_damage_presentation()


func _refresh_damage_presentation() -> void:
    if _damage_visual_root == null or not is_instance_valid(_damage_visual_root):
        return
    var integrity := clampf(current_health / maxf(1.0, maximum_health), 0.0, 1.0)
    var damage := 1.0 - integrity
    var active := _damage_presentation_enabled and alive and damage > 0.08
    _damage_visual_root.visible = active
    if _damage_signal_material != null:
        _damage_signal_material.emission_energy_multiplier = lerpf(0.65, 3.4, damage)
        _damage_signal_material.albedo_color = Color("321322").lerp(Color("76233f"), damage)
    for index in range(3):
        var scar := _damage_visual_root.get_node_or_null("OrganicDamageScar%02d" % index) as Node3D
        var leak := _damage_visual_root.get_node_or_null("OrganicDamageLeak%02d" % index) as Node3D
        var threshold := 0.08 + float(index) * 0.18
        var visibility := clampf((damage - threshold) / 0.18, 0.0, 1.0)
        if scar != null:
            scar.visible = active and visibility > 0.0
            scar.scale = Vector3(1.0, 0.7 + visibility * 0.3, 1.0)
        if leak != null:
            leak.visible = active and visibility > 0.25


func _build_death_presentation() -> void:
    if _death_visual_root != null and is_instance_valid(_death_visual_root):
        _death_visual_root.free()
    _death_visual_root = Node3D.new()
    _death_visual_root.name = "OrganicDeathPresentation"
    _death_visual_root.visible = false
    add_child(_death_visual_root)

    var size_scale := 1.0
    var signal_color := Color("d83e5c")
    match species:
        &"glassmoth":
            size_scale = 0.78
            signal_color = Color("6ce4dd")
        &"miremaw", &"rootweaver":
            size_scale = 1.35
            signal_color = Color("b52e59")
        &"carrionbell", &"ashmantle":
            size_scale = 1.12
            signal_color = Color("f06b32")
        &"broodmass":
            size_scale = 1.58
            signal_color = Color("9f2947")
        &"apex":
            size_scale = 1.92
            signal_color = Color("f04426")

    var shell_mat := ModelKit3D.material(Color("251b23"), 0.08, 0.78)
    var edge_mat := ModelKit3D.material(Color("5d4a4b"), 0.0, 0.9)
    var root_mat := ModelKit3D.material(Color("321626"), 0.0, 0.72)
    _death_signal_material = ModelKit3D.material(Color("2b101d"), 0.0, 0.5, signal_color, 1.8)

    ModelKit3D.add_segmented_carapace(
        _death_visual_root,
        0.42 * size_scale,
        Vector3(0.0, 0.78 * size_scale, 0.12),
        shell_mat,
        edge_mat,
        Vector3(1.42, 0.62, 1.6),
        3,
        "OrganicDeathCarapace"
    )
    ModelKit3D.add_organic_plate(
        _death_visual_root,
        0.31 * size_scale,
        Vector3(0.0, 0.98 * size_scale, -0.52 * size_scale),
        root_mat,
        edge_mat,
        Vector3(1.28, 0.32, 1.0),
        "OrganicDeathRootCollar"
    )
    for index in range(5):
        var angle := TAU * float(index) / 5.0 + 0.3
        var shard_position := Vector3(cos(angle) * 0.5, 0.78 + float(index % 2) * 0.16, sin(angle) * 0.48) * size_scale
        ModelKit3D.add_beveled_box(
            _death_visual_root,
            Vector3(0.16, 0.34 + float(index % 2) * 0.08, 0.08) * size_scale,
            shard_position,
            edge_mat,
            Vector3(0.18, angle, -0.24 + float(index) * 0.12),
            "OrganicDeathShard%02d" % index,
            0.22
        )
    for index in range(3):
        var vein_side := -1.0 if index % 2 == 0 else 1.0
        ModelKit3D.add_tapered_cylinder(
            _death_visual_root,
            0.025 * size_scale,
            0.045 * size_scale,
            0.68 * size_scale,
            Vector3(vein_side * (0.23 + float(index) * 0.08), 0.84 * size_scale, -0.08 * size_scale),
            root_mat,
            Vector3(0.0, 0.0, vein_side * (0.45 + float(index) * 0.1)),
            "OrganicDeathVein%02d" % index
        )
    for side in [-1.0, 1.0]:
        ModelKit3D.add_capsule(
            _death_visual_root,
            0.035 * size_scale,
            0.72 * size_scale,
            Vector3(side * 0.52 * size_scale, 0.62 * size_scale, 0.18 * size_scale),
            edge_mat,
            Vector3(0.0, 0.0, side * 0.72),
            "OrganicDeathSpine%s" % ("L" if side < 0.0 else "R")
        )
    ModelKit3D.add_sphere(
        _death_visual_root,
        0.12 * size_scale,
        Vector3(0.0, 1.28 * size_scale, -0.48 * size_scale),
        _death_signal_material,
        Vector3(1.0, 0.72, 0.86),
        "OrganicDeathSignal"
    )
    _refresh_death_presentation()


func _refresh_death_presentation() -> void:
    if _death_visual_root == null or not is_instance_valid(_death_visual_root):
        return
    var remaining_ratio := clampf(death_presentation_remaining / DEATH_PRESENTATION_SECONDS, 0.0, 1.0)
    var active := not alive and remaining_ratio > 0.0
    _death_visual_root.visible = active
    if not active:
        return
    _death_visual_root.scale = Vector3(1.0 + (1.0 - remaining_ratio) * 0.08, 0.76 + remaining_ratio * 0.24, 1.0 + (1.0 - remaining_ratio) * 0.08)
    _death_visual_root.rotation.z = (1.0 - remaining_ratio) * 0.18
    if _death_signal_material != null:
        _death_signal_material.emission_energy_multiplier = lerpf(0.25, 1.8, remaining_ratio)


func _ensure_deferred_proxy_root() -> Node3D:
    if _deferred_proxy_root != null and is_instance_valid(_deferred_proxy_root):
        return _deferred_proxy_root
    _deferred_proxy_root = Node3D.new()
    _deferred_proxy_root.name = "DeferredVisualProxy"
    add_child(_deferred_proxy_root)
    return _deferred_proxy_root


func _refresh_visuals() -> void:
    if _model_root == null:
        return
    # Keep the runtime species available to the release material pass while
    # authored children remain nested under OrganicModel. This is presentation
    # metadata only; combat, ecology and collision remain actor-owned.
    _model_root.set_meta(&"ironwright_organic_family", String(species))
    for child in _model_root.get_children():
        # Visuals are rebuilt synchronously when a tier or authored shell is
        # applied. Free the old presentation tree immediately so stable
        # lookup names (for example OrganicModel/Torso/TorsoCore) do not gain
        # numeric suffixes while queued nodes still occupy the parent.
        child.free()
    if species == &"veilstalker":
        _build_authored_veilstalker_visuals()
        return
    if species == &"razorhound":
        _build_authored_razorhound_visuals()
        return
    if species == &"apex":
        _build_authored_apex_visuals()
        return
    if species == &"sporecaster":
        _build_authored_sporecaster_visuals()
        return
    if species == &"broodmass":
        _build_authored_broodmass_visuals()
        return
    if species == &"burrower":
        _build_authored_burrower_visuals()
        return
    if species == &"skitterling":
        _build_authored_skitterling_visuals()
        return
    if species == &"roofleaper":
        _build_authored_organic_family_visuals(AUTHORED_ROOFLEAPER_MODEL_SCENE, &"RoofleaperModel", &"RoofleaperAuthoredModel")
        return
    if species == &"glassmoth":
        _build_authored_organic_family_visuals(AUTHORED_GLASSMOTH_MODEL_SCENE, &"GlassmothModel", &"GlassmothAuthoredModel")
        return
    if species == &"miremaw":
        _build_authored_organic_family_visuals(AUTHORED_MIREMAW_MODEL_SCENE, &"MiremawModel", &"MiremawAuthoredModel")
        return
    if species == &"carrionbell":
        _build_authored_organic_family_visuals(AUTHORED_CARRIONBELL_MODEL_SCENE, &"CarrionbellModel", &"CarrionbellAuthoredModel")
        return
    if species == &"rootweaver":
        _build_authored_organic_family_visuals(AUTHORED_ROOTWEAVER_MODEL_SCENE, &"RootweaverModel", &"RootweaverAuthoredModel")
        return
    if species == &"thornback":
        _build_authored_organic_family_visuals(AUTHORED_THORNBACK_MODEL_SCENE, &"ThornbackModel", &"ThornbackAuthoredModel")
        return
    if species == &"ashmantle":
        _build_authored_organic_family_visuals(AUTHORED_ASHMANTLE_MODEL_SCENE, &"AshmantleModel", &"AshmantleAuthoredModel")
        return
    var flesh := ModelKit3D.material(Color("201719"), 0.0, 0.91)
    var chitin := ModelKit3D.material(Color("332529"), 0.12, 0.66)
    var bone := ModelKit3D.material(Color("786f60"), 0.0, 0.82)
    var membrane := ModelKit3D.material(Color("421727"), 0.0, 0.78, Color("9f2947"), 0.75)
    var eye := ModelKit3D.material(Color("4b0b0a"), 0.0, 0.42, Color("f04426"), 3.2)
    var wet_chitin := ModelKit3D.material(Color("241a25"), 0.2, 0.36)
    var tendon := ModelKit3D.material(Color("713c4a"), 0.0, 0.64)

    var body_scale := Vector3(1.35, 0.7, 1.7)
    var body_radius := 0.62
    var head_offset := -1.0
    if species == &"veilstalker":
        body_scale = Vector3(1.6, 1.15, 2.0)
    elif species == &"burrower":
        body_scale = Vector3(1.8, 0.52, 2.15)
        head_offset = -1.3
    elif species == &"sporecaster":
        body_scale = Vector3(1.45, 1.05, 1.7)
    elif species == &"broodmass":
        body_radius = 0.82
        body_scale = Vector3(2.2, 1.35, 2.35)
        head_offset = -1.5
    elif species == &"apex":
        body_radius = 1.05
        body_scale = Vector3(2.5, 1.65, 2.8)
        head_offset = -2.0

    var segment_count := 3
    if species in [&"veilstalker", &"burrower", &"broodmass", &"apex"]:
        segment_count = 5
    ModelKit3D.add_segmented_carapace(
        _model_root,
        body_radius,
        Vector3(0.0, body_radius + 0.16, 0.0),
        flesh,
        wet_chitin,
        body_scale,
        segment_count,
        "Torso",
        true
    )
    ModelKit3D.add_sphere(_model_root, body_radius * 0.62, Vector3(0.0, body_radius + 0.12, head_offset), chitin, Vector3(1.1, 0.8, 1.25), "Head")
    ModelKit3D.add_organic_plate(_model_root, body_radius * 0.44, Vector3(-body_scale.x * 0.18, body_radius * 1.18, 0.18), wet_chitin, chitin, Vector3(1.45, 0.56, 1.65), "OrganicDorsalPlate", true)

    var leg_pairs := 3
    if species in [&"veilstalker", &"burrower", &"broodmass", &"apex"]:
        leg_pairs = 4
    for index in range(leg_pairs):
        var z_position := -0.7 + float(index) * (1.4 / maxf(1.0, float(leg_pairs - 1)))
        for side in [-1.0, 1.0]:
            var leg_length := 1.35
            if species == &"apex":
                leg_length = 2.2
            elif species == &"broodmass":
                leg_length = 1.8
            ModelKit3D.add_capsule(_model_root, 0.09 * body_radius / 0.62, leg_length, Vector3(side * body_scale.x * 0.48, body_radius * 0.62, z_position), chitin, Vector3(0.0, 0.0, side * 0.92), "Leg")
            ModelKit3D.add_capsule(_model_root, 0.07 * body_radius / 0.62, leg_length * 0.62, Vector3(side * body_scale.x * 0.82, 0.16, z_position + 0.08), bone, Vector3(0.0, 0.0, side * 0.45), "Talon")

    if species == &"skitterling":
        for index in range(3):
            var shell_z := -0.42 + float(index) * 0.42
            ModelKit3D.add_organic_plate(_model_root, 0.28 - float(index) * 0.025, Vector3(0.0, 0.84 + float(index) * 0.05, shell_z), wet_chitin, chitin, Vector3(1.16, 0.42, 0.78), "SkitterlingCarapace", true)
        for side in [-1.0, 1.0]:
            ModelKit3D.add_capsule(_model_root, 0.035, 0.58, Vector3(side * 0.22, 1.08, -1.02), tendon, Vector3(0.5, 0.0, side * 0.18), "SkitterlingAntenna")
            ModelKit3D.add_capsule(_model_root, 0.045, 0.5, Vector3(side * 0.2, 0.66, -1.18), bone, Vector3(0.78, 0.0, side * 0.25), "SkitterlingMandible")
        ModelKit3D.add_membrane_fan(_model_root, 0.2, Vector3(0.0, 1.05, 0.2), tendon, 3, "SkitterlingSensoryFan")

    if species == &"razorhound":
        ModelKit3D.add_sphere(_model_root, 0.34, Vector3(0.0, 0.78, -1.0), wet_chitin, Vector3(1.22, 0.7, 1.42), "RazorhoundSnout")
        for side in [-1.0, 1.0]:
            ModelKit3D.add_organic_plate(_model_root, 0.23, Vector3(side * 0.46, 0.96, -0.12), chitin, bone, Vector3(0.9, 0.42, 1.3), "RazorhoundCheekPlate", true)
        for side in [-1.0, 1.0]:
            ModelKit3D.add_sphere(_model_root, 0.16, Vector3(side * 0.27, 1.12, -0.95), bone, Vector3(0.7, 1.25, 0.72), "RazorhoundEar")
            ModelKit3D.add_capsule(_model_root, 0.055, 0.66, Vector3(side * 0.28, 0.62, -1.22), bone, Vector3(0.8, 0.0, side * 0.18), "RazorhoundFang")
        for index in range(4):
            ModelKit3D.add_capsule(_model_root, 0.065, 0.62 + float(index % 2) * 0.12, Vector3(0.0, 1.0 + float(index) * 0.08, 0.1 + float(index) * 0.36), bone, Vector3(0.0, 0.0, 0.18), "RazorhoundSpine")
        ModelKit3D.add_capsule(_model_root, 0.08, 1.15, Vector3(0.0, 0.8, 1.42), tendon, Vector3(-0.42, 0.0, 0.0), "RazorhoundTail")

    if species == &"veilstalker":
        # First authored organic family pass: the asymmetric thorax, layered
        # veil membranes and forward sensory crown establish a predator
        # silhouette before the creature enters combat range.
        ModelKit3D.add_ribbed_shell(_model_root, 0.56, Vector3(0.0, 0.99, -0.22), wet_chitin, chitin, Vector3(1.84, 0.76, 1.52), "VeilstalkerThorax")
        ModelKit3D.add_sphere(_model_root, 0.42, Vector3(-0.22, 1.18, 0.72), flesh, Vector3(1.28, 0.82, 1.08), "VeilstalkerAbdomen")
        for index in range(3):
            var plate_z := -0.68 + float(index) * 0.44
            ModelKit3D.add_organic_plate(_model_root, 0.34, Vector3(0.0, 1.42 - float(index) * 0.045, plate_z), chitin, bone, Vector3(1.48, 0.55, 0.62), "VeilstalkerDorsalPlate", true)
        for side in [-1.0, 1.0]:
            ModelKit3D.add_sphere(_model_root, 0.34, Vector3(side * 0.98, 1.1, -0.18), membrane, Vector3(0.22, 1.6, 0.9), "VeilstalkerVeil")
            ModelKit3D.add_capsule(_model_root, 0.075, 1.75, Vector3(side * 0.78, 0.72, -0.62), tendon, Vector3(0.22, 0.0, side * 0.34), "VeilstalkerForelimb")
            ModelKit3D.add_capsule(_model_root, 0.06, 0.92, Vector3(side * 0.93, 0.22, -1.02), bone, Vector3(0.58, 0.0, side * 0.2), "VeilstalkerHook")
        ModelKit3D.add_sphere(_model_root, 0.4, Vector3(0.0, 1.36, -1.04), chitin, Vector3(1.12, 0.8, 1.15), "VeilstalkerCowl")
        for index in range(3):
            var tendril_side := -1.0 if index % 2 == 0 else 1.0
            var tendril_x := tendril_side * (0.16 + float(index) * 0.08)
            ModelKit3D.add_capsule(_model_root, 0.035, 0.72 + float(index) * 0.14, Vector3(tendril_x, 1.12, -1.52 - float(index) * 0.05), tendon, Vector3(0.55, 0.0, tendril_side * 0.18), "VeilstalkerTendril")
        for index in range(3):
            var tail_z := 0.72 + float(index) * 0.38
            ModelKit3D.add_sphere(_model_root, 0.19 - float(index) * 0.025, Vector3(-0.22 + float(index) * 0.08, 0.98 - float(index) * 0.06, tail_z), flesh, Vector3(1.35, 0.74, 1.28), "VeilstalkerTail")

    if species == &"sporecaster":
        ModelKit3D.add_membrane_fan(_model_root, 0.42, Vector3(0.0, 1.18, 0.18), membrane, 7, "SporecasterGillFan")
        for index in range(5):
            var angle := TAU * float(index) / 5.0
            var sac_position := Vector3(cos(angle) * 0.55, 1.55, sin(angle) * 0.45)
            ModelKit3D.add_cylinder(_model_root, 0.055, 0.5, sac_position + Vector3(0.0, -0.25, 0.0), tendon, Vector3.ZERO, "SporecasterStem")
            ModelKit3D.add_sphere(_model_root, 0.34, sac_position, membrane, Vector3(0.8, 1.35, 0.8), "SporecasterSac")
            ModelKit3D.add_sphere(_model_root, 0.09, sac_position + Vector3(0.0, 0.25, 0.0), eye, Vector3.ONE, "SporecasterOculus")
    elif species == &"burrower":
        for index in range(3):
            ModelKit3D.add_tapered_cylinder(_model_root, 0.29 - float(index) * 0.025, 0.2, 0.1, Vector3(0.0, 0.76, -1.23 - float(index) * 0.18), wet_chitin, Vector3(1.5708, 0.0, 0.0), "BurrowerDrillRing")
        for index in range(5):
            ModelKit3D.add_capsule(_model_root, 0.1, 0.8, Vector3(-0.8 + float(index) * 0.4, 0.9, 0.1), bone, Vector3(0.0, 0.0, -0.35 + float(index) * 0.16), "BurrowSpine")
        ModelKit3D.add_cylinder(_model_root, 0.22, 0.42, Vector3(0.0, 0.76, -1.52), bone, Vector3(1.5708, 0.0, 0.0), "BurrowerDrill")
        ModelKit3D.add_sphere(_model_root, 0.19, Vector3(0.0, 0.76, -1.76), wet_chitin, Vector3(1.0, 0.72, 1.2), "BurrowerTip")
    elif species in [&"broodmass", &"apex"]:
        var spine_count := 6 if species == &"broodmass" else 9
        for index in range(spine_count):
            var x := -1.2 + float(index) * (2.4 / maxf(1.0, float(spine_count - 1)))
            ModelKit3D.add_capsule(_model_root, 0.12, 1.1 + float(index % 3) * 0.3, Vector3(x, body_radius * 1.8, 0.1), bone, Vector3(0.0, 0.0, -0.3 + float(index) * 0.08), "CrownSpine")
        if species == &"broodmass":
            ModelKit3D.add_membrane_fan(_model_root, 0.64, Vector3(0.0, 1.42, 0.38), membrane, 7, "BroodmassDorsalFan")
            for side in [-1.0, 1.0]:
                ModelKit3D.add_sphere(_model_root, 0.36, Vector3(side * 0.64, 1.3, 0.48), flesh, Vector3(1.1, 0.78, 1.2), "BroodmassLobe")
        else:
            ModelKit3D.add_membrane_fan(_model_root, 0.9, Vector3(0.0, 1.62, 0.24), membrane, 9, "ApexDorsalFan")
            ModelKit3D.add_sphere(_model_root, 0.5, Vector3(0.0, 2.15, -0.35), wet_chitin, Vector3(1.24, 0.72, 1.3), "ApexCrown")
            for side in [-1.0, 1.0]:
                ModelKit3D.add_capsule(_model_root, 0.1, 1.0, Vector3(side * 0.42, 1.08, -1.76), bone, Vector3(0.82, 0.0, side * 0.15), "ApexJaw")

    # Small asymmetric silhouette details help creatures read as animals rather
    # than mirrored game pieces from the tactical camera.
    ModelKit3D.add_capsule(_model_root, 0.05 * body_radius / 0.62, 0.9 * body_radius / 0.62, Vector3(-body_scale.x * 0.33, body_radius * 1.4, 0.42), bone, Vector3(0.38, 0.0, -0.34), "AsymmetricSpine")

    var eye_y := body_radius + 0.24
    var eye_z := head_offset - body_radius * 0.48
    ModelKit3D.add_sphere(_model_root, 0.09 * body_radius / 0.62, Vector3(-0.16, eye_y, eye_z), eye, Vector3.ONE, "EyeLeft")
    ModelKit3D.add_sphere(_model_root, 0.09 * body_radius / 0.62, Vector3(0.16, eye_y, eye_z), eye, Vector3.ONE, "EyeRight")
    ModelKit3D.add_capsule(_model_root, 0.06 * body_radius / 0.62, 0.72 * body_radius / 0.62, Vector3(-0.2, body_radius * 0.86, eye_z - 0.18), bone, Vector3(0.85, 0.0, -0.3), "MandibleLeft")
    ModelKit3D.add_capsule(_model_root, 0.06 * body_radius / 0.62, 0.72 * body_radius / 0.62, Vector3(0.2, body_radius * 0.86, eye_z - 0.18), bone, Vector3(0.85, 0.0, 0.3), "MandibleRight")
    ModelKit3D.add_glow_light(_model_root, Vector3(0.0, eye_y, eye_z + 0.05), Color("e43725"), 0.42 + body_radius * 0.28, 2.2 + body_radius * 1.7)


func _build_authored_veilstalker_visuals() -> void:
    # Keep the imported production scene intact under OrganicModel so its
    # authored animation hierarchy and renderer resources remain stable.
    # Species stats and ecology stay on this actor.
    var authored_scene_instance := _instantiate_authored_scene(AUTHORED_VEILSTALKER_MODEL_SCENE, "Veilstalker")
    if authored_scene_instance == null:
        return
    _attach_authored_scene_hierarchy(authored_scene_instance, _model_root, &"VeilstalkerAuthoredModel")
    # Keep the production shell's torso anchor stable for release material
    # continuity and secondary-animation lookup. The compact core sits inside
    # the imported thorax, adding depth without changing the authored outline.
    var torso := Node3D.new()
    torso.name = "Torso"
    _model_root.add_child(torso, true)
    var torso_material := ModelKit3D.material(Color("422934"), 0.08, 0.68)
    ModelKit3D.add_sphere(torso, 0.34, Vector3(0.0, 0.98, 0.1), torso_material, Vector3(1.55, 0.68, 1.2), "TorsoCore")


func _build_authored_razorhound_visuals() -> void:
    # Razorhound is a common early predator, so its authored shell carries
    # most of the hostile roster's day-to-day silhouette without changing the
    # ecology or combat contract.
    var authored_scene_instance := _instantiate_authored_scene(AUTHORED_RAZORHOUND_MODEL_SCENE, "Razorhound")
    if authored_scene_instance == null:
        return
    _attach_authored_scene_hierarchy(authored_scene_instance, _model_root, &"RazorhoundAuthoredModel")


func _build_authored_apex_visuals() -> void:
    # The Cistern Apex is the late-world landmark threat. Its authored shell
    # carries the crown, jaw, membrane and root signatures while this node
    # continues to own all gameplay state and collision.
    var authored_scene_instance := _instantiate_authored_scene(AUTHORED_APEX_MODEL_SCENE, "Apex")
    if authored_scene_instance == null:
        return
    _attach_authored_scene_hierarchy(authored_scene_instance, _model_root, &"ApexAuthoredModel")


func _build_authored_sporecaster_visuals() -> void:
    # The Sporecaster is a ranged infestation role. Keep its sac/gill language
    # in the authored shell while the enemy node retains targeting, ecology
    # and channel timing ownership.
    var authored_scene_instance := _instantiate_authored_scene(AUTHORED_SPORECASTER_MODEL_SCENE, "Sporecaster")
    if authored_scene_instance == null:
        return
    _attach_authored_scene_hierarchy(authored_scene_instance, _model_root, &"SporecasterAuthoredModel")


func _build_authored_broodmass_visuals() -> void:
    # Broodmass is a large nest organism. Its authored shell carries the
    # lobe, maw, spine, fin and hook signatures while gameplay stays here.
    var authored_scene_instance := _instantiate_authored_scene(AUTHORED_BROODMASS_MODEL_SCENE, "Broodmass")
    if authored_scene_instance == null:
        return
    _attach_authored_scene_hierarchy(authored_scene_instance, _model_root, &"BroodmassAuthoredModel")


func _build_authored_burrower_visuals() -> void:
    # Burrower's authored shell carries its drill and bore-lamp language while
    # patrol, collision and attack ownership remain on the enemy node.
    var authored_scene_instance := _instantiate_authored_scene(AUTHORED_BURROWER_MODEL_SCENE, "Burrower")
    if authored_scene_instance == null:
        return
    _attach_authored_scene_hierarchy(authored_scene_instance, _model_root, &"BurrowerAuthoredModel")


func _build_authored_skitterling_visuals() -> void:
    # Skitterling is the common scavenger. Its authored shell keeps the small
    # creature readable without changing its ecology or noise response.
    var authored_scene_instance := _instantiate_authored_scene(AUTHORED_SKITTERLING_MODEL_SCENE, "Skitterling")
    if authored_scene_instance == null:
        return
    var authored_shell_root := Node3D.new()
    authored_shell_root.name = "SkitterlingAuthoredShell"
    # The scavenger is physically small, but the earlier 0.28 shell scale made
    # its authored anatomy disappear beside common predators. Enlarge only the
    # presentation shell; collision, movement, ecology and attack range remain
    # owned by the actor and are unchanged.
    authored_shell_root.scale = Vector3.ONE * 0.58
    _model_root.add_child(authored_shell_root)
    _attach_authored_scene_hierarchy(authored_scene_instance, authored_shell_root, &"SkitterlingAuthoredModel")


func _build_authored_organic_family_visuals(model_path: String, imported_root_name: StringName, marker_name: StringName) -> void:
    # Tier-2 and tier-4 families keep their complete imported scene under
    # OrganicModel. The runtime actor still owns gameplay, while recursive
    # material/LOD passes can inspect the authored hierarchy without tearing
    # down generated roots or animation resources.
    var authored_scene_instance := _instantiate_authored_scene(model_path, String(imported_root_name))
    if authored_scene_instance == null:
        return
    _attach_authored_scene_hierarchy(authored_scene_instance, _model_root, marker_name)
    _add_authored_family_anatomy_finish()


func _attach_authored_scene_hierarchy(scene_instance: Node3D, target_root: Node3D, marker_name: StringName) -> void:
    if scene_instance == null or target_root == null:
        return
    # Preserve the imported glTF hierarchy and its generated AnimationPlayer.
    # Same-frame child reparent/free churn can invalidate renderer resources on
    # the compatibility renderer during repeated reduced-detail transitions.
    scene_instance.name = "ImportedAuthoredModel"
    target_root.add_child(scene_instance)
    var authored_marker := Node3D.new()
    authored_marker.name = String(marker_name)
    target_root.add_child(authored_marker)


func _add_authored_family_anatomy_finish() -> void:
    # Generic authored families share a small living focal so their imported
    # shells read as complete organisms rather than unlit static meshes. The
    # bounded vascular rim and asymmetrical growth nodes are presentation-only;
    # species stats, animation ownership, collision and ecology stay unchanged.
    var finish_root := Node3D.new()
    finish_root.name = "OrganicFamilyAnatomyFinish"
    _model_root.add_child(finish_root)

    var scale_factor := 1.0
    var accent_color := Color("c94d68")
    match species:
        &"roofleaper":
            scale_factor = 0.88
            accent_color = Color("de7c9a")
        &"glassmoth":
            scale_factor = 0.82
            accent_color = Color("8ee7d0")
        &"miremaw":
            scale_factor = 1.18
            accent_color = Color("df9b63")
        &"carrionbell":
            scale_factor = 1.05
            accent_color = Color("dd6e92")
        &"rootweaver":
            scale_factor = 1.28
            accent_color = Color("b85ce1")
        &"thornback":
            scale_factor = 1.12
            accent_color = Color("e3b45d")
        &"ashmantle":
            scale_factor = 1.2
            accent_color = Color("f07b4a")

    var tissue := ModelKit3D.material(Color("3d202b").lerp(accent_color.darkened(0.72), 0.28), 0.02, 0.72)
    var rim := ModelKit3D.material(accent_color.darkened(0.42), 0.04, 0.44, accent_color, 1.35)
    ModelKit3D.add_torus(
        finish_root,
        0.48 * scale_factor,
        0.036 * scale_factor,
        Vector3(0.0, 1.08 * scale_factor, 0.12),
        rim,
        Vector3(0.0, 0.0, 0.0),
        "OrganicPulseRim",
        32,
        6
    )
    ModelKit3D.add_organic_plate(
        finish_root,
        0.18 * scale_factor,
        Vector3(-0.1 * scale_factor, 1.34 * scale_factor, 0.22),
        tissue,
        rim,
        Vector3(1.1, 0.48, 1.25),
        "OrganicGrowthPlate",
        true
    )
    for side in [-1.0, 1.0]:
        var side_sign := float(side)
        ModelKit3D.add_capsule(
            finish_root,
            0.032 * scale_factor,
            0.48 * scale_factor,
            Vector3(side_sign * 0.28 * scale_factor, 1.02 * scale_factor, -0.1),
            tissue,
            Vector3(0.22, 0.0, side_sign * 0.3),
            "OrganicVascularVein%s" % ("L" if side_sign < 0.0 else "R")
        )
        ModelKit3D.add_sphere(
            finish_root,
            0.07 * scale_factor,
            Vector3(side_sign * 0.31 * scale_factor, 1.28 * scale_factor, -0.08),
            rim,
            Vector3(1.0, 0.78, 0.92),
            "OrganicVascularNode%s" % ("L" if side_sign < 0.0 else "R")
        )
