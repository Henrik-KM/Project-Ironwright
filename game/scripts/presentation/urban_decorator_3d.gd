extends Node

## Adds readable blue-hour street detail and distant organic unease.

var world: Node3D
var elapsed: float = 0.0
var flicker_lights: Array[OmniLight3D] = []
var phases: Dictionary = {}
var rust_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var concrete_material: StandardMaterial3D
var leaf_material: StandardMaterial3D
var organic_material: StandardMaterial3D
var puddle_material: StandardMaterial3D


func configure(next_world: Node3D) -> void:
    world = next_world


func _ready() -> void:
    _create_materials()
    _build_city_detail()


func _process(delta: float) -> void:
    elapsed += delta
    for light in flicker_lights:
        if not is_instance_valid(light):
            continue
        if not phases.has(light):
            phases[light] = float(light.get_instance_id() % 97) * 0.13
        var phase_value := float(phases[light])
        var base_energy := float(light.get_meta(&"base_energy", light.light_energy))
        light.light_energy = base_energy * (0.88 + sin(elapsed * 3.7 + phase_value) * 0.08 + sin(elapsed * 13.1 + phase_value) * 0.025)


func _create_materials() -> void:
    rust_material = ModelKit3D.material(Color("72462e"), 0.46, 0.72)
    dark_material = ModelKit3D.material(Color("20282a"), 0.78, 0.38)
    concrete_material = ModelKit3D.material(Color("4a4946"), 0.0, 0.94)
    leaf_material = ModelKit3D.material(Color("344635"), 0.0, 0.88)
    organic_material = ModelKit3D.material(Color("40282f"), 0.02, 0.78, Color("8e2935"), 0.55)
    puddle_material = StandardMaterial3D.new()
    puddle_material.albedo_color = Color(0.12, 0.2, 0.24, 0.48)
    puddle_material.metallic = 0.42
    puddle_material.roughness = 0.12
    puddle_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _build_city_detail() -> void:
    if world == null:
        return
    var root := Node3D.new()
    root.name = "UrbanAestheticPass"
    world.add_child(root)

    var puddles := [
        [Vector3(-1.8, 0.035, -18.0), Vector2(4.8, 1.25), 0.08],
        [Vector3(2.6, 0.035, 21.5), Vector2(3.7, 1.0), -0.18],
        [Vector3(-28.2, 0.035, 7.0), Vector2(4.2, 1.1), 1.52],
        [Vector3(28.0, 0.035, -8.5), Vector2(3.5, 1.25), 1.38],
        [Vector3(0.8, 0.035, -49.0), Vector2(4.5, 1.2), -0.07],
        [Vector3(-0.6, 0.035, 48.5), Vector2(3.8, 1.0), 0.11],
    ]
    for item in puddles:
        _add_puddle(root, item[0], item[1], float(item[2]))

    _build_warm_windows(root)
    _build_shopfronts(root)
    _build_street_props(root)
    _build_overgrowth(root)
    _build_organic_growth(root)
    _build_motes(root)


func _build_warm_windows(root: Node3D) -> void:
    var positions := [
        Vector3(-8.1, 4.2, -21.1), Vector3(-11.0, 6.7, -21.1),
        Vector3(8.2, 3.9, 21.1), Vector3(11.0, 6.4, 21.1),
        Vector3(-35.2, 5.0, 21.1), Vector3(35.1, 7.0, -21.1),
        Vector3(-8.0, 8.2, -49.1), Vector3(8.3, 5.5, 49.1),
    ]
    var glass := ModelKit3D.material(Color("6e4b2c"), 0.05, 0.34, Color("ff9e4d"), 2.6)
    for index in range(positions.size()):
        var position: Vector3 = positions[index]
        var size := Vector3(1.25, 1.05, 0.08)
        if absf(position.x) > 20.0 and absf(position.z) < 25.0:
            size = Vector3(0.08, 1.05, 1.25)
        ModelKit3D.add_box(root, size, position, glass, Vector3.ZERO, "SurvivorWindow")
        if index % 3 == 0:
            flicker_lights.append(_add_light(root, position + Vector3(0.0, 0.0, 0.25), Color("ffad62"), 0.6, 5.0))


func _build_shopfronts(root: Node3D) -> void:
    var cyan_sign := ModelKit3D.material(Color("284d52"), 0.18, 0.32, Color("6de0e4"), 3.0)
    var warm_sign := ModelKit3D.material(Color("6d3f28"), 0.18, 0.36, Color("ff8b46"), 2.7)
    ModelKit3D.add_box(root, Vector3(3.4, 0.55, 0.12), Vector3(-12.0, 2.6, 21.15), cyan_sign, Vector3.ZERO, "ClinicSign")
    ModelKit3D.add_box(root, Vector3(0.12, 0.65, 3.0), Vector3(21.15, 2.8, -12.0), warm_sign, Vector3.ZERO, "WorkshopSign")
    flicker_lights.append(_add_light(root, Vector3(-12.0, 2.4, 20.5), Color("78e5e8"), 0.9, 6.5))
    flicker_lights.append(_add_light(root, Vector3(20.5, 2.5, -12.0), Color("ff9450"), 0.85, 6.0))


