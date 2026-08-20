class_name EndgameEscalationDirector3D
extends Node

## Owns the final-protocol visual language without owning any simulation state.
## The lattice is a bounded Heartforge capstone: it grows in readable stages as
## the causal response advances, then resolves into a calm sanctuary crown.

signal visual_state_changed(state: StringName, progress: float)

var world: Node3D
var heartforge: Heartforge3D
var endgame_director: EndgameDirector3D
var visual_root: Node3D
var lattice_root: Node3D
var completion_root: Node3D
var pulse_ring: MeshInstance3D
var core_light: OmniLight3D
var current_state: StringName = &"dormant"
var current_progress: float = 0.0
var current_protocol: StringName = &""
var _lattice_materials: Array[StandardMaterial3D] = []
var _completion_materials: Array[StandardMaterial3D] = []
var _stage_roots: Array[Node3D] = []
var _last_stage: int = -1
var _pulse_clock: float = 0.0


func configure(next_world: Node3D, next_heartforge: Heartforge3D, next_endgame_director: EndgameDirector3D) -> void:
    world = next_world
    heartforge = next_heartforge
    endgame_director = next_endgame_director


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    if endgame_director != null:
        _connect_once(endgame_director, &"endgame_started", Callable(self, "_on_endgame_started"))
        _connect_once(endgame_director, &"endgame_progress", Callable(self, "_on_endgame_progress"))
        _connect_once(endgame_director, &"endgame_completed", Callable(self, "_on_endgame_completed"))
        _connect_once(endgame_director, &"endgame_failed", Callable(self, "_on_endgame_failed"))
    sync_from_endgame_state()


func _process(delta: float) -> void:
    if lattice_root == null or not is_instance_valid(lattice_root):
        return
    _pulse_clock += delta
    lattice_root.rotation.y += delta * (0.18 + current_progress * 0.6)
    var pulse := 1.0 + sin(_pulse_clock * (2.4 + current_progress * 3.0)) * (0.025 + current_progress * 0.045)
    lattice_root.scale = Vector3.ONE * (0.74 + current_progress * 0.34) * pulse
    if pulse_ring != null:
        var ring_pulse := 1.0 + sin(_pulse_clock * 3.1) * (0.035 + current_progress * 0.06)
        pulse_ring.scale = Vector3(ring_pulse, 1.0, ring_pulse)
    if core_light != null:
        core_light.light_energy = lerpf(core_light.light_energy, 3.8 + current_progress * 7.0, clampf(delta * 5.0, 0.0, 1.0))


func sync_from_endgame_state() -> void:
    if endgame_director == null:
        return
    if not endgame_director.active_protocol.is_empty():
        current_protocol = StringName(endgame_director.active_protocol.get("id", &""))
        current_state = &"active"
        current_progress = endgame_director.progress_fraction()
        _ensure_lattice()
        _apply_lattice_progress(current_progress)
    elif endgame_director.completed_protocol != &"":
        current_protocol = endgame_director.completed_protocol
        current_state = &"completed"
        current_progress = 1.0
        _ensure_lattice()
        _show_completion()
    else:
        current_state = &"dormant"
        current_progress = 0.0


func _on_endgame_started(protocol_id: StringName, _display_name: String) -> void:
    current_protocol = protocol_id
    current_state = &"active"
    current_progress = 0.0
    _ensure_lattice()
    _apply_lattice_progress(0.0)
    visual_state_changed.emit(current_state, current_progress)


func _on_endgame_progress(protocol_id: StringName, progress: float, _detail: String) -> void:
    if current_state != &"active" or protocol_id != current_protocol:
        return
    current_progress = clampf(progress, 0.0, 1.0)
    _apply_lattice_progress(current_progress)
    visual_state_changed.emit(current_state, current_progress)


func _on_endgame_completed(protocol_id: StringName, _display_name: String, _ending: String) -> void:
    if current_protocol != &"" and protocol_id != current_protocol:
        return
    current_protocol = protocol_id
    current_state = &"completed"
    current_progress = 1.0
    _ensure_lattice()
    _show_completion()
    visual_state_changed.emit(current_state, current_progress)


func _on_endgame_failed(protocol_id: StringName, _reason: String) -> void:
    if current_protocol != &"" and protocol_id != current_protocol:
        return
    current_protocol = protocol_id
    current_state = &"failed"
    current_progress = 0.0
    if visual_root != null:
        visual_root.visible = false
    visual_state_changed.emit(current_state, current_progress)


