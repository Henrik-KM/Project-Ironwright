class_name ReleaseTransactionalSaveService3D
extends Node

signal save_completed(slot_id: StringName, path: String)
signal save_failed(slot_id: StringName, reason: String)
signal load_completed(slot_id: StringName, source_path: String, recovered_backup: bool)
signal load_failed(slot_id: StringName, report: Dictionary)
signal migration_completed(slot_id: StringName, legacy_sources: Array[String])
signal schema_migrated(slot_id: StringName, from_version: int, to_version: int, fields: Array[String])

const CURRENT_SCHEMA_VERSION: int = 4
const DEFAULT_BACKUP_COUNT: int = 3
const DEFAULT_SAVE_ROOT: String = "user://saves"

var save_root: String = DEFAULT_SAVE_ROOT
var backup_count: int = DEFAULT_BACKUP_COUNT
var build_id: String = "ironwright_1_0_rc1"
var last_error: String = ""
var last_load_report: Dictionary = {}


func _ready() -> void:
    add_to_group(&"transactional_save_service")
    _ensure_directory()


func configure(next_save_root: String = DEFAULT_SAVE_ROOT, next_backup_count: int = DEFAULT_BACKUP_COUNT) -> void:
    save_root = next_save_root.trim_suffix("/")
    backup_count = clampi(next_backup_count, 1, 8)
    _ensure_directory()


func save_snapshot(slot_id: StringName, payload: Dictionary, metadata: Dictionary = {}) -> bool:
    last_error = ""
    _ensure_directory()
    var payload_copy := payload.duplicate(true)
    var payload_json := _canonical_json(payload_copy)
    var envelope := {
        "schema_version": CURRENT_SCHEMA_VERSION,
        "build_id": build_id,
        "saved_at_unix": int(Time.get_unix_time_from_system()),
        "slot_id": String(slot_id),
        "checksum_sha256": _sha256(payload_json),
        "metadata": metadata.duplicate(true),
        "payload": payload_copy,
    }
    var serialized := JSON.stringify(envelope)
    var temp_path := _temp_path(slot_id)
    var file := FileAccess.open(temp_path, FileAccess.WRITE)
    if file == null:
        return _fail_save(slot_id, "Could not open temporary save file")
    file.store_string(serialized)
    file.flush()
    file.close()

    var verification := _read_and_validate(temp_path)
    if verification.is_empty():
        DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
        return _fail_save(slot_id, "Temporary save failed checksum validation")

    _rotate_backups(slot_id)
    var current_path := _current_path(slot_id)
    if FileAccess.file_exists(current_path):
        var backup_one := _backup_path(slot_id, 1)
        if FileAccess.file_exists(backup_one):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_one))
        var backup_result := DirAccess.rename_absolute(ProjectSettings.globalize_path(current_path), ProjectSettings.globalize_path(backup_one))
        if backup_result != OK:
            DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))
            return _fail_save(slot_id, "Could not preserve the previous verified save")

    var commit_result := DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(current_path))
    if commit_result != OK:
        if FileAccess.file_exists(_backup_path(slot_id, 1)):
            DirAccess.rename_absolute(ProjectSettings.globalize_path(_backup_path(slot_id, 1)), ProjectSettings.globalize_path(current_path))
        return _fail_save(slot_id, "Could not atomically commit the new save")

    save_completed.emit(slot_id, current_path)
    return true


