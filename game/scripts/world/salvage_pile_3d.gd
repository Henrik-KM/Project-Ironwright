class_name SalvagePile3D
extends StaticBody3D

signal depleted(pile: SalvagePile3D)
signal amount_changed(pile: SalvagePile3D, remaining: int)

@export var remaining_scrap: int = 56
@export var manual_channel_seconds: float = 4.4
@export var noise_radius: float = 25.0
@export var noise_intensity: float = 1.0
@export var display_name: String = "Collapsed machinery"

var reserved_by_group: StringName = &""
var _model_root: Node3D


func _ready() -> void:
    add_to_group("salvage_piles")
    collision_layer = 1
    collision_mask = 1 | 2 | 4
    _build_visuals()


func extract_manual() -> int:
    return _extract(mini(remaining_scrap, 24))


func extract_for_robot(requested: int) -> int:
    return _extract(mini(remaining_scrap, maxi(0, requested)))


func _extract(amount: int) -> int:
    if amount <= 0 or remaining_scrap <= 0:
        return 0
    var recovered := mini(amount, remaining_scrap)
    remaining_scrap -= recovered
    amount_changed.emit(self, remaining_scrap)
    if remaining_scrap <= 0:
        depleted.emit(self)
        visible = false
        collision_layer = 0
    else:
        scale = Vector3.ONE * clampf(0.45 + float(remaining_scrap) / 95.0, 0.55, 1.1)
    return recovered


func has_scrap() -> bool:
    return remaining_scrap > 0


func reserve(group_id: StringName) -> bool:
    if reserved_by_group != &"" and reserved_by_group != group_id:
        return false
    reserved_by_group = group_id
    return true


func release_reservation(group_id: StringName) -> void:
    if reserved_by_group == group_id:
        reserved_by_group = &""


func _build_visuals() -> void:
    ModelKit3D.add_collision_box(self, Vector3(2.8, 1.0, 2.2), Vector3(0.0, 0.5, 0.0))
    _model_root = Node3D.new()
    _model_root.name = "SalvageModel"
    add_child(_model_root)

    var iron := ModelKit3D.material(Color("3d4240"), 0.68, 0.48)
    var rust := ModelKit3D.material(Color("77472c"), 0.35, 0.8)
    var dark := ModelKit3D.material(Color("1b2021"), 0.75, 0.5)
    var wire := ModelKit3D.material(Color("2f5b61"), 0.4, 0.44, Color("5dc5cf"), 0.75)

    ModelKit3D.add_box(_model_root, Vector3(2.5, 0.58, 1.65), Vector3(0.0, 0.35, 0.0), iron, Vector3(0.08, 0.35, 0.18), "WreckBody")
    ModelKit3D.add_cylinder(_model_root, 0.46, 0.34, Vector3(-0.82, 0.34, 0.66), dark, Vector3(1.5708, 0.0, 0.0), "WheelA")
    ModelKit3D.add_cylinder(_model_root, 0.46, 0.34, Vector3(0.82, 0.34, -0.66), dark, Vector3(1.5708, 0.0, 0.0), "WheelB")
    ModelKit3D.add_box(_model_root, Vector3(1.15, 0.38, 0.75), Vector3(0.25, 0.85, -0.1), rust, Vector3(-0.22, -0.4, 0.08), "CollapsedPanel")
    ModelKit3D.add_cylinder(_model_root, 0.08, 1.3, Vector3(-0.45, 0.65, -0.68), wire, Vector3(0.2, 0.0, 1.1), "LiveCable")
    ModelKit3D.add_glow_light(_model_root, Vector3(-0.45, 0.72, -0.68), Color("5dc5cf"), 0.35, 2.4)
