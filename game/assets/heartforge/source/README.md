# Heartforge authored shell

`build_heartforge_asset.py` creates the original high-definition Heartforge
primary shell used by the native release scene. It is dependency-free and
uses the shared project mesh builder only for primitive construction.

The imported asset owns the permanent reactor silhouette and stable visual
sockets. Tier geometry, adaptation choices, damage-memory, lights, collision,
interaction and progression remain runtime-owned.
