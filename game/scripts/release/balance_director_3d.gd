class_name BalanceDirector3D
extends Node

signal profile_changed(profile_id: StringName, profile: Dictionary)
signal adaptive_relief_changed(value: float)

const PROFILES_PATH := "res://data/balance_profiles.json"

var profiles: Dictionary = {}
var guardrails: Dictionary = {}
var current_profile_id: StringName = &"survival"
var current_profile: Dictionary = {}
var adaptive_relief: float = 0.0
var pressure_samples: Array[Dictionary] = []
var critical_loss_clock: float = 9999.0
var heartforge_critical_clock: float = 9999.0
var evaluation_clock: float = 0.0
var load_errors: Array[String] = []


func _ready() -> void:
    add_to_group(&"balance_director")
    _load_profiles()
    set_profile(current_profile_id)


func _process(delta: float) -> void:
    critical_loss_clock += delta
    heartforge_critical_clock += delta
    evaluation_clock += delta
    if evaluation_clock < 2.0:
        return
    evaluation_clock = 0.0
    _update_adaptive_relief()


func _load_profiles() -> void:
    profiles.clear()
    guardrails.clear()
    load_errors.clear()
    var file := FileAccess.open(PROFILES_PATH, FileAccess.READ)
    if file == null:
        load_errors.append("Missing balance profiles")
        profiles = _fallback_profiles()
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        load_errors.append("Invalid balance profiles")
        profiles = _fallback_profiles()
        return
    var data := parsed as Dictionary
    var raw_profiles: Variant = data.get("profiles", {})
    profiles = (raw_profiles as Dictionary).duplicate(true) if raw_profiles is Dictionary else _fallback_profiles()
    var raw_guardrails: Variant = data.get("guardrails", {})
    guardrails = (raw_guardrails as Dictionary).duplicate(true) if raw_guardrails is Dictionary else {}
    current_profile_id = StringName(str(data.get("default_profile", "survival")))


func set_profile(profile_id: StringName) -> bool:
    var raw: Variant = profiles.get(String(profile_id), profiles.get(profile_id, null))
    if not (raw is Dictionary):
        return false
    current_profile_id = profile_id
    current_profile = (raw as Dictionary).duplicate(true)
    adaptive_relief = 0.0
    profile_changed.emit(current_profile_id, current_profile.duplicate(true))
    adaptive_relief_changed.emit(adaptive_relief)
    return true


func profile_ids() -> Array[StringName]:
    var result: Array[StringName] = []
    for raw_id in profiles:
        result.append(StringName(str(raw_id)))
    result.sort_custom(func(a: StringName, b: StringName) -> bool:
        return str(a) < str(b)
    )
    return result


func profile(profile_id: StringName = &"") -> Dictionary:
    var target_id := current_profile_id if profile_id == &"" else profile_id
    var raw: Variant = profiles.get(String(target_id), profiles.get(target_id, {}))
    return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func apply_to_enemy(enemy: OrganicEnemy3D) -> void:
    if enemy == null:
        return
    if not enemy.has_meta(&"release_base_health"):
        enemy.set_meta(&"release_base_health", enemy.maximum_health)
        enemy.set_meta(&"release_base_damage", enemy.attack_damage)
        enemy.set_meta(&"release_base_speed", enemy.move_speed)
    var health_ratio := enemy.current_health / maxf(1.0, enemy.maximum_health)
    enemy.maximum_health = float(enemy.get_meta(&"release_base_health")) * float(current_profile.get("enemy_health_multiplier", 1.0))
    enemy.attack_damage = float(enemy.get_meta(&"release_base_damage")) * float(current_profile.get("enemy_damage_multiplier", 1.0))
    enemy.move_speed = float(enemy.get_meta(&"release_base_speed")) * float(current_profile.get("enemy_speed_multiplier", 1.0))
    enemy.current_health = maxf(1.0, enemy.maximum_health * health_ratio)


func scale_scrap_yield(amount: int) -> int:
    return maxi(1, int(round(float(amount) * float(current_profile.get("scrap_yield_multiplier", 1.0)))))


func scale_operation_threat(value: float) -> float:
    return value * float(current_profile.get("operation_threat_multiplier", 1.0)) * (1.0 - adaptive_relief * 0.42)


func regional_pressure_multiplier() -> float:
    var configured := float(current_profile.get("regional_pressure_multiplier", 1.0))
    return maxf(0.55, configured * (1.0 - adaptive_relief))


func active_enemy_cap() -> int:
    return maxi(32, int(current_profile.get("active_enemy_cap", 96)))