func _ensure_lattice() -> void:
    if visual_root != null and is_instance_valid(visual_root):
        visual_root.visible = true
        return
    if world == null or heartforge == null:
        return
    visual_root = Node3D.new()
    visual_root.name = "EndgameProtocolVisuals"
    world.add_child(visual_root)
    visual_root.global_position = heartforge.global_position

    lattice_root = Node3D.new()
    lattice_root.name = "ProtocolLattice"
    visual_root.add_child(lattice_root)

    var lattice_mat := ModelKit3D.material(Color("3b202f"), 0.42, 0.34, Color("ff4d6d"), 3.2)
    var accent_mat := ModelKit3D.material(Color("6a3825"), 0.3, 0.3, Color("ff963f"), 4.0)
    _lattice_materials = [lattice_mat, accent_mat]

    ModelKit3D.add_cylinder(lattice_root, 3.28, 0.12, Vector3(0.0, 0.18, 0.0), lattice_mat, Vector3.ZERO, "ProtocolBaseRing")
    pulse_ring = ModelKit3D.add_cylinder(lattice_root, 2.25, 0.08, Vector3(0.0, 0.34, 0.0), accent_mat, Vector3.ZERO, "ProtocolPulseRing")
    ModelKit3D.add_cylinder(lattice_root, 1.18, 0.16, Vector3(0.0, 2.5, 0.0), accent_mat, Vector3.ZERO, "ProtocolCoreHalo")

    for index in range(8):
        var angle := TAU * float(index) / 8.0
        var position := Vector3(cos(angle) * 2.82, 2.25, sin(angle) * 2.82)
        ModelKit3D.add_beveled_box(lattice_root, Vector3(0.16, 4.0, 0.26), position, lattice_mat, Vector3(0.0, -angle, 0.0), "ProtocolSpine%d" % index, 0.18)

    for stage_index in range(3):
        var stage_root := Node3D.new()
        stage_root.name = "ProtocolStage%d" % stage_index
        lattice_root.add_child(stage_root)
        _stage_roots.append(stage_root)
        var radius := 2.5 + float(stage_index) * 0.42
        var height := 2.0 + float(stage_index) * 1.05
        for index in range(4 + stage_index * 2):
            var angle := TAU * float(index) / float(4 + stage_index * 2) + float(stage_index) * 0.28
            var position := Vector3(cos(angle) * radius, height, sin(angle) * radius)
            ModelKit3D.add_tapered_cylinder(stage_root, 0.07, 0.12, 1.1 + float(stage_index) * 0.4, position, accent_mat, Vector3(0.0, 0.0, angle), "ProtocolArc%d_%d" % [stage_index, index])
        ModelKit3D.add_cylinder(stage_root, radius, 0.07, Vector3(0.0, height - 0.52, 0.0), lattice_mat, Vector3.ZERO, "ProtocolStageRing%d" % stage_index)

    completion_root = Node3D.new()
    completion_root.name = "SanctuaryCrown"
    completion_root.visible = false
    visual_root.add_child(completion_root)
    var completion_mat := ModelKit3D.material(Color("4f746d"), 0.46, 0.26, Color("69f0d2"), 4.6)
    var completion_accent := ModelKit3D.material(Color("8b6331"), 0.38, 0.28, Color("ffd36a"), 3.8)
    _completion_materials = [completion_mat, completion_accent]
    ModelKit3D.add_cylinder(completion_root, 3.4, 0.1, Vector3(0.0, 0.26, 0.0), completion_mat, Vector3.ZERO, "SanctuaryCrownRing")
    for index in range(8):
        var angle := TAU * float(index) / 8.0
        var position := Vector3(cos(angle) * 2.78, 3.45, sin(angle) * 2.78)
        ModelKit3D.add_beveled_box(completion_root, Vector3(0.22, 2.35, 0.38), position, completion_mat, Vector3(0.0, -angle, angle * 0.16), "SanctuaryCrownFin%d" % index, 0.16)
    ModelKit3D.add_cylinder(completion_root, 0.32, 1.5, Vector3(0.0, 4.75, 0.0), completion_accent, Vector3.ZERO, "SanctuaryCrownBeacon")

    core_light = OmniLight3D.new()
    core_light.name = "ProtocolCoreLight"
    core_light.light_color = Color("ff5d73")
    core_light.light_energy = 3.8
    core_light.omni_range = 15.0
    core_light.position = Vector3(0.0, 2.5, 0.0)
    visual_root.add_child(core_light)


func _apply_lattice_progress(progress: float) -> void:
    if visual_root == null:
        return
    visual_root.visible = true
    lattice_root.visible = true
    completion_root.visible = false
    for index in range(_stage_roots.size()):
        _stage_roots[index].visible = progress >= float(index) * 0.32
    var stage := mini(2, int(floor(progress * 3.0)))
    if stage != _last_stage:
        _last_stage = stage
        visual_state_changed.emit(StringName("stage_%d" % stage), progress)
    var crisis := Color("ff4d6d").lerp(Color("ffb347"), clampf(progress * 1.8, 0.0, 1.0))
    if progress > 0.72:
        crisis = crisis.lerp(Color("d76aff"), (progress - 0.72) / 0.28)
    for material in _lattice_materials:
        material.emission = crisis
        material.emission_energy_multiplier = 3.2 + progress * 2.6
    if core_light != null:
        core_light.light_color = crisis


func _show_completion() -> void:
    if visual_root == null:
        return
    visual_root.visible = true
    lattice_root.visible = false
    completion_root.visible = true
    completion_root.scale = Vector3.ONE * 0.72
    for material in _completion_materials:
        material.emission_energy_multiplier = 4.8
    if core_light != null:
        core_light.light_color = Color("69f0d2")
        core_light.light_energy = 8.5
    var tween := create_tween()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(completion_root, "scale", Vector3.ONE, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _connect_once(source: Object, signal_name: StringName, callback: Callable) -> void:
    if source != null and source.has_signal(signal_name) and not source.is_connected(signal_name, callback):
        source.connect(signal_name, callback)
