#!/usr/bin/env python3
"""Finish primitive feral roaming and backup-aligned enemy-tier persistence."""

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def replace(relative: str, old: str, new: str) -> None:
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    if old in text:
        path.write_text(text.replace(old, new), encoding="utf-8")


def insert_after(relative: str, marker: str, block: str) -> None:
    path = ROOT / relative
    text = path.read_text(encoding="utf-8")
    if block.strip() in text:
        return
    index = text.find(marker)
    if index < 0:
        raise RuntimeError(f"Marker not found in {relative}: {marker!r}")
    index += len(marker)
    path.write_text(text[:index] + block + text[index:], encoding="utf-8")


def main() -> int:
    replace(
        "game/scripts/enemies/enemy_tier_brain_3d.gd",
        '''        roam_serial += 1\n        goal_position = _random_point(territory_center, territory_radius * 1.45, roam_serial * 31 + 7)\n        has_goal = true\n        _set_behaviour(&"roam", "Wandering randomly from its birth nest without a strategic purpose.")''',
        '''        roam_serial += 1\n        # Feral organisms perform a broad random walk. A very weak home bias\n        # prevents permanent drift outside the authored world without turning\n        # the movement into nest patrol or purposeful defense.\n        var wandering_center := enemy.global_position.lerp(territory_center, 0.12)\n        goal_position = _random_point(wandering_center, territory_radius * 1.45, roam_serial * 31 + 7)\n        has_goal = true\n        _set_behaviour(&"roam", "Wandering continuously through the town without patrol, scouting, or a strategic purpose.")''',
    )
    insert_after(
        "game/scripts/systems/enemy_tier_progression_bootstrap_3d.gd",
        "var pending_restore: bool = false\n",
        "var prefer_backup_restore: bool = false\n",
    )
    replace(
        "game/scripts/systems/enemy_tier_progression_bootstrap_3d.gd",
        '''    if pending_restore:\n        pending_restore = false\n        _restore_sidecar()''',
        '''    if pending_restore:\n        pending_restore = false\n        _restore_sidecar(prefer_backup_restore)\n        prefer_backup_restore = false''',
    )
    replace(
        "game/scripts/systems/enemy_tier_progression_bootstrap_3d.gd",
        '''func _on_world_load_completed(slot_id: StringName, source_path: String, recovered_backup: bool) -> void:\n    pending_restore = true''',
        '''func _on_world_load_completed(slot_id: StringName, source_path: String, recovered_backup: bool) -> void:\n    prefer_backup_restore = recovered_backup\n    pending_restore = true''',
    )
    replace(
        "game/scripts/systems/enemy_tier_progression_bootstrap_3d.gd",
        '''func _restore_sidecar() -> bool:\n    var envelope := _read_verified(SIDECAR_PATH)\n    if envelope.is_empty():\n        envelope = _read_verified(SIDECAR_BACKUP_PATH)''',
        '''func _restore_sidecar(prefer_backup: bool = false) -> bool:\n    var envelope := _read_verified(SIDECAR_BACKUP_PATH if prefer_backup else SIDECAR_PATH)\n    if envelope.is_empty():\n        envelope = _read_verified(SIDECAR_PATH if prefer_backup else SIDECAR_BACKUP_PATH)''',
    )
    print("Completed feral roaming and backup-aligned enemy-tier persistence.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
