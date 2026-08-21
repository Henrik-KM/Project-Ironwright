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
    _build_high_definition_facades()
    _build_wrecks_and_debris()
    _build_lived_in_street_details()
    _build_civic_infrastructure()
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


func _build_high_definition_facades() -> void:
    var facades := Node3D.new()
    facades.name = "HighDefinitionFacadeDetails"
    add_child(facades)

    var window_dark := ModelKit3D.material(Color("0b1518"), 0.18, 0.34, Color("27515a"), 0.22)
    var window_warm := ModelKit3D.material(Color("4a3027"), 0.12, 0.42, Color("d88954"), 0.72)
    var frame := ModelKit3D.material(Color("1c2527"), 0.66, 0.48)
    var concrete := ModelKit3D.material(Color("4b4d4a"), 0.04, 0.84)
    var weathered := ModelKit3D.material(Color("664536"), 0.46, 0.7)
    var service := ModelKit3D.material(Color("263e41"), 0.62, 0.5, Color("51c8ca"), 0.42)

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
        _add_high_definition_facade(
            facades,
            position,
            Vector3(width, height, depth),
            index,
            window_dark,
            window_warm,
            frame,
            concrete,
            weathered,
            service
        )


func _add_high_definition_facade(
        parent: Node3D,
        position: Vector3,
        size: Vector3,
        index: int,
        window_dark: StandardMaterial3D,
        window_warm: StandardMaterial3D,
        frame: StandardMaterial3D,
        concrete: StandardMaterial3D,
        weathered: StandardMaterial3D,
        service: StandardMaterial3D
    ) -> void:
    var facade := Node3D.new()
    facade.name = "FacadeDetail%02d" % index
    facade.position = position
    parent.add_child(facade)

    var front_z := -size.z * 0.515
    var floor_count := maxi(2, int(size.y / 2.6))
    var bay_count := maxi(3, int(size.x / 3.3))
    var bay_width := minf(2.35, (size.x * 0.76) / float(bay_count))
    var bay_span := size.x * 0.76 / float(bay_count)
    for floor_index in range(floor_count):
        var floor_y := 1.48 + float(floor_index) * 2.35
        if floor_y > size.y - 0.7:
            continue
        ModelKit3D.add_beveled_box(
            facade,
            Vector3(size.x * 0.84, 0.08, 0.22),
            Vector3(0.0, floor_y - 0.72, front_z - 0.035),
            frame,
            Vector3.ZERO,
            "FacadeFloorPlate%02d" % floor_index,
            0.18
        )
        for bay_index in range(bay_count):
            var bay_x := -size.x * 0.38 + bay_span * (float(bay_index) + 0.5)
            var lit := (index + floor_index + bay_index) % 7 == 0
            var window_material := window_warm if lit else window_dark
            ModelKit3D.add_beveled_box(
                facade,
                Vector3(bay_width, 1.12, 0.1),
                Vector3(bay_x, floor_y, front_z - 0.055),
                window_material,
                Vector3.ZERO,
                "FacadeWindowBay%02d_%02d" % [floor_index, bay_index],
                0.12
            )
            ModelKit3D.add_box(
                facade,
                Vector3(0.07, 1.0, 0.045),
                Vector3(bay_x - bay_width * 0.5, floor_y, front_z - 0.12),
                frame,
                Vector3.ZERO,
                "FacadeWindowMullion"
            )

    for side in [-1.0, 1.0]:
        ModelKit3D.add_beveled_box(
            facade,
            Vector3(0.16, size.y * 0.82, 0.2),
            Vector3(side * size.x * 0.42, size.y * 0.42, front_z - 0.02),
            frame,
            Vector3.ZERO,
            "FacadeVerticalPier",
            0.18
        )

    ModelKit3D.add_beveled_box(
        facade,
        Vector3(size.x * 0.9, 0.18, 0.5),
        Vector3(0.0, size.y + 0.16, front_z + 0.04),
        concrete,
        Vector3.ZERO,
        "FacadeRoofParapet",
        0.2
    )

    var service_side := -1.0 if index % 2 == 0 else 1.0
    var service_y := 0.9 + float(index % 3) * 0.18
    ModelKit3D.add_louvered_panel(
        facade,
        Vector3(1.45, 0.72, 0.1),
        Vector3(service_side * size.x * 0.28, service_y, front_z - 0.1),
        frame,
        service,
        Vector3.ZERO,
        "FacadeServiceShutter",
        4
    )
    ModelKit3D.add_cylinder(
        facade,
        0.045,
        size.y * 0.72,
        Vector3(service_side * size.x * 0.46, size.y * 0.37, front_z - 0.12),
        weathered,
        Vector3.ZERO,
        "FacadeRainDownpipe"
    )
    ModelKit3D.add_beveled_box(
        facade,
        Vector3(1.8, 0.1, 0.16),
        Vector3(service_side * size.x * 0.22, size.y * 0.66, front_z - 0.11),
        weathered,
        Vector3(0.0, 0.0, 0.08 * service_side),
        "FacadeWeatheredLintel",
        0.16
    )

    var side_detail := Node3D.new()
    side_detail.name = "FacadeSideDetail%02d" % index
    parent.add_child(side_detail)
    var side_x := size.x * 0.515 * (-1.0 if index % 2 == 0 else 1.0)
    var side_front_z := -size.z * 0.38
    var side_bay_count := maxi(2, int(size.z / 3.1))
    var side_bay_span := size.z * 0.72 / float(side_bay_count)
    for floor_index in range(floor_count):
        var side_floor_y := 1.48 + float(floor_index) * 2.35
        if side_floor_y > size.y - 0.7:
            continue
        ModelKit3D.add_beveled_box(
            side_detail,
            Vector3(0.22, 0.08, size.z * 0.76),
            Vector3(side_x, side_floor_y - 0.72, 0.0),
            frame,
            Vector3.ZERO,
            "FacadeSideFloorPlate%02d" % floor_index,
            0.18
        )
        for bay_index in range(side_bay_count):
            var bay_z := side_front_z + side_bay_span * (float(bay_index) + 0.5)
            var lit_side := (index + floor_index + bay_index + 2) % 9 == 0
            ModelKit3D.add_beveled_box(
                side_detail,
                Vector3(0.1, 1.02, minf(2.0, side_bay_span * 0.72)),
                Vector3(side_x, side_floor_y, bay_z),
                window_warm if lit_side else window_dark,
                Vector3.ZERO,
                "FacadeSideWindow%02d_%02d" % [floor_index, bay_index],
                0.12
            )
    ModelKit3D.add_beveled_box(
        side_detail,
        Vector3(0.18, size.y * 0.82, 0.22),
        Vector3(side_x, size.y * 0.42, side_front_z),
        frame,
        Vector3.ZERO,
        "FacadeSidePier",
        0.18
    )
    var roof_utility := Node3D.new()
    roof_utility.name = "FacadeRoofUtility%02d" % index
    roof_utility.position = Vector3(size.x * 0.23, size.y + 0.3, size.z * 0.12)
    facade.add_child(roof_utility)
    ModelKit3D.add_louvered_panel(roof_utility, Vector3(1.15, 0.48, 0.3), Vector3.ZERO, frame, service, Vector3(0.0, -0.12, 0.0), "FacadeRoofUtilityHousing", 3)
    ModelKit3D.add_cylinder(roof_utility, 0.065, 0.68, Vector3(-0.68, 0.25, 0.0), weathered, Vector3.ZERO, "FacadeRoofVent")

    if index % 3 == 0:
        var brace_y := minf(size.y * 0.72, size.y - 1.0)
        _add_facade_brace(
            facade,
            Vector3(-size.x * 0.3, brace_y - 1.1, front_z - 0.16),
            Vector3(size.x * 0.3, brace_y + 0.75, front_z - 0.16),
            weathered,
            "FacadeDamageBraceA"
        )
        _add_facade_brace(
            facade,
            Vector3(size.x * 0.3, brace_y - 1.1, front_z - 0.17),
            Vector3(-size.x * 0.12, brace_y + 0.44, front_z - 0.17),
            concrete,
            "FacadeDamageBraceB"
        )


