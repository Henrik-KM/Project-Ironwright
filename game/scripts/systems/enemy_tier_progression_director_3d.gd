class_name EnemyTierProgressionDirector3D
extends Node

signal tier_population_changed(tier: int, population: int, cap: int)
signal tier_replenishment_changed(tier: int, rate_per_minute: float)
signal tier_saturated(tier: int, transferred_rate: float, next_tier: int)
signal enemy_tier_spawned(enemy: Node3D, tier: int, nest_id: StringName)
signal nest_cleared(nest_id: StringName, removed_rates: Dictionary)
signal ecology_intel_changed(summary: Dictionary)
signal escalation_event_applied(event_id: StringName, deltas: Dictionary)

const CONFIG_PATH := "res://data/enemy_tier_progression.json"
const ENEMY_BRAIN_SCRIPT := preload("res://scripts/enemies/enemy_tier_brain_3d.gd")
const NEST_SCRIPT := preload("res://scripts/world/enemy_tier_nest_3d.gd")

var world: Node
var config: Dictionary = {}
var tiers: Dictionary = {}
var tier_order: Array[int] = []
var population: Dictionary = {}
var anonymous_rates: Dictionary = {}
var spawn_credit: Dictionary = {}
var saturated: Dictionary = {}
var rate_sources: Dictionary = {}
var nests: Dictionary = {}
var applied_events: Dictionary = {}
var connected_enemies: Dictionary = {}
var spawn_serial: int = 0
var simulation_clock: float = 0.0
var reconcile_clock: float = 0.0
var intel_clock: float = 0.0
var elapsed_seconds: float = 0.0
var transfer_factor: float = 0.1
var spawn_credit_cap: float = 3.0
var simulation_tick_seconds: float = 1.0
var population_reconcile_seconds: float = 2.0
var tier_1_growth_per_second: float = 1.0 / 60.0
var maximum_tier: int = 5
var progression_node: Node
var operation_node: Node
var region_node: Node
var last_heartforge_tier: int = 1
var last_intel_signature: String = ""
var enabled: bool = true
var load_errors: Array[String] = []


func configure(next_world: Node) -> void:
    world = next_world


func _ready() -> void:
    add_to_group(&"enemy_tier_progression")
    process_mode = Node.PROCESS_MODE_PAUSABLE
    _load_config()
    _initialize_state()
    call_deferred("_bind_world")


func _process(delta: float) -> void:
    if not enabled or config.is_empty():
        return
    elapsed_seconds += delta
    simulation_clock += delta
    reconcile_clock += delta
    intel_clock += delta
    _poll_world_progression()
    if reconcile_clock >= population_reconcile_seconds:
        reconcile_clock = 0.0
        _reconcile_population()
        _refresh_nest_sources()
    if simulation_clock >= simulation_tick_seconds:
        var step := simulation_clock
        simulation_clock = 0.0
        _simulation_tick(step)
    if intel_clock >= 2.0:
        intel_clock = 0.0
        _emit_intel_if_changed()


func _load_config() -> void:
    load_errors.clear()
    var file := FileAccess.open(CONFIG_PATH, FileAccess.READ)
    if file == null:
        load_errors.append("Missing enemy tier progression configuration")
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        load_errors.append("Enemy tier progression configuration is invalid")
        return
    config = (parsed as Dictionary).duplicate(true)
    transfer_factor = clampf(float(config.get("transfer_factor", 0.1)), 0.001, 1.0)
    spawn_credit_cap = maxf(1.0, float(config.get("spawn_credit_cap", 3.0)))
    simulation_tick_seconds = maxf(0.1, float(config.get("simulation_tick_seconds", 1.0)))
    population_reconcile_seconds = maxf(0.25, float(config.get("population_reconcile_seconds", 2.0)))
    tier_1_growth_per_second = maxf(0.0, float(config.get("tier_1_rate_growth_per_minute_per_minute", 1.0)) / 60.0)


