class_name IronwrightWorld3D
extends Node3D

const SAVE_SERVICE_SCRIPT := preload("res://scripts/systems/transactional_save_service_3d.gd")
const MECHROMANCER_SCENE := preload("res://scenes/actors/mechromancer_3d.tscn")
const ROBOT_SCENE := preload("res://scenes/actors/robot_unit_3d.tscn")
const ENEMY_SCENE := preload("res://scenes/actors/organic_enemy_3d.tscn")
const HEARTFORGE_SCENE := preload("res://scenes/world/heartforge_3d.tscn")
const SALVAGE_SCENE := preload("res://scenes/world/salvage_pile_3d.tscn")
const CITY_SCENE := preload("res://scenes/world/procedural_city_3d.tscn")
const HUD_SCENE := preload("res://scenes/ui/ironwright_hud_3d.tscn")
const AUDIO_DIRECTOR_SCRIPT := preload("res://scripts/presentation/audio_feedback_director_3d.gd")
const OPERATION_DETAIL_SCRIPT := preload("res://scripts/systems/operation_detail_director_3d.gd")

var run_state: RunState3D
var noise_system: NoiseSystem3D
var autonomy_director: AutonomyDirector3D
var ecology_director: EcologyDirector3D
var player: Mechromancer3D
var companion: RobotUnit3D
var heartforge: Heartforge3D
var hud: IronwrightHUD3D
var camera: Camera3D
var camera_height: float = 18.0
var camera_distance: float = 15.0
var map_mode: bool = false
var follow_operation: bool = false
var paused: bool = false
var game_ended: bool = false
var objective_stage: int = 0
var nearest_salvage: SalvagePile3D
var forge_in_range: bool = false
var active_tracers: Array[Node3D] = []
var salvage_serial: int = 0
var enemy_serial: int = 0
var save_service: TransactionalSaveService3D
var audio_director: AudioFeedbackDirector3D
var operation_detail_director: Variant


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    save_service = SAVE_SERVICE_SCRIPT.new() as TransactionalSaveService3D
    save_service.configure()
    _setup_environment()
    operation_detail_director = OPERATION_DETAIL_SCRIPT.new()
    operation_detail_director.name = "OperationDetailDirector"
    operation_detail_director.configure(camera)
    add_child(operation_detail_director)
    _spawn_world()
    audio_director = AUDIO_DIRECTOR_SCRIPT.new() as AudioFeedbackDirector3D
    audio_director.name = "AudioFeedbackDirector"
    audio_director.configure(self, player, heartforge, noise_system)
    add_child(audio_director)
    _connect_systems()
    _update_hud_from_state()
    run_state.log_event("The Heartforge light is weak. The companion is your only reliable protection.")


func _process(delta: float) -> void:
    if paused or game_ended:
        return
    _update_camera(delta)
    _update_interaction_context()
    _update_objective()
    if hud != null and autonomy_director != null:
        hud.set_operation(autonomy_director.operation_summary())


func _unhandled_input(event: InputEvent) -> void:
    if not (event is InputEventKey) or not event.pressed or event.echo:
        if event is InputEventMouseButton and event.pressed:
            if event.button_index == MOUSE_BUTTON_WHEEL_UP:
                camera_height = maxf(11.0, camera_height - 1.4)
            elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
                camera_height = minf(29.0, camera_height + 1.4)
        return

    var key_event := event as InputEventKey
    var key := key_event.keycode
    if game_ended and key == KEY_ENTER:
        get_tree().reload_current_scene()
        return

    if key == KEY_ESCAPE:
        if hud.forge_open:
            _close_forge_menu()
        else:
            paused = not paused
            get_tree().paused = paused
            hud.push_notification("PAUSED" if paused else "RESUMED")
        return

    if paused:
        return

    if hud.forge_open:
        match key:
            KEY_1:
                _start_manual_build(&"salvager")
            KEY_2:
                _start_manual_build(&"guardian")
            KEY_3:
                _start_manual_build(&"scout")
            KEY_4:
                _start_manual_upgrade(&"salvager")
            KEY_5:
                _start_manual_upgrade(&"guardian")
            KEY_6:
                _start_manual_upgrade(&"scout")
        return

    match key:
        KEY_E:
            _handle_context_interaction()
        KEY_1:
            run_state.set_focus(RunState3D.FOCUS_DEFEND)
        KEY_2:
            run_state.set_focus(RunState3D.FOCUS_SALVAGE)
        KEY_3:
            run_state.set_focus(RunState3D.FOCUS_EXPEDITION)
        KEY_X:
            _authorize_expedition()
        KEY_M:
            map_mode = not map_mode
            hud.show_map_banner(map_mode)
        KEY_F:
            follow_operation = not follow_operation
            hud.push_notification("FOLLOWING ACTIVE MACHINE GROUP" if follow_operation else "CAMERA RETURNED TO THE MECHROMANCER")
        KEY_F5:
            _save_game()
        KEY_F9:
            _load_game()


