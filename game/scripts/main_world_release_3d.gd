class_name IronwrightReleaseWorld3D
extends IronwrightProductionWorld3D

const RELEASE_SLOT: StringName = &"world_0"
const LEGACY_BASE_SAVE := "user://ironwright_first_light_3d.json"
const LEGACY_FOUNDATION_SAVE := "user://ironwright_full_game_extension.json"
const LEGACY_COMPLETE_SAVE := "user://ironwright_complete_game_state.json"
const VERTICAL_SLICE_DIRECTOR := preload("res://scripts/presentation/vertical_slice_readable_director_3d.gd")
const VERTICAL_SLICE_ACTOR_ART := preload("res://scripts/presentation/vertical_slice_actor_art_3d.gd")
const RUN_VARIATION_SCRIPT := preload("res://scripts/presentation/run_variation_director_3d.gd")
const SESSION_DIAGNOSTICS_SCRIPT := preload("res://scripts/release/release_session_diagnostics_service_3d.gd")
const COLOR_FILTER_SCRIPT := preload("res://scripts/release/release_color_filter_3d.gd")
const REMOTE_CAMERA_HEIGHT_EXPANSION := 5.5
const REMOTE_CAMERA_DISTANCE_EXPANSION := 6.5
const OBSERVATORY_PRESENTATION_REVIEW_SCENE: PackedScene = preload("res://assets/observatory/observatory.gltf")
const BURIED_LABS_PRESENTATION_REVIEW_SCENE: PackedScene = preload("res://assets/buried_labs/buried_labs.gltf")

static var pending_launch_mode: StringName = &"title"

const PRESENTATION_REVIEW_FRIENDLIES: Array[StringName] = [
	&"companion", &"guardian", &"salvager", &"scout", &"engineer", &"relay",
]
const PRESENTATION_REVIEW_EARLY_ORGANICS: Array[StringName] = [
	&"skitterling", &"razorhound", &"roofleaper", &"glassmoth", &"veilstalker", &"burrower", &"sporecaster",
]
const PRESENTATION_REVIEW_LATE_ORGANICS: Array[StringName] = [
	&"broodmass", &"miremaw", &"carrionbell", &"rootweaver", &"thornback", &"ashmantle", &"apex",
]
const PRESENTATION_REVIEW_REGIONS: Array[StringName] = [
	&"region.north_ruins", &"region.west_grid", &"region.east_tenements",
	&"region.glasshouse", &"region.flood_market", &"region.riverworks",
	&"region.tram_graveyard", &"region.cathedral_quarter", &"region.observatory_ridge",
	&"region.buried_labs", &"region.root_cistern",
]
const ROOT_CISTERN_PRESENTATION_REVIEW_SCENE: PackedScene = preload("res://assets/root_cistern/root_cistern.gltf")

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
var release_color_filter: ReleaseColorFilter3D
var session_diagnostics: ReleaseSessionDiagnostics3D
var release_started: bool = false
var controller_action_cooldown: float = 0.0
var release_save_clock: float = 0.0
var _last_map_label_mode: bool = false
var vertical_slice: VerticalSliceDirector3D
var vertical_slice_actor_art: VerticalSliceActorArt3D
var run_variation_director: RunVariationDirector3D
var camera_target_velocity: Vector3 = Vector3.ZERO
var camera_heading: Vector3 = Vector3(0.0, 0.0, 1.0)
var release_camera_departure_clock: float = 0.0
var presentation_review_active: bool = false
var presentation_review_page: int = 0
var presentation_review_pages: Array = []
var presentation_review_label: Label
var presentation_review_stage: Node3D
var presentation_review_camera_target: Vector3 = Vector3.ZERO
var presentation_review_camera_desired: Vector3 = Vector3(0.0, 4.8, 18.0)
var endgame_protocol_review_active: bool = false
var endgame_protocol_review_clock: float = 0.0
var endgame_protocol_review_completed: bool = false


func _ready() -> void:
	super._ready()
	_setup_vertical_slice_presentation()
	_setup_release_services()
	_connect_release_services()
	_apply_release_settings()
	_apply_balance_to_existing_world()
	call_deferred("_finish_release_boot")


func _process(delta: float) -> void:
	if presentation_review_active:
		_update_presentation_review_camera(delta)
		return
	super._process(delta)
	if map_mode != _last_map_label_mode:
		_last_map_label_mode = map_mode
		_set_region_map_emphasis(map_mode)
	controller_action_cooldown = maxf(0.0, controller_action_cooldown - delta)
	release_save_clock += delta
	if endgame_protocol_review_active and not endgame_protocol_review_completed:
		endgame_protocol_review_clock += delta
		# Hold the real active-protocol frame long enough for visual and audio
		# review, then use the director's normal completion signal to show the
		# actual victory overlay and sanctuary crown. This mode never saves.
		if endgame_protocol_review_clock >= 8.0 and endgame_director != null and not endgame_director.active_protocol.is_empty():
			endgame_protocol_review_completed = true
			endgame_director._complete_active_protocol()
	if release_started:
		_handle_controller_actions()
	if release_front_end != null and release_front_end.is_modal_open():
		_ensure_modal_focus()


func _on_player_died() -> void:
	if session_diagnostics != null:
		session_diagnostics.record_event(&"player_defeat", "The Mechromancer was lost.")
	super._on_player_died()


