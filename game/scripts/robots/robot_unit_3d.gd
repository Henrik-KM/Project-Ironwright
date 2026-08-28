class_name RobotUnit3D
extends CharacterBody3D

const AUTHORED_BULWARK_MODEL_SCENE := "res://assets/bulwark/bulwark.gltf"
const AUTHORED_WARDEN_MODEL_SCENE := "res://assets/warden/warden.gltf"
const AUTHORED_SCRAPPER_MODEL_SCENE := "res://assets/scrapper/scrapper.gltf"
const AUTHORED_PATHFINDER_MODEL_SCENE := "res://assets/pathfinder/pathfinder.gltf"
const AUTHORED_ENGINEER_MODEL_SCENE := "res://assets/engineer/engineer.gltf"
const AUTHORED_RELAY_MODEL_SCENE := "res://assets/relay/relay.gltf"
const DISABLED_PRESENTATION_SECONDS := 0.86

const CALLSIGN_PREFIXES: Dictionary = {
    &"companion": "Bulwark",
    &"guardian": "Ward",
    &"salvager": "Mender",
    &"scout": "Lantern",
    &"engineer": "Forgehand",
    &"relay": "Chorus",
}

signal destroyed(robot: RobotUnit3D)
signal health_changed(robot: RobotUnit3D, current: float, maximum: float)
signal weapon_fired(origin: Vector3, target: Vector3, target_node: Node)
signal salvage_completed(robot: RobotUnit3D, pile: Node, amount: int)

var archetype: StringName = &"salvager"
var level: int = 1
var callsign: String = ""
var callsign_serial: int = 1
var maximum_health: float = 90.0
var current_health: float = 90.0
var move_speed: float = 4.4
var attack_damage: float = 4.0
var attack_range: float = 6.0
var attack_interval: float = 1.1
var attack_cooldown: float = 0.0
var salvage_rate: float = 1.0
var construction_rate: float = 1.0
var signal_strength: float = 1.0
var state_name: StringName = &"idle"
var decision_reason: String = "Awaiting a macro-level machine focus."
var goal_position: Vector3
var has_goal: bool = false
var speed_cap: float = 999.0
var hold_position: bool = false
var assigned_group: StringName = &""
var formation_index: int = 0
var current_target: Node3D
var salvage_target: Node
var salvage_progress: float = 0.0
var salvage_duration: float = 5.4
var player_reference: Node3D
var heartforge_reference: Node3D
var progression: ProgressionDirector3D
var alive: bool = true
var disabled_presentation_remaining: float = 0.0
var obstacle_recovery_remaining: float = 0.0
var obstacle_recovery_direction: Vector3 = Vector3.ZERO

var _model_root: Node3D
var _sensor_light: OmniLight3D
var _damage_visual_root: Node3D
var _damage_signal_material: StandardMaterial3D
var _disabled_visual_root: Node3D
var _disabled_signal_material: StandardMaterial3D
var _damage_presentation_enabled: bool = true
var defer_authored_visuals: bool = false
var _deferred_proxy_root: Node3D


func _ready() -> void:
    add_to_group("friendly_robots")
    collision_layer = 2
    collision_mask = 1 | 2 | 4
    if callsign.is_empty():
        assign_callsign(callsign_serial)
    _apply_level_stats()
    if defer_authored_visuals:
        _build_collision()
        _ensure_deferred_proxy_root()
    else:
        _build_visuals()


func configure(next_archetype: StringName, next_level: int) -> void:
    archetype = next_archetype
    level = clampi(next_level, 1, 3)
    if callsign.is_empty():
        assign_callsign(1)
    _apply_level_stats()
    if is_inside_tree():
        _refresh_visual_identity()
        _build_disabled_presentation()


func assign_callsign(serial: int = 1) -> void:
    callsign_serial = maxi(1, serial)
    var prefix := str(CALLSIGN_PREFIXES.get(archetype, String(archetype).capitalize()))
    callsign = prefix if callsign_serial == 1 else "%s-%02d" % [prefix, callsign_serial]


func restore_callsign(saved_callsign: Variant) -> void:
    var restored := str(saved_callsign).strip_edges()
    if restored.is_empty():
        assign_callsign(callsign_serial)
        return
    callsign = restored


func display_identity() -> String:
    return callsign if not callsign.is_empty() else String(archetype).capitalize()


func set_progression(next_progression: ProgressionDirector3D) -> void:
    var health_ratio := current_health / maxf(1.0, maximum_health)
    progression = next_progression
    _apply_level_stats()
    current_health = maximum_health * health_ratio
    _refresh_damage_presentation()
    health_changed.emit(self, current_health, maximum_health)


func _physics_process(delta: float) -> void:
    if not alive:
        disabled_presentation_remaining = maxf(0.0, disabled_presentation_remaining - delta)
        _refresh_disabled_presentation()
        if disabled_presentation_remaining <= 0.0:
            queue_free()
        return
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    if archetype == &"companion" and player_reference != null and is_instance_valid(player_reference):
        _update_companion_goal()

    if salvage_target != null and is_instance_valid(salvage_target):
        _update_robot_salvage(delta)
    else:
        salvage_target = null
        salvage_progress = 0.0

    _update_attack()
    _update_motion(delta)


func _update_companion_goal() -> void:
    var to_player := player_reference.global_position - global_position
    if to_player.length() > 4.0 and current_target == null:
        set_goal(player_reference.global_position + Vector3(1.6, 0.0, 1.4), "Staying close because the Mechromancer cannot survive sustained contact alone.", move_speed)
    elif to_player.length() < 2.1 and current_target == null:
        clear_goal("Holding beside the Mechromancer and intercepting nearby threats.")


func _update_attack() -> void:
    current_target = _nearest_enemy(attack_range)
    if current_target == null or attack_cooldown > 0.0:
        return
    attack_cooldown = attack_interval
    state_name = &"engaging"
    decision_reason = "Intercepting the closest organic threat inside the assigned protection envelope."
    var origin := global_position + Vector3.UP * 0.9
    var impact := current_target.global_position + Vector3.UP * 0.45
    if current_target.has_method("apply_damage"):
        current_target.call("apply_damage", attack_damage, self)
    weapon_fired.emit(origin, impact, current_target)


func _update_motion(delta: float) -> void:
    obstacle_recovery_remaining = maxf(0.0, obstacle_recovery_remaining - delta)
    if hold_position or not has_goal or current_target != null and archetype != &"scout":
        velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
        velocity.y = -0.8
        move_and_slide()
        return

    var direction := goal_position - global_position
    direction.y = 0.0
    if direction.length() <= 0.45:
        velocity.x = move_toward(velocity.x, 0.0, 24.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 24.0 * delta)
        velocity.y = -0.8
        move_and_slide()
        return

    direction = direction.normalized()
    var steering_direction := direction
    if obstacle_recovery_remaining > 0.0 and obstacle_recovery_direction.length_squared() > 0.01:
        steering_direction = (direction + obstacle_recovery_direction * 0.9).normalized()
    var desired_speed := minf(move_speed, speed_cap)
    velocity.x = move_toward(velocity.x, steering_direction.x * desired_speed, 18.0 * delta)
    velocity.z = move_toward(velocity.z, steering_direction.z * desired_speed, 18.0 * delta)
    velocity.y = -0.8
    rotation.y = lerp_angle(rotation.y, atan2(steering_direction.x, steering_direction.z), 0.2)
    var position_before := global_position
    move_and_slide()
    _register_blocked_route(position_before, direction, desired_speed, delta)


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
    decision_reason = "Taking a short recovery arc around a blocked route while preserving the assigned formation goal."