func _add_facade_brace(parent: Node3D, start: Vector3, end: Vector3, material: StandardMaterial3D, name_hint: String) -> void:
    var direction := end - start
    var brace := ModelKit3D.add_cylinder(parent, 0.055, direction.length(), (start + end) * 0.5, material, Vector3.ZERO, name_hint)
    brace.quaternion = Quaternion(Vector3.UP, direction.normalized())


func _create_ruined_building(position: Vector3, size: Vector3, index: int) -> void:
    var body := StaticBody3D.new()
    body.name = "RuinedBuilding%02d" % index
    body.position = position
    add_child(body)
    var material := building_materials[index % building_materials.size()]
    ModelKit3D.add_beveled_box(body, size, Vector3(0.0, size.y * 0.5, 0.0), material, Vector3.ZERO, "Shell", 0.075)
    ModelKit3D.add_collision_box(body, size, Vector3(0.0, size.y * 0.5, 0.0))

    var frame_material := ModelKit3D.material(Color("1f2526"), 0.42, 0.58)
    var roof_metal := ModelKit3D.material(Color("343b3b"), 0.62, 0.52)
    for side in [-1.0, 1.0]:
        ModelKit3D.add_beveled_box(body, Vector3(0.24, size.y * 0.84, 0.28), Vector3(side * size.x * 0.41, size.y * 0.43, -size.z * 0.53), frame_material, Vector3.ZERO, "BuildingCornerFrame", 0.24)
    ModelKit3D.add_beveled_box(body, Vector3(size.x * 0.88, 0.18, 0.32), Vector3(0.0, size.y + 0.12, -size.z * 0.12), frame_material, Vector3(0.0, 0.02, 0.0), "BuildingFacadeCrown", 0.22)
    ModelKit3D.add_beveled_box(body, Vector3(size.x * 0.92, 0.16, size.z * 0.86), Vector3(0.0, size.y + 0.08, 0.05), roof_metal, Vector3.ZERO, "BuildingRoofSlab", 0.18)

    var roof_damage_side := -1.0 if index % 2 == 0 else 1.0
    ModelKit3D.add_box(body, Vector3(size.x * 0.42, 1.0, size.z * 0.5), Vector3(roof_damage_side * size.x * 0.26, size.y + 0.35, -size.z * 0.15), rubble_material, Vector3(0.12, 0.16, roof_damage_side * 0.18), "CollapsedRoof")
    var roof_detail := Node3D.new()
    roof_detail.name = "BuildingRoofUtilityDetail"
    roof_detail.position = Vector3(-roof_damage_side * size.x * 0.2, size.y + 0.18, size.z * 0.16)
    body.add_child(roof_detail)
    ModelKit3D.add_louvered_panel(roof_detail, Vector3(1.35, 0.52, 0.34), Vector3.ZERO, roof_metal, frame_material, Vector3(0.0, 0.18, 0.0), "RoofUtilityUnit", 3)
    ModelKit3D.add_cylinder(roof_detail, 0.075, 0.72, Vector3(0.76, 0.28, 0.08), frame_material, Vector3.ZERO, "RoofUtilityVent")
    ModelKit3D.add_cylinder(roof_detail, 0.12, 0.08, Vector3(0.76, 0.64, 0.08), roof_metal, Vector3.ZERO, "RoofUtilityCap")
    for floor_index in range(1, int(size.y / 2.6)):
        var window_y := float(floor_index) * 2.25
        for side in [-1.0, 1.0]:
            var window_mat := ModelKit3D.material(Color("111617"), 0.0, 0.88)
            ModelKit3D.add_beveled_box(body, Vector3(1.25, 1.1, 0.08), Vector3(side * size.x * 0.23, window_y, -size.z * 0.505), window_mat, Vector3.ZERO, "Window", 0.12)


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


