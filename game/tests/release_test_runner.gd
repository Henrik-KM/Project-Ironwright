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
    _test_controller_and_accessibility(world)
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
    _expect(world.release_world_art is ReleaseWorldArtDirector3D, "Release runtime must install production environment dressing.")
    _expect(world.release_animation is ReleaseAnimationDirector3D, "Release runtime must install secondary animation.")
    _expect(world.release_front_end is ReleaseFrontEnd3D, "Release runtime must install title, pause and settings screens.")
    _expect(world.run_variation_director is RunVariationDirector3D, "Release runtime must install deterministic authored run variation.")
    _expect(world.release_started, "Headless release tests must enter the playable world automatically.")


func _test_run_variation(world: IronwrightReleaseWorld3D) -> void:
    var variation := world.run_variation_director
    _expect(variation.profile_ids().size() == 3, "Release must load the three authored world-condition profiles.")
    _expect(world.run_state.world_seed != 0, "A new run must record a non-zero world seed.")
    _expect(world.run_state.world_variant_id != &"", "A new run must record a stable world-condition ID.")
    _expect(not variation.current_display_name().is_empty(), "The active world condition must expose a player-readable name.")
    _expect(world.vertical_slice.weather_emitter != null and world.vertical_slice.weather_emitter.amount >= 80, "The active world condition must configure the opening weather emitter.")

    var saved_state := world.run_state.to_dictionary()
    var restored_state := RunState3D.new()
    restored_state.restore_from_dictionary(saved_state)
    _expect(restored_state.world_seed == world.run_state.world_seed, "World variation seed must survive run-state serialization.")
    _expect(restored_state.world_variant_id == world.run_state.world_variant_id, "World variation ID must survive run-state serialization.")


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

    var settings := world.settings_service
    settings.set_value(&"text_scale", 1.35, false)
    settings.set_value(&"high_contrast_ui", true, false)
    settings.apply_accessibility_to_tree(world.hud)
    _expect(world.hud.resource_label.get_theme_font_size("font_size") >= 27, "Text scaling must enlarge the resource HUD.")
    _expect(world.hud.resource_label.get_theme_constant("outline_size") >= 4, "High contrast must strengthen text outlines.")
    settings.set_value(&"text_scale", 1.0, false)
    settings.set_value(&"high_contrast_ui", false, false)


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
    _expect(world.release_world_art.regions_dressed >= 12, "Every persistent region must receive release dressing.")
    _expect(world.release_world_art.meshes_textured > 30, "The existing world must receive a broad textured material pass.")
    _expect(world.release_audio.stream_library.size() >= 13, "Release audio director must load music, ambience and effects.")
    _expect(not world.release_animation.attached_subjects.is_empty(), "Release secondary animation must attach to world subjects.")


func _test_content_breadth(world: IronwrightReleaseWorld3D) -> void:
    _expect(world.region_director.region_data.size() >= 12, "Commercial release must contain at least twelve persistent regions.")
    _expect(world.long_operation_director.operations.size() >= 12, "Commercial release must contain at least twelve physical long-range operations.")
    _expect(world.outpost_sites.size() >= 8, "Commercial release must contain at least eight bounded outpost sites.")
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
    var late_robot := world._spawn_robot(&"salvager", world.player.global_position + Vector3(3.0, 0.0, -3.0), 1)
    var late_enemy := world._spawn_enemy(world.player.global_position + Vector3(-4.0, 0.0, -4.0), &"veilstalker")
    var late_authored_family := world._spawn_enemy(world.player.global_position + Vector3(-6.0, 0.0, -2.0), &"rootweaver")
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
    _expect(world.release_world_art.meshes_textured > textured_before, "Runtime release art must texture meshes added after initial boot.")

    late_robot.queue_free()
    late_enemy.queue_free()
    late_authored_family.queue_free()


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
    _expect(front_end.continue_button.disabled, "Continue must be disabled without a valid save.")
    world._show_title_screen()
    _expect(not world.hud.visible and not world.strategic_hud.visible and not world.operations_hud.visible, "The title screen must hide tactical HUD layers instead of leaving gameplay guidance behind the modal.")
    world._start_release_world()
    _expect(world.hud.visible and world.strategic_hud.visible and world.operations_hud.visible, "Entering the playable world must restore all tactical HUD layers.")
    front_end.show_settings_from_title()
    _expect(front_end.active_screen == &"settings", "Accessibility and audio settings screen must open from title.")
    _expect(front_end.settings_controls.size() >= 16, "Settings screen must expose release accessibility, audio, language and controller options.")
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
