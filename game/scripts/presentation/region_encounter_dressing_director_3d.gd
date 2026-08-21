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
var _vegetation: StandardMaterial3D


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
    _build_district_breadth(dressing, kind)


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
    _vegetation = ModelKit3D.material(Color("294239"), 0.0, 0.88, Color("4e9a72"), 0.38)


func _build_district_breadth(parent: Node3D, kind: StringName) -> void:
    # The authored vignette gives each landmark a focal story. This bounded
    # edge kit makes the surrounding district feel inhabited and weathered as
    # well, without adding collision, resources, routes or player-managed work.
    var breadth := Node3D.new()
    breadth.name = "DistrictBreadthLayer"
    parent.add_child(breadth)
    ModelKit3D.add_beveled_box(
        breadth,
        Vector3(11.6, 0.12, 1.55),
        Vector3(-8.4, 0.19, 9.2),
        _dark_steel,
        Vector3(0.0, 0.0, -0.05),
        "DistrictBreadthServicePad",
        0.2
    )
    for index in range(3):
        var x := -12.0 + float(index) * 3.7
        ModelKit3D.add_tapered_cylinder(
            breadth,
            0.09,
            0.14,
            0.78,
            Vector3(x, 0.57, 9.08),
            _rust,
            Vector3.ZERO,
            "DistrictBreadthRoutePost%d" % index
        )
        ModelKit3D.add_surface_panel(
            breadth,
            Vector3(0.52, 0.38, 0.08),
            Vector3(x, 0.86, 9.0),
            _dark_steel,
            _warning,
            Vector3.ZERO,
            "DistrictBreadthRouteMarker%d" % index
        )
    _add_beam(breadth, Vector3(-13.2, 0.46, 9.12), Vector3(-7.2, 1.45, 9.12), 0.045, _steel, "DistrictBreadthServiceRail")
    _add_beam(breadth, Vector3(-7.2, 1.45, 9.12), Vector3(-3.6, 0.46, 9.12), 0.045, _rust, "DistrictBreadthBrokenRail")

    for index in range(3):
        var growth_x := -4.8 + float(index) * 3.1
        ModelKit3D.add_membrane_fan(
            breadth,
            0.34 + float(index % 2) * 0.08,
            Vector3(growth_x, 0.64, 8.05),
            _vegetation,
            4,
            "DistrictBreadthGrowth%d" % index
        )

    var identity := Node3D.new()
    identity.name = "DistrictBreadthIdentity_%s" % String(kind)
    breadth.add_child(identity)
    match kind:
        &"archive":
            ModelKit3D.add_surface_panel(identity, Vector3(1.45, 0.82, 0.1), Vector3(5.4, 1.05, 8.55), _dark_steel, _cool, Vector3.ZERO, "DistrictBreadthRecordsIndex")
            _add_beam(identity, Vector3(5.35, 1.52, 8.48), Vector3(7.5, 2.4, 8.1), 0.035, _rust, "DistrictBreadthRecordsCable")
        &"industrial":
            ModelKit3D.add_louvered_panel(identity, Vector3(1.8, 1.2, 0.16), Vector3(5.2, 1.35, 8.45), _dark_steel, _cool, Vector3.ZERO, "DistrictBreadthPowerLouver", 4)
            _add_beam(identity, Vector3(4.25, 1.18, 8.35), Vector3(6.6, 2.8, 8.35), 0.045, _rust, "DistrictBreadthPowerCable")
        &"tenement":
            ModelKit3D.add_beveled_box(identity, Vector3(2.1, 0.22, 1.2), Vector3(5.3, 0.38, 8.4), _rust, Vector3.ZERO, "DistrictBreadthPlanter", 0.18)
            ModelKit3D.add_membrane_fan(identity, 0.4, Vector3(5.0, 0.82, 8.35), _vegetation, 5, "DistrictBreadthPlanterGrowth")
        &"greenhouse":
            ModelKit3D.add_beveled_box(identity, Vector3(2.6, 0.14, 1.1), Vector3(5.2, 0.38, 8.35), _rust, Vector3.ZERO, "DistrictBreadthGrowBed", 0.18)
            _add_beam(identity, Vector3(4.2, 0.54, 8.35), Vector3(6.4, 2.2, 8.35), 0.035, _cool, "DistrictBreadthIrrigationLine")
        &"commercial":
            ModelKit3D.add_beveled_box(identity, Vector3(2.4, 0.12, 1.6), Vector3(5.1, 2.6, 8.3), _rust, Vector3(0.0, 0.0, -0.08), "DistrictBreadthMarketCanopy", 0.18)
            _add_beam(identity, Vector3(4.05, 0.45, 8.35), Vector3(4.05, 2.55, 8.35), 0.045, _dark_steel, "DistrictBreadthMarketPost")
        &"waterfront":
            for index in range(2):
                ModelKit3D.add_cylinder(identity, 0.12, 0.72, Vector3(4.4 + float(index) * 1.7, 0.58, 8.4), _rust, Vector3.ZERO, "DistrictBreadthMooringCleat%d" % index)
                _add_beam(identity, Vector3(4.4 + float(index) * 1.7, 0.94, 8.4), Vector3(5.8 + float(index) * 1.7, 0.45, 9.2), 0.035, _warning, "DistrictBreadthMooringLine%d" % index)
        &"rail":
            for index in range(3):
                ModelKit3D.add_beveled_box(identity, Vector3(2.0, 0.1, 0.24), Vector3(4.0 + float(index) * 2.0, 0.3, 8.35), _rust, Vector3.ZERO, "DistrictBreadthRailSleeper%d" % index, 0.16)
            _add_beam(identity, Vector3(3.0, 0.35, 8.35), Vector3(8.3, 0.35, 8.35), 0.06, _steel, "DistrictBreadthRailLine")
        &"nest":
            _add_beam(identity, Vector3(4.0, 0.35, 8.6), Vector3(6.8, 3.25, 8.2), 0.12, _organic, "DistrictBreadthNestRib")
            ModelKit3D.add_membrane_fan(identity, 0.72, Vector3(6.3, 1.1, 8.2), _membrane, 6, "DistrictBreadthNestVeil")
        &"observatory":
            ModelKit3D.add_cylinder(identity, 0.12, 2.2, Vector3(5.1, 1.3, 8.35), _steel, Vector3.ZERO, "DistrictBreadthSurveyStake")
            ModelKit3D.add_surface_panel(identity, Vector3(1.1, 0.62, 0.08), Vector3(5.1, 1.45, 8.2), _dark_steel, _cool, Vector3.ZERO, "DistrictBreadthSurveyPanel")
        &"research":
            ModelKit3D.add_louvered_panel(identity, Vector3(1.65, 1.12, 0.16), Vector3(5.2, 1.2, 8.4), _dark_steel, _membrane, Vector3.ZERO, "DistrictBreadthContainmentVent", 4)
            _add_beam(identity, Vector3(4.15, 0.38, 8.42), Vector3(6.5, 2.1, 8.42), 0.04, _warning, "DistrictBreadthHazardCable")
        &"endgame":
            _add_beam(identity, Vector3(4.0, 0.34, 8.35), Vector3(6.1, 2.65, 8.35), 0.08, _organic, "DistrictBreadthRootBrace")
            ModelKit3D.add_organic_plate(identity, 0.64, Vector3(6.4, 0.95, 8.3), _membrane, _rust, Vector3(1.1, 0.7, 0.86), "DistrictBreadthRootPlate")
        _:
            ModelKit3D.add_surface_panel(identity, Vector3(1.4, 0.8, 0.1), Vector3(5.2, 1.0, 8.4), _dark_steel, _warning, Vector3.ZERO, "DistrictBreadthGenericMarker")
    _build_secondary_breadth_kit(breadth, kind)


