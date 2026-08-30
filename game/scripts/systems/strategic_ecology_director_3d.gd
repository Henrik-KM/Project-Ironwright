class_name StrategicEcologyDirector3D
extends Node

signal ecology_report(message: String)
signal regional_pressure_changed(region_id: StringName, pressure: float)

var region_director: WorldRegionDirector3D
var spawn_enemy_callback: Callable
var evaluation_clock: float = 0.0
var migration_clock: float = 0.0
var spawn_serial: int = 0
var active_enemy_cap: int = 96
var endgame_escalation: float = 1.0
var pressure_multiplier: float = 1.0
var run_variation_pressure_multiplier: float = 1.0
var reports_cooldown: float = 0.0
var population_states: Dictionary = {}
var run_state: RunState3D
var external_population_control: bool = false


func configure(next_region_director: WorldRegionDirector3D, next_spawn_enemy_callback: Callable, next_run_state: RunState3D = null) -> void:
    region_director = next_region_director
    spawn_enemy_callback = next_spawn_enemy_callback
    run_state = next_run_state


func set_external_population_control(value: bool) -> void:
    external_population_control = value
    if value:
        # The canonical tier director is the only birth authority. Regional
        # state remains live so pressure, hunger, memory, and migrations keep
        # evolving instead of becoming a frozen backdrop.
        spawn_enemy_callback = Callable()


func _process(delta: float) -> void:
    if region_director == null:
        return
    _ensure_population_states()
    reports_cooldown = maxf(0.0, reports_cooldown - delta)
    evaluation_clock += delta
    migration_clock += delta
    if evaluation_clock >= 3.8:
        evaluation_clock = 0.0
        _update_regions()
    if migration_clock >= 23.0:
        migration_clock = 0.0
        _attempt_migration()


func set_release_balance(next_enemy_cap: int, next_pressure_multiplier: float) -> void:
    active_enemy_cap = clampi(next_enemy_cap, 32, 180)
    pressure_multiplier = clampf(next_pressure_multiplier, 0.5, 1.8)


func set_run_variation_pressure_multiplier(value: float) -> void:
    run_variation_pressure_multiplier = clampf(value, 0.75, 1.35)


func effective_pressure_multiplier() -> float:
    return pressure_multiplier * run_variation_pressure_multiplier


func _update_regions() -> void:
    _ensure_population_states()
    var active_total := get_tree().get_nodes_in_group(&"organic_enemies").size()
    for raw_region_id in region_director.region_data:
        var region_id := raw_region_id as StringName
        var data := region_director.get_region_data(region_id)
        var landmark := region_director.get_landmark(region_id)
        if landmark == null:
            continue

        var local_count := _enemy_count_in_region(region_id)
        var pressure := landmark.effective_pressure() * effective_pressure_multiplier()
        var state: Dictionary = population_states[region_id]
        _advance_population_state(state, pressure, float(data.get("spawn_budget", 5)))
        var target_count := int(round(float(state.get("population", 4.0)) * 0.42 * minf(endgame_escalation, 2.4)))
        target_count += int(round(pressure * 1.5))
        target_count = clampi(target_count, 1, 28)
        if (
            not external_population_control
            and spawn_enemy_callback.is_valid()
            and local_count < target_count
            and active_total < active_enemy_cap
        ):
            _spawn_regional_organism(region_id, local_count)
            active_total += 1

        var drift := -0.0025 if local_count <= target_count else 0.001
        if region_id == &"region.heartforge_district":
            drift += 0.0012
        landmark.set_pressure(maxf(float(data.get("base_pressure", 0.4)) * 0.72, landmark.pressure + drift * effective_pressure_multiplier()))
        if run_state != null:
            run_state.observe_region_pressure(region_id, landmark.effective_pressure() * effective_pressure_multiplier(), landmark.display_name)
        regional_pressure_changed.emit(region_id, landmark.effective_pressure())


