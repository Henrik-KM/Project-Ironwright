extends Control

const PROTOTYPE_SCOPE_PATH := "res://data/prototype_scope.json"

@onready var status_label: Label = %StatusLabel


func _ready() -> void:
    var scope := _read_json(PROTOTYPE_SCOPE_PATH)
    if scope.is_empty():
        status_label.text = "Prototype scope could not be loaded. Run repository validation."
        push_error("Unable to load %s" % PROTOTYPE_SCOPE_PATH)
        return

    var milestone_name := str(scope.get("display_name", "Unknown milestone"))
    var status := str(scope.get("status", "unknown"))
    var experience := str(scope.get("player_experience", "No experience statement found."))
    var required_systems: Array = scope.get("required_systems", [])

    status_label.text = (
        "Next milestone: %s\n"
        + "Status: %s\n\n"
        + "%s\n\n"
        + "Required prototype systems: %d"
    ) % [milestone_name, status, experience, required_systems.size()]


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
