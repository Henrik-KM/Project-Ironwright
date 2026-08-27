class_name OrganicEnemyTiered3D
extends OrganicEnemyRelease3D

const SPECIES_TIERS: Dictionary = {
    &"skitterling": 1,
    &"razorhound": 2,
    &"roofleaper": 2,
    &"glassmoth": 2,
    &"veilstalker": 3,
    &"burrower": 3,
    &"sporecaster": 3,
    &"broodmass": 4,
    &"miremaw": 4,
    &"carrionbell": 4,
    &"rootweaver": 4,
    &"thornback": 2,
    &"ashmantle": 3,
    &"apex": 5,
}

const FALLBACK_TIER_CONFIGS: Dictionary = {
    1: {"display_name": "Feral", "intelligence_label": "primitive roaming", "behaviour_profile": "feral", "health_multiplier": 0.78, "damage_multiplier": 0.72, "speed_multiplier": 0.68, "detection_multiplier": 0.78},
    2: {"display_name": "Territorial", "intelligence_label": "nest defence and patrol", "behaviour_profile": "territorial", "health_multiplier": 0.94, "damage_multiplier": 0.9, "speed_multiplier": 0.9, "detection_multiplier": 0.96},
    3: {"display_name": "Predatory", "intelligence_label": "scouting, hunting and pack memory", "behaviour_profile": "predatory", "health_multiplier": 1.0, "damage_multiplier": 1.0, "speed_multiplier": 1.0, "detection_multiplier": 1.08},
    4: {"display_name": "Strategic", "intelligence_label": "route interception and priority targeting", "behaviour_profile": "strategic", "health_multiplier": 1.08, "damage_multiplier": 1.08, "speed_multiplier": 1.02, "detection_multiplier": 1.18},
    5: {"display_name": "Apex", "intelligence_label": "regional strategic predator", "behaviour_profile": "apex", "health_multiplier": 1.18, "damage_multiplier": 1.16, "speed_multiplier": 1.04, "detection_multiplier": 1.28},
}

var enemy_tier: int = 1
var tier_profile: StringName = &"feral"
var tier_display_name: String = "Feral"
var tier_intelligence_label: String = "primitive roaming"
var tier_config_data: Dictionary = {}
var _tier_base_species: StringName = &""
var _tier_base_stats: Dictionary = {}
var _tier_visual_root: Node3D
var _requested_ecology_directive: StringName = &""


func _ready() -> void:
    super._ready()
    if _requested_ecology_directive != &"":
        ecology_directive = _resolve_directive_for_tier(_requested_ecology_directive)
        _choose_next_ecological_behaviour(true)


func configure(next_species: StringName, next_player: Node3D, next_heartforge: Node3D) -> void:
    _requested_ecology_directive = &""
    super.configure(next_species, next_player, next_heartforge)
    var canonical_tier := clampi(int(SPECIES_TIERS.get(next_species, 1)), 1, 5)
    var fallback: Variant = FALLBACK_TIER_CONFIGS.get(canonical_tier, FALLBACK_TIER_CONFIGS[1])
    configure_tier(canonical_tier, (fallback as Dictionary).duplicate(true), true)