func _setup_environment() -> void:
    var world_environment := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color("050709")
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color("27313a")
    environment.ambient_light_energy = 0.17
    environment.fog_enabled = true
    environment.fog_light_color = Color("171e23")
    environment.fog_light_energy = 0.35
    environment.fog_density = 0.025
    environment.fog_aerial_perspective = 0.5
    environment.fog_sky_affect = 0.1
    world_environment.environment = environment
    add_child(world_environment)

    var moon := DirectionalLight3D.new()
    moon.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
    moon.light_color = Color("607386")
    moon.light_energy = 0.43
    moon.shadow_enabled = true
    moon.directional_shadow_max_distance = 95.0
    add_child(moon)

    camera = Camera3D.new()
    camera.name = "IsometricCamera"
    camera.current = true
    camera.fov = 52.0
    camera.near = 0.15
    camera.far = 300.0
    add_child(camera)


func _spawn_world() -> void:
    add_child(CITY_SCENE.instantiate())

    run_state = RunState3D.new()
    run_state.name = "RunState"
    run_state.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(run_state)

    noise_system = NoiseSystem3D.new()
    noise_system.name = "NoiseSystem"
    noise_system.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(noise_system)

    heartforge = HEARTFORGE_SCENE.instantiate() as Heartforge3D
    heartforge.name = "Heartforge"
    heartforge.process_mode = Node.PROCESS_MODE_PAUSABLE
    heartforge.position = Vector3.ZERO
    add_child(heartforge)

    player = MECHROMANCER_SCENE.instantiate() as Mechromancer3D
    player.name = "Mechromancer"
    player.process_mode = Node.PROCESS_MODE_PAUSABLE
    player.position = Vector3(0.0, 0.0, 6.0)
    add_child(player)

    autonomy_director = AutonomyDirector3D.new()
    autonomy_director.name = "AutonomyDirector"
    autonomy_director.process_mode = Node.PROCESS_MODE_PAUSABLE
    autonomy_director.configure(run_state, noise_system, player, heartforge, operation_detail_director)
    add_child(autonomy_director)

    ecology_director = EcologyDirector3D.new()
    ecology_director.name = "EcologyDirector"
    ecology_director.process_mode = Node.PROCESS_MODE_PAUSABLE
    ecology_director.configure(noise_system, player, heartforge, Callable(self, "_spawn_enemy"))
    add_child(ecology_director)

    hud = HUD_SCENE.instantiate() as IronwrightHUD3D
    add_child(hud)

    companion = _spawn_robot(&"companion", Vector3(1.9, 0.0, 5.0), 1)
    companion.name = "Bulwark_01"

    _spawn_initial_salvage()


func _connect_systems() -> void:
    player.health_changed.connect(hud.set_player_health)
    player.died.connect(_on_player_died)
    player.pistol_fired.connect(_spawn_tracer)
    player.channel_started.connect(_on_channel_started)
    player.channel_progress.connect(_on_channel_progress)
    player.channel_completed.connect(_on_channel_completed)
    player.channel_cancelled.connect(_on_channel_cancelled)
    player.noise_requested.connect(noise_system.emit_noise)

    heartforge.health_changed.connect(_on_heartforge_health_changed)
    heartforge.destroyed.connect(_on_heartforge_destroyed)

    companion.health_changed.connect(_on_companion_health_changed)
    companion.destroyed.connect(_on_companion_destroyed)

    run_state.scrap_changed.connect(func(value: int) -> void: hud.set_resources(value, run_state.rare_cores))
    run_state.rare_cores_changed.connect(func(value: int) -> void: hud.set_resources(run_state.scrap, value))
    run_state.focus_changed.connect(hud.set_focus)
    run_state.event_logged.connect(hud.push_notification)
    run_state.robot_level_changed.connect(_on_robot_level_changed)

    autonomy_director.operation_changed.connect(_on_operation_changed)
    autonomy_director.robot_registered.connect(_on_robot_registered)
    autonomy_director.expedition_core_secured.connect(func() -> void: hud.push_notification("COGNITION CORE SECURED · THE GROUP IS TURNING HOME"))
    autonomy_director.expedition_returned.connect(_on_expedition_returned)

    hud.forge_build_selected.connect(_start_manual_build)
    hud.forge_upgrade_selected.connect(_start_manual_upgrade)
    hud.forge_closed.connect(_close_forge_menu)
    hud.expedition_authorized.connect(_authorize_expedition)


