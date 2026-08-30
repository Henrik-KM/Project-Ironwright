class_name EnemyTierProgressionBootstrap3D
extends Node

const DEFAULT_SIDECAR_ROOT := "user://saves"
const DEFAULT_SIDECAR_SLOT: StringName = &"world_0"

var sidecar_path: String = "%s/%s.enemy_tiers.json" % [DEFAULT_SIDECAR_ROOT, DEFAULT_SIDECAR_SLOT]
var sidecar_temp_path: String = "%s/%s.enemy_tiers.tmp" % [DEFAULT_SIDECAR_ROOT, DEFAULT_SIDECAR_SLOT]
var sidecar_backup_path: String = "%s/%s.enemy_tiers.backup.json" % [DEFAULT_SIDECAR_ROOT, DEFAULT_SIDECAR_SLOT]

var world: Node
var director: EnemyTierProgressionDirector3D
var suppression: AutonomousEnemySuppression3D
var intel_hud: EnemyTierIntelHUD3D
var transactional_save_service: Node
var main_hud: Node
var map_mode_last: bool = false
var initialized: bool = false
var initialization_started: bool = false
var pending_restore: bool = false
var prefer_backup_restore: bool = false
var last_suppression_active_wardens: int = 0


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    call_deferred("_initialize")


func _process(delta: float) -> void:
    if not initialized or world == null or not is_instance_valid(world):
        return
    var map_mode := bool(world.get("map_mode")) if _has_property(world, &"map_mode") else false if _has_property(world, &"map_mode") else false
    if map_mode != map_mode_last:
        map_mode_last = map_mode
        intel_hud.set_command_map_visible(map_mode)
    if pending_restore:
        pending_restore = false
        # RC1 stored tier state in a second file whose generation could drift
        # from the transactional world save. Unified snapshots always win;
        # the sidecar is now a read-only migration fallback for older saves.
        if not bool(world.get_meta(&"enemy_tier_progression_restored_from_unified", false)):
            if _restore_sidecar(prefer_backup_restore):
                world.set_meta(&"enemy_tier_progression_migrated_from_sidecar", true)
        prefer_backup_restore = false


func _initialize() -> void:
    if initialized or initialization_started:
        return
    world = get_parent()
    if world == null:
        return
    initialization_started = true
    await _await_initial_presentation_idle()
    if world == null or not is_instance_valid(world) or world.is_queued_for_deletion():
        initialization_started = false
        return

    director = EnemyTierProgressionDirector3D.new()
    director.name = "EnemyTierProgressionDirector"
    director.configure(world)
    add_child(director)
    if not await _await_director_world_binding():
        initialization_started = false
        push_warning("Enemy-tier director did not finish binding its physical nest network; canonical ecology remains unavailable.")
        return

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
        if _has_property(transactional_save_service, &"save_root"):
            _configure_sidecar_paths(str(transactional_save_service.get("save_root")), DEFAULT_SIDECAR_SLOT)
        if transactional_save_service.has_signal(&"save_completed"):
            transactional_save_service.connect(&"save_completed", Callable(self, "_on_world_save_completed"))
        if transactional_save_service.has_signal(&"load_completed"):
            transactional_save_service.connect(&"load_completed", Callable(self, "_on_world_load_completed"))
    _disable_legacy_population_generators()
    director.call_deferred("_emit_intel_if_changed", true)
    initialized = true
    initialization_started = false


func _await_initial_presentation_idle() -> void:
    var release_art := world.get_node_or_null("ReleaseWorldArtDirector") if world != null else null
    if release_art == null or not release_art.has_method(&"is_presentation_idle"):
        return
    var stable_samples := 0
    for _attempt in range(480):
        _advance_authored_model_handoffs()
        if bool(release_art.call(&"is_presentation_idle")):
            stable_samples += 1
            if stable_samples >= 3:
                return
        else:
            stable_samples = 0
        await get_tree().create_timer(0.025, true, false, true).timeout
        await get_tree().process_frame
    push_warning("Enemy-tier presentation startup exceeded its renderer handoff guard; continuing after the bounded wait.")


func _await_director_world_binding() -> bool:
    # Director readiness includes its physical nest network, not merely the
    # existence of the node. Continue/load and live review may proceed only
    # after this boundary so they cannot observe a half-bound ecology.
    for _attempt in range(600):
        if director != null and is_instance_valid(director) and director.world_bound and not director.nests.is_empty():
            return true
        if world == null or not is_instance_valid(world) or world.is_queued_for_deletion():
            return false
        await get_tree().create_timer(0.025, true, false, true).timeout
        await get_tree().process_frame
    return false


