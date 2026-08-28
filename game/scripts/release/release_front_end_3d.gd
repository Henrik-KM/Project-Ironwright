class_name ReleaseFrontEnd3D
extends CanvasLayer

signal new_world_requested
signal continue_requested
signal resume_requested
signal save_requested
signal load_requested
signal return_title_requested
signal quit_requested
signal settings_applied(settings: Dictionary)
signal presentation_review_requested

var localization: LocalizationService3D
var settings_service: ReleaseSettingsService3D
var backdrop: ColorRect
var title_atmosphere: ColorRect
var title_panel: PanelContainer
var pause_panel: PanelContainer
var settings_panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var pause_subtitle_label: Label
var version_label: Label
var continue_button: Button
var new_world_button: Button
var no_save_label: Label
var settings_title: Label
var settings_controls: Dictionary = {}
var remap_buttons: Dictionary = {}
var controller_remap_buttons: Dictionary = {}
var active_screen: StringName = &"hidden"
var last_focus: Control
var remap_capture_action: StringName = &""


func configure(next_localization: LocalizationService3D, next_settings: ReleaseSettingsService3D) -> void:
    localization = next_localization
    settings_service = next_settings


func _ready() -> void:
    layer = 80
    process_mode = Node.PROCESS_MODE_ALWAYS
    add_to_group(&"release_front_end")
    _build_ui()
    if localization != null:
        localization.locale_changed.connect(_on_locale_changed)
    if settings_service != null:
        settings_service.settings_changed.connect(_on_settings_changed)
    _refresh_text()
    hide_all()


func _unhandled_input(event: InputEvent) -> void:
    if not visible or not (event is InputEventKey or event is InputEventJoypadButton):
        return
    if active_screen == &"title" and event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo and ((event as InputEventKey).keycode == KEY_F10 or (event as InputEventKey).physical_keycode == KEY_F10):
        presentation_review_requested.emit()
        get_viewport().set_input_as_handled()
        return
    if active_screen == &"settings" and remap_capture_action != &"":
        if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
            var key_event := event as InputEventKey
            if key_event.keycode == KEY_ESCAPE:
                remap_capture_action = &""
            elif settings_service != null:
                settings_service.set_key_binding(remap_capture_action, key_event.keycode)
                remap_capture_action = &""
            _populate_settings_controls()
            get_viewport().set_input_as_handled()
        elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
            if settings_service != null:
                settings_service.set_controller_binding(remap_capture_action, (event as InputEventJoypadButton).button_index)
            remap_capture_action = &""
            _populate_settings_controls()
            get_viewport().set_input_as_handled()
        return
    if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"iw_cancel"):
        if active_screen == &"settings":
            show_title(false) if last_focus == continue_button else show_pause()
        elif active_screen == &"pause":
            resume_requested.emit()
        get_viewport().set_input_as_handled()


