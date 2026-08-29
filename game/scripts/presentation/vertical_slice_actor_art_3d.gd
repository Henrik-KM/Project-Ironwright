class_name VerticalSliceActorArt3D
extends Node

## Concentrated silhouette pass for the opening cast. These meshes are still
## procedural, but deliberately replace toy-like symmetry with layered,
## asymmetric industrial shapes and readable functional parts.

var world: Node
var polished: Dictionary = {}
var steel: StandardMaterial3D
var dark_steel: StandardMaterial3D
var rust: StandardMaterial3D
var fabric: StandardMaterial3D
var leather: StandardMaterial3D
var cyan: StandardMaterial3D
var warm: StandardMaterial3D
var ceramic: StandardMaterial3D
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
    fabric = ModelKit3D.material(Color("202a31"), 0.03, 0.94)
    leather = ModelKit3D.material(Color("493329"), 0.06, 0.88)
    # Keep the cognition and utility accents luminous without washing the
    # authored machine shells into white bands at the close review distance.
    cyan = ModelKit3D.material(Color("23454b"), 0.34, 0.26, Color("6adbe1"), 1.25)
    warm = ModelKit3D.material(Color("72421f"), 0.24, 0.32, Color("f29a48"), 1.15)
    ceramic = ModelKit3D.material(Color("707777"), 0.08, 0.72)
    finish_panel = ModelKit3D.material(Color("273338"), 0.68, 0.34)
    finish_cable = ModelKit3D.material(Color("10181c"), 0.35, 0.52)
    finish_warning = ModelKit3D.material(Color("6e3d27"), 0.34, 0.58, Color("d58a48"), 0.42)
    finish_status = ModelKit3D.material(Color("1b555b"), 0.26, 0.24, Color("75e6e8"), 1.35)
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
    var model := player.get_node_or_null("MechromancerModel") as Node3D
    if model == null or model.get_node_or_null("VerticalSliceCharacterArt") != null:
        return
    var detail := Node3D.new()
    detail.name = "VerticalSliceCharacterArt"
    model.add_child(detail)

    # Hood silhouette and respirator collar.
    ModelKit3D.add_sphere(detail, 0.33, Vector3(0.0, 1.9, 0.06), fabric, Vector3(1.03, 0.95, 1.08), "DeepHood")
    ModelKit3D.add_beveled_box(detail, Vector3(0.56, 0.16, 0.32), Vector3(0.0, 1.66, -0.13), dark_steel, Vector3(0.08, 0.0, 0.0), "RespiratorCollar", 0.2)
    ModelKit3D.add_beveled_box(detail, Vector3(0.28, 0.16, 0.18), Vector3(0.0, 1.72, -0.28), ceramic, Vector3.ZERO, "RespiratorMask", 0.24)

    # Layered scavenger rig gives the body asymmetry and identifies the
    # Mechromancer as a field mechanic, not a generic mobile-game hero.
    ModelKit3D.add_beveled_box(detail, Vector3(0.7, 0.88, 0.34), Vector3(0.0, 1.08, 0.34), leather, Vector3(-0.05, 0.0, 0.02), "FieldPack", 0.16)
    ModelKit3D.add_beveled_box(detail, Vector3(0.82, 0.1, 0.08), Vector3(0.0, 1.4, -0.28), rust, Vector3(0.0, 0.0, -0.05), "ChestHarness", 0.2)
    ModelKit3D.add_beveled_box(detail, Vector3(0.1, 0.8, 0.08), Vector3(-0.28, 1.05, -0.24), leather, Vector3(0.0, 0.0, 0.08), "HarnessStrap", 0.28)
    ModelKit3D.add_beveled_box(detail, Vector3(0.1, 0.8, 0.08), Vector3(0.28, 1.05, -0.24), leather, Vector3(0.0, 0.0, -0.08), "HarnessStrap", 0.28)
    ModelKit3D.add_sphere(detail, 0.055, Vector3(-0.28, 1.39, -0.3), warm, Vector3(1.0, 0.72, 0.72), "HarnessFastener")
    ModelKit3D.add_sphere(detail, 0.055, Vector3(0.28, 1.39, -0.3), warm, Vector3(1.0, 0.72, 0.72), "HarnessFastener")
    ModelKit3D.add_cylinder(detail, 0.18, 0.46, Vector3(-0.43, 1.06, 0.38), rust, Vector3(1.5708, 0.0, 0.0), "CableSpool")
    ModelKit3D.add_cylinder(detail, 0.045, 0.5, Vector3(-0.43, 1.06, 0.12), dark_steel, Vector3(1.5708, 0.0, 0.0), "CableSpoolAxle")
    ModelKit3D.add_beveled_box(detail, Vector3(0.24, 0.5, 0.18), Vector3(0.48, 0.92, 0.3), rust, Vector3(0.0, 0.0, -0.08), "ToolRoll", 0.2)

    # Weak pistol is visibly improvised and small relative to the machines.
    ModelKit3D.add_beveled_box(detail, Vector3(0.13, 0.15, 0.65), Vector3(0.48, 1.06, -0.42), dark_steel, Vector3(0.0, 0.0, 0.01), "PistolSlide", 0.2)
    ModelKit3D.add_cylinder(detail, 0.045, 0.62, Vector3(0.48, 1.08, -0.72), steel, Vector3(1.5708, 0.0, 0.0), "PistolBarrel")
    ModelKit3D.add_beveled_box(detail, Vector3(0.14, 0.38, 0.16), Vector3(0.48, 0.83, -0.27), leather, Vector3(0.1, 0.0, 0.0), "PistolGrip", 0.24)

    # Final field-kit pass: asymmetric protection and communications hardware
    # reinforce the Mechromancer as a vulnerable technician who survives by
    # carrying tools, not as a clean heroic avatar. These pieces are visual
    # only and do not alter the gameplay capsule or weapon sockets.
    ModelKit3D.add_beveled_box(
        detail,
        Vector3(0.5, 0.18, 0.46),
        Vector3(-0.44, 1.48, 0.08),
        steel,
        Vector3(-0.08, 0.0, 0.12),
        "FieldShoulderGuard",
        0.22
    )
    ModelKit3D.add_surface_panel(
        detail,
        Vector3(0.38, 0.42, 0.08),
        Vector3(0.38, 1.42, 0.08),
        dark_steel,
        cyan,
        Vector3(-0.04, 0.0, 0.0),
        "FieldCommsPanel"
    )
    ModelKit3D.add_cylinder(detail, 0.028, 0.58, Vector3(0.56, 1.78, 0.1), dark_steel, Vector3(0.08, 0.0, -0.12), "FieldCommsAntenna")
    ModelKit3D.add_sphere(detail, 0.05, Vector3(0.53, 2.06, 0.07), cyan, Vector3.ONE, "FieldCommsBeacon")
    ModelKit3D.add_beveled_box(detail, Vector3(0.18, 0.12, 0.32), Vector3(-0.34, 0.28, -0.34), rust, Vector3(0.0, 0.0, 0.08), "FieldBootCuff", 0.2)
    ModelKit3D.add_beveled_box(detail, Vector3(0.18, 0.12, 0.32), Vector3(0.34, 0.28, -0.34), rust, Vector3(0.0, 0.0, -0.08), "FieldBootCuff", 0.2)
    ModelKit3D.add_beveled_box(detail, Vector3(0.1, 0.34, 0.14), Vector3(-0.52, 0.86, -0.38), leather, Vector3(0.0, 0.0, 0.12), "WristToolLoop", 0.24)

    # Second-pass focal details make the technician read as a maintained field
    # instrument at tactical distance: protected shoulder hardware, a service
    # canister and restrained tool-deck parts add manufactured depth without
    # changing the authored skeleton, collision capsule or pistol contract.
    ModelKit3D.add_louvered_panel(
        detail,
        Vector3(0.42, 0.22, 0.16),
        Vector3(-0.44, 1.5, -0.18),
        dark_steel,
        steel,
        Vector3(-0.08, 0.0, 0.12),
        "FieldShoulderLampHousing",
        3
    )
    ModelKit3D.add_sphere(detail, 0.065, Vector3(-0.44, 1.48, -0.29), cyan, Vector3(1.0, 0.72, 0.72), "FieldShoulderLampLens")
    ModelKit3D.add_cylinder(detail, 0.13, 0.3, Vector3(-0.62, 0.78, 0.04), rust, Vector3(1.5708, 0.0, 0.0), "FieldUtilityCanister")
    ModelKit3D.add_cylinder(detail, 0.042, 0.34, Vector3(-0.62, 0.78, -0.13), dark_steel, Vector3(1.5708, 0.0, 0.0), "FieldUtilityCanisterClamp")
    ModelKit3D.add_beveled_box(detail, Vector3(0.38, 0.12, 0.22), Vector3(0.62, 0.72, 0.22), steel, Vector3(0.0, 0.0, -0.08), "FieldToolDeck", 0.18)
    ModelKit3D.add_beveled_box(detail, Vector3(0.06, 0.2, 0.26), Vector3(0.53, 0.86, 0.22), warm, Vector3(0.0, 0.0, -0.08), "FieldToolClamp", 0.28)

    # Field-finish pass: a restrained hood rim, visor housing, work gloves and
    # coat-hem hardware give the human technician a readable close-range
    # material break from head to hand to boot. These are visual-only pieces;
    # the authored skeleton, interaction sockets and gameplay capsule remain
    # untouched.
    ModelKit3D.add_torus(
        detail,
        0.28,
        0.028,
        Vector3(0.0, 1.91, 0.05),
        leather,
        Vector3.ZERO,
        "FieldHoodRim",
        36,
        8
    )
    ModelKit3D.add_surface_panel(
        detail,
        Vector3(0.34, 0.1, 0.05),
        Vector3(0.0, 1.82, -0.31),
        dark_steel,
        ceramic,
        Vector3(-0.03, 0.0, 0.0),
        "FieldVisorHousing"
    )
    ModelKit3D.add_capsule(
        detail,
        0.085,
        0.3,
        Vector3(-0.48, 0.68, -0.34),
        leather,
        Vector3(0.0, 0.0, 0.12),
        "FieldWorkGloveLeft"
    )
    ModelKit3D.add_capsule(
        detail,
        0.085,
        0.3,
        Vector3(0.48, 0.68, -0.34),
        leather,
        Vector3(0.0, 0.0, -0.12),
        "FieldWorkGloveRight"
    )
    ModelKit3D.add_beveled_box(
        detail,
        Vector3(0.32, 0.12, 0.16),
        Vector3(-0.23, 0.4, -0.2),
        leather,
        Vector3(0.0, 0.0, 0.08),
        "FieldCoatHemLeft",
        0.22
    )
    ModelKit3D.add_beveled_box(
        detail,
        Vector3(0.32, 0.12, 0.16),
        Vector3(0.23, 0.4, -0.2),
        leather,
        Vector3(0.0, 0.0, -0.08),
        "FieldCoatHemRight",
        0.22
    )

    # Hero micro-detail pass: a readable forearm diagnostic and protected knee
    # hardware sharpen the technician silhouette at close tactical distance.
    # These parts are deliberately small, asymmetric and presentation-only.
    ModelKit3D.add_surface_panel(
        detail,
        Vector3(0.24, 0.24, 0.07),
        Vector3(-0.5, 0.98, -0.38),
        finish_panel,
        finish_status,
        Vector3(-0.08, 0.0, 0.12),
        "FieldForearmDiagnostic"
    )
    ModelKit3D.add_sphere(detail, 0.045, Vector3(-0.5, 1.04, -0.425), finish_status, Vector3(1.5, 0.65, 0.42), "FieldForearmDiagnosticLens")
    ModelKit3D.add_beveled_box(detail, Vector3(0.24, 0.14, 0.3), Vector3(-0.2, 0.58, -0.34), steel, Vector3(-0.06, 0.0, 0.08), "FieldKneeGuardLeft", 0.2)
    ModelKit3D.add_beveled_box(detail, Vector3(0.24, 0.14, 0.3), Vector3(0.2, 0.58, -0.34), steel, Vector3(-0.06, 0.0, -0.08), "FieldKneeGuardRight", 0.2)
    ModelKit3D.add_cylinder(detail, 0.045, 0.12, Vector3(-0.48, 1.26, 0.02), finish_warning, Vector3(1.5708, 0.0, 0.0), "FieldCableClamp")

    # Final hero surface pass: a framed rear pack and exposed service cable
    # make the Mechromancer read as a maintained field instrument from the
    # three-quarter camera. The added parts are presentation-only and stay
    # clear of the authored skeleton, sockets and gameplay capsule.
    ModelKit3D.add_beveled_box(detail, Vector3(0.78, 0.1, 0.46), Vector3(0.0, 1.38, 0.54), leather, Vector3(-0.04, 0.0, 0.0), "FieldPackBackplate", 0.2)
    for side in [-1.0, 1.0]:
        var pack_side := float(side)
        ModelKit3D.add_beveled_box(detail, Vector3(0.07, 0.62, 0.08), Vector3(pack_side * 0.32, 1.16, 0.55), steel, Vector3(0.0, 0.0, pack_side * 0.06), "FieldPackFrameRail%s" % ("Left" if pack_side < 0.0 else "Right"), 0.22)
        ModelKit3D.add_sphere(detail, 0.06, Vector3(pack_side * 0.32, 1.48, 0.5), warm, Vector3(1.0, 0.72, 0.72), "FieldPackAnchor%s" % ("Left" if pack_side < 0.0 else "Right"))
    ModelKit3D.add_cylinder(detail, 0.12, 0.58, Vector3(0.0, 1.52, 0.55), rust, Vector3(0.0, 0.0, 1.5708), "FieldPackTopRoll")
    ModelKit3D.add_cylinder(detail, 0.026, 0.54, Vector3(-0.38, 1.48, 0.34), finish_cable, Vector3(0.28, 0.0, 0.0), "FieldPackServiceCable")

    # One practical lamp rather than glowing eyes all over the model.
    ModelKit3D.add_sphere(detail, 0.085, Vector3(-0.38, 1.48, -0.22), cyan, Vector3(1.0, 0.75, 0.55), "WorkLamp")
    var lamp := OmniLight3D.new()
    lamp.name = "MechromancerWorkLamp"
    lamp.position = Vector3(-0.4, 1.48, -0.35)
    lamp.light_color = Color("80dbe0")
    lamp.light_energy = 0.34
    lamp.omni_range = 3.7
    lamp.shadow_enabled = false
    detail.add_child(lamp)


