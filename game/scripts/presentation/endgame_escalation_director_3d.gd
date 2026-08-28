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
var built_protocol: StringName = &""
var _lattice_materials: Array[StandardMaterial3D] = []
var _completion_materials: Array[StandardMaterial3D] = []
var _stage_roots: Array[Node3D] = []
var _last_stage: int = -1
var _pulse_clock: float = 0.0
const SANCTUARY_CROWN_START_SCALE := 0.48
const SANCTUARY_CROWN_TARGET_SCALE := 0.58
const SANCTUARY_CROWN_EMISSION := 0.34
const SANCTUARY_CORE_LIGHT_ENERGY := 0.68


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
        var target_energy := SANCTUARY_CORE_LIGHT_ENERGY if current_state == &"completed" else 0.45 + current_progress * 0.65
        core_light.light_energy = lerpf(core_light.light_energy, target_energy, clampf(delta * 5.0, 0.0, 1.0))


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
        if built_protocol != current_protocol:
            visual_root.free()
            visual_root = null
            lattice_root = null
            completion_root = null
            pulse_ring = null
            core_light = null
            _stage_roots.clear()
            _lattice_materials.clear()
            _completion_materials.clear()
            _last_stage = -1
        else:
            visual_root.visible = true
            return
    if world == null or heartforge == null:
        return
    visual_root = Node3D.new()
    visual_root.name = "EndgameProtocolVisuals"
    world.add_child(visual_root)
    visual_root.global_position = _heartforge_capstone_anchor()

    lattice_root = Node3D.new()
    lattice_root.name = "ProtocolLattice"
    visual_root.add_child(lattice_root)

    var transformation_protocol := current_protocol == &"protocol.transformation"
    built_protocol = current_protocol
    var lattice_mat := ModelKit3D.material(Color("27453d") if transformation_protocol else Color("3b202f"), 0.42, 0.34, Color("4dd6a0") if transformation_protocol else Color("d93458"), 0.28)
    var accent_mat := ModelKit3D.material(Color("35634d") if transformation_protocol else Color("6a3825"), 0.3, 0.3, Color("a5e66f") if transformation_protocol else Color("d88239"), 0.42)
    _lattice_materials = [lattice_mat, accent_mat]

    # The crisis must frame the Heartforge rather than cage the player. Keep
    # the same staged lattice language, but lower the rings and tighten the
    # footprint so the active cast remains visible at the tactical camera.
    _add_ring(lattice_root, 2.52, 2.62, Vector3(0.0, 0.14, 0.0), lattice_mat, "ProtocolBaseRing")
    pulse_ring = _add_ring(lattice_root, 1.72, 1.80, Vector3(0.0, 0.30, 0.0), accent_mat, "ProtocolPulseRing")
    _add_ring(lattice_root, 0.82, 0.92, Vector3(0.0, 2.18, 0.0), accent_mat, "ProtocolCoreHalo")

    for index in range(6):
        var angle := TAU * float(index) / 6.0
        var position := Vector3(cos(angle) * 2.24, 1.72, sin(angle) * 2.24)
        ModelKit3D.add_capsule(lattice_root, 0.075, 3.0, position, lattice_mat, Vector3.ZERO, "ProtocolSpine%d" % index)

    if transformation_protocol:
        # Transformation is the living-partnership ending: two crossed,
        # low-energy loops make it visibly different from the severance and
        # containment cages without changing the crisis footprint or player
        # collision. The loops read as a negotiated braid around the Heartforge.
        ModelKit3D.add_torus(lattice_root, 1.18, 0.055, Vector3(0.0, 1.35, 0.0), accent_mat, Vector3(PI * 0.5, 0.0, 0.18), "ProtocolLivingLoopA", 40, 8)
        ModelKit3D.add_torus(lattice_root, 1.18, 0.055, Vector3(0.0, 1.35, 0.0), accent_mat, Vector3(0.0, 0.0, PI * 0.5), "ProtocolLivingLoopB", 40, 8)

    for stage_index in range(3):
        var stage_root := Node3D.new()
        stage_root.name = "ProtocolStage%d" % stage_index
        lattice_root.add_child(stage_root)
        _stage_roots.append(stage_root)
        var radius := 1.86 + float(stage_index) * 0.32
        var height := 1.58 + float(stage_index) * 0.82
        for index in range(3 + stage_index):
            var angle := TAU * float(index) / float(3 + stage_index) + float(stage_index) * 0.28
            var position := Vector3(cos(angle) * radius, height, sin(angle) * radius)
            ModelKit3D.add_tapered_cylinder(stage_root, 0.055, 0.09, 0.86 + float(stage_index) * 0.28, position, accent_mat, Vector3(0.0, 0.0, angle), "ProtocolArc%d_%d" % [stage_index, index])
        _add_ring(stage_root, radius - 0.07, radius, Vector3(0.0, height - 0.52, 0.0), lattice_mat, "ProtocolStageRing%d" % stage_index)

    completion_root = Node3D.new()
    completion_root.name = "SanctuaryCrown"
    completion_root.visible = false
    visual_root.add_child(completion_root)
    var completion_mat := ModelKit3D.material(Color("3e866d") if transformation_protocol else Color("4f746d"), 0.46, 0.26, Color("8ff3b4") if transformation_protocol else Color("69f0d2"), 4.6)
    var completion_accent := ModelKit3D.material(Color("6e8d3d") if transformation_protocol else Color("8b6331"), 0.38, 0.28, Color("d7ff8a") if transformation_protocol else Color("ffd36a"), 3.8)
    _completion_materials = [completion_mat, completion_accent]
    _add_ring(completion_root, 3.3, 3.4, Vector3(0.0, 0.26, 0.0), completion_mat, "SanctuaryCrownRing")
    for index in range(8):
        var angle := TAU * float(index) / 8.0
        var position := Vector3(cos(angle) * 2.78, 3.45, sin(angle) * 2.78)
        ModelKit3D.add_beveled_box(completion_root, Vector3(0.22, 2.35, 0.38), position, completion_mat, Vector3(0.0, -angle, angle * 0.16), "SanctuaryCrownFin%d" % index, 0.16)
    if transformation_protocol:
        ModelKit3D.add_torus(completion_root, 2.18, 0.08, Vector3(0.0, 2.25, 0.0), completion_accent, Vector3(PI * 0.5, 0.0, 0.0), "SanctuaryLivingLoop", 48, 8)
    ModelKit3D.add_cylinder(completion_root, 0.32, 1.5, Vector3(0.0, 4.75, 0.0), completion_accent, Vector3.ZERO, "SanctuaryCrownBeacon")

    core_light = OmniLight3D.new()
    core_light.name = "ProtocolCoreLight"
    core_light.light_color = Color("ff5d73")
    core_light.light_energy = 0.45
    core_light.omni_range = 15.0
    core_light.position = Vector3(0.0, 2.5, 0.0)
    visual_root.add_child(core_light)


