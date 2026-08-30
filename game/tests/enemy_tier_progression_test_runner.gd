extends SceneTree

class FakeEnemy:
    extends CharacterBody3D

    signal killed(enemy, killer)

    var species: StringName = &"skitterling"
    var maximum_health: float = 100.0
    var current_health: float = 100.0
    var attack_damage: float = 10.0
    var move_speed: float = 4.0
    var attack_range: float = 1.5
    var attack_interval: float = 1.0
    var attack_cooldown: float = 0.0
    var investigate_seconds: float = 0.0
    var investigate_position: Vector3 = Vector3.ZERO
    var aggression: float = 0.4
    var state_name: StringName = &"idle"
    var archetype: StringName = &""
    var attacked_target: Node

    func _ready() -> void:
        add_to_group(&"organic_enemies")

    func is_alive() -> bool:
        return current_health > 0.0

    func apply_damage(amount: float, source: Node = null) -> void:
        current_health = maxf(0.0, current_health - amount)
        if current_health <= 0.0:
            killed.emit(self, source)

    func _attack_target(target: Node) -> void:
        attacked_target = target
        if target != null and target.has_method(&"apply_damage"):
            target.call(&"apply_damage", attack_damage, self)


class FakeFriendly:
    extends CharacterBody3D

    var archetype: StringName = &"salvager"
    var maximum_health: float = 100.0
    var current_health: float = 100.0

    func _ready() -> void:
        add_to_group(&"friendly_robots")

    func is_alive() -> bool:
        return current_health > 0.0

    func apply_damage(amount: float, source: Node = null) -> void:
        current_health = maxf(0.0, current_health - amount)


class FakeOutpost:
    extends StaticBody3D

    var role: StringName = &"repair"
    var current_health: float = 200.0
    var maximum_health: float = 200.0

    func _ready() -> void:
        add_to_group(&"outposts")

    func is_alive() -> bool:
        return current_health > 0.0

    func apply_damage(amount: float, source: Node = null) -> void:
        current_health = maxf(0.0, current_health - amount)


class FakeWorld:
    extends Node3D

    var spawned: Array = []

    func _spawn_enemy(position: Vector3, species: StringName):
        var enemy := FakeEnemy.new()
        enemy.species = species
        add_child(enemy)
        enemy.global_position = position
        spawned.append(enemy)
        return enemy


class FakeNotificationHUD:
    extends Node

    var notifications: Array[String] = []

    func push_notification(message: String) -> void:
        notifications.append(message)


var failures: Array[String] = []
var world
var director: EnemyTierProgressionDirector3D


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    world = FakeWorld.new()
    root.add_child(world)
    director = EnemyTierProgressionDirector3D.new()
    director.configure(world)
    world.add_child(director)
    await process_frame
    await process_frame
    director.enabled = false

    _test_transfer_below_cap()
    _test_exact_ten_to_one_transfer()
    _test_high_to_low_no_same_tick_cascade()
    _test_casualty_headroom_and_growth()
    _test_bounded_spawn_credit()
    await _test_physical_nest_spawning_and_cap()
    await _test_causal_threat_nest_and_cap()
    await _test_nest_source_removal_after_evolution()
    _test_dynamic_event_modifiers()
    _test_suppression_notification_cadence()
    await _test_tier_behaviour_progression()
    _test_brain_runtime_intent_round_trip()
    await _test_ordinary_nest_is_not_combat_actor()
    _test_serialization_round_trip()

    world.queue_free()
    await process_frame
    _finish()


func _reset_rates_and_population() -> void:
    for tier in director.tier_order:
        director.debug_set_population(tier, 0)
        director.debug_set_anonymous_rate(tier, 0.0)
        director.spawn_credit[tier] = 0.0
        director.saturated[tier] = false
    director.rate_sources.clear()


func _test_transfer_below_cap() -> void:
    _reset_rates_and_population()
    director.debug_set_population(1, 99)
    director.debug_set_anonymous_rate(1, 10.0)
    director.debug_process_saturation()
    _expect(is_equal_approx(director.replenishment_rate(1), 10.0), "Tier I replenishment must remain at Tier I below cap.")
    _expect(is_zero_approx(director.replenishment_rate(2)), "No upward replenishment transfer may occur below cap.")