func _polish_robot(robot: RobotUnit3D) -> void:
    var model := robot.get_node_or_null("RobotModel") as Node3D
    if model == null or model.get_node_or_null("VerticalSliceMachineArt") != null:
        return
    var detail := Node3D.new()
    detail.name = "VerticalSliceMachineArt"
    model.add_child(detail)

    match robot.archetype:
        &"companion":
            _build_bulwark_detail(detail)
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
    ModelKit3D.add_beveled_box(parent, Vector3(1.9, 0.62, 0.18), Vector3(0.0, 1.08, -0.92), steel, Vector3(-0.03, 0.0, 0.0), "BulwarkFrontPlate", 0.2)
    ModelKit3D.add_beveled_box(parent, Vector3(0.42, 0.82, 0.28), Vector3(-0.88, 0.86, -0.35), rust, Vector3(0.0, 0.0, 0.12), "BulwarkShoulderLeft", 0.16)
    ModelKit3D.add_beveled_box(parent, Vector3(0.42, 0.82, 0.28), Vector3(0.88, 0.86, -0.35), rust, Vector3(0.0, 0.0, -0.12), "BulwarkShoulderRight", 0.16)
    ModelKit3D.add_cylinder(parent, 0.11, 1.3, Vector3(-0.4, 1.4, -0.72), dark_steel, Vector3(1.5708, 0.0, 0.0), "BulwarkGunLeft")
    ModelKit3D.add_cylinder(parent, 0.11, 1.3, Vector3(0.4, 1.4, -0.72), dark_steel, Vector3(1.5708, 0.0, 0.0), "BulwarkGunRight")
    ModelKit3D.add_beveled_box(parent, Vector3(1.3, 0.16, 0.62), Vector3(0.0, 1.64, 0.42), black_metal(), Vector3.ZERO, "BulwarkRadiator", 0.2)
    # The companion's defining promise is protection. A compact, restrained
    # field arc and protected emitter spine make that role legible before
    # combat starts without turning the machine into a bright screen-space
    # halo or adding a second gameplay resource.
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
    parent.add_child(shield_ring)
    ModelKit3D.add_tapered_cylinder(parent, 0.12, 0.18, 0.62, Vector3(0.0, 1.94, 0.46), dark_steel, Vector3.ZERO, "BulwarkShieldEmitterSpine")
    ModelKit3D.add_sphere(parent, 0.13, Vector3(0.0, 2.28, 0.46), shield_material, Vector3(1.2, 0.7, 1.2), "BulwarkShieldEmitter")
    for side in [-1.0, 1.0]:
        ModelKit3D.add_beveled_box(parent, Vector3(0.16, 0.62, 0.46), Vector3(float(side) * 0.92, 1.08, 0.72), shield_material, Vector3(0.0, 0.0, float(side) * 0.08), "BulwarkShieldGuard", 0.14)
    ModelKit3D.add_louvered_panel(
        parent,
        Vector3(1.12, 0.28, 0.16),
        Vector3(0.0, 1.67, 0.43),
        dark_steel,
        steel,
        Vector3.ZERO,
        "BulwarkRadiatorLouver",
        4
    )
    ModelKit3D.add_surface_panel(
        parent,
        Vector3(0.82, 0.24, 0.08),
        Vector3(0.0, 1.48, -0.98),
        dark_steel,
        shield_material,
        Vector3.ZERO,
        "BulwarkFrontSensorVisor"
    )
    # The companion's front face now has a shallow service interface and
    # guarded feet: manufactured depth that supports the protection fantasy
    # without adding another glow source or gameplay socket.
    ModelKit3D.add_surface_panel(
        parent,
        Vector3(0.58, 0.2, 0.07),
        Vector3(0.0, 1.1, -1.25),
        finish_panel,
        finish_warning,
        Vector3(-0.04, 0.0, 0.0),
        "BulwarkServiceFace"
    )
    for side in [-1.0, 1.0]:
        var side_sign := float(side)
        ModelKit3D.add_cylinder(parent, 0.045, 0.1, Vector3(side_sign * 0.22, 1.1, -1.31), finish_warning, Vector3(1.5708, 0.0, 0.0), "BulwarkServiceLatch%s" % ("Left" if side_sign < 0.0 else "Right"))
        ModelKit3D.add_beveled_box(parent, Vector3(0.5, 0.1, 0.16), Vector3(side_sign * 0.7, 1.43, -0.34), steel, Vector3(0.0, 0.0, side_sign * 0.08), "BulwarkShoulderRail%s" % ("Left" if side_sign < 0.0 else "Right"), 0.18)
        ModelKit3D.add_beveled_box(parent, Vector3(0.46, 0.1, 0.38), Vector3(side_sign * 0.68, 0.18, -0.66), dark_steel, Vector3.ZERO, "BulwarkFootPlate%s" % ("Left" if side_sign < 0.0 else "Right"), 0.2)
        # Side-mounted actuator rings and heat panels complete the companion's
        # protected silhouette without introducing another combat signal.
        ModelKit3D.add_torus(parent, 0.16, 0.035, Vector3(side_sign * 0.98, 0.9, -0.45), finish_warning, Vector3(1.5708, 0.0, 0.0), "BulwarkActuatorRing%s" % ("Left" if side_sign < 0.0 else "Right"), 24, 8)
        ModelKit3D.add_sphere(parent, 0.09, Vector3(side_sign * 0.98, 0.9, -0.49), dark_steel, Vector3(1.0, 0.72, 0.72), "BulwarkActuatorCap%s" % ("Left" if side_sign < 0.0 else "Right"))
        ModelKit3D.add_louvered_panel(parent, Vector3(0.28, 0.34, 0.14), Vector3(side_sign * 0.84, 1.0, 0.48), dark_steel, steel, Vector3(0.0, side_sign * 1.5708, 0.0), "BulwarkSideHeatPanel%s" % ("Left" if side_sign < 0.0 else "Right"), 3)
    ModelKit3D.add_surface_panel(parent, Vector3(0.38, 0.12, 0.05), Vector3(0.0, 1.1, -1.31), finish_panel, finish_status, Vector3(-0.04, 0.0, 0.0), "BulwarkServiceWindowFrame")
    var emitter_collar := MeshInstance3D.new()
    emitter_collar.name = "BulwarkEmitterCollar"
    var emitter_mesh := TorusMesh.new()
    emitter_mesh.inner_radius = 0.16
    emitter_mesh.outer_radius = 0.21
    emitter_mesh.rings = 16
    emitter_mesh.ring_segments = 32
    emitter_collar.mesh = emitter_mesh
    emitter_collar.material_override = shield_material
    emitter_collar.position = Vector3(0.0, 2.28, 0.46)
    emitter_collar.rotation.x = PI * 0.5
    parent.add_child(emitter_collar)
    _add_machine_lamp(parent, Vector3(0.0, 1.42, -1.0), Color("f0a65a"), 0.42)


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