func _initialize_state() -> void:
    tiers.clear()
    tier_order.clear()
    population.clear()
    anonymous_rates.clear()
    spawn_credit.clear()
    saturated.clear()
    rate_sources.clear()
    var raw_tiers: Array = config.get("tiers", [])
    for raw_entry in raw_tiers:
        if not (raw_entry is Dictionary):
            continue
        var entry := (raw_entry as Dictionary).duplicate(true)
        var tier := int(entry.get("tier", 0))
        if tier <= 0:
            continue
        tiers[tier] = entry
        tier_order.append(tier)
        population[tier] = 0
        anonymous_rates[tier] = 0.0
        spawn_credit[tier] = 0.0
        saturated[tier] = false
    tier_order.sort()
    maximum_tier = tier_order[-1] if not tier_order.is_empty() else 5
    if tiers.has(1):
        anonymous_rates[1] = maxf(0.0, float(config.get("tier_1_initial_replenishment_per_minute", 1.0)))


func _bind_world() -> void:
    if world == null:
        world = get_tree().current_scene
    if world == null:
        return
    progression_node = _find_node_with_method(world, &"current_phase_data")
    operation_node = _find_node_with_method(world, &"available_operations")
    region_node = _find_node_with_method(world, &"region_for_position")
    _spawn_configured_nests()
    for enemy in get_tree().get_nodes_in_group(&"organic_enemies"):
        _register_enemy(enemy)
    get_tree().node_added.connect(_on_tree_node_added)
    _reconcile_population()
    _refresh_nest_sources()
    _emit_all_rates()


func _find_node_with_method(root: Node, method_name: StringName) -> Node:
    if root.has_method(method_name):
        return root
    for child in root.get_children():
        var found := _find_node_with_method(child, method_name)
        if found != null:
            return found
    return null


func _on_tree_node_added(node: Node) -> void:
    if node == null:
        return
    call_deferred("_consider_new_node", node)


func _consider_new_node(node: Node) -> void:
    if not is_instance_valid(node):
        return
    if node.is_in_group(&"organic_enemies") and not node.is_in_group(&"enemy_tier_nests"):
        _register_enemy(node)
    elif node.is_in_group(&"enemy_tier_nests"):
        register_nest(node)


func _spawn_configured_nests() -> void:
    var existing: Dictionary = {}
    for raw_nest in get_tree().get_nodes_in_group(&"enemy_tier_nests"):
        if is_instance_valid(raw_nest):
            var identifier := StringName(str(raw_nest.get("nest_id")))
            existing[identifier] = raw_nest
            register_nest(raw_nest)
    for raw_entry in config.get("nest_archetypes", []):
        if not (raw_entry is Dictionary):
            continue
        var entry := raw_entry as Dictionary
        var nest_id := StringName(str(entry.get("id", "")))
        if nest_id == &"" or existing.has(nest_id):
            continue
        var nest := NEST_SCRIPT.new()
        nest.configure(entry)
        world.add_child(nest)
        register_nest(nest)


func register_nest(nest: Node) -> void:
    if nest == null or not is_instance_valid(nest):
        return
    var nest_id := StringName(str(nest.get("nest_id")))
    if nest_id == &"":
        return
    nests[nest_id] = nest
    if nest.has_signal(&"destroyed"):
        var callback := Callable(self, "_on_nest_destroyed")
        if not nest.is_connected(&"destroyed", callback):
            nest.connect(&"destroyed", callback)
    if nest.has_signal(&"restored"):
        var restored_callback := Callable(self, "_on_nest_restored")
        if not nest.is_connected(&"restored", restored_callback):
            nest.connect(&"restored", restored_callback)
    _sync_nest_sources(nest)


func _refresh_nest_sources() -> void:
    for raw_nest_id in nests.keys():
        var nest_id := raw_nest_id as StringName
        var nest: Node = nests.get(nest_id, null)
        if nest == null or not is_instance_valid(nest):
            _remove_sources_for_owner(nest_id)
            nests.erase(nest_id)
            continue
        _sync_nest_sources(nest)


