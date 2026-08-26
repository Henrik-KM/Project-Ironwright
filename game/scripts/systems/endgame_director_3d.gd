class_name EndgameDirector3D
extends Node

## Owns the player-triggered final crisis. No final response may begin from a
## recurring timer: the player must deliberately initiate an unlocked protocol.

const REMOTE_PHASE_END := 0.30

signal endgame_started(protocol_id: StringName, display_name: String)
signal endgame_progress(protocol_id: StringName, progress: float, detail: String)
signal endgame_completed(protocol_id: StringName, display_name: String, ending: String)
signal endgame_failed(protocol_id: StringName, reason: String)

const PROTOCOLS_PATH := "res://data/endgame_protocols.json"

var run_state: RunState3D
var progression: ProgressionDirector3D
var operations: LongRangeOperationDirector3D
var outpost_director: OutpostDirector3D
var region_director: WorldRegionDirector3D
var ecology: StrategicEcologyDirector3D
var heartforge: Heartforge3D
var spawn_enemy_callback: Callable
var protocols: Dictionary = {}
var active_protocol: Dictionary = {}
var completed_protocol: StringName = &""
var last_remote_support_progress: float = 0.0
var last_homefront_hold_progress: float = 0.0
var spawn_clock: float = 0.0
var event_serial: int = 0
var load_errors: Array[String] = []


func configure(
        next_run_state: RunState3D,
        next_progression: ProgressionDirector3D,
        next_operations: LongRangeOperationDirector3D,
        next_outpost_director: OutpostDirector3D,
        next_region_director: WorldRegionDirector3D,
        next_ecology: StrategicEcologyDirector3D,
        next_heartforge: Heartforge3D,
        next_spawn_enemy_callback: Callable
    ) -> void:
    run_state = next_run_state
    progression = next_progression
    operations = next_operations
    outpost_director = next_outpost_director
    region_director = next_region_director
    ecology = next_ecology
    heartforge = next_heartforge
    spawn_enemy_callback = next_spawn_enemy_callback


func _ready() -> void:
    _load_protocols()


func _process(delta: float) -> void:
    if active_protocol.is_empty() or completed_protocol != &"":
        return
    active_protocol["elapsed"] = float(active_protocol.get("elapsed", 0.0)) + delta
    spawn_clock += delta
    var data: Dictionary = active_protocol.get("data", {})
    var duration := maxf(1.0, float(data.get("duration_seconds", 210.0)))
    var progress := clampf(float(active_protocol.get("elapsed", 0.0)) / duration, 0.0, 1.0)
    _update_endgame_phases(progress)
    var pressure_multiplier := float(data.get("pressure_multiplier", 2.0))
    pressure_multiplier *= 1.0 - operations.endgame_pressure_reduction
    ecology.set_endgame_escalation(1.0 + progress * maxf(0.2, pressure_multiplier - 1.0))

    var spawn_interval := maxf(4.0, float(data.get("spawn_interval_seconds", 10.0)))
    spawn_interval *= 1.0 + operations.endgame_pressure_reduction * 0.9
    if spawn_clock >= spawn_interval:
        spawn_clock = 0.0
        _spawn_causal_response(progress, pressure_multiplier)

    var protocol_id := StringName(active_protocol.get("id", &""))
    endgame_progress.emit(protocol_id, progress, _progress_detail(progress))
    if progress >= 1.0:
        if float(active_protocol.get("remote_support_progress", 0.0)) < 0.999:
            fail_active_protocol("The remote relay network lost too many functioning outposts before the final signal could be severed.")
        elif float(active_protocol.get("homefront_hold_progress", 0.0)) < 0.999:
            fail_active_protocol("The Heartforge could not hold the final convergence long enough to complete the protocol.")
        else:
            _complete_active_protocol()


func _load_protocols() -> void:
    protocols.clear()
    load_errors.clear()
    var file := FileAccess.open(PROTOCOLS_PATH, FileAccess.READ)
    if file == null:
        load_errors.append("Missing %s" % PROTOCOLS_PATH)
        return
    var parsed: Variant = JSON.parse_string(file.get_as_text())
    if not (parsed is Dictionary):
        load_errors.append("Invalid endgame protocol JSON")
        return
    for raw_entry in (parsed as Dictionary).get("protocols", []):
        if not (raw_entry is Dictionary):
            continue
        var entry := (raw_entry as Dictionary).duplicate(true)
        var protocol_id := StringName(str(entry.get("id", "")))
        if protocol_id == &"":
            continue
        protocols[protocol_id] = entry


