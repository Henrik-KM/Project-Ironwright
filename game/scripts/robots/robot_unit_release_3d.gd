class_name RobotUnitRelease3D
extends RobotUnit3D

const REDUCED_PROXY_MESH: BoxMesh = preload("res://assets/release/proxies/robot_proxy_mesh.tres")

var _spatial_index: SpatialIndex3D
var visual_lod_level: int = 0
var reduced_detail: bool = false
var coarse_simulation: bool = false
var _reduced_proxy: MeshInstance3D


func _ready() -> void:
    super._ready()
    call_deferred("_resolve_spatial_index")


func _resolve_spatial_index() -> void:
    _spatial_index = get_tree().get_first_node_in_group(&"spatial_index_service") as SpatialIndex3D


func _nearest_enemy(maximum_range: float) -> Node3D:
    if _spatial_index == null or not is_instance_valid(_spatial_index):
        _resolve_spatial_index()
    if _spatial_index == null:
        return super._nearest_enemy(maximum_range)
    var unit_target := _spatial_index.nearest(&"organic_enemies", global_position, maximum_range)
    var nest_target := _spatial_index.nearest(&"enemy_tier_nests", global_position, maximum_range)
    if unit_target == null:
        return nest_target
    if nest_target == null:
        return unit_target
    return nest_target if global_position.distance_to(nest_target.global_position) < global_position.distance_to(unit_target.global_position) else unit_target


func set_reduced_detail(value: bool) -> void:
    if reduced_detail == value:
        return
    reduced_detail = value
    coarse_simulation = false
    set_physics_process(not reduced_detail)
    if reduced_detail:
        velocity = Vector3.ZERO


func set_coarse_simulation(value: bool) -> void:
    if reduced_detail or coarse_simulation == value:
        return
    coarse_simulation = value
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
    visual_lod_level = clampi(level_value, 0, 2)
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
    var cast_mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if visual_lod_level == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for child in _model_root.get_children():
        if child == _reduced_proxy:
            _reduced_proxy.visible = visual_lod_level >= 1
            continue
        if child is Node3D:
            child.visible = visual_lod_level < 1
        if child is GeometryInstance3D:
            (child as GeometryInstance3D).cast_shadow = cast_mode


func _sync_presentation_lod() -> void:
    for child_name in [&"ProceduralAnimator3D", &"AuthoredActorAnimation3D", &"ReleaseSecondaryMotion3D"]:
        var controller := get_node_or_null(NodePath(String(child_name)))
        if controller != null and controller.has_method(&"set_presentation_lod"):
            controller.call(&"set_presentation_lod", visual_lod_level)


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
