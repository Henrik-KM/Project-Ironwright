extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightCompleteGameWorld3D
    root.add_child(world)
    await process_frame
    await physics_frame
    await process_frame

    _expect(world != null, "The complete-game scene must instantiate for archive testing.")
    _expect(world.story_archive_director != null, "The complete-game world must own a story archive director.")
    if world == null or world.story_archive_director == null:
        _finish()
        return

    var archive := world.story_archive_director
    _expect(archive.has_record(&"story.heartforge.last_light"), "The opening archive record must unlock automatically.")
    var opening_threads := archive.story_arc_summaries()
    var civic_thread := opening_threads.filter(func(thread: Dictionary) -> bool: return str(thread.get("id", "")) == "thread.civic_afterimage")
    _expect(civic_thread.size() == 1 and int(civic_thread[0].get("progress", 0)) == 1 and int(civic_thread[0].get("total", 0)) == 5, "The archive must expose a derived civic story thread from the opening record without creating a quest task.")
    _expect(archive.archive_records().any(func(record: Dictionary) -> bool: return str(record.get("kind", "")) == "story_thread"), "The on-demand archive must present story threads alongside physical records.")
    var thread_advances: Array[StringName] = []
    archive.thread_advanced.connect(func(thread_id: StringName, _display_name: String, _stage_count: int, _description: String) -> void: thread_advances.append(thread_id))

    world.run_state.observe_organic_species(&"razorhound", &"hunt", &"region.west_grid")
    world.run_state.observe_organic_species(&"razorhound", &"track_last_known", &"region.west_grid")
    var ecology_records := archive.archive_records().filter(func(record: Dictionary) -> bool: return str(record.get("id", "")) == "bestiary.razorhound")
    _expect(ecology_records.size() == 1 and str(ecology_records[0].get("description", "")).contains("track last known"), "The Town Archive must expose persistent bestiary behaviour evidence without adding a management surface.")

    world.run_state.observe_region_pressure(&"region.west_grid", 0.91, "West Grid")
    var pressure_records := archive.archive_records().filter(func(record: Dictionary) -> bool: return str(record.get("id", "")) == "pressure.region.west_grid")
    _expect(pressure_records.size() == 1 and str(pressure_records[0].get("description", "")).contains("91% ecological pressure"), "The Town Archive must expose a persistent regional pressure chronicle without adding a management surface.")
    var run_state_snapshot := world.run_state.to_dictionary()
    var restored_run_state := RunState3D.new()
    restored_run_state.restore_from_dictionary(run_state_snapshot)
    _expect(restored_run_state.observed_region_pressure.has("region.west_grid"), "Regional pressure chronicle evidence must survive run-state serialization.")
    restored_run_state.free()

    _expect(world.outpost_director.discover_site(&"site.north_archive_sublevel"), "The archive sublevel site must be discoverable through the real outpost director.")
    _expect(world.outpost_director.discover_site(&"site.east_roof_reservoir"), "The roof reservoir site must be discoverable through the real outpost director.")
    _expect(world.outpost_director.discover_site(&"site.west_cooling_station"), "The cooling station site must be discoverable through the real outpost director.")
    _expect(world.outpost_director.discover_site(&"site.root_signal_ledge"), "The root signal ledge site must be discoverable through the real outpost director.")
    _expect(world.outpost_director.discover_site(&"site.cathedral_bell_yard"), "The Cathedral bell-yard site must be discoverable through the real outpost director.")
    _expect(archive.has_record(&"story.site.north_archive_sublevel"), "Discovering the archive sublevel must unlock its physical story record.")
    _expect(archive.has_record(&"story.site.east_roof_reservoir"), "Discovering the roof reservoir must unlock its physical story record.")
    _expect(archive.has_record(&"story.site.west_cooling_station"), "Discovering the cooling station must unlock its physical story record.")
    _expect(archive.has_record(&"story.site.root_signal_ledge"), "Discovering the root ledge must unlock its physical story record.")
    _expect(archive.has_record(&"story.site.cathedral_bell_yard"), "Discovering the Cathedral bell yard must unlock its physical story record.")

    world.outpost_director.operation_changed.emit(&"outpost_build", &"constructed", "")
    _expect(archive.has_record(&"story.outpost.first_relay"), "A constructed outpost must unlock the first relay record.")

    world.outpost_director.operation_changed.emit(&"outpost", &"destroyed", "")
    _expect(archive.has_record(&"story.outpost.distance_cost"), "An outpost loss must unlock the distance-cost record.")

    world.outpost_director.operation_changed.emit(&"outpost_rebuild", &"complete", "")
    _expect(archive.has_record(&"story.outpost.returned_signal"), "An automatic rebuild must unlock the returned-signal record.")

    world.autonomy_director.operation_changed.emit(&"salvage", &"complete", "")
    _expect(archive.has_record(&"story.machine.first_salvage"), "The first autonomous salvage return must unlock a durable machine-witness record.")

    _expect(world.region_director.discover_region(&"region.west_grid"), "The West Grid discovery must be available for machine-thread feedback coverage.")
    _expect(world.region_director.discover_region(&"region.east_tenements"), "The East Tenements discovery must be available for machine-thread feedback coverage.")
    _expect(thread_advances.any(func(thread_id: StringName) -> bool: return thread_id == &"machine_witness"), "Crossing a real machine-witness chapter must emit bounded live story feedback.")

    _expect(world.region_director.discover_region(&"region.glasshouse"), "The Glasshouse discovery must be available for ecological thread coverage.")
    _expect(world.region_director.discover_region(&"region.observatory_ridge"), "The Observatory discovery must be available for ecological thread coverage.")
    _expect(world.region_director.discover_region(&"region.cathedral_quarter"), "The Cathedral discovery must be available for ecological thread coverage.")

    world.long_operation_director.operation_changed.emit(&"operation.north_archive_sublevel", &"complete", "")
    world.long_operation_director.operation_changed.emit(&"operation.east_residential_rescue", &"complete", "")
    world.long_operation_director.operation_changed.emit(&"operation.west_transformer_repair", &"complete", "")
    world.long_operation_director.operation_changed.emit(&"operation.root_signal_purge", &"complete", "")
    world.long_operation_director.operation_changed.emit(&"operation.cathedral_brood_suppression", &"complete", "")
    _expect(archive.has_record(&"story.north_archive.sublevel"), "The archive sublevel operation must leave a durable civic record.")
    _expect(archive.has_record(&"story.east_tenements.beacon"), "The residential beacon operation must leave a durable machine-witness record.")
    _expect(archive.has_record(&"story.west_grid.transformer"), "The transformer repair must leave a durable industrial record.")
    _expect(archive.has_record(&"story.root_cistern.ledge"), "The root signal purge must leave a durable endgame record.")
    _expect(archive.has_record(&"story.cathedral.silence"), "The Cathedral brood suppression must leave a durable ecological record.")
    var converged_threads := archive.story_arc_summaries().filter(func(thread: Dictionary) -> bool: return str(thread.get("id", "")) == "thread.ecological_convergence")
    _expect(converged_threads.size() == 1 and int(converged_threads[0].get("progress", 0)) == 5 and str(converged_threads[0].get("description", "")).contains("Migration, resonance"), "Ecological evidence must advance the authored run-level thread and its current chapter.")

    world.endgame_director.endgame_completed.emit(&"protocol.containment", "Containment", "")
    _expect(archive.has_record(&"story.endgame.containment"), "The chosen final protocol must unlock its matching archive record.")
    _expect(not archive.has_record(&"story.endgame.severance"), "An unchosen final protocol must remain locked.")

    var saved := archive.to_dictionary()
    archive.restore_from_dictionary({})
    _expect(archive.record_count() == 0, "Archive restore must clear records absent from the saved payload.")
    archive.reconcile_discovered_state()
    _expect(archive.has_record(&"story.site.north_archive_sublevel"), "Archive reconciliation must recover site records from already-discovered site state.")
    archive.restore_from_dictionary(saved)
    _expect(archive.has_record(&"story.outpost.first_relay"), "Archive save/load must preserve event records.")
    _expect(archive.has_record(&"story.endgame.containment"), "Archive save/load must preserve the chosen ending record.")
    var restored_threads := archive.story_arc_summaries()
    _expect(restored_threads.size() == 3 and restored_threads.any(func(thread: Dictionary) -> bool: return int(thread.get("progress", 0)) == 5), "Derived story thread progress must remain correct after archive save/load restoration.")

    _finish()


func _finish() -> void:
    if failures.is_empty():
        print("Project Ironwright story archive tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Project Ironwright story archive tests failed: %d" % failures.size())
    quit(1)


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