func _build_ui() -> void:
    backdrop = ColorRect.new()
    backdrop.name = "ReleaseBackdrop"
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    # Keep the authored Heartforge scene legible behind the title so the first
    # frame carries the same warm/cool material language as the playable
    # opening. The panel and vignette still protect text contrast.
    backdrop.color = Color(0.008, 0.018, 0.024, 0.48)
    backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(backdrop)

    var vignette := ColorRect.new()
    vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var shader := Shader.new()
    shader.code = """
shader_type canvas_item;
render_mode unshaded;
void fragment() {
    vec2 p = UV * 2.0 - 1.0;
    float d = dot(p, p);
    vec3 cold = vec3(0.026, 0.065, 0.085);
    vec3 warm = vec3(0.25, 0.11, 0.045);
    float hearth = exp(-length(UV - vec2(0.5, 0.77)) * 5.2);
    COLOR = vec4(mix(cold, warm, hearth), smoothstep(0.15, 1.5, d) * 0.62 + 0.18);
}
"""
    var vignette_material := ShaderMaterial.new()
    vignette_material.shader = shader
    vignette.material = vignette_material
    backdrop.add_child(vignette)

    title_atmosphere = ColorRect.new()
    title_atmosphere.name = "TitleAtmosphere"
    title_atmosphere.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    title_atmosphere.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var atmosphere_shader := Shader.new()
    atmosphere_shader.code = """
shader_type canvas_item;
render_mode unshaded;

float ring(float distance_to_ring, float width) {
    return 1.0 - smoothstep(0.0, width, abs(distance_to_ring));
}

void fragment() {
    vec2 p = (UV - vec2(0.5, 0.62)) * vec2(1.0, 1.72);
    float radius = length(p);
    float core = exp(-radius * 10.0);
    float halo = exp(-abs(radius - 0.27) * 18.0);
    float ring_a = ring(radius - 0.40, 0.010);
    float ring_b = ring(radius - 0.57, 0.005);
    float horizon = 1.0 - smoothstep(0.0, 0.18, abs(UV.y - 0.68));
    float service_left = exp(-abs(UV.x - 0.22) * 52.0) * smoothstep(0.18, 0.78, UV.y);
    float service_right = exp(-abs(UV.x - 0.78) * 52.0) * smoothstep(0.18, 0.78, UV.y);
    float scan = 0.5 + 0.5 * sin((UV.y * 180.0) + sin(UV.x * 12.0));
    vec3 color = vec3(0.022, 0.09, 0.11);
    color += vec3(0.95, 0.30, 0.09) * (core * 0.82 + halo * 0.20);
    color += vec3(0.10, 0.62, 0.74) * (ring_a * 0.58 + ring_b * 0.36);
    color += vec3(0.34, 0.16, 0.06) * horizon * 0.36;
    color += vec3(0.06, 0.34, 0.38) * (service_left + service_right) * 0.28;
    float alpha = 0.24 + core * 0.28 + halo * 0.12 + (ring_a + ring_b) * 0.18 + horizon * 0.12 + (service_left + service_right) * 0.05;
    alpha *= 0.88 + scan * 0.12;
    COLOR = vec4(color, alpha);
}
"""
    var atmosphere_material := ShaderMaterial.new()
    atmosphere_material.shader = atmosphere_shader
    title_atmosphere.material = atmosphere_material
    backdrop.add_child(title_atmosphere)

    var viewport_height := get_viewport().get_visible_rect().size.y
    var title_height := 560.0 if viewport_height <= 0.0 else minf(560.0, maxf(440.0, viewport_height - 28.0))
    title_panel = _panel(Vector2(660, title_height))
    var title_box := _vertical_content(title_panel, 10)
    title_label = _heading("PROJECT IRONWRIGHT", 42, Color("f2eadc"))
    title_box.add_child(title_label)
    subtitle_label = _body_label("", 17, Color("b8c7c4"), 48)
    subtitle_label.custom_minimum_size.x = 600.0
    subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_box.add_child(subtitle_label)
    version_label = _body_label("", 13, Color("d4a86b"), 20)
    version_label.custom_minimum_size.x = 600.0
    version_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    version_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_box.add_child(version_label)
    title_box.add_child(HSeparator.new())
    continue_button = _menu_button("CONTINUE", func() -> void: continue_requested.emit())
    title_box.add_child(continue_button)
    new_world_button = _menu_button("NEW WORLD", func() -> void: new_world_requested.emit())
    title_box.add_child(new_world_button)
    title_box.add_child(_menu_button("SETTINGS", show_settings_from_title))
    title_box.add_child(_menu_button("QUIT", func() -> void: quit_requested.emit()))
    no_save_label = _body_label("", 13, Color("b96d63"), 32)
    no_save_label.custom_minimum_size.x = 600.0
    no_save_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    no_save_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title_box.add_child(no_save_label)

    pause_panel = _panel(Vector2(560, 570))
    var pause_box := _vertical_content(pause_panel, 13)
    pause_box.add_child(_heading("PROJECT IRONWRIGHT", 31, Color("f2eadc")))
    pause_subtitle_label = _body_label("THE WORLD IS PAUSED", 14, Color("a8bab7"), 30)
    pause_box.add_child(pause_subtitle_label)
    pause_box.add_child(HSeparator.new())
    pause_box.add_child(_menu_button("RESUME", func() -> void: resume_requested.emit()))
    pause_box.add_child(_menu_button("SAVE WORLD", func() -> void: save_requested.emit()))
    pause_box.add_child(_menu_button("LOAD WORLD", func() -> void: load_requested.emit()))
    pause_box.add_child(_menu_button("SETTINGS", show_settings_from_pause))
    pause_box.add_child(_menu_button("RETURN TO TITLE", func() -> void: return_title_requested.emit()))
    pause_box.add_child(_menu_button("QUIT", func() -> void: quit_requested.emit()))

    settings_panel = _panel(Vector2(820, 760))
    var settings_shell := VBoxContainer.new()
    settings_shell.add_theme_constant_override("separation", 10)
    settings_panel.add_child(settings_shell)
    settings_title = _heading("ACCESSIBILITY, CONTROLS & AUDIO", 28, Color("f2eadc"))
    settings_shell.add_child(settings_title)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(0, 610)
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    settings_shell.add_child(scroll)
    var settings_box := VBoxContainer.new()
    settings_box.name = "SettingsRows"
    settings_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    settings_box.add_theme_constant_override("separation", 10)
    scroll.add_child(settings_box)
    _build_settings_rows(settings_box)
    var apply_button := _menu_button("APPLY", _apply_settings)
    settings_shell.add_child(apply_button)
    settings_shell.add_child(_menu_button("BACK", _back_from_settings))


