class_name IronwrightReleaseWorld3D
extends IronwrightProductionWorld3D

const RELEASE_SLOT: StringName = &"world_0"
const LEGACY_BASE_SAVE := "user://ironwright_first_light_3d.json"
const LEGACY_FOUNDATION_SAVE := "user://ironwright_full_game_extension.json"
const LEGACY_COMPLETE_SAVE := "user://ironwright_complete_game_state.json"
const VERTICAL_SLICE_DIRECTOR := preload("res://scripts/presentation/vertical_slice_readable_director_3d.gd")
const VERTICAL_SLICE_ACTOR_ART := preload("res://scripts/presentation/vertical_slice_actor_art_3d.gd")
const RUN_VARIATION_SCRIPT := preload("res://scripts/presentation/run_variation_director_3d.gd")

static var pending_launch_mode: StringName = &"title"

var localization_service: LocalizationService3D
var settings_service: ReleaseSettingsService3D
var transactional_save_service: ReleaseTransactionalSaveService3D
var spatial_index: SpatialIndex3D
var balance_director: BalanceDirector3D
var performance_director: PerformanceDirector3D
var release_world_art: ReleaseWorldArtDirector3D
var release_animation: ReleaseAnimationDirector3D
var release_audio: ReleaseAudioDirector3D
var release_front_end: ReleaseFrontEnd3D
var release_started: bool = false
var controller_action_cooldown: float = 0.0
var release_save_clock: float = 0.0
var _last_map_label_mode: bool = false
var vertical_slice: VerticalSliceDirector3D
var vertical_slice_actor_art: VerticalSliceActorArt3D
var run_variation_director: RunVariationDirector3D
var camera_target_velocity: Vector3 = Vector3.ZERO
var camera_heading: Vector3 = Vector3(0.0, 0.0, 1.0)


func _ready() -> void:
    super._ready()
    _setup_vertical_slice_presentation()
    _setup_release_services()
    _connect_release_services()
    _apply_release_settings()
    _apply_balance_to_existing_world()
    call_deferred("_finish_release_boot")


func _process(delta: float) -> void:
    super._process(delta)
    if map_mode != _last_map_label_mode:
        _last_map_label_mode = map_mode
        _set_region_map_emphasis(map_mode)
    controller_action_cooldown = maxf(0.0, controller_action_cooldown - delta)
    release_save_clock += delta
    if release_started:
        _handle_controller_actions()
    if release_front_end != null and release_front_end.is_modal_open():
        _ensure_modal_focus()


func _setup_vertical_slice_presentation() -> void:
    # Keep the Heartforge readable while giving the Mechromancer and companion
    # enough screen presence for their authored silhouettes to carry the frame.
    camera_height = 16.8
    camera_distance = 10.0
    if camera != null:
        camera.fov = 44.0
        camera.near = 0.35
    _set_region_map_emphasis(false)

    vertical_slice = VERTICAL_SLICE_DIRECTOR.new() as VerticalSliceDirector3D
    vertical_slice.name = "VerticalSliceDirector"
    vertical_slice.configure(self, heartforge, player, camera, ecology_director)
    add_child(vertical_slice)

    vertical_slice_actor_art = VERTICAL_SLICE_ACTOR_ART.new() as VerticalSliceActorArt3D
    vertical_slice_actor_art.name = "VerticalSliceActorArt"
    vertical_slice_actor_art.configure(self)
    add_child(vertical_slice_actor_art)

    run_variation_director = RUN_VARIATION_SCRIPT.new() as RunVariationDirector3D
    run_variation_director.name = "RunVariationDirector"
    run_variation_director.configure(run_state, vertical_slice, region_atmosphere_director)
    add_child(run_variation_director)

    if hud != null:
        hud.notifications.clear()
        hud.notification_ages.clear()
        hud._refresh_notifications()
        hud.push_notification("HEARTFORGE DISTRICT · KEEP THE BULWARK CLOSE")
    run_state.log_event("Presentation status: pre-alpha production prototype. The Heartforge district is the current representative vertical slice.")
    run_state.log_event("The Heartforge district now uses the representative vertical presentation slice. The remainder of the world inherits this quality only after the slice passes human review.")


