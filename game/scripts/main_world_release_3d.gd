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
const OBSERVATORY_PRESENTATION_REVIEW_SCENE := "res://assets/observatory/observatory.gltf"
const BURIED_LABS_PRESENTATION_REVIEW_SCENE := "res://assets/buried_labs/buried_labs.gltf"
const TRAM_GRAVEYARD_PRESENTATION_REVIEW_SCENE := "res://assets/tram_graveyard/tram_graveyard.gltf"
const OUTPOST_PRESENTATION_REVIEW_SCENE := "res://scenes/world/outpost_3d.tscn"

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
const ROOT_CISTERN_PRESENTATION_REVIEW_SCENE := "res://assets/root_cistern/root_cistern.gltf"

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
var presentation_review_capture_path: String = ""
var presentation_review_capture_frames: int = 0
var endgame_protocol_review_active: bool = false
var endgame_protocol_review_clock: float = 0.0
var endgame_protocol_review_completed: bool = false
var endgame_protocol_review_capture_path: String = ""
var endgame_protocol_review_capture_frames: int = 0
var heartforge_progression_review_capture_path: String = ""
var heartforge_progression_review_capture_frames: int = 0
var title_review_capture_path: String = ""
var title_review_capture_frames: int = 0
var stream_ring_review_active: bool = false
var stream_ring_review_clock: float = 0.0
var stream_ring_review_phase: int = 0
var title_pause_timer: Timer


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
		if not presentation_review_capture_path.is_empty():
			presentation_review_capture_frames += 1
			if presentation_review_capture_frames == 45:
				var review_image := get_viewport().get_texture().get_image()
				var capture_error := review_image.save_png(presentation_review_capture_path)
				if capture_error == OK:
					print("Presentation review screenshot written to %s" % presentation_review_capture_path)
				else:
					push_error("Presentation review screenshot failed: %s" % capture_error)
				presentation_review_capture_path = ""
		return
	if stream_ring_review_active:
		_update_stream_ring_review(delta)
	super._process(delta)
	if not title_review_capture_path.is_empty():
		title_review_capture_frames += 1
		if title_review_capture_frames == 45:
			var review_image := get_viewport().get_texture().get_image()
			var capture_error := review_image.save_png(title_review_capture_path)
			if capture_error == OK:
				print("Title review screenshot written to %s" % title_review_capture_path)
			else:
				push_error("Title review screenshot failed: %s" % capture_error)
			title_review_capture_path = ""
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
	if endgame_protocol_review_completed and not endgame_protocol_review_capture_path.is_empty():
		endgame_protocol_review_capture_frames += 1
		if endgame_protocol_review_capture_frames == 30:
			var review_image := get_viewport().get_texture().get_image()
			var capture_error := review_image.save_png(endgame_protocol_review_capture_path)
			if capture_error == OK:
				print("Endgame protocol review screenshot written to %s" % endgame_protocol_review_capture_path)
			else:
				push_error("Endgame protocol review screenshot failed: %s" % capture_error)
			endgame_protocol_review_capture_path = ""
	if not heartforge_progression_review_capture_path.is_empty():
		heartforge_progression_review_capture_frames += 1
		if heartforge_progression_review_capture_frames == 45:
			var review_image := get_viewport().get_texture().get_image()
			var capture_error := review_image.save_png(heartforge_progression_review_capture_path)
			if capture_error == OK:
				print("Heartforge progression review screenshot written to %s" % heartforge_progression_review_capture_path)
			else:
				push_error("Heartforge progression review screenshot failed: %s" % capture_error)
			heartforge_progression_review_capture_path = ""
	if not adaptive_defense_review_capture_path.is_empty():
		adaptive_defense_review_capture_frames += 1
		if adaptive_defense_review_capture_frames == 45:
			var review_image := get_viewport().get_texture().get_image()
			var capture_error := review_image.save_png(adaptive_defense_review_capture_path)
			if capture_error == OK:
				print("Adaptive defense review screenshot written to %s" % adaptive_defense_review_capture_path)
			else:
				push_error("Adaptive defense review screenshot failed: %s" % capture_error)
			adaptive_defense_review_capture_path = ""
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
	camera_height = 11.2
	camera_distance = 8.45
	# A slight opening-only yaw separates the vulnerable Mechromancer from the
	# Bulwark's close protection slot without changing movement, formation or
	# the Heartforge escape lane.
	camera_heading = Vector3(0.62, 0.0, 0.78).normalized()
	if camera != null:
		camera.fov = 43.8
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
		hud.push_notification(_localized_runtime_text("notification.heartforge.district", "HEARTFORGE DISTRICT · KEEP THE BULWARK CLOSE"))
	run_state.log_event("Presentation status: release candidate. The Heartforge district is the inhabited opening of the persistent town.")
	run_state.log_event("The opening district, remote regions and endgame landmarks share the authored release presentation while the machine society carries the long run forward.")


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
	if _is_endgame_focus_context():
		_update_endgame_establishing_camera(delta)
		return
	camera.fov = lerpf(camera.fov, 43.8, 1.0 - exp(-delta * 3.0))

	var target := player.global_position
	var home_focus := false
	var formation_spread := 0.0
	if follow_operation:
		var operation_target := _active_follow_target()
		if operation_target != null:
			target = operation_target.global_position
			if long_operation_director != null and not long_operation_director.active_operation.is_empty():
				var follow_focus := long_operation_director.get_follow_focus()
				if not follow_focus.is_empty():
					target = follow_focus.get("center", target)
					formation_spread = float(follow_focus.get("spread", 0.0))
				release_camera_departure_clock += delta
				home_focus = release_camera_departure_clock < 3.0 or target.distance_to(heartforge.global_position) < 18.0
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
	if follow_operation and formation_spread > 2.5:
		# Keep every member readable in a broad formation while preserving the
		# close tactical feel once the group has regrouped.
		var spread_excess := formation_spread - 2.5
		dynamic_height += minf(4.0, spread_excess * 0.72)
		dynamic_distance += minf(7.0, spread_excess * 1.15)
	var desired := target + Vector3(0.0, dynamic_height, 0.0) + _camera_horizontal_offset(dynamic_distance)
	var resolved := desired if home_focus else _resolve_camera_occlusion(target, desired, dynamic_height, dynamic_distance)
	if camera.global_position.distance_to(resolved) > 20.0:
		camera.global_position = resolved
	else:
		camera.global_position = camera.global_position.lerp(resolved, 1.0 - exp(-delta * 7.2))
	camera.look_at(target + Vector3.UP * 0.68, Vector3.UP)


func _is_endgame_focus_context() -> bool:
	if endgame_director == null:
		return false
	if not endgame_director.active_protocol.is_empty():
		return true
	return game_ended and first_victory_achieved and not sanctuary_continuation


func _update_endgame_establishing_camera(delta: float) -> void:
	if camera == null or heartforge == null:
		return
	# The final protocol is a town-scale consequence, not a close-up combat
	# interruption. Give the lattice, Heartforge and surviving cast a calmer
	# establishing frame while the normal player camera remains unchanged.
	var target := heartforge.global_position + Vector3.UP * 1.15
	var heading := Vector3(camera_heading.x, 0.0, camera_heading.z)
	if heading.length_squared() <= 0.001:
		heading = Vector3(0.0, 0.0, 1.0)
	heading = heading.normalized()
	var final_height := camera_height + 3.8
	var final_distance := camera_distance + 5.2
	var desired := target + Vector3.UP * final_height + heading * final_distance
	var resolved := _resolve_camera_occlusion(target, desired, final_height, final_distance)
	if camera.global_position.distance_to(resolved) > 20.0:
		camera.global_position = resolved
	else:
		camera.global_position = camera.global_position.lerp(resolved, 1.0 - exp(-delta * 4.0))
	camera.fov = lerpf(camera.fov, 46.0, 1.0 - exp(-delta * 3.0))
	camera.look_at(target, Vector3.UP)


func _snap_release_camera_to_subject() -> void:
	# The release camera is created before the world actors are spawned. Set its
	# first playable transform explicitly so the opening never renders a frame
	# from the camera's origin while the normal follow blend catches up.
	if camera == null or player == null:
		return
	var target := player.global_position
	var dynamic_height := camera_height
	var dynamic_distance := camera_distance
	if _is_remote_camera_context(target):
		var remote_expansion := _remote_camera_expansion()
		dynamic_height += remote_expansion.x
		dynamic_distance += remote_expansion.y
	var desired := target + Vector3.UP * dynamic_height + _camera_horizontal_offset(dynamic_distance)
	var resolved := _resolve_camera_occlusion(target, desired, dynamic_height, dynamic_distance)
	camera.global_position = resolved
	camera.look_at(target + Vector3.UP * 0.68, Vector3.UP)
	camera.fov = 43.8
	camera_target_velocity = Vector3.ZERO


