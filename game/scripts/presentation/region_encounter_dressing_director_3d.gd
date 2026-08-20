class_name RegionEncounterDressingDirector3D
extends Node

## Builds one authored, presentation-only encounter vignette when a region is
## discovered. It never creates collision, routes, resources or objectives;
## the region landmark remains the sole owner of persistent world identity.

var region_director: WorldRegionDirector3D
var built_regions: Dictionary = {}
var _steel: StandardMaterial3D
var _dark_steel: StandardMaterial3D
var _rust: StandardMaterial3D
var _concrete: StandardMaterial3D
var _organic: StandardMaterial3D
var _membrane: StandardMaterial3D
var _warm: StandardMaterial3D
var _cool: StandardMaterial3D
var _warning: StandardMaterial3D


func configure(next_region_director: WorldRegionDirector3D) -> void:
    region_director = next_region_director


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _create_materials()
    if region_director != null:
        if not region_director.is_connected(&"region_discovered", Callable(self, "_on_region_discovered")):
            region_director.region_discovered.connect(_on_region_discovered)
        call_deferred("_build_all_discovered")


func _build_all_discovered() -> void:
    if region_director == null:
        return
    for raw_id in region_director.landmarks.keys():
        var region_id := StringName(raw_id)
        if region_director.is_discovered(region_id):
            _build_region(region_id)


func _on_region_discovered(region_id: StringName, _display_name: String) -> void:
    call_deferred("_build_region", region_id)


func _build_region(region_id: StringName) -> void:
    if bool(built_regions.get(region_id, false)) or region_director == null:
        return
    var landmark := region_director.get_landmark(region_id)
    if landmark == null:
        return
    var kind := StringName(str(region_director.get_region_data(region_id).get("kind", landmark.region_kind)))
    if kind == &"sanctuary":
        built_regions[region_id] = true
        return
    var dressing := Node3D.new()
    dressing.name = "AuthoredEncounterDressing"
    if not landmark.add_presentation_detail(dressing):
        return
    built_regions[region_id] = true
    match kind:
        &"archive":
            _build_archive_vignette(dressing)
        &"industrial":
            _build_industrial_vignette(dressing)
        &"tenement":
            _build_tenement_vignette(dressing)
        &"greenhouse":
            _build_greenhouse_vignette(dressing)
        &"commercial":
            _build_commercial_vignette(dressing)
        &"waterfront":
            _build_waterfront_vignette(dressing)
        &"rail":
            _build_rail_vignette(dressing)
        &"nest":
            _build_nest_vignette(dressing)
        &"observatory":
            _build_observatory_vignette(dressing)
        &"research":
            _build_research_vignette(dressing)
        &"endgame":
            _build_endgame_vignette(dressing)
        _:
            _build_archive_vignette(dressing)


func _create_materials() -> void:
    _steel = ModelKit3D.material(Color("465257"), 0.68, 0.38)
    _dark_steel = ModelKit3D.material(Color("182126"), 0.82, 0.3)
    _rust = ModelKit3D.material(Color("75442c"), 0.46, 0.68)
    _concrete = ModelKit3D.material(Color("5a5b56"), 0.06, 0.78)
    _organic = ModelKit3D.material(Color("2b1820"), 0.0, 0.86, Color("872a43"), 0.42)
    _membrane = ModelKit3D.material(Color("4a1d31"), 0.04, 0.58, Color("b73f68"), 1.1)
    _warm = ModelKit3D.material(Color("744520"), 0.18, 0.3, Color("f29a4a"), 2.3)
    _cool = ModelKit3D.material(Color("22505a"), 0.28, 0.28, Color("6fe5ea"), 2.5)
    _warning = ModelKit3D.material(Color("a2622d"), 0.14, 0.58, Color("e58c3c"), 0.8)


