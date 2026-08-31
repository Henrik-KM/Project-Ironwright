class_name VerticalSliceActorArt3D
extends Node

## Concentrated presentation pass for the opening cast. Authored hero packages
## own their static silhouette; this director now adds only bounded runtime
## feedback there while retaining procedural role detail for ordinary machines.

const BULWARK_PROTECTION_VFX_MATERIAL_FAMILY := &"bulwark_protection_vfx"

var world: Node
var polished: Dictionary = {}
var steel: StandardMaterial3D
var dark_steel: StandardMaterial3D
var rust: StandardMaterial3D
var cyan: StandardMaterial3D
var warm: StandardMaterial3D
var finish_panel: StandardMaterial3D
var finish_cable: StandardMaterial3D
var finish_warning: StandardMaterial3D
var finish_status: StandardMaterial3D
var scan_queued: bool = false


func configure(next_world: Node) -> void:
    world = next_world


func _ready() -> void:
    steel = ModelKit3D.material(Color("39464b"), 0.74, 0.34)
    dark_steel = ModelKit3D.material(Color("151d20"), 0.84, 0.3)
    rust = ModelKit3D.material(Color("6b3e29"), 0.48, 0.67)
    # Keep the cognition and utility accents luminous without washing the
    # authored machine shells into white bands at the close review distance.
    cyan = ModelKit3D.material(Color("23454b"), 0.34, 0.26, Color("58c7cf"), 0.95)
    warm = ModelKit3D.material(Color("72421f"), 0.24, 0.32, Color("ee8b3e"), 0.9)
    finish_panel = ModelKit3D.material(Color("273338"), 0.68, 0.34)
    finish_cable = ModelKit3D.material(Color("10181c"), 0.35, 0.52)
    finish_warning = ModelKit3D.material(Color("6e3d27"), 0.34, 0.58, Color("d58a48"), 0.42)
    finish_status = ModelKit3D.material(Color("153f45"), 0.26, 0.24, Color("4fc4cc"), 0.72)
    _polish_existing()
    get_tree().node_added.connect(_on_node_added)


func _polish_existing() -> void:
    for node in get_tree().get_nodes_in_group(&"player_character"):
        _polish(node)
    for node in get_tree().get_nodes_in_group(&"friendly_robots"):
        _polish(node)
    for node in get_tree().get_nodes_in_group(&"heartforge"):
        _polish(node)


func _on_node_added(node: Node) -> void:
    if not (node is Node3D):
        return
    if scan_queued:
        return
    scan_queued = true
    call_deferred("_scan_unpolished")


func _scan_unpolished() -> void:
    scan_queued = false
    _polish_existing()


func _polish(node: Node) -> void:
    if node == null or not is_instance_valid(node) or polished.has(node):
        return
    if node is Mechromancer3D:
        _polish_player(node as Mechromancer3D)
    elif node is RobotUnit3D:
        _polish_robot(node as RobotUnit3D)
    elif node is Heartforge3D:
        _polish_heartforge(node as Heartforge3D)
    else:
        return
    polished[node] = true


func _polish_player(player: Mechromancer3D) -> void:
    # The imported Mechromancer package now owns the complete static field-kit
    # silhouette and PBR surface treatment. Keep only one restrained practical
    # light on its authored shoulder socket; progression and the bounded death
    # presentation remain actor-owned siblings. No geometry or material
    # override is created here.
    var model := player.get_node_or_null("MechromancerModel") as Node3D
    if model == null or model.find_child("MechromancerReadabilityLight", true, false) != null:
        return
    var shoulder_socket := model.find_child("ShoulderLamp", true, false) as Node3D
    if shoulder_socket == null:
        return
    var readability_light := OmniLight3D.new()
    readability_light.name = "MechromancerReadabilityLight"
    readability_light.position = Vector3(0.0, 0.0, -0.08)
    readability_light.light_color = Color("80dbe0")
    readability_light.light_energy = 0.22
    readability_light.omni_range = 3.6
    readability_light.shadow_enabled = false
    shoulder_socket.add_child(readability_light)