func _test_exact_ten_to_one_transfer() -> void:
    _reset_rates_and_population()
    director.debug_set_population(1, director.unit_cap(1))
    director.debug_set_anonymous_rate(1, 10.0)
    director.debug_process_saturation()
    _expect(is_zero_approx(director.replenishment_rate(1)), "Saturated source tier must become zero after transfer.")
    _expect(is_equal_approx(director.replenishment_rate(2), 1.0), "Ten Tier-I units/min must become exactly one Tier-II unit/min.")
    _expect(is_zero_approx(float(director.spawn_credit.get(1, -1.0))), "Saturation must clear source-tier spawn credit.")


func _test_high_to_low_no_same_tick_cascade() -> void:
    _reset_rates_and_population()
    director.debug_set_population(1, director.unit_cap(1))
    director.debug_set_population(2, director.unit_cap(2))
    director.debug_set_anonymous_rate(1, 10.0)
    director.debug_process_saturation()
    _expect(is_equal_approx(director.replenishment_rate(2), 1.0), "A newly transferred Tier-II rate must remain at Tier II until the next evaluation.")
    _expect(is_zero_approx(director.replenishment_rate(3)), "High-to-low processing must prevent a same-tick multi-tier cascade.")
    director.debug_process_saturation()
    _expect(is_zero_approx(director.replenishment_rate(2)), "Tier II must transfer on the following evaluation when still saturated.")
    _expect(is_equal_approx(director.replenishment_rate(3), 0.1), "Second evaluation must transfer Tier II to Tier III at 10:1.")


func _test_casualty_headroom_and_growth() -> void:
    _reset_rates_and_population()
    director.debug_set_population(1, 75)
    director.debug_simulation_tick(60.0)
    _expect(is_equal_approx(director.replenishment_rate(1), 1.0), "One prototype minute must add one unit/min to Tier-I pressure when headroom exists.")
    _expect(is_zero_approx(director.replenishment_rate(2)), "Tier-I casualties must make new pressure refill the weak tier instead of escalating immediately.")


func _test_bounded_spawn_credit() -> void:
    _reset_rates_and_population()
    director.debug_set_anonymous_rate(1, 500.0)
    director.debug_simulation_tick(600.0)
    _expect(float(director.spawn_credit.get(1, 0.0)) <= director.spawn_credit_cap + 0.0001, "Missing spawn sources must never accumulate an unbounded birth backlog.")


func _test_ordinary_nest_is_not_combat_actor() -> void:
    var ordinary_nest := OrganicNest3D.new()
    ordinary_nest.configure({"id": "nest.test_ordinary_registration", "maturity": 0.5, "supported_tiers": [1]})
    world.add_child(ordinary_nest)
    await process_frame
    director._register_enemy(ordinary_nest)
    _expect(not director.connected_enemies.has(ordinary_nest.get_instance_id()), "Ordinary nests may share the organic threat group but must not enter combat-tier stat registration.")
    ordinary_nest.queue_free()
    await process_frame