func _setup_vertical_slice_presentation() -> void:
	# Keep the Heartforge readable while giving the Mechromancer and companion
	# enough screen presence for their authored silhouettes to carry the frame.
	# Bring the vulnerable technician and indispensable companion into the
	# opening's visual foreground while retaining the forge, weather and
	# amber escape lane as readable context.
	camera_height = 11.8
	camera_distance = 8.8
	# A slight opening-only yaw separates the vulnerable Mechromancer from the
	# Bulwark's close protection slot without changing movement, formation or
	# the Heartforge escape lane.
	camera_heading = Vector3(0.62, 0.0, 0.78).normalized()
	if camera != null:
		camera.fov = 44.5
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
	run_variation_director.configure(run_state, vertical_slice, region_atmosphere_director, strategic_ecology_director)
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
	if not follow_operation or long_operation_director == null or long_operation_director.active_operation.is_empty():
		release_camera_departure_clock = 0.0

	if map_mode:
		var map_target := Vector3(0.0, 0.0, -8.0)
		if region_director != null and region_director.discovered_count() > 1:
			map_target = _discovered_region_centroid()
		var desired_map_position := map_target + Vector3(0.0, 82.0, 10.0)
		camera.global_position = camera.global_position.lerp(desired_map_position, 1.0 - exp(-delta * 4.2))
		camera.look_at(map_target, Vector3.FORWARD)
		return

	var target := player.global_position
	var home_focus := false
	if follow_operation:
		var operation_target := _active_follow_target()
		if operation_target != null:
			target = operation_target.global_position
			if long_operation_director != null and not long_operation_director.active_operation.is_empty():
				release_camera_departure_clock += delta
				home_focus = release_camera_departure_clock < 3.0 or operation_target.global_position.distance_to(heartforge.global_position) < 18.0
				if home_focus:
					target = player.global_position
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
		# Remote landmarks need enough breadth to establish their identity, but
		# the expedition cast must remain readable as the player enters them.
		var remote_expansion := _remote_camera_expansion()
		dynamic_height += remote_expansion.x
		dynamic_distance += remote_expansion.y
	var desired := target + Vector3(0.0, dynamic_height, 0.0) + _camera_horizontal_offset(dynamic_distance)
	var resolved := desired if home_focus else _resolve_camera_occlusion(target, desired, dynamic_height, dynamic_distance)
	if camera.global_position.distance_to(resolved) > 20.0:
		camera.global_position = resolved
	else:
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


func _remote_camera_expansion() -> Vector2:
	return Vector2(REMOTE_CAMERA_HEIGHT_EXPANSION, REMOTE_CAMERA_DISTANCE_EXPANSION)


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
	var candidates: Array[Vector3] = [
		desired,
		target + Vector3(-dynamic_distance * 0.82, dynamic_height + 2.0, dynamic_distance * 0.42),
		target + Vector3(dynamic_distance * 0.82, dynamic_height + 2.0, dynamic_distance * 0.42),
		target + Vector3(-dynamic_distance * 0.72, dynamic_height + 5.5, -dynamic_distance * 0.54),
		target + Vector3(dynamic_distance * 0.72, dynamic_height + 5.5, -dynamic_distance * 0.54),
		target + Vector3(0.0, dynamic_height + 8.0, dynamic_distance * 0.22),
		target + Vector3(0.0, dynamic_height + 16.0, 0.0),
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
		# If the landmark is surrounded by tall city geometry, keep a high
		# establishing shot instead of parking the camera against the hit face.
		return candidates[candidates.size() - 1]
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
	if presentation_review_active:
		if event is InputEventKey and event.pressed and not event.echo:
			var review_key := (event as InputEventKey).keycode
			if review_key == 0:
				review_key = (event as InputEventKey).physical_keycode
			match review_key:
				KEY_1:
					_show_presentation_review_page(0)
				KEY_2:
					_show_presentation_review_page(1)
				KEY_3:
					_show_presentation_review_page(2)
				KEY_4:
					_show_presentation_review_page(3)
				KEY_5:
					_show_presentation_review_page(4)
				KEY_6:
					_show_presentation_review_page(5)
				KEY_7:
					_show_presentation_review_page(6)
				KEY_8:
					_show_presentation_review_page(7)
				KEY_9:
					_show_presentation_review_page(8)
				KEY_0:
					_show_presentation_review_page(9)
				KEY_LEFT, KEY_UP:
					_show_presentation_review_page(presentation_review_page - 1)
				KEY_RIGHT, KEY_DOWN:
					_show_presentation_review_page(presentation_review_page + 1)
				KEY_ESCAPE:
					get_tree().quit()
			get_viewport().set_input_as_handled()
		return
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

	session_diagnostics = SESSION_DIAGNOSTICS_SCRIPT.new() as ReleaseSessionDiagnostics3D
	session_diagnostics.name = "SessionDiagnostics"
	session_diagnostics.process_mode = Node.PROCESS_MODE_ALWAYS
	session_diagnostics.configure(str(ProjectSettings.get_setting("application/config/version", "unknown")))
	add_child(session_diagnostics)

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

	release_color_filter = COLOR_FILTER_SCRIPT.new() as ReleaseColorFilter3D
	release_color_filter.name = "ReleaseColorFilter"
	release_color_filter.configure(settings_service)
	add_child(release_color_filter)

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
	release_front_end.presentation_review_requested.connect(func() -> void:
		_start_release_world()
		call_deferred("_start_presentation_review")
	)
	release_front_end.quit_requested.connect(func() -> void:
		if session_diagnostics != null:
			session_diagnostics.mark_clean_shutdown("menu_quit")
		get_tree().quit()
	)
	release_front_end.settings_applied.connect(_on_front_end_settings_applied)

	settings_service.settings_changed.connect(func(next_settings: Dictionary) -> void:
		_apply_release_settings()
	)
	settings_service.input_device_changed.connect(func(_device_kind: StringName) -> void:
		refresh_input_legend()
	)
	settings_service.controller_connection_changed.connect(_on_controller_connection_changed)
	transactional_save_service.save_completed.connect(func(slot_id: StringName, path: String) -> void:
		session_diagnostics.record_event(&"save_completed", "Transactional run snapshot committed.", {"slot": String(slot_id)})
		hud.push_notification(localization_service.text("save.saved"))
	)
	transactional_save_service.save_failed.connect(func(slot_id: StringName, reason: String) -> void:
		session_diagnostics.record_event(&"save_failed", reason, {"slot": String(slot_id)})
		hud.push_notification("%s · %s" % [localization_service.text("save.failed"), reason.to_upper()])
	)
	transactional_save_service.load_completed.connect(func(slot_id: StringName, source_path: String, recovered_backup: bool) -> void:
		hud.push_notification(localization_service.text("save.invalid") if recovered_backup else localization_service.text("save.loaded"))
	)
	transactional_save_service.load_failed.connect(func(slot_id: StringName, report: Dictionary) -> void:
		session_diagnostics.record_event(&"load_failed", "Transactional load failed.", {"slot": String(slot_id), "attempts": report.get("attempts", []).size()})
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
	elif _has_heartforge_progression_review_flag():
		_start_release_world()
		call_deferred("_start_heartforge_progression_review")
	elif _has_endgame_protocol_review_flag():
		_start_release_world()
		call_deferred("_start_endgame_protocol_review")
	elif _has_mechromancer_evolution_review_flag():
		_start_release_world()
		call_deferred("_start_mechromancer_evolution_review")
	elif _has_presentation_review_flag():
		_start_release_world()
		call_deferred("_start_presentation_review")
	elif _has_route_memory_review_flag():
		_start_release_world()
		call_deferred("_start_route_memory_review")
	elif _has_dynamic_operation_review_flag():
		_start_release_world()
		call_deferred("_start_dynamic_operation_review")
	elif _has_casualty_recovery_review_flag():
		_start_release_world()
		call_deferred("_start_casualty_recovery_review")
	elif mode == &"new":
		_start_release_world()
	elif mode == &"continue":
		_start_release_world()
		_load_release_game()
	else:
		_show_title_screen()


func _has_presentation_review_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == "--presentation-review":
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument) == "--presentation-review":
			return true
	return false


func _has_mechromancer_evolution_review_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == "--mechromancer-evolution-review":
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument) == "--mechromancer-evolution-review":
			return true
	return false