func _polish_heartforge(forge: Heartforge3D) -> void:
    var model := forge.get_node_or_null("HeartforgeModel") as Node3D
    if model == null or model.get_node_or_null("VerticalSliceForgeArt") != null:
        return
    var detail := Node3D.new()
    detail.name = "VerticalSliceForgeArt"
    model.add_child(detail)

    # External pipework and service manifolds make the forge read as a machine
    # assembled from municipal infrastructure rather than a glowing cylinder.
    for side in [-1.0, 1.0]:
        ModelKit3D.add_cylinder(detail, 0.18, 3.0, Vector3(side * 2.15, 1.6, 0.9), steel, Vector3(0.0, 0.0, side * 0.12), "ForgeCoolantStack")
        ModelKit3D.add_cylinder(detail, 0.12, 2.3, Vector3(side * 1.7, 2.2, -1.55), rust, Vector3(1.1, 0.0, side * 0.2), "ForgePressurePipe")
        ModelKit3D.add_beveled_box(detail, Vector3(0.72, 0.6, 0.52), Vector3(side * 2.15, 0.72, 1.2), dark_steel, Vector3.ZERO, "ForgePump", 0.2)
    for index in range(5):
        var angle := -1.1 + float(index) * 0.55
        ModelKit3D.add_beveled_box(detail, Vector3(0.36, 0.18, 0.52), Vector3(cos(angle) * 1.9, 3.45, sin(angle) * 1.9), rust, Vector3(0.0, -angle, 0.08), "ForgeTopClamp", 0.22)
    ModelKit3D.add_beveled_box(detail, Vector3(1.4, 0.24, 0.9), Vector3(-2.65, 1.1, -0.2), dark_steel, Vector3.ZERO, "ForgeControlCabinet", 0.18)
    ModelKit3D.add_beveled_box(detail, Vector3(1.0, 0.08, 0.55), Vector3(-2.65, 1.28, -0.47), cyan, Vector3.ZERO, "ForgeDiagnosticPanel", 0.2)


func _add_machine_lamp(parent: Node3D, position: Vector3, color: Color, energy: float) -> void:
    ModelKit3D.add_sphere(parent, 0.07, position, ModelKit3D.material(color.darkened(0.58), 0.25, 0.25, color, 1.8), Vector3.ONE, "MachineLamp")
    var light := OmniLight3D.new()
    light.position = position
    light.light_color = color
    light.light_energy = energy
    light.omni_range = 3.2
    light.shadow_enabled = false
    parent.add_child(light)


func black_metal() -> StandardMaterial3D:
    return dark_steel
