class_name IronwrightTieredWorld3D
extends IronwrightReleaseWorld3D

var _pending_restore_enemy_data: Array[Dictionary] = []
var _ecology_runtime_review_capture_path: String = ""
var _ecology_runtime_review_camera_active: bool = false
var _ecology_runtime_review_camera_nest: Node3D
var _ecology_runtime_review_camera_enemy: Node3D


func _ready() -> void:
	super._ready()
	_disable_legacy_population_materialization()
	run_state.log_event("Enemy escalation is population-driven. Saturated lower tiers convert reproductive capacity into rarer, more intelligent organisms.")


func _process(delta: float) -> void:
	super._process(delta)
	if not _ecology_runtime_review_camera_active:
		return
	if camera == null or not is_instance_valid(_ecology_runtime_review_camera_nest) or not is_instance_valid(_ecology_runtime_review_camera_enemy):
		return
	var nest_position := _ecology_runtime_review_camera_nest.global_position
	var enemy_position := _ecology_runtime_review_camera_enemy.global_position
	var player_position := player.global_position
	var center := (nest_position + enemy_position + player_position) / 3.0 + Vector3.UP * 0.7
	var away_from_nest := player_position - nest_position
	away_from_nest.y = 0.0
	if away_from_nest.length_squared() <= 0.001:
		away_from_nest = Vector3.FORWARD
	var review_camera_position := center + Vector3.UP * 8.0 + away_from_nest.normalized() * 11.0
	camera.global_position = review_camera_position
	camera.look_at(center, Vector3.UP)
	camera.fov = 48.0


func _disable_legacy_population_materialization() -> void:
	# Earlier directors retain noise propagation, pressure, ecological memory,
	# and behavior context. They no longer own births: every ordinary organism
	# must pass through a tier cap and a living physical nest.
	if ecology_director != null:
		ecology_director.set_external_population_control(true)
		ecology_director.spawn_enemy_callable = Callable()
	if strategic_ecology_director != null:
		strategic_ecology_director.set_external_population_control(true)
		strategic_ecology_director.spawn_enemy_callback = Callable()
	if long_operation_director != null:
		long_operation_director.spawn_enemy_callback = Callable(self, "_spawn_capped_operation_threat").bind(&"operation_disturbance")
	if endgame_director != null:
		endgame_director.spawn_enemy_callback = Callable(self, "_spawn_capped_operation_threat").bind(&"endgame_disturbance")


func _canonical_enemy_tier_director() -> EnemyTierProgressionDirector3D:
	return get_tree().get_first_node_in_group(&"enemy_tier_progression") as EnemyTierProgressionDirector3D


