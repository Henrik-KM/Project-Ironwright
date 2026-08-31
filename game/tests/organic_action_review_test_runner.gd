extends SceneTree

const ENEMY_SCENE := preload("res://scenes/actors/organic_enemy_3d.tscn")
const PRESENTATION_FEEDBACK_SCRIPT := preload("res://scripts/presentation/presentation_feedback_3d.gd")
const RELEASE_WORLD_SOURCE := "res://scripts/main_world_release_3d.gd"
const ORGANIC_FAMILIES: Array[StringName] = [
    &"skitterling", &"razorhound", &"roofleaper", &"glassmoth", &"veilstalker", &"burrower", &"sporecaster",
    &"broodmass", &"miremaw", &"carrionbell", &"rootweaver", &"thornback", &"ashmantle", &"apex",
]
const REVIEW_SEQUENCE: Array[StringName] = [
    &"Idle", &"Walk", &"Attack", &"Hit", &"Feed", &"Nest", &"Retreat", &"Death",
]
const OVERLAY_ANCHORS: Dictionary = {
    &"TierSilhouette": &"OrganicTierAttachment",
    &"OrganicDamagePresentation": &"OrganicDamageAttachment",
    &"OrganicDeathPresentation": &"OrganicDeathAttachment",
}
const FORBIDDEN_GENERIC_TIER_NAME_TOKENS: Array[String] = [
    "seam", "cage", "rod",
]
const FORBIDDEN_GENERIC_DEATH_NAME_TOKENS: Array[String] = [
    "organicdeathcarapace", "organicdeathrootcollar", "organicdeathshard", "organicdeathvein", "organicdeathspine",
]

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    _test_review_fixture_contract()
    _test_family_asset_clip_contracts()
    await _test_live_actor_action_contract()
    if failures.is_empty():
        print("Organic action review tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Organic action review tests failed: %d" % failures.size())
    quit(1)


func _test_review_fixture_contract() -> void:
    var source_file := FileAccess.open(RELEASE_WORLD_SOURCE, FileAccess.READ)
    _expect(source_file != null, "The release-world source must remain readable for organic action-review validation.")
    if source_file == null:
        return
    var source := source_file.get_as_text().replace("\r\n", "\n")
    _expect(source.contains("--organic-action-review"), "The release world must expose the dedicated organic action-review launch flag.")
    _expect(source.contains("--organic-action-review-family="), "The action review must expose an exact family-selection argument.")
    _expect(source.contains("ORGANIC_ACTION_REVIEW_FAMILIES"), "The family selector must remain bounded by one canonical roster.")
    for family in ORGANIC_FAMILIES:
        _expect(source.contains("&\"%s\"" % String(family)), "The action review must support the exact %s family id." % String(family))
    _expect(source.contains("ORGANIC_ACTION_REVIEW_SEQUENCE"), "The action review must keep one explicit deterministic eight-state sequence.")
    for action in REVIEW_SEQUENCE:
        _expect(source.contains("&\"%s\"" % String(action)), "The deterministic organic action review must include %s." % String(action))
    _expect(source.contains("await _start_presentation_review()"), "The organic fixture must reuse the neutral production gallery.")
    _expect(source.contains("organic_action_review_actor = candidate"), "The fixture must select the shipped OrganicEnemy3D actor staged by the gallery.")
    _expect(source.contains("get_node_or_null(\"AuthoredActorAnimation3D\")"), "The fixture must use the production authored-animation bridge.")
    _expect(source.contains("organic_action_review_presentation.process_mode = Node.PROCESS_MODE_ALWAYS"), "The paused gallery must keep the organic runtime bridge processing.")
    _expect(source.contains("organic_action_review_animation.process_mode = Node.PROCESS_MODE_ALWAYS"), "The paused gallery must keep the imported AnimationPlayer processing.")
    _expect(source.contains("review_key >= KEY_1 and review_key <= KEY_8"), "The gallery must expose deterministic direct selection for all eight organic states.")
    _expect(source.contains("organic_action_review_manual_hold = true"), "Direct organic state selection must hold the requested state.")
    _expect(source.contains("1-8 HOLD STATE"), "The gallery label must disclose its held direct-state controls.")
    _expect(source.contains("SPACE AUTO"), "The gallery label must disclose how to resume automatic cycling.")
    _expect(source.contains("organic_action_review_actor.set_physics_process(false)"), "The fixture must disable organic actor physics.")
    _expect(source.contains("player.input_enabled = false"), "The fixture must keep player input disabled.")
    _expect(source.contains("if organic_action_review_active:\n\t\treturn false"), "The release save gate must reject organic action-review state.")
    _expect(source.contains("get_signal_connection_list(signal_name)"), "The fixture must explicitly isolate the disposable actor's outward signals.")
    _expect(source.contains("callback.get_object() == organic_action_review_presentation"), "Signal isolation must preserve the authored runtime bridge.")
    _expect(source.contains("organic_action_review_actor._attack_target(organic_action_review_target)"), "Attack review must use the production attack method.")
    _expect(source.contains("organic_action_review_actor.pending_attack_target = null"), "The inert review attack must be cleared before it can resolve damage.")
    _expect(source.contains("organic_action_review_actor.apply_damage(maxf(1.0"), "Hit review must use bounded real actor damage.")
    _expect(source.contains("organic_action_review_actor.apply_damage(organic_action_review_actor.maximum_health * 2.0, null)"), "Death review must use the production lethal method.")
    _expect(source.contains("ACTOR-OWNED DEATH PRESENTATION + AUTHORED DEATH CLIP"), "Death must expose both the actor-owned mortality read and authored clip.")
    _expect(source.contains("NO INPUT / PHYSICS / ECOLOGY / SAVE"), "The live label must disclose every disabled side-effect lane.")


