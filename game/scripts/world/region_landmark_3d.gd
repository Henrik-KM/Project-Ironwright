class_name RegionLandmark3D
extends Node3D

const AUTHORED_ROOT_CISTERN_MODEL_SCENE: PackedScene = preload("res://assets/root_cistern/root_cistern.gltf")
const AUTHORED_RIVERWORKS_MODEL_SCENE: PackedScene = preload("res://assets/riverworks/riverworks.gltf")
const AUTHORED_CATHEDRAL_MODEL_SCENE: PackedScene = preload("res://assets/cathedral/cathedral.gltf")
const AUTHORED_OBSERVATORY_MODEL_SCENE: PackedScene = preload("res://assets/observatory/observatory.gltf")
const AUTHORED_TRAM_GRAVEYARD_MODEL_SCENE: PackedScene = preload("res://assets/tram_graveyard/tram_graveyard.gltf")
const AUTHORED_BURIED_LABS_MODEL_SCENE: PackedScene = preload("res://assets/buried_labs/buried_labs.gltf")

signal landmark_changed(landmark: RegionLandmark3D)

var region_id: StringName = &"region.unknown"
var display_name: String = "Unknown district"
var region_kind: StringName = &"urban"
var radius: float = 36.0
var discovered: bool = false
var pressure: float = 0.5
var suppression: float = 0.0
var description: String = ""
var _visual_root: Node3D
var _beacon_root: Node3D
var _label: Label3D
var _light: OmniLight3D
var _practical_lights: Array[OmniLight3D] = []
var _nest_shell: Node3D
var _elapsed: float = 0.0
var _map_emphasis: bool = false
var presentation_detail_level: int = 0
var _motion_nodes: Array[Node3D] = []
var _motion_base_transforms: Dictionary = {}


func configure(data: Dictionary) -> void:
    region_id = StringName(str(data.get("id", "region.unknown")))
    display_name = str(data.get("display_name", "Unknown district"))
    region_kind = StringName(str(data.get("kind", "urban")))
    radius = float(data.get("radius", 36.0))
    discovered = bool(data.get("initially_discovered", false))
    pressure = float(data.get("base_pressure", 0.5))
    description = str(data.get("description", ""))
    var raw_center: Array = data.get("center", [0.0, 0.0, 0.0])
    if raw_center.size() >= 3:
        position = Vector3(float(raw_center[0]), float(raw_center[1]), float(raw_center[2]))


func _ready() -> void:
    add_to_group(&"world_regions")
    _build_visuals()
    _refresh_discovery()


func _process(delta: float) -> void:
    _elapsed += delta
    if _beacon_root == null or not discovered:
        return
    _beacon_root.rotation.y = _elapsed * (0.1 if _map_emphasis else 0.045)
    var pulse := 0.96 + sin(_elapsed * 1.7) * (0.035 if _map_emphasis else 0.018)
    _beacon_root.scale = Vector3.ONE * pulse
    if _label != null:
        _label.position.y = (6.0 if _map_emphasis else 5.65) + sin(_elapsed * 1.35) * 0.06
    if presentation_detail_level < 2:
        _animate_region_details()


func set_map_emphasis(value: bool) -> void:
    _map_emphasis = value
    if _label != null:
        _label.visible = discovered and value
    if _light != null:
        var base_energy := 1.0 if value else 0.28
        var detail_factor := 1.0 if presentation_detail_level == 0 else 0.58
        _light.light_energy = base_energy * detail_factor
        _light.omni_range = 9.0 if value else (4.5 if presentation_detail_level == 0 else 3.0)


func set_presentation_detail_level(level: int) -> void:
    presentation_detail_level = clampi(level, 0, 2)
    if _visual_root != null:
        _visual_root.visible = presentation_detail_level < 2
    for practical_light in _practical_lights:
        if is_instance_valid(practical_light):
            practical_light.light_energy = 0.72 if presentation_detail_level == 0 else 0.38
    if _light != null:
        var base_energy := 1.0 if _map_emphasis else 0.28
        _light.light_energy = base_energy if presentation_detail_level == 0 else base_energy * 0.58
        _light.omni_range = 9.0 if _map_emphasis else (4.5 if presentation_detail_level == 0 else 3.0)


func set_player_proximity(distance: float) -> void:
    if _nest_shell != null:
        _nest_shell.visible = not (region_kind == &"nest" and distance <= 12.0)


func add_presentation_detail(node: Node3D) -> bool:
    if node == null or _visual_root == null:
        return false
    _visual_root.add_child(node)
    return true


func set_discovered(value: bool) -> void:
    if discovered == value:
        return
    discovered = value
    _refresh_discovery()
    landmark_changed.emit(self)


func set_pressure(value: float) -> void:
    pressure = maxf(0.0, value)
    landmark_changed.emit(self)


func add_suppression(amount: float) -> void:
    suppression = clampf(suppression + maxf(0.0, amount), 0.0, 0.85)
    landmark_changed.emit(self)


func effective_pressure() -> float:
    return maxf(0.05, pressure * (1.0 - suppression))


func to_dictionary() -> Dictionary:
    return {
        "region_id": String(region_id),
        "discovered": discovered,
        "pressure": pressure,
        "suppression": suppression,
    }


func restore_from_dictionary(data: Dictionary) -> void:
    discovered = bool(data.get("discovered", discovered))
    pressure = maxf(0.0, float(data.get("pressure", pressure)))
    suppression = clampf(float(data.get("suppression", suppression)), 0.0, 0.85)
    if is_inside_tree():
        _refresh_discovery()
        landmark_changed.emit(self)


