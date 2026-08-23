#!/usr/bin/env python3
"""Validate and create a clean ZIP archive of the repository."""

from __future__ import annotations

import subprocess
import sys
import zipfile
from pathlib import Path
from typing import Iterable

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT.parent / f"{ROOT.name}.zip"
EXCLUDED_PARTS = {".git", ".godot", "__pycache__", "build", "dist", "exports"}
EXCLUDED_FILE_NAMES = {"export.cfg", "export_presets.cfg"}
EXCLUDED_SUFFIXES = {".app", ".exe", ".log", ".pck"}
FIXED_ZIP_TIMESTAMP = (1980, 1, 1, 0, 0, 0)


def iter_source_files(root: Path = ROOT) -> Iterable[tuple[Path, Path]]:
    """Yield tracked source files and their repository-relative paths.

    Git's tracked-file list is intentional here: ignored local exports, caches,
    recordings, and diagnostics must never leak into a source archive, even if
    they happen to exist below the repository root when packaging runs.
    """

    result = subprocess.run(
        ["git", "ls-files", "-z", "--cached"],
        cwd=root,
        check=True,
        capture_output=True,
    )
    tracked_paths = result.stdout.decode("utf-8").split("\0")
    tracked_relatives: set[Path] = set()
    for raw_path in tracked_paths:
        if not raw_path:
            continue
        relative = Path(raw_path)
        tracked_relatives.add(relative)
        if relative.name in EXCLUDED_FILE_NAMES:
            continue
        if any(part in EXCLUDED_PARTS for part in relative.parts):
            continue
        if relative.suffix.lower() in EXCLUDED_SUFFIXES:
            continue
        path = root / relative
        if path.is_file():
            yield path, relative

    manifest = root / "MANIFEST.sha256"
    if manifest.is_file() and manifest.relative_to(root) not in tracked_relatives:
        yield manifest, manifest.relative_to(root)


def write_deterministic_entry(archive: zipfile.ZipFile, path: Path, relative: Path) -> None:
    """Write one source file with stable ZIP metadata for reproducible archives."""

    info = zipfile.ZipInfo(str(Path(ROOT.name) / relative).replace("\\", "/"), FIXED_ZIP_TIMESTAMP)
    info.compress_type = zipfile.ZIP_DEFLATED
    info.create_system = 0
    archive.writestr(info, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)


def main() -> int:
    validation = subprocess.run(
        [sys.executable, str(ROOT / "scripts/validate_repo.py"), "--write-manifest"],
        cwd=ROOT,
        check=False,
    )
    if validation.returncode != 0:
        return validation.returncode

    if OUTPUT.exists():
        OUTPUT.unlink()

    source_files = sorted(iter_source_files(), key=lambda item: item[1].as_posix())
    with zipfile.ZipFile(OUTPUT, "w") as archive:
        for path, relative in source_files:
            write_deterministic_entry(archive, path, relative)

    print(f"Created {OUTPUT} ({len(source_files)} source files)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
