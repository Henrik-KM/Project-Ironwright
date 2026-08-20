class_name EnemyTierDirector3D
extends Node

signal tier_population_changed(tier: int, population: int, cap: int)
signal replenishment_changed(tier: int, rate_per_minute: float, reason: String)
signal saturation_transferred(from_tier: int, to_tier: int, transferred_rate: float)
signal tier_first_observed(tier: int, display_name: String)
signal nest_registered(nest: OrganicNest3D)
signal nest_cleared(nest_id: StringName, display_name: String)
signal ecology_report(message: String)
signal snapshot_changed(snapshot: Dictionary)

const DATA_PATH := "res://data/enemy_tier_progression.json"

var run_state: RunState3D
var ecology_director: EcologyDirector3D
var strategic_ecology_director: StrategicEcologyDirector3D
var region_director: WorldRegionDirector3D
var long_operation_director: LongRangeOperationDirector3D
var progression_director: ProgressionDirector3D
var spawn_enemy_callback: Callable
var world_parent: Node3D

var tier_configs: Dictionary = {}
var tier_states: Dictionary = {}
var nest_profiles: Dictionary = {}
var density_labels: Array[Dictionary] = []
var nests: Array[OrganicNest3D] = []
var nests_by_id: Dictionary = {}
var species_to_tier: Dictionary = {}
var observed_tiers: Dictionary = {}
var population_override_for_test: Dictionary = {}

var tick_seconds: float = 1.0
var saturation_transfer_factor: float = 0.1
var tier_1_growth_per_minute_per_minute: float = 1.0
var tier_1_growth_floor: float = 0.15
var spawn_credit_cap: float = 3.0
var maximum_materializations_per_tick: int = 4
var nest_maturity_per_minute: float = 0.004
var nest_spawn_radius_min: float = 2.4
var nest_spawn_radius_max: float = 6.2
var top_tier_dormant_at_cap: bool = true
var simulation_clock: float = 0.0
var spawn_serial: int = 0
var simulation_enabled: bool = true
var materialization_enabled: bool = true
var legacy_runtime_disabled: bool = false
var load_errors: Array[String] = []
var last_snapshot: Dictionary = {}


func configure(
        next_run_state: RunState3D,
        next_ecology_director: EcologyDirector3D,
        next_strategic_ecology_director: StrategicEcologyDirector3D,
        next_region_director: WorldRegionDirector3D,
        next_long_operation_director: LongRangeOperationDirector3D,
        next_progression_director: ProgressionDirector3D,
        next_spawn_enemy_callback: Callable,
        next_world_parent: Node3D
    ) -> void:
    run_state = next_run_state
    ecology_director = next_ecology_director
    strategic_ecology_director = next_strategic_ecology_director
    region_director = next_region_director
    long_operation_director = next_long_operation_director
    progression_director = next_progression_director
    spawn_enemy_callback = next_spawn_enemy_callback
    world_parent = next_world_parent

    if ecology_director != null and ecology_director.has_method(&"set_external_population_control"):
        ecology_director.call(&"set_external_population_control", true)
    if strategic_ecology_director != null and strategic_ecology_director.has_method(&"set_external_population_control"):
        strategic_ecology_director.call(&"set_external_population_control", true)


func _ready() -> void:
    add_to_group(&"enemy_tier_director")
    _load_configuration()
    if legacy_runtime_disabled:
        simulation_enabled = false
        materialization_enabled = false
        return
    _initialize_tier_states()
    _create_physical_nest_network()
    _adopt_existing_enemies()
    _connect_world_events()
    _refresh_population_counts(true)
    _emit_snapshot()


func _process(delta: float) -> void:
    if not simulation_enabled or tier_states.is_empty() or nests.is_empty():
        return
    simulation_clock += delta
    while simulation_clock >= tick_seconds:
        simulation_clock -= tick_seconds
        _simulation_step(tick_seconds)


