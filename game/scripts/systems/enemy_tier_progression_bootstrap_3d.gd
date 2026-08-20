class_name EnemyTierProgressionBootstrap3D
extends Node

const SIDECAR_PATH := "user://saves/world_0.enemy_tiers.json"
const SIDECAR_TEMP_PATH := "user://saves/world_0.enemy_tiers.tmp"
const SIDECAR_BACKUP_PATH := "user://saves/world_0.enemy_tiers.backup.json"

var world: Node
var director: EnemyTierProgressionDirector3D
var suppression: AutonomousEnemySuppression3D
var intel_hud: EnemyTierIntelHUD3D
var transactional_save_service: Node
var main_hud: Node
var map_mode_last: bool = false
var initialized: bool = false
var pending_restore: bool = false


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_initialize")


func _process(delta: float) -> void:
    if not initialized or world == null or not is_instance_valid(world):
        return
    var map_mode := bool(world.get("map_mode"))
    if map_mode != map_mode_last:
        map_mode_last = map_mode
        intel_hud.set_command_map_visible(map_mode)
    if pending_restore:
        pending_restore = false
        _restore_sidecar()


func _initialize() -> void:
    if initialized:
        return
    world = get_parent()
    if world == null:
        return
    initialized = true

    director = EnemyTierProgressionDirector3D.new()
    director.name = "EnemyTierProgressionDirector"
    director.configure(world)
    add_child(director)

    suppression = AutonomousEnemySuppression3D.new()
    suppression.name = "AutonomousEnemySuppression"
    suppression.configure(world, director)
    add_child(suppression)

    intel_hud = EnemyTierIntelHUD3D.new()
    intel_hud.name = "EnemyTierIntelHUD"
    add_child(intel_hud)

    director.ecology_intel_changed.connect(_on_intel_changed)
    director.tier_saturated.connect(_on_tier_saturated)
    director.nest_cleared.connect(_on_nest_cleared)
    director.escalation_event_applied.connect(_on_escalation_event)
    suppression.suppression_patrol_changed.connect(_on_suppression_changed)

    main_hud = _find_node_with_method(world, &"push_notification")
    transactional_save_service = get_tree().get_first_node_in_group(&"transactional_save_service")
    if transactional_save_service != null:
        if transactional_save_service.has_signal(&"save_completed"):
            transactional_save_service.connect(&"save_completed", Callable(self, "_on_world_save_completed"))
        if transactional_save_service.has_signal(&"load_completed"):
            transactional_save_service.connect(&"load_completed", Callable(self, "_on_world_load_completed"))
    _disable_legacy_population_generators()
    director.call_deferred("_emit_intel_if_changed", true)


func _disable_legacy_population_generators() -> void:
    _disable_generator_recursive(world)


func _disable_generator_recursive(node: Node) -> void:
    if node == null or node == director:
        return
    var class_name_text := node.get_class()
    var script := node.get_script()
    if script != null:
        class_name_text = str(script.get_global_name())
    if (
        class_name_text in ["EcologyDirector3D", "StrategicEcologyDirector3D"]
        or node.has_method(&"_spawn_regional_organism")
    ):
        node.set_meta(&"population_controlled_by_enemy_tiers", true)
        if _has_property(node, &"active_enemy_cap"):
            node.set("active_enemy_cap", 0)
        if _has_property(node, &"spawn_interval"):
            node.set("spawn_interval", 999999.0)
    for child in node.get_children():
        _disable_generator_recursive(child)


func _has_property(object: Object, property_name: StringName) -> bool:
    for property in object.get_property_list():
        if StringName(str(property.get("name", ""))) == property_name:
            return true
    return false


func _on_intel_changed(summary: Dictionary) -> void:
    intel_hud.update_intel(summary)


func _on_tier_saturated(tier: int, transferred_rate: float, next_tier: int) -> void:
    _notify(
        "ECOLOGICAL SATURATION · TIER %s\n%.2f units/min of reproductive pressure evolved into Tier %s at 10:1." % [
            _roman(tier),
            transferred_rate,
            _roman(next_tier),
        ]
    )