func _start_ecology_runtime_review() -> void:
	print("ECOLOGY_RUNTIME_REVIEW requested")
	_ecology_runtime_review_capture_path = _ecology_runtime_review_capture_argument()
	if not await _await_enemy_tier_bootstrap_initialized():
		print("ECOLOGY_RUNTIME_REVIEW failed: canonical startup timeout")
		hud.push_notification("ECOLOGY REVIEW FAILED · CANONICAL ECOLOGY STARTUP DID NOT COMPLETE")
		return
	var canonical := _canonical_enemy_tier_director()
	if canonical == null or canonical.nests.is_empty():
		print("ECOLOGY_RUNTIME_REVIEW failed: canonical nest network unavailable")
		hud.push_notification("ECOLOGY REVIEW FAILED · CANONICAL NEST NETWORK IS UNAVAILABLE")
		return
	var review_nest: Node3D
	var review_nest_distance := INF
	for raw_nest in canonical.nests.values():
		if not (raw_nest is Node3D) or not is_instance_valid(raw_nest):
			continue
		var candidate := raw_nest as Node3D
		if not candidate.has_method(&"can_spawn_tier") or not bool(candidate.call(&"can_spawn_tier", 2)):
			continue
		var distance_to_home := candidate.global_position.distance_squared_to(heartforge.global_position)
		if review_nest == null or distance_to_home < review_nest_distance:
			review_nest = candidate
			review_nest_distance = distance_to_home
	if review_nest == null:
		review_nest = canonical.nests.values()[0] as Node3D
	var approach_direction := heartforge.global_position - review_nest.global_position
	approach_direction.y = 0.0
	if approach_direction.length_squared() <= 0.001:
		approach_direction = Vector3.FORWARD
	# Face away from the nest so the normal tactical camera looks through the
	# Mechromancer toward the physical source and its newly born organism.
	camera_heading = approach_direction.normalized()
	player.global_position = review_nest.global_position + approach_direction.normalized() * 15.0
	player.velocity = Vector3.ZERO
	_snap_release_camera_to_subject()
	if region_atmosphere_director != null:
		region_atmosphere_director.refresh_now()
	if region_lod_director != null:
		region_lod_director.refresh_now()
	# Review-only staging earns one Tier-II reproduction credit so this explicit
	# visual fixture proves a physical nest birth without weakening the runtime
	# rule that operations and endgame incidents must spend canonical credit.
	canonical.spawn_credit[2] = maxf(float(canonical.spawn_credit.get(2, 0.0)), 1.0)
	var review_enemy := canonical.request_causal_threat(player.global_position, &"burrower", &"ecology_review_disturbance", 2)
	if review_enemy == null:
		print("ECOLOGY_RUNTIME_REVIEW failed: no compatible living nest response")
		hud.push_notification("ECOLOGY REVIEW FAILED · NO LIVING COMPATIBLE NEST COULD RESPOND")
		return
	print("ECOLOGY_RUNTIME_REVIEW ready: nest=%s enemy=%s tier=%d" % [String(review_nest.get("nest_id")), String(review_enemy.name), int(review_enemy.get_meta(&"enemy_tier", 0))])
	hud.push_notification("ECOLOGY RUNTIME REVIEW · A CAPPED ORGANISM EMERGED AT A LIVING NEST AND IS MOVING TOWARD THE DISTURBANCE · PRESS M FOR THE SINGLE ECOLOGY INTELLIGENCE PANEL")
	if not _ecology_runtime_review_capture_path.is_empty():
		_ecology_runtime_review_camera_nest = review_nest
		_ecology_runtime_review_camera_enemy = review_enemy as Node3D
		_ecology_runtime_review_camera_active = true
		_capture_ecology_runtime_review()


func _capture_ecology_runtime_review() -> void:
	# Let the physical birth, camera snap, atmosphere, and LOD refresh render
	# before capturing. This remains a silent developer review path.
	await get_tree().process_frame
	await get_tree().process_frame
	var review_image := get_viewport().get_texture().get_image()
	var capture_error := review_image.save_png(_ecology_runtime_review_capture_path)
	if capture_error == OK:
		print("Ecology runtime review screenshot written to %s" % _ecology_runtime_review_capture_path)
	else:
		push_error("Ecology runtime review screenshot failed: %s" % capture_error)
	_ecology_runtime_review_capture_path = ""
	_ecology_runtime_review_camera_active = false
	_ecology_runtime_review_camera_nest = null
	_ecology_runtime_review_camera_enemy = null


func _ecology_runtime_review_capture_argument() -> String:
	var arguments: Array = OS.get_cmdline_args()
	arguments.append_array(OS.get_cmdline_user_args())
	for index in arguments.size():
		var argument := str(arguments[index])
		if argument.begins_with("--ecology-runtime-review-screenshot="):
			return argument.get_slice("=", 1)
		if argument == "--ecology-runtime-review-screenshot" and index + 1 < arguments.size():
			return str(arguments[index + 1])
	return ""


func _spawn_enemy(position: Vector3, species: StringName) -> OrganicEnemy3D:
	var enemy := super._spawn_enemy(position, species)
	if not (enemy is OrganicEnemyTiered3D):
		return enemy
	var tiered := enemy as OrganicEnemyTiered3D
	var restored: Dictionary = {}
	if not _pending_restore_enemy_data.is_empty():
		restored = _pending_restore_enemy_data.pop_front()
	if not restored.is_empty() and not str(restored.get("name", "")).is_empty():
		tiered.name = str(restored.get("name"))
	var canonical_tier_director := _canonical_enemy_tier_director()
	if canonical_tier_director != null:
		var canonical_tier := int(restored.get("canonical_enemy_tier", restored.get("enemy_tier", 0)))
		if canonical_tier <= 0:
			canonical_tier = canonical_tier_director.infer_tier_for_species(species)
		var home_nest_id := StringName(str(restored.get("home_nest_id", "")))
		canonical_tier_director.assign_enemy_tier(tiered, canonical_tier, home_nest_id)
	if not restored.is_empty():
		var territory := _array_to_vector(restored.get("territory_origin", _vector_to_array(position)))
		var radius := float(restored.get("territory_radius", tiered.territory_radius))
		var directive := StringName(str(restored.get("ecology_directive", String(tiered.ecology_directive))))
		tiered.configure_ecology(territory, radius, directive)
		tiered.last_known_prey_position = _array_to_vector(restored.get("last_known_prey_position", [0.0, 0.0, 0.0]))
		tiered.has_last_known_prey = bool(restored.get("has_last_known_prey", false))
	if release_world_art != null:
		release_world_art.apply_to_node(tiered)
	return tiered


