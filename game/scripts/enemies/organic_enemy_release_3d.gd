class_name OrganicEnemyRelease3D
extends OrganicEnemyFullGame3D

const REDUCED_PROXY_MESH: CapsuleMesh = preload("res://assets/release/proxies/organic_proxy_mesh.tres")

var _spatial_index: SpatialIndex3D
var reduced_detail: bool = false
var coarse_simulation: bool = false
var visual_lod_level: int = 0
var _reduced_proxy: MeshInstance3D


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
    coarse_simulation = false
    set_physics_process(not reduced_detail)
    var tier_brain := get_node_or_null("EnemyTierBrain")
    if tier_brain != null and tier_brain.has_method(&"set_simulation_lod"):
        tier_brain.call(&"set_simulation_lod", 2 if reduced_detail else 0)
    if reduced_detail:
        velocity = Vector3.ZERO
        state_name = &"remote_simulation"


func set_coarse_simulation(value: bool) -> void:
    if reduced_detail or coarse_simulation == value:
        return
    coarse_simulation = value
    set_physics_process(not coarse_simulation)
    var tier_brain := get_node_or_null("EnemyTierBrain")
    if tier_brain != null and tier_brain.has_method(&"set_simulation_lod"):
        tier_brain.call(&"set_simulation_lod", 1 if coarse_simulation else 0)


func reduced_detail_tick(delta: float) -> void:
    if not reduced_detail:
        return
    var tier_brain := get_node_or_null("EnemyTierBrain")
    if tier_brain != null and tier_brain.has_method(&"reduced_detail_tick"):
        tier_brain.call(&"reduced_detail_tick", delta)
        return
    _coarse_detail_tick(delta)


func coarse_detail_tick(delta: float) -> void:
    if not coarse_simulation:
        return
    var tier_brain := get_node_or_null("EnemyTierBrain")
    if tier_brain != null and tier_brain.has_method(&"coarse_detail_tick"):
        tier_brain.call(&"coarse_detail_tick", delta)
        return
    _coarse_detail_tick(delta)


