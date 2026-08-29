class_name HeartforgePresentation3D
extends Node

## Presentation-only motion for the Heartforge's authored and progression
## hardware. Simulation owns tier, health and operations; this controller only
## gives the machine's visible state a restrained mechanical response.

var subject: Heartforge3D
var progression_time: float = 0.0


func configure(next_subject: Heartforge3D) -> void:
    subject = next_subject


func _ready() -> void:
    if subject == null:
        subject = get_parent() as Heartforge3D
    if subject == null:
        set_process(false)


func _process(delta: float) -> void:
    if subject == null or not is_instance_valid(subject):
        return
    if _reduced_motion_enabled():
        return
    progression_time += delta
    _animate_focal_hardware()
    _animate_progression_hardware()
    _animate_adaptation_hardware()


func _animate_focal_hardware() -> void:
    var lens_phase := progression_time * 2.05
    for index in range(3):
        var lens := _named_node("HeartforgeFocalSignalLens%02d" % index)
        if lens == null:
            continue
        var pulse := 1.0 + sin(lens_phase + float(index) * 1.55) * 0.075
        lens.scale = Vector3(1.0, 0.68, 0.42) * pulse

    var control_face := _named_node("HeartforgeFocalControlFace")
    if control_face != null:
        control_face.rotation.z = sin(progression_time * 0.72) * 0.012


func _animate_progression_hardware() -> void:
    var adaptive_root := subject.get_node_or_null("HeartforgeModel/AdaptiveHeartforgeGeometry") as Node3D
    if adaptive_root == null or not adaptive_root.visible:
        return

    var tier := clampi(subject.progression_tier, 1, 5)
    var tier3_housing := _named_node("Tier3RelayHousing")
    if tier3_housing != null and tier >= 3:
        var relay_pulse := 1.0 + sin(progression_time * 1.65 + 0.4) * 0.035
        tier3_housing.scale = Vector3(1.0, relay_pulse, 1.0)

    var crossbar := _named_node("Tier4SignalCrossbar")
    if crossbar != null and tier >= 4:
        crossbar.rotation.z = sin(progression_time * 0.62 + 0.7) * 0.016

    var beacon := _named_node("Tier5CrownBeacon")
    if beacon != null and tier >= 5:
        var beacon_pulse := 1.0 + sin(progression_time * 2.25 + 1.1) * 0.09
        beacon.scale = Vector3(1.0, beacon_pulse, 1.0)

    if tier < 5:
        return
    for child in adaptive_root.get_children():
        if not child is Node3D or not String(child.name).begins_with("Tier5CrownFin"):
            continue
        var fin := child as Node3D
        var phase := float(fin.get_index()) * 0.42
        var fin_pulse := 1.0 + sin(progression_time * 1.3 + phase) * 0.045
        fin.scale = Vector3(1.0, fin_pulse, 1.0)


func _animate_adaptation_hardware() -> void:
    var detail := subject.get_node_or_null("HeartforgeModel/HeartforgeAdaptationDetail") as Node3D
    var preview := subject.get_node_or_null("HeartforgeModel/HeartforgeAdaptationPreview") as Node3D
    var active_root := detail if detail != null and detail.visible else preview
    if active_root == null or not active_root.visible:
        return

    # Each principle gets one restrained, readable machine rhythm. These are
    # presentation cues only; the director remains authoritative for state,
    # timing and the resulting damage/noise trade-off.
    if subject.adaptation_profile == &"adaptation.anchored_shell":
        var anchor_ring := active_root.get_node_or_null("AnchorShellSignalRing") as Node3D
        if anchor_ring != null:
            anchor_ring.rotation.z = sin(progression_time * 0.72) * 0.025
        var anchor_crossbar := active_root.get_node_or_null("AnchorShellCrossbar") as Node3D
        if anchor_crossbar != null:
            anchor_crossbar.scale.y = 1.0 + sin(progression_time * 1.1 + 0.4) * 0.018
    elif subject.adaptation_profile == &"adaptation.sacrificial_hollow":
        var hollow_ring := active_root.get_node_or_null("SacrificialHollowRing") as Node3D
        if hollow_ring != null:
            hollow_ring.rotation.x = sin(progression_time * 0.58) * 0.035
        for child in active_root.get_children():
            if not child is Node3D or not String(child.name).begins_with("SacrificialHollowRib"):
                continue
            var rib := child as Node3D
            var rib_phase := float(rib.get_index()) * 0.47
            rib.scale.y = 1.0 + sin(progression_time * 1.22 + rib_phase) * 0.025
    elif subject.adaptation_profile == &"adaptation.quiet_core":
        var quiet_panel := active_root.get_node_or_null("QuietCoreSignalPanel") as Node3D
        if quiet_panel != null:
            quiet_panel.scale = Vector3.ONE * (1.0 + sin(progression_time * 0.8) * 0.018)
        for child in active_root.get_children():
            if not child is Node3D or not String(child.name).begins_with("QuietCoreDampenerBaffle"):
                continue
            var baffle := child as Node3D
            var baffle_phase := float(baffle.get_index()) * 0.6
            baffle.scale.z = 1.0 + sin(progression_time * 0.9 + baffle_phase) * 0.02
    elif subject.adaptation_profile == &"":
        var preview_ring := active_root.get_node_or_null("AdaptationPreviewRing") as Node3D
        if preview_ring != null:
            preview_ring.rotation.z = sin(progression_time * 0.6) * 0.02

    var worksite := active_root.get_node_or_null("AdaptationWorksiteCrew") as Node3D
    if worksite != null:
        worksite.rotation.y = progression_time * 0.16
        for index in range(worksite.get_child_count()):
            var builder := worksite.get_child(index) as Node3D
            if builder == null:
                continue
            var phase := float(index) * 2.1
            builder.position.y = 0.035 + sin(progression_time * 1.25 + phase) * 0.025
            var tool := builder.get_node_or_null("AdaptationBuilderTool%02d" % index) as Node3D
            if tool != null:
                tool.scale.y = 1.0 + sin(progression_time * 2.2 + phase) * 0.08
            var beacon := builder.get_node_or_null("AdaptationBuilderBeacon%02d" % index) as Node3D
            if beacon != null:
                beacon.scale = Vector3.ONE * (1.0 + sin(progression_time * 2.0 + phase) * 0.12)


func _named_node(node_name: String) -> Node3D:
    if subject == null:
        return null
    return subject.find_child(node_name, true, false) as Node3D


func _reduced_motion_enabled() -> bool:
    var settings := get_tree().get_first_node_in_group(&"release_settings_service")
    if settings == null or not settings.has_method(&"get_value"):
        return false
    return bool(settings.get_value(&"reduced_motion", false))
