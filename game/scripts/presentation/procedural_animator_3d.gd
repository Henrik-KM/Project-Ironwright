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
var animation_elapsed: float = 0.0
var animation_frame_offset: int = 0
var _has_state_name: bool = false
var _has_channel_kind: bool = false
var _has_visual_lod_level: bool = false
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
    animation_frame_offset = subject.get_instance_id() % 2
    _has_state_name = _property_exists(subject, &"state_name")
    _has_channel_kind = _property_exists(subject, &"channel_kind")
    _has_visual_lod_level = _property_exists(subject, &"visual_lod_level")
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
    if _has_visual_lod_level and int(subject.get(&"visual_lod_level")) >= 1:
        return
    animation_elapsed += delta
    var cadence := _animation_cadence()
    if cadence > 1 and (int(Engine.get_process_frames()) + animation_frame_offset) % cadence != 0:
        return
    var animation_delta := animation_elapsed
    animation_elapsed = 0.0
    _capture_missing_recursive(model_root)
    recoil = move_toward(recoil, 0.0, animation_delta * 8.5)
    hit_impulse = move_toward(hit_impulse, 0.0, animation_delta * 5.0)
    idle_phase = fmod(idle_phase + animation_delta * 1.35, TAU)

    var horizontal_speed := 0.0
    if subject is CharacterBody3D:
        var body := subject as CharacterBody3D
        horizontal_speed = Vector2(body.velocity.x, body.velocity.z).length()
    var movement_blend := clampf(horizontal_speed / 4.5, 0.0, 1.0)
    phase = fmod(phase + animation_delta * lerpf(2.4, 8.6, movement_blend), TAU)

    _restore_base_transforms()
    if subject.is_in_group(&"player_character"):
        _animate_mechromancer(movement_blend)
    elif subject.is_in_group(&"friendly_robots"):
        _animate_robot(movement_blend, delta)
    elif subject.is_in_group(&"organic_enemies"):
        _animate_organic(movement_blend)


func _animation_cadence() -> int:
    if not _has_visual_lod_level:
        return 1
    var lod_level := clampi(int(subject.get(&"visual_lod_level")), 0, 2)
    # Release actors keep full animation detail nearby, but stagger the
    # presentation-only work across frames so a large active contact does not
    # turn every model into a per-frame recursive traversal. The accumulated
    # delta above keeps the motion continuous at the lower update cadence.
    return [2, 3, 5][lod_level]