func outpost_repair_multiplier() -> float:
    return float(current_profile.get("outpost_repair_multiplier", 1.0))


func continuity_scrap_loss() -> int:
    return maxi(0, int(current_profile.get("continuity_scrap_loss", 180)))


func record_machine_loss(archetype: StringName, world_time: float) -> void:
    critical_loss_clock = 0.0
    _record_sample(&"machine_loss", {"archetype": String(archetype), "world_time": world_time})


func record_heartforge_integrity(ratio: float, world_time: float) -> void:
    if ratio <= float(guardrails.get("critical_integrity_threshold", 0.28)):
        heartforge_critical_clock = 0.0
        _record_sample(&"heartforge_critical", {"integrity": ratio, "world_time": world_time})


func record_victory(world_time: float) -> void:
    _record_sample(&"first_victory", {"world_time": world_time, "profile": String(current_profile_id)})


func _update_adaptive_relief() -> void:
    var target := 0.0
    var configured_max := float(current_profile.get("adaptive_relief", 0.12))
    var loss_window := float(guardrails.get("critical_machine_loss_window_seconds", 45.0))
    var recovery_window := float(guardrails.get("minimum_heartforge_recovery_window_seconds", 18.0))
    if critical_loss_clock <= loss_window:
        target += configured_max * 0.55
    if heartforge_critical_clock <= recovery_window:
        target += configured_max
    target = clampf(target, 0.0, configured_max)
    var before := adaptive_relief
    adaptive_relief = move_toward(adaptive_relief, target, 0.018)
    if not is_equal_approx(before, adaptive_relief):
        adaptive_relief_changed.emit(adaptive_relief)


func _record_sample(kind: StringName, data: Dictionary) -> void:
    var entry := data.duplicate(true)
    entry["kind"] = String(kind)
    pressure_samples.push_back(entry)
    var limit := maxi(64, int(guardrails.get("telemetry_history_limit", 256)))
    if pressure_samples.size() > limit:
        pressure_samples = pressure_samples.slice(pressure_samples.size() - limit, pressure_samples.size())


func to_dictionary() -> Dictionary:
    return {
        "schema_version": 1,
        "profile_id": String(current_profile_id),
        "adaptive_relief": adaptive_relief,
        "critical_loss_clock": critical_loss_clock,
        "heartforge_critical_clock": heartforge_critical_clock,
        "pressure_samples": pressure_samples.duplicate(true),
    }


func restore_from_dictionary(data: Dictionary) -> void:
    set_profile(StringName(str(data.get("profile_id", "survival"))))
    adaptive_relief = clampf(float(data.get("adaptive_relief", 0.0)), 0.0, float(current_profile.get("adaptive_relief", 0.12)))
    critical_loss_clock = maxf(0.0, float(data.get("critical_loss_clock", 9999.0)))
    heartforge_critical_clock = maxf(0.0, float(data.get("heartforge_critical_clock", 9999.0)))
    pressure_samples.clear()
    for raw_entry in data.get("pressure_samples", []):
        if raw_entry is Dictionary:
            pressure_samples.append((raw_entry as Dictionary).duplicate(true))
    adaptive_relief_changed.emit(adaptive_relief)


func _fallback_profiles() -> Dictionary:
    return {
        "story": {"enemy_health_multiplier": 0.78, "enemy_damage_multiplier": 0.72, "enemy_speed_multiplier": 0.94, "regional_pressure_multiplier": 0.78, "active_enemy_cap": 62, "scrap_yield_multiplier": 1.28, "outpost_repair_multiplier": 1.25, "operation_threat_multiplier": 0.8, "continuity_scrap_loss": 110, "adaptive_relief": 0.22},
        "survival": {"enemy_health_multiplier": 1.0, "enemy_damage_multiplier": 1.0, "enemy_speed_multiplier": 1.0, "regional_pressure_multiplier": 1.0, "active_enemy_cap": 96, "scrap_yield_multiplier": 1.0, "outpost_repair_multiplier": 1.0, "operation_threat_multiplier": 1.0, "continuity_scrap_loss": 180, "adaptive_relief": 0.12},
        "brutal": {"enemy_health_multiplier": 1.18, "enemy_damage_multiplier": 1.22, "enemy_speed_multiplier": 1.06, "regional_pressure_multiplier": 1.24, "active_enemy_cap": 124, "scrap_yield_multiplier": 0.9, "outpost_repair_multiplier": 0.82, "operation_threat_multiplier": 1.22, "continuity_scrap_loss": 260, "adaptive_relief": 0.05},
    }
