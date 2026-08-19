class_name FormationRules3D
extends RefCounted


static func pace_multiplier(max_separation: float) -> float:
    if max_separation >= 7.0:
        return 0.0
    if max_separation >= 4.5:
        return 0.34
    if max_separation >= 2.8:
        return 0.66
    return 1.0


static func formation_offset(index: int, role: StringName) -> Vector3:
    if role == &"scout":
        return Vector3(0.0, 0.0, -2.8)
    if role == &"salvager":
        return Vector3(0.0, 0.0, 1.2 + float(index % 2) * 1.2)
    var side := -1.0 if index % 2 == 0 else 1.0
    var row := float(index / 2)
    return Vector3(side * (2.0 + row * 0.55), 0.0, 0.8 + row * 1.2)


static func rotated_offset(offset: Vector3, forward: Vector3) -> Vector3:
    var flat_forward := Vector3(forward.x, 0.0, forward.z)
    if flat_forward.length_squared() < 0.001:
        flat_forward = Vector3.FORWARD
    flat_forward = flat_forward.normalized()
    var right := Vector3(flat_forward.z, 0.0, -flat_forward.x)
    return right * offset.x + Vector3.UP * offset.y + flat_forward * offset.z