func _sync_nest_sources(nest: Node) -> void:
    var nest_id := StringName(str(nest.get("nest_id")))
    var alive := true
    if nest.has_method(&"is_alive"):
        alive = bool(nest.call(&"is_alive"))
    var raw_rates: Variant = nest.call(&"effective_replenishment") if nest.has_method(&"effective_replenishment") else {}
    var rates: Dictionary = raw_rates as Dictionary if raw_rates is Dictionary else {}
    for tier in tier_order:
        var source_id := StringName("%s.tier_%d" % [String(nest_id), tier])
        var desired := maxf(0.0, float(rates.get(str(tier), rates.get(tier, 0.0)))) if alive else 0.0
        _set_named_source(source_id, nest_id, &"nest", tier, desired)


func _set_named_source(
        source_id: StringName,
        owner_id: StringName,
        kind: StringName,
        base_tier: int,
        desired_base_rate: float
    ) -> void:
    if desired_base_rate <= 0.000001:
        _remove_source(source_id)
        return
    var existing: Dictionary = rate_sources.get(source_id, {})
    if existing.is_empty():
        var destination := _route_new_rate_tier(base_tier)
        var conversion_steps := maxi(0, destination - base_tier)
        var converted_rate := desired_base_rate * pow(transfer_factor, conversion_steps)
        rate_sources[source_id] = {
            "source_id": String(source_id),
            "owner_id": String(owner_id),
            "kind": String(kind),
            "base_tier": base_tier,
            "base_rate": desired_base_rate,
            "current_tier": destination,
            "current_rate": converted_rate,
        }
        tier_replenishment_changed.emit(destination, replenishment_rate(destination))
        return
    var current_tier := int(existing.get("current_tier", base_tier))
    var conversion_steps := maxi(0, current_tier - base_tier)
    existing["base_rate"] = desired_base_rate
    existing["current_rate"] = desired_base_rate * pow(transfer_factor, conversion_steps)
    rate_sources[source_id] = existing
    tier_replenishment_changed.emit(current_tier, replenishment_rate(current_tier))


func _remove_source(source_id: StringName) -> void:
    var existing: Dictionary = rate_sources.get(source_id, {})
    if existing.is_empty():
        return
    var tier := int(existing.get("current_tier", 1))
    rate_sources.erase(source_id)
    tier_replenishment_changed.emit(tier, replenishment_rate(tier))


func _remove_sources_for_owner(owner_id: StringName) -> Dictionary:
    var removed: Dictionary = {}
    var source_ids: Array = rate_sources.keys()
    for raw_source_id in source_ids:
        var source_id := raw_source_id as StringName
        var source: Dictionary = rate_sources.get(source_id, {})
        if StringName(str(source.get("owner_id", ""))) != owner_id:
            continue
        var tier := int(source.get("current_tier", 1))
        removed[tier] = float(removed.get(tier, 0.0)) + float(source.get("current_rate", 0.0))
        rate_sources.erase(source_id)
        tier_replenishment_changed.emit(tier, replenishment_rate(tier))
    return removed


func _on_nest_destroyed(nest: Node, source: Node = null) -> void:
    var nest_id := StringName(str(nest.get("nest_id")))
    var removed := _remove_sources_for_owner(nest_id)
    nest_cleared.emit(nest_id, removed)
    _emit_intel_if_changed(true)


func _on_nest_restored(nest: Node) -> void:
    _sync_nest_sources(nest)
    _emit_intel_if_changed(true)


func _register_enemy(enemy: Node) -> void:
    if enemy == null or not is_instance_valid(enemy) or enemy.is_in_group(&"enemy_tier_nests"):
        return
    var instance_id := enemy.get_instance_id()
    if connected_enemies.has(instance_id):
        return
    var tier := int(enemy.get_meta(&"enemy_tier", 0))
    if tier <= 0:
        tier = infer_tier_for_species(StringName(str(enemy.get("species"))))
        assign_enemy_tier(enemy, tier, &"")
    connected_enemies[instance_id] = weakref(enemy)
    if enemy.has_signal(&"killed"):
        var callback := Callable(self, "_on_enemy_killed")
        if not enemy.is_connected(&"killed", callback):
            enemy.connect(&"killed", callback)
    if enemy.has_signal(&"tree_exited"):
        var exit_callback := Callable(self, "_on_enemy_tree_exited").bind(instance_id)
        if not enemy.is_connected(&"tree_exited", exit_callback):
            enemy.connect(&"tree_exited", exit_callback)