func _update_camera(delta: float) -> void:
    if camera == null or player == null:
        return

    if map_mode:
        var map_target := Vector3(0.0, 0.0, -8.0)
        if region_director != null and region_director.discovered_count() > 1:
            map_target = _discovered_region_centroid()
        var desired_map_position := map_target + Vector3(0.0, 82.0, 10.0)
        camera.global_position = camera.global_position.lerp(desired_map_position, 1.0 - exp(-delta * 4.2))
        camera.look_at(map_target, Vector3.FORWARD)
        return

    var target := player.global_position
    if follow_operation:
        var operation_target := _active_follow_target()
        if operation_target != null:
            target = operation_target.global_position
        else:
            follow_operation = false

    var subject_velocity := player.velocity if not follow_operation else Vector3.ZERO
    subject_velocity.y = 0.0
    camera_target_velocity = camera_target_velocity.lerp(subject_velocity, 1.0 - exp(-delta * 3.2))
    _update_camera_heading(subject_velocity, delta)
    var lead := camera_target_velocity * 0.38
    if lead.length() > 2.5:
        lead = lead.normalized() * 2.5
    target += lead

    var threat_bias := _nearby_threat_camera_bias(target)
    var dynamic_height := camera_height + threat_bias.y
    var dynamic_distance := camera_distance + threat_bias.z
    if _is_remote_camera_context(target):
        dynamic_height += 9.0
        dynamic_distance += 10.0
    var desired := target + Vector3(0.0, dynamic_height, 0.0) + _camera_horizontal_offset(dynamic_distance)
    var resolved := _resolve_camera_occlusion(target, desired, dynamic_height, dynamic_distance)
    camera.global_position = camera.global_position.lerp(resolved, 1.0 - exp(-delta * 7.2))
    camera.look_at(target + Vector3.UP * 0.68, Vector3.UP)


func _update_camera_heading(velocity: Vector3, delta: float) -> void:
    var planar_velocity := Vector3(velocity.x, 0.0, velocity.z)
    if planar_velocity.length_squared() <= 0.16:
        return
    var desired_heading := -planar_velocity.normalized()
    var blend := 1.0 - exp(-delta * 2.4)
    camera_heading = camera_heading.lerp(desired_heading, blend).normalized()


func _camera_horizontal_offset(distance: float) -> Vector3:
    var horizontal_heading := Vector3(camera_heading.x, 0.0, camera_heading.z)
    if horizontal_heading.length_squared() <= 0.001:
        horizontal_heading = Vector3(0.0, 0.0, 1.0)
    return horizontal_heading.normalized() * distance


func _is_remote_camera_context(position: Vector3) -> bool:
    if region_director == null:
        return false
    return region_director.region_for_position(position) != &"region.heartforge_district"


func _nearby_threat_camera_bias(target: Vector3) -> Vector3:
    var threat_count := 0
    var nearest := INF
    for enemy in get_tree().get_nodes_in_group(&"organic_enemies"):
        if not is_instance_valid(enemy) or not (enemy is Node3D):
            continue
        var distance := target.distance_to((enemy as Node3D).global_position)
        if distance <= 15.0:
            threat_count += 1
            nearest = minf(nearest, distance)
    if threat_count <= 0:
        return Vector3.ZERO
    var intensity := clampf(float(threat_count) * 0.18 + (1.0 - clampf(nearest / 15.0, 0.0, 1.0)) * 0.45, 0.0, 1.0)
    # Threats deserve a little more vertical context without shrinking the
    # silhouettes that communicate attack language and species identity.
    return Vector3(0.0, intensity * 2.6, -intensity * 1.2)


func _active_follow_target() -> Node3D:
    if long_operation_director != null and not long_operation_director.active_operation.is_empty():
        var long_target := long_operation_director.get_follow_target()
        if long_target != null:
            return long_target
    if outpost_director != null and not outpost_director.operation.is_empty():
        var outpost_target := outpost_director.get_follow_target()
        if outpost_target != null:
            return outpost_target
    if autonomy_director != null:
        return autonomy_director.get_follow_target()
    return null


func _resolve_camera_occlusion(target: Vector3, desired: Vector3, dynamic_height: float, dynamic_distance: float) -> Vector3:
    var space_state := get_world_3d().direct_space_state
    var target_eye := target + Vector3.UP * 1.1
    var horizontal_offset := _camera_horizontal_offset(dynamic_distance)
    var candidates: Array[Vector3] = [
        desired,
        target + Vector3(0.0, dynamic_height + 5.5, 0.0) + horizontal_offset * 0.72,
        target + Vector3(0.0, dynamic_height + 10.0, 0.0) + horizontal_offset * 0.48,
        target + Vector3(0.0, dynamic_height + 15.0, 0.0) + horizontal_offset * 0.22,
    ]

    var exclusions: Array[RID] = []
    if player is CollisionObject3D:
        exclusions.append((player as CollisionObject3D).get_rid())
    if heartforge is CollisionObject3D:
        exclusions.append((heartforge as CollisionObject3D).get_rid())

    var last_hit: Dictionary = {}
    for candidate in candidates:
        var query := PhysicsRayQueryParameters3D.create(target_eye, candidate)
        query.collision_mask = 1
        query.collide_with_areas = false
        query.collide_with_bodies = true
        query.exclude = exclusions
        var hit := space_state.intersect_ray(query)
        if hit.is_empty():
            return candidate
        last_hit = hit

    if not last_hit.is_empty():
        var collision_position: Vector3 = last_hit.get("position", desired)
        var direction := (collision_position - target_eye).normalized()
        var safe_distance := maxf(5.0, target_eye.distance_to(collision_position) - 1.0)
        return target_eye + direction * safe_distance
    return desired


