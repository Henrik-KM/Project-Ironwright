class_name Outpost3D
extends StaticBody3D

signal health_changed(outpost: Outpost3D, current: float, maximum: float)
signal destroyed(outpost: Outpost3D)
signal threat_detected(outpost: Outpost3D, enemy: Node3D)
signal cargo_ready(outpost: Outpost3D)
signal weapon_fired(origin: Vector3, target: Vector3, target_node: Node)
signal state_changed(outpost: Outpost3D)

const ROLES: Array[StringName] = [&"resource", &"defence", &"scout", &"repair"]

var site_id: StringName = &"site.unknown"
var role: StringName = &"resource"
var tier: int = 1
var maximum_health: float = 240.0
var current_health: float = 240.0
var alive: bool = true
var stored_scrap: int = 0
var run_state: RunState3D

var _model_root: Node3D
var _status_light: OmniLight3D
var _damage_root: Node3D
var _damage_scar: Node3D
var _damage_leak: Node3D
var _critical_light: OmniLight3D
var _repair_clock: float = 0.0
var _role_clock: float = 0.0
var _weapon_cooldown: float = 0.0
var _warning_cooldown: float = 0.0

# Presentation-only state. The autonomy director remains the authority for
# work and scheduling; these bounded values let the release animation layer
# show what an outpost is doing without creating a player-managed task list.
var presentation_activity: float = 0.0
var presentation_status: StringName = &"idle"
var _presentation_status_clock: float = 0.0


func configure(
        next_site_id: StringName,
        next_role: StringName,
        next_tier: int,
        next_run_state: RunState3D
    ) -> void:
    site_id = next_site_id
    role = next_role if next_role in ROLES else &"resource"
    tier = clampi(next_tier, 1, 3)
    run_state = next_run_state
    _apply_tier_stats(true)


func _ready() -> void:
    add_to_group(&"outposts")
    collision_layer = 1
    collision_mask = 4
    _build_visuals()
    _refresh_visuals()
    health_changed.emit(self, current_health, maximum_health)


func _process(delta: float) -> void:
    presentation_activity = move_toward(presentation_activity, 0.0, delta * 0.72)
    _presentation_status_clock = maxf(0.0, _presentation_status_clock - delta)
    if _presentation_status_clock <= 0.0 and presentation_activity <= 0.01:
        presentation_status = &"idle"
    if not alive:
        presentation_activity = 0.0
        presentation_status = &"destroyed"
        return
    _repair_clock += delta
    _role_clock += delta
    _weapon_cooldown = maxf(0.0, _weapon_cooldown - delta)
    _warning_cooldown = maxf(0.0, _warning_cooldown - delta)
    _perform_automatic_repair()
    _perform_role()


func apply_damage(amount: float, source: Node = null) -> void:
    if not alive or amount <= 0.0:
        return
    current_health = maxf(0.0, current_health - amount)
    health_changed.emit(self, current_health, maximum_health)
    if current_health > 0.0:
        _refresh_damage_presentation()
        return
    alive = false
    _set_presentation_activity(&"destroyed", 0.0, 0.0)
    collision_layer = 0
    _refresh_visuals()
    destroyed.emit(self)
    state_changed.emit(self)


func repair(amount: float) -> void:
    if not alive or amount <= 0.0:
        return
    current_health = minf(maximum_health, current_health + amount)
    health_changed.emit(self, current_health, maximum_health)
    _refresh_damage_presentation()


func upgrade_to(next_tier: int) -> bool:
    if not alive or next_tier <= tier or next_tier > 3:
        return false
    var ratio := current_health / maxf(1.0, maximum_health)
    tier = next_tier
    _apply_tier_stats(false)
    current_health = maxf(maximum_health * ratio, maximum_health * 0.55)
    _refresh_visuals()
    health_changed.emit(self, current_health, maximum_health)
    state_changed.emit(self)
    return true


func rebuild(next_tier: int = -1) -> void:
    if next_tier > 0:
        tier = clampi(next_tier, 1, 3)
    alive = true
    collision_layer = 1
    _apply_tier_stats(true)
    current_health = maximum_health
    _set_presentation_activity(&"rebuilding", 1.0, 1.4)
    _refresh_visuals()
    health_changed.emit(self, current_health, maximum_health)
    state_changed.emit(self)