func _build_settings_rows(parent: VBoxContainer) -> void:
    settings_controls.clear()
    remap_buttons.clear()
    controller_remap_buttons.clear()
    var language := OptionButton.new()
    language.name = "LanguageOption"
    if localization != null:
        for locale in localization.available_locales():
            language.add_item(localization.language_name(locale))
            language.set_item_metadata(language.item_count - 1, String(locale))
    settings_controls["language"] = language
    parent.add_child(_settings_row("settings.language", language))

    var difficulty := OptionButton.new()
    difficulty.name = "DifficultyOption"
    for profile_id in ["story", "survival", "brutal"]:
        difficulty.add_item(profile_id.capitalize())
        difficulty.set_item_metadata(difficulty.item_count - 1, profile_id)
    settings_controls["difficulty"] = difficulty
    parent.add_child(_settings_row("settings.difficulty", difficulty))

    for key in ["master_volume", "music_volume", "ambience_volume", "effects_volume"]:
        var slider := HSlider.new()
        slider.min_value = 0.0
        slider.max_value = 1.0
        slider.step = 0.02
        slider.custom_minimum_size = Vector2(270, 36)
        settings_controls[key] = slider
        parent.add_child(_settings_row("settings.%s" % key, slider))

    var text_scale := HSlider.new()
    text_scale.min_value = 0.85
    text_scale.max_value = 1.4
    text_scale.step = 0.05
    text_scale.custom_minimum_size = Vector2(270, 36)
    settings_controls["text_scale"] = text_scale
    parent.add_child(_settings_row("settings.text_scale", text_scale))

    var camera_shake := HSlider.new()
    camera_shake.min_value = 0.0
    camera_shake.max_value = 1.0
    camera_shake.step = 0.05
    camera_shake.custom_minimum_size = Vector2(270, 36)
    settings_controls["camera_shake"] = camera_shake
    parent.add_child(_settings_row("settings.camera_shake", camera_shake))

    var colorblind := OptionButton.new()
    for mode in ["off", "deuteranopia", "protanopia", "tritanopia"]:
        colorblind.add_item(mode.capitalize())
        colorblind.set_item_metadata(colorblind.item_count - 1, mode)
    settings_controls["colorblind_mode"] = colorblind
    parent.add_child(_settings_row("settings.colorblind_mode", colorblind))

    var fps := OptionButton.new()
    for value in [30, 45, 60, 90, 120]:
        fps.add_item("%d FPS" % value)
        fps.set_item_metadata(fps.item_count - 1, value)
    settings_controls["target_fps"] = fps
    parent.add_child(_settings_row("settings.target_fps", fps))

    var game_speed := OptionButton.new()
    for value in [0.75, 1.0, 1.25]:
        game_speed.add_item("%.2fx" % value)
        game_speed.set_item_metadata(game_speed.item_count - 1, value)
    settings_controls["game_speed"] = game_speed
    parent.add_child(_settings_row("settings.game_speed", game_speed))

    for key in ["high_contrast_ui", "reduced_motion", "reduced_flashes", "hold_interactions", "controller_vibration", "subtitles", "show_world_guidance"]:
        var toggle := CheckButton.new()
        toggle.text = ""
        settings_controls[key] = toggle
        var label_key := "settings.%s" % key
        if key == "high_contrast_ui":
            label_key = "settings.high_contrast"
        elif key == "show_world_guidance":
            label_key = "settings.world_guidance"
        parent.add_child(_settings_row(label_key, toggle))

    var remap_hint := _body_label("settings.remap_hint", 13, Color("9fb1ae"), 42)
    remap_hint.name = "RemapHint"
    remap_hint.set_meta(&"localization_key", "settings.remap_hint")
    parent.add_child(remap_hint)
    for action in ReleaseSettingsService3D.REMAPPABLE_ACTIONS:
        var button := Button.new()
        button.name = "Remap_%s" % String(action)
        button.custom_minimum_size = Vector2(270, 36)
        button.pressed.connect(_begin_remap.bind(action))
        remap_buttons[action] = button
        parent.add_child(_settings_row("settings.%s" % _remap_label_suffix(action), button))
        var controller_button := Button.new()
        controller_button.name = "ControllerRemap_%s" % String(action)
        controller_button.custom_minimum_size = Vector2(270, 36)
        controller_button.pressed.connect(_begin_controller_remap.bind(action))
        controller_remap_buttons[action] = controller_button
        parent.add_child(_settings_row("settings.controller_%s" % _remap_label_suffix(action), controller_button))