func _test_family_asset_clip_contracts() -> void:
    for family in ORGANIC_FAMILIES:
        var asset_path := "res://assets/%s/%s.gltf" % [String(family), String(family)]
        var asset_file := FileAccess.open(asset_path, FileAccess.READ)
        _expect(asset_file != null, "The %s action-review family must retain its shipped glTF." % String(family))
        if asset_file == null:
            continue
        var parsed: Variant = JSON.parse_string(asset_file.get_as_text())
        _expect(parsed is Dictionary, "The %s action-review glTF must remain valid JSON." % String(family))
        if not (parsed is Dictionary):
            continue
        var clip_names: Array[StringName] = []
        for raw_animation in (parsed as Dictionary).get("animations", []):
            var animation_data := raw_animation as Dictionary
            clip_names.append(StringName(str(animation_data.get("name", ""))))
        for action in REVIEW_SEQUENCE:
            _expect(action in clip_names, "The %s authored package must retain the %s clip used by live review." % [String(family), String(action)])


func _test_live_actor_action_contract() -> void:
    # Exercise the same presentation decorator used by the production action
    # gallery. Source-only fixture tests previously missed generic runtime
    # anatomy that detached from the imported action hierarchy entirely.
    var presentation_feedback := PRESENTATION_FEEDBACK_SCRIPT.new()
    presentation_feedback.name = "OrganicActionReviewPresentationFeedback"
    root.add_child(presentation_feedback)
    await process_frame
    presentation_feedback.set_process(false)

    for family in ORGANIC_FAMILIES:
        await _test_family_live_action_contract(family)

    presentation_feedback.queue_free()
    await process_frame


