class_name ModelKit3D
extends RefCounted


static func material(
        color: Color,
        metallic: float = 0.0,
        roughness: float = 0.82,
        emission_color: Color = Color(0, 0, 0, 1),
        emission_energy: float = 0.0
    ) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = color
    result.metallic = metallic
    result.roughness = roughness
    if emission_energy > 0.0:
        result.emission_enabled = true
        result.emission = emission_color
        result.emission_energy_multiplier = emission_energy
    return result


static func add_box(
        parent: Node3D,
        size: Vector3,
        position: Vector3,
        mat: Material,
        rotation: Vector3 = Vector3.ZERO,
        name_hint: String = "Box"
    ) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var instance := MeshInstance3D.new()
    instance.name = name_hint
    instance.mesh = mesh
    instance.material_override = mat
    instance.position = position
    instance.rotation = rotation
    parent.add_child(instance)
    return instance


static func add_cylinder(
        parent: Node3D,
        radius: float,
        height: float,
        position: Vector3,
        mat: Material,
        rotation: Vector3 = Vector3.ZERO,
        name_hint: String = "Cylinder"
    ) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 10
    var instance := MeshInstance3D.new()
    instance.name = name_hint
    instance.mesh = mesh
    instance.material_override = mat
    instance.position = position
    instance.rotation = rotation
    parent.add_child(instance)
    return instance


static func add_sphere(
        parent: Node3D,
        radius: float,
        position: Vector3,
        mat: Material,
        scale: Vector3 = Vector3.ONE,
        name_hint: String = "Sphere"
    ) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 12
    mesh.rings = 6
    var instance := MeshInstance3D.new()
    instance.name = name_hint
    instance.mesh = mesh
    instance.material_override = mat
    instance.position = position
    instance.scale = scale
    parent.add_child(instance)
    return instance


static func add_capsule(
        parent: Node3D,
        radius: float,
        height: float,
        position: Vector3,
        mat: Material,
        rotation: Vector3 = Vector3.ZERO,
        name_hint: String = "Capsule"
    ) -> MeshInstance3D:
    var mesh := CapsuleMesh.new()
    mesh.radius = radius
    mesh.height = max(height, radius * 2.05)
    mesh.radial_segments = 10
    mesh.rings = 5
    var instance := MeshInstance3D.new()
    instance.name = name_hint
    instance.mesh = mesh
    instance.material_override = mat
    instance.position = position
    instance.rotation = rotation
    parent.add_child(instance)
    return instance


static func add_collision_box(parent: CollisionObject3D, size: Vector3, position: Vector3) -> CollisionShape3D:
    var shape := BoxShape3D.new()
    shape.size = size
    var collision := CollisionShape3D.new()
    collision.shape = shape
    collision.position = position
    parent.add_child(collision)
    return collision


static func add_collision_capsule(parent: CollisionObject3D, radius: float, height: float, position: Vector3) -> CollisionShape3D:
    var shape := CapsuleShape3D.new()
    shape.radius = radius
    shape.height = max(height, radius * 2.05)
    var collision := CollisionShape3D.new()
    collision.shape = shape
    collision.position = position
    parent.add_child(collision)
    return collision


static func add_glow_light(parent: Node3D, position: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
    var light := OmniLight3D.new()
    light.position = position
    light.light_color = color
    light.light_energy = energy
    light.omni_range = light_range
    light.shadow_enabled = false
    parent.add_child(light)
    return light