func assign_enemy_tier(enemy: Node, tier: int, home_nest_id: StringName) -> void:
    if enemy == null or not is_instance_valid(enemy):
        return
    tier = clampi(tier, 1, maximum_tier)
    enemy.set_meta(&"enemy_tier", tier)
    enemy.set_meta(&"home_nest_id", String(home_nest_id))
    var tier_data := get_tier_data(tier)
    if not enemy.has_meta(&"enemy_tier_base_stats"):
        enemy.set_meta(&"enemy_tier_base_stats", {
            "maximum_health": float(enemy.get("maximum_health")),
            "attack_damage": float(enemy.get("attack_damage")),
            "move_speed": float(enemy.get("move_speed")),
        })
    var base_stats: Dictionary = enemy.get_meta(&"enemy_tier_base_stats")
    var old_maximum := maxf(1.0, float(enemy.get("maximum_health")))
    var health_ratio := float(enemy.get("current_health")) / old_maximum
    var maximum_health := float(base_stats.get("maximum_health", old_maximum)) * float(tier_data.get("health_multiplier", 1.0))
    enemy.set("maximum_health", maximum_health)
    enemy.set("current_health", maxf(1.0, maximum_health * health_ratio))
    enemy.set("attack_damage", float(base_stats.get("attack_damage", enemy.get("attack_damage"))) * float(tier_data.get("damage_multiplier", 1.0)))
    enemy.set("move_speed", float(base_stats.get("move_speed", enemy.get("move_speed"))) * float(tier_data.get("speed_multiplier", 1.0)))
    var brain := enemy.get_node_or_null("EnemyTierBrain")
    if brain == null:
        brain = ENEMY_BRAIN_SCRIPT.new()
        brain.name = "EnemyTierBrain"
        enemy.add_child(brain)
    brain.configure(enemy, self, tier, home_nest_id)


func _on_enemy_killed(enemy: Node, killer: Node = null) -> void:
    if enemy == null:
        return
    var tier := int(enemy.get_meta(&"enemy_tier", 1))
    population[tier] = maxi(0, int(population.get(tier, 0)) - 1)
    saturated[tier] = int(population.get(tier, 0)) >= unit_cap(tier)
    tier_population_changed.emit(tier, int(population.get(tier, 0)), unit_cap(tier))
    _emit_intel_if_changed(true)


func _on_enemy_tree_exited(instance_id: int) -> void:
    connected_enemies.erase(instance_id)


func _reconcile_population() -> void:
    var counts: Dictionary = {}
    for tier in tier_order:
        counts[tier] = 0
    for enemy in get_tree().get_nodes_in_group(&"organic_enemies"):
        if not is_instance_valid(enemy) or enemy.is_in_group(&"enemy_tier_nests"):
            continue
        var alive := true
        if enemy.has_method(&"is_alive"):
            alive = bool(enemy.call(&"is_alive"))
        if not alive:
            continue
        _register_enemy(enemy)
        var tier := clampi(int(enemy.get_meta(&"enemy_tier", 1)), 1, maximum_tier)
        counts[tier] = int(counts.get(tier, 0)) + 1
    for tier in tier_order:
        var before := int(population.get(tier, 0))
        var after := int(counts.get(tier, 0))
        population[tier] = after
        if before != after:
            tier_population_changed.emit(tier, after, unit_cap(tier))
        saturated[tier] = after >= unit_cap(tier)


func _simulation_tick(delta: float) -> void:
    _add_anonymous_rate(1, tier_1_growth_per_second * delta)
    _process_saturation_high_to_low()
    for tier in tier_order:
        _accumulate_and_spawn(tier, delta)