func _test_physical_nest_spawning_and_cap() -> void:
    _reset_rates_and_population()
    _remove_all_nests()
    var nest := EnemyTierNest3D.new()
    nest.configure({
        "id": "nest.test_physical",
        "display_name": "Test Physical Nest",
        "position": [12.0, 0.0, -8.0],
        "maturity": 1.0,
        "maximum_health": 100.0,
        "supported_tiers": [1],
        "replenishment_per_minute": {"1": 120.0},
        "regrowth_seconds": 1000.0,
    })
    world.add_child(nest)
    director.register_nest(nest)
    await process_frame
    director.debug_set_population(1, director.unit_cap(1) - 1)
    director.spawn_credit[1] = 2.0
    director._accumulate_and_spawn(1, 1.0)
    _expect(world.spawned.size() >= 1, "Tier-generated organisms must materialize through a physical valid nest.")
    var spawned: Node = world.spawned[-1] as Node
    _expect(StringName(str(spawned.get_meta(&"home_nest_id", ""))) == &"nest.test_physical", "Spawned organism must retain its physical home nest.")
    _expect(int(spawned.get_meta(&"enemy_tier", 0)) == 1, "Spawned organism must retain its assigned tier separately from species.")
    _expect(int(director.population.get(1, 0)) == director.unit_cap(1), "Tier spawning must stop exactly at the unit cap.")
    director.spawn_credit[1] = 3.0
    director._accumulate_and_spawn(1, 60.0)
    _expect(int(director.population.get(1, 0)) == director.unit_cap(1), "No replenishment source may spawn beyond a tier cap.")
    _expect(not nest.is_in_group(&"organic_enemies"), "Physical nests must not inflate organic unit populations or legacy enemy counts.")
    _expect(nest.is_in_group(&"enemy_tier_nests"), "Physical nests must remain addressable as a separate combat-target group.")


func _test_nest_source_removal_after_evolution() -> void:
    _reset_rates_and_population()
    _remove_all_nests()
    var nest := EnemyTierNest3D.new()
    nest.configure({
        "id": "nest.test_evolved_source",
        "display_name": "Evolved Source Nest",
        "position": [-14.0, 0.0, 9.0],
        "maturity": 1.0,
        "maximum_health": 80.0,
        "supported_tiers": [1],
        "replenishment_per_minute": {"1": 5.0},
        "regrowth_seconds": 1000.0,
    })
    world.add_child(nest)
    director.register_nest(nest)
    director._refresh_nest_sources()
    _expect(director.replenishment_rate(1) >= 4.99, "Living physical nest must contribute its configured replenishment.")
    director.debug_set_population(1, director.unit_cap(1))
    director.debug_process_saturation()
    _expect(director.replenishment_rate(2) >= 0.499, "A nest source must evolve upward with its saturated tier.")
    nest.apply_damage(9999.0)
    await process_frame
    _expect(director.replenishment_rate(2) < 0.001, "Clearing a nest must remove its contribution from the tier it evolved into.")


