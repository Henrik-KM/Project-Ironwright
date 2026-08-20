class_name OrganicNest3D
extends StaticBody3D

signal nest_destroyed(nest, source: Node)
signal nest_damaged(nest, current: float, maximum: float)
signal maturity_changed(nest, maturity: float)

var nest_id: StringName = &"nest.unknown"
var display_name: String = "Organic nest"
var profile_id: StringName = &"local_minor"
var region_id: StringName = &"region.heartforge_district"
var local_nest_index: int = -1
var supported_tiers: Array[int] = [1]
var maximum_health: float = 180.0
var current_health: float = 180.0
var maturity: float = 0.35
var territory_radius: float = 24.0
var spawn_weight: float = 1.0
var destroy_replenishment_delta_per_minute: Dictionary = {}
var destroy_tier_1_growth_delta: float = 0.0
var active: bool = true
var discovered: bool = true
var spawn_serial: int = 0

var _model_root: Node3D
var _status_light: OmniLight3D


func configure(data: Dictionary) -> void:
    nest_id = StringName(str(data.get("nest_id", data.get("id", "nest.unknown"))))
    display_name = str(data.get("display_name", "Organic nest"))
    profile_id = StringName(str(data.get("profile_id", "local_minor")))
    region_id = StringName(str(data.get("region_id", "region.heartforge_district")))
    local_nest_index = int(data.get("local_nest_index", -1))
    supported_tiers.clear()
    for raw_tier in data.get("supported_tiers", [1]):
        supported_tiers.append(clampi(int(raw_tier), 1, 5))
    maximum_health = maxf(1.0, float(data.get("maximum_health", 180.0)))
    current_health = clampf(float(data.get("current_health", maximum_health)), 0.0, maximum_health)
    maturity = clampf(float(data.get("initial_maturity", data.get("maturity", 0.35))), 0.0, 1.0)
    territory_radius = clampf(float(data.get("territory_radius", 24.0)), 8.0, 70.0)
    spawn_weight = maxf(0.05, float(data.get("spawn_weight", 1.0)))
    var raw_deltas: Variant = data.get("destroy_replenishment_delta_per_minute", {})
    destroy_replenishment_delta_per_minute = (raw_deltas as Dictionary).duplicate(true) if raw_deltas is Dictionary else {}
    destroy_tier_1_growth_delta = float(data.get("destroy_tier_1_growth_delta", 0.0))
    active = bool(data.get("active", current_health > 0.0)) and current_health > 0.0
    discovered = bool(data.get("discovered", true))


func _ready() -> void:
    add_to_group(&"organic_nests")
    add_to_group(&"organic_enemies")
    collision_layer = 4 if active else 0
    collision_mask = 1 | 2
    _build_visuals()
    _refresh_visuals()


func is_alive() -> bool:
    return active and current_health > 0.0


func can_spawn_tier(tier: int) -> bool:
    return active and tier in supported_tiers


func spawn_position(minimum_radius: float, maximum_radius: float) -> Vector3:
    spawn_serial += 1
    var nest_hash := String(nest_id).hash()
    var angle := fmod(float(spawn_serial) * 2.399963 + float(nest_hash % 997) * 0.017, TAU)
    var fraction := 0.25 + 0.75 * _deterministic_unit(spawn_serial, 11)
    var radius := lerpf(minimum_radius, maximum_radius, fraction)
    return global_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func apply_damage(amount: float, source: Node = null) -> void:
    if not active or amount <= 0.0:
        return
    current_health = maxf(0.0, current_health - amount)
    nest_damaged.emit(self, current_health, maximum_health)
    if current_health > 0.0:
        return
    active = false
    collision_layer = 0
    _refresh_visuals()
    nest_destroyed.emit(self, source)


func advance_maturity(amount: float) -> void:
    if not active or amount <= 0.0:
        return
    var before := maturity
    maturity = clampf(maturity + amount, 0.0, 1.0)
    if not is_equal_approx(before, maturity):
        maturity_changed.emit(self, maturity)


func restore_after_load(data: Dictionary) -> void:
    current_health = clampf(float(data.get("current_health", maximum_health)), 0.0, maximum_health)
    maturity = clampf(float(data.get("maturity", maturity)), 0.0, 1.0)
    active = bool(data.get("active", current_health > 0.0)) and current_health > 0.0
    discovered = bool(data.get("discovered", discovered))
    spawn_serial = maxi(0, int(data.get("spawn_serial", spawn_serial)))
    collision_layer = 4 if active else 0
    if is_inside_tree():
        _refresh_visuals()


