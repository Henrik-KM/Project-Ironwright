class_name ProceduralCity3D
extends Node3D

const WORLD_EXTENT := 78.0

var road_material: StandardMaterial3D
var sidewalk_material: StandardMaterial3D
var building_materials: Array[StandardMaterial3D] = []
var rubble_material: StandardMaterial3D
var metal_material: StandardMaterial3D
var curb_material: StandardMaterial3D


func _ready() -> void:
    _create_materials()
    _build_ground()
    _build_street_grid()
    _build_street_edges()
    _build_buildings()
    _build_wrecks_and_debris()
    _build_lighting()
    _build_north_ruins()


func _create_materials() -> void:
    road_material = ModelKit3D.material(Color("111517"), 0.05, 0.96)
    sidewalk_material = ModelKit3D.material(Color("252728"), 0.0, 0.94)
    rubble_material = ModelKit3D.material(Color("4a4038"), 0.0, 0.94)
    metal_material = ModelKit3D.material(Color("2e3435"), 0.72, 0.52)
    curb_material = ModelKit3D.material(Color("3a4140"), 0.08, 0.84)
    building_materials = [
        ModelKit3D.material(Color("312c2a"), 0.0, 0.95),
        ModelKit3D.material(Color("282b2c"), 0.0, 0.92),
        ModelKit3D.material(Color("3a302b"), 0.0, 0.96),
    ]


func _build_ground() -> void:
    var ground := StaticBody3D.new()
    ground.name = "Ground"
    add_child(ground)
    ModelKit3D.add_box(ground, Vector3(WORLD_EXTENT * 2.0, 0.35, WORLD_EXTENT * 2.0), Vector3(0.0, -0.2, 0.0), rubble_material, Vector3.ZERO, "CityGround")
    ModelKit3D.add_collision_box(ground, Vector3(WORLD_EXTENT * 2.0, 0.35, WORLD_EXTENT * 2.0), Vector3(0.0, -0.2, 0.0))


func _build_street_grid() -> void:
    for x in [-28.0, 0.0, 28.0]:
        var road := Node3D.new()
        road.name = "RoadX%d" % int(x)
        add_child(road)
        ModelKit3D.add_box(road, Vector3(8.2, 0.08, WORLD_EXTENT * 2.0), Vector3(x, 0.02, 0.0), road_material, Vector3.ZERO, "Road")
        for z in range(-70, 71, 10):
            ModelKit3D.add_box(road, Vector3(0.18, 0.03, 3.2), Vector3(x, 0.075, float(z)), sidewalk_material, Vector3.ZERO, "LaneMark")

    for z in [-28.0, 0.0, 28.0]:
        var road := Node3D.new()
        road.name = "RoadZ%d" % int(z)
        add_child(road)
        ModelKit3D.add_box(road, Vector3(WORLD_EXTENT * 2.0, 0.08, 8.2), Vector3(0.0, 0.025, z), road_material, Vector3.ZERO, "Road")
        for x in range(-70, 71, 10):
            ModelKit3D.add_box(road, Vector3(3.2, 0.03, 0.18), Vector3(float(x), 0.075, z), sidewalk_material, Vector3.ZERO, "LaneMark")


func _build_street_edges() -> void:
    var edges := Node3D.new()
    edges.name = "HighDefinitionStreetEdges"
    add_child(edges)
    # Raised curb segments give the town a consistent street scale while the
    # systemic ground and road bodies remain authoritative for collision.
    for x in [-28.0, 0.0, 28.0]:
        for side in [-1.0, 1.0]:
            for z in range(-70, 71, 12):
                ModelKit3D.add_beveled_box(edges, Vector3(0.46, 0.16, 9.2), Vector3(x + side * 4.34, 0.14, float(z)), curb_material, Vector3(0.0, 0.0, 0.012 * float(int(z / 12.0) % 2)), "StreetCurb", 0.28)
    for z in [-28.0, 0.0, 28.0]:
        for side in [-1.0, 1.0]:
            for x in range(-70, 71, 12):
                ModelKit3D.add_beveled_box(edges, Vector3(9.2, 0.16, 0.46), Vector3(float(x), 0.14, z + side * 4.34), curb_material, Vector3(0.0, 0.012 * float(int(x / 12.0) % 2), 0.0), "StreetCurb", 0.28)


