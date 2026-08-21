class_name ReleaseSettingsService3D
extends Node

signal settings_changed(settings: Dictionary)
signal input_device_changed(device_kind: StringName)
signal controller_connection_changed(connected: bool, device_id: int)

const DEFAULTS_PATH := "res://data/accessibility_defaults.json"
const SETTINGS_PATH := "user://ironwright_release_settings.json"
const SETTINGS_TEMP_PATH := "user://ironwright_release_settings.tmp"
const SETTINGS_BACKUP_PATH := "user://ironwright_release_settings.backup.json"
const REMAPPABLE_ACTIONS: Array[StringName] = [&"iw_move_up", &"iw_move_down", &"iw_move_left", &"iw_move_right", &"iw_interact"]
const DEFAULT_INPUT_BINDINGS: Dictionary = {
    "iw_move_up": KEY_W,
    "iw_move_down": KEY_S,
    "iw_move_left": KEY_A,
    "iw_move_right": KEY_D,
    "iw_interact": KEY_E,
}

var settings: Dictionary = {}
var defaults: Dictionary = {}
var last_input_device: StringName = &"keyboard_mouse"
var load_errors: Array[String] = []


func _ready() -> void:
    add_to_group(&"release_settings_service")
    _load_defaults()
    _load_settings()
    ensure_input_map()
    apply_input_bindings()
    Input.joy_connection_changed.connect(_on_joy_connection_changed)
    apply_runtime_settings()


func _unhandled_input(event: InputEvent) -> void:
    var next_device := last_input_device
    if event is InputEventJoypadButton or event is InputEventJoypadMotion:
        next_device = &"controller"
    elif event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion:
        next_device = &"keyboard_mouse"
    if next_device != last_input_device:
        last_input_device = next_device
        input_device_changed.emit(last_input_device)


func _load_defaults() -> void:
    load_errors.clear()
    var file := FileAccess.open(DEFAULTS_PATH, FileAccess.READ)
    if file == null:
        load_errors.append("Missing accessibility defaults")
        defaults = _fallback_defaults()
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        load_errors.append("Invalid accessibility defaults")
        defaults = _fallback_defaults()
        return
    var raw: Variant = (parsed as Dictionary).get("defaults", {})
    defaults = (raw as Dictionary).duplicate(true) if raw is Dictionary else _fallback_defaults()


func _load_settings() -> void:
    settings = defaults.duplicate(true)
    if not FileAccess.file_exists(SETTINGS_PATH):
        return
    var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
    if file == null:
        load_errors.append("Settings file could not be opened")
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        load_errors.append("Settings file was invalid; defaults restored")
        return
    var data := parsed as Dictionary
    for raw_key in defaults:
        if data.has(raw_key):
            settings[raw_key] = data[raw_key]
    _sanitize()


func save_settings() -> bool:
    _sanitize()
    var file := FileAccess.open(SETTINGS_TEMP_PATH, FileAccess.WRITE)
    if file == null:
        return false
    file.store_string(JSON.stringify(settings, "  "))
    file.flush()
    file.close()
    if not _validate_settings_file(SETTINGS_TEMP_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_TEMP_PATH))
        return false
    if FileAccess.file_exists(SETTINGS_BACKUP_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_BACKUP_PATH))
    if FileAccess.file_exists(SETTINGS_PATH):
        DirAccess.rename_absolute(ProjectSettings.globalize_path(SETTINGS_PATH), ProjectSettings.globalize_path(SETTINGS_BACKUP_PATH))
    var result := DirAccess.rename_absolute(ProjectSettings.globalize_path(SETTINGS_TEMP_PATH), ProjectSettings.globalize_path(SETTINGS_PATH))
    return result == OK


func _validate_settings_file(path: String) -> bool:
    var file := FileAccess.open(path, FileAccess.READ)
    if file == null:
        return false
    return JSON.parse_string(file.get_as_text()) is Dictionary


func get_value(key: StringName, fallback: Variant = null) -> Variant:
    return settings.get(String(key), settings.get(key, fallback))


func set_value(key: StringName, value: Variant, persist: bool = true) -> void:
    settings[String(key)] = value
    _sanitize()
    apply_runtime_settings()
    if persist:
        save_settings()
    settings_changed.emit(settings.duplicate(true))


func apply_runtime_settings() -> void:
    Engine.max_fps = clampi(int(get_value(&"target_fps", 60)), 30, 240)
    Engine.time_scale = clampf(float(get_value(&"game_speed", 1.0)), 0.75, 1.25)
    _ensure_audio_buses()
    _set_bus_linear("Master", float(get_value(&"master_volume", 0.88)))
    _set_bus_linear("Music", float(get_value(&"music_volume", 0.68)))
    _set_bus_linear("Ambience", float(get_value(&"ambience_volume", 0.78)))
    _set_bus_linear("Effects", float(get_value(&"effects_volume", 0.86)))


