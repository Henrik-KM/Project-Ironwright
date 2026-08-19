class_name IronwrightBeautifulWorld3D
extends IronwrightWorld3D

## Production-facing presentation layer over the systems-complete 3D slice.
## Simulation remains in IronwrightWorld3D; this class owns only atmosphere,
## procedural art detail, animation and feedback.

var aesthetic_director: AestheticDirector3D


func _ready() -> void:
    super._ready()
    aesthetic_director = AestheticDirector3D.new()
    aesthetic_director.name = "AestheticDirector"
    aesthetic_director.process_mode = Node.PROCESS_MODE_ALWAYS
    aesthetic_director.configure(self, player, heartforge, camera, run_state, noise_system)
    add_child(aesthetic_director)
    run_state.log_event("Blue-hour light reaches the streets. The Heartforge is still small, but it finally feels inhabited.")
    if hud != null:
        hud.push_notification("AESTHETIC OVERHAUL ONLINE · WARM SANCTUARY · READABLE BLUE-HOUR CITY · PROCEDURAL ANIMATION")