func _spawn_initial_salvage() -> void:
    _spawn_salvage(Vector3(0.0, 0.0, -13.0), 52, "Collapsed municipal loader")
    _spawn_salvage(Vector3(0.0, 0.0, 19.0), 66, "Burned delivery truck")
    _spawn_salvage(Vector3(28.0, 0.0, 0.0), 74, "Ruined tram motor")
    _spawn_salvage(Vector3(-28.0, 0.0, 0.0), 70, "Substation wreckage")
    _spawn_salvage(Vector3(0.0, 0.0, -44.0), 92, "Archive service vehicle")
    _spawn_salvage(Vector3(0.0, 0.0, 47.0), 84, "Collapsed workshop press")


func _spawn_salvage(position: Vector3, amount: int, display_name: String) -> SalvagePile3D:
    salvage_serial += 1
    var pile := SALVAGE_SCENE.instantiate() as SalvagePile3D
    pile.name = "Salvage_%02d" % salvage_serial
    pile.position = position
    pile.remaining_scrap = amount
    pile.display_name = display_name
    pile.manual_channel_seconds = 4.2 + float(amount) / 80.0
    pile.noise_radius = 23.0 + float(amount) * 0.06
    add_child(pile)
    return pile


func _spawn_robot(archetype: StringName, position: Vector3, level: int) -> RobotUnit3D:
    var robot := ROBOT_SCENE.instantiate() as RobotUnit3D
    robot.configure(archetype, level)
    var progression_node := get_node_or_null("ProgressionDirector") as ProgressionDirector3D
    if progression_node != null:
        robot.set_progression(progression_node)
    robot.defer_authored_visuals = should_defer_spawn_visuals(position)
    robot.process_mode = Node.PROCESS_MODE_PAUSABLE
    robot.position = position
    add_child(robot)
    autonomy_director.register_robot(robot)
    robot.weapon_fired.connect(_spawn_tracer)
    return robot


func _spawn_enemy(position: Vector3, species: StringName) -> OrganicEnemy3D:
    enemy_serial += 1
    var enemy := ENEMY_SCENE.instantiate() as OrganicEnemy3D
    enemy.name = "%s_%02d" % [String(species).capitalize(), enemy_serial]
    enemy.configure(species, player, heartforge)
    enemy.defer_authored_visuals = should_defer_spawn_visuals(position)
    enemy.process_mode = Node.PROCESS_MODE_PAUSABLE
    enemy.position = position
    add_child(enemy)
    enemy.killed.connect(_on_enemy_killed)
    return enemy


func should_defer_spawn_visuals(_position: Vector3) -> bool:
    return false


func _update_camera(delta: float) -> void:
    if camera == null or player == null:
        return
    var target := player.global_position
    if map_mode:
        var map_target := Vector3(0.0, 0.0, -8.0)
        var desired_map_position := map_target + Vector3(0.0, 78.0, 8.0)
        camera.global_position = camera.global_position.lerp(desired_map_position, 1.0 - exp(-delta * 4.0))
        camera.look_at(map_target, Vector3.FORWARD)
        return
    if follow_operation:
        var operation_target := autonomy_director.get_follow_target()
        if operation_target != null:
            target = operation_target.global_position
        else:
            follow_operation = false
    var desired_position := target + Vector3(0.0, camera_height, camera_distance)
    camera.global_position = camera.global_position.lerp(desired_position, 1.0 - exp(-delta * 6.5))
    camera.look_at(target + Vector3.UP * 0.7, Vector3.UP)


