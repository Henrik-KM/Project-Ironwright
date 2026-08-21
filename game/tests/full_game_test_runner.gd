extends SceneTree

const MAIN_SCENE := preload("res://scenes/main_3d.tscn")
const TEST_SAVE_ROOT := "user://ironwright_outpost_checkpoint_test"
const TEST_SAVE_PATH := "user://ironwright_outpost_checkpoint_test/world_0.json"

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightReleaseWorld3D
    root.add_child(world)
    await process_frame
    await physics_frame
    await process_frame

    _expect(world != null, "The main scene must instantiate the full-game world.")
    _expect(world.progression != null, "The full-game world must contain a progression director.")
    _expect(world.outpost_director != null, "The full-game world must contain an outpost director.")
    _expect(world.strategic_hud != null, "The full-game world must contain the strategic command HUD.")
    _expect(world.progression.heartforge_tier == 1, "The oppressive opening must begin at Heartforge tier 1.")
    _expect(world.progression.technologies.size() >= 35, "The commercial progression tree must contain at least 35 consequential technologies.")
    _expect(world.outpost_sites.size() >= 20, "The full-game world must provide the commercial lower-bound pool of fixed support sites.")
    _expect(world.outpost_director.discovered_sites().is_empty(), "Outpost sites must remain hidden during the opening.")
    _expect(world.run_state.build_cost(&"engineer") == 56, "The Engineer build cost must be available in run state.")

    for enemy in get_nodes_in_group(&"organic_enemies"):
        if is_instance_valid(enemy):
            enemy.free()
    await process_frame

    world.run_state.scrap = 2400
    world.run_state.manual_scrap_recovered = 40
    world.run_state.robots_built = 5
    world.run_state.add_rare_core(3)
    world.run_state.expedition_core_recovered = true
    world.progression._evaluate_automatic_technologies()

    _expect(world.progression.has_technology(&"tech.machine.task_memory"), "Task Memory should unlock automatically after demonstrated salvage.")
    _expect(world.progression.purchase(&"tech.machine.group_coordination"), "Group Coordination should be purchasable after the first machine group exists.")
    _expect(world.progression.purchase(&"tech.heartforge.tier_2"), "The returned core and prerequisite should permit Heartforge tier 2.")
    world.progression._evaluate_automatic_technologies()
    _expect(world.progression.heartforge_tier == 2, "Heartforge tier 2 must unlock through progression.")
    _expect(world.progression.has_effect(&"engineer_build_available"), "Tier 2 must unlock the Engineer frame.")
    _expect(world.progression.has_effect(&"outpost_role_resource"), "Tier 2 must unlock the first outpost role.")
    world._spawn_robot(&"guardian", Vector3(-2.0, 0.0, 4.0), 1)
    var guardian_probe := world.autonomy_director.living_robots(&"guardian")[0]
    var baseline_guardian_speed := guardian_probe.move_speed
    _expect(world.progression.purchase(&"tech.machine.actuator_tuning"), "Actuator Tuning should be purchasable at Heartforge tier 2.")
    _expect(world.progression.modifier_value(&"robot_speed_multiplier") >= 0.08, "Actuator Tuning must expose a persistent machine speed modifier.")
    _expect(guardian_probe.move_speed > baseline_guardian_speed, "Existing machines must receive progression modifiers immediately.")

    var discovered := world.outpost_director.discover_sites_by(&"expedition.north_ruins")
    _expect(discovered >= 3, "The North Ruins expedition must reveal multiple fixed support sites.")

    world._spawn_robot(&"engineer", Vector3(1.0, 0.0, 4.0), 1)
    world._spawn_robot(&"guardian", Vector3(-1.0, 0.0, 4.0), 1)
    world._spawn_robot(&"scout", Vector3(0.0, 0.0, 5.5), 1)
    world._spawn_robot(&"salvager", Vector3(2.0, 0.0, 5.0), 1)
    await physics_frame

    var site := world.outpost_director.get_site(&"site.north_transit_yard")
    _expect(site != null and site.discovered, "The North Transit Yard must be a discovered physical site.")
    _expect(world.outpost_director.can_authorize_build(site.site_id, &"resource"), "A discovered site, tier 2, Scrap, Engineer and escort must permit construction.")

    var start_position := world.heartforge.global_position
    _expect(world.outpost_director.authorize_build(site.site_id, &"resource"), "The resource outpost project should be authorized.")
    _expect(not world.outpost_director.operation.is_empty(), "Authorization must create a physical operation rather than an instant structure.")
    var initial_anchor: Vector3 = world.outpost_director.operation.get("anchor", start_position)
    _expect(initial_anchor.distance_to(site.global_position) > 10.0, "The construction team must begin at the Heartforge.")

    world.transactional_save_service.configure(TEST_SAVE_ROOT, 3)
    world._save_game()
    _expect(FileAccess.file_exists(TEST_SAVE_PATH), "The full-game save hook must write while an outpost convoy is in flight.")
    world._load_game()
    site = world.outpost_director.get_site(&"site.north_transit_yard")
    _expect(StringName(world.outpost_director.operation.get("kind", &"")) == &"build", "Loading must restore the active outpost convoy kind.")
    var restored_anchor: Vector3 = world.outpost_director.operation.get("anchor", Vector3.ZERO)
    _expect(restored_anchor.distance_to(initial_anchor) < 0.1, "Loading must restore the convoy physical anchor.")

    world.outpost_director._update_operation(0.5)
    var moved_anchor: Vector3 = world.outpost_director.operation.get("anchor", initial_anchor)
    _expect(moved_anchor.distance_to(initial_anchor) > 0.01, "The construction group must physically start travelling.")
    _expect(moved_anchor.distance_to(site.global_position) > 1.0, "The outpost must not teleport into existence.")

    _force_operation_arrival(world.outpost_director)
    world.outpost_director._update_operation(0.1)
    _expect(StringName(world.outpost_director.operation.get("state", &"")) == &"working", "Construction must begin only after the full group arrives.")
    world.outpost_director._update_operation(30.0)
    _expect(site.has_functioning_outpost(), "The Engineer group must construct a functioning physical outpost.")
    _expect(site.outpost.role == &"resource", "The chosen strategic role must control autonomous outpost behaviour.")

    _force_operation_arrival(world.outpost_director)
    world.outpost_director._update_operation(0.1)
    _expect(world.outpost_director.operation.is_empty(), "The construction group must physically complete its return.")

    var scrap_before_repair := world.run_state.scrap
    site.outpost.apply_damage(60.0)
    var damaged_health := site.outpost.current_health
    site.outpost._process(6.0)
    _expect(site.outpost.current_health > damaged_health, "A functioning outpost must repair itself automatically.")
    _expect(world.run_state.scrap < scrap_before_repair, "Automatic repair must consume the single ordinary resource.")

    site.outpost._process(20.0)
    _expect(site.outpost.stored_scrap > 0, "A resource outpost must gather Scrap into forward storage.")
    var scrap_before_haul := world.run_state.scrap
    site.outpost.stored_scrap = 30
    world.outpost_director.maintenance_clock = 2.0
    world.outpost_director._process(1.1)
    _expect(StringName(world.outpost_director.operation.get("kind", &"")) == &"haul", "Stored outpost output must schedule a physical protected haul.")
    _expect(world.run_state.scrap == scrap_before_haul, "Resource output must not be credited before the convoy returns.")

    _force_operation_arrival(world.outpost_director)
    world.outpost_director._update_operation(0.1)
    world.outpost_director._update_operation(4.0)
    var loaded_cargo := int(world.outpost_director.operation.get("cargo", 0))
    _expect(loaded_cargo > 0, "The convoy must load real forward-stored Scrap.")
    _expect(world.run_state.scrap == scrap_before_haul, "Loaded cargo must still not teleport to the Heartforge.")
    _force_operation_arrival(world.outpost_director)
    world.outpost_director._update_operation(0.1)
    _expect(world.run_state.scrap == scrap_before_haul + loaded_cargo, "Cargo must be credited only after physical return.")

    world.run_state.scrap = 2400
    site.outpost.apply_damage(99999.0)
    _expect(not site.outpost.is_alive(), "Organic damage must be able to destroy an outpost.")
    world.outpost_director.maintenance_clock = 2.0
    world.outpost_director._process(1.1)
    _expect(StringName(world.outpost_director.operation.get("kind", &"")) == &"rebuild", "Destroyed outposts must automatically schedule escorted rebuilding.")

    _force_operation_arrival(world.outpost_director)
    world.outpost_director._update_operation(0.1)
    world.outpost_director._update_operation(30.0)
    _expect(site.outpost.is_alive(), "The Engineer team must rebuild the destroyed outpost automatically.")
    _force_operation_arrival(world.outpost_director)
    world.outpost_director._update_operation(0.1)

    var progression_data := world.progression.to_dictionary()
    var outpost_data := world.outpost_director.to_dictionary()
    world.progression.restore_from_dictionary(progression_data)
    world.outpost_director.restore_from_dictionary(outpost_data)
    var restored_site := world.outpost_director.get_site(&"site.north_transit_yard")
    _expect(world.progression.heartforge_tier == 2, "Progression save state must preserve Heartforge tier.")
    _expect(restored_site != null and restored_site.has_functioning_outpost(), "Outpost save state must preserve the physical outpost.")
    _expect(restored_site.outpost.role == &"resource", "Outpost save state must preserve strategic role.")

    world.progression.set_heartforge_tier(3)
    world.long_operation_director.completed_operations.append(&"operation.west_grid_survey")
    world.run_state.scrap = 2400
    world.run_state.rare_cores = 4
    _expect(world.progression.can_purchase(&"tech.doctrine.preservation"), "A tier 3 run with the West Grid survey complete must expose the Preservation Doctrine choice.")
    _expect(world.progression.can_purchase(&"tech.doctrine.defiance"), "A tier 3 run with the West Grid survey complete must expose the Defiance Doctrine choice.")
    _expect(world.progression.can_purchase(&"tech.doctrine.predation"), "A tier 3 run with the West Grid survey complete must expose the Predation Doctrine choice.")
    _expect(world.progression.purchase(&"tech.doctrine.preservation"), "The player must be able to commit one machine doctrine.")
    _expect(world.progression.active_doctrine_id() == &"tech.doctrine.preservation", "The committed machine doctrine must persist as a stable technology choice.")
    _expect(not world.progression.can_purchase(&"tech.doctrine.defiance") and not world.progression.can_purchase(&"tech.doctrine.predation"), "Machine doctrine choices must be mutually exclusive rather than becoming a tuning panel.")
    world.strategic_hud.update_progression(world._strategic_technologies(), "Expansion", 3, world.run_state.scrap, world.run_state.rare_cores, world.progression.active_doctrine_display_name())
    _expect(world.strategic_hud.summary_label.text.contains("Preservation Doctrine"), "The strategic evolution surface must show the active machine doctrine.")
    var doctrine_data := world.progression.to_dictionary()
    _expect(int(doctrine_data.get("schema_version", 0)) == 3, "The progression payload must advance its schema for the persisted doctrine choice.")
    world.progression.restore_from_dictionary(doctrine_data)
    _expect(world.progression.active_doctrine_id() == &"tech.doctrine.preservation", "Progression save/load must preserve the committed machine doctrine.")

    if failures.is_empty():
        print("Project Ironwright full-game foundation tests passed.")
        _cleanup_save_files()
        world.free()
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Project Ironwright full-game foundation tests failed: %d" % failures.size())
    _cleanup_save_files()
    world.free()
    quit(1)


func _force_operation_arrival(director: OutpostDirector3D) -> void:
    if director.operation.is_empty():
        return
    var route: PackedVector3Array = director.operation.get("route", PackedVector3Array())
    director.operation["route_index"] = route.size()


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _cleanup_save_files() -> void:
    for path in [TEST_SAVE_PATH, TEST_SAVE_ROOT + "/world_0.backup_1.json", TEST_SAVE_ROOT + "/world_0.backup_2.json", TEST_SAVE_ROOT + "/world_0.backup_3.json", TEST_SAVE_ROOT + "/world_0.tmp"]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
