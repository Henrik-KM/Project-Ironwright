class_name Heartforge3D
extends StaticBody3D

signal health_changed(current: float, maximum: float)
signal destroyed

@export var maximum_health: float = 520.0
var current_health: float = 520.0
var interaction_radius: float = 4.1
var active_operation: StringName = &""
var _core_light: OmniLight3D
var _model_root: Node3D


func _ready() -> void:
    add_to_group("heartforge")
    collision_layer = 1
    collision_mask = 4
    current_health = maximum_health
    _build_visuals()
    health_changed.emit(current_health, maximum_health)


func apply_damage(amount: float, source: Node = null) -> void:
    if amount <= 0.0 or current_health <= 0.0:
        return
    current_health = maxf(0.0, current_health - amount)
    health_changed.emit(current_health, maximum_health)
    if current_health <= 0.0:
        destroyed.emit()


func repair(amount: float) -> void:
    if current_health <= 0.0:
        return
    current_health = minf(maximum_health, current_health + maxf(0.0, amount))
    health_changed.emit(current_health, maximum_health)


func is_alive() -> bool:
    return current_health > 0.0


func set_operation(kind: StringName) -> void:
    active_operation = kind
    if _core_light != null:
        _core_light.light_energy = 7.0 if kind != &"" else 4.4


func _build_visuals() -> void:
    ModelKit3D.add_collision_box(self, Vector3(5.4, 3.6, 5.4), Vector3(0.0, 1.8, 0.0))
    _model_root = Node3D.new()
    _model_root.name = "HeartforgeModel"
    add_child(_model_root)

    var iron := ModelKit3D.material(Color("2c3132"), 0.82, 0.42)
    var dark := ModelKit3D.material(Color("161b1c"), 0.72, 0.55)
    var rust := ModelKit3D.material(Color("6d432b"), 0.48, 0.72)
    var heat := ModelKit3D.material(Color("9e4f18"), 0.25, 0.38, Color("ff6d21"), 4.8)
    var cyan := ModelKit3D.material(Color("29585c"), 0.42, 0.36, Color("62e1e7"), 2.2)

    ModelKit3D.add_cylinder(_model_root, 2.55, 0.7, Vector3(0.0, 0.35, 0.0), dark, Vector3.ZERO, "Foundation")
    ModelKit3D.add_cylinder(_model_root, 1.75, 3.4, Vector3(0.0, 2.0, 0.0), iron, Vector3.ZERO, "CoreHousing")
    ModelKit3D.add_cylinder(_model_root, 1.1, 2.5, Vector3(0.0, 2.0, 0.0), heat, Vector3.ZERO, "FurnaceCore")
    ModelKit3D.add_cylinder(_model_root, 2.15, 0.22, Vector3(0.0, 1.0, 0.0), rust, Vector3.ZERO, "LowerRing")
    ModelKit3D.add_cylinder(_model_root, 2.08, 0.22, Vector3(0.0, 2.9, 0.0), rust, Vector3.ZERO, "UpperRing")
    ModelKit3D.add_cylinder(_model_root, 0.36, 2.6, Vector3(-1.85, 1.7, 0.0), iron, Vector3.ZERO, "WestStack")
    ModelKit3D.add_cylinder(_model_root, 0.36, 2.6, Vector3(1.85, 1.7, 0.0), iron, Vector3.ZERO, "EastStack")
    ModelKit3D.add_box(_model_root, Vector3(3.0, 0.35, 1.8), Vector3(0.0, 0.48, 3.25), iron, Vector3.ZERO, "ForgeBench")
    ModelKit3D.add_box(_model_root, Vector3(2.2, 0.18, 1.1), Vector3(0.0, 0.72, 3.25), cyan, Vector3.ZERO, "AssemblyPlate")

    for angle_index in range(8):
        var angle := TAU * float(angle_index) / 8.0
        var position := Vector3(cos(angle) * 2.35, 1.75, sin(angle) * 2.35)
        ModelKit3D.add_box(_model_root, Vector3(0.24, 2.1, 0.42), position, rust, Vector3(0.0, -angle, 0.0), "Rib")

    _core_light = ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 2.1, 0.0), Color("ff7d32"), 4.4, 19.0)
    ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 1.2, 3.15), Color("62e1e7"), 1.4, 7.0)