func protocol(protocol_id: StringName) -> Dictionary:
    var raw: Variant = protocols.get(protocol_id, {})
    return (raw as Dictionary).duplicate(true) if raw is Dictionary else {}


func available_protocols() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    if completed_protocol != &"" or not active_protocol.is_empty():
        return result
    for raw_id in protocols:
        var protocol_id := raw_id as StringName
        var entry := protocol(protocol_id)
        if requirements_met(entry):
            result.append(entry)
    result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return str(a.get("display_name", "")) < str(b.get("display_name", ""))
    )
    return result


func requirements_met(entry: Dictionary) -> bool:
    if progression == null or operations == null:
        return false
    var requirements: Dictionary = entry.get("requirements", {})
    if progression.heartforge_tier < int(requirements.get("heartforge_tier", 5)):
        return false
    if requirements.has("technology"):
        if not progression.has_technology(StringName(str(requirements["technology"]))):
            return false
    if requirements.has("completed_operation"):
        if not operations.has_completed(StringName(str(requirements["completed_operation"]))):
            return false
    if requirements.has("components_min") and operations.component_count() < int(requirements["components_min"]):
        return false
    if requirements.has("functioning_outposts_min"):
        if _functioning_outpost_count() < int(requirements["functioning_outposts_min"]):
            return false
    return true


func can_initiate(protocol_id: StringName) -> bool:
    if completed_protocol != &"" or not active_protocol.is_empty():
        return false
    if operations != null and not operations.active_operation.is_empty():
        return false
    if outpost_director != null and not outpost_director.operation.is_empty():
        return false
    var entry := protocol(protocol_id)
    if entry.is_empty() or not requirements_met(entry):
        return false
    return (
        run_state.scrap >= int(entry.get("scrap_cost", 0))
        and run_state.rare_cores >= int(entry.get("rare_core_cost", 0))
    )


func initiate(protocol_id: StringName) -> bool:
    if not can_initiate(protocol_id):
        return false
    var entry := protocol(protocol_id)
    var scrap_cost := int(entry.get("scrap_cost", 0))
    var core_cost := int(entry.get("rare_core_cost", 0))
    if not run_state.spend_scrap(scrap_cost):
        return false
    if not run_state.spend_rare_cores(core_cost):
        run_state.refund_scrap(scrap_cost)
        return false

    var support_site_id := _select_endgame_support_site()
    var remote_outposts_min := maxi(1, int(entry.get("remote_outposts_min", 1)))
    active_protocol = {
        "id": protocol_id,
        "data": entry,
        "elapsed": 0.0,
        "remote_support_site_id": String(support_site_id),
        "remote_support_progress": 0.0,
        "remote_outposts_min": remote_outposts_min,
        "homefront_hold_progress": 0.0,
    }
    last_remote_support_progress = 0.0
    last_homefront_hold_progress = 0.0
    spawn_clock = 0.0
    event_serial = 0
    region_director.add_pressure(&"region.heartforge_district", 0.42)
    region_director.add_pressure(&"region.root_cistern", 0.55)
    run_state.log_event("Final protocol initiated: %s. Remote relay support assigned from %s." % [str(entry.get("display_name", String(protocol_id))), String(support_site_id)])
    endgame_started.emit(protocol_id, str(entry.get("display_name", String(protocol_id))))
    return true


func fail_active_protocol(reason: String) -> void:
    if active_protocol.is_empty():
        return
    var protocol_id := StringName(active_protocol.get("id", &""))
    active_protocol.clear()
    ecology.set_endgame_escalation(1.0)
    endgame_failed.emit(protocol_id, reason)


func progress_fraction() -> float:
    if active_protocol.is_empty():
        return 1.0 if completed_protocol != &"" else 0.0
    var data: Dictionary = active_protocol.get("data", {})
    return clampf(float(active_protocol.get("elapsed", 0.0)) / maxf(1.0, float(data.get("duration_seconds", 210.0))), 0.0, 1.0)


func status_summary() -> String:
    if completed_protocol != &"":
        return "%s completed" % String(completed_protocol).replace("protocol.", "").capitalize()
    if active_protocol.is_empty():
        return "No final protocol active"
    var data: Dictionary = active_protocol.get("data", {})
    return "%s · %d%%" % [str(data.get("display_name", "Final protocol")), int(round(progress_fraction() * 100.0))]


