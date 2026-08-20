class_name EcologyDirector3D
extends Node

signal pressure_changed(value: float)
signal nest_activity_changed(index: int, activity: StringName)

var noise_system: NoiseSystem3D
var player_reference: Node3D
var heartforge_reference: Node3D
var spawn_enemy_callable: Callable
var nest_positions: Array[Vector3] = [
    Vector3(-55.0, 0.0, -49.0),
    Vector3(56.0, 0.0, -36.0),
    Vector3(-48.0, 0.0, 47.0),
    Vector3(52.0, 0.0, 52.0),
]
var nest_population: Array[float] = [2.5, 2.0, 2.2, 1.8]
var nest_activity: Array[StringName] = [&"guard", &"scout", &"roam", &"hunt"]
var nest_radii: Array[float] = [18.0, 20.0, 19.0, 21.0]
var world_pressure: float = 0.18
var pending_noise_budget: float = 0.0
var last_noise_position: Vector3 = Vector3.ZERO
var spawn_cooldown: float = 0.0
var passive_clock: float = 0.0
var strategic_clock: float = 0.0
var initial_spawned: bool = false
var spawn_serial: int = 0


func configure(
        next_noise_system: NoiseSystem3D,
        player: Node3D,
        heartforge: Node3D,
        spawn_callable: Callable
    ) -> void:
    noise_system = next_noise_system
    player_reference = player
    heartforge_reference = heartforge
    spawn_enemy_callable = spawn_callable
    if not noise_system.noise_emitted.is_connected(_on_noise):
        noise_system.noise_emitted.connect(_on_noise)


func _process(delta: float) -> void:
    spawn_cooldown = maxf(0.0, spawn_cooldown - delta)
    passive_clock += delta
    strategic_clock += delta
    for index in range(nest_population.size()):
        nest_population[index] = minf(8.0, nest_population[index] + delta * (0.014 + world_pressure * 0.018))

    if not initial_spawned:
        initial_spawned = true
        _spawn_initial_ecology()

    if strategic_clock >= 13.0:
        strategic_clock = 0.0
        _reassess_nest_activity()

    var active_count := get_tree().get_nodes_in_group(&"organic_enemies").size()
    var passive_cap := 5 + int(world_pressure * 7.0)
    if passive_clock >= 7.0 and active_count < passive_cap and spawn_cooldown <= 0.0:
        passive_clock = 0.0
        var nest_index := _best_nest_for_position(heartforge_reference.global_position)
        _spawn_from_nest(nest_index, _ambient_species(), _directive_for_spawn(nest_index, _ambient_species()))

    if pending_noise_budget >= 0.72 and spawn_cooldown <= 0.0:
        pending_noise_budget -= 0.72
        var nest_index := _best_nest_for_position(last_noise_position)
        var species := _species_for_pressure()
        _spawn_from_nest(nest_index, species, &"hunt" if world_pressure >= 0.42 else _directive_for_spawn(nest_index, species))


func _on_noise(position: Vector3, radius: float, intensity: float, source_kind: StringName) -> void:
    last_noise_position = position
    pending_noise_budget += intensity * (0.55 if source_kind == &"robot_salvage" else 0.9)
    world_pressure = clampf(world_pressure + intensity * 0.012, 0.0, 1.0)
    pressure_changed.emit(world_pressure)

    for enemy in get_tree().get_nodes_in_group(&"organic_enemies"):
        if is_instance_valid(enemy) and enemy.has_method(&"hear_noise"):
            enemy.call(&"hear_noise", position, radius, intensity, source_kind)

    if source_kind in [&"manual_salvage", &"forge_build", &"heartforge_evolution"]:
        pending_noise_budget += 0.45


func _spawn_initial_ecology() -> void:
    _spawn_enemy(Vector3(-16.0, 0.0, -22.0), &"skitterling", 0, &"feed")
    _spawn_enemy(Vector3(21.0, 0.0, -31.0), &"veilstalker", 1, &"scout")
    _spawn_enemy(Vector3(-34.0, 0.0, 13.0), &"skitterling", 2, &"roam")


func _spawn_from_nest(index: int, species: StringName, directive: StringName = &"") -> void:
    if index < 0 or index >= nest_positions.size() or nest_population[index] < 1.0:
        return
    nest_population[index] -= 1.0
    spawn_serial += 1
    var angle := float(spawn_serial) * 2.399963 + float(index) * 0.71
    var radius := 1.8 + float((spawn_serial + index) % 4) * 0.9
    var offset := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
    _spawn_enemy(nest_positions[index] + offset, species, index, directive)
    spawn_cooldown = 2.4