func _build_visuals() -> void:
    if region_kind != &"sanctuary":
        var collision_root := StaticBody3D.new()
        collision_root.name = "PersistentRegionCollision"
        collision_root.collision_layer = 1
        add_child(collision_root)
        var ground_shape := ModelKit3D.add_collision_box(
            collision_root,
            Vector3(radius * 2.0, 0.35, radius * 2.0),
            Vector3(0.0, -0.2, 0.0)
        )
        ground_shape.name = "PersistentRegionGround"

    _visual_root = Node3D.new()
    _visual_root.name = "PersistentRegionGeometry"
    add_child(_visual_root)

    var concrete := ModelKit3D.material(Color("3a3c3b"), 0.04, 0.94)
    var brick := ModelKit3D.material(Color("59433b"), 0.02, 0.91)
    var metal := ModelKit3D.material(Color("343d40"), 0.58, 0.56)
    var rust := ModelKit3D.material(Color("774a32"), 0.34, 0.79)
    var organic := ModelKit3D.material(Color("25171d"), 0.0, 0.96)
    var membrane := ModelKit3D.material(Color("3c1827"), 0.0, 0.82, Color("8e233a"), 0.65)
    var edge := ModelKit3D.material(Color("1f292b"), 0.52, 0.46)

    match region_kind:
        &"sanctuary":
            ModelKit3D.add_cylinder(_visual_root, 8.0, 0.16, Vector3(0.0, 0.08, 0.0), concrete, Vector3.ZERO, "TownSquare")
        &"industrial":
            _add_ruin_block(Vector3(-7.0, 0.0, -5.0), Vector3(8.0, 7.0, 5.0), metal)
            _add_ruin_block(Vector3(7.0, 0.0, 6.0), Vector3(10.0, 4.5, 6.0), concrete)
            ModelKit3D.add_cylinder(_visual_root, 1.4, 7.5, Vector3(11.0, 3.75, -7.0), rust, Vector3.ZERO, "SubstationTank")
            ModelKit3D.add_beveled_box(_visual_root, Vector3(3.4, 0.28, 2.5), Vector3(11.0, 0.18, -7.0), edge, Vector3.ZERO, "SubstationTankPlinth", 0.22)
            ModelKit3D.add_surface_panel(_visual_root, Vector3(1.5, 1.0, 0.1), Vector3(11.0, 3.1, -8.38), edge, rust, Vector3.ZERO, "SubstationAccessPanel")
        &"commercial":
            _add_ruin_block(Vector3(-8.0, 0.0, 0.0), Vector3(7.0, 5.0, 12.0), brick)
            _add_ruin_block(Vector3(8.0, 0.0, -2.0), Vector3(7.0, 6.5, 10.0), concrete)
            for index in range(7):
                ModelKit3D.add_beveled_box(_visual_root, Vector3(2.2, 0.18, 1.5), Vector3(-6.0 + float(index) * 2.0, 0.12, 7.0), metal, Vector3.ZERO, "MarketTable", 0.24)
                ModelKit3D.add_box(_visual_root, Vector3(1.7, 0.035, 0.1), Vector3(-6.0 + float(index) * 2.0, 0.24, 6.22), rust, Vector3.ZERO, "MarketTableTrim")
            var market_identity := Node3D.new()
            market_identity.name = "FloodMarketIdentityDetails"
            _visual_root.add_child(market_identity)
            var canopy := ModelKit3D.material(Color("704137"), 0.08, 0.72, Color("dc714a"), 0.45)
            var canopy_trim := ModelKit3D.material(Color("27383b"), 0.58, 0.44, Color("efaa61"), 0.72)
            var sign_material := ModelKit3D.material(Color("1a282c"), 0.4, 0.5, Color("67d6c4"), 1.05)
            for stall_index in range(3):
                var x := -6.0 + float(stall_index) * 6.0
                _add_beam(market_identity, Vector3(x - 1.5, 0.25, 5.4), Vector3(x - 1.5, 2.65, 5.4), 0.07, canopy_trim, "MarketStallPost")
                _add_beam(market_identity, Vector3(x + 1.5, 0.25, 5.4), Vector3(x + 1.5, 2.65, 5.4), 0.07, canopy_trim, "MarketStallPost")
                ModelKit3D.add_beveled_box(market_identity, Vector3(3.4, 0.14, 1.7), Vector3(x, 2.78, 5.4), canopy, Vector3(0.0, 0.0, 0.04 * float(stall_index - 1)), "MarketCanopy", 0.18)
                ModelKit3D.add_surface_panel(market_identity, Vector3(1.05, 0.58, 0.08), Vector3(x, 1.95, 5.08), sign_material, canopy_trim, Vector3.ZERO, "MarketHangingSign")
                _add_beam(market_identity, Vector3(x - 0.44, 2.36, 5.05), Vector3(x - 0.44, 2.0, 5.05), 0.025, canopy_trim, "MarketSignCable")
        &"archive":
            var archive := Node3D.new()
            archive.name = "ArchiveIdentityDetails"
            _visual_root.add_child(archive)
            _add_ruin_block(Vector3(-6.0, 0.0, -1.0), Vector3(8.0, 8.5, 6.0), concrete)
            _add_ruin_block(Vector3(7.0, 0.0, 3.0), Vector3(6.0, 5.5, 5.0), brick)
            ModelKit3D.add_beveled_box(archive, Vector3(3.8, 0.42, 1.2), Vector3(0.0, 0.24, 7.0), metal, Vector3.ZERO, "ArchiveSteps", 0.22)
            ModelKit3D.add_surface_panel(archive, Vector3(2.6, 2.0, 0.1), Vector3(0.0, 1.65, 6.32), metal, membrane, Vector3.ZERO, "ArchiveDoor")
            ModelKit3D.add_cylinder(archive, 0.22, 5.8, Vector3(0.0, 3.2, 7.4), membrane, Vector3.ZERO, "ArchiveSignalMast")
        &"tenement":
            var tenement := Node3D.new()
            tenement.name = "TenementIdentityDetails"
            _visual_root.add_child(tenement)
            _add_ruin_block(Vector3(-8.0, 0.0, 0.0), Vector3(8.0, 9.0, 6.0), brick)
            _add_ruin_block(Vector3(7.0, 0.0, -2.0), Vector3(7.0, 7.0, 5.0), concrete)
            for level in range(3):
                ModelKit3D.add_beveled_box(tenement, Vector3(15.0, 0.14, 0.46), Vector3(0.0, 1.65 + float(level) * 2.2, 4.2), metal, Vector3(0.02, 0.0, 0.0), "TenementWalkway", 0.24)
                _add_beam(tenement, Vector3(-5.5, 0.4 + float(level) * 2.2, 4.2), Vector3(-5.5, 1.65 + float(level) * 2.2, 4.2), 0.07, rust, "TenementWalkwayPost")
                _add_beam(tenement, Vector3(5.5, 0.4 + float(level) * 2.2, 4.2), Vector3(5.5, 1.65 + float(level) * 2.2, 4.2), 0.07, rust, "TenementWalkwayPost")
            for index in range(4):
                ModelKit3D.add_box(tenement, Vector3(1.15, 1.0, 0.05), Vector3(-5.2 + float(index) * 3.4, 2.7 + float(index % 2) * 2.2, 4.0), membrane, Vector3.ZERO, "TenementHangingCloth")
        &"greenhouse":
            var greenhouse := Node3D.new()
            greenhouse.name = "GreenhouseIdentityDetails"
            _visual_root.add_child(greenhouse)
            var glass := ModelKit3D.material(Color("5d7d79"), 0.12, 0.28, Color("76d7c8"), 0.42)
            for side in [-1.0, 1.0]:
                _add_beam(greenhouse, Vector3(side * 5.5, 0.0, -5.0), Vector3(side * 5.5, 6.5, 0.0), 0.12, metal, "GreenhouseFrame")
                _add_beam(greenhouse, Vector3(side * 5.5, 6.5, 0.0), Vector3(side * 3.8, 6.5, 6.0), 0.12, metal, "GreenhouseRoofFrame")
            for side in [-1.0, 1.0]:
                ModelKit3D.add_box(greenhouse, Vector3(0.05, 4.6, 5.8), Vector3(side * 5.38, 2.45, 0.2), glass, Vector3.ZERO, "GreenhouseGlassPanel")
            for index in range(4):
                ModelKit3D.add_beveled_box(greenhouse, Vector3(2.2, 0.26, 0.9), Vector3(-3.3 + float(index) * 2.2, 0.25, 3.2), rust, Vector3.ZERO, "GreenhousePlanter", 0.22)
                ModelKit3D.add_membrane_fan(greenhouse, 0.48, Vector3(-3.3 + float(index) * 2.2, 0.78, 3.2), membrane, 5, "GreenhouseGrowthFan")
        &"waterfront":
            var waterfront := Node3D.new()
            waterfront.name = "WaterfrontIdentityDetails"
            _visual_root.add_child(waterfront)
            var retaining := ModelKit3D.material(Color("2d3c3f"), 0.28, 0.78)
            ModelKit3D.add_beveled_box(waterfront, Vector3(16.0, 2.6, 1.0), Vector3(0.0, 1.3, 6.6), retaining, Vector3(0.0, 0.0, 0.0), "RetainingWall", 0.2)
            var water := ModelKit3D.material(Color("0c303a"), 0.3, 0.24, Color("2a7f8a"), 0.16)
            var waterline := ModelKit3D.material(Color("1b5960"), 0.46, 0.2, Color("69d4c7"), 0.42)
            var sluice_metal := ModelKit3D.material(Color("26383b"), 0.68, 0.42)
            var sluice_rust := ModelKit3D.material(Color("855035"), 0.36, 0.68, Color("dd7748"), 0.3)
            var river_growth := ModelKit3D.material(Color("1a4540"), 0.04, 0.78, Color("5fd0a3"), 0.3)
            ModelKit3D.add_box(waterfront, Vector3(15.0, 0.035, 5.6), Vector3(0.0, 0.06, 10.0), water, Vector3.ZERO, "Floodwater")
            var sluice := Node3D.new()
            sluice.name = "RiverworksSluiceDetails"
            waterfront.add_child(sluice)
            ModelKit3D.add_beveled_box(sluice, Vector3(16.0, 0.12, 0.18), Vector3(0.0, 2.64, 6.58), sluice_metal, Vector3.ZERO, "RetainingWallCap", 0.12)
            ModelKit3D.add_beveled_box(sluice, Vector3(13.2, 0.035, 1.35), Vector3(0.0, 0.13, 7.48), water, Vector3(0.0, 0.0, 0.02), "RiverWaterChannel", 0.12)
            ModelKit3D.add_beveled_box(sluice, Vector3(6.0, 1.95, 0.24), Vector3(0.0, 1.18, 6.02), sluice_metal, Vector3.ZERO, "SluiceGate", 0.16)
            for rib_index in range(3):
                var rib_x := -2.0 + float(rib_index) * 2.0
                _add_beam(sluice, Vector3(rib_x, 0.38, 5.84), Vector3(rib_x, 2.05, 5.84), 0.065, sluice_rust, "SluiceGateRib")
            ModelKit3D.add_surface_panel(sluice, Vector3(1.2, 0.62, 0.1), Vector3(0.0, 1.38, 5.82), sluice_metal, waterline, Vector3.ZERO, "SluiceControlPanel")
            for pylon_index in range(4):
                var pylon_x := -6.0 + float(pylon_index) * 4.0
                ModelKit3D.add_cylinder(sluice, 0.12, 2.8, Vector3(pylon_x, 1.42, 8.25), sluice_metal, Vector3.ZERO, "RiverDockPylon")
                ModelKit3D.add_beveled_box(sluice, Vector3(2.6, 0.055, 0.08), Vector3(pylon_x, 0.22, 8.12), waterline, Vector3(0.0, 0.0, 0.04 * float(pylon_index - 1)), "RiverWaterlineBreak", 0.1)
            for growth_index in range(3):
                var growth_x := -5.0 + float(growth_index) * 5.0
                ModelKit3D.add_membrane_fan(sluice, 0.55, Vector3(growth_x, 0.42, 9.1), river_growth, 5, "RiverbankGrowth")
            _build_authored_riverworks_visuals()
        &"rail":
            _build_authored_tram_graveyard_visuals()
        &"observatory":
            _build_authored_observatory_visuals()
        &"nest":
            _nest_shell = Node3D.new()
            _nest_shell.name = "NestOccluderShell"
            _visual_root.add_child(_nest_shell)
            _add_ruin_block(Vector3(-8.0, 0.0, 3.0), Vector3(5.5, 6.0, 5.5), brick, _nest_shell)
            # The authored Cathedral shell replaces the old ring of generic
            # brood spikes and oversized mass so the civic ruin remains the
            # readable subject while its biological takeover stays legible.
            _build_authored_cathedral_visuals()
        &"research":
            var research := Node3D.new()
            research.name = "BuriedLaboratoriesIdentityDetails"
            _visual_root.add_child(research)
            var lab_glass := ModelKit3D.material(Color("31505a"), 0.12, 0.2, Color("6fc7d7"), 0.34)
            var lab_signal := ModelKit3D.material(Color("262243"), 0.22, 0.38, Color("b08ce9"), 0.9)
            var lab_trim := ModelKit3D.material(Color("7b503c"), 0.32, 0.72, Color("d78355"), 0.22)
            for vessel_index in range(3):
                var vessel_x := -4.5 + float(vessel_index) * 4.5
                ModelKit3D.add_beveled_box(research, Vector3(2.45, 0.22, 1.7), Vector3(vessel_x, 0.3, 4.2), edge, Vector3.ZERO, "LabContainmentPlinth", 0.2)
                ModelKit3D.add_cylinder(research, 0.82, 2.8, Vector3(vessel_x, 1.82, 4.2), lab_glass, Vector3.ZERO, "LabContainmentVessel")
                ModelKit3D.add_cylinder(research, 0.1, 3.45, Vector3(vessel_x, 2.1, 4.2), lab_signal, Vector3.ZERO, "LabContainmentCore")
                ModelKit3D.add_surface_panel(research, Vector3(1.35, 0.56, 0.1), Vector3(vessel_x, 0.88, 3.28), edge, lab_signal, Vector3.ZERO, "LabSpecimenConsole")
                ModelKit3D.add_cylinder(research, 0.12, 1.4, Vector3(vessel_x, 3.55, 4.2), lab_trim, Vector3.ZERO, "LabVesselCap")
            _add_beam(research, Vector3(-6.0, 4.45, 4.2), Vector3(6.0, 4.45, 4.2), 0.085, metal, "LabTransferRail")
            for vessel_index in range(3):
                var vessel_x := -4.5 + float(vessel_index) * 4.5
                _add_beam(research, Vector3(vessel_x, 4.4, 4.2), Vector3(vessel_x, 3.6, 4.2), 0.055, lab_trim, "LabTransferDrop")
            ModelKit3D.add_beveled_box(research, Vector3(11.6, 0.12, 0.18), Vector3(0.0, 4.62, 4.2), lab_signal, Vector3.ZERO, "LabTransferSignal", 0.1)
            ModelKit3D.add_beveled_box(_visual_root, Vector3(6.6, 0.32, 2.0), Vector3(0.0, 0.18, 9.0), edge, Vector3.ZERO, "LabAccess", 0.24)
            ModelKit3D.add_surface_panel(_visual_root, Vector3(2.2, 0.8, 0.1), Vector3(0.0, 0.62, 7.92), edge, membrane, Vector3.ZERO, "LabAccessPanel")
            _build_authored_buried_labs_visuals()
        &"endgame":
            _build_authored_root_cistern_visuals()
        _:
            _add_ruin_block(Vector3(-5.0, 0.0, 0.0), Vector3(7.0, 6.0, 8.0), brick)
            _add_ruin_block(Vector3(6.0, 0.0, -4.0), Vector3(6.0, 4.0, 7.0), concrete)

    _add_region_surface_finish()
    _add_region_practical_lights()
    _capture_region_motion_nodes()

    _beacon_root = Node3D.new()
    _beacon_root.name = "RegionBeacon"
    add_child(_beacon_root)
    var beacon_color := _region_color()
    var glow := ModelKit3D.material(beacon_color.darkened(0.62), 0.2, 0.4, beacon_color, 2.0)
    ModelKit3D.add_cylinder(_beacon_root, 0.045, 3.2, Vector3(0.0, 1.6, 0.0), glow, Vector3.ZERO, "BeaconMast")
    ModelKit3D.add_sphere(_beacon_root, 0.16, Vector3(0.0, 3.3, 0.0), glow, Vector3.ONE, "BeaconCrown")
    _light = ModelKit3D.add_glow_light(_beacon_root, Vector3(0.0, 3.3, 0.0), beacon_color, 0.28, 4.5)

    _label = Label3D.new()
    _label.name = "RegionLabel"
    _label.text = display_name.to_upper()
    _label.position = Vector3(0.0, 5.65, 0.0)
    _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    # District names are a command-map annotation, not a giant tactical HUD.
    _label.fixed_size = false
    _label.font_size = 24
    _label.pixel_size = 0.022
    _label.outline_size = 5
    _label.modulate = beacon_color.lightened(0.18)
    _label.outline_modulate = Color(0.015, 0.022, 0.026, 0.94)
    _label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _label.visible = false
    _beacon_root.add_child(_label)