func _settings_row(label_key: String, control: Control) -> HBoxContainer:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 18)
    var label := _body_label(label_key, 16, Color("dce5e2"), 42)
    label.name = "Localized_%s" % label_key.replace(".", "_")
    label.set_meta(&"localization_key", label_key)
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(label)
    control.custom_minimum_size.x = maxf(control.custom_minimum_size.x, 270.0)
    row.add_child(control)
    return row


func show_title(has_save: bool) -> void:
    visible = true
    active_screen = &"title"
    title_panel.visible = true
    pause_panel.visible = false
    settings_panel.visible = false
    continue_button.disabled = not has_save
    no_save_label.visible = not has_save
    remap_capture_action = &""
    _refresh_text()
    _populate_settings_controls()
    _focus_first_button(title_panel)
    if not has_save and new_world_button != null:
        # A first-run player should land on the only actionable entry point,
        # while Continue remains visibly unavailable.
        new_world_button.grab_focus()


func show_pause() -> void:
    visible = true
    active_screen = &"pause"
    title_panel.visible = false
    pause_panel.visible = true
    settings_panel.visible = false
    remap_capture_action = &""
    _refresh_text()
    _focus_first_button(pause_panel)


func show_settings_from_title() -> void:
    last_focus = continue_button
    _show_settings()


func show_settings_from_pause() -> void:
    last_focus = pause_panel
    _show_settings()


func _show_settings() -> void:
    visible = true
    active_screen = &"settings"
    title_panel.visible = false
    pause_panel.visible = false
    settings_panel.visible = true
    remap_capture_action = &""
    _populate_settings_controls()
    _refresh_text()
    var language := settings_controls.get("language") as Control
    if language != null:
        language.grab_focus()


func _back_from_settings() -> void:
    if last_focus == continue_button:
        show_title(continue_button != null and not continue_button.disabled)
    else:
        show_pause()


func hide_all() -> void:
    visible = false
    active_screen = &"hidden"
    title_panel.visible = false
    pause_panel.visible = false
    settings_panel.visible = false


func is_modal_open() -> bool:
    return visible and active_screen != &"hidden"


func _populate_settings_controls() -> void:
    if settings_service == null:
        return
    for key in ["master_volume", "music_volume", "ambience_volume", "effects_volume", "text_scale", "camera_shake"]:
        var slider := settings_controls.get(key) as HSlider
        if slider != null:
            slider.value = float(settings_service.get_value(StringName(key), slider.value))
    for key in ["high_contrast_ui", "reduced_motion", "reduced_flashes", "hold_interactions", "controller_vibration", "subtitles", "show_world_guidance"]:
        var toggle := settings_controls.get(key) as CheckButton
        if toggle != null:
            toggle.button_pressed = bool(settings_service.get_value(StringName(key), false))
    var selected_language := str(settings_service.get_value(&"language", "en"))
    if localization != null:
        # A non-saving review override changes the active catalog without
        # changing persisted preferences. Keep the visible selector aligned
        # with the catalog the player is actually seeing.
        selected_language = String(localization.current_locale)
    _select_metadata(settings_controls.get("language") as OptionButton, selected_language)
    _select_metadata(settings_controls.get("difficulty") as OptionButton, str(settings_service.get_value(&"difficulty", "survival")))
    _select_metadata(settings_controls.get("colorblind_mode") as OptionButton, str(settings_service.get_value(&"colorblind_mode", "off")))
    _select_metadata(settings_controls.get("target_fps") as OptionButton, int(settings_service.get_value(&"target_fps", 60)))
    _select_metadata(settings_controls.get("game_speed") as OptionButton, float(settings_service.get_value(&"game_speed", 1.0)))
    for action in ReleaseSettingsService3D.REMAPPABLE_ACTIONS:
        var button := remap_buttons.get(action) as Button
        if button != null:
            button.text = settings_service.key_binding_display_name(action)
        var controller_button := controller_remap_buttons.get(action) as Button
        if controller_button != null:
            controller_button.text = settings_service.controller_binding_display_name(action)