func configure_tier(tier: int, config: Dictionary, recapture_base: bool = false) -> void:
    var health_ratio := current_health / maxf(1.0, maximum_health)
    enemy_tier = clampi(tier, 1, 5)
    tier_config_data = config.duplicate(true)
    tier_profile = StringName(str(config.get("behaviour_profile", "feral")))
    tier_display_name = str(config.get("display_name", "Tier %d" % enemy_tier))
    tier_intelligence_label = str(config.get("intelligence_label", "unknown"))

    if recapture_base or _tier_base_stats.is_empty() or _tier_base_species != species:
        _tier_base_species = species
        _tier_base_stats = {
            "maximum_health": maximum_health,
            "attack_damage": attack_damage,
            "move_speed": move_speed,
            "detection_range": detection_range,
            "attack_range": attack_range,
            "attack_interval": attack_interval,
        }
    else:
        maximum_health = float(_tier_base_stats.get("maximum_health", maximum_health))
        attack_damage = float(_tier_base_stats.get("attack_damage", attack_damage))
        move_speed = float(_tier_base_stats.get("move_speed", move_speed))
        detection_range = float(_tier_base_stats.get("detection_range", detection_range))
        attack_range = float(_tier_base_stats.get("attack_range", attack_range))
        attack_interval = float(_tier_base_stats.get("attack_interval", attack_interval))

    maximum_health *= maxf(0.1, float(config.get("health_multiplier", 1.0)))
    attack_damage *= maxf(0.1, float(config.get("damage_multiplier", 1.0)))
    move_speed *= maxf(0.1, float(config.get("speed_multiplier", 1.0)))
    detection_range *= maxf(0.1, float(config.get("detection_multiplier", 1.0)))
    current_health = clampf(maximum_health * health_ratio, 0.0, maximum_health)
    set_meta(&"enemy_tier", enemy_tier)
    set_meta(&"tier_profile", String(tier_profile))
    ecology_directive = _resolve_directive_for_tier(ecology_directive)
    behaviour_clock = behaviour_duration
    if is_inside_tree():
        _refresh_visuals()
        _choose_next_ecological_behaviour(true)


func configure_ecology(home_position: Vector3, radius: float, directive: StringName = &"") -> void:
    _requested_ecology_directive = directive
    var expanded_radius := radius
    if enemy_tier == 1:
        expanded_radius = radius * 1.55
    elif enemy_tier == 2:
        expanded_radius = radius * 1.08
    elif enemy_tier >= 4:
        expanded_radius = radius * 1.28
    super.configure_ecology(home_position, expanded_radius, _resolve_directive_for_tier(directive))


func hear_noise(position: Vector3, radius: float, intensity: float, source_kind: StringName) -> void:
    if enemy_tier <= 1:
        return
    if enemy_tier == 2:
        if global_position.distance_to(position) > radius * 0.72 or intensity < 0.42:
            return
        super.hear_noise(position, radius * 0.72, intensity * 0.72, source_kind)
        return
    super.hear_noise(position, radius, intensity, source_kind)


func receive_pack_alert(position: Vector3, intensity: float) -> void:
    if enemy_tier < 2:
        return
    super.receive_pack_alert(position, intensity * (0.72 if enemy_tier == 2 else 1.0))


func _choose_target() -> Node3D:
    if _spatial_index == null or not is_instance_valid(_spatial_index):
        _resolve_spatial_index()

    var awareness := detection_range + aggression * (2.5 if enemy_tier <= 1 else 8.0 + float(enemy_tier) * 1.5)
    if ecology_directive == &"protect_nest":
        awareness *= 1.12
    elif ecology_directive == &"scout":
        awareness *= 1.17
    elif ecology_directive == &"hunt":
        awareness *= 1.28

    var candidates: Array[Node3D] = []
    if player_reference != null and is_instance_valid(player_reference) and _candidate_is_alive(player_reference):
        candidates.append(player_reference)

    if _spatial_index != null:
        for robot in _spatial_index.query_radius(&"friendly_robots", global_position, awareness):
            if _candidate_is_alive(robot):
                candidates.append(robot)
        if enemy_tier >= 2:
            for outpost in _spatial_index.query_radius(&"outposts", global_position, awareness + 3.0):
                if _candidate_is_alive(outpost):
                    candidates.append(outpost)
    else:
        for robot in get_tree().get_nodes_in_group(&"friendly_robots"):
            if robot is Node3D and _candidate_is_alive(robot as Node3D):
                candidates.append(robot as Node3D)
        if enemy_tier >= 2:
            for outpost in get_tree().get_nodes_in_group(&"outposts"):
                if outpost is Node3D and _candidate_is_alive(outpost as Node3D):
                    candidates.append(outpost as Node3D)

    if enemy_tier >= 4 and heartforge_reference != null and is_instance_valid(heartforge_reference):
        candidates.append(heartforge_reference)

    var best: Node3D
    var best_score := INF
    for candidate in candidates:
        if candidate == null or not is_instance_valid(candidate):
            continue
        var distance := global_position.distance_to(candidate.global_position)
        if distance > awareness:
            continue
        if not _target_allowed_by_territory(candidate.global_position):
            continue
        if not _has_line_of_sight(candidate):
            continue
        var score := distance * _tier_target_priority(candidate)
        if score < best_score:
            best = candidate
            best_score = score
    return best