func _test_family_live_action_contract(family: StringName) -> void:
    var family_label := String(family).capitalize()
    var actor := ENEMY_SCENE.instantiate() as OrganicEnemy3D
    _expect(actor != null, "%s action review must instantiate the shipped OrganicEnemy3D scene." % family_label)
    if actor == null:
        return
    actor.configure(family, null, null)
    root.add_child(actor)
    actor.global_position = Vector3.ZERO
    actor.collision_layer = 0
    actor.collision_mask = 0

    var presentation := AuthoredActorAnimation3D.new()
    presentation.name = "AuthoredActorAnimation3D"
    presentation.configure(actor)
    actor.add_child(presentation)
    # PresentationFeedback3D discovers newly staged actors through a deferred
    # callback. Two real frames guarantee that the exact production decorator
    # has installed its stable source-owned socket before assertions begin.
    await process_frame
    await process_frame
    actor.set_process(false)
    actor.set_physics_process(false)
    presentation.set_process(false)
    var procedural_animator := actor.get_node_or_null("ProceduralAnimator3D")
    if procedural_animator != null:
        procedural_animator.set_process(false)

    _expect(actor is OrganicEnemyTiered3D, "%s must retain the shipped tier-aware organic runtime actor." % family_label)
    _expect(presentation.model_root == actor.get_node_or_null("OrganicModel"), "%s runtime bridge must animate the actor's real OrganicModel hierarchy." % family_label)
    _expect(presentation.animation_player != null, "%s must expose its imported AnimationPlayer at runtime." % family_label)
    if presentation.animation_player == null:
        actor.queue_free()
        await process_frame
        return
    for action in REVIEW_SEQUENCE:
        _expect(_has_clip(presentation.animation_player, action), "%s live AnimationPlayer must retain %s." % [family_label, String(action)])

    _assert_family_overlay_hierarchy_contract(actor, family)
    if family == &"skitterling":
        await _assert_skitterling_authored_anatomy(actor, presentation)

    var inert_target := Node3D.new()
    inert_target.name = "OrganicActionReviewInertTarget_%s" % String(family)
    root.add_child(inert_target)
    var attack_events := [0]
    var health_events := [0]
    var death_events := [0]
    actor.attack_started.connect(func(_enemy: OrganicEnemy3D, _target: Node) -> void: attack_events[0] += 1)
    actor.health_changed.connect(func(_enemy: OrganicEnemy3D, _current: float, _maximum: float) -> void: health_events[0] += 1)
    actor.killed.connect(func(_enemy: OrganicEnemy3D, _killer: Node) -> void: death_events[0] += 1)

    # Damage is established once and deliberately carried through every living
    # action. This catches review implementations that rebuild, hide or detach
    # the wound whenever the primary authored clip changes.
    presentation._last_health = actor.current_health
    var pristine_health := actor.current_health
    actor.apply_damage(maxf(1.0, actor.maximum_health * 0.12), null)
    var persistent_damage_root := actor.get_node_or_null("OrganicDamagePresentation") as Node3D
    _expect(actor.is_alive() and actor.current_health < pristine_health, "%s must enter the persistent damaged state without a lethal transition." % family_label)
    _expect(health_events[0] == 1, "%s persistent damage setup must emit one real health change." % family_label)
    _expect(persistent_damage_root != null, "%s must retain one actor-owned damage presentation root." % family_label)

    for action in REVIEW_SEQUENCE:
        _prepare_living_action(actor, presentation)
        match action:
            &"Idle":
                presentation._select_loop_clip()
            &"Walk":
                actor.velocity = Vector3(0.0, 0.0, -actor.move_speed)
                actor._set_state(&"hunting")
                presentation._select_loop_clip()
            &"Attack":
                actor._attack_target(inert_target)
                _expect(attack_events[0] == 1, "%s Attack must emit the real attack_started signal exactly once." % family_label)
                _expect(actor.pending_attack_target == inert_target and actor.attack_windup_remaining > 0.0, "%s Attack must create its real bounded wind-up." % family_label)
                actor.pending_attack_target = null
                actor.attack_windup_remaining = 0.0
            &"Hit":
                presentation._last_health = actor.current_health
                var health_before_hit := actor.current_health
                actor.apply_damage(maxf(1.0, actor.maximum_health * 0.03), null)
                _expect(actor.current_health < health_before_hit and actor.is_alive(), "%s Hit must apply a second bounded real wound without killing the actor." % family_label)
            &"Feed":
                actor.set_meta(&"enemy_behaviour", &"feed")
                actor._set_state(&"feeding")
                presentation._select_loop_clip()
            &"Nest":
                actor.set_meta(&"enemy_behaviour", &"guard_nest")
                actor._set_state(&"nest_guard")
                presentation._select_loop_clip()
            &"Retreat":
                actor.set_meta(&"enemy_behaviour", &"retreat")
                actor.velocity = Vector3(0.0, 0.0, actor.move_speed)
                actor._set_state(&"retreating")
                presentation._select_loop_clip()
            &"Death":
                _expect(actor.is_alive() and death_events[0] == 0, "%s must remain alive until the Death review state begins." % family_label)
                presentation._last_health = actor.current_health
                actor.apply_damage(actor.maximum_health * 2.0, null)

        var death_expected := action == &"Death"
        _expect(actor.is_alive() != death_expected, "%s %s must %s the only lethal transition in the sequence." % [family_label, String(action), "be" if death_expected else "precede"])
        _expect(death_events[0] == (1 if death_expected else 0), "%s %s must keep killed emission bounded to Death only." % [family_label, String(action)])
        _expect(actor.current_health < actor.maximum_health, "%s %s must preserve the established damage state." % [family_label, String(action)])
        _expect(actor.get_node_or_null("OrganicDamagePresentation") == persistent_damage_root, "%s %s must retain the same persistent damage presentation instance." % [family_label, String(action)])
        _expect(_clip_matches(presentation.active_clip, action), "%s real %s state must select its authored clip." % [family_label, String(action)])
        await _assert_family_action_overlay_contract(actor, presentation, family, action)

    _expect(health_events[0] == 3, "%s review must emit exactly persistent-damage, Hit and lethal health changes." % family_label)
    _expect(attack_events[0] == 1 and not inert_target.has_method(&"apply_damage"), "%s isolated Attack review must remain exactly-once and non-damaging." % family_label)
    _expect(not actor.is_physics_processing(), "%s dead review actor must remain physics-disabled so it cannot queue-free." % family_label)
    inert_target.queue_free()
    actor.queue_free()
    await process_frame