func _apply_settings() -> void:
    if settings_service == null:
        return
    var values: Dictionary = {}
    values["language"] = _selected_metadata(settings_controls.get("language") as OptionButton, "en")
    values["difficulty"] = _selected_metadata(settings_controls.get("difficulty") as OptionButton, "survival")
    values["colorblind_mode"] = _selected_metadata(settings_controls.get("colorblind_mode") as OptionButton, "off")
    values["target_fps"] = int(_selected_metadata(settings_controls.get("target_fps") as OptionButton, 60))
    values["game_speed"] = float(_selected_metadata(settings_controls.get("game_speed") as OptionButton, 1.0))
    for key in ["master_volume", "music_volume", "ambience_volume", "effects_volume", "text_scale", "camera_shake"]:
        var slider := settings_controls.get(key) as HSlider
        if slider != null:
            values[key] = slider.value
    for key in ["high_contrast_ui", "reduced_motion", "reduced_flashes", "hold_interactions", "controller_vibration", "subtitles", "show_world_guidance"]:
        var toggle := settings_controls.get(key) as CheckButton
        if toggle != null:
            values[key] = toggle.button_pressed
    for key in values:
        settings_service.set_value(StringName(str(key)), values[key], false)
    settings_service.save_settings()
    if localization != null:
        localization.set_locale(StringName(str(values["language"])))
    settings_applied.emit(values.duplicate(true))
    _refresh_text()


func _begin_remap(action: StringName) -> void:
    if not ReleaseSettingsService3D.REMAPPABLE_ACTIONS.has(action):
        return
    remap_capture_action = action
    var button := remap_buttons.get(action) as Button
    if button != null:
        button.text = localization.text("settings.press_key") if localization != null else "PRESS A KEY"
    if button != null:
        button.grab_focus()


func _begin_controller_remap(action: StringName) -> void:
    if not ReleaseSettingsService3D.REMAPPABLE_ACTIONS.has(action):
        return
    remap_capture_action = action
    var button := controller_remap_buttons.get(action) as Button
    if button != null:
        button.text = localization.text("settings.press_button") if localization != null else "PRESS A BUTTON"
        button.grab_focus()


func _remap_label_suffix(action: StringName) -> String:
    match action:
        &"iw_move_up": return "move_up"
        &"iw_move_down": return "move_down"
        &"iw_move_left": return "move_left"
        &"iw_move_right": return "move_right"
        &"iw_interact": return "interact"
    return String(action)


func _on_locale_changed(locale: StringName) -> void:
    _refresh_text()


func _on_settings_changed(next_settings: Dictionary) -> void:
    _populate_settings_controls()


func _refresh_text() -> void:
    if localization == null or title_label == null:
        return
    title_label.text = localization.text("app.title")
    subtitle_label.text = localization.text("app.subtitle")
    version_label.text = localization.text("menu.release_candidate")
    pause_subtitle_label.text = localization.text("menu.world_paused")
    continue_button.text = localization.text("menu.continue")
    no_save_label.text = localization.text("menu.no_save")
    settings_title.text = localization.text("settings.title")
    _translate_buttons(title_panel)
    _translate_buttons(pause_panel)
    _translate_buttons(settings_panel)
    _translate_labels(settings_panel)


func _translate_buttons(root: Node) -> void:
    if root == null:
        return
    for child in root.get_children():
        if child is Button:
            var button := child as Button
            var localization_key := str(button.get_meta(&"localization_key", ""))
            if localization_key.is_empty():
                var current := button.text.to_lower().replace(" ", "_").replace("·", "").strip_edges()
                var mappings := {
                    "continue": "menu.continue",
                    "new_world": "menu.new_world",
                    "settings": "menu.settings",
                    "quit": "menu.quit",
                    "resume": "menu.resume",
                    "save_world": "menu.save",
                    "load_world": "menu.load",
                    "return_to_title": "menu.return_title",
                    "apply": "menu.apply",
                    "back": "menu.back",
                }
                localization_key = str(mappings.get(current, ""))
            if not localization_key.is_empty():
                button.text = localization.text(localization_key)
        _translate_buttons(child)