func _build_lived_in_street_details() -> void:
    var details := Node3D.new()
    details.name = "HighDefinitionStreetDetails"
    add_child(details)

    var civic_metal := ModelKit3D.material(Color("303a3b"), 0.72, 0.48)
    var civic_rust := ModelKit3D.material(Color("70432f"), 0.42, 0.72)
    var civic_concrete := ModelKit3D.material(Color("4a4e4c"), 0.0, 0.84)
    var civic_dark := ModelKit3D.material(Color("171d1f"), 0.62, 0.42)
    var vegetation := ModelKit3D.material(Color("29443a"), 0.0, 0.92)
    var vegetation_light := ModelKit3D.material(Color("55714b"), 0.0, 0.86)
    var civic_amber := ModelKit3D.material(Color("7e512d"), 0.12, 0.36, Color("f1a35b"), 1.2)
    var civic_cyan := ModelKit3D.material(Color("1e4e55"), 0.28, 0.3, Color("6adce1"), 1.6)

    _add_street_bench(details, Vector3(-20.0, 0.0, -8.0), 0.0, civic_metal, civic_rust)
    _add_street_bench(details, Vector3(20.0, 0.0, 8.0), PI, civic_metal, civic_rust)
    _add_street_bench(details, Vector3(-8.0, 0.0, 22.0), PI * 0.5, civic_metal, civic_rust)

    _add_service_cabinet(details, Vector3(-24.0, 0.0, 8.0), 0.0, civic_metal, civic_dark, civic_cyan)
    _add_service_cabinet(details, Vector3(24.0, 0.0, -8.0), PI, civic_rust, civic_dark, civic_amber)
    _add_service_cabinet(details, Vector3(8.0, 0.0, -24.0), PI * 0.5, civic_metal, civic_dark, civic_cyan)

    _add_planter(details, Vector3(-8.0, 0.0, -22.0), civic_concrete, vegetation, vegetation_light)
    _add_planter(details, Vector3(8.0, 0.0, 22.0), civic_concrete, vegetation, vegetation_light)
    _add_planter(details, Vector3(-22.0, 0.0, 20.0), civic_rust, vegetation, vegetation_light)

    _add_civic_sign(details, Vector3(-20.0, 0.0, 18.0), PI * 0.5, civic_metal, civic_dark, civic_amber)
    _add_civic_sign(details, Vector3(20.0, 0.0, -18.0), -PI * 0.5, civic_metal, civic_dark, civic_cyan)

    for index in range(14):
        var x := -34.0 + float(index % 7) * 11.0
        var z := -34.0 + float(index / 7) * 68.0
        _add_weed_cluster(details, Vector3(x, 0.0, z), vegetation, vegetation_light, index)


