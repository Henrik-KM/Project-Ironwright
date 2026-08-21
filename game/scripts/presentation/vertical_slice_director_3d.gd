class_name VerticalSliceDirector3D
extends Node

## A deliberately concentrated presentation pass for the opening Heartforge
## district. The purpose is not to spread more placeholder geometry across the
## whole world; it is to establish one representative frame with stronger
## composition, material hierarchy, silhouettes, weather, environmental story
## and readable combat space before that language is propagated outward.

var world: Node3D
var heartforge: Heartforge3D
var player: Mechromancer3D
var camera: Camera3D
var ecology: EcologyDirector3D
var root: Node3D
var elapsed: float = 0.0
var steam_emitters: Array[CPUParticles3D] = []
var practical_lights: Array[OmniLight3D] = []
var flicker_phase: Dictionary = {}

var masonry: StandardMaterial3D
var soot_masonry: StandardMaterial3D
var interior_dark: StandardMaterial3D
var wet_asphalt: StandardMaterial3D
var wet_concrete: StandardMaterial3D
var wet_concrete_dark: StandardMaterial3D
var painted_metal: StandardMaterial3D
var rust_metal: StandardMaterial3D
var black_metal: StandardMaterial3D
var warm_glass: StandardMaterial3D
var cold_glass: StandardMaterial3D
var fabric: StandardMaterial3D
var organic: StandardMaterial3D
var warning_paint: StandardMaterial3D


func configure(
        next_world: Node3D,
        next_heartforge: Heartforge3D,
        next_player: Mechromancer3D,
        next_camera: Camera3D,
        next_ecology: EcologyDirector3D
    ) -> void:
    world = next_world
    heartforge = next_heartforge
    player = next_player
    camera = next_camera
    ecology = next_ecology


func _ready() -> void:
    if world == null:
        world = get_parent() as Node3D
    _create_materials()
    root = Node3D.new()
    root.name = "HeartforgeVerticalSlice"
    world.add_child.call_deferred(root)
    call_deferred("_build_vertical_slice")


func _process(delta: float) -> void:
    elapsed += delta
    for light in practical_lights:
        if not is_instance_valid(light):
            continue
        if not flicker_phase.has(light):
            flicker_phase[light] = float(light.get_instance_id() % 181) * 0.071
        var phase := float(flicker_phase[light])
        var base := float(light.get_meta(&"vertical_base_energy", light.light_energy))
        light.light_energy = base * (0.96 + sin(elapsed * 2.7 + phase) * 0.028 + sin(elapsed * 17.0 + phase * 1.9) * 0.009)


func _build_vertical_slice() -> void:
    if root == null or not is_instance_valid(root):
        return
    _polish_environment()
    _replace_central_building_visuals()
    _build_heartforge_plaza()
    _build_foreground_refuge_threshold()
    _build_service_lane()
    _build_street_encounter_dressing()
    _build_sanctuary_perimeter()
    _build_workshop_gantry()
    _build_heartforge_maintenance_detail()
    _build_street_story_props()
    _build_local_nest_landmarks()
    _build_weather()
    _build_atmospheric_steam()
    _build_lighting_rig()


func _create_materials() -> void:
    masonry = ModelKit3D.material(Color("504b46"), 0.02, 0.86)
    soot_masonry = ModelKit3D.material(Color("2d3031"), 0.02, 0.9)
    interior_dark = ModelKit3D.material(Color("0d1214"), 0.0, 0.98)
    wet_asphalt = ModelKit3D.material(Color("1b2529"), 0.22, 0.3)
    wet_concrete = ModelKit3D.material(Color("536164"), 0.08, 0.52)
    wet_concrete_dark = ModelKit3D.material(Color("3c4a4d"), 0.14, 0.6)
    painted_metal = ModelKit3D.material(Color("465458"), 0.72, 0.36)
    rust_metal = ModelKit3D.material(Color("6c3f29"), 0.48, 0.64)
    black_metal = ModelKit3D.material(Color("1c282c"), 0.78, 0.34)
    warm_glass = ModelKit3D.material(Color("6b4829"), 0.16, 0.28, Color("f49a4a"), 1.8)
    cold_glass = ModelKit3D.material(Color("21444a"), 0.22, 0.26, Color("65ccd2"), 1.4)
    fabric = ModelKit3D.material(Color("4b3b34"), 0.0, 0.96)
    organic = ModelKit3D.material(Color("351820"), 0.0, 0.78, Color("812738"), 0.32)
    warning_paint = ModelKit3D.material(Color("a65c2c"), 0.12, 0.66)


func _polish_environment() -> void:
    var environment_node := _find_world_environment(world)
    if environment_node == null or environment_node.environment == null:
        return
    var environment := environment_node.environment
    environment.tonemap_exposure = 1.04
    environment.tonemap_white = 2.15
    environment.adjustment_brightness = 0.96
    environment.adjustment_contrast = 1.13
    environment.adjustment_saturation = 0.92
    environment.ambient_light_energy = 0.43
    environment.fog_density = 0.0115
    environment.fog_light_color = Color("607581")
    environment.fog_light_energy = 0.62
    # Keep the Heartforge's warm core and cyan route markers legible without
    # turning wet concrete and puddles into broad white pools.
    environment.glow_intensity = 0.43
    environment.glow_strength = 0.76
    environment.glow_bloom = 0.075