func _add_region_practical_lights() -> void:
    if region_kind == &"sanctuary":
        return
    var primary_color := _region_color().lightened(0.08)
    var secondary_color := Color("e89a5a")
    match region_kind:
        &"greenhouse":
            secondary_color = Color("72d2b2")
        &"waterfront":
            secondary_color = Color("65cbd7")
        &"nest", &"endgame":
            secondary_color = Color("d85a78")
        &"research", &"observatory":
            secondary_color = Color("a98fe3")

    var light_data := [
        [Vector3(-8.0, 3.8, -5.0), primary_color],
        [Vector3(8.0, 3.2, 5.5), secondary_color],
    ]
    for index in light_data.size():
        var practical_light := OmniLight3D.new()
        practical_light.name = "RegionPracticalLight%d" % index
        practical_light.position = light_data[index][0]
        practical_light.light_color = light_data[index][1]
        practical_light.light_energy = 0.72
        practical_light.omni_range = 24.0
        practical_light.shadow_enabled = false
        _visual_root.add_child(practical_light)
        _practical_lights.append(practical_light)


func _build_authored_root_cistern_visuals() -> void:
    # The late landmark receives a production shell while region state, LOD
    # and endgame ownership remain on this node and its existing services.
    var authored_scene_instance := AUTHORED_ROOT_CISTERN_MODEL_SCENE.instantiate()
    var imported_root := authored_scene_instance.get_node_or_null("RootCisternModel") as Node
    if imported_root == null:
        imported_root = authored_scene_instance
    var authored_children := imported_root.get_children()
    for child in authored_children:
        child.owner = null
        imported_root.remove_child(child)
        _visual_root.add_child(child)
    if imported_root != authored_scene_instance:
        imported_root.free()
    authored_scene_instance.free()
    var authored_marker := Node3D.new()
    authored_marker.name = "RootCisternAuthoredModel"
    _visual_root.add_child(authored_marker)