func _polish_robot(robot: RobotUnit3D) -> void:
    var model := robot.get_node_or_null("RobotModel") as Node3D
    if model == null or model.get_node_or_null("VerticalSliceMachineArt") != null:
        return
    var detail := Node3D.new()
    detail.name = "VerticalSliceMachineArt"
    model.add_child(detail)

    if robot.archetype == &"companion":
        # The authored Bulwark package owns the complete static silhouette and
        # surface finish. This layer contributes only animated protection
        # feedback, so it cannot double the shell, weapons or service hardware.
        _build_bulwark_detail(detail)
        return

    match robot.archetype:
        &"guardian":
            _build_warden_detail(detail)
        &"salvager":
            _build_scrapper_detail(detail)
        &"scout":
            _build_pathfinder_detail(detail)
        &"engineer":
            _build_engineer_detail(detail)
        &"relay":
            _build_relay_detail(detail)
        _:
            _build_scrapper_detail(detail)
    _build_machine_roster_micro_detail(detail, robot)
    _build_machine_role_signature(detail, robot)
    _build_machine_finish(detail, robot)


func _build_machine_roster_micro_detail(parent: Node3D, robot: RobotUnit3D) -> void:
    # The focal pair has a dedicated hero pass; this bounded companion pass
    # gives the remaining machine roles one maintained close-range signature
    # each, so the roster does not collapse into the same generic chassis.
    match robot.archetype:
        &"guardian":
            ModelKit3D.add_surface_panel(
                parent,
                Vector3(0.34, 0.16, 0.07),
                Vector3(0.0, 1.52, -0.96),
                finish_panel,
                finish_warning,
                Vector3(-0.05, 0.0, 0.0),
                "WardenTargetingFace"
            )
            for side in [-1.0, 1.0]:
                ModelKit3D.add_cylinder(parent, 0.13, 0.055, Vector3(float(side) * 0.52, 1.56, -0.995), finish_warning, Vector3(1.5708, 0.0, 0.0), "WardenRecoilCollar%s" % ("Left" if side < 0.0 else "Right"))
        &"salvager":
            ModelKit3D.add_surface_panel(
                parent,
                Vector3(0.42, 0.18, 0.07),
                Vector3(0.0, 1.63, -0.25),
                finish_panel,
                finish_warning,
                Vector3(-0.04, 0.0, 0.0),
                "ScrapperHopperLatch"
            )
            for side in [-1.0, 1.0]:
                ModelKit3D.add_cylinder(parent, 0.055, 0.06, Vector3(float(side) * 0.36, 1.6, -0.34), finish_warning, Vector3(1.5708, 0.0, 0.0), "ScrapperCargoFastener%s" % ("Left" if side < 0.0 else "Right"))
        &"scout":
            for side in [-1.0, 1.0]:
                ModelKit3D.add_beveled_box(parent, Vector3(0.08, 0.28, 0.18), Vector3(float(side) * 0.2, 1.98, 0.14), finish_panel, Vector3(0.0, 0.0, float(side) * 0.16), "PathfinderMastBrace%s" % ("Left" if side < 0.0 else "Right"), 0.18)
            ModelKit3D.add_sphere(parent, 0.07, Vector3(0.0, 2.72, -0.08), finish_status, Vector3(1.2, 0.72, 0.72), "PathfinderSurveyBeacon")
        &"engineer":
            ModelKit3D.add_surface_panel(
                parent,
                Vector3(0.36, 0.18, 0.07),
                Vector3(0.0, 1.64, -0.18),
                finish_panel,
                finish_warning,
                Vector3(-0.04, 0.0, 0.0),
                "EngineerToolControl"
            )
            ModelKit3D.add_louvered_panel(
                parent,
                Vector3(0.36, 0.22, 0.12),
                Vector3(0.0, 1.16, -0.98),
                dark_steel,
                finish_warning,
                Vector3.ZERO,
                "EngineerForgeGuard",
                3
            )