func _load_configuration() -> void:
    tier_configs.clear()
    nest_profiles.clear()
    density_labels.clear()
    species_to_tier.clear()
    load_errors.clear()

    var file := FileAccess.open(DATA_PATH, FileAccess.READ)
    if file == null:
        load_errors.append("Missing enemy tier progression data")
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        load_errors.append("Enemy tier progression data is not a JSON object")
        return
    var data := parsed as Dictionary
    if data.get("tiers", null) is Array:
        # The canonical population-driven director owns the array-shaped
        # contract. Keep this legacy node as a compatibility surface without
        # parsing or simulating the newer runtime state in parallel.
        legacy_runtime_disabled = true
        return
    var simulation: Dictionary = data.get("simulation", {})
    tick_seconds = maxf(0.1, float(simulation.get("tick_seconds", 1.0)))
    saturation_transfer_factor = clampf(float(simulation.get("saturation_transfer_factor", 0.1)), 0.001, 1.0)
    tier_1_growth_per_minute_per_minute = maxf(0.0, float(simulation.get("tier_1_rate_growth_per_minute_per_minute", 1.0)))
    tier_1_growth_floor = maxf(0.0, float(simulation.get("tier_1_rate_growth_floor", 0.15)))
    spawn_credit_cap = maxf(1.0, float(simulation.get("spawn_credit_cap", 3.0)))
    maximum_materializations_per_tick = clampi(int(simulation.get("maximum_materializations_per_tick", 4)), 1, 32)
    nest_maturity_per_minute = maxf(0.0, float(simulation.get("nest_maturity_per_minute", 0.004)))
    nest_spawn_radius_min = maxf(0.5, float(simulation.get("nest_spawn_radius_min", 2.4)))
    nest_spawn_radius_max = maxf(nest_spawn_radius_min, float(simulation.get("nest_spawn_radius_max", 6.2)))
    top_tier_dormant_at_cap = bool(simulation.get("top_tier_dormant_at_cap", true))

    var raw_tiers: Dictionary = data.get("tiers", {})
    for raw_key in raw_tiers:
        var tier := clampi(int(str(raw_key)), 1, 5)
        var raw_config: Variant = raw_tiers[raw_key]
        if not (raw_config is Dictionary):
            continue
        var config := (raw_config as Dictionary).duplicate(true)
        config["tier"] = tier
        tier_configs[tier] = config
        var weights: Dictionary = config.get("species_weights", {})
        for raw_species in weights:
            species_to_tier[StringName(str(raw_species))] = tier

    var raw_profiles: Dictionary = data.get("nest_profiles", {})
    for raw_key in raw_profiles:
        if raw_profiles[raw_key] is Dictionary:
            nest_profiles[StringName(str(raw_key))] = (raw_profiles[raw_key] as Dictionary).duplicate(true)

    for raw_label in data.get("density_labels", []):
        if raw_label is Dictionary:
            density_labels.append((raw_label as Dictionary).duplicate(true))


func _initialize_tier_states() -> void:
    tier_states.clear()
    for tier in sorted_tiers():
        var config := tier_config(tier)
        tier_states[tier] = {
            "tier": tier,
            "population": 0,
            "cap": maxi(1, int(config.get("unit_cap", 1))),
            "replenishment_per_minute": maxf(0.0, float(config.get("initial_replenishment_per_minute", 0.0))),
            "spawn_credit": clampf(float(config.get("initial_spawn_credit", 0.0)), 0.0, spawn_credit_cap),
            "saturated": false,
            "transferred_total": 0.0,
            "spawned_total": 0,
        }


func _connect_world_events() -> void:
    if long_operation_director != null:
        var callback := Callable(self, "_on_operation_returned")
        if not long_operation_director.operation_returned.is_connected(callback):
            long_operation_director.operation_returned.connect(callback)
    if progression_director != null:
        var callback := Callable(self, "_on_technology_unlocked")
        if not progression_director.technology_unlocked.is_connected(callback):
            progression_director.technology_unlocked.connect(callback)
    if strategic_ecology_director != null and strategic_ecology_director.has_signal(&"migration_requested"):
        var callback := Callable(self, "_on_migration_requested")
        if not strategic_ecology_director.is_connected(&"migration_requested", callback):
            strategic_ecology_director.connect(&"migration_requested", callback)


