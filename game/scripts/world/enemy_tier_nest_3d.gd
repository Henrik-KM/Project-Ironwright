class_name EnemyTierNest3D
extends StaticBody3D

signal health_changed(nest: EnemyTierNest3D, current: float, maximum: float)
signal destroyed(nest: EnemyTierNest3D, source: Node)
signal restored(nest: EnemyTierNest3D)
signal maturity_changed(nest: EnemyTierNest3D, maturity: float)

var nest_id: StringName = &"nest.unknown"
var display_name: String = "Organic Nest"
var region_id: StringName = &"region.heartforge_district"
var supported_tiers: Array[int] = [1]
var replenishment_per_minute: Dictionary = {"1": 0.5}
var maturity: float = 0.5
var maximum_health: float = 250.0
var current_health: float = 250.0
var alive: bool = true
var regrowth_seconds: float = 1800.0
var destroyed_elapsed: float = 0.0
var regrowth_progress: float = 0.0
var can_regrow: bool = true
var spawn_serial: int = 0
var state_name: StringName = &"active"
var _model_root: Node3D
var _pulse_light: OmniLight3D
var _region_director: Node
var _visual_clock: float = 0.0
var _base_scale: Vector3 = Vector3.ONE


func configure(data: Dictionary) -> void:
    nest_id = StringName(str(data.get("id", "nest.unknown")))
    display_name = str(data.get("display_name", "Organic Nest"))
    region_id = StringName(str(data.get("region_id", "region.heartforge_district")))
    maturity = clampf(float(data.get("maturity", 0.5)), 0.05, 1.0)
    maximum_health = maxf(25.0, float(data.get("maximum_health", 250.0)))
    current_health = maximum_health
    regrowth_seconds = maxf(60.0, float(data.get("regrowth_seconds", 1800.0)))
    can_regrow = bool(data.get("can_regrow", true))
    var raw_replenishment: Variant = data.get("replenishment_per_minute", {})
    replenishment_per_minute = {}
    if raw_replenishment is Dictionary:
        replenishment_per_minute = (raw_replenishment as Dictionary).duplicate(true)
    supported_tiers.clear()
    for raw_tier in data.get("supported_tiers", [1]):
        supported_tiers.append(maxi(1, int(raw_tier)))
    var raw_position: Array = data.get("position", [0.0, 0.0, 0.0])
    if raw_position.size() >= 3:
        position = Vector3(float(raw_position[0]), float(raw_position[1]), float(raw_position[2]))


func _ready() -> void:
    add_to_group(&"enemy_tier_nests")
    add_to_group(&"organic_structures")
    add_to_group(&"organic_ecology_sources")
    collision_layer = 4
    collision_mask = 2
    _build_visuals()
    _base_scale = scale
    call_deferred("_resolve_region_director")


func _process(delta: float) -> void:
    _visual_clock += delta
    _animate_visuals()
    if alive or not can_regrow:
        return
    destroyed_elapsed += delta
    if destroyed_elapsed < regrowth_seconds:
        return
    state_name = &"regrowing"
    regrowth_progress = clampf(regrowth_progress + delta / maxf(90.0, regrowth_seconds * 0.18), 0.0, 1.0)
    current_health = maximum_health * regrowth_progress
    visible = true
    if regrowth_progress < 1.0:
        collision_layer = 0
        _refresh_visual_state()
        return
    alive = true
    state_name = &"active"
    destroyed_elapsed = 0.0
    regrowth_progress = 0.0
    current_health = maximum_health
    collision_layer = 4
    _refresh_visual_state()
    health_changed.emit(self, current_health, maximum_health)
    restored.emit(self)


func _resolve_region_director() -> void:
    _region_director = _find_node_with_method(get_tree().current_scene, &"effective_pressure")


func _find_node_with_method(root: Node, method_name: StringName) -> Node:
    if root == null:
        return null
    if root.has_method(method_name) and root.has_method(&"get_landmark"):
        return root
    for child in root.get_children():
        var found := _find_node_with_method(child, method_name)
        if found != null:
            return found
    return null