func _build_secondary_breadth_kit(parent: Node3D, kind: StringName) -> void:
    # A second, compact service edge keeps a landmark from reading as one
    # hero prop floating in an empty district. It is deliberately presentation
    # only: no collision, storage, routes, jobs or player-facing maintenance.
    var kit := Node3D.new()
    kit.name = "DistrictBreadthSecondaryKit"
    parent.add_child(kit)

    var accent := _warning
    var growth_material := _vegetation
    match kind:
        &"industrial", &"waterfront", &"observatory":
            accent = _cool
        &"greenhouse":
            accent = _vegetation
            growth_material = _membrane
        &"nest", &"research", &"endgame":
            accent = _membrane
            growth_material = _organic
        &"archive", &"tenement", &"commercial", &"rail":
            accent = _warm

    ModelKit3D.add_beveled_box(
        kit,
        Vector3(3.2, 0.18, 1.8),
        Vector3(-10.2, 0.24, 11.2),
        _dark_steel,
        Vector3(0.0, 0.0, -0.035),
        "DistrictBreadthSecondaryPlinth",
        0.2
    )
    ModelKit3D.add_beveled_box(
        kit,
        Vector3(2.35, 1.35, 0.92),
        Vector3(-10.2, 0.98, 10.92),
        _steel,
        Vector3(0.0, 0.0, 0.018),
        "DistrictBreadthSecondaryPod",
        0.18
    )
    ModelKit3D.add_louvered_panel(
        kit,
        Vector3(1.18, 0.62, 0.1),
        Vector3(-10.2, 0.92, 10.42),
        _dark_steel,
        accent,
        Vector3.ZERO,
        "DistrictBreadthSecondaryVent",
        4
    )
    ModelKit3D.add_surface_panel(
        kit,
        Vector3(0.76, 0.46, 0.08),
        Vector3(-10.2, 1.64, 10.42),
        _dark_steel,
        accent,
        Vector3.ZERO,
        "DistrictBreadthSecondaryBadge"
    )
    for side in [-1.0, 1.0]:
        _add_beam(
            kit,
            Vector3(-10.2 + side * 1.18, 0.42, 10.72),
            Vector3(-10.2 + side * 1.44, 1.76, 10.72),
            0.042,
            _rust,
            "DistrictBreadthSecondaryBrace"
        )
    _add_beam(
        kit,
        Vector3(-8.95, 1.7, 10.9),
        Vector3(-8.35, 2.45, 10.9),
        0.035,
        accent,
        "DistrictBreadthSecondaryCableAnchor"
    )
    ModelKit3D.add_cylinder(
        kit,
        0.13,
        0.72,
        Vector3(-11.78, 0.62, 11.22),
        _rust,
        Vector3.ZERO,
        "DistrictBreadthSecondarySpindle"
    )
    ModelKit3D.add_organic_plate(
        kit,
        0.34,
        Vector3(-8.72, 0.63, 11.18),
        growth_material,
        accent,
        Vector3(1.0, 0.58, 0.72),
        "DistrictBreadthSecondaryGrowth"
    )

    match kind:
        &"archive":
            ModelKit3D.add_beveled_box(kit, Vector3(1.25, 0.9, 0.5), Vector3(-11.35, 0.78, 11.78), _rust, Vector3.ZERO, "DistrictBreadthArchiveShelf", 0.14)
        &"industrial":
            ModelKit3D.add_cylinder(kit, 0.34, 0.16, Vector3(-10.2, 1.78, 11.2), _cool, Vector3(PI * 0.5, 0.0, 0.0), "DistrictBreadthTransformerCap")
        &"tenement":
            _add_beam(kit, Vector3(-11.5, 1.9, 11.65), Vector3(-8.9, 1.9, 11.65), 0.045, _rust, "DistrictBreadthBalconyFrame")
        &"greenhouse":
            _add_beam(kit, Vector3(-11.2, 1.76, 11.0), Vector3(-9.2, 2.62, 11.0), 0.038, _cool, "DistrictBreadthIrrigationValve")
        &"commercial":
            ModelKit3D.add_beveled_box(kit, Vector3(1.35, 0.7, 0.72), Vector3(-11.25, 0.68, 11.9), _rust, Vector3(0.0, 0.0, 0.04), "DistrictBreadthMarketCrate", 0.16)
        &"waterfront":
            ModelKit3D.add_cylinder(kit, 0.13, 1.1, Vector3(-11.5, 0.78, 11.9), _rust, Vector3.ZERO, "DistrictBreadthMooringPost")
        &"rail":
            _add_beam(kit, Vector3(-11.7, 0.44, 11.9), Vector3(-8.8, 0.44, 11.9), 0.06, _steel, "DistrictBreadthRailSwitch")
        &"nest":
            _add_beam(kit, Vector3(-11.4, 0.45, 11.75), Vector3(-9.2, 2.5, 11.35), 0.095, _organic, "DistrictBreadthBroodVeil")
        &"observatory":
            ModelKit3D.add_cylinder(kit, 0.07, 2.3, Vector3(-11.35, 1.36, 11.55), accent, Vector3.ZERO, "DistrictBreadthSurveyMast")
        &"research":
            ModelKit3D.add_surface_panel(kit, Vector3(1.08, 0.72, 0.08), Vector3(-11.3, 1.08, 11.72), _dark_steel, accent, Vector3.ZERO, "DistrictBreadthContainmentLatch")
        &"endgame":
            _add_beam(kit, Vector3(-11.45, 0.45, 11.75), Vector3(-9.05, 2.7, 11.2), 0.07, _organic, "DistrictBreadthRootAnchor")


