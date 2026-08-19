class_name OrganicEnemy3D
extends CharacterBody3D

signal killed(enemy: OrganicEnemy3D, killer: Node)
signal attack_landed(enemy: OrganicEnemy3D, target: Node)

var species: StringName = &"skitterling"
var maximum_health: float = 30.0
var current_health: float = 30.0
var move_speed: float = 4.2
var attack_damage: float = 9.0
var attack_range: float = 1.35
var attack_interval: float = 1.25
var detection_range: float = 14.0
var attack_cooldown: float = 0.0
var state_name: StringName = &"lurking"
var investigate_position: Vector3
var investigate_seconds: float = 0.0
var aggression: float = 0.2
var player_reference: Node3D
var heartforge_reference: Node3D
var alive: bool = true
var _target: Node3D
var _model_root: Node3D


func _ready() -> void:
    add_to_group("organic_enemies")
    collision_layer = 4
    collision_mask = 1 | 2 | 4
    _apply_species_stats()
    _build_visuals()


func configure(next_species: StringName, player: Node3D, heartforge: Node3D) -> void:
    species = next_species
    player_reference = player
    heartforge_reference = heartforge
    _apply_species_stats()
    if is_inside_tree():
        _refresh_visuals()


func hear_noise(position: Vector3, radius: float, intensity: float, source_kind: StringName) -> void:
    if not alive:
        return
    var distance_to_noise := global_position.distance_to(position)
    if distance_to_noise > radius:
        return
    investigate_position = position
    investigate_seconds = maxf(investigate_seconds, 5.0 + intensity * 3.0)
    aggression = clampf(aggression + intensity * 0.22, 0.0, 1.0)
    state_name = &"investigating"


func _physics_process(delta: float) -> void:
    if not alive:
        return
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    investigate_seconds = maxf(0.0, investigate_seconds - delta)
    _target = _choose_target()

    if _target != null:
        var target_distance := global_position.distance_to(_target.global_position)
        if target_distance <= attack_range:
            _attack_target(_target)
            _slow_to_stop(delta)
        else:
            state_name = &"hunting"
            _move_toward(_target.global_position, move_speed, delta)
    elif investigate_seconds > 0.0:
        state_name = &"investigating"
        _move_toward(investigate_position, move_speed * 0.78, delta)
    else:
        state_name = &"lurking"
        _slow_to_stop(delta)


func _choose_target() -> Node3D:
    var best: Node3D
    var best_distance := detection_range + aggression * 11.0

    if player_reference != null and is_instance_valid(player_reference) and player_reference.has_method("is_alive") and bool(player_reference.call("is_alive")):
        var player_distance := global_position.distance_to(player_reference.global_position)
        if player_distance < best_distance:
            best = player_reference
            best_distance = player_distance

    for robot in get_tree().get_nodes_in_group("friendly_robots"):
        if not is_instance_valid(robot) or not (robot is Node3D):
            continue
        if robot.has_method("is_alive") and not bool(robot.call("is_alive")):
            continue
        var robot_distance := global_position.distance_to(robot.global_position)
        if robot_distance < best_distance:
            best = robot
            best_distance = robot_distance

    if heartforge_reference != null and is_instance_valid(heartforge_reference) and aggression > 0.65:
        var forge_distance := global_position.distance_to(heartforge_reference.global_position)
        if forge_distance < best_distance:
            best = heartforge_reference

    return best


func _move_toward(target_position: Vector3, speed: float, delta: float) -> void:
    var direction := target_position - global_position
    direction.y = 0.0
    if direction.length_squared() < 0.04:
        _slow_to_stop(delta)
        return
    direction = direction.normalized()
    velocity.x = move_toward(velocity.x, direction.x * speed, 14.0 * delta)
    velocity.z = move_toward(velocity.z, direction.z * speed, 14.0 * delta)
    velocity.y = -0.9
    rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 0.22)
    move_and_slide()


func _slow_to_stop(delta: float) -> void:
    velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
    velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
    velocity.y = -0.9
    move_and_slide()


func _attack_target(target: Node) -> void:
    state_name = &"attacking"
    if attack_cooldown > 0.0:
        return
    attack_cooldown = attack_interval
    if target.has_method("apply_damage"):
        target.call("apply_damage", attack_damage, self)
    attack_landed.emit(self, target)