func _build_machine_role_signature(parent: Node3D, robot: RobotUnit3D) -> void:
    # Third-pass role hardware gives the four ordinary frames a distinctive
    # close-camera silhouette instead of relying on color or a single prop.
    # These assemblies remain presentation-only and are deliberately bounded
    # so larger autonomous populations do not acquire a new simulation cost.
    match robot.archetype:
        &"guardian":
            for side in [-1.0, 1.0]:
                var side_sign := float(side)
                ModelKit3D.add_beveled_box(
                    parent,
                    Vector3(0.16, 0.28, 0.52),
                    Vector3(side_sign * 0.78, 1.66, -0.76),
                    finish_panel,
                    Vector3(-0.08, 0.0, side_sign * 0.12),
                    "WardenThermalFin%s" % ("Left" if side_sign < 0.0 else "Right"),
                    0.2
                )
            ModelKit3D.add_surface_panel(
                parent,
                Vector3(0.34, 0.18, 0.08),
                Vector3(0.0, 1.72, -1.02),
                dark_steel,
                finish_status,
                Vector3(-0.06, 0.0, 0.0),
                "WardenOpticShroud"
            )
            ModelKit3D.add_cylinder(parent, 0.07, 0.28, Vector3(0.0, 1.72, -0.7), finish_warning, Vector3(1.5708, 0.0, 0.0), "WardenBreechClamp")
        &"salvager":
            ModelKit3D.add_beveled_box(
                parent,
                Vector3(1.24, 0.12, 0.14),
                Vector3(0.0, 1.92, 0.34),
                finish_panel,
                Vector3(0.04, 0.0, 0.0),
                "ScrapperHopperLip",
                0.2
            )
            for side in [-1.0, 1.0]:
                var side_sign := float(side)
                ModelKit3D.add_cylinder(
                    parent,
                    0.15,
                    0.08,
                    Vector3(side_sign * 0.56, 1.2, 0.42),
                    finish_warning,
                    Vector3(1.5708, 0.0, 0.0),
                    "ScrapperDrum%s" % ("Left" if side_sign < 0.0 else "Right")
                )
            ModelKit3D.add_louvered_panel(
                parent,
                Vector3(0.46, 0.2, 0.12),
                Vector3(0.0, 1.22, -0.99),
                dark_steel,
                finish_status,
                Vector3(-0.08, 0.0, 0.0),
                "ScrapperCuttingGuard",
                3
            )
        &"scout":
            var mast_collar := MeshInstance3D.new()
            mast_collar.name = "PathfinderMastCollar"
            var collar_mesh := TorusMesh.new()
            collar_mesh.inner_radius = 0.09
            collar_mesh.outer_radius = 0.14
            collar_mesh.rings = 12
            collar_mesh.ring_segments = 24
            mast_collar.mesh = collar_mesh
            mast_collar.material_override = finish_warning
            mast_collar.position = Vector3(0.0, 1.28, 0.14)
            parent.add_child(mast_collar)
            for side in [-1.0, 1.0]:
                var side_sign := float(side)
                ModelKit3D.add_beveled_box(
                    parent,
                    Vector3(0.08, 0.1, 0.64),
                    Vector3(side_sign * 0.18, 2.72, 0.14),
                    finish_panel,
                    Vector3(0.0, 0.0, side_sign * 0.18),
                    "PathfinderDishRib%s" % ("Left" if side_sign < 0.0 else "Right"),
                    0.18
                )
            ModelKit3D.add_surface_panel(
                parent,
                Vector3(0.26, 0.18, 0.08),
                Vector3(0.42, 1.02, 0.3),
                dark_steel,
                finish_status,
                Vector3(0.0, 0.0, -0.12),
                "PathfinderSignalCanister"
            )
        &"engineer":
            ModelKit3D.add_cylinder(
                parent,
                0.16,
                0.26,
                Vector3(-0.52, 0.98, 0.22),
                finish_warning,
                Vector3(1.5708, 0.0, 0.0),
                "EngineerCableSpool"
            )
            ModelKit3D.add_surface_panel(
                parent,
                Vector3(0.34, 0.24, 0.08),
                Vector3(-0.76, 1.42, -0.46),
                dark_steel,
                finish_status,
                Vector3(-0.1, 0.0, 0.12),
                "EngineerWeldingShield"
            )
            ModelKit3D.add_beveled_box(
                parent,
                Vector3(0.42, 0.16, 0.3),
                Vector3(1.34, 0.76, -0.3),
                finish_panel,
                Vector3(0.0, 0.0, -0.16),
                "EngineerClampJaw",
                0.2
            )
        &"relay":
            var relay_collar := MeshInstance3D.new()
            relay_collar.name = "RelayMastCollar"
            var relay_collar_mesh := TorusMesh.new()
            relay_collar_mesh.inner_radius = 0.09
            relay_collar_mesh.outer_radius = 0.14
            relay_collar_mesh.rings = 12
            relay_collar_mesh.ring_segments = 24
            relay_collar.mesh = relay_collar_mesh
            relay_collar.material_override = finish_warning
            relay_collar.position = Vector3(0.0, 1.58, 0.08)
            parent.add_child(relay_collar)
            ModelKit3D.add_louvered_panel(parent, Vector3(0.48, 0.24, 0.12), Vector3(0.0, 1.0, 0.76), dark_steel, finish_status, Vector3.ZERO, "RelayHeatSink", 4)
            for side in [-1.0, 1.0]:
                var side_sign := float(side)
                ModelKit3D.add_beveled_box(parent, Vector3(0.08, 0.1, 0.62), Vector3(side_sign * 0.18, 2.7, 0.08), finish_panel, Vector3(0.0, 0.0, side_sign * 0.16), "RelayDishRib%s" % ("Left" if side_sign < 0.0 else "Right"), 0.18)
            ModelKit3D.add_surface_panel(parent, Vector3(0.28, 0.18, 0.08), Vector3(0.0, 1.2, -0.74), dark_steel, finish_status, Vector3.ZERO, "RelaySignalFace")