func _choose_next_ecological_behaviour(force: bool) -> void:
    ecology_directive = _resolve_directive_for_tier(ecology_directive)
    super._choose_next_ecological_behaviour(force)
    if enemy_tier == 1:
        movement_reason = "Tier 1 organisms wander without a strategic objective and attack only prey they directly encounter."
    elif enemy_tier == 2:
        movement_reason = "Tier 2 organisms patrol and defend a physical brood territory."
    elif enemy_tier == 3:
        movement_reason = "Tier 3 organisms scout, remember prey and conduct purposeful hunts."
    elif enemy_tier == 4:
        movement_reason = "Tier 4 organisms intercept machine routes and prioritize vulnerable operational targets."
    else:
        movement_reason = "Tier 5 organisms act as regional apex threats and pressure critical infrastructure."


func _default_ecology_directive() -> StringName:
    return _resolve_directive_for_tier(&"")


func _hunting_waypoint() -> Vector3:
    if enemy_tier >= 4:
        var interest := _strategic_interest_target()
        if interest != null:
            var direction := interest.global_position - territory_origin
            direction.y = 0.0
            if direction.length_squared() > 0.1:
                var side := Vector3(direction.z, 0.0, -direction.x).normalized()
                var flank := side * (_deterministic_unit(behaviour_serial, 101 + enemy_tier) - 0.5) * (10.0 + float(enemy_tier) * 2.0)
                return interest.global_position + flank
    return super._hunting_waypoint()


func _prey_priority_multiplier(target: Node3D) -> float:
    var multiplier := super._prey_priority_multiplier(target)
    if enemy_tier <= 2:
        return multiplier
    if target is RobotUnit3D:
        var robot := target as RobotUnit3D
        if enemy_tier == 3 and robot.archetype in [&"salvager", &"scout"]:
            multiplier *= 0.76
        elif enemy_tier >= 4 and robot.archetype in [&"salvager", &"engineer"]:
            multiplier *= 0.52
        elif enemy_tier >= 4 and robot.archetype == &"scout":
            multiplier *= 0.68
    elif target is Outpost3D:
        multiplier *= 0.64 if enemy_tier >= 4 else 0.92
    elif target is Heartforge3D:
        multiplier *= 0.42 if enemy_tier >= 5 else 0.78
    elif target is Mechromancer3D:
        multiplier *= 0.68 if enemy_tier >= 3 else 0.9
    return multiplier


