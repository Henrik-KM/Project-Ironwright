class_name ReleaseSecondaryMotion3D
extends Node

var subject: Node3D
var settings_service: ReleaseSettingsService3D
var phase: float = 0.0
var deterministic_offset: float = 0.0
var animated_nodes: Array[Node3D] = []
var base_transforms: Dictionary = {}


func configure(next_subject: Node3D, next_settings: ReleaseSettingsService3D) -> void:
    subject = next_subject
    settings_service = next_settings


func _ready() -> void:
    if subject == null:
        subject = get_parent() as Node3D
    if subject == null:
        set_process(false)
        return
    deterministic_offset = float(subject.get_instance_id() % 997) * 0.019
    call_deferred("_capture_nodes")


func _capture_nodes() -> void:
    animated_nodes.clear()
    base_transforms.clear()
    _capture_recursive(subject)
    if animated_nodes.is_empty():
        set_process(false)


func _capture_recursive(node: Node) -> void:
    for child in node.get_children():
        if child is Node3D:
            var node_3d := child as Node3D
            if _is_release_animated_name(String(node_3d.name)):
                animated_nodes.append(node_3d)
                base_transforms[node_3d] = node_3d.transform
        _capture_recursive(child)


func _process(delta: float) -> void:
    if subject == null or not is_instance_valid(subject):
        return
    phase = fmod(phase + delta, TAU * 16.0)
    var motion_scale := 1.0
    if settings_service != null and bool(settings_service.get_value(&"reduced_motion", false)):
        motion_scale = 0.22
    for node in animated_nodes:
        if not is_instance_valid(node) or not base_transforms.has(node):
            continue
        node.transform = base_transforms[node]
        _animate_node(node, motion_scale)


func _animate_node(node: Node3D, motion_scale: float) -> void:
    var node_name := String(node.name)
    var local_phase := phase + deterministic_offset + float(node.get_instance_id() % 31) * 0.13
    if node_name.begins_with("WelderArm"):
        node.rotation.x += sin(local_phase * 5.2) * 0.28 * motion_scale
        node.rotation.z += cos(local_phase * 2.4) * 0.08 * motion_scale
    elif node_name.begins_with("AssemblyArm") or node_name.begins_with("RepairArm"):
        node.rotation.x += sin(local_phase * 2.6) * 0.24 * motion_scale
        node.rotation.y += cos(local_phase * 1.7) * 0.14 * motion_scale
    elif node_name.begins_with("ExtractorArm"):
        node.rotation.y += sin(local_phase * 1.3) * 0.22 * motion_scale
    elif node_name.begins_with("Wing") or node_name.begins_with("GlideMembrane"):
        node.rotation.z += sin(local_phase * 7.5) * 0.3 * motion_scale
        node.rotation.x += cos(local_phase * 3.2) * 0.08 * motion_scale
    elif node_name.begins_with("SignalBell"):
        node.scale *= Vector3(1.0 + sin(local_phase * 2.2) * 0.045 * motion_scale, 1.0 - sin(local_phase * 2.2) * 0.035 * motion_scale, 1.0 + sin(local_phase * 2.2) * 0.045 * motion_scale)
    elif node_name.begins_with("RootArm") or node_name.begins_with("RootPylon"):
        node.rotation.z += sin(local_phase * 0.95) * 0.07 * motion_scale
        node.rotation.x += cos(local_phase * 0.7) * 0.045 * motion_scale
    elif node_name.begins_with("LeapLeg"):
        node.rotation.x += sin(local_phase * 4.3) * 0.12 * motion_scale
    elif node_name.begins_with("SensorDish") or node_name.begins_with("ObservatoryDish"):
        node.rotation.y += local_phase * 0.11 * motion_scale
    elif node_name.begins_with("DefenceBarrel") or node_name.begins_with("TurretMast"):
        node.rotation.y += sin(local_phase * 0.8) * 0.22 * motion_scale
    elif node_name.begins_with("HangingCloth"):
        node.rotation.z += sin(local_phase * 1.8) * 0.08 * motion_scale
    elif node_name.begins_with("MyceliumGlow") or node_name.begins_with("RootSignal"):
        var pulse := 1.0 + sin(local_phase * 2.8) * 0.13 * motion_scale
        node.scale *= Vector3.ONE * pulse


func _is_release_animated_name(node_name: String) -> bool:
    for prefix in [
        "WelderArm",
        "AssemblyArm",
        "RepairArm",
        "ExtractorArm",
        "Wing",
        "GlideMembrane",
        "SignalBell",
        "RootArm",
        "RootPylon",
        "LeapLeg",
        "SensorDish",
        "ObservatoryDish",
        "DefenceBarrel",
        "TurretMast",
        "HangingCloth",
        "MyceliumGlow",
        "RootSignal",
    ]:
        if node_name.begins_with(prefix):
            return true
    return false