func _has_heartforge_progression_review_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == "--heartforge-progression-review":
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument) == "--heartforge-progression-review":
			return true
	return false


func _has_endgame_protocol_review_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == "--endgame-protocol-review":
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument) == "--endgame-protocol-review":
			return true
	return false


func _has_route_memory_review_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == "--route-memory-review":
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument) == "--route-memory-review":
			return true
	return false


func _has_dynamic_operation_review_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == "--dynamic-operation-review":
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument) == "--dynamic-operation-review":
			return true
	return false


func _has_casualty_recovery_review_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == "--casualty-recovery-review":
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument) == "--casualty-recovery-review":
			return true
	return false


func _start_presentation_review() -> void:
	presentation_review_active = true
	presentation_review_page = 0
	# The gallery is an authored visual fixture, not a normal run. Reveal every
	# regional story witness here so the exact Windows review can judge the
	# physical archive connection while ordinary gameplay remains discovery-gated.
	if region_director != null:
		for region_id in PRESENTATION_REVIEW_REGIONS:
			region_director.discover_region(region_id)
	if story_archive_director != null:
		story_archive_director.reconcile_discovered_state()
	player.input_enabled = false
	player.set_physics_process(false)
	player.set_process(false)
	if hud != null:
		hud.visible = false
	if strategic_hud != null:
		strategic_hud.visible = false
	if operations_hud != null:
		operations_hud.visible = false
	if release_front_end != null:
		release_front_end.hide_all()

	var review_layer := CanvasLayer.new()
	review_layer.name = "PresentationReviewLayer"
	review_layer.layer = 120
	add_child(review_layer)
	presentation_review_label = Label.new()
	presentation_review_label.name = "PresentationReviewLabel"
	presentation_review_label.position = Vector2(34.0, 26.0)
	presentation_review_label.add_theme_font_size_override("font_size", 22)
	presentation_review_label.add_theme_color_override("font_color", Color("f1dfb8"))
	presentation_review_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.86))
	presentation_review_label.add_theme_constant_override("shadow_offset_x", 2)
	presentation_review_label.add_theme_constant_override("shadow_offset_y", 2)
	review_layer.add_child(presentation_review_label)

	presentation_review_pages = [[], [], []]
	for _region_id in PRESENTATION_REVIEW_REGIONS:
		presentation_review_pages.append([])
	presentation_review_pages[0].append(player)
	var companion := get_node_or_null("Bulwark_01") as Node3D
	if companion != null:
		presentation_review_pages[0].append(companion)
	for archetype in PRESENTATION_REVIEW_FRIENDLIES:
		if archetype == &"companion":
			continue
		var robot := _spawn_robot(archetype, Vector3.ZERO, 1) as Node3D
		if robot != null:
			robot.set_physics_process(false)
			robot.set_process(false)
			presentation_review_pages[0].append(robot)
	for species in PRESENTATION_REVIEW_EARLY_ORGANICS:
		var enemy := _spawn_enemy(Vector3.ZERO, species) as Node3D
		if enemy != null:
			enemy.set_physics_process(false)
			enemy.set_process(false)
			presentation_review_pages[1].append(enemy)
	for species in PRESENTATION_REVIEW_LATE_ORGANICS:
		var enemy := _spawn_enemy(Vector3.ZERO, species) as Node3D
		if enemy != null:
			enemy.set_physics_process(false)
			enemy.set_process(false)
			presentation_review_pages[2].append(enemy)
	for index in PRESENTATION_REVIEW_REGIONS.size():
		var landmark := _presentation_review_landmark(PRESENTATION_REVIEW_REGIONS[index])
		var review_actor: Node3D = landmark
		if PRESENTATION_REVIEW_REGIONS[index] == &"region.root_cistern" and landmark != null:
			review_actor = _create_root_cistern_presentation_review_actor(landmark)
		elif PRESENTATION_REVIEW_REGIONS[index] == &"region.observatory_ridge" and landmark != null:
			review_actor = _create_observatory_presentation_review_actor(landmark)
		elif PRESENTATION_REVIEW_REGIONS[index] == &"region.buried_labs" and landmark != null:
			review_actor = _create_buried_labs_presentation_review_actor(landmark)
		if review_actor != null:
			landmark.set_presentation_detail_level(0)
			landmark.set_map_emphasis(false)
			presentation_review_pages[3 + index].append(review_actor)
	_create_presentation_review_stage()
	_show_presentation_review_page(0)
	get_tree().paused = true
	run_state.log_event("Presentation review mode: 1 friendly roster, 2 early organics, 3 late organics, 4-14 all remote regions. Arrow keys browse; Escape exits review.")


