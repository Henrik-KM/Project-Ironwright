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


static func add_beveled_box(
        parent: Node3D,
        size: Vector3,
        position: Vector3,
        mat: Material,
        rotation: Vector3 = Vector3.ZERO,
        name_hint: String = "BeveledBox",
        bevel_ratio: float = 0.14
    ) -> Node3D:
    # Original high-definition hard-surface treatment. A recessed core, raised
    # top skin, rounded rails and corner caps replace the toy-like razor edges
    # of a single BoxMesh while keeping the same authored proportions.
    var shell := Node3D.new()
    shell.name = name_hint
    shell.position = position
    shell.rotation = rotation
    parent.add_child(shell)
    var smallest := minf(size.x, minf(size.y, size.z))
    var bevel := clampf(smallest * bevel_ratio, 0.018, smallest * 0.42)
    var core_size := Vector3(maxf(0.02, size.x - bevel * 2.0), maxf(0.02, size.y - bevel * 2.0), maxf(0.02, size.z - bevel * 2.0))
    add_box(shell, core_size, Vector3(0.0, -bevel * 0.22, 0.0), mat, Vector3.ZERO, "%sCore" % name_hint)
    var top_size := Vector3(maxf(0.02, size.x - bevel * 1.45), maxf(0.02, size.y * 0.12), maxf(0.02, size.z - bevel * 1.45))
    add_box(shell, top_size, Vector3(0.0, size.y * 0.5 - bevel * 0.5, 0.0), mat, Vector3.ZERO, "%sTopSkin" % name_hint)
    var edge_x := maxf(0.02, size.x - bevel * 2.0)
    var edge_z := maxf(0.02, size.z - bevel * 2.0)
    var top_y := size.y * 0.5 - bevel
    for side in [-1.0, 1.0]:
        add_tapered_cylinder(shell, bevel, bevel * 0.92, edge_x, Vector3(0.0, top_y, side * (size.z * 0.5 - bevel)), mat, Vector3(0.0, 0.0, PI * 0.5), "%sTopRail" % name_hint)
        add_tapered_cylinder(shell, bevel, bevel * 0.92, edge_z, Vector3(side * (size.x * 0.5 - bevel), top_y, 0.0), mat, Vector3(PI * 0.5, 0.0, 0.0), "%sSideRail" % name_hint)
        for front in [-1.0, 1.0]:
            add_sphere(shell, bevel, Vector3(side * (size.x * 0.5 - bevel), top_y, front * (size.z * 0.5 - bevel)), mat, Vector3.ONE, "%sCornerCap" % name_hint)
    return shell


static func add_cylinder(
        parent: Node3D,
        radius: float,
        height: float,
        position: Vector3,
        mat: Material,
        rotation: Vector3 = Vector3.ZERO,
        name_hint: String = "Cylinder"
    ) -> MeshInstance3D:
    return add_tapered_cylinder(parent, radius, radius, height, position, mat, rotation, name_hint)


static func add_tapered_cylinder(
        parent: Node3D,
        top_radius: float,
        bottom_radius: float,
        height: float,
        position: Vector3,
        mat: Material,
        rotation: Vector3 = Vector3.ZERO,
        name_hint: String = "Cylinder"
    ) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = top_radius
    mesh.bottom_radius = bottom_radius
    mesh.height = height
    mesh.radial_segments = 32
    mesh.rings = 3
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
    mesh.radial_segments = 32
    mesh.rings = 24
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
    mesh.radial_segments = 32
    mesh.rings = 20
    var instance := MeshInstance3D.new()
    instance.name = name_hint
    instance.mesh = mesh
    instance.material_override = mat
    instance.position = position
    instance.rotation = rotation
    parent.add_child(instance)
    return instance


