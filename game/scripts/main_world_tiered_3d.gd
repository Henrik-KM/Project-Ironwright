class_name IronwrightTieredWorld3D
extends IronwrightReleaseWorld3D

var enemy_tier_director: EnemyTierDirector3D
var enemy_tier_event_bridge: EnemyTierEventBridge3D
var enemy_tier_hud: EnemyTierHUD3D
var _pending_restore_enemy_data: Array[Dictionary] = []
var _last_tier_map_mode: bool = false


func _ready() -> void:
    super._ready()
    _disable_legacy_population_materialization()
    _setup_enemy_tier_progression()
    _connect_enemy_tier_progression()
    _last_tier_map_mode = map_mode
    enemy_tier_hud.set_map_visible(map_mode)
    run_state.log_event("Enemy escalation is population-driven. Saturated lower tiers convert reproductive capacity into rarer, more intelligent organisms.")


func _process(delta: float) -> void:
    super._process(delta)
    if enemy_tier_hud != null and map_mode != _last_tier_map_mode:
        _last_tier_map_mode = map_mode
        enemy_tier_hud.set_map_visible(map_mode)


func _disable_legacy_population_materialization() -> void:
    # Earlier directors retain noise propagation, pressure, ecological memory,
    # and behavior context. They no longer own births: every ordinary organism
    # must pass through a tier cap and a living physical nest.
    if ecology_director != null:
        ecology_director.set_external_population_control(true)
        ecology_director.spawn_enemy_callable = Callable()
    if strategic_ecology_director != null:
        strategic_ecology_director.spawn_enemy_callback = Callable()
    if long_operation_director != null:
        long_operation_director.spawn_enemy_callback = Callable(self, "_spawn_capped_operation_threat")
    if endgame_director != null:
        endgame_director.spawn_enemy_callback = Callable(self, "_spawn_capped_operation_threat")


func _setup_enemy_tier_progression() -> void:
    enemy_tier_director = EnemyTierDirector3D.new()
    enemy_tier_director.name = "EnemyTierDirector"
    enemy_tier_director.process_mode = Node.PROCESS_MODE_PAUSABLE
    enemy_tier_director.configure(
        run_state,
        ecology_director,
        strategic_ecology_director,
        region_director,
        long_operation_director,
        progression,
        Callable(self, "_spawn_enemy"),
        self
    )
    add_child(enemy_tier_director)

    enemy_tier_event_bridge = EnemyTierEventBridge3D.new()
    enemy_tier_event_bridge.name = "EnemyTierEventBridge"
    enemy_tier_event_bridge.process_mode = Node.PROCESS_MODE_PAUSABLE
    enemy_tier_event_bridge.configure(enemy_tier_director, long_operation_director, progression, endgame_director)
    add_child(enemy_tier_event_bridge)

    enemy_tier_hud = EnemyTierHUD3D.new()
    enemy_tier_hud.name = "EnemyTierHUD"
    add_child(enemy_tier_hud)
    enemy_tier_hud.set_snapshot(enemy_tier_director.snapshot())


func _connect_enemy_tier_progression() -> void:
    enemy_tier_director.snapshot_changed.connect(enemy_tier_hud.set_snapshot)
    enemy_tier_director.ecology_report.connect(_on_tier_ecology_report)
    enemy_tier_director.tier_first_observed.connect(_on_tier_first_observed)
    enemy_tier_director.saturation_transferred.connect(_on_tier_saturation_transferred)
    enemy_tier_director.nest_cleared.connect(_on_tier_nest_cleared)


func _on_tier_ecology_report(message: String) -> void:
    run_state.log_event(message)


func _on_tier_first_observed(tier: int, display_name: String) -> void:
    hud.push_notification("NEW ENEMY TIER CONFIRMED · TIER %d %s\nMachine intelligence reports increasingly purposeful behavior." % [tier, display_name.to_upper()])
    if release_audio != null and tier >= 3:
        release_audio.notify_danger()


func _on_tier_saturation_transferred(from_tier: int, to_tier: int, transferred_rate: float) -> void:
    hud.push_notification("ECOLOGICAL ESCALATION · TIER %d SATURATED\nFuture reproductive capacity is shifting toward Tier %d organisms." % [from_tier, to_tier])


func _on_tier_nest_cleared(nest_id: StringName, display_name: String) -> void:
    hud.push_notification("BROOD SITE CLEARED · %s\nLong-term replenishment has fallen." % display_name.to_upper())