func _set_region_map_emphasis(value: bool) -> void:
    for node in get_tree().get_nodes_in_group(&"world_regions"):
        if is_instance_valid(node) and node.has_method(&"set_map_emphasis"):
            node.call(&"set_map_emphasis", value)


func _discovered_region_centroid() -> Vector3:
    if region_director == null:
        return Vector3.ZERO
    var regions := region_director.discovered_regions()
    if regions.is_empty():
        return Vector3.ZERO
    var total := Vector3.ZERO
    var count := 0
    for data in regions:
        var region_id := StringName(str(data.get("id", "")))
        total += region_director.center(region_id)
        count += 1
    return total / float(maxi(1, count))


func _unhandled_input(event: InputEvent) -> void:
    if release_front_end != null and release_front_end.is_modal_open():
        return
    if event is InputEventKey and event.pressed and not event.echo:
        var key := (event as InputEventKey).keycode
        if key == KEY_ESCAPE and not hud.forge_open and not strategic_hud.is_open() and not operations_hud.is_open():
            _show_pause_menu()
            get_viewport().set_input_as_handled()
            return
    super._unhandled_input(event)


func _setup_release_services() -> void:
    localization_service = LocalizationService3D.new()
    localization_service.name = "LocalizationService"
    localization_service.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(localization_service)

    settings_service = ReleaseSettingsService3D.new()
    settings_service.name = "ReleaseSettingsService"
    settings_service.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(settings_service)
    localization_service.set_locale(StringName(str(settings_service.get_value(&"language", "en"))))

    transactional_save_service = ReleaseTransactionalSaveService3D.new()
    transactional_save_service.name = "TransactionalSaveService"
    transactional_save_service.process_mode = Node.PROCESS_MODE_ALWAYS
    add_child(transactional_save_service)

    spatial_index = SpatialIndex3D.new()
    spatial_index.name = "SpatialIndex"
    spatial_index.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(spatial_index)

    balance_director = BalanceDirector3D.new()
    balance_director.name = "BalanceDirector"
    balance_director.process_mode = Node.PROCESS_MODE_PAUSABLE
    add_child(balance_director)
    balance_director.set_profile(StringName(str(settings_service.get_value(&"difficulty", "survival"))))

    performance_director = PerformanceDirector3D.new()
    performance_director.name = "PerformanceDirector"
    performance_director.process_mode = Node.PROCESS_MODE_PAUSABLE
    performance_director.configure(Callable(self, "_release_focus_position"), int(settings_service.get_value(&"target_fps", 60)))
    add_child(performance_director)

    release_world_art = ReleaseWorldArtDirector3D.new()
    release_world_art.name = "ReleaseWorldArtDirector"
    release_world_art.configure(self, region_director, settings_service)
    add_child(release_world_art)

    release_animation = ReleaseAnimationDirector3D.new()
    release_animation.name = "ReleaseAnimationDirector"
    release_animation.configure(self, settings_service)
    add_child(release_animation)

    release_audio = ReleaseAudioDirector3D.new()
    release_audio.name = "ReleaseAudioDirector"
    release_audio.process_mode = Node.PROCESS_MODE_ALWAYS
    release_audio.configure(player, heartforge, progression, strategic_ecology_director, endgame_director, localization_service, settings_service)
    add_child(release_audio)

    release_front_end = ReleaseFrontEnd3D.new()
    release_front_end.name = "ReleaseFrontEnd"
    release_front_end.configure(localization_service, settings_service)
    add_child(release_front_end)