func _start_mechromancer_evolution_review() -> void:
	if progression != null:
		progression.set_heartforge_tier(5)
		for effect_id in [
			&"unlock_machine_society",
			&"unlock_adaptive_defence",
			&"unlock_final_protocol_research",
			&"machine_signal_lattice",
		]:
			progression.unlocked_effects[effect_id] = true
		progression.progression_changed.emit()
	_start_presentation_review()
	if presentation_review_label != null:
		presentation_review_label.text = "MECHROMANCER EVOLUTION REVIEW  ·  HEARTFORGE TIER V\nTIER II FIELD RIG  ·  TIER III COGNITION LATTICE  ·  TIER IV BIO-SENSOR  ·  TIER V PROTOCOL HARDWARE"


func _start_heartforge_progression_review() -> void:
	if progression != null:
		progression.set_heartforge_tier(5)
		for effect_id in [
			&"unlock_machine_society",
			&"unlock_adaptive_defence",
			&"unlock_final_protocol_research",
			&"machine_signal_lattice",
		]:
			progression.unlocked_effects[effect_id] = true
		progression.progression_changed.emit()
	if hud != null:
		hud.push_notification("HEARTFORGE PROGRESSION REVIEW · TIER V CROWN ACTIVE")
	if run_state != null:
		run_state.log_event("Heartforge progression review mode: Tier V authored hardware and presentation motion are active in the opening tactical frame.")
	# The review flag can raise the tier before the release audio node finishes
	# its deferred ready path. Re-submit the same signal through the audio
	# director so the exact exported review also exercises the localized
	# progression cue; its own tier guard prevents duplicate playback in normal
	# gameplay.
	if release_audio != null and progression != null:
		release_audio.call_deferred("_on_heartforge_tier_changed", progression.heartforge_tier)


func _start_endgame_protocol_review() -> void:
	# This is a non-saving fixture for the exact exported build. It satisfies the
	# same late-run data contracts as a real run, then enters the ordinary
	# player-triggered protocol path so the review covers both crisis and victory
	# presentation without inventing a parallel cutscene system.
	endgame_protocol_review_active = true
	endgame_protocol_review_clock = 0.0
	endgame_protocol_review_completed = false
	if progression != null:
		progression.set_heartforge_tier(5)
		for technology_id in [&"tech.endgame.severance", &"tech.endgame.containment"]:
			if technology_id not in progression.unlocked_technologies:
				progression.unlocked_technologies.append(technology_id)
		progression.unlocked_effects[&"unlock_final_protocol_research"] = true
		progression.progression_changed.emit()
	if long_operation_director != null:
		long_operation_director.completed_operations = [&"operation.root_cistern_mapping"]
		long_operation_director.recovered_components = [
			&"component.choral_gland",
			&"component.genome_prism",
			&"component.root_map",
			&"component.migration_ephemeris",
		]
	if run_state != null:
		run_state.scrap = 1200
		run_state.rare_cores = 8
	if region_director != null:
		region_director.discover_region(&"region.root_cistern")
	if endgame_director != null and endgame_director.initiate(&"protocol.severance"):
		if hud != null:
			hud.push_notification("FINAL PROTOCOL REVIEW · SEVERANCE LATTICE ACTIVE · VICTORY RESOLUTION IN 8 SECONDS")
		if run_state != null:
			run_state.log_event("Endgame protocol review mode: active Severance lattice will resolve through the ordinary victory path.")


