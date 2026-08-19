class_name RobotUnit3D
extends CharacterBody3D

signal destroyed(robot: RobotUnit3D)
signal health_changed(robot: RobotUnit3D, current: float, maximum: float)
signal weapon_fired(origin: Vector3, target: Vector3, target_node: Node)
signal salvage_completed(robot: RobotUnit3D, pile: Node, amount: int)

var archetype: StringName = &"salvager"
var level: int = 1
var maximum_health: float = 90.0
var current_health: float = 90.0
var move_speed: float = 4.4
var attack_damage: float = 4.0
var attack_range: float = 6.0
var attack_interval: float = 1.1
var attack_cooldown: float = 0.0
var salvage_rate: float = 1.0
var construction_rate: float = 1.0
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
var alive: bool = true

var _model_root: Node3D
var _sensor_light: OmniLight3D


func _ready() -> void:
    add_to_group("friendly_robots")
    collision_layer = 2
    collision_mask = 1 | 2 | 4
    _apply_level_stats()
    _build_visuals()


func configure(next_archetype: StringName, next_level: int) -> void:
    archetype = next_archetype
    level = clampi(next_level, 1, 3)
    _apply_level_stats()
    if is_inside_tree():
        _refresh_visual_identity()


func _physics_process(delta: float) -> void:
    if not alive:
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
    var desired_speed := minf(move_speed, speed_cap)
    velocity.x = move_toward(velocity.x, direction.x * desired_speed, 18.0 * delta)
    velocity.z = move_toward(velocity.z, direction.z * desired_speed, 18.0 * delta)
    velocity.y = -0.8
    rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 0.2)
    move_and_slide()


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
    health_changed.emit(self, current_health, maximum_health)
    if current_health <= 0.0:
        alive = false
        state_name = &"disabled"
        decision_reason = "Disabled at this physical location; recovery requires the surviving machines."
        destroyed.emit(self)
        queue_free()


func repair(amount: float) -> void:
    if not alive:
        return
    current_health = minf(maximum_health, current_health + maxf(0.0, amount))
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
    return best


func _apply_level_stats() -> void:
    construction_rate = 1.0
    salvage_rate = 1.0
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
        _:
            maximum_health = [95.0, 125.0, 165.0][level - 1]
            attack_damage = [4.0, 6.0, 9.0][level - 1]
            move_speed = [4.4, 4.7, 5.0][level - 1]
            salvage_rate = [1.0, 1.35, 1.8][level - 1]
            attack_range = 5.0
            attack_interval = 1.25
    current_health = maximum_health


func _build_visuals() -> void:
    ModelKit3D.add_collision_capsule(self, 0.48, 1.0, Vector3(0.0, 0.52, 0.0))
    _model_root = Node3D.new()
    _model_root.name = "RobotModel"
    add_child(_model_root)
    _refresh_visual_identity()


func _refresh_visual_identity() -> void:
    if _model_root == null:
        return
    for child in _model_root.get_children():
        child.queue_free()

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
    ModelKit3D.add_box(_model_root, body_size, Vector3(0.0, 0.86, 0.0), steel, Vector3.ZERO, "Chassis")
    ModelKit3D.add_box(_model_root, Vector3(body_size.x * 0.8, 0.16, body_size.z * 0.7), Vector3(0.0, 1.25, 0.0), rust, Vector3.ZERO, "ArmorPlate")
    ModelKit3D.add_sphere(_model_root, 0.22, Vector3(0.0, 1.12, -body_size.z * 0.55), glow, Vector3(1.2, 0.8, 0.6), "Sensor")

    for side in [-1.0, 1.0]:
        for front in [-1.0, 1.0]:
            var leg_x: float = float(side) * body_size.x * 0.48
            var leg_z: float = float(front) * body_size.z * 0.38
            ModelKit3D.add_capsule(_model_root, 0.12, 0.72, Vector3(leg_x, 0.46, leg_z), dark_steel, Vector3(0.0, 0.0, float(side) * 0.34), "Leg")
            ModelKit3D.add_box(_model_root, Vector3(0.28, 0.12, 0.42), Vector3(leg_x + float(side) * 0.12, 0.12, leg_z), rust, Vector3.ZERO, "Foot")

    match archetype:
        &"salvager":
            ModelKit3D.add_box(_model_root, Vector3(0.95, 0.55, 0.82), Vector3(0.0, 1.45, 0.2), dark_steel, Vector3.ZERO, "CargoBin")
            ModelKit3D.add_cylinder(_model_root, 0.12, 0.8, Vector3(0.66, 0.95, -0.35), rust, Vector3(0.0, 0.0, 1.15), "Dismantler")
        &"guardian", &"companion":
            ModelKit3D.add_cylinder(_model_root, 0.12, 1.1, Vector3(0.0, 1.35, -0.65), dark_steel, Vector3(1.5708, 0.0, 0.0), "Weapon")
            ModelKit3D.add_box(_model_root, Vector3(1.72, 0.82, 0.14), Vector3(0.0, 0.78, 0.7), steel, Vector3.ZERO, "RearShield")
        &"scout":
            ModelKit3D.add_cylinder(_model_root, 0.06, 1.5, Vector3(0.0, 1.8, 0.15), dark_steel, Vector3.ZERO, "Antenna")
            ModelKit3D.add_sphere(_model_root, 0.11, Vector3(0.0, 2.55, 0.15), glow, Vector3.ONE, "Beacon")
        &"engineer":
            ModelKit3D.add_box(_model_root, Vector3(0.92, 0.4, 0.78), Vector3(0.0, 1.5, 0.24), dark_steel, Vector3.ZERO, "MaterialCradle")
            ModelKit3D.add_cylinder(_model_root, 0.1, 1.15, Vector3(-0.72, 1.05, -0.1), rust, Vector3(0.0, 0.0, 1.05), "WelderArm")
            ModelKit3D.add_cylinder(_model_root, 0.11, 1.2, Vector3(0.72, 1.05, 0.0), steel, Vector3(0.0, 0.0, -1.0), "AssemblyArm")
            ModelKit3D.add_sphere(_model_root, 0.08, Vector3(-1.18, 0.74, -0.1), glow, Vector3.ONE, "WelderGlow")

    _sensor_light = ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 1.12, -body_size.z * 0.62), glow_color, 0.85, 4.0)