func _build_buildings() -> void:
    var blocks := [
        Vector3(-14.0, 0.0, -14.0), Vector3(14.0, 0.0, -14.0),
        Vector3(-14.0, 0.0, 14.0), Vector3(14.0, 0.0, 14.0),
        Vector3(-42.0, 0.0, -14.0), Vector3(42.0, 0.0, -14.0),
        Vector3(-42.0, 0.0, 14.0), Vector3(42.0, 0.0, 14.0),
        Vector3(-14.0, 0.0, -42.0), Vector3(14.0, 0.0, -42.0),
        Vector3(-14.0, 0.0, 42.0), Vector3(14.0, 0.0, 42.0),
        Vector3(-42.0, 0.0, -42.0), Vector3(42.0, 0.0, -42.0),
        Vector3(-42.0, 0.0, 42.0), Vector3(42.0, 0.0, 42.0),
    ]
    for index in range(blocks.size()):
        var position: Vector3 = blocks[index]
        var width := 15.0 + float(index % 3) * 1.5
        var depth := 14.0 + float((index + 1) % 3)
        var height := 7.5 + float((index * 7) % 8)
        if position.z < -35.0:
            height += 4.0
        _create_ruined_building(position, Vector3(width, height, depth), index)


func _create_ruined_building(position: Vector3, size: Vector3, index: int) -> void:
    var body := StaticBody3D.new()
    body.name = "RuinedBuilding%02d" % index
    body.position = position
    add_child(body)
    var material := building_materials[index % building_materials.size()]
    ModelKit3D.add_box(body, size, Vector3(0.0, size.y * 0.5, 0.0), material, Vector3.ZERO, "Shell")
    ModelKit3D.add_collision_box(body, size, Vector3(0.0, size.y * 0.5, 0.0))

    var frame_material := ModelKit3D.material(Color("1f2526"), 0.42, 0.58)
    for side in [-1.0, 1.0]:
        ModelKit3D.add_beveled_box(body, Vector3(0.24, size.y * 0.84, 0.28), Vector3(side * size.x * 0.41, size.y * 0.43, -size.z * 0.53), frame_material, Vector3.ZERO, "BuildingCornerFrame", 0.24)
    ModelKit3D.add_beveled_box(body, Vector3(size.x * 0.88, 0.18, 0.32), Vector3(0.0, size.y + 0.12, -size.z * 0.12), frame_material, Vector3(0.0, 0.02, 0.0), "BuildingFacadeCrown", 0.22)

    var roof_damage_side := -1.0 if index % 2 == 0 else 1.0
    ModelKit3D.add_box(body, Vector3(size.x * 0.42, 1.0, size.z * 0.5), Vector3(roof_damage_side * size.x * 0.26, size.y + 0.35, -size.z * 0.15), rubble_material, Vector3(0.12, 0.16, roof_damage_side * 0.18), "CollapsedRoof")
    for floor_index in range(1, int(size.y / 2.6)):
        var window_y := float(floor_index) * 2.25
        for side in [-1.0, 1.0]:
            var window_mat := ModelKit3D.material(Color("111617"), 0.0, 0.88)
            ModelKit3D.add_box(body, Vector3(1.25, 1.1, 0.08), Vector3(side * size.x * 0.23, window_y, -size.z * 0.505), window_mat, Vector3.ZERO, "Window")


