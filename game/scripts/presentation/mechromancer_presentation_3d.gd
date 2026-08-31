class_name MechromancerPresentation3D
extends Node

## Presentation-only controller for the authored Mechromancer asset.
## Gameplay remains owned by Mechromancer3D; this node only selects imported
## animation clips and provides a small fallback motion when the asset is not
## imported yet.

var subject: Node3D
var model_root: Node3D
var animation_player: AnimationPlayer
var last_health: float = -1.0
var fire_remaining: float = 0.0
var hit_remaining: float = 0.0
var fallback_time: float = 0.0
var progression_time: float = 0.0
var active_clip: StringName = &""


func configure(next_subject: Node3D) -> void:
    subject = next_subject


func _ready() -> void:
    if subject == null:
        subject = get_parent() as Node3D
    if subject == null:
        set_process(false)
        return
    if subject is Mechromancer3D:
        # Presentation may attach after the actor emitted its initial health
        # signal. Seed the comparison baseline so the first real damage event
        # selects Hit instead of being mistaken for initialization.
        last_health = (subject as Mechromancer3D).current_health
    model_root = subject.get_node_or_null("MechromancerModel") as Node3D
    if model_root != null:
        animation_player = _find_animation_player(model_root)
    _connect_subject_signals()
    if animation_player != null:
        _configure_animation_loops()
    call_deferred("_select_loop_clip")


func _process(delta: float) -> void:
    if subject == null or not is_instance_valid(subject):
        return
    fallback_time += delta
    progression_time += delta
    fire_remaining = maxf(0.0, fire_remaining - delta)
    hit_remaining = maxf(0.0, hit_remaining - delta)
    _animate_progression_hardware()

    if animation_player == null:
        _animate_fallback(delta)
        return
    if fire_remaining > 0.0 or hit_remaining > 0.0:
        return
    _select_loop_clip()


func _connect_subject_signals() -> void:
    if subject.has_signal(&"pistol_fired"):
        _connect_once(subject, &"pistol_fired", Callable(self, "_on_pistol_fired"))
    if subject.has_signal(&"health_changed"):
        _connect_once(subject, &"health_changed", Callable(self, "_on_health_changed"))
    if subject.has_signal(&"channel_started"):
        _connect_once(subject, &"channel_started", Callable(self, "_on_channel_started"))
    if subject.has_signal(&"channel_completed"):
        _connect_once(subject, &"channel_completed", Callable(self, "_on_channel_finished"))
    if subject.has_signal(&"channel_cancelled"):
        _connect_once(subject, &"channel_cancelled", Callable(self, "_on_channel_finished"))


func _connect_once(source: Object, signal_name: StringName, callback: Callable) -> void:
    if not source.is_connected(signal_name, callback):
        source.connect(signal_name, callback)


func _configure_animation_loops() -> void:
    for clip_name in [&"Idle", &"Walk", &"Work", &"Upgrade"]:
        var resolved := _resolve_clip(clip_name)
        if resolved == &"":
            continue
        var animation := animation_player.get_animation(resolved)
        if animation != null:
            animation.loop_mode = Animation.LOOP_LINEAR


func _select_loop_clip() -> void:
    if animation_player == null or fire_remaining > 0.0 or hit_remaining > 0.0:
        return
    var selected := &"Idle"
    var channel := StringName(str(subject.get("channel_kind")))
    if channel == &"forge_upgrade":
        selected = &"Upgrade"
    elif channel != &"":
        selected = &"Work"
    elif subject is CharacterBody3D:
        var body := subject as CharacterBody3D
        if Vector2(body.velocity.x, body.velocity.z).length() > 0.25:
            selected = &"Walk"
    _play_clip(selected, true)


func _play_clip(requested: StringName, looping: bool = false) -> void:
    if animation_player == null:
        return
    var resolved := _resolve_clip(requested)
    if resolved == &"":
        return
    if looping and active_clip == resolved and animation_player.is_playing():
        return
    animation_player.play(resolved, 0.12)
    active_clip = resolved