func _spawn_canonical_enemy_from_nest(position: Vector3, species: StringName, tier: int, home_nest_id: StringName) -> OrganicEnemy3D:
	# Canonical births already know their tier and physical origin. Bypass the
	# generic restore-aware wrapper so the brain is configured once with its real
	# home instead of briefly receiving an empty-home fallback assignment.
	var enemy := super._spawn_enemy(position, species)
	if enemy is OrganicEnemyTiered3D:
		var canonical_tier_director := _canonical_enemy_tier_director()
		if canonical_tier_director != null:
			canonical_tier_director.assign_enemy_tier(enemy, tier, home_nest_id)
		if release_world_art != null:
			release_world_art.apply_to_node(enemy)
	return enemy


func _spawn_capped_operation_threat(position: Vector3, species: StringName, source_kind: StringName = &"operation_disturbance") -> Node:
	var canonical_tier_director := _canonical_enemy_tier_director()
	if canonical_tier_director == null:
		return null
	var requested_tier := canonical_tier_director.infer_tier_for_species(species)
	match species:
		&"razorhound", &"burrower":
			requested_tier = 2
		&"sporecaster":
			requested_tier = 3
		&"broodmass":
			requested_tier = 4
		&"apex":
			requested_tier = 5
	return canonical_tier_director.request_causal_threat(position, species, source_kind, requested_tier)


func _apply_balance_to_existing_world() -> void:
	super._apply_balance_to_existing_world()


func _collect_release_snapshot() -> Dictionary:
	var snapshot := super._collect_release_snapshot()
	var base: Dictionary = snapshot.get("base", {})
	var enemies: Array[Dictionary] = []
	for node in get_tree().get_nodes_in_group(&"organic_enemies"):
		if not (node is OrganicEnemy3D) or not is_instance_valid(node):
			continue
		var enemy := node as OrganicEnemy3D
		if not enemy.is_alive():
			continue
		var tier := int(enemy.get_meta(&"enemy_tier", enemy.get("enemy_tier") if enemy.get("enemy_tier") != null else 1))
		var runtime_intent: Dictionary = {}
		var causal_destination: Array = []
		var brain := enemy.get_node_or_null("EnemyTierBrain")
		if brain != null and brain.has_method(&"serialize_runtime_intent"):
			var raw_runtime_intent: Variant = brain.call(&"serialize_runtime_intent")
			if raw_runtime_intent is Dictionary:
				runtime_intent = (raw_runtime_intent as Dictionary).duplicate(true)
		var raw_causal_destination: Variant = enemy.get_meta(&"causal_destination", [])
		if raw_causal_destination is Array:
			causal_destination = (raw_causal_destination as Array).duplicate(true)
		enemies.append({
			"name": String(enemy.name),
			"species": String(enemy.species),
			"enemy_tier": tier,
			"canonical_enemy_tier": int(enemy.get_meta(&"enemy_tier", tier)),
			"home_nest_id": str(enemy.get_meta(&"home_nest_id", "")),
			"position": _vector_to_array(enemy.global_position),
			"health": enemy.current_health,
			"aggression": enemy.aggression,
			"territory_origin": _vector_to_array(enemy.territory_origin),
			"territory_radius": enemy.territory_radius,
			"ecology_directive": String(enemy.ecology_directive),
			"last_known_prey_position": _vector_to_array(enemy.last_known_prey_position),
			"has_last_known_prey": enemy.has_last_known_prey,
			"ecology_region": str(enemy.get_meta(&"ecology_region", "")),
			"ecology_region_previous": str(enemy.get_meta(&"ecology_region_previous", "")),
			"ecology_origin": str(enemy.get_meta(&"ecology_origin", "")),
			"causal_source_kind": str(enemy.get_meta(&"causal_source_kind", "")),
			"causal_destination": causal_destination,
			"enemy_pack_id": str(enemy.get_meta(&"enemy_pack_id", "")),
			"enemy_behaviour": str(enemy.get_meta(&"enemy_behaviour", "")),
			"enemy_behaviour_reason": str(enemy.get_meta(&"enemy_behaviour_reason", "")),
			"brain_runtime_intent": runtime_intent,
		})
	base["enemies"] = enemies
	snapshot["base"] = base

	var release: Dictionary = snapshot.get("release", {})
	var canonical_tier_director := _canonical_enemy_tier_director()
	release["enemy_tier_progression"] = canonical_tier_director.to_dictionary() if canonical_tier_director != null else {}
	snapshot["release"] = release
	return snapshot