func _simulation_step(delta: float) -> void:
    _refresh_population_counts(false)
    _grow_tier_one_rate(delta)
    _advance_nest_maturity(delta)
    _process_saturation_transfers()
    _accrue_spawn_credit(delta)
    if materialization_enabled:
        _materialize_available_credit()
    _refresh_population_counts(false)
    _emit_snapshot()


func _grow_tier_one_rate(delta: float) -> void:
    if not tier_states.has(1):
        return
    var state: Dictionary = tier_states[1]
    var before := float(state.get("replenishment_per_minute", 0.0))
    var growth := maxf(tier_1_growth_floor, tier_1_growth_per_minute_per_minute)
    state["replenishment_per_minute"] = before + growth * delta / 60.0


func _advance_nest_maturity(delta: float) -> void:
    var amount := nest_maturity_per_minute * delta / 60.0
    if amount <= 0.0:
        return
    for nest in nests:
        if is_instance_valid(nest) and nest.is_alive():
            nest.advance_maturity(amount)


func _process_saturation_transfers() -> void:
    var tiers := sorted_tiers()
    for index in range(tiers.size() - 2, -1, -1):
        var tier := tiers[index]
        var state: Dictionary = tier_states[tier]
        var population := int(state.get("population", 0))
        var cap := int(state.get("cap", 1))
        var rate := float(state.get("replenishment_per_minute", 0.0))
        state["saturated"] = population >= cap
        if population < cap or rate <= 0.000001:
            continue
        var next_tier := tiers[index + 1]
        var transferred := rate * saturation_transfer_factor
        var next_state: Dictionary = tier_states[next_tier]
        next_state["replenishment_per_minute"] = float(next_state.get("replenishment_per_minute", 0.0)) + transferred
        state["replenishment_per_minute"] = 0.0
        state["spawn_credit"] = 0.0
        state["transferred_total"] = float(state.get("transferred_total", 0.0)) + transferred
        saturation_transferred.emit(tier, next_tier, transferred)
        replenishment_changed.emit(tier, 0.0, "Population saturation transferred the tier's reproductive throughput upward.")
        replenishment_changed.emit(next_tier, float(next_state["replenishment_per_minute"]), "Lower-tier saturation created more advanced organisms.")
        ecology_report.emit("Tier %d is saturated. %.2f units/min of its reproductive capacity shifted to Tier %d." % [tier, transferred, next_tier])

    var top_tier := tiers[tiers.size() - 1]
    var top_state: Dictionary = tier_states[top_tier]
    top_state["saturated"] = int(top_state.get("population", 0)) >= int(top_state.get("cap", 1))


func _accrue_spawn_credit(delta: float) -> void:
    var top_tier := highest_tier()
    for tier in sorted_tiers():
        var state: Dictionary = tier_states[tier]
        var population := int(state.get("population", 0))
        var cap := int(state.get("cap", 1))
        if population >= cap:
            if tier == top_tier and top_tier_dormant_at_cap:
                state["spawn_credit"] = minf(float(state.get("spawn_credit", 0.0)), spawn_credit_cap)
            continue
        if _valid_nests_for_tier(tier).is_empty():
            state["spawn_credit"] = minf(float(state.get("spawn_credit", 0.0)), spawn_credit_cap)
            continue
        var rate := maxf(0.0, float(state.get("replenishment_per_minute", 0.0)))
        state["spawn_credit"] = minf(spawn_credit_cap, float(state.get("spawn_credit", 0.0)) + rate * delta / 60.0)


func _materialize_available_credit() -> void:
    var materialized := 0
    var tiers := sorted_tiers()
    tiers.reverse()
    for tier in tiers:
        var state: Dictionary = tier_states[tier]
        while (
            materialized < maximum_materializations_per_tick
            and float(state.get("spawn_credit", 0.0)) >= 1.0
            and int(state.get("population", 0)) < int(state.get("cap", 1))
        ):
            var nest := _choose_nest_for_tier(tier)
            if nest == null:
                state["spawn_credit"] = minf(float(state.get("spawn_credit", 0.0)), spawn_credit_cap)
                break
            if not _spawn_from_nest(tier, nest):
                break
            state["spawn_credit"] = maxf(0.0, float(state.get("spawn_credit", 0.0)) - 1.0)
            state["population"] = int(state.get("population", 0)) + 1
            state["spawned_total"] = int(state.get("spawned_total", 0)) + 1
            materialized += 1