func _add_ring(parent: Node3D, inner_radius: float, outer_radius: float, position: Vector3, material: StandardMaterial3D, node_name: String) -> MeshInstance3D:
    var ring := MeshInstance3D.new()
    ring.name = node_name
    var ring_mesh := TorusMesh.new()
    ring_mesh.inner_radius = inner_radius
    ring_mesh.outer_radius = outer_radius
    ring_mesh.rings = 20
    ring_mesh.ring_segments = 40
    ring.mesh = ring_mesh
    ring.material_override = material
    ring.position = position
    parent.add_child(ring)
    return ring


func _heartforge_capstone_anchor() -> Vector3:
    var approach := _capstone_approach()
    # Place the capstone toward, but offset from, the player-facing side. A
    # centered lattice occupies the cast's silhouette during the crisis; the
    # lateral offset lets the player and Bulwark remain judgeable while the
    # transformation still reads against the Heartforge.
    var lateral := Vector3.UP.cross(approach).normalized()
    return heartforge.global_position + approach * 4.2 + lateral * 2.15 + Vector3.UP * 0.35


func _capstone_approach() -> Vector3:
    var approach := Vector3(0.0, 0.0, 1.0)
    if world != null:
        var focus := world.get("player") as Node3D
        if focus != null:
            var planar_approach := focus.global_position - heartforge.global_position
            planar_approach.y = 0.0
            if planar_approach.length_squared() > 0.04:
                approach = planar_approach.normalized()
    return approach


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
    var crisis := Color("4dd6a0").lerp(Color("d7ff8a"), clampf(progress * 1.8, 0.0, 1.0)) if current_protocol == &"protocol.transformation" else Color("ff4d6d").lerp(Color("ffb347"), clampf(progress * 1.8, 0.0, 1.0))
    if current_protocol != &"protocol.transformation" and progress > 0.72:
        crisis = crisis.lerp(Color("d76aff"), (progress - 0.72) / 0.28)
    for material in _lattice_materials:
        material.emission = crisis
        material.emission_energy_multiplier = 0.20 + progress * 0.34
    if core_light != null:
        core_light.light_color = crisis
        core_light.light_energy = 0.45 + current_progress * 0.65


func _show_completion() -> void:
    if visual_root == null:
        return
    visual_root.visible = true
    lattice_root.visible = false
    completion_root.visible = true
    # The completed sanctuary is a quiet backdrop for the surviving cast, not
    # a second foreground cage. Pull it farther behind the Heartforge-facing
    # approach and keep the crown compact so its fins frame the settlement
    # without competing with the Mechromancer or Bulwark in the close tactical
    # camera.
    completion_root.position = -_capstone_approach() * 2.30
    completion_root.scale = Vector3.ONE * SANCTUARY_CROWN_START_SCALE
    for material in _completion_materials:
        material.emission_energy_multiplier = SANCTUARY_CROWN_EMISSION
    if core_light != null:
        core_light.light_color = Color("8ff3b4") if current_protocol == &"protocol.transformation" else Color("69f0d2")
        core_light.light_energy = SANCTUARY_CORE_LIGHT_ENERGY
    var tween := create_tween()
    tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    tween.tween_property(completion_root, "scale", Vector3.ONE * SANCTUARY_CROWN_TARGET_SCALE, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _connect_once(source: Object, signal_name: StringName, callback: Callable) -> void:
    if source != null and source.has_signal(signal_name) and not source.is_connected(signal_name, callback):
        source.connect(signal_name, callback)