func _replace_central_building_visuals() -> void:
    var city := _find_procedural_city(world)
    if city == null:
        return
    var definitions := [
        ["RuinedBuilding00", Vector3(-14.0, 0.0, -14.0), 6.4, &"pharmacy"],
        ["RuinedBuilding01", Vector3(14.0, 0.0, -14.0), 7.1, &"apartments"],
        ["RuinedBuilding02", Vector3(-14.0, 0.0, 14.0), 5.8, &"workshop"],
        ["RuinedBuilding03", Vector3(14.0, 0.0, 14.0), 6.8, &"municipal"],
    ]
    for definition in definitions:
        var body := city.get_node_or_null(str(definition[0])) as StaticBody3D
        if body == null:
            continue
        for child in body.get_children():
            if child is MeshInstance3D:
                (child as MeshInstance3D).visible = false
        _build_cutaway_facade(body, float(definition[2]), definition[3] as StringName)


func _build_cutaway_facade(body: StaticBody3D, height: float, identity: StringName) -> void:
    var facade := Node3D.new()
    facade.name = "VerticalSliceFacade"
    body.add_child(facade)
    var width := 13.2
    var depth := 12.4
    var floors := maxi(2, int(round(height / 2.35)))

    # The street-facing volume is made from structure and rooms rather than a
    # single opaque cube. It reads as a ruined building but preserves view into
    # the Heartforge plaza from the tactical camera.
    for corner_x in [-1.0, 1.0]:
        for corner_z in [-1.0, 1.0]:
            ModelKit3D.add_beveled_box(
                facade,
                Vector3(0.42, height, 0.42),
                Vector3(corner_x * width * 0.46, height * 0.5, corner_z * depth * 0.46),
                soot_masonry,
                Vector3.ZERO,
                "StructuralPier",
                0.13
            )

    for floor_index in range(floors + 1):
        var y := minf(height, float(floor_index) * 2.25)
        ModelKit3D.add_beveled_box(facade, Vector3(width * 0.92, 0.18, 0.34), Vector3(0.0, y, -depth * 0.46), masonry, Vector3.ZERO, "FloorEdge", 0.18)
        ModelKit3D.add_beveled_box(facade, Vector3(0.34, 0.18, depth * 0.92), Vector3(-width * 0.46, y, 0.0), masonry, Vector3.ZERO, "SideFloorEdge", 0.18)

    # Rear and one side stay mostly intact; the plaza-facing edges are broken
    # into wall panels with gaps, balconies and visible dark interior depth.
    ModelKit3D.add_beveled_box(facade, Vector3(width * 0.92, height * 0.86, 0.28), Vector3(0.0, height * 0.43, depth * 0.46), soot_masonry, Vector3.ZERO, "RearWall", 0.12)
    ModelKit3D.add_beveled_box(facade, Vector3(0.28, height * 0.78, depth * 0.64), Vector3(width * 0.46, height * 0.39, 1.2), masonry, Vector3.ZERO, "OuterWall", 0.12)

    for floor_index in range(floors):
        var y := 1.15 + float(floor_index) * 2.25
        for bay in range(3):
            if (floor_index + bay + int(body.get_instance_id() % 3)) % 4 == 0:
                continue
            var x := -4.0 + float(bay) * 4.0
            ModelKit3D.add_beveled_box(facade, Vector3(2.7, 1.72, 0.18), Vector3(x, y, -depth * 0.46), masonry, Vector3.ZERO, "FacadePanel", 0.16)
            ModelKit3D.add_box(facade, Vector3(1.1, 0.92, 0.07), Vector3(x, y + 0.08, -depth * 0.485), interior_dark, Vector3.ZERO, "WindowVoid")
        if floor_index > 0:
            ModelKit3D.add_beveled_box(facade, Vector3(width * 0.7, 0.12, 0.78), Vector3(-0.6, y - 0.78, -depth * 0.56), black_metal, Vector3(0.0, 0.0, 0.02 * float(floor_index % 2)), "BrokenBalcony", 0.2)

    _add_facade_identity(facade, identity, width, depth)
    _add_roof_damage(facade, width, depth, height)


func _add_facade_identity(parent: Node3D, identity: StringName, width: float, depth: float) -> void:
    match identity:
        &"pharmacy":
            ModelKit3D.add_box(parent, Vector3(3.8, 0.48, 0.13), Vector3(-1.8, 2.7, -depth * 0.52), cold_glass, Vector3(0.0, 0.0, -0.03), "PharmacySign")
            ModelKit3D.add_box(parent, Vector3(2.8, 1.8, 0.12), Vector3(2.6, 1.25, -depth * 0.52), warm_glass, Vector3.ZERO, "OccupiedWindow")
        &"workshop":
            ModelKit3D.add_box(parent, Vector3(5.0, 0.52, 0.13), Vector3(0.5, 2.4, -depth * 0.52), warning_paint, Vector3(0.0, 0.0, 0.04), "WorkshopFascia")
            for index in range(4):
                ModelKit3D.add_box(parent, Vector3(0.16, 2.1, 0.15), Vector3(-3.0 + float(index) * 2.0, 1.05, -depth * 0.53), black_metal, Vector3.ZERO, "ShutterRib")
        &"municipal":
            for index in range(3):
                ModelKit3D.add_cylinder(parent, 0.16, 2.7, Vector3(-3.0 + float(index) * 3.0, 1.35, -depth * 0.54), masonry, Vector3.ZERO, "MunicipalColumn")
            ModelKit3D.add_box(parent, Vector3(7.8, 0.42, 0.18), Vector3(0.0, 3.0, -depth * 0.53), masonry, Vector3.ZERO, "MunicipalLintel")
        &"apartments":
            for index in range(3):
                ModelKit3D.add_box(parent, Vector3(2.2, 0.1, 0.62), Vector3(-3.2 + float(index) * 3.2, 3.0 + float(index % 2) * 2.15, -depth * 0.56), black_metal, Vector3.ZERO, "FireEscape")
                _add_hanging_cloth(parent, Vector3(-3.2 + float(index) * 3.2, 3.1 + float(index % 2) * 2.15, -depth * 0.67), index)