func _restore_sanctuary_continuation_presentation() -> void:
	# Dismissing the first-victory boundary returns to the living tactical world.
	# Reassert the same resident presentation contract used by a fresh release
	# start so the victory camera, atmosphere and stream ring cannot leave the
	# player looking at an empty clear field.
	if get_tree().paused:
		get_tree().paused = false
	paused = false
	if release_front_end != null:
		release_front_end.hide_all()
	if release_world_art != null and release_world_art.dressing_root != null:
		# The release dressing is a sibling presentation layer rather than a
		# child of the procedural city. Reassert it explicitly at this boundary;
		# otherwise the living sanctuary can retain only actors and forge hardware
		# after a victory-review transition.
		release_world_art.dressing_root.visible = true
	_set_tactical_hud_visible(true)
	if player != null:
		player.input_enabled = true
	if camera != null:
		_snap_release_camera_to_subject()
	if region_atmosphere_director != null:
		region_atmosphere_director.refresh_now()
	if region_lod_director != null:
		region_lod_director.refresh_now()
	for node_name in ["ProceduralUrbanDistrict", "Heartforge", "HeartforgeVerticalSlice", "CozyHeartforgeCamp", "UrbanAestheticPass"]:
		var node := get_node_or_null(node_name) as Node3D
		if node != null:
			node.visible = true


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
	# The inherited complete-game world installs the legacy spatial feedback
	# director for the lower-level entrypoints. The release layer owns the
	# canonical player and organic event mix; disconnect only those overlapping
	# bindings while retaining robot, noise, region and endgame coverage for
	# shared diagnostics and lower-level tests.
	if audio_director != null and is_instance_valid(audio_director):
		audio_director.disable_release_overlap_bindings()
	localization_service = LocalizationService3D.new()
	localization_service.name = "LocalizationService"
	localization_service.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(localization_service)
	localization_service.locale_changed.connect(_on_release_locale_changed)

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
	release_audio.register_region_atmosphere(region_atmosphere_director)
	if adaptive_defense_director != null:
		release_audio.register_adaptive_defense(adaptive_defense_director)

	release_front_end = ReleaseFrontEnd3D.new()
	release_front_end.name = "ReleaseFrontEnd"
	release_front_end.configure(localization_service, settings_service)
	add_child(release_front_end)

	title_pause_timer = Timer.new()
	title_pause_timer.name = "TitlePauseTimer"
	title_pause_timer.one_shot = true
	title_pause_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	title_pause_timer.timeout.connect(_pause_title_after_first_frame)
	add_child(title_pause_timer)


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
	_refresh_hud_accessibility_layout()
	_apply_command_line_locale_override()
	var mode := pending_launch_mode
	pending_launch_mode = &"title"
	if _is_headless_release():
		_start_release_world()
	elif _has_new_world_flag():
		# A direct fresh-world launch keeps exact-export playtests reproducible
		# without requiring UI automation through the title screen. It is a
		# developer-facing launch flag and does not bypass any in-world gate.
		_start_release_world()
	elif _has_heartforge_progression_review_flag():
		_start_release_world()
		call_deferred("_start_heartforge_progression_review")
	elif _has_adaptive_defense_review_flag():
		_start_release_world()
		call_deferred("_start_adaptive_defense_review")
	elif _has_complete_objective_review_flag():
		_start_release_world()
		call_deferred("_start_complete_objective_review")
	elif _has_endgame_protocol_review_flag():
		_start_release_world()
		call_deferred("_start_endgame_protocol_review")
	elif _has_mechromancer_evolution_review_flag():
		_start_release_world()
		call_deferred("_start_mechromancer_evolution_review")
	elif _has_presentation_review_flag():
		_start_release_world()
		call_deferred("_start_presentation_review")
	elif _has_stream_ring_review_flag():
		_start_release_world()
		call_deferred("_start_stream_ring_review")
	elif _has_route_memory_review_flag():
		_start_release_world()
		call_deferred("_start_route_memory_review")
	elif _has_route_recovery_marker_review_flag():
		_start_release_world()
		call_deferred("_start_route_recovery_marker_review")
	elif _has_dynamic_operation_review_flag():
		_start_release_world()
		call_deferred("_start_dynamic_operation_review")
	elif _has_authored_operation_review_flag():
		_start_release_world()
		call_deferred("_start_authored_operation_review")
	elif _has_concurrent_operation_review_flag():
		_start_release_world()
		call_deferred("_start_concurrent_operation_review")
	elif _has_casualty_recovery_review_flag():
		_start_release_world()
		call_deferred("_start_casualty_recovery_review")
	elif _has_run_variation_review_flag():
		_start_release_world()
		call_deferred("_start_run_variation_review")
	elif _has_title_review_flag():
		process_mode = Node.PROCESS_MODE_ALWAYS
		title_review_capture_path = _title_review_capture_argument()
		title_review_capture_frames = 0
		_show_title_screen()
	elif mode == &"new":
		_start_release_world()
	elif mode == &"continue":
		_start_release_world()
		_load_release_game()
	else:
		_show_title_screen()


func _has_new_world_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) in ["--new", "--new-world"]:
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument) in ["--new", "--new-world"]:
			return true
	return false


func _has_presentation_review_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == "--presentation-review":
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument) == "--presentation-review":
			return true
	return false


func _has_stream_ring_review_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == "--stream-ring-review":
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument) == "--stream-ring-review":
			return true
	return false


func _has_title_review_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == "--title-review":
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument) == "--title-review":
			return true
	return false


func _title_review_capture_argument() -> String:
	var arguments: Array = OS.get_cmdline_args()
	arguments.append_array(OS.get_cmdline_user_args())
	for index in arguments.size():
		var argument := str(arguments[index])
		if argument.begins_with("--title-review-screenshot="):
			return argument.get_slice("=", 1)
		if argument == "--title-review-screenshot" and index + 1 < arguments.size():
			return str(arguments[index + 1])
	return ""


func _presentation_review_start_page() -> int:
	var arguments: Array = OS.get_cmdline_args()
	arguments.append_array(OS.get_cmdline_user_args())
	for index in arguments.size():
		var argument := str(arguments[index])
		if argument.begins_with("--presentation-review-page="):
			return maxi(0, int(argument.get_slice("=", 1)))
		if argument == "--presentation-review-page" and index + 1 < arguments.size():
			return maxi(0, int(arguments[index + 1]))
	return 0


func _presentation_review_capture_argument() -> String:
	var arguments: Array = OS.get_cmdline_args()
	arguments.append_array(OS.get_cmdline_user_args())
	for index in arguments.size():
		var argument := str(arguments[index])
		if argument.begins_with("--presentation-review-screenshot="):
			return argument.get_slice("=", 1)
		if argument == "--presentation-review-screenshot" and index + 1 < arguments.size():
			return str(arguments[index + 1])
	return ""


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


func _heartforge_progression_review_capture_argument() -> String:
	var arguments: Array = OS.get_cmdline_args()
	arguments.append_array(OS.get_cmdline_user_args())
	for index in arguments.size():
		var argument := str(arguments[index])
		if argument.begins_with("--heartforge-progression-review-screenshot="):
			return argument.get_slice("=", 1)
		if argument == "--heartforge-progression-review-screenshot" and index + 1 < arguments.size():
			return str(arguments[index + 1])
	return ""


func _has_adaptive_defense_review_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == "--adaptive-defense-review":
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument) == "--adaptive-defense-review":
			return true
	return false


func _has_complete_objective_review_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == "--complete-objective-review":
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument) == "--complete-objective-review":
			return true
	return false


func _apply_command_line_locale_override() -> void:
	if localization_service == null:
		return
	var arguments: Array = OS.get_cmdline_args()
	arguments.append_array(OS.get_cmdline_user_args())
	for argument in arguments:
		var raw := str(argument)
		if not raw.begins_with("--locale="):
			continue
		var locale := StringName(raw.get_slice("=", 1).to_lower())
		if localization_service.set_locale(locale):
			return


func _has_endgame_protocol_review_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == "--endgame-protocol-review" or str(argument).begins_with("--endgame-protocol-review="):
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument) == "--endgame-protocol-review" or str(argument).begins_with("--endgame-protocol-review="):
			return true
	return false


func _endgame_protocol_review_id() -> StringName:
	var arguments: Array = OS.get_cmdline_args()
	arguments.append_array(OS.get_cmdline_user_args())
	for argument in arguments:
		var raw := str(argument)
		if raw.begins_with("--endgame-protocol-review="):
			var suffix := raw.get_slice("=", 1).to_lower()
			if suffix in ["severance", "containment", "transformation"]:
				return StringName("protocol.%s" % suffix)
	return &"protocol.severance"


func _endgame_protocol_review_capture_argument() -> String:
	var arguments: Array = OS.get_cmdline_args()
	arguments.append_array(OS.get_cmdline_user_args())
	for index in arguments.size():
		var argument := str(arguments[index])
		if argument.begins_with("--endgame-protocol-review-screenshot="):
			return argument.get_slice("=", 1)
		if argument == "--endgame-protocol-review-screenshot" and index + 1 < arguments.size():
			return str(arguments[index + 1])
	return ""


func _has_route_memory_review_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == "--route-memory-review":
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument) == "--route-memory-review":
			return true
	return false


func _has_route_recovery_marker_review_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == "--route-recovery-marker-review":
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument) == "--route-recovery-marker-review":
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


func _has_authored_operation_review_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == "--authored-operation-review":
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument) == "--authored-operation-review":
			return true
	return false


func _has_concurrent_operation_review_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument) == "--concurrent-operation-review":
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument) == "--concurrent-operation-review":
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


func _has_run_variation_review_flag() -> bool:
	for argument in OS.get_cmdline_args():
		if str(argument).begins_with("--run-variation-review"):
			return true
	for argument in OS.get_cmdline_user_args():
		if str(argument).begins_with("--run-variation-review"):
			return true
	return false


func _run_variation_review_argument() -> StringName:
	var arguments: Array = OS.get_cmdline_args()
	arguments.append_array(OS.get_cmdline_user_args())
	for index in arguments.size():
		var argument := str(arguments[index])
		if argument.begins_with("--run-variation-review="):
			return StringName(argument.get_slice("=", 1))
		if argument == "--run-variation-review" and index + 1 < arguments.size():
			return StringName(str(arguments[index + 1]))
	return &"weather.frost_hush"


func _start_run_variation_review() -> void:
	if run_variation_director == null or run_state == null:
		return
	var variant_id := _run_variation_review_argument()
	if not run_variation_director.profiles.has(variant_id):
		push_error("Run variation review requested an unknown profile: %s" % String(variant_id))
		return
	run_state.set_world_variant(variant_id, run_state.world_seed)
	run_variation_director.apply_current()
	var variant_name := localization_service.text("world.condition.%s.name" % String(variant_id).replace("weather.", ""))
	hud.push_notification("RUN VARIATION REVIEW · %s" % variant_name)
	run_state.log_event("Run variation review started: %s. No save or player input is enabled." % String(variant_id))