func _update_interaction_context() -> void:
    nearest_salvage = null
    forge_in_range = player.global_position.distance_to(heartforge.global_position + Vector3(0.0, 0.0, 3.0)) <= heartforge.interaction_radius
    var best_distance := 2.65
    for candidate in get_tree().get_nodes_in_group("salvage_piles"):
        if not is_instance_valid(candidate) or not (candidate is SalvagePile3D) or not candidate.has_scrap():
            continue
        var current_distance := player.global_position.distance_to(candidate.global_position)
        if current_distance < best_distance:
            nearest_salvage = candidate
            best_distance = current_distance

    if player.is_channeling():
        hud.set_prompt("Do not move. Any hit interrupts the exposed operation.")
    elif hud.forge_open:
        hud.set_prompt("Choose one manual fabrication or class upgrade. ESC closes the forge.")
    elif nearest_salvage != null:
        hud.set_prompt("HOLD E · salvage %s · loud, slow, pistol disabled" % nearest_salvage.display_name)
    elif forge_in_range:
        hud.set_prompt("E · operate Heartforge manually")
    else:
        hud.set_prompt("The pistol buys seconds. Stay close enough for the Bulwark to intercept.")


func _handle_context_interaction() -> void:
    if player.is_channeling():
        return
    if nearest_salvage != null:
        player.begin_channel(
            &"manual_salvage",
            nearest_salvage,
            nearest_salvage.manual_channel_seconds,
            "SALVAGING %s" % nearest_salvage.display_name.to_upper(),
            {},
            true,
            nearest_salvage.noise_radius,
            nearest_salvage.noise_intensity
        )
        return
    if forge_in_range:
        hud.show_forge_menu()
        player.input_enabled = false


func _start_manual_build(archetype: StringName) -> void:
    if not forge_in_range or player.is_channeling():
        hud.push_notification("MOVE TO THE HEARTFORGE ASSEMBLY PLATE FIRST")
        return
    var cost := run_state.build_cost(archetype)
    if not run_state.spend_scrap(cost):
        hud.push_notification("INSUFFICIENT SCRAP · %d REQUIRED" % cost)
        return
    _close_forge_menu()
    heartforge.set_operation(&"forge_build")
    player.begin_channel(
        &"forge_build",
        heartforge,
        run_state.build_time(archetype),
        "FORGING %s" % String(archetype).to_upper(),
        {"archetype": String(archetype), "cost": cost},
        false,
        29.0,
        1.15
    )


func _start_manual_upgrade(archetype: StringName) -> void:
    if not forge_in_range or player.is_channeling():
        return
    var cost := run_state.upgrade_cost(archetype)
    if not run_state.can_upgrade(archetype):
        hud.push_notification("UPGRADE LOCKED · NEED %d SCRAP AND %d RARE CORE" % [int(cost.get("scrap", 0)), int(cost.get("cores", 0))])
        return
    _close_forge_menu()
    heartforge.set_operation(&"forge_upgrade")
    player.begin_channel(
        &"forge_upgrade",
        heartforge,
        6.0 + float(run_state.level_for(archetype)) * 2.0,
        "REBUILDING ALL %s FRAMES" % String(archetype).to_upper(),
        {"archetype": String(archetype)},
        false,
        31.0,
        1.25
    )


func _close_forge_menu() -> void:
    hud.hide_forge_menu()
    player.input_enabled = true


func _authorize_expedition() -> void:
    run_state.set_focus(RunState3D.FOCUS_EXPEDITION)
    if autonomy_director.authorize_north_expedition():
        hud.push_notification("NORTH RUINS EXPEDITION AUTHORIZED · F TO FOLLOW")
    else:
        hud.push_notification("EXPEDITION NEEDS 1 PATHFINDER, 1 WARDEN, AND 1 SCRAPPER")


func _on_channel_started(kind: StringName, duration: float, description: String) -> void:
    hud.show_channel(kind, 0.0, description)


func _on_channel_progress(kind: StringName, progress: float, description: String) -> void:
    hud.show_channel(kind, progress, description)


