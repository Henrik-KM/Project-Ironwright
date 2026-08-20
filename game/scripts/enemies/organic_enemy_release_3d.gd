class_name OrganicEnemyRelease3D
extends OrganicEnemyFullGame3D

var _spatial_index: SpatialIndex3D
var reduced_detail: bool = false
var visual_lod_level: int = 0


func _ready() -> void:
    super._ready()
    call_deferred("_resolve_spatial_index")


func _resolve_spatial_index() -> void:
    _spatial_index = get_tree().get_first_node_in_group(&"spatial_index_service") as SpatialIndex3D


func _choose_target() -> Node3D:
    if _spatial_index == null or not is_instance_valid(_spatial_index):
        _resolve_spatial_index()
    if _spatial_index == null:
        return super._choose_target()

    var maximum_distance := detection_range + aggression * 11.0
    var best: Node3D
    var best_distance := maximum_distance

    if player_reference != null and is_instance_valid(player_reference) and player_reference.has_method(&"is_alive") and bool(player_reference.call(&"is_alive")):
        var player_distance := global_position.distance_to(player_reference.global_position)
        if player_distance < best_distance:
            best = player_reference
            best_distance = player_distance

    for robot in _spatial_index.query_radius(&"friendly_robots", global_position, maximum_distance):
        if robot.has_method(&"is_alive") and not bool(robot.call(&"is_alive")):
            continue
        var distance := global_position.distance_to(robot.global_position)
        if distance < best_distance:
            best = robot
            best_distance = distance

    for outpost in _spatial_index.query_radius(&"outposts", global_position, maximum_distance + 4.0):
        if outpost.has_method(&"is_alive") and not bool(outpost.call(&"is_alive")):
            continue
        var distance := global_position.distance_to(outpost.global_position)
        if distance < best_distance:
            best = outpost
            best_distance = distance

    if heartforge_reference != null and is_instance_valid(heartforge_reference) and aggression > 0.65:
        var forge_distance := global_position.distance_to(heartforge_reference.global_position)
        if forge_distance < best_distance:
            best = heartforge_reference
    return best


func set_reduced_detail(value: bool) -> void:
    if reduced_detail == value:
        return
    reduced_detail = value
    set_physics_process(not reduced_detail)
    if reduced_detail:
        velocity = Vector3.ZERO
        state_name = &"remote_simulation"


func reduced_detail_tick(delta: float) -> void:
    if not reduced_detail or not alive:
        return
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    investigate_seconds = maxf(0.0, investigate_seconds - delta)
    _target = _choose_target()
    var destination := investigate_position
    var speed := move_speed * 0.72
    if _target != null:
        destination = _target.global_position
        speed = move_speed * 0.82
        var distance := global_position.distance_to(destination)
        if distance <= attack_range:
            _attack_target(_target)
            return
    elif investigate_seconds <= 0.0:
        return
    var direction := destination - global_position
    direction.y = 0.0
    if direction.length_squared() <= 0.04:
        return
    direction = direction.normalized()
    global_position += direction * speed * delta
    rotation.y = atan2(direction.x, direction.z)


