class_name MechromancerRelease3D
extends Mechromancer3D

var _spatial_index: SpatialIndex3D
var _settings_service: ReleaseSettingsService3D


func _ready() -> void:
    super._ready()
    call_deferred("_resolve_release_services")


func _resolve_release_services() -> void:
    _spatial_index = get_tree().get_first_node_in_group(&"spatial_index_service") as SpatialIndex3D
    _settings_service = get_tree().get_first_node_in_group(&"release_settings_service") as ReleaseSettingsService3D


func _update_movement(delta: float) -> void:
    var input_vector := Vector2.ZERO
    if input_enabled:
        if (
            InputMap.has_action(&"iw_move_left")
            and InputMap.has_action(&"iw_move_right")
            and InputMap.has_action(&"iw_move_up")
            and InputMap.has_action(&"iw_move_down")
        ):
            input_vector = Input.get_vector(&"iw_move_left", &"iw_move_right", &"iw_move_up", &"iw_move_down")
        else:
            input_vector = Vector2(
                float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
                float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
            )
    input_vector = input_vector.normalized()

    var target_velocity := Vector3(input_vector.x, 0.0, input_vector.y) * move_speed
    velocity.x = move_toward(velocity.x, target_velocity.x, 28.0 * delta)
    velocity.z = move_toward(velocity.z, target_velocity.z, 28.0 * delta)
    velocity.y = -0.8
    move_and_slide()

    if input_vector.length_squared() > 0.01 and current_target == null:
        rotation.y = lerp_angle(rotation.y, atan2(input_vector.x, input_vector.y), 0.18)


func _nearest_enemy_in_range(maximum_range: float) -> Node3D:
    if _spatial_index == null or not is_instance_valid(_spatial_index):
        _spatial_index = get_tree().get_first_node_in_group(&"spatial_index_service") as SpatialIndex3D
    if _spatial_index == null:
        return super._nearest_enemy_in_range(maximum_range)
    var unit_target := _spatial_index.nearest(&"organic_enemies", global_position, maximum_range)
    var nest_target := _spatial_index.nearest(&"enemy_tier_nests", global_position, maximum_range)
    if unit_target == null:
        return nest_target
    if nest_target == null:
        return unit_target
    return nest_target if global_position.distance_to(nest_target.global_position) < global_position.distance_to(unit_target.global_position) else unit_target


func _update_channel(delta: float) -> void:
    var hold_required := channel_requires_hold
    if _settings_service == null or not is_instance_valid(_settings_service):
        _settings_service = get_tree().get_first_node_in_group(&"release_settings_service") as ReleaseSettingsService3D
    if _settings_service != null:
        hold_required = hold_required and bool(_settings_service.get_value(&"hold_interactions", true))
    var interact_pressed := Input.is_action_pressed(&"iw_interact") if InputMap.has_action(&"iw_interact") else Input.is_key_pressed(KEY_E)
    if hold_required and not interact_pressed:
        cancel_channel()
        return
    if channel_target != null and not is_instance_valid(channel_target):
        cancel_channel()
        return

    channel_elapsed += delta
    channel_noise_clock += delta
    if channel_noise_radius > 0.0 and channel_noise_clock >= channel_noise_interval:
        channel_noise_clock = 0.0
        noise_requested.emit(global_position, channel_noise_radius, channel_noise_intensity, channel_kind)

    var progress := clampf(channel_elapsed / channel_duration, 0.0, 1.0)
    channel_progress.emit(channel_kind, progress, channel_description)
    if channel_elapsed < channel_duration:
        return

    var finished_kind := channel_kind
    var finished_target := channel_target
    var finished_metadata := channel_metadata.duplicate(true)
    _clear_channel()
    channel_completed.emit(finished_kind, finished_target, finished_metadata)


func apply_damage(amount: float, source: Node = null) -> void:
    var before := current_health
    super.apply_damage(amount, source)
    if current_health >= before:
        return
    if _settings_service == null or not is_instance_valid(_settings_service):
        _settings_service = get_tree().get_first_node_in_group(&"release_settings_service") as ReleaseSettingsService3D
    if _settings_service == null or not bool(_settings_service.get_value(&"controller_vibration", true)):
        return
    var severity := clampf((before - current_health) / maxf(1.0, maximum_health), 0.0, 1.0)
    for device_id in Input.get_connected_joypads():
        Input.start_joy_vibration(device_id, 0.18 + severity * 0.32, 0.32 + severity * 0.58, 0.12 + severity * 0.2)
