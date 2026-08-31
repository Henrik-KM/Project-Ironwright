extends SceneTree

const PLAYER_SCENE := preload("res://scenes/actors/mechromancer_3d.tscn")
const MECHROMANCER_PRESENTATION := preload("res://scripts/presentation/mechromancer_presentation_3d.gd")
const RELEASE_WORLD_SOURCE := "res://scripts/main_world_release_3d.gd"

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    _test_review_fixture_contract()
    await _test_live_actor_action_contract()
    if failures.is_empty():
        print("Mechromancer action review tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Mechromancer action review tests failed: %d" % failures.size())
    quit(1)


func _test_review_fixture_contract() -> void:
    var source_file := FileAccess.open(RELEASE_WORLD_SOURCE, FileAccess.READ)
    _expect(source_file != null, "The release-world source must remain readable for action-review contract validation.")
    if source_file == null:
        return
    var source := source_file.get_as_text().replace("\r\n", "\n")
    _expect(source.contains("--mechromancer-action-review"), "The release world must expose the dedicated Mechromancer action-review launch flag.")
    _expect(source.contains("MECHROMANCER_ACTION_REVIEW_SEQUENCE"), "The action review must keep one explicit deterministic action sequence.")
    for action in ["Idle", "Walk", "Fire", "Work", "Upgrade", "Hit", "Death"]:
        _expect(source.contains("&\"%s\"" % action), "The deterministic action review must include %s." % action)
    _expect(source.contains("await _start_presentation_review()"), "The action review must reuse the neutral production gallery rather than a substitute actor scene.")
    _expect(source.contains("mechromancer_action_review_presentation.process_mode = Node.PROCESS_MODE_ALWAYS"), "The paused gallery must keep the runtime presentation bridge processing.")
    _expect(source.contains("mechromancer_action_review_animation.process_mode = Node.PROCESS_MODE_ALWAYS"), "The paused gallery must keep the imported AnimationPlayer processing.")
    _expect(source.contains("review_key >= KEY_1 and review_key <= KEY_7"), "The action gallery must expose deterministic direct selection for all seven live-review states.")
    _expect(source.contains("mechromancer_action_review_manual_hold = true"), "Direct state selection must hold the requested state for reliable visual inspection.")
    _expect(source.contains("1-7 HOLD STATE"), "The action-gallery label must disclose its held direct state controls.")
    _expect(source.contains("SPACE AUTO"), "The action-gallery label must disclose how to resume automatic cycling.")
    _expect(source.contains("player.input_enabled = false"), "The action fixture must disable player input.")
    _expect(source.contains("player.set_physics_process(false)"), "The action fixture must disable actor physics and keep the subject fixed.")
    _expect(source.contains("if mechromancer_action_review_active:\n\t\treturn false"), "The release save gate must reject action-review state.")
    _expect(source.contains("if mechromancer_action_review_active:\n\t\treturn"), "The review lethal path must be guarded before normal game-over handling.")
    _expect(source.contains("player.pistol_fired.emit"), "Fire review must use the production pistol signal without a damage target.")
    _expect(source.contains("player.begin_channel(&\"manual_salvage\""), "Work review must use the production channel method.")
    _expect(source.contains("player.begin_channel(&\"forge_upgrade\""), "Upgrade review must use the production channel method.")
    _expect(source.contains("player.apply_damage(8.0, self)"), "Hit review must use the production damage method.")
    _expect(source.contains("player.apply_damage(player.maximum_health * 2.0, self)"), "Death review must use the production lethal path.")
    _expect(source.contains("ACTOR-OWNED RUNTIME COLLAPSE"), "Death must be labelled as the actor-owned runtime collapse, not an imported seventh clip.")


