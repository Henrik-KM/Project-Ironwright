# Signal Relay authored asset source

`build_relay_asset.py` generates the original `../relay.gltf` runtime shell
from the shared high-definition machine mesh helpers. Curved mast, dish, leg
and service hardware uses dense source tessellation so the communications
silhouette remains smooth after a rebuild. The Relay is a
presentation-only communications chassis with a protected mast, directional
dish, signal beacon, heat sink, service latch and signal cable.

The chassis and internal core use smooth authored ellipsoidal envelopes while
the dish, mast and signal hardware preserve the Relay's distinct silhouette.

Stable nodes include `RelayModel`, `Sensor`, `OpticLens`, `RelayMast`,
`RelayDirectionalDish`, `RelayBeacon`, `RelayDishRim`, and
`ProductionAssetMarker`. The asset exposes `Idle`, `Walk`, `Work`, `Fire`, and
`Hit` clips; the runtime procedural layer remains responsible for simulation
and small secondary motion.

No third-party runtime asset is used. The Relay's collision, health, route
support, autonomy, and save state remain owned by the game systems.