func _build_archive_vignette(parent: Node3D) -> void:
    ModelKit3D.add_beveled_box(parent, Vector3(5.8, 0.24, 3.0), Vector3(-1.4, 0.25, -6.3), _dark_steel, Vector3.ZERO, "ArchiveReadingPlinth", 0.22)
    for index in range(3):
        var x := -3.2 + float(index) * 1.8
        ModelKit3D.add_beveled_box(parent, Vector3(1.3, 1.35, 0.92), Vector3(x, 1.02, -5.8), _steel, Vector3(0.0, 0.04 * index, 0.0), "ArchiveRecordCrate", 0.16)
        ModelKit3D.add_surface_panel(parent, Vector3(0.65, 0.4, 0.08), Vector3(x, 1.15, -5.32), _dark_steel, _warning, Vector3.ZERO, "ArchiveRecordPlate")
    _add_beam(parent, Vector3(1.5, 0.4, -5.9), Vector3(3.6, 2.8, -5.3), 0.06, _rust, "ArchiveCable")


func _build_industrial_vignette(parent: Node3D) -> void:
    ModelKit3D.add_beveled_box(parent, Vector3(8.4, 0.24, 2.2), Vector3(0.0, 0.22, -3.4), _dark_steel, Vector3.ZERO, "SubstationWorkPad", 0.2)
    for index in range(3):
        var x := -3.2 + float(index) * 3.2
        ModelKit3D.add_tapered_cylinder(parent, 0.54, 0.68, 2.05, Vector3(x, 1.24, -3.25), _steel, Vector3.ZERO, "SubstationPressureTank")
        ModelKit3D.add_cylinder(parent, 0.59, 0.1, Vector3(x, 2.25, -3.25), _rust, Vector3.ZERO, "SubstationTankBand")
        _add_beam(parent, Vector3(x, 2.1, -3.25), Vector3(x + 0.7, 3.1, -1.35), 0.055, _cool, "SubstationPipe")
    ModelKit3D.add_surface_panel(parent, Vector3(2.0, 1.15, 0.08), Vector3(4.2, 1.38, -3.0), _dark_steel, _cool, Vector3.ZERO, "SubstationControlPanel")
    _add_light(parent, Vector3(0.0, 2.8, -2.6), Color("67dbe2"), 1.8, 10.0)


func _build_tenement_vignette(parent: Node3D) -> void:
    for level in range(3):
        var y := 1.0 + float(level) * 1.8
        _add_beam(parent, Vector3(-6.0, y, -6.2), Vector3(6.0, y, -6.2), 0.06, _steel, "TenementLaundryRail")
        for index in range(5):
            var x := -4.8 + float(index) * 2.4
            ModelKit3D.add_box(parent, Vector3(0.9, 0.72, 0.045), Vector3(x, y - 0.42, -6.12), _membrane if index % 2 == 0 else _warning, Vector3(0.03 * index, 0.02 * index, 0.0), "TenementLaundry")
    ModelKit3D.add_beveled_box(parent, Vector3(2.4, 0.18, 1.0), Vector3(-5.8, 0.28, -5.8), _rust, Vector3.ZERO, "TenementBench", 0.2)


func _build_greenhouse_vignette(parent: Node3D) -> void:
    for index in range(4):
        var x := -4.5 + float(index) * 3.0
        ModelKit3D.add_beveled_box(parent, Vector3(2.2, 0.28, 1.15), Vector3(x, 0.25, -4.7), _rust, Vector3.ZERO, "GreenhouseBed", 0.22)
        for growth in range(3):
            ModelKit3D.add_membrane_fan(parent, 0.35, Vector3(x - 0.55 + float(growth) * 0.55, 0.76, -4.7), _membrane, 4, "GreenhouseGrowth")
        _add_beam(parent, Vector3(x, 0.65, -4.1), Vector3(x, 2.0, -2.9), 0.04, _cool, "GreenhouseIrrigation")
    ModelKit3D.add_cylinder(parent, 0.72, 1.45, Vector3(6.1, 0.9, -4.8), _steel, Vector3.ZERO, "GreenhouseWaterTank")