func _start_presentation_review() -> void:
	presentation_review_active = true
	presentation_review_page = 0
	presentation_review_capture_path = _presentation_review_capture_argument()
	presentation_review_capture_frames = 0
	# The gallery deliberately promotes every authored landmark, so the normal
	# proximity LOD loop must not downgrade the selected review fixture back to a
	# reduced proxy while the capture is being inspected.
	if region_lod_director != null:
		region_lod_director.set_process(false)
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
	if _is_headless_release():
		for index in PRESENTATION_REVIEW_REGIONS.size():
			_populate_presentation_review_region(index)
	var outpost_review_page: Array = presentation_review_pages[3 + PRESENTATION_REVIEW_REGIONS.size()]
	if _is_headless_release():
		_populate_presentation_review_outposts(outpost_review_page)
	_create_presentation_review_stage()
	_show_presentation_review_page(_presentation_review_start_page())
	get_tree().paused = true
	run_state.log_event("Presentation review mode: 1 friendly roster, 2 early organics, 3 late organics, 4-14 all remote regions, 15 autonomous outpost roles. Arrow keys browse; Escape exits review.")


func _ensure_presentation_review_page_loaded(page: int) -> void:
	if page >= 3 and page < 3 + PRESENTATION_REVIEW_REGIONS.size():
		var region_index := page - 3
		if presentation_review_pages[page].is_empty():
			_populate_presentation_review_region(region_index)
	elif page == 3 + PRESENTATION_REVIEW_REGIONS.size():
		if presentation_review_pages[page].is_empty():
			_populate_presentation_review_outposts(presentation_review_pages[page])


func _populate_presentation_review_region(index: int) -> void:
	if index < 0 or index >= PRESENTATION_REVIEW_REGIONS.size():
		return
	var page := 3 + index
	if not presentation_review_pages[page].is_empty():
		return
	var region_id: StringName = PRESENTATION_REVIEW_REGIONS[index]
	if region_director != null:
		region_director.discover_region(region_id)
	var landmark := _presentation_review_landmark(region_id)
	var review_actor: Node3D = landmark
	if region_id == &"region.root_cistern" and landmark != null:
		review_actor = _create_root_cistern_presentation_review_actor(landmark)
	elif region_id == &"region.observatory_ridge" and landmark != null:
		review_actor = _create_observatory_presentation_review_actor(landmark)
	elif region_id == &"region.buried_labs" and landmark != null:
		review_actor = _create_buried_labs_presentation_review_actor(landmark)
	elif region_id == &"region.tram_graveyard" and landmark != null:
		review_actor = _create_tram_graveyard_presentation_review_actor(landmark)
	elif region_id == &"region.cathedral_quarter" and landmark != null:
		_apply_cathedral_presentation_material_overrides(landmark)
	if review_actor == null or landmark == null:
		return
	# Promote only the selected fixture. Other remote packages remain streamed out
	# until their page is selected, keeping the live review startup bounded.
	landmark.set_streamed_in(true)
	landmark.set_presentation_detail_level(0)
	if region_id == &"region.root_cistern":
		landmark.visible = false
		var review_persistent_scene := landmark.get_node_or_null("RootCisternAuthoredScene") as Node3D
		if review_persistent_scene != null:
			review_persistent_scene.visible = false
		var review_reduced_proxy := landmark.get_node_or_null("ReducedRegionProxy") as Node3D
		if review_reduced_proxy != null:
			review_reduced_proxy.visible = false
	landmark.set_map_emphasis(false)
	presentation_review_pages[page].append(review_actor)


func _populate_presentation_review_outposts(page: Array) -> void:
	if not page.is_empty():
		return
	var outpost_scene := _load_presentation_review_scene(OUTPOST_PRESENTATION_REVIEW_SCENE, "outpost review")
	for index in 4:
		var outpost := outpost_scene.instantiate() as Outpost3D if outpost_scene != null else null
		if outpost == null:
			continue
		outpost.name = "PresentationReviewOutpost%02d" % index
		outpost.configure(StringName("presentation.review.outpost.%d" % index), [&"resource", &"defence", &"scout", &"repair"][index], 3, run_state)
		add_child(outpost)
		outpost.set_physics_process(false)
		outpost.set_process(false)
		outpost.set_presentation_review_mode()
		page.append(outpost)


func _load_presentation_review_scene(path: String, label: String) -> PackedScene:
	var resource := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_REUSE)
	if not (resource is PackedScene):
		push_error("Presentation review scene could not be loaded for %s: %s" % [label, path])
		return null
	return resource as PackedScene


func _start_stream_ring_review() -> void:
	# This is a development-only camera-focus fixture. It moves the actual
	# player between two authored regions so the renderer can be checked without
	# manual travel or any live audio output.
	stream_ring_review_active = true
	stream_ring_review_clock = 0.0
	stream_ring_review_phase = 0
	if region_director != null:
		region_director.discover_region(&"region.west_grid")
		region_director.discover_region(&"region.root_cistern")
	if player != null:
		player.input_enabled = false
		player.global_position = Vector3(-92.0, 0.0, 18.0)
	if region_atmosphere_director != null:
		region_atmosphere_director.refresh_now()
	if region_lod_director != null:
		region_lod_director.refresh_now()
	if hud != null:
		hud.push_notification("STREAM RING REVIEW · WEST GRID FOCUS · ROOT CISTERN IS COARSE/STREAMED OUT")
	run_state.log_event("Stream-ring review started: West Grid focus, then Root Cistern focus, then West Grid return. No save or player input is enabled.")


func _update_stream_ring_review(delta: float) -> void:
	stream_ring_review_clock += delta
	if stream_ring_review_phase == 0 and stream_ring_review_clock >= 10.0:
		stream_ring_review_phase = 1
		if player != null and region_director != null:
			player.global_position = region_director.center(&"region.root_cistern")
		if region_atmosphere_director != null:
			region_atmosphere_director.refresh_now()
		if region_lod_director != null:
			region_lod_director.refresh_now()
		if hud != null:
			hud.push_notification("STREAM RING REVIEW · ROOT CISTERN FOCUS · AUTHORED REGION RESTORED")
	elif stream_ring_review_phase == 1 and stream_ring_review_clock >= 20.0:
		stream_ring_review_phase = 2
		if player != null:
			player.global_position = Vector3(-92.0, 0.0, 18.0)
		if region_atmosphere_director != null:
			region_atmosphere_director.refresh_now()
		if region_lod_director != null:
			region_lod_director.refresh_now()
		if hud != null:
			hud.push_notification("STREAM RING REVIEW · WEST GRID RETURN · ROOT CISTERN PROXY RETAINED")


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
	heartforge_progression_review_capture_path = _heartforge_progression_review_capture_argument()
	heartforge_progression_review_capture_frames = 0
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
	endgame_protocol_review_capture_path = _endgame_protocol_review_capture_argument()
	endgame_protocol_review_capture_frames = 0
	var review_protocol_id := _endgame_protocol_review_id()
	if progression != null:
		progression.set_heartforge_tier(5)
		for technology_id in [&"tech.machine.forge_assistance", &"tech.endgame.severance", &"tech.endgame.containment", &"tech.endgame.transformation"]:
			if technology_id not in progression.unlocked_technologies:
				progression.unlocked_technologies.append(technology_id)
		progression.unlocked_effects[&"unlock_final_protocol_research"] = true
		progression.progression_changed.emit()
	if long_operation_director != null:
		long_operation_director.completed_operations = [
			&"operation.west_grid_survey",
			&"operation.flood_market_recovery",
			&"operation.cathedral_brood_suppression",
			&"operation.buried_lab_excavation",
			&"operation.root_cistern_mapping",
		]
		long_operation_director.recovered_components = [
			&"component.choral_gland",
			&"component.genome_prism",
			&"component.root_map",
			&"component.migration_ephemeris",
		]
	if run_state != null:
		run_state.scrap = 1200
		run_state.rare_cores = 8
		run_state.manual_scrap_recovered = 20
		run_state.autonomous_scrap_recovered = 30
		run_state.expedition_core_recovered = true
		full_game_milestone_complete = true
	if outpost_director != null:
		for index in range(mini(4, outpost_director.sites.size())):
			var site := outpost_director.sites[index] as OutpostSite3D
			if site == null:
				continue
			site.set_discovered(true)
			if not site.has_outpost():
				outpost_director._spawn_outpost(site, site.recommended_role, 1)
	if region_director != null:
		region_director.discover_region(&"region.root_cistern")
	if endgame_director != null and endgame_director.initiate(review_protocol_id):
		if hud != null:
			hud.push_notification("FINAL PROTOCOL REVIEW · %s ACTIVE · VICTORY RESOLUTION IN 8 SECONDS" % str(review_protocol_id).replace("protocol.", "").to_upper())
		if run_state != null:
			run_state.log_event("Endgame protocol review mode: active %s lattice will resolve through the ordinary victory path." % str(review_protocol_id))


