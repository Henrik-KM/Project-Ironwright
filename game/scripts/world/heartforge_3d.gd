class_name Heartforge3D
extends StaticBody3D

signal health_changed(current: float, maximum: float)
signal destroyed

const AUTHORED_HEARTFORGE_MODEL_SCENE: PackedScene = preload("res://assets/heartforge/heartforge.gltf")
const RESTING_CORE_LIGHT_ENERGY: float = 1.8
const ACTIVE_CORE_LIGHT_ENERGY: float = 2.8

@export var maximum_health: float = 520.0
var current_health: float = 520.0
var interaction_radius: float = 4.1
var active_operation: StringName = &""
var progression_tier: int = 1
var adaptation_profile: StringName = &""
var incoming_damage_multiplier: float = 1.0
var _core_light: OmniLight3D
var _model_root: Node3D
var _adaptive_geometry: Node3D
var _adaptation_detail: Node3D
var _damage_visual_root: Node3D
var _damage_signal_material: StandardMaterial3D


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
    current_health = maxf(0.0, current_health - amount * incoming_damage_multiplier)
    _refresh_damage_presentation()
    health_changed.emit(current_health, maximum_health)
    if current_health <= 0.0:
        destroyed.emit()


func repair(amount: float) -> void:
    if current_health <= 0.0:
        return
    current_health = minf(maximum_health, current_health + maxf(0.0, amount))
    _refresh_damage_presentation()
    health_changed.emit(current_health, maximum_health)


func is_alive() -> bool:
    return current_health > 0.0


func set_operation(kind: StringName) -> void:
    active_operation = kind
    if _core_light != null:
        _core_light.light_energy = ACTIVE_CORE_LIGHT_ENERGY if kind != &"" else RESTING_CORE_LIGHT_ENERGY


func set_adaptation_profile(next_profile: StringName) -> void:
    adaptation_profile = next_profile
    match next_profile:
        &"adaptation.anchored_shell":
            incoming_damage_multiplier = 0.74
        &"adaptation.sacrificial_hollow":
            incoming_damage_multiplier = 0.86
        &"adaptation.quiet_core":
            incoming_damage_multiplier = 0.93
        _:
            incoming_damage_multiplier = 1.0
    if _model_root == null:
        return
    if _adaptation_detail != null:
        _adaptation_detail.free()
    _adaptation_detail = Node3D.new()
    _adaptation_detail.name = "HeartforgeAdaptationDetail"
    _model_root.add_child(_adaptation_detail)
    _build_adaptation_detail(next_profile)


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

    # A compact reactor/control layer gives the Heartforge a readable
    # manufactured focal face at tactical distance. It is presentation-only:
    # the existing collision box, interaction radius and progression state
    # remain the sole gameplay contract for this machine.
    var focal_detail := Node3D.new()
    focal_detail.name = "HeartforgeFocalDetail"
    _model_root.add_child(focal_detail)
    var collar_mesh := TorusMesh.new()
    collar_mesh.inner_radius = 1.28
    collar_mesh.outer_radius = 1.48
    collar_mesh.rings = 18
    collar_mesh.ring_segments = 48
    var collar := MeshInstance3D.new()
    collar.name = "HeartforgeUpperCollar"
    collar.mesh = collar_mesh
    collar.material_override = cladding_edge
    collar.position = Vector3(0.0, 3.78, 0.0)
    focal_detail.add_child(collar)
    for index in range(8):
        var angle := TAU * float(index) / 8.0 + PI * 0.125
        var fin_position := Vector3(cos(angle) * 1.45, 3.78, sin(angle) * 1.45)
        ModelKit3D.add_beveled_box(
            focal_detail,
            Vector3(0.16, 0.58, 0.34),
            fin_position,
            iron,
            Vector3(0.0, -angle, 0.0),
            "HeartforgeFocalRadialFin%02d" % index,
            0.16
        )
    ModelKit3D.add_louvered_panel(
        focal_detail,
        Vector3(1.22, 0.68, 0.12),
        Vector3(0.0, 2.7, 1.92),
        dark,
        core_signal,
        Vector3.ZERO,
        "HeartforgeFocalControlFace",
        5
    )
    for index in range(3):
        var lens_material := heat if index == 1 else cyan
        ModelKit3D.add_sphere(
            focal_detail,
            0.075,
            Vector3(-0.34 + float(index) * 0.34, 2.73, 2.01),
            lens_material,
            Vector3(1.0, 0.68, 0.42),
            "HeartforgeFocalSignalLens%02d" % index
        )
    for side in [-1.0, 1.0]:
        ModelKit3D.add_cylinder(
            focal_detail,
            0.055,
            1.1,
            Vector3(side * 1.26, 2.66, 1.88),
            rust,
            Vector3(0.0, 0.0, PI * 0.5),
            "HeartforgeFocalCableBranch"
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

    # The permanent Heartforge shell is source-authored. Keep the former
    # named procedural socket set hidden as a migration-compatible contract;
    # adaptive tiers, retrofits, damage, lights and the interaction surface
    # remain runtime-owned around the imported production asset.
    var authored_model := AUTHORED_HEARTFORGE_MODEL_SCENE.instantiate()
    authored_model.name = "HeartforgeAuthoredModel"
    _model_root.add_child(authored_model)
    _retune_authored_materials(authored_model)
    var legacy_shell := Node3D.new()
    legacy_shell.name = "LegacyProceduralHeartforgeShell"
    for child in _model_root.get_children():
        if child == authored_model or child == legacy_shell:
            continue
        child.reparent(legacy_shell)
    _model_root.add_child(legacy_shell)
    legacy_shell.visible = false

    # The core remains the warm focal source, but its ground influence is
    # bounded so the Heartforge does not flatten the surrounding paving.
    _core_light = ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 2.1, 0.0), Color("ff7d32"), RESTING_CORE_LIGHT_ENERGY, 13.0)
    ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 1.2, 3.15), Color("62e1e7"), 0.9, 6.0)

    _damage_visual_root = Node3D.new()
    _damage_visual_root.name = "HeartforgeDamagePresentation"
    _model_root.add_child(_damage_visual_root)
    _damage_signal_material = ModelKit3D.material(Color("551c26"), 0.04, 0.44, Color("e74352"), 0.7)
    var scar_edge := ModelKit3D.material(Color("a55a39"), 0.18, 0.62)
    for index in range(3):
        var angle := -0.72 + float(index) * 0.74
        var position := Vector3(sin(angle) * 1.78, 1.22 + float(index % 2) * 0.82, cos(angle) * 1.78)
        ModelKit3D.add_beveled_box(
            _damage_visual_root,
            Vector3(0.08, 0.72 + float(index) * 0.12, 0.18),
            position,
            _damage_signal_material,
            Vector3(0.0, -angle, 0.22),
            "HeartforgeDamageScar%02d" % index,
            0.28
        )
        ModelKit3D.add_sphere(
            _damage_visual_root,
            0.08 + float(index) * 0.012,
            position + Vector3.UP * (0.48 + float(index % 2) * 0.1),
            _damage_signal_material,
            Vector3(1.0, 0.72, 1.0),
            "HeartforgeDamageLeak%02d" % index
        )
    _refresh_damage_presentation()


