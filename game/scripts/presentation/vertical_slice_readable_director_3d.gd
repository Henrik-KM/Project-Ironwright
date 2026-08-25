class_name VerticalSliceReadableDirector3D
extends VerticalSliceDirector3D

## The vertical slice uses darker wet materials and deeper interior contrast than
## the broad aesthetic pass, so preserve a minimum readable ambient floor while
## relying on local practical lights for mood.


func _ready() -> void:
    process_priority = 100
    super._ready()


func _polish_environment() -> void:
    super._polish_environment()
    var environment_node := _find_world_environment(world)
    if environment_node == null or environment_node.environment == null:
        return
    # Lift the opening-only ambient floor just enough to preserve readable wet
    # district geometry in the lower frame without flattening the Heartforge
    # key, practical lights, or the amber route contrast.
    environment_node.environment.ambient_light_energy = maxf(0.52, environment_node.environment.ambient_light_energy)
    environment_node.environment.set_meta(&"opening_ambient_floor", 0.52)
    environment_node.environment.fog_density = minf(0.013, environment_node.environment.fog_density)


func _process(delta: float) -> void:
    super._process(delta)
    var environment_node := _find_world_environment(world)
    if environment_node == null or environment_node.environment == null:
        return
    # Region atmosphere may reapply a lower palette after the opening pass has
    # been built. Keep the opening floor sustained so slower CI and longer
    # sessions retain the same readable wet-district frame.
    environment_node.environment.ambient_light_energy = maxf(0.52, environment_node.environment.ambient_light_energy)