func _build_archive_vignette(parent: Node3D) -> void:
    var civic_archive := Node3D.new()
    civic_archive.name = "ArchiveCivicFacade"
    parent.add_child(civic_archive)
    var archive_masonry := ModelKit3D.material(Color("4b4d4a"), 0.35, 0.62)
    var archive_edge := ModelKit3D.material(Color("805137"), 0.42, 0.66)
    var archive_dark := ModelKit3D.material(Color("182326"), 0.4, 0.34)
    var archive_warm := ModelKit3D.material(Color("7a512f"), 0.18, 0.34, Color("e7a05c"), 1.15)
    var archive_cyan := ModelKit3D.material(Color("245058"), 0.3, 0.3, Color("67d9df"), 1.65)

    ModelKit3D.add_beveled_box(civic_archive, Vector3(7.4, 4.8, 0.5), Vector3(4.5, 2.4, 7.05), archive_masonry, Vector3(0.0, 0.0, 0.02), "ArchiveFacadeShell", 0.16)
    ModelKit3D.add_beveled_box(civic_archive, Vector3(7.85, 0.24, 0.76), Vector3(4.5, 4.86, 7.0), archive_edge, Vector3.ZERO, "ArchiveRoofCoping", 0.2)
    for level in range(2):
        var y := 1.05 + float(level) * 1.82
        for bay in range(3):
            var x := 2.25 + float(bay) * 2.25
            var lit := level == 0 and bay == 1
            ModelKit3D.add_surface_panel(civic_archive, Vector3(1.28, 0.96, 0.1), Vector3(x, y, 7.34), archive_masonry, archive_warm if lit else archive_dark, Vector3.ZERO, "ArchiveWindowBay%d%d" % [level, bay])
    ModelKit3D.add_beveled_box(civic_archive, Vector3(1.45, 2.1, 0.12), Vector3(4.5, 1.32, 7.42), archive_dark, Vector3.ZERO, "ArchiveVaultDoor", 0.14)
    ModelKit3D.add_surface_panel(civic_archive, Vector3(0.64, 0.58, 0.08), Vector3(4.5, 1.34, 7.52), archive_dark, archive_cyan, Vector3.ZERO, "ArchiveAccessReader")
    for side in [-1.0, 1.0]:
        _add_beam(civic_archive, Vector3(4.5 + side * 3.05, 0.55, 7.5), Vector3(4.5 + side * 2.35, 4.4, 7.5), 0.065, archive_edge, "ArchiveStructuralPier")
    ModelKit3D.add_louvered_panel(civic_archive, Vector3(1.05, 0.7, 0.08), Vector3(6.9, 2.9, 7.42), archive_dark, archive_cyan, Vector3.ZERO, "ArchiveClimateGrille", 4)
    _add_beam(civic_archive, Vector3(1.25, 4.1, 7.0), Vector3(7.45, 4.1, 7.0), 0.045, archive_cyan, "ArchiveServiceRail")
    ModelKit3D.add_tapered_cylinder(civic_archive, 0.42, 0.58, 1.05, Vector3(7.4, 5.38, 6.9), archive_edge, Vector3.ZERO, "ArchiveRoofBeacon")
    ModelKit3D.add_cylinder(civic_archive, 0.07, 1.4, Vector3(7.4, 6.6, 6.9), archive_cyan, Vector3.ZERO, "ArchiveBeaconMast")
    ModelKit3D.add_membrane_fan(civic_archive, 0.52, Vector3(2.1, 0.72, 7.52), _membrane, 5, "ArchiveRootIntrusion")
    _add_light(civic_archive, Vector3(4.5, 1.45, 7.62), Color("e8a15c"), 0.9, 6.5)
    _add_light(civic_archive, Vector3(6.9, 2.8, 7.65), Color("67d9df"), 0.62, 5.2)

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
    var vertical_life := Node3D.new()
    vertical_life.name = "TenementVerticalLifeDetails"
    parent.add_child(vertical_life)
    var facade := ModelKit3D.material(Color("4a5050"), 0.4, 0.58)
    var facade_edge := ModelKit3D.material(Color("7c523e"), 0.42, 0.68)
    var window_dark := ModelKit3D.material(Color("172326"), 0.35, 0.34)
    var window_warm := ModelKit3D.material(Color("7d4e30"), 0.2, 0.32, Color("e9a35d"), 1.2)
    var service_cyan := ModelKit3D.material(Color("24494e"), 0.32, 0.3, Color("63d4d8"), 1.8)
    var growth := ModelKit3D.material(Color("321a25"), 0.0, 0.8, Color("a43258"), 0.62)

    ModelKit3D.add_beveled_box(vertical_life, Vector3(6.8, 5.5, 0.5), Vector3(4.6, 2.75, -7.05), facade, Vector3(0.0, 0.0, 0.02), "TenementFacadeShell", 0.16)
    ModelKit3D.add_beveled_box(vertical_life, Vector3(7.25, 0.22, 0.78), Vector3(4.6, 5.62, -7.02), facade_edge, Vector3.ZERO, "TenementRoofCoping", 0.22)
    for level in range(3):
        var y := 1.2 + float(level) * 1.65
        for bay in range(3):
            var x := 2.35 + float(bay) * 2.25
            var lit := level == 1 and bay == 1
            ModelKit3D.add_surface_panel(vertical_life, Vector3(1.22, 0.92, 0.1), Vector3(x, y, -7.34), facade, window_warm if lit else window_dark, Vector3.ZERO, "TenementWindowBay%d%d" % [level, bay])
            if bay == 0:
                ModelKit3D.add_louvered_panel(vertical_life, Vector3(0.8, 0.52, 0.08), Vector3(x + 0.12, y - 0.05, -7.4), window_dark, service_cyan, Vector3.ZERO, "TenementServiceLouver%d" % level, 3)

    for level in range(3):
        var y := 0.82 + float(level) * 1.72
        ModelKit3D.add_beveled_box(vertical_life, Vector3(2.55, 0.14, 0.82), Vector3(0.65, y, -7.62), facade_edge, Vector3(0.0, 0.0, 0.03), "TenementFireEscapeLanding%d" % level, 0.2)
        _add_beam(vertical_life, Vector3(-0.52, y, -7.62), Vector3(-0.52, y + 0.78, -7.62), 0.055, service_cyan, "TenementFireEscapeRail")
        _add_beam(vertical_life, Vector3(1.82, y, -7.62), Vector3(1.82, y + 0.78, -7.62), 0.055, service_cyan, "TenementFireEscapeRail")
    _add_beam(vertical_life, Vector3(1.82, 0.84, -7.62), Vector3(1.82, 5.35, -7.62), 0.07, facade_edge, "TenementFireEscapeLadder")
    ModelKit3D.add_tapered_cylinder(vertical_life, 0.62, 0.78, 1.55, Vector3(8.4, 6.35, -6.9), facade_edge, Vector3.ZERO, "TenementRoofWaterTank")
    ModelKit3D.add_cylinder(vertical_life, 0.1, 1.5, Vector3(8.4, 7.85, -6.9), service_cyan, Vector3.ZERO, "TenementRoofTankVent")
    _add_beam(vertical_life, Vector3(7.2, 5.72, -7.0), Vector3(8.4, 6.0, -6.9), 0.045, service_cyan, "TenementServicePipe")
    ModelKit3D.add_membrane_fan(vertical_life, 0.72, Vector3(1.95, 0.68, -7.63), growth, 5, "TenementBreachGrowth")
    _add_light(vertical_life, Vector3(4.6, 3.05, -7.58), Color("e5a15d"), 1.15, 7.0)
    _add_light(vertical_life, Vector3(1.0, 2.15, -7.7), Color("68d7d5"), 0.8, 5.5)

    for level in range(3):
        var y := 1.0 + float(level) * 1.8
        _add_beam(parent, Vector3(-6.0, y, -6.2), Vector3(6.0, y, -6.2), 0.06, _steel, "TenementLaundryRail")
        for index in range(5):
            var x := -4.8 + float(index) * 2.4
            ModelKit3D.add_box(parent, Vector3(0.9, 0.72, 0.045), Vector3(x, y - 0.42, -6.12), _membrane if index % 2 == 0 else _warning, Vector3(0.03 * index, 0.02 * index, 0.0), "TenementLaundry")
    ModelKit3D.add_beveled_box(parent, Vector3(2.4, 0.18, 1.0), Vector3(-5.8, 0.28, -5.8), _rust, Vector3.ZERO, "TenementBench", 0.2)