func _spawn_enemy(position: Vector3, species: StringName, nest_index: int = -1, directive: StringName = &"") -> Node:
    if not spawn_enemy_callable.is_valid():
        return null
    var spawned: Variant = spawn_enemy_callable.call(position, species)
    if spawned is OrganicEnemy3D:
        var enemy := spawned as OrganicEnemy3D
        var resolved_index := nest_index if nest_index >= 0 else _nearest_nest_index(position)
        var home := nest_positions[resolved_index] if resolved_index >= 0 else position
        var radius := nest_radii[resolved_index] if resolved_index >= 0 else 18.0
        var resolved_directive := directive if directive != &"" else _directive_for_spawn(resolved_index, species)
        enemy.configure_ecology(home, radius, resolved_directive)
        enemy.set_meta(&"nest_index", resolved_index)
        enemy.set_meta(&"ecology_origin", "local_nest")
        return enemy
    return spawned as Node if spawned is Node else null


func _reassess_nest_activity() -> void:
    for index in range(nest_positions.size()):
        var previous := nest_activity[index]
        var distance_to_player := nest_positions[index].distance_to(player_reference.global_position) if player_reference != null else 999.0
        var distance_to_noise := nest_positions[index].distance_to(last_noise_position)
        var next_activity: StringName = previous
        if world_pressure >= 0.72 or distance_to_noise <= 30.0 and pending_noise_budget >= 0.4:
            next_activity = &"hunt"
        elif distance_to_player <= 26.0:
            next_activity = &"guard"
        elif world_pressure >= 0.4 and index % 2 == 1:
            next_activity = &"scout"
        elif index % 3 == 0:
            next_activity = &"patrol"
        else:
            next_activity = &"roam"
        if next_activity != previous:
            nest_activity[index] = next_activity
            nest_activity_changed.emit(index, next_activity)


func _directive_for_spawn(index: int, species: StringName) -> StringName:
    if species in [&"broodmass", &"sporecaster"]:
        return &"protect_nest"
    if species == &"razorhound":
        return &"hunt"
    if species == &"veilstalker":
        return &"scout"
    if species == &"burrower":
        return &"patrol"
    if species == &"skitterling":
        if index >= 0 and nest_activity[index] == &"guard":
            return &"patrol"
        return &"feed"
    if index >= 0:
        match nest_activity[index]:
            &"guard":
                return &"protect_nest"
            &"scout":
                return &"scout"
            &"hunt":
                return &"hunt"
            &"patrol":
                return &"patrol"
    return &"roam"


func _best_nest_for_position(position: Vector3) -> int:
    var best_index := 0
    var best_distance := INF
    for index in range(nest_positions.size()):
        if nest_population[index] < 1.0:
            continue
        var current_distance := nest_positions[index].distance_to(position)
        if current_distance < best_distance:
            best_index = index
            best_distance = current_distance
    return best_index


func _nearest_nest_index(position: Vector3) -> int:
    var best_index := -1
    var best_distance := INF
    for index in range(nest_positions.size()):
        var current_distance := nest_positions[index].distance_to(position)
        if current_distance < best_distance:
            best_index = index
            best_distance = current_distance
    return best_index


func _ambient_species() -> StringName:
    if world_pressure < 0.34:
        return &"skitterling"
    if world_pressure < 0.62:
        return &"razorhound"
    return &"veilstalker"


func _species_for_pressure() -> StringName:
    if world_pressure > 0.78:
        return &"veilstalker"
    if world_pressure > 0.52:
        return &"razorhound"
    if world_pressure > 0.3:
        return &"razorhound"
    return &"skitterling"


func nest_snapshot() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for index in range(nest_positions.size()):
        result.append({
            "index": index,
            "position": nest_positions[index],
            "population": nest_population[index],
            "activity": nest_activity[index],
            "radius": nest_radii[index],
        })
    return result


func to_dictionary() -> Dictionary:
    var activities: Array[String] = []
    for activity in nest_activity:
        activities.append(String(activity))
    return {
        "world_pressure": world_pressure,
        "nest_population": nest_population.duplicate(),
        "nest_activity": activities,
        "pending_noise_budget": pending_noise_budget,
        "last_noise_position": [last_noise_position.x, last_noise_position.y, last_noise_position.z],
        "spawn_serial": spawn_serial,
    }


func restore_from_dictionary(data: Dictionary) -> void:
    world_pressure = float(data.get("world_pressure", world_pressure))
    var saved_population: Array = data.get("nest_population", [])
    for index in range(mini(saved_population.size(), nest_population.size())):
        nest_population[index] = float(saved_population[index])
    var saved_activity: Array = data.get("nest_activity", [])
    for index in range(mini(saved_activity.size(), nest_activity.size())):
        nest_activity[index] = StringName(str(saved_activity[index]))
    pending_noise_budget = float(data.get("pending_noise_budget", 0.0))
    spawn_serial = maxi(0, int(data.get("spawn_serial", spawn_serial)))
    var saved_position: Array = data.get("last_noise_position", [])
    if saved_position.size() >= 3:
        last_noise_position = Vector3(float(saved_position[0]), float(saved_position[1]), float(saved_position[2]))