func _update_robot_salvage(delta: float) -> void:
    if global_position.distance_to(salvage_target.global_position) > 2.2:
        return
    salvage_progress += delta * salvage_rate
    state_name = &"salvaging"
    decision_reason = "Dismantling the assigned wreck while the group maintains cohesion and protection."
    if salvage_progress < salvage_duration:
        return
    salvage_progress = 0.0
    var amount := 0
    if salvage_target.has_method("extract_for_robot"):
        amount = int(salvage_target.call("extract_for_robot", 18 + level * 5))
    salvage_completed.emit(self, salvage_target, amount)
    salvage_target = null


func set_goal(position: Vector3, reason: String, maximum_speed: float = 999.0) -> void:
    goal_position = position
    has_goal = true
    hold_position = false
    speed_cap = maximum_speed
    if state_name != &"engaging" and state_name != &"salvaging":
        state_name = &"moving"
    decision_reason = reason


func clear_goal(reason: String = "Holding position.") -> void:
    has_goal = false
    hold_position = true
    speed_cap = 0.0
    if current_target == null:
        state_name = &"holding"
    decision_reason = reason


func begin_robot_salvage(pile: Node) -> void:
    salvage_target = pile
    salvage_progress = 0.0


func set_group(group_id: StringName, index: int) -> void:
    assigned_group = group_id
    formation_index = index


func apply_damage(amount: float, source: Node = null) -> void:
    if not alive or amount <= 0.0:
        return
    current_health = maxf(0.0, current_health - amount)
    _refresh_damage_presentation()
    health_changed.emit(self, current_health, maximum_health)
    if current_health <= 0.0:
        alive = false
        state_name = &"disabled"
        decision_reason = "Disabled at this physical location; recovery requires the surviving machines."
        disabled_presentation_remaining = DISABLED_PRESENTATION_SECONDS
        _refresh_disabled_presentation()
        destroyed.emit(self)


func repair(amount: float) -> void:
    if not alive:
        return
    current_health = minf(maximum_health, current_health + maxf(0.0, amount))
    _refresh_damage_presentation()
    health_changed.emit(self, current_health, maximum_health)


func is_alive() -> bool:
    return alive and current_health > 0.0


func _nearest_enemy(maximum_range: float) -> Node3D:
    var best: Node3D
    var best_distance := maximum_range
    for candidate in get_tree().get_nodes_in_group("organic_enemies"):
        if not is_instance_valid(candidate) or not (candidate is Node3D):
            continue
        if candidate.has_method("is_alive") and not bool(candidate.call("is_alive")):
            continue
        var current_distance := global_position.distance_to(candidate.global_position)
        if current_distance < best_distance:
            best = candidate
            best_distance = current_distance
    for candidate in get_tree().get_nodes_in_group(&"enemy_tier_nests"):
        if not is_instance_valid(candidate) or not (candidate is Node3D):
            continue
        if candidate.has_method(&"is_alive") and not bool(candidate.call(&"is_alive")):
            continue
        var nest_distance := global_position.distance_to(candidate.global_position)
        if nest_distance < best_distance:
            best = candidate
            best_distance = nest_distance
    return best


func _apply_level_stats() -> void:
    construction_rate = 1.0
    salvage_rate = 1.0
    signal_strength = 1.0
    match archetype:
        &"companion":
            maximum_health = [180.0, 245.0, 335.0][level - 1]
            attack_damage = [13.0, 18.0, 25.0][level - 1]
            move_speed = [5.2, 5.5, 5.8][level - 1]
            attack_range = 7.2
            attack_interval = 0.82
        &"guardian":
            maximum_health = [155.0, 215.0, 295.0][level - 1]
            attack_damage = [10.0, 15.0, 21.0][level - 1]
            move_speed = [4.2, 4.4, 4.7][level - 1]
            attack_range = 7.5
            attack_interval = 0.9
        &"scout":
            maximum_health = [80.0, 105.0, 140.0][level - 1]
            attack_damage = [5.0, 7.0, 10.0][level - 1]
            move_speed = [6.2, 6.8, 7.5][level - 1]
            attack_range = 6.5
            attack_interval = 1.0
        &"engineer":
            maximum_health = [110.0, 150.0, 205.0][level - 1]
            attack_damage = [5.0, 8.0, 12.0][level - 1]
            move_speed = [4.25, 4.55, 4.9][level - 1]
            construction_rate = [1.0, 1.35, 1.8][level - 1]
            attack_range = 5.6
            attack_interval = 1.18
        &"relay":
            maximum_health = [92.0, 126.0, 172.0][level - 1]
            attack_damage = [4.0, 6.0, 9.0][level - 1]
            move_speed = [4.6, 4.9, 5.2][level - 1]
            signal_strength = [1.0, 1.35, 1.8][level - 1]
            attack_range = 5.8
            attack_interval = 1.15
        _:
            maximum_health = [95.0, 125.0, 165.0][level - 1]
            attack_damage = [4.0, 6.0, 9.0][level - 1]
            move_speed = [4.4, 4.7, 5.0][level - 1]
            salvage_rate = [1.0, 1.35, 1.8][level - 1]
            attack_range = 5.0
            attack_interval = 1.25
    if progression != null:
        maximum_health *= 1.0 + progression.modifier_value(&"robot_health_multiplier")
        move_speed *= 1.0 + progression.modifier_value(&"robot_speed_multiplier")
        attack_damage *= 1.0 + progression.modifier_value(&"robot_damage_multiplier")
        salvage_rate *= 1.0 + progression.modifier_value(&"robot_salvage_multiplier")
        construction_rate *= 1.0 + progression.modifier_value(&"robot_construction_multiplier")
        signal_strength *= 1.0 + progression.modifier_value(&"robot_signal_multiplier")
    current_health = maximum_health


func _build_collision() -> void:
    if get_node_or_null("CollisionShape3D") == null:
        ModelKit3D.add_collision_capsule(self, 0.48, 1.0, Vector3(0.0, 0.52, 0.0))


func _build_visuals() -> void:
    _build_collision()
    _model_root = Node3D.new()
    _model_root.name = "RobotModel"
    add_child(_model_root)
    _refresh_visual_identity()
    _build_damage_presentation()
    _build_disabled_presentation()


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
        push_error("Robot authored scene could not be loaded for %s: %s" % [label, path])
        return null
    var instance := (resource as PackedScene).instantiate() as Node3D
    if instance == null:
        push_error("Robot authored scene could not be instantiated for %s: %s" % [label, path])
    return instance


func set_damage_presentation_enabled(value: bool) -> void:
    _damage_presentation_enabled = value
    _refresh_damage_presentation()