func _refresh_damage_presentation() -> void:
    if _damage_visual_root == null:
        return
    var integrity := clampf(current_health / maxf(1.0, maximum_health), 0.0, 1.0)
    var damage := 1.0 - integrity
    _damage_visual_root.visible = damage > 0.035
    if _damage_signal_material != null:
        _damage_signal_material.emission_energy_multiplier = lerpf(0.45, 3.4, damage)
        _damage_signal_material.albedo_color = Color("3e1820").lerp(Color("7b2430"), damage)
    for index in range(3):
        var scar := _damage_visual_root.get_node_or_null("HeartforgeDamageScar%02d" % index) as Node3D
        var leak := _damage_visual_root.get_node_or_null("HeartforgeDamageLeak%02d" % index) as Node3D
        var threshold := 0.1 + float(index) * 0.2
        var visibility := clampf((damage - threshold) / 0.18, 0.0, 1.0)
        if scar != null:
            scar.visible = visibility > 0.0
            scar.scale = Vector3(1.0, 0.72 + visibility * 0.28, 1.0)
        if leak != null:
            leak.visible = visibility > 0.25


func _retune_authored_materials(authored_model: Node3D) -> void:
    # The imported shell supplies authored emissive materials, while runtime
    # progression supplies the crown and local lights. Keep the combined
    # focal energy legible under the opening ACES/glow grade instead of
    # allowing the shell to collapse into a white patch at tactical distance.
    for raw_node in authored_model.find_children("*", "MeshInstance3D", true, false):
        var mesh_instance := raw_node as MeshInstance3D
        if mesh_instance == null or mesh_instance.mesh == null:
            continue
        var node_name := String(mesh_instance.name).to_lower()
        var emission_ceiling := 0.72
        if node_name.contains("furnace") or node_name.contains("thermal"):
            emission_ceiling = 0.25
        elif node_name.contains("louver") or node_name.contains("lens") or node_name.contains("plateglow"):
            emission_ceiling = 0.38
        for surface_index in range(mesh_instance.mesh.get_surface_count()):
            var source_material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
            if source_material == null or not source_material.emission_enabled:
                continue
            var tuned_material := source_material.duplicate() as StandardMaterial3D
            tuned_material.emission_energy_multiplier = minf(tuned_material.emission_energy_multiplier, emission_ceiling)
            mesh_instance.set_surface_override_material(surface_index, tuned_material)


