extends Node

## Actor silhouette polish, authored animation registration and transient VFX.

const MECHROMANCER_PRESENTATION := preload("res://scripts/presentation/mechromancer_presentation_3d.gd")

var world: Node3D
var player: Node3D
var heartforge: Node3D
var camera: Camera3D
var noise_system: Node
var elapsed: float = 0.0
var camera_shake: float = 0.0
var active_channel_kind: StringName = &""
var channel_spark_clock: float = 0.0
var cyan_material: StandardMaterial3D
var warm_material: StandardMaterial3D
var rust_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var organic_material: StandardMaterial3D


func configure(next_world: Node3D, next_player: Node3D, next_heartforge: Node3D, next_camera: Camera3D, next_noise_system: Node) -> void:
    world = next_world
    player = next_player
    heartforge = next_heartforge
    camera = next_camera
    noise_system = next_noise_system


func _ready() -> void:
    cyan_material = ModelKit3D.material(Color("244c52"), 0.38, 0.34, Color("75e4e8"), 2.5)
    warm_material = ModelKit3D.material(Color("7f4b28"), 0.18, 0.58, Color("ff9b43"), 2.8)
    rust_material = ModelKit3D.material(Color("72462e"), 0.46, 0.72)
    dark_material = ModelKit3D.material(Color("20282a"), 0.78, 0.38)
    organic_material = ModelKit3D.material(Color("40282f"), 0.02, 0.78, Color("8e2935"), 0.55)
    _attach_existing_actors()
    get_tree().node_added.connect(_on_node_added)
    _connect_world_feedback()


func _process(delta: float) -> void:
    elapsed += delta
    camera_shake = move_toward(camera_shake, 0.0, delta * 2.8)
    _animate_camera()
    _animate_channel_sparks(delta)


func _attach_existing_actors() -> void:
    for actor in get_tree().get_nodes_in_group(&"player_character"):
        _polish_actor(actor)
    for actor in get_tree().get_nodes_in_group(&"friendly_robots"):
        _polish_actor(actor)
    for actor in get_tree().get_nodes_in_group(&"organic_enemies"):
        _polish_actor(actor)


func _on_node_added(node: Node) -> void:
    if node is Node3D:
        call_deferred("_try_polish_actor", node)


func _try_polish_actor(node: Variant) -> void:
    if not is_instance_valid(node):
        return
    if not (node is Node):
        return
    if node.is_in_group(&"player_character") or node.is_in_group(&"friendly_robots") or node.is_in_group(&"organic_enemies"):
        _polish_actor(node)


func _polish_actor(node: Node) -> void:
    if not (node is Node3D):
        return
    var actor := node as Node3D
    if actor.is_in_group(&"player_character"):
        if actor.get_node_or_null("MechromancerPresentation3D") == null:
            var mechromancer_presentation := MECHROMANCER_PRESENTATION.new()
            mechromancer_presentation.name = "MechromancerPresentation3D"
            mechromancer_presentation.configure(actor)
            actor.add_child(mechromancer_presentation)
    elif actor.get_node_or_null("ProceduralAnimator3D") == null:
        var animator := ProceduralAnimator3D.new()
        animator.name = "ProceduralAnimator3D"
        animator.configure(actor)
        actor.add_child(animator)
    if actor.get_node_or_null("AestheticDetails") == null:
        _add_actor_details(actor)
    _connect_actor_feedback(actor)


func _add_actor_details(actor: Node3D) -> void:
    var model_root := _actor_model_root(actor)
    if model_root == null:
        return
    var details := Node3D.new()
    details.name = "AestheticDetails"
    model_root.add_child(details)
    if actor.is_in_group(&"player_character"):
        _add_player_details(details)
    elif actor.is_in_group(&"friendly_robots"):
        _add_robot_details(actor, details)
    elif actor.is_in_group(&"organic_enemies"):
        _add_enemy_details(actor, details)


func _add_player_details(details: Node3D) -> void:
    var model_root := details.get_parent() as Node3D
    var shoulder_lamp: Node3D
    var warm_lamp: Node3D
    if model_root != null:
        shoulder_lamp = model_root.find_child("ShoulderLamp", true, false) as Node3D
        warm_lamp = model_root.find_child("WarmLamp", true, false) as Node3D
    if shoulder_lamp != null:
        _add_light(shoulder_lamp, Vector3(0.0, 0.0, -0.1), Color("79e4e9"), 0.55, 4.6)
    else:
        push_error("Mechromancer authored model is missing the ShoulderLamp socket.")
    if warm_lamp != null:
        _add_light(warm_lamp, Vector3(0.0, 0.0, -0.05), Color("ff9b52"), 0.18, 2.2)


