class_name MachineSocietyDirector3D
extends Node

signal autonomous_machine_built(archetype: StringName, level: int, reason: String)
signal society_status_changed(status: String)

var run_state: RunState3D
var progression: ProgressionDirector3D
var autonomy_director: AutonomyDirector3D
var heartforge: Heartforge3D
var noise_system: NoiseSystem3D
var spawn_robot_callback: Callable
var evaluation_clock: float = 0.0
var fabrication_clock: float = 0.0
var last_status: String = "Manual fabrication remains required."
var autonomous_builds: int = 0


func configure(
        next_run_state: RunState3D,
        next_progression: ProgressionDirector3D,
        next_autonomy_director: AutonomyDirector3D,
        next_heartforge: Heartforge3D,
        next_noise_system: NoiseSystem3D,
        next_spawn_robot_callback: Callable
    ) -> void:
    run_state = next_run_state
    progression = next_progression
    autonomy_director = next_autonomy_director
    heartforge = next_heartforge
    noise_system = next_noise_system
    spawn_robot_callback = next_spawn_robot_callback


func _process(delta: float) -> void:
    if run_state == null or progression == null or autonomy_director == null:
        return
    fabrication_clock = maxf(0.0, fabrication_clock - delta)
    evaluation_clock += delta
    if evaluation_clock < 2.0:
        return
    evaluation_clock = 0.0
    _evaluate_society()


func _evaluate_society() -> void:
    if not progression.has_effect(&"unlock_ordinary_replacement"):
        _set_status("Manual fabrication remains required until Forge Assistance is authorized.")
        return
    if fabrication_clock > 0.0:
        _set_status("The autonomous forge is cooling before another ordinary replacement.")
        return
    if not _operation_capacity_available():
        _set_status("Replacement is deferred while a major machine group is operating away from the Heartforge.")
        return

    var desired := desired_composition()
    var replacement_order: Array[StringName] = [&"guardian", &"salvager", &"engineer", &"scout"]
    if progression.has_effect(&"relay_frame_available"):
        replacement_order.append(&"relay")
    for raw_archetype in replacement_order:
        var archetype := raw_archetype as StringName
        var target_count := int(desired.get(archetype, 0))
        var current_count := autonomy_director.count_robots(archetype)
        if current_count >= target_count:
            continue
        var cost := run_state.build_cost(archetype)
        if run_state.scrap < cost:
            _set_status("Autonomous replacement needs %d Scrap for the next %s." % [cost, String(archetype).capitalize()])
            return
        if not run_state.spend_scrap(cost):
            return
        _spawn_replacement(archetype, current_count)
        return

    _set_status("Ordinary machine composition is self-maintaining at the current Heartforge tier.")


func desired_composition() -> Dictionary:
    var tier := progression.heartforge_tier
    if tier >= 5:
        var late := {&"salvager": 6, &"guardian": 7, &"scout": 3, &"engineer": 3}
        if progression != null and progression.has_effect(&"relay_frame_available"):
            late[&"relay"] = 1
        return late
    if tier >= 4:
        var frontier := {&"salvager": 5, &"guardian": 5, &"scout": 2, &"engineer": 2}
        if progression != null and progression.has_effect(&"relay_frame_available"):
            frontier[&"relay"] = 1
        return frontier
    if tier >= 3:
        return {&"salvager": 3, &"guardian": 3, &"scout": 2, &"engineer": 2}
    return {&"salvager": 1, &"guardian": 1, &"scout": 1, &"engineer": 1}


func _spawn_replacement(archetype: StringName, current_count: int) -> void:
    if not spawn_robot_callback.is_valid():
        run_state.refund_scrap(run_state.build_cost(archetype))
        return
    var angle := TAU * float(autonomous_builds + current_count + 1) / 8.0
    var position := heartforge.global_position + Vector3(cos(angle) * 3.4, 0.0, sin(angle) * 3.4 + 2.8)
    var level := run_state.level_for(archetype)
    spawn_robot_callback.call(archetype, position, level)
    run_state.robots_built += 1
    autonomous_builds += 1
    fabrication_clock = maxf(8.0, 18.0 - float(progression.heartforge_tier) * 1.5)
    if noise_system != null:
        noise_system.emit_noise(heartforge.global_position, 24.0, 0.62, &"autonomous_replacement")
    var reason := "The machine society replaced a missing %s to maintain its broad strategic composition without a production queue." % String(archetype).capitalize()
    run_state.log_event(reason)
    autonomous_machine_built.emit(archetype, level, reason)
    _set_status(reason)


func _operation_capacity_available() -> bool:
    if not autonomy_director.salvage_operation.is_empty() or not autonomy_director.expedition_operation.is_empty():
        return false
    return true


func _set_status(value: String) -> void:
    if value == last_status:
        return
    last_status = value
    society_status_changed.emit(last_status)


func status_summary() -> String:
    return last_status


func context_dictionary() -> Dictionary:
    return {
        "autonomous_replacement_unlocked": progression != null and progression.has_effect(&"unlock_ordinary_replacement"),
        "autonomous_builds": autonomous_builds,
    }


func to_dictionary() -> Dictionary:
    return {
        "schema_version": 1,
        "autonomous_builds": autonomous_builds,
        "fabrication_clock": fabrication_clock,
        "last_status": last_status,
    }


func restore_from_dictionary(data: Dictionary) -> void:
    autonomous_builds = maxi(0, int(data.get("autonomous_builds", 0)))
    fabrication_clock = maxf(0.0, float(data.get("fabrication_clock", 0.0)))
    last_status = str(data.get("last_status", "Manual fabrication remains required."))