func _start_complete_objective_review() -> void:
	# Non-saving fixture for exact exported review of the canonical late-run
	# objective surface. It reaches the same state through stable progression,
	# operation and outpost contracts, then leaves the final protocol idle so
	# the player-facing objective can be judged in the selected locale.
	if progression != null:
		progression.set_heartforge_tier(5)
		for technology_id in [&"tech.machine.forge_assistance", &"tech.endgame.severance"]:
			if technology_id not in progression.unlocked_technologies:
				progression.unlocked_technologies.append(technology_id)
		progression.unlocked_effects[&"unlock_final_protocol_research"] = true
		progression.progression_changed.emit()
	if long_operation_director != null:
		long_operation_director.completed_operations = [
			&"operation.west_grid_survey",
			&"operation.flood_market_recovery",
			&"operation.cathedral_brood_suppression",
			&"operation.buried_lab_excavation",
			&"operation.root_cistern_mapping",
		]
		long_operation_director.recovered_components = [
			&"component.vital_membrane",
			&"component.choral_gland",
			&"component.genome_prism",
			&"component.root_map",
		]
	if run_state != null:
		run_state.scrap = 1200
		run_state.rare_cores = 8
		run_state.manual_scrap_recovered = 20
		run_state.autonomous_scrap_recovered = 30
		run_state.expedition_core_recovered = true
		full_game_milestone_complete = true
	if autonomy_director != null:
		_spawn_robot(&"salvager", heartforge.global_position + Vector3(0.0, 0.0, 3.8), 1)
		_spawn_robot(&"guardian", heartforge.global_position + Vector3(3.0, 0.0, 2.0), 1)
		_spawn_robot(&"scout", heartforge.global_position + Vector3(-3.0, 0.0, 2.0), 1)
	if outpost_director != null:
		for index in range(mini(3, outpost_director.sites.size())):
			var site := outpost_director.sites[index] as OutpostSite3D
			if site == null:
				continue
			site.set_discovered(true)
			if not site.has_outpost():
				outpost_director._spawn_outpost(site, site.recommended_role, 1)
	if region_director != null:
		region_director.discover_region(&"region.root_cistern")
	if hud != null:
		hud.push_notification(_localized_runtime_text("notification.complete.response_offer", "WORLD-STATE RESPONSE OFFER · PRESSURE HAS BECOME A CHOICE"))
	call_deferred("_update_complete_game_objective")


func _start_concurrent_operation_review() -> void:
	if progression == null or region_director == null or long_operation_director == null or outpost_director == null:
		return
	progression.set_heartforge_tier(2)
	if not progression.has_technology(&"tech.machine.group_coordination"):
		progression.unlocked_technologies.append(&"tech.machine.group_coordination")
	run_state.scrap = 900
	run_state.robots_built = maxi(run_state.robots_built, 8)
	run_state.scrap_changed.emit(run_state.scrap)
	var roles: Array[StringName] = [&"salvager", &"guardian", &"scout"]
	var positions: Array[Vector3] = [Vector3(-4.0, 0.0, 4.0), Vector3(0.0, 0.0, 5.0), Vector3(4.0, 0.0, 4.0)]
	for index in roles.size():
		while autonomy_director.living_robots(roles[index]).size() < 2:
			_spawn_robot(roles[index], positions[index] + Vector3(float(autonomy_director.living_robots(roles[index]).size()) * 1.4, 0.0, 1.8), 1)
	region_director.discover_region(&"region.west_grid")
	var site := outpost_director.sites[0] as OutpostSite3D if not outpost_director.sites.is_empty() else null
	if site == null:
		return
	site.set_discovered(true)
	if not site.has_outpost():
		outpost_director._spawn_outpost(site, &"resource", 1)
	if site.outpost != null:
		site.outpost.stored_scrap = 30
	if not long_operation_director.authorize(&"operation.west_grid_survey"):
		push_error("Concurrent operation review could not authorize its long-range fixture.")
		return
	outpost_director.maintenance_clock = 2.0
	outpost_director._process(1.1)
	if long_operation_director.active_operation.is_empty() or outpost_director.operation.is_empty():
		push_error("Concurrent operation review did not create both remote fixtures.")
		return
	follow_operation = false
	player.input_enabled = false
	hud.push_notification("CONCURRENT REMOTE REVIEW · LONG-RANGE GROUP + OUTPOST HAUL ACTIVE")
	long_operation_director.operation_changed.emit(
		&"concurrent_review",
		&"active",
		"Two autonomous remote groups are travelling at once; each keeps a separate formation and the Heartforge network remains online."
	)


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
	if presentation_review_pages.size() != 4 + PRESENTATION_REVIEW_REGIONS.size():
		return
	presentation_review_page = clampi(page, 0, presentation_review_pages.size() - 1)
	_ensure_presentation_review_page_loaded(presentation_review_page)
	for page_actors in presentation_review_pages:
		for actor in page_actors:
			if is_instance_valid(actor):
				actor.visible = false
	var is_region_page := presentation_review_page >= 3 and presentation_review_page < 3 + PRESENTATION_REVIEW_REGIONS.size()
	if release_world_art != null and release_world_art.dressing_root != null:
		release_world_art.dressing_root.visible = is_region_page
	if release_world_art != null:
		for raw_region_id in release_world_art.region_dressing_roots:
			var dressing_root := release_world_art.region_dressing_root(raw_region_id as StringName)
			if dressing_root != null:
				dressing_root.visible = false
	var actors: Array = presentation_review_pages[presentation_review_page]
	var outpost_page := presentation_review_page == 3 + PRESENTATION_REVIEW_REGIONS.size()
	is_region_page = presentation_review_page >= 3 and not outpost_page
	var region_id := PRESENTATION_REVIEW_REGIONS[presentation_review_page - 3] if is_region_page else &""
	if is_region_page and release_world_art != null:
		var selected_region_dressing := release_world_art.ensure_region_dressing(region_id) if release_world_art.has_method(&"ensure_region_dressing") else release_world_art.region_dressing_root(region_id)
		if selected_region_dressing != null:
			selected_region_dressing.visible = region_id != &"region.tram_graveyard"
			if region_id == &"region.cathedral_quarter":
				# The Cathedral's review-only biological hierarchy spans the
				# authored landmark and its release brood dressing. Apply the same
				# restrained dry-violet treatment to both roots so the choir reads
				# as one deliberate takeover instead of isolated pink props.
				_apply_cathedral_presentation_material_overrides(selected_region_dressing)
	for index in actors.size():
		var actor := actors[index] as Node3D
		if actor == null or not is_instance_valid(actor):
			continue
		actor.visible = true
		_set_presentation_review_actor_lighting(actor, presentation_review_page == 0 or outpost_page)
		if is_region_page:
			# Riverworks keeps its opposite-side service face, while Tram Graveyard
			# is explicitly front-facing for the dedicated carriage review actor.
			# Other families keep their authored front.
			if region_id == &"region.riverworks":
				actor.rotation.y = PI
			elif region_id == &"region.tram_graveyard":
				# The carriage fronts and maintenance pit are authored toward the
				# gallery camera. Keep the review instance front-facing so the rail
				# identity reads as a connected yard instead of clipped roof fragments.
				actor.rotation.y = 0.0
			if actor.has_method("set_presentation_detail_level"):
				actor.call("set_presentation_detail_level", 0)
			var region_geometry := actor.get_node_or_null("PersistentRegionGeometry") as Node3D
			if region_geometry != null:
				region_geometry.visible = true
		else:
			# The roster page is an authored model review, so show the
			# Mechromancer's field-engineer face and protected front hardware
			# instead of repeating the live third-person rear angle. Friendly
			# robots retain their established presentation orientation.
			actor.rotation.y = 0.0 if presentation_review_page == 0 and index == 0 else PI
			var late_organic_roster := presentation_review_page == 2
			# Early families have several broad flight and limb silhouettes. Give
			# that page three positions in the near row and four in the rear row so
			# the broadest shells do not merge into one silhouette band; late
			# families keep the deeper three-across composition that suits their
			# folded mass.
			var row_capacity := 2 if outpost_page else (3 if presentation_review_page == 1 else (3 if presentation_review_page >= 1 else mini(4, actors.size())))
			var row_index := 0 if index < row_capacity else 1
			var row_count := mini(row_capacity, actors.size()) if row_index == 0 else actors.size() - row_capacity
			var row_position := index if row_index == 0 else index - row_capacity
			# The organic roster needs a true detail frame. Its authored shells
			# carry fine veins, membrane ribs, crown plates and threat sockets that
			# collapse into one silhouette band at the old spacing. Keep the actor
			# roots and gameplay scale untouched; only the bounded review fixture
			# gets a wider two-row composition so every family remains judgeable.
			# Late organic families carry broad folded silhouettes. Give the
			# review gallery enough air to judge those layers individually;
			# this only changes the development review fixture, not gameplay
			# scale, collision or tactical spacing.
			# The late families have the broadest folded shells in the roster. Give
			# that page a little more lateral and depth separation while keeping the
			# review fixture bounded; runtime scale, collision and gameplay spacing
			# remain untouched.
			var spacing := 5.4 if outpost_page else (3.35 if late_organic_roster else (3.0 if presentation_review_page == 1 else (4.1 if presentation_review_page >= 1 else 4.2)))
			var centered_x := (float(row_position) - float(row_count - 1) * 0.5) * spacing
			if presentation_review_page == 1:
				# The early families carry wide wings, fans and limb spans. Use a
				# triangular near row and a wider rear row so every shell keeps a
				# readable outline while remaining inside the bounded review frame.
				var early_positions := [-4.4, 0.0, 4.4] if row_index == 0 else [-4.8, -1.6, 1.6, 4.8]
				centered_x = early_positions[row_position]
			var row_z := 1.45 if row_index == 0 else -3.35
			if presentation_review_page == 0:
				row_z = 0.7 if row_index == 0 else -2.5
			elif outpost_page:
				row_z = 1.25 if row_index == 0 else -2.6
			elif late_organic_roster and row_index == 0:
				row_z = 1.35
			elif late_organic_roster:
				row_z = -3.2
			row_z += _presentation_review_depth_offset(actor)
			actor.scale = Vector3.ONE
			# Materialize deferred authored shells before applying the bounded
			# gallery compensation. Otherwise set_visual_lod(0) can build a fresh
			# OrganicModel after the scale assignment and silently reset the review
			# root to unit scale.
			if actor.has_method("set_visual_lod"):
				actor.call("set_visual_lod", 0)
			var review_model_root := actor.get_node_or_null("OrganicModel") as Node3D
			if review_model_root != null:
				review_model_root.scale = Vector3.ONE * _presentation_review_model_scale(actor)
			actor.position = Vector3(centered_x, 0.0, row_z)
			if outpost_page:
				# Break the four role shelters out of a rigid two-by-two grid while
				# preserving the authored front-facing presentation basis.
				var outpost_positions: Array[Vector3] = [
					Vector3(-3.0, 0.0, 1.1), Vector3(3.0, 0.0, 0.9),
					Vector3(-2.35, 0.0, -2.85), Vector3(2.35, 0.0, -3.1),
				]
				if index < outpost_positions.size():
					actor.position = outpost_positions[index]
					actor.rotation.y = PI
	var page_titles: Array[String] = [
		"PLAYER + FRIENDLY MACHINE SOCIETY", "EARLY ORGANIC FAMILIES", "LATE ORGANIC FAMILIES",
		"REMOTE · NORTH RUINS", "REMOTE · WEST GRID", "REMOTE · EAST TENEMENTS",
		"REMOTE · MUNICIPAL GLASSHOUSE", "REMOTE · FLOOD MARKET", "REMOTE · RIVERWORKS",
		"REMOTE · TRAM GRAVEYARD", "REMOTE · CATHEDRAL QUARTER", "REMOTE · OBSERVATORY RIDGE",
		"REMOTE · BURIED LABORATORIES", "REMOTE · ROOT CISTERN", "AUTONOMOUS OUTPOST ROLES · TIER III",
	]
	var page_title: String = page_titles[presentation_review_page]
	presentation_review_label.text = "PRESENTATION REVIEW  ·  %s  ·  %d/%d\n1-9, 0 DIRECT PAGE   ←/→ BROWSE   ESC EXIT" % [page_title, presentation_review_page + 1, presentation_review_pages.size()]
	if is_region_page and not actors.is_empty():
		var review_target_height := 3.8 if region_id == &"region.east_tenements" else (3.0 if region_id == &"region.cathedral_quarter" else 2.0)
		presentation_review_camera_target = (actors[0] as Node3D).global_position + Vector3.UP * review_target_height
		presentation_review_camera_desired = presentation_review_camera_target + _presentation_review_region_camera_offset(region_id)
	elif is_region_page and region_director != null:
		presentation_review_camera_target = region_director.center(region_id) + Vector3.UP * 2.0
		presentation_review_camera_desired = presentation_review_camera_target + Vector3(0.0, 12.0, 19.0)
	else:
		var organic_roster_detail := presentation_review_page == 1 or presentation_review_page == 2
		# The organic roster is a model-library review, not a distant world
		# tableau. Give the authored shells enough screen area for their crown,
		# membrane and locomotion details to be judged without changing actor
		# scale, gameplay spacing, collision or tactical camera behaviour.
		var core_target_height := 2.1 if outpost_page else (1.5 if organic_roster_detail else (1.08 if presentation_review_page >= 1 else 1.45))
		var core_target_depth := -0.38 if presentation_review_page >= 1 else -0.7
		if organic_roster_detail:
			# The two organic roster pages are the close-camera art gate. Lower the
			# target slightly and bring the review camera in so the authored shells
			# use the frame instead of leaving a large unused sky band above them.
			# This is review-fixture composition only; gameplay camera, actor scale,
			# collision, LOD and tactical spacing remain unchanged.
			var late_organic_roster := presentation_review_page == 2
			presentation_review_camera_target = Vector3(0.0, 1.18 if late_organic_roster else 1.22, -0.85 if late_organic_roster else core_target_depth)
			presentation_review_camera_desired = Vector3(0.0, 4.45 if late_organic_roster else 4.05, 12.8 if late_organic_roster else 9.35)
		else:
			presentation_review_camera_target = Vector3(0.0, core_target_height, core_target_depth)
			presentation_review_camera_desired = Vector3(0.0, 5.25, 12.4) if outpost_page else (Vector3(0.0, 4.45, 12.8) if presentation_review_page >= 1 else Vector3(0.0, 4.8, 12.5))
	_set_presentation_review_stage_for_page(is_region_page)
	_update_presentation_review_camera(1.0)