func _refresh_visuals() -> void:
    super._refresh_visuals()
    if _model_root == null:
        return
    _tier_visual_root = Node3D.new()
    _tier_visual_root.name = "TierSilhouette"
    _model_root.add_child(_tier_visual_root)
    var tier_colors := {
        1: Color("9e7046"),
        2: Color("d68a48"),
        3: Color("b55568"),
        4: Color("8a5fd1"),
        5: Color("e03759"),
    }
    var tier_color: Color = tier_colors.get(enemy_tier, Color("d68a48"))
    var tier_detail := Node3D.new()
    tier_detail.name = "TierHighDefinitionDetail"
    _tier_visual_root.add_child(tier_detail)
    var crest_material := ModelKit3D.material(tier_color.darkened(0.48), 0.05, 0.52, tier_color, 0.78 + float(enemy_tier) * 0.28)
    var channel_material := ModelKit3D.material(tier_color.darkened(0.28), 0.08, 0.42, tier_color, 0.72 + float(enemy_tier) * 0.22)
    var bone := ModelKit3D.material(Color("a69678"), 0.0, 0.76)

    # The tier read is carried by anatomy rather than a floating icon: a
    # compact dorsal series and paired vascular channels make population
    # pressure legible at the tactical camera without changing the actor's
    # collision or simulation state.
    # Tier anatomy is a restrained biological accent, not a second skeleton.
    # The previous dorsal plate series filled the close gallery with repeated
    # bars that read as a cage over the authored shell. Keep one short spine,
    # adding a paired cue only for strategic and apex tiers.
    var dorsal_count := 1 + int(enemy_tier >= 4)
    for index in range(dorsal_count):
        var dorsal_z := 0.0 if dorsal_count == 1 else (-0.24 if index == 0 else 0.24)
        var dorsal_y := 1.42 + float(enemy_tier) * 0.06
        ModelKit3D.add_capsule(
            tier_detail,
            0.032 + float(enemy_tier) * 0.006,
            0.30 + float(enemy_tier) * 0.05,
            Vector3(0.0, dorsal_y, dorsal_z),
            crest_material,
            Vector3(0.18 + float(index) * 0.12, 0.0, 0.0),
            "TierDorsalPlate%02d" % index
        )

    # A restrained oval seam gives every active tiered shell one continuous
    # biological edge treatment. It sits in the presentation layer only, so
    # the imported family meshes, collision, LOD and simulation remain intact.
    var surface_seam := ModelKit3D.add_torus(
        tier_detail,
        0.54 + float(enemy_tier) * 0.035,
        0.018 + float(enemy_tier) * 0.003,
        Vector3(0.0, 1.03 + float(enemy_tier) * 0.045, 0.04),
        channel_material,
        Vector3.ZERO,
        "OrganicSurfaceSeam",
        48,
        8
    )
    surface_seam.scale = Vector3(1.28, 0.62, 1.0)

    var channel_count := 1 + mini(int(enemy_tier / 2), 2)
    for side in [-1.0, 1.0]:
        var side_label := "L" if side < 0.0 else "R"
        for index in range(channel_count):
            var fraction := float(index) / float(maxi(1, channel_count - 1))
            var channel_z := lerpf(-0.58, 0.58, fraction)
            var channel_y := 0.91 + float(enemy_tier) * 0.045 + sin(fraction * PI) * 0.08
            ModelKit3D.add_capsule(
                tier_detail,
                0.014 + float(enemy_tier) * 0.003,
                0.25 + float(enemy_tier) * 0.045,
                Vector3(side * (0.28 + float(enemy_tier) * 0.045), channel_y, channel_z),
                channel_material,
                Vector3(PI * 0.5, 0.0, 0.0),
                "TierVascularChannel%s%02d" % [side_label, index]
            )

    var crown_ring := Node3D.new()
    crown_ring.name = "TierCrownRing"
    crown_ring.position = Vector3(0.0, 1.52 + float(enemy_tier) * 0.1, 0.0)
    tier_detail.add_child(crown_ring)
    var crown_count := 4 + enemy_tier
    for index in range(crown_count):
        var angle := TAU * float(index) / float(crown_count)
        ModelKit3D.add_sphere(
            crown_ring,
            0.034 + float(enemy_tier) * 0.007,
            Vector3(cos(angle) * (0.22 + float(enemy_tier) * 0.035), 0.0, sin(angle) * (0.22 + float(enemy_tier) * 0.035)),
            channel_material,
            Vector3(1.0, 0.66, 1.0),
            "TierCrownNode%02d" % index
        )

    # A few short crown spines give higher tiers a living silhouette cue. They
    # are deliberately shorter and sparser than the old vertical rods.
    var crest_count := 1 + mini(2, int((enemy_tier + 1) / 2))
    for index in range(crest_count):
        var z := -0.48 + float(index) * 0.48
        ModelKit3D.add_capsule(
            tier_detail,
            0.032 + float(enemy_tier) * 0.006,
            0.26 + float(enemy_tier) * 0.07,
            Vector3(0.0, 1.30 + float(enemy_tier) * 0.08, z),
            bone,
            Vector3(0.42 + float(index % 2) * 0.12, 0.0, 0.0),
            "TierCrest_%02d" % index
        )
    for index in range(enemy_tier - 1):
        var angle := TAU * float(index) / float(maxi(1, enemy_tier - 1))
        ModelKit3D.add_sphere(
            tier_detail,
            0.07 + float(enemy_tier) * 0.018,
            Vector3(cos(angle) * 0.48, 1.05 + float(enemy_tier) * 0.09, sin(angle) * 0.48),
            crest_material,
            Vector3.ONE,
            "TierSignal_%02d" % index
        )