func _build_greenhouse_vignette(parent: Node3D) -> void:
    var light_canopy := Node3D.new()
    light_canopy.name = "GreenhouseLightCanopy"
    light_canopy.position = Vector3(0.0, 0.0, 8.0)
    parent.add_child(light_canopy)
    var frame := ModelKit3D.material(Color("3e5552"), 0.58, 0.34)
    var frame_edge := ModelKit3D.material(Color("79513a"), 0.42, 0.62)
    var glass_dark := ModelKit3D.material(Color("254b4b"), 0.18, 0.3, Color("4faaa0"), 0.42)
    var glass_warm := ModelKit3D.material(Color("6f6038"), 0.12, 0.3, Color("d9cb70"), 0.8)
    var utility_cyan := ModelKit3D.material(Color("24585b"), 0.34, 0.28, Color("6ce1d6"), 1.7)
    var growth_material := ModelKit3D.material(Color("2a4b38"), 0.0, 0.8, Color("67d0a0"), 0.52)

    ModelKit3D.add_beveled_box(light_canopy, Vector3(7.8, 4.5, 0.42), Vector3(4.6, 2.25, -6.95), frame, Vector3(0.0, 0.0, 0.02), "GreenhouseFacadeShell", 0.16)
    ModelKit3D.add_beveled_box(light_canopy, Vector3(8.2, 0.22, 0.7), Vector3(4.6, 4.62, -6.92), frame_edge, Vector3.ZERO, "GreenhouseRoofCoping", 0.2)
    for bay in range(3):
        var x := 1.9 + float(bay) * 2.7
        var lit := bay == 1
        ModelKit3D.add_surface_panel(light_canopy, Vector3(1.65, 1.45, 0.1), Vector3(x, 2.45, -6.5), frame, glass_warm if lit else glass_dark, Vector3.ZERO, "GreenhouseLightBay%d" % bay)
    for side in [-1.0, 1.0]:
        _add_beam(light_canopy, Vector3(4.6 + side * 3.45, 0.3, -6.5), Vector3(4.6 + side * 3.05, 4.45, -6.5), 0.075, frame_edge, "GreenhouseFacadePier")
    ModelKit3D.add_louvered_panel(light_canopy, Vector3(1.18, 0.72, 0.08), Vector3(7.25, 1.2, -6.45), frame, utility_cyan, Vector3.ZERO, "GreenhouseClimateLouver", 4)
    _add_beam(light_canopy, Vector3(1.3, 4.0, -6.5), Vector3(7.8, 4.0, -6.5), 0.045, utility_cyan, "GreenhouseIrrigationRail")
    for index in range(3):
        var x := 2.25 + float(index) * 2.35
        _add_beam(light_canopy, Vector3(x, 3.95, -6.5), Vector3(x, 1.05, -6.45), 0.035, utility_cyan, "GreenhouseDropLine")
        ModelKit3D.add_membrane_fan(light_canopy, 0.42 + float(index % 2) * 0.12, Vector3(x, 0.72, -6.4), growth_material, 5, "GreenhouseFacadeGrowth")
    ModelKit3D.add_tapered_cylinder(light_canopy, 0.48, 0.65, 1.25, Vector3(8.1, 5.35, -6.8), frame_edge, Vector3.ZERO, "GreenhouseRoofTank")
    ModelKit3D.add_cylinder(light_canopy, 0.07, 1.3, Vector3(8.1, 6.62, -6.8), utility_cyan, Vector3.ZERO, "GreenhouseRoofVent")
    ModelKit3D.add_beveled_box(light_canopy, Vector3(2.4, 0.1, 1.2), Vector3(2.2, 4.86, -6.3), glass_dark, Vector3(0.0, 0.0, 0.2), "GreenhouseBrokenSkylight", 0.14)
    _add_light(light_canopy, Vector3(4.6, 2.55, -6.3), Color("d8ce79"), 0.85, 6.8)
    _add_light(light_canopy, Vector3(7.25, 1.4, -6.3), Color("6ce1d6"), 0.55, 4.8)

    for index in range(4):
        var x := -4.5 + float(index) * 3.0
        ModelKit3D.add_beveled_box(parent, Vector3(2.2, 0.28, 1.15), Vector3(x, 0.25, -4.7), _rust, Vector3.ZERO, "GreenhouseBed", 0.22)
        for growth in range(3):
            ModelKit3D.add_membrane_fan(parent, 0.35, Vector3(x - 0.55 + float(growth) * 0.55, 0.76, -4.7), _membrane, 4, "GreenhouseGrowth")
        _add_beam(parent, Vector3(x, 0.65, -4.1), Vector3(x, 2.0, -2.9), 0.04, _cool, "GreenhouseIrrigation")
    ModelKit3D.add_cylinder(parent, 0.72, 1.45, Vector3(6.1, 0.9, -4.8), _steel, Vector3.ZERO, "GreenhouseWaterTank")
    _add_light(parent, Vector3(0.0, 2.0, -4.7), Color("73d8be"), 0.9, 7.5)


