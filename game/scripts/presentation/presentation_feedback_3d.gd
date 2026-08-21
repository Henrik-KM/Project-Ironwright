extends Node

## Actor silhouette polish, authored animation registration and transient VFX.

const MECHROMANCER_PRESENTATION := preload("res://scripts/presentation/mechromancer_presentation_3d.gd")

var world: Node3D
var player: Node3D
var heartforge: Node3D
var camera: Camera3D
var noise_system: Node
var settings_service: ReleaseSettingsService3D
var elapsed: float = 0.0
var camera_shake: float = 0.0
var active_channel_kind: StringName = &""
var channel_spark_clock: float = 0.0
var cyan_material: StandardMaterial3D
var warm_material: StandardMaterial3D
var rust_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var organic_material: StandardMaterial3D
var channel_field: Node3D
var channel_field_material: StandardMaterial3D
var channel_field_color: Color = Color.WHITE
var labor_signatures: Dictionary = {}
var last_actor_health: Dictionary = {}
var last_player_health: float = -1.0
var construction_signature: Node3D


func configure(next_world: Node3D, next_player: Node3D, next_heartforge: Node3D, next_camera: Camera3D, next_noise_system: Node) -> void:
    world = next_world
    player = next_player
    heartforge = next_heartforge
    camera = next_camera
    noise_system = next_noise_system


func active_labor_signature_count() -> int:
    return labor_signatures.size()


func active_construction_signature_count() -> int:
    return 1 if construction_signature != null and is_instance_valid(construction_signature) else 0


func _ready() -> void:
    cyan_material = ModelKit3D.material(Color("244c52"), 0.38, 0.34, Color("75e4e8"), 2.5)
    warm_material = ModelKit3D.material(Color("7f4b28"), 0.18, 0.58, Color("ff9b43"), 2.8)
    rust_material = ModelKit3D.material(Color("72462e"), 0.46, 0.72)
    dark_material = ModelKit3D.material(Color("20282a"), 0.78, 0.38)
    organic_material = ModelKit3D.material(Color("40282f"), 0.02, 0.78, Color("8e2935"), 0.55)
    _resolve_settings_service()
    call_deferred("_resolve_settings_service")
    _attach_existing_actors()
    get_tree().node_added.connect(_on_node_added)
    _connect_world_feedback()


func _process(delta: float) -> void:
    if settings_service == null or not is_instance_valid(settings_service):
        _resolve_settings_service()
    elapsed += delta
    camera_shake = move_toward(camera_shake, 0.0, delta * 2.8)
    _animate_camera()
    _animate_channel_sparks(delta)
    _refresh_autonomous_labor_signatures(delta)
    _refresh_autonomous_construction_signature(delta)


func accessibility_snapshot() -> Dictionary:
    _resolve_settings_service()
    return {
        "settings_resolved": settings_service != null and is_instance_valid(settings_service),
        "reduced_flashes": _reduced_flashes_enabled(),
        "reduced_motion": _reduced_motion_enabled(),
        "camera_shake_scale": _camera_shake_scale(),
    }


func _resolve_settings_service() -> void:
    if settings_service != null and is_instance_valid(settings_service):
        return
    settings_service = get_tree().get_first_node_in_group(&"release_settings_service") as ReleaseSettingsService3D


func _reduced_flashes_enabled() -> bool:
    return settings_service != null and bool(settings_service.get_value(&"reduced_flashes", false))


func _reduced_motion_enabled() -> bool:
    return settings_service != null and bool(settings_service.get_value(&"reduced_motion", false))