func _prepare_living_action(actor: OrganicEnemy3D, presentation: AuthoredActorAnimation3D) -> void:
    actor.attack_cooldown = 0.0
    actor.attack_windup_remaining = 0.0
    actor.pending_attack_target = null
    actor.velocity = Vector3.ZERO
    if actor.has_meta(&"enemy_behaviour"):
        actor.remove_meta(&"enemy_behaviour")
    actor._set_state(&"lurking")
    actor._refresh_damage_presentation()
    actor._refresh_death_presentation()
    presentation.one_shot_remaining = 0.0
    presentation._last_health = actor.current_health
    presentation._last_loop_key = &""
    if presentation.animation_player != null:
        presentation.animation_player.stop()


func _has_clip(player: AnimationPlayer, requested: StringName) -> bool:
    if player.has_animation(requested):
        return true
    for candidate in player.get_animation_list():
        if String(candidate).ends_with("/" + String(requested)) or String(candidate).ends_with(String(requested)):
            return true
    return false


func _resolve_clip_name(player: AnimationPlayer, requested: StringName) -> StringName:
    if player.has_animation(requested):
        return requested
    for candidate in player.get_animation_list():
        if String(candidate).ends_with("/" + String(requested)) or String(candidate).ends_with(String(requested)):
            return candidate
    return &""


func _clip_matches(actual: StringName, expected: StringName) -> bool:
    return actual == expected or String(actual).ends_with("/" + String(expected)) or String(actual).ends_with(String(expected))