func _build_civic_infrastructure() -> void:
    var infrastructure := Node3D.new()
    infrastructure.name = "HighDefinitionCivicInfrastructure"
    add_child(infrastructure)

    var steel := ModelKit3D.material(Color("3b4849"), 0.76, 0.4)
    var weathered_steel := ModelKit3D.material(Color("604538"), 0.5, 0.68)
    var dark := ModelKit3D.material(Color("151c1e"), 0.7, 0.42)
    var concrete := ModelKit3D.material(Color("4b5150"), 0.02, 0.82)
    var cyan := ModelKit3D.material(Color("1d535a"), 0.3, 0.32, Color("62d7dd"), 1.45)
    var amber := ModelKit3D.material(Color("76502f"), 0.24, 0.44, Color("ed9a52"), 1.1)

    var junction_positions := [
        Vector3(-4.7, 0.0, -4.7), Vector3(4.7, 0.0, 4.7),
        Vector3(-32.7, 0.0, -4.7), Vector3(32.7, 0.0, 4.7),
    ]
    for index in range(junction_positions.size()):
        _add_civic_drain_junction(infrastructure, junction_positions[index], index, dark, steel, concrete)

    var riser_specs := [
        [Vector3(-5.0, 0.0, -11.8), 0.0, cyan],
        [Vector3(5.0, 0.0, 11.8), PI, amber],
        [Vector3(-33.0, 0.0, 11.2), PI * 0.5, cyan],
        [Vector3(33.0, 0.0, -11.2), -PI * 0.5, amber],
    ]
    for index in range(riser_specs.size()):
        var spec: Array = riser_specs[index]
        _add_civic_utility_riser(infrastructure, spec[0] as Vector3, float(spec[1]), index, steel if index % 2 == 0 else weathered_steel, dark, spec[2] as StandardMaterial3D)

    var mast_specs := [
        [Vector3(-4.8, 0.0, -4.1), 0.0, cyan],
        [Vector3(4.8, 0.0, 4.1), PI, amber],
    ]
    for index in range(mast_specs.size()):
        var mast_spec: Array = mast_specs[index]
        _add_civic_signal_mast(infrastructure, mast_spec[0] as Vector3, float(mast_spec[1]), index, steel, dark, mast_spec[2] as StandardMaterial3D)

    _add_civic_cable_span(infrastructure, Vector3(-4.35, 4.2, -26.0), Vector3(-4.35, 4.2, -9.0), dark, 0)
    _add_civic_cable_span(infrastructure, Vector3(4.35, 4.05, 9.0), Vector3(4.35, 4.05, 26.0), dark, 1)
    _add_civic_cable_span(infrastructure, Vector3(-32.0, 3.85, -4.35), Vector3(-24.0, 3.85, -4.35), dark, 2)
    _add_civic_cable_span(infrastructure, Vector3(24.0, 3.7, 4.35), Vector3(32.0, 3.7, 4.35), dark, 3)


