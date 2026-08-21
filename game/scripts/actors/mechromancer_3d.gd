class_name Mechromancer3D
extends CharacterBody3D

const AUTHORED_MODEL_SCENE: PackedScene = preload("res://assets/mechromancer/mechromancer.gltf")

signal health_changed(current: float, maximum: float)
signal died
signal pistol_fired(origin: Vector3, target: Vector3, target_node: Node)
signal channel_started(kind: StringName, duration: float, description: String)
signal channel_progress(kind: StringName, progress: float, description: String)
signal channel_completed(kind: StringName, target: Node, metadata: Dictionary)
signal channel_cancelled(kind: StringName, target: Node, metadata: Dictionary)
signal noise_requested(position: Vector3, radius: float, intensity: float, source_kind: StringName)

@export var maximum_health: float = 100.0
@export var move_speed: float = 5.4
@export var pistol_range: float = 10.5
@export var pistol_damage: float = 4.0
@export var pistol_interval: float = 0.82

var current_health: float = 100.0
var current_target: Node3D
var input_enabled: bool = true
var invulnerability_seconds: float = 0.0
var pistol_cooldown: float = 0.0
var channel_kind: StringName = &""
var channel_target: Node
var channel_duration: float = 0.0
var channel_elapsed: float = 0.0
var channel_description: String = ""
var channel_metadata: Dictionary = {}
var channel_requires_hold: bool = false
var channel_noise_radius: float = 0.0
var channel_noise_intensity: float = 0.0
var channel_noise_clock: float = 0.0
var channel_noise_interval: float = 0.72

var _body_root: Node3D
var _pistol_muzzle: Node3D


func _ready() -> void:
    add_to_group("player_character")
    collision_layer = 1
    collision_mask = 1 | 2 | 4
    current_health = maximum_health
    _build_visuals()
    health_changed.emit(current_health, maximum_health)


func _physics_process(delta: float) -> void:
    pistol_cooldown = maxf(0.0, pistol_cooldown - delta)
    invulnerability_seconds = maxf(0.0, invulnerability_seconds - delta)

    if is_channeling():
        _update_channel(delta)
        velocity.x = move_toward(velocity.x, 0.0, 32.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 32.0 * delta)
        velocity.y = -0.5
        move_and_slide()
        return

    _update_movement(delta)
    _update_automatic_pistol()


func _update_movement(delta: float) -> void:
    var input_vector := Vector2.ZERO
    if input_enabled:
        input_vector.x = _movement_action_strength(&"iw_move_right") - _movement_action_strength(&"iw_move_left")
        input_vector.y = _movement_action_strength(&"iw_move_down") - _movement_action_strength(&"iw_move_up")
    input_vector = input_vector.normalized()

    var target_velocity := Vector3(input_vector.x, 0.0, input_vector.y) * move_speed
    velocity.x = move_toward(velocity.x, target_velocity.x, 28.0 * delta)
    velocity.z = move_toward(velocity.z, target_velocity.z, 28.0 * delta)
    velocity.y = -0.8
    move_and_slide()

    if input_vector.length_squared() > 0.01 and current_target == null:
        rotation.y = lerp_angle(rotation.y, atan2(input_vector.x, input_vector.y), 0.18)


func _update_automatic_pistol() -> void:
    current_target = _nearest_enemy_in_range(pistol_range)
    if current_target == null:
        return
    var target_direction := current_target.global_position - global_position
    target_direction.y = 0.0
    if target_direction.length_squared() > 0.01:
        rotation.y = lerp_angle(rotation.y, atan2(target_direction.x, target_direction.z), 0.28)
    if pistol_cooldown > 0.0:
        return
    pistol_cooldown = pistol_interval
    var origin := _pistol_muzzle.global_position if _pistol_muzzle != null else global_position + Vector3.UP * 1.25
    var impact := current_target.global_position + Vector3.UP * 0.55
    if current_target.has_method("apply_damage"):
        current_target.call("apply_damage", pistol_damage, self)
    pistol_fired.emit(origin, impact, current_target)


func _movement_action_strength(action: StringName) -> float:
    var strength := 0.0
    if InputMap.has_action(action):
        strength = Input.get_action_strength(action)
    return maxf(strength, _keyboard_movement_strength(action))


func _keyboard_movement_strength(action: StringName) -> float:
    match action:
        &"iw_move_left":
            return 1.0 if Input.is_key_pressed(KEY_A) else 0.0
        &"iw_move_right":
            return 1.0 if Input.is_key_pressed(KEY_D) else 0.0
        &"iw_move_up":
            return 1.0 if Input.is_key_pressed(KEY_W) else 0.0
        &"iw_move_down":
            return 1.0 if Input.is_key_pressed(KEY_S) else 0.0
    return 0.0