func _spawn_from_nest(tier: int, nest: OrganicNest3D) -> bool:
    if not spawn_enemy_callback.is_valid() or nest == null or not nest.can_spawn_tier(tier):
        return false
    spawn_serial += 1
    var species := _choose_species_for_tier(tier, nest)
    if species == &"":
        return false
    var position := nest.spawn_position(nest_spawn_radius_min, nest_spawn_radius_max)
    var spawned: Variant = spawn_enemy_callback.call(position, species)
    if not (spawned is OrganicEnemy3D):
        return false
    var enemy := spawned as OrganicEnemy3D
    if enemy.has_method(&"configure_tier"):
        enemy.call(&"configure_tier", tier, tier_config(tier))
    else:
        enemy.set_meta(&"enemy_tier", tier)
    var directive := nest.intelligence_directive_for_tier(tier)
    enemy.configure_ecology(nest.global_position, nest.territory_radius, directive)
    enemy.set_meta(&"enemy_tier", tier)
    enemy.set_meta(&"home_nest_id", String(nest.nest_id))
    enemy.set_meta(&"ecology_region", String(nest.region_id))
    enemy.set_meta(&"ecology_origin", "tier_replenishment")
    var callback := Callable(self, "_on_enemy_killed")
    if not enemy.killed.is_connected(callback):
        enemy.killed.connect(callback)
    if not observed_tiers.has(tier):
        observed_tiers[tier] = true
        tier_first_observed.emit(tier, str(tier_config(tier).get("display_name", "Tier %d" % tier)))
        if tier > 1:
            ecology_report.emit("Machines have confirmed the first Tier %d organism: %s." % [tier, str(tier_config(tier).get("intelligence_label", "advanced behavior"))])
    return true


func _choose_species_for_tier(tier: int, nest: OrganicNest3D) -> StringName:
    var weights: Dictionary = tier_config(tier).get("species_weights", {})
    if weights.is_empty():
        return &"skitterling" if tier == 1 else &""
    var total := 0.0
    for value in weights.values():
        total += maxf(0.0, float(value))
    if total <= 0.0:
        return StringName(str(weights.keys()[0]))
    var selector := _deterministic_unit(spawn_serial, tier * 37 + int(nest.nest_id.hash() % 997)) * total
    var running := 0.0
    for raw_species in weights:
        running += maxf(0.0, float(weights[raw_species]))
        if selector <= running:
            return StringName(str(raw_species))
    return StringName(str(weights.keys()[weights.size() - 1]))


func _choose_nest_for_tier(tier: int) -> OrganicNest3D:
    var candidates := _valid_nests_for_tier(tier)
    var best: OrganicNest3D
    var best_score := INF
    for nest in candidates:
        var resident_count := _population_near_nest(nest, tier)
        var congestion := float(resident_count) / maxf(1.0, 5.0 + nest.maturity * 10.0)
        var deterministic_bias := _deterministic_unit(spawn_serial + resident_count, int(nest.nest_id.hash() % 4093)) * 0.18
        var score := congestion / maxf(0.05, nest.spawn_weight) + deterministic_bias - nest.maturity * 0.12
        if score < best_score:
            best = nest
            best_score = score
    return best


func _valid_nests_for_tier(tier: int) -> Array[OrganicNest3D]:
    var result: Array[OrganicNest3D] = []
    for nest in nests:
        if is_instance_valid(nest) and nest.can_spawn_tier(tier):
            result.append(nest)
    return result


func _population_near_nest(nest: OrganicNest3D, tier: int) -> int:
    var count := 0
    for node in get_tree().get_nodes_in_group(&"organic_enemies"):
        if not (node is OrganicEnemy3D) or not is_instance_valid(node):
            continue
        var enemy := node as OrganicEnemy3D
        if not enemy.is_alive() or enemy_tier_for(enemy) != tier:
            continue
        if enemy.global_position.distance_to(nest.global_position) <= nest.territory_radius:
            count += 1
    return count