func _process_saturation_high_to_low() -> void:
    var descending := tier_order.duplicate()
    descending.reverse()
    for tier in descending:
        if tier >= maximum_tier:
            saturated[tier] = int(population.get(tier, 0)) >= unit_cap(tier)
            continue
        var is_full := int(population.get(tier, 0)) >= unit_cap(tier)
        if not is_full:
            saturated[tier] = false
            continue
        var transfer_total := replenishment_rate(tier)
        if transfer_total <= 0.000001:
            saturated[tier] = true
            continue
        _transfer_tier_rate(tier)
        saturated[tier] = true
        tier_saturated.emit(tier, transfer_total, tier + 1)


func _transfer_tier_rate(tier: int) -> void:
    if tier >= maximum_tier:
        return
    var next_tier := tier + 1
    var anonymous := float(anonymous_rates.get(tier, 0.0))
    if anonymous > 0.0:
        anonymous_rates[tier] = 0.0
        anonymous_rates[next_tier] = float(anonymous_rates.get(next_tier, 0.0)) + anonymous * transfer_factor
    for raw_source_id in rate_sources.keys():
        var source_id := raw_source_id as StringName
        var source: Dictionary = rate_sources.get(source_id, {})
        if int(source.get("current_tier", -1)) != tier:
            continue
        source["current_tier"] = next_tier
        source["current_rate"] = float(source.get("current_rate", 0.0)) * transfer_factor
        rate_sources[source_id] = source
    spawn_credit[tier] = 0.0
    tier_replenishment_changed.emit(tier, 0.0)
    tier_replenishment_changed.emit(next_tier, replenishment_rate(next_tier))


func _add_anonymous_rate(base_tier: int, amount: float) -> void:
    if absf(amount) <= 0.0000001:
        return
    if amount < 0.0:
        reduce_replenishment(base_tier, -amount)
        return
    var destination := _route_new_rate_tier(base_tier)
    var converted := amount * pow(transfer_factor, maxi(0, destination - base_tier))
    anonymous_rates[destination] = maxf(0.0, float(anonymous_rates.get(destination, 0.0)) + converted)
    tier_replenishment_changed.emit(destination, replenishment_rate(destination))


func _route_new_rate_tier(base_tier: int) -> int:
    var tier := clampi(base_tier, 1, maximum_tier)
    while tier < maximum_tier and int(population.get(tier, 0)) >= unit_cap(tier):
        tier += 1
    return tier


func reduce_replenishment(base_tier: int, base_amount: float) -> float:
    var remaining := maxf(0.0, base_amount)
    var removed_base_equivalent := 0.0
    for tier in range(clampi(base_tier, 1, maximum_tier), maximum_tier + 1):
        if remaining <= 0.000001:
            break
        var conversion := pow(transfer_factor, maxi(0, tier - base_tier))
        var available_equivalent := replenishment_rate(tier) / maxf(0.000001, conversion)
        var take_equivalent := minf(remaining, available_equivalent)
        var take_current := take_equivalent * conversion
        _remove_rate_from_tier(tier, take_current)
        remaining -= take_equivalent
        removed_base_equivalent += take_equivalent
    return removed_base_equivalent


func _remove_rate_from_tier(tier: int, amount: float) -> void:
    var remaining := maxf(0.0, amount)
    var anonymous := float(anonymous_rates.get(tier, 0.0))
    var take := minf(anonymous, remaining)
    anonymous_rates[tier] = anonymous - take
    remaining -= take
    if remaining > 0.000001:
        for raw_source_id in rate_sources.keys():
            var source_id := raw_source_id as StringName
            var source: Dictionary = rate_sources.get(source_id, {})
            if int(source.get("current_tier", -1)) != tier:
                continue
            var source_rate := float(source.get("current_rate", 0.0))
            take = minf(source_rate, remaining)
            source_rate -= take
            remaining -= take
            if source_rate <= 0.000001:
                rate_sources.erase(source_id)
            else:
                source["current_rate"] = source_rate
                var base_tier := int(source.get("base_tier", tier))
                source["base_rate"] = source_rate / pow(transfer_factor, maxi(0, tier - base_tier))
                rate_sources[source_id] = source
            if remaining <= 0.000001:
                break
    tier_replenishment_changed.emit(tier, replenishment_rate(tier))