func _coarse_detail_tick(delta: float) -> void:
    if not alive:
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
    set_damage_presentation_enabled(visual_lod_level == 0)
    if _model_root == null:
        if visual_lod_level == 0:
            ensure_authored_visuals()
        else:
            _ensure_reduced_proxy()
            _reduced_proxy.visible = true
            return
    if _model_root == null:
        return
    _ensure_reduced_proxy()
    for child in _model_root.get_children():
        if child == _reduced_proxy:
            _reduced_proxy.visible = visual_lod_level >= 1
            continue
        if child is Node3D:
            child.visible = visual_lod_level < 1
        if child is GeometryInstance3D:
            (child as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if visual_lod_level == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _ensure_reduced_proxy() -> void:
    if _reduced_proxy != null and is_instance_valid(_reduced_proxy):
        return
    _reduced_proxy = MeshInstance3D.new()
    _reduced_proxy.name = "ReducedDetailProxy"
    _reduced_proxy.mesh = REDUCED_PROXY_MESH
    _reduced_proxy.position = Vector3(0.0, 0.78, 0.0)
    _reduced_proxy.visible = false
    var proxy_parent := _model_root if _model_root != null else _ensure_deferred_proxy_root()
    proxy_parent.add_child(_reduced_proxy)


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
    current_health = maximum_health


func _refresh_visuals() -> void:
    super._refresh_visuals()
    if _model_root == null:
        return
    if species in [&"roofleaper", &"glassmoth", &"miremaw", &"carrionbell", &"rootweaver", &"thornback", &"ashmantle"]:
        return
    var chitin := ModelKit3D.material(Color("33252b"), 0.08, 0.72)
    var bone := ModelKit3D.material(Color("817762"), 0.0, 0.84)
    var membrane := ModelKit3D.material(Color("53172f"), 0.0, 0.78, Color("b52e59"), 1.3)
    var cold_membrane := ModelKit3D.material(Color("234046"), 0.0, 0.72, Color("6ce4dd"), 1.8)
    var wet_chitin := ModelKit3D.material(Color("241a25"), 0.2, 0.36)
    var tendon := ModelKit3D.material(Color("713c4a"), 0.0, 0.64)
    var eye := ModelKit3D.material(Color("4b0b0a"), 0.0, 0.42, Color("f04426"), 3.2)

    match species:
        &"roofleaper":
            ModelKit3D.add_organic_plate(_model_root, 0.34, Vector3(0.0, 1.34, -0.86), chitin, bone, Vector3(1.35, 0.55, 1.08), "RoofleaperCrown")
            for side in [-1.0, 1.0]:
                ModelKit3D.add_capsule(_model_root, 0.075, 1.8, Vector3(side * 0.78, 1.0, 0.15), bone, Vector3(0.0, 0.0, side * 1.08), "LeapLeg")
                ModelKit3D.add_box(_model_root, Vector3(0.08, 0.85, 1.15), Vector3(side * 0.7, 1.1, 0.25), membrane, Vector3(0.0, 0.0, side * 0.42), "GlideMembrane")
                for rib in range(3):
                    ModelKit3D.add_capsule(_model_root, 0.028, 0.78 - float(rib) * 0.08, Vector3(side * (0.46 + float(rib) * 0.2), 1.12, 0.28 + float(rib) * 0.18), bone, Vector3(0.0, 0.0, side * 0.82), "RoofleaperWingStrut%d" % rib)
                ModelKit3D.add_capsule(_model_root, 0.04, 0.72, Vector3(side * 0.3, 0.76, 1.32), tendon, Vector3(-0.35, 0.0, side * 0.16), "RoofleaperTailTendon")
            ModelKit3D.add_sphere(_model_root, 0.095, Vector3(0.0, 1.54, -1.12), eye, Vector3(1.0, 0.76, 0.86), "RoofleaperCrownOculus")
        &"glassmoth":
            for side in [-1.0, 1.0]:
                ModelKit3D.add_box(_model_root, Vector3(1.45, 0.05, 1.2), Vector3(side * 0.92, 1.0, 0.15), cold_membrane, Vector3(0.12, 0.08, side * 0.22), "Wing")
                for vein in range(3):
                    ModelKit3D.add_cylinder(_model_root, 0.025, 1.25, Vector3(side * (0.55 + vein * 0.27), 1.02, 0.15), bone, Vector3(0.0, 0.0, side * 0.95), "WingVein")
                    ModelKit3D.add_capsule(_model_root, 0.022, 0.62, Vector3(side * (0.6 + float(vein) * 0.25), 1.09, 0.38), cold_membrane, Vector3(0.0, 0.0, side * 0.72), "GlassmothWingRib%d" % vein)
            ModelKit3D.add_ribbed_shell(_model_root, 0.34, Vector3(0.0, 1.0, -0.12), chitin, bone, Vector3(1.18, 0.9, 1.28), "GlassmothThorax")
            for side in [-1.0, 1.0]:
                ModelKit3D.add_capsule(_model_root, 0.025, 0.72, Vector3(side * 0.16, 1.34, -0.72), bone, Vector3(0.42, 0.0, side * 0.2), "GlassmothAntenna")
            ModelKit3D.add_sphere(_model_root, 0.1, Vector3(0.0, 1.3, -0.92), cold_membrane, Vector3(1.0, 0.72, 0.82), "GlassmothOculus")
        &"miremaw":
            ModelKit3D.add_sphere(_model_root, 0.92, Vector3(0.0, 0.82, -0.25), chitin, Vector3(2.0, 0.85, 2.2), "MireCarapace")
            ModelKit3D.add_ribbed_shell(_model_root, 0.64, Vector3(0.0, 1.12, 0.22), wet_chitin, bone, Vector3(1.58, 0.72, 1.72), "MiremawDorsalShell")
            for index in range(4):
                var shell_z := -0.62 + float(index) * 0.42
                ModelKit3D.add_organic_plate(_model_root, 0.25 - float(index) * 0.02, Vector3(-0.18 + float(index % 2) * 0.12, 1.38 - float(index) * 0.04, shell_z), chitin, bone, Vector3(1.32, 0.42, 0.72), "MiremawDorsalPlate%d" % index)
            for side in [-1.0, 1.0]:
                ModelKit3D.add_capsule(_model_root, 0.15, 1.35, Vector3(side * 0.5, 0.45, -1.15), bone, Vector3(1.0, 0.0, side * 0.35), "MireJaw")
                ModelKit3D.add_capsule(_model_root, 0.065, 0.62, Vector3(side * 0.72, 0.56, -1.55), bone, Vector3(0.82, 0.0, side * 0.18), "MiremawTusk")
            ModelKit3D.add_membrane_fan(_model_root, 0.32, Vector3(0.0, 0.82, 0.64), membrane, 5, "MiremawGillFan")
        &"carrionbell":
            ModelKit3D.add_sphere(_model_root, 0.72, Vector3(0.0, 1.65, 0.25), membrane, Vector3(1.15, 1.6, 1.15), "SignalBell")
            ModelKit3D.add_ribbed_shell(_model_root, 0.48, Vector3(0.0, 1.2, 0.18), chitin, bone, Vector3(1.28, 0.9, 1.32), "CarrionbellMantle")
            for index in range(5):
                var angle := TAU * float(index) / 5.0
                ModelKit3D.add_capsule(_model_root, 0.055, 1.0, Vector3(cos(angle) * 0.42, 2.2, sin(angle) * 0.42), bone, Vector3(0.0, 0.0, angle), "BellTendril")
                ModelKit3D.add_capsule(_model_root, 0.028, 0.64, Vector3(cos(angle) * 0.7, 1.54, sin(angle) * 0.7), tendon, Vector3(0.35, 0.0, angle + 0.42), "CarrionbellSignalTendril%d" % index)
            ModelKit3D.add_organic_plate(_model_root, 0.3, Vector3(0.0, 2.32, 0.24), membrane, bone, Vector3(1.25, 0.32, 1.18), "CarrionbellCrownPlate")
            ModelKit3D.add_sphere(_model_root, 0.1, Vector3(0.0, 2.48, 0.2), eye, Vector3(1.0, 0.72, 0.82), "CarrionbellResonator")
        &"rootweaver":
            ModelKit3D.add_sphere(_model_root, 0.86, Vector3(0.0, 1.05, 0.0), chitin, Vector3(1.7, 1.35, 1.8), "RootCore")
            ModelKit3D.add_ribbed_shell(_model_root, 0.58, Vector3(0.0, 1.52, 0.08), wet_chitin, bone, Vector3(1.42, 0.86, 1.46), "RootweaverCrown")
            for index in range(8):
                var angle := TAU * float(index) / 8.0
                var direction := Vector3(cos(angle), 0.0, sin(angle))
                ModelKit3D.add_capsule(_model_root, 0.1, 2.0, direction * 1.05 + Vector3.UP * 0.42, bone, Vector3(0.0, -angle, 1.05), "RootArm")
                ModelKit3D.add_capsule(_model_root, 0.042, 1.18, direction * 0.74 + Vector3.UP * (1.12 + float(index % 2) * 0.12), tendon, Vector3(0.0, -angle + 0.34, 1.0), "RootweaverTendril%d" % index)
            ModelKit3D.add_membrane_fan(_model_root, 0.42, Vector3(0.0, 1.98, 0.18), membrane, 6, "RootweaverSporeFan")
            ModelKit3D.add_sphere(_model_root, 0.11, Vector3(-0.18, 1.82, -0.6), eye, Vector3(1.0, 0.78, 0.82), "RootweaverOculus")