func _camera_shake_scale() -> float:
    if _reduced_motion_enabled():
        return 0.0
    if settings_service == null:
        return 1.0
    return clampf(float(settings_service.get_value(&"camera_shake", 0.65)), 0.0, 1.0)


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
    else:
        if actor.get_node_or_null("ProceduralAnimator3D") == null:
            var animator := ProceduralAnimator3D.new()
            animator.name = "ProceduralAnimator3D"
            animator.configure(actor)
            actor.add_child(animator)
        if actor.get_node_or_null("AuthoredActorAnimation3D") == null:
            var authored_animation := AuthoredActorAnimation3D.new()
            authored_animation.name = "AuthoredActorAnimation3D"
            authored_animation.configure(actor)
            actor.add_child(authored_animation)
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
        if _property_exists(player, &"current_health"):
            last_player_health = float(player.get(&"current_health"))
    if heartforge != null:
        _connect_once(heartforge, &"health_changed", Callable(self, "_on_heartforge_health_changed"))


func _connect_actor_feedback(actor: Node3D) -> void:
    _connect_once(actor, &"pistol_fired", Callable(self, "_on_weapon_fired"))
    _connect_once(actor, &"weapon_fired", Callable(self, "_on_weapon_fired"))
    _connect_once(actor, &"attack_started", Callable(self, "_on_attack_started"))
    _connect_once(actor, &"attack_landed", Callable(self, "_on_attack_landed"))
    _connect_once(actor, &"killed", Callable(self, "_on_enemy_killed"))
    _connect_once(actor, &"destroyed", Callable(self, "_on_actor_destroyed"))
    if not actor.is_in_group(&"player_character"):
        _connect_once(actor, &"health_changed", Callable(self, "_on_actor_health_changed"))
        if _property_exists(actor, &"current_health"):
            last_actor_health[actor.get_instance_id()] = float(actor.get(&"current_health"))


func _connect_once(source: Object, signal_name: StringName, callback: Callable) -> void:
    if source.has_signal(signal_name) and not source.is_connected(signal_name, callback):
        source.connect(signal_name, callback)


func _on_weapon_fired(origin: Vector3, target: Vector3, target_node: Node) -> void:
    var friendly := target_node != null and target_node.is_in_group(&"organic_enemies")
    var color := Color("7ae8ed") if friendly else Color("ff9a50")
    _spawn_weapon_tracer(origin, target, color)
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


func _on_attack_landed(enemy: Node, target: Node) -> void:
    if not enemy is Node3D or not target is Node3D:
        return
    var attacker := enemy as Node3D
    var victim := target as Node3D
    var impact_position := (attacker.global_position + victim.global_position) * 0.5 + Vector3.UP * 0.45
    _spawn_burst(impact_position, Color("e65a4f"), 16, 2.5, Vector3(0.0, -3.8, 0.0), 0.46, "OrganicAttackImpact")
    _spawn_flash(impact_position, Color("ed654f"), 0.9, 4.2, 0.1)
    camera_shake = maxf(camera_shake, 0.11)


func _on_actor_health_changed(actor: Node, current: float, _maximum: float) -> void:
    if not actor is Node3D:
        return
    var actor_id := actor.get_instance_id()
    var previous := float(last_actor_health.get(actor_id, current))
    last_actor_health[actor_id] = current
    if current <= 0.0 or current >= previous:
        return
    var friendly := actor.is_in_group(&"friendly_robots")
    var position := (actor as Node3D).global_position + Vector3.UP * (0.82 if friendly else 0.66)
    var color := Color("74e1e7") if friendly else Color("f06a58")
    var burst_amount := 11 if friendly else 14
    _spawn_burst(position, color, burst_amount, 2.1 if friendly else 2.5, Vector3(0.0, -3.2, 0.0), 0.42, "ActorImpactResponse")
    _spawn_flash(position, color, 0.8 if friendly else 0.95, 3.2 if friendly else 3.8, 0.09)
    camera_shake = maxf(camera_shake, 0.06 if friendly else 0.075)


func _on_enemy_killed(enemy: Node, _killer: Node) -> void:
    if enemy != null:
        last_actor_health.erase(enemy.get_instance_id())
    if enemy is Node3D:
        var position := (enemy as Node3D).global_position + Vector3.UP * 0.5
        _spawn_burst(position, Color("b13d45"), 22, 2.8, Vector3(0.0, -4.0, 0.0), 0.9)
        _spawn_flash(position, Color("9b2635"), 1.2, 5.0, 0.16)
        camera_shake = maxf(camera_shake, 0.22)