func _accumulate_and_spawn(tier: int, delta: float) -> void:
    var count := int(population.get(tier, 0))
    var cap := unit_cap(tier)
    if count >= cap:
        return
    var rate := replenishment_rate(tier)
    if rate <= 0.000001:
        return
    var credit := minf(spawn_credit_cap, float(spawn_credit.get(tier, 0.0)) + rate * delta / 60.0)
    spawn_credit[tier] = credit
    while credit >= 1.0 and int(population.get(tier, 0)) < cap:
        var nest := _select_spawn_nest(tier)
        if nest == null:
            break
        if not _spawn_from_nest(tier, nest):
            break
        credit -= 1.0
        spawn_credit[tier] = credit


func _select_spawn_nest(tier: int) -> Node:
    var candidates: Array[Node] = []
    for raw_nest_id in nests.keys():
        var nest: Node = nests.get(raw_nest_id, null)
        if nest == null or not is_instance_valid(nest):
            continue
        if nest.has_method(&"can_spawn_tier") and bool(nest.call(&"can_spawn_tier", tier)):
            candidates.append(nest)
    if candidates.is_empty():
        return null
    candidates.sort_custom(func(a: Node, b: Node) -> bool:
        var a_id := str(a.get("nest_id"))
        var b_id := str(b.get("nest_id"))
        var a_score := _stable_hash("%s:%d:%d" % [a_id, tier, spawn_serial])
        var b_score := _stable_hash("%s:%d:%d" % [b_id, tier, spawn_serial])
        return a_score < b_score
    )
    return candidates[0]


func _spawn_from_nest(tier: int, nest: Node) -> bool:
    if world == null or not world.has_method(&"_spawn_enemy"):
        return false
    spawn_serial += 1
    var tier_data := get_tier_data(tier)
    var raw_species: Array = tier_data.get("species", [])
    if raw_species.is_empty():
        return false
    var species := StringName(str(raw_species[spawn_serial % raw_species.size()]))
    var position: Vector3 = nest.call(&"next_spawn_position", tier, spawn_serial) if nest.has_method(&"next_spawn_position") else (nest as Node3D).global_position
    var enemy: Variant = world.call(&"_spawn_enemy", position, species)
    if not (enemy is Node3D):
        return false
    var nest_id := StringName(str(nest.get("nest_id")))
    assign_enemy_tier(enemy as Node, tier, nest_id)
    _register_enemy(enemy as Node)
    population[tier] = int(population.get(tier, 0)) + 1
    tier_population_changed.emit(tier, int(population[tier]), unit_cap(tier))
    enemy_tier_spawned.emit(enemy as Node3D, tier, nest_id)
    return true


func _stable_hash(value: String) -> int:
    var hash_value := 2166136261
    for byte in value.to_utf8_buffer():
        hash_value = int((hash_value ^ int(byte)) * 16777619) & 0x7fffffff
    return hash_value


func _poll_world_progression() -> void:
    if progression_node != null and is_instance_valid(progression_node):
        var heartforge_tier := int(progression_node.get("heartforge_tier"))
        if heartforge_tier > last_heartforge_tier:
            for tier_value in range(last_heartforge_tier + 1, heartforge_tier + 1):
                apply_event(StringName("heartforge_tier_%d" % tier_value))
            last_heartforge_tier = heartforge_tier
    if operation_node != null and is_instance_valid(operation_node):
        var completed: Variant = operation_node.get("completed_operations")
        if completed is Array:
            for raw_operation_id in completed:
                apply_event(StringName(str(raw_operation_id)))


