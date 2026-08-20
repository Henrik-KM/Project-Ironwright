class_name AudioFeedbackDirector3D
extends Node

## Small original sound language for the survival slice.
##
## Audio is generated from deterministic waveforms at runtime so the prototype
## has real spatial feedback without external asset dependencies. The event
## vocabulary is intentionally compact: each sound reinforces a meaningful
## action or danger rather than becoming constant background chatter.

signal sound_event(profile: StringName, position: Vector3)

const MIX_RATE := 22050
const MAX_ACTIVE_PLAYERS := 18

var world: Node3D
var player: Node3D
var heartforge: Node3D
var noise_system: Node
var profiles: Dictionary = {}
var active_players: Array[AudioStreamPlayer3D] = []
var event_count: int = 0
var last_profile: StringName = &""
var _last_heartforge_health: float = -1.0


func configure(next_world: Node3D, next_player: Node3D, next_heartforge: Node3D, next_noise_system: Node) -> void:
    world = next_world
    player = next_player
    heartforge = next_heartforge
    noise_system = next_noise_system


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for profile in [&"pistol", &"machine_weapon", &"salvage", &"forge", &"organic_attack", &"organic_death", &"heartforge_damage", &"noise_pulse"]:
        profiles[profile] = _build_profile(profile)
    _register_existing_actors()
    get_tree().node_added.connect(_on_node_added)
    if player != null and player.has_signal(&"channel_started"):
        player.connect(&"channel_started", Callable(self, "_on_channel_started"))
    if player != null and player.has_signal(&"channel_completed"):
        player.connect(&"channel_completed", Callable(self, "_on_channel_completed"))
    if noise_system != null and noise_system.has_signal(&"noise_emitted"):
        noise_system.connect(&"noise_emitted", Callable(self, "_on_noise_emitted"))
    if heartforge != null and heartforge.has_signal(&"health_changed"):
        heartforge.connect(&"health_changed", Callable(self, "_on_heartforge_health_changed"))


func _process(_delta: float) -> void:
    for index in range(active_players.size() - 1, -1, -1):
        var audio_player := active_players[index]
        if not is_instance_valid(audio_player):
            active_players.remove_at(index)


func available_profiles() -> Array[StringName]:
    var result: Array[StringName] = []
    for key in profiles.keys():
        result.append(StringName(key))
    result.sort()
    return result


func has_profile(profile: StringName) -> bool:
    return profiles.has(profile) and profiles[profile] is AudioStreamWAV


func play_profile(profile: StringName, position: Vector3, volume_db: float = -7.0) -> void:
    if not profiles.has(profile) or world == null:
        return
    while active_players.size() >= MAX_ACTIVE_PLAYERS:
        var oldest: AudioStreamPlayer3D = active_players.pop_front() as AudioStreamPlayer3D
        if is_instance_valid(oldest):
            oldest.queue_free()
    var audio_player := AudioStreamPlayer3D.new()
    audio_player.name = "Sound_%s_%03d" % [String(profile), event_count]
    audio_player.stream = profiles[profile] as AudioStreamWAV
    audio_player.volume_db = volume_db
    audio_player.unit_size = 3.0
    audio_player.max_distance = 34.0
    audio_player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
    world.add_child(audio_player)
    audio_player.global_position = position
    audio_player.finished.connect(audio_player.queue_free)
    active_players.append(audio_player)
    event_count += 1
    last_profile = profile
    sound_event.emit(profile, position)
    audio_player.play()


func stop_all() -> void:
    for audio_player in active_players:
        if is_instance_valid(audio_player):
            audio_player.queue_free()
    active_players.clear()


func _register_existing_actors() -> void:
    if player != null:
        _register_actor(player)
    for actor in get_tree().get_nodes_in_group(&"friendly_robots"):
        _register_actor(actor)
    for actor in get_tree().get_nodes_in_group(&"organic_enemies"):
        _register_actor(actor)


func _on_node_added(node: Node) -> void:
    if node is Node3D:
        call_deferred("_register_if_actor", node)


func _register_if_actor(node: Variant) -> void:
    if not is_instance_valid(node):
        return
    if not (node is Node):
        return
    var actor := node as Node
    if actor.is_in_group(&"player_character") or actor.is_in_group(&"friendly_robots") or actor.is_in_group(&"organic_enemies"):
        _register_actor(actor)


func _register_actor(actor: Node) -> void:
    if actor.has_signal(&"pistol_fired"):
        _connect_once(actor, &"pistol_fired", Callable(self, "_on_pistol_fired"))
    if actor.has_signal(&"weapon_fired"):
        _connect_once(actor, &"weapon_fired", Callable(self, "_on_weapon_fired"))
    if actor.has_signal(&"attack_landed"):
        _connect_once(actor, &"attack_landed", Callable(self, "_on_attack_landed"))
    if actor.has_signal(&"killed"):
        _connect_once(actor, &"killed", Callable(self, "_on_actor_killed"))


func _connect_once(source: Object, signal_name: StringName, callback: Callable) -> void:
    if source.has_signal(signal_name) and not source.is_connected(signal_name, callback):
        source.connect(signal_name, callback)