func _set_presentation_review_actor_lighting(actor: Node3D, friendly_roster: bool) -> void:
	# Friendly robot sensor lamps are valuable in the live tactical scene, but
	# their short-range pools become large soft blobs on the neutral gallery
	# floor and compete with the authored shell materials. Store each original
	# energy once and attenuate only the development-only roster page.
	for child in actor.find_children("*", "OmniLight3D", true, false):
		var light := child as OmniLight3D
		if light == null:
			continue
		if not light.has_meta("presentation_review_base_energy"):
			light.set_meta("presentation_review_base_energy", light.light_energy)
		var base_energy := float(light.get_meta("presentation_review_base_energy"))
		light.light_energy = base_energy * (0.24 if friendly_roster else 1.0)


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
		return Vector3(0.0, 8.2, 16.0)
	if region_id == &"region.flood_market":
		return Vector3(8.5, 9.4, 15.4)
	if region_id == &"region.cathedral_quarter":
		# The centered frame lets the foreground choir and pipe dressing eclipse
		# the nave while the tower is cropped against the top edge. A bounded
		# diagonal, slightly more distant frame separates the choir hardware from
		# the civic shell and keeps the tower silhouette in view; runtime landmark
		# placement and encounter geometry remain untouched.
		return Vector3(6.6, 8.5, 18.8)
	if region_id == &"region.observatory_ridge":
		# Lower the review eye so the reflector's parabolic depth and pivot cradle
		# read as one instrument instead of a broad blue disc. Runtime landmark
		# placement and geometry remain untouched.
		return Vector3(6.0, 3.2, 15.4)
	if region_id == &"region.buried_labs":
		return Vector3(0.0, 10.2, 15.0)
	if region_id == &"region.north_ruins":
		return Vector3(-7.0, 9.6, 14.8)
	if region_id == &"region.west_grid":
		# The industrial hall's foreground service stacks otherwise line up
		# directly over the switchyard and reroute witness under the shared
		# elevated remote angle. A bounded diagonal frame keeps the turbine
		# housing, transformer hardware and physical route board legible while
		# leaving the runtime landmark, navigation and encounter geometry alone.
		return Vector3(-7.4, 8.4, 16.2)
	if region_id == &"region.east_tenements":
		# The residential blocks are broad and low-detail from the shared remote
		# angle. A closer diagonal frame lets the facade bands, balconies and
		# laundry read as attached lived-in infrastructure instead of a distant
		# symmetrical rail grid. This is review-fixture composition only.
		return Vector3(7.0, 9.0, 19.0)
	if region_id == &"region.root_cistern":
		# A slight diagonal separates the foreground control threshold from the
		# capstone's lower relay anatomy, keeping both the approach cue and the
		# central living machine legible in the exact review frame. Runtime camera,
		# landmark placement and traversal geometry remain untouched.
		return Vector3(-5.4, 9.0, 18.0)
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
	if actor_name.begins_with("skitterling"):
		# The Skitterling is intentionally the smallest living family in the
		# world, but its authored shell still needs enough pixels for the
		# carapace caps, sensory fan and mandible plates to be inspected beside
		# the larger early predators. This is gallery-only and does not alter
		# gameplay scale, collision, movement, ecology or animation timing.
		return 1.24
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
	# The six signal pylons form a ring around the capstone. Rotate only this
	# development review instance so the approach camera reads between pylons
	# instead of placing one directly over the core; runtime landmark orientation
	# and all gameplay spatial contracts remain unchanged.
	review_actor.rotation.y = PI / 6.0
	var authored_resource := _load_presentation_review_scene(ROOT_CISTERN_PRESENTATION_REVIEW_SCENE, "Root Cistern")
	if authored_resource == null:
		return review_actor
	var authored_scene := authored_resource.instantiate()
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
	var persistent_authored_scene := landmark.get_node_or_null("RootCisternAuthoredScene") as Node3D
	if persistent_authored_scene != null:
		# The exact review actor is the single source of truth for this page;
		# suppress the persistent copy to avoid a doubled pylon/core silhouette.
		persistent_authored_scene.visible = false
	var reduced_proxy := landmark.get_node_or_null("ReducedRegionProxy") as Node3D
	if reduced_proxy != null:
		# The exact page is already represented by the authored capstone scene;
		# leaving the generic distant ribs behind it creates a false second
		# silhouette and obscures the central relay hierarchy.
		reduced_proxy.visible = false
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
	var authored_resource := _load_presentation_review_scene(OBSERVATORY_PRESENTATION_REVIEW_SCENE, "Observatory Ridge")
	if authored_resource == null:
		return review_actor
	var authored_scene := authored_resource.instantiate()
	authored_scene.name = "ObservatoryPresentationReviewModel"
	review_actor.add_child(authored_scene)
	_tune_observatory_presentation_review_materials(authored_scene)
	_dress_observatory_presentation_review_actor(review_actor)
	return review_actor


func _tune_observatory_presentation_review_materials(authored_scene: Node) -> void:
	# The reflector is the landmark's focal surface. Keep it deep blue, but
	# give the compact review key enough reflected colour to show the parabolic
	# bowl instead of collapsing it into a dark circular platform.
	var dish_material := ModelKit3D.material(Color("1d4f78"), 0.12, 0.66)
	var dish_rim_material := ModelKit3D.material(Color("587b82"), 0.68, 0.42)
	var dish_pedestal_material := ModelKit3D.material(Color("1a2930"), 0.64, 0.52)
	var dish_pedestal_ring_material := ModelKit3D.material(Color("70402f"), 0.34, 0.62)
	var dish_pivot_material := ModelKit3D.material(Color("29444a"), 0.52, 0.46)
	var actuator_material := ModelKit3D.material(Color("82452f"), 0.28, 0.66)
	var signal_material := ModelKit3D.material(Color("124d58"), 0.32, 0.34, Color("58dfe3"), 0.92)
	for child in authored_scene.find_children("*", "MeshInstance3D", true, false):
		if not child is MeshInstance3D:
			continue
		var mesh := child as MeshInstance3D
		var node_name := mesh.name.to_lower()
		if node_name.contains("dishsupportring"):
			mesh.material_override = dish_pedestal_ring_material
		elif node_name.contains("dishpedestal"):
			mesh.material_override = dish_pedestal_material
		elif node_name.contains("dishpivothousing"):
			mesh.material_override = dish_pivot_material
		elif node_name.contains("dishpivotband"):
			mesh.material_override = signal_material
		elif node_name.contains("dishrib") or node_name.contains("dishrim"):
			mesh.material_override = dish_rim_material
		elif node_name.contains("dishbrace") or node_name.contains("dishactuator"):
			mesh.material_override = actuator_material
		elif node_name.contains("dish"):
			mesh.material_override = dish_material
		elif node_name.contains("feedsignal"):
			mesh.material_override = signal_material