func apply_event(event_id: StringName) -> bool:
    if event_id == &"" or applied_events.has(event_id):
        return false
    var modifiers: Dictionary = config.get("event_modifiers", {})
    var raw: Variant = modifiers.get(String(event_id), modifiers.get(event_id, null))
    if not (raw is Dictionary):
        return false
    var deltas := raw as Dictionary
    for raw_tier in deltas.keys():
        var tier := int(str(raw_tier))
        var amount := float(deltas[raw_tier])
        _add_anonymous_rate(tier, amount)
    applied_events[event_id] = true
    escalation_event_applied.emit(event_id, deltas.duplicate(true))
    _emit_intel_if_changed(true)
    return true


func infer_tier_for_species(species: StringName) -> int:
    for tier in tier_order:
        var species_list: Array = get_tier_data(tier).get("species", [])
        if String(species) in species_list:
            return tier
    match species:
        &"apex":
            return 5
        &"broodmass", &"rootweaver", &"miremaw":
            return 4
        &"veilstalker", &"sporecaster", &"carrionbell", &"glassmoth":
            return 3
        &"burrower", &"roofleaper", &"razorhound":
            return 2
        _:
            return 1


func get_tier_data(tier: int) -> Dictionary:
    var raw: Variant = tiers.get(tier, {})
    return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func unit_cap(tier: int) -> int:
    return maxi(1, int(get_tier_data(tier).get("unit_cap", 1)))


func replenishment_rate(tier: int) -> float:
    var total := maxf(0.0, float(anonymous_rates.get(tier, 0.0)))
    for source in rate_sources.values():
        if source is Dictionary and int(source.get("current_tier", -1)) == tier:
            total += maxf(0.0, float(source.get("current_rate", 0.0)))
    return total


func active_nest_count() -> int:
    var count := 0
    for nest in nests.values():
        if is_instance_valid(nest) and (not nest.has_method(&"is_alive") or bool(nest.call(&"is_alive"))):
            count += 1
    return count


func highest_confirmed_tier() -> int:
    for tier in range(maximum_tier, 0, -1):
        if int(population.get(tier, 0)) > 0:
            return tier
    return 1


func density_label(tier: int) -> String:
    var fraction := float(population.get(tier, 0)) / float(unit_cap(tier))
    var thresholds: Dictionary = config.get("intel_thresholds", {})
    if fraction >= float(thresholds.get("saturated_fraction", 0.98)):
        return "SATURATED"
    if fraction >= float(thresholds.get("dense_fraction", 0.75)):
        return "DENSE"
    if fraction >= float(thresholds.get("present_fraction", 0.45)):
        return "PRESENT"
    if fraction >= float(thresholds.get("sparse_fraction", 0.2)):
        return "SPARSE"
    return "LOW"


func intelligence_summary() -> Dictionary:
    var highest := highest_confirmed_tier()
    var saturated_tiers: Array[int] = []
    var rates: Dictionary = {}
    var populations: Dictionary = {}
    for tier in tier_order:
        populations[str(tier)] = {
            "current": int(population.get(tier, 0)),
            "cap": unit_cap(tier),
            "density": density_label(tier),
        }
        rates[str(tier)] = replenishment_rate(tier)
        if int(population.get(tier, 0)) >= unit_cap(tier):
            saturated_tiers.append(tier)
    var trend := "STABLE"
    if not saturated_tiers.is_empty() or replenishment_rate(maxi(2, highest)) > 0.15:
        trend = "WORSENING"
    elif active_nest_count() <= 2 and replenishment_rate(1) < 1.0:
        trend = "SUPPRESSED"
    return {
        "tier_1_density": density_label(1),
        "highest_confirmed_tier": highest,
        "highest_tier_name": str(get_tier_data(highest).get("display_name", "Unknown")),
        "saturated_tiers": saturated_tiers,
        "active_nests": active_nest_count(),
        "trend": trend,
        "populations": populations,
        "rates": rates,
    }


func _emit_intel_if_changed(force: bool = false) -> void:
    var summary := intelligence_summary()
    var signature := JSON.stringify(summary)
    if not force and signature == last_intel_signature:
        return
    last_intel_signature = signature
    ecology_intel_changed.emit(summary)


func _emit_all_rates() -> void:
    for tier in tier_order:
        tier_replenishment_changed.emit(tier, replenishment_rate(tier))