func _build_disabled_presentation() -> void:
    if _disabled_visual_root != null and is_instance_valid(_disabled_visual_root):
        _disabled_visual_root.free()
    _disabled_visual_root = Node3D.new()
    _disabled_visual_root.name = "RobotDisabledPresentation"
    add_child(_disabled_visual_root)

    var body_scale := 1.0
    var signal_color := Color("e07a43")
    match archetype:
        &"companion":
            body_scale = 1.08
            signal_color = Color("e08c4d")
        &"guardian":
            body_scale = 1.18
            signal_color = Color("dc6541")
        &"salvager":
            body_scale = 1.0
            signal_color = Color("d17a43")
        &"scout":
            body_scale = 0.9
            signal_color = Color("59c4c7")
        &"engineer":
            body_scale = 1.04
            signal_color = Color("e0a052")
        &"relay":
            body_scale = 1.22
            signal_color = Color("6ed6da")

    var dead_steel := ModelKit3D.material(Color("252c2d"), 0.72, 0.62)
    var dead_edge := ModelKit3D.material(Color("60402f"), 0.34, 0.78)
    var dead_core := ModelKit3D.material(signal_color.darkened(0.58), 0.16, 0.44, signal_color, 1.4)
    var cable := ModelKit3D.material(Color("4d2528"), 0.28, 0.68, Color("c94d43"), 0.48)
    var shard := ModelKit3D.material(Color("745044"), 0.28, 0.72)

    ModelKit3D.add_beveled_box(
        _disabled_visual_root,
        Vector3(0.82, 0.14, 0.56) * body_scale,
        Vector3(0.0, 0.72, -0.04),
        dead_steel,
        Vector3(0.0, 0.0, -0.12),
        "RobotDisabledCarapace",
        0.08
    )
    ModelKit3D.add_organic_plate(
        _disabled_visual_root,
        0.12 * body_scale,
        Vector3(0.0, 0.91, -0.32),
        dead_edge,
        shard,
        Vector3(0.52, 0.18, 0.22) * body_scale,
        "RobotDisabledRootCollar"
    )
    for side in [-1.0, 1.0]:
        ModelKit3D.add_capsule(
            _disabled_visual_root,
            0.045 * body_scale,
            0.62 * body_scale,
            Vector3(side * 0.34, 0.82, 0.18),
            cable,
            Vector3(0.12, 0.0, side * 0.48),
            "RobotDisabledCable%s" % ("Left" if side < 0.0 else "Right")
        )
    for index in range(3):
        var angle := -0.55 + float(index) * 0.55
        ModelKit3D.add_beveled_box(
            _disabled_visual_root,
            Vector3(0.12, 0.08, 0.28) * body_scale,
            Vector3(sin(angle) * 0.48, 0.78 + float(index % 2) * 0.08, -0.18 + cos(angle) * 0.06),
            shard,
            Vector3(0.0, angle, -0.24),
            "RobotDisabledShard%02d" % index,
            0.035
        )
    ModelKit3D.add_sphere(
        _disabled_visual_root,
        0.11 * body_scale,
        Vector3(0.0, 0.94, -0.4),
        dead_core,
        Vector3(1.15, 0.72, 0.72),
        "RobotDisabledSignal"
    )
    _disabled_signal_material = dead_core
    _refresh_disabled_presentation()


func _refresh_disabled_presentation() -> void:
    if _disabled_visual_root == null or not is_instance_valid(_disabled_visual_root):
        return
    var active := not alive and disabled_presentation_remaining > 0.0
    _disabled_visual_root.visible = active
    if not active:
        return
    var progress := clampf(disabled_presentation_remaining / DISABLED_PRESENTATION_SECONDS, 0.0, 1.0)
    _disabled_visual_root.scale = Vector3(1.0, 0.72 + progress * 0.28, 1.0)
    _disabled_visual_root.rotation.z = (1.0 - progress) * 0.18
    if _disabled_signal_material != null:
        _disabled_signal_material.emission_energy_multiplier = lerpf(0.18, 1.6, progress)


