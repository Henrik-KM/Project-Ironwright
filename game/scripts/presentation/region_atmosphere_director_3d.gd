class_name RegionAtmosphereDirector3D
extends Node

## Keeps the persistent town visually legible as one continuous place while
## giving each authored region a restrained material and atmospheric identity.
## This is presentation-only: it never changes pressure, discovery or routing.

signal atmosphere_changed(region_id: StringName, kind: StringName)

var world: Node3D
var region_director: WorldRegionDirector3D
var player: Node3D
var environment: Environment
var current_region_id: StringName = &""
var current_kind: StringName = &""
var _target_ambient_color := Color("8da6b6")
var _target_fog_color := Color("718491")
var _target_ambient_energy: float = 0.56
var _target_fog_energy: float = 0.72
var _target_fog_density: float = 0.0085
var _target_saturation: float = 1.08
var _target_contrast: float = 1.08
var _target_brightness: float = 1.04
var _target_glow_intensity: float = 0.72
var _refresh_clock: float = 0.0
var _run_variation_profile: Dictionary = {}
var _run_ambient_tint := Color.WHITE
var _run_fog_tint := Color.WHITE


func configure(next_world: Node3D, next_region_director: WorldRegionDirector3D, next_player: Node3D) -> void:
    world = next_world
    region_director = next_region_director
    player = next_player


func _ready() -> void:
    environment = _find_environment(world)
    if environment == null:
        set_process(false)
        return
    refresh_now()


func _process(delta: float) -> void:
    if environment == null or region_director == null or player == null:
        return
    _refresh_clock += delta
    if _refresh_clock >= 0.35:
        _refresh_clock = 0.0
        _refresh_region(false)
    _apply_visuals(clampf(delta * 2.4, 0.0, 1.0))


func refresh_now() -> void:
    if environment == null:
        environment = _find_environment(world)
    _refresh_region(true)
    _apply_visuals(1.0)


func apply_run_variation(profile: Dictionary) -> void:
    _run_variation_profile = profile.duplicate(true)
    _run_ambient_tint = _profile_color(profile.get("ambient_tint", "#ffffff"), Color.WHITE)
    _run_fog_tint = _profile_color(profile.get("fog_tint", "#ffffff"), Color.WHITE)
    refresh_now()


func palette_for_kind(kind: StringName) -> Dictionary:
    match kind:
        &"sanctuary":
            # The opening district has its own restrained glow budget so the
            # Heartforge remains warm and focal without flattening wet ground.
            return _palette(Color("8da6b6"), Color("718491"), 0.56, 0.72, 0.0085, 1.08, 1.08, 1.04, 0.43)
        &"industrial":
            return _palette(Color("7e9a9e"), Color("536a70"), 0.52, 0.86, 0.0105, 0.94, 1.15, 0.98, 0.84)
        &"commercial":
            return _palette(Color("9c8c83"), Color("756b67"), 0.58, 0.78, 0.0095, 1.02, 1.09, 1.03, 0.9)
        &"tenement":
            return _palette(Color("8f9794"), Color("626f72"), 0.54, 0.8, 0.009, 0.98, 1.1, 1.01, 0.76)
        &"greenhouse":
            return _palette(Color("7eaa91"), Color("526e68"), 0.6, 0.74, 0.008, 1.12, 1.04, 1.04, 1.02)
        &"waterfront":
            return _palette(Color("6d8fa0"), Color("496e7c"), 0.5, 0.94, 0.012, 0.92, 1.16, 0.97, 0.88)
        &"rail":
            return _palette(Color("858a88"), Color("5e6467"), 0.5, 0.84, 0.010, 0.9, 1.18, 0.98, 0.8)
        &"nest":
            return _palette(Color("876d7b"), Color("5f465b"), 0.48, 0.9, 0.0115, 1.16, 1.12, 0.97, 1.08)
        &"research":
            return _palette(Color("76939d"), Color("4c6570"), 0.57, 0.82, 0.009, 0.98, 1.15, 1.0, 1.0)
        &"observatory":
            return _palette(Color("879ab0"), Color("586d83"), 0.62, 0.76, 0.008, 1.06, 1.06, 1.05, 1.12)
        &"endgame":
            return _palette(Color("795e72"), Color("4d394f"), 0.45, 1.0, 0.013, 1.2, 1.14, 0.94, 1.18)
        &"archive":
            return _palette(Color("899ba0"), Color("5d7178"), 0.55, 0.8, 0.009, 1.0, 1.1, 1.02, 0.86)
        _:
            return _palette(Color("8da6b6"), Color("718491"), 0.56, 0.72, 0.0085, 1.08, 1.08, 1.04, 0.72)