func _add_roof_damage(parent: Node3D, width: float, depth: float, height: float) -> void:
    for index in range(5):
        var x := -width * 0.35 + float(index) * width * 0.17
        ModelKit3D.add_beveled_box(parent, Vector3(width * 0.2, 0.35 + float(index % 2) * 0.3, depth * 0.34), Vector3(x, height + 0.16 + float(index % 2) * 0.22, 1.4 + float(index % 3) * 0.7), soot_masonry, Vector3(0.04 * index, 0.12 * index, 0.08 - float(index) * 0.025), "BrokenRoofSlab", 0.14)


func _build_heartforge_plaza() -> void:
    var plaza := Node3D.new()
    plaza.name = "HeartforgePlazaDetail"
    root.add_child(plaza)

    # A recessed service ring establishes a visual centre around the forge.
    # It is presentation-only and deliberately leaves the existing player
    # route and Heartforge collision untouched.
    var service_ring := Node3D.new()
    service_ring.name = "HeartforgeServiceRing"
    plaza.add_child(service_ring)
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = 2.72
    ring_mesh.outer_radius = 3.02
    ring_mesh.rings = 20
    ring_mesh.ring_segments = 56
    var ring_instance := MeshInstance3D.new()
    ring_instance.name = "ForgeRecessedServiceRing"
    ring_instance.mesh = ring_mesh
    ring_instance.material_override = black_metal
    ring_instance.position = Vector3(0.0, 0.13, 0.0)
    service_ring.add_child(ring_instance)
    for index in range(8):
        var angle := TAU * float(index) / 8.0
        var marker_material := warm_glass if index % 2 == 0 else cold_glass
        ModelKit3D.add_beveled_box(
            service_ring,
            Vector3(0.72, 0.065, 0.16),
            Vector3(cos(angle) * 3.16, 0.18, sin(angle) * 3.16),
            marker_material,
            Vector3(0.0, angle, 0.0),
            "ForgeServiceMarker",
            0.18
        )
    var ring_light := _add_light(service_ring, Vector3(0.0, 0.38, 0.0), Color("80cdd4"), 0.18, 6.0, false)
    ring_light.set_meta(&"vertical_base_energy", 0.18)
    practical_lights.append(ring_light)

    # Broken municipal pavers create human scale around the forge instead of a
    # single featureless grey polygon.
    for x in range(-5, 6):
        for z in range(-5, 6):
            if abs(x) <= 2 and abs(z) <= 2:
                continue
            var jitter_y := 0.055 + float((x * 7 + z * 11) % 5) * 0.006
            var rotation := float((x * 13 + z * 17) % 9 - 4) * 0.009
            var paver_material := wet_concrete if abs(x * 3 + z * 5) % 4 != 0 else wet_concrete_dark
            ModelKit3D.add_box(plaza, Vector3(1.12, 0.07, 1.12), Vector3(float(x) * 1.16, jitter_y, float(z) * 1.16), paver_material, Vector3(0.01 * float((x + z) % 2), rotation, 0.0), "BrokenPaver")

    # Drainage, patched utility cuts and old municipal markings.
    for index in range(5):
        ModelKit3D.add_box(plaza, Vector3(1.65, 0.04, 0.62), Vector3(-5.0 + float(index) * 2.5, 0.105, 7.15), black_metal, Vector3.ZERO, "DrainGrate")
        for bar in range(5):
            ModelKit3D.add_box(plaza, Vector3(0.08, 0.025, 0.58), Vector3(-5.55 + float(index) * 2.5 + float(bar) * 0.27, 0.132, 7.15), painted_metal, Vector3.ZERO, "DrainSlot")
    ModelKit3D.add_box(plaza, Vector3(9.6, 0.045, 1.2), Vector3(0.0, 0.09, -8.0), wet_asphalt, Vector3(0.0, -0.08, 0.0), "UtilityPatch")
    for index in range(7):
        ModelKit3D.add_box(plaza, Vector3(0.16, 0.025, 1.3), Vector3(-4.5 + float(index) * 1.5, 0.12, -8.0), warning_paint, Vector3(0.0, -0.08, 0.0), "OldHazardStripe")

    _add_puddle(plaza, Vector3(-7.0, 0.115, 3.2), Vector2(2.6, 1.1), -0.22)
    _add_puddle(plaza, Vector3(6.4, 0.115, -5.6), Vector2(2.0, 0.8), 0.31)
    _add_puddle(plaza, Vector3(1.8, 0.115, 8.4), Vector2(1.6, 0.62), -0.12)


