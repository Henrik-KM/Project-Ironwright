class_name EcologyDirector3D
extends Node

signal pressure_changed(value: float)

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
var world_pressure: float = 0.18
var pending_noise_budget: float = 0.0
var last_noise_position: Vector3 = Vector3.ZERO
var spawn_cooldown: float = 0.0
var passive_clock: float = 0.0
var initial_spawned: bool = false


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
    for index in range(nest_population.size()):
        nest_population[index] = minf(8.0, nest_population[index] + delta * (0.014 + world_pressure * 0.018))

    if not initial_spawned:
        initial_spawned = true
        _spawn_initial_ecology()

    var active_count := get_tree().get_nodes_in_group("organic_enemies").size()
    var passive_cap := 5 + int(world_pressure * 7.0)
    if passive_clock >= 7.0 and active_count < passive_cap and spawn_cooldown <= 0.0:
        passive_clock = 0.0
        _spawn_from_nest(_best_nest_for_position(heartforge_reference.global_position), _ambient_species())

    if pending_noise_budget >= 0.72 and spawn_cooldown <= 0.0:
        pending_noise_budget -= 0.72
        _spawn_from_nest(_best_nest_for_position(last_noise_position), _species_for_pressure())


func _on_noise(position: Vector3, radius: float, intensity: float, source_kind: StringName) -> void:
    last_noise_position = position
    pending_noise_budget += intensity * (0.55 if source_kind == &"robot_salvage" else 0.9)
    world_pressure = clampf(world_pressure + intensity * 0.012, 0.0, 1.0)
    pressure_changed.emit(world_pressure)

    for enemy in get_tree().get_nodes_in_group("organic_enemies"):
        if is_instance_valid(enemy) and enemy.has_method("hear_noise"):
            enemy.call("hear_noise", position, radius, intensity, source_kind)

    if source_kind == &"manual_salvage" or source_kind == &"forge_build":
        pending_noise_budget += 0.45


func _spawn_initial_ecology() -> void:
    _spawn_enemy(Vector3(-16.0, 0.0, -22.0), &"skitterling")
    _spawn_enemy(Vector3(21.0, 0.0, -31.0), &"razorhound")
    _spawn_enemy(Vector3(-34.0, 0.0, 13.0), &"skitterling")


func _spawn_from_nest(index: int, species: StringName) -> void:
    if index < 0 or index >= nest_positions.size() or nest_population[index] < 1.0:
        return
    nest_population[index] -= 1.0
    var offset := Vector3(sin(Time.get_ticks_msec() * 0.001 + index) * 3.0, 0.0, cos(Time.get_ticks_msec() * 0.0013 + index) * 3.0)
    _spawn_enemy(nest_positions[index] + offset, species)
    spawn_cooldown = 2.4


func _spawn_enemy(position: Vector3, species: StringName) -> void:
    if spawn_enemy_callable.is_valid():
        spawn_enemy_callable.call(position, species)


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


func _ambient_species() -> StringName:
    return &"skitterling" if world_pressure < 0.45 else &"razorhound"


func _species_for_pressure() -> StringName:
    if world_pressure > 0.72:
        return &"veilstalker"
    if world_pressure > 0.34:
        return &"razorhound"
    return &"skitterling"


func to_dictionary() -> Dictionary:
    return {
        "world_pressure": world_pressure,
        "nest_population": nest_population.duplicate(),
        "pending_noise_budget": pending_noise_budget,
        "last_noise_position": [last_noise_position.x, last_noise_position.y, last_noise_position.z],
    }


func restore_from_dictionary(data: Dictionary) -> void:
    world_pressure = float(data.get("world_pressure", world_pressure))
    var saved_population: Array = data.get("nest_population", [])
    for index in range(mini(saved_population.size(), nest_population.size())):
        nest_population[index] = float(saved_population[index])
    pending_noise_budget = float(data.get("pending_noise_budget", 0.0))
    var saved_position: Array = data.get("last_noise_position", [])
    if saved_position.size() >= 3:
        last_noise_position = Vector3(float(saved_position[0]), float(saved_position[1]), float(saved_position[2]))