func _on_pistol_fired(origin: Vector3, _target: Vector3, _target_node: Node) -> void:
    play_profile(&"pistol", origin, -6.0)


func _on_weapon_fired(origin: Vector3, _target: Vector3, target_node: Node) -> void:
    var profile := &"machine_weapon"
    if target_node != null and target_node.is_in_group(&"organic_enemies"):
        profile = &"machine_weapon"
    play_profile(profile, origin, -8.0)


func _on_attack_landed(enemy: Node, target: Node) -> void:
    var position := (enemy as Node3D).global_position if enemy is Node3D else Vector3.ZERO
    if target is Node3D:
        position = ((enemy as Node3D).global_position + (target as Node3D).global_position) * 0.5
    play_profile(&"organic_attack", position, -7.5)


func _on_actor_killed(enemy: Node, _killer: Node) -> void:
    if enemy is Node3D and enemy.is_in_group(&"organic_enemies"):
        play_profile(&"organic_death", (enemy as Node3D).global_position, -8.0)


func _on_noise_emitted(position: Vector3, _radius: float, intensity: float, source_kind: StringName) -> void:
    if source_kind in [&"manual_salvage", &"forge_build", &"forge_upgrade"]:
        play_profile(&"noise_pulse", position, -10.0 + clampf(intensity, 0.0, 1.0) * 2.0)


func _on_channel_started(kind: StringName, _duration: float, _description: String) -> void:
    if player == null:
        return
    play_profile(&"salvage" if kind == &"manual_salvage" else &"forge", player.global_position, -9.0)


func _on_channel_completed(kind: StringName, _target: Node, _metadata: Dictionary) -> void:
    if player == null:
        return
    play_profile(&"salvage" if kind == &"manual_salvage" else &"forge", player.global_position, -5.5)


func _on_heartforge_health_changed(current: float, _maximum: float) -> void:
    if _last_heartforge_health >= 0.0 and current < _last_heartforge_health:
        play_profile(&"heartforge_damage", heartforge.global_position, -6.5)
    _last_heartforge_health = current


func _build_profile(profile: StringName) -> AudioStreamWAV:
    var duration := 0.2
    match profile:
        &"machine_weapon":
            duration = 0.24
        &"salvage":
            duration = 0.34
        &"forge":
            duration = 0.5
        &"organic_attack":
            duration = 0.28
        &"organic_death":
            duration = 0.55
        &"heartforge_damage":
            duration = 0.34
        &"noise_pulse":
            duration = 0.16

    var sample_count := maxi(1, int(duration * MIX_RATE))
    var data := PackedByteArray()
    data.resize(sample_count * 2)
    for index in range(sample_count):
        var time := float(index) / float(MIX_RATE)
        var normalized := float(index) / float(sample_count - 1)
        var value := _sample_profile(profile, normalized, time, duration, index)
        var signed_sample := clampi(int(clampf(value, -1.0, 1.0) * 30000.0), -32768, 32767)
        data[index * 2] = signed_sample & 0xff
        data[index * 2 + 1] = (signed_sample >> 8) & 0xff

    var stream := AudioStreamWAV.new()
    stream.format = AudioStreamWAV.FORMAT_16_BITS
    stream.mix_rate = MIX_RATE
    stream.stereo = false
    stream.data = data
    return stream


func _sample_profile(profile: StringName, normalized: float, time: float, duration: float, index: int) -> float:
    var attack := clampf(normalized / 0.035, 0.0, 1.0)
    var release := clampf((1.0 - normalized) / 0.18, 0.0, 1.0)
    var envelope := attack * release
    var noise := sin(float(index) * 12.9898 + 78.233) * 0.5 + sin(float(index) * 4.1414) * 0.25
    match profile:
        &"pistol":
            return (sin(TAU * (650.0 * time - 380.0 * time * time / duration)) * 0.46 + noise * 0.38) * envelope
        &"machine_weapon":
            return (sin(TAU * (190.0 * time + 110.0 * time * time / duration)) * 0.52 + sin(TAU * 820.0 * time) * 0.12) * envelope
        &"salvage":
            return (sin(TAU * 92.0 * time) * 0.45 + sin(TAU * 184.0 * time) * 0.18 + noise * 0.09) * (0.35 + envelope * 0.65)
        &"forge":
            return (sin(TAU * 58.0 * time) * 0.5 + sin(TAU * 116.0 * time) * 0.2 + sin(TAU * 420.0 * time) * 0.1) * (0.3 + envelope * 0.7)
        &"organic_attack":
            return (noise * 0.58 + sin(TAU * (140.0 * time + 90.0 * time * time / duration)) * 0.34) * envelope
        &"organic_death":
            return (noise * 0.28 + sin(TAU * (360.0 * time - 270.0 * time * time / duration)) * 0.48) * envelope
        &"heartforge_damage":
            return (sin(TAU * 72.0 * time) * 0.56 + sin(TAU * 144.0 * time) * 0.18) * envelope
        &"noise_pulse":
            return sin(TAU * (280.0 * time + 210.0 * time * time / duration)) * envelope
    return 0.0
