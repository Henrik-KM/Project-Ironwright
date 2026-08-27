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
var route_recovery_beacon: Node3D
var route_recovery_label: Label3D
var route_recovery_ring: MeshInstance3D
var route_recovery_material: StandardMaterial3D
var route_recovery_elapsed: float = 0.0
var casualty_recovery_beacon: Node3D
var casualty_recovery_label: Label3D
var casualty_recovery_ring: MeshInstance3D
var casualty_recovery_elapsed: float = 0.0


func configure(next_camera: Camera3D) -> void:
    camera = next_camera


func _ready() -> void:
    _build_route_recovery_beacon()


func _process(delta: float) -> void:
    if route_recovery_beacon != null and route_recovery_beacon.visible:
        route_recovery_elapsed += delta
        var pulse := 0.92 + sin(route_recovery_elapsed * 3.1) * 0.08
        route_recovery_beacon.scale = Vector3.ONE * pulse
        if route_recovery_ring != null:
            route_recovery_ring.rotation.y = route_recovery_elapsed * 0.72
            route_recovery_ring.position.y = 2.72 + sin(route_recovery_elapsed * 2.4) * 0.08
        if route_recovery_label != null:
            route_recovery_label.position.y = 3.28 + sin(route_recovery_elapsed * 2.1) * 0.07
    if casualty_recovery_beacon != null and casualty_recovery_beacon.visible:
        casualty_recovery_elapsed += delta
        var casualty_pulse := 0.94 + sin(casualty_recovery_elapsed * 2.7) * 0.06
        casualty_recovery_beacon.scale = Vector3.ONE * casualty_pulse
        if casualty_recovery_ring != null:
            casualty_recovery_ring.rotation.y = casualty_recovery_elapsed * -0.66


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


func show_route_recovery(operation_id: StringName, target: Vector3, attempt: int, limit: int) -> void:
    if route_recovery_beacon == null:
        _build_route_recovery_beacon()
    route_recovery_beacon.global_position = target
    route_recovery_beacon.visible = true
    route_recovery_label.text = "AUTONOMOUS DETOUR\nSIDE ROUTE %d/%d · %s" % [attempt, limit, String(operation_id).replace("operation.", "")]


func clear_route_recovery() -> void:
    if route_recovery_beacon != null:
        route_recovery_beacon.visible = false


func show_casualty_recovery(record_id: StringName, target: Vector3, identity: String) -> void:
    if casualty_recovery_beacon == null:
        _build_casualty_recovery_beacon()
    casualty_recovery_beacon.global_position = target
    casualty_recovery_beacon.visible = true
    casualty_recovery_label.text = "CASUALTY BEACON\n%s · %s" % [identity.to_upper(), String(record_id).replace("casualty.", "FIELD SIGNAL ")]


func clear_casualty_recovery() -> void:
    if casualty_recovery_beacon != null:
        casualty_recovery_beacon.visible = false


func is_casualty_recovery_visible() -> bool:
    return casualty_recovery_beacon != null and casualty_recovery_beacon.visible


func is_route_recovery_visible() -> bool:
    return route_recovery_beacon != null and route_recovery_beacon.visible


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