func _build_damage_presentation() -> void:
    if _damage_visual_root != null and is_instance_valid(_damage_visual_root):
        _damage_visual_root.free()
    _damage_visual_root = Node3D.new()
    _damage_visual_root.name = "RobotDamagePresentation"
    add_child(_damage_visual_root)

    _damage_signal_material = ModelKit3D.material(
        Color("431d25"),
        0.08,
        0.48,
        Color("f04d55"),
        0.8
    )
    var leak_material := ModelKit3D.material(
        Color("52252b"),
        0.04,
        0.42,
        Color("ff7055"),
        1.8
    )
    var positions := [
        Vector3(-0.48, 1.06, -0.94),
        Vector3(0.34, 1.26, -0.9),
        Vector3(0.0, 0.76, 0.86),
    ]
    for index in range(3):
        var position: Vector3 = positions[index]
        ModelKit3D.add_beveled_box(
            _damage_visual_root,
            Vector3(0.075, 0.46 + float(index) * 0.1, 0.12),
            position,
            _damage_signal_material,
            Vector3(0.0, 0.0, -0.28 + float(index) * 0.22),
            "RobotDamageScar%02d" % index,
            0.28
        )
        ModelKit3D.add_sphere(
            _damage_visual_root,
            0.07 + float(index) * 0.012,
            position + Vector3.UP * (0.26 + float(index) * 0.08),
            leak_material,
            Vector3(1.0, 0.72, 1.0),
            "RobotDamageLeak%02d" % index
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
        _damage_signal_material.emission_energy_multiplier = lerpf(0.55, 3.0, damage)
        _damage_signal_material.albedo_color = Color("381a21").lerp(Color("762c35"), damage)
    for index in range(3):
        var scar := _damage_visual_root.get_node_or_null("RobotDamageScar%02d" % index) as Node3D
        var leak := _damage_visual_root.get_node_or_null("RobotDamageLeak%02d" % index) as Node3D
        var threshold := 0.08 + float(index) * 0.2
        var visibility := clampf((damage - threshold) / 0.18, 0.0, 1.0)
        if scar != null:
            scar.visible = active and visibility > 0.0
            scar.scale = Vector3(1.0, 0.68 + visibility * 0.32, 1.0)
        if leak != null:
            leak.visible = active and visibility > 0.25


func _ensure_deferred_proxy_root() -> Node3D:
    if _deferred_proxy_root != null and is_instance_valid(_deferred_proxy_root):
        return _deferred_proxy_root
    _deferred_proxy_root = Node3D.new()
    _deferred_proxy_root.name = "DeferredVisualProxy"
    add_child(_deferred_proxy_root)
    return _deferred_proxy_root


func _refresh_visual_identity() -> void:
    if _model_root == null:
        return
    for child in _model_root.get_children():
        child.queue_free()

    if archetype == &"companion":
        _build_authored_companion_visuals()
        return
    if archetype == &"guardian":
        _build_authored_warden_visuals()
        return
    if archetype == &"salvager":
        _build_authored_scrapper_visuals()
        return
    if archetype == &"scout":
        _build_authored_pathfinder_visuals()
        return
    if archetype == &"engineer":
        _build_authored_engineer_visuals()
        return
    if archetype == &"relay":
        _build_signal_relay_visuals()
        return

    var steel := ModelKit3D.material(Color("3f4648"), 0.78, 0.4)
    var dark_steel := ModelKit3D.material(Color("202628"), 0.85, 0.38)
    var rust := ModelKit3D.material(Color("70452c"), 0.52, 0.72)
    var glow_color := Color("6de8ee")
    if archetype == &"guardian" or archetype == &"companion":
        glow_color = Color("e5a75c")
    elif archetype == &"scout":
        glow_color = Color("8bd879")
    elif archetype == &"engineer":
        glow_color = Color("efb06a")
    var glow := ModelKit3D.material(glow_color.darkened(0.55), 0.3, 0.3, glow_color, 2.8)

    var body_size := Vector3(1.25, 0.62, 1.55)
    if archetype == &"guardian" or archetype == &"companion":
        body_size = Vector3(1.5, 0.82, 1.7)
    elif archetype == &"engineer":
        body_size = Vector3(1.35, 0.72, 1.58)
    ModelKit3D.add_beveled_box(_model_root, body_size, Vector3(0.0, 0.86, 0.0), steel, Vector3.ZERO, "Chassis", 0.16)
    ModelKit3D.add_beveled_box(_model_root, Vector3(body_size.x * 0.84, 0.16, body_size.z * 0.72), Vector3(0.0, 1.25, 0.0), rust, Vector3.ZERO, "ArmorPlate", 0.22)
    ModelKit3D.add_box(_model_root, Vector3(body_size.x * 0.68, 0.09, body_size.z * 0.82), Vector3(0.0, 0.55, body_size.z * 0.08), dark_steel, Vector3.ZERO, "LowerChassis")
    ModelKit3D.add_box(_model_root, Vector3(0.16, 0.32, body_size.z * 0.76), Vector3(0.0, 0.88, 0.0), rust, Vector3.ZERO, "ChassisSpine")
    ModelKit3D.add_surface_panel(_model_root, Vector3(body_size.x * 0.72, 0.18, body_size.z * 0.48), Vector3(0.0, 1.34, -body_size.z * 0.05), steel, rust, Vector3(-0.04, 0.0, 0.0), "ChassisDetailPanel")
    ModelKit3D.add_sphere(_model_root, 0.22, Vector3(0.0, 1.12, -body_size.z * 0.55), glow, Vector3(1.2, 0.8, 0.6), "Sensor")
    ModelKit3D.add_box(_model_root, Vector3(0.48, 0.26, 0.12), Vector3(0.0, 1.15, -body_size.z * 0.62), dark_steel, Vector3.ZERO, "OpticHousing")
    ModelKit3D.add_sphere(_model_root, 0.075, Vector3(0.0, 1.15, -body_size.z * 0.7), glow, Vector3(1.7, 0.75, 0.5), "OpticLens")

    for side in [-1.0, 1.0]:
        var shoulder_x := float(side) * body_size.x * 0.57
        ModelKit3D.add_beveled_box(_model_root, Vector3(0.22, 0.24, body_size.z * 0.58), Vector3(shoulder_x, 1.0, 0.0), steel, Vector3(0.0, 0.0, float(side) * 0.12), "ShoulderPlate", 0.2)
        ModelKit3D.add_sphere(_model_root, 0.115, Vector3(shoulder_x, 0.77, -0.02), rust, Vector3.ONE, "Joint")
        ModelKit3D.add_box(_model_root, Vector3(0.09, 0.18, body_size.z * 0.5), Vector3(shoulder_x + float(side) * 0.13, 0.9, 0.0), dark_steel, Vector3(0.0, 0.0, float(side) * 0.14), "SidePanel")
        ModelKit3D.add_cylinder(_model_root, 0.035, body_size.z * 0.45, Vector3(shoulder_x - float(side) * 0.05, 0.86, -0.02), rust, Vector3(1.5708, 0.0, 0.0), "ExposedCable")

    # Frame progression is visible in the machine silhouette as well as in
    # simulation stats. These bounded assemblies are rebuilt whenever a frame
    # level changes and remain presentation-only: no new sockets, jobs or
    # per-unit maintenance are introduced.
    if level >= 2:
        var evolution_steel := ModelKit3D.material(Color("53656a"), 0.78, 0.3)
        var evolution_accent := ModelKit3D.material(glow_color.darkened(0.42), 0.32, 0.28, glow_color, 2.4)
        for side in [-1.0, 1.0]:
            var side_sign := float(side)
            ModelKit3D.add_beveled_box(
                _model_root,
                Vector3(0.18, 0.34, body_size.z * 0.66),
                Vector3(side_sign * body_size.x * 0.64, 1.1, 0.0),
                evolution_steel,
                Vector3(0.0, 0.0, side_sign * 0.08),
                "Tier2ShoulderRail",
                0.22
            )
            ModelKit3D.add_box(
                _model_root,
                Vector3(0.055, 0.08, body_size.z * 0.48),
                Vector3(side_sign * body_size.x * 0.75, 1.1, -0.03),
                evolution_accent,
                Vector3(0.0, 0.0, side_sign * 0.08),
                "Tier2SignalStrip"
            )
        ModelKit3D.add_louvered_panel(
            _model_root,
            Vector3(body_size.x * 0.46, 0.28, 0.16),
            Vector3(0.0, 1.48, body_size.z * 0.34),
            dark_steel,
            evolution_steel,
            Vector3.ZERO,
            "Tier2DorsalServicePanel",
            3
        )

    if level >= 3:
        var crown_material := ModelKit3D.material(glow_color.darkened(0.34), 0.42, 0.24, glow_color, 3.1)
        var crown_ring := MeshInstance3D.new()
        crown_ring.name = "Tier3CrownRing"
        var crown_mesh := TorusMesh.new()
        crown_mesh.inner_radius = body_size.x * 0.34
        crown_mesh.outer_radius = crown_mesh.inner_radius + 0.055
        crown_mesh.rings = 16
        crown_mesh.ring_segments = 32
        crown_ring.mesh = crown_mesh
        crown_ring.material_override = crown_material
        crown_ring.position = Vector3(0.0, 1.92, 0.08)
        _model_root.add_child(crown_ring)
        ModelKit3D.add_cylinder(_model_root, 0.045, 0.58, Vector3(0.0, 2.17, 0.08), crown_material, Vector3.ZERO, "Tier3CrownMast")
        for index in range(3):
            var crown_angle := TAU * float(index) / 3.0
            ModelKit3D.add_sphere(
                _model_root,
                0.075,
                Vector3(cos(crown_angle) * body_size.x * 0.4, 1.94, 0.08 + sin(crown_angle) * body_size.x * 0.4),
                crown_material,
                Vector3.ONE,
                "Tier3CrownBeacon"
            )

    for side in [-1.0, 1.0]:
        for front in [-1.0, 1.0]:
            var leg_x: float = float(side) * body_size.x * 0.48
            var leg_z: float = float(front) * body_size.z * 0.38
            ModelKit3D.add_capsule(_model_root, 0.12, 0.72, Vector3(leg_x, 0.46, leg_z), dark_steel, Vector3(0.0, 0.0, float(side) * 0.34), "Leg")
            ModelKit3D.add_beveled_box(_model_root, Vector3(0.28, 0.12, 0.42), Vector3(leg_x + float(side) * 0.12, 0.12, leg_z), rust, Vector3.ZERO, "Foot", 0.2)

    match archetype:
        &"salvager":
            ModelKit3D.add_box(_model_root, Vector3(0.95, 0.55, 0.82), Vector3(0.0, 1.45, 0.2), dark_steel, Vector3.ZERO, "CargoBin")
            ModelKit3D.add_box(_model_root, Vector3(1.05, 0.08, 0.92), Vector3(0.0, 1.75, 0.2), rust, Vector3.ZERO, "CargoLip")
            ModelKit3D.add_box(_model_root, Vector3(0.12, 0.48, 0.9), Vector3(0.0, 1.46, 0.2), rust, Vector3.ZERO, "CargoStrap")
            ModelKit3D.add_sphere(_model_root, 0.14, Vector3(0.66, 0.95, -0.35), dark_steel, Vector3.ONE, "DismantlerJoint")
            ModelKit3D.add_cylinder(_model_root, 0.12, 0.8, Vector3(0.66, 0.95, -0.35), rust, Vector3(0.0, 0.0, 1.15), "Dismantler")
            ModelKit3D.add_box(_model_root, Vector3(0.28, 0.18, 0.32), Vector3(0.66, 0.95, -0.82), dark_steel, Vector3(0.0, 0.0, 0.15), "DismantlerTool")
            ModelKit3D.add_cylinder(_model_root, 0.11, 0.18, Vector3(0.0, 1.46, 0.2), rust, Vector3(1.5708, 0.0, 0.0), "SalvageDrum")
            ModelKit3D.add_box(_model_root, Vector3(0.18, 0.34, 0.56), Vector3(-0.66, 1.08, 0.15), steel, Vector3(0.0, 0.0, -0.18), "SalvageClamp")
        &"guardian", &"companion":
            ModelKit3D.add_beveled_box(_model_root, Vector3(1.72, 0.82, 0.14), Vector3(0.0, 0.78, 0.7), steel, Vector3.ZERO, "RearShield", 0.18)
            ModelKit3D.add_beveled_box(_model_root, Vector3(1.38, 0.52, 0.12), Vector3(0.0, 1.02, 0.84), rust, Vector3.ZERO, "ShieldRib", 0.16)
            ModelKit3D.add_cylinder(_model_root, 0.12, 1.1, Vector3(-0.25, 1.35, -0.65), dark_steel, Vector3(1.5708, 0.0, 0.0), "Weapon")
            ModelKit3D.add_cylinder(_model_root, 0.12, 1.1, Vector3(0.25, 1.35, -0.65), dark_steel, Vector3(1.5708, 0.0, 0.0), "WeaponBarrel")
            ModelKit3D.add_cylinder(_model_root, 0.16, 0.12, Vector3(-0.25, 1.35, -1.18), glow, Vector3(1.5708, 0.0, 0.0), "WeaponMuzzle")
            ModelKit3D.add_cylinder(_model_root, 0.16, 0.12, Vector3(0.25, 1.35, -1.18), glow, Vector3(1.5708, 0.0, 0.0), "WeaponMuzzle")
            if archetype == &"companion":
                ModelKit3D.add_box(_model_root, Vector3(0.68, 0.12, 0.18), Vector3(0.0, 1.46, 0.1), rust, Vector3.ZERO, "CompanionCrown")
        &"scout":
            ModelKit3D.add_box(_model_root, Vector3(0.18, 0.3, 0.9), Vector3(-body_size.x * 0.54, 1.02, 0.08), steel, Vector3(0.0, 0.0, -0.16), "ScoutFin")
            ModelKit3D.add_box(_model_root, Vector3(0.18, 0.3, 0.9), Vector3(body_size.x * 0.54, 1.02, 0.08), steel, Vector3(0.0, 0.0, 0.16), "ScoutFin")
            ModelKit3D.add_cylinder(_model_root, 0.06, 1.5, Vector3(0.0, 1.8, 0.15), dark_steel, Vector3.ZERO, "Antenna")
            ModelKit3D.add_cylinder(_model_root, 0.15, 0.08, Vector3(0.0, 2.46, 0.15), rust, Vector3.ZERO, "BeaconRing")
            ModelKit3D.add_sphere(_model_root, 0.11, Vector3(0.0, 2.55, 0.15), glow, Vector3.ONE, "Beacon")
            ModelKit3D.add_sphere(_model_root, 0.08, Vector3(-0.22, 1.14, -body_size.z * 0.66), glow, Vector3.ONE, "ScoutOptic")
            ModelKit3D.add_sphere(_model_root, 0.08, Vector3(0.22, 1.14, -body_size.z * 0.66), glow, Vector3.ONE, "ScoutOptic")
        &"engineer":
            ModelKit3D.add_box(_model_root, Vector3(0.92, 0.4, 0.78), Vector3(0.0, 1.5, 0.24), dark_steel, Vector3.ZERO, "MaterialCradle")
            ModelKit3D.add_box(_model_root, Vector3(1.02, 0.08, 0.86), Vector3(0.0, 1.72, 0.24), rust, Vector3.ZERO, "CradleLip")
            ModelKit3D.add_sphere(_model_root, 0.13, Vector3(-0.72, 1.05, -0.1), dark_steel, Vector3.ONE, "PistonJoint")
            ModelKit3D.add_sphere(_model_root, 0.13, Vector3(0.72, 1.05, 0.0), dark_steel, Vector3.ONE, "PistonJoint")
            ModelKit3D.add_cylinder(_model_root, 0.1, 1.15, Vector3(-0.72, 1.05, -0.1), rust, Vector3(0.0, 0.0, 1.05), "WelderArm")
            ModelKit3D.add_cylinder(_model_root, 0.11, 1.2, Vector3(0.72, 1.05, 0.0), steel, Vector3(0.0, 0.0, -1.0), "AssemblyArm")
            ModelKit3D.add_box(_model_root, Vector3(0.22, 0.18, 0.34), Vector3(-1.18, 0.74, -0.1), dark_steel, Vector3(0.0, 0.0, 0.2), "ToolHead")
            ModelKit3D.add_box(_model_root, Vector3(0.26, 0.18, 0.32), Vector3(1.18, 0.72, 0.0), dark_steel, Vector3(0.0, 0.0, -0.2), "AssemblyToolHead")
            ModelKit3D.add_cylinder(_model_root, 0.12, 0.16, Vector3(0.0, 1.44, 0.22), glow, Vector3(1.5708, 0.0, 0.0), "ForgeCoil")
            ModelKit3D.add_sphere(_model_root, 0.08, Vector3(-1.18, 0.74, -0.1), glow, Vector3.ONE, "WelderGlow")

    _add_hero_service_detail(glow_color)
    _sensor_light = ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 1.12, -body_size.z * 0.62), glow_color, 0.85, 4.0)