func _test_causal_threat_nest_and_cap() -> void:
    _clear_fake_actors()
    await process_frame
    _reset_rates_and_population()
    _remove_all_nests()
    var nest := EnemyTierNest3D.new()
    nest.configure({
        "id": "nest.test_causal",
        "display_name": "Causal Response Nest",
        "position": [18.0, 0.0, -4.0],
        "maturity": 1.0,
        "maximum_health": 100.0,
        "supported_tiers": [1],
        "replenishment_per_minute": {"1": 0.1},
        "regrowth_seconds": 1000.0,
    })
    world.add_child(nest)
    director.register_nest(nest)
    var near_nest := EnemyTierNest3D.new()
    near_nest.configure({
        "id": "nest.test_causal_near",
        "display_name": "Nearest Causal Response Nest",
        "position": [75.0, 0.0, 42.0],
        "maturity": 1.0,
        "maximum_health": 100.0,
        "supported_tiers": [1],
        "replenishment_per_minute": {"1": 0.1},
        "regrowth_seconds": 1000.0,
    })
    world.add_child(near_nest)
    director.register_nest(near_nest)
    await process_frame
    var incident := Vector3(120.0, 0.0, 80.0)
    director.spawn_credit[1] = 1.0
    var first := director.request_causal_threat(incident, &"skitterling", &"operation_disturbance")
    await process_frame
    await process_frame
    _expect(first != null, "An under-cap causal threat must materialize from a compatible living nest.")
    if first == null:
        return
    _expect(is_zero_approx(float(director.spawn_credit.get(1, -1.0))), "A causal birth must consume exactly one earned canonical spawn credit.")
    _expect(StringName(str(first.get_meta(&"home_nest_id", ""))) == &"nest.test_causal_near", "A causal threat must retain the nearest compatible physical nest that materialized it.")
    _expect(first.global_position.distance_to(near_nest.global_position) < 12.0 and first.global_position.distance_to(incident) > 35.0, "A causal threat must enter at its nearest compatible nest, never pop into existence at the incident point.")
    var brain := first.get_node_or_null("EnemyTierBrain") as EnemyTierBrain3D
    _expect(brain != null and brain.behaviour == &"causal_response", "A nest-origin threat must receive an inspectable causal-response movement reason.")
    _expect(brain != null and brain.home_nest == near_nest and brain.pack_id == &"pack.nest.test_causal_near.tier_1", "A nest-born brain must rebind its physical home, territory, and pack after canonical assignment.")
    if brain != null:
        var distance_before := first.global_position.distance_to(incident)
        brain.set_simulation_lod(2)
        for _step in range(4):
            brain.reduced_detail_tick(1.0)
        _expect(first.global_position.distance_to(incident) < distance_before, "A causal responder must physically advance toward the incident instead of timing out in place.")
        _expect(brain.forced_goal_kind == &"causal_response", "A distant causal route must remain durable until arrival, engagement, or bounded path failure.")

    var tier_one_data := director.tiers[1] as Dictionary
    var original_cap := int(tier_one_data.get("unit_cap", 100))
    var spawn_serial_before := director.spawn_serial
    var redirected_without_credit := director.request_causal_threat(incident + Vector3(2.0, 0.0, 0.0), &"skitterling", &"operation_disturbance")
    _expect(redirected_without_credit == first and director.spawn_serial == spawn_serial_before, "An under-cap incident with no spawn credit must redirect a living organism instead of minting a birth.")

    tier_one_data["unit_cap"] = 1
    director.tiers[1] = tier_one_data
    var redirected := director.request_causal_threat(incident + Vector3(5.0, 0.0, 0.0), &"skitterling", &"endgame_disturbance")
    _expect(redirected == first and director.spawn_serial == spawn_serial_before, "A full tier must redirect its nearest living organism without creating another actor.")
    tier_one_data["unit_cap"] = original_cap
    director.tiers[1] = tier_one_data

    _remove_all_nests()
    var spawned_before: int = int(world.spawned.size())
    director.spawn_credit[5] = 1.0
    var refused := director.request_causal_threat(Vector3.ZERO, &"apex", &"endgame_disturbance")
    _expect(refused == null and world.spawned.size() == spawned_before, "A causal threat with no compatible living nest must refuse materialization.")


func _test_dynamic_event_modifiers() -> void:
    _reset_rates_and_population()
    director.applied_events.clear()
    _expect(not director.config.has("event_modifiers"), "Base population tuning must not duplicate the canonical ecological event table.")
    _expect(director.detailed_event_effects.has(&"operation.buried_lab_excavation"), "The canonical event table must load operation effects.")
    _expect(director.detailed_event_effects.has(&"heartforge_tier_2"), "Technology event IDs must normalize into the canonical progression ledger.")
    var excavation_effect: Dictionary = director.detailed_event_effects.get(&"operation.buried_lab_excavation", {})
    _expect(not String(excavation_effect.get("reason", "")).is_empty(), "Every canonical ecological event needs a causal audit reason.")
    var excavation_reason := director.event_causal_reason(&"operation.buried_lab_excavation")
    _expect(excavation_reason == str(excavation_effect.get("reason", "")), "Runtime ecology diagnostics must expose the configured causal reason without a second event table.")
    _expect(director.apply_event(&"operation.buried_lab_excavation"), "Configured technology expedition must apply an ecological modifier once.")
    _expect(is_equal_approx(director.replenishment_rate(1), 2.8), "The authoritative excavation effect must apply exactly once from the canonical event table.")
    _expect(not director.apply_event(&"operation.buried_lab_excavation"), "The same completed operation must not apply its permanent ecological cost twice.")
    var before := director.replenishment_rate(1)
    _expect(director.apply_event(&"operation.cathedral_brood_suppression"), "Major brood suppression must apply its configured reduction.")
    _expect(director.replenishment_rate(1) < before, "Brood suppression must decrease future replenishment.")
    director._refresh_nest_sources()
    _expect(director.replenishment_rate(1) < before, "Permanent suppression must remain after physical nest-source refresh.")

    var bootstrap := EnemyTierProgressionBootstrap3D.new()
    var notification_hud := FakeNotificationHUD.new()
    bootstrap.initialized = true
    root.add_child(bootstrap)
    bootstrap.director = director
    bootstrap.main_hud = notification_hud
    bootstrap._on_escalation_event(&"operation.buried_lab_excavation", excavation_effect.get("replenishment_delta_per_minute", {}))
    _expect(notification_hud.notifications.size() == 1 and notification_hud.notifications[0].contains(excavation_reason), "Ecological consequence presentation must state the configured causal reason, not only its numeric direction.")
    notification_hud.free()
    bootstrap.free()