func _build_machine_finish(parent: Node3D, robot: RobotUnit3D) -> void:
    # A final shared manufacturing pass gives every frame the same authored
    # language: inset service panel, fasteners, protected cable runs and a
    # small status light. Role-specific silhouettes remain the dominant read.
    var finish := Node3D.new()
    finish.name = "MachineSurfaceFinish"
    parent.add_child(finish)

    var body_width := 1.25
    var body_depth := 1.55
    if robot.archetype in [&"guardian", &"companion"]:
        body_width = 1.5
        body_depth = 1.7
    elif robot.archetype == &"engineer":
        body_width = 1.35
        body_depth = 1.58
    elif robot.archetype == &"relay":
        body_width = 1.18
        body_depth = 1.4

    ModelKit3D.add_surface_panel(
        finish,
        Vector3(body_width * 0.62, 0.15, body_depth * 0.34),
        Vector3(0.0, 1.43, -body_depth * 0.43),
        finish_panel,
        finish_warning,
        Vector3(-0.03, 0.0, 0.0),
        "MachineServicePanel"
    )
    ModelKit3D.add_box(
        finish,
        Vector3(body_width * 0.42, 0.045, 0.045),
        Vector3(0.0, 1.51, -body_depth * 0.625),
        finish_status,
        Vector3.ZERO,
        "MachineStatusBar"
    )

    for side in [-1.0, 1.0]:
        var side_sign := float(side)
        ModelKit3D.add_cylinder(
            finish,
            0.105,
            0.07,
            Vector3(side_sign * body_width * 0.49, 0.59, -body_depth * 0.25),
            finish_warning,
            Vector3.ZERO,
            "MachineJointCollar"
        )
        ModelKit3D.add_tapered_cylinder(
            finish,
            0.035,
            0.05,
            body_depth * 0.48,
            Vector3(side_sign * body_width * 0.54, 0.9, -0.02),
            finish_cable,
            Vector3(0.0, 0.0, side_sign * 0.18),
            "MachineCableRun"
        )
        ModelKit3D.add_beveled_box(
            finish,
            Vector3(0.12, 0.28, body_depth * 0.34),
            Vector3(side_sign * body_width * 0.56, 0.99, 0.1),
            finish_panel,
            Vector3(0.0, 0.0, side_sign * 0.08),
            "MachineSideGuard",
            0.22
        )