func _assert_family_overlay_hierarchy_contract(actor: OrganicEnemy3D, family: StringName) -> void:
    var family_label := String(family).capitalize()
    var model_root := actor.get_node_or_null("OrganicModel") as Node3D
    _expect(model_root != null, "%s must retain one OrganicModel runtime root." % family_label)
    if model_root == null:
        return
    var imported_models := model_root.find_children("ImportedAuthoredModel", "Node3D", true, false)
    _expect(imported_models.size() == 1, "%s must retain exactly one intact ImportedAuthoredModel hierarchy." % family_label)
    var imported_model := imported_models[0] as Node3D if imported_models.size() == 1 else null
    var authored_torso := imported_model.find_child("Torso", true, false) as Node3D if imported_model != null else null
    _expect(authored_torso != null, "%s imported package must expose the stable authored Torso attachment socket." % family_label)

    var aesthetic_sockets := actor.find_children("AestheticDetails", "Node3D", true, false)
    _expect(aesthetic_sockets.size() == 1, "%s must expose exactly one stable AestheticDetails socket." % family_label)
    var aesthetic_details := model_root.get_node_or_null("AestheticDetails") as Node3D
    _expect(aesthetic_details != null, "%s AestheticDetails must remain a direct OrganicModel child." % family_label)
    if aesthetic_details != null:
        _expect(str(aesthetic_details.get_meta(&"authored_anatomy_policy", "")) == "source_owned_organic_family", "%s AestheticDetails must declare the shared source-owned organic-family policy." % family_label)
        _expect(aesthetic_details.find_children("*", "MeshInstance3D", true, false).is_empty(), "%s AestheticDetails must remain meshless; anatomy belongs to its authored package." % family_label)

    if authored_torso == null:
        return
    for raw_overlay_name in OVERLAY_ANCHORS:
        var overlay_name := StringName(raw_overlay_name)
        var overlay_root := _overlay_root(actor, model_root, overlay_name)
        var anchor_name := StringName(OVERLAY_ANCHORS[overlay_name])
        _expect(overlay_root != null, "%s must retain the %s sibling overlay." % [family_label, String(overlay_name)])
        if overlay_root == null:
            continue
        _expect(overlay_root.get_parent() == (model_root if overlay_name == &"TierSilhouette" else actor), "%s %s must stay outside the imported package as a material-safe sibling overlay." % [family_label, String(overlay_name)])
        _expect(str(overlay_root.get_meta(&"attachment_mode", "")) == "authored_torso_remote", "%s %s must use the exact authored_torso_remote attachment mode with no fallback." % [family_label, String(overlay_name)])
        _expect(not str(overlay_root.get_meta(&"attachment_mode", "")).contains("fallback"), "%s %s must never accept a degraded scale-only fallback." % [family_label, String(overlay_name)])
        _expect(_overlay_has_exact_remote_anchor(authored_torso, overlay_root, anchor_name), "%s %s must be driven by the stable %s RemoteTransform3D under authored Torso." % [family_label, String(overlay_name), String(anchor_name)])

    for legacy_anchor_name in ["SkitterlingTierAttachment", "SkitterlingDamageAttachment", "SkitterlingDeathAttachment"]:
        _expect(actor.find_child(legacy_anchor_name, true, false) == null, "%s must not retain legacy family-specific attachment %s." % [family_label, legacy_anchor_name])

    var tier_root := model_root.get_node_or_null("TierSilhouette") as Node3D
    var death_root := actor.get_node_or_null("OrganicDeathPresentation") as Node3D
    if tier_root != null:
        _expect(str(tier_root.get_meta(&"presentation_profile", "")) == "compact_authored_focal_signal", "%s tier layer must declare the compact authored focal-signal profile." % family_label)
        _expect(not _has_forbidden_named_descendant(tier_root, FORBIDDEN_GENERIC_TIER_NAME_TOKENS), "%s tier layer must not rebuild the generic seam, cage or rod vocabulary." % family_label)
        _expect(_tier_geometry_is_compact(tier_root, authored_torso), "%s tier layer must stay shallow, torso-bound and free of vertical rods or broad cages." % family_label)
    if death_root != null:
        _expect(not _has_forbidden_named_descendant(death_root, FORBIDDEN_GENERIC_DEATH_NAME_TOKENS), "%s death presentation must not duplicate the generic runtime corpse nodes." % family_label)


func _assert_skitterling_authored_anatomy(actor: OrganicEnemy3D, presentation: AuthoredActorAnimation3D) -> void:
    var sensory_fans: Array[MeshInstance3D] = []
    var sensory_ribs: Array[MeshInstance3D] = []
    for index in range(4):
        var fan := actor.find_child("SkitterlingSensoryFan%d" % index, true, false) as MeshInstance3D
        var rib := actor.find_child("SkitterlingSensoryRib%d" % index, true, false) as MeshInstance3D
        _expect(fan != null and rib != null and fan.get_parent().name == "Torso" and rib.get_parent().name == "Torso", "The live Skitterling sensory pair %d must remain attached to its authored Torso." % index)
        if fan != null:
            sensory_fans.append(fan)
        if rib != null:
            sensory_ribs.append(rib)
    _expect(sensory_fans.size() == 4 and sensory_ribs.size() == 4, "The live Skitterling must expose exactly four compact sensory fan/rib pairs.")
    if presentation.animation_player == null:
        return
    for action in REVIEW_SEQUENCE:
        var resolved_action := _resolve_clip_name(presentation.animation_player, action)
        if resolved_action == &"":
            continue
        var action_clip := presentation.animation_player.get_animation(resolved_action)
        if action_clip == null:
            continue
        presentation.animation_player.play(resolved_action)
        for sample_fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
            presentation.animation_player.seek(action_clip.length * sample_fraction, true)
            await process_frame
            for fan in sensory_fans:
                var fan_bounds := fan.transform * fan.get_aabb()
                var fan_center := fan_bounds.get_center()
                _expect(fan_bounds.size.y <= 0.075 and fan_bounds.end.y <= 0.70, "Skitterling %s at %.2f must keep %s below the shell with no towering vertical extent." % [String(action), sample_fraction, fan.name])
                _expect(absf(fan_center.x) >= 0.34 and absf(fan_center.x) <= 0.44 and fan_center.y >= 0.56 and fan_center.y <= 0.66 and fan_center.z >= -0.34 and fan_center.z <= 0.02, "Skitterling %s at %.2f must keep %s centered on the front/mid torso flank." % [String(action), sample_fraction, fan.name])
                _expect(absf(fan.basis.x.y) <= 0.0002, "Skitterling %s at %.2f must not roll %s into an edge-on vertical screen bar." % [String(action), sample_fraction, fan.name])
            for rib in sensory_ribs:
                var rib_bounds := rib.transform * rib.get_aabb()
                var rib_center := rib_bounds.get_center()
                _expect(rib_bounds.size.y <= 0.04 and rib_bounds.end.y <= 0.64, "Skitterling %s at %.2f must keep %s as a flat flank tie." % [String(action), sample_fraction, rib.name])
                _expect(absf(rib_center.x) >= 0.28 and absf(rib_center.x) <= 0.36 and rib_center.y >= 0.54 and rib_center.y <= 0.63 and rib_center.z >= -0.34 and rib_center.z <= 0.02, "Skitterling %s at %.2f must keep %s attached beneath its matching side vane." % [String(action), sample_fraction, rib.name])
    presentation.animation_player.stop()