func _add_hero_service_detail(glow_color: Color) -> void:
    # Every authored friendly chassis gets one restrained manufactured focal:
    # a signal collar, service face and paired harness anchors. This gives the
    # machine society a shared production language without adding sockets,
    # jobs, maintenance or collision geometry.
    var collar_y := 1.48
    var collar_radius := 0.66
    var panel_width := 0.72
    match archetype:
        &"companion", &"guardian":
            collar_y = 1.56
            collar_radius = 0.78
            panel_width = 0.86
        &"scout":
            collar_y = 1.42
            collar_radius = 0.58
            panel_width = 0.64
        &"relay":
            collar_y = 2.18
            collar_radius = 0.72
            panel_width = 0.82

    var housing := ModelKit3D.material(Color("172428"), 0.86, 0.32)
    var edge := ModelKit3D.material(Color("4d6264"), 0.74, 0.34)
    var signal_mat := ModelKit3D.material(glow_color.darkened(0.48), 0.34, 0.25, glow_color, 2.6)
    ModelKit3D.add_torus(_model_root, collar_radius, 0.042, Vector3(0.0, collar_y, 0.14), edge, Vector3.ZERO, "HeroSignalCollar", 32, 6)
    ModelKit3D.add_surface_panel(
        _model_root,
        Vector3(panel_width, 0.18, 0.16),
        Vector3(0.0, collar_y + 0.02, -collar_radius * 0.8),
        housing,
        signal_mat,
        Vector3(-0.04, 0.0, 0.0),
        "HeroServiceFace"
    )
    for side in [-1.0, 1.0]:
        var side_sign := float(side)
        ModelKit3D.add_beveled_box(
            _model_root,
            Vector3(0.11, 0.12, 0.22),
            Vector3(side_sign * collar_radius * 0.72, collar_y, 0.14),
            edge,
            Vector3(0.0, 0.0, side_sign * 0.12),
            "HeroHarnessAnchor%s" % ("L" if side_sign < 0.0 else "R"),
            0.18
        )
        ModelKit3D.add_cylinder(
            _model_root,
            0.026,
            0.42,
            Vector3(side_sign * collar_radius * 0.72, collar_y - 0.22, 0.16),
            signal_mat,
            Vector3(0.0, 0.0, side_sign * 0.18),
            "HeroHarnessConduit%s" % ("L" if side_sign < 0.0 else "R")
        )


