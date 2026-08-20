class_name ProceduralAnimator3D
extends Node

## Lightweight authored motion for the procedural prototype models.
## This node affects presentation only: collision, navigation and decisions
## remain owned by the parent actor.

var subject: Node3D
var model_root: Node3D
var base_transforms: Dictionary = {}
var phase: float = 0.0
var idle_phase: float = 0.0
var recoil: float = 0.0
var hit_impulse: float = 0.0
var deterministic_offset: float = 0.0
var _has_state_name: bool = false
var _has_channel_kind: bool = false
var _last_health: float = -1.0


func configure(next_subject: Node3D) -> void:
    subject = next_subject


func _ready() -> void:
    if subject == null:
        subject = get_parent() as Node3D
    if subject == null:
        set_process(false)
        return
    deterministic_offset = float(subject.get_instance_id() % 997) * 0.017
    _has_state_name = _property_exists(subject, &"state_name")
    _has_channel_kind = _property_exists(subject, &"channel_kind")
    _resolve_model_root()
    if model_root == null:
        call_deferred("_resolve_and_capture")
    else:
        _capture_base_transforms(model_root)
    _connect_feedback_signals()


func _resolve_and_capture() -> void:
    _resolve_model_root()
    if model_root == null:
        set_process(false)
        return
    _capture_base_transforms(model_root)


func _resolve_model_root() -> void:
    if subject == null:
        return
    for candidate_name in [&"MechromancerModel", &"RobotModel", &"OrganicModel"]:
        var candidate := subject.get_node_or_null(NodePath(String(candidate_name))) as Node3D
        if candidate != null:
            model_root = candidate
            return
    for child in subject.get_children():
        if child is Node3D and String(child.name).ends_with("Model"):
            model_root = child as Node3D
            return


func _capture_base_transforms(root: Node) -> void:
    base_transforms.clear()
    _capture_recursive(root)


func _capture_recursive(node: Node) -> void:
    if node is Node3D:
        base_transforms[node] = (node as Node3D).transform
    for child in node.get_children():
        _capture_recursive(child)


func _capture_missing_recursive(node: Node) -> void:
    if node is Node3D and not base_transforms.has(node):
        base_transforms[node] = (node as Node3D).transform
    for child in node.get_children():
        _capture_missing_recursive(child)


func _connect_feedback_signals() -> void:
    if subject == null:
        return
    var fired_callback := Callable(self, "_on_fired")
    if subject.has_signal(&"pistol_fired") and not subject.is_connected(&"pistol_fired", fired_callback):
        subject.connect(&"pistol_fired", fired_callback)
    if subject.has_signal(&"weapon_fired") and not subject.is_connected(&"weapon_fired", fired_callback):
        subject.connect(&"weapon_fired", fired_callback)
    var health_callback := Callable(self, "_on_health_changed")
    if subject.has_signal(&"health_changed") and not subject.is_connected(&"health_changed", health_callback):
        subject.connect(&"health_changed", health_callback)


func _process(delta: float) -> void:
    if subject == null or not is_instance_valid(subject) or model_root == null:
        return
    _capture_missing_recursive(model_root)
    recoil = move_toward(recoil, 0.0, delta * 8.5)
    hit_impulse = move_toward(hit_impulse, 0.0, delta * 5.0)
    idle_phase = fmod(idle_phase + delta * 1.35, TAU)

    var horizontal_speed := 0.0
    if subject is CharacterBody3D:
        var body := subject as CharacterBody3D
        horizontal_speed = Vector2(body.velocity.x, body.velocity.z).length()
    var movement_blend := clampf(horizontal_speed / 4.5, 0.0, 1.0)
    phase = fmod(phase + delta * lerpf(2.4, 8.6, movement_blend), TAU)

    _restore_base_transforms()
    if subject.is_in_group(&"player_character"):
        _animate_mechromancer(movement_blend)
    elif subject.is_in_group(&"friendly_robots"):
        _animate_robot(movement_blend, delta)
    elif subject.is_in_group(&"organic_enemies"):
        _animate_organic(movement_blend)


func _restore_base_transforms() -> void:
    for key in base_transforms.keys():
        var node := key as Node3D
        if node != null and is_instance_valid(node):
            node.transform = base_transforms[key]