func _connect_release_services() -> void:
    release_front_end.new_world_requested.connect(_on_new_world_requested)
    release_front_end.continue_requested.connect(_on_continue_requested)
    release_front_end.resume_requested.connect(_resume_from_pause)
    release_front_end.save_requested.connect(_save_release_game)
    release_front_end.load_requested.connect(_load_release_game)
    release_front_end.return_title_requested.connect(_return_to_title)
    release_front_end.quit_requested.connect(func() -> void: get_tree().quit())
    release_front_end.settings_applied.connect(_on_front_end_settings_applied)

    settings_service.settings_changed.connect(func(next_settings: Dictionary) -> void:
        _apply_release_settings()
    )
    settings_service.controller_connection_changed.connect(_on_controller_connection_changed)
    transactional_save_service.save_completed.connect(func(slot_id: StringName, path: String) -> void:
        hud.push_notification(localization_service.text("save.saved"))
    )
    transactional_save_service.save_failed.connect(func(slot_id: StringName, reason: String) -> void:
        hud.push_notification("%s · %s" % [localization_service.text("save.failed"), reason.to_upper()])
    )
    transactional_save_service.load_completed.connect(func(slot_id: StringName, source_path: String, recovered_backup: bool) -> void:
        hud.push_notification(localization_service.text("save.invalid") if recovered_backup else localization_service.text("save.loaded"))
    )
    transactional_save_service.load_failed.connect(func(slot_id: StringName, report: Dictionary) -> void:
        var attempts: Array = report.get("attempts", [])
        run_state.log_event("Save recovery failed: %s" % JSON.stringify(report))
        hud.push_notification("%s · %d ATTEMPTS" % [localization_service.text("save.recovery_failed"), attempts.size()])
    )
    transactional_save_service.migration_completed.connect(func(slot_id: StringName, legacy_sources: Array[String]) -> void:
        hud.push_notification(localization_service.text("save.migrated"))
    )
    transactional_save_service.schema_migrated.connect(func(slot_id: StringName, from_version: int, to_version: int, fields: Array[String]) -> void:
        hud.push_notification("%s · %d→%d" % [localization_service.text("save.migrated"), from_version, to_version])
    )

    balance_director.profile_changed.connect(func(profile_id: StringName, profile_data: Dictionary) -> void:
        _apply_balance_profile()
    )
    balance_director.adaptive_relief_changed.connect(func(value: float) -> void:
        _apply_ecology_balance()
    )
    heartforge.health_changed.connect(func(current: float, maximum: float) -> void:
        balance_director.record_heartforge_integrity(current / maxf(1.0, maximum), run_state.elapsed_seconds)
    )
    autonomy_director.robot_registered.connect(_connect_release_robot_tracking)


func _finish_release_boot() -> void:
    settings_service.apply_accessibility_to_tree(self)
    var mode := pending_launch_mode
    pending_launch_mode = &"title"
    if _is_headless_release():
        _start_release_world()
    elif mode == &"new":
        _start_release_world()
    elif mode == &"continue":
        _start_release_world()
        _load_release_game()
    else:
        _show_title_screen()


func _show_title_screen() -> void:
    release_started = false
    paused = true
    player.input_enabled = false
    _set_tactical_hud_visible(false)
    get_tree().paused = true
    release_front_end.show_title(transactional_save_service.has_valid_save(RELEASE_SLOT) or _legacy_save_exists())


func _start_release_world() -> void:
    release_started = true
    paused = false
    game_ended = false
    get_tree().paused = false
    player.input_enabled = true
    _set_tactical_hud_visible(true)
    release_front_end.hide_all()
    settings_service.apply_accessibility_to_tree(self)
    if run_variation_director != null:
        run_variation_director.ensure_current_variant()
        hud.push_notification("WORLD CONDITION · %s" % run_variation_director.current_display_name())
    hud.push_notification("SURVIVAL PROFILE · THE TOWN IS LISTENING")


func _set_tactical_hud_visible(should_show: bool) -> void:
    if hud != null:
        hud.visible = should_show
    if strategic_hud != null:
        strategic_hud.visible = should_show
    if operations_hud != null:
        operations_hud.visible = should_show


func _show_pause_menu() -> void:
    if not release_started:
        return
    paused = true
    player.input_enabled = false
    get_tree().paused = true
    release_front_end.show_pause()


func _resume_from_pause() -> void:
    release_front_end.hide_all()
    get_tree().paused = false
    paused = false
    player.input_enabled = not player.is_channeling()


func _on_new_world_requested() -> void:
    transactional_save_service.delete_slot(RELEASE_SLOT)
    pending_launch_mode = &"new"
    get_tree().paused = false
    get_tree().reload_current_scene()


func _on_continue_requested() -> void:
    _start_release_world()
    _load_release_game()


func _return_to_title() -> void:
    pending_launch_mode = &"title"
    get_tree().paused = false
    get_tree().reload_current_scene()