func _build_authored_riverworks_visuals() -> void:
    # The mid-game waterworks receives a production shell while region state,
    # collision, LOD and operation ownership remain on this landmark node.
    var authored_scene_instance := AUTHORED_RIVERWORKS_MODEL_SCENE.instantiate()
    var imported_root := authored_scene_instance.get_node_or_null("RiverworksModel") as Node
    if imported_root == null:
        imported_root = authored_scene_instance
    var authored_children := imported_root.get_children()
    for child in authored_children:
        child.owner = null
        imported_root.remove_child(child)
        _visual_root.add_child(child)
    if imported_root != authored_scene_instance:
        imported_root.free()
    authored_scene_instance.free()
    var authored_marker := Node3D.new()
    authored_marker.name = "RiverworksAuthoredModel"
    _visual_root.add_child(authored_marker)


func _build_authored_cathedral_visuals() -> void:
    # Cathedral Quarter receives a production shell while the nest director,
    # proximity occlusion and ecology remain owned by this landmark node.
    var authored_scene_instance := AUTHORED_CATHEDRAL_MODEL_SCENE.instantiate()
    var imported_root := authored_scene_instance.get_node_or_null("CathedralModel") as Node
    if imported_root == null:
        imported_root = authored_scene_instance
    var authored_children := imported_root.get_children()
    for child in authored_children:
        child.owner = null
        imported_root.remove_child(child)
        _visual_root.add_child(child)
    if imported_root != authored_scene_instance:
        imported_root.free()
    authored_scene_instance.free()
    var authored_marker := Node3D.new()
    authored_marker.name = "CathedralAuthoredModel"
    _visual_root.add_child(authored_marker)