func _on_nest_cleared(nest_id: StringName, removed_rates: Dictionary) -> void:
    var total := 0.0
    for value in removed_rates.values():
        total += float(value)
    _notify(
        "NEST CLEARED · %s\nLong-term replenishment fell by %.2f units/min across its current evolved tiers." % [
            String(nest_id).replace("nest.", "").replace("_", " ").capitalize(),
            total,
        ]
    )


func _on_escalation_event(event_id: StringName, deltas: Dictionary) -> void:
    var positive := 0.0
    var negative := 0.0
    for value in deltas.values():
        var amount := float(value)
        if amount >= 0.0:
            positive += amount
        else:
            negative += -amount
    if positive > negative:
        _notify("ECOLOGICAL COST · %s\nThe operation or technology increased future organic replenishment." % String(event_id).replace("operation.", "").replace("_", " ").capitalize())
    elif negative > 0.0:
        _notify("ECOLOGICAL SUPPRESSION · %s\nThe completed action reduced long-term organic replenishment." % String(event_id).replace("operation.", "").replace("_", " ").capitalize())


func _on_suppression_changed(active_wardens: int, target_cells: int, reason: String) -> void:
    intel_hud.update_suppression(suppression.status_summary())
    if active_wardens > 0:
        _notify("AUTONOMOUS SUPPRESSION · %d WARDEN%s\n%s" % [active_wardens, "" if active_wardens == 1 else "S", reason])


func _notify(message: String) -> void:
    if main_hud != null and is_instance_valid(main_hud):
        main_hud.call(&"push_notification", message)


func _on_world_save_completed(slot_id: StringName, path: String) -> void:
    _save_sidecar()


func _on_world_load_completed(slot_id: StringName, source_path: String, recovered_backup: bool) -> void:
    pending_restore = true


func _save_sidecar() -> bool:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
    var payload := director.to_dictionary()
    var payload_json := JSON.stringify(payload)
    var envelope := {
        "schema_version": 1,
        "saved_at_unix": int(Time.get_unix_time_from_system()),
        "checksum_sha256": _sha256(payload_json),
        "payload": payload,
    }
    var file := FileAccess.open(SIDECAR_TEMP_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(envelope))
    file.flush()
    file.close()
    if _read_verified(SIDECAR_TEMP_PATH).is_empty():
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SIDECAR_TEMP_PATH))
        return false
    if FileAccess.file_exists(SIDECAR_BACKUP_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SIDECAR_BACKUP_PATH))
    if FileAccess.file_exists(SIDECAR_PATH):
        DirAccess.rename_absolute(ProjectSettings.globalize_path(SIDECAR_PATH), ProjectSettings.globalize_path(SIDECAR_BACKUP_PATH))
    return DirAccess.rename_absolute(ProjectSettings.globalize_path(SIDECAR_TEMP_PATH), ProjectSettings.globalize_path(SIDECAR_PATH)) == OK


func _restore_sidecar() -> bool:
    var envelope := _read_verified(SIDECAR_PATH)
    if envelope.is_empty():
        envelope = _read_verified(SIDECAR_BACKUP_PATH)
    if envelope.is_empty():
        return false
    var payload: Variant = envelope.get("payload", {})
    if not (payload is Dictionary):
        return false
    director.restore_from_dictionary(payload)
    return true


func _read_verified(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        return {}
    var envelope := parsed as Dictionary
    var payload: Variant = envelope.get("payload", null)
    if not (payload is Dictionary):
        return {}
    var expected := str(envelope.get("checksum_sha256", ""))
    if expected.is_empty() or expected != _sha256(JSON.stringify(payload)):
        return {}
    return envelope


func _sha256(value: String) -> String:
    var context := HashingContext.new()
    if context.start(HashingContext.HASH_SHA256) != OK:
        return ""
    context.update(value.to_utf8_buffer())
    return context.finish().hex_encode()


func _find_node_with_method(root: Node, method_name: StringName) -> Node:
    if root == null:
        return null
    if root.has_method(method_name):
        return root
    for child in root.get_children():
        var found := _find_node_with_method(child, method_name)
        if found != null:
            return found
    return null


func _roman(value: int) -> String:
    match value:
        1:
            return "I"
        2:
            return "II"
        3:
            return "III"
        4:
            return "IV"
        _:
            return "V"
