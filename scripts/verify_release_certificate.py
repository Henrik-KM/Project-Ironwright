#!/usr/bin/env python3
"""Verify that the committed release certificate matches the certified source.

The certification workflow tests a source revision, generates deterministic
release assets, exports both desktop packages, then commits only the generated
asset outputs and certificate. This verifier prevents an older certificate from
remaining green after a later source change.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CERTIFICATE_PATH = ROOT / "docs" / "RELEASE_CERTIFICATION.json"
ALLOWED_CERTIFICATION_OUTPUTS = (
    "docs/RELEASE_CERTIFICATION.json",
    "game/assets/release/audio/",
    "game/assets/release/textures/",
)


def git(*arguments: str) -> str:
    completed = subprocess.run(
        ["git", *arguments],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return completed.stdout.strip()


def fail(message: str) -> int:
    print(f"RELEASE CERTIFICATE VERIFICATION FAILED: {message}", file=sys.stderr)
    return 1


def main() -> int:
    if not CERTIFICATE_PATH.is_file():
        return fail("docs/RELEASE_CERTIFICATION.json is missing; wait for the full certification workflow")
    try:
        certificate = json.loads(CERTIFICATE_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return fail(f"certificate JSON is invalid: {exc}")
    if not isinstance(certificate, dict):
        return fail("certificate root must be an object")

    current_head = git("rev-parse", "HEAD")
    parent = git("rev-parse", "HEAD^")
    certified_source = str(certificate.get("certified_source_sha", ""))
    if certified_source != parent:
        return fail(
            f"certificate names {certified_source or '<empty>'}, but the certification commit parent is {parent}"
        )

    message = git("log", "-1", "--pretty=%s")
    if message != "Certify Project Ironwright 1.0.0-rc.1":
        return fail(f"PR head is not the certification commit: {message!r}")

    changed = [
        line.strip()
        for line in git("diff", "--name-only", certified_source, current_head).splitlines()
        if line.strip()
    ]
    unexpected = [
        path
        for path in changed
        if not any(path == prefix or path.startswith(prefix) for prefix in ALLOWED_CERTIFICATION_OUTPUTS)
    ]
    if unexpected:
        return fail(f"certification commit contains unexpected source changes: {unexpected}")

    passed = set(certificate.get("passed_gates", []))
    required = {
        "browser_reference_and_contracts",
        "release_assets",
        "godot_import",
        "core_gameplay",
        "aesthetic_acceptance",
        "progression_and_outposts",
        "first_session_accessibility",
        "complete_start_to_victory",
        "commercial_release_regression",
        "windows_export",
        "linux_export",
    }
    missing = sorted(required - passed)
    if missing:
        return fail(f"certificate is missing required passed gates: {missing}")

    artifacts = certificate.get("artifacts")
    if not isinstance(artifacts, dict):
        return fail("certificate artifacts field is missing")
    for name in [
        "ProjectIronwright-1.0.0-rc.1-Windows.zip",
        "ProjectIronwright-1.0.0-rc.1-Linux.tar.gz",
        "SHA256SUMS.txt",
    ]:
        record = artifacts.get(name)
        if not isinstance(record, dict):
            return fail(f"certificate is missing artifact {name}")
        if int(record.get("bytes", 0)) <= 0 or len(str(record.get("sha256", ""))) != 64:
            return fail(f"artifact record is invalid: {name}")

    print(
        "Project Ironwright release certificate verified: "
        f"source={certified_source}, certificate={current_head}, outputs={len(changed)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