func _on_actor_destroyed(actor: Node) -> void:
    if actor != null:
        last_actor_health.erase(actor.get_instance_id())


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
    _spawn_channel_field(kind)


func _on_channel_finished(_kind: StringName, _target: Node, _metadata: Dictionary) -> void:
    active_channel_kind = &""
    channel_spark_clock = 0.0
    if channel_field != null and is_instance_valid(channel_field):
        var finishing_field := channel_field
        channel_field = null
        var fade := finishing_field.create_tween()
        fade.tween_property(finishing_field, "scale", Vector3.ONE * 1.28, 0.18)
        fade.tween_callback(finishing_field.queue_free)


func _on_player_health_changed(current: float, maximum: float) -> void:
    if maximum <= 0.0:
        return
    var previous := last_player_health
    last_player_health = current
    var ratio := current / maximum
    camera_shake = maxf(camera_shake, lerpf(0.42, 0.12, ratio))
    if previous >= 0.0 and current < previous and current > 0.0 and player != null:
        var impact_position := player.global_position + Vector3.UP * 1.1
        _spawn_burst(impact_position, Color("ffb05e"), 12, 2.2, Vector3(0.0, -3.8, 0.0), 0.45, "PlayerImpactResponse")
        _spawn_flash(impact_position, Color("ff8c4e"), 1.1, 4.0, 0.1)
    var hud := get_tree().get_first_node_in_group(&"beautiful_hud")
    if not _reduced_flashes_enabled() and hud != null and hud.has_method(&"flash_damage"):
        hud.call(&"flash_damage", 1.0 - ratio)


func _on_heartforge_health_changed(current: float, maximum: float) -> void:
    var hud := get_tree().get_first_node_in_group(&"beautiful_hud")
    if hud != null and hud.has_method(&"set_sanctuary_integrity"):
        hud.call(&"set_sanctuary_integrity", clampf(current / maxf(1.0, maximum), 0.0, 1.0))


func _animate_channel_sparks(delta: float) -> void:
    if active_channel_kind == &"" or player == null:
        return
    if channel_field != null and is_instance_valid(channel_field):
        channel_field.global_position = player.global_position + Vector3(0.0, 0.04, 0.0)
        channel_field.rotation.y += delta * (1.6 if active_channel_kind == &"manual_salvage" else 2.4)
        channel_field.scale = Vector3.ONE * (1.0 + sin(elapsed * 4.0) * 0.035)
    channel_spark_clock += delta
    if channel_spark_clock < 0.16:
        return
    channel_spark_clock = 0.0
    var color := Color("74e1e7") if active_channel_kind == &"manual_salvage" else Color("ffad54")
    _spawn_burst(player.global_position + Vector3(0.0, 0.85, -0.55), color, 4, 1.4, Vector3(0.0, -2.8, 0.0), 0.32)


func _refresh_autonomous_labor_signatures(delta: float) -> void:
    if world == null:
        return
    var active_keys: Dictionary = {}
    for raw_robot in get_tree().get_nodes_in_group(&"friendly_robots"):
        var robot := raw_robot as RobotUnit3D
        if robot == null or not is_instance_valid(robot) or robot.salvage_target == null:
            continue
        var target := robot.salvage_target as Node3D
        if target == null or not is_instance_valid(target) or robot.state_name != &"salvaging":
            continue
        var key := str(robot.get_instance_id())
        active_keys[key] = true
        var signature: Node3D = labor_signatures.get(key) as Node3D
        if signature == null or not is_instance_valid(signature):
            signature = _create_labor_signature(key)
            labor_signatures[key] = signature
        _update_labor_signature(signature, robot, target, delta)
    for raw_key in labor_signatures.keys():
        var key := str(raw_key)
        if active_keys.has(key):
            continue
        var stale_signature := labor_signatures[raw_key] as Node3D
        if stale_signature != null and is_instance_valid(stale_signature):
            stale_signature.queue_free()
        labor_signatures.erase(raw_key)


