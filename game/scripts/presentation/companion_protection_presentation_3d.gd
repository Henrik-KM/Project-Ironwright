class_name CompanionProtectionPresentation3D
extends Node

## Presentation-only protection language for the indispensable Bulwark.
##
## The shield already owns the gameplay protection contract. This controller
## only animates the existing visual hardware so the companion reads as an
## attentive guardian while idle, and as an actively engaged protector when a
## threat enters its envelope.

var subject: Node3D
var elapsed: float = 0.0
var shield_arc: Node3D
var shield_emitter: Node3D
var emitter_collar: Node3D
var scan_blade: Node3D
var _has_archetype: bool = false
var _has_state_name: bool = false
var _has_current_target: bool = false


func configure(next_subject: Node3D) -> void:
    subject = next_subject


func _ready() -> void:
    if subject == null:
        subject = get_parent() as Node3D
    if subject == null:
        set_process(false)
        return
    _has_archetype = _property_exists(subject, &"archetype")
    _has_state_name = _property_exists(subject, &"state_name")
    _has_current_target = _property_exists(subject, &"current_target")
    _resolve_hardware()
    if not _is_companion():
        set_process(false)


func set_presentation_lod(level: int) -> void:
    # Protection language is a close-range readability layer. Remote actors
    # retain their reduced proxy and never pay for this per-frame cue.
    set_process(level <= 0)


func _process(delta: float) -> void:
    if subject == null or not is_instance_valid(subject):
        return
    if shield_arc == null or not is_instance_valid(shield_arc):
        _resolve_hardware()
    if shield_arc == null:
        return
    elapsed += delta
    var engaged := _is_engaged()
    var sweep_speed := 0.34 if not engaged else 1.18
    shield_arc.rotation.y = fmod(elapsed * sweep_speed, TAU)
    if scan_blade != null and is_instance_valid(scan_blade):
        scan_blade.visible = true
        scan_blade.scale.y = 0.82 + sin(elapsed * (1.7 if not engaged else 3.4)) * 0.12
    if shield_emitter != null and is_instance_valid(shield_emitter):
        var pulse_speed := 1.8 if not engaged else 3.2
        var pulse := 1.0 + sin(elapsed * pulse_speed + 0.45) * (0.035 if not engaged else 0.09)
        shield_emitter.scale = Vector3(1.0, 0.7, 1.0) * pulse
    if emitter_collar != null and is_instance_valid(emitter_collar):
        emitter_collar.rotation.z = sin(elapsed * (0.9 if not engaged else 1.6)) * 0.035


func _resolve_hardware() -> void:
    if subject == null:
        return
    shield_arc = subject.find_child("BulwarkShieldArc", true, false) as Node3D
    shield_emitter = subject.find_child("BulwarkShieldEmitter", true, false) as Node3D
    emitter_collar = subject.find_child("BulwarkEmitterCollar", true, false) as Node3D
    scan_blade = subject.find_child("BulwarkShieldScanBlade", true, false) as Node3D


func _is_companion() -> bool:
    return _has_archetype and StringName(str(subject.get(&"archetype"))) == &"companion"


func _is_engaged() -> bool:
    if _has_current_target and subject.get(&"current_target") != null:
        return true
    if _has_state_name and StringName(str(subject.get(&"state_name"))) in [&"engaging", &"intercepting"]:
        return true
    return false


func _property_exists(object: Object, property_name: StringName) -> bool:
    for property in object.get_property_list():
        if StringName(property.get("name", "")) == property_name:
            return true
    return false