func apply_damage(amount: float, source: Node = null) -> void:
    if not alive or amount <= 0.0:
        return
    current_health = maxf(0.0, current_health - amount)
    health_changed.emit(self, current_health, maximum_health)
    if current_health > 0.0:
        return
    alive = false
    state_name = &"destroyed"
    destroyed_elapsed = 0.0
    regrowth_progress = 0.0
    collision_layer = 0
    _refresh_visual_state()
    destroyed.emit(self, source)


func repair(amount: float) -> void:
    if not alive or amount <= 0.0:
        return
    current_health = minf(maximum_health, current_health + amount)
    health_changed.emit(self, current_health, maximum_health)


func is_alive() -> bool:
    return alive and current_health > 0.0


func can_spawn_tier(tier: int) -> bool:
    return alive and tier in supported_tiers and contribution_for_tier(tier) > 0.000001


func contribution_for_tier(tier: int) -> float:
    if not alive:
        return 0.0
    var raw := float(replenishment_per_minute.get(str(tier), replenishment_per_minute.get(tier, 0.0)))
    return maxf(0.0, raw * maturity * _regional_source_multiplier())


func effective_replenishment() -> Dictionary:
    var result: Dictionary = {}
    for tier in supported_tiers:
        result[str(tier)] = contribution_for_tier(tier)
    return result


func _regional_source_multiplier() -> float:
    if _region_director == null or not is_instance_valid(_region_director):
        return 1.0
    var landmark: Variant = _region_director.call(&"get_landmark", region_id)
    if landmark == null or not is_instance_valid(landmark):
        return 1.0
    var suppression := clampf(float(landmark.get("suppression")), 0.0, 0.9)
    return 1.0 - suppression * 0.72


func next_spawn_position(tier: int, serial: int) -> Vector3:
    spawn_serial += 1
    var angle := fmod(float(serial * 47 + spawn_serial * 19 + tier * 31), 360.0) * PI / 180.0
    var tier_config := _tier_config(tier)
    var minimum := float(tier_config.get("spawn_radius_min", 3.5))
    var maximum := maxf(minimum, float(tier_config.get("spawn_radius_max", 8.0)))
    var fraction := fmod(float(serial * 37 + tier * 13), 97.0) / 96.0
    var radius := lerpf(minimum, maximum, fraction)
    return global_position + Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)


func _tier_config(tier: int) -> Dictionary:
    var progression := get_tree().get_first_node_in_group(&"enemy_tier_progression")
    if progression != null and progression.has_method(&"get_tier_data"):
        var raw: Variant = progression.call(&"get_tier_data", tier)
        if raw is Dictionary:
            return (raw as Dictionary).duplicate(true)
    return {}


func set_maturity(value: float) -> void:
    var next := clampf(value, 0.05, 1.0)
    if is_equal_approx(next, maturity):
        return
    maturity = next
    _refresh_visual_state()
    maturity_changed.emit(self, maturity)


func status_summary() -> String:
    if alive:
        var tier_labels: Array[String] = []
        for tier in supported_tiers:
            tier_labels.append(str(tier))
        return "%s · %d%% mature · supports tiers %s" % [display_name, int(round(maturity * 100.0)), ", ".join(tier_labels)]
    if state_name == &"regrowing":
        return "%s · regrowing · %d%%" % [display_name, int(round(regrowth_progress * 100.0))]
    return "%s · destroyed · regrowth evidence in %d min" % [display_name, int(ceil(maxf(0.0, regrowth_seconds - destroyed_elapsed) / 60.0))]


func to_dictionary() -> Dictionary:
    return {
        "schema_version": 1,
        "nest_id": String(nest_id),
        "alive": alive,
        "maturity": maturity,
        "current_health": current_health,
        "destroyed_elapsed": destroyed_elapsed,
        "regrowth_progress": regrowth_progress,
        "state_name": String(state_name),
        "spawn_serial": spawn_serial,
    }