func _create_labor_signature(key: String) -> Node3D:
    var signature := Node3D.new()
    signature.name = "AutonomousLaborSignature_%s" % key
    world.add_child(signature)

    var ring := MeshInstance3D.new()
    ring.name = "LaborTargetRing"
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.72
    ring_mesh.outer_radius = 0.78
    ring_mesh.rings = 16
    ring_mesh.ring_segments = 32
    ring.mesh = ring_mesh
    ring.material_override = _vfx_material(Color("ffad55"), 0.62, 2.4)
    ring.position.y = 0.08
    signature.add_child(ring)

    var core := MeshInstance3D.new()
    core.name = "LaborWorkCore"
    var core_mesh := CylinderMesh.new()
    core_mesh.top_radius = 0.055
    core_mesh.bottom_radius = 0.12
    core_mesh.height = 0.72
    core_mesh.radial_segments = 12
    core.mesh = core_mesh
    core.material_override = _vfx_material(Color("ffd08a"), 0.72, 3.2)
    core.position.y = 0.42
    signature.add_child(core)

    var link := MeshInstance3D.new()
    link.name = "LaborMachineLink"
    var link_mesh := CylinderMesh.new()
    link_mesh.top_radius = 0.018
    link_mesh.bottom_radius = 0.035
    link_mesh.height = 1.0
    link_mesh.radial_segments = 8
    link.mesh = link_mesh
    link.material_override = _vfx_material(Color("ff9b50"), 0.46, 1.8)
    signature.add_child(link)
    return signature


func _update_labor_signature(signature: Node3D, robot: RobotUnit3D, target: Node3D, delta: float) -> void:
    var target_position := target.global_position + Vector3.UP * 0.08
    var robot_position := robot.global_position + Vector3.UP * 0.82
    signature.global_position = target_position
    var ring := signature.get_node_or_null("LaborTargetRing") as MeshInstance3D
    if ring != null:
        ring.rotation.y += delta * 2.4
        var pulse := 1.0 + sin(elapsed * 5.0) * 0.08
        ring.scale = Vector3.ONE * pulse
    var core := signature.get_node_or_null("LaborWorkCore") as MeshInstance3D
    if core != null:
        core.rotation.y -= delta * 1.8
        core.position.y = 0.42 + sin(elapsed * 4.2) * 0.08
    var link := signature.get_node_or_null("LaborMachineLink") as MeshInstance3D
    if link == null:
        return
    var direction := robot_position - target_position
    var distance := direction.length()
    link.position = direction * 0.5
    link.scale = Vector3(1.0, maxf(0.15, distance), 1.0)
    if distance > 0.01:
        link.quaternion = Quaternion(Vector3.UP, direction.normalized())


func _refresh_autonomous_construction_signature(delta: float) -> void:
    if world == null:
        _clear_construction_signature()
        return
    var outpost_director := world.get_node_or_null("OutpostDirector") as Node
    if outpost_director == null:
        _clear_construction_signature()
        return
    var operation_variant: Variant = outpost_director.get("operation")
    if not (operation_variant is Dictionary):
        _clear_construction_signature()
        return
    var operation := operation_variant as Dictionary
    var kind := StringName(str(operation.get("kind", "")))
    var state := StringName(str(operation.get("state", "")))
    if state != &"working" or kind not in [&"build", &"upgrade", &"rebuild"]:
        _clear_construction_signature()
        return
    var site := operation.get("site") as Node3D
    if site == null or not is_instance_valid(site):
        _clear_construction_signature()
        return
    if construction_signature == null or not is_instance_valid(construction_signature):
        construction_signature = _create_construction_signature(kind)
    var members_variant: Variant = operation.get("members", [])
    var members: Array = members_variant as Array if members_variant is Array else []
    _update_construction_signature(construction_signature, site, members, kind, delta)