func _advance_authored_model_handoffs() -> void:
    if world == null or not is_instance_valid(world):
        return
    for raw_landmark in world.find_children("*", "RegionLandmark3D", true, false):
        var landmark := raw_landmark as RegionLandmark3D
        if landmark != null and landmark.authored_model_presentation_pending():
            landmark.advance_authored_model_presentation()


func _disable_legacy_population_generators() -> void:
    _disable_generator_recursive(world)


func _disable_generator_recursive(node: Node) -> void:
    if node == null or node == director:
        return
    var class_name_text := node.get_class()
    var script: Script = node.get_script() as Script
    if script != null:
        if script.has_method(&"get_global_name"):
            class_name_text = str(script.call(&"get_global_name"))
    if (
        class_name_text in ["EcologyDirector3D", "StrategicEcologyDirector3D"]
        or node.has_method(&"_spawn_regional_organism")
    ):
        node.set_meta(&"population_controlled_by_enemy_tiers", true)
        # These directors still own attention, nest posture, regional pressure,
        # and physical migration. Hand off births without freezing the living
        # ecology that makes the population model visible in play.
        if node.has_method(&"set_external_population_control"):
            node.call(&"set_external_population_control", true)
        if _has_property(node, &"spawn_enemy_callable"):
            node.set("spawn_enemy_callable", Callable())
        if _has_property(node, &"spawn_enemy_callback"):
            node.set("spawn_enemy_callback", Callable())
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
        _text("notification.tier.saturation_detail", "ECOLOGICAL SATURATION · TIER {0}\n{1} units/min of reproductive pressure evolved into Tier {2} at 10:1.", [
            _roman(tier),
            transferred_rate,
            _roman(next_tier),
        ])
    )


