class_name TransactionalSaveService3D
extends RefCounted

## Run-level persistence service.
##
## A save is written to a temporary file, promoted atomically, and rotated
## through two bounded backups. Older two-file saves are read and wrapped into
## the current envelope without weakening validation of the live state.

const CURRENT_SCHEMA_VERSION: int = 2
const SAVE_FORMAT := "project_ironwright_run"

var primary_path: String = "user://ironwright_run.json"
var backup_one_path: String = "user://ironwright_run.json.bak1"
var backup_two_path: String = "user://ironwright_run.json.bak2"
var legacy_foundation_path: String = "user://ironwright_first_light_3d.json"
var legacy_extension_path: String = "user://ironwright_full_game_extension.json"
var last_error: String = ""
var last_source_path: String = ""


func configure(
        next_primary_path: String = "",
        next_legacy_foundation_path: String = "",
        next_legacy_extension_path: String = ""
    ) -> void:
    if next_primary_path != "":
        primary_path = next_primary_path
    backup_one_path = primary_path + ".bak1"
    backup_two_path = primary_path + ".bak2"
    if next_legacy_foundation_path != "":
        legacy_foundation_path = next_legacy_foundation_path
    if next_legacy_extension_path != "":
        legacy_extension_path = next_legacy_extension_path


func write_snapshot(snapshot: Dictionary) -> bool:
    last_error = ""
    var envelope := snapshot.duplicate(true)
    envelope["schema_version"] = CURRENT_SCHEMA_VERSION
    envelope["format"] = SAVE_FORMAT
    if not envelope.has("foundation") or not (envelope.get("foundation") is Dictionary):
        last_error = "Save envelope is missing its foundation dictionary."
        return false
    if not envelope.has("extensions") or not (envelope.get("extensions") is Dictionary):
        envelope["extensions"] = {}

    var serialized := JSON.stringify(envelope)
    var temporary_path := primary_path + ".tmp"
    var file := FileAccess.open(temporary_path, FileAccess.WRITE)
    if file == null:
        last_error = "Could not open temporary save file."
        return false
    file.store_string(serialized)
    file.flush()
    file.close()

    if FileAccess.file_exists(primary_path):
        if not _rotate_existing_backups():
            _remove_if_exists(temporary_path)
            return false
        var move_primary_error := DirAccess.rename_absolute(primary_path, backup_one_path)
        if move_primary_error != OK:
            last_error = "Could not move the previous save into backup 1 (%s)." % move_primary_error
            _remove_if_exists(temporary_path)
            return false

    var promote_error := DirAccess.rename_absolute(temporary_path, primary_path)
    if promote_error != OK:
        last_error = "Could not promote the temporary save (%s)." % promote_error
        # Restore the previous primary when promotion fails after rotation.
        if not FileAccess.file_exists(primary_path) and FileAccess.file_exists(backup_one_path):
            DirAccess.rename_absolute(backup_one_path, primary_path)
        _remove_if_exists(temporary_path)
        return false
    return true


func read_snapshot() -> Dictionary:
    last_error = ""
    last_source_path = ""
    for candidate_path in [primary_path, backup_one_path, backup_two_path]:
        var candidate := _read_dictionary(candidate_path)
        if candidate.is_empty():
            continue
        var migrated := _migrate_envelope(candidate)
        if not migrated.is_empty():
            last_source_path = candidate_path
            return migrated

    var legacy_foundation := _read_dictionary(legacy_foundation_path)
    if not legacy_foundation.is_empty():
        var migrated_legacy := _migrate_legacy_foundation(legacy_foundation)
        if not migrated_legacy.is_empty():
            last_source_path = legacy_foundation_path
            return migrated_legacy

    if last_error == "":
        last_error = "No valid Project Ironwright save was found."
    return {}


func _rotate_existing_backups() -> bool:
    if FileAccess.file_exists(backup_two_path):
        var remove_error := DirAccess.remove_absolute(backup_two_path)
        if remove_error != OK:
            last_error = "Could not rotate backup 2 (%s)." % remove_error
            return false
    if FileAccess.file_exists(backup_one_path):
        var move_backup_error := DirAccess.rename_absolute(backup_one_path, backup_two_path)
        if move_backup_error != OK:
            last_error = "Could not rotate backup 1 (%s)." % move_backup_error
            return false
    return true


func _read_dictionary(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        last_error = "Could not open save candidate %s." % path
        return {}
    var parser := JSON.new()
    var parse_error := parser.parse(file.get_as_text())
    file.close()
    if parse_error != OK:
        last_error = "Save candidate %s is not valid JSON." % path
        return {}
    var parsed: Variant = parser.data
    if parsed is Dictionary:
        return parsed as Dictionary
    last_error = "Save candidate %s is not a JSON dictionary." % path
    return {}


func _migrate_envelope(candidate: Dictionary) -> Dictionary:
    var schema_version := int(candidate.get("schema_version", 0))
    if schema_version > CURRENT_SCHEMA_VERSION:
        last_error = "Save schema %d is newer than this build." % schema_version
        return {}
    if not candidate.has("foundation") or not (candidate.get("foundation") is Dictionary):
        last_error = "Save envelope has no valid foundation section."
        return {}
    var result := candidate.duplicate(true)
    result["schema_version"] = CURRENT_SCHEMA_VERSION
    result["format"] = SAVE_FORMAT
    if not result.has("extensions") or not (result.get("extensions") is Dictionary):
        result["extensions"] = {}
    return result


func _migrate_legacy_foundation(legacy_foundation: Dictionary) -> Dictionary:
    if not legacy_foundation.has("run_state"):
        last_error = "Legacy foundation save has no run state."
        return {}
    var result := {
        "schema_version": CURRENT_SCHEMA_VERSION,
        "format": SAVE_FORMAT,
        "migrated_from_legacy": true,
        "foundation": legacy_foundation.duplicate(true),
        "extensions": {},
    }
    var legacy_extension := _read_dictionary(legacy_extension_path)
    if not legacy_extension.is_empty():
        (result["extensions"] as Dictionary)["full_game"] = legacy_extension.duplicate(true)
    return result


func _remove_if_exists(path: String) -> void:
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(path)