func _on_channel_completed(kind: StringName, target: Node, metadata: Dictionary) -> void:
    hud.hide_channel()
    heartforge.set_operation(&"")
    if kind == &"manual_salvage" and target is SalvagePile3D:
        var pile := target as SalvagePile3D
        var recovered := pile.extract_manual()
        run_state.add_scrap(recovered, false)
        run_state.log_event("You recovered %d Scrap while the salvage noise drew organisms closer." % recovered)
    elif kind == &"forge_build":
        var archetype := StringName(str(metadata.get("archetype", "salvager")))
        var spawn_offset := Vector3(2.4 + float(run_state.robots_built % 3), 0.0, 3.5 + float(run_state.robots_built % 2))
        _spawn_robot(archetype, heartforge.global_position + spawn_offset, run_state.level_for(archetype))
        run_state.robots_built += 1
        run_state.log_event("A level %d %s was built manually at the Heartforge." % [run_state.level_for(archetype), String(archetype).capitalize()])
    elif kind == &"forge_upgrade":
        var upgrade_archetype := StringName(str(metadata.get("archetype", "salvager")))
        run_state.purchase_upgrade(upgrade_archetype)
    player.input_enabled = true


func _on_channel_cancelled(kind: StringName, target: Node, metadata: Dictionary) -> void:
    hud.hide_channel()
    heartforge.set_operation(&"")
    if kind == &"forge_build":
        run_state.refund_scrap(int(metadata.get("cost", 0)))
        hud.push_notification("FABRICATION INTERRUPTED · SCRAP RETURNED")
    elif kind == &"forge_upgrade":
        hud.push_notification("UPGRADE INTERRUPTED")
    elif kind == &"manual_salvage":
        hud.push_notification("SALVAGE ABANDONED · THE NOISE REMAINS")
    player.input_enabled = true


func _on_robot_registered(robot: RobotUnit3D) -> void:
    if robot.archetype == &"companion":
        robot.health_changed.connect(_on_companion_health_changed)


func _on_robot_level_changed(archetype: StringName, level: int) -> void:
    _apply_level_to_existing_robots(archetype)


func _apply_level_to_existing_robots(archetype: StringName) -> void:
    for robot in autonomy_director.living_robots(archetype):
        var health_ratio := robot.current_health / maxf(1.0, robot.maximum_health)
        robot.configure(archetype, run_state.level_for(archetype))
        robot.current_health = robot.maximum_health * health_ratio


func _on_operation_changed(kind: StringName, state: StringName, detail: String) -> void:
    hud.push_notification("%s · %s\n%s" % [String(kind).to_upper(), String(state).to_upper(), detail])
    var release_audio := get_node_or_null("ReleaseAudioDirector") as ReleaseAudioDirector3D
    if release_audio != null:
        var anchor := heartforge.global_position if heartforge != null else Vector3.ZERO
        if kind == &"salvage" and not autonomy_director.salvage_operation.is_empty():
            anchor = autonomy_director.salvage_operation.get("anchor", anchor)
        elif kind == &"expedition" and not autonomy_director.expedition_operation.is_empty():
            anchor = autonomy_director.expedition_operation.get("anchor", anchor)
        release_audio.notify_operation(kind, state, detail, anchor)


func _on_expedition_returned() -> void:
    if run_state.expedition_core_recovered:
        game_ended = true
        hud.show_ending(true, "The machines crossed the real city as one formation, secured the Cognition Core, and returned without individual orders. The next phase can unlock forge automation and deeper machine intelligence.")


func _on_player_died() -> void:
    game_ended = true
    hud.show_ending(false, "The weak pistol could not replace the lost protection of the machines. The city reclaimed the Mechromancer.")


func _on_heartforge_destroyed() -> void:
    game_ended = true
    hud.show_ending(false, "The only Heartforge was destroyed. There is no secondary settlement and no territory to retreat into.")


func _on_heartforge_health_changed(current: float, maximum: float) -> void:
    if current / maximum < 0.35:
        hud.push_notification("HEARTFORGE INTEGRITY CRITICAL")


func _on_companion_health_changed(robot: RobotUnit3D, current: float, maximum: float) -> void:
    if hud != null:
        hud.set_companion_health(current, maximum)


func _on_companion_destroyed(robot: RobotUnit3D) -> void:
    hud.set_companion_health(0.0, robot.maximum_health)
    hud.push_notification("BULWARK DISABLED · RETREAT. THE PISTOL CANNOT HOLD THE STREET ALONE.")


func _on_enemy_killed(enemy: OrganicEnemy3D, killer: Node) -> void:
    if killer == player:
        run_state.log_event("The weak pistol finished a %s only after sustained exposure." % String(enemy.species))


