class_name AuthoredActorAnimation3D
extends Node

## Runtime bridge for imported robot and organic animation clips.
##
## Gameplay remains owned by the actor. This node only maps the actor's
## explainable state to the authored clips already present in its glTF model.
## ProceduralAnimator3D continues to provide small secondary motion and LOD
## cadence; this controller owns the primary role/readability beat.

var subject: Node3D
var model_root: Node3D
var animation_player: AnimationPlayer
var active_clip: StringName = &""
var one_shot_remaining: float = 0.0
var _has_state_name: bool = false
var _has_attack_windup: bool = false
var _has_visual_lod_level: bool = false
var _has_current_health: bool = false
var _last_health: float = -1.0


func configure(next_subject: Node3D) -> void:
    subject = next_subject


func _ready() -> void:
    if subject == null:
        subject = get_parent() as Node3D
    if subject == null:
        set_process(false)
        return
    _has_state_name = _property_exists(subject, &"state_name")
    _has_attack_windup = _property_exists(subject, &"attack_windup_remaining")
    _has_visual_lod_level = _property_exists(subject, &"visual_lod_level")
    _has_current_health = _property_exists(subject, &"current_health")
    if _has_current_health:
        _last_health = float(subject.get(&"current_health"))
    model_root = _resolve_model_root()
    if model_root != null:
        animation_player = _find_animation_player(model_root)
    _connect_subject_signals()
    if animation_player == null:
        set_process(false)
        return
    _configure_animation_loops()
    call_deferred("_select_loop_clip")


func _process(delta: float) -> void:
    if subject == null or not is_instance_valid(subject) or animation_player == null:
        return
    one_shot_remaining = maxf(0.0, one_shot_remaining - delta)
    if _has_visual_lod_level and int(subject.get(&"visual_lod_level")) >= 2:
        return
    if one_shot_remaining > 0.0:
        return
    if _state_name() == &"dead":
        return
    _select_loop_clip()


func _resolve_model_root() -> Node3D:
    if subject == null:
        return null
    for candidate_name in [&"RobotModel", &"OrganicModel"]:
        var candidate := subject.get_node_or_null(NodePath(String(candidate_name))) as Node3D
        if candidate != null:
            return candidate
    return null


func _connect_subject_signals() -> void:
    if subject == null:
        return
    if subject.has_signal(&"weapon_fired"):
        _connect_once(subject, &"weapon_fired", Callable(self, "_on_weapon_fired"))
    if subject.has_signal(&"attack_started"):
        _connect_once(subject, &"attack_started", Callable(self, "_on_attack_started"))
    if subject.has_signal(&"killed"):
        _connect_once(subject, &"killed", Callable(self, "_on_killed"))
    if subject.has_signal(&"health_changed"):
        _connect_once(subject, &"health_changed", Callable(self, "_on_health_changed"))


func _connect_once(source: Object, signal_name: StringName, callback: Callable) -> void:
    if source.has_signal(signal_name) and not source.is_connected(signal_name, callback):
        source.connect(signal_name, callback)


func _configure_animation_loops() -> void:
    for clip_name in [&"Idle", &"Walk", &"Work", &"Survey", &"Feed", &"Nest", &"Retreat"]:
        var resolved := _resolve_clip(clip_name)
        if resolved == &"":
            continue
        var animation := animation_player.get_animation(resolved)
        if animation != null:
            animation.loop_mode = Animation.LOOP_LINEAR


func _select_loop_clip() -> void:
    if animation_player == null or one_shot_remaining > 0.0:
        return
    var selected := &"Idle"
    var state := _state_name()
    if subject.is_in_group(&"friendly_robots"):
        if state in [&"salvaging", &"repairing", &"building"]:
            selected = &"Work"
        elif _is_moving(state):
            selected = &"Walk"
    elif subject.is_in_group(&"organic_enemies"):
        if state == &"attacking" and _has_attack_windup and float(subject.get(&"attack_windup_remaining")) > 0.0:
            _play_one_shot(&"Attack")
            return
        var behaviour := _behaviour_name()
        if state == &"feeding" or behaviour == &"feed":
            selected = &"Feed"
        elif state == &"nest_guard" or behaviour in [&"guard_nest", &"nest_guard"]:
            selected = &"Nest"
        elif state == &"retreating" or behaviour == &"retreat":
            selected = &"Retreat"
        elif _is_moving(state):
            selected = &"Walk"
    _play_clip(selected, true)


func _is_moving(state: StringName) -> bool:
    if state in [&"moving", &"hunting", &"investigating", &"scouting", &"patrolling", &"retreating"]:
        return true
    if subject is CharacterBody3D:
        var body := subject as CharacterBody3D
        return Vector2(body.velocity.x, body.velocity.z).length() > 0.25
    return false


func _play_one_shot(requested: StringName) -> void:
    var resolved := _resolve_clip(requested)
    if resolved == &"":
        return
    _play_clip(resolved, false)
    var animation := animation_player.get_animation(resolved)
    one_shot_remaining = maxf(0.18, animation.length if animation != null else 0.24)


func _play_clip(requested: StringName, looping: bool) -> void:
    if animation_player == null:
        return
    var resolved := _resolve_clip(requested)
    if resolved == &"":
        return
    if looping and active_clip == resolved and animation_player.is_playing():
        return
    animation_player.play(resolved, 0.10)
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


func _on_weapon_fired(_origin: Vector3, _target: Vector3, _target_node: Node) -> void:
    _play_one_shot(&"Fire")


func _on_attack_started(_enemy: Node, _target: Node) -> void:
    _play_one_shot(&"Attack")


func _on_killed(_enemy: Node, _killer: Node) -> void:
    _play_one_shot(&"Death")


func _on_health_changed(_actor: Node, current: float, _maximum: float) -> void:
    var was_damaged := _last_health >= 0.0 and current < _last_health and current > 0.0
    _last_health = current
    if was_damaged:
        _play_one_shot(&"Hit")


func _state_name() -> StringName:
    if not _has_state_name:
        return &""
    return StringName(subject.get(&"state_name"))


func _behaviour_name() -> StringName:
    if subject == null or not subject.has_meta(&"enemy_behaviour"):
        return &""
    return StringName(str(subject.get_meta(&"enemy_behaviour", "")))


func _property_exists(object: Object, property_name: StringName) -> bool:
    for property in object.get_property_list():
        if StringName(property.get("name", "")) == property_name:
            return true
    return false


func _find_animation_player(root: Node) -> AnimationPlayer:
    if root is AnimationPlayer:
        return root as AnimationPlayer
    for child in root.get_children():
        var result := _find_animation_player(child)
        if result != null:
            return result
    return null