func _complete_active_protocol() -> void:
    var protocol_id := StringName(active_protocol.get("id", &""))
    var data: Dictionary = active_protocol.get("data", {})
    last_remote_support_progress = remote_support_progress()
    last_homefront_hold_progress = homefront_hold_progress()
    completed_protocol = protocol_id
    active_protocol.clear()
    ecology.set_endgame_escalation(1.0)
    region_director.suppress_region(&"region.root_cistern", 0.85)
    region_director.suppress_region(&"region.heartforge_district", 0.7)
    var ending := str(data.get("ending", "The Heartforge survives."))
    run_state.log_event("First victory achieved through %s." % str(data.get("display_name", String(protocol_id))))
    endgame_completed.emit(protocol_id, str(data.get("display_name", String(protocol_id))), ending)


func _update_endgame_phases(progress: float) -> void:
    if active_protocol.is_empty():
        return
    var required := maxi(1, int(active_protocol.get("remote_outposts_min", 1)))
    var functioning := _functioning_outpost_count()
    var remote_capacity := clampf(float(functioning) / float(required), 0.0, 1.0)
    var remote_progress := clampf(progress / REMOTE_PHASE_END, 0.0, 1.0) * remote_capacity
    active_protocol["remote_support_progress"] = remote_progress

    # The second phase is the home-front hold. Heartforge integrity is sampled
    # into the phase result so a damaged sanctuary can visibly fail a protocol
    # even if the remote relay survived.
    var hold_progress := clampf((progress - REMOTE_PHASE_END) / (1.0 - REMOTE_PHASE_END), 0.0, 1.0)
    var heartforge_integrity := 1.0
    if heartforge != null:
        heartforge_integrity = clampf(heartforge.current_health / maxf(1.0, heartforge.maximum_health), 0.0, 1.0)
    active_protocol["homefront_hold_progress"] = hold_progress * heartforge_integrity


func remote_support_progress() -> float:
    var value := last_remote_support_progress
    if not active_protocol.is_empty():
        value = float(active_protocol.get("remote_support_progress", 0.0))
    return clampf(value, 0.0, 1.0)


func homefront_hold_progress() -> float:
    var value := last_homefront_hold_progress
    if not active_protocol.is_empty():
        value = float(active_protocol.get("homefront_hold_progress", 0.0))
    return clampf(value, 0.0, 1.0)


func _select_endgame_support_site() -> StringName:
    if outpost_director == null:
        return &"none"
    var candidates := outpost_director.discovered_sites()
    candidates.sort_custom(func(a: OutpostSite3D, b: OutpostSite3D) -> bool:
        return String(a.site_id) < String(b.site_id)
    )
    for site in candidates:
        if site.has_functioning_outpost():
            return site.site_id
    return &"none"


func _spawn_causal_response(progress: float, pressure_multiplier: float) -> void:
    if not spawn_enemy_callback.is_valid():
        return
    event_serial += 1
    var route_sources: Array[StringName] = [
        &"region.north_ruins",
        &"region.west_grid",
        &"region.flood_market",
        &"region.cathedral_quarter",
        &"region.buried_labs",
        &"region.root_cistern",
    ]
    var source_id := route_sources[event_serial % route_sources.size()]
    var source_data := region_director.get_region_data(source_id)
    var route: Array = source_data.get("route_from_heartforge", [])
    var spawn_position := region_director.center(source_id)
    if not route.is_empty() and route[0] is Array and route[0].size() >= 3:
        var point: Array = route[0]
        spawn_position = Vector3(float(point[0]), float(point[1]), float(point[2]))
    var angle := fmod(float(event_serial) * 2.399963, TAU)
    spawn_position += Vector3(cos(angle) * 5.0, 0.0, sin(angle) * 5.0)

    var species: StringName = &"razorhound"
    if progress >= 0.78 and event_serial % 4 == 0:
        species = &"apex"
    elif progress >= 0.5 and event_serial % 3 == 0:
        species = &"broodmass"
    elif progress >= 0.28 and event_serial % 2 == 0:
        species = &"sporecaster"
    elif pressure_multiplier > 2.0:
        species = &"burrower"
    spawn_enemy_callback.call(spawn_position, species)

    if pressure_multiplier >= 2.1 and event_serial % 3 == 0:
        spawn_enemy_callback.call(spawn_position + Vector3(2.2, 0.0, -1.4), &"razorhound")