func _build_foreground_refuge_threshold() -> void:
    var threshold := Node3D.new()
    threshold.name = "ForegroundRefugeThreshold"
    root.add_child(threshold)

    var slab := ModelKit3D.material(Color("39484b"), 0.28, 0.62)
    var slab_edge := ModelKit3D.material(Color("1b2528"), 0.62, 0.48)
    var route_glow := ModelKit3D.material(Color("315b60"), 0.32, 0.46, Color("74d6db"), 0.72)

    # The lower tactical frame is the player's first lived-in threshold, not
    # an empty camera margin. Broken service slabs add scale and depth while
    # remaining presentation-only and outside the collision-owning city kit.
    for index in range(6):
        var z := 7.0 + float(index) * 1.75
        var width := 5.5 - float(index % 3) * 0.34
        var offset_x := -0.16 if index % 2 == 0 else 0.12
        ModelKit3D.add_beveled_box(
            threshold,
            Vector3(width, 0.09, 1.18),
            Vector3(offset_x, 0.12, z),
            slab,
            Vector3(0.0, 0.012 * float(index % 2), 0.0),
            "ThresholdSlab",
            0.22
        )
        ModelKit3D.add_beveled_box(
            threshold,
            Vector3(width * 0.78, 0.035, 0.08),
            Vector3(offset_x, 0.19, z - 0.42),
            slab_edge,
            Vector3.ZERO,
            "ThresholdSeam",
            0.12
        )

    for side in [-1.0, 1.0]:
        for index in range(3):
            var z := 8.2 + float(index) * 3.5
            ModelKit3D.add_beveled_box(
                threshold,
                Vector3(0.14, 0.16, 1.4),
                Vector3(side * 2.82, 0.2, z),
                route_glow,
                Vector3.ZERO,
                "ThresholdRouteMarker",
                0.16
            )

    _add_puddle(threshold, Vector3(0.4, 0.19, 14.3), Vector2(2.3, 0.58), 0.18)
    var left_light := _add_light(threshold, Vector3(-2.75, 0.72, 11.0), Color("6ebac3"), 0.22, 5.2, false)
    left_light.set_meta(&"vertical_base_energy", 0.22)
    practical_lights.append(left_light)
    var right_light := _add_light(threshold, Vector3(2.75, 0.72, 15.1), Color("d58c56"), 0.18, 5.2, false)
    right_light.set_meta(&"vertical_base_energy", 0.18)
    practical_lights.append(right_light)


func _build_service_lane() -> void:
    var lane := Node3D.new()
    lane.name = "ForgeServiceLane"
    root.add_child(lane)
    # A readable escape / expedition lane extending north keeps the opening
    # composition from feeling like a boxed arena.
    for z in range(-28, -8, 2):
        ModelKit3D.add_box(lane, Vector3(5.4, 0.035, 1.72), Vector3(0.0, 0.11, float(z)), wet_asphalt, Vector3.ZERO, "ServiceLanePatch")
    for z in range(-27, -9, 4):
        ModelKit3D.add_box(lane, Vector3(0.12, 0.025, 1.8), Vector3(-2.25, 0.145, float(z)), warning_paint, Vector3.ZERO, "ServiceEdgeMark")
        ModelKit3D.add_box(lane, Vector3(0.12, 0.025, 1.8), Vector3(2.25, 0.145, float(z)), warning_paint, Vector3.ZERO, "ServiceEdgeMark")