func _spawn_tracer(origin: Vector3, target: Vector3, target_node: Node) -> void:
    var direction := target - origin
    var length := direction.length()
    if length <= 0.05:
        return
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.025
    mesh.bottom_radius = 0.025
    mesh.height = length
    mesh.radial_segments = 6
    var tracer := MeshInstance3D.new()
    tracer.mesh = mesh
    tracer.position = (origin + target) * 0.5
    tracer.quaternion = Quaternion(Vector3.UP, direction.normalized())
    var emission_color := Color("77ecf0") if origin.distance_to(player.global_position) < 2.5 else Color("e0a45e")
    tracer.material_override = ModelKit3D.material(emission_color, 0.0, 0.2, emission_color, 4.0)
    add_child(tracer)
    active_tracers.append(tracer)
    var tween := create_tween()
    tween.tween_interval(0.075)
    tween.tween_callback(func() -> void:
        active_tracers.erase(tracer)
        if is_instance_valid(tracer):
            tracer.queue_free()
    )


func _update_hud_from_state() -> void:
    hud.set_resources(run_state.scrap, run_state.rare_cores)
    hud.set_focus(run_state.focus)
    hud.set_player_health(player.current_health, player.maximum_health)
    hud.set_companion_health(companion.current_health, companion.maximum_health)


func _update_objective() -> void:
    if run_state.manual_scrap_recovered < 20:
        objective_stage = 0
        hud.set_objective("LEAVE THE LIGHT", "Hold E at a nearby wreck. Salvaging takes time, disables the pistol, and alerts the ecology.")
    elif autonomy_director.count_robots(&"salvager") < 1:
        objective_stage = 1
        hud.set_objective("FORGE A SCRAPPER", "Return to the Heartforge, press E, and build it manually while the Bulwark protects you.")
    elif run_state.autonomous_scrap_recovered < 30:
        objective_stage = 2
        hud.set_objective("LET THE MACHINES WORK", "Press 2. The Scrapper will leave in a coordinated group, salvage, and physically return with Scrap.")
    elif autonomy_director.count_robots(&"guardian") < 1 or autonomy_director.count_robots(&"scout") < 1:
        objective_stage = 3
        hud.set_objective("PREPARE A REAL EXPEDITION", "Use autonomous salvage to fund one Warden and one Pathfinder. You must still forge both personally.")
    elif not run_state.expedition_core_recovered and autonomy_director.expedition_operation.is_empty():
        objective_stage = 4
        hud.set_objective("NORTH RUINS", "Press X to authorize the group objective. The machines choose formation and local reactions; F follows them.")
    elif not run_state.expedition_core_recovered:
        objective_stage = 5
        hud.set_objective("KEEP THE HEARTFORGE ALIVE", "The expedition exists physically elsewhere. The home remains exposed while the group travels and returns.")


func _save_game() -> void:
    if player.is_channeling():
        hud.push_notification("SAVE DEFERRED · FINISH THE ACTIVE MANUAL CHANNEL")
        return
    var snapshot := {
        "foundation": {
            "schema_version": 1,
            "run_state": run_state.to_dictionary(),
            "player": {"position": _vector_to_array(player.global_position), "health": player.current_health},
            "heartforge": {"health": heartforge.current_health},
            "robots": [],
            "salvage": [],
            "enemies": [],
            "ecology": ecology_director.to_dictionary(),
        },
        "extensions": _save_extension_data(),
    }
    var foundation: Dictionary = snapshot["foundation"]
    for robot in autonomy_director.living_robots():
        foundation["robots"].append({
            "name": String(robot.name),
            "archetype": String(robot.archetype),
            "level": robot.level,
            "callsign": robot.callsign,
            "position": _vector_to_array(robot.global_position),
            "health": robot.current_health,
        })
    for pile in get_tree().get_nodes_in_group("salvage_piles"):
        if is_instance_valid(pile) and pile is SalvagePile3D:
            foundation["salvage"].append({
                "position": _vector_to_array(pile.global_position),
                "remaining": pile.remaining_scrap,
                "display_name": pile.display_name,
            })
    for enemy in get_tree().get_nodes_in_group("organic_enemies"):
        if is_instance_valid(enemy) and enemy is OrganicEnemy3D and enemy.is_alive():
            foundation["enemies"].append({
                "species": String(enemy.species),
                "position": _vector_to_array(enemy.global_position),
                "health": enemy.current_health,
            })
    if save_service == null or not save_service.write_snapshot(snapshot):
        hud.push_notification("SAVE FAILED · %s" % (save_service.last_error if save_service != null else "SERVICE UNAVAILABLE"))
        return
    hud.push_notification("WORLD SAVED TRANSACTIONALLY · BACKUPS ROTATED · ACTOR POSITIONS RETAINED")