func _on_front_end_settings_applied(values: Dictionary) -> void:
    localization_service.set_locale(StringName(str(values.get("language", "en"))))
    balance_director.set_profile(StringName(str(values.get("difficulty", "survival"))))
    performance_director.target_fps = int(values.get("target_fps", 60))
    settings_service.apply_accessibility_to_tree(self)
    release_audio.play_effect(&"ui_confirm", "", 0.0, -4.0)


func _apply_release_settings() -> void:
    if settings_service == null:
        return
    if localization_service != null:
        localization_service.set_locale(StringName(str(settings_service.get_value(&"language", "en"))))
    if balance_director != null:
        balance_director.set_profile(StringName(str(settings_service.get_value(&"difficulty", "survival"))))
    if performance_director != null:
        performance_director.target_fps = int(settings_service.get_value(&"target_fps", 60))
    if objective_guidance != null:
        objective_guidance.visible = bool(settings_service.get_value(&"show_world_guidance", true))


func _apply_balance_profile() -> void:
    _apply_balance_to_existing_world()
    _apply_ecology_balance()
    _scale_operation_threats()


func _apply_balance_to_existing_world() -> void:
    if balance_director == null:
        return
    for enemy in get_tree().get_nodes_in_group(&"organic_enemies"):
        if enemy is OrganicEnemy3D:
            balance_director.apply_to_enemy(enemy as OrganicEnemy3D)
    for pile in get_tree().get_nodes_in_group(&"salvage_piles"):
        if pile is SalvagePile3D and not pile.has_meta(&"release_base_scrap"):
            pile.set_meta(&"release_base_scrap", pile.remaining_scrap)
        if pile is SalvagePile3D:
            pile.remaining_scrap = balance_director.scale_scrap_yield(int(pile.get_meta(&"release_base_scrap", pile.remaining_scrap)))
    for robot in autonomy_director.living_robots():
        _connect_release_robot_tracking(robot)


func _apply_ecology_balance() -> void:
    if strategic_ecology_director == null or balance_director == null:
        return
    strategic_ecology_director.set_release_balance(balance_director.active_enemy_cap(), balance_director.regional_pressure_multiplier())


func _scale_operation_threats() -> void:
    if long_operation_director == null or balance_director == null:
        return
    for raw_id in long_operation_director.operations:
        var entry: Dictionary = long_operation_director.operations[raw_id]
        if not entry.has("release_base_threat"):
            entry["release_base_threat"] = float(entry.get("threat_level", 1.0))
        entry["threat_level"] = balance_director.scale_operation_threat(float(entry["release_base_threat"]))
        long_operation_director.operations[raw_id] = entry


func _connect_release_robot_tracking(robot: RobotUnit3D) -> void:
    if robot == null:
        return
    var callback := Callable(self, "_on_release_robot_destroyed")
    if not robot.destroyed.is_connected(callback):
        robot.destroyed.connect(callback)


func _on_release_robot_destroyed(robot: RobotUnit3D) -> void:
    balance_director.record_machine_loss(robot.archetype, run_state.elapsed_seconds)


func _on_controller_connection_changed(connected: bool, device_id: int) -> void:
    if hud == null or localization_service == null:
        return
    hud.push_notification(localization_service.text("controller.connected" if connected else "controller.disconnected"))


func _handle_controller_actions() -> void:
    if release_front_end.is_modal_open() or controller_action_cooldown > 0.0:
        return
    if Input.is_action_just_pressed(&"iw_pause"):
        _show_pause_menu()
        controller_action_cooldown = 0.18
        return
    if hud.forge_open or strategic_hud.is_open() or operations_hud.is_open():
        if Input.is_action_just_pressed(&"iw_cancel"):
            if hud.forge_open:
                _close_forge_menu()
            elif strategic_hud.is_open():
                _close_strategic_hud()
            else:
                _close_operations_hud()
            controller_action_cooldown = 0.18
        return
    if Input.is_action_just_pressed(&"iw_interact"):
        _handle_context_interaction()
    elif Input.is_action_just_pressed(&"iw_follow"):
        follow_operation = not follow_operation
        hud.push_notification("FOLLOWING ACTIVE MACHINE GROUP" if follow_operation else "CAMERA RETURNED TO THE MECHROMANCER")
    elif Input.is_action_just_pressed(&"iw_map"):
        map_mode = not map_mode
        hud.show_map_banner(map_mode)
    elif Input.is_action_just_pressed(&"iw_evolution"):
        _open_evolution_hud()
    elif Input.is_action_just_pressed(&"iw_outposts"):
        _open_outpost_hud()
    elif Input.is_action_just_pressed(&"iw_operations"):
        _open_operations_hud()
    elif Input.is_action_just_pressed(&"iw_endgame"):
        _open_endgame_hud()
    elif Input.is_action_just_pressed(&"iw_focus_defend"):
        run_state.set_focus(RunState3D.FOCUS_DEFEND)
    elif Input.is_action_just_pressed(&"iw_focus_salvage"):
        run_state.set_focus(RunState3D.FOCUS_SALVAGE)
    elif Input.is_action_just_pressed(&"iw_focus_expedition"):
        run_state.set_focus(RunState3D.FOCUS_EXPEDITION)
    controller_action_cooldown = 0.16