func _build_street_encounter_dressing() -> void:
    var dressing := Node3D.new()
    dressing.name = "AuthoredStreetEncounterDressing"
    root.add_child(dressing)

    # A transit shelter gives the escape lane a human civic history and a
    # readable scale reference. It is deliberately presentation-only: the
    # route remains open and the systemic city owns all collision geometry.
    var shelter := Node3D.new()
    shelter.name = "CollapsedTransitShelter"
    shelter.position = Vector3(-4.9, 0.0, -15.8)
    dressing.add_child(shelter)
    for side in [-1.0, 1.0]:
        ModelKit3D.add_cylinder(shelter, 0.075, 2.65, Vector3(side * 1.45, 1.33, 0.0), black_metal, Vector3.ZERO, "ShelterFrame")
        ModelKit3D.add_cylinder(shelter, 0.06, 2.25, Vector3(side * 1.45, 1.12, -1.15), rust_metal, Vector3(0.08 * side, 0.0, 0.05), "ShelterRearFrame")
    ModelKit3D.add_beveled_box(shelter, Vector3(3.0, 0.12, 1.7), Vector3(0.0, 2.62, 0.08), rust_metal, Vector3(0.05, 0.0, -0.08), "ShelterCanopy", 0.22)
    ModelKit3D.add_box(shelter, Vector3(2.65, 1.55, 0.045), Vector3(0.0, 1.25, 0.03), cold_glass, Vector3(0.0, 0.0, 0.08), "ShelterGlass")
    ModelKit3D.add_beveled_box(shelter, Vector3(2.1, 0.16, 0.48), Vector3(0.0, 0.72, -0.6), painted_metal, Vector3(0.0, 0.0, 0.04), "ShelterBench", 0.2)
    for side in [-1.0, 1.0]:
        ModelKit3D.add_cylinder(shelter, 0.055, 0.68, Vector3(side * 0.78, 0.36, -0.6), black_metal, Vector3.ZERO, "BenchSupport")
    ModelKit3D.add_beveled_box(shelter, Vector3(0.55, 0.78, 0.1), Vector3(-1.72, 1.68, -0.55), warning_paint, Vector3(0.0, 0.0, 0.03), "RouteMarker", 0.16)
    var shelter_light := _add_light(shelter, Vector3(0.0, 2.33, -0.42), Color("6fc8d3"), 0.42, 4.2, false)
    shelter_light.set_meta(&"vertical_base_energy", 0.42)
    practical_lights.append(shelter_light)

    # A municipal relay cabinet and exposed conduit establish a second,
    # functional story beat: the town's infrastructure failed before the
    # Heartforge became the only dependable light.
    var relay := Node3D.new()
    relay.name = "FloodedUtilityRelay"
    relay.position = Vector3(4.55, 0.0, -22.4)
    dressing.add_child(relay)
    ModelKit3D.add_beveled_box(relay, Vector3(1.25, 1.75, 0.72), Vector3(0.0, 0.88, 0.0), painted_metal, Vector3(0.0, -0.06, 0.0), "RelayCabinet", 0.18)
    ModelKit3D.add_surface_panel(relay, Vector3(0.62, 0.72, 0.08), Vector3(0.0, 1.0, -0.39), black_metal, warning_paint, Vector3.ZERO, "RelayAccessPanel")
    ModelKit3D.add_cylinder(relay, 0.14, 1.55, Vector3(-0.42, 1.86, 0.0), rust_metal, Vector3.ZERO, "RelayConduit")
    ModelKit3D.add_cylinder(relay, 0.1, 1.25, Vector3(0.38, 1.72, 0.0), black_metal, Vector3.ZERO, "RelayConduit")
    _add_beam(relay, Vector3(-0.42, 1.15, 0.0), Vector3(-1.8, 0.36, 0.0), 0.045, rust_metal, "RelayGroundCable")
    for index in range(3):
        ModelKit3D.add_box(relay, Vector3(0.12, 0.04, 0.42), Vector3(-0.28 + float(index) * 0.28, 0.22, -0.4), warning_paint, Vector3(0.0, 0.0, -0.28), "RelayHazardStripe")
    var relay_light := _add_light(relay, Vector3(0.0, 1.3, -0.48), Color("ed6042"), 0.28, 2.8, false)
    relay_light.set_meta(&"vertical_base_energy", 0.28)
    practical_lights.append(relay_light)
    _add_puddle(dressing, Vector3(4.2, 0.12, -23.2), Vector2(2.0, 0.68), -0.18)

    # The first visible biological breach is a landmark, not an encounter
    # trigger. It tells the player that the danger ahead is ecological and
    # gives the lane a memorable silhouette without scheduling a wave.
    var breach := Node3D.new()
    breach.name = "OrganicBreachMarker"
    breach.position = Vector3(0.0, 0.0, -30.4)
    dressing.add_child(breach)
    ModelKit3D.add_ribbed_shell(breach, 1.1, Vector3(0.0, 0.72, 0.0), organic, warning_paint, Vector3(1.15, 0.7, 1.35), "BreachRootMass")
    for side in [-1.0, 1.0]:
        var start := Vector3(side * 0.42, 0.7, 0.0)
        var finish := Vector3(side * 1.7, 2.9, 0.2)
        _add_beam(breach, start, finish, 0.12, organic, "BreachSpine")
        _add_beam(breach, finish, Vector3(side * 2.2, 1.25, 0.0), 0.075, organic, "BreachSpine")
    ModelKit3D.add_membrane_fan(breach, 0.8, Vector3(0.0, 1.4, 0.0), organic, 5, "BreachMembrane")
    var breach_light := _add_light(breach, Vector3(0.0, 1.05, -0.35), Color("a82f47"), 0.38, 5.0, false)
    breach_light.set_meta(&"vertical_base_energy", 0.38)
    practical_lights.append(breach_light)


func _build_sanctuary_perimeter() -> void:
    var perimeter := Node3D.new()
    perimeter.name = "ImprovisedSanctuaryPerimeter"
    root.add_child(perimeter)
    var positions := [
        [Vector3(-9.0, 0.0, -6.8), 0.2], [Vector3(-9.5, 0.0, -2.8), -0.1],
        [Vector3(9.2, 0.0, 4.8), -0.18], [Vector3(8.6, 0.0, 8.0), 0.12],
        [Vector3(-5.8, 0.0, 9.4), 1.5], [Vector3(5.2, 0.0, 9.5), 1.56],
    ]
    for index in range(positions.size()):
        var position: Vector3 = positions[index][0]
        var yaw := float(positions[index][1])
        ModelKit3D.add_box(perimeter, Vector3(3.2, 1.05, 0.38), position + Vector3.UP * 0.53, rust_metal if index % 2 == 0 else painted_metal, Vector3(0.0, yaw, 0.0), "WeldedBarricade")
        ModelKit3D.add_box(perimeter, Vector3(2.8, 0.1, 0.08), position + Vector3(0.0, 1.2, 0.0), warning_paint, Vector3(0.0, yaw, 0.0), "BarricadeStripe")
        for leg in [-1.0, 1.0]:
            ModelKit3D.add_box(perimeter, Vector3(0.16, 0.72, 0.6), position + Vector3(leg * 1.25, 0.34, 0.0), black_metal, Vector3(0.0, yaw, 0.1 * leg), "BarricadeFoot")

    # Open northern throat: the base is a refuge, not a sealed RTS compound.
    for x in [-4.4, 4.4]:
        ModelKit3D.add_cylinder(perimeter, 0.12, 4.2, Vector3(x, 2.1, -9.4), black_metal, Vector3.ZERO, "GatePost")
        ModelKit3D.add_box(perimeter, Vector3(0.45, 0.45, 0.25), Vector3(x, 3.65, -9.5), cold_glass, Vector3.ZERO, "GateSensor")