func _restore_release_snapshot(snapshot: Dictionary) -> void:
	set_meta(&"enemy_tier_progression_restored_from_unified", false)
	set_meta(&"enemy_tier_progression_migrated_from_sidecar", false)
	set_meta(&"enemy_tier_progression_reconstructed_from_world", false)
	_pending_restore_enemy_data.clear()
	var base: Dictionary = snapshot.get("base", {})
	for raw_enemy in base.get("enemies", []):
		if raw_enemy is Dictionary:
			_pending_restore_enemy_data.append((raw_enemy as Dictionary).duplicate(true))
	var canonical_tier_director := _canonical_enemy_tier_director()
	var release: Dictionary = snapshot.get("release", {})
	var canonical_state: Variant = release.get("enemy_tier_progression", {})
	var has_unified_canonical_state := canonical_state is Dictionary and not (canonical_state as Dictionary).is_empty()
	if canonical_tier_director != null:
		canonical_tier_director.enabled = false
		if not has_unified_canonical_state:
			_reset_canonical_enemy_tier_state(canonical_tier_director)
	super._restore_release_snapshot(snapshot)
	_pending_restore_enemy_data.clear()
	if canonical_tier_director != null:
		if has_unified_canonical_state:
			canonical_tier_director.restore_from_dictionary(canonical_state as Dictionary)
			set_meta(&"enemy_tier_progression_restored_from_unified", true)
		_restore_canonical_enemy_continuity(canonical_tier_director, base.get("enemies", []))
		if not has_unified_canonical_state:
			_reconstruct_canonical_enemy_tier_state(canonical_tier_director)
			set_meta(&"enemy_tier_progression_reconstructed_from_world", true)
		canonical_tier_director.enabled = true
		canonical_tier_director._reconcile_population()
		canonical_tier_director._refresh_nest_sources()
		canonical_tier_director._emit_intel_if_changed(true)


func _reset_canonical_enemy_tier_state(director: EnemyTierProgressionDirector3D) -> void:
	# A legacy snapshot has no canonical tier generation. Start from authored
	# defaults before loading its actors so a missing or corrupt RC1 sidecar can
	# never inherit rates, credits, events, or damaged nests from the prior run.
	director._spawn_configured_nests()
	director._initialize_state()
	director.applied_events.clear()
	director.connected_enemies.clear()
	director.elapsed_seconds = 0.0
	director.spawn_serial = 0
	director.simulation_clock = 0.0
	director.reconcile_clock = 0.0
	director.intel_clock = 0.0
	director.last_heartforge_tier = 1
	director.last_intel_signature = ""
	director.tier_1_growth_per_second = maxf(0.0, float(director.config.get("tier_1_rate_growth_per_minute_per_minute", 1.0)) / 60.0)

	var authored_nest_ids: Dictionary = {}
	for raw_entry in director.config.get("nest_archetypes", []):
		if not (raw_entry is Dictionary):
			continue
		var entry := raw_entry as Dictionary
		var nest_id := StringName(str(entry.get("id", "")))
		if nest_id == &"":
			continue
		authored_nest_ids[nest_id] = true
		var raw_nest: Variant = director.nests.get(nest_id, null)
		if raw_nest == null or not is_instance_valid(raw_nest):
			continue
		var nest := raw_nest as Node
		if nest.has_method(&"configure"):
			nest.call(&"configure", entry)
		if nest.has_method(&"restore_from_dictionary"):
			nest.call(&"restore_from_dictionary", {
				"alive": true,
				"maturity": float(entry.get("maturity", 0.5)),
				"current_health": float(entry.get("maximum_health", 250.0)),
				"destroyed_elapsed": 0.0,
				"regrowth_progress": 0.0,
				"state_name": "active",
				"spawn_serial": 0,
			})
	for raw_nest_id in director.nests.keys():
		if not authored_nest_ids.has(StringName(str(raw_nest_id))):
			director.nests.erase(raw_nest_id)
	director._refresh_nest_sources()


