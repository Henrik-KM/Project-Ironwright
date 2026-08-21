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
const ORGANIC_SPECIES := [
    &"veilstalker", &"razorhound", &"apex", &"sporecaster", &"broodmass", &"burrower",
    &"skitterling", &"roofleaper", &"glassmoth", &"miremaw", &"carrionbell", &"rootweaver", &"thornback", &"ashmantle",
]

var world: Node3D
var player: Node3D
var heartforge: Node3D
var noise_system: Node
var profiles: Dictionary = {}
var active_players: Array[AudioStreamPlayer3D] = []
var event_count: int = 0
var last_profile: StringName = &""
var last_actor_health: Dictionary = {}
var last_player_health: float = -1.0
var _last_heartforge_health: float = -1.0
var _last_endgame_stage: int = -1


func configure(next_world: Node3D, next_player: Node3D, next_heartforge: Node3D, next_noise_system: Node) -> void:
    world = next_world
    player = next_player
    heartforge = next_heartforge
    noise_system = next_noise_system


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    for profile in [&"pistol", &"machine_weapon", &"machine_impact", &"player_impact", &"salvage", &"forge", &"organic_attack", &"organic_impact", &"organic_death", &"heartforge_damage", &"noise_pulse", &"region_transition", &"endgame_start", &"endgame_stage", &"endgame_complete", &"endgame_failure"]:
        profiles[profile] = _build_profile(profile)
    for species in ORGANIC_SPECIES:
        profiles[_organic_profile_id(species, false)] = _build_profile(_organic_profile_id(species, false))
        profiles[_organic_profile_id(species, true)] = _build_profile(_organic_profile_id(species, true))
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


func organic_profile_id(species: StringName, death: bool = false) -> StringName:
    return _organic_profile_id(species, death)


func play_profile(profile: StringName, position: Vector3, volume_db: float = -7.0, pitch_scale: float = 1.0) -> void:
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
    audio_player.pitch_scale = clampf(pitch_scale, 0.55, 1.55)
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


func register_region_atmosphere(source: Node) -> void:
    if source == null or not source.has_signal(&"atmosphere_changed"):
        return
    _connect_once(source, &"atmosphere_changed", Callable(self, "_on_region_atmosphere_changed"))


func register_endgame(source: Node) -> void:
    if source == null:
        return
    _connect_once(source, &"endgame_started", Callable(self, "_on_endgame_started"))
    _connect_once(source, &"endgame_progress", Callable(self, "_on_endgame_progress"))
    _connect_once(source, &"endgame_completed", Callable(self, "_on_endgame_completed"))
    _connect_once(source, &"endgame_failed", Callable(self, "_on_endgame_failed"))


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
    if actor.is_in_group(&"player_character"):
        _connect_once(actor, &"health_changed", Callable(self, "_on_player_health_changed"))
        if actor.get(&"current_health") != null:
            last_player_health = float(actor.get(&"current_health"))
    if actor.has_signal(&"pistol_fired"):
        _connect_once(actor, &"pistol_fired", Callable(self, "_on_pistol_fired"))
    if actor.has_signal(&"weapon_fired"):
        _connect_once(actor, &"weapon_fired", Callable(self, "_on_weapon_fired"))
    if actor.has_signal(&"attack_landed"):
        _connect_once(actor, &"attack_landed", Callable(self, "_on_attack_landed"))
    if actor.has_signal(&"killed"):
        _connect_once(actor, &"killed", Callable(self, "_on_actor_killed"))
    if actor.is_in_group(&"friendly_robots") or actor.is_in_group(&"organic_enemies"):
        _connect_once(actor, &"health_changed", Callable(self, "_on_actor_health_changed"))
        if actor.get(&"current_health") != null:
            last_actor_health[actor.get_instance_id()] = float(actor.get(&"current_health"))


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
    var species: StringName = enemy.species if enemy is OrganicEnemy3D else &"skitterling"
    play_profile(_organic_profile_id(species, false), position, -7.5, _organic_pitch(species, false))