func record_disturbance(position: Vector3, intensity: float, source_kind: StringName) -> void:
    var region_id := region_director.region_for_position(position)
    var amount := clampf(intensity * 0.035 * effective_pressure_multiplier(), 0.005, 0.16)
    region_director.add_pressure(region_id, amount)
    _ensure_population_states()
    if population_states.has(region_id):
        var state: Dictionary = population_states[region_id]
        state["disturbance"] = clampf(float(state.get("disturbance", 0.0)) + intensity * 0.09, 0.0, 1.0)
        state["food"] = maxf(0.0, float(state.get("food", 0.65)) - intensity * 0.012)
        state["migration_tendency"] = clampf(float(state.get("migration_tendency", 0.0)) + intensity * 0.025, 0.0, 1.0)
    if reports_cooldown <= 0.0 and intensity >= 0.9:
        reports_cooldown = 5.0
        var landmark := region_director.get_landmark(region_id)
        if landmark != null:
            ecology_report.emit("Organic activity is concentrating around %s after %s." % [landmark.display_name, String(source_kind).replace("_", " ")])


func record_organic_kill(position: Vector3, species: StringName) -> void:
    var region_id := region_director.region_for_position(position)
    var reduction := 0.002
    if species in [&"broodmass", &"rootweaver"]:
        reduction = 0.018
    elif species in [&"apex", &"miremaw"]:
        reduction = 0.08
    elif species == &"carrionbell":
        reduction = 0.012
    elif species == &"ashmantle":
        reduction = 0.014
    elif species == &"thornback":
        reduction = 0.006
    var landmark := region_director.get_landmark(region_id)
    if landmark != null:
        landmark.set_pressure(maxf(0.05, landmark.pressure - reduction))
    _ensure_population_states()
    if population_states.has(region_id):
        var state: Dictionary = population_states[region_id]
        var population_loss := 0.45
        if species in [&"broodmass", &"rootweaver"]:
            population_loss = 1.8
        elif species in [&"apex", &"miremaw"]:
            population_loss = 3.2
        state["population"] = maxf(0.5, float(state.get("population", 4.0)) - population_loss)
        state["hunger"] = clampf(float(state.get("hunger", 0.35)) + 0.045, 0.0, 1.0)
        state["disturbance"] = clampf(float(state.get("disturbance", 0.0)) + 0.08, 0.0, 1.0)


func set_endgame_escalation(value: float) -> void:
    endgame_escalation = clampf(value, 1.0, 3.5)


func _attempt_migration() -> void:
    if not external_population_control and get_tree().get_nodes_in_group(&"organic_enemies").size() >= active_enemy_cap - 4:
        return
    _ensure_population_states()
    var source_id: StringName = &""
    var source_pressure := 0.0
    for raw_region_id in region_director.region_data:
        var region_id := raw_region_id as StringName
        if region_id == &"region.heartforge_district":
            continue
        var pressure := region_director.effective_pressure(region_id) * effective_pressure_multiplier()
        var state: Dictionary = population_states.get(region_id, {})
        var migration_score := pressure * float(state.get("migration_tendency", 0.0))
        if migration_score > source_pressure:
            source_id = region_id
            source_pressure = migration_score
    if source_id == &"" or source_pressure < 0.46:
        return

    var data := region_director.get_region_data(source_id)
    var raw_route: Array = data.get("route_from_heartforge", [])
    if raw_route.size() < 2:
        return
    var source_point: Array = raw_route[raw_route.size() - 2]
    if source_point.size() < 3:
        return
    var origin := Vector3(float(source_point[0]), float(source_point[1]), float(source_point[2]))
    var destination := origin
    var destination_point: Variant = raw_route[0]
    if destination_point is Array and (destination_point as Array).size() >= 3:
        destination = Vector3(float(destination_point[0]), float(destination_point[1]), float(destination_point[2]))
    var pack_size := clampi(1 + int(floor(source_pressure)), 2, 5)
    var migrated_count := 0
    if external_population_control:
        migrated_count = _redirect_existing_migration(source_id, destination, pack_size)
    else:
        for index in range(pack_size):
            var offset := Vector3(float(index - pack_size / 2) * 1.8, 0.0, float(index % 2) * 1.4)
            if _spawn_species(origin + offset, _species_for_region(source_id, index + spawn_serial), source_id, &"hunt") != null:
                migrated_count += 1
    if migrated_count <= 0:
        return
    var source_state: Dictionary = population_states[source_id]
    source_state["population"] = maxf(0.5, float(source_state.get("population", 4.0)) - float(migrated_count) * 0.8)
    source_state["migration_tendency"] = clampf(float(source_state.get("migration_tendency", 0.0)) - 0.22, 0.0, 1.0)
    source_state["disturbance"] = clampf(float(source_state.get("disturbance", 0.0)) - 0.08, 0.0, 1.0)
    region_director.add_pressure(source_id, -0.035)
    var landmark := region_director.get_landmark(source_id)
    if landmark != null:
        ecology_report.emit("A hunting migration has left %s and entered the connecting streets." % landmark.display_name)