func _ensure_modal_focus() -> void:
    if get_viewport().gui_get_focus_owner() != null:
        return
    for root in [release_front_end.title_panel, release_front_end.pause_panel, release_front_end.settings_panel, hud.forge_panel, strategic_hud.panel, operations_hud.panel]:
        if root != null and root.visible:
            _enable_and_focus_buttons(root)
            return


func _enable_and_focus_buttons(root: Node) -> bool:
    if root is Button and (root as Button).visible and not (root as Button).disabled:
        (root as Button).focus_mode = Control.FOCUS_ALL
        (root as Button).grab_focus()
        return true
    for child in root.get_children():
        if child is Button:
            (child as Button).focus_mode = Control.FOCUS_ALL
        if _enable_and_focus_buttons(child):
            return true
    return false


func _release_focus_position() -> Vector3:
    if follow_operation and long_operation_director != null:
        var target := long_operation_director.get_follow_target()
        if target != null:
            return target.global_position
    return player.global_position if player != null else Vector3.ZERO


func _spawn_enemy(position: Vector3, species: StringName) -> OrganicEnemy3D:
    var enemy := super._spawn_enemy(position, species)
    if balance_director != null:
        balance_director.apply_to_enemy(enemy)
    return enemy


func should_defer_spawn_visuals(position: Vector3) -> bool:
    if performance_director == null or player == null:
        return false
    return position.distance_to(_release_focus_position()) > performance_director.active_radius


func _spawn_salvage(position: Vector3, amount: int, display_name: String) -> SalvagePile3D:
    var adjusted := balance_director.scale_scrap_yield(amount) if balance_director != null else amount
    var pile := super._spawn_salvage(position, adjusted, display_name)
    pile.set_meta(&"release_base_scrap", amount)
    return pile


func _on_heartforge_destroyed() -> void:
    if progression != null and progression.has_effect(&"single_continuity_recovery") and not continuity_used:
        continuity_used = true
        heartforge.current_health = heartforge.maximum_health * 0.48
        heartforge.health_changed.emit(heartforge.current_health, heartforge.maximum_health)
        var loss := balance_director.continuity_scrap_loss() if balance_director != null else 180
        run_state.scrap = maxi(0, run_state.scrap - loss)
        run_state.scrap_changed.emit(run_state.scrap)
        run_state.log_event("Distributed Continuity rebuilt the Heartforge after catastrophic failure. The one-use reserve is gone.")
        hud.push_notification("DISTRIBUTED CONTINUITY CONSUMED · HEARTFORGE RECOVERED AT 48% · %d SCRAP LOST" % loss)
        return
    if endgame_director != null and not endgame_director.active_protocol.is_empty():
        endgame_director.fail_active_protocol("The Heartforge failed before the final protocol completed.")
    super._on_heartforge_destroyed()


func _on_endgame_completed(protocol_id: StringName, display_name: String, ending: String) -> void:
    balance_director.record_victory(run_state.elapsed_seconds)
    release_audio.notify_victory()
    _save_release_game()
    super._on_endgame_completed(protocol_id, display_name, ending)


func _save_game() -> void:
    _save_release_game()


func _load_game() -> void:
    _load_release_game()


func _save_release_game() -> bool:
    if not _release_save_is_safe():
        hud.push_notification(localization_service.text("save.deferred"))
        return false
    var snapshot := _collect_release_snapshot()
    var metadata := {
        "heartforge_tier": progression.heartforge_tier,
        "world_time_seconds": run_state.elapsed_seconds,
        "regions_discovered": region_director.discovered_count(),
        "first_victory": first_victory_achieved,
        "difficulty": String(balance_director.current_profile_id),
    }
    return transactional_save_service.save_snapshot(RELEASE_SLOT, snapshot, metadata)