func _resolve_directive_for_tier(requested: StringName) -> StringName:
    match enemy_tier:
        1:
            return &"roam"
        2:
            if requested in [&"protect_nest", &"patrol"]:
                return requested
            if requested == &"hunt" and species == &"razorhound":
                return &"hunt"
            return &"protect_nest" if behaviour_serial % 3 != 0 else &"patrol"
        3:
            if requested in [&"scout", &"hunt", &"protect_nest", &"patrol"]:
                return requested
            return &"scout" if behaviour_serial % 2 == 0 else &"hunt"
        4:
            if requested in [&"hunt", &"protect_nest", &"scout"]:
                return requested
            return &"hunt"
        5:
            if requested in [&"hunt", &"patrol"]:
                return requested
            return &"patrol" if behaviour_serial % 3 == 0 else &"hunt"
    return &"roam"


func _tier_target_priority(target: Node3D) -> float:
    var multiplier := _prey_priority_multiplier(target)
    if enemy_tier == 1:
        return 1.0
    if enemy_tier == 2 and target is Outpost3D:
        return 1.05
    return multiplier


func _candidate_is_alive(candidate: Node3D) -> bool:
    return not candidate.has_method(&"is_alive") or bool(candidate.call(&"is_alive"))


func _has_line_of_sight(target: Node3D) -> bool:
    if target == null or not is_instance_valid(target):
        return false
    var from := global_position + Vector3.UP * 0.65
    var to := target.global_position + Vector3.UP * 0.55
    var query := PhysicsRayQueryParameters3D.create(from, to)
    query.collision_mask = 1 | 2 | 4
    query.collide_with_areas = false
    query.collide_with_bodies = true
    query.exclude = [get_rid()]
    var hit := get_world_3d().direct_space_state.intersect_ray(query)
    if hit.is_empty():
        return true
    return hit.get("collider", null) == target


func _strategic_interest_target() -> Node3D:
    var best: Node3D
    var best_score := INF
    for node in get_tree().get_nodes_in_group(&"friendly_robots"):
        if not (node is RobotUnit3D) or not is_instance_valid(node):
            continue
        var robot := node as RobotUnit3D
        if not robot.is_alive():
            continue
        var priority := 1.0
        if robot.archetype in [&"salvager", &"engineer"]:
            priority = 0.5
        elif robot.archetype == &"scout":
            priority = 0.7
        var score := global_position.distance_to(robot.global_position) * priority
        if score < best_score:
            best = robot
            best_score = score
    for node in get_tree().get_nodes_in_group(&"outposts"):
        if not (node is Outpost3D) or not is_instance_valid(node):
            continue
        var outpost := node as Outpost3D
        if not outpost.is_alive():
            continue
        var score := global_position.distance_to(outpost.global_position) * 0.62
        if score < best_score:
            best = outpost
            best_score = score
    if enemy_tier >= 5 and heartforge_reference != null and is_instance_valid(heartforge_reference):
        var forge_score := global_position.distance_to(heartforge_reference.global_position) * 0.43
        if forge_score < best_score:
            best = heartforge_reference
    return best