func is_alive() -> bool:
    return alive and current_health > 0.0


func take_stored_scrap(maximum_amount: int = 9999) -> int:
    if stored_scrap <= 0:
        return 0
    var amount := mini(stored_scrap, maxi(0, maximum_amount))
    stored_scrap -= amount
    state_changed.emit(self)
    return amount


func to_dictionary() -> Dictionary:
    return {
        "schema_version": 1,
        "site_id": String(site_id),
        "role": String(role),
        "tier": tier,
        "current_health": current_health,
        "alive": alive,
        "stored_scrap": stored_scrap,
    }


func restore_from_dictionary(data: Dictionary) -> void:
    role = StringName(str(data.get("role", String(role))))
    tier = clampi(int(data.get("tier", tier)), 1, 3)
    alive = bool(data.get("alive", true))
    stored_scrap = maxi(0, int(data.get("stored_scrap", 0)))
    _apply_tier_stats(true)
    current_health = clampf(float(data.get("current_health", maximum_health)), 0.0, maximum_health)
    if current_health <= 0.0:
        alive = false
    collision_layer = 1 if alive else 0
    if is_inside_tree():
        _refresh_visuals()
        health_changed.emit(self, current_health, maximum_health)
        state_changed.emit(self)


func _apply_tier_stats(reset_health: bool) -> void:
    maximum_health = [240.0, 390.0, 590.0][tier - 1]
    if reset_health:
        current_health = maximum_health


func _perform_automatic_repair() -> void:
    if _repair_clock < maxf(2.6, 4.8 - float(tier) * 0.5):
        return
    _repair_clock = 0.0
    if current_health >= maximum_health - 0.1 or run_state == null:
        return
    if run_state.spend_scrap(1):
        repair(7.0 + float(tier) * 5.0)
        _set_presentation_activity(&"repairing", 1.0, 0.9)


func _perform_role() -> void:
    match role:
        &"resource":
            _perform_resource_role()
        &"defence":
            _perform_defence_role()
        &"scout":
            _perform_scout_role()
        &"repair":
            _perform_repair_role()


func _perform_resource_role() -> void:
    var interval := maxf(5.5, 12.5 - float(tier) * 1.8)
    if _role_clock < interval:
        return
    _role_clock = 0.0
    stored_scrap = mini(120, stored_scrap + 4 + tier * 3)
    _set_presentation_activity(&"harvesting", 1.0, 1.0)
    if stored_scrap >= 20:
        cargo_ready.emit(self)
    state_changed.emit(self)


func _perform_defence_role() -> void:
    if _weapon_cooldown > 0.0:
        return
    var enemy := _nearest_enemy(10.0 + float(tier) * 4.0)
    if enemy == null:
        return
    _weapon_cooldown = maxf(0.48, 1.05 - float(tier) * 0.15)
    var damage := 7.0 + float(tier) * 6.0
    if enemy.has_method("apply_damage"):
        enemy.call("apply_damage", damage, self)
    _set_presentation_activity(&"defending", 1.0, 0.65)
    weapon_fired.emit(global_position + Vector3.UP * 2.0, enemy.global_position + Vector3.UP * 0.45, enemy)


func _perform_scout_role() -> void:
    if _warning_cooldown > 0.0:
        return
    var enemy := _nearest_enemy(18.0 + float(tier) * 7.0)
    if enemy == null:
        return
    _warning_cooldown = maxf(2.5, 6.5 - float(tier))
    _set_presentation_activity(&"scouting", 1.0, 1.1)
    threat_detected.emit(self, enemy)


func _perform_repair_role() -> void:
    var interval := maxf(1.4, 3.2 - float(tier) * 0.45)
    if _role_clock < interval:
        return
    _role_clock = 0.0
    var repair_range := 8.0 + float(tier) * 3.0
    var repaired_robot := false
    for robot in get_tree().get_nodes_in_group(&"friendly_robots"):
        if not is_instance_valid(robot) or not (robot is Node3D):
            continue
        if global_position.distance_to(robot.global_position) > repair_range:
            continue
        if robot.has_method("repair"):
            robot.call("repair", 4.0 + float(tier) * 3.0)
            repaired_robot = true
    if repaired_robot:
        _set_presentation_activity(&"repairing", 1.0, 1.0)