func _build_authored_observatory_visuals() -> void:
    # Observatory Ridge receives an open survey apparatus instead of a solid
    # dome so the player, dish and route remain readable at tactical distance.
    var identity_details := Node3D.new()
    identity_details.name = "ObservatoryIdentityDetails"
    _visual_root.add_child(identity_details)
    var authored_scene_instance := AUTHORED_OBSERVATORY_MODEL_SCENE.instantiate()
    var imported_root := authored_scene_instance.get_node_or_null("ObservatoryModel") as Node
    if imported_root == null:
        imported_root = authored_scene_instance
    var authored_children := imported_root.get_children()
    for child in authored_children:
        child.owner = null
        imported_root.remove_child(child)
        _visual_root.add_child(child)
    if imported_root != authored_scene_instance:
        imported_root.free()
    authored_scene_instance.free()
    var authored_marker := Node3D.new()
    authored_marker.name = "ObservatoryAuthoredModel"
    _visual_root.add_child(authored_marker)


func _build_authored_tram_graveyard_visuals() -> void:
    # Tram Graveyard keeps its encounter dressing and rail simulation in this
    # landmark while the authored shell supplies the readable maintenance
    # infrastructure and damaged carriage silhouettes.
    var identity_details := Node3D.new()
    identity_details.name = "RailIdentityDetails"
    _visual_root.add_child(identity_details)
    var authored_scene_instance := AUTHORED_TRAM_GRAVEYARD_MODEL_SCENE.instantiate()
    var imported_root := authored_scene_instance.get_node_or_null("TramGraveyardModel") as Node
    if imported_root == null:
        imported_root = authored_scene_instance
    var authored_children := imported_root.get_children()
    for child in authored_children:
        child.owner = null
        imported_root.remove_child(child)
        _visual_root.add_child(child)
    if imported_root != authored_scene_instance:
        imported_root.free()
    authored_scene_instance.free()
    var authored_marker := Node3D.new()
    authored_marker.name = "TramGraveyardAuthoredModel"
    _visual_root.add_child(authored_marker)


func _build_authored_buried_labs_visuals() -> void:
    # The research vignette remains owned by this landmark; the authored shell
    # makes its containment hall and sealed biological work legible at range.
    var authored_scene_instance := AUTHORED_BURIED_LABS_MODEL_SCENE.instantiate()
    var imported_root := authored_scene_instance.get_node_or_null("BuriedLabsModel") as Node
    if imported_root == null:
        imported_root = authored_scene_instance
    var authored_children := imported_root.get_children()
    for child in authored_children:
        child.owner = null
        imported_root.remove_child(child)
        _visual_root.add_child(child)
    if imported_root != authored_scene_instance:
        imported_root.free()
    authored_scene_instance.free()
    var authored_marker := Node3D.new()
    authored_marker.name = "BuriedLabsAuthoredModel"
    _visual_root.add_child(authored_marker)