func _build_authored_companion_visuals() -> void:
    # The opening companion is the one machine the player must trust. Give it
    # a real authored shell while preserving this node's collision, sockets,
    # deterministic animation lookup, and role feedback systems.
    var authored_model := _instantiate_authored_scene(AUTHORED_BULWARK_MODEL_SCENE, "Bulwark")
    if authored_model == null:
        return
    authored_model.name = "BulwarkAuthoredModel"
    _model_root.add_child(authored_model)

    var steel := ModelKit3D.material(Color("53656a"), 0.78, 0.3)
    var dark_steel := ModelKit3D.material(Color("182326"), 0.86, 0.34)
    var glow_color := Color("e5a75c")
    var glow := ModelKit3D.material(glow_color.darkened(0.5), 0.34, 0.28, glow_color, 2.8)

    if level >= 2:
        for side in [-1.0, 1.0]:
            var side_sign := float(side)
            ModelKit3D.add_beveled_box(
                _model_root,
                Vector3(0.18, 0.34, 1.14),
                Vector3(side_sign * 1.02, 1.1, 0.0),
                steel,
                Vector3(0.0, 0.0, side_sign * 0.08),
                "Tier2ShoulderRail",
                0.22
            )
            ModelKit3D.add_box(
                _model_root,
                Vector3(0.055, 0.08, 0.8),
                Vector3(side_sign * 1.1, 1.1, -0.03),
                glow,
                Vector3(0.0, 0.0, side_sign * 0.08),
                "Tier2SignalStrip"
            )
        ModelKit3D.add_louvered_panel(
            _model_root,
            Vector3(0.72, 0.28, 0.16),
            Vector3(0.0, 1.6, 0.56),
            dark_steel,
            steel,
            Vector3.ZERO,
            "Tier2DorsalServicePanel",
            3
        )

    if level >= 3:
        var crown_ring := MeshInstance3D.new()
        crown_ring.name = "Tier3CrownRing"
        var crown_mesh := TorusMesh.new()
        crown_mesh.inner_radius = 0.5
        crown_mesh.outer_radius = 0.56
        crown_mesh.rings = 16
        crown_mesh.ring_segments = 32
        crown_ring.mesh = crown_mesh
        crown_ring.material_override = glow
        crown_ring.position = Vector3(0.0, 2.02, 0.18)
        _model_root.add_child(crown_ring)
        ModelKit3D.add_cylinder(_model_root, 0.045, 0.58, Vector3(0.0, 2.28, 0.18), glow, Vector3.ZERO, "Tier3CrownMast")
        for index in range(3):
            var crown_angle := TAU * float(index) / 3.0
            ModelKit3D.add_sphere(
                _model_root,
                0.075,
                Vector3(cos(crown_angle) * 0.56, 2.04, 0.18 + sin(crown_angle) * 0.56),
                glow,
                Vector3.ONE,
                "Tier3CrownBeacon"
            )

    _add_hero_service_detail(glow_color)
    _sensor_light = ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 1.15, -1.04), glow_color, 0.9, 4.2)


func _build_authored_warden_visuals() -> void:
    # Warden is the second production silhouette: an escort machine whose
    # broad armour, counterweight and heat hardware communicate a defensive
    # doctrine without adding a new player-managed role or resource.
    var authored_model := _instantiate_authored_scene(AUTHORED_WARDEN_MODEL_SCENE, "Warden")
    if authored_model == null:
        return
    authored_model.name = "WardenAuthoredModel"
    _model_root.add_child(authored_model)

    var steel := ModelKit3D.material(Color("53656a"), 0.78, 0.3)
    var dark_steel := ModelKit3D.material(Color("182326"), 0.86, 0.34)
    var glow_color := Color("e5a75c")
    var glow := ModelKit3D.material(glow_color.darkened(0.5), 0.34, 0.28, glow_color, 2.8)

    # Keep the guardian's original escort read explicit in the authored shell:
    # rear protection remains a stable role cue and is also used by the
    # presentation animator for a restrained rib motion.
    ModelKit3D.add_beveled_box(_model_root, Vector3(1.78, 0.74, 0.14), Vector3(0.0, 0.8, 0.86), steel, Vector3.ZERO, "RearShield", 0.18)
    ModelKit3D.add_beveled_box(_model_root, Vector3(1.44, 0.12, 0.12), Vector3(0.0, 1.05, 0.96), dark_steel, Vector3.ZERO, "ShieldRib", 0.16)

    if level >= 2:
        for side in [-1.0, 1.0]:
            var side_sign := float(side)
            ModelKit3D.add_beveled_box(
                _model_root,
                Vector3(0.2, 0.36, 1.2),
                Vector3(side_sign * 1.1, 1.12, 0.0),
                steel,
                Vector3(0.0, 0.0, side_sign * 0.08),
                "Tier2ShoulderRail",
                0.22
            )
            ModelKit3D.add_box(
                _model_root,
                Vector3(0.06, 0.08, 0.84),
                Vector3(side_sign * 1.18, 1.12, -0.03),
                glow,
                Vector3(0.0, 0.0, side_sign * 0.08),
                "Tier2SignalStrip"
            )
        ModelKit3D.add_louvered_panel(
            _model_root,
            Vector3(0.82, 0.3, 0.16),
            Vector3(0.0, 1.64, 0.56),
            dark_steel,
            steel,
            Vector3.ZERO,
            "Tier2DorsalServicePanel",
            4
        )

    if level >= 3:
        var crown_ring := MeshInstance3D.new()
        crown_ring.name = "Tier3CrownRing"
        var crown_mesh := TorusMesh.new()
        crown_mesh.inner_radius = 0.54
        crown_mesh.outer_radius = 0.6
        crown_mesh.rings = 16
        crown_mesh.ring_segments = 32
        crown_ring.mesh = crown_mesh
        crown_ring.material_override = glow
        crown_ring.position = Vector3(0.0, 2.1, 0.18)
        _model_root.add_child(crown_ring)
        ModelKit3D.add_cylinder(_model_root, 0.05, 0.6, Vector3(0.0, 2.38, 0.18), glow, Vector3.ZERO, "Tier3CrownMast")
        for index in range(3):
            var crown_angle := TAU * float(index) / 3.0
            ModelKit3D.add_sphere(
                _model_root,
                0.078,
                Vector3(cos(crown_angle) * 0.6, 2.12, 0.18 + sin(crown_angle) * 0.6),
                glow,
                Vector3.ONE,
                "Tier3CrownBeacon"
            )

    _add_hero_service_detail(glow_color)
    _sensor_light = ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 1.18, -1.07), glow_color, 0.9, 4.2)