func _build_route_recovery_beacon() -> void:
    if route_recovery_beacon != null:
        return
    var housing_material := ModelKit3D.material(Color("17282d"), 0.58, 0.42)
    var edge_material := ModelKit3D.material(Color("29525a"), 0.42, 0.34, Color("4daeb0"), 0.72)
    # Keep the detour cue legible in a busy street without washing out the
    # Heartforge key light, nearby actors or the route itself. It is a warning
    # marker, not a permanent beacon competing with the scene focal point.
    route_recovery_material = ModelKit3D.material(Color("123d49"), 0.18, 0.3, Color("5ce0d1"), 1.65)
    route_recovery_beacon = Node3D.new()
    route_recovery_beacon.name = "AutonomousRouteRecoveryBeacon"
    route_recovery_beacon.visible = false
    add_child(route_recovery_beacon)
    ModelKit3D.add_beveled_box(
        route_recovery_beacon,
        Vector3(2.75, 0.18, 2.75),
        Vector3(0.0, 0.1, 0.0),
        housing_material,
        Vector3.ZERO,
        "DetourBaseHousing",
        0.22
    )
    var collar := MeshInstance3D.new()
    collar.name = "DetourBaseCollar"
    var collar_mesh := TorusMesh.new()
    collar_mesh.inner_radius = 0.64
    collar_mesh.outer_radius = 0.74
    collar_mesh.rings = 16
    collar_mesh.ring_segments = 28
    collar.mesh = collar_mesh
    collar.material_override = edge_material
    collar.position = Vector3(0.0, 0.25, 0.0)
    collar.rotation.x = PI * 0.5
    collar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    route_recovery_beacon.add_child(collar)
    for index in range(4):
        var angle := TAU * float(index) / 4.0 + PI * 0.25
        var direction_plate := ModelKit3D.add_beveled_box(
            route_recovery_beacon,
            Vector3(0.58, 0.08, 0.22),
            Vector3(cos(angle) * 0.76, 0.27, sin(angle) * 0.76),
            route_recovery_material,
            Vector3(0.0, -angle, 0.0),
            "DetourDirection%02d" % index,
            0.1
        )
    for index in range(8):
        var angle := TAU * float(index) / 8.0
        var segment := ModelKit3D.add_box(
            route_recovery_beacon,
            Vector3(0.68, 0.06, 0.12),
            Vector3(cos(angle) * 1.18, 0.08, sin(angle) * 1.18),
            route_recovery_material,
            Vector3(0.0, -angle, 0.0),
            "DetourRingSegment"
        )
        segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var stem := ModelKit3D.add_tapered_cylinder(
        route_recovery_beacon,
        0.045,
        0.09,
        2.52,
        Vector3(0.0, 1.28, 0.0),
        route_recovery_material,
        Vector3.ZERO,
        "DetourStem"
    )
    stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    ModelKit3D.add_beveled_box(
        route_recovery_beacon,
        Vector3(0.42, 0.12, 0.42),
        Vector3(0.0, 0.31, 0.0),
        edge_material,
        Vector3.ZERO,
        "DetourStemCollar",
        0.12
    )
    var crown := ModelKit3D.add_sphere(
        route_recovery_beacon,
        0.17,
        Vector3(0.0, 2.7, 0.0),
        route_recovery_material,
        Vector3(1.0, 0.56, 1.0),
        "DetourCrown"
    )
    crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    route_recovery_ring = MeshInstance3D.new()
    route_recovery_ring.name = "DetourSignalRing"
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.24
    ring_mesh.outer_radius = 0.38
    ring_mesh.rings = 18
    ring_mesh.ring_segments = 32
    route_recovery_ring.mesh = ring_mesh
    route_recovery_ring.material_override = route_recovery_material
    route_recovery_ring.position = Vector3(0.0, 2.72, 0.0)
    route_recovery_ring.rotation.x = PI * 0.5
    route_recovery_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    route_recovery_beacon.add_child(route_recovery_ring)
    route_recovery_label = Label3D.new()
    route_recovery_label.name = "DetourLabel"
    route_recovery_label.text = "AUTONOMOUS DETOUR"
    route_recovery_label.position = Vector3(0.0, 3.28, 0.0)
    route_recovery_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    route_recovery_label.fixed_size = false
    route_recovery_label.font_size = 17
    route_recovery_label.pixel_size = 0.014
    route_recovery_label.outline_size = 4
    route_recovery_label.modulate = Color("b9eee6")
    route_recovery_label.outline_modulate = Color(0.01, 0.025, 0.03, 0.96)
    route_recovery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    route_recovery_label.no_depth_test = false
    route_recovery_beacon.add_child(route_recovery_label)
    ModelKit3D.add_glow_light(route_recovery_beacon, Vector3(0.0, 1.35, 0.0), Color("5ce0d1"), 0.2, 2.8)


func _build_casualty_recovery_beacon() -> void:
    if casualty_recovery_beacon != null:
        return
    var material := ModelKit3D.material(Color("4a241a"), 0.18, 0.36, Color("ef8c55"), 3.6)
    casualty_recovery_beacon = Node3D.new()
    casualty_recovery_beacon.name = "DisabledMachineRecoveryBeacon"
    casualty_recovery_beacon.visible = false
    add_child(casualty_recovery_beacon)
    for index in range(6):
        var angle := TAU * float(index) / 6.0
        var segment := ModelKit3D.add_box(
            casualty_recovery_beacon,
            Vector3(0.72, 0.075, 0.14),
            Vector3(cos(angle) * 1.06, 0.09, sin(angle) * 1.06),
            material,
            Vector3(0.0, -angle, 0.0),
            "CasualtyRingSegment"
        )
        segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var stem := ModelKit3D.add_tapered_cylinder(
        casualty_recovery_beacon,
        0.055,
        0.11,
        2.26,
        Vector3(0.0, 1.15, 0.0),
        material,
        Vector3.ZERO,
        "CasualtyStem"
    )
    stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    ModelKit3D.add_sphere(
        casualty_recovery_beacon,
        0.2,
        Vector3(0.0, 2.42, 0.0),
        material,
        Vector3(1.0, 0.58, 1.0),
        "CasualtySignal"
    )
    casualty_recovery_ring = MeshInstance3D.new()
    casualty_recovery_ring.name = "CasualtySignalRing"
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 0.22
    ring_mesh.outer_radius = 0.36
    ring_mesh.rings = 16
    ring_mesh.ring_segments = 28
    casualty_recovery_ring.mesh = ring_mesh
    casualty_recovery_ring.material_override = material
    casualty_recovery_ring.position = Vector3(0.0, 2.44, 0.0)
    casualty_recovery_ring.rotation.x = PI * 0.5
    casualty_recovery_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    casualty_recovery_beacon.add_child(casualty_recovery_ring)
    casualty_recovery_label = Label3D.new()
    casualty_recovery_label.name = "CasualtyLabel"
    casualty_recovery_label.text = "CASUALTY BEACON"
    casualty_recovery_label.position = Vector3(0.0, 3.08, 0.0)
    casualty_recovery_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    casualty_recovery_label.font_size = 20
    casualty_recovery_label.pixel_size = 0.018
    casualty_recovery_label.outline_size = 5
    casualty_recovery_label.modulate = Color("ffe0c4")
    casualty_recovery_label.outline_modulate = Color(0.03, 0.012, 0.008, 0.96)
    casualty_recovery_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    casualty_recovery_beacon.add_child(casualty_recovery_label)
    ModelKit3D.add_glow_light(casualty_recovery_beacon, Vector3(0.0, 1.15, 0.0), Color("ef8c55"), 0.48, 3.8)