func _clear_construction_signature() -> void:
    if construction_signature != null and is_instance_valid(construction_signature):
        construction_signature.queue_free()
    construction_signature = null


func _create_construction_signature(kind: StringName) -> Node3D:
    var signature := Node3D.new()
    signature.name = "AutonomousConstructionSignature"
    world.add_child(signature)
    var color := Color("66d7dd") if kind == &"upgrade" else Color("ffad55")
    var ring := MeshInstance3D.new()
    ring.name = "ConstructionTargetRing"
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 1.14
    ring_mesh.outer_radius = 1.22
    ring_mesh.rings = 18
    ring_mesh.ring_segments = 40
    ring.mesh = ring_mesh
    ring.material_override = _vfx_material(color, 0.58, 2.1)
    ring.position.y = 0.3
    signature.add_child(ring)

    var core := MeshInstance3D.new()
    core.name = "ConstructionWorkCore"
    var core_mesh := CylinderMesh.new()
    core_mesh.top_radius = 0.07
    core_mesh.bottom_radius = 0.16
    core_mesh.height = 0.9
    core_mesh.radial_segments = 14
    core.mesh = core_mesh
    core.material_override = _vfx_material(color.lightened(0.12), 0.72, 2.8)
    core.position.y = 0.74
    signature.add_child(core)

    for index in range(4):
        var angle := TAU * float(index) / 4.0 + 0.25
        var pylon := MeshInstance3D.new()
        pylon.name = "ConstructionPylon%d" % index
        var pylon_mesh := CylinderMesh.new()
        pylon_mesh.top_radius = 0.045
        pylon_mesh.bottom_radius = 0.07
        pylon_mesh.height = 1.45
        pylon_mesh.radial_segments = 10
        pylon.mesh = pylon_mesh
        pylon.material_override = _vfx_material(color, 0.42, 1.6)
        pylon.position = Vector3(cos(angle) * 0.92, 0.78, sin(angle) * 0.92)
        signature.add_child(pylon)

    for index in range(3):
        var link := MeshInstance3D.new()
        link.name = "ConstructionMachineLink%d" % index
        var link_mesh := CylinderMesh.new()
        link_mesh.top_radius = 0.022
        link_mesh.bottom_radius = 0.045
        link_mesh.height = 1.0
        link_mesh.radial_segments = 8
        link.mesh = link_mesh
        link.material_override = _vfx_material(color, 0.42, 1.5)
        signature.add_child(link)
    return signature


func _update_construction_signature(signature: Node3D, site: Node3D, members: Array, kind: StringName, delta: float) -> void:
    var site_position := site.global_position
    signature.global_position = site_position
    var ring := signature.get_node_or_null("ConstructionTargetRing") as MeshInstance3D
    if ring != null:
        ring.rotation.y += delta * (1.6 if kind == &"upgrade" else 2.2)
        var pulse := 1.0 + sin(elapsed * 4.2) * 0.07
        ring.scale = Vector3.ONE * pulse
    var core := signature.get_node_or_null("ConstructionWorkCore") as MeshInstance3D
    if core != null:
        core.rotation.y -= delta * 2.0
        core.position.y = 0.52 + sin(elapsed * 3.6) * 0.1
    for index in range(3):
        var link := signature.get_node_or_null("ConstructionMachineLink%d" % index) as MeshInstance3D
        if link == null:
            continue
        if index >= members.size() or not is_instance_valid(members[index]) or not (members[index] is Node3D):
            link.visible = false
            continue
        link.visible = true
        var member := members[index] as Node3D
        var direction := member.global_position + Vector3.UP * 0.9 - (site_position + Vector3.UP * 0.3)
        var distance := direction.length()
        link.position = direction * 0.5 + Vector3.UP * 0.3
        link.scale = Vector3.ONE * Vector3(1.0, maxf(0.15, distance), 1.0)
        if distance > 0.01:
            link.quaternion = Quaternion(Vector3.UP, direction.normalized())


