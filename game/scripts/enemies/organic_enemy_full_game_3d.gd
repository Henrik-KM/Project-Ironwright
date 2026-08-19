class_name OrganicEnemyFullGame3D
extends OrganicEnemy3D


func _choose_target() -> Node3D:
    var best := super._choose_target()
    var best_distance := detection_range + aggression * 11.0
    if best != null:
        best_distance = global_position.distance_to(best.global_position)

    for outpost in get_tree().get_nodes_in_group(&"outposts"):
        if not is_instance_valid(outpost) or not (outpost is Node3D):
            continue
        if outpost.has_method("is_alive") and not bool(outpost.call("is_alive")):
            continue
        var outpost_distance := global_position.distance_to(outpost.global_position)
        var attraction_range := detection_range + 3.0 + aggression * 14.0
        if outpost_distance <= attraction_range and outpost_distance < best_distance:
            best = outpost
            best_distance = outpost_distance
    return best
