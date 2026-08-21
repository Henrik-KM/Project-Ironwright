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
var _status_light: OmniLight3D
var _visual_clock: float = 0.0


func _ready() -> void:
    add_to_group("salvage_piles")
    collision_layer = 1
    collision_mask = 1 | 2 | 4
    _build_visuals()


func _process(delta: float) -> void:
    _visual_clock += delta
    if _status_light != null and visible:
        _status_light.light_energy = 0.28 + sin(_visual_clock * 2.2) * 0.035


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
    var edge := ModelKit3D.material(Color("8e6a4b"), 0.42, 0.62)
    var glass := ModelKit3D.material(Color("526c6d"), 0.22, 0.2, Color("8ad9d0"), 0.32)
    var hazard := ModelKit3D.material(Color("b87238"), 0.18, 0.54, Color("d89042"), 0.9)
    var hub := ModelKit3D.material(Color("879493"), 0.74, 0.34)

    # The first salvage target is a close-range interaction landmark. Keep the
    # authoritative collision box above, but give the wreck a layered,
    # readable construction instead of a single block with two wheels.
    var detail_root := Node3D.new()
    detail_root.name = "HighDefinitionSalvageDetail"
    _model_root.add_child(detail_root)
    ModelKit3D.add_beveled_box(detail_root, Vector3(2.5, 0.58, 1.65), Vector3(0.0, 0.35, 0.0), iron, Vector3(0.08, 0.35, 0.18), "WreckBody", 0.18)
    ModelKit3D.add_cylinder(_model_root, 0.46, 0.34, Vector3(-0.82, 0.34, 0.66), dark, Vector3(1.5708, 0.0, 0.0), "WheelA")
    ModelKit3D.add_cylinder(_model_root, 0.46, 0.34, Vector3(0.82, 0.34, -0.66), dark, Vector3(1.5708, 0.0, 0.0), "WheelB")
    ModelKit3D.add_cylinder(detail_root, 0.18, 0.37, Vector3(-0.82, 0.34, 0.66), hub, Vector3(1.5708, 0.0, 0.0), "WheelHubA")
    ModelKit3D.add_cylinder(detail_root, 0.18, 0.37, Vector3(0.82, 0.34, -0.66), hub, Vector3(1.5708, 0.0, 0.0), "WheelHubB")
    for side in [-1.0, 1.0]:
        ModelKit3D.add_tapered_cylinder(detail_root, 0.06, 0.085, 2.08, Vector3(0.0, 0.68, side * 0.7), edge, Vector3(0.0, 0.0, PI * 0.5), "ChassisRail%02d" % int(side + 1.0))
    ModelKit3D.add_surface_panel(detail_root, Vector3(1.15, 0.38, 0.75), Vector3(0.25, 0.85, -0.1), rust, edge, Vector3(-0.22, -0.4, 0.08), "CollapsedPanel")
    ModelKit3D.add_surface_panel(detail_root, Vector3(0.82, 0.3, 0.08), Vector3(-0.94, 0.54, -0.42), dark, hazard, Vector3(0.08, 0.35, 0.0), "WreckServicePanel")
    for index in range(2):
        var axle_z := -0.56 if index == 0 else 0.56
        ModelKit3D.add_cylinder(detail_root, 0.065, 1.62, Vector3(0.0, 0.32, axle_z), edge, Vector3(1.5708, 0.0, 0.0), "SalvageAxle%02d" % index)
        for side in [-1.0, 1.0]:
            ModelKit3D.add_tapered_cylinder(detail_root, 0.055, 0.075, 0.62, Vector3(side * 0.66, 0.58, axle_z), rust, Vector3(0.0, 0.0, side * 0.28), "SalvageSuspension%02d" % index)
    for index in range(3):
        var cable_position := Vector3(-0.48 + float(index) * 0.16, 0.66 + float(index % 2) * 0.05, -0.72 + float(index % 2) * 0.08)
        ModelKit3D.add_tapered_cylinder(detail_root, 0.035, 0.052, 1.24 - float(index) * 0.12, cable_position, wire, Vector3(0.2 + float(index) * 0.05, 0.0, 1.08 - float(index) * 0.12), "SalvageCableBundle%02d" % index)
    for index in range(3):
        var shard_position := Vector3(-0.34 + float(index) * 0.34, 1.03 + float(index % 2) * 0.08, -0.18 + float(index % 2) * 0.16)
        ModelKit3D.add_beveled_box(detail_root, Vector3(0.34, 0.05, 0.16), shard_position, glass, Vector3(-0.2, 0.3 * float(index), 0.28), "BrokenGlassShard%02d" % index, 0.2)
    ModelKit3D.add_sphere(detail_root, 0.11, Vector3(-0.45, 0.72, -0.68), wire, Vector3.ONE, "SalvageStatusLens")
    _status_light = ModelKit3D.add_glow_light(detail_root, Vector3(-0.45, 0.72, -0.68), Color("5dc5cf"), 0.28, 2.4)
