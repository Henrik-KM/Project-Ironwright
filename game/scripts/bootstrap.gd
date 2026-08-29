extends Control

const PROTOTYPE_SCOPE_PATH := "res://data/prototype_scope.json"
const RELEASE_SCENE_PATH := "res://scenes/main_3d.tscn"

@onready var status_label: Label = %StatusLabel


func _ready() -> void:
    status_label.text = "Verifying the persistent Heartforge world…"
    var scope := _read_json(PROTOTYPE_SCOPE_PATH)
    if scope.is_empty():
        status_label.text = "The world contract could not be loaded. Run repository validation."
        push_error("Unable to load %s" % PROTOTYPE_SCOPE_PATH)
        return

    var milestone_name := str(scope.get("display_name", "Unknown milestone"))
    var status := str(scope.get("status", "unknown"))
    var experience := str(scope.get("player_experience", "No experience statement found."))
    var required_systems: Array = scope.get("required_systems", [])

    status_label.text = (
        "World contract: %s\n"
        + "Status: %s\n\n"
        + "%s\n\n"
        + "Starting the full Heartforge district (%d systems)…"
    ) % [milestone_name, status, experience, required_systems.size()]
    call_deferred("_enter_release_world")


func _enter_release_world() -> void:
    var error := get_tree().change_scene_to_file(RELEASE_SCENE_PATH)
    if error != OK:
        status_label.text = "The full Heartforge world could not be started. Run repository validation."
        push_error("Unable to load %s: %s" % [RELEASE_SCENE_PATH, error])


func _read_json(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {}

    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return {}

    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if parsed is Dictionary:
        return parsed

    return {}
