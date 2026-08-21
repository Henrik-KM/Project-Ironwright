class_name Heartforge3D
extends StaticBody3D

signal health_changed(current: float, maximum: float)
signal destroyed

@export var maximum_health: float = 520.0
var current_health: float = 520.0
var interaction_radius: float = 4.1
var active_operation: StringName = &""
var progression_tier: int = 1
var _core_light: OmniLight3D
var _model_root: Node3D
var _adaptive_geometry: Node3D


func _ready() -> void:
    add_to_group("heartforge")
    collision_layer = 1
    collision_mask = 4
    current_health = maximum_health
    _build_visuals()
    set_progression_tier(progression_tier)
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
        _core_light.light_energy = 5.6 if kind != &"" else 3.6


func set_progression_tier(next_tier: int) -> void:
    var clamped := clampi(next_tier, 1, 5)
    if progression_tier == clamped and _adaptive_geometry != null and not _adaptive_geometry.get_children().is_empty():
        return
    progression_tier = clamped
    if _model_root == null:
        return
    if _adaptive_geometry == null:
        _adaptive_geometry = Node3D.new()
        _adaptive_geometry.name = "AdaptiveHeartforgeGeometry"
        _model_root.add_child(_adaptive_geometry)
    for child in _adaptive_geometry.get_children():
        child.free()
    _build_adaptive_geometry(progression_tier)


func _build_visuals() -> void:
    ModelKit3D.add_collision_box(self, Vector3(5.4, 3.6, 5.4), Vector3(0.0, 1.8, 0.0))
    _model_root = Node3D.new()
    _model_root.name = "HeartforgeModel"
    add_child(_model_root)

    var iron := ModelKit3D.material(Color("2c3132"), 0.82, 0.42)
    var dark := ModelKit3D.material(Color("161b1c"), 0.72, 0.55)
    var rust := ModelKit3D.material(Color("6d432b"), 0.48, 0.72)
    var heat := ModelKit3D.material(Color("9e4f18"), 0.25, 0.38, Color("ff6d21"), 4.8)
    # Cyan service surfaces should read as powered hardware without blooming
    # into a flat white card in the tactical frame.
    var cyan := ModelKit3D.material(Color("214b50"), 0.42, 0.36, Color("42b8c0"), 0.34)
    var cladding := ModelKit3D.material(Color("3d484a"), 0.78, 0.36)
    var cladding_edge := ModelKit3D.material(Color("7b4c31"), 0.54, 0.62)
    var core_signal := ModelKit3D.material(Color("24565a"), 0.44, 0.3, Color("6fdfe4"), 1.6)

    ModelKit3D.add_cylinder(_model_root, 2.55, 0.7, Vector3(0.0, 0.35, 0.0), dark, Vector3.ZERO, "Foundation")
    ModelKit3D.add_cylinder(_model_root, 1.75, 3.4, Vector3(0.0, 2.0, 0.0), iron, Vector3.ZERO, "CoreHousing")
    ModelKit3D.add_cylinder(_model_root, 1.1, 2.5, Vector3(0.0, 2.0, 0.0), heat, Vector3.ZERO, "FurnaceCore")
    ModelKit3D.add_cylinder(_model_root, 2.15, 0.22, Vector3(0.0, 1.0, 0.0), rust, Vector3.ZERO, "LowerRing")
    ModelKit3D.add_cylinder(_model_root, 2.08, 0.22, Vector3(0.0, 2.9, 0.0), rust, Vector3.ZERO, "UpperRing")

    var cladding_detail := Node3D.new()
    cladding_detail.name = "CoreCladdingDetail"
    _model_root.add_child(cladding_detail)
    for segment in range(8):
        var angle := TAU * float(segment) / 8.0 + PI * 0.125
        var cladding_position := Vector3(cos(angle) * 1.7, 2.0, sin(angle) * 1.7)
        ModelKit3D.add_beveled_box(
            cladding_detail,
            Vector3(0.34, 2.42, 0.62),
            cladding_position,
            cladding,
            Vector3(0.0, -angle, 0.0),
            "CoreCladdingSegment",
            0.18
        )
        ModelKit3D.add_beveled_box(
            cladding_detail,
            Vector3(0.38, 0.12, 0.68),
            cladding_position + Vector3.UP * 1.08,
            cladding_edge,
            Vector3(0.0, -angle, 0.0),
            "CoreCladdingCap",
            0.2
        )
    ModelKit3D.add_louvered_panel(
        cladding_detail,
        Vector3(0.72, 0.92, 0.1),
        Vector3(0.0, 2.12, 1.84),
        dark,
        core_signal,
        Vector3.ZERO,
        "CoreServiceLouver",
        4
    )
    ModelKit3D.add_surface_panel(
        cladding_detail,
        Vector3(0.56, 0.64, 0.1),
        Vector3(0.0, 1.12, 1.88),
        dark,
        core_signal,
        Vector3.ZERO,
        "CoreInspectionPort"
    )
    for side in [-1.0, 1.0]:
        ModelKit3D.add_cylinder(
            cladding_detail,
            0.08,
            1.8,
            Vector3(side * 1.86, 2.05, 0.0),
            core_signal,
            Vector3.ZERO,
            "CoreSignalRail"
        )
    ModelKit3D.add_cylinder(_model_root, 0.36, 2.6, Vector3(-1.85, 1.7, 0.0), iron, Vector3.ZERO, "WestStack")
    ModelKit3D.add_cylinder(_model_root, 0.36, 2.6, Vector3(1.85, 1.7, 0.0), iron, Vector3.ZERO, "EastStack")
    ModelKit3D.add_box(_model_root, Vector3(3.0, 0.35, 1.8), Vector3(0.0, 0.48, 3.25), iron, Vector3.ZERO, "ForgeBench")
    ModelKit3D.add_beveled_box(_model_root, Vector3(2.18, 0.18, 1.06), Vector3(0.0, 0.72, 3.25), dark, Vector3.ZERO, "AssemblyPlate", 0.18)
    ModelKit3D.add_beveled_box(_model_root, Vector3(1.68, 0.06, 0.72), Vector3(0.0, 0.84, 3.25), cyan, Vector3.ZERO, "AssemblyPlateGlow", 0.18)
    for slot in range(3):
        ModelKit3D.add_box(_model_root, Vector3(0.1, 0.025, 0.42), Vector3(-0.48 + float(slot) * 0.48, 0.88, 3.25), dark, Vector3.ZERO, "AssemblyPlateSlot")

    for angle_index in range(8):
        var angle := TAU * float(angle_index) / 8.0
        var position := Vector3(cos(angle) * 2.35, 1.75, sin(angle) * 2.35)
        ModelKit3D.add_box(_model_root, Vector3(0.24, 2.1, 0.42), position, rust, Vector3(0.0, -angle, 0.0), "Rib")

    # The core remains the warm focal source, but its ground influence is
    # bounded so the Heartforge does not flatten the surrounding paving.
    _core_light = ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 2.1, 0.0), Color("ff7d32"), 3.6, 16.0)
    ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 1.2, 3.15), Color("62e1e7"), 1.4, 7.0)