func _refresh_population_counts(force_emit: bool) -> void:
    var counts: Dictionary = {}
    for tier in sorted_tiers():
        counts[tier] = 0
    for node in get_tree().get_nodes_in_group(&"organic_enemies"):
        if not (node is OrganicEnemy3D) or not is_instance_valid(node):
            continue
        var enemy := node as OrganicEnemy3D
        if not enemy.is_alive():
            continue
        var tier := enemy_tier_for(enemy)
        if counts.has(tier):
            counts[tier] = int(counts[tier]) + 1
    for tier in population_override_for_test:
        counts[int(tier)] = maxi(0, int(population_override_for_test[tier]))
    for tier in sorted_tiers():
        var state: Dictionary = tier_states[tier]
        var before := int(state.get("population", 0))
        var after := int(counts.get(tier, 0))
        state["population"] = after
        if force_emit or before != after:
            tier_population_changed.emit(tier, after, int(state.get("cap", 1)))


func enemy_tier_for(enemy: OrganicEnemy3D) -> int:
    if enemy == null:
        return 1
    if "enemy_tier" in enemy:
        return clampi(int(enemy.enemy_tier), 1, highest_tier())
    if enemy.has_meta(&"enemy_tier"):
        return clampi(int(enemy.get_meta(&"enemy_tier")), 1, highest_tier())
    return clampi(int(species_to_tier.get(enemy.species, 1)), 1, highest_tier())


func _adopt_existing_enemies() -> void:
    for node in get_tree().get_nodes_in_group(&"organic_enemies"):
        if not (node is OrganicEnemy3D) or not is_instance_valid(node):
            continue
        var enemy := node as OrganicEnemy3D
        var tier := clampi(int(species_to_tier.get(enemy.species, 1)), 1, highest_tier())
        if enemy.has_method(&"configure_tier"):
            enemy.call(&"configure_tier", tier, tier_config(tier))
        enemy.set_meta(&"enemy_tier", tier)
        var callback := Callable(self, "_on_enemy_killed")
        if not enemy.killed.is_connected(callback):
            enemy.killed.connect(callback)
        observed_tiers[tier] = true


func _create_physical_nest_network() -> void:
    if world_parent == null:
        return
    for existing in get_tree().get_nodes_in_group(&"organic_nests"):
        if existing is OrganicNest3D:
            register_nest(existing as OrganicNest3D)

    if ecology_director != null:
        for index in range(ecology_director.nest_positions.size()):
            var data := _nest_data_from_profile(&"local_minor")
            data["nest_id"] = "nest.local.%d" % index
            data["display_name"] = "Heartforge Feral Nest %d" % (index + 1)
            data["region_id"] = "region.heartforge_district"
            data["local_nest_index"] = index
            _spawn_nest(ecology_director.nest_positions[index], data)

    if region_director != null:
        for raw_region_id in region_director.region_data:
            var region_id := raw_region_id as StringName
            if region_id == &"region.heartforge_district":
                continue
            var region_data := region_director.get_region_data(region_id)
            var profile_id := _nest_profile_for_region(StringName(str(region_data.get("kind", "urban"))))
            var data := _nest_data_from_profile(profile_id)
            data["nest_id"] = "nest.%s" % String(region_id).replace("region.", "")
            data["display_name"] = "%s brood site" % str(region_data.get("display_name", "Regional"))
            data["region_id"] = String(region_id)
            var center := region_director.center(region_id)
            var radius := region_director.radius(region_id)
            var angle := _deterministic_unit(int(region_id.hash() % 8191), 71) * TAU
            var position := center + Vector3(cos(angle) * radius * 0.28, 0.0, sin(angle) * radius * 0.28)
            _spawn_nest(position, data)


func _spawn_nest(position: Vector3, data: Dictionary) -> OrganicNest3D:
    var nest := OrganicNest3D.new()
    nest.configure(data)
    nest.position = position
    world_parent.add_child(nest)
    register_nest(nest)
    return nest