func _restore_base_transforms() -> void:
    for key in base_transforms.keys():
        if not is_instance_valid(key) or not key is Node3D:
            continue
        var node := key as Node3D
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
    var feeding := state == &"feeding"
    var nest_guard := state == &"nest_guard"
    var retreating := state == &"retreating"
    var dead := state == &"dead"
    var windup := _attack_windup_remaining()
    var threat_blend := clampf(windup / 0.34, 0.0, 1.0)
    var death_blend := 1.0 if dead else 0.0
    if _property_exists(subject, &"death_presentation_remaining"):
        var death_remaining := maxf(0.0, float(subject.get(&"death_presentation_remaining")))
        if death_remaining > 0.0:
            death_blend = clampf(1.0 - death_remaining / 0.72, 0.0, 1.0)
    var pulse := 1.0 + sin(idle_phase * 2.4 + deterministic_offset) * 0.028
    model_root.scale = model_root.scale * Vector3(pulse, 1.0 / pulse, pulse)
    model_root.position.y += absf(sin(phase * 2.0)) * 0.075 * movement_blend
    model_root.rotation.z += sin(phase + deterministic_offset) * 0.045 * movement_blend
    model_root.rotation.x += hit_impulse * 0.12

    # The imported action clips establish the broad movement, while this
    # presentation-only layer gives the close tactical silhouette a readable
    # physical intent: feeding creatures lower their head, nest guardians
    # brace around their territory, retreating creatures protect their core,
    # and dying creatures lose height and balance before leaving the world.
    if feeding:
        model_root.position.z += 0.12
        model_root.rotation.x += 0.16 + sin(idle_phase * 2.2 + deterministic_offset) * 0.035
    elif nest_guard:
        model_root.position.y += 0.035
        model_root.rotation.z += sin(idle_phase * 1.4 + deterministic_offset) * 0.06
        model_root.rotation.x -= 0.045
    elif retreating:
        model_root.position.z += 0.18
        model_root.rotation.x += 0.12
        model_root.rotation.z += sin(idle_phase * 2.0 + deterministic_offset) * 0.045
    if death_blend > 0.0:
        model_root.position.y -= 0.22 * death_blend
        model_root.rotation.z += 0.24 * death_blend
        model_root.scale *= Vector3(1.0 - 0.18 * death_blend, 1.0 - 0.24 * death_blend, 1.0 - 0.18 * death_blend)

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
        if hit_impulse > 0.0:
            head.rotation.z += hit_impulse * 0.16
            head.rotation.x -= hit_impulse * 0.09
        if feeding:
            head.rotation.x += 0.22 + sin(idle_phase * 2.8 + deterministic_offset) * 0.07
        elif nest_guard:
            head.rotation.y += sin(idle_phase * 1.25 + deterministic_offset) * 0.2
        elif retreating:
            head.rotation.x -= 0.1
    for mandible in _nodes_with_prefix(model_root, "Mandible"):
        mandible.rotation.y += sin(idle_phase * (5.0 if hunting else 2.6) + deterministic_offset) * 0.19
        if hit_impulse > 0.0:
            mandible.rotation.x += hit_impulse * 0.18
            mandible.rotation.y -= hit_impulse * 0.08
        if feeding:
            mandible.rotation.y += sin(idle_phase * 4.2 + deterministic_offset) * 0.16
        if windup > 0.0:
            mandible.rotation.y += 0.18 * clampf(windup / 0.34, 0.0, 1.0)
    for tail in _nodes_with_prefix(model_root, "Tail"):
        tail.rotation.y += sin(idle_phase * (3.4 if hunting else 1.6) + deterministic_offset) * 0.24
        tail.rotation.z += cos(idle_phase * 1.8 + deterministic_offset) * 0.08
        if hit_impulse > 0.0:
            tail.rotation.z -= hit_impulse * 0.11
        if retreating:
            tail.rotation.x += 0.18
            tail.rotation.z -= 0.12
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

    _animate_tier_anatomy(threat_blend, movement_blend)

    if _organic_species() == &"veilstalker":
        var attacking := state == &"attacking"
        var stalking := hunting or state in [&"scouting", &"patrolling"]
        var veil_sway := sin(idle_phase * (2.4 if stalking else 1.35) + deterministic_offset)
        var veil_index := 0
        for veil in _nodes_with_prefix(model_root, "VeilstalkerVeil"):
            veil.rotation.z += veil_sway * (0.12 if stalking else 0.07)
            var side := -1.0 if veil_index % 2 == 0 else 1.0
            veil.rotation.y += side * (0.05 + threat_blend * 0.24)
            veil.position.x += side * threat_blend * 0.06
            veil.scale *= Vector3(1.0 + threat_blend * 0.18, 1.0 - threat_blend * 0.11, 1.0 + threat_blend * 0.08)
            veil_index += 1
        for limb in _nodes_with_prefix(model_root, "VeilstalkerForelimb"):
            limb.rotation.x += (0.22 + threat_blend * 0.58 if attacking else 0.06) + sin(phase + deterministic_offset) * 0.12 * movement_blend
            limb.rotation.z += sin(idle_phase * 1.4 + deterministic_offset) * 0.06
        for hook in _nodes_with_prefix(model_root, "VeilstalkerHook"):
            hook.rotation.x += sin(phase * 1.4 + deterministic_offset) * 0.16 * movement_blend
        for cowl in _nodes_with_prefix(model_root, "VeilstalkerCowl"):
            cowl.scale *= Vector3(1.0 + threat_blend * 0.12, 1.0 - threat_blend * 0.1, 1.0 + threat_blend * 0.12)
            cowl.rotation.x += threat_blend * 0.16
        for tendril in _nodes_with_prefix(model_root, "VeilstalkerTendril"):
            tendril.rotation.z += sin(idle_phase * 3.2 + deterministic_offset) * (0.18 if stalking else 0.08) + threat_blend * 0.12
        for plate in _nodes_with_prefix(model_root, "VeilstalkerDorsalPlate"):
            plate.rotation.x += sin(idle_phase * 2.0 + deterministic_offset) * 0.035
        for tail in _nodes_with_prefix(model_root, "VeilstalkerTail"):
            tail.rotation.y += sin(idle_phase * (3.8 if attacking else 1.7) + deterministic_offset) * 0.16
            tail.rotation.z += threat_blend * 0.08
        if attacking:
            model_root.position.z -= 0.08 + absf(sin(phase * 1.7)) * 0.06
            model_root.rotation.x -= 0.08 + absf(sin(phase * 1.7)) * 0.04

    _animate_authored_family_signature(_organic_species(), threat_blend, movement_blend)