func apply_input_bindings() -> void:
    for action in REMAPPABLE_ACTIONS:
        if not InputMap.has_action(action):
            continue
        for existing in InputMap.action_get_events(action):
            if existing is InputEventKey:
                InputMap.action_erase_event(action, existing)
        var event := InputEventKey.new()
        event.keycode = get_key_binding(action)
        event.physical_keycode = event.keycode
        InputMap.action_add_event(action, event)


func get_key_binding(action: StringName) -> Key:
    var bindings: Variant = settings.get("input_bindings", {})
    if bindings is Dictionary and bindings.has(String(action)):
        return int(bindings[String(action)]) as Key
    return int(DEFAULT_INPUT_BINDINGS.get(String(action), KEY_NONE)) as Key


func set_key_binding(action: StringName, keycode: Key, persist: bool = true) -> bool:
    if action not in REMAPPABLE_ACTIONS or keycode == KEY_NONE:
        return false
    var bindings: Dictionary = settings.get("input_bindings", {}).duplicate(true)
    for other_action in REMAPPABLE_ACTIONS:
        if other_action != action and int(bindings.get(String(other_action), DEFAULT_INPUT_BINDINGS.get(String(other_action), KEY_NONE))) == int(keycode):
            bindings[String(other_action)] = int(get_key_binding(action))
    bindings[String(action)] = int(keycode)
    settings["input_bindings"] = bindings
    apply_input_bindings()
    if persist:
        save_settings()
    settings_changed.emit(settings.duplicate(true))
    return true


func key_binding_display_name(action: StringName) -> String:
    return OS.get_keycode_string(int(get_key_binding(action)))


func apply_accessibility_to_tree(root: Node) -> void:
    if root == null:
        return
    var text_scale := clampf(float(get_value(&"text_scale", 1.0)), 0.75, 1.6)
    var high_contrast := bool(get_value(&"high_contrast_ui", false))
    _apply_accessibility_recursive(root, text_scale, high_contrast)


func _apply_accessibility_recursive(node: Node, text_scale: float, high_contrast: bool) -> void:
    if node is Control:
        var control := node as Control
        if control is Label or control is Button or control is OptionButton or control is CheckButton:
            var base_size := 16
            if control.has_meta(&"ironwright_base_font_size"):
                base_size = int(control.get_meta(&"ironwright_base_font_size"))
            else:
                var current := control.get_theme_font_size("font_size")
                base_size = current if current > 0 else 16
                control.set_meta(&"ironwright_base_font_size", base_size)
            control.add_theme_font_size_override("font_size", maxi(11, int(round(float(base_size) * text_scale))))
            if high_contrast:
                control.add_theme_color_override("font_color", Color("ffffff"))
                control.add_theme_color_override("font_outline_color", Color("000000"))
                control.add_theme_constant_override("outline_size", maxi(4, int(round(4.0 * text_scale))))
    for child in node.get_children():
        _apply_accessibility_recursive(child, text_scale, high_contrast)


func ensure_input_map() -> void:
    _ensure_action(&"iw_move_left")
    _ensure_action(&"iw_move_right")
    _ensure_action(&"iw_move_up")
    _ensure_action(&"iw_move_down")
    _ensure_action(&"iw_interact")
    _ensure_action(&"iw_cancel")
    _ensure_action(&"iw_follow")
    _ensure_action(&"iw_map")
    _ensure_action(&"iw_pause")
    _ensure_action(&"iw_evolution")
    _ensure_action(&"iw_outposts")
    _ensure_action(&"iw_operations")
    _ensure_action(&"iw_endgame")
    _ensure_action(&"iw_focus_defend")
    _ensure_action(&"iw_focus_salvage")
    _ensure_action(&"iw_focus_expedition")

    _add_axis_once(&"iw_move_left", JOY_AXIS_LEFT_X, -1.0)
    _add_axis_once(&"iw_move_right", JOY_AXIS_LEFT_X, 1.0)
    _add_axis_once(&"iw_move_up", JOY_AXIS_LEFT_Y, -1.0)
    _add_axis_once(&"iw_move_down", JOY_AXIS_LEFT_Y, 1.0)
    _add_button_once(&"iw_move_left", JOY_BUTTON_DPAD_LEFT)
    _add_button_once(&"iw_move_right", JOY_BUTTON_DPAD_RIGHT)
    _add_button_once(&"iw_move_up", JOY_BUTTON_DPAD_UP)
    _add_button_once(&"iw_move_down", JOY_BUTTON_DPAD_DOWN)
    _add_button_once(&"iw_interact", JOY_BUTTON_A)
    _add_button_once(&"iw_cancel", JOY_BUTTON_B)
    _add_button_once(&"iw_follow", JOY_BUTTON_X)
    _add_button_once(&"iw_map", JOY_BUTTON_Y)
    _add_button_once(&"iw_pause", JOY_BUTTON_START)
    _add_button_once(&"iw_evolution", JOY_BUTTON_LEFT_SHOULDER)
    _add_button_once(&"iw_outposts", JOY_BUTTON_RIGHT_SHOULDER)
    _add_axis_once(&"iw_operations", JOY_AXIS_TRIGGER_LEFT, 1.0)
    _add_axis_once(&"iw_endgame", JOY_AXIS_TRIGGER_RIGHT, 1.0)
    _add_button_once(&"iw_focus_defend", JOY_BUTTON_DPAD_UP)
    _add_button_once(&"iw_focus_salvage", JOY_BUTTON_DPAD_LEFT)
    _add_button_once(&"iw_focus_expedition", JOY_BUTTON_DPAD_RIGHT)


