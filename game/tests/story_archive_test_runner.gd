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

    _expect(world.outpost_director.discover_site(&"site.north_archive_sublevel"), "The archive sublevel site must be discoverable through the real outpost director.")
    _expect(world.outpost_director.discover_site(&"site.east_roof_reservoir"), "The roof reservoir site must be discoverable through the real outpost director.")
    _expect(world.outpost_director.discover_site(&"site.west_cooling_station"), "The cooling station site must be discoverable through the real outpost director.")
    _expect(world.outpost_director.discover_site(&"site.root_signal_ledge"), "The root signal ledge site must be discoverable through the real outpost director.")
    _expect(archive.has_record(&"story.site.north_archive_sublevel"), "Discovering the archive sublevel must unlock its physical story record.")
    _expect(archive.has_record(&"story.site.east_roof_reservoir"), "Discovering the roof reservoir must unlock its physical story record.")
    _expect(archive.has_record(&"story.site.west_cooling_station"), "Discovering the cooling station must unlock its physical story record.")
    _expect(archive.has_record(&"story.site.root_signal_ledge"), "Discovering the root ledge must unlock its physical story record.")

    world.outpost_director.operation_changed.emit(&"outpost_build", &"constructed", "")
    _expect(archive.has_record(&"story.outpost.first_relay"), "A constructed outpost must unlock the first relay record.")

    world.outpost_director.operation_changed.emit(&"outpost", &"destroyed", "")
    _expect(archive.has_record(&"story.outpost.distance_cost"), "An outpost loss must unlock the distance-cost record.")

    world.outpost_director.operation_changed.emit(&"outpost_rebuild", &"complete", "")
    _expect(archive.has_record(&"story.outpost.returned_signal"), "An automatic rebuild must unlock the returned-signal record.")

    world.long_operation_director.operation_changed.emit(&"operation.north_archive_sublevel", &"complete", "")
    world.long_operation_director.operation_changed.emit(&"operation.east_residential_rescue", &"complete", "")
    world.long_operation_director.operation_changed.emit(&"operation.west_transformer_repair", &"complete", "")
    world.long_operation_director.operation_changed.emit(&"operation.root_signal_purge", &"complete", "")
    _expect(archive.has_record(&"story.north_archive.sublevel"), "The archive sublevel operation must leave a durable civic record.")
    _expect(archive.has_record(&"story.east_tenements.beacon"), "The residential beacon operation must leave a durable machine-witness record.")
    _expect(archive.has_record(&"story.west_grid.transformer"), "The transformer repair must leave a durable industrial record.")
    _expect(archive.has_record(&"story.root_cistern.ledge"), "The root signal purge must leave a durable endgame record.")

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