func _redirect_existing_migration(source_id: StringName, destination: Vector3, pack_size: int) -> int:
    var candidates: Array[Node3D] = []
    for node in get_tree().get_nodes_in_group(&"organic_enemies"):
        if not (node is Node3D) or not is_instance_valid(node):
            continue
        var enemy := node as Node3D
        if enemy.is_in_group(&"enemy_tier_nests"):
            continue
        if enemy.has_method(&"is_alive") and not bool(enemy.call(&"is_alive")):
            continue
        if StringName(str(enemy.get_meta(&"ecology_region", ""))) != source_id:
            continue
        candidates.append(enemy)
    candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
        return a.global_position.distance_squared_to(destination) < b.global_position.distance_squared_to(destination)
    )
    var redirected := mini(pack_size, candidates.size())
    for index in range(redirected):
        var enemy := candidates[index]
        var offset := Vector3(float(index - redirected / 2) * 1.8, 0.0, float(index % 2) * 1.4)
        var brain := enemy.get_node_or_null("EnemyTierBrain")
        if brain != null and brain.has_method(&"receive_migration_goal"):
            brain.call(&"receive_migration_goal", destination + offset, source_id)
        elif enemy.has_method(&"hear_noise"):
            enemy.call(&"hear_noise", destination + offset, 1000.0, 1.0, &"regional_migration")
        enemy.set_meta(&"ecology_origin", "regional_migration")
    return redirected


func _spawn_regional_organism(region_id: StringName, local_count: int) -> void:
    spawn_serial += 1
    var center := region_director.center(region_id)
    var radius := region_director.radius(region_id)
    var angle := fmod(float(spawn_serial) * 2.399963, TAU)
    var distance := radius * (0.48 + fmod(float(spawn_serial * 13), 40.0) / 100.0)
    var position := center + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
    var species := _species_for_region(region_id, local_count + spawn_serial)
    _spawn_species(position, species, region_id, _directive_for_region(region_id, species, local_count + spawn_serial))


func _ensure_population_states() -> void:
    if region_director == null:
        return
    for raw_region_id in region_director.region_data:
        var region_id := raw_region_id as StringName
        if population_states.has(region_id):
            continue
        var data := region_director.get_region_data(region_id)
        var base_population := clampf(float(data.get("spawn_budget", 5)) * 1.8, 2.0, 38.0)
        population_states[region_id] = {
            "region_id": String(region_id),
            "population": base_population,
            "health": 0.78,
            "food": 0.68,
            "hunger": 0.3,
            "territory": 0.52,
            "nesting": 0.24 if StringName(str(data.get("kind", "urban"))) == &"nest" else 0.08,
            "disturbance": 0.0,
            "migration_tendency": 0.18,
        }


func _advance_population_state(state: Dictionary, pressure: float, spawn_budget: float) -> void:
    var food := clampf(float(state.get("food", 0.68)), 0.0, 1.0)
    var hunger := clampf(float(state.get("hunger", 0.3)) + 0.009 + pressure * 0.003, 0.0, 1.0)
    var disturbance := maxf(0.0, float(state.get("disturbance", 0.0)) - 0.012)
    food = clampf(food + 0.004 - hunger * 0.002 - disturbance * 0.001, 0.0, 1.0)
    var population := maxf(0.5, float(state.get("population", spawn_budget * 1.8)))
    if food > 0.48 and disturbance < 0.55:
        population += 0.035 + float(state.get("nesting", 0.08)) * 0.02
    elif food < 0.22 or hunger > 0.78:
        population -= 0.06
    var territory := clampf(float(state.get("territory", 0.52)) + (population / maxf(2.0, spawn_budget * 2.0) - 0.5) * 0.003, 0.0, 1.0)
    var nesting := clampf(float(state.get("nesting", 0.08)) + (0.006 if food > 0.5 else -0.008), 0.0, 1.0)
    var migration_tendency := clampf(hunger * 0.44 + disturbance * 0.42 + pressure * 0.14 - territory * 0.08, 0.0, 1.0)
    state["population"] = clampf(population, 0.5, 42.0)
    state["health"] = clampf(food * 0.62 + (1.0 - hunger) * 0.38, 0.0, 1.0)
    state["food"] = food
    state["hunger"] = hunger
    state["territory"] = territory
    state["nesting"] = nesting
    state["disturbance"] = disturbance
    state["migration_tendency"] = migration_tendency