func _build_bulwark_detail(parent: Node3D) -> void:
    # Bulwark's authored package owns every static plate, weapon, emitter,
    # collar and service surface. Keep only the animated field cues here; the
    # protection controller continues to resolve the package-owned
    # BulwarkShieldEmitter and BulwarkEmitterCollar by their stable names.
    var shield_material := ModelKit3D.material(Color("14383d"), 0.46, 0.32, Color("50c6ce"), 0.82)
    var shield_ring := MeshInstance3D.new()
    shield_ring.name = "BulwarkShieldArc"
    var shield_mesh := TorusMesh.new()
    shield_mesh.inner_radius = 0.72
    shield_mesh.outer_radius = 0.79
    shield_mesh.rings = 24
    shield_mesh.ring_segments = 48
    shield_ring.mesh = shield_mesh
    shield_ring.material_override = shield_material
    shield_ring.position = Vector3(0.0, 0.34, 0.08)
    shield_ring.set_meta(&"release_material_family", BULWARK_PROTECTION_VFX_MATERIAL_FAMILY)
    parent.add_child(shield_ring)
    var scan_material := ModelKit3D.material(Color("255f65"), 0.34, 0.24, Color("79e3e8"), 1.9)
    var scan_blade := ModelKit3D.add_beveled_box(
        shield_ring,
        Vector3(0.055, 0.16, 0.18),
        Vector3(0.0, 0.0, -0.785),
        scan_material,
        Vector3.ZERO,
        "BulwarkShieldScanBlade",
        0.025
    )
    scan_blade.set_meta(&"release_material_family", BULWARK_PROTECTION_VFX_MATERIAL_FAMILY)
    var protection_light := OmniLight3D.new()
    protection_light.name = "BulwarkProtectionLight"
    protection_light.position = Vector3(0.0, 1.42, -1.0)
    protection_light.light_color = Color("f0a65a")
    protection_light.light_energy = 0.42
    protection_light.omni_range = 3.2
    protection_light.shadow_enabled = false
    parent.add_child(protection_light)


