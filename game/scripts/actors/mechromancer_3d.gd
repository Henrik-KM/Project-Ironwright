class_name Mechromancer3D
extends CharacterBody3D

const AUTHORED_MODEL_SCENE: PackedScene = preload("res://assets/mechromancer/mechromancer.gltf")
const DEATH_PRESENTATION_SECONDS := 0.9

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
var death_presentation_remaining: float = 0.0
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
var _death_visual_root: Node3D
var _death_signal_material: StandardMaterial3D
var _progression_visual_root: Node3D
var _progression_visual_signature: String = ""


func _ready() -> void:
    add_to_group("player_character")
    collision_layer = 1
    collision_mask = 1 | 2 | 4
    current_health = maximum_health
    _build_visuals()
    health_changed.emit(current_health, maximum_health)


func _physics_process(delta: float) -> void:
    if current_health <= 0.0:
        death_presentation_remaining = maxf(0.0, death_presentation_remaining - delta)
        _refresh_death_presentation()
        return
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
    if InputMap.has_action(action):
        for event in InputMap.action_get_events(action):
            if event is InputEventKey and Input.is_key_pressed((event as InputEventKey).keycode):
                return 1.0
        return 0.0
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
    if InputMap.has_action(&"iw_interact"):
        return Input.is_action_pressed(&"iw_interact")
    return Input.is_key_pressed(KEY_E)


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
        death_presentation_remaining = DEATH_PRESENTATION_SECONDS
        _refresh_death_presentation()
        died.emit()


func heal_full() -> void:
    current_health = maximum_health
    death_presentation_remaining = 0.0
    _refresh_death_presentation()
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
    _build_death_presentation()


func apply_progression_visuals(unlocked_effects: Dictionary, heartforge_tier: int) -> void:
    # The Mechromancer is the player's visible measure of the machine society's
    # growth. Keep this as a small, derived presentation layer: it must survive
    # save/load through the progression state without changing the gameplay
    # capsule, targeting silhouette, sockets or routine player workload.
    if _body_root == null or not is_instance_valid(_body_root):
        return
    var active_effect_names := PackedStringArray()
    for raw_effect in unlocked_effects.keys():
        if bool(unlocked_effects.get(raw_effect, false)):
            active_effect_names.append(str(raw_effect))
    active_effect_names.sort()
    var signature := "%d|%s" % [clampi(heartforge_tier, 1, 5), ",".join(active_effect_names)]
    if signature == _progression_visual_signature:
        return
    _progression_visual_signature = signature
    if _progression_visual_root != null and is_instance_valid(_progression_visual_root):
        # This layer is entirely derived and owns no active gameplay state;
        # free it synchronously so a rebuild cannot be silently renamed by a
        # still-queued previous layer.
        _progression_visual_root.free()
    _progression_visual_root = Node3D.new()
    _progression_visual_root.name = "MechromancerProgressionVisuals"
    # Keep the derived layer on the gameplay actor rather than inside the
    # imported glTF scene. This avoids import-owned child-name rewriting and
    # keeps the layer's presentation scale explicit and reviewable.
    _progression_visual_root.scale = Vector3.ONE * 1.28
    add_child(_progression_visual_root)

    var tier := clampi(heartforge_tier, 1, 5)
    if tier < 2:
        return

    var dark_steel := ModelKit3D.material(Color("27343a"), 0.76, 0.3)
    var worn_steel := ModelKit3D.material(Color("6b6253"), 0.68, 0.42)
    var signal_cyan := ModelKit3D.material(Color("6baeb1"), 0.42, 0.3, Color("73e5e3"), 2.1)
    var forge_amber := ModelKit3D.material(Color("a06a36"), 0.58, 0.34, Color("ffb35b"), 1.7)
    var bio_violet := ModelKit3D.material(Color("765a72"), 0.34, 0.44, Color("d58cbf"), 1.1)

    # Tier II is a practical field retrofit: a shoulder brace and tool-coupler
    # make the first Heartforge evolution visible without turning the human
    # engineer into a robot mannequin.
    ModelKit3D.add_beveled_box(
        _progression_visual_root,
        Vector3(0.3, 0.08, 0.24),
        Vector3(0.43, -0.26, 1.66),
        worn_steel,
        Vector3(0.0, 0.0, -0.08),
        "MechromancerTierIIShoulderBrace",
        0.16
    )
    ModelKit3D.add_surface_panel(
        _progression_visual_root,
        Vector3(0.24, 0.09, 0.22),
        Vector3(-0.42, -0.31, 1.34),
        dark_steel,
        signal_cyan,
        Vector3(0.0, 0.0, 0.12),
        "MechromancerTierIIToolCoupler"
    )
    ModelKit3D.add_cylinder(
        _progression_visual_root,
        0.035,
        0.28,
        Vector3(-0.43, -0.24, 1.52),
        signal_cyan,
        Vector3(PI * 0.5, 0.0, 0.0),
        "MechromancerTierIISignalPin"
    )

    if tier >= 3 or unlocked_effects.has(&"unlock_machine_society"):
        # Tier III adds a protected cognition rail and paired cable guides. The
        # asymmetry keeps the field-kit identity readable from the rear camera.
        ModelKit3D.add_beveled_box(
            _progression_visual_root,
            Vector3(0.16, 0.08, 0.48),
            Vector3(-0.25, 0.55, 1.46),
            dark_steel,
            Vector3(0.0, 0.08, 0.0),
            "MechromancerTierIIICognitionRail",
            0.18
        )
        for side in [-1.0, 1.0]:
            ModelKit3D.add_tapered_cylinder(
                _progression_visual_root,
                0.022,
                0.032,
                0.42,
                Vector3(-0.25 + side * 0.1, 0.5, 1.36),
                forge_amber if side < 0.0 else signal_cyan,
                Vector3(0.18, 0.0, side * 0.22),
                "MechromancerTierIIICableGuide%s" % ("Left" if side < 0.0 else "Right")
            )
        ModelKit3D.add_sphere(
            _progression_visual_root,
            0.045,
            Vector3(-0.25, 0.49, 1.74),
            signal_cyan,
            Vector3(1.0, 0.72, 0.72),
            "MechromancerTierIIICognitionNode"
        )

    if tier >= 4 or unlocked_effects.has(&"unlock_adaptive_defence"):
        # Tier IV is a small biological-signal reader, not a new weapon: it
        # communicates the adaptive sensor fantasy at shoulder distance.
        ModelKit3D.add_beveled_box(
            _progression_visual_root,
            Vector3(0.2, 0.07, 0.3),
            Vector3(0.28, -0.3, 1.8),
            bio_violet,
            Vector3(-0.18, 0.0, 0.08),
            "MechromancerTierIVBioSensorHousing",
            0.2
        )
        ModelKit3D.add_sphere(
            _progression_visual_root,
            0.055,
            Vector3(0.28, -0.35, 1.8),
            bio_violet,
            Vector3(1.2, 0.42, 0.8),
            "MechromancerTierIVBioSensorLens"
        )

    if tier >= 5 or unlocked_effects.has(&"unlock_final_protocol_research"):
        # Tier V closes the arc with a restrained protocol clasp and heat vent;
        # the silhouette remains a vulnerable human carrying more responsibility.
        ModelKit3D.add_beveled_box(
            _progression_visual_root,
            Vector3(0.22, 0.07, 0.2),
            Vector3(0.0, -0.35, 1.52),
            forge_amber,
            Vector3(0.0, 0.0, 0.0),
            "MechromancerTierVProtocolClasp",
            0.18
        )
        ModelKit3D.add_louvered_panel(
            _progression_visual_root,
            Vector3(0.18, 0.12, 0.06),
            Vector3(0.18, 0.5, 1.47),
            dark_steel,
            forge_amber,
            Vector3(0.0, 0.0, -0.12),
            "MechromancerTierVHeatVent",
            3
        )


