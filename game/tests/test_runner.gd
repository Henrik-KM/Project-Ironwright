extends SceneTree

const RUN_STATE_SCRIPT := preload("res://scripts/systems/run_state_3d.gd")
const FORMATION_SCRIPT := preload("res://scripts/systems/formation_rules_3d.gd")
const PLAYER_SCENE := preload("res://scenes/actors/mechromancer_3d.tscn")
const ENEMY_SCENE := preload("res://scenes/actors/organic_enemy_3d.tscn")
const MAIN_SCENE := preload("res://scenes/main_3d.tscn")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    _test_progression_costs()
    _test_formation_cohesion()
    await _test_automatic_pistol_and_channel_lockout()
    await _test_main_scene_smoke()

    if failures.is_empty():
        print("Project Ironwright 3D tests passed.")
        quit(0)
    else:
        for failure in failures:
            push_error(failure)
        print("Project Ironwright 3D tests failed: %d" % failures.size())
        quit(1)


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _test_progression_costs() -> void:
    var state := RUN_STATE_SCRIPT.new() as RunState3D
    _expect(state.build_cost(&"salvager") == 42, "The first Scrapper must cost 42 Scrap.")
    _expect(state.build_time(&"guardian") >= 8.0, "Manual Warden fabrication must expose the player for meaningful time.")
    state.scrap = 500
    _expect(state.purchase_upgrade(&"salvager"), "Level 2 Scrapper upgrade should be purchasable with Scrap.")
    _expect(state.level_for(&"salvager") == 2, "Scrapper class level should become 2.")
    _expect(not state.can_upgrade(&"salvager"), "Level 3 must require a rare core, not only ordinary Scrap.")
    state.add_rare_core(1)
    _expect(state.can_upgrade(&"salvager"), "One rare core should unlock the level 3 Scrapper upgrade when Scrap is sufficient.")
    state.free()


func _test_formation_cohesion() -> void:
    _expect(is_equal_approx(FORMATION_SCRIPT.pace_multiplier(1.0), 1.0), "A cohesive group should travel at its doctrine pace.")
    _expect(FORMATION_SCRIPT.pace_multiplier(5.0) < 0.5, "A separated group must slow substantially.")
    _expect(is_zero_approx(FORMATION_SCRIPT.pace_multiplier(8.0)), "A badly separated group must stop and regroup.")
    var salvage_offset: Vector3 = FORMATION_SCRIPT.formation_offset(1, &"salvager")
    var guard_offset: Vector3 = FORMATION_SCRIPT.formation_offset(1, &"guardian")
    _expect(salvage_offset.z > guard_offset.z, "Vulnerable salvagers should remain inside or behind the escort formation.")


func _test_automatic_pistol_and_channel_lockout() -> void:
    var player := PLAYER_SCENE.instantiate() as Mechromancer3D
    var enemy := ENEMY_SCENE.instantiate() as OrganicEnemy3D
    player.position = Vector3.ZERO
    enemy.configure(&"skitterling", null, null)
    enemy.position = Vector3(0.0, 0.0, -6.0)
    root.add_child(player)
    root.add_child(enemy)
    var shots := [0]
    player.pistol_fired.connect(func(_origin: Vector3, _target: Vector3, _node: Node) -> void: shots[0] += 1)
    await physics_frame
    await physics_frame
    _expect(shots[0] >= 1, "The weak pistol must automatically fire at an organic enemy in range.")

    player.pistol_cooldown = 0.0
    var before_channel: int = shots[0]
    _expect(player.begin_channel(&"manual_salvage", enemy, 2.0, "TEST SALVAGE", {}, false, 20.0, 1.0), "Player should be able to begin a manual salvage channel.")
    await physics_frame
    await physics_frame
    _expect(shots[0] == before_channel, "The Mechromancer must not fire while salvaging or fabricating.")
    player.cancel_channel()
    player.free()
    enemy.free()


func _test_main_scene_smoke() -> void:
    var world := MAIN_SCENE.instantiate() as IronwrightWorld3D
    root.add_child(world)
    await process_frame
    await physics_frame
    _expect(world.player != null, "The 3D scene must spawn the Mechromancer.")
    _expect(world.companion != null, "The 3D scene must spawn the indispensable Bulwark companion.")
    _expect(world.heartforge != null, "The 3D scene must spawn exactly one Heartforge.")
    _expect(world.autonomy_director.count_robots(&"companion") == 1, "The opening should contain one companion robot.")
    _expect(get_nodes_in_group("salvage_piles").size() >= 5, "The urban slice needs physical salvage sites.")
    _expect(world.run_state.scrap < world.run_state.build_cost(&"salvager"), "The player should need one risky manual salvage before building the first Scrapper.")
    world.free()