func _assert_family_action_overlay_contract(
        actor: OrganicEnemy3D,
        presentation: AuthoredActorAnimation3D,
        family: StringName,
        action: StringName
    ) -> void:
    var family_label := String(family).capitalize()
    if presentation.animation_player == null:
        _expect(false, "%s %s overlay validation requires the imported AnimationPlayer." % [family_label, String(action)])
        return
    var clip_name := _resolve_clip_name(presentation.animation_player, action)
    var clip := presentation.animation_player.get_animation(clip_name) if clip_name != &"" else null
    _expect(clip != null, "%s %s overlay validation requires its authored clip." % [family_label, String(action)])
    if clip == null:
        return
    presentation.animation_player.play(clip_name)
    for sample_fraction in [0.0, 0.25, 0.5, 0.75, 1.0]:
        presentation.animation_player.seek(clip.length * sample_fraction, true)
        # RemoteTransform3D updates after the imported Torso receives its
        # sampled action transform. One real frame mirrors live gallery order
        # and catches roots that only matched at construction time.
        await process_frame
        _assert_family_overlay_sample(actor, family, action, sample_fraction)


func _assert_family_overlay_sample(actor: OrganicEnemy3D, family: StringName, action: StringName, sample_fraction: float) -> void:
    var family_label := String(family).capitalize()
    var sample_label := "%s %s at %.2f" % [family_label, String(action), sample_fraction]
    var model_root := actor.get_node_or_null("OrganicModel") as Node3D
    var imported_model := model_root.find_child("ImportedAuthoredModel", true, false) as Node3D if model_root != null else null
    var authored_torso := imported_model.find_child("Torso", true, false) as Node3D if imported_model != null else null
    var tier_root := model_root.get_node_or_null("TierSilhouette") as Node3D if model_root != null else null
    var damage_root := actor.get_node_or_null("OrganicDamagePresentation") as Node3D
    var death_root := actor.get_node_or_null("OrganicDeathPresentation") as Node3D
    if authored_torso == null or tier_root == null or damage_root == null or death_root == null:
        _expect(false, "%s must retain authored Torso and all three runtime sibling overlays." % sample_label)
        return
    _expect(_transform_matches(tier_root.global_transform, authored_torso.global_transform), "%s TierSilhouette must exactly track authored Torso position, rotation and scale." % sample_label)
    _expect(_transform_matches(damage_root.global_transform, authored_torso.global_transform), "%s damage overlay must exactly track authored Torso position, rotation and scale." % sample_label)
    _expect(_transform_matches(death_root.global_transform, authored_torso.global_transform), "%s death overlay must exactly track authored Torso position, rotation and scale." % sample_label)

    var death_expected := action == &"Death"
    _expect(tier_root.is_visible_in_tree(), "%s must retain its compact tier communication layer." % sample_label)
    _expect(damage_root.is_visible_in_tree() == not death_expected, "%s must keep persistent damage visible through every living clip and hide it only for Death." % sample_label)
    _expect(death_root.is_visible_in_tree() == death_expected, "%s must expose the authored-body death response only during Death." % sample_label)
    _expect(actor.is_alive() == not death_expected, "%s must keep the lethal state exclusive to Death." % sample_label)

    if family == &"skitterling" and action == &"Hit":
        var authored_bounds := _visible_mesh_bounds(imported_model)
        _expect(authored_bounds.size.length_squared() > 0.0 and _skitterling_hit_wound_is_shallow(damage_root, authored_bounds), "%s must preserve the accepted shallow, non-emissive shell lesion." % sample_label)