func _create_presentation_review_stage() -> void:
	var preserved_nodes: Array[Node] = [camera]
	if release_world_art != null:
		preserved_nodes.append(release_world_art)
		# ReleaseWorldArtDirector3D owns the dressing controller, but its
		# presentation root is intentionally parented directly under the world so
		# region LOD and cleanup can address it as one bounded layer. Preserve that
		# sibling root as well or the exact gallery silently hides every release
		# dressing pass while leaving authored landmark geometry visible.
		if release_world_art.dressing_root != null:
			preserved_nodes.append(release_world_art.dressing_root)
	for page_actors in presentation_review_pages:
		for actor in page_actors:
			if is_instance_valid(actor):
				preserved_nodes.append(actor)
	for child in get_children():
		if child is Node3D and not preserved_nodes.has(child) and not (child is Camera3D) and not (child is DirectionalLight3D):
			(child as Node3D).visible = false

	presentation_review_stage = Node3D.new()
	presentation_review_stage.name = "PresentationReviewStage"
	add_child(presentation_review_stage)
	# Keep the gallery neutral enough for material inspection. The earlier nearly
	# black backdrop made the darker organic shells collapse into one value band.
	_add_presentation_review_box("ReviewFloor", Vector3(30.0, 0.35, 13.0), Vector3(0.0, -0.25, 0.0), Color("243744"), 0.44, 0.46)
	_add_presentation_review_box("ReviewBackdrop", Vector3(30.0, 11.0, 0.3), Vector3(0.0, 5.0, -3.8), Color("162936"), 0.05, 0.78)
	var front_fill := OmniLight3D.new()
	front_fill.name = "ReviewFrontFill"
	front_fill.position = Vector3(0.0, 6.2, 8.0)
	front_fill.omni_range = 28.0
	front_fill.light_energy = 3.4
	front_fill.light_color = Color("ffe1c1")
	front_fill.shadow_enabled = true
	presentation_review_stage.add_child(front_fill)
	var warm_light := OmniLight3D.new()
	warm_light.name = "ReviewWarmLight"
	warm_light.position = Vector3(-7.0, 6.0, 6.0)
	warm_light.omni_range = 24.0
	warm_light.light_energy = 3.6
	warm_light.light_color = Color("ffbd78")
	warm_light.shadow_enabled = true
	presentation_review_stage.add_child(warm_light)
	var cool_light := OmniLight3D.new()
	cool_light.name = "ReviewCoolLight"
	cool_light.position = Vector3(8.0, 5.0, 3.0)
	cool_light.omni_range = 22.0
	cool_light.light_energy = 2.8
	cool_light.light_color = Color("7ac7e8")
	cool_light.shadow_enabled = true
	presentation_review_stage.add_child(cool_light)
	var rim_light := OmniLight3D.new()
	rim_light.name = "ReviewRimLight"
	rim_light.position = Vector3(0.0, 4.8, -1.8)
	rim_light.omni_range = 25.0
	rim_light.light_energy = 4.2
	rim_light.light_color = Color("72c2ca")
	rim_light.shadow_enabled = true
	presentation_review_stage.add_child(rim_light)
	var organic_fill := OmniLight3D.new()
	organic_fill.name = "ReviewOrganicFill"
	organic_fill.position = Vector3(0.0, 3.8, 8.0)
	organic_fill.omni_range = 18.0
	organic_fill.light_energy = 0.0
	organic_fill.light_color = Color("d6aa8f")
	organic_fill.shadow_enabled = false
	presentation_review_stage.add_child(organic_fill)


func _add_presentation_review_box(node_name: String, size: Vector3, position: Vector3, color: Color, metallic: float, roughness: float, emission: Color = Color.BLACK) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box := BoxMesh.new()
	box.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = metallic
	material.roughness = roughness
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = 1.8
	box.material = material
	mesh_instance.mesh = box
	mesh_instance.position = position
	presentation_review_stage.add_child(mesh_instance)


