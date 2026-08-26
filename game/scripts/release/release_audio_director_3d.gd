class_name ReleaseAudioDirector3D
extends Node

signal mood_changed(mood: StringName)

const AUDIO_ROOT := "res://assets/release/audio"
const QUIET_AUDIO_FLAG := "--quiet-audio"
const QUIET_AUDIO_CAP_DB := -18.0
const STREAM_PATHS: Dictionary = {
    &"ambience_city": AUDIO_ROOT + "/ambience_city.wav",
    &"ambience_sanctuary": AUDIO_ROOT + "/ambience_sanctuary.wav",
    &"music_embers": AUDIO_ROOT + "/music_embers.wav",
    &"music_pressure": AUDIO_ROOT + "/music_pressure.wav",
    &"music_sovereignty": AUDIO_ROOT + "/music_sovereignty.wav",
    &"pistol": AUDIO_ROOT + "/sfx_pistol.wav",
    &"salvage": AUDIO_ROOT + "/sfx_salvage.wav",
    &"forge": AUDIO_ROOT + "/sfx_forge.wav",
    &"organic_hit": AUDIO_ROOT + "/sfx_organic_hit.wav",
    &"machine_report": AUDIO_ROOT + "/sfx_machine_report.wav",
    &"danger": AUDIO_ROOT + "/sfx_danger.wav",
    &"victory": AUDIO_ROOT + "/sfx_victory.wav",
    &"ui_confirm": AUDIO_ROOT + "/sfx_ui_confirm.wav",
}

var player: Mechromancer3D
var heartforge: Heartforge3D
var progression: ProgressionDirector3D
var strategic_ecology: StrategicEcologyDirector3D
var endgame: EndgameDirector3D
var localization: LocalizationService3D
var settings_service: ReleaseSettingsService3D
var stream_library: Dictionary = {}
var city_ambience: AudioStreamPlayer
var sanctuary_ambience: AudioStreamPlayer
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var active_music: AudioStreamPlayer
var inactive_music: AudioStreamPlayer
var current_mood: StringName = &""
var sfx_pool: Array[AudioStreamPlayer] = []
var sfx_cursor: int = 0
var caption_layer: CanvasLayer
var caption_panel: PanelContainer
var caption_label: Label
var caption_clock: float = 0.0
var evaluation_clock: float = 0.0
var operation_report_clock: float = 0.0
var operation_report_count: int = 0
var last_operation_signature: StringName = &""
var spatial_operation_reports: Array[AudioStreamPlayer3D] = []
var attack_warning_clock: float = 0.0
var attack_warning_count: int = 0
var last_heartforge_tier: int = 1
var heartforge_tier_cue_count: int = 0
var quiet_audio: bool = false


func configure(
        next_player: Mechromancer3D,
        next_heartforge: Heartforge3D,
        next_progression: ProgressionDirector3D,
        next_strategic_ecology: StrategicEcologyDirector3D,
        next_endgame: EndgameDirector3D,
        next_localization: LocalizationService3D,
        next_settings: ReleaseSettingsService3D
    ) -> void:
    player = next_player
    heartforge = next_heartforge
    progression = next_progression
    strategic_ecology = next_strategic_ecology
    endgame = next_endgame
    localization = next_localization
    settings_service = next_settings


func _ready() -> void:
    add_to_group(&"release_audio_director")
    quiet_audio = _has_command_line_flag(QUIET_AUDIO_FLAG)
    _load_streams()
    _build_players()
    _build_caption_ui()
    _connect_existing_nodes()
    get_tree().node_added.connect(_on_node_added)
    last_heartforge_tier = progression.heartforge_tier if progression != null else 1
    _switch_music(&"embers", true)


func _process(delta: float) -> void:
    evaluation_clock += delta
    caption_clock = maxf(0.0, caption_clock - delta)
    operation_report_clock = maxf(0.0, operation_report_clock - delta)
    attack_warning_clock = maxf(0.0, attack_warning_clock - delta)
    if caption_panel != null and caption_clock <= 0.0:
        caption_panel.visible = false
    _update_ambience(delta)
    _update_music_crossfade(delta)
    if evaluation_clock >= 0.5:
        evaluation_clock = 0.0
        _evaluate_music_mood()


func _load_streams() -> void:
    stream_library.clear()
    for raw_id in STREAM_PATHS:
        var stream_id := raw_id as StringName
        var path := str(STREAM_PATHS[stream_id])
        if not ResourceLoader.exists(path):
            continue
        var stream := load(path) as AudioStream
        if stream == null:
            continue
        if stream is AudioStreamWAV and (String(stream_id).begins_with("music_") or String(stream_id).begins_with("ambience_")):
            var wav := stream as AudioStreamWAV
            wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
            wav.loop_begin = 0
            var channels := 2 if wav.stereo else 1
            wav.loop_end = maxi(1, wav.data.size() / maxi(1, channels * 2))
        stream_library[stream_id] = stream