func _add_civic_drain_junction(parent: Node3D, position: Vector3, index: int, dark: StandardMaterial3D, steel: StandardMaterial3D, concrete: StandardMaterial3D) -> void:
    var junction := Node3D.new()
    junction.name = "CivicDrainJunction%02d" % index
    junction.position = position
    parent.add_child(junction)
    ModelKit3D.add_beveled_box(junction, Vector3(1.35, 0.1, 1.05), Vector3(0.0, 0.1, 0.0), concrete, Vector3.ZERO, "CivicDrainFrame", 0.18)
    ModelKit3D.add_box(junction, Vector3(1.05, 0.045, 0.78), Vector3(0.0, 0.17, 0.0), dark, Vector3.ZERO, "CivicDrainRecess")
    for slot in range(5):
        ModelKit3D.add_beveled_box(junction, Vector3(0.07, 0.035, 0.72), Vector3(-0.4 + float(slot) * 0.2, 0.205, 0.0), steel, Vector3.ZERO, "CivicDrainSlot%02d" % slot, 0.12)
    for side in [-1.0, 1.0]:
        ModelKit3D.add_beveled_box(junction, Vector3(0.12, 0.06, 1.02), Vector3(side * 0.62, 0.18, 0.0), steel, Vector3.ZERO, "CivicDrainRail", 0.12)


func _add_civic_utility_riser(parent: Node3D, position: Vector3, heading: float, index: int, body: StandardMaterial3D, dark: StandardMaterial3D, status: StandardMaterial3D) -> void:
    var riser := Node3D.new()
    riser.name = "CivicUtilityRiser%02d" % index
    riser.position = position
    riser.rotation.y = heading
    parent.add_child(riser)
    ModelKit3D.add_beveled_box(riser, Vector3(0.72, 1.62, 0.46), Vector3(0.0, 0.82, 0.0), body, Vector3.ZERO, "CivicRiserBody", 0.14)
    ModelKit3D.add_louvered_panel(riser, Vector3(0.44, 0.34, 0.08), Vector3(0.0, 0.62, -0.28), dark, body, Vector3.ZERO, "CivicRiserVent", 3)
    ModelKit3D.add_surface_panel(riser, Vector3(0.42, 0.42, 0.07), Vector3(0.0, 1.16, -0.28), dark, status, Vector3.ZERO, "CivicRiserServiceFace")
    ModelKit3D.add_cylinder(riser, 0.045, 1.05, Vector3(0.24, 1.58, 0.03), dark, Vector3(0.0, 0.0, 0.08), "CivicRiserConduit")
    ModelKit3D.add_sphere(riser, 0.075, Vector3(0.0, 1.44, -0.33), status, Vector3.ONE, "CivicRiserStatus")
    ModelKit3D.add_beveled_box(riser, Vector3(0.86, 0.12, 0.58), Vector3(0.0, 1.72, 0.0), body, Vector3(0.0, 0.0, 0.04), "CivicRiserCap", 0.16)


