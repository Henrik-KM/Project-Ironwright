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


func configure(next_world: Node) -> void:
    world = next_world


func _ready() -> void:
    steel = ModelKit3D.material(Color("39464b"), 0.74, 0.34)
    dark_steel = ModelKit3D.material(Color("151d20"), 0.84, 0.3)
    rust = ModelKit3D.material(Color("6b3e29"), 0.48, 0.67)
    fabric = ModelKit3D.material(Color("202a31"), 0.03, 0.94)
    leather = ModelKit3D.material(Color("493329"), 0.06, 0.88)
    cyan = ModelKit3D.material(Color("23454b"), 0.34, 0.26, Color("6adbe1"), 1.7)
    warm = ModelKit3D.material(Color("72421f"), 0.24, 0.32, Color("f29a48"), 1.65)
    ceramic = ModelKit3D.material(Color("707777"), 0.08, 0.72)
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
    if node.is_in_group(&"player_character") or node.is_in_group(&"friendly_robots") or node.is_in_group(&"heartforge"):
        call_deferred("_polish", node)


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
    ModelKit3D.add_box(detail, Vector3(0.56, 0.16, 0.32), Vector3(0.0, 1.66, -0.13), dark_steel, Vector3(0.08, 0.0, 0.0), "RespiratorCollar")
    ModelKit3D.add_box(detail, Vector3(0.28, 0.16, 0.18), Vector3(0.0, 1.72, -0.28), ceramic, Vector3.ZERO, "RespiratorMask")

    # Layered scavenger rig gives the body asymmetry and identifies the
    # Mechromancer as a field mechanic, not a generic mobile-game hero.
    ModelKit3D.add_box(detail, Vector3(0.7, 0.88, 0.34), Vector3(0.0, 1.08, 0.34), leather, Vector3(-0.05, 0.0, 0.02), "FieldPack")
    ModelKit3D.add_box(detail, Vector3(0.82, 0.1, 0.08), Vector3(0.0, 1.4, -0.28), rust, Vector3(0.0, 0.0, -0.05), "ChestHarness")
    ModelKit3D.add_box(detail, Vector3(0.1, 0.8, 0.08), Vector3(-0.28, 1.05, -0.24), leather, Vector3(0.0, 0.0, 0.08), "HarnessStrap")
    ModelKit3D.add_box(detail, Vector3(0.1, 0.8, 0.08), Vector3(0.28, 1.05, -0.24), leather, Vector3(0.0, 0.0, -0.08), "HarnessStrap")
    ModelKit3D.add_cylinder(detail, 0.18, 0.46, Vector3(-0.43, 1.06, 0.38), rust, Vector3(1.5708, 0.0, 0.0), "CableSpool")
    ModelKit3D.add_cylinder(detail, 0.045, 0.5, Vector3(-0.43, 1.06, 0.12), dark_steel, Vector3(1.5708, 0.0, 0.0), "CableSpoolAxle")
    ModelKit3D.add_box(detail, Vector3(0.24, 0.5, 0.18), Vector3(0.48, 0.92, 0.3), rust, Vector3(0.0, 0.0, -0.08), "ToolRoll")

    # Weak pistol is visibly improvised and small relative to the machines.
    ModelKit3D.add_box(detail, Vector3(0.13, 0.15, 0.65), Vector3(0.48, 1.06, -0.42), dark_steel, Vector3(0.0, 0.0, 0.01), "PistolSlide")
    ModelKit3D.add_cylinder(detail, 0.045, 0.62, Vector3(0.48, 1.08, -0.72), steel, Vector3(1.5708, 0.0, 0.0), "PistolBarrel")
    ModelKit3D.add_box(detail, Vector3(0.14, 0.38, 0.16), Vector3(0.48, 0.83, -0.27), leather, Vector3(0.1, 0.0, 0.0), "PistolGrip")

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
        _:
            _build_scrapper_detail(detail)


func _build_bulwark_detail(parent: Node3D) -> void:
    ModelKit3D.add_box(parent, Vector3(1.9, 0.62, 0.18), Vector3(0.0, 1.08, -0.92), steel, Vector3(-0.03, 0.0, 0.0), "BulwarkFrontPlate")
    ModelKit3D.add_box(parent, Vector3(0.42, 0.82, 0.28), Vector3(-0.88, 0.86, -0.35), rust, Vector3(0.0, 0.0, 0.12), "BulwarkShoulderLeft")
    ModelKit3D.add_box(parent, Vector3(0.42, 0.82, 0.28), Vector3(0.88, 0.86, -0.35), rust, Vector3(0.0, 0.0, -0.12), "BulwarkShoulderRight")
    ModelKit3D.add_cylinder(parent, 0.11, 1.3, Vector3(-0.4, 1.4, -0.72), dark_steel, Vector3(1.5708, 0.0, 0.0), "BulwarkGunLeft")
    ModelKit3D.add_cylinder(parent, 0.11, 1.3, Vector3(0.4, 1.4, -0.72), dark_steel, Vector3(1.5708, 0.0, 0.0), "BulwarkGunRight")
    ModelKit3D.add_box(parent, Vector3(1.3, 0.16, 0.62), Vector3(0.0, 1.64, 0.42), black_metal(), Vector3.ZERO, "BulwarkRadiator")
    _add_machine_lamp(parent, Vector3(0.0, 1.42, -1.0), Color("f0a65a"), 0.42)