func _add_robot_details(actor: Node3D, details: Node3D) -> void:
    var archetype := StringName(actor.get(&"archetype")) if _property_exists(actor, &"archetype") else &"salvager"
    ModelKit3D.add_box(details, Vector3(1.1, 0.09, 1.3), Vector3(0.0, 1.47, 0.0), rust_material, Vector3.ZERO, "RaisedArmorPanel")
    for side in [-1.0, 1.0]:
        ModelKit3D.add_cylinder(details, 0.045, 1.05, Vector3(side * 0.62, 1.0, 0.1), cyan_material, Vector3(0.0, 0.0, side * 0.46), "ExposedCable")
    match archetype:
        &"companion", &"guardian":
            ModelKit3D.add_box(details, Vector3(1.75, 0.52, 0.12), Vector3(0.0, 1.05, -0.94), rust_material, Vector3.ZERO, "ProtectiveBrow")
            ModelKit3D.add_sphere(details, 0.11, Vector3(-0.42, 1.34, -0.94), warm_material, Vector3.ONE, "GuardLampLeft")
            ModelKit3D.add_sphere(details, 0.11, Vector3(0.42, 1.34, -0.94), warm_material, Vector3.ONE, "GuardLampRight")
        &"scout":
            ModelKit3D.add_sphere(details, 0.17, Vector3(-0.45, 1.42, -0.68), cyan_material, Vector3(1.2, 0.6, 1.2), "ScoutOptic")
            ModelKit3D.add_sphere(details, 0.17, Vector3(0.45, 1.42, -0.68), cyan_material, Vector3(1.2, 0.6, 1.2), "ScoutOptic")
        _:
            ModelKit3D.add_box(details, Vector3(1.08, 0.58, 0.86), Vector3(0.0, 1.62, 0.35), dark_material, Vector3.ZERO, "ScrapBasket")


func _add_enemy_details(actor: Node3D, details: Node3D) -> void:
    var species := StringName(actor.get(&"species")) if _property_exists(actor, &"species") else &"skitterling"
    var spine_count := 4 if species == &"skitterling" else 6
    for index in range(spine_count):
        var z := -0.55 + float(index) * 0.28
        ModelKit3D.add_capsule(details, 0.045, 0.55 + float(index % 2) * 0.2, Vector3(0.0, 1.18, z), organic_material, Vector3(0.48, 0.0, 0.0), "BackSpine")
    if species == &"veilstalker":
        for side in [-1.0, 1.0]:
            ModelKit3D.add_sphere(details, 0.24, Vector3(side * 1.06, 1.05, -0.15), organic_material, Vector3(0.18, 1.35, 0.72), "VeilstalkerDetailMembrane")
            ModelKit3D.add_capsule(details, 0.035, 0.85, Vector3(side * 0.3, 1.18, -1.55), organic_material, Vector3(0.52, 0.0, side * 0.14), "VeilstalkerDetailTendril")
    else:
        ModelKit3D.add_capsule(details, 0.08, 1.4, Vector3(0.0, 0.72, 1.15), organic_material, Vector3(1.2, 0.0, 0.0), "Tail")


func _connect_world_feedback() -> void:
    if noise_system != null and noise_system.has_signal(&"noise_emitted"):
        _connect_once(noise_system, &"noise_emitted", Callable(self, "_on_noise_emitted"))
    if player != null:
        _connect_once(player, &"channel_started", Callable(self, "_on_channel_started"))
        _connect_once(player, &"channel_completed", Callable(self, "_on_channel_finished"))
        _connect_once(player, &"channel_cancelled", Callable(self, "_on_channel_finished"))
        _connect_once(player, &"health_changed", Callable(self, "_on_player_health_changed"))
    if heartforge != null:
        _connect_once(heartforge, &"health_changed", Callable(self, "_on_heartforge_health_changed"))


func _connect_actor_feedback(actor: Node3D) -> void:
    _connect_once(actor, &"pistol_fired", Callable(self, "_on_weapon_fired"))
    _connect_once(actor, &"weapon_fired", Callable(self, "_on_weapon_fired"))
    _connect_once(actor, &"attack_started", Callable(self, "_on_attack_started"))
    _connect_once(actor, &"killed", Callable(self, "_on_enemy_killed"))