func _show_presentation_review_page(page: int) -> void:
	if presentation_review_pages.size() != 3 + PRESENTATION_REVIEW_REGIONS.size():
		return
	presentation_review_page = clampi(page, 0, presentation_review_pages.size() - 1)
	for page_actors in presentation_review_pages:
		for actor in page_actors:
			if is_instance_valid(actor):
				actor.visible = false
	if release_world_art != null:
		for raw_region_id in release_world_art.region_dressing_roots:
			var dressing_root := release_world_art.region_dressing_root(raw_region_id as StringName)
			if dressing_root != null:
				dressing_root.visible = false
	var actors: Array = presentation_review_pages[presentation_review_page]
	var is_region_page := presentation_review_page >= 3
	var region_id := PRESENTATION_REVIEW_REGIONS[presentation_review_page - 3] if is_region_page else &""
	if is_region_page and release_world_art != null:
		var selected_region_dressing := release_world_art.region_dressing_root(region_id)
		if selected_region_dressing != null:
			selected_region_dressing.visible = true
	for index in actors.size():
		var actor := actors[index] as Node3D
		if actor == null or not is_instance_valid(actor):
			continue
		actor.visible = true
		if is_region_page:
			# Riverworks and Tram Graveyard place their service/focal face toward
			# the opposite side of the shared review camera. Correct only those two
			# authored orientations; other families keep their authored front.
			if region_id == &"region.riverworks" or region_id == &"region.tram_graveyard":
				actor.rotation.y = PI
			if actor.has_method("set_presentation_detail_level"):
				actor.call("set_presentation_detail_level", 0)
			var region_geometry := actor.get_node_or_null("PersistentRegionGeometry") as Node3D
			if region_geometry != null:
				region_geometry.visible = true
		else:
			actor.rotation.y = PI
			var row_index := 0 if index < mini(4, actors.size()) else 1
			var row_count := mini(4, actors.size()) if row_index == 0 else actors.size() - mini(4, actors.size())
			var row_position := index if row_index == 0 else index - mini(4, actors.size())
			# The organic roster needs a true detail frame. Its authored shells
			# carry fine veins, membrane ribs, crown plates and threat sockets that
			# collapse into one silhouette band at the old spacing. Keep the actor
			# roots and gameplay scale untouched; only the bounded review fixture
			# gets a closer two-row composition.
			var spacing := 2.9 if presentation_review_page >= 1 else 4.2
			var centered_x := (float(row_position) - float(row_count - 1) * 0.5) * spacing
			var row_z := 0.82 if row_index == 0 else -1.72
			if presentation_review_page == 0:
				row_z = 0.7 if row_index == 0 else -2.5
			row_z += _presentation_review_depth_offset(actor)
			actor.scale = Vector3.ONE
			var review_model_root := actor.get_node_or_null("OrganicModel") as Node3D
			if review_model_root != null:
				review_model_root.scale = Vector3.ONE * _presentation_review_model_scale(actor)
			actor.position = Vector3(centered_x, 0.0, row_z)
			if actor.has_method("set_visual_lod"):
				actor.call("set_visual_lod", 0)
	var page_titles: Array[String] = [
		"PLAYER + FRIENDLY MACHINE SOCIETY", "EARLY ORGANIC FAMILIES", "LATE ORGANIC FAMILIES",
		"REMOTE · NORTH RUINS", "REMOTE · WEST GRID", "REMOTE · EAST TENEMENTS",
		"REMOTE · MUNICIPAL GLASSHOUSE", "REMOTE · FLOOD MARKET", "REMOTE · RIVERWORKS",
		"REMOTE · TRAM GRAVEYARD", "REMOTE · CATHEDRAL QUARTER", "REMOTE · OBSERVATORY RIDGE",
		"REMOTE · BURIED LABORATORIES", "REMOTE · ROOT CISTERN",
	]
	var page_title: String = page_titles[presentation_review_page]
	presentation_review_label.text = "PRESENTATION REVIEW  ·  %s  ·  %d/%d\n1-9 / 0 DIRECT PAGE   ←/→ BROWSE   ESC EXIT" % [page_title, presentation_review_page + 1, presentation_review_pages.size()]
	if is_region_page and not actors.is_empty():
		presentation_review_camera_target = (actors[0] as Node3D).global_position + Vector3.UP * 2.0
		presentation_review_camera_desired = presentation_review_camera_target + _presentation_review_region_camera_offset(region_id)
	elif is_region_page and region_director != null:
		presentation_review_camera_target = region_director.center(region_id) + Vector3.UP * 2.0
		presentation_review_camera_desired = presentation_review_camera_target + Vector3(0.0, 12.0, 19.0)
	else:
		var core_target_height := 1.08 if presentation_review_page >= 1 else 1.45
		var core_target_depth := -0.38 if presentation_review_page >= 1 else -0.7
		presentation_review_camera_target = Vector3(0.0, core_target_height, core_target_depth)
		presentation_review_camera_desired = Vector3(0.0, 4.45, 11.15) if presentation_review_page >= 1 else Vector3(0.0, 4.8, 12.5)
	_set_presentation_review_stage_for_page(is_region_page)
	_update_presentation_review_camera(1.0)


func _presentation_review_region_camera_offset(region_id: StringName) -> Vector3:
	# Small, vertically focused authored landmarks need a closer review frame;
	# otherwise the shared remote-region camera makes their detail impossible to
	# judge against the broader districts. A bounded diagonal offset also keeps
	# layered service geometry from collapsing into a flat elevation.
	if region_id == &"region.riverworks":
		return Vector3(8.2, 9.2, 14.4)
	if region_id == &"region.tram_graveyard":
		# Lower the rail frame enough for the carriage sides, windows and
		# undercarriages to read as depth rather than a stack of roof planes.
		return Vector3(-8.0, 7.4, 13.8)
	if region_id == &"region.flood_market":
		return Vector3(8.5, 9.4, 15.4)
	if region_id == &"region.cathedral_quarter":
		return Vector3(0.0, 10.5, 17.0)
	if region_id == &"region.observatory_ridge":
		# The authored dish is vertically dominant; give the review camera enough
		# distance to keep the dish, mast, service ring and platform in one frame.
		return Vector3(0.0, 10.2, 17.0)
	if region_id == &"region.buried_labs":
		return Vector3(0.0, 10.2, 15.0)
	if region_id == &"region.north_ruins":
		return Vector3(-7.0, 9.6, 14.8)
	return Vector3(0.0, 12.0, 19.0)


func _presentation_review_depth_offset(actor: Node3D) -> float:
	# Small organisms are staged slightly forward in the development-only gallery
	# so perspective gives their authored anatomy room without stretching child
	# offsets or touching runtime actor scale, collision, damage, ecology or
	# navigation.
	var actor_name := actor.name.to_lower()
	if actor_name.begins_with("skitterling"):
		return 1.0
	if actor_name.begins_with("glassmoth"):
		return 0.8
	if actor_name.begins_with("roofleaper"):
		return 0.3
	return 0.0


func _presentation_review_model_scale(actor: Node3D) -> float:
	# Apply only a restrained visual-root compensation for families authored at
	# a smaller inspection scale. The actor root remains at unit scale.
	var actor_name := actor.name.to_lower()
	if actor_name.begins_with("glassmoth"):
		return 1.1
	return 1.0

func _presentation_review_landmark(region_id: StringName) -> RegionLandmark3D:
	if region_director == null:
		return null
	var direct := region_director.get_landmark(region_id)
	if direct != null:
		return direct
	for raw_landmark in region_director.landmarks.values():
		var landmark := raw_landmark as RegionLandmark3D
		if landmark != null and landmark.region_id == region_id:
			return landmark
	return null