func _spawn_channel_field(kind: StringName) -> void:
    if world == null or player == null:
        return
    if channel_field != null and is_instance_valid(channel_field):
        channel_field.queue_free()
    channel_field = Node3D.new()
    channel_field.name = "ActiveChannelField"
    channel_field_color = Color("74e1e7") if kind == &"manual_salvage" else Color("ffad54")
    channel_field_material = _vfx_material(channel_field_color, 0.52, 4.0)
    world.add_child(channel_field)
    channel_field.global_position = player.global_position + Vector3(0.0, 0.12, 0.0)

    var disc := MeshInstance3D.new()
    disc.name = "ChannelFieldDisc"
    var disc_mesh := CylinderMesh.new()
    disc_mesh.top_radius = 1.02
    disc_mesh.bottom_radius = 1.02
    disc_mesh.height = 0.018
    disc_mesh.radial_segments = 48
    disc.mesh = disc_mesh
    disc.material_override = channel_field_material
    disc.transparency = 0.18
    disc.position.y = -0.07
    channel_field.add_child(disc)

    for index in range(3):
        var ring := MeshInstance3D.new()
        ring.name = "ChannelFieldRing%d" % index
        var ring_mesh := TorusMesh.new()
        ring_mesh.inner_radius = 0.78 + float(index) * 0.12
        ring_mesh.outer_radius = ring_mesh.inner_radius + 0.045
        ring_mesh.rings = 16
        ring_mesh.ring_segments = 36
        ring.mesh = ring_mesh
        ring.material_override = channel_field_material
        ring.position.y = 0.05 + float(index) * 0.42
        ring.rotation.x = 0.06 * float(index)
        channel_field.add_child(ring)

    var core := MeshInstance3D.new()
    core.name = "ChannelFieldCore"
    var core_mesh := CylinderMesh.new()
    core_mesh.top_radius = 0.035
    core_mesh.bottom_radius = 0.08
    core_mesh.height = 1.18
    core_mesh.radial_segments = 16
    core.mesh = core_mesh
    core.material_override = channel_field_material
    core.position.y = 0.6
    channel_field.add_child(core)


func _spawn_weapon_tracer(origin: Vector3, target: Vector3, color: Color) -> void:
    if world == null:
        return
    var direction := target - origin
    var distance := direction.length()
    if distance <= 0.08:
        return
    var tracer := MeshInstance3D.new()
    tracer.name = "WeaponTracer"
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.026
    mesh.bottom_radius = 0.05
    mesh.height = distance
    mesh.radial_segments = 12
    tracer.mesh = mesh
    var material := ModelKit3D.material(color, 0.18, 0.3, color, 3.6)
    tracer.material_override = material
    world.add_child(tracer)
    tracer.global_position = (origin + target) * 0.5
    tracer.quaternion = Quaternion(Vector3.UP, direction.normalized())
    var tween := tracer.create_tween().set_parallel(true)
    tween.tween_property(material, "emission_energy_multiplier", 0.0, 0.16)
    tween.tween_property(tracer, "scale", Vector3(1.0, 1.15, 1.0), 0.16)
    tween.chain().tween_callback(tracer.queue_free)