func load_snapshot(slot_id: StringName) -> Dictionary:
    last_error = ""
    var report := {
        "slot_id": String(slot_id),
        "outcome": "failed",
        "selected_path": "",
        "selected_source": "",
        "recovered_backup": false,
        "schema_migrated": false,
        "attempts": [],
        "error": "",
    }
    var candidates: Array[String] = [_current_path(slot_id)]
    for index in range(1, backup_count + 1):
        candidates.append(_backup_path(slot_id, index))
    for index in range(candidates.size()):
        var path := candidates[index]
        var attempt := {
            "path": path,
            "source": "current" if index == 0 else "backup_%d" % index,
            "status": "missing",
        }
        if not FileAccess.file_exists(path):
            _append_load_attempt(report, attempt)
            continue
        var envelope := _read_and_validate(path)
        if envelope.is_empty():
            attempt["status"] = "invalid"
            _append_load_attempt(report, attempt)
            continue
        var from_version := int(envelope.get("schema_version", CURRENT_SCHEMA_VERSION))
        var migration := _migrate_versioned_envelope(envelope)
        if migration.is_empty():
            attempt["status"] = "migration_failed"
            _append_load_attempt(report, attempt)
            last_error = "Save schema migration failed for %s" % path
            continue
        if from_version < CURRENT_SCHEMA_VERSION:
            var migrated_payload := migration.get("payload", {}) as Dictionary
            var migrated_metadata := migration.get("metadata", {}) as Dictionary
            if not save_snapshot(slot_id, migrated_payload, migrated_metadata):
                attempt["status"] = "migration_persist_failed"
                _append_load_attempt(report, attempt)
                last_error = "Could not persist migrated save schema for %s" % path
                continue
            var fields := migration.get("migration_fields", []) as Array[String]
            schema_migrated.emit(slot_id, from_version, CURRENT_SCHEMA_VERSION, fields.duplicate())
            report["schema_migrated"] = true
            envelope = _read_and_validate(_current_path(slot_id))
            if envelope.is_empty():
                attempt["status"] = "migration_verify_failed"
                _append_load_attempt(report, attempt)
                last_error = "Migrated save failed post-write validation"
                continue
        var payload: Variant = envelope.get("payload", {})
        if payload is Dictionary:
            attempt["status"] = "loaded"
            _append_load_attempt(report, attempt)
            report["outcome"] = "recovered_backup" if index > 0 else ("migrated" if bool(report.get("schema_migrated", false)) else "loaded")
            report["selected_path"] = path
            report["selected_source"] = attempt["source"]
            report["recovered_backup"] = index > 0
            report["error"] = ""
            last_load_report = report.duplicate(true)
            load_completed.emit(slot_id, path, index > 0)
            return (payload as Dictionary).duplicate(true)
    last_error = "No valid current save or rotating backup was found"
    report["error"] = last_error
    last_load_report = report.duplicate(true)
    load_failed.emit(slot_id, last_load_report.duplicate(true))
    return {}


func has_valid_save(slot_id: StringName) -> bool:
    if not _read_and_validate(_current_path(slot_id)).is_empty():
        return true
    for index in range(1, backup_count + 1):
        if not _read_and_validate(_backup_path(slot_id, index)).is_empty():
            return true
    return false


func delete_slot(slot_id: StringName) -> void:
    var paths: Array[String] = [_current_path(slot_id), _temp_path(slot_id)]
    for index in range(1, backup_count + 1):
        paths.append(_backup_path(slot_id, index))
    for path in paths:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func migrate_legacy_payload(
        slot_id: StringName,
        legacy_payload: Dictionary,
        legacy_sources: Array[String]
    ) -> bool:
    if legacy_payload.is_empty():
        return false
    var metadata := {
        "migrated_from_legacy": true,
        "legacy_sources": legacy_sources.duplicate(),
    }
    if not save_snapshot(slot_id, legacy_payload, metadata):
        return false
    migration_completed.emit(slot_id, legacy_sources.duplicate())
    return true


func inspect_slot(slot_id: StringName) -> Dictionary:
    var envelope := _read_and_validate(_current_path(slot_id))
    if envelope.is_empty():
        for index in range(1, backup_count + 1):
            envelope = _read_and_validate(_backup_path(slot_id, index))
            if not envelope.is_empty():
                envelope["using_backup"] = true
                envelope["backup_index"] = index
                break
    if envelope.is_empty():
        return {}
    envelope.erase("payload")
    return envelope


func get_last_load_report() -> Dictionary:
    return last_load_report.duplicate(true)


func corrupt_current_for_test(slot_id: StringName) -> bool:
    var file := FileAccess.open(_current_path(slot_id), FileAccess.WRITE)
    if file == null:
        return false
    file.store_string("{corrupt")
    file.close()
    return true


func _rotate_backups(slot_id: StringName) -> void:
    var oldest := _backup_path(slot_id, backup_count)
    if FileAccess.file_exists(oldest):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(oldest))
    for index in range(backup_count - 1, 0, -1):
        var source := _backup_path(slot_id, index)
        var destination := _backup_path(slot_id, index + 1)
        if not FileAccess.file_exists(source):
            continue
        if FileAccess.file_exists(destination):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(destination))
        DirAccess.rename_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(destination))