func _build_adaptive_geometry(tier: int) -> void:
    var iron := ModelKit3D.material(Color("394143"), 0.78, 0.42)
    var dark := ModelKit3D.material(Color("1b2425"), 0.74, 0.5)
    var rust := ModelKit3D.material(Color("805034"), 0.42, 0.72)
    var heat := ModelKit3D.material(Color("9e4f18"), 0.24, 0.42, Color("ff7b2f"), 3.4)
    var cyan := ModelKit3D.material(Color("28595c"), 0.38, 0.34, Color("70e9ee"), 2.5)

    if tier >= 2:
        for side in [-1.0, 1.0]:
            for depth in [-1.0, 1.0]:
                var base_position := Vector3(side * 2.18, 1.16, depth * 1.34)
                ModelKit3D.add_beveled_box(_adaptive_geometry, Vector3(0.46, 1.72, 0.72), base_position, iron, Vector3(0.0, side * 0.12, depth * 0.08), "Tier2Buttress", 0.1)
                ModelKit3D.add_cylinder(_adaptive_geometry, 0.09, 1.45, base_position + Vector3(0.0, 0.18, -depth * 0.34), rust, Vector3.ZERO, "Tier2ServiceColumn")

    if tier >= 3:
        for side in [-1.0, 1.0]:
            var conduit_position := Vector3(side * 2.48, 1.62, 0.0)
            ModelKit3D.add_cylinder(_adaptive_geometry, 0.12, 2.8, conduit_position, cyan, Vector3.ZERO, "Tier3SignalConduit")
            ModelKit3D.add_box(_adaptive_geometry, Vector3(0.34, 0.7, 0.56), Vector3(side * 2.48, 2.6, 0.0), dark, Vector3.ZERO, "Tier3RelayHousing")
        ModelKit3D.add_cylinder(_adaptive_geometry, 2.42, 0.12, Vector3(0.0, 3.3, 0.0), heat, Vector3.ZERO, "Tier3HeatRing")

    if tier >= 4:
        for side in [-1.0, 1.0]:
            ModelKit3D.add_cylinder(_adaptive_geometry, 0.13, 4.7, Vector3(side * 2.72, 2.45, 0.0), iron, Vector3.ZERO, "Tier4SignalMast")
            ModelKit3D.add_box(_adaptive_geometry, Vector3(0.24, 0.18, 3.8), Vector3(side * 2.72, 3.0, 0.0), rust, Vector3.ZERO, "Tier4MastBrace")
        ModelKit3D.add_beveled_box(_adaptive_geometry, Vector3(5.7, 0.28, 0.34), Vector3(0.0, 4.4, 0.0), iron, Vector3.ZERO, "Tier4SignalCrossbar", 0.08)

    if tier >= 5:
        ModelKit3D.add_cylinder(_adaptive_geometry, 2.9, 0.18, Vector3(0.0, 4.72, 0.0), heat, Vector3.ZERO, "Tier5SovereigntyCrown")
        for angle_index in range(8):
            var angle := TAU * float(angle_index) / 8.0
            var crown_position := Vector3(cos(angle) * 2.72, 4.9, sin(angle) * 2.72)
            ModelKit3D.add_beveled_box(_adaptive_geometry, Vector3(0.24, 0.78, 0.52), crown_position, cyan, Vector3(0.0, -angle, 0.0), "Tier5CrownFin", 0.08)
        ModelKit3D.add_cylinder(_adaptive_geometry, 0.34, 1.15, Vector3(0.0, 5.15, 0.0), heat, Vector3.ZERO, "Tier5CrownBeacon")