func _animate_mechromancer(movement_blend: float) -> void:
    var channeling := false
    if _has_channel_kind:
        channeling = StringName(subject.get(&"channel_kind")) != &""

    var breath := sin(idle_phase + deterministic_offset)
    model_root.position.y += breath * 0.018
    model_root.rotation.z += sin(phase) * 0.026 * movement_blend
    model_root.rotation.x += hit_impulse * 0.08

    var legs := _nodes_with_prefix(model_root, "LeftLeg")
    legs.append_array(_nodes_with_prefix(model_root, "RightLeg"))
    for index in range(legs.size()):
        var direction := -1.0 if index % 2 == 0 else 1.0
        legs[index].rotation.x += sin(phase) * 0.42 * movement_blend * direction

    var left_arms := _nodes_with_prefix(model_root, "LeftArm")
    var right_arms := _nodes_with_prefix(model_root, "RightArm")
    for arm in left_arms:
        arm.rotation.x += sin(phase) * -0.32 * movement_blend
    for arm in right_arms:
        arm.rotation.x += sin(phase) * 0.22 * movement_blend - recoil * 0.18

    for pistol in _nodes_with_prefix(model_root, "WeakPistol"):
        pistol.position.z += recoil * 0.13
        pistol.rotation.x += recoil * 0.08

    var coat_tails := _nodes_with_prefix(model_root, "CoatTail")
    for index in range(coat_tails.size()):
        var tail := coat_tails[index]
        tail.rotation.x += 0.08 + movement_blend * 0.18
        tail.rotation.z += sin(phase + float(index) * PI) * 0.055 * movement_blend

    if channeling:
        model_root.rotation.x -= 0.105
        model_root.position.y -= 0.035
        for arm in left_arms:
            arm.rotation.x -= 0.72
            arm.rotation.z -= 0.22
        for arm in right_arms:
            arm.rotation.x -= 0.82
            arm.rotation.z += 0.22


func _animate_robot(movement_blend: float, delta: float) -> void:
    var state := _state_name()
    var working := state in [&"salvaging", &"repairing", &"building"]
    var bob := absf(sin(phase * 2.0)) * 0.055 * movement_blend
    model_root.position.y += bob
    model_root.rotation.z += sin(phase) * 0.018 * movement_blend
    model_root.rotation.x += hit_impulse * 0.07

    var legs := _nodes_with_prefix(model_root, "Leg")
    var feet := _nodes_with_prefix(model_root, "Foot")
    for index in range(legs.size()):
        var leg_phase := phase + float(index % 2) * PI
        legs[index].rotation.x += sin(leg_phase) * 0.44 * movement_blend
        legs[index].rotation.z += cos(leg_phase) * 0.09 * movement_blend
    for index in range(feet.size()):
        var foot_phase := phase + float(index % 2) * PI
        feet[index].position.y += maxf(0.0, sin(foot_phase)) * 0.13 * movement_blend

    for weapon in _nodes_with_prefix(model_root, "Weapon"):
        weapon.position.z += recoil * 0.16
    for sensor in _nodes_with_prefix(model_root, "Sensor"):
        sensor.rotation.y += sin(idle_phase * 0.75 + deterministic_offset) * 0.18
    for optic in _nodes_with_prefix(model_root, "Optic"):
        optic.rotation.y += sin(idle_phase * 1.1 + deterministic_offset) * 0.08
    for cable in _nodes_with_prefix(model_root, "ExposedCable"):
        cable.rotation.z += sin(idle_phase * 2.2 + deterministic_offset) * 0.045
    for antenna in _nodes_with_prefix(model_root, "Antenna"):
        antenna.rotation.z += sin(idle_phase * 1.7 + deterministic_offset) * 0.035

    if working:
        model_root.rotation.z += sin(idle_phase * 5.0) * 0.025
        for tool in _nodes_with_prefix(model_root, "Dismantler"):
            tool.rotation.y += idle_phase * 2.3
            tool.rotation.x += sin(idle_phase * 5.5) * 0.22

    for drum in _nodes_with_prefix(model_root, "SalvageDrum"):
        drum.rotation.x += delta * 0.9 if working else delta * 0.18
    for joint in _nodes_with_prefix(model_root, "PistonJoint"):
        joint.rotation.z += sin(idle_phase * 2.2 + deterministic_offset) * 0.08
    for piston in _nodes_with_prefix(model_root, "WelderArm"):
        piston.rotation.x += sin(idle_phase * 2.1 + deterministic_offset) * (0.08 if working else 0.025)
    for piston in _nodes_with_prefix(model_root, "AssemblyArm"):
        piston.rotation.x += cos(idle_phase * 1.9 + deterministic_offset) * (0.07 if working else 0.022)
    for tool_head in _nodes_with_prefix(model_root, "ToolHead"):
        tool_head.rotation.y += sin(idle_phase * 4.5 + deterministic_offset) * (0.18 if working else 0.04)
    for coil in _nodes_with_prefix(model_root, "ForgeCoil"):
        coil.rotation.y += delta * (2.2 if working else 0.55)
    for fin in _nodes_with_prefix(model_root, "ScoutFin"):
        fin.rotation.z += sin(idle_phase * 1.35 + deterministic_offset) * 0.035
    for shield_rib in _nodes_with_prefix(model_root, "ShieldRib"):
        shield_rib.rotation.x += sin(idle_phase * 1.4 + deterministic_offset) * 0.018