func _dress_observatory_presentation_review_actor(review_actor: Node3D) -> void:
	var dressing := Node3D.new()
	dressing.name = "ObservatorySurveyServiceReviewDressing"
	review_actor.add_child(dressing)
	var base_material := ModelKit3D.material(Color("17262c"), 0.72, 0.44)
	var edge_material := ModelKit3D.material(Color("455b5e"), 0.72, 0.42)
	var console_material := ModelKit3D.material(Color("29383a"), 0.6, 0.48)
	var cyan_signal := ModelKit3D.material(Color("14515a"), 0.34, 0.32, Color("56e0e4"), 1.0)
	var warm_signal := ModelKit3D.material(Color("75402f"), 0.28, 0.62, Color("d47b48"), 0.46)
	ModelKit3D.add_beveled_box(
		dressing,
		Vector3(9.8, 0.3, 5.8),
		Vector3(0.0, 0.18, 0.0),
		base_material,
		Vector3.ZERO,
		"ObservatorySurveyServiceDeck",
		0.16
	)
	for side in [-1.0, 1.0]:
		ModelKit3D.add_cylinder(
			dressing,
			0.11,
			2.6,
			Vector3(side * 4.1, 1.3, -1.85),
			edge_material,
			Vector3.ZERO,
			"ObservatoryServiceDeckPost"
		)
		var console := ModelKit3D.add_beveled_box(
			dressing,
			Vector3(2.2, 1.05, 0.92),
			Vector3(side * 2.25, 0.92, -2.0),
			console_material,
			Vector3.ZERO,
			"ObservatoryApproachConsole",
			0.18
		)
		ModelKit3D.add_surface_panel(
			console,
			Vector3(1.35, 0.5, 0.1),
			Vector3(0.0, 0.18, -0.51),
			console_material,
			cyan_signal,
			Vector3.ZERO,
			"ObservatoryApproachReadout"
		)
	ModelKit3D.add_torus(
		dressing,
		2.18,
		0.075,
		Vector3(-0.4, 3.58, 0.92),
		warm_signal,
		Vector3(PI * 0.12, 0.0, 0.0),
		"ObservatoryDishApertureRing",
		48,
		8
	)
	ModelKit3D.add_beveled_box(
		dressing,
		Vector3(8.6, 0.14, 0.16),
		Vector3(0.0, 2.55, -2.0),
		warm_signal,
		Vector3.ZERO,
		"ObservatoryApproachWarningRail",
		0.18
	)


func _create_buried_labs_presentation_review_actor(landmark: RegionLandmark3D) -> Node3D:
	var review_actor := Node3D.new()
	review_actor.name = "BuriedLabsPresentationReviewActor"
	add_child(review_actor)
	review_actor.global_position = landmark.global_position
	var authored_resource := _load_presentation_review_scene(BURIED_LABS_PRESENTATION_REVIEW_SCENE, "Buried Laboratories")
	if authored_resource == null:
		return review_actor
	var authored_scene := authored_resource.instantiate()
	authored_scene.name = "BuriedLabsPresentationReviewModel"
	review_actor.add_child(authored_scene)
	_tone_buried_labs_presentation_review_walls(authored_scene)
	_dress_buried_labs_presentation_review_actor(review_actor)
	return review_actor


func _tone_buried_labs_presentation_review_walls(authored_scene: Node) -> void:
	var wall_material := ModelKit3D.material(Color("172a30"), 0.26, 0.72)
	var vessel_glass_material := ModelKit3D.material(Color("16434b"), 0.22, 0.44, Color("3c9fa6"), 0.42)
	var vessel_core_material := ModelKit3D.material(Color("281638"), 0.14, 0.42, Color("9259bb"), 0.45)
	var vessel_light_material := ModelKit3D.material(Color("3f2d72"), 0.08, 0.32, Color("ae72df"), 0.62)
	for child in authored_scene.find_children("*", "MeshInstance3D", true, false):
		if not child is MeshInstance3D:
			continue
		var mesh := child as MeshInstance3D
		var node_name := mesh.name.to_lower()
		if node_name.contains("wall") or node_name.contains("containmenthall"):
			mesh.material_override = wall_material
		elif node_name.contains("vesselbody"):
			# Keep the pressure envelope readable as glass under the shared review
			# key; the imported emissive surface was clipping into a flat cyan mass.
			mesh.material_override = vessel_glass_material
		elif node_name.contains("vesselcore"):
			mesh.material_override = vessel_core_material
		elif node_name.contains("vessellight"):
			mesh.material_override = vessel_light_material


func _dress_buried_labs_presentation_review_actor(review_actor: Node3D) -> void:
	var dressing := Node3D.new()
	dressing.name = "BuriedLabsContainmentReviewDressing"
	review_actor.add_child(dressing)
	var frame_dark := ModelKit3D.material(Color("121d22"), 0.82, 0.34)
	var frame_edge := ModelKit3D.material(Color("435457"), 0.76, 0.42)
	var service_metal := ModelKit3D.material(Color("29383b"), 0.62, 0.48)
	var warning := ModelKit3D.material(Color("8b4b32"), 0.34, 0.62)
	var cyan_signal := ModelKit3D.material(Color("15535b"), 0.42, 0.28, Color("62e6e7"), 1.35)
	var violet_signal := ModelKit3D.material(Color("29204a"), 0.34, 0.32, Color("b978f0"), 1.0)

	# A restrained outer frame turns the imported containment vessels into a
	# maintained research bay instead of leaving the pale enclosure planes as
	# the dominant silhouette at the exact review distance.
	for side in [-1.0, 1.0]:
		ModelKit3D.add_beveled_box(
			dressing,
			Vector3(0.34, 5.9, 0.34),
			Vector3(side * 7.4, 2.9, 1.75),
			frame_dark,
			Vector3.ZERO,
			"BuriedLabsOuterFramePost",
			0.18
		)
		ModelKit3D.add_surface_panel(
			dressing,
			Vector3(0.58, 1.05, 0.12),
			Vector3(side * 7.18, 2.2, 1.48),
			frame_dark,
			warning,
			Vector3(0.0, PI * 0.5, 0.0),
			"BuriedLabsOuterWarningPanel"
		)
	ModelKit3D.add_beveled_box(
		dressing,
		Vector3(15.0, 0.34, 0.34),
		Vector3(0.0, 5.8, 1.75),
		frame_edge,
		Vector3.ZERO,
		"BuriedLabsTransferGantry",
		0.18
	)
	ModelKit3D.add_beveled_box(
		dressing,
		Vector3(14.2, 0.24, 0.22),
		Vector3(0.0, 4.62, 1.75),
		warning,
		Vector3.ZERO,
		"BuriedLabsTransferWarningRail",
		0.18
	)

	# Keep the foreground readable as a service level, with one instrument
	# console per vessel and a continuous containment lip around each core.
	ModelKit3D.add_beveled_box(
		dressing,
		Vector3(14.2, 0.26, 2.15),
		Vector3(0.0, 0.22, -2.55),
		service_metal,
		Vector3.ZERO,
		"BuriedLabsServiceWalkway",
		0.16
	)
	for vessel_index in range(3):
		var vessel_x := -4.5 + float(vessel_index) * 4.5
		ModelKit3D.add_torus(
			dressing,
			0.94,
			0.075,
			Vector3(vessel_x, 1.18, 0.0),
			cyan_signal,
			Vector3.ZERO,
			"BuriedLabsContainmentCollar",
			40,
			8
		)
		var console := ModelKit3D.add_beveled_box(
			dressing,
			Vector3(2.55, 1.15, 0.78),
			Vector3(vessel_x, 1.0, -2.28),
			service_metal,
			Vector3.ZERO,
			"BuriedLabsSpecimenConsole",
			0.18
		)
		ModelKit3D.add_surface_panel(
			console,
			Vector3(1.56, 0.52, 0.1),
			Vector3(0.0, 0.18, -0.43),
			frame_dark,
			violet_signal,
			Vector3.ZERO,
			"BuriedLabsSpecimenReadout"
		)
		ModelKit3D.add_tapered_cylinder(
			dressing,
			0.07,
			0.045,
			3.0,
			Vector3(vessel_x, 4.25, 0.0),
			warning,
			Vector3.ZERO,
			"BuriedLabsExtractionDrop"
		)