func _on_actor_killed(enemy: Node, _killer: Node) -> void:
    if enemy != null:
        last_actor_health.erase(enemy.get_instance_id())
    if enemy is Node3D and enemy.is_in_group(&"organic_enemies"):
        var species: StringName = enemy.species if enemy is OrganicEnemy3D else &"skitterling"
        play_profile(_organic_profile_id(species, true), (enemy as Node3D).global_position, -8.0, _organic_pitch(species, true))


func _on_actor_health_changed(actor: Node, current: float, _maximum: float) -> void:
    if not actor is Node3D:
        return
    var actor_id := actor.get_instance_id()
    var previous := float(last_actor_health.get(actor_id, current))
    last_actor_health[actor_id] = current
    if current <= 0.0 or current >= previous:
        return
    var friendly := actor.is_in_group(&"friendly_robots")
    var profile := &"machine_impact" if friendly else &"organic_impact"
    play_profile(profile, (actor as Node3D).global_position + Vector3.UP * 0.7, -8.0, 1.0 if friendly else 0.92)


func _on_player_health_changed(current: float, _maximum: float) -> void:
    var previous := last_player_health
    last_player_health = current
    if previous >= 0.0 and current < previous and current > 0.0 and player != null:
        play_profile(&"player_impact", player.global_position + Vector3.UP * 1.0, -5.5, 0.96)


func _on_noise_emitted(position: Vector3, _radius: float, intensity: float, source_kind: StringName) -> void:
    if source_kind in [&"manual_salvage", &"forge_build", &"forge_upgrade", &"outpost_construction"]:
        var construction_pitch := 0.78 if source_kind == &"outpost_construction" else 1.0
        play_profile(&"noise_pulse", position, -10.0 + clampf(intensity, 0.0, 1.0) * 2.0, construction_pitch)


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


func _on_region_atmosphere_changed(_region_id: StringName, kind: StringName) -> void:
    if player == null:
        return
    var pitch := 1.0
    match kind:
        &"industrial":
            pitch = 0.82
        &"waterfront":
            pitch = 0.9
        &"nest", &"endgame":
            pitch = 0.68
        &"research", &"observatory":
            pitch = 1.18
        &"greenhouse":
            pitch = 1.08
        &"commercial", &"tenement":
            pitch = 1.02
        _:
            pitch = 0.96
    play_profile(&"region_transition", player.global_position, -12.0, pitch)


func _on_endgame_started(_protocol_id: StringName, _display_name: String) -> void:
    _last_endgame_stage = -1
    if heartforge != null:
        play_profile(&"endgame_start", heartforge.global_position, -3.5, 0.72)


func _on_endgame_progress(_protocol_id: StringName, progress: float, _detail: String) -> void:
    var stage := clampi(int(floor(progress * 4.0)), 0, 3)
    if stage == _last_endgame_stage or heartforge == null:
        return
    _last_endgame_stage = stage
    play_profile(&"endgame_stage", heartforge.global_position, -8.0, 0.78 + float(stage) * 0.12)


func _on_endgame_completed(_protocol_id: StringName, _display_name: String, _ending: String) -> void:
    if heartforge != null:
        play_profile(&"endgame_complete", heartforge.global_position, -2.5, 1.12)


func _on_endgame_failed(_protocol_id: StringName, _reason: String) -> void:
    if heartforge != null:
        play_profile(&"endgame_failure", heartforge.global_position, -5.0, 0.66)


