extends Node

## Builds and animates the warm, inhabited Heartforge sanctuary.

var world: Node3D
var heartforge: Node3D
var integrity: float = 1.0
var elapsed: float = 0.0
var warm_lights: Array[OmniLight3D] = []
var flicker_lights: Array[OmniLight3D] = []
var light_phases: Dictionary = {}
var warm_material: StandardMaterial3D
var cyan_material: StandardMaterial3D
var rust_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var puddle_material: StandardMaterial3D


func configure(next_world: Node3D, next_heartforge: Node3D) -> void:
    world = next_world
    heartforge = next_heartforge


func _ready() -> void:
    _create_materials()
    _build_camp()


func _process(delta: float) -> void:
    elapsed += delta
    var health_multiplier := lerpf(0.45, 1.0, integrity)
    if integrity < 0.32:
        health_multiplier *= 0.8 + sin(elapsed * 9.0) * 0.18
    for light in flicker_lights:
        if not is_instance_valid(light):
            continue
        if not light_phases.has(light):
            light_phases[light] = float(light.get_instance_id() % 113) * 0.11
        var phase_value := float(light_phases[light])
        var base_energy := float(light.get_meta(&"base_energy", light.light_energy))
        var flicker := 0.92 + sin(elapsed * 4.1 + phase_value) * 0.055 + sin(elapsed * 11.7 + phase_value * 1.8) * 0.018
        light.light_energy = base_energy * flicker * health_multiplier
    for light in warm_lights:
        if not is_instance_valid(light) or light in flicker_lights:
            continue
        light.light_energy = float(light.get_meta(&"base_energy", light.light_energy)) * health_multiplier


func set_integrity(value: float) -> void:
    integrity = clampf(value, 0.0, 1.0)


func _create_materials() -> void:
    warm_material = ModelKit3D.material(Color("7f4b28"), 0.18, 0.58, Color("ff9b43"), 2.8)
    cyan_material = ModelKit3D.material(Color("244c52"), 0.38, 0.34, Color("75e4e8"), 2.5)
    rust_material = ModelKit3D.material(Color("72462e"), 0.46, 0.72)
    dark_material = ModelKit3D.material(Color("20282a"), 0.78, 0.38)
    puddle_material = StandardMaterial3D.new()
    puddle_material.albedo_color = Color(0.12, 0.2, 0.24, 0.48)
    puddle_material.metallic = 0.42
    puddle_material.roughness = 0.12
    puddle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _build_camp() -> void:
    if world == null or heartforge == null:
        return
    var camp := Node3D.new()
    camp.name = "CozyHeartforgeCamp"
    world.add_child(camp)
    camp.position = heartforge.global_position

    _add_puddle(camp, Vector3(-5.2, 0.035, 2.4), Vector2(3.3, 1.25), 0.22)
    _add_puddle(camp, Vector3(5.0, 0.035, -2.1), Vector2(2.5, 1.0), -0.34)

    ModelKit3D.add_box(camp, Vector3(5.8, 0.12, 3.2), Vector3(-4.8, 3.45, 2.9), rust_material, Vector3(0.03, -0.08, -0.08), "WorkshopCanopy")
    for position in [Vector3(-7.2, 1.7, 1.6), Vector3(-2.45, 1.7, 1.6), Vector3(-7.2, 1.7, 4.2), Vector3(-2.45, 1.7, 4.2)]:
        ModelKit3D.add_cylinder(camp, 0.08, 3.4, position, dark_material, Vector3.ZERO, "CanopyPost")

    ModelKit3D.add_box(camp, Vector3(3.6, 0.24, 1.25), Vector3(-4.9, 0.85, 2.7), dark_material, Vector3.ZERO, "Workbench")
    ModelKit3D.add_box(camp, Vector3(3.2, 0.65, 0.18), Vector3(-4.9, 1.35, 3.2), rust_material, Vector3.ZERO, "ToolWall")
    for index in range(6):
        var x := -6.1 + float(index) * 0.48
        var material := cyan_material if index == 4 else dark_material
        ModelKit3D.add_cylinder(camp, 0.055, 0.72 + float(index % 3) * 0.16, Vector3(x, 1.36, 3.02), material, Vector3(0.0, 0.0, 0.18 * float(index % 2)), "HangingTool")

    _add_crate_stack(camp, Vector3(5.3, 0.0, 3.2), 3)
    _add_crate_stack(camp, Vector3(-6.5, 0.0, -2.5), 2)
    _add_barrel(camp, Vector3(4.8, 0.0, 4.7), Color("6e4c34"))
    _add_barrel(camp, Vector3(5.8, 0.0, 4.45), Color("38545b"))

    ModelKit3D.add_box(camp, Vector3(1.4, 0.16, 0.55), Vector3(-2.7, 0.62, -4.45), rust_material, Vector3.ZERO, "BenchSeat")
    for side in [-1.0, 1.0]:
        ModelKit3D.add_box(camp, Vector3(0.12, 0.62, 0.12), Vector3(-2.7 + side * 0.52, 0.31, -4.45), dark_material, Vector3.ZERO, "BenchLeg")
    ModelKit3D.add_box(camp, Vector3(1.25, 0.04, 0.5), Vector3(-2.7, 0.72, -4.42), ModelKit3D.material(Color("66594f"), 0.0, 0.96), Vector3(0.03, 0.0, -0.03), "FoldedBlanket")
    ModelKit3D.add_cylinder(camp, 0.16, 0.28, Vector3(-1.95, 0.16, -4.05), dark_material, Vector3.ZERO, "Kettle")

    _build_string_lights(camp)
    _build_embers(camp)
    _build_smoke(camp)
    _add_camp_lights(camp)