func _build_death_presentation() -> void:
    if _death_visual_root != null and is_instance_valid(_death_visual_root):
        _death_visual_root.free()
    _death_visual_root = Node3D.new()
    _death_visual_root.name = "MechromancerDeathPresentation"
    add_child(_death_visual_root)

    var dead_coat := ModelKit3D.material(Color("20282d"), 0.08, 0.9)
    var dead_leather := ModelKit3D.material(Color("3d2b2a"), 0.18, 0.82)
    var dead_metal := ModelKit3D.material(Color("4b5354"), 0.58, 0.58)
    _death_signal_material = ModelKit3D.material(Color("4e2025"), 0.1, 0.46, Color("e05248"), 1.6)
    var spent_glow := _death_signal_material

    ModelKit3D.add_beveled_box(
        _death_visual_root,
        Vector3(0.62, 0.14, 0.32),
        Vector3(0.0, 0.9, -0.12),
        dead_coat,
        Vector3(0.12, 0.0, -0.16),
        "MechromancerDeathCollapsedTorso",
        0.1
    )
    ModelKit3D.add_organic_plate(
        _death_visual_root,
        0.11,
        Vector3(0.0, 1.08, -0.26),
        dead_leather,
        dead_metal,
        Vector3(0.42, 0.16, 0.18),
        "MechromancerDeathRespiratorCollar"
    )
    ModelKit3D.add_beveled_box(
        _death_visual_root,
        Vector3(0.42, 0.1, 0.24),
        Vector3(-0.34, 0.66, 0.12),
        dead_leather,
        Vector3(0.08, 0.0, -0.3),
        "MechromancerDeathFieldPack",
        0.08
    )
    for side in [-1.0, 1.0]:
        ModelKit3D.add_capsule(
            _death_visual_root,
            0.035,
            0.52,
            Vector3(side * 0.26, 0.52, -0.02),
            dead_metal,
            Vector3(0.32, 0.0, side * 0.24),
            "MechromancerDeathLeg%s" % ("Left" if side < 0.0 else "Right")
        )
    ModelKit3D.add_sphere(
        _death_visual_root,
        0.08,
        Vector3(0.0, 1.08, -0.42),
        spent_glow,
        Vector3(1.15, 0.72, 0.72),
        "MechromancerDeathSignal"
    )
    for index in range(2):
        ModelKit3D.add_beveled_box(
            _death_visual_root,
            Vector3(0.1, 0.06, 0.24),
            Vector3(-0.34 + float(index) * 0.68, 0.84, -0.34),
            dead_metal,
            Vector3(0.0, 0.0, -0.32 + float(index) * 0.64),
            "MechromancerDeathShard%02d" % index,
            0.03
        )
    _refresh_death_presentation()


func _refresh_death_presentation() -> void:
    if _death_visual_root == null or not is_instance_valid(_death_visual_root):
        return
    var active := current_health <= 0.0 and death_presentation_remaining > 0.0
    _death_visual_root.visible = active
    if not active:
        return
    var progress := clampf(death_presentation_remaining / DEATH_PRESENTATION_SECONDS, 0.0, 1.0)
    _death_visual_root.scale = Vector3(1.0, 0.68 + progress * 0.32, 1.0)
    _death_visual_root.rotation.z = (1.0 - progress) * -0.2
    if _death_signal_material != null:
        _death_signal_material.emission_energy_multiplier = lerpf(0.16, 1.8, progress)
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