func set_visual_lod(level_value: int) -> void:
    visual_lod_level = clampi(level_value, 0, 2)
    if _model_root == null:
        return
    for child in _model_root.get_children():
        if child is GeometryInstance3D:
            (child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if visual_lod_level == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        if visual_lod_level >= 2 and child.name.contains("Spine") or child.name.contains("WingVein"):
            child.visible = false
        elif child is Node3D:
            child.visible = true


func _apply_species_stats() -> void:
    super._apply_species_stats()
    match species:
        &"roofleaper":
            maximum_health = 62.0
            move_speed = 6.35
            attack_damage = 13.0
            attack_range = 1.45
            detection_range = 21.0
            attack_interval = 0.92
        &"glassmoth":
            maximum_health = 46.0
            move_speed = 5.75
            attack_damage = 10.0
            attack_range = 5.4
            detection_range = 23.0
            attack_interval = 1.6
        &"miremaw":
            maximum_health = 225.0
            move_speed = 2.75
            attack_damage = 29.0
            attack_range = 2.15
            detection_range = 22.0
            attack_interval = 1.75
        &"carrionbell":
            maximum_health = 118.0
            move_speed = 3.25
            attack_damage = 9.0
            attack_range = 6.2
            detection_range = 28.0
            attack_interval = 2.0
        &"rootweaver":
            maximum_health = 265.0
            move_speed = 3.15
            attack_damage = 23.0
            attack_range = 6.7
            detection_range = 31.0
            attack_interval = 1.85
    current_health = maximum_health


func _refresh_visuals() -> void:
    super._refresh_visuals()
    if _model_root == null:
        return
    var chitin := ModelKit3D.material(Color("33252b"), 0.08, 0.72)
    var bone := ModelKit3D.material(Color("817762"), 0.0, 0.84)
    var membrane := ModelKit3D.material(Color("53172f"), 0.0, 0.78, Color("b52e59"), 1.3)
    var cold_membrane := ModelKit3D.material(Color("234046"), 0.0, 0.72, Color("6ce4dd"), 1.8)

    match species:
        &"roofleaper":
            for side in [-1.0, 1.0]:
                ModelKit3D.add_capsule(_model_root, 0.075, 1.8, Vector3(side * 0.78, 1.0, 0.15), bone, Vector3(0.0, 0.0, side * 1.08), "LeapLeg")
                ModelKit3D.add_box(_model_root, Vector3(0.08, 0.85, 1.15), Vector3(side * 0.7, 1.1, 0.25), membrane, Vector3(0.0, 0.0, side * 0.42), "GlideMembrane")
        &"glassmoth":
            for side in [-1.0, 1.0]:
                ModelKit3D.add_box(_model_root, Vector3(1.45, 0.05, 1.2), Vector3(side * 0.92, 1.0, 0.15), cold_membrane, Vector3(0.12, 0.08, side * 0.22), "Wing")
                for vein in range(3):
                    ModelKit3D.add_cylinder(_model_root, 0.025, 1.25, Vector3(side * (0.55 + vein * 0.27), 1.02, 0.15), bone, Vector3(0.0, 0.0, side * 0.95), "WingVein")
        &"miremaw":
            ModelKit3D.add_sphere(_model_root, 0.92, Vector3(0.0, 0.82, -0.25), chitin, Vector3(2.0, 0.85, 2.2), "MireCarapace")
            for side in [-1.0, 1.0]:
                ModelKit3D.add_capsule(_model_root, 0.15, 1.35, Vector3(side * 0.5, 0.45, -1.15), bone, Vector3(1.0, 0.0, side * 0.35), "MireJaw")
        &"carrionbell":
            ModelKit3D.add_sphere(_model_root, 0.72, Vector3(0.0, 1.65, 0.25), membrane, Vector3(1.15, 1.6, 1.15), "SignalBell")
            for index in range(5):
                var angle := TAU * float(index) / 5.0
                ModelKit3D.add_capsule(_model_root, 0.055, 1.0, Vector3(cos(angle) * 0.42, 2.2, sin(angle) * 0.42), bone, Vector3(0.0, 0.0, angle), "BellTendril")
        &"rootweaver":
            ModelKit3D.add_sphere(_model_root, 0.86, Vector3(0.0, 1.05, 0.0), chitin, Vector3(1.7, 1.35, 1.8), "RootCore")
            for index in range(8):
                var angle := TAU * float(index) / 8.0
                var direction := Vector3(cos(angle), 0.0, sin(angle))
                ModelKit3D.add_capsule(_model_root, 0.1, 2.0, direction * 1.05 + Vector3.UP * 0.42, bone, Vector3(0.0, -angle, 1.05), "RootArm")
