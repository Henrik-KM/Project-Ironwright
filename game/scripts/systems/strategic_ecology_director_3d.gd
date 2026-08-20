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
var reports_cooldown: float = 0.0


func configure(next_region_director: WorldRegionDirector3D, next_spawn_enemy_callback: Callable) -> void:
    region_director = next_region_director
    spawn_enemy_callback = next_spawn_enemy_callback


func _process(delta: float) -> void:
    if region_director == null:
        return
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


func _update_regions() -> void:
    var active_total := get_tree().get_nodes_in_group(&"organic_enemies").size()
    if active_total >= active_enemy_cap:
        return
    for raw_region_id in region_director.region_data:
        var region_id := raw_region_id as StringName
        var data := region_director.get_region_data(region_id)
        var landmark := region_director.get_landmark(region_id)
        if landmark == null:
            continue

        var local_count := _enemy_count_in_region(region_id)
        var pressure := landmark.effective_pressure() * pressure_multiplier
        var target_count := int(round(float(data.get("spawn_budget", 5)) * pressure * minf(endgame_escalation, 2.4)))
        target_count = clampi(target_count, 1, 28)
        if local_count < target_count and active_total < active_enemy_cap:
            _spawn_regional_organism(region_id, local_count)
            active_total += 1

        var drift := -0.0025 if local_count <= target_count else 0.001
        if region_id == &"region.heartforge_district":
            drift += 0.0012
        landmark.set_pressure(maxf(float(data.get("base_pressure", 0.4)) * 0.72, landmark.pressure + drift * pressure_multiplier))
        regional_pressure_changed.emit(region_id, landmark.effective_pressure())


func record_disturbance(position: Vector3, intensity: float, source_kind: StringName) -> void:
    var region_id := region_director.region_for_position(position)
    var amount := clampf(intensity * 0.035 * pressure_multiplier, 0.005, 0.16)
    region_director.add_pressure(region_id, amount)
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
    var landmark := region_director.get_landmark(region_id)
    if landmark != null:
        landmark.set_pressure(maxf(0.05, landmark.pressure - reduction))


func set_endgame_escalation(value: float) -> void:
    endgame_escalation = clampf(value, 1.0, 3.5)


func _attempt_migration() -> void:
    if get_tree().get_nodes_in_group(&"organic_enemies").size() >= active_enemy_cap - 4:
        return
    var source_id: StringName = &""
    var source_pressure := 1.15
    for raw_region_id in region_director.region_data:
        var region_id := raw_region_id as StringName
        if region_id == &"region.heartforge_district":
            continue
        var pressure := region_director.effective_pressure(region_id) * pressure_multiplier
        if pressure > source_pressure:
            source_id = region_id
            source_pressure = pressure
    if source_id == &"":
        return

    var data := region_director.get_region_data(source_id)
    var raw_route: Array = data.get("route_from_heartforge", [])
    if raw_route.size() < 2:
        return
    var source_point: Array = raw_route[raw_route.size() - 2]
    if source_point.size() < 3:
        return
    var origin := Vector3(float(source_point[0]), float(source_point[1]), float(source_point[2]))
    var pack_size := clampi(1 + int(floor(source_pressure)), 2, 5)
    for index in range(pack_size):
        var offset := Vector3(float(index - pack_size / 2) * 1.8, 0.0, float(index % 2) * 1.4)
        _spawn_species(origin + offset, _species_for_region(source_id, index + spawn_serial), source_id, &"hunt")
    region_director.add_pressure(source_id, -0.035)
    var landmark := region_director.get_landmark(source_id)
    if landmark != null:
        ecology_report.emit("A hunting migration has left %s and entered the connecting streets." % landmark.display_name)


func _spawn_regional_organism(region_id: StringName, local_count: int) -> void:
    spawn_serial += 1
    var center := region_director.center(region_id)
    var radius := region_director.radius(region_id)
    var angle := fmod(float(spawn_serial) * 2.399963, TAU)
    var distance := radius * (0.48 + fmod(float(spawn_serial * 13), 40.0) / 100.0)
    var position := center + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
    var species := _species_for_region(region_id, local_count + spawn_serial)
    _spawn_species(position, species, region_id, _directive_for_region(region_id, species, local_count + spawn_serial))


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
        return enemy
    return spawned as Node if spawned is Node else null


func _directive_for_region(region_id: StringName, species: StringName, selector: int) -> StringName:
    var data := region_director.get_region_data(region_id)
    var kind := StringName(str(data.get("kind", "urban")))
    if species in [&"broodmass", &"sporecaster"]:
        return &"protect_nest"
    if species == &"razorhound":
        return &"hunt"
    if species == &"veilstalker":
        return &"scout"
    if species == &"burrower":
        return &"patrol"
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
            return &"carrionbell" if selector % 7 == 0 else (&"burrower" if selector % 3 == 0 else &"razorhound")
        &"tenement":
            return &"roofleaper" if selector % 2 == 0 else &"razorhound"
        &"greenhouse":
            return &"glassmoth" if selector % 2 == 0 else &"sporecaster"
        &"commercial":
            return &"sporecaster" if selector % 3 == 0 else (&"glassmoth" if selector % 5 == 0 else &"skitterling")
        &"waterfront":
            return &"miremaw" if selector % 6 == 0 else (&"burrower" if selector % 3 == 0 else &"razorhound")
        &"rail":
            return &"carrionbell" if selector % 5 == 0 else (&"burrower" if selector % 2 == 0 else &"razorhound")
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
    var highest_name := "Heartforge District"
    var highest_pressure := 0.0
    for raw_region_id in region_director.region_data:
        var region_id := raw_region_id as StringName
        var pressure := region_director.effective_pressure(region_id) * pressure_multiplier
        if pressure > highest_pressure:
            highest_pressure = pressure
            var landmark := region_director.get_landmark(region_id)
            if landmark != null:
                highest_name = landmark.display_name
    return "%s · pressure %.2f" % [highest_name, highest_pressure]


func to_dictionary() -> Dictionary:
    return {
        "schema_version": 2,
        "spawn_serial": spawn_serial,
        "endgame_escalation": endgame_escalation,
        "migration_clock": migration_clock,
        "active_enemy_cap": active_enemy_cap,
        "pressure_multiplier": pressure_multiplier,
    }


func restore_from_dictionary(data: Dictionary) -> void:
    spawn_serial = maxi(0, int(data.get("spawn_serial", 0)))
    endgame_escalation = clampf(float(data.get("endgame_escalation", 1.0)), 1.0, 3.5)
    migration_clock = maxf(0.0, float(data.get("migration_clock", 0.0)))
    active_enemy_cap = clampi(int(data.get("active_enemy_cap", active_enemy_cap)), 32, 180)
    pressure_multiplier = clampf(float(data.get("pressure_multiplier", pressure_multiplier)), 0.5, 1.8)