func _build_wrecks_and_debris() -> void:
    var car_positions := [
        Vector3(-2.4, 0.0, -16.0), Vector3(2.3, 0.0, 18.5),
        Vector3(-29.5, 0.0, -4.0), Vector3(30.0, 0.0, 5.2),
        Vector3(-1.8, 0.0, -48.0), Vector3(3.0, 0.0, 48.0),
    ]
    for index in range(car_positions.size()):
        var wreck := StaticBody3D.new()
        wreck.name = "VehicleWreck%02d" % index
        wreck.position = car_positions[index]
        wreck.rotation.y = 0.22 * float(index % 3)
        add_child(wreck)
        ModelKit3D.add_beveled_box(wreck, Vector3(2.8, 0.65, 1.45), Vector3(0.0, 0.48, 0.0), metal_material, Vector3(0.08, 0.0, 0.04), "Vehicle", 0.18)
        ModelKit3D.add_surface_panel(wreck, Vector3(1.1, 0.38, 0.08), Vector3(0.0, 0.82, -0.7), rubble_material, metal_material, Vector3(0.08, 0.0, 0.0), "VehicleBrokenGlass")
        for side in [-1.0, 1.0]:
            ModelKit3D.add_cylinder(wreck, 0.18, 0.12, Vector3(side * 0.92, 0.28, -0.7), metal_material, Vector3(PI * 0.5, 0.0, 0.0), "VehicleWheel")
        ModelKit3D.add_collision_box(wreck, Vector3(2.8, 0.65, 1.45), Vector3(0.0, 0.48, 0.0))

    var debris_positions := [
        Vector3(-7.0, 0.0, -9.0), Vector3(8.0, 0.0, 11.0), Vector3(-31.0, 0.0, 20.0),
        Vector3(33.0, 0.0, -22.0), Vector3(-12.0, 0.0, -31.0), Vector3(15.0, 0.0, 31.0),
        Vector3(-50.0, 0.0, 2.0), Vector3(51.0, 0.0, -3.0),
    ]
    for index in range(debris_positions.size()):
        var debris_root := Node3D.new()
        debris_root.position = debris_positions[index]
        add_child(debris_root)
        for piece in range(4):
            ModelKit3D.add_box(
                debris_root,
                Vector3(0.6 + piece * 0.18, 0.25 + piece * 0.08, 0.5),
                Vector3(float(piece) * 0.35 - 0.5, 0.18 + piece * 0.05, float(piece % 2) * 0.5),
                rubble_material,
                Vector3(0.1 * piece, 0.35 * piece, 0.2),
                "Rubble"
            )


func _build_lighting() -> void:
    var lamp_positions := [
        Vector3(-5.5, 0.0, -7.0), Vector3(6.2, 0.0, 7.5),
        Vector3(-1.8, 0.0, -24.0), Vector3(1.8, 0.0, 25.0),
        Vector3(-27.0, 0.0, 1.8), Vector3(27.0, 0.0, -1.8),
    ]
    var pole_mat := ModelKit3D.material(Color("252a2a"), 0.75, 0.48)
    for index in range(lamp_positions.size()):
        var lamp := Node3D.new()
        lamp.position = lamp_positions[index]
        add_child(lamp)
        ModelKit3D.add_cylinder(lamp, 0.08, 4.6, Vector3(0.0, 2.3, 0.0), pole_mat, Vector3.ZERO, "LampPole")
        if index < 2 or index % 3 == 0:
            ModelKit3D.add_glow_light(lamp, Vector3(0.0, 4.35, 0.0), Color("d49257"), 0.65, 9.0)


func _build_north_ruins() -> void:
    var ruins := Node3D.new()
    ruins.name = "NorthRuinsVisual"
    ruins.position = Vector3(0.0, 0.0, -66.0)
    add_child(ruins)
    var stone := ModelKit3D.material(Color("46403b"), 0.0, 0.94)
    var core := ModelKit3D.material(Color("26484e"), 0.35, 0.38, Color("67e0e9"), 3.4)
    for side in [-1.0, 1.0]:
        ModelKit3D.add_box(ruins, Vector3(3.2, 8.2, 2.2), Vector3(side * 4.3, 4.1, 0.0), stone, Vector3(0.0, side * 0.08, side * 0.08), "ArchiveTower")
    ModelKit3D.add_box(ruins, Vector3(6.5, 1.0, 2.5), Vector3(0.0, 0.5, 0.0), stone, Vector3.ZERO, "ArchiveSteps")
    ModelKit3D.add_sphere(ruins, 0.48, Vector3(0.0, 1.4, -0.3), core, Vector3.ONE, "CognitionCore")
    ModelKit3D.add_glow_light(ruins, Vector3(0.0, 1.5, -0.3), Color("67e0e9"), 1.0, 7.0)