func _overlay_root(actor: OrganicEnemy3D, model_root: Node3D, overlay_name: StringName) -> Node3D:
    if overlay_name == &"TierSilhouette":
        return model_root.get_node_or_null(NodePath(String(overlay_name))) as Node3D
    return actor.get_node_or_null(NodePath(String(overlay_name))) as Node3D


func _overlay_has_exact_remote_anchor(authored_torso: Node3D, overlay_root: Node3D, anchor_name: StringName) -> bool:
    var anchor := authored_torso.get_node_or_null(NodePath(String(anchor_name))) as RemoteTransform3D
    if (
        anchor == null
        or anchor.get_parent() != authored_torso
        or not anchor.update_position
        or not anchor.update_rotation
        or not anchor.update_scale
        or not anchor.use_global_coordinates
    ):
        return false
    return anchor.get_node_or_null(anchor.remote_path) == overlay_root


func _has_forbidden_named_descendant(root_node: Node, forbidden_tokens: Array[String]) -> bool:
    for descendant in root_node.find_children("*", "", true, false):
        var lowered_name := String(descendant.name).to_lower()
        for token in forbidden_tokens:
            if lowered_name.contains(token):
                return true
    return false


func _tier_geometry_is_compact(tier_root: Node3D, authored_torso: Node3D) -> bool:
    var tier_meshes := tier_root.find_children("*", "MeshInstance3D", true, false)
    if tier_meshes.is_empty() or tier_meshes.size() > 12:
        return false
    if tier_root.find_children("TierDorsalPlate00", "Node3D", true, false).size() != 1:
        return false
    if tier_root.find_children("TierVascularChannel*", "MeshInstance3D", true, false).size() != 2:
        return false
    var crown_socket := tier_root.find_child("TierCrownRing", true, false) as Node3D
    if crown_socket == null or crown_socket is MeshInstance3D:
        return false
    if str(crown_socket.get_meta(&"mesh_policy", "")) != "meshless_signal_socket":
        return false
    var crown_meshes := crown_socket.find_children("*", "MeshInstance3D", true, false)
    if crown_meshes.size() < 1 or crown_meshes.size() > 4:
        return false
    var crest_meshes := tier_root.find_children("TierCrest_*", "MeshInstance3D", true, false)
    if crest_meshes.size() != 1:
        return false
    var crest := crest_meshes[0] as MeshInstance3D
    if crest == null or not (crest.mesh is SphereMesh) or crest.scale.y > minf(crest.scale.x, crest.scale.z) * 0.30:
        return false
    for raw_channel in tier_root.find_children("TierVascularChannel*", "MeshInstance3D", true, false):
        var channel := raw_channel as MeshInstance3D
        if channel == null or channel.mesh == null:
            return false
        var channel_bounds := channel.transform * channel.get_aabb()
        if channel_bounds.size.y > maxf(channel_bounds.size.x, channel_bounds.size.z) * 0.36:
            return false
    for raw_mesh in tier_meshes:
        var mesh_instance := raw_mesh as MeshInstance3D
        if mesh_instance != null and mesh_instance.mesh is TorusMesh:
            return false

    var torso_bounds := _visible_mesh_bounds(authored_torso)
    var tier_bounds := _visible_mesh_bounds(tier_root)
    if torso_bounds.size.length_squared() <= 0.000001 or tier_bounds.size.length_squared() <= 0.000001:
        return false
    if not tier_bounds.intersects(torso_bounds):
        return false
    var torso_horizontal := maxf(torso_bounds.size.x, torso_bounds.size.z)
    var tier_horizontal := maxf(tier_bounds.size.x, tier_bounds.size.z)
    return tier_horizontal <= torso_horizontal * 0.82 and tier_bounds.size.y <= torso_bounds.size.y * 0.62 + 0.04