func _connect_once(source: Object, signal_name: StringName, callback: Callable) -> void:
    if source.has_signal(signal_name) and not source.is_connected(signal_name, callback):
        source.connect(signal_name, callback)


func _on_weapon_fired(origin: Vector3, target: Vector3, target_node: Node) -> void:
    var friendly := target_node != null and target_node.is_in_group(&"organic_enemies")
    var color := Color("7ae8ed") if friendly else Color("ff9a50")
    _spawn_flash(origin, color, 2.3, 4.5, 0.08)
    _spawn_burst(target, color, 9, 1.6, Vector3(0.0, -2.2, 0.0), 0.42)
    camera_shake = maxf(camera_shake, 0.12)


func _on_attack_started(enemy: Node, target: Node) -> void:
    if not enemy is Node3D or not target is Node3D:
        return
    var attacker := enemy as Node3D
    var victim := target as Node3D
    var radius := 0.9
    if enemy.get("attack_range") != null:
        radius = maxf(0.72, float(enemy.get("attack_range")) * 0.72)
    var warning_position := victim.global_position + Vector3(0.0, 0.045, 0.0)
    _spawn_attack_telegraph(warning_position, radius)
    _spawn_flash(attacker.global_position + Vector3.UP * 0.7, Color("d14b55"), 0.55, 3.8, 0.12)
    camera_shake = maxf(camera_shake, 0.035)


func _on_enemy_killed(enemy: Node, _killer: Node) -> void:
    if enemy is Node3D:
        var position := (enemy as Node3D).global_position + Vector3.UP * 0.5
        _spawn_burst(position, Color("b13d45"), 22, 2.8, Vector3(0.0, -4.0, 0.0), 0.9)
        _spawn_flash(position, Color("9b2635"), 1.2, 5.0, 0.16)
        camera_shake = maxf(camera_shake, 0.22)


func _on_noise_emitted(position: Vector3, radius: float, intensity: float, source_kind: StringName) -> void:
    var dangerous := source_kind in [&"manual_salvage", &"forge_build", &"forge_upgrade"]
    var color := Color("ff9b50") if dangerous else Color("71dce2")
    _spawn_noise_ring(position, radius, color, intensity)
    if dangerous:
        _spawn_burst(position + Vector3.UP * 0.7, Color("ffad55"), 14, 2.1, Vector3(0.0, -3.2, 0.0), 0.62)
        camera_shake = maxf(camera_shake, 0.14 * intensity)


func _on_channel_started(kind: StringName, _duration: float, _description: String) -> void:
    active_channel_kind = kind
    channel_spark_clock = 0.0


func _on_channel_finished(_kind: StringName, _target: Node, _metadata: Dictionary) -> void:
    active_channel_kind = &""
    channel_spark_clock = 0.0


func _on_player_health_changed(current: float, maximum: float) -> void:
    if maximum <= 0.0:
        return
    var ratio := current / maximum
    camera_shake = maxf(camera_shake, lerpf(0.42, 0.12, ratio))
    var hud := get_tree().get_first_node_in_group(&"beautiful_hud")
    if hud != null and hud.has_method(&"flash_damage"):
        hud.call(&"flash_damage", 1.0 - ratio)


func _on_heartforge_health_changed(current: float, maximum: float) -> void:
    var hud := get_tree().get_first_node_in_group(&"beautiful_hud")
    if hud != null and hud.has_method(&"set_sanctuary_integrity"):
        hud.call(&"set_sanctuary_integrity", clampf(current / maxf(1.0, maximum), 0.0, 1.0))


func _animate_channel_sparks(delta: float) -> void:
    if active_channel_kind == &"" or player == null:
        return
    channel_spark_clock += delta
    if channel_spark_clock < 0.16:
        return
    channel_spark_clock = 0.0
    var color := Color("74e1e7") if active_channel_kind == &"manual_salvage" else Color("ffad54")
    _spawn_burst(player.global_position + Vector3(0.0, 0.85, -0.55), color, 4, 1.4, Vector3(0.0, -2.8, 0.0), 0.32)


func _animate_camera() -> void:
    if camera == null:
        return
    if camera_shake <= 0.001:
        camera.h_offset = move_toward(camera.h_offset, 0.0, 0.08)
        camera.v_offset = move_toward(camera.v_offset, 0.0, 0.08)
        return
    camera.h_offset = sin(elapsed * 39.0) * camera_shake * 0.16
    camera.v_offset = cos(elapsed * 47.0) * camera_shake * 0.11