func _build_warden_detail(parent: Node3D) -> void:
    for side in [-1.0, 1.0]:
        ModelKit3D.add_box(parent, Vector3(0.46, 0.8, 1.3), Vector3(side * 0.78, 0.85, 0.05), steel, Vector3(0.0, 0.0, side * 0.08), "WardenSidePlate")
    ModelKit3D.add_cylinder(parent, 0.12, 1.45, Vector3(0.0, 1.42, -0.78), dark_steel, Vector3(1.5708, 0.0, 0.0), "WardenAutocannon")
    ModelKit3D.add_box(parent, Vector3(0.54, 0.38, 0.56), Vector3(0.0, 1.42, -0.55), rust, Vector3.ZERO, "WardenBreech")
    ModelKit3D.add_box(parent, Vector3(1.6, 0.15, 0.46), Vector3(0.0, 0.46, 0.84), dark_steel, Vector3(0.0, 0.0, -0.08), "WardenCounterweight")
    _add_machine_lamp(parent, Vector3(-0.36, 1.36, -0.9), Color("e9a65b"), 0.34)
    _add_machine_lamp(parent, Vector3(0.36, 1.36, -0.9), Color("e9a65b"), 0.34)


func _build_scrapper_detail(parent: Node3D) -> void:
    ModelKit3D.add_box(parent, Vector3(1.18, 0.72, 1.0), Vector3(0.0, 1.5, 0.28), dark_steel, Vector3(0.06, 0.0, 0.0), "DeepScrapHopper")
    for side in [-1.0, 1.0]:
        ModelKit3D.add_cylinder(parent, 0.095, 1.25, Vector3(side * 0.72, 0.92, -0.18), rust, Vector3(0.0, 0.0, side * 1.0), "ScrapManipulator")
        ModelKit3D.add_box(parent, Vector3(0.32, 0.18, 0.52), Vector3(side * 1.15, 0.6, -0.2), steel, Vector3(0.0, 0.0, side * 0.16), "ScrapClaw")
    ModelKit3D.add_cylinder(parent, 0.18, 0.34, Vector3(0.0, 1.12, -0.92), dark_steel, Vector3(1.5708, 0.0, 0.0), "CuttingHead")
    _add_machine_lamp(parent, Vector3(0.0, 1.22, -0.98), Color("6bd7de"), 0.3)


func _build_pathfinder_detail(parent: Node3D) -> void:
    ModelKit3D.add_cylinder(parent, 0.06, 1.9, Vector3(0.0, 2.0, 0.14), dark_steel, Vector3.ZERO, "PathfinderMast")
    ModelKit3D.add_sphere(parent, 0.28, Vector3(0.0, 2.72, 0.14), steel, Vector3(1.4, 0.35, 1.4), "PathfinderDish")
    for side in [-1.0, 1.0]:
        ModelKit3D.add_box(parent, Vector3(0.72, 0.08, 0.42), Vector3(side * 0.72, 1.42, 0.08), dark_steel, Vector3(0.0, 0.0, side * 0.12), "PathfinderSensorWing")
        _add_machine_lamp(parent, Vector3(side * 0.65, 1.42, -0.3), Color("82d68a"), 0.24)


func _build_engineer_detail(parent: Node3D) -> void:
    ModelKit3D.add_box(parent, Vector3(1.22, 0.5, 0.86), Vector3(0.0, 1.56, 0.26), dark_steel, Vector3.ZERO, "EngineerToolCradle")
    ModelKit3D.add_cylinder(parent, 0.09, 1.35, Vector3(-0.78, 1.12, -0.1), rust, Vector3(0.0, 0.0, 1.08), "EngineerWelderBoom")
    ModelKit3D.add_cylinder(parent, 0.1, 1.42, Vector3(0.78, 1.12, 0.0), steel, Vector3(0.0, 0.0, -1.04), "EngineerClampBoom")
    ModelKit3D.add_box(parent, Vector3(0.32, 0.22, 0.46), Vector3(1.28, 0.78, -0.02), steel, Vector3.ZERO, "EngineerClamp")
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
        ModelKit3D.add_box(detail, Vector3(0.72, 0.6, 0.52), Vector3(side * 2.15, 0.72, 1.2), dark_steel, Vector3.ZERO, "ForgePump")
    for index in range(5):
        var angle := -1.1 + float(index) * 0.55
        ModelKit3D.add_box(detail, Vector3(0.36, 0.18, 0.52), Vector3(cos(angle) * 1.9, 3.45, sin(angle) * 1.9), rust, Vector3(0.0, -angle, 0.08), "ForgeTopClamp")
    ModelKit3D.add_box(detail, Vector3(1.4, 0.24, 0.9), Vector3(-2.65, 1.1, -0.2), dark_steel, Vector3.ZERO, "ForgeControlCabinet")
    ModelKit3D.add_box(detail, Vector3(1.0, 0.08, 0.55), Vector3(-2.65, 1.28, -0.47), cyan, Vector3.ZERO, "ForgeDiagnosticPanel")


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
