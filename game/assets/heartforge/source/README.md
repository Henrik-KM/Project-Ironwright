# Heartforge authored shell

`build_heartforge_asset.py` creates the original high-definition Heartforge
primary shell used by the native release scene. It is dependency-free and
uses the shared project mesh builder only for primitive construction.
The reactor housing and furnace now use smooth ellipsoidal envelopes, while
the service cladding, control face, thermal shrouds and fabrication braces use
small authored chamfers so the focal machine holds a manufactured highlight at
tactical-camera distance.

The imported asset owns the permanent reactor silhouette and stable visual
sockets. Tier geometry, adaptation choices, damage-memory, lights, collision,
interaction and progression remain runtime-owned.
