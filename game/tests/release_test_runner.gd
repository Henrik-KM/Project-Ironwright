extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")
const TEST_SAVE_ROOT := "user://release_test_saves"
const TEST_SLOT: StringName = &"release_regression"

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

    _test_release_services(world)
    _test_run_variation(world)
    _test_localization(world)
    await _test_controller_and_accessibility(world)
    _test_release_assets_and_art(world)
    _test_content_breadth(world)
    await _test_runtime_material_continuity(world)
    await _test_spatial_and_performance(world)
    _test_transactional_save_service()
    _test_unified_snapshot(world)
    _test_front_end(world)

    world.queue_free()
    await process_frame
    _finish()


func _test_release_services(world: IronwrightReleaseWorld3D) -> void:
    _expect(world.localization_service is LocalizationService3D, "Release runtime must install localization.")
    _expect(world.settings_service is ReleaseSettingsService3D, "Release runtime must install accessibility and controller settings.")
    _expect(world.transactional_save_service is ReleaseTransactionalSaveService3D, "Release runtime must install transactional persistence.")
    _expect(world.spatial_index is SpatialIndex3D, "Release runtime must install the spatial index.")
    _expect(world.balance_director is BalanceDirector3D, "Release runtime must install long-run balance profiles.")
    _expect(world.performance_director is PerformanceDirector3D, "Release runtime must install active/reduced-detail simulation.")
    _expect(world.release_audio is ReleaseAudioDirector3D, "Release runtime must install adaptive audio.")
    if world.release_audio is ReleaseAudioDirector3D:
        _expect(is_equal_approx(world.release_audio._organic_signature_pitch(&"glassmoth", false), 1.28), "Release audio must preserve the high signature of Glassmoth.")
        _expect(world.release_audio._organic_signature_pitch(&"apex", true) < world.release_audio._organic_signature_pitch(&"apex", false), "Release audio must lower a species signature on death.")
        var report_count_before := world.release_audio.operation_report_count
        world.release_audio.notify_operation(&"salvage", &"outbound", "Test machine report", Vector3(0.0, 0.0, -18.0))
        _expect(world.release_audio.operation_report_count == report_count_before + 1, "Autonomous operation transitions must emit a bounded machine report cue.")
        _expect(world.release_audio.last_operation_signature == &"salvage.outbound", "Machine report cues must retain an explainable operation signature.")
        world.release_audio.notify_operation(&"salvage", &"working", "Repeated work report", Vector3(0.0, 0.0, -18.0))
        world.release_audio.notify_operation(&"salvage", &"working", "Repeated work report", Vector3(0.0, 0.0, -18.0))
        _expect(world.release_audio.operation_report_count == report_count_before + 2, "Repeated autonomous work must be rate-limited instead of flooding the audio layer.")
    _expect(world.release_world_art is ReleaseWorldArtDirector3D, "Release runtime must install production environment dressing.")
    _expect(world.release_animation is ReleaseAnimationDirector3D, "Release runtime must install secondary animation.")
    _expect(world.release_front_end is ReleaseFrontEnd3D, "Release runtime must install title, pause and settings screens.")
    _expect(world.run_variation_director is RunVariationDirector3D, "Release runtime must install deterministic authored run variation.")
    _expect(world.release_started, "Headless release tests must enter the playable world automatically.")