func _build_commercial_vignette(parent: Node3D) -> void:
    ModelKit3D.add_beveled_box(parent, Vector3(11.0, 0.16, 2.4), Vector3(0.0, 3.4, -7.2), _rust, Vector3(0.0, 0.0, -0.05), "MarketAwning", 0.2)
    for index in range(5):
        var x := -5.0 + float(index) * 2.5
        _add_beam(parent, Vector3(x, 0.0, -6.9), Vector3(x, 3.25, -7.2), 0.05, _dark_steel, "MarketAwningPost")
        ModelKit3D.add_beveled_box(parent, Vector3(1.8, 0.62, 1.0), Vector3(x, 0.55, -5.4), _steel, Vector3(0.0, 0.05 * index, 0.0), "MarketCrateStack", 0.16)
    ModelKit3D.add_surface_panel(parent, Vector3(2.7, 0.8, 0.08), Vector3(-4.9, 2.6, -6.85), _dark_steel, _warm, Vector3.ZERO, "MarketSign")
    _add_light(parent, Vector3(0.0, 2.9, -6.5), Color("f2a057"), 1.1, 8.0)


func _build_waterfront_vignette(parent: Node3D) -> void:
    ModelKit3D.add_beveled_box(parent, Vector3(12.0, 0.24, 2.8), Vector3(0.0, 0.24, -7.0), _concrete, Vector3.ZERO, "DockServiceDeck", 0.18)
    for index in range(4):
        var x := -4.8 + float(index) * 3.2
        ModelKit3D.add_cylinder(parent, 0.16, 1.25, Vector3(x, 0.84, -6.45), _rust, Vector3.ZERO, "DockBollard")
        _add_beam(parent, Vector3(x, 1.35, -6.45), Vector3(x + 1.1, 0.7, -9.2), 0.045, _warning, "DockMooringLine")
    ModelKit3D.add_beveled_box(parent, Vector3(3.3, 0.68, 1.4), Vector3(5.0, 0.62, -8.2), _dark_steel, Vector3(0.0, 0.1, 0.0), "DockPumpCase", 0.2)
    ModelKit3D.add_cylinder(parent, 0.12, 2.4, Vector3(5.0, 1.8, -8.2), _cool, Vector3.ZERO, "DockPumpPipe")
    _add_light(parent, Vector3(0.0, 2.2, -7.0), Color("63cbd9"), 1.0, 8.0)