func to_dictionary() -> Dictionary:
    return {
        "nest_id": String(nest_id),
        "profile_id": String(profile_id),
        "region_id": String(region_id),
        "local_nest_index": local_nest_index,
        "current_health": current_health,
        "maturity": maturity,
        "active": active,
        "discovered": discovered,
        "spawn_serial": spawn_serial,
    }


func intelligence_directive_for_tier(tier: int) -> StringName:
    if tier <= 1:
        return &"roam"
    if tier == 2:
        return &"protect_nest" if spawn_serial % 3 != 0 else &"patrol"
    if tier == 3:
        return &"scout" if spawn_serial % 2 == 0 else &"hunt"
    if tier == 4:
        return &"hunt" if spawn_serial % 3 != 0 else &"protect_nest"
    return &"patrol"


func _build_visuals() -> void:
    ModelKit3D.add_collision_capsule(self, 1.65, 2.2, Vector3(0.0, 1.1, 0.0))
    _model_root = Node3D.new()
    _model_root.name = "NestModel"
    add_child(_model_root)


func _refresh_visuals() -> void:
    if _model_root == null:
        return
    for child in _model_root.get_children():
        child.queue_free()

    var chitin := ModelKit3D.material(Color("2b1d24"), 0.08, 0.68)
    var flesh := ModelKit3D.material(Color("4e192e"), 0.0, 0.72)
    var bone := ModelKit3D.material(Color("786d5d"), 0.0, 0.84)
    var signal_color := Color("da4267") if active else Color("4f2a31")
    var signal := ModelKit3D.material(signal_color.darkened(0.62), 0.0, 0.55, signal_color, 2.8 if active else 0.15)

    if not active:
        ModelKit3D.add_sphere(_model_root, 1.4, Vector3(0.0, 0.55, 0.0), chitin, Vector3(1.8, 0.48, 1.6), "CollapsedNest")
        for index in range(7):
            var angle := TAU * float(index) / 7.0
            ModelKit3D.add_capsule(_model_root, 0.1, 1.9, Vector3(cos(angle) * 1.25, 0.35, sin(angle) * 1.25), bone, Vector3(0.0, -angle, 1.18), "BrokenSpine")
        return

    var scale_factor := 0.82 + maturity * 0.52
    ModelKit3D.add_sphere(_model_root, 1.35, Vector3(0.0, 0.82, 0.0), chitin, Vector3(1.9, 0.86, 1.72) * scale_factor, "NestCore")
    ModelKit3D.add_sphere(_model_root, 0.62, Vector3(-0.8, 0.66, 0.55), flesh, Vector3(1.25, 1.0, 1.35) * scale_factor, "BroodSacA")
    ModelKit3D.add_sphere(_model_root, 0.55, Vector3(0.85, 0.58, 0.35), flesh, Vector3(1.15, 0.95, 1.3) * scale_factor, "BroodSacB")
    for index in range(9):
        var angle := TAU * float(index) / 9.0
        var radius := 1.35 + float(index % 3) * 0.24
        ModelKit3D.add_capsule(
            _model_root,
            0.09 + maturity * 0.035,
            2.1 + maturity * 1.2,
            Vector3(cos(angle) * radius, 1.0 + maturity * 0.35, sin(angle) * radius),
            bone,
            Vector3(0.0, -angle, 0.55 + float(index % 2) * 0.18),
            "NestSpine_%02d" % index
        )
    for index in range(5):
        var angle := TAU * float(index) / 5.0 + 0.35
        ModelKit3D.add_sphere(_model_root, 0.12, Vector3(cos(angle) * 0.85, 1.42 + maturity * 0.4, sin(angle) * 0.85), signal, Vector3.ONE, "NestSignal_%02d" % index)
    _status_light = ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 1.6, 0.0), signal_color, 0.65 + maturity * 0.75, 5.5 + maturity * 4.0)


func _deterministic_unit(serial: int, salt: int) -> float:
    var nest_hash := String(nest_id).hash()
    var value := sin(float(nest_hash % 8191) * 0.173 + float(serial) * 12.9898 + float(salt) * 4.1414) * 43758.5453
    return value - floor(value)
