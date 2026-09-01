extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")
const TEST_SAVE_ROOT := "user://release_test_saves"
const TEST_SLOT: StringName = &"release_regression"
const DIAGNOSTICS_TEST_PATH := "user://ironwright_release_diagnostics_test/session.json"

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightReleaseWorld3D
    root.add_child(world)
    for index in range(8):
        await process_frame
    await physics_frame
    await _await_enemy_tier_bootstrap(world)
    await _await_renderer_quiescence(world)

    _expect(world != null, "The native scene must instantiate the commercial release world.")
    if world == null:
        _finish()
        return
    # Release assertions use the canonical English copy; isolate the suite
    # from a locale persisted by a preceding live export review.
    world.settings_service.set_value(&"language", "en", false)
    world.localization_service.set_locale(&"en")

    await _test_continue_bootstrap_gate(world)
    _test_release_services(world)
    _test_audio_mixer_settings(world)
    _test_run_variation(world)
    _test_localization(world)
    await _test_controller_and_accessibility(world)
    await _test_release_assets_and_art(world)
    await _test_presentation_review(world)
    _test_content_breadth(world)
    await _test_runtime_material_continuity(world)
    await _test_spatial_and_performance(world)
    _test_transactional_save_service()
    _test_enemy_tier_unified_persistence(world)
    _test_unified_snapshot(world)
    _test_front_end(world)
    await _test_complete_objective_review_fixture(world)

    await _teardown_world(world)
    _finish()


func _await_enemy_tier_bootstrap(world: Node) -> void:
    for _attempt in range(600):
        var bootstrap := world.get_node_or_null("EnemyTierProgressionBootstrap") as EnemyTierProgressionBootstrap3D if world != null else null
        if bootstrap != null and bootstrap.initialized:
            return
        await create_timer(0.025, true, false, true).timeout
        await process_frame


func _await_renderer_quiescence(world: Node) -> void:
    if world == null or not is_instance_valid(world) or world.is_queued_for_deletion():
        return
    var settled := false
    for _attempt in range(320):
        var pending := false
        for raw_landmark in world.find_children("*", "RegionLandmark3D", true, false):
            var landmark := raw_landmark as RegionLandmark3D
            if landmark == null or not landmark.authored_model_presentation_pending():
                continue
            pending = true
            landmark.advance_authored_model_presentation()
        var release_art := world.get_node_or_null("ReleaseWorldArtDirector") as ReleaseWorldArtDirector3D
        if release_art != null and not release_art.is_presentation_idle():
            pending = true
        if not pending:
            settled = true
            break
        await create_timer(0.025, true, false, true).timeout
        await process_frame
    _expect(settled, "Release validation must drain the production presentation queue and every authored-model handoff before continuing.")


func _teardown_world(world: Node) -> void:
    paused = false
    if world == null or not is_instance_valid(world):
        return
    await _await_renderer_quiescence(world)
    var release_art := world.get_node_or_null("ReleaseWorldArtDirector") as ReleaseWorldArtDirector3D
    _expect(release_art == null or release_art.is_presentation_idle(), "Release teardown must not retire the world while production presentation work is still active.")
    for raw_landmark in world.find_children("*", "RegionLandmark3D", true, false):
        var landmark := raw_landmark as RegionLandmark3D
        _expect(landmark == null or not landmark.authored_model_presentation_pending(), "Release teardown must drain authored-model attach and cleanup handoffs before releasing renderer resources.")
    var region_lod := world.get_node_or_null("RegionPresentationLodDirector")
    if region_lod != null:
        region_lod.set_process(false)
    var spatial_audio := world.get_node_or_null("AudioFeedbackDirector") as AudioFeedbackDirector3D
    if spatial_audio != null:
        spatial_audio.stop_all()
    var release_audio := world.get_node_or_null("ReleaseAudioDirector") as ReleaseAudioDirector3D
    if release_audio != null:
        release_audio.clear_transient_feedback()
        release_audio.set_process(false)
    world.propagate_call(&"set_process", [false], true)
    world.propagate_call(&"set_physics_process", [false], true)
    world.queue_free()
    for _cleanup_frame in range(8):
        await process_frame
    await create_timer(0.25, true, false, true).timeout
    for _cleanup_frame in range(4):
        await process_frame


func _test_continue_bootstrap_gate(world: IronwrightReleaseWorld3D) -> void:
    var bootstrap := world.get_node_or_null("EnemyTierProgressionBootstrap") as EnemyTierProgressionBootstrap3D
    _expect(bootstrap != null and bootstrap.initialized, "Continue ordering requires an initialized production enemy-tier bootstrap fixture.")
    if bootstrap == null:
        return
    var gate_results: Array[bool] = []
    bootstrap.initialized = false
    call_deferred("_capture_continue_bootstrap_gate", world, gate_results)
    await process_frame
    await create_timer(0.075, true, false, true).timeout
    await process_frame
    _expect(gate_results.is_empty(), "Continue restoration must remain blocked while canonical ecology initialization is incomplete.")
    bootstrap.initialized = true
    for _attempt in range(20):
        if not gate_results.is_empty():
            break
        await create_timer(0.025, true, false, true).timeout
        await process_frame
    _expect(gate_results == [true], "Continue restoration must resume only after the production enemy-tier bootstrap reports readiness.")


func _capture_continue_bootstrap_gate(world: IronwrightReleaseWorld3D, gate_results: Array[bool]) -> void:
    gate_results.append(await world._await_enemy_tier_bootstrap_initialized())


func _test_release_services(world: IronwrightReleaseWorld3D) -> void:
    _expect(world.audio_director != null and not world.audio_director.release_overlap_bindings_enabled, "The release entrypoint must hand overlapping player and organic cues to the canonical release mixer.")
    _expect(world.localization_service is LocalizationService3D, "Release runtime must install localization.")
    _expect(world.localization_service.text("menu.release_candidate").contains("1.0.0 RC.1"), "The release shell must display the authoritative 1.0.0 RC.1 version label.")
    _expect(world.settings_service is ReleaseSettingsService3D, "Release runtime must install accessibility and controller settings.")
    _expect(world.transactional_save_service is ReleaseTransactionalSaveService3D, "Release runtime must install transactional persistence.")
    _expect(world.spatial_index is SpatialIndex3D, "Release runtime must install the spatial index.")
    _expect(world.balance_director is BalanceDirector3D, "Release runtime must install long-run balance profiles.")
    _expect(world.performance_director is PerformanceDirector3D, "Release runtime must install active/reduced-detail simulation.")
    if world.spatial_index is SpatialIndex3D:
        _expect(world.spatial_index.indexed_nodes(&"organic_enemies").size() == int(world.spatial_index.indexed_counts.get(&"organic_enemies", 0)), "The spatial index must expose its current organic population without a second scene-tree scan.")
        _expect(world.spatial_index.indexed_nodes(&"friendly_robots").size() == int(world.spatial_index.indexed_counts.get(&"friendly_robots", 0)), "The spatial index must expose its current friendly population without a second scene-tree scan.")
    _expect(world.release_audio is ReleaseAudioDirector3D, "Release runtime must install adaptive audio.")
    _expect(world.release_color_filter is ReleaseColorFilter3D, "Release runtime must install the live colour-vision correction layer.")
    if world.release_audio is ReleaseAudioDirector3D and world.operations_hud != null:
        _expect(world.release_audio.caption_layer != null and world.release_audio.caption_layer.layer < world.operations_hud.layer, "Sound captions must remain below strategic readouts so modal close actions stay readable.")
    if world.release_color_filter is ReleaseColorFilter3D:
        _expect(not world.release_color_filter.is_active(), "Colour-vision correction must default to off.")
    if world.release_audio is ReleaseAudioDirector3D:
        world.release_audio.quiet_audio = true
        _expect(is_equal_approx(world.release_audio._safe_volume_db(0.0), -30.0), "Quiet audio review mode must cap a full-scale cue at a very low playback level.")
        _expect(is_equal_approx(world.release_audio._safe_volume_db(-36.0), -36.0), "Quiet audio review mode must preserve already-quiet cues without boosting them.")
        _expect(world.release_audio._should_quiet_audio(["--presentation-review"]), "Any presentation review launch must activate the quiet audio ceiling even when the explicit quiet flag is omitted.")
        _expect(world.release_audio._should_quiet_audio(["--complete-objective-review"]), "Any objective review launch must activate the quiet audio ceiling even when the explicit quiet flag is omitted.")
        _expect(world.release_audio._should_quiet_audio(["--new-world"]), "Fresh-world development fixtures must activate the quiet audio ceiling even when the explicit quiet flag is omitted.")
        _expect(not world.release_audio._should_quiet_audio(["--headless", "--path", "game"]), "Ordinary non-review launches must not be forced into the review-only audio ceiling.")
        world.release_audio.quiet_audio = false
        world.release_audio.caption_panel.visible = false
        world.settings_service.set_value(&"subtitles", false, false)
        world.settings_service.set_value(&"sound_captions", true, false)
        world.release_audio.show_caption("audio.caption.report")
        _expect(world.release_audio.caption_panel.visible, "Sound captions must remain available when general subtitles are disabled.")
        world.release_audio.caption_panel.visible = false
        world.settings_service.set_value(&"sound_captions", false, false)
        world.release_audio.show_caption("audio.caption.report")
        _expect(not world.release_audio.caption_panel.visible, "Sound captions must have an independent accessibility toggle.")
        world.settings_service.set_value(&"subtitles", true, false)
        world.settings_service.set_value(&"sound_captions", true, false)
        world.release_audio.music_duck_remaining = 0.0
        _expect(is_equal_approx(world.release_audio.music_target_volume_db(), -7.0), "Release music must return to its calm target when no immediate danger is present.")
        world.release_audio._arm_music_duck(1.2)
        _expect(is_equal_approx(world.release_audio.music_target_volume_db(), -11.5), "Immediate danger must duck the adaptive music so the warning remains readable.")
        world.release_audio._process(1.3)
        _expect(is_zero_approx(world.release_audio.music_duck_remaining), "Danger music ducking must expire instead of leaving the soundtrack permanently muted.")
        _expect(is_equal_approx(world.release_audio._organic_signature_pitch(&"glassmoth", false), 1.28), "Release audio must preserve the high signature of Glassmoth.")
        _expect(world.release_audio._organic_signature_pitch(&"apex", true) < world.release_audio._organic_signature_pitch(&"apex", false), "Release audio must lower a species signature on death.")
        for call_id in [&"organic_call_low", &"organic_call_mid", &"organic_call_high", &"organic_call_root", &"organic_call_bell", &"organic_call_wing"]:
            _expect(world.release_audio.stream_library.has(call_id), "Release audio must load the authored organic call family %s." % call_id)
        _expect(world.release_audio._organic_call_id(&"apex") == &"organic_call_low", "Apex warnings must use the low organic call family.")
        _expect(world.release_audio._organic_call_id(&"razorhound") == &"organic_call_mid", "Ground hunter warnings must use the mid organic call family.")
        _expect(world.release_audio._organic_call_id(&"glassmoth") == &"organic_call_wing", "Glassmoth warnings must use the authored wing variant.")
        _expect(world.release_audio._organic_call_id(&"rootweaver") == &"organic_call_root", "Rootweaver warnings must use the authored root variant.")
        _expect(world.release_audio._organic_call_id(&"carrionbell") == &"organic_call_bell", "Carrion Bell warnings must use the authored bell variant.")
        var adaptive_director := world.get_node_or_null("AdaptiveDefenseDirector") as AdaptiveDefenseDirector3D
        _expect(adaptive_director != null, "Release audio must be able to observe the adaptive Heartforge director.")
        if adaptive_director != null:
            var proposal_cues_before := world.release_audio.adaptive_proposal_cue_count
            adaptive_director.proposal_available.emit("Test adaptive proposal")
            _expect(world.release_audio.adaptive_proposal_cue_count == proposal_cues_before + 1 and world.release_audio.last_effect_id == &"machine_report", "An adaptive Heartforge proposal must emit one restrained machine-report cue.")
            var build_cues_before := world.release_audio.adaptive_build_cue_count
            adaptive_director.adaptation_changed.emit(&"adaptation.anchored_shell", &"building", "Test build")
            adaptive_director.adaptation_changed.emit(&"adaptation.anchored_shell", &"building", "Repeated test build")
            _expect(world.release_audio.adaptive_build_cue_count == build_cues_before + 1 and world.release_audio.last_effect_id == &"forge", "Adaptive construction must emit one rate-limited forge-start cue.")
            var completion_cues_before := world.release_audio.adaptive_completion_cue_count
            adaptive_director.adaptation_completed.emit(&"adaptation.anchored_shell", "Anchor Deeply")
            _expect(world.release_audio.adaptive_completion_cue_count == completion_cues_before + 1 and not world.release_audio.adaptive_build_audio_played and world.release_audio.last_effect_id == &"forge", "Adaptive completion must emit one forge-resolution cue and reset its build rate limit.")
        var tier_callback := Callable(world.release_audio, "_on_heartforge_tier_changed")
        _expect(world.progression.heartforge_tier_changed.is_connected(tier_callback), "Heartforge tier changes must connect to the release progression audio cue.")
        var tier_cue_count_before := world.release_audio.heartforge_tier_cue_count
        world.release_audio._on_heartforge_tier_changed(2)
        _expect(world.release_audio.heartforge_tier_cue_count == tier_cue_count_before + 1, "A Heartforge tier change must emit one bounded progression cue.")
        _expect(world.release_audio.last_heartforge_tier == 2, "Progression audio must retain the last announced Heartforge tier for rate limiting.")
        world.release_audio._on_heartforge_tier_changed(2)
        _expect(world.release_audio.heartforge_tier_cue_count == tier_cue_count_before + 1, "Repeated Heartforge tier notifications must not flood the progression audio layer.")
        var report_count_before := world.release_audio.operation_report_count
        world.release_audio.notify_operation(&"salvage", &"outbound", "Test machine report", Vector3(0.0, 0.0, -18.0))
        _expect(world.release_audio.operation_report_count == report_count_before + 1, "Autonomous operation transitions must emit a bounded machine report cue.")
        _expect(world.release_audio.last_operation_signature == &"salvage.outbound", "Machine report cues must retain an explainable operation signature.")
        world.release_audio.notify_operation(&"salvage", &"working", "Repeated work report", Vector3(0.0, 0.0, -18.0))
        world.release_audio.notify_operation(&"salvage", &"working", "Repeated work report", Vector3(0.0, 0.0, -18.0))
        _expect(world.release_audio.operation_report_count == report_count_before + 2, "Repeated autonomous work must be rate-limited instead of flooding the audio layer.")
        var audio_outpost := Outpost3D.new()
        audio_outpost.configure(&"audio.test.site", &"resource", 1, world.run_state)
        var outpost_cue_count_before := world.release_audio.outpost_cue_count
        world.release_audio.notify_outpost_activity(audio_outpost, &"harvesting")
        _expect(world.release_audio.outpost_cue_count == outpost_cue_count_before + 1, "Autonomous outpost activity must emit a bounded role-aware spatial cue.")
        _expect(world.release_audio.last_outpost_cue_signature == &"audio.test.site.harvesting", "Outpost audio must retain a stable site-and-activity signature for diagnostics.")
        world.release_audio.notify_outpost_activity(audio_outpost, &"harvesting")
        _expect(world.release_audio.outpost_cue_count == outpost_cue_count_before + 1, "Repeated outpost activity must be rate-limited instead of flooding the audio layer.")
        world.release_audio.outpost_cue_clock = 0.0
        world.release_audio.notify_outpost_activity(audio_outpost, &"repairing")
        _expect(world.release_audio.outpost_cue_count == outpost_cue_count_before + 2, "A changed outpost activity must become available after its short overlap window.")
        world.release_audio.show_caption("audio.caption.report")
        world.release_audio.clear_transient_feedback()
        _expect(not world.release_audio.caption_panel.visible and is_zero_approx(world.release_audio.caption_clock), "The ending boundary must clear transient sound captions instead of leaving a stale cue beneath the final surface.")
        _expect(world.release_audio.spatial_operation_reports.is_empty(), "The ending boundary must release transient spatial operation cues.")
        audio_outpost.free()
        # Headless release boot does not materialize combat actors, so use a
        # real OrganicEnemy3D fixture through the same connection path rather
        # than weakening the test to a mock signal.
        var warning_enemy := OrganicEnemy3D.new()
        world.release_audio._connect_actor(warning_enemy)
        var warning_callback := Callable(world.release_audio, "_on_organic_attack_started")
        _expect(warning_enemy.attack_started.is_connected(warning_callback), "Organic attack wind-ups must connect to the release danger cue.")
        world.release_audio.attack_warning_clock = 0.0
        var warning_count_before := world.release_audio.attack_warning_count
        world.release_audio._on_organic_attack_started(warning_enemy, world.player)
        _expect(world.release_audio.attack_warning_count == warning_count_before + 1, "An organic attack wind-up must emit a pre-impact danger cue.")
        _expect(world.release_audio.last_effect_id == world.release_audio._organic_call_id(warning_enemy.species), "An organic attack wind-up must use its species call family.")
        _expect(world.release_audio.music_duck_remaining > 0.0, "An organic attack wind-up must duck the adaptive music during its readable warning window.")
        world.release_audio._on_organic_attack_started(warning_enemy, world.player)
        _expect(world.release_audio.attack_warning_count == warning_count_before + 1, "Overlapping organic wind-ups must be rate-limited in the audio layer.")
        world.release_audio.attack_warning_clock = 0.0
        world.release_audio._on_organic_attack_started(warning_enemy, world.player)
        _expect(world.release_audio.attack_warning_count == warning_count_before + 2, "The danger cue must become available again after its short overlap window.")
        warning_enemy.free()
    _expect(world.release_world_art is ReleaseWorldArtDirector3D, "Release runtime must install production environment dressing.")
    _expect(world.release_animation is ReleaseAnimationDirector3D, "Release runtime must install secondary animation.")
    _expect(world.release_front_end is ReleaseFrontEnd3D, "Release runtime must install title, pause and settings screens.")
    _expect(world.session_diagnostics is ReleaseSessionDiagnostics3D, "Release runtime must install bounded local session diagnostics.")
    if world.session_diagnostics is ReleaseSessionDiagnostics3D:
        _expect(world.session_diagnostics.session_state == &"started", "A release boot must write a started diagnostics marker.")
        _expect(world.session_diagnostics.to_dictionary().get("events", []).size() <= ReleaseSessionDiagnostics3D.MAX_EVENTS, "Session diagnostics must remain bounded.")
    _test_session_diagnostics()
    _expect(world.run_variation_director is RunVariationDirector3D, "Release runtime must install deterministic authored run variation.")
    _expect(world.release_started, "Headless release tests must enter the playable world automatically.")
    if world.camera != null and world.player != null:
        world.camera.global_position = world.player.global_position
        world._start_release_world()
        _expect(world.camera.global_position.distance_to(world.player.global_position) >= 12.0, "The release world must snap the opening camera to a readable tactical distance before the first playable frame.")


func _test_audio_mixer_settings(world: IronwrightReleaseWorld3D) -> void:
    var settings := world.settings_service as ReleaseSettingsService3D
    _expect(settings != null, "Audio mixer verification requires the release settings service.")
    if settings == null:
        return
    var values := {
        "master_volume": settings.get_value(&"master_volume", 0.88),
        "music_volume": settings.get_value(&"music_volume", 0.68),
        "ambience_volume": settings.get_value(&"ambience_volume", 0.78),
        "effects_volume": settings.get_value(&"effects_volume", 0.86),
    }
    var probes := {
        "Master": 0.5,
        "Music": 0.0,
        "Ambience": 0.25,
        "Effects": 1.0,
    }
    for bus_name in probes:
        _expect(AudioServer.get_bus_index(bus_name) >= 0, "Release audio must expose the %s mixer bus to player settings." % bus_name)
    settings.set_value(&"master_volume", probes["Master"], false)
    settings.set_value(&"music_volume", probes["Music"], false)
    settings.set_value(&"ambience_volume", probes["Ambience"], false)
    settings.set_value(&"effects_volume", probes["Effects"], false)
    for bus_name in probes:
        var bus_index := AudioServer.get_bus_index(bus_name)
        if bus_index < 0:
            continue
        var linear_value := float(probes[bus_name])
        var expected_db := -80.0 if linear_value <= 0.0001 else linear_to_db(linear_value)
        _expect(AudioServer.is_bus_mute(bus_index) == (linear_value <= 0.0001), "%s volume must update the mixer mute state." % bus_name)
        _expect(is_equal_approx(AudioServer.get_bus_volume_db(bus_index), expected_db), "%s volume must update the mixer gain." % bus_name)
    settings.set_value(&"master_volume", values["master_volume"], false)
    settings.set_value(&"music_volume", values["music_volume"], false)
    settings.set_value(&"ambience_volume", values["ambience_volume"], false)
    settings.set_value(&"effects_volume", values["effects_volume"], false)