func register_nest(nest: OrganicNest3D) -> void:
    if nest == null or nests_by_id.has(nest.nest_id):
        return
    nests.append(nest)
    nests_by_id[nest.nest_id] = nest
    var callback := Callable(self, "_on_nest_destroyed")
    if not nest.nest_destroyed.is_connected(callback):
        nest.nest_destroyed.connect(callback)
    nest_registered.emit(nest)


func _nest_data_from_profile(profile_id: StringName) -> Dictionary:
    var raw: Variant = nest_profiles.get(profile_id, {})
    var data := (raw as Dictionary).duplicate(true) if raw is Dictionary else {}
    data["profile_id"] = String(profile_id)
    return data


func _nest_profile_for_region(kind: StringName) -> StringName:
    if kind == &"endgame":
        return &"endgame_root"
    if kind in [&"nest", &"research", &"waterfront", &"rail"]:
        return &"regional_advanced"
    return &"regional_standard"


func _on_nest_destroyed(nest: OrganicNest3D, source: Node) -> void:
    for raw_tier in nest.destroy_replenishment_delta_per_minute:
        apply_replenishment_delta(int(str(raw_tier)), float(nest.destroy_replenishment_delta_per_minute[raw_tier]), "Destroyed %s." % nest.display_name)
    apply_tier_one_growth_delta(nest.destroy_tier_1_growth_delta, "Destroyed %s." % nest.display_name)
    if ecology_director != null and nest.local_nest_index >= 0 and ecology_director.has_method(&"mark_nest_destroyed"):
        ecology_director.call(&"mark_nest_destroyed", nest.local_nest_index)
    if region_director != null and nest.region_id != &"":
        region_director.add_pressure(nest.region_id, -0.16 - nest.maturity * 0.12)
    nest_cleared.emit(nest.nest_id, nest.display_name)
    ecology_report.emit("%s was cleared. Long-term enemy replenishment has fallen." % nest.display_name)


func _on_enemy_killed(enemy: OrganicEnemy3D, killer: Node) -> void:
    _refresh_population_counts(false)


func _on_operation_returned(operation_id: StringName, display_name: String, rewards: Dictionary) -> void:
    if long_operation_director == null:
        return
    var operation := long_operation_director.operation(operation_id)
    var effects: Variant = operation.get("ecology_effects", {})
    if effects is Dictionary and not (effects as Dictionary).is_empty():
        apply_ecology_effect(effects as Dictionary, "Completed %s." % display_name)


func _on_technology_unlocked(technology_id: StringName, display_name: String, effects: Array) -> void:
    if progression_director == null:
        return
    var technology := progression_director.technology(technology_id)
    var ecology_effects: Variant = technology.get("ecology_effects", {})
    if ecology_effects is Dictionary and not (ecology_effects as Dictionary).is_empty():
        apply_ecology_effect(ecology_effects as Dictionary, "Unlocked %s." % display_name)


func _on_migration_requested(region_id: StringName, pressure: float) -> void:
    var candidates: Array[OrganicEnemy3D] = []
    for node in get_tree().get_nodes_in_group(&"organic_enemies"):
        if not (node is OrganicEnemy3D) or not is_instance_valid(node):
            continue
        var enemy := node as OrganicEnemy3D
        if not enemy.is_alive() or StringName(str(enemy.get_meta(&"ecology_region", ""))) != region_id:
            continue
        if enemy_tier_for(enemy) < 2:
            continue
        candidates.append(enemy)
    candidates.sort_custom(func(a: OrganicEnemy3D, b: OrganicEnemy3D) -> bool:
        return enemy_tier_for(a) > enemy_tier_for(b)
    )
    var count := mini(candidates.size(), clampi(1 + int(floor(pressure)), 1, 4))
    for index in range(count):
        candidates[index].configure_ecology(candidates[index].territory_origin, candidates[index].territory_radius * 1.2, &"hunt")