func _build_players() -> void:
    city_ambience = _audio_player("CityAmbience", "Ambience", &"ambience_city", -18.0)
    sanctuary_ambience = _audio_player("SanctuaryAmbience", "Ambience", &"ambience_sanctuary", -10.0)
    music_a = _audio_player("MusicA", "Music", &"music_embers", -12.0)
    music_b = _audio_player("MusicB", "Music", &"music_pressure", -60.0)
    active_music = music_a
    inactive_music = music_b
    for index in range(12):
        var player_node := AudioStreamPlayer.new()
        player_node.name = "ReleaseSFX_%02d" % index
        player_node.bus = "Effects"
        add_child(player_node)
        sfx_pool.append(player_node)


func _audio_player(node_name: String, bus_name: String, stream_id: StringName, volume_db: float) -> AudioStreamPlayer:
    var audio := AudioStreamPlayer.new()
    audio.name = node_name
    audio.bus = bus_name
    audio.stream = stream_library.get(stream_id, null)
    audio.volume_db = _safe_volume_db(volume_db)
    add_child(audio)
    if audio.stream != null:
        audio.play()
    return audio


func _build_caption_ui() -> void:
    caption_layer = CanvasLayer.new()
    caption_layer.name = "SoundCaptionLayer"
    # Strategic readouts must sit above captions so a transient audio label
    # cannot cover their fixed close footer.
    caption_layer.layer = 34
    add_child(caption_layer)
    caption_panel = PanelContainer.new()
    caption_panel.name = "SoundCaptionPanel"
    caption_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    caption_panel.offset_left = -260.0
    caption_panel.offset_right = 260.0
    caption_panel.offset_top = -164.0
    caption_panel.offset_bottom = -120.0
    caption_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.018, 0.035, 0.04, 0.88)
    style.border_color = Color(0.72, 0.82, 0.8, 0.32)
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    caption_panel.add_theme_stylebox_override("panel", style)
    caption_layer.add_child(caption_panel)
    caption_label = Label.new()
    caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    caption_label.add_theme_font_size_override("font_size", 15)
    caption_label.add_theme_constant_override("outline_size", 3)
    caption_label.add_theme_color_override("font_color", Color("f2eee6"))
    caption_panel.add_child(caption_label)
    caption_panel.visible = false


func play_effect(effect_id: StringName, caption_key: String = "", pitch_variation: float = 0.0, volume_db: float = 0.0, base_pitch: float = 1.0) -> void:
    var stream: AudioStream = stream_library.get(effect_id, null)
    if stream == null or sfx_pool.is_empty():
        return
    var audio := sfx_pool[sfx_cursor % sfx_pool.size()]
    sfx_cursor += 1
    audio.stop()
    audio.stream = stream
    audio.pitch_scale = clampf(base_pitch + sin(float(sfx_cursor) * 1.731) * pitch_variation, 0.55, 1.55)
    audio.volume_db = _safe_volume_db(volume_db)
    audio.play()
    if not caption_key.is_empty():
        show_caption(caption_key)


func notify_operation(kind: StringName, state: StringName, detail: String, world_position: Vector3 = Vector3.ZERO) -> void:
    var signature := StringName("%s.%s" % [String(kind), String(state)])
    if signature == last_operation_signature and operation_report_clock > 0.0:
        return
    last_operation_signature = signature
    operation_report_clock = 1.4 if state in [&"working", &"engaged"] else 0.35
    operation_report_count += 1
    var pitch := 0.92
    var volume := -7.0
    match state:
        &"outbound":
            pitch = 1.02
            volume = -6.0
        &"working", &"engaged":
            pitch = 0.88
            volume = -8.0
        &"returning":
            pitch = 0.98
            volume = -6.0
        &"complete", &"constructed", &"secured":
            pitch = 1.08
            volume = -3.0
        &"aborted", &"destroyed":
            pitch = 0.72
            volume = -5.0
    var anchor := world_position
    if anchor == Vector3.ZERO and heartforge != null and is_instance_valid(heartforge):
        anchor = heartforge.global_position
    _play_spatial_report(anchor, volume, pitch)
    show_caption("audio.caption.report")