static func add_surface_panel(
        parent: Node3D,
        size: Vector3,
        position: Vector3,
        base_mat: Material,
        accent_mat: Material,
        rotation: Vector3 = Vector3.ZERO,
        name_hint: String = "SurfacePanel"
    ) -> Node3D:
    # A layered panel reads as manufactured surface detail at tactical scale:
    # inset core, raised cap, edge rails and four fasteners. It stays composed
    # of cheap primitives so it remains safe for large autonomous populations.
    var panel := Node3D.new()
    panel.name = name_hint
    panel.position = position
    panel.rotation = rotation
    parent.add_child(panel)
    var core_size := Vector3(maxf(0.04, size.x * 0.9), maxf(0.04, size.y * 0.72), maxf(0.04, size.z * 0.9))
    add_box(panel, core_size, Vector3.ZERO, base_mat, Vector3.ZERO, "%sCore" % name_hint)
    var cap_size := Vector3(maxf(0.03, size.x * 0.76), maxf(0.025, size.y * 0.18), maxf(0.03, size.z * 0.76))
    add_box(panel, cap_size, Vector3(0.0, size.y * 0.43, 0.0), accent_mat, Vector3.ZERO, "%sCap" % name_hint)
    var rail_size := Vector3(maxf(0.025, size.x * 0.045), maxf(0.025, size.y * 0.22), maxf(0.03, size.z * 0.78))
    for side in [-1.0, 1.0]:
        add_box(panel, rail_size, Vector3(side * size.x * 0.45, size.y * 0.2, 0.0), accent_mat, Vector3.ZERO, "%sRail" % name_hint)
    var rivet_radius := clampf(minf(size.x, size.z) * 0.045, 0.025, 0.075)
    for side in [-1.0, 1.0]:
        for front in [-1.0, 1.0]:
            add_sphere(panel, rivet_radius, Vector3(side * size.x * 0.37, size.y * 0.47, front * size.z * 0.34), accent_mat, Vector3.ONE, "%sRivet" % name_hint)
    return panel


static func add_louvered_panel(
        parent: Node3D,
        size: Vector3,
        position: Vector3,
        base_mat: Material,
        accent_mat: Material,
        rotation: Vector3 = Vector3.ZERO,
        name_hint: String = "LouveredPanel",
        slat_count: int = 4
    ) -> Node3D:
    # Repeated inset louvers give a machine surface a believable heat or air
    # path. The assembly remains a bounded set of cheap meshes for autonomous
    # populations while reading as manufactured hardware from the tactical
    # camera.
    var panel := Node3D.new()
    panel.name = name_hint
    panel.position = position
    panel.rotation = rotation
    parent.add_child(panel)
    add_beveled_box(panel, size, Vector3.ZERO, base_mat, Vector3.ZERO, "%sHousing" % name_hint, 0.18)
    var count := maxi(2, slat_count)
    for index in range(count):
        var fraction := float(index) / float(count - 1)
        var slat_y := lerpf(-size.y * 0.29, size.y * 0.29, fraction)
        add_beveled_box(
            panel,
            Vector3(size.x * 0.74, maxf(0.025, size.y * 0.085), maxf(0.018, size.z * 0.11)),
            Vector3(0.0, slat_y, -size.z * 0.5 - 0.012),
            accent_mat,
            Vector3(-0.16, 0.0, 0.0),
            "%sSlat%d" % [name_hint, index],
            0.2
        )
    return panel


static func add_organic_plate(
        parent: Node3D,
        radius: float,
        position: Vector3,
        base_mat: Material,
        edge_mat: Material,
        scale: Vector3 = Vector3.ONE,
        name_hint: String = "OrganicPlate"
    ) -> Node3D:
    # Overlapping wet shell and dry edge give organic families a readable
    # material break without introducing a second texture or shader pipeline.
    var plate := Node3D.new()
    plate.name = name_hint
    plate.position = position
    plate.scale = scale
    parent.add_child(plate)
    add_sphere(plate, radius, Vector3.ZERO, base_mat, Vector3.ONE, "%sShell" % name_hint)
    add_sphere(plate, radius * 0.76, Vector3(0.0, radius * 0.42, -radius * 0.08), edge_mat, Vector3(1.0, 0.16, 0.88), "%sRidge" % name_hint)
    return plate