func _add_civic_signal_mast(parent: Node3D, position: Vector3, heading: float, index: int, steel: StandardMaterial3D, dark: StandardMaterial3D, signal_material: StandardMaterial3D) -> void:
    var mast := Node3D.new()
    mast.name = "CivicSignalMast%02d" % index
    mast.position = position
    mast.rotation.y = heading
    parent.add_child(mast)
    ModelKit3D.add_cylinder(mast, 0.075, 3.45, Vector3(0.0, 1.72, 0.0), steel, Vector3.ZERO, "CivicSignalPost")
    ModelKit3D.add_beveled_box(mast, Vector3(1.45, 0.12, 0.14), Vector3(0.0, 3.32, 0.0), dark, Vector3.ZERO, "CivicSignalArm", 0.14)
    ModelKit3D.add_beveled_box(mast, Vector3(0.42, 0.72, 0.2), Vector3(0.54, 2.94, 0.0), dark, Vector3.ZERO, "CivicSignalHousing", 0.12)
    ModelKit3D.add_sphere(mast, 0.11, Vector3(0.54, 3.08, -0.12), signal_material, Vector3(1.0, 0.76, 0.72), "CivicSignalLens")
    ModelKit3D.add_beveled_box(mast, Vector3(0.92, 0.12, 0.08), Vector3(-0.14, 2.84, -0.11), signal_material, Vector3.ZERO, "CivicSignalStripe", 0.12)


func _add_civic_cable_span(parent: Node3D, start: Vector3, end: Vector3, material: StandardMaterial3D, index: int) -> void:
    var midpoint := start.lerp(end, 0.5)
    midpoint.y -= 0.5
    _add_civic_cable_segment(parent, start, midpoint, material, "CivicOverheadCable%02dA" % index)
    _add_civic_cable_segment(parent, midpoint, end, material, "CivicOverheadCable%02dB" % index)


func _add_civic_cable_segment(parent: Node3D, start: Vector3, end: Vector3, material: StandardMaterial3D, name_hint: String) -> void:
    var direction := end - start
    var cable := ModelKit3D.add_cylinder(parent, 0.035, direction.length(), (start + end) * 0.5, material, Vector3.ZERO, name_hint)
    cable.quaternion = Quaternion(Vector3.UP, direction.normalized())


func _add_street_bench(parent: Node3D, position: Vector3, heading: float, metal: StandardMaterial3D, wood: StandardMaterial3D) -> void:
    var bench := Node3D.new()
    bench.name = "CivicBench"
    bench.position = position
    bench.rotation.y = heading
    parent.add_child(bench)
    ModelKit3D.add_beveled_box(bench, Vector3(2.0, 0.16, 0.56), Vector3(0.0, 0.78, 0.0), wood, Vector3.ZERO, "CivicBenchSeat", 0.12)
    ModelKit3D.add_beveled_box(bench, Vector3(2.0, 0.72, 0.14), Vector3(0.0, 1.08, 0.22), wood, Vector3(-0.08, 0.0, 0.0), "CivicBenchBack", 0.1)
    for side in [-1.0, 1.0]:
        ModelKit3D.add_cylinder(bench, 0.055, 0.72, Vector3(float(side) * 0.7, 0.39, 0.0), metal, Vector3.ZERO, "CivicBenchLeg")
        ModelKit3D.add_cylinder(bench, 0.05, 0.7, Vector3(float(side) * 0.7, 0.39, 0.16), metal, Vector3.ZERO, "CivicBenchBrace")