func _capture_region_motion_nodes() -> void:
    _motion_nodes.clear()
    _motion_base_transforms.clear()
    if _visual_root == null:
        return
    _capture_region_motion_nodes_recursive(_visual_root)


func _capture_region_motion_nodes_recursive(node: Node) -> void:
    for child in node.get_children():
        if child is Node3D:
            var node_3d := child as Node3D
            if _is_region_motion_name(String(node_3d.name)):
                _motion_nodes.append(node_3d)
                _motion_base_transforms[node_3d] = node_3d.transform
            _capture_region_motion_nodes_recursive(node_3d)
        elif child is Node:
            _capture_region_motion_nodes_recursive(child)


func _animate_region_details() -> void:
    for index in _motion_nodes.size():
        var node := _motion_nodes[index]
        if not is_instance_valid(node) or not _motion_base_transforms.has(node):
            continue
        node.transform = _motion_base_transforms[node]
        var local_phase := _elapsed + float(index) * 0.31
        var node_name := String(node.name)
        if node_name.begins_with("RiverworksRotor"):
            node.rotation.y += _elapsed * 0.82
        elif node_name.begins_with("RiverworksMaintenanceValve"):
            node.rotation.z += sin(local_phase * 0.8) * 0.14
        elif node_name.begins_with("RiverworksSluiceSignal") or node_name.begins_with("RootCisternPulse"):
            var signal_pulse := 1.0 + sin(local_phase * 2.4) * 0.12
            node.scale = _motion_base_transforms[node].basis.get_scale() * signal_pulse
        elif node_name.begins_with("CathedralChoirSignal"):
            var choir_pulse := 1.0 + sin(local_phase * 2.0) * 0.10
            node.scale = _motion_base_transforms[node].basis.get_scale() * choir_pulse
        elif node_name.begins_with("CathedralBell"):
            node.rotation.z += sin(local_phase * 0.55) * 0.035
        elif node_name.begins_with("CathedralOrganicVein"):
            node.rotation.x += sin(local_phase * 0.8) * 0.045
        elif node_name.begins_with("ObservatoryDish"):
            node.rotation.y += _elapsed * 0.08
        elif node_name.begins_with("ObservatoryFeedSignal"):
            var feed_pulse := 1.0 + sin(local_phase * 2.2) * 0.10
            node.scale = _motion_base_transforms[node].basis.get_scale() * feed_pulse
        elif node_name.begins_with("ObservatoryMastLight"):
            node.scale = _motion_base_transforms[node].basis.get_scale() * (1.0 + sin(local_phase * 1.7) * 0.08)
        elif node_name.begins_with("TramSignalLamp"):
            node.scale = _motion_base_transforms[node].basis.get_scale() * (1.0 + sin(local_phase * 1.8) * 0.08)
        elif node_name.begins_with("TramOrganicSeep"):
            node.rotation.y += sin(local_phase * 0.9) * 0.06
            node.scale = _motion_base_transforms[node].basis.get_scale() * (1.0 + sin(local_phase * 1.25) * 0.06)
        elif node_name.begins_with("BuriedLabsVesselLight") or node_name.begins_with("BuriedLabsTransferLight"):
            node.scale = _motion_base_transforms[node].basis.get_scale() * (1.0 + sin(local_phase * 2.0) * 0.10)
        elif node_name.begins_with("BuriedLabsOrganicSeep"):
            node.rotation.y += sin(local_phase * 0.8) * 0.06
            node.scale = _motion_base_transforms[node].basis.get_scale() * (1.0 + sin(local_phase * 1.2) * 0.07)
        elif node_name.begins_with("RiverworksGrowth") or node_name.begins_with("RiverbankGrowth"):
            node.rotation.y += sin(local_phase * 1.15) * 0.12
            node.scale *= Vector3(1.0, 1.0 + sin(local_phase * 1.8) * 0.08, 1.0)


func _is_region_motion_name(node_name: String) -> bool:
    for prefix in [
        "RiverworksRotor",
        "RiverworksMaintenanceValve",
        "RiverworksSluiceSignal",
        "RiverworksGrowth",
        "RiverbankGrowth",
        "RootCisternPulse",
        "CathedralChoirSignal",
        "CathedralBell",
        "CathedralOrganicVein",
        "ObservatoryDish",
        "ObservatoryFeedSignal",
        "ObservatoryMastLight",
        "TramSignalLamp",
        "TramOrganicSeep",
        "BuriedLabsVesselLight",
        "BuriedLabsTransferLight",
        "BuriedLabsOrganicSeep",
    ]:
        if node_name.begins_with(prefix):
            return true
    return false