func population_state(region_id: StringName) -> Dictionary:
    _ensure_population_states()
    var state: Variant = population_states.get(region_id, {})
    return (state as Dictionary).duplicate(true) if state is Dictionary else {}


func _spawn_species(position: Vector3, species: StringName, region_id: StringName = &"", directive: StringName = &"") -> Node:
    if not spawn_enemy_callback.is_valid():
        return null
    var spawned: Variant = spawn_enemy_callback.call(position, species)
    if spawned is OrganicEnemy3D:
        var enemy := spawned as OrganicEnemy3D
        var resolved_region := region_id if region_id != &"" else region_director.region_for_position(position)
        var home := region_director.center(resolved_region)
        var radius := maxf(10.0, region_director.radius(resolved_region) * 0.58)
        var resolved_directive := directive if directive != &"" else _directive_for_region(resolved_region, species, spawn_serial)
        enemy.configure_ecology(home, radius, resolved_directive)
        enemy.set_meta(&"ecology_region", String(resolved_region))
        enemy.set_meta(&"ecology_origin", "regional")
        var behaviour_callback := Callable(self, "_on_enemy_behaviour_changed")
        if enemy.has_signal(&"behaviour_changed") and not enemy.is_connected(&"behaviour_changed", behaviour_callback):
            enemy.behaviour_changed.connect(behaviour_callback)
        _on_enemy_behaviour_changed(enemy, enemy.ecology_directive)
        return enemy
    return spawned as Node if spawned is Node else null


func _on_enemy_behaviour_changed(enemy: OrganicEnemy3D, behaviour: StringName) -> void:
    if run_state == null or enemy == null:
        return
    var region_id := StringName(str(enemy.get_meta("ecology_region", "")))
    run_state.observe_organic_species(enemy.species, behaviour, region_id)


func _directive_for_region(region_id: StringName, species: StringName, selector: int) -> StringName:
    var data := region_director.get_region_data(region_id)
    var kind := StringName(str(data.get("kind", "urban")))
    if species in [&"broodmass", &"sporecaster", &"thornback"]:
        return &"protect_nest"
    if species == &"razorhound":
        return &"hunt"
    if species == &"veilstalker":
        return &"scout"
    if species == &"burrower":
        return &"patrol"
    if species == &"ashmantle":
        return &"scout"
    match kind:
        &"nest", &"endgame":
            return &"protect_nest" if selector % 3 != 0 else &"hunt"
        &"industrial", &"research":
            return &"patrol" if selector % 2 == 0 else &"scout"
        &"commercial":
            return &"feed" if selector % 3 != 0 else &"scout"
        _:
            return &"roam" if selector % 3 != 0 else &"hunt"