func _load_release_game() -> bool:
    _close_operations_hud()
    _close_strategic_hud()
    if hud.forge_open:
        _close_forge_menu()
    var snapshot := transactional_save_service.load_snapshot(RELEASE_SLOT)
    if snapshot.is_empty() and _migrate_legacy_saves():
        snapshot = transactional_save_service.load_snapshot(RELEASE_SLOT)
    if snapshot.is_empty():
        var recovery_report := transactional_save_service.get_last_load_report()
        if str(recovery_report.get("error", "")).is_empty():
            hud.push_notification(localization_service.text("menu.no_save"))
        return false
    _restore_release_snapshot(snapshot)
    _start_release_world()
    return true


func _release_save_is_safe() -> bool:
    if player.is_channeling():
        return false
    return true


func _collect_release_snapshot() -> Dictionary:
    var robots: Array[Dictionary] = []
    for robot in autonomy_director.living_robots():
        robots.append({"name": String(robot.name), "archetype": String(robot.archetype), "level": robot.level, "position": _vector_to_array(robot.global_position), "health": robot.current_health})
    var salvage: Array[Dictionary] = []
    for pile in get_tree().get_nodes_in_group(&"salvage_piles"):
        if pile is SalvagePile3D:
            salvage.append({"position": _vector_to_array(pile.global_position), "remaining": pile.remaining_scrap, "display_name": pile.display_name, "base_scrap": int(pile.get_meta(&"release_base_scrap", pile.remaining_scrap))})
    var enemies: Array[Dictionary] = []
    for enemy in get_tree().get_nodes_in_group(&"organic_enemies"):
        if enemy is OrganicEnemy3D and enemy.is_alive():
            enemies.append({"species": String(enemy.species), "position": _vector_to_array(enemy.global_position), "health": enemy.current_health, "aggression": enemy.aggression})
    return {
        "schema_version": 4,
        "base": {
            "run_state": run_state.to_dictionary(),
            "player": {"position": _vector_to_array(player.global_position), "health": player.current_health},
            "heartforge": {"health": heartforge.current_health, "maximum_health": heartforge.maximum_health},
            "robots": robots,
            "salvage": salvage,
            "enemies": enemies,
            "ecology": ecology_director.to_dictionary(),
            "autonomy": autonomy_director.to_dictionary(),
        },
        "foundation": {
            "progression": progression.to_dictionary(),
            "outposts": outpost_director.to_dictionary(),
            "foundation_milestone_complete": full_game_milestone_complete,
        },
        "complete": {
            "regions": region_director.to_dictionary(),
            "long_operations": long_operation_director.to_dictionary(),
            "machine_society": machine_society_director.to_dictionary(),
            "strategic_ecology": strategic_ecology_director.to_dictionary(),
            "endgame": endgame_director.to_dictionary(),
            "continuity_used": continuity_used,
            "first_victory_achieved": first_victory_achieved,
            "spawned_region_salvage": _serialize_stringname_dictionary(spawned_region_salvage),
        },
        "release": {
            "balance": balance_director.to_dictionary(),
            "performance": performance_director.to_dictionary(),
            "audio": release_audio.to_dictionary(),
            "release_started": release_started,
        },
    }


