extends SceneTree

## Representative authored-region streaming benchmark.
##
## The benchmark exercises the real release world one region at a time. It
## records asynchronous promotion latency and the number of authored package
## roots that remain instantiated after each focus change. It intentionally
## does not impose a machine-specific frame-rate target; target hardware is a
## separate external gate.

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")
const REGION_IDS: Array[StringName] = [
    &"region.west_grid", &"region.riverworks", &"region.cathedral_quarter",
    &"region.observatory_ridge", &"region.tram_graveyard", &"region.buried_labs",
    &"region.glasshouse", &"region.north_ruins", &"region.east_tenements",
    &"region.flood_market", &"region.root_cistern",
]
const MAX_PROMOTION_WAIT_FRAMES := 180
const MAX_RESIDENT_AUTHORED_PACKAGES := 3
const MAX_PREFETCHED_PACKAGES := 2

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_benchmark")


func _run_benchmark() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightReleaseWorld3D
    root.add_child(world)
    for _index in range(8):
        await process_frame
    await physics_frame

    _expect(world != null and world.region_director != null, "Streaming benchmark must boot the complete release region service.")
    _expect(world != null and world.region_lod_director != null, "Streaming benchmark must boot the release region LOD service.")
    if world == null or world.region_director == null or world.region_lod_director == null:
        _finish()
        return

    # The release art pass intentionally prioritizes the opening cast and
    # finishes the remaining material work in bounded batches. Start the
    # package sweep only after that real boot queue is idle; otherwise the
    # benchmark conflates initial presentation construction with a player
    # moving between already playable districts.
    if world.release_world_art != null:
        for _frame in range(240):
            if not world.release_world_art.texture_queue_active:
                break
            await process_frame
    for _frame in range(12):
        await process_frame
    # Hold the focus sweep under explicit benchmark control. The real player
    # remains at the Heartforge during this test, so leaving the automatic
    # distance refresh enabled would legitimately stream a package back out
    # before its asynchronous promotion could be measured.
    world.region_lod_director.set_process(false)
    # This runner measures imported authored packages, not the separate
    # procedural encounter-dressing lifecycle. The presentation/streaming
    # runner owns that renderer transition contract; disconnect it here so
    # generated dressing churn cannot contaminate package latency or memory
    # readings.
    if world.release_world_art != null:
        var dressing_callback := Callable(world.release_world_art, "_on_region_stream_changed")
        if world.region_lod_director.is_connected(&"region_stream_changed", dressing_callback):
            world.region_lod_director.disconnect(&"region_stream_changed", dressing_callback)

    # Prefetching must load only the reusable package resource. It must not
    # attach hidden geometry before the region actually enters the focus ring.
    var prefetch_landmark := world.region_director.get_landmark(&"region.root_cistern") as RegionLandmark3D
    _expect(prefetch_landmark != null, "Prefetch coverage needs the Root Cistern landmark.")
    world.region_lod_director.set_region_streamed(&"region.root_cistern", false)
    var prefetch_started := world.region_lod_director.prefetch_region(&"region.root_cistern")
    _expect(prefetch_started, "A remote authored region must accept a bounded asynchronous prefetch request.")
    if prefetch_landmark != null:
        _expect(prefetch_landmark._authored_model_root.get_child_count() == 0, "Prefetching must not instantiate authored geometry outside the focus ring.")
    var prefetch_wait_frames := 0
    while prefetch_wait_frames < MAX_PROMOTION_WAIT_FRAMES:
        await process_frame
        prefetch_wait_frames += 1
        if prefetch_landmark != null and prefetch_landmark.authored_model_package_ready():
            break
    _expect(prefetch_landmark != null and prefetch_landmark.authored_model_package_ready(), "Prefetched authored package must become reusable within the bounded wait.")
    _expect(world.region_lod_director.prefetched_region_count() <= MAX_PREFETCHED_PACKAGES, "Prefetched package references must remain within the bounded cache budget.")
    if prefetch_landmark != null:
        _expect(prefetch_landmark._authored_model_root.get_child_count() == 0, "A completed prefetch must still leave geometry detached until promotion.")
    world.region_lod_director.set_region_streamed(&"region.root_cistern", true)
    for _prefetch_attach_frame in range(8):
        await process_frame
    _expect(prefetch_landmark != null and _authored_package_ready(prefetch_landmark), "Streaming in a prefetched region must attach the already-loaded authored package.")
    world.region_lod_director.set_region_streamed(&"region.root_cistern", false)
    for _prefetch_cleanup_frame in range(8):
        await process_frame
    _expect(prefetch_landmark == null or not _authored_package_ready(prefetch_landmark), "Streaming out a prefetched region must release its instantiated geometry.")

    var promotion_wait_frames: Array[int] = []
    var resident_package_counts: Array[int] = []
    var maximum_streamed_regions := world.region_lod_director.streamed_region_count()
    var maximum_resident_packages := _resident_authored_package_count(world)
    var starting_memory := _static_memory_bytes()

    for region_id in REGION_IDS:
        var landmark := world.region_director.get_landmark(region_id) as RegionLandmark3D
        _expect(landmark != null, "Streaming benchmark region must exist: %s" % String(region_id))
        if landmark == null:
            continue
        world.region_director.discover_region(region_id)
        world.region_lod_director.set_region_streamed(region_id, false)
        await process_frame

        var started_usec := Time.get_ticks_usec()
        world.region_lod_director.set_region_streamed(region_id, true)
        var wait_frames := 0
        while wait_frames < MAX_PROMOTION_WAIT_FRAMES:
            await process_frame
            wait_frames += 1
            if _authored_package_ready(landmark):
                break
        promotion_wait_frames.append(wait_frames)
        _expect(_authored_package_ready(landmark), "Authored package must promote asynchronously within the bounded wait for %s." % String(region_id))

        var elapsed_ms := float(Time.get_ticks_usec() - started_usec) / 1000.0
        var resident_count := _resident_authored_package_count(world)
        resident_package_counts.append(resident_count)
        maximum_streamed_regions = maxi(maximum_streamed_regions, world.region_lod_director.streamed_region_count())
        maximum_resident_packages = maxi(maximum_resident_packages, resident_count)
        _expect(resident_count <= MAX_RESIDENT_AUTHORED_PACKAGES, "Authored package residency must remain bounded during %s (observed %d)." % [String(region_id), resident_count])
        print("RESOURCE_STREAM_SAMPLE region=%s wait_frames=%d promotion_ms=%.2f resident_packages=%d" % [String(region_id), wait_frames, elapsed_ms, resident_count])

        world.region_lod_director.set_region_streamed(region_id, false)
        for _cleanup_frame in range(8):
            await process_frame
        _expect(not _authored_package_ready(landmark), "Streaming out %s must release its instantiated authored package nodes." % String(region_id))

    var report := {
        "schema_version": 1,
        "region_count": REGION_IDS.size(),
        "max_promotion_wait_frames": MAX_PROMOTION_WAIT_FRAMES,
        "prefetch_wait_frames": prefetch_wait_frames,
        "prefetched_region_count": world.region_lod_director.prefetched_region_count(),
        "promotion_wait_frames": promotion_wait_frames,
        "resident_package_counts": resident_package_counts,
        "maximum_streamed_regions": maximum_streamed_regions,
        "maximum_resident_authored_packages": maximum_resident_packages,
        "starting_static_memory_bytes": starting_memory,
        "ending_static_memory_bytes": _static_memory_bytes(),
        "status": "pass" if failures.is_empty() else "fail",
    }
    print("RESOURCE_STREAMING_BENCHMARK_JSON " + JSON.stringify(report))
    world.queue_free()
    for _cleanup_frame in range(8):
        await process_frame
    _finish()


func _authored_package_ready(landmark: RegionLandmark3D) -> bool:
    return landmark != null and landmark._authored_model_root != null and landmark._authored_model_root.get_child_count() > 0


func _resident_authored_package_count(world: IronwrightReleaseWorld3D) -> int:
    var count := 0
    for raw_landmark in world.region_director.landmarks.values():
        var landmark := raw_landmark as RegionLandmark3D
        if _authored_package_ready(landmark):
            count += 1
    return count


func _static_memory_bytes() -> int:
    return int(Performance.get_monitor(Performance.MEMORY_STATIC))


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
        push_error(message)


func _finish() -> void:
    if failures.is_empty():
        print("Project Ironwright authored resource streaming benchmark passed.")
        quit(0)
    else:
        print("Project Ironwright authored resource streaming benchmark failed: %d" % failures.size())
        quit(1)
