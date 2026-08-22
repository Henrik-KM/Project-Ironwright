class_name ReleaseSessionDiagnostics3D
extends Node

## Bounded local session diagnostics for crash and unclean-shutdown recovery.
## This never sends telemetry and never adds a player-facing management task.

const SCHEMA_VERSION := 1
const MAX_EVENTS := 64
const DEFAULT_REPORT_PATH := "user://ironwright_diagnostics/session.json"

var build_id: String = ""
var report_path: String = DEFAULT_REPORT_PATH
var active_session_id: String = ""
var previous_session: Dictionary = {}
var unclean_previous_session: bool = false
var session_state: StringName = &"idle"
var events: Array[Dictionary] = []


func configure(next_build_id: String, next_report_path: String = "") -> void:
    build_id = next_build_id
    if not next_report_path.is_empty():
        report_path = next_report_path
    previous_session = _read_report()
    unclean_previous_session = str(previous_session.get("state", "")) == "started"
    active_session_id = "%d-%d" % [int(Time.get_unix_time_from_system()), Time.get_ticks_msec()]
    session_state = &"started"
    events.clear()
    record_event(
        &"session_started",
        "Release session started.",
        {"unclean_previous_session": unclean_previous_session}
    )


func record_event(kind: StringName, detail: String, metadata: Dictionary = {}) -> void:
    if session_state == &"idle":
        return
    events.append({
        "time": Time.get_datetime_string_from_system(true),
        "kind": String(kind),
        "detail": detail,
        "metadata": metadata.duplicate(true),
    })
    while events.size() > MAX_EVENTS:
        events.pop_front()
    _write_report()


func mark_clean_shutdown(reason: String = "normal_exit") -> void:
    if session_state != &"started":
        return
    session_state = &"clean"
    record_event(&"session_closed", "Release session closed cleanly.", {"reason": reason})


func has_unclean_previous_session() -> bool:
    return unclean_previous_session


func to_dictionary() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "state": String(session_state),
        "build_id": build_id,
        "active_session_id": active_session_id,
        "unclean_previous_session": unclean_previous_session,
        "previous_session_id": str(previous_session.get("active_session_id", "")),
        "engine_version": str(Engine.get_version_info().get("string", "")),
        "platform": OS.get_name(),
        "events": events.duplicate(true),
    }


func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        mark_clean_shutdown("window_close_request")


func _read_report() -> Dictionary:
    if not FileAccess.file_exists(report_path):
        return {}
    var file := FileAccess.open(report_path, FileAccess.READ)
    if file == null:
        return {}
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    return parsed as Dictionary if parsed is Dictionary else {}


func _write_report() -> void:
    var directory := report_path.get_base_dir()
    var directory_error := DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
    if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
        return
    var temporary_path := report_path + ".tmp"
    var backup_path := report_path + ".bak"
    var file := FileAccess.open(temporary_path, FileAccess.WRITE)
    if file == null:
        return
    file.store_string(JSON.stringify(to_dictionary()))
    file.close()
    if FileAccess.file_exists(backup_path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(backup_path))
    if FileAccess.file_exists(report_path):
        if DirAccess.rename_absolute(ProjectSettings.globalize_path(report_path), ProjectSettings.globalize_path(backup_path)) != OK:
            return
    if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary_path), ProjectSettings.globalize_path(report_path)) != OK:
        if FileAccess.file_exists(backup_path):
            DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_path), ProjectSettings.globalize_path(report_path))
