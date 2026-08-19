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
        _:
            maximum_health = 28.0
            move_speed = 4.4
            attack_damage = 9.0
            detection_range = 13.0
            attack_interval = 1.2
    current_health = maximum_health


func _build_visuals() -> void:
    ModelKit3D.add_collision_capsule(self, 0.5, 0.9, Vector3(0.0, 0.5, 0.0))
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
    var eye := ModelKit3D.material(Color("5a120e"), 0.0, 0.48, Color("f33a20"), 3.6)

    var body_scale := Vector3(1.35, 0.7, 1.7)
    if species == &"veilstalker":
        body_scale = Vector3(1.6, 1.15, 2.0)
    ModelKit3D.add_sphere(_model_root, 0.62, Vector3(0.0, 0.75, 0.0), flesh, body_scale, "Torso")
    ModelKit3D.add_sphere(_model_root, 0.38, Vector3(0.0, 0.72, -1.0), chitin, Vector3(1.1, 0.8, 1.25), "Head")

    var leg_pairs := 3 if species != &"veilstalker" else 4
    for index in range(leg_pairs):
        var z_position := -0.55 + float(index) * 0.58
        for side in [-1.0, 1.0]:
            ModelKit3D.add_capsule(_model_root, 0.09, 1.35, Vector3(side * 0.72, 0.38, z_position), chitin, Vector3(0.0, 0.0, side * 0.92), "Leg")
            ModelKit3D.add_capsule(_model_root, 0.07, 0.86, Vector3(side * 1.22, 0.13, z_position + 0.08), bone, Vector3(0.0, 0.0, side * 0.45), "Talon")

    ModelKit3D.add_sphere(_model_root, 0.09, Vector3(-0.16, 0.84, -1.32), eye, Vector3.ONE, "EyeLeft")
    ModelKit3D.add_sphere(_model_root, 0.09, Vector3(0.16, 0.84, -1.32), eye, Vector3.ONE, "EyeRight")
    ModelKit3D.add_capsule(_model_root, 0.06, 0.72, Vector3(-0.2, 0.55, -1.45), bone, Vector3(0.85, 0.0, -0.3), "MandibleLeft")
    ModelKit3D.add_capsule(_model_root, 0.06, 0.72, Vector3(0.2, 0.55, -1.45), bone, Vector3(0.85, 0.0, 0.3), "MandibleRight")
    ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 0.85, -1.28), Color("e43725"), 0.55, 2.8)