func restore_from_dictionary(data: Dictionary) -> void:
    alive = bool(data.get("alive", true))
    maturity = clampf(float(data.get("maturity", maturity)), 0.05, 1.0)
    current_health = clampf(float(data.get("current_health", maximum_health)), 0.0, maximum_health)
    destroyed_elapsed = maxf(0.0, float(data.get("destroyed_elapsed", 0.0)))
    regrowth_progress = clampf(float(data.get("regrowth_progress", 0.0)), 0.0, 1.0)
    state_name = StringName(str(data.get("state_name", "active" if alive else "destroyed")))
    spawn_serial = maxi(0, int(data.get("spawn_serial", 0)))
    collision_layer = 4 if alive else 0
    visible = alive or state_name == &"regrowing"
    if is_inside_tree():
        _refresh_visual_state()
        health_changed.emit(self, current_health, maximum_health)


func _build_visuals() -> void:
    ModelKit3D.add_collision_capsule(self, 2.1, 1.6, Vector3(0.0, 1.1, 0.0))
    _model_root = Node3D.new()
    _model_root.name = "TierNestModel"
    add_child(_model_root)

    var chitin := ModelKit3D.material(Color("2d2028"), 0.04, 0.68)
    var bone := ModelKit3D.material(Color("877d68"), 0.0, 0.84)
    var membrane := ModelKit3D.material(Color("5d1837"), 0.0, 0.64, Color("b83462"), 1.7)
    var wound := ModelKit3D.material(Color("31131f"), 0.0, 0.76, Color("d94c69"), 2.4)

    ModelKit3D.add_sphere(_model_root, 1.75, Vector3(0.0, 1.0, 0.0), chitin, Vector3(1.4, 0.72, 1.4), "NestCore")
    for index in range(10):
        var angle := TAU * float(index) / 10.0
        var radius := 2.0 + float(index % 3) * 0.35
        var direction := Vector3(cos(angle), 0.0, sin(angle))
        ModelKit3D.add_capsule(
            _model_root,
            0.1 + float(index % 2) * 0.035,
            2.4 + float(index % 4) * 0.35,
            direction * radius + Vector3.UP * 0.5,
            bone,
            Vector3(0.0, -angle, 1.02),
            "NestRoot_%02d" % index
        )
    for index in range(6):
        var angle := TAU * float(index) / 6.0 + 0.33
        ModelKit3D.add_sphere(
            _model_root,
            0.46 + float(index % 2) * 0.12,
            Vector3(cos(angle) * 1.35, 0.75 + float(index % 3) * 0.4, sin(angle) * 1.35),
            membrane,
            Vector3(1.1, 1.25, 1.1),
            "BroodSac_%02d" % index
        )
    ModelKit3D.add_sphere(_model_root, 0.48, Vector3(0.0, 1.75, 0.0), wound, Vector3(1.0, 1.25, 1.0), "NestPulse")
    _pulse_light = ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 1.8, 0.0), Color("d84b69"), 1.3, 7.5)
    _refresh_visual_state()


func _animate_visuals() -> void:
    if _model_root == null:
        return
    var pulse := 1.0 + sin(_visual_clock * (1.8 + maturity * 1.2)) * 0.045 * maturity
    var pulse_node := _model_root.get_node_or_null("NestPulse") as Node3D
    if pulse_node != null:
        pulse_node.scale = Vector3.ONE * pulse
    if _pulse_light != null:
        _pulse_light.light_energy = (0.25 if not alive else 0.9 + maturity * 0.8) * (0.88 + sin(_visual_clock * 2.4) * 0.12)


func _refresh_visual_state() -> void:
    if _model_root == null:
        return
    var state_scale := maxf(0.08, maturity)
    if not alive:
        state_scale = maxf(0.08, regrowth_progress * 0.72)
    _model_root.scale = _base_scale * Vector3(0.82 + state_scale * 0.28, 0.55 + state_scale * 0.48, 0.82 + state_scale * 0.28)
    _model_root.rotation.z = 0.0 if alive else 0.22
    if _pulse_light != null:
        _pulse_light.light_color = Color("d84b69") if alive else Color("6f2a36")