func _set_presentation_activity(status: StringName, strength: float, seconds: float) -> void:
    presentation_status = status
    presentation_activity = maxf(presentation_activity, clampf(strength, 0.0, 1.0))
    _presentation_status_clock = maxf(_presentation_status_clock, maxf(0.0, seconds))


func _nearest_enemy(maximum_range: float) -> Node3D:
    var best: Node3D
    var best_distance := maximum_range
    for candidate in get_tree().get_nodes_in_group(&"organic_enemies"):
        if not is_instance_valid(candidate) or not (candidate is Node3D):
            continue
        if candidate.has_method("is_alive") and not bool(candidate.call("is_alive")):
            continue
        var current_distance := global_position.distance_to(candidate.global_position)
        if current_distance < best_distance:
            best = candidate
            best_distance = current_distance
    return best


func _build_visuals() -> void:
    ModelKit3D.add_collision_box(self, Vector3(5.6, 3.4, 5.6), Vector3(0.0, 1.7, 0.0))
    _model_root = Node3D.new()
    _model_root.name = "OutpostModel"
    add_child(_model_root)


func _refresh_visuals() -> void:
    if _model_root == null:
        return
    for child in _model_root.get_children():
        child.free()

    var dark := ModelKit3D.material(Color("171c1e"), 0.78, 0.48)
    var iron := ModelKit3D.material(Color("3e4749"), 0.72, 0.46)
    var rust := ModelKit3D.material(Color("82573c"), 0.42, 0.7)
    var panel := ModelKit3D.material(Color("596568"), 0.76, 0.38)
    var panel_accent := ModelKit3D.material(Color("a6b5b3"), 0.64, 0.32)
    var role_color := Color("6bd8dd")
    if role == &"defence":
        role_color = Color("e1a159")
    elif role == &"scout":
        role_color = Color("8bd978")
    elif role == &"repair":
        role_color = Color("a78be0")
    var glow := ModelKit3D.material(role_color.darkened(0.62), 0.25, 0.38, role_color, 3.0)

    if not alive:
        ModelKit3D.add_box(_model_root, Vector3(4.5, 0.45, 4.5), Vector3(0.0, 0.25, 0.0), dark, Vector3.ZERO, "DestroyedFoundation")
        for index in range(6):
            ModelKit3D.add_box(
                _model_root,
                Vector3(0.7 + float(index % 3) * 0.35, 0.35, 0.55),
                Vector3(-1.5 + float(index % 3) * 1.4, 0.35 + float(index / 3) * 0.18, -0.8 + float(index / 3) * 1.5),
                rust,
                Vector3(0.15 * index, 0.35 * index, 0.12),
                "Rubble"
            )
        _status_light = ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 0.6, 0.0), Color("8b241b"), 0.3, 3.0)
        return

    ModelKit3D.add_cylinder(_model_root, 2.65, 0.45, Vector3(0.0, 0.23, 0.0), dark, Vector3.ZERO, "Foundation")
    ModelKit3D.add_beveled_box(_model_root, Vector3(3.7, 2.1, 3.4), Vector3(0.0, 1.35, 0.0), iron, Vector3.ZERO, "CoreShelter", 0.16)
    ModelKit3D.add_beveled_box(_model_root, Vector3(4.1, 0.24, 3.8), Vector3(0.0, 2.48, 0.0), rust, Vector3.ZERO, "RoofPlate", 0.28)
    ModelKit3D.add_louvered_panel(_model_root, Vector3(2.35, 0.82, 0.14), Vector3(0.0, 1.35, -1.72), panel, panel_accent, Vector3.ZERO, "CoreVent", 4)
    ModelKit3D.add_surface_panel(_model_root, Vector3(1.18, 0.72, 0.12), Vector3(-1.95, 1.18, -0.18), panel, panel_accent, Vector3(0.0, PI * 0.5, 0.0), "CoreServicePanel")
    ModelKit3D.add_sphere(_model_root, 0.24, Vector3(0.0, 2.9, -1.0), glow, Vector3.ONE, "StatusBeacon")

    for tier_index in range(tier):
        var y := 2.75 + float(tier_index) * 0.62
        var frame_name := "TierFrame%d" % (tier_index + 1)
        var frame := Node3D.new()
        frame.name = frame_name
        frame.position = Vector3(0.0, y, 0.0)
        _model_root.add_child(frame)
        var frame_size := 3.1 + float(tier_index) * 0.25
        ModelKit3D.add_beveled_box(frame, Vector3(frame_size, 0.16, 0.22), Vector3(0.0, 0.0, -frame_size * 0.5), rust, Vector3.ZERO, "%sNorthRail" % frame_name, 0.28)
        ModelKit3D.add_beveled_box(frame, Vector3(frame_size, 0.16, 0.22), Vector3(0.0, 0.0, frame_size * 0.5), rust, Vector3.ZERO, "%sSouthRail" % frame_name, 0.28)
        ModelKit3D.add_beveled_box(frame, Vector3(0.22, 0.16, frame_size - 0.42), Vector3(-frame_size * 0.5, 0.0, 0.0), rust, Vector3.ZERO, "%sWestRail" % frame_name, 0.28)
        ModelKit3D.add_beveled_box(frame, Vector3(0.22, 0.16, frame_size - 0.42), Vector3(frame_size * 0.5, 0.0, 0.0), rust, Vector3.ZERO, "%sEastRail" % frame_name, 0.28)

    var role_signature := Node3D.new()
    role_signature.name = "OutpostRoleSignature"
    _model_root.add_child(role_signature)

    match role:
        &"resource":
            ModelKit3D.add_beveled_box(role_signature, Vector3(1.5, 1.1, 1.4), Vector3(-1.2, 1.2, -1.75), dark, Vector3.ZERO, "ResourceHopper", 0.18)
            ModelKit3D.add_louvered_panel(role_signature, Vector3(1.0, 0.62, 0.1), Vector3(-1.2, 1.36, -2.47), panel, panel_accent, Vector3.ZERO, "ResourceHopperLouver", 3)
            ModelKit3D.add_cylinder(role_signature, 0.16, 2.2, Vector3(1.3, 1.45, -1.45), iron, Vector3(-0.4, 0.0, 0.0), "ResourceExtractorArm")
            ModelKit3D.add_sphere(role_signature, 0.26, Vector3(1.3, 2.47, -1.45), glow, Vector3(1.0, 0.65, 1.0), "ResourceIntakeBeacon")
        &"defence":
            ModelKit3D.add_beveled_box(role_signature, Vector3(1.7, 0.7, 1.5), Vector3(0.0, 3.02, 0.0), panel, Vector3.ZERO, "DefenceTurretHousing", 0.2)
            ModelKit3D.add_cylinder(role_signature, 0.18, 2.7, Vector3(0.0, 3.55, 0.0), iron, Vector3.ZERO, "DefenceTurretMast")
            ModelKit3D.add_cylinder(role_signature, 0.12, 1.8, Vector3(0.0, 4.58, -0.75), dark, Vector3(1.5708, 0.0, 0.0), "DefenceBarrel")
            ModelKit3D.add_sphere(role_signature, 0.18, Vector3(0.0, 4.58, -1.68), glow, Vector3(1.0, 0.72, 1.0), "DefenceMuzzleGlow")
            ModelKit3D.add_surface_panel(role_signature, Vector3(0.78, 0.42, 0.12), Vector3(-0.88, 3.02, -0.68), panel, panel_accent, Vector3(0.0, PI * 0.5, 0.0), "DefenceServicePanel")
        &"scout":
            ModelKit3D.add_beveled_box(role_signature, Vector3(1.0, 0.6, 1.0), Vector3(0.0, 3.08, 0.0), panel, Vector3.ZERO, "ScoutSensorHousing", 0.22)
            ModelKit3D.add_cylinder(role_signature, 0.11, 4.2, Vector3(0.0, 4.0, 0.0), iron, Vector3.ZERO, "ScoutSensorMast")
            ModelKit3D.add_sphere(role_signature, 0.38, Vector3(0.0, 6.15, 0.0), glow, Vector3(1.4, 0.55, 1.4), "ScoutSensorDish")
            for side in [-1.0, 1.0]:
                ModelKit3D.add_cylinder(role_signature, 0.055, 1.4, Vector3(side * 0.43, 6.15, 0.0), panel_accent, Vector3(0.0, 0.0, PI * 0.5), "ScoutDishRib")
            ModelKit3D.add_surface_panel(role_signature, Vector3(0.7, 0.38, 0.12), Vector3(0.0, 3.02, -0.52), panel, panel_accent, Vector3.ZERO, "ScoutServicePanel")
        &"repair":
            ModelKit3D.add_beveled_box(role_signature, Vector3(3.0, 0.18, 2.2), Vector3(0.0, 0.58, -2.15), glow, Vector3.ZERO, "RepairPad", 0.3)
            ModelKit3D.add_surface_panel(role_signature, Vector3(1.7, 0.24, 0.12), Vector3(0.0, 0.72, -2.15), panel, panel_accent, Vector3.ZERO, "RepairPadPanel")
            ModelKit3D.add_cylinder(role_signature, 0.12, 2.0, Vector3(-1.45, 1.35, -1.65), iron, Vector3(0.0, 0.0, 0.75), "RepairArm")
            ModelKit3D.add_cylinder(role_signature, 0.12, 2.0, Vector3(1.45, 1.35, -1.65), iron, Vector3(0.0, 0.0, -0.75), "RepairArmRight")
            ModelKit3D.add_sphere(role_signature, 0.2, Vector3(0.0, 1.02, -2.15), glow, Vector3(1.4, 0.5, 1.0), "RepairFieldEmitter")

    _status_light = ModelKit3D.add_glow_light(_model_root, Vector3(0.0, 2.9, -1.0), role_color, 0.9 + float(tier) * 0.35, 6.0 + float(tier) * 2.0)
    _build_damage_presentation()