func _progress_detail(progress: float) -> String:
    if remote_support_progress() < 0.999:
        var support_site := str(active_protocol.get("remote_support_site_id", "the remote relay site"))
        return "REMOTE RELAY · %d%% · %s is holding the recovered signal path while the Heartforge braces for convergence." % [int(round(remote_support_progress() * 100.0)), support_site]
    if homefront_hold_progress() < 0.999:
        return "HOME-FRONT HOLD · %d%% · The remote relay is secure; keep the Heartforge standing through the final convergence." % int(round(homefront_hold_progress() * 100.0))
    if progress < 0.2:
        return "The Heartforge is coupling the recovered components. Organic movement is converging on the town centre."
    if progress < 0.5:
        return "The final signal is propagating through the persistent regions. Remote defences are absorbing the first response."
    if progress < 0.8:
        return "The root network is resisting. Apex organisms are entering the routes while machines maintain the Heartforge lattice."
    return "The protocol is almost irreversible. Hold the Heartforge until the root signal collapses or closes."


func _functioning_outpost_count() -> int:
    var count := 0
    if outpost_director == null:
        return count
    for site in outpost_director.discovered_sites():
        if site.has_functioning_outpost():
            count += 1
    return count


func context_dictionary() -> Dictionary:
    return {
        "endgame_active": not active_protocol.is_empty(),
        "endgame_completed": completed_protocol != &"",
        "completed_protocol": String(completed_protocol),
        "endgame_progress": progress_fraction(),
        "remote_support_progress": remote_support_progress(),
        "homefront_hold_progress": homefront_hold_progress(),
        "remote_support_site_id": str(active_protocol.get("remote_support_site_id", "")),
    }


func to_dictionary() -> Dictionary:
    var serialized_active: Dictionary = {}
    if not active_protocol.is_empty():
        serialized_active = {
            "id": String(active_protocol.get("id", &"")),
            "elapsed": float(active_protocol.get("elapsed", 0.0)),
            "remote_support_site_id": str(active_protocol.get("remote_support_site_id", "")),
            "remote_support_progress": float(active_protocol.get("remote_support_progress", 0.0)),
            "remote_outposts_min": int(active_protocol.get("remote_outposts_min", 1)),
            "homefront_hold_progress": float(active_protocol.get("homefront_hold_progress", 0.0)),
        }
    return {
        "schema_version": 2,
        "active_protocol": serialized_active,
        "completed_protocol": String(completed_protocol),
        "spawn_clock": spawn_clock,
        "event_serial": event_serial,
        "last_remote_support_progress": last_remote_support_progress,
        "last_homefront_hold_progress": last_homefront_hold_progress,
    }


func restore_from_dictionary(data: Dictionary) -> void:
    completed_protocol = StringName(str(data.get("completed_protocol", "")))
    spawn_clock = maxf(0.0, float(data.get("spawn_clock", 0.0)))
    event_serial = maxi(0, int(data.get("event_serial", 0)))
    last_remote_support_progress = clampf(float(data.get("last_remote_support_progress", 0.0)), 0.0, 1.0)
    last_homefront_hold_progress = clampf(float(data.get("last_homefront_hold_progress", 0.0)), 0.0, 1.0)
    active_protocol.clear()
    var saved_active: Variant = data.get("active_protocol", {})
    if saved_active is Dictionary:
        var saved := saved_active as Dictionary
        var protocol_id := StringName(str(saved.get("id", "")))
        var entry := protocol(protocol_id)
        if protocol_id != &"" and not entry.is_empty() and completed_protocol == &"":
            active_protocol = {
                "id": protocol_id,
                "data": entry,
                "elapsed": maxf(0.0, float(saved.get("elapsed", 0.0))),
                "remote_support_site_id": str(saved.get("remote_support_site_id", "")),
                "remote_support_progress": clampf(float(saved.get("remote_support_progress", 0.0)), 0.0, 1.0),
                "remote_outposts_min": maxi(1, int(saved.get("remote_outposts_min", entry.get("remote_outposts_min", 1)))),
                "homefront_hold_progress": clampf(float(saved.get("homefront_hold_progress", 0.0)), 0.0, 1.0),
            }