static func add_ribbed_shell(
        parent: Node3D,
        radius: float,
        position: Vector3,
        base_mat: Material,
        ridge_mat: Material,
        scale: Vector3 = Vector3.ONE,
        name_hint: String = "RibbedShell"
    ) -> Node3D:
    # A layered thorax has a readable biological construction: wet core,
    # lateral shell lobes and raised dorsal ribs. The ribs are deliberately
    # asymmetric so the family does not read like a mirrored prop.
    var shell := Node3D.new()
    shell.name = name_hint
    shell.position = position
    shell.scale = scale
    parent.add_child(shell)
    add_sphere(shell, radius, Vector3.ZERO, base_mat, Vector3.ONE, "%sCore" % name_hint)
    for side in [-1.0, 1.0]:
        add_sphere(shell, radius * 0.58, Vector3(side * radius * 0.78, radius * 0.12, radius * 0.05), ridge_mat, Vector3(0.62, 0.9, 1.2), "%sLateralLobe" % name_hint)
    for index in range(4):
        var rib_z := -radius * 0.65 + float(index) * radius * 0.43
        var rib_height := radius * (1.18 + (0.08 if index == 1 else 0.0))
        add_capsule(shell, radius * 0.075, rib_height, Vector3(-radius * 0.04 + (0.04 if index == 2 else 0.0), radius * 0.62, rib_z), ridge_mat, Vector3(0.0, 0.0, PI * 0.5), "%sDorsalRib" % name_hint)
    return shell


static func add_segmented_carapace(
        parent: Node3D,
        radius: float,
        position: Vector3,
        base_mat: Material,
        edge_mat: Material,
        scale: Vector3 = Vector3.ONE,
        segment_count: int = 4,
        name_hint: String = "SegmentedCarapace"
    ) -> Node3D:
    # Shared high-definition anatomy for the organic roster. A wet central
    # body remains cheap to simulate, while overlapping segment plates create
    # a readable shell construction instead of a single smooth toy sphere.
    var shell := Node3D.new()
    shell.name = name_hint
    shell.position = position
    shell.scale = scale
    parent.add_child(shell)
    add_sphere(shell, radius * 0.9, Vector3.ZERO, base_mat, Vector3.ONE, "%sCore" % name_hint)
    var count := maxi(2, segment_count)
    for index in range(count):
        var fraction := float(index) / float(count - 1)
        var segment_z := lerpf(-radius * 0.68, radius * 0.68, fraction)
        var segment_radius := radius * (0.31 + 0.04 * sin(fraction * PI))
        var segment_scale := Vector3(1.18 - absf(fraction - 0.5) * 0.16, 0.62, 0.8)
        add_organic_plate(
            shell,
            segment_radius,
            Vector3(0.0, radius * (0.31 + 0.05 * sin(fraction * PI)), segment_z),
            base_mat,
            edge_mat,
            segment_scale,
            "%sSegment%d" % [name_hint, index]
        )
    for side in [-1.0, 1.0]:
        add_tapered_cylinder(
            shell,
            radius * 0.065,
            radius * 0.09,
            radius * 1.18,
            Vector3(side * radius * 0.74, radius * 0.2, radius * 0.04),
            edge_mat,
            Vector3(0.0, 0.0, side * 0.5),
            "%sLateralSeam" % name_hint
        )
    return shell


static func add_membrane_fan(
        parent: Node3D,
        radius: float,
        position: Vector3,
        mat: Material,
        fan_count: int = 5,
        name_hint: String = "MembraneFan"
    ) -> Node3D:
    # Thin overlapping fins provide a family-level silhouette break for
    # spore-bearing or veil-bearing creatures without adding a shader pass.
    var fan := Node3D.new()
    fan.name = name_hint
    fan.position = position
    parent.add_child(fan)
    var count := maxi(3, fan_count)
    for index in range(count):
        var fraction := float(index) / float(count - 1)
        var side := fraction * 2.0 - 1.0
        var blade := add_sphere(
            fan,
            radius * (0.42 - absf(side) * 0.08),
            Vector3(side * radius * 0.78, absf(side) * radius * 0.18, 0.0),
            mat,
            Vector3(0.34, 1.45 - absf(side) * 0.22, 0.78),
            "%sBlade%d" % [name_hint, index]
        )
        blade.rotation.z = side * 0.42
    return fan


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