func _animate_tier_anatomy(threat_blend: float, movement_blend: float) -> void:
    if subject == null or not _property_exists(subject, &"enemy_tier"):
        return
    var tier := clampi(int(subject.get(&"enemy_tier")), 1, 5)
    var channel_pulse := 1.0 + sin(idle_phase * (1.55 + float(tier) * 0.18) + deterministic_offset) * (0.08 + float(tier) * 0.018)
    var signal_pulse := 1.0 + sin(idle_phase * (2.15 + float(tier) * 0.24) + deterministic_offset) * (0.06 + threat_blend * 0.14)
    for channel in _nodes_with_prefix(model_root, "TierVascularChannel"):
        channel.scale = Vector3(channel_pulse, 1.0, 1.0 + threat_blend * 0.18)
        channel.rotation.y += sin(idle_phase * 1.4 + deterministic_offset) * 0.035
    for plate in _nodes_with_prefix(model_root, "TierDorsalPlate"):
        plate.rotation.x += sin(idle_phase * (1.25 + float(tier) * 0.12) + deterministic_offset) * (0.018 + movement_blend * 0.025)
        plate.position.y += sin(idle_phase * 1.7 + deterministic_offset) * 0.012 * (1.0 + threat_blend)
    for crest in _nodes_with_prefix(model_root, "TierCrest"):
        crest.rotation.z += sin(phase * 1.1 + deterministic_offset) * (0.022 + threat_blend * 0.07)
    for signal_node in _nodes_with_prefix(model_root, "TierSignal"):
        signal_node.scale = Vector3.ONE * signal_pulse
    for crown_node in _nodes_with_prefix(model_root, "TierCrownNode"):
        crown_node.scale = Vector3.ONE * signal_pulse
    for ring in _nodes_with_prefix(model_root, "TierCrownRing"):
        ring.rotation.y += (0.12 + float(tier) * 0.035) * (0.55 + threat_blend)


func _organic_species() -> StringName:
    if subject == null or not _property_exists(subject, &"species"):
        return &""
    return StringName(subject.get(&"species"))