func _test_suppression_notification_cadence() -> void:
    var bootstrap := EnemyTierProgressionBootstrap3D.new()
    var notification_hud := FakeNotificationHUD.new()
    bootstrap.initialized = true
    root.add_child(bootstrap)
    bootstrap.main_hud = notification_hud
    bootstrap.intel_hud = EnemyTierIntelHUD3D.new()
    bootstrap.suppression = AutonomousEnemySuppression3D.new()
    bootstrap.add_child(bootstrap.intel_hud)
    bootstrap.add_child(bootstrap.suppression)

    bootstrap._on_suppression_changed(2, 1, "Wardens are thinning a dense feral population.")
    bootstrap._on_suppression_changed(2, 1, "Wardens are thinning a dense feral population.")
    _expect(notification_hud.notifications.is_empty(), "Routine autonomous Tier-I thinning must remain ambient command-map status without repeated notifications.")

    bootstrap._on_suppression_changed(0, 0, "All Wardens are committed to higher-priority protection.")
    _expect(notification_hud.notifications.size() == 1, "A suppression patrol standing down must produce one legible transition notification.")
    bootstrap._on_suppression_changed(0, 0, "All Wardens are committed to higher-priority protection.")
    _expect(notification_hud.notifications.size() == 1, "An inactive suppression state must not repeat its transition notification.")

    notification_hud.free()
    bootstrap.free()