func _spawn_enemy(position: Vector3, species: StringName) -> OrganicEnemy3D:
    var enemy := super._spawn_enemy(position, species)
    if not (enemy is OrganicEnemyTiered3D):
        return enemy
    var tiered := enemy as OrganicEnemyTiered3D
    var restored: Dictionary = {}
    if not _pending_restore_enemy_data.is_empty():
        restored = _pending_restore_enemy_data.pop_front()
    var tier := int(restored.get("enemy_tier", 0))
    if tier <= 0 and enemy_tier_director != null:
        tier = int(enemy_tier_director.species_to_tier.get(species, 1))
    tier = clampi(tier if tier > 0 else 1, 1, 5)
    var config := enemy_tier_director.tier_config(tier) if enemy_tier_director != null else {}
    tiered.configure_tier(tier, config)
    if not restored.is_empty():
        var territory := _array_to_vector(restored.get("territory_origin", _vector_to_array(position)))
        var radius := float(restored.get("territory_radius", tiered.territory_radius))
        var directive := StringName(str(restored.get("ecology_directive", String(tiered.ecology_directive))))
        tiered.configure_ecology(territory, radius, directive)
        tiered.last_known_prey_position = _array_to_vector(restored.get("last_known_prey_position", [0.0, 0.0, 0.0]))
        tiered.has_last_known_prey = bool(restored.get("has_last_known_prey", false))
    return tiered


func _spawn_capped_operation_threat(position: Vector3, species: StringName) -> Node:
    if enemy_tier_director == null:
        return _spawn_enemy(position, species)
    var tier := clampi(int(enemy_tier_director.species_to_tier.get(species, 1)), 1, 5)
    var state := enemy_tier_director.tier_state(tier)
    var living := _living_enemies_of_tier(tier)
    if living.size() >= int(state.get("cap", 1)):
        # An operation may redirect a real organism already in the world, but
        # it may never create an entity above the tier's population cap.
        if living.is_empty():
            return null
        var existing := _nearest_enemy_to_position(living, position)
        existing.hear_noise(position, 1000.0, 1.0, &"operation_disturbance")
        return existing
    return _spawn_enemy(position, species)


func _living_enemies_of_tier(tier: int) -> Array[OrganicEnemyTiered3D]:
    var result: Array[OrganicEnemyTiered3D] = []
    for node in get_tree().get_nodes_in_group(&"organic_enemies"):
        if node is OrganicEnemyTiered3D and is_instance_valid(node):
            var enemy := node as OrganicEnemyTiered3D
            if enemy.is_alive() and enemy.enemy_tier == tier:
                result.append(enemy)
    return result


func _nearest_enemy_to_position(candidates: Array[OrganicEnemyTiered3D], position: Vector3) -> OrganicEnemyTiered3D:
    var best := candidates[0]
    var best_distance := best.global_position.distance_to(position)
    for enemy in candidates:
        var distance := enemy.global_position.distance_to(position)
        if distance < best_distance:
            best = enemy
            best_distance = distance
    return best


func _apply_balance_to_existing_world() -> void:
    super._apply_balance_to_existing_world()
    if enemy_tier_director == null:
        return
    for node in get_tree().get_nodes_in_group(&"organic_enemies"):
        if node is OrganicEnemyTiered3D and is_instance_valid(node):
            var enemy := node as OrganicEnemyTiered3D
            enemy.configure_tier(enemy.enemy_tier, enemy_tier_director.tier_config(enemy.enemy_tier), true)


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
        var tier := enemy_tier_director.enemy_tier_for(enemy) if enemy_tier_director != null else 1
        enemies.append({
            "species": String(enemy.species),
            "enemy_tier": tier,
            "position": _vector_to_array(enemy.global_position),
            "health": enemy.current_health,
            "aggression": enemy.aggression,
            "territory_origin": _vector_to_array(enemy.territory_origin),
            "territory_radius": enemy.territory_radius,
            "ecology_directive": String(enemy.ecology_directive),
            "last_known_prey_position": _vector_to_array(enemy.last_known_prey_position),
            "has_last_known_prey": enemy.has_last_known_prey,
        })
    base["enemies"] = enemies
    snapshot["base"] = base

    var release: Dictionary = snapshot.get("release", {})
    release["enemy_tiers"] = enemy_tier_director.to_dictionary() if enemy_tier_director != null else {}
    release["enemy_tier_events"] = enemy_tier_event_bridge.to_dictionary() if enemy_tier_event_bridge != null else {}
    snapshot["release"] = release
    return snapshot


func _restore_release_snapshot(snapshot: Dictionary) -> void:
    _pending_restore_enemy_data.clear()
    var base: Dictionary = snapshot.get("base", {})
    for raw_enemy in base.get("enemies", []):
        if raw_enemy is Dictionary:
            _pending_restore_enemy_data.append((raw_enemy as Dictionary).duplicate(true))
    if enemy_tier_director != null:
        enemy_tier_director.simulation_enabled = false
    super._restore_release_snapshot(snapshot)
    _pending_restore_enemy_data.clear()
    var release: Dictionary = snapshot.get("release", {})
    if enemy_tier_director != null:
        enemy_tier_director.restore_from_dictionary(release.get("enemy_tiers", {}))
        enemy_tier_director.simulation_enabled = true
    if enemy_tier_event_bridge != null:
        enemy_tier_event_bridge.restore_from_dictionary(release.get("enemy_tier_events", {}))
        enemy_tier_event_bridge.reconcile_existing_state()
    if enemy_tier_hud != null and enemy_tier_director != null:
        enemy_tier_hud.set_snapshot(enemy_tier_director.snapshot())


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