func _build_street_props(root: Node3D) -> void:
    var positions := [Vector3(-5.6, 0.0, -24.0), Vector3(5.5, 0.0, 24.0), Vector3(-24.0, 0.0, 5.6), Vector3(24.0, 0.0, -5.6)]
    for index in range(positions.size()):
        var position: Vector3 = positions[index]
        ModelKit3D.add_box(root, Vector3(1.35, 0.12, 0.45), position + Vector3(0.0, 0.65, 0.0), rust_material, Vector3(0.0, float(index) * 0.42, 0.0), "StreetBench")
        ModelKit3D.add_cylinder(root, 0.07, 0.65, position + Vector3(-0.48, 0.32, 0.0), dark_material, Vector3.ZERO, "BenchLeg")
        ModelKit3D.add_cylinder(root, 0.07, 0.65, position + Vector3(0.48, 0.32, 0.0), dark_material, Vector3.ZERO, "BenchLeg")
    for position in [Vector3(-6.2, 0.0, 13.0), Vector3(6.0, 0.0, -13.0), Vector3(-30.0, 0.0, -5.5), Vector3(30.0, 0.0, 5.5)]:
        ModelKit3D.add_box(root, Vector3(0.75, 1.1, 0.75), position + Vector3(0.0, 0.55, 0.0), dark_material, Vector3.ZERO, "MunicipalBin")
        ModelKit3D.add_box(root, Vector3(0.82, 0.12, 0.82), position + Vector3(0.0, 1.15, 0.0), rust_material, Vector3(0.05, 0.0, 0.08), "BinLid")


func _build_overgrowth(root: Node3D) -> void:
    var patches := [Vector3(-18.0, 0.0, -5.4), Vector3(18.0, 0.0, 5.5), Vector3(-5.5, 0.0, 34.0), Vector3(5.4, 0.0, -35.0), Vector3(-34.0, 0.0, 5.5), Vector3(34.0, 0.0, -5.5)]
    for patch_index in range(patches.size()):
        var patch: Vector3 = patches[patch_index]
        for stem_index in range(7):
            var angle := float(stem_index) * 2.399 + float(patch_index)
            var radius := 0.25 + float(stem_index % 3) * 0.22
            var position := patch + Vector3(cos(angle) * radius, 0.15, sin(angle) * radius)
            ModelKit3D.add_capsule(root, 0.035, 0.65 + float(stem_index % 3) * 0.18, position, leaf_material, Vector3(0.15 * sin(angle), 0.0, 0.22 * cos(angle)), "StreetWeed")


func _build_organic_growth(root: Node3D) -> void:
    var patches := [Vector3(-50.0, 0.0, -49.0), Vector3(51.0, 0.0, -38.0), Vector3(-47.0, 0.0, 48.0), Vector3(52.0, 0.0, 51.0)]
    for patch_index in range(patches.size()):
        var patch: Vector3 = patches[patch_index]
        for spine_index in range(8):
            var angle := TAU * float(spine_index) / 8.0
            var height := 1.0 + float((spine_index + patch_index) % 4) * 0.55
            var position := patch + Vector3(cos(angle) * 1.6, height * 0.45, sin(angle) * 1.6)
            ModelKit3D.add_capsule(root, 0.11, height, position, organic_material, Vector3(cos(angle) * 0.48, 0.0, -sin(angle) * 0.48), "OrganicSpine")
        ModelKit3D.add_sphere(root, 0.75, patch + Vector3(0.0, 0.45, 0.0), organic_material, Vector3(1.45, 0.6, 1.45), "OrganicNestMass")
        flicker_lights.append(_add_light(root, patch + Vector3(0.0, 0.8, 0.0), Color("a82d3c"), 0.42, 5.0))


func _build_motes(root: Node3D) -> void:
    var motes := CPUParticles3D.new()
    motes.name = "BlueHourMotes"
    motes.amount = 160
    motes.lifetime = 12.0
    motes.preprocess = 10.0
    motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    motes.emission_box_extents = Vector3(60.0, 9.0, 60.0)
    motes.position = Vector3(0.0, 5.5, 0.0)
    motes.direction = Vector3(0.4, 0.1, 0.2)
    motes.spread = 180.0
    motes.gravity = Vector3(0.0, -0.018, 0.0)
    motes.initial_velocity_min = 0.04
    motes.initial_velocity_max = 0.16
    motes.scale_amount_min = 0.025
    motes.scale_amount_max = 0.07
    motes.color = Color(0.72, 0.82, 0.87, 0.28)
    motes.mesh = _particle_mesh(Color(0.72, 0.82, 0.87, 0.28), Vector2(0.055, 0.055))
    root.add_child(motes)


func _add_light(parent: Node3D, position: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
    var light := OmniLight3D.new()
    light.position = position
    light.light_color = color
    light.light_energy = energy
    light.omni_range = light_range
    light.shadow_enabled = false
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


func _particle_mesh(color: Color, size: Vector2) -> QuadMesh:
    var mesh := QuadMesh.new()
    mesh.size = size
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.vertex_color_use_as_albedo = true
    mesh.material = material
    return mesh