func _animate_organic(movement_blend: float) -> void:
    var state := _state_name()
    var hunting := state in [&"hunting", &"attacking", &"investigating"]
    var windup := _attack_windup_remaining()
    var pulse := 1.0 + sin(idle_phase * 2.4 + deterministic_offset) * 0.028
    model_root.scale = model_root.scale * Vector3(pulse, 1.0 / pulse, pulse)
    model_root.position.y += absf(sin(phase * 2.0)) * 0.075 * movement_blend
    model_root.rotation.z += sin(phase + deterministic_offset) * 0.045 * movement_blend
    model_root.rotation.x += hit_impulse * 0.12

    var legs := _nodes_with_prefix(model_root, "Leg")
    var talons := _nodes_with_prefix(model_root, "Talon")
    for index in range(legs.size()):
        var leg_phase := phase * 1.35 + float(index) * 0.72
        legs[index].rotation.z += sin(leg_phase) * 0.34 * lerpf(0.25, 1.0, movement_blend)
        legs[index].rotation.x += cos(leg_phase) * 0.18 * movement_blend
    for index in range(talons.size()):
        talons[index].rotation.x += sin(phase * 1.7 + float(index)) * 0.14 * movement_blend

    for head in _nodes_with_prefix(model_root, "Head"):
        head.rotation.y += sin(idle_phase * 1.9 + deterministic_offset) * (0.12 if hunting else 0.06)
        head.rotation.x += sin(idle_phase * 3.1 + deterministic_offset) * 0.035
    for mandible in _nodes_with_prefix(model_root, "Mandible"):
        mandible.rotation.y += sin(idle_phase * (5.0 if hunting else 2.6) + deterministic_offset) * 0.19
        if windup > 0.0:
            mandible.rotation.y += 0.18 * clampf(windup / 0.34, 0.0, 1.0)
    for tail in _nodes_with_prefix(model_root, "Tail"):
        tail.rotation.y += sin(idle_phase * (3.4 if hunting else 1.6) + deterministic_offset) * 0.24
        tail.rotation.z += cos(idle_phase * 1.8 + deterministic_offset) * 0.08
    for tail in _nodes_with_prefix(model_root, "RazorhoundTail"):
        tail.rotation.y += sin(idle_phase * (3.2 if hunting else 1.45) + deterministic_offset) * 0.16
    for antenna in _nodes_with_prefix(model_root, "SkitterlingAntenna"):
        antenna.rotation.z += sin(idle_phase * 2.8 + deterministic_offset) * 0.1
    for ear in _nodes_with_prefix(model_root, "RazorhoundEar"):
        ear.rotation.z += sin(idle_phase * 2.1 + deterministic_offset) * 0.06
    for sac in _nodes_with_prefix(model_root, "SporecasterSac"):
        sac.scale = sac.scale * (1.0 + sin(idle_phase * 2.0 + deterministic_offset) * 0.025)
    for oculus in _nodes_with_prefix(model_root, "SporecasterOculus"):
        oculus.rotation.y += sin(idle_phase * 1.5 + deterministic_offset) * 0.12
    for spine in _nodes_with_prefix(model_root, "RazorhoundSpine"):
        spine.rotation.x += sin(idle_phase * 1.7 + deterministic_offset) * 0.035
    for jaw in _nodes_with_prefix(model_root, "ApexJaw"):
        jaw.rotation.y += sin(idle_phase * (2.4 if hunting else 1.2) + deterministic_offset) * 0.1
        if windup > 0.0:
            jaw.rotation.y += 0.24 * clampf(windup / 0.34, 0.0, 1.0)
    for lobe in _nodes_with_prefix(model_root, "BroodmassLobe"):
        lobe.rotation.z += sin(idle_phase * 1.6 + deterministic_offset) * 0.04
    for spine in _nodes_with_prefix(model_root, "BackSpine"):
        spine.rotation.z += sin(idle_phase * 2.9 + deterministic_offset) * 0.035

    if windup > 0.0:
        var charge := clampf(windup / 0.34, 0.0, 1.0)
        model_root.position.z += 0.06 * charge
        model_root.rotation.x += 0.1 * charge

    if _organic_species() == &"veilstalker":
        var attacking := state == &"attacking"
        var stalking := hunting or state in [&"scouting", &"patrolling"]
        var veil_sway := sin(idle_phase * (2.4 if stalking else 1.35) + deterministic_offset)
        for veil in _nodes_with_prefix(model_root, "VeilstalkerVeil"):
            veil.rotation.z += veil_sway * (0.12 if stalking else 0.07)
        for limb in _nodes_with_prefix(model_root, "VeilstalkerForelimb"):
            limb.rotation.x += (0.22 if attacking else 0.06) + sin(phase + deterministic_offset) * 0.12 * movement_blend
        for hook in _nodes_with_prefix(model_root, "VeilstalkerHook"):
            hook.rotation.x += sin(phase * 1.4 + deterministic_offset) * 0.16 * movement_blend
        for tendril in _nodes_with_prefix(model_root, "VeilstalkerTendril"):
            tendril.rotation.z += sin(idle_phase * 3.2 + deterministic_offset) * (0.18 if stalking else 0.08)
        for plate in _nodes_with_prefix(model_root, "VeilstalkerDorsalPlate"):
            plate.rotation.x += sin(idle_phase * 2.0 + deterministic_offset) * 0.035
        for tail in _nodes_with_prefix(model_root, "VeilstalkerTail"):
            tail.rotation.y += sin(idle_phase * (3.8 if attacking else 1.7) + deterministic_offset) * 0.16
        if attacking:
            model_root.position.z -= 0.08 + absf(sin(phase * 1.7)) * 0.06
            model_root.rotation.x -= 0.08 + absf(sin(phase * 1.7)) * 0.04


