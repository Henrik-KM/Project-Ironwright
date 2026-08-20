class_name OperationDetailDirector3D
extends Node

## Keeps remote operations continuous while allowing distant groups to skip
## per-frame actor steering. Reduced detail is an optimization of the same
## route, anchor and assignment state, not a detached mission result.

signal detail_changed(operation_id: StringName, detail_mode: StringName)

const ACTIVE_RADIUS := 34.0
const RETURN_TO_ACTIVE_RADIUS := 27.0
const FORMATION_RULES := preload("res://scripts/systems/formation_rules_3d.gd")

var camera: Camera3D
var modes: Dictionary = {}


func configure(next_camera: Camera3D) -> void:
    camera = next_camera


func update_operation(operation_id: StringName, anchor: Vector3) -> StringName:
    var previous := StringName(modes.get(operation_id, &"active"))
    var next := previous
    if camera == null:
        next = &"active"
    else:
        var distance := camera.global_position.distance_to(anchor)
        if previous == &"reduced" and distance <= RETURN_TO_ACTIVE_RADIUS:
            next = &"active"
        elif previous == &"active" and distance >= ACTIVE_RADIUS:
            next = &"reduced"
    modes[operation_id] = next
    if next != previous:
        detail_changed.emit(operation_id, next)
    return next


func clear_operation(operation_id: StringName) -> void:
    modes.erase(operation_id)


func mode_for(operation_id: StringName) -> StringName:
    return StringName(modes.get(operation_id, &"active"))


func apply_reduced_formation(anchor: Vector3, forward: Vector3, members: Array) -> void:
    for index in range(members.size()):
        var robot := members[index] as Node3D
        if robot == null or not is_instance_valid(robot):
            continue
        var archetype := StringName(str(robot.get("archetype")))
        var offset := FORMATION_RULES.formation_offset(index, archetype)
        var destination := anchor + FORMATION_RULES.rotated_offset(offset, forward)
        robot.global_position = destination
        if robot is CharacterBody3D:
            (robot as CharacterBody3D).velocity = Vector3.ZERO


func apply_reduced_salvage(assignments: Dictionary, home: Vector3) -> void:
    for raw_assignment in assignments.values():
        if not (raw_assignment is Dictionary):
            continue
        var assignment := raw_assignment as Dictionary
        var robot := assignment.get("robot") as Node3D
        if robot == null or not is_instance_valid(robot):
            continue
        var state := StringName(str(assignment.get("state", "idle")))
        var target := assignment.get("target") as Node3D
        var destination := home
        if state in [&"outbound", &"working"] and target != null and is_instance_valid(target):
            destination = target.global_position
        elif state == &"returning":
            destination = home
        robot.global_position = destination
        if robot is CharacterBody3D:
            (robot as CharacterBody3D).velocity = Vector3.ZERO
