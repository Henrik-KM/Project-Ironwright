#!/usr/bin/env python3
"""Expand the authored Project Ironwright patch staged in chunk files."""

from __future__ import annotations

import base64
import json
import zlib
from pathlib import Path


CHUNK_DIR = Path("scripts/.aesthetic_patch")


def main() -> int:
    chunks = sorted(CHUNK_DIR.glob("chunk_*.txt"))
    if not chunks:
        raise RuntimeError(f"No patch chunks found under {CHUNK_DIR}")

    payload = "".join(path.read_text(encoding="utf-8").strip() for path in chunks)
    decoded = base64.b64decode(payload, validate=True)
    files = json.loads(zlib.decompress(decoded).decode("utf-8"))
    if not isinstance(files, dict) or not files:
        raise RuntimeError("Decoded patch must contain a non-empty file mapping")

    for relative_path, content in files.items():
        if not isinstance(relative_path, str) or not isinstance(content, str):
            raise RuntimeError("Patch entries must map UTF-8 paths to text contents")
        path = Path(relative_path)
        if path.is_absolute() or ".." in path.parts:
            raise RuntimeError(f"Unsafe patch path: {relative_path}")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    print(f"Applied {len(files)} Project Ironwright aesthetic and gameplay files.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