func _create_tram_graveyard_presentation_review_actor(landmark: RegionLandmark3D) -> Node3D:
	var review_actor := Node3D.new()
	review_actor.name = "TramGraveyardPresentationReviewActor"
	add_child(review_actor)
	review_actor.global_position = landmark.global_position
	var authored_resource := _load_presentation_review_scene(TRAM_GRAVEYARD_PRESENTATION_REVIEW_SCENE, "Tram Graveyard")
	if authored_resource == null:
		return review_actor
	var authored_scene := authored_resource.instantiate()
	authored_scene.name = "TramGraveyardPresentationReviewModel"
	review_actor.add_child(authored_scene)
	# The authored carriage pair supplies the landmark identity. Add a bounded
	# review-only wreck field around it so the exact frame communicates a graveyard
	# rather than two clean parked cars. This has no collision, route, save or
	# runtime-world ownership; it exists only on the development review actor.
	var wreckage := Node3D.new()
	wreckage.name = "TramGraveyardReviewWreckage"
	review_actor.add_child(wreckage)
	var rust := ModelKit3D.material(Color("684331"), 0.32, 0.82)
	var soot := ModelKit3D.material(Color("252b2d"), 0.08, 0.94)
	var dull_glass := ModelKit3D.material(Color("263c40"), 0.16, 0.42)
	ModelKit3D.add_beveled_box(
		wreckage,
		Vector3(3.4, 0.30, 1.0),
		Vector3(-6.8, 0.42, -3.9),
		rust,
		Vector3(0.18, 0.32, 0.28),
		"TramReviewCollapsedPanelA",
		0.18
	)
	ModelKit3D.add_beveled_box(
		wreckage,
		Vector3(2.8, 0.24, 0.82),
		Vector3(6.6, 0.34, 3.8),
		rust,
		Vector3(-0.12, -0.54, -0.34),
		"TramReviewCollapsedPanelB",
		0.16
	)
	ModelKit3D.add_beveled_box(
		wreckage,
		Vector3(2.2, 0.16, 0.52),
		Vector3(5.2, 0.26, -5.0),
		dull_glass,
		Vector3(0.08, 0.28, 0.42),
		"TramReviewBrokenWindowGlass",
		0.12
	)
	ModelKit3D.add_beveled_box(
		wreckage,
		Vector3(0.92, 0.48, 0.10),
		Vector3(-4.35, 2.30, 3.38),
		dull_glass,
		Vector3(0.0, 0.0, -0.22),
		"TramReviewBrokenFrontWindowA",
		0.10
	)
	ModelKit3D.add_beveled_box(
		wreckage,
		Vector3(0.78, 0.42, 0.10),
		Vector3(2.55, 2.26, -1.42),
		dull_glass,
		Vector3(0.0, 0.0, 0.18),
		"TramReviewBrokenFrontWindowB",
		0.10
	)
	ModelKit3D.add_beveled_box(
		wreckage,
		Vector3(3.0, 0.28, 0.78),
		Vector3(-4.4, 0.36, -3.0),
		rust,
		Vector3(0.14, -0.24, 0.30),
		"TramReviewCollapsedPanelC",
		0.16
	)
	ModelKit3D.add_cylinder(
		wreckage,
		0.07,
		3.1,
		Vector3(-7.2, 1.0, 0.7),
		soot,
		Vector3(0.0, 0.0, 1.08),
		"TramReviewBentServicePost"
	)
	ModelKit3D.add_cylinder(
		wreckage,
		0.055,
		2.4,
		Vector3(7.0, 0.82, -0.8),
		rust,
		Vector3(0.12, 0.0, -0.76),
		"TramReviewFallenSignalPost"
	)
	for index in range(6):
		var rubble_position := Vector3(-5.5 + float(index % 3) * 5.4, 0.18, -5.7 + float(index / 3) * 2.1)
		ModelKit3D.add_sphere(
			wreckage,
			0.18 + float(index % 2) * 0.08,
			rubble_position,
			soot if index % 2 == 0 else rust,
			Vector3(1.0, 0.7, 1.2),
			"TramReviewRubble%02d" % index
		)
	return review_actor


func _apply_cathedral_presentation_material_overrides(landmark: Node) -> void:
	# Cathedral Quarter's authored choir, spine and vein meshes are the organic
	# takeover layer. Keep their geometry and authored landmark identity, but
	# use a dry deep-violet material in the compact review frame so the civic
	# brick nave remains legible beside them.
	var organic_material := ModelKit3D.material(Color("241b24"), 0.0, 0.92)
	_apply_cathedral_material_recursive(landmark, organic_material)


func _apply_cathedral_material_recursive(node: Node, organic_material: Material) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var identifier := "%s %s" % [String(child.name).to_lower(), String(child.get_path()).to_lower()]
			if _contains_any_text(identifier, ["choir", "spine", "vein", "broodsac", "brood"]):
				(child as MeshInstance3D).material_override = organic_material
		if child.get_child_count() > 0:
			_apply_cathedral_material_recursive(child, organic_material)


func _contains_any_text(text: String, tokens: Array[String]) -> bool:
	for token in tokens:
		if token in text:
			return true
	return false


func _update_presentation_review_camera(delta: float) -> void:
	if camera == null:
		return
	var target := presentation_review_camera_target
	var desired := presentation_review_camera_desired
	camera.global_position = camera.global_position.lerp(desired, 1.0 - exp(-delta * 5.0))
	# Early flight families need a little more horizontal breathing room than
	# the late folded silhouettes. Keep the models at their authored review
	# scale and widen only this gallery lens instead of shrinking the cast.
	var core_review_fov := 46.0 if presentation_review_page >= 1 else 43.0
	var outpost_page := presentation_review_page == 3 + PRESENTATION_REVIEW_REGIONS.size()
	camera.fov = 42.0 if outpost_page else (44.0 if presentation_review_page == 13 else (46.0 if presentation_review_page == 12 else (48.0 if presentation_review_page == 11 else (52.0 if presentation_review_page >= 3 else core_review_fov))))
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
		# Glasshouse panes and the irrigation header are translucent and metallic;
		# keep the compact review key below the bloom threshold so the crop beds
		# and frame hierarchy remain visible without changing runtime lighting.
		compact_region_light_scale = 0.52
	elif presentation_review_page == 7:
		compact_region_light_scale = 0.58
	elif presentation_review_page == 8:
		compact_region_light_scale = 0.60
	elif presentation_review_page == 9:
		# The rail carriages use a dark teal shell; retain enough review-only
		# key to separate their bodies, windows and undercarriages from the slate
		# backdrop without changing runtime lighting.
		compact_region_light_scale = 0.68
	elif presentation_review_page == 10:
		compact_region_light_scale = 0.58
	elif presentation_review_page == 11:
		# The blue-violet survey dish is broad and shallow. Keep the key restrained
		# enough to preserve the ribs and feed hardware, but not so low that the
		# reflector reads as a flat dark platform.
		compact_region_light_scale = 0.52
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
	var organic_gallery_light_scale := 1.18 if presentation_review_page >= 1 and presentation_review_page <= 2 else 1.0
	var outpost_page := presentation_review_page == 3 + PRESENTATION_REVIEW_REGIONS.size()
	var outpost_gallery_light_scale := 0.72 if outpost_page else 1.0
	# Friendly authored shells carry bright cyan sensors and pale steel. The
	# roster page needs a slightly quieter shared key so copper oxide, rubber,
	# brushed steel and protected tool hardware retain their material breaks.
	# This is review-only; tactical lighting remains unchanged.
	var friendly_roster_light_scale := 0.72 if presentation_review_page == 0 else 1.0
	var review_light_scale := compact_region_light_scale * organic_gallery_light_scale * friendly_roster_light_scale * outpost_gallery_light_scale
	var organic_page := presentation_review_page >= 1 and presentation_review_page <= 2
	if organic_fill != null:
		organic_fill.visible = organic_page
		organic_fill.light_energy = 2.2 if organic_page else 0.0
		# A low, shadowless fill reveals legs, roots and jaw hardware that sit
		# below the broad shell key without changing runtime lighting.
		organic_fill.position = target + Vector3(0.0, 2.6, 7.0)
	# The authored shells already carry high-frequency normal detail. Removing
	# only the organic gallery key's hard shadows keeps plates, ribs and
	# membranes from collapsing into black bands at compact acceptance
	# resolution; restore the normal review shadows when browsing regions.
	for review_light in [front_fill, warm_light, cool_light, rim_light]:
		if review_light != null:
			review_light.shadow_enabled = not organic_page
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
	_set_title_camera()
	if release_audio != null:
		release_audio.set_title_screen_active(true)
	player.input_enabled = false
	_set_tactical_hud_visible(false)
	get_tree().paused = false
	release_front_end.show_title(transactional_save_service.has_valid_save(RELEASE_SLOT) or _legacy_save_exists())
	if title_pause_timer != null:
		title_pause_timer.start(0.12)


func _set_title_camera() -> void:
	# The title is an authored world threshold, not an abstract loading card.
	# Frame the Heartforge and the two opening silhouettes on the open side of
	# the left-weighted menu while leaving the playable tactical camera unchanged.
	# A slightly higher, calmer angle clears the foreground service gantry that
	# previously cut across the forge's thermal core and made the title image
	# read as infrastructure before sanctuary.
	if camera == null or heartforge == null:
		return
	var title_target := heartforge.global_position + Vector3(0.0, 2.0, 1.4)
	camera.global_position = title_target + Vector3(9.2, 8.1, 16.0)
	camera.look_at(title_target, Vector3.UP)
	camera.fov = 44.0


func _pause_title_after_first_frame() -> void:
	# A paused SceneTree can present the initial swapchain as a transparent
	# frame on desktop OpenGL. Let the title render briefly before freezing the
	# simulation so the menu is visible without allowing gameplay to run.
	if release_started or release_front_end == null:
		return
	if release_front_end.active_screen == &"title":
		get_tree().paused = true


func _start_release_world() -> void:
	if title_pause_timer != null:
		title_pause_timer.stop()
	release_started = true
	paused = false
	if release_audio != null:
		release_audio.set_title_screen_active(false)
	game_ended = false
	get_tree().paused = false
	player.input_enabled = true
	_snap_release_camera_to_subject()
	_set_tactical_hud_visible(true)
	release_front_end.hide_all()
	settings_service.apply_accessibility_to_tree(self)
	if run_variation_director != null:
		run_variation_director.ensure_current_variant()
		var variant_key := String(run_state.world_variant_id).replace("weather.", "")
		var variant_name := localization_service.text("world.condition.%s.name" % variant_key)
		hud.push_notification(localization_service.text("notification.world_condition", [variant_name]))
	hud.push_notification(localization_service.text("notification.survival_profile"))