func _species_for_region(region_id: StringName, selector: int) -> StringName:
    var data := region_director.get_region_data(region_id)
    var kind := StringName(str(data.get("kind", "urban")))
    match kind:
        &"industrial":
            return &"ashmantle" if selector % 11 == 0 else (&"carrionbell" if selector % 7 == 0 else (&"burrower" if selector % 3 == 0 else &"razorhound"))
        &"tenement":
            return &"roofleaper" if selector % 2 == 0 else &"razorhound"
        &"greenhouse":
            return &"thornback" if selector % 7 == 0 else (&"glassmoth" if selector % 2 == 0 else &"sporecaster")
        &"commercial":
            return &"ashmantle" if selector % 11 == 0 else (&"sporecaster" if selector % 3 == 0 else (&"glassmoth" if selector % 5 == 0 else &"skitterling"))
        &"waterfront":
            return &"thornback" if selector % 9 == 0 else (&"miremaw" if selector % 6 == 0 else (&"burrower" if selector % 3 == 0 else &"razorhound"))
        &"rail":
            return &"ashmantle" if selector % 9 == 0 else (&"carrionbell" if selector % 5 == 0 else (&"burrower" if selector % 2 == 0 else &"razorhound"))
        &"nest":
            return &"broodmass" if selector % 5 == 0 else (&"sporecaster" if selector % 2 == 0 else &"razorhound")
        &"observatory":
            return &"roofleaper" if selector % 3 == 0 else (&"carrionbell" if selector % 5 == 0 else &"veilstalker")
        &"research":
            return &"rootweaver" if selector % 7 == 0 else (&"burrower" if selector % 2 == 0 else &"veilstalker")
        &"endgame":
            return &"rootweaver" if selector % 4 == 0 else (&"broodmass" if selector % 5 == 0 else &"veilstalker")
        _:
            return &"razorhound" if selector % 4 == 0 else &"skitterling"


func _enemy_count_in_region(region_id: StringName) -> int:
    var center := region_director.center(region_id)
    var radius := region_director.radius(region_id)
    var count := 0
    for enemy in get_tree().get_nodes_in_group(&"organic_enemies"):
        if is_instance_valid(enemy) and enemy is Node3D and center.distance_to(enemy.global_position) <= radius:
            count += 1
    return count


func pressure_summary() -> String:
    var summary := pressure_summary_data()
    var highest_name := str(summary.get("region_name", "Heartforge District"))
    var highest_pressure := float(summary.get("pressure", 0.0))
    return "%s · pressure %.2f" % [highest_name, highest_pressure]


func pressure_summary_data() -> Dictionary:
    var highest_region_id: StringName = &"region.heartforge_district"
    var highest_name := "Heartforge District"
    var highest_pressure := 0.0
    if region_director == null:
        return {"region_id": highest_region_id, "region_name": highest_name, "pressure": highest_pressure}
    for raw_region_id in region_director.region_data:
        var region_id := raw_region_id as StringName
        var pressure := region_director.effective_pressure(region_id) * effective_pressure_multiplier()
        if pressure > highest_pressure:
            highest_pressure = pressure
            highest_region_id = region_id
            var landmark := region_director.get_landmark(region_id)
            if landmark != null:
                highest_name = landmark.display_name
    return {"region_id": highest_region_id, "region_name": highest_name, "pressure": highest_pressure}


func to_dictionary() -> Dictionary:
    _ensure_population_states()
    var serialized_populations: Array[Dictionary] = []
    for raw_region_id in population_states:
        var state: Dictionary = population_states[raw_region_id]
        serialized_populations.append(state.duplicate(true))
    return {
        "schema_version": 3,
        "spawn_serial": spawn_serial,
        "endgame_escalation": endgame_escalation,
        "migration_clock": migration_clock,
        "active_enemy_cap": active_enemy_cap,
        "pressure_multiplier": pressure_multiplier,
        "external_population_control": external_population_control,
        "population_states": serialized_populations,
    }


func restore_from_dictionary(data: Dictionary) -> void:
    _ensure_population_states()
    spawn_serial = maxi(0, int(data.get("spawn_serial", 0)))
    endgame_escalation = clampf(float(data.get("endgame_escalation", 1.0)), 1.0, 3.5)
    migration_clock = maxf(0.0, float(data.get("migration_clock", 0.0)))
    active_enemy_cap = clampi(int(data.get("active_enemy_cap", active_enemy_cap)), 32, 180)
    pressure_multiplier = clampf(float(data.get("pressure_multiplier", pressure_multiplier)), 0.5, 1.8)
    set_external_population_control(bool(data.get("external_population_control", external_population_control)))
    for raw_state in data.get("population_states", []):
        if not raw_state is Dictionary:
            continue
        var saved: Dictionary = raw_state
        var region_id := StringName(str(saved.get("region_id", "")))
        if region_id == &"" or not population_states.has(region_id):
            continue
        var state: Dictionary = population_states[region_id]
        for field in [&"population", &"health", &"food", &"hunger", &"territory", &"nesting", &"disturbance", &"migration_tendency"]:
            if saved.has(field):
                state[field] = float(saved[field])