func _play_spatial_report(world_position: Vector3, volume_db: float, pitch_scale: float) -> void:
    var stream: AudioStream = stream_library.get(&"machine_report", null)
    if stream == null:
        return
    while spatial_operation_reports.size() >= 8:
        var oldest: AudioStreamPlayer3D = spatial_operation_reports[0]
        spatial_operation_reports.remove_at(0)
        if is_instance_valid(oldest):
            oldest.queue_free()
    var audio := AudioStreamPlayer3D.new()
    audio.name = "OperationReport_%02d" % operation_report_count
    audio.bus = "Effects"
    audio.stream = stream
    audio.volume_db = _safe_volume_db(volume_db)
    audio.pitch_scale = pitch_scale
    audio.max_distance = 42.0
    audio.unit_size = 5.0
    audio.finished.connect(_on_spatial_report_finished.bind(audio))
    add_child(audio)
    audio.global_position = world_position
    spatial_operation_reports.append(audio)
    audio.play()


func _on_spatial_report_finished(audio: AudioStreamPlayer3D) -> void:
    spatial_operation_reports.erase(audio)
    if is_instance_valid(audio):
        audio.queue_free()


func show_caption(key: String, seconds: float = 2.2) -> void:
    if settings_service != null and not bool(settings_service.get_value(&"subtitles", true)):
        return
    caption_label.text = "[%s]" % (localization.text(key) if localization != null else key)
    caption_panel.visible = true
    caption_clock = maxf(caption_clock, seconds)


func notify_machine_report() -> void:
    play_effect(&"machine_report", "audio.caption.report", 0.02, -5.0)


func notify_danger() -> void:
    play_effect(&"danger", "audio.caption.danger", 0.0, -2.0)


func notify_victory() -> void:
    play_effect(&"victory", "audio.caption.victory", 0.0, 0.0)
    _switch_music(&"sovereignty")


func _connect_existing_nodes() -> void:
    if progression != null:
        var tier_callback := Callable(self, "_on_heartforge_tier_changed")
        if not progression.heartforge_tier_changed.is_connected(tier_callback):
            progression.heartforge_tier_changed.connect(tier_callback)
    for node in get_tree().get_nodes_in_group(&"player_character"):
        _connect_actor(node)
    for node in get_tree().get_nodes_in_group(&"organic_enemies"):
        _connect_actor(node)
    for node in get_tree().get_nodes_in_group(&"friendly_robots"):
        _connect_actor(node)


func _on_node_added(node: Node) -> void:
    call_deferred("_connect_actor", node)


func _connect_actor(node: Variant) -> void:
    if not is_instance_valid(node) or not (node is Node):
        return
    if node is Mechromancer3D:
        var mech := node as Mechromancer3D
        var pistol_callback := Callable(self, "_on_pistol_fired")
        if not mech.pistol_fired.is_connected(pistol_callback):
            mech.pistol_fired.connect(pistol_callback)
        var channel_callback := Callable(self, "_on_channel_started")
        if not mech.channel_started.is_connected(channel_callback):
            mech.channel_started.connect(channel_callback)
    elif node is OrganicEnemy3D:
        var enemy := node as OrganicEnemy3D
        var warning_callback := Callable(self, "_on_organic_attack_started")
        if not enemy.attack_started.is_connected(warning_callback):
            enemy.attack_started.connect(warning_callback)
        var attack_callback := Callable(self, "_on_organic_attack")
        if not enemy.attack_landed.is_connected(attack_callback):
            enemy.attack_landed.connect(attack_callback)
        var killed_callback := Callable(self, "_on_organic_killed")
        if not enemy.killed.is_connected(killed_callback):
            enemy.killed.connect(killed_callback)


func _on_pistol_fired(origin: Vector3, target: Vector3, target_node: Node) -> void:
    play_effect(&"pistol", "audio.caption.pistol", 0.035, -7.0)


func _on_channel_started(kind: StringName, duration: float, description: String) -> void:
    if kind == &"manual_salvage":
        play_effect(&"salvage", "audio.caption.salvage", 0.02, -3.0)
    elif kind in [&"forge_build", &"forge_upgrade", &"heartforge_evolution"]:
        play_effect(&"forge", "audio.caption.forge", 0.015, -2.0)


func _on_heartforge_tier_changed(tier: int) -> void:
    if tier <= last_heartforge_tier:
        return
    last_heartforge_tier = tier
    heartforge_tier_cue_count += 1
    var pitch := lerpf(0.9, 1.08, clampf(float(tier - 2) / 3.0, 0.0, 1.0))
    play_effect(&"forge", "audio.caption.heartforge_tier", 0.012, -1.0, pitch)
    if tier >= 4:
        _switch_music(&"sovereignty")


func _on_organic_attack(enemy: OrganicEnemy3D, target: Node) -> void:
    if player != null and is_instance_valid(player) and target == player:
        play_effect(&"organic_hit", "audio.caption.organic", 0.05, -2.0, _organic_signature_pitch(enemy.species, false))