func _build_commercial_vignette(parent: Node3D) -> void:
    ModelKit3D.add_beveled_box(parent, Vector3(11.0, 0.16, 2.4), Vector3(0.0, 3.4, -7.2), _rust, Vector3(0.0, 0.0, -0.05), "MarketAwning", 0.2)
    for index in range(5):
        var x := -5.0 + float(index) * 2.5
        _add_beam(parent, Vector3(x, 0.0, -6.9), Vector3(x, 3.25, -7.2), 0.05, _dark_steel, "MarketAwningPost")
        ModelKit3D.add_beveled_box(parent, Vector3(1.8, 0.62, 1.0), Vector3(x, 0.55, -5.4), _steel, Vector3(0.0, 0.05 * index, 0.0), "MarketCrateStack", 0.16)
    ModelKit3D.add_surface_panel(parent, Vector3(2.7, 0.8, 0.08), Vector3(-4.9, 2.6, -6.85), _dark_steel, _warm, Vector3.ZERO, "MarketSign")
    _add_light(parent, Vector3(0.0, 2.9, 6.5), Color("f2a057"), 1.1, 8.0)


func _build_waterfront_vignette(parent: Node3D) -> void:
    ModelKit3D.add_beveled_box(parent, Vector3(12.0, 0.24, 2.8), Vector3(0.0, 0.24, -7.0), _concrete, Vector3.ZERO, "DockServiceDeck", 0.18)
    for index in range(4):
        var x := -4.8 + float(index) * 3.2
        ModelKit3D.add_cylinder(parent, 0.16, 1.25, Vector3(x, 0.84, -6.45), _rust, Vector3.ZERO, "DockBollard")
        _add_beam(parent, Vector3(x, 1.35, -6.45), Vector3(x + 1.1, 0.7, -9.2), 0.045, _warning, "DockMooringLine")
    ModelKit3D.add_beveled_box(parent, Vector3(3.3, 0.68, 1.4), Vector3(5.0, 0.62, -8.2), _dark_steel, Vector3(0.0, 0.1, 0.0), "DockPumpCase", 0.2)
    ModelKit3D.add_cylinder(parent, 0.12, 2.4, Vector3(5.0, 1.8, -8.2), _cool, Vector3.ZERO, "DockPumpPipe")
    _add_light(parent, Vector3(0.0, 2.2, 7.0), Color("63cbd9"), 1.0, 8.0)


func _build_rail_vignette(parent: Node3D) -> void:
    for side in [-1.0, 1.0]:
        _add_beam(parent, Vector3(side * 1.7, 0.2, -8.5), Vector3(side * 1.7, 0.2, 8.5), 0.08, _steel, "RailServiceLine")
    for z in range(-6, 9, 3):
        ModelKit3D.add_beveled_box(parent, Vector3(4.2, 0.14, 0.32), Vector3(0.0, 0.17, float(z)), _rust, Vector3.ZERO, "RailServiceSleeper", 0.2)
    _add_beam(parent, Vector3(-5.4, 0.0, -6.8), Vector3(-5.4, 4.6, -6.8), 0.09, _dark_steel, "RailSignalPost")
    ModelKit3D.add_surface_panel(parent, Vector3(0.7, 0.62, 0.08), Vector3(-5.4, 3.4, -6.98), _dark_steel, _warm, Vector3.ZERO, "RailSignalFace")
    _add_beam(parent, Vector3(-5.4, 4.25, -6.8), Vector3(2.3, 4.25, -6.8), 0.07, _steel, "RailSignalArm")
    _add_light(parent, Vector3(-5.4, 3.4, -6.4), Color("f0a45a"), 0.9, 7.0)


func _build_nest_vignette(parent: Node3D) -> void:
    for side in [-1.0, 1.0]:
        _add_beam(parent, Vector3(side * 5.8, 0.2, -6.5), Vector3(side * 2.3, 3.9, -5.8), 0.18, _organic, "NestRibArch")
    for index in range(5):
        var angle := -0.9 + float(index) * 0.45
        ModelKit3D.add_sphere(parent, 0.42, Vector3(cos(angle) * 3.6, 0.5, -5.6 + sin(angle) * 1.5), _membrane, Vector3(1.0, 0.82, 1.15), "NestEggSac")
    ModelKit3D.add_membrane_fan(parent, 1.6, Vector3(0.0, 2.4, -5.7), _organic, 7, "NestWarningFan")
    _add_light(parent, Vector3(0.0, 2.2, -5.4), Color("b83a60"), 1.0, 7.5)