func apply_ecology_effect(effects: Dictionary, reason: String) -> void:
    var deltas: Dictionary = effects.get("replenishment_delta_per_minute", {})
    for raw_tier in deltas:
        apply_replenishment_delta(int(str(raw_tier)), float(deltas[raw_tier]), reason)
    if effects.has("tier_1_growth_delta"):
        apply_tier_one_growth_delta(float(effects.get("tier_1_growth_delta", 0.0)), reason)
    if effects.has("spawn_credit_delta"):
        var credits: Dictionary = effects.get("spawn_credit_delta", {})
        for raw_tier in credits:
            var tier := int(str(raw_tier))
            if tier_states.has(tier):
                var state: Dictionary = tier_states[tier]
                state["spawn_credit"] = clampf(float(state.get("spawn_credit", 0.0)) + float(credits[raw_tier]), 0.0, spawn_credit_cap)


func apply_replenishment_delta(tier: int, delta: float, reason: String) -> void:
    tier = clampi(tier, 1, highest_tier())
    if not tier_states.has(tier) or is_zero_approx(delta):
        return
    var state: Dictionary = tier_states[tier]
    state["replenishment_per_minute"] = maxf(0.0, float(state.get("replenishment_per_minute", 0.0)) + delta)
    replenishment_changed.emit(tier, float(state["replenishment_per_minute"]), reason)
    ecology_report.emit("%s Tier %d replenishment changed by %+.2f units/min." % [reason, tier, delta])


func apply_tier_one_growth_delta(delta: float, reason: String) -> void:
    if is_zero_approx(delta):
        return
    tier_1_growth_per_minute_per_minute = maxf(tier_1_growth_floor, tier_1_growth_per_minute_per_minute + delta)
    ecology_report.emit("%s Tier 1 replenishment growth changed by %+.2f per minute." % [reason, delta])


func tier_config(tier: int) -> Dictionary:
    var raw: Variant = tier_configs.get(tier, {})
    return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func tier_state(tier: int) -> Dictionary:
    var raw: Variant = tier_states.get(tier, {})
    return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func sorted_tiers() -> Array[int]:
    var result: Array[int] = []
    for raw_tier in tier_configs:
        result.append(int(raw_tier))
    result.sort()
    return result


func highest_tier() -> int:
    var tiers := sorted_tiers()
    return tiers[tiers.size() - 1] if not tiers.is_empty() else 1


func highest_observed_tier() -> int:
    var result := 1
    for raw_tier in observed_tiers:
        if bool(observed_tiers[raw_tier]):
            result = maxi(result, int(raw_tier))
    return result


func active_nest_count() -> int:
    var count := 0
    for nest in nests:
        if is_instance_valid(nest) and nest.is_alive():
            count += 1
    return count


func density_label(tier: int) -> String:
    var state := tier_state(tier)
    var cap := maxf(1.0, float(state.get("cap", 1)))
    var fraction := float(state.get("population", 0)) / cap
    for entry in density_labels:
        if fraction <= float(entry.get("maximum_fraction", 1.0)):
            return str(entry.get("label", "unknown"))
    return "saturated"


func trend_label() -> String:
    var tier_one := tier_state(1)
    var rate := float(tier_one.get("replenishment_per_minute", 0.0))
    var saturated_count := 0
    for tier in sorted_tiers():
        if bool(tier_state(tier).get("saturated", false)):
            saturated_count += 1
    if saturated_count >= 2:
        return "critical escalation"
    if saturated_count == 1:
        return "escalating"
    if rate >= 8.0:
        return "worsening quickly"
    if rate >= 3.0:
        return "worsening"
    return "contained for now"


func snapshot() -> Dictionary:
    var tiers: Array[Dictionary] = []
    for tier in sorted_tiers():
        var state := tier_state(tier)
        var config := tier_config(tier)
        tiers.append({
            "tier": tier,
            "display_name": str(config.get("display_name", "Tier %d" % tier)),
            "intelligence_label": str(config.get("intelligence_label", "unknown")),
            "population": int(state.get("population", 0)),
            "cap": int(state.get("cap", 1)),
            "density": density_label(tier),
            "replenishment_per_minute": float(state.get("replenishment_per_minute", 0.0)),
            "spawn_credit": float(state.get("spawn_credit", 0.0)),
            "saturated": bool(state.get("saturated", false)),
        })
    return {
        "tiers": tiers,
        "highest_observed_tier": highest_observed_tier(),
        "active_nests": active_nest_count(),
        "total_nests": nests.size(),
        "tier_1_growth_per_minute_per_minute": tier_1_growth_per_minute_per_minute,
        "trend": trend_label(),
    }


