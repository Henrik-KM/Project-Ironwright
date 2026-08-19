class_name AestheticDirector3D
extends Node

## Coordinates the native presentation pass. Gameplay state remains owned by
## IronwrightWorld3D and its existing systems.

const SANCTUARY_DECORATOR := preload("res://scripts/presentation/sanctuary_decorator_3d.gd")
const URBAN_DECORATOR := preload("res://scripts/presentation/urban_decorator_3d.gd")
const PRESENTATION_FEEDBACK := preload("res://scripts/presentation/presentation_feedback_3d.gd")

var world: Node3D
var player: Node3D
var heartforge: Node3D
var camera: Camera3D
var run_state: Node
var noise_system: Node
var sanctuary: Node
var urban: Node
var feedback: Node


func configure(
        next_world: Node3D,
        next_player: Node3D,
        next_heartforge: Node3D,
        next_camera: Camera3D,
        next_run_state: Node,
        next_noise_system: Node
    ) -> void:
    world = next_world
    player = next_player
    heartforge = next_heartforge
    camera = next_camera
    run_state = next_run_state
    noise_system = next_noise_system


func _ready() -> void:
    if world == null:
        world = get_parent() as Node3D
    _polish_environment()

    sanctuary = SANCTUARY_DECORATOR.new()
    sanctuary.name = "SanctuaryDecorator"
    sanctuary.configure(world, heartforge)
    add_child(sanctuary)

    urban = URBAN_DECORATOR.new()
    urban.name = "UrbanDecorator"
    urban.configure(world)
    add_child(urban)

    feedback = PRESENTATION_FEEDBACK.new()
    feedback.name = "PresentationFeedback"
    feedback.configure(world, player, heartforge, camera, noise_system)
    add_child(feedback)

    if heartforge != null and heartforge.has_signal(&"health_changed"):
        var callback := Callable(self, "_on_heartforge_health_changed")
        if not heartforge.is_connected(&"health_changed", callback):
            heartforge.connect(&"health_changed", callback)


func _polish_environment() -> void:
    if world == null:
        return
    var environment_node := _find_world_environment(world)
    if environment_node == null:
        environment_node = WorldEnvironment.new()
        environment_node.name = "BeautifulWorldEnvironment"
        world.add_child(environment_node)
    var environment := environment_node.environment
    if environment == null:
        environment = Environment.new()
        environment_node.environment = environment

    var sky_material := ProceduralSkyMaterial.new()
    sky_material.sky_top_color = Color("304d68")
    sky_material.sky_horizon_color = Color("a27c69")
    sky_material.ground_horizon_color = Color("665b53")
    sky_material.ground_bottom_color = Color("1c2328")
    sky_material.sun_angle_max = 18.0
    sky_material.sun_curve = 0.11
    sky_material.sun_energy_multiplier = 0.55
    var sky := Sky.new()
    sky.sky_material = sky_material

    environment.background_mode = Environment.BG_SKY
    environment.sky = sky
    environment.background_energy_multiplier = 0.82
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    environment.ambient_light_color = Color("8da6b6")
    environment.ambient_light_energy = 0.56
    environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    environment.tonemap_mode = Environment.TONE_MAPPER_ACES
    environment.tonemap_exposure = 1.18
    environment.tonemap_white = 2.35
    environment.adjustment_enabled = true
    environment.adjustment_brightness = 1.04
    environment.adjustment_contrast = 1.08
    environment.adjustment_saturation = 1.08
    environment.fog_enabled = true
    environment.fog_light_color = Color("718491")
    environment.fog_light_energy = 0.72
    environment.fog_density = 0.0085
    environment.fog_height = 1.2
    environment.fog_height_density = 0.07
    environment.fog_aerial_perspective = 0.38
    environment.fog_sky_affect = 0.42
    environment.glow_enabled = true
    environment.glow_intensity = 0.72
    environment.glow_strength = 1.12
    environment.glow_bloom = 0.18

    var moon := _find_directional_light(world)
    if moon != null:
        moon.light_color = Color("b5cddd")
        moon.light_energy = 0.82
        moon.shadow_enabled = true
        moon.directional_shadow_max_distance = 120.0

    var sunset_fill := DirectionalLight3D.new()
    sunset_fill.name = "WarmHorizonFill"
    sunset_fill.rotation_degrees = Vector3(-24.0, 132.0, 0.0)
    sunset_fill.light_color = Color("d88958")
    sunset_fill.light_energy = 0.32
    sunset_fill.shadow_enabled = false
    world.add_child(sunset_fill)


func _on_heartforge_health_changed(current: float, maximum: float) -> void:
    var ratio := clampf(current / maxf(1.0, maximum), 0.0, 1.0)
    if sanctuary != null and sanctuary.has_method(&"set_integrity"):
        sanctuary.call(&"set_integrity", ratio)


func _find_world_environment(root: Node) -> WorldEnvironment:
    for child in root.get_children():
        if child is WorldEnvironment:
            return child as WorldEnvironment
        var nested := _find_world_environment(child)
        if nested != null:
            return nested
    return null


func _find_directional_light(root: Node) -> DirectionalLight3D:
    for child in root.get_children():
        if child is DirectionalLight3D:
            return child as DirectionalLight3D
        var nested := _find_directional_light(child)
        if nested != null:
            return nested
    return null
