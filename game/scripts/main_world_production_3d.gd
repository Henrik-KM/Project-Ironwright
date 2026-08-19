class_name IronwrightProductionWorld3D
extends IronwrightFullGameWorld3D

## Final native entrypoint for the current production foundation. This thin
## layer keeps progression gates authoritative even when inherited forge UI
## callbacks call the generic fabrication methods directly.


func _start_manual_build(archetype: StringName) -> void:
    if archetype == &"engineer" and (progression == null or not progression.has_effect(&"engineer_build_available")):
        if hud != null:
            hud.push_notification("ENGINEER FRAME LOCKED · EVOLVE THE HEARTFORGE TO TIER 2")
        return
    super._start_manual_build(archetype)


func _start_manual_upgrade(archetype: StringName) -> void:
    if archetype == &"engineer" and (progression == null or not progression.has_effect(&"engineer_build_available")):
        if hud != null:
            hud.push_notification("ENGINEER UPGRADES LOCKED · EVOLVE THE HEARTFORGE TO TIER 2")
        return
    super._start_manual_upgrade(archetype)