func _build_adaptive_geometry(tier: int) -> void:
    var iron := ModelKit3D.material(Color("394143"), 0.78, 0.42)
    var dark := ModelKit3D.material(Color("1b2425"), 0.74, 0.5)
    var rust := ModelKit3D.material(Color("805034"), 0.42, 0.72)
    var heat := ModelKit3D.material(Color("9e4f18"), 0.24, 0.42, Color("ff7b2f"), 2.0)
    var cyan := ModelKit3D.material(Color("28595c"), 0.38, 0.34, Color("70e9ee"), 1.25)

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
        # The sovereignty crown is a ring, not a filled plate. A solid
        # cylinder reads as a pale disc from the tactical camera and hides
        # the reactor silhouette beneath it.
        var crown_heat := ModelKit3D.material(Color("6e3419"), 0.3, 0.5, Color("ff7b2f"), 0.72)
        var crown_mesh := TorusMesh.new()
        crown_mesh.inner_radius = 2.28
        crown_mesh.outer_radius = 2.9
        crown_mesh.rings = 20
        crown_mesh.ring_segments = 64
        var crown := MeshInstance3D.new()
        crown.name = "Tier5SovereigntyCrown"
        crown.mesh = crown_mesh
        crown.material_override = crown_heat
        crown.position = Vector3(0.0, 4.72, 0.0)
        _adaptive_geometry.add_child(crown)
        for angle_index in range(8):
            var angle := TAU * float(angle_index) / 8.0
            var crown_position := Vector3(cos(angle) * 2.72, 4.9, sin(angle) * 2.72)
            ModelKit3D.add_beveled_box(_adaptive_geometry, Vector3(0.24, 0.78, 0.52), crown_position, cyan, Vector3(0.0, -angle, 0.0), "Tier5CrownFin", 0.08)
        ModelKit3D.add_cylinder(_adaptive_geometry, 0.34, 1.15, Vector3(0.0, 5.15, 0.0), heat, Vector3.ZERO, "Tier5CrownBeacon")


func _build_adaptation_detail(profile: StringName) -> void:
    if _adaptation_detail == null or profile == &"":
        return
    var iron := ModelKit3D.material(Color("465053"), 0.76, 0.4)
    var dark := ModelKit3D.material(Color("172123"), 0.72, 0.5)
    var rust := ModelKit3D.material(Color("8d5938"), 0.4, 0.7)
    var cyan := ModelKit3D.material(Color("28646a"), 0.32, 0.3, Color("77e9ee"), 1.8)
    var amber := ModelKit3D.material(Color("8b4b25"), 0.28, 0.42, Color("ff7a32"), 2.4)
    match profile:
        &"adaptation.anchored_shell":
            for side in [-1.0, 1.0]:
                ModelKit3D.add_beveled_box(_adaptation_detail, Vector3(0.3, 2.55, 0.62), Vector3(side * 2.02, 1.65, 0.0), iron, Vector3(0.0, side * 0.12, 0.0), "AnchorShellBrace", 0.1)
                ModelKit3D.add_cylinder(_adaptation_detail, 0.1, 3.2, Vector3(side * 2.24, 1.8, 0.0), rust, Vector3.ZERO, "AnchorShellServiceColumn")
            ModelKit3D.add_beveled_box(_adaptation_detail, Vector3(4.9, 0.22, 0.34), Vector3(0.0, 3.32, 0.0), dark, Vector3.ZERO, "AnchorShellCrossbar", 0.08)
            ModelKit3D.add_cylinder(_adaptation_detail, 2.38, 0.1, Vector3(0.0, 3.42, 0.0), cyan, Vector3.ZERO, "AnchorShellSignalRing")
        &"adaptation.sacrificial_hollow":
            for angle_index in range(8):
                var angle := TAU * float(angle_index) / 8.0
                var position := Vector3(cos(angle) * 2.52, 1.34, sin(angle) * 2.52)
                ModelKit3D.add_beveled_box(_adaptation_detail, Vector3(0.22, 1.24, 0.48), position, rust, Vector3(0.0, -angle, 0.0), "SacrificialHollowRib", 0.08)
            ModelKit3D.add_cylinder(_adaptation_detail, 2.78, 0.14, Vector3(0.0, 0.86, 0.0), amber, Vector3.ZERO, "SacrificialHollowRing")
            ModelKit3D.add_louvered_panel(_adaptation_detail, Vector3(0.82, 0.72, 0.12), Vector3(0.0, 1.72, 2.42), dark, amber, Vector3.ZERO, "SacrificialHollowService", 5)
        &"adaptation.quiet_core":
            for side in [-1.0, 1.0]:
                ModelKit3D.add_beveled_box(_adaptation_detail, Vector3(0.5, 2.5, 0.24), Vector3(side * 1.92, 2.05, 0.0), dark, Vector3(0.0, side * 0.08, 0.0), "QuietCoreShroud", 0.14)
                ModelKit3D.add_cylinder(_adaptation_detail, 0.07, 2.7, Vector3(side * 2.15, 2.1, 0.0), cyan, Vector3.ZERO, "QuietCoreDampedRail")
            ModelKit3D.add_beveled_box(_adaptation_detail, Vector3(2.32, 0.16, 0.88), Vector3(0.0, 2.18, 2.02), dark, Vector3.ZERO, "QuietCoreServiceShroud", 0.12)
            ModelKit3D.add_surface_panel(_adaptation_detail, Vector3(1.2, 0.5, 0.1), Vector3(0.0, 2.2, 2.48), dark, cyan, Vector3.ZERO, "QuietCoreSignalPanel")
