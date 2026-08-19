class_name ObjectiveGuidance3D
extends Node3D

## A world-space objective cue for the first session. It marks a real physical
## target and lays a restrained route trail through the same world rather than
## resolving objectives in a detached map or tutorial overlay.

const ROUTE_DOT_COUNT: int = 9

var player: Node3D
var target: Node3D
var target_title: String = ""
var interaction_text: String = ""
var elapsed: float = 0.0
var marker_root: Node3D
var marker_label: Label3D
var route_dots: Array[MeshInstance3D] = []
var guide_material: StandardMaterial3D
var guide_light: OmniLight3D
var active_color: Color = Color("f2b365")


func configure(next_player: Node3D) -> void:
    player = next_player


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _build_visuals()
    clear_guidance()


func _process(delta: float) -> void:
    elapsed += delta
    if target == null or not is_instance_valid(target) or player == null or not is_instance_valid(player):
        clear_guidance()
        return

    marker_root.visible = true
    marker_root.global_position = target.global_position
    marker_root.rotation.y = elapsed * 0.42
    var pulse := 0.92 + sin(elapsed * 3.4) * 0.12
    marker_root.scale = Vector3.ONE * pulse
    marker_label.text = "%s\n%s" % [target_title, interaction_text]
    marker_label.position.y = 3.45 + sin(elapsed * 2.1) * 0.12

    var origin := player.global_position
    var destination := target.global_position
    var distance := origin.distance_to(destination)
    var show_route := distance > 3.2
    for index in range(route_dots.size()):
        var dot := route_dots[index]
        dot.visible = show_route
        if not show_route:
            continue
        var fraction := float(index + 1) / float(ROUTE_DOT_COUNT + 1)
        var position_on_route := origin.lerp(destination, fraction)
        position_on_route.y = 0.16 + sin(elapsed * 4.0 - float(index) * 0.55) * 0.045
        dot.global_position = position_on_route
        var dot_pulse := 0.68 + 0.22 * sin(elapsed * 4.0 - float(index) * 0.62)
        dot.scale = Vector3.ONE * dot_pulse


func set_guidance(
        next_target: Node3D,
        next_title: String,
        next_interaction: String,
        color: Color = Color("f2b365")
    ) -> void:
    target = next_target
    target_title = next_title
    interaction_text = next_interaction
    active_color = color
    _apply_color()
    if marker_root != null:
        marker_root.visible = target != null


func clear_guidance() -> void:
    target = null
    target_title = ""
    interaction_text = ""
    if marker_root != null:
        marker_root.visible = false
    for dot in route_dots:
        dot.visible = false


func is_guiding() -> bool:
    return target != null and is_instance_valid(target)


func distance_to_target() -> float:
    if not is_guiding() or player == null:
        return 0.0
    return player.global_position.distance_to(target.global_position)


func direction_to_target() -> String:
    if not is_guiding() or player == null:
        return ""
    var offset := target.global_position - player.global_position
    if absf(offset.x) > absf(offset.z):
        return "EAST" if offset.x > 0.0 else "WEST"
    return "SOUTH" if offset.z > 0.0 else "NORTH"


func route_summary() -> String:
    if not is_guiding():
        return ""
    return "%d m %s" % [int(round(distance_to_target())), direction_to_target()]


func _build_visuals() -> void:
    guide_material = ModelKit3D.material(active_color.darkened(0.55), 0.1, 0.32, active_color, 4.0)

    marker_root = Node3D.new()
    marker_root.name = "ObjectiveBeacon"
    add_child(marker_root)

    for index in range(8):
        var angle := TAU * float(index) / 8.0
        var position := Vector3(cos(angle) * 1.65, 0.12, sin(angle) * 1.65)
        var segment := ModelKit3D.add_box(
            marker_root,
            Vector3(0.72, 0.08, 0.16),
            position,
            guide_material,
            Vector3(0.0, -angle, 0.0),
            "BeaconRingSegment"
        )
        segment.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    var beam := ModelKit3D.add_cylinder(
        marker_root,
        0.055,
        2.7,
        Vector3(0.0, 1.45, 0.0),
        guide_material,
        Vector3.ZERO,
        "BeaconStem"
    )
    beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    var crown := ModelKit3D.add_sphere(
        marker_root,
        0.2,
        Vector3(0.0, 2.85, 0.0),
        guide_material,
        Vector3.ONE,
        "BeaconCrown"
    )
    crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

    guide_light = ModelKit3D.add_glow_light(marker_root, Vector3(0.0, 2.1, 0.0), active_color, 0.82, 5.5)

    marker_label = Label3D.new()
    marker_label.name = "ObjectiveLabel"
    marker_label.text = "OBJECTIVE"
    marker_label.position = Vector3(0.0, 3.45, 0.0)
    marker_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    marker_label.fixed_size = true
    marker_label.font_size = 38
    marker_label.outline_size = 9
    marker_label.modulate = Color("fff2d9")
    marker_label.outline_modulate = Color(0.015, 0.025, 0.03, 0.96)
    marker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    marker_root.add_child(marker_label)

    for index in range(ROUTE_DOT_COUNT):
        var dot := ModelKit3D.add_sphere(
            self,
            0.13,
            Vector3.ZERO,
            guide_material,
            Vector3(1.0, 0.28, 1.0),
            "RouteCue_%02d" % index
        )
        dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        dot.visible = false
        route_dots.append(dot)


func _apply_color() -> void:
    if guide_material != null:
        guide_material.albedo_color = active_color.darkened(0.55)
        guide_material.emission = active_color
    if guide_light != null:
        guide_light.light_color = active_color
