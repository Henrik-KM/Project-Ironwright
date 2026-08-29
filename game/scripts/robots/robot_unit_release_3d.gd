class_name RobotUnitRelease3D
extends RobotUnit3D

const REDUCED_PROXY_MESH: BoxMesh = preload("res://assets/release/proxies/robot_proxy_mesh.tres")
const COARSE_TARGET_REFRESH_SECONDS := 0.44
const REDUCED_TARGET_REFRESH_SECONDS := 0.9

var _spatial_index: SpatialIndex3D
var visual_lod_level: int = 0
var reduced_detail: bool = false
var coarse_simulation: bool = false
var _cached_nearest_target: Node3D
var _nearest_target_refresh_remaining: float = 0.0
var _reduced_proxy: MeshInstance3D
var _runtime_shadow_enabled: bool = true


func _ready() -> void:
    super._ready()
    call_deferred("_resolve_spatial_index")


func _resolve_spatial_index() -> void:
    _spatial_index = get_tree().get_first_node_in_group(&"spatial_index_service") as SpatialIndex3D


func _nearest_enemy(maximum_range: float) -> Node3D:
    if reduced_detail or coarse_simulation:
        if _nearest_target_refresh_remaining > 0.0:
            if _cached_nearest_target == null or not is_instance_valid(_cached_nearest_target):
                return null
            if _cached_nearest_target.has_method(&"is_alive") and not bool(_cached_nearest_target.call(&"is_alive")):
                return null
            return _cached_nearest_target if global_position.distance_to(_cached_nearest_target.global_position) <= maximum_range else null
    if _spatial_index == null or not is_instance_valid(_spatial_index):
        _resolve_spatial_index()
    if _spatial_index == null:
        return super._nearest_enemy(maximum_range)
    var unit_target := _spatial_index.nearest(&"organic_enemies", global_position, maximum_range)
    var nest_target := _spatial_index.nearest(&"enemy_tier_nests", global_position, maximum_range)
    var result: Node3D
    if unit_target == null:
        result = nest_target
    elif nest_target == null:
        result = unit_target
    else:
        result = nest_target if global_position.distance_to(nest_target.global_position) < global_position.distance_to(unit_target.global_position) else unit_target
    if reduced_detail or coarse_simulation:
        _cached_nearest_target = result
        _nearest_target_refresh_remaining = REDUCED_TARGET_REFRESH_SECONDS if reduced_detail else COARSE_TARGET_REFRESH_SECONDS
    return result


func set_reduced_detail(value: bool) -> void:
    if reduced_detail == value:
        return
    reduced_detail = value
    coarse_simulation = false
    _cached_nearest_target = null
    _nearest_target_refresh_remaining = 0.0
    _update_release_collision()
    set_physics_process(not reduced_detail)
    if reduced_detail:
        velocity = Vector3.ZERO


func set_coarse_simulation(value: bool) -> void:
    if reduced_detail or coarse_simulation == value:
        return
    coarse_simulation = value
    _cached_nearest_target = null
    _nearest_target_refresh_remaining = 0.0
    _update_release_collision()
    set_physics_process(not coarse_simulation)


func reduced_detail_tick(delta: float) -> void:
    if not reduced_detail:
        return
    _coarse_detail_tick(delta)


func coarse_detail_tick(delta: float) -> void:
    if not coarse_simulation:
        return
    _coarse_detail_tick(delta)


func _coarse_detail_tick(delta: float) -> void:
    if not alive:
        return
    attack_cooldown = maxf(0.0, attack_cooldown - delta)
    _nearest_target_refresh_remaining = maxf(0.0, _nearest_target_refresh_remaining - delta)
    if archetype == &"companion" and player_reference != null and is_instance_valid(player_reference):
        _update_companion_goal()
    if salvage_target != null and is_instance_valid(salvage_target):
        _update_robot_salvage(delta)
    else:
        salvage_target = null
        salvage_progress = 0.0
    _update_attack()
    if current_target != null and archetype != &"scout":
        return
    if not has_goal:
        return
    var direction := goal_position - global_position
    direction.y = 0.0
    if direction.length_squared() <= 0.2:
        return
    direction = direction.normalized()
    var desired_speed := minf(move_speed, speed_cap)
    global_position += direction * desired_speed * delta
    rotation.y = atan2(direction.x, direction.z)


func set_visual_lod(level_value: int) -> void:
    var next_visual_lod := clampi(level_value, 0, 2)
    var unchanged := visual_lod_level == next_visual_lod
    visual_lod_level = next_visual_lod
    if unchanged:
        # The performance director evaluates the neighborhood repeatedly. Do
        # not re-walk every authored child when the actor remains in the same
        # detail band, but still repair deferred materialization if an active
        # actor has not built its shell yet.
        if _model_root == null:
            if visual_lod_level == 0:
                ensure_authored_visuals()
            else:
                _ensure_reduced_proxy()
                _reduced_proxy.visible = true
        return
    set_damage_presentation_enabled(visual_lod_level == 0)
    _sync_presentation_lod()
    if _model_root == null:
        if visual_lod_level == 0:
            ensure_authored_visuals()
        else:
            _ensure_reduced_proxy()
            _reduced_proxy.visible = true
            return
    if _model_root == null:
        return
    _ensure_reduced_proxy()
    var cast_mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if visual_lod_level == 0 and _runtime_shadow_enabled else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for child in _model_root.get_children():
        if child == _reduced_proxy:
            _reduced_proxy.visible = visual_lod_level >= 1
            continue
        if child is Node3D:
            child.visible = visual_lod_level < 1
    _set_model_shadow_casting(_model_root, cast_mode)


func set_runtime_shadow_enabled(enabled: bool) -> void:
    if _runtime_shadow_enabled == enabled:
        return
    _runtime_shadow_enabled = enabled
    if _model_root != null and is_instance_valid(_model_root):
        var cast_mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if enabled and visual_lod_level == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _set_model_shadow_casting(_model_root, cast_mode)


func _set_model_shadow_casting(node: Node, cast_mode: int) -> void:
    if node is GeometryInstance3D:
        (node as GeometryInstance3D).cast_shadow = cast_mode
    for child in node.get_children():
        _set_model_shadow_casting(child, cast_mode)


func _sync_presentation_lod() -> void:
    for child_name in [&"ProceduralAnimator3D", &"AuthoredActorAnimation3D", &"ReleaseSecondaryMotion3D"]:
        var controller := get_node_or_null(NodePath(String(child_name)))
        if controller != null and controller.has_method(&"set_presentation_lod"):
            controller.call(&"set_presentation_lod", visual_lod_level)


func _update_release_collision() -> void:
    if not alive:
        return
    var collision_enabled := not reduced_detail and not coarse_simulation
    collision_layer = 2 if collision_enabled else 0
    collision_mask = (1 | 2 | 4) if collision_enabled else 0
    for child in get_children():
        if child is CollisionShape3D:
            (child as CollisionShape3D).disabled = not collision_enabled


func _ensure_reduced_proxy() -> void:
    if _reduced_proxy != null and is_instance_valid(_reduced_proxy):
        return
    _reduced_proxy = MeshInstance3D.new()
    _reduced_proxy.name = "ReducedDetailProxy"
    _reduced_proxy.mesh = REDUCED_PROXY_MESH
    _reduced_proxy.position = Vector3(0.0, 0.78, 0.0)
    _reduced_proxy.visible = false
    var proxy_parent := _model_root if _model_root != null else _ensure_deferred_proxy_root()
    proxy_parent.add_child(_reduced_proxy)