func _add_camp_lights(camp: Node3D) -> void:
    var definitions := [
        [Vector3(-4.7, 2.8, 2.8), Color("ffb35e"), 2.2, 11.0, true],
        [Vector3(4.7, 2.4, 3.8), Color("ffc16a"), 1.65, 8.5, false],
        [Vector3(-2.0, 1.4, -4.0), Color("ff9651"), 1.05, 6.5, false],
        [Vector3(0.0, 3.9, 0.0), Color("ff7c32"), 2.7, 17.0, true],
    ]
    for item in definitions:
        var light := _add_light(camp, item[0], item[1], float(item[2]), float(item[3]), bool(item[4]))
        warm_lights.append(light)
        if bool(item[4]):
            flicker_lights.append(light)


func _build_string_lights(camp: Node3D) -> void:
    var cable := ModelKit3D.material(Color("17191a"), 0.4, 0.78)
    var anchors := [Vector3(-7.0, 3.0, 1.6), Vector3(-2.6, 3.0, 1.6), Vector3(2.9, 2.8, 2.2), Vector3(6.0, 2.7, 4.3)]
    for index in range(anchors.size() - 1):
        _add_beam(camp, anchors[index], anchors[index + 1], 0.022, cable)
    for index in range(15):
        var t := float(index) / 14.0
        var position := _sample_polyline(anchors, t)
        position.y -= sin(t * PI) * 0.18
        ModelKit3D.add_sphere(camp, 0.075, position, warm_material, Vector3(1.0, 1.12, 1.0), "WarmBulb")
        if index % 3 == 0:
            var light := _add_light(camp, position, Color("ffb96e"), 0.48, 4.2, false)
            warm_lights.append(light)
            flicker_lights.append(light)


func _build_embers(parent: Node3D) -> void:
    var particles := CPUParticles3D.new()
    particles.name = "HeartforgeEmbers"
    particles.amount = 42
    particles.lifetime = 2.8
    particles.preprocess = 2.0
    particles.position = Vector3(0.0, 1.0, 0.0)
    particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
    particles.emission_sphere_radius = 1.3
    particles.direction = Vector3.UP
    particles.spread = 28.0
    particles.gravity = Vector3(0.0, 0.32, 0.0)
    particles.initial_velocity_min = 0.35
    particles.initial_velocity_max = 1.1
    particles.scale_amount_min = 0.035
    particles.scale_amount_max = 0.09
    particles.color = Color("ff9a3c")
    particles.mesh = _particle_mesh(Color("ff9a3c"), Vector2(0.07, 0.07), true)
    parent.add_child(particles)


