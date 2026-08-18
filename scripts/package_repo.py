#!/usr/bin/env python3
"""Validate and create a clean ZIP archive of the repository."""

from __future__ import annotations

import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT.parent / f"{ROOT.name}.zip"
EXCLUDED_PARTS = {".git", ".godot", "__pycache__"}


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

    with zipfile.ZipFile(OUTPUT, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(ROOT.rglob("*")):
            if not path.is_file():
                continue
            relative = path.relative_to(ROOT)
            if any(part in EXCLUDED_PARTS for part in relative.parts):
                continue
            archive.write(path, Path(ROOT.name) / relative)

    print(f"Created {OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
