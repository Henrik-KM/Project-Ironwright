extends SceneTree

const DETAIL_SCRIPT := preload("res://scripts/systems/operation_detail_director_3d.gd")

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    var camera := Camera3D.new()
    camera.position = Vector3.ZERO
    root.add_child(camera)
    var director = DETAIL_SCRIPT.new()
    root.add_child(director)
    director.configure(camera)

    _expect(director.update_operation(&"operation.test", Vector3(20.0, 0.0, 0.0)) == &"active", "A nearby operation must begin in active detail.")
    _expect(director.update_operation(&"operation.test", Vector3(60.0, 0.0, 0.0)) == &"reduced", "A distant operation must transition to reduced detail.")
    _expect(director.update_operation(&"operation.test", Vector3(40.0, 0.0, 0.0)) == &"reduced", "Reduced detail must use hysteresis instead of thrashing at the boundary.")
    camera.position = Vector3(35.0, 0.0, 0.0)
    _expect(director.update_operation(&"operation.test", Vector3(60.0, 0.0, 0.0)) == &"active", "Returning the camera within the active radius must restore active detail.")
    director.clear_operation(&"operation.test")
    _expect(director.mode_for(&"operation.test") == &"active", "Clearing an operation must remove its transient detail mode.")
    director.show_route_recovery(&"operation.test", Vector3(4.0, 0.0, 6.0), 1, 3)
    var recovery_beacon := director.get_node_or_null("AutonomousRouteRecoveryBeacon") as Node3D
    _expect(recovery_beacon != null and recovery_beacon.visible, "Route recovery detail must expose a visible in-world detour beacon.")
    if recovery_beacon != null:
        _expect(recovery_beacon.find_child("DetourBaseHousing", true, false) != null and recovery_beacon.find_child("DetourBaseCollar", true, false) != null, "Route recovery detail must ground the detour marker in a manufactured housing.")
        _expect(recovery_beacon.find_child("DetourDirection00", true, false) != null and recovery_beacon.find_child("DetourDirection03", true, false) != null, "Route recovery detail must expose bounded directional plates for the autonomous side route.")
    _expect(director.route_recovery_material != null and director.route_recovery_material.emission_energy_multiplier <= 2.0, "The autonomous detour cue must keep its emissive warning below the scene-washing threshold.")
    _expect(director.route_recovery_label != null and director.route_recovery_label.font_size <= 18 and director.route_recovery_label.pixel_size <= 0.016, "The autonomous detour label must remain a restrained in-world explanation rather than a dominant screen-space banner.")
    director.clear_route_recovery()
    _expect(not director.is_route_recovery_visible(), "Clearing route recovery detail must remove the transient detour beacon.")

    if failures.is_empty():
        print("Project Ironwright operation-detail tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Project Ironwright operation-detail tests failed: %d" % failures.size())
    quit(1)


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
