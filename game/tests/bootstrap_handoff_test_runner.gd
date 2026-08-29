extends SceneTree

var failures: Array[String] = []


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    var change_error := change_scene_to_file("res://scenes/bootstrap.tscn")
    _expect(change_error == OK, "The retained bootstrap scene must be loadable.")
    for _frame in range(4):
        await process_frame

    var active_scene := current_scene
    _expect(active_scene != null, "The bootstrap handoff must leave an active scene.")
    if active_scene != null:
        _expect(active_scene.scene_file_path == "res://scenes/main_3d.tscn", "The bootstrap scene must hand off to the full game entrypoint.")

    if failures.is_empty():
        print("Project Ironwright bootstrap handoff tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
