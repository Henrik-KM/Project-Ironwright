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

    _expect(world != null, "The native scene must instantiate the commercial release world.")
    if world == null:
        _finish()
        return
    # Release assertions use the canonical English copy; isolate the suite
    # from a locale persisted by a preceding live export review.
    world.settings_service.set_value(&"language", "en", false)
    world.localization_service.set_locale(&"en")

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
    _test_enemy_tier_sidecar_isolation(world)
    _test_unified_snapshot(world)
    _test_front_end(world)

    world.queue_free()
    for _cleanup_frame in range(8):
        await process_frame
    _finish()


func _test_release_services(world: IronwrightReleaseWorld3D) -> void:
    _expect(world.audio_director != null and not world.audio_director.release_overlap_bindings_enabled, "The release entrypoint must hand overlapping player and organic cues to the canonical release mixer.")
    _expect(world.localization_service is LocalizationService3D, "Release runtime must install localization.")
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
    _expect(world.run_state.world_seed != 0, "A new run must record a non-zero world seed.")
    _expect(world.run_state.world_variant_id != &"", "A new run must record a stable world-condition ID.")
    _expect(not variation.current_display_name().is_empty(), "The active world condition must expose a player-readable name.")
    _expect(world.vertical_slice.weather_emitter != null and world.vertical_slice.weather_emitter.amount >= 80, "The active world condition must configure the opening weather emitter.")
    var active_profile: Dictionary = variation.current_profile()
    _expect(is_equal_approx(world.strategic_ecology_director.run_variation_pressure_multiplier, float(active_profile.get("ecology_pressure_multiplier", 1.0))), "The active world condition must apply its authored ecology-pressure identity to the live ecology director.")
    if str(active_profile.get("particle_style", "rain")) == "ash" and world.vertical_slice.weather_emitter != null:
        var ash_mesh := world.vertical_slice.weather_emitter.mesh as QuadMesh
        _expect(ash_mesh != null and ash_mesh.size.x <= 0.1 and ash_mesh.size.y <= 0.1, "Ashfall Drift must materialize as small drifting flecks instead of rain streaks.")
    var original_variant := world.run_state.world_variant_id
    world.run_state.set_world_variant(&"weather.ashfall_drift", world.run_state.world_seed)
    variation.apply_current()
    _expect(is_equal_approx(world.strategic_ecology_director.run_variation_pressure_multiplier, 1.02), "Switching to Ashfall Drift must update the live ecology-pressure identity without changing the saved run seed.")
    var ash_mesh := world.vertical_slice.weather_emitter.mesh as QuadMesh if world.vertical_slice.weather_emitter != null else null
    _expect(ash_mesh != null and ash_mesh.size.x <= 0.1 and ash_mesh.size.y <= 0.1, "Ashfall Drift must apply a fleck-sized particle mesh at runtime.")
    world.run_state.set_world_variant(&"weather.frost_hush", world.run_state.world_seed)
    variation.apply_current()
    _expect(is_equal_approx(world.strategic_ecology_director.run_variation_pressure_multiplier, 0.86), "Switching to Frost Hush must update the live ecology-pressure identity without changing the saved run seed.")
    var frost_mesh := world.vertical_slice.weather_emitter.mesh as QuadMesh if world.vertical_slice.weather_emitter != null else null
    _expect(frost_mesh != null and frost_mesh.size.x >= 0.1 and frost_mesh.size.y >= 0.1, "Frost Hush must apply a readable drifting-flake particle mesh at runtime.")
    world.run_state.set_world_variant(original_variant, world.run_state.world_seed)
    variation.apply_current()

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
    _expect(service.text("objective.opening.salvage.title") == "BÄRGA DITT FÖRSTA SKROT", "Swedish catalog must localize the opening objective title.")
    _expect(service.text("notification.forge.insufficient_scrap", [42]) == "OTILLRÄCKLIGT MED SKROT · 42 KRÄVS" and service.text("notification.complete.systems_online") == "STADENS NÄTVERK ÖPPNA · P LÅNGDISTANSOPERATIONER · V SLUTPROTOKOLL", "Swedish gameplay reports must localize fabrication and complete-run guidance.")
    _expect(service.text("notification.outpost.foundation_complete").begins_with("FULLSPELGRUND KLAR") and service.text("objective.full_game.outpost.title") == "GODKÄNN EN UTPOST", "Swedish full-game foundation reports and outpost objectives must resolve through the selected catalog.")
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
    _expect(service.text("objective.opening.salvage.title") == "BERGE DEIN ERSTES SCHROTTGUT", "German catalog must localize the opening objective title.")
    _expect(service.text("notification.forge.insufficient_scrap", [42]) == "NICHT GENUG SCHROTT · 42 ERFORDERLICH" and service.text("notification.final_protocol.initiated") == "ENDPROTOKOLL GESTARTET · DIE REAKTION IST KAUSAL UND UNWIDERRUFLICH", "German gameplay reports must localize fabrication and final-protocol guidance.")
    _expect(service.text("notification.evolution.tier_online", [2]) == "HERZSCHMIEDE-STUFE 2 AKTIV · INGENIEUR- UND AUSSENPOSTENPROTOKOLLE VERFÜGBAR" and service.text("objective.full_game.outpost.title") == "EINEN AUSSENPOSTEN GENEHMIGEN", "German full-game evolution reports and outpost objectives must resolve through the selected catalog.")
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

    var tier_hud := world.get_node_or_null("EnemyTierHUD") as EnemyTierHUD3D
    _expect(tier_hud != null, "Release runtime must expose the population-tier command-map panel.")
    if tier_hud != null:
        tier_hud.set_snapshot({
            "highest_observed_tier": 3,
            "active_nests": 2,
            "total_nests": 4,
            "trend": "WORSENING",
            "tiers": [
                {"tier": 1, "display_name": "Feral", "intelligence_label": "primitive roaming", "density": "LOW", "replenishment_per_minute": 0.4, "saturated": false},
                {"tier": 2, "display_name": "Territorial", "intelligence_label": "nest defence and patrol", "density": "DENSE", "replenishment_per_minute": 3.0, "saturated": false},
                {"tier": 3, "display_name": "Predatory", "intelligence_label": "scouting, hunting and pack memory", "density": "PRESENT", "replenishment_per_minute": 0.8, "saturated": false},
            ],
        })
        tier_hud.refresh_localized_text()
        _expect(tier_hud.title_label.text == "ÖKOLOGISCHE INTELLIGENZ" and "Höchste bestätigte Stufe" in tier_hud.summary_label.text, "German locale must localize the population-tier panel heading and summary.")
        _expect("STUFE 3" in tier_hud.tier_rows[2].text and "Spähen, Jagd" in tier_hud.tier_rows[2].text and "langsame Erneuerung" in tier_hud.tier_rows[2].text, "German locale must localize tier names, intelligence and replenishment labels.")

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
    var keyboard_position_before := world.player.global_position
    var expected_keyboard_direction := world.player._camera_relative_movement(Vector2(0.0, -1.0))
    Input.action_press(&"iw_move_up")
    for _frame in range(12):
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
    for _frame in range(12):
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
    settings.set_value(&"text_scale", 1.35, false)
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
    _expect(not world.release_animation.attached_subjects.is_empty(), "Release secondary animation must attach to world subjects.")
    var rail_dressing := world.release_world_art.dressing_root.find_child("HighDefinitionRailDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(rail_dressing != null, "Release rail dressing must expose a bounded high-definition carriage layer.")
    if rail_dressing != null:
        _expect(rail_dressing.find_child("DerailedTram00", true, false) != null and rail_dressing.find_child("TramWindow00_00", true, false) != null, "Release rail dressing must expose layered carriage shell and window detail.")
        _expect(rail_dressing.find_child("TramRoofPlate00", true, false) != null and rail_dressing.find_child("TramBeltRail00_Front", true, false) != null and rail_dressing.find_child("TramWindow00_00_Front", true, false) != null, "Release rail dressing must expose paired carriage shell sides, roof plate and belt rails.")
        _expect(rail_dressing.find_child("TramServicePanel00", true, false) != null and rail_dressing.find_child("TramRoofVent00", true, false) != null, "Release rail dressing must expose service and roof hardware.")
        _expect(rail_dressing.find_child("TramBogiePlate00_00", true, false) != null and rail_dressing.find_child("TramAxle00_00", true, false) != null, "Release rail dressing must expose readable undercarriage detail.")
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
    world._start_presentation_review()
    await process_frame
    _expect(world.presentation_review_pages.size() == 15, "Presentation review must expose the three core pages, all eleven remote regions and the autonomous outpost role page.")
    _expect(world.presentation_review_label != null and "1-9, 0 DIRECT PAGE" in world.presentation_review_label.text, "Presentation review navigation must describe the digit-key page controls clearly.")
    _expect(world.release_world_art != null and world.release_world_art.dressing_root != null, "Presentation review must retain the release dressing root alongside its controller.")
    world._show_presentation_review_page(0)
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
    world._show_presentation_review_page(1)
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
        _expect(is_equal_approx(first_early_actor.position.x, -4.4) and is_equal_approx(third_early_actor.position.x, 4.4), "Early organic presentation must use the widened triangular near-row composition.")
    var late_review_page: Array = world.presentation_review_pages[2]
    if late_review_page.size() >= 1:
        var first_late_actor := late_review_page[0] as Node3D
        _expect(first_late_actor != null and first_late_actor.find_child("OrganicSurfaceSeam", true, false) != null, "Active organic families must retain a smooth continuous shell seam for close-camera material separation.")
    for page_index in range(3, 3 + world.PRESENTATION_REVIEW_REGIONS.size()):
        world._show_presentation_review_page(page_index)
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
    world._show_presentation_review_page(9)
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
    world._show_presentation_review_page(10)
    await process_frame
    var cathedral_dressing := world.release_world_art.region_dressing_root(&"region.cathedral_quarter") if world.release_world_art != null else null
    _expect(world.release_world_art != null and world.release_world_art.dressing_root.visible, "Remote presentation review must keep the sibling release dressing root visible.")
    _expect(cathedral_dressing != null and cathedral_dressing.visible and cathedral_dressing.find_child("CathedralReleaseFacade", true, false) != null, "Cathedral Quarter presentation review must retain its release facade dressing when selected.")
    if cathedral_dressing != null:
        _expect(cathedral_dressing.find_child("CathedralChoirCrownRail", true, false) != null and cathedral_dressing.find_child("CathedralChoirPipe03", true, false) != null and cathedral_dressing.find_child("CathedralChoirSignal", true, false) != null, "Cathedral Quarter presentation review must retain its layered choir crown and signal detail.")
        var bell_yard := cathedral_dressing.find_child("CathedralBellYardWitness", true, false)
        _expect(bell_yard != null and bell_yard.find_child("CathedralBellYardBell", true, false) != null and bell_yard.find_child("CathedralBellYardSilenceCollar", true, false) != null, "Cathedral Quarter presentation review must retain a physical bell-yard witness for the brood-suppression history.")
    world._show_presentation_review_page(13)
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
    world._show_presentation_review_page(11)
    await process_frame
    var observatory_page: Array = world.presentation_review_pages[11] if world.presentation_review_pages.size() > 11 else []
    _expect(observatory_page.size() == 1, "Observatory Ridge presentation review must expose one dedicated review actor.")
    if observatory_page.size() == 1:
        var observatory_actor := observatory_page[0] as Node3D
        _expect(observatory_actor != null and observatory_actor.visible, "Observatory Ridge presentation review actor must be visible on its remote page.")
        _expect(observatory_actor != null and observatory_actor.find_children("*", "MeshInstance3D", true, false).size() > 20, "Observatory Ridge presentation review actor must retain its authored mesh hierarchy.")
    world._show_presentation_review_page(12)
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
    world._show_presentation_review_page(14)
    await process_frame
    var outpost_page: Array = world.presentation_review_pages[14] if world.presentation_review_pages.size() > 14 else []
    _expect(outpost_page.size() == 4, "Autonomous outpost presentation review must expose all four role silhouettes.")
    _expect(world.camera.fov <= 42.5 and world.presentation_review_camera_target.y >= 1.8, "Autonomous outpost review must use a close elevated frame for the Tier III shelter and role hardware.")
    if outpost_page.size() == 4:
        _expect(absf((outpost_page[2] as Node3D).position.z - (outpost_page[0] as Node3D).position.z) >= 3.0, "Autonomous outpost review must separate its two role rows for readable shelter and signature detail.")
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
        world._show_presentation_review_page(core_page)
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
            _expect(world.camera.fov <= 46.5, "Organic presentation pages must use a close camera frame for anatomy review.")
        if core_page >= 1:
            var organic_front_fill := world.presentation_review_stage.get_node_or_null("ReviewFrontFill") as OmniLight3D
            var organic_cool_light := world.presentation_review_stage.get_node_or_null("ReviewCoolLight") as OmniLight3D
            var organic_detail_fill := world.presentation_review_stage.get_node_or_null("ReviewOrganicFill") as OmniLight3D
            _expect(organic_front_fill != null and organic_front_fill.light_energy >= 4.0, "Organic presentation pages must receive a stronger balanced-frame key light for material separation.")
            _expect(organic_cool_light != null and organic_cool_light.light_energy >= 3.2, "Organic presentation pages must retain a cool rim lift for readable anatomy edges.")
            _expect(organic_detail_fill != null and organic_detail_fill.visible and organic_detail_fill.light_energy >= 1.5, "Organic presentation pages must receive a restrained low front fill for secondary anatomy readability.")
        _expect(world.presentation_review_camera_desired.z < 18.0, "Core presentation pages must use the closer review camera framing.")
    world._show_presentation_review_page(14)
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
    var opening_robot := get_first_node_in_group(&"friendly_robots") as Node
    var opening_bulwark := opening_robot.get_node_or_null("RobotModel/BulwarkAuthoredModel") if opening_robot != null else null
    var opening_authored_mesh := _find_first_mesh(opening_bulwark)
    _expect(opening_authored_mesh != null and opening_authored_mesh.get_meta(&"release_material_family", &"") == &"metal", "Authored Bulwark shell meshes must receive the release metal material pass.")
    var opening_material := opening_authored_mesh.material_override as StandardMaterial3D if opening_authored_mesh != null else null
    _expect(opening_material != null and opening_material.normal_enabled and opening_material.normal_texture != null, "Authored Bulwark shell materials must carry the generated normal-relief companion.")
    _expect(opening_bulwark != null and opening_bulwark.find_child("BulwarkEmitterGuardL", true, false) != null and opening_bulwark.find_child("BulwarkEmitterGuardR", true, false) != null, "The Bulwark protection emitter must retain its authored paired guard rails.")
    _expect(opening_bulwark != null and opening_bulwark.find_child("BulwarkServiceFace", true, false) != null and opening_bulwark.find_child("BulwarkServiceWindow", true, false) != null, "The Bulwark companion must expose an authored front service face and diagnostic window.")
    var player_authored_mesh := _find_first_mesh(world.player.get_node_or_null("MechromancerModel") if world.player != null else null)
    _expect(player_authored_mesh != null and player_authored_mesh.get_meta(&"release_material_family", &"") == &"", "The authored Mechromancer shell must preserve its source material families instead of receiving a flattened release metal override.")
    var player_model := world.player.get_node_or_null("MechromancerModel") if world.player != null else null
    _expect(player_model != null and player_model.find_child("ChestShell", true, false) != null and player_model.find_child("ChestArmorPlate", true, false) != null, "The Mechromancer must expose the layered curved chest shell and breastplate in the live authored model.")
    var player_leather := _find_mesh_named(player_model, "FieldPack")
    var player_coat := _find_mesh_named(player_model, "Torso")
    var player_lamp := _find_mesh_named(player_model, "LampCore")
    _expect(player_leather != null and player_coat != null and player_lamp != null, "The authored Mechromancer material-break samples must remain present.")
    _expect(player_leather != null and player_leather.material_override == null and player_coat != null and player_coat.material_override == null and player_lamp != null and player_lamp.material_override == null, "The Mechromancer leather, coat and cognition-light samples must retain their imported material assignments.")
    _expect(world.player.find_child("FieldHoodRim", true, false) != null and world.player.find_child("FieldVisorHousing", true, false) != null, "The release Mechromancer must retain the close-range hood and visor field-finish hardware.")
    _expect(world.player.find_child("HoodLowerSeam", true, false) != null and world.player.find_child("VisorBrow", true, false) != null and world.player.find_child("VisorMountLeft", true, false) != null and world.player.find_child("VisorMountRight", true, false) != null, "The release Mechromancer must retain the authored protective hood seam and fastened visor brow finish.")
    _expect(world.player.find_child("FieldWorkGloveLeft", true, false) != null and world.player.find_child("FieldWorkGloveRight", true, false) != null and world.player.find_child("FieldCoatHemLeft", true, false) != null and world.player.find_child("FieldCoatHemRight", true, false) != null, "The release Mechromancer must retain paired gloves and coat-hem field-finish hardware.")
    _expect(world.player.find_child("FieldPackBackplate", true, false) != null and world.player.find_child("FieldPackTopRoll", true, false) != null and world.player.find_child("FieldPackServiceCable", true, false) != null, "The release Mechromancer must retain the framed pack and service cable hero surface pass.")
    _expect(opening_robot != null and opening_robot.find_child("BulwarkActuatorRingLeft", true, false) != null and opening_robot.find_child("BulwarkActuatorRingRight", true, false) != null and opening_robot.find_child("BulwarkSideHeatPanelLeft", true, false) != null and opening_robot.find_child("BulwarkServiceWindowFrame", true, false) != null, "The release Bulwark must retain paired actuator, heat-panel and diagnostic-window depth.")
    var relay := world._spawn_robot(&"relay", world.player.global_position + Vector3(5.0, 0.0, -2.0), 1)
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
    var late_enemy := world._spawn_enemy(world.player.global_position + Vector3(-4.0, 0.0, -4.0), &"veilstalker")
    var late_authored_family := world._spawn_enemy(world.player.global_position + Vector3(-6.0, 0.0, -2.0), &"rootweaver")
    var later_families: Array[OrganicEnemyRelease3D] = []
    for index in range(6):
        var later_species := [&"roofleaper", &"glassmoth", &"miremaw", &"carrionbell", &"thornback", &"ashmantle"][index] as StringName
        later_families.append(world._spawn_enemy(world.player.global_position + Vector3(-8.0 + float(index) * 3.0, 0.0, -6.0), later_species) as OrganicEnemyRelease3D)
    await process_frame
    await process_frame

    var organic_damage_root := late_enemy.get_node_or_null("OrganicDamagePresentation") as Node3D
    _expect(organic_damage_root != null, "Organic enemies must carry a bounded persistent damage presentation root.")
    if organic_damage_root != null:
        late_enemy.apply_damage(float(late_enemy.maximum_health) * 0.34)
        _expect(organic_damage_root.visible, "Nearby damaged organisms must expose persistent wound and leak presentation.")
        late_enemy.set_visual_lod(1)
        _expect(not organic_damage_root.visible, "Reduced-detail organism presentation must hide persistent damage overlays.")
        late_enemy.set_visual_lod(0)
        _expect(organic_damage_root.visible, "Restored close organism presentation must show persistent damage overlays again.")

    var robot_core := late_robot.get_node_or_null("RobotModel/Chassis/ChassisCore") as MeshInstance3D
    var enemy_core := late_enemy.get_node_or_null("OrganicModel/Torso/TorsoCore") as MeshInstance3D
    var enemy_authored_mesh := _find_first_mesh_with_token(late_enemy.get_node_or_null("OrganicModel"), "veilstalker")
    var late_authored_family_mesh := _find_first_mesh(late_authored_family.find_child("RootweaverCrown", true, false) if late_authored_family != null else null)
    var rootweaver_membrane_mesh := _find_first_mesh(late_authored_family.find_child("RootweaverSporeFan", true, false) if late_authored_family != null else null)
    _expect(robot_core != null and robot_core.get_meta(&"release_material_family", &"") == &"metal", "Late-fabricated robots must receive the release metal material pass.")
    _expect(enemy_core != null and enemy_core.get_meta(&"release_material_family", &"") == &"chitin", "Late-spawned organic families must receive the release chitin material pass.")
    _expect(enemy_authored_mesh != null and enemy_authored_mesh.get_meta(&"release_material_family", &"") == &"chitin", "Authored Veilstalker shell meshes must receive the release chitin material pass.")
    _expect(late_authored_family != null and late_authored_family.find_child("RootweaverAuthoredModel", true, false) != null and late_authored_family_mesh != null and late_authored_family_mesh.get_meta(&"release_material_family", &"") == &"chitin", "Late-spawned Rootweaver shells must retain their authored marker and release chitin material pass.")
    var rootweaver_membrane_material := rootweaver_membrane_mesh.material_override as StandardMaterial3D if rootweaver_membrane_mesh != null else null
    _expect(rootweaver_membrane_material != null and rootweaver_membrane_material.albedo_color.r < 0.7 and rootweaver_membrane_material.albedo_color.b < 0.7, "Authored organic membrane surfaces must retain restrained release color after texturing.")
    _expect(rootweaver_membrane_material != null and rootweaver_membrane_material.rim_enabled and rootweaver_membrane_material.clearcoat_enabled and rootweaver_membrane_material.get_meta(&"release_organic_surface_finish", &"") == "membrane_rim_clearcoat", "Authored organic membranes must receive a restrained rim and clearcoat finish for high-definition material separation.")
    var rootweaver_spine_mesh := _find_first_mesh(late_authored_family.find_child("RootweaverRootSpineR", true, false) if late_authored_family != null else null)
    var rootweaver_spine_material := rootweaver_spine_mesh.material_override as StandardMaterial3D if rootweaver_spine_mesh != null else null
    var rootweaver_material_delta := 0.0
    if rootweaver_spine_material != null and rootweaver_membrane_material != null:
        rootweaver_material_delta = absf(rootweaver_spine_material.albedo_color.r - rootweaver_membrane_material.albedo_color.r) + absf(rootweaver_spine_material.albedo_color.g - rootweaver_membrane_material.albedo_color.g) + absf(rootweaver_spine_material.albedo_color.b - rootweaver_membrane_material.albedo_color.b)
    _expect(rootweaver_spine_material != null and rootweaver_membrane_material != null and rootweaver_material_delta > 0.12, "Authored organic structural ridges must retain a visible material break from living membranes.")
    _expect(rootweaver_spine_material != null and rootweaver_spine_material.rim_enabled and rootweaver_spine_material.clearcoat_enabled and rootweaver_spine_material.get_meta(&"release_organic_surface_finish", &"") == "chitin_rim_clearcoat", "Authored organic structural anatomy must retain the wet-chitin surface finish.")
    var roofleaper_frame_mesh := _find_first_mesh(later_families[0].find_child("RoofleaperWingFrameL", true, false) if later_families.size() > 0 and later_families[0] != null else null)
    var roofleaper_frame_material := roofleaper_frame_mesh.material_override as StandardMaterial3D if roofleaper_frame_mesh != null else null
    _expect(roofleaper_frame_mesh != null and roofleaper_frame_mesh.get_meta(&"release_material_family", &"") == &"chitin", "Wing-frame supports must use the structural chitin material lane rather than the membrane lane.")
    _expect(roofleaper_frame_material != null and roofleaper_frame_material.albedo_texture == null and not roofleaper_frame_material.normal_enabled and roofleaper_frame_material.roughness >= 0.71 and roofleaper_frame_material.albedo_color.get_luminance() < 0.52, "Wing-frame supports must retain a clean darker, rough structural surface instead of a pale membrane texture.")
    var rootweaver_rib_mesh := _find_first_mesh(late_authored_family.find_child("RootweaverSporeRib0", true, false) if late_authored_family != null else null)
    _expect(rootweaver_rib_mesh != null and rootweaver_rib_mesh.get_meta(&"release_material_family", &"") == &"chitin", "Spore-fan ribs must use the structural chitin material lane while the fan membrane stays living.")
    for family in later_families:
        var family_mesh := _find_first_mesh(family.get_node_or_null("OrganicModel") if family != null else null)
        _expect(family_mesh != null and family_mesh.get_meta(&"release_material_family", &"") == &"chitin", "Every later organic family shell must receive the release chitin material pass.")
    var thornback_mesh := _find_first_mesh_with_token(later_families[4].get_node_or_null("OrganicModel") if later_families[4] != null else null, "thornback")
    var ashmantle_mesh := _find_first_mesh_with_token(later_families[5].get_node_or_null("OrganicModel") if later_families[5] != null else null, "ashmantle")
    _expect(thornback_mesh != null and thornback_mesh.get_meta(&"release_material_family", &"") == &"chitin", "Thornback authored shell meshes must retain release chitin material continuity.")
    _expect(ashmantle_mesh != null and ashmantle_mesh.get_meta(&"release_material_family", &"") == &"chitin", "Ashmantle authored shell meshes must retain release chitin material continuity.")
    var ashmantle_mantle_mesh := _find_first_mesh_with_token(later_families[5].get_node_or_null("OrganicModel") if later_families[5] != null else null, "ashmantlemantle")
    _expect(ashmantle_mantle_mesh != null and ashmantle_mantle_mesh.get_meta(&"release_material_family", &"") == &"membrane", "Ashmantle mantle surfaces must retain release membrane material continuity.")
    _expect(world.release_world_art.meshes_textured > textured_before, "Runtime release art must texture meshes added after initial boot.")

    late_robot.queue_free()
    relay.queue_free()
    late_enemy.queue_free()
    late_authored_family.queue_free()
    for family in later_families:
        family.queue_free()


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
    var near_enemy := world._spawn_enemy(world.player.global_position + Vector3(6.0, 0.0, 0.0), &"roofleaper") as OrganicEnemyRelease3D
    var medium_enemy := world._spawn_enemy(world.player.global_position + Vector3(80.0, 0.0, 0.0), &"glassmoth") as OrganicEnemyRelease3D
    var medium_robot := world._spawn_robot(&"scout", world.player.global_position + Vector3(82.0, 0.0, 0.0), 1) as RobotUnitRelease3D
    var far_enemy := world._spawn_enemy(world.player.global_position + Vector3(260.0, 0.0, 0.0), &"rootweaver") as OrganicEnemyRelease3D
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


func _test_enemy_tier_sidecar_isolation(world: IronwrightReleaseWorld3D) -> void:
    var bootstrap := world.get_node_or_null("EnemyTierProgressionBootstrap")
    _expect(bootstrap != null, "Release runtime must include the enemy-tier sidecar bootstrap.")
    if bootstrap == null:
        return

    var isolated_root := "user://release_enemy_tier_sidecar_test"
    var isolated_slot: StringName = &"isolated_slot"
    var isolated_save_path := "%s/%s.json" % [isolated_root, isolated_slot]
    bootstrap.call("_configure_sidecar_paths", isolated_root, isolated_slot)
    var expected_path := "%s/%s.enemy_tiers.json" % [isolated_root, isolated_slot]
    _expect(str(bootstrap.get("sidecar_path")) == expected_path, "Enemy-tier sidecars must follow the configured save root and slot.")
    _expect(not str(bootstrap.get("sidecar_path")).contains("user://saves/world_0"), "Enemy-tier sidecars must not fall back to the shared default path after isolation.")

    _expect(bool(bootstrap.call("_on_world_save_completed", isolated_slot, isolated_save_path)), "An isolated enemy-tier sidecar save must complete successfully.")
    _expect(FileAccess.file_exists(expected_path), "A completed isolated save must write its enemy-tier sidecar beside that save.")

    var second_root := "user://release_enemy_tier_sidecar_test_second"
    var second_slot: StringName = &"second_slot"
    bootstrap.call("_configure_sidecar_from_save_path", second_slot, "%s/%s.json" % [second_root, second_slot])
    _expect(str(bootstrap.get("sidecar_path")) == "%s/%s.enemy_tiers.json" % [second_root, second_slot], "Loading a save from another root must retarget the enemy-tier sidecar.")

    for path in [
        expected_path,
        expected_path.replace(".json", ".tmp"),
        expected_path.replace(".json", ".backup.json"),
    ]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    bootstrap.call("_configure_sidecar_paths", "user://saves", "world_0")


func _test_unified_snapshot(world: IronwrightReleaseWorld3D) -> void:
    var snapshot := world._collect_release_snapshot()
    _expect(int(snapshot.get("schema_version", 0)) == 4, "Unified commercial save snapshot must use schema 4.")
    for domain in ["base", "foundation", "complete", "release"]:
        _expect(snapshot.has(domain), "Unified save snapshot must include the %s domain." % domain)
    var release_data: Dictionary = snapshot.get("release", {})
    for key in ["balance", "performance", "audio"]:
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
    var title_rect := front_end.title_panel.get_global_rect()
    var title_viewport := front_end.get_viewport().get_visible_rect()
    _expect(title_rect.position.y >= title_viewport.position.y - 0.5 and title_rect.end.y <= title_viewport.end.y + 0.5, "The first-run title panel must fit inside the current viewport instead of clipping its no-save guidance.")
    world._show_title_screen()
    _expect(world.camera.global_position.distance_to(world.heartforge.global_position) > 12.0 and is_equal_approx(world.camera.fov, 44.0), "The title screen must use the authored world threshold camera instead of the playable camera origin.")
    _expect(front_end.title_panel.get_global_rect().position.x < title_viewport.size.x * 0.5, "The title panel must leave the opposing side of the frame open for the Heartforge and opening cast.")
    _expect(not world.hud.visible and not world.strategic_hud.visible and not world.operations_hud.visible, "The title screen must hide tactical HUD layers instead of leaving gameplay guidance behind the modal.")
    world._start_release_world()
    _expect(world.hud.visible and world.strategic_hud.visible and world.operations_hud.visible, "Entering the playable world must restore all tactical HUD layers.")
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