func _build_authored_scrapper_visuals() -> void:
    # Scrapper's authored shell makes the machine society's routine burden
    # visible: the hopper, arms and intake say "recover useful material" at a
    # glance without exposing a per-robot work queue to the player.
    var authored_scene_instance := _instantiate_authored_scene(AUTHORED_SCRAPPER_MODEL_SCENE, "Scrapper")
    if authored_scene_instance == null:
        return
    # Flatten the imported scene so the existing release-art path
    # `RobotModel/Chassis/ChassisCore` remains valid for late-fabricated units.
    # Keep a marker node for diagnostics without making it an extra visual
    # wrapper around every mesh.
    var imported_root := authored_scene_instance.get_node_or_null("ScrapperModel") as Node
    if imported_root == null:
        imported_root = authored_scene_instance
    var authored_children := imported_root.get_children()
    for child in authored_children:
        child.owner = null
        imported_root.remove_child(child)
        _model_root.add_child(child)
    if imported_root != authored_scene_instance:
        imported_root.free()
    authored_scene_instance.free()
    var authored_marker := Node3D.new()
    authored_marker.name = "ScrapperAuthoredModel"
    _model_root.add_child(authored_marker)

    var steel := ModelKit3D.material(Color("53656a"), 0.78, 0.3)
    var dark_steel := ModelKit3D.material(Color("182326"), 0.86, 0.34)
    var glow_color := Color("6de8ee")
    var glow := ModelKit3D.material(glow_color.darkened(0.5), 0.34, 0.28, glow_color, 2.8)

    if level >= 2:
        for side in [-1.0, 1.0]:
            var side_sign := float(side)
            ModelKit3D.add_beveled_box(
                _model_root,
                Vector3(0.16, 0.3, 1.0),
                Vector3(side_sign * 0.8, 1.1, 0.0),
                steel,
                Vector3(0.0, 0.0, side_sign * 0.08),
                "Tier2ShoulderRail",
                0.2
            )
            ModelKit3D.add_box(
                _model_root,
                Vector3(0.05, 0.07, 0.7),
                Vector3(side_sign * 0.88, 1.1, -0.02),
                glow,
                Vector3(0.0, 0.0, side_sign * 0.08),
                "Tier2SignalStrip"
            )
        ModelKit3D.add_louvered_panel(
            _model_root,
            Vector3(0.64, 0.26, 0.15),
            Vector3(0.0, 1.9, 0.2),
            dark_steel,
            steel,
            Vector3.ZERO,
            "Tier2DorsalServicePanel",
            3
        )

    if level >= 3:
        var crown_ring := MeshInstance3D.new()
        crown_ring.name = "Tier3CrownRing"
        var crown_mesh := TorusMesh.new()
        crown_mesh.inner_radius = 0.42
        crown_mesh.outer_radius = 0.48
        crown_mesh.rings = 16
        crown_mesh.ring_segments = 32
        crown_ring.mesh = crown_mesh
        crown_ring.material_override = glow
        crown_ring.position = Vector3(0.0, 2.12, 0.2)
        _model_root.add_child(crown_ring)
        ModelKit3D.add_cylinder(_model_root, 0.04, 0.5, Vector3(0.0, 2.35, 0.2), glow, Vector3.ZERO, "Tier3CrownMast")
        ModelKit3D.add_sphere(_model_root, 0.07, Vector3(0.0, 2.64, 0.2), glow, Vector3.ONE, "Tier3CrownBeacon")

    _add_hero_service_detail(glow_color)
    _sensor_light = ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 1.08, -0.94), glow_color, 0.76, 3.7)


func _build_authored_pathfinder_visuals() -> void:
    # Pathfinder's scout silhouette is intentionally taller and lighter: the
    # mast, dish and paired optics make screening and survey behavior legible
    # without exposing a route-planning dashboard or per-unit chores.
    var authored_scene_instance := _instantiate_authored_scene(AUTHORED_PATHFINDER_MODEL_SCENE, "Pathfinder")
    if authored_scene_instance == null:
        return
    var imported_root := authored_scene_instance.get_node_or_null("PathfinderModel") as Node
    if imported_root == null:
        imported_root = authored_scene_instance
    var authored_children := imported_root.get_children()
    for child in authored_children:
        child.owner = null
        imported_root.remove_child(child)
        _model_root.add_child(child)
    if imported_root != authored_scene_instance:
        imported_root.free()
    authored_scene_instance.free()
    var authored_marker := Node3D.new()
    authored_marker.name = "PathfinderAuthoredModel"
    _model_root.add_child(authored_marker)

    var steel := ModelKit3D.material(Color("536a61"), 0.78, 0.3)
    var dark_steel := ModelKit3D.material(Color("182624"), 0.86, 0.34)
    var glow_color := Color("8bd879")
    var glow := ModelKit3D.material(glow_color.darkened(0.5), 0.34, 0.28, glow_color, 2.8)

    if level >= 2:
        for side in [-1.0, 1.0]:
            var side_sign := float(side)
            ModelKit3D.add_beveled_box(
                _model_root,
                Vector3(0.16, 0.3, 1.1),
                Vector3(side_sign * 0.78, 1.08, 0.08),
                steel,
                Vector3(0.0, 0.0, side_sign * 0.12),
                "Tier2ShoulderRail",
                0.2
            )
            ModelKit3D.add_box(
                _model_root,
                Vector3(0.05, 0.07, 0.78),
                Vector3(side_sign * 0.86, 1.08, 0.02),
                glow,
                Vector3(0.0, 0.0, side_sign * 0.1),
                "Tier2SignalStrip"
            )
        ModelKit3D.add_louvered_panel(
            _model_root,
            Vector3(0.58, 0.24, 0.14),
            Vector3(0.0, 1.54, 0.18),
            dark_steel,
            steel,
            Vector3.ZERO,
            "Tier2DorsalServicePanel",
            3
        )

    if level >= 3:
        var crown_ring := MeshInstance3D.new()
        crown_ring.name = "Tier3CrownRing"
        var crown_mesh := TorusMesh.new()
        crown_mesh.inner_radius = 0.34
        crown_mesh.outer_radius = 0.4
        crown_mesh.rings = 16
        crown_mesh.ring_segments = 32
        crown_ring.mesh = crown_mesh
        crown_ring.material_override = glow
        crown_ring.position = Vector3(0.0, 3.06, 0.12)
        _model_root.add_child(crown_ring)
        ModelKit3D.add_cylinder(_model_root, 0.035, 0.42, Vector3(0.0, 3.28, 0.12), glow, Vector3.ZERO, "Tier3CrownMast")
        ModelKit3D.add_sphere(_model_root, 0.065, Vector3(0.0, 3.52, 0.12), glow, Vector3.ONE, "Tier3CrownBeacon")

    _add_hero_service_detail(glow_color)
    _sensor_light = ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 1.06, -0.9), glow_color, 0.72, 3.8)