func _build_observatory_vignette(parent: Node3D) -> void:
    ModelKit3D.add_beveled_box(parent, Vector3(6.8, 0.3, 4.4), Vector3(0.0, 0.25, -5.2), _concrete, Vector3.ZERO, "SurveyDeck", 0.2)
    for side in [-1.0, 1.0]:
        _add_beam(parent, Vector3(side * 2.6, 0.4, -4.0), Vector3(side * 1.7, 3.6, -5.2), 0.08, _steel, "SurveyTripod")
    ModelKit3D.add_sphere(parent, 1.05, Vector3(0.0, 2.7, -5.0), _steel, Vector3(1.5, 0.42, 1.0), "SurveyDish")
    ModelKit3D.add_cylinder(parent, 0.11, 2.2, Vector3(0.0, 3.2, -5.0), _cool, Vector3.ZERO, "SurveyReceiver")
    ModelKit3D.add_surface_panel(parent, Vector3(1.3, 0.72, 0.08), Vector3(-2.0, 0.95, -4.7), _dark_steel, _cool, Vector3.ZERO, "SurveyConsole")
    _add_light(parent, Vector3(0.0, 2.4, 4.7), Color("8bc9ed"), 0.9, 7.5)


func _build_research_vignette(parent: Node3D) -> void:
    ModelKit3D.add_beveled_box(parent, Vector3(7.8, 0.24, 2.8), Vector3(0.0, 0.24, -7.0), _dark_steel, Vector3.ZERO, "LabExclusionPad", 0.2)
    for index in range(4):
        var x := -3.6 + float(index) * 2.4
        ModelKit3D.add_beveled_box(parent, Vector3(1.2, 1.55, 0.86), Vector3(x, 1.05, -6.6), _steel, Vector3.ZERO, "LabSpecimenCase", 0.16)
        ModelKit3D.add_surface_panel(parent, Vector3(0.58, 0.7, 0.08), Vector3(x, 1.12, -6.14), _dark_steel, _membrane, Vector3.ZERO, "LabSpecimenPanel")
    _add_beam(parent, Vector3(-5.0, 0.5, -7.9), Vector3(5.0, 0.5, -7.9), 0.06, _warning, "LabHazardRail")
    _add_light(parent, Vector3(0.0, 2.3, 6.5), Color("a97de0"), 1.0, 8.0)


func _build_endgame_vignette(parent: Node3D) -> void:
    for index in range(4):
        var angle := TAU * float(index) / 4.0 + 0.25
        var position := Vector3(cos(angle) * 5.3, 2.2, sin(angle) * 5.3)
        ModelKit3D.add_tapered_cylinder(parent, 0.16, 0.28, 4.2, position, _concrete, Vector3.ZERO, "CisternSignalPylon")
        ModelKit3D.add_cylinder(parent, 0.32, 0.08, position + Vector3.UP * 2.0, _cool, Vector3.ZERO, "CisternSignalHalo")
        _add_beam(parent, position + Vector3.UP * 2.0, Vector3(0.0, 1.4, 0.0), 0.035, _membrane, "CisternRootCable")
    ModelKit3D.add_beveled_box(parent, Vector3(5.6, 0.22, 1.3), Vector3(0.0, 0.22, -6.3), _dark_steel, Vector3.ZERO, "CisternControlWalk", 0.18)
    ModelKit3D.add_surface_panel(parent, Vector3(1.7, 0.9, 0.08), Vector3(0.0, 0.98, -5.65), _dark_steel, _membrane, Vector3.ZERO, "CisternProtocolPanel")
    _add_light(parent, Vector3(0.0, 2.8, -5.8), Color("d45d9a"), 1.2, 9.0)


func _add_beam(parent: Node3D, start: Vector3, finish: Vector3, radius: float, material: Material, node_name: String) -> void:
    var direction := finish - start
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = maxf(0.01, direction.length())
    mesh.radial_segments = 20
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = mesh
    instance.material_override = material
    instance.position = (start + finish) * 0.5
    if direction.length() > 0.001:
        instance.quaternion = Quaternion(Vector3.UP, direction.normalized())
    parent.add_child(instance)


func _add_light(parent: Node3D, position: Vector3, color: Color, energy: float, range: float) -> void:
    var light := OmniLight3D.new()
    light.name = "EncounterPractical"
    light.position = position
    light.light_color = color
    light.light_energy = energy
    light.omni_range = range
    light.shadow_enabled = false
    parent.add_child(light)