func _build_rail_vignette(parent: Node3D) -> void:
    var maintenance_bay := Node3D.new()
    maintenance_bay.name = "TramMaintenanceBay"
    parent.add_child(maintenance_bay)
    var carriage_metal := ModelKit3D.material(Color("3e4949"), 0.62, 0.4)
    var carriage_edge := ModelKit3D.material(Color("7b4b32"), 0.4, 0.68)
    var carriage_dark := ModelKit3D.material(Color("172426"), 0.44, 0.34)
    var carriage_glass := ModelKit3D.material(Color("28545a"), 0.22, 0.28, Color("5ed1d3"), 1.15)
    var maintenance_cyan := ModelKit3D.material(Color("24565c"), 0.32, 0.3, Color("6cdde0"), 1.55)
    var infestation := ModelKit3D.material(Color("321a26"), 0.0, 0.8, Color("a43862"), 0.58)

    ModelKit3D.add_beveled_box(maintenance_bay, Vector3(6.6, 2.55, 2.55), Vector3(4.6, 1.48, -5.1), carriage_metal, Vector3(0.0, 0.0, 0.025), "TramCarriageShell", 0.18)
    ModelKit3D.add_beveled_box(maintenance_bay, Vector3(6.95, 0.18, 2.82), Vector3(4.6, 2.84, -5.1), carriage_edge, Vector3(0.0, 0.0, 0.02), "TramCarriageRoof", 0.2)
    for bay in range(3):
        var x := 2.2 + float(bay) * 2.4
        ModelKit3D.add_surface_panel(maintenance_bay, Vector3(1.45, 0.88, 0.1), Vector3(x, 1.75, -6.43), carriage_metal, carriage_glass, Vector3.ZERO, "TramCarriageWindow%d" % bay)
    ModelKit3D.add_beveled_box(maintenance_bay, Vector3(1.1, 1.85, 0.12), Vector3(4.6, 1.12, -6.47), carriage_dark, Vector3.ZERO, "TramCarriageDoor", 0.14)
    ModelKit3D.add_surface_panel(maintenance_bay, Vector3(0.48, 0.5, 0.08), Vector3(4.6, 1.3, -6.58), carriage_dark, maintenance_cyan, Vector3.ZERO, "TramCarriageDoorReader")
    _add_beam(maintenance_bay, Vector3(1.15, 0.42, -6.4), Vector3(8.05, 0.42, -6.4), 0.045, carriage_edge, "TramCarriageLowerRail")
    ModelKit3D.add_membrane_fan(maintenance_bay, 0.7, Vector3(7.25, 0.82, -6.52), infestation, 6, "TramCarriageInfestation")
    ModelKit3D.add_beveled_box(maintenance_bay, Vector3(5.0, 0.22, 1.75), Vector3(-4.1, 0.22, 5.3), carriage_dark, Vector3.ZERO, "TramInspectionPit", 0.16)
    for side in [-1.0, 1.0]:
        _add_beam(maintenance_bay, Vector3(-6.0, 0.45, 4.55 + side * 0.72), Vector3(-2.2, 0.45, 4.55 + side * 0.72), 0.045, maintenance_cyan, "TramPitServiceRail")
    _add_beam(maintenance_bay, Vector3(1.2, 4.75, -4.6), Vector3(8.0, 4.75, -4.6), 0.07, carriage_metal, "TramMaintenanceGantry")
    _add_beam(maintenance_bay, Vector3(4.6, 4.7, -4.6), Vector3(4.6, 2.78, -5.1), 0.04, maintenance_cyan, "TramHoistCable")
    _add_light(maintenance_bay, Vector3(4.6, 2.0, -6.65), Color("62d9dd"), 0.72, 5.5)
    _add_light(maintenance_bay, Vector3(-4.1, 0.75, 5.0), Color("df985c"), 0.5, 4.5)

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
    var optics_station := Node3D.new()
    optics_station.name = "ObservatoryOpticsStation"
    parent.add_child(optics_station)
    var station_metal := ModelKit3D.material(Color("3c4b52"), 0.64, 0.34)
    var station_edge := ModelKit3D.material(Color("7a5037"), 0.4, 0.62)
    var station_dark := ModelKit3D.material(Color("17262b"), 0.46, 0.32)
    var survey_glass := ModelKit3D.material(Color("284e61"), 0.22, 0.24, Color("6ebde0"), 1.2)
    var survey_signal := ModelKit3D.material(Color("254f61"), 0.34, 0.28, Color("7bd9ed"), 1.7)
    var survey_warm := ModelKit3D.material(Color("6d4c31"), 0.16, 0.42, Color("e9a15a"), 0.78)

    ModelKit3D.add_beveled_box(optics_station, Vector3(6.2, 2.35, 2.35), Vector3(4.4, 1.35, -6.65), station_metal, Vector3(0.0, 0.0, 0.02), "ObservatoryControlCabin", 0.18)
    ModelKit3D.add_beveled_box(optics_station, Vector3(6.55, 0.18, 2.62), Vector3(4.4, 2.58, -6.65), station_edge, Vector3.ZERO, "ObservatoryCabinRoof", 0.2)
    for bay in range(3):
        var x := 2.1 + float(bay) * 2.3
        ModelKit3D.add_surface_panel(optics_station, Vector3(1.28, 0.84, 0.1), Vector3(x, 1.65, -7.9), station_metal, survey_glass if bay != 1 else survey_warm, Vector3.ZERO, "ObservatoryWindowBay%d" % bay)
    ModelKit3D.add_beveled_box(optics_station, Vector3(1.08, 1.72, 0.12), Vector3(4.4, 1.1, -7.95), station_dark, Vector3.ZERO, "ObservatoryAccessDoor", 0.14)
    ModelKit3D.add_surface_panel(optics_station, Vector3(0.5, 0.48, 0.08), Vector3(4.4, 1.24, -8.06), station_dark, survey_signal, Vector3.ZERO, "ObservatoryAccessReader")
    ModelKit3D.add_cylinder(optics_station, 0.58, 1.65, Vector3(7.9, 3.15, -6.7), station_dark, Vector3(0.0, 0.0, PI * 0.5), "ObservatoryLensBarrel")
    ModelKit3D.add_cylinder(optics_station, 0.46, 0.12, Vector3(8.76, 3.15, -6.7), survey_glass, Vector3(0.0, 0.0, PI * 0.5), "ObservatoryLensGlass")
    _add_beam(optics_station, Vector3(7.1, 2.2, -6.7), Vector3(8.0, 1.7, -6.7), 0.055, station_edge, "ObservatoryLensBrace")
    _add_beam(optics_station, Vector3(0.9, 2.18, -6.6), Vector3(7.9, 2.18, -6.6), 0.045, survey_signal, "ObservatoryServiceRail")
    ModelKit3D.add_surface_panel(optics_station, Vector3(1.3, 0.72, 0.08), Vector3(1.45, 0.92, -7.75), station_dark, survey_signal, Vector3.ZERO, "ObservatoryStarMapPanel")
    ModelKit3D.add_cylinder(optics_station, 0.1, 1.7, Vector3(8.0, 4.1, -6.7), survey_signal, Vector3.ZERO, "ObservatoryRelayMast")
    _add_beam(optics_station, Vector3(8.0, 4.7, -6.7), Vector3(6.0, 5.35, -6.7), 0.035, survey_signal, "ObservatoryRelayCable")
    _add_light(optics_station, Vector3(4.4, 1.5, -8.12), Color("6ebde0"), 0.72, 5.8)
    _add_light(optics_station, Vector3(1.45, 1.05, -7.9), Color("e9a15a"), 0.4, 4.2)

    ModelKit3D.add_beveled_box(parent, Vector3(6.8, 0.3, 4.4), Vector3(0.0, 0.25, -5.2), _concrete, Vector3.ZERO, "SurveyDeck", 0.2)
    for side in [-1.0, 1.0]:
        _add_beam(parent, Vector3(side * 2.6, 0.4, -4.0), Vector3(side * 1.7, 3.6, -5.2), 0.08, _steel, "SurveyTripod")
    ModelKit3D.add_sphere(parent, 1.05, Vector3(0.0, 2.7, -5.0), _steel, Vector3(1.5, 0.42, 1.0), "SurveyDish")
    ModelKit3D.add_cylinder(parent, 0.11, 2.2, Vector3(0.0, 3.2, -5.0), _cool, Vector3.ZERO, "SurveyReceiver")
    ModelKit3D.add_surface_panel(parent, Vector3(1.3, 0.72, 0.08), Vector3(-2.0, 0.95, -4.7), _dark_steel, _cool, Vector3.ZERO, "SurveyConsole")
    _add_light(parent, Vector3(0.0, 2.4, -4.7), Color("8bc9ed"), 0.9, 7.5)


func _build_research_vignette(parent: Node3D) -> void:
    ModelKit3D.add_beveled_box(parent, Vector3(7.8, 0.24, 2.8), Vector3(0.0, 0.24, -7.0), _dark_steel, Vector3.ZERO, "LabExclusionPad", 0.2)
    for index in range(4):
        var x := -3.6 + float(index) * 2.4
        ModelKit3D.add_beveled_box(parent, Vector3(1.2, 1.55, 0.86), Vector3(x, 1.05, -6.6), _steel, Vector3.ZERO, "LabSpecimenCase", 0.16)
        ModelKit3D.add_surface_panel(parent, Vector3(0.58, 0.7, 0.08), Vector3(x, 1.12, -6.14), _dark_steel, _membrane, Vector3.ZERO, "LabSpecimenPanel")
    _add_beam(parent, Vector3(-5.0, 0.5, -7.9), Vector3(5.0, 0.5, -7.9), 0.06, _warning, "LabHazardRail")
    _add_light(parent, Vector3(0.0, 2.3, -6.5), Color("a97de0"), 1.0, 8.0)


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
