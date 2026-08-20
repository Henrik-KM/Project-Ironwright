class_name TransactionalSaveService3D
extends Node

signal save_completed(slot_id: StringName, path: String)
signal save_failed(slot_id: StringName, reason: String)
signal load_completed(slot_id: StringName, source_path: String, recovered_backup: bool)
signal migration_completed(slot_id: StringName, legacy_sources: Array[String])

const CURRENT_SCHEMA_VERSION: int = 4
const DEFAULT_BACKUP_COUNT: int = 3
const DEFAULT_SAVE_ROOT: String = "user://saves"

var save_root: String = DEFAULT_SAVE_ROOT
var backup_count: int = DEFAULT_BACKUP_COUNT
var build_id: String = "ironwright_1_0_rc1"
var last_error: String = ""


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
    var payload_json := JSON.stringify(payload_copy)
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
    var candidates: Array[String] = [_current_path(slot_id)]
    for index in range(1, backup_count + 1):
        candidates.append(_backup_path(slot_id, index))
    for index in range(candidates.size()):
        var path := candidates[index]
        if not FileAccess.file_exists(path):
            continue
        var envelope := _read_and_validate(path)
        if envelope.is_empty():
            continue
        var payload: Variant = envelope.get("payload", {})
        if payload is Dictionary:
            load_completed.emit(slot_id, path, index > 0)
            return (payload as Dictionary).duplicate(true)
    last_error = "No valid current save or rotating backup was found"
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
    var parsed: Variant = JSON.parse_string(file.get_as_text())
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
    var actual := _sha256(JSON.stringify(payload))
    if expected.is_empty() or expected != actual:
        return {}
    return envelope.duplicate(true)


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