func _build_warden_detail(parent: Node3D) -> void:
    for side in [-1.0, 1.0]:
        ModelKit3D.add_beveled_box(parent, Vector3(0.46, 0.8, 1.3), Vector3(side * 0.78, 0.85, 0.05), steel, Vector3(0.0, 0.0, side * 0.08), "WardenSidePlate", 0.16)
    ModelKit3D.add_cylinder(parent, 0.12, 1.45, Vector3(0.0, 1.42, -0.78), dark_steel, Vector3(1.5708, 0.0, 0.0), "WardenAutocannon")
    ModelKit3D.add_beveled_box(parent, Vector3(0.54, 0.38, 0.56), Vector3(0.0, 1.42, -0.55), rust, Vector3.ZERO, "WardenBreech", 0.18)
    ModelKit3D.add_beveled_box(parent, Vector3(1.6, 0.15, 0.46), Vector3(0.0, 0.46, 0.84), dark_steel, Vector3(0.0, 0.0, -0.08), "WardenCounterweight", 0.2)
    ModelKit3D.add_louvered_panel(parent, Vector3(0.72, 0.32, 0.18), Vector3(-0.52, 1.34, -0.87), dark_steel, rust, Vector3(-0.04, 0.0, 0.0), "WardenHeatExchanger", 5)
    ModelKit3D.add_louvered_panel(parent, Vector3(0.54, 0.26, 0.16), Vector3(0.52, 1.3, -0.84), dark_steel, steel, Vector3(-0.06, 0.0, 0.0), "WardenAmmunitionPanel", 4)
    for side in [-1.0, 1.0]:
        ModelKit3D.add_cylinder(parent, 0.14, 0.1, Vector3(side * 0.52, 1.56, -0.93), warm, Vector3(1.5708, 0.0, 0.0), "WardenRecoilRing")
    _add_machine_lamp(parent, Vector3(-0.36, 1.36, -0.9), Color("e9a65b"), 0.34)
    _add_machine_lamp(parent, Vector3(0.36, 1.36, -0.9), Color("e9a65b"), 0.34)


func _build_scrapper_detail(parent: Node3D) -> void:
    ModelKit3D.add_beveled_box(parent, Vector3(1.18, 0.72, 1.0), Vector3(0.0, 1.5, 0.28), dark_steel, Vector3(0.06, 0.0, 0.0), "DeepScrapHopper", 0.16)
    for side in [-1.0, 1.0]:
        ModelKit3D.add_cylinder(parent, 0.095, 1.25, Vector3(side * 0.72, 0.92, -0.18), rust, Vector3(0.0, 0.0, side * 1.0), "ScrapManipulator")
        ModelKit3D.add_beveled_box(parent, Vector3(0.32, 0.18, 0.52), Vector3(side * 1.15, 0.6, -0.2), steel, Vector3(0.0, 0.0, side * 0.16), "ScrapClaw", 0.22)
    ModelKit3D.add_cylinder(parent, 0.18, 0.34, Vector3(0.0, 1.12, -0.92), dark_steel, Vector3(1.5708, 0.0, 0.0), "CuttingHead")
    ModelKit3D.add_louvered_panel(parent, Vector3(0.78, 0.34, 0.18), Vector3(0.0, 1.48, -0.38), dark_steel, rust, Vector3(-0.08, 0.0, 0.0), "ScrapperIntake", 4)
    for side in [-1.0, 1.0]:
        ModelKit3D.add_cylinder(parent, 0.12, 0.1, Vector3(side * 1.15, 0.62, -0.44), cyan, Vector3(1.5708, 0.0, 0.0), "ScrapMagnet")
    _add_machine_lamp(parent, Vector3(0.0, 1.22, -0.98), Color("6bd7de"), 0.3)


func _build_relay_detail(parent: Node3D) -> void:
    var relay_glow := ModelKit3D.material(Color("174c52"), 0.32, 0.22, Color("79e3e8"), 2.0)
    ModelKit3D.add_surface_panel(parent, Vector3(0.72, 0.26, 0.08), Vector3(0.0, 1.2, -0.78), dark_steel, relay_glow, Vector3.ZERO, "RelayServiceFace")
    ModelKit3D.add_louvered_panel(parent, Vector3(0.7, 0.3, 0.14), Vector3(0.0, 0.88, 0.76), dark_steel, steel, Vector3.ZERO, "RelayRearRadiator", 5)
    ModelKit3D.add_cylinder(parent, 0.07, 1.28, Vector3(0.0, 1.7, 0.08), dark_steel, Vector3.ZERO, "RelayAntennaMast")
    ModelKit3D.add_sphere(parent, 0.1, Vector3(0.0, 2.34, -0.02), relay_glow, Vector3(1.0, 0.72, 0.72), "RelaySignalBeacon")
    ModelKit3D.add_beveled_box(parent, Vector3(0.18, 0.3, 0.46), Vector3(-0.7, 1.0, 0.0), finish_panel, Vector3(0.0, 0.0, 0.18), "RelaySideGuardLeft", 0.18)
    ModelKit3D.add_beveled_box(parent, Vector3(0.18, 0.3, 0.46), Vector3(0.7, 1.0, 0.0), finish_panel, Vector3(0.0, 0.0, -0.18), "RelaySideGuardRight", 0.18)
    _add_machine_lamp(parent, Vector3(0.0, 1.2, -0.84), Color("79e3e8"), 0.28)