func _interact_held() -> bool:
    return Input.is_key_pressed(KEY_E) or (InputMap.has_action(&"iw_interact") and Input.is_action_pressed(&"iw_interact"))


func _nearest_enemy_in_range(maximum_range: float) -> Node3D:
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


func begin_channel(
        kind: StringName,
        target: Node,
        duration: float,
        description: String,
        metadata: Dictionary = {},
        requires_hold: bool = false,
        noise_radius: float = 0.0,
        noise_intensity: float = 0.0
    ) -> bool:
    if is_channeling() or duration <= 0.0:
        return false
    channel_kind = kind
    channel_target = target
    channel_duration = duration
    channel_elapsed = 0.0
    channel_description = description
    channel_metadata = metadata.duplicate(true)
    channel_requires_hold = requires_hold
    channel_noise_radius = maxf(0.0, noise_radius)
    channel_noise_intensity = maxf(0.0, noise_intensity)
    channel_noise_clock = channel_noise_interval
    current_target = null
    channel_started.emit(channel_kind, channel_duration, channel_description)
    return true


func cancel_channel() -> void:
    if not is_channeling():
        return
    var old_kind := channel_kind
    var old_target := channel_target
    var old_metadata := channel_metadata.duplicate(true)
    _clear_channel()
    channel_cancelled.emit(old_kind, old_target, old_metadata)


func _update_channel(delta: float) -> void:
    if channel_requires_hold and not _interact_held():
        cancel_channel()
        return
    if channel_target != null and not is_instance_valid(channel_target):
        cancel_channel()
        return

    channel_elapsed += delta
    channel_noise_clock += delta
    if channel_noise_radius > 0.0 and channel_noise_clock >= channel_noise_interval:
        channel_noise_clock = 0.0
        noise_requested.emit(global_position, channel_noise_radius, channel_noise_intensity, channel_kind)

    var progress := clampf(channel_elapsed / channel_duration, 0.0, 1.0)
    channel_progress.emit(channel_kind, progress, channel_description)
    if channel_elapsed < channel_duration:
        return

    var finished_kind := channel_kind
    var finished_target := channel_target
    var finished_metadata := channel_metadata.duplicate(true)
    _clear_channel()
    channel_completed.emit(finished_kind, finished_target, finished_metadata)


func _clear_channel() -> void:
    channel_kind = &""
    channel_target = null
    channel_duration = 0.0
    channel_elapsed = 0.0
    channel_description = ""
    channel_metadata.clear()
    channel_requires_hold = false
    channel_noise_radius = 0.0
    channel_noise_intensity = 0.0
    channel_noise_clock = 0.0


func is_channeling() -> bool:
    return channel_kind != &""


func apply_damage(amount: float, source: Node = null) -> void:
    if amount <= 0.0 or invulnerability_seconds > 0.0 or current_health <= 0.0:
        return
    current_health = maxf(0.0, current_health - amount)
    invulnerability_seconds = 0.16
    if is_channeling():
        cancel_channel()
    health_changed.emit(current_health, maximum_health)
    if current_health <= 0.0:
        died.emit()


func heal_full() -> void:
    current_health = maximum_health
    health_changed.emit(current_health, maximum_health)


func is_alive() -> bool:
    return current_health > 0.0


func _build_visuals() -> void:
    ModelKit3D.add_collision_capsule(self, 0.42, 1.75, Vector3(0.0, 0.88, 0.0))
    var authored_model := AUTHORED_MODEL_SCENE.instantiate() as Node3D
    if authored_model == null:
        push_error("Mechromancer authored glTF could not be instantiated.")
        _body_root = Node3D.new()
        _body_root.name = "MechromancerModel"
        add_child(_body_root)
    else:
        authored_model.name = "MechromancerModel"
        add_child(authored_model)
        _body_root = authored_model
        # Presentation scale is intentionally independent from the gameplay
        # capsule: the authored technician must remain legible at the normal
        # isometric camera distance without changing collision or targeting.
        _body_root.scale = Vector3(1.28, 1.28, 1.28)

    _pistol_muzzle = _find_visual_node(_body_root, &"PistolMuzzle")
    if _pistol_muzzle == null:
        push_error("Mechromancer authored glTF is missing the PistolMuzzle socket.")
        _pistol_muzzle = Marker3D.new()
        _pistol_muzzle.name = "PistolMuzzle"
        _pistol_muzzle.position = Vector3(0.48, 1.12, -0.7)
        _body_root.add_child(_pistol_muzzle)


func _find_visual_node(root: Node, node_name: StringName) -> Node3D:
    if root is Node3D and StringName(root.name) == node_name:
        return root as Node3D
    for child in root.get_children():
        var result := _find_visual_node(child, node_name)
        if result != null:
            return result
    return null