func _build_workshop_gantry() -> void:
    if heartforge == null:
        return
    var gantry := Node3D.new()
    gantry.name = "ForgeMaintenanceGantry"
    root.add_child(gantry)
    for x in [-3.7, 3.7]:
        ModelKit3D.add_cylinder(gantry, 0.14, 5.1, Vector3(x, 2.55, 1.8), painted_metal, Vector3.ZERO, "GantryColumn")
    _add_beam(gantry, Vector3(-3.7, 5.0, 1.8), Vector3(3.7, 5.0, 1.8), 0.12, black_metal, "GantryBeam")
    _add_beam(gantry, Vector3(0.0, 4.9, 1.8), Vector3(0.0, 4.2, -1.8), 0.08, rust_metal, "ServiceBoom")
    ModelKit3D.add_box(gantry, Vector3(0.8, 0.55, 0.62), Vector3(0.0, 4.5, -1.5), black_metal, Vector3(0.0, 0.0, -0.08), "ChainHoist")
    _add_beam(gantry, Vector3(0.0, 4.25, -1.5), Vector3(0.0, 2.6, -1.5), 0.028, black_metal, "HoistChain")
    ModelKit3D.add_box(gantry, Vector3(0.62, 0.25, 0.22), Vector3(0.0, 2.45, -1.5), rust_metal, Vector3(0.0, 0.0, 0.18), "HoistHook")

    # Thick routed power lines connect the inhabited workshop to the forge.
    _add_beam(gantry, Vector3(-3.6, 3.7, 1.8), Vector3(-2.0, 2.4, 0.7), 0.055, black_metal, "PowerUmbilical")
    _add_beam(gantry, Vector3(3.6, 3.7, 1.8), Vector3(2.0, 2.4, 0.7), 0.055, black_metal, "PowerUmbilical")


func _build_heartforge_maintenance_detail() -> void:
    if heartforge == null:
        return
    var detail := Node3D.new()
    detail.name = "HeartforgeMaintenanceDetail"
    root.add_child(detail)

    # The refuge is a working machine, not a decorative cylinder. These two
    # pressure vessels and their gauges give the forge a believable service
    # scale while staying outside the player route and all gameplay collision.
    for side in [-1.0, 1.0]:
        var tank := Node3D.new()
        tank.name = "PressureVessel%s" % ("West" if side < 0.0 else "East")
        tank.position = Vector3(side * 5.15, 0.0, 2.75)
        detail.add_child(tank)
        ModelKit3D.add_beveled_box(tank, Vector3(1.34, 0.32, 1.18), Vector3(0.0, 0.18, 0.0), black_metal, Vector3(0.0, side * 0.08, 0.0), "TankFoot", 0.2)
        ModelKit3D.add_tapered_cylinder(tank, 0.5, 0.62, 1.7, Vector3(0.0, 1.12, 0.0), painted_metal, Vector3.ZERO, "TankBody")
        for y in [0.36, 1.88]:
            ModelKit3D.add_cylinder(tank, 0.57, 0.09, Vector3(0.0, y, 0.0), rust_metal, Vector3.ZERO, "TankBand")
        ModelKit3D.add_surface_panel(tank, Vector3(0.56, 0.7, 0.08), Vector3(0.0, 1.05, -0.56), black_metal, warning_paint, Vector3.ZERO, "TankGaugePanel")
        ModelKit3D.add_cylinder(tank, 0.16, 0.06, Vector3(0.0, 1.24, -0.62), warm_glass, Vector3(1.5708, 0.0, 0.0), "TankGauge")
        _add_beam(tank, Vector3(side * -0.18, 1.94, -0.04), Vector3(side * -0.18, 2.42, -0.04), 0.07, black_metal, "TankValveStem")
        _add_beam(detail, tank.position + Vector3(side * 0.42, 1.48, 0.0), Vector3(side * 2.32, 2.05, -1.48), 0.055, rust_metal, "TankForgeFeed")
        var tank_light := _add_light(tank, Vector3(0.0, 1.55, -0.6), Color("e77a3e"), 0.2, 2.7, false)
        tank_light.set_meta(&"vertical_base_energy", 0.2)
        practical_lights.append(tank_light)

    # A cyan coolant manifold contrasts with the warm furnace and explains
    # the exposed cables that already cross the workshop gantry.
    var manifold := Node3D.new()
    manifold.name = "CoolantManifold"
    manifold.position = Vector3(4.15, 0.0, -1.35)
    detail.add_child(manifold)
    ModelKit3D.add_beveled_box(manifold, Vector3(1.5, 0.22, 0.92), Vector3(0.0, 0.34, 0.0), black_metal, Vector3(0.0, -0.1, 0.0), "ManifoldBase", 0.22)
    for index in range(3):
        var x := -0.48 + float(index) * 0.48
        ModelKit3D.add_cylinder(manifold, 0.11, 1.35, Vector3(x, 1.08, 0.0), painted_metal, Vector3.ZERO, "CoolantRiser")
        ModelKit3D.add_cylinder(manifold, 0.15, 0.08, Vector3(x, 1.78, 0.0), cold_glass, Vector3.ZERO, "CoolantValve")
        _add_beam(manifold, Vector3(x, 0.45, -0.12), Vector3(x * 0.58, 0.45, -0.92), 0.045, black_metal, "CoolantReturn")
    _add_beam(detail, Vector3(4.15, 1.72, -1.35), Vector3(2.0, 2.35, 0.72), 0.06, black_metal, "CoolantForgeFeed")
    var manifold_light := _add_light(manifold, Vector3(0.0, 1.35, -0.45), Color("62dbe4"), 0.36, 4.2, false)
    manifold_light.set_meta(&"vertical_base_energy", 0.36)
    practical_lights.append(manifold_light)

    # The rear service rail, its insulated handles and a small warning plate
    # make the forge maintenance loop legible from the tactical camera.
    var rail := Node3D.new()
    rail.name = "ForgeServiceRail"
    rail.position = Vector3(0.0, 0.0, -2.75)
    detail.add_child(rail)
    for side in [-1.0, 1.0]:
        ModelKit3D.add_cylinder(rail, 0.08, 2.6, Vector3(side * 1.55, 1.32, 0.0), black_metal, Vector3.ZERO, "ServiceRailPost")
    for index in range(4):
        ModelKit3D.add_beveled_box(rail, Vector3(3.1, 0.1, 0.16), Vector3(0.0, 0.38 + float(index) * 0.63, 0.0), painted_metal, Vector3.ZERO, "ServiceRailRung", 0.18)
    ModelKit3D.add_surface_panel(rail, Vector3(0.86, 0.62, 0.08), Vector3(1.96, 1.22, -0.08), black_metal, warning_paint, Vector3.ZERO, "ServiceWarningPlate")