func _resolve_clip(requested: StringName) -> StringName:
    if animation_player == null:
        return &""
    if animation_player.has_animation(requested):
        return requested
    for candidate in animation_player.get_animation_list():
        var candidate_text := String(candidate)
        if candidate_text.ends_with("/" + String(requested)) or candidate_text.ends_with(String(requested)):
            return StringName(candidate_text)
    return &""


func _on_pistol_fired(_origin: Vector3, _target: Vector3, _target_node: Node) -> void:
    fire_remaining = 0.24
    _play_clip(&"Fire")


func _on_health_changed(current: Variant, _maximum: Variant = null) -> void:
    var current_value := float(current)
    if last_health >= 0.0 and current_value < last_health:
        hit_remaining = 0.28
        _play_clip(&"Hit")
    last_health = current_value


func _on_channel_started(_kind: StringName, _duration: float, _description: String) -> void:
    _play_clip(&"Upgrade" if _kind == &"forge_upgrade" else &"Work", true)


func _on_channel_finished(_kind: StringName, _target: Node, _metadata: Dictionary) -> void:
    _select_loop_clip()


func _animate_fallback(delta: float) -> void:
    if model_root == null:
        return
    var speed := 0.0
    if subject is CharacterBody3D:
        var body := subject as CharacterBody3D
        speed = Vector2(body.velocity.x, body.velocity.z).length()
    var movement := clampf(speed / 4.5, 0.0, 1.0)
    model_root.position.y = sin(fallback_time * 1.35) * 0.012
    model_root.rotation.z = sin(fallback_time * 8.0) * 0.018 * movement


func _animate_progression_hardware() -> void:
    if subject == null or not is_instance_valid(subject):
        return
    var progression_root := subject.get_node_or_null("MechromancerProgressionVisuals") as Node3D
    if progression_root == null or not progression_root.visible:
        return

    # These are intentionally small, low-frequency hardware responses. They
    # make the player's learned machine language feel alive while preserving
    # the human field-engineer silhouette, collision capsule and imported clip
    # ownership. The nodes are resolved each frame because progression rebuilds
    # replace this derived root synchronously.
    var cognition_rail := progression_root.get_node_or_null("MechromancerTierIIICognitionRail") as Node3D
    if cognition_rail != null:
        cognition_rail.rotation.z = sin(progression_time * 1.7) * 0.025

    var cognition_node := progression_root.get_node_or_null("MechromancerTierIIICognitionNode") as Node3D
    if cognition_node != null:
        var cognition_pulse := 1.0 + sin(progression_time * 2.4 + 0.6) * 0.11
        cognition_node.scale = Vector3.ONE * cognition_pulse

    var signal_pin := progression_root.get_node_or_null("MechromancerTierIISignalPin") as Node3D
    if signal_pin != null:
        signal_pin.rotation.y = fmod(progression_time * 0.8, TAU)

    var bio_sensor_lens := progression_root.get_node_or_null("MechromancerTierIVBioSensorLens") as Node3D
    if bio_sensor_lens != null:
        var sensor_sweep := 1.0 + sin(progression_time * 1.35 + 1.4) * 0.08
        bio_sensor_lens.scale = Vector3(1.2, 0.42, 0.8) * sensor_sweep
        bio_sensor_lens.rotation.y = sin(progression_time * 0.9) * 0.12

    var heat_vent := progression_root.get_node_or_null("MechromancerTierVHeatVent") as Node3D
    if heat_vent != null:
        heat_vent.rotation.x = sin(progression_time * 1.1 + 0.9) * 0.035


func _find_animation_player(root: Node) -> AnimationPlayer:
    if root is AnimationPlayer:
        return root as AnimationPlayer
    for child in root.get_children():
        var result := _find_animation_player(child)
        if result != null:
            return result
    return null