func _on_organic_attack_started(enemy: OrganicEnemy3D, target: Node) -> void:
    if player == null or not is_instance_valid(player) or target != player:
        return
    # A pack can begin several wind-ups in the same frame. Keep the warning
    # audible without turning a crowded defence into a constant alarm.
    if attack_warning_clock > 0.0:
        return
    attack_warning_clock = 0.18
    attack_warning_count += 1
    play_effect(&"danger", "", 0.04, -8.0, _organic_signature_pitch(enemy.species, false))


func _on_organic_killed(enemy: OrganicEnemy3D, killer: Node) -> void:
    play_effect(&"organic_hit", "", 0.08, -9.0, _organic_signature_pitch(enemy.species, true))


func _organic_signature_pitch(species: StringName, death: bool) -> float:
    var pitch := 1.0
    match species:
        &"apex", &"broodmass", &"rootweaver":
            pitch = 0.74
        &"burrower", &"miremaw":
            pitch = 0.84
        &"razorhound", &"carrionbell":
            pitch = 0.96
        &"veilstalker", &"sporecaster":
            pitch = 1.08
        &"ashmantle":
            pitch = 0.88
        &"thornback":
            pitch = 0.92
        &"roofleaper":
            pitch = 1.2
        &"glassmoth":
            pitch = 1.28
        _:
            pitch = 1.0
    return pitch * (0.92 if death else 1.0)


func _update_ambience(delta: float) -> void:
    if player == null or heartforge == null or not is_instance_valid(player) or not is_instance_valid(heartforge):
        return
    var distance := player.global_position.distance_to(heartforge.global_position)
    var sanctuary_weight := 1.0 - clampf((distance - 6.0) / 30.0, 0.0, 1.0)
    var city_weight := 1.0 - sanctuary_weight * 0.82
    var sanctuary_target := _safe_volume_db(linear_to_db(maxf(0.001, sanctuary_weight * 0.95)))
    var city_target := _safe_volume_db(linear_to_db(maxf(0.001, city_weight * 0.85)))
    sanctuary_ambience.volume_db = lerpf(sanctuary_ambience.volume_db, sanctuary_target, 1.0 - exp(-delta * 2.0))
    city_ambience.volume_db = lerpf(city_ambience.volume_db, city_target, 1.0 - exp(-delta * 2.0))


func _evaluate_music_mood() -> void:
    var next_mood: StringName = &"embers"
    if endgame != null and not endgame.active_protocol.is_empty():
        next_mood = &"pressure"
    elif progression != null and progression.heartforge_tier >= 4:
        next_mood = &"sovereignty"
    if strategic_ecology != null:
        var summary := strategic_ecology.pressure_summary()
        var parts := summary.split("pressure ")
        if parts.size() > 1 and float(parts[1]) >= 1.15:
            next_mood = &"pressure"
    if next_mood != current_mood:
        _switch_music(next_mood)


func _switch_music(mood: StringName, immediate: bool = false) -> void:
    var stream_id := StringName("music_%s" % String(mood))
    var stream: AudioStream = stream_library.get(stream_id, null)
    if stream == null:
        return
    current_mood = mood
    inactive_music.stop()
    inactive_music.stream = stream
    inactive_music.volume_db = _safe_volume_db(0.0) if immediate else -60.0
    inactive_music.play()
    var swap := active_music
    active_music = inactive_music
    inactive_music = swap
    if immediate:
        inactive_music.stop()
    mood_changed.emit(current_mood)


func _update_music_crossfade(delta: float) -> void:
    if active_music == null or inactive_music == null:
        return
    active_music.volume_db = move_toward(active_music.volume_db, _safe_volume_db(-7.0), delta * 24.0)
    inactive_music.volume_db = move_toward(inactive_music.volume_db, -60.0, delta * 28.0)
    if inactive_music.volume_db <= -58.0 and inactive_music.playing:
        inactive_music.stop()


func to_dictionary() -> Dictionary:
    return {"schema_version": 1, "current_mood": String(current_mood)}


func restore_from_dictionary(data: Dictionary) -> void:
    _switch_music(StringName(str(data.get("current_mood", "embers"))), true)


func _safe_volume_db(volume_db: float) -> float:
    return minf(volume_db, QUIET_AUDIO_CAP_DB) if quiet_audio else volume_db


func _has_command_line_flag(flag: String) -> bool:
    for argument in OS.get_cmdline_args():
        if str(argument) == flag:
            return true
    for argument in OS.get_cmdline_user_args():
        if str(argument) == flag:
            return true
    return false