func _build_street_story_props() -> void:
    var props := Node3D.new()
    props.name = "OpeningEnvironmentalStory"
    root.add_child(props)

    # Abandoned evacuation point.
    ModelKit3D.add_box(props, Vector3(4.4, 0.1, 2.2), Vector3(9.2, 0.12, -5.5), fabric, Vector3(0.03, -0.18, 0.0), "CollapsedTentRoof")
    for position in [Vector3(7.4, 0.85, -6.4), Vector3(10.8, 0.85, -4.7)]:
        ModelKit3D.add_cylinder(props, 0.05, 1.7, position, black_metal, Vector3.ZERO, "TentPole")
    for index in range(4):
        ModelKit3D.add_box(props, Vector3(0.72, 0.48, 0.52), Vector3(7.8 + float(index % 2) * 0.85, 0.24, -4.1 + float(index / 2) * 0.7), rust_metal, Vector3(0.04 * index, 0.2 * index, 0.0), "EvacuationCase")

    # A dead municipal drone, implying the Mechromancer is rebuilding from a
    # world that already failed rather than spawning generic fantasy robots.
    ModelKit3D.add_box(props, Vector3(1.5, 0.25, 1.05), Vector3(-8.1, 0.26, -4.0), painted_metal, Vector3(0.16, 0.55, 0.24), "DeadMunicipalDrone")
    for side in [-1.0, 1.0]:
        ModelKit3D.add_cylinder(props, 0.22, 0.16, Vector3(-8.1 + side * 0.78, 0.22, -4.0), black_metal, Vector3(1.5708, 0.0, 0.0), "DroneWheel")

    # Hanging cables create depth and parallax without becoming giant text.
    var cable_points := [
        [Vector3(-9.0, 3.8, -6.8), Vector3(-3.7, 4.8, 1.8)],
        [Vector3(9.2, 3.6, 4.8), Vector3(3.7, 4.6, 1.8)],
        [Vector3(-5.8, 3.2, 9.4), Vector3(-2.4, 3.7, 3.8)],
    ]
    for pair in cable_points:
        _add_beam(props, pair[0], pair[1], 0.022, black_metal, "HangingCable")


func _build_local_nest_landmarks() -> void:
    if ecology == null:
        return
    var nests := Node3D.new()
    nests.name = "VisibleOrganicNests"
    root.add_child(nests)
    var snapshots := ecology.nest_snapshot()
    for data in snapshots:
        var position: Vector3 = data.get("position", Vector3.ZERO)
        var nest := Node3D.new()
        nest.name = "Nest_%02d" % int(data.get("index", 0))
        nest.position = position
        nests.add_child(nest)
        ModelKit3D.add_sphere(nest, 1.4, Vector3(0.0, 0.46, 0.0), organic, Vector3(1.55, 0.48, 1.35), "RootMat")
        for index in range(11):
            var angle := TAU * float(index) / 11.0
            var radius := 1.4 + float(index % 3) * 0.5
            var height := 1.2 + float((index * 5) % 4) * 0.45
            ModelKit3D.add_capsule(nest, 0.1, height, Vector3(cos(angle) * radius, height * 0.45, sin(angle) * radius), organic, Vector3(cos(angle) * 0.5, 0.0, -sin(angle) * 0.5), "NestSpine")
        var light := _add_light(nest, Vector3(0.0, 0.9, 0.0), Color("8f2639"), 0.34, 5.5, false)
        light.set_meta(&"vertical_base_energy", 0.34)
        practical_lights.append(light)