func _on_nest_cleared(nest_id: StringName, removed_rates: Dictionary) -> void:
    var total := 0.0
    for value in removed_rates.values():
        total += float(value)
    _notify(
        _text("notification.tier.nest_cleared_detail", "NEST CLEARED · {0}\nLong-term replenishment fell by {1} units/min across its current evolved tiers.", [
            String(nest_id).replace("nest.", "").replace("_", " ").capitalize(),
            total,
        ])
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
    var causal_reason := director.event_causal_reason(event_id) if director != null else ""
    var notification := ""
    if positive > negative:
        notification = _text("notification.tier.ecological_cost", "ECOLOGICAL COST · {0}\nThe operation or technology increased future organic replenishment.", [String(event_id).replace("operation.", "").replace("_", " ").capitalize()])
    elif negative > 0.0:
        notification = _text("notification.tier.ecological_suppression", "ECOLOGICAL SUPPRESSION · {0}\nThe completed action reduced long-term organic replenishment.", [String(event_id).replace("operation.", "").replace("_", " ").capitalize()])
    if notification.is_empty():
        return
    if not causal_reason.is_empty():
        notification += "\n%s" % causal_reason
    _notify(notification)


func _on_suppression_changed(active_wardens: int, target_cells: int, reason: String) -> void:
    intel_hud.update_suppression(suppression.status_summary())
    # Routine Tier-I thinning belongs in the command-map status, not in an
    # eight-second notification loop. Surface only the transition where an
    # existing patrol stands down so a lost or completed assignment is legible.
    if last_suppression_active_wardens > 0 and active_wardens == 0:
        _notify(_text("notification.tier.autonomous_suppression_stood_down", "AUTONOMOUS SUPPRESSION STOOD DOWN\n{0}", [reason]))
    last_suppression_active_wardens = active_wardens


func _notify(message: String) -> void:
    if main_hud != null and is_instance_valid(main_hud):
        main_hud.call(&"push_notification", message)


func _text(key: String, fallback: String, replacements: Array = []) -> String:
    var service := get_tree().get_first_node_in_group(&"localization_service") as LocalizationService3D
    if service != null:
        return service.text(key, replacements)
    var result := fallback
    for index in range(replacements.size()):
        result = result.replace("{%d}" % index, str(replacements[index]))
    return result


func _on_world_save_completed(slot_id: StringName, path: String) -> bool:
    _configure_sidecar_from_save_path(slot_id, path)
    # Canonical tier state now lives inside the same checksummed transactional
    # snapshot as the actors it describes. Keep legacy sidecars untouched so an
    # RC1 save can be migrated, but never create a new mismatched generation.
    return true


func _on_world_load_completed(slot_id: StringName, source_path: String, recovered_backup: bool) -> void:
    _configure_sidecar_from_save_path(slot_id, source_path)
    prefer_backup_restore = recovered_backup
    pending_restore = true


func _restore_sidecar(prefer_backup: bool = false) -> bool:
    var envelope := _read_verified(sidecar_backup_path if prefer_backup else sidecar_path)
    if envelope.is_empty():
        envelope = _read_verified(sidecar_path if prefer_backup else sidecar_backup_path)
    if envelope.is_empty():
        return false
    var payload: Variant = envelope.get("payload", {})
    if not (payload is Dictionary):
        return false
    director.restore_from_dictionary(payload)
    return true


func _configure_sidecar_paths(save_root: String, slot_id: StringName = DEFAULT_SIDECAR_SLOT) -> void:
    var normalized_root := save_root.strip_edges()
    while normalized_root.ends_with("/"):
        normalized_root = normalized_root.left(-1)
    if normalized_root.is_empty():
        normalized_root = DEFAULT_SIDECAR_ROOT
    var safe_slot := _safe_slot(slot_id)
    sidecar_path = "%s/%s.enemy_tiers.json" % [normalized_root, safe_slot]
    sidecar_temp_path = "%s/%s.enemy_tiers.tmp" % [normalized_root, safe_slot]
    sidecar_backup_path = "%s/%s.enemy_tiers.backup.json" % [normalized_root, safe_slot]


func _configure_sidecar_from_save_path(slot_id: StringName, save_path: String) -> void:
    if save_path.strip_edges().is_empty():
        return
    _configure_sidecar_paths(save_path.get_base_dir(), slot_id)


func _canonical_json(value: Variant) -> String:
    if value is Dictionary:
        var source := value as Dictionary
        var keys: Array = source.keys()
        keys.sort_custom(func(left: Variant, right: Variant) -> bool:
            var left_text := str(left)
            var right_text := str(right)
            if left_text == right_text:
                return typeof(left) < typeof(right)
            return left_text < right_text
        )
        var pairs: Array[String] = []
        for raw_key in keys:
            pairs.append("%s:%s" % [JSON.stringify(str(raw_key)), _canonical_json(source.get(raw_key))])
        return "{%s}" % ",".join(pairs)
    if value is Array:
        var items: Array[String] = []
        for item in value:
            items.append(_canonical_json(item))
        return "[%s]" % ",".join(items)
    if value is float:
        var number := float(value)
        if not is_finite(number):
            return "null"
        if is_equal_approx(number, round(number)):
            return str(int(number))
        # JSON round-tripping can perturb the last binary-float digits. A
        # stable eight-decimal representation keeps the checksum deterministic
        # without erasing meaningful ecological rates.
        return String.num(number, 8)
    return JSON.stringify(value)


func _read_verified(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    # JSON.parse_string() emits an engine error for malformed legacy files.
    # The sidecar is an optional read-only migration source, so reject corrupt
    # input quietly and let the canonical world reconstruction remain active.
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK:
        return {}
    var parsed: Variant = parser.data
    if not (parsed is Dictionary):
        return {}
    var envelope := parsed as Dictionary
    var payload: Variant = envelope.get("payload", null)
    if not (payload is Dictionary):
        return {}
    var expected := str(envelope.get("checksum_sha256", ""))
    if expected.is_empty() or expected != _sha256(_canonical_json(payload)):
        return {}
    return envelope


func _sha256(value: String) -> String:
    var context := HashingContext.new()
    if context.start(HashingContext.HASH_SHA256) != OK:
        return ""
    context.update(value.to_utf8_buffer())
    return context.finish().hex_encode()


func _safe_slot(slot_id: StringName) -> String:
    var value := String(slot_id).to_lower().replace(" ", "_")
    var safe := ""
    for character in value:
        var code := character.to_ascii_buffer()[0]
        if code in range(48, 58) or code in range(97, 123) or character == "_" or character == "-":
            safe += character
    return safe if not safe.is_empty() else String(DEFAULT_SIDECAR_SLOT)


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