func _build_damage_presentation() -> void:
    _damage_root = Node3D.new()
    _damage_root.name = "OutpostDamagePresentation"
    _model_root.add_child(_damage_root)
    var scar_material := ModelKit3D.material(Color("7e2c25"), 0.4, 0.72)
    var leak_material := ModelKit3D.material(Color("b65c31"), 0.28, 0.62, Color("f08a42"), 2.4)
    var critical_material := ModelKit3D.material(Color("712018"), 0.24, 0.68, Color("e34d32"), 3.0)
    _damage_scar = Node3D.new()
    _damage_scar.name = "OutpostDamageScar00"
    _damage_root.add_child(_damage_scar)
    ModelKit3D.add_beveled_box(_damage_scar, Vector3(0.36, 1.02, 0.12), Vector3(-1.18, 1.24, -1.79), scar_material, Vector3(0.0, 0.0, -0.34), "ScarPlate", 0.05)
    ModelKit3D.add_beveled_box(_damage_scar, Vector3(0.2, 0.54, 0.1), Vector3(-0.72, 1.66, -1.8), scar_material, Vector3(0.0, 0.0, 0.48), "ScarBrace", 0.04)
    _damage_leak = Node3D.new()
    _damage_leak.name = "OutpostDamageLeak00"
    _damage_root.add_child(_damage_leak)
    ModelKit3D.add_cylinder(_damage_leak, 0.055, 0.7, Vector3(0.82, 1.18, -1.82), leak_material, Vector3(0.15, 0.0, 0.35), "LeakCable")
    ModelKit3D.add_sphere(_damage_leak, 0.12, Vector3(0.62, 0.82, -1.85), leak_material, Vector3(1.0, 0.7, 1.0), "LeakEmitter")
    var critical_marker := Node3D.new()
    critical_marker.name = "OutpostCriticalMarker"
    _damage_root.add_child(critical_marker)
    ModelKit3D.add_beveled_box(critical_marker, Vector3(0.72, 0.1, 0.16), Vector3(0.0, 2.52, -1.92), critical_material, Vector3.ZERO, "CriticalWarningBar", 0.04)
    _critical_light = ModelKit3D.add_glow_light(critical_marker, Vector3.ZERO, Color("e34d32"), 0.0, 2.8)
    _refresh_damage_presentation()


func _refresh_damage_presentation() -> void:
    if _damage_root == null:
        return
    var integrity := current_health / maxf(1.0, maximum_health)
    var damaged := alive and integrity < 0.78
    var critical := alive and integrity < 0.42
    _damage_root.visible = damaged
    if _damage_scar != null:
        _damage_scar.visible = damaged
    if _damage_leak != null:
        _damage_leak.visible = critical
    if _critical_light != null:
        _critical_light.light_energy = 0.9 if critical else 0.0