func _build_authored_engineer_visuals() -> void:
    # Engineer is the construction specialist: the visual language emphasizes
    # assembly tooling and a contained forge rather than another combat loadout.
    var authored_scene_instance := _instantiate_authored_scene(AUTHORED_ENGINEER_MODEL_SCENE, "Engineer")
    if authored_scene_instance == null:
        return
    var imported_root := authored_scene_instance.get_node_or_null("EngineerModel") as Node
    if imported_root == null:
        imported_root = authored_scene_instance
    var authored_children := imported_root.get_children()
    for child in authored_children:
        child.owner = null
        imported_root.remove_child(child)
        _model_root.add_child(child)
    if imported_root != authored_scene_instance:
        imported_root.free()
    authored_scene_instance.free()
    var authored_marker := Node3D.new()
    authored_marker.name = "EngineerAuthoredModel"
    _model_root.add_child(authored_marker)

    var steel := ModelKit3D.material(Color("53656a"), 0.78, 0.3)
    var dark_steel := ModelKit3D.material(Color("182326"), 0.86, 0.34)
    var glow_color := Color("efb06a")
    var glow := ModelKit3D.material(glow_color.darkened(0.5), 0.34, 0.28, glow_color, 2.8)

    if level >= 2:
        for side in [-1.0, 1.0]:
            var side_sign := float(side)
            ModelKit3D.add_beveled_box(
                _model_root,
                Vector3(0.18, 0.32, 1.08),
                Vector3(side_sign * 0.9, 1.1, 0.0),
                steel,
                Vector3(0.0, 0.0, side_sign * 0.08),
                "Tier2ShoulderRail",
                0.2
            )
            ModelKit3D.add_box(
                _model_root,
                Vector3(0.05, 0.07, 0.76),
                Vector3(side_sign * 0.98, 1.1, -0.02),
                glow,
                Vector3(0.0, 0.0, side_sign * 0.08),
                "Tier2SignalStrip"
            )
        ModelKit3D.add_louvered_panel(
            _model_root,
            Vector3(0.7, 0.28, 0.15),
            Vector3(0.0, 1.82, 0.28),
            dark_steel,
            steel,
            Vector3.ZERO,
            "Tier2DorsalServicePanel",
            3
        )

    if level >= 3:
        var crown_ring := MeshInstance3D.new()
        crown_ring.name = "Tier3CrownRing"
        var crown_mesh := TorusMesh.new()
        crown_mesh.inner_radius = 0.44
        crown_mesh.outer_radius = 0.5
        crown_mesh.rings = 16
        crown_mesh.ring_segments = 32
        crown_ring.mesh = crown_mesh
        crown_ring.material_override = glow
        crown_ring.position = Vector3(0.0, 2.08, 0.2)
        _model_root.add_child(crown_ring)
        ModelKit3D.add_cylinder(_model_root, 0.04, 0.5, Vector3(0.0, 2.32, 0.2), glow, Vector3.ZERO, "Tier3CrownMast")
        ModelKit3D.add_sphere(_model_root, 0.07, Vector3(0.0, 2.62, 0.2), glow, Vector3.ONE, "Tier3CrownBeacon")

    _add_hero_service_detail(glow_color)
    _sensor_light = ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 1.1, -0.98), glow_color, 0.78, 3.8)


func _build_signal_relay_visuals() -> void:
    # The Relay is a deliberately distinct late-game chassis: a tall, quiet
    # communications instrument with a protected mast and directional array.
    # Its primary shell is source-authored glTF; the bounded runtime finish
    # below carries progression-state detail without replacing that shell.
    # Keep the imported scene root intact so Godot's generated AnimationPlayer
    # remains alongside RelayModel. The other authored shells predate this
    # animation contract and can be extracted safely; the Relay keeps the
    # source scene as one bounded presentation unit.
    var authored_model := _instantiate_authored_scene(AUTHORED_RELAY_MODEL_SCENE, "Relay")
    if authored_model == null:
        return
    authored_model.name = "RelayAuthoredModel"
    _model_root.add_child(authored_model)

    var dark_steel := ModelKit3D.material(Color("111b20"), 0.88, 0.28)
    var cyan_color := Color("79e3e8")
    var cyan := ModelKit3D.material(Color("164c52"), 0.34, 0.22, cyan_color, 2.6)
    var amber := ModelKit3D.material(Color("6d3e20"), 0.38, 0.42, Color("e5a45b"), 1.3)
    if level >= 2:
        ModelKit3D.add_louvered_panel(_model_root, Vector3(0.24, 0.32, 0.1), Vector3(-0.7, 1.0, 0.0), dark_steel, cyan, Vector3(0.0, 0.0, 0.2), "RelaySignalPanel", 3)
        ModelKit3D.add_louvered_panel(_model_root, Vector3(0.24, 0.32, 0.1), Vector3(0.7, 1.0, 0.0), dark_steel, cyan, Vector3(0.0, 0.0, -0.2), "RelaySignalPanel", 3)
    if level >= 3:
        var crown_ring := MeshInstance3D.new()
        crown_ring.name = "Tier3CrownRing"
        var crown_mesh := TorusMesh.new()
        crown_mesh.inner_radius = 0.4
        crown_mesh.outer_radius = 0.445
        crown_mesh.rings = 16
        crown_mesh.ring_segments = 32
        crown_ring.mesh = crown_mesh
        crown_ring.material_override = amber
        crown_ring.position = Vector3(0.0, 2.38, 0.02)
        _model_root.add_child(crown_ring)
        ModelKit3D.add_sphere(_model_root, 0.065, Vector3(0.0, 2.52, 0.02), amber, Vector3.ONE, "Tier3CrownBeacon")
    _add_hero_service_detail(cyan_color)
    _sensor_light = ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 2.28, -0.04), cyan_color, 0.72, 4.4)
