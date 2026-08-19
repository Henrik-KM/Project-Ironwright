#!/usr/bin/env python3
"""Dependency-free smoke test that catches missing browser build files."""
from __future__ import annotations

import functools
import http.server
import json
import pathlib
import socketserver
import threading
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[2]
WEB = ROOT / "web"


class QuietHandler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, _format: str, *args: object) -> None:
        return


def fetch(base: str, relative: str) -> bytes:
    with urllib.request.urlopen(f"{base}/{relative}", timeout=5) as response:
        if response.status != 200:
            raise AssertionError(f"{relative}: HTTP {response.status}")
        return response.read()


def main() -> None:
    handler = functools.partial(QuietHandler, directory=str(WEB))
    with socketserver.TCPServer(("127.0.0.1", 0), handler) as server:
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        base = f"http://127.0.0.1:{server.server_address[1]}"
        try:
            index = fetch(base, "index.html").decode("utf-8")
            styles = fetch(base, "styles.css").decode("utf-8")
            loader = fetch(base, "src/loader.mjs").decode("utf-8")
            assert "game-canvas" in index
            assert "automatically fires" in index
            assert "#game-shell" in styles
            assert "loadSource" in loader
            for kind in ("sim", "game"):
                manifest = json.loads(fetch(base, f"source/{kind}/manifest.json"))
                assert manifest["parts"], f"{kind} manifest has no parts"
                for part in manifest["parts"]:
                    content = fetch(base, f"source/{kind}/{part}")
                    assert content, f"source/{kind}/{part} is empty"
        finally:
            server.shutdown()
            thread.join(timeout=2)
    print("Browser build smoke test passed: all launch files and segmented sources are present.")


if __name__ == "__main__":
    main()