func _vfx_material(color: Color, alpha: float, emission_energy: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(color.r, color.g, color.b, alpha)
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = emission_energy
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return material


func _animate_camera() -> void:
    if camera == null:
        return
    var effective_shake := camera_shake * _camera_shake_scale()
    if effective_shake <= 0.001:
        camera.h_offset = move_toward(camera.h_offset, 0.0, 0.08)
        camera.v_offset = move_toward(camera.v_offset, 0.0, 0.08)
        return
    camera.h_offset = sin(elapsed * 39.0) * effective_shake * 0.16
    camera.v_offset = cos(elapsed * 47.0) * effective_shake * 0.11


func _spawn_flash(position: Vector3, color: Color, energy: float, light_range: float, lifetime: float) -> void:
    if world == null or _reduced_flashes_enabled():
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
    var telegraph := Node3D.new()
    telegraph.name = "OrganicAttackTelegraph"
    telegraph.position = position + Vector3.UP * 0.06

    var disc := MeshInstance3D.new()
    disc.name = "OrganicAttackTelegraphDisc"
    var disc_mesh := CylinderMesh.new()
    disc_mesh.top_radius = 1.0
    disc_mesh.bottom_radius = 1.0
    disc_mesh.height = 0.024
    disc_mesh.radial_segments = 32
    var disc_material := StandardMaterial3D.new()
    disc_material.albedo_color = Color(1.0, 0.08, 0.14, 0.38)
    disc_material.emission_enabled = true
    disc_material.emission = Color("ff3048")
    disc_material.emission_energy_multiplier = 2.1
    disc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    disc_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    disc_mesh.material = disc_material
    disc.mesh = disc_mesh
    telegraph.add_child(disc)

    var ring := MeshInstance3D.new()
    ring.name = "OrganicAttackTelegraphRing"
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.78
    ring_mesh.outer_radius = 1.0
    ring_mesh.rings = 32
    ring_mesh.ring_segments = 8
    var ring_material := StandardMaterial3D.new()
    ring_material.albedo_color = Color(1.0, 0.2, 0.24, 0.9)
    ring_material.emission_enabled = true
    ring_material.emission = Color("ff4058")
    ring_material.emission_energy_multiplier = 3.2
    ring_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    ring_mesh.material = ring_material
    ring.mesh = ring_mesh
    ring.position.y = 0.045
    telegraph.add_child(ring)

    var pylon_materials: Array[StandardMaterial3D] = []
    var pylon_offsets := [Vector2(-0.82, 0.0), Vector2(0.82, 0.0), Vector2(0.0, -0.82), Vector2(0.0, 0.82)]
    for pylon_index in pylon_offsets.size():
        var pylon := MeshInstance3D.new()
        pylon.name = "OrganicAttackTelegraphPylon%d" % pylon_index
        var pylon_mesh := BoxMesh.new()
        pylon_mesh.size = Vector3(0.08, 0.62, 0.08)
        var pylon_material := StandardMaterial3D.new()
        pylon_material.albedo_color = Color(1.0, 0.24, 0.28, 0.9)
        pylon_material.emission_enabled = true
        pylon_material.emission = Color("ff4058")
        pylon_material.emission_energy_multiplier = 3.6
        pylon_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        pylon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        pylon_mesh.material = pylon_material
        pylon.mesh = pylon_mesh
        var pylon_offset: Vector2 = pylon_offsets[pylon_index]
        pylon.position = Vector3(pylon_offset.x, 0.31, pylon_offset.y)
        telegraph.add_child(pylon)
        pylon_materials.append(pylon_material)

    telegraph.scale = Vector3(radius * 0.68, 1.0, radius * 0.68)
    world.add_child(telegraph)
    var tween := telegraph.create_tween().set_parallel(true)
    tween.tween_property(telegraph, "scale", Vector3(radius, 1.0, radius), 0.34)
    tween.tween_property(disc_material, "albedo_color", Color(1.0, 0.08, 0.14, 0.0), 0.34)
    tween.tween_property(ring_material, "albedo_color", Color(1.0, 0.2, 0.24, 0.0), 0.34)
    for pylon_material in pylon_materials:
        tween.tween_property(pylon_material, "albedo_color", Color(1.0, 0.24, 0.28, 0.0), 0.34)
    tween.chain().tween_callback(telegraph.queue_free)


func _spawn_burst(position: Vector3, color: Color, amount: int, speed: float, gravity: Vector3, lifetime: float, node_name: String = "TransientBurst") -> void:
    if world == null:
        return
    var particles := CPUParticles3D.new()
    particles.name = node_name
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