func _test_run_variation(world: IronwrightReleaseWorld3D) -> void:
    var variation := world.run_variation_director
    _expect(variation.profile_ids().size() == 4, "Release must load the four authored world-condition profiles.")
    _expect(variation.profiles.has(&"weather.signal_bloom"), "Release must retain the authored Signal Bloom world-condition profile.")
    if variation.profiles.has(&"weather.signal_bloom"):
        var signal_bloom: Dictionary = variation.profiles[&"weather.signal_bloom"]
        _expect(float(signal_bloom.get("glow_bias", 0.0)) > 0.1 and str(signal_bloom.get("rain_color", "")) == "#76bfc8", "Signal Bloom must carry its distinct cyan organic atmospheric signature.")
    _expect(world.run_state.world_seed != 0, "A new run must record a non-zero world seed.")
    _expect(world.run_state.world_variant_id != &"", "A new run must record a stable world-condition ID.")
    _expect(not variation.current_display_name().is_empty(), "The active world condition must expose a player-readable name.")
    _expect(world.vertical_slice.weather_emitter != null and world.vertical_slice.weather_emitter.amount >= 80, "The active world condition must configure the opening weather emitter.")

    var saved_state := world.run_state.to_dictionary()
    var restored_state := RunState3D.new()
    restored_state.restore_from_dictionary(saved_state)
    _expect(restored_state.world_seed == world.run_state.world_seed, "World variation seed must survive run-state serialization.")
    _expect(restored_state.world_variant_id == world.run_state.world_variant_id, "World variation ID must survive run-state serialization.")

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
    _expect(service.set_locale(&"de"), "German locale must be selectable.")
    _expect(service.text("menu.settings") == "EINSTELLUNGEN", "German catalog must resolve release settings text.")
    service.set_locale(&"en")


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

    var position_before := world.player.global_position
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
    _expect(world.player.global_position.x > position_before.x + 0.2, "The release Mechromancer must move from a joypad axis, not only from raw keyboard state.")

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
        "res://assets/release/audio/music_embers.wav",
        "res://assets/release/audio/music_pressure.wav",
        "res://assets/release/audio/music_sovereignty.wav",
        "res://assets/release/audio/sfx_pistol.wav",
        "res://assets/release/audio/sfx_salvage.wav",
        "res://assets/release/audio/sfx_forge.wav",
    ]
    for path in audio_paths:
        _expect(ResourceLoader.exists(path), "Release audio must import: %s" % path)
        _expect(load(path) is AudioStream, "Release audio must load as AudioStream: %s" % path)

    _expect(world.release_world_art.textures.size() == 9, "Release art director must load all nine texture families.")
    _expect(world.release_world_art.normal_textures.size() == 9, "Release art director must load normal relief for all nine texture families.")
    _expect(world.release_world_art.regions_dressed >= 12, "Every persistent region must receive release dressing.")
    _expect(world.release_world_art.meshes_textured > 30, "The existing world must receive a broad textured material pass.")
    _expect(world.release_audio.stream_library.size() >= 13, "Release audio director must load music, ambience and effects.")
    _expect(not world.release_animation.attached_subjects.is_empty(), "Release secondary animation must attach to world subjects.")
    var rail_dressing := world.release_world_art.dressing_root.find_child("HighDefinitionRailDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(rail_dressing != null, "Release rail dressing must expose a bounded high-definition carriage layer.")
    if rail_dressing != null:
        _expect(rail_dressing.find_child("DerailedTram00", true, false) != null and rail_dressing.find_child("TramWindow00_00", true, false) != null, "Release rail dressing must expose layered carriage shell and window detail.")
        _expect(rail_dressing.find_child("TramServicePanel00", true, false) != null and rail_dressing.find_child("TramRoofVent00", true, false) != null, "Release rail dressing must expose service and roof hardware.")
        _expect(rail_dressing.find_child("TramBogiePlate00_00", true, false) != null and rail_dressing.find_child("TramAxle00_00", true, false) != null, "Release rail dressing must expose readable undercarriage detail.")
    var archive_dressing := world.release_world_art.dressing_root.find_child("HighDefinitionArchiveDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(archive_dressing != null, "Release archive dressing must expose a bounded high-definition records layer.")
    if archive_dressing != null:
        _expect(archive_dressing.find_child("ArchiveFragment00", true, false) != null and archive_dressing.find_child("ArchiveWindow00_00", true, false) != null, "Release archive dressing must expose layered archive shell and window detail.")
        _expect(archive_dressing.find_child("ArchiveRecordsShutter00", true, false) != null and archive_dressing.find_child("ArchiveRoofSlab00", true, false) != null, "Release archive dressing must expose records and roof hardware.")
        _expect(archive_dressing.find_child("ArchiveServiceRiser00", true, false) != null and archive_dressing.find_child("ArchiveFilingRail00_00", true, false) != null, "Release archive dressing must expose service and filing hardware.")
    var market_dressing := world.release_world_art.dressing_root.find_child("HighDefinitionMarketDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(market_dressing != null, "Release market dressing must expose a bounded high-definition stall layer.")
    if market_dressing != null:
        _expect(market_dressing.find_child("MarketStall00", true, false) != null and market_dressing.find_child("MarketCanopy00", true, false) != null, "Release market dressing must expose layered stall shells and canopy detail.")
        _expect(market_dressing.find_child("MarketCounter00", true, false) != null and market_dressing.find_child("MarketDisplayCrate00_00", true, false) != null, "Release market dressing must expose counter and display hardware.")
        _expect(market_dressing.find_child("MarketMembraneAwning00", true, false) != null and market_dressing.find_child("MarketCanopyPost00_-1_-1", true, false) != null, "Release market dressing must expose organic awning and canopy supports.")
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
        _expect(observatory_dressing.find_child("ObservatoryDish", true, false) != null and observatory_dressing.find_child("ObservatoryDishRib00", true, false) != null and observatory_dressing.find_child("ObservatoryDishHub", true, false) != null, "Release observatory dressing must expose ribbed dish geometry.")
        _expect(observatory_dressing.find_child("DishFeed", true, false) != null and observatory_dressing.find_child("DishReceiverLens", true, false) != null, "Release observatory dressing must expose receiver hardware.")
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


func _test_content_breadth(world: IronwrightReleaseWorld3D) -> void:
    _expect(world.region_director.region_data.size() >= 12, "Commercial release must contain at least twelve persistent regions.")
    _expect(world.long_operation_director.operations.size() >= 12, "Commercial release must contain at least twelve physical long-range operations.")
    _expect(world.outpost_sites.size() >= 8, "Commercial release must contain at least eight bounded outpost sites.")
    var heartforge_detail := world.release_world_art.dressing_root.find_child("HighDefinitionHeartforgeDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(heartforge_detail != null and heartforge_detail.find_child("HeartforgeBarrier00", true, false) != null and heartforge_detail.find_child("HeartforgeBarrierService00", true, false) != null, "The opening Heartforge perimeter must retain its authored barrier and service-detail dressing.")
    var industrial_detail := world.release_world_art.dressing_root.find_child("HighDefinitionIndustrialDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(industrial_detail != null, "The West Grid secondary industrial layer must be present.")
    _expect(industrial_detail != null and industrial_detail.find_child("SubstationTank00", true, false) != null, "The West Grid secondary industrial layer must retain its authored substation tanks.")
    _expect(industrial_detail != null and industrial_detail.find_child("TankServiceLouver", true, false) != null, "The West Grid substation tanks must retain their authored service louvers.")
    _expect(industrial_detail != null and industrial_detail.find_child("GridPipeFlange00", true, false) != null, "The West Grid pipe run must retain authored flange hardware.")
    var greenhouse_detail := world.release_world_art.dressing_root.find_child("HighDefinitionGreenhouseDressing", true, false) if world.release_world_art.dressing_root != null else null
    _expect(greenhouse_detail != null and greenhouse_detail.find_child("GlasshouseFrame00", true, false) != null and greenhouse_detail.find_child("ClimateVent", true, false) != null and greenhouse_detail.find_child("GlasshouseOvergrowth00", true, false) != null, "The Municipal Glasshouse secondary layer must retain authored frame, climate and overgrowth detail.")
    var riverworks := world.region_director.get_landmark(&"region.riverworks")
    _expect(riverworks != null and riverworks.find_child("RiverworksRotor", true, false) != null, "Commercial release must retain the authored Riverworks pump landmark.")
    var cathedral := world.region_director.get_landmark(&"region.cathedral_quarter")
    _expect(cathedral != null and cathedral.find_child("CathedralChoirCore", true, false) != null, "Commercial release must retain the authored Cathedral Quarter landmark.")
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
    _expect(west_grid != null and west_grid.find_child("WestGridTurbineHall", true, false) != null, "Commercial release must retain the authored West Grid landmark.")
    _expect(world.balance_director.profile_ids().size() == 3, "Story, Survival and Brutal profiles must be present.")
    _expect(world.balance_director.set_profile(&"story"), "Story profile must be selectable.")
    _expect(world.balance_director.active_enemy_cap() < 96, "Story profile must lower the active enemy cap.")
    _expect(world.balance_director.set_profile(&"brutal"), "Brutal profile must be selectable.")
    _expect(world.balance_director.regional_pressure_multiplier() > 1.0, "Brutal profile must increase regional pressure.")
    world.balance_director.set_profile(&"survival")


func _test_runtime_material_continuity(world: IronwrightReleaseWorld3D) -> void:
    var textured_before := world.release_world_art.meshes_textured
    var opening_robot := get_first_node_in_group(&"friendly_robots") as Node
    var opening_authored_mesh := _find_first_mesh(opening_robot.get_node_or_null("RobotModel/BulwarkAuthoredModel") if opening_robot != null else null)
    _expect(opening_authored_mesh != null and opening_authored_mesh.get_meta(&"release_material_family", &"") == &"metal", "Authored Bulwark shell meshes must receive the release metal material pass.")
    var opening_material := opening_authored_mesh.material_override as StandardMaterial3D if opening_authored_mesh != null else null
    _expect(opening_material != null and opening_material.normal_enabled and opening_material.normal_texture != null, "Authored Bulwark shell materials must carry the generated normal-relief companion.")
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
    for index in range(4):
        var later_species := [&"roofleaper", &"glassmoth", &"miremaw", &"carrionbell"][index] as StringName
        later_families.append(world._spawn_enemy(world.player.global_position + Vector3(-8.0 + float(index) * 3.0, 0.0, -6.0), later_species) as OrganicEnemyRelease3D)
    await process_frame
    await process_frame

    var robot_core := late_robot.get_node_or_null("RobotModel/Chassis/ChassisCore") as MeshInstance3D
    var enemy_core := late_enemy.get_node_or_null("OrganicModel/Torso/TorsoCore") as MeshInstance3D
    var enemy_authored_mesh := _find_first_mesh_with_token(late_enemy.get_node_or_null("OrganicModel"), "veilstalker")
    var late_authored_family_mesh := _find_first_mesh(late_authored_family.get_node_or_null("OrganicModel/RootweaverCrown") if late_authored_family != null else null)
    _expect(robot_core != null and robot_core.get_meta(&"release_material_family", &"") == &"metal", "Late-fabricated robots must receive the release metal material pass.")
    _expect(enemy_core != null and enemy_core.get_meta(&"release_material_family", &"") == &"chitin", "Late-spawned organic families must receive the release chitin material pass.")
    _expect(enemy_authored_mesh != null and enemy_authored_mesh.get_meta(&"release_material_family", &"") == &"chitin", "Authored Veilstalker shell meshes must receive the release chitin material pass.")
    _expect(late_authored_family != null and late_authored_family.find_child("RootweaverAuthoredModel", true, false) != null and late_authored_family_mesh != null and late_authored_family_mesh.get_meta(&"release_material_family", &"") == &"chitin", "Late-spawned Rootweaver shells must retain their authored marker and release chitin material pass.")
    for family in later_families:
        var family_mesh := _find_first_mesh(family.get_node_or_null("OrganicModel") if family != null else null)
        _expect(family_mesh != null and family_mesh.get_meta(&"release_material_family", &"") == &"chitin", "Every later organic family shell must receive the release chitin material pass.")
    _expect(world.release_world_art.meshes_textured > textured_before, "Runtime release art must texture meshes added after initial boot.")

    late_robot.queue_free()
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
    _expect(not medium_enemy.reduced_detail and medium_enemy.visual_lod_level == 1 and medium_enemy.coarse_simulation, "Medium-distance organisms must retain state while using coarse simulation.")
    _expect(not medium_robot.reduced_detail and medium_robot.visual_lod_level == 1 and medium_robot.coarse_simulation, "Medium-distance machines must retain state while using coarse simulation.")
    _expect(bool(medium_enemy.find_child("ReducedDetailProxy", true, false).visible), "Medium organisms must retain a lightweight readable silhouette proxy.")
    _expect(bool(medium_robot.find_child("ReducedDetailProxy", true, false).visible), "Medium machines must retain a lightweight readable silhouette proxy.")
    _expect(far_enemy.reduced_detail and far_enemy.visual_lod_level == 2, "Distant organisms must enter reduced-detail simulation.")
    var before := far_enemy.global_position
    far_enemy.investigate_position = before + Vector3(10.0, 0.0, 0.0)
    far_enemy.investigate_seconds = 5.0
    far_enemy.reduced_detail_tick(1.0)
    _expect(far_enemy.global_position.distance_to(before) > 0.01, "Reduced-detail organisms must continue causal physical movement.")
    near_enemy.queue_free()
    medium_enemy.queue_free()
    medium_robot.queue_free()
    far_enemy.queue_free()


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
    _expect("RELEASE CANDIDATE" not in front_end.version_label.text.to_upper(), "The title screen must present diegetic version language instead of internal release-status text.")
    _expect(front_end.continue_button.disabled, "Continue must be disabled without a valid save.")
    world._show_title_screen()
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