func _create_root_cistern_presentation_review_actor(landmark: RegionLandmark3D) -> Node3D:
	var review_actor := Node3D.new()
	review_actor.name = "RootCisternPresentationReviewActor"
	add_child(review_actor)
	review_actor.global_position = landmark.global_position
	var authored_scene := ROOT_CISTERN_PRESENTATION_REVIEW_SCENE.instantiate()
	authored_scene.name = "RootCisternPresentationReviewModel"
	review_actor.add_child(authored_scene)
	_tune_root_cistern_basin_material(authored_scene)
	var presentation_surface := landmark.find_child("AuthoredDistrictSurfaceFinish", true, false) as Node3D
	if presentation_surface != null:
		# Root Cistern's generic district apron blooms into a white card at the
		# exact review scale. The authored basin and release dressing already
		# provide the readable ground anchor for this bounded presentation page.
		presentation_surface.visible = false
	var persistent_geometry := landmark.get_node_or_null("PersistentRegionGeometry") as Node3D
	if persistent_geometry != null:
		persistent_geometry.visible = false
	return review_actor


func _tune_root_cistern_basin_material(scene_root: Node) -> void:
	# The dedicated exact-review actor is a second instance of the authored
	# scene, so it needs the same dark wet-concrete treatment as the persistent
	# landmark instance. Without this bounded presentation correction the
	# broad basin reads as a white card and hides the core hardware.
	if scene_root == null:
		return
	var basin := scene_root.find_child("RootCisternBasin", true, false) as MeshInstance3D
	if basin == null:
		return
	var material := basin.get_active_material(0) as StandardMaterial3D
	if material == null:
		return
	material = material.duplicate(true) as StandardMaterial3D
	material.albedo_color = Color("18282b")
	material.roughness = 0.82
	material.metallic = 0.04
	basin.material_override = material
	var water := scene_root.find_child("RootCisternBasinWater", true, false) as MeshInstance3D
	if water == null:
		return
	var water_material := water.get_active_material(0) as StandardMaterial3D
	if water_material == null:
		return
	water_material = water_material.duplicate(true) as StandardMaterial3D
	water_material.albedo_color = Color("0b2025")
	water_material.emission_enabled = false
	water_material.roughness = 0.34
	water_material.metallic = 0.08
	water.material_override = water_material


func _create_observatory_presentation_review_actor(landmark: RegionLandmark3D) -> Node3D:
	var review_actor := Node3D.new()
	review_actor.name = "ObservatoryPresentationReviewActor"
	add_child(review_actor)
	review_actor.global_position = landmark.global_position
	var authored_scene := OBSERVATORY_PRESENTATION_REVIEW_SCENE.instantiate()
	authored_scene.name = "ObservatoryPresentationReviewModel"
	review_actor.add_child(authored_scene)
	return review_actor


func _create_buried_labs_presentation_review_actor(landmark: RegionLandmark3D) -> Node3D:
	var review_actor := Node3D.new()
	review_actor.name = "BuriedLabsPresentationReviewActor"
	add_child(review_actor)
	review_actor.global_position = landmark.global_position
	var authored_scene := BURIED_LABS_PRESENTATION_REVIEW_SCENE.instantiate()
	authored_scene.name = "BuriedLabsPresentationReviewModel"
	review_actor.add_child(authored_scene)
	return review_actor


func _update_presentation_review_camera(delta: float) -> void:
	if camera == null:
		return
	var target := presentation_review_camera_target
	var desired := presentation_review_camera_desired
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-delta * 5.0))
	var core_review_fov := 42.0 if presentation_review_page >= 1 else 43.0
	camera.fov = 46.0 if presentation_review_page == 12 else (48.0 if presentation_review_page == 11 else (52.0 if presentation_review_page >= 3 else core_review_fov))
	camera.look_at(target, Vector3.UP)


