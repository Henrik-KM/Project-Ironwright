extends SceneTree

const SAVE_SERVICE := preload("res://scripts/systems/transactional_save_service_3d.gd")
const TEST_PRIMARY := "user://ironwright_transactional_save_test.json"
const TEST_LEGACY_FOUNDATION := "user://ironwright_transactional_legacy_foundation.json"
const TEST_LEGACY_EXTENSION := "user://ironwright_transactional_legacy_extension.json"

var failures: Array[String] = []


func _initialize() -> void:
    call_deferred("_run_all")


func _run_all() -> void:
    _cleanup()
    var service := SAVE_SERVICE.new() as TransactionalSaveService3D
    service.configure(TEST_PRIMARY, TEST_LEGACY_FOUNDATION, TEST_LEGACY_EXTENSION)

    var first := {
        "foundation": {"run_state": {"scrap": 12}},
        "extensions": {"full_game": {"foundation_milestone_complete": false}},
    }
    _expect(service.write_snapshot(first), "The transactional save service must write the first envelope.")
    var second := {
        "foundation": {"run_state": {"scrap": 24}},
        "extensions": {"full_game": {"foundation_milestone_complete": true}},
    }
    _expect(service.write_snapshot(second), "The transactional save service must write a replacement envelope.")
    _expect(FileAccess.file_exists(TEST_PRIMARY + ".bak1"), "The previous save must rotate into backup 1.")
    var current := service.read_snapshot()
    _expect(int(current.get("schema_version", 0)) == TransactionalSaveService3D.CURRENT_SCHEMA_VERSION, "Current saves must expose the current schema version.")
    _expect(int((current.get("foundation", {}) as Dictionary).get("run_state", {}).get("scrap", 0)) == 24, "The primary save must preserve the newest foundation state.")

    var corrupt := FileAccess.open(TEST_PRIMARY, FileAccess.WRITE)
    corrupt.store_string("{not valid json")
    corrupt.close()
    var recovered := service.read_snapshot()
    _expect(service.last_source_path == TEST_PRIMARY + ".bak1", "A corrupt primary must recover from backup 1.")
    _expect(int((recovered.get("foundation", {}) as Dictionary).get("run_state", {}).get("scrap", 0)) == 12, "Backup recovery must restore the last valid foundation state.")

    _cleanup()
    var legacy_foundation := FileAccess.open(TEST_LEGACY_FOUNDATION, FileAccess.WRITE)
    legacy_foundation.store_string(JSON.stringify({"schema_version": 1, "run_state": {"scrap": 31}}))
    legacy_foundation.close()
    var legacy_extension := FileAccess.open(TEST_LEGACY_EXTENSION, FileAccess.WRITE)
    legacy_extension.store_string(JSON.stringify({"schema_version": 1, "progression": {"heartforge_tier": 2}}))
    legacy_extension.close()
    var migrated := service.read_snapshot()
    _expect(bool(migrated.get("migrated_from_legacy", false)), "Legacy two-file saves must be identified as migrated.")
    _expect(int((migrated.get("foundation", {}) as Dictionary).get("run_state", {}).get("scrap", 0)) == 31, "Legacy foundation state must migrate into the unified envelope.")
    _expect((migrated.get("extensions", {}) as Dictionary).has("full_game"), "Legacy full-game extension state must migrate with the foundation.")

    _cleanup()
    if failures.is_empty():
        print("Project Ironwright transactional persistence tests passed.")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    print("Project Ironwright transactional persistence tests failed: %d" % failures.size())
    quit(1)


func _cleanup() -> void:
    for path in [
        TEST_PRIMARY,
        TEST_PRIMARY + ".bak1",
        TEST_PRIMARY + ".bak2",
        TEST_PRIMARY + ".tmp",
        TEST_LEGACY_FOUNDATION,
        TEST_LEGACY_EXTENSION,
    ]:
        if FileAccess.file_exists(path):
            DirAccess.remove_absolute(path)


func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