func _test_live_actor_action_contract() -> void:
    var player := PLAYER_SCENE.instantiate() as Mechromancer3D
    _expect(player != null, "The action review must use the shipped Mechromancer runtime actor.")
    if player == null:
        return
    root.add_child(player)
    player.set_physics_process(false)
    var presentation := MECHROMANCER_PRESENTATION.new() as MechromancerPresentation3D
    presentation.name = "MechromancerPresentation3D"
    presentation.configure(player)
    player.add_child(presentation)
    await process_frame

    _expect(presentation.model_root == player.get_node_or_null("MechromancerModel"), "The action bridge must animate the real actor's authored model root.")
    _expect(presentation.animation_player != null, "The shipped Mechromancer must expose its imported AnimationPlayer.")
    if presentation.animation_player == null:
        player.queue_free()
        await process_frame
        return
    _expect(is_equal_approx(presentation.last_health, player.current_health), "Late presentation attachment must seed current health so the first hit animates.")
    for clip_name in [&"Idle", &"Walk", &"Fire", &"Work", &"Upgrade", &"Hit"]:
        _expect(_has_clip(presentation.animation_player, clip_name), "The authored AnimationPlayer must retain the %s clip." % clip_name)
    _expect(not _has_clip(presentation.animation_player, &"Death"), "Death must remain the actor-owned runtime collapse rather than a misleading imported clip.")

    player.velocity = Vector3.ZERO
    presentation._select_loop_clip()
    _expect(_clip_matches(presentation.active_clip, &"Idle"), "A stationary live actor must select Idle.")

    player.velocity = Vector3(0.0, 0.0, -2.4)
    presentation._select_loop_clip()
    _expect(_clip_matches(presentation.active_clip, &"Walk"), "A moving live actor must select Walk.")

    var fire_origin := player.global_position + Vector3.UP
    player.pistol_fired.emit(fire_origin, fire_origin + Vector3.FORWARD * 5.0, null)
    _expect(_clip_matches(presentation.active_clip, &"Fire"), "The production pistol signal must select Fire.")

    _expect(player.begin_channel(&"manual_salvage", null, 999.0, "ACTION REVIEW", {}, false, 0.0, 0.0), "The production work channel must start without a world target.")
    _expect(_clip_matches(presentation.active_clip, &"Work"), "The production work channel must select Work.")
    player.cancel_channel()

    _expect(player.begin_channel(&"forge_upgrade", null, 999.0, "ACTION REVIEW", {}, false, 0.0, 0.0), "The production upgrade channel must start without a world target.")
    _expect(_clip_matches(presentation.active_clip, &"Upgrade"), "The production forge-upgrade channel must select Upgrade.")
    player.cancel_channel()

    player.velocity = Vector3.ZERO
    player.invulnerability_seconds = 0.0
    var health_before_hit := player.current_health
    player.apply_damage(8.0)
    _expect(player.current_health < health_before_hit, "The focused Hit review must use real bounded actor damage.")
    _expect(_clip_matches(presentation.active_clip, &"Hit"), "The first real hit after late presentation attachment must select Hit.")

    player.heal_full()
    player.invulnerability_seconds = 0.0
    var death_events := [0]
    player.died.connect(func() -> void: death_events[0] += 1)
    player.apply_damage(player.maximum_health * 2.0)
    var death_root := player.get_node_or_null("MechromancerDeathPresentation") as Node3D
    var authored_model := player.get_node_or_null("MechromancerModel") as Node3D
    _expect(death_events[0] == 1 and not player.is_alive(), "The Death phase must exercise the real lethal signal path exactly once.")
    _expect(death_root != null and death_root.visible, "The lethal path must expose the shipped actor-owned equipment collapse.")

    player.death_presentation_remaining = 0.08
    player._refresh_death_presentation()
    _expect(authored_model != null and authored_model.visible and authored_model.rotation.z < -0.8, "The lethal path must keep the authored body visible in a readable grounded fall instead of replacing it with sparse floating debris.")
    _expect(authored_model != null and authored_model.position.y > 0.45, "The fallen authored body must be lifted around its ground pivot instead of clipping below the floor.")

    player.heal_full()
    _expect(player.is_alive() and (death_root == null or not death_root.visible), "The next review cycle must restore the actor entirely in memory.")
    _expect(authored_model != null and authored_model.visible and authored_model.rotation.is_equal_approx(Vector3.ZERO), "Healing the review actor must restore the authored body transform.")
    player.queue_free()
    await process_frame


func _has_clip(player: AnimationPlayer, requested: StringName) -> bool:
    if player.has_animation(requested):
        return true
    for candidate in player.get_animation_list():
        if String(candidate).ends_with("/" + String(requested)) or String(candidate).ends_with(String(requested)):
            return true
    return false


func _clip_matches(actual: StringName, expected: StringName) -> bool:
    return actual == expected or String(actual).ends_with("/" + String(expected)) or String(actual).ends_with(String(expected))


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