func _test_tier_behaviour_progression() -> void:
    _clear_fake_actors()
    await process_frame
    var target := FakeFriendly.new()
    target.archetype = &"salvager"
    world.add_child(target)
    target.global_position = Vector3(7.0, 0.0, 0.0)
    await process_frame

    var tier_one: FakeEnemy = _make_brained_enemy(1, Vector3.ZERO)
    tier_one.get_node("EnemyTierBrain").call(&"_choose_next_behaviour", true)
    _expect(StringName(str(tier_one.get_meta(&"enemy_behaviour", ""))) in [&"chase", &"roam"], "Tier I must use only primitive roam/chase behavior.")
    target.global_position = Vector3(80.0, 0.0, 0.0)
    tier_one.get_node("EnemyTierBrain").call(&"_choose_next_behaviour", true)
    _expect(StringName(str(tier_one.get_meta(&"enemy_behaviour", ""))) == &"roam", "Tier I without visible prey must wander randomly, not defend nests or scout.")
    var tier_one_brain := tier_one.get_node("EnemyTierBrain") as EnemyTierBrain3D
    tier_one.attack_cooldown = 0.9
    tier_one_brain._physics_process(0.1)
    _expect(is_equal_approx(tier_one.attack_cooldown, 0.8), "Tier intelligence must decrement attack cooldown once per simulation tick.")
    tier_one_brain.set_simulation_lod(2)
    _expect(not tier_one_brain.is_physics_processing(), "Reduced tier intelligence must suspend its per-frame physics callback.")
    tier_one_brain.reduced_detail_tick(0.45)
    tier_one_brain.set_simulation_lod(1)
    _expect(not tier_one_brain.is_physics_processing(), "Coarse tier intelligence must remain scheduled instead of per-frame.")
    tier_one_brain.coarse_detail_tick(0.22)
    tier_one_brain.set_simulation_lod(0)
    _expect(tier_one_brain.is_physics_processing(), "Active tier intelligence must restore its live physics callback.")

    var stale_target := FakeFriendly.new()
    world.add_child(stale_target)
    tier_one_brain.set("current_target", stale_target)
    stale_target.queue_free()
    await process_frame
    _expect(tier_one_brain.call(&"_validate_target", stale_target) == null, "Tier intelligence must clear a stale freed target without a typed-object runtime error.")

    var nest := EnemyTierNest3D.new()
    nest.configure({"id": "nest.behaviour", "position": [20.0, 0.0, 0.0], "supported_tiers": [1, 2, 3, 4, 5], "replenishment_per_minute": {"1": 0.1}, "maximum_health": 100.0})
    world.add_child(nest)
    director.register_nest(nest)
    target.global_position = Vector3(21.0, 0.0, 0.0)
    var tier_two: FakeEnemy = _make_brained_enemy(2, Vector3(24.0, 0.0, 0.0), &"nest.behaviour")
    tier_two.get_node("EnemyTierBrain").call(&"_choose_next_behaviour", true)
    _expect(StringName(str(tier_two.get_meta(&"enemy_behaviour", ""))) == &"guard_nest", "Tier II must purposefully guard a threatened home nest.")

    target.global_position = Vector3(35.0, 0.0, 0.0)
    var tier_three: FakeEnemy = _make_brained_enemy(3, Vector3(28.0, 0.0, 0.0), &"nest.behaviour")
    tier_three.get_node("EnemyTierBrain").call(&"_choose_next_behaviour", true)
    _expect(StringName(str(tier_three.get_meta(&"enemy_behaviour", ""))) in [&"hunt_vulnerable", &"coordinated_hunt"], "Tier III must proactively hunt vulnerable work frames.")

    var outpost := FakeOutpost.new()
    world.add_child(outpost)
    outpost.global_position = Vector3(48.0, 0.0, 0.0)
    var tier_four: FakeEnemy = _make_brained_enemy(4, Vector3(42.0, 0.0, 0.0), &"nest.behaviour")
    tier_four.get_node("EnemyTierBrain").call(&"_choose_next_behaviour", true)
    _expect(StringName(str(tier_four.get_meta(&"enemy_behaviour", ""))) in [&"strategic_attack", &"route_ambush", &"probe_defences"], "Tier IV must make strategic route or infrastructure decisions.")

    var tier_five: FakeEnemy = _make_brained_enemy(5, Vector3(44.0, 0.0, 0.0), &"nest.behaviour")
    tier_five.get_node("EnemyTierBrain").call(&"_choose_next_behaviour", true)
    _expect(StringName(str(tier_five.get_meta(&"enemy_behaviour", ""))) in [&"regional_predation", &"maintain_large_territory"], "Tier V must operate at a regional strategic level.")


func _make_brained_enemy(tier: int, position: Vector3, nest_id: StringName = &""):
    var enemy := FakeEnemy.new()
    world.add_child(enemy)
    enemy.global_position = position
    director.assign_enemy_tier(enemy, tier, nest_id)
    return enemy