func _ensure_action(action: StringName) -> void:
    if not InputMap.has_action(action):
        InputMap.add_action(action, 0.22)


func _add_button_once(action: StringName, button_index: int) -> void:
    for existing in InputMap.action_get_events(action):
        if existing is InputEventJoypadButton and (existing as InputEventJoypadButton).button_index == button_index:
            return
    var event := InputEventJoypadButton.new()
    event.button_index = button_index
    InputMap.action_add_event(action, event)


func _add_axis_once(action: StringName, axis: int, value: float) -> void:
    for existing in InputMap.action_get_events(action):
        if existing is InputEventJoypadMotion:
            var motion := existing as InputEventJoypadMotion
            if motion.axis == axis and is_equal_approx(signf(motion.axis_value), signf(value)):
                return
    var event := InputEventJoypadMotion.new()
    event.axis = axis
    event.axis_value = value
    InputMap.action_add_event(action, event)


func _ensure_audio_buses() -> void:
    _ensure_bus("Music")
    _ensure_bus("Ambience")
    _ensure_bus("Effects")


func _ensure_bus(bus_name: String) -> void:
    if AudioServer.get_bus_index(bus_name) >= 0:
        return
    AudioServer.add_bus()
    AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _set_bus_linear(bus_name: String, value: float) -> void:
    var index := AudioServer.get_bus_index(bus_name)
    if index < 0:
        return
    var clamped := clampf(value, 0.0, 1.0)
    AudioServer.set_bus_mute(index, clamped <= 0.0001)
    AudioServer.set_bus_volume_db(index, -80.0 if clamped <= 0.0001 else linear_to_db(clamped))


func _sanitize() -> void:
    settings["language"] = str(settings.get("language", "en"))
    settings["difficulty"] = str(settings.get("difficulty", "survival"))
    for key in ["master_volume", "music_volume", "ambience_volume", "effects_volume"]:
        settings[key] = clampf(float(settings.get(key, defaults.get(key, 0.8))), 0.0, 1.0)
    settings["text_scale"] = clampf(float(settings.get("text_scale", 1.0)), 0.85, 1.4)
    settings["camera_shake"] = clampf(float(settings.get("camera_shake", 0.65)), 0.0, 1.0)
    settings["target_fps"] = clampi(int(settings.get("target_fps", 60)), 30, 120)
    settings["game_speed"] = clampf(float(settings.get("game_speed", defaults.get("game_speed", 1.0))), 0.75, 1.25)
    for key in ["high_contrast_ui", "reduced_motion", "reduced_flashes", "hold_interactions", "controller_vibration", "subtitles", "show_world_guidance"]:
        settings[key] = bool(settings.get(key, defaults.get(key, false)))
    settings["colorblind_mode"] = str(settings.get("colorblind_mode", "off"))
    var input_bindings: Dictionary = settings.get("input_bindings", {}).duplicate(true)
    for action in REMAPPABLE_ACTIONS:
        var keycode := int(input_bindings.get(String(action), DEFAULT_INPUT_BINDINGS.get(String(action), KEY_NONE)))
        input_bindings[String(action)] = keycode if keycode > 0 else int(DEFAULT_INPUT_BINDINGS.get(String(action), KEY_NONE))
    settings["input_bindings"] = input_bindings


func _fallback_defaults() -> Dictionary:
    return {
        "language": "en",
        "difficulty": "survival",
        "master_volume": 0.88,
        "music_volume": 0.68,
        "ambience_volume": 0.78,
        "effects_volume": 0.86,
        "text_scale": 1.0,
        "high_contrast_ui": false,
        "colorblind_mode": "off",
        "reduced_motion": false,
        "reduced_flashes": false,
        "camera_shake": 0.65,
        "hold_interactions": true,
        "controller_vibration": true,
        "subtitles": true,
        "show_world_guidance": true,
        "target_fps": 60,
        "game_speed": 1.0,
        "input_bindings": {
            "iw_move_up": KEY_W,
            "iw_move_down": KEY_S,
            "iw_move_left": KEY_A,
            "iw_move_right": KEY_D,
            "iw_interact": KEY_E,
        },
    }


func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
    controller_connection_changed.emit(connected, device_id)