func _add_ruin_block(origin: Vector3, size: Vector3, material: Material, parent: Node3D = null) -> void:
    var target_root: Node3D = parent if parent != null else _visual_root
    ModelKit3D.add_beveled_box(target_root, size, origin + Vector3(0.0, size.y * 0.5, 0.0), material, Vector3.ZERO, "RuinBlock", 0.12)
    var edge := ModelKit3D.material(Color("1f292b"), 0.52, 0.46)
    var pier_height := minf(size.y * 0.86, 7.2)
    for side in [-1.0, 1.0]:
        ModelKit3D.add_beveled_box(
            target_root,
            Vector3(0.22, pier_height, 0.24),
            origin + Vector3(side * size.x * 0.4, pier_height * 0.5, -size.z * 0.52),
            edge,
            Vector3.ZERO,
            "RuinCornerPier",
            0.3
        )
    ModelKit3D.add_beveled_box(
        target_root,
        Vector3(size.x * 0.9, 0.16, size.z * 0.9),
        origin + Vector3(0.0, size.y + 0.08, 0.0),
        edge,
        Vector3(0.0, 0.02, 0.0),
        "RuinRoofCap",
        0.24
    )
    var dark := ModelKit3D.material(Color("171a1b"), 0.0, 0.98)
    for floor_index in range(maxi(1, int(size.y / 2.2))):
        for window_index in range(3):
            var x := origin.x - size.x * 0.3 + float(window_index) * size.x * 0.3
            var y := origin.y + 1.2 + float(floor_index) * 2.0
            ModelKit3D.add_surface_panel(target_root, Vector3(0.7, 0.75, 0.08), Vector3(x, y, origin.z - size.z * 0.51), dark, edge, Vector3.ZERO, "DarkWindow")

    # A small service spine breaks up the broad ruin masses with believable
    # authored hardware. It is presentation-only and remains under the
    # persistent landmark geometry so the region LOD can reduce it at range.
    var service_material := ModelKit3D.material(Color("303b3e"), 0.64, 0.42)
    var service_accent := ModelKit3D.material(Color("b7633a"), 0.34, 0.62, Color("e8894a"), 0.82)
    var panel_width := clampf(size.x * 0.22, 0.95, 1.8)
    var panel_height := clampf(size.y * 0.2, 0.9, 1.35)
    var panel_x := origin.x + size.x * 0.18
    var panel_y := origin.y + minf(size.y * 0.52, 2.9)
    var panel_z := origin.z - size.z * 0.51 - 0.08
    ModelKit3D.add_louvered_panel(
        target_root,
        Vector3(panel_width, panel_height, 0.16),
        Vector3(panel_x, panel_y, panel_z),
        service_material,
        service_accent,
        Vector3.ZERO,
        "RuinFacadeServicePanel",
        4
    )
    ModelKit3D.add_surface_panel(
        target_root,
        Vector3(panel_width * 0.82, panel_height * 0.76, 0.1),
        Vector3(panel_x, panel_y, panel_z - 0.105),
        service_material,
        service_accent,
        Vector3.ZERO,
        "RuinFacadeServicePlate"
    )
    _add_beam(
        target_root,
        Vector3(panel_x + panel_width * 0.34, panel_y + panel_height * 0.46, panel_z - 0.03),
        Vector3(panel_x + size.x * 0.28, origin.y + size.y - 0.24, panel_z - 0.04),
        0.028,
        service_accent,
        "RuinFacadeServiceCable"
    )
    ModelKit3D.add_beveled_box(
        target_root,
        Vector3(size.x * 0.34, 0.12, 0.12),
        Vector3(origin.x - size.x * 0.22, origin.y + minf(size.y * 0.76, size.y - 0.35), panel_z - 0.02),
        edge,
        Vector3(0.0, 0.0, -0.04),
        "RuinFacadeScarRail",
        0.22
    )


