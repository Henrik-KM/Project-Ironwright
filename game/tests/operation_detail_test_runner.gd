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