func _test_brain_runtime_intent_round_trip() -> void:
    var actor: FakeEnemy = _make_brained_enemy(3, Vector3(64.0, 0.0, -12.0), &"nest.behaviour")
    var brain := actor.get_node("EnemyTierBrain") as EnemyTierBrain3D
    _expect(brain != null and brain.initialized, "Runtime-intent persistence requires one initialized canonical enemy brain.")
    if brain == null or not brain.initialized:
        return
    var original_lod := brain.simulation_lod
    var original_intent := brain.serialize_runtime_intent()
    brain.set_simulation_lod(2)
    brain.decision_clock = 0.73
    brain.remote_clock = 0.21
    brain.state_elapsed = 8.5
    brain.roam_serial = 17
    brain.scout_serial = 9
    var saved := brain.serialize_runtime_intent()

    brain.decision_clock = 0.0
    brain.remote_clock = 0.0
    brain.state_elapsed = 0.0
    brain.roam_serial = 0
    brain.scout_serial = 0
    brain.restore_runtime_intent(saved)
    _expect(is_equal_approx(brain.decision_clock, 0.73), "Enemy decision phase must resume at the same point after save and restore.")
    _expect(is_equal_approx(brain.remote_clock, 0.21), "Enemy reduced-detail accumulation must survive save and restore.")
    _expect(is_equal_approx(brain.state_elapsed, 8.5), "Enemy behaviour-state elapsed time must survive save and restore.")
    _expect(brain.roam_serial == 17 and brain.scout_serial == 9, "Deterministic roam and scout goal serials must survive save and restore.")

    var legacy := saved.duplicate(true)
    for key in ["decision_clock", "remote_clock", "state_elapsed", "roam_serial", "scout_serial"]:
        legacy.erase(key)
    brain.decision_clock = 0.5
    brain.remote_clock = 0.4
    brain.state_elapsed = 33.0
    brain.roam_serial = 80
    brain.scout_serial = 70
    brain.restore_runtime_intent(legacy)
    _expect(is_zero_approx(brain.decision_clock) and is_zero_approx(brain.remote_clock) and is_zero_approx(brain.state_elapsed), "Legacy enemy intent must deterministically reset omitted timing phases instead of inheriting construction time.")
    _expect(brain.roam_serial == 0 and brain.scout_serial == 0, "Legacy enemy intent must deterministically reset omitted goal serials.")

    brain.restore_runtime_intent(original_intent)
    brain.set_simulation_lod(original_lod)


func _test_serialization_round_trip() -> void:
    director.applied_events[&"test.event"] = true
    director.debug_set_anonymous_rate(1, 3.25)
    director.spawn_credit[1] = 1.75
    director.simulation_clock = 0.37
    director.reconcile_clock = 1.41
    director.intel_clock = 0.92
    var saved := director.to_dictionary()
    director.debug_set_anonymous_rate(1, 0.0)
    director.spawn_credit[1] = 0.0
    director.simulation_clock = 0.0
    director.reconcile_clock = 0.0
    director.intel_clock = 0.0
    director.applied_events.clear()
    director.restore_from_dictionary(saved)
    _expect(int(saved.get("schema_version", 0)) == 2, "Canonical ecology persistence must version its deterministic clock-complete schema.")
    _expect(director.replenishment_rate(1) >= 3.249, "Tier replenishment must survive save and restore.")
    _expect(is_equal_approx(float(director.spawn_credit.get(1, 0.0)), 1.75), "Fractional spawn credit must survive save and restore.")
    _expect(bool(director.applied_events.get(&"test.event", false)), "Applied ecological events must survive save and restore.")
    _expect(director.suppression_offsets.has(1), "Persistent ecological suppression offsets must survive the release save domain.")
    _expect(is_equal_approx(director.simulation_clock, 0.37), "The canonical ecology simulation phase must survive save and restore.")
    _expect(is_equal_approx(director.reconcile_clock, 1.41), "The canonical ecology population-reconcile phase must survive save and restore.")
    _expect(is_equal_approx(director.intel_clock, 0.92), "The canonical ecology intelligence phase must survive save and restore.")

    var legacy := saved.duplicate(true)
    for key in ["simulation_clock", "reconcile_clock", "intel_clock"]:
        legacy.erase(key)
    director.simulation_clock = 0.8
    director.reconcile_clock = 1.8
    director.intel_clock = 1.8
    director.restore_from_dictionary(legacy)
    _expect(is_zero_approx(director.simulation_clock) and is_zero_approx(director.reconcile_clock) and is_zero_approx(director.intel_clock), "Schema-1 ecology saves must deterministically reset omitted phase clocks.")


func _remove_all_nests() -> void:
    for nest in director.nests.values():
        if is_instance_valid(nest):
            nest.queue_free()
    director.nests.clear()
    director.rate_sources.clear()


func _clear_fake_actors() -> void:
    for group_name in [&"organic_enemies", &"friendly_robots", &"outposts"]:
        for node in get_nodes_in_group(group_name):
            if node != null and is_instance_valid(node) and node != director:
                node.queue_free()


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)


func _finish() -> void:
    if failures.is_empty():
        print("Project Ironwright enemy tier progression tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Project Ironwright enemy tier progression tests failed: %d" % failures.size())
    quit(1)