func _test_session_diagnostics() -> void:
    for path in [DIAGNOSTICS_TEST_PATH, DIAGNOSTICS_TEST_PATH + ".tmp", DIAGNOSTICS_TEST_PATH + ".bak"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    var first := ReleaseSessionDiagnostics3D.new()
    first.configure("diagnostics-test", DIAGNOSTICS_TEST_PATH)
    first.record_event(&"test_marker", "The first diagnostic session was intentionally left unclean.")
    var first_id := first.active_session_id
    first.free()
    var second := ReleaseSessionDiagnostics3D.new()
    second.configure("diagnostics-test", DIAGNOSTICS_TEST_PATH)
    _expect(second.has_unclean_previous_session(), "A new session must detect a prior started marker as an unclean shutdown.")
    _expect(str(second.previous_session.get("active_session_id", "")) == first_id, "Unclean recovery must retain the prior session identifier.")
    second.mark_clean_shutdown("test_complete")
    var report_file := FileAccess.open(DIAGNOSTICS_TEST_PATH, FileAccess.READ)
    var parsed_report: Variant = JSON.parse_string(report_file.get_as_text()) if report_file != null else null
    _expect(parsed_report is Dictionary and str((parsed_report as Dictionary).get("state", "")) == "clean", "A clean shutdown must atomically persist a clean diagnostics state.")
    second.free()
    for path in [DIAGNOSTICS_TEST_PATH, DIAGNOSTICS_TEST_PATH + ".tmp", DIAGNOSTICS_TEST_PATH + ".bak"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_run_variation(world: IronwrightReleaseWorld3D) -> void:
    var variation := world.run_variation_director
    _expect(variation.profile_ids().size() == 6, "Release must load the six authored world-condition profiles.")
    _expect(variation.profiles.has(&"weather.signal_bloom"), "Release must retain the authored Signal Bloom world-condition profile.")
    if variation.profiles.has(&"weather.signal_bloom"):
        var signal_bloom: Dictionary = variation.profiles[&"weather.signal_bloom"]
        _expect(float(signal_bloom.get("glow_bias", 0.0)) > 0.1 and str(signal_bloom.get("rain_color", "")) == "#76bfc8", "Signal Bloom must carry its distinct cyan organic atmospheric signature.")
        _expect(str(signal_bloom.get("ambient_tint", "")) == "#84aab8" and str(signal_bloom.get("fog_tint", "")) == "#4c7681", "Signal Bloom must carry its distinct restrained run-identity color grade.")
        _expect(float(signal_bloom.get("ecology_pressure_multiplier", 0.0)) > 1.2, "Signal Bloom must carry a stronger authored ecology-pressure identity beyond weather presentation.")
        _expect(float(signal_bloom.get("ecology_migration_multiplier", 0.0)) > 1.2, "Signal Bloom must carry a stronger authored migration identity beyond pressure presentation.")
    _expect(variation.profiles.has(&"weather.ashfall_drift"), "Release must retain the authored Ashfall Drift world-condition profile.")
    if variation.profiles.has(&"weather.ashfall_drift"):
        var ashfall_drift: Dictionary = variation.profiles[&"weather.ashfall_drift"]
        _expect(int(ashfall_drift.get("rain_amount", 0)) == 80 and float(ashfall_drift.get("rain_velocity_max", 0.0)) <= 7.0, "Ashfall Drift must use a restrained dry-front particle signature.")
        _expect(str(ashfall_drift.get("particle_style", "")) == "ash" and str(ashfall_drift.get("rain_color", "")) == "#b28d8270", "Ashfall Drift must use a distinct drifting ash particle style and translucent particulate colour.")
        _expect(str(ashfall_drift.get("ambient_tint", "")) == "#aa9a94" and str(ashfall_drift.get("fog_tint", "")) == "#776866", "Ashfall Drift must carry its distinct warm ash atmospheric signature.")
        _expect(float(ashfall_drift.get("glow_bias", 0.0)) > 0.0 and float(ashfall_drift.get("glow_bias", 0.0)) < 0.1, "Ashfall Drift must preserve restrained practical-light emphasis.")
    _expect(variation.profiles.has(&"weather.frost_hush"), "Release must retain the authored Frost Hush world-condition profile.")
    if variation.profiles.has(&"weather.frost_hush"):
        var frost_hush: Dictionary = variation.profiles[&"weather.frost_hush"]
        _expect(str(frost_hush.get("particle_style", "")) == "frost" and int(frost_hush.get("rain_amount", 0)) == 180, "Frost Hush must use a sparse drifting-flake particle signature.")
        _expect(str(frost_hush.get("ambient_tint", "")) == "#9ab6c4" and str(frost_hush.get("fog_tint", "")) == "#587484", "Frost Hush must carry its distinct cold atmospheric signature.")
        _expect(float(frost_hush.get("ecology_pressure_multiplier", 0.0)) < 1.0, "Frost Hush must carry a restrained lower-pressure ecological identity.")
    for profile_id in variation.profile_ids():
        var profile: Dictionary = variation.profiles[profile_id]
        _expect(str(profile.get("ambient_tint", "")) != "" and str(profile.get("fog_tint", "")) != "", "Every authored world condition must define deterministic ambient and fog identity tints.")
        _expect(float(profile.get("ecology_pressure_multiplier", 0.0)) >= 0.75 and float(profile.get("ecology_pressure_multiplier", 0.0)) <= 1.35, "Every authored world condition must define a bounded ecology-pressure identity.")
        _expect(float(profile.get("ecology_migration_multiplier", 0.0)) >= 0.7 and float(profile.get("ecology_migration_multiplier", 0.0)) <= 1.35, "Every authored world condition must define a bounded ecology-migration identity.")
    _expect(world.run_state.world_seed != 0, "A new run must record a non-zero world seed.")
    _expect(world.run_state.world_variant_id != &"", "A new run must record a stable world-condition ID.")
    _expect(not variation.current_display_name().is_empty(), "The active world condition must expose a player-readable name.")
    _expect(world.vertical_slice.weather_emitter != null and world.vertical_slice.weather_emitter.amount >= 80, "The active world condition must configure the opening weather emitter.")
    var active_profile: Dictionary = variation.current_profile()
    _expect(is_equal_approx(world.strategic_ecology_director.run_variation_pressure_multiplier, float(active_profile.get("ecology_pressure_multiplier", 1.0))), "The active world condition must apply its authored ecology-pressure identity to the live ecology director.")
    _expect(is_equal_approx(world.strategic_ecology_director.run_variation_migration_multiplier, float(active_profile.get("ecology_migration_multiplier", 1.0))), "The active world condition must apply its authored ecology-migration identity to the live ecology director.")
    if str(active_profile.get("particle_style", "rain")) == "ash" and world.vertical_slice.weather_emitter != null:
        var ash_mesh := world.vertical_slice.weather_emitter.mesh as QuadMesh
        _expect(ash_mesh != null and ash_mesh.size.x <= 0.1 and ash_mesh.size.y <= 0.1, "Ashfall Drift must materialize as small drifting flecks instead of rain streaks.")
    var original_variant := world.run_state.world_variant_id
    world.run_state.set_world_variant(&"weather.ashfall_drift", world.run_state.world_seed)
    variation.apply_current()
    _expect(is_equal_approx(world.strategic_ecology_director.run_variation_pressure_multiplier, 1.02), "Switching to Ashfall Drift must update the live ecology-pressure identity without changing the saved run seed.")
    _expect(is_equal_approx(world.strategic_ecology_director.run_variation_migration_multiplier, 1.02), "Switching to Ashfall Drift must update the live ecology-migration identity without changing the saved run seed.")
    var ash_mesh := world.vertical_slice.weather_emitter.mesh as QuadMesh if world.vertical_slice.weather_emitter != null else null
    _expect(ash_mesh != null and ash_mesh.size.x <= 0.1 and ash_mesh.size.y <= 0.1, "Ashfall Drift must apply a fleck-sized particle mesh at runtime.")
    world.run_state.set_world_variant(&"weather.frost_hush", world.run_state.world_seed)
    variation.apply_current()
    _expect(is_equal_approx(world.strategic_ecology_director.run_variation_pressure_multiplier, 0.86), "Switching to Frost Hush must update the live ecology-pressure identity without changing the saved run seed.")
    _expect(is_equal_approx(world.strategic_ecology_director.run_variation_migration_multiplier, 0.78), "Switching to Frost Hush must update the live ecology-migration identity without changing the saved run seed.")
    var frost_mesh := world.vertical_slice.weather_emitter.mesh as QuadMesh if world.vertical_slice.weather_emitter != null else null
    _expect(frost_mesh != null and frost_mesh.size.x >= 0.1 and frost_mesh.size.y >= 0.1, "Frost Hush must apply a readable drifting-flake particle mesh at runtime.")
    var migration_probe_low := {"population": 8.0, "food": 0.3, "hunger": 0.8, "disturbance": 0.7, "territory": 0.2, "nesting": 0.2}
    var migration_probe_high := migration_probe_low.duplicate(true)
    world.strategic_ecology_director.set_run_variation_migration_multiplier(0.78)
    world.strategic_ecology_director._advance_population_state(migration_probe_low, 1.0, 10.0)
    world.strategic_ecology_director.set_run_variation_migration_multiplier(1.26)
    world.strategic_ecology_director._advance_population_state(migration_probe_high, 1.0, 10.0)
    _expect(float(migration_probe_high.get("migration_tendency", 0.0)) > float(migration_probe_low.get("migration_tendency", 0.0)), "A high-migration world condition must make the same stressed ecology more likely to relocate than a low-migration condition.")
    world.run_state.set_world_variant(original_variant, world.run_state.world_seed)
    variation.apply_current()
    _expect(world._localized_pressure_summary().contains("migration tendency"), "The command recap must expose migration tendency alongside regional pressure so world-condition ecology changes remain legible.")

    var saved_state := world.run_state.to_dictionary()
    var restored_state := RunState3D.new()
    restored_state.restore_from_dictionary(saved_state)
    _expect(restored_state.world_seed == world.run_state.world_seed, "World variation seed must survive run-state serialization.")
    _expect(restored_state.world_variant_id == world.run_state.world_variant_id, "World variation ID must survive run-state serialization.")
    restored_state.free()

    var legacy_state := RunState3D.new()
    legacy_state.restore_from_dictionary({"schema_version": 2, "scrap": 24, "event_log": []})
    var legacy_variation := RunVariationDirector3D.new()
    legacy_variation.configure(legacy_state, world.vertical_slice, world.region_atmosphere_director)
    legacy_variation._load_profiles()
    legacy_variation.apply_current()
    _expect(legacy_state.world_seed != 0 and legacy_state.world_variant_id in legacy_variation.profile_ids(), "Legacy saves without a world-condition ID must deterministically reconcile to an authored profile during load.")
    legacy_variation.free()
    legacy_state.free()


func _test_localization(world: IronwrightReleaseWorld3D) -> void:
    var service := world.localization_service
    _expect(service.catalogs_have_parity(), "English, Swedish and German release catalogs must have identical keys.")
    _expect(service.available_locales().size() == 3, "Release must expose exactly the three validated locales.")
    var english := service.text("menu.new_world")
    _expect(service.set_locale(&"sv"), "Swedish locale must be selectable.")
    var swedish := service.text("menu.new_world")
    _expect(swedish == "NY VÄRLD" and swedish != english, "Swedish catalog must resolve localized release strings.")
    var guidance_probe := Node3D.new()
    world.add_child(guidance_probe)
    guidance_probe.global_position = world.player.global_position + Vector3(8.0, 0.0, 0.0)
    world.objective_guidance.set_guidance(guidance_probe, service.text("guidance.marker"), service.text("guidance.salvage.hold", ["E"]))
    _expect(world.objective_guidance.direction_to_target() == "ÖSTER" and "ÖSTER" in world.objective_guidance.route_summary(), "Swedish first-session world guidance must localize its physical cardinal direction.")
    _expect(world.objective_guidance.marker_label.text.begins_with("MÅL\n"), "Swedish first-session world guidance must localize its beacon marker label.")
    guidance_probe.queue_free()
    world.objective_guidance.clear_guidance()
    _expect(service.text("menu.release_candidate").contains("1.0.0 RC.1"), "Swedish release shell must display the authoritative 1.0.0 RC.1 version label.")
    _expect(service.text("objective.opening.salvage.title") == "BÄRGA DITT FÖRSTA SKROT", "Swedish catalog must localize the opening objective title.")
    _expect(service.text("objective.base.light.title") == "LÄMNA LJUSET" and service.text("objective.base.light.detail", ["E"]).contains("Håll E"), "Swedish lower-level opening objectives must localize the first salvage stage and its binding replacement.")
    _expect(service.text("objective.base.north_ruins.title") == "NORDRUINERNA" and service.text("objective.base.heartforge.detail").contains("fysiskt"), "Swedish lower-level expedition objectives must localize the physical-group stages.")
    _expect(service.text("notification.forge.insufficient_scrap", [42]) == "OTILLRÄCKLIGT MED SKROT · 42 KRÄVS" and service.text("notification.complete.systems_online") == "STADENS NÄTVERK ÖPPNA · P LÅNGDISTANSOPERATIONER · V SLUTPROTOKOLL", "Swedish gameplay reports must localize fabrication and complete-run guidance.")
    _expect(service.text("notification.outpost.foundation_complete").begins_with("FULLSPELGRUND KLAR") and service.text("objective.full_game.outpost.title") == "GODKÄNN EN UTPOST", "Swedish full-game foundation reports and outpost objectives must resolve through the selected catalog.")
    world.hud.notifications.clear()
    world._on_outpost_operation_changed(&"outpost_build", &"outbound", "An Engineer and escort are physically travelling to North Transit Yard.")
    _expect(world.hud.notification_label.text.contains("UTPOSTLAGET AVRESER") and world.hud.notification_label.text.contains("Norra trafikgården") and not world.hud.notification_label.text.contains("Engineer") and not world.hud.notification_label.text.contains("travelling"), "Swedish autonomous outpost reports must localize the stable activity and site instead of copying English diagnostic detail.")
    world.operations_hud.open_archive([{
        "id": "story.heartforge.last_light",
        "display_name": "The Last Light",
        "description": "The town's final service ledger names the Heartforge as a shelter, not a weapon.",
        "source_name": "Heartforge District",
        "arc": "civic_afterimage",
    }])
    var swedish_archive_metadata := world.operations_hud.requirements_label.text.to_lower()
    _expect(world.operations_hud.selection_label.text == "DET SISTA LJUSET" and world.operations_hud.description_label.text.begins_with("Stadens sista servicelogg"), "Swedish Town Archive records must localize their recovered name and description in the actual archive surface.")
    _expect(service.text("story.source.heartforge_district") == "Hjärtsmedjedistriktet" and service.text("story.arc.civic_afterimage") == "Medborgerligt efterljus", "Swedish Town Archive source and arc catalog entries must resolve.")
    _expect("hjärtsmedjedistriktet" in swedish_archive_metadata, "Swedish Town Archive must render its localized source label.")
    _expect("medborgerligt efterljus" in swedish_archive_metadata, "Swedish Town Archive must render its localized arc label.")
    world.operations_hud.close()
    world.operations_hud.open_archive([{
        "id": "thread.civic_afterimage",
        "kind": "story_thread",
        "thread_key": "civic_afterimage",
        "display_name": "THREAD · The Town That Stayed · 1/5",
        "description": "THREAD PROGRESS · 1/5 PHYSICAL CLUES RECOVERED\\n\\nThe first ledger is not a mission.",
        "source_name": "Run-level civic thread",
        "arc": "civic_afterimage",
        "progress": 1,
        "total": 5,
        "stage_count": 1,
        "stage_description": "The first ledger is not a mission.",
        "missing_record_ids": ["story.north_ruins.ledger"],
    }])
    _expect(world.operations_hud.selection_label.text == "TRÅD · STADEN SOM STANNADE · 1/5" and "TRÅDFÖRLOPP" in world.operations_hud.description_label.text and "NÄSTA SPÅR" in world.operations_hud.description_label.text, "Swedish Town Archive threads must localize their title, progress and next-trace copy on the actual archive surface.")
    _expect("CIVILT SPÅR FÖR OMGÅNGEN" in world.operations_hud.requirements_label.text and "MEDBORGERLIGT EFTERLJUS" in world.operations_hud.requirements_label.text, "Swedish Town Archive threads must localize their source and arc metadata on the actual archive surface.")
    world.operations_hud.close()
    world.operations_hud.open_archive([{
        "id": "bestiary.razorhound",
        "archive_kind": "bestiary",
        "species_key": "razorhound",
        "behaviour_keys": ["hunt", "track_last_known"],
        "display_name": "Bestiary · Razorhound",
        "description": "Field evidence identifies Razorhound.",
        "source_name": "Regional ecology",
        "arc": "bestiary",
    }])
    var swedish_bestiary_description := world.operations_hud.description_label.text.to_upper()
    _expect(world.operations_hud.selection_label.text == "BESTIARIUM · RAZORHOUND" and "FÄLTBEVIS" in swedish_bestiary_description and "JAGA" in swedish_bestiary_description and "FÖLJ SENAST KÄNDA" in swedish_bestiary_description, "Swedish Town Archive bestiary records must localize their title and observed behaviour on the actual archive surface.")
    _expect("REGIONAL EKOLOGI" in world.operations_hud.requirements_label.text and "BESTIARIUM" in world.operations_hud.requirements_label.text, "Swedish Town Archive bestiary records must localize their source and arc metadata on the actual archive surface.")
    world.operations_hud.close()
    world.operations_hud.open_archive([{
        "id": "pressure.region.west_grid",
        "archive_kind": "pressure",
        "region_key": "region.west_grid",
        "peak_pressure": 91,
        "display_name": "Pressure Chronicle · West Grid",
        "description": "West Grid reached 91% ecological pressure during the run.",
        "source_name": "Regional ecology",
        "arc": "pressure",
    }])
    _expect(world.operations_hud.selection_label.text == "TRYCKKRÖNIKA · VÄSTRA NÄTET" and "91% EKOLOGISKT TRYCK" in world.operations_hud.description_label.text.to_upper(), "Swedish Town Archive pressure records must localize their title, region and pressure description on the actual archive surface.")
    _expect("REGIONAL EKOLOGI" in world.operations_hud.requirements_label.text and "TRYCKKRÖNIKA" in world.operations_hud.requirements_label.text, "Swedish Town Archive pressure records must localize their source and arc metadata on the actual archive surface.")
    world.operations_hud.close()
    _expect(service.text("objective.complete.initiate.title") == "STARTA SLUTPROTOKOLLET" and service.text("objective.complete.initiate.prompt").begins_with("TRYCK V"), "Swedish late-run objective title and prompt must resolve through the selected catalog.")
    world.release_front_end.show_pause()
    service.set_locale(&"sv")
    _expect(_front_end_has_button_text(world.release_front_end.pause_panel, "SPARA VÄRLD") and world.release_front_end.pause_subtitle_label.text == "VÄRLDEN ÄR PAUSAD", "Changing to Swedish in pause settings must refresh the already-built pause actions and subtitle.")
    world.strategic_hud.open_evolution()
    _expect("UTVECKLING" in world.strategic_hud.title_label.text and world.strategic_hud.previous_button.text == "◀ FÖREGÅENDE" and "Fortsätt det aktuella målet" in world.strategic_hud.detail_label.text, "Swedish locale must refresh strategic command chrome and explanatory copy.")
    world.strategic_hud.close()
    world.operations_hud.open_operations()
    _expect(world.operations_hud.title_label.text == "LÅNGDISTANSOPERATIONER" and world.operations_hud.close_button.text == "STÄNG · ESC" and "Varje grupp" in world.operations_hud.status_label.text, "Swedish locale must refresh operations command chrome and explanatory copy.")
    world.operations_hud.close()
    _expect(service.set_locale(&"de"), "German locale must be selectable.")
    world.settings_service.set_value(&"language", "de", false)
    _expect(service.set_locale(&"en"), "English locale must remain selectable after a persisted German preference.")
    world.release_front_end._populate_settings_controls()
    var language_control := world.release_front_end.settings_controls.get("language") as OptionButton
    _expect(language_control != null and str(language_control.get_item_metadata(language_control.selected)) == "en", "The settings language selector must follow the active catalog during a non-saving locale override.")
    _expect(service.set_locale(&"de"), "German locale must remain selectable after the override alignment check.")
    _expect(service.text("menu.settings") == "EINSTELLUNGEN", "German catalog must resolve release settings text.")
    _expect(service.text("menu.release_candidate").contains("1.0.0 RC.1"), "German release shell must display the authoritative 1.0.0 RC.1 version label.")
    _expect(service.text("objective.opening.salvage.title") == "BERGE DEIN ERSTES SCHROTTGUT", "German catalog must localize the opening objective title.")
    guidance_probe = Node3D.new()
    world.add_child(guidance_probe)
    guidance_probe.global_position = world.player.global_position + Vector3(-8.0, 0.0, 0.0)
    world.objective_guidance.set_guidance(guidance_probe, service.text("guidance.marker"), service.text("guidance.salvage.hold", ["E"]))
    _expect(world.objective_guidance.direction_to_target() == "WEST" and "WEST" in world.objective_guidance.route_summary(), "German first-session world guidance must localize its physical cardinal direction.")
    _expect(world.objective_guidance.marker_label.text.begins_with("ZIEL\n"), "German first-session world guidance must localize its beacon marker label.")
    guidance_probe.queue_free()
    world.objective_guidance.clear_guidance()
    _expect(service.text("notification.forge.insufficient_scrap", [42]) == "NICHT GENUG SCHROTT · 42 ERFORDERLICH" and service.text("notification.final_protocol.initiated") == "ENDPROTOKOLL GESTARTET · DIE REAKTION IST KAUSAL UND UNWIDERRUFLICH", "German gameplay reports must localize fabrication and final-protocol guidance.")
    _expect(service.text("notification.evolution.tier_online", [2]) == "HERZSCHMIEDE-STUFE 2 AKTIV · INGENIEUR- UND AUSSENPOSTENPROTOKOLLE VERFÜGBAR" and service.text("objective.full_game.outpost.title") == "EINEN AUSSENPOSTEN GENEHMIGEN", "German full-game evolution reports and outpost objectives must resolve through the selected catalog.")
    world.hud.notifications.clear()
    world._on_outpost_operation_changed(&"outpost_build", &"outbound", "An Engineer and escort are physically travelling to North Transit Yard.")
    _expect(world.hud.notification_label.text.contains("AUSSENPOSTENTEAM BRICHT AUF") and world.hud.notification_label.text.contains("Nördlicher Verkehrshof") and not world.hud.notification_label.text.contains("Engineer") and not world.hud.notification_label.text.contains("travelling"), "German autonomous outpost reports must localize the stable activity and site instead of copying English diagnostic detail.")
    _expect(service.text("objective.complete.initiate.title") == "DAS ENDPROTOKOLL EINLEITEN" and service.text("objective.complete.initiate.detail").begins_with("Drücke V") and service.text("objective.complete.initiate.prompt").begins_with("V DRÜCKEN"), "German late-run objective title, detail and prompt must resolve through the selected catalog.")
    _expect(world._localized_ecology_report("Organic activity is concentrating around West Grid after strategic_operation.") == "ORGANISCHE AKTIVITÄT KONZENTRIERT SICH UM WEST GRID NACH STRATEGIC OPERATION", "German strategic ecology reports must resolve through the selected catalog.")
    _expect(service.text("hud.ending.first_light_secured") == "ERSTES LICHT GESICHERT" and service.text("hud.ending.continue") == "EINGABE DRÜCKEN, UM WEITER ZU ERKUNDEN.", "German victory overlay chrome must resolve localized title and continuation prompt.")
    _expect(service.text("endgame.severance.ending").begins_with("Das Signal bricht zusammen"), "German Severance ending copy must be present for the live final-protocol overlay.")
    _expect(service.text("endgame.transformation.name") == "Transformation" and service.text("endgame.transformation.ending").begins_with("Die Herzschmiede"), "German Transformation ending copy must be present for the live final-protocol overlay.")
    _expect(service.text("objective.endgame.active.title") == "HERZSCHMIEDE HALTEN" and service.text("objective.endgame.active.prompt").begins_with("HERZSCHMIEDE HALTEN"), "German active final-protocol objective chrome must be localized.")
    _expect(service.text("hud.sanctuary.damaged") == "ZUFUCHT BESCHÄDIGT · HERZSCHMIEDE HALTEN", "German sanctuary status badge must be localized.")
    _expect(service.text("world.condition.mist_lull.name") == "Nebelruhe" and service.text("world.condition.mist_lull.description").begins_with("Der Regen lässt nach"), "German authored world-condition name and description must resolve for the opening report.")
    _expect(service.text("story.record.endgame_severance.name") == "Die abgetrennte Wurzel" and service.text("story.record.endgame_transformation.name") == "Die verwandelte Wurzel" and service.text("notification.first_victory_achieved", ["Trennung"]) == "ERSTER SIEG · Trennung", "German endgame machine-report events must resolve stable localized record and victory text.")
    world.operations_hud.open_archive([{
        "id": "story.heartforge.last_light",
        "display_name": "Das letzte Licht",
        "description": "Das letzte Serviceprotokoll der Stadt bezeichnet die Herzschmiede als Zuflucht, nicht als Waffe.",
        "source_name": "Heartforge District",
        "arc": "civic_afterimage",
    }])
    var german_archive_metadata := world.operations_hud.requirements_label.text.to_lower()
    _expect(world.operations_hud.selection_label.text == "DAS LETZTE LICHT" and world.operations_hud.description_label.text.begins_with("Das letzte Serviceprotokoll"), "German Town Archive records must localize their recovered name and description in the actual archive surface.")
    _expect(service.text("story.source.heartforge_district") == "Herzschmiedeviertel" and service.text("story.arc.civic_afterimage") == "Bürgerliches Nachbild", "German Town Archive source and arc catalog entries must resolve.")
    _expect("herzschmiedeviertel" in german_archive_metadata, "German Town Archive must render its localized source label.")
    _expect("bürgerliches nachbild" in german_archive_metadata, "German Town Archive must render its localized arc label.")
    world.operations_hud.close()
    world.operations_hud.open_archive([{
        "id": "story.machine.first_salvage",
        "display_name": "The First Shared Load",
        "source_name": "Opening salvage network",
        "arc": "machine_witness",
        "description": "The first salvage group returned with a load no single frame could have carried alone."
    }])
    await process_frame
    _expect(world.operations_hud.selection_label.text == "DIE ERSTE GEMEINSAME LAST" and "Bergungsgruppe" in world.operations_hud.description_label.text and "ERSTES BERGUNGSNETZWERK" in world.operations_hud.requirements_label.text, "German Town Archive must localize the first autonomous salvage witness on the actual archive surface.")
    _expect(not world.operations_hud.selection_label.text.contains("machine_first_salvage") and not world.operations_hud.description_label.text.contains("The first salvage group"), "Localized salvage archive rendering must not expose raw keys or English fallback copy.")
    world.operations_hud.close()
    service.set_locale(&"sv")
    world.operations_hud.open_archive([{
        "id": "story.machine.first_salvage",
        "display_name": "The First Shared Load",
        "source_name": "Opening salvage network",
        "arc": "machine_witness",
        "description": "The first salvage group returned with a load no single frame could have carried alone."
    }])
    await process_frame
    _expect(world.operations_hud.selection_label.text == "DEN FÖRSTA GEMENSAMMA LASTEN" and "bärgningsgruppen" in world.operations_hud.description_label.text and "DET FÖRSTA BÄRGNINGSNÄTVERKET" in world.operations_hud.requirements_label.text, "Swedish Town Archive must localize the first autonomous salvage witness on the actual archive surface.")
    world.operations_hud.close()
    service.set_locale(&"de")
    world.operations_hud.open_archive([{
        "id": "thread.civic_afterimage",
        "kind": "story_thread",
        "thread_key": "civic_afterimage",
        "display_name": "THREAD · Die Stadt, die blieb · 1/5",
        "description": "FADENFORTSCHRITT · 1/5 PHYSISCHE SPUREN GEBORGEN\\n\\nDas erste Protokoll ist keine Mission.",
        "source_name": "Run-level civic thread",
        "arc": "civic_afterimage",
        "progress": 1,
        "total": 5,
        "stage_count": 1,
        "stage_description": "Das erste Protokoll ist keine Mission.",
        "missing_record_ids": ["story.north_ruins.ledger"],
    }])
    _expect(world.operations_hud.selection_label.text == "FADEN · DIE STADT, DIE BLIEB · 1/5" and "FADENFORTSCHRITT" in world.operations_hud.description_label.text and "NÄCHSTE SPUR" in world.operations_hud.description_label.text, "German Town Archive threads must localize their title, progress and next-trace copy on the actual archive surface.")
    _expect("BÜRGERLICHER LAUF-FADEN" in world.operations_hud.requirements_label.text and "BÜRGERLICHES NACHBILD" in world.operations_hud.requirements_label.text, "German Town Archive threads must localize their source and arc metadata on the actual archive surface.")
    world.operations_hud.close()
    world.operations_hud.open_archive([{
        "id": "bestiary.razorhound",
        "archive_kind": "bestiary",
        "species_key": "razorhound",
        "behaviour_keys": ["hunt", "track_last_known"],
        "display_name": "Bestiary · Razorhound",
        "description": "Field evidence identifies Razorhound.",
        "source_name": "Regional ecology",
        "arc": "bestiary",
    }])
    var german_bestiary_description := world.operations_hud.description_label.text.to_upper()
    _expect(world.operations_hud.selection_label.text == "BESTIARIUM · RAZORHOUND" and "FELDBELEGE" in german_bestiary_description and "JAGEN" in german_bestiary_description and "LETZTE SPUR VERFOLGEN" in german_bestiary_description, "German Town Archive bestiary records must localize their title and observed behaviour on the actual archive surface.")
    _expect("REGIONALE ÖKOLOGIE" in world.operations_hud.requirements_label.text and "BESTIARIUM" in world.operations_hud.requirements_label.text, "German Town Archive bestiary records must localize their source and arc metadata on the actual archive surface.")
    world.operations_hud.close()
    world.operations_hud.open_archive([{
        "id": "pressure.region.west_grid",
        "archive_kind": "pressure",
        "region_key": "region.west_grid",
        "peak_pressure": 91,
        "display_name": "Pressure Chronicle · West Grid",
        "description": "West Grid reached 91% ecological pressure during the run.",
        "source_name": "Regional ecology",
        "arc": "pressure",
    }])
    _expect(world.operations_hud.selection_label.text == "DRUCKCHRONIK · WESTLICHES NETZ" and "91% ÖKOLOGISCHEN DRUCK" in world.operations_hud.description_label.text.to_upper(), "German Town Archive pressure records must localize their title, region and pressure description on the actual archive surface.")
    _expect("REGIONALE ÖKOLOGIE" in world.operations_hud.requirements_label.text and "DRUCKCHRONIK" in world.operations_hud.requirements_label.text, "German Town Archive pressure records must localize their source and arc metadata on the actual archive surface.")
    world.operations_hud.close()
    _expect(service.text("notification.technology_online", ["FELDTECHNIK"]) == "TECHNOLOGIE AKTIV · FELDTECHNIK" and service.text("notification.outpost_status", ["Ressourcenposten", "Nördlicher Verkehrshof", "1", "100"]) == "Ressourcenposten bei Nördlicher Verkehrshof · STUFE 1 · INTEGRITÄT 100%", "German endgame technology and outpost reports must resolve stable localized presentation text.")
    _expect(service.text("notification.technology_unlocked", ["FELDTECHNIK"]) == "TECHNOLOGIE FREIGESCHALTET · FELDTECHNIK", "German canonical technology-unlocked reports must resolve stable localized presentation text.")
    _expect(service.text("notification.long_operation.authorized") == "LANGSTRECKENOPERATION AUTORISIERT · FOLGT REALEN STRASSEN · F ZUM FOLGEN" and service.text("notification.long_operation.outbound", ["FORGEHAND BERGEN"]).begins_with("FORGEHAND BERGEN · AUFBRUCH"), "German physical-operation reports must resolve stable localized presentation text.")
    _expect(service.text("adaptive.proposal.reason.damage", [55]).begins_with("Der Herzschmiede-Architekt") and service.text("adaptation.anchored_shell.display_name") == "Tief verankern", "German adaptive-defence proposal copy and adaptation names must resolve stable localized presentation text.")
    _expect(service.text("notification.adaptive.proposal", ["Tief verankern"]).begins_with("VORSCHLAG FÜR ADAPTIVE VERTEIDIGUNG") and service.text("adaptive.state.building", ["Tief verankern", 50]) == "Maschinen bauen Tief verankern · 50%", "German adaptive-defence state reports must resolve stable localized presentation text.")
    world.adaptive_defense_director.pending_reason = "The Heartforge architect found repeated perimeter damage at 55% integrity and proposes one structural response."
    world.adaptive_defense_director.pending_reason_kind = &"damage"
    world.adaptive_defense_director.pending_reason_value = 55.0
    world.localization_service.set_locale(&"de")
    world._on_run_state_event_logged("Adaptive Heartforge proposal available: The Heartforge architect found repeated perimeter damage at 55% integrity and proposes one structural response.")
    _expect(world.hud.notification_label.text.contains("VORSCHLAG FÜR ADAPTIVE VERTEIDIGUNG") and not world.hud.notification_label.text.contains("Adaptive Heartforge proposal available"), "German adaptive proposal machine reports must use the localized proposal surface instead of leaking the canonical event text.")
    world.adaptive_defense_director.completed_adaptation = &"adaptation.anchored_shell"
    world._on_run_state_event_logged("Adaptive Heartforge response completed: Anchor Deeply")
    _expect(world.hud.notification_label.text.contains("TIEF VERANKERN") and not world.hud.notification_label.text.contains("Adaptive Heartforge response completed"), "German adaptive completion machine reports must localize the selected response name instead of leaking the canonical event text.")
    world.adaptive_defense_director.pending_reason = ""
    world.adaptive_defense_director.completed_adaptation = &""
    world._on_run_state_event_logged("The complete systemic run is active. Survive, expand autonomy, recover the root components, and choose how the town ends.")
    _expect(not world.hud.notification_label.text.contains("The complete systemic run is active"), "Diagnostic-only release event log entries must not leak raw English into the HUD.")
    world._on_run_state_event_logged("The Heartforge light is weak. The companion is your only reliable protection.")
    _expect(world.hud.notification_label.text.contains("HERZOFENLICHT"), "The base Heartforge opening report must resolve to the selected locale on the release HUD.")
    var protocol_fixture := world.endgame_director.protocol(&"protocol.severance")
    world.operations_hud.update_protocols([protocol_fixture], "No final protocol active")
    world.operations_hud.open_endgame()
    _expect(world.operations_hud.selection_label.text == "TRENNUNG" and world.operations_hud.description_label.text.begins_with("Nutze die geborgenen Komponenten"), "German final-protocol choices must localize their names and descriptions instead of exposing canonical English data.")
    _expect(world.operations_hud.status_label.text.begins_with("Kein Endprotokoll aktiv"), "German final-protocol status must localize the inactive state.")
    _expect(world._localized_endgame_status_summary("Severance · 20%") == "Trennung · 20%", "German active final-protocol status must localize the protocol name in world objective and operation updates.")
    _expect(world._localized_endgame_status_summary("Severance completed") == "Trennung abgeschlossen", "German completed final-protocol status must localize the protocol name in world objective and operation updates.")
    _expect(world._localized_endgame_failure_reason("The Heartforge could not hold the final convergence long enough to complete the protocol.") == "Die Herzschmiede konnte die letzte Konvergenz nicht lange genug halten, um das Protokoll abzuschließen.", "German final-protocol failure reasons must remain attributable instead of falling back to English prose.")
    world._on_endgame_started(&"protocol.severance", "Severance")
    _expect(world.hud.notification_label.text.contains("TRENNUNG"), "German final-protocol convergence notification must localize the protocol name.")
    world.operations_hud.close()
    _expect(_front_end_has_button_text(world.release_front_end.pause_panel, "WELT SPEICHERN") and world.release_front_end.pause_subtitle_label.text == "DIE WELT IST PAUSIERT", "Changing to German in pause settings must refresh the already-built pause actions and subtitle.")
    world.hud.show_forge_menu()
    _expect(world.hud.forge_title.text == "HERZSCHMIEDE · MANUELLE FERTIGUNG", "German locale must refresh the first-session Heartforge title.")
    _expect(world.hud.forge_copy.text.begins_with("Der Mechromant muss"), "German locale must refresh the first-session fabrication explanation.")
    _expect(world.hud.forge_reserve_label.text == "AKTUELLER VORRAT · 24 Schrott · 0 Kognitionskerne", "The forge must repeat current reserves inside the dimmed fabrication modal.")
    _expect(world.hud.forge_buttons.size() >= 9 and world.hud.forge_buttons[0].text == "1  SCHROTTER BAUEN · 42 Schrott · 6,5 s", "German locale must refresh the shared and production forge actions.")
    _expect(world.hud.forge_close_button.text == "ESC  HERZSCHMIEDE SCHLIESSEN", "German locale must refresh the fixed forge close action.")
    _expect("BEWEGEN" in world.hud.help_label.text, "German locale must refresh the release input legend.")
    world.hud.hide_forge_menu()
    _expect(world.localization_service.text("objective.base.scrapper.title") == "FERTIGE EINEN SCHROTTER" and world.localization_service.text("objective.base.scrapper.detail", ["E"]).contains("drücke E"), "German lower-level opening objectives must localize the Heartforge fabrication stage and its binding replacement.")
    _expect(world.localization_service.text("objective.base.autonomy.detail").contains("koordinierten Gruppe") and world.localization_service.text("objective.base.expedition.title") == "BEREITE EINE ECHTE EXPEDITION VOR", "German lower-level autonomous and expedition objectives must resolve through the selected catalog.")
    _expect(world.localization_service.text("prompt.interaction.channeling") != "prompt.interaction.channeling" and world.localization_service.text("notification.event.scrap_recovered", [4]).begins_with("4 SCHROTT"), "German base interaction and early-run event catalogs must resolve their new release-facing keys.")
    world.player.global_position = Vector3(0.0, 0.0, -10.8)
    world._update_interaction_context()
    _expect(world.hud.prompt_label.text.begins_with("HALTE") and "BERGE" in world.hud.prompt_label.text and "Pistole" not in world.hud.prompt_label.text, "German salvage interaction prompts must be localized on the actual tactical HUD.")
    world.player.global_position = Vector3(100.0, 0.0, 100.0)
    world._update_interaction_context()
    _expect("PISTOLE" in world.hud.prompt_label.text and "BULWARK" in world.hud.prompt_label.text, "German no-context protection guidance must be localized on the actual tactical HUD.")
    world.player.global_position = Vector3(0.0, 0.0, 6.0)
    world._update_interaction_context()
    world.strategic_hud.open_outposts()
    _expect("AUSSENPOSTEN" in world.strategic_hud.title_label.text and world.strategic_hud.close_button.text == "SCHLIESSEN · ESC" and "Autonome Außenposten" in world.strategic_hud.detail_label.text, "German locale must refresh strategic outpost chrome and explanatory copy.")
    world.strategic_hud.close()
    var dynamic_operation := {
        "id": "operation.dynamic.pressure_suppression.region.west_grid",
        "dynamic_template_id": "dynamic.pressure_suppression",
        "localization_region_id": "region.west_grid",
        "route_waypoints": 4,
        "route_distance": 94.0,
        "route_variant": 0,
        "team_roles": ["scout", "guardian", "engineer"],
    }
    _expect(world.operations_hud._localized_operation_field(dynamic_operation, "name", "Stabilize West Grid") == "Westliches Netz stabilisieren", "German dynamic operation names must resolve the dynamic template namespace and region replacement.")
    _expect("Wegpunkte" in world.operations_hud._localized_route_brief(dynamic_operation) and world.operations_hud._localized_team_roles(dynamic_operation["team_roles"]) == "Späher, Wächter, Ingenieur", "German dynamic operation route grammar and team roles must stay localized.")
    var casualty_operation := dynamic_operation.duplicate(true)
    casualty_operation["dynamic_template_id"] = "dynamic.machine_recovery"
    casualty_operation["localization_machine_name"] = "Siebzehn"
    _expect(world.operations_hud._localized_operation_field(casualty_operation, "description", "Siebzehn went dark in West Grid.").begins_with("Siebzehn ist in der Region Westliches Netz"), "German casualty recovery briefings must localize both the machine and region replacements.")
    _expect(world.operations_hud._localized_operation_field({"id": "operation.west_grid_survey"}, "name", "Survey the West Grid") == "Westliches Netz erkunden", "German authored operation names must resolve stable operation catalog keys.")
    _expect(world.operations_hud._localized_operation_field({"id": "operation.buried_lab_airlock"}, "name", "Clear the Buried Lab Airlock") == "Luftschleuse des vergrabenen Labors räumen", "German expanded authored operation names must resolve stable catalog keys.")
    _expect(world.operations_hud._localized_operation_field({"id": "operation.north_transit_signal"}, "name", "Stabilize the North Transit Yard") == "Nördlichen Verkehrshof stabilisieren", "German extended authored operation names must resolve stable catalog keys.")
    world.operations_hud.open_endgame()
    _expect(world.operations_hud.title_label.text == "ENDPROTOKOLLE", "German locale must refresh final-protocol command chrome.")
    world.operations_hud.close()

    var route_detail := world.operation_detail_director as OperationDetailDirector3D
    _expect(route_detail != null, "Release runtime must retain the operation detail presentation director.")
    if route_detail != null:
        route_detail.show_route_recovery(&"operation.detour", Vector3(4.0, 0.0, 6.0), 1, 3)
        _expect("AUTONOMER UMWEG" in route_detail.route_recovery_label.text and "SEITENROUTE 1/3" in route_detail.route_recovery_label.text and "operation.detour.name" not in route_detail.route_recovery_label.text, "German locale must localize the visible autonomous detour marker without exposing a raw operation key.")
        route_detail.show_casualty_recovery(&"casualty.test_frame", Vector3(4.0, 0.0, 6.0), "Siebzehn")
        _expect("AUSFALLSIGNAL" in route_detail.casualty_recovery_label.text and "FELDSIGNAL TEST FRAME" in route_detail.casualty_recovery_label.text, "German locale must localize the visible casualty beacon marker.")
        service.set_locale(&"sv")
        route_detail.refresh_localized_text()
        _expect("AUTONOM OMVÄG" in route_detail.route_recovery_label.text and "FÖRLUSTSIGNAL" in route_detail.casualty_recovery_label.text and "operation.detour.name" not in route_detail.route_recovery_label.text, "Swedish locale must refresh already-visible autonomous markers without exposing a raw operation key.")
        route_detail.clear_route_recovery()
        route_detail.clear_casualty_recovery()
        service.set_locale(&"de")
    _expect(world.localization_service.text("notification.complete.route_recovery_marker_review") != "notification.complete.route_recovery_marker_review", "Route recovery marker review notifications must resolve to readable localized copy.")

    var tier_bootstrap := world.get_node_or_null("EnemyTierProgressionBootstrap") as EnemyTierProgressionBootstrap3D
    _expect(tier_bootstrap != null and tier_bootstrap.director != null, "Release runtime must expose one canonical population-tier director.")
    _expect(get_nodes_in_group(&"enemy_tier_progression").size() == 1, "Release runtime must contain exactly one active population-tier controller.")
    _expect(world.get_node_or_null("EnemyTierDirector") == null and world.get_node_or_null("EnemyTierHUD") == null, "The disabled legacy population controller and duplicate HUD must not exist in the release world.")
    _expect(world.ecology_director.is_processing() and world.strategic_ecology_director.is_processing(), "Birth handoff must keep local attention and strategic regional ecology processing alive.")
    _expect(world.ecology_director.external_population_control and world.strategic_ecology_director.external_population_control, "Both legacy ecology contexts must explicitly delegate births to the canonical tier director.")
    _expect(not world.ecology_director.spawn_enemy_callable.is_valid() and not world.strategic_ecology_director.spawn_enemy_callback.is_valid(), "Delegated ecology contexts must not retain an uncapped birth callback.")
    if tier_bootstrap != null and tier_bootstrap.director != null:
        var canonical := tier_bootstrap.director
        var event_state := canonical.to_dictionary()
        var tier_one_before := canonical.replenishment_rate(1)
        _expect(canonical.apply_event(&"tech.machine.forge_assistance"), "A representative technology must apply its canonical ecological consequence.")
        var tier_one_after := canonical.replenishment_rate(1)
        _expect(tier_one_after > tier_one_before, "The representative technology must visibly increase its configured replenishment pressure.")
        _expect(not canonical.apply_event(&"tech.machine.forge_assistance") and is_equal_approx(canonical.replenishment_rate(1), tier_one_after), "A repeated technology signal must be idempotent.")
        _expect(canonical.apply_event(&"operation.cathedral_brood_suppression"), "A representative suppression operation must reach the canonical ecological ledger.")
        _expect(canonical.replenishment_rate(1) < tier_one_after, "A suppression operation must reduce long-term replenishment instead of merely changing copy.")
        for protocol_id in [&"protocol.severance", &"protocol.containment", &"protocol.transformation"]:
            _expect(canonical.apply_event(protocol_id), "Endgame %s must apply one canonical ecological response." % String(protocol_id))
        var event_roundtrip := canonical.to_dictionary()
        canonical.restore_from_dictionary(event_roundtrip)
        _expect(canonical.applied_events.has(&"tech.machine.forge_assistance") and canonical.applied_events.has(&"protocol.transformation"), "The one canonical applied-event ledger must survive save/load.")
        canonical.restore_from_dictionary(event_state)

        var balance_actor: OrganicEnemyTiered3D
        for candidate in get_nodes_in_group(&"organic_enemies"):
            if candidate is OrganicEnemyTiered3D and is_instance_valid(candidate) and not candidate.is_in_group(&"enemy_tier_nests"):
                balance_actor = candidate as OrganicEnemyTiered3D
                break
        if balance_actor != null:
            world._apply_balance_to_existing_world()
            var first_balance := Vector3(balance_actor.maximum_health, balance_actor.attack_damage, balance_actor.move_speed)
            world._apply_balance_to_existing_world()
            var second_balance := Vector3(balance_actor.maximum_health, balance_actor.attack_damage, balance_actor.move_speed)
            _expect(first_balance.is_equal_approx(second_balance), "Applying the same release balance twice must not compound canonical tier stats.")

    var intel_hud := world.get_node_or_null("EnemyTierProgressionBootstrap/EnemyTierIntelHUD") as EnemyTierIntelHUD3D
    _expect(intel_hud != null, "Release runtime must expose the ecological intelligence summary panel.")
    if intel_hud != null:
        intel_hud.update_intel({
            "tier_1_density": "DENSE",
            "highest_confirmed_tier": 3,
            "highest_tier_name": "Predatory",
            "active_nests": 2,
            "trend": "WORSENING",
            "saturated_tiers": [2],
        })
        intel_hud.refresh_localized_text()
        _expect("ÖKOLOGISCHE INTELLIGENZ" == intel_hud.heading_label.text and "Höchste bestätigte Stufe" in intel_hud.tier_label.text and "SÄTTIGUNG" in intel_hud.escalation_label.text, "German locale must localize the ecological intelligence summary panel.")

    world.settings_service.set_value(&"language", "en", false)
    world.release_front_end.hide_all()
    service.set_locale(&"en")


func _front_end_has_button_text(root: Node, expected: String) -> bool:
    for node in root.find_children("*", "Button", true, false):
        if node is Button and (node as Button).text == expected:
            return true
    return false


func _test_controller_and_accessibility(world: IronwrightReleaseWorld3D) -> void:
    var required_actions: Array[StringName] = [
        &"iw_move_left",
        &"iw_move_right",
        &"iw_move_up",
        &"iw_move_down",
        &"iw_interact",
        &"iw_cancel",
        &"iw_follow",
        &"iw_follow_next",
        &"iw_map",
        &"iw_pause",
        &"iw_evolution",
        &"iw_outposts",
        &"iw_operations",
        &"iw_endgame",
        &"iw_focus_defend",
        &"iw_focus_salvage",
        &"iw_focus_expedition",
    ]
    for action in required_actions:
        _expect(InputMap.has_action(action), "Controller action %s must be registered." % String(action))
        var has_controller_event := false
        for event in InputMap.action_get_events(action):
            if event is InputEventJoypadButton or event is InputEventJoypadMotion:
                has_controller_event = true
        _expect(has_controller_event, "Controller action %s needs a joypad binding." % String(action))

    for movement_action in [&"iw_move_up", &"iw_move_down", &"iw_move_left", &"iw_move_right"]:
        var has_keyboard_event := false
        for event in InputMap.action_get_events(movement_action):
            if event is InputEventKey:
                has_keyboard_event = true
        _expect(has_keyboard_event, "Keyboard movement action %s needs a live key binding." % String(movement_action))

    var strategic_keyboard_bindings := {
        &"iw_evolution": KEY_T,
        &"iw_outposts": KEY_O,
        &"iw_follow_next": KEY_G,
    }
    for action in strategic_keyboard_bindings:
        var expected_key: Key = strategic_keyboard_bindings[action]
        var has_expected_key := false
        for event in InputMap.action_get_events(action):
            if event is InputEventKey and (event as InputEventKey).keycode == expected_key:
                has_expected_key = true
        _expect(has_expected_key, "Strategic action %s needs its default keyboard command key." % String(action))

    # Freeze the presentation camera while exercising the input actuator so
    # the assertion measures the input frame itself, not the release camera's
    # deliberate travel-direction reframe.
    world.set_process(false)
    world.camera.rotation = Vector3(0.0, PI * 0.37, 0.0)
    world.player.velocity = Vector3.ZERO
    var keyboard_position_before := world.player.global_position
    var expected_keyboard_direction := world.player._camera_relative_movement(Vector2(0.0, -1.0))
    Input.action_press(&"iw_move_up")
    for _frame in range(18):
        await physics_frame
    Input.action_release(&"iw_move_up")
    var keyboard_displacement := world.player.global_position - keyboard_position_before
    keyboard_displacement.y = 0.0
    _expect(keyboard_displacement.length() > 0.2 and keyboard_displacement.normalized().dot(expected_keyboard_direction) > 0.80, "The release Mechromancer must move through the shared camera-relative keyboard path.")

    world.player.velocity = Vector3.ZERO
    var position_before := world.player.global_position
    var expected_controller_direction := world.player._camera_relative_movement(Vector2(1.0, 0.0))
    var motion := InputEventJoypadMotion.new()
    motion.device = 0
    motion.axis = JOY_AXIS_LEFT_X
    motion.axis_value = 1.0
    Input.parse_input_event(motion)
    for _frame in range(18):
        await physics_frame
    var release_motion := InputEventJoypadMotion.new()
    release_motion.device = 0
    release_motion.axis = JOY_AXIS_LEFT_X
    release_motion.axis_value = 0.0
    Input.parse_input_event(release_motion)
    var controller_displacement := world.player.global_position - position_before
    controller_displacement.y = 0.0
    var controller_alignment := controller_displacement.normalized().dot(expected_controller_direction) if controller_displacement.length() > 0.001 else 0.0
    _expect(controller_displacement.length() > 0.2 and controller_alignment > 0.80, "The release Mechromancer must move from a camera-relative joypad axis, not only from raw keyboard state.")
    world.set_process(true)

    Input.action_press(&"iw_interact")
    await process_frame
    _expect(bool(world.player.call("_interact_held")), "Hold-to-interact channels must recognize the controller interact action.")
    Input.action_release(&"iw_interact")

    var settings := world.settings_service
    var original_camera_shake := float(settings.get_value(&"camera_shake", 0.65))
    var original_reduced_motion := bool(settings.get_value(&"reduced_motion", false))
    var original_reduced_flashes := bool(settings.get_value(&"reduced_flashes", false))
    # Exercise the actual supported ceiling, not a lower proxy. The release
    # protocol promises 140% text scaling at 1280x720, so this gate must prove
    # the real maximum survives the live accessibility tree pass.
    settings.set_value(&"text_scale", 1.4, false)
    settings.set_value(&"high_contrast_ui", true, false)
    settings.apply_accessibility_to_tree(world.hud)
    _expect(world.hud.resource_label.get_theme_font_size("font_size") >= 27, "Text scaling must enlarge the resource HUD.")
    _expect(world.hud.resource_label.get_theme_constant("outline_size") >= 4, "High contrast must strengthen text outlines.")
    settings.set_value(&"text_scale", 1.0, false)
    settings.set_value(&"high_contrast_ui", false, false)
    settings.set_value(&"colorblind_mode", "deuteranopia", false)
    if world.release_color_filter is ReleaseColorFilter3D:
        _expect(world.release_color_filter.is_active(), "A selected colour-vision mode must activate the live world filter.")
        _expect(world.release_color_filter.current_mode() == &"deuteranopia", "The live filter must expose the selected colour-vision mode.")
    settings.set_value(&"colorblind_mode", "unsupported-mode", false)
    _expect(str(settings.get_value(&"colorblind_mode", "")) == "off", "Unsupported colour-vision modes must fail closed to the neutral rendering.")
    _expect(not world.release_color_filter.is_active(), "An unsupported colour-vision mode must not leave a stale filter active.")
    settings.set_value(&"colorblind_mode", "off", false)
    var presentation_feedback := world.aesthetic_director.feedback
    _expect(presentation_feedback != null, "Release presentation must install the live feedback layer.")
    if presentation_feedback != null and presentation_feedback.has_method(&"accessibility_snapshot"):
        var default_feedback: Dictionary = presentation_feedback.call(&"accessibility_snapshot")
        _expect(bool(default_feedback.get("settings_resolved", false)), "Live presentation feedback must resolve the release settings service.")
        _expect(is_equal_approx(float(default_feedback.get("camera_shake_scale", -1.0)), original_camera_shake if not original_reduced_motion else 0.0), "Live presentation feedback must consume the configured camera-shake scale.")
        settings.set_value(&"camera_shake", 0.0, false)
        var no_shake_feedback: Dictionary = presentation_feedback.call(&"accessibility_snapshot")
        _expect(is_equal_approx(float(no_shake_feedback.get("camera_shake_scale", -1.0)), 0.0), "Camera-shake zero must reach live presentation feedback.")
        settings.set_value(&"reduced_motion", true, false)
        var reduced_motion_feedback: Dictionary = presentation_feedback.call(&"accessibility_snapshot")
        _expect(is_equal_approx(float(reduced_motion_feedback.get("camera_shake_scale", -1.0)), 0.0), "Reduced motion must suppress live camera shake.")
        settings.set_value(&"reduced_motion", false, false)
        settings.set_value(&"camera_shake", 0.65, false)
        settings.set_value(&"reduced_flashes", true, false)
        var reduced_flash_feedback: Dictionary = presentation_feedback.call(&"accessibility_snapshot")
        _expect(bool(reduced_flash_feedback.get("reduced_flashes", false)), "Reduced flashes must reach live presentation feedback.")
        settings.set_value(&"reduced_flashes", false, false)
    settings.set_value(&"camera_shake", original_camera_shake, false)
    settings.set_value(&"reduced_motion", original_reduced_motion, false)
    settings.set_value(&"reduced_flashes", original_reduced_flashes, false)
    settings.set_value(&"game_speed", 1.25, false)
    _expect(is_equal_approx(Engine.time_scale, 1.25), "Game speed accessibility setting must apply to the running release clock.")
    settings.set_value(&"game_speed", 1.0, false)
    _expect(is_equal_approx(Engine.time_scale, 1.0), "Game speed accessibility setting must restore the default clock.")

    var original_up := settings.get_key_binding(&"iw_move_up")
    var original_down := settings.get_key_binding(&"iw_move_down")
    _expect(original_up != KEY_NONE and original_down != KEY_NONE, "Release settings must expose valid movement bindings.")
    _expect(settings.set_key_binding(&"iw_move_up", KEY_I, false), "Release settings must accept a remapped keyboard action.")
    _expect(settings.get_key_binding(&"iw_move_up") == KEY_I, "Remapped keyboard action must persist in the live settings state.")
    var remapped_event_found := false
    for event in InputMap.action_get_events(&"iw_move_up"):
        if event is InputEventKey and (event as InputEventKey).keycode == KEY_I:
            remapped_event_found = true
    _expect(remapped_event_found, "Remapped keyboard action must update the live InputMap event.")
    _expect(settings.set_key_binding(&"iw_move_up", original_up, false), "Release settings must restore a remapped keyboard action.")
    _expect(settings.get_key_binding(&"iw_move_up") == original_up and settings.get_key_binding(&"iw_move_down") == original_down, "Restoring a keyboard action must leave the other movement bindings intact.")

    var original_interact := settings.get_key_binding(&"iw_interact")
    settings.last_input_device = &"keyboard_mouse"
    _expect(settings.input_binding_display_name(&"iw_interact") == OS.get_keycode_string(int(original_interact)), "The active input hint must expose the current keyboard binding.")
    _expect(settings.set_key_binding(&"iw_interact", KEY_I, false), "Release settings must accept a remapped interact action for live guidance.")
    _expect(settings.input_binding_display_name(&"iw_interact") == "I", "The active input hint must update after an interact remap.")
    _expect(world._input_binding_hint(&"iw_interact", "E") == "I", "World guidance must consume the live interact binding.")
    _expect("I INTERACT" in world.hud.help_label.text, "The tactical control legend must refresh after an interact remap.")
    world._update_first_session_guidance()
    _expect(world.objective_guidance != null and "HOLD I" in world.objective_guidance.marker_label.text, "The opening world marker must use the remapped interact binding.")
    _expect("Hold I" in world.hud.objective_label.text, "The opening objective copy must use the remapped interact binding.")
    var original_active_protocol := world.endgame_director.active_protocol
    var original_completed_protocol := world.endgame_director.completed_protocol
    world.endgame_director.active_protocol = {"id": &"protocol.severance"}
    world._update_first_session_guidance()
    _expect(not world.objective_guidance.is_guiding() and not world.objective_guidance.marker_root.visible, "The opening world marker must clear when a final protocol becomes active.")
    world.endgame_director.active_protocol = original_active_protocol
    world.endgame_director.completed_protocol = &"protocol.severance"
    world._update_first_session_guidance()
    _expect(not world.objective_guidance.is_guiding() and not world.objective_guidance.marker_root.visible, "The opening world marker must remain clear after final protocol victory.")
    world.endgame_director.completed_protocol = original_completed_protocol
    _expect(settings.set_key_binding(&"iw_interact", original_interact, false), "Release settings must restore the original interact binding.")
    _expect("E INTERACT" in world.hud.help_label.text, "Restoring the interact binding must refresh the control legend.")

    var original_controller_up := settings.get_controller_binding(&"iw_move_up")
    var original_controller_down := settings.get_controller_binding(&"iw_move_down")
    _expect(original_controller_up >= 0 and original_controller_down >= 0, "Release settings must expose valid controller bindings.")
    _expect(settings.set_controller_binding(&"iw_move_up", JOY_BUTTON_LEFT_SHOULDER, false), "Release settings must accept a remapped controller action.")
    _expect(settings.get_controller_binding(&"iw_move_up") == JOY_BUTTON_LEFT_SHOULDER, "Remapped controller action must persist in the live settings state.")
    var controller_event_found := false
    for event in InputMap.action_get_events(&"iw_move_up"):
        if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_SHOULDER:
            controller_event_found = true
    _expect(controller_event_found, "Remapped controller action must update the live InputMap event.")
    _expect(settings.set_controller_binding(&"iw_move_up", original_controller_up, false), "Release settings must restore a remapped controller action.")
    _expect(settings.get_controller_binding(&"iw_move_up") == original_controller_up and settings.get_controller_binding(&"iw_move_down") == original_controller_down, "Restoring a controller action must leave the other movement bindings intact.")


func _test_release_assets_and_art(world: IronwrightReleaseWorld3D) -> void:
    # The runtime intentionally starts with a bounded authored stream ring.
    # This broad asset audit explicitly promotes every persistent region so it
    # can inspect the complete release catalogue without changing boot policy.
    var region_lod := world.get_node_or_null("RegionPresentationLodDirector") as RegionPresentationLodDirector3D
    if region_lod != null and world.region_director != null:
        # This is an explicit full-catalogue inspection, not a player-focus
        # simulation. Freeze automatic reevaluation so the release dressing
        # rebuilds cannot race a concurrent stream-out during threaded loads.
        region_lod.set_process(false)
        for raw_region_id in world.region_director.region_data.keys():
            var region_id := StringName(raw_region_id)
            var landmark := world.region_director.get_landmark(region_id)
            if landmark == null or landmark.region_kind == &"sanctuary":
                continue
            # Promote one authored district at a time. This mirrors the
            # bounded runtime stream ring and prevents the compatibility
            # renderer from receiving a burst of simultaneous glTF imports
            # during a complete-catalogue audit.
            landmark.set_streamed_in(true)
            var package_name: String = str({
                &"industrial": "WestGridAuthoredScene",
                &"commercial": "FloodMarketAuthoredScene",
                &"archive": "ArchiveAuthoredScene",
                &"tenement": "TenementAuthoredScene",
                &"greenhouse": "GlasshouseAuthoredScene",
                &"waterfront": "RiverworksAuthoredScene",
                &"rail": "TramGraveyardAuthoredScene",
                &"observatory": "ObservatoryAuthoredScene",
                &"nest": "CathedralAuthoredScene",
                &"research": "BuriedLabsAuthoredScene",
                &"endgame": "RootCisternAuthoredScene",
            }.get(landmark.region_kind, ""))
            for _frame in range(120):
                var authored_package := landmark.get_node_or_null("PersistentRegionGeometry/%s" % package_name) as Node3D
                if authored_package != null and authored_package.get_child_count() > 0:
                    break
                await process_frame
            world.release_world_art.ensure_region_dressing(region_id)
            region_lod.set_region_streamed(region_id, true)
            # Let the compatibility renderer retire deferred resources before
            # the next high-definition district is promoted.
            await process_frame
    var texture_paths := [
        "res://assets/release/textures/asphalt_wet.png",
        "res://assets/release/textures/brick_ruin.png",
        "res://assets/release/textures/chitin.png",
        "res://assets/release/textures/concrete_wet.png",
        "res://assets/release/textures/grime_decal.png",
        "res://assets/release/textures/membrane.png",
        "res://assets/release/textures/metal_brushed.png",
        "res://assets/release/textures/moss_growth.png",
        "res://assets/release/textures/rust_panel.png",
        "res://assets/release/textures/asphalt_wet_normal.png",
        "res://assets/release/textures/brick_ruin_normal.png",
        "res://assets/release/textures/chitin_normal.png",
        "res://assets/release/textures/concrete_wet_normal.png",
        "res://assets/release/textures/grime_decal_normal.png",
        "res://assets/release/textures/membrane_normal.png",
        "res://assets/release/textures/metal_brushed_normal.png",
        "res://assets/release/textures/moss_growth_normal.png",
        "res://assets/release/textures/rust_panel_normal.png",
    ]
    for path in texture_paths:
        _expect(ResourceLoader.exists(path), "Release texture must import: %s" % path)
        _expect(load(path) is Texture2D, "Release texture must load as Texture2D: %s" % path)

    var audio_paths := [
        "res://assets/release/audio/ambience_city.wav",
        "res://assets/release/audio/ambience_sanctuary.wav",
        "res://assets/release/audio/ambience_industrial.wav",
        "res://assets/release/audio/ambience_waterfront.wav",
        "res://assets/release/audio/ambience_nest.wav",
        "res://assets/release/audio/ambience_cistern.wav",
        "res://assets/release/audio/music_title.wav",
        "res://assets/release/audio/music_sanctuary.wav",
        "res://assets/release/audio/music_embers.wav",
        "res://assets/release/audio/music_pressure.wav",
        "res://assets/release/audio/music_sovereignty.wav",
        "res://assets/release/audio/sfx_pistol.wav",
        "res://assets/release/audio/sfx_salvage.wav",
        "res://assets/release/audio/sfx_forge.wav",
        "res://assets/release/audio/sfx_organic_call_low.wav",
        "res://assets/release/audio/sfx_organic_call_mid.wav",
        "res://assets/release/audio/sfx_organic_call_high.wav",
        "res://assets/release/audio/sfx_organic_call_root.wav",
        "res://assets/release/audio/sfx_organic_call_bell.wav",
        "res://assets/release/audio/sfx_organic_call_wing.wav",
    ]
    for path in audio_paths:
        _expect(ResourceLoader.exists(path), "Release audio must import: %s" % path)
        _expect(load(path) is AudioStream, "Release audio must load as AudioStream: %s" % path)

    _expect(world.release_world_art.textures.size() == 9, "Release art director must load all nine texture families.")
    _expect(world.release_world_art.normal_textures.size() == 9, "Release art director must load normal relief for all nine texture families.")
    _expect(world.release_world_art.regions_dressed >= 12, "Every persistent region must receive release dressing.")
    _expect(world.release_world_art.meshes_textured > 30, "The existing world must receive a broad textured material pass.")
    _expect(world.release_audio.stream_library.size() >= 20, "Release audio director must load title music, regional ambience, adaptive music, family calls and species variants.")
    _expect(world.release_audio.stream_library.has(&"music_sanctuary"), "Release audio must load the warm Heartforge sanctuary music state.")
    _expect(world.release_audio.regional_ambience.size() == ReleaseAudioDirector3D.REGIONAL_AMBIENCE_SOURCES.size(), "Release audio director must prepare a bounded ambience bed for every non-sanctuary region family.")
    for raw_kind in ReleaseAudioDirector3D.REGIONAL_AMBIENCE_SOURCES:
        var region_kind := raw_kind as StringName
        var regional_player := world.release_audio.regional_ambience.get(region_kind) as AudioStreamPlayer
        var source_id := ReleaseAudioDirector3D.REGIONAL_AMBIENCE_SOURCES[region_kind] as StringName
        _expect(regional_player != null and regional_player.stream == world.release_audio.stream_library.get(source_id), "Region %s must retain its intentional authored ambience source." % String(region_kind))
    _expect(ReleaseAudioDirector3D.REGIONAL_AMBIENCE_SOURCES[&"endgame"] == &"ambience_cistern", "The Root Cistern must use its dedicated endgame ambience instead of inheriting the generic nest bed.")
    world.release_audio.set_title_screen_active(true)
    _expect(world.release_audio.current_mood == &"title", "Release audio must select the restrained title theme while the title screen is active.")
    world.release_audio.set_title_screen_active(false)
    _expect(world.release_audio.current_mood == &"embers", "Release audio must return to the embers theme when gameplay begins.")
    var saved_audio_player_position := world.player.global_position
    var saved_audio_progression := world.release_audio.progression
    var saved_audio_ecology := world.release_audio.strategic_ecology
    var saved_audio_endgame := world.release_audio.endgame
    world.release_audio.progression = null
    world.release_audio.strategic_ecology = null
    world.release_audio.endgame = null
    world.player.global_position = world.heartforge.global_position
    world.release_audio._evaluate_music_mood()
    _expect(world.release_audio.current_mood == &"sanctuary", "Gameplay near the Heartforge must select the warm sanctuary music state.")
    world.player.global_position = world.heartforge.global_position + Vector3(0.0, 0.0, ReleaseAudioDirector3D.SANCTUARY_MUSIC_RADIUS + 4.0)
    world.release_audio._evaluate_music_mood()
    _expect(world.release_audio.current_mood == &"embers", "Leaving the Heartforge sanctuary radius must return to the embers music state.")
    world.player.global_position = saved_audio_player_position
    world.release_audio.progression = saved_audio_progression
    world.release_audio.strategic_ecology = saved_audio_ecology
    world.release_audio.endgame = saved_audio_endgame
    _expect(not world.release_animation.attached_subjects.is_empty(), "Release secondary animation must attach to world subjects.")
    var tram_region_root := world.release_world_art.ensure_region_dressing(&"region.tram_graveyard") if world.release_world_art != null else null
    await process_frame
    var rail_dressing := tram_region_root.find_child("HighDefinitionRailDressing", true, false) if tram_region_root != null else null
    _expect(rail_dressing != null, "Release rail dressing must expose a bounded high-definition carriage layer.")
    if rail_dressing != null:
        _expect(rail_dressing.find_child("DerailedTram00", true, false) != null and rail_dressing.find_child("TramWindow00_00", true, false) != null, "Release rail dressing must expose layered carriage shell and window detail.")
        _expect(rail_dressing.find_child("TramRoofPlate00", true, false) != null and rail_dressing.find_child("TramBeltRail00_Front", true, false) != null and rail_dressing.find_child("TramWindow00_00_Front", true, false) != null, "Release rail dressing must expose paired carriage shell sides, roof plate and belt rails.")
        _expect(rail_dressing.find_child("TramServicePanel00", true, false) != null and rail_dressing.find_child("TramRoofVent00", true, false) != null, "Release rail dressing must expose service and roof hardware.")
        _expect(rail_dressing.find_child("TramBogiePlate00_00", true, false) != null and rail_dressing.find_child("TramAxle00_00", true, false) != null, "Release rail dressing must expose readable undercarriage detail.")
        _expect(rail_dressing.find_child("CatenaryMast00_00", true, false) != null and rail_dressing.find_child("CatenaryCrossarm00_00", true, false) != null, "Release rail dressing must expose paired overhead-service support hardware.")
        _expect(rail_dressing.find_child("CatenaryInsulator00_00_L", true, false) != null and rail_dressing.find_child("CatenaryDrop00_01", true, false) != null and rail_dressing.find_child("OverheadLine00_00", true, false) != null, "Release rail dressing must expose insulated catenary spans and suspension drops.")
    var archive_dressing := world.release_world_art.dressing_root.find_child("HighDefinitionArchiveDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(archive_dressing != null, "Release archive dressing must expose a bounded high-definition records layer.")
    if archive_dressing != null:
        _expect(archive_dressing.find_child("ArchiveGateway", true, false) != null and archive_dressing.find_child("ArchiveGatewayHeader", true, false) != null and archive_dressing.find_child("ArchiveGatewayIndex", true, false) != null, "Release archive dressing must expose a bounded civic gateway that makes the records destination readable at remote review distance.")
        _expect(archive_dressing.find_child("ArchiveGatewayPilasterL", true, false) != null and archive_dressing.find_child("ArchiveGatewayIndexRail0", true, false) != null and archive_dressing.find_child("ArchiveGatewayBeacon", true, false) != null, "Release archive gateway must retain layered pilaster, index-rail and beacon detail.")
        _expect(archive_dressing.find_child("ArchiveFragment00", true, false) != null and archive_dressing.find_child("ArchiveWindow00_00", true, false) != null, "Release archive dressing must expose layered archive shell and window detail.")
        _expect(archive_dressing.find_child("ArchiveWindowFront00_00", true, false) != null and archive_dressing.find_child("ArchiveWindowMullion00_00", true, false) != null and archive_dressing.find_child("ArchiveStackCap00", true, false) != null, "Release archive dressing must expose the approach-side records bays, mullions and capped stack detail.")
        _expect(archive_dressing.find_child("ArchiveRecordsShutter00", true, false) != null and archive_dressing.find_child("ArchiveRoofSlab00", true, false) != null, "Release archive dressing must expose records and roof hardware.")
        _expect(archive_dressing.find_child("ArchiveServiceRiser00", true, false) != null and archive_dressing.find_child("ArchiveFilingRail00_00", true, false) != null, "Release archive dressing must expose service and filing hardware.")
        _expect(archive_dressing.find_child("ArchiveSublevelWitness", true, false) != null and archive_dressing.find_child("ArchiveSublevelRecordCase", true, false) != null, "Release archive dressing must expose the physical sealed-catalogue witness.")
        _expect(archive_dressing.find_child("ArchiveSublevelStep00", true, false) != null and archive_dressing.find_child("ArchiveSublevelIndex", true, false) != null and archive_dressing.find_child("ArchiveSublevelLamp", true, false) != null, "Release archive dressing must expose the witness steps, index and service lamp.")
    var market_dressing := world.release_world_art.dressing_root.find_child("HighDefinitionMarketDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(market_dressing != null, "Release market dressing must expose a bounded high-definition stall layer.")
    if market_dressing != null:
        _expect(market_dressing.find_child("MarketStall00", true, false) != null and market_dressing.find_child("MarketCanopy00", true, false) != null, "Release market dressing must expose layered stall shells and canopy detail.")
        _expect(market_dressing.find_child("MarketCounter00", true, false) != null and market_dressing.find_child("MarketDisplayCrate00_00", true, false) != null, "Release market dressing must expose counter and display hardware.")
        _expect(market_dressing.find_child("MarketMembraneAwning00", true, false) != null and market_dressing.find_child("MarketCanopyPost00_-1_-1", true, false) != null, "Release market dressing must expose organic awning and canopy supports.")
        var market_canopy := market_dressing.find_child("MarketCanopy00Core", true, false) as MeshInstance3D
        var market_canopy_material := market_canopy.material_override as StandardMaterial3D if market_canopy != null else null
        _expect(market_canopy_material != null and market_canopy_material.albedo_texture != null, "Flood Market canopies must use the textured membrane material family instead of a flat color-only surface.")
    var research_dressing := world.release_world_art.dressing_root.find_child("HighDefinitionResearchDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(research_dressing != null, "Release research dressing must expose a bounded high-definition containment layer.")
    if research_dressing != null:
        _expect(research_dressing.find_child("LabConsole00", true, false) != null and research_dressing.find_child("LabDisplay00", true, false) != null, "Release research dressing must expose layered console and display detail.")
        _expect(research_dressing.find_child("LabCoolingLouver00", true, false) != null and research_dressing.find_child("LabSamplePort00", true, false) != null, "Release research dressing must expose cooling and sample hardware.")
        _expect(research_dressing.find_child("LabContainmentVessel00", true, false) != null and research_dressing.find_child("LabContainmentCore00", true, false) != null and research_dressing.find_child("LabContainmentCap00", true, false) != null, "Release research dressing must expose layered containment vessels.")
    var observatory_dressing := world.release_world_art.dressing_root.find_child("HighDefinitionObservatoryDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(observatory_dressing != null, "Release observatory dressing must expose a bounded high-definition optics layer.")
    if observatory_dressing != null:
        _expect(observatory_dressing.find_child("ObservatoryBase", true, false) != null and observatory_dressing.find_child("ObservatoryServiceDeck", true, false) != null, "Release observatory dressing must expose layered base and service deck detail.")
        _expect(observatory_dressing.find_child("ObservatoryDish", true, false) == null and observatory_dressing.find_child("ObservatoryDishRib00", true, false) != null and observatory_dressing.find_child("ObservatoryDishHub", true, false) != null, "Release observatory dressing must frame the authored reflector with rib and hub geometry without restoring the former proxy sphere.")
        _expect(observatory_dressing.find_child("DishFeed", true, false) != null and observatory_dressing.find_child("DishReceiverLens", true, false) != null, "Release observatory dressing must expose receiver hardware.")
        _expect(observatory_dressing.find_child("ObservatoryMigrationWitness", true, false) != null and observatory_dressing.find_child("ObservatoryMigrationMapPlate", true, false) != null, "Release observatory dressing must expose a physical migration-map witness beside the survey instrument.")
        _expect(observatory_dressing.find_child("ObservatoryMigrationTrace00", true, false) != null and observatory_dressing.find_child("ObservatoryMigrationNode02", true, false) != null and observatory_dressing.find_child("ObservatoryMigrationCalibrationLens", true, false) != null, "The Observatory migration witness must retain layered route traces and calibration hardware.")
    var waterworks_dressing := world.release_world_art.dressing_root.find_child("HighDefinitionWaterworksDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(waterworks_dressing != null, "Release waterworks dressing must expose a bounded high-definition pump layer.")
    if waterworks_dressing != null:
        _expect(waterworks_dressing.find_child("PumpWalkway00", true, false) != null and waterworks_dressing.find_child("PumpWalkwayGrate00_00", true, false) != null, "Release waterworks dressing must expose layered walkways and grates.")
        _expect(waterworks_dressing.find_child("PumpGantry00", true, false) != null and waterworks_dressing.find_child("PumpGantryCrossbar00", true, false) != null, "Release waterworks dressing must expose gantry hardware.")
        _expect(waterworks_dressing.find_child("PumpHousing00", true, false) != null and waterworks_dressing.find_child("PumpHousingLouver00", true, false) != null and waterworks_dressing.find_child("PumpControlPanel00", true, false) != null, "Release waterworks dressing must expose pump housing and controls.")
        _expect(waterworks_dressing.find_child("RiverWaterChannel00", true, false) != null and waterworks_dressing.find_child("RiverWaterFoam00_00", true, false) != null, "Release waterworks dressing must expose readable wet channels and flow breaks.")
        _expect(waterworks_dressing.find_child("RiverWaterRetainingWallL", true, false) != null and waterworks_dressing.find_child("WaterHeaderPipe00", true, false) != null, "Release waterworks dressing must expose retaining and manifold hardware.")
        _expect(waterworks_dressing.find_child("WaterSluiceGate", true, false) != null and waterworks_dressing.find_child("WaterSluiceControlPanel", true, false) != null, "Release waterworks dressing must expose a readable sluice assembly.")
    var tenement_dressing := world.release_world_art.dressing_root.find_child("HighDefinitionTenementDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(tenement_dressing != null, "Release tenement dressing must expose a bounded high-definition residential layer.")
    if tenement_dressing != null:
        _expect(tenement_dressing.find_child("TenementBalcony00", true, false) != null and tenement_dressing.find_child("TenementBalconyRail00", true, false) != null, "Release tenement dressing must expose layered balcony and railing detail.")
        _expect(tenement_dressing.find_child("TenementBalconyPost00_00", true, false) != null and tenement_dressing.find_child("TenementBalconyService00", true, false) != null, "Release tenement dressing must expose balcony support and service hardware.")
        _expect(tenement_dressing.find_child("TenementClothesline00", true, false) != null and tenement_dressing.find_child("TenementHangingCloth00_00", true, false) != null, "Release tenement dressing must expose readable residential clothing detail.")
        _expect(tenement_dressing.find_child("TenementCourtThreshold", true, false) != null and tenement_dressing.find_child("TenementCourtCanopy", true, false) != null and tenement_dressing.find_child("TenementCourtServicePanel", true, false) != null and tenement_dressing.find_child("TenementCourtLight", true, false) != null, "Release tenement dressing must expose a bounded shared residential court threshold.")
        var cloth_meshes := tenement_dressing.find_children("TenementHangingCloth*", "MeshInstance3D", true, false)
        var cloth_palette: Dictionary = {}
        for cloth_node in cloth_meshes:
            var cloth_mesh := cloth_node as MeshInstance3D
            var cloth_material := cloth_mesh.material_override as StandardMaterial3D if cloth_mesh != null else null
            if cloth_material != null:
                cloth_palette[cloth_material.albedo_color.to_html(false)] = true
        _expect(cloth_meshes.size() >= 12 and cloth_palette.size() >= 3, "Release tenement laundry must retain varied weathered cloth materials instead of repeated bright panels.")
    var cistern_dressing := world.release_world_art.dressing_root.find_child("HighDefinitionCisternDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(cistern_dressing != null, "Release Root Cistern dressing must expose a bounded high-definition service layer.")
    if cistern_dressing != null:
        _expect(cistern_dressing.find_child("CisternServiceRing", true, false) != null and cistern_dressing.find_child("CisternSignalRing", true, false) != null, "Release Root Cistern dressing must expose layered service and signal rings.")
        _expect(cistern_dressing.find_child("CisternControlDeck", true, false) != null and cistern_dressing.find_child("CisternDeckGrate00", true, false) != null and cistern_dressing.find_child("CisternProtocolPanel", true, false) != null, "Release Root Cistern dressing must expose an approach-facing control deck.")
        _expect(cistern_dressing.find_child("CisternPumpHousing", true, false) != null and cistern_dressing.find_child("CisternPumpLouver", true, false) != null and cistern_dressing.find_child("CisternHeaderPipe00", true, false) != null, "Release Root Cistern dressing must expose buried pump hardware and header pipes.")
        _expect(cistern_dressing.find_child("CisternRootAnchor00", true, false) != null and cistern_dressing.find_child("CisternAnchorPulse00", true, false) != null, "Release Root Cistern dressing must expose bounded living-root anchor detail.")
        var cistern_service_ring := cistern_dressing.find_child("CisternServiceRing", true, false) as MeshInstance3D
        var cistern_service_material := cistern_service_ring.material_override as StandardMaterial3D if cistern_service_ring != null else null
        _expect(cistern_service_material != null and cistern_service_material.albedo_color.r < 0.20 and cistern_service_material.albedo_color.g < 0.30, "Release Root Cistern service ring must retain a dark wet-metal treatment instead of blooming into a white disc.")
        var cistern_signal_ring := cistern_dressing.find_child("CisternSignalRing", true, false) as MeshInstance3D
        var cistern_signal_material := cistern_signal_ring.material_override as StandardMaterial3D if cistern_signal_ring != null else null
        _expect(cistern_signal_material != null and cistern_signal_material.albedo_color.r < 0.12 and cistern_signal_material.albedo_color.g < 0.25, "Release Root Cistern signal ring must retain a dark inset beneath the cyan service pulse.")
    var root_cistern_landmark := world.region_director.get_landmark(&"region.root_cistern") if world.region_director != null else null
    var authored_basin := root_cistern_landmark.find_child("RootCisternBasin", true, false) as MeshInstance3D if root_cistern_landmark != null else null
    var authored_basin_material := authored_basin.material_override as StandardMaterial3D if authored_basin != null else null
    _expect(authored_basin_material != null and authored_basin_material.albedo_color.r < 0.20 and authored_basin_material.albedo_color.g < 0.35, "Root Cistern authored basin must retain a dark wet-concrete tint instead of blooming into a white review card.")
    var authored_water := root_cistern_landmark.find_child("RootCisternBasinWater", true, false) as MeshInstance3D if root_cistern_landmark != null else null
    var authored_water_material := authored_water.material_override as StandardMaterial3D if authored_water != null else null
    _expect(authored_water_material != null and not authored_water_material.emission_enabled and authored_water_material.albedo_color.r < 0.12 and authored_water_material.albedo_color.g < 0.25, "Root Cistern authored water must remain a dark readable pool instead of blooming over the core.")


func _test_presentation_review(world: IronwrightReleaseWorld3D) -> void:
    await world._start_presentation_review()
    await process_frame
    _expect(world.presentation_review_pages.size() == 15, "Presentation review must expose the three core pages, all eleven remote regions and the autonomous outpost role page.")
    _expect(world.release_audio != null and world.release_audio.process_mode == Node.PROCESS_MODE_DISABLED and world.release_audio.transient_feedback_locked, "Presentation review must suspend release audio and transient captions so live-world alerts cannot cover the authored gallery frame.")
    _expect(world.presentation_review_label != null and "1-9, 0 DIRECT PAGE" in world.presentation_review_label.text, "Presentation review navigation must describe the digit-key page controls clearly.")
    _expect(world.release_world_art != null and world.release_world_art.dressing_root != null, "Presentation review must retain the release dressing root alongside its controller.")
    _expect((world.presentation_review_pages[3] as Array).is_empty(), "Presentation review must keep unvisited remote pages lazy instead of constructing the whole gallery at startup.")
    await world._show_presentation_review_page(0)
    await process_frame
    _expect(world.presentation_review_camera_desired.z - world.presentation_review_camera_target.z <= 13.3, "Core presentation pages must use a closer roster framing for authored detail review.")
    _expect(absf(world.player.rotation.y) <= 0.05, "The friendly roster review must show the Mechromancer's authored field-engineer front rather than the rear tactical camera angle.")
    var friendly_front_fill := world.presentation_review_stage.get_node_or_null("ReviewFrontFill") as OmniLight3D if world.presentation_review_stage != null else null
    _expect(friendly_front_fill != null and friendly_front_fill.light_energy <= 2.5, "Friendly roster review must use a restrained shared key so authored steel and copper material breaks remain readable.")
    var friendly_lamp_count := 0
    var friendly_lamp_max_energy := 0.0
    for friendly_actor in world.presentation_review_pages[0]:
        var friendly_node := friendly_actor as Node3D
        if friendly_node == null:
            continue
        for child in friendly_node.find_children("*", "OmniLight3D", true, false):
            var lamp := child as OmniLight3D
            if lamp == null:
                continue
            friendly_lamp_count += 1
            friendly_lamp_max_energy = maxf(friendly_lamp_max_energy, lamp.light_energy)
    _expect(friendly_lamp_count > 0 and friendly_lamp_max_energy <= 0.25, "Friendly roster review must attenuate actor sensor lamps so floor pools do not overpower authored robot materials.")
    world.player.apply_progression_visuals({
        &"unlock_machine_society": true,
        &"unlock_adaptive_defence": true,
        &"unlock_final_protocol_research": true,
        &"machine_signal_lattice": true,
    }, 5)
    await process_frame
    _expect(world.player.find_child("MechromancerProgressionVisuals", true, false) != null, "The Mechromancer must expose a derived progression visual layer.")
    _expect(world.player.find_child("MechromancerTierIIShoulderBrace", true, false) != null and world.player.find_child("MechromancerTierIIICognitionRail", true, false) != null, "Heartforge and machine-society progression must add protected field and cognition hardware to the player model.")
    _expect(world.player.find_child("MechromancerTierIVBioSensorLens", true, false) != null and world.player.find_child("MechromancerTierVProtocolClasp", true, false) != null, "Late progression must add adaptive sensing and protocol hardware without replacing the field-engineer silhouette.")
    await world._show_presentation_review_page(1)
    await process_frame
    _expect(world.presentation_review_camera_desired.z - world.presentation_review_camera_target.z <= 14.0, "Organic presentation pages must use a dedicated close detail frame for authored anatomy review.")
    var early_review_page: Array = world.presentation_review_pages[1]
    if early_review_page.size() >= 7:
        var first_early_actor := early_review_page[0] as Node3D
        var second_early_actor := early_review_page[1] as Node3D
        _expect(first_early_actor != null and second_early_actor != null and absf(second_early_actor.position.x - first_early_actor.position.x) >= 3.0, "Organic presentation rows must preserve a readable horizontal gap between authored families.")
        var third_early_actor := early_review_page[2] as Node3D
        var fourth_early_actor := early_review_page[3] as Node3D
        _expect(third_early_actor != null and fourth_early_actor != null and third_early_actor.position.z > fourth_early_actor.position.z + 3.0, "Early organic presentation must separate its broad near row from the rear row so wing and limb silhouettes remain judgeable.")
        _expect(is_equal_approx(first_early_actor.position.x, -4.0) and is_equal_approx(third_early_actor.position.x, 4.0), "Early organic presentation must use the fitted triangular near-row composition.")
        var early_rear_tier_base := world.presentation_review_stage.get_node_or_null("ReviewEarlyRearTierBase") as Node3D
        var early_rear_tier_top := world.presentation_review_stage.get_node_or_null("ReviewEarlyRearTierTop") as Node3D
        _expect(early_rear_tier_base != null and early_rear_tier_top != null and early_rear_tier_base.visible and early_rear_tier_top.visible, "Early organic presentation must expose a grounded rear display tier so the back-row anatomy is not visually occluded.")
        _expect(fourth_early_actor.position.y >= 0.6 and fourth_early_actor.position.y <= 0.7, "Early organic rear-row actors must remain grounded on the raised presentation tier.")
    await world._show_presentation_review_page(2)
    await process_frame
    var late_review_page: Array = world.presentation_review_pages[2]
    if late_review_page.size() >= 1:
        var first_late_actor := late_review_page[0] as Node3D
        var tier_root := first_late_actor.find_child("TierSilhouette", true, false) as Node3D if first_late_actor != null else null
        var tier_detail := tier_root.get_node_or_null("TierHighDefinitionDetail") as Node3D if tier_root != null else null
        var signal_socket := tier_detail.get_node_or_null("TierCrownRing") as Node3D if tier_detail != null else null
        _expect(tier_root != null and str(tier_root.get_meta(&"presentation_profile", "")) == "compact_authored_focal_signal", "Active organic families must retain the compact authored-body tier signal in close review.")
        _expect(tier_detail != null and tier_detail.find_child("TierDorsalPlate00", true, false) != null and tier_detail.find_child("TierVascularChannelL00", true, false) != null and tier_detail.find_child("TierVascularChannelR00", true, false) != null, "The compact tier signal must remain one shallow scute with two short surface channels.")
        _expect(signal_socket != null and str(signal_socket.get_meta(&"mesh_policy", "")) == "meshless_signal_socket" and signal_socket.find_child("TierCrownNode00", true, false) != null, "Tier identity must use a meshless authored-surface socket with embedded signal buds.")
        _expect(first_late_actor == null or first_late_actor.find_child("OrganicSurfaceSeam", true, false) == null, "The close-review organism must not restore the removed broad generic surface seam.")
    for page_index in range(3, 3 + world.PRESENTATION_REVIEW_REGIONS.size()):
        await world._show_presentation_review_page(page_index)
        await process_frame
        var region_page: Array = world.presentation_review_pages[page_index]
        _expect(region_page.size() == 1, "Every remote presentation-review page must expose one landmark actor.")
        if region_page.size() == 1:
            _expect((region_page[0] as Node3D).visible, "Every remote presentation-review landmark must be visible when selected.")
        _expect(world.presentation_review_camera_desired.z - world.presentation_review_camera_target.z <= 19.1, "Remote presentation pages must use a closer landmark framing for authored detail review.")
    var riverworks_review_offset := world._presentation_review_region_camera_offset(&"region.riverworks")
    _expect(riverworks_review_offset.z <= 16.6 and riverworks_review_offset.y <= 10.3, "Riverworks presentation review must use a closer frame for its pump and sluice hardware.")
    var tenement_review_offset := world._presentation_review_region_camera_offset(&"region.east_tenements")
    _expect(tenement_review_offset.z <= 19.2 and tenement_review_offset.y <= 9.2 and tenement_review_offset.x >= 6.5, "East Tenements presentation review must use a bounded diagonal frame for its facade, balcony and laundry hardware.")
    var west_grid_review_offset := world._presentation_review_region_camera_offset(&"region.west_grid")
    _expect(west_grid_review_offset.z <= 16.4 and west_grid_review_offset.y <= 8.6 and west_grid_review_offset.x <= -7.0, "West Grid presentation review must use a bounded diagonal frame for its industrial focal and reroute witness.")
    var tram_review_offset := world._presentation_review_region_camera_offset(&"region.tram_graveyard")
    _expect(tram_review_offset.z <= 16.6 and tram_review_offset.y <= 10.3 and is_zero_approx(tram_review_offset.x), "Tram Graveyard presentation review must use a centered rail-yard frame for its carriage hardware.")
    await world._show_presentation_review_page(9)
    await process_frame
    var tram_review_page: Array = world.presentation_review_pages[9] if world.presentation_review_pages.size() > 9 else []
    if tram_review_page.size() == 1:
        var tram_review_actor := tram_review_page[0] as Node3D
        _expect(is_zero_approx(tram_review_actor.rotation.y), "Tram Graveyard review must face the authored carriage fronts toward the exact gallery camera.")
        _expect(tram_review_actor.name == "TramGraveyardPresentationReviewActor" and tram_review_actor.find_child("TramYardDeck", true, false) != null, "Tram Graveyard review must use a dedicated authored actor with its grounded yard deck.")
    var tram_review_dressing := world.release_world_art.region_dressing_root(&"region.tram_graveyard") if world.release_world_art != null else null
    _expect(tram_review_dressing == null or not tram_review_dressing.visible, "Tram Graveyard review must hide the sparse release dressing so the authored carriage pair remains the focal landmark.")
    var flood_market_review_offset := world._presentation_review_region_camera_offset(&"region.flood_market")
    _expect(flood_market_review_offset.z <= 15.5 and flood_market_review_offset.y <= 9.5 and flood_market_review_offset.x >= 8.4, "Flood Market presentation review must use a bounded diagonal frame for its canopy, stall and water-channel hardware.")
    var cathedral_review_offset := world._presentation_review_region_camera_offset(&"region.cathedral_quarter")
    _expect(cathedral_review_offset.z <= 19.6 and cathedral_review_offset.y <= 8.8 and cathedral_review_offset.x >= 6.2, "Cathedral Quarter presentation review must use a bounded diagonal frame for its nave, tower and choir hardware.")
    var observatory_review_offset := world._presentation_review_region_camera_offset(&"region.observatory_ridge")
    _expect(observatory_review_offset.z <= 16.8 and observatory_review_offset.y <= 5.0 and observatory_review_offset.x >= 5.6, "Observatory Ridge presentation review must use a bounded low diagonal survey-station frame for its dish and instrument hardware.")
    await world._show_presentation_review_page(10)
    await process_frame
    var cathedral_dressing := world.release_world_art.region_dressing_root(&"region.cathedral_quarter") if world.release_world_art != null else null
    _expect(world.release_world_art != null and world.release_world_art.dressing_root.visible, "Remote presentation review must keep the sibling release dressing root visible.")
    _expect(cathedral_dressing != null and cathedral_dressing.visible and cathedral_dressing.find_child("CathedralReleaseFacade", true, false) != null, "Cathedral Quarter presentation review must retain its release facade dressing when selected.")
    if cathedral_dressing != null:
        _expect(cathedral_dressing.find_child("CathedralChoirCrownRail", true, false) != null and cathedral_dressing.find_child("CathedralChoirPipe03", true, false) != null and cathedral_dressing.find_child("CathedralChoirSignal", true, false) != null, "Cathedral Quarter presentation review must retain its layered choir crown and signal detail.")
        _expect(cathedral_dressing.find_child("CathedralReleaseRoofline", true, false) != null and cathedral_dressing.find_child("CathedralReleaseRoofEaveL", true, false) != null and cathedral_dressing.find_child("CathedralReleaseClerestory02", true, false) != null and cathedral_dressing.find_child("CathedralReleaseRoofFinial", true, false) != null, "Cathedral Quarter presentation review must retain a broken roofline, clerestory and finial silhouette.")
        var bell_yard := cathedral_dressing.find_child("CathedralBellYardWitness", true, false)
        _expect(bell_yard != null and bell_yard.find_child("CathedralBellYardBell", true, false) != null and bell_yard.find_child("CathedralBellYardSilenceCollar", true, false) != null, "Cathedral Quarter presentation review must retain a physical bell-yard witness for the brood-suppression history.")
    await world._show_presentation_review_page(13)
    await process_frame
    var page: Array = world.presentation_review_pages[13] if world.presentation_review_pages.size() > 13 else []
    _expect(page.size() == 1, "Root Cistern presentation review must expose one dedicated review actor.")
    if page.size() == 1:
        var actor := page[0] as Node3D
        _expect(actor != null and actor.visible, "Root Cistern presentation review actor must be visible on the final remote page.")
        _expect(actor != null and is_equal_approx(actor.rotation.y, PI / 6.0), "Root Cistern presentation review must use the between-pylons capstone framing angle.")
        _expect(actor != null and actor.find_children("*", "MeshInstance3D", true, false).size() > 20, "Root Cistern presentation review actor must retain its authored high-definition mesh hierarchy.")
        _expect(actor != null and actor.find_child("RootCisternCoreCollar", true, false) != null and actor.find_child("RootCisternCoreRoot0", true, false) != null, "Root Cistern presentation review must retain the grounded collar and radial root-brace detail.")
        _expect(actor != null and actor.find_child("RootCisternCoreCapPlate", true, false) != null and actor.find_child("RootCisternCoreCapCollar", true, false) != null and actor.find_child("RootCisternCoreCapSocket", true, false) != null and actor.find_child("RootCisternCoreCapRib00", true, false) != null, "Root Cistern presentation review must retain the distinct capstone interface and radial service ribs.")
        var review_basin := actor.find_child("RootCisternBasin", true, false) as MeshInstance3D
        var review_basin_material := review_basin.material_override as StandardMaterial3D if review_basin != null else null
        _expect(review_basin_material != null and review_basin_material.albedo_color.r < 0.20 and review_basin_material.albedo_color.g < 0.35, "Root Cistern presentation review must retain the dark basin treatment used by the persistent landmark.")
        var review_water := actor.find_child("RootCisternBasinWater", true, false) as MeshInstance3D
        var review_water_material := review_water.material_override as StandardMaterial3D if review_water != null else null
        _expect(review_water_material != null and not review_water_material.emission_enabled and review_water_material.albedo_color.r < 0.12 and review_water_material.albedo_color.g < 0.25, "Root Cistern presentation review must retain a dark water treatment around the core.")
    await world._show_presentation_review_page(11)
    await process_frame
    var observatory_page: Array = world.presentation_review_pages[11] if world.presentation_review_pages.size() > 11 else []
    _expect(observatory_page.size() == 1, "Observatory Ridge presentation review must expose one dedicated review actor.")
    if observatory_page.size() == 1:
        var observatory_actor := observatory_page[0] as Node3D
        _expect(observatory_actor != null and observatory_actor.visible, "Observatory Ridge presentation review actor must be visible on its remote page.")
        _expect(observatory_actor != null and observatory_actor.find_children("*", "MeshInstance3D", true, false).size() > 20, "Observatory Ridge presentation review actor must retain its authored mesh hierarchy.")
    await world._show_presentation_review_page(12)
    await process_frame
    var buried_labs_page: Array = world.presentation_review_pages[12] if world.presentation_review_pages.size() > 12 else []
    _expect(buried_labs_page.size() == 1, "Buried Laboratories presentation review must expose one dedicated review actor.")
    if buried_labs_page.size() == 1:
        var buried_labs_actor := buried_labs_page[0] as Node3D
        _expect(buried_labs_actor != null and buried_labs_actor.visible, "Buried Laboratories presentation review actor must be visible on its remote page.")
        _expect(buried_labs_actor != null and buried_labs_actor.find_children("*", "MeshInstance3D", true, false).size() > 20, "Buried Laboratories presentation review actor must retain its authored mesh hierarchy.")
        _expect(buried_labs_actor != null and buried_labs_actor.find_child("BuriedLabsGenomePrism", true, false) != null and buried_labs_actor.find_child("BuriedLabsExtractionBeam", true, false) != null, "Buried Laboratories presentation review actor must retain its genome-prism extraction focal assembly.")
        var buried_labs_review_offset := world._presentation_review_region_camera_offset(&"region.buried_labs")
        _expect(buried_labs_review_offset.z <= 15.1 and buried_labs_review_offset.y <= 10.3, "Buried Laboratories presentation review must use a closer vertical frame for its authored extraction gantry.")
    await world._show_presentation_review_page(14)
    await process_frame
    var outpost_page: Array = world.presentation_review_pages[14] if world.presentation_review_pages.size() > 14 else []
    _expect(outpost_page.size() == 4, "Autonomous outpost presentation review must expose all four role silhouettes.")
    _expect(world.camera.fov >= 47.5 and world.camera.fov <= 48.5 and world.presentation_review_camera_target.y >= 2.2, "Autonomous outpost review must use a wide elevated frame for the Tier III shelter and role hardware.")
    if outpost_page.size() == 4:
        _expect(absf((outpost_page[2] as Node3D).position.z - (outpost_page[0] as Node3D).position.z) >= 4.5, "Autonomous outpost review must separate its two role rows for readable shelter and signature detail.")
        _expect(absf((outpost_page[1] as Node3D).position.x - (outpost_page[0] as Node3D).position.x) >= 8.5, "Autonomous outpost review must separate adjacent shelter footprints for readable role hardware.")
    for index in outpost_page.size():
        var outpost_actor := outpost_page[index] as Outpost3D
        _expect(outpost_actor != null and outpost_actor.visible and is_equal_approx(absf(outpost_actor.rotation.y), PI), "Autonomous outpost role review actors must face the gallery camera.")
        if outpost_actor != null:
            _expect(outpost_actor.find_child("OutpostAuthoredModel", true, false) != null and outpost_actor.find_child("TierFrame3", true, false) != null, "Autonomous outpost role review must retain the authored shelter and Tier III frame.")
            _expect(outpost_actor.find_child("OutpostRoleSignature", true, false) != null, "Autonomous outpost role review must retain its bounded role-signature assembly.")
            if index == 0:
                _expect(outpost_actor.find_child("ResourceIntakeCollar", true, false) != null, "Resource outpost review must retain the high-definition intake collar.")
            elif index == 1:
                _expect(outpost_actor.find_child("DefenceTurretCollar", true, false) != null, "Defence outpost review must retain the high-definition turret collar.")
            elif index == 2:
                _expect(outpost_actor.find_child("ScoutMastBraceLeft", true, false) != null, "Scout outpost review must retain the high-definition mast brace.")
            elif index == 3:
                _expect(outpost_actor.find_child("RepairFieldRing", true, false) != null, "Repair outpost review must retain the high-definition field ring.")
    for core_page in range(3):
        await world._show_presentation_review_page(core_page)
        await process_frame
        var core_actors: Array = world.presentation_review_pages[core_page]
        _expect(core_actors.size() >= 3, "Each core presentation page must expose enough actors for a readable staged composition.")
        if core_actors.size() >= 3:
            var first_core_actor := core_actors[0] as Node3D
            var last_core_actor := core_actors[core_actors.size() - 1] as Node3D
            _expect(first_core_actor != null and last_core_actor != null and absf(first_core_actor.position.z - last_core_actor.position.z) > 1.0, "Core presentation pages must use depth-separated rows so authored actors remain judgeable.")
            if core_page == 1 and first_core_actor != null:
                var skitterling_shell := first_core_actor.find_child("SkitterlingAuthoredShell", true, false) as Node3D
                _expect(skitterling_shell != null and skitterling_shell.scale.x >= 0.55, "The small Skitterling shell must retain an enlarged authored presentation shell instead of becoming a thumbnail.")
                _expect(first_core_actor.position.z >= 1.8, "The small Skitterling shell must be staged slightly forward for readable anatomy without stretching its actor root.")
        if core_page >= 1:
            for core_actor in core_actors:
                var staged_actor := core_actor as Node3D
                var x_limit := 7.2 if core_page == 2 else 6.4
                _expect(staged_actor != null and absf(staged_actor.position.x) <= x_limit, "Organic presentation pages must keep every staged family fully inside the bounded two-row review frame.")
            if core_page == 2:
                _expect(absf((core_actors[3] as Node3D).position.z - (core_actors[0] as Node3D).position.z) > 4.0, "Late-organic presentation must give its broadest shells a deeper second row so layered silhouettes do not merge.")
            _expect(world.camera.fov <= 54.5, "Organic presentation pages must use a bounded close camera frame for anatomy review.")
        if core_page >= 1:
            var organic_front_fill := world.presentation_review_stage.get_node_or_null("ReviewFrontFill") as OmniLight3D
            var organic_cool_light := world.presentation_review_stage.get_node_or_null("ReviewCoolLight") as OmniLight3D
            var organic_detail_fill := world.presentation_review_stage.get_node_or_null("ReviewOrganicFill") as OmniLight3D
            _expect(organic_front_fill != null and organic_front_fill.light_energy >= 4.0, "Organic presentation pages must receive a stronger balanced-frame key light for material separation.")
            _expect(organic_cool_light != null and organic_cool_light.light_energy >= 3.2, "Organic presentation pages must retain a cool rim lift for readable anatomy edges.")
            _expect(organic_detail_fill != null and organic_detail_fill.visible and organic_detail_fill.light_energy >= 1.5, "Organic presentation pages must receive a restrained low front fill for secondary anatomy readability.")
        _expect(world.presentation_review_camera_desired.z < 18.0, "Core presentation pages must use the closer review camera framing.")
    await world._show_presentation_review_page(14)
    world.presentation_review_active = false
    world.get_tree().paused = false
    world._set_tactical_hud_visible(true)


func _test_content_breadth(world: IronwrightReleaseWorld3D) -> void:
    # Content breadth is a catalogue audit, so explicitly restore every
    # authored region before checking its stable landmark sockets.
    var region_lod := world.get_node_or_null("RegionPresentationLodDirector") as RegionPresentationLodDirector3D
    if region_lod != null and world.region_director != null:
        for raw_region_id in world.region_director.region_data.keys():
            var region_id := StringName(raw_region_id)
            region_lod.set_region_streamed(region_id, true)
            world.release_world_art.ensure_region_dressing(region_id)
    _expect(world.region_director.region_data.size() >= 12, "Commercial release must contain at least twelve persistent regions.")
    _expect(world.long_operation_director.operations.size() >= 16, "Commercial release must contain at least sixteen physical long-range operations.")
    for operation_id in [
            &"operation.north_archive_sublevel",
            &"operation.east_residential_rescue",
            &"operation.west_transformer_repair",
            &"operation.root_signal_purge"]:
        _expect(world.long_operation_director.operations.has(operation_id), "The expanded operation breadth must retain %s." % String(operation_id))
    _expect(world.outpost_sites.size() >= 8, "Commercial release must contain at least eight bounded outpost sites.")
    var heartforge_detail := world.release_world_art.dressing_root.find_child("HighDefinitionHeartforgeDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(heartforge_detail != null and heartforge_detail.find_child("HeartforgeBarrier00", true, false) != null and heartforge_detail.find_child("HeartforgeBarrierService00", true, false) != null, "The opening Heartforge perimeter must retain its authored barrier and service-detail dressing.")
    var threshold_package := heartforge_detail.get_node_or_null("AuthoredHeartforgeThreshold") as Node3D if heartforge_detail != null else null
    _expect(threshold_package != null, "The refuge boundary must instantiate its authored threshold package as a direct Heartforge-dressing child.")
    _expect(heartforge_detail == null or heartforge_detail.find_children("AuthoredHeartforgeThreshold", "Node3D", true, false).size() == 1, "The refuge boundary must contain exactly one authored threshold package.")
    _expect(threshold_package != null and StringName(str(threshold_package.get_meta(&"ironwright_asset_id", &""))) == &"heartforge.threshold.v1", "The authored threshold must expose its stable package identifier.")
    _expect(threshold_package != null and StringName(str(threshold_package.get_meta(&"threshold_visual_source", &""))) == &"authored", "A healthy threshold import must report the authored package as its active visual source.")
    _expect(threshold_package != null and threshold_package.position.is_equal_approx(Vector3(0.0, 0.0, -5.8)) and threshold_package.rotation.is_equal_approx(Vector3.ZERO) and threshold_package.scale.is_equal_approx(Vector3.ONE), "The authored threshold must retain the established refuge-boundary transform.")
    for detail_name in [
        "ThresholdStructure",
        "ThresholdPillarL",
        "ThresholdFootL",
        "ThresholdPillarR",
        "ThresholdFootR",
        "ThresholdLintel",
        "ThresholdCrown",
        "RouteThresholdAmberBand",
        "ThresholdServiceLayer",
        "ThresholdServicePanel",
        "LeftServicePanel",
        "RightServicePanel",
        "ThresholdSignalLayer",
        "ThresholdLamp00",
        "ThresholdLamp01",
        "ThresholdLamp02",
        "LeftRouteSensor",
        "RightRouteSensor",
        "ThresholdRouteMarker",
        "ThresholdOrganicMachineLayer",
        "ProductionAssetMarker",
    ]:
        _expect(threshold_package != null and threshold_package.find_child(detail_name, true, false) != null, "The authored threshold package must retain stable detail node %s." % detail_name)
    for removed_legacy_name in ["HeartforgeThresholdGate", "HeartforgeThresholdFallback", "AmberRouteThresholdArch", "RouteThresholdPost", "RouteThresholdHeader", "GatePost", "GateSensor"]:
        _expect(world.find_children(removed_legacy_name, "", true, false).is_empty(), "A healthy authored refuge boundary must not retain legacy threshold node %s." % removed_legacy_name)
    _expect(threshold_package == null or threshold_package.find_children("*", "CollisionObject3D", true, false).is_empty(), "The authored threshold must remain presentation-only and introduce no collision object.")
    _expect(threshold_package == null or threshold_package.find_children("*", "CollisionShape3D", true, false).is_empty(), "The authored threshold must not add a route blocker through collision geometry.")
    _expect(world.find_child("ForgeServiceLane", true, false) != null and world.find_child("AmberRouteChevron", true, false) != null and world.find_child("AmberRouteGuideBeacon", true, false) != null and world.find_child("AmberRouteGuideLamp", true, false) != null, "Threshold consolidation must preserve the service lane and its ground-level amber route cues.")
    var threshold_route_guide := world.find_child("AmberRouteGuideBeacon", true, false) as Node3D
    _expect(threshold_package == null or threshold_route_guide == null or threshold_route_guide.global_position.z < threshold_package.global_position.z - 1.4, "The retained route beacons must sit beyond the authored threshold footprint rather than intersecting its structure.")
    _expect(world.find_child("ForegroundRefugeThreshold", true, false) != null and world.find_child("ThresholdSlab", true, false) != null and world.find_child("ImprovisedSanctuaryPerimeter", true, false) != null and world.find_child("WeldedBarricade", true, false) != null, "Threshold consolidation must preserve the lived-in foreground refuge and non-threshold perimeter dressing.")
    var threshold_meshes: Array[MeshInstance3D] = []
    _collect_mesh_instances(threshold_package, threshold_meshes)
    _expect(threshold_meshes.size() >= 12, "The authored threshold must expose a substantial UV/PBR mesh package rather than a token marker.")
    var threshold_material_ids: Dictionary = {}
    for threshold_mesh in threshold_meshes:
        _expect(threshold_mesh.material_override == null, "The authored threshold must preserve imported surface materials without a global override.")
        _expect(StringName(str(threshold_mesh.get_meta(&"release_material_family", &""))) == &"authored_threshold_pbr", "Every authored threshold mesh must use the dedicated imported-PBR release family.")
        _expect(_mesh_retains_imported_heartforge_pbr(threshold_mesh), "Every authored threshold surface must retain base-color, normal and packed ORM texture wiring.")
        threshold_material_ids[threshold_mesh.get_instance_id()] = _active_surface_material_ids(threshold_mesh)
    var threshold_band := _find_mesh_named(threshold_package, "RouteThresholdAmberBand")
    _expect(_mesh_retains_imported_heartforge_emission(threshold_band), "The authored threshold lintel must retain its textured amber route signal.")
    world.release_world_art.apply_to_node(threshold_package)
    _expect(heartforge_detail == null or heartforge_detail.find_children("AuthoredHeartforgeThreshold", "Node3D", true, false).size() == 1, "A repeated release material pass must not duplicate the authored threshold package.")
    for threshold_mesh in threshold_meshes:
        _expect(threshold_mesh.material_override == null and StringName(str(threshold_mesh.get_meta(&"release_material_family", &""))) == &"authored_threshold_pbr", "A repeated release pass must preserve the authored threshold PBR contract.")
        _expect(_active_surface_material_ids(threshold_mesh) == threshold_material_ids.get(threshold_mesh.get_instance_id(), []), "A repeated release pass must preserve authored threshold material identity.")
    var heartforge_release := world.release_world_art.dressing_root.find_child("HeartforgeReleaseDressing", true, false) if world.release_world_art.dressing_root != null else null
    var string_light := heartforge_release.find_child("SanctuaryStringLight", true, false) as MeshInstance3D if heartforge_release != null else null
    var string_light_material := string_light.get_active_material(0) as StandardMaterial3D if string_light != null and string_light.mesh != null and string_light.mesh.get_surface_count() > 0 else null
    _expect(string_light_material != null and string_light_material.emission_energy_multiplier <= 0.9, "Release sanctuary string lights must retain a restrained amber emission budget.")
    var industrial_detail := world.release_world_art.dressing_root.find_child("HighDefinitionIndustrialDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(industrial_detail != null, "The West Grid secondary industrial layer must be present.")
    _expect(industrial_detail != null and industrial_detail.find_child("SubstationTank00", true, false) != null, "The West Grid secondary industrial layer must retain its authored substation tanks.")
    _expect(industrial_detail != null and industrial_detail.find_child("TankServiceLouver", true, false) != null, "The West Grid substation tanks must retain their authored service louvers.")
    _expect(industrial_detail != null and industrial_detail.find_child("GridPipeFlange00", true, false) != null, "The West Grid pipe run must retain authored flange hardware.")
    _expect(industrial_detail != null and industrial_detail.find_child("GridSwitchyardFocal", true, false) != null and industrial_detail.find_child("GridTransformerBody", true, false) != null and industrial_detail.find_child("GridSwitchyardBusRail", true, false) != null and industrial_detail.find_child("GridSwitchyardBushing01", true, false) != null and industrial_detail.find_child("GridTransformerWarningPanel", true, false) != null, "The West Grid industrial layer must retain its bounded transformer switchyard focal assembly.")
    var greenhouse_detail := world.release_world_art.dressing_root.find_child("HighDefinitionGreenhouseDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(greenhouse_detail != null and greenhouse_detail.find_child("GlasshouseFrame00", true, false) != null and greenhouse_detail.find_child("ClimateVent", true, false) != null and greenhouse_detail.find_child("GlasshouseOvergrowth00", true, false) != null, "The Municipal Glasshouse secondary layer must retain authored frame, climate and overgrowth detail.")
    var greenhouse_growth_material: StandardMaterial3D
    var greenhouse_growth_node := greenhouse_detail.find_child("MyceliumGlow00", true, false) if greenhouse_detail != null else null
    if greenhouse_growth_node is MeshInstance3D:
        greenhouse_growth_material = (greenhouse_growth_node as MeshInstance3D).material_override as StandardMaterial3D
    var greenhouse_pane_material: StandardMaterial3D
    var greenhouse_pane_node := greenhouse_detail.find_child("GlasshouseFacadePane00Core", true, false) if greenhouse_detail != null else null
    if greenhouse_pane_node is MeshInstance3D:
        greenhouse_pane_material = (greenhouse_pane_node as MeshInstance3D).material_override as StandardMaterial3D
    var greenhouse_service_signal: StandardMaterial3D
    var greenhouse_service_signal_node := greenhouse_detail.find_child("GlasshouseTankSignal", true, false) if greenhouse_detail != null else null
    if greenhouse_service_signal_node is MeshInstance3D:
        greenhouse_service_signal = (greenhouse_service_signal_node as MeshInstance3D).material_override as StandardMaterial3D
    _expect(greenhouse_growth_material != null and greenhouse_growth_material.emission_energy_multiplier <= 0.9, "Municipal Glasshouse growth lights must retain a restrained green emission budget.")
    _expect(greenhouse_pane_material != null and greenhouse_pane_material.emission_energy_multiplier <= 0.15, "Municipal Glasshouse cold glass must retain a restrained cyan emission budget.")
    _expect(greenhouse_service_signal != null and greenhouse_service_signal.emission_energy_multiplier <= 0.8, "Municipal Glasshouse service signals must retain a restrained cyan emission budget.")
    var greenhouse_service := greenhouse_detail.find_child("HighDefinitionGreenhouseServiceLayer", true, false) if greenhouse_detail != null else null
    _expect(greenhouse_service != null and greenhouse_service.find_child("GlasshouseServiceWalkway", true, false) != null and greenhouse_service.find_child("GlasshouseClimateConsole", true, false) != null and greenhouse_service.find_child("GlasshouseIrrigationHeader", true, false) != null, "The Municipal Glasshouse must retain its bounded service walkway, climate console and irrigation header.")
    var riverworks := world.region_director.get_landmark(&"region.riverworks")
    _expect(riverworks != null and riverworks.find_child("RiverworksRotor", true, false) != null, "Commercial release must retain the authored Riverworks pump landmark.")
    var waterworks_detail := world.release_world_art.dressing_root.find_child("HighDefinitionWaterworksDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(waterworks_detail != null and waterworks_detail.find_child("WaterworksPumpStationFocal", true, false) != null and waterworks_detail.find_child("WaterworksStationBody", true, false) != null and waterworks_detail.find_child("WaterworksStationControlPanel", true, false) != null and waterworks_detail.find_child("WaterworksStationHeader", true, false) != null, "The Riverworks industrial layer must retain its bounded pump-station focal assembly.")
    var market_detail := world.release_world_art.dressing_root.find_child("HighDefinitionMarketDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(market_detail != null and market_detail.find_child("MarketExchangeFocal", true, false) != null and market_detail.find_child("MarketExchangeCounter", true, false) != null and market_detail.find_child("MarketExchangeSign", true, false) != null and market_detail.find_child("MarketExchangeFloodline", true, false) != null, "The Flood Market presentation layer must retain its bounded exchange focal assembly.")
    var cathedral := world.region_director.get_landmark(&"region.cathedral_quarter")
    _expect(cathedral != null and cathedral.find_child("CathedralChoirCore", true, false) != null, "Commercial release must retain the authored Cathedral Quarter landmark.")
    var cathedral_brood_sac := world.release_world_art.dressing_root.find_child("BroodSac00Shell", true, false) if world.release_world_art.dressing_root != null else null
    var cathedral_brood_ridge := world.release_world_art.dressing_root.find_child("BroodSac00Ridge", true, false) if world.release_world_art.dressing_root != null else null
    _expect(cathedral_brood_sac != null and cathedral_brood_ridge != null, "Cathedral Quarter release dressing must retain layered brood-sac anatomy instead of a ring of flat proxy spheres.")
    var observatory := world.region_director.get_landmark(&"region.observatory_ridge")
    _expect(observatory != null and observatory.find_child("ObservatoryDish", true, false) != null, "Commercial release must retain the authored Observatory Ridge landmark.")
    var tram_graveyard := world.region_director.get_landmark(&"region.tram_graveyard")
    _expect(tram_graveyard != null and tram_graveyard.find_child("TramCarriageADoor", true, false) != null, "Commercial release must retain the authored Tram Graveyard landmark.")
    var buried_labs := world.region_director.get_landmark(&"region.buried_labs")
    _expect(buried_labs != null and buried_labs.find_child("BuriedLabsVesselCore0", true, false) != null, "Commercial release must retain the authored Buried Laboratories landmark.")
    var glasshouse := world.region_director.get_landmark(&"region.glasshouse")
    _expect(glasshouse != null and glasshouse.find_child("GlasshouseClimateLouver", true, false) != null, "Commercial release must retain the authored Municipal Glasshouse landmark.")
    var archive := world.region_director.get_landmark(&"region.north_ruins")
    _expect(archive != null and archive.find_child("ArchiveVaultDoor", true, false) != null, "Commercial release must retain the authored North Ruins landmark.")
    var tenement := world.region_director.get_landmark(&"region.east_tenements")
    _expect(tenement != null and tenement.find_child("TenementFireEscapeLadder", true, false) != null, "Commercial release must retain the authored East Tenements landmark.")
    var flood_market := world.region_director.get_landmark(&"region.flood_market")
    _expect(flood_market != null and flood_market.find_child("FloodMarketCanopy0", true, false) != null, "Commercial release must retain the authored Flood Market landmark.")
    var west_grid := world.region_director.get_landmark(&"region.west_grid")
    _expect(west_grid != null and west_grid.find_child("WestGridTurbineHall", true, false) != null and west_grid.find_child("WestGridRerouteWitness", true, false) != null and west_grid.find_child("WestGridRerouteRouteMap", true, false) != null, "Commercial release must retain the authored West Grid landmark and its physical reroute witness.")
    _expect(world.balance_director.profile_ids().size() == 3, "Story, Survival and Brutal profiles must be present.")
    _expect(world.balance_director.set_profile(&"story"), "Story profile must be selectable.")
    _expect(world.balance_director.active_enemy_cap() < 96, "Story profile must lower the active enemy cap.")
    _expect(world.balance_director.set_profile(&"brutal"), "Brutal profile must be selectable.")
    _expect(world.balance_director.regional_pressure_multiplier() > 1.0, "Brutal profile must increase regional pressure.")
    world.balance_director.set_profile(&"survival")


func _test_runtime_material_continuity(world: IronwrightReleaseWorld3D) -> void:
    var textured_before := world.release_world_art.meshes_textured
    var heartforge := world.heartforge as Heartforge3D
    var heartforge_model := heartforge.get_node_or_null("HeartforgeModel") as Node3D if heartforge != null else null
    var authored_heartforge := heartforge_model.get_node_or_null("HeartforgeAuthoredModel") as Node3D if heartforge_model != null else null
    _expect(heartforge_model != null and StringName(str(heartforge_model.get_meta(&"heartforge_visual_source", &""))) == &"authored", "The release Heartforge must report its authored package as the active visual source.")
    _expect(authored_heartforge != null and StringName(str(authored_heartforge.get_meta(&"ironwright_asset_id", &""))) == &"heartforge.core.v1", "The release Heartforge must expose the exact authored package marker.")
    _expect(heartforge_model != null and heartforge_model.find_child("LegacyProceduralHeartforgeShell", true, false) == null, "The release Heartforge must not carry a hidden procedural shell beside its authored package.")
    var heartforge_authored_meshes: Array[MeshInstance3D] = []
    _collect_mesh_instances(authored_heartforge, heartforge_authored_meshes)
    _expect(not heartforge_authored_meshes.is_empty(), "The release Heartforge must expose its imported authored mesh package.")
    var heartforge_material_ids: Dictionary = {}
    for authored_mesh in heartforge_authored_meshes:
        _expect(StringName(str(authored_mesh.get_meta(&"release_material_family", &""))) == &"authored_heartforge_pbr", "Every authored Heartforge mesh must use the dedicated imported-PBR release family.")
        _expect(authored_mesh.material_override == null, "Release texturing must not flatten an authored Heartforge mesh with a generic material override.")
        _expect(_mesh_retains_imported_heartforge_pbr(authored_mesh), "Every authored Heartforge surface must retain imported base-color, normal and ORM texture channels.")
        heartforge_material_ids[authored_mesh.get_instance_id()] = _active_surface_material_ids(authored_mesh)
    var heartforge_thermal_mesh := _find_mesh_named(authored_heartforge, "FurnaceCore")
    var heartforge_cyan_mesh := _find_mesh_named(authored_heartforge, "CoreServiceLouver00")
    _expect(_mesh_retains_imported_heartforge_emission(heartforge_thermal_mesh), "The authored Heartforge thermal core must retain its imported emissive texture.")
    _expect(_mesh_retains_imported_heartforge_emission(heartforge_cyan_mesh), "The authored Heartforge cyan service louver must retain its imported emissive texture.")
    world.release_world_art.apply_to_node(authored_heartforge)
    for authored_mesh in heartforge_authored_meshes:
        var expected_material_ids: Array = heartforge_material_ids.get(authored_mesh.get_instance_id(), [])
        _expect(_active_surface_material_ids(authored_mesh) == expected_material_ids, "A repeated release texture pass must not replace an imported Heartforge surface material.")
        _expect(authored_mesh.material_override == null and StringName(str(authored_mesh.get_meta(&"release_material_family", &""))) == &"authored_heartforge_pbr", "A repeated release pass must preserve the authored Heartforge PBR contract.")
    var original_heartforge_tier := heartforge.progression_tier if heartforge != null else 1
    if heartforge != null:
        heartforge.set_progression_tier(maxi(3, original_heartforge_tier))
        world.release_world_art.apply_to_node(heartforge)
    var heartforge_progression_root := heartforge_model.get_node_or_null("AdaptiveHeartforgeGeometry") as Node3D if heartforge_model != null else null
    var heartforge_progression_meshes: Array[MeshInstance3D] = []
    _collect_mesh_instances(heartforge_progression_root, heartforge_progression_meshes)
    _expect(not heartforge_progression_meshes.is_empty(), "The release Heartforge must retain visible runtime-owned progression geometry.")
    for progression_mesh in heartforge_progression_meshes:
        _expect(StringName(str(progression_mesh.get_meta(&"release_material_family", &""))) != &"authored_heartforge_pbr", "Runtime Heartforge progression geometry must never inherit the authored-package material family.")
        _expect(progression_mesh.material_override != null, "Runtime Heartforge progression geometry must retain its procedural material treatment.")
    if heartforge != null:
        heartforge.set_progression_tier(original_heartforge_tier)
    var opening_robot := get_first_node_in_group(&"friendly_robots") as Node
    var opening_bulwark := opening_robot.get_node_or_null("RobotModel/BulwarkAuthoredModel") if opening_robot != null else null
    var opening_authored_meshes: Array[MeshInstance3D] = []
    _collect_mesh_instances(opening_bulwark, opening_authored_meshes)
    _expect(not opening_authored_meshes.is_empty(), "The release Bulwark must expose its imported authored mesh package.")
    for authored_mesh in opening_authored_meshes:
        _expect(authored_mesh.get_meta(&"release_material_family", &"") == &"authored_bulwark_pbr", "Every authored Bulwark mesh must use the dedicated imported-PBR release family.")
        _expect(authored_mesh.material_override == null, "Release texturing must not flatten an authored Bulwark mesh with a generic material override.")
        _expect(_mesh_retains_imported_bulwark_pbr(authored_mesh), "Every authored Bulwark mesh must retain imported base-color, normal and ORM texture channels.")
    var opening_emitter_lens := _find_mesh_named(opening_bulwark, "BulwarkEmitterLensInset")
    _expect(_mesh_retains_imported_bulwark_emission(opening_emitter_lens), "The authored Bulwark emitter must retain its imported emissive-mask channel.")
    _expect(opening_bulwark != null and opening_bulwark.find_child("BulwarkEmitterGuardL", true, false) != null and opening_bulwark.find_child("BulwarkEmitterGuardR", true, false) != null, "The Bulwark protection emitter must retain its authored paired guard rails.")
    _expect(opening_bulwark != null and opening_bulwark.find_child("BulwarkEmitterCollar", true, false) != null and opening_bulwark.find_child("BulwarkEmitterAperture", true, false) != null and opening_bulwark.find_child("BulwarkEmitterLensInset", true, false) != null, "The Bulwark protection emitter must retain its nested authored projector assembly.")
    _expect(opening_bulwark != null and opening_bulwark.find_child("BulwarkServiceFace", true, false) != null and opening_bulwark.find_child("BulwarkServiceWindow", true, false) != null, "The Bulwark companion must expose an authored front service face and diagnostic window.")
    var player_model := world.player.get_node_or_null("MechromancerModel") if world.player != null else null
    var authored_mechromancer := _find_asset_package(player_model, &"mechromancer.player.v1")
    _expect(authored_mechromancer != null, "The release player must expose the exact authored Mechromancer package identity.")
    _expect(_asset_package_count(player_model, &"mechromancer.player.v1") == 1, "The release player must contain exactly one authored Mechromancer package.")
    _expect(player_model == null or player_model.get_node_or_null("VerticalSliceCharacterArt") == null, "The release actor-art pass must not duplicate the authored Mechromancer with a legacy static overlay.")
    var player_readability_light := world.player.find_child("MechromancerReadabilityLight", true, false) as OmniLight3D if world.player != null else null
    _expect(player_readability_light != null and player_readability_light.get_parent() != null and player_readability_light.get_parent().name == &"ShoulderLamp" and player_readability_light.light_energy <= 0.25, "Static-overlay consolidation must retain one restrained readability light on the authored shoulder socket.")
    var player_authored_meshes: Array[MeshInstance3D] = []
    _collect_mesh_instances(authored_mechromancer, player_authored_meshes)
    _expect(not player_authored_meshes.is_empty(), "The release Mechromancer must expose its imported authored mesh package.")
    var player_material_ids: Dictionary = {}
    for authored_mesh in player_authored_meshes:
        _expect(StringName(str(authored_mesh.get_meta(&"release_material_family", &""))) == &"authored_mechromancer_pbr", "Every authored Mechromancer mesh must use the dedicated imported-PBR release family.")
        _expect(authored_mesh.material_override == null, "Release texturing must not flatten an authored Mechromancer mesh with a generic material override.")
        _expect(_mesh_retains_imported_mechromancer_pbr(authored_mesh), "Every authored Mechromancer surface must retain imported base-color, normal and packed ORM texture channels.")
        player_material_ids[authored_mesh.get_instance_id()] = _active_surface_material_ids(authored_mesh)
    _expect(player_model != null and player_model.find_child("ChestShell", true, false) != null and player_model.find_child("ChestArmorPlate", true, false) != null, "The Mechromancer must expose the layered curved chest shell and breastplate in the live authored model.")
    var player_leather := _find_mesh_named(player_model, "FieldPack")
    var player_coat := _find_mesh_named(player_model, "Torso")
    var player_lamp := _find_mesh_named(player_model, "LampCore")
    _expect(player_leather != null and player_coat != null and player_lamp != null, "The authored Mechromancer material-break samples must remain present.")
    _expect(player_leather != null and player_leather.material_override == null and player_coat != null and player_coat.material_override == null and player_lamp != null and player_lamp.material_override == null, "The Mechromancer leather, coat and cognition-light samples must retain their imported material assignments.")
    _expect(_mesh_retains_imported_heartforge_emission(player_lamp), "The authored Mechromancer work lamp must retain its imported emissive-mask channel.")
    world.release_world_art.apply_to_node(player_model)
    for authored_mesh in player_authored_meshes:
        var expected_player_material_ids: Array = player_material_ids.get(authored_mesh.get_instance_id(), [])
        _expect(_active_surface_material_ids(authored_mesh) == expected_player_material_ids, "A repeated release texture pass must not replace an imported Mechromancer surface material.")
        _expect(authored_mesh.material_override == null and StringName(str(authored_mesh.get_meta(&"release_material_family", &""))) == &"authored_mechromancer_pbr", "A repeated release pass must preserve the authored Mechromancer PBR contract.")
    world.player.apply_progression_visuals({
        &"unlock_machine_society": true,
        &"unlock_adaptive_defence": true,
        &"unlock_final_protocol_research": true,
        &"machine_signal_lattice": true,
    }, 5)
    world.release_world_art.apply_to_node(world.player)
    var player_progression_root := world.player.get_node_or_null("MechromancerProgressionVisuals") as Node3D
    var player_progression_meshes: Array[MeshInstance3D] = []
    _collect_mesh_instances(player_progression_root, player_progression_meshes)
    _expect(player_progression_root != null and player_progression_root.get_parent() == world.player and not player_progression_meshes.is_empty(), "The authored-package handoff must retain the actor-owned Mechromancer progression layer.")
    for progression_mesh in player_progression_meshes:
        _expect(StringName(str(progression_mesh.get_meta(&"release_material_family", &""))) != &"authored_mechromancer_pbr" and progression_mesh.material_override != null, "Runtime Mechromancer progression hardware must keep its procedural material treatment outside the authored package family.")
    var player_death_root := world.player.get_node_or_null("MechromancerDeathPresentation") as Node3D
    var player_death_meshes: Array[MeshInstance3D] = []
    _collect_mesh_instances(player_death_root, player_death_meshes)
    _expect(player_death_root != null and player_death_root.get_parent() == world.player and not player_death_meshes.is_empty(), "The authored-package handoff must retain the bounded actor-owned Mechromancer death layer.")
    for death_mesh in player_death_meshes:
        _expect(StringName(str(death_mesh.get_meta(&"release_material_family", &""))) != &"authored_mechromancer_pbr" and death_mesh.material_override != null, "Runtime Mechromancer death geometry must keep its procedural failure material treatment outside the authored package family.")
    _expect(world.player.find_child("FieldHoodRim", true, false) != null and world.player.find_child("FieldVisorHousing", true, false) != null, "The release Mechromancer must retain the close-range hood and visor field-finish hardware.")
    _expect(world.player.find_child("HoodLowerSeam", true, false) != null and world.player.find_child("VisorBrow", true, false) != null and world.player.find_child("VisorMountLeft", true, false) != null and world.player.find_child("VisorMountRight", true, false) != null, "The release Mechromancer must retain the authored protective hood seam and fastened visor brow finish.")
    _expect(world.player.find_child("FieldWorkGloveLeft", true, false) != null and world.player.find_child("FieldWorkGloveRight", true, false) != null and world.player.find_child("FieldCoatHemLeft", true, false) != null and world.player.find_child("FieldCoatHemRight", true, false) != null, "The release Mechromancer must retain paired gloves and coat-hem field-finish hardware.")
    _expect(world.player.find_child("FieldPackBackplate", true, false) != null and world.player.find_child("FieldPackTopRoll", true, false) != null and world.player.find_child("FieldPackServiceCable", true, false) != null, "The release Mechromancer must retain the framed pack and service cable hero surface pass.")
    _expect(opening_robot != null and opening_robot.find_child("BulwarkActuatorRingLeft", true, false) != null and opening_robot.find_child("BulwarkActuatorRingRight", true, false) != null and opening_robot.find_child("BulwarkSideHeatPanelLeft", true, false) != null and opening_robot.find_child("BulwarkServiceWindowFrame", true, false) != null, "The release Bulwark must retain paired actuator, heat-panel and diagnostic-window depth.")
    var progressed_bulwark := world._spawn_robot(&"companion", world.player.global_position + Vector3(7.0, 0.0, -3.0), 3)
    if progressed_bulwark != null:
        progressed_bulwark.call(&"ensure_authored_visuals")
        world.release_world_art.apply_to_node(progressed_bulwark)
    var progressed_model := progressed_bulwark.get_node_or_null("RobotModel") if progressed_bulwark != null else null
    var progression_meshes: Array[MeshInstance3D] = []
    if progressed_model != null:
        for progressed_child in progressed_model.get_children():
            if progressed_child.name == &"BulwarkAuthoredModel" or String(progressed_child.name).begins_with("Hero") or progressed_child is Light3D:
                continue
            _collect_mesh_instances(progressed_child as Node, progression_meshes)
    _expect(not progression_meshes.is_empty(), "A level-three Bulwark must retain visible procedural progression hardware.")
    var untextured_progression_meshes: Array[String] = []
    for progression_mesh in progression_meshes:
        var progression_family := StringName(str(progression_mesh.get_meta(&"release_material_family", &"")))
        if progression_family != &"metal" or progression_mesh.material_override == null:
            untextured_progression_meshes.append("%s:%s" % [progression_mesh.name, progression_family])
    _expect(untextured_progression_meshes.is_empty(), "Every procedural Bulwark progression mesh must retain the generic release metal treatment; invalid surfaces: %s." % ", ".join(untextured_progression_meshes))
    var progressed_authored_mesh := _find_first_mesh(progressed_bulwark.get_node_or_null("RobotModel/BulwarkAuthoredModel") if progressed_bulwark != null else null)
    _expect(progressed_authored_mesh != null and progressed_authored_mesh.get_meta(&"release_material_family", &"") == &"authored_bulwark_pbr" and progressed_authored_mesh.material_override == null, "Progression must not leak generic metal overrides back into the authored Bulwark package.")
    var relay := world._spawn_robot(&"relay", world.player.global_position + Vector3(5.0, 0.0, -2.0), 1)
    if relay != null:
        relay.call(&"ensure_authored_visuals")
    await process_frame
    var relay_authored_mesh := _find_first_mesh(relay.get_node_or_null("RobotModel/RelayAuthoredModel") if relay != null else null)
    _expect(relay_authored_mesh != null and relay_authored_mesh.get_meta(&"release_material_family", &"") == &"metal", "The authored Signal Relay shell must receive the release metal material pass.")
    var opening_damage_root := opening_robot.get_node_or_null("RobotDamagePresentation") as Node3D if opening_robot != null else null
    _expect(opening_damage_root != null, "Authored machine actors must carry a bounded persistent damage presentation root.")
    if opening_robot != null and opening_damage_root != null:
        opening_robot.call("apply_damage", float(opening_robot.get("maximum_health")) * 0.34)
        _expect(opening_damage_root.visible, "Nearby damaged machines must expose persistent scar and leak presentation.")
        opening_robot.call("set_damage_presentation_enabled", false)
        _expect(not opening_damage_root.visible, "Reduced-detail machine presentation must hide persistent damage overlays.")
        opening_robot.call("set_damage_presentation_enabled", true)
        _expect(opening_damage_root.visible, "Restored close machine presentation must show persistent damage overlays again.")
        opening_robot.call("repair", float(opening_robot.get("maximum_health")))
        _expect(not opening_damage_root.visible, "Fully repaired machines must clear persistent damage presentation.")
    var late_robot := world._spawn_robot(&"salvager", world.player.global_position + Vector3(3.0, 0.0, -3.0), 1)
    var organic_fixture_species: Array[StringName] = [
        &"skitterling", &"razorhound", &"roofleaper", &"glassmoth", &"veilstalker", &"burrower", &"sporecaster",
        &"broodmass", &"miremaw", &"carrionbell", &"rootweaver", &"thornback", &"ashmantle", &"apex",
    ]
    var organic_fixture_asset_ids: Array[StringName] = [
        &"skitterling.scavenger.v1", &"razorhound.predator.v1", &"roofleaper.ambusher.v1", &"glassmoth.swarm.v1",
        &"veilstalker.predator.v1", &"burrower.drill.v1", &"sporecaster.infestation.v1", &"broodmass.nest.v1",
        &"miremaw.amphibious.v1", &"carrionbell.signal.v1", &"rootweaver.route_controller.v1",
        &"thornback.territorial.v1", &"ashmantle.route_predator.v1", &"apex.cistern.v1",
    ]
    var source_owned_focal_names := {
        &"roofleaper": &"RoofleaperCentralOculus",
        &"glassmoth": &"GlassmothLensCollar",
        &"miremaw": &"MiremawMawGuard",
        &"carrionbell": &"CarrionbellThroatCollar",
        &"rootweaver": &"RootweaverRouteMask",
        &"thornback": &"ThornbackFaceShield",
        &"ashmantle": &"AshmantleThermalCollar",
    }
    var organic_fixtures: Array[OrganicEnemyRelease3D] = []
    for index in range(organic_fixture_species.size()):
        var column := index % 7
        var row := index / 7
        var fixture_position := world.player.global_position + Vector3(-12.0 + float(column) * 4.0, 0.0, -11.0 - float(row) * 5.0)
        organic_fixtures.append(world._spawn_enemy(fixture_position, organic_fixture_species[index]) as OrganicEnemyRelease3D)

    # The production director may defer shells outside its nearest-subject
    # budget. This fixture explicitly audits all 14 packages, so materialize
    # only these test actors before checking imported material ownership.
    for index in range(organic_fixtures.size()):
        var fixture_actor := organic_fixtures[index]
        if fixture_actor == null:
            continue
        fixture_actor.ensure_authored_visuals()
        if organic_fixture_species[index] == &"glassmoth":
            # Exercise the production gallery's real non-unit model scale. The
            # three runtime siblings must still inherit the authored Torso's
            # complete transform rather than falling back to actor-root scale.
            var glassmoth_model := fixture_actor.get_node_or_null("OrganicModel") as Node3D
            if glassmoth_model != null:
                glassmoth_model.scale = Vector3.ONE * 1.1
    if late_robot != null:
        late_robot.call(&"ensure_authored_visuals")
    await process_frame
    await process_frame

    for index in range(organic_fixtures.size()):
        var fixture_actor := organic_fixtures[index]
        var species_id := organic_fixture_species[index]
        var asset_id := organic_fixture_asset_ids[index]
        _expect(fixture_actor != null, "The authored organic runtime fixture must spawn %s." % species_id)
        if fixture_actor == null:
            continue
        var organic_model := fixture_actor.get_node_or_null("OrganicModel") as Node3D
        var authored_package := _find_asset_package(organic_model, asset_id)
        _expect(authored_package != null, "The %s runtime actor must expose exact imported package %s." % [species_id, asset_id])
        _expect(_asset_package_count(organic_model, asset_id) == 1, "The %s runtime actor must contain exactly one authoritative organic package." % species_id)
        var authored_meshes: Array[MeshInstance3D] = []
        _collect_mesh_instances(authored_package, authored_meshes)
        _expect(not authored_meshes.is_empty(), "The %s imported package must expose authored mesh surfaces." % species_id)
        var material_ids: Dictionary = {}
        for authored_mesh in authored_meshes:
            material_ids[authored_mesh.get_instance_id()] = _active_surface_material_ids(authored_mesh)

        var overlay_specs := [
            {"root": &"TierSilhouette", "anchor": &"OrganicTierAttachment", "profile": "compact_authored_focal_signal"},
            {"root": &"OrganicDamagePresentation", "anchor": &"OrganicDamageAttachment", "profile": "authored_torso_surface_wounds"},
            {"root": &"OrganicDeathPresentation", "anchor": &"OrganicDeathAttachment", "profile": "authored_body_death_clip"},
        ]
        var authored_torso := authored_package.find_child("Torso", true, false) as Node3D if authored_package != null else null
        _expect(authored_torso != null, "The %s imported package must expose the authored Torso socket used by every runtime overlay." % species_id)
        var runtime_material_ids: Dictionary = {}
        var damage_signal_material := fixture_actor._damage_signal_material
        var death_signal_material := fixture_actor._death_signal_material
        for overlay_spec in overlay_specs:
            var overlay_name := StringName(str(overlay_spec.get("root", &"")))
            var anchor_name := StringName(str(overlay_spec.get("anchor", &"")))
            var overlay_matches := fixture_actor.find_children(String(overlay_name), "", true, false)
            var anchor_matches := fixture_actor.find_children(String(anchor_name), "RemoteTransform3D", true, false)
            _expect(overlay_matches.size() == 1, "The %s runtime must contain exactly one %s root." % [species_id, overlay_name])
            _expect(anchor_matches.size() == 1, "The %s runtime must contain exactly one meshless %s anchor." % [species_id, anchor_name])
            var overlay_root := overlay_matches[0] as Node3D if overlay_matches.size() == 1 else null
            var attachment := anchor_matches[0] as RemoteTransform3D if anchor_matches.size() == 1 else null
            _expect(overlay_root != null and str(overlay_root.get_meta(&"presentation_profile", "")) == str(overlay_spec.get("profile", "")), "The %s %s root must retain its bounded authored-body presentation profile." % [species_id, overlay_name])
            _expect(overlay_root != null and StringName(str(overlay_root.get_meta(&"release_material_family", &""))) == &"chitin", "The %s %s root must explicitly own the runtime chitin material boundary." % [species_id, overlay_name])
            _expect(overlay_root != null and str(overlay_root.get_meta(&"attachment_mode", "")) == "authored_torso_remote", "The %s %s root must report authored-Torso remote attachment." % [species_id, overlay_name])
            _expect(overlay_root != null and not _node_is_descendant_of(overlay_root, authored_package), "The %s %s mesh root must remain outside the imported PBR package." % [species_id, overlay_name])
            _expect(attachment != null and _node_is_descendant_of(attachment, authored_package), "The %s %s anchor must live inside the imported package while remaining meshless." % [species_id, anchor_name])
            _expect(attachment != null and attachment.get_parent() == authored_torso, "The %s %s anchor must be a direct child of the authored Torso socket." % [species_id, anchor_name])
            _expect(attachment != null and attachment.update_position and attachment.update_rotation and attachment.update_scale and attachment.use_global_coordinates, "The %s %s anchor must copy the complete global transform." % [species_id, anchor_name])
            _expect(attachment != null and overlay_root != null and attachment.get_node_or_null(attachment.remote_path) == overlay_root, "The %s %s anchor must target the corresponding runtime sibling." % [species_id, anchor_name])
            _expect(attachment != null and overlay_root != null and attachment.global_transform.is_equal_approx(overlay_root.global_transform), "The %s %s root must coincide with its animated authored-Torso anchor." % [species_id, overlay_name])
            var anchor_meshes: Array[MeshInstance3D] = []
            _collect_mesh_instances(attachment, anchor_meshes)
            _expect(anchor_meshes.is_empty(), "The %s %s anchor must never place runtime meshes inside authored-package ancestry." % [species_id, anchor_name])
            var overlay_meshes: Array[MeshInstance3D] = []
            _collect_mesh_instances(overlay_root, overlay_meshes)
            _expect(not overlay_meshes.is_empty(), "The %s %s root must retain a visible bounded runtime mesh set." % [species_id, overlay_name])
            for overlay_mesh in overlay_meshes:
                _expect(overlay_mesh.material_override != null, "The %s %s mesh %s must begin with an explicit runtime material object." % [species_id, overlay_name, overlay_mesh.name])
                if overlay_name in [&"OrganicDamagePresentation", &"OrganicDeathPresentation"]:
                    runtime_material_ids[overlay_mesh.get_instance_id()] = overlay_mesh.material_override.get_instance_id() if overlay_mesh.material_override != null else 0

        if species_id == &"glassmoth" and authored_torso != null:
            var glassmoth_torso_scale := authored_torso.global_transform.basis.get_scale().abs()
            _expect(not glassmoth_torso_scale.is_equal_approx(Vector3.ONE), "The Glassmoth release fixture must exercise the production gallery's non-unit model scale.")
            for overlay_spec in overlay_specs:
                var overlay_name := StringName(str(overlay_spec.get("root", &"")))
                var overlay_root := fixture_actor.find_child(String(overlay_name), true, false) as Node3D
                var overlay_scale := overlay_root.global_transform.basis.get_scale().abs() if overlay_root != null else Vector3.ZERO
                _expect(overlay_root != null and overlay_scale.is_equal_approx(glassmoth_torso_scale), "Glassmoth %s must inherit the authored Torso's non-unit gallery scale." % overlay_name)

        for removed_death_prefix in [
            "OrganicDeathCarapace", "OrganicDeathRootCollar", "OrganicDeathShard",
            "OrganicDeathVein", "OrganicDeathSpine", "SkitterlingDeathResponse",
        ]:
            _expect(fixture_actor.find_children("%s*" % removed_death_prefix, "", true, false).is_empty(), "The %s runtime must not rebuild removed generic corpse anatomy %s*." % [species_id, removed_death_prefix])

        # Three explicit release passes audit idempotence from the material
        # objects present on the live fixture, including hidden death feedback.
        for _release_pass in range(3):
            world.release_world_art.apply_to_node(fixture_actor)
        for authored_mesh in authored_meshes:
            var expected_ids: Array = material_ids.get(authored_mesh.get_instance_id(), [])
            _expect(StringName(str(authored_mesh.get_meta(&"release_material_family", &""))) == &"authored_organic_pbr", "Every %s imported mesh must use the authored organic PBR release family." % species_id)
            _expect(authored_mesh.material_override == null, "Release texturing must not flatten a %s imported mesh with a generic override." % species_id)
            _expect(_mesh_retains_imported_organic_pbr(authored_mesh), "Every %s imported surface must retain base-color, normal and packed ORM textures." % species_id)
            _expect(_active_surface_material_ids(authored_mesh) == expected_ids, "Three release passes must preserve %s imported material identity." % species_id)

        for overlay_spec in overlay_specs:
            var overlay_name := StringName(str(overlay_spec.get("root", &"")))
            var overlay_root := fixture_actor.find_child(String(overlay_name), true, false) as Node3D
            var overlay_meshes: Array[MeshInstance3D] = []
            _collect_mesh_instances(overlay_root, overlay_meshes)
            for overlay_mesh in overlay_meshes:
                var material_family := StringName(str(overlay_mesh.get_meta(&"release_material_family", &"")))
                _expect(material_family != &"" and material_family != &"authored_organic_pbr", "The %s %s mesh %s must stay runtime-classified outside authored organic PBR." % [species_id, overlay_name, overlay_mesh.name])
                _expect(overlay_mesh.material_override != null, "The %s %s mesh %s must retain its runtime material after three release passes." % [species_id, overlay_name, overlay_mesh.name])
                if overlay_name in [&"OrganicDamagePresentation", &"OrganicDeathPresentation"]:
                    var expected_material_id := int(runtime_material_ids.get(overlay_mesh.get_instance_id(), 0))
                    var actual_material_id := overlay_mesh.material_override.get_instance_id() if overlay_mesh.material_override != null else 0
                    _expect(expected_material_id != 0 and actual_material_id == expected_material_id, "Three release passes must preserve exact %s %s material object identity on %s." % [species_id, overlay_name, overlay_mesh.name])
        _expect(fixture_actor._damage_signal_material == damage_signal_material and _overlay_uses_material( fixture_actor.find_child("OrganicDamagePresentation", true, false), damage_signal_material), "The %s wound meshes must retain the actor's live damage material object through three release passes." % species_id)
        _expect(fixture_actor._death_signal_material == death_signal_material and _overlay_uses_material(fixture_actor.find_child("OrganicDeathPresentation", true, false), death_signal_material), "The %s death meshes must retain the actor's live death material object through three release passes." % species_id)

        _expect(fixture_actor.find_child("OrganicFamilyAnatomyFinish", true, false) == null, "The %s runtime actor must not duplicate source-owned anatomy with the former finish overlay." % species_id)
        var organic_damage := fixture_actor.get_node_or_null("OrganicDamagePresentation") as Node3D
        var wound_socket := organic_damage.get_node_or_null("OrganicDamageScar00") as Node3D if organic_damage != null else null
        _expect(wound_socket != null and str(wound_socket.get_meta(&"damage_profile", "")) == "shallow_authored_torso_lesion", "The %s runtime must retain shallow authored-Torso lesion sockets." % species_id)
        fixture_actor.set_damage_presentation_enabled(true)
        fixture_actor.apply_damage(float(fixture_actor.maximum_health) * 0.12)
        _expect(organic_damage != null and organic_damage.visible, "The real bounded Hit path must reveal the %s authored-surface wounds." % species_id)
        fixture_actor.current_health = fixture_actor.maximum_health
        fixture_actor._refresh_damage_presentation()
        if source_owned_focal_names.has(species_id):
            var focal_name := StringName(str(source_owned_focal_names[species_id]))
            _expect(authored_package != null and authored_package.find_child("OrganicPulseRim", true, false) != null and authored_package.find_child("OrganicGrowthPlate", true, false) != null, "The %s imported package must directly own its pulse and growth anatomy." % species_id)
            _expect(authored_package != null and authored_package.find_child(String(focal_name), true, false) != null, "The %s imported package must directly own focal anatomy %s." % [species_id, focal_name])
        if species_id == &"veilstalker":
            _expect(organic_model == null or organic_model.get_node_or_null("Torso") == null, "The Veilstalker runtime must not add a duplicate torso/core beside its imported package.")
            _expect(authored_package != null and authored_package.find_child("TorsoCore", true, false) != null, "The Veilstalker imported package must own its sole torso core.")

    var late_enemy := organic_fixtures[4]
    var organic_damage_root := late_enemy.get_node_or_null("OrganicDamagePresentation") as Node3D if late_enemy != null else null
    _expect(organic_damage_root != null, "Organic enemies must carry a bounded persistent damage presentation root.")
    if late_enemy != null and organic_damage_root != null:
        late_enemy.apply_damage(float(late_enemy.maximum_health) * 0.34)
        _expect(organic_damage_root.visible, "Nearby damaged organisms must expose persistent wound and leak presentation.")

    var veilstalker_package := _find_asset_package(late_enemy.get_node_or_null("OrganicModel") if late_enemy != null else null, &"veilstalker.predator.v1")
    var veilstalker_meshes: Array[MeshInstance3D] = []
    _collect_mesh_instances(veilstalker_package, veilstalker_meshes)
    var pre_lod_material_ids: Dictionary = {}
    for authored_mesh in veilstalker_meshes:
        pre_lod_material_ids[authored_mesh.get_instance_id()] = _active_surface_material_ids(authored_mesh)

    if late_enemy != null:
        late_enemy.set_visual_lod(1)
        world.release_world_art.apply_to_node(late_enemy)
    var reduced_proxy := late_enemy.find_child("ReducedDetailProxy", true, false) as MeshInstance3D if late_enemy != null else null
    _expect(organic_damage_root == null or not organic_damage_root.visible, "Reduced-detail organism presentation must hide persistent damage overlays.")
    _expect(reduced_proxy != null and reduced_proxy.visible, "Reduced-detail organisms must expose their bounded proxy.")
    _expect(reduced_proxy != null and StringName(str(reduced_proxy.get_meta(&"release_material_family", &""))) != &"authored_organic_pbr" and reduced_proxy.material_override != null, "The reduced-detail proxy must remain runtime-owned and outside the authored organic PBR family.")

    if late_enemy != null:
        late_enemy.set_visual_lod(0)
        world.release_world_art.apply_to_node(late_enemy)
    _expect(organic_damage_root == null or organic_damage_root.visible, "Restored close organism presentation must show persistent damage overlays again.")
    _expect(reduced_proxy == null or not reduced_proxy.visible, "Returning to active detail must hide the reduced proxy.")
    for authored_mesh in veilstalker_meshes:
        var expected_ids: Array = pre_lod_material_ids.get(authored_mesh.get_instance_id(), [])
        _expect(_active_surface_material_ids(authored_mesh) == expected_ids, "An active/proxy/active transition must preserve imported organic material identity.")
        _expect(authored_mesh.material_override == null and StringName(str(authored_mesh.get_meta(&"release_material_family", &""))) == &"authored_organic_pbr", "An active/proxy/active transition must restore the authored organic package without a generic override.")

    if late_enemy != null:
        world.release_world_art.apply_to_node(late_enemy)
        for overlay_name in ["OrganicDamagePresentation", "OrganicDeathPresentation", "TierSilhouette"]:
            var overlay_root := late_enemy.find_child(overlay_name, true, false) as Node3D
            _expect(overlay_root != null, "The runtime organism must retain its %s overlay." % overlay_name)
            var overlay_meshes: Array[MeshInstance3D] = []
            _collect_mesh_instances(overlay_root, overlay_meshes)
            _expect(not overlay_meshes.is_empty(), "The runtime %s overlay must retain visible meshes." % overlay_name)
            for overlay_mesh in overlay_meshes:
                _expect(StringName(str(overlay_mesh.get_meta(&"release_material_family", &""))) != &"authored_organic_pbr", "Runtime %s meshes must never inherit the imported organic material family." % overlay_name)
                _expect(overlay_mesh.material_override != null, "Runtime %s meshes must retain their procedural material treatment." % overlay_name)

    var robot_core := late_robot.get_node_or_null("RobotModel/Chassis/ChassisCore") as MeshInstance3D if late_robot != null else null
    _expect(robot_core != null and robot_core.get_meta(&"release_material_family", &"") == &"metal", "Late-fabricated robots must receive the release metal material pass.")
    _expect(world.release_world_art.meshes_textured > textured_before, "Runtime release art must texture meshes added after initial boot.")

    if late_robot != null:
        late_robot.queue_free()
    if progressed_bulwark != null:
        progressed_bulwark.queue_free()
    if relay != null:
        relay.queue_free()
    for fixture_actor in organic_fixtures:
        if fixture_actor != null:
            fixture_actor.queue_free()

func _find_first_mesh(node: Node) -> MeshInstance3D:
    if node == null or not is_instance_valid(node):
        return null
    if node is MeshInstance3D:
        return node as MeshInstance3D
    for child in node.get_children():
        var result := _find_first_mesh(child as Node)
        if result != null:
            return result
    return null


func _find_asset_package(node: Node, asset_id: StringName) -> Node3D:
    if node == null or not is_instance_valid(node):
        return null
    if node is Node3D and _node_asset_id(node) == asset_id:
        return node as Node3D
    for child in node.get_children():
        var found := _find_asset_package(child as Node, asset_id)
        if found != null:
            return found
    return null


func _asset_package_count(node: Node, asset_id: StringName) -> int:
    if node == null or not is_instance_valid(node):
        return 0
    var count := 1 if _node_asset_id(node) == asset_id else 0
    for child in node.get_children():
        count += _asset_package_count(child as Node, asset_id)
    return count


func _node_asset_id(node: Node) -> StringName:
    var direct_id := StringName(str(node.get_meta(&"ironwright_asset_id", &"")))
    if direct_id != &"":
        return direct_id
    for metadata_key in [&"extras.ironwright_asset_id", &"extras/ironwright_asset_id"]:
        var imported_id := StringName(str(node.get_meta(metadata_key, &"")))
        if imported_id != &"":
            return imported_id
    var extras := node.get_meta(&"extras", {}) as Dictionary
    return StringName(str(extras.get("ironwright_asset_id", "")))


func _collect_mesh_instances(node: Node, result: Array[MeshInstance3D]) -> void:
    if node == null or not is_instance_valid(node):
        return
    if node is MeshInstance3D:
        result.append(node as MeshInstance3D)
    for child in node.get_children():
        _collect_mesh_instances(child as Node, result)


func _node_is_descendant_of(node: Node, ancestor: Node) -> bool:
    if node == null or ancestor == null or not is_instance_valid(node) or not is_instance_valid(ancestor):
        return false
    var current := node
    while current != null:
        if current == ancestor:
            return true
        current = current.get_parent()
    return false


func _overlay_uses_material(node: Node, material: Material) -> bool:
    if node == null or material == null or not is_instance_valid(node) or not is_instance_valid(material):
        return false
    var meshes: Array[MeshInstance3D] = []
    _collect_mesh_instances(node, meshes)
    for mesh_instance in meshes:
        if mesh_instance.material_override == material:
            return true
    return false


func _mesh_retains_imported_mechromancer_pbr(mesh_instance: MeshInstance3D) -> bool:
    if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
        return false
    for surface_index in range(mesh_instance.mesh.get_surface_count()):
        var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
        if material == null or material.albedo_texture == null or not material.normal_enabled or material.normal_texture == null:
            return false
        if material.metallic_texture == null or material.roughness_texture == null or not material.ao_enabled or material.ao_texture == null:
            return false
    return true


func _mesh_retains_imported_organic_pbr(mesh_instance: MeshInstance3D) -> bool:
    if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
        return false
    for surface_index in range(mesh_instance.mesh.get_surface_count()):
        var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
        if material == null or material.albedo_texture == null or not material.normal_enabled or material.normal_texture == null:
            return false
        if material.metallic_texture == null or material.roughness_texture == null or not material.ao_enabled or material.ao_texture == null:
            return false
    return true


func _mesh_retains_imported_bulwark_pbr(mesh_instance: MeshInstance3D) -> bool:
    if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
        return false
    for surface_index in range(mesh_instance.mesh.get_surface_count()):
        var material := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
        if material == null or material.albedo_texture == null or not material.normal_enabled or material.normal_texture == null:
            return false
        if material.metallic_texture == null or material.roughness_texture == null or not material.ao_enabled or material.ao_texture == null:
            return false
    return true


func _mesh_retains_imported_bulwark_emission(mesh_instance: MeshInstance3D) -> bool:
    if mesh_instance == null or mesh_instance.mesh == null:
        return false
    for surface_index in range(mesh_instance.mesh.get_surface_count()):
        var material := mesh_instance.mesh.surface_get_material(surface_index) as StandardMaterial3D
        if material != null and material.emission_enabled and material.emission_texture != null:
            return true
    return false


func _mesh_retains_imported_heartforge_pbr(mesh_instance: MeshInstance3D) -> bool:
    if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() <= 0:
        return false
    for surface_index in range(mesh_instance.mesh.get_surface_count()):
        var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
        if material == null or material.albedo_texture == null or not material.normal_enabled or material.normal_texture == null:
            return false
        if material.metallic_texture == null or material.roughness_texture == null or not material.ao_enabled or material.ao_texture == null:
            return false
    return true


func _mesh_retains_imported_heartforge_emission(mesh_instance: MeshInstance3D) -> bool:
    if mesh_instance == null or mesh_instance.mesh == null:
        return false
    for surface_index in range(mesh_instance.mesh.get_surface_count()):
        var material := mesh_instance.get_active_material(surface_index) as StandardMaterial3D
        if material != null and material.emission_enabled and material.emission_texture != null:
            return true
    return false


func _active_surface_material_ids(mesh_instance: MeshInstance3D) -> Array[int]:
    var material_ids: Array[int] = []
    if mesh_instance == null or mesh_instance.mesh == null:
        return material_ids
    for surface_index in range(mesh_instance.mesh.get_surface_count()):
        var material := mesh_instance.get_active_material(surface_index)
        material_ids.append(material.get_instance_id() if material != null else 0)
    return material_ids


func _find_first_mesh_with_token(node: Node, token: String) -> MeshInstance3D:
    if node == null or not is_instance_valid(node):
        return null
    if node is MeshInstance3D and token in String(node.name).to_lower():
        return node as MeshInstance3D
    for child in node.get_children():
        var result := _find_first_mesh_with_token(child as Node, token)
        if result != null:
            return result
    return null


func _find_mesh_named(node: Node, node_name: String) -> MeshInstance3D:
    if node == null or not is_instance_valid(node):
        return null
    if node is MeshInstance3D and String(node.name) == node_name:
        return node as MeshInstance3D
    for child in node.get_children():
        var result := _find_mesh_named(child as Node, node_name)
        if result != null:
            return result
    return null


func _test_spatial_and_performance(world: IronwrightReleaseWorld3D) -> void:
    # This assertion audits the three LOD bands, not the adaptive-FPS response.
    # Reset the bounded defaults so a heavily loaded CI host cannot shrink the
    # medium radius below the fixture's 80 m actors before the forced sample.
    world.performance_director.active_radius = 58.0
    world.performance_director.medium_radius = 118.0
    world.performance_director.active_entity_budget = 24
    world.performance_director.medium_entity_budget = 40
    var near_enemy := world._spawn_enemy(world.player.global_position + Vector3(6.0, 0.0, 0.0), &"roofleaper") as OrganicEnemyRelease3D
    var medium_enemy := world._spawn_enemy(world.player.global_position + Vector3(80.0, 0.0, 0.0), &"glassmoth") as OrganicEnemyRelease3D
    var medium_robot := world._spawn_robot(&"scout", world.player.global_position + Vector3(82.0, 0.0, 0.0), 1) as RobotUnitRelease3D
    # Keep the reduced-detail fixture outside the medium band but inside the
    # authored world envelope. Positions beyond the world envelope are valid
    # for remote simulation, but the release-world cleanup may legitimately
    # retire them before this presentation-only assertion samples the state.
    var far_enemy := world._spawn_enemy(world.player.global_position + Vector3(140.0, 0.0, 0.0), &"rootweaver") as OrganicEnemyRelease3D
    # These are inert fixtures: the performance gate must inspect LOD state,
    # not allow live combat or ecology cleanup to remove a sample mid-check.
    for fixture in [near_enemy, medium_enemy, medium_robot, far_enemy]:
        var fixture_brain := fixture.get_node_or_null("EnemyTierBrain") as Node
        if fixture_brain != null:
            fixture_brain.set_physics_process(false)
    await process_frame
    world.spatial_index.rebuild()
    var nearest := world.spatial_index.nearest(&"organic_enemies", world.player.global_position, 20.0)
    _expect(nearest == near_enemy, "Spatial index must return the nearest active organic enemy.")
    world.performance_director.force_evaluate_for_test()
    _expect(not near_enemy.reduced_detail and near_enemy.visual_lod_level == 0, "Nearby organisms must remain fully active.")
    var near_enemy_shape := _collision_shape_for(near_enemy)
    _expect(near_enemy.collision_layer == 4 and near_enemy.collision_mask == (1 | 2 | 4) and near_enemy_shape != null and not near_enemy_shape.disabled, "Nearby organisms must retain release collision.")
    _expect(not medium_enemy.reduced_detail and medium_enemy.visual_lod_level == 1 and medium_enemy.coarse_simulation, "Medium-distance organisms must retain state while using coarse simulation.")
    var medium_enemy_shape := _collision_shape_for(medium_enemy)
    _expect(medium_enemy.collision_layer == 0 and medium_enemy.collision_mask == 0 and medium_enemy_shape != null and medium_enemy_shape.disabled, "Medium-distance organisms must release physics collision.")
    _expect(not medium_robot.reduced_detail and medium_robot.visual_lod_level == 1 and medium_robot.coarse_simulation, "Medium-distance machines must retain state while using coarse simulation.")
    var medium_robot_shape := _collision_shape_for(medium_robot)
    _expect(medium_robot.collision_layer == 0 and medium_robot.collision_mask == 0 and medium_robot_shape != null and medium_robot_shape.disabled, "Medium-distance machines must release physics collision.")
    _expect(bool(medium_enemy.find_child("ReducedDetailProxy", true, false).visible), "Medium organisms must retain a lightweight readable silhouette proxy.")
    _expect(bool(medium_robot.find_child("ReducedDetailProxy", true, false).visible), "Medium machines must retain a lightweight readable silhouette proxy.")
    _expect(far_enemy.reduced_detail and far_enemy.visual_lod_level == 2, "Distant organisms must enter reduced-detail simulation.")
    var far_enemy_shape := _collision_shape_for(far_enemy)
    _expect(far_enemy.collision_layer == 0 and far_enemy.collision_mask == 0 and far_enemy_shape != null and far_enemy_shape.disabled, "Distant organisms must release physics collision.")
    var before := far_enemy.global_position
    far_enemy.investigate_position = before + Vector3(10.0, 0.0, 0.0)
    far_enemy.investigate_seconds = 5.0
    far_enemy.reduced_detail_tick(1.0)
    _expect(far_enemy.global_position.distance_to(before) > 0.01, "Reduced-detail organisms must continue causal physical movement.")
    near_enemy.queue_free()
    medium_enemy.queue_free()
    medium_robot.queue_free()
    far_enemy.queue_free()


func _collision_shape_for(actor: Node) -> CollisionShape3D:
    for child in actor.get_children():
        if child is CollisionShape3D:
            return child as CollisionShape3D
    return null


func _test_transactional_save_service() -> void:
    var service := ReleaseTransactionalSaveService3D.new()
    service.configure(TEST_SAVE_ROOT, 3)
    root.add_child(service)
    service.delete_slot(TEST_SLOT)
    var first_saved := service.save_snapshot(TEST_SLOT, {"revision": 1, "nested": {"value": "first"}})
    _expect(first_saved, "First transactional save must succeed: %s" % service.last_error)
    var second_saved := service.save_snapshot(TEST_SLOT, {"revision": 2, "nested": {"value": "second"}})
    _expect(second_saved, "Second transactional save must preserve a backup: %s" % service.last_error)
    _expect(service.corrupt_current_for_test(TEST_SLOT), "Regression test must be able to corrupt only the current save.")
    var recovered := service.load_snapshot(TEST_SLOT)
    _expect(int(recovered.get("revision", 0)) == 1, "A corrupted current save must recover the previous verified backup.")
    var inspection := service.inspect_slot(TEST_SLOT)
    _expect(bool(inspection.get("using_backup", false)), "Recovered slot inspection must report backup use.")
    var recovery_failures: Array[Dictionary] = []
    service.load_failed.connect(func(slot_id: StringName, report: Dictionary) -> void:
        recovery_failures.append(report.duplicate(true))
    )
    var recovery_report := service.get_last_load_report()
    _expect(str(recovery_report.get("outcome", "")) == "recovered_backup", "Backup recovery must expose a recovered-backup report outcome.")
    _expect(int((recovery_report.get("attempts", []) as Array).size()) >= 2 and str(recovery_report.get("selected_source", "")) == "backup_1", "Backup recovery reports must retain the attempted current path and selected backup source.")
    var precision_slot: StringName = &"release_fractional_precision"
    service.delete_slot(precision_slot)
    var precision_payload := {
        "elapsed_seconds": 28800.125000000004,
        "goal_position": [31.1234567890123, 0.0, -17.9876543210987],
        "spawn_credit": 0.6300000000000001,
        "population_state": {1: {"territory": 0.5200000405311584, "food": 0.6699999570846558}},
    }
    _expect(service.save_snapshot(precision_slot, precision_payload), "Transactional checksums must survive JSON round-tripping of long-run fractional state: %s" % service.last_error)
    var precision_loaded := service.load_snapshot(precision_slot)
    _expect(is_equal_approx(float(precision_loaded.get("elapsed_seconds", 0.0)), 28800.125), "Fractional long-run state must remain readable after checksum verification.")
    _expect((precision_loaded.get("population_state", {}) as Dictionary).has("1"), "Transactional normalization must preserve integer-keyed simulation dictionaries as JSON string keys.")
    service.delete_slot(precision_slot)
    var migration_events: Array[String] = []
    service.schema_migrated.connect(func(slot_id: StringName, from_version: int, to_version: int, fields: Array[String]) -> void:
        migration_events.append("%d>%d:%d" % [from_version, to_version, fields.size()])
    )
    _expect(service.save_snapshot(TEST_SLOT, {"schema_version": 3, "base": {"run_state": {"scrap": 77}}}), "A versioned save fixture must be writable before migration.")
    var versioned_path := "%s/%s.json" % [TEST_SAVE_ROOT, String(TEST_SLOT)]
    var versioned_file := FileAccess.open(versioned_path, FileAccess.READ)
    var versioned_envelope := JSON.parse_string(versioned_file.get_as_text()) as Dictionary
    versioned_file.close()
    versioned_envelope["schema_version"] = 3
    versioned_envelope["payload"] = {"schema_version": 3, "base": {"run_state": {"scrap": 77}}}
    versioned_envelope["checksum_sha256"] = service._sha256(service._canonical_json(versioned_envelope["payload"]))
    var legacy_schema_file := FileAccess.open(versioned_path, FileAccess.WRITE)
    legacy_schema_file.store_string(JSON.stringify(versioned_envelope))
    legacy_schema_file.close()
    var migrated_schema := service.load_snapshot(TEST_SLOT)
    _expect(int((migrated_schema.get("base", {}) as Dictionary).get("run_state", {}).get("scrap", 0)) == 77, "Versioned save migration must preserve the legacy base state.")
    var migrated_inspection := service.inspect_slot(TEST_SLOT)
    var migration_metadata: Dictionary = migrated_inspection.get("metadata", {})
    var migration_record: Dictionary = migration_metadata.get("schema_migration", {})
    _expect(int(migrated_inspection.get("schema_version", 0)) == ReleaseTransactionalSaveService3D.CURRENT_SCHEMA_VERSION, "Versioned save migration must persist the current envelope schema.")
    _expect(int(migration_record.get("from_version", 0)) == 3 and int(migration_record.get("to_version", 0)) == ReleaseTransactionalSaveService3D.CURRENT_SCHEMA_VERSION, "Versioned save migration must retain an explicit from/to report.")
    _expect(migration_events.size() == 1, "Versioned save migration must emit one diagnostic event.")
    var migration_report := service.get_last_load_report()
    _expect(str(migration_report.get("outcome", "")) == "migrated" and bool(migration_report.get("schema_migrated", false)), "Versioned migration must expose a durable migrated-load report outcome.")
    service.delete_slot(TEST_SLOT)
    var failed_file := FileAccess.open(versioned_path, FileAccess.WRITE)
    failed_file.store_string("{corrupt")
    failed_file.close()
    var failed_load := service.load_snapshot(TEST_SLOT)
    _expect(failed_load.is_empty(), "A slot with no valid current or backup snapshot must fail closed.")
    var failed_report := service.get_last_load_report()
    _expect(str(failed_report.get("outcome", "")) == "failed" and not str(failed_report.get("error", "")).is_empty(), "Failed save recovery must expose a human-readable failure report.")
    _expect((failed_report.get("attempts", []) as Array).size() == 4 and recovery_failures.size() == 1, "Failed save recovery must report every bounded candidate and emit one failure signal.")
    service.delete_slot(TEST_SLOT)
    service.queue_free()


func _test_enemy_tier_unified_persistence(world: IronwrightReleaseWorld3D) -> void:
    var bootstrap := world.get_node_or_null("EnemyTierProgressionBootstrap") as EnemyTierProgressionBootstrap3D
    _expect(bootstrap != null and bootstrap.director != null, "Release runtime must include the canonical enemy-tier persistence bootstrap.")
    var tiered_world := world as IronwrightTieredWorld3D
    _expect(tiered_world != null, "Canonical enemy-tier persistence requires the tiered production world.")
    if bootstrap == null or bootstrap.director == null or tiered_world == null:
        return

    var isolated_root := "user://release_enemy_tier_sidecar_test"
    var isolated_slot: StringName = &"isolated_slot"
    var isolated_save_path := "%s/%s.json" % [isolated_root, isolated_slot]
    bootstrap._configure_sidecar_paths(isolated_root, isolated_slot)
    var expected_path := "%s/%s.enemy_tiers.json" % [isolated_root, isolated_slot]
    var director := bootstrap.director
    var sidecar_paths := [
        expected_path,
        expected_path.replace(".json", ".tmp"),
        expected_path.replace(".json", ".backup.json"),
    ]
    for path in sidecar_paths:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

    var original_director_state := director.to_dictionary()
    _test_enemy_runtime_intent_persistence(tiered_world, director)
    director.debug_set_anonymous_rate(2, 0.37)
    director.spawn_credit[2] = 0.63
    director.simulation_clock = 0.43
    director.reconcile_clock = 1.27
    director.intel_clock = 0.81
    var unified_state := director.to_dictionary()
    director.debug_set_anonymous_rate(2, 4.0)
    director.spawn_credit[2] = 0.0
    director.simulation_clock = 0.0
    director.reconcile_clock = 0.0
    director.intel_clock = 0.0
    director.restore_from_dictionary(unified_state)
    _expect(is_equal_approx(float(director.anonymous_rates.get(2, 0.0)), 0.37) and is_equal_approx(float(director.spawn_credit.get(2, 0.0)), 0.63), "Canonical tier rates and spawn credit must round-trip inside one unified state payload.")
    _expect(is_equal_approx(director.simulation_clock, 0.43) and is_equal_approx(director.reconcile_clock, 1.27) and is_equal_approx(director.intel_clock, 0.81), "Unified saves must resume every canonical ecology phase clock without a timing jump.")

    var stale_sidecar := unified_state.duplicate(true)
    (stale_sidecar["anonymous_rates"] as Dictionary)["2"] = 8.75
    var stale_payload_json := bootstrap._canonical_json(stale_sidecar)
    var stale_envelope := {"schema_version": 1, "saved_at_unix": 1, "checksum_sha256": bootstrap._sha256(stale_payload_json), "payload": stale_sidecar}
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(isolated_root))
    var stale_file := FileAccess.open(expected_path, FileAccess.WRITE)
    stale_file.store_string(JSON.stringify(stale_envelope))
    stale_file.close()

    world.set_meta(&"enemy_tier_progression_restored_from_unified", true)
    bootstrap.pending_restore = true
    bootstrap._process(0.0)
    _expect(is_equal_approx(float(director.anonymous_rates.get(2, 0.0)), 0.37), "A stale RC1 sidecar must never overwrite canonical tier state restored from the transactional world generation.")
    var stale_before_save := FileAccess.get_file_as_string(expected_path)
    _expect(bootstrap._on_world_save_completed(isolated_slot, isolated_save_path), "Unified tier persistence must acknowledge a completed transactional world save.")
    _expect(FileAccess.get_file_as_string(expected_path) == stale_before_save, "New saves must not write or rotate the legacy enemy-tier sidecar.")

    director.debug_set_anonymous_rate(2, 71.0)
    director.spawn_credit[2] = director.spawn_credit_cap
    director.applied_events[&"stale.pre_load.event"] = true
    var reset_nest: EnemyTierNest3D
    for raw_nest in director.nests.values():
        if raw_nest is EnemyTierNest3D:
            reset_nest = raw_nest as EnemyTierNest3D
            break
    if reset_nest != null:
        reset_nest.apply_damage(reset_nest.maximum_health + 1.0)
    tiered_world._reset_canonical_enemy_tier_state(director)
    _expect(not director.applied_events.has(&"stale.pre_load.event") and is_zero_approx(float(director.anonymous_rates.get(2, 0.0))), "A legacy load must discard the prior world's canonical event ledger and rates before considering its RC1 sidecar.")
    _expect(is_zero_approx(float(director.spawn_credit.get(2, 0.0))), "A legacy load must discard the prior world's queued spawn credit before reconstruction.")
    if reset_nest != null:
        _expect(reset_nest.is_alive() and is_equal_approx(reset_nest.current_health, reset_nest.maximum_health), "Legacy reconstruction must reset authored nests instead of retaining destruction from the prior world.")
    tiered_world._reconstruct_canonical_enemy_tier_state(director)

    world.set_meta(&"enemy_tier_progression_restored_from_unified", false)
    world.set_meta(&"enemy_tier_progression_migrated_from_sidecar", false)
    bootstrap.pending_restore = true
    bootstrap._process(0.0)
    _expect(is_equal_approx(float(director.anonymous_rates.get(2, 0.0)), 8.75) and bool(world.get_meta(&"enemy_tier_progression_migrated_from_sidecar", false)), "An older save without unified tier state must receive one read-only RC1 sidecar migration.")

    for path in sidecar_paths:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    director.debug_set_anonymous_rate(2, 89.0)
    director.applied_events[&"stale.missing_fallback.event"] = true
    tiered_world._reset_canonical_enemy_tier_state(director)
    tiered_world._reconstruct_canonical_enemy_tier_state(director)
    var missing_rate := float(director.anonymous_rates.get(2, 0.0))
    var missing_population := int(director.population.get(2, 0))
    world.set_meta(&"enemy_tier_progression_restored_from_unified", false)
    world.set_meta(&"enemy_tier_progression_migrated_from_sidecar", false)
    bootstrap.pending_restore = true
    bootstrap._process(0.0)
    _expect(not bool(world.get_meta(&"enemy_tier_progression_migrated_from_sidecar", false)) and is_equal_approx(float(director.anonymous_rates.get(2, 0.0)), missing_rate) and int(director.population.get(2, 0)) == missing_population, "A missing RC1 sidecar must preserve the deterministic loaded-world reconstruction.")
    _expect(not director.applied_events.has(&"stale.missing_fallback.event"), "A missing fallback must never retain the previous world's event ledger.")

    var corrupt_file := FileAccess.open(expected_path, FileAccess.WRITE)
    corrupt_file.store_string(JSON.stringify({"schema_version": 1, "checksum_sha256": "invalid", "payload": {"anonymous_rates": {"2": 999.0}}}))
    corrupt_file.close()
    director.debug_set_anonymous_rate(2, 91.0)
    director.spawn_credit[2] = director.spawn_credit_cap
    director.applied_events[&"stale.corrupt_fallback.event"] = true
    tiered_world._reset_canonical_enemy_tier_state(director)
    tiered_world._reconstruct_canonical_enemy_tier_state(director)
    var reconstructed_rate := float(director.anonymous_rates.get(2, 0.0))
    var reconstructed_credit := float(director.spawn_credit.get(2, 0.0))
    var reconstructed_population := int(director.population.get(2, 0))
    world.set_meta(&"enemy_tier_progression_restored_from_unified", false)
    world.set_meta(&"enemy_tier_progression_migrated_from_sidecar", false)
    bootstrap.pending_restore = true
    bootstrap._process(0.0)
    _expect(not bool(world.get_meta(&"enemy_tier_progression_migrated_from_sidecar", false)), "A corrupt RC1 sidecar must fail closed instead of claiming a migration.")
    _expect(is_equal_approx(float(director.anonymous_rates.get(2, 0.0)), reconstructed_rate) and is_equal_approx(float(director.spawn_credit.get(2, 0.0)), reconstructed_credit) and int(director.population.get(2, 0)) == reconstructed_population, "A missing or corrupt RC1 sidecar must leave the deterministic loaded-world reconstruction intact.")
    _expect(not director.applied_events.has(&"stale.corrupt_fallback.event"), "A corrupt fallback must never resurrect the previous world's event ledger.")

    director.restore_from_dictionary(original_director_state)
    for path in sidecar_paths:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    world.set_meta(&"enemy_tier_progression_restored_from_unified", false)
    world.set_meta(&"enemy_tier_progression_migrated_from_sidecar", false)
    bootstrap._configure_sidecar_paths("user://saves", &"world_0")


func _test_enemy_runtime_intent_persistence(world: IronwrightTieredWorld3D, director: EnemyTierProgressionDirector3D) -> void:
    var actor: OrganicEnemyTiered3D
    for raw_enemy in get_nodes_in_group(&"organic_enemies"):
        if raw_enemy is OrganicEnemyTiered3D and is_instance_valid(raw_enemy) and not raw_enemy.is_in_group(&"enemy_tier_nests"):
            var candidate := raw_enemy as OrganicEnemyTiered3D
            if candidate.is_alive() and candidate.get_node_or_null("EnemyTierBrain") != null:
                actor = candidate
                break
    _expect(actor != null, "Enemy intent persistence requires one living canonical organic actor.")
    if actor == null:
        return
    var brain := actor.get_node("EnemyTierBrain")
    _expect(brain.has_method(&"serialize_runtime_intent") and brain.has_method(&"restore_runtime_intent"), "Canonical enemy brains must expose bounded runtime-intent persistence helpers.")
    if not brain.has_method(&"serialize_runtime_intent") or not brain.has_method(&"restore_runtime_intent"):
        return

    var original_intent: Dictionary = brain.call(&"serialize_runtime_intent")
    var metadata_keys: Array[StringName] = [&"ecology_region", &"ecology_region_previous", &"ecology_origin", &"causal_source_kind", &"causal_destination", &"enemy_pack_id", &"enemy_behaviour", &"enemy_behaviour_reason"]
    var original_metadata: Dictionary = {}
    var original_metadata_presence: Dictionary = {}
    for metadata_key in metadata_keys:
        original_metadata_presence[metadata_key] = actor.has_meta(metadata_key)
        if actor.has_meta(metadata_key):
            var original_value: Variant = actor.get_meta(metadata_key)
            if original_value is Array:
                original_metadata[metadata_key] = (original_value as Array).duplicate(true)
            elif original_value is Dictionary:
                original_metadata[metadata_key] = (original_value as Dictionary).duplicate(true)
            else:
                original_metadata[metadata_key] = original_value

    var destination := actor.global_position + Vector3(31.0, 0.0, -17.0)
    actor.set_meta(&"ecology_region", "migration.route")
    actor.set_meta(&"ecology_region_previous", "region.west_grid")
    actor.set_meta(&"ecology_origin", "tier_replenishment")
    actor.set_meta(&"causal_source_kind", "persistence_fixture")
    actor.set_meta(&"causal_destination", [destination.x, destination.y, destination.z])
    brain.call(&"receive_causal_threat_goal", destination, &"persistence_fixture")
    brain.set("decision_clock", 0.41)
    brain.set("remote_clock", 0.19)
    brain.set("state_elapsed", 6.25)
    brain.set("roam_serial", 23)
    brain.set("scout_serial", 11)
    var snapshot := world._collect_release_snapshot()
    var saved_enemy: Dictionary = {}
    for raw_saved_enemy in (snapshot.get("base", {}) as Dictionary).get("enemies", []):
        if raw_saved_enemy is Dictionary and str((raw_saved_enemy as Dictionary).get("name", "")) == String(actor.name):
            saved_enemy = (raw_saved_enemy as Dictionary).duplicate(true)
            break
    _expect(not saved_enemy.is_empty(), "Unified saves must include the selected canonical enemy actor.")
    if not saved_enemy.is_empty():
        var saved_intent: Dictionary = saved_enemy.get("brain_runtime_intent", {})
        _expect(str(saved_intent.get("forced_goal_kind", "")) == "causal_response" and str(saved_intent.get("forced_goal_source", "")) == "persistence_fixture", "Unified saves must retain an enemy's causal-response intent and diagnostic source.")
        _expect(is_equal_approx(float(saved_intent.get("decision_clock", -1.0)), 0.41) and is_equal_approx(float(saved_intent.get("remote_clock", -1.0)), 0.19) and is_equal_approx(float(saved_intent.get("state_elapsed", -1.0)), 6.25), "Unified saves must retain an enemy's exact decision, reduced-detail, and behaviour-state timing phases.")
        _expect(int(saved_intent.get("roam_serial", -1)) == 23 and int(saved_intent.get("scout_serial", -1)) == 11, "Unified saves must retain deterministic roam and scout goal serials.")
        _expect(str(saved_enemy.get("ecology_region_previous", "")) == "region.west_grid" and str(saved_enemy.get("ecology_origin", "")) == "tier_replenishment", "Unified saves must retain enemy region, origin, and migration continuity.")
        _expect(str(saved_enemy.get("causal_source_kind", "")) == "persistence_fixture" and (saved_enemy.get("causal_destination", []) as Array).size() == 3, "Unified saves must retain the causal source and destination that explain an enemy's movement.")

        brain.call(&"receive_migration_goal", actor.global_position + Vector3(-44.0, 0.0, 12.0), &"region.flood_market")
        actor.set_meta(&"ecology_origin", "mutated_after_save")
        world._restore_canonical_enemy_continuity(director, [saved_enemy])
        var restored_intent: Dictionary = brain.call(&"serialize_runtime_intent")
        var restored_goal: Array = restored_intent.get("goal_position", [])
        _expect(str(restored_intent.get("forced_goal_kind", "")) == "causal_response" and str(restored_intent.get("forced_goal_source", "")) == "persistence_fixture", "Enemy save restoration must resume the saved causal intent instead of choosing an unrelated fresh behavior.")
        _expect(restored_goal.size() == 3 and Vector3(float(restored_goal[0]), float(restored_goal[1]), float(restored_goal[2])).is_equal_approx(destination), "Enemy save restoration must retain the physical causal destination.")
        _expect(is_equal_approx(float(restored_intent.get("decision_clock", -1.0)), 0.41) and is_equal_approx(float(restored_intent.get("remote_clock", -1.0)), 0.19) and is_equal_approx(float(restored_intent.get("state_elapsed", -1.0)), 6.25), "Enemy save restoration must resume the saved timing phases instead of making an early or delayed decision.")
        _expect(int(restored_intent.get("roam_serial", -1)) == 23 and int(restored_intent.get("scout_serial", -1)) == 11, "Enemy save restoration must resume deterministic future goal selection.")
        _expect(str(actor.get_meta(&"ecology_region_previous", "")) == "region.west_grid" and str(actor.get_meta(&"ecology_origin", "")) == "tier_replenishment", "Enemy save restoration must retain region and origin diagnostics.")
        _expect(str(actor.get_meta(&"enemy_pack_id", "")) == str(saved_enemy.get("enemy_pack_id", "")), "Enemy save restoration must retain pack continuity.")

    brain.call(&"restore_runtime_intent", original_intent)
    for metadata_key in metadata_keys:
        if bool(original_metadata_presence.get(metadata_key, false)):
            actor.set_meta(metadata_key, original_metadata.get(metadata_key))
        else:
            actor.remove_meta(metadata_key)


func _test_unified_snapshot(world: IronwrightReleaseWorld3D) -> void:
    var snapshot := world._collect_release_snapshot()
    _expect(int(snapshot.get("schema_version", 0)) == 4, "Unified commercial save snapshot must use schema 4.")
    for domain in ["base", "foundation", "complete", "release"]:
        _expect(snapshot.has(domain), "Unified save snapshot must include the %s domain." % domain)
    var release_data: Dictionary = snapshot.get("release", {})
    for key in ["balance", "performance", "audio", "enemy_tier_progression"]:
        _expect(release_data.has(key), "Release save domain must preserve %s state." % key)


func _test_front_end(world: IronwrightReleaseWorld3D) -> void:
    var front_end := world.release_front_end
    front_end.show_title(false)
    _expect(front_end.active_screen == &"title" and front_end.visible, "Localized release title screen must open.")
    _expect(front_end.backdrop != null and front_end.backdrop.color.a <= 0.50, "The title screen must retain enough authored world presence behind the menu to establish the Heartforge visual identity.")
    var title_atmosphere_material := front_end.title_atmosphere.material as ShaderMaterial if front_end.title_atmosphere != null else null
    _expect(front_end.title_atmosphere != null and title_atmosphere_material != null and title_atmosphere_material.shader != null, "The title screen must retain its restrained forge-and-service atmosphere layer.")
    _expect("RELEASE CANDIDATE" not in front_end.version_label.text.to_upper(), "The title screen must present diegetic version language instead of internal release-status text.")
    _expect(front_end.continue_button.disabled, "Continue must be disabled without a valid save.")
    _expect(front_end.new_world_button != null and front_end.new_world_button.has_focus(), "A first-run title screen must focus the actionable New World entry when Continue is unavailable.")
    _expect(front_end.no_save_label.visible and front_end.no_save_label.text != "", "A first-run title screen must visibly explain why Continue is unavailable.")
    front_end.show_title(true, "SAVED WORLD READY · HEARTFORGE TIER 3 · 4 REGIONS DISCOVERED")
    _expect(not front_end.continue_button.disabled and front_end.save_status_label.visible and front_end.save_status_label.text.contains("HEARTFORGE TIER 3"), "A title screen with a verified save must expose compact progress context beside Continue.")
    front_end.show_title(false)
    _expect(not front_end.save_status_label.visible and front_end.no_save_label.visible, "Returning to a first-run title state must clear stale saved-world progress context.")
    front_end.show_title(true, world._title_save_summary(false, true))
    world.localization_service.set_locale(&"sv")
    _expect("ÄLDRE VÄRLD" in front_end.save_status_label.text, "Changing language on the title screen must refresh legacy saved-world context instead of retaining stale localized copy.")
    world.localization_service.set_locale(&"en")
    front_end.show_title(false)
    var title_rect := front_end.title_panel.get_global_rect()
    var title_viewport := front_end.get_viewport().get_visible_rect()
    _expect(title_rect.position.y >= title_viewport.position.y - 0.5 and title_rect.end.y <= title_viewport.end.y + 0.5, "The first-run title panel must fit inside the current viewport instead of clipping its no-save guidance.")
    world._show_title_screen()
    _expect(world.camera.global_position.distance_to(world.heartforge.global_position) > 12.0 and is_equal_approx(world.camera.fov, 44.0), "The title screen must use the authored world threshold camera instead of the playable camera origin.")
    _expect(front_end.title_panel.get_global_rect().position.x < title_viewport.size.x * 0.5, "The title panel must leave the opposing side of the frame open for the Heartforge and opening cast.")
    _expect(not world.hud.visible and not world.strategic_hud.visible and not world.operations_hud.visible, "The title screen must hide tactical HUD layers instead of leaving gameplay guidance behind the modal.")
    world._start_release_world()
    _expect(world.hud.visible and world.strategic_hud.visible and world.operations_hud.visible, "Entering the playable world must restore all tactical HUD layers.")
    world.pending_launch_mode = &"title"
    world._request_release_scene_reload(&"continue", false)
    _expect(world.pending_launch_mode == &"continue" and world._should_build_city_on_boot(), "Continue from the lightweight title shell must request a full playable scene rebuild before loading the save.")
    world.pending_launch_mode = &"title"
    if world.release_world_art != null and world.release_world_art.dressing_root != null:
        world.release_world_art.dressing_root.visible = false
    for node_name in ["ProceduralUrbanDistrict", "Heartforge", "HeartforgeVerticalSlice", "CozyHeartforgeCamp", "UrbanAestheticPass"]:
        var live_node := world.get_node_or_null(node_name) as Node3D
        if live_node != null:
            live_node.visible = false
    world._restore_live_world_presentation()
    _expect(world.release_world_art != null and world.release_world_art.dressing_root != null and world.release_world_art.dressing_root.visible, "Save restoration must reassert the release dressing instead of leaving actors over a blank world.")
    for node_name in ["ProceduralUrbanDistrict", "Heartforge", "HeartforgeVerticalSlice", "CozyHeartforgeCamp", "UrbanAestheticPass"]:
        var restored_node := world.get_node_or_null(node_name) as Node3D
        if restored_node != null:
            _expect(restored_node.visible, "Save restoration must keep %s visible." % node_name)
    front_end.show_settings_from_title()
    _expect(front_end.active_screen == &"settings", "Accessibility and audio settings screen must open from title.")
    _expect(front_end.settings_controls.size() >= 18, "Settings screen must expose release accessibility, audio, language, pacing and controller options.")
    for action in ReleaseSettingsService3D.REMAPPABLE_ACTIONS:
        _expect(front_end.remap_buttons.has(action), "Settings screen must expose a remapping control for %s." % String(action))
        _expect(front_end.controller_remap_buttons.has(action), "Settings screen must expose a controller remapping control for %s." % String(action))
    var raw_localization_labels := 0
    for node in front_end.settings_panel.find_children("*", "Label", true, false):
        if node is Label and String((node as Label).text).begins_with("settings."):
            raw_localization_labels += 1
    _expect(raw_localization_labels == 0, "Settings labels must resolve localization keys instead of exposing raw settings.* identifiers.")
    front_end.hide_all()

    world.hud.show_map_banner(true)
    var map_banner_rect := world.hud.map_banner.get_global_rect()
    var viewport_size := Vector2(world.get_viewport().get_visible_rect().size)
    _expect(map_banner_rect.position.x >= -0.5 and map_banner_rect.end.x <= viewport_size.x + 0.5, "The command-map banner must remain inside the viewport-safe horizontal bounds.")
    _expect(map_banner_rect.size.x >= 300.0, "The command-map banner must retain enough width to keep its live-position guidance readable.")
    world.hud.show_map_banner(false)

    var containment_detail := world.localization_service.text("hud.ending.first_victory_detail", [
        world.localization_service.text("endgame.containment.name"),
        world.localization_service.text("endgame.containment.ending"),
    ])
    world.hud.show_ending(true, containment_detail, true)
    var ending_content := world.hud.ending_panel.get_node_or_null("PanelContent") as Control
    var ending_label := ending_content.get_child(0) as Label if ending_content != null and ending_content.get_child_count() > 0 else null
    var ending_text := "\n%s\n" % String(ending_label.text) if ending_label != null else ""
    _expect("\nThe\n" not in ending_text, "The Containment victory narrative must not strand its final paragraph opener on a line by itself.")
    world.hud.dismiss_ending()


func _test_complete_objective_review_fixture(world: IronwrightReleaseWorld3D) -> void:
    world._start_complete_objective_review()
    await process_frame
    _expect(world.outpost_director != null and world.outpost_director.operation.is_empty(), "The idle complete-objective review must not start a competing autonomous outpost haul.")
    _expect(world.endgame_director != null and world.endgame_director.can_initiate(&"protocol.severance"), "The complete-objective review must leave its visible final protocol genuinely initiable.")
    if world.endgame_director != null:
        _expect(world.endgame_director.initiate(&"protocol.severance"), "The complete-objective review protocol action must enter the ordinary active final-protocol path.")


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _finish() -> void:
    if failures.is_empty():
        print("Project Ironwright commercial release tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Project Ironwright commercial release tests failed: %d" % failures.size())
    quit(1)