func _build_pathfinder_detail(parent: Node3D) -> void:
    ModelKit3D.add_cylinder(parent, 0.06, 1.9, Vector3(0.0, 2.0, 0.14), dark_steel, Vector3.ZERO, "PathfinderMast")
    ModelKit3D.add_sphere(parent, 0.28, Vector3(0.0, 2.72, 0.14), steel, Vector3(1.4, 0.35, 1.4), "PathfinderDish")
    ModelKit3D.add_cylinder(parent, 0.11, 0.16, Vector3(0.0, 2.72, -0.05), cyan, Vector3(1.5708, 0.0, 0.0), "PathfinderDishHub")
    ModelKit3D.add_louvered_panel(parent, Vector3(0.62, 0.24, 0.16), Vector3(0.0, 1.34, -0.48), dark_steel, cyan, Vector3(-0.05, 0.0, 0.0), "PathfinderSensorPod", 3)
    for side in [-1.0, 1.0]:
        ModelKit3D.add_beveled_box(parent, Vector3(0.72, 0.08, 0.42), Vector3(side * 0.72, 1.42, 0.08), dark_steel, Vector3(0.0, 0.0, side * 0.12), "PathfinderSensorWing", 0.22)
        ModelKit3D.add_sphere(parent, 0.075, Vector3(side * 0.3, 1.38, -0.56), cyan, Vector3(1.0, 0.72, 0.6), "PathfinderRangeLens")
        _add_machine_lamp(parent, Vector3(side * 0.65, 1.42, -0.3), Color("82d68a"), 0.24)


func _build_engineer_detail(parent: Node3D) -> void:
    ModelKit3D.add_beveled_box(parent, Vector3(1.22, 0.5, 0.86), Vector3(0.0, 1.56, 0.26), dark_steel, Vector3.ZERO, "EngineerToolCradle", 0.16)
    ModelKit3D.add_cylinder(parent, 0.09, 1.35, Vector3(-0.78, 1.12, -0.1), rust, Vector3(0.0, 0.0, 1.08), "EngineerWelderBoom")
    ModelKit3D.add_cylinder(parent, 0.1, 1.42, Vector3(0.78, 1.12, 0.0), steel, Vector3(0.0, 0.0, -1.04), "EngineerClampBoom")
    ModelKit3D.add_beveled_box(parent, Vector3(0.32, 0.22, 0.46), Vector3(1.28, 0.78, -0.02), steel, Vector3.ZERO, "EngineerClamp", 0.22)
    _add_machine_lamp(parent, Vector3(-1.25, 0.76, -0.12), Color("f0ad68"), 0.3)


func _polish_heartforge(_forge: Heartforge3D) -> void:
    # Static model-local forge hardware is now owned by the authored asset.
    # Ambient sanctuary dressing remains world-owned and is intentionally
    # unaffected by this actor-art pass.
    pass


func _add_machine_lamp(parent: Node3D, position: Vector3, color: Color, energy: float) -> void:
    ModelKit3D.add_sphere(parent, 0.07, position, ModelKit3D.material(color.darkened(0.58), 0.25, 0.25, color, 1.8), Vector3.ONE, "MachineLamp")
    var light := OmniLight3D.new()
    light.position = position
    light.light_color = color
    light.light_energy = energy
    light.omni_range = 3.2
    light.shadow_enabled = false
    parent.add_child(light)
