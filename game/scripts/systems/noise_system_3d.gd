class_name NoiseSystem3D
extends Node

signal noise_emitted(position: Vector3, radius: float, intensity: float, source_kind: StringName)

var recent_events: Array[Dictionary] = []


func emit_noise(position: Vector3, radius: float, intensity: float, source_kind: StringName) -> void:
    var event := {
        "position": position,
        "radius": maxf(0.0, radius),
        "intensity": maxf(0.0, intensity),
        "source_kind": source_kind,
        "time": Time.get_ticks_msec(),
    }
    recent_events.push_front(event)
    if recent_events.size() > 24:
        recent_events.resize(24)
    noise_emitted.emit(position, radius, intensity, source_kind)