func _load_game() -> void:
    if save_service == null:
        hud.push_notification("SAVE INVALID · SERVICE UNAVAILABLE")
        return
    var snapshot: Dictionary = save_service.read_snapshot()
    if snapshot.is_empty():
        hud.push_notification("NO VALID SAVE FOUND · %s" % save_service.last_error)
        return
    var data: Dictionary = snapshot.get("foundation", {})
    if data.is_empty():
        hud.push_notification("SAVE INVALID · FOUNDATION MISSING")
        return
    _clear_runtime_entities()
    run_state.restore_from_dictionary(data.get("run_state", {}))
    var player_data: Dictionary = data.get("player", {})
    player.global_position = _array_to_vector(player_data.get("position", [0, 0, 6]))
    player.current_health = float(player_data.get("health", player.maximum_health))
    player.health_changed.emit(player.current_health, player.maximum_health)
    var forge_data: Dictionary = data.get("heartforge", {})
    heartforge.current_health = float(forge_data.get("health", heartforge.maximum_health))
    heartforge.health_changed.emit(heartforge.current_health, heartforge.maximum_health)

    for robot_data in data.get("robots", []):
        var archetype := StringName(str(robot_data.get("archetype", "salvager")))
        var robot := _spawn_robot(archetype, _array_to_vector(robot_data.get("position", [0, 0, 4])), int(robot_data.get("level", 1)))
        var saved_name := str(robot_data.get("name", ""))
        if not saved_name.is_empty():
            robot.name = saved_name
        robot.restore_callsign(robot_data.get("callsign", ""))
        robot.current_health = float(robot_data.get("health", robot.maximum_health))
        if archetype == &"companion":
            companion = robot
            if not robot.destroyed.is_connected(_on_companion_destroyed):
                robot.destroyed.connect(_on_companion_destroyed)

    for pile_data in data.get("salvage", []):
        var pile := _spawn_salvage(_array_to_vector(pile_data.get("position", [0, 0, -12])), int(pile_data.get("remaining", 0)), str(pile_data.get("display_name", "Wreckage")))
        if pile.remaining_scrap <= 0:
            pile.visible = false
            pile.collision_layer = 0

    for enemy_data in data.get("enemies", []):
        var enemy := _spawn_enemy(_array_to_vector(enemy_data.get("position", [20, 0, -20])), StringName(str(enemy_data.get("species", "skitterling"))))
        enemy.current_health = float(enemy_data.get("health", enemy.maximum_health))
    ecology_director.restore_from_dictionary(data.get("ecology", {}))
    _update_hud_from_state()
    _restore_extension_data(snapshot.get("extensions", {}))
    var migrated_note := " · LEGACY SAVE MIGRATED" if bool(snapshot.get("migrated_from_legacy", false)) else ""
    hud.push_notification("WORLD LOADED TRANSACTIONALLY%s" % migrated_note)


func _save_extension_data() -> Dictionary:
    return {"autonomy": autonomy_director.to_dictionary()}


func _restore_extension_data(extensions: Variant) -> void:
    if extensions is Dictionary:
        autonomy_director.restore_from_dictionary((extensions as Dictionary).get("autonomy", {}))


func _clear_runtime_entities() -> void:
    autonomy_director.salvage_operation.clear()
    autonomy_director.expedition_operation.clear()
    for robot in get_tree().get_nodes_in_group("friendly_robots"):
        if is_instance_valid(robot):
            robot.free()
    autonomy_director.robots.clear()
    for pile in get_tree().get_nodes_in_group("salvage_piles"):
        if is_instance_valid(pile):
            pile.free()
    for enemy in get_tree().get_nodes_in_group("organic_enemies"):
        if is_instance_valid(enemy):
            enemy.free()


func _vector_to_array(value: Vector3) -> Array[float]:
    return [value.x, value.y, value.z]


func _array_to_vector(value: Variant) -> Vector3:
    if value is Array and value.size() >= 3:
        return Vector3(float(value[0]), float(value[1]), float(value[2]))
    return Vector3.ZERO