func apply_damage(amount: float, source: Node = null) -> void:
    if not alive or amount <= 0.0:
        return
    current_health = maxf(0.0, current_health - amount)
    aggression = 1.0
    if source is Node3D:
        investigate_position = source.global_position
        investigate_seconds = 10.0
    if current_health > 0.0:
        return
    alive = false
    state_name = &"dead"
    killed.emit(self, source)
    queue_free()


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
        _:
            maximum_health = 28.0
            move_speed = 4.4
            attack_damage = 9.0
            detection_range = 13.0
            attack_interval = 1.2
    current_health = maximum_health


func _build_visuals() -> void:
    var collision_radius := 0.5
    var collision_height := 0.9
    if species == &"broodmass":
        collision_radius = 0.85
        collision_height = 1.4
    elif species == &"apex":
        collision_radius = 1.15
        collision_height = 2.0
    ModelKit3D.add_collision_capsule(self, collision_radius, collision_height, Vector3(0.0, collision_height * 0.5, 0.0))
    _model_root = Node3D.new()
    _model_root.name = "OrganicModel"
    add_child(_model_root)
    _refresh_visuals()


func _refresh_visuals() -> void:
    if _model_root == null:
        return
    for child in _model_root.get_children():
        child.queue_free()
    var flesh := ModelKit3D.material(Color("21191a"), 0.0, 0.94)
    var chitin := ModelKit3D.material(Color("35272a"), 0.08, 0.75)
    var bone := ModelKit3D.material(Color("766d5c"), 0.0, 0.85)
    var membrane := ModelKit3D.material(Color("421727"), 0.0, 0.83, Color("9f2947"), 0.9)
    var eye := ModelKit3D.material(Color("5a120e"), 0.0, 0.48, Color("f33a20"), 3.6)

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

    ModelKit3D.add_sphere(_model_root, body_radius, Vector3(0.0, body_radius + 0.16, 0.0), flesh, body_scale, "Torso")
    ModelKit3D.add_sphere(_model_root, body_radius * 0.62, Vector3(0.0, body_radius + 0.12, head_offset), chitin, Vector3(1.1, 0.8, 1.25), "Head")

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

    if species == &"sporecaster":
        for index in range(5):
            var angle := TAU * float(index) / 5.0
            ModelKit3D.add_sphere(_model_root, 0.34, Vector3(cos(angle) * 0.55, 1.55, sin(angle) * 0.45), membrane, Vector3(0.8, 1.35, 0.8), "SporeSac")
    elif species == &"burrower":
        for index in range(5):
            ModelKit3D.add_capsule(_model_root, 0.1, 0.8, Vector3(-0.8 + float(index) * 0.4, 0.9, 0.1), bone, Vector3(0.0, 0.0, -0.35 + float(index) * 0.16), "BurrowSpine")
    elif species in [&"broodmass", &"apex"]:
        var spine_count := 6 if species == &"broodmass" else 9
        for index in range(spine_count):
            var x := -1.2 + float(index) * (2.4 / maxf(1.0, float(spine_count - 1)))
            ModelKit3D.add_capsule(_model_root, 0.12, 1.1 + float(index % 3) * 0.3, Vector3(x, body_radius * 1.8, 0.1), bone, Vector3(0.0, 0.0, -0.3 + float(index) * 0.08), "CrownSpine")

    var eye_y := body_radius + 0.24
    var eye_z := head_offset - body_radius * 0.48
    ModelKit3D.add_sphere(_model_root, 0.09 * body_radius / 0.62, Vector3(-0.16, eye_y, eye_z), eye, Vector3.ONE, "EyeLeft")
    ModelKit3D.add_sphere(_model_root, 0.09 * body_radius / 0.62, Vector3(0.16, eye_y, eye_z), eye, Vector3.ONE, "EyeRight")
    ModelKit3D.add_capsule(_model_root, 0.06 * body_radius / 0.62, 0.72 * body_radius / 0.62, Vector3(-0.2, body_radius * 0.86, eye_z - 0.18), bone, Vector3(0.85, 0.0, -0.3), "MandibleLeft")
    ModelKit3D.add_capsule(_model_root, 0.06 * body_radius / 0.62, 0.72 * body_radius / 0.62, Vector3(0.2, body_radius * 0.86, eye_z - 0.18), bone, Vector3(0.85, 0.0, 0.3), "MandibleRight")
    ModelKit3D.add_glow_light(_model_root, Vector3(0.0, eye_y, eye_z + 0.05), Color("e43725"), 0.55 + body_radius * 0.35, 2.8 + body_radius * 2.2)