func _build_smoke(parent: Node3D) -> void:
    var particles := CPUParticles3D.new()
    particles.name = "HeartforgeSmoke"
    particles.amount = 24
    particles.lifetime = 5.5
    particles.preprocess = 4.0
    particles.position = Vector3(0.0, 4.25, 0.0)
    particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    particles.emission_box_extents = Vector3(0.7, 0.2, 0.7)
    particles.direction = Vector3.UP
    particles.spread = 18.0
    particles.gravity = Vector3(0.0, 0.22, 0.0)
    particles.initial_velocity_min = 0.18
    particles.initial_velocity_max = 0.55
    particles.scale_amount_min = 0.35
    particles.scale_amount_max = 1.15
    particles.color = Color(0.22, 0.25, 0.27, 0.28)
    particles.mesh = _particle_mesh(Color(0.2, 0.22, 0.24, 0.2), Vector2(0.8, 0.8), false)
    parent.add_child(particles)


func _add_light(parent: Node3D, position: Vector3, color: Color, energy: float, light_range: float, shadows: bool) -> OmniLight3D:
    var light := OmniLight3D.new()
    light.position = position
    light.light_color = color
    light.light_energy = energy
    light.omni_range = light_range
    light.shadow_enabled = shadows
    light.set_meta(&"base_energy", energy)
    parent.add_child(light)
    return light


func _add_puddle(parent: Node3D, position: Vector3, size: Vector2, rotation_y: float) -> void:
    var instance := MeshInstance3D.new()
    instance.name = "RainPuddle"
    var mesh := CylinderMesh.new()
    mesh.top_radius = 1.0
    mesh.bottom_radius = 1.0
    mesh.height = 0.025
    mesh.radial_segments = 32
    instance.mesh = mesh
    instance.material_override = puddle_material
    instance.position = position
    instance.rotation.y = rotation_y
    instance.scale = Vector3(size.x, 1.0, size.y)
    parent.add_child(instance)


func _add_crate_stack(parent: Node3D, position: Vector3, count: int) -> void:
    for index in range(count):
        var offset := Vector3(float(index % 2) * 0.75, 0.42 + float(index / 2) * 0.78, float(index % 3) * 0.18)
        ModelKit3D.add_box(parent, Vector3(0.72, 0.72, 0.72), position + offset, rust_material, Vector3(0.02 * index, 0.18 * index, 0.03), "WorkshopCrate")
        ModelKit3D.add_box(parent, Vector3(0.76, 0.07, 0.76), position + offset + Vector3(0.0, 0.37, 0.0), dark_material, Vector3.ZERO, "CrateBand")


func _add_barrel(parent: Node3D, position: Vector3, color: Color) -> void:
    var material := ModelKit3D.material(color, 0.55, 0.6)
    ModelKit3D.add_cylinder(parent, 0.34, 0.95, position + Vector3(0.0, 0.48, 0.0), material, Vector3.ZERO, "WorkshopBarrel")
    ModelKit3D.add_cylinder(parent, 0.37, 0.055, position + Vector3(0.0, 0.18, 0.0), dark_material, Vector3.ZERO, "BarrelBand")
    ModelKit3D.add_cylinder(parent, 0.37, 0.055, position + Vector3(0.0, 0.78, 0.0), dark_material, Vector3.ZERO, "BarrelBand")


func _add_beam(parent: Node3D, start: Vector3, finish: Vector3, radius: float, material: Material) -> void:
    var direction := finish - start
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = maxf(0.01, direction.length())
    mesh.radial_segments = 8
    var instance := MeshInstance3D.new()
    instance.name = "StringLightCable"
    instance.mesh = mesh
    instance.material_override = material
    instance.position = (start + finish) * 0.5
    if direction.length() > 0.001:
        instance.quaternion = Quaternion(Vector3.UP, direction.normalized())
    parent.add_child(instance)


func _sample_polyline(points: Array, t: float) -> Vector3:
    var scaled := clampf(t, 0.0, 1.0) * float(points.size() - 1)
    var index := mini(int(floor(scaled)), points.size() - 2)
    return (points[index] as Vector3).lerp(points[index + 1] as Vector3, scaled - float(index))


func _particle_mesh(color: Color, size: Vector2, unshaded: bool) -> QuadMesh:
    var mesh := QuadMesh.new()
    mesh.size = size
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED if unshaded else BaseMaterial3D.SHADING_MODE_PER_PIXEL
    material.vertex_color_use_as_albedo = true
    mesh.material = material
    return mesh