func _set_presentation_review_stage_for_page(is_region_page: bool) -> void:
	if presentation_review_stage == null:
		return
	var target := presentation_review_camera_target if is_region_page else Vector3.ZERO
	var floor := presentation_review_stage.get_node_or_null("ReviewFloor") as Node3D
	var backdrop := presentation_review_stage.get_node_or_null("ReviewBackdrop") as Node3D
	var amber_band := presentation_review_stage.get_node_or_null("ReviewAmberBand") as Node3D
	var teal_band := presentation_review_stage.get_node_or_null("ReviewTealBand") as Node3D
	for node in [floor, backdrop, amber_band, teal_band]:
		if node != null:
			node.visible = not is_region_page
	var front_fill := presentation_review_stage.get_node_or_null("ReviewFrontFill") as OmniLight3D
	var warm_light := presentation_review_stage.get_node_or_null("ReviewWarmLight") as OmniLight3D
	var cool_light := presentation_review_stage.get_node_or_null("ReviewCoolLight") as OmniLight3D
	var rim_light := presentation_review_stage.get_node_or_null("ReviewRimLight") as OmniLight3D
	var organic_fill := presentation_review_stage.get_node_or_null("ReviewOrganicFill") as OmniLight3D
	# North Ruins' broad archive facade, West Grid's steel hall and ceramic
	# pressure tanks, East Tenements' brick blocks, Municipal Glasshouse's
	# transparent panes, Flood Market's broad canopy, Riverworks' pump housing,
	# and Tram Graveyard's carriage shells, plus Cathedral Quarter's broad nave,
	# need a lower presentation key so authored surfaces do not bloom into pale
	# blocks at the compact exact-export review size. Runtime lighting is
	# unchanged; region accents remain untouched. Observatory's dish and Buried
	# Laboratories' vessel bay and Root Cistern's core use the same review-only
	# restraint so their survey, containment, basin and pylon hardware stays
	# visible.
	var compact_region_light_scale := 1.0
	if presentation_review_page == 4:
		compact_region_light_scale = 0.46
	elif presentation_review_page == 5:
		compact_region_light_scale = 0.62
	elif presentation_review_page == 6:
		compact_region_light_scale = 0.64
	elif presentation_review_page == 7:
		compact_region_light_scale = 0.58
	elif presentation_review_page == 8:
		compact_region_light_scale = 0.60
	elif presentation_review_page == 9:
		compact_region_light_scale = 0.56
	elif presentation_review_page == 10:
		compact_region_light_scale = 0.58
	elif presentation_review_page == 11:
		compact_region_light_scale = 0.54
	elif presentation_review_page == 12:
		compact_region_light_scale = 0.60
	elif presentation_review_page == 13:
		# The authored Root Cistern basin carries a broad pale surface that
		# clips into a white disc under the shared compact key. Keep this
		# development-only review exposure lower so the core, service ring and
		# root anchors retain readable depth without changing runtime lighting.
		compact_region_light_scale = 0.32
	# Darker organic shells need a little more review-only key and rim energy
	# than the manufactured roster to keep wet materials and anatomy breaks
	# judgeable at the supported compact export size. Runtime lighting is untouched.
	var organic_gallery_light_scale := 1.38 if presentation_review_page >= 1 and presentation_review_page <= 2 else 1.0
	var review_light_scale := compact_region_light_scale * organic_gallery_light_scale
	var organic_page := presentation_review_page >= 1 and presentation_review_page <= 2
	if organic_fill != null:
		organic_fill.visible = organic_page
		organic_fill.light_energy = 1.75 if organic_page else 0.0
		organic_fill.position = target + Vector3(0.0, 4.0, 8.0)
	if front_fill != null:
		front_fill.light_energy = 3.4 * review_light_scale
		front_fill.position = target + Vector3(0.0, 9.0, 16.0)
	if warm_light != null:
		warm_light.light_energy = 3.6 * review_light_scale
		warm_light.position = target + Vector3(-12.0, 8.0, 10.0)
	if cool_light != null:
		cool_light.light_energy = 2.8 * review_light_scale
		cool_light.position = target + Vector3(12.0, 7.0, 6.0)
	if rim_light != null:
		rim_light.light_energy = 4.2 * review_light_scale
		rim_light.position = target + Vector3(0.0, 7.0, -8.0)


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
	refresh_input_legend()


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
	if session_diagnostics != null:
		session_diagnostics.record_event(&"heartforge_failure", "The Heartforge was destroyed.")
	if progression != null and progression.has_effect(&"single_continuity_recovery") and not continuity_used:
		continuity_used = true
		heartforge.current_health = heartforge.maximum_health * 0.48
		heartforge.health_changed.emit(heartforge.current_health, heartforge.maximum_health)
		var loss := balance_director.continuity_scrap_loss() if balance_director != null else 180
		run_state.scrap = maxi(0, run_state.scrap - loss)
		run_state.record_scrap_spend(loss, "continuity recovery")
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
	if not endgame_protocol_review_active:
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
	if has_method(&"_show_session_recap"):
		call(&"_show_session_recap")
	return true


func _release_save_is_safe() -> bool:
	if player.is_channeling():
		return false
	return true


func _collect_release_snapshot() -> Dictionary:
	var robots: Array[Dictionary] = []
	for robot in autonomy_director.living_robots():
		robots.append({"name": String(robot.name), "archetype": String(robot.archetype), "level": robot.level, "callsign": robot.callsign, "position": _vector_to_array(robot.global_position), "health": robot.current_health})
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
			"story_archive": story_archive_director.to_dictionary(),
			"long_operations": long_operation_director.to_dictionary(),
			"machine_society": machine_society_director.to_dictionary(),
			"strategic_ecology": strategic_ecology_director.to_dictionary(),
			"endgame": endgame_director.to_dictionary(),
			"continuity_used": continuity_used,
			"first_victory_achieved": first_victory_achieved,
			"spawned_region_salvage": _serialize_stringname_dictionary(spawned_region_salvage),
			"machine_relationship_moments": machine_relationship_moments.duplicate(true),
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
		robot.restore_callsign(robot_data.get("callsign", ""))
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
	var saved_story_archive: Variant = complete.get("story_archive", {})
	if saved_story_archive is Dictionary and not (saved_story_archive as Dictionary).is_empty():
		story_archive_director.restore_from_dictionary(saved_story_archive)
	long_operation_director.restore_from_dictionary(complete.get("long_operations", {}))
	machine_society_director.restore_from_dictionary(complete.get("machine_society", {}))
	strategic_ecology_director.restore_from_dictionary(complete.get("strategic_ecology", {}))
	endgame_director.restore_from_dictionary(complete.get("endgame", {}))
	if endgame_escalation_director != null:
		endgame_escalation_director.sync_from_endgame_state()
	continuity_used = bool(complete.get("continuity_used", false))
	first_victory_achieved = bool(complete.get("first_victory_achieved", false))
	var saved_relationship_moments: Variant = complete.get("machine_relationship_moments", {})
	machine_relationship_moments = saved_relationship_moments.duplicate(true) if saved_relationship_moments is Dictionary else {}
	spawned_region_salvage.clear()
	var saved_salvage: Dictionary = complete.get("spawned_region_salvage", {})
	for raw_key in saved_salvage:
		spawned_region_salvage[StringName(str(raw_key))] = bool(saved_salvage[raw_key])
	for region_data in region_director.discovered_regions():
		_ensure_region_salvage(StringName(str(region_data.get("id", ""))))
	story_archive_director.reconcile_discovered_state()

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