func _restore_release_snapshot(snapshot: Dictionary) -> void:
    var base: Dictionary = snapshot.get("base", {})
    _clear_runtime_entities()
    run_state.restore_from_dictionary(base.get("run_state", {}))
    if run_variation_director != null:
        run_variation_director.ensure_current_variant()
    var player_data: Dictionary = base.get("player", {})
    player.global_position = _array_to_vector(player_data.get("position", [0, 0, 6]))
    player.current_health = clampf(float(player_data.get("health", player.maximum_health)), 0.0, player.maximum_health)
    player.health_changed.emit(player.current_health, player.maximum_health)
    var forge_data: Dictionary = base.get("heartforge", {})
    heartforge.maximum_health = maxf(100.0, float(forge_data.get("maximum_health", heartforge.maximum_health)))
    heartforge.current_health = clampf(float(forge_data.get("health", heartforge.maximum_health)), 0.0, heartforge.maximum_health)
    heartforge.health_changed.emit(heartforge.current_health, heartforge.maximum_health)

    for robot_data in base.get("robots", []):
        var archetype := StringName(str(robot_data.get("archetype", "salvager")))
        var robot := _spawn_robot(archetype, _array_to_vector(robot_data.get("position", [0, 0, 4])), int(robot_data.get("level", 1)))
        var saved_name := str(robot_data.get("name", ""))
        if not saved_name.is_empty():
            robot.name = saved_name
        robot.current_health = clampf(float(robot_data.get("health", robot.maximum_health)), 0.0, robot.maximum_health)
        if archetype == &"companion":
            companion = robot

    for pile_data in base.get("salvage", []):
        var pile := _spawn_salvage(_array_to_vector(pile_data.get("position", [0, 0, -12])), int(pile_data.get("base_scrap", pile_data.get("remaining", 0))), str(pile_data.get("display_name", "Wreckage")))
        pile.remaining_scrap = int(pile_data.get("remaining", pile.remaining_scrap))
        if pile.remaining_scrap <= 0:
            pile.visible = false
            pile.collision_layer = 0

    for enemy_data in base.get("enemies", []):
        var enemy := _spawn_enemy(_array_to_vector(enemy_data.get("position", [20, 0, -20])), StringName(str(enemy_data.get("species", "skitterling"))))
        enemy.current_health = clampf(float(enemy_data.get("health", enemy.maximum_health)), 0.0, enemy.maximum_health)
        enemy.aggression = clampf(float(enemy_data.get("aggression", enemy.aggression)), 0.0, 1.0)
    ecology_director.restore_from_dictionary(base.get("ecology", {}))
    autonomy_director.restore_from_dictionary(base.get("autonomy", {}))

    var foundation: Dictionary = snapshot.get("foundation", {})
    progression.restore_from_dictionary(foundation.get("progression", {}))
    outpost_director.restore_from_dictionary(foundation.get("outposts", {}))
    full_game_milestone_complete = bool(foundation.get("foundation_milestone_complete", false))

    var complete: Dictionary = snapshot.get("complete", {})
    region_director.restore_from_dictionary(complete.get("regions", {}))
    long_operation_director.restore_from_dictionary(complete.get("long_operations", {}))
    machine_society_director.restore_from_dictionary(complete.get("machine_society", {}))
    strategic_ecology_director.restore_from_dictionary(complete.get("strategic_ecology", {}))
    endgame_director.restore_from_dictionary(complete.get("endgame", {}))
    if endgame_escalation_director != null:
        endgame_escalation_director.sync_from_endgame_state()
    continuity_used = bool(complete.get("continuity_used", false))
    first_victory_achieved = bool(complete.get("first_victory_achieved", false))
    spawned_region_salvage.clear()
    var saved_salvage: Dictionary = complete.get("spawned_region_salvage", {})
    for raw_key in saved_salvage:
        spawned_region_salvage[StringName(str(raw_key))] = bool(saved_salvage[raw_key])
    for region_data in region_director.discovered_regions():
        _ensure_region_salvage(StringName(str(region_data.get("id", ""))))

    var release: Dictionary = snapshot.get("release", {})
    balance_director.restore_from_dictionary(release.get("balance", {}))
    performance_director.restore_from_dictionary(release.get("performance", {}))
    release_audio.restore_from_dictionary(release.get("audio", {}))
    progression._evaluate_automatic_technologies()
    _apply_balance_profile()
    _update_hud_from_state()
    spatial_index.rebuild()
    performance_director.force_evaluate_for_test()


func _migrate_legacy_saves() -> bool:
    var base := _read_json_dictionary(LEGACY_BASE_SAVE)
    var foundation := _read_json_dictionary(LEGACY_FOUNDATION_SAVE)
    var complete := _read_json_dictionary(LEGACY_COMPLETE_SAVE)
    if base.is_empty() and foundation.is_empty() and complete.is_empty():
        return false
    var snapshot := {
        "schema_version": 4,
        "base": base,
        "foundation": foundation,
        "complete": complete,
        "release": {"balance": balance_director.to_dictionary(), "performance": performance_director.to_dictionary(), "audio": release_audio.to_dictionary(), "release_started": true},
    }
    var sources: Array[String] = []
    for path in [LEGACY_BASE_SAVE, LEGACY_FOUNDATION_SAVE, LEGACY_COMPLETE_SAVE]:
        if FileAccess.file_exists(path):
            sources.append(path)
    return transactional_save_service.migrate_legacy_payload(RELEASE_SLOT, snapshot, sources)


func _read_json_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    return (parsed as Dictionary).duplicate(true) if parsed is Dictionary else {}


func _legacy_save_exists() -> bool:
    return FileAccess.file_exists(LEGACY_BASE_SAVE) or FileAccess.file_exists(LEGACY_FOUNDATION_SAVE) or FileAccess.file_exists(LEGACY_COMPLETE_SAVE)


func _is_headless_release() -> bool:
    return DisplayServer.get_name() == "headless" or OS.has_feature("server")