func _animate_authored_family_signature(species: StringName, threat_blend: float, movement_blend: float) -> void:
    # These small family signatures make the imported high-definition shells
    # communicate intent before damage lands. They are presentation-only and
    # deliberately use stable authored node prefixes rather than gameplay data.
    var attack_sway := sin(idle_phase * 2.2 + deterministic_offset)
    match species:
        &"skitterling":
            var mandible_index := 0
            for mandible in _nodes_with_prefix(model_root, "SkitterlingMandible"):
                var side := -1.0 if mandible_index % 2 == 0 else 1.0
                mandible.rotation.y += side * (0.08 + threat_blend * 0.24)
                mandible_index += 1
            for antenna in _nodes_with_prefix(model_root, "SkitterlingAntenna"):
                antenna.rotation.z += attack_sway * (0.08 + threat_blend * 0.12)
            if threat_blend > 0.0:
                model_root.position.z -= 0.035 * threat_blend
        &"razorhound":
            for snout in _nodes_with_prefix(model_root, "RazorhoundSnout"):
                snout.rotation.x -= 0.12 * threat_blend
            for ear in _nodes_with_prefix(model_root, "RazorhoundEar"):
                ear.rotation.z += attack_sway * 0.055
            for spine in _nodes_with_prefix(model_root, "RazorhoundSpine"):
                spine.rotation.x += attack_sway * (0.025 + threat_blend * 0.06)
            if threat_blend > 0.0:
                model_root.position.z -= 0.075 * threat_blend
                model_root.rotation.x -= 0.055 * threat_blend
        &"burrower":
            for drill in _nodes_with_prefix(model_root, "BurrowerDrill"):
                drill.rotation.z += idle_phase * (1.4 + threat_blend * 2.6)
            for flute in _nodes_with_prefix(model_root, "BurrowerDrillFlute"):
                flute.rotation.z -= idle_phase * (0.8 + threat_blend * 1.6)
            for lamp in _nodes_with_prefix(model_root, "BurrowerLamp"):
                lamp.scale = lamp.scale * (1.0 + sin(idle_phase * 3.0) * (0.025 + threat_blend * 0.08))
            if threat_blend > 0.0:
                model_root.position.z -= 0.09 * threat_blend
                model_root.rotation.x += 0.08 * threat_blend
        &"sporecaster":
            for sac in _nodes_with_prefix(model_root, "SporecasterSac"):
                var sac_pulse := 1.0 + sin(idle_phase * 2.0 + deterministic_offset) * (0.035 + threat_blend * 0.12)
                sac.scale *= Vector3(sac_pulse, 1.0 + threat_blend * 0.16, sac_pulse)
            for stem in _nodes_with_prefix(model_root, "SporecasterStem"):
                stem.rotation.z += attack_sway * (0.025 + threat_blend * 0.11)
            for oculus in _nodes_with_prefix(model_root, "SporecasterOculus"):
                oculus.rotation.y += sin(idle_phase * 1.7 + deterministic_offset) * 0.13
            for rib in _nodes_with_prefix(model_root, "SporecasterGillRib"):
                rib.rotation.z += attack_sway * (0.04 + threat_blend * 0.09)
        &"broodmass":
            for maw in _nodes_with_prefix(model_root, "BroodmassMaw"):
                maw.rotation.y += 0.16 * threat_blend
            for hook in _nodes_with_prefix(model_root, "BroodmassMawHook"):
                hook.rotation.x -= 0.12 * threat_blend
            for lobe in _nodes_with_prefix(model_root, "BroodmassLobe"):
                lobe.scale *= Vector3(1.0 + threat_blend * 0.08, 1.0 + sin(idle_phase * 1.8) * 0.035, 1.0 + threat_blend * 0.08)
        &"apex":
            for jaw in _nodes_with_prefix(model_root, "ApexJaw"):
                jaw.rotation.y += 0.20 * threat_blend
            for membrane in _nodes_with_prefix(model_root, "ApexMembrane"):
                membrane.rotation.z += attack_sway * (0.04 + threat_blend * 0.12)
            if threat_blend > 0.0:
                model_root.rotation.x -= 0.06 * threat_blend
        &"roofleaper":
            var wing_index := 0
            for wing in _nodes_with_prefix(model_root, "RoofleaperWing"):
                var side := -1.0 if wing_index % 2 == 0 else 1.0
                wing.rotation.z += side * (0.05 + threat_blend * 0.28) + attack_sway * 0.045
                wing.scale *= Vector3(1.0 + threat_blend * 0.08, 1.0, 1.0 + threat_blend * 0.12)
                wing_index += 1
            for talon in _nodes_with_prefix(model_root, "RoofleaperTalons"):
                talon.rotation.x -= 0.16 * threat_blend
            if threat_blend > 0.0:
                model_root.position.y += 0.10 * threat_blend
                model_root.position.z -= 0.08 * threat_blend
        &"glassmoth":
            var wing_index := 0
            for wing in _nodes_with_prefix(model_root, "GlassmothWing"):
                var side := -1.0 if wing_index % 2 == 0 else 1.0
                wing.rotation.z += side * (0.08 + threat_blend * 0.34) + attack_sway * 0.06
                wing_index += 1
            for antenna in _nodes_with_prefix(model_root, "GlassmothAntenna"):
                antenna.rotation.z += attack_sway * 0.08
        &"miremaw":
            var jaw_index := 0
            for hook in _nodes_with_prefix(model_root, "MiremawJawHook"):
                var side := -1.0 if jaw_index % 2 == 0 else 1.0
                hook.rotation.x += side * (0.05 + threat_blend * 0.24)
                jaw_index += 1
            for fan in _nodes_with_prefix(model_root, "MiremawGillFan"):
                fan.scale *= Vector3(1.0 + threat_blend * 0.14, 1.0 + sin(idle_phase * 2.4) * 0.05, 1.0 + threat_blend * 0.14)
            for fin in _nodes_with_prefix(model_root, "MiremawWaterFin"):
                fin.rotation.z += attack_sway * 0.08
            for spine in _nodes_with_prefix(model_root, "MiremawGillSpine"):
                spine.rotation.z += attack_sway * (0.05 + threat_blend * 0.10)
            for plate in _nodes_with_prefix(model_root, "MiremawJawPlate"):
                plate.rotation.x += attack_sway * (0.04 + threat_blend * 0.12)
        &"carrionbell":
            for resonator in _nodes_with_prefix(model_root, "CarrionbellResonator"):
                resonator.scale *= Vector3(1.0 + threat_blend * 0.16, 1.0 + threat_blend * 0.24, 1.0 + threat_blend * 0.16)
                resonator.rotation.y += attack_sway * (0.06 + threat_blend * 0.12)
            for tendril in _nodes_with_prefix(model_root, "CarrionbellSignalTendril"):
                tendril.rotation.z += attack_sway * 0.10
            for rib in _nodes_with_prefix(model_root, "CarrionbellBellRib"):
                rib.rotation.y += attack_sway * (0.04 + threat_blend * 0.11)
        &"rootweaver":
            var arm_index := 0
            for arm in _nodes_with_prefix(model_root, "RootweaverArm"):
                var side := -1.0 if arm_index % 2 == 0 else 1.0
                arm.rotation.z += side * (0.06 + threat_blend * 0.26)
                arm_index += 1
            for fan in _nodes_with_prefix(model_root, "RootweaverSporeFan"):
                fan.scale *= Vector3(1.0 + threat_blend * 0.12, 1.0 + sin(idle_phase * 2.1) * 0.05, 1.0 + threat_blend * 0.12)
            for spine in _nodes_with_prefix(model_root, "RootweaverRouteSpine"):
                spine.rotation.z += attack_sway * (0.04 + movement_blend * 0.06)
            for root_spine in _nodes_with_prefix(model_root, "RootweaverRootSpine"):
                root_spine.rotation.z += attack_sway * (0.05 + threat_blend * 0.10)
        &"thornback":
            var thorn_index := 0
            for spine in _nodes_with_prefix(model_root, "ThornbackSpine"):
                var side := -1.0 if thorn_index % 2 == 0 else 1.0
                spine.rotation.z += side * (0.04 + threat_blend * 0.16)
                thorn_index += 1
            for plate in _nodes_with_prefix(model_root, "ThornbackJawPlate"):
                plate.rotation.x += 0.08 + threat_blend * 0.28
                plate.rotation.y += attack_sway * 0.08
            for ridge in _nodes_with_prefix(model_root, "ThornbackDorsalRidge"):
                ridge.rotation.x += attack_sway * (0.035 + threat_blend * 0.08)
        &"ashmantle":
            for louver in _nodes_with_prefix(model_root, "AshmantleHeatLouver"):
                louver.rotation.z += attack_sway * (0.04 + threat_blend * 0.16)
                louver.scale *= Vector3(1.0 + threat_blend * 0.08, 1.0, 1.0 + threat_blend * 0.08)
            for rib in _nodes_with_prefix(model_root, "AshmantleLouverRib"):
                rib.rotation.z += attack_sway * (0.05 + threat_blend * 0.12)
            for tendril in _nodes_with_prefix(model_root, "AshmantleTendril"):
                tendril.rotation.z += attack_sway * (0.08 + threat_blend * 0.18)
            for siphon in _nodes_with_prefix(model_root, "AshmantleSiphon"):
                siphon.scale *= Vector3(1.0 + threat_blend * 0.12, 1.0 + threat_blend * 0.18, 1.0 + threat_blend * 0.12)
                siphon.rotation.x += threat_blend * 0.18


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