func _should_build_city_on_boot() -> bool:
	# A normal windowed launch is a title-screen boot. Keep the forge, player and
	# companion available for the authored title backdrop, but defer the costly
	# city construction until New World/Continue or an explicit review mode.
	# Headless validation and all review fixtures intentionally retain the full
	# world so their structural and visual contracts remain meaningful.
	if _is_headless_release() or pending_launch_mode in [&"new", &"continue"]:
		return true
	var arguments := OS.get_cmdline_args()
	arguments.append_array(OS.get_cmdline_user_args())
	for argument in arguments:
		var raw_argument := str(argument)
		if raw_argument in [
			"--new", "--new-world", "--presentation-review", "--title-review",
			"--stream-ring-review", "--route-memory-review", "--route-recovery-marker-review",
			"--dynamic-operation-review", "--authored-operation-review", "--casualty-recovery-review",
			"--concurrent-operation-review",
			"--run-variation-review", "--heartforge-progression-review", "--adaptive-defense-review",
			"--complete-objective-review", "--endgame-protocol-review", "--mechromancer-evolution-review",
		]:
			return true
		if raw_argument.begins_with("--endgame-protocol-review="):
			return true
	return false


func _on_run_state_event_logged(message: String) -> void:
	if message == "The Heartforge light is weak. The companion is your only reliable protection.":
		hud.push_notification(_localized_runtime_text(
			"notification.event.heartforge_weak",
			"HEARTFORGE LIGHT IS WEAK · THE COMPANION IS YOUR ONLY RELIABLE PROTECTION"
		))
		return
	if message == "The Bulwark projects a visible route to the nearest recoverable wreck.":
		hud.push_notification(_localized_runtime_text(
			"notification.event.route_ready",
			"THE BULWARK PROJECTS A VISIBLE ROUTE TO THE NEAREST RECOVERABLE WRECK"
		))
		return
	# These stable log entries are useful in diagnostics but are not player
	# reports. Suppress their raw English copy from the release HUD; the
	# actionable release callbacks already provide localized summaries.
	for diagnostic_prefix in [
		"Presentation status:",
		"The opening district, remote regions and endgame landmarks share",
		"The complete systemic run is active.",
		"Full-game progression is active.",
		"Enemy escalation is population-driven.",
		"MACHINE WITNESS ·",
		"Long-range operation complete:",
		"Disabled machine recovered:",
		"CASUALTY BEACON ·",
		"You recovered ",
		"A level ",
		"The weak pistol finished a ",
		"Distributed Continuity rebuilt the Heartforge after catastrophic failure.",
	]:
		if message.begins_with(diagnostic_prefix):
			return
	if message.begins_with("Adaptive Heartforge proposal available:"):
		var proposal_summary := message.trim_prefix("Adaptive Heartforge proposal available:").strip_edges()
		var proposal_director := get_node_or_null("AdaptiveDefenseDirector") as AdaptiveDefenseDirector3D
		if proposal_director != null and proposal_director.has_pending_proposal():
			proposal_summary = proposal_director.proposal_summary()
		hud.push_notification(_localized_runtime_text(
			"notification.adaptive.proposal",
			"ADAPTIVE DEFENCE PROPOSAL · PRESS T TO CHOOSE\n{0}",
			[proposal_summary]
		))
		return
	if message.begins_with("Adaptive Heartforge response completed:"):
		var completed_name := message.trim_prefix("Adaptive Heartforge response completed:").strip_edges()
		var completion_director := get_node_or_null("AdaptiveDefenseDirector") as AdaptiveDefenseDirector3D
		if completion_director != null and completion_director.completed_adaptation != &"":
			var localized_entry := completion_director.localized_adaptation(completion_director.completed_adaptation)
			completed_name = str(localized_entry.get("display_name", completed_name))
		hud.push_notification(_localized_runtime_text(
			"notification.adaptive.complete",
			"HEARTFORGE RESPONSE ONLINE · {0} · THE NEW STRUCTURE IS NOW MACHINE-MAINTAINED",
			[completed_name.to_upper()]
		))
		return
	if message.begins_with("World condition: "):
		var variant_key := String(run_state.world_variant_id).replace("weather.", "")
		var variant_name := localization_service.text("world.condition.%s.name" % variant_key)
		var variant_description := localization_service.text("world.condition.%s.description" % variant_key)
		hud.push_notification(localization_service.text("notification.world_condition_detail", [variant_name, variant_description]))
		return
	if message.begins_with("Town record recovered: "):
		var record_name := message.trim_prefix("Town record recovered: ")
		var record_key := ""
		if record_name == "The Severed Root":
			record_key = "endgame_severance"
		elif record_name == "The Caged Root":
			record_key = "endgame_containment"
		elif record_name == "The Transformed Root":
			record_key = "endgame_transformation"
		if not record_key.is_empty():
			hud.push_notification(localization_service.text("notification.town_record_recovered", [localization_service.text("story.record.%s.name" % record_key)]))
			return
	if message.begins_with("Technology unlocked: "):
		var technology_name := message.trim_prefix("Technology unlocked: ")
		var technology_key := "technology.name.%s" % technology_name.to_lower().replace(" ", "_")
		var localized_name := localization_service.text(technology_key)
		if localized_name != technology_key:
			hud.push_notification(localization_service.text("notification.technology_unlocked", [localized_name.to_upper()]))
			return
	if message.begins_with("First victory achieved through "):
		var protocol_name := message.trim_prefix("First victory achieved through ").trim_suffix(".")
		var protocol_key := protocol_name.to_lower()
		var localized_protocol := localization_service.text("endgame.%s.name" % protocol_key)
		if localized_protocol != "endgame.%s.name" % protocol_key:
			hud.push_notification(localization_service.text("notification.first_victory_achieved", [localized_protocol]))
			return
	if message.ends_with(" integrity."):
		var status_parts := message.trim_suffix(".").split(" ")
		if status_parts.size() >= 9 and status_parts[1] == "outpost" and status_parts[2] == "at" and status_parts[4] == "is" and status_parts[5] == "tier" and status_parts[7] == "with":
			var role_key := status_parts[0].to_lower()
			var site_key := status_parts[3].replace(".", "_")
			var role_name := localization_service.text("outpost.role.%s" % role_key)
			var site_name := localization_service.text("outpost.site.%s.name" % site_key)
			if role_name != "outpost.role.%s" % role_key and site_name != "outpost.site.%s.name" % site_key:
				hud.push_notification(localization_service.text("notification.outpost_status", [role_name, site_name, status_parts[6], status_parts[8].trim_suffix("%")]))
				return
	super._on_run_state_event_logged(message)


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
	_refresh_hud_accessibility_layout()
	release_audio.play_effect(&"ui_confirm", "", 0.0, -4.0)


func _on_release_locale_changed(_locale: StringName) -> void:
	if hud != null:
		hud.refresh_localized_text()
	if strategic_hud != null:
		strategic_hud.refresh_localized_text()
	if operations_hud != null:
		operations_hud.refresh_localized_text()
	var operation_detail := get_node_or_null("OperationDetailDirector")
	if operation_detail != null and operation_detail.has_method(&"refresh_localized_text"):
		operation_detail.call(&"refresh_localized_text")
	var enemy_tier_hud := get_node_or_null("EnemyTierHUD")
	if enemy_tier_hud != null and enemy_tier_hud.has_method(&"refresh_localized_text"):
		enemy_tier_hud.call(&"refresh_localized_text")
	var enemy_tier_bootstrap := get_node_or_null("EnemyTierProgressionBootstrap")
	if enemy_tier_bootstrap != null:
		var intel_hud := enemy_tier_bootstrap.get_node_or_null("EnemyTierIntelHUD")
		if intel_hud != null and intel_hud.has_method(&"refresh_localized_text"):
			intel_hud.call(&"refresh_localized_text")
	refresh_input_legend()


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
	_refresh_hud_accessibility_layout()
	refresh_input_legend()


func _refresh_hud_accessibility_layout() -> void:
	if hud == null or not is_instance_valid(hud):
		return
	hud.apply_safe_layout(Vector2(get_viewport().get_visible_rect().size))


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
		hud.push_notification(_localized_runtime_text("notification.follow.active" if follow_operation else "notification.follow.returned", "FOLLOWING ACTIVE MACHINE GROUP" if follow_operation else "CAMERA RETURNED TO THE MECHROMANCER"))
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
		hud.push_notification(_localized_runtime_text("notification.continuity.consumed", "DISTRIBUTED CONTINUITY CONSUMED · HEARTFORGE RECOVERED AT 48% · {0} SCRAP LOST", [loss]))
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
			enemies.append({
				"species": String(enemy.species),
				"position": _vector_to_array(enemy.global_position),
				"health": enemy.current_health,
				"aggression": enemy.aggression,
				"tier": int(enemy.get_meta(&"enemy_tier", 0)),
				"home_nest_id": str(enemy.get_meta(&"home_nest_id", "")),
			})
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
		var species := StringName(str(enemy_data.get("species", "skitterling")))
		var enemy := _spawn_enemy(_array_to_vector(enemy_data.get("position", [20, 0, -20])), species)
		enemy.current_health = clampf(float(enemy_data.get("health", enemy.maximum_health)), 0.0, enemy.maximum_health)
		enemy.aggression = clampf(float(enemy_data.get("aggression", enemy.aggression)), 0.0, 1.0)
		var tier_progression := get_tree().get_first_node_in_group(&"enemy_tier_progression")
		if tier_progression != null and tier_progression.has_method(&"assign_enemy_tier"):
			var restored_tier := int(enemy_data.get("tier", 0))
			if restored_tier <= 0 and tier_progression.has_method(&"infer_tier_for_species"):
				restored_tier = int(tier_progression.call(&"infer_tier_for_species", species))
			var home_nest_id := StringName(str(enemy_data.get("home_nest_id", "")))
			tier_progression.call(&"assign_enemy_tier", enemy, restored_tier, home_nest_id)
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