func _spawn_flash(position: Vector3, color: Color, energy: float, light_range: float, lifetime: float) -> void:
    if world == null:
        return
    var light := OmniLight3D.new()
    light.light_color = color
    light.light_energy = energy
    light.omni_range = light_range
    world.add_child(light)
    light.position = position
    var tween := light.create_tween()
    tween.tween_property(light, "light_energy", 0.0, lifetime)
    tween.tween_callback(light.queue_free)


func _spawn_attack_telegraph(position: Vector3, radius: float) -> void:
    if world == null:
        return
    var telegraph := MeshInstance3D.new()
    telegraph.name = "OrganicAttackTelegraph"
    var mesh := CylinderMesh.new()
    mesh.top_radius = 1.0
    mesh.bottom_radius = 1.0
    mesh.height = 0.018
    mesh.radial_segments = 32
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.78, 0.12, 0.2, 0.34)
    material.emission_enabled = true
    material.emission = Color("8f2636")
    material.emission_energy_multiplier = 1.3
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mesh.material = material
    telegraph.mesh = mesh
    telegraph.position = position
    telegraph.scale = Vector3(radius * 0.68, 1.0, radius * 0.68)
    world.add_child(telegraph)
    var tween := telegraph.create_tween().set_parallel(true)
    tween.tween_property(telegraph, "scale", Vector3(radius, 1.0, radius), 0.24)
    tween.tween_property(material, "albedo_color", Color(0.78, 0.12, 0.2, 0.0), 0.24)
    tween.chain().tween_callback(telegraph.queue_free)


func _spawn_burst(position: Vector3, color: Color, amount: int, speed: float, gravity: Vector3, lifetime: float) -> void:
    if world == null:
        return
    var particles := CPUParticles3D.new()
    particles.name = "TransientBurst"
    particles.position = position
    particles.amount = amount
    particles.lifetime = lifetime
    particles.one_shot = true
    particles.explosiveness = 1.0
    particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    particles.emission_sphere_radius = 0.12
    particles.direction = Vector3.UP
    particles.spread = 180.0
    particles.gravity = gravity
    particles.initial_velocity_min = speed * 0.45
    particles.initial_velocity_max = speed
    particles.scale_amount_min = 0.035
    particles.scale_amount_max = 0.105
    particles.color = color
    particles.mesh = _particle_mesh(color, Vector2(0.07, 0.07))
    world.add_child(particles)
    particles.emitting = true
    get_tree().create_timer(lifetime + 0.2).timeout.connect(particles.queue_free)


func _spawn_noise_ring(position: Vector3, radius: float, color: Color, intensity: float) -> void:
    if world == null:
        return
    var mesh := TorusMesh.new()
    mesh.inner_radius = 0.94
    mesh.outer_radius = 1.0
    mesh.rings = 12
    mesh.ring_segments = 32
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(color.r, color.g, color.b, 0.5)
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = 1.5
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var ring := MeshInstance3D.new()
    ring.name = "NoisePulse"
    ring.mesh = mesh
    ring.material_override = material
    ring.scale = Vector3.ONE * 0.3
    ring.transparency = 0.18
    world.add_child(ring)
    ring.position = position + Vector3.UP * 0.08
    var duration := 0.75 + intensity * 0.25
    var tween := ring.create_tween().set_parallel(true)
    tween.tween_property(ring, "scale", Vector3.ONE * maxf(2.0, radius), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(ring, "transparency", 1.0, duration)
    tween.chain().tween_callback(ring.queue_free)


func _particle_mesh(color: Color, size: Vector2) -> QuadMesh:
    var mesh := QuadMesh.new()
    mesh.size = size
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo = true
    mesh.material = material
    return mesh


func _add_light(parent: Node3D, position: Vector3, color: Color, energy: float, light_range: float) -> void:
    var light := OmniLight3D.new()
    light.position = position
    light.light_color = color
    light.light_energy = energy
    light.omni_range = light_range
    parent.add_child(light)


func _actor_model_root(actor: Node3D) -> Node3D:
    for model_name in ["MechromancerModel", "RobotModel", "OrganicModel"]:
        var candidate := actor.get_node_or_null(NodePath(model_name)) as Node3D
        if candidate != null:
            return candidate
    return null


func _property_exists(object: Object, property_name: StringName) -> bool:
    for property in object.get_property_list():
        if StringName(property.get("name", "")) == property_name:
            return true
    return false
