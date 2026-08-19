class_name RegionLandmark3D
extends Node3D

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
var _elapsed: float = 0.0


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
    _beacon_root.rotation.y = _elapsed * 0.18
    var pulse := 0.88 + sin(_elapsed * 1.7) * 0.08
    _beacon_root.scale = Vector3.ONE * pulse
    if _label != null:
        _label.position.y = 6.2 + sin(_elapsed * 1.35) * 0.12


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
    _visual_root = Node3D.new()
    _visual_root.name = "PersistentRegionGeometry"
    add_child(_visual_root)

    var concrete := ModelKit3D.material(Color("3a3c3b"), 0.04, 0.94)
    var brick := ModelKit3D.material(Color("59433b"), 0.02, 0.91)
    var metal := ModelKit3D.material(Color("343d40"), 0.58, 0.56)
    var rust := ModelKit3D.material(Color("774a32"), 0.34, 0.79)
    var organic := ModelKit3D.material(Color("25171d"), 0.0, 0.96)
    var membrane := ModelKit3D.material(Color("3c1827"), 0.0, 0.82, Color("8e233a"), 0.65)

    match region_kind:
        &"sanctuary":
            ModelKit3D.add_cylinder(_visual_root, 8.0, 0.16, Vector3(0.0, 0.08, 0.0), concrete, Vector3.ZERO, "TownSquare")
        &"industrial":
            _add_ruin_block(Vector3(-7.0, 0.0, -5.0), Vector3(8.0, 7.0, 5.0), metal)
            _add_ruin_block(Vector3(7.0, 0.0, 6.0), Vector3(10.0, 4.5, 6.0), concrete)
            ModelKit3D.add_cylinder(_visual_root, 1.4, 7.5, Vector3(11.0, 3.75, -7.0), rust, Vector3.ZERO, "SubstationTank")
        &"commercial":
            _add_ruin_block(Vector3(-8.0, 0.0, 0.0), Vector3(7.0, 5.0, 12.0), brick)
            _add_ruin_block(Vector3(8.0, 0.0, -2.0), Vector3(7.0, 6.5, 10.0), concrete)
            for index in range(7):
                ModelKit3D.add_box(_visual_root, Vector3(2.2, 0.18, 1.5), Vector3(-6.0 + float(index) * 2.0, 0.12, 7.0), metal, Vector3.ZERO, "MarketTable")
        &"nest":
            _add_ruin_block(Vector3(0.0, 0.0, 4.0), Vector3(12.0, 12.0, 8.0), brick)
            for index in range(9):
                var angle := TAU * float(index) / 9.0
                ModelKit3D.add_capsule(_visual_root, 0.55, 5.2 + float(index % 3), Vector3(cos(angle) * 8.0, 2.4, sin(angle) * 8.0), organic, Vector3(0.2, angle, 0.25), "BroodSpire")
            ModelKit3D.add_sphere(_visual_root, 3.6, Vector3(0.0, 2.2, -2.0), membrane, Vector3(1.4, 0.9, 1.6), "BroodMass")
        &"research":
            _add_ruin_block(Vector3(-6.5, -1.0, 0.0), Vector3(10.0, 3.0, 11.0), concrete)
            _add_ruin_block(Vector3(7.0, -1.6, -5.0), Vector3(8.0, 2.2, 7.0), metal)
            ModelKit3D.add_cylinder(_visual_root, 3.2, 0.45, Vector3(0.0, 0.15, 9.0), metal, Vector3.ZERO, "LabAccess")
        &"endgame":
            for index in range(6):
                var angle := TAU * float(index) / 6.0
                ModelKit3D.add_cylinder(_visual_root, 1.15, 8.0, Vector3(cos(angle) * 8.5, 4.0, sin(angle) * 8.5), concrete, Vector3.ZERO, "CisternPillar")
            ModelKit3D.add_sphere(_visual_root, 4.4, Vector3(0.0, 1.4, 0.0), membrane, Vector3(1.35, 0.48, 1.35), "RootOrgan")
        _:
            _add_ruin_block(Vector3(-5.0, 0.0, 0.0), Vector3(7.0, 6.0, 8.0), brick)
            _add_ruin_block(Vector3(6.0, 0.0, -4.0), Vector3(6.0, 4.0, 7.0), concrete)

    _beacon_root = Node3D.new()
    _beacon_root.name = "RegionBeacon"
    add_child(_beacon_root)
    var beacon_color := _region_color()
    var glow := ModelKit3D.material(beacon_color.darkened(0.62), 0.2, 0.4, beacon_color, 3.2)
    ModelKit3D.add_cylinder(_beacon_root, 0.08, 4.8, Vector3(0.0, 2.4, 0.0), glow, Vector3.ZERO, "BeaconMast")
    ModelKit3D.add_sphere(_beacon_root, 0.28, Vector3(0.0, 4.9, 0.0), glow, Vector3.ONE, "BeaconCrown")
    _light = ModelKit3D.add_glow_light(_beacon_root, Vector3(0.0, 4.9, 0.0), beacon_color, 0.75, 7.0)

    _label = Label3D.new()
    _label.name = "RegionLabel"
    _label.text = display_name.to_upper()
    _label.position = Vector3(0.0, 6.2, 0.0)
    _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _label.fixed_size = true
    _label.font_size = 38
    _label.outline_size = 9
    _label.modulate = beacon_color.lightened(0.24)
    _label.outline_modulate = Color(0.015, 0.022, 0.026, 0.97)
    _beacon_root.add_child(_label)


func _add_ruin_block(origin: Vector3, size: Vector3, material: Material) -> void:
    ModelKit3D.add_box(_visual_root, size, origin + Vector3(0.0, size.y * 0.5, 0.0), material, Vector3.ZERO, "RuinBlock")
    var dark := ModelKit3D.material(Color("171a1b"), 0.0, 0.98)
    for floor_index in range(maxi(1, int(size.y / 2.2))):
        for window_index in range(3):
            var x := origin.x - size.x * 0.3 + float(window_index) * size.x * 0.3
            var y := origin.y + 1.2 + float(floor_index) * 2.0
            ModelKit3D.add_box(_visual_root, Vector3(0.7, 0.75, 0.08), Vector3(x, y, origin.z - size.z * 0.51), dark, Vector3.ZERO, "DarkWindow")


func _refresh_discovery() -> void:
    if _beacon_root != null:
        _beacon_root.visible = discovered


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