func _reconstruct_canonical_enemy_tier_state(director: EnemyTierProgressionDirector3D) -> void:
	# Exact RC1 values come from a verified sidecar in the following process
	# frame. If none verifies, derive the safest deterministic generation from
	# the loaded actors and completed world progression instead of stale memory.
	director._reconcile_population()
	director._refresh_nest_sources()
	director._poll_world_progression()
	if progression != null:
		for technology_id in progression.unlocked_technologies:
			director.apply_event(StringName(str(technology_id)))
	if endgame_director != null:
		var protocol_id := endgame_director.completed_protocol
		if protocol_id == &"" and not endgame_director.active_protocol.is_empty():
			protocol_id = StringName(str(endgame_director.active_protocol.get("id", "")))
		if protocol_id != &"":
			director.apply_event(protocol_id)
	director.elapsed_seconds = maxf(0.0, run_state.elapsed_seconds)


func _restore_canonical_enemy_continuity(director: EnemyTierProgressionDirector3D, saved_enemies: Variant) -> void:
	if not (saved_enemies is Array):
		return
	for raw_enemy in saved_enemies:
		if not (raw_enemy is Dictionary):
			continue
		var saved_enemy := raw_enemy as Dictionary
		var saved_name := str(saved_enemy.get("name", ""))
		if saved_name.is_empty():
			continue
		var restored_enemy := _restored_enemy_by_name(saved_name)
		if restored_enemy == null:
			continue
		var restored_tier := int(saved_enemy.get("canonical_enemy_tier", saved_enemy.get("enemy_tier", 1)))
		var restored_home := StringName(str(saved_enemy.get("home_nest_id", "")))
		director.assign_enemy_tier(restored_enemy, restored_tier, restored_home)
		for metadata_key in [&"ecology_region", &"ecology_region_previous", &"ecology_origin", &"causal_source_kind", &"causal_destination", &"enemy_pack_id", &"enemy_behaviour", &"enemy_behaviour_reason"]:
			var storage_key := String(metadata_key)
			if saved_enemy.has(storage_key):
				var metadata_value: Variant = saved_enemy.get(storage_key)
				if metadata_value is Array:
					metadata_value = (metadata_value as Array).duplicate(true)
				elif metadata_value is Dictionary:
					metadata_value = (metadata_value as Dictionary).duplicate(true)
				restored_enemy.set_meta(metadata_key, metadata_value)
		var runtime_intent: Variant = saved_enemy.get("brain_runtime_intent", {})
		var brain := restored_enemy.get_node_or_null("EnemyTierBrain")
		if brain != null and runtime_intent is Dictionary and not (runtime_intent as Dictionary).is_empty() and brain.has_method(&"restore_runtime_intent"):
			var saved_pack_id := StringName(str(saved_enemy.get("enemy_pack_id", "")))
			if saved_pack_id != &"":
				brain.set("pack_id", saved_pack_id)
			brain.call(&"restore_runtime_intent", runtime_intent)


func _restored_enemy_by_name(saved_name: String) -> OrganicEnemy3D:
	var direct := get_node_or_null(NodePath(saved_name))
	if direct is OrganicEnemy3D:
		return direct as OrganicEnemy3D
	for raw_enemy in get_tree().get_nodes_in_group(&"organic_enemies"):
		if raw_enemy is OrganicEnemy3D and is_instance_valid(raw_enemy) and String(raw_enemy.name) == saved_name:
			return raw_enemy as OrganicEnemy3D
	return null


func _clear_runtime_entities() -> void:
	var preserved_nests: Array[OrganicNest3D] = []
	for node in get_tree().get_nodes_in_group(&"organic_nests"):
		if node is OrganicNest3D and is_instance_valid(node):
			var nest := node as OrganicNest3D
			preserved_nests.append(nest)
			if nest.is_in_group(&"organic_enemies"):
				nest.remove_from_group(&"organic_enemies")
	super._clear_runtime_entities()
	for nest in preserved_nests:
		if is_instance_valid(nest):
			nest.add_to_group(&"organic_enemies")