func _skitterling_hit_wound_is_shallow(damage_root: Node3D, authored_bounds: AABB) -> bool:
    var lesion_socket := damage_root.get_node_or_null("OrganicDamageScar00") as Node3D
    if lesion_socket == null:
        return false
    if str(lesion_socket.get_meta(&"damage_profile", "")) != "shallow_authored_torso_lesion":
        return false
    if StringName(str(damage_root.get_meta(&"release_material_family", &""))) != &"chitin":
        return false
    var lesion_rim := lesion_socket.get_node_or_null("OrganicDamageLesion00Rim") as MeshInstance3D
    var lesion_core := lesion_socket.get_node_or_null("OrganicDamageLesion00Core") as MeshInstance3D
    var cracks := lesion_socket.find_children("OrganicDamageLesion00Crack*", "MeshInstance3D", true, false)
    var wound_meshes := lesion_socket.find_children("*", "MeshInstance3D", true, false)
    if lesion_rim == null or lesion_core == null or cracks.size() != 3 or wound_meshes.size() != 5:
        return false

    var wound_bounds := _visible_mesh_bounds(lesion_socket)
    var shallow_limit := 0.055
    var horizontal_long := maxf(wound_bounds.size.x, wound_bounds.size.z)
    var horizontal_short := minf(wound_bounds.size.x, wound_bounds.size.z)
    var shell_long := maxf(authored_bounds.size.x, authored_bounds.size.z)
    if (
        wound_bounds.size.y > shallow_limit
        or wound_bounds.size.y > authored_bounds.size.y * 0.07
        or wound_bounds.end.y > authored_bounds.end.y + 0.01
        or horizontal_long > 0.22
        or horizontal_long > shell_long * 0.22
        or horizontal_short <= 0.0
        or horizontal_long / horizontal_short > 2.4
        or wound_bounds.size.y / horizontal_long > 0.22
    ):
        return false

    for raw_mesh in wound_meshes:
        var mesh := raw_mesh as MeshInstance3D
        if mesh == null or mesh.mesh == null or not mesh.is_visible_in_tree():
            return false
        var material := mesh.material_override as StandardMaterial3D
        if material == null:
            return false
        if material.emission_enabled and material.emission_energy_multiplier > 0.08:
            return false
        if material.metallic > 0.05 or material.roughness < 0.78:
            return false

    for raw_crack in cracks:
        var crack := raw_crack as MeshInstance3D
        if crack == null:
            return false
        var crack_bounds := crack.global_transform * crack.get_aabb()
        var crack_longest := maxf(crack_bounds.size.x, maxf(crack_bounds.size.y, crack_bounds.size.z))
        if crack_longest > 0.065 or crack_bounds.size.y > 0.035:
            return false
        if not wound_bounds.grow(0.01).intersects(crack_bounds):
            return false
    return true


func _transform_matches(left: Transform3D, right: Transform3D) -> bool:
    if left.origin.distance_to(right.origin) > 0.0002:
        return false
    var left_axes := [left.basis.x, left.basis.y, left.basis.z]
    var right_axes := [right.basis.x, right.basis.y, right.basis.z]
    for axis in range(3):
        if left_axes[axis].distance_to(right_axes[axis]) > 0.0002:
            return false
    return true


func _bounds_enclosed_by(inner: AABB, outer: AABB) -> bool:
    return (
        inner.position.x >= outer.position.x
        and inner.position.y >= outer.position.y
        and inner.position.z >= outer.position.z
        and inner.end.x <= outer.end.x
        and inner.end.y <= outer.end.y
        and inner.end.z <= outer.end.z
    )


func _visible_mesh_bounds(root_node: Node3D) -> AABB:
    var combined := AABB()
    var has_bounds := false
    if root_node == null:
        return combined
    for raw_mesh in root_node.find_children("*", "MeshInstance3D", true, false):
        var mesh := raw_mesh as MeshInstance3D
        if mesh == null or mesh.mesh == null or not mesh.is_visible_in_tree():
            continue
        var bounds := mesh.global_transform * mesh.get_aabb()
        combined = bounds if not has_bounds else combined.merge(bounds)
        has_bounds = true
    return combined


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
