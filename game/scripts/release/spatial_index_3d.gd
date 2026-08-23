class_name SpatialIndex3D
extends Node

const INDEXED_GROUPS: Array[StringName] = [
    &"organic_enemies",
    &"enemy_tier_nests",
    &"friendly_robots",
    &"outposts",
    &"salvage_piles",
]

var cell_size: float = 14.0
var rebuild_interval: float = 0.32
var rebuild_clock: float = 0.0
var grids: Dictionary = {}
var indexed_counts: Dictionary = {}
var flat_nodes: Dictionary = {}


func _ready() -> void:
    add_to_group(&"spatial_index_service")
    rebuild()


func _process(delta: float) -> void:
    rebuild_clock += delta
    if rebuild_clock < rebuild_interval:
        return
    rebuild_clock = 0.0
    rebuild()


func rebuild() -> void:
    grids.clear()
    indexed_counts.clear()
    flat_nodes.clear()
    for group_name in INDEXED_GROUPS:
        var grid: Dictionary = {}
        var nodes: Array[Node3D] = []
        var count := 0
        for candidate in get_tree().get_nodes_in_group(group_name):
            if not is_instance_valid(candidate) or not (candidate is Node3D):
                continue
            var node := candidate as Node3D
            if not node.visible:
                continue
            nodes.append(node)
            var cell := _cell_for(node.global_position)
            if not grid.has(cell):
                grid[cell] = []
            (grid[cell] as Array).append(node)
            count += 1
        grids[group_name] = grid
        flat_nodes[group_name] = nodes
        indexed_counts[group_name] = count


func indexed_nodes(group_name: StringName) -> Array[Node3D]:
    var value: Variant = flat_nodes.get(group_name, [])
    if value is Array:
        # Callers only inspect the current index. Returning the maintained
        # snapshot avoids copying the full population on every LOD evaluation.
        return value as Array[Node3D]
    return []


func query_radius(group_name: StringName, origin: Vector3, radius: float) -> Array[Node3D]:
    var result: Array[Node3D] = []
    var grid_value: Variant = grids.get(group_name, {})
    if not (grid_value is Dictionary):
        return result
    var grid := grid_value as Dictionary
    var cell_radius := ceili(maxf(0.0, radius) / cell_size)
    var center := _cell_for(origin)
    var radius_squared := radius * radius
    for x in range(center.x - cell_radius, center.x + cell_radius + 1):
        for y in range(center.y - cell_radius, center.y + cell_radius + 1):
            var cell := Vector2i(x, y)
            var bucket: Variant = grid.get(cell, [])
            if not (bucket is Array):
                continue
            for raw_node in bucket:
                if not is_instance_valid(raw_node) or not (raw_node is Node3D):
                    continue
                var node := raw_node as Node3D
                var offset := node.global_position - origin
                offset.y = 0.0
                if offset.length_squared() <= radius_squared:
                    result.append(node)
    return result


func nearest(
        group_name: StringName,
        origin: Vector3,
        radius: float,
        alive_method: StringName = &"is_alive"
    ) -> Node3D:
    var best: Node3D
    var best_distance_squared := radius * radius
    for node in query_radius(group_name, origin, radius):
        if alive_method != &"" and node.has_method(alive_method) and not bool(node.call(alive_method)):
            continue
        var offset := node.global_position - origin
        offset.y = 0.0
        var distance_squared := offset.length_squared()
        if distance_squared < best_distance_squared:
            best = node
            best_distance_squared = distance_squared
    return best


func count_in_radius(group_name: StringName, origin: Vector3, radius: float) -> int:
    return query_radius(group_name, origin, radius).size()


func total_indexed() -> int:
    var total := 0
    for count in indexed_counts.values():
        total += int(count)
    return total


func _cell_for(position: Vector3) -> Vector2i:
    return Vector2i(floori(position.x / cell_size), floori(position.z / cell_size))