func _build_weather() -> void:
    var rain := CPUParticles3D.new()
    rain.name = "LocalRain"
    rain.amount = 520
    rain.lifetime = 1.4
    rain.preprocess = 1.4
    rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
    rain.emission_box_extents = Vector3(28.0, 10.0, 28.0)
    rain.position = Vector3(0.0, 10.0, 0.0)
    rain.direction = Vector3(0.18, -1.0, 0.08)
    rain.spread = 5.0
    rain.gravity = Vector3(0.0, -12.0, 0.0)
    rain.initial_velocity_min = 9.0
    rain.initial_velocity_max = 14.0
    rain.scale_amount_min = 0.42
    rain.scale_amount_max = 0.9
    var streak := QuadMesh.new()
    streak.size = Vector2(0.018, 0.42)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.7, 0.82, 0.88, 0.28)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    streak.material = material
    rain.mesh = streak
    root.add_child(rain)


func _build_atmospheric_steam() -> void:
    for position in [Vector3(-6.8, 0.15, -7.8), Vector3(7.4, 0.15, 6.9), Vector3(2.4, 0.15, -10.2)]:
        var steam := CPUParticles3D.new()
        steam.name = "StreetSteam"
        steam.position = position
        steam.amount = 18
        steam.lifetime = 3.8
        steam.preprocess = 2.0
        steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
        steam.emission_sphere_radius = 0.18
        steam.direction = Vector3.UP
        steam.spread = 16.0
        steam.gravity = Vector3(0.12, 0.2, 0.08)
        steam.initial_velocity_min = 0.3
        steam.initial_velocity_max = 0.8
        steam.scale_amount_min = 0.32
        steam.scale_amount_max = 1.0
        var cloud := QuadMesh.new()
        cloud.size = Vector2(0.9, 0.9)
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(0.55, 0.62, 0.65, 0.13)
        material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
        cloud.material = material
        steam.mesh = cloud
        root.add_child(steam)
        steam_emitters.append(steam)


func _build_lighting_rig() -> void:
    var definitions := [
        [Vector3(0.0, 5.2, 1.6), Color("ff8d42"), 2.15, 14.0, true, &"heartforge_key"],
        [Vector3(-6.8, 3.2, 2.0), Color("ffb36a"), 0.78, 8.0, true, &"warm_threshold"],
        [Vector3(7.8, 3.0, -2.0), Color("9fcbd8"), 0.58, 9.0, false, &"cool_facade"],
        [Vector3(0.0, 3.4, -10.0), Color("7ec4d1"), 0.5, 9.0, false, &"cool_route"],
        [Vector3(-9.0, 3.8, -7.0), Color("dca46d"), 0.48, 6.5, false, &"warm_district"],
        [Vector3(0.0, 7.2, 8.0), Color("86c9d4"), 0.2, 15.0, false, &"sky_rim"],
        [Vector3(0.0, 4.0, -8.0), Color("d07043"), 0.2, 9.0, false, &"route_warmth"],
    ]
    for data in definitions:
        var light := _add_light(root, data[0], data[1], float(data[2]), float(data[3]), bool(data[4]))
        light.set_meta(&"vertical_base_energy", float(data[2]))
        light.set_meta(&"opening_light_role", data[5])
        practical_lights.append(light)


func _add_hanging_cloth(parent: Node3D, position: Vector3, index: int) -> void:
    ModelKit3D.add_box(parent, Vector3(1.35, 1.1, 0.045), position, fabric, Vector3(0.0, 0.04 * float(index), 0.08 * (-1.0 if index % 2 == 0 else 1.0)), "HangingCloth")


func _add_puddle(parent: Node3D, position: Vector3, size: Vector2, rotation_y: float) -> void:
    var mesh := CylinderMesh.new()
    mesh.top_radius = 1.0
    mesh.bottom_radius = 1.0
    mesh.height = 0.018
    mesh.radial_segments = 32
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.08, 0.15, 0.19, 0.44)
    material.metallic = 0.5
    material.roughness = 0.08
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    var instance := MeshInstance3D.new()
    instance.name = "VerticalSlicePuddle"
    instance.mesh = mesh
    instance.material_override = material
    instance.position = position
    instance.rotation.y = rotation_y
    instance.scale = Vector3(size.x, 1.0, size.y)
    parent.add_child(instance)


func _add_light(parent: Node3D, position: Vector3, color: Color, energy: float, light_range: float, shadows: bool) -> OmniLight3D:
    var light := OmniLight3D.new()
    light.position = position
    light.light_color = color
    light.light_energy = energy
    light.omni_range = light_range
    light.shadow_enabled = shadows
    parent.add_child(light)
    return light


func _add_beam(parent: Node3D, start: Vector3, finish: Vector3, radius: float, material: Material, node_name: String) -> void:
    var direction := finish - start
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = maxf(0.01, direction.length())
    mesh.radial_segments = 8
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = mesh
    instance.material_override = material
    instance.position = (start + finish) * 0.5
    if direction.length() > 0.001:
        instance.quaternion = Quaternion(Vector3.UP, direction.normalized())
    parent.add_child(instance)


func _find_procedural_city(node: Node) -> ProceduralCity3D:
    if node is ProceduralCity3D:
        return node as ProceduralCity3D
    for child in node.get_children():
        var found := _find_procedural_city(child)
        if found != null:
            return found
    return null


func _find_world_environment(node: Node) -> WorldEnvironment:
    if node is WorldEnvironment:
        return node as WorldEnvironment
    for child in node.get_children():
        var found := _find_world_environment(child)
        if found != null:
            return found
    return null
