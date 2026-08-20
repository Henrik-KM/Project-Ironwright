class_name RobotUnitRelease3D
extends RobotUnit3D

var _spatial_index: SpatialIndex3D
var visual_lod_level: int = 0


func _ready() -> void:
    super._ready()
    call_deferred("_resolve_spatial_index")


func _resolve_spatial_index() -> void:
    _spatial_index = get_tree().get_first_node_in_group(&"spatial_index_service") as SpatialIndex3D


func _nearest_enemy(maximum_range: float) -> Node3D:
    if _spatial_index == null or not is_instance_valid(_spatial_index):
        _resolve_spatial_index()
    if _spatial_index != null:
        return _spatial_index.nearest(&"organic_enemies", global_position, maximum_range)
    return super._nearest_enemy(maximum_range)


func set_visual_lod(level_value: int) -> void:
    visual_lod_level = clampi(level_value, 0, 2)
    if _model_root == null:
        return
    var cast_mode := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if visual_lod_level == 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    for child in _model_root.get_children():
        if child is GeometryInstance3D:
            (child as GeometryInstance3D).cast_shadow = cast_mode
        if visual_lod_level >= 2 and (child.name in [&"ArmorPlate", &"CargoBin", &"Antenna", &"MaterialCradle", &"WelderGlow"] or child.name.begins_with("Tier2") or child.name.begins_with("Tier3")):
            child.visible = false
        elif child is Node3D:
            child.visible = true