func _organic_species() -> StringName:
    if subject == null or not _property_exists(subject, &"species"):
        return &""
    return StringName(subject.get(&"species"))


func _attack_windup_remaining() -> float:
    if subject == null or not _property_exists(subject, &"attack_windup_remaining"):
        return 0.0
    return maxf(0.0, float(subject.get(&"attack_windup_remaining")))


func _nodes_with_prefix(root: Node, prefix: String) -> Array[Node3D]:
    var result: Array[Node3D] = []
    _collect_nodes_with_prefix(root, prefix, result)
    return result


func _collect_nodes_with_prefix(node: Node, prefix: String, result: Array[Node3D]) -> void:
    for child in node.get_children():
        if child is Node3D:
            var child_3d := child as Node3D
            if String(child_3d.name).begins_with(prefix):
                result.append(child_3d)
        _collect_nodes_with_prefix(child, prefix, result)


func _state_name() -> StringName:
    if not _has_state_name:
        return &""
    return StringName(subject.get(&"state_name"))


func _property_exists(object: Object, property_name: StringName) -> bool:
    for property in object.get_property_list():
        if StringName(property.get("name", "")) == property_name:
            return true
    return false


func _on_fired(_origin: Vector3, _target: Vector3, _target_node: Node) -> void:
    recoil = 1.0


func _on_health_changed(arg_1: Variant, arg_2: Variant = null, _arg_3: Variant = null) -> void:
    var current := -1.0
    if typeof(arg_1) in [TYPE_FLOAT, TYPE_INT]:
        current = float(arg_1)
    elif typeof(arg_2) in [TYPE_FLOAT, TYPE_INT]:
        current = float(arg_2)
    if current < 0.0:
        return
    if _last_health >= 0.0 and current < _last_health:
        hit_impulse = 1.0
    _last_health = current
