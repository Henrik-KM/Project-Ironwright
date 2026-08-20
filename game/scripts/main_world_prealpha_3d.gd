class_name IronwrightPreAlphaWorld3D
extends IronwrightCompleteGameWorld3D

## Presentation reset informed by the first full-game screenshot review. This
## layer does not pretend the current procedural art is production-ready; it
## fixes obvious prototype presentation failures while keeping the systemic
## game intact for further art production.

var _last_map_label_mode: bool = false


func _ready() -> void:
    super._ready()
    camera_height = 20.5
    camera_distance = 12.5
    if camera != null:
        camera.fov = 46.0
        camera.near = 0.35
    _set_region_map_emphasis(false)

    # The previous alpha boot message implied a level of finish that the actual
    # frame does not support. Make the build status explicit in-game as well as
    # in the production quality contract.
    if hud != null:
        hud.notifications.clear()
        hud.notification_ages.clear()
        hud._refresh_notifications()
        hud.push_notification("PRE-ALPHA SYSTEMIC BUILD · ART, ANIMATION, CAMERA AND PRESENTATION STILL IN PRODUCTION")
    run_state.log_event("Presentation status: pre-alpha production prototype. Systemic completeness does not imply release-ready art or feel.")


func _process(delta: float) -> void:
    super._process(delta)
    if map_mode != _last_map_label_mode:
        _last_map_label_mode = map_mode
        _set_region_map_emphasis(map_mode)


func _update_camera(delta: float) -> void:
    if camera == null or player == null:
        return

    if map_mode:
        var map_target := Vector3(0.0, 0.0, -8.0)
        if region_director != null and region_director.discovered_count() > 1:
            map_target = _discovered_region_centroid()
        var desired_map_position := map_target + Vector3(0.0, 82.0, 10.0)
        camera.global_position = camera.global_position.lerp(desired_map_position, 1.0 - exp(-delta * 4.2))
        camera.look_at(map_target, Vector3.FORWARD)
        return

    var target := player.global_position
    if follow_operation:
        var operation_target := _active_follow_target()
        if operation_target != null:
            target = operation_target.global_position
        else:
            follow_operation = false

    var desired := target + Vector3(0.0, camera_height, camera_distance)
    var resolved := _resolve_camera_occlusion(target, desired)
    camera.global_position = camera.global_position.lerp(resolved, 1.0 - exp(-delta * 7.2))
    camera.look_at(target + Vector3.UP * 0.72, Vector3.UP)


func _active_follow_target() -> Node3D:
    if long_operation_director != null and not long_operation_director.active_operation.is_empty():
        var long_target := long_operation_director.get_follow_target()
        if long_target != null:
            return long_target
    if outpost_director != null and not outpost_director.operation.is_empty():
        var outpost_target := outpost_director.get_follow_target()
        if outpost_target != null:
            return outpost_target
    if autonomy_director != null:
        return autonomy_director.get_follow_target()
    return null


func _resolve_camera_occlusion(target: Vector3, desired: Vector3) -> Vector3:
    var space_state := get_world_3d().direct_space_state
    var target_eye := target + Vector3.UP * 1.1
    var candidates: Array[Vector3] = [
        desired,
        target + Vector3(0.0, camera_height + 5.5, camera_distance * 0.72),
        target + Vector3(0.0, camera_height + 10.0, camera_distance * 0.48),
        target + Vector3(0.0, camera_height + 15.0, camera_distance * 0.22),
    ]

    var exclusions: Array[RID] = []
    if player is CollisionObject3D:
        exclusions.append((player as CollisionObject3D).get_rid())
    if heartforge is CollisionObject3D:
        exclusions.append((heartforge as CollisionObject3D).get_rid())

    var last_hit: Dictionary = {}
    for candidate in candidates:
        var query := PhysicsRayQueryParameters3D.create(target_eye, candidate)
        query.collision_mask = 1
        query.collide_with_areas = false
        query.collide_with_bodies = true
        query.exclude = exclusions
        var hit := space_state.intersect_ray(query)
        if hit.is_empty():
            return candidate
        last_hit = hit

    if not last_hit.is_empty():
        var collision_position: Vector3 = last_hit.get("position", desired)
        var direction := (collision_position - target_eye).normalized()
        var safe_distance := maxf(5.0, target_eye.distance_to(collision_position) - 1.0)
        return target_eye + direction * safe_distance
    return desired


func _set_region_map_emphasis(value: bool) -> void:
    for node in get_tree().get_nodes_in_group(&"world_regions"):
        if is_instance_valid(node) and node.has_method(&"set_map_emphasis"):
            node.call(&"set_map_emphasis", value)


func _discovered_region_centroid() -> Vector3:
    if region_director == null:
        return Vector3.ZERO
    var regions := region_director.discovered_regions()
    if regions.is_empty():
        return Vector3.ZERO
    var total := Vector3.ZERO
    var count := 0
    for data in regions:
        var region_id := StringName(str(data.get("id", "")))
        total += region_director.center(region_id)
        count += 1
    return total / float(maxi(1, count))