func debug_set_population(tier: int, value: int) -> void:
    population[tier] = clampi(value, 0, unit_cap(tier))
    saturated[tier] = int(population[tier]) >= unit_cap(tier)


func debug_set_anonymous_rate(tier: int, value: float) -> void:
    anonymous_rates[tier] = maxf(0.0, value)


func debug_process_saturation() -> void:
    _process_saturation_high_to_low()


func debug_simulation_tick(delta: float) -> void:
    _simulation_tick(delta)


func to_dictionary() -> Dictionary:
    var serialized_sources: Dictionary = {}
    for source_id in rate_sources:
        serialized_sources[String(source_id)] = (rate_sources[source_id] as Dictionary).duplicate(true)
    var serialized_nests: Dictionary = {}
    for nest_id in nests:
        var nest: Node = nests[nest_id]
        if is_instance_valid(nest) and nest.has_method(&"to_dictionary"):
            serialized_nests[String(nest_id)] = nest.call(&"to_dictionary")
    return {
        "schema_version": 1,
        "elapsed_seconds": elapsed_seconds,
        "spawn_serial": spawn_serial,
        "population": _stringify_numeric_dictionary(population),
        "anonymous_rates": _stringify_numeric_dictionary(anonymous_rates),
        "spawn_credit": _stringify_numeric_dictionary(spawn_credit),
        "saturated": _stringify_numeric_dictionary(saturated),
        "rate_sources": serialized_sources,
        "applied_events": _stringify_key_dictionary(applied_events),
        "last_heartforge_tier": last_heartforge_tier,
        "nests": serialized_nests,
    }


func restore_from_dictionary(data: Dictionary) -> void:
    elapsed_seconds = maxf(0.0, float(data.get("elapsed_seconds", 0.0)))
    spawn_serial = maxi(0, int(data.get("spawn_serial", 0)))
    _restore_numeric_dictionary(population, data.get("population", {}), true)
    _restore_numeric_dictionary(anonymous_rates, data.get("anonymous_rates", {}), false)
    _restore_numeric_dictionary(spawn_credit, data.get("spawn_credit", {}), false)
    _restore_numeric_dictionary(saturated, data.get("saturated", {}), false)
    rate_sources.clear()
    var saved_sources: Dictionary = data.get("rate_sources", {})
    for raw_source_id in saved_sources:
        var value: Variant = saved_sources[raw_source_id]
        if value is Dictionary:
            rate_sources[StringName(str(raw_source_id))] = (value as Dictionary).duplicate(true)
    applied_events.clear()
    var saved_events: Dictionary = data.get("applied_events", {})
    for raw_event_id in saved_events:
        applied_events[StringName(str(raw_event_id))] = bool(saved_events[raw_event_id])
    last_heartforge_tier = clampi(int(data.get("last_heartforge_tier", 1)), 1, maximum_tier)
    var saved_nests: Dictionary = data.get("nests", {})
    for raw_nest_id in saved_nests:
        var nest_id := StringName(str(raw_nest_id))
        var nest: Node = nests.get(nest_id, null)
        if nest != null and is_instance_valid(nest) and nest.has_method(&"restore_from_dictionary"):
            nest.call(&"restore_from_dictionary", saved_nests[raw_nest_id])
    _reconcile_population()
    _refresh_nest_sources()
    _emit_all_rates()
    _emit_intel_if_changed(true)


func _stringify_numeric_dictionary(source: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for key in source:
        result[str(key)] = source[key]
    return result


func _stringify_key_dictionary(source: Dictionary) -> Dictionary:
    var result: Dictionary = {}
    for key in source:
        result[String(key)] = source[key]
    return result


func _restore_numeric_dictionary(target: Dictionary, raw: Variant, integer_values: bool) -> void:
    if not (raw is Dictionary):
        return
    var source := raw as Dictionary
    for tier in tier_order:
        var value: Variant = source.get(str(tier), source.get(tier, target.get(tier, 0)))
        target[tier] = int(value) if integer_values else float(value)