func _emit_snapshot() -> void:
    var next_snapshot := snapshot()
    if JSON.stringify(next_snapshot) == JSON.stringify(last_snapshot):
        return
    last_snapshot = next_snapshot.duplicate(true)
    snapshot_changed.emit(next_snapshot)


func to_dictionary() -> Dictionary:
    var serialized_states: Dictionary = {}
    for tier in sorted_tiers():
        serialized_states[str(tier)] = tier_state(tier)
    var serialized_nests: Array[Dictionary] = []
    for nest in nests:
        if is_instance_valid(nest):
            serialized_nests.append(nest.to_dictionary())
    var serialized_observed: Array[int] = []
    for tier in observed_tiers:
        if bool(observed_tiers[tier]):
            serialized_observed.append(int(tier))
    serialized_observed.sort()
    return {
        "schema_version": 1,
        "tier_states": serialized_states,
        "tier_1_growth_per_minute_per_minute": tier_1_growth_per_minute_per_minute,
        "spawn_serial": spawn_serial,
        "observed_tiers": serialized_observed,
        "nests": serialized_nests,
    }


func restore_from_dictionary(data: Dictionary) -> void:
    var saved_states: Dictionary = data.get("tier_states", {})
    for raw_tier in saved_states:
        var tier := int(str(raw_tier))
        if not tier_states.has(tier) or not (saved_states[raw_tier] is Dictionary):
            continue
        var state: Dictionary = tier_states[tier]
        var saved := saved_states[raw_tier] as Dictionary
        state["replenishment_per_minute"] = maxf(0.0, float(saved.get("replenishment_per_minute", state.get("replenishment_per_minute", 0.0))))
        state["spawn_credit"] = clampf(float(saved.get("spawn_credit", 0.0)), 0.0, spawn_credit_cap)
        state["transferred_total"] = maxf(0.0, float(saved.get("transferred_total", 0.0)))
        state["spawned_total"] = maxi(0, int(saved.get("spawned_total", 0)))
    tier_1_growth_per_minute_per_minute = maxf(tier_1_growth_floor, float(data.get("tier_1_growth_per_minute_per_minute", tier_1_growth_per_minute_per_minute)))
    spawn_serial = maxi(0, int(data.get("spawn_serial", spawn_serial)))
    observed_tiers.clear()
    for raw_tier in data.get("observed_tiers", [1]):
        observed_tiers[clampi(int(raw_tier), 1, highest_tier())] = true
    var saved_nests: Array = data.get("nests", [])
    for raw_nest in saved_nests:
        if not (raw_nest is Dictionary):
            continue
        var nest_data := raw_nest as Dictionary
        var nest_id := StringName(str(nest_data.get("nest_id", "")))
        var nest := nests_by_id.get(nest_id) as OrganicNest3D
        if nest != null:
            nest.restore_after_load(nest_data)
    _refresh_population_counts(true)
    _emit_snapshot()


func set_population_override_for_test(tier: int, population: int) -> void:
    population_override_for_test[clampi(tier, 1, highest_tier())] = maxi(0, population)
    _refresh_population_counts(true)


func clear_population_overrides_for_test() -> void:
    population_override_for_test.clear()
    _refresh_population_counts(true)


func set_tier_rate_for_test(tier: int, rate: float) -> void:
    if tier_states.has(tier):
        var state: Dictionary = tier_states[tier]
        state["replenishment_per_minute"] = maxf(0.0, rate)


func force_simulation_step_for_test(delta: float = 1.0) -> void:
    _simulation_step(maxf(0.0, delta))


func _deterministic_unit(serial: int, salt: int) -> float:
    var value := sin(float(serial) * 12.9898 + float(salt) * 78.233) * 43758.5453
    return value - floor(value)