func _build_profile(profile: StringName) -> AudioStreamWAV:
    var duration := 0.2
    var profile_text := String(profile)
    if profile_text.begins_with("organic_attack_"):
        duration = 0.44
    elif profile_text.begins_with("organic_death_"):
        duration = 0.62
    else:
        match profile:
            &"machine_weapon":
                duration = 0.24
            &"machine_impact":
                duration = 0.2
            &"player_impact":
                duration = 0.24
            &"salvage":
                duration = 0.34
            &"forge":
                duration = 0.5
            &"organic_attack":
                duration = 0.28
            &"organic_impact":
                duration = 0.24
            &"organic_death":
                duration = 0.55
            &"heartforge_damage":
                duration = 0.34
            &"noise_pulse":
                duration = 0.16
            &"region_transition":
                duration = 0.78
            &"endgame_start":
                duration = 1.15
            &"endgame_stage":
                duration = 0.58
            &"endgame_complete":
                duration = 1.8
            &"endgame_failure":
                duration = 0.72

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
    var profile_text := String(profile)
    if profile_text.begins_with("organic_attack_") or profile_text.begins_with("organic_death_"):
        var death := profile_text.begins_with("organic_death_")
        var prefix := "organic_death_" if death else "organic_attack_"
        var species := StringName(profile_text.trim_prefix(prefix))
        return _sample_organic_signature(species, death, normalized, time, duration, envelope, noise)
    match profile:
        &"pistol":
            return (sin(TAU * (650.0 * time - 380.0 * time * time / duration)) * 0.46 + noise * 0.38) * envelope
        &"machine_weapon":
            return (sin(TAU * (190.0 * time + 110.0 * time * time / duration)) * 0.52 + sin(TAU * 820.0 * time) * 0.12) * envelope
        &"machine_impact":
            return (noise * 0.34 + sin(TAU * (250.0 * time - 90.0 * time * time / duration)) * 0.48 + sin(TAU * 540.0 * time) * 0.12) * envelope
        &"player_impact":
            return (noise * 0.3 + sin(TAU * (148.0 * time - 52.0 * time * time / duration)) * 0.5 + sin(TAU * 420.0 * time) * 0.12) * envelope
        &"salvage":
            return (sin(TAU * 92.0 * time) * 0.45 + sin(TAU * 184.0 * time) * 0.18 + noise * 0.09) * (0.35 + envelope * 0.65)
        &"forge":
            return (sin(TAU * 58.0 * time) * 0.5 + sin(TAU * 116.0 * time) * 0.2 + sin(TAU * 420.0 * time) * 0.1) * (0.3 + envelope * 0.7)
        &"organic_attack":
            return (noise * 0.58 + sin(TAU * (140.0 * time + 90.0 * time * time / duration)) * 0.34) * envelope
        &"organic_impact":
            return (noise * 0.62 + sin(TAU * (112.0 * time + 70.0 * time * time / duration)) * 0.38) * envelope
        &"organic_death":
            return (noise * 0.28 + sin(TAU * (360.0 * time - 270.0 * time * time / duration)) * 0.48) * envelope
        &"heartforge_damage":
            return (sin(TAU * 72.0 * time) * 0.56 + sin(TAU * 144.0 * time) * 0.18) * envelope
        &"noise_pulse":
            return sin(TAU * (280.0 * time + 210.0 * time * time / duration)) * envelope
        &"region_transition":
            var low := sin(TAU * 72.0 * time) * 0.36
            var fifth := sin(TAU * 108.0 * time) * 0.18
            var shimmer := sin(TAU * (420.0 * time + 80.0 * time * time / duration)) * 0.16
            return (low + fifth + shimmer + noise * 0.08) * envelope
        &"endgame_start":
            var sub_bass := sin(TAU * (48.0 * time + 34.0 * time * time / duration)) * 0.46
            var alarm := sin(TAU * 310.0 * time) * 0.18
            return (sub_bass + alarm + noise * 0.08) * (0.22 + envelope * 0.78)
        &"endgame_stage":
            return (sin(TAU * (90.0 * time + 150.0 * time * time / duration)) * 0.42 + noise * 0.16) * envelope
        &"endgame_complete":
            var root := sin(TAU * (62.0 * time + 28.0 * time * time / duration)) * 0.34
            var fifth := sin(TAU * (93.0 * time + 46.0 * time * time / duration)) * 0.24
            var crown := sin(TAU * 372.0 * time) * 0.16
            return (root + fifth + crown) * (0.2 + envelope * 0.8)
        &"endgame_failure":
            return (sin(TAU * (54.0 * time - 36.0 * time * time / duration)) * 0.48 + noise * 0.2) * envelope
    return 0.0