func _add_service_cabinet(parent: Node3D, position: Vector3, heading: float, body: StandardMaterial3D, dark: StandardMaterial3D, status: StandardMaterial3D) -> void:
    var cabinet := Node3D.new()
    cabinet.name = "CivicServiceCabinet"
    cabinet.position = position
    cabinet.rotation.y = heading
    parent.add_child(cabinet)
    ModelKit3D.add_beveled_box(cabinet, Vector3(1.15, 1.7, 0.62), Vector3(0.0, 0.86, 0.0), body, Vector3(0.0, 0.0, 0.02), "CivicCabinetShell", 0.14)
    ModelKit3D.add_surface_panel(cabinet, Vector3(0.72, 0.92, 0.08), Vector3(0.0, 0.93, -0.34), dark, status, Vector3.ZERO, "CivicCabinetDoor")
    ModelKit3D.add_louvered_panel(cabinet, Vector3(0.52, 0.32, 0.08), Vector3(0.0, 0.52, -0.39), dark, body, Vector3.ZERO, "CivicCabinetVent", 3)
    ModelKit3D.add_cylinder(cabinet, 0.035, 0.8, Vector3(0.38, 1.74, 0.04), dark, Vector3(0.0, 0.0, 0.12), "CivicCabinetCable")
    ModelKit3D.add_sphere(cabinet, 0.065, Vector3(0.0, 1.48, -0.4), status, Vector3.ONE, "CivicCabinetStatus")


func _add_planter(parent: Node3D, position: Vector3, concrete: StandardMaterial3D, vegetation: StandardMaterial3D, vegetation_light: StandardMaterial3D) -> void:
    var planter := Node3D.new()
    planter.name = "CivicPlanter"
    planter.position = position
    parent.add_child(planter)
    ModelKit3D.add_beveled_box(planter, Vector3(1.8, 0.64, 1.3), Vector3.ZERO + Vector3.UP * 0.32, concrete, Vector3.ZERO, "CivicPlanterBasin", 0.12)
    ModelKit3D.add_beveled_box(planter, Vector3(1.48, 0.14, 1.0), Vector3.UP * 0.68, civic_dark_material(), Vector3.ZERO, "CivicPlanterSoil", 0.05)
    for index in range(5):
        var side := -1.0 if index % 2 == 0 else 1.0
        ModelKit3D.add_capsule(planter, 0.09 + float(index % 2) * 0.03, 0.75 + float(index % 3) * 0.18, Vector3(-0.52 + float(index) * 0.25, 1.0 + float(index % 2) * 0.12, side * 0.16), vegetation if index % 2 == 0 else vegetation_light, Vector3(0.75, 1.0, 0.75), "CivicPlanterGrowth")


func _add_civic_sign(parent: Node3D, position: Vector3, heading: float, pole: StandardMaterial3D, plate: StandardMaterial3D, light: StandardMaterial3D) -> void:
    var sign := Node3D.new()
    sign.name = "CivicRouteSign"
    sign.position = position
    sign.rotation.y = heading
    parent.add_child(sign)
    ModelKit3D.add_cylinder(sign, 0.06, 2.8, Vector3(0.0, 1.4, 0.0), pole, Vector3.ZERO, "CivicSignPost")
    ModelKit3D.add_beveled_box(sign, Vector3(1.2, 0.52, 0.1), Vector3(0.0, 2.48, 0.0), plate, Vector3(0.0, 0.0, 0.03), "CivicSignPlate", 0.08)
    ModelKit3D.add_box(sign, Vector3(0.72, 0.06, 0.035), Vector3(0.0, 2.48, -0.07), light, Vector3.ZERO, "CivicSignStripe")


func _add_weed_cluster(parent: Node3D, position: Vector3, vegetation: StandardMaterial3D, vegetation_light: StandardMaterial3D, index: int) -> void:
    var cluster := Node3D.new()
    cluster.name = "StreetWeedCluster%02d" % index
    cluster.position = position
    cluster.rotation.y = float(index) * 0.41
    parent.add_child(cluster)
    for blade in range(4):
        var material := vegetation if blade % 2 == 0 else vegetation_light
        ModelKit3D.add_tapered_cylinder(cluster, 0.045, 0.015, 0.62 + float(blade % 2) * 0.22, Vector3(-0.18 + float(blade) * 0.12, 0.32, 0.0), material, Vector3(0.0, float(blade) * 0.14 - 0.2, float(blade) * 0.08 - 0.12), "StreetWeedBlade")


func civic_dark_material() -> StandardMaterial3D:
    return ModelKit3D.material(Color("1e2424"), 0.08, 0.92)


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
