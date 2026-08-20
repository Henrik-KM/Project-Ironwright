class_name ReleaseAnimationDirector3D
extends Node

var world: Node
var settings_service: ReleaseSettingsService3D
var attached_subjects: Dictionary = {}
var scan_clock: float = 0.0


func configure(next_world: Node, next_settings: ReleaseSettingsService3D) -> void:
    world = next_world
    settings_service = next_settings


func _ready() -> void:
    add_to_group(&"release_animation_director")
    get_tree().node_added.connect(_on_node_added)
    call_deferred("_scan_world")


func _process(delta: float) -> void:
    scan_clock += delta
    if scan_clock < 2.0:
        return
    scan_clock = 0.0
    _scan_world()


func _on_node_added(node: Node) -> void:
    call_deferred("_consider_subject", node)


func _scan_world() -> void:
    if world == null:
        world = get_parent()
    _scan_recursive(world)


func _scan_recursive(node: Node) -> void:
    _consider_subject(node)
    for child in node.get_children():
        _scan_recursive(child)


func _consider_subject(node: Variant) -> void:
    if not is_instance_valid(node) or not (node is Node) or not (node is Node3D):
        return
    if attached_subjects.has(node):
        return
    if not _contains_release_motion_target(node):
        return
    var motion := ReleaseSecondaryMotion3D.new()
    motion.name = "ReleaseSecondaryMotion3D"
    motion.configure(node as Node3D, settings_service)
    node.add_child(motion)
    attached_subjects[node] = motion


func _contains_release_motion_target(node: Node) -> bool:
    if node is RobotUnit3D or node is OrganicEnemy3D or node is Outpost3D:
        return true
    var name_text := String(node.name)
    return (
        name_text.begins_with("Release_")
        or name_text == "HeartforgeReleaseDressing"
        or name_text == "ReleaseWorldDressing"
    )