func _translate_labels(root: Node) -> void:
    if root.has_meta(&"localization_key") and root is Label:
        (root as Label).text = localization.text(str(root.get_meta(&"localization_key")))
    for child in root.get_children():
        _translate_labels(child)


func _select_metadata(option: OptionButton, value: Variant) -> void:
    if option == null:
        return
    for index in range(option.item_count):
        if option.get_item_metadata(index) == value:
            option.select(index)
            return


func _selected_metadata(option: OptionButton, fallback: Variant) -> Variant:
    if option == null or option.selected < 0:
        return fallback
    return option.get_item_metadata(option.selected)


func _panel(size_value: Vector2) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.offset_left = -size_value.x * 0.5
    panel.offset_right = size_value.x * 0.5
    panel.offset_top = -size_value.y * 0.5
    panel.offset_bottom = size_value.y * 0.5
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.02, 0.04, 0.048, 0.97)
    style.border_color = Color(0.53, 0.68, 0.66, 0.46)
    style.set_border_width_all(1)
    style.set_corner_radius_all(14)
    style.shadow_color = Color(0.0, 0.0, 0.0, 0.62)
    style.shadow_size = 22
    style.content_margin_left = 28.0
    style.content_margin_right = 28.0
    style.content_margin_top = 24.0
    style.content_margin_bottom = 24.0
    panel.add_theme_stylebox_override("panel", style)
    add_child(panel)
    return panel


func _vertical_content(panel: PanelContainer, separation: int) -> VBoxContainer:
    var box := VBoxContainer.new()
    box.add_theme_constant_override("separation", separation)
    panel.add_child(box)
    return box


func _heading(value: String, size_value: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.add_theme_font_size_override("font_size", size_value)
    label.add_theme_constant_override("outline_size", 5)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
    return label


func _body_label(value: String, size_value: int, color: Color, minimum_height: float) -> Label:
    var label := Label.new()
    label.text = value
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.custom_minimum_size.y = minimum_height
    label.add_theme_font_size_override("font_size", size_value)
    label.add_theme_constant_override("outline_size", 3)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.86))
    return label


func _menu_button(value: String, callback: Callable) -> Button:
    var button := Button.new()
    button.text = value
    var localization_keys := {
        "CONTINUE": "menu.continue",
        "NEW WORLD": "menu.new_world",
        "SETTINGS": "menu.settings",
        "QUIT": "menu.quit",
        "RESUME": "menu.resume",
        "SAVE WORLD": "menu.save",
        "LOAD WORLD": "menu.load",
        "RETURN TO TITLE": "menu.return_title",
        "APPLY": "menu.apply",
        "BACK": "menu.back",
    }
    if localization_keys.has(value):
        button.set_meta(&"localization_key", localization_keys[value])
    button.custom_minimum_size = Vector2(0, 52)
    button.add_theme_font_size_override("font_size", 18)
    button.focus_mode = Control.FOCUS_ALL
    button.pressed.connect(callback)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.04, 0.075, 0.08, 0.96)
    normal.border_color = Color(0.38, 0.58, 0.58, 0.4)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(7)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color(0.15, 0.12, 0.08, 0.98)
    hover.border_color = Color(0.98, 0.65, 0.34, 0.76)
    button.add_theme_stylebox_override("normal", normal)
    var disabled := normal.duplicate() as StyleBoxFlat
    disabled.bg_color = Color(0.025, 0.045, 0.048, 0.78)
    disabled.border_color = Color(0.28, 0.38, 0.38, 0.24)
    button.add_theme_stylebox_override("disabled", disabled)
    button.add_theme_color_override("font_disabled_color", Color("667774"))
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("focus", hover)
    button.add_theme_stylebox_override("pressed", hover)
    return button


func _focus_first_button(root: Node) -> void:
    if root is Button and not (root as Button).disabled and (root as Button).visible:
        (root as Button).grab_focus()
        return
    for child in root.get_children():
        var before := get_viewport().gui_get_focus_owner()
        _focus_first_button(child)
        if get_viewport().gui_get_focus_owner() != before:
            return