func _read_and_validate(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}
    var parser := JSON.new()
    if parser.parse(file.get_as_text()) != OK:
        return {}
    var parsed: Variant = parser.data
    if not (parsed is Dictionary):
        return {}
    var envelope := parsed as Dictionary
    var schema := int(envelope.get("schema_version", 0))
    if schema <= 0 or schema > CURRENT_SCHEMA_VERSION:
        return {}
    var payload: Variant = envelope.get("payload", null)
    if not (payload is Dictionary):
        return {}
    var expected := str(envelope.get("checksum_sha256", ""))
    var actual := _sha256(_canonical_json(payload))
    if expected.is_empty() or expected != actual:
        return {}
    return envelope.duplicate(true)


func _append_load_attempt(report: Dictionary, attempt: Dictionary) -> void:
    var attempts: Array = report.get("attempts", [])
    attempts.append(attempt.duplicate(true))
    report["attempts"] = attempts


func _migrate_versioned_envelope(envelope: Dictionary) -> Dictionary:
    var from_version := int(envelope.get("schema_version", 0))
    if from_version <= 0 or from_version > CURRENT_SCHEMA_VERSION:
        return {}
    var raw_payload: Variant = envelope.get("payload", null)
    if not (raw_payload is Dictionary):
        return {}
    var payload := (raw_payload as Dictionary).duplicate(true)
    var fields: Array[String] = []
    if not payload.has("base"):
        var legacy_base := _extract_legacy_base(payload)
        payload["base"] = legacy_base
        fields.append("base")
    for domain in ["foundation", "complete", "release"]:
        if not payload.has(domain) or not (payload.get(domain) is Dictionary):
            payload[domain] = {}
            fields.append(domain)
    if not payload.has("schema_version") or int(payload.get("schema_version", 0)) < CURRENT_SCHEMA_VERSION:
        payload["schema_version"] = CURRENT_SCHEMA_VERSION
        fields.append("payload.schema_version")
    var metadata: Dictionary = envelope.get("metadata", {}).duplicate(true) if envelope.get("metadata", {}) is Dictionary else {}
    if from_version < CURRENT_SCHEMA_VERSION:
        metadata["schema_migration"] = {
            "from_version": from_version,
            "to_version": CURRENT_SCHEMA_VERSION,
            "fields": fields.duplicate(),
        }
    return {
        "payload": payload,
        "metadata": metadata,
        "migration_fields": fields,
    }


func _extract_legacy_base(payload: Dictionary) -> Dictionary:
    var base: Dictionary = {}
    for key in ["run_state", "player", "heartforge", "robots", "salvage", "enemies", "ecology", "autonomy"]:
        if payload.has(key):
            base[key] = payload[key]
    return base


func _canonical_json(value: Variant) -> String:
    if value is Dictionary:
        var source := value as Dictionary
        var keys: Array[String] = []
        for key in source.keys():
            keys.append(str(key))
        keys.sort()
        var pairs: Array[String] = []
        for key in keys:
            pairs.append("%s:%s" % [JSON.stringify(key), _canonical_json(source.get(key))])
        return "{%s}" % ",".join(pairs)
    if value is Array:
        var items: Array[String] = []
        for item in value:
            items.append(_canonical_json(item))
        return "[%s]" % ",".join(items)
    if value is float:
        var number := float(value)
        if is_finite(number) and is_equal_approx(number, round(number)):
            return str(int(number))
    return JSON.stringify(value)


func _sha256(value: String) -> String:
    var context := HashingContext.new()
    if context.start(HashingContext.HASH_SHA256) != OK:
        return ""
    context.update(value.to_utf8_buffer())
    return context.finish().hex_encode()


func _ensure_directory() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_root))


func _current_path(slot_id: StringName) -> String:
    return "%s/%s.json" % [save_root, _safe_slot(slot_id)]


func _temp_path(slot_id: StringName) -> String:
    return "%s/%s.tmp" % [save_root, _safe_slot(slot_id)]


func _backup_path(slot_id: StringName, index: int) -> String:
    return "%s/%s.backup_%d.json" % [save_root, _safe_slot(slot_id), index]


func _safe_slot(slot_id: StringName) -> String:
    var value := String(slot_id).to_lower().replace(" ", "_")
    var safe := ""
    for character in value:
        if character.to_ascii_buffer()[0] in range(48, 58) or character.to_ascii_buffer()[0] in range(97, 123) or character == "_" or character == "-":
            safe += character
    return safe if not safe.is_empty() else "slot_0"


func _fail_save(slot_id: StringName, reason: String) -> bool:
    last_error = reason
    save_failed.emit(slot_id, reason)
    return false