func _add_region_surface_finish() -> void:
    if region_kind == &"sanctuary":
        return
    var finish := Node3D.new()
    finish.name = "AuthoredDistrictSurfaceFinish"
    _visual_root.add_child(finish)
    var district_ground := ModelKit3D.material(Color("26363a"), 0.38, 0.78)
    var district_inset := ModelKit3D.material(Color("1b2529"), 0.62, 0.88)
    var finish_metal := ModelKit3D.material(Color("3d4b4f"), 0.58, 0.46)
    var finish_dark := ModelKit3D.material(Color("20282b"), 0.76, 0.38)
    var finish_rust := ModelKit3D.material(Color("864a32"), 0.32, 0.7)
    var finish_glow := ModelKit3D.material(_region_color().darkened(0.5), 0.3, 0.42, _region_color(), 1.25)

    # Remote districts need a readable foreground when the player reaches
    # them physically. This is presentation-only geometry: it creates no
    # collision, resources, routing or additional player-managed structure.
    ModelKit3D.add_beveled_box(
        finish,
        Vector3(38.0, 0.16, 34.0),
        Vector3(0.0, 0.08, 0.0),
        district_ground,
        Vector3.ZERO,
        "RegionalGroundApron",
        0.26
    )
    ModelKit3D.add_beveled_box(
        finish,
        Vector3(30.0, 0.06, 24.0),
        Vector3(0.0, 0.19, 0.0),
        district_inset,
        Vector3.ZERO,
        "RegionalGroundInset",
        0.18
    )
    ModelKit3D.add_beveled_box(finish, Vector3(33.0, 0.12, 0.18), Vector3(0.0, 0.25, -15.9), finish_glow, Vector3.ZERO, "RegionalFrontMarker", 0.08)
    ModelKit3D.add_beveled_box(finish, Vector3(33.0, 0.12, 0.18), Vector3(0.0, 0.25, 15.9), finish_glow, Vector3.ZERO, "RegionalRearMarker", 0.08)
    ModelKit3D.add_beveled_box(finish, Vector3(0.18, 0.12, 30.0), Vector3(-17.9, 0.25, 0.0), finish_glow, Vector3.ZERO, "RegionalLeftMarker", 0.08)
    ModelKit3D.add_beveled_box(finish, Vector3(0.18, 0.12, 30.0), Vector3(17.9, 0.25, 0.0), finish_glow, Vector3.ZERO, "RegionalRightMarker", 0.08)

    match region_kind:
        &"archive":
            ModelKit3D.add_surface_panel(finish, Vector3(2.0, 1.2, 0.12), Vector3(3.1, 2.0, 6.25), finish_dark, finish_glow, Vector3.ZERO, "ArchiveFacadeIndex")
            _add_beam(finish, Vector3(4.0, 2.55, 6.18), Vector3(4.8, 4.9, 6.0), 0.035, finish_rust, "ArchiveFacadeCable")
        &"industrial":
            ModelKit3D.add_louvered_panel(finish, Vector3(2.0, 1.45, 0.18), Vector3(-8.2, 2.65, -7.65), finish_dark, finish_glow, Vector3.ZERO, "IndustrialFacadeExchanger", 5)
            _add_beam(finish, Vector3(-7.35, 2.1, -7.78), Vector3(-4.8, 1.3, -6.0), 0.05, finish_rust, "IndustrialFacadePipe")
        &"tenement":
            for index in range(3):
                var x := 3.7 + float(index) * 1.35
                ModelKit3D.add_surface_panel(finish, Vector3(0.86, 1.08, 0.1), Vector3(x, 2.1 + float(index % 2) * 1.55, -3.0), finish_dark, finish_rust, Vector3.ZERO, "TenementFacadeWindow")
            _add_beam(finish, Vector3(3.5, 1.0, -3.12), Vector3(7.0, 4.9, -3.1), 0.035, finish_metal, "TenementFacadeCable")
        &"greenhouse":
            ModelKit3D.add_louvered_panel(finish, Vector3(1.7, 1.2, 0.16), Vector3(-4.15, 2.05, -5.18), finish_dark, finish_glow, Vector3.ZERO, "GreenhouseFacadeClimatePanel", 4)
            ModelKit3D.add_organic_plate(finish, 0.48, Vector3(3.9, 1.18, -4.9), finish_glow, finish_rust, Vector3(1.0, 0.55, 0.8), "GreenhouseFacadeGrowthScar")
        &"commercial":
            ModelKit3D.add_surface_panel(finish, Vector3(2.4, 1.05, 0.12), Vector3(4.4, 2.0, -6.22), finish_dark, finish_glow, Vector3.ZERO, "MarketFacadeRegister")
            _add_beam(finish, Vector3(3.25, 2.55, -6.28), Vector3(5.7, 3.2, -6.35), 0.04, finish_rust, "MarketFacadeCable")
            var floodwater := ModelKit3D.material(Color("102a31"), 0.42, 0.24, Color("2d7f83"), 0.08)
            var waterline := ModelKit3D.material(Color("214f54"), 0.5, 0.18, Color("63c8b9"), 0.32)
            for channel_index in range(2):
                var channel_x := -8.0 + float(channel_index) * 16.0
                ModelKit3D.add_beveled_box(finish, Vector3(3.1, 0.035, 1.1), Vector3(channel_x, 0.28, 10.4), floodwater, Vector3(0.0, 0.0, -0.08 + 0.16 * float(channel_index)), "MarketFloodChannel", 0.16)
                ModelKit3D.add_beveled_box(finish, Vector3(2.55, 0.022, 0.045), Vector3(channel_x - 0.12, 0.34, 9.96), waterline, Vector3(0.0, 0.0, -0.08 + 0.16 * float(channel_index)), "MarketWaterline", 0.08)
        &"waterfront":
            ModelKit3D.add_louvered_panel(finish, Vector3(1.9, 1.3, 0.16), Vector3(-5.9, 1.75, 5.1), finish_dark, finish_glow, Vector3.ZERO, "DockFacadePumpPanel", 4)
            for index in range(3):
                ModelKit3D.add_cylinder(finish, 0.1, 0.75, Vector3(-2.0 + float(index) * 2.0, 0.48, 5.35), finish_rust, Vector3.ZERO, "DockFacadeBollard")
        &"rail":
            ModelKit3D.add_surface_panel(finish, Vector3(1.4, 1.4, 0.1), Vector3(7.2, 2.6, -5.2), finish_dark, finish_glow, Vector3.ZERO, "RailFacadeSignalBox")
            _add_beam(finish, Vector3(7.2, 3.25, -5.28), Vector3(7.2, 5.5, -7.4), 0.045, finish_metal, "RailFacadeSignalCable")
        &"nest":
            for index in range(4):
                var angle := -0.9 + float(index) * 0.6
                ModelKit3D.add_organic_plate(finish, 0.7, Vector3(cos(angle) * 6.2, 1.2 + float(index % 2) * 0.6, -3.7 + sin(angle) * 1.2), finish_glow, finish_rust, Vector3(1.1, 0.72, 0.86), "NestFacadeGrowthPlate")
        &"observatory":
            ModelKit3D.add_surface_panel(finish, Vector3(1.8, 1.0, 0.1), Vector3(4.0, 1.4, -3.8), finish_dark, finish_glow, Vector3.ZERO, "ObservatoryFacadeConsole")
            _add_beam(finish, Vector3(4.8, 1.9, -3.86), Vector3(5.7, 4.1, -2.3), 0.035, finish_metal, "ObservatoryFacadeCable")
        &"research":
            ModelKit3D.add_louvered_panel(finish, Vector3(2.2, 1.4, 0.18), Vector3(4.3, 1.65, -8.7), finish_dark, finish_glow, Vector3.ZERO, "LabFacadeVent", 5)
            ModelKit3D.add_surface_panel(finish, Vector3(1.5, 0.9, 0.1), Vector3(6.2, 1.35, -8.65), finish_dark, finish_rust, Vector3.ZERO, "LabFacadeSamplePort")
        &"endgame":
            for index in range(3):
                var angle := -0.7 + float(index) * 0.7
                ModelKit3D.add_organic_plate(finish, 0.82, Vector3(cos(angle) * 4.2, 1.5 + float(index) * 0.35, sin(angle) * 4.2), finish_glow, finish_rust, Vector3(1.15, 0.7, 0.9), "CisternFacadeRootPlate")


func _add_beam(parent: Node3D, start: Vector3, finish: Vector3, radius: float, material: Material, node_name: String) -> void:
    var direction := finish - start
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = maxf(0.01, direction.length())
    mesh.radial_segments = 16
    var instance := MeshInstance3D.new()
    instance.name = node_name
    instance.mesh = mesh
    instance.material_override = material
    instance.position = (start + finish) * 0.5
    if direction.length() > 0.001:
        instance.quaternion = Quaternion(Vector3.UP, direction.normalized())
    parent.add_child(instance)


func _refresh_discovery() -> void:
    if _beacon_root != null:
        _beacon_root.visible = discovered
    if _label != null:
        _label.visible = discovered and _map_emphasis


func _region_color() -> Color:
    match region_kind:
        &"sanctuary":
            return Color("efb36a")
        &"industrial":
            return Color("74d5dc")
        &"commercial":
            return Color("72c7a0")
        &"nest":
            return Color("e95b62")
        &"research":
            return Color("a58be0")
        &"endgame":
            return Color("f17b53")
        _:
            return Color("80c7d0")