func _refresh_region(force: bool) -> void:
    if region_director == null or player == null:
        return
    var next_region := region_director.region_for_position(player.global_position)
    if not force and next_region == current_region_id:
        return
    var data := region_director.get_region_data(next_region)
    var next_kind := StringName(str(data.get("kind", "sanctuary")))
    current_region_id = next_region
    current_kind = next_kind
    var palette := palette_for_kind(next_kind)
    _target_ambient_color = palette["ambient"]
    _target_fog_color = palette["fog"]
    _target_ambient_energy = float(palette["ambient_energy"])
    _target_fog_energy = float(palette["fog_energy"])
    _target_fog_density = float(palette["fog_density"])
    _target_saturation = float(palette["saturation"])
    _target_contrast = float(palette["contrast"])
    _target_brightness = float(palette["brightness"])
    _target_glow_intensity = float(palette["glow"])
    # Run identity is a restrained color grade layered under each authored
    # district palette. It changes the town's emotional read without changing
    # visibility, navigation, ecology, pressure or any player-maintained
    # system.
    _target_ambient_color = _target_ambient_color.lerp(_run_ambient_tint, 0.16)
    _target_fog_color = _target_fog_color.lerp(_run_fog_tint, 0.16)
    _target_ambient_energy += float(_run_variation_profile.get("ambient_energy_bias", 0.0))
    _target_fog_energy += float(_run_variation_profile.get("fog_energy_bias", 0.0))
    _target_fog_density = maxf(0.001, _target_fog_density + float(_run_variation_profile.get("fog_density_bias", 0.0)))
    _target_brightness += float(_run_variation_profile.get("brightness_bias", 0.0))
    _target_glow_intensity = maxf(0.0, _target_glow_intensity + float(_run_variation_profile.get("glow_bias", 0.0)))
    atmosphere_changed.emit(current_region_id, current_kind)


func _apply_visuals(weight: float) -> void:
    if environment == null:
        return
    environment.ambient_light_color = environment.ambient_light_color.lerp(_target_ambient_color, weight)
    environment.fog_light_color = environment.fog_light_color.lerp(_target_fog_color, weight)
    var opening_floor := float(environment.get_meta(&"opening_ambient_floor", 0.0))
    var heartforge := world.get_node_or_null("Heartforge") as Node3D if world != null else null
    if opening_floor > 0.0 and (player == null or heartforge == null or player.global_position.distance_to(heartforge.global_position) > 32.0):
        opening_floor = 0.0
    environment.ambient_light_energy = maxf(opening_floor, lerpf(environment.ambient_light_energy, _target_ambient_energy, weight))
    environment.fog_light_energy = lerpf(environment.fog_light_energy, _target_fog_energy, weight)
    environment.fog_density = lerpf(environment.fog_density, _target_fog_density, weight)
    environment.adjustment_saturation = lerpf(environment.adjustment_saturation, _target_saturation, weight)
    environment.adjustment_contrast = lerpf(environment.adjustment_contrast, _target_contrast, weight)
    environment.adjustment_brightness = lerpf(environment.adjustment_brightness, _target_brightness, weight)
    environment.glow_intensity = lerpf(environment.glow_intensity, _target_glow_intensity, weight)


func _palette(ambient: Color, fog: Color, ambient_energy: float, fog_energy: float, fog_density: float, saturation: float, contrast: float, brightness: float, glow: float) -> Dictionary:
    return {
        "ambient": ambient,
        "fog": fog,
        "ambient_energy": ambient_energy,
        "fog_energy": fog_energy,
        "fog_density": fog_density,
        "saturation": saturation,
        "contrast": contrast,
        "brightness": brightness,
        "glow": glow,
    }


func _find_environment(node: Node) -> Environment:
    if node == null:
        return null
    if node is WorldEnvironment:
        return (node as WorldEnvironment).environment
    for child in node.get_children():
        var found := _find_environment(child)
        if found != null:
            return found
    return null


func _profile_color(value: Variant, fallback: Color) -> Color:
    if value is Color:
        return value as Color
    var raw := str(value)
    if raw.is_empty():
        return fallback
    return Color(raw)