func _organic_profile_id(species: StringName, death: bool) -> StringName:
    var safe_species := String(species) if species in ORGANIC_SPECIES else "skitterling"
    return StringName("organic_death_%s" % safe_species if death else "organic_attack_%s" % safe_species)


func _organic_pitch(species: StringName, death: bool) -> float:
    var parameters := _organic_signature_parameters(species)
    var base := float(parameters.get("pitch", 1.0))
    return clampf(base * (0.92 if death else 1.0), 0.68, 1.34)


func _organic_signature_parameters(species: StringName) -> Dictionary:
    match species:
        &"veilstalker":
            return {"base": 178.0, "overtone": 410.0, "pitch": 1.08, "texture": 0.16, "sweep": 72.0}
        &"razorhound":
            return {"base": 124.0, "overtone": 286.0, "pitch": 0.94, "texture": 0.36, "sweep": 118.0}
        &"apex":
            return {"base": 58.0, "overtone": 172.0, "pitch": 0.72, "texture": 0.22, "sweep": 34.0}
        &"sporecaster":
            return {"base": 92.0, "overtone": 348.0, "pitch": 0.86, "texture": 0.42, "sweep": 52.0}
        &"broodmass":
            return {"base": 68.0, "overtone": 136.0, "pitch": 0.76, "texture": 0.31, "sweep": 28.0}
        &"burrower":
            return {"base": 82.0, "overtone": 218.0, "pitch": 0.82, "texture": 0.46, "sweep": 44.0}
        &"roofleaper":
            return {"base": 232.0, "overtone": 612.0, "pitch": 1.24, "texture": 0.25, "sweep": 142.0}
        &"glassmoth":
            return {"base": 318.0, "overtone": 860.0, "pitch": 1.3, "texture": 0.12, "sweep": 206.0}
        &"miremaw":
            return {"base": 104.0, "overtone": 244.0, "pitch": 0.88, "texture": 0.54, "sweep": 36.0}
        &"carrionbell":
            return {"base": 148.0, "overtone": 296.0, "pitch": 0.98, "texture": 0.18, "sweep": -52.0}
        &"rootweaver":
            return {"base": 74.0, "overtone": 196.0, "pitch": 0.8, "texture": 0.38, "sweep": 22.0}
        &"thornback":
            return {"base": 116.0, "overtone": 248.0, "pitch": 0.92, "texture": 0.48, "sweep": 96.0}
        &"ashmantle":
            return {"base": 86.0, "overtone": 322.0, "pitch": 0.88, "texture": 0.28, "sweep": -68.0}
        _:
            return {"base": 206.0, "overtone": 480.0, "pitch": 1.0, "texture": 0.32, "sweep": 84.0}


func _sample_organic_signature(species: StringName, death: bool, normalized: float, time: float, duration: float, envelope: float, noise: float) -> float:
    var parameters := _organic_signature_parameters(species)
    var base := float(parameters["base"])
    var overtone := float(parameters["overtone"])
    var texture := float(parameters["texture"])
    var sweep := float(parameters["sweep"])
    var direction := -1.0 if death else 1.0
    var body := sin(TAU * (base * time + direction * sweep * time * time / duration)) * (0.5 if death else 0.42)
    var harmonic := sin(TAU * (overtone * time + sweep * 0.35 * time)) * (0.16 if death else 0.23)
    var rasp := noise * texture
    var pulse := sin(TAU * (2.0 + (3.0 if death else 5.0)) * normalized) * 0.08
    return (body + harmonic + rasp + pulse) * envelope
